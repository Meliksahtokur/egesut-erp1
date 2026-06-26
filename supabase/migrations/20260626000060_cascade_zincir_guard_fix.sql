-- Migration: cascade/orphan zincir-guard (4 zincir tipini koru)
-- Tarih: 2026-06-26 — Spec §3 düzeltme.
-- Aynı-tip zincir (BESLEME, BUZAGI_BAKIM, TEDAVI_GUN, ILERI_GEBE_ASI): parent kapanınca dokunma.
-- Farklı-tip containment: parent kapanınca çocuğu iptal et.
-- View'da parent_id zincir tipli ise tamamlanmış parent'ı muaf tut.
-- Trigger fonksiyonunu ve view'ı sıfırdan CREATE OR REPLACE ediyoruz.

CREATE OR REPLACE FUNCTION public._trg_gorev_parent_kapandi()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.gorev_log
       SET iptal = true, kapatan_ref = 'parent-silindi'
     WHERE parent_id = OLD.id AND NOT tamamlandi AND NOT iptal
       AND gorev_tipi NOT IN ('BESLEME','BUZAGI_BAKIM','TEDAVI_GUN','ILERI_GEBE_ASI');
    RETURN OLD;
  END IF;
  IF (NEW.tamamlandi OR NEW.iptal) AND NOT (OLD.tamamlandi OR OLD.iptal) THEN
    UPDATE public.gorev_log c
       SET iptal = true, kapatan_ref = 'parent-kapandi'
     WHERE c.parent_id = NEW.id AND NOT c.tamamlandi AND NOT c.iptal
       AND c.gorev_tipi <> NEW.gorev_tipi;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE VIEW public.v_orphan_gorev AS
  SELECT g.*
  FROM public.gorev_log g
  WHERE NOT g.tamamlandi AND NOT g.iptal
    AND (
      NOT EXISTS (SELECT 1 FROM public.hayvanlar h WHERE h.id = g.hayvan_id AND h.durum = 'Aktif')
      OR (g.parent_id IS NOT NULL
          AND g.gorev_tipi NOT IN ('BESLEME','BUZAGI_BAKIM','TEDAVI_GUN','ILERI_GEBE_ASI')
          AND NOT EXISTS (SELECT 1 FROM public.gorev_log p WHERE p.id = g.parent_id))
      OR (g.parent_id IS NOT NULL
          AND EXISTS (SELECT 1 FROM public.gorev_log p
                        WHERE p.id = g.parent_id AND (p.tamamlandi OR p.iptal) AND p.gorev_tipi <> g.gorev_tipi))
    );