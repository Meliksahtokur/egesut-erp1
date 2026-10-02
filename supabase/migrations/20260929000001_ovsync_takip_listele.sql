-- ============================================================================
-- Migration: 20260929000001_ovsync_takip_listele
-- Plan: docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md — P1
--       (G-20260930-OVSYNC-TAKIP-IMPL, madde drift kapısı: yalnız P1)
-- Spec: design.md §3 (S0-S4) · §5 (satır şeması) · §6c.5 (takip) · §7 (doğruluk)
--       · §10c #8 (KPA) / #11 (S2 kaynak) / #13 (farm_id) · K6 köprüsü · K15
--
-- ovsync_takip_listele(p_padok text DEFAULT NULL, p_sonlanan_gun int DEFAULT 60)
--   RETURNS jsonb — SALT-OKUNUR takip RPC'si. YAZMA YOK (yalnız SELECT);
--   RPC_TABLES'a girmez (spec §5 salt-okunur invariant'ı).
--
-- CTE modeli: ovsync_baslat_uyarilari (20260926000003:38-104) genişletmesi —
--   gorevli ∪ gorevsiz ∪ aktif-zincir ∪ sonuc-bekleyen ∪ kapalı.
--
-- S2 (sonuç bekleyen) kümesi = gebelik_muayene_listele (20260925000002:294-322)
--   5 predicate BİREBİR (T-45 küme eşitliği şartı; CURRENT_DATE kasıtlı —
--   kaynak fonksiyonla aynı ifade; ekranın geri kalanı Europe/Istanbul günü).
--
-- Doğruluk kuralları (design.md §7, gövdeye işlendi):
--   §7.1 görev durumu (tamamlandi, iptal) ikilisiyle yorumlanır;
--   §7.2 satırda yalnız aktif TAI (iptal/tamamlanmış/kapatan_ref'li hariç —
--        "son PG kazanır": PG_YERINE zincirinde kapatan_ref dolu eski TAI düşer);
--   §7.3 gelecek tarihli "tamamlandı" gün → 'tutarsiz' ('uygulanmadi' YAZILMAZ);
--   §7.4 close_reason NULL → 'ESKI';
--   §7.5 K6 köprüsü (hayvan_id + tohumlama tarihi ∈ [start_date, kapanış+2g])
--        eşleşmezse toh_sonuc='bilinmiyor' — tahmin YOK;
--   §7.6 hayvanlar.tohumlama_durumu KULLANILMAZ (§18.11 — gebelik otoritesi değil);
--   §7.8 tanınmayan yapı/alan → 'bilinmiyor' (tai.kaynak enum dışı vb.).
--
-- farm_id (#13 + C6): dokunulan tabloların (cases, hayvanlar, tohumlama,
--   gorev_log, treatment_days) farm_id kolonu YOK [OBSERVED egesut_lsp aynası
--   2026-09-30] → farm_id predikatı hiçbir CTE'ye YAZILMADI.
--   P1 pg_application_event OKUMAZ (C6): 'PG_TOHUMLAMA:<event>' kaynaklı TAI
--   hayvan-seviyesinde bağlanır (bagli_case_id NULL → hayvan fallback).
--
-- ACL (kalıp 20260926000003:106-107): Supabase default-privilege tuzağı gereği
--   REVOKE'a PUBLIC + anon + authenticated birlikte girer; GRANT yalnız
--   authenticated + service_role. Anon GRANT YAZILMAZ (bilinen anon EXECUTE
--   açığı engeli, 2026-06-14 lockdown sonrası şablon kuralı).
--
-- Geri alınabilir: fonksiyon YENİ — rollback = DROP FUNCTION (prova betiğinde ölçülür).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.ovsync_takip_listele(p_padok text DEFAULT NULL, p_sonlanan_gun int DEFAULT 60)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
SELECT CASE
  -- Bayrak kapalı yolu (spec §5 + plan P1): {ok, bayrak_kapali:true, satirlar:[]}
  WHEN NOT public._ovsync_pg_aktif() THEN
    jsonb_build_object('ok', true, 'bayrak_kapali', true, 'satirlar', '[]'::jsonb)
  ELSE (
    WITH bugun AS (
      SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS d
    ), esik AS (
      -- Muayene eşiği TEK kaynak (§18.13): yeni sabit yazılmaz.
      SELECT public._ayar('sessiz_tohumlama_muafiyet_gun', 40)::int AS muayene_gun
    ), vaka_spine AS (
      -- ── Omurga: aktif + sonlanan (p_sonlanan_gun penceresi) OVSYNC vakaları ──

      SELECT 'aktif'::text AS vaka_tip, c.id AS case_id, c.animal_id AS hayvan_id,
             c.start_date, NULL::date AS kapanis_tarihi, c.closed_at, c.close_reason,
             h.kupe_no, COALESCE(h.kategori, h.grup) AS grup, h.padok
        FROM public.cases c
        JOIN public.hayvanlar h ON h.id = c.animal_id
       WHERE c.protocol_family = 'OVSYNC'
         AND c.status = 'active'
         AND (p_padok IS NULL OR h.padok = p_padok)
      UNION ALL
      SELECT 'kapali'::text, c.id, c.animal_id, c.start_date,
             (c.closed_at AT TIME ZONE 'Europe/Istanbul')::date, c.closed_at, c.close_reason,
             h.kupe_no, COALESCE(h.kategori, h.grup), h.padok
        FROM public.cases c
        JOIN public.hayvanlar h ON h.id = c.animal_id
        CROSS JOIN bugun b
       WHERE c.protocol_family = 'OVSYNC'
         AND c.status = 'closed'
         AND (c.closed_at AT TIME ZONE 'Europe/Istanbul')::date >= b.d - p_sonlanan_gun
         AND (p_padok IS NULL OR h.padok = p_padok)
    ), gun_durum AS (
      -- ── Protokol günleri (§7.3 durum makinesi) ──
      SELECT td.case_id, td.day_no, td.treatment_date, td.planned_time,
             td.tamamlanma_tarihi,
             CASE
               WHEN COALESCE(td.tamamlandi, false) AND td.treatment_date > b.d
                 THEN 'tutarsiz'::text          -- §7.3: gelecek 'tamamlandı' → tutarsiz
               WHEN COALESCE(td.tamamlandi, false)
                 THEN 'tamam'::text
               WHEN c.status = 'closed'
                 THEN 'uygulanmadi'::text       -- vaka kapandı, gün açık kaldı
               WHEN td.treatment_date < b.d
                 THEN 'gecikti'::text
               ELSE 'planli'::text
             END AS durum
        FROM public.treatment_days td
        JOIN public.cases c ON c.id = td.case_id
        CROSS JOIN bugun b
       WHERE c.protocol_family = 'OVSYNC'
    ), gun_ozet AS (
      SELECT g.case_id,
             jsonb_agg(jsonb_build_object(
                 'gun_no', g.day_no,
                 'tarih', g.treatment_date,
                 'planned_time', g.planned_time,
                 'durum', g.durum,
                 'tamamlandi_tarihi', g.tamamlanma_tarihi)
                 ORDER BY g.day_no) AS gunler,
             min(g.day_no) FILTER (WHERE g.durum IN ('planli', 'gecikti')) AS sonraki_gun,
             max(CASE WHEN g.durum = 'gecikti' THEN b.d - g.treatment_date ELSE 0 END) AS gecikme_gun,
             min(g.treatment_date) AS fiili_baslangic,
             bool_or(g.treatment_date = b.d AND g.durum IN ('planli', 'gecikti')) AS bugun_isi
        FROM gun_durum g
        CROSS JOIN bugun b
       GROUP BY g.case_id
    ), tai_tumu AS (
      -- ── TAI görevleri (TOHUMLAMA_PLANLI): kaynak türü + vaka bağlaması ──
      -- Kaynak formatları: 'TEDAVI_SABLON_TOHUMLAMA:<case_id>:<sablon_id>'
      -- [CONFIRMED 20260722000003:13] · 'PG_TOHUMLAMA:<event_id>'
      -- [CONFIRMED 20260923000004:667]. UUID şekli regex'le doğrulanır; uymazsa
      -- bağlama NULL (§7.8 bilinmiyor — cast hatası üretmeden).

      SELECT g.id AS gorev_id, g.hayvan_id, g.hedef_tarih, g.hedef_saat, g.kaynak,
             COALESCE(g.tamamlandi, false) AS tamamlandi,
             COALESCE(g.iptal, false) AS iptal,
             g.kapatan_ref, g.created_at,
             CASE
               WHEN g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:%' THEN 'sablon'::text
               WHEN g.kaynak LIKE 'PG_TOHUMLAMA:%'            THEN 'pg'::text
               ELSE 'bilinmiyor'::text        -- §7.8: enum dışı kaynak
             END AS kaynak_tur,
             CASE
               WHEN substring(g.kaynak FROM '^TEDAVI_SABLON_TOHUMLAMA:([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}):') IS NOT NULL
                 THEN substring(g.kaynak FROM '^TEDAVI_SABLON_TOHUMLAMA:([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}):')::uuid
               ELSE NULL                      -- PG_TOHUMLAMA / MANUEL: hayvan fallback
             END AS bagli_case_id
        FROM public.gorev_log g
       WHERE g.gorev_tipi = 'TOHUMLAMA_PLANLI'
    ), vaka_tai AS (
      -- §7.2: yalnız AKTİF TAI (iptal/tamamlanmış/kapatan_ref'li hariç).
      -- Bağlama: case-bağlı (şablon) tercih; case'siz (PG/manuel/bilinmiyor) hayvan fallback.
      SELECT DISTINCT ON (v.case_id)
             v.case_id, tg.gorev_id, tg.hedef_tarih, tg.hedef_saat, tg.kaynak_tur,
             CASE
               WHEN tg.hedef_tarih < b.d THEN 'gecikti'::text
               ELSE 'planli'::text
             END AS durum
        FROM vaka_spine v
        CROSS JOIN bugun b
        JOIN tai_tumu tg
          ON tg.iptal = false
         AND tg.tamamlandi = false
         AND tg.kapatan_ref IS NULL
         AND (tg.bagli_case_id = v.case_id
              OR (tg.bagli_case_id IS NULL AND tg.hayvan_id = v.hayvan_id))
       ORDER BY v.case_id,
                (tg.bagli_case_id IS NOT NULL) DESC,
                tg.hedef_tarih DESC NULLS LAST,
                tg.created_at DESC NULLS LAST
    ), vaka_tai_ozet AS (
      -- Erken/görevsiz TAI teşhisi için: vakanın (veya hayvanının) TÜM TAI görevleri.
      SELECT v.case_id,
             bool_or(tg.gorev_id IS NOT NULL) AS tai_gorev_var,
             max(tg.hedef_tarih) AS max_tai_hedef
        FROM vaka_spine v
        LEFT JOIN tai_tumu tg
          ON (tg.bagli_case_id = v.case_id
              OR (tg.bagli_case_id IS NULL AND tg.hayvan_id = v.hayvan_id))
       GROUP BY v.case_id
    ), vaka_toh AS (
      -- ── K6 köprüsü: hayvan_id + tohumlama tarihi ∈ [start_date, kapanış+2g] ──
      -- Eşleşmezse toh_sonuc 'bilinmiyor' (§7.5); tohumlama_durumu okunmaz (§7.6).

      SELECT DISTINCT ON (v.case_id)
             v.case_id, t.id AS toh_id, t.tarih AS toh_tarih, t.sonuc AS toh_sonuc
        FROM vaka_spine v
        CROSS JOIN bugun b
        JOIN public.tohumlama t
          ON t.hayvan_id = v.hayvan_id
         AND t.tarih >= v.start_date
         AND t.tarih <= COALESCE(v.kapanis_tarihi, b.d) + 2
       ORDER BY v.case_id, t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
    ), vaka_dalga AS (
      -- ── Dalga: vakayı açan OVSYNC_BASLAT görevinin hedef_tarih'i ──
      -- Açan görev bulunamazsa (gorevsiz açılış) cases.start_date; yalnız
      -- hedef_baslangic NULL kalır (sapma.gorevsiz sinyali).

      SELECT DISTINCT ON (v.case_id)
             v.case_id, g.hedef_tarih AS hedef_baslangic,
             COALESCE(g.hedef_tarih, v.start_date) AS dalga_anahtari
        FROM vaka_spine v
        LEFT JOIN public.gorev_log g
          ON g.hayvan_id = v.hayvan_id
         AND g.gorev_tipi = 'OVSYNC_BASLAT'
         AND g.hedef_tarih BETWEEN v.start_date - 14 AND v.start_date + 2
       ORDER BY v.case_id, g.hedef_tarih DESC NULLS LAST
    ), sonuc_bekleyen AS (
      -- ── S2: sonuç bekleyenler — gebelik_muayene_listele 5 predicate BİREBİR ──
      -- (20260925000002:305-320; T-45 küme eşitliği şartı — burada tek karakter
      -- bile değiştirilemez; CURRENT_DATE kaynak fonksiyonla aynı.)

      SELECT t.id AS toh_id, t.hayvan_id, t.tarih AS son_toh_tarihi, t.case_id AS toh_case_id,
             h.kupe_no, h.padok, COALESCE(h.kategori, h.grup) AS grup
        FROM public.tohumlama t
        JOIN public.hayvanlar h ON h.id = t.hayvan_id
       WHERE t.sonuc = 'Bekliyor'
         AND t.tarih <= CURRENT_DATE - public._ayar('sessiz_tohumlama_muafiyet_gun', 40)::int
         AND h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
         AND t.id = (SELECT t2.id FROM public.tohumlama t2
                     WHERE t2.hayvan_id = t.hayvan_id
                     ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST
                     LIMIT 1)
         -- 30 g tamamlanmış-cooldown (D2): açık görev filtrelenmez (K15 ayrı alan).
         AND NOT EXISTS (SELECT 1 FROM public.gorev_log g
                         WHERE g.kaynak = 'GEBELIK-KONTROL-' || t.id
                           AND g.tamamlandi = true
                           AND g.tamamlanma_tarihi >= (CURRENT_DATE - 30))
         AND (p_padok IS NULL OR h.padok = p_padok)
    ), s2_dalga AS (
      -- S2 dalgası: tohumlama bir OVSYNC vakasına bağlıysa o vakanın dalgası;
      -- değilse NULL (UI 'tekil başlangıçlar' olarak gruplar).
      SELECT DISTINCT ON (sb.toh_id)
             sb.toh_id, COALESCE(g2.hedef_tarih, vc.start_date) AS dalga_anahtari
        FROM sonuc_bekleyen sb
        LEFT JOIN public.cases vc
          ON vc.id = sb.toh_case_id AND vc.protocol_family = 'OVSYNC'
        LEFT JOIN public.gorev_log g2
          ON g2.hayvan_id = sb.hayvan_id
         AND g2.gorev_tipi = 'OVSYNC_BASLAT'
         AND vc.id IS NOT NULL
         AND g2.hedef_tarih BETWEEN vc.start_date - 14 AND vc.start_date + 2
       ORDER BY sb.toh_id, g2.hedef_tarih DESC NULLS LAST
    ), baslat_gorevli AS (
      -- ── S3 bileşenleri: bekleyen başlatma ──

      -- TÜM açık OVSYNC_BASLAT görevleri (uyarılar ±2g penceresinden geniş —
      -- S3 'TÜM bekleyenleri listeler', §10c #8).
      SELECT g.id AS gorev_id, g.hayvan_id, g.hedef_tarih, g.hedef_saat, g.kaynak,
             CASE
               WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%'  THEN 'duve'::text
               WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'::text
               WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'::text
               ELSE 'acik_disi'::text
             END AS taban_turu
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND (p_padok IS NULL OR h.padok = p_padok)
    ), baslat_gorevsiz AS (
      -- uyarılar gorevsiz CTE'si birebir (20260926000003:60-85): yalnız pencere
      -- [bugun, bugun+2] içindeki kural günleri öneri satırı doğurur.
      SELECT NULL::uuid AS gorev_id, h.id AS hayvan_id,
             (SELECT public._ovsync_kural_tarihi(h.id)) AS hedef_tarih,
             NULL::time AS hedef_saat,
             'ACIK-DISI-ONERI:' || h.id AS kaynak,
             CASE
               WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'dogum'::text
               WHEN EXISTS (SELECT 1 FROM public.tohumlama t
                             WHERE t.hayvan_id = h.id AND t.sonuc = 'Abort'
                               AND t.abort_tarihi IS NOT NULL) THEN 'abort'::text
               WHEN h.dogum_tarihi IS NOT NULL THEN 'duve'::text
               ELSE 'acik_disi'::text
             END AS taban_turu
        FROM public.hayvanlar h
        CROSS JOIN bugun b
       WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi' AND COALESCE(h.kisir, false) = false
         AND public._acik_disi_ovsync_hedef(h.id) IS NOT NULL
         AND (SELECT public._ovsync_kural_tarihi(h.id)) >= b.d
         AND (SELECT public._ovsync_kural_tarihi(h.id)) <= b.d + 2
         AND NOT EXISTS (SELECT 1 FROM public.gorev_log g2
                         WHERE g2.hayvan_id = h.id AND g2.gorev_tipi = 'OVSYNC_BASLAT'
                           AND COALESCE(g2.tamamlandi, false) = false
                           AND COALESCE(g2.iptal, false) = false)
         AND (p_padok IS NULL OR h.padok = p_padok)
    ), takiptekiler AS (
      -- §6c.5: açık TAKIP_MUAYENE görevi = takipteki Boş hayvan (P2a sonrası dolur;
      -- tip bugün yoksa küme boş — tanınmayan tip hata ÜRETMEZ, §7.8 ile uyumlu).
      SELECT DISTINCT ON (g.hayvan_id)
             g.id AS takip_gorev_id, g.hayvan_id, g.hedef_tarih, g.hedef_saat
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'TAKIP_MUAYENE'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND (p_padok IS NULL OR h.padok = p_padok)
       ORDER BY g.hayvan_id, g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
    ), acik_muayene_gorevi AS (
      -- ── K15: açık GEBELIK_KONTROL görevi (S2 satır aksiyonu buna bağlanır) ──

      SELECT DISTINCT ON (g.hayvan_id)
             g.hayvan_id, g.id AS muayene_gorev_id
        FROM public.gorev_log g
       WHERE g.gorev_tipi = 'GEBELIK_KONTROL'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
       ORDER BY g.hayvan_id, g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
    ), ilgili_hayvanlar AS (
      -- ── Hayvan düzeyi yardımcılar (K13 deneme sayacı + taban_turu) ──

      SELECT hayvan_id FROM vaka_spine
      UNION SELECT hayvan_id FROM baslat_gorevli
      UNION SELECT hayvan_id FROM baslat_gorevsiz
      UNION SELECT hayvan_id FROM sonuc_bekleyen
      UNION SELECT hayvan_id FROM takiptekiler
    ), hayvan_ureme AS (
      -- K13/§18.14: gösterim denemesi SON DOĞUMDAN beri sayılır; doğum yoksa ömür boyu.
      SELECT s.hayvan_id,
             (SELECT count(*) FROM public.tohumlama t
               WHERE t.hayvan_id = s.hayvan_id
                 AND ((SELECT max(d2.tarih) FROM public.dogum d2 WHERE d2.anne_id = s.hayvan_id) IS NULL
                      OR t.tarih >= (SELECT max(d2.tarih) FROM public.dogum d2 WHERE d2.anne_id = s.hayvan_id))
             ) AS deneme_sayisi
        FROM ilgili_hayvanlar s
    ), hayvan_taban AS (
      SELECT s.hayvan_id,
             CASE
               WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = s.hayvan_id) THEN 'dogum'::text
               WHEN EXISTS (SELECT 1 FROM public.tohumlama t
                             WHERE t.hayvan_id = s.hayvan_id AND t.sonuc = 'Abort'
                               AND t.abort_tarihi IS NOT NULL) THEN 'abort'::text
               WHEN (SELECT h2.dogum_tarihi FROM public.hayvanlar h2 WHERE h2.id = s.hayvan_id) IS NOT NULL THEN 'duve'::text
               ELSE 'acik_disi'::text
             END AS taban_turu
        FROM ilgili_hayvanlar s
    ), vaka_satirlar AS (
      -- ── S0/S1/S4 satırları (vaka omurgasından) ──

      SELECT
        CASE
          WHEN v.vaka_tip = 'kapali' THEN 'S4'
          WHEN COALESCE(go.gecikme_gun, 0) > 0
               OR (ta.gorev_id IS NOT NULL AND ta.durum = 'gecikti')
               OR COALESCE(go.bugun_isi, false)
               OR (ta.gorev_id IS NOT NULL AND ta.durum = 'planli' AND ta.hedef_tarih = b.d)
            THEN 'S0'
          ELSE 'S1'
        END AS bolum,
        CASE
          WHEN COALESCE(go.gecikme_gun, 0) > 0 OR (ta.gorev_id IS NOT NULL AND ta.durum = 'gecikti')
            THEN 'geciken'
          ELSE 'bugun'
        END AS kpa_tip,
        jsonb_build_object(
          'bolum',
          CASE
            WHEN v.vaka_tip = 'kapali' THEN 'S4'
            WHEN COALESCE(go.gecikme_gun, 0) > 0
                 OR (ta.gorev_id IS NOT NULL AND ta.durum = 'gecikti')
                 OR COALESCE(go.bugun_isi, false)
                 OR (ta.gorev_id IS NOT NULL AND ta.durum = 'planli' AND ta.hedef_tarih = b.d)
              THEN 'S0'
            ELSE 'S1'
          END,
          'dalga_anahtari', vd.dalga_anahtari,
          'hayvan_id', v.hayvan_id,
          'kupe_no', v.kupe_no,
          'grup', v.grup,
          'padok', v.padok,
          'taban_turu', ht.taban_turu,
          'gunler', COALESCE(go.gunler, '[]'::jsonb),
          'tai',
          CASE WHEN ta.gorev_id IS NOT NULL THEN
            jsonb_build_object('gorev_id', ta.gorev_id, 'hedef_tarih', ta.hedef_tarih,
                               'hedef_saat', ta.hedef_saat, 'durum', ta.durum,
                               'kaynak', ta.kaynak_tur)
          END,
          'sonraki_gun', go.sonraki_gun,
          'gecikme_gun',
          GREATEST(
            COALESCE(go.gecikme_gun, 0),
            CASE WHEN ta.gorev_id IS NOT NULL AND ta.durum = 'gecikti'
                 THEN b.d - ta.hedef_tarih ELSE 0 END),
          'sapma', jsonb_build_object(
            'hedef_baslangic', vd.hedef_baslangic,
            'fiili_baslangic', go.fiili_baslangic,
            'kayma_gun',
            CASE WHEN vd.hedef_baslangic IS NOT NULL AND go.fiili_baslangic IS NOT NULL
                 THEN go.fiili_baslangic - vd.hedef_baslangic END,
            'erken_tai',
            COALESCE(
              vth.toh_tarih IS NOT NULL AND (
                (ta.gorev_id IS NOT NULL AND vth.toh_tarih < ta.hedef_tarih)
                OR (ta.gorev_id IS NULL AND COALESCE(toz.tai_gorev_var, false)
                    AND vth.toh_tarih < toz.max_tai_hedef)),
              false),
            'gorevsiz_tai',
            vth.toh_tarih IS NOT NULL AND NOT COALESCE(toz.tai_gorev_var, false)),
          -- §7.4: kapanış nedeni NULL → 'ESKI' (yalnız S4'te dolu).
          'close_reason',
          CASE WHEN v.vaka_tip = 'kapali' THEN COALESCE(v.close_reason, 'ESKI') END,
          -- §7.5: S4'te köprü eşleşmezse 'bilinmiyor'; açık vakada henüz tohumlama
          -- yoksa NULL dürüsttür (tahmin yok).
          'toh_sonuc',
          CASE WHEN v.vaka_tip = 'kapali' THEN COALESCE(vth.toh_sonuc, 'bilinmiyor')
               ELSE vth.toh_sonuc END,
          'deneme_sayisi', hu.deneme_sayisi,
          'muayene', NULL::jsonb,
          'takip', NULL::jsonb,
          'muayene_gorev_id', am.muayene_gorev_id
        ) AS row_j,
        vd.dalga_anahtari AS sira_tarih,
        v.kapanis_tarihi AS sira_kapanis,
        v.hayvan_id AS sira_hayvan
      FROM vaka_spine v
      CROSS JOIN bugun b
      LEFT JOIN gun_ozet go ON go.case_id = v.case_id
      LEFT JOIN vaka_tai ta ON ta.case_id = v.case_id
      LEFT JOIN vaka_tai_ozet toz ON toz.case_id = v.case_id
      LEFT JOIN vaka_toh vth ON vth.case_id = v.case_id
      LEFT JOIN vaka_dalga vd ON vd.case_id = v.case_id
      LEFT JOIN hayvan_ureme hu ON hu.hayvan_id = v.hayvan_id
      LEFT JOIN hayvan_taban ht ON ht.hayvan_id = v.hayvan_id
      LEFT JOIN acik_muayene_gorevi am ON am.hayvan_id = v.hayvan_id
    ), s2_satirlar AS (
      SELECT 'S2'::text AS bolum, 'muayene'::text AS kpa_tip,
             jsonb_build_object(
               'bolum', 'S2',
               'dalga_anahtari', sd.dalga_anahtari,
               'hayvan_id', sb.hayvan_id,
               'kupe_no', sb.kupe_no,
               'grup', sb.grup,
               'padok', sb.padok,
               'taban_turu', ht.taban_turu,
               'gunler', '[]'::jsonb,
               'tai', NULL::jsonb,
               'sonraki_gun', NULL::int,
               'gecikme_gun', 0,
               'sapma', jsonb_build_object(
                 'hedef_baslangic', NULL::date, 'fiili_baslangic', NULL::date,
                 'kayma_gun', NULL::int, 'erken_tai', false, 'gorevsiz_tai', false),
               'close_reason', NULL::text,
               'toh_sonuc', 'Bekliyor',
               'deneme_sayisi', hu.deneme_sayisi,
               'muayene', jsonb_build_object(
                 'tai_tarihi', sb.son_toh_tarihi,
                 'muayene_tarihi', sb.son_toh_tarihi + e.muayene_gun,
                 'kalan_gun', sb.son_toh_tarihi + e.muayene_gun - CURRENT_DATE),
               'takip', NULL::jsonb,
               'muayene_gorev_id', am.muayene_gorev_id
             ) AS row_j,
             (sb.son_toh_tarihi + e.muayene_gun - CURRENT_DATE) AS sira_kalan,
             sb.hayvan_id AS sira_hayvan
      FROM sonuc_bekleyen sb
      LEFT JOIN s2_dalga sd ON sd.toh_id = sb.toh_id
      CROSS JOIN esik e
      LEFT JOIN hayvan_ureme hu ON hu.hayvan_id = sb.hayvan_id
      LEFT JOIN hayvan_taban ht ON ht.hayvan_id = sb.hayvan_id
      LEFT JOIN acik_muayene_gorevi am ON am.hayvan_id = sb.hayvan_id
    ), s3_gorevli AS (
      SELECT 'S3'::text AS bolum, 'baslatma'::text AS kpa_tip,
             jsonb_build_object(
               'bolum', 'S3',
               'dalga_anahtari', bg.hedef_tarih,
               'hayvan_id', bg.hayvan_id,
               'kupe_no', h.kupe_no,
               'grup', COALESCE(h.kategori, h.grup),
               'padok', h.padok,
               'taban_turu', bg.taban_turu,
               'gunler', '[]'::jsonb,
               'tai', NULL::jsonb,
               'sonraki_gun', NULL::int,
               'gecikme_gun', 0,
               'sapma', jsonb_build_object(
                 'hedef_baslangic', bg.hedef_tarih, 'fiili_baslangic', NULL::date,
                 'kayma_gun', NULL::int, 'erken_tai', false, 'gorevsiz_tai', false),
               'close_reason', NULL::text,
               'toh_sonuc', NULL::text,
               'deneme_sayisi', hu.deneme_sayisi,
               'muayene', NULL::jsonb,
               'takip',
               CASE WHEN tk.takip_gorev_id IS NOT NULL THEN
                 jsonb_build_object('gorev_id', tk.takip_gorev_id,
                                    'hedef_tarih', tk.hedef_tarih,
                                    'hedef_saat', tk.hedef_saat)
               END,
               'muayene_gorev_id', am.muayene_gorev_id
             ) AS row_j,
             bg.hedef_tarih AS sira_tarih,
             (tk.takip_gorev_id IS NOT NULL) AS takipte_mi,
             bg.hayvan_id AS sira_hayvan
      FROM baslat_gorevli bg
      JOIN public.hayvanlar h ON h.id = bg.hayvan_id
      LEFT JOIN takiptekiler tk ON tk.hayvan_id = bg.hayvan_id
      LEFT JOIN hayvan_ureme hu ON hu.hayvan_id = bg.hayvan_id
      LEFT JOIN acik_muayene_gorevi am ON am.hayvan_id = bg.hayvan_id
    ), s3_gorevsiz AS (
      SELECT 'S3'::text AS bolum, 'baslatma'::text AS kpa_tip,
             jsonb_build_object(
               'bolum', 'S3',
               'dalga_anahtari', bgo.hedef_tarih,
               'hayvan_id', bgo.hayvan_id,
               'kupe_no', h.kupe_no,
               'grup', COALESCE(h.kategori, h.grup),
               'padok', h.padok,
               'taban_turu', bgo.taban_turu,
               'gunler', '[]'::jsonb,
               'tai', NULL::jsonb,
               'sonraki_gun', NULL::int,
               'gecikme_gun', 0,
               'sapma', jsonb_build_object(
                 'hedef_baslangic', NULL::date, 'fiili_baslangic', NULL::date,
                 'kayma_gun', NULL::int, 'erken_tai', false, 'gorevsiz_tai', false),
               'close_reason', NULL::text,
               'toh_sonuc', NULL::text,
               'deneme_sayisi', hu.deneme_sayisi,
               'muayene', NULL::jsonb,
               'takip', NULL::jsonb,
               'muayene_gorev_id', am.muayene_gorev_id
             ) AS row_j,
             bgo.hedef_tarih AS sira_tarih,
             false AS takipte_mi,
             bgo.hayvan_id AS sira_hayvan
      FROM baslat_gorevsiz bgo
      JOIN public.hayvanlar h ON h.id = bgo.hayvan_id
      LEFT JOIN hayvan_ureme hu ON hu.hayvan_id = bgo.hayvan_id
      LEFT JOIN acik_muayene_gorevi am ON am.hayvan_id = bgo.hayvan_id
    ), s3_takip AS (
      -- Yalnız göreve/görevsiz öneriye düşmeyen takiptekiler (mükerrer sayım yok).
      SELECT 'S3'::text AS bolum, 'takip'::text AS kpa_tip,
             jsonb_build_object(
               'bolum', 'S3',
               'dalga_anahtari', NULL::date,
               'hayvan_id', tk.hayvan_id,
               'kupe_no', h.kupe_no,
               'grup', COALESCE(h.kategori, h.grup),
               'padok', h.padok,
               'taban_turu', ht.taban_turu,
               'gunler', '[]'::jsonb,
               'tai', NULL::jsonb,
               'sonraki_gun', NULL::int,
               'gecikme_gun', 0,
               'sapma', jsonb_build_object(
                 'hedef_baslangic', NULL::date, 'fiili_baslangic', NULL::date,
                 'kayma_gun', NULL::int, 'erken_tai', false, 'gorevsiz_tai', false),
               'close_reason', NULL::text,
               'toh_sonuc', NULL::text,
               'deneme_sayisi', hu.deneme_sayisi,
               'muayene', NULL::jsonb,
               'takip', jsonb_build_object('gorev_id', tk.takip_gorev_id,
                                           'hedef_tarih', tk.hedef_tarih,
                                           'hedef_saat', tk.hedef_saat),
               'muayene_gorev_id', am.muayene_gorev_id
             ) AS row_j,
             tk.hedef_tarih AS sira_tarih,
             true AS takipte_mi,
             tk.hayvan_id AS sira_hayvan
      FROM takiptekiler tk
      JOIN public.hayvanlar h ON h.id = tk.hayvan_id
      LEFT JOIN hayvan_ureme hu ON hu.hayvan_id = tk.hayvan_id
      LEFT JOIN hayvan_taban ht ON ht.hayvan_id = tk.hayvan_id
      LEFT JOIN acik_muayene_gorevi am ON am.hayvan_id = tk.hayvan_id
     WHERE NOT EXISTS (SELECT 1 FROM baslat_gorevli bg WHERE bg.hayvan_id = tk.hayvan_id)
    ), satirlar AS (
      SELECT bolum, kpa_tip, row_j, sira_tarih, NULL::int AS sira_kalan, sira_kapanis,
             NULL::boolean AS takipte_mi, sira_hayvan
        FROM vaka_satirlar
      UNION ALL
      SELECT bolum, kpa_tip, row_j, NULL::date, sira_kalan, NULL::date,
             NULL::boolean, sira_hayvan
        FROM s2_satirlar
      UNION ALL
      SELECT bolum, kpa_tip, row_j, sira_tarih, NULL::int, NULL::date,
             takipte_mi, sira_hayvan
        FROM s3_gorevli
      UNION ALL
      SELECT bolum, kpa_tip, row_j, sira_tarih, NULL::int, NULL::date,
             takipte_mi, sira_hayvan
        FROM s3_gorevsiz
      UNION ALL
      SELECT bolum, kpa_tip, row_j, sira_tarih, NULL::int, NULL::date,
             takipte_mi, sira_hayvan
        FROM s3_takip
    ), kpa AS (
      SELECT
        count(*) FILTER (WHERE s.bolum IN ('S0', 'S1')) AS aktif,
        count(*) FILTER (WHERE s.bolum = 'S0' AND s.kpa_tip = 'bugun') AS bugun,
        count(*) FILTER (WHERE s.bolum = 'S0' AND s.kpa_tip = 'geciken') AS geciken,
        count(*) FILTER (WHERE s.bolum = 'S2') AS muayene_bekleyen,
        count(*) FILTER (WHERE s.bolum = 'S3') AS bekleyen_baslatma,
        count(*) FILTER (WHERE s.bolum = 'S3' AND COALESCE(s.takipte_mi, false)) AS bekleyen_baslatma_takipte
      FROM satirlar s
    )
    SELECT jsonb_build_object(
      'ok', true,
      'bayrak_kapali', false,
      'kpa', jsonb_build_object(
        'aktif', k.aktif,
        'bugun', k.bugun,
        'geciken', k.geciken,
        'muayene_bekleyen', k.muayene_bekleyen,
        'bekleyen_baslatma', k.bekleyen_baslatma,
        'bekleyen_baslatma_takipte', k.bekleyen_baslatma_takipte
      ),
      'esikler', jsonb_build_object('muayene_gun', e.muayene_gun, 'pencere_gun', 2),
      'satirlar', COALESCE((
        SELECT jsonb_agg(s.row_j ORDER BY
                 s.bolum,
                 -- S0/S1: dalga; S3: hedef (NULLS LAST); S4: kapanış (yeniden eskiye — negatif anahtar); S2: kalan gün
                 CASE
                   WHEN s.bolum = 'S4' THEN -1 * (s.sira_kapanis - DATE '1970-01-01')
                   WHEN s.bolum = 'S2' THEN s.sira_kalan
                   ELSE (s.sira_tarih - DATE '1970-01-01')
                 END ASC NULLS LAST,
                 s.sira_hayvan)
          FROM satirlar s
      ), '[]'::jsonb)
    )
    FROM kpa k
    CROSS JOIN esik e
  )
END AS sonuc
$function$;

REVOKE ALL ON FUNCTION public.ovsync_takip_listele(text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ovsync_takip_listele(text, integer) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260929000001_ovsync_takip_listele (P1)
