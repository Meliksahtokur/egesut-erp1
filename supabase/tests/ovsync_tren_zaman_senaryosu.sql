-- ============================================================================
-- supabase/tests/ovsync_tren_zaman_senaryosu.sql — Ovsync treni ZAMAN SENARYOSU (DM1 / N6 eki madde 1, sahip onayı 2026-11-09)
-- Amaç: tekil kabul testlerinin görmediği "olaylar üst üste binince" hatalarını yakalamak. 5 hayvan, 3 haftalık takvim.
-- Koşum: ( echo 'BEGIN;'; cat <seri 001..008> supabase/tests/ovsync_tren_zaman_senaryosu.sql; echo 'ROLLBACK;' ) | psql … egesut_ovsync_kabul
--   Betik kendi BEGIN/COMMIT'ini taşımaz; yardımcıları kendisi kurar (ovsync_tren_kabul.sql kalıbı, kb_ok/kb_bugun aynı sözleşme).
-- Zaman ilerletme: now() işlem içinde sabittir, RPC'ler bugünü now()'dan okur. Bu yüzden "t gün ilerle" = senaryonun bütün tarihlerini
--   (görev, vaka, gün, seans, uygulama anı, PG olayı, protokol örneği) ve tren çapasını t gün GERİ almak (kb_geri kalıbının genellemesi).
--   D<k> = senaryonun k. günü; mutlak tarih zs_d(k) = kb_bugun() + k − geçen_gün. Her assert yanında kural kimliği (PLAN R*, spec K*, RL-*).
-- Hayvanlar: T1..T4 tren D0'a biner; B1 D1'de bağımsız başlar. Liste gösterimi: D<k>[ad:aşama,…] (! = ritim dışı) · B[…] bağımsızlar.
-- ============================================================================
\set QUIET on
SET LOCAL client_min_messages = notice;
DO $$ BEGIN PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000cafe', true); END $$;

