-- Migration: Aşı 2. Doz (Rota-Corona) Duplicate Görev Fix
-- Tarih: 2026-06-13
-- Yazar: Pi agent (MiniMax-M3) + kullanıcı brainstorm
-- Review + düzeltme: Claude (Opus 4.8) — bkz docs/plans/2026-06-13-asi-rapel-dupe-fix-REVIEW.md
-- Branch: feature/asilama-tam-mimari
-- Tasarım: docs/plans/2026-06-13-asi-rapel-dupe-fix-design.md
--
-- ═══════════════════════════════════════════════════════════════════════════
-- SORUN
-- ═══════════════════════════════════════════════════════════════════════════
-- Aynı düve için 2. doz Rota-Corona aşısı iki kez görev olarak oluşuyor:
--   1. ileri_gebe_asi_tamamla: 1. doz tamamlanınca rapel oluşturur (parent_id dolu)
--   2. gebelik_protokol_kontrol: 261. gün gelince preventive oluşturur (parent_id NULL)
--   3. ileri_gebe_gorev_kontrol: 261. gün gelince preventive oluşturur (parent_id NULL, eski)
--
-- Üçü de `aciklama` text'i üzerinden dedupe yapıyordu → string drift (20260525000003)
-- sonrası eski string'li kayıt yeni scan'de görünmüyor → duplicate. Ayrıca NOT EXISTS
-- atomik değil (READ COMMITTED) → race condition.
--
-- ═══════════════════════════════════════════════════════════════════════════
-- ÇÖZÜM
-- ═══════════════════════════════════════════════════════════════════════════
-- Semantic key (`etken_kod='ROTA_2DOZ'`) + UNIQUE PARTIAL INDEX.
--   - 1. doz `ROTA` kalır; 2. doz (tüm geçmiş + gelecek) `ROTA_2DOZ` olur.
--   - Partial index sadece aktif kayıtları kısıtlar (tamamlanmış/iptal audit birikebilir).
--
-- ═══════════════════════════════════════════════════════════════════════════
-- REVIEW DÜZELTMELERİ (canlı DB doğrulamasından sonra — 2026-06-13)
-- ═══════════════════════════════════════════════════════════════════════════
-- B1: ileri_gebe_asi_tamamla canlıda RETURNS jsonb → migration json idi → abort.
--     Düzeltildi: RETURNS jsonb + jsonb_build_object.
-- B2: Tamamlanmış 2. doz kayıtları canlıda etken_kod='ROTA' (NULL değil). Eski backfill
--     `etken_kod IS NULL` koşulu onları atlıyordu → cleanup'ın legit join'i kırılıyordu.
--     Düzeltildi: backfill `(etken_kod IS NULL OR etken_kod='ROTA')` ('%2. doz%' filtresi
--     1. doz'a değmez). Kullanıcı onayı: ROTA→ROTA_2DOZ yeniden etiketleme uygun.
-- B3: gebelik_protokol_kontrol 261 dedup'ına `tamamlandi=false` eklenmesi "gebelik başına
--     1 kez" korumasını kaldırıyordu. Çıkarıldı; ileri_gebe_gorev_kontrol ile hizalandı
--     (etken_kod='ROTA_2DOZ' AND iptal=false).
-- B4: Sıralama — cleanup, UNIQUE index'ten ÖNCE (savunma: backfill genişledi, aynı hayvanda
--     2+ aktif ROTA_2DOZ doğarsa index abort etmesin).
-- B5: Cleanup'a `tamamlandi=false` eklendi → sadece AKTİF stray görevler iptal edilir,
--     tamamlanmış tarihî kayıtlar (örn küpe 168 16b8513b) korunur.
-- B6: islem_log'da created_at kolonu yok (`tarih` var) → doğrulama sorguları düzeltildi.
--
-- KAPSAM: Sadece aşı 2. doz. 1. doz, Ademin, E Vitamini duplicate'lerine dokunulmaz.
-- Geri alma: Tasarım doc Bölüm 5 + bu dosyanın sonu.

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. BACKFILL: Tüm 2. doz kayıtlarına etken_kod='ROTA_2DOZ' yaz
-- ═══════════════════════════════════════════════════════════════════════════
-- NEDEN (etken_kod IS NULL OR etken_kod='ROTA'):
--   - Canlıda stray scheduler kaydı etken_kod=NULL, tamamlanmış/rapel kayıtlar 'ROTA'.
--   - Her ikisini de ROTA_2DOZ'a taşımalıyız ki cleanup'ın legit join'i + dedup tutarlı olsun.
-- NEDEN aciklama ILIKE '%2. doz%' güvenli:
--   - '(1. doz)' kayıtlarını dışlar → 1. doz 'ROTA' olarak kalır (composite key çakışmaz).
--   - '(2. doz)', '(2. doz — düve)', '(2. doz) — iptal edildi...' hepsini yakalar.
UPDATE gorev_log
SET etken_kod = 'ROTA_2DOZ'
WHERE gorev_tipi = 'ILERI_GEBE_ASI'
  AND aciklama ILIKE '%Rota-Corona%2. doz%'
  AND (etken_kod IS NULL OR etken_kod = 'ROTA');

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. MEVCUT DUPLICATE TEMİZLİĞİ (UNIQUE index'ten ÖNCE — B4)
-- ═══════════════════════════════════════════════════════════════════════════
-- KURAL: Aynı hayvan için parent_id'li (legit, ileri_gebe_asi_tamamla'dan) bir ROTA_2DOZ
-- kaydı varsa, parent_id NULL olan (scheduler'dan) AKTİF stray görev → iptal et.
--
-- NEDEN tamamlandi=false (B5): Sadece aktif/açık stray görevleri iptal et. Tamamlanmış
--   tarihî kayıtlara (gerçekten yapılmış aşı) dokunma — audit bütünlüğü.
-- NEDEN parent_id IS NULL: ileri_gebe_asi_tamamla her zaman parent_id set eder;
--   scheduler'lar etmez → parent_id NULL = scheduler kaynaklı duplicate.
-- NEDEN EXISTS legit: Eğer hayvan için SADECE scheduler kaydı varsa (1. doz hiç yapılmadı),
--   bu legitimate'tir → iptal etme.
UPDATE gorev_log uzak
SET iptal = true,
    aciklama = aciklama || ' — duplicate temizlendi (2026-06-13 fix)',
    kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP'
WHERE uzak.gorev_tipi = 'ILERI_GEBE_ASI'
  AND uzak.etken_kod = 'ROTA_2DOZ'
  AND uzak.iptal = false
  AND uzak.tamamlandi = false       -- ← B5: sadece aktif stray
  AND uzak.parent_id IS NULL
  AND EXISTS (
    SELECT 1 FROM gorev_log legit
    WHERE legit.hayvan_id = uzak.hayvan_id
      AND legit.etken_kod = 'ROTA_2DOZ'
      AND legit.parent_id IS NOT NULL
      AND legit.iptal = false
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. UNIQUE PARTIAL INDEX: Aktif duplicate'leri DB seviyesinde engelle
-- ═══════════════════════════════════════════════════════════════════════════
-- (cleanup sonrası → aynı hayvanda en fazla 1 aktif ROTA_2DOZ kaldığı garanti)
CREATE UNIQUE INDEX IF NOT EXISTS uq_gorev_rota_2doz_active
  ON gorev_log (hayvan_id, etken_kod)
  WHERE etken_kod = 'ROTA_2DOZ'
    AND iptal = false
    AND tamamlandi = false;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. ileri_gebe_asi_tamamla: Rapel INSERT'ine etken_kod + ON CONFLICT ekle
-- ═══════════════════════════════════════════════════════════════════════════
-- B1: Canlı imza RETURNS jsonb → aynısını koru (RETURNS json yaparsak abort).
CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(
  p_gorev_id   text,
  p_vaccine_id uuid,
  p_tarih      date    DEFAULT CURRENT_DATE,
  p_doz        numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_result  jsonb;
  v_rapel_id    uuid;
  v_rapel_tarih date;
  v_is_first    boolean;
BEGIN
  -- 1. Görevi çek ve kontrol et
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  -- 2. Aşıyı kaydet (add_vaccination → vaccination_log + stok trigger)
  --    'GorevID:' prefix → add_vaccination kendi ASI_RAPEL oluşturmaz (ileri_gebe halleder)
  SELECT public.add_vaccination(
    v_gorev.hayvan_id::text, p_vaccine_id, p_tarih, p_doz, 'GorevID:' || p_gorev_id
  ) INTO v_vax_result;

  IF (v_vax_result->>'ok')::boolean = false THEN
    RETURN v_vax_result;
  END IF;

  -- 3. Görevi tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- 4. 1. doz ise rapel görevi oluştur (21 gün sonra) — sadece düveler
  v_is_first := v_gorev.aciklama ILIKE '%1. doz%';
  IF v_is_first THEN
    -- Sadece Düve grubundaki hayvanlar rapel alır (inekler tek doz)
    PERFORM 1 FROM hayvanlar
    WHERE id = v_gorev.hayvan_id AND grup ILIKE '%Düve%';
    IF FOUND THEN
      v_rapel_tarih := p_tarih + 21;
      v_rapel_id := gen_random_uuid();
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak, etken_kod)
      VALUES (
        v_rapel_id,
        v_gorev.hayvan_id,
        'ILERI_GEBE_ASI',
        '💉 Rota-Corona Aşısı (2. doz — düve)',
        v_rapel_tarih,
        false,
        v_gorev.stok_id,
        1,
        v_gorev.id,
        'ILERI_GEBE',
        'ROTA_2DOZ'  -- ← semantic key
      )
      ON CONFLICT (hayvan_id, etken_kod) WHERE etken_kod = 'ROTA_2DOZ' AND iptal = false AND tamamlandi = false
      DO NOTHING;
      -- ↑ UNIQUE partial index ile çalışır (PostgreSQL partial index inference)
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_vax_result->>'vaccination_id',
    'rapel_gorev_id', v_rapel_id,
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. gebelik_protokol_kontrol: 261. gün INSERT'inde etken_kod bazlı dedupe
-- ═══════════════════════════════════════════════════════════════════════════
-- Sadece 261. gün bloğu değişiyor. Diğer bloklar canlı ile birebir.
-- B3: dedup = etken_kod='ROTA_2DOZ' AND iptal=false (tamamlandi filtresi YOK —
--     gebelik başına 1 kez koruması: non-cancelled herhangi bir ROTA_2DOZ varsa üretme).
CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_padok_kuru  text;
  v_stok_id     text;
BEGIN
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih, t.id
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- 210. gün: Kuru dönem (değişiklik yok)
    IF v_gun >= 210
       AND v_hayvan.grup ILIKE '%Sağmal%'
       AND v_hayvan.grup NOT ILIKE '%Kuru%'
    THEN
      v_hedef := v_toh.tarih::date + 210;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'PADOK_DEGISIM',
             '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün gebelik) — Kuru/Gebe padoğuna transfer',
             v_hedef, false, v_padok_kuru, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'PADOK_DEGISIM'
          AND aciklama ILIKE '%Kuru döneme%'
          AND iptal = false
          AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 240. gün: Rota-Corona 1. doz (değişiklik yok — scope dışı)
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (sadece düveler) — ← DEĞİŞEN BLOK
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id, etken_kod)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_toh.id::text,
             'ROTA_2DOZ'  -- ← semantic key
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND etken_kod = 'ROTA_2DOZ'  -- ← aciklama yerine etken_kod
          AND iptal = false            -- ← tamamlandi filtresi YOK (B3: gebelik başına 1 kez)
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin (değişiklik yok)
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: IM E Vitamini (değişiklik yok)
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260+ gün: Besleme (Anyonik Sabah/Akşam) (değişiklik yok)
    IF v_gun >= 260 THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'BESLEME'
          AND aciklama = '🌅 Anyonik Besleme (Sabah)'
          AND hedef_tarih = CURRENT_DATE
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;

      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌙 Anyonik Besleme (Akşam)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'BESLEME'
          AND aciklama = '🌙 Anyonik Besleme (Akşam)'
          AND hedef_tarih = CURRENT_DATE
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'olusturulan', v_olusturulan,
    'hayvanlar', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'hayvan_id',    t.hayvan_id,
          'tarih',        t.tarih::text,
          'gebelik_gun',  CURRENT_DATE - t.tarih::date,
          'kupe_no',      h.kupe_no,
          'devlet_kupe',  h.devlet_kupe,
          'grup',         h.grup,
          'padok',        h.padok
        )
        ORDER BY CURRENT_DATE - t.tarih::date DESC
      )
      FROM tohumlama t
      JOIN hayvanlar h ON h.id = t.hayvan_id
      WHERE t.sonuc = 'Gebe'
        AND h.durum = 'Aktif'
        AND CURRENT_DATE - t.tarih::date >= 210
        AND t.tarih = (
          SELECT MAX(t2.tarih) FROM tohumlama t2
          WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe'
        )
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gebelik_protokol_kontrol() TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. ileri_gebe_gorev_kontrol: 261. gün bloğunda etken_kod bazlı dedupe
-- ═══════════════════════════════════════════════════════════════════════════
-- Canlı scheduler (loadTasks'tan çağrılıyor). Aynı 261 düzeltmesi.
-- Dedup gebelik_protokol_kontrol ile hizalı: etken_kod='ROTA_2DOZ' AND iptal=false.
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_stok_id     text;
  v_kaynak      text;
  v_inst_id     uuid;
BEGIN
  SELECT v.stock_item_id INTO v_stok_id FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun    := CURRENT_DATE - v_toh.tarih::date;
    v_kaynak := 'ILERI_GEBE-' || v_toh.hayvan_id;

    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (v_toh.hayvan_id, 'UREME', 'GEBELIK', v_kaynak, v_toh.tarih::date, 'aktif')
    ON CONFLICT (kaynak_ref) DO NOTHING;

    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;

    -- 240. gün: Rota-Corona 1. doz (değişiklik yok)
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (sadece düveler) — ← DEĞİŞEN BLOK
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id, etken_kod)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id,
             'ROTA_2DOZ'  -- ← semantic key
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND etken_kod = 'ROTA_2DOZ'  -- ← aciklama yerine etken_kod
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin (değişiklik yok)
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: E Vitamini (değişiklik yok)
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_gorev_kontrol() TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. AUDIT LOG: Temizlik özetini islem_log'a yaz
-- ═══════════════════════════════════════════════════════════════════════════
-- NOT: islem_log'da created_at YOK; varsayılan 'tarih timestamptz default now()'.
INSERT INTO islem_log (id, tip, snapshot)
SELECT
  gen_random_uuid()::text,
  'ASI_RAPEL_DUPE_CLEANUP',
  jsonb_build_object(
    'iptal_edilen_count', COUNT(*),
    'tarih', CURRENT_DATE,
    'migration', '20260613000001_asi_rapel_dupe_fix',
    'kural', 'parent_id NULL + tamamlandi=false + aynı hayvan için parent_id dolu legit ROTA_2DOZ olan aktif stray'
  )
