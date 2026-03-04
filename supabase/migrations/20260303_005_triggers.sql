CREATE OR REPLACE FUNCTION public.set_deneme_no()
RETURNS TRIGGER AS $$
BEGIN
  SELECT COALESCE(MAX(deneme_no), 0) + 1 
  INTO NEW.deneme_no
  FROM public.tohumlama
  WHERE hayvan_id = NEW.hayvan_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_deneme_no ON public.tohumlama;
CREATE TRIGGER trg_deneme_no
  BEFORE INSERT ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.set_deneme_no();

NOTIFY pgrst, 'reload schema';