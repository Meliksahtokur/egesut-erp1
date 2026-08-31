-- Tablo-seviyesi guard trigger'ları — 2026-08-31
--
-- Gerekçe: RPC guard'ları (tohumlama_kaydet'teki 12ay/Erkek kontrolü vb.) yalnızca
-- fonksiyon yolunu korur; doğrudan SQL INSERT (seed data) ve REST bypass'ı
-- fonksiyonu atlar. Tablo trigger'ı tek enforcement noktası olarak tüm yazma
-- yollarını kapsar. RPC guard'ları yerinde kalır (savunma derinliği).
-- Eşik değişmedi: 365 gün (12 ay) — kullanıcı onayı 2026-08-31 ("12 ay kalabilir").
-- Canlı veri doğrulaması: 6 ihlal sayacının 6'sı da 0 (deploy öncesi) → mevcut
-- satırların UPDATE'leri kırılmaz.
--
-- Erkek↔grup kuralı frontend'in aynasıdır (app.js: "Erkek hayvan Sağmal/Kuru/Gebe
-- grubuna eklenemez"); tohumlama yaş eşiği v_eligible/tohumlama_kaydet ile aynıdır
-- (tohumlama anındaki yaş kullanılır: NEW.tarih - dogum_tarihi).

-- 1) hayvanlar: Erkek ↔ Sağmal/Gebe grubu engeli + ileri doğum tarihi reddi
CREATE OR REPLACE FUNCTION public._guard_hayvanlar_cinsiyet_grup()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.cinsiyet = 'Erkek' AND (NEW.grup ILIKE 'Sağmal%' OR NEW.grup ILIKE 'Gebe%') THEN
    RAISE EXCEPTION 'Erkek hayvan Sağmal/Gebe grubuna eklenemez (grup: %)', NEW.grup;
  END IF;
  IF NEW.dogum_tarihi IS NOT NULL
     AND NEW.dogum_tarihi > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Doğum tarihi ileri tarih olamaz: %', NEW.dogum_tarihi;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_hayvanlar_guard ON public.hayvanlar;
CREATE TRIGGER trg_hayvanlar_guard
  BEFORE INSERT OR UPDATE OF cinsiyet, grup, dogum_tarihi ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public._guard_hayvanlar_cinsiyet_grup();

-- 2) tohumlama: Erkek hayvan reddi + bilinen doğum tarihinde tohumlama anındaki
--    yaş < 365 gün reddi (bilinmeyen doğum tarihi geçer — RPC guard'ıyla aynı)
CREATE OR REPLACE FUNCTION public._guard_tohumlama_yas_cinsiyet()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_cinsiyet text;
  v_dogum    date;
BEGIN
  SELECT cinsiyet, dogum_tarihi INTO v_cinsiyet, v_dogum
    FROM public.hayvanlar WHERE id = NEW.hayvan_id;
  IF NOT FOUND THEN
    RETURN NEW; -- hayvan referansı çözülemiyor: FK/yetki katmanı ilgilenir
  END IF;
  IF v_cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama kaydı yapılamaz (hayvan: %)', NEW.hayvan_id;
  END IF;
  IF v_dogum IS NOT NULL AND (NEW.tarih - v_dogum) < 365 THEN
    RAISE EXCEPTION '12 aydan küçük hayvana tohumlama kaydı yapılamaz (tohumlama anındaki yaş: % gün)', (NEW.tarih - v_dogum);
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_tohumlama_guard ON public.tohumlama;
CREATE TRIGGER trg_tohumlama_guard
  BEFORE INSERT OR UPDATE OF hayvan_id, tarih ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public._guard_tohumlama_yas_cinsiyet();

-- 3) dogum: ileri tarih reddi (dogum_kaydet RPC'sinde kontrol yoktu — docs
--    tutarlılık denetimi ⚠️8; RPC gövdesine dokunmak yerine tablo katmanı)
CREATE OR REPLACE FUNCTION public._guard_dogum_ileri_tarih()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tarih IS NOT NULL
     AND NEW.tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Doğum tarihi ileri tarih olamaz: %', NEW.tarih;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_dogum_guard ON public.dogum;
CREATE TRIGGER trg_dogum_guard
  BEFORE INSERT OR UPDATE OF tarih ON public.dogum
  FOR EACH ROW EXECUTE FUNCTION public._guard_dogum_ileri_tarih();
