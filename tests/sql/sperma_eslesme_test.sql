-- 20260910000002_sperma_eslesme_sertlestirme.sql davranis testi (W2, BUG-002).
-- Uçtan uca üç tohumlama yolunda ortak eşleşme kuralını ölçer:
--   K1 tohumlama_kaydet + bos ad ('') → stok_hareket satırı YOK;
--   K2 tohumlama_kaydet + bilinen ad → exact satırdan düşer, superstring'ten
--      değil; notlar canlıdaki gibi kupe_no taşır (tur='Tohumlama', miktar=1);
--   K3 tohumlama_tekrar_kaydet + bos ad → satır YOK;
--   K4 tohumlama_tekrar_kaydet + bilinen ad → exact satırdan düşer; notlar
--      'Tekrar Aşım N. deneme — <kupe_no>' (canlı formatta);
--   K5 planli_tohumlama_kaydet (delegasyon): bos ad → satır YOK; substring ad
--      → tam 1 düşüm, exact satır DOKUNULMAZ (çift-düşüm guard'ı);
--   K6 kategori kapsamı: İlaç satırına hiçbir yoldan düşüm gitmez.
-- Not: gövde denetimi (row shape) W1'in sperma_stok_dus_test.sql'de helper
-- düzeyinde; bu dosya çağrı yollarını (helper'a BAĞLANTIYI) ölçer.
-- Gereksinim: public.fn_sperma_stok_dus kurulu (M1+M2 sonrası).
-- Canlı/demo DB'de güvenlidir: tüm test verisi transaction sonunda ROLLBACK
-- edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/sperma_eslesme_test.sql

BEGIN;

DO $test$
DECLARE
  v_h1            text := '__TEST_W2_HAYVAN_KAYDET__';
  v_h2            text := '__TEST_W2_HAYVAN_TEKRAR__';
  v_h3            text := '__TEST_W2_HAYVAN_PLANLI__';
  v_stok_exact_id text := '__TEST_W2_STOK_EXACT__';
  v_stok_super_id text := '__TEST_W2_STOK_SUPER__';
  v_stok_sub_id   text := '__TEST_W2_STOK_SUB__';
  v_stok_ilac_id  text := '__TEST_W2_STOK_ILAC__';
  v_g1            uuid := gen_random_uuid();
  v_g2            uuid := gen_random_uuid();
  v_sonuc         jsonb;
  v_n             integer;
  v_notlar        text;
BEGIN
  -- Seed: üç hayvan (Dişi, Aktif; dogum_tarihi NULL → yaş/VWP kapısı atlanır),
  -- superstring + substring hedef satırlar exact'ten ÖNCE (B8: exact'i önce
  -- seed etmek, precedence'ini kaybetmiş LIMIT 1 mutantını gizleyebilirdi),
  -- testedilen adlarla çakışmayan TEKİL adlı İlaç satırı (B8: aynı adlı ikiz
  -- iki kategori seed'ini kafa karıştırıyordu),
  -- tekrar yolu için Bekliyor tohumlama, planlı yolu için 2 açık görev.
  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum, cinsiyet)
  VALUES
    (v_h1, 'W2-KUPE-11', 'Sağmal (Laktasyonda)', 'Aktif', 'Dişi'),
    (v_h2, 'W2-KUPE-22', 'Sağmal (Laktasyonda)', 'Aktif', 'Dişi'),
    (v_h3, 'W2-KUPE-33', 'Sağmal (Laktasyonda)', 'Aktif', 'Dişi');

  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar)
  VALUES
    (v_stok_super_id, 'TEST-SPERM-W2 PRO (üst yumuşatıcı)', 'Sperma', 5),
    (v_stok_sub_id,   'TEST-SPERM-W2 SUBSTR Ürün', 'Sperma', 5),
    (v_stok_ilac_id,  'TEST-ILAC-W2', 'İlaç', 5),
    (v_stok_exact_id, 'TEST-SPERM-W2', 'Sperma', 5);

  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, sonuc, deneme_no, deneme_sayisi, denemeler)
  VALUES
    (gen_random_uuid(), v_h2, CURRENT_DATE, 'TEST-SPERM-W2', 'Bekliyor', 1, 1, '[]'::jsonb);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal)
  VALUES
    (v_g1, v_h3, 'TOHUMLAMA_PLANLI', 'W2 test görevi 1', CURRENT_DATE, false, false);
  -- Not: v_g2 (K5b görevi) K5a'DAN SONRA açılır — canlıda kaydet, hayvana ait
  -- tüm açık TOHUMLAMA_PLANLI görevlerini kapattığı için önceden açılan ikinci
  -- görev "Görev kapalı" ile reddedilirdi (canlı davranış, test verisi değil).

  -- K1: tohumlama_kaydet + '' → hiçbir stok_hareket satırı.
  v_sonuc := public.tohumlama_kaydet(v_h1, CURRENT_DATE, '', NULL, NULL, '[]'::jsonb, false);
  IF COALESCE(v_sonuc->>'ok', '') <> 'true' THEN
    RAISE EXCEPTION 'K1: kaydet bos adla başarısız: %', v_sonuc;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K1: bos ad % düşüm üretti (0 beklenir)', v_n;
  END IF;

  -- K2: tohumlama_kaydet + exact ad → exact satır; superstring/sub/İlaç temiz.
  v_sonuc := public.tohumlama_kaydet(v_h1, CURRENT_DATE, 'TEST-SPERM-W2', NULL, NULL, '[]'::jsonb, false);
  IF COALESCE(v_sonuc->>'ok', '') <> 'true' THEN
    RAISE EXCEPTION 'K2: kaydet başarısız: %', v_sonuc;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_exact_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'K2: exact düşüm beklenen 1, gelen %', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K2: exact onceligi yok ya da İlaç kategorisine sızdı (% satır)', v_n;
  END IF;
  SELECT notlar INTO v_notlar FROM public.stok_hareket WHERE stok_id = v_stok_exact_id;
  IF v_notlar <> 'Tohumlama — W2-KUPE-11' THEN
    RAISE EXCEPTION 'K2: notlar canlı formatta değil: <%>', v_notlar;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.stok_hareket
                  WHERE stok_id = v_stok_exact_id AND tur = 'Tohumlama'
                    AND miktar = 1 AND iptal = false) THEN
    RAISE EXCEPTION 'K2: ledger satır şekli yanlış (tur/miktar/iptal)';
  END IF;

  -- K3: tekrar yolu + '' → hiçbir satır yok (canlıda rastgele düşen kusur).
  v_sonuc := public.tohumlama_tekrar_kaydet(v_h2, CURRENT_DATE, '');
  IF COALESCE(v_sonuc->>'ok', '') <> 'true' THEN
    RAISE EXCEPTION 'K3: tekrar bos adla başarısız: %', v_sonuc;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'K3: bos ad tekrar yolunda düşüm üretti (toplam 1 beklenir, gelen %)', v_n;
  END IF;

  -- K4: tekrar yolu + exact ad → exact satır; notlar canlı tekrar formatında.
  v_sonuc := public.tohumlama_tekrar_kaydet(v_h2, CURRENT_DATE, 'TEST-SPERM-W2');
  IF COALESCE(v_sonuc->>'ok', '') <> 'true' THEN
    RAISE EXCEPTION 'K4: tekrar başarısız: %', v_sonuc;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_exact_id;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'K4: exact toplam beklenen 2, gelen %', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'K4: yanlış satıra düşüm (% satır)', v_n;
  END IF;
  SELECT notlar INTO v_notlar FROM public.stok_hareket
   WHERE stok_id = v_stok_exact_id AND notlar LIKE 'Tekrar Aşım %';
  -- Not: K3'teki boş-ad tekrar çağrısı deneme sayısını zaten 1→2 artırdı
  -- (düşüm dışındaki adımlar canlı davranışıyla aynı kalır); K4 → 3. deneme.
  IF v_notlar <> 'Tekrar Aşım 3. deneme — W2-KUPE-22' THEN
    RAISE EXCEPTION 'K4: tekrar notlar canlı formatta değil: <%>', v_notlar;
  END IF;

  -- K5a: planlı yol (delegasyon) + '' → görev tamamlanır ama düşüm YOK.
  v_sonuc := public.planli_tohumlama_kaydet(v_g1, v_h3, CURRENT_DATE, '', NULL, NULL, '[]'::jsonb, false);
  IF COALESCE(v_sonuc->>'ok', '') <> 'true' THEN
    RAISE EXCEPTION 'K5a: planli bos adla başarısız: %', v_sonuc;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'K5a: planli bos adla düşüm üretti (toplam 2 beklenir, gelen %)', v_n;
  END IF;

  -- K5b: planlı yol + substring ad → tam 1 düşüm; exact DOKUNULMAZ
  -- (planli kaydet'in kendisinin ikinci bir düşüm EKLEMEDİĞİNİN kanıtı).
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal)
  VALUES
    (v_g2, v_h3, 'TOHUMLAMA_PLANLI', 'W2 test görevi 2', CURRENT_DATE, false, false);
  v_sonuc := public.planli_tohumlama_kaydet(v_g2, v_h3, CURRENT_DATE, 'TEST-SPERM-W2 SUBSTR', NULL, NULL, '[]'::jsonb, false);
  IF COALESCE(v_sonuc->>'ok', '') <> 'true' THEN
    RAISE EXCEPTION 'K5b: planli başarısız: %', v_sonuc;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_sub_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'K5b: substring düşüm beklenen 1, gelen %', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE stok_id = v_stok_exact_id;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'K5b: exact satır planlı yoldan etkilendi (2 beklenir, gelen %) — çift düşüm?', v_n;
  END IF;
  SELECT notlar INTO v_notlar FROM public.stok_hareket WHERE stok_id = v_stok_sub_id;
  IF v_notlar <> 'Tohumlama — W2-KUPE-33' THEN
    RAISE EXCEPTION 'K5b: notlar canlı formatta değil: <%>', v_notlar;
  END IF;

  -- K6: toplam denge — üç düşüm çağrısı, üç ledger satırı; superstring ve
  -- İlaç satırları baştan sona temiz.
  SELECT count(*) INTO v_n FROM public.stok_hareket
   WHERE stok_id IN (v_stok_exact_id, v_stok_super_id, v_stok_sub_id, v_stok_ilac_id);
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'K6: toplam ledger beklenen 3, gelen %', v_n;
  END IF;

  RAISE NOTICE 'TESTDONE:t';
END;
$test$;

ROLLBACK;
