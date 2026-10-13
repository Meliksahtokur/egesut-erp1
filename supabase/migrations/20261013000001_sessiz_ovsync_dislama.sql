-- ════════════════════════════════════════════════════════════════════
-- K1 — Sessiz listeden aktif Ovsync dışlama (sahip kararı 2026-10-13)
-- "Ovsync'teki hayvan sessiz listede görünmez — hayvan Ovsync'teyse zaten
-- takiptedir, işlemdedir, başıboş değildir."
--
-- Gövde CANLI pg_get_functiondef('public.sessiz_hayvanlar_listele'::regproc)
-- çıktısından türetildi (2026-10-13 MEASURED); imza, dönüş tipi, SECURITY,
-- search_path ve GRANT'lar birebir korunur. TEK değişiklik: WHERE'e aktif
-- OVSYNC dışlama koşulu (cases.status='active' AND protocol_family='OVSYNC').
-- v_eligible'a DOKUNULMAZ (başka tüketicileri var: reconcile, stat_suru_ozet).
-- anon'a GRANT YOK (canlı ACL: authenticated + service_role).
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- squawk hijyeni: fonksiyon yeniden tanımı öncesinde timeout'lar
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(p_padok text DEFAULT NULL::text, p_min_gun integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN (SELECT COALESCE(jsonb_agg(
    jsonb_build_object('hayvan_id', e.id, 'kupe_no', e.kupe_no, 'grup', e.grup, 'padok', e.padok,
      'sessiz_gun', COALESCE(e.sessiz_gun, 9999), 'son_aktivite', e.son_aktivite_tarihi)
    ORDER BY COALESCE(e.sessiz_gun, 9999) DESC), '[]'::jsonb)
  FROM public.v_eligible e
  WHERE (p_padok IS NULL OR e.padok = p_padok) AND COALESCE(e.sessiz_gun, 9999) >= p_min_gun
    -- K1: aktif OVSYNC vakası olan hayvan sessiz listede görünmez.
    -- Kapalı vaka ve OVSYNC-dışı aktif vaka düşürmez (domain-rules :138 korunur).
    AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = e.id AND c.status = 'active' AND c.protocol_family = 'OVSYNC'));
END;
$function$;

-- ACL — canlı ile birebir (2026-10-13 MEASURED: authenticated + service_role;
-- anon/PUBLIC EXECUTE YOK): idempotent yeniden-kaplama, anon'a GRANT YOK.
REVOKE ALL ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
