-- Migration: v_orphan_gorev — orphan tanımı tek yerde (parent gitmiş/kapanmış VEYA hayvan aktif değil)
-- Tarih: 2026-06-26 — Spec §2 Faz 3.
CREATE OR REPLACE VIEW public.v_orphan_gorev AS
  SELECT g.*
  FROM public.gorev_log g
  WHERE NOT g.tamamlandi AND NOT g.iptal
    AND (
      (g.parent_id IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM public.gorev_log p
         WHERE p.id = g.parent_id AND NOT p.tamamlandi AND NOT p.iptal))
      OR NOT EXISTS (
         SELECT 1 FROM public.hayvanlar h
         WHERE h.id = g.hayvan_id AND h.durum = 'Aktif')
    );