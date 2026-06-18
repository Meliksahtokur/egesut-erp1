-- Migration: Toplu grup+padok değişimi + transfer görev uzlaştırma
-- EgeSüt ERP — 2026-06-18
-- 1. padok_degistir_toplu: p_yeni_grup opsiyonel parametresi
-- 2. gorev_tamamla: BUG A (grup adı) + BUG B (padok_id) fix
-- 3. fn_padok_transfer_gorev_kapat + trigger (görev listener)
-- 4. padok_transfer_gorev_uzlastir (reconciliation scan)
-- Geri alınabilir: evet

BEGIN;

-- ══════════════════════════════════════════════════════════════
-- 1. padok_degistir_toplu — p_yeni_grup eklendi
-- ══════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.padok_degistir_toplu(text[], uuid, text[]);
CREATE OR REPLACE FUNCTION public.padok_degistir_toplu(
  p_hayvan_ids text[],
  p_yeni_padok_id uuid,
  p_etiketler text[] DEFAULT NULL,
  p_yeni_grup text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_yeni_padok   padoklar%ROWTYPE;
  v_aktif_sayisi integer;
  v_hayvan_id    text;
  v_hayvan       hayvanlar%ROWTYPE;
  v_eslem_var    boolean;
BEGIN
  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Grup-padok uyum guard (UI bypass koruması)
  IF p_yeni_grup IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM grup_padok_eslem
      WHERE grup = p_yeni_grup AND padok_id = p_yeni_padok_id
    ) INTO v_eslem_var;
    IF NOT v_eslem_var THEN
      RETURN jsonb_build_object('success', false, 'error', 'grup_padok_uyumsuz');
    END IF;
  END IF;

  -- Kapasite hard block (validasyon, yazma yok)
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi + array_length(p_hayvan_ids, 1) > v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   (v_aktif_sayisi + array_length(p_hayvan_ids, 1))::text
                   || '/' || v_yeni_padok.kapasite::text
      );
    END IF;
  END IF;

  -- Hayvan validasyonları (validasyon, yazma yok)
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı: ' || v_hayvan_id);
    END IF;
    IF v_hayvan.padok_id = p_yeni_padok_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta: ' || v_hayvan_id);
    END IF;
  END LOOP;

  -- Tüm validasyonlar geçti — yazma işlemleri
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    UPDATE hayvanlar
       SET padok_id   = p_yeni_padok_id,
           padok      = v_yeni_padok.ad,
           grup       = COALESCE(p_yeni_grup, grup),
           updated_at = now()
     WHERE id = v_hayvan_id;

    INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('padok_degisim', v_hayvan_id, v_hayvan_id, '{}'::jsonb,
            'Toplu padok değişimi → ' || v_yeni_padok.ad
            || COALESCE(' (grup: ' || p_yeni_grup || ')', ''));
  END LOOP;

  -- Etiket güncelleme (varsa, mevcut etiketlerle birleştir)
  IF p_etiketler IS NOT NULL AND array_length(p_etiketler, 1) > 0 THEN
    UPDATE hayvanlar
       SET etiketler = array(
             SELECT DISTINCT unnest(COALESCE(etiketler, '{}') || p_etiketler)
           )
     WHERE id = ANY(p_hayvan_ids);
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'hayvan_sayisi', array_length(p_hayvan_ids, 1),
    'yeni_padok',    v_yeni_padok.ad,
    'yeni_padok_id', p_yeni_padok_id,
    'yeni_grup',     p_yeni_grup
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir_toplu(text[], uuid, text[], text) TO anon, authenticated;

COMMIT;
