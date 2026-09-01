-- ============================================================================
-- BUZAĞI KÜPE REVİZYONU — 2026-09-01 (spec: .claude/specs/2026-09-01-buzagi-kupe-revizyon-kararlar.md)
-- ============================================================================
-- K1  Recycle: çıkmış hayvanın İŞLETME küpesi hemen yeniden kullanılabilir
--     (kupe_musait_mi + dogum_kaydet işletme kontrolüne durum='Aktif' filtresi)
-- K2  Devlet (TR) küpesi kontrolü GLOBAL kalır (TURKVET: hayvana ömür boyu)
-- K3  Partial unique index: iki AKTİF hayvana aynı string küpe verilemez
--     (string-bazlı — "002"≠"02", sıfır-trick doğal korunur)
-- K5  Erkek buzağı: sayısal küpe 500-599 zorunlu (dogum_kaydet sunucu kuralı)
--     h11 hayvan_ekle/hayvan_guncelle overload'ları artık kupe_musait_mi çağırır
-- K7  asistan_hayvan_detay: aynı küpe string'inde AKTİF hayvan öncelikli
--
-- BAZLAR (en güncel tanımlar, GT değil):
--   dogum_kaydet         ← CANLI İKİZ gövdesi (pg_get_functiondef dump'u;
--                          ikiz-dogum-modeli branch'inden deploy edildi — 20260901000001_ikiz_dogum_olay_id.sql
--                          main'e henüz MERGE DEĞİL; bu dosya 20260901000002 olduğundan fresh install'da
--                          dosya adı sıralaması ikiz migration'ın ÖNCE koşmasını garanti eder)
--   hayvan_ekle/_guncelle← 20260706000006_h11_hayvan_yas_grup_validasyon.sql
--   asistan_hayvan_detay ← 99999999999999_ground_truth.sql (= 20260621000003)
--   kupe_musait_mi       ← imza aynen (p_kupe_no, p_devlet_kupe, p_hayvan_id)
-- ============================================================================
BEGIN;

-- ----------------------------------------------------------------------------
-- 1. kupe_musait_mi — imza AYNEN (PostgREST overload çözümü bozulmasın)
--    YENİ: işletme küpesi kontrolü yalnız Aktif'lerde; çıkmışta kullanılmışsa
--    bilgi amaçlı kupe_gecmis_id/kupe_gecmis_durum döner. Devlet küpesi GLOBAL.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.kupe_musait_mi(
  p_kupe_no text, p_devlet_kupe text, p_hayvan_id text DEFAULT NULL)
RETURNS jsonb AS $func$
DECLARE
  v_aktif_cakisma text; v_devlet_cakisma text;
  v_gecmis_id text; v_gecmis_durum text;
BEGIN
  IF p_kupe_no IS NOT NULL AND p_kupe_no <> '' THEN
    SELECT id INTO v_aktif_cakisma FROM public.hayvanlar
     WHERE kupe_no = p_kupe_no AND durum = 'Aktif'
       AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
    IF v_aktif_cakisma IS NULL THEN
      SELECT id, durum INTO v_gecmis_id, v_gecmis_durum FROM public.hayvanlar
       WHERE kupe_no = p_kupe_no AND durum IS DISTINCT FROM 'Aktif'
         AND (p_hayvan_id IS NULL OR id <> p_hayvan_id)
       ORDER BY cikis_tarihi DESC NULLS LAST, id DESC LIMIT 1;
    END IF;
  END IF;
  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '' THEN
    SELECT id INTO v_devlet_cakisma FROM public.hayvanlar
     WHERE devlet_kupe = p_devlet_kupe
       AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
  END IF;
  RETURN jsonb_build_object(
    'musait', (v_aktif_cakisma IS NULL AND v_devlet_cakisma IS NULL),
    'kupe_cakisma_id', v_aktif_cakisma,
    'kupe_gecmis_id', v_gecmis_id,
    'kupe_gecmis_durum', v_gecmis_durum,
    'devlet_cakisma_id', v_devlet_cakisma);
END; $func$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. dogum_kaydet — baz: CANLIDA DEPLOY EDİLMİŞ İKİZ VERSİYONU (pg_get_functiondef dump'u;
--    ikiz-dogum-modeli branch migration'ı 20260901000001_ikiz_dogum_olay_id.sql — main'e henüz merge değil;
--    sıralama dosya adıyla garanti: 20260901000001 (ikiz) < 20260901000002 (bu dosya)).
--    İkiz mantığına DOKUNULMADI: v_olay_id/v_ikinci/v_anne_yan_etki/v_yavru_sirasi, İKİZ GUARD,
--    OLAY PENCERESİ (10 gün), ANNE GÖREV GUARD'I (60 gün), olay_id INSERT kolonu,
--    coklu_dogum/olay_id/yavru_sirasi dönüş anahtarları aynen.
--    Yalnızca 2 değişiklik:
--    a) Dup check: işletme küpesi yalnız AKTİFlerde çakışır (K1); devlet GLOBAL (K2)
--    b) Erkek + sayısal küpe + 500-599 dışı → red (K5, ::numeric — int4 overflow koruması)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip text DEFAULT 'Normal'::text, p_kg numeric DEFAULT NULL::numeric, p_baba text DEFAULT NULL::text, p_hekim_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_anne           record;
  v_dogum_id       uuid := gen_random_uuid();
  v_buzagi_id      text;
  v_ana_gorev      uuid := gen_random_uuid();
  v_sayac          integer := 0;
  v_dup            text;
  v_baba_bilgi     text;
  v_anne_inst_id   uuid;
  v_buzagi_inst_id uuid;
  v_olay_id        uuid;
  v_ikinci         boolean := false;
  v_anne_yan_etki  boolean := true;
  v_yavru_sirasi   integer;
