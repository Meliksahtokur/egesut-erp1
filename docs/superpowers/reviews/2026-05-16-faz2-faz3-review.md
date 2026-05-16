# Faz 2 + Faz 3 Review

> **Tarih:** 2026-05-16
> **Commitler:** a9ba636 (Faz 2), 1eddb2b (Faz 3), 76add8d (review fix)
> **Dosyalar:** `js/ui.js`, `js/api.js`, `20260516000001_faz1_rpc_bypass_fix.sql` (B1-B9 eklendi)

---

## Faz 1 Review Fix Durumu (76add8d)

Onceki review'daki 10 sorunun durumu:

| # | Seviye | Sorun | Durum |
|---|--------|-------|-------|
| C1 | CRITICAL | tohumlama.iptal yok | DUZELTILDI (satir 394-395) |
| C2 | CRITICAL | stok_ekle cift-cikarma | DUZELTILDI (stok_hareket INSERT kaldirildi, satir 305-307) |
| C3 | CRITICAL | stok_ekleme pozitif=azalma | DUZELTILDI (negatif miktar kullaniliyor, satir 348-351) |
| C4 | CRITICAL | BEGIN/COMMIT yok | DUZELTILDI (satir 6 + 697) |
| H1 | HIGH | RPC_TABLES eksik | DUZELTILDI (api.js:283-301) |
| H2 | HIGH | gorev_tamamla iptal check | **KONTROL GEREKLI** (asagida) |
| H3 | HIGH | islem_log snapshot formati | DUZELTILDI (silinen key eklendi, ref_id/ref_tablo eklendi) |
| M1 | MEDIUM | yas >= 365 gun kontrolu | **KONTROL GEREKLI** (asagida) |
| M2 | MEDIUM | interval yerine p_ay*30 | **KONTROL GEREKLI** (asagida) |
| M3 | MEDIUM | deneme_no hardcoded | DUZELTILDI (satir 401-403) |

---

## Faz 2 Review (a9ba636) — Frontend Hesaplama -> View

### Sonuc: TEMIZ

Faz 2 sadece frontend degisiklikleri iceriyor (migration yok):

1. **api.js:** `stok` FETCHER `stok_tuketim_view`'a cevirildi + `gebelik_ozet` FETCHER eklendi
2. **ui.js:** 6 lokasyonda `moves.filter().reduce()` stok hesabi kaldirildi, `s.guncel_stok` / `s.stok_durum` kullaniliyor

**Dogru calisan degisiklikler:**
- `loadDash()`: `stkNet` hesabi kaldirildi, `stok_durum==='kritik'`/`'tukendi'` filtreleri dogru
- `_dashBands()`: `stkNet` parametresi kaldirildi, `s.guncel_stok` kullaniliyor
- `loadStock()`: `getData('stok_hareket')` kaldirildi, view'dan `guncel_stok`/`stok_durum` okunuyor
- `loadRaporlar()`: Stok durumu view'dan geliyor
- `loadDrugsCache()`: `moves` sorgusu kaldirildi, `s?.guncel_stok` kullaniliyor
- `getSpermaStok()`: `getData('stok_hareket')` kaldirildi, `s.guncel_stok` okunuyor
- `refreshIlacCache()`: Ayni pattern

**Fallback pattern dogru:** `+(s.guncel_stok ?? s.baslangic_miktar ?? 0)` — view'dan veri gelmezse `baslangic_miktar` kullanilir.

**Uyari (LOW):** `stok_hareket` hala FETCHERS'ta ve bazi yerlerde cekilmeye devam ediyor (`loadDrugsCache` icinde `pullTables(['drug_classes','drug_products','stok','stok_hareket'])`). Stok hesabi artik view'dan geldigine gore `stok_hareket` pull'u gereksiz olabilir — ama tedavi detay sayfasi icin lazim, dolayisiyla kalabilir.

---

## Faz 3 Review (1eddb2b + 76add8d) — db.from() -> RPC

### CRITICAL Sorunlar

---

### F3-C1: `grup_padok_eslem_toggle` — kolon adi `grup` ama RPC `grup_adi` kullaniyor

