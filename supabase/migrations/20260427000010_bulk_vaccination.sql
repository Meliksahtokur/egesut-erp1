-- ============================================================
-- Bulk Vaccination RPC
-- Allows vaccinating multiple animals at once via a single RPC call.
-- Reads existing add_vaccination function for pattern reference:
--   migration 20260331000032_vaccination_module.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.bulk_vaccination(
  p_animal_ids  text[],
  p_vaccine_id  text,
  p_date        date,
  p_dose_ml     numeric DEFAULT NULL,
  p_notes       text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_animal_id   text;
  v_result      jsonb;
  v_success     int := 0;
  v_errors      jsonb := '[]'::jsonb;
BEGIN
  FOREACH v_animal_id IN ARRAY p_animal_ids LOOP
    v_result := public.add_vaccination(v_animal_id, p_vaccine_id::uuid, p_date, p_dose_ml, p_notes);
    IF (v_result->>'ok')::boolean THEN
      v_success := v_success + 1;
    ELSE
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('animal_id', v_animal_id, 'error', v_result->>'mesaj')
      );
    END IF;
  END LOOP;
  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$$;

-- Allow anon/authenticated clients to call this RPC
GRANT EXECUTE ON FUNCTION public.bulk_vaccination TO anon, authenticated;