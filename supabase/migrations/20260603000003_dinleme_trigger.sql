-- Migration: Protokol Uyarı Sistemi — Dinleme Trigger'ları (Task 9)
-- Etkiler: 3 AFTER INSERT trigger: vaccination_log, uygulama_log, drug_administrations
-- Bağımlılık: 20260603000001_protokol_etken_kod.sql (_etken_kod_bul, _gorev_dinle)
-- Bağımlılık: 20260603000002_uygulama_log.sql (uygulama_log tablosu)

BEGIN;

-- ============================================================
-- Trigger 1: vaccination_log INSERT → _gorev_dinle
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_dinle_vaccination()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
BEGIN
  v_etken := public._etken_kod_bul(NULL, NEW.vaccine_id);
  IF v_etken IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.animal_id, v_etken, 'vaccination_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dinle_vaccination ON public.vaccination_log;
CREATE TRIGGER trg_dinle_vaccination
  AFTER INSERT ON public.vaccination_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_vaccination();

-- ============================================================
-- Trigger 2: uygulama_log INSERT → _gorev_dinle
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_dinle_uygulama()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.etken_kod IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.hayvan_id, NEW.etken_kod, 'uygulama_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dinle_uygulama ON public.uygulama_log;
CREATE TRIGGER trg_dinle_uygulama
  AFTER INSERT ON public.uygulama_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_uygulama();

-- ============================================================
-- Trigger 3: drug_administrations INSERT → _gorev_dinle
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_dinle_drug_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
  v_animal_id text;
BEGIN
  v_etken := public._etken_kod_bul(NEW.stok_id, NULL);
  IF v_etken IS NULL THEN
    RETURN NEW;
  END IF;

  -- hayvan_id: drug_administrations → treatment_days → cases → animal_id
  SELECT c.animal_id INTO v_animal_id
  FROM public.treatment_days td
  JOIN public.cases c ON c.id = td.case_id
  WHERE td.id = NEW.treatment_day_id;

  IF v_animal_id IS NOT NULL THEN
    PERFORM public._gorev_dinle(v_animal_id, v_etken, 'drug_admin:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dinle_drug_admin ON public.drug_administrations;
CREATE TRIGGER trg_dinle_drug_admin
  AFTER INSERT ON public.drug_administrations
  FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_drug_admin();

COMMIT;