**Dosya:** `20260516000001_faz1_rpc_bypass_fix.sql:685-689`
**Kod:**
```sql
IF EXISTS (SELECT 1 FROM public.grup_padok_eslem WHERE grup_adi = p_grup_adi AND padok_id = p_padok_id) THEN
    DELETE FROM public.grup_padok_eslem WHERE grup_adi = p_grup_adi AND padok_id = p_padok_id;
...
    INSERT INTO public.grup_padok_eslem (grup_adi, padok_id)
```

**Sorun:** `grup_padok_eslem` tablosu (migration 20260511000001_padoklar.sql:34-38):
```sql
CREATE TABLE IF NOT EXISTS public.grup_padok_eslem (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  grup text NOT NULL,           -- <-- kolon adi "grup", "grup_adi" DEGIL
  padok_id uuid NOT NULL,
  UNIQUE(grup, padok_id)
);
```

RPC `grup_adi` referans ediyor, tablo `grup` kullaniyor. Her cagri **column "grup_adi" does not exist** hatasi verir.

**Fix:** RPC'deki `grup_adi` -> `grup` degistir:
```sql
IF EXISTS (SELECT 1 FROM public.grup_padok_eslem WHERE grup = p_grup_adi AND padok_id = p_padok_id) THEN
    DELETE FROM public.grup_padok_eslem WHERE grup = p_grup_adi AND padok_id = p_padok_id;
...
    INSERT INTO public.grup_padok_eslem (grup, padok_id)
    VALUES (p_grup_adi, p_padok_id);
```

---

### F3-C2: `hekim_ekle` (yeni) — `kurum` kolonu `hekimler` tablosunda YOK

**Dosya:** `20260516000001_faz1_rpc_bypass_fix.sql:537`
**Kod:**
```sql
INSERT INTO public.hekimler (id, ad, telefon, kurum, aktif)
VALUES (v_id, p_ad, p_telefon, p_kurum, true);
```

**Sorun:** `hekimler` tablosu (migration 20260511000002:5-10):
```sql
CREATE TABLE IF NOT EXISTS public.hekimler (
  id      text PRIMARY KEY,
  ad      text NOT NULL,
  telefon text,
  aktif   boolean NOT NULL DEFAULT true
);
```
- `kurum` kolonu YOK — INSERT hata verir
- Ayrica `id` tipi `text` ama RPC `gen_random_uuid()` (uuid) kullaniyor — text ile uuid arasi implicit cast calismali ama tip tutarsizligi var

**Fix — 2 opsiyon:**

**Opsiyon A (onerilen):** `kurum` referansini kaldir, `id` tipini text olarak koru:
```sql
CREATE OR REPLACE FUNCTION public.hekim_ekle(
  p_ad text, p_telefon text DEFAULT NULL
)
...
  v_id := 'H' || extract(epoch from now())::bigint::text;  -- mevcut pattern
  INSERT INTO public.hekimler (id, ad, telefon, aktif)
  VALUES (v_id, p_ad, p_telefon, true);
```

**Opsiyon B:** Migration ile `kurum` kolonu ekle:
```sql
ALTER TABLE public.hekimler ADD COLUMN IF NOT EXISTS kurum text;
```
Bu durumda hekim_guncelle'deki `kurum` referansi da calisir.

---

### F3-C3: `hekim_guncelle` — `kurum` kolonu yok + `id` tipi uyumsuz

**Dosya:** `20260516000001_faz1_rpc_bypass_fix.sql:556-587`
**Sorun:** Ayni sorun — `kurum` kolonu yok. `p_hekim_id uuid` ama tablo `id text`.

**Fix:** Eger Opsiyon A secilirse `kurum` kaldirilir, `p_hekim_id` tipi `text` olur.
Eger Opsiyon B secilirse migration ile `kurum` kolonu eklenir.

---

### F3-C4: `padok_ekle` ve `padok_guncelle` — `tip` kolonu `padoklar` tablosunda YOK

