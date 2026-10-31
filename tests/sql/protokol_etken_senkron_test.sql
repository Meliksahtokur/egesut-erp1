-- tests/sql/protokol_etken_senkron_test.sql — görev ↔ protokol uyarısı senkronu (G-20261030-PROTOKOL-ETKEN, F1+F2).
-- HEDEF: YALNIZ scripts/kabul-db/build.sh ile kurulan verisiz tam kopya (default+constraint+tetik gerekir; db-build-baseline
-- aynası bunları taşımaz, orada yanlış nedenle kızarır). Migration önce o kopyaya uygulanır. Canlıya bu betikle erişilmez.
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/protokol_etken_senkron_test.sql → rc=0 hepsi PASS; rc!=0 en az biri RED.
-- Davranış ölçer: üreticinin açtığı görev kapanınca / uygulama girilince protokol_eksik_tara satırı düşer,
-- p_occurred_at uygulama_log.tarih'e yazılır. Fixture + yan etkiler tek transaction'da, sonda ROLLBACK.
\echo '=== PROTOKOL ETKEN SENKRON — izole DB testi ==='
BEGIN;
SET LOCAL TIME ZONE 'UTC';  -- Supabase oturum dilimi; yerel +03 gün hesabı hatasını örter
CREATE FUNCTION pg_temp.bg() RETURNS date LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $$;
CREATE FUNCTION pg_temp.an(g date, s time) RETURNS timestamptz LANGUAGE sql IMMUTABLE AS $$ SELECT (g + s) AT TIME ZONE 'Europe/Istanbul' $$;
-- Taramada hayvan+etken satırının durumu; satır yoksa 'yok'.
CREATE FUNCTION pg_temp.tara(h text, ek text) RETURNS text LANGUAGE sql AS $$
  SELECT COALESCE((SELECT e->>'durum' FROM jsonb_array_elements(public.protokol_eksik_tara()) e
    WHERE e->>'hayvan_id' = h AND e->>'etken_kod' = ek AND e->>'protokol' = 'ILERI_GEBE_PROTOKOL' LIMIT 1), 'yok') $$;
CREATE FUNCTION pg_temp.gorev(h text, a text) RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM gorev_log WHERE hayvan_id = h AND aciklama LIKE a LIMIT 1 $$;
DELETE FROM protokol_ayar WHERE anahtar = 'ovsync_pg_kurallari_aktif'; INSERT INTO protokol_ayar(anahtar, deger) VALUES ('ovsync_pg_kurallari_aktif', 1);
INSERT INTO stok(id, urun_adi, kategori, birim, baslangic_miktar) VALUES
  ('E2E-PES-ROTA', 'E2E-PES Rota', 'Aşı', 'doz', 10), ('E2E-PES-EVIT', 'E2E-PES Yeldif', 'İlaç', 'ml', 100), ('E2E-PES-ADEM', 'E2E-PES Ademin', 'İlaç', 'ml', 100);
INSERT INTO vaccines(id, name, dose, unit, route, stock_item_id) VALUES (gen_random_uuid(), 'E2E-PES Rota', 1, 'doz', 'IM', 'E2E-PES-ROTA');
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
  SELECT 'E2E-PES-H-' || i, 'E2E-PES-' || i, 'Dişi', 'Aktif', 'Sağmal (Kuru)', 'Kuru Padok', pg_temp.bg() - 1500 FROM generate_series(1, 4) i;
-- H-1: gebelik 270. gün → ROTA hedef g-30, ADEMIN g-10, E_VIT g-5 (bugünkü uygulama pencereye girmez, sonuç görev kapanışına bağlı).
INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler)
  VALUES (gen_random_uuid(), 'E2E-PES-H-1', pg_temp.bg() - 270, 'Gebe', 1, '[]');
