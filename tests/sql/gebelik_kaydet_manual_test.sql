-- gebelik_kaydet_manual davranış testi (BUG-003 fix: migration 20260910000003).
-- Canli/yerel DB'de guvenlidir: tum test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/gebelik_kaydet_manual_test.sql
--
-- Kapsam (BUG-003, dar-goal):
--   1. Güvenli çağrı: RPC ok=true, tohumlama satırı (id uuid, sonuc='Gebe',
--      deneme_no=1) ve islem_log GEBELIK_MANUEL satırı yazılır. 42804 red-first
--      kanıtı: 2026-09-10 demo, "column \"id\" is of type uuid but expression
--      is of type text".
--   2. Cinsiyet guard: erkek hayvana gebelik reddi ('Sadece dişi...').
--   3. Aktif-gebe guard: mevcut 'Gebe' kaydı olan hayvana ikinci gebelik reddi.

BEGIN;

DO $test$
DECLARE
  v_hayvan_id text := '__TEST_GEBELIK_MANUEL__';
  v_sonuc jsonb;
  v_toh_id uuid;
  v_toh_adet integer;
  v_deneme integer;
  v_log_adet integer;
BEGIN
  -- Öncül: canlıda tohumlama.id uuid (GT text gösteriyor — SMELL-003 drift).
  -- Test bu beklentiye bağlı; drift olursa test değil şema değişmiştir.
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'tohumlama'
       AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    RAISE EXCEPTION 'Öncül bozuk: public.tohumlama.id uuid değil (GT drift mi?)';
  END IF;

  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum, cinsiyet)
  VALUES (v_hayvan_id, v_hayvan_id, 'Sağmal (Laktasyonda)', 'Aktif', 'Dişi');

  v_sonuc := public.gebelik_kaydet_manual(v_hayvan_id, CURRENT_DATE - 1, 'TEST SPERMA');

  IF v_sonuc ->> 'ok' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'RPC ok=true dönmedi: %', v_sonuc;
  END IF;
  v_toh_id := (v_sonuc ->> 'tohumlama_id')::uuid;

  SELECT count(*)::integer, COALESCE(MAX(deneme_no), 0)
    INTO v_toh_adet, v_deneme
    FROM public.tohumlama WHERE hayvan_id = v_hayvan_id;
  IF v_toh_adet <> 1 OR v_deneme <> 1 THEN
    RAISE EXCEPTION 'tohumlama satırı beklenmedik: adet=% deneme_no=%', v_toh_adet, v_deneme;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.tohumlama
     WHERE id = v_toh_id AND sonuc = 'Gebe' AND sperma = 'TEST SPERMA'
  ) THEN
    RAISE EXCEPTION 'tohumlama satırı id ile bulunamadı: %', v_toh_id;
  END IF;

  SELECT count(*)::integer INTO v_log_adet
    FROM public.islem_log
   WHERE tip = 'GEBELIK_MANUEL' AND ana_hayvan_id = v_hayvan_id;
  IF v_log_adet <> 1 THEN
    RAISE EXCEPTION 'islem_log GEBELIK_MANUEL satırı yok: adet=%', v_log_adet;
  END IF;

  RAISE NOTICE 'PASS: güvenli çağrı — tohumlama(%) + islem_log yazıldı', v_toh_id;
END
$test$;

DO $test$
DECLARE
  v_erkek_id text := '__TEST_GEBELIK_MANUEL_ERKEK__';
  v_padok_ad text;
  v_padok_id uuid;
  v_hata text;
BEGIN
  -- Erkek hayvan ancak Sağmal/Gebe dışı gruba girebilir (cinsiyet-grup guard);
  -- grup-padok senkron trigger'ı geçerli padok ister — referans fixture deseni.
  SELECT p.ad, g.padok_id INTO STRICT v_padok_ad, v_padok_id
    FROM public.grup_padok_eslem g
    JOIN public.padoklar p ON p.id = g.padok_id
   WHERE g.grup = 'Besi'
   ORDER BY p.ad
   LIMIT 1;

  INSERT INTO public.hayvanlar (id, kupe_no, grup, padok, padok_id, durum, cinsiyet)
  VALUES (v_erkek_id, v_erkek_id, 'Besi', v_padok_ad, v_padok_id, 'Aktif', 'Erkek');

  BEGIN
    PERFORM public.gebelik_kaydet_manual(v_erkek_id, CURRENT_DATE - 1, NULL);
    RAISE EXCEPTION 'Cinsiyet guard çalışmadı: erkek hayvana gebelik yazıldı';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'Sadece dişi%' THEN
      RAISE EXCEPTION 'Beklenmeyen hata: %', v_hata;
    END IF;
  END;

  RAISE NOTICE 'PASS: erkek hayvana gebelik reddi (cinsiyet guard)';
END
$test$;

DO $test$
DECLARE
  v_gebe_id text := '__TEST_GEBELIK_MANUEL_ZATEN_GEBE__';
  v_hata text;
BEGIN
  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum, cinsiyet)
  VALUES (v_gebe_id, v_gebe_id, 'Sağmal (Laktasyonda)', 'Aktif', 'Dişi');

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, deneme_no)
  VALUES (gen_random_uuid(), v_gebe_id, CURRENT_DATE - 30, 'ÖNCEKİ', 'Gebe', 1);

  BEGIN
    PERFORM public.gebelik_kaydet_manual(v_gebe_id, CURRENT_DATE - 1, NULL);
    RAISE EXCEPTION 'Aktif-gebe guard çalışmadı: ikinci gebelik yazıldı';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'Hayvanın aktif gebeliği%' THEN
      RAISE EXCEPTION 'Beklenmeyen hata: %', v_hata;
    END IF;
  END;

  RAISE NOTICE 'PASS: aktif gebelik varken ikinci gebelik reddi (guard)';
END
$test$;

ROLLBACK;
