-- Hayvan Takip karşı testleri (spec §8.3): HAYVAN_TAKIP_MUAYENE üreme akışlarını etkilemez.
-- BEGIN/ROLLBACK taşımaz: hayvan_takip_kos.sh sarar. Her KR bloğu SAVEPOINT içinde kendi
-- fixture'ını kurar. gorev_tipi serbest metin olduğundan KR01-KR10 migration'dan önce de
-- yeşildir; kırmızı kanıtı hayvan_takip_karsi_mutant.sql ile üretilir.
-- Fixture: E2E-HT-K-A (açık yeni tip görev), E2E-HT-K-B (görevsiz ikiz). Kimlikler uuid
-- biçimlidir: _takip_gorev_kur hayvan kimliğini uuid alır.

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000cafe', true) \g /dev/null

CREATE FUNCTION pg_temp.ht_a() RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT '00000000-0000-4000-8000-0000000e2ea1'::text $f$;
CREATE FUNCTION pg_temp.ht_b() RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT '00000000-0000-4000-8000-0000000e2eb1'::text $f$;
CREATE FUNCTION pg_temp.ht_bugun() RETURNS date LANGUAGE sql STABLE AS $f$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $f$;
CREATE FUNCTION pg_temp.ht_ovsync() RETURNS uuid LANGUAGE sql IMMUTABLE AS $f$ SELECT 'c346e115-35ff-4430-92b8-874c505d857e'::uuid $f$;

CREATE FUNCTION pg_temp.ht_ok(p_kosul boolean, p_mesaj text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_kosul IS NOT TRUE THEN RAISE EXCEPTION '%', p_mesaj; END IF;
END $f$;

-- Çağrıyı koşar, hatasını metin döner; hata yoksa NULL. Etkisi hata halinde geri sarılır.
CREATE FUNCTION pg_temp.ht_hata(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN SQLERRM;
END $f$;

-- Yeni tip görev: ref_takip_id yazmaz, migration'a bağımlı değildir.
CREATE FUNCTION pg_temp.ht_gorev(p_hayvan text, p_gun int DEFAULT 7) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
  VALUES (v, p_hayvan, 'HAYVAN_TAKIP_MUAYENE', 'E2E-HT-K muayene', pg_temp.ht_bugun() + p_gun, false, false,
          'HAYVAN_TAKIP:00000000-0000-4000-8000-0000000e2e01');
  RETURN v;
END $f$;

-- A ve B'yi kurar; p_gorev ise A'ya açık yeni tip görev bağlar ve kimliğini döner.
CREATE FUNCTION pg_temp.ht_kur(p_gorev boolean DEFAULT true) RETURNS uuid LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, dogum_tarihi, durum, irk, grup, padok)
  VALUES (pg_temp.ht_a(), 'E2E-HT-K-A', 'Dişi', pg_temp.ht_bugun() - 1500, 'Aktif', 'Holstein', 'Sağmal', 'P1'),
         (pg_temp.ht_b(), 'E2E-HT-K-B', 'Dişi', pg_temp.ht_bugun() - 1500, 'Aktif', 'Holstein', 'Sağmal', 'P1');
  RETURN CASE WHEN p_gorev THEN pg_temp.ht_gorev(pg_temp.ht_a()) END;
END $f$;

CREATE FUNCTION pg_temp.ht_takip_ac(p_hayvan text) RETURNS uuid LANGUAGE sql AS $f$
  SELECT public._takip_gorev_kur(p_hayvan::uuid, 'E2E-HT-K-TOH', 7, NULL::time)
$f$;

-- sessiz_hayvanlar_listele satırındaki sessiz_gun; hayvan listede değilse NULL.
CREATE FUNCTION pg_temp.ht_sessiz(p_hayvan text) RETURNS int LANGUAGE sql AS $f$
  SELECT (x->>'sessiz_gun')::int FROM jsonb_array_elements(public.sessiz_hayvanlar_listele(NULL, 0)) x
   WHERE x->>'hayvan_id' = p_hayvan
$f$;

-- ovsync_takip_listele takipteki kümesinde mi: satırın takip alanı dolu.
CREATE FUNCTION pg_temp.ht_takipte(p_hayvan text) RETURNS boolean LANGUAGE sql AS $f$
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(public.ovsync_takip_listele()->'satirlar') x
                  WHERE x->>'hayvan_id' = p_hayvan AND jsonb_typeof(x->'takip') = 'object')
