-- ============================================================================
-- supabase/tests/ovsync_tren_kabul.sql — Ovsync treni SQL kabul betiği
-- Plan: docs/plans/2026-11-09-ovsync-tren/PLAN.md (N1 — L-DB, D1..D8)
-- Spec: docs/plans/2026-11-09-ovsync-tren/design.md
--
-- Sözleşme (PLAN.md N1 "Kabul betiği sözleşmesi" + "Senaryo izolasyonu"):
--   * Betik migration UYGULAMAZ ve kendi BEGIN/COMMIT/ROLLBACK'ını taşımaz;
--     çağıran BEGIN … ROLLBACK ile sarar (README).
--   * Her senaryo:  SAVEPOINT kb_s;  DO $t$…$t$;  ROLLBACK TO SAVEPOINT kb_s;
--     Fixture'lar, protokol_ayar değişiklikleri ve set_config(…, true) GUC'ları
--     (app.ovsync_tren_ic dahil) geri sarımla sıfırlanır; sonraki senaryo temiz
--     başlar. Bölüm bayrak/çapa kurulumu senaryonun İÇİNDE yapılır.
--   * Yardımcılar ve PASS sayacı ilk savepoint'ten ÖNCE yaratılır. Sayaç TEMP
--     SEQUENCE'tır (sequence geri sarılmaz); kb_ok başarıda nextval, sonda
--     'OZET: <n> PASS'. FAIL → RAISE EXCEPTION 'FAIL <id>: beklenen … gerçek …'
--     (ON_ERROR_STOP koşumu durdurur).
--   * Tarihler yalnız kb_bugun() (Europe/Istanbul bugünü) ile kurulur; CURRENT_DATE yok.
--   * Kilidi sınayan senaryo ilk satırda set_config('app.ovsync_tren_ic','',true).
--   * Sayı/toplam assert'leri senaryonun kendi 'KB-' hayvan kümesine süzülür.
-- ============================================================================

\set QUIET on
SET LOCAL client_min_messages = notice;
DO $$ BEGIN PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000cafe', true); END $$;

-- ── Yardımcılar (pg_temp; ilk savepoint'ten önce) ───────────────────────────
CREATE TEMP SEQUENCE kb_gecti_seq;

-- Istanbul yerel bugünü (CURRENT_DATE UTC'dir; 00:00-03:00 TR arası 1 gün geride kalır)
CREATE FUNCTION pg_temp.kb_bugun() RETURNS date LANGUAGE sql STABLE AS $f$
  SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date
$f$;

CREATE FUNCTION pg_temp.kb_ok(p_kosul boolean, p_test text, p_beklenen text, p_gercek text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_kosul IS NOT TRUE THEN
    RAISE EXCEPTION 'FAIL %: beklenen % gerçek %', p_test, p_beklenen, COALESCE(p_gercek, '<NULL>');
  END IF;
  PERFORM nextval('pg_temp.kb_gecti_seq');
END $f$;

CREATE FUNCTION pg_temp.kb_id(p_on text) RETURNS text LANGUAGE sql VOLATILE AS $f$
  SELECT p_on || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 10)
$f$;

-- Dişi test hayvanı, yaşı p_yas_gun (doğrudan INSERT; trigger'lar yürür)
CREATE FUNCTION pg_temp.kb_hayvan(p_yas_gun int DEFAULT 1500, p_durum text DEFAULT 'Aktif',
                                  p_kisir boolean DEFAULT false)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text := pg_temp.kb_id('KB');
BEGIN
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, dogum_tarihi, durum, irk, kisir)
  VALUES (v, v, 'Dişi', pg_temp.kb_bugun() - p_yas_gun, p_durum, 'Holstein', p_kisir);
  RETURN v;
END $f$;

-- Europe/Istanbul yerel gün+saat → timestamptz
CREATE FUNCTION pg_temp.kb_yerel(p_gun date, p_saat time) RETURNS timestamptz
LANGUAGE sql IMMUTABLE AS $f$ SELECT (p_gun + p_saat) AT TIME ZONE 'Europe/Istanbul' $f$;

-- protokol_ayar değerini senaryo içinde kurar; satır yoksa false döner (yazma yok)
CREATE FUNCTION pg_temp.kb_ayar(p_anahtar text, p_deger numeric) RETURNS boolean
LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.protokol_ayar SET deger = p_deger WHERE anahtar = p_anahtar;
  RETURN FOUND;
END $f$;

-- Annede açık doğum-sonrası PG görevi sayısı (gövdedeki gerçek açıklamalar)
CREATE FUNCTION pg_temp.kb_dogum_pg_sayi(p_anne text) RETURNS int LANGUAGE sql STABLE AS $f$
  SELECT count(*)::int FROM public.gorev_log
   WHERE hayvan_id = p_anne AND NOT COALESCE(tamamlandi, false) AND NOT COALESCE(iptal, false)
     AND aciklama IN ('2. Gün PG', '25. Gün PG', '39. Gün PG (Presynch-14 senkron)')
$f$;

-- Hatırlatma satırları, verilen hayvan kümesine süzülmüş (plpgsql: RPC yokken de yaratılabilsin)
CREATE FUNCTION pg_temp.kb_hatirlatma(p_hayvanlar text[]) RETURNS jsonb LANGUAGE plpgsql STABLE AS $f$
BEGIN
  RETURN (SELECT COALESCE(jsonb_agg(s ORDER BY s->>'hayvan_id'), '[]'::jsonb)
            FROM jsonb_array_elements(public.dogum_sonrasi_pg_hatirlatma()->'satirlar') s
           WHERE s->>'hayvan_id' = ANY(p_hayvanlar));
END $f$;

-- ── D2 ek yardımcıları (PLAN.md N1) ─────────────────────────────────────────
-- Treni açar: ovsync_tren_aktif=1 + çapa (YYYYMMDD, R1). Tren, Ovsync-PG bayrağına bağlı olduğundan o da 1'e çekilir.
CREATE FUNCTION pg_temp.kb_tren_ac(p_capa date) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF NOT (pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1)
          AND pg_temp.kb_ayar('ovsync_tren_aktif', 1)
          AND pg_temp.kb_ayar('ovsync_tren_capa', to_char(p_capa, 'YYYYMMDD')::numeric)) THEN
    RAISE EXCEPTION 'FIXTURE: kb_tren_ac ayar satırı eksik';
  END IF;
END $f$;

CREATE FUNCTION pg_temp.kb_tren_kapat() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF NOT pg_temp.kb_ayar('ovsync_tren_aktif', 0) THEN RAISE EXCEPTION 'FIXTURE: kb_tren_kapat ayar satırı eksik'; END IF;
END $f$;

-- OVSYNC vakası: create_case (Ovsync Protokol) + Ovsync şablonu p_baslangic_tarihi = p_d0 (V3 yolu); case_id döner.
CREATE FUNCTION pg_temp.kb_ovsync_vaka(p_hayvan text, p_d0 date) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v_r jsonb; v_case uuid;
BEGIN
  v_r := public.create_case(p_hayvan, 'c346e115-35ff-4430-92b8-874c505d857e'::uuid, 'kb ovsync');
  v_case := (v_r->>'case_id')::uuid;
  IF v_case IS NULL THEN RAISE EXCEPTION 'FIXTURE: create_case %', v_r; END IF;
  v_r := public.tedavi_sablon_uygula(v_case, 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'::uuid, p_d0);
  IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN RAISE EXCEPTION 'FIXTURE: tedavi_sablon_uygula %', v_r; END IF;
  RETURN v_case;
END $f$;

-- Vakanın hastalık-dışı gün#k'sının (treatment_date, day_no sırası) açık seanslarını seans_tamamla ile kapatır.
CREATE FUNCTION pg_temp.kb_seans_yap(p_case uuid, p_gun_sira int, p_uygulanmadi boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE v_s uuid; v_r jsonb; v_n int := 0;
BEGIN
  FOR v_s IN
    SELECT u.id FROM public.treatment_day_uygulamalar u
     WHERE u.treatment_day_id = (SELECT d.id FROM public.treatment_days d
                                  WHERE d.case_id = p_case AND d.disease_id IS NULL
                                  ORDER BY d.treatment_date, d.day_no OFFSET p_gun_sira - 1 LIMIT 1)
       AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)
     ORDER BY u.planned_time
  LOOP
    v_r := public.seans_tamamla(p_seans_admin_id := v_s, p_uygulanmadi := p_uygulanmadi, p_not := 'kb');
    IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN RAISE EXCEPTION 'FIXTURE: seans_tamamla %', v_r; END IF;
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN RAISE EXCEPTION 'FIXTURE: kb_seans_yap gün#% açık seans yok', p_gun_sira; END IF;
END $f$;

-- gün#k'ya ikinci (18:00) seans ekler (çok seanslı gün / kısmi seans fixture'ı); yeni seans id döner.
CREATE FUNCTION pg_temp.kb_seans_ekle(p_case uuid, p_gun_sira int) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.treatment_day_uygulamalar (treatment_day_id, case_id, planned_time, planned_date, stok_id, drug_product_id, dose, unit, route)
  SELECT u.treatment_day_id, u.case_id, '18:00', u.planned_date, u.stok_id, u.drug_product_id, u.dose, u.unit, u.route
    FROM public.treatment_day_uygulamalar u
   WHERE u.treatment_day_id = (SELECT d.id FROM public.treatment_days d WHERE d.case_id = p_case AND d.disease_id IS NULL
                                ORDER BY d.treatment_date, d.day_no OFFSET p_gun_sira - 1 LIMIT 1)
   ORDER BY u.planned_time LIMIT 1
  RETURNING id INTO v;
  IF v IS NULL THEN RAISE EXCEPTION 'FIXTURE: kb_seans_ekle gün#% yok', p_gun_sira; END IF;
  RETURN v;
END $f$;

-- İfadeyi koşar, yakalanan hata metnini döner (hata yoksa NULL). SQLSTATE başa eklenir: '<sqlstate>|<mesaj>'.
CREATE FUNCTION pg_temp.kb_hata(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN NULL;
EXCEPTION WHEN others THEN
  RETURN SQLSTATE || '|' || SQLERRM;
END $f$;

-- ── D3 ek yardımcıları (görev doğumu / anahtar / G7 / G9) ───────────────────
-- Düve (doğum kaydı yok): _ovsync_kural_tarihi = dogum_tarihi + 12 ay 21 gün = p_kural olacak doğum tarihiyle kurulur.
CREATE FUNCTION pg_temp.kb_duve(p_kural date, p_kisir boolean DEFAULT false) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_d date; v_h text;
BEGIN
  SELECT x::date INTO v_d FROM generate_series(p_kural - 420, p_kural - 360, interval '1 day') AS x
   WHERE (x::date + interval '12 months 21 days')::date = p_kural ORDER BY x DESC LIMIT 1;
  IF v_d IS NULL THEN RAISE EXCEPTION 'FIXTURE: kb_duve % için doğum tarihi yok', p_kural; END IF;
  v_h := pg_temp.kb_hayvan(pg_temp.kb_bugun() - v_d, 'Aktif', p_kisir);
  IF public._ovsync_kural_tarihi(v_h) IS DISTINCT FROM p_kural THEN
    RAISE EXCEPTION 'FIXTURE: kb_duve kural % ≠ %', public._ovsync_kural_tarihi(v_h), p_kural; END IF;
  RETURN v_h;
END $f$;

-- Hayvanın açık OVSYNC_BASLAT görevleri (id, hedef_tarih, kaynak) — sayı assert'leri için
CREATE FUNCTION pg_temp.kb_acik_ob(p_hayvan text) RETURNS TABLE (id uuid, hedef_tarih date, kaynak text)
LANGUAGE sql STABLE AS $f$
  SELECT g.id, g.hedef_tarih, g.kaynak FROM public.gorev_log g
   WHERE g.hayvan_id = p_hayvan AND g.gorev_tipi = 'OVSYNC_BASLAT'
     AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
$f$;

-- ovsync_baslat_uyarilari() içinde hayvanın satırı (yoksa NULL; birden çoksa hata)
CREATE FUNCTION pg_temp.kb_uyari(p_hayvan text) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE v jsonb; v_n int;
BEGIN
  SELECT count(*), min(u::text)::jsonb INTO v_n, v
    FROM jsonb_array_elements(public.ovsync_baslat_uyarilari()->'uyarilar') u WHERE u->>'hayvan_id' = p_hayvan;
  IF v_n > 1 THEN RAISE EXCEPTION 'FIXTURE: kb_uyari % satır %', p_hayvan, v_n; END IF;
  RETURN v;
END $f$;

-- Bekliyor tohumlama (Boş/G7 fixture'ı)
CREATE FUNCTION pg_temp.kb_toh_bekliyor(p_hayvan text, p_tarih date) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (p_hayvan, p_tarih, 'Bekliyor', 'KB-SP') RETURNING id INTO v;
  RETURN v;
END $f$;

-- Eski (R10 öncesi) biçimde kapanmış ACIK-DISI instance: 'ACIK-DISI-<h>-<kural>'
CREATE FUNCTION pg_temp.kb_eski_instance(p_hayvan text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum, kapandi_at, kapandi_sebep)
  VALUES (p_hayvan, 'UREME', 'ILK_TOHUMLAMA', 'ACIK-DISI-' || p_hayvan || '-' || public._ovsync_kural_tarihi(p_hayvan)::text,
          pg_temp.kb_bugun() - 400, 'tamamlandi', now() - interval '30 days', 'kb eski');
END $f$;

-- Runbook P1(c): eski anahtar çakışmasıyla takılı hayvan listesi (eski biçim instance kural günüyle eşleşir, hayvan uygun,
-- açık görev yok — _acik_disi_ovsync_hedef açık görevde zaten NULL döner)
CREATE FUNCTION pg_temp.kb_takili(p_hayvan text) RETURNS boolean LANGUAGE sql STABLE AS $f$
  SELECT EXISTS (SELECT 1 FROM public.protokol_instance pi
                  WHERE pi.hayvan_id = p_hayvan
                    AND pi.kaynak_ref = 'ACIK-DISI-' || pi.hayvan_id || '-' || public._ovsync_kural_tarihi(pi.hayvan_id)::text
                    AND public._acik_disi_ovsync_hedef(pi.hayvan_id) IS NOT NULL)
$f$;

-- ── D4 ek yardımcıları (başlatma yolları / K8) ──────────────────────────────
-- Açık OVSYNC_BASLAT görevi (doğrudan INSERT; hedef verilen gün) — id döner
CREATE FUNCTION pg_temp.kb_ob_gorev(p_hayvan text, p_hedef date) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, kaynak)
  VALUES (p_hayvan, 'OVSYNC_BASLAT', 'kb ovsync başlat', p_hedef, 'KB-OB-' || p_hayvan) RETURNING id INTO v;
  RETURN v;
END $f$;

-- Vakanın tren etiketi, start_date'i ve hastalık-dışı gün#1 tarihi (tek satır)
CREATE FUNCTION pg_temp.kb_vaka_d0(p_case uuid) RETURNS TABLE (ovsync_tren date, start_date date, gun1 date)
LANGUAGE plpgsql STABLE AS $f$
BEGIN
  RETURN QUERY SELECT c.ovsync_tren, c.start_date,
                      (SELECT min(d.treatment_date) FROM public.treatment_days d WHERE d.case_id = c.id AND d.disease_id IS NULL)
                 FROM public.cases c WHERE c.id = p_case;
END $f$;


-- ── D5 ek yardımcıları (K10 kilidi / K9) ────────────────────────────────────
-- gorev_ertele_kural prod satırları (MEASURED 2026-11-09, Management API read_only). Kabul DB verisizdir ve gorev_ertele'nin
-- kural adımı (fail-closed) kilitten önce gelir; senaryo içinde tohumlanır (savepoint geri sarar).
CREATE FUNCTION pg_temp.kb_ertele_kural() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO public.gorev_ertele_kural (gorev_tipi, ertelenebilir, pencere_kurali, max_erteleme_gun, asimi_uyari_gun, zincir_tetikler)
  SELECT v.t, v.e, v.p, NULL, 7, v.z
    FROM (VALUES ('OVSYNC_BASLAT', true, 'tohumlama', '{"tai_ofset_gun": 10}'::jsonb),
                 ('TOHUMLAMA_PLANLI', true, 'tohumlama', '{}'::jsonb),
                 ('ILAC', true, 'yok', '{}'::jsonb),
                 ('TEDAVI_GUN', false, 'yok', '{}'::jsonb),
                 ('TEDAVI_SEANS', false, 'yok', '{}'::jsonb)) AS v(t, e, p, z)
   WHERE NOT EXISTS (SELECT 1 FROM public.gorev_ertele_kural k WHERE k.gorev_tipi = v.t);
END $f$;

-- Ovsync şablon TAI'si (kaynak TEDAVI_SABLON_TOHUMLAMA:<case>:<şablon>, D0+10 10:00; vaka_kalan_gunleri_kaydir 8. adımı bunu taşır)
CREATE FUNCTION pg_temp.kb_ovsync_tai(p_case uuid, p_d0 date) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v_r jsonb;
BEGIN
  v_r := public.tedavi_sablon_tohumlama_gorev_ekle(p_case, 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'::uuid, p_d0);
  IF NOT COALESCE((v_r->>'olustu')::boolean, false) THEN RAISE EXCEPTION 'FIXTURE: kb_ovsync_tai %', v_r; END IF;
  RETURN (v_r->>'gorev_id')::uuid;
END $f$;

-- Mastit vakası (Ovsync dışı) + p_gun tarihli bir tedavi günü; case_id döner
CREATE FUNCTION pg_temp.kb_mastit(p_hayvan text, p_gun date) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v_m jsonb; v_c uuid;
BEGIN
  v_m := public.create_case(p_hayvan, '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb mastit');
  v_c := (v_m->>'case_id')::uuid;
  IF v_c IS NULL THEN RAISE EXCEPTION 'FIXTURE: kb_mastit create_case %', v_m; END IF;
  PERFORM public.add_treatment_day_with_sessions(v_c, p_gun, NULL, NULL);
  RETURN v_c;
END $f$;

-- Vakanın günlerine bağlı ilk açık görev (tip; hedef_tarih sırası) — coklu kaydırma girdisi
CREATE FUNCTION pg_temp.kb_vaka_gorev(p_case uuid, p_tip text) RETURNS uuid LANGUAGE plpgsql STABLE AS $f$
DECLARE v uuid;
BEGIN
  SELECT g.id INTO v FROM public.gorev_log g JOIN public.treatment_days d ON d.id::text = g.aciklama::jsonb->>'day_id'
   WHERE d.case_id = p_case AND g.gorev_tipi = p_tip AND left(g.aciklama, 1) = '{'
     AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
   ORDER BY g.hedef_tarih, g.id LIMIT 1;
  IF v IS NULL THEN RAISE EXCEPTION 'FIXTURE: kb_vaka_gorev % % yok', p_case, p_tip; END IF;
  RETURN v;
END $f$;

-- Vakanın hastalık-dışı gün tarihleri (sıralı dizi) — "değişmedi/kaydı" assert'leri
CREATE FUNCTION pg_temp.kb_gunler(p_case uuid) RETURNS date[] LANGUAGE sql STABLE AS $f$
  SELECT COALESCE(array_agg(d.treatment_date ORDER BY d.treatment_date, d.day_no), '{}') FROM public.treatment_days d
   WHERE d.case_id = p_case AND d.disease_id IS NULL
$f$;

-- OVSYNC_TREN_EKRANI hata metninden JSON gövdesi (kb_hata biçimi '<sqlstate>|OVSYNC_TREN_EKRANI:{…}'); başka hata → NULL
CREATE FUNCTION pg_temp.kb_ekrani(p_e text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE WHEN p_e LIKE 'P0001|OVSYNC_TREN_EKRANI:{%' THEN substr(p_e, length('P0001|OVSYNC_TREN_EKRANI:') + 1)::jsonb END
$f$;

-- ── D6 ek yardımcıları (aşama RPC'leri / K11) ───────────────────────────────
-- Hata metninden verilen kodun JSON gövdesi (kb_hata biçimi '<sqlstate>|KOD:{…}'); başka hata → NULL
CREATE FUNCTION pg_temp.kb_kod(p_e text, p_kod text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE WHEN p_e LIKE 'P0001|' || p_kod || ':{%' THEN substr(p_e, length('P0001|' || p_kod || ':') + 1)::jsonb END
$f$;

-- "Geriye" fixture: vakanın tüm günlerini, seans planlarını, uygulanma anlarını, gün görevlerini ve tren etiketini p_n gün geri alır
-- (zaman ilerletilemediği için "planlanan günden N gün sonra tamamlandı" böyle kurulur; tamamlandi bayrakları değişmez).
CREATE FUNCTION pg_temp.kb_geri(p_case uuid, p_n int) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.gorev_log g SET hedef_tarih = g.hedef_tarih - p_n
   WHERE g.gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS') AND left(g.aciklama, 1) = '{'
     AND g.aciklama::jsonb->>'day_id' IN (SELECT d.id::text FROM public.treatment_days d WHERE d.case_id = p_case);
  UPDATE public.treatment_days SET treatment_date = treatment_date - p_n WHERE case_id = p_case;
  UPDATE public.treatment_day_uygulamalar
     SET planned_date = planned_date - p_n, uygulama_tamamlandi_at = uygulama_tamamlandi_at - make_interval(days => p_n)
   WHERE case_id = p_case;
  UPDATE public.cases SET ovsync_tren = ovsync_tren - p_n WHERE id = p_case AND ovsync_tren IS NOT NULL;
END $f$;

-- Vakanın hastalık-dışı gün#k'sının açık seanslarını tek tek seans_tamamla ile kapatır; SON çağrının dönüşü
CREATE FUNCTION pg_temp.kb_seans_yap_r(p_case uuid, p_gun_sira int) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE v_s uuid; v_r jsonb;
BEGIN
  FOR v_s IN
    SELECT u.id FROM public.treatment_day_uygulamalar u
     WHERE u.treatment_day_id = (SELECT d.id FROM public.treatment_days d WHERE d.case_id = p_case AND d.disease_id IS NULL
                                  ORDER BY d.treatment_date, d.day_no OFFSET p_gun_sira - 1 LIMIT 1)
       AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)
     ORDER BY u.planned_time
  LOOP
    v_r := public.seans_tamamla(p_seans_admin_id := v_s, p_not := 'kb');
    IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN RAISE EXCEPTION 'FIXTURE: seans_tamamla %', v_r; END IF;
  END LOOP;
  IF v_r IS NULL THEN RAISE EXCEPTION 'FIXTURE: kb_seans_yap_r gün#% açık seans yok', p_gun_sira; END IF;
  RETURN v_r;
END $f$;

-- Hastalık-dışı gün#k'nın seans id'leri (planned_time sırası)
CREATE FUNCTION pg_temp.kb_seanslar(p_case uuid, p_gun_sira int) RETURNS uuid[] LANGUAGE sql STABLE AS $f$
  SELECT COALESCE(array_agg(u.id ORDER BY u.planned_time), '{}') FROM public.treatment_day_uygulamalar u
   WHERE u.treatment_day_id = (SELECT d.id FROM public.treatment_days d WHERE d.case_id = p_case AND d.disease_id IS NULL
                                ORDER BY d.treatment_date, d.day_no OFFSET p_gun_sira - 1 LIMIT 1)
$f$;

-- Hayvanın açık PG_TOHUMLAMA TAI'si (son hedef) — K6(a) fixture'ları
CREATE FUNCTION pg_temp.kb_pg_tai(p_hayvan text) RETURNS uuid LANGUAGE sql STABLE AS $f$
  SELECT g.id FROM public.gorev_log g
   WHERE g.hayvan_id = p_hayvan AND g.gorev_tipi = 'TOHUMLAMA_PLANLI' AND g.kaynak LIKE 'PG_TOHUMLAMA:%'
     AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
   ORDER BY g.hedef_tarih DESC, g.hedef_saat DESC NULLS LAST LIMIT 1
$f$;

-- ── D7 ek yardımcıları (tren listesi / toptan erteleme) ─────────────────────
-- ovsync_tren_listele dönüşünde hayvanın üye satırı + _tren/_ritim_disi (trende) ya da _bagimsiz; _adet = toplam görünme sayısı
CREATE FUNCTION pg_temp.kb_liste_uye(p_l jsonb, p_hayvan text) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $f$
DECLARE v jsonb; v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM (
    SELECT 1 FROM jsonb_array_elements(p_l->'trenler') t, jsonb_array_elements(t.value->'uyeler') u WHERE u.value->>'hayvan_id' = p_hayvan
    UNION ALL
    SELECT 1 FROM jsonb_array_elements(p_l->'bagimsizlar') u WHERE u.value->>'hayvan_id' = p_hayvan) x;
  SELECT u.value || jsonb_build_object('_tren', t.value->'tren_gunu', '_ritim_disi', t.value->'ritim_disi') INTO v
    FROM jsonb_array_elements(p_l->'trenler') t, jsonb_array_elements(t.value->'uyeler') u WHERE u.value->>'hayvan_id' = p_hayvan LIMIT 1;
  IF v IS NULL THEN
    SELECT u.value || jsonb_build_object('_bagimsiz', true) INTO v
      FROM jsonb_array_elements(p_l->'bagimsizlar') u WHERE u.value->>'hayvan_id' = p_hayvan LIMIT 1;
  END IF;
  RETURN COALESCE(v, '{}'::jsonb) || jsonb_build_object('_adet', v_n);
END $f$;

-- Toptan plan/önizleme uyeler[] içinde hayvanın satırı (yoksa NULL)
CREATE FUNCTION pg_temp.kb_plan_uye(p_p jsonb, p_hayvan text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT u.value FROM jsonb_array_elements(p_p->'uyeler') u WHERE u.value->>'hayvan_id' = p_hayvan LIMIT 1
$f$;

-- Güncel tren çapası (protokol_ayar YYYYMMDD → date)
CREATE FUNCTION pg_temp.kb_capa() RETURNS date LANGUAGE sql STABLE AS $f$
  SELECT to_date(deger::bigint::text, 'YYYYMMDD') FROM public.protokol_ayar WHERE anahtar = 'ovsync_tren_capa'
$f$;

-- Yazma izleri özeti (önizleme yazmaz / hiçbir şey değişmedi assert'leri)
CREATE FUNCTION pg_temp.kb_ozet() RETURNS text LANGUAGE sql STABLE AS $f$
  SELECT md5(concat_ws('|',
    (SELECT string_agg(concat_ws(',', id, hedef_tarih, hedef_saat, tamamlandi, iptal, kapatan_ref), ';' ORDER BY id) FROM public.gorev_log),
    (SELECT string_agg(concat_ws(',', id, treatment_date, tamamlandi), ';' ORDER BY id) FROM public.treatment_days),
    (SELECT string_agg(concat_ws(',', id, planned_date, uygulama_tamamlandi_at, uygulanmadi), ';' ORDER BY id) FROM public.treatment_day_uygulamalar),
    (SELECT string_agg(concat_ws(',', id, status, close_reason, ovsync_tren), ';' ORDER BY id) FROM public.cases),
    (SELECT string_agg(concat_ws(',', anahtar, deger), ';' ORDER BY anahtar) FROM public.protokol_ayar),
    (SELECT count(*)::text FROM public.islem_log)))
$f$;

-- TR-K7-1/2/ONIZLE ortak fixture (X = p_x tren günü, çapa p_x): h1/h2 açık OVSYNC_BASLAT hedef X (aşama 0, sınıf i);
-- h3 D7 vakası (D0 X−7 geriye tarihli, aşama 1, etiket X−7, şablon TAI); h6 bağımsız (D0 X, K9 hastalık günü → etiket NULL);
-- h7 ileri görev hedef X+7. Dönüş: {h1,h2,h3,h6,h7,g1,g2,g7,c3,c6}
CREATE FUNCTION pg_temp.kb_k7_fixture(p_x date) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE v jsonb := '{}'::jsonb; v_h text; v_c uuid;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(p_x);
  v_h := pg_temp.kb_hayvan(); v := v || jsonb_build_object('h1', v_h, 'g1', pg_temp.kb_ob_gorev(v_h, p_x));
  v_h := pg_temp.kb_hayvan(); v := v || jsonb_build_object('h2', v_h, 'g2', pg_temp.kb_ob_gorev(v_h, p_x));
  v_h := pg_temp.kb_hayvan(); v_c := pg_temp.kb_ovsync_vaka(v_h, p_x - 7);
  PERFORM pg_temp.kb_ovsync_tai(v_c, p_x - 7);
  v := v || jsonb_build_object('h3', v_h, 'c3', v_c);
  v_h := pg_temp.kb_hayvan(); v_c := pg_temp.kb_ovsync_vaka(v_h, p_x);
  PERFORM public.ovsync_hastalik_gunu_ekle(v_c);
  v := v || jsonb_build_object('h6', v_h, 'c6', v_c);
  v_h := pg_temp.kb_hayvan(); v := v || jsonb_build_object('h7', v_h, 'g7', pg_temp.kb_ob_gorev(v_h, p_x + 7));
  PERFORM set_config('app.ovsync_tren_ic', '', true);   -- hastalık RPC'sinin iç bayrağı fixture dışına sızmasın
  IF public._ovsync_asama((v->>'c3')::uuid) IS DISTINCT FROM 1
     OR (SELECT ovsync_tren FROM public.cases WHERE id = (v->>'c3')::uuid) IS DISTINCT FROM p_x - 7
     OR (SELECT ovsync_tren FROM public.cases WHERE id = (v->>'c6')::uuid) IS NOT NULL THEN
    RAISE EXCEPTION 'FIXTURE: kb_k7_fixture %', v;
  END IF;
  RETURN v;
END $f$;

-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM F0 — Doğum sonrası PG → hatırlatma (D1, migration 20261110100001)
-- ════════════════════════════════════════════════════════════════════════════

-- TR-F0-1: bayrak 0 → doğumda PG görevi açılmaz; diğer anne görevleri açılır
SAVEPOINT kb_s;
DO $t$
DECLARE v_anne text; v_var boolean; v_r jsonb; v_n int; v_digr int;
BEGIN
  v_var  := pg_temp.kb_ayar('dogum_sonrasi_pg_gorev_aktif', 0);
  v_anne := pg_temp.kb_hayvan(1500);
  v_r := public.dogum_kaydet(v_anne, pg_temp.kb_bugun() - 1, pg_temp.kb_id('KB-YV'));
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'TR-F0-1', 'dogum_kaydet ok', v_r::text);
  v_n := pg_temp.kb_dogum_pg_sayi(v_anne);
  PERFORM pg_temp.kb_ok(v_n = 0, 'TR-F0-1', 'açık doğum PG görevi 0', v_n::text);
  SELECT count(*) INTO v_digr FROM public.gorev_log
   WHERE hayvan_id = v_anne AND NOT tamamlandi AND NOT iptal
     AND aciklama IN ('Doğum günü: Oksitosin', 'Doğum günü: Ademin', 'Doğum günü: Kalsiyum', '53. Gün: E Vitamini');
  PERFORM pg_temp.kb_ok(v_digr = 4, 'TR-F0-1', 'Oksitosin/Ademin/Kalsiyum/E Vitamini 4 görev', v_digr::text);
  PERFORM pg_temp.kb_ok((v_r->>'gorev_sayisi')::int = 12, 'TR-F0-1', 'gorev_sayisi 12 (5 anne + 7 buzağı)', v_r->>'gorev_sayisi');
  PERFORM pg_temp.kb_ok(v_var, 'TR-F0-1', 'ayar satırı dogum_sonrasi_pg_gorev_aktif var', v_var::text);
  RAISE NOTICE 'PASS TR-F0-1: bayrak 0 → PG görevi yok, diğer anne görevleri var';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-F0-2: bayrak 1 → arşiv kodu canlı, üç PG görevi gününde açılır
SAVEPOINT kb_s;
DO $t$
DECLARE v_anne text; v_var boolean; v_r jsonb; v_p date := pg_temp.kb_bugun() - 1; v_n int;
BEGIN
  v_var  := pg_temp.kb_ayar('dogum_sonrasi_pg_gorev_aktif', 1);
  PERFORM pg_temp.kb_ok(v_var, 'TR-F0-2', 'ayar satırı var', v_var::text);
  v_anne := pg_temp.kb_hayvan(1500);
  v_r := public.dogum_kaydet(v_anne, v_p, pg_temp.kb_id('KB-YV'));
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'TR-F0-2', 'dogum_kaydet ok', v_r::text);
  SELECT count(*) INTO v_n FROM public.gorev_log
   WHERE hayvan_id = v_anne AND gorev_tipi = 'ILAC' AND etken_kod = 'PG' AND NOT tamamlandi AND NOT iptal
     AND kaynak = 'DOGUM-' || v_anne
     AND ((aciklama = '2. Gün PG' AND hedef_tarih = v_p + 2)
       OR (aciklama = '25. Gün PG' AND hedef_tarih = v_p + 25)
       OR (aciklama = '39. Gün PG (Presynch-14 senkron)' AND hedef_tarih = v_p + 39));
  PERFORM pg_temp.kb_ok(v_n = 3, 'TR-F0-2', 'üç PG görevi (d2/d25/d39, etken PG)', v_n::text);
  PERFORM pg_temp.kb_ok((v_r->>'gorev_sayisi')::int = 15, 'TR-F0-2', 'gorev_sayisi 15 (8 anne + 7 buzağı)', v_r->>'gorev_sayisi');
  RAISE NOTICE 'PASS TR-F0-2: bayrak 1 → üç PG görevi açılır';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-F0-3: bayrak 0 → doğumu bugün-2 ve bugün-25 olan Aktif dişi hatırlatmada (gun 2/25), bugün-3 yok;
--          son doğum esas (eski doğum satır üretmez), ikiz tek satır, Aktif olmayan görünmez
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_a2 text; v_a25 text; v_a3 text; v_eski text; v_ikiz text; v_pasif text;
        v_h jsonb; v_s jsonb; v_r jsonb;
BEGIN
  PERFORM pg_temp.kb_ayar('dogum_sonrasi_pg_gorev_aktif', 0);
  v_a2  := pg_temp.kb_hayvan(1500);  PERFORM public.dogum_kaydet(v_a2,  v_b - 2,  pg_temp.kb_id('KB-YV'));
  v_a25 := pg_temp.kb_hayvan(1500);  PERFORM public.dogum_kaydet(v_a25, v_b - 25, pg_temp.kb_id('KB-YV'));
  v_a3  := pg_temp.kb_hayvan(1500);  PERFORM public.dogum_kaydet(v_a3,  v_b - 3,  pg_temp.kb_id('KB-YV'));
  -- önceki doğum bugün-25 (ayrı olay), son doğum bugün-2 → yalnız gun 2 (önceki doğum satır üretmez)
  v_eski := pg_temp.kb_hayvan(2000);
  PERFORM public.dogum_kaydet(v_eski, v_b - 25, pg_temp.kb_id('KB-YV'));
  PERFORM public.dogum_kaydet(v_eski, v_b - 2,   pg_temp.kb_id('KB-YV'));
  -- ikiz: aynı tarihte iki yavru → tek satır
  v_ikiz := pg_temp.kb_hayvan(1500);
  PERFORM public.dogum_kaydet(v_ikiz, v_b - 25, pg_temp.kb_id('KB-YV'));
  v_r := public.dogum_kaydet(v_ikiz, v_b - 25, pg_temp.kb_id('KB-YV'));
  PERFORM pg_temp.kb_ok((v_r->>'coklu_dogum')::boolean, 'TR-F0-3', 'ikinci yavru coklu_dogum', v_r::text);
  -- Aktif olmayan anne
  v_pasif := pg_temp.kb_hayvan(1500);
  PERFORM public.dogum_kaydet(v_pasif, v_b - 2, pg_temp.kb_id('KB-YV'));
  UPDATE public.hayvanlar SET durum = 'Satıldı' WHERE id = v_pasif;

  v_h := public.dogum_sonrasi_pg_hatirlatma();
  PERFORM pg_temp.kb_ok((v_h->>'ok')::boolean AND (v_h->>'aktif')::boolean, 'TR-F0-3', 'ok=true aktif=true', v_h::text);

  v_s := pg_temp.kb_hatirlatma(ARRAY[v_a2]);
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_s) = 1 AND (v_s->0->>'gun')::int = 2
                        AND (v_s->0->>'dogum_tarihi')::date = v_b - 2 AND v_s->0->>'kupe_no' = v_a2,
                        'TR-F0-3', 'bugün-2 → tek satır gun 2, dogum_tarihi, kupe_no', v_s::text);
  v_s := pg_temp.kb_hatirlatma(ARRAY[v_a25]);
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_s) = 1 AND (v_s->0->>'gun')::int = 25
                        AND (v_s->0->>'dogum_tarihi')::date = v_b - 25,
                        'TR-F0-3', 'bugün-25 → tek satır gun 25', v_s::text);
  v_s := pg_temp.kb_hatirlatma(ARRAY[v_a3]);
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_s) = 0, 'TR-F0-3', 'bugün-3 → satır yok', v_s::text);
  v_s := pg_temp.kb_hatirlatma(ARRAY[v_eski]);
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_s) = 1 AND (v_s->0->>'gun')::int = 2,
                        'TR-F0-3', 'son doğum esas → tek satır gun 2', v_s::text);
  v_s := pg_temp.kb_hatirlatma(ARRAY[v_ikiz]);
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_s) = 1 AND (v_s->0->>'gun')::int = 25,
                        'TR-F0-3', 'ikiz → tek satır gun 25', v_s::text);
  v_s := pg_temp.kb_hatirlatma(ARRAY[v_pasif]);
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_s) = 0, 'TR-F0-3', 'Aktif olmayan anne → satır yok', v_s::text);
  RAISE NOTICE 'PASS TR-F0-3: d2/d25 hatırlatma satırları, d3 yok';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-F0-4: bayrak 1 → hatırlatma kapalı (aktif=false, satirlar boş)
SAVEPOINT kb_s;
DO $t$
DECLARE v_a text; v_h jsonb;
BEGIN
  PERFORM pg_temp.kb_ayar('dogum_sonrasi_pg_gorev_aktif', 1);
  v_a := pg_temp.kb_hayvan(1500);
  PERFORM public.dogum_kaydet(v_a, pg_temp.kb_bugun() - 2, pg_temp.kb_id('KB-YV'));
  v_h := public.dogum_sonrasi_pg_hatirlatma();
  PERFORM pg_temp.kb_ok((v_h->>'ok')::boolean AND NOT (v_h->>'aktif')::boolean
                        AND jsonb_typeof(v_h->'satirlar') = 'array' AND jsonb_array_length(v_h->'satirlar') = 0,
                        'TR-F0-4', 'ok=true aktif=false satirlar=[]', v_h::text);
  RAISE NOTICE 'PASS TR-F0-4: bayrak 1 → satirlar boş';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-IZOL-1 (a): senaryo içinde protokol_ayar + işlem-yerel GUC değiştirilir
