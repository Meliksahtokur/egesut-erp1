-- Görevde MUTLAKA var olması istenen nesneler. Çıktı: eksik olanların listesi (boş = tamam).
SET search_path TO pg_catalog;
WITH t(n) AS (VALUES ('hayvanlar'),('tohumlama'),('dogum'),('gorev_log'),('islem_log'),('cases'),('treatment_days'),
  ('treatment_day_uygulamalar'),('drug_administrations'),('drug_classes'),('drug_products'),('stok'),('stok_hareket'),
  ('uygulama_log'),('protokol_instance'),('protokol_ayar'),('tedavi_sablonu'),('tedavi_sablonu_kalem'),
  ('sablon_hastalik_eslem'),('diseases'),('kizginlik_log')),
f(n) AS (VALUES ('dogum_kaydet'),('tohumlama_kaydet'),('planli_tohumlama_kaydet'),('tohumlama_abort'),('hizli_uygulama'),
  ('hizli_uygulama_geri_al'),('bulk_ilac'),('seans_tamamla'),('close_case_with_remaining'),('tedavi_sablon_uygula'),
  ('tedavi_sablon_tohumlama_gorev_ekle'),('_vaka_ac_tek'),('add_treatment_day_with_sessions'),('_tohumlama_gorev_uygunluk'),
  ('_etken_kod_bul'),('protokol_eksik_tara'),
  -- surum_gizli köprüsü (UI geri alma yolu): bu 4'ü degisim_geri_al'in doğrudan çağırdığı
  ('degisim_geri_al'),('degisim_onizle'),('geri_alma_bileti_al'),('sahip_sifresi_ayarla')),
-- surum_gizli: degisim_geri_al'in bağımlı olduğu 4 tablo + 12 fonksiyon (görev kapsamı)
sg_t(n) AS (VALUES ('sahip_sifresi'),('geri_alma_bileti'),('geri_alma_kullanim'),('l4_rehber_adimlari')),
sg_f(n) AS (VALUES ('_cagiran'),('_degisim_plan'),('_degisim_uygula'),('_ekle_bagli'),('_guncel_satir'),('_kapsamda'),
  ('_l4_rehber_uyesi'),('_l4_zaman_txid'),('_l4_zincir'),('_pk_gorunum'),('_pk_json'),('_pk_kolonlar'))
SELECT 'tablo ' || n FROM t WHERE NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r' AND c.relname = t.n)
UNION ALL
SELECT 'fonksiyon ' || n FROM f WHERE NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = f.n)
UNION ALL
SELECT 'surum_gizli tablo ' || n FROM sg_t WHERE NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relnamespace = 'surum_gizli'::regnamespace AND c.relkind = 'r' AND c.relname = sg_t.n)
UNION ALL
SELECT 'surum_gizli fonksiyon ' || n FROM sg_f WHERE NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'surum_gizli'::regnamespace AND p.proname = sg_f.n)
UNION ALL
SELECT 'protokol_instance.kaynak_ref UNIQUE' WHERE NOT EXISTS (
  SELECT 1 FROM pg_index i JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
  WHERE i.indrelid = 'public.protokol_instance'::regclass AND i.indisunique AND i.indnatts = 1
    AND i.indpred IS NULL AND a.attname = 'kaynak_ref')
UNION ALL
SELECT 'islem_log immutability trigger (UPDATE+DELETE)' WHERE NOT EXISTS (
  SELECT 1 FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
  WHERE t.tgrelid = 'public.islem_log'::regclass AND NOT t.tgisinternal AND t.tgenabled <> 'D'
    AND p.proname = '_islem_log_immutable_guard' AND (t.tgtype & 8) <> 0 AND (t.tgtype & 16) <> 0)
UNION ALL
SELECT 'tohumlama triggerlari (hic yok)'
  FROM pg_trigger t WHERE t.tgrelid = 'public.tohumlama'::regclass AND NOT t.tgisinternal HAVING count(*) = 0;
