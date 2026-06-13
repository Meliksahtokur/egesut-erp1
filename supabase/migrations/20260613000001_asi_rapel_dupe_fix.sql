-- Migration: Aşı 2. Doz (Rota-Corona) Duplicate Görev Fix
-- Tarih: 2026-06-13
-- Yazar: Pi agent (MiniMax-M3) + kullanıcı brainstorm
-- Branch: main (hotfix)
-- Tasarım: docs/plans/2026-06-13-asi-rapel-dupe-fix-design.md
--
-- ═══════════════════════════════════════════════════════════════════════════
-- SORUN
-- ═══════════════════════════════════════════════════════════════════════════
-- Aynı düve için 2. doz Rota-Corona aşısı iki kez görev olarak oluşuyor:
--   1. ileri_gebe_asi_tamamla: 1. doz tamamlanınca rapel oluşturur
--   2. gebelik_protokol_kontrol: 261. gün gelince preventive oluşturur
--   3. ileri_gebe_gorev_kontrol: 261. gün gelince preventive oluşturur (eski)
--
-- Üçü de `aciklama` text'i üzerinden dedupe yapar:
--   - 2026-05-22: eski string '(2. doz)' ile kayıt oluştu (migration 20260509000003)
--   - 2026-05-25: string '(2. doz — düve)' olarak değişti (migration 20260525000003)
--   - 2026-06-12: yeni scan eski string'li kaydı görmedi → duplicate oluştu
--
-- Ek olarak `NOT EXISTS` atomik değil → race condition ile 2 paralel transaction
-- aynı INSERT'i yapabilir (PostgreSQL default READ COMMITTED).
--
-- ═══════════════════════════════════════════════════════════════════════════
-- ÇÖZÜM
-- ═══════════════════════════════════════════════════════════════════════════
-- Semantic key (`etken_kod='ROTA_2DOZ'`) + UNIQUE PARTIAL INDEX
--   - 1. doz zaten `etken_kod='ROTA'`, 2. doz için `ROTA_2DOZ` kullanılır
--   - Partial index sadece aktif kayıtları kısıtlar (tamamlanmış/iptal audit birikebilir)
--   - UNIQUE constraint race condition imkansız kılar
--   - 3 yol birleştirilmiyor (kullanıcı scope kararı), sadece duplicate oluşumu engelleniyor
--
-- KAPSAM: Sadece aşı 2. doz. 1. doz, Ademin, E Vitamini duplicate'lerine dokunulmaz.
--
-- Geri alma: Tasarım doc Bölüm 5. DROP INDEX + 3 RPC'yi eski haline döndür.

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. BACKFILL: Mevcut 2. doz kayıtlarına etken_kod='ROTA_2DOZ' yaz
-- ═══════════════════════════════════════════════════════════════════════════
-- NEDEN: Bu UPDATE olmadan UNIQUE constraint eski kayıtları görmez
--   → aktif duplicate hâlâ oluşabilir
-- NEDEN her iki string varyantı: '(2. doz)' (eski, düve'siz) ve '(2. doz — düve)' (yeni)
--   → string drift sonrası her ikisi de DB'de mevcut
UPDATE gorev_log
SET etken_kod = 'ROTA_2DOZ'
WHERE gorev_tipi = 'ILERI_GEBE_ASI'
  AND aciklama ILIKE '%Rota-Corona%2. doz%'
  AND etken_kod IS NULL;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. UNIQUE PARTIAL INDEX: Aktif duplicate'leri DB seviyesinde engelle
-- ═══════════════════════════════════════════════════════════════════════════
-- NEDEN partial (iptal=false AND tamamlandi=false):
--   - Tamamlanmış (tamamlandi=true) → audit trail için birikebilir
--     (aynı hayvana birden fazla kez aşı yapılmış olabilir, tıbbi geçmiş)
--   - İptal edilmiş (iptal=true) → temizlik geçmişi için birikebilir
--   - Sadece aktif (false/false) → max 1 kayıt
-- NEDEN (hayvan_id, etken_kod) key:
--   - Bir hayvan için 2. doz aşısı = en fazla 1 aktif görev
--   - 1. doz ayrı etken_kod='ROTA' → çakışma yok (composite key farklı)
--   - Aynı hayvana farklı etken_kod (ROTA, ADEMIN, E_VIT) → çakışma yok
CREATE UNIQUE INDEX IF NOT EXISTS uq_gorev_rota_2doz_active
  ON gorev_log (hayvan_id, etken_kod)
  WHERE etken_kod = 'ROTA_2DOZ'
    AND iptal = false
    AND tamamlandi = false;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. ileri_gebe_asi_tamamla: Rapel INSERT'ine etken_kod + ON CONFLICT ekle
-- ═══════════════════════════════════════════════════════════════════════════
-- ESKİ davranış: 'ON CONFLICT DO NOTHING' — UNIQUE constraint yoktu, anlamsızdı
-- YENİ davranış: 'ON CONFLICT (hayvan_id, etken_kod) WHERE ... DO NOTHING'
--   → UNIQUE partial index ile çalışır
-- Düve kontrolü korundu (migration 20260525000003'ten). Sadece düveler rapel alır.
CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(
  p_gorev_id   text,
  p_vaccine_id uuid,
  p_tarih      date    DEFAULT CURRENT_DATE,
  p_doz        numeric DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_result  json;
  v_rapel_id    uuid;
  v_rapel_tarih date;
  v_is_first    boolean;
BEGIN
  -- 1. Görevi çek ve kontrol et
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN json_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
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
        'ROTA_2DOZ'  -- ← YENİ: semantic key
      )
      ON CONFLICT (hayvan_id, etken_kod) WHERE etken_kod = 'ROTA_2DOZ' AND iptal = false AND tamamlandi = false
      DO NOTHING;
      -- ↑ YENİ: UNIQUE partial index ile çalışır
      --   (PostgreSQL ON CONFLICT partial index WHERE syntax'ı destekler)
    END IF;
  END IF;

  RETURN json_build_object(
    'ok', true,
    'vaccination_id', v_vax_result->>'vaccination_id',
    'rapel_gorev_id', v_rapel_id,
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. gebelik_protokol_kontrol: 261. gün INSERT'inde etken_kod kullan
-- ═══════════════════════════════════════════════════════════════════════════
-- ESKİ davranış: 'NOT EXISTS WHERE aciklama = ...' → string değişiminde bozulur
-- YENİ davranış: 'NOT EXISTS WHERE etken_kod = ...' → semantik anahtar
--   + ek olarak ON CONFLICT (defense in depth) → UNIQUE constraint koruması
--
-- Bu fonksiyonun TAMAMINI yeniden yazıyoruz çünkü:
--   - 240. gün (1. doz) → etken_kod='ROTA' (zaten yok, eklemiyoruz, scope dışı)
--   - 261. gün (2. doz düve) → etken_kod='ROTA_2DOZ' ← DEĞİŞİYOR
--   - 260. gün (SC Ademin) → etken_kod='ADEMIN' (zaten var, eklemiyoruz)
--   - 265. gün (E Vitamini) → etken_kod='E_VIT' (zaten var, eklemiyoruz)
--   - 210. gün (Kuru dönem) → etken_kod yok (PADOK_DEGISIM, scope dışı)
--   - Besleme (260+) → etken_kod yok (BESLEME, scope dışı)
--
-- Sadece 261. gün bloğu değişiyor. Diğer bloklar birebir aynı kalır.
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
             'ROTA_2DOZ'  -- ← YENİ: semantic key
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND etken_kod = 'ROTA_2DOZ'  -- ← DEĞİŞTİ: aciklama yerine etken_kod
          AND iptal = false
          AND tamamlandi = false  -- ← YENİ: partial index ile uyumlu
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
-- 5. ileri_gebe_gorev_kontrol: 261. gün bloğunda etken_kod kullan
-- ═══════════════════════════════════════════════════════════════════════════
-- Bu fonksiyon canlı scheduler olarak `gebelik_protokol_kontrol` ile çift çalışıyor
-- (kullanıcı notu: "ileri_gebe_gorev_kontrol hâlâ neden canlı?" → mimari refactor,
--  bu fix scope dışı). Aynı 261. gün düzeltmesini buraya da uyguluyoruz.
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
             'ROTA_2DOZ'  -- ← YENİ: semantic key
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND etken_kod = 'ROTA_2DOZ'  -- ← DEĞİŞTİ: aciklama yerine etken_kod
          AND iptal = false  -- ← YENİ: partial index ile uyumlu
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
-- 6. MEVCUT DUPLICATE TEMİZLİĞİ: Parent_id NULL olan aktif duplicate'leri iptal et
-- ═══════════════════════════════════════════════════════════════════════════
-- KURAL:
--   - Aynı hayvan için etken_kod='ROTA_2DOZ' parent_id'li başka kayıt varsa
--   - ve bizim kaydımız parent_id NULL ise → iptal et (duplicate)
--
-- NEDEN sadece parent_id IS NULL olan:
--   - ileri_gebe_asi_tamamla her zaman parent_id set eder (1. doz görevinin ID'si)
--   - gebelik_protokol_kontrol ve ileri_gebe_gorev_kontrol parent_id set etmez
--   - parent_id NULL olan = scheduler tarafından oluşturulan duplicate
--
-- NEDEN sadece legitimate kayıt varsa:
--   - Eğer hayvan için SADECE gebelik_protokol_kontrol kayıt oluşturduysa
--     (1. doz henüz yapılmadıysa), bu legitimate'tir
--   - Sadece gerçekten duplicate olanları işaretle
--
-- ÇIKTI: iptal=true + aciklama'ya suffix + kapatan_ref='ASI_RAPEL_DUPE_CLEANUP'
--   (geri alınabilir, audit trail korunur)
UPDATE gorev_log uzak
SET iptal = true,
    aciklama = aciklama || ' — duplicate temizlendi (2026-06-13 fix)',
    kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP'
WHERE uzak.gorev_tipi = 'ILERI_GEBE_ASI'
  AND uzak.etken_kod = 'ROTA_2DOZ'
  AND uzak.iptal = false
  AND uzak.parent_id IS NULL
  AND EXISTS (
    SELECT 1 FROM gorev_log legit
    WHERE legit.hayvan_id = uzak.hayvan_id
      AND legit.etken_kod = 'ROTA_2DOZ'
      AND legit.parent_id IS NOT NULL
      AND legit.iptal = false
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. AUDIT LOG: Temizlik özetini islem_log'a yaz
-- ═══════════════════════════════════════════════════════════════════════════
-- NEDEN: Geri alma ve denetim için. kaç kayıt iptal edildi, hangi tarihte, hangi migration.
INSERT INTO islem_log (id, tip, snapshot)
SELECT
  gen_random_uuid()::text,
  'ASI_RAPEL_DUPE_CLEANUP',
  jsonb_build_object(
    'iptal_edilen_count', COUNT(*),
    'tarih', CURRENT_DATE,
    'migration', '20260613000001_asi_rapel_dupe_fix',
    'kural', 'parent_id NULL olan ve aynı hayvan için parent_id dolu başka kayıt olan aktif duplicate'
  )
FROM gorev_log
WHERE kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP'
  AND iptal = true;

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. SCHEMA CACHE YENİLE (PostgREST api için gerekli)
-- ═══════════════════════════════════════════════════════════════════════════
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
-- ÇALIŞTIRMA SONRASI DOĞRULAMA (supabase_migrate ile, ayrı çalıştır):
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Aktif duplicate sayısı (0 olmalı):
--    SELECT hayvan_id, COUNT(*) FROM gorev_log
--    WHERE etken_kod='ROTA_2DOZ' AND iptal=false
--    GROUP BY hayvan_id HAVING COUNT(*) > 1;
--
-- 2. İptal edilen duplicate sayısı (2 olmalı: küpe 184 + bcc67af7):
--    SELECT COUNT(*) FROM gorev_log
--    WHERE kapatan_ref='ASI_RAPEL_DUPE_CLEANUP' AND iptal=true;
--
-- 3. islem_log audit (1 kayıt):
--    SELECT * FROM islem_log WHERE tip='ASI_RAPEL_DUPE_CLEANUP' ORDER BY created_at DESC LIMIT 1;
--
-- 4. UNIQUE constraint test (TEST-HAYVAN oluşturup 2 INSERT dene):
--    DO $$ DECLARE ... unique_violation beklenir ... END $$;
--    Detaylı kod: docs/plans/2026-06-13-asi-rapel-dupe-fix-design.md Bölüm 4.2
--
-- 5. Idempotency test (aynı fonksiyon 2 kez çalıştır, olusturulan=0 dönmeli):
--    SELECT ileri_gebe_gorev_kontrol();  -- 1. çağrı
--    SELECT ileri_gebe_gorev_kontrol();  -- 2. çağrı (olusturulan=0 beklenir)
--    SELECT gebelik_protokol_kontrol();  -- 3. çağrı (olusturulan=0 beklenir)
--
-- ═══════════════════════════════════════════════════════════════════════════
-- GERİ ALMA (acil durumda):
-- ═══════════════════════════════════════════════════════════════════════════
-- DROP INDEX IF EXISTS uq_gorev_rota_2doz_active;
-- -- 3 RPC'yi eski haline döndür (migration 20260603000005_protokol_fix_v2 + 20260525000003 + 20260605000008)
-- -- iptal_edilen duplicate'leri geri al (opsiyonel):
-- UPDATE gorev_log SET iptal=false, aciklama=REPLACE(aciklama, ' — duplicate temizlendi (2026-06-13 fix)', ''), kapatan_ref=NULL
-- WHERE kapatan_ref='ASI_RAPEL_DUPE_CLEANUP';
-- -- etken_kod='ROTA_2DOZ' backfill geri alınamaz (kabul edilebilir, semantik etiket sadece)
-- -- Tasarım doc Bölüm 5: docs/plans/2026-06-13-asi-rapel-dupe-fix-design.md
