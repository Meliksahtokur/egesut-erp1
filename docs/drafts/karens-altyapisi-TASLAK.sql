-- ============================================================================
-- ⚠️  TASLAK — DEPLOY EDİLEMEZ. BİLİNEN HATA VAR (aşağıda). ⚠️
--
--   Bu dosya bilerek supabase/migrations/ DIŞINDA tutuluyor: oradaki her dosya
--   main'e merge'te deploy.yml tarafından canlıya uygulanır. Tamamlanınca
--   20260716000001_karens_altyapisi.sql adıyla oraya taşınacak.
--
--   DURUM (2026-07-16): şema + türetme mantığı canlı şemaya karşı ROLLBACK'li
--   test edildi, çalışıyor. Sonuçlar: 137 aktif hayvan, 536 karens üreten
--   uygulama (ASI=378 TEDAVI=89 UYGULAMA=69), 46 hayvan BILINMIYOR, 91 TEMIZ.
--
--   🐞 AÇIK HATA — fail-safe deliniyor, düzeltilmeden deploy EDİLMEMELİ:
--      hayvan_karens_uygulama_view'daki CROSS JOIN LATERAL _karens_bul(...),
--      drug_product_id NULL olan satırlarda sıfır satır döndürüyor ve uygulamayı
--      view'dan SESSİZCE DÜŞÜRÜYOR. Canlıda drug_administrations'ın 158 satırının
--      62'sinde drug_product_id NULL → bu uygulamalar karens hesabına hiç girmiyor
--      → hayvan yanlışlıkla TEMIZ görünebilir. Aynı hata (b) yolunda elle yazılmış:
--      WHERE s.drug_product_id IS NOT NULL o satırları filtreliyor (73→69).
--
--      DÜZELTME YÖNÜ: CROSS JOIN LATERAL → LEFT JOIN LATERAL ... ON true, ve
--      NULL filtreleri kaldır. Ürün bağlantısı bilinmeyen uygulama KAYBOLMAMALI,
--      sut_saat/et_gun NULL ile gelip BILINMIYOR üretmeli. Ayrıca ürünü
--      stok üzerinden kurtar: COALESCE(da.drug_product_id, s.drug_product_id)
--      (mevcut _etken_kod_bul aynı fallback desenini kullanıyor).
--
--   AÇIK TASARIM SORUSU: karens etken maddede mi (drug_classes) ürün seviyesinde
--      mi (drug_products) otorite olmalı? Taslak ikisini de destekliyor (ürün
--      NULL → sınıftan miras). Aynı etken maddenin LA/IMM formülasyonları farklı
--      karens verdiği için ürün ezmesi korunmalı.
--
--   YAPILMADI: numune görevi üretimi (süt arınması + 1 günde NUMUNE gorev_log
--      kaydı), hayvan kartı sağlık bölümü UI, kiloya göre dozaj.
--
--   KARENS DEĞERLERİ BİLEREK BOŞ: prospektüsten girilecek (karens_guncelle RPC).
--      Değer uydurmak gıda güvenliği riskidir.
-- ============================================================================