CREATE TEMP SEQUENCE kb_gecti_seq;
CREATE FUNCTION pg_temp.kb_bugun() RETURNS date LANGUAGE sql STABLE AS $f$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $f$;
CREATE FUNCTION pg_temp.kb_ok(p_kosul boolean, p_test text, p_beklenen text, p_gercek text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_kosul IS NOT TRUE THEN RAISE EXCEPTION 'FAIL %: beklenen % gerçek %', p_test, p_beklenen, COALESCE(p_gercek, '<NULL>'); END IF;
  PERFORM nextval('pg_temp.kb_gecti_seq');
END $f$;
-- Eşitlik assert'i: beklenen/gerçek metin olarak raporlanır
CREATE FUNCTION pg_temp.zs_eq(p_test text, p_beklenen text, p_gercek text) RETURNS void LANGUAGE sql AS $f$
  SELECT pg_temp.kb_ok(p_gercek IS NOT DISTINCT FROM p_beklenen, p_test, p_beklenen, p_gercek) $f$;
CREATE FUNCTION pg_temp.kb_hata(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
BEGIN EXECUTE p_sql; RETURN NULL; EXCEPTION WHEN others THEN RETURN SQLSTATE || '|' || SQLERRM; END $f$;

-- Senaryo durumu: geçen gün + ad → hayvan eşlemesi
CREATE TEMP TABLE zs_saat (t int NOT NULL);
INSERT INTO zs_saat VALUES (0);
CREATE TEMP TABLE zs_hayvan (ad text PRIMARY KEY, id text NOT NULL, gorev uuid);
CREATE FUNCTION pg_temp.zs_d(p_k int) RETURNS date LANGUAGE sql STABLE AS $f$ SELECT pg_temp.kb_bugun() + p_k - (SELECT t FROM zs_saat) $f$;
CREATE FUNCTION pg_temp.zs_k(p_d date) RETURNS text LANGUAGE sql STABLE AS $f$ SELECT 'D' || (p_d - pg_temp.zs_d(0)) $f$;
CREATE FUNCTION pg_temp.zs_h(p_ad text) RETURNS text LANGUAGE sql STABLE AS $f$ SELECT id FROM zs_hayvan WHERE ad = p_ad $f$;
-- Hayvanın aktif OVSYNC vakası (tek olmalı)
CREATE FUNCTION pg_temp.zs_case(p_ad text) RETURNS uuid LANGUAGE sql STABLE AS $f$
  SELECT c.id FROM public.cases c WHERE c.animal_id = pg_temp.zs_h(p_ad) AND c.status = 'active' AND c.protocol_family = 'OVSYNC' $f$;
-- Aktif vakanın (D0, etiket, bağımsız) üçlüsü: "D0 D0 f" biçimi; vaka yoksa NULL
CREATE FUNCTION pg_temp.zs_bag(p_ad text) RETURNS text LANGUAGE sql STABLE AS $f$
  SELECT concat_ws(' ', pg_temp.zs_k(c.start_date), COALESCE(pg_temp.zs_k(c.ovsync_tren), '-'), c.ovsync_bagimsiz::text)
    FROM public.cases c WHERE c.id = pg_temp.zs_case(p_ad) $f$;
-- Açık görev hedefleri: tip başına D<k> listesi ("OB:D14 TAI:D9")
CREATE FUNCTION pg_temp.zs_gorev(p_ad text) RETURNS text LANGUAGE sql STABLE AS $f$
  SELECT COALESCE(string_agg(x, ' ' ORDER BY x), '') FROM (
    SELECT CASE g.gorev_tipi WHEN 'OVSYNC_BASLAT' THEN 'OB' ELSE 'TAI' END || ':' || string_agg(pg_temp.zs_k(g.hedef_tarih), ',' ORDER BY g.hedef_tarih) AS x
      FROM public.gorev_log g
     WHERE g.hayvan_id = pg_temp.zs_h(p_ad) AND g.gorev_tipi IN ('OVSYNC_BASLAT', 'TOHUMLAMA_PLANLI')
       AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
     GROUP BY g.gorev_tipi) y $f$;
-- ovsync_tren_listele'nin senaryo hayvanlarına süzülmüş özeti
CREATE FUNCTION pg_temp.zs_liste() RETURNS text LANGUAGE plpgsql AS $f$
DECLARE l jsonb := public.ovsync_tren_listele(); v_t text; v_b text;
BEGIN
  SELECT string_agg(x.s, ' ' ORDER BY x.d) INTO v_t FROM (
    SELECT (t.value->>'tren_gunu')::date AS d,
           pg_temp.zs_k((t.value->>'tren_gunu')::date) || CASE WHEN (t.value->>'ritim_disi')::boolean THEN '!' ELSE '' END
             || '[' || string_agg(z.ad || ':' || COALESCE(u.value->>'asama', '?'), ',' ORDER BY z.ad) || ']' AS s
      FROM jsonb_array_elements(l->'trenler') t, jsonb_array_elements(t.value->'uyeler') u JOIN zs_hayvan z ON z.id = u.value->>'hayvan_id'
     GROUP BY t.value) x;
  SELECT 'B[' || COALESCE(string_agg(z.ad || ':' || COALESCE(u.value->>'asama', '?'), ',' ORDER BY z.ad), '') || ']' INTO v_b
    FROM jsonb_array_elements(l->'bagimsizlar') u JOIN zs_hayvan z ON z.id = u.value->>'hayvan_id';
  RETURN concat_ws(' ', v_t, v_b);
END $f$;
-- Hayvan + açık OVSYNC_BASLAT görevi (hedef D<k>)
CREATE FUNCTION pg_temp.zs_hayvan_ekle(p_ad text, p_hedef_k int) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE v text := 'ZS-' || p_ad || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 8); v_g uuid;
BEGIN
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, dogum_tarihi, durum, irk, kisir)
  VALUES (v, v, 'Dişi', pg_temp.kb_bugun() - 1500, 'Aktif', 'Holstein', false);
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, kaynak)
  VALUES (v, 'OVSYNC_BASLAT', 'zs ovsync başlat', pg_temp.zs_d(p_hedef_k), 'ZS-OB-' || v) RETURNING id INTO v_g;
  INSERT INTO zs_hayvan VALUES (p_ad, v, v_g);
