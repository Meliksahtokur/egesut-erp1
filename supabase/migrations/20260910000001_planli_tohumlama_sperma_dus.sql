-- 20260910000001_planli_tohumlama_sperma_dus.sql
-- G-20260910-UREME-STOK-BUGFIX / W1+W2b (BUG-001 yanlış alarm teşhisi +
-- BUG-002 paylaşımlı matcher) — sperma stok düşüm helper'ının FİNAL biçimi.
-- M2 (20260910000002) yalnız iki legacy yolu (tohumlama_kaydet,
-- tohumlama_tekrar_kaydet) bu helper'a bağlar; helper tanımı M2'de YOKTUR.
--
-- Bağlam: canlı `tohumlama_kaydet` ve `tohumlama_tekrar_kaydet` sperma stoğunu
-- gövde içi `INSERT INTO stok_hareket ... ILIKE '%'||p_sperma||'%'` ile düşüyor.
-- Bu matcher iki kusur taşıyor (BUG-002): `p_sperma=''` → `ILIKE '%%'` rastgele
-- bir Sperma satırından düşer; substring çapraz eşleşme kısa adı yanlış ürüne
-- takabilir. Helper bu iki kusuru kapanmış TEK paylaşılan düşüm seamini kurar.
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
-- W2b (review düzeltme turu, 2026-09-10): helper'ın final hali (opsiyonel
-- p_notlar parametresiyle) M2'den BURAYA taşındı. Tek imza, DROP YOK:
--   * CREATE OR REPLACE replay'de her zaman tek imzaya yakınsar — bu dosyanın
--     M2'den sonra yeniden çalıştırılması ikinci bir (text) overload'ı
--     üretmez; 42725 "could not choose best candidate" belirsizliği
--     imkânsızlaşır (review B2);
--   * DROP yokluğu ACL/owner'ı korur (review B3);
--   * Whitespace guard regex'e çevrildi (review B6): btrim(text) varsayılan
--     yalnız boşluk kırpar, tab/newline/CR'yi geçirirdi (review demo ölçümü:
--     E'\t' 1 ledger satırı üretti). `~ '^\s*$'` seçildi çünkü Postgres ARE'de
--     \s tüm whitespace sınıfıdır ([[:space:]] eşdeğeri).
--
-- Davranış sözleşmesi (lead mimari kararı):
--   (a) p_sperma NULL veya whitespace-sınıfı bakımından boş → HİÇBİR
--       stok_hareket satırı yok;
--   (b) önce exact eşleşme: kategori='Sperma' AND urun_adi = p_sperma;
--   (c) exact yoksa substring: urun_adi ILIKE '%'||p_sperma||'%';
--   (d) INSERT şekli canlı tohumlama_kaydet gövdesiyle aynı (tur='Tohumlama',
--       miktar=1, iptal=false); notlar: çağıran verirse onun metni
--       (kupe_no/deneme bilgisi), vermezse 'Tohumlama — ' || p_sperma;
--   (e) stok eksiye düşebilir — kısıt/trigger eklenmez (serbest düşüm,
--       emsal 20260902000002).
-- Idempotent — CREATE OR REPLACE (DROP yok). Şema nitelemeleri explicit
-- `public.`.

CREATE OR REPLACE FUNCTION public.fn_sperma_stok_dus(p_sperma text, p_notlar text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_stok_id text;
BEGIN
  -- (a) NULL/whitespace ad asla düşüm üretmez ('' → ILIKE '%%' rastgele satır
  -- kusurunun kapanışı); regex, btrim'in kaçırdığı tab/newline/CR'yi de kapsar.
  IF p_sperma IS NULL OR p_sperma ~ '^\s*$' THEN
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
  -- p_notlar çağıranın verdiği metinle yazılabilir (kupe_no/deneme bilgisi);
  -- verilmezse 'Tohumlama — ' || p_sperma.
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  VALUES (v_stok_id, 'Tohumlama', 1,
          COALESCE(p_notlar, 'Tohumlama — ' || p_sperma), false);
END;
$function$;