SAVEPOINT kb_s;
DO $t$
DECLARE v_var boolean; v_h text; v_n int;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  v_var := pg_temp.kb_ayar('dogum_sonrasi_pg_gorev_aktif', 1);
  PERFORM set_config('app.ovsync_tren_ic', '1', true);
  PERFORM pg_temp.kb_ok(v_var AND public._ayar('dogum_sonrasi_pg_gorev_aktif', 0) = 1
                        AND current_setting('app.ovsync_tren_ic', true) = '1',
                        'TR-IZOL-1', 'senaryo içinde ayar=1 ve GUC=1',
                        format('%s %s', public._ayar('dogum_sonrasi_pg_gorev_aktif', 0), current_setting('app.ovsync_tren_ic', true)));
  -- fixture sızıntısı ölçümü (D1 review KÜÇÜK-1): (a)'da bir KB- hayvanı kurulur, (b) hiç görmemeli
  v_h := pg_temp.kb_hayvan();
  SELECT count(*) INTO v_n FROM public.hayvanlar WHERE id = v_h AND id LIKE 'KB-%';
  PERFORM pg_temp.kb_ok(v_n = 1, 'TR-IZOL-1', 'senaryo içinde KB- fixture hayvanı var', v_n::text);
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-IZOL-1 (b): sonraki senaryo ikisini de varsayılan görür
SAVEPOINT kb_s;
DO $t$
DECLARE v_n int;
BEGIN
  PERFORM pg_temp.kb_ok(public._ayar('dogum_sonrasi_pg_gorev_aktif', -1) = 0
                        AND COALESCE(current_setting('app.ovsync_tren_ic', true), '') = '',
                        'TR-IZOL-1', 'geri sarım sonrası ayar=0 ve GUC boş',
                        format('%s %s', public._ayar('dogum_sonrasi_pg_gorev_aktif', -1), current_setting('app.ovsync_tren_ic', true)));
  SELECT count(*) INTO v_n FROM public.hayvanlar WHERE id LIKE 'KB-%';
  PERFORM pg_temp.kb_ok(v_n = 0, 'TR-IZOL-1', 'geri sarım sonrası KB- hayvanı 0 (fixture sızıntısı yok)', v_n::text);
  RAISE NOTICE 'PASS TR-IZOL-1: savepoint geri sarımı ayar ve GUC''u sıfırlar';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-F0-ACL: hatırlatma RPC'si anon'a kapalı, authenticated'a açık; ayar tohumu sözleşmesi
SAVEPOINT kb_s;
DO $t$
DECLARE r record;
BEGIN
  PERFORM pg_temp.kb_ok(NOT has_function_privilege('anon', 'public.dogum_sonrasi_pg_hatirlatma()', 'EXECUTE'),
                        'TR-F0-ACL', 'anon EXECUTE false', 'true');
  PERFORM pg_temp.kb_ok(has_function_privilege('authenticated', 'public.dogum_sonrasi_pg_hatirlatma()', 'EXECUTE'),
                        'TR-F0-ACL', 'authenticated EXECUTE true', 'false');
  PERFORM pg_temp.kb_ok(NOT has_function_privilege('anon', 'public.dogum_kaydet(text,date,text,text,text,numeric,text,text)', 'EXECUTE'),
                        'TR-F0-ACL', 'dogum_kaydet anon EXECUTE false', 'true');
  SELECT * INTO r FROM public.protokol_ayar WHERE anahtar = 'dogum_sonrasi_pg_gorev_aktif';
  PERFORM pg_temp.kb_ok(FOUND AND r.deger = 0 AND r.min_deger = 0 AND r.max_deger = 1,
                        'TR-F0-ACL', 'ayar deger=0 min=0 max=1', format('%s %s %s', r.deger, r.min_deger, r.max_deger));
  RAISE NOTICE 'PASS TR-F0-ACL: anon kapalı, authenticated açık';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM K1/K2/AYAR/AŞAMA/ACL — Tren çekirdeği (D2, migration 20261110100002)
-- ════════════════════════════════════════════════════════════════════════════

-- TR-K1-1: tren günü hesabı (çapa Per 2026-11-12, öne çekme 2)
SAVEPOINT kb_s;
DO $t$
DECLARE v date;
BEGIN
  v := public._ovsync_tren_gunu_ic('2026-11-14', '2026-11-12', 2, '2026-11-09');
  PERFORM pg_temp.kb_ok(v = '2026-11-12', 'TR-K1-1', 'kural 11-14 → 11-12 (2 gün öne çekme)', v::text);
  v := public._ovsync_tren_gunu_ic('2026-11-15', '2026-11-12', 2, '2026-11-09');
  PERFORM pg_temp.kb_ok(v = '2026-11-19', 'TR-K1-1', 'kural 11-15 → 11-19 (sonraki tren)', v::text);
  v := public._ovsync_tren_gunu_ic('2026-11-19', '2026-11-12', 2, '2026-11-09');
  PERFORM pg_temp.kb_ok(v = '2026-11-19', 'TR-K1-1', 'kural 11-19 (tren günü) → 11-19', v::text);
  v := public._ovsync_tren_gunu_ic('2026-11-01', '2026-11-12', 2, '2026-11-13');
  PERFORM pg_temp.kb_ok(v = '2026-11-19', 'TR-K1-1', 'geçmiş kural 11-01, bugün 11-13 → 11-19 (bugünden önce tren yok)', v::text);
  v := public._ovsync_tren_gunu_ic(NULL, '2026-11-12', 2, '2026-11-09');
  PERFORM pg_temp.kb_ok(v IS NULL, 'TR-K1-1', 'NULL kural → NULL', v::text);
  RAISE NOTICE 'PASS TR-K1-1: _ovsync_tren_gunu_ic çapa 2026-11-12 tablo değerleri';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K2-N1: 3 gün öne çekme yok (öne çekme ayarı 2)
SAVEPOINT kb_s;
DO $t$
DECLARE v date;
BEGIN
  v := public._ovsync_tren_gunu_ic('2026-11-15', '2026-11-12', 2, '2026-11-09');
  PERFORM pg_temp.kb_ok(v <> '2026-11-12', 'TR-K2-N1', 'kural 11-15 → 11-12 DEĞİL (3 gün öne çekilmez)', v::text);
  v := public._ovsync_tren_gunu_ic('2026-11-14', '2026-11-12', 1, '2026-11-09');
  PERFORM pg_temp.kb_ok(v = '2026-11-19', 'TR-K2-N1', 'öne çekme 1 iken kural 11-14 → 11-19', v::text);
  RAISE NOTICE 'PASS TR-K2-N1: öne çekme sınırı aşılmaz';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K1-2: sonuç her zaman çapadan 7'nin katı uzakta, ≥ bugün, ≥ kural−2 ve ilk uygun tren
--   (10 sabit kural: bugün−30..bugün+51, 9 gün adım; mod 7 kalanlarının hepsi kapsanır — D2 review KÜÇÜK, random() kaldırıldı)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c date := pg_temp.kb_bugun() + 3; k date; v date; v_n int := 0;
BEGIN
  FOR k IN SELECT v_b + o FROM generate_series(-30, 51, 9) AS o LOOP
    v := public._ovsync_tren_gunu_ic(k, v_c, 2, v_b);
    PERFORM pg_temp.kb_ok(((v - v_c) % 7 + 7) % 7 = 0 AND v >= v_b AND v >= k - 2 AND v - 7 < GREATEST(k - 2, v_b),
                          'TR-K1-2', 'ritimde, ≥bugün, ≥kural−2, ilk uygun tren', format('kural %s → %s', k, v));
    v_n := v_n + 1;
  END LOOP;
  PERFORM pg_temp.kb_ok(v_n = 10, 'TR-K1-2', '10 kural', v_n::text);
  PERFORM pg_temp.kb_tren_ac(v_c);
  PERFORM pg_temp.kb_ok(public._ovsync_tren_gunu_mu(v_c) AND public._ovsync_tren_gunu_mu(v_c - 14) AND public._ovsync_tren_gunu_mu(v_c + 21)
                        AND NOT public._ovsync_tren_gunu_mu(v_c + 1) AND NOT public._ovsync_tren_gunu_mu(v_c - 3)
                        AND NOT public._ovsync_tren_gunu_mu(NULL),
                        'TR-K1-2', '_ovsync_tren_gunu_mu: çapa±7k true, diğerleri false', 'yanlış');
  RAISE NOTICE 'PASS TR-K1-2: 10 sabit kural ritimde';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-TZ-1: _ic yalnız p_bugun'a bağlı; açık trende _ovsync_tren_gunu bugünü TR (kb_bugun) alır
SAVEPOINT kb_s;
DO $t$
DECLARE v1 date; v2 date; v3 date; v_k date := pg_temp.kb_bugun() + 4;
BEGIN
  v1 := public._ovsync_tren_gunu_ic('2026-11-14', '2026-11-12', 2, '2026-11-09');
  v2 := public._ovsync_tren_gunu_ic('2026-11-14', '2026-11-12', 2, '2026-11-09');
  v3 := public._ovsync_tren_gunu_ic('2026-11-14', '2026-11-12', 2, '2026-11-13');
  PERFORM pg_temp.kb_ok(v1 = v2 AND v1 = '2026-11-12' AND v3 = '2026-11-19', 'TR-TZ-1',
                        'aynı bugün → aynı (11-12); bugün 11-13 → 11-19', format('%s %s %s', v1, v2, v3));
  PERFORM pg_temp.kb_tren_ac(pg_temp.kb_bugun() + 2);
  v1 := public._ovsync_tren_gunu(v_k);
  v2 := public._ovsync_tren_gunu_ic(v_k, pg_temp.kb_bugun() + 2, 2, pg_temp.kb_bugun());
  PERFORM pg_temp.kb_ok(v1 = v2 AND v1 = pg_temp.kb_bugun() + 2, 'TR-TZ-1',
                        '_ovsync_tren_gunu(bugün+4) = _ic(.., kb_bugun()) = bugün+2', format('%s %s', v1, v2));
  v1 := public._ovsync_tren_gunu(pg_temp.kb_bugun() - 10);
  PERFORM pg_temp.kb_ok(v1 = pg_temp.kb_bugun() + 2, 'TR-TZ-1', 'geçmiş kural → ilk tren ≥ TR bugünü', v1::text);
  RAISE NOTICE 'PASS TR-TZ-1: tren günü yalnız verilen bugüne bağlı, açık yol TR bugünü';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-REG-1: bayrak 0 → eski hedef (GREATEST(kural, bugün)); ayar bozuk olsa da okunmaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v date; v_e text;
BEGIN
  PERFORM pg_temp.kb_tren_kapat();
  PERFORM pg_temp.kb_ok(NOT public._ovsync_tren_aktif(), 'TR-REG-1', '_ovsync_tren_aktif()=false', public._ovsync_tren_aktif()::text);
  v := public._ovsync_tren_gunu(v_b + 5);
  PERFORM pg_temp.kb_ok(v = v_b + 5, 'TR-REG-1', 'kural bugün+5 → bugün+5', v::text);
  v := public._ovsync_tren_gunu(v_b - 3);
  PERFORM pg_temp.kb_ok(v = v_b, 'TR-REG-1', 'kural bugün−3 → bugün', v::text);
  PERFORM pg_temp.kb_ok(NOT public._ovsync_tren_gunu_mu('2026-11-12') AND NOT public._ovsync_tren_gunu_mu(v_b),
                        'TR-REG-1', 'kapalıyken çapa günü dahil tren günü yok', 'true');
  DELETE FROM public.protokol_ayar WHERE anahtar = 'ovsync_tren_capa';
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_tren_gunu(%L::date)', v_b + 5));
  PERFORM pg_temp.kb_ok(v_e IS NULL AND public._ovsync_tren_gunu(v_b + 5) = v_b + 5, 'TR-REG-1',
                        'kapalıyken çapa satırı yok → hata yok, eski hedef', v_e);
  -- tren ayarı 1 ama Ovsync-PG bayrağı 0 → tren kapalı sayılır
  PERFORM pg_temp.kb_ayar('ovsync_tren_aktif', 1);
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 0);
  PERFORM pg_temp.kb_ok(NOT public._ovsync_tren_aktif() AND public._ovsync_tren_gunu(v_b - 3) = v_b, 'TR-REG-1',
                        'ovsync_pg_kurallari_aktif=0 → tren kapalı', public._ovsync_tren_aktif()::text);
  RAISE NOTICE 'PASS TR-REG-1: bayrak 0 eski hedef, ayar okunmaz';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-AYAR-N1: bayrak 1 + çapa satırı silinmiş → OVSYNC_TREN_AYAR (sessiz düşüş yok)
SAVEPOINT kb_s;
DO $t$
DECLARE v_a jsonb; v_e text;
BEGIN
  PERFORM pg_temp.kb_tren_ac('2026-11-12');
  v_a := public._ovsync_tren_ayar();
  PERFORM pg_temp.kb_ok(public._ovsync_tren_aktif() AND (v_a->>'capa')::date = '2026-11-12'
                        AND (v_a->>'one_cekme')::int = 2 AND (v_a->>'tolerans')::int = 1,
                        'TR-AYAR-N1', 'sağlam ayar → {capa 2026-11-12, one_cekme 2, tolerans 1}', v_a::text);
  DELETE FROM public.protokol_ayar WHERE anahtar = 'ovsync_tren_capa';
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_tren_gunu(%L::date)', pg_temp.kb_bugun() + 5));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%'
                        AND (substr(v_e, length('P0001|OVSYNC_TREN_AYAR:') + 1)::jsonb)->>'anahtar' = 'ovsync_tren_capa'
                        AND (substr(v_e, length('P0001|OVSYNC_TREN_AYAR:') + 1)::jsonb)->>'sebep' = 'EKSIK',
                        'TR-AYAR-N1', '_ovsync_tren_gunu → OVSYNC_TREN_AYAR {anahtar ovsync_tren_capa, sebep EKSIK}', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_tren_gunu_mu(%L::date)', pg_temp.kb_bugun()));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%', 'TR-AYAR-N1', '_ovsync_tren_gunu_mu → OVSYNC_TREN_AYAR', v_e);
  RAISE NOTICE 'PASS TR-AYAR-N1: çapa yok → OVSYNC_TREN_AYAR';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-AYAR-N2: çapa 20261131 (geçersiz tarih) → OVSYNC_TREN_AYAR, ham 22008 dışarı çıkmaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_e text;
BEGIN
  PERFORM pg_temp.kb_tren_ac('2026-11-12');
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_tren_gunu(%L::date)', pg_temp.kb_bugun() + 5));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%' AND v_e NOT LIKE '22008%'
                        AND (substr(v_e, length('P0001|OVSYNC_TREN_AYAR:') + 1)::jsonb)->>'sebep' = 'TARIH_GECERSIZ',
                        'TR-AYAR-N2', 'OVSYNC_TREN_AYAR sebep TARIH_GECERSIZ (22008 değil)', v_e);
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261301);
  v_e := pg_temp.kb_hata('SELECT public._ovsync_tren_ayar()');
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%', 'TR-AYAR-N2', 'ay 13 → OVSYNC_TREN_AYAR', v_e);
  -- to_date('20261100') hata atmadan 2026-11-01 döner → gidiş-dönüş karşılaştırması yakalar
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261100);
  v_e := pg_temp.kb_hata('SELECT public._ovsync_tren_ayar()');
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%TARIH_GECERSIZ%', 'TR-AYAR-N2', 'gün 00 (to_date sessiz 11-01) → OVSYNC_TREN_AYAR', v_e);
  RAISE NOTICE 'PASS TR-AYAR-N2: 20261131 → OVSYNC_TREN_AYAR';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-AYAR-N4: çapa 20261112.5 (tam sayı değil) → OVSYNC_TREN_AYAR; tolerans/öne çekme aralık dışı da hata
SAVEPOINT kb_s;
DO $t$
DECLARE v_e text;
BEGIN
  PERFORM pg_temp.kb_tren_ac('2026-11-12');
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261112.5);
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_tren_gunu(%L::date)', pg_temp.kb_bugun() + 5));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%', 'TR-AYAR-N4', 'çapa 20261112.5 → OVSYNC_TREN_AYAR', v_e);
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261112);
  PERFORM pg_temp.kb_ayar('ovsync_pg_erteleme_tolerans_gun', -1);
  v_e := pg_temp.kb_hata('SELECT public._ovsync_tren_ayar()');
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%ovsync_pg_erteleme_tolerans_gun%', 'TR-AYAR-N4', 'tolerans −1 → OVSYNC_TREN_AYAR', v_e);
  PERFORM pg_temp.kb_ayar('ovsync_pg_erteleme_tolerans_gun', 1);
  PERFORM pg_temp.kb_ayar('ovsync_tren_one_cekme_gun', 3);
  v_e := pg_temp.kb_hata('SELECT public._ovsync_tren_ayar()');
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_AYAR:%ovsync_tren_one_cekme_gun%', 'TR-AYAR-N4', 'öne çekme 3 → OVSYNC_TREN_AYAR', v_e);
  RAISE NOTICE 'PASS TR-AYAR-N4: tam sayı olmayan çapa ve aralık dışı ayar → OVSYNC_TREN_AYAR';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-KAYMA-1: PG1 birikimli kayma (R18) = PG1 günü − (GnRH1 gerçek tamamlanma günü TR + 7)
SAVEPOINT kb_s;
DO $t$
DECLARE v_c0 uuid; v_c1 uuid; v_cg uuid; v_k int;
BEGIN
  v_c0 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_c0, 1);
  v_k := public._ovsync_pg1_kayma(v_c0);
  PERFORM pg_temp.kb_ok(v_k = 0, 'TR-KAYMA-1', 'GnRH1 planlı günde yapıldı → 0', v_k::text);
  v_c1 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun() - 1);
  PERFORM pg_temp.kb_seans_yap(v_c1, 1);
  v_k := public._ovsync_pg1_kayma(v_c1);
  PERFORM pg_temp.kb_ok(v_k = -1, 'TR-KAYMA-1', 'GnRH1 1 gün geç yapıldı → −1', v_k::text);
  -- PG1 günü 1 gün ileri alınırsa kayma +1 (birikimli; GnRH1 çapası değişmez)
  UPDATE public.treatment_days SET treatment_date = treatment_date + 1
   WHERE id = (SELECT id FROM public.treatment_days WHERE case_id = v_c0 AND disease_id IS NULL ORDER BY treatment_date, day_no OFFSET 1 LIMIT 1);
  v_k := public._ovsync_pg1_kayma(v_c0);
  PERFORM pg_temp.kb_ok(v_k = 1, 'TR-KAYMA-1', 'PG1 +1 gün → kayma 1', v_k::text);
  v_cg := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun() + 1);
  v_k := public._ovsync_pg1_kayma(v_cg);
  PERFORM pg_temp.kb_ok(v_k IS NULL, 'TR-KAYMA-1', 'aşama 0 → NULL', v_k::text);
  -- aşama 2 (PG1 de yapıldı) → değer döner; aşama belirsiz (PG1 günü kısmi seans) → NULL
  v_cg := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_cg, 1);
  PERFORM pg_temp.kb_seans_yap(v_cg, 2);
  v_k := public._ovsync_pg1_kayma(v_cg);
  PERFORM pg_temp.kb_ok(v_k = 0, 'TR-KAYMA-1', 'aşama 2 → 0', v_k::text);
  v_cg := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_cg, 1);
  PERFORM public.seans_tamamla(p_seans_admin_id := pg_temp.kb_seans_ekle(v_cg, 2));
  v_k := public._ovsync_pg1_kayma(v_cg);
  PERFORM pg_temp.kb_ok(v_k IS NULL, 'TR-KAYMA-1', 'aşama belirsiz (PG1 günü 2 seanstan 1i) → NULL', v_k::text);
  -- GnRH1 TR 01:00'de (UTC'de önceki gün) yapıldı; oturum UTC iken de TR günü esas → 0
  UPDATE public.treatment_day_uygulamalar SET uygulama_tamamlandi_at = pg_temp.kb_yerel(pg_temp.kb_bugun(), '01:00')
   WHERE treatment_day_id = (SELECT id FROM public.treatment_days WHERE case_id = v_c1 AND disease_id IS NULL ORDER BY treatment_date, day_no LIMIT 1);
  UPDATE public.treatment_days SET treatment_date = pg_temp.kb_bugun() + 7
   WHERE id = (SELECT id FROM public.treatment_days WHERE case_id = v_c1 AND disease_id IS NULL ORDER BY treatment_date, day_no OFFSET 1 LIMIT 1);
  PERFORM set_config('TimeZone', 'UTC', true);
  v_k := public._ovsync_pg1_kayma(v_c1);
  PERFORM pg_temp.kb_ok(v_k = 0, 'TR-KAYMA-1', 'GnRH1 TR 01:00 (UTC dün) → TR günü esas, kayma 0', v_k::text);
  RAISE NOTICE 'PASS TR-KAYMA-1: kayma 0 / −1 / +1 / NULL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ASAMA-0/1/2/N: aşama türetimi (R6)
SAVEPOINT kb_s;
DO $t$
DECLARE v_c uuid; v_a smallint;
BEGIN
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  v_a := public._ovsync_asama(v_c);
  PERFORM pg_temp.kb_ok(v_a = 0, 'TR-ASAMA-0', 'hiç seans yapılmadı → 0', v_a::text);
  RAISE NOTICE 'PASS TR-ASAMA-0: aşama 0';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

SAVEPOINT kb_s;
DO $t$
DECLARE v_c uuid; v_a smallint;
BEGIN
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_a := public._ovsync_asama(v_c);
  PERFORM pg_temp.kb_ok(v_a = 1, 'TR-ASAMA-1', 'gün#1 (GnRH1) yapıldı → 1', v_a::text);
  RAISE NOTICE 'PASS TR-ASAMA-1: aşama 1';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

SAVEPOINT kb_s;
DO $t$
DECLARE v_c uuid; v_a smallint;
BEGIN
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  v_a := public._ovsync_asama(v_c);
  PERFORM pg_temp.kb_ok(v_a = 2, 'TR-ASAMA-2', 'gün#1 + gün#2 (PG1) yapıldı → 2', v_a::text);
  RAISE NOTICE 'PASS TR-ASAMA-2: aşama 2';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

SAVEPOINT kb_s;
DO $t$
DECLARE v_c uuid; v_c2 uuid; v_a smallint; v_m jsonb;
BEGIN
  -- kısmi seans (R6-EK'te de belirsiz): gün#1'in 2 seansından yalnız biri uygulandı → NULL
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM public.seans_tamamla(p_seans_admin_id := pg_temp.kb_seans_ekle(v_c, 1));
  v_a := public._ovsync_asama(v_c);
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', 'gün#1 kısmi seans → NULL (belirsiz)', v_a::text);
  -- sıra tutarsız: gün#2 yapıldı, gün#1 yapılmadı → NULL
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_c2, 2);
  v_a := public._ovsync_asama(v_c2);
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', 'gün#2 yapıldı gün#1 yapılmadı → NULL', v_a::text);
  -- kapalı vaka / Ovsync olmayan vaka / olmayan id → NULL
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c2) = 0, 'TR-ASAMA-N', 'kapatma öncesi aşama 0', public._ovsync_asama(v_c2)::text);
  UPDATE public.cases SET status = 'closed', closed_at = now() WHERE id = v_c2;
  v_a := public._ovsync_asama(v_c2);
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', 'kapalı vaka → NULL', v_a::text);
  v_m := public.create_case(pg_temp.kb_hayvan(), '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb mastit');
  v_a := public._ovsync_asama((v_m->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', 'Ovsync olmayan vaka → NULL', v_a::text);
  -- gün sayısı ≠ 4 → NULL
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  DELETE FROM public.treatment_days
   WHERE id = (SELECT id FROM public.treatment_days WHERE case_id = v_c2 AND disease_id IS NULL ORDER BY treatment_date, day_no OFFSET 3 LIMIT 1);
  v_a := public._ovsync_asama(v_c2);
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', '3 gün → NULL', v_a::text);
  -- gün#1'in tüm seansları uygulanmış ama gün kapanmamış (tutarsız) → NULL
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  UPDATE public.treatment_day_uygulamalar SET uygulama_tamamlandi_at = now()
   WHERE treatment_day_id = (SELECT id FROM public.treatment_days WHERE case_id = v_c2 AND disease_id IS NULL ORDER BY treatment_date, day_no LIMIT 1);
  v_a := public._ovsync_asama(v_c2);
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', 'seansları uygulanmış ama gün kapanmamış → NULL', v_a::text);
  -- seanssız gün (tamamlandi=true, seans satırı yok) → yapıldı sayılmaz → NULL
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  DELETE FROM public.treatment_day_uygulamalar
   WHERE treatment_day_id = (SELECT id FROM public.treatment_days WHERE case_id = v_c2 AND disease_id IS NULL ORDER BY treatment_date, day_no LIMIT 1);
  UPDATE public.treatment_days SET tamamlandi = true
   WHERE id = (SELECT id FROM public.treatment_days WHERE case_id = v_c2 AND disease_id IS NULL ORDER BY treatment_date, day_no LIMIT 1);
  v_a := public._ovsync_asama(v_c2);
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', 'seanssız tamamlanmış gün → NULL', v_a::text);
  v_a := public._ovsync_asama(gen_random_uuid());
  PERFORM pg_temp.kb_ok(v_a IS NULL, 'TR-ASAMA-N', 'olmayan vaka → NULL', v_a::text);
  RAISE NOTICE 'PASS TR-ASAMA-N: belirsiz/tutarsız/aktif Ovsync olmayan → NULL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-R6EK-1 (root SORU-3): geriye tarihli gün (tamamlandi=true, seanslar işaretsiz) → yapıldı; kayma çapası treatment_date
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c uuid; v_d record; v_a smallint; v_k int;
BEGIN
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b - 3);
  SELECT d.tamamlandi, (SELECT count(*) FROM public.treatment_day_uygulamalar u WHERE u.treatment_day_id = d.id
                         AND (u.uygulama_tamamlandi_at IS NOT NULL OR u.uygulanmadi)) AS kapali INTO v_d
    FROM public.treatment_days d WHERE d.case_id = v_c AND d.disease_id IS NULL ORDER BY d.treatment_date, d.day_no LIMIT 1;
  PERFORM pg_temp.kb_ok(v_d.tamamlandi AND v_d.kapali = 0, 'TR-R6EK-1', 'fixture: gün#1 geçmiş → tamamlandi, seans işaretsiz', row_to_json(v_d)::text);
  v_a := public._ovsync_asama(v_c);  v_k := public._ovsync_pg1_kayma(v_c);
  PERFORM pg_temp.kb_ok(v_a = 1 AND v_k = 0, 'TR-R6EK-1', 'D0 = bugün−3: aşama 1, kayma 0 (çapa = D0)', format('%s %s', v_a, v_k));
  -- D0 = bugün−8: GnRH1 ve PG1 geçmiş (ikisi de geriye tarihli) → aşama 2, kayma 0
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b - 8);
  v_a := public._ovsync_asama(v_c);  v_k := public._ovsync_pg1_kayma(v_c);
  PERFORM pg_temp.kb_ok(v_a = 2 AND v_k = 0, 'TR-R6EK-1', 'D0 = bugün−8: aşama 2, kayma 0', format('%s %s', v_a, v_k));
  RAISE NOTICE 'PASS TR-R6EK-1: geriye tarihli işaretsiz gün yapıldı, çapa treatment_date';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-R6EK-2: geriye tarihli günde seans sonradan (bugün) işaretlendi → çapa işaret günü (LEAST yok)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c uuid; v_a smallint; v_k int;
BEGIN
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b - 2);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_a := public._ovsync_asama(v_c);  v_k := public._ovsync_pg1_kayma(v_c);
  PERFORM pg_temp.kb_ok(v_a = 1 AND v_k = -2, 'TR-R6EK-2', 'D0 = bugün−2, seans bugün işaretli: aşama 1, kayma −2 (çapa bugün)', format('%s %s', v_a, v_k));
  RAISE NOTICE 'PASS TR-R6EK-2: seans geç işaretli → çapa işaret günü';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-R6EK-3: uygulanmadı işaretli gün → yapılmadı (0/1 aşamasına girer)
SAVEPOINT kb_s;
DO $t$
DECLARE v_c uuid; v_a smallint; v_k int;
BEGIN
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_c, 1, true);
  v_a := public._ovsync_asama(v_c);  v_k := public._ovsync_pg1_kayma(v_c);
  PERFORM pg_temp.kb_ok(v_a = 0 AND v_k IS NULL, 'TR-R6EK-3', 'GnRH1 uygulanmadı → aşama 0, kayma NULL', format('%s %s', v_a, v_k));
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2, true);
  v_a := public._ovsync_asama(v_c);
  PERFORM pg_temp.kb_ok(v_a = 1, 'TR-R6EK-3', 'GnRH1 yapıldı, PG1 uygulanmadı → aşama 1', v_a::text);
  -- çok seanslı açık günde yalnız uygulanmadı işareti (uygulanan yok) → yapılmadı
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_ekle(v_c, 3);
  PERFORM public.seans_tamamla(p_seans_admin_id := (SELECT u.id FROM public.treatment_day_uygulamalar u
                                 WHERE u.treatment_day_id = (SELECT id FROM public.treatment_days WHERE case_id = v_c AND disease_id IS NULL ORDER BY treatment_date, day_no OFFSET 2 LIMIT 1)
                                 ORDER BY u.planned_time LIMIT 1), p_uygulanmadi := true);
  v_a := public._ovsync_asama(v_c);
  PERFORM pg_temp.kb_ok(v_a = 0, 'TR-R6EK-3', 'açık günde yalnız uygulanmadı seans → aşama 0', v_a::text);
  RAISE NOTICE 'PASS TR-R6EK-3: uygulanmadı → yapılmadı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-GUC: iç bayrak işlem-yerel; kendi savepoint'inde açılır, sonraki senaryoda yine kapalı
SAVEPOINT kb_s;
DO $t$
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ok(NOT public._ovsync_ic_mi(), 'TR-K10-GUC', 'başlangıçta _ovsync_ic_mi()=false', public._ovsync_ic_mi()::text);
  PERFORM public._ovsync_ic_ac();
  PERFORM pg_temp.kb_ok(public._ovsync_ic_mi() AND current_setting('app.ovsync_tren_ic', true) = '1',
                        'TR-K10-GUC', '_ovsync_ic_ac() sonrası true', public._ovsync_ic_mi()::text);
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

SAVEPOINT kb_s;
DO $t$
BEGIN
  PERFORM pg_temp.kb_ok(NOT public._ovsync_ic_mi(), 'TR-K10-GUC', 'sonraki senaryoda _ovsync_ic_mi()=false', public._ovsync_ic_mi()::text);
  RAISE NOTICE 'PASS TR-K10-GUC: iç bayrak işlem-yerel, geri sarımla kapanır';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-KILIT-0: Ovsync görevi tanımı (R5 a/b/c, bayraktan bağımsız, bozuk JSON güvenli) + kilit yardımcıları
SAVEPOINT kb_s;
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_d text := pg_temp.kb_hayvan(); v_c uuid; v_m jsonb;
        v_seans uuid; v_gun uuid; v_ob uuid; v_tai uuid; v_tai_d uuid; v_ilac uuid; v_boz uuid; v_duz uuid; v_mg uuid; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_kapat();
  v_c := pg_temp.kb_ovsync_vaka(v_h, pg_temp.kb_bugun());
  SELECT id INTO v_seans FROM public.gorev_log WHERE hayvan_id = v_h AND gorev_tipi = 'TEDAVI_SEANS' LIMIT 1;
  SELECT id INTO v_gun   FROM public.gorev_log WHERE hayvan_id = v_h AND gorev_tipi = 'TEDAVI_GUN' LIMIT 1;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'OVSYNC_BASLAT', 'kb', pg_temp.kb_bugun() + 3) RETURNING id INTO v_ob;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'TOHUMLAMA_PLANLI', 'kb', pg_temp.kb_bugun() + 10) RETURNING id INTO v_tai;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_d, 'TOHUMLAMA_PLANLI', 'kb', pg_temp.kb_bugun() + 10) RETURNING id INTO v_tai_d;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'ILAC', 'E Vitamini', pg_temp.kb_bugun()) RETURNING id INTO v_ilac;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'TEDAVI_GUN', '{"day_id": bozuk', pg_temp.kb_bugun()) RETURNING id INTO v_boz;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'TEDAVI_SEANS', 'Gün 1 düz metin', pg_temp.kb_bugun()) RETURNING id INTO v_duz;
  v_m := public.create_case(v_d, '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb mastit');
  PERFORM public.add_treatment_day_with_sessions((v_m->>'case_id')::uuid, pg_temp.kb_bugun() + 1, NULL, NULL);
  SELECT id INTO v_mg FROM public.gorev_log WHERE hayvan_id = v_d AND gorev_tipi = 'TEDAVI_GUN' LIMIT 1;
  -- bayrak kapalıyken de tanım aynı
  PERFORM pg_temp.kb_ok(public._ovsync_gorev_mu(v_ob) AND public._ovsync_gorev_mu(v_tai) AND public._ovsync_gorev_mu(v_seans)
                        AND public._ovsync_gorev_mu(v_gun), 'TR-KILIT-0', 'OVSYNC_BASLAT, Ovsync hayvan TAI, Ovsync TEDAVI_SEANS/GUN → true',
                        format('%s %s %s %s', public._ovsync_gorev_mu(v_ob), public._ovsync_gorev_mu(v_tai), public._ovsync_gorev_mu(v_seans), public._ovsync_gorev_mu(v_gun)));
  PERFORM pg_temp.kb_ok(v_mg IS NOT NULL AND NOT public._ovsync_gorev_mu(v_tai_d) AND NOT public._ovsync_gorev_mu(v_ilac) AND NOT public._ovsync_gorev_mu(v_mg)
                        AND NOT public._ovsync_gorev_mu(v_boz) AND NOT public._ovsync_gorev_mu(v_duz) AND NOT public._ovsync_gorev_mu(gen_random_uuid()),
                        'TR-KILIT-0', 'Ovsync olmayan TAI, ILAC, Mastit TEDAVI_GUN, bozuk/düz aciklama, olmayan id → false',
                        format('%s %s %s %s %s %s', v_mg, public._ovsync_gorev_mu(v_tai_d), public._ovsync_gorev_mu(v_ilac), public._ovsync_gorev_mu(v_mg),
                               public._ovsync_gorev_mu(v_boz), public._ovsync_gorev_mu(v_duz)));
  -- kilit: kapalıyken sessiz
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_kilit_gorev(%L::uuid), public._ovsync_kilit_vaka(%L::uuid)', v_ob, v_c));
  PERFORM pg_temp.kb_ok(v_e IS NULL, 'TR-KILIT-0', 'bayrak 0 → kilit yok', v_e);
  -- açık + iç değil → OVSYNC_TREN_EKRANI
  PERFORM pg_temp.kb_tren_ac(pg_temp.kb_bugun() + 3);
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_kilit_gorev(%L::uuid)', v_ob));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_EKRANI:%'
                        AND (substr(v_e, length('P0001|OVSYNC_TREN_EKRANI:') + 1)::jsonb) @> jsonb_build_object('gorev_id', v_ob, 'hayvan_id', v_h, 'tren_gunu', pg_temp.kb_bugun() + 3),
                        'TR-KILIT-0', 'Ovsync görevi → OVSYNC_TREN_EKRANI {gorev_id, hayvan_id, tren_gunu}', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_kilit_vaka(%L::uuid)', v_c));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_EKRANI:%'
                        AND (substr(v_e, length('P0001|OVSYNC_TREN_EKRANI:') + 1)::jsonb) @> jsonb_build_object('case_id', v_c, 'hayvan_id', v_h),
                        'TR-KILIT-0', 'OVSYNC vaka → OVSYNC_TREN_EKRANI {case_id, hayvan_id}', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_kilit_gorev(%L::uuid), public._ovsync_kilit_vaka(%L::uuid)', v_ilac, (v_m->>'case_id')));
  PERFORM pg_temp.kb_ok(v_e IS NULL, 'TR-KILIT-0', 'ILAC görevi ve Mastit vakası kilit dışı', v_e);
  -- iç bayrakla aşılır
  PERFORM public._ovsync_ic_ac();
  v_e := pg_temp.kb_hata(format('SELECT public._ovsync_kilit_gorev(%L::uuid), public._ovsync_kilit_vaka(%L::uuid)', v_ob, v_c));
  PERFORM pg_temp.kb_ok(v_e IS NULL, 'TR-KILIT-0', 'iç bayrak → kilit yok', v_e);
  RAISE NOTICE 'PASS TR-KILIT-0: Ovsync görevi tanımı ve kilit yardımcıları';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ACL-1: yeni iç yardımcılar anon/authenticated'a kapalı; tohum sözleşmesi + cases.ovsync_tren kolonu
SAVEPOINT kb_s;
DO $t$
DECLARE v_f text; r record; v_n int := 0;
BEGIN
  FOREACH v_f IN ARRAY ARRAY[
    'public._ovsync_tren_aktif()', 'public._ovsync_tren_ayar()', 'public._ovsync_tren_gunu_ic(date,date,integer,date)',
    'public._ovsync_tren_gunu(date)', 'public._ovsync_tren_gunu_mu(date)', 'public._ovsync_asama(uuid)',
    'public._ovsync_pg1_kayma(uuid)', 'public._ovsync_ic_ac()', 'public._ovsync_ic_mi()', 'public._ovsync_gorev_mu(uuid)',
    'public._ovsync_kilit_gorev(uuid)', 'public._ovsync_kilit_vaka(uuid)'] LOOP
    PERFORM pg_temp.kb_ok(NOT has_function_privilege('anon', v_f, 'EXECUTE') AND NOT has_function_privilege('authenticated', v_f, 'EXECUTE'),
                          'TR-ACL-1', v_f || ' anon/authenticated EXECUTE false', 'açık');
    v_n := v_n + 1;
  END LOOP;
  PERFORM pg_temp.kb_ok(v_n = 12, 'TR-ACL-1', '12 iç yardımcı', v_n::text);
  FOR r IN SELECT * FROM (VALUES ('ovsync_tren_aktif', 0::numeric, 'bool', 0::numeric, 1::numeric),
                                 ('ovsync_tren_capa', 20261112, 'YYYYMMDD', 20260101, 20991231),
                                 ('ovsync_tren_one_cekme_gun', 2, 'gün', 0, 2),
                                 ('ovsync_pg_erteleme_tolerans_gun', 1, 'gün', 0, 2)) AS b(anahtar, deger, birim, mn, mx) LOOP
    PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM public.protokol_ayar a WHERE a.anahtar = r.anahtar AND a.deger = r.deger
                                     AND a.birim = r.birim AND a.min_deger = r.mn AND a.max_deger = r.mx),
                          'TR-ACL-1', format('tohum %s=%s %s %s..%s', r.anahtar, r.deger, r.birim, r.mn, r.mx),
                          (SELECT format('%s %s %s..%s', a.deger, a.birim, a.min_deger, a.max_deger) FROM public.protokol_ayar a WHERE a.anahtar = r.anahtar));
  END LOOP;
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.cases'::regclass AND attname = 'ovsync_tren'
                                   AND atttypid = 'date'::regtype AND NOT attnotnull AND NOT attisdropped),
                        'TR-ACL-1', 'cases.ovsync_tren date NULL', 'yok');
  RAISE NOTICE 'PASS TR-ACL-1: iç yardımcılar kapalı, tohumlar ve kolon sözleşmede';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM D3 — Görev doğumu, anahtar (R10), G7/G9 (D3, migration 20261110100003)
