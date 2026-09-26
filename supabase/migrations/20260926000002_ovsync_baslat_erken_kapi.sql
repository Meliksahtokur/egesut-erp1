-- 20260926000002: start_first_service_protocol erken-çağrı kapısı (K4; T13/T11 fix)
-- Gövde = 000017 gövdesi (canlı demo gövdesi = 000017 birebir) + TEK yeni blok:
-- hedefe 2 günden çok varsa OVSYNC_ERKEN hatası. Pencere hedef−2 gün AÇIK (dahil):
-- v_bugun < hedef_tarih - 2 → red. T13: erken doğmuş görev + erken Başlat çağrısı
-- sessizce zincir açıyordu (v_s := GREATEST geleceği kabulleniyor); T11: kart
-- yolunda Başlat pencereyi bilmiyor — bu DB kapısı TEK karar noktası (UI etiketi
-- ayrı kalem, K4-UI).
-- Blok yerleşimi: 'zaten' idempotent-return'undan SONRA, otomatik muafiyetlerden
-- ÖNCE (iptal/tamamlanmış görev erken kapıya takılmaz). Probe kanıtı (demo,
-- BEGIN…ROLLBACK): P1 31g erken RED; P2 hedef−2 DAHİL kabul + zincir tam; P3 +3
-- RED — off-by-one doğru.
-- Otomatik yollar etkilenmez: zamanlayıcı + kısır-reconcile hedef <= bugun
-- filtresiyle çağırır → koşul onlarda doğamaz (20260923000006:~660, 000012:~235).
-- Tek (uuid) overload mevcut; DROP FUNCTION GEREKMEZ.
-- ACL: REVOKE'a authenticated dahil (Supabase default-privilege ACL tuzağı) +
-- hemen GRANT geri. anon/PUBLIC EXECUTE YOK.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.start_first_service_protocol(p_gorev_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, pg_temp
AS $function$
DECLARE
  v_g           record;
  v_h           record;
  v_olay        date;
  v_neden       text;
  v_son_sonuc   text;
  v_bugun       date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_s           date;
  v_sablon_id   uuid;
  v_disease_id  uuid;
  v_n           integer;
  v_res         jsonb;
  v_sab         jsonb;
  v_top         jsonb;
  v_case_id     uuid;
  v_tai_id      uuid;
  v_d58         uuid[];
  v_pg_gorev_iptal uuid[];
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RAISE EXCEPTION 'OZELLIK_KAPALI:%', jsonb_build_object(
      'bayrak', 'ovsync_pg_kurallari_aktif', 'gorev_id', p_gorev_id);
  END IF;

  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_BULUNAMADI:%', jsonb_build_object('gorev_id', p_gorev_id);
  END IF;
  IF v_g.gorev_tipi IS DISTINCT FROM 'OVSYNC_BASLAT' THEN
    RAISE EXCEPTION 'GOREV_TIPI_UYUMSUZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RETURN jsonb_build_object('ok', true, 'zaten', true, 'gorev_id', p_gorev_id,
      'iptal', COALESCE(v_g.iptal, false), 'kapatan_ref', v_g.kapatan_ref);
  END IF;

  -- K4 (2026-09-26): erken-çağrı kapısı — hedefe 2 günden çok varsa RET.
  -- Pencere hedef−2 gün AÇIK (dahil): v_bugun < hedef-2 → red. T13: gelecek-
  -- hedefli görev sessizce zincir açıyordu (v_s := GREATEST geleceği kabulleniyor).
  IF v_bugun < v_g.hedef_tarih - 2 THEN
    RAISE EXCEPTION 'OVSYNC_ERKEN:%', jsonb_build_object(
      'gorev_id', p_gorev_id,
      'hedef_tarih', v_g.hedef_tarih,
      'kalan_gun', (v_g.hedef_tarih - v_bugun),
      'acilisa_kalan_gun', (v_g.hedef_tarih - v_bugun - 2));
  END IF;

  -- Olay tarihi = rota instance başlangıcı (yoksa hedef − 51, SK6)
  SELECT baslangic INTO v_olay FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  v_olay := COALESCE(v_olay, v_g.hedef_tarih - 51);

  -- ── Otomatik muafiyetler (SK7 final seti) ─────────────────────────────
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_g.hayvan_id FOR UPDATE;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSIF COALESCE(v_h.kisir, false) THEN
    v_neden := 'KISIR';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu
    SELECT t.sonuc INTO v_son_sonuc FROM public.tohumlama t
     WHERE t.hayvan_id = v_g.hayvan_id
       ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
       LIMIT 1;
    IF v_son_sonuc = 'Gebe' THEN
      v_neden := 'GEBE';
    ELSIF v_son_sonuc = 'Bekliyor' THEN
      v_neden := 'BEKLIYOR';
    ELSIF EXISTS (SELECT 1 FROM public.cases c
                   WHERE c.animal_id = v_g.hayvan_id
                     AND c.status = 'active'
                     AND c.protocol_family IS NOT NULL) THEN
      v_neden := 'AKTIF_SENKRONIZASYON';
    END IF;
  END IF;

  IF v_neden IS NOT NULL THEN
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = p_gorev_id;
    UPDATE public.protokol_instance
       SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = v_g.protokol_instance_id AND durum = 'aktif';
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_SKIPPED', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
            jsonb_build_object('gorev_id', p_gorev_id, 'neden', v_neden,
              'kaynak', v_g.kaynak, 'olay_tarihi', v_olay, 'hedef_tarih', v_g.hedef_tarih),
            '{}'::jsonb);
    RETURN jsonb_build_object('ok', true, 'atlandi', v_neden, 'gorev_id', p_gorev_id);
  END IF;

  -- ── Başlangıç, şablon, hastalık ───────────────────────────────────────
  v_s := GREATEST(v_g.hedef_tarih, v_bugun);

  SELECT count(*), (array_agg(id))[1] INTO v_n, v_sablon_id
    FROM public.tedavi_sablonu
   WHERE protokol_ailesi = 'OVSYNC' AND aktif IS TRUE;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'aktif_ovsync_sablon_sayisi', v_n);
  END IF;

  SELECT count(DISTINCT disease_id), (array_agg(DISTINCT disease_id))[1] INTO v_n, v_disease_id
   FROM public.sablon_hastalik_eslem
   WHERE sablon_id = v_sablon_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_HASTALIK_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sablon_id', v_sablon_id, 'hastalik_sayisi', v_n);
  END IF;

  -- ── Atomik zincir ──────────────────────────────────────────────────────
  v_res := public._vaka_ac_tek(v_g.hayvan_id, v_disease_id, 'İlk tohumlama zinciri', v_s);
  IF (v_res->>'ok') IS DISTINCT FROM 'true' OR (v_res->>'case_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_ACILAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'hayvan_id', v_g.hayvan_id, 'sonuc', v_res);
  END IF;
  v_case_id := (v_res->>'case_id')::uuid;

  UPDATE public.cases
     SET protocol_family = 'OVSYNC'
   WHERE id = v_case_id
     AND protocol_family IS NULL;

  v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                       p_baslangic_tarihi := v_s);
  IF (v_sab->>'ok') IS DISTINCT FROM 'true'
     OR COALESCE((v_sab->>'seans_sayisi')::int, 0) = 0
     OR COALESCE(jsonb_array_length(v_sab->'atlanan'), 0) > 0 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_UYGULANAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_sab);
  END IF;

  v_top := public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                                     p_baslangic_tarihi := v_s);
  IF (v_top->>'ok') IS DISTINCT FROM 'true'
     OR (v_top->>'olustu') IS DISTINCT FROM 'true'
     OR (v_top->>'gorev_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_TAI_OLUSMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_top);
  END IF;
  v_tai_id := (v_top->>'gorev_id')::uuid;

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_D58_IPTAL'
     WHERE hayvan_id = v_g.hayvan_id
       AND kaynak = 'DOGUM-' || v_g.hayvan_id
       AND gorev_tipi = 'DIGER'
       AND aciklama ILIKE '%kızgınlık takibi%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
       AND hedef_tarih BETWEEN v_olay + 50 AND v_olay + 70
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_d58 FROM u;

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true,
           kapatan_ref = 'ILK_TOH_PROTOKOL_YERINE:' || v_case_id::text
     WHERE hayvan_id = v_g.hayvan_id
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND kaynak LIKE 'PG_TOHUMLAMA:%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_gorev_iptal FROM u;

  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = 'case:' || v_case_id::text
   WHERE id = p_gorev_id;
  UPDATE public.protokol_instance
     SET durum = 'tamamlandi', kapandi_at = now(), kapandi_sebep = 'case:' || v_case_id::text
   WHERE id = v_g.protokol_instance_id AND durum = 'aktif';

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_PROTOCOL_STARTED', v_g.hayvan_id, v_case_id::text, 'cases',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'case_id', v_case_id,
            'sablon_id', v_sablon_id, 'disease_id', v_disease_id,
            'baslangic', v_s, 'olay_tarihi', v_olay, 'kaynak', v_g.kaynak,
            'tohumlama_gorev_id', v_tai_id,
            'seans_sayisi', (v_sab->>'seans_sayisi')::int,
            'd58_iptal', to_jsonb(v_d58),
            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal)),
          '{}'::jsonb);

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id, 'tohumlama_gorev_id', v_tai_id,
                            'baslangic', v_s, 'd58_iptal', to_jsonb(v_d58),
                            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal));
END;
$function$;

-- ACL yeniden beyanı (000017 deseni; REVOKE'a authenticated dahil — Supabase
-- default-privilege ACL tuzağı, GRANT hemen geri verilir). anon/PUBLIC EXECUTE YOK.
REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260926000002_ovsync_baslat_erken_kapi (K4)
