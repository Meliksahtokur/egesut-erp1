> **✅ TAMAMLANDI** — Tüm implementasyon commit'leri: `dcd3b6b` (feat), `72d1af6` (fix), `b4f1fe9` (fix). İleri gebe aşı tamamlama → vaccination_log + stok düşme + 21 gün rapel görevi otomasyonu çalışıyor.

# İleri Gebe Aşı Tamamlama + Rapel Otomasyonu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ILERI_GEBE_ASI` görev tamamlama → vaccination_log + stok düşme + 21 gün rapel görevi otomasyonu.

**Architecture:** `ileri_gebe_gorev_kontrol` RPC'si `stok_id` ve `gorev_tipi='ILERI_GEBE_ASI'` ile görev oluşturur. Yeni `ileri_gebe_asi_tamamla` RPC atomik olarak `add_vaccination` + gorev tamamlama + rapel gorev oluşturma yapar. Frontend `openTaskDet()` ILERI_GEBE_ASI tipini tespit eder, mini form gösterir, rapel görevi için date picker sunar.

**Tech Stack:** PostgreSQL (Supabase), Vanilla JS (ui.js/api.js), HTML modal

---

### Task 1: Migration — `ileri_gebe_gorev_kontrol` Güncelle

**Files:**
- Create: `supabase/migrations/20260509000002_ileri_gebe_asi_gorev_update.sql`

Mevcut migration (`20260509000001_ileri_gebe_gorev.sql`) 1. doz görevini `gorev_tipi='ILERI_GEBE'` ve `stok_id=NULL` ile oluşturuyor. Bunları `gorev_tipi='ILERI_GEBE_ASI'` + `stok_id` olarak düzeltmemiz gerekiyor.

- [ ] **Step 1: Migration dosyasını yaz**

```sql
-- Migration: ileri_gebe_gorev_kontrol — ILERI_GEBE_ASI tipi + stok_id
-- Etkiler:
--   1. ileri_gebe_gorev_kontrol: 1. doz Rota-Corona görevini ILERI_GEBE_ASI tipiyle + stok_id ile oluşturur
--   2. Mevcut ILERI_GEBE tipindeki Rota-Corona görevlerini günceller (henüz tamamlanmamış)
-- Geri alınabilir: evet — gorev_tipi'yi tekrar ILERI_GEBE yaparak

BEGIN;

-- 1. Mevcut tamamlanmamış 1. doz görevlerini güncelle
UPDATE gorev_log
SET
  gorev_tipi = 'ILERI_GEBE_ASI',
  stok_id    = (
    SELECT v.stock_item_id FROM vaccines v
    WHERE v.name ILIKE '%Rota%' LIMIT 1
  ),
  miktar     = 1
WHERE gorev_tipi = 'ILERI_GEBE'
  AND aciklama ILIKE '%Rota-Corona%1. doz%'
  AND tamamlandi = false;

-- 2. ileri_gebe_gorev_kontrol — 1. doz bloğunu ILERI_GEBE_ASI + stok_id ile güncelle
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_stok_id     text;
BEGIN
  -- Rota-Corona aşısının stock_item_id'sini bul
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v
  WHERE v.name ILIKE '%Rota%'
  LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- 240. gün: Rota-Corona 1. doz (tüm gebeler) — ILERI_GEBE_ASI tipi + stok_id
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (sadece düveler) — ILERI_GEBE_ASI tipi + stok_id
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin (tüm gebeler) — ILERI_GEBE tipi (ilaç, aşı değil)
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: IM E Vitamini (tüm gebeler) — ILERI_GEBE tipi (ilaç, aşı değil)
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
```

Dosya yolu: `supabase/migrations/20260509000002_ileri_gebe_asi_gorev_update.sql`

- [ ] **Step 2: Migration'ı Supabase'e uygula**

```bash
cd /root/egesut-erp1
cat supabase/migrations/20260509000002_ileri_gebe_asi_gorev_update.sql | python3 - << 'PYEOF'
import urllib.request, json, os
url = "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/exec_sql"
# Migration'ı supabase_migrate MCP tool ile uygula
PYEOF
```

MCP tool kullan: `supabase_migrate` ile SQL içeriğini gönder.

- [ ] **Step 3: Doğrula**

Supabase'de çalıştır:
```sql
SELECT gorev_tipi, stok_id, COUNT(*) 
FROM gorev_log 
WHERE aciklama ILIKE '%Rota-Corona%'
GROUP BY gorev_tipi, stok_id;
```

