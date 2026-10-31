-- ============================================================================
-- Migration: 20261017000001_stat_saglik_vaka
-- 2026-10-17 · İstatistik Atölyesi AP1 Task 3 (spec v2 §4.2.1-§4.2.5; plan Task 3, P7; root ruling
--   2026-10-17 T1(e)=C: Ovsync log kolu daraltıldı; sahip S1 (c) 2026-10-31, domain §19.7: basarisiz_tedavi_degisti).
-- Etkiler: YENİ nesneler — stat_bugun, stat_vaka_ovsync_mu, stat_medyan_gecikme, v_stat_saglik_vaka,
--   stat_saglik_vekil, v_stat_saglik_vaka_ilac, stat_saglik_vaka_tl, stat_saglik_fiyat_kaynagi.
--   Mevcut nesneye dokunulmaz (main _vaka_ovsync_mu, v_stat_vaka, stat_tedavi_* aynen). Tablo yazımı yok.
-- ACL: hepsi SECURITY INVOKER + SET search_path = public, pg_temp; REVOKE ALL FROM PUBLIC, anon, authenticated;
--   fonksiyonlara EXECUTE / view'lara SELECT yalnız authenticated. anon GRANT yok.
-- TZ: bugün = stat_bugun() (Europe/Istanbul); kapanış günü = (closed_at AT TIME ZONE 'Europe/Istanbul')::date.
-- Idempotent: CREATE OR REPLACE (VIEW/FUNCTION); ikinci psql -f hatasız.
-- Geri alma: DROP FUNCTION stat_saglik_fiyat_kaynagi(jsonb,jsonb), stat_saglik_vaka_tl(jsonb,jsonb),
--   stat_saglik_vekil(); DROP VIEW v_stat_saglik_vaka_ilac, v_stat_saglik_vaka;
--   DROP FUNCTION stat_medyan_gecikme(int[]), stat_vaka_ovsync_mu(uuid), stat_bugun();
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. Bugün (TR) ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_bugun()
RETURNS date
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $$;

COMMENT ON FUNCTION public.stat_bugun() IS
  'İstatistiğin tek "bugün" kaynağı: (now() AT TIME ZONE ''Europe/Istanbul'')::date (sunucu saat dilimi UTC olduğundan sunucu tarihi kullanılmaz).';

-- ── 2. Üreme protokolü (Ovsync) vakası mı — istatistiğin tek tanımı ──────────
CREATE OR REPLACE FUNCTION public.stat_vaka_ovsync_mu(p_case_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.cases c
    LEFT JOIN public.diseases d ON d.id = c.disease_id
    WHERE c.id = p_case_id
      AND (c.protocol_family = 'OVSYNC'
           OR d.name ILIKE '%ovsync%'
           OR (c.protocol_family IS NULL
               AND (EXISTS (SELECT 1 FROM public.sablon_hastalik_eslem e
                              JOIN public.tedavi_sablonu t ON t.id = e.sablon_id
                             WHERE e.disease_id = c.disease_id AND t.protokol_ailesi = 'OVSYNC')
                    OR EXISTS (SELECT 1 FROM public.gorev_log g
                                 JOIN public.tedavi_sablonu t
                                   ON g.kaynak = 'TEDAVI_SABLON_TOHUMLAMA:' || c.id::text || ':' || t.id::text
                                WHERE t.protokol_ailesi = 'OVSYNC' AND g.iptal = false)))));
$$;

COMMENT ON FUNCTION public.stat_vaka_ovsync_mu(uuid) IS
  'İstatistikte üreme protokolü (Ovsync) vakası: protocol_family=''OVSYNC'' VEYA hastalık adı ILIKE ''%ovsync%'' VEYA '
  '(protocol_family NULL iken) OVSYNC-eşlemeli şablonu olan hastalık VEYA log kolu. Kaynak: main _vaka_ovsync_mu '
  '(20261013000003_alt_vaka.sql:66-84; DEFINER + yalnız service_role olduğundan çağrılmaz, mantık aynalanır). '
  'Log kolu daraltıldı (root ruling 2026-10-17): yalnız gorev_log.kaynak = ''TEDAVI_SABLON_TOHUMLAMA:<case_id>:<sablon_id>'' '
  'satırı, 3. parçası tedavi_sablonu.id olan (yazan: tedavi_sablon_tohumlama_gorev_ekle, 20260730000001:128, '
  '20260909000001:130; '':MANUEL'' anahtarı şablona eşleşmez) ve tedavi_sablonu.protokol_ailesi=''OVSYNC'' olan şablona '
  'kaynak = önek || case_id || '':'' || tedavi_sablonu.id eşitliğiyle bağlanan ve iptal=false olan log sayılır. '
  'Not: yalnız protocol_family=''OVSYNC'' dışlanır; ileride OVSYNC dışı bir aile gelirse o vaka sağlık kapsamına girer '
  've şablon/log kolları (protocol_family IS NULL şartlı) atlanır — 2026-10-17 itibarıyla değerler yalnız NULL/OVSYNC.';

