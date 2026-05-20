-- Migration: ileri_gebe_view kaldır — dashboard RPC sonucu kullanıyor
-- Etkiler: DROP VIEW public.ileri_gebe_view
-- Geri alınabilir: migration 20260519000001'deki tanım

BEGIN;

DROP VIEW IF EXISTS public.ileri_gebe_view;

COMMIT;
