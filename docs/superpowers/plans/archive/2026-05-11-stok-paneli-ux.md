> **✅ TAMAMLANDI** — Commit: `66ece4b` (feat), `2573dad` (fix: stok_hareket kaydı + arama barı), `fa0f0b2` (fix: miktar negatif). Tab-based navigation, product detail modal, stok_duzelt RPC, arsivle, arama barı çalışıyor.

# Stok Paneli UX Iyilestirme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tab-based navigation, product editing/deletion, and stock correction to the existing stok panel.

**Architecture:** Convert existing grouped list layout to tabbed UI. Add product detail modal for editing/archiving. Stock correction creates a stok_hareket record. No DB schema changes needed — only frontend + one small RPC for stock correction.

**Tech Stack:** Vanilla JS, existing stok/stok_hareket tables, IDB sync, existing modal patterns.

---

## Current State

- `loadStokPanel()` in `js/ui.js:1507` renders ALL products in a grouped vertical scroll
- Groups: Saglik (Sperma, Antibiyotik, NSAID, Hormon, etc.), Asilar, Yem
- Each product card shows: name, category, current stock, progress bar, "+ Miktar Ekle" and "Hareketler" buttons
- No edit/delete capability for products
- No tab navigation — everything in one scroll
- Stock correction not possible (only manual "Miktar Ekle")

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `supabase/migrations/20260511000005_stok_duzelt.sql` | Create | stok_duzelt RPC for stock correction |
| `js/ui.js` | Modify | Tab navigation, product detail modal, stock correction UI |
| `index.html` | Modify | Product detail modal (m-stok-det), tab bar in stok-panel |

---

### Task 1: DB — Stock correction RPC

**Files:**
- Create: `supabase/migrations/20260511000005_stok_duzelt.sql`

- [ ] **Step 1: Write the RPC**

```sql
BEGIN;

CREATE OR REPLACE FUNCTION public.stok_duzelt(
  p_stok_id text,
  p_yeni_miktar numeric,
  p_not text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_guncel numeric;
  v_fark numeric;
BEGIN
  SELECT * INTO v_stok FROM stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadi');
  END IF;

  SELECT COALESCE(v_stok.baslangic_miktar, 0) - COALESCE(SUM(sh.miktar), 0)
  INTO v_guncel
  FROM stok_hareket sh
  WHERE sh.stok_id = p_stok_id AND NOT sh.iptal;

  v_fark := v_guncel - p_yeni_miktar;

  IF v_fark = 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Miktar zaten ayni');
  END IF;

  INSERT INTO stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi)
  VALUES (p_stok_id, 'Duzeltme', v_fark, COALESCE(p_not, 'Sayim duzeltmesi'), false, 'duzeltme');

  RETURN jsonb_build_object('ok', true, 'eski', v_guncel, 'yeni', p_yeni_miktar, 'fark', v_fark);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stok_duzelt(text, numeric, text) TO anon, authenticated;

END;
```

- [ ] **Step 2: Deploy via supabase_migrate**

- [ ] **Step 3: Save file + commit**

```bash
git add supabase/migrations/20260511000005_stok_duzelt.sql
git commit -m "migration: stok_duzelt RPC for stock count correction"
```

---

### Task 2: Index.html — Product detail modal + tab bar

**Files:**
- Modify: `index.html`

- [ ] **Step 1: Add tab bar to stok-panel**

Find the stok-panel element in index.html. Inside it, before `stok-panel-body`, add a tab bar:

```html
<div id="stok-tabs" style="display:flex;gap:4px;padding:8px 12px;overflow-x:auto;-webkit-overflow-scrolling:touch">
  <button class="kat-btn on" onclick="setStokTab('tumu')">Tumu</button>
  <button class="kat-btn" onclick="setStokTab('ilac')">Ilac</button>
  <button class="kat-btn" onclick="setStokTab('asi')">Asi</button>
  <button class="kat-btn" onclick="setStokTab('sperma')">Sperma</button>
  <button class="kat-btn" onclick="setStokTab('diger')">Diger</button>
</div>
```

This reuses the `.kat-btn` CSS class from the task kategori bar (Spec 1).

- [ ] **Step 2: Add product detail modal**

Add before the closing body tag (alongside other modals):