-- ── 3. Medyan gecikme (vekil G) ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_medyan_gecikme(p_gecikmeler int[])
RETURNS int
LANGUAGE sql IMMUTABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN count(u.x) < 5 THEN 0
              ELSE round((percentile_cont(0.5) WITHIN GROUP (ORDER BY u.x))::numeric, 0)::int END
  FROM (SELECT unnest(p_gecikmeler::int[]) AS x) AS u;
$$;

COMMENT ON FUNCTION public.stat_medyan_gecikme(int[]) IS
  'Vekil gecikme G (spec §4.2.5): eleman <5 ise 0, aksi percentile_cont(0.5) numeric round ile tam güne (0,5 yukarı).';

-- ── 4. Vaka satırı ─────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_stat_saglik_vaka WITH (security_invoker = true) AS
WITH kapsam AS (                                  -- iki kez okunur → PG materialize eder
  SELECT c.id, c.animal_id, c.disease_id, c.start_date, c.status, c.closed_at, c.created_at,
         CASE WHEN c.status = 'closed' THEN (c.closed_at AT TIME ZONE 'Europe/Istanbul')::date END AS kapanis
  FROM public.cases c
  WHERE NOT public.stat_vaka_ovsync_mu(c.id)
), toplu AS (
  SELECT c.closed_at FROM public.cases c
  WHERE c.status = 'closed' AND c.closed_at IS NOT NULL
  GROUP BY c.closed_at HAVING count(*) >= 3
), gun AS (
  SELECT td.case_id,
         count(DISTINCT td.id) AS plan_gun,
         count(DISTINCT td.treatment_date) FILTER (WHERE a.id IS NOT NULL AND a.uygulanmadi IS NOT TRUE) AS uygulanan_gun,
         min(td.treatment_date) FILTER (WHERE a.id IS NOT NULL AND a.uygulanmadi IS NOT TRUE) AS ilk_uygulama,
         max(td.treatment_date) FILTER (WHERE a.id IS NOT NULL AND a.uygulanmadi IS NOT TRUE) AS son_uygulama
  FROM public.treatment_days td
  LEFT JOIN public.drug_administrations a ON a.treatment_day_id = td.id
  GROUP BY td.case_id
), kalem_ham AS (
  -- fiyat anahtarı: a.stok_id; NULL ise ürünü taşıyan stok satırı tam bir tane ise o
  SELECT u.case_id, u.birim, u.miktar, s.id AS stok_id, s.birim AS stok_birim
  FROM (SELECT td.case_id, a.unit AS birim, a.dose AS miktar,
               COALESCE(a.stok_id, (SELECT max(s2.id) FROM public.stok s2
                                     WHERE s2.drug_product_id = a.drug_product_id
                                    HAVING count(*) = 1)) AS anahtar
          FROM public.treatment_days td
          JOIN public.drug_administrations a ON a.treatment_day_id = td.id AND a.uygulanmadi IS NOT TRUE) u
  LEFT JOIN public.stok s ON s.id = u.anahtar
), kalem AS (
  SELECT k.case_id,
         jsonb_agg(jsonb_build_object('stok_id', k.stok_id, 'birim', k.birim, 'miktar', k.miktar, 'neden', k.neden)
                   ORDER BY k.stok_id NULLS LAST, k.birim) AS kalemler
  FROM (SELECT h.case_id, h.stok_id, h.birim, sum(h.miktar) AS miktar,
               CASE WHEN h.stok_id IS NULL THEN 'stoksuz'
                    WHEN h.stok_birim IS NULL OR h.birim <> h.stok_birim THEN 'birim_uyusmaz' END AS neden
          FROM kalem_ham h
         GROUP BY h.case_id, h.stok_id, h.birim, h.stok_birim) k
  GROUP BY k.case_id
), satir AS (
  SELECT k.*, h.kupe_no, h.cikis_tipi, h.cikis_tarihi,
         g.plan_gun, g.uygulanan_gun, g.ilk_uygulama, g.son_uygulama,
         (k.kapanis IS NOT NULL AND k.closed_at IN (SELECT t.closed_at FROM toplu t)) AS toplu_kapanis,
         EXISTS (SELECT 1 FROM kapsam n                   -- nüks: aynı hayvan + hastalık, kapsam içi yeni vaka;
                  WHERE n.animal_id = k.animal_id AND n.disease_id = k.disease_id AND n.id <> k.id   -- gün 0 dahil (R2)
                    AND n.start_date >= k.kapanis AND n.start_date <= k.kapanis + 30) AS nuks,
         EXISTS (SELECT 1 FROM kapsam n                   -- tedavi değişti (S1): kapanıştan 24 saat içinde kaydedilmiş yeni vaka;
                  WHERE n.animal_id = k.animal_id AND n.disease_id = k.disease_id AND n.id <> k.id   -- eskisinden sonra kaydedilmiş
                    AND n.start_date >= k.kapanis AND n.created_at > k.created_at
                    AND n.created_at <= k.closed_at + interval '24 hours') AS tedavi_degisti
  FROM kapsam k
  LEFT JOIN public.hayvanlar h ON h.id = k.animal_id
  LEFT JOIN gun g ON g.case_id = k.id
), vekil AS (
  SELECT public.stat_medyan_gecikme(array_agg(s.kapanis - s.son_uygulama)) AS g
  FROM satir s
  WHERE s.kapanis IS NOT NULL AND NOT s.toplu_kapanis AND s.son_uygulama IS NOT NULL
), sonuclu AS (
  SELECT s.*,
         CASE                                             -- spec §4.2.2 sırası, ilk eşleşen kazanır
           WHEN s.status = 'active' AND s.cikis_tipi IN ('olum', 'kesim') THEN 'basarisiz_olum_kesim'
           WHEN s.status = 'active' THEN NULL
           WHEN s.kapanis IS NULL THEN NULL               -- kapalı ama closed_at yok: sonuçsuz (fail-closed)
           WHEN s.cikis_tipi IN ('olum', 'kesim') AND s.cikis_tarihi <= s.kapanis + 30 THEN 'basarisiz_olum_kesim'
           WHEN s.tedavi_degisti THEN 'basarisiz_tedavi_degisti'
           WHEN s.nuks THEN 'basarisiz_nuks'
           WHEN public.stat_bugun() < s.kapanis + 30 THEN 'olgunlasmamis'
           ELSE 'basarili'
         END AS sonuc,
         CASE WHEN s.kapanis IS NULL THEN NULL
              WHEN NOT s.toplu_kapanis THEN s.kapanis - s.start_date
              WHEN s.son_uygulama IS NOT NULL THEN LEAST(s.son_uygulama + v.g, s.kapanis) - s.start_date
         END AS kapanma_ham
  FROM satir s CROSS JOIN vekil v
)
SELECT o.id::uuid                                          AS vaka_id,
       o.animal_id::text                                   AS hayvan_id,
       o.kupe_no::text                                     AS kupe_no,
       d.id::uuid                                          AS hastalik_id,
       d.name::text                                        AS hastalik,
       COALESCE(d.category, 'Kategorisiz')::text           AS kategori,
       o.start_date::date                                  AS baslangic,
       o.kapanis::date                                     AS kapanis,
       o.toplu_kapanis::boolean                            AS toplu_kapanis,
       o.ilk_uygulama::date                                AS ilk_uygulama,
       o.son_uygulama::date                                AS son_uygulama,
       (o.son_uygulama - o.ilk_uygulama + 1)::int          AS tedavi_suresi_gun,
       COALESCE(o.uygulanan_gun, 0)::int                   AS uygulanan_gun,
       COALESCE(o.plan_gun, 0)::int                        AS plan_gun,
       (CASE WHEN o.uygulanan_gun > 0
             THEN round(o.uygulanan_gun::numeric / NULLIF(o.plan_gun, 0), 3) END)::numeric(5,3) AS plan_uyum,
       (CASE WHEN o.status = 'closed' AND o.kapanis IS NULL THEN 'kapali_tarihsiz'   -- root ruling T3 tur2
             WHEN o.sonuc IS NULL THEN 'acik' ELSE 'sonuclandi' END)::text AS durum,
       o.sonuc::text                                       AS sonuc,
       (CASE WHEN o.sonuc = 'basarisiz_tedavi_degisti' THEN NULL                     -- S1: hız ölçüsünde yok
             WHEN o.kapanma_ham >= 0 THEN o.kapanma_ham END)::int AS kapanma_gunu,   -- P7: negatif → NULL
       (o.toplu_kapanis AND o.son_uygulama IS NOT NULL
        AND o.sonuc IS DISTINCT FROM 'basarisiz_tedavi_degisti')::boolean AS kapanma_vekil,
       COALESCE(ka.kalemler, '[]'::jsonb)::jsonb           AS maliyet_kalemleri
