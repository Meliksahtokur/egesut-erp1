-- Migration: Ovsync treni — tren listesi ve toptan erteleme (ovsync treni D7)
-- Tarih: 2026-11-09. Spec docs/plans/2026-11-09-ovsync-tren/design.md (K3, K4–K7, §5, §7); PLAN.md D7, R3/R7/R9/R16/R18;
--   progress.md RL-1 (etiket yalnız vaka_kalan_gunleri_kaydir içinde artar), RL-12 (K6 a/b dışlaması: BASTAN/PG48 üyeleri D6
--   RPC'leriyle işlenir), R6-EK (belirsiz aşama düşüşüne öneri), sözleşme eki 2026-11-09 (pg_pay, ritim_disi_neden, pg1_zaman,
--   ovsync_tren, tren_sayisi, dokunulmaz). Önceki migration: 20261110100006. BEGIN/COMMIT yok. Prod apply sahip kapısında.
-- Yalnız YENİ nesne (mevcut gövde değişmez → md5 koruması yok):
--   _ovsync_tren_uye_vaka(case, tolerans) iç, _ovsync_tren_ertele_plan(tarih, n) iç,
--   ovsync_tren_listele(), ovsync_tren_ertele_onizle(tarih, n), ovsync_tren_ertele(tarih, n, secimler) RPC.
-- Bayrak (ovsync_tren_aktif) 0 iken: listele {aktif:false} döner, önizleme/erteleme OVSYNC_TREN_KAPALI; başka hiçbir yol değişmez.
-- Tarih yalnız TR: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ROLLBACK: DROP FUNCTION public.ovsync_tren_ertele(date,integer,jsonb), public.ovsync_tren_ertele_onizle(date,integer),
--   public.ovsync_tren_listele(), public._ovsync_tren_ertele_plan(date,integer), public._ovsync_tren_uye_vaka(uuid,integer).

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- 1) Vaka üye satırı (liste + plan tek tanım): {hayvan_id, kupe_no, case_id, gorev_id:null, asama, ovsync_tren,
--    sonraki_is:{tarih, saat, tur}, pg_pay, pg1_zaman}. sonraki_is = açık seansı olan ilk hastalık-dışı gün (sıra → GNRH1/PG1/PG2/
--    GNRH2), yoksa açık TOHUMLAMA_PLANLI (TAI). pg_pay (sözleşme eki) = aşama 1'de tolerans − _ovsync_pg1_kayma (ham, kırpmasız),
--    aksi NULL. pg1_zaman = gün#2'nin tüm seansları uygulandıysa en geç uygulama anı, aksi NULL. İç '_kayma' (= _ovsync_pg1_kayma,
--    satır başına bir kez; D7 tur 2 KÜÇÜK) yalnız çağıranlar içindir — dışa dönen satırdan çıkarılır.
CREATE FUNCTION public._ovsync_tren_uye_vaka(p_case_id uuid, p_tolerans integer)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_c     record;
  v_asama smallint := public._ovsync_asama(p_case_id);
  v_d     record;
  v_si    jsonb;
  v_pg1   timestamptz;
  v_kayma integer := public._ovsync_pg1_kayma(p_case_id);
