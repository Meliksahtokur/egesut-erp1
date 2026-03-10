-- Migration 012 — _islem_log_yaz trigger fix
-- IF/ELSIF zinciri CASE yapısına geçirildi (NEW.sonuc hatası düzeltildi)

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip       text;
  v_hayvan_id text;
  v_snapshot  jsonb;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar'    THEN v_tip := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
                             v_hayvan_id := NEW.id;          v_snapshot := to_jsonb(NEW);
    WHEN 'dogum'        THEN v_tip := 'DOGUM_KAYDI';
                             v_hayvan_id := NEW.anne_id;     v_snapshot := to_jsonb(NEW);
    WHEN 'tohumlama'    THEN v_tip := CASE TG_OP WHEN 'UPDATE' THEN 'ABORT_KAYDI' ELSE 'TOHUMLAMA' END;
                             v_hayvan_id := NEW.hayvan_id;   v_snapshot := to_jsonb(NEW);
    WHEN 'hastalik_log' THEN v_tip := 'HASTALIK_KAYDI';
                             v_hayvan_id := NEW.hayvan_id;   v_snapshot := to_jsonb(NEW);
    WHEN 'kizginlik_log'THEN v_tip := 'KIZGINLIK';
                             v_hayvan_id := NEW.hayvan_id;   v_snapshot := to_jsonb(NEW);
    ELSE                     v_tip := upper(TG_TABLE_NAME) || '_' || TG_OP;
                             v_hayvan_id := NULL;            v_snapshot := to_jsonb(NEW);
  END CASE;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot)
  VALUES (v_tip, v_hayvan_id, v_snapshot);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_islem_hastalik ON public.hastalik_log;
CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();