CREATE TEMP TABLE _pes(senaryo text PRIMARY KEY, sonuc text, kanit text);
CREATE FUNCTION pg_temp.yaz(s text, ok boolean, k text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO _pes VALUES (s, CASE WHEN ok IS TRUE THEN 'PASS' ELSE 'RED' END, k) $$;

-- ── F1 üretici: 3 INSERT etken_kod yazar
DO $do$ DECLARE v text; BEGIN
  PERFORM public.gebelik_protokol_kontrol();
  SELECT string_agg(etken_kod || '/' || gorev_tipi, ',' ORDER BY hedef_tarih) INTO v FROM gorev_log
    WHERE hayvan_id = 'E2E-PES-H-1' AND gorev_tipi IN ('ILERI_GEBE', 'ILERI_GEBE_ASI');
  PERFORM pg_temp.yaz('F1-URETICI', v = 'ROTA/ILERI_GEBE_ASI,ADEMIN/ILERI_GEBE,E_VIT/ILERI_GEBE', v);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('F1-URETICI', false, SQLERRM); END $do$;

-- ── Yön (a): üretici görevi done → tarama düşer (24 saat 'tamamlandi', eksik değil)
DO $do$ DECLARE v0 text; v1 text; BEGIN
  v0 := pg_temp.tara('E2E-PES-H-1', 'ADEMIN');
  PERFORM public.gorev_tamamla(pg_temp.gorev('E2E-PES-H-1', '%SC Ademin%')::text);
  v1 := pg_temp.tara('E2E-PES-H-1', 'ADEMIN');
  PERFORM pg_temp.yaz('A-ADEMIN-DONE', v0 = 'eksik' AND v1 = 'tamamlandi', v0 || '→' || v1);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('A-ADEMIN-DONE', false, SQLERRM); END $do$;
-- Rota: görev stoklu (K8 köprüsü) → uyarı düşer, görev kendi tek doz stok satırını yazar
DO $do$ DECLARE v0 text; v1 text; n int; g uuid := pg_temp.gorev('E2E-PES-H-1', '%Rota-Corona%'); BEGIN
  v0 := pg_temp.tara('E2E-PES-H-1', 'ROTA');
  PERFORM public.gorev_tamamla(g::text);
  v1 := pg_temp.tara('E2E-PES-H-1', 'ROTA');
  SELECT count(*) INTO n FROM stok_hareket WHERE stok_id = 'E2E-PES-ROTA';
  PERFORM pg_temp.yaz('A-ROTA-DONE', v0 = 'eksik' AND v1 = 'tamamlandi' AND n = 1, v0 || '→' || v1 || ' stok_hareket=' || n);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('A-ROTA-DONE', false, SQLERRM); END $do$;

-- ── Yön (b): uyarıdan hizli_uygulama → eşleşen görev kapanır, kapatan_ref dolu, uyarı düşer
DO $do$ DECLARE v0 text; v1 text; r jsonb; g record; BEGIN
  v0 := pg_temp.tara('E2E-PES-H-1', 'E_VIT');
  r := public.hizli_uygulama('E2E-PES-H-1', 'E2E-PES-EVIT', 5, 'ml', 'IM', 'E2E-PES');
  v1 := pg_temp.tara('E2E-PES-H-1', 'E_VIT');
  SELECT tamamlandi, kapatan_ref INTO g FROM gorev_log WHERE id = pg_temp.gorev('E2E-PES-H-1', '%E Vitamini%');
  PERFORM pg_temp.yaz('B-UYGULA-GOREV', v0 = 'eksik' AND v1 = 'tamamlandi' AND g.tamamlandi AND g.kapatan_ref = 'uygulama_log:' || (r->>'id'),
    v0 || '→' || v1 || ' ' || g::text);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('B-UYGULA-GOREV', false, SQLERRM); END $do$;

-- ── F2: p_occurred_at tarihe; gece yarısı sonrası an İstanbul gününe düşer (UTC'de önceki gün)
DO $do$ DECLARE r jsonb; d date; BEGIN
  r := public.hizli_uygulama('E2E-PES-H-2', 'E2E-PES-EVIT', 5, 'ml', 'IM', 'E2E-PES', p_occurred_at => pg_temp.an(pg_temp.bg() - 2, '00:30'));
  SELECT tarih INTO d FROM uygulama_log WHERE id = (r->>'id')::uuid;
  PERFORM pg_temp.yaz('F2-TARIH-ISTANBUL', d = pg_temp.bg() - 2, 'tarih=' || d);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('F2-TARIH-ISTANBUL', false, SQLERRM); END $do$;
DO $do$ DECLARE r jsonb; d date; BEGIN
  r := public.hizli_uygulama('E2E-PES-H-2', 'E2E-PES-EVIT', 5, 'ml', 'IM', 'E2E-PES');
  SELECT tarih INTO d FROM uygulama_log WHERE id = (r->>'id')::uuid;
  PERFORM pg_temp.yaz('F2-BOS-VARSAYILAN', d = CURRENT_DATE, 'tarih=' || d);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('F2-BOS-VARSAYILAN', false, SQLERRM); END $do$;
-- KN-2: görevsiz geç uygulama, gerçek tarihiyle pencereye girer ve uyarıyı düşürür (hedef g-6; g-5 içeride, bugün dışarıda)
DO $do$ DECLARE v0 text; v1 text; BEGIN
  INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler) VALUES (gen_random_uuid(), 'E2E-PES-H-3', pg_temp.bg() - 266, 'Gebe', 1, '[]');
  v0 := pg_temp.tara('E2E-PES-H-3', 'ADEMIN');
  PERFORM public.hizli_uygulama('E2E-PES-H-3', 'E2E-PES-ADEM', 5, 'ml', 'IM', 'E2E-PES', p_occurred_at => pg_temp.an(pg_temp.bg() - 5, '10:00'));
  v1 := pg_temp.tara('E2E-PES-H-3', 'ADEMIN');
  PERFORM pg_temp.yaz('F2-PENCERE-GEC-GIRIS', v0 = 'eksik' AND v1 = 'yok', v0 || '→' || v1);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('F2-PENCERE-GEC-GIRIS', false, SQLERRM); END $do$;
-- Mevcut MK7 sınırı değişmedi: bayrak açıkken 7 günden eski an reddedilir
DO $do$ BEGIN
  PERFORM public.hizli_uygulama('E2E-PES-H-4', 'E2E-PES-EVIT', 5, 'ml', 'IM', 'E2E-PES', p_occurred_at => now() - interval '8 days');
  PERFORM pg_temp.yaz('F2-MK7-SINIR', false, 'reddedilmedi');
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.yaz('F2-MK7-SINIR', SQLERRM LIKE 'PG_ZAMAN_GECERSIZ%', SQLERRM); END $do$;

-- ── Özet + hüküm (ROLLBACK = temizlik). Beklenen senaryo sayısı: 8.
SELECT senaryo, sonuc, kanit FROM _pes ORDER BY senaryo;
SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS pes_red, count(*) AS pes_toplam FROM _pes \gset
ROLLBACK;
SELECT set_config('pes.red', :'pes_red', false), set_config('pes.toplam', :'pes_toplam', false) \g /dev/null
DO $do$ BEGIN
  IF current_setting('pes.toplam')::int <> 8 OR current_setting('pes.red')::int > 0 THEN
    RAISE EXCEPTION 'PROTOKOL ETKEN TEST RED: % / % senaryo kirmizi', current_setting('pes.red'), current_setting('pes.toplam');
  END IF;
  RAISE NOTICE 'PROTOKOL ETKEN TEST PASS';
END $do$;