-- ════════════════════════════════════════════════════════════════════════════

-- TR-DOGUM-1: açık, çapa bugün+2, düve kural bugün+3 → görev doğar, hedef bugün+2 (öne çekme); sınır tren−2 = bugün
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; r record; v_p jsonb;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_duve(v_b + 3);
  PERFORM pg_temp.kb_ok(public._acik_disi_hedef_ic(v_h) = v_b + 2, 'TR-DOGUM-1', '_acik_disi_hedef_ic = tren günü bugün+2',
                        public._acik_disi_hedef_ic(v_h)::text);
  v_g := public._acik_disi_gorev_kur(v_h);
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL, 'TR-DOGUM-1', 'tren−2 = bugün → görev doğar', '<NULL>');
  SELECT g.gorev_tipi, g.hedef_tarih, g.kaynak INTO r FROM public.gorev_log g WHERE g.id = v_g;
  PERFORM pg_temp.kb_ok(r.gorev_tipi = 'OVSYNC_BASLAT' AND r.hedef_tarih = v_b + 2, 'TR-DOGUM-1',
                        'OVSYNC_BASLAT hedef bugün+2 (kural bugün+3, 1 gün öne)', format('%s %s', r.gorev_tipi, r.hedef_tarih));
  PERFORM pg_temp.kb_ok(r.kaynak = format('ACIK-DISI-%s-%s-0', v_h, v_b + 3), 'TR-DOGUM-1',
                        'R10 anahtarı ACIK-DISI-<h>-<kural>-0 (tohumlama yok)', r.kaynak);
  SELECT l.payload INTO v_p FROM public.islem_log l WHERE l.ref_id = v_g::text AND l.tip = 'FIRST_SERVICE_ROUTE_CREATED';
  PERFORM pg_temp.kb_ok((v_p->>'tren_gunu')::date = v_b + 2 AND (v_p->>'hedef_tarih')::date = v_b + 2
                        AND (v_p->>'kural_tarihi')::date = v_b + 3, 'TR-DOGUM-1', 'islem_log payload tren_gunu/hedef/kural', v_p::text);
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM pg_temp.kb_acik_ob(v_h)) = 1, 'TR-DOGUM-1', 'tek açık OVSYNC_BASLAT',
                        (SELECT count(*) FROM pg_temp.kb_acik_ob(v_h))::text);
  RAISE NOTICE 'PASS TR-DOGUM-1: görev tren−2 günü doğar, hedef tren günü';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-DOGUM-N1: çapa bugün+4, kural bugün+5 → NULL (tren−2 > bugün); satır/instance doğmaz; p_hemen kapıyı atlar
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_h2 text; v_g uuid;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 4);
  v_h := pg_temp.kb_duve(v_b + 5);
  PERFORM pg_temp.kb_ok(public._acik_disi_hedef_ic(v_h) = v_b + 4, 'TR-DOGUM-N1', 'önizleme hedefi tren bugün+4',
                        public._acik_disi_hedef_ic(v_h)::text);
  v_g := public._acik_disi_gorev_kur(v_h);
  PERFORM pg_temp.kb_ok(v_g IS NULL, 'TR-DOGUM-N1', 'tren−2 = bugün+2 > bugün → NULL', v_g::text);
  PERFORM pg_temp.kb_ok(NOT EXISTS (SELECT 1 FROM pg_temp.kb_acik_ob(v_h))
                        AND NOT EXISTS (SELECT 1 FROM public.protokol_instance WHERE hayvan_id = v_h),
                        'TR-DOGUM-N1', 'görev satırı ve instance doğmadı', 'var');
  -- sınır: tren−2 = bugün+1 (çapa bugün+3, kural bugün+4) → yine NULL
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h2 := pg_temp.kb_duve(v_b + 4);
  PERFORM pg_temp.kb_ok(public._acik_disi_gorev_kur(v_h2) IS NULL, 'TR-DOGUM-N1', 'tren−2 = bugün+1 → NULL', 'görev açıldı');
  -- p_hemen (kullanıcı iradesi) kapıyı atlar, hedef yine tren günü
  PERFORM pg_temp.kb_tren_ac(v_b + 4);
  v_g := public._acik_disi_gorev_kur(v_h, p_hemen => true);
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 4,
                        'TR-DOGUM-N1', 'p_hemen → görev, hedef tren bugün+4', (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g)::text);
  RAISE NOTICE 'PASS TR-DOGUM-N1: tren−2 > bugün → görev doğmaz';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-REG-DOGUM: bayrak 0 → eski davranış (kural gelecekte NULL, p_hemen yok sayılır; kural geçmiş → hedef GREATEST(kural,bugün))
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_h2 text; v_h3 text; v_g uuid; r record; v_p jsonb;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);   -- bozuk çapa: kapalı yollar ayarı okumamalı
  v_h := pg_temp.kb_duve(v_b + 5);
  PERFORM pg_temp.kb_ok(public._acik_disi_hedef_ic(v_h) = v_b + 5, 'TR-REG-DOGUM', 'önizleme GREATEST(kural,bugün) = bugün+5',
                        public._acik_disi_hedef_ic(v_h)::text);
  PERFORM pg_temp.kb_ok(public._acik_disi_gorev_kur(v_h) IS NULL, 'TR-REG-DOGUM', 'kural bugün+5 → NULL (C5 kapısı)', 'görev');
  PERFORM pg_temp.kb_ok(public._acik_disi_gorev_kur(v_h, p_hemen => true) IS NULL, 'TR-REG-DOGUM', 'bayrak 0: p_hemen yok sayılır', 'görev');
  v_h2 := pg_temp.kb_duve(v_b - 10);
  v_g := public._acik_disi_gorev_kur(v_h2);
  SELECT g.hedef_tarih, g.kaynak INTO r FROM public.gorev_log g WHERE g.id = v_g;
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL AND r.hedef_tarih = v_b, 'TR-REG-DOGUM', 'kural geçmiş → hedef bugün', r.hedef_tarih::text);
  PERFORM pg_temp.kb_ok(r.kaynak = format('ACIK-DISI-%s-%s-0', v_h2, v_b - 10), 'TR-REG-DOGUM', 'R10 anahtarı bayraktan bağımsız', r.kaynak);
  SELECT l.payload INTO v_p FROM public.islem_log l WHERE l.ref_id = v_g::text AND l.tip = 'FIRST_SERVICE_ROUTE_CREATED';
  PERFORM pg_temp.kb_ok(v_p IS NOT NULL AND NOT (v_p ? 'tren_gunu') AND (v_p->>'hedef_tarih')::date = v_b,
                        'TR-REG-DOGUM', 'bayrak 0 payload eski biçim (tren_gunu yok)', v_p::text);
  -- 4-arg çağıran _ilk_tohumlama_rota_kur (dogum_kaydet/tohumlama_abort kancası) default p_hemen ile çözülür
  v_h3 := pg_temp.kb_duve(v_b - 20);
  v_g := public._ilk_tohumlama_rota_kur(v_h3, v_b - 60, 'KB-ROTA-' || v_h3);
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b,
                        'TR-REG-DOGUM', '_ilk_tohumlama_rota_kur (4 arg) → hedef bugün', COALESCE(v_g::text, '<NULL>'));
  RAISE NOTICE 'PASS TR-REG-DOGUM: bayrak 0 görev doğumu eski';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ANAH-1: eski biçim ACIK-DISI instance (tamamlandi) + Boş → G7 görev açar (yeni anahtar); açık görev varsa onun id'si;
--            tren açıkken G7 p_hemen ile doğar, hedef tren günü
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_t uuid; v_r jsonb; v_g uuid; v_ob uuid; r record;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_duve(v_b - 30);
  PERFORM pg_temp.kb_eski_instance(v_h);
  v_t := pg_temp.kb_toh_bekliyor(v_h, v_b - 5);
  v_r := public.tohumlama_bos_ve_devam(p_tohumlama_id => v_t::text, p_secim => 'OVSYNC');
  v_g := (v_r->>'ovsync_gorev_id')::uuid;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_g IS NOT NULL, 'TR-ANAH-1', 'ovsync_gorev_id NOT NULL (eski anahtar çakışmıyor)', v_r::text);
  SELECT g.kaynak, g.hedef_tarih INTO r FROM public.gorev_log g WHERE g.id = v_g;
  PERFORM pg_temp.kb_ok(r.kaynak = format('ACIK-DISI-%s-%s-%s', v_h, v_b - 30, v_t), 'TR-ANAH-1',
                        'kaynak yeni biçim ACIK-DISI-<h>-<kural>-<son tohumlama>', r.kaynak);
  PERFORM pg_temp.kb_ok(r.hedef_tarih = v_b AND (SELECT sonuc FROM public.tohumlama WHERE id = v_t) = 'Boş',
                        'TR-ANAH-1', 'bayrak 0 hedef bugün, tohumlama Boş', r.hedef_tarih::text);
  -- açık OVSYNC_BASLAT varsa onun id'si döner (R10)
  v_h := pg_temp.kb_duve(v_b - 30);
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'OVSYNC_BASLAT', 'kb', v_b + 1) RETURNING id INTO v_ob;
  v_t := pg_temp.kb_toh_bekliyor(v_h, v_b - 5);
  v_r := public.tohumlama_bos_ve_devam(p_tohumlama_id => v_t::text, p_secim => 'OVSYNC');
  PERFORM pg_temp.kb_ok((v_r->>'ovsync_gorev_id')::uuid = v_ob AND (SELECT count(*) FROM pg_temp.kb_acik_ob(v_h)) = 1,
                        'TR-ANAH-1', 'açık OVSYNC_BASLAT varken onun id''si, ikinci görev yok', v_r::text);
  -- tren açık: G7 kullanıcı iradesi → p_hemen; çapa bugün+5, tren−2 = bugün+3 > bugün olsa da görev doğar, hedef tren
  PERFORM pg_temp.kb_tren_ac(v_b + 5);
  v_h := pg_temp.kb_duve(v_b - 30);
  v_t := pg_temp.kb_toh_bekliyor(v_h, v_b - 5);
  v_r := public.tohumlama_bos_ve_devam(p_tohumlama_id => v_t::text, p_secim => 'OVSYNC');
  v_g := (v_r->>'ovsync_gorev_id')::uuid;
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 5,
                        'TR-ANAH-1', 'tren açık G7 → hedef tren bugün+5 (p_hemen)', v_r::text);
  RAISE NOTICE 'PASS TR-ANAH-1: R10 anahtarı + G7 görev';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ANAH-N1: aynı ama açık "senkron" ILAC görevi → OVSYNC_GOREV_ACILAMADI, Boş ataması dahil geri sarılır
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_t uuid; v_e text; v_j jsonb; v_durum text;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_duve(v_b - 30);
  PERFORM pg_temp.kb_eski_instance(v_h);
  v_t := pg_temp.kb_toh_bekliyor(v_h, v_b - 5);
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'ILAC', '39. Gün PG (Presynch-14 senkron)', v_b + 1);
  SELECT tohumlama_durumu INTO v_durum FROM public.hayvanlar WHERE id = v_h;
  v_e := pg_temp.kb_hata(format('SELECT public.tohumlama_bos_ve_devam(p_tohumlama_id => %L, p_secim => %L)', v_t, 'OVSYNC'));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_GOREV_ACILAMADI:%', 'TR-ANAH-N1', 'OVSYNC_GOREV_ACILAMADI', COALESCE(v_e, '<hata yok>'));
  v_j := substr(v_e, length('P0001|OVSYNC_GOREV_ACILAMADI:') + 1)::jsonb;
  PERFORM pg_temp.kb_ok(v_j->>'hayvan_id' = v_h AND v_j->>'sebep' = 'HEDEF_YOK', 'TR-ANAH-N1', 'payload {hayvan_id, sebep HEDEF_YOK}', v_j::text);
  PERFORM pg_temp.kb_ok((SELECT sonuc FROM public.tohumlama WHERE id = v_t) = 'Bekliyor'
                        AND (SELECT tohumlama_durumu FROM public.hayvanlar WHERE id = v_h) IS NOT DISTINCT FROM v_durum,
                        'TR-ANAH-N1', 'tohumlama Bekliyor ve hayvan durumu değişmedi (geri sarıldı)',
                        (SELECT sonuc FROM public.tohumlama WHERE id = v_t));
  PERFORM pg_temp.kb_ok(NOT EXISTS (SELECT 1 FROM pg_temp.kb_acik_ob(v_h))
                        AND (SELECT count(*) FROM public.protokol_instance WHERE hayvan_id = v_h) = 1,
                        'TR-ANAH-N1', 'görev/instance yok (yalnız eski instance)', 'var');
  RAISE NOTICE 'PASS TR-ANAH-N1: G7 fail-closed';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ANAH-GOC: eski anahtar çakışmasıyla takılı (eski instance, açık görev yok, uygun) hayvana artık görev doğar;
--              P1(c) listesi (pg_temp.kb_takili) bu hayvanı önce gösterir, sonra göstermez; cron yolu da açar
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_h2 text; v_g uuid; v_r jsonb;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_duve(v_b - 30);
  PERFORM pg_temp.kb_eski_instance(v_h);
  PERFORM pg_temp.kb_ok(pg_temp.kb_takili(v_h), 'TR-ANAH-GOC', 'P1(c) listesinde (takılı)', 'yok');
  v_g := public._acik_disi_gorev_kur(v_h);
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL AND (SELECT kaynak FROM public.gorev_log WHERE id = v_g) = format('ACIK-DISI-%s-%s-0', v_h, v_b - 30),
                        'TR-ANAH-GOC', 'görev açıldı, kaynak yeni biçim', COALESCE(v_g::text, '<NULL>'));
  PERFORM pg_temp.kb_ok(NOT pg_temp.kb_takili(v_h), 'TR-ANAH-GOC', 'görev sonrası P1(c) listesinden çıktı', 'hâlâ takılı');
  -- cron (ilk_tohumlama_zamanlayici, 1-arg çağıran) aynı hayvanı açar
  v_h2 := pg_temp.kb_duve(v_b - 30);
  PERFORM pg_temp.kb_eski_instance(v_h2);
  v_r := public.ilk_tohumlama_zamanlayici(false);
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM pg_temp.kb_acik_ob(v_h2)) = 1
                        AND (SELECT kaynak FROM pg_temp.kb_acik_ob(v_h2)) = format('ACIK-DISI-%s-%s-0', v_h2, v_b - 30),
                        'TR-ANAH-GOC', 'cron takılı hayvana görev açtı', v_r::text);
  RAISE NOTICE 'PASS TR-ANAH-GOC: takılı hayvan çözülür (runbook P1(c))';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-G9-1: açık + kural geçmiş OVSYNC vaka protokol_iptal(yeniden başlat) → yeni görev hedefi tren günü (iptal günü değil)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_r jsonb; v_g uuid; r record;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  v_h := pg_temp.kb_duve(v_b - 30);
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_tren_ac(v_b + 3);   -- tren bugün+3, tren−2 = bugün+1 > bugün: p_hemen olmadan doğmazdı
  v_r := public.protokol_iptal(v_c, true, 'kb G9');
  v_g := (v_r->>'yeni_gorev_id')::uuid;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_g IS NOT NULL, 'TR-G9-1', 'yeni görev açıldı', v_r::text);
  SELECT g.hedef_tarih, g.kaynak INTO r FROM public.gorev_log g WHERE g.id = v_g;
  PERFORM pg_temp.kb_ok(r.hedef_tarih = public._ovsync_tren_gunu(v_b - 30) AND r.hedef_tarih = v_b + 3, 'TR-G9-1',
                        'hedef = _ovsync_tren_gunu(kural) = bugün+3', r.hedef_tarih::text);
  PERFORM pg_temp.kb_ok(r.kaynak = 'PROTOKOL-IPTAL-' || v_c::text, 'TR-G9-1', 'kaynak PROTOKOL-IPTAL-<case>', r.kaynak);
  RAISE NOTICE 'PASS TR-G9-1: yeniden başlat tren gününe';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-G9-REG: bayrak 0 → hedef iptal günü (eski)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_r jsonb; v_g uuid;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_duve(v_b - 30);
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  v_r := public.protokol_iptal(v_c, true, 'kb G9 reg');
  v_g := (v_r->>'yeni_gorev_id')::uuid;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_g IS NOT NULL AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b,
                        'TR-G9-REG', 'hedef iptal günü (bugün)', v_r::text);
  PERFORM pg_temp.kb_ok(v_r->>'yeniden_not' IS NULL, 'TR-G9-REG', 'yeniden_not NULL', v_r->>'yeniden_not');
  RAISE NOTICE 'PASS TR-G9-REG: bayrak 0 yeniden başlat eski';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-UYARI-1: açık → görevsiz satır yalnız tren−2 ∈ [bugün, bugün+2]; hedef_tarih = tren, tai = tren+10; tren_gunu/kural_tarihi alanları
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_a text; v_y text; v_l text; v_u text; v_x text; v_gh text; v_g uuid; v_s jsonb;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  v_a := pg_temp.kb_duve(v_b + 5);    -- çapa+3: tren bugün+3, tren−2 = bugün+1 → listede (eski kural ∉ [b,b+2] → listede değildi)
  v_y := pg_temp.kb_duve(v_b + 6);    -- çapa+3: tren bugün+10 → listede değil
  v_l := pg_temp.kb_duve(v_b + 1);    -- çapa+1: tren bugün+1, tren−2 = bugün−1 → listede değil (eski: listedeydi)
  v_u := pg_temp.kb_duve(v_b + 7);    -- çapa+4: alt bugün+5 → tren bugün+11 → değil
  v_x := pg_temp.kb_duve(v_b + 6);    -- (v_y ile aynı kural; çapa+4'te tren bugün+4, tren−2 = bugün+2 → üst sınır listede)
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_s := pg_temp.kb_uyari(v_a);
  PERFORM pg_temp.kb_ok(v_s IS NOT NULL AND v_s->>'gorev_id' IS NULL AND (v_s->>'hedef_tarih')::date = v_b + 3
                        AND (v_s->>'tai_tarihi')::date = v_b + 13 AND (v_s->>'tren_gunu')::date = v_b + 3
                        AND (v_s->>'kural_tarihi')::date = v_b + 5, 'TR-UYARI-1',
                        'kural bugün+5 → görevsiz satır hedef/tren bugün+3, tai bugün+13, kural bugün+5', COALESCE(v_s::text, '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_uyari(v_y) IS NULL, 'TR-UYARI-1', 'tren−2 = bugün+8 → satır yok', pg_temp.kb_uyari(v_y)::text);
  PERFORM pg_temp.kb_tren_ac(v_b + 1);
  PERFORM pg_temp.kb_ok(pg_temp.kb_uyari(v_l) IS NULL, 'TR-UYARI-1', 'tren−2 = bugün−1 → satır yok (alt sınır)', pg_temp.kb_uyari(v_l)::text);
  PERFORM pg_temp.kb_tren_ac(v_b + 4);
  v_s := pg_temp.kb_uyari(v_x);
  PERFORM pg_temp.kb_ok(v_s IS NOT NULL AND (v_s->>'hedef_tarih')::date = v_b + 4, 'TR-UYARI-1', 'tren−2 = bugün+2 → satır (üst sınır)',
                        COALESCE(v_s::text, '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_uyari(v_u) IS NULL, 'TR-UYARI-1', 'tren bugün+11 → satır yok', pg_temp.kb_uyari(v_u)::text);
  -- görevli kol: tren alanı görev hedefi, kural_tarihi hayvanın kuralı
  PERFORM pg_temp.kb_tren_ac(v_b + 1);
  v_gh := pg_temp.kb_duve(v_b + 1);
  v_g := public._acik_disi_gorev_kur(v_gh);
  v_s := pg_temp.kb_uyari(v_gh);
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL AND (v_s->>'gorev_id')::uuid = v_g AND (v_s->>'hedef_tarih')::date = v_b + 1
                        AND (v_s->>'tren_gunu')::date = v_b + 1 AND (v_s->>'kural_tarihi')::date = v_b + 1,
                        'TR-UYARI-1', 'görevli satır tren_gunu = hedef bugün+1, kural_tarihi', COALESCE(v_s::text, '<yok>'));
  RAISE NOTICE 'PASS TR-UYARI-1: uyarı penceresi tren−2';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-UYARI-REG: bayrak 0 → görevsiz satır kural ∈ [bugün, bugün+2] (eski), hedef = kural; alan kümesi eski 10 + 2 yeni
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_a text; v_y text; v_z text; v_gh text; v_g uuid; v_s jsonb; v_k text[];
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);   -- bozuk çapa: kapalı dal ayarı okumamalı
  v_a := pg_temp.kb_duve(v_b + 1);
  v_y := pg_temp.kb_duve(v_b + 5);
  v_z := pg_temp.kb_duve(v_b + 2);
  v_s := pg_temp.kb_uyari(v_a);
  PERFORM pg_temp.kb_ok(v_s IS NOT NULL AND v_s->>'gorev_id' IS NULL AND (v_s->>'hedef_tarih')::date = v_b + 1
                        AND (v_s->>'tai_tarihi')::date = v_b + 11 AND v_s->>'tren_gunu' IS NULL AND (v_s->>'kural_tarihi')::date = v_b + 1
                        AND v_s->>'kaynak' = 'ACIK-DISI-ONERI:' || v_a AND v_s->>'taban_turu' = 'duve',
                        'TR-UYARI-REG', 'kural bugün+1 → görevsiz satır eski değerler, tren_gunu NULL', COALESCE(v_s::text, '<yok>'));
  SELECT array_agg(k ORDER BY k) INTO v_k FROM jsonb_object_keys(v_s) k;
  PERFORM pg_temp.kb_ok(cardinality(v_k) = 12
                        AND v_k @> ARRAY['gorev_id','hayvan_id','hedef_saat','hedef_tarih','kaynak','kategori','kisir','kupe_no',
                                         'kural_tarihi','tai_tarihi','taban_turu','tren_gunu'],
                        'TR-UYARI-REG', 'alanlar eski 10 + tren_gunu/kural_tarihi', v_k::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_uyari(v_z) IS NOT NULL, 'TR-UYARI-REG', 'kural bugün+2 → satır (üst sınır)', '<yok>');
  PERFORM pg_temp.kb_ok(pg_temp.kb_uyari(v_y) IS NULL, 'TR-UYARI-REG', 'kural bugün+5 → satır yok', pg_temp.kb_uyari(v_y)::text);
  v_gh := pg_temp.kb_duve(v_b - 5);
  v_g := public._acik_disi_gorev_kur(v_gh);
  v_s := pg_temp.kb_uyari(v_gh);
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL AND (v_s->>'gorev_id')::uuid = v_g AND (v_s->>'hedef_tarih')::date = v_b
                        AND v_s->>'tren_gunu' IS NULL AND (v_s->>'kural_tarihi')::date = v_b - 5,
                        'TR-UYARI-REG', 'görevli satır hedef bugün, tren_gunu NULL, kural_tarihi', COALESCE(v_s::text, '<yok>'));
  RAISE NOTICE 'PASS TR-UYARI-REG: bayrak 0 uyarı eski';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K5-KISIR: kısır hayvan _ovsync_baslat_gorev_kur(..., p_hemen => true) → NULL (tren açık)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_duve(v_b - 30, true);
  v_g := public._ovsync_baslat_gorev_kur(v_h, v_b - 400, 'KB-K5-' || v_h, v_b - 30, p_hemen => true);
  PERFORM pg_temp.kb_ok(v_g IS NULL, 'TR-K5-KISIR', 'kısır → NULL', v_g::text);
  PERFORM pg_temp.kb_ok(public._acik_disi_gorev_kur(v_h, p_hemen => true) IS NULL, 'TR-K5-KISIR', '_acik_disi_gorev_kur kısır → NULL', 'görev');
  PERFORM pg_temp.kb_ok(NOT EXISTS (SELECT 1 FROM pg_temp.kb_acik_ob(v_h))
                        AND NOT EXISTS (SELECT 1 FROM public.protokol_instance WHERE hayvan_id = v_h),
                        'TR-K5-KISIR', 'görev/instance yok', 'var');
  RAISE NOTICE 'PASS TR-K5-KISIR: kısır tren yolundan girmez';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ETKI-D3 (ek): 1-arg çağıran tohumlama_sonuc_bos çalışır (default p_hemen); bilinmeyen hayvan 1/4-arg çağrıları çözülür
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_t uuid; v_r jsonb;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_duve(v_b - 30);
  v_t := pg_temp.kb_toh_bekliyor(v_h, v_b - 5);
  v_r := public.tohumlama_sonuc_bos(v_t::text, 'kb');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT kaynak FROM pg_temp.kb_acik_ob(v_h)) = format('ACIK-DISI-%s-%s-%s', v_h, v_b - 30, v_t),
                        'TR-ETKI-D3', 'tohumlama_sonuc_bos → görev, kaynak son tohumlama', v_r::text);
  PERFORM pg_temp.kb_ok(public._acik_disi_gorev_kur('KB-YOK-1') IS NULL
                        AND public._ovsync_baslat_gorev_kur('KB-YOK-1', v_b, 'KB-YOK', v_b) IS NULL,
                        'TR-ETKI-D3', '1-arg/4-arg çağrı default ile çözülür', 'hata');
  RAISE NOTICE 'PASS TR-ETKI-D3: eski arg sayılı çağıranlar çalışır';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ACL-D3 (ek): yeni imzalar — iç yardımcılar anon/authenticated'a kapalı, RPC'ler authenticated'a açık; eski imzalar yok
SAVEPOINT kb_s;
DO $t$
DECLARE v_f text; v_n int := 0;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['public._ovsync_baslat_gorev_kur(text,date,text,date,boolean)', 'public._acik_disi_gorev_kur(text,boolean)',
                             'public._acik_disi_hedef_ic(text)'] LOOP
    PERFORM pg_temp.kb_ok(NOT has_function_privilege('anon', v_f, 'EXECUTE') AND NOT has_function_privilege('authenticated', v_f, 'EXECUTE')
                          AND has_function_privilege('service_role', v_f, 'EXECUTE'),
                          'TR-ACL-D3', v_f || ' anon/authenticated kapalı, service_role açık', 'yanlış');
    v_n := v_n + 1;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['public.ovsync_baslat_uyarilari()', 'public.protokol_iptal(uuid,boolean,text)',
                             'public.tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean)'] LOOP
    PERFORM pg_temp.kb_ok(NOT has_function_privilege('anon', v_f, 'EXECUTE') AND has_function_privilege('authenticated', v_f, 'EXECUTE'),
                          'TR-ACL-D3', v_f || ' anon kapalı, authenticated açık', 'yanlış');
    v_n := v_n + 1;
  END LOOP;
  PERFORM pg_temp.kb_ok(v_n = 6 AND to_regprocedure('public._ovsync_baslat_gorev_kur(text,date,text,date)') IS NULL
                        AND to_regprocedure('public._acik_disi_gorev_kur(text)') IS NULL
                        AND (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                               AND proname IN ('_ovsync_baslat_gorev_kur', '_acik_disi_gorev_kur')) = 2,
                        'TR-ACL-D3', 'eski imzalar düştü, overload yok', 'eski imza var');
  RAISE NOTICE 'PASS TR-ACL-D3: yeni imza ACL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM D4 — Başlatma yolları, K8 sunucu tarafı, TR tarihi (D4, migration 20261110100004)
-- ════════════════════════════════════════════════════════════════════════════

-- TR-K8-1: tren açık, görev hedefi = tren (bugün+3, pencere dışı) → start_first_service_protocol OVSYNC_ERKEN; vaka açılmaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_e text;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 3);
  v_e := pg_temp.kb_hata(format('SELECT public.start_first_service_protocol(%L::uuid)', v_g));
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_ERKEN:%', 'TR-K8-1', 'OVSYNC_ERKEN (hedef bugün+3)', v_e);
  PERFORM pg_temp.kb_ok(NOT EXISTS (SELECT 1 FROM public.cases WHERE animal_id = v_h)
                        AND (SELECT NOT COALESCE(tamamlandi, false) FROM public.gorev_log WHERE id = v_g),
                        'TR-K8-1', 'vaka açılmadı, görev açık', 'vaka/görev değişti');
  RAISE NOTICE 'PASS TR-K8-1: tren açık, pencere dışı görev OVSYNC_ERKEN';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K8-2: aynı görev p_bagimsiz => true → vaka D0 = bugün, ovsync_tren NULL (bugün tren günü değil); pencere içi görevde de bugüne çeker
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_r jsonb; r record;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 3);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_r->>'case_id' IS NOT NULL AND (v_r->>'baslangic')::date = v_b,
                        'TR-K8-2', 'bağımsız: ok, baslangic bugün', v_r::text);
  PERFORM pg_temp.kb_ok(v_r ? 'ovsync_tren' AND jsonb_typeof(v_r->'ovsync_tren') = 'null', 'TR-K8-2',
                        'dönüşte ovsync_tren alanı NULL', v_r::text);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok(r.start_date = v_b AND r.gun1 = v_b AND r.ovsync_tren IS NULL, 'TR-K8-2',
                        'vaka start_date = gün#1 = bugün, ovsync_tren NULL', format('%s %s %s', r.start_date, r.gun1, r.ovsync_tren));
  PERFORM pg_temp.kb_ok((SELECT tamamlandi FROM public.gorev_log WHERE id = v_g), 'TR-K8-2', 'görev tamamlandı', 'açık');
  -- pencere içi (hedef bugün+1) görev: bağımsız başlangıcı bugüne çeker (eski yol hedef+0 = bugün+1 olurdu)
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 1);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok(r.start_date = v_b AND r.gun1 = v_b AND r.ovsync_tren IS NULL, 'TR-K8-2',
                        'pencere içi görev bağımsız → D0 bugün', format('%s %s %s', r.start_date, r.gun1, r.ovsync_tren));
  RAISE NOTICE 'PASS TR-K8-2: bağımsız başlatma bugün, trensiz';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K8-3: görev hedefi bugün ve bugün tren günü → ovsync_tren = bugün (normal, bağımsız ve cron tek-arg yolu)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_r jsonb; r record; v_z jsonb; v_s jsonb;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b);
  v_r := public.start_first_service_protocol(v_g);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'ovsync_tren')::date = v_b AND r.ovsync_tren = v_b AND r.gun1 = v_b,
                        'TR-K8-3', 'ovsync_tren = bugün (dönüş + vaka)', format('%s %s', v_r, r.ovsync_tren));
  -- R4: tren günü = bugün iken bağımsız da trendedir (üyelik yalnız D0 tarihinden)
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  PERFORM pg_temp.kb_ok((v_r->>'ovsync_tren')::date = v_b
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = (v_r->>'case_id')::uuid) = v_b,
                        'TR-K8-3', 'bağımsız + bugün tren günü → yine trende', v_r::text);
  -- cron ilk_tohumlama_zamanlayici → start_first_service_protocol(r.id) tek arg (default'lar) çalışır
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b);
  v_z := public.ilk_tohumlama_zamanlayici();
  SELECT s INTO v_s FROM jsonb_array_elements(v_z->'baslatilanlar') s WHERE (s->>'gorev_id')::uuid = v_g;
  PERFORM pg_temp.kb_ok(v_s IS NOT NULL
                        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_z->'hatalar') e WHERE (e->>'gorev_id')::uuid = v_g)
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = (v_s->>'case_id')::uuid) = v_b,
                        'TR-K8-3', 'cron tek-arg çağrısı başlatır, ovsync_tren bugün', v_z::text);
  RAISE NOTICE 'PASS TR-K8-3: tren günü başlatma trene bindirir (cron dahil)';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K8-REG: bayrak 0 → p_bagimsiz yok sayılır (OVSYNC_ERKEN); başlatma eski, ovsync_tren NULL; bozuk çapa okunmaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_e text; v_r jsonb; r record; v_c uuid;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);   -- bozuk çapa: kapalı yollar ayarı okumamalı
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 3);
  v_e := pg_temp.kb_hata(format('SELECT public.start_first_service_protocol(%L::uuid, p_bagimsiz => true)', v_g));
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_ERKEN:%', 'TR-K8-REG', 'bayrak 0 + p_bagimsiz → OVSYNC_ERKEN (eski)', v_e);
  -- pencere içi görev: eski başlangıç GREATEST(hedef, bugün) = bugün+1, bağımsız bayrağı etkisiz
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 1);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'baslangic')::date = v_b + 1 AND r.start_date = v_b + 1 AND r.gun1 = v_b + 1
                        AND r.ovsync_tren IS NULL AND v_r ? 'ovsync_tren' AND jsonb_typeof(v_r->'ovsync_tren') = 'null',
                        'TR-K8-REG', 'bayrak 0: D0 = hedef bugün+1, ovsync_tren NULL', format('%s %s', v_r, r.ovsync_tren));
  -- OVSYNC şablonu bayrak 0'da ayar okumadan uygulanır, etiket yazılmaz
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL,
                        'TR-K8-REG', 'bayrak 0 tedavi_sablon_uygula → ovsync_tren NULL', 'dolu');
  -- Ovsync-PG bayrağı 0 → p_bagimsiz ile de OZELLIK_KAPALI (eski kapı)
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 0);
  v_g := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b);
  v_e := pg_temp.kb_hata(format('SELECT public.start_first_service_protocol(%L::uuid, false, true)', v_g));
  PERFORM pg_temp.kb_ok(v_e LIKE '%OZELLIK_KAPALI:%', 'TR-K8-REG', 'pg bayrağı 0 → OZELLIK_KAPALI', v_e);
  RAISE NOTICE 'PASS TR-K8-REG: bayrak 0 başlatma eski';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K8-V3: create_case + tedavi_sablon_uygula(p_baslangic_tarihi => tren) → gün#1 = tren, ovsync_tren = tren; tren olmayan → NULL;
