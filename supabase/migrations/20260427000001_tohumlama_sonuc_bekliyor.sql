-- Migration: tohumlama_sonuc_bekliyor RPC
-- Reverts tohumlama from 'Boş' to 'Bekliyor' state
-- Reverts hayvanlar.tohumlama_durumu from islem_log snapshot

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bekliyor(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_islem_id          text := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_onceki_toh_sonuc  text;
  v_snapshot          jsonb;
  v_hayvan_snapshot   jsonb;
BEGIN
  -- 1. Find tohumlama by id, require sonuc is 'Boş'
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Only 'Boş' can be reverted to 'Bekliyor'
  IF v_toh.sonuc != 'Boş' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Boş durumundaki tohumlama Bekliyor yapılabilir');
  END IF;

  -- Save current tohumlama.sonuc for logging
  v_onceki_toh_sonuc := v_toh.sonuc;

  -- 2. Get previous hayvanlar.tohumlama_durumu from islem_log (snapshot of BOS_ATAMA event)
  SELECT snapshot INTO v_snapshot
  FROM public.islem_log
  WHERE ref_id = p_tohumlama_id
    AND ref_tablo = 'tohumlama'
    AND tip = 'TOHUMLAMA_SONUC'
  ORDER BY tarih DESC
  LIMIT 1;

  IF v_snapshot IS NOT NULL THEN
    -- Extract previous tohumlama_durumu from snapshot
    SELECT elem->'onceki'->>'tohumlama_durumu' INTO v_onceki_durum
    FROM jsonb_array_elements(v_snapshot->'guncellenen') AS elem
    WHERE elem->>'tablo' = 'hayvanlar';
  END IF;

  -- Fallback: if no snapshot found, default to 'Tohumlanabilir'
  IF v_onceki_durum IS NULL THEN
    v_onceki_durum := 'Tohumlanabilir';
  END IF;

  -- 3. Set tohumlama.sonuc = 'Bekliyor'
  UPDATE public.tohumlama SET sonuc = 'Bekliyor' WHERE id::text = p_tohumlama_id;

  -- 4. Revert hayvanlar.tohumlama_durumu to prior state
  UPDATE public.hayvanlar
  SET tohumlama_durumu = v_onceki_durum
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  -- 5. Write islem_log with tip='TOHUMLAMA_SONUC'
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA_SONUC',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_onceki_toh_sonuc)
        ),
        jsonb_build_object(
          'tablo', 'hayvanlar',
          'id', v_toh.hayvan_id,
          'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum)
        )
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