$f$;

-- KR01
SAVEPOINT kr;
DO $t$
BEGIN
  PERFORM pg_temp.ht_kur();
  PERFORM public.create_case(pg_temp.ht_a(), pg_temp.ht_ovsync(), 'E2E-HT-K', false);
  PERFORM pg_temp.ht_ok(EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = pg_temp.ht_a() AND c.status = 'active'), 'vaka açılmadı');
  RAISE NOTICE 'KR01 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR01 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR02
SAVEPOINT kr;
DO $t$
BEGIN
  PERFORM pg_temp.ht_kur();
  INSERT INTO public.pg_application_event (source_type, source_id, hayvan_id, occurred_at, karar)
  VALUES ('HIZLI_UYGULAMA', 'E2E-HT-K-KR02', pg_temp.ht_a(), now(), 'ALLOW');
  RAISE NOTICE 'KR02 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR02 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR03
SAVEPOINT kr;
DO $t$
DECLARE v_g uuid; r record;
BEGIN
  v_g := pg_temp.ht_kur();
  PERFORM public.tohumlama_kaydet(pg_temp.ht_a(), pg_temp.ht_bugun(), 'E2E-HT-K-SPERMA');
  SELECT tamamlandi, iptal, takip_kapanis_nedeni, kapatan_ref INTO r FROM public.gorev_log WHERE id = v_g;
  PERFORM pg_temp.ht_ok(r.tamamlandi IS NOT TRUE AND r.iptal IS NOT TRUE, format('görev kapandı: %s', to_jsonb(r)));
  PERFORM pg_temp.ht_ok(r.takip_kapanis_nedeni IS NULL, format('neden yazıldı: %s', r.takip_kapanis_nedeni));
  RAISE NOTICE 'KR03 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR03 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR04 (takip muafiyeti _ovsync_baslat_gorev_kur'da değil, _acik_disi_hedef_ic'te)
SAVEPOINT kr;
DO $t$
DECLARE v_a date; v_b date; v_ka date; v_kb date; v_na int; v_nb int; v_ha date; v_hb date;
BEGIN
  PERFORM pg_temp.ht_kur();
  -- Önce hedef: açık OVSYNC_BASLAT _acik_disi_hedef_ic'i kendisi NULL'a çeker.
  v_a := public._acik_disi_hedef_ic(pg_temp.ht_a());
  v_b := public._acik_disi_hedef_ic(pg_temp.ht_b());
  PERFORM pg_temp.ht_ok(v_a IS NOT NULL AND v_a = v_b, format('_acik_disi_hedef_ic A=%s B=%s', v_a, v_b));
  v_ka := public._ovsync_kural_tarihi(pg_temp.ht_a());
  v_kb := public._ovsync_kural_tarihi(pg_temp.ht_b());
  PERFORM public._ovsync_baslat_gorev_kur(pg_temp.ht_a(), pg_temp.ht_bugun(), 'E2E-HT-K-KR04-A', v_ka);
  PERFORM public._ovsync_baslat_gorev_kur(pg_temp.ht_b(), pg_temp.ht_bugun(), 'E2E-HT-K-KR04-B', v_kb);
  SELECT count(*), max(hedef_tarih) INTO v_na, v_ha FROM public.gorev_log
   WHERE hayvan_id = pg_temp.ht_a() AND gorev_tipi = 'OVSYNC_BASLAT' AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE;
  SELECT count(*), max(hedef_tarih) INTO v_nb, v_hb FROM public.gorev_log
   WHERE hayvan_id = pg_temp.ht_b() AND gorev_tipi = 'OVSYNC_BASLAT' AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE;
  PERFORM pg_temp.ht_ok(v_na = 1 AND v_nb = 1, format('OVSYNC_BASLAT sayısı A=%s B=%s', v_na, v_nb));
  PERFORM pg_temp.ht_ok(v_ha IS NOT NULL AND v_ha = v_hb, format('hedef_tarih A=%s B=%s', v_ha, v_hb));
  RAISE NOTICE 'KR04 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR04 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR05
