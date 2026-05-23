# Repeat Breed Badge — View Tabanlı Implementasyon

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement this plan task-by-task.

**Goal:** Repeat breed tespitini frontend'den (buildRepeatMap) backend view'a taşıyıp, hayvan kartında 🔁 amber (aktif) / ↻ gri (geçmiş) badge'leri göstermek.
**Durum:** ✅ Uygulandı — 2026-05-23 (commit `752d39a`)

**Architecture:** `hayvan_durum_view`'a yeni CTE eklenir: son 15 gün içindeki tohumlama sayısına göre `repeat_breed_active` ve `repeat_breed_past` boolean kolonları hesaplanır. Frontend'de `buildRepeatMap()` komple kalkar, `_animalTagsHtml` doğrudan hayvan nesnesindeki bu iki alanı okur.

**Tech Stack:** PostgreSQL view, Vanilla JS (ui.js), GitHub Pages deploy

---

## Tasarım Kararları

### Backend Mantığı (View CTE)

```sql
repeat_breed AS (
  SELECT
    hayvan_id,
    COUNT(*) AS repeat_adet  -- sadece sayı, aktif/past ayrımı aşağıda
  FROM public.tohumlama
  WHERE tarih >= CURRENT_DATE - 15
  GROUP BY hayvan_id
)
```

Neden 15 gün? Çiftliklerde tohumlama döngüsü ~21 gün. 15 günlük pencere tek bir cycle'a denk gelir, fazla kaydı almaz.

### İki Boolean Alan

Aktif/past ayrımı CTE'de değil, final SELECT'te `son_tohumlama.toh_sonuc` (zaten var olan son kayıt durumu) ile yapılır:

| Alan | Koşul | Badge |
|------|-------|-------|
| `repeat_breed_active` | `repeat_adet >= 2 AND toh_sonuc = 'Bekliyor'` | 🔁 amber |
| `repeat_breed_past` | `repeat_adet >= 2 AND toh_sonuc ≠ 'Bekliyor'` | ↻ gri |

İkisi de true olabilir → iki badge yan yana gösterilir.

### Frontend Değişikliği

`globalThis._repeatMap` ve `buildRepeatMap()` tamamen kalkar. `_animalTagsHtml` içinde:
```js
const _aktif = a.repeat_breed_active;
const _gecmis = a.repeat_breed_past;
if (_aktif) badge += amber 🔁;
if (_gecmis) badge += gri ↻;
```

`hayvan_durum_view` zaten `pullTables('hayvanlar')` ile çekilir → kolonlar otomatik gelir, `api.js` değişmez.

---

## Migration Dosyası

**Yeni:** `supabase/migrations/20260523000001_repeat_breed_view.sql`

```sql
BEGIN;

-- tohumlanabilir_hayvanlar hayvan_durum_view'a bağımlı
DROP VIEW IF EXISTS public.tohumlanabilir_hayvanlar CASCADE;
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;

CREATE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id, h.kupe_no, h.devlet_kupe, h.irk, h.cinsiyet,
    h.dogum_tarihi, h.grup, h.padok_id,
    COALESCE(pk.ad, h.padok) AS padok,
    h.durum, h.anne_id, h.kategori,
    h.tohumlama_durumu, h.tohumlama_onay_tarihi,
    h.suttten_kesme_tarihi, h.cikis_tipi, h.cikis_tarihi,
    h.cikis_sebebi, h.satis_fiyati, h.notlar,
    h.dogum_kg, h.canli_agirlik, h.boy, h.renk,
    h.ayirici_ozellik, h.baba_bilgi, h.abort_sayisi,
    CASE
      WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.padoklar pk ON pk.id = h.padok_id
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id,
    id    AS toh_id,
    tarih AS toh_tarih,
    sperma,
    sonuc AS toh_sonuc,
    (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log
  WHERE durum = 'Aktif'
  GROUP BY hayvan_id
),
-- ═══ YENİ CTE: repeat breed analizi ═══
-- Sadece son 15 gündeki tohumlama sayısı. Aktif/past ayrımı
-- final SELECT'te son_tohumlama.toh_sonuc ile yapılır (son kaydın durumu).
repeat_breed AS (
  SELECT
    hayvan_id,
    COUNT(*) AS repeat_adet
  FROM public.tohumlama
  WHERE tarih >= CURRENT_DATE - 15
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id, st.toh_tarih, st.sperma, st.toh_sonuc, st.toh_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,
  CASE
    WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 181 AND 365 THEN 'duve_kucuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 366 AND 730 THEN 'duve_buyuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun > 730 THEN 'sagmal'
    ELSE 'genel'
  END AS hesap_kategori,
  CASE
    WHEN y.cinsiyet = 'Dişi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (st.toh_sonuc IS NULL OR st.toh_sonuc = 'Boş')
    THEN true
    ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun BETWEEN 76 AND 180
    THEN true
    ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true
    ELSE false
  END AS dogum_yaklasti,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280
    ELSE 0
  END AS dogum_gecikme_gun,
  CASE
    WHEN st.toh_sonuc = 'Gebe' THEN 'gebe'
    WHEN st.toh_sonuc = 'Bekliyor' THEN 'bekliyor'
    WHEN y.yas_gun >= y.tohumlama_esik_gun AND y.cinsiyet = 'Dişi' THEN 'tohumlanabilir'
    ELSE 'erken'
  END AS tohumlama_durumu_hesap,
  -- ═══ YENİ KOLONLAR ═══
  -- Aktif: son 15g 2+ tohumlama VE son kaydın sonucu Bekliyor
  -- Geçmiş: son 15g 2+ tohumlama VE son kaydın sonucu Bekliyor DEĞİL
  COALESCE(rb.repeat_adet >= 2 AND st.toh_sonuc = 'Bekliyor', false) AS repeat_breed_active,
  COALESCE(rb.repeat_adet >= 2 AND st.toh_sonuc IS DISTINCT FROM 'Bekliyor', false) AS repeat_breed_past
FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id
LEFT JOIN repeat_breed rb ON rb.hayvan_id = y.id;

GRANT SELECT ON public.hayvan_durum_view TO anon, authenticated;

-- tohumlanabilir_hayvanlar view'ı yeniden oluştur (yeni kolonlar eklendi)
CREATE VIEW public.tohumlanabilir_hayvanlar AS
SELECT id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
  grup, padok_id, padok, durum, anne_id, kategori,
  tohumlama_durumu, tohumlama_onay_tarihi, suttten_kesme_tarihi,
  cikis_tipi, cikis_tarihi, cikis_sebebi, satis_fiyati, notlar,
  dogum_kg, canli_agirlik, boy, renk, ayirici_ozellik, baba_bilgi, abort_sayisi,
  yas_gun, tohumlama_esik_gun,
  toh_id, toh_tarih, sperma, toh_sonuc, toh_gun,
  aktif_hastalik_sayisi, hesap_kategori,
  tohumlama_bildirisi_gerekli, suttten_kesme_bildirisi_gerekli,
  dogum_yaklasti, dogum_gecikme_gun, tohumlama_durumu_hesap,
  repeat_breed_active, repeat_breed_past
FROM hayvan_durum_view
WHERE tohumlama_durumu_hesap = 'tohumlanabilir';

GRANT SELECT ON public.tohumlanabilir_hayvanlar TO anon, authenticated;

COMMIT;
```