BEGIN
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı'); END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE (kupe_no = p_kupe AND durum = 'Aktif') OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe); END IF;

  -- K5: erkek buzağı sayısal küpesi 500-599 aralığında olmalı (::numeric — int4 overflow koruması)
  IF p_cins = 'Erkek' AND p_kupe ~ '^[0-9]+$'
     AND (p_kupe::numeric < 500 OR p_kupe::numeric > 599) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Erkek buzağı küpesi 500-599 aralığında olmalı (girilen: ' || p_kupe || ')');
  END IF;

  -- İKİZ GUARD: aynı anne + aynı yavru küpesi zaten kayıtlıysa reddet (typo → yanlış ikiz engeli)
  IF EXISTS (SELECT 1 FROM public.dogum WHERE anne_id = p_anne_id AND yavru_kupe = p_kupe) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe bu annenin yavrusu olarak zaten kayıtlı: ' || p_kupe);
  END IF;

  -- OLAY PENCERESİ (10 gün): yakın doğum varsa aynı olaya bağlanır (ikiz/üçüz)
  SELECT olay_id INTO v_olay_id FROM public.dogum
   WHERE anne_id = p_anne_id AND tarih BETWEEN p_tarih - 10 AND p_tarih
   ORDER BY tarih DESC LIMIT 1;
  v_ikinci := v_olay_id IS NOT NULL;

  -- ANNE GÖREV GUARD'I (60 gün): yakın doğum varsa anne yan etkileri ASLA tekrarlanmaz
  -- (9 görev + tohumlama kapatma + grup/padok + protokol + BESLEME iptali)
  IF EXISTS (SELECT 1 FROM public.dogum
             WHERE anne_id = p_anne_id AND tarih BETWEEN p_tarih - 60 AND p_tarih) THEN
    v_anne_yan_etki := false;
  END IF;

  IF NOT v_ikinci THEN v_olay_id := gen_random_uuid(); END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe' ORDER BY tarih DESC LIMIT 1;
    -- 2. yavru dalında Gebe tohumlama yoktur: babayı olayın ilk doğumundan al
    IF v_baba_bilgi IS NULL AND v_ikinci THEN
      SELECT baba_bilgi INTO v_baba_bilgi FROM public.dogum
      WHERE olay_id = v_olay_id AND baba_bilgi IS NOT NULL ORDER BY tarih DESC LIMIT 1;
    END IF;
  ELSE v_baba_bilgi := p_baba; END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi, olay_id)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi, v_olay_id);

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  SELECT COUNT(*) INTO v_yavru_sirasi FROM public.dogum WHERE olay_id = v_olay_id;

  IF v_anne_yan_etki THEN
    UPDATE public.hayvanlar SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok' WHERE id = p_anne_id;

    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (p_anne_id, 'UREME', 'DOGUM', 'DOGUM-' || p_anne_id, p_tarih, 'aktif')
    ON CONFLICT (kaynak_ref) DO UPDATE SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
    RETURNING id INTO v_anne_inst_id;
    IF v_anne_inst_id IS NULL THEN
      SELECT id INTO v_anne_inst_id FROM public.protokol_instance WHERE kaynak_ref = 'DOGUM-' || p_anne_id;
    END IF;

    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
    VALUES
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih,      false, 'DOGUM-' || p_anne_id, 'OKSITOSIN', v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih,      false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih,      false, 'DOGUM-' || p_anne_id, 'KALSIYUM',  v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '11. Gün PG',            p_tarih + 11, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Ademin',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Yeldif',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '54. Gün: Yeldif',       p_tarih + 54, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'DIGER','⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL, v_anne_inst_id);

    UPDATE public.tohumlama
    SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzazi_kupe = p_kupe
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';
    GET DIAGNOSTICS v_sayac = ROW_COUNT;

    UPDATE public.gorev_log SET iptal = true
    WHERE hayvan_id = p_anne_id AND gorev_tipi = 'BESLEME' AND tamamlandi = false AND iptal = false;

    UPDATE public.protokol_instance SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'DOGUM'
    WHERE hayvan_id = p_anne_id AND alttip = 'BESLEME' AND durum = 'aktif';
  END IF;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (v_buzagi_id, 'BAKIM', 'BUZAGI', 'BUZAGI-' || v_buzagi_id, p_tarih, 'aktif')
  RETURNING id INTO v_buzagi_inst_id;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id);

  RETURN jsonb_build_object(
    'ok', true, 'buzagi_id', v_buzagi_id, 'dogum_id', v_dogum_id,
    'gorev_sayisi', (CASE WHEN v_anne_yan_etki THEN 9 ELSE 0 END) + 7,
    'anne_inst_id', v_anne_inst_id,
    'buzagi_inst_id', v_buzagi_inst_id, 'tohumlama_kapatildi', v_sayac,
    'coklu_dogum', v_ikinci, 'olay_id', v_olay_id, 'yavru_sirasi', v_yavru_sirasi
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text, date, text, text, text, numeric, text, text) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. Partial unique index (K3) — string-bazlı; yalnız Aktif + dolu küpeler
--    Deploy öncesi dublikasyon taraması 0 dönmeli (orchestrator).
-- ----------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS hayvanlar_kupe_no_key
  ON public.hayvanlar (kupe_no)
 WHERE durum = 'Aktif' AND kupe_no IS NOT NULL AND kupe_no <> '';

