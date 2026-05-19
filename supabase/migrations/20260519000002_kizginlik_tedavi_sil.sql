-- ============================================================
-- kizginlik_tedavi_sil
-- kizginlik_log'a tedavi_case_id + cozuldu kolonları
-- kizginlik_sil RPC (kayıt sil + varsa case kapat)
-- Vaka kapanınca kızgınlığı otomatik kapatma trigger'ı
-- kizginlik_tedavi_baglanti_kur RPC (manuel bağlantı)
-- ============================================================

BEGIN;

-- 1. kizginlik_log'a kolon ekle
ALTER TABLE public.kizginlik_log
  ADD COLUMN IF NOT EXISTS tedavi_case_id uuid REFERENCES public.cases(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cozuldu       boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.kizginlik_log.tedavi_case_id IS 'Opsiyonel vaka bağlantısı — cases.id FK';
COMMENT ON COLUMN public.kizginlik_log.cozuldu        IS 'true = tedavi edildi / kapatıldı';

CREATE INDEX IF NOT EXISTS kizginlik_log_cozuldu_idx ON public.kizginlik_log(cozuldu);

-- 2. kizginlik_sil RPC
CREATE OR REPLACE FUNCTION public.kizginlik_sil(p_kayit_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan_id text;
  v_case_id   uuid;
BEGIN
  SELECT hayvan_id, tedavi_case_id INTO v_hayvan_id, v_case_id
  FROM public.kizginlik_log WHERE id = p_kayit_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Kayıt bulunamadı');
  END IF;
  DELETE FROM public.kizginlik_log WHERE id = p_kayit_id;
  IF v_case_id IS NOT NULL THEN
    UPDATE public.cases
    SET status = 'closed', closed_at = now()
    WHERE id = v_case_id AND status = 'active';
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.kizginlik_sil(text) TO anon, authenticated;

-- 3. Vaka kapanınca kızgınlık kapatma trigger
CREATE OR REPLACE FUNCTION public._kizginlik_case_close()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'closed' AND OLD.status = 'active' THEN
    UPDATE public.kizginlik_log
    SET cozuldu = true
    WHERE tedavi_case_id = NEW.id AND cozuldu = false;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_kizginlik_case_close ON public.cases;
CREATE TRIGGER trg_kizginlik_case_close
  AFTER UPDATE OF status ON public.cases
  FOR EACH ROW
  WHEN (NEW.status = 'closed' AND OLD.status = 'active')
  EXECUTE FUNCTION public._kizginlik_case_close();

-- 4. kizginlik_tedavi_baglanti_kur RPC
CREATE OR REPLACE FUNCTION public.kizginlik_tedavi_baglanti_kur(p_kayit_id text, p_case_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.kizginlik_log
  SET tedavi_case_id = p_case_id,
      cozuldu       = true
  WHERE id = p_kayit_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Kayıt bulunamadı');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.kizginlik_tedavi_baglanti_kur(text, uuid) TO anon, authenticated;

COMMIT;
