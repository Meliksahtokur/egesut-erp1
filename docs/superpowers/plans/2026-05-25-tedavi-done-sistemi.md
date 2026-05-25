# Tedavi Done Sistemi — Implementasyon Planı

> Topoloji: Hierarchical | 4 task | 0 paralel blok
> Model: deepseek-chat (flash) — aksi belirtilmedi
> **DURUM: ✅ TAMAMLANDI — 2026-05-25 | Commit: 400d4bd + 8def478**

**Bilinen küçük eksikler (kritik değil, ileride fix):**
- Done günlerde ✏️/🗑 ilaç butonları gizlenmeli (isDone kontrolü yok)
- Done günlerde 🕐 saat butonu gizlenmeli
- Render sırası: `Object.values(byDay)` day_no'ya göre explicit sort edilmeli

**Hedef:** Vaka modalındaki her tedavi gününe "Tamamla" butonu ekle; sıralı tamamlama zorunlu; tüm günler done olunca vaka kapatılabilir; opsiyonel not.

**Etkilenen dosyalar:**
- `supabase/migrations/99999999999999_ground_truth.sql`
- `supabase/migrations/20260525000002_treatment_day_done.sql` (yeni)
- `js/ui.js` → `renderCaseTimeline()`, `openCaseDet()`

---

## Başlamadan Önce

Sırayla oku:
1. `cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | grep -A 15 "CREATE TABLE.*treatment_days"`
2. `cat /root/egesut-erp1/.claude/rpc-reference.md`
3. `sed -n '2587,2710p' /root/egesut-erp1/js/ui.js`  ← openCaseDet + renderCaseTimeline
4. `sed -n '1338,1362p' /root/egesut-erp1/index.html`  ← m-case-det modal HTML

Sonra planı oku, net olmayan şey varsa sor.

---

## Task 1 — DB: Kolon + RPC Ekle

**Okuma:**
```bash
grep -n "treatment_days\|tamamlandi" /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | head -20
```

**Uygulama:**

Migration dosyası oluştur: `supabase/migrations/20260525000002_treatment_day_done.sql`

```sql
-- treatment_days: done tracking kolonları
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS tamamlandi         boolean     DEFAULT false,
  ADD COLUMN IF NOT EXISTS tamamlanma_tarihi  timestamptz,
  ADD COLUMN IF NOT EXISTS tamamlanma_notu    text;

-- RPC: treatment_day_tamamla
-- Sıralı kontrol: önceki gün done değilse hata fırlatır.
CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id  uuid,
  p_not     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_day     public.treatment_days%ROWTYPE;
  v_onceki  boolean;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;

  IF v_day.tamamlandi THEN
    RAISE EXCEPTION 'Bu tedavi günü zaten tamamlandı';
  END IF;

  -- Sıralı kontrol: aynı vakada day_no daha küçük olan tamamlanmamış var mı?
  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id
      AND day_no  < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;

  IF v_onceki THEN
    RAISE EXCEPTION 'Önceki tedavi günleri tamamlanmadan bu gün tamamlanamaz';
  END IF;

  UPDATE public.treatment_days
  SET tamamlandi        = true,
      tamamlanma_tarihi = now(),
      tamamlanma_notu   = p_not
  WHERE id = p_day_id;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla(uuid, text) TO anon, authenticated;
```

`supabase_migrate({sql: "<yukarıdaki SQL'in tamamı>"})` ile deploy et.

Aynı SQL'i `ground_truth.sql`'e de ekle — treatment_days CREATE TABLE bloğunun hemen altına
(satır ~2726 civarı, `CREATE INDEX IF NOT EXISTS treatment_days_case_id_idx` öncesi):

```sql
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS tamamlandi         boolean     DEFAULT false,
  ADD COLUMN IF NOT EXISTS tamamlanma_tarihi  timestamptz,
  ADD COLUMN IF NOT EXISTS tamamlanma_notu    text;
```

RPC bloğunu da ground_truth.sql'deki diğer RPC'lerin yanına ekle.

**Doğrulama:**
```
supabase_query({table: "treatment_days", select: "id,tamamlandi,tamamlanma_tarihi,tamamlanma_notu", limit: 3})
```
→ `tamamlandi: false` kolonları görünmeli.

**Commit:**
```bash
git add supabase/migrations/20260525000002_treatment_day_done.sql supabase/migrations/99999999999999_ground_truth.sql
git commit -m "feat(treatment): done tracking — tamamlandi kolon + treatment_day_tamamla RPC"
git push origin main
```

---

## Task 2 — JS: renderCaseTimeline — Done State + Tamamla Butonu

**Okuma:**
```bash
sed -n '2627,2705p' /root/egesut-erp1/js/ui.js
```

**Uygulama:**

