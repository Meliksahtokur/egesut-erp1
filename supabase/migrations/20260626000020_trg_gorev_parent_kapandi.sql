-- Migration: parent görev kapanınca/silinince açık çocukları iptal et (cascade)
-- Tarih: 2026-06-26 — Spec §2 Faz 2. Tek zorunlu nokta (her path'i kapsar).
CREATE OR REPLACE FUNCTION public._trg_gorev_parent_kapandi()
RETURNS trigger LANGUAGE plpgsql AS $function$
DECLARE v_pid uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_pid := OLD.id;
  ELSE
    -- yalnız açık→kapalı geçişinde (recursion + gereksiz çalışmayı önle)
    IF (NEW.tamamlandi OR NEW.iptal) AND NOT (OLD.tamamlandi OR OLD.iptal) THEN
      v_pid := NEW.id;
    ELSE
      RETURN NEW;
    END IF;
  END IF;

  UPDATE public.gorev_log
     SET iptal = true, kapatan_ref = 'parent-kapandi'
   WHERE parent_id = v_pid
     AND NOT tamamlandi AND NOT iptal;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_gorev_parent_kapandi ON public.gorev_log;
CREATE TRIGGER trg_gorev_parent_kapandi
  AFTER UPDATE OF tamamlandi, iptal OR DELETE ON public.gorev_log
  FOR EACH ROW EXECUTE FUNCTION public._trg_gorev_parent_kapandi();