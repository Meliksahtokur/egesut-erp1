-- ============================================================================
-- Migration: 20260925000007_cila_t1_acik_disi_senkron_muafiyet
-- Tarih: 2026-09-25 · SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s5.md §7 (T1)
-- Amaç: açık senkron-protokol görevi (ILAC/TOHUMLAMA_HAZIRLIK, 'senkron' damgalı)
--   varken yeni açık-dişi hedef üretilmez — çift senkron planlamanın kalıcı fix'i.
-- SAHİP KARARI: 188'in kasıtlı çift zinciri KORUNUR — mevcut OVSYNC_BASLAT bloğu
--   ikame edilmedi, üçüncü koşul eklendi (görevler kapanınca üretim geri döner).
-- Hedef: _acik_disi_hedef_ic (drift-düzeltmesi: canlı sarmalayıcı ince; sarmalayıcı
--   _acik_disi_ovsync_hedef ve ilk_tohumlama_zamanlayici DOKUNULMAZ).
-- Kanal: yalnız DEMO (sahip onaylı); prod ayrı sahip kapısıdır. Anon GRANT YOK.
--
-- REVERT KAYNAĞI — apply-öncesi canlı pg_get_functiondef('_acik_disi_hedef_ic(text)')
-- (S1 M1 kisır guard'lı güncel gövde, birebir; T1 bloğu hariç bu migration'ın ürettiği
--  gövde bununla birebirdir — geri dönüş: bu canlı gövdeyi CREATE OR REPLACE ile yaz):
-- ----------------------------------------------------------------------------
-- CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text)
--  RETURNS date
--  LANGUAGE plpgsql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
-- DECLARE
--   v_h   record;
--   v_son text;
--   v_k   date;
-- BEGIN
--   -- Bayrak YOKSAYAN uygunluk (dry-run önizleme). Yeni iş yaratmaz.
--   SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
--     INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
--   IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' THEN
--     RETURN NULL;
--   END IF;
-- 
--   -- S1/M1: kısır hayvan üreme planına girmez (kisir kolonu; işaret kalkınca normal kural)
--   IF v_h.kisir THEN
--     RETURN NULL;
--   END IF;
-- 
--   SELECT t.sonuc INTO v_son FROM public.tohumlama t
--    WHERE t.hayvan_id = p_hayvan_id
--    ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
--    LIMIT 1;
--   IF v_son IN ('Gebe', 'Bekliyor') THEN
--     RETURN NULL;
--   END IF;
-- 
--   IF EXISTS (SELECT 1 FROM public.cases c
--               WHERE c.animal_id = p_hayvan_id
--                 AND c.status = 'active'
--                 AND c.protocol_family IS NOT NULL) THEN
--     RETURN NULL;
--   END IF;
-- 
--   IF EXISTS (SELECT 1 FROM public.gorev_log g
--               WHERE g.hayvan_id = p_hayvan_id
--                 AND g.gorev_tipi = 'OVSYNC_BASLAT'
--                 AND COALESCE(g.tamamlandi, false) = false
--                 AND COALESCE(g.iptal, false) = false) THEN
--     RETURN NULL;
--   END IF;
-- 
--   v_k := public._ovsync_kural_tarihi(p_hayvan_id);
--   IF v_k IS NULL THEN
--     RETURN NULL;
--   END IF;
-- 
--   RETURN GREATEST(v_k, (now() AT TIME ZONE 'Europe/Istanbul')::date);
-- END;
-- $function$
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_h   record;
  v_son text;
  v_k   date;
BEGIN
  -- Bayrak YOKSAYAN uygunluk (dry-run önizleme). Yeni iş yaratmaz.
  SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
    INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RETURN NULL;
  END IF;

  -- S1/M1: kısır hayvan üreme planına girmez (kisir kolonu; işaret kalkınca normal kural)
  IF v_h.kisir THEN
    RETURN NULL;
  END IF;

  SELECT t.sonuc INTO v_son FROM public.tohumlama t
   WHERE t.hayvan_id = p_hayvan_id
   ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
   LIMIT 1;
  IF v_son IN ('Gebe', 'Bekliyor') THEN
    RETURN NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM public.cases c
              WHERE c.animal_id = p_hayvan_id
                AND c.status = 'active'
                AND c.protocol_family IS NOT NULL) THEN
    RETURN NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM public.gorev_log g
              WHERE g.hayvan_id = p_hayvan_id
                AND g.gorev_tipi = 'OVSYNC_BASLAT'
                AND COALESCE(g.tamamlandi, false) = false
                AND COALESCE(g.iptal, false) = false) THEN
    RETURN NULL;
  END IF;

  -- ═══ T1 ek koşulu (cila 20260925000007) — açık senkron-protokol görevi varken
  --     yeni açık-dişi hedef ÜRETME. 188 kasıtlı zinciri etkilemez: OVSYNC_BASLAT
  --     bloğu yukarıda zaten NULL döndürür; bu koşul yalnız zincir çalışırken
  --     (ILAC/TOHUMLAMA_HAZIRLIK, 'senkron' damgalı) üretimi durdurur; görevler
  --     kapanınca zamanlayıcı normal üretimine döner (spec-s5 §7.1 sahibin kararı:
  --     kasıtlı ardışık zincirler korunur). Canlı damga deseni: aciklama
  --     '39. Gün PG (Presynch-14 senkron)' — kaynak-alanı damgası canlıda 0 satır,
  --     OR bacağı zararsız (spec §7.2-V3).
  IF EXISTS (
    SELECT 1 FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id
       AND g.gorev_tipi IN ('ILAC', 'TOHUMLAMA_HAZIRLIK')
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%')
  ) THEN
    RETURN NULL;
  END IF;

  v_k := public._ovsync_kural_tarihi(p_hayvan_id);
  IF v_k IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN GREATEST(v_k, (now() AT TIME ZONE 'Europe/Istanbul')::date);
END;
$function$;

COMMENT ON FUNCTION public._acik_disi_hedef_ic(text) IS
  'R3.2 SK7 bayrak-yoksayan uygunluk (yalnız dry-run önizleme; iş yaratmaz). Muaf: kısır, Aktif değil/Dişi değil, Gebe/Bekliyor, aktif senkronizasyon vakası, açık OVSYNC_BASLAT, AÇIK senkron-protokol görevi (T1), tabansız.';
REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- EOF 20260925000007