-- ----------------------------------------------------------------------------
-- 4. hayvan_ekle — h11 overload (p_padok_id'li, frontend'in çağırdığı) + küpe kontrolü
--    Parametre listesi ve gövde h11'den BİREBİR; yalnız v_chk declare'ı ve
--    baştaki kupe_musait_mi kontrolü eklendi. Diğer overload'lara DOKUNULMADI.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no text DEFAULT NULL::text,
  p_devlet_kupe text DEFAULT NULL::text,
  p_irk text DEFAULT NULL::text,
  p_cinsiyet text DEFAULT NULL::text,
  p_dogum_tarihi date DEFAULT NULL::date,
  p_grup text DEFAULT 'Genel'::text,
  p_padok text DEFAULT NULL::text,
  p_dogum_kg numeric DEFAULT NULL::numeric,
  p_anne_id text DEFAULT NULL::text,
  p_baba_bilgi text DEFAULT NULL::text,
  p_canli_agirlik numeric DEFAULT NULL::numeric,
  p_boy numeric DEFAULT NULL::numeric,
  p_renk text DEFAULT NULL::text,
  p_ayirici_ozellik text DEFAULT NULL::text,
  p_padok_id uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id text;
  v_padok_id uuid;
  v_padok_ad text;
  v_yas_gun integer;
  v_chk jsonb;
