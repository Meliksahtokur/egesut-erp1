-- ─────────────────────────────────────────────────────────────
-- stok_tuketim_view'a drug_product_id kolonu ekle
--
-- SORUN: loadDrugsCache (js/ui.js) ilaçları stok satırına
--   stok.drug_product_id === drug_product.id ile eşleştiriyor.
--   Ancak idb 'stok' store'u stok_tuketim_view'dan besleniyor ve
--   view bu kolonu dışa vermiyordu → eşleşme hep boş → markalı
--   ilaçların hepsi "stok yok" görünüyordu (Fulimed, Ketojezik,
--   Meloksikam vb.). Ayrıca her ilaç "legacy" fallback ile
--   kategori grubunda mükerrer listeleniyordu.
--
-- ÇÖZÜM: view SELECT'ine s.drug_product_id eklenir. s.id PK
--   olduğundan GROUP BY'a eklenmesi şart değil ama mevcut stille
--   uyum için eklendi.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.stok_tuketim_view AS
SELECT
  s.id,
  s.urun_adi,
  s.kategori,
  s.birim,
  s.baslangic_miktar,
  s.esik,
  COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) AS toplam_kullanim,
  s.baslangic_miktar - COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) AS guncel_stok,
  CASE
    WHEN s.baslangic_miktar - COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) <= 0
    THEN 'tukendi'
    WHEN s.baslangic_miktar - COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) <= s.esik
    THEN 'kritik'
    ELSE 'normal'
  END AS stok_durum,
  -- CREATE OR REPLACE ortaya kolon ekleyemediği için en sona eklendi
  s.drug_product_id
FROM public.stok s
LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
GROUP BY s.id, s.urun_adi, s.kategori, s.birim, s.baslangic_miktar, s.esik, s.drug_product_id;
