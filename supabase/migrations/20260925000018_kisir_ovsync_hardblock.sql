-- 20260925000018_kisir_ovsync_hardblock.sql — cila2 C1
-- Kısır hayvanda Ovsync protokol açılışı DB katmanında HARD engellenir (fail-closed).
-- Sahip talimatı: "kısır hayvanda ovsync açılması hem db hem de frontend
-- katmanlarında hardblocklanmalı — söyledim ama yapılmamış".
--
-- Kapsam (cila2 keşif raporu, 2026-09-25):
--   * cases INSERT'i kesen 6 yolun TEK mekanik kapısı: BEFORE INSERT trigger.
--     Yol envanteri: start_first_service_protocol (zaten soft-skip), create_case,
--     vaka_toplu_ac, kizginlik_vaka_ac (doğrudan INSERT), REST POST /cases.
--     Hastalık → sablon_hastalik_eslem → tedavi_sablonu.protokol_ailesi çözümlemesi
--     ile yalnız OVSYNC-aileli hastalıklar engellenir; Metrit vb. Üreme kategorili
--     ama ailesiz tedavi hastalıkları etkilenmez.
--   * UPDATE kolu: protocol_family 'OVSYNC'e GEÇİŞ yapıldığında aynı guard
--     (REST PATCH /cases dahil).
--   * tedavi_sablon_uygula: OVSYNC-aile şablonunun kısır hayvanın AKTİF vakasına
--     uygulanması (canlı demo gövdesi + yeni guard bacağı; önceki değişiklikler
--     korunur — S-3 provenance, R3.1 #12, gün/seans üretimi aynen).
-- Görev üretimi (_ovsync_baslat_gorev_kur K3) ve zincir başlatma
-- (start_first_service_protocol soft-skip) zaten korumalı — dokunulmaz.

BEGIN;

-- ── 1) Yardımcı: hastalık OVSYNC-aile şablonuna eşli mi? ──────────────────────
CREATE OR REPLACE FUNCTION public._ovsync_hastalik_mi(p_disease_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.sablon_hastalik_eslem e
      JOIN public.tedavi_sablonu s ON s.id = e.sablon_id
     WHERE e.disease_id = p_disease_id
       AND s.protokol_ailesi = 'OVSYNC'
  );
$$;

-- ── 2) Yardımcı: ihlal varsa RAISE — mesajın TEK noktası ─────────────────────
-- p_hayvan_id TEXT: cases.animal_id text'tir ve id UUID'si ya da kupe_no
-- taşır (domain-rules §1) — ikisi de çözülür, aktif hayvan öncelikli (K7 disiplini).
CREATE OR REPLACE FUNCTION public._kisir_ovsync_guard(p_hayvan_id text, p_ovsync boolean)
RETURNS void
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_ovsync AND COALESCE(
       (SELECT h.kisir FROM public.hayvanlar h
         WHERE h.id::text = p_hayvan_id OR h.kupe_no = p_hayvan_id
         ORDER BY (h.durum = 'Aktif') DESC
         LIMIT 1), false)
  THEN
    RAISE EXCEPTION 'KISIR_HAYVAN_OVSYNC_YASAK: hayvan % kısır işaretli — Ovsync protokolü açılamaz', p_hayvan_id;
  END IF;
END;
$$;

-- MİMAR NOTU (2026-09-25, C1 ek kabul): bu migration'ın ilk taslağı guard'ı
-- (uuid, boolean) imzasıyla kurdu; sonraki düzeltmede imza cases.animal_id'in
-- tipine (text) çekildi. CREATE OR REPLACE farklı imzada ESKİ overload'u
-- düşürmez — demo'da iki overload bir arada kaldı (ölü uuid overload'u ilk
-- probe'ta 'function does not exist' üretmişti). Tek taşınabilir temizlik:
DROP FUNCTION IF EXISTS public._kisir_ovsync_guard(uuid, boolean);

-- ── 3) cases guard trigger'ı (BEFORE INSERT/UPDATE) ──────────────────────────
CREATE OR REPLACE FUNCTION public._guard_cases_kisir_ovsync()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- INSERT: hastalığın ailesi şablon eşlemesinden çözülür (INSERT anında
  -- protocol_family henüz yazılmamış olabilir).
  IF TG_OP = 'INSERT' THEN
    PERFORM public._kisir_ovsync_guard(
      NEW.animal_id,
      public._ovsync_hastalik_mi(NEW.disease_id));
  END IF;
  -- UPDATE: protocol_family 'OVSYNC'e GEÇİYORSA (eski değer farklıysa) guard.
  IF TG_OP = 'UPDATE'
     AND NEW.protocol_family = 'OVSYNC'
     AND OLD.protocol_family IS DISTINCT FROM 'OVSYNC'
  THEN
    PERFORM public._kisir_ovsync_guard(NEW.animal_id, true);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cases_kisir_ovsync ON public.cases;
CREATE TRIGGER trg_cases_kisir_ovsync
  BEFORE INSERT OR UPDATE OF protocol_family ON public.cases
  FOR EACH ROW EXECUTE FUNCTION public._guard_cases_kisir_ovsync();