FROM sonuclu o
JOIN public.diseases d ON d.id = o.disease_id
LEFT JOIN kalem ka ON ka.case_id = o.id;

COMMENT ON VIEW public.v_stat_saglik_vaka IS
  'AP1 sağlık vakası (spec §4.2.2): Ovsync dışı (stat_vaka_ovsync_mu) her vaka için bir satır; sonuç sırası aktif+ölüm/kesim → '
  'açık → kapanış+30 içinde ölüm/kesim → kapanıştan sonra 24 saat içinde (created_at <= closed_at + 24 saat, start_date >= kapanış, created_at > kapanan vakanın created_at) '
  'kapsam içi aynı hastalık yeni vakası = basarisiz_tedavi_degisti (kapanma günü NULL, vekil false; domain §19.7) → '
  '[kapanış, kapanış+30] içinde (kapanış günü açılan dahil, root ruling R2) kapsam içi '
  'aynı hastalık nüksü → 30 gün dolmadı (olgunlaşmamış) → '
  'başarılı; kapanma günü = kapanış − başlangıç, toplu kapanışta (aynı closed_at ≥3 vaka) LEAST(son uygulama + G, kapanış) − '
  'başlangıç (vekil), negatifse NULL; maliyet_kalemleri uygulanmış ilaçların (stok, birim) toplamıdır, ₺ hesap anında. '
  'Kapalı olup closed_at''ı NULL olan vaka (kapanış günü bilinmiyor) sonuçsuzdur: sonuc NULL, durum ''kapali_tarihsiz'' '
  '(açık değildir; açık-vaka sayacına girmez, root ruling T3 tur2), '
  'başarı/nüks/ölüm paydalarına, olgunlaşmaya, kapanma gününe ve vekil G kümesine girmez (lead ruling T3 review tur1). '
  'Vekil kümesi (vekil CTE) = kapanis dolu ∧ toplu değil ∧ son_uygulama dolu; aynı tanım: stat_saglik_vekil().';