`renderCaseTimeline` içindeki her gün kartını güncelle. Mevcut kart yapısı:
```js
<div style="border:1px solid var(--card2);border-radius:10px;padding:10px;margin-bottom:8px">
  <div style="display:flex;justify-content:space-between;...">  ← header
    <span>Gün X — tarih ...</span>
    ${aktifse + İlaç + 🗑 Gün butonları}
  </div>
  <div id="drugs-..."> ilaçlar </div>
</div>
```

Değişiklikler:

1. **Kart border/arka plan:** done ise yeşil tint (`rgba(78,154,42,.08)` border `rgba(78,154,42,.3)`), aktif ise mevcut, locked (önceki bitmemiş) ise soluk.

2. **Header sağ taraf (aktif vakada):**
   - Eğer `day.tamamlandi`: `✅ Tamamlandı — ${fmtTarihSaat(day.tamamlanma_tarihi)}` (yeşil badge, buton yok)
   - Eğer tamamlanmamış ama önceki bitmemiş (locked): `🔒` ikonu, soluk renk, buton disabled
   - Eğer tamamlanmamış ve sırası gelmiş (aktif): `[✅ Tamamla]` butonu (yeşil)

3. **Not satırı (done ise):** `tamamlanma_notu` varsa kart altında `📝 "not içeriği"` italic satırı.

4. **Tamamla butonu tıklanınca:** `caseDayTamamla(day.day_id)` çağırır.

Yeni JS kodu yazılacak yerler (`renderCaseTimeline` içi, `el.innerHTML = Object.values(byDay).map(...)` bloğu):

```js
// byDay objesine tamamlandi/tamamlanma_tarihi/tamamlanma_notu ekle
// (allDays'den td objesi çekilirken zaten geliyor — sadece push ederek map'e at)
if (!byDay[r.day_id]) byDay[r.day_id] = {
  day_no: r.day_no, date: r.treatment_date, day_id: r.day_id,
  time: r.treatment_time || '', drugs: [],
  tamamlandi: td.tamamlandi || false,
  tamamlanma_tarihi: td.tamamlanma_tarihi || null,
  tamamlanma_notu: td.tamamlanma_notu || null
};
```

**ÖNEMLİ:** `td` objesi `allDays.find(d => d.id === r.day_id)` ile bulunmalı — `r` objesi üzerinden değil.
Mevcut kodda `days.forEach(td => ...)` döngüsü var, oradan `tamamlandi` alanları `byDay` map'ine taşınmalı.

Sıralı lock hesabı:
```js
// Her gün için: kendinden küçük day_no'lu tüm günler done mu?
const sortedDays = Object.values(byDay).sort((a,b) => a.day_no - b.day_no);
sortedDays.forEach((day, idx) => {
  day._locked = idx > 0 && !sortedDays[idx-1].tamamlandi;
});
```

Kart HTML (template içi — done/locked/aktif durumları):

```js
const isDone   = day.tamamlandi;
const isLocked = !isDone && day._locked;
const canDone  = !isDone && !isLocked && _curCase?.status === 'active';

const cardBorder = isDone
  ? 'border:1px solid rgba(78,154,42,.35);background:rgba(78,154,42,.05)'
  : isLocked
    ? 'border:1px solid var(--card2);opacity:.65'
    : 'border:1px solid var(--card2)';

const rightSide = isDone
  ? `<span style="background:rgba(78,154,42,.12);color:var(--green);padding:3px 9px;border-radius:8px;font-size:.7rem;font-weight:700">✅ ${fmtGunSaat(day.tamamlanma_tarihi)}</span>`
  : isLocked
    ? `<span style="color:var(--ink3);font-size:.75rem">🔒 Önceki bekleniyor</span>`
    : _curCase?.status==='active'
      ? `<div style='display:flex;gap:4px'>
           <button onclick="caseDayTamamlaAc('${day.day_id}')" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:3px 10px;font-size:.7rem;font-weight:700;cursor:pointer">✅ Tamamla</button>
           <button onclick="caseDrugFormAc('${day.day_id}')" style="background:var(--blue);color:#fff;border:none;border-radius:7px;padding:3px 10px;font-size:.7rem;cursor:pointer">+ İlaç</button>
           <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.12);color:var(--red);border:1px solid rgba(192,50,26,.2);border-radius:7px;padding:3px 8px;font-size:.7rem;cursor:pointer">🗑</button>
         </div>`
      : '';

const notSatiri = isDone && day.tamamlanma_notu
  ? `<div style="margin-top:6px;font-size:.72rem;color:var(--ink3);font-style:italic">📝 "${esc(day.tamamlanma_notu)}"</div>`
  : '';
```

**Yeni helper fonksiyon** (`renderCaseTimeline` öncesine ekle):
```js
function fmtGunSaat(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  return d.toLocaleDateString('tr-TR',{day:'2-digit',month:'2-digit'}) + ' ' +
         d.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'});
}
```

