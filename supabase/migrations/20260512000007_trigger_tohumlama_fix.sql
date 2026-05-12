-- Migration: Fix _islem_log_yaz trigger — tohumlama UPDATE'lerde gereksiz ABORT_KAYDI engelle
-- Bug: Tohumlama sonucu Boş/Gebe/Bekliyor değişince trigger ABORT_KAYDI yazıyordu
--       + RPC'ler de kendi islem_log'unu yazıyor → çift kayıt + yanlış tip
-- Fix: RPC'ler kendi log'unu yaptığı için, trigger sadece INSERT(tohumlama) ve
--       RPC dışı abort UPDATE'lerde log yazar. Diğer UPDATE'leri sessizce geçer.
BEGIN;

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
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
      -- FIX: UPDATE'lerde ABORT_KAYDI varsayma — tüm RPC'ler kendi islem_log'unu yapıyor
      IF TG_OP = 'INSERT' THEN
        v_tip := 'TOHUMLAMA';
      ELSE
        -- UPDATE: sadece abort (RPC dışı) durumunda logla
        -- RPC'ler (tohumlama_abort, tohumlama_sonuc_bos, vb.) kendi islem_log'unu INSERT eder
        IF NEW.sonuc = 'Abort' AND OLD.sonuc != 'Abort' THEN
          v_tip := 'ABORT_KAYDI';
        ELSE
          -- RPC tarafından yönetilen UPDATE — trigger sessizce geç
          RETURN NEW;
        END IF;
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
$$;

COMMIT;
