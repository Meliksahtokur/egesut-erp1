-- ═══ Migration: hizli_uygulama p_bbirim typo fix ═══
-- Tarih: 2026-06-13
-- Yazar: Pi agent (MiniMax-M3)
-- Bug: küpe 136 Ademin görevi tamamlanamıyor (Hata: column "p_bbirim" does not exist)
-- Scope: 32 hayvan, 62 aktif ILERI_GEBE görevi (ADEMIN + E_VIT)
-- Ref: docs/plans/2026-06-13-hizli-uygulama-p-bbirim-typo-fix.md

-- ═══ 1. PRE-CHECK ═══
-- prosrc'te typo var mı, fonksiyon hangi tanım?
DO $$
DECLARE
  v_has_typo boolean;
  v_def text;
BEGIN
  SELECT prosrc LIKE '%p_bbirim%', pg_get_functiondef('public.hizli_uygulama'::regproc)
    INTO v_has_typo, v_def
  FROM pg_proc WHERE proname = 'hizli_uygulama';

  IF NOT v_has_typo THEN
    RAISE NOTICE '[hizli_uygulama p_bbirim fix] prosrc''te typo YOK — migration gerekli değil (idempotent skip)';
  ELSE
    RAISE NOTICE '[hizli_uygulama p_bbirim fix] prosrc''te typo VAR — fix uygulanıyor';
  END IF;
END $$;

-- ═══ 2. FIX: CREATE OR REPLACE ═══
-- İmza korunur, gövdede sadece VALUES satırındaki p_bbirim → p_birim düzeltildi
CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id   text,
  p_doz       numeric,
  p_birim     text,
  p_rota      text,
  p_notlar    text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hayvan hayvanlar%ROWTYPE;
  v_stok   record;
  v_etken  text;
  v_id     uuid;
  v_kalan  numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)  -- FIX: p_bbirim → p_birim
  RETURNING id INTO v_id;

  -- islem_log audit (BUG-064 Fix #2)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES (
    'HIZLI_UYGULAMA',
    p_hayvan_id,
    v_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','uygulama_log','id',v_id::text)),
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb
    ),
    format('Hızlı Uygulama — %s — %s %s %s', v_hayvan.kupe_no, v_stok.urun_adi, p_doz, p_birim)
  );

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz,
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
$function$;

-- ═══ 3. POST-CHECK ═══
DO $$
DECLARE
  v_has_typo boolean;
  v_has_correct boolean;
BEGIN
  SELECT
    prosrc LIKE '%p_bbirim%',
    prosrc LIKE '%p_birim%'
  INTO v_has_typo, v_has_correct
  FROM pg_proc WHERE proname = 'hizli_uygulama';

  IF v_has_typo THEN
    RAISE EXCEPTION '[hizli_uygulama p_bbirim fix] BAŞARISIZ — prosrc''te hâlâ p_bbirim var';
  END IF;
  IF NOT v_has_correct THEN
    RAISE EXCEPTION '[hizli_uygulama p_bbirim fix] BAŞARISIZ — p_birim bulunamadı';
  END IF;
  RAISE NOTICE '[hizli_uygulama p_bbirim fix] BAŞARILI — typo düzeltildi, doğru parametre korundu';
END $$;

-- ═══ 4. SCHEMA RELOAD ═══
NOTIFY pgrst, 'reload schema';