**Dosya:** `20260516000001_faz1_rpc_bypass_fix.sql:599, 628-630`
**Kod:**
```sql
-- padok_ekle:
INSERT INTO public.padoklar (id, ad, tip, sira, aktif)
VALUES (v_id, p_ad, COALESCE(p_tip, 'Genel'), p_sira, true);

-- padok_guncelle:
UPDATE public.padoklar SET
  ad = ..., tip = ..., sira = ..., aktif = ...
```

**Sorun:** `padoklar` tablosu (migration 20260511000001:7-12):
```sql
CREATE TABLE IF NOT EXISTS public.padoklar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ad text NOT NULL UNIQUE,
  kapasite integer,
  aktif boolean DEFAULT true,
  sira integer DEFAULT 0
);
```
- `tip` kolonu YOK — INSERT/UPDATE hata verir
- `kapasite` kolonu var ama RPC'lerde kullanilmiyor

**Fix — 2 opsiyon:**

**Opsiyon A (onerilen):** `tip` yerine `kapasite` kullan (mevcut tablo semasina uy):
```sql
-- padok_ekle:
CREATE OR REPLACE FUNCTION public.padok_ekle(
  p_ad text, p_kapasite integer DEFAULT NULL, p_sira integer DEFAULT 0
)
...
  INSERT INTO public.padoklar (id, ad, kapasite, sira, aktif)
  VALUES (v_id, p_ad, p_kapasite, p_sira, true);

-- padok_guncelle:
CREATE OR REPLACE FUNCTION public.padok_guncelle(
  p_padok_id uuid, p_ad text DEFAULT NULL, p_kapasite integer DEFAULT NULL,
  p_sira integer DEFAULT NULL, p_aktif boolean DEFAULT NULL
)
...
  UPDATE public.padoklar SET
    ad = COALESCE(...), kapasite = COALESCE(p_kapasite, kapasite), ...
```

**Opsiyon B:** Migration ile `tip` kolonu ekle:
```sql
ALTER TABLE public.padoklar ADD COLUMN IF NOT EXISTS tip text DEFAULT 'Genel';
```

---

### F3-C5: `padok_guncelle` frontend — `kapasite` parametresi gonderilmiyor

**Dosya:** `js/ui.js:3865-3868`
**Kod:**
```js
const kap=parseInt(document.getElementById('pd-kap').value)||null, tip=v('pd-tip')||null;
const{error}=await rpc('padok_guncelle',{p_padok_id:_curPadokDet.id,p_ad:ad,p_tip:tip,p_sira:null});
```

**Sorun:** `kap` hesaplaniyor ama RPC cagirisina gonderilmiyor! `p_tip` yerine `p_kapasite: kap` gonderilmeli (eger Opsiyon A secilirse).

**Fix:**
```js
const{error}=await rpc('padok_guncelle',{p_padok_id:_curPadokDet.id,p_ad:ad,p_kapasite:kap,p_sira:null});
```

---

### F3-C6: `padok_ekle` frontend — `p_sira` icin kapasite degeri gonderiliyor

**Dosya:** `js/ui.js:4063`
**Kod:**
```js
const{error}=await rpc('padok_ekle',{p_ad:ad,p_tip:tip,p_sira:kap||0});
```

**Sorun:** `kap` (kapasite degeri) `p_sira` (siralama degeri) olarak gonderiliyor. Semantik olarak yanlis — kapasite 50 ise sira da 50 olur.

**Fix:**
```js
const{error}=await rpc('padok_ekle',{p_ad:ad,p_kapasite:kap,p_sira:0});
```

---

### HIGH Sorunlar

---

### F3-H1: Onceki review H2 — `gorev_tamamla` iptal check hala eksik

**Dosya:** `20260516000001_faz1_rpc_bypass_fix.sql:157-163`
**Sorun:** Review fix commitinde (76add8d) `gorev_tamamla`'ya iptal check eklenmemis.

**Fix:**
```sql
IF v_gorev.tamamlandi THEN
  RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış');
END IF;
-- EKLE:
IF v_gorev.iptal THEN
  RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz');
END IF;
```

---