END $f$;
-- Vakanın hastalık-dışı gün#k seanslarını seans_tamamla ile kapatır; son dönüş (ovsync_uyari burada)
CREATE FUNCTION pg_temp.zs_seans(p_ad text, p_gun_sira int) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE v_s uuid; v_r jsonb; v_c uuid := pg_temp.zs_case(p_ad);
BEGIN
  FOR v_s IN SELECT u.id FROM public.treatment_day_uygulamalar u
              WHERE u.treatment_day_id = (SELECT d.id FROM public.treatment_days d WHERE d.case_id = v_c AND d.disease_id IS NULL
                                           ORDER BY d.treatment_date, d.day_no OFFSET p_gun_sira - 1 LIMIT 1)
                AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false) ORDER BY u.planned_time LOOP
    v_r := public.seans_tamamla(p_seans_admin_id := v_s, p_not := 'zs');
    IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN RAISE EXCEPTION 'FIXTURE: seans_tamamla % %', p_ad, v_r; END IF;
  END LOOP;
  IF v_r IS NULL THEN RAISE EXCEPTION 'FIXTURE: zs_seans % gün#% açık seans yok', p_ad, p_gun_sira; END IF;
  RETURN v_r;
END $f$;
-- Zamanı p_n gün ilerletir: senaryonun bütün tarihleri ve çapa p_n gün geri (bugün sabit kalır)
CREATE FUNCTION pg_temp.zs_ilerle(p_n int) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE i interval := make_interval(days => p_n);
BEGIN
  UPDATE public.gorev_log SET hedef_tarih = hedef_tarih - p_n, created_at = created_at - i, tamamlanma_tarihi = tamamlanma_tarihi - i
   WHERE hayvan_id IN (SELECT id FROM zs_hayvan);
  UPDATE public.treatment_days SET treatment_date = treatment_date - p_n, tamamlanma_tarihi = tamamlanma_tarihi - i, created_at = created_at - i
   WHERE case_id IN (SELECT c.id FROM public.cases c WHERE c.animal_id IN (SELECT id FROM zs_hayvan));
  UPDATE public.treatment_day_uygulamalar SET planned_date = planned_date - p_n, uygulama_tamamlandi_at = uygulama_tamamlandi_at - i,
         created_at = created_at - i
   WHERE case_id IN (SELECT c.id FROM public.cases c WHERE c.animal_id IN (SELECT id FROM zs_hayvan));
  UPDATE public.cases SET start_date = start_date - p_n, ovsync_tren = ovsync_tren - p_n, closed_at = closed_at - i, created_at = created_at - i
   WHERE animal_id IN (SELECT id FROM zs_hayvan);
  UPDATE public.protokol_instance SET baslangic = baslangic - p_n, created_at = created_at - i, kapandi_at = kapandi_at - i
   WHERE hayvan_id IN (SELECT id FROM zs_hayvan);
  UPDATE public.pg_application_event SET occurred_at = occurred_at - i, created_at = created_at - i WHERE hayvan_id IN (SELECT id FROM zs_hayvan);
  UPDATE public.protokol_ayar SET deger = to_char(to_date(deger::bigint::text, 'YYYYMMDD') - p_n, 'YYYYMMDD')::numeric
   WHERE anahtar = 'ovsync_tren_capa';
  UPDATE zs_saat SET t = t + p_n;
  PERFORM set_config('app.ovsync_tren_ic', '', true);   -- iç bayrak adım dışına sızmasın (R5)
END $f$;

