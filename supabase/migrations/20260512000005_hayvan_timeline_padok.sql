-- Migration: timeline view'da padok değişikliğini vurgula
-- HAYVAN_GUNCELLENDI event'lerinde snapshot->old->padok_id vs snapshot->new->padok_id karşılaştırması
BEGIN;

DROP VIEW IF EXISTS public.hayvan_timeline_view;

CREATE VIEW public.hayvan_timeline_view AS
-- Doğum
SELECT
  d.anne_id                        AS hayvan_id,
  'DOGUM_KAYDI'                    AS tip,
  'birth_recorded'                 AS event_type,
  d.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'yavru_kupe', d.yavru_kupe,
    'yavru_cins', d.yavru_cins,
    'dogum_tipi', d.dogum_tipi,
    'dogum_kg',   d.dogum_kg,
    'hekim_id',   d.hekim_id
  )                                AS detay,
  d.id                             AS kaynak_id
FROM public.dogum d

UNION ALL

-- Tohumlama
SELECT
  t.hayvan_id,
  'TOHUMLAMA'                      AS tip,
  'insemination_performed'         AS event_type,
  t.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'sperma',      t.sperma,
    'sonuc',       t.sonuc,
    'deneme_no',   t.deneme_no,
    'hekim_id',    t.hekim_id
  )                                AS detay,
  t.id::text                       AS kaynak_id
FROM public.tohumlama t

UNION ALL

-- Hastalık
SELECT
  hl.hayvan_id,
  'HASTALIK_KAYDI'                 AS tip,
  'treatment_recorded'             AS event_type,
  hl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'tani',      hl.tani,
    'kategori',  hl.kategori,
    'siddet',    hl.siddet,
    'durum',     hl.durum,
    'hekim_id',  hl.hekim_id
  )                                AS detay,
  hl.id                            AS kaynak_id
FROM public.hastalik_log hl

UNION ALL

-- Kızgınlık
SELECT
  kl.hayvan_id,
  'KIZGINLIK'                      AS tip,
  'estrus_detected'                AS event_type,
  kl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'belirti', kl.belirti,
    'notlar',  kl.notlar
  )                                AS detay,
  kl.id                            AS kaynak_id
FROM public.kizginlik_log kl

UNION ALL

-- Hayvan Güncellemeleri (islem_log'dan, PADOK_ODAKLI)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  CASE
    -- Padok değişikliği varsa detaya ekle
    WHEN il.snapshot ? 'old' AND il.snapshot->'old' ? 'padok_id'
         AND il.snapshot->'old'->>'padok_id' IS DISTINCT FROM il.snapshot->'new'->>'padok_id'
    THEN jsonb_build_object(
      'padok_degisti', true,
      'eski_padok', il.snapshot->'old'->>'padok',
      'yeni_padok', il.snapshot->'new'->>'padok',
      'eski_padok_id', il.snapshot->'old'->>'padok_id',
      'yeni_padok_id', il.snapshot->'new'->>'padok_id'
    )
    ELSE jsonb_build_object('padok_degisti', false)
  END                               AS detay,
  il.id                             AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('HAYVAN_GUNCELLENDI', 'HAYVAN_EKLENDI')

UNION ALL

-- Diğer islem_log tipleri (ABORT, SATIS, OLUM, SUTTEN_KESME)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  COALESCE(il.payload->'meta', il.snapshot) AS detay,
  il.id                            AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('ABORT_KAYDI', 'SATIS_KAYDI', 'OLUM_KAYDI', 'SUTTEN_KESME')

ORDER BY zaman DESC;

GRANT SELECT ON public.hayvan_timeline_view TO anon, authenticated;

COMMIT;