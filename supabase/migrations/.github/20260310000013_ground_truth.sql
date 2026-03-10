-- ═══════════════════════════════════════════════════════════════
-- Migration 013 — Ground Truth
-- Canlı DB ile repo farkları kapatıldı + eksik fonksiyonlar eklendi
-- Tümü idempotent
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- 1. EKSİK KOLONLAR
-- ──────────────────────────────────────────

-- hayvanlar
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS abort_sayisi integer DEFAULT 0;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kesim_kg     numeric;
-- NOT: hayvanlar.cins kolonu canlıda var ama COUNT=0, kullanılmıyor.
-- Temizlik sprint'inde DROP edilecek.

-- dogum
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS yavru_irk  text;
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- hastalik_log
ALTER TABLE public.hastalik_log ADD COLUMN IF NOT EXISTS kapanis_tarihi  date;
ALTER TABLE public.hastalik_log ADD COLUMN IF NOT EXISTS veteriner_notu  text;
ALTER TABLE public.hastalik_log ADD COLUMN IF NOT EXISTS created_at      timestamptz DEFAULT now();
-- NOT: hem kapanis_tarihi hem kapanma_tarihi var. forms.js kapanma_tarihi kullanıyor.

-- tohumlama
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS tohumlayan     text;
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS kontrol_tarihi date;
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS created_at     timestamptz DEFAULT now();

-- stok_hareket
ALTER TABLE public.stok_hareket ADD COLUMN IF NOT EXISTS tarih      timestamptz DEFAULT now();
ALTER TABLE public.stok_hareket ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- ──────────────────────────────────────────
-- 2. EKSİK FONKSİYONLAR
-- ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.cikis_yap(
  p_hayvan_id text,
  p_tip       text,
  p_tarih     date    DEFAULT CURRENT_DATE,
  p_sebep     text    DEFAULT NULL,
  p_fiyat     numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hayvanlar SET
    durum        = 'Pasif',
    cikis_tipi   = p_tip,
    cikis_tarihi = p_tarih,
    cikis_sebebi = p_sebep,
    satis_fiyati = CASE WHEN p_tip = 'satis' THEN p_fiyat ELSE satis_fiyati END
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif hayvan bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.geri_al(
  p_islem_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_log  record;
  v_item jsonb;
BEGIN
  SELECT * INTO v_log
  FROM public.islem_log
  WHERE id = p_islem_id AND durum = 'aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İşlem bulunamadı veya zaten geri alındı');
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_log.snapshot->'olusturulan') LOOP
    EXECUTE format('DELETE FROM public.%I WHERE id = $1', v_item->>'tablo')
      USING (v_item->>'id');
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_log.snapshot->'guncellenen') LOOP
    EXECUTE format(
      'UPDATE public.%I SET %s WHERE id = $1',
      v_item->>'tablo',
      (SELECT string_agg(key || ' = ' || quote_literal(value), ', ')
       FROM jsonb_each_text(v_item->'onceki'))
    ) USING (v_item->>'id');
  END LOOP;

  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE id = p_islem_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.cikis_yap(text,text,date,text,numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.geri_al(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