--           Ovsync dışı şablon etiket yazmaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c uuid; v_r jsonb; r record;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 2);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0(v_c);
  PERFORM pg_temp.kb_ok(r.gun1 = v_b + 2 AND r.ovsync_tren = v_b + 2, 'TR-K8-V3', 'tren bugün+2: gün#1 = ovsync_tren = bugün+2',
                        format('%s %s', r.gun1, r.ovsync_tren));
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 9);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0(v_c);
  PERFORM pg_temp.kb_ok(r.gun1 = v_b + 9 AND r.ovsync_tren = v_b + 9, 'TR-K8-V3', 'sonraki tren bugün+9 → ovsync_tren bugün+9',
                        format('%s %s', r.gun1, r.ovsync_tren));
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 3);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0(v_c);
  PERFORM pg_temp.kb_ok(r.gun1 = v_b + 3 AND r.ovsync_tren IS NULL, 'TR-K8-V3', 'tren olmayan bugün+3 → NULL',
                        format('%s %s', r.gun1, r.ovsync_tren));
  -- p_baslangic_tarihi NULL → v_case.start_date (create_case = bugün; bugün tren günü değil) → NULL;
  -- start_date tren günü ise o
  v_c := (public.create_case(pg_temp.kb_hayvan(), 'c346e115-35ff-4430-92b8-874c505d857e'::uuid, 'kb')->>'case_id')::uuid;
  UPDATE public.cases SET start_date = v_b + 2 WHERE id = v_c;
  v_r := public.tedavi_sablon_uygula(v_c, 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'::uuid);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0(v_c);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND r.gun1 = v_b + 2 AND r.ovsync_tren = v_b + 2, 'TR-K8-V3',
                        'p_baslangic NULL → start_date (tren) etiketlenir', format('%s %s %s', v_r, r.gun1, r.ovsync_tren));
  -- Ovsync dışı şablon (Enterit) tren gününde de etiket yazmaz
  v_c := (public.create_case(pg_temp.kb_hayvan(), '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb')->>'case_id')::uuid;
  v_r := public.tedavi_sablon_uygula(v_c, '530ce1b7-5256-45f4-b6b9-655a64ff6ec9'::uuid, v_b + 2);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL, 'TR-K8-V3',
                        'Ovsync dışı şablon → NULL', v_r::text);
  RAISE NOTICE 'PASS TR-K8-V3: V3 yolunda üyelik D0 tarihinden';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K8-V4: vaka_toplu_ac(p_tarih => tren, Ovsync şablonlu) → tüm vakalarda ovsync_tren = tren; tren olmayan tarih → NULL
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h1 text := pg_temp.kb_hayvan(); v_h2 text := pg_temp.kb_hayvan(); v_h3 text := pg_temp.kb_hayvan();
        v_r jsonb; v_n int;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 4);
  v_r := public.vaka_toplu_ac(p_animal_ids := ARRAY[v_h1, v_h2], p_disease_id := 'c346e115-35ff-4430-92b8-874c505d857e'::uuid,
                              p_sablon_id := 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'::uuid, p_tarih := v_b + 4);
  SELECT count(*) INTO v_n FROM public.cases c
   WHERE c.animal_id IN (v_h1, v_h2) AND c.status = 'active' AND c.ovsync_tren = v_b + 4 AND c.start_date = v_b + 4;
  PERFORM pg_temp.kb_ok((v_r->>'basari')::int = 2 AND v_n = 2, 'TR-K8-V4', '2 vaka, ikisi de ovsync_tren = tren bugün+4',
                        format('basari %s etiketli %s %s', v_r->>'basari', v_n, v_r));
  v_r := public.vaka_toplu_ac(p_animal_ids := ARRAY[v_h3], p_disease_id := 'c346e115-35ff-4430-92b8-874c505d857e'::uuid,
                              p_sablon_id := 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'::uuid, p_tarih := v_b + 5);
  PERFORM pg_temp.kb_ok((v_r->>'basari')::int = 1
                        AND (SELECT ovsync_tren FROM public.cases WHERE animal_id = v_h3 AND status = 'active') IS NULL,
                        'TR-K8-V4', 'tren olmayan bugün+5 → NULL', v_r::text);
  RAISE NOTICE 'PASS TR-K8-V4: toplu vaka trene biner';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K8-KISIR: kısır hayvan hiçbir başlatma yolundan Ovsync'e (ve trene) girmez (§18.5)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_e text; v_r jsonb; v_g uuid;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan(1500, 'Aktif', true);
  v_c := (public.create_case(v_h, '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb')->>'case_id')::uuid;
  IF v_c IS NULL THEN RAISE EXCEPTION 'FIXTURE: kısır hayvana Mastit vakası açılamadı'; END IF;
  v_e := pg_temp.kb_hata(format('SELECT public.tedavi_sablon_uygula(%L::uuid, %L::uuid, %L::date)',
                                v_c, 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7', v_b));
  PERFORM pg_temp.kb_ok(v_e LIKE '%KISIR_HAYVAN_OVSYNC_YASAK%', 'TR-K8-KISIR', 'tedavi_sablon_uygula (OVSYNC) → KISIR_HAYVAN_OVSYNC_YASAK', v_e);
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL
                        AND NOT EXISTS (SELECT 1 FROM public.treatment_days WHERE case_id = v_c),
                        'TR-K8-KISIR', 'etiket/gün yazılmadı', 'yazıldı');
  v_r := public.vaka_toplu_ac(p_animal_ids := ARRAY[v_h], p_disease_id := 'c346e115-35ff-4430-92b8-874c505d857e'::uuid,
                              p_sablon_id := 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'::uuid, p_tarih := v_b);
  PERFORM pg_temp.kb_ok(COALESCE((v_r->>'basari')::int, 0) = 0
                        AND NOT EXISTS (SELECT 1 FROM public.cases WHERE animal_id = v_h AND protocol_family = 'OVSYNC'),
                        'TR-K8-KISIR', 'toplu vaka kısırı düşürür', v_r::text);
  v_g := pg_temp.kb_ob_gorev(v_h, v_b);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  PERFORM pg_temp.kb_ok(v_r->>'atlandi' = 'KISIR' AND NOT EXISTS (SELECT 1 FROM public.cases WHERE animal_id = v_h AND ovsync_tren IS NOT NULL),
                        'TR-K8-KISIR', 'start bağımsız → atlandi KISIR', v_r::text);
  RAISE NOTICE 'PASS TR-K8-KISIR: kısır trene girmez';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-TZ-2: _vaka_ac_tek(.., NULL) → start_date = TR bugünü; oturum saat dilimi TR'den farklı bir güne düşse de
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_tz text; v_r jsonb;
BEGIN
  -- TR saati < 14 → UTC-12 (TR−15 sa: takvim bir gün geride); aksi → UTC+14 (TR+11 sa: bir gün ileride). Her an CURRENT_DATE ≠ TR bugünü.
  v_tz := CASE WHEN extract(hour FROM now() AT TIME ZONE 'Europe/Istanbul') < 14 THEN 'Etc/GMT+12' ELSE 'Pacific/Kiritimati' END;
  PERFORM set_config('timezone', v_tz, true);
  PERFORM pg_temp.kb_ok(CURRENT_DATE <> v_b, 'TR-TZ-2', 'fixture: oturum CURRENT_DATE ≠ TR bugünü (' || v_tz || ')', CURRENT_DATE::text);
  v_r := public._vaka_ac_tek(pg_temp.kb_hayvan(), '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb', NULL);
  PERFORM pg_temp.kb_ok((SELECT start_date FROM public.cases WHERE id = (v_r->>'case_id')::uuid) = v_b, 'TR-TZ-2',
                        '_vaka_ac_tek NULL tarih → start_date = kb_bugun()', (SELECT start_date FROM public.cases WHERE id = (v_r->>'case_id')::uuid)::text);
  v_r := public.create_case(pg_temp.kb_hayvan(), '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb');
  PERFORM pg_temp.kb_ok((SELECT start_date FROM public.cases WHERE id = (v_r->>'case_id')::uuid) = v_b, 'TR-TZ-2',
                        'create_case → start_date = kb_bugun()', v_r::text);
  -- p_tarih dolu çağrı etkilenmez
  v_r := public._vaka_ac_tek(pg_temp.kb_hayvan(), '1bb109ce-27b9-4cad-8acf-87cc871e285a'::uuid, 'kb', v_b + 6);
  PERFORM pg_temp.kb_ok((SELECT start_date FROM public.cases WHERE id = (v_r->>'case_id')::uuid) = v_b + 6, 'TR-TZ-2',
                        'p_tarih dolu → o gün', v_r::text);
  RAISE NOTICE 'PASS TR-TZ-2: vaka açılış günü TR';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ONIZLE-1 + TR-EK-ONIZLE: açık → tren_gunu ritimde ve ≥ bugün, uye_sayisi fixture sayısı; kupe_no, kural_tarihi, uye_kupeler
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_o jsonb; v_m1 text; v_m2 text; v_m3 text; v_n1 text; v_n2 text; v_x text; v_y text; v_z text;
        v_gx uuid; v_gz uuid; v_c uuid;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_o := public.ovsync_tren_onizle();
  PERFORM pg_temp.kb_ok((v_o->>'ok')::boolean AND (v_o->>'aktif')::boolean AND (v_o->>'bugun')::date = v_b
                        AND (v_o->>'tren_gunu')::date = v_b + 2 AND NOT (v_o->>'tren_bugun_mu')::boolean
                        AND jsonb_typeof(v_o->'gorev') = 'null' AND (v_o->>'uye_sayisi')::int = 0
                        AND jsonb_typeof(v_o->'kupe_no') = 'null' AND jsonb_typeof(v_o->'kural_tarihi') = 'null'
                        AND v_o->'uye_kupeler' = '[]'::jsonb,
                        'TR-ONIZLE-1', 'boş tren (verisiz kabul DB): tren bugün+2, 0 üye, hayvansız alanlar NULL', v_o::text);
  -- üyeler: iki aktif OVSYNC vaka (D0 = tren) + bir açık OVSYNC_BASLAT (hedef tren); küpeler sayısal sıra sınamak için 5708/36/169
  v_m1 := pg_temp.kb_hayvan(); UPDATE public.hayvanlar SET kupe_no = '5708' WHERE id = v_m1;
  v_m2 := pg_temp.kb_hayvan(); UPDATE public.hayvanlar SET kupe_no = '36' WHERE id = v_m2;
  v_m3 := pg_temp.kb_hayvan(); UPDATE public.hayvanlar SET kupe_no = '169' WHERE id = v_m3;
  PERFORM pg_temp.kb_ovsync_vaka(v_m1, v_b + 2);
  PERFORM pg_temp.kb_ovsync_vaka(v_m2, v_b + 2);
  PERFORM pg_temp.kb_ob_gorev(v_m3, v_b + 2);
  -- üye olmayanlar: sonraki tren (bugün+9) vakası + görevi, kapatılmış tren vakası, iptal görev
  v_n1 := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_ovsync_vaka(v_n1, v_b + 9);
  v_n2 := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_ob_gorev(v_n2, v_b + 9);
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 2); UPDATE public.cases SET status = 'closed' WHERE id = v_c;
  v_gz := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b + 2);
  UPDATE public.gorev_log SET iptal = true, tamamlandi = true WHERE id = v_gz;
  -- X: kendi açık görevi tren gününde (hedef bugün+2), kural günü bugün+4 olan düve
  v_x := pg_temp.kb_duve(v_b + 4);
  v_gx := pg_temp.kb_ob_gorev(v_x, v_b + 2);
  v_o := public.ovsync_tren_onizle(v_x);
  PERFORM pg_temp.kb_ok((v_o->>'tren_gunu')::date = v_b + 2 AND (v_o->'gorev'->>'id')::uuid = v_gx
                        AND (v_o->'gorev'->>'hedef_tarih')::date = v_b + 2 AND (v_o->>'uye_sayisi')::int = 3
                        AND (v_o->>'gorev_hedef_eski')::boolean = false,
                        -- root ruling D4 notları (2): uye_sayisi = uye_kupeler kümesi, sorulan hayvan hariç (eski beklenen 4)
                        'TR-ONIZLE-1', 'X: tren = kendi görev hedefi, görev {id,hedef}, uye_sayisi 3 (2 vaka + 1 görev; X hariç), hedef eski değil', v_o::text);
  PERFORM pg_temp.kb_ok((v_o->>'uye_sayisi')::int = jsonb_array_length(v_o->'uye_kupeler'), 'TR-D4EK-3',
                        'X: uye_sayisi = len(uye_kupeler)', v_o::text);
  PERFORM pg_temp.kb_ok(v_o->>'kupe_no' = v_x AND (v_o->>'kural_tarihi')::date = v_b + 4
                        AND v_o->'uye_kupeler' = '["36", "169", "5708"]'::jsonb,
                        'TR-EK-ONIZLE', 'X: kupe_no, kural_tarihi bugün+4, uye_kupeler sıralı ve X hariç', v_o::text);
  -- Y: görevsiz hayvan (kural günü geçmiş) → tren = sonraki tren (öne çekmesiz), kural_tarihi = _ovsync_kural_tarihi, uye_kupeler X dahil
  v_y := pg_temp.kb_hayvan();
  v_o := public.ovsync_tren_onizle(v_y);
  PERFORM pg_temp.kb_ok((v_o->>'tren_gunu')::date = v_b + 2 AND jsonb_typeof(v_o->'gorev') = 'null' AND (v_o->>'uye_sayisi')::int = 4
                        AND ((v_o->>'tren_gunu')::date - v_b + 7 * 10 - 2) % 7 = 0 AND (v_o->>'tren_gunu')::date >= v_b,
                        'TR-ONIZLE-1', 'Y: tren ritimde ve ≥ bugün, görev yok, 4 üye', v_o::text);
  PERFORM pg_temp.kb_ok((v_o->>'uye_sayisi')::int = jsonb_array_length(v_o->'uye_kupeler')
                        AND (v_o->>'gorev_hedef_eski')::boolean = false, 'TR-D4EK-3',
                        'Y (görevsiz): uye_sayisi = len(uye_kupeler) = 4, gorev_hedef_eski false', v_o::text);
  PERFORM pg_temp.kb_ok(v_o->>'kupe_no' = v_y AND (v_o->>'kural_tarihi')::date = public._ovsync_kural_tarihi(v_y)
                        AND (v_o->>'kural_tarihi')::date < v_b
                        AND v_o->'uye_kupeler' = (SELECT jsonb_agg(k ORDER BY length(k), k) FROM unnest(ARRAY['36','169','5708',v_x]) k),
                        'TR-EK-ONIZLE', 'Y: kupe_no, kural_tarihi (geçmiş), uye_kupeler 4', v_o::text);
  -- Z: kendi görevi sonraki trende (bugün+9) → o trenin üyeleri
  v_z := pg_temp.kb_hayvan();
  v_gz := pg_temp.kb_ob_gorev(v_z, v_b + 9);
  v_o := public.ovsync_tren_onizle(v_z);
  PERFORM pg_temp.kb_ok((v_o->>'tren_gunu')::date = v_b + 9 AND (v_o->'gorev'->>'id')::uuid = v_gz AND (v_o->>'uye_sayisi')::int = 2
                        AND v_o->'uye_kupeler' = (SELECT jsonb_agg(k ORDER BY length(k), k) FROM unnest(ARRAY[v_n1, v_n2]) k),
                        -- root ruling D4 notları (2): Z hariç (eski beklenen 3)
                        'TR-ONIZLE-1', 'Z: tren bugün+9, 2 üye (n1 vaka, n2 görev; Z hariç), uye_kupeler Z hariç', v_o::text);
  PERFORM pg_temp.kb_ok((v_o->>'uye_sayisi')::int = jsonb_array_length(v_o->'uye_kupeler'), 'TR-D4EK-3',
                        'Z: uye_sayisi = len(uye_kupeler)', v_o::text);
  -- tren günü bugün → tren_bugun_mu
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_o := public.ovsync_tren_onizle();
  PERFORM pg_temp.kb_ok((v_o->>'tren_gunu')::date = v_b AND (v_o->>'tren_bugun_mu')::boolean, 'TR-ONIZLE-1',
                        'çapa bugün → tren_gunu bugün, tren_bugun_mu true', v_o::text);
  -- açık + ayar bozuk → OVSYNC_TREN_AYAR (sessiz düşüş yok)
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);
  PERFORM pg_temp.kb_ok(pg_temp.kb_hata('SELECT public.ovsync_tren_onizle()') LIKE '%OVSYNC_TREN_AYAR%', 'TR-ONIZLE-1',
                        'bozuk çapa → OVSYNC_TREN_AYAR', pg_temp.kb_hata('SELECT public.ovsync_tren_onizle()'));
  RAISE NOTICE 'PASS TR-ONIZLE-1: önizleme tren günü ve üyeler';
  RAISE NOTICE 'PASS TR-EK-ONIZLE: kupe_no / kural_tarihi / uye_kupeler';
  RAISE NOTICE 'PASS TR-D4EK-3: uye_sayisi = len(uye_kupeler)';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ONIZLE-2: kapalı → {ok:true, aktif:false} (yalnız iki alan; bozuk çapa okunmaz)
SAVEPOINT kb_s;
DO $t$
DECLARE v_o jsonb;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);
  v_o := public.ovsync_tren_onizle(pg_temp.kb_hayvan());
  PERFORM pg_temp.kb_ok(v_o = '{"ok": true, "aktif": false}'::jsonb, 'TR-ONIZLE-2', '{ok:true, aktif:false}', v_o::text);
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 0);
  PERFORM pg_temp.kb_ayar('ovsync_tren_aktif', 1);
  v_o := public.ovsync_tren_onizle();
  PERFORM pg_temp.kb_ok(v_o = '{"ok": true, "aktif": false}'::jsonb, 'TR-ONIZLE-2', 'pg bayrağı 0 → tren kapalı sayılır', v_o::text);
  RAISE NOTICE 'PASS TR-ONIZLE-2: kapalı önizleme';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ACL-2: ovsync_tren_onizle, start_first_service_protocol (yeni imza), tedavi_sablon_uygula anon kapalı / authenticated açık;
--           _vaka_ac_tek iç yardımcı; eski start imzası düştü, overload yok
SAVEPOINT kb_s;
DO $t$
DECLARE v_f text; v_n int := 0;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['public.ovsync_tren_onizle(text)', 'public.start_first_service_protocol(uuid,boolean,boolean)',
                             'public.tedavi_sablon_uygula(uuid,uuid,date,boolean,text)'] LOOP
    PERFORM pg_temp.kb_ok(to_regprocedure(v_f) IS NOT NULL AND NOT has_function_privilege('anon', v_f, 'EXECUTE')
                          AND has_function_privilege('authenticated', v_f, 'EXECUTE')
                          AND has_function_privilege('service_role', v_f, 'EXECUTE'),
                          'TR-ACL-2', v_f || ' anon kapalı, authenticated/service_role açık', 'yanlış');
    v_n := v_n + 1;
  END LOOP;
  v_f := 'public._vaka_ac_tek(text,uuid,text,date)';
  PERFORM pg_temp.kb_ok(NOT has_function_privilege('anon', v_f, 'EXECUTE') AND NOT has_function_privilege('authenticated', v_f, 'EXECUTE')
                        AND has_function_privilege('service_role', v_f, 'EXECUTE'),
                        'TR-ACL-2', v_f || ' iç yardımcı: anon/authenticated kapalı, service_role açık', 'yanlış');
  PERFORM pg_temp.kb_ok(v_n = 3 AND to_regprocedure('public.start_first_service_protocol(uuid,boolean)') IS NULL
                        AND (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                               AND proname IN ('start_first_service_protocol', 'ovsync_tren_onizle')) = 2
                        AND (SELECT prosecdef AND provolatile = 's' FROM pg_proc WHERE oid = 'public.ovsync_tren_onizle(text)'::regprocedure),
                        'TR-ACL-2', 'eski imza düştü, overload yok, önizleme STABLE SECDEF', 'yanlış');
  RAISE NOTICE 'PASS TR-ACL-2: D4 ACL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- ── D4-EK (root ruling D4 notları, RL-11): eski hedefli görev → ilk tren; NULL üyelik fail-closed ──────────────────
-- Kabul DB'sinde gorev_ertele_kural boştur; yeniden hedefleme gorev_ertele üzerinden yürüdüğü için kb_ertele_kural() çağrılır.

-- TR-D4EK-1: gecikmiş görev → önizleme gelecek tren + gorev_hedef_eski; başlat → başlamaz, görev o trene yeniden hedeflenir
--            (iç bayrakla gorev_ertele, bayrak geri yüklenir); cron aynı yol; bugün tren günüyse gecikmiş görev bugün trene biner
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_o jsonb; v_r jsonb; v_p jsonb; v_e text; v_z jsonb; r record;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b - 2);
  v_o := public.ovsync_tren_onizle(v_h);
  PERFORM pg_temp.kb_ok((v_o->>'tren_gunu')::date = v_b + 3 AND (v_o->>'gorev_hedef_eski')::boolean
                        AND (v_o->'gorev'->>'hedef_tarih')::date = v_b - 2 AND NOT (v_o->>'tren_bugun_mu')::boolean,
                        'TR-D4EK-1', 'önizleme: gecikmiş (bugün−2) görev → tren bugün+3, gorev_hedef_eski true', v_o::text);
  v_r := public.start_first_service_protocol(v_g);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'basladi')::boolean = false AND (v_r->>'yeniden_hedef')::date = v_b + 3
                        AND v_r ? 'ovsync_tren' AND jsonb_typeof(v_r->'ovsync_tren') = 'null' AND (v_r->>'gorev_id')::uuid = v_g,
                        'TR-D4EK-1', 'başlat: {ok, basladi:false, yeniden_hedef bugün+3, ovsync_tren null}', v_r::text);
  SELECT g.hedef_tarih, g.tamamlandi, g.iptal INTO r FROM public.gorev_log g WHERE g.id = v_g;
  PERFORM pg_temp.kb_ok(r.hedef_tarih = v_b + 3 AND NOT COALESCE(r.tamamlandi, false) AND NOT COALESCE(r.iptal, false)
                        AND NOT EXISTS (SELECT 1 FROM public.cases WHERE animal_id = v_h),
                        'TR-D4EK-1', 'görev açık, hedef bugün+3; vaka açılmadı', format('%s %s %s', r.hedef_tarih, r.tamamlandi, r.iptal));
  SELECT l.payload INTO v_p FROM public.islem_log l WHERE l.ref_id = v_g::text AND l.tip = 'GOREV_ERTELE';
  PERFORM pg_temp.kb_ok((v_p->>'eski_tarih')::date = v_b - 2 AND (v_p->>'yeni_tarih')::date = v_b + 3 AND NOT public._ovsync_ic_mi(),
                        'TR-D4EK-1', 'GOREV_ERTELE soyu (eski bugün−2 → bugün+3); iç bayrak geri yüklendi', COALESCE(v_p::text, '<log yok>'));
  -- yeniden_hedef = görevin gerçek yeni hedefi (gorev_ertele pencere yuvarlaması dahil; 22:00 → ertesi gün 09:00)
  v_h := pg_temp.kb_hayvan();
  v_e := pg_temp.kb_ob_gorev(v_h, v_b - 4)::text;
  UPDATE public.gorev_log SET hedef_saat = '22:00' WHERE id = v_e::uuid;
  v_z := public.start_first_service_protocol(v_e::uuid);
  PERFORM pg_temp.kb_ok((v_z->>'yeniden_hedef')::date = (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_e::uuid)
                        AND (v_z->>'basladi')::boolean = false,
                        'TR-D4EK-1', 'yeniden_hedef = gorev_log.hedef_tarih (ertele dönüşü)', v_z::text);
  -- D5 review tur 2 KÜÇÜK (D8): R9 treni bugün+3; 22:00 pencere yuvarlaması (>21:00 → ertesi gün 09:00) hedefi gerçekten ertesi güne kaydırır
  PERFORM pg_temp.kb_ok((v_z->>'yeniden_hedef')::date = v_b + 4
                        AND (SELECT hedef_saat FROM public.gorev_log WHERE id = v_e::uuid) = time '09:00',
                        'TR-D4EK-1', '22:00 → tren bugün+3 değil, yuvarlamayla bugün+4 09:00', v_z::text);
  v_h := (SELECT hayvan_id FROM public.gorev_log WHERE id = v_g);
  -- yeniden hedeflenmiş görev artık normal: önizleme eski değil; erken başlatma eski kapıya takılır
  v_o := public.ovsync_tren_onizle(v_h);
  v_e := pg_temp.kb_hata(format('SELECT public.start_first_service_protocol(%L::uuid)', v_g));
  PERFORM pg_temp.kb_ok((v_o->>'gorev_hedef_eski')::boolean = false AND (v_o->>'tren_gunu')::date = v_b + 3 AND v_e LIKE '%OVSYNC_ERKEN:%',
                        'TR-D4EK-1', 'yeniden hedef sonrası eski değil, tekrar başlat OVSYNC_ERKEN', format('%s %s', v_o, v_e));
  -- cron: gecikmiş görev aynı yoldan yeniden hedeflenir (vaka açılmaz, hata yok)
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b - 1);
  v_z := public.ilk_tohumlama_zamanlayici();
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 3
                        AND NOT EXISTS (SELECT 1 FROM public.cases WHERE animal_id = v_h)
                        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_z->'hatalar') e WHERE (e->>'gorev_id')::uuid = v_g),
                        'TR-D4EK-1', 'cron gecikmiş görevi bugün+3 trenine yeniden hedefler', v_z::text);
  -- bugün tren günü: gecikmiş görev bugün başlar, ovsync_tren bugün
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b - 3);
  v_o := public.ovsync_tren_onizle(v_h);
  PERFORM pg_temp.kb_ok((v_o->>'tren_gunu')::date = v_b AND (v_o->>'gorev_hedef_eski')::boolean AND (v_o->>'tren_bugun_mu')::boolean,
                        'TR-D4EK-1', 'bugün tren: önizleme tren bugün, eski true', v_o::text);
  v_r := public.start_first_service_protocol(v_g);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND NOT (v_r ? 'basladi') AND (v_r->>'baslangic')::date = v_b AND (v_r->>'ovsync_tren')::date = v_b
                        AND r.ovsync_tren = v_b AND r.start_date = v_b AND r.gun1 = v_b,
                        'TR-D4EK-1', 'bugün tren + gecikmiş görev → bugün başlar, ovsync_tren bugün', format('%s %s', v_r, r.ovsync_tren));
  -- bayrak 0: cron gecikmiş görevi eski yoldan bugün başlatır, yeniden hedeflemez
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b - 2);
  v_z := public.ilk_tohumlama_zamanlayici();
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b - 2
                        AND (SELECT tamamlandi FROM public.gorev_log WHERE id = v_g)
                        AND (SELECT start_date FROM public.cases WHERE animal_id = v_h AND status = 'active') = v_b
                        AND (SELECT ovsync_tren FROM public.cases WHERE animal_id = v_h AND status = 'active') IS NULL
                        AND NOT EXISTS (SELECT 1 FROM public.islem_log l WHERE l.ref_id = v_g::text AND l.tip = 'GOREV_ERTELE'),
                        'TR-D4EK-1', 'bayrak 0 cron: gecikmiş görev → vaka bugün, yeniden hedef yok', v_z::text);
  RAISE NOTICE 'PASS TR-D4EK-1: gecikmiş görev ilk trene bağlanır';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-D4EK-2: ritim dışı görev → aynı yol (pencere içi ve uzak gelecek; OVSYNC_ERKEN değil); bugün trense bugün başlar;
--            tren günündeki gelecek görev eski kapıda kalır; bayrak 0'da eski davranış
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_o jsonb; v_r jsonb; v_e text; r record;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 1);              -- pencere içi, tren günü değil
  v_o := public.ovsync_tren_onizle(v_h);
  PERFORM pg_temp.kb_ok((v_o->>'tren_gunu')::date = v_b + 3 AND (v_o->>'gorev_hedef_eski')::boolean, 'TR-D4EK-2',
                        'önizleme: ritim dışı (bugün+1) → tren bugün+3, eski true', v_o::text);
  v_r := public.start_first_service_protocol(v_g);
  PERFORM pg_temp.kb_ok((v_r->>'basladi')::boolean = false AND (v_r->>'yeniden_hedef')::date = v_b + 3
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 3
                        AND NOT EXISTS (SELECT 1 FROM public.cases WHERE animal_id = v_h),
                        'TR-D4EK-2', 'başlat: başlamaz, görev bugün+3', v_r::text);
  -- uzak gelecek, ritim dışı (12−3 = 9), kural = hedef = bugün+12 → R9: ilk tren ≥ kural−2 = bugün+10 (D4-EK tur 2, K2)
  v_h := pg_temp.kb_duve(v_b + 12);
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 12);
  v_o := public.ovsync_tren_onizle(v_h);
  v_r := public.start_first_service_protocol(v_g);
  PERFORM pg_temp.kb_ok((v_r->>'basladi')::boolean = false AND (v_r->>'yeniden_hedef')::date = v_b + 10
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 10
                        AND (v_o->>'tren_gunu')::date = v_b + 10 AND (v_o->>'gorev_hedef_eski')::boolean,
                        'TR-D4EK-2', 'uzak ritim dışı (kural bugün+12) → OVSYNC_ERKEN değil, tren bugün+10 (önizleme = başlat)', format('%s %s', v_o, v_r));
  PERFORM pg_temp.kb_ok((v_r->>'yeniden_hedef')::date >= public._ovsync_kural_tarihi(v_h) - 2
                        AND (v_r->>'yeniden_hedef')::date <> v_b + 3,
                        'TR-D4EK-2', 'öne çekme ≤ 2 gün (yeniden_hedef ≥ kural−2; bugün+3 değil)', v_r::text);
  -- kural hedeften ileride (kural bugün+12, ritim dışı hedef bugün+5) → R9 GREATEST(kural, hedef): tren bugün+10, bugün+3 değil
  v_h := pg_temp.kb_duve(v_b + 12);
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 5);
  v_r := public.start_first_service_protocol(v_g);
  PERFORM pg_temp.kb_ok((v_r->>'yeniden_hedef')::date = v_b + 10, 'TR-D4EK-2',
                        'kural > hedef → tren kuraldan (bugün+10)', v_r::text);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 10);             -- tren günü (10−3 = 7), pencere dışı
  v_o := public.ovsync_tren_onizle(v_h);
  v_e := pg_temp.kb_hata(format('SELECT public.start_first_service_protocol(%L::uuid)', v_g));
  PERFORM pg_temp.kb_ok((v_o->>'gorev_hedef_eski')::boolean = false AND (v_o->>'tren_gunu')::date = v_b + 10 AND v_e LIKE '%OVSYNC_ERKEN:%',
                        'TR-D4EK-2', 'tren günündeki gelecek görev: eski değil, OVSYNC_ERKEN', format('%s %s', v_o, v_e));
  -- bugün tren günü + ritim dışı (bugün+1) görev → bugün başlar
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 1);
  v_r := public.start_first_service_protocol(v_g);
  SELECT * INTO r FROM pg_temp.kb_vaka_d0((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'ovsync_tren')::date = v_b AND r.ovsync_tren = v_b AND r.start_date = v_b,
                        'TR-D4EK-2', 'bugün tren + ritim dışı görev → bugün başlar', format('%s %s', v_r, r.ovsync_tren));
  -- bayrak 0: gecikmiş görev eski yoldan bugün başlar, etiket yok
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b - 2);
  v_r := public.start_first_service_protocol(v_g);
  PERFORM pg_temp.kb_ok((v_r->>'baslangic')::date = v_b AND jsonb_typeof(v_r->'ovsync_tren') = 'null' AND NOT (v_r ? 'basladi')
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = (v_r->>'case_id')::uuid) IS NULL,
                        'TR-D4EK-2', 'bayrak 0: gecikmiş görev bugün başlar, ovsync_tren NULL (eski)', v_r::text);
  RAISE NOTICE 'PASS TR-D4EK-2: ritim dışı görev ilk trene bağlanır';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-D4EK-4: TREN yolunda NULL üyelik → OVSYNC_TREN_UYELIK_YOK {gorev_id, case_id, d0} ve geri sarma. Normal akışta ulaşılamaz
--            (D0 hep tren günü); fixture: senaryo içinde cases.ovsync_tren'i silen geçici tetikleyici (savepoint ile düşer).
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_e text; v_j jsonb; v_r jsonb;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  EXECUTE $x$CREATE FUNCTION public.kb_tmp_tren_sil() RETURNS trigger LANGUAGE plpgsql AS $f$
            BEGIN NEW.ovsync_tren := NULL; RETURN NEW; END $f$$x$;
  EXECUTE 'CREATE TRIGGER kb_tmp_tren_sil BEFORE INSERT OR UPDATE ON public.cases FOR EACH ROW EXECUTE FUNCTION public.kb_tmp_tren_sil()';
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b);
  v_e := pg_temp.kb_hata(format('SELECT public.start_first_service_protocol(%L::uuid)', v_g));
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_TREN_UYELIK_YOK:%', 'TR-D4EK-4', 'TREN yolu NULL üyelik → OVSYNC_TREN_UYELIK_YOK', v_e);
  v_j := substring(v_e FROM 'OVSYNC_TREN_UYELIK_YOK:(.*)$')::jsonb;
  PERFORM pg_temp.kb_ok((v_j->>'gorev_id')::uuid = v_g AND v_j->>'case_id' IS NOT NULL AND (v_j->>'d0')::date = v_b,
                        'TR-D4EK-4', 'payload {gorev_id, case_id, d0 bugün}', v_j::text);
  PERFORM pg_temp.kb_ok(NOT EXISTS (SELECT 1 FROM public.cases WHERE animal_id = v_h)
                        AND (SELECT NOT COALESCE(tamamlandi, false) FROM public.gorev_log WHERE id = v_g),
                        'TR-D4EK-4', 'geri sarıldı: vaka yok, görev açık', 'yazma kaldı');
  -- bağımsız yol NULL üyeliğe izinlidir (aynı tetikleyiciyle başarı)
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_r->>'case_id' IS NOT NULL AND jsonb_typeof(v_r->'ovsync_tren') = 'null',
                        'TR-D4EK-4', 'bağımsız: NULL üyelik hata değil', v_r::text);
  RAISE NOTICE 'PASS TR-D4EK-4: NULL üyelik fail-closed';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM D5 — K10 sunucu kilidi + K9 hastalık günü (D5, migration 20261110100005)
-- Kabul DB'sinde gorev_ertele_kural boştur (verisiz kurulum); gorev_ertele senaryoları kb_ertele_kural() ile prod satırlarını tohumlar.
-- ════════════════════════════════════════════════════════════════════════════

-- TR-K10-1: tren açık: Ovsync şablon TAI'sine gorev_ertele → OVSYNC_TREN_EKRANI {gorev_id, hayvan_id, tren_gunu}; görev yerinde
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_e text; v_j jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_tai := pg_temp.kb_ovsync_tai(v_c, v_b + 2);
  v_e := pg_temp.kb_hata(format('SELECT public.gorev_ertele(%L::uuid, %L::date)', v_tai, v_b + 13));
  v_j := pg_temp.kb_ekrani(v_e);
  PERFORM pg_temp.kb_ok(v_j @> jsonb_build_object('gorev_id', v_tai, 'hayvan_id', v_h, 'tren_gunu', v_b + 2), 'TR-K10-1',
                        'OVSYNC_TREN_EKRANI {gorev_id, hayvan_id, tren_gunu = vakanın treni}', v_e);
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 12
                        AND NOT EXISTS (SELECT 1 FROM public.islem_log WHERE ref_id = v_tai::text AND tip IN ('GOREV_ERTELE', 'TOHUMLAMA_ERTELE')),
                        'TR-K10-1', 'TAI yerinde, erteleme kaydı yok', (SELECT hedef_tarih::text FROM public.gorev_log WHERE id = v_tai));
  RAISE NOTICE 'PASS TR-K10-1: Ovsync TAI gorev_ertele kilitli';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-2: tren açık: OVSYNC_BASLAT'a gorev_ertele → OVSYNC_TREN_EKRANI (tren_gunu = görev hedefi)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 2);
  v_e := pg_temp.kb_hata(format('SELECT public.gorev_ertele(%L::uuid, %L::date)', v_g, v_b + 9));
  PERFORM pg_temp.kb_ok(pg_temp.kb_ekrani(v_e) @> jsonb_build_object('gorev_id', v_g, 'hayvan_id', v_h, 'tren_gunu', v_b + 2), 'TR-K10-2',
                        'OVSYNC_TREN_EKRANI (OVSYNC_BASLAT)', v_e);
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 2, 'TR-K10-2', 'görev hedefi yerinde',
                        (SELECT hedef_tarih::text FROM public.gorev_log WHERE id = v_g));
  RAISE NOTICE 'PASS TR-K10-2: OVSYNC_BASLAT gorev_ertele kilitli';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-3: tren açık: tohumlama_gorev_ertele (Ovsync TAI; şablon ve PG_TOHUMLAMA) → OVSYNC_TREN_EKRANI
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_pg uuid; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_tai := pg_temp.kb_ovsync_tai(v_c, v_b + 2);
  v_e := pg_temp.kb_hata(format('SELECT public.tohumlama_gorev_ertele(%L::uuid, %L::date)', v_tai, v_b + 13));
  PERFORM pg_temp.kb_ok(pg_temp.kb_ekrani(v_e) @> jsonb_build_object('gorev_id', v_tai, 'hayvan_id', v_h), 'TR-K10-3',
                        'OVSYNC_TREN_EKRANI (şablon TAI)', v_e);
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak)
  VALUES (v_h, 'TOHUMLAMA_PLANLI', 'kb pg tai', v_b + 5, '10:00', 'PG_TOHUMLAMA:kb') RETURNING id INTO v_pg;
  v_e := pg_temp.kb_hata(format('SELECT public.tohumlama_gorev_ertele(%L::uuid, %L::date)', v_pg, v_b + 6));
  PERFORM pg_temp.kb_ok(pg_temp.kb_ekrani(v_e) @> jsonb_build_object('gorev_id', v_pg), 'TR-K10-3', 'OVSYNC_TREN_EKRANI (PG_TOHUMLAMA TAI)', v_e);
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 12
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_pg) = v_b + 5,
                        'TR-K10-3', 'iki TAI de yerinde', 'kaydı');
  RAISE NOTICE 'PASS TR-K10-3: tohumlama_gorev_ertele Ovsync TAI kilitli';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-4: tren açık: vaka_kalan_gunleri_kaydir (aktif OVSYNC vaka) → OVSYNC_TREN_EKRANI {case_id, hayvan_id, tren_gunu}; hiçbir şey kaymaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_e text; v_once date[];
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_tai := pg_temp.kb_ovsync_tai(v_c, v_b + 2);
  v_once := pg_temp.kb_gunler(v_c);
  v_e := pg_temp.kb_hata(format('SELECT public.vaka_kalan_gunleri_kaydir(%L::uuid, 1)', v_c));
  PERFORM pg_temp.kb_ok(pg_temp.kb_ekrani(v_e) @> jsonb_build_object('case_id', v_c, 'hayvan_id', v_h, 'tren_gunu', v_b + 2), 'TR-K10-4',
                        'OVSYNC_TREN_EKRANI {case_id, hayvan_id, tren_gunu}', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler(v_c) = v_once AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 12
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 2,
                        'TR-K10-4', 'günler, TAI ve etiket yerinde', pg_temp.kb_gunler(v_c)::text);
  RAISE NOTICE 'PASS TR-K10-4: OVSYNC vaka kaydırma kilitli';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-5: tren açık: vaka_kalan_gunleri_kaydir_coklu([ovsync_gorev, mastit_gorev], 1) → mastit kayar, ovsync_atlanan 1 satır,
--           toplam/atlanan/hatalar'a girmez; islem_log payload'ında da var
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_m uuid; v_og uuid; v_og2 uuid; v_mg uuid; v_r jsonb; v_once date[]; v_x jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_m := pg_temp.kb_mastit(v_h, v_b + 1);
  v_og := pg_temp.kb_vaka_gorev(v_c, 'TEDAVI_GUN');
  v_mg := pg_temp.kb_vaka_gorev(v_m, 'TEDAVI_GUN');
  v_once := pg_temp.kb_gunler(v_c);
  v_r := public.vaka_kalan_gunleri_kaydir_coklu(ARRAY[v_og, v_mg], 1);
  v_x := jsonb_build_array(jsonb_build_object('gorev_id', v_og, 'case_id', v_c, 'hayvan_id', v_h,
                                              'kupe_no', (SELECT kupe_no FROM public.hayvanlar WHERE id = v_h)));
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'toplam')::int = 1 AND (v_r->>'kaydirilan')::int = 1
                        AND (v_r->>'atlanan')::int = 0 AND v_r->'hatalar' = '[]'::jsonb AND v_r->'ovsync_atlanan' = v_x
                        AND jsonb_array_length(v_r->'detaylar') = 1 AND v_r->'detaylar'->0->>'case_id' = v_m::text,
                        'TR-K10-5', format('toplam 1, kaydirilan 1, atlanan 0, hatalar [], ovsync_atlanan %s', v_x), v_r::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler(v_m) = ARRAY[v_b + 2] AND pg_temp.kb_gunler(v_c) = v_once
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 2,
                        'TR-K10-5', 'mastit günü +1, Ovsync günleri/etiket yerinde', format('%s %s', pg_temp.kb_gunler(v_m), pg_temp.kb_gunler(v_c)));
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM public.islem_log WHERE tip = 'VAKA_KAYDIR_TOPLU' AND payload->'ovsync_atlanan' = v_x
                                   AND (payload->>'toplam')::int = 1 AND payload->'hatalar' = '[]'::jsonb),
                        'TR-K10-5', 'VAKA_KAYDIR_TOPLU payload ovsync_atlanan', 'yok');
  -- yalnız Ovsync görevleri (aynı vakadan iki görev) → görev başına satır, toplam 0
  v_og2 := pg_temp.kb_vaka_gorev(v_c, 'TEDAVI_SEANS');
  v_r := public.vaka_kalan_gunleri_kaydir_coklu(ARRAY[v_og, v_og2], 1);
  PERFORM pg_temp.kb_ok((v_r->>'toplam')::int = 0 AND (v_r->>'kaydirilan')::int = 0 AND v_r->'hatalar' = '[]'::jsonb
                        AND jsonb_array_length(v_r->'ovsync_atlanan') = 2 AND pg_temp.kb_gunler(v_c) = v_once,
                        'TR-K10-5', 'yalnız Ovsync: 2 atlanan satır, toplam 0, günler yerinde', v_r::text);
  RAISE NOTICE 'PASS TR-K10-5: coklu kaydırma Ovsync görevlerini ayırır';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-6: tren açık: Ovsync'siz hayvanın TOHUMLAMA_PLANLI'sı gorev_ertele ve tohumlama_gorev_ertele ile ertelenir (kilit dışı)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_r jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak)
  VALUES (v_h, 'TOHUMLAMA_PLANLI', 'kb tai', v_b + 5, '10:00', 'KB-TAI') RETURNING id INTO v_g;
  v_r := public.gorev_ertele(v_g, v_b + 6);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 6,
                        'TR-K10-6', 'gorev_ertele → hedef bugün+6', v_r::text);
  v_r := public.tohumlama_gorev_ertele(v_g, v_b + 7);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 7,
                        'TR-K10-6', 'tohumlama_gorev_ertele → hedef bugün+7', v_r::text);
  RAISE NOTICE 'PASS TR-K10-6: Ovsync olmayan TAI kilit dışı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-7: tren açık: aktif OVSYNC vakalı hayvanın ILAC görevi (E Vitamini) gorev_ertele ile ertelenir
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_r jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  PERFORM pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'ILAC', 'E Vitamini', v_b + 1) RETURNING id INTO v_g;
  v_r := public.gorev_ertele(v_g, v_b + 3);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b + 3,
                        'TR-K10-7', 'ILAC görevi ertelendi (bugün+3)', v_r::text);
  RAISE NOTICE 'PASS TR-K10-7: Ovsync hayvanının ILAC görevi kilit dışı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-8: tren açık: aynı hayvanın Ovsync dışı aktif vakası (Mastit) vaka_kalan_gunleri_kaydir ile kayar; Ovsync vakası yerinde
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_m uuid; v_r jsonb; v_once date[];
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_m := pg_temp.kb_mastit(v_h, v_b + 1);
  v_once := pg_temp.kb_gunler(v_c);
  v_r := public.vaka_kalan_gunleri_kaydir(v_m, 2);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND pg_temp.kb_gunler(v_m) = ARRAY[v_b + 3] AND pg_temp.kb_gunler(v_c) = v_once
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_m) IS NULL,
                        'TR-K10-8', 'Mastit +2, Ovsync yerinde, Mastit etiketi NULL', format('%s %s', v_r, pg_temp.kb_gunler(v_m)));
  RAISE NOTICE 'PASS TR-K10-8: Ovsync dışı vaka kaydırma kilit dışı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-9: _ovsync_gorev_mu tablo testi (R5): OVSYNC_BASLAT, Ovsync hayvanının PG_TOHUMLAMA TAI'si, Ovsync TEDAVI_SEANS → true;
