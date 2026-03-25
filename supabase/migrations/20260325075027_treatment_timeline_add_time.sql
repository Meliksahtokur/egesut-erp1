-- ══════════════════════════════════════════════════════════════
-- MIGRATION 026 — treatment_timeline view'a treatment_time ekle
-- EgeSüt ERP — 2026-03-25
--
-- Sorun: treatment_days.treatment_time kolonu view'a dahil
--        edilmemişti. JS tarafı r.treatment_time okuyunca
--        undefined alıyor, saat hiç gösterilmiyordu.
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.treatment_timeline AS
SELECT
  h.id              AS animal_id,
  h.kupe_no,
  c.id              AS case_id,
  c.status          AS case_status,
  c.start_date      AS case_start,
  dis.name          AS disease,
  dis.category      AS disease_category,
  td.id             AS day_id,
  td.day_no,
  td.treatment_date,
  dp.id             AS drug_id,
  COALESCE(dp.brand_name, s.urun_adi, '?') AS drug,
  da.id             AS administration_id,
  da.dose,
  da.unit,
  da.route,
  da.notes          AS admin_notes,
  da.stok_id,
  td.treatment_time
FROM treatment_days td
  JOIN  cases             c   ON c.id   = td.case_id
  JOIN  hayvanlar         h   ON h.id   = c.animal_id
  JOIN  diseases          dis ON dis.id = c.disease_id
  LEFT JOIN drug_administrations da  ON da.treatment_day_id = td.id
  LEFT JOIN drug_products        dp  ON dp.id = da.drug_product_id
  LEFT JOIN stok                 s   ON s.id  = da.stok_id;

NOTIFY pgrst, 'reload schema';
