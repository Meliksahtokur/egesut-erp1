# Canlı DB ölçüm kanıtları — üreme RPC stok davranışı (2026-09-10)

**Yöntem:** root oturumu, salt-okunur PostgreSQL katalog sorgusu (pg_proc +
pg_get_functiondef) PROD Supabase üzerinden. Yazma yok. Nokta-ziamanı
ölçümdür; canlı sonradan değişebilir — teyit gerektiğinde sorgu yeniden
koşulur.

## S1 — İmzalar + stok_hareket teması

```sql
SELECT p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       position('stok_hareket' in pg_get_functiondef(p.oid)) > 0 AS touches_stok_hareket
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('gebelik_kaydet_manual','tohumlama_kaydet',
                    'tohumlama_tekrar_kaydet','planli_tohumlama_kaydet')
ORDER BY p.proname;
```

Çıktı (2026-09-10):

```json
[{"name":"gebelik_kaydet_manual","args":"p_hayvan_id text, p_tarih date, p_sperma text","touches_stok_hareket":false},
 {"name":"planli_tohumlama_kaydet","args":"p_gorev_id uuid, p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean","touches_stok_hareket":false},
 {"name":"tohumlama_kaydet","args":"p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean","touches_stok_hareket":true},
 {"name":"tohumlama_tekrar_kaydet","args":"p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text","touches_stok_hareket":true}]
```

Sonuç: `planli_tohumlama_kaydet` gövdesi stok_hareket'e hiç dokunmuyor
(BUG-001); diğer ikisi dokunuyor.

## S2 — `tohumlama_kaydet` gövdesindeki stok düşümü bloğu (ilk geçen yer çevresi)

```sql
SELECT substring(pg_get_functiondef(p.oid)
       from greatest(position('stok_hareket' in pg_get_functiondef(p.oid))-500,1) for 1400) AS excerpt
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname='tohumlama_kaydet';
```

Çıktıdan ilgili kesit (kısaltılmış değil, bağlam kesilmiş):

```sql
INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
         'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id), false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;
```

Sonuç: düşüm deseni = `urun_adi ILIKE '%<sperma>%'` substring eşleşmesi
(BUG-002: `p_sperma = ''` → `ILIKE '%%'` → kategori=Sperma herhangi bir
satırdan LIMIT 1 ile rastgele düşüm riski).

## S3 — GT↔canlı drift gözlemi (SMELL-003 kanıtı)

Tracked `supabase/migrations/99999999999999_ground_truth.sql` içinde
`CREATE OR REPLACE FUNCTION public.tohumlama_kaydet` son tanımı satır
10858–10924 aralığıdır (66 satır) ve bu aralıkta `stok_hareket` GEÇMEZ
(`sed -n '10858,10924p' | grep -c stok_hareket` → 0). Canlı gövde ise S2'deki
stok düşümü + gorev_log + ek uygulama döngüsünü içerir. Yani GT o anki canlı
gövdeyi yansıtmıyor; canlı otorite kabul edildi.

## S4 — Kolon tipleri (r3-review turu, 2026-09-10, information_schema)

```sql
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND (
  (table_name='tohumlama'   AND column_name IN ('id','sperma','created_at','tarih','hayvan_id','sonuc'))
  OR (table_name='hayvanlar' AND column_name IN ('id','anne_id','baba_bilgi','dogum_tarihi','cinsiyet'))
  OR (table_name='dogum'     AND column_name IN ('id','olay_id','anne_id','baba_bilgi','dogum_tarihi'))
  OR (table_name='stok'      AND column_name IN ('id','kategori','urun_adi')))
ORDER BY table_name, column_name;
```

Özet çıktı: `tohumlama.id` **uuid**, `tohumlama.created_at` **timestamptz
(MEV CUT)**, `tohumlama.sperma/hayvan_id/sonuc` text, `tarih` date;
`hayvanlar.id/anne_id/baba_bilgi/cinsiyet` text, `dogum_tarihi` date;
`dogum.id/olay_id` uuid, `dogum.anne_id/baba_bilgi` text; `stok.id/kategori/
urun_adi` text. **Drift örneği #2:** tracked GT `tohumlama.id`'yi text
gösteriyor (GT:116); canlı uuid — canlı otorite. `created_at` da GT tablo
tanımında görünmüyor, canlıda mevcut (cutoff tasarımı bu kolona dayanabilir).

## S5 — RPC dönüş tipleri (legacy dönüş kontratı, r3 turu)

```sql
SELECT p.proname, pg_get_function_result(p.oid) FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('tohumlama_kaydet',
 'tohumlama_tekrar_kaydet','planli_tohumlama_kaydet','gebelik_kaydet_manual',
 'hayvan_ekle','dogum_kaydet');
```

Çıktı: altısının dönüş tipi de **jsonb** (`hayvan_ekle`'nin iki overload'ı
dahil). `_semen` varyantlarının dönüş eşdeğerlik hedefi = jsonb, aynı shape.

## S6 — Maternal spot-check (r3 turu, salt-okunur, gerçek sürü)

```sql
SELECT count(*) FILTER (WHERE h.anne_id IS NOT NULL) AS anne_id_dolu,
       count(*) FILTER (WHERE h.anne_id IS NOT NULL AND EXISTS
         (SELECT 1 FROM dogum d WHERE d.anne_id = h.anne_id)) AS dam_dogum_kaydi_var
FROM hayvanlar h;
```

Çıktı: **anne_id_dolu = 61, dam_dogum_kaydi_var = 61** — anne_id'si dolu her
hayvanın dam'ı için doğum kaydı mevcut; maternal backfill için çelişki
sayısı 0. (207, tohumlama satır sayısıdır; maternal kontrolün evreni 61'dir.)

## S7 — Kalan RPC imzaları (r4 turu)

`hayvan_ekle` (2 overload): `(p_kupe_no text, p_devlet_kupe text, p_irk text,
p_cinsiyet text, p_dogum_tarihi date, p_grup text, p_padok text, p_dogum_kg
numeric, p_anne_id text, p_baba_bilgi text, p_canli_agirlik numeric, p_boy
numeric, p_renk text, p_ayirici_ozellik text[, p_padok_id uuid])`.
`dogum_kaydet`: `(p_anne_id text, p_tarih date, p_kupe text, p_cins text,
p_tip text, p_kg numeric, p_baba text, p_hekim_id text)`.
`geri_al`: `(p_islem_id text)`.

## S8 — Tarihe-bağlı maternal kontrol (r4 turu; plan Task 0.3 sorgusunun düzeltilmiş hali)

**Kolon düzeltmesi:** `dogum` tablosunda `dogum_tarihi` YOKTUR — tarih kolonu
adı **`tarih`** (canlı kolon listesi: id, anne_id, tarih, yavru_cins,
yavru_kupe, yavru_irk, dogum_tipi, created_at, hekim_id, dogum_kg, baba_bilgi,
olay_id). Plan Task 0.3'teki örnek sorgu bu nedenle `d.tarih` olarak düzeltildi.

```sql
SELECT count(*) FILTER (WHERE h.anne_id IS NOT NULL) AS anne_dolu,
       count(*) FILTER (WHERE h.anne_id IS NOT NULL AND NOT EXISTS
         (SELECT 1 FROM dogum d WHERE d.anne_id = h.anne_id
            AND d.tarih <= h.dogum_tarihi)) AS tarihsel_uyumsuz
FROM hayvanlar h;
```

Çıktı: **anne_dolu = 61, tarihsel_uyumsuz = 1** — bir hayvanın dam'ının doğum
kaydı, yavrunun kendi doğum tarihinden SONRA tarihli (veri anomalisi;
integrity raporunun ilk gerçek bulgusu, backfill'de otomatik override edilmez,
rapora düşer).

## Kapsam notu

- `gebelik_kaydet_manual`'ın PROD çağrıda SQL 42804 verdiği (BUG-003) bu
  dosyanın ölçümü DEĞİLDİR; bilinen PROD hata raporuna dayanır ve demo DB'de
  kırmızı-önce reproduce ile doğrulanacaktır (goal
  `G-20260910-UREME-STOK-BUGFIX`).
- ET kullanım kararı owner'a aittir; tarihli owner kararı planın D-bölümüne
  işlenmeden Faz 7 zarfı yazılamaz (açık maddedir, ölçümle kapanmaz).