BEGIN
  -- Küpe çakışma kontrolü (K1/K2): işletme=aktif-filtreli, devlet=global
  SELECT public.kupe_musait_mi(p_kupe_no, p_devlet_kupe) INTO v_chk;
  IF NOT (v_chk->>'musait')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      CASE WHEN v_chk->>'kupe_cakisma_id' IS NOT NULL
        THEN 'İşletme küpesi zaten kayıtlı (aktif): ' || COALESCE(p_kupe_no,'')
        ELSE 'Devlet küpesi zaten kayıtlı: ' || COALESCE(p_devlet_kupe,'') END);
  END IF;

  -- H-11: Yaş/grup validasyonu (js/forms.js:66-77 birebir)
  -- Sadece doğum tarihi verildiğinde kontrol et (nullable alan — mevcut satırlar NULL olabilir)
  IF p_dogum_tarihi IS NOT NULL THEN
    v_yas_gun := floor((current_date - p_dogum_tarihi));
    IF v_yas_gun < 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Doğum tarihi ileri tarih olamaz');
    END IF;
    IF p_grup = 'Süt İçen Buzağı' AND v_yas_gun > 180 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', '6 aylıktan büyük hayvan "Süt İçen Buzağı" grubuna eklenemez');
    END IF;
    IF (p_grup = 'Süt İçen Buzağı' OR p_grup = 'Sütten Kesilmiş Buzağı') AND v_yas_gun > 365 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', '12 aylıktan büyük hayvan buzağı grubuna eklenemez');
    END IF;
  END IF;

  v_id := gen_random_uuid()::text;

  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
    IF v_padok_id IS NULL THEN
      v_padok_ad := p_padok;
    END IF;
  END IF;

  INSERT INTO hayvanlar (
    id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
    grup, padok, padok_id, durum, dogum_kg, anne_id, baba_bilgi,
    canli_agirlik, boy, renk, ayirici_ozellik
  ) VALUES (
    v_id, NULLIF(p_kupe_no,''), NULLIF(p_devlet_kupe,''),
    NULLIF(p_irk,''), p_cinsiyet, p_dogum_tarihi,
    p_grup, v_padok_ad, v_padok_id, 'Aktif', p_dogum_kg, p_anne_id, p_baba_bilgi,
    p_canli_agirlik, p_boy, p_renk, p_ayirici_ozellik
  );

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. hayvan_guncelle — h11 overload (p_padok_id + p_kisir'li, en geniş) + küpe kontrolü
--    Parametre listesi ve gövde h11'den BİREBİR; yalnız v_chk declare'ı ve
--    küpe_musait_mi(p_hayvan_id = p_id) kontrolü eklendi (küpe/devlet NULL ise atla).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id text,
  p_kupe_no text DEFAULT NULL::text,
  p_devlet_kupe text DEFAULT NULL::text,
  p_irk text DEFAULT NULL::text,
  p_cinsiyet text DEFAULT NULL::text,
  p_dogum_tarihi date DEFAULT NULL::date,
  p_grup text DEFAULT NULL::text,
  p_padok text DEFAULT NULL::text,
  p_dogum_kg numeric DEFAULT NULL::numeric,
  p_canli_agirlik numeric DEFAULT NULL::numeric,
  p_boy numeric DEFAULT NULL::numeric,
  p_renk text DEFAULT NULL::text,
  p_ayirici_ozellik text DEFAULT NULL::text,
  p_baba_bilgi text DEFAULT NULL::text,
  p_notlar text DEFAULT NULL::text,
  p_anne_id text DEFAULT NULL::text,
  p_padok_id uuid DEFAULT NULL::uuid,
  p_kisir boolean DEFAULT NULL::boolean
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
  v_gebe     boolean;
  v_efektif_dt   date;
  v_efektif_grup text;
  v_yas_gun integer;
  v_chk jsonb;
BEGIN
  -- Küpe değişiyorsa çakışma kontrolü (K1/K2) — kendi kaydı hariç (p_hayvan_id = p_id)
  IF (p_kupe_no IS NOT NULL AND p_kupe_no <> '') OR (p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '') THEN
    SELECT public.kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_id) INTO v_chk;
    IF NOT (v_chk->>'musait')::boolean THEN
      RETURN jsonb_build_object('ok', false, 'error',
        CASE WHEN v_chk->>'kupe_cakisma_id' IS NOT NULL
          THEN 'İşletme küpesi zaten kayıtlı (aktif): ' || COALESCE(p_kupe_no,'')
          ELSE 'Devlet küpesi zaten kayıtlı: ' || COALESCE(p_devlet_kupe,'') END);
    END IF;
  END IF;

  -- Kısır işaretleme validation: gebe hayvan kısır olamaz
  IF p_kisir IS NOT NULL AND p_kisir = true THEN
    SELECT EXISTS (
      SELECT 1 FROM tohumlama t
      WHERE t.hayvan_id = p_id AND t.sonuc = 'Gebe'
    ) INTO v_gebe;
    IF v_gebe THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Gebe hayvan kısır olarak işaretlenemez');
    END IF;
  END IF;

  -- H-11: Yaş/grup validasyonu (js/forms.js:66-77 birebir)
  -- p_dogum_tarihi VEYA p_grup güncelleniyorsa, EFEKTİF (yeni ya da mevcut
  -- satırdan gelen, COALESCE ile) değerler üzerinden kontrol et.
  -- Eğer ikisi de NULL geliyorsa (sadece diğer alanlar güncelleniyor), mevcut
  -- satırın değerleri kullanılır.
  IF p_dogum_tarihi IS NOT NULL OR p_grup IS NOT NULL THEN
    SELECT COALESCE(p_dogum_tarihi, h.dogum_tarihi),
           COALESCE(NULLIF(p_grup, ''), h.grup)
      INTO v_efektif_dt, v_efektif_grup
      FROM hayvanlar h
     WHERE h.id = p_id;

    IF v_efektif_dt IS NOT NULL THEN
      v_yas_gun := floor((current_date - v_efektif_dt));
      IF v_yas_gun < 0 THEN
        RETURN jsonb_build_object('ok', false, 'error', 'Doğum tarihi ileri tarih olamaz');
      END IF;
      IF v_efektif_grup = 'Süt İçen Buzağı' AND v_yas_gun > 180 THEN
        RETURN jsonb_build_object('ok', false, 'error', '6 aylıktan büyük hayvan "Süt İçen Buzağı" grubuna eklenemez');
      END IF;
      IF (v_efektif_grup = 'Süt İçen Buzağı' OR v_efektif_grup = 'Sütten Kesilmiş Buzağı') AND v_yas_gun > 365 THEN
        RETURN jsonb_build_object('ok', false, 'error', '12 aylıktan büyük hayvan buzağı grubuna eklenemez');
      END IF;
    END IF;
  END IF;

  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
  END IF;

  UPDATE hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),        kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),    devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),            irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),       cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,              dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),           grup),
    padok            = COALESCE(v_padok_ad,                  padok),
    padok_id         = COALESCE(v_padok_id,                  padok_id),
    dogum_kg         = COALESCE(p_dogum_kg,                  dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,             canli_agirlik),
    boy              = COALESCE(p_boy,                       boy),
    renk             = COALESCE(NULLIF(p_renk,''),           renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''),ayirici_ozellik),
    baba_bilgi       = COALESCE(NULLIF(p_baba_bilgi,''),     baba_bilgi),
    notlar           = COALESCE(NULLIF(p_notlar,''),         notlar),
    anne_id          = COALESCE(NULLIF(p_anne_id,''),        anne_id),
    kisir            = COALESCE(p_kisir,                     kisir)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6. asistan_hayvan_detay — aktif-öncelik (K7): aynı küpe string'i geçmişte
