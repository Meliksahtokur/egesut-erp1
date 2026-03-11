-- Migration 016 — islem_log ref_id/ref_tablo + hastalık yönetim RPC'leri
-- Supabase SQL Editor'dan çalıştır

-- ── 1. islem_log'a köprü kolonları ─────────────────────────────
ALTER TABLE public.islem_log
  ADD COLUMN IF NOT EXISTS ref_id    text,
  ADD COLUMN IF NOT EXISTS ref_tablo text;

-- Eski kayıtları snapshot'tan geriye doldur
UPDATE public.islem_log
SET
  ref_id    = snapshot->>'id',
  ref_tablo = CASE tip
    WHEN 'HASTALIK_KAYDI'   THEN 'hastalik_log'
    WHEN 'TOHUMLAMA'        THEN 'tohumlama'
    WHEN 'ABORT_KAYDI'      THEN 'tohumlama'
    WHEN 'DOGUM_KAYDI'      THEN 'dogum'
    WHEN 'HAYVAN_EKLENDI'   THEN 'hayvanlar'
    WHEN 'HAYVAN_GUNCELLENDI' THEN 'hayvanlar'
    WHEN 'KIZGINLIK'        THEN 'kizginlik_log'
    ELSE NULL
  END
WHERE ref_id IS NULL AND snapshot->>'id' IS NOT NULL;

-- ── 2. Trigger güncelle — ref_id ve ref_tablo doldursun ────────
CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip       text;
  v_hayvan_id text;
  v_snapshot  jsonb;
  v_ref_id    text;
  v_ref_tablo text;
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
      v_tip       := CASE TG_OP WHEN 'UPDATE' THEN 'ABORT_KAYDI' ELSE 'TOHUMLAMA' END;
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

-- Trigger'ları yeniden bağla (idempotent)
DROP TRIGGER IF EXISTS trg_islem_hastalik ON public.hastalik_log;
CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT OR UPDATE ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

-- ── 3. HASTALIK_GUNCELLE RPC ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_guncelle(
  p_id         text,
  p_tani       text    DEFAULT NULL,
  p_kategori   text    DEFAULT NULL,
  p_siddet     text    DEFAULT NULL,
  p_semptomlar text    DEFAULT NULL,
  p_lokasyon   text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    tani       = COALESCE(p_tani,       tani),
    kategori   = COALESCE(p_kategori,   kategori),
    siddet     = COALESCE(p_siddet,     siddet),
    semptomlar = COALESCE(p_semptomlar, semptomlar),
    lokasyon   = COALESCE(p_lokasyon,   lokasyon),
    hekim_id   = COALESCE(p_hekim_id,   hekim_id)
  WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ── 4. HASTALIK_KAPAT RPC ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_kapat(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    durum          = 'Kapandı',
    kapanma_tarihi = CURRENT_DATE
  WHERE id = p_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ── 5. HASTALIK_SIL RPC ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Bağlı tedavi görevlerini iptal et
  UPDATE public.gorev_log SET
    tamamlandi = true,
    notlar     = COALESCE(notlar, '') || ' [Hastalık kaydı silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;

  -- Asıl kaydı sil
  DELETE FROM public.hastalik_log WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ── 6. RLS & SECURITY DEFINER ───────────────────────────────────
ALTER FUNCTION public.hastalik_guncelle SECURITY DEFINER;
ALTER FUNCTION public.hastalik_kapat    SECURITY DEFINER;
ALTER FUNCTION public.hastalik_sil      SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