BEGIN
  SELECT c.animal_id, c.ovsync_tren, COALESCE(h.kupe_no, c.animal_id) AS kupe_no INTO v_c
    FROM public.cases c LEFT JOIN public.hayvanlar h ON h.id = c.animal_id WHERE c.id = p_case_id;
  SELECT g.sira, g.treatment_date, g.saat INTO v_d
    FROM (SELECT row_number() OVER (ORDER BY d.treatment_date, d.day_no) AS sira, d.treatment_date, d.tamamlandi,
                 (SELECT min(u.planned_time) FROM public.treatment_day_uygulamalar u
                   WHERE u.treatment_day_id = d.id AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)) AS saat
            FROM public.treatment_days d WHERE d.case_id = p_case_id AND d.disease_id IS NULL) g
   WHERE g.saat IS NOT NULL AND NOT COALESCE(g.tamamlandi, false)
   ORDER BY g.sira LIMIT 1;
  IF FOUND THEN
    v_si := jsonb_build_object('tarih', v_d.treatment_date, 'saat', v_d.saat,
                               'tur', (ARRAY['GNRH1', 'PG1', 'PG2', 'GNRH2'])[v_d.sira]);
  ELSE
    SELECT jsonb_build_object('tarih', g.hedef_tarih, 'saat', g.hedef_saat, 'tur', 'TAI') INTO v_si
      FROM public.gorev_log g
     WHERE g.hayvan_id = v_c.animal_id AND g.gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
     ORDER BY g.hedef_tarih, g.hedef_saat NULLS LAST LIMIT 1;
  END IF;
  SELECT CASE WHEN count(*) > 0 AND count(u.uygulama_tamamlandi_at) = count(*) THEN max(u.uygulama_tamamlandi_at) END INTO v_pg1
    FROM public.treatment_day_uygulamalar u
   WHERE u.treatment_day_id = (SELECT d.id FROM public.treatment_days d WHERE d.case_id = p_case_id AND d.disease_id IS NULL
                                ORDER BY d.treatment_date, d.day_no OFFSET 1 LIMIT 1);
  RETURN jsonb_build_object('hayvan_id', v_c.animal_id, 'kupe_no', v_c.kupe_no, 'case_id', p_case_id, 'gorev_id', NULL,
    'asama', v_asama, 'ovsync_tren', v_c.ovsync_tren, 'sonraki_is', v_si,
    'pg_pay', CASE WHEN v_asama = 1 THEN p_tolerans - v_kayma END, 'pg1_zaman', v_pg1, '_kayma', v_kayma);
END;
$function$;

-- 2) ovsync_tren_listele (K3, R16): trenler = ovsync_tren'e göre gruplanmış aktif OVSYNC vakaları + hedefe göre açık OVSYNC_BASLAT
--    (hedef ≤ bugün+28; ötesi ileri_sayisi). Üyesiz tren üretilmez (gruplar üyeden doğar). Ritim dışı: tren ≢ çapa (mod 7);
--    ritim dışı trende üyeye ritim_disi_neden (sözleşme eki). Bağımsızlar: ovsync_tren NULL aktif OVSYNC vakalar (K9 dahil).
CREATE FUNCTION public.ovsync_tren_listele()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bugun  date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_ayar   jsonb;
  v_capa   date;
  v_tol    integer;
  v_tr     jsonb;
  v_bag    jsonb;
  v_ileri  integer;