Beklenen: `gorev_tipi = 'ILERI_GEBE_ASI'`, `stok_id IS NOT NULL`.

- [ ] **Step 4: Commit**

```bash
cd /root/egesut-erp1
git add supabase/migrations/20260509000002_ileri_gebe_asi_gorev_update.sql
git commit -m "migration: ileri_gebe_gorev_kontrol — ILERI_GEBE_ASI tipi + stok_id"
git push
```

---

### Task 2: Migration — `ileri_gebe_asi_tamamla` RPC

**Files:**
- Create: `supabase/migrations/20260509000003_ileri_gebe_asi_tamamla.sql`

Bu RPC: gorev_log'u doğrular → `add_vaccination` çağırır (vaccination_log + stok trigger) → görevi tamamlar → 1. doz ise 21 gün sonraya rapel görevi oluşturur.

- [ ] **Step 1: Migration dosyasını yaz**

```sql
-- Migration: ileri_gebe_asi_tamamla RPC
-- Etkiler:
--   1. Yeni RPC: ileri_gebe_asi_tamamla — aşı kayıt + gorev tamamlama + rapel oluşturma
-- Bağımlılık: add_vaccination RPC (20260331000032_vaccination_module.sql)
-- Geri alınabilir: DROP FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric);

BEGIN;

CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(
  p_gorev_id   text,
  p_vaccine_id uuid,
  p_tarih      date    DEFAULT CURRENT_DATE,
  p_doz        numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_result  jsonb;
  v_rapel_id    text;
  v_rapel_tarih date;
  v_is_first    boolean;
BEGIN
  -- 1. Görevi çek ve kontrol et
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  -- 2. Aşıyı kaydet (add_vaccination → vaccination_log + stok trigger)
  SELECT public.add_vaccination(
    v_gorev.hayvan_id, p_vaccine_id, p_tarih, p_doz, 'GorevID:' || p_gorev_id
  ) INTO v_vax_result;

  IF (v_vax_result->>'ok')::boolean = false THEN
    RETURN v_vax_result;
  END IF;

  -- 3. Görevi tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id;

  -- 4. 1. doz ise rapel görevi oluştur (21 gün sonra)
  v_is_first := v_gorev.aciklama ILIKE '%1. doz%';
  IF v_is_first THEN
    v_rapel_tarih := p_tarih + 21;
    v_rapel_id := gen_random_uuid()::text;
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak)
    VALUES (
      v_rapel_id,
      v_gorev.hayvan_id,
      'ILERI_GEBE_ASI',
      '💉 Rota-Corona Aşısı (2. doz)',
      v_rapel_tarih,
      false,
      v_gorev.stok_id,
      1,
      p_gorev_id,
      'ILERI_GEBE'
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_vax_result->>'vaccination_id',
    'rapel_gorev_id', v_rapel_id,
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric) TO anon, authenticated;

END;
```

Dosya yolu: `supabase/migrations/20260509000003_ileri_gebe_asi_tamamla.sql`

- [ ] **Step 2: Migration'ı uygula**

`supabase_migrate` MCP tool ile SQL'i çalıştır.

- [ ] **Step 3: RPC'yi test et**

Supabase'de çalıştır (gerçek bir ILERI_GEBE_ASI görevi seç):
```sql
-- Önce test görevi ID'sini bul
SELECT id, hayvan_id, aciklama, stok_id, gorev_tipi 
FROM gorev_log 
WHERE gorev_tipi = 'ILERI_GEBE_ASI' AND tamamlandi = false 
LIMIT 1;

-- Test RPC (hayvan_id ve vaccine_id uygun olmalı — sadece test, rollback istersen)
-- SELECT public.ileri_gebe_asi_tamamla('<gorev_id>', '<vaccine_id>');
```

Çıktı `{"ok": true, ...}` olmalı.

- [ ] **Step 4: Commit**

```bash
cd /root/egesut-erp1
git add supabase/migrations/20260509000003_ileri_gebe_asi_tamamla.sql
git commit -m "migration: ileri_gebe_asi_tamamla RPC — vaccination + rapel otomasyon"
git push
```

---

### Task 3: api.js — rpcInvalidate Listesi Güncelle

**Files:**
- Modify: `js/api.js` ~234

`ileri_gebe_asi_tamamla` RPC çağrıldıktan sonra vaccination_log, gorev_log, stok_hareket cache'leri invalidate edilmeli.

- [ ] **Step 1: rpcInvalidate'e ekle**

`js/api.js` satır 234'teki `bulk_ilac` satırından sonra:

```js
// Mevcut:
  bulk_ilac:                  ['islem_log','stok','stok_hareket'],

// Eklenecek (sonrasına):
  ileri_gebe_asi_tamamla:    ['vaccination_log','gorev_log','stok_hareket'],
```

- [ ] **Step 2: Commit**

```bash
cd /root/egesut-erp1
git add js/api.js
git commit -m "api: ileri_gebe_asi_tamamla rpcInvalidate listesine eklendi"
git push
```

---

### Task 4: index.html — Mini Form + Rapel Date Picker

**Files:**
- Modify: `index.html` — `#m-task-det` modal içine `#td-asi-form` ve `#td-rapel-form` div'leri ekle

Mevcut modal yapısı (satır 1118-1132):
```html
<div id="m-task-det" class="mo" ...>
  <div class="modal">...
    <div id="td-header">...</div>
    <div id="td-subs">...</div>
    <div class="m-body">
      <button id="td-tamam-btn">✅ Tamamlandı Olarak İşaretle</button>
      <button ...>🗑 Görevi İptal Et</button>
      <button ...>Kapat</button>
    </div>
  </div>
</div>
```

- [ ] **Step 1: HTML değişikliği yap**

`index.html` satır 1126-1130 arasındaki `<div class="m-body"...>` bloğunu şu şekilde güncelle:

```html
    <div class="m-body" style="padding-top:10px">
      <!-- ILERI_GEBE_ASI: standart tamamla butonu yerine aşı mini formu -->
      <div id="td-asi-form" style="display:none;background:var(--card2);border-radius:12px;padding:12px 14px;margin-bottom:10px">
        <div style="font-size:.75rem;font-weight:700;color:var(--ink3);margin-bottom:8px">💉 Aşı Uygula</div>
        <div style="margin-bottom:8px">
          <div style="font-size:.7rem;color:var(--ink3);margin-bottom:3px">Aşı</div>
          <div id="td-asi-adi" style="font-size:.85rem;font-weight:600;color:var(--ink)">—</div>
        </div>
        <div style="margin-bottom:8px">
          <label style="font-size:.7rem;color:var(--ink3);display:block;margin-bottom:3px">Tarih</label>
          <input type="date" id="td-asi-tarih" style="width:100%;padding:6px 8px;border-radius:8px;border:1px solid var(--card3);background:var(--bg);color:var(--ink);font-size:.85rem">
        </div>
        <div style="margin-bottom:10px">
          <label style="font-size:.7rem;color:var(--ink3);display:block;margin-bottom:3px">Doz (ml)</label>
          <input type="number" id="td-asi-doz" step="0.5" min="0.5" style="width:100%;padding:6px 8px;border-radius:8px;border:1px solid var(--card3);background:var(--bg);color:var(--ink);font-size:.85rem">
        </div>
        <div style="display:flex;gap:8px">
          <button id="td-asi-uygula-btn" class="btn btn-g" style="flex:1" onclick="asiUygulaVeTamamla()">Uygula ve Tamamla</button>
          <button class="btn btn-o" style="flex:0 0 auto" onclick="document.getElementById('td-asi-form').style.display='none';document.getElementById('td-asi-ac-btn').style.display='block'">İptal</button>
        </div>
      </div>

      <!-- Rapel görevi için tarih güncelleme -->
      <div id="td-rapel-form" style="display:none;background:#fff8e1;border-radius:12px;padding:12px 14px;margin-bottom:10px;border:1px solid #ffe082">
        <div style="font-size:.75rem;font-weight:700;color:#b8860b;margin-bottom:8px">📅 Rapel Tarihi</div>
        <div style="margin-bottom:10px">
          <label style="font-size:.7rem;color:var(--ink3);display:block;margin-bottom:3px">Planlanan tarih (14–21 gün)</label>
          <input type="date" id="td-rapel-tarih" style="width:100%;padding:6px 8px;border-radius:8px;border:1px solid #ffe082;background:var(--bg);color:var(--ink);font-size:.85rem">
        </div>
        <button class="btn btn-g" onclick="rapelTarihiKaydet()" style="background:#f9a825;color:#fff">📅 Tarihi Kaydet</button>
      </div>

      <button id="td-tamam-btn" class="btn btn-g" onclick="detayTamamla()">✅ Tamamlandı Olarak İşaretle</button>
      <button id="td-asi-ac-btn" class="btn btn-g" style="display:none;background:var(--blue,#2196f3)" onclick="asiFormAc()">💉 Aşıyı Uygula</button>
      <button class="btn" style="background:#fff3e0;color:#b84c00;margin-top:6px;border:1px solid #f0b060;font-weight:700" onclick="detayIptal()">🗑 Görevi İptal Et</button>
      <button class="btn btn-o" onclick="closeM('m-task-det')" style="margin-top:6px">Kapat</button>
    </div>
```