-- ── 4) tedavi_sablon_uygula — canlı gövde + kısır/OVSYNC bacağı ──────────────
-- Şablon doğrulamasından hemen sonra, gün/seans üretiminden ÖNCE guard:
-- kısır hayvanın vakasına OVSYNC-aile şablonu uygulanamaz.
CREATE OR REPLACE FUNCTION public.tedavi_sablon_uygula(
  p_case_id uuid,
  p_sablon_id uuid,
  p_baslangic_tarihi date DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_case         record;
  v_gun_no       smallint;
  v_date         date;
  v_sessions     jsonb;
  v_atlanan      jsonb := '[]'::jsonb;
  v_gun_atlanan  jsonb;
  v_gun_sayisi   int := 0;
  v_seans_sayisi int := 0;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  -- 000018 (cila2 C1): OVSYNC-aile şablonu kısır hayvana uygulanamaz.
  -- Fail-closed: yumuşak dönüş değil, KISIR_HAYVAN_OVSYNC_YASAK exception.
  PERFORM public._kisir_ovsync_guard(
    v_case.animal_id,
    EXISTS (SELECT 1 FROM public.tedavi_sablonu s
             WHERE s.id = p_sablon_id AND s.protokol_ailesi = 'OVSYNC'));

  FOR v_gun_no IN
    SELECT DISTINCT gun_no FROM public.tedavi_sablonu_kalem
    WHERE sablon_id = p_sablon_id ORDER BY gun_no
  LOOP
    v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_gun_no - 1);

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'planned_time',    to_char(k.planned_time,'HH24:MI'),
             'stok_id',         k.stok_id,
             'drug_product_id', k.drug_product_id,
             'dose',            k.dose,
             'unit',            k.unit,
             'route',           k.route
           ) ORDER BY k.planned_time), '[]'::jsonb)
    INTO v_sessions
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
      AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id));

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gun_no', k.gun_no,
             'planned_time', to_char(k.planned_time,'HH24:MI'),
             'neden', 'silinmiş ilaç/stok')), '[]'::jsonb)
    INTO v_gun_atlanan
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND ((k.drug_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
        OR (k.stok_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id)));
    IF jsonb_array_length(v_gun_atlanan) > 0 THEN
      v_atlanan := v_atlanan || v_gun_atlanan;
    END IF;

    IF jsonb_array_length(v_sessions) > 0 THEN
      PERFORM public.add_treatment_day_with_sessions(p_case_id, v_date, v_sessions, NULL);
      v_gun_sayisi   := v_gun_sayisi + 1;
      v_seans_sayisi := v_seans_sayisi + jsonb_array_length(v_sessions);
    END IF;
  END LOOP;

  -- S-3 provenance (bayraktan bağımsız, salt metadata): vakanın İLK şablon
  -- uygulaması damgalanır; source_template_id doluysa ikinci uygulama BU
  -- provenance'ı (source_template_id, protocol_snapshot) EZMEZ (R3.1) — dal
  -- yalnız source_template_id IS NULL iken çalışır.
  UPDATE public.cases c
     SET source_template_id = t.id,
         protocol_family    = COALESCE(t.protokol_ailesi, c.protocol_family),
         protocol_snapshot  = jsonb_build_object(
           'sablon_id',       t.id,
           'ad',              t.ad,
           'protokol_ailesi', t.protokol_ailesi,
           'tohumlama_plani', t.tohumlama_plani,
           'kalemler', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                 'gun_no',          k.gun_no,
                                 'planned_time',    to_char(k.planned_time,'HH24:MI'),
                                 'stok_id',         k.stok_id,
                                 'drug_product_id', k.drug_product_id,
                                 'dose',            k.dose,
                                 'unit',            k.unit,
                                 'route',           k.route
                               ) ORDER BY k.gun_no, k.planned_time, k.id), '[]'::jsonb)
                          FROM public.tedavi_sablonu_kalem k
                         WHERE k.sablon_id = t.id),
           'uygulama_at',     now(),
           'baslangic',       COALESCE(p_baslangic_tarihi, v_case.start_date))
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NULL
     AND t.id = p_sablon_id;

  -- R3.1 (#12): source_template_id ZATEN doluysa (ikinci+ şablon uygulaması)
  -- yukarıdaki dal atlanır — provenance/snapshot ezilmez. Ama protocol_family
  -- hâlâ NULL ise (ör. ilk uygulanan şablon ailesizdi: Mastit gibi) ve bu
  -- şablonun ailesi doluysa, YALNIZ protocol_family ayrı bir UPDATE ile
  -- doldurulur; source_template_id ve protocol_snapshot bu dalda DOKUNULMAZ.
  UPDATE public.cases c
     SET protocol_family = t.protokol_ailesi
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NOT NULL
     AND c.protocol_family IS NULL
     AND t.protokol_ailesi IS NOT NULL
     AND t.id = p_sablon_id;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$$;

-- ── 5) ACL ───────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public._ovsync_hastalik_mi(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public._kisir_ovsync_guard(text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public._guard_cases_kisir_ovsync() FROM PUBLIC, anon;

COMMIT;
