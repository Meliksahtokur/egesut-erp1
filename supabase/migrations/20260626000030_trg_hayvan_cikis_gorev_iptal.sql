-- Migration: hayvan Aktif'ten çıkınca (Satıldı/Öldü/diğer) tüm açık görevlerini iptal
-- Tarih: 2026-06-26 — Spec §2 Faz 2. cikis_yap seans boşluğunu + doğrudan durum path'ini kapatır.
CREATE OR REPLACE FUNCTION public._trg_hayvan_cikis_gorev_iptal()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
  IF NEW.durum <> 'Aktif' AND OLD.durum = 'Aktif' THEN
    UPDATE public.gorev_log
       SET iptal = true, kapatan_ref = 'hayvan-cikis'
     WHERE hayvan_id = NEW.id
       AND NOT tamamlandi AND NOT iptal;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_hayvan_cikis_gorev_iptal ON public.hayvanlar;
CREATE TRIGGER trg_hayvan_cikis_gorev_iptal
  AFTER UPDATE OF durum ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public._trg_hayvan_cikis_gorev_iptal();