-- Migration: genel islem_geri_al — snapshot'taki old değerleri geri yükle
-- HAYVAN_GUNCELLENDI ve GOREV_GUNCELLENDI destekler
BEGIN;

CREATE OR REPLACE FUNCTION public.islem_geri_al(
  p_islem_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_islem record;
  v_old jsonb;
  v_tablo text;
  v_id text;
  v_col text;
  v_val jsonb;
  v_sets text[] := ARRAY[]::text[];
  v_pairs text;
BEGIN
  -- İşlemi bul
  SELECT * INTO v_islem FROM public.islem_log WHERE id = p_islem_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Islem bulunamadi');
  END IF;

  IF v_islem.durum = 'geri_alindi' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem zaten geri alinmis');
  END IF;

  -- Snapshot'ta old objesi var mı?
  v_old := v_islem.snapshot->'old';
  IF v_old IS NULL OR v_old = 'null'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem icin geri alma verisi bulunamadi. Sadece yeni islemler destekleniyor.');
  END IF;

  -- Hedef tabloyu belirle
  CASE v_islem.tip
    WHEN 'HAYVAN_GUNCELLENDI' THEN
      -- old'daki tüm kolonları geri yükle (id hariç)
      FOR v_col, v_val IN SELECT * FROM jsonb_each(v_old)
      LOOP
        IF v_col != 'id' THEN
          -- #>> '{}' jsonb değerini text'e çevirir (tırnakları kaldırır)
          v_sets := array_append(v_sets, format('%I = %L', v_col, v_val #>> '{}'));
        END IF;
      END LOOP;
      v_pairs := array_to_string(v_sets, ', ');
      EXECUTE format('UPDATE hayvanlar SET %s WHERE id = %L', v_pairs, v_old->>'id');

    WHEN 'GOREV_GUNCELLENDI' THEN
      -- Görev geri alma
      FOR v_col, v_val IN SELECT * FROM jsonb_each(v_old)
      LOOP
        IF v_col != 'id' THEN
          v_sets := array_append(v_sets, format('%I = %L', v_col, v_val #>> '{}'));
        END IF;
      END LOOP;
      v_pairs := array_to_string(v_sets, ', ');
      EXECUTE format('UPDATE gorev_log SET %s WHERE id = %L', v_pairs, v_old->>'id');

    ELSE
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem tipi icin geri alma desteklenmiyor: ' || v_islem.tip);
  END CASE;

  -- İşlemi geri alındı olarak işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi',
      geri_alma_tarihi = now()
  WHERE id = p_islem_id;

  RETURN jsonb_build_object('ok', true, 'mesaj', 'Islem geri alindi');
END;
$$;

GRANT EXECUTE ON FUNCTION public.islem_geri_al(text) TO anon, authenticated;

COMMIT;