FROM gorev_log
WHERE kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP'
  AND iptal = true;

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. SCHEMA CACHE YENİLE (PostgREST)
-- ═══════════════════════════════════════════════════════════════════════════
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
-- ÇALIŞTIRMA SONRASI DOĞRULAMA (ayrı çalıştır):
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Aktif duplicate sayısı (0 olmalı):
--    SELECT hayvan_id, COUNT(*) FROM gorev_log
--    WHERE etken_kod='ROTA_2DOZ' AND iptal=false AND tamamlandi=false
--    GROUP BY hayvan_id HAVING COUNT(*) > 1;
--
-- 2. İptal edilen stray sayısı (1 olmalı: küpe 184 / 16de0128):
--    SELECT id, hayvan_id, aciklama FROM gorev_log
--    WHERE kapatan_ref='ASI_RAPEL_DUPE_CLEANUP' AND iptal=true;
--
-- 3. islem_log audit (1 kayıt, snapshot.iptal_edilen_count=1) — DİKKAT: tarih (created_at YOK):
--    SELECT * FROM islem_log WHERE tip='ASI_RAPEL_DUPE_CLEANUP' ORDER BY tarih DESC LIMIT 1;
--
-- 4. Tamamlanmış tarihî kayıt korundu mu (küpe 168 16b8513b iptal OLMAMALI):
--    SELECT id, tamamlandi, iptal FROM gorev_log WHERE id='16b8513b-f94a-4d44-97dd-2b433a5a1aa1';
--
-- 5. UNIQUE constraint test (TEST-HAYVAN, 2 INSERT → 2.si unique_violation):
--    Detaylı kod: docs/plans/2026-06-13-asi-rapel-dupe-fix-design.md Bölüm 4.2
--
-- 6. Idempotency (aynı fonksiyon 2 kez → olusturulan=0):
--    SELECT ileri_gebe_gorev_kontrol(); SELECT ileri_gebe_gorev_kontrol();
--    SELECT gebelik_protokol_kontrol();
--
-- ═══════════════════════════════════════════════════════════════════════════
-- GERİ ALMA (acil durumda):
-- ═══════════════════════════════════════════════════════════════════════════
-- DROP INDEX IF EXISTS uq_gorev_rota_2doz_active;
-- -- 3 RPC'yi eski haline döndür (canlı: 20260603000005 + 20260605000008; ileri_gebe_asi_tamamla jsonb)
-- UPDATE gorev_log SET iptal=false, aciklama=REPLACE(aciklama,' — duplicate temizlendi (2026-06-13 fix)',''), kapatan_ref=NULL
-- WHERE kapatan_ref='ASI_RAPEL_DUPE_CLEANUP';
-- -- etken_kod ROTA_2DOZ backfill geri alınabilir: UPDATE ... SET etken_kod='ROTA' WHERE etken_kod='ROTA_2DOZ';
