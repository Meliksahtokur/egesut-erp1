-- Migration: Anyonik Besleme Görevi — sabah+akşam zinciri, doğumda iptal
-- Etkiler:
--   1. gebelik_protokol_kontrol REPLACE — 260. günde BESLEME çifti ekle
--   2. besleme_tamam(text) yeni RPC — tamamlama + zincirleme
--   3. dogum_kaydet REPLACE — doğumda aktif BESLEME iptal
-- Geri alınabilir: DROP FUNCTION public.besleme_tamam(text);
--   gebelik_protokol_kontrol → migration 20260521000001 versiyonuna dön
--   dogum_kaydet → migration 99999999999999_ground_truth versiyonuna dön

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. gebelik_protokol_kontrol REPLACE — BESLEME bloğu eklendi
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
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
  -- Rota-Corona aşı stok_id'sini bul
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  -- Kuru/Gebe padok adını bul
  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  -- Tüm aktif gebe inekler — her hayvanın en son Gebe tohumlaması
  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- ── 210. gün: Kuru dönem transfer ──────────────────────────────
    -- Sadece hâlâ Sağmal grubunda olan ineklere (Kuru'ya taşınmamışsa)
    IF v_gun >= 210
       AND v_hayvan.grup ILIKE '%Sağmal%'
       AND v_hayvan.grup NOT ILIKE '%Kuru%'
    THEN
      v_hedef := v_toh.tarih::date + 210;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'PADOK_DEGISIM',
             '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün gebelik) — Kuru/Gebe padoğuna transfer',
             v_hedef, false, v_padok_kuru
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

    -- ── 240. gün: Rota-Corona 1. doz (tüm gebeler) ─────────────────
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 261. gün: Rota-Corona 2. doz (sadece düveler) ──────────────
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 260. gün: SC Ademin (tüm gebeler) ──────────────────────────
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 265. gün: IM E Vitamini (tüm gebeler) ──────────────────────
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 260. gün: Anyonik Besleme — SABAH (günlük zincir başlangıcı) ──────
    IF v_gun >= 260 THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, 'BESLEME_OTOMATIK'
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

      -- ── 260. gün: Anyonik Besleme — AKŞAM ────────────────────────────
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌙 Anyonik Besleme (Akşam)', CURRENT_DATE, false, 'BESLEME_OTOMATIK'
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

-- ═══════════════════════════════════════════════════════════
-- 2. besleme_tamam RPC — tamamlama + zincirleme
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.besleme_tamam(p_gorev_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev gorev_log%ROWTYPE;
  v_yeni_id uuid;
BEGIN
  -- 1. Görevi çek
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten kapalı');
  END IF;

  -- 2. Tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- 3. Hayvan hâlâ gebe mi kontrol et (doğum yapmışsa zinciri kesme)
  IF NOT EXISTS (
    SELECT 1 FROM tohumlama
    WHERE hayvan_id = v_gorev.hayvan_id
      AND sonuc = 'Gebe'
  ) THEN
    RETURN jsonb_build_object('ok', true, 'zincir', 'hayvan_artik_gebe_degil');
  END IF;

  -- 4. Zincirleme: ertesi gün için aynı besleme tipini oluştur
  v_yeni_id := gen_random_uuid();
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih,
                         tamamlandi, kaynak, parent_id)
  SELECT v_yeni_id, v_gorev.hayvan_id, 'BESLEME',
         v_gorev.aciklama,                 -- aynı başlık (Sabah veya Akşam)
         v_gorev.hedef_tarih + 1,          -- ertesi gün
         false, 'BESLEME_OTOMATIK', v_gorev.id::text
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = v_gorev.hayvan_id
      AND aciklama = v_gorev.aciklama
      AND hedef_tarih = v_gorev.hedef_tarih + 1
      AND iptal = false
  );

  RETURN jsonb_build_object('ok', true, 'yeni_gorev_id', v_yeni_id, 'tarih', v_gorev.hedef_tarih + 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.besleme_tamam(text) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 3. dogum_kaydet REPLACE — BESLEME iptal bloğu eklendi
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.dogum_kaydet(
  p_anne_id    text,
  p_tarih      date,
  p_kupe       text,
  p_cins       text    DEFAULT 'Dişi',
  p_tip        text    DEFAULT 'Normal',
  p_kg         numeric DEFAULT NULL,
  p_baba       text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_anne        record;
  v_dogum_id    uuid := gen_random_uuid();
  v_buzagi_id   text;
  v_ana_gorev   uuid := gen_random_uuid();
  v_sayac       integer;
  v_dup         text;
  v_baba_bilgi  text;
BEGIN
  -- Anne var mı?
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı');
  END IF;

  -- Küpe daha önce var mı?
  SELECT id INTO v_dup FROM public.hayvanlar WHERE kupe_no = p_kupe OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe);
  END IF;

  -- Baba bilgisini aktif Gebe tohumlamadan al (UI p_baba göndermiyorsa)
  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi
    FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe'
    ORDER BY tarih DESC
    LIMIT 1;
  ELSE
    v_baba_bilgi := p_baba;
  END IF;

  -- 1. Doğum kaydı
  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi);

  -- 2. Buzağı ID
  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  -- 3. Buzağıyı sürüye ekle
  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  -- 4. Anne grup + padok güncelle
  UPDATE public.hayvanlar
  SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok'
  WHERE id = p_anne_id;

  -- 5. Anne protokol görevleri (7 görev)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Oksitosin + Ademin + Kalsiyum', p_tarih,        false, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '2. Gün PG',                                  p_tarih + 2,   false, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '11. Gün PG',                                 p_tarih + 11,  false, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '25. Gün PG',                                 p_tarih + 25,  false, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '53. Gün: Ademin + Yeldif',                   p_tarih + 53,  false, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '54. Gün: Yeldif',                            p_tarih + 54,  false, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), p_anne_id, 'DIGER', '⚡ 58-63. gün kızgınlık takibi',             p_tarih + 58,  false, 'DOGUM-' || p_anne_id);

  -- 6. Buzağı ana görev
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'DOGUM-' || p_anne_id);

  -- 7. Buzağı alt görevler (6 görev)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id);

  -- 8. Açık gebe tohumlama kaydını kapat
  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  -- 9. Doğumda aktif BESLEME görevlerini iptal et
  UPDATE gorev_log
  SET iptal = true
  WHERE hayvan_id = p_anne_id
    AND gorev_tipi = 'BESLEME'
    AND tamamlandi = false
    AND iptal = false;

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 14,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