### F3-H2: Onceki review M1 — yas >= 365 kontrolu hala eksik (tohumlanabilir_onayla)

Kontrol ettim — `hayvan_tohumlanabilir_onayla` RPC'sinde yas kontrolu eklenmemis.

**Fix:** Ayni — domain-rules.md'deki kural 2.

---

### F3-H3: Onceki review M2 — `p_ay * 30` hala interval degil

Kontrol ettim — `hayvan_tohumlama_ertele`'de hala `CURRENT_DATE + (p_ay * 30)` var.

---

### F3-H4: `vaccine_rapel_guncelle` — null check eksik

**Dosya:** `20260516000001_faz1_rpc_bypass_fix.sql:505`
**Sorun:** Frontend `days===''?null:parseInt(val)` gonderiyor — null olabilir (rapeli kaldirmak icin).
RPC'de `IF p_repeat_days <= 0` — NULL icin bu condition FALSE doner yani RAISE etmez. Ama NULL integer parametre PostgreSQL'de `integer` tipine girmeyebilir (depends on PostgREST handling).

**Fix (LOW):** NULL'a izin vermek icin check'i guncelle:
```sql
IF p_repeat_days IS NOT NULL AND p_repeat_days <= 0 THEN
  RAISE EXCEPTION 'Rapel süresi pozitif olmalıdır';
END IF;
```

---

## Faz 3 RPC_TABLES — OK

Tum Faz 3 RPC'leri `api.js` RPC_TABLES'a dogru eklenmis (satir 292-301).

---

## Ozet

| # | Seviye | Faz | Sorun | Fix |
|---|--------|-----|-------|-----|
| F3-C1 | CRITICAL | 3 | `grup_padok_eslem_toggle`: `grup_adi` -> `grup` | SQL kolon adi degistir |
| F3-C2 | CRITICAL | 3 | `hekim_ekle`: `kurum` kolonu yok | Ya kolonu ekle ya da RPC'den cikar |
| F3-C3 | CRITICAL | 3 | `hekim_guncelle`: `kurum` yok + id tipi text/uuid | Ayni fix |
| F3-C4 | CRITICAL | 3 | `padok_ekle/guncelle`: `tip` kolonu yok | Ya kolonu ekle ya da `kapasite` kullan |
| F3-C5 | CRITICAL | 3 | Frontend `kapasite` parametresi gondermiyor | ui.js duzelt |
| F3-C6 | CRITICAL | 3 | Frontend `kap` -> `p_sira` semantik hata | ui.js duzelt |
| F3-H1 | HIGH | 1 | `gorev_tamamla` iptal check hala eksik | SQL ekle |
| F3-H2 | HIGH | 1 | `tohumlanabilir_onayla` yas check hala eksik | SQL ekle |
| F3-H3 | HIGH | 1 | `tohumlama_ertele` interval yerine *30 | SQL duzelt |
| F3-H4 | LOW | 3 | `vaccine_rapel_guncelle` null check | SQL duzelt |

**KARAR (kesinlesmis): Opsiyon A — mevcut semayla uyumlu kal.**

- `hekimler.kurum` → RPC'lerden `kurum` parametresini ve referansini KALDIR
- `padoklar.tip` → RPC'lerden `tip` parametresini KALDIR, yerine `kapasite` kullan (tablo zaten `kapasite` kolonu var)
- `hekim_ekle`/`hekim_guncelle` → `p_hekim_id` tipi `text` olmali (tablo `id text`)
- Yeni kolon eklenmeyecek, ALTER TABLE yok

**Implementor icin:**
1. Oncelik sirasi: C1 → C2 → C3 → C4 → C5 → C6 → H1 → H2 → H3 → H4
2. Tum SQL degisiklikleri `20260516000001_faz1_rpc_bypass_fix.sql` icinde
3. Frontend degisiklikleri `js/ui.js` icinde (C5, C6)
4. Her fix icin dosya yolu, satir numarasi ve fix kodu yukarida mevcut
5. Fix sonrasi test: her RPC'yi bir kez cagir, hata donmemeli
