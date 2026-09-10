-- 20260910000001_planli_tohumlama_sperma_dus.sql davranis testi (W1, BUG-001).
-- public.fn_sperma_stok_dus helper'ini doğrudan ölçer (lead kararı 398ff5c7:
-- M1 helper-only, planli_tohumlama_kaydet'e dokunulmaz):
--   K1 bos/boşluk/NULL ad → stok_hareket satırı YOK;
--   K2 exact urun_adi, superstring içeren üründen ÖNCE kazanır;
--   K3 exact yoksa substring ILIKE fallback çalışır;
--   K4 kategori='Sperma' kapsamı korunur (İlaç satırına sıçramaz);
--   K5 eşleşme yok → sessiz geçer;
--   her düşüm tam 1 ledger satırı (miktar=1, tur='Tohumlama', iptal=false).
-- Canlı/demo DB'de güvenlidir: tüm test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/sperma_stok_dus_test.sql

BEGIN;

DO $test$
DECLARE
  v_stok_exact_id   text := '__TEST_W1_STOK_EXACT__';
  v_stok_super_id   text := '__TEST_W1_STOK_SUPER__';
  v_stok_sub_id     text := '__TEST_W1_STOK_SUB__';
  v_stok_ilac_id    text := '__TEST_W1_STOK_ILAC__';
  v_n integer;
BEGIN
  -- Seed: exact ad + onun superstring'i + substring-hedef ürün + aynı adla
  -- Sperma OLMAYAN (İlaç) satır.
  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar)
  VALUES
    (v_stok_exact_id, 'TEST-SPERM-W1', 'Sperma', 5),
    (v_stok_super_id, 'TEST-SPERM-W1 PRO (üst yumuşatıcı)', 'Sperma', 5),
    (v_stok_sub_id,   'TEST-SPERM-W1 SUBSTR Ürün', 'Sperma', 5),
    (v_stok_ilac_id,  'TEST-SPERM-W1', 'İlaç', 5);

  -- K2: bilinen ad → exact satırdan düşer, superstring'e değil.
  PERFORM public.fn_sperma_stok_dus('TEST-SPERM-W1');

  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_exact_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'K2 exact dusum beklenen 1, gelen %', v_n;
  END IF;

  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_super_id;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K2 exact onceligi yok: superstring satirina % dusum gitti', v_n;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.stok_hareket
     WHERE stok_id = v_stok_exact_id AND miktar = 1 AND tur = 'Tohumlama' AND iptal = false
  ) THEN
    RAISE EXCEPTION 'K2 ledger satir sekli yanlis (tur/miktar/iptal)';
  END IF;

  -- K1: boş string / boşluk / NULL → hiçbir satır yok ('' → ILIKE '%%' kusuru).
  PERFORM public.fn_sperma_stok_dus('');
  PERFORM public.fn_sperma_stok_dus('   ');
  PERFORM public.fn_sperma_stok_dus(NULL);

  SELECT count(*) INTO v_n
    FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id)
     AND notlar <> 'Tohumlama — TEST-SPERM-W1';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K1 bos/bosluk/NULL ad % satir üretti', v_n;
  END IF;

  -- K3: exact eşleşme yok → substring ILIKE fallback tek satıra düşer.
  PERFORM public.fn_sperma_stok_dus('TEST-SPERM-W1 SUBSTR');

  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_sub_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'K3 substring fallback dusum beklenen 1, gelen %', v_n;
  END IF;

  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_super_id;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K3 substring fallback yanlis satira düstü (superstring)';
  END IF;

  -- K4: İlaç kategorisine asla düşüm gitmez.
  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_ilac_id;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K4 İlaç kategorisine % düşüm gitti', v_n;
  END IF;

  -- K5: eşleşmeyen ad sessizce geçer.
  PERFORM public.fn_sperma_stok_dus('HIC OLMAYAN URUN ADI XYZ');
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE notlar LIKE '%HIC OLMAYAN URUN ADI XYZ%';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K5 eşleşmeyen ad % satır üretti', v_n;
  END IF;

  -- Toplam: her düşüm 1 satır — iki çağrı, iki ledger satırı.
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'Toplam ledger satiri beklenen 2, gelen %', v_n;
  END IF;

  RAISE NOTICE 'TESTDONE:t';
END;
$test$;

ROLLBACK;