```html
<div id="m-stok-det" class="mo" onclick="mClose(event,this)">
  <div class="modal" style="max-width:380px">
    <div class="mh">
      <h3 id="stok-det-title">Urun Detay</h3>
      <button class="mc" onclick="closeM('m-stok-det')">×</button>
    </div>
    <div class="mb" style="padding:12px 16px">
      <label style="font-size:.7rem;color:var(--ink3)">Urun Adi</label>
      <input id="sd-ad" style="width:100%;padding:8px;border:1px solid var(--brd);border-radius:8px;margin-bottom:8px">
      <label style="font-size:.7rem;color:var(--ink3)">Kategori</label>
      <select id="sd-kat" style="width:100%;padding:8px;border:1px solid var(--brd);border-radius:8px;margin-bottom:8px">
        <option>Antibiyotik</option><option>NSAID</option><option>Hormon</option>
        <option>Vitamin</option><option>Antiparaziter</option><option>Sperma</option>
        <option>Asi</option><option>Yem</option><option>Sarf</option><option>Ekipman</option>
        <option>Diger Ilac</option><option>Diger</option>
      </select>
      <label style="font-size:.7rem;color:var(--ink3)">Birim</label>
      <select id="sd-birim" style="width:100%;padding:8px;border:1px solid var(--brd);border-radius:8px;margin-bottom:8px">
        <option>ml</option><option>adet</option><option>gr</option><option>kg</option><option>doz</option>
      </select>
      <label style="font-size:.7rem;color:var(--ink3)">Kritik Esik</label>
      <input id="sd-esik" type="number" style="width:100%;padding:8px;border:1px solid var(--brd);border-radius:8px;margin-bottom:8px">

      <div style="background:var(--card2);border-radius:8px;padding:10px;margin-bottom:8px">
        <div style="font-size:.7rem;color:var(--ink3)">Mevcut Stok</div>
        <div id="sd-guncel" style="font-size:1.2rem;font-weight:700;color:var(--ink)">—</div>
      </div>

      <div style="background:var(--card2);border-radius:8px;padding:10px;margin-bottom:12px">
        <div style="font-size:.7rem;color:var(--ink3);margin-bottom:4px">Stok Duzelt (sayim sonrasi)</div>
        <div style="display:flex;gap:6px">
          <input id="sd-yeni-miktar" type="number" placeholder="Gercek miktar" style="flex:1;padding:8px;border:1px solid var(--brd);border-radius:8px">
          <button onclick="stokDuzeltKaydet()" class="btn btn-g" style="padding:8px 14px;font-size:.75rem">Duzelt</button>
        </div>
      </div>

      <div style="display:flex;gap:8px">
        <button onclick="stokDetKaydet()" class="btn btn-g" style="flex:1">Kaydet</button>
        <button onclick="stokDetArsivle()" class="btn" style="flex:1;background:var(--red);color:#fff">Arsivle</button>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: stok panel tab bar + product detail modal"
```

---

### Task 3: UI.js — Tab navigation

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: Add tab state and filter logic**

Add near the top of ui.js (with other state variables):

```javascript
let _stokTab = 'tumu';
```

Add the tab switch function:

```javascript
function setStokTab(tab){
  _stokTab=tab;
  document.querySelectorAll('#stok-tabs .kat-btn').forEach(b=>b.classList.remove('on'));
  event.target.classList.add('on');
  loadStokPanel();
}
```

- [ ] **Step 2: Update loadStokPanel to filter by tab**

In `loadStokPanel()` (line 1507), after `const stok=getState('stock')`, add a filter:

```javascript
const TAB_FILTER = {
  tumu: () => true,
  ilac: s => ['Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diger Ilac'].includes(s.kategori),
  asi: s => s.isVaccine || s.kategori === 'Asi',
  sperma: s => s.kategori === 'Sperma',
  diger: s => ['Yem','Sarf','Ekipman','Diger'].includes(s.kategori)
};
const filteredStok = stok.filter(TAB_FILTER[_stokTab] || TAB_FILTER.tumu);
```

Then use `filteredStok` instead of `stok` in the rendering loop. The existing GRUPLAR structure can remain — it will just filter down to fewer items per tab.

**IMPORTANT:** The kategori values in TAB_FILTER must match the EXACT values stored in `stok.kategori`. Verify with:
```javascript
console.log([...new Set(stok.map(s=>s.kategori))]);
```

Adjust filter values if they use Turkish characters (e.g., 'Diğer İlaç' not 'Diger Ilac').

- [ ] **Step 3: Add product card edit button**

In the product card rendering (around line 1566), add an edit button alongside existing buttons:

```javascript
`<button onclick="openStokDet('${s.id}')" style="padding:6px 10px;background:var(--card2);color:var(--ink3);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">Duzenle</button>`
```

