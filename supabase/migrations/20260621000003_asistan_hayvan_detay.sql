-- Tek hayvanın 360° özeti (asistan tool'u)
BEGIN;

CREATE OR REPLACE FUNCTION public.asistan_hayvan_detay(p_kupe text DEFAULT NULL, p_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_h record;
  v_out jsonb;
BEGIN
  SELECT * INTO v_h FROM hayvanlar
   WHERE (p_id IS NOT NULL AND id = p_id)
      OR (p_kupe IS NOT NULL AND kupe_no = p_kupe)
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('bulundu', false);
  END IF;

  v_out := jsonb_build_object(
    'bulundu', true,
    'hayvan', to_jsonb(v_h),
    'tohumlama', (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.tarih DESC), '[]'::jsonb)
                  FROM tohumlama t WHERE t.hayvan_id = v_h.id),
    'gorevler', (SELECT coalesce(jsonb_agg(to_jsonb(g) ORDER BY g.created_at DESC), '[]'::jsonb)
                 FROM gorev_log g WHERE g.hayvan_id = v_h.id),
    'uygulamalar', (SELECT coalesce(jsonb_agg(to_jsonb(u) ORDER BY u.created_at DESC), '[]'::jsonb)
                    FROM uygulama_log u WHERE u.hayvan_id = v_h.id),
    'islem_log', (SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.tarih DESC), '[]'::jsonb)
                  FROM islem_log i WHERE i.ana_hayvan_id = v_h.id)
  );
  RETURN v_out;
END $$;

REVOKE ALL ON FUNCTION public.asistan_hayvan_detay(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asistan_hayvan_detay(text, text) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
COMMIT;
