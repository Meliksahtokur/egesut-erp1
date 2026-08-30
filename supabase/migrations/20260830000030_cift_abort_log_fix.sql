-- Goal C — Çifte ABORT_KAYDI fix
-- tohumlama UPDATE'inde trigger artık tamamen sessiz; tohumlama_abort kendi kaydını yazıyor.
-- Taban: canlı prod gövdesi (assets/islem_log_yaz_canli.sql), tek fark yukarıdaki blok.

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_tip          text;
  v_hayvan_id    text;
  v_snapshot     jsonb;
  v_payload      jsonb;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar' THEN
      v_tip := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    WHEN 'dogum' THEN
      v_tip := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'tohumlama' THEN
      -- FIX (2026-08-30): UPDATE'larda trigger tamamen sessiz — tüm RPC'ler
      -- (tohumlama_abort dahil) kendi islem_log kaydını INSERT eder.
      -- Önceki sürüm RPC + trigger çift ABORT_KAYDI üretiyordu.
      IF TG_OP = 'INSERT' THEN
        v_tip := 'TOHUMLAMA';
      ELSE
        RETURN NEW;
      END IF;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'hastalik_log' THEN
      v_tip := 'HASTALIK_KAYDI';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'kizginlik_log' THEN
      v_tip := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'gorev_log' THEN
      v_tip := CASE TG_OP WHEN 'INSERT' THEN 'GOREV_EKLENDI' ELSE 'GOREV_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    ELSE
      v_tip := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot := to_jsonb(NEW);
  END CASE;

  v_payload := jsonb_build_object(
    'event_type', CASE v_tip
      WHEN 'DOGUM_KAYDI' THEN 'birth_recorded'
      WHEN 'TOHUMLAMA' THEN 'insemination_performed'
      WHEN 'HASTALIK_KAYDI' THEN 'treatment_recorded'
      WHEN 'HAYVAN_EKLENDI' THEN 'animal_registered'
      WHEN 'HAYVAN_GUNCELLENDI' THEN 'animal_updated'
      WHEN 'ABORT_KAYDI' THEN 'abortion_recorded'
      WHEN 'KIZGINLIK' THEN 'estrus_detected'
      WHEN 'GOREV_EKLENDI' THEN 'task_created'
      WHEN 'GOREV_GUNCELLENDI' THEN 'task_updated'
      ELSE lower(v_tip)
    END,
    'entity_type', 'animal',
    'entity_id', v_hayvan_id,
    'meta', v_snapshot
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, payload)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_payload);

  RETURN NEW;
END;
$function$
;

NOTIFY pgrst, 'reload schema';