Add it in the button row `<div style="display:flex;gap:6px;margin-top:8px">` section.

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat: stok panel tab navigation with category filtering"
```

---

### Task 4: UI.js — Product detail modal functions

**Files:**
- Modify: `js/ui.js`

- [ ] **Step 1: openStokDet function**

```javascript
let _curStokDet = null;

async function openStokDet(stokId){
  const stoklar = await getData('stok');
  const s = stoklar.find(x => x.id === stokId);
  if(!s) return;
  _curStokDet = s;
  g('stok-det-title').textContent = s.urun_adi;
  g('sd-ad').value = s.urun_adi || '';
  g('sd-kat').value = s.kategori || '';
  g('sd-birim').value = s.birim || 'adet';
  g('sd-esik').value = s.esik || '';
  g('sd-guncel').textContent = (s.guncel || 0) + ' ' + (s.birim || '');
  g('sd-yeni-miktar').value = '';
  openM('m-stok-det');
}
```

- [ ] **Step 2: Save product details**

```javascript
async function stokDetKaydet(){
  if(!_curStokDet) return;
  const updates = {
    urun_adi: v('sd-ad').trim(),
    kategori: v('sd-kat'),
    birim: v('sd-birim'),
    esik: parseFloat(v('sd-esik')) || 0
  };
  if(!updates.urun_adi){ toast('Urun adi bos olamaz'); return; }
  const{error} = await db.from('stok').update(updates).eq('id', _curStokDet.id);
  if(error){ toast('Hata: ' + error.message); return; }
  await pullTables(['stok']);
  closeM('m-stok-det');
  loadStokPanel();
  toast('Urun guncellendi');
}
```

- [ ] **Step 3: Archive product**

```javascript
async function stokDetArsivle(){
  if(!_curStokDet) return;
  const hareketler = await getData('stok_hareket');
  const count = hareketler.filter(h => h.stok_id === _curStokDet.id && !h.iptal).length;
  const msg = count > 0
    ? `Bu urunde ${count} hareket kaydi var. Arsivlenecek (silinmeyecek). Devam?`
    : 'Bu urunu arsivlemek istediginizden emin misiniz?';
  openConfirm('Urun Arsivle', msg, async () => {
    const{error} = await db.from('stok').update({kategori: 'Arsiv'}).eq('id', _curStokDet.id);
    if(error){ toast('Hata: ' + error.message); return; }
    await pullTables(['stok']);
    closeM('m-stok-det');
    loadStokPanel();
    toast('Urun arsivlendi');
  });
}
```

Note: We archive by setting `kategori='Arsiv'` rather than deleting, since stok_hareket records reference the stok_id. Archived products don't appear in TAB_FILTER since 'Arsiv' isn't in any tab filter.

- [ ] **Step 4: Stock correction function**

```javascript
async function stokDuzeltKaydet(){
  if(!_curStokDet) return;
  const yeni = parseFloat(v('sd-yeni-miktar'));
  if(isNaN(yeni) || yeni < 0){ toast('Gecerli bir miktar girin'); return; }
  const res = await rpc('stok_duzelt', { p_stok_id: _curStokDet.id, p_yeni_miktar: yeni });
  if(!res.ok){ toast(res.mesaj || 'Hata'); return; }
  await pullTables(['stok', 'stok_hareket']);
  g('sd-guncel').textContent = yeni + ' ' + (_curStokDet.birim || '');
  g('sd-yeni-miktar').value = '';
  toast('Stok duzeltildi: ' + res.eski + ' → ' + res.yeni);
}
```

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "feat: stok product detail modal — edit, archive, stock correction"
```

---

### Task 5: Final integration + test

**Files:** No new files — verification and cleanup.

- [ ] **Step 1: Verify all tab filters work**

Open the app → Stok paneli:
1. "Tumu" tab → all products visible
2. "Ilac" tab → only Antibiyotik, NSAID, Hormon, Vitamin, Antiparaziter, Diger Ilac
3. "Asi" tab → only vaccine products
4. "Sperma" tab → only sperma products
5. "Diger" tab → Yem, Sarf, Ekipman

- [ ] **Step 2: Verify product edit flow**

1. Click "Duzenle" on a product → modal opens with correct values
2. Change name → Kaydet → panel refreshes with new name
3. Change category → product moves to correct tab

- [ ] **Step 3: Verify stock correction**

1. Open product detail → current stock shown
2. Enter correction amount → Duzelt → stock updated
3. Check stok_hareket → new "Duzeltme" record exists

- [ ] **Step 4: Verify archive**

1. Open product → Arsivle → confirm
2. Product disappears from all tabs
3. stok_hareket records preserved

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: stok paneli UX complete — tabs, product edit, correction, archive"
```