SAVEPOINT kr;
DO $t$
DECLARE v_a int; v_b int;
BEGIN
  PERFORM pg_temp.ht_kur();
  v_a := pg_temp.ht_sessiz(pg_temp.ht_a());
  v_b := pg_temp.ht_sessiz(pg_temp.ht_b());
  PERFORM pg_temp.ht_ok(v_b IS NOT NULL, 'B sessiz listede yok');
  PERFORM pg_temp.ht_ok(v_a = v_b, format('sessiz_gun A=%s B=%s', v_a, v_b));
  RAISE NOTICE 'KR05 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR05 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR06 (B pozitif kontrol: küme gerçekten okunuyor)
SAVEPOINT kr;
DO $t$
BEGIN
  PERFORM pg_temp.ht_kur();
  PERFORM pg_temp.ht_takip_ac(pg_temp.ht_b());
  PERFORM pg_temp.ht_ok(pg_temp.ht_takipte(pg_temp.ht_b()), 'kontrol: TAKIP_MUAYENE açık B takipte değil');
  PERFORM pg_temp.ht_ok(NOT pg_temp.ht_takipte(pg_temp.ht_a()), 'A takipteki kümesinde');
  RAISE NOTICE 'KR06 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR06 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR07
SAVEPOINT kr;
DO $t$
DECLARE v_g uuid; v_t uuid;
BEGIN
  v_g := pg_temp.ht_kur();
  v_t := pg_temp.ht_takip_ac(pg_temp.ht_a());
  PERFORM pg_temp.ht_ok(EXISTS (SELECT 1 FROM public.gorev_log WHERE id = v_t AND gorev_tipi = 'TAKIP_MUAYENE'
                                   AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE), 'TAKIP_MUAYENE açılmadı');
  PERFORM pg_temp.ht_ok(EXISTS (SELECT 1 FROM public.gorev_log WHERE id = v_g AND iptal IS NOT TRUE), 'yeni tip görev kapandı');
  RAISE NOTICE 'KR07 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR07 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR08 (B'de önce TAKIP_MUAYENE: mutantta da _takip_gorev_kur açılsın)
SAVEPOINT kr;
DO $t$
DECLARE v_h text;
BEGIN
  PERFORM pg_temp.ht_kur();
  PERFORM pg_temp.ht_takip_ac(pg_temp.ht_b());
  PERFORM pg_temp.ht_gorev(pg_temp.ht_b());
  v_h := pg_temp.ht_hata(format('SELECT public.create_case(%L, %L::uuid, %L, false)', pg_temp.ht_b(), pg_temp.ht_ovsync(), 'E2E-HT-K'));
  PERFORM pg_temp.ht_ok(v_h LIKE 'TAKIP_ACIK:%', format('TAKIP_ACIK bekleniyordu: %s', COALESCE(v_h, '<hata yok>')));
  RAISE NOTICE 'KR08 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR08 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR09 (yeni tip hedef_tarih daha ileri: mutantta ORDER BY onu seçer)
SAVEPOINT kr;
DO $t$
DECLARE v_t uuid; v_g uuid; rt record; rg record;
BEGIN
  PERFORM pg_temp.ht_kur();
  v_t := pg_temp.ht_takip_ac(pg_temp.ht_b());
  v_g := pg_temp.ht_gorev(pg_temp.ht_b(), 30);
  PERFORM public.tohumlama_kaydet(pg_temp.ht_b(), pg_temp.ht_bugun(), 'E2E-HT-K-SPERMA');
  SELECT iptal, takip_kapanis_nedeni INTO rt FROM public.gorev_log WHERE id = v_t;
  SELECT tamamlandi, iptal, takip_kapanis_nedeni INTO rg FROM public.gorev_log WHERE id = v_g;
  PERFORM pg_temp.ht_ok(rt.iptal IS TRUE AND rt.takip_kapanis_nedeni = 'YENI_TOHUMLAMA', format('TAKIP_MUAYENE: %s', to_jsonb(rt)));
  PERFORM pg_temp.ht_ok(rg.tamamlandi IS NOT TRUE AND rg.iptal IS NOT TRUE AND rg.takip_kapanis_nedeni IS NULL, format('yeni tip: %s', to_jsonb(rg)));
  RAISE NOTICE 'KR09 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR09 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR10
