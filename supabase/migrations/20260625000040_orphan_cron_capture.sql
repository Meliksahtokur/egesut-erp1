-- Migration: tohumlama_orphan_gorev_temizle ghost fonksiyonunu sabitle (davranış değişmez)
-- Tarih: 2026-06-25 — Spec §8 hijyen. Önceden yalnız ground_truth'ta vardı.

CREATE OR REPLACE FUNCTION public.tohumlama_orphan_gorev_temizle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_iptal_gorev1 integer;
  v_iptal_gorev2 integer;
  v_iptal_gorev3 integer;
  v_iptal_gorev  integer;
  v_iptal_inst   integer;
BEGIN
  -- 1) ref_tohumlama_id ile bağlı (eski sistem)
  UPDATE public.gorev_log g
    SET iptal = true
    WHERE g.tamamlandi = false
      AND g.iptal = false
      AND g.gorev_tipi IN ('GEBELIK_KONTROL', 'VETERINER_KONTROL', 'KIZGINLIK_TAKIP')
      AND g.ref_tohumlama_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE t.id::text = g.ref_tohumlama_id
          AND t.sonuc IN ('Boş', 'Abort')
      );
  GET DIAGNOSTICS v_iptal_gorev1 = ROW_COUNT;

  -- 2) kaynak ile bağlı (yeni sistem)
  UPDATE public.gorev_log g
    SET iptal = true
    WHERE g.tamamlandi = false
      AND g.iptal = false
      AND g.kaynak LIKE 'TOH-%'
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE 'TOH-' || t.id::text = g.kaynak
          AND t.sonuc IN ('Boş', 'Abort')
      );
  GET DIAGNOSTICS v_iptal_gorev2 = ROW_COUNT;

  -- 3) NULL kaynak + NULL ref — orphan, bağlı tohumlama Boş/Abort (yeni eklenen)
  UPDATE public.gorev_log g
    SET iptal = true
    WHERE g.tamamlandi = false
      AND g.iptal = false
      AND g.kaynak IS NULL
      AND g.ref_tohumlama_id IS NULL
      AND g.gorev_tipi IN ('GEBELIK_KONTROL', 'VETERINER_KONTROL', 'KIZGINLIK_TAKIP')
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE t.hayvan_id = g.hayvan_id
          AND t.sonuc IN ('Boş', 'Abort')
          AND t.tarih < g.hedef_tarih  -- orphan görev önce gelmiş
      );
  GET DIAGNOSTICS v_iptal_gorev3 = ROW_COUNT;

  v_iptal_gorev := v_iptal_gorev1 + v_iptal_gorev2 + v_iptal_gorev3;

  -- 4) protokol_instance — kaynak_ref bazlı
  UPDATE public.protokol_instance pi
    SET durum = 'iptal'
    WHERE pi.durum = 'aktif'
      AND pi.kaynak_ref LIKE 'TOH-%'
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE 'TOH-' || t.id::text = pi.kaynak_ref
          AND t.sonuc IN ('Boş', 'Abort')
      );
  GET DIAGNOSTICS v_iptal_inst = ROW_COUNT;

  RETURN jsonb_build_object(
    'iptal_gorev',  v_iptal_gorev,
    'iptal_gorev_ref_tohumlama', v_iptal_gorev1,
    'iptal_gorev_kaynak',        v_iptal_gorev2,
    'iptal_gorev_null_orphan',   v_iptal_gorev3,
    'iptal_inst',   v_iptal_inst,
    'zaman',        now()
  );
END;
$function$;