# Spec: Yonetim Paneli CRUD — Hard FK

**Tarih:** 2026-05-10 (guncelleme: 2026-05-11)
**Oncelik:** YUKSEK
**Bagimsizlik:** Yok

---

## Karar Logu

- **Padok FK yaklaşımı:** Hard FK secildi (2026-05-11 brainstorming).
  - `hayvanlar.padok_id uuid REFERENCES padoklar(id)` — DB seviyesinde referential integrity
  - `hayvanlar.padok` TEXT kolonu gecis doneminde kalir, view her iki alani da dondurur
  - Rename bedava: sadece `padoklar.ad` guncellenir, hayvanlar.padok_id degismez
  - Delete guvenli: FK constraint icinde hayvan varsa DB reddeder
- **GRUP_PADOK:** Dinamik olacak. `grup_padok_eslem` tablosunda saklanir, kullanici yonetir.
- **Domain Engine (gelecek):** Padok bazli otomasyonlar (kuruluk esiğı, gorev kurallari) ayri spec olarak ele alinacak (Spec 5).

---

## Mevcut Durum

### Ayarlar Paneli (m-ayarlar)
- Hekimler: Ekle (local array) | Sil (local array) | DB persist YOK
- Sperma: Ekle (local array) | Sil (local array) | DB persist YOK
- Padok: CRUD YOK, `GRUP_PADOK` config.js'te hardcoded
- `hayvanlar.padok` TEXT alani — FK yok, string esleme

### Etkilenen Tablolar
- `hayvanlar` — padok TEXT → padok_id UUID FK eklenir
- `hekimler` — mevcut, silme RPC gerekli
- `stok` (kategori='Sperma') — silme constraint check
- `tohumlama` — hekim_id + sperma constraint bagimliliklari
- `dogum`, `hastalik_log` — hekim_id bagimliliklari

---

## 1. Padok CRUD (Hard FK)

### Yeni Tablolar

```sql
-- padoklar
CREATE TABLE padoklar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ad text NOT NULL UNIQUE,
  kapasite integer,
  aktif boolean DEFAULT true,
  sira integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- grup_padok_eslem (GRUP_PADOK yerine)
CREATE TABLE grup_padok_eslem (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  grup text NOT NULL,
  padok_id uuid NOT NULL REFERENCES padoklar(id) ON DELETE CASCADE,
  UNIQUE(grup, padok_id)
);
```

### hayvanlar Degisikligi

```sql
ALTER TABLE hayvanlar ADD COLUMN padok_id uuid REFERENCES padoklar(id);
-- Migrasyon: mevcut TEXT degerlerinden esle
UPDATE hayvanlar h SET padok_id = p.id FROM padoklar p WHERE h.padok = p.ad;
```

### hayvan_durum_view Guncelleme
- `h.padok` yerinde `p.ad AS padok` (JOIN ile)
- `h.padok_id` de SELECT'e eklenir
- Frontend `a.padok` okumaya devam eder (display icin), `a.padok_id` yazma icin kullanir

### CRUD Operasyonlari
- **Ekle:** ad + kapasite → INSERT padoklar
- **Yeniden Adlandir:** padoklar.ad UPDATE (ID degismez, tum hayvanlar otomatik dogru)
- **Sil:** FK constraint — icinde hayvan varsa DB reddeder, UI uyari verir
- **Grup Esleme:** grup_padok_eslem tablosunda hangi grup hangi padoğa gider, kullanici yonetir

### Config.js Degisikligi
- `GRUP_PADOK` hardcode kaldirilir
- `let _padoklar = []` ve `let _grupPadokEslem = []` IDB'den yuklenir
- Fonksiyon: `getPadoklarForGrup(grup)` → esleme tablosundan filtrele

---

## 2. Hekim DB Silme

### Mevcut
- `_customHekimler` local array'den silme var
- DB'ye hic yazilmiyor

### Hedef
- Tum hekimler DB'de (`hekimler` tablosu)
- Silme: RPC ile constraint check (tohumlama, dogum, hastalik_log)
- Kullaniliyorsa silinemez, uyari mesaji

### RPC: hekim_sil
```sql
CREATE OR REPLACE FUNCTION public.hekim_sil(p_hekim_id text)
RETURNS jsonb AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM tohumlama WHERE hekim_id = p_hekim_id) THEN
    RETURN '{"ok":false,"mesaj":"Tohumlama kaydı olan hekim silinemez"}'::jsonb;
  END IF;
  IF EXISTS (SELECT 1 FROM dogum WHERE hekim_id = p_hekim_id) THEN
    RETURN '{"ok":false,"mesaj":"Doğum kaydı olan hekim silinemez"}'::jsonb;
  END IF;
  DELETE FROM hekimler WHERE id = p_hekim_id;
  RETURN '{"ok":true}'::jsonb;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 3. Sperma DB Silme

### Constraint
- `tohumlama.sperma` TEXT alani — sperma adi burada string olarak sakli
- Kullanilmissa silinemez

### Implementasyon
- `stok` tablosundan DELETE WHERE id = ? AND kategori = 'Sperma'
- Once `tohumlama.sperma` kontrolu: eslesme varsa red

---

## 4. IDB Sync Degisiklikleri

- `padoklar` ve `grup_padok_eslem` tablolari FETCHERS'a eklenir
- `hekimler` tablosu FETCHERS'a eklenir (su an sync edilmiyor)
- DB_VER bump (14 → 15) — yeni object store'lar
- `onupgradeneeded` callback'te: `padoklar`, `grup_padok_eslem`, `hekimler` store olustur

---

## 5. Frontend Degisiklikleri

### forms.js
- Hayvan ekleme/guncelleme: `p_padok: v('a-padok')` → `p_padok_id: v('a-padok')` (artik UUID secilir)
- Padok dropdown: `padoklar` IDB tablosundan doldurulur

### ui.js
- Display: `a.padok` (view'dan gelen ad) → degismez
- Filtre: `a.padok === selectedPadok` → degismez (view ad donduruyor)
- Ayarlar: padok/hekim/sperma CRUD bolumu yeniden yazilir

### config.js
- `GRUP_PADOK` const kaldirilir
- `HEKIMLER` hardcode yerine DB'den yukle (fallback olarak kalir)
- `SPERMA_LISTESI` hardcode kalir (stok tablosu zaten var)

---

## Test Senaryolari

1. Padok ekle → listede gorunur → hayvan bu padoğa atanabilir
2. Padok yeniden adlandir → tum hayvanlarda yeni isim gorunur (ID degismedi)
3. Padok sil (bos) → basarili
4. Padok sil (icinde hayvan var) → hata mesaji
5. Hekim sil → tohumlama kaydi yoksa basarili
6. Hekim sil → tohumlama kaydi varsa hata mesaji
7. Sperma sil → tohumlama kaydi yoksa basarili
8. Grup→padok esleme degistir → yeni hayvan ekleme formunda dogru padok onerilir