-- ============================================================================
-- Migration: Karens (ilaç kalıntı süresi) altyapısı — süt + et arınma takibi
-- Tarih: 2026-07-16
--
-- NEDEN: Sistem ilaç uygulamasını, dozu, stok düşümünü ve etken maddeyi biliyor
--   ama uygulanan hayvanın sütünün/etinin ne zaman gıda zincirine girebileceğini
--   BİLMİYORDU. Süt sığırcılığında bu, sistemin çözmesi gereken en kritik uyum
--   sorusudur: antibiyotikli süt tanka giderse tüm tank imha edilir.
--
-- TASARIM — üç karar:
--
--   (1) Karens SAKLANMAZ, TÜRETİLİR. stok_hareket ledger'ındaki prensibin aynısı:
--       hayvana "karens_bitis" kolonu yazmıyoruz. Uygulama tarihi + ürün karensi
--       her okumada yeniden hesaplanır. Saklanan değer cache'tir, cache drift eder;
--       türetilen değer edemez. Karens geriye dönük düzeltilirse (yanlış girilmiş
--       prospektüs değeri) tüm geçmiş kendiliğinden doğrulanır.
--
--   (2) İKİ SEVİYE: drug_classes = etken madde varsayılanı, drug_products = ürün
--       ezmesi. Ürün NULL ise sınıftan miras alır (_karens_bul COALESCE).
--       Neden iki seviye: karens formülasyona bağlıdır, etken maddeye değil —
--       aynı kloksasilin IMM ile LA formunda farklı arınma verir. Ama her ürüne
--       ayrı ayrı girmek de angarya. Etken maddeye bir kere gir, formülasyon
--       farkı olanı ürün seviyesinde ez.
--
--   (3) NULL ASLA "TEMİZ" DEĞİLDİR — fail-safe. Karens değeri girilmemiş bir
--       ilaç uygulanmışsa view 'BILINMIYOR' der, 'TEMIZ' demez. Bilinmeyeni
--       temiz saymak, bu sistemin engellemek için var olduğu hatanın ta kendisi.
--       Bilinmiyor penceresi protokol_ayar.karens_bilinmiyor_pencere_gun ile
--       sınırlanır (varsayılan 90 gün) — 2 yıl önceki bilinmeyen uygulama
--       hayvanı sonsuza kadar şüpheli bırakmasın.
--
-- KAPSAM: Bu migration SADECE şema + türetme altyapısı kurar. Karens DEĞERLERİ
--   BOŞ gelir — prospektüsten girilecek (UI: karens_guncelle). Değer uydurmak
--   gıda güvenliği riskidir; boş bırakmak fail-safe'tir.
--
-- Bağımlılıklar: drug_classes/drug_products (20260710000001 etken_kod otoritesi),
--   add_drug_administration, add_vaccination, protokol_ayar
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ŞEMA — karens kolonları (etken madde varsayılanı + ürün ezmesi + aşı)
-- ============================================================================

ALTER TABLE public.drug_classes  ADD COLUMN IF NOT EXISTS sut_karens_saat integer;
ALTER TABLE public.drug_classes  ADD COLUMN IF NOT EXISTS et_karens_gun   integer;
ALTER TABLE public.drug_products ADD COLUMN IF NOT EXISTS sut_karens_saat integer;
ALTER TABLE public.drug_products ADD COLUMN IF NOT EXISTS et_karens_gun   integer;
ALTER TABLE public.vaccines      ADD COLUMN IF NOT EXISTS sut_karens_saat integer;
ALTER TABLE public.vaccines      ADD COLUMN IF NOT EXISTS et_karens_gun   integer;

COMMENT ON COLUMN public.drug_classes.sut_karens_saat IS
  'Etken madde VARSAYILAN süt karensi (saat). drug_products.sut_karens_saat NULL ise buradan miras alınır. '
  'NULL = bilinmiyor → view TEMIZ demez, BILINMIYOR der.';
COMMENT ON COLUMN public.drug_classes.et_karens_gun IS
  'Etken madde VARSAYILAN et karensi (gün). drug_products.et_karens_gun NULL ise buradan miras alınır.';
COMMENT ON COLUMN public.drug_products.sut_karens_saat IS
  'Ürün süt karensi (saat) — prospektüsten. NULL ise drug_classes varsayılanı kullanılır. '
  'Formülasyon farkı olan ürünlerde (LA, IMM) sınıf varsayılanını EZMEK için doldurulur.';
COMMENT ON COLUMN public.drug_products.et_karens_gun IS
  'Ürün et karensi (gün) — prospektüsten. NULL ise drug_classes varsayılanı kullanılır.';
COMMENT ON COLUMN public.vaccines.sut_karens_saat IS
  'Aşı süt karensi (saat). Çoğu aşıda 0 (karens yok) — ama 0 ile NULL FARKLIDIR: '
  '0 = karens yok (bilinen), NULL = bilinmiyor.';
COMMENT ON COLUMN public.vaccines.et_karens_gun IS
  'Aşı et karensi (gün). 0 = karens yok (bilinen), NULL = bilinmiyor.';

