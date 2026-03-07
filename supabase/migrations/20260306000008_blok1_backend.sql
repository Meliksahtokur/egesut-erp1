-- ═══════════════════════════════════════════════════════════════
-- MIGRATION 008 — BLOK 1: BACKEND TEMELİ
-- EgeSüt ERP v9 — 2026-03-06
-- Tüm iş mantığı frontend'den backend'e taşındı.
-- Frontend artık sadece bu prosedürleri çağırır.
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. YENİ KOLONLAR
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS notlar text;
ALTER TABLE public.irk_esik  ADD COLUMN IF NOT EXISTS kullanim_sayisi integer NOT NULL DEFAULT 0;

-- ──────────────────────────────────────────────────────────────
-- 2. HAYVAN_EKLE — Yeni hayvan kaydı
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no        text    DEFAULT NULL,
  p_devlet_kupe    text    DEFAULT NULL,
  p_irk            text    DEFAULT NULL,
  p_cinsiyet       text    DEFAULT NULL,
  p_dogum_tarihi   date    DEFAULT NULL,
  p_grup           text    DEFAULT 'Genel',
  p_padok          text    DEFAULT 'P1',
  p_dogum_kg       numeric DEFAULT NULL,
  p_anne_id        text    DEFAULT NULL,
  p_baba_bilgi     text    DEFAULT NULL,
  p_canli_agirlik  numeric DEFAULT NULL,
  p_boy            numeric DEFAULT NULL,
  p_renk           text    DEFAULT NULL,
  p_ayirici_ozellik text   DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_chk  jsonb;
  v_id   text;
  v_sayac integer;
BEGIN
  -- Küpe müsait mi?
  SELECT public.kupe_musait_mi(p_kupe_no, p_devlet_kupe) INTO v_chk;
  IF NOT (v_chk->>'musait')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      CASE WHEN v_chk->>'kupe_cakisma_id' IS NOT NULL
        THEN 'İşletme küpesi zaten kayıtlı: ' || COALESCE(p_kupe_no,'')
        ELSE 'Devlet küpesi zaten kayıtlı: ' || COALESCE(p_devlet_kupe,'')
      END);
  END IF;

  -- ID üret (H + 6 hane sıralı)
  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (
    id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
    grup, padok, durum, dogum_kg, anne_id, baba_bilgi,
    canli_agirlik, boy, renk, ayirici_ozellik
  ) VALUES (
    v_id, NULLIF(p_kupe_no,''), NULLIF(p_devlet_kupe,''),
    NULLIF(p_irk,''), p_cinsiyet, p_dogum_tarihi,
    p_grup, p_padok, 'Aktif', p_dogum_kg, p_anne_id, p_baba_bilgi,
    p_canli_agirlik, p_boy, p_renk, p_ayirici_ozellik
  );

  -- Irk kullanım sayacı
  IF p_irk IS NOT NULL AND p_irk <> '' THEN
    UPDATE public.irk_esik SET kullanim_sayisi = kullanim_sayisi + 1
    WHERE irk = p_irk;
    -- Bilinmeyen ırk → otomatik ekle
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    IF v_sayac = 0 THEN
      INSERT INTO public.irk_esik (irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi)
      VALUES (p_irk, 365, 60, 1)
      ON CONFLICT (irk) DO UPDATE SET kullanim_sayisi = irk_esik.kullanim_sayisi + 1;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hayvan_id', v_id);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 3. DOGUM_KAYDET — Doğum + buzağı + görevler tek transaction