-- ── 5. Vekil G ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_saglik_vekil()
RETURNS TABLE(g int, normal_n int)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT public.stat_medyan_gecikme(array_agg(v.kapanis - v.son_uygulama)), count(*)::int
  FROM public.v_stat_saglik_vaka v
  WHERE v.kapanis IS NOT NULL AND NOT v.toplu_kapanis AND v.son_uygulama IS NOT NULL;
$$;

COMMENT ON FUNCTION public.stat_saglik_vekil() IS
  'Vekil kapanma G (spec §4.2.5): kapsam içi, toplu olmayan, kapalı, ≥1 uygulanmış ilaçlı vakalarda kapanış − son uygulama '
  'medyanı (stat_medyan_gecikme; n<5 → 0); tüm geçmişten, dönem süzgeci yok. Aynı tanım: v_stat_saglik_vaka içindeki '
  'vekil CTE (kapanis IS NOT NULL ∧ NOT toplu_kapanis ∧ son_uygulama IS NOT NULL); biri değişirse diğeri de değişir.';

-- ── 6. Vaka × ilaç ─────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_stat_saglik_vaka_ilac WITH (security_invoker = true) AS
WITH kapsam AS (
  SELECT c.id FROM public.cases c WHERE NOT public.stat_vaka_ovsync_mu(c.id)
), uyg AS (
  SELECT td.case_id, dc.active_ingredient AS etken, COALESCE(dp.brand_name, s.urun_adi) AS preparat,
         COALESCE(dc.class_name, dc.group_name) AS sinif
  FROM kapsam k
  JOIN public.treatment_days td ON td.case_id = k.id
  JOIN public.drug_administrations a ON a.treatment_day_id = td.id AND a.uygulanmadi IS NOT TRUE
  LEFT JOIN public.stok s ON s.id = a.stok_id
  LEFT JOIN public.drug_products dp ON dp.id = COALESCE(a.drug_product_id, s.drug_product_id)
  LEFT JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
)
SELECT DISTINCT u.case_id::uuid AS vaka_id, x.duzey::text AS duzey,
       COALESCE(CASE x.duzey WHEN 'etken' THEN u.etken WHEN 'preparat' THEN u.preparat ELSE u.sinif END,
                '(bilinmiyor)')::text AS deger