BEGIN
  IF NOT public._ovsync_tren_aktif() THEN
    RETURN jsonb_build_object('ok', true, 'aktif', false, 'capa', NULL, 'bugun', v_bugun,
                              'trenler', '[]'::jsonb, 'bagimsizlar', '[]'::jsonb, 'ileri_sayisi', 0);
  END IF;
  v_ayar := public._ovsync_tren_ayar();
  v_capa := (v_ayar->>'capa')::date;
  v_tol  := (v_ayar->>'tolerans')::int;

  WITH u AS (
    SELECT g.hedef_tarih AS tren,
           jsonb_build_object('hayvan_id', g.hayvan_id, 'kupe_no', COALESCE(h.kupe_no, g.hayvan_id), 'case_id', NULL,
             'gorev_id', g.id, 'asama', 0, 'ovsync_tren', g.hedef_tarih, 'pg_pay', NULL, 'pg1_zaman', NULL,
             'sonraki_is', jsonb_build_object('tarih', g.hedef_tarih, 'saat', g.hedef_saat, 'tur', 'GNRH1'),
             'ritim_disi_neden', CASE WHEN ((g.hedef_tarih - v_capa) % 7 + 7) % 7 <> 0
                                      THEN CASE WHEN g.hedef_tarih < v_bugun THEN 'gecikmiş başlangıç' ELSE 'başlangıç ritim dışı' END END) AS j
      FROM public.gorev_log g LEFT JOIN public.hayvanlar h ON h.id = g.hayvan_id
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
       AND g.hedef_tarih <= v_bugun + 28
    UNION ALL
    SELECT v.tren, (v.j - '_kayma')
           || jsonb_build_object('ritim_disi_neden', CASE WHEN ((v.tren - v_capa) % 7 + 7) % 7 <> 0 THEN
                CASE WHEN COALESCE((v.j->>'_kayma')::int, 0) <> 0
                     THEN 'PG ' || CASE WHEN (v.j->>'_kayma')::int > 0 THEN '+' ELSE '' END || (v.j->>'_kayma') || ' gün'
                     ELSE 'tren ritmi değişti' END END)
      FROM (SELECT c.ovsync_tren AS tren, public._ovsync_tren_uye_vaka(c.id, v_tol) AS j FROM public.cases c
             WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC' AND c.ovsync_tren IS NOT NULL) v
  ), t AS (
    SELECT u.tren, jsonb_agg(u.j ORDER BY u.j->>'kupe_no', u.j->>'hayvan_id') AS uyeler FROM u GROUP BY u.tren
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object('tren_gunu', t.tren, 'ritim_disi', ((t.tren - v_capa) % 7 + 7) % 7 <> 0,
                                               'uyeler', t.uyeler) ORDER BY t.tren), '[]'::jsonb)
    INTO v_tr FROM t;

  SELECT COALESCE(jsonb_agg(x.j ORDER BY x.j->>'kupe_no', x.j->>'hayvan_id'), '[]'::jsonb) INTO v_bag
    FROM (SELECT public._ovsync_tren_uye_vaka(c.id, v_tol) - '_kayma' AS j FROM public.cases c
           WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC' AND c.ovsync_tren IS NULL) x;

  SELECT count(*)::int INTO v_ileri FROM public.gorev_log g
   WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
     AND g.hedef_tarih > v_bugun + 28;

  RETURN jsonb_build_object('ok', true, 'aktif', true, 'capa', v_capa, 'bugun', v_bugun,
                            'trenler', v_tr, 'bagimsizlar', v_bag, 'ileri_sayisi', v_ileri);
END;
$function$;

-- 3) Toptan erteleme planı (R7, R18, R9; yazma yok). Küme (X = p_tarih): (i) hedefi X açık OVSYNC_BASLAT, (ii) ovsync_tren = X,
--    (iii) ovsync_tren = X−7 aktif OVSYNC vaka. Karar: aşama 0 → KAYAR (+N), (iii)'te aşama 0 (gecikmiş GnRH1) → BASTAN (RL-17);
--    aşama 1 → N ≤ pg_pay (kayma + N ≤ tolerans) ise KAYAR, aksi BASTAN; aşama 2 → SECIM; aşama belirsiz → sonuc NULL (erteleme bu
--    üyeyi düşürür, R6-EK). yeni_tarih: görev X+N, aşama 0 gün#1+N, aşama 1 gün#2+N, BASTAN = yeni tren X+N (RL-15; kural daha
--    geçse K2 ile kuraldan) — ovsync_bastan_baslat'a p_hedef olarak verilir, aynı işlemde başlatma olmaz.
--    RL-16: X, bugünden itibaren üyesi olan İLK ritim günü olmalı (aksi OVSYNC_TREN_GUNU_DEGIL sebep ONCEKI_TREN_VAR).
--    ileri_vakalar (RL-14): ovsync_tren > X aşama 0 aktif OVSYNC vakalar → +N (vaka_kalan_gunleri_kaydir; etiket RL-1).
--    ileri_gorevler: hedefi X'ten büyük açık OVSYNC_BASLAT → R9 yeni = _ic(GREATEST(kural, eski), yeni çapa, öne çekme, bugün);
--    kural yok → yeni NULL, kural_yok true; değişmeyen listelenmez. dokunulmaz: X'te günü olan ama kümeye girmeyen aktif OVSYNC
--    vakalar (bağımsız = etiket NULL, ritim dışı = etiket dolu).
CREATE FUNCTION public._ovsync_tren_ertele_plan(p_tarih date, p_n integer)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bugun  date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_ayar   jsonb;
  v_capa   date;
  v_yeni   date;
  v_one    integer;
  v_tol    integer;
  v_uy     jsonb;
  v_ileri  jsonb;
  v_dok    jsonb;
  v_ilk    date;
  v_iv     jsonb;
