-- Sütten kesme listener trigger'ları
-- BEFORE: kesim sinyali → atomik senkron (tarih+grup+padok) + 40g sert alt sınır
-- AFTER : protokol_instance + gorev_log lifecycle (kapat / undo'da aç)
-- NOT: AFTER UPDATE (kolon belirtmeden) — BEFORE trigger tarihi SET listesi dışında değiştirebilir.
BEGIN;

CREATE OR REPLACE FUNCTION public.trg_sutten_kesme_normalize()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_wgrup constant text := 'Sütten Kesilmiş Buzağı';
  v_wpadok record;
  v_signal boolean := false;
  v_kesim_tarihi date;
  v_min numeric;
BEGIN
  -- 1) tarih/grup sinyali (ucuz)
  IF (NEW.suttten_kesme_tarihi IS NOT NULL AND OLD.suttten_kesme_tarihi IS NULL)
     OR (NEW.grup = v_wgrup AND OLD.grup IS DISTINCT FROM v_wgrup) THEN
    v_signal := true;
  END IF;
  -- 2) padok sinyali (yalnız padok değiştiyse lookup yap — perf)
  IF NOT v_signal AND NEW.padok IS DISTINCT FROM OLD.padok THEN
    SELECT * INTO v_wpadok FROM public.padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' ORDER BY id LIMIT 1;
    IF FOUND AND NEW.padok = v_wpadok.ad THEN v_signal := true; END IF;
  END IF;

  IF v_signal THEN
    v_kesim_tarihi := COALESCE(NEW.suttten_kesme_tarihi, CURRENT_DATE);
    IF NEW.dogum_tarihi IS NULL THEN
      RAISE EXCEPTION 'Sütten kesim için doğum tarihi gerekli (hayvan %)', NEW.id;
    END IF;
    v_min := public._ayar('sutten_kesme_erken_uyari', 40);
    IF (v_kesim_tarihi - NEW.dogum_tarihi) < v_min THEN
      RAISE EXCEPTION 'Çok erken sütten kesim: % gün (min %)', (v_kesim_tarihi - NEW.dogum_tarihi), v_min;
    END IF;
    -- weaned padok'u her zaman çek (record alanına koşulsuz erişim güvenli)
    SELECT * INTO v_wpadok FROM public.padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' ORDER BY id LIMIT 1;
    NEW.suttten_kesme_tarihi := v_kesim_tarihi;
    NEW.grup := v_wgrup;
    IF FOUND THEN
      NEW.padok := v_wpadok.ad;
      NEW.padok_id := v_wpadok.id;
    ELSE
      RAISE WARNING 'weaned padok bulunamadı (Sütten Kesilmiş) — padok güncellenmedi';
    END IF;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_sutten_kesme_normalize ON public.hayvanlar;
CREATE TRIGGER trg_sutten_kesme_normalize
  BEFORE UPDATE ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public.trg_sutten_kesme_normalize();

CREATE OR REPLACE FUNCTION public.trg_sutten_kesme_kapat()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.suttten_kesme_tarihi IS NULL AND NEW.suttten_kesme_tarihi IS NOT NULL THEN
    UPDATE public.gorev_log
       SET tamamlandi=true, tamamlanma_tarihi=now(), kapatan_ref='trg-sutten-kes'
     WHERE hayvan_id=NEW.id AND gorev_tipi='SUTTEN_KESME' AND tamamlandi=false AND iptal=false;
    UPDATE public.protokol_instance
       SET durum='tamamlandi', kapandi_at=now(), kapandi_sebep='TAMAMLANDI'
     WHERE kaynak_ref='SUTTENKES-'||NEW.id AND durum='aktif';
  ELSIF OLD.suttten_kesme_tarihi IS NOT NULL AND NEW.suttten_kesme_tarihi IS NULL THEN
    UPDATE public.protokol_instance
       SET durum='aktif', kapandi_at=NULL, kapandi_sebep=NULL
     WHERE kaynak_ref='SUTTENKES-'||NEW.id AND durum='tamamlandi';
    UPDATE public.gorev_log
       SET tamamlandi=false, tamamlanma_tarihi=NULL
     WHERE hayvan_id=NEW.id AND gorev_tipi='SUTTEN_KESME' AND kapatan_ref='trg-sutten-kes';
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_sutten_kesme_kapat ON public.hayvanlar;
CREATE TRIGGER trg_sutten_kesme_kapat
  AFTER UPDATE ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public.trg_sutten_kesme_kapat();

COMMIT;
