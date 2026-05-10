-- Migration: gorev_geri_al RPC
-- Etkiler: Tamamlanan görevi geri al — vaccination + stok + child sil
-- Geri alınabilir: DROP FUNCTION public.gorev_geri_al(text);

BEGIN;

CREATE OR REPLACE FUNCTION public.gorev_geri_al(
  p_gorev_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_id      uuid;
  v_child_count integer;
BEGIN
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF NOT v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten aktif');
  END IF;

  IF v_gorev.tamamlanma_tarihi < now() - interval '7 days' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', '7 günden eski görevler geri alınamaz');
  END IF;

  IF EXISTS (SELECT 1 FROM gorev_log WHERE parent_id = p_gorev_id::uuid AND tamamlandi = true) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Rapel görevi tamamlanmış, geri alınamaz');
  END IF;

  SELECT id INTO v_vax_id FROM vaccination_log
  WHERE notes LIKE '%GorevID:' || p_gorev_id || '%'
  ORDER BY created_at DESC LIMIT 1;

  IF v_vax_id IS NOT NULL THEN
    DELETE FROM stok_hareket WHERE referans_tipi = 'vaccination' AND referans_id = v_vax_id::text;
    DELETE FROM vaccination_log WHERE id = v_vax_id;
  END IF;

  SELECT COUNT(*) INTO v_child_count FROM gorev_log WHERE parent_id = p_gorev_id::uuid;
  DELETE FROM gorev_log WHERE parent_id = p_gorev_id::uuid;

  UPDATE gorev_log
  SET tamamlandi = false, tamamlanma_tarihi = null
  WHERE id = p_gorev_id::uuid;

  RETURN jsonb_build_object(
    'ok', true,
    'silinen_rapel', v_child_count,
    'silinen_asi_id', v_vax_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gorev_geri_al(text) TO anon, authenticated;

END;