BEGIN
  IF NOT public._ovsync_tren_aktif() THEN
    RAISE EXCEPTION 'OVSYNC_TREN_KAPALI:%', jsonb_build_object('rpc', 'ovsync_tren_ertele', 'tarih', p_tarih)::text;
  END IF;
  v_ayar := public._ovsync_tren_ayar();
  v_capa := (v_ayar->>'capa')::date;
  v_one  := (v_ayar->>'one_cekme')::int;
  v_tol  := (v_ayar->>'tolerans')::int;
  IF p_n IS NULL OR p_n < 1 OR p_n > 7 THEN
    RAISE EXCEPTION 'OVSYNC_TREN_N_GECERSIZ:%', jsonb_build_object('gun', p_n, 'min', 1, 'max', 7)::text;
  END IF;
  IF p_tarih IS NULL OR p_tarih < v_bugun THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('tarih', p_tarih, 'bugun', v_bugun)::text;
  END IF;
  IF ((p_tarih - v_capa) % 7 + 7) % 7 <> 0 THEN
    RAISE EXCEPTION 'OVSYNC_TREN_GUNU_DEGIL:%', jsonb_build_object('tarih', p_tarih, 'capa', v_capa)::text;
  END IF;
  -- RL-16: [bugün, X) aralığında üyeli (görev hedefi / etiket / etiket+7) ritim günü varsa X ilk tren değil
  SELECT min(x.t) INTO v_ilk
    FROM (SELECT g.hedef_tarih AS t FROM public.gorev_log g
           WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
          UNION ALL
          SELECT c.ovsync_tren FROM public.cases c WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC'
          UNION ALL
          SELECT c.ovsync_tren + 7 FROM public.cases c WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC') x
   WHERE x.t >= v_bugun AND x.t < p_tarih AND ((x.t - v_capa) % 7 + 7) % 7 = 0;
  IF v_ilk IS NOT NULL THEN
    RAISE EXCEPTION 'OVSYNC_TREN_GUNU_DEGIL:%', jsonb_build_object('tarih', p_tarih, 'sebep', 'ONCEKI_TREN_VAR', 'ilk_tren', v_ilk)::text;
  END IF;
  v_yeni := p_tarih + p_n;

  WITH m AS (
    SELECT jsonb_build_object('hayvan_id', g.hayvan_id, 'kupe_no', COALESCE(h.kupe_no, g.hayvan_id), 'case_id', NULL,
             'gorev_id', g.id, 'asama', 0, 'ovsync_tren', g.hedef_tarih, 'pg_pay', NULL, 'pg1_zaman', NULL) AS j,
           NULL::date AS g1, NULL::date AS g2
      FROM public.gorev_log g LEFT JOIN public.hayvanlar h ON h.id = g.hayvan_id
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND g.hedef_tarih = p_tarih
       AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
    UNION ALL
    SELECT public._ovsync_tren_uye_vaka(c.id, v_tol) - 'sonraki_is' - '_kayma',
           (SELECT d.treatment_date FROM public.treatment_days d WHERE d.case_id = c.id AND d.disease_id IS NULL
             ORDER BY d.treatment_date, d.day_no LIMIT 1),
           (SELECT d.treatment_date FROM public.treatment_days d WHERE d.case_id = c.id AND d.disease_id IS NULL
             ORDER BY d.treatment_date, d.day_no OFFSET 1 LIMIT 1)
      FROM public.cases c
     WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC' AND c.ovsync_tren IN (p_tarih, p_tarih - 7)
  ), k AS (
    SELECT m.j, m.g1, m.g2,
           CASE WHEN (m.j->>'asama')::int = 0 THEN CASE WHEN (m.j->>'ovsync_tren')::date < p_tarih THEN 'BASTAN' ELSE 'KAYAR' END
                WHEN (m.j->>'asama')::int = 1 AND m.j->>'pg_pay' IS NOT NULL
                  THEN CASE WHEN p_n <= (m.j->>'pg_pay')::int THEN 'KAYAR' ELSE 'BASTAN' END
                WHEN (m.j->>'asama')::int = 2 THEN 'SECIM' END AS sonuc
      FROM m
  )
  SELECT COALESCE(jsonb_agg(k.j || jsonb_build_object('sonuc', k.sonuc, 'yeni_tarih',
           CASE WHEN k.sonuc = 'KAYAR' THEN
                  CASE WHEN k.j->>'case_id' IS NULL THEN v_yeni WHEN (k.j->>'asama')::int = 0 THEN k.g1 + p_n ELSE k.g2 + p_n END
                WHEN k.sonuc = 'BASTAN' THEN   -- RL-15: taban X+1 öne çekmeden muaf → X+N (kural geçse kuraldan K2)
                  public._ovsync_tren_gunu_ic(GREATEST(public._ovsync_kural_tarihi(k.j->>'hayvan_id'), p_tarih + 1 + v_one),
                                              v_yeni, v_one, v_bugun) END)
           ORDER BY k.j->>'ovsync_tren', k.j->>'kupe_no', k.j->>'hayvan_id'), '[]'::jsonb)
    INTO v_uy FROM k;
  IF jsonb_array_length(v_uy) = 0 THEN
    RAISE EXCEPTION 'OVSYNC_TREN_BOS:%', jsonb_build_object('tarih', p_tarih)::text;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('gorev_id', x.id, 'hayvan_id', x.hayvan_id, 'eski', x.eski, 'yeni', x.yeni)
                            || CASE WHEN x.kural IS NULL THEN jsonb_build_object('kural_yok', true) ELSE '{}'::jsonb END
                            ORDER BY x.eski, x.hayvan_id), '[]'::jsonb)
    INTO v_ileri
    FROM (SELECT g.id, g.hayvan_id, g.hedef_tarih AS eski, public._ovsync_kural_tarihi(g.hayvan_id) AS kural,
                 public._ovsync_tren_gunu_ic(GREATEST(public._ovsync_kural_tarihi(g.hayvan_id), g.hedef_tarih), v_yeni, v_one, v_bugun) AS yeni
            FROM public.gorev_log g
           WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND g.hedef_tarih > p_tarih
             AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)) x
   WHERE x.yeni IS DISTINCT FROM (x.eski);

  SELECT COALESCE(jsonb_agg(jsonb_build_object('case_id', c.id, 'hayvan_id', c.animal_id, 'kupe_no', COALESCE(h.kupe_no, c.animal_id),
                                               'eski', c.ovsync_tren, 'yeni', c.ovsync_tren + p_n) ORDER BY c.ovsync_tren, c.animal_id), '[]'::jsonb)
    INTO v_iv
    FROM public.cases c LEFT JOIN public.hayvanlar h ON h.id = c.animal_id
   WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC' AND c.ovsync_tren > p_tarih AND public._ovsync_asama(c.id) = 0;

  SELECT jsonb_build_object('bagimsiz', count(*) FILTER (WHERE c.ovsync_tren IS NULL),
                            'ritim_disi', count(*) FILTER (WHERE c.ovsync_tren IS NOT NULL))
    INTO v_dok
    FROM public.cases c
   WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC'
     AND (c.ovsync_tren IS NULL OR c.ovsync_tren NOT IN (p_tarih, p_tarih - 7))
     AND EXISTS (SELECT 1 FROM public.treatment_days d WHERE d.case_id = c.id AND d.treatment_date = p_tarih);

  RETURN jsonb_build_object('tren', p_tarih, 'yeni_tren', v_yeni, 'uyeler', v_uy, 'ileri_gorevler', v_ileri, 'ileri_vakalar', v_iv,
    'tren_sayisi', (SELECT count(DISTINCT e.value->>'ovsync_tren')::int FROM pg_catalog.jsonb_array_elements(v_uy) e),
    'dokunulmaz', v_dok);
