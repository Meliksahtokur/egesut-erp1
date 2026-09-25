-- ============================================================================
-- Migration: 20260925000009_sessiz_reconcile_esik50
-- Tarih: 2026-09-25 · Cila-onarım K1 (mimar incelemesi A1: eşik 55'e geri dönme)
-- Etkiler: public.sessiz_hayvanlar_reconcile() gövdesi (CREATE OR REPLACE, imza değişmez)
--
-- HATA: 20260925000008, sessiz_hayvanlar_reconcile'ı BAYAT 20260625000020
--   gövdesinden yeniden yazdı; 20260925000002'nin sahibin onaylı 50 günlük
--   eşiğini (spec-s2 §5A) üret ve kapat bacaklarında 55'e GERİ DÖNDÜRDÜ
--   (listele/stat/v_eligible 50'de kalınca tutarsızlık; KAPAT bacağı 50–54 gün
--   sessiz hayvanın meşru görevini 'sessiz-noteligible' diye iptal etti).
--   000008 başlığındaki "önceki gövde 20260625000020" iddiası da yanlıştı
--   (önceki gövde = 20260925000002; 000008 onun üzerine değil bayat gövde
--   üzerine yazmıştı).
-- ONARIM: 000008'İN protocol_family guard'ı (R1 sonsuz döngü kesintisi)
--   KORUNARAK yalnızca üret+kapat eşikleri 50'ye çekilir. Gövde zinciri:
--   20260625000020 (55) → 20260925000002 (50) → 20260925000008 (55 + guard)
--   → 20260925000009 (50 + guard). ACL dokunulmaz; anon GRANT yazılmaz.
-- Geri alınabilir: evet — önceki canlı gövde (000008) CREATE OR REPLACE ile
--   geri yazılır.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_reconcile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uretilen  integer := 0;
  v_kapatilan integer := 0;
  v_rec       record;
BEGIN
  -- 1) ÜRET: eligible + açık SESSIZ görevi yok + son 30 günde kullanıcı-tamamlaması yok
  --    + aktif protocol_family vakası YOK (20260925000008: vakalı hayvana SESSIZ
  --    görev üretilmez — aksi halde R1 temizliği cron ile dirilip sonsuz döngü kurar)
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun
    FROM public.v_eligible e
    WHERE e.sessiz_gun >= 50
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = false AND g.iptal = false
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = true
          AND g.tamamlanma_tarihi >= (CURRENT_DATE - 30)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.cases c
        WHERE c.animal_id = e.id
          AND c.status = 'active'
          AND c.protocol_family IS NOT NULL
      )
  LOOP
    INSERT INTO public.gorev_log
      (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
    VALUES (
      gen_random_uuid(), v_rec.id, 'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', v_rec.sessiz_gun, v_rec.kupe_no),
      CURRENT_DATE, false, false, 'SESSIZ-' || v_rec.id
    );
    v_uretilen := v_uretilen + 1;
  END LOOP;

  -- 2) KAPAT: açık SESSIZ görevi var ama artık eligible değil (auto-close, cooldown SAYMAZ)
  UPDATE public.gorev_log g
  SET iptal = true, kapatan_ref = 'sessiz-noteligible'
  WHERE g.gorev_tipi = 'VETERINER_KONTROL'
    AND g.kaynak LIKE 'SESSIZ-%'
    AND g.tamamlandi = false AND g.iptal = false
    AND NOT EXISTS (
      SELECT 1 FROM public.v_eligible e
      WHERE e.id = g.hayvan_id AND e.sessiz_gun >= 50
    );
  GET DIAGNOSTICS v_kapatilan = ROW_COUNT;

  RETURN jsonb_build_object('uretilen', v_uretilen, 'kapatilan', v_kapatilan, 'zaman', now());
END;
$function$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000009_sessiz_reconcile_esik50 (K1)
