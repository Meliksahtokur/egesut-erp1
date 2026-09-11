-- 20260911000001_dogum_buzagi_id_foundation.sql davranis testi (Task 0.5, gate G0b).
-- Canli/yerel DB'de guvenlidir: tum test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/dogum_buzagi_id_test.sql
-- Kapsam: unique ihlali reddi / SET NULL davranisi / konservatif backfill 4 sinifi
--         (migration'in GERCEK _dogum_buzagi_backfill() fonksiyonu uzerinden) /
--         dogum_kaydet ayni-transaction yazimi / D53 postpartum regresyonu (8+7).

BEGIN;

DO $test$
DECLARE
  v_fail      integer := 0;
  v_res       jsonb;
  v_calf      text;
  v_dogum_id  uuid;
  v_tmp       text;
  v_cnt       integer;
  v_sayac_json jsonb;
BEGIN
  ------------------------------------------------------------------
  -- FIXTURE'lar (__W1T_ ad-uzayi — gercek veriyle cakisma yok)
  ------------------------------------------------------------------
  INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi)
  VALUES ('__W1T_ANNE', '__W1T_ANNE_KUPE', 'Hint', 'Dişi', 'Test Grup', 'Test Padok', 'Aktif', DATE '2024-01-01');

  ------------------------------------------------------------------
  -- TEST 1: dogum_kaydet ayni transaction'da buzagi_id yazar
  ------------------------------------------------------------------
  v_res := public.dogum_kaydet('__W1T_ANNE', CURRENT_DATE, '__W1T_K1', 'Dişi', 'Normal', 35, '__W1T_BABA', NULL);
  IF v_res->>'ok' IS DISTINCT FROM 'true' THEN
    RAISE NOTICE 'FAIL T1a: dogum_kaydet ok!=true: %', v_res;
    v_fail := v_fail + 1;
  ELSE
    v_calf     := v_res->>'buzagi_id';
    v_dogum_id := (v_res->>'dogum_id')::uuid;

    SELECT d.buzagi_id INTO v_tmp FROM public.dogum d WHERE d.id = v_dogum_id;
    IF v_tmp IS DISTINCT FROM v_calf THEN
      RAISE NOTICE 'FAIL T1b: dogum.buzagi_id (%) != RPC buzagi_id (%)', v_tmp, v_calf;
      v_fail := v_fail + 1;
    END IF;

    SELECT h.kupe_no INTO v_tmp FROM public.hayvanlar h WHERE h.id = v_calf;
    IF v_tmp IS DISTINCT FROM '__W1T_K1' THEN
      RAISE NOTICE 'FAIL T1c: calf kaydi yok / kupe uyusmuyor: %', v_tmp;
      v_fail := v_fail + 1;
    END IF;
    RAISE NOTICE 'T1 OK: dogum_kaydet buzagi_id=% yazdi (dogum=%)', v_calf, v_dogum_id;
  END IF;

  ------------------------------------------------------------------
  -- TEST 2: partial unique — ayni buzagi_id ikinci dogum satirina yazilamaz
  ------------------------------------------------------------------
  BEGIN
    INSERT INTO public.dogum (anne_id, tarih, yavru_kupe, buzagi_id)
    VALUES ('__W1T_ANNE', CURRENT_DATE, '__W1T_K2', v_calf);
    RAISE NOTICE 'FAIL T2a: unique ihlali YAKALANMADI (23505 bekleniyordu)';
    v_fail := v_fail + 1;
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'T2 OK: unique ihlali reddedildi (23505)';
  END;

  ------------------------------------------------------------------
  -- TEST 3: ON DELETE SET NULL — calf silinir, dogum kaydi KALIR, bag NULL olur
  ------------------------------------------------------------------
  INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi)
  VALUES ('__W1T_CALF3', '__W1T_K3', 'Hint', 'Dişi', 'Test Grup', 'Test Padok', 'Aktif', DATE '2024-06-10');
  INSERT INTO public.dogum (anne_id, tarih, yavru_kupe, buzagi_id)
  VALUES ('__W1T_ANNE', DATE '2024-06-10', '__W1T_K3', '__W1T_CALF3');

  DELETE FROM public.hayvanlar WHERE id = '__W1T_CALF3';

  SELECT d.buzagi_id INTO v_tmp FROM public.dogum d
   WHERE d.anne_id = '__W1T_ANNE' AND d.yavru_kupe = '__W1T_K3';
  IF v_tmp IS NOT NULL THEN
    RAISE NOTICE 'FAIL T3a: calf DELETE sonrasi buzagi_id NULL olmali, gelen: %', v_tmp;
    v_fail := v_fail + 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.dogum d
                 WHERE d.anne_id = '__W1T_ANNE' AND d.yavru_kupe = '__W1T_K3') THEN
    RAISE NOTICE 'FAIL T3b: dogum kaydi silinmis — SET NULL beklenirken kayit kalmaliydi';
    v_fail := v_fail + 1;
  ELSE
    RAISE NOTICE 'T3 OK: calf DELETE -> dogum kaldi, buzagi_id NULL';
  END IF;

  ------------------------------------------------------------------
  -- TEST 4: konservatif backfill — 4 sinif (migration DO blogu ile ayni mantik)
  ------------------------------------------------------------------
  -- (a) auto + cok-aday(claim-cakisma): TEK hayvanlar adayi, ama ayni calf'i iki dogum
  --     satiri istiyor. NOT: hayvanlar.kupe_no tam unique oldugu icin (uq_hayvanlar_kupe_no)
  --     "cok-aday" sinifinin canli verideki tek gercek kaynagi claim-cakismasidir.
  INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi)
  VALUES ('__W1T_BF1CALF', '__W1T_BF1', 'Hint', 'Dişi', 'Test Grup', 'Test Padok', 'Aktif', DATE '2024-06-01');
  INSERT INTO public.dogum (anne_id, tarih, yavru_kupe)
  VALUES ('__W1T_ANNE', DATE '2024-06-01', '__W1T_BF1');
  INSERT INTO public.dogum (anne_id, tarih, yavru_kupe)
  VALUES ('__W1T_ANNE', DATE '2024-06-01', '__W1T_BF1');
  -- (c) tarih-uyumsuz: TEK aday ama dogum_tarihi farkli
  INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi)
  VALUES ('__W1T_BF3CALF', '__W1T_BF3', 'Hint', 'Erkek', 'Test Grup', 'Test Padok', 'Aktif', DATE '2024-08-02');
  INSERT INTO public.dogum (anne_id, tarih, yavru_kupe)
  VALUES ('__W1T_ANNE', DATE '2024-08-01', '__W1T_BF3');
  -- (d) aday-yok: kupe ile eslesen hayvanlar yok
  INSERT INTO public.dogum (anne_id, tarih, yavru_kupe)
  VALUES ('__W1T_ANNE', DATE '2024-09-01', '__W1T_BF4');

  -- root-gate F3 duzeltmesi: artik KOPYA yok — migration'in GERCEK ic fonksiyonu
  -- (_dogum_buzagi_backfill, 20260911000001 ile gelen) cagiriliyor
  v_sayac_json := public._dogum_buzagi_backfill();
  IF v_sayac_json IS NULL OR v_sayac_json ? 'auto' IS NOT TRUE
     OR v_sayac_json ? 'cok-aday' IS NOT TRUE THEN
    RAISE NOTICE 'FAIL T4pre: _dogum_buzagi_backfill sayac jsonb donmedi: %', v_sayac_json;
    v_fail := v_fail + 1;
  ELSE
    RAISE NOTICE 'T4 OK-ust: gercek backfill fonksiyonu cagrildi, sayaclar: %', v_sayac_json;
  END IF;

  -- auto-aday ciftinden TAM BIRI yazilmali (loop sirasi belirsiz; ikisi de ayni calf'i hedefler)
  SELECT count(*) INTO v_cnt FROM public.dogum d
   WHERE d.anne_id='__W1T_ANNE' AND d.yavru_kupe='__W1T_BF1' AND d.tarih=DATE '2024-06-01'
     AND d.buzagi_id IS NOT NULL;
  IF v_cnt <> 1 THEN
    RAISE NOTICE 'FAIL T4b: auto sinifi — beklenen tam 1 auto, gelen: %', v_cnt;
    v_fail := v_fail + 1;
  ELSE
    RAISE NOTICE 'T4b OK: auto sinifi — ayni calf isteyen ciftten yalniz biri yazildi';
  END IF;

  -- ciftin digeri (claim-cakisma -> cok-aday) NULL kalmali
  SELECT count(*) INTO v_cnt FROM public.dogum d
   WHERE d.anne_id='__W1T_ANNE' AND d.yavru_kupe='__W1T_BF1' AND d.tarih=DATE '2024-06-01'
     AND d.buzagi_id IS NULL;
  IF v_cnt <> 1 THEN
    RAISE NOTICE 'FAIL T4c: cok-aday (claim-cakisma) — beklenen tam 1 NULL, gelen: %', v_cnt;
    v_fail := v_fail + 1;
  ELSE
    RAISE NOTICE 'T4c OK: cok-aday (claim-cakisma) NULL kaldi';
  END IF;

  SELECT d.buzagi_id INTO v_tmp FROM public.dogum d
   WHERE d.anne_id='__W1T_ANNE' AND d.yavru_kupe='__W1T_BF3';
  IF v_tmp IS NOT NULL THEN
    RAISE NOTICE 'FAIL T4d: tarih-uyumsuz sinifi NULL kalmaliydi, gelen: %', v_tmp;
    v_fail := v_fail + 1;
  ELSE
    RAISE NOTICE 'T4d OK: tarih-uyumsuz NULL kaldi';
  END IF;

  SELECT d.buzagi_id INTO v_tmp FROM public.dogum d
   WHERE d.anne_id='__W1T_ANNE' AND d.yavru_kupe='__W1T_BF4';
  IF v_tmp IS NOT NULL THEN
    RAISE NOTICE 'FAIL T4e: aday-yok sinifi NULL kalmaliydi, gelen: %', v_tmp;
    v_fail := v_fail + 1;
  ELSE
    RAISE NOTICE 'T4e OK: aday-yok NULL kaldi';
  END IF;

  ------------------------------------------------------------------
  -- TEST 5 (root-gate F2 regresyonu): dogum_kaydet D53 postpartum davranisi
  -- — 8+7 gorev_sayisi, '53. Gun: E Vitamini' VAR, eski Ademin/Yeldif d53/d54 YOK
  ------------------------------------------------------------------
  INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi)
  VALUES ('__W1T_ANNE2', '__W1T_ANNE2_KUPE', 'Hint', 'Dişi', 'Test Grup', 'Test Padok', 'Aktif', DATE '2023-01-01');

  v_res := public.dogum_kaydet('__W1T_ANNE2', DATE '2025-01-10', '__W1T_K5', 'Dişi', 'Normal', 36, '__W1T_BABA2', NULL);
  IF v_res->>'ok' IS DISTINCT FROM 'true' THEN
    RAISE NOTICE 'FAIL T5a: dogum_kaydet ok!=true: %', v_res;
    v_fail := v_fail + 1;
  ELSE
    IF v_res->>'gorev_sayisi' IS DISTINCT FROM '15' THEN
      RAISE NOTICE 'FAIL T5b: gorev_sayisi 8+7=15 olmali (eski 10+7 govde isareti), gelen: %', v_res->>'gorev_sayisi';
      v_fail := v_fail + 1;
    ELSE
      RAISE NOTICE 'T5b OK: gorev_sayisi=15 (anne 8 + buzagi 7)';
    END IF;

    SELECT count(*) INTO v_cnt FROM public.gorev_log
     WHERE hayvan_id = '__W1T_ANNE2' AND aciklama = '53. Gün: E Vitamini'
       AND gorev_tipi = 'ILAC' AND etken_kod = 'E_VIT';
    IF v_cnt <> 1 THEN
      RAISE NOTICE 'FAIL T5c: tek adet 53. Gun E Vitamini (E_VIT) beklenirdi, gelen: %', v_cnt;
      v_fail := v_fail + 1;
    ELSE
      RAISE NOTICE 'T5c OK: 53. Gun E Vitamini gorevi var (tek adet, E_VIT)';
    END IF;

    SELECT count(*) INTO v_cnt FROM public.gorev_log
     WHERE hayvan_id = '__W1T_ANNE2' AND kaynak = 'DOGUM-__W1T_ANNE2'
       AND aciklama IN ('53. Gün: Ademin', '53. Gün: Yeldif', '54. Gün: Yeldif');
    IF v_cnt <> 0 THEN
      RAISE NOTICE 'FAIL T5d: kaldirilan eski d53/d54 gorevleri geri geldi (% adet)', v_cnt;
      v_fail := v_fail + 1;
    ELSE
      RAISE NOTICE 'T5d OK: eski 53.Ademin / 53.Yeldif / 54.Yeldif gorevleri YOK';
    END IF;

    SELECT count(*) INTO v_cnt FROM public.gorev_log
     WHERE hayvan_id = '__W1T_ANNE2' AND kaynak = 'DOGUM-__W1T_ANNE2';
    IF v_cnt <> 8 THEN
      RAISE NOTICE 'FAIL T5e: anne gorev sayisi 8 olmali, gelen: %', v_cnt;
      v_fail := v_fail + 1;
    ELSE
      RAISE NOTICE 'T5e OK: anne gorev listesi 8 satir (D53 listesi)';
    END IF;
  END IF;

  ------------------------------------------------------------------
  -- SONUC
  ------------------------------------------------------------------
  IF v_fail > 0 THEN
    RAISE EXCEPTION 'W1T: % TEST BASARISIZ', v_fail;
  END IF;
  RAISE NOTICE 'W1T: TUM TESTLER GECTI';
END
$test$;

ROLLBACK;