--    çıkmışta + bugün aktifte varsa AKTİF hayvan döner.
--    Gövde: ground truth (= 20260621000003) birebir; yalnız ORDER BY eklendi.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.asistan_hayvan_detay(p_kupe text DEFAULT NULL::text, p_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_h record;
  v_out jsonb;
BEGIN
  SELECT * INTO v_h FROM hayvanlar
   WHERE (p_id IS NOT NULL AND id = p_id)
      OR (p_kupe IS NOT NULL AND kupe_no = p_kupe)
   ORDER BY (durum = 'Aktif') DESC, id
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('bulundu', false);
  END IF;

  v_out := jsonb_build_object(
    'bulundu', true,
    'hayvan', to_jsonb(v_h),
    'tohumlama', (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.tarih DESC), '[]'::jsonb)
                  FROM tohumlama t WHERE t.hayvan_id = v_h.id),
    'gorevler', (SELECT coalesce(jsonb_agg(to_jsonb(g) ORDER BY g.created_at DESC), '[]'::jsonb)
                 FROM gorev_log g WHERE g.hayvan_id = v_h.id),
    'uygulamalar', (SELECT coalesce(jsonb_agg(to_jsonb(u) ORDER BY u.created_at DESC), '[]'::jsonb)
                    FROM uygulama_log u WHERE u.hayvan_id = v_h.id),
    'islem_log', (SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.tarih DESC), '[]'::jsonb)
                  FROM islem_log i WHERE i.ana_hayvan_id = v_h.id)
  );
  RETURN v_out;
END $function$
;

REVOKE ALL ON FUNCTION public.asistan_hayvan_detay(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asistan_hayvan_detay(text, text) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
COMMIT;
