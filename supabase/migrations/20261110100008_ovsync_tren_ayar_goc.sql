-- ============================================================================
-- 20261110100008_ovsync_tren_ayar_goc.sql — Ovsync treni D8: ayar ve göç
-- Plan: docs/plans/2026-11-09-ovsync-tren/PLAN.md "### D8" (R1, R9, R14; R6-EK D8 eki — root SORU-3; D2 review çapa aralığı).
-- Yeni RPC'ler:
--   ovsync_tren_yeniden_hedefle(p_kuru, p_capa) — açık ileri (hedef ≥ bugün_TR) OVSYNC_BASLAT'ları R9 formülüyle trene hedefler,
--     etiketsiz/hastalıksız ritimdeki aktif OVSYNC vakalarına üyelik yazar (R14), belirsiz aşamalı vakaları listeler (R6-EK).
--     Kuru: bayraktan bağımsız, yazma yok. Kuru değil: bayrak kapalıysa OVSYNC_TREN_KAPALI; yazma gorev_ertele (iç bayrak) ile.
--   ovsync_tren_ayar_guncelle(p_aktif, p_capa) — ayar satırları protokol_ayar_guncelle üzerinden (PROTOKOL_AYAR kaydı aynı
--     snapshot), açılışta ayar doğrulanır (spec §7) ve aynı işlemde yeniden_hedefle(false) koşar.
-- Mevcut fonksiyon gövdesi değişmez (md5 koruması gerekmez). Tarih yalnız TR.
-- ============================================================================
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- 1) ovsync_tren_yeniden_hedefle → {ok, kuru, capa, gorevler:[{gorev_id, hayvan_id, kupe_no, eski, yeni, durum}],
--    uyelik:[{case_id, hayvan_id, tren}], belirsiz_asama:[{case_id, hayvan_id, kupe_no}], belirsiz_sayisi}
--    durum: kural yok → KURAL_YOK (yeni null, dokunulmaz); yeni = eski → AYNI; aksi TASINIR. Gecikmiş (hedef < bugün) görev
--    listede yok (başlatıldığında RL-11 yolu yeniden hedefler). Yazma dönüşünde `yeni` = gorev_ertele'nin yazdığı gün.
CREATE FUNCTION public.ovsync_tren_yeniden_hedefle(p_kuru boolean DEFAULT true, p_capa date DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bugun date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_kuru  boolean := COALESCE(p_kuru, true);
  v_a     jsonb;
  v_capa  date;
  v_one   integer;
  v_gor   jsonb;
  v_uye   jsonb;
  v_bel   jsonb;
  v_u     jsonb;
  v_r     jsonb;
  v_yaz   jsonb := '[]'::jsonb;
  v_ic    text;
BEGIN
  IF NOT v_kuru THEN
    IF NOT public._ovsync_tren_aktif() THEN
      RAISE EXCEPTION 'OVSYNC_TREN_KAPALI:%', jsonb_build_object('rpc', 'ovsync_tren_yeniden_hedefle')::text;
    END IF;
    PERFORM pg_advisory_xact_lock(hashtext('ovsync_tren'));
  END IF;
  v_a := public._ovsync_tren_ayar();   -- eksik/bozuk ayar → OVSYNC_TREN_AYAR (kuru dahil)
  IF NOT v_kuru AND p_capa IS NOT NULL AND p_capa <> (v_a->>'capa')::date THEN
    RAISE EXCEPTION 'OVSYNC_TREN_AYAR:%', jsonb_build_object('anahtar', 'ovsync_tren_capa',
      'deger', to_char(p_capa, 'YYYYMMDD')::numeric, 'sebep', 'AYARDAN_FARKLI')::text;
  END IF;
  v_capa := COALESCE(p_capa, (v_a->>'capa')::date);
  v_one  := (v_a->>'one_cekme')::int;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('gorev_id', x.id, 'hayvan_id', x.hayvan_id, 'kupe_no', x.kupe_no,
           'eski', x.eski, 'yeni', x.yeni,
           'durum', CASE WHEN x.kural IS NULL THEN 'KURAL_YOK' WHEN x.yeni = x.eski THEN 'AYNI' ELSE 'TASINIR' END)
           ORDER BY x.eski, x.kupe_no, x.id), '[]'::jsonb)
    INTO v_gor
    FROM (SELECT s.*, CASE WHEN s.kural IS NOT NULL
                           THEN public._ovsync_tren_gunu_ic(GREATEST(s.kural, s.eski), v_capa, v_one, v_bugun) END AS yeni
            FROM (SELECT g.id, g.hayvan_id, COALESCE(h.kupe_no, g.hayvan_id) AS kupe_no, g.hedef_tarih AS eski,
                         public._ovsync_kural_tarihi(g.hayvan_id) AS kural
                    FROM public.gorev_log g
                    LEFT JOIN public.hayvanlar h ON h.id = g.hayvan_id
                   WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND g.hedef_tarih >= v_bugun
                     AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)) s) x;

  -- R14: etiketsiz, bağımsız işaretsiz (D9), hastalık günsüz aktif OVSYNC vaka; D0 = hastalık-dışı gün#1 (GnRH1 planı) ritimde → tren = D0
  SELECT COALESCE(jsonb_agg(jsonb_build_object('case_id', s.id, 'hayvan_id', s.animal_id, 'tren', s.gun1)
           ORDER BY s.gun1, s.animal_id), '[]'::jsonb)
    INTO v_uye
    FROM (SELECT c.id, c.animal_id,
                 (SELECT min(d.treatment_date) FROM public.treatment_days d WHERE d.case_id = c.id AND d.disease_id IS NULL) AS gun1
            FROM public.cases c
           WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC' AND c.ovsync_tren IS NULL
             AND NOT c.ovsync_bagimsiz                                   -- D9 (RD9-4): bağımsız (K8/K9) üye olmaz
             AND NOT EXISTS (SELECT 1 FROM public.treatment_days d WHERE d.case_id = c.id AND d.disease_id IS NOT NULL)) s
   WHERE ((s.gun1 - v_capa) % 7 + 7) % 7 = 0;

  -- R6-EK (root SORU-3): aşaması türetilemeyen aktif OVSYNC vakaları (sahibe, runbook P1c yanında)
  SELECT COALESCE(jsonb_agg(jsonb_build_object('case_id', c.id, 'hayvan_id', c.animal_id, 'kupe_no', COALESCE(h.kupe_no, c.animal_id))
           ORDER BY COALESCE(h.kupe_no, c.animal_id), c.id), '[]'::jsonb)
    INTO v_bel
    FROM public.cases c LEFT JOIN public.hayvanlar h ON h.id = c.animal_id
   WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC' AND public._ovsync_asama(c.id) IS NULL;

  IF NOT v_kuru THEN
    v_ic := current_setting('app.ovsync_tren_ic', true);
    PERFORM public._ovsync_ic_ac();
    FOR v_u IN SELECT e.value FROM pg_catalog.jsonb_array_elements(v_gor) e LOOP
      IF v_u->>'durum' = 'TASINIR' THEN   -- GOREV_ERTELE soyu korunur (R9)
        v_r := public.gorev_ertele((v_u->>'gorev_id')::uuid, (v_u->>'yeni')::date);
        v_u := v_u || jsonb_build_object('yeni', v_r->'hedef_tarih');
      END IF;
      v_yaz := v_yaz || jsonb_build_array(v_u);
    END LOOP;
    v_gor := v_yaz;
    UPDATE public.cases c SET ovsync_tren = (e.value->>'tren')::date
      FROM pg_catalog.jsonb_array_elements(v_uye) e
     WHERE c.id = (e.value->>'case_id')::uuid AND c.ovsync_tren IS NULL AND NOT c.ovsync_bagimsiz;   -- D9 (RD9-4)
    PERFORM set_config('app.ovsync_tren_ic', COALESCE(v_ic, ''), true);
  END IF;

  RETURN jsonb_build_object('ok', true, 'kuru', v_kuru, 'capa', v_capa, 'gorevler', v_gor, 'uyelik', v_uye,
                            'belirsiz_asama', v_bel, 'belirsiz_sayisi', jsonb_array_length(v_bel));
