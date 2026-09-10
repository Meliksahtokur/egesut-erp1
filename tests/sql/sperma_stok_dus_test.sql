-- 20260910000001_planli_tohumlama_sperma_dus.sql davranis testi (W1, BUG-001;
-- W2b ile B6 whitespace + B8 seed düzeni eklendi).
-- public.fn_sperma_stok_dus helper'ini doğrudan ölçer (lead kararı 398ff5c7:
-- M1 helper-only, planli_tohumlama_kaydet'e dokunulmaz):
--   K1 bos/boşluk/NULL/tab/newline ad → stok_hareket satırı YOK;
--   K2 exact urun_adi, superstring içeren üründen ÖNCE kazanır;
--   K3 exact yoksa substring ILIKE fallback çalışır;
--   K4 kategori='Sperma' kapsamı korunur (İlaç ADIYLA negatif çağrı);
--   K5 eşleşme yok → sessiz geçer;
--   her düşüm tam 1 ledger satırı (miktar=1, tur='Tohumlama', iptal=false).
-- Mutant taraması notu (B8): superstring/substring satırları exact'ten ÖNCE
-- seed edilir — exact-precedence'i kaybetmiş bir mutant ilk Sperma satırını
-- (superstring) seçer ve K2 onu yakalar; exact'i önce seed etmek bu mutantı
-- gizleyebilirdi (LIMIT 1 sıralamasız seçimde ilk satır kazanma eğiliminde).
-- İlaç negatifi (B8): aynı adlı ikiz yerine testedilen adlarla çakışmayan
-- TEKİL adlı ('TEST-ILAC-W1') İlaç satırı + o adla yapılan negatif çağrı —
-- kategori filtresini düşmüş mutant bu çağrıda İlaç satırına düşer, K4 yakalar.
-- Canlı/demo DB'de güvenlidir: tüm test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/sperma_stok_dus_test.sql

BEGIN;

DO $test$
DECLARE
  v_stok_exact_id   text := '__TEST_W1_STOK_EXACT__';
  v_stok_super_id   text := '__TEST_W1_STOK_SUPER__';
  v_stok_sub_id     text := '__TEST_W1_STOK_SUB__';
  v_stok_ilac_id    text := '__TEST_W1_STOK_ILAC__';
  v_n             integer;
  v_toplam_once  integer;
  v_toplam_sonra integer;
BEGIN
  -- Seed (B8 sırası): superstring + substring-hedef satırlar exact'ten ÖNCE;
  -- İlaç satırı tekil adlı (testedilen sperma adlarının hiçbiriyle
  -- exact/substring çakışmaz).
  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar)
  VALUES
    (v_stok_super_id, 'TEST-SPERM-W1 PRO (üst yumuşatıcı)', 'Sperma', 5),
    (v_stok_sub_id,   'TEST-SPERM-W1 SUBSTR Ürün', 'Sperma', 5),
    (v_stok_ilac_id,  'TEST-ILAC-W1', 'İlaç', 5),
    (v_stok_exact_id, 'TEST-SPERM-W1', 'Sperma', 5);

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

  -- K1: boş string / boşluk / NULL / tab / newline / CR / CRLF → hiçbir satır yok
  -- ('' → ILIKE '%%' kusuru; tab/newline/CR/CRLF → btrim'in kaçırdığı
  -- whitespace sınıfı, B6 guard'ının fixture karşılığı; CR/CRLF root-gate F5).
  -- F3 (root-gate): GLOBAL invariant — toplam stok_hareket sayısı değişmez.
  -- Seed-ID sayımı mutantın MEVCUT (seed-dışı) Sperma satırına yazmasını
  -- göremez; toplam delta=0 bunu bağımsız kanıtlar.
  SELECT count(*) INTO v_toplam_once FROM public.stok_hareket;
  PERFORM public.fn_sperma_stok_dus('');
  PERFORM public.fn_sperma_stok_dus('   ');
  PERFORM public.fn_sperma_stok_dus(NULL);
  PERFORM public.fn_sperma_stok_dus(E'\t');
  PERFORM public.fn_sperma_stok_dus(E'\n  ');
  PERFORM public.fn_sperma_stok_dus(E'\r');
  PERFORM public.fn_sperma_stok_dus(E'\r\n');
  SELECT count(*) INTO v_toplam_sonra FROM public.stok_hareket;
  IF v_toplam_sonra <> v_toplam_once THEN
    RAISE EXCEPTION 'F3: bos-girdi TOPLAM stok_hareket delta % <> 0 (mutant seed-disi satira yazmis olabilir)', v_toplam_sonra - v_toplam_once;
  END IF;

  SELECT count(*) INTO v_n
    FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id)
     AND notlar <> 'Tohumlama — TEST-SPERM-W1';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K1 bos/bosluk/NULL/tab/newline/CR ad % satir üretti', v_n;
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

  -- K4: İlaç kategorisine asla düşüm gitmez — İlaç ADIYLA negatif çağrı;
  -- kategori filtresini düşmüş mutant bu çağrıda İlaç satırına düşer ve
  -- burada yakalanır (B8: negatif test artık pasif değil, deterministik).
  PERFORM public.fn_sperma_stok_dus('TEST-ILAC-W1');
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

  -- Toplam: her düşüm 1 satır — iki düşüm çağrısı (K2, K3), iki ledger satırı;
  -- boş-ad/negatif çağrıların (K1, K4, K5) hiçbiri satır eklemez.
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'Toplam ledger satiri beklenen 2, gelen %', v_n;
  END IF;

  RAISE NOTICE 'TESTDONE:t';
END;
$test$;

ROLLBACK;
