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

## Kapsam notu

- `gebelik_kaydet_manual`'ın PROD çağrıda SQL 42804 verdiği (BUG-003) bu
  dosyanın ölçümü DEĞİLDİR; bilinen PROD hata raporuna dayanır ve demo DB'de
  kırmızı-önce reproduce ile doğrulanacaktır (goal
  `G-20260910-UREME-STOK-BUGFIX`).
- 207 tohumlamalık vethek seti maternal spot-check'i P1 Task 0.3 koşusunda
  üretilir; bu dosyaya eklenir.
