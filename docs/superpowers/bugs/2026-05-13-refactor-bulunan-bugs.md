# Pre-Existing Bugs — Refactor Sırasında Tespit Edilenler

> **Bulundu:** 2026-05-13, Plan 1 uygulaması sırasında canlı test
> **Fix zamanı:** Tüm refactor planları tamamlandıktan sonra
> **Spagetti riski:** YOK — tümü bağımsız SQL/backend hataları, JS refactor'undan etkilenmez

---

## Bug 1: `tohumlanabilir_hayvanlar` View'ı Boş Dönüyor

**Etki:** 🟡 Tohumlama modal'ında autocomplete listesi boş. "Elle" moduyla manuel giriş yapılabiliyor.

**Kök neden:** Hayvanların `dogum_tarihi` NULL olduğu için `hayvan_durum_view` içindeki `yas_gun` hesaplanamıyor:

```sql
-- hayvan_durum_view, yas CTE:
CASE
  WHEN h.dogum_tarihi IS NOT NULL
  THEN CURRENT_DATE - h.dogum_tarihi  -- dogum_tarihi NULL → NULL
  ELSE NULL
END AS yas_gun
```

Ve `tohumlama_durumu_hesap`:
```sql
WHEN y.yas_gun >= y.tohumlama_esik_gun AND y.cinsiyet = 'Dişi' THEN 'tohumlanabilir'
-- NULL >= 365 = FALSE → hicbir hayvan 'tohumlanabilir' olmuyor
```

**Fallback:** `acHayvan()` fonksiyonu (ui.js:3173) `_eligibleHayvanlar()` fallback'ini dener ama o da `dogum_tarihi` kontrol ediyor:
```js
function _eligibleHayvanlar(){
  // ...
  if(!a.dogum_tarihi) return false;  // aynı sorun
  return (Date.now()-new Date(a.dogum_tarihi).getTime())>=minMs;
}
```

**Fix:** Veritabanındaki hayvanlara dogum_tarihi gir. Ya da view/fonksiyon mantığını değiştir (dogum_tarihi yoksa 0 gün kabul et — ANCAK bu yanlış hayvanları "tohumlanabilir" gösterir).

**Etkilenen dosyalar:** `hayvan_durum_view`, `tohumlanabilir_hayvanlar` view, `_eligibleHayvanlar()` (ui.js:3178)

---

## Bug 2: `delete_treatment_day` RPC — `da.drug_id` Column Hatası

**Etki:** 🔴 Vaka düzenleme → tedavi günü silme işlemi çalışmıyor. SQL hatası dönüyor:

```
column da.drug_id does not exist
```

**Kök neden:** `delete_treatment_day` RPC fonksiyonu içinde `da.drug_id`'ye referans verilmiş ama `drug_administrations` tablosunda `drug_id` diye bir kolon yok. Migration'da bu RPC oluşturulurken yanlış kolon adı yazılmış.

**Etkilenen dosyalar:** Migration (hangi migration'da tanımlandıysa) + `ui.js:2751` (RPC çağrısı)

---

## Bug 3: Tedavi Tipinde Görev Bulunmuyor (Veri Eksikliği)

**Etki:** 🟡 Görevler sayfasında "Tedavi" filtresine tıklandığında "Henüz tamamlanan görev yok" mesajı. Bunun nedeni veritabanında `gorev_tipi = 'TEDAVI'` veya `'ILAC_UYGULAMA'` olan kayıtların bulunmaması. Bug değil, veri eksikliği.

**Not:** Görev otomasyonu (RPC'ler) sadece AŞI, VİTAMİN, KONTROL, BAKIM tiplerinde görev üretiyor olabilir. Tedavi görevleri otomatik oluşmuyor. Kullanıcı elle ekleyebilir.

**Etkilenen dosyalar:** Yok (veri eksikliği)

---

## Bug 4: Hayvan Kartında Semptom Chips Gösterilmiyor (Tespit Edilemedi)

**Etki:** 🟡 Hastalık modal'ında semptom chips'leri görünmüyor olabilir.

**Kök neden:** `openM('m-disease')` içinde `updateSemptomDropdown('')` çağrılıyor. Bu fonksiyon `ui.js`'de tanımlı. Modal.js'deki openM fonksiyonu birebir aynı olduğu için sorun önceden de vardı. Muhtemelen `_semptomSecili` başlangıç değeri veya DOM elementi bulunamamasından kaynaklanıyor.

**Etkilenen dosyalar:** `ui.js:updateSemptomDropdown()`

---

## Hızlı Çözümler

| Bug | Zorluk | Fix süresi | Aciliyet |
|-----|--------|-----------|----------|
| Bug 1 (tohumlanabilir boş) | Orta | 30dk (hayvanlara dogum_tarihi gir + migration fix) | Yüksek — tohumlama için gerekli |
| Bug 2 (column hatası) | Düşük | 15dk (RPC migration fix) | Orta — silme işlemi çalışmıyor |
| Bug 3 (tedavi görevi yok) | Düşük | 5dk (manuel gorev eklenebilir) | Düşük |
| Bug 4 (semptom chips) | Orta | 15dk (kod inceleme) | Düşük |