- [ ] **Step 2: Commit**

```bash
cd /root/egesut-erp1
git add index.html
git commit -m "html: task det modal — asi mini form + rapel tarih picker"
git push
```

---

### Task 5: ui.js — openTaskDet + asiUygulaVeTamamla + rapelTarihiKaydet

**Files:**
- Modify: `js/ui.js` — `openTaskDet()` + `detayTamamla()` + 2 yeni fonksiyon

`_curTaskVaccineId` global değişken eklenecek (vaccine lookup sonucu saklanır).

- [ ] **Step 1: Global değişken ekle**

`js/ui.js` içinde `_curTaskDet` tanımlandığı yerin yanına (yaklaşık `let _curTaskDet = null;` satırı):

```js
let _curTaskDet = null;
let _curTaskVaccineId = null;  // ILERI_GEBE_ASI için vaccine_id
```

- [ ] **Step 2: openTaskDet() fonksiyonunu güncelle**

Mevcut `openTaskDet` satır 1848-1877'deki fonksiyonun `openM('m-task-det');` satırından önce şunları ekle:

```js
  // Butonları reset et
  const tamamBtn = document.getElementById('td-tamam-btn');
  const asiAcBtn = document.getElementById('td-asi-ac-btn');
  const asiForm  = document.getElementById('td-asi-form');
  const rapelForm= document.getElementById('td-rapel-form');
  if (tamamBtn)  tamamBtn.style.display = 'block';
  if (asiAcBtn)  asiAcBtn.style.display  = 'none';
  if (asiForm)   asiForm.style.display   = 'none';
  if (rapelForm) rapelForm.style.display = 'none';
  _curTaskVaccineId = null;

  // ILERI_GEBE_ASI: standart tamamla gizle, aşı butonu göster
  if (t.gorev_tipi === 'ILERI_GEBE_ASI') {
    if (tamamBtn) tamamBtn.style.display = 'none';
    if (asiAcBtn) asiAcBtn.style.display  = 'block';
    // Vaccine lookup: stok_id → vaccines tablosundan vaccine_id + isim + doz
    try {
      const vaccines = await getData('vaccines');
      const vax = vaccines.find(v => v.stock_item_id === t.stok_id);
      if (vax) {
        _curTaskVaccineId = vax.id;
        document.getElementById('td-asi-adi').textContent = vax.name || 'Rota-Corona';
        const dozEl = document.getElementById('td-asi-doz');
        if (dozEl && vax.dose) dozEl.value = vax.dose;
      }
    } catch(e) { console.warn('vaccine lookup:', e.message); }
    // Tarih alanı default = bugün, max = bugün
    const tarihEl = document.getElementById('td-asi-tarih');
    const todayStr = new Date().toISOString().split('T')[0];
    if (tarihEl) { tarihEl.value = todayStr; tarihEl.max = todayStr; }
  }

  // Rapel görevi: parent_id varsa tarih picker göster
  if (t.parent_id && t.gorev_tipi === 'ILERI_GEBE_ASI') {
    try {
      const allTasks = await idbGetAll('gorev_log');
      const parent = allTasks.find(p => p.id === t.parent_id);
      if (parent && parent.tamamlanma_tarihi) {
        const parentDate = new Date(parent.tamamlanma_tarihi);
        const minDate = new Date(parentDate); minDate.setDate(minDate.getDate() + 14);
        const maxDate = new Date(parentDate); maxDate.setDate(maxDate.getDate() + 21);
        const fmt = d => d.toISOString().split('T')[0];
        const rapelTarihEl = document.getElementById('td-rapel-tarih');
        if (rapelTarihEl) {
          rapelTarihEl.min = fmt(minDate);
          rapelTarihEl.max = fmt(maxDate);
          rapelTarihEl.value = t.hedef_tarih || fmt(maxDate);
        }
        if (rapelForm) rapelForm.style.display = 'block';
      }
    } catch(e) { console.warn('parent lookup:', e.message); }
  }
```

- [ ] **Step 3: asiFormAc() fonksiyonunu ekle**

`detayIptal()` fonksiyonundan önce ekle:

```js
function asiFormAc() {
  document.getElementById('td-asi-form').style.display = 'block';
  document.getElementById('td-asi-ac-btn').style.display = 'none';
}
```

- [ ] **Step 4: asiUygulaVeTamamla() fonksiyonunu ekle**

`asiFormAc()` sonrasına ekle:

```js
async function asiUygulaVeTamamla() {
  if (!_curTaskDet || !_curTaskVaccineId) {
    toast('Aşı bilgisi eksik', true); return;
  }
  const btn = document.getElementById('td-asi-uygula-btn');
  if (btn) { btn.disabled = true; btn.textContent = 'İşleniyor…'; }
  try {
    const tarih = document.getElementById('td-asi-tarih').value || new Date().toISOString().split('T')[0];
    const dozRaw = document.getElementById('td-asi-doz').value;
    const doz = dozRaw ? parseFloat(dozRaw) : null;
    const res = await rpc('ileri_gebe_asi_tamamla', {
      p_gorev_id:   _curTaskDet.id,
      p_vaccine_id: _curTaskVaccineId,
      p_tarih:      tarih,
      p_doz:        doz,
    });
    if (!res.ok) { toast(_trErr(res.mesaj||'Hata'), true); return; }
    closeM('m-task-det');
    updateTaskBadge();
    loadTasks(_curTaskFilter || 'today');
    loadDash();
    const rapelTarih = res.rapel_tarih ? fmtTarih(res.rapel_tarih) : null;
    toast(rapelTarih ? `✅ Aşı kaydedildi · Rapel: ${rapelTarih}` : '✅ Aşı kaydedildi');
  } catch(e) {
    toast(_trErr(e.message), true);
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'Uygula ve Tamamla'; }
  }
}
```

- [ ] **Step 5: rapelTarihiKaydet() fonksiyonunu ekle**

`asiUygulaVeTamamla()` sonrasına ekle:

```js
async function rapelTarihiKaydet() {
  if (!_curTaskDet) return;
  const tarihEl = document.getElementById('td-rapel-tarih');
  const yeniTarih = tarihEl?.value;
  if (!yeniTarih) { toast('Tarih seçin', true); return; }
  try {
    await write('gorev_log', { hedef_tarih: yeniTarih }, 'PATCH', `id=eq.${_curTaskDet.id}`);
    toast('📅 Rapel tarihi güncellendi');
    loadTasks(_curTaskFilter || 'today');
  } catch(e) {
    toast(_trErr(e.message), true);
  }
}
```

- [ ] **Step 6: Commit**

```bash
cd /root/egesut-erp1
git add js/ui.js
git commit -m "ui: openTaskDet ILERI_GEBE_ASI tespiti + asi mini form + rapel date picker"
git push
```

---

### Task 6: Manuel Test — 148 Numaralı Hayvan

148 numaralı hayvanın Rota-Corona aşısı fiziksel olarak yapıldı, sisteme girmeyi kaçırdık. Feature hazır olunca:

- [ ] **Step 1: 148'in görev ID'sini bul**

Uygulamada Görevler sekmesine git → 148'i filtrele veya Supabase'de:
```sql
SELECT id, aciklama, hedef_tarih, stok_id, tamamlandi 
FROM gorev_log 
WHERE hayvan_id = (SELECT id FROM hayvanlar WHERE kupe_no = '148')
  AND gorev_tipi = 'ILERI_GEBE_ASI'
  AND tamamlandi = false;
```

- [ ] **Step 2: Yeni modal ile tamamla**

Uygulamada görevi aç → 💉 Aşıyı Uygula → gerçek uygulama tarihini gir → Uygula ve Tamamla.

Beklenecek: vaccination_log kaydı oluştu, stok düştü, rapel görevi 21 gün sonraya atandı.

- [ ] **Step 3: Doğrula**

```sql
-- vaccination_log kaydı
SELECT * FROM vaccination_log 
WHERE animal_id = (SELECT id FROM hayvanlar WHERE kupe_no = '148')
ORDER BY date DESC LIMIT 3;

-- Stok hareketi
SELECT * FROM stok_hareket 
WHERE stok_id = (SELECT stock_item_id FROM vaccines WHERE name ILIKE '%Rota%')
ORDER BY created_at DESC LIMIT 5;

-- Rapel görevi
SELECT id, aciklama, hedef_tarih, parent_id FROM gorev_log
WHERE hayvan_id = (SELECT id FROM hayvanlar WHERE kupe_no = '148')
  AND aciklama ILIKE '%2. doz%';
```