END;
$function$;

-- 2) ovsync_tren_ayar_guncelle → {ok, aktif, capa, yeniden_hedef:<yeniden_hedefle dönüşü>|null}
--    p_aktif NULL ya da (açılış ve p_capa NULL) → OVSYNC_TREN_AYAR; çapa satırın min/max'ı (20260101..20991231) dışında →
--    OVSYNC_TREN_AYAR ARALIK_DISI. Değişen satır protokol_ayar_guncelle ile yazılır (aynı PROTOKOL_AYAR snapshot'ı; değişmeyen
--    yazılmaz). Kapatma ayarı doğrulamaz (bozuk ya da eksik çapada da hızlı geri çalışır); açılışta (0→1) ya da açıkken çapa
--    değişince ayar doğrulanır, sonra R14 göçü (RL-18); açıkken aynı çapa → yeniden_hedef null.
CREATE FUNCTION public.ovsync_tren_ayar_guncelle(p_aktif boolean, p_capa date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_aktif  numeric;
  v_eski_c numeric;
  v_mn     numeric;
  v_mx     numeric;
  v_yeni_c numeric := to_char(p_capa, 'YYYYMMDD')::numeric;
  v_capa   date;
  v_yh     jsonb;
BEGIN
  IF p_aktif IS NULL OR (p_aktif AND p_capa IS NULL) THEN
    RAISE EXCEPTION 'OVSYNC_TREN_AYAR:%', jsonb_build_object(
      'anahtar', CASE WHEN p_aktif IS NULL THEN 'ovsync_tren_aktif' ELSE 'ovsync_tren_capa' END, 'deger', NULL, 'sebep', 'EKSIK')::text;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('ovsync_tren'));
  SELECT max(a.deger) FILTER (WHERE a.anahtar = 'ovsync_tren_aktif'), max(a.deger) FILTER (WHERE a.anahtar = 'ovsync_tren_capa'),
         max(a.min_deger) FILTER (WHERE a.anahtar = 'ovsync_tren_capa'), max(a.max_deger) FILTER (WHERE a.anahtar = 'ovsync_tren_capa')
    INTO v_aktif, v_eski_c, v_mn, v_mx
    FROM public.protokol_ayar a WHERE a.anahtar IN ('ovsync_tren_aktif', 'ovsync_tren_capa');
  IF v_aktif IS NULL OR (p_aktif AND v_eski_c IS NULL) THEN   -- kapatma eksik çapa satırında da çalışır (hızlı geri)
    RAISE EXCEPTION 'OVSYNC_TREN_AYAR:%', jsonb_build_object(
      'anahtar', CASE WHEN v_aktif IS NULL THEN 'ovsync_tren_aktif' ELSE 'ovsync_tren_capa' END, 'deger', NULL, 'sebep', 'EKSIK')::text;
  END IF;
  IF v_yeni_c < COALESCE(v_mn, 20260101) OR v_yeni_c > COALESCE(v_mx, 20991231) THEN
    RAISE EXCEPTION 'OVSYNC_TREN_AYAR:%', jsonb_build_object('anahtar', 'ovsync_tren_capa', 'deger', v_yeni_c,
      'sebep', 'ARALIK_DISI')::text;
  END IF;

  IF v_aktif IS DISTINCT FROM (CASE WHEN p_aktif THEN 1 ELSE 0 END)::numeric THEN
    PERFORM public.protokol_ayar_guncelle('ovsync_tren_aktif', CASE WHEN p_aktif THEN 1 ELSE 0 END);
  END IF;
  IF v_yeni_c <> v_eski_c THEN   -- kapatmada çapa satırı yoksa (NULL) yazılmaz
    PERFORM public.protokol_ayar_guncelle('ovsync_tren_capa', v_yeni_c);
  END IF;

  IF p_aktif AND (v_aktif = 0 OR v_yeni_c <> v_eski_c) THEN   -- RL-18: göç + üyelik yalnız açılışta ya da çapa değişince
    PERFORM public._ovsync_tren_ayar();                        -- açılıştan önce ayar doğrulaması (spec §7)
    v_yh := public.ovsync_tren_yeniden_hedefle(false);         -- R14: aynı işlemde göç + üyelik
  END IF;
  BEGIN
    v_capa := to_date(COALESCE(v_yeni_c, v_eski_c)::bigint::text, 'YYYYMMDD');
    IF to_char(v_capa, 'YYYYMMDD') <> COALESCE(v_yeni_c, v_eski_c)::bigint::text THEN v_capa := NULL; END IF;
  EXCEPTION WHEN others THEN
    v_capa := NULL;   -- kapatırken bozuk çapa: dönüşte null (ayar okunmaz)
  END;
  RETURN jsonb_build_object('ok', true, 'aktif', p_aktif, 'capa', v_capa, 'yeniden_hedef', v_yh);
END;
$function$;

-- ACL (Supabase varsayılan yetkisi anon'a EXECUTE verir): iki RPC authenticated + service_role
REVOKE ALL ON FUNCTION public.ovsync_tren_yeniden_hedefle(boolean, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_tren_yeniden_hedefle(boolean, date) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_tren_ayar_guncelle(boolean, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_tren_ayar_guncelle(boolean, date) TO authenticated, service_role;
