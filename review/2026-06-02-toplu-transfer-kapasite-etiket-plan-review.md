# Plan Review: Toplu Transfer + Kapasite + Besi Etiket

> **Plan:** `docs/superpowers/plans/2026-06-02-toplu-transfer-kapasite-etiket.md`
> **Spec:** `docs/superpowers/specs/2026-06-02-toplu-transfer-kapasite-etiket.md`
> **Tarih:** 2026-06-02
> **Reviewer:** minimax-arch-1 (v4 flash)
> **Durum:** ❌ Düzeltme gerekli

---

## İçindekiler

1. [🔴 KRİTİK: `islem_log` Kolon İsimleri + Eksik `snapshot`](#1-kritik-islem_log-kolon-isimleri--eksik-snapshot)
2. [🔴 KRİTİK: Eksik `updated_at = now()`](#2-kritik-eksik-updated_at--now)
3. [🔴 KRİTİK: `loadSuru()` Fonksiyonu Yok](#3-kritik-loadsuru-fonksiyonu-yok)
4. [🔴 KRİTİK: `window._suruData` Globali Yok](#4-kritik-window_surudata-globali-yok)
5. [🔴 KRİTİK: `window._padoklar` Globali Yok](#5-kritik-window_padoklar-globali-yok)
6. [🟡 ÖNEMLİ: Seçim Terk Uyarısı Kapsamı Net Değil](#6-onemli-secim-terk-uyarisi-kapsami-net-degil)
7. [🟡 ÖNEMLİ: `ground_truth.sql` Güncelleme Zorluğu](#7-onemli-ground_truthsql-guncelleme-zorlugu)
8. [🟡 ÖNEMLİ: `padokTopluTasi` Redirect Eski Akışı Kırabilir](#8-onemli-padoktoplutasi-redirect-eski-akisi-kirabilir)
9. [🟡 ÖNEMLİ: Mevcut RPC'lerde Pre-Existing Bug](#9-onemli-mevcut-rpclerde-pre-existing-bug)
10. [🟢 MİNÖR: Performans — Doluluk Bar O(n*m)](#10-minor-performans--doluluk-bar-onm)
11. [🟢 MİNÖR: Satır Numaraları Doğrulanmalı](#11-minor-satir-numaralari-dogrulanmali)
12. [✅ Doğru Tespitler](#12-dogru-tespitler)
13. [📋 Düzeltme Önerileri](#13-duzeltme-onerileri)

---

## 1. 🔴 KRİTİK: `islem_log` Kolon İsimleri + Eksik `snapshot`

**Etkilenen Task:** Task 2 (`padok_degistir` + `padok_degistir_toplu` RPC'ler)

### Sorun

Plan'daki RPC kodları `islem_log` tablosuna INSERT yaparken olmayan/yanlış kolon isimleri kullanıyor ve `snapshot` (NOT NULL) kolonunu hiç eklemiyor.

**Plan'da yazan (Task 2 Step 1 & 2):**
```sql
INSERT INTO islem_log (hayvan_id, islem_tipi, aciklama)
VALUES (p_hayvan_id, 'padok_degisim',
        COALESCE(p_not, 'Padok değiştirildi → ' || v_yeni_padok.ad));
```

**`islem_log` tablosu (`ground_truth.sql:295-313`):**
```sql
CREATE TABLE public.islem_log (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tip             text NOT NULL,
  ana_hayvan_id   text,
  tarih           timestamptz DEFAULT now(),
  kullanici_notu  text,
  durum           text NOT NULL DEFAULT 'aktif',
  geri_alma_tarihi timestamptz,
  snapshot        jsonb NOT NULL         -- ← ZORUNLU!
  -- sonradan eklenen: payload jsonb, ref_id text, ref_tablo text
);
```

### Karşılaştırma Tablosu

| Plan | Gerçek Tablo | Mevcut RPC | Çözüm |
|------|-------------|------------|-------|
| `hayvan_id` | `ana_hayvan_id` | `ref_id` | `ana_hayvan_id` kullan |
| `islem_tipi` | `tip` | `islem` | `tip` kullan (tablo standardı) |
| `aciklama` | `kullanici_notu` | `aciklama` | `kullanici_notu` kullan |
| ❌ **Eksik** | `snapshot jsonb NOT NULL` | ❌ Eksik | **Mecburi** — `'{}'::jsonb` ekle |
| ❌ **Eksik** | `ref_id` | `ref_id` | `p_hayvan_id` ile doldur |
| ❌ **Eksik** | `tarih` | `created_at` | `now()` ile doldur |

### Neden Kritik?

`snapshot` kolonu `NOT NULL` constraint'ine sahip. INSERT'te snapshot gönderilmezse:

```
ERROR: null value in column "snapshot" violates not-null constraint
```

### Mevcut RPC'ler de Aynı Hatayı İçeriyor

Dosya: `supabase/migrations/20260512000001_padok_degistir_rpc.sql:47`
```sql
INSERT INTO public.islem_log (islem, aciklama, ref_id, created_at)
```

Bu da tablo şemasıyla uyuşmuyor (`islem` → `tip`, `aciklama` → `kullanici_notu`, `created_at` → `tarih`). Eğer bu migration daha önce deploy edildiyse ve çalışıyorsa, ya production'daki tablo şeması farklıdır ya da migration hiç çalıştırılmamıştır. **Yeni migration'ın doğru kolonları kullanması gerekir.**

---

## 2. 🔴 KRİTİK: Eksik `updated_at = now()`

**Etkilenen Task:** Task 2 Step 1 (`padok_degistir`)

### Sorun

Plan'daki UPDATE'te `updated_at` timestamp'i güncellenmiyor.

**Plan:**
```sql
UPDATE hayvanlar
SET padok_id = p_yeni_padok_id,
    padok    = v_yeni_padok.ad
WHERE id = p_hayvan_id;
```

**`ground_truth.sql:7096-7100` — mevcut versiyon:**
```sql
UPDATE public.hayvanlar
SET padok_id = p_yeni_padok_id,
    padok = v_yeni_padok_adi,
    updated_at = now()       -- ← BURADA VAR
WHERE id = p_hayvan_id;
```

### Çözüm

```sql
UPDATE hayvanlar
SET padok_id = p_yeni_padok_id,
    padok    = v_yeni_padok.ad,
    updated_at = now()
WHERE id = p_hayvan_id;
```

---

## 3. 🔴 KRİTİK: `loadSuru()` Fonksiyonu Yok

**Etkilenen Task:** Task 10 Step 1 (`btTransferOnayla`)

### Sorun

Plan'da transfer sonrası sürü listesi yenileme:

```javascript
if (typeof loadSuru === 'function') await loadSuru();
```

`js/ui.js` içinde **`loadSuru` diye bir fonksiyon bulunmuyor**.

Mevcut kodda sürü verisini yükleyen fonksiyon:

- **`loadAnimals()`** (line 568) — Hayvan listesini yükler, render eder

Ayrıca `renderPadokDolulukBar` çağrısı da aynı yerde:
```javascript
if (typeof renderPadokDolulukBar === 'function') renderPadokDolulukBar();
```
Bu fonksiyon plan kapsamında yeni ekleneceği için sorun yok.

### Çözüm

```javascript
if (typeof loadAnimals === 'function') await loadAnimals();
if (typeof renderPadokDolulukBar === 'function') renderPadokDolulukBar();
```

---

## 4. 🔴 KRİTİK: `window._suruData` Globali Yok

**Etkilenen Task:** Task 4 (doluluk bar), Task 6 (action bar), Task 7 (modal seçili hayvanlar), Task 8 (hedef padok listesi)

### Sorun

Plan boyunca `window._suruData` global değişkeni kullanılıyor. Örnekler:

| Fonksiyon | Kullanım |
|-----------|----------|
| `renderPadokDolulukBar` | `window._suruData.filter(h => h.padok_id === p.id && h.durum === 'Aktif')` |
| `_btGuncelleActionBar` | `window._suruData.filter(h => _btSecilenIds.includes(h.id))` |
| `_btRenderSeciliHayvanlar` | `window._suruData.filter(h => _btModalSecilenIds.includes(h.id))` |
| `_btRenderHedefPadoklar` | `window._suruData.filter(h => _btModalSecilenIds.includes(h.id))` |
| `_btGuncelleOzet` | `window._suruData.filter(h => _btModalSecilenIds.includes(h.id))` |
| `_btRenderEtiketTekkek` | `window._suruData.filter(h => _btModalSecilenIds.includes(h.id))` |
| `_btRenderSerbestListe` | `window._suruData.filter(h => h.durum === 'Aktif')` |
| `btApplyFiltre` | `window._suruData.filter(...)` |
| `btTransferOnayla` | `window._suruData.filter(h => _btModalSecilenIds.includes(h.id))` |

**`js/ui.js`'de `window._suruData` diye bir değişken yok.**

### Mevcut Veri Akışı

```javascript
// js/ui.js:568-590
async function loadAnimals() {
  const animals = await getData('hayvanlar', a => a.durum === 'Aktif');
  if (typeof setState === 'function') setState('animals', animals);
  // ...
  renderAnimals(sorted);
}
```

Hayvan verisi **`getState('animals')`** ile veya doğrudan **`getData('hayvanlar')** ile çekiliyor.

### Çözüm

İki seçenek:

**A) `window._suruData` globalini `loadAnimals()` sonunda set et:**
```javascript
async function loadAnimals() {
  const animals = await getData('hayvanlar', a => a.durum === 'Aktif');
  window._suruData = animals;  // ← ekle
  // ...
}
```

**B) Mevcut state API'ini kullan (önerilen):**
```javascript
const suruData = getState('animals') || [];
```
(Tüm kullanımları `getState('animals')` ile değiştir.)

---

## 5. 🔴 KRİTİK: `window._padoklar` Globali Yok

**Etkilenen Task:** Task 4, Task 7, Task 8

### Sorun

Plan `window._padoklar` kullanıyor:
- `renderPadokDolulukBar`: `const padoklar = window._padoklar || [];`
- `_btRenderHedefPadoklar`: `const padoklar = window._padoklar || [];`
- `_btGuncelleOzet`: `const padoklar = window._padoklar || [];`
- `btTransferOnayla`: `const padoklar = window._padoklar || [];`

Mevcut kodda padok verisi `loadPadokConfig()` ile geliyor. Bu fonksiyonun padokları hangi değişkende tuttuğu kontrol edilmeli.

### Mevcut `loadPadokConfig` Kullanımı

```javascript
// js/ui.js:5423, 5440, 5607, 5619
await loadPadokConfig();
```

`loadPadokConfig` fonksiyonunun içine bakmak gerek — padokları `window._padoklar`'a mı yoksa farklı bir değişkene mi atadığı görülmeli. Eğer atamıyorsa, eklenmeli.

### Çözüm

`loadPadokConfig()` içinde:
```javascript
window._padoklar = padoklar;  // veya getData('padoklar') sonucu
```

---

## 6. 🟡 ÖNEMLİ: Seçim Terk Uyarısı Kapsamı Net Değil

**Etkilenen Task:** Task 5 Step 4

### Sorun

Plan diyor ki:

> Mevcut sekme geçiş fonksiyonlarını (örn. `showTab`, `showSection`) başına `_btSecimTerkUyari(() => { ... })` sarmalıyla güncelle.

Ancak:

1. **Hangi fonksiyonlar?** `showTab`/`showSection` mevcut kodda var mı? Doğrulanmamış.
2. **`openM()` sarmalanmalı mı?** Her modal açılışında seçim terk uyarısı verilmeli mi?
3. **Yalnızca belirli modal'lar mı?** `m-animal-det` (hayvan detay) gibi modal'lar seçimi bozmalı mı?
4. **Sekme değişimleri?** Ana sekme (`pg-suru` → `pg-ureme` gibi) değişimlerinde de uyarı verilmeli mi?

### Öneri

Plan netleştirilmeli. Örneğin:
- `openM()` override edilip, eğer `_btSecimModu === true` ise uyarı göster
- Veya sadece belirli `data-action` handler'larında kontrol ekle

---

## 7. 🟡 ÖNEMLİ: `ground_truth.sql` Güncelleme Zorluğu

**Etkilenen Task:** Task 1 Step 3, Task 2 Step 4

### Sorun

Plan diyor ki:
- "`99999999999999_ground_truth.sql` içinde `hayvanlar` tablosunun CREATE TABLE bloğunu bul, `etiketler text[] DEFAULT '{}'` kolonunu ekle."
- "Satır ~7040-7110: `padok_degistir` fonksiyonunu yeni versiyonuyla değiştir"

`ground_truth.sql` **8762 satır**. `hayvanlar` CREATE TABLE'ını bulmak ve doğru kolon sırasına eklemek dikkat gerektirir. Satır numaraları (`~7040`, `~7114`) güncelliğini kaybetmiş olabilir — özellikle `ground_truth.sql` sık değişen bir dosyaysa.

### Öneri

Implementasyon öncesi `grep` ile gerçek satır numaraları tespit edilmeli.

---

## 8. 🟡 ÖNEMLİ: `padokTopluTasi` Redirect Eski Akışı Kırabilir

**Etkilenen Task:** Task 10 Step 2

### Sorun

Plan, mevcut `padokTopluTasi()` fonksiyonunu şöyle değiştiriyor:

```javascript
function padokTopluTasi() {
  if (!_pdHayvanIds.length) { toast('⚠️ Lütfen en az bir hayvan seçin', true); return; }
  _btSecilenIds = [..._pdHayvanIds];
  _btModalSecilenIds = [..._pdHayvanIds];
  _btHedefPadokId = null;
  openBulkTransfer();
}
```

Bu, mevcut `_pdTransferAcSelector()` akışını tamamen iptal ediyor. Ancak:

1. **`padokTekliTasi()`** hala eski akışı kullanıyor — `_pdTransferAcSelector()` + `padokTransferOnayla()`
2. **Handler'daki `padok-transfer-onay`** hala eski `padokTransferOnayla()`'yı çağırıyor
3. **`m-padok-transfer` modal'ı** (line 1782) hala HTML'de duruyor

### Öneri

Eski `padokTransferOnayla()` ve `_pdTransferAcSelector()` fonksiyonları temizlenmeli veya eski handler'lar yeni akışa yönlendirilmeli. Aksi halde iki paralel transfer akışı oluşur.

---

## 9. 🟡 ÖNEMLİ: Mevcut RPC'lerde Pre-Existing Bug

**Etkilenen:** Task 2 ile ilgili, ama mevcut kod sorunu

### Sorun

Hem `20260512000001_padok_degistir_rpc.sql` hem de `20260512000002_padok_degistir_toplu_rpc.sql` migration dosyaları `islem_log`'a INSERT yaparken **olmayan kolonlar** kullanıyor:

```sql
INSERT INTO public.islem_log (islem, aciklama, ref_id, created_at)
```

Oysa `islem_log` tablosunda:
- `islem` diye kolon yok → `tip`
- `aciklama` diye kolon yok → `kullanici_notu`  
- `created_at` diye kolon yok → `tarih`

**Bu RPC'ler çağrıldığında hata alınması gerekir.** Eğer production'da çalışıyorsa, ya:
- Tablo şeması farklıdır (ground_truth güncel değil)
- Bu migration'lar hiç deploy edilmemiştir
- Başka bir migration kolonları rename etmiştir (bulunamadı)

### Öneri

Bu plan kapsamında RPC'ler yeniden yazılırken **doğru kolon isimleri kullanılmalı**. Mevcut bug'ı devralmak yerine fix'lenmiş olarak gelmeli.

---

## 10. 🟢 MİNÖR: Performans — Doluluk Bar O(n*m)

**Etkilenen:** Task 4 Step 2 (`renderPadokDolulukBar`)

### Sorun

```javascript
const dolu = suruData.filter(h => h.padok_id === p.id && h.durum === 'Aktif').length;
```

Her padok için tüm hayvan listesi taranıyor. N hayvan × M padok = O(n*m). 2000 hayvan + 15 padok = 30,000 iterasyon. Her render'da tekrarlanır.

### Çözüm Önerisi

```javascript
// Tek seferde padok bazlı sayım
const padokSayac = {};
suruData.forEach(h => {
  if (h.durum === 'Aktif') {
    padokSayac[h.padok_id] = (padokSayac[h.padok_id] || 0) + 1;
  }
});
// Sonra padokSayac[p.id] kullan
```

---

## 11. 🟢 MİNÖR: Satır Numaraları Doğrulanmalı

**Etkilenen:** Tüm Task'lar

### Sorun

Plan'daki `~satır` referansları:

| Referans | Gerçek (control) |
|----------|------------------|
| `index.html` ~satır 355 (search-bar) | ✅ `index.html:355` |
| `index.html` ~satır 386 (`suru-body`) | ✅ `index.html:385` |
| `index.html` ~satır 1797 (`m-padok-transfer`) | ✅ `index.html:1782` (15 satır kayma) |
| `js/ui.js` ~satır 5452 (`_pdHayvanIds`) | ✅ `ui.js:5450` |
| `js/ui.js` ~satır 5524 (`padokTopluTasi`) | ✅ `ui.js:5524` |
| `ground_truth.sql` ~satır 7040-7110 | ✅ `7059-7127` |
| `ground_truth.sql` ~satır 7114-7200 | ✅ `7133-7217` |
| `handlers.js` ~satır 243 | ✅ `handlers.js:243` |

Çoğu doğru, birkaç satır kayması var. Implementasyon öncesi son kontrol yapılmalı.

---

## 12. ✅ Doğru Tespitler

Plan'da doğru olan noktalar:

| Konu | Açıklama |
|------|----------|
| `--green3` CSS değişkeni | `index.html:23`'de tanımlı ✅ |
| `openM`/`closeM` fonksiyonları | Mevcut kodda var (ui.js:15'te import) ✅ |
| `GRUP_PADOK` globali | ui.js:13'te import edilmiş ✅ |
| `_pdHayvanIds` değişkeni | ui.js:5450'de var ✅ |
| `padokTopluTasi` fonksiyonu | ui.js:5524'te var ✅ |
| `padokTransferOnayla` fonksiyonu | ui.js:5545'te var ✅ |
| `m-padok-transfer` modal'ı | index.html:1782'de var ✅ |
| `padok_degistir_toplu`'ya 3. parametre ekleme | Mevcut imza `(text[], uuid)`, yeni imza `(text[], uuid, text[])` ✅ |
| `padok_degistir` kapasite kontrolü | Mevcut fonksiyonda kapasite kontrolü yok, plan doğru ekliyor ✅ |
| All-or-nothing transaction | Mevcut `padok_degistir_toplu` per-animal exception loop kullanıyor, plan all-or-nothing ✅ |

---

## 13. 📋 Düzeltme Önerileri

### Acil (Implementasyon öncesi düzeltilmeli)

1. **`islem_log` INSERT** — kolon isimlerini tablo şemasıyla uyumlu hale getir:
   ```sql
   INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
   VALUES ('padok_degisim', p_hayvan_id, p_hayvan_id, '{}'::jsonb,
           COALESCE(p_not, 'Padok değiştirildi → ' || v_yeni_padok.ad));
   ```

2. **`updated_at = now()`** — UPDATE'e ekle

3. **`window._suruData`** — Ya `loadAnimals()` içinde set et, ya da `getState('animals')` kullan

4. **`window._padoklar`** — `loadPadokConfig()` içinde set et

5. **`loadSuru` → `loadAnimals`** — düzelt

### Önemli (Implementasyon sırasında dikkat)

6. Seçim terk uyarısı kapsamını netleştir: hangi fonksiyonlar sarmalanacak?
7. Eski `padokTransferOnayla`/`_pdTransferAcSelector` temizliği
8. `ground_truth.sql` satır numaralarını doğrula
9. `_btRenderSuru` CSS class yaklaşımı doğru — kart template'ine `.bt-cb` checkbox eklendiğinden emin ol

### Stretch

10. Doluluk bar performans iyileştirmesi (padokSayac map)

---

## Ek: Mevcut Kodda Doğrulama Tablosu

| Değişken/Fonksiyon | Plan'da | Mevcut Kod | Durum |
|-------------------|---------|-----------|-------|
| `window._suruData` | Global hayvan verisi | Yok | ❌ |
| `window._padoklar` | Global padok verisi | Yok | ❌ |
| `loadSuru()` | Sürü yenileme | Yok (`loadAnimals()` var) | ❌ |
| `loadAnimals()` | — | ui.js:568 | ✅ Mevcut |
| `loadPadokConfig()` | Doluluk bar için | ui.js:5423,5440 | ✅ Mevcut |
| `_pdHayvanIds` | State | ui.js:5450 | ✅ Mevcut |
| `padokTopluTasi()` | Redirect edilecek | ui.js:5524 | ✅ Mevcut |
| `padokTransferOnayla()` | Eski akış | ui.js:5545 | ✅ Mevcut |
| `openM()`/`closeM()` | Modal kontrol | ui.js:15 import | ✅ Mevcut |
| `GRUP_PADOK` | Grup uyum | ui.js:13 import | ✅ Mevcut |
| `getState('animals')` | — | ui.js:1684 | ✅ Mevcut |
| `--green3` | CSS renk | index.html:23 | ✅ Tanımlı |
| `getData('hayvanlar')` | API | ui.js:571 | ✅ Mevcut |
| `islem_log` tablosu | RPC INSERT | ground_truth:295 | ⚠️ Kolon adları uyuşmaz |
| `padok_degistir` RPC | Kapasite kontrolü | ground_truth:7059 | ⚠️ Pre-existing bug |
| `padok_degistir_toplu` RPC | All-or-nothing | ground_truth:7133 | ⚠️ Pre-existing bug |

---

*Review tamamlandı. Özet: 5 kritik + 4 önemli + 2 minör sorun. En acil: `islem_log` kolon isimleri ve `snapshot` eksikliği.*
