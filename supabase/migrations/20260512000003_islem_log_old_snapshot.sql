-- Migration: islem_log trigger'a OLD snapshot desteği
-- hayvanlar UPDATE ve gorev_log UPDATE için OLD+NEW kaydedilir
BEGIN;

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip          text;
  v_hayvan_id    text;
  v_snapshot     jsonb;
  v_payload      jsonb;
BEGIN
  -- Tip + hayvan_id tablo adına göre belirle
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      -- DEĞİŞİKLİK: UPDATE'te OLD + NEW, INSERT'te sadece NEW
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object(
          'old', to_jsonb(OLD),
          'new', to_jsonb(NEW)
        );
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    WHEN 'dogum' THEN
      v_tip       := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'tohumlama' THEN
      v_tip       := CASE TG_OP WHEN 'UPDATE' THEN 'ABORT_KAYDI' ELSE 'TOHUMLAMA' END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'hastalik_log' THEN
      v_tip       := 'HASTALIK_KAYDI';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'kizginlik_log' THEN
      v_tip       := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'gorev_log' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'GOREV_EKLENDI' ELSE 'GOREV_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      -- DEĞİŞİKLİK: UPDATE'te OLD + NEW, INSERT'te sadece NEW
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object(
          'old', to_jsonb(OLD),
          'new', to_jsonb(NEW)
        );
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    ELSE
      v_tip       := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot  := to_jsonb(NEW);
  END CASE;

  -- Standart payload envelope
  v_payload := jsonb_build_object(
    'event_type', CASE v_tip
      WHEN 'DOGUM_KAYDI'        THEN 'birth_recorded'
      WHEN 'TOHUMLAMA'          THEN 'insemination_performed'
      WHEN 'HASTALIK_KAYDI'     THEN 'treatment_recorded'
      WHEN 'HAYVAN_EKLENDI'     THEN 'animal_registered'
      WHEN 'HAYVAN_GUNCELLENDI' THEN 'animal_updated'
      WHEN 'ABORT_KAYDI'        THEN 'abortion_recorded'
      WHEN 'KIZGINLIK'          THEN 'estrus_detected'
      WHEN 'GOREV_EKLENDI'      THEN 'task_created'
      WHEN 'GOREV_GUNCELLENDI'  THEN 'task_updated'
      ELSE lower(v_tip)
    END,
    'entity_type', 'animal',
    'entity_id',   v_hayvan_id,
    'meta',        v_snapshot
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, payload)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_payload);

  RETURN NEW;
END;
$$;

COMMIT;