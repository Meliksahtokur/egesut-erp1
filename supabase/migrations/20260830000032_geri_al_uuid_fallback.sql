-- Fix: geri_al guncellenen döngüsünde uuid PK fallback (operator does not exist: uuid = text)
-- Taban: canlı prod gövdesi (assets/geri_al_canli.sql), tek fark yukarıdaki fallback bloğu.

CREATE OR REPLACE FUNCTION public.geri_al(p_islem_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_snapshot  jsonb;
  v_item      jsonb;
  v_tablo     text;
  v_pk        text;
  v_onceki    jsonb;
  v_col       text;
  v_val       text;
  v_set_parts text[] := '{}';
  v_sql       text;
BEGIN
  SELECT snapshot INTO v_snapshot
  FROM islem_log
  WHERE id = p_islem_id;

  IF v_snapshot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'islem bulunamadi');
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';

    IF v_tablo = 'treatment_days' THEN
      -- Stok iade: iptal=true (audit trail korunur — DELETE değil)
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        WHERE da.treatment_day_id = v_pk::uuid
      );
      -- Tedavi günü sil (CASCADE: drug_administrations otomatik)
      DELETE FROM public.treatment_days WHERE id = v_pk::uuid;

    ELSIF v_tablo = 'cases' THEN
      -- TEDAVI_GUN gorev orphan temizliği (snapshot'ta değil, manuel sil)
      DELETE FROM public.gorev_log g
      WHERE g.gorev_tipi = 'TEDAVI_GUN'
        AND EXISTS (
          SELECT 1 FROM public.treatment_days td
          WHERE td.case_id = v_pk::uuid
            AND g.aciklama IS NOT NULL
            AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
        );

      -- Stok iade: tüm treatment_days için iptal=true
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        JOIN public.treatment_days td ON da.treatment_day_id = td.id
        WHERE td.case_id = v_pk::uuid
      );

      -- Case sil (CASCADE zinciri)
      DELETE FROM public.cases WHERE id = v_pk::uuid;

    ELSE
      BEGIN
        EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
      EXCEPTION WHEN others THEN
        EXECUTE format('DELETE FROM %I WHERE id = $1::uuid', v_tablo) USING v_pk;
      END;
    END IF;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'guncellenen')
  LOOP
    v_tablo  := v_item->>'tablo';
    v_pk     := v_item->>'id';
    v_onceki := v_item->'onceki';
    v_set_parts := '{}';

    FOR v_col, v_val IN SELECT key, value #>> '{}' FROM jsonb_each(v_onceki)
    LOOP
      v_set_parts := array_append(
        v_set_parts,
        format('%I = %L', v_col, v_val)
      );
    END LOOP;

    IF array_length(v_set_parts, 1) > 0 THEN
      v_sql := format(
        'UPDATE %I SET %s WHERE id = $1',
        v_tablo,
        array_to_string(v_set_parts, ', ')
      );
      BEGIN
        EXECUTE v_sql USING v_pk;
      EXCEPTION WHEN others THEN
        -- uuid PK'lı tablolar (tohumlama vb.) için tip fallback'i —
        -- 'olusturulan' döngüsündeki DELETE fallback'i ile aynı desen
        EXECUTE format(
          'UPDATE %I SET %s WHERE id = $1::uuid',
          v_tablo,
          array_to_string(v_set_parts, ', ')
        ) USING v_pk;
      END;
    END IF;
  END LOOP;

  UPDATE islem_log SET durum = 'geri_alindi' WHERE id = p_islem_id;
  RETURN jsonb_build_object('ok', true);
END;
$function$
;

NOTIFY pgrst, 'reload schema';
