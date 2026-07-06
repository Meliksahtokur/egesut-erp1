-- Critical #6 fix: islem_log audit trail immutability.
-- Önceden: RLS "service_insert" policy PUBLIC+ALL+USING(true), authenticated role'e
-- DELETE/UPDATE grant açıktı → giriş yapmış herhangi bir kullanıcı audit log'u
-- silebilir/değiştirebilirdi (db.from('islem_log').delete() ile).
--
-- 11 fonksiyon islem_log'a yazıyor: hepsi SECURITY DEFINER + owner=postgres.
-- 6 fonksiyon (geri_al, case_geri_al, tohumlama_geri_al, islem_geri_al,
-- buzagi_sutten_kesme_geri_al, hizli_uygulama_geri_al) UPDATE yapıyor — HEPSİ
-- sadece "durum='geri_alindi'[, geri_alma_tarihi=now()]" kalıbını kullanıyor,
-- başka hiçbir kolona dokunmuyor (canlı pg_get_functiondef ile tek tek doğrulandı).
-- Hiçbir fonksiyon DELETE yapmıyor.
--
-- Demo projede (vtzqjmazsvurxdeondmi) uçtan uca test edildi (2026-07-06):
-- meşru durum-geçişi başarılı, snapshot mutasyonu + DELETE trigger tarafından
-- reddedildi, authenticated rolüyle ham UPDATE grant seviyesinde reddedildi.
-- SECURITY DEFINER+owner=postgres olduğu için REVOKE geri_al ailesini etkilemez.

CREATE OR REPLACE FUNCTION public._islem_log_immutable_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'islem_log kayıtları silinemez (immutable audit trail)';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.tip IS DISTINCT FROM OLD.tip
       OR NEW.ana_hayvan_id IS DISTINCT FROM OLD.ana_hayvan_id
       OR NEW.ref_id IS DISTINCT FROM OLD.ref_id
       OR NEW.ref_tablo IS DISTINCT FROM OLD.ref_tablo
       OR NEW.snapshot IS DISTINCT FROM OLD.snapshot
       OR NEW.tarih IS DISTINCT FROM OLD.tarih
       OR NEW.kullanici_notu IS DISTINCT FROM OLD.kullanici_notu
       OR NEW.payload IS DISTINCT FROM OLD.payload THEN
      RAISE EXCEPTION 'islem_log kayıtları değiştirilemez — sadece durum=geri_alindi geçişine izin verilir';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_islem_log_immutable ON public.islem_log;
CREATE TRIGGER trg_islem_log_immutable
BEFORE UPDATE OR DELETE ON public.islem_log
FOR EACH ROW EXECUTE FUNCTION public._islem_log_immutable_guard();

REVOKE DELETE, UPDATE, TRUNCATE ON public.islem_log FROM authenticated;
-- TRUNCATE ayrıca revoke edildi: TRUNCATE row-level BEFORE trigger'ları TETİKLEMEZ,
-- bu yüzden yukarıdaki trigger'ı tamamen bypass ederdi (canlıda kontrol edilip
-- authenticated'da hâlâ mevcut olduğu görülüp aynı migration turunda kapatıldı).
