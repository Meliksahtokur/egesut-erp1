-- tests/sql/dogum_kupe_recycle_test.sql — K1 recycle + buzağı id çakışması kilidi (2026-10-30).
-- HEDEF: YALNIZ yerel izole parite DB (db-build-baseline.sh çıktısı). Canlıya (demo/prod) bu betikle erişilmez.
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/dogum_kupe_recycle_test.sql → rc=0 hepsi PASS; rc!=0 en az biri RED.
-- Fixture + yan etkiler tek transaction'da, sonda ROLLBACK.
\echo '=== DOGUM KUPE RECYCLE — izole DB testi ==='
BEGIN;
CREATE TEMP TABLE _sonuc (ad text, durum text, detay text) ON COMMIT DROP;
CREATE FUNCTION pg_temp.yaz(a text, kosul boolean, d text DEFAULT '') RETURNS void LANGUAGE sql
  AS $$ INSERT INTO _sonuc VALUES (a, CASE WHEN kosul THEN 'PASS' ELSE 'FAIL' END, d) $$;

INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi) VALUES
  ('__T3_ANNE', '__T3_ANNE_K', 'Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01'),
  ('__T3_ANNE2','__T3_ANNE2_K','Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01'),
  ('__T3_AKTIF','__T3_AKTIF_K','Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01'),
  ('__T6_ANNE', '__T6_ANNE_K', 'Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01'),
  ('__T6_ANNE2','__T6_ANNE2_K','Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01');
INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi, cikis_tipi, cikis_tarihi) VALUES
  ('__T3_OLU', '__T3_OLU_K', 'Holstein', 'Erkek', 'Besi', 'Besi Padok', 'Ölü', DATE '2024-01-01', 'Ölüm', DATE '2026-01-01');

DO $test$
DECLARE
  v_res jsonb; v_h record; v_say integer; v_ad text; v_n integer; v_a text; v_b text; v_kisit text;