SAVEPOINT kr;
DO $t$
DECLARE v_t uuid; v_h text;
BEGIN
  PERFORM pg_temp.ht_kur();
  v_t := pg_temp.ht_takip_ac(pg_temp.ht_b());
  v_h := pg_temp.ht_hata(format('SELECT public.gorev_tamamla(%L, NULL, false)', v_t));
  PERFORM pg_temp.ht_ok(v_h = 'MUAYENE_SONUC_GEREKLI:TAKIP_MUAYENE', format('guard: %s', COALESCE(v_h, '<hata yok>')));
  RAISE NOTICE 'KR10 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR10 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;

-- KR11 (T5 sonrası: gerçek görev, ref_takip_id dolu)
SAVEPOINT kr;
DO $t$
DECLARE v_g uuid; v_h text; v_a int; v_b int;
BEGIN
  IF (SELECT prosrc NOT LIKE '%HAYVAN_TAKIP_MUAYENE%' FROM pg_proc WHERE oid = 'public.gorev_tamamla(text,text,boolean)'::regprocedure) THEN
    RAISE NOTICE 'KR11 ATLANDI';
    RETURN;
  END IF;
  PERFORM pg_temp.ht_kur(false);
  PERFORM public.hayvan_takip_ac(pg_temp.ht_a(), 'TOPALLIK', NULL, pg_temp.ht_bugun() + 7, NULL);
  SELECT id INTO v_g FROM public.gorev_log
   WHERE hayvan_id = pg_temp.ht_a() AND gorev_tipi = 'HAYVAN_TAKIP_MUAYENE' AND ref_takip_id IS NOT NULL;
  PERFORM pg_temp.ht_ok(v_g IS NOT NULL, 'hayvan_takip_ac görev açmadı');
  -- KR05
  v_a := pg_temp.ht_sessiz(pg_temp.ht_a());
  v_b := pg_temp.ht_sessiz(pg_temp.ht_b());
  PERFORM pg_temp.ht_ok(v_b IS NOT NULL AND v_a = v_b, format('sessiz_gun A=%s B=%s', v_a, v_b));
  -- KR06
  PERFORM pg_temp.ht_ok(NOT pg_temp.ht_takipte(pg_temp.ht_a()), 'A takipteki kümesinde');
  -- Guard
  v_h := pg_temp.ht_hata(format('SELECT public.gorev_tamamla(%L, NULL, false)', v_g));
  PERFORM pg_temp.ht_ok(v_h = 'MUAYENE_SONUC_GEREKLI:HAYVAN_TAKIP_MUAYENE', format('guard: %s', COALESCE(v_h, '<hata yok>')));
  -- KR01
  PERFORM public.create_case(pg_temp.ht_a(), pg_temp.ht_ovsync(), 'E2E-HT-K', false);
  PERFORM public.create_case(pg_temp.ht_b(), pg_temp.ht_ovsync(), 'E2E-HT-K', false);
  PERFORM pg_temp.ht_ok((SELECT count(*) FROM public.cases WHERE animal_id IN (pg_temp.ht_a(), pg_temp.ht_b()) AND status = 'active') = 2, 'vaka sayısı A ve B için 2 değil');
  -- KR07
  PERFORM pg_temp.ht_takip_ac(pg_temp.ht_a());
  PERFORM pg_temp.ht_takip_ac(pg_temp.ht_b());
  RAISE NOTICE 'KR11 PASS';
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'KR11 FAIL: %', SQLERRM;
END $t$;
ROLLBACK TO kr;
