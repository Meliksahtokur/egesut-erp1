-- ============================================================================
-- Migration: 20260925000013_ovsync_protocol_family
-- Tarih: 2026-09-25 · Cila-onarım K4 (mimar yan bulgu + R-ARAŞTIRMA ikincil etki)
--
-- HATA: start_first_service_protocol zinciri açtığı vakaya
--   cases.protocol_family yazmıyordu; buna dayanan TÜM guard'lar
--   (start_first AKTIF_SENKRONIZASYON muafiyeti, 000008 sessiz-reconcile
--   guard'ı, ureme_temizlik R1, _acik_disi_hedef_ic) ölü kalıyordu — demo
--   ölçümü M6: 12/12 aktif Ovsync vakasında protocol_family NULL.
-- ONARIM: zincir vaka kimliğini (v_case_id) aldıktan HEMEN SONRA vakaya
--   aile damgası yazılır: protocol_family='OVSYNC' WHERE ... IS NULL
--   (idempotent; şablona değil zincirin kendisine yazılır — şablon guard'ı
--   zaten aile=OVSYNC geçmeden buraya ulaşmayı engeller → sabit 'OVSYNC'
--   güvenli; 20260923000005 kapanış-yolu aile doldurması da beslenir).
-- Gövde tabanı: apply-öncesi canlı demo gövdesi (2026-09-25 çekimi =
--   20260925000001:85 gövdesi birebir; KISIR VAR, UPDATE cases YOK).
-- Mevcut aktif Ovsync vakalarının backfill'i MIGRATION DEĞİL —
--   scripts/cila-onarim/2026-09-25-k4-backfill.sql (demo'ya özel betik).
-- Geri alınabilir: canlı taban gövde CREATE OR REPLACE ile geri yazılır.
-- ACL değişmez; anon/PUBLIC kapalı kalır.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.start_first_service_protocol(p_gorev_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
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

  -- K4 (2026-09-25, mimar yan bulgu): zincirin açtığı vaka aile damgasını taşır.
  -- Buna dayanan TÜM guard'lar (start_first AKTIF_SENKRONIZASYON, 000008 reconcile
  -- guard'ı, ureme_temizlik R1, _acik_disi_hedef_ic) bu yazımla canlanır.
  -- Şablona değil zincirin kendisine yazılır (sablon guard'ı zaten aile=OVSYNC
  -- geçmeden buraya ulaşmayı engeller → sabit 'OVSYNC' güvenli).
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

  v_top := public.tedavi_sablon_tohumulama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                                     p_baslangic_tarihi := v_s);
  IF (v_top->>'ok') IS DISTINCT FROM 'true'
     OR (v_top->>'olustu') IS DISTINCT FROM 'true'
     OR (v_top->>'gorev_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_TAI_OLUSMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_top);
  END IF;
  v_tai_id := (v_top->>'gorev_id')::uuid;

  -- ── SK4: doğum protokolünün 58. gün kızgınlık takibi iptal (53. gün E-vit kalır)
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

  -- ── R3.1: tek açık TAI kartı — açık PG sonrası görevleri iptal et
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

  -- ── Görev ve rota kapanışı + audit ───────────────────────────────────
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
$fn$;

COMMENT ON FUNCTION public.start_first_service_protocol(uuid) IS
  'R3.2: açık OVSYNC_BASLAT görevinden atomik Ovsync zinciri. Muafiyetler: AKTIF_DEGIL/KISIR/GEBE/BEKLIYOR/AKTIF_SENKRONIZASYON (TOHUMLAMA_VAR kalktı, SK7; KISIR S1). K4: açtığı vakaya protocol_family=OVSYNC yazar.';

REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000013_ovsync_protocol_family (K4)
