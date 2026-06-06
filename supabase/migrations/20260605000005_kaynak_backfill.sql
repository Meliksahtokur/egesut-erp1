BEGIN;

-- ── 1. ILERI_GEBE → ILERI_GEBE-{hayvan_id} ────────────────────────────────
UPDATE public.gorev_log
SET kaynak = 'ILERI_GEBE-' || hayvan_id
WHERE kaynak = 'ILERI_GEBE'
  AND hayvan_id IS NOT NULL;

-- ── 2. BESLEME_OTOMATIK → BESLEME-{hayvan_id} ─────────────────────────────
UPDATE public.gorev_log
SET kaynak = 'BESLEME-' || hayvan_id
WHERE kaynak = 'BESLEME_OTOMATIK'
  AND hayvan_id IS NOT NULL;

-- ── 3. Backfill: protokol_instance — DOGUM protokolleri (anne) ────────────
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT
  substring(gl.kaynak FROM 7) AS hayvan_id,
  'UREME',
  'DOGUM',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih), CURRENT_DATE),
  CASE
    WHEN bool_or(gl.tamamlandi = false AND gl.iptal = false) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'DOGUM-%'
  AND gl.hayvan_id IS NOT NULL
  AND substring(gl.kaynak FROM 7) IN (SELECT id FROM public.hayvanlar)
GROUP BY gl.kaynak
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 4. Backfill: protokol_instance — TOHUMLAMA ────────────────────────────
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT
  gl.hayvan_id,
  'UREME',
  'TOHUMLAMA',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih) - 21, CURRENT_DATE),
  CASE
    WHEN bool_or(gl.tamamlandi = false AND gl.iptal = false) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'TOH-%'
  AND gl.hayvan_id IS NOT NULL
GROUP BY gl.kaynak, gl.hayvan_id
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 5. Backfill: protokol_instance — ILERI_GEBE (UREME/GEBELIK) ──────────
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT
  gl.hayvan_id,
  'UREME',
  'GEBELIK',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih) - 240, CURRENT_DATE),
  CASE
    WHEN bool_or(gl.tamamlandi = false AND gl.iptal = false) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'ILERI_GEBE-%'
  AND gl.hayvan_id IS NOT NULL
GROUP BY gl.kaynak, gl.hayvan_id
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 6. Backfill: protokol_instance — BESLEME (BAKIM/BESLEME) ─────────────
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT
  gl.hayvan_id,
  'BAKIM',
  'BESLEME',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih), CURRENT_DATE),
  CASE
    WHEN bool_or(gl.tamamlandi = false AND gl.iptal = false) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'BESLEME-%'
  AND gl.hayvan_id IS NOT NULL
GROUP BY gl.kaynak, gl.hayvan_id
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 7. Backfill: gorev_log.protokol_instance_id doldur ───────────────────
UPDATE public.gorev_log gl
SET protokol_instance_id = pi.id
FROM public.protokol_instance pi
WHERE gl.kaynak = pi.kaynak_ref
  AND gl.protokol_instance_id IS NULL;

COMMIT;