---

### Task 1: Migration dosyasını oluştur

**Files:**
- Create: `supabase/migrations/20260523000001_repeat_breed_view.sql`

**Step 1:** Yukarıdaki migration içeriğini dosyaya yaz.

**Step 2: Commit**

```bash
git add supabase/migrations/20260523000001_repeat_breed_view.sql
git commit -m "feat: add repeat_breed_active/past columns to hayvan_durum_view"
```

---

### Task 2: UI'dan buildRepeatMap()'i kaldır

**Files:**
- Modify: `js/ui.js:545-560` (buildRepeatMap bloğu)

**Step 1:** `loadAnimals()` içindeki şu bloğu komple sil:
```js
// Repeat breed haritası — cycle bazında max deneme_no
const allToh=await getData('tohumlama');
globalThis._repeatMap={};
allToh.sort((a,b)=>...);
for(const t of allToh){ ... }
```

**Step 2:** `_animalTagsHtml`'deki repeatBadge render kodunu güncelle:
Eski:
```js
const _repeatE=(globalThis._repeatMap||{})[a.id];
let repeatBadge='';
if(_repeatE){
  if(_repeatE.currentMax>=2){
    repeatBadge=`<span class="repeat-badge amber">🔁 ${_repeatE.currentMax}x Aşım</span>`;
  } else if(_repeatE.pastMax>=2){
    repeatBadge=`<span class="repeat-badge green">🔁 ${_repeatE.pastMax}x Aşım</span>`;
  }
}
```

Yeni:
```js
let repeatBadge='';
if(a.repeat_breed_active){
  repeatBadge+=`<span class="repeat-badge active">🔁 Tekrar Aşım</span>`;
}
if(a.repeat_breed_past){
  repeatBadge+=`<span class="repeat-badge past">↻ Tekrar</span>`;
}
```

**Step 3:** İlgili CSS sınıflarını güncelle (`index.html`):
Eski `.repeat-badge.amber` ve `.repeat-badge.green` yerine:
```css
.repeat-badge{display:inline-block;font-size:.58rem;font-weight:700;padding:2px 7px;border-radius:6px;margin-left:2px}
.repeat-badge.active{background:rgba(201,125,10,.15);color:#c97d0a}
.repeat-badge.past{background:rgba(107,122,92,.15);color:var(--ink3)}
```

**Step 4: Commit**

```bash
git add js/ui.js index.html
git commit -m "refactor: replace buildRepeatMap with view columns repeat_breed_active/past"
```

---

### Task 3: Deploy migration + push

**Step 1:** Supabase'e migration'ı deploy et:
```bash
# supabase_migrate MCP tool ile
mcp_tools--bank_supabase_migrate({sql: file content})
```

**Step 2:** Git push:
```bash
git push origin main
```

---

### Task 4: Doğrulama

**Step 1:** `hayvan_durum_view`'dan veri çek:
```sql
SELECT id, kupe_no, repeat_breed_active, repeat_breed_past
FROM hayvan_durum_view
WHERE repeat_breed_active OR repeat_breed_past
LIMIT 20;
```

**Step 2:** 195 nolu hayvanı kontrol et:
```sql
SELECT toh.tarih, toh.sonuc, toh.deneme_no
FROM tohumlama toh
JOIN hayvanlar h ON h.id = toh.hayvan_id
WHERE h.kupe_no = '195'
  AND toh.tarih >= CURRENT_DATE - 15
ORDER BY toh.tarih;
```

**Step 3:** Frontend'de sürü sayfasını aç, badge'lerin doğru renkte göründüğünü kontrol et.

---

### Rollback Plan

Migration'ı geri almak:
```sql
DROP VIEW IF EXISTS public.tohumlanabilir_hayvanlar CASCADE;
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;
-- Sonra bir önceki view versiyonunu geri yükle (mevcut 20260511000001_padoklar.sql'deki)
```

Frontend değişikliklerini geri almak:
```bash
git revert HEAD~1
```