--           Mastit TEDAVI_GUN, ILAC → false; kilit yalnız true olanlarda (gorev_ertele yolu)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_m uuid; v_ob uuid; v_pg uuid; v_se uuid; v_mg uuid; v_il uuid;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_m := pg_temp.kb_mastit(v_h, v_b + 1);
  v_ob := pg_temp.kb_ob_gorev(v_h, v_b + 9);
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak)
  VALUES (v_h, 'TOHUMLAMA_PLANLI', 'kb pg tai', v_b + 5, '10:00', 'PG_TOHUMLAMA:kb') RETURNING id INTO v_pg;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih) VALUES (v_h, 'ILAC', 'E Vitamini', v_b + 1) RETURNING id INTO v_il;
  v_se := pg_temp.kb_vaka_gorev(v_c, 'TEDAVI_SEANS');
  v_mg := pg_temp.kb_vaka_gorev(v_m, 'TEDAVI_GUN');
  PERFORM pg_temp.kb_ok(public._ovsync_gorev_mu(v_ob) AND public._ovsync_gorev_mu(v_pg) AND public._ovsync_gorev_mu(v_se)
                        AND NOT public._ovsync_gorev_mu(v_mg) AND NOT public._ovsync_gorev_mu(v_il),
                        'TR-K10-9', 'OVSYNC_BASLAT/PG_TOHUMLAMA TAI/Ovsync TEDAVI_SEANS true; Mastit TEDAVI_GUN/ILAC false',
                        format('%s %s %s %s %s', public._ovsync_gorev_mu(v_ob), public._ovsync_gorev_mu(v_pg), public._ovsync_gorev_mu(v_se),
                               public._ovsync_gorev_mu(v_mg), public._ovsync_gorev_mu(v_il)));
  RAISE NOTICE 'PASS TR-K10-9: Ovsync görevi tablo testi';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-REG: bayrak 0 (bozuk çapa okunmaz) → 1–4 eski davranış: gorev_ertele (TAI, OVSYNC_BASLAT), tohumlama_gorev_ertele ertelenir;
--             vaka_kalan_gunleri_kaydir kayar (etiket NULL kalır); coklu Ovsync görevini kaydırır, ovsync_atlanan []
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_ob uuid; v_r jsonb; v_once date[]; v_og uuid;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);   -- bozuk çapa: kapalı yollar ayarı okumamalı
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_tai := pg_temp.kb_ovsync_tai(v_c, v_b + 2);
  v_ob := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b + 2);
  v_r := public.gorev_ertele(v_tai, v_b + 13);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 13,
                        'TR-K10-REG', '1: gorev_ertele Ovsync TAI ertelenir', v_r::text);
  v_r := public.gorev_ertele(v_ob, v_b + 3);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_ob) = v_b + 3,
                        'TR-K10-REG', '2: gorev_ertele OVSYNC_BASLAT ertelenir', v_r::text);
  v_r := public.tohumlama_gorev_ertele(v_tai, v_b + 14);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 14,
                        'TR-K10-REG', '3: tohumlama_gorev_ertele Ovsync TAI ertelenir', v_r::text);
  v_once := pg_temp.kb_gunler(v_c);
  v_r := public.vaka_kalan_gunleri_kaydir(v_c, 1);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'tai')::int = 1
                        AND pg_temp.kb_gunler(v_c) = ARRAY(SELECT d + 1 FROM unnest(v_once) d)
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 15
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL,
                        'TR-K10-REG', '4: vaka_kalan_gunleri_kaydir kayar (TAI +1), etiket NULL', format('%s %s', v_r, pg_temp.kb_gunler(v_c)));
  v_og := pg_temp.kb_vaka_gorev(v_c, 'TEDAVI_GUN');
  v_r := public.vaka_kalan_gunleri_kaydir_coklu(ARRAY[v_og], 1);
  PERFORM pg_temp.kb_ok((v_r->>'toplam')::int = 1 AND (v_r->>'kaydirilan')::int = 1 AND v_r->'hatalar' = '[]'::jsonb
                        AND v_r->'ovsync_atlanan' = '[]'::jsonb
                        AND pg_temp.kb_gunler(v_c) = ARRAY(SELECT d + 2 FROM unnest(v_once) d),
                        'TR-K10-REG', 'coklu: Ovsync vakası kayar, ovsync_atlanan []', v_r::text);
  RAISE NOTICE 'PASS TR-K10-REG: bayrak 0 erteleme/kaydırma eski';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K10-IC: tren açık + _ovsync_ic_ac() → vaka_kalan_gunleri_kaydir OVSYNC vakada çalışır, TAI'yi taşır; RL-1: trendeki vakada
--            ovsync_tren += k (ardışık), bağımsız vakada NULL kalır; iç bayrakla gorev_ertele de çalışır
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_c2 uuid; v_tai uuid; v_tai2 uuid; v_r jsonb; v_once date[];
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_tai := pg_temp.kb_ovsync_tai(v_c, v_b + 2);
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 3);   -- tren günü değil → bağımsız
  v_tai2 := pg_temp.kb_ovsync_tai(v_c2, v_b + 3);
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 2 AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c2) IS NULL,
                        'TR-K10-IC', 'fixture: trende etiket bugün+2, bağımsız NULL', 'yanlış');
  PERFORM public._ovsync_ic_ac();
  v_once := pg_temp.kb_gunler(v_c);
  v_r := public.vaka_kalan_gunleri_kaydir(v_c, 1);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'tai')::int = 1 AND pg_temp.kb_gunler(v_c) = ARRAY(SELECT d + 1 FROM unnest(v_once) d)
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 13
                        AND EXISTS (SELECT 1 FROM public.islem_log WHERE tip = 'TOHUMLAMA_ERTELE' AND ref_id = v_tai::text),
                        'TR-K10-IC', 'iç bayrak: günler +1, TAI +1 (TOHUMLAMA_ERTELE)', format('%s %s', v_r, pg_temp.kb_gunler(v_c)));
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 3, 'TR-K10-IC', 'RL-1: etiket +1 (bugün+3)',
                        (SELECT ovsync_tren::text FROM public.cases WHERE id = v_c));
  v_r := public.vaka_kalan_gunleri_kaydir(v_c, 2);
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 5 AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 15,
                        'TR-K10-IC', 'RL-1: ardışık +2 → etiket bugün+5, TAI bugün+15', (SELECT ovsync_tren::text FROM public.cases WHERE id = v_c));
  v_r := public.vaka_kalan_gunleri_kaydir(v_c2, 1);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c2) IS NULL
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai2) = v_b + 14,
                        'TR-K10-IC', 'bağımsız vaka kayar, etiket NULL kalır', v_r::text);
  v_r := public.gorev_ertele(v_tai, v_b + 16);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 16,
                        'TR-K10-IC', 'iç bayrak: gorev_ertele Ovsync TAI çalışır', v_r::text);
  -- iç çağrıda coklu Ovsync görevini ayırmaz (kaydırır), ovsync_atlanan []
  v_r := public.vaka_kalan_gunleri_kaydir_coklu(ARRAY[pg_temp.kb_vaka_gorev(v_c, 'TEDAVI_GUN')], 1);
  PERFORM pg_temp.kb_ok((v_r->>'kaydirilan')::int = 1 AND v_r->'ovsync_atlanan' = '[]'::jsonb
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 6,
                        'TR-K10-IC', 'iç bayrak: coklu Ovsync vakasını kaydırır, etiket bugün+6', v_r::text);
  RAISE NOTICE 'PASS TR-K10-IC: iç bayrak kilidi aşar, etiket kaymayla güncellenir';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K9-1: tren açık: ovsync_hastalik_gunu_ekle (iç bayrak kendi açar) → ovsync_tren NULL, tren_ayrildi true, açık TAI +7;
--          ikinci çağrı (mevcut) tren_ayrildi false; bağımsız vakada false; bayrak 0'da TAI +7, tren_ayrildi false
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_r jsonb; v_c2 uuid; v_tai2 uuid;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_tai := pg_temp.kb_ovsync_tai(v_c, v_b + 2);
  v_r := public.ovsync_hastalik_gunu_ekle(v_c);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND NOT (v_r->>'mevcut')::boolean AND (v_r->>'ertelenen')::int = 1
                        AND v_r->'tren_ayrildi' = 'true'::jsonb,
                        'TR-K9-1', 'ok, ertelenen 1, tren_ayrildi true', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 19
                        AND EXISTS (SELECT 1 FROM public.treatment_days WHERE case_id = v_c AND disease_id IS NOT NULL AND treatment_date = v_b),
                        'TR-K9-1', 'etiket NULL, TAI +7 (bugün+19), hastalık günü bugün', (SELECT hedef_tarih::text FROM public.gorev_log WHERE id = v_tai));
  PERFORM pg_temp.kb_ok(public._ovsync_ic_mi(), 'TR-K9-1', 'RPC iç bayrağı açtı (kilit aşıldı)', 'kapalı');
  v_r := public.ovsync_hastalik_gunu_ekle(v_c);
  PERFORM pg_temp.kb_ok((v_r->>'mevcut')::boolean AND v_r->'tren_ayrildi' = 'false'::jsonb
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai) = v_b + 19,
                        'TR-K9-1', 'ikinci çağrı mevcut, tren_ayrildi false, TAI tekrar ertelenmez', v_r::text);
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 3);
  v_r := public.ovsync_hastalik_gunu_ekle(v_c2);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_r->'tren_ayrildi' = 'false'::jsonb, 'TR-K9-1', 'bağımsız vaka → tren_ayrildi false', v_r::text);
  -- bayrak 0: iç bayrak kapalı olsa da kilit yok; TAI +7, etiket zaten NULL
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_kapat();
  v_c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 2);
  v_tai2 := pg_temp.kb_ovsync_tai(v_c2, v_b + 2);
  v_r := public.ovsync_hastalik_gunu_ekle(v_c2);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'ertelenen')::int = 1 AND v_r->'tren_ayrildi' = 'false'::jsonb
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai2) = v_b + 19,
                        'TR-K9-1', 'bayrak 0: TAI +7, tren_ayrildi false', v_r::text);
  RAISE NOTICE 'PASS TR-K9-1: hastalık günü trenden ayırır, TAI iç bayrakla ötelenir';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K9-N1: K9 sonrası hayvan trende değil (D7'de ovsync_tren_listele assert'i eklenecek; burada ovsync_tren IS NULL) —
--           sonraki iç kaydırma etiketi geri doğurmaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c uuid;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 2);
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 2, 'TR-K9-N1', 'fixture: trende', 'NULL');
  PERFORM public.ovsync_hastalik_gunu_ekle(v_c);
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL, 'TR-K9-N1', 'K9 sonrası ovsync_tren NULL', 'dolu');
  PERFORM public.vaka_kalan_gunleri_kaydir(v_c, 1);   -- iç bayrak hastalık RPC'sinden açık
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL, 'TR-K9-N1', 'kaydırma sonrası da NULL', 'dolu');
  RAISE NOTICE 'PASS TR-K9-N1: hastalık günlü hayvan trende değil';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ACL-D5: değişen 5 RPC imzası aynı (tek overload), anon kapalı, authenticated/service_role açık, SECURITY DEFINER
SAVEPOINT kb_s;
DO $t$
DECLARE v_f text; v_n int := 0;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['public.gorev_ertele(uuid,date,time without time zone)',
                             'public.tohumlama_gorev_ertele(uuid,date,time without time zone)',
                             'public.vaka_kalan_gunleri_kaydir(uuid,integer)',
                             'public.vaka_kalan_gunleri_kaydir_coklu(uuid[],integer)',
                             'public.ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text)'] LOOP
    PERFORM pg_temp.kb_ok(to_regprocedure(v_f) IS NOT NULL AND NOT has_function_privilege('anon', v_f, 'EXECUTE')
                          AND has_function_privilege('authenticated', v_f, 'EXECUTE') AND has_function_privilege('service_role', v_f, 'EXECUTE')
                          AND (SELECT prosecdef FROM pg_proc WHERE oid = to_regprocedure(v_f)),
                          'TR-ACL-D5', v_f || ' anon kapalı, authenticated/service_role açık, SECDEF', 'yanlış');
    v_n := v_n + 1;
  END LOOP;
  PERFORM pg_temp.kb_ok(v_n = 5 AND (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                                       AND proname IN ('gorev_ertele', 'tohumlama_gorev_ertele', 'vaka_kalan_gunleri_kaydir',
                                                       'vaka_kalan_gunleri_kaydir_coklu', 'ovsync_hastalik_gunu_ekle')) = 5,
                        'TR-ACL-D5', '5 imza, overload yok', v_n::text);
  RAISE NOTICE 'PASS TR-ACL-D5: D5 ACL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM D6 — Aşama RPC'leri (K4/K5/K6) + K11 geç tamamlama (D6, migration 20261110100006)
--   ovsync_hayvan_ertele, ovsync_pg48_tohumla, ovsync_bastan_baslat, seans_tamamla R13; RL-1 (etiket tek sayım), R6-EK, sözleşme eki.
-- ════════════════════════════════════════════════════════════════════════════

-- TR-K4-1: aşama 0 açık OVSYNC_BASLAT → hedef sonraki tren (+7), gorev_ertele soyu; p_gun 1..7 dışı red; hiçbir şeyi yok → VAKA_YOK
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_g uuid; v_r jsonb; v_hd date; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_b + 2);
  v_r := public.ovsync_hayvan_ertele(v_h, 1);
  SELECT hedef_tarih INTO v_hd FROM public.gorev_log WHERE id = v_g;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'asama')::int = 0 AND v_r->>'sonuc' = 'SONRAKI_TREN'
                        AND (v_r->>'yeni_tarih')::date = v_b + 9 AND v_hd = v_b + 9,
                        'TR-K4-1', 'görev hedefi bugün+2 → bugün+9 (sonraki tren), sonuc SONRAKI_TREN', v_r::text || ' ' || v_hd);
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM public.islem_log l WHERE l.tip = 'GOREV_ERTELE' AND l.ref_id = v_g::text
                                   AND (l.payload->>'yeni_tarih')::date = v_b + 9),
                        'TR-K4-1', 'gorev_ertele soyu (GOREV_ERTELE kaydı)', 'yok');
  v_r := public.ovsync_hayvan_ertele(v_h, 7);
  SELECT hedef_tarih INTO v_hd FROM public.gorev_log WHERE id = v_g;
  PERFORM pg_temp.kb_ok(v_hd = v_b + 16 AND (v_r->>'yeni_tarih')::date = v_b + 16, 'TR-K4-1', 'p_gun 7 → yine bir sonraki tren (+7)', v_hd::text);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 8)', v_h));
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_TREN_N_GECERSIZ')->>'gun' = '8', 'TR-K4-1', 'p_gun 8 → OVSYNC_TREN_N_GECERSIZ', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 0)', v_h));
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_TREN_N_GECERSIZ') IS NOT NULL, 'TR-K4-1', 'p_gun 0 → OVSYNC_TREN_N_GECERSIZ', v_e);
  SELECT hedef_tarih INTO v_hd FROM public.gorev_log WHERE id = v_g;
  PERFORM pg_temp.kb_ok(v_hd = v_b + 16, 'TR-K4-1', 'geçersiz gün hedefi değiştirmedi', v_hd::text);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 1)', pg_temp.kb_hayvan()));
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_VAKA_YOK') IS NOT NULL, 'TR-K4-1', 'görevi/vakası olmayan hayvan → OVSYNC_VAKA_YOK', v_e);
  RAISE NOTICE 'PASS TR-K4-1: aşama 0 görev → sonraki tren';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K4-2: aşama 0 trende vaka → tüm günler +7 (D0 sonraki trene), etiket +7 (RL-1: tek sayım, +14 değil), TAI +7;
--          bağımsız aşama 0 vaka → p_gun kadar kayar (KAYDI), etiket NULL kalır
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_g0 date[]; v_g1 date[]; v_r jsonb;
        v_t0 date; v_t1 date; v_e date;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 1);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 1);
  v_tai := pg_temp.kb_ovsync_tai(v_c, v_b + 1);
  v_g0 := pg_temp.kb_gunler(v_c);
  SELECT hedef_tarih INTO v_t0 FROM public.gorev_log WHERE id = v_tai;
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 0 AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 1,
                        'TR-K4-2', 'fixture: aşama 0, etiket bugün+1', public._ovsync_asama(v_c)::text);
  v_r := public.ovsync_hayvan_ertele(v_h, 1);
  v_g1 := pg_temp.kb_gunler(v_c);
  SELECT hedef_tarih INTO v_t1 FROM public.gorev_log WHERE id = v_tai;
  SELECT ovsync_tren INTO v_e FROM public.cases WHERE id = v_c;
  PERFORM pg_temp.kb_ok((v_r->>'asama')::int = 0 AND v_r->>'sonuc' = 'SONRAKI_TREN' AND (v_r->>'yeni_tarih')::date = v_b + 8,
                        'TR-K4-2', 'asama 0, SONRAKI_TREN, yeni_tarih bugün+8', v_r::text);
  PERFORM pg_temp.kb_ok(v_g1 = ARRAY[v_g0[1] + 7, v_g0[2] + 7, v_g0[3] + 7, v_g0[4] + 7], 'TR-K4-2', 'gün#1..4 +7',
                        v_g0::text || ' → ' || v_g1::text);
  PERFORM pg_temp.kb_ok(v_e = v_b + 8, 'TR-K4-2', 'etiket bugün+1 → bugün+8 (tek sayım, RL-1)', v_e::text);
  PERFORM pg_temp.kb_ok(v_t1 = v_t0 + 7, 'TR-K4-2', 'şablon TAI +7 (iç bayrakla kilit aşıldı)', v_t0 || ' → ' || v_t1);
  -- bağımsız aşama 0 (D0 tren günü değil → etiket NULL)
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  v_g0 := pg_temp.kb_gunler(v_c);
  v_r := public.ovsync_hayvan_ertele(v_h, 3);
  v_g1 := pg_temp.kb_gunler(v_c);
  PERFORM pg_temp.kb_ok(v_r->>'sonuc' = 'KAYDI' AND (v_r->>'asama')::int = 0 AND (v_r->>'yeni_tarih')::date = v_b + 5
                        AND v_g1[1] = v_g0[1] + 3 AND v_g1[4] = v_g0[4] + 3
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL,
                        'TR-K4-2', 'bağımsız aşama 0: +3 serbest, KAYDI, etiket NULL', v_r::text || ' ' || v_g1::text);
  RAISE NOTICE 'PASS TR-K4-2: aşama 0 trende vaka → sonraki tren, etiket +7';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K5-1: aşama 1 p_gun=1 → kalan günler +1 (gün#1 sabit), etiket +1 (R3/RL-1, tek sayım), kayma 1
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_g0 date[]; v_g1 date[]; v_r jsonb; v_e date;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_g0 := pg_temp.kb_gunler(v_c);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 1 AND public._ovsync_pg1_kayma(v_c) = 0, 'TR-K5-1', 'fixture: aşama 1, kayma 0',
                        public._ovsync_asama(v_c)::text);
  v_r := public.ovsync_hayvan_ertele(v_h, 1);
  v_g1 := pg_temp.kb_gunler(v_c);
  SELECT ovsync_tren INTO v_e FROM public.cases WHERE id = v_c;
  PERFORM pg_temp.kb_ok((v_r->>'asama')::int = 1 AND v_r->>'sonuc' = 'KAYDI' AND (v_r->>'yeni_tarih')::date = v_g0[2] + 1,
                        'TR-K5-1', 'asama 1, KAYDI, yeni_tarih = PG1 + 1', v_r::text);
  PERFORM pg_temp.kb_ok(v_g1 = ARRAY[v_g0[1], v_g0[2] + 1, v_g0[3] + 1, v_g0[4] + 1], 'TR-K5-1', 'gün#1 sabit, gün#2..4 +1',
                        v_g0::text || ' → ' || v_g1::text);
  PERFORM pg_temp.kb_ok(v_e = v_b + 1, 'TR-K5-1', 'etiket bugün → bugün+1 (tek sayım)', v_e::text);
  PERFORM pg_temp.kb_ok(public._ovsync_pg1_kayma(v_c) = 1, 'TR-K5-1', 'kayma 1', public._ovsync_pg1_kayma(v_c)::text);
  RAISE NOTICE 'PASS TR-K5-1: aşama 1 +1 gün';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K5-N1: aşama 1 p_gun=2 (tolerans 1) → OVSYNC_ASAMA1_TOLERANS{tolerans, mevcut_kayma, istenen, oneri, case_id}; hiçbir şey kaymadı
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_g0 date[]; v_e text; v_j jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_g0 := pg_temp.kb_gunler(v_c);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 2)', v_h));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_ASAMA1_TOLERANS');
  PERFORM pg_temp.kb_ok((v_j->>'tolerans')::int = 1 AND (v_j->>'mevcut_kayma')::int = 0 AND (v_j->>'istenen')::int = 2
                        AND v_j->>'oneri' = 'BASTAN_BASLAT' AND (v_j->>'case_id')::uuid = v_c,
                        'TR-K5-N1', 'OVSYNC_ASAMA1_TOLERANS {tolerans 1, mevcut 0, istenen 2, BASTAN_BASLAT, case_id}', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler(v_c) = v_g0 AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b,
                        'TR-K5-N1', 'günler ve etiket değişmedi', pg_temp.kb_gunler(v_c)::text);
  RAISE NOTICE 'PASS TR-K5-N1: aşama 1 tolerans aşımı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K5-N2: ardışık iki p_gun=1 → ilki başarılı, ikincisi OVSYNC_ASAMA1_TOLERANS (mevcut_kayma=1, birikimli R18); PG1 ilk çağrının halinde
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_g0 date[]; v_g1 date[]; v_e text; v_j jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_g0 := pg_temp.kb_gunler(v_c);
  PERFORM public.ovsync_hayvan_ertele(v_h, 1);
  v_g1 := pg_temp.kb_gunler(v_c);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 1)', v_h));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_ASAMA1_TOLERANS');
  PERFORM pg_temp.kb_ok((v_j->>'mevcut_kayma')::int = 1 AND (v_j->>'istenen')::int = 1, 'TR-K5-N2', 'ikinci +1 → TOLERANS, mevcut_kayma 1', v_e);
  PERFORM pg_temp.kb_ok(v_g1[2] = v_g0[2] + 1 AND pg_temp.kb_gunler(v_c) = v_g1
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 1,
                        'TR-K5-N2', 'PG1 ilk çağrıdan sonraki halinde, etiket +1', pg_temp.kb_gunler(v_c)::text);
  RAISE NOTICE 'PASS TR-K5-N2: birikimli tolerans';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K5-2: GnRH1 1 gün geç yapılmış (kayma −1) → p_gun=2 başarılı (toplam +1), sonra p_gun=1 red
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_g0 date[]; v_r jsonb; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b - 1);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b - 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_g0 := pg_temp.kb_gunler(v_c);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 1 AND public._ovsync_pg1_kayma(v_c) = -1, 'TR-K5-2', 'fixture: aşama 1, kayma −1',
                        public._ovsync_pg1_kayma(v_c)::text);
  v_r := public.ovsync_hayvan_ertele(v_h, 2);
  PERFORM pg_temp.kb_ok(v_r->>'sonuc' = 'KAYDI' AND (v_r->>'yeni_tarih')::date = v_g0[2] + 2 AND public._ovsync_pg1_kayma(v_c) = 1
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 1,
                        'TR-K5-2', '+2 başarılı (−1+2 = 1 ≤ 1), kayma 1, etiket +2', v_r::text);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 1)', v_h));
  PERFORM pg_temp.kb_ok((pg_temp.kb_kod(v_e, 'OVSYNC_ASAMA1_TOLERANS')->>'mevcut_kayma')::int = 1, 'TR-K5-2', 'sonra +1 red (1+1 > 1)', v_e);
  RAISE NOTICE 'PASS TR-K5-2: GnRH1 geç → negatif kayma payı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K6-N1: aşama 2 → OVSYNC_ASAMA2_ERTELEME_YOK{case_id, secenekler:[PG48,BASTAN]}; günler değişmedi
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_g0 date[]; v_e text; v_j jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  v_g0 := pg_temp.kb_gunler(v_c);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 1)', v_h));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_ASAMA2_ERTELEME_YOK');
  PERFORM pg_temp.kb_ok((v_j->>'case_id')::uuid = v_c AND v_j->'secenekler' = '["PG48", "BASTAN"]'::jsonb,
                        'TR-K6-N1', 'OVSYNC_ASAMA2_ERTELEME_YOK {case_id, secenekler [PG48, BASTAN]}', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler(v_c) = v_g0, 'TR-K6-N1', 'günler değişmedi', pg_temp.kb_gunler(v_c)::text);
  RAISE NOTICE 'PASS TR-K6-N1: aşama 2 erteleme yok';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ASAMA-N (D6): belirsiz aşama (gün#1 kısmi seans, R6) → OVSYNC_ASAMA_BELIRSIZ{case_id, oneri}; günler değişmedi
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_g0 date[]; v_e text; v_j jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM public.seans_tamamla(p_seans_admin_id := pg_temp.kb_seans_ekle(v_c, 1));
  v_g0 := pg_temp.kb_gunler(v_c);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) IS NULL, 'TR-ASAMA-N', 'fixture: aşama NULL', public._ovsync_asama(v_c)::text);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 1)', v_h));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_ASAMA_BELIRSIZ');
  PERFORM pg_temp.kb_ok((v_j->>'case_id')::uuid = v_c AND v_j->>'oneri' = 'BASTAN_BASLAT', 'TR-ASAMA-N',
                        'OVSYNC_ASAMA_BELIRSIZ {case_id, oneri BASTAN_BASLAT}', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler(v_c) = v_g0, 'TR-ASAMA-N', 'günler değişmedi', pg_temp.kb_gunler(v_c)::text);
  RAISE NOTICE 'PASS TR-ASAMA-N: belirsiz aşama erteleme reddi';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K6-A1: aşama 2 (PG1 bugün tamamlandı, VWP dışı) → ovsync_pg48_tohumla: kalan 2 gün tamamlandı, seansları uygulanmadı,
--           açık PG_TOHUMLAMA TAI duruyor; aşama ≠ 2 → OVSYNC_ASAMA2_DEGIL
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_r jsonb; v_n int; v_e text; v_c1 uuid;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  v_tai := pg_temp.kb_pg_tai(v_h);
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar u
   WHERE u.case_id = v_c AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 2 AND v_tai IS NOT NULL AND v_n >= 2, 'TR-K6-A1',
                        'fixture: aşama 2, PG TAI açık, ≥2 açık seans', format('%s %s %s', public._ovsync_asama(v_c), v_tai, v_n));
  v_r := public.ovsync_pg48_tohumla(v_c);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'tai_gorev_id')::uuid = v_tai AND (v_r->>'kapanan_seans')::int = v_n
                        AND (v_r->>'tai_hedef')::date = (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_tai),
                        'TR-K6-A1', '{ok, tai_gorev_id = PG TAI, tai_hedef, kapanan_seans = açık seans sayısı}', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT bool_and(d.tamamlandi) FROM public.treatment_days d WHERE d.case_id = v_c AND d.disease_id IS NULL),
                        'TR-K6-A1', 'dört günün hepsi tamamlandı', 'açık gün var');
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM public.treatment_day_uygulamalar u WHERE u.case_id = v_c AND u.uygulanmadi) = v_n
                        AND NOT EXISTS (SELECT 1 FROM public.treatment_day_uygulamalar u WHERE u.case_id = v_c
                                         AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)),
                        'TR-K6-A1', 'kalan seanslar uygulanmadı, açık seans yok', 'farklı');
  PERFORM pg_temp.kb_ok(pg_temp.kb_pg_tai(v_h) = v_tai, 'TR-K6-A1', 'PG_TOHUMLAMA TAI açık duruyor', pg_temp.kb_pg_tai(v_h)::text);
  PERFORM pg_temp.kb_ok((SELECT status FROM public.cases WHERE id = v_c) = 'active' AND public._ovsync_asama(v_c) = 2,
                        'TR-K6-A1', 'vaka açık, aşama 2', public._ovsync_asama(v_c)::text);
  -- aşama 1 vakada pg48 → OVSYNC_ASAMA2_DEGIL; Ovsync olmayan vaka → OVSYNC_VAKA_YOK
  v_c1 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b);
  PERFORM pg_temp.kb_seans_yap(v_c1, 1);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_pg48_tohumla(%L::uuid)', v_c1));
  PERFORM pg_temp.kb_ok((pg_temp.kb_kod(v_e, 'OVSYNC_ASAMA2_DEGIL')->>'asama')::int = 1, 'TR-K6-A1', 'aşama 1 → OVSYNC_ASAMA2_DEGIL', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_pg48_tohumla(%L::uuid)', pg_temp.kb_mastit(pg_temp.kb_hayvan(), v_b + 1)));
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_VAKA_YOK') IS NOT NULL, 'TR-K6-A1', 'Ovsync olmayan vaka → OVSYNC_VAKA_YOK', v_e);
  RAISE NOTICE 'PASS TR-K6-A1: PG1 + 48 s tohumla';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K6-A-N1: VWP içi (doğum bugün−20) → PG TAI açılmadı → OVSYNC_PG48_TAI_YOK; hiçbir seans kapanmadı
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_n int; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  INSERT INTO public.dogum (anne_id, tarih, yavru_cins) VALUES (v_h, v_b - 20, 'Dişi');
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar u
   WHERE u.case_id = v_c AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 2 AND pg_temp.kb_pg_tai(v_h) IS NULL AND v_n >= 2, 'TR-K6-A-N1',
                        'fixture: aşama 2, VWP içi → PG TAI yok', format('%s %s', public._ovsync_asama(v_c), pg_temp.kb_pg_tai(v_h)));
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_pg48_tohumla(%L::uuid)', v_c));
  PERFORM pg_temp.kb_ok((pg_temp.kb_kod(v_e, 'OVSYNC_PG48_TAI_YOK')->>'case_id')::uuid = v_c, 'TR-K6-A-N1', 'OVSYNC_PG48_TAI_YOK', v_e);
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM public.treatment_day_uygulamalar u WHERE u.case_id = v_c
                          AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)) = v_n,
                        'TR-K6-A-N1', 'açık seanslar yerinde', 'kapandı');
  RAISE NOTICE 'PASS TR-K6-A-N1: PG TAI yok → red';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K6-A-N2: TAI anı geçmiş (PG olayı 3 gün önce: olay ve TAI 3 gün geri) → OVSYNC_PG48_GECMIS; seanslar açık
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_tai uuid; v_n int; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  v_tai := pg_temp.kb_pg_tai(v_h);
  UPDATE public.pg_application_event SET occurred_at = occurred_at - interval '3 days' WHERE tohumlama_gorev_id = v_tai;
  UPDATE public.gorev_log SET hedef_tarih = hedef_tarih - 3 WHERE id = v_tai;
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar u
   WHERE u.case_id = v_c AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_pg48_tohumla(%L::uuid)', v_c));
  PERFORM pg_temp.kb_ok((pg_temp.kb_kod(v_e, 'OVSYNC_PG48_GECMIS')->>'tai_gorev_id')::uuid = v_tai, 'TR-K6-A-N2', 'OVSYNC_PG48_GECMIS', v_e);
  PERFORM pg_temp.kb_ok(v_n >= 2 AND (SELECT count(*) FROM public.treatment_day_uygulamalar u WHERE u.case_id = v_c
                          AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)) = v_n,
                        'TR-K6-A-N2', 'açık seanslar yerinde', v_n::text);
  RAISE NOTICE 'PASS TR-K6-A-N2: TAI anı geçmiş → red';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K6-B1: ovsync_bastan_baslat → eski vaka IPTAL, yeni görev hedefi tren günü; basladi = (tren = bugün)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_r jsonb; v_g record; v_y record; v_e text; v_tai uuid;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  -- tren bugün+3 (≠ bugün): başlamaz, görev trende bekler
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b - 4);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 1, 'TR-K6-B1', 'fixture: aşama 1 (geriye tarihli GnRH1)', public._ovsync_asama(v_c)::text);
  v_r := public.ovsync_bastan_baslat(v_c);
  SELECT g.hedef_tarih, g.tamamlandi, g.iptal INTO v_g FROM public.gorev_log g WHERE g.id = (v_r->>'yeni_gorev_id')::uuid;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'kapanan_case_id')::uuid = v_c AND (v_r->>'basladi')::boolean = false
                        AND v_r ? 'yeni_case_id' AND v_r->'yeni_case_id' = 'null'::jsonb
                        AND (v_r->>'hedef_tarih')::date = v_b + 3 AND v_g.hedef_tarih = v_b + 3 AND NOT v_g.tamamlandi AND NOT v_g.iptal,
                        'TR-K6-B1', 'tren bugün+3: görev hedefi bugün+3, basladi false, yeni_case_id null', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT status = 'closed' AND close_reason = 'IPTAL' FROM public.cases WHERE id = v_c), 'TR-K6-B1',
                        'eski vaka IPTAL', (SELECT status || ' ' || close_reason FROM public.cases WHERE id = v_c));
  -- tren bugün: aynı işlemde başlar, yeni vaka trende (etiket bugün)
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_r := public.ovsync_bastan_baslat(v_c, p_not => 'kb bastan');
  SELECT * INTO v_y FROM pg_temp.kb_vaka_d0((v_r->>'yeni_case_id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'basladi')::boolean AND (v_r->>'hedef_tarih')::date = v_b AND v_y.gun1 = v_b AND v_y.ovsync_tren = v_b
                        AND (SELECT tamamlandi FROM public.gorev_log WHERE id = (v_r->>'yeni_gorev_id')::uuid),
                        'TR-K6-B1', 'tren bugün: basladi, yeni vaka D0 bugün, etiket bugün, görev kapandı', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT close_reason FROM public.cases WHERE id = v_c) = 'IPTAL'
                        AND (SELECT status FROM public.cases WHERE id = (v_r->>'yeni_case_id')::uuid) = 'active',
                        'TR-K6-B1', 'eski IPTAL, yeni aktif', 'farklı');
  -- D6 tur 2 (RL-12): aşama 2 (seans 1+2, PG TAI açık) → K6(b) iki dalda da PG TAI bırakmaz (a/b dışlayıcı)
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  v_tai := pg_temp.kb_pg_tai(v_h);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 2 AND v_tai IS NOT NULL, 'TR-K6-B1', 'fixture: aşama 2, PG TAI açık (tren bugün+3)',
                        format('%s %s', public._ovsync_asama(v_c), v_tai));
  v_r := public.ovsync_bastan_baslat(v_c);
  PERFORM pg_temp.kb_ok((v_r->>'basladi')::boolean = false AND pg_temp.kb_pg_tai(v_h) IS NULL
                        AND (SELECT iptal AND tamamlandi AND kapatan_ref LIKE 'ILK_TOH_PROTOKOL_YERINE:%' FROM public.gorev_log WHERE id = v_tai),
                        'TR-K6-B1', 'aşama 2, basladi=false: PG TAI iptal (ILK_TOH_PROTOKOL_YERINE)',
                        v_r::text || ' ' || COALESCE(pg_temp.kb_pg_tai(v_h)::text, '-'));
  -- D7 (D6 review KÜÇÜK): başlamayan dal iptal ettiği PG TAI id'lerini dönüşe ve islem_log payload'ına yazar
  PERFORM pg_temp.kb_ok(v_r->'iptal_tai' = jsonb_build_array(v_tai)
                        AND EXISTS (SELECT 1 FROM public.islem_log l WHERE l.tip = 'OVSYNC_BASTAN_BEKLIYOR' AND l.ref_id = v_r->>'yeni_gorev_id'
                                       AND l.payload->'iptal_tai' = jsonb_build_array(v_tai) AND (l.payload->>'case_id')::uuid = v_c),
                        'TR-K6-B1', 'basladi=false: iptal_tai = [PG TAI] dönüşte ve islem_log payload''ında', v_r::text);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  v_tai := pg_temp.kb_pg_tai(v_h);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 2 AND v_tai IS NOT NULL, 'TR-K6-B1', 'fixture: aşama 2, PG TAI açık (tren bugün)',
                        format('%s %s', public._ovsync_asama(v_c), v_tai));
  v_r := public.ovsync_bastan_baslat(v_c);
  PERFORM pg_temp.kb_ok((v_r->>'basladi')::boolean AND pg_temp.kb_pg_tai(v_h) IS NULL
                        AND (SELECT iptal AND tamamlandi AND kapatan_ref LIKE 'ILK_TOH_PROTOKOL_YERINE:%' FROM public.gorev_log WHERE id = v_tai),
                        'TR-K6-B1', 'aşama 2, basladi=true: PG TAI iptal (ILK_TOH_PROTOKOL_YERINE)',
                        v_r::text || ' ' || COALESCE(pg_temp.kb_pg_tai(v_h)::text, '-'));
  PERFORM pg_temp.kb_ok(v_r->'iptal_tai' = jsonb_build_array(v_tai), 'TR-K6-B1', 'basladi=true: iptal_tai = start pg_gorev_iptal', v_r::text);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_bastan_baslat(%L::uuid)', pg_temp.kb_mastit(pg_temp.kb_hayvan(), v_b + 1)));
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_VAKA_YOK') IS NOT NULL, 'TR-K6-B1', 'Ovsync olmayan vaka → OVSYNC_VAKA_YOK', v_e);
  RAISE NOTICE 'PASS TR-K6-B1: baştan başlat → trene bin';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K6-B2: ovsync_bastan_baslat(p_bagimsiz => true) → yeni vaka D0 bugün, etiket NULL (bugün tren değil)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_r jsonb; v_y record;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b - 4);
  v_r := public.ovsync_bastan_baslat(v_c, p_bagimsiz => true);
  SELECT * INTO v_y FROM pg_temp.kb_vaka_d0((v_r->>'yeni_case_id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'basladi')::boolean AND (v_r->>'kapanan_case_id')::uuid = v_c AND v_y.gun1 = v_b
                        AND v_y.start_date = v_b AND v_y.ovsync_tren IS NULL,
                        'TR-K6-B2', 'bağımsız: basladi, D0 bugün, etiket NULL', v_r::text || ' ' || row_to_json(v_y)::text);
  RAISE NOTICE 'PASS TR-K6-B2: baştan başlat bağımsız';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K6-B-N1: baştan başlat istenen sonucu üretemezse hepsi geri (fail-closed):
--   (a) yeniden başlat görevi açılmadı (dogum_tarihi yok → TABANSIZ) → OVSYNC_BASTAN_BASLATILAMADI{yeniden_not};
--   (b) tren bugün ama başlatma muaf (Bekliyor tohumlama) → aynı kod; ikisinde de vaka açık kalır
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_e text; v_j jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  UPDATE public.hayvanlar SET dogum_tarihi = NULL WHERE id = v_h;
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_bastan_baslat(%L::uuid)', v_c));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_BASTAN_BASLATILAMADI');
  PERFORM pg_temp.kb_ok((v_j->>'case_id')::uuid = v_c AND v_j->>'yeniden_not' LIKE 'TABANSIZ%', 'TR-K6-B-N1',
                        'kural çözülemedi → görev açılmadı → OVSYNC_BASTAN_BASLATILAMADI{yeniden_not TABANSIZ…}', v_e);
  PERFORM pg_temp.kb_ok((SELECT status FROM public.cases WHERE id = v_c) = 'active', 'TR-K6-B-N1', '(a) vaka açık kaldı (geri sarıldı)',
                        (SELECT status FROM public.cases WHERE id = v_c));
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_toh_bekliyor(v_h, v_b - 1);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_bastan_baslat(%L::uuid)', v_c));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_BASTAN_BASLATILAMADI');
  PERFORM pg_temp.kb_ok(v_j->>'yeniden_not' = 'BASLATMA_OLMADI' AND v_j->'sonuc'->>'atlandi' = 'BEKLIYOR', 'TR-K6-B-N1',
                        'tren bugün + Bekliyor → başlatma muaf → OVSYNC_BASTAN_BASLATILAMADI', v_e);
  PERFORM pg_temp.kb_ok((SELECT status FROM public.cases WHERE id = v_c) = 'active'
                        AND NOT EXISTS (SELECT 1 FROM pg_temp.kb_acik_ob(v_h)), 'TR-K6-B-N1', '(b) vaka açık, yeni görev yok (geri sarıldı)', 'farklı');
  RAISE NOTICE 'PASS TR-K6-B-N1: baştan başlat fail-closed';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K11-1 + TR-EK-UYARI: PG1 planlanan günden 2 gün sonra tamamlandı → occurred_at = now(), ovsync_uyari PG1_TOLERANS_ASILDI
--   gecikme 2 + sözleşme eki alanları; PG1 dışı geç seans uyarı üretmez
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_s uuid; v_r jsonb; v_u jsonb; v_o timestamptz;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_geri(v_c, 9);           -- GnRH1 bugün−9, PG1 planı bugün−2
  PERFORM pg_temp.kb_tren_ac(v_b - 2);       -- ritim etiketle aynı sınıf (bugün−9 ≡ bugün−2)
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 1 AND public._ovsync_pg1_kayma(v_c) = 0 AND (pg_temp.kb_gunler(v_c))[2] = v_b - 2,
                        'TR-K11-1', 'fixture: aşama 1, kayma 0, PG1 planı bugün−2', pg_temp.kb_gunler(v_c)::text);
  v_s := (pg_temp.kb_seanslar(v_c, 2))[1];
  v_r := pg_temp.kb_seans_yap_r(v_c, 2);
  SELECT occurred_at INTO v_o FROM public.pg_application_event WHERE source_type = 'TEDAVI_SEANS' AND source_id = v_s::text;
  PERFORM pg_temp.kb_ok(v_o BETWEEN now() - interval '1 minute' AND now() + interval '1 minute', 'TR-K11-1',
                        'PG olay anı = gerçek tamamlama anı (±1 dk)', v_o::text);
  v_u := v_r->'ovsync_uyari';
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_u->>'kod' = 'PG1_TOLERANS_ASILDI' AND (v_u->>'gecikme_gun')::int = 2
                        AND v_u->>'oneri' = 'BASTAN_BASLAT' AND (v_u->>'case_id')::uuid = v_c,
                        'TR-K11-1', 'ovsync_uyari {PG1_TOLERANS_ASILDI, gecikme 2, BASTAN_BASLAT, case_id}', v_r::text);
  PERFORM pg_temp.kb_ok(v_u->>'kupe_no' = (SELECT kupe_no FROM public.hayvanlar WHERE id = v_h)
                        AND (v_u->>'planlanan_tarih')::date = v_b - 2 AND (v_u->>'tamamlanan_tarih')::date = v_b
                        AND (v_u->>'bastan_tren_gunu')::date = public._ovsync_tren_gunu(v_b) AND (v_u->>'bastan_tren_gunu')::date = v_b + 5,
                        'TR-EK-UYARI', 'kupe_no, planlanan_tarih bugün−2, tamamlanan_tarih bugün, bastan_tren_gunu bugün+5', v_u::text);
  -- PG1 dışı (gün#3, planı bugün−1) geç tamamlama → uyarı yok
  v_r := pg_temp.kb_seans_yap_r(v_c, 3);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND NOT v_r ? 'ovsync_uyari', 'TR-K11-1', 'gün#3 geç → ovsync_uyari yok', v_r::text);
  RAISE NOTICE 'PASS TR-K11-1: PG1 2 gün geç → uyarı';
  RAISE NOTICE 'PASS TR-EK-UYARI: uyarı sözleşme eki alanları';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K11-2: PG1 1 gün geç (tolerans 1) → ovsync_uyari yok; olay anı yine now()
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_s uuid; v_r jsonb; v_o timestamptz;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_geri(v_c, 8);
  PERFORM pg_temp.kb_tren_ac(v_b - 1);
  v_s := (pg_temp.kb_seanslar(v_c, 2))[1];
  v_r := pg_temp.kb_seans_yap_r(v_c, 2);
  SELECT occurred_at INTO v_o FROM public.pg_application_event WHERE source_type = 'TEDAVI_SEANS' AND source_id = v_s::text;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND NOT v_r ? 'ovsync_uyari' AND v_o BETWEEN now() - interval '1 minute' AND now() + interval '1 minute',
                        'TR-K11-2', '1 gün geç → uyarı yok, olay anı now()', v_r::text || ' ' || v_o);
  RAISE NOTICE 'PASS TR-K11-2: tolerans içinde uyarı yok';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K11-3: önce ovsync_hayvan_ertele(h,1) (kayma 1), sonra PG1 yeni planından 1 gün geç → gecikme 2 (birikimli), uyarı var
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_r jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_geri(v_c, 9);
  PERFORM pg_temp.kb_tren_ac(v_b - 2);
  PERFORM public.ovsync_hayvan_ertele(v_h, 1);
  PERFORM pg_temp.kb_ok(public._ovsync_pg1_kayma(v_c) = 1 AND (pg_temp.kb_gunler(v_c))[2] = v_b - 1, 'TR-K11-3',
                        'fixture: ertele +1 → PG1 planı bugün−1, kayma 1', pg_temp.kb_gunler(v_c)::text);
  v_r := pg_temp.kb_seans_yap_r(v_c, 2);
  PERFORM pg_temp.kb_ok(v_r->'ovsync_uyari'->>'kod' = 'PG1_TOLERANS_ASILDI' AND (v_r->'ovsync_uyari'->>'gecikme_gun')::int = 2
                        AND (v_r->'ovsync_uyari'->>'planlanan_tarih')::date = v_b - 1,
                        'TR-K11-3', 'yeni plandan 1 gün geç + kayma 1 → gecikme 2, uyarı', v_r::text);
  RAISE NOTICE 'PASS TR-K11-3: birikimli gecikme';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K11-REG: tren bayrağı 0 (Ovsync-PG açık) → olay anı = LEAST(now, planlanan an) = planlanan an (eski); uyarı yok
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_s uuid; v_p timestamptz; v_r jsonb; v_o timestamptz;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM pg_temp.kb_geri(v_c, 9);
  v_s := (pg_temp.kb_seanslar(v_c, 2))[1];
  SELECT (u.planned_date + u.planned_time) AT TIME ZONE 'Europe/Istanbul' INTO v_p FROM public.treatment_day_uygulamalar u WHERE u.id = v_s;
  v_r := pg_temp.kb_seans_yap_r(v_c, 2);
  SELECT occurred_at INTO v_o FROM public.pg_application_event WHERE source_type = 'TEDAVI_SEANS' AND source_id = v_s::text;
  PERFORM pg_temp.kb_ok(v_p < now() - interval '1 day' AND v_o = v_p AND NOT v_r ? 'ovsync_uyari', 'TR-K11-REG',
                        'bayrak 0: occurred_at = planlanan an (LEAST), uyarı yok', v_o || ' / ' || v_p || ' ' || v_r::text);
  RAISE NOTICE 'PASS TR-K11-REG: bayrak 0 eski olay anı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-KAPALI: tren bayrağı 0 → üç yeni RPC OVSYNC_TREN_KAPALI (gerçek Ovsync fixture'ında da; hiçbir şey değişmez)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_e text; v_g0 date[];
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  v_g0 := pg_temp.kb_gunler(v_c);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_hayvan_ertele(%L, 1)', v_h));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_KAPALI%', 'TR-KAPALI', 'ovsync_hayvan_ertele → OVSYNC_TREN_KAPALI', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_pg48_tohumla(%L::uuid)', v_c));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_KAPALI%', 'TR-KAPALI', 'ovsync_pg48_tohumla → OVSYNC_TREN_KAPALI', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_bastan_baslat(%L::uuid)', v_c));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_KAPALI%', 'TR-KAPALI', 'ovsync_bastan_baslat → OVSYNC_TREN_KAPALI', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler(v_c) = v_g0 AND (SELECT status FROM public.cases WHERE id = v_c) = 'active',
                        'TR-KAPALI', 'vaka değişmedi', 'değişti');
  RAISE NOTICE 'PASS TR-KAPALI: bayrak 0 → OVSYNC_TREN_KAPALI';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ACL-3: üç yeni RPC + seans_tamamla: anon kapalı, authenticated/service_role açık, SECDEF, tek overload
SAVEPOINT kb_s;
DO $t$
DECLARE v_f text; v_n int := 0;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['public.ovsync_hayvan_ertele(text,integer)',
                             'public.ovsync_pg48_tohumla(uuid)',
                             'public.ovsync_bastan_baslat(uuid,boolean,text,date)',   -- D7 tur 2: p_hedef (RL-15)
                             'public.seans_tamamla(uuid,boolean,text,boolean,text,boolean)'] LOOP
    PERFORM pg_temp.kb_ok(to_regprocedure(v_f) IS NOT NULL AND NOT has_function_privilege('anon', v_f, 'EXECUTE')
                          AND has_function_privilege('authenticated', v_f, 'EXECUTE') AND has_function_privilege('service_role', v_f, 'EXECUTE')
                          AND (SELECT prosecdef FROM pg_proc WHERE oid = to_regprocedure(v_f)),
                          'TR-ACL-3', v_f || ' anon kapalı, authenticated/service_role açık, SECDEF', 'yanlış');
    v_n := v_n + 1;
  END LOOP;
  PERFORM pg_temp.kb_ok(v_n = 4 AND (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                                       AND proname IN ('ovsync_hayvan_ertele', 'ovsync_pg48_tohumla', 'ovsync_bastan_baslat', 'seans_tamamla')) = 4,
                        'TR-ACL-3', '4 imza, overload yok', v_n::text);
  RAISE NOTICE 'PASS TR-ACL-3: D6 ACL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM D7 — Tren listesi (K3, R16) ve toptan erteleme (K7, R7/R9/R18) (D7, migration 20261110100007)
--   ovsync_tren_listele, ovsync_tren_ertele_onizle, ovsync_tren_ertele; RL-1, RL-12, R6-EK, sözleşme eki (pg_pay, ritim_disi_neden,
--   pg1_zaman, ovsync_tren, tren_sayisi, dokunulmaz).
-- ════════════════════════════════════════════════════════════════════════════

-- TR-LISTE-1 / TR-K3-1 / TR-EK-LISTE: D0 treni (bugün), D7 treni (bugün−7), ileri tren (bugün+7, görev) ve bağımsız; sonraki_is.tur,
--   pg_pay (aşama 1 = tolerans − kayma, ham; aşama 0/2 NULL), pg1_zaman, ritimdekilerde ritim_disi_neden NULL; üyesiz tren yok
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_l jsonb; v_a text; v_bb text; v_d text; v_e text; v_f text; v_k text;
        v_cd uuid; v_u jsonb; v_hs text[];
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_a := pg_temp.kb_hayvan();  PERFORM pg_temp.kb_ovsync_vaka(v_a, v_b);
  v_bb := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_ovsync_vaka(v_bb, v_b - 7);
  v_d := pg_temp.kb_hayvan();  v_cd := pg_temp.kb_ovsync_vaka(v_d, v_b - 7);
  PERFORM pg_temp.kb_seans_yap(v_cd, 2);
  v_e := pg_temp.kb_hayvan();  PERFORM pg_temp.kb_ob_gorev(v_e, v_b + 7);
  v_f := pg_temp.kb_hayvan();  PERFORM pg_temp.kb_ovsync_vaka(v_f, v_b + 1);          -- tren günü değil → bağımsız
  v_k := pg_temp.kb_hayvan();  PERFORM pg_temp.kb_seans_yap(pg_temp.kb_ovsync_vaka(v_k, v_b - 1), 1);   -- bağımsız, kayma −1
  v_hs := ARRAY[v_a, v_bb, v_d, v_e, v_f, v_k];
  v_l := public.ovsync_tren_listele();
  PERFORM pg_temp.kb_ok((v_l->>'ok')::boolean AND (v_l->>'aktif')::boolean AND (v_l->>'capa')::date = v_b AND (v_l->>'bugun')::date = v_b,
                        'TR-LISTE-1', 'ok, aktif, capa = bugun = bugün', v_l::text);
  v_u := pg_temp.kb_liste_uye(v_l, v_a);
  PERFORM pg_temp.kb_ok((v_u->>'_tren')::date = v_b AND v_u->'_ritim_disi' = 'false'::jsonb AND (v_u->>'asama')::int = 0
                        AND v_u->'sonraki_is'->>'tur' = 'GNRH1' AND (v_u->'sonraki_is'->>'tarih')::date = v_b
                        AND (v_u->'sonraki_is'->>'saat')::time = '10:00' AND v_u->>'case_id' IS NOT NULL AND (v_u->>'_adet')::int = 1,
                        'TR-LISTE-1', 'D0 treni (bugün): aşama 0, sonraki GNRH1 bugün 10:00', v_u::text);
  v_u := pg_temp.kb_liste_uye(v_l, v_bb);
  PERFORM pg_temp.kb_ok((v_u->>'_tren')::date = v_b - 7 AND (v_u->>'asama')::int = 1 AND v_u->'sonraki_is'->>'tur' = 'PG1'
                        AND (v_u->'sonraki_is'->>'tarih')::date = v_b,
                        'TR-LISTE-1', 'D7 treni (bugün−7): aşama 1, sonraki PG1 bugün', v_u::text);
  PERFORM pg_temp.kb_ok((v_u->>'pg_pay')::int = 1 AND v_u->'pg1_zaman' = 'null'::jsonb AND v_u->'ritim_disi_neden' = 'null'::jsonb,
                        'TR-EK-LISTE', 'aşama 1: pg_pay = tolerans 1 − kayma 0, pg1_zaman NULL, ritimde neden NULL', v_u::text);
  v_u := pg_temp.kb_liste_uye(v_l, v_d);
  PERFORM pg_temp.kb_ok((v_u->>'_tren')::date = v_b - 7 AND (v_u->>'asama')::int = 2 AND v_u->'sonraki_is'->>'tur' = 'PG2'
                        AND (v_u->'sonraki_is'->>'tarih')::date = v_b + 1,
                        'TR-LISTE-1', 'D7 treni: aşama 2, sonraki PG2 yarın', v_u::text);
  PERFORM pg_temp.kb_ok(v_u->'pg_pay' = 'null'::jsonb AND abs(extract(epoch FROM (v_u->>'pg1_zaman')::timestamptz - now())) < 60,
                        'TR-EK-LISTE', 'aşama 2: pg_pay NULL, pg1_zaman = PG1 seansı uygulama anı (±1 dk)', v_u::text);
  v_u := pg_temp.kb_liste_uye(v_l, v_a);
  PERFORM pg_temp.kb_ok(v_u->'pg_pay' = 'null'::jsonb AND v_u->'pg1_zaman' = 'null'::jsonb, 'TR-EK-LISTE', 'aşama 0: pg_pay/pg1_zaman NULL', v_u::text);
  v_u := pg_temp.kb_liste_uye(v_l, v_e);
  PERFORM pg_temp.kb_ok((v_u->>'_tren')::date = v_b + 7 AND v_u->>'gorev_id' IS NOT NULL AND v_u->'case_id' = 'null'::jsonb
                        AND (v_u->>'asama')::int = 0 AND v_u->'sonraki_is'->>'tur' = 'GNRH1' AND (v_u->'sonraki_is'->>'tarih')::date = v_b + 7,
                        'TR-LISTE-1', 'görev treni (bugün+7): gorev_id dolu, case_id NULL, GNRH1', v_u::text);
  v_u := pg_temp.kb_liste_uye(v_l, v_f);
  PERFORM pg_temp.kb_ok((v_u->>'_bagimsiz')::boolean AND v_u->>'_tren' IS NULL AND (v_u->>'_adet')::int = 1 AND (v_u->>'asama')::int = 0,
                        'TR-LISTE-1', 'D0 tren günü değil → bagimsizlar (trende değil)', v_u::text);
  v_u := pg_temp.kb_liste_uye(v_l, v_k);
  PERFORM pg_temp.kb_ok((v_u->>'_bagimsiz')::boolean AND (v_u->>'asama')::int = 1 AND (v_u->>'pg_pay')::int = 2,
                        'TR-EK-LISTE', 'GnRH1 1 gün geç (kayma −1) → pg_pay = 1 − (−1) = 2 (ham)', v_u::text);
  -- K3: üyesiz tren yok; KB kümesinin trenleri tam {bugün−7, bugün, bugün+7} (bugün+14 ritim günü ama üyesiz → yok)
  PERFORM pg_temp.kb_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_l->'trenler') t WHERE jsonb_array_length(t.value->'uyeler') = 0),
                        'TR-K3-1', 'listede üyesiz tren yok', v_l->>'trenler');
  PERFORM pg_temp.kb_ok((SELECT array_agg(DISTINCT (t.value->>'tren_gunu')::date ORDER BY (t.value->>'tren_gunu')::date)
                           FROM jsonb_array_elements(v_l->'trenler') t, jsonb_array_elements(t.value->'uyeler') u
                          WHERE u.value->>'hayvan_id' = ANY(v_hs)) = ARRAY[v_b - 7, v_b, v_b + 7],
                        'TR-K3-1', 'KB trenleri {bugün−7, bugün, bugün+7}, boş ritim günü yok', v_l->>'trenler');
  RAISE NOTICE 'PASS TR-LISTE-1/TR-K3-1/TR-EK-LISTE: tren listesi';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-LISTE-2: ileri (bugün+40) görev → ileri_sayisi +1, tren listesinde değil; bugün+28 sınırda listede; bayrak 0 → aktif false
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_l0 jsonb; v_l jsonb; v_h text; v_h28 text;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_l0 := public.ovsync_tren_listele();
  v_h := pg_temp.kb_hayvan();   PERFORM pg_temp.kb_ob_gorev(v_h, v_b + 40);
  v_h28 := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_ob_gorev(v_h28, v_b + 28);
  v_l := public.ovsync_tren_listele();
  PERFORM pg_temp.kb_ok((v_l->>'ileri_sayisi')::int = (v_l0->>'ileri_sayisi')::int + 1 AND (pg_temp.kb_liste_uye(v_l, v_h)->>'_adet')::int = 0,
                        'TR-LISTE-2', 'bugün+40 görev: ileri_sayisi +1, listede yok', v_l0->>'ileri_sayisi' || ' → ' || (v_l->>'ileri_sayisi'));
  PERFORM pg_temp.kb_ok((pg_temp.kb_liste_uye(v_l, v_h28)->>'_tren')::date = v_b + 28, 'TR-LISTE-2', 'bugün+28 sınırda listede',
                        pg_temp.kb_liste_uye(v_l, v_h28)::text);
  PERFORM pg_temp.kb_tren_kapat();
  v_l := public.ovsync_tren_listele();
  PERFORM pg_temp.kb_ok((v_l->>'ok')::boolean AND NOT (v_l->>'aktif')::boolean AND jsonb_array_length(v_l->'trenler') = 0,
                        'TR-LISTE-2', 'bayrak 0 → {ok, aktif:false}, tren yok', v_l::text);
  RAISE NOTICE 'PASS TR-LISTE-2: ileri_sayisi';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K9-N1 (D7): hastalık günlü hayvan listede bagimsizlar'da, hiçbir trende değil
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_u jsonb;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b + 2);
  PERFORM pg_temp.kb_ok((pg_temp.kb_liste_uye(public.ovsync_tren_listele(), v_h)->>'_tren')::date = v_b + 2, 'TR-K9-N1', 'fixture: listede trende', 'yok');
  PERFORM public.ovsync_hastalik_gunu_ekle(v_c);
  v_u := pg_temp.kb_liste_uye(public.ovsync_tren_listele(), v_h);
  PERFORM pg_temp.kb_ok((v_u->>'_bagimsiz')::boolean AND (v_u->>'_adet')::int = 1 AND (v_u->>'case_id')::uuid = v_c,
                        'TR-K9-N1', 'K9 sonrası listede bagimsizlar (tek görünme)', v_u::text);
  RAISE NOTICE 'PASS TR-K9-N1 (D7): hastalık günlü hayvan bagimsizlar''da';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-RITIM / TR-K7-TOL (1) / TR-EK-LISTE: tek hayvan +1 → etiket ritim dışı → listede ritim_disi:true kendi başlığı,
--   ritim_disi_neden 'PG +1 gün', pg_pay 0; toptan önizleme kümesinde yok
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_l jsonb; v_u jsonb; v_p jsonb; v_o text;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM public.ovsync_hayvan_ertele(v_h, 1);
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  v_l := public.ovsync_tren_listele();
  v_u := pg_temp.kb_liste_uye(v_l, v_h);
  PERFORM pg_temp.kb_ok((v_u->>'_tren')::date = v_b + 1 AND (v_u->>'_ritim_disi')::boolean AND (v_u->>'_adet')::int = 1
                        AND (SELECT jsonb_array_length(t.value->'uyeler') FROM jsonb_array_elements(v_l->'trenler') t
                              WHERE (t.value->>'tren_gunu')::date = v_b + 1) = 1,
                        'TR-K7-RITIM', 'ritim dışı etiket (bugün+1) kendi başlığında, ritim_disi true', v_u::text);
  PERFORM pg_temp.kb_ok(v_u->>'ritim_disi_neden' = 'PG +1 gün' AND (v_u->>'pg_pay')::int = 0, 'TR-EK-LISTE',
                        'ritim_disi_neden ''PG +1 gün'', pg_pay 0 (pay doldu)', v_u::text);
  -- ham değer (kırpma yok): tolerans 2 iken +1 daha (kayma 2), sonra tolerans 1 → pg_pay −1
  PERFORM pg_temp.kb_ayar('ovsync_pg_erteleme_tolerans_gun', 2);
  PERFORM public.ovsync_hayvan_ertele(v_h, 1);
  PERFORM pg_temp.kb_ayar('ovsync_pg_erteleme_tolerans_gun', 1);
  v_u := pg_temp.kb_liste_uye(public.ovsync_tren_listele(), v_h);
  PERFORM pg_temp.kb_ok((v_u->>'pg_pay')::int = -1 AND v_u->>'ritim_disi_neden' = 'PG +2 gün', 'TR-EK-LISTE',
                        'pg_pay ham (1 − 2 = −1, 0''a kırpılmaz), neden ''PG +2 gün''', v_u::text);
  v_o := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_ob_gorev(v_o, v_b + 7);
  v_p := public.ovsync_tren_ertele_onizle(v_b + 7, 1);
  PERFORM pg_temp.kb_ok(pg_temp.kb_plan_uye(v_p, v_h) IS NULL AND pg_temp.kb_plan_uye(v_p, v_o) IS NOT NULL,
                        'TR-K7-TOL', 'ritim dışı aşama 1 vaka bugün+7 toptan kümesinde YOK', v_p::text);
  RAISE NOTICE 'PASS TR-K7-RITIM/TR-K7-TOL(1): ritim dışı başlık';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-TOL (2): tek hayvan +1 (kayma 1, etiket bugün+1) → bugün treninin toptan +1'i ritmi bugün+1 sınıfına taşır → bu vakanın
--   PG1 gününde (bugün+8) önizleme +1 → BASTAN (birikimli 1+1 = 2 > 1)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_p jsonb; v_u jsonb;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_seans_yap(v_c, 1);
  PERFORM public.ovsync_hayvan_ertele(v_h, 1);
  PERFORM pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b);                 -- bugün treninin üyesi
  PERFORM public.ovsync_tren_ertele(v_b, 1);
  PERFORM pg_temp.kb_ok(pg_temp.kb_capa() = v_b + 1 AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b + 1,
                        'TR-K7-TOL', 'çapa bugün+1, vaka etiketi yeniden ritimde', pg_temp.kb_capa()::text);
  -- RL-16: etiket bugün+1 vaka bugün+1 treninin (ii) üyesi → toptan yalnız orada; PG1 erteleme kararı aynı (birikimli)
  v_p := public.ovsync_tren_ertele_onizle(v_b + 1, 1);
  v_u := pg_temp.kb_plan_uye(v_p, v_h);
  PERFORM pg_temp.kb_ok((v_u->>'asama')::int = 1 AND v_u->>'sonuc' = 'BASTAN' AND (v_u->>'pg_pay')::int = 0,
                        'TR-K7-TOL', 'etiket treninde +1 → BASTAN (birikimli 2 > 1)', v_u::text);
  RAISE NOTICE 'PASS TR-K7-TOL(2): birikimli tolerans toptanda';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-1 / TR-K7-6 / TR-K7-7: X = bugün; 2 görev (aşama 0) + D7 vakası (aşama 1) → ertele(X,1): görevler X+1, D7 vakasının kalan günleri
--   +1 (etiket +1 tek sayım), çapa X+1, önizleme = gerçek; bağımsız vaka dokunulmaz; X+7 ileri görev → X+8 (R9); islem_log
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_f jsonb; v_p jsonb; v_r jsonb; v_g3 date[]; v_g6 date[]; v_u jsonb; v_i jsonb; v_l jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  v_f := pg_temp.kb_k7_fixture(v_b);
  v_g3 := pg_temp.kb_gunler((v_f->>'c3')::uuid);
  v_g6 := pg_temp.kb_gunler((v_f->>'c6')::uuid);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 1);
  PERFORM pg_temp.kb_ok((v_p->>'ok')::boolean AND (v_p->>'tren')::date = v_b AND (v_p->>'yeni_tren')::date = v_b + 1,
                        'TR-K7-1', 'önizleme tren X, yeni_tren X+1', v_p::text);
  v_u := pg_temp.kb_plan_uye(v_p, v_f->>'h1');
  PERFORM pg_temp.kb_ok(v_u->>'sonuc' = 'KAYAR' AND (v_u->>'asama')::int = 0 AND (v_u->>'yeni_tarih')::date = v_b + 1
                        AND (v_u->>'gorev_id')::uuid = (v_f->>'g1')::uuid AND v_u->'case_id' = 'null'::jsonb,
                        'TR-K7-1', 'görev üyesi: aşama 0, KAYAR → X+1', v_u::text);
  v_u := pg_temp.kb_plan_uye(v_p, v_f->>'h3');
  PERFORM pg_temp.kb_ok(v_u->>'sonuc' = 'KAYAR' AND (v_u->>'asama')::int = 1 AND (v_u->>'yeni_tarih')::date = v_g3[2] + 1,
                        'TR-K7-1', 'D7 vakası: aşama 1, KAYAR → PG1 + 1', v_u::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_plan_uye(v_p, v_f->>'h6') IS NULL AND pg_temp.kb_plan_uye(v_p, v_f->>'h7') IS NULL
                        AND jsonb_array_length(v_p->'uyeler') = 3,
                        'TR-K7-6', 'bağımsız vaka ve ileri görev kümede değil (3 üye)', v_p->>'uyeler');
  PERFORM pg_temp.kb_ok((v_p->'ileri_gorevler'->0->>'gorev_id')::uuid = (v_f->>'g7')::uuid AND jsonb_array_length(v_p->'ileri_gorevler') = 1
                        AND (v_p->'ileri_gorevler'->0->>'eski')::date = v_b + 7 AND (v_p->'ileri_gorevler'->0->>'yeni')::date = v_b + 8,
                        'TR-K7-7', 'önizleme ileri görev X+7 → X+8', v_p->>'ileri_gorevler');
  v_r := public.ovsync_tren_ertele(v_b, 1);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND jsonb_array_length(v_r->'islenen') = 3 AND (v_r->>'yeni_tren')::date = v_b + 1,
                        'TR-K7-1', 'ertele ok, 3 üye işlendi', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = (v_f->>'g1')::uuid) = v_b + 1
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = (v_f->>'g2')::uuid) = v_b + 1,
                        'TR-K7-1', 'görev hedefleri X+1', 'farklı');
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler((v_f->>'c3')::uuid) = ARRAY[v_g3[1], v_g3[2] + 1, v_g3[3] + 1, v_g3[4] + 1]
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = (v_f->>'c3')::uuid) = v_b - 6,
                        'TR-K7-1', 'D7 vakası gün#1 sabit, gün#2..4 +1, etiket X−7 → X−6 (tek sayım, RL-1)',
                        pg_temp.kb_gunler((v_f->>'c3')::uuid)::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_capa() = v_b + 1, 'TR-K7-1', 'çapa X+1', pg_temp.kb_capa()::text);
  -- önizleme = gerçek (her üyenin yeni_tarih'i)
  FOR v_i IN SELECT e.value FROM jsonb_array_elements(v_r->'islenen') e LOOP
    PERFORM pg_temp.kb_ok((v_i->>'yeni_tarih')::date = (pg_temp.kb_plan_uye(v_p, v_i->>'hayvan_id')->>'yeni_tarih')::date,
                          'TR-K7-1', 'önizleme yeni_tarih = gerçek', v_i::text);
  END LOOP;
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM public.islem_log l WHERE l.tip = 'OVSYNC_TREN_ERTELE' AND (l.payload->>'tren')::date = v_b
                                   AND (l.payload->>'n')::int = 1 AND (l.payload->>'yeni_capa')::numeric = to_char(v_b + 1, 'YYYYMMDD')::numeric
                                   AND l.payload->>'eski_capa' = to_char(v_b, 'YYYYMMDD')),
                        'TR-K7-1', 'islem_log OVSYNC_TREN_ERTELE (eski/yeni çapa)', 'yok');
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler((v_f->>'c6')::uuid) = v_g6 AND (SELECT ovsync_tren FROM public.cases WHERE id = (v_f->>'c6')::uuid) IS NULL,
                        'TR-K7-6', 'bağımsız vaka günleri ve etiketi değişmedi', pg_temp.kb_gunler((v_f->>'c6')::uuid)::text);
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = (v_f->>'g7')::uuid) = v_b + 8
                        AND EXISTS (SELECT 1 FROM public.islem_log l WHERE l.tip = 'GOREV_ERTELE' AND l.ref_id = v_f->>'g7'),
                        'TR-K7-7', 'ileri görev X+7 → X+8 (R9, GOREV_ERTELE soyu)', (SELECT hedef_tarih::text FROM public.gorev_log WHERE id = (v_f->>'g7')::uuid));
  v_l := public.ovsync_tren_listele();
  PERFORM pg_temp.kb_ok((pg_temp.kb_liste_uye(v_l, v_f->>'h1')->>'_tren')::date = v_b + 1
                        AND NOT (pg_temp.kb_liste_uye(v_l, v_f->>'h3')->>'_ritim_disi')::boolean,
                        'TR-K7-1', 'listede görev X+1 treninde, D7 vakası ritimde', v_l::text);
  RAISE NOTICE 'PASS TR-K7-1/TR-K7-6/TR-K7-7: toptan +1';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-2: aynı fixture ertele(X,3) → aşama 1 vaka IPTAL (birikimli 0+3 > 1) + yeni görev hedefi X+3 (D6 ovsync_bastan_baslat); görevler X+3
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_f jsonb; v_p jsonb; v_r jsonb; v_u jsonb; v_ob date;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  v_f := pg_temp.kb_k7_fixture(v_b);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 3);
  v_u := pg_temp.kb_plan_uye(v_p, v_f->>'h3');
  PERFORM pg_temp.kb_ok(v_u->>'sonuc' = 'BASTAN' AND (v_u->>'yeni_tarih')::date = v_b + 3, 'TR-K7-2', 'önizleme: D7 vakası BASTAN → X+3', v_u::text);
  v_r := public.ovsync_tren_ertele(v_b, 3);
  SELECT hedef_tarih INTO v_ob FROM pg_temp.kb_acik_ob(v_f->>'h3');
  PERFORM pg_temp.kb_ok((SELECT status = 'closed' AND close_reason = 'IPTAL' FROM public.cases WHERE id = (v_f->>'c3')::uuid) AND v_ob = v_b + 3
                        AND (SELECT count(*) FROM pg_temp.kb_acik_ob(v_f->>'h3')) = 1,
                        'TR-K7-2', 'D7 vakası IPTAL, yeni OVSYNC_BASLAT hedefi X+3', COALESCE(v_ob::text, 'görev yok'));
  PERFORM pg_temp.kb_ok((SELECT e.value->>'islem' = 'BASTAN' AND (e.value->>'yeni_tarih')::date = v_b + 3
                               FROM jsonb_array_elements(v_r->'islenen') e WHERE e.value->>'hayvan_id' = v_f->>'h3'),
                        'TR-K7-2', 'islenen: BASTAN, yeni_tarih X+3 (= önizleme)', v_r->>'islenen');
  PERFORM pg_temp.kb_ok((SELECT hedef_tarih FROM public.gorev_log WHERE id = (v_f->>'g1')::uuid) = v_b + 3 AND pg_temp.kb_capa() = v_b + 3,
                        'TR-K7-2', 'görevler X+3, çapa X+3', pg_temp.kb_capa()::text);
  RAISE NOTICE 'PASS TR-K7-2: toptan +3 → aşama 1 baştan';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-2 (RL-15 varyantları): toptan BASTAN hedefi her zaman yeni tren X+N; aynı işlemde başlatma YOK (basladi:false).
--   X = bugün, N = 7 (yeni ritim bugünle çakışır) ve X = bugün+3, N = 4 (K2 en yakın tren bugün olurdu). Önizleme = gerçek.
CREATE FUNCTION pg_temp.kb_k7_bastan_xn(p_x date, p_n int) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE v_f jsonb; v_p jsonb; v_r jsonb; v_u jsonb; v_i jsonb; v_t text := 'TR-K7-2';
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  v_f := pg_temp.kb_k7_fixture(p_x);
  v_p := public.ovsync_tren_ertele_onizle(p_x, p_n);
  v_u := pg_temp.kb_plan_uye(v_p, v_f->>'h3');
  PERFORM pg_temp.kb_ok(v_u->>'sonuc' = 'BASTAN' AND (v_u->>'yeni_tarih')::date = p_x + p_n, v_t,
                        format('X=%s N=%s önizleme: BASTAN → X+N', p_x, p_n), v_u::text);
  v_r := public.ovsync_tren_ertele(p_x, p_n);
  SELECT e.value INTO v_i FROM jsonb_array_elements(v_r->'islenen') e WHERE e.value->>'hayvan_id' = v_f->>'h3';
  PERFORM pg_temp.kb_ok(v_i->>'islem' = 'BASTAN' AND (v_i->>'yeni_tarih')::date = p_x + p_n AND NOT (v_i->'detay'->>'basladi')::boolean,
                        v_t, format('X=%s N=%s islenen: BASTAN X+N, basladi false', p_x, p_n), v_i::text);
  PERFORM pg_temp.kb_ok((SELECT close_reason FROM public.cases WHERE id = (v_f->>'c3')::uuid) = 'IPTAL'
                        AND (SELECT hedef_tarih FROM pg_temp.kb_acik_ob(v_f->>'h3')) = p_x + p_n
                        AND (SELECT count(*) FROM pg_temp.kb_acik_ob(v_f->>'h3')) = 1
                        AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = v_f->>'h3' AND c.status = 'active'),
                        v_t, format('X=%s N=%s vaka IPTAL, tek açık görev X+N, yeni vaka yok', p_x, p_n),
                        (SELECT string_agg(hedef_tarih::text, ',') FROM pg_temp.kb_acik_ob(v_f->>'h3')));
  PERFORM pg_temp.kb_ok(pg_temp.kb_capa() = p_x + p_n, v_t, 'çapa X+N', pg_temp.kb_capa()::text);
