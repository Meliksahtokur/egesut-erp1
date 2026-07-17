-- 20260717000001_hayvan_grup_padok_sync.sql davranis testi.
-- Canli/yerel DB'de guvenlidir: tum test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/hayvan_grup_padok_sync_test.sql

BEGIN;

DO $test$
DECLARE
  v_hayvan_id text := '__TEST_GRUP_PADOK_SYNC__';
  v_buzagi_id text := '__TEST_GRUP_PADOK_BUZAGI__';
  v_besi_id text := '__TEST_GRUP_PADOK_BESI__';
  v_gorev_id uuid := gen_random_uuid();
  v_sagmal_id uuid;
  v_kuru_id uuid;
  v_buzagi_padok_id uuid;
  v_besi_padok_id uuid;
  v_besi_padok_ad text;
  v_besi_eslem_sayisi integer;
  v_sonuc jsonb;
  v_satir record;
  v_hata_yakalandi boolean := false;
BEGIN
  SELECT id INTO STRICT v_sagmal_id FROM public.padoklar WHERE ad = 'Sağmal Padok';
  SELECT id INTO STRICT v_kuru_id FROM public.padoklar WHERE ad = 'Kuru/Gebe Padok';
  SELECT id INTO STRICT v_buzagi_padok_id FROM public.padoklar WHERE ad = 'Buzağı Padok (Süt İçenler)';

  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum)
  VALUES (v_hayvan_id, '__TEST_GRUP_PADOK_SYNC__', 'Sağmal (Laktasyonda)', 'Aktif');

  SELECT grup, padok, padok_id INTO STRICT v_satir
    FROM public.hayvanlar WHERE id = v_hayvan_id;
  IF v_satir.padok <> 'Sağmal Padok' OR v_satir.padok_id IS DISTINCT FROM v_sagmal_id THEN
    RAISE EXCEPTION 'Tekil grup INSERT senkronu basarisiz';
  END IF;

  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum)
  VALUES (v_buzagi_id, '__TEST_GRUP_PADOK_BUZAGI__', 'Süt İçen Buzağı', 'Aktif');

  SELECT padok, padok_id INTO STRICT v_satir
    FROM public.hayvanlar WHERE id = v_buzagi_id;
  IF v_satir.padok <> 'Buzağı Padok (Süt İçenler)'
     OR v_satir.padok_id IS DISTINCT FROM v_buzagi_padok_id THEN
    RAISE EXCEPTION 'Buzagi INSERT senkronu basarisiz';
  END IF;

  SELECT count(*)::integer INTO v_besi_eslem_sayisi
    FROM public.grup_padok_eslem WHERE grup = 'Besi';
  IF v_besi_eslem_sayisi < 2 THEN
    RAISE EXCEPTION 'Besi coklu padok fixture eksik';
  END IF;

  SELECT g.padok_id, p.ad INTO STRICT v_besi_padok_id, v_besi_padok_ad
    FROM public.grup_padok_eslem g
    JOIN public.padoklar p ON p.id = g.padok_id
   WHERE g.grup = 'Besi'
   ORDER BY p.ad
   LIMIT 1;

  INSERT INTO public.hayvanlar (id, kupe_no, grup, padok, padok_id, durum)
  VALUES (v_besi_id, '__TEST_GRUP_PADOK_BESI__', 'Besi', v_besi_padok_ad, v_besi_padok_id, 'Aktif');

  SELECT padok, padok_id INTO STRICT v_satir
    FROM public.hayvanlar WHERE id = v_besi_id;
  IF v_satir.padok <> v_besi_padok_ad OR v_satir.padok_id IS DISTINCT FROM v_besi_padok_id THEN
    RAISE EXCEPTION 'Besi acik padok secimi korunmadi';
  END IF;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
  VALUES
    (v_gorev_id, v_hayvan_id, 'PADOK_DEGISIM', 'Kuru döneme geçiş testi', CURRENT_DATE, false, 'Kuru/Gebe Padok');

  v_sonuc := public.gorev_tamamla(v_gorev_id::text, NULL);
  IF NOT COALESCE((v_sonuc->>'ok')::boolean, false)
     OR NOT COALESCE((v_sonuc->>'padok_guncellendi')::boolean, false) THEN
    RAISE EXCEPTION 'Kuru gorev RPC sonucu basarisiz: %', v_sonuc;
  END IF;

  SELECT grup, padok, padok_id INTO STRICT v_satir
    FROM public.hayvanlar WHERE id = v_hayvan_id;
  IF v_satir.grup <> 'Sağmal (Kuru)'
     OR v_satir.padok <> 'Kuru/Gebe Padok'
     OR v_satir.padok_id IS DISTINCT FROM v_kuru_id THEN
    RAISE EXCEPTION 'Kuru gorev atomik grup/padok gecisi basarisiz';
  END IF;

  UPDATE public.hayvanlar
     SET grup = 'Sağmal (Laktasyonda)'
   WHERE id = v_hayvan_id;

  SELECT grup, padok, padok_id INTO STRICT v_satir
    FROM public.hayvanlar WHERE id = v_hayvan_id;
  IF v_satir.padok <> 'Sağmal Padok' OR v_satir.padok_id IS DISTINCT FROM v_sagmal_id THEN
    RAISE EXCEPTION 'Grup degisimi sonrasi otomatik padok senkronu basarisiz';
  END IF;

  BEGIN
    UPDATE public.hayvanlar
       SET padok = 'Kuru/Gebe Padok', padok_id = v_kuru_id
     WHERE id = v_hayvan_id;
  EXCEPTION WHEN check_violation THEN
    v_hata_yakalandi := true;
  END;

  IF NOT v_hata_yakalandi THEN
    RAISE EXCEPTION 'Uyumsuz padok degisikligi reddedilmedi';
  END IF;

  RAISE NOTICE 'TESTDONE:t';
END;
$test$;

ROLLBACK;