-- ──────────────────────────────────────────────────────────────
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

  -- 1. Doğum kaydı
  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, p_baba);

  -- 2. Buzağı ID
  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  -- 3. Buzağıyı sürüye ekle
  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, p_baba, p_cins, 'Süt İçen Buzağılar', 'Buzağı Ahırı', 'Aktif', p_kg);

  -- 4. Anne padok güncelle
  UPDATE public.hayvanlar SET padok = 'Sağmal Padok' WHERE id = p_anne_id;

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

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 14,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 4. TOHUMLAMA_KAYDET
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id  text,
  p_tarih      date,
  p_sperma     text,
  p_hekim_id   text    DEFAULT NULL,
  p_irk_bilgisi text   DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  -- Erkek kontrolü
  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvana tohumlama yapılamaz');
  END IF;

  -- Yaş kontrolü (12 ay = 365 gün)
  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan 12 aydan küçük — tohumlama yapılamaz');
    END IF;
  END IF;

  -- Zaten gebe mi?
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan zaten gebe — önce gebeliği kapatın');
  END IF;

  -- Deneme no
  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  -- Tohumlama kaydı
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  -- Kontrol görevleri
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş (varsa)
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
    'Tohumlama — ' || v_hayvan.kupe_no, false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.tur = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh_id, 'deneme_no', v_deneme);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 5. KIZGINLIK_KAYDET
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kizginlik_kaydet(
  p_hayvan_id  text,
  p_tarih      date,
  p_belirti    text    DEFAULT NULL,
  p_notlar     text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan  record;
  v_yas_gun integer;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  -- Erkek kontrolü
  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvanlarda kızgınlık kaydı yapılamaz');
  END IF;

  -- Yaş kontrolü
  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'mesaj', 'Hayvan 12 aydan küçük — kızgınlık kaydı yapılamaz',
        'oneri', 'Hayvan kartındaki Notlar bölümüne ekleyin'
      );
    END IF;
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar)
  VALUES (gen_random_uuid()::text, p_hayvan_id, p_tarih, p_belirti, p_notlar);

  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 6. HASTALIK_KAYDET
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_kaydet(
  p_hayvan_id   text,
  p_tani        text,
  p_kategori    text    DEFAULT NULL,
  p_siddet      text    DEFAULT NULL,
  p_semptomlar  text    DEFAULT NULL,
  p_lokasyon    text    DEFAULT NULL,
  p_hekim_id    text    DEFAULT NULL,
  p_ilaclar     jsonb   DEFAULT '[]',
  p_tedavi_gun  integer DEFAULT 1
) RETURNS jsonb AS $$
DECLARE
  v_hayvan    record;
  v_hst_id    uuid := gen_random_uuid();
  v_bugun     date := CURRENT_DATE;
  v_ilac      jsonb;
  v_stok_id   text;
  v_miktar    numeric;
  v_g         integer;
  v_ilac_ac   text := '';
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  -- İlk ilaç bilgisi (ana kayıt için)
  IF jsonb_array_length(p_ilaclar) > 0 THEN
    v_ilac    := p_ilaclar->0;
    v_stok_id := v_ilac->>'stokId';
    v_miktar  := (v_ilac->>'mik')::numeric;
  END IF;

  -- Hastalık kaydı
  INSERT INTO public.hastalik_log (
    id, hayvan_id, tarih, kategori, tani, siddet, semptomlar,
    lokasyon, hekim_id, ilac_stok_id, ilac_miktar, durum
  ) VALUES (
    v_hst_id, p_hayvan_id, v_bugun, p_kategori, p_tani, p_siddet, p_semptomlar,
    p_lokasyon, p_hekim_id, NULLIF(v_stok_id,''), v_miktar, 'Aktif'
  );

  -- Stok hareketleri (tüm ilaçlar)
  FOR v_ilac IN SELECT * FROM jsonb_array_elements(p_ilaclar)
  LOOP
    v_stok_id := v_ilac->>'stokId';
    v_miktar  := (v_ilac->>'mik')::numeric;
    IF v_stok_id IS NOT NULL AND v_stok_id <> '' AND v_miktar > 0 THEN
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
      VALUES (v_stok_id, 'Tedavi', v_miktar, p_tani || ' - ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id), false);
      v_ilac_ac := v_ilac_ac || COALESCE(v_ilac->>'stokAd', '') || ' ' || v_miktar::text || ' ';
    END IF;
  END LOOP;

  -- Takip görevleri
  IF p_tedavi_gun > 1 AND jsonb_array_length(p_ilaclar) > 0 THEN
    FOR v_g IN 1..(p_tedavi_gun - 1) LOOP
      INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
      VALUES (
        gen_random_uuid(), p_hayvan_id, 'ILAC',
        'Tedavi ' || (v_g+1) || '. gün: ' || TRIM(v_ilac_ac),
        v_bugun + v_g, false, 'TEDAVI-' || v_hst_id::text
      );
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hastalik_id', v_hst_id);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 7. ABORT_KAYDET
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.abort_kaydet(
  p_tohumlama_id  text,
  p_notlar        text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_toh record;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id = p_tohumlama_id::uuid AND sonuc = 'Gebe';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Gebe tohumlama kaydı bulunamadı');
  END IF;

  UPDATE public.tohumlama
  SET sonuc = 'Abort', abort_notlar = p_notlar
  WHERE id = p_tohumlama_id::uuid;

  UPDATE public.hayvanlar
  SET tohumlama_durumu = NULL, tohumlama_onay_tarihi = NULL
  WHERE id = v_toh.hayvan_id;

  RETURN jsonb_build_object('ok', true, 'hayvan_id', v_toh.hayvan_id);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 8. HAYVAN NOTU EKLE
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hayvan_not_ekle(
  p_hayvan_id  text,
  p_not        text
) RETURNS jsonb AS $$
DECLARE
  v_mevcut text;
  v_yeni   text;
  v_tarih  text := TO_CHAR(CURRENT_DATE, 'DD.MM.YYYY');
BEGIN
  SELECT notlar INTO v_mevcut FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  v_yeni := CASE
    WHEN v_mevcut IS NULL OR v_mevcut = '' THEN '[' || v_tarih || '] ' || p_not
    ELSE v_mevcut || E'\n' || '[' || v_tarih || '] ' || p_not
  END;

  UPDATE public.hayvanlar SET notlar = v_yeni WHERE id = p_hayvan_id;

  RETURN jsonb_build_object('ok', true, 'notlar', v_yeni);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 9. İŞLEM LOG OTOMATİK TRIGGER'LAR
-- Her tablo INSERT/UPDATE'de islem_log'a otomatik yazar.
-- Frontend'in yazIslemLog() çağırmasına gerek kalmaz.
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS TRIGGER AS $$
DECLARE
  v_tip          text;
  v_ana_hayvan   text;
  v_snapshot     jsonb;
BEGIN
  -- Tablo + işlem tipine göre log tipi belirle
  IF TG_TABLE_NAME = 'hayvanlar' AND TG_OP = 'INSERT' THEN
    v_tip        := 'HAYVAN_EKLENDI';
    v_ana_hayvan := NEW.id;
    v_snapshot   := jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','hayvanlar','id',NEW.id,'veri',
        jsonb_build_object('kupe_no',NEW.kupe_no,'irk',NEW.irk,'cinsiyet',NEW.cinsiyet,'dogum_tarihi',NEW.dogum_tarihi)
      )),
      'guncellenen', '[]'::jsonb, 'silinen', '[]'::jsonb
    );

  ELSIF TG_TABLE_NAME = 'dogum' AND TG_OP = 'INSERT' THEN
    v_tip        := 'DOGUM_KAYDI';
    v_ana_hayvan := NEW.anne_id;
    v_snapshot   := jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','dogum','id',NEW.id,'veri',
        jsonb_build_object('anne_id',NEW.anne_id,'tarih',NEW.tarih,'yavru_kupe',NEW.yavru_kupe,'yavru_cins',NEW.yavru_cins)
      )),
      'guncellenen', '[]'::jsonb, 'silinen', '[]'::jsonb
    );

  ELSIF TG_TABLE_NAME = 'tohumlama' AND TG_OP = 'INSERT' THEN
    v_tip        := 'TOHUMLAMA';
    v_ana_hayvan := NEW.hayvan_id;
    v_snapshot   := jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','tohumlama','id',NEW.id,'veri',
        jsonb_build_object('hayvan_id',NEW.hayvan_id,'tarih',NEW.tarih,'sperma',NEW.sperma,'deneme_no',NEW.deneme_no)
      )),
      'guncellenen', '[]'::jsonb, 'silinen', '[]'::jsonb
    );

  ELSIF TG_TABLE_NAME = 'tohumlama' AND TG_OP = 'UPDATE' AND NEW.sonuc = 'Abort' AND OLD.sonuc != 'Abort' THEN
    v_tip        := 'ABORT_KAYDI';
    v_ana_hayvan := NEW.hayvan_id;
    v_snapshot   := jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo','tohumlama','id',NEW.id,
        'onceki',jsonb_build_object('sonuc',OLD.sonuc),
        'sonraki',jsonb_build_object('sonuc','Abort')
      )),
      'silinen', '[]'::jsonb
    );

  ELSIF TG_TABLE_NAME = 'hastalik_log' AND TG_OP = 'INSERT' THEN
    v_tip        := 'HASTALIK_KAYDI';
    v_ana_hayvan := NEW.hayvan_id;
    v_snapshot   := jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','hastalik_log','id',NEW.id,'veri',
        jsonb_build_object('hayvan_id',NEW.hayvan_id,'tani',NEW.tani,'tarih',NEW.tarih)
      )),
      'guncellenen', '[]'::jsonb, 'silinen', '[]'::jsonb
    );

  ELSIF TG_TABLE_NAME = 'kizginlik_log' AND TG_OP = 'INSERT' THEN
    v_tip        := 'KIZGINLIK_KAYDI';
    v_ana_hayvan := NEW.hayvan_id;
    v_snapshot   := jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','kizginlik_log','id',NEW.id,'veri',
        jsonb_build_object('hayvan_id',NEW.hayvan_id,'tarih',NEW.tarih,'belirti',NEW.belirti)
      )),
      'guncellenen', '[]'::jsonb, 'silinen', '[]'::jsonb
    );

  ELSE
    RETURN NEW; -- Diğer UPDATE'ler loglanmaz
  END IF;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot)
  VALUES (v_tip, v_ana_hayvan, v_snapshot);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger'ları bağla
DROP TRIGGER IF EXISTS trg_islem_hayvanlar  ON public.hayvanlar;
DROP TRIGGER IF EXISTS trg_islem_dogum      ON public.dogum;
DROP TRIGGER IF EXISTS trg_islem_tohumlama  ON public.tohumlama;
DROP TRIGGER IF EXISTS trg_islem_hastalik   ON public.hastalik_log;
DROP TRIGGER IF EXISTS trg_islem_kizginlik  ON public.kizginlik_log;

CREATE TRIGGER trg_islem_hayvanlar
  AFTER INSERT ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_dogum
  AFTER INSERT ON public.dogum
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_tohumlama_insert
  AFTER INSERT ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_tohumlama_abort
  AFTER UPDATE OF sonuc ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_kizginlik
  AFTER INSERT ON public.kizginlik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

-- ──────────────────────────────────────────────────────────────
-- 10. HAYVAN_DURUM_VIEW GÜNCELLEMESİ
-- notlar ve abort_sayisi eklendi
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;
CREATE OR REPLACE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id, h.kupe_no, h.devlet_kupe, h.irk, h.cinsiyet, h.dogum_tarihi,
    h.grup, h.padok, h.durum, h.anne_id, h.kategori, h.notlar,
    h.tohumlama_durumu, h.tohumlama_onay_tarihi, h.suttten_kesme_tarihi,
    h.cikis_tipi, h.cikis_tarihi,
    CASE WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi ELSE NULL END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id, id AS toh_id, tarih AS toh_tarih, sperma,
    sonuc AS toh_sonuc, (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
abort_sayac AS (
  SELECT hayvan_id, COUNT(*) AS abort_sayisi
  FROM public.tohumlama WHERE sonuc = 'Abort'
  GROUP BY hayvan_id
),
son_bos_ref AS (
  SELECT t.hayvan_id, MAX(t.tarih) AS bos_ref_tarih
  FROM (
    SELECT hayvan_id, tarih FROM public.tohumlama WHERE sonuc IN ('Boş','Abort')
    UNION ALL
    SELECT anne_id AS hayvan_id, tarih FROM public.dogum
  ) t
  GROUP BY t.hayvan_id
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log WHERE durum = 'Aktif'
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id, st.toh_tarih, st.sperma, st.toh_sonuc, st.toh_gun,
  COALESCE(ab.abort_sayisi, 0) AS abort_sayisi,
  CASE
    WHEN st.toh_sonuc IS DISTINCT FROM 'Gebe' AND sb.bos_ref_tarih IS NOT NULL
    THEN (CURRENT_DATE - sb.bos_ref_tarih)
    ELSE NULL
  END AS bos_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,
  CASE
    WHEN y.cikis_tipi IS NOT NULL                                         THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75               THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180          THEN 'suttten_kesilmis'
    WHEN y.yas_gun > 180 AND y.yas_gun <= 365                             THEN 'kucuk_dana_duve'
    WHEN y.yas_gun > 365 AND st.toh_sonuc IS DISTINCT FROM 'Gebe'
         AND y.cinsiyet = 'Dişi'                                          THEN 'buyuk_duve'
    WHEN st.toh_sonuc = 'Gebe'                                            THEN 'gebe_duve_inek'
    WHEN y.grup LIKE '%Sağmal%'                                           THEN 'sagmal_inek'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180                        THEN 'besi_danasi'
    ELSE 'diger'
  END AS hesap_kategori,
  CASE
    WHEN y.cinsiyet = 'Dişi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (y.tohumlama_durumu IS NULL OR y.tohumlama_durumu = 'ertelendi')
      AND st.toh_sonuc IS DISTINCT FROM 'Gebe'
      AND y.cikis_tipi IS NULL
    THEN true ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL
      AND y.yas_gun >= COALESCE((
        SELECT suttten_kesme_gun FROM public.irk_esik WHERE irk = y.irk
      ), 60)
      AND y.cikis_tipi IS NULL
    THEN true ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 14
    THEN true ELSE false
  END AS dogum_yaklasti,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN (st.toh_gun - 280) ELSE 0
  END AS dogum_gecikme_gun
FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN abort_sayac   ab ON ab.hayvan_id = y.id
LEFT JOIN son_bos_ref   sb ON sb.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id
WHERE y.durum = 'Aktif';

-- ──────────────────────────────────────────────────────────────
-- 11. IRK LİSTESİ FONKSİYONU (frontend dropdown için)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.irk_listesi()
RETURNS TABLE(irk text, tohumlama_gun integer, suttten_kesme_gun integer, kullanim_sayisi integer)
AS $$
  SELECT irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi
  FROM public.irk_esik
  ORDER BY kullanim_sayisi DESC, irk ASC;
$$ LANGUAGE sql;

-- ──────────────────────────────────────────────────────────────
-- 12. NOTIFY — PostgREST schema cache yenile
-- ──────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