FROM uyg u
CROSS JOIN (VALUES ('etken'), ('preparat'), ('sinif')) AS x(duzey);

COMMENT ON VIEW public.v_stat_saglik_vaka_ilac IS
  'AP1 vaka × ilaç (spec §4.2.3): uygulanmış her ilaç için ürün = COALESCE(a.drug_product_id, stok.drug_product_id); '
  'etken = drug_classes.active_ingredient, preparat = COALESCE(brand_name, stok.urun_adi), sınıf = COALESCE(class_name, '
  'group_name); çözülemeyen değer ''(bilinmiyor)''; (vaka, düzey, değer) tekil; kapsam v_stat_saglik_vaka ile aynı.';

-- ── 7. Vaka ₺ ve fiyat kaynağı ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_saglik_vaka_tl(p_kalemler jsonb, p_fiyat jsonb)
RETURNS numeric
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN p_kalemler IS NULL OR bool_or(f.fiyat IS NULL OR f.neden IS NOT NULL) THEN NULL
              ELSE round(COALESCE(sum(f.miktar * f.fiyat), 0), 2) END
  FROM (
    SELECT k->>'neden' AS neden, (k->>'miktar')::numeric AS miktar,
           COALESCE((COALESCE(p_fiyat, '{}'::jsonb) ->> (k->>'stok_id'))::numeric,
                    (SELECT s.maliyet FROM public.stok s WHERE s.id = k->>'stok_id' AND s.maliyet > 0)) AS fiyat
    FROM (SELECT jsonb_array_elements(COALESCE(p_kalemler, '[]'::jsonb)) AS k) AS e
  ) f;
$$;

COMMENT ON FUNCTION public.stat_saglik_vaka_tl(jsonb, jsonb) IS
  'Vaka maliyeti (spec §4.2.4): kalem birim fiyatı = p_fiyat[stok_id] (geçici) yoksa stok.maliyet > 0 (kayıtlı); '
  'bir kalem fiyatsız ya da neden dolu ise NULL (kısmi toplam yok); aksi Σ miktar × fiyat, 2 ondalık; boş dizi → 0.';

CREATE OR REPLACE FUNCTION public.stat_saglik_fiyat_kaynagi(p_kalemler jsonb, p_fiyat jsonb)
RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN bool_or(e.k->>'neden' IS NULL
                           AND (COALESCE(p_fiyat, '{}'::jsonb) ->> (e.k->>'stok_id')) IS NOT NULL) THEN 'gecici'
              WHEN public.stat_saglik_vaka_tl(p_kalemler, p_fiyat) IS NOT NULL THEN 'kayitli'
              ELSE 'fiyatsiz' END
  FROM (SELECT jsonb_array_elements(COALESCE(p_kalemler, '[]'::jsonb)) AS k) AS e;
$$;

COMMENT ON FUNCTION public.stat_saglik_fiyat_kaynagi(jsonb, jsonb) IS
  'Fiyat kaynağı: ''gecici'' (en az bir kalem geçici fiyatlı), ''kayitli'' (₺ hesaplanabilir, geçici yok; boş dizi dahil), '
  '''fiyatsiz'' (₺ NULL ve geçici yok).';

-- ── 8. ACL ─────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.stat_bugun() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_vaka_ovsync_mu(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_medyan_gecikme(int[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_saglik_vekil() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_saglik_vaka_tl(jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_saglik_fiyat_kaynagi(jsonb, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_bugun() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_vaka_ovsync_mu(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_medyan_gecikme(int[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_saglik_vekil() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_saglik_vaka_tl(jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_saglik_fiyat_kaynagi(jsonb, jsonb) TO authenticated;

REVOKE ALL ON TABLE public.v_stat_saglik_vaka FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v_stat_saglik_vaka_ilac FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.v_stat_saglik_vaka TO authenticated;
GRANT SELECT ON TABLE public.v_stat_saglik_vaka_ilac TO authenticated;

COMMIT;