END;
$function$;

-- 4) ovsync_tren_ertele_onizle (K7 önizleme zorunlu): plan, yazma yok.
CREATE FUNCTION public.ovsync_tren_ertele_onizle(p_tarih date, p_n integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public._ovsync_tren_aktif() THEN   -- KAPALI payload'ında çağıranın adı (D7 tur 2 KÜÇÜK)
    RAISE EXCEPTION 'OVSYNC_TREN_KAPALI:%', jsonb_build_object('rpc', 'ovsync_tren_ertele_onizle', 'tarih', p_tarih)::text;
  END IF;
  RETURN jsonb_build_object('ok', true) || public._ovsync_tren_ertele_plan(p_tarih, p_n);
END;
$function$;

-- 5) ovsync_tren_ertele (K7, S10): tek işlem, kısmi başarı YOK. Seçim kontrolü yazmadan önce; çapa yeni ritme (BASTAN hedefi yeni
--    çapadan çıkar); her üye ayrı alt blokta (KAYAR: görev gorev_ertele, vaka vaka_kalan_gunleri_kaydir — etiket orada artar, RL-1;
--    BASTAN/SECIM: D6 RPC'leri — K6 a/b dışlaması, RL-12); ileri görevler R9 (gorev_ertele, GOREV_ERTELE soyu). Hata listesi doluysa
--    OVSYNC_TREN_ERTELE_DUSTU (çapa dahil hepsi geri). Başarıda islem_log OVSYNC_TREN_ERTELE.
CREATE FUNCTION public.ovsync_tren_ertele(p_tarih date, p_n integer, p_secimler jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_plan   jsonb;
  v_eski   numeric;
  v_u      jsonb;
  v_s      text;
  v_r      jsonb;
  v_t      date;
  v_case   uuid;
  v_isl    jsonb := '[]'::jsonb;
  v_dus    jsonb := '[]'::jsonb;
  v_eksik  jsonb;
BEGIN
  PERFORM public._ovsync_ic_ac();
  PERFORM pg_advisory_xact_lock(hashtext('ovsync_tren'));
  v_plan := public._ovsync_tren_ertele_plan(p_tarih, p_n);   -- doğrulama + küme (eski ritimle)

  SELECT COALESCE(jsonb_agg(e.value->'case_id'), '[]'::jsonb) INTO v_eksik
    FROM pg_catalog.jsonb_array_elements(v_plan->'uyeler') e
   WHERE e.value->>'sonuc' = 'SECIM'
     AND COALESCE(COALESCE(p_secimler, '{}'::jsonb)->>(e.value->>'case_id'), '') NOT IN ('PG48', 'BASTAN');
  IF jsonb_array_length(v_eksik) > 0 THEN
    RAISE EXCEPTION 'OVSYNC_TREN_SECIM_EKSIK:%', jsonb_build_object('eksik', v_eksik)::text;
  END IF;

  SELECT a.deger INTO v_eski FROM public.protokol_ayar a WHERE a.anahtar = 'ovsync_tren_capa';
  UPDATE public.protokol_ayar SET deger = to_char(p_tarih + p_n, 'YYYYMMDD')::numeric WHERE anahtar = 'ovsync_tren_capa';

  FOR v_u IN SELECT e.value FROM pg_catalog.jsonb_array_elements(v_plan->'uyeler') e LOOP
    v_case := (v_u->>'case_id')::uuid;
    v_s := COALESCE(v_u->>'sonuc', 'BELIRSIZ');
    IF v_s = 'SECIM' THEN
      v_s := p_secimler->>(v_u->>'case_id');
    END IF;
    BEGIN
      -- Hayvan kilidi aşama tekrar okunmadan önce (D6 sırası): plan ile işlem arasında seans araya giremez
      PERFORM 1 FROM public.hayvanlar h WHERE h.id = v_u->>'hayvan_id' FOR NO KEY UPDATE;
      IF v_case IS NOT NULL AND public._ovsync_asama(v_case) IS DISTINCT FROM (v_u->>'asama')::smallint THEN
        v_s := 'BELIRSIZ';
      END IF;
      IF v_s = 'BELIRSIZ' THEN
        RAISE EXCEPTION 'OVSYNC_ASAMA_BELIRSIZ:%', jsonb_build_object('case_id', v_case, 'oneri', 'BASTAN_BASLAT')::text;
      ELSIF v_s = 'KAYAR' AND v_case IS NULL THEN
        v_r := public.gorev_ertele((v_u->>'gorev_id')::uuid, p_tarih + p_n);
        v_t := (v_r->>'hedef_tarih')::date;
      ELSIF v_s = 'KAYAR' THEN
        v_r := public.vaka_kalan_gunleri_kaydir(v_case, p_n);
        SELECT d.treatment_date INTO v_t FROM public.treatment_days d WHERE d.case_id = v_case AND d.disease_id IS NULL
         ORDER BY d.treatment_date, d.day_no OFFSET (v_u->>'asama')::int LIMIT 1;
      ELSIF v_s = 'BASTAN' THEN
        v_r := public.ovsync_bastan_baslat(v_case, false, 'OVSYNC_TREN_ERTELE', (v_u->>'yeni_tarih')::date);   -- RL-15
        v_t := (v_r->>'hedef_tarih')::date;
      ELSE   -- PG48
        v_r := public.ovsync_pg48_tohumla(v_case);
        v_t := (v_r->>'tai_hedef')::date;
      END IF;
      v_isl := v_isl || jsonb_build_array(jsonb_build_object('hayvan_id', v_u->'hayvan_id', 'kupe_no', v_u->'kupe_no',
        'case_id', v_u->'case_id', 'gorev_id', v_u->'gorev_id', 'asama', v_u->'asama', 'sonuc', v_u->'sonuc',
        'islem', v_s, 'yeni_tarih', v_t, 'detay', v_r));
    EXCEPTION WHEN OTHERS THEN
      v_dus := v_dus || jsonb_build_array(jsonb_build_object('hayvan_id', v_u->'hayvan_id', 'kupe_no', v_u->'kupe_no',
        'case_id', v_u->'case_id', 'sebep', SQLERRM)
        || CASE WHEN v_s = 'BELIRSIZ' THEN jsonb_build_object('oneri', 'BASTAN_BASLAT_YA_DA_SEANS_ISARETLE') ELSE '{}'::jsonb END);
    END;
  END LOOP;

  FOR v_u IN SELECT e.value FROM pg_catalog.jsonb_array_elements(v_plan->'ileri_vakalar') e LOOP   -- RL-14
    BEGIN
      PERFORM 1 FROM public.hayvanlar h WHERE h.id = v_u->>'hayvan_id' FOR NO KEY UPDATE;
      IF public._ovsync_asama((v_u->>'case_id')::uuid) IS DISTINCT FROM 0 THEN
        RAISE EXCEPTION 'OVSYNC_ASAMA_BELIRSIZ:%', jsonb_build_object('case_id', v_u->'case_id', 'oneri', 'BASTAN_BASLAT')::text;
      END IF;
      PERFORM public.vaka_kalan_gunleri_kaydir((v_u->>'case_id')::uuid, p_n);
    EXCEPTION WHEN OTHERS THEN
      v_dus := v_dus || jsonb_build_array(jsonb_build_object('hayvan_id', v_u->'hayvan_id', 'kupe_no', v_u->'kupe_no',
        'case_id', v_u->'case_id', 'sebep', SQLERRM));
    END;
  END LOOP;

  FOR v_u IN SELECT e.value FROM pg_catalog.jsonb_array_elements(v_plan->'ileri_gorevler') e WHERE e.value->>'yeni' IS NOT NULL LOOP
    BEGIN
      PERFORM public.gorev_ertele((v_u->>'gorev_id')::uuid, (v_u->>'yeni')::date);
    EXCEPTION WHEN OTHERS THEN
      v_dus := v_dus || jsonb_build_array(jsonb_build_object('hayvan_id', v_u->'hayvan_id', 'gorev_id', v_u->'gorev_id',
        'kupe_no', (SELECT h.kupe_no FROM public.hayvanlar h WHERE h.id = v_u->>'hayvan_id'), 'sebep', SQLERRM));
    END;
  END LOOP;

  IF jsonb_array_length(v_dus) > 0 THEN
    RAISE EXCEPTION 'OVSYNC_TREN_ERTELE_DUSTU:%', jsonb_build_object('tren', p_tarih, 'n', p_n, 'dusenler', v_dus)::text;
  END IF;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('OVSYNC_TREN_ERTELE', NULL, 'ovsync_tren_capa', 'protokol_ayar',
          jsonb_build_object('tren', p_tarih, 'yeni_tren', p_tarih + p_n, 'n', p_n, 'eski_capa', v_eski,
            'yeni_capa', to_char(p_tarih + p_n, 'YYYYMMDD')::numeric, 'secimler', COALESCE(p_secimler, '{}'::jsonb),
            'islenen', v_isl, 'ileri_gorevler', v_plan->'ileri_gorevler', 'ileri_vakalar', v_plan->'ileri_vakalar'),
          jsonb_build_object('olusturulan', '[]'::jsonb, 'silinen', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object('tablo', 'protokol_ayar', 'id', 'ovsync_tren_capa',
              'onceki', jsonb_build_object('deger', v_eski), 'sonraki', jsonb_build_object('deger', to_char(p_tarih + p_n, 'YYYYMMDD')::numeric)))));

  RETURN jsonb_build_object('ok', true, 'tren', p_tarih, 'yeni_tren', p_tarih + p_n, 'islenen', v_isl,
                            'ileri_gorevler', v_plan->'ileri_gorevler', 'ileri_vakalar', v_plan->'ileri_vakalar');
END;
$function$;

-- ACL (Supabase varsayılan yetkisi anon'a EXECUTE verir): iç yardımcılar authenticated'a da kapalı; RPC'ler authenticated + service_role.
REVOKE ALL ON FUNCTION public._ovsync_tren_uye_vaka(uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_tren_ertele_plan(date, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ovsync_tren_listele() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_tren_listele() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_tren_ertele_onizle(date, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_tren_ertele_onizle(date, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_tren_ertele(date, integer, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_tren_ertele(date, integer, jsonb) TO authenticated, service_role;
