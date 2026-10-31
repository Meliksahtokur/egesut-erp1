-- ============================================================================
-- Migration: 20261005000002_v_stat_vaka
-- Tarih: 2026-10-05 · istatistik F0 Task 3 (plan P3 — spec §5.2, K7-K9)
-- Etkiler: 1 yeni view public.v_stat_vaka (vaka başına bir satır, salt-okuma)
--   + COMMENT + ACL. Tablo/fonksiyon/veri değişikliği YOK; cases/treatment_days/
--   drug_administrations yalnız okunur (domain-rules §13.9).
-- security_invoker: çağıranın RLS'i uygulanır (spec §5.1); farm filtresi yok (K14).
-- Kurallar (preflight R2-R4, R9-R12):
--   * "uygulanmış" = drug_administrations.uygulanmadi IS NOT TRUE (NULL uygulanmış sayılır).
--   * kapanis = (closed_at AT TIME ZONE 'Europe/Istanbul')::date, yalnız status='closed';
--     bugün = (now() AT TIME ZONE 'Europe/Istanbul')::date (CURRENT_DATE yok, TZ dersi).
--   * sonuc sırası (ilk eşleşen): 1 oldu_kesildi → 2 nuks → 3 iyilesti → 4 devam.
--   * olay_gun negatifse NULL; ters tarihli vakada vaka_suresi_gun NULL.
--   * protokol_uyum yalnız en az bir uygulama günü varsa (ilaçsız vaka NULL, plan RF3).
--   * maliyet_tl = Σ dose × stok.maliyet (stok_id bağı, maliyet > 0); katkı yoksa NULL.
-- Idempotent: CREATE OR REPLACE VIEW; ikinci koşum no-op.
-- Geri alma: DROP VIEW IF EXISTS public.v_stat_vaka; (ledger "Demo geri alma listesi" R19).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE VIEW public.v_stat_vaka WITH (security_invoker = true) AS
WITH uygulama AS (
  -- tedavi günü × uygulama satırı (uygulaması olmayan gün de plan_gun için kalır)
  SELECT td.case_id,
         td.id AS gun_id,
         td.treatment_date,
         (a.id IS NOT NULL AND a.uygulanmadi IS NOT TRUE) AS uygulandi,
         COALESCE(dp.brand_name, s.urun_adi) AS urun,
         COALESCE(dc.class_name, dc.group_name) AS sinif,
         CASE WHEN s.maliyet > 0 THEN a.dose * s.maliyet END AS maliyet_katki
  FROM public.treatment_days td
  LEFT JOIN public.drug_administrations a ON a.treatment_day_id = td.id
  LEFT JOIN public.drug_products dp ON dp.id = a.drug_product_id
  LEFT JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
  LEFT JOIN public.stok s ON s.id = a.stok_id
), vaka_uygulama AS (
  SELECT u.case_id,
         count(DISTINCT u.gun_id) AS plan_gun,
         count(DISTINCT u.treatment_date) FILTER (WHERE u.uygulandi) AS uygulanan_gun,
         min(u.treatment_date) FILTER (WHERE u.uygulandi) AS ilk_uygulama,
         max(u.treatment_date) FILTER (WHERE u.uygulandi) AS son_uygulama,
         array_agg(DISTINCT u.urun ORDER BY u.urun)
           FILTER (WHERE u.uygulandi AND u.urun IS NOT NULL) AS protokol,
         array_agg(DISTINCT u.sinif ORDER BY u.sinif)
           FILTER (WHERE u.uygulandi AND u.sinif IS NOT NULL) AS protokol_sinif,
         sum(u.maliyet_katki) FILTER (WHERE u.uygulandi) AS maliyet_tl
  FROM uygulama u
  GROUP BY u.case_id
), kapanisli AS (
  SELECT c.id, c.animal_id, c.disease_id, c.start_date, c.status, c.protocol_family,
         CASE WHEN c.status = 'closed'
              THEN (c.closed_at AT TIME ZONE 'Europe/Istanbul')::date END AS kapanis
  FROM public.cases c
), olayli AS (
  SELECT k.*,
         CASE WHEN k.kapanis >= k.start_date THEN k.kapanis - k.start_date END AS vaka_suresi_gun,
         h.cikis_tipi, h.cikis_tarihi,
         (SELECT min(n.start_date)                        -- R12: (kapanis, kapanis+30] içinde ilk nüks
            FROM public.cases n
           WHERE n.animal_id = k.animal_id AND n.disease_id = k.disease_id AND n.id <> k.id
             AND n.start_date > k.kapanis AND n.start_date <= k.kapanis + 30) AS nuks_baslangic
  FROM kapanisli k
  LEFT JOIN public.hayvanlar h ON h.id = k.animal_id
), sonuclu AS (
  SELECT o.*,
         CASE                                             -- spec §5.2 sırası, ilk eşleşen kazanır
           WHEN o.cikis_tipi IN ('olum', 'kesim')
                AND (o.status = 'active' OR o.cikis_tarihi <= o.kapanis + 30) THEN 'oldu_kesildi'
           WHEN o.nuks_baslangic IS NOT NULL THEN 'nuks'
           WHEN o.status = 'closed' THEN 'iyilesti'
           ELSE 'devam'
         END AS sonuc
  FROM olayli o
), olay_hesap AS (
  SELECT s.*,
         CASE s.sonuc
           WHEN 'oldu_kesildi' THEN s.cikis_tarihi - s.start_date
           WHEN 'nuks'         THEN s.nuks_baslangic - s.start_date
           WHEN 'iyilesti'     THEN s.vaka_suresi_gun
           ELSE (now() AT TIME ZONE 'Europe/Istanbul')::date - s.start_date
         END AS olay_ham
  FROM sonuclu s
)
SELECT v.id::uuid                                        AS vaka_id,
       v.animal_id::text                                 AS hayvan_id,
       d.name::text                                      AS hastalik,
       d.category::text                                  AS kategori,
       v.protocol_family::text                           AS protokol_ailesi,
       v.start_date::date                                AS baslangic,
       v.kapanis::date                                   AS kapanis,
       v.vaka_suresi_gun::int                            AS vaka_suresi_gun,
       vu.ilk_uygulama::date                             AS ilk_uygulama,
       vu.son_uygulama::date                             AS son_uygulama,
       (vu.son_uygulama - vu.ilk_uygulama + 1)::int      AS tedavi_suresi_gun,
       COALESCE(vu.uygulanan_gun, 0)::int                AS uygulanan_gun,
       COALESCE(vu.plan_gun, 0)::int                     AS plan_gun,
       (CASE WHEN vu.uygulanan_gun > 0
             THEN round(vu.uygulanan_gun::numeric / NULLIF(vu.plan_gun, 0), 3)
        END)::numeric(5,3)                               AS protokol_uyum,
       COALESCE(vu.protokol, '{}')::text[]               AS protokol,
       COALESCE(vu.protokol_sinif, '{}')::text[]         AS protokol_sinif,
       v.sonuc::text                                     AS sonuc,
       (CASE WHEN v.olay_ham >= 0 THEN v.olay_ham END)::int AS olay_gun,
       (v.sonuc = 'devam')::boolean                      AS sansur,
       round(vu.maliyet_tl, 2)::numeric(12,2)            AS maliyet_tl
FROM olay_hesap v
JOIN public.diseases d ON d.id = v.disease_id
LEFT JOIN vaka_uygulama vu ON vu.case_id = v.id;

COMMENT ON VIEW public.v_stat_vaka IS
  'İstatistik tedavi pilotu (spec §5.2, K7-K9): vaka başına bir satır. Sınırlamalar: şiddet alanı yok, '
  'süreler dağılım (medyan + Q1/Q3) olarak okunur, ortalama tek başına basılmaz; ilaç karşılaştırması '
  'yalnız aynı hastalık ve aynı dönem içinde anlamlıdır; oldu_kesildi yalnız cikis_tipi olum|kesim '
  '(satis/kayip ölüm sayılmaz; küme 2026-10-05 demo+prod {kesim,olum,satis,NULL}); maliyet_tl güncel '
  'stok.maliyet ile, fiyat geçmişi ve birim dönüşümü yok.';

REVOKE ALL ON TABLE public.v_stat_vaka FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.v_stat_vaka TO authenticated;

COMMIT;