DO $t$
DECLARE r jsonb; e text; v_c uuid; v_t1 uuid; v_t2 uuid; v_t4 uuid; v_b1 uuid;
BEGIN
  -- ══ HAZIRLIK (t=0): gorev_ertele kuralları (kabul DB verisiz; prod satırları), Ovsync-PG bayrağı, 5 hayvan ══
  INSERT INTO public.gorev_ertele_kural (gorev_tipi, ertelenebilir, pencere_kurali, max_erteleme_gun, asimi_uyari_gun, zincir_tetikler)
  SELECT v.t, v.e, v.p, NULL, 7, v.z
    FROM (VALUES ('OVSYNC_BASLAT', true, 'tohumlama', '{"tai_ofset_gun": 10}'::jsonb), ('TOHUMLAMA_PLANLI', true, 'tohumlama', '{}'::jsonb),
                 ('TEDAVI_GUN', false, 'yok', '{}'::jsonb), ('TEDAVI_SEANS', false, 'yok', '{}'::jsonb)) AS v(t, e, p, z)
   WHERE NOT EXISTS (SELECT 1 FROM public.gorev_ertele_kural k WHERE k.gorev_tipi = v.t);
  UPDATE public.protokol_ayar SET deger = 1 WHERE anahtar = 'ovsync_pg_kurallari_aktif';
  PERFORM pg_temp.zs_hayvan_ekle(a, 0) FROM unnest(ARRAY['T1', 'T2', 'T3', 'T4', 'B1']) a;
  -- Tren açılır, çapa D0 (bugün): görevler zaten tren gününde → göç taşımaz
  r := public.ovsync_tren_ayar_guncelle(true, pg_temp.zs_d(0));
  PERFORM pg_temp.zs_eq('ZS-0a', 'true D0', concat_ws(' ', r->>'aktif', pg_temp.zs_k((r->>'capa')::date)));                -- R1, K1
  PERFORM pg_temp.zs_eq('ZS-0b', '0', (SELECT count(*)::text FROM jsonb_array_elements(r->'yeniden_hedef'->'gorevler') g
                                          WHERE g->>'hayvan_id' IN (SELECT id FROM zs_hayvan) AND g->>'durum' = 'TASINIR'));  -- R9 (hedef zaten tren günü: AYNI)
  PERFORM pg_temp.zs_eq('ZS-0c', 'D0[B1:0,T1:0,T2:0,T3:0,T4:0] B[]', pg_temp.zs_liste());                                  -- R16, K3

  -- ══ HAFTA 1 ══
  -- E1 (D0, tren günü = bugün): T1..T4 ▶ Başlat → soru yok, trene biner (R4); GnRH1 yapılır → aşama 1 (R6)
  FOR r IN SELECT public.start_first_service_protocol((SELECT gorev FROM zs_hayvan WHERE ad = a))
             FROM unnest(ARRAY['T1', 'T2', 'T3', 'T4']) a LOOP
    PERFORM pg_temp.zs_eq('ZS-1a', 'D0', pg_temp.zs_k((r->>'ovsync_tren')::date));                                          -- R3, R4
  END LOOP;
  PERFORM pg_temp.zs_seans(a, 1) FROM unnest(ARRAY['T1', 'T2', 'T3', 'T4']) a;
  PERFORM pg_temp.zs_eq('ZS-1b', 'D0 D0 false', pg_temp.zs_bag('T2'));                                                     -- R3
  PERFORM pg_temp.zs_eq('ZS-1c', 'TAI:D10', pg_temp.zs_gorev('T1'));                                                      -- K1 (D0+10 TAI), §18.2
  PERFORM pg_temp.zs_eq('ZS-1d', 'D0[B1:0,T1:1,T2:1,T3:1,T4:1] B[]', pg_temp.zs_liste());                                 -- R6, R16

  -- E2 (D1, tren günü değil): B1 "Bağımsız başlat — bugün" → D0=D1, etiket yok, bağımsız işareti (K8, R4, D9)
  PERFORM pg_temp.zs_ilerle(1);
  r := public.start_first_service_protocol((SELECT gorev FROM zs_hayvan WHERE ad = 'B1'), p_bagimsiz => true);
  PERFORM pg_temp.zs_seans('B1', 1);
  PERFORM pg_temp.zs_eq('ZS-2a', 'D1 - true', pg_temp.zs_bag('B1'));                                                       -- K8, R4, D9 RD9-3a
  PERFORM pg_temp.zs_eq('ZS-2b', 'TAI:D11', pg_temp.zs_gorev('B1'));                                                      -- K8 (bağımsız D0 bugün)
  PERFORM pg_temp.zs_eq('ZS-2c', 'D0[T1:1,T2:1,T3:1,T4:1] B[B1:1]', pg_temp.zs_liste());                                  -- K8 (trene sayılmaz)

  -- E3 (D3): T3'e hastalık günü → trenden ayrılır, bağımsız (K9); açık TAI 7 gün ötelenir (§18.18)
  PERFORM pg_temp.zs_ilerle(2);
  r := public.ovsync_hastalik_gunu_ekle(pg_temp.zs_case('T3'));
  PERFORM pg_temp.zs_eq('ZS-3a', 'true', r->>'tren_ayrildi');                                                              -- K9
  PERFORM pg_temp.zs_eq('ZS-3b', 'D0 - true', pg_temp.zs_bag('T3'));                                                       -- K9, R3, D9 RD9-3b
  PERFORM pg_temp.zs_eq('ZS-3c', 'TAI:D17', pg_temp.zs_gorev('T3'));                                                      -- §18.18 (TAI +7)
  PERFORM pg_temp.zs_eq('ZS-3d', 'D0[T1:1,T2:1,T4:1] B[B1:1,T3:1]', pg_temp.zs_liste());                                  -- K9

  -- ══ HAFTA 2 ══
  -- E4 (D7, ritim günü: D0 treninin PG1 günü): T1 PG1 zamanında → aşama 2, uyarı yok; PG+48 TAI şablon TAI'sinin yerine (§18.6)
  PERFORM pg_temp.zs_ilerle(4);
  r := pg_temp.zs_seans('T1', 2);
  PERFORM pg_temp.kb_ok(NOT r ? 'ovsync_uyari', 'ZS-4a', 'gecikme 0 → ovsync_uyari yok', r::text);                         -- R13, K11
  PERFORM pg_temp.zs_eq('ZS-4b', 'TAI:D9', pg_temp.zs_gorev('T1'));                                                       -- §18.6 (PG+48, son PG kazanır)
  PERFORM pg_temp.zs_eq('ZS-4c', 'D0[T1:2,T2:1,T4:1] B[B1:1,T3:1]', pg_temp.zs_liste());                                  -- R6
  -- Toptan önizleme: tren gününü 1 hafta (N=7) ertele, X=D7 = bugünden itibaren ilk ritim günü (RL-16)
  r := public.ovsync_tren_ertele_onizle(pg_temp.zs_d(7), 7);
  PERFORM pg_temp.zs_eq('ZS-4d', 'T1:SECIM:- T2:BASTAN:D14 T4:BASTAN:D14',
    (SELECT string_agg(z.ad || ':' || (u->>'sonuc') || ':' || COALESCE(pg_temp.zs_k((u->>'yeni_tarih')::date), '-'), ' ' ORDER BY z.ad)
       FROM jsonb_array_elements(r->'uyeler') u JOIN zs_hayvan z ON z.id = u->>'hayvan_id'));                              -- R7, K5, K6, R18, RL-15
  PERFORM pg_temp.zs_eq('ZS-4e', '1', r->'dokunulmaz'->>'bagimsiz');                                                      -- R7 (bağımsız dokunulmaz: T3'ün D7 günü var)
  -- Aşama 2 üyesi seçimsiz → hiçbir şey yazılmaz (K6, spec §7)
  e := pg_temp.kb_hata(format('SELECT public.ovsync_tren_ertele(%L::date, 7)', pg_temp.zs_d(7)));
  PERFORM pg_temp.kb_ok(e LIKE 'P0001|OVSYNC_TREN_SECIM_EKSIK:%' AND e LIKE '%' || pg_temp.zs_case('T1') || '%', 'ZS-4f',
                        'OVSYNC_TREN_SECIM_EKSIK (T1)', e);                                                                -- K6, K7
  PERFORM pg_temp.zs_eq('ZS-4g', 'D0', pg_temp.zs_k((SELECT to_date(deger::bigint::text, 'YYYYMMDD') FROM public.protokol_ayar
                                                      WHERE anahtar = 'ovsync_tren_capa')));                                -- K7 (kısmi yazma yok)
  -- T1 için (a) PG1+48 s tohumla seçilir → onay
  v_t1 := pg_temp.zs_case('T1'); v_t2 := pg_temp.zs_case('T2'); v_t4 := pg_temp.zs_case('T4');
  r := public.ovsync_tren_ertele(pg_temp.zs_d(7), 7, jsonb_build_object(v_t1, 'PG48'));
  PERFORM pg_temp.zs_eq('ZS-4h', 'D14', pg_temp.zs_k((SELECT to_date(deger::bigint::text, 'YYYYMMDD') FROM public.protokol_ayar
                                                       WHERE anahtar = 'ovsync_tren_capa')));                               -- K7 (çapa += N)
  PERFORM pg_temp.zs_eq('ZS-4i', 'TAI:D9', pg_temp.zs_gorev('T1'));                                                       -- K6(a), R12 (PG+48 TAI kalır)
  PERFORM pg_temp.zs_eq('ZS-4j', '0', (SELECT count(*)::text FROM public.treatment_day_uygulamalar u
                                        WHERE u.case_id = v_t1 AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)));  -- K6(a): kalan günler kapandı
  PERFORM pg_temp.zs_eq('ZS-4k', 'IPTAL IPTAL', (SELECT string_agg(c.close_reason, ' ' ORDER BY c.id) FROM public.cases c
                                                  WHERE c.id IN (v_t2, v_t4) AND c.status <> 'active'));                    -- K5, §18.9 (baştan = iptal)
  PERFORM pg_temp.zs_eq('ZS-4l', 'OB:D14', pg_temp.zs_gorev('T2'));                                                       -- RL-15 (BASTAN hedefi X+N, başlatılmaz)
  PERFORM pg_temp.zs_eq('ZS-4m', 'OB:D14', pg_temp.zs_gorev('T4'));                                                       -- RL-15
  PERFORM pg_temp.zs_eq('ZS-4n', 'TAI:D17 | TAI:D11', pg_temp.zs_gorev('T3') || ' | ' || pg_temp.zs_gorev('B1'));          -- R7 (bağımsızlar dokunulmaz)
  PERFORM pg_temp.zs_eq('ZS-4o', 'D0 - true | D1 - true', pg_temp.zs_bag('T3') || ' | ' || pg_temp.zs_bag('B1'));          -- R7, K9

  -- E5 (D8): T3 (hastalıklı, bağımsız) PG1'i 1 gün geç → tolerans içi, uyarı yok (K5 tolerans 1, R13)
  PERFORM pg_temp.zs_ilerle(1);
  r := pg_temp.zs_seans('T3', 2);
  PERFORM pg_temp.kb_ok(NOT r ? 'ovsync_uyari', 'ZS-5a', 'gecikme 1 ≤ tolerans 1 → uyarı yok', r::text);                  -- K5, R13
  -- E6 (D10): B1 PG1'i (plan D8) 2 gün geç → K11 uyarısı; karar: baştan başlat, bağımsız (bugün)
  PERFORM pg_temp.zs_ilerle(2);
  r := pg_temp.zs_seans('B1', 2);
  PERFORM pg_temp.zs_eq('ZS-6a', 'PG1_TOLERANS_ASILDI 2 BASTAN_BASLAT', concat_ws(' ', r->'ovsync_uyari'->>'kod',
                          r->'ovsync_uyari'->>'gecikme_gun', r->'ovsync_uyari'->>'oneri'));                                -- K11, R13
  v_b1 := pg_temp.zs_case('B1');
  r := public.ovsync_bastan_baslat(v_b1, p_bagimsiz => true);
  PERFORM pg_temp.zs_eq('ZS-6b', 'IPTAL', (SELECT close_reason FROM public.cases WHERE id = v_b1 AND status <> 'active'));  -- K5, K11 (baştan = iptal)
  PERFORM pg_temp.zs_eq('ZS-6c', 'D10 - true', pg_temp.zs_bag('B1'));                                                      -- R4 (bağımsız: bugün), D9
  PERFORM pg_temp.zs_seans('B1', 1);
  PERFORM pg_temp.zs_eq('ZS-6d', 'D0[T1:2] D14[T2:0,T4:0] B[B1:1,T3:2]', pg_temp.zs_liste());                              -- R7, R16, K9

  -- ══ HAFTA 3 ══
  -- E7 (D14, ritim günü): T2, T4 yeni görevleriyle trene biner (tren = bugün, R4)
  PERFORM pg_temp.zs_ilerle(4);
  PERFORM public.start_first_service_protocol((SELECT gorev_id FROM (SELECT g.id AS gorev_id FROM public.gorev_log g
            WHERE g.hayvan_id = pg_temp.zs_h(a) AND g.gorev_tipi = 'OVSYNC_BASLAT' AND NOT g.tamamlandi AND NOT g.iptal) x))
    FROM unnest(ARRAY['T2', 'T4']) a;
  PERFORM pg_temp.zs_seans(a, 1) FROM unnest(ARRAY['T2', 'T4']) a;
  PERFORM pg_temp.zs_eq('ZS-7a', 'D14 D14 false', pg_temp.zs_bag('T4'));                                                   -- R3, R4
  PERFORM pg_temp.zs_eq('ZS-7b', 'TAI:D24', pg_temp.zs_gorev('T2'));                                                      -- K1
  -- E8 (D15): tren çapası değişir → yeni ritim D3+7k (B1'in D0'ı D10 bu ritimde); bağımsız trene GİRMEZ (D9 RD9-4, R14)
  PERFORM pg_temp.zs_ilerle(1);
  r := public.ovsync_tren_ayar_guncelle(true, pg_temp.zs_d(17));
  PERFORM pg_temp.zs_eq('ZS-8a', '0', (SELECT count(*)::text FROM jsonb_array_elements(r->'yeniden_hedef'->'uyelik') u
                                        WHERE u->>'case_id' IN (SELECT c.id::text FROM public.cases c JOIN zs_hayvan z ON z.id = c.animal_id)));  -- R14, D9
  PERFORM pg_temp.zs_eq('ZS-8b', 'D10 - true', pg_temp.zs_bag('B1'));                                                       -- D9 RD9-4
  PERFORM pg_temp.zs_eq('ZS-8c', 'D14 D14 false', pg_temp.zs_bag('T2'));                                                   -- R3 (etiket korunur)
  PERFORM pg_temp.zs_eq('ZS-8d', 'D0![T1:2] D14![T2:1,T4:1] B[B1:1,T3:2]', pg_temp.zs_liste());                            -- R7 (ritim dışı başlık)
  -- Çapa yeniden D0 ritmine (D21): hastalıklı T3'ün D0'ı ritimde ama trene GİRMEZ (K9, R14 hastalık günsüz, D9)
  r := public.ovsync_tren_ayar_guncelle(true, pg_temp.zs_d(21));
  PERFORM pg_temp.zs_eq('ZS-8e', 'D0 - true', pg_temp.zs_bag('T3'));                                                        -- K9, R14, D9
  PERFORM pg_temp.zs_eq('ZS-8f', 'D0[T1:2] D14[T2:1,T4:1] B[B1:1,T3:2]', pg_temp.zs_liste());                              -- R7, K3
END $t$;

DO $$ BEGIN RAISE NOTICE 'OZET % PASS', (SELECT last_value FROM pg_temp.kb_gecti_seq); END $$;