-- Bilinmiyor penceresi — protokol_ayar (min/max sınırlı, UI'dan ayarlanabilir)
INSERT INTO public.protokol_ayar (anahtar, deger, birim, min_deger, max_deger, aciklama)
VALUES (
  'karens_bilinmiyor_pencere_gun', 90, 'gün', 30, 365,
  'Karens değeri girilmemiş bir uygulamanın hayvanı kaç gün "BILINMIYOR" tutacağı. '
  'Bu pencereden eski bilinmeyen uygulamalar yok sayılır (makul azami karens süresi).'
)
ON CONFLICT (anahtar) DO NOTHING;

-- ============================================================================
-- 2. _karens_bul — ürün → sınıf miras zinciri (tek otorite noktası)
--    İlaç yolu: p_drug_product_id. Aşı yolu: p_vaccine_id.
--    Dönüş: (sut_saat, et_gun). Her ikisi de NULL olabilir = bilinmiyor.
-- ============================================================================

CREATE OR REPLACE FUNCTION public._karens_bul(
  p_drug_product_id uuid DEFAULT NULL,
  p_vaccine_id      uuid DEFAULT NULL
) RETURNS TABLE (sut_saat integer, et_gun integer)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  -- Aşı yolu: miras yok, aşının kendi değeri
  SELECT v.sut_karens_saat, v.et_karens_gun
  FROM public.vaccines v
  WHERE p_vaccine_id IS NOT NULL AND v.id = p_vaccine_id

  UNION ALL

  -- İlaç yolu: ürün değeri, NULL ise etken madde (sınıf) varsayılanı
  SELECT COALESCE(dp.sut_karens_saat, dc.sut_karens_saat),
         COALESCE(dp.et_karens_gun,   dc.et_karens_gun)
  FROM public.drug_products dp
  LEFT JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
  WHERE p_drug_product_id IS NOT NULL AND dp.id = p_drug_product_id

  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public._karens_bul(uuid, uuid) TO anon, authenticated;

-- ============================================================================
-- 3. hayvan_karens_uygulama_view — üç uygulama yolunun birleşimi
--    (a) drug_administrations → treatment_days → cases → hayvan  (tedavi seansı)
--    (b) uygulama_log → hayvan                                    (tekil uygulama)
--    (c) vaccination_log → hayvan                                 (aşı)
--
--    Saat bilinmiyorsa 23:59 varsayılır — FAIL-SAFE: karens daha GEÇ biter.
--    uygulanmadi=true kayıtlar hariç (uygulanmamış ilaç karens yaratmaz).
-- ============================================================================

CREATE OR REPLACE VIEW public.hayvan_karens_uygulama_view AS
-- (a) Tedavi seansı yolu
SELECT
  c.animal_id                                   AS hayvan_id,
  'TEDAVI'::text                                AS kaynak,
  da.id                                         AS kaynak_id,
  (td.treatment_date + COALESCE(td.treatment_time, time '23:59'))::timestamptz AS uygulama_an,
  td.treatment_date                             AS uygulama_tarih,
  k.sut_saat, k.et_gun
FROM public.drug_administrations da
JOIN public.treatment_days td ON td.id = da.treatment_day_id
JOIN public.cases c           ON c.id  = td.case_id
CROSS JOIN LATERAL public._karens_bul(da.drug_product_id, NULL) k
WHERE COALESCE(da.uygulanmadi, false) = false

UNION ALL

-- (b) Tekil uygulama yolu (stok → drug_product zinciri)
SELECT
  u.hayvan_id,
  'UYGULAMA'::text,
  u.id,
  (u.tarih + time '23:59')::timestamptz,
  u.tarih,
  k.sut_saat, k.et_gun
FROM public.uygulama_log u
JOIN public.stok s ON s.id = u.stok_id
CROSS JOIN LATERAL public._karens_bul(s.drug_product_id, NULL) k
WHERE s.drug_product_id IS NOT NULL

UNION ALL

-- (c) Aşı yolu
SELECT
  vl.animal_id,
  'ASI'::text,
  vl.id,
  (vl.vaccination_date + time '23:59')::timestamptz,
  vl.vaccination_date,
  k.sut_saat, k.et_gun
FROM public.vaccination_log vl
CROSS JOIN LATERAL public._karens_bul(NULL, vl.vaccine_id) k;

COMMENT ON VIEW public.hayvan_karens_uygulama_view IS
  'Karens üreten her uygulama (tedavi + tekil + aşı), tek akışta. hayvan_karens_view bunun üstünde toplar.';

-- ============================================================================
-- 4. hayvan_karens_view — hayvan başına AKTİF karens durumu
--    "En yüksek karens kazanır" — uygulama fazında birden çok ilaç varsa
--    en geç biten arınma hayvanın durumunu belirler (max bitiş).
--
--    durum:  KARENSTE   → aktif karens var (bitis gelecekte)
--            BILINMIYOR → pencere içinde karensi girilmemiş uygulama var
--            TEMIZ      → tüm uygulamalar bilinen ve karensleri bitmiş
--    BILINMIYOR, TEMIZ'i EZER (fail-safe).
-- ============================================================================

CREATE OR REPLACE VIEW public.hayvan_karens_view AS
WITH pencere AS (
  SELECT COALESCE(
    (SELECT deger FROM public.protokol_ayar WHERE anahtar = 'karens_bilinmiyor_pencere_gun'),
    90
  )::int AS gun
),
hesap AS (
  SELECT
    v.hayvan_id,
    -- Süt: bilinen karensler → bitiş anı
    max(v.uygulama_an + (v.sut_saat || ' hours')::interval)
      FILTER (WHERE v.sut_saat IS NOT NULL)                       AS sut_bitis,
    max((v.uygulama_tarih + v.et_gun)::timestamptz)
      FILTER (WHERE v.et_gun IS NOT NULL)                         AS et_bitis,
    -- Bilinmeyen: pencere içinde karensi NULL olan uygulama var mı
    bool_or(v.sut_saat IS NULL AND v.uygulama_tarih >= CURRENT_DATE - p.gun) AS sut_bilinmiyor,
    bool_or(v.et_gun   IS NULL AND v.uygulama_tarih >= CURRENT_DATE - p.gun) AS et_bilinmiyor
  FROM public.hayvan_karens_uygulama_view v
  CROSS JOIN pencere p
  GROUP BY v.hayvan_id
)
SELECT
  h.id                AS hayvan_id,
  h.kupe_no,
  h.grup,
  x.sut_bitis,
  x.et_bitis,
  CASE
    WHEN x.sut_bitis IS NOT NULL AND x.sut_bitis > now() THEN 'KARENSTE'
    WHEN COALESCE(x.sut_bilinmiyor, false)                THEN 'BILINMIYOR'
    ELSE 'TEMIZ'
  END AS sut_durum,
  CASE
    WHEN x.et_bitis IS NOT NULL AND x.et_bitis > now()   THEN 'KARENSTE'
    WHEN COALESCE(x.et_bilinmiyor, false)                THEN 'BILINMIYOR'
    ELSE 'TEMIZ'
  END AS et_durum,
  GREATEST(0, CEIL(EXTRACT(epoch FROM (x.sut_bitis - now())) / 3600))::int AS sut_kalan_saat,
  GREATEST(0, (x.et_bitis::date - CURRENT_DATE))::int                       AS et_kalan_gun
FROM public.hayvanlar h
LEFT JOIN hesap x ON x.hayvan_id = h.id
WHERE h.durum = 'Aktif';

COMMENT ON VIEW public.hayvan_karens_view IS
  'Hayvan başına aktif süt/et karens durumu. Türetilmiş — hiçbir yere yazılmaz. '
  'BILINMIYOR, TEMIZ''i ezer: karensi girilmemiş ilaç uygulanmışsa süt temiz SAYILMAZ.';

GRANT SELECT ON public.hayvan_karens_uygulama_view TO anon, authenticated;
GRANT SELECT ON public.hayvan_karens_view          TO anon, authenticated;

-- ============================================================================
-- 5. karens_guncelle — UI'dan karens tanımlama (etken madde / ürün / aşı)
--    Kataloglar satıcı değil KULLANICI tarafından yönetilir; karens de dahil.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.karens_guncelle(
  p_drug_class_id   uuid    DEFAULT NULL,
  p_drug_product_id uuid    DEFAULT NULL,
  p_vaccine_id      uuid    DEFAULT NULL,
  p_sut_karens_saat integer DEFAULT NULL,
  p_et_karens_gun   integer DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_hedef text;
BEGIN
  IF num_nonnulls(p_drug_class_id, p_drug_product_id, p_vaccine_id) <> 1 THEN
    RAISE EXCEPTION 'Tam olarak bir hedef verilmeli: drug_class_id VEYA drug_product_id VEYA vaccine_id';
  END IF;

  IF p_sut_karens_saat IS NOT NULL AND p_sut_karens_saat < 0 THEN
    RAISE EXCEPTION 'Süt karensi negatif olamaz: %', p_sut_karens_saat;
  END IF;
  IF p_et_karens_gun IS NOT NULL AND p_et_karens_gun < 0 THEN
    RAISE EXCEPTION 'Et karensi negatif olamaz: %', p_et_karens_gun;
  END IF;

  IF p_drug_class_id IS NOT NULL THEN
    UPDATE public.drug_classes
    SET sut_karens_saat = p_sut_karens_saat, et_karens_gun = p_et_karens_gun
    WHERE id = p_drug_class_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Etken madde bulunamadı: %', p_drug_class_id; END IF;
    v_hedef := 'drug_classes';

  ELSIF p_drug_product_id IS NOT NULL THEN
    UPDATE public.drug_products
    SET sut_karens_saat = p_sut_karens_saat, et_karens_gun = p_et_karens_gun
    WHERE id = p_drug_product_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'İlaç bulunamadı: %', p_drug_product_id; END IF;
    v_hedef := 'drug_products';

  ELSE
    UPDATE public.vaccines
    SET sut_karens_saat = p_sut_karens_saat, et_karens_gun = p_et_karens_gun
    WHERE id = p_vaccine_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Aşı bulunamadı: %', p_vaccine_id; END IF;
    v_hedef := 'vaccines';
  END IF;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('KARENS_GUNCELLE',
          COALESCE(p_drug_class_id, p_drug_product_id, p_vaccine_id)::text,
          v_hedef,
          jsonb_build_object(
            'olusturulan', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object(
              'tablo', v_hedef,
              'id', COALESCE(p_drug_class_id, p_drug_product_id, p_vaccine_id)::text,
              'veri', jsonb_build_object('sut_karens_saat', p_sut_karens_saat,
                                         'et_karens_gun',   p_et_karens_gun))),
            'silinen', '[]'::jsonb),
          'Karens güncellendi');

  RETURN jsonb_build_object('ok', true, 'hedef', v_hedef);
END;
$$;

GRANT EXECUTE ON FUNCTION public.karens_guncelle(uuid, uuid, uuid, integer, integer) TO anon, authenticated;

-- ============================================================================
-- 6. karens_eksik_audit — hangi katalog kayıtlarında karens girilmemiş?
--    protokol_orphan_audit ile aynı mantık: sessiz eksiği GÖRÜNÜR kılar.
--    Kullanımdaki (stoğa bağlı) ilaçlar önceliklidir — kullanılmayan katalog
--    kaydının karensi boş olması sorun değil.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.karens_eksik_audit()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_urun_eksik   int;
  v_asi_eksik    int;
  v_hayvan_bilin int;
  v_ornekler     jsonb;
BEGIN
  -- Stoğa bağlı (fiilen kullanılabilir) ürünlerden karensi çözülemeyenler
  SELECT count(*) INTO v_urun_eksik
  FROM public.drug_products dp
  JOIN public.stok s ON s.drug_product_id = dp.id
  LEFT JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
  WHERE COALESCE(dp.sut_karens_saat, dc.sut_karens_saat) IS NULL
     OR COALESCE(dp.et_karens_gun,   dc.et_karens_gun)   IS NULL;

  SELECT count(*) INTO v_asi_eksik
  FROM public.vaccines
  WHERE sut_karens_saat IS NULL OR et_karens_gun IS NULL;

  SELECT count(*) INTO v_hayvan_bilin
  FROM public.hayvan_karens_view
  WHERE sut_durum = 'BILINMIYOR' OR et_durum = 'BILINMIYOR';

  SELECT jsonb_agg(jsonb_build_object(
           'drug_product_id', t.id, 'ilac', t.brand_name, 'etken', t.active_ingredient))
  INTO v_ornekler
  FROM (
    SELECT dp.id, dp.brand_name, dc.active_ingredient
    FROM public.drug_products dp
    JOIN public.stok s ON s.drug_product_id = dp.id
    LEFT JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE COALESCE(dp.sut_karens_saat, dc.sut_karens_saat) IS NULL
       OR COALESCE(dp.et_karens_gun,   dc.et_karens_gun)   IS NULL
    ORDER BY dc.active_ingredient, dp.brand_name
    LIMIT 20
  ) t;

  RETURN jsonb_build_object(
    'karens_eksik_ilac',   v_urun_eksik,
    'karens_eksik_asi',    v_asi_eksik,
    'karensi_belirsiz_hayvan', v_hayvan_bilin,
    'ornekler', COALESCE(v_ornekler, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.karens_eksik_audit() TO anon, authenticated;

COMMIT;
