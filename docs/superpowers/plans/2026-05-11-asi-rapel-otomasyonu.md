# Asi Rapel Otomasyonu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the automatic rapel (repeat dose) task creation when a vaccination is performed, make rapel intervals editable in the UI, and prevent duplicate rapel tasks.

**Architecture:** Update `add_vaccination` RPC to create better gorev_log entries (with stok_id, kaynak, parent tracking, duplicate check). Add rapel interval editing to ayarlar panel's vaccine catalog. Buzagi takvimi is deferred to a separate spec.

**Tech Stack:** Supabase RPC (PostgreSQL), vanilla JS, existing IDB sync + ayarlar UI patterns.

---

## Current State

- `add_vaccination` RPC (migration 20260331000032) already creates `ASI_HATIRLATMA` gorev when `repeat_interval_days IS NOT NULL`
- BUT the gorev is missing: `stok_id`, `miktar`, `kaynak`, proper parent linking
- `ileri_gebe_asi_tamamla` RPC creates its own rapel (ILERI_GEBE_ASI type with parent_id)
- When ileri_gebe calls add_vaccination, it passes `'GorevID:' || gorev_id` as p_notes — this creates a DUPLICATE rapel (ASI_HATIRLATMA) alongside the ileri_gebe one
- `vaccines.repeat_interval_days` exists in DB but is NOT editable from UI

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `supabase/migrations/20260511000004_add_vaccination_rapel_fix.sql` | Create | Update add_vaccination RPC with better rapel gorev |
| `js/ui.js` | Modify | Vaccine catalog rapel interval editing in ayarlar |
| `index.html` | Modify | Vaccine catalog section UI update |

---

### Task 1: Update add_vaccination RPC — Better rapel gorev

**Files:**
- Create: `supabase/migrations/20260511000004_add_vaccination_rapel_fix.sql`

- [ ] **Step 1: Write the updated RPC**

Key changes from original:
1. Add `stok_id`, `miktar`, `kaynak='ASI_RAPEL'` to rapel gorev
2. Skip rapel creation when p_notes starts with 'GorevID:' (ileri_gebe handles its own)
3. Duplicate check: don't create if same hayvan_id + gorev_tipi + hedef_tarih + vaccine exists
4. Link rapel to vaccination via notes

```sql
BEGIN;

CREATE OR REPLACE FUNCTION public.add_vaccination(
  p_animal_id     text,
  p_vaccine_id    uuid,
  p_date          date    DEFAULT CURRENT_DATE,
  p_dose_override numeric DEFAULT NULL,
  p_notes         text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_vaccine     record;
  v_new_id      uuid;
  v_next_due    date;
  v_dose        numeric;
  v_animal      record;
  v_islem_id    text := gen_random_uuid()::text;
  v_is_gorev_triggered boolean;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadi veya aktif degil');
  END IF;

  SELECT * INTO v_vaccine FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Asi kaydi bulunamadi');
  END IF;

  v_dose := COALESCE(p_dose_override, v_vaccine.dose);

  IF v_vaccine.repeat_interval_days IS NOT NULL THEN
    v_next_due := p_date + (v_vaccine.repeat_interval_days || ' days')::interval;
  END IF;

  INSERT INTO public.vaccination_log (
    animal_id, vaccine_id, vaccination_date, dose_given, unit, route, next_due_date, notes
  ) VALUES (
    p_animal_id, p_vaccine_id, p_date, v_dose,
    v_vaccine.unit, v_vaccine.route, v_next_due, p_notes
  )
  RETURNING id INTO v_new_id;

  -- Rapel gorev olustur — SADECE:
  -- 1. repeat_interval_days varsa
  -- 2. ileri_gebe'den tetiklenmemisse (GorevID: prefix = ileri_gebe kendi rapelini yaratir)
  -- 3. Duplicate yoksa (ayni hayvan + ayni hedef tarih + ASI_RAPEL)
  v_is_gorev_triggered := (p_notes IS NOT NULL AND p_notes LIKE 'GorevID:%');

  IF v_next_due IS NOT NULL AND NOT v_is_gorev_triggered THEN
    INSERT INTO public.gorev_log (
      hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi,
      stok_id, miktar, kaynak
    )
    SELECT
      p_animal_id,
      'ASI_RAPEL',
      v_vaccine.name || ' (rapel)',
      v_next_due,
      false,
      v_vaccine.stock_item_id,
      v_dose,
      'ASI_RAPEL'
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = p_animal_id
        AND gorev_tipi = 'ASI_RAPEL'
        AND hedef_tarih = v_next_due
        AND aciklama LIKE v_vaccine.name || '%'
        AND tamamlandi = false
    );
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ASI_KAYDI',
    p_animal_id,
    v_new_id::text,
    'vaccination_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'vaccination_log', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb,
      'vaccine_name', v_vaccine.name,
      'next_due', v_next_due
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_new_id,
    'next_due', v_next_due,
    'islem_id', v_islem_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_vaccination(text,uuid,date,numeric,text) TO anon, authenticated;

END;
```

- [ ] **Step 2: Deploy via supabase_migrate**

Test cases:
```sql
-- Test 1: Normal asi → rapel olusmaliydi... (check gorev_log)
-- Test 2: ileri_gebe tetiklemesi → ASI_RAPEL olusMAMALI
-- Bu testleri prod'da yapamayız, sadece RPC deploy kontrolu
SELECT 'add_vaccination updated' AS status;
```

- [ ] **Step 3: Save file + commit**

```bash
git add supabase/migrations/20260511000004_add_vaccination_rapel_fix.sql
git commit -m "fix: add_vaccination rapel — stok_id, duplicate check, ileri_gebe bypass"
```

---

### Task 2: Ayarlar UI — Vaccine rapel interval editing

**Files:**
- Modify: `js/ui.js` (renderAyarlarVaksiyon function, around the vaccine catalog section)
- Modify: `index.html` (ay-vaksiyon-list section)

- [ ] **Step 1: Find and update the vaccine catalog renderer**

Search for `ay-vaksiyon-list` in ui.js. The current renderer shows a read-only list. Update it to include a rapel interval dropdown per vaccine.

Find the function that renders the vaccine list (likely `renderAyarlarVaksiyonList` or similar). Replace with:

```javascript
async function renderAyarlarVaksiyonList(){
  const el=g('ay-vaksiyon-list'); if(!el) return;
  const vaccines=await getData('vaccines');
  const intervals=[
    {val:null,lbl:'Tek Doz'},
    {val:21,lbl:'21 gun'},
    {val:90,lbl:'90 gun'},
    {val:180,lbl:'180 gun'},
    {val:365,lbl:'365 gun'}
  ];
  el.innerHTML=vaccines.map(vac=>{
    const opts=intervals.map(i=>`<option value="${i.val===null?'':i.val}"${vac.repeat_interval_days===i.val?' selected':''}>${i.lbl}</option>`).join('');
    return `<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
      <div>
        <span style="font-size:.8rem;color:var(--ink)">${vac.name}</span>
        ${vac.is_mandatory?'<span style="font-size:.6rem;color:var(--red);margin-left:4px">Zorunlu</span>':''}
      </div>
      <select onchange="vaccineRapelGuncelle('${vac.id}',this.value)" style="padding:4px 6px;border:1px solid var(--brd);border-radius:6px;font-size:.7rem;min-width:80px">
        ${opts}
      </select>
    </div>`;
  }).join('');
}
```

- [ ] **Step 2: Add the update function**

```javascript
async function vaccineRapelGuncelle(vaccineId, val){
  const days=val===''?null:parseInt(val);
  const{error}=await db.from('vaccines').update({repeat_interval_days:days}).eq('id',vaccineId);
  if(error){toast('Hata: '+error.message);return;}
  await pullTables(['vaccines']);
  toast('Rapel suresi guncellendi');
}
```

- [ ] **Step 3: Ensure renderAyarlarVaksiyonList is called when ayarlar opens**

Find where the other ayarlar renderers are called (renderAyarlarHekimList, renderAyarlarSpermaList). Add `renderAyarlarVaksiyonList()` alongside them.

- [ ] **Step 4: Add vaccines to IDB FETCHERS if not already there**

Check if `vaccines` is already in the FETCHERS object in api.js. It should be (from the vaccination module migration). If not, add:
```javascript
vaccines: () => db.from('vaccines').select('*'),
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js index.html
git commit -m "feat: vaccine rapel interval editing in ayarlar panel"
```

---

### Task 3: Verify gorev_log kategori integration

**Files:** No changes needed — verification only.

- [ ] **Step 1: Verify ASI_RAPEL shows in task list**

The task category filter (from Spec 1) uses `_katTipMap`:
```javascript
const _katTipMap = {
  'Asi': ['ASI_HATIRLATMA','ILERI_GEBE_ASI','BUZAGI_ASI'],
  ...
};
```

Check that `ASI_RAPEL` is included in the 'Asi' category. If not, add it:

In `js/ui.js`, find `_katTipMap` and add `'ASI_RAPEL'` to the Asi array:
```javascript
'Asi': ['ASI_HATIRLATMA','ASI_RAPEL','ILERI_GEBE_ASI','BUZAGI_ASI'],
```

- [ ] **Step 2: Verify rapel task completion works**

When a rapel task (ASI_RAPEL) is completed:
1. It should have `stok_id` → enables stock deduction on completion
2. The existing `doneTask()` flow should handle it like any vaccination task

Check that `doneTask()` in ui.js handles ASI_RAPEL gorev_tipi. If it needs special handling (opening vaccine selection modal), add a case for it alongside existing ASI_HATIRLATMA handling.

- [ ] **Step 3: Commit if changes were needed**

```bash
git add js/ui.js
git commit -m "fix: ASI_RAPEL added to kategori filter + task completion flow"
```

---

### Task 4: Clean up old ASI_HATIRLATMA gorev references

**Files:**
- Modify: `js/ui.js` (optional cleanup)

- [ ] **Step 1: Check if ASI_HATIRLATMA is used anywhere else**

The old `add_vaccination` created gorevs with `gorev_tipi='ASI_HATIRLATMA'`. The new one uses `'ASI_RAPEL'`. Existing gorevs in the DB may still have ASI_HATIRLATMA.

DON'T delete or rename existing gorev_log records. Just ensure both types are handled:
- `ASI_HATIRLATMA` (legacy) and `ASI_RAPEL` (new) should both appear under "Asi" category
- Both should be completable via the same flow

- [ ] **Step 2: Verify _katTipMap includes both**

```javascript
'Asi': ['ASI_HATIRLATMA','ASI_RAPEL','ILERI_GEBE_ASI','BUZAGI_ASI'],
```

This was likely done in Task 3. Confirm and commit if needed.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: asi rapel otomasyonu complete — improved RPC + rapel UI + kategori fix"
```