END $f$;
SAVEPOINT kb_s;
DO $t$ BEGIN PERFORM pg_temp.kb_k7_bastan_xn(pg_temp.kb_bugun(), 7); RAISE NOTICE 'PASS TR-K7-2 (RL-15): X=bugün N=7 → X+N'; END $t$;
ROLLBACK TO SAVEPOINT kb_s;
SAVEPOINT kb_s;
DO $t$ BEGIN PERFORM pg_temp.kb_k7_bastan_xn(pg_temp.kb_bugun() + 3, 4); RAISE NOTICE 'PASS TR-K7-2 (RL-15): X=bugün+3 N=4 → X+N'; END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-GECIKMIS (RL-17): sınıf (iii) (etiket X−7) aşama 0 üye (GnRH1 X−7'de yapılmamış) → BASTAN (hedef X+N), geçmiş güne kaydırma yok
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_p jsonb; v_r jsonb; v_u jsonb; v_i jsonb;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan(); v_c := pg_temp.kb_ovsync_vaka(v_h, v_b);
  PERFORM pg_temp.kb_geri(v_c, 7);                                           -- D0 bugün−7, hiçbir seans yapılmadı
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c) = 0 AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) = v_b - 7,
                        'TR-K7-GECIKMIS', 'fixture: etiket X−7, aşama 0 (gecikmiş GnRH1)', pg_temp.kb_gunler(v_c)::text);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 1);
  v_u := pg_temp.kb_plan_uye(v_p, v_h);
  PERFORM pg_temp.kb_ok((v_u->>'asama')::int = 0 AND v_u->>'sonuc' = 'BASTAN' AND (v_u->>'yeni_tarih')::date = v_b + 1,
                        'TR-K7-GECIKMIS', 'önizleme: aşama 0 (iii) → BASTAN X+1 (geçmiş tarih yok)', v_u::text);
  -- ovsync_bastan_baslat p_hedef doğrulaması (RL-15, 006): tren günü değil / kendi hedefinden erken / bağımsızla → HEDEF_GECERSIZ, geri
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(pg_temp.kb_hata(format('SELECT public.ovsync_bastan_baslat(%L::uuid, false, NULL, %L::date)', v_c, v_b + 1)),
                                       'OVSYNC_BASTAN_HEDEF_GECERSIZ') IS NOT NULL
                        AND pg_temp.kb_kod(pg_temp.kb_hata(format('SELECT public.ovsync_bastan_baslat(%L::uuid, false, NULL, %L::date)', v_c, v_b - 7)),
                                           'OVSYNC_BASTAN_HEDEF_GECERSIZ') IS NOT NULL
                        AND pg_temp.kb_kod(pg_temp.kb_hata(format('SELECT public.ovsync_bastan_baslat(%L::uuid, true, NULL, %L::date)', v_c, v_b + 7)),
                                           'OVSYNC_BASTAN_HEDEF_GECERSIZ') IS NOT NULL
                        AND (SELECT status FROM public.cases WHERE id = v_c) = 'active',
                        'TR-K7-GECIKMIS', 'bastan_baslat p_hedef geçersiz (ritim dışı / erken / bağımsız) → HEDEF_GECERSIZ, vaka aktif', 'farklı');
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  v_r := public.ovsync_tren_ertele(v_b, 1);
  SELECT e.value INTO v_i FROM jsonb_array_elements(v_r->'islenen') e WHERE e.value->>'hayvan_id' = v_h;
  PERFORM pg_temp.kb_ok(v_i->>'islem' = 'BASTAN' AND (v_i->>'yeni_tarih')::date = v_b + 1
                        AND (SELECT close_reason FROM public.cases WHERE id = v_c) = 'IPTAL'
                        AND (SELECT hedef_tarih FROM pg_temp.kb_acik_ob(v_h)) = v_b + 1,
                        'TR-K7-GECIKMIS', 'ertele: vaka IPTAL, yeni görev X+1 (= önizleme)', v_r::text);
  RAISE NOTICE 'PASS TR-K7-GECIKMIS: (iii) aşama 0 → BASTAN';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-ILERI (RL-14): X = bugün; ileri D0'lı aşama 0 vakalar (etiket X+7, X+14) toptanda +N kayar (etiket RL-1 ile, tek sayım);
--   önizleme/dönüş/islem_log ileri_vakalar [{case_id, hayvan_id, kupe_no, eski, yeni}]; X kümesinde değiller; listede yeni ritimde
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h1 text; v_c1 uuid; v_h2 text; v_c2 uuid; v_g1 date[]; v_p jsonb; v_r jsonb; v_e jsonb; v_l jsonb;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  PERFORM pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b);                    -- X treninin üyesi
  v_h1 := pg_temp.kb_hayvan(); v_c1 := pg_temp.kb_ovsync_vaka(v_h1, v_b + 7);
  v_h2 := pg_temp.kb_hayvan(); v_c2 := pg_temp.kb_ovsync_vaka(v_h2, v_b + 14);
  v_g1 := pg_temp.kb_gunler(v_c1);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c1) = 0 AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c1) = v_b + 7
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c2) = v_b + 14,
                        'TR-K7-ILERI', 'fixture: ileri D0 aşama 0, etiket X+7 / X+14', v_g1::text);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 2);
  SELECT e.value INTO v_e FROM jsonb_array_elements(v_p->'ileri_vakalar') e WHERE e.value->>'hayvan_id' = v_h1;
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_p->'ileri_vakalar') = 2 AND (v_e->>'case_id')::uuid = v_c1 AND v_e->>'kupe_no' = v_h1
                        AND (v_e->>'eski')::date = v_b + 7 AND (v_e->>'yeni')::date = v_b + 9
                        AND pg_temp.kb_plan_uye(v_p, v_h1) IS NULL AND pg_temp.kb_plan_uye(v_p, v_h2) IS NULL,
                        'TR-K7-ILERI', 'önizleme ileri_vakalar: X+7 → X+9 (+N), kümede değil', COALESCE(v_p->>'ileri_vakalar', '<yok>'));
  v_r := public.ovsync_tren_ertele(v_b, 2);
  PERFORM pg_temp.kb_ok(v_r->'ileri_vakalar' = v_p->'ileri_vakalar', 'TR-K7-ILERI', 'dönüş ileri_vakalar = önizleme', COALESCE(v_r->>'ileri_vakalar', '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_gunler(v_c1) = ARRAY[v_g1[1] + 2, v_g1[2] + 2, v_g1[3] + 2, v_g1[4] + 2]
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c1) = v_b + 9
                        AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c2) = v_b + 16,
                        'TR-K7-ILERI', 'ileri vakaların günleri +2, etiket +2 (tek sayım, RL-1)', pg_temp.kb_gunler(v_c1)::text);
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM public.islem_log l WHERE l.tip = 'OVSYNC_TREN_ERTELE' AND jsonb_array_length(l.payload->'ileri_vakalar') = 2),
                        'TR-K7-ILERI', 'islem_log payload ileri_vakalar', 'yok');
  v_l := public.ovsync_tren_listele();
  PERFORM pg_temp.kb_ok((pg_temp.kb_liste_uye(v_l, v_h1)->>'_tren')::date = v_b + 9 AND NOT (pg_temp.kb_liste_uye(v_l, v_h1)->>'_ritim_disi')::boolean,
                        'TR-K7-ILERI', 'listede ileri vaka yeni ritimde (X+9)', pg_temp.kb_liste_uye(v_l, v_h1)::text);
  RAISE NOTICE 'PASS TR-K7-ILERI: ileri vakalar +N';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-3: aşama 2 üye seçimsiz → OVSYNC_TREN_SECIM_EKSIK{eksik:[case_id]}, hiçbir şey değişmedi; önizlemede SECIM
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_g uuid; v_p jsonb; v_e text; v_j jsonb; v_oz text;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan();
  v_c := pg_temp.kb_ovsync_vaka(v_h, v_b - 7);
  PERFORM pg_temp.kb_seans_yap(v_c, 2);
  v_g := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 1);
  PERFORM pg_temp.kb_ok(pg_temp.kb_plan_uye(v_p, v_h)->>'sonuc' = 'SECIM' AND (pg_temp.kb_plan_uye(v_p, v_h)->>'asama')::int = 2
                        AND pg_temp.kb_plan_uye(v_p, v_h)->'yeni_tarih' = 'null'::jsonb,
                        'TR-K7-3', 'önizleme: aşama 2 → SECIM, yeni_tarih NULL', v_p::text);
  v_oz := pg_temp.kb_ozet();
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ertele(%L::date, 1)', v_b));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_TREN_SECIM_EKSIK');
  PERFORM pg_temp.kb_ok(v_j->'eksik' = jsonb_build_array(v_c), 'TR-K7-3', 'OVSYNC_TREN_SECIM_EKSIK{eksik:[case_id]}', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ertele(%L::date, 1, %L::jsonb)', v_b, jsonb_build_object(v_c, 'HAYIR')));
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_TREN_SECIM_EKSIK') IS NOT NULL, 'TR-K7-3', 'geçersiz seçim de eksik sayılır', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_ozet() = v_oz AND pg_temp.kb_capa() = v_b AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_b,
                        'TR-K7-3', 'hiçbir şey değişmedi (özet md5, çapa, görev)', pg_temp.kb_capa()::text);
  RAISE NOTICE 'PASS TR-K7-3: seçim eksik';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-4: iki aşama 2 üye, seçim PG48 / BASTAN → başarı; PG48: kalan seanslar uygulanmadı, PG TAI açık, vaka aktif;
--   BASTAN: vaka IPTAL, yeni görev X+1, PG TAI kapandı (K6 a/b dışlaması, RL-12)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_hp text; v_cp uuid; v_hb text; v_cb uuid; v_r jsonb;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_hp := pg_temp.kb_hayvan(); v_cp := pg_temp.kb_ovsync_vaka(v_hp, v_b - 7); PERFORM pg_temp.kb_seans_yap(v_cp, 2);
  v_hb := pg_temp.kb_hayvan(); v_cb := pg_temp.kb_ovsync_vaka(v_hb, v_b - 7); PERFORM pg_temp.kb_seans_yap(v_cb, 2);
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_cp) = 2 AND public._ovsync_asama(v_cb) = 2 AND pg_temp.kb_pg_tai(v_hp) IS NOT NULL
                        AND pg_temp.kb_pg_tai(v_hb) IS NOT NULL, 'TR-K7-4', 'fixture: iki aşama 2, PG TAI açık', 'farklı');
  v_r := public.ovsync_tren_ertele(v_b, 1, jsonb_build_object(v_cp, 'PG48', v_cb, 'BASTAN'));
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND jsonb_array_length(v_r->'islenen') = 2, 'TR-K7-4', 'ertele ok, 2 üye', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT status FROM public.cases WHERE id = v_cp) = 'active' AND pg_temp.kb_pg_tai(v_hp) IS NOT NULL
                        AND NOT EXISTS (SELECT 1 FROM public.treatment_day_uygulamalar u JOIN public.treatment_days d ON d.id = u.treatment_day_id
                                         WHERE d.case_id = v_cp AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)),
                        'TR-K7-4', 'PG48: vaka aktif, kalan seanslar uygulanmadı, PG TAI açık', v_r->>'islenen');
  PERFORM pg_temp.kb_ok((SELECT close_reason FROM public.cases WHERE id = v_cb) = 'IPTAL' AND pg_temp.kb_pg_tai(v_hb) IS NULL
                        AND (SELECT hedef_tarih FROM pg_temp.kb_acik_ob(v_hb)) = v_b + 1,
                        'TR-K7-4', 'BASTAN: IPTAL, PG TAI kapandı, yeni görev X+1', v_r->>'islenen');
  RAISE NOTICE 'PASS TR-K7-4: aşama 2 seçimleri';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-5: üye düşer (aşama 1 vakanın şablon TAI'si geçmişte → kaydırma hata; aşama belirsiz vaka) → OVSYNC_TREN_ERTELE_DUSTU
--   {dusenler:[{hayvan_id, kupe_no, sebep, (oneri)}]}, tüm üyeler + çapa önceki halinde (R6-EK önerisi belirsizde)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h1 text; v_g1 uuid; v_h2 text; v_c2 uuid; v_tai uuid; v_h3 text; v_c3 uuid; v_g2 date[];
        v_e text; v_j jsonb; v_d2 jsonb; v_d3 jsonb; v_oz text; v_p jsonb;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h1 := pg_temp.kb_hayvan(); v_g1 := pg_temp.kb_ob_gorev(v_h1, v_b);
  v_h2 := pg_temp.kb_hayvan(); v_c2 := pg_temp.kb_ovsync_vaka(v_h2, v_b - 7);
  v_tai := pg_temp.kb_ovsync_tai(v_c2, v_b - 7);
  UPDATE public.gorev_log SET hedef_tarih = v_b - 2 WHERE id = v_tai;     -- tutarsız: açık TAI geçmişte → kaydırma GECMIS_TARIH
  v_h3 := pg_temp.kb_hayvan(); v_c3 := pg_temp.kb_ovsync_vaka(v_h3, v_b);
  PERFORM public.seans_tamamla(p_seans_admin_id := pg_temp.kb_seans_ekle(v_c3, 1));   -- gün#1 kısmi → aşama NULL
  PERFORM pg_temp.kb_ok(public._ovsync_asama(v_c3) IS NULL AND public._ovsync_asama(v_c2) = 1, 'TR-K7-5', 'fixture: aşama 1 + belirsiz', 'farklı');
  v_p := public.ovsync_tren_ertele_onizle(v_b, 1);
  PERFORM pg_temp.kb_ok(pg_temp.kb_plan_uye(v_p, v_h3)->'sonuc' = 'null'::jsonb AND pg_temp.kb_plan_uye(v_p, v_h3)->'asama' = 'null'::jsonb,
                        'TR-K7-5', 'önizleme: belirsiz üye sonuc NULL (onay açılmaz)', v_p::text);
  v_g2 := pg_temp.kb_gunler(v_c2);
  v_oz := pg_temp.kb_ozet();
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ertele(%L::date, 1)', v_b));
  v_j := pg_temp.kb_kod(v_e, 'OVSYNC_TREN_ERTELE_DUSTU');
  SELECT e.value INTO v_d2 FROM jsonb_array_elements(v_j->'dusenler') e WHERE e.value->>'hayvan_id' = v_h2;
  SELECT e.value INTO v_d3 FROM jsonb_array_elements(v_j->'dusenler') e WHERE e.value->>'hayvan_id' = v_h3;
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_j->'dusenler') = 2 AND v_d2->>'kupe_no' = v_h2 AND v_d2->>'sebep' LIKE '%GECMIS_TARIH%'
                        AND NOT v_d2 ? 'oneri',
                        'TR-K7-5', 'OVSYNC_TREN_ERTELE_DUSTU: aşama 1 vaka düştü (sebep GECMIS_TARIH), sorunsuz görev listede değil', v_e);
  PERFORM pg_temp.kb_ok(v_d3->>'sebep' LIKE 'OVSYNC_ASAMA_BELIRSIZ%' AND v_d3->>'oneri' = 'BASTAN_BASLAT_YA_DA_SEANS_ISARETLE'
                        AND v_d3->>'kupe_no' = v_h3,
                        'TR-K7-5', 'belirsiz üye: sebep OVSYNC_ASAMA_BELIRSIZ, oneri BASTAN_BASLAT_YA_DA_SEANS_ISARETLE (R6-EK)', v_d3::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_ozet() = v_oz AND pg_temp.kb_capa() = v_b AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g1) = v_b
                        AND pg_temp.kb_gunler(v_c2) = v_g2 AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c2) = v_b - 7,
                        'TR-K7-5', 'hepsi geri: görev X''te, vaka günleri/etiketi ve çapa önceki halinde (özet md5)', pg_temp.kb_capa()::text);
  RAISE NOTICE 'PASS TR-K7-5: kısmi başarı yok';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-KISMI: X'te D0 trenindeki 2 vakadan birinin gün#1'i yapılmış → onizle(X,1): yapılan aşama 1 KAYAR (PG1+1), yapılmayan aşama 0
--   KAYAR (X+1); onizle(X,3): yapılan BASTAN, yapılmayan KAYAR (X+3)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_ha text; v_ca uuid; v_hb text; v_p jsonb; v_u jsonb;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_ha := pg_temp.kb_hayvan(); v_ca := pg_temp.kb_ovsync_vaka(v_ha, v_b); PERFORM pg_temp.kb_seans_yap(v_ca, 1);
  v_hb := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_ovsync_vaka(v_hb, v_b);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 1);
  v_u := pg_temp.kb_plan_uye(v_p, v_ha);
  PERFORM pg_temp.kb_ok((v_u->>'asama')::int = 1 AND v_u->>'sonuc' = 'KAYAR' AND (v_u->>'yeni_tarih')::date = v_b + 8,
                        'TR-K7-KISMI', '+1: yapılan aşama 1, KAYAR → PG1 bugün+8', v_u::text);
  v_u := pg_temp.kb_plan_uye(v_p, v_hb);
  PERFORM pg_temp.kb_ok((v_u->>'asama')::int = 0 AND v_u->>'sonuc' = 'KAYAR' AND (v_u->>'yeni_tarih')::date = v_b + 1,
                        'TR-K7-KISMI', '+1: yapılmayan aşama 0, KAYAR → bugün+1', v_u::text);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 3);
  PERFORM pg_temp.kb_ok(pg_temp.kb_plan_uye(v_p, v_ha)->>'sonuc' = 'BASTAN' AND (pg_temp.kb_plan_uye(v_p, v_ha)->>'yeni_tarih')::date = v_b + 3
                        AND pg_temp.kb_plan_uye(v_p, v_hb)->>'sonuc' = 'KAYAR' AND (pg_temp.kb_plan_uye(v_p, v_hb)->>'yeni_tarih')::date = v_b + 3,
                        'TR-K7-KISMI', '+3: yapılan BASTAN → bugün+3, yapılmayan KAYAR → bugün+3', v_p->>'uyeler');
  RAISE NOTICE 'PASS TR-K7-KISMI: kısmi iş sonrası önizleme';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-HAFTA2: X treni 4 vaka, ikisinin GnRH1'i X'te yapılmış → ertele(X,1): dördünün ovsync_tren X+1; RL-16: onizle(X+8,1)
--   ONCEKI_TREN_VAR (ilk_tren X+1), onizle(X+1,1) kümesi dördünü içerir (yapılan 2'si aşama 1); listele dördünü tek başlık X+1 altında
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text[] := '{}'; v_c uuid[] := '{}'; v_i int; v_p jsonb; v_l jsonb;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  FOR v_i IN 1..4 LOOP
    v_h := v_h || pg_temp.kb_hayvan();
    v_c := v_c || pg_temp.kb_ovsync_vaka(v_h[v_i], v_b);
  END LOOP;
  PERFORM pg_temp.kb_seans_yap(v_c[1], 1);
  PERFORM pg_temp.kb_seans_yap(v_c[2], 1);
  PERFORM public.ovsync_tren_ertele(v_b, 1);
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM public.cases WHERE id = ANY(v_c) AND ovsync_tren = v_b + 1 AND status = 'active') = 4,
                        'TR-K7-HAFTA2', 'dört vakanın etiketi X+1', 'farklı');
  -- RL-16: X+1 treni (dördünün etiketi) bugünden sonra ilk üyeli tren → X+8 önizlemesi ONCEKI_TREN_VAR; dördü X+1 kümesinde
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(pg_temp.kb_hata(format('SELECT public.ovsync_tren_ertele_onizle(%L::date, 1)', v_b + 8)),
                                       'OVSYNC_TREN_GUNU_DEGIL')->>'ilk_tren' = (v_b + 1)::text,
                        'TR-K7-HAFTA2', 'onizle(X+8,1) → ONCEKI_TREN_VAR, ilk_tren X+1', 'farklı');
  v_p := public.ovsync_tren_ertele_onizle(v_b + 1, 1);
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM jsonb_array_elements(v_p->'uyeler') e WHERE e.value->>'hayvan_id' = ANY(v_h)) = 4
                        AND (pg_temp.kb_plan_uye(v_p, v_h[1])->>'asama')::int = 1 AND (pg_temp.kb_plan_uye(v_p, v_h[2])->>'asama')::int = 1
                        AND (pg_temp.kb_plan_uye(v_p, v_h[1])->>'ovsync_tren')::date = v_b + 1
                        AND (pg_temp.kb_plan_uye(v_p, v_h[3])->>'asama')::int = 0,
                        'TR-K7-HAFTA2', 'onizle(X+1,1) kümesi dördünü içerir (2 aşama 1, etiket X+1)', v_p->>'uyeler');
  v_l := public.ovsync_tren_listele();
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM jsonb_array_elements(v_l->'trenler') t, jsonb_array_elements(t.value->'uyeler') u
                          WHERE u.value->>'hayvan_id' = ANY(v_h) AND (t.value->>'tren_gunu')::date = v_b + 1
                            AND NOT (t.value->>'ritim_disi')::boolean) = 4,
                        'TR-K7-HAFTA2', 'listele: dördü tek başlık X+1 altında (ritimde)', v_l->>'trenler');
  RAISE NOTICE 'PASS TR-K7-HAFTA2: ertesi hafta toptan dördünü görür';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-N1 / TR-K7-N2: N ∉ 1..7 → OVSYNC_TREN_N_GECERSIZ; ritim dışı tarih → OVSYNC_TREN_GUNU_DEGIL; geçmiş → GECMIS_TARIH;
--   üyesiz → OVSYNC_TREN_BOS (hiç üyeli tren yokken; RL-16 sonrası önceki üyeli tren varsa ONCEKI_TREN_VAR, TR-K7-N3);
--   bayrak 0 → OVSYNC_TREN_KAPALI (önizleme ve erteleme; payload rpc çağıranın adı)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_e text; v_f text;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  FOREACH v_f IN ARRAY ARRAY['ovsync_tren_ertele_onizle', 'ovsync_tren_ertele'] LOOP
    v_e := pg_temp.kb_hata(format('SELECT public.%s(%L::date, 1)', v_f, v_b + 14));
    PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_TREN_BOS') IS NOT NULL, 'TR-K7-N2', v_f || ' üyesiz tren → OVSYNC_TREN_BOS', v_e);
  END LOOP;
  PERFORM pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b);
  FOREACH v_f IN ARRAY ARRAY['ovsync_tren_ertele_onizle', 'ovsync_tren_ertele'] LOOP
    v_e := pg_temp.kb_hata(format('SELECT public.%s(%L::date, 8)', v_f, v_b));
    PERFORM pg_temp.kb_ok((pg_temp.kb_kod(v_e, 'OVSYNC_TREN_N_GECERSIZ')->>'gun')::int = 8, 'TR-K7-N1', v_f || ' p_n=8 → OVSYNC_TREN_N_GECERSIZ', v_e);
    v_e := pg_temp.kb_hata(format('SELECT public.%s(%L::date, 0)', v_f, v_b));
    PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_TREN_N_GECERSIZ') IS NOT NULL, 'TR-K7-N1', v_f || ' p_n=0 → OVSYNC_TREN_N_GECERSIZ', v_e);
    v_e := pg_temp.kb_hata(format('SELECT public.%s(%L::date, 1)', v_f, v_b + 1));
    PERFORM pg_temp.kb_ok((pg_temp.kb_kod(v_e, 'OVSYNC_TREN_GUNU_DEGIL')->>'tarih')::date = v_b + 1, 'TR-K7-N2', v_f || ' ritim dışı → OVSYNC_TREN_GUNU_DEGIL', v_e);
    v_e := pg_temp.kb_hata(format('SELECT public.%s(%L::date, 1)', v_f, v_b - 7));
    PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'GECMIS_TARIH') IS NOT NULL, 'TR-K7-N2', v_f || ' geçmiş tren → GECMIS_TARIH', v_e);
  END LOOP;
  PERFORM pg_temp.kb_ok(pg_temp.kb_capa() = v_b, 'TR-K7-N2', 'red sonrası çapa değişmedi', pg_temp.kb_capa()::text);
  PERFORM pg_temp.kb_tren_kapat();
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ertele(%L::date, 1)', v_b));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_KAPALI%', 'TR-K7-N2', 'bayrak 0 → OVSYNC_TREN_KAPALI', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_TREN_KAPALI')->>'rpc' = 'ovsync_tren_ertele', 'TR-K7-N2', 'KAPALI payload rpc ovsync_tren_ertele', v_e);
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ertele_onizle(%L::date, 1)', v_b));
  PERFORM pg_temp.kb_ok(v_e LIKE 'P0001|OVSYNC_TREN_KAPALI%', 'TR-K7-N2', 'bayrak 0 önizleme → OVSYNC_TREN_KAPALI', v_e);
  PERFORM pg_temp.kb_ok(pg_temp.kb_kod(v_e, 'OVSYNC_TREN_KAPALI')->>'rpc' = 'ovsync_tren_ertele_onizle', 'TR-K7-N2',
                        'önizleme KAPALI payload rpc ovsync_tren_ertele_onizle (KÜÇÜK)', v_e);
  RAISE NOTICE 'PASS TR-K7-N1/TR-K7-N2: doğrulama';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-N3 (RL-16): toptan yalnız bugünden itibaren üyesi olan İLK ritim gününde; daha ileri X → OVSYNC_TREN_GUNU_DEGIL
--   {tarih, sebep:'ONCEKI_TREN_VAR', ilk_tren} (önizleme + erteleme), hiçbir şey değişmez. Üyelik sınıfları: (iii) etiket X−7 (bugün
--   treni), (i) görev, (ii) etiket. İlk tren üzerinde erteleme çalışır (pozitif kontrol).
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_e text; v_f text; v_j jsonb; v_oz text; v_t date;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b);
  PERFORM pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b - 7);             -- yalnız (iii): bugün treninin üyesi
  PERFORM pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b + 7);                -- X = bugün+7 üyesi
  PERFORM pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 14);            -- X = bugün+14 (ii) üyesi
  v_oz := pg_temp.kb_ozet();
  FOREACH v_f IN ARRAY ARRAY['ovsync_tren_ertele_onizle', 'ovsync_tren_ertele'] LOOP
    FOREACH v_t IN ARRAY ARRAY[v_b + 7, v_b + 14] LOOP
      v_e := pg_temp.kb_hata(format('SELECT public.%s(%L::date, 1)', v_f, v_t));
      v_j := pg_temp.kb_kod(v_e, 'OVSYNC_TREN_GUNU_DEGIL');
      PERFORM pg_temp.kb_ok(v_j->>'sebep' = 'ONCEKI_TREN_VAR' AND (v_j->>'ilk_tren')::date = v_b AND (v_j->>'tarih')::date = v_t,
                            'TR-K7-N3', format('%s(%s) → ONCEKI_TREN_VAR, ilk_tren bugün', v_f, v_t), v_e);
    END LOOP;
  END LOOP;
  PERFORM pg_temp.kb_ok(pg_temp.kb_ozet() = v_oz, 'TR-K7-N3', 'red sonrası hiçbir şey değişmedi (özet md5)', pg_temp.kb_capa()::text);
  PERFORM pg_temp.kb_ok((public.ovsync_tren_ertele(v_b, 1)->>'ok')::boolean, 'TR-K7-N3', 'ilk tren (bugün) ertelenebilir', 'hata');
  RAISE NOTICE 'PASS TR-K7-N3: önceki tren kapısı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-ILK-GELECEK (RL-16, root): bugün tren günü değil, üyeli ilk ritim günü gelecekte (çapa bugün+2) → o güne önizleme ve
--   ertele(X,1) başarılı; aynı fixture'da X+7 → ONCEKI_TREN_VAR (ilk_tren X)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_x date := pg_temp.kb_bugun() + 2; v_h text; v_g uuid; v_e text; v_f text; v_j jsonb; v_p jsonb; v_r jsonb;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_x);
  v_h := pg_temp.kb_hayvan(); v_g := pg_temp.kb_ob_gorev(v_h, v_x);
  PERFORM pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_x + 7);
  PERFORM pg_temp.kb_ok(NOT public._ovsync_tren_gunu_mu(v_b), 'TR-K7-ILK-GELECEK', 'fixture: bugün tren günü değil', 'tren günü');
  FOREACH v_f IN ARRAY ARRAY['ovsync_tren_ertele_onizle', 'ovsync_tren_ertele'] LOOP
    v_e := pg_temp.kb_hata(format('SELECT public.%s(%L::date, 1)', v_f, v_x + 7));
    v_j := pg_temp.kb_kod(v_e, 'OVSYNC_TREN_GUNU_DEGIL');
    PERFORM pg_temp.kb_ok(v_j->>'sebep' = 'ONCEKI_TREN_VAR' AND (v_j->>'ilk_tren')::date = v_x,
                          'TR-K7-ILK-GELECEK', v_f || '(X+7) → ONCEKI_TREN_VAR, ilk_tren X', v_e);
  END LOOP;
  v_p := public.ovsync_tren_ertele_onizle(v_x, 1);
  PERFORM pg_temp.kb_ok((v_p->>'ok')::boolean AND (pg_temp.kb_plan_uye(v_p, v_h)->>'yeni_tarih')::date = v_x + 1,
                        'TR-K7-ILK-GELECEK', 'onizle(X,1) başarılı, üye X+1', v_p::text);
  v_r := public.ovsync_tren_ertele(v_x, 1);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_x + 1 AND pg_temp.kb_capa() = v_x + 1,
                        'TR-K7-ILK-GELECEK', 'ertele(X,1) başarılı: görev X+1, çapa X+1', v_r::text);
  RAISE NOTICE 'PASS TR-K7-ILK-GELECEK: gelecekteki ilk tren';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-K7-ONIZLE: önizleme yazmaz (gorev_log/treatment_days/seans/cases/protokol_ayar/islem_log özeti md5 aynı)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_oz text; v_p jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_k7_fixture(v_b);
  v_oz := pg_temp.kb_ozet();
  v_p := public.ovsync_tren_ertele_onizle(v_b, 1);
  v_p := public.ovsync_tren_ertele_onizle(v_b, 3);
  PERFORM pg_temp.kb_ok(pg_temp.kb_ozet() = v_oz AND jsonb_array_length(v_p->'uyeler') = 3, 'TR-K7-ONIZLE', 'önizleme sonrası özet md5 aynı', 'değişti');
  RAISE NOTICE 'PASS TR-K7-ONIZLE: önizleme yazmaz';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-EK-ONIZLE-2: iki trenli küme (görev X = bugün+1, vaka etiketi X−7) → üye ovsync_tren, tren_sayisi 2; dokunulmaz: bağımsız 2
--   (K9 hastalık, X'te günü var), ritim dışı 1 (çapa değişmiş, etiket ritimde değil, X'te günü var); pg_pay/pg1_zaman alanları.
--   RL-16: X ilk üyeli ritim günü olmalı (önceki X = bugün+8 kurgusu bugün+1 treni yüzünden ONCEKI_TREN_VAR olur) → X = bugün+1.
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_hr text; v_hg text; v_cg uuid; v_ho text; v_hm text; v_p jsonb; v_u jsonb; v_x date := pg_temp.kb_bugun() + 1;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_hr := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_geri(pg_temp.kb_ovsync_vaka(v_hr, v_b), 7);   -- etiket b−7; günleri b−7, b, b+1, b+2
  PERFORM pg_temp.kb_tren_ac(v_x);                                                     -- çapa değişti → etiket b−7 ritim dışı
  v_hg := pg_temp.kb_hayvan(); v_cg := pg_temp.kb_ovsync_vaka(v_hg, v_x);
  PERFORM public.ovsync_hastalik_gunu_ekle(v_cg);                                       -- bağımsız
  PERFORM public.ovsync_hastalik_gunu_ekle(pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_x));   -- ikinci bağımsız (sayılar asimetrik)
  v_ho := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_ob_gorev(v_ho, v_x);                 -- sınıf (i)
  v_hm := pg_temp.kb_hayvan(); PERFORM pg_temp.kb_geri(pg_temp.kb_ovsync_vaka(v_hm, v_x), 7);   -- sınıf (iii), etiket X−7, aşama 0
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM public.treatment_days d WHERE d.case_id = v_cg AND d.treatment_date = v_x),
                        'TR-EK-ONIZLE-2', 'fixture: bağımsız vakanın X''te günü var', pg_temp.kb_gunler(v_cg)::text);
  v_p := public.ovsync_tren_ertele_onizle(v_x, 1);
  PERFORM pg_temp.kb_ok((v_p->>'tren_sayisi')::int = 2 AND (pg_temp.kb_plan_uye(v_p, v_ho)->>'ovsync_tren')::date = v_x
                        AND (pg_temp.kb_plan_uye(v_p, v_hm)->>'ovsync_tren')::date = v_x - 7 AND jsonb_array_length(v_p->'uyeler') = 2,
                        'TR-EK-ONIZLE-2', 'üye ovsync_tren (görev X, vaka X−7), tren_sayisi 2', v_p::text);
  PERFORM pg_temp.kb_ok(v_p->'dokunulmaz' = '{"bagimsiz": 2, "ritim_disi": 1}'::jsonb, 'TR-EK-ONIZLE-2', 'dokunulmaz {bagimsiz:2, ritim_disi:1}',
                        v_p->>'dokunulmaz');
  v_u := pg_temp.kb_plan_uye(v_p, v_hm);
  PERFORM pg_temp.kb_ok(v_u ? 'pg_pay' AND v_u ? 'pg1_zaman' AND v_u->'pg_pay' = 'null'::jsonb AND v_u->'pg1_zaman' = 'null'::jsonb,
                        'TR-EK-ONIZLE-2', 'uyeler pg_pay/pg1_zaman alanları (aşama 0 → NULL)', v_u::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_plan_uye(v_p, v_hr) IS NULL AND pg_temp.kb_plan_uye(v_p, v_hg) IS NULL, 'TR-EK-ONIZLE-2',
                        'dokunulmazlar kümede değil', v_p->>'uyeler');
  RAISE NOTICE 'PASS TR-EK-ONIZLE-2: önizleme sözleşme eki';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-EK-ONIZLE-2 (aşama 1 pg_pay önizlemede): KISMI fixture'ında yapılan vaka pg_pay 1
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_c uuid; v_u jsonb;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_h := pg_temp.kb_hayvan(); v_c := pg_temp.kb_ovsync_vaka(v_h, v_b); PERFORM pg_temp.kb_seans_yap(v_c, 1);
  v_u := pg_temp.kb_plan_uye(public.ovsync_tren_ertele_onizle(v_b, 1), v_h);
  PERFORM pg_temp.kb_ok((v_u->>'pg_pay')::int = 1 AND (v_u->>'ovsync_tren')::date = v_b AND v_u->'pg1_zaman' = 'null'::jsonb
                        AND NOT v_u ? 'sonraki_is', 'TR-EK-ONIZLE-2', 'aşama 1 üye: pg_pay 1, ovsync_tren X, pg1_zaman NULL', v_u::text);
  RAISE NOTICE 'PASS TR-EK-ONIZLE-2: aşama 1 pg_pay';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ACL-4: üç RPC anon kapalı, authenticated/service_role açık, SECDEF, tek overload; iki iç yardımcı authenticated'a da kapalı
SAVEPOINT kb_s;
DO $t$
DECLARE v_f text;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['public.ovsync_tren_listele()', 'public.ovsync_tren_ertele_onizle(date,integer)',
                             'public.ovsync_tren_ertele(date,integer,jsonb)'] LOOP
    PERFORM pg_temp.kb_ok(to_regprocedure(v_f) IS NOT NULL AND NOT has_function_privilege('anon', v_f, 'EXECUTE')
                          AND has_function_privilege('authenticated', v_f, 'EXECUTE') AND has_function_privilege('service_role', v_f, 'EXECUTE')
                          AND (SELECT prosecdef FROM pg_proc WHERE oid = to_regprocedure(v_f)),
                          'TR-ACL-4', v_f || ' anon kapalı, authenticated/service_role açık, SECDEF', 'yanlış');
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['public._ovsync_tren_ertele_plan(date,integer)', 'public._ovsync_tren_uye_vaka(uuid,integer)'] LOOP
    PERFORM pg_temp.kb_ok(to_regprocedure(v_f) IS NOT NULL AND NOT has_function_privilege('anon', v_f, 'EXECUTE')
                          AND NOT has_function_privilege('authenticated', v_f, 'EXECUTE'),
                          'TR-ACL-4', v_f || ' iç yardımcı: anon/authenticated kapalı', 'açık');
  END LOOP;
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                          AND proname IN ('ovsync_tren_listele', 'ovsync_tren_ertele_onizle', 'ovsync_tren_ertele',
                                          '_ovsync_tren_ertele_plan', '_ovsync_tren_uye_vaka')) = 5,
                        'TR-ACL-4', '5 imza, overload yok', 'fazla');
  RAISE NOTICE 'PASS TR-ACL-4: D7 ACL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- ════════════════════════════════════════════════════════════════════════════
-- D8 — Ayar ve göç (ovsync_tren_yeniden_hedefle, ovsync_tren_ayar_guncelle) + D3 review eki (TR-ANAH-2)
-- ════════════════════════════════════════════════════════════════════════════
-- Göç fixture'ı: X = p_x tren günü; ayar çapası X+1 (ayar_guncelle(true, X) çapayı değiştirir); bayrak 0. Açık OVSYNC_BASLAT'lar:
-- a kural geçmiş, hedef X+4 (tren dışı gün) → X+7 · b kural geçmiş, hedef bugün → X · c kural bugün+1, elle ileri X+10 → X+14
-- (kuralın treni X'e geri çekilmez) · d hedef X+7 (ritimde) → AYNI · e doğum tarihi yok → KURAL_YOK · f gecikmiş (bugün−1) → listede yok
CREATE FUNCTION pg_temp.kb_goc_fixture(p_x date) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE v jsonb := '{}'::jsonb; v_h text; k text;
BEGIN
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', to_char(p_x + 1, 'YYYYMMDD')::numeric);
  FOREACH k IN ARRAY ARRAY['a', 'b', 'd', 'e', 'f'] LOOP
    v_h := pg_temp.kb_hayvan();
    v := v || jsonb_build_object('h' || k, v_h, 'g' || k, pg_temp.kb_ob_gorev(v_h,
           CASE k WHEN 'a' THEN p_x + 4 WHEN 'b' THEN pg_temp.kb_bugun() WHEN 'd' THEN p_x + 7 WHEN 'e' THEN p_x + 1
                  ELSE pg_temp.kb_bugun() - 1 END));
  END LOOP;
  UPDATE public.hayvanlar SET dogum_tarihi = NULL WHERE id = v->>'he';
  v_h := pg_temp.kb_duve(pg_temp.kb_bugun() + 1);
  RETURN v || jsonb_build_object('hc', v_h, 'gc', pg_temp.kb_ob_gorev(v_h, p_x + 10));
END $f$;

-- yeniden_hedefle dönüşünde görevin satırı (yoksa NULL)
CREATE FUNCTION pg_temp.kb_goc_g(p_r jsonb, p_g text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT e FROM jsonb_array_elements(p_r->'gorevler') e WHERE e->>'gorev_id' = p_g
$f$;

-- TR-GOC-1: kuru liste (bayrak 0, p_capa X): R9 yeni + durum; gecikmiş görev yok; yazma yok; p_capa NULL → ayar çapası;
--           kuru değil + bayrak kapalı → OVSYNC_TREN_KAPALI
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_x date := pg_temp.kb_bugun() + 3; f jsonb; v_r jsonb; v_o text; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  f := pg_temp.kb_goc_fixture(v_x);
  v_o := pg_temp.kb_ozet();
  v_r := public.ovsync_tren_yeniden_hedefle(true, v_x);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'kuru')::boolean AND (v_r->>'capa')::date = v_x,
                        'TR-GOC-1', '{ok, kuru:true, capa X}', v_r::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>'ga') = jsonb_build_object('gorev_id', f->'ga', 'hayvan_id', f->'ha', 'kupe_no', f->'ha',
                          'eski', v_x + 4, 'yeni', v_x + 7, 'durum', 'TASINIR'),
                        'TR-GOC-1', 'a: tren dışı gün X+4 → X+7 TASINIR (öne çekme ≤2 X''e yetmez)', COALESCE(pg_temp.kb_goc_g(v_r, f->>'ga')::text, '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>'gb') @> jsonb_build_object('eski', v_b, 'yeni', v_x, 'durum', 'TASINIR'),
                        'TR-GOC-1', 'b: kural geçmiş, hedef bugün → ilk tren X', COALESCE(pg_temp.kb_goc_g(v_r, f->>'gb')::text, '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>'gc') @> jsonb_build_object('eski', v_x + 10, 'yeni', v_x + 14, 'durum', 'TASINIR'),
                        'TR-GOC-1', 'c: elle ileri X+10 → X+14 (kural treni X''e geri çekilmez)', COALESCE(pg_temp.kb_goc_g(v_r, f->>'gc')::text, '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>'gd') @> jsonb_build_object('eski', v_x + 7, 'yeni', v_x + 7, 'durum', 'AYNI'),
                        'TR-GOC-1', 'd: ritimde X+7 → AYNI', COALESCE(pg_temp.kb_goc_g(v_r, f->>'gd')::text, '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>'ge') @> jsonb_build_object('eski', v_x + 1, 'durum', 'KURAL_YOK')
                        AND pg_temp.kb_goc_g(v_r, f->>'ge')->'yeni' = 'null'::jsonb,
                        'TR-GOC-1', 'e: kural yok → KURAL_YOK, yeni null', COALESCE(pg_temp.kb_goc_g(v_r, f->>'ge')::text, '<yok>'));
  PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>'gf') IS NULL, 'TR-GOC-1', 'f: gecikmiş görev listede yok', pg_temp.kb_goc_g(v_r, f->>'gf')::text);
  PERFORM pg_temp.kb_ok(pg_temp.kb_ozet() = v_o, 'TR-GOC-1', 'kuru: yazma yok', 'değişti');
  v_r := public.ovsync_tren_yeniden_hedefle();
  PERFORM pg_temp.kb_ok((v_r->>'capa')::date = v_x + 1 AND (pg_temp.kb_goc_g(v_r, f->>'gb')->>'yeni')::date = v_x + 1
                        AND pg_temp.kb_ozet() = v_o,
                        'TR-GOC-1', 'varsayılan: kuru, ayar çapası X+1 → b yeni X+1, yazma yok', v_r::text);
  v_e := pg_temp.kb_hata('SELECT public.ovsync_tren_yeniden_hedefle(false)');
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_TREN_KAPALI:%' AND pg_temp.kb_ozet() = v_o, 'TR-GOC-1', 'kuru değil + bayrak 0 → OVSYNC_TREN_KAPALI', v_e);
  RAISE NOTICE 'PASS TR-GOC-1: kuru göç listesi';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-GOC-2: ayar_guncelle(true, X) → hedef_tarih = kuru yeni (birebir); GOREV_ERTELE soyu yalnız TASINIR'da; ayar satırları +
--           PROTOKOL_AYAR kaydı (protokol_ayar_guncelle snapshot'ı); iç bayrak geri yüklendi (K10 kilidi dışarıda sürer)
SAVEPOINT kb_s;
DO $t$
DECLARE v_x date := pg_temp.kb_bugun() + 3; f jsonb; v_k jsonb; v_r jsonb; v_y jsonb; k text; v_e text; v_s jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  f := pg_temp.kb_goc_fixture(v_x);
  v_k := public.ovsync_tren_yeniden_hedefle(true, v_x);
  v_r := public.ovsync_tren_ayar_guncelle(true, v_x);
  v_y := v_r->'yeniden_hedef';
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'aktif')::boolean AND (v_r->>'capa')::date = v_x
                        AND (v_y->>'kuru')::boolean = false AND (v_y->>'capa')::date = v_x,
                        'TR-GOC-2', '{ok, aktif:true, capa X, yeniden_hedef kuru:false}', v_r::text);
  FOREACH k IN ARRAY ARRAY['a', 'b', 'c', 'd'] LOOP
    PERFORM pg_temp.kb_ok((SELECT g.hedef_tarih FROM public.gorev_log g WHERE g.id = (f->>('g' || k))::uuid)
                            = (pg_temp.kb_goc_g(v_k, f->>('g' || k))->>'yeni')::date
                          AND pg_temp.kb_goc_g(v_y, f->>('g' || k)) = pg_temp.kb_goc_g(v_k, f->>('g' || k)),
                          'TR-GOC-2', k || ': hedef_tarih = kuru yeni; yazma dönüşü satırı = kuru satır',
                          format('%s / %s', pg_temp.kb_goc_g(v_y, f->>('g' || k)), pg_temp.kb_goc_g(v_k, f->>('g' || k))));
  END LOOP;
  PERFORM pg_temp.kb_ok((SELECT g.hedef_tarih FROM public.gorev_log g WHERE g.id = (f->>'ge')::uuid) = v_x + 1
                        AND (SELECT g.hedef_tarih FROM public.gorev_log g WHERE g.id = (f->>'gf')::uuid) = pg_temp.kb_bugun() - 1,
                        'TR-GOC-2', 'e (KURAL_YOK) ve f (gecikmiş) dokunulmaz', 'değişti');
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM public.islem_log l WHERE l.tip = 'GOREV_ERTELE'
                           AND l.ref_id IN (f->>'ga', f->>'gb', f->>'gc')) = 3
                        AND NOT EXISTS (SELECT 1 FROM public.islem_log l WHERE l.tip = 'GOREV_ERTELE' AND l.ref_id IN (f->>'gd', f->>'ge', f->>'gf'))
                        AND EXISTS (SELECT 1 FROM public.islem_log l WHERE l.tip = 'GOREV_ERTELE' AND l.ref_id = f->>'ga'
                                      AND (l.payload->>'eski_tarih')::date = v_x + 4 AND (l.payload->>'yeni_tarih')::date = v_x + 7),
                        'TR-GOC-2', 'GOREV_ERTELE soyu: a/b/c birer kayıt (a X+4→X+7), d/e/f yok', 'yanlış');
  PERFORM pg_temp.kb_ok((SELECT deger FROM public.protokol_ayar WHERE anahtar = 'ovsync_tren_aktif') = 1
                        AND pg_temp.kb_capa() = v_x AND public._ovsync_tren_aktif(), 'TR-GOC-2', 'ayar: aktif 1, çapa X', 'yanlış');
  SELECT jsonb_agg(l.snapshot || jsonb_build_object('not', l.kullanici_notu, 'ref_tablo', l.ref_tablo) ORDER BY l.snapshot->'guncellenen'->0->>'id')
    INTO v_s FROM public.islem_log l WHERE l.tip = 'PROTOKOL_AYAR';
  PERFORM pg_temp.kb_ok(v_s = jsonb_build_array(
      jsonb_build_object('olusturulan', '[]'::jsonb, 'silinen', '[]'::jsonb, 'not', 'Protokol ayarı: ovsync_tren_aktif', 'ref_tablo', 'protokol_ayar',
        'guncellenen', jsonb_build_array(jsonb_build_object('tablo', 'protokol_ayar', 'id', 'ovsync_tren_aktif',
          'onceki', jsonb_build_object('deger', 0), 'sonraki', jsonb_build_object('deger', 1)))),
      jsonb_build_object('olusturulan', '[]'::jsonb, 'silinen', '[]'::jsonb, 'not', 'Protokol ayarı: ovsync_tren_capa', 'ref_tablo', 'protokol_ayar',
        'guncellenen', jsonb_build_array(jsonb_build_object('tablo', 'protokol_ayar', 'id', 'ovsync_tren_capa',
          'onceki', jsonb_build_object('deger', to_char(v_x + 1, 'YYYYMMDD')::numeric),
          'sonraki', jsonb_build_object('deger', to_char(v_x, 'YYYYMMDD')::numeric))))),
    'TR-GOC-2', 'PROTOKOL_AYAR: aktif 0→1 ve çapa X+1→X, protokol_ayar_guncelle snapshot''ı', COALESCE(v_s::text, '<yok>'));
  v_e := pg_temp.kb_hata(format('SELECT public.gorev_ertele(%L::uuid, %L::date)', f->>'gd', v_x + 8));
  PERFORM pg_temp.kb_ok(NOT public._ovsync_ic_mi() AND v_e LIKE '%OVSYNC_TREN_EKRANI:%',
                        'TR-GOC-2', 'iç bayrak geri yüklendi: sonrasında Görevler ertelemesi kilitli', COALESCE(v_e, '<hata yok>'));
  RAISE NOTICE 'PASS TR-GOC-2: açılışta göç yazıldı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-GOC-3: RL-18 — açıkken aynı çapayla ayar_guncelle(true, X) göç koşmaz (yeniden_hedef null); idempotentlik doğrudan
--           yeniden_hedefle(false) ×2 ile → satırlar AYNI (e KURAL_YOK); yeni GOREV_ERTELE / PROTOKOL_AYAR kaydı yok
--           (değişmeyen ayar yazılmaz); açıkken çapa değişince (X+7) göç yine koşar
SAVEPOINT kb_s;
DO $t$
DECLARE v_x date := pg_temp.kb_bugun() + 3; f jsonb; v_a jsonb; v_r jsonb; v_r2 jsonb; k text; v_ge int; v_pa int;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  f := pg_temp.kb_goc_fixture(v_x);
  PERFORM public.ovsync_tren_ayar_guncelle(true, v_x);
  v_ge := (SELECT count(*) FROM public.islem_log WHERE tip = 'GOREV_ERTELE');
  v_pa := (SELECT count(*) FROM public.islem_log WHERE tip = 'PROTOKOL_AYAR');
  v_a := public.ovsync_tren_ayar_guncelle(true, v_x);
  PERFORM pg_temp.kb_ok((v_a->>'ok')::boolean AND (v_a->>'aktif')::boolean AND (v_a->>'capa')::date = v_x
                        AND v_a->'yeniden_hedef' = 'null'::jsonb,
                        'TR-GOC-3', 'RL-18: açıkken aynı çapa → {ok, aktif, capa X, yeniden_hedef:null} (göç yok)', v_a::text);
  v_r := public.ovsync_tren_yeniden_hedefle(false);
  v_r2 := public.ovsync_tren_yeniden_hedefle(false);
  FOREACH k IN ARRAY ARRAY['a', 'b', 'c', 'd'] LOOP
    PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>('g' || k))->>'durum' = 'AYNI' AND pg_temp.kb_goc_g(v_r2, f->>('g' || k))->>'durum' = 'AYNI',
                          'TR-GOC-3', k || ': doğrudan yeniden_hedefle(false) ×2 → AYNI', format('%s / %s', pg_temp.kb_goc_g(v_r, f->>('g' || k)), pg_temp.kb_goc_g(v_r2, f->>('g' || k))));
  END LOOP;
  PERFORM pg_temp.kb_ok(pg_temp.kb_goc_g(v_r, f->>'ge')->>'durum' = 'KURAL_YOK' AND v_r->'gorevler' = v_r2->'gorevler',
                        'TR-GOC-3', 'e KURAL_YOK; iki çağrının listesi aynı', format('%s / %s', v_r->'gorevler', v_r2->'gorevler'));
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM public.islem_log WHERE tip = 'GOREV_ERTELE') = v_ge
                        AND (SELECT count(*) FROM public.islem_log WHERE tip = 'PROTOKOL_AYAR') = v_pa,
                        'TR-GOC-3', 'yeni GOREV_ERTELE/PROTOKOL_AYAR kaydı yok', 'yazıldı');
  v_a := public.ovsync_tren_ayar_guncelle(true, v_x + 7);
  PERFORM pg_temp.kb_ok(jsonb_typeof(v_a->'yeniden_hedef') = 'object' AND (v_a->'yeniden_hedef'->>'kuru')::boolean = false
                        AND (v_a->'yeniden_hedef'->>'capa')::date = v_x + 7 AND pg_temp.kb_capa() = v_x + 7,
                        'TR-GOC-3', 'RL-18: açıkken çapa X→X+7 → göç koşar (yeniden_hedef kuru:false, capa X+7)', v_a::text);
  RAISE NOTICE 'PASS TR-GOC-3: idempotent';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-GOC-4: D0'ı ritimde aktif OVSYNC vaka (ovsync_tren NULL) → uyelik'te ve kolon dolu; hastalık günlü / ritim dışı / etiketli dolmaz
SAVEPOINT kb_s;
DO $t$
DECLARE v_x date := pg_temp.kb_bugun() + 3; v_h1 text; v_h4 text; c1 uuid; c2 uuid; c3 uuid; c4 uuid; v_k jsonb; v_r jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h1 := pg_temp.kb_hayvan(); c1 := pg_temp.kb_ovsync_vaka(v_h1, v_x);
  c2 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_x); PERFORM public.ovsync_hastalik_gunu_ekle(c2);
  c3 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_x + 1);
  v_h4 := pg_temp.kb_hayvan(); c4 := pg_temp.kb_ovsync_vaka(v_h4, v_x - 7);
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM public.cases WHERE id IN (c1, c2, c3, c4) AND ovsync_tren IS NULL) = 4
                        AND EXISTS (SELECT 1 FROM public.treatment_days d WHERE d.case_id = c2 AND d.disease_id IS NOT NULL),
                        'TR-GOC-4', 'fixture: bayrak 0 → dört vaka etiketsiz, c2 hastalık günlü', 'yanlış');
  v_k := public.ovsync_tren_yeniden_hedefle(true, v_x);
  PERFORM pg_temp.kb_ok(v_k->'uyelik' @> jsonb_build_array(jsonb_build_object('case_id', c1, 'hayvan_id', v_h1, 'tren', v_x),
                                                           jsonb_build_object('case_id', c4, 'hayvan_id', v_h4, 'tren', v_x - 7))
                        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_k->'uyelik') e WHERE (e->>'case_id')::uuid IN (c2, c3))
                        AND (SELECT count(*) FROM public.cases WHERE id IN (c1, c4) AND ovsync_tren IS NULL) = 2,
                        'TR-GOC-4', 'kuru uyelik: c1 (X), c4 (X−7); c2 hastalık, c3 ritim dışı yok; kolon yazılmadı', v_k->>'uyelik');
  v_r := public.ovsync_tren_ayar_guncelle(true, v_x)->'yeniden_hedef';
  PERFORM pg_temp.kb_ok((SELECT ovsync_tren FROM public.cases WHERE id = c1) = v_x AND (SELECT ovsync_tren FROM public.cases WHERE id = c4) = v_x - 7
                        AND (SELECT count(*) FROM public.cases WHERE id IN (c2, c3) AND ovsync_tren IS NULL) = 2
                        AND v_r->'uyelik' @> jsonb_build_array(jsonb_build_object('case_id', c1, 'hayvan_id', v_h1, 'tren', v_x)),
                        'TR-GOC-4', 'açılış: c1 = X, c4 = X−7 yazıldı; c2/c3 NULL', v_r->>'uyelik');
  v_r := public.ovsync_tren_yeniden_hedefle(false);
  PERFORM pg_temp.kb_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_r->'uyelik') e WHERE (e->>'case_id')::uuid IN (c1, c2, c3, c4)),
                        'TR-GOC-4', 'etiketli vaka ikinci çağrıda uyelik''te yok', v_r->>'uyelik');
  RAISE NOTICE 'PASS TR-GOC-4: R14 üyelik';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-GOC-5 (R6-EK, root SORU-3): belirsiz aşamalı aktif OVSYNC vakaları {case_id, hayvan_id, kupe_no} + belirsiz_sayisi (kuru ve yazma)
SAVEPOINT kb_s;
DO $t$
DECLARE v_x date := pg_temp.kb_bugun() + 3; v_h5 text; c5 uuid; c6 uuid; v_k jsonb; v_r jsonb;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h5 := pg_temp.kb_hayvan(); c5 := pg_temp.kb_ovsync_vaka(v_h5, pg_temp.kb_bugun());
  PERFORM pg_temp.kb_seans_yap(c5, 2);
  c6 := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), pg_temp.kb_bugun());
  PERFORM pg_temp.kb_ok(public._ovsync_asama(c5) IS NULL AND public._ovsync_asama(c6) = 0, 'TR-GOC-5', 'fixture: c5 belirsiz, c6 aşama 0', 'yanlış');
  v_k := public.ovsync_tren_yeniden_hedefle(true, v_x);
  PERFORM pg_temp.kb_ok(v_k->'belirsiz_asama' @> jsonb_build_array(jsonb_build_object('case_id', c5, 'hayvan_id', v_h5, 'kupe_no', v_h5))
                        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_k->'belirsiz_asama') e WHERE (e->>'case_id')::uuid = c6)
                        AND (v_k->>'belirsiz_sayisi')::int = jsonb_array_length(v_k->'belirsiz_asama'),
                        'TR-GOC-5', 'kuru: c5 listede (case_id, hayvan_id, kupe_no), c6 yok, sayı = liste', v_k::text);
  v_r := public.ovsync_tren_ayar_guncelle(true, v_x)->'yeniden_hedef';
  PERFORM pg_temp.kb_ok(v_r->'belirsiz_asama' = v_k->'belirsiz_asama' AND v_r->'belirsiz_sayisi' = v_k->'belirsiz_sayisi',
                        'TR-GOC-5', 'yazma dönüşünde de aynı belirsiz listesi', v_r::text);
  RAISE NOTICE 'PASS TR-GOC-5: belirsiz aşama sayımı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-GOC-6 (RL-18, D8 T2 ÖNEMLİ): açılıştan sonra bağımsız başlatılan vaka (ovsync_tren NULL) gün#1'i tren gününe düşse de
--           aynı çapayla ayar_guncelle(true, X) onu trene bağlamaz (göç + üyelik yalnız açılışta / çapa değişiminde)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_x date := pg_temp.kb_bugun() + 3; v_h text; v_g uuid; v_c uuid; v_r jsonb; r record;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_r := public.ovsync_tren_ayar_guncelle(true, v_x);                    -- açılış (0→1)
  PERFORM pg_temp.kb_ok(public._ovsync_tren_aktif() AND jsonb_typeof(v_r->'yeniden_hedef') = 'object',
                        'TR-GOC-6', 'açılış: bayrak 1, göç koştu', v_r::text);
  v_h := pg_temp.kb_hayvan();
  v_g := pg_temp.kb_ob_gorev(v_h, v_x);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);   -- bugün tren değil → D0 bugün, etiket NULL
  v_c := (v_r->>'case_id')::uuid;
  PERFORM public.ovsync_hayvan_ertele(v_h, 3);                           -- aşama 0 bağımsız: serbest +3 → gün#1 = X (tren günü)
  SELECT * INTO r FROM pg_temp.kb_vaka_d0(v_c);
  PERFORM pg_temp.kb_ok(r.gun1 = v_x AND r.ovsync_tren IS NULL AND public._ovsync_tren_gunu_mu(r.gun1),
                        'TR-GOC-6', 'fixture: bağımsız vaka gün#1 = X (tren günü), ovsync_tren NULL', format('%s %s', r.gun1, r.ovsync_tren));
  v_r := public.ovsync_tren_ayar_guncelle(true, v_x);                    -- açıkken aynı çapa
  PERFORM pg_temp.kb_ok(v_r->'yeniden_hedef' = 'null'::jsonb AND (SELECT ovsync_tren FROM public.cases WHERE id = v_c) IS NULL,
                        'TR-GOC-6', 'aynı çapa: yeniden_hedef null, bağımsız vaka ovsync_tren NULL kalır',
                        format('%s / %s', v_r, (SELECT ovsync_tren FROM public.cases WHERE id = v_c)));
  RAISE NOTICE 'PASS TR-GOC-6: bağımsız vaka aynı çapada trene bağlanmaz';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-AYAR-P1: ayar_guncelle(false, NULL) → bayrak 0, çapa ve görev hedefleri değişmez, yeniden_hedef null, PROTOKOL_AYAR 1→0;
--             (false, X+1) çapayı yazar, yeniden hedeflemez; bozuk ayarda da kapanır (hızlı geri)
SAVEPOINT kb_s;
DO $t$
DECLARE v_x date := pg_temp.kb_bugun() + 3; v_g uuid; v_r jsonb; v_s jsonb; v_e text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_x);
  v_g := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_x + 4);
  v_r := public.ovsync_tren_ayar_guncelle(false, NULL);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'aktif')::boolean = false AND (v_r->>'capa')::date = v_x
                        AND v_r->'yeniden_hedef' = 'null'::jsonb,
                        'TR-AYAR-P1', '{ok, aktif:false, capa X, yeniden_hedef:null}', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT deger FROM public.protokol_ayar WHERE anahtar = 'ovsync_tren_aktif') = 0 AND pg_temp.kb_capa() = v_x
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_x + 4
                        AND NOT EXISTS (SELECT 1 FROM public.islem_log WHERE tip = 'GOREV_ERTELE'),
                        'TR-AYAR-P1', 'bayrak 0, çapa X, görev X+4 (tren dışı) değişmedi', 'değişti');
  SELECT jsonb_agg(l.snapshot->'guncellenen') INTO v_s FROM public.islem_log l WHERE l.tip = 'PROTOKOL_AYAR';
  PERFORM pg_temp.kb_ok(v_s = jsonb_build_array(jsonb_build_array(jsonb_build_object('tablo', 'protokol_ayar', 'id', 'ovsync_tren_aktif',
                          'onceki', jsonb_build_object('deger', 1), 'sonraki', jsonb_build_object('deger', 0)))),
                        'TR-AYAR-P1', 'tek PROTOKOL_AYAR kaydı: aktif 1→0', COALESCE(v_s::text, '<yok>'));
  v_r := public.ovsync_tren_ayar_guncelle(false, v_x + 1);
  PERFORM pg_temp.kb_ok((v_r->>'capa')::date = v_x + 1 AND pg_temp.kb_capa() = v_x + 1 AND v_r->'yeniden_hedef' = 'null'::jsonb
                        AND (SELECT hedef_tarih FROM public.gorev_log WHERE id = v_g) = v_x + 4,
                        'TR-AYAR-P1', 'kapalıyken çapa X+1 yazılır, görev yeniden hedeflenmez', v_r::text);
  PERFORM pg_temp.kb_tren_ac(v_x);
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);
  v_r := public.ovsync_tren_ayar_guncelle(false, NULL);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND NOT public._ovsync_tren_aktif() AND v_r->'capa' = 'null'::jsonb,
                        'TR-AYAR-P1', 'bozuk çapada da kapanır (hızlı geri), capa null', v_r::text);
  -- D8 T2 KÜÇÜK: çapa satırı silinmiş + kapat → ok, aktif 0 (kapatma eksik çapa satırında da çalışır)
  PERFORM pg_temp.kb_tren_ac(v_x);
  DELETE FROM public.protokol_ayar WHERE anahtar = 'ovsync_tren_capa';
  v_e := pg_temp.kb_hata('SELECT public.ovsync_tren_ayar_guncelle(false, NULL)');
  PERFORM pg_temp.kb_ok(v_e IS NULL AND NOT public._ovsync_tren_aktif()
                        AND (SELECT deger FROM public.protokol_ayar WHERE anahtar = 'ovsync_tren_aktif') = 0,
                        'TR-AYAR-P1', 'çapa satırı silinmiş + kapat → ok, aktif 0', COALESCE(v_e, '<hata yok>'));
  v_r := public.ovsync_tren_ayar_guncelle(false, NULL);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'aktif')::boolean = false AND v_r->'capa' = 'null'::jsonb,
                        'TR-AYAR-P1', 'çapa satırı yokken kapatma dönüşü {ok, aktif:false, capa:null}', v_r::text);
  RAISE NOTICE 'PASS TR-AYAR-P1: kapatma';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-AYAR-N3: (true, NULL) ve (NULL, X) → OVSYNC_TREN_AYAR; açılışta öne çekme ayarı bozuksa OVSYNC_TREN_AYAR, bayrak 0 kalır
SAVEPOINT kb_s;
DO $t$
DECLARE v_x date := pg_temp.kb_bugun() + 3; v_e text; v_o text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_o := pg_temp.kb_ozet();
  v_e := pg_temp.kb_hata('SELECT public.ovsync_tren_ayar_guncelle(true, NULL)');
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_TREN_AYAR:%ovsync_tren_capa%' AND pg_temp.kb_ozet() = v_o,
                        'TR-AYAR-N3', '(true, NULL) → OVSYNC_TREN_AYAR (çapa), yazma yok', COALESCE(v_e, '<hata yok>'));
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ayar_guncelle(NULL, %L::date)', v_x));
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_TREN_AYAR:%ovsync_tren_aktif%' AND pg_temp.kb_ozet() = v_o,
                        'TR-AYAR-N3', '(NULL, X) → OVSYNC_TREN_AYAR (aktif), yazma yok', COALESCE(v_e, '<hata yok>'));
  PERFORM pg_temp.kb_ayar('ovsync_tren_one_cekme_gun', 5);
  v_o := pg_temp.kb_ozet();
  v_e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ayar_guncelle(true, %L::date)', v_x));
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_TREN_AYAR:%ovsync_tren_one_cekme_gun%' AND pg_temp.kb_ozet() = v_o
                        AND NOT public._ovsync_tren_aktif(),
                        'TR-AYAR-N3', 'öne çekme 5 → açılış OVSYNC_TREN_AYAR, bayrak 0 kalır (spec §7)', COALESCE(v_e, '<hata yok>'));
  RAISE NOTICE 'PASS TR-AYAR-N3: eksik/bozuk ayar';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-AYAR-N5 (D2 review): çapa 20260101..20991231 dışı → OVSYNC_TREN_AYAR ARALIK_DISI; sınırlar kabul
SAVEPOINT kb_s;
DO $t$
DECLARE v_e text; v_e2 text; v_r jsonb; v_o text;
BEGIN
  PERFORM pg_temp.kb_tren_kapat();
  v_o := pg_temp.kb_ozet();
  v_e := pg_temp.kb_hata('SELECT public.ovsync_tren_ayar_guncelle(false, ''2025-12-31''::date)');
  v_e2 := pg_temp.kb_hata('SELECT public.ovsync_tren_ayar_guncelle(false, ''2100-01-01''::date)');
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_TREN_AYAR:%ARALIK_DISI%' AND v_e2 LIKE '%OVSYNC_TREN_AYAR:%ARALIK_DISI%' AND pg_temp.kb_ozet() = v_o,
                        'TR-AYAR-N5', '2025-12-31 ve 2100-01-01 → ARALIK_DISI, yazma yok', format('%s / %s', v_e, v_e2));
  v_r := public.ovsync_tren_ayar_guncelle(false, '2026-01-01');
  PERFORM pg_temp.kb_ok(pg_temp.kb_capa() = '2026-01-01', 'TR-AYAR-N5', 'alt sınır 2026-01-01 kabul', v_r::text);
  v_r := public.ovsync_tren_ayar_guncelle(false, '2099-12-31');
  PERFORM pg_temp.kb_ok(pg_temp.kb_capa() = '2099-12-31', 'TR-AYAR-N5', 'üst sınır 2099-12-31 kabul', v_r::text);
  RAISE NOTICE 'PASS TR-AYAR-N5: çapa aralığı';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-AYAR-CRON: bayrak 1 + çapa bozuk → ilk_tohumlama_zamanlayici() ve ovsync_tren_listele() OVSYNC_TREN_AYAR ile düşer (sessiz başarı yok);
--               bayrak 0'da aynı bozuk çapa cron'u düşürmez (ayar okunmaz)
SAVEPOINT kb_s;
DO $t$
DECLARE v_e text; v_e2 text;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_tren_ac(pg_temp.kb_bugun() + 3);
  PERFORM pg_temp.kb_ayar('ovsync_tren_capa', 20261131);
  PERFORM pg_temp.kb_hayvan();
  v_e := pg_temp.kb_hata('SELECT public.ilk_tohumlama_zamanlayici()');
  v_e2 := pg_temp.kb_hata('SELECT public.ovsync_tren_listele()');
  PERFORM pg_temp.kb_ok(v_e LIKE '%OVSYNC_TREN_AYAR:%TARIH_GECERSIZ%' AND v_e2 LIKE '%OVSYNC_TREN_AYAR:%',
                        'TR-AYAR-CRON', 'cron ve listele OVSYNC_TREN_AYAR', format('%s / %s', COALESCE(v_e, '<hata yok>'), COALESCE(v_e2, '<hata yok>')));
  PERFORM pg_temp.kb_tren_kapat();
  v_e := pg_temp.kb_hata('SELECT public.ilk_tohumlama_zamanlayici()');
  PERFORM pg_temp.kb_ok(v_e IS NULL, 'TR-AYAR-CRON', 'bayrak 0: bozuk çapa cron''u düşürmez', v_e);
  RAISE NOTICE 'PASS TR-AYAR-CRON: bozuk ayar sessiz geçmez';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ANAH-2 (D3 review): iki tohumlamalı hayvanda R10 anahtarı SON tohumlamanın (tarih DESC) id'siyle biter
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_h text; v_t uuid; v_t0 uuid; v_r jsonb; v_k text;
BEGIN
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_h := pg_temp.kb_duve(v_b - 30);
  v_t := pg_temp.kb_toh_bekliyor(v_h, v_b - 5);
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_h, v_b - 20, 'Boş', 'KB-SP') RETURNING id INTO v_t0;
  v_r := public.tohumlama_bos_ve_devam(p_tohumlama_id => v_t::text, p_secim => 'OVSYNC');
  v_k := (SELECT g.kaynak FROM public.gorev_log g WHERE g.id = (v_r->>'ovsync_gorev_id')::uuid);
  PERFORM pg_temp.kb_ok(v_k = format('ACIK-DISI-%s-%s-%s', v_h, v_b - 30, v_t) AND v_k NOT LIKE '%' || v_t0::text,
                        'TR-ANAH-2', 'kaynak son tohumlama (bugün−5) id''siyle biter, önceki (bugün−20) değil', COALESCE(v_k, v_r::text));
  RAISE NOTICE 'PASS TR-ANAH-2: R10 son tohumlama sırası';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-ACL-5: iki RPC anon kapalı, authenticated/service_role açık, SECDEF, search_path sabit, tek overload
SAVEPOINT kb_s;
DO $t$
DECLARE v_f text;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['public.ovsync_tren_yeniden_hedefle(boolean,date)', 'public.ovsync_tren_ayar_guncelle(boolean,date)'] LOOP
    PERFORM pg_temp.kb_ok(to_regprocedure(v_f) IS NOT NULL AND NOT has_function_privilege('anon', v_f, 'EXECUTE')
                          AND has_function_privilege('authenticated', v_f, 'EXECUTE') AND has_function_privilege('service_role', v_f, 'EXECUTE')
                          AND (SELECT prosecdef AND proconfig @> ARRAY['search_path=public, pg_temp'] FROM pg_proc WHERE oid = to_regprocedure(v_f)),
                          'TR-ACL-5', v_f || ' anon kapalı, authenticated/service_role açık, SECDEF, search_path', 'yanlış');
  END LOOP;
  PERFORM pg_temp.kb_ok((SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                          AND proname IN ('ovsync_tren_yeniden_hedefle', 'ovsync_tren_ayar_guncelle')) = 2,
                        'TR-ACL-5', '2 imza, overload yok', 'fazla');
  RAISE NOTICE 'PASS TR-ACL-5: D8 ACL';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM D9 — Bağımsız vaka işareti cases.ovsync_bagimsiz (K8/K9; RD9-1..6)
-- Değişmez: bayrak açıkken başlatılan/etiketlenen aktif OVSYNC vakada ovsync_tren IS NULL ⇔ ovsync_bagimsiz.
-- ════════════════════════════════════════════════════════════════════════════
-- Vakanın (ovsync_tren, ovsync_bagimsiz) çifti. Kolon jsonb üzerinden okunur: kolon yokken (RED) senaryo kb_ok FAIL'iyle düşer.
CREATE FUNCTION pg_temp.kb_bag(p_case uuid) RETURNS TABLE (tren date, bag boolean) LANGUAGE sql STABLE AS $f$
  SELECT c.ovsync_tren, (to_jsonb(c)->>'ovsync_bagimsiz')::boolean FROM public.cases c WHERE c.id = p_case
$f$;

-- TR-BAG-1: açık, bugün tren günü değil, start_first_service_protocol(p_bagimsiz=>true) → ovsync_tren NULL, işaret true
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_g uuid; v_r jsonb; r record;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_g := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b + 3);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  SELECT * INTO r FROM pg_temp.kb_bag((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND r.tren IS NULL AND r.bag IS TRUE, 'TR-BAG-1',
                        'bağımsız başlatma: ovsync_tren NULL, ovsync_bagimsiz true', format('%s %s %s', r.tren, r.bag, v_r));
  RAISE NOTICE 'PASS TR-BAG-1: bağımsız başlatma işaretlenir';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-BAG-2: TR-BAG-1 vakası; çapa değişir ve vakanın D0'ı (bugün) yeni ritme düşer → ayar_guncelle göçü onu bağlamaz;
--           doğrudan yeniden_hedefle(false) da bağlamaz (uyelik listesinde de yok)
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_g uuid; v_c uuid; v_r jsonb; r record;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_g := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b + 3);
  v_c := (public.start_first_service_protocol(v_g, p_bagimsiz => true)->>'case_id')::uuid;
  v_r := public.ovsync_tren_ayar_guncelle(true, v_b + 7);               -- çapa değişir; bugün = yeni ritim günü
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(public._ovsync_tren_gunu_mu(v_b) AND jsonb_typeof(v_r->'yeniden_hedef') = 'object'
                        AND r.tren IS NULL AND r.bag IS TRUE, 'TR-BAG-2',
                        'çapa değişimi (D0 yeni ritimde): göç koştu, ovsync_tren NULL, işaret true', format('%s %s %s', r.tren, r.bag, v_r));
  v_r := public.ovsync_tren_yeniden_hedefle(false);
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(r.tren IS NULL AND r.bag IS TRUE
                        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_r->'uyelik') e WHERE (e->>'case_id')::uuid = v_c),
                        'TR-BAG-2', 'doğrudan yeniden_hedefle(false): NULL + true, uyelik dışı', format('%s %s %s', r.tren, r.bag, v_r));
  RAISE NOTICE 'PASS TR-BAG-2: bağımsız vaka çapa değişiminde trene bağlanmaz';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-BAG-3: K9 — trendeki vakaya hastalık günü → ovsync_tren NULL + işaret true; sonra çapa değişimi → NULL kalır
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c uuid; v_r jsonb; r record;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_tren_ac(v_b + 2);
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 2);
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(r.tren = v_b + 2 AND r.bag IS FALSE, 'TR-BAG-3', 'fixture: trende (bugün+2), işaret false',
                        format('%s %s', r.tren, r.bag));
  v_r := public.ovsync_hastalik_gunu_ekle(v_c);
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(v_r->'tren_ayrildi' = 'true'::jsonb AND r.tren IS NULL AND r.bag IS TRUE, 'TR-BAG-3',
                        'hastalık günü: tren_ayrildi, ovsync_tren NULL, işaret true', format('%s %s %s', r.tren, r.bag, v_r));
  v_r := public.ovsync_tren_ayar_guncelle(true, v_b + 9);               -- çapa değişir (aynı ritim sınıfı, göç koşar)
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(jsonb_typeof(v_r->'yeniden_hedef') = 'object' AND r.tren IS NULL AND r.bag IS TRUE, 'TR-BAG-3',
                        'çapa değişimi sonrası NULL + true', format('%s %s %s', r.tren, r.bag, v_r));
  RAISE NOTICE 'PASS TR-BAG-3: K9 hastalık günü bağımsız işaretler';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-BAG-4: regresyon — bayrak kapalıyken açılmış eski vaka (işaret false, D0 = bugün+2) → açılışta (çapa bugün+2) trene bağlanır
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c uuid; v_r jsonb; r record;
BEGIN
  PERFORM set_config('app.ovsync_tren_ic', '', true);
  PERFORM pg_temp.kb_ertele_kural();
  PERFORM pg_temp.kb_ayar('ovsync_pg_kurallari_aktif', 1);
  PERFORM pg_temp.kb_tren_kapat();
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 2);
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(r.tren IS NULL AND r.bag IS FALSE, 'TR-BAG-4', 'bayrak 0 vaka: NULL, işaret false', format('%s %s', r.tren, r.bag));
  v_r := public.ovsync_tren_ayar_guncelle(true, v_b + 2);               -- açılış (0→1)
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(r.tren = v_b + 2 AND r.bag IS FALSE
                        AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_r->'yeniden_hedef'->'uyelik') e WHERE (e->>'case_id')::uuid = v_c),
                        'TR-BAG-4', 'açılış: eski vaka trene bağlandı (bugün+2), işaret false', format('%s %s %s', r.tren, r.bag, v_r));
  RAISE NOTICE 'PASS TR-BAG-4: eski vaka açılışta bağlanır';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-BAG-5: R4 — bugün tren günü + p_bagimsiz=>true → trende (bugün), işaret false
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_g uuid; v_r jsonb; r record;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b);
  v_g := pg_temp.kb_ob_gorev(pg_temp.kb_hayvan(), v_b);
  v_r := public.start_first_service_protocol(v_g, p_bagimsiz => true);
  SELECT * INTO r FROM pg_temp.kb_bag((v_r->>'case_id')::uuid);
  PERFORM pg_temp.kb_ok(r.tren = v_b AND r.bag IS FALSE, 'TR-BAG-5', 'tren günü bağımsız: ovsync_tren bugün, işaret false',
                        format('%s %s %s', r.tren, r.bag, v_r));
  RAISE NOTICE 'PASS TR-BAG-5: tren günü bağımsız trene biner';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- TR-BAG-6: V3 yolu (create_case + tedavi_sablon_uygula), açık: tren olmayan D0 → NULL + true; tren D0 → etiket, false
SAVEPOINT kb_s;
DO $t$
DECLARE v_b date := pg_temp.kb_bugun(); v_c uuid; r record;
BEGIN
  PERFORM pg_temp.kb_tren_ac(v_b + 3);
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 1);
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(r.tren IS NULL AND r.bag IS TRUE, 'TR-BAG-6', 'V3 tren dışı D0: NULL + true', format('%s %s', r.tren, r.bag));
  v_c := pg_temp.kb_ovsync_vaka(pg_temp.kb_hayvan(), v_b + 3);
  SELECT * INTO r FROM pg_temp.kb_bag(v_c);
  PERFORM pg_temp.kb_ok(r.tren = v_b + 3 AND r.bag IS FALSE, 'TR-BAG-6', 'V3 tren D0: etiket bugün+3, false', format('%s %s', r.tren, r.bag));
  RAISE NOTICE 'PASS TR-BAG-6: V3 yolu işaret';
END $t$;
ROLLBACK TO SAVEPOINT kb_s;

-- ════════════════════════════════════════════════════════════════════════════
-- ÖZET (son satır)
-- ════════════════════════════════════════════════════════════════════════════
DO $t$
BEGIN
  RAISE NOTICE 'OZET: % PASS', currval('pg_temp.kb_gecti_seq');
END $t$;
