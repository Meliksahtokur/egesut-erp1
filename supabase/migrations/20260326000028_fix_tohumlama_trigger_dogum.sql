-- Fix: tohumlama UPDATE trigger 'Doğum Yaptı' güncellemesini ABORT_KAYDI değil DOGUM_KAYDI olarak loglasın
-- Sorun: dogum_kaydet RPC tohumlama.sonuc='Doğum Yaptı' yaparken trigger her UPDATE'i ABORT_KAYDI yazıyordu

CREATE OR REPLACE FUNCTION public.fn_islem_log()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip        text;
  v_hayvan_id  uuid;
  v_snapshot   jsonb;
  v_ref_id     uuid;
  v_ref_tablo  text;
BEGIN
  CASE TG_TABLE_NAME

    WHEN 'hayvanlar' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hayvanlar';

    WHEN 'dogum' THEN
      v_tip       := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'dogum';

    WHEN 'tohumlama' THEN
      v_tip := CASE
        WHEN TG_OP = 'UPDATE' AND NEW.sonuc = 'Abort'       THEN 'ABORT_KAYDI'
        WHEN TG_OP = 'UPDATE' AND NEW.sonuc = 'Doğum Yaptı' THEN 'DOGUM_KAYDI'
        WHEN TG_OP = 'UPDATE'                                THEN 'TOHUMLAMA_GUNCELLENDI'
        ELSE 'TOHUMLAMA'
      END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'tohumlama';

    WHEN 'hastalik_log' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HASTALIK_KAYDI' ELSE 'HASTALIK_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hastalik_log';

    WHEN 'kizginlik_log' THEN
      v_tip       := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'kizginlik_log';

    ELSE
      v_tip       := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := TG_TABLE_NAME;
  END CASE;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, ref_id, ref_tablo)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_ref_id, v_ref_tablo);

  RETURN NEW;
END;
$$;
