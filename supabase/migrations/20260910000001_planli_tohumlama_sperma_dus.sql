-- 20260910000001_planli_tohumlama_sperma_dus.sql
-- G-20260910-UREME-STOK-BUGFIX / W1 (BUG-001) — paylaşılan sperma stok düşüm helper'ı.
--
-- Bağlam: canlı `tohumlama_kaydet` ve `tohumlama_tekrar_kaydet` sperma stoğunu
-- gövde içi `INSERT INTO stok_hareket ... ILIKE '%'||p_sperma||'%'` ile düşüyor.
-- Bu matcher iki kusur taşıyor (BUG-002): `p_sperma=''` → `ILIKE '%%'` rastgele
-- bir Sperma satırından düşer; substring çapraz eşleşme kısa adı yanlış ürüne
-- takabilir. Bu migration, BUG-002 kuralıyla doğan TEK paylaşılan düşüm
-- seamyi (`fn_sperma_stok_dus`) kurar; legacy yolların buna bağlanması M2
-- (20260910000002) kapsamındadır.
--
-- Not (W1 ölçümü + lead bağımsız doğrulaması, 2026-09-10 — karar 398ff5c7):
-- BUG-001 yanlış alarmdır. Canlı `planli_tohumlama_kaydet` gövdesi koşulsuz
-- delege eder: `v_result := public.tohumlama_kaydet(...)` — ve düşüm o iç
-- çağrının gövdesindeki `INSERT INTO stok_hareket` üzerinden zaten gerçekleşir
-- (demo davranışsal probe: planlı çağrı 1 stok_hareket satırı üretti).
-- Bu yüzden planlı yola ayrıca düşüm satırı EKLENMEZ (çift düşüm olur);
-- `planli_tohumlama_kaydet` bu migration'da değişmeden kalır ve sertleşmiş
-- kuralı, tohumlama_kaydet M2'de helper'a bağlandığında delegasyonla miras alır.
--
-- Davranış sözleşmesi (lead mimari kararı):
--   (a) p_sperma NULL veya btrim sonrası boş → HİÇBİR stok_hareket satırı yok;
--   (b) önce exact eşleşme: kategori='Sperma' AND urun_adi = p_sperma;
--   (c) exact yoksa substring: urun_adi ILIKE '%'||p_sperma||'%';
--   (d) INSERT şekli canlı tohumlama_kaydet gövdesiyle aynı (tur='Tohumlama',
--       miktar=1, iptal=false);
--   (e) stok eksiye düşebilir — kısıt/trigger eklenmez (serbest düşüm,
--       emsal 20260902000002).
-- Idempotent — CREATE OR REPLACE. Şema nitelemeleri explicit `public.`.

CREATE OR REPLACE FUNCTION public.fn_sperma_stok_dus(p_sperma text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_stok_id text;
BEGIN
  -- (a) Boş/boşluk ad asla düşüm üretmez ('' → ILIKE '%%' rastgele satır
  -- kusurunun kapanışı).
  IF p_sperma IS NULL OR btrim(p_sperma) = '' THEN
    RETURN;
  END IF;

  -- (b) Exact eşleşme önceliklidir.
  SELECT s.id INTO v_stok_id
    FROM public.stok s
   WHERE s.kategori = 'Sperma'
     AND s.urun_adi = p_sperma
   LIMIT 1;

  -- (c) Exact yoksa substring ILIKE (canlı davranışla aynı eşleşme ailesi).
  IF v_stok_id IS NULL THEN
    SELECT s.id INTO v_stok_id
      FROM public.stok s
     WHERE s.kategori = 'Sperma'
       AND s.urun_adi ILIKE '%' || p_sperma || '%'
     LIMIT 1;
  END IF;

  IF v_stok_id IS NULL THEN
    RETURN;
  END IF;

  -- (d) Ledger: pozitif miktar = kullanım; canlı INSERT şekliyle aynı kolonlar.
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  VALUES (v_stok_id, 'Tohumlama', 1, 'Tohumlama — ' || p_sperma, false);
END;
$function$;
