-- Migration: Protokol Uyarı Sistemi — uygulama_log + hizli_uygulama RPC'ler (Task 6-8)
-- Etkiler: yeni uygulama_log tablosu, hizli_uygulama RPC, hizli_uygulama_geri_al RPC
-- Bağımlılık: 20260603000001_protokol_etken_kod.sql (_etken_kod_bul, _gorev_dinle)

BEGIN;

-- ============================================================
-- Task 6: uygulama_log Tablosu
-- ============================================================

CREATE TABLE IF NOT EXISTS public.uygulama_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  stok_id text REFERENCES public.stok(id),
  etken_kod text,
  doz numeric NOT NULL,
  birim text NOT NULL,
  rota text NOT NULL CHECK (rota IN ('IM','IV','SC','PO','Topikal','Intrauterin')),
  tarih date NOT NULL DEFAULT CURRENT_DATE,
  notlar text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_uygulama_log_hayvan ON public.uygulama_log(hayvan_id);
CREATE INDEX IF NOT EXISTS idx_uygulama_log_tarih ON public.uygulama_log(tarih);

COMMENT ON TABLE public.uygulama_log IS 'Case-free hızlı ilaç/vitamin uygulama kaydı — görev dinleme trigger tetikler';

ALTER TABLE public.uygulama_log ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='uygulama_log' AND policyname='anon_all_uygulama_log') THEN
    CREATE POLICY anon_all_uygulama_log ON public.uygulama_log FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.uygulama_log TO anon, authenticated;

-- ============================================================
-- Task 7: hizli_uygulama RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_rota text,
  p_notlar text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_stok record;
  v_etken text;
  v_id uuid;
  v_kalan numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  IF p_notlar IS NULL OR TRIM(p_notlar) = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Not alanı zorunludur');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- Stok düşüm
  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid()::text, p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0)
  );
END;
$$;

-- ============================================================
-- Task 8: hizli_uygulama_geri_al RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.hizli_uygulama_geri_al(
  p_uygulama_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uyg record;
  v_hayvan record;
BEGIN
  SELECT * INTO v_uyg FROM public.uygulama_log WHERE id = p_uygulama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Uygulama kaydı bulunamadı');
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_uyg.hayvan_id;

  -- Stok iade (ters hareket)
  IF v_uyg.stok_id IS NOT NULL THEN
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid()::text, v_uyg.stok_id, 'İade (Hızlı Uyg.)', -v_uyg.doz,
            'Geri Al — ' || COALESCE(v_hayvan.kupe_no, v_uyg.hayvan_id), false);
  END IF;

  -- Bu uygulama ile kapanan görevi tekrar aç
  UPDATE public.gorev_log
  SET tamamlandi = false,
      tamamlanma_tarihi = NULL,
      kapatan_ref = NULL
  WHERE kapatan_ref = 'uygulama_log:' || p_uygulama_id::text;

  DELETE FROM public.uygulama_log WHERE id = p_uygulama_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

COMMIT;