BEGIN
  -- T1: ölü hayvanın küpesi doğumda yeniden kullanılır (K1)
  BEGIN
    v_res := public.dogum_kaydet('__T3_ANNE', DATE '2026-10-01', '__T3_OLU_K', 'Erkek');
    PERFORM pg_temp.yaz('T1a olu kupeyle dogum gecer', (v_res->>'ok')::boolean, v_res::text);
    SELECT count(*) INTO v_say FROM public.hayvanlar WHERE kupe_no = '__T3_OLU_K';
    PERFORM pg_temp.yaz('T1b ayni kupe iki satirda (olu+aktif)', v_say = 2, 'satir=' || v_say);
    SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_res->>'buzagi_id';
    PERFORM pg_temp.yaz('T1c yeni buzagi aktif ve kupeli',
      v_h.durum = 'Aktif' AND v_h.kupe_no = '__T3_OLU_K', coalesce(v_h.durum, 'yok'));
    PERFORM pg_temp.yaz('T1d buzagi id uuid bicimli',
      (v_res->>'buzagi_id') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', v_res->>'buzagi_id');
    PERFORM pg_temp.yaz('T1e dogum.buzagi_id ayni transaction baglandi',
      EXISTS (SELECT 1 FROM public.dogum WHERE id = (v_res->>'dogum_id')::uuid AND buzagi_id = v_res->>'buzagi_id'), '');
    PERFORM pg_temp.yaz('T1f gorev sayisi 8 anne + 7 buzagi',
      (SELECT count(*) FROM public.gorev_log WHERE hayvan_id IN ('__T3_ANNE', v_res->>'buzagi_id')) = 15,
      v_res->>'gorev_sayisi');
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.yaz('T1 olu kupeyle dogum', false, SQLSTATE || ' ' || SQLERRM);
  END;

  -- T2: aktif hayvanın küpesi doğumda reddedilir (K3 RPC ayağı)
  BEGIN
    v_res := public.dogum_kaydet('__T3_ANNE2', DATE '2026-10-01', '__T3_AKTIF_K', 'Dişi');
    PERFORM pg_temp.yaz('T2 aktif kupe red',
      (v_res->>'ok')::boolean = false AND v_res->>'mesaj' LIKE 'Bu küpe zaten kayıtlı%', v_res::text);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.yaz('T2 aktif kupe red', false, SQLSTATE || ' ' || SQLERRM);
  END;

  -- T3: DB ayağı — iki AKTİF aynı küpe partial index ile reddedilir (K3 korunur)
  v_kisit := NULL;
  BEGIN
    INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi)
    VALUES ('__T3_CIFT', '__T3_AKTIF_K', 'Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01');
    v_kisit := 'yok';
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_kisit = CONSTRAINT_NAME;
  END;
  PERFORM pg_temp.yaz('T3 iki aktif ayni kupe DB red', v_kisit = 'hayvanlar_kupe_no_key', coalesce(v_kisit, 'null'));

  -- T4: ölü hayvan geri aktife alınamaz, küpesi başka aktifteyse (K3, recycle sonrası yeni durum)
  v_kisit := NULL;
  BEGIN
    UPDATE public.hayvanlar SET durum = 'Aktif', cikis_tipi = NULL, cikis_tarihi = NULL WHERE id = '__T3_OLU';
    v_kisit := 'yok';
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_kisit = CONSTRAINT_NAME;
  END;
  PERFORM pg_temp.yaz('T4 geri aktife alma cakisma red', v_kisit = 'hayvanlar_kupe_no_key', coalesce(v_kisit, 'null'));

  -- T5: hard DELETE sonrası doğum geçer. COUNT(*)+1 üretimi bu dizilimde dolu id üretirdi:
  -- sayı n iken H(n+1) ve H(n+2) eklenir, H(n+1) silinir → sayı n+1, "sıradaki" = H(n+2) = dolu.
  SELECT count(*) INTO v_n FROM public.hayvanlar;
  v_a := 'H' || lpad((v_n + 1)::text, 6, '0');
  v_b := 'H' || lpad((v_n + 2)::text, 6, '0');
  INSERT INTO public.hayvanlar (id, kupe_no, irk, cinsiyet, grup, padok, durum, dogum_tarihi)
  VALUES (v_a, '__T3_SIL_A', 'Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01'),
         (v_b, '__T3_SIL_B', 'Holstein', 'Dişi', 'Sağmal (Kuru)', 'Kuru Padok', 'Aktif', DATE '2022-01-01');
  DELETE FROM public.hayvanlar WHERE id = v_a;
  BEGIN
    v_res := public.dogum_kaydet('__T3_ANNE2', DATE '2026-10-02', '__T3_YENI_K', 'Dişi');
    PERFORM pg_temp.yaz('T5 DELETE sonrasi dogum gecer', (v_res->>'ok')::boolean, v_res::text);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.yaz('T5 DELETE sonrasi dogum gecer', false, SQLSTATE || ' ' || SQLERRM);
  END;

  -- T6: eski tam unique index gitmiş, partial index duruyor
  PERFORM pg_temp.yaz('T6a uq_hayvanlar_kupe_no yok', to_regclass('public.uq_hayvanlar_kupe_no') IS NULL, '');
  PERFORM pg_temp.yaz('T6b hayvanlar_kupe_no_key var', to_regclass('public.hayvanlar_kupe_no_key') IS NOT NULL, '');

  -- T7 (sahip 2026-10-31): aynı anne, ölen yavrusunun küpesini yeni yavruya verir; aktif yavrunun küpesini veremez
  BEGIN
    v_res := public.dogum_kaydet('__T6_ANNE', DATE '2026-09-01', '__T6_Y1', 'Dişi');
    v_a := v_res->>'buzagi_id';
    UPDATE public.hayvanlar SET durum = 'Ölü', cikis_tipi = 'Ölüm', cikis_tarihi = DATE '2026-09-05' WHERE id = v_a;
    v_res := public.dogum_kaydet('__T6_ANNE', DATE '2026-10-20', '__T6_Y1', 'Dişi');
    PERFORM pg_temp.yaz('T7a ayni anne olu yavru kupesi gecer', (v_res->>'ok')::boolean, v_res::text);
    PERFORM pg_temp.yaz('T7b iki dogum satiri kendi buzagisina bagli',
      (SELECT array_agg(buzagi_id ORDER BY tarih) FROM public.dogum WHERE anne_id = '__T6_ANNE')
        = ARRAY[v_a, v_res->>'buzagi_id'], v_res::text);
    v_res := public.dogum_kaydet('__T6_ANNE', DATE '2026-10-21', '__T6_Y1', 'Dişi');
    PERFORM pg_temp.yaz('T7c ayni anne aktif yavru kupesi red',
      (v_res->>'ok')::boolean = false AND v_res->>'mesaj' LIKE 'Bu küpe zaten kayıtlı%', v_res::text);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.yaz('T7 ayni anne olu yavru', false, SQLSTATE || ' ' || SQLERRM);
  END;

  -- T8: yazım hatası ikiz koruması aktif yavruda sürer (küpesi sonradan düzeltilmiş); bağsız eski satır engellemez
  BEGIN
    v_res := public.dogum_kaydet('__T6_ANNE2', DATE '2026-10-01', '__T6_Y2', 'Dişi');
    UPDATE public.hayvanlar SET kupe_no = '__T6_Y2B' WHERE id = v_res->>'buzagi_id';
    v_res := public.dogum_kaydet('__T6_ANNE2', DATE '2026-10-02', '__T6_Y2', 'Dişi');
    PERFORM pg_temp.yaz('T8a aktif yavru ikiz koruma mesaji degismedi',
      (v_res->>'ok')::boolean = false
      AND v_res->>'mesaj' = 'Bu küpe bu annenin yavrusu olarak zaten kayıtlı: __T6_Y2', v_res::text);
    INSERT INTO public.dogum (anne_id, tarih, yavru_cins, yavru_kupe) VALUES ('__T6_ANNE2', DATE '2020-01-01', 'Dişi', '__T6_Y3');
    v_res := public.dogum_kaydet('__T6_ANNE2', DATE '2026-10-03', '__T6_Y3', 'Dişi');
    PERFORM pg_temp.yaz('T8b buzagi_id bos eski satir engellemez', (v_res->>'ok')::boolean, v_res::text);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.yaz('T8 ikiz koruma', false, SQLSTATE || ' ' || SQLERRM);
  END;

  -- T9: küpesi başkasına verilmiş çıkmış hayvanın kartı düzenlenir (form küpeyi aynen yollar, submitAnimal imzası)
  BEGIN
    PERFORM pg_temp.yaz('T9a kendi degismeyen kupesi musait',
      (public.kupe_musait_mi('__T3_OLU_K', NULL, '__T3_OLU')->>'musait')::boolean, '');
    v_res := public.hayvan_guncelle(p_id => '__T3_OLU', p_kupe_no => '__T3_OLU_K', p_renk => 'Siyah', p_kisir => false);
    PERFORM pg_temp.yaz('T9b cikmis hayvan karti duzenlenir',
      (v_res->>'ok')::boolean AND (SELECT renk FROM public.hayvanlar WHERE id = '__T3_OLU') = 'Siyah', v_res::text);
    v_res := public.hayvan_guncelle(p_id => '__T3_OLU', p_kupe_no => '__T3_AKTIF_K', p_kisir => false);
    PERFORM pg_temp.yaz('T9c baska aktif kupeye gecis red',
      (v_res->>'ok')::boolean = false AND v_res->>'error' LIKE 'İşletme küpesi zaten kayıtlı (aktif)%', v_res::text);
    PERFORM pg_temp.yaz('T9d baska hayvanin aktif kupesi musait degil',
      (public.kupe_musait_mi('__T3_OLU_K', NULL, '__T3_AKTIF')->>'musait')::boolean = false
      AND (public.kupe_musait_mi('__T3_OLU_K', NULL)->>'musait')::boolean = false, '');
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.yaz('T9 cikmis hayvan duzenleme', false, SQLSTATE || ' ' || SQLERRM);
  END;
END
$test$;

\pset format unaligned
\pset tuples_only on
SELECT durum || ' ' || ad || CASE WHEN durum = 'FAIL' THEN ' :: ' || detay ELSE '' END FROM _sonuc;
DO $$
DECLARE v_fail integer;
BEGIN
  SELECT count(*) INTO v_fail FROM _sonuc WHERE durum <> 'PASS';
  IF v_fail > 0 THEN RAISE EXCEPTION 'RED: % test FAIL', v_fail; END IF;
  RAISE NOTICE 'YESIL: % test PASS', (SELECT count(*) FROM _sonuc);
END $$;
ROLLBACK;