**Syntax check:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

---

## Task 3 — JS: caseDayTamamlaAc + caseDayTamamla + Vakayı Kapat Koşulu

**Uygulama:**

`caseDayTamamlaAc(dayId)` — inline not girişi açar (mevcut saat modalı tarzında):

```js
function caseDayTamamlaAc(dayId) {
  let box = document.getElementById('tamamla-modal');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'tamamla-modal';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) box.remove(); };
  box.innerHTML = `
    <div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
      <div style="font-weight:800;font-size:.9rem;margin-bottom:14px">✅ Tedaviyi Tamamla</div>
      <input type="text" id="tamamla-not-inp" placeholder="Not ekle (opsiyonel)"
        style="width:100%;border:1.5px solid var(--card3);border-radius:10px;padding:12px;font-size:.9rem;background:var(--card);color:var(--ink);outline:none;margin-bottom:12px;box-sizing:border-box">
      <div style="display:flex;gap:8px">
        <button onclick="caseDayTamamla('${dayId}')"
          style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">✅ Tamamla</button>
        <button onclick="document.getElementById('tamamla-modal').remove()"
          style="flex:1;padding:12px;background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:10px;font-size:.9rem;cursor:pointer">İptal</button>
      </div>
    </div>`;
  document.body.appendChild(box);
  setTimeout(() => document.getElementById('tamamla-not-inp')?.focus(), 100);
}

async function caseDayTamamla(dayId) {
  const not = document.getElementById('tamamla-not-inp')?.value?.trim() || null;
  try {
    await rpc('treatment_day_tamamla', { p_day_id: dayId, p_not: not });
    document.getElementById('tamamla-modal')?.remove();
    toast('✅ Tedavi tamamlandı');
    await pullTables(['treatment_days']);
    if (_curCase) {
      await renderCaseTimeline(_curCase.id);
      _updateKapatBtn(_curCase.id);  // ← Vakayı Kapat butonunu güncelle
    }
  } catch(e) { toast('❌ ' + e.message, true); }
}
```

**`_updateKapatBtn` — Vakayı Kapat koşul kontrolü:**

```js
async function _updateKapatBtn(caseId) {
  const kapatBolum = document.getElementById('cd-kapat-bolum');
  if (!kapatBolum) return;
  const allDays = await idbGetAll('treatment_days');
  const caseDays = allDays.filter(d => d.case_id === caseId);
  // 0 gün varsa → kapatılabilir (kısıtlama yok)
  // Hepsi done ise → kapatılabilir
  const hepsiDone = caseDays.length === 0 || caseDays.every(d => d.tamamlandi);
  const btn = kapatBolum.querySelector('button');
  if (!btn) return;
  if (hepsiDone) {
    btn.disabled = false;
    btn.style.opacity = '';
    btn.title = '';
  } else {
    const kalan = caseDays.filter(d => !d.tamamlandi).length;
    btn.disabled = true;
    btn.style.opacity = '.45';
    btn.title = `${kalan} tedavi günü tamamlanmadan vaka kapatılamaz`;
  }
}
```

`openCaseDet` fonksiyonunda `openM('m-case-det')` çağrısından **önce** `_updateKapatBtn(c.id)` ekle.

**Syntax check:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

**Commit:**
```bash
git add js/ui.js
git commit -m "feat(treatment): done sistemi — sıralı tamamla butonu, not girişi, vaka kapat koşulu"
git push origin main
```

---

## Task 4 — Doğrulama

Canlı DB'de test et:

```
supabase_rpc({function_name: "treatment_day_tamamla", params: '{"p_day_id":"<ilk_gun_id>","p_not":"Test notu"}'})
```
→ `{"ok": true, "day_id": "..."}` beklenir.

İkinci günü birinci bitmeden done etmeye çalış:
```
supabase_rpc({function_name: "treatment_day_tamamla", params: '{"p_day_id":"<ikinci_gun_id>"}'})
```
→ `"Önceki tedavi günleri tamamlanmadan..."` hatası beklenir.

IDB cache güncellendi mi kontrol:
```
supabase_query({table: "treatment_days", filters: "case_id=eq.<test_case_id>", select: "id,day_no,tamamlandi,tamamlanma_tarihi", limit: 10})
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "treatment_day done sistemi: tamamlandi+tamamlanma_tarihi+tamamlanma_notu kolonları eklendi. treatment_day_tamamla RPC sıralı kontrol yapar (önceki bitmeden sonraki done edilemez). _updateKapatBtn ile Vakayı Kapat butonu dinamik enable/disable. caseDayTamamlaAc inline modal ile not alır.",
  category: "code_change",
  priority: "medium",
  tags: "treatment,done,rpc,ui.js"
})
```
