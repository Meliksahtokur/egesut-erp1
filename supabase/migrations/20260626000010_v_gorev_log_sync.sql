-- Migration: v_gorev_log_sync — client sync cap fix (açıklar hep + son 300 kapalı)
-- Tarih: 2026-06-26 — Spec §2 Faz 1. Kolon düzeni gorev_log ile birebir (client SELECT *).
CREATE OR REPLACE VIEW public.v_gorev_log_sync AS
  SELECT * FROM public.gorev_log WHERE NOT tamamlandi AND NOT iptal
  UNION ALL
  SELECT * FROM (
    SELECT * FROM public.gorev_log
    WHERE (tamamlandi OR iptal)
    ORDER BY created_at DESC NULLS LAST
    LIMIT 300
  ) kapali;