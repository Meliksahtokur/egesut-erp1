CREATE TABLE IF NOT EXISTS public.hayvanlar (
  id text PRIMARY KEY,
  kupe_no text,
  devlet_kupe text,
  irk text,
  cinsiyet text,
  dogum_tarihi date,
  dogum_kg numeric,
  canli_agirlik numeric,
  boy numeric,
  renk text,
  ayirici_ozellik text,
  anne_id text,
  baba_bilgi text,
  grup text,
  padok text,
  durum text DEFAULT 'Aktif'
);

CREATE TABLE IF NOT EXISTS public.stok (
  id text PRIMARY KEY,
  urun_adi text NOT NULL,
  kategori text,
  birim text,
  baslangic_miktar numeric DEFAULT 0,
  esik numeric DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.stok_hareket (
  id text PRIMARY KEY,
  stok_id text,
  tur text,
  miktar numeric,
  notlar text,
  iptal boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.gorev_log (
  id text PRIMARY KEY,
  hayvan_id text,
  gorev_tipi text,
  aciklama text,
  hedef_tarih date,
  tamamlandi boolean DEFAULT false,
  tamamlanma_tarihi timestamptz,
  parent_id text,
  stok_id text,
  miktar numeric,
  hekim_id text,
  kaynak text,
  padok_hedef text,
  iptal boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.hastalik_log (
  id text PRIMARY KEY,
  hayvan_id text,
  tarih date,
  kategori text,
  tani text,
  siddet text,
  semptomlar text,
  hekim_id text,
  ilac_stok_id text,
  ilac_miktar numeric,
  durum text DEFAULT 'Aktif',
  kapanma_tarihi date
);

CREATE TABLE IF NOT EXISTS public.tohumlama (
  id text PRIMARY KEY,
  hayvan_id text,
  tarih date,
  sperma text,
  hekim_id text,
  sonuc text DEFAULT 'Bekliyor',
  deneme_no integer DEFAULT 1
);

CREATE TABLE IF NOT EXISTS public.dogum (
  id text PRIMARY KEY,
  anne_id text,
  tarih date,
  yavru_cins text,
  yavru_kupe text,
  dogum_tipi text,
  dogum_kg numeric,
  baba_bilgi text,
  hekim_id text
);

CREATE TABLE IF NOT EXISTS public.buzagi_takip (
  id text PRIMARY KEY,
  kupe_no text,
  cinsiyet text,
  dogum_tarihi date,
  anne_id text
);

NOTIFY pgrst, 'reload schema';
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS devlet_kupe text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cinsiyet text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS anne_id text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS baba_bilgi text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS canli_agirlik numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS dogum_kg numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS boy numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS renk text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS ayirici_ozellik text;

ALTER TABLE public.stok ADD COLUMN IF NOT EXISTS kategori text;
ALTER TABLE public.stok ADD COLUMN IF NOT EXISTS esik numeric DEFAULT 0;

ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS dogum_kg numeric;
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS baba_bilgi text;

ALTER TABLE public.hastalik_log DROP CONSTRAINT IF EXISTS hastalik_log_hayvan_id_fkey;

ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS iptal boolean DEFAULT false;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS padok_hedef text;

NOTIFY pgrst, 'reload schema';ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS padok text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kupe_no text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS durum text DEFAULT 'Aktif';
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS grup text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS iptal boolean DEFAULT false;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS padok_hedef text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS hekim_id text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS miktar numeric;
NOTIFY pgrst, 'reload schema';DO $$ BEGIN
  ALTER TABLE public.stok_hareket 
    ADD CONSTRAINT stok_hareket_stok_id_fkey 
    FOREIGN KEY (stok_id) REFERENCES public.stok(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.tohumlama
    ADD CONSTRAINT tohumlama_hayvan_id_fkey
    FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.dogum
    ADD CONSTRAINT dogum_anne_id_fkey
    FOREIGN KEY (anne_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.gorev_log
    ADD CONSTRAINT gorev_log_hayvan_id_fkey
    FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';CREATE OR REPLACE FUNCTION public.set_deneme_no()
RETURNS TRIGGER AS $$
BEGIN
  SELECT COALESCE(MAX(deneme_no), 0) + 1 
  INTO NEW.deneme_no
  FROM public.tohumlama
  WHERE hayvan_id = NEW.hayvan_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_deneme_no ON public.tohumlama;
CREATE TRIGGER trg_deneme_no
  BEFORE INSERT ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.set_deneme_no();

NOTIFY pgrst, 'reload schema';-- ══════════════════════════════════════════════════════════════
-- FAZ 1 — CORE MIGRATION
-- EgeSüt ERP v9 — 2026-03-06
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- 1. EKSİK KOLON DÜZELTMELERİ (mevcut 400 hatalarının kaynağı)
-- ──────────────────────────────────────────

-- kizginlik_log tablosu yoktu
CREATE TABLE IF NOT EXISTS public.kizginlik_log (
  id          text PRIMARY KEY,
  hayvan_id   text,
  tarih       date,
  belirti     text,
  notlar      text,
  olusturma   timestamptz DEFAULT now()
);

-- hastalik_log eksik kolonlar
ALTER TABLE public.hastalik_log ADD COLUMN IF NOT EXISTS lokasyon text;
ALTER TABLE public.hastalik_log ADD COLUMN IF NOT EXISTS siddet   text;

-- tohumlama eksik kolonlar
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS dogum_tarihi  date;
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS buzagi_kupe   text;
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS abort_notlar  text;

-- gorev_log eksik kolon
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS kaynak text;

-- dogum eksik kolon
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS hekim_id text;

-- ──────────────────────────────────────────
-- 2. HAYVAN YAŞAM DÖNGÜSÜ KOLONLARI
-- ──────────────────────────────────────────

-- Biyolojik kategori (frontend hesaplamaz, backend view'dan gelir)
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kategori text;
  -- Değerler: sut_icen | suttten_kesilmis | kucuk_dana_duve |
  --           buyuk_dana_duve | buyuk_duve | sagmal_inek |
  --           kuru_donem | besi_danasi | tosun

-- Yaşam olayları tarihleri
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS suttten_kesme_tarihi   date;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS tohumlama_onay_tarihi  date;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS tohumlama_durumu       text;
  -- Değerler: NULL | tohumlanabilir | tohumlandi | gebe | ertelendi

-- Sürüden çıkış
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cikis_tipi    text;   -- olum | satis
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cikis_tarihi  date;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cikis_sebebi  text;   -- ölüm sebebi veya satış notu
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS satis_fiyati  numeric;

-- ──────────────────────────────────────────
-- 3. IRK EŞİK TABLOSU
-- Tohumlama minimum yaşı ırka göre (gün cinsinden)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.irk_esik (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  irk             text NOT NULL UNIQUE,
  tohumlama_gun   integer NOT NULL DEFAULT 365,
  suttten_kesme_gun integer NOT NULL DEFAULT 60,
  guncelleme      timestamptz DEFAULT now()
);

-- Varsayılan ırk eşikleri
INSERT INTO public.irk_esik (irk, tohumlama_gun, suttten_kesme_gun) VALUES
  ('Holstein',   365, 60),
  ('Montofon',   420, 60),
  ('Simmental',  400, 60),
  ('Jersey',     365, 56),
  ('Simental',   400, 60),
  ('Melez',      365, 60)
ON CONFLICT (irk) DO NOTHING;

-- ──────────────────────────────────────────
-- 4. BİLDİRİM LOG TABLOSU
-- Backend yazar, frontend sadece okur
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bildirim_log (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  hayvan_id       text,
  tip             text NOT NULL,
    -- tohumlama_yasi | suttten_kesme | dogum_yaklasti |
    -- dogum_gecikti  | tedavi_takip  | stok_kritik
  mesaj           text,
  durum           text NOT NULL DEFAULT 'bekliyor',
    -- bekliyor | goruldu | ertelendi | tamamlandi | iptal
  erteleme_tarihi date,
  olusturma       timestamptz DEFAULT now(),
  guncelleme      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bildirim_hayvan   ON public.bildirim_log(hayvan_id);
CREATE INDEX IF NOT EXISTS idx_bildirim_durum    ON public.bildirim_log(durum);
CREATE INDEX IF NOT EXISTS idx_bildirim_tip      ON public.bildirim_log(tip);

-- ──────────────────────────────────────────
-- 5. İŞLEM LOG TABLOSU
-- Her işlem buraya yazılır → geri alma buradan yapılır
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.islem_log (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tip             text NOT NULL,
    -- DOGUM_KAYDI | TOHUMLAMA | HASTALIK | OLUM | SATIS |
    -- SUTEN_KESME | ABORT | GOREV_TAMAMLA | STOK_HAREKET
  ana_hayvan_id   text,
  tarih           timestamptz DEFAULT now(),
  kullanici_notu  text,
  durum           text NOT NULL DEFAULT 'aktif',  -- aktif | geri_alindi
  geri_alma_tarihi timestamptz,
  -- Etkilenen tüm kayıtlar JSON olarak saklanır
  -- Geri almada bu snapshot kullanılır
  snapshot        jsonb NOT NULL
    -- {
    --   "olusturulan": [{"tablo":"hayvanlar","id":"...","veri":{...}}],
    --   "guncellenen": [{"tablo":"tohumlama","id":"...","onceki":{...},"sonraki":{...}}],
    --   "silinen":     [{"tablo":"gorev_log","id":"...","veri":{...}}]
    -- }
);

CREATE INDEX IF NOT EXISTS idx_islem_hayvan  ON public.islem_log(ana_hayvan_id);
CREATE INDEX IF NOT EXISTS idx_islem_tarih   ON public.islem_log(tarih DESC);
CREATE INDEX IF NOT EXISTS idx_islem_durum   ON public.islem_log(durum);

-- ──────────────────────────────────────────
-- 6. ÇÖP KUTUSU TABLOSU
-- Silinen kayıtlar 30 gün burada bekler
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cop_kutusu (
  id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  kaynak_tablo          text NOT NULL,
  kaynak_id             text NOT NULL,
  veri                  jsonb NOT NULL,
  silme_tarihi          timestamptz DEFAULT now(),
  otomatik_silme_tarihi timestamptz DEFAULT (now() + interval '30 days'),
  geri_yuklendi         boolean DEFAULT false,
  silme_sebebi          text   -- islem_log.id referansı veya 'manuel'
);

CREATE INDEX IF NOT EXISTS idx_cop_tablo      ON public.cop_kutusu(kaynak_tablo);
CREATE INDEX IF NOT EXISTS idx_cop_silme      ON public.cop_kutusu(otomatik_silme_tarihi);
CREATE INDEX IF NOT EXISTS idx_cop_geri       ON public.cop_kutusu(geri_yuklendi);

-- ──────────────────────────────────────────
-- 7. HAYVAN DURUM VIEW
-- Frontend bu view'ı okur — badge ve kategori hesabı burada
-- ──────────────────────────────────────────
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;
CREATE OR REPLACE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id,
    h.kupe_no,
    h.devlet_kupe,
    h.irk,
    h.cinsiyet,
    h.dogum_tarihi,
    h.grup,
    h.padok,
    h.durum,
    h.anne_id,
    h.kategori,
    h.tohumlama_durumu,
    h.tohumlama_onay_tarihi,
    h.suttten_kesme_tarihi,
    h.cikis_tipi,
    h.cikis_tarihi,
    -- Yaş (gün)
    CASE
      WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END AS yas_gun,
    -- Irk eşiği
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id,
    id    AS toh_id,
    tarih AS toh_tarih,
    sperma,
    sonuc AS toh_sonuc,
    (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log
  WHERE durum = 'Aktif'
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id,
  st.toh_tarih,
  st.sperma,
  st.toh_sonuc,
  st.toh_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,

  -- Hesaplanan kategori (hayvanlar.kategori boşsa buradan hesapla)
  CASE
    WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.yas_gun > 180 AND y.yas_gun <= 365 THEN 'kucuk_dana_duve'
    WHEN y.yas_gun > 365 AND st.toh_sonuc IS DISTINCT FROM 'Gebe'
         AND y.cinsiyet = 'Dişi' THEN 'buyuk_duve'
    WHEN st.toh_sonuc = 'Gebe' THEN 'gebe_duve_inek'
    WHEN y.grup = 'Sağmal' OR y.grup LIKE '%Sağmal%' THEN 'sagmal_inek'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi_danasi'
    ELSE 'diger'
  END AS hesap_kategori,

  -- Tohumlama bildirisi gerekiyor mu?
  CASE
    WHEN y.cinsiyet = 'Dişi'
     AND y.yas_gun >= y.tohumlama_esik_gun
     AND (y.tohumlama_durumu IS NULL OR y.tohumlama_durumu = 'ertelendi')
     AND st.toh_sonuc IS DISTINCT FROM 'Gebe'
     AND y.cikis_tipi IS NULL
    THEN true
    ELSE false
  END AS tohumlama_bildirisi_gerekli,

  -- Sütten kesme bildirisi gerekiyor mu?
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL
     AND y.yas_gun >= COALESCE(
       (SELECT suttten_kesme_gun FROM public.irk_esik WHERE irk = y.irk),
       60
     )
     AND y.cikis_tipi IS NULL
    THEN true
    ELSE false
  END AS suttten_kesme_bildirisi_gerekli,

  -- Doğum yaklaşıyor mu? (14 gün içinde)
  CASE
    WHEN st.toh_sonuc = 'Gebe'
     AND (280 - st.toh_gun) BETWEEN 0 AND 14
    THEN true
    ELSE false
  END AS dogum_yaklasti,

  -- Doğum gecikiyor mu?
  CASE
    WHEN st.toh_sonuc = 'Gebe'
     AND st.toh_gun > 280
    THEN (st.toh_gun - 280)
    ELSE 0
  END AS dogum_gecikme_gun

FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id
WHERE y.durum = 'Aktif';

-- ──────────────────────────────────────────
-- 8. RAPORLAMA VIEWleri
-- ──────────────────────────────────────────

-- Gebelik özet
CREATE OR REPLACE VIEW public.gebelik_ozet_view AS
SELECT
  COUNT(*) FILTER (WHERE sonuc = 'Gebe')        AS gebe_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Bekliyor')    AS bekleyen_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Abort')       AS abort_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Doğum Yaptı') AS dogum_yapti_sayisi,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
    / NULLIF(COUNT(*), 0), 1
  ) AS gebelik_orani_pct
FROM public.tohumlama
WHERE tarih >= CURRENT_DATE - interval '12 months';

-- Hastalık istatistik
CREATE OR REPLACE VIEW public.hastalik_istatistik_view AS
SELECT
  tani,
  kategori,
  COUNT(*)                                           AS toplam,
  COUNT(*) FILTER (WHERE durum = 'Aktif')            AS aktif,
  COUNT(*) FILTER (WHERE durum = 'İyileşti')         AS iyilesti,
  MIN(tarih)                                         AS ilk_gorulme,
  MAX(tarih)                                         AS son_gorulme
FROM public.hastalik_log
GROUP BY tani, kategori
ORDER BY toplam DESC;

-- Stok tüketim
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
  END AS stok_durum
FROM public.stok s
LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
GROUP BY s.id, s.urun_adi, s.kategori, s.birim, s.baslangic_miktar, s.esik;

-- ──────────────────────────────────────────
-- 9. DUPLICATE KONTROL FONKSİYONU
-- Frontend kayıt öncesi bu fonksiyonu çağırır
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kupe_musait_mi(
  p_kupe_no     text,
  p_devlet_kupe text,
  p_hayvan_id   text DEFAULT NULL  -- güncelleme için mevcut ID hariç tut
)
RETURNS jsonb AS $func$
DECLARE
  v_kupe_cakisma    text;
  v_devlet_cakisma  text;
BEGIN
  -- İşletme küpesi çakışması
  IF p_kupe_no IS NOT NULL AND p_kupe_no != '' THEN
    SELECT id INTO v_kupe_cakisma
    FROM public.hayvanlar
    WHERE kupe_no = p_kupe_no
      AND (p_hayvan_id IS NULL OR id != p_hayvan_id)
    LIMIT 1;
  END IF;

  -- Devlet küpesi çakışması
  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe != '' THEN
    SELECT id INTO v_devlet_cakisma
    FROM public.hayvanlar
    WHERE devlet_kupe = p_devlet_kupe
      AND (p_hayvan_id IS NULL OR id != p_hayvan_id)
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'musait',           (v_kupe_cakisma IS NULL AND v_devlet_cakisma IS NULL),
    'kupe_cakisma_id',  v_kupe_cakisma,
    'devlet_cakisma_id',v_devlet_cakisma
  );
END;
$func$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────
-- 10. BAŞLAT
-- ──────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
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
DROP TRIGGER IF EXISTS trg_islem_hayvanlar          ON public.hayvanlar;
DROP TRIGGER IF EXISTS trg_islem_dogum              ON public.dogum;
DROP TRIGGER IF EXISTS trg_islem_tohumlama          ON public.tohumlama;
DROP TRIGGER IF EXISTS trg_islem_tohumlama_insert   ON public.tohumlama;
DROP TRIGGER IF EXISTS trg_islem_tohumlama_abort    ON public.tohumlama;
DROP TRIGGER IF EXISTS trg_islem_hastalik           ON public.hastalik_log;
DROP TRIGGER IF EXISTS trg_islem_kizginlik          ON public.kizginlik_log;

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

-- ──────────────────────────────────────────────────────────────
-- 13. RLS POLİCY'LERİ — tüm tablolar
-- ──────────────────────────────────────────────────────────────
DO $$ 
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'hayvanlar','tohumlama','hastalik_log','dogum','stok','stok_hareket',
    'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log',
    'cop_kutusu','irk_esik'
  ]) LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    -- Mevcut policy varsa drop et, yeniden oluştur
    BEGIN
      EXECUTE format('DROP POLICY IF EXISTS allow_all ON public.%I', t);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    EXECUTE format(
      'CREATE POLICY allow_all ON public.%I FOR ALL USING (true) WITH CHECK (true)', t
    );
  END LOOP;
END $$;

-- Stored function'lar SECURITY DEFINER — RLS bypass eder
ALTER FUNCTION public.hayvan_ekle       SECURITY DEFINER;
ALTER FUNCTION public.dogum_kaydet      SECURITY DEFINER;
ALTER FUNCTION public.tohumlama_kaydet  SECURITY DEFINER;
ALTER FUNCTION public.kizginlik_kaydet  SECURITY DEFINER;
ALTER FUNCTION public.hastalik_kaydet   SECURITY DEFINER;
ALTER FUNCTION public.abort_kaydet      SECURITY DEFINER;
ALTER FUNCTION public.hayvan_not_ekle   SECURITY DEFINER;
ALTER FUNCTION public.cikis_yap         SECURITY DEFINER;
ALTER FUNCTION public.geri_al           SECURITY DEFINER;
ALTER FUNCTION public._islem_log_yaz    SECURITY DEFINER;
-- ═══════════════════════════════════════════════════════════════
-- Migration 009 — DB Zemini
-- 1. hekimler tablosu (app.js sabit array → DB)
-- 2. islem_log payload kolonu (event standartlaştırma)
-- 3. hayvan_timeline_view (UI'a hazır event listesi)
-- 4. tohumlama_kaydet validasyon (erkek + yaş + aktif gebelik)
-- Tümü idempotent: tekrar çalıştırılabilir
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. HEKİMLER TABLOSU
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.hekimler (
  id      text PRIMARY KEY,
  ad      text NOT NULL,
  telefon text,
  aktif   boolean NOT NULL DEFAULT true
);

-- Seed: app.js'deki sabit array buraya taşınıyor
INSERT INTO public.hekimler (id, ad, aktif) VALUES
  ('H1', 'Melik Tokur',        true),
  ('H2', 'Hüseyin Aygün',      true),
  ('H3', 'Süleyman Kocabaş',   true)
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE public.hekimler ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "hekimler_all" ON public.hekimler;
CREATE POLICY "hekimler_all"
  ON public.hekimler FOR ALL
  USING (true) WITH CHECK (true);

-- ──────────────────────────────────────────────────────────────
-- 2. islem_log — payload jsonb kolonu ekle
--    tip (text) korunuyor — geriye uyumluluk için
--    payload = standart event envelope
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.islem_log
  ADD COLUMN IF NOT EXISTS payload jsonb;

-- payload standart formatı:
-- {
--   "event_type": "insemination_performed",   -- snake_case sabit
--   "entity_type": "animal",
--   "entity_id": "...",
--   "actor": "H1",                            -- hekim_id
--   "meta": { ...işleme özel alanlar... }
-- }

-- Mevcut kayıtlar için payload backfill (tip → event_type mapping)
UPDATE public.islem_log
SET payload = jsonb_build_object(
  'event_type', CASE tip
    WHEN 'DOGUM_KAYDI'     THEN 'birth_recorded'
    WHEN 'TOHUMLAMA'       THEN 'insemination_performed'
    WHEN 'HASTALIK_KAYDI'  THEN 'treatment_recorded'
    WHEN 'HAYVAN_EKLENDI'  THEN 'animal_registered'
    WHEN 'ABORT_KAYDI'     THEN 'abortion_recorded'
    WHEN 'KIZGINLIK'       THEN 'estrus_detected'
    WHEN 'OLUM_KAYDI'      THEN 'animal_died'
    WHEN 'SATIS_KAYDI'     THEN 'animal_sold'
    WHEN 'SUTTEN_KESME'    THEN 'weaning_performed'
    WHEN 'GOREV_TAMAMLA'   THEN 'task_completed'
    WHEN 'STOK_HAREKET'    THEN 'stock_movement'
    ELSE lower(tip)
  END,
  'entity_type', 'animal',
  'entity_id',   ana_hayvan_id,
  'meta',        snapshot
)
WHERE payload IS NULL;

-- ──────────────────────────────────────────────────────────────
-- 3. _islem_log_yaz trigger fonksiyonu — payload standartla
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip          text;
  v_hayvan_id    text;
  v_snapshot     jsonb;
  v_payload      jsonb;
BEGIN
  -- Tip + hayvan_id tablo adına göre belirle
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'dogum' THEN
      v_tip       := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'tohumlama' THEN
      v_tip       := 'TOHUMLAMA';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'hastalik_log' THEN
      v_tip       := 'HASTALIK_KAYDI';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'kizginlik_log' THEN
      v_tip       := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
    ELSE
      v_tip       := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot  := to_jsonb(NEW);
  END CASE;

  -- Standart payload envelope
  v_payload := jsonb_build_object(
    'event_type', CASE v_tip
      WHEN 'DOGUM_KAYDI'        THEN 'birth_recorded'
      WHEN 'TOHUMLAMA'          THEN 'insemination_performed'
      WHEN 'HASTALIK_KAYDI'     THEN 'treatment_recorded'
      WHEN 'HAYVAN_EKLENDI'     THEN 'animal_registered'
      WHEN 'HAYVAN_GUNCELLENDI' THEN 'animal_updated'
      WHEN 'ABORT_KAYDI'        THEN 'abortion_recorded'
      WHEN 'KIZGINLIK'          THEN 'estrus_detected'
      ELSE lower(v_tip)
    END,
    'entity_type', 'animal',
    'entity_id',   v_hayvan_id,
    'meta',        v_snapshot
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, payload)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_payload);

  RETURN NEW;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 4. HAYVAN_TIMELINE_VIEW
--    UI'a hazır: hayvan başına tüm eventler, tek sorguda
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.hayvan_timeline_view;

CREATE VIEW public.hayvan_timeline_view AS
-- Doğum
SELECT
  d.anne_id                        AS hayvan_id,
  'DOGUM_KAYDI'                    AS tip,
  'birth_recorded'                 AS event_type,
  d.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'yavru_kupe', d.yavru_kupe,
    'yavru_cins', d.yavru_cins,
    'dogum_tipi', d.dogum_tipi,
    'dogum_kg',   d.dogum_kg,
    'hekim_id',   d.hekim_id
  )                                AS detay,
  d.id                             AS kaynak_id
FROM public.dogum d

UNION ALL

-- Tohumlama
SELECT
  t.hayvan_id,
  'TOHUMLAMA'                      AS tip,
  'insemination_performed'         AS event_type,
  t.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'sperma',      t.sperma,
    'sonuc',       t.sonuc,
    'deneme_no',   t.deneme_no,
    'hekim_id',    t.hekim_id
  )                                AS detay,
  t.id::text                       AS kaynak_id
FROM public.tohumlama t

UNION ALL

-- Hastalık
SELECT
  hl.hayvan_id,
  'HASTALIK_KAYDI'                 AS tip,
  'treatment_recorded'             AS event_type,
  hl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'tani',      hl.tani,
    'kategori',  hl.kategori,
    'siddet',    hl.siddet,
    'durum',     hl.durum,
    'hekim_id',  hl.hekim_id
  )                                AS detay,
  hl.id                            AS kaynak_id
FROM public.hastalik_log hl

UNION ALL

-- Kızgınlık
SELECT
  kl.hayvan_id,
  'KIZGINLIK'                      AS tip,
  'estrus_detected'                AS event_type,
  kl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'belirti', kl.belirti,
    'notlar',  kl.notlar
  )                                AS detay,
  kl.id                            AS kaynak_id
FROM public.kizginlik_log kl

UNION ALL

-- Hayvan eklendi / güncellendi (islem_log'dan)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  COALESCE(il.payload->'meta', il.snapshot) AS detay,
  il.id                            AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('HAYVAN_EKLENDI', 'ABORT_KAYDI', 'SATIS_KAYDI', 'OLUM_KAYDI', 'SUTTEN_KESME')

ORDER BY zaman DESC;

-- ──────────────────────────────────────────────────────────────
-- 5. TOHUMLAMA_KAYDET — validasyon + sperma stok fix
--    (009a'yı içerir, ayrıca hekim_ad parametresi eklendi)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id   text,
  p_tarih       date,
  p_sperma      text,
  p_hekim_id    text  DEFAULT NULL,
  p_irk_bilgisi text  DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  -- Erkek kontrolü
  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';
  END IF;

  -- Yaş kontrolü (12 ay = 365 gün)
  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  -- Aktif gebelik kontrolü
  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  -- İleri tarih kontrolü
  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  -- Deneme no
  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id;

  -- Tohumlama kaydı
  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  -- Kontrol görevleri
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş (kategori = 'Sperma')
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh_id,
    'deneme_no',    v_deneme
  );
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 6. hekimler tablosuna RPC — frontend için
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hekim_listesi()
RETURNS TABLE(id text, ad text, telefon text, aktif boolean)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT id, ad, telefon, aktif
  FROM public.hekimler
  WHERE aktif = true
  ORDER BY ad;
$$;

CREATE OR REPLACE FUNCTION public.hekim_ekle(
  p_id      text,
  p_ad      text,
  p_telefon text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.hekimler (id, ad, telefon, aktif)
  VALUES (p_id, p_ad, p_telefon, true)
  ON CONFLICT (id) DO UPDATE SET ad = p_ad, telefon = p_telefon;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 7. pullTables için hekimler izni
-- ──────────────────────────────────────────────────────────────
GRANT SELECT ON public.hekimler TO anon, authenticated;
GRANT SELECT ON public.hayvan_timeline_view TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hekim_listesi() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hekim_ekle(text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text) TO anon, authenticated;
-- ═══════════════════════════════════════════════════════════════
-- Migration 010 — hayvan_guncelle RPC
-- Hayvan kartından bilgi/padok düzenleme
-- ═══════════════════════════════════════════════════════════════

-- updated_at kolonu yoksa ekle
ALTER TABLE public.hayvanlar
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id              text,
  p_kupe_no         text    DEFAULT NULL,
  p_devlet_kupe     text    DEFAULT NULL,
  p_irk             text    DEFAULT NULL,
  p_cinsiyet        text    DEFAULT NULL,
  p_dogum_tarihi    date    DEFAULT NULL,
  p_grup            text    DEFAULT NULL,
  p_padok           text    DEFAULT NULL,
  p_dogum_kg        numeric DEFAULT NULL,
  p_canli_agirlik   numeric DEFAULT NULL,
  p_boy             numeric DEFAULT NULL,
  p_renk            text    DEFAULT NULL,
  p_ayirici_ozellik text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_chk    jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_id;
  END IF;

  -- Küpe değişiyorsa çakışma kontrolü (kendi küpesini hariç tut)
  IF p_kupe_no IS NOT NULL AND p_kupe_no <> '' AND p_kupe_no <> COALESCE(v_hayvan.kupe_no,'') THEN
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE kupe_no = p_kupe_no AND id <> p_id) THEN
      RAISE EXCEPTION 'İşletme küpesi zaten kayıtlı: %', p_kupe_no;
    END IF;
  END IF;

  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '' AND p_devlet_kupe <> COALESCE(v_hayvan.devlet_kupe,'') THEN
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE devlet_kupe = p_devlet_kupe AND id <> p_id) THEN
      RAISE EXCEPTION 'Devlet küpesi zaten kayıtlı: %', p_devlet_kupe;
    END IF;
  END IF;

  UPDATE public.hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),         kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),     devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),             irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),        cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,               dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),            grup),
    padok            = COALESCE(NULLIF(p_padok,''),           padok),
    dogum_kg         = COALESCE(p_dogum_kg,                   dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,              canli_agirlik),
    boy              = COALESCE(p_boy,                        boy),
    renk             = COALESCE(NULLIF(p_renk,''),            renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''), ayirici_ozellik),
    updated_at       = now()
  WHERE id = p_id;

  -- islem_log trigger otomatik yazacak (HAYVAN_GUNCELLENDI)

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_guncelle(text,text,text,text,text,date,text,text,numeric,numeric,numeric,text,text) TO anon, authenticated;
-- ═══════════════════════════════════════════════════════════════
-- Migration 011 — hayvan_durum_view'a fiziksel alanlar ekle
-- canli_agirlik, boy, renk, ayirici_ozellik, dogum_kg, notlar
-- abort_sayisi, baba_bilgi
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id,
    h.kupe_no,
    h.devlet_kupe,
    h.irk,
    h.cinsiyet,
    h.dogum_tarihi,
    h.grup,
    h.padok,
    h.durum,
    h.anne_id,
    h.kategori,
    h.tohumlama_durumu,
    h.tohumlama_onay_tarihi,
    h.suttten_kesme_tarihi,
    h.cikis_tipi,
    h.cikis_tarihi,
    h.cikis_sebebi,
    h.satis_fiyati,
    h.notlar,
    -- Fiziksel özellikler
    h.dogum_kg,
    h.canli_agirlik,
    h.boy,
    h.renk,
    h.ayirici_ozellik,
    h.baba_bilgi,
    h.abort_sayisi,
    -- Yaş (gün)
    CASE
      WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END AS yas_gun,
    -- Irk eşiği
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id,
    id    AS toh_id,
    tarih AS toh_tarih,
    sperma,
    sonuc AS toh_sonuc,
    (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log
  WHERE durum = 'Aktif'
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id,
  st.toh_tarih,
  st.sperma,
  st.toh_sonuc,
  st.toh_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,

  -- Hesaplanan kategori
  CASE
    WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 181 AND 365 THEN 'duve_kucuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 366 AND 730 THEN 'duve_buyuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun > 730 THEN 'sagmal'
    ELSE 'genel'
  END AS hesap_kategori,

  -- Tohumlama bildirisi gerekli mi?
  CASE
    WHEN y.cinsiyet = 'Dişi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (st.toh_sonuc IS NULL OR st.toh_sonuc = 'Boş')
    THEN true
    ELSE false
  END AS tohumlama_bildirisi_gerekli,

  -- Sütten kesme bildirisi
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun BETWEEN 76 AND 180
    THEN true
    ELSE false
  END AS suttten_kesme_bildirisi_gerekli,

  -- Doğum yaklaştı mı? (≤7 gün)
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true
    ELSE false
  END AS dogum_yaklasti,

  -- Doğum gecikti mi?
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280
    ELSE 0
  END AS dogum_gecikme_gun,

  -- Tohumlama durumu (view hesabı)
  CASE
    WHEN st.toh_sonuc = 'Gebe' THEN 'gebe'
    WHEN st.toh_sonuc = 'Bekliyor' THEN 'bekliyor'
    WHEN y.yas_gun >= y.tohumlama_esik_gun AND y.cinsiyet = 'Dişi' THEN 'tohumlanabilir'
    ELSE 'erken'
  END AS tohumlama_durumu_hesap

FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id;

GRANT SELECT ON public.hayvan_durum_view TO anon, authenticated;
-- Migration 012 — _islem_log_yaz trigger fix
-- IF/ELSIF zinciri CASE yapısına geçirildi (NEW.sonuc hatası düzeltildi)

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip       text;
  v_hayvan_id text;
  v_snapshot  jsonb;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar'    THEN v_tip := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
                             v_hayvan_id := NEW.id;          v_snapshot := to_jsonb(NEW);
    WHEN 'dogum'        THEN v_tip := 'DOGUM_KAYDI';
                             v_hayvan_id := NEW.anne_id;     v_snapshot := to_jsonb(NEW);
    WHEN 'tohumlama'    THEN v_tip := CASE TG_OP WHEN 'UPDATE' THEN 'ABORT_KAYDI' ELSE 'TOHUMLAMA' END;
                             v_hayvan_id := NEW.hayvan_id;   v_snapshot := to_jsonb(NEW);
    WHEN 'hastalik_log' THEN v_tip := 'HASTALIK_KAYDI';
                             v_hayvan_id := NEW.hayvan_id;   v_snapshot := to_jsonb(NEW);
    WHEN 'kizginlik_log'THEN v_tip := 'KIZGINLIK';
                             v_hayvan_id := NEW.hayvan_id;   v_snapshot := to_jsonb(NEW);
    ELSE                     v_tip := upper(TG_TABLE_NAME) || '_' || TG_OP;
                             v_hayvan_id := NULL;            v_snapshot := to_jsonb(NEW);
  END CASE;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot)
  VALUES (v_tip, v_hayvan_id, v_snapshot);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_islem_hastalik ON public.hastalik_log;
CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();
-- Migration 016 — islem_log ref_id/ref_tablo + hastalık yönetim RPC'leri
-- Supabase SQL Editor'dan çalıştır

-- ── 1. islem_log'a köprü kolonları ─────────────────────────────
ALTER TABLE public.islem_log
  ADD COLUMN IF NOT EXISTS ref_id    text,
  ADD COLUMN IF NOT EXISTS ref_tablo text;

-- Eski kayıtları snapshot'tan geriye doldur
UPDATE public.islem_log
SET
  ref_id    = snapshot->>'id',
  ref_tablo = CASE tip
    WHEN 'HASTALIK_KAYDI'   THEN 'hastalik_log'
    WHEN 'TOHUMLAMA'        THEN 'tohumlama'
    WHEN 'ABORT_KAYDI'      THEN 'tohumlama'
    WHEN 'DOGUM_KAYDI'      THEN 'dogum'
    WHEN 'HAYVAN_EKLENDI'   THEN 'hayvanlar'
    WHEN 'HAYVAN_GUNCELLENDI' THEN 'hayvanlar'
    WHEN 'KIZGINLIK'        THEN 'kizginlik_log'
    ELSE NULL
  END
WHERE ref_id IS NULL AND snapshot->>'id' IS NOT NULL;

-- ── 2. Trigger güncelle — ref_id ve ref_tablo doldursun ────────
CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip       text;
  v_hayvan_id text;
  v_snapshot  jsonb;
  v_ref_id    text;
  v_ref_tablo text;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hayvanlar';

    WHEN 'dogum' THEN
      v_tip       := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'dogum';

    WHEN 'tohumlama' THEN
      v_tip       := CASE TG_OP WHEN 'UPDATE' THEN 'ABORT_KAYDI' ELSE 'TOHUMLAMA' END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'tohumlama';

    WHEN 'hastalik_log' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HASTALIK_KAYDI' ELSE 'HASTALIK_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hastalik_log';

    WHEN 'kizginlik_log' THEN
      v_tip       := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'kizginlik_log';

    ELSE
      v_tip       := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := TG_TABLE_NAME;
  END CASE;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, ref_id, ref_tablo)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_ref_id, v_ref_tablo);

  RETURN NEW;
END;
$$;

-- Trigger'ları yeniden bağla (idempotent)
DROP TRIGGER IF EXISTS trg_islem_hastalik ON public.hastalik_log;
CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT OR UPDATE ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

-- ── 3. HASTALIK_GUNCELLE RPC ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_guncelle(
  p_id         text,
  p_tani       text    DEFAULT NULL,
  p_kategori   text    DEFAULT NULL,
  p_siddet     text    DEFAULT NULL,
  p_semptomlar text    DEFAULT NULL,
  p_lokasyon   text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    tani       = COALESCE(p_tani,       tani),
    kategori   = COALESCE(p_kategori,   kategori),
    siddet     = COALESCE(p_siddet,     siddet),
    semptomlar = COALESCE(p_semptomlar, semptomlar),
    lokasyon   = COALESCE(p_lokasyon,   lokasyon),
    hekim_id   = COALESCE(p_hekim_id,   hekim_id)
  WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ── 4. HASTALIK_KAPAT RPC ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_kapat(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    durum          = 'Kapandı',
    kapanma_tarihi = CURRENT_DATE
  WHERE id = p_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ── 5. HASTALIK_SIL RPC ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Bağlı tedavi görevlerini iptal et
  UPDATE public.gorev_log SET
    tamamlandi = true,
    notlar     = COALESCE(notlar, '') || ' [Hastalık kaydı silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;

  -- Asıl kaydı sil
  DELETE FROM public.hastalik_log WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ── 6. RLS & SECURITY DEFINER ───────────────────────────────────
ALTER FUNCTION public.hastalik_guncelle SECURITY DEFINER;
ALTER FUNCTION public.hastalik_kapat    SECURITY DEFINER;
ALTER FUNCTION public.hastalik_sil      SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
-- Migration 016b — hastalik RPC cast fix
CREATE OR REPLACE FUNCTION public.hastalik_guncelle(
  p_id         text,
  p_tani       text    DEFAULT NULL,
  p_kategori   text    DEFAULT NULL,
  p_siddet     text    DEFAULT NULL,
  p_semptomlar text    DEFAULT NULL,
  p_lokasyon   text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    tani       = COALESCE(p_tani,       tani),
    kategori   = COALESCE(p_kategori,   kategori),
    siddet     = COALESCE(p_siddet,     siddet),
    semptomlar = COALESCE(p_semptomlar, semptomlar),
    lokasyon   = COALESCE(p_lokasyon,   lokasyon),
    hekim_id   = COALESCE(p_hekim_id,   hekim_id)
  WHERE id::text = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayit bulunamadi');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.hastalik_kapat(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    durum          = 'Kapandi',
    kapanma_tarihi = CURRENT_DATE
  WHERE id::text = p_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif kayit bulunamadi');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log SET
    tamamlandi = true,
    notlar     = COALESCE(notlar, '') || ' [Hastalik kaydi silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;
  DELETE FROM public.hastalik_log WHERE id::text = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayit bulunamadi');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.hastalik_guncelle SECURITY DEFINER;
ALTER FUNCTION public.hastalik_kapat    SECURITY DEFINER;
ALTER FUNCTION public.hastalik_sil      SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
-- Migration 018 — hastalik_sil notlar→aciklama fix
CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log SET
    tamamlandi = true,
    aciklama   = COALESCE(aciklama, '') || ' [Hastalik kaydi silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;

  DELETE FROM public.hastalik_log WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayit bulunamadi');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;
ALTER FUNCTION public.hastalik_sil SECURITY DEFINER;
NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 019 — TEDAVİ TABLOSU YENİDEN TASARIM
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. tedavi tablosuna eksik kolonlar eklendi
--    (uygulama_yolu, hekim_id, uygulayan, bekleme_suresi_gun)
-- 2. stok.kategori standardize edildi (İlaç / Sperma / Malzeme / Yem)
-- 3. hastalik_kaydet RPC → ilaçları tedavi tablosuna yazar
-- 4. tedavi_ekle RPC → sonradan ilaç eklemek için
-- 5. tedavi_sil RPC → ilaç kaydı sil + stok_hareket iptal
-- 6. hastalik_guncelle RPC → p_ilaclar kaldırıldı (tedavi_ekle/sil kullanılacak)
-- 7. tedavi view → hastalık detayı için
-- 8. RLS politikaları
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. TEDAVİ TABLOSUNA EKSİK KOLONLAR
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.tedavi
  ADD COLUMN IF NOT EXISTS uygulama_yolu    text,     -- IM, SC, IV, Oral, Topikal
  ADD COLUMN IF NOT EXISTS hekim_id         text,
  ADD COLUMN IF NOT EXISTS bekleme_suresi_gun integer, -- süt/et bekleme süresi (gün)
  ADD COLUMN IF NOT EXISTS notlar           text;

-- uygulama_yolu kısıtı (opsiyonel, esnek tutmak için CHECK yok)
COMMENT ON COLUMN public.tedavi.uygulama_yolu IS 'IM | SC | IV | Oral | Topikal | Intrauterin';
COMMENT ON COLUMN public.tedavi.bekleme_suresi_gun IS 'İlaç sonrası süt/et yasağı gün sayısı';

-- ──────────────────────────────────────────────────────────────
-- 2. STOK KATEGORİ COMMENT
-- ──────────────────────────────────────────────────────────────
COMMENT ON COLUMN public.stok.kategori IS 'İlaç | Sperma | Malzeme | Yem | Diğer';

-- ──────────────────────────────────────────────────────────────
-- 3. TEDAVİ VIEW — hastalık detay modalı için
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.tedavi_view CASCADE;
CREATE OR REPLACE VIEW public.tedavi_view AS
SELECT
  t.id,
  t.hayvan_id,
  t.vaka_id,
  t.tarih,
  t.tani,
  t.miktar,
  t.uygulama_yolu,
  t.hekim_id,
  t.bekleme_suresi_gun,
  t.sut_yasagi_bitis,
  t.aktif,
  t.notlar,
  t.created_at,
  s.urun_adi   AS ilac_adi,
  s.birim      AS ilac_birim,
  s.kategori   AS ilac_kategori
FROM public.tedavi t
LEFT JOIN public.stok s ON s.id = t.ilac_stok_id;

-- ──────────────────────────────────────────────────────────────
-- 4. HASTALIK_KAYDET — ilaçları tedavi tablosuna yazar
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
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan    record;
  v_hst_id    uuid := gen_random_uuid();
  v_bugun     date := CURRENT_DATE;
  v_ilac      jsonb;
  v_stok_id   text;
  v_miktar    numeric;
  v_yol       text;
  v_bekleme   integer;
  v_g         integer;
  v_ilac_ac   text := '';
  v_stok_rec  record;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  -- Hastalık (vaka) kaydı
  INSERT INTO public.hastalik_log (
    id, hayvan_id, tarih, kategori, tani, siddet, semptomlar,
    lokasyon, hekim_id, durum
  ) VALUES (
    v_hst_id, p_hayvan_id, v_bugun, p_kategori, p_tani, p_siddet, p_semptomlar,
    p_lokasyon, p_hekim_id, 'Aktif'
  );

  -- İlaçları tedavi tablosuna yaz + stok_hareket düş
  FOR v_ilac IN SELECT * FROM jsonb_array_elements(p_ilaclar)
  LOOP
    v_stok_id := v_ilac->>'stokId';
    v_miktar  := (v_ilac->>'mik')::numeric;
    v_yol     := v_ilac->>'uygulama_yolu';
    v_bekleme := (v_ilac->>'bekleme_suresi_gun')::integer;

    IF v_stok_id IS NOT NULL AND v_stok_id <> '' AND v_miktar > 0 THEN
      -- Stok adını bul
      SELECT * INTO v_stok_rec FROM public.stok WHERE id = v_stok_id;

      -- Tedavi kaydı
      INSERT INTO public.tedavi (
        hayvan_id, vaka_id, tarih, tani,
        ilac_stok_id, miktar, uygulama_yolu,
        hekim_id, bekleme_suresi_gun,
        sut_yasagi_bitis, aktif
      ) VALUES (
        p_hayvan_id, v_hst_id::text, v_bugun, p_tani,
        v_stok_id, v_miktar, v_yol,
        p_hekim_id, v_bekleme,
        CASE WHEN v_bekleme > 0 THEN v_bugun + v_bekleme ELSE NULL END,
        true
      );

      -- Stok hareketi
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
      VALUES (
        v_stok_id, 'Tedavi', v_miktar,
        p_tani || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
        false
      );

      v_ilac_ac := v_ilac_ac || COALESCE(v_stok_rec.urun_adi, v_stok_id) || ' ' || v_miktar::text || ' ';
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
$$;

-- ──────────────────────────────────────────────────────────────
-- 5. TEDAVİ_EKLE — Mevcut vakaya ilaç ekle
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tedavi_ekle(
  p_vaka_id         text,
  p_hayvan_id       text,
  p_ilac_stok_id    text,
  p_miktar          numeric,
  p_uygulama_yolu   text    DEFAULT NULL,
  p_bekleme_gun     integer DEFAULT NULL,
  p_hekim_id        text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok    record;
  v_hayvan  record;
  v_bugun   date := CURRENT_DATE;
  v_tani    text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  SELECT tani INTO v_tani FROM public.hastalik_log WHERE id::text = p_vaka_id;

  INSERT INTO public.tedavi (
    hayvan_id, vaka_id, tarih, tani,
    ilac_stok_id, miktar, uygulama_yolu,
    hekim_id, bekleme_suresi_gun,
    sut_yasagi_bitis, aktif, notlar
  ) VALUES (
    p_hayvan_id, p_vaka_id, v_bugun, v_tani,
    p_ilac_stok_id, p_miktar, p_uygulama_yolu,
    p_hekim_id, p_bekleme_gun,
    CASE WHEN p_bekleme_gun > 0 THEN v_bugun + p_bekleme_gun ELSE NULL END,
    true, p_notlar
  );

  -- Stok hareketi
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  VALUES (
    p_ilac_stok_id, 'Tedavi', p_miktar,
    COALESCE(v_tani, 'Tedavi') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 6. TEDAVİ_SİL — İlaç kaydını sil + stok_hareket iptal et
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tedavi_sil(
  p_tedavi_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi record;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  -- Stok hareketini iptal et (son eşleşen)
  UPDATE public.stok_hareket
  SET iptal = true
  WHERE id = (
    SELECT id FROM public.stok_hareket
    WHERE stok_id = v_tedavi.ilac_stok_id
      AND tur = 'Tedavi'
      AND iptal = false
      AND miktar = v_tedavi.miktar
    ORDER BY created_at DESC
    LIMIT 1
  );

  DELETE FROM public.tedavi WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 7. HASTALIK_GUNCELLE — ilaç parametresi yok (tedavi_ekle/sil kullanılır)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_guncelle(
  p_id         text,
  p_tani       text    DEFAULT NULL,
  p_kategori   text    DEFAULT NULL,
  p_siddet     text    DEFAULT NULL,
  p_semptomlar text    DEFAULT NULL,
  p_lokasyon   text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    tani       = COALESCE(p_tani,       tani),
    kategori   = COALESCE(p_kategori,   kategori),
    siddet     = COALESCE(p_siddet,     siddet),
    semptomlar = COALESCE(p_semptomlar, semptomlar),
    lokasyon   = COALESCE(p_lokasyon,   lokasyon),
    hekim_id   = COALESCE(p_hekim_id,   hekim_id)
  WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 8. HASTALIK_SİL — tedavi kayıtlarını da temizle
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_ted record;
BEGIN
  -- Bağlı tedavilerin stok hareketlerini iptal et
  FOR v_ted IN SELECT * FROM public.tedavi WHERE vaka_id = p_id
  LOOP
    UPDATE public.stok_hareket
    SET iptal = true
    WHERE id = (
      SELECT id FROM public.stok_hareket
      WHERE stok_id = v_ted.ilac_stok_id
        AND tur = 'Tedavi'
        AND iptal = false
        AND miktar = v_ted.miktar
      ORDER BY created_at DESC
      LIMIT 1
    );
  END LOOP;

  -- Bağlı tedavileri sil
  DELETE FROM public.tedavi WHERE vaka_id = p_id;

  -- Takip görevlerini kapat
  UPDATE public.gorev_log SET
    tamamlandi = true,
    aciklama   = COALESCE(aciklama, '') || ' [Hastalık kaydı silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;

  -- Hastalık kaydını sil
  DELETE FROM public.hastalik_log WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 9. RLS POLİTİKALARI
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.tedavi ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tedavi_select ON public.tedavi;
DROP POLICY IF EXISTS tedavi_insert ON public.tedavi;
DROP POLICY IF EXISTS tedavi_update ON public.tedavi;
DROP POLICY IF EXISTS tedavi_delete ON public.tedavi;

CREATE POLICY tedavi_select ON public.tedavi FOR SELECT USING (true);
CREATE POLICY tedavi_insert ON public.tedavi FOR INSERT WITH CHECK (true);
CREATE POLICY tedavi_update ON public.tedavi FOR UPDATE USING (true);
CREATE POLICY tedavi_delete ON public.tedavi FOR DELETE USING (true);

-- SECURITY DEFINER
ALTER FUNCTION public.hastalik_kaydet  SECURITY DEFINER;
ALTER FUNCTION public.tedavi_ekle      SECURITY DEFINER;
ALTER FUNCTION public.tedavi_sil       SECURITY DEFINER;
ALTER FUNCTION public.hastalik_guncelle SECURITY DEFINER;
ALTER FUNCTION public.hastalik_sil     SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
-- Migration 020: hastalik_guncelle RPC'ye p_tarih parametresi ekle

-- Eski imzalı fonksiyonu drop et
DROP FUNCTION IF EXISTS public.hastalik_guncelle(text,text,text,text,text,text,text);

CREATE OR REPLACE FUNCTION public.hastalik_guncelle(
  p_id         text,
  p_tani       text    DEFAULT NULL,
  p_kategori   text    DEFAULT NULL,
  p_siddet     text    DEFAULT NULL,
  p_semptomlar text    DEFAULT NULL,
  p_lokasyon   text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL,
  p_tarih      date    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    tani       = COALESCE(p_tani,       tani),
    kategori   = COALESCE(p_kategori,   kategori),
    siddet     = COALESCE(p_siddet,     siddet),
    semptomlar = COALESCE(p_semptomlar, semptomlar),
    lokasyon   = COALESCE(p_lokasyon,   lokasyon),
    hekim_id   = COALESCE(p_hekim_id,   hekim_id),
    tarih      = COALESCE(p_tarih,      tarih)
  WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;-- ══════════════════════════════════════════════════════════════
-- MIGRATION 021 — TEDAVİ GÜNCELLEME + STOK LEDGER DÜZELTMESİ
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. stok_hareket tablosuna referans_tipi + referans_id kolonları (audit trail)
-- 2. tedavi_ekle — stok_hareket'e referans bilgisi eklendi
-- 3. tedavi_sil — iptal=true yerine +miktar yeni hareket INSERT (ledger)
-- 4. tedavi_guncelle — fark hareketi INSERT eder, tedavi UPDATE eder
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. STOK_HAREKET — AUDIT KOLONLARI
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.stok_hareket
  ADD COLUMN IF NOT EXISTS referans_tipi text,   -- 'tedavi' | 'stok_girisi' | 'duzeltme' vb.
  ADD COLUMN IF NOT EXISTS referans_id   text;   -- ilgili kaydın id'si

COMMENT ON COLUMN public.stok_hareket.referans_tipi IS 'tedavi | stok_girisi | duzeltme | iade';
COMMENT ON COLUMN public.stok_hareket.referans_id   IS 'İlgili kaydın id değeri (tedavi.id vb.)';

-- ──────────────────────────────────────────────────────────────
-- 2. TEDAVİ_EKLE — referans bilgisi eklendi
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_ekle(text,text,text,numeric,text,integer,text,text);

CREATE OR REPLACE FUNCTION public.tedavi_ekle(
  p_vaka_id         text,
  p_hayvan_id       text,
  p_ilac_stok_id    text,
  p_miktar          numeric,
  p_uygulama_yolu   text    DEFAULT NULL,
  p_bekleme_gun     integer DEFAULT NULL,
  p_hekim_id        text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok      record;
  v_hayvan    record;
  v_bugun     date := CURRENT_DATE;
  v_tani      text;
  v_tedavi_id uuid := gen_random_uuid();
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  IF v_stok.miktar < p_miktar THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.urun_adi,'?'));
  END IF;

  SELECT tani INTO v_tani FROM public.hastalik_log WHERE id::text = p_vaka_id;

  INSERT INTO public.tedavi (
    id, hayvan_id, vaka_id, tarih, tani,
    ilac_stok_id, miktar, uygulama_yolu,
    hekim_id, bekleme_suresi_gun,
    sut_yasagi_bitis, aktif, notlar
  ) VALUES (
    v_tedavi_id, p_hayvan_id, p_vaka_id, v_bugun, v_tani,
    p_ilac_stok_id, p_miktar, p_uygulama_yolu,
    p_hekim_id, p_bekleme_gun,
    CASE WHEN p_bekleme_gun > 0 THEN v_bugun + p_bekleme_gun ELSE NULL END,
    true, p_notlar
  );

  -- Stok hareketi — ledger kaydı (negatif = kullanım)
  INSERT INTO public.stok_hareket (
    id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
  ) VALUES (
    gen_random_uuid()::text,
    p_ilac_stok_id,
    'Tedavi',
    -p_miktar,
    COALESCE(v_tani, 'Tedavi') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false,
    'tedavi',
    v_tedavi_id::text
  );

  -- Stok miktarını güncelle
  UPDATE public.stok SET miktar = miktar - p_miktar WHERE id = p_ilac_stok_id;

  RETURN jsonb_build_object('ok', true, 'tedavi_id', v_tedavi_id);
END;
$$;

ALTER FUNCTION public.tedavi_ekle SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────
-- 3. TEDAVİ_SİL — ledger: +miktar yeni hareket, DELETE tedavi
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_sil(text);

CREATE OR REPLACE FUNCTION public.tedavi_sil(
  p_tedavi_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi  record;
  v_stok    record;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

  -- Ledger: stok iadesi — yeni pozitif hareket ekle
  INSERT INTO public.stok_hareket (
    id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
  ) VALUES (
    gen_random_uuid()::text,
    v_tedavi.ilac_stok_id,
    'Tedavi İptal',
    v_tedavi.miktar,   -- pozitif = iade
    'Tedavi silindi — ' || COALESCE(v_tedavi.tani, '?'),
    false,
    'tedavi_iptal',
    p_tedavi_id
  );

  -- Stok miktarını geri ekle
  UPDATE public.stok SET miktar = miktar + v_tedavi.miktar WHERE id = v_tedavi.ilac_stok_id;

  -- Tedavi kaydını sil
  DELETE FROM public.tedavi WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.tedavi_sil SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────
-- 4. TEDAVİ_GUNCELLE — fark hareketi + UPDATE
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_guncelle(text,numeric,text,integer,text,text);

CREATE OR REPLACE FUNCTION public.tedavi_guncelle(
  p_tedavi_id       text,
  p_miktar          numeric  DEFAULT NULL,
  p_uygulama_yolu   text     DEFAULT NULL,
  p_bekleme_gun     integer  DEFAULT NULL,
  p_hekim_id        text     DEFAULT NULL,
  p_notlar          text     DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi  record;
  v_stok    record;
  v_fark    numeric;
  v_yeni_miktar numeric;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  v_yeni_miktar := COALESCE(p_miktar, v_tedavi.miktar);
  v_fark := v_tedavi.miktar - v_yeni_miktar;  -- pozitif = stok geri döner, negatif = daha fazla kullanım

  IF v_fark <> 0 THEN
    SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

    -- Yetersiz stok kontrolü (daha fazla kullanılacaksa)
    IF v_fark < 0 AND v_stok.miktar < ABS(v_fark) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.urun_adi,'?'));
    END IF;

    -- Ledger: fark hareketi
    INSERT INTO public.stok_hareket (
      id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
    ) VALUES (
      gen_random_uuid()::text,
      v_tedavi.ilac_stok_id,
      'Tedavi Düzeltme',
      v_fark,   -- pozitif = iade, negatif = ek kullanım
      'Tedavi güncellendi — ' || COALESCE(v_tedavi.tani, '?'),
      false,
      'tedavi_duzeltme',
      p_tedavi_id
    );

    -- Stok miktarını güncelle
    UPDATE public.stok SET miktar = miktar + v_fark WHERE id = v_tedavi.ilac_stok_id;
  END IF;

  -- Tedavi kaydını güncelle
  UPDATE public.tedavi SET
    miktar             = v_yeni_miktar,
    uygulama_yolu      = COALESCE(p_uygulama_yolu,  uygulama_yolu),
    bekleme_suresi_gun = COALESCE(p_bekleme_gun,     bekleme_suresi_gun),
    sut_yasagi_bitis   = CASE
                           WHEN p_bekleme_gun IS NOT NULL AND p_bekleme_gun > 0
                           THEN tarih + p_bekleme_gun
                           ELSE sut_yasagi_bitis
                         END,
    hekim_id           = COALESCE(p_hekim_id,        hekim_id),
    notlar             = COALESCE(p_notlar,           notlar)
  WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.tedavi_guncelle SECURITY DEFINER;

-- RLS
GRANT EXECUTE ON FUNCTION public.tedavi_ekle    TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_sil     TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_guncelle TO anon, authenticated;
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 022 — CASE MANAGEMENT SYSTEM
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. diseases        — controlled entity (FK ile tanı)
-- 2. drugs           — controlled entity (FK ile ilaç, stok bağlı)
-- 3. cases           — vaka katmanı (hayvanlar → cases)
-- 4. treatment_days  — günlük tedavi kaydı
-- 5. drug_administrations — ilaç uygulama (controlled FK)
-- 6. Trigger: day_no otomatik artar
-- 7. Trigger: drug_administrations INSERT → stok_hareket ledger
-- 8. View: treatment_timeline
-- 9. RPC: create_case, add_treatment_day, add_drug_administration, close_case
-- 10. RLS policies
-- 11. Seed data: diseases, drugs
--
-- Dokunulmayan tablolar: hayvanlar, stok, stok_hareket, hastalik_log, tedavi
-- Stok ledger mantığı: stok_hareket.miktar pozitif = kullanım
--   (frontend: guncel = baslangic_miktar - SUM(stok_hareket.miktar WHERE NOT iptal))
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. DISEASES — Controlled entity
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.diseases (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text        UNIQUE NOT NULL,
  category    text,
  created_at  timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.diseases           IS 'Controlled hastalık listesi — free text yasak';
COMMENT ON COLUMN public.diseases.category  IS 'Meme | Üreme | Metabolik | Ayak | Solunum | Sindirim | Buzağı | Diğer';

-- ──────────────────────────────────────────────────────────────
-- 2. DRUGS — Controlled entity, stok ile bağlı
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drugs (
  id             uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text  UNIQUE NOT NULL,
  stock_item_id  text  REFERENCES public.stok(id) ON DELETE SET NULL,
  default_unit   text,
  default_route  text,
  created_at     timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.drugs                IS 'Controlled ilaç listesi — free text yasak';
COMMENT ON COLUMN public.drugs.stock_item_id  IS 'stok.id FK — NULL ise stok düşümü yapılmaz';
COMMENT ON COLUMN public.drugs.default_route  IS 'IM | IV | SC | PO | Topikal | Intrauterin';

-- ──────────────────────────────────────────────────────────────
-- 3. CASES — Vaka katmanı
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cases (
  id          uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  animal_id   text  NOT NULL REFERENCES public.hayvanlar(id),
  disease_id  uuid  NOT NULL REFERENCES public.diseases(id),
  start_date  date  NOT NULL DEFAULT CURRENT_DATE,
  status      text  NOT NULL DEFAULT 'active',
  notes       text,
  created_at  timestamptz DEFAULT now(),
  closed_at   timestamptz,
  CONSTRAINT cases_status_check CHECK (status IN ('active','closed'))
);

COMMENT ON TABLE  public.cases         IS 'Veteriner vaka kaydı — hayvan başına aktif/kapalı vakalar';
COMMENT ON COLUMN public.cases.status  IS 'active | closed';

CREATE INDEX IF NOT EXISTS cases_animal_id_idx ON public.cases(animal_id);
CREATE INDEX IF NOT EXISTS cases_status_idx    ON public.cases(status);

-- ──────────────────────────────────────────────────────────────
-- 4. TREATMENT DAYS — Günlük tedavi
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.treatment_days (
  id               uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id          uuid  NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  day_no           integer,
  treatment_date   date  NOT NULL DEFAULT CURRENT_DATE,
  notes            text,
  created_at       timestamptz DEFAULT now()
);

COMMENT ON COLUMN public.treatment_days.day_no IS 'Trigger ile otomatik artar — frontend set etmez';

CREATE INDEX IF NOT EXISTS treatment_days_case_id_idx ON public.treatment_days(case_id);

-- ──────────────────────────────────────────────────────────────
-- 5. DRUG ADMINISTRATIONS — İlaç uygulama (controlled FK)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_administrations (
  id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id  uuid    NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  drug_id           uuid    NOT NULL REFERENCES public.drugs(id),
  dose              numeric NOT NULL CHECK (dose > 0),
  unit              text    NOT NULL,
  route             text,
  notes             text,
  created_at        timestamptz DEFAULT now(),
  CONSTRAINT drug_administrations_route_check
    CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin'))
);

COMMENT ON TABLE  public.drug_administrations  IS 'Controlled ilaç uygulama — drug_id FK zorunlu';
COMMENT ON COLUMN public.drug_administrations.route IS 'IM | IV | SC | PO | Topikal | Intrauterin';

CREATE INDEX IF NOT EXISTS drug_admin_day_id_idx ON public.drug_administrations(treatment_day_id);

-- ──────────────────────────────────────────────────────────────
-- 6. TRIGGER: day_no otomatik artar
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_treatment_day_no()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.day_no IS NULL THEN
    SELECT COALESCE(MAX(day_no), 0) + 1
    INTO   NEW.day_no
    FROM   public.treatment_days
    WHERE  case_id = NEW.case_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_day_no ON public.treatment_days;
CREATE TRIGGER trg_set_day_no
  BEFORE INSERT ON public.treatment_days
  FOR EACH ROW EXECUTE FUNCTION public.set_treatment_day_no();

-- ──────────────────────────────────────────────────────────────
-- 7. TRIGGER: drug_administrations → stok_hareket ledger
--
-- Mevcut ledger mantığı korunur:
--   stok_hareket.miktar POZİTİF = kullanım
--   frontend: guncel = baslangic_miktar - SUM(miktar WHERE NOT iptal)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.drug_administration_stok_dusum()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id   text;
  v_drug_name text;
  v_animal_id text;
  v_kupe_no   text;
  v_guncel    numeric;
BEGIN
  -- İlacın stok bağlantısını kontrol et
  SELECT d.stock_item_id, d.name
  INTO   v_stok_id, v_drug_name
  FROM   public.drugs d
  WHERE  d.id = NEW.drug_id;

  -- Stok bağlantısı yoksa ledger kaydı yapmadan geç
  IF v_stok_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Hayvan küpe no'sunu bul (notlar için)
  SELECT c.animal_id INTO v_animal_id
  FROM   public.treatment_days td
  JOIN   public.cases c ON c.id = td.case_id
  WHERE  td.id = NEW.treatment_day_id;

  SELECT kupe_no INTO v_kupe_no
  FROM   public.hayvanlar
  WHERE  id = v_animal_id;

  -- Stok yeterliliği kontrolü
  SELECT COALESCE(s.baslangic_miktar, 0)
         - COALESCE((
             SELECT SUM(sh.miktar)
             FROM   public.stok_hareket sh
             WHERE  sh.stok_id = v_stok_id
               AND  NOT sh.iptal
           ), 0)
  INTO v_guncel
  FROM public.stok s
  WHERE s.id = v_stok_id;

  IF v_guncel < NEW.dose THEN
    RAISE EXCEPTION 'Yetersiz stok: % (mevcut: %, istenen: %)',
      v_drug_name, v_guncel, NEW.dose;
  END IF;

  -- Ledger: pozitif = kullanım (frontend bu değeri SUM'dan düşürür)
  INSERT INTO public.stok_hareket (
    stok_id, tur, miktar, notlar, iptal,
    referans_tipi, referans_id
  ) VALUES (
    v_stok_id,
    'Tedavi',
    NEW.dose,   -- POZİTİF — mevcut ledger mantığıyla uyumlu
    v_drug_name || ' — ' || COALESCE(v_kupe_no, v_animal_id),
    false,
    'drug_administration',
    NEW.id::text
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_drug_administration_stok ON public.drug_administrations;
CREATE TRIGGER trg_drug_administration_stok
  AFTER INSERT ON public.drug_administrations
  FOR EACH ROW EXECUTE FUNCTION public.drug_administration_stok_dusum();

-- ──────────────────────────────────────────────────────────────
-- 8. VIEW: treatment_timeline
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.treatment_timeline CASCADE;
CREATE VIEW public.treatment_timeline AS
SELECT
  h.id          AS animal_id,
  h.kupe_no     AS kupe_no,
  c.id          AS case_id,
  c.status      AS case_status,
  c.start_date  AS case_start,
  dis.name      AS disease,
  dis.category  AS disease_category,
  td.id         AS day_id,
  td.day_no,
  td.treatment_date,
  dr.id         AS drug_id,
  dr.name       AS drug,
  da.id         AS administration_id,
  da.dose,
  da.unit,
  da.route,
  da.notes      AS admin_notes
FROM public.drug_administrations da
JOIN public.treatment_days  td  ON td.id  = da.treatment_day_id
JOIN public.cases           c   ON c.id   = td.case_id
JOIN public.hayvanlar       h   ON h.id   = c.animal_id
JOIN public.drugs           dr  ON dr.id  = da.drug_id
JOIN public.diseases        dis ON dis.id = c.disease_id;

COMMENT ON VIEW public.treatment_timeline IS 'Vaka → gün → ilaç timeline, frontend için hazır';

-- ──────────────────────────────────────────────────────────────
-- 9. RPC FONKSİYONLARI
-- ──────────────────────────────────────────────────────────────

-- 9a. create_case
DROP FUNCTION IF EXISTS public.create_case(text, uuid, text);
CREATE OR REPLACE FUNCTION public.create_case(
  p_animal_id   text,
  p_disease_id  uuid,
  p_notes       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id  uuid;
  v_animal  record;
  v_disease record;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_disease FROM public.diseases WHERE id = p_disease_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık kaydı bulunamadı');
  END IF;

  -- Aynı hayvanda aynı hastalıkta zaten aktif vaka var mı?
  IF EXISTS (
    SELECT 1 FROM public.cases
    WHERE animal_id = p_animal_id
      AND disease_id = p_disease_id
      AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hayvan için zaten aktif bir ' || v_disease.name || ' vakası mevcut');
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, notes)
  VALUES (p_animal_id, p_disease_id, p_notes)
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$$;

-- 9b. add_treatment_day
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid);
CREATE OR REPLACE FUNCTION public.add_treatment_day(
  p_case_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id uuid;
  v_case   record;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya gün eklenemez');
  END IF;

  INSERT INTO public.treatment_days (case_id)
  VALUES (p_case_id)
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'day_id', v_new_id);
END;
$$;

-- 9c. add_drug_administration
DROP FUNCTION IF EXISTS public.add_drug_administration(uuid, uuid, numeric, text, text);
CREATE OR REPLACE FUNCTION public.add_drug_administration(
  p_day_id   uuid,
  p_drug_id  uuid,
  p_dose     numeric,
  p_unit     text,
  p_route    text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id   uuid;
  v_day      record;
  v_case     record;
  v_drug     record;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi günü bulunamadı');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = v_day.case_id;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya ilaç eklenemez');
  END IF;

  SELECT * INTO v_drug FROM public.drugs WHERE id = p_drug_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kaydı bulunamadı');
  END IF;

  IF p_dose IS NULL OR p_dose <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçerli bir doz girin');
  END IF;

  INSERT INTO public.drug_administrations (
    treatment_day_id, drug_id, dose, unit, route
  ) VALUES (
    p_day_id, p_drug_id, p_dose,
    COALESCE(p_unit, v_drug.default_unit, ''),
    COALESCE(p_route, v_drug.default_route)
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'administration_id', v_new_id);
END;
$$;

-- 9d. close_case
DROP FUNCTION IF EXISTS public.close_case(uuid);
CREATE OR REPLACE FUNCTION public.close_case(
  p_case_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.cases
  SET status    = 'closed',
      closed_at = now()
  WHERE id = p_case_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 10. RLS
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.diseases             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drugs                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cases                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treatment_days       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drug_administrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS diseases_select             ON public.diseases;
DROP POLICY IF EXISTS drugs_select                ON public.drugs;
DROP POLICY IF EXISTS cases_all                   ON public.cases;
DROP POLICY IF EXISTS treatment_days_all          ON public.treatment_days;
DROP POLICY IF EXISTS drug_administrations_all    ON public.drug_administrations;

CREATE POLICY diseases_select          ON public.diseases             FOR SELECT USING (true);
CREATE POLICY drugs_select             ON public.drugs                FOR SELECT USING (true);
CREATE POLICY cases_all                ON public.cases                FOR ALL    USING (true);
CREATE POLICY treatment_days_all       ON public.treatment_days       FOR ALL    USING (true);
CREATE POLICY drug_administrations_all ON public.drug_administrations FOR ALL    USING (true);

-- SECURITY DEFINER GRANTS
GRANT EXECUTE ON FUNCTION public.create_case             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_treatment_day       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_drug_administration TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.close_case              TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 11. SEED DATA — Diseases
-- ──────────────────────────────────────────────────────────────
INSERT INTO public.diseases (name, category) VALUES
  ('Mastit',                    'Meme'),
  ('Subklinik Mastit',          'Meme'),
  ('Klinik Mastit',             'Meme'),
  ('Metrit',                    'Üreme'),
  ('Endometrit',                'Üreme'),
  ('Pyometra',                  'Üreme'),
  ('Retensiyo Sekundinarum',    'Üreme'),
  ('Kistik Over',               'Üreme'),
  ('Anoestrus',                 'Üreme'),
  ('Hipokalsemi (Süt Humması)', 'Metabolik'),
  ('Ketozis',                   'Metabolik'),
  ('Ruminal Asidoz',            'Metabolik'),
  ('Timpani',                   'Metabolik'),
  ('Şirden Deplasmanı',         'Metabolik'),
  ('Topallık (Dermatit)',       'Ayak'),
  ('Topallık (Laminit)',        'Ayak'),
  ('Beyaz Çizgi Hastalığı',     'Ayak'),
  ('Tırnak Yarası',             'Ayak'),
  ('Pnömoni',                   'Solunum'),
  ('Buzağı İshali',             'Buzağı'),
  ('Buzağı Göbek İltihabı',    'Buzağı'),
  ('Neonatal Zayıflık',         'Buzağı')
ON CONFLICT (name) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- 12. SEED DATA — Drugs (stock_item_id başlangıçta NULL)
--     UI'dan stok kalemini drugs tablosuna bağlamak gerekir
-- ──────────────────────────────────────────────────────────────
INSERT INTO public.drugs (name, default_unit, default_route) VALUES
  ('Enrofloksasin',    'ml',  'IM'),
  ('Oksitetrasiklin',  'ml',  'IM'),
  ('Penisilin',        'ml',  'IM'),
  ('Meloksikam',       'ml',  'IM'),
  ('Ketoprofen',       'ml',  'IM'),
  ('Flunixin',         'ml',  'IV'),
  ('Deksametazon',     'ml',  'IM'),
  ('B Kompleks',       'ml',  'IM'),
  ('Kalsiyum Boroglukonat', 'ml', 'IV'),
  ('Magnezyum Sülfat', 'ml',  'IV'),
  ('Glukoz %50',       'ml',  'IV'),
  ('Elektrolit',       'gr',  'PO'),
  ('Rumen Stimülanı',  'ml',  'PO'),
  ('Oksitoksin',       'ml',  'IM'),
  ('Progesteron',      'ml',  'IM'),
  ('GnRH',             'ml',  'IM'),
  ('PGF2α',            'ml',  'IM'),
  ('Antiparaziter',    'ml',  'SC'),
  ('Vitamin AD3E',     'ml',  'IM'),
  ('Vitamin C',        'ml',  'IV')
ON CONFLICT (name) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- PostgREST schema cache yenile
-- ──────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 023 — REMOVE DRUG ADMINISTRATION RPC
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. remove_drug_administration(p_admin_id uuid) → jsonb
--    - drug_administrations kaydını siler
--    - Bağlı stok_hareket satırını iptal=true yapar (ledger bütünlüğü)
--    - Kapalı vakada silme yasak
--    - stok_hareket kaydı yoksa (stok_item_id=NULL ilaç) yine de siler
-- ══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.remove_drug_administration(uuid);

CREATE OR REPLACE FUNCTION public.remove_drug_administration(
  p_admin_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin  record;
  v_day    record;
  v_case   record;
BEGIN
  -- Kaydı çek
  SELECT * INTO v_admin
  FROM   public.drug_administrations
  WHERE  id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kaydı bulunamadı');
  END IF;

  -- Tedavi günü → vaka kontrolü
  SELECT * INTO v_day  FROM public.treatment_days WHERE id = v_admin.treatment_day_id;
  SELECT * INTO v_case FROM public.cases          WHERE id = v_day.case_id;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakadan ilaç silinemez');
  END IF;

  -- Bağlı stok_hareket satırını iptal et (ledger'ı geri al)
  -- referans_tipi='drug_administration' AND referans_id=p_admin_id::text ile eşleştir
  UPDATE public.stok_hareket
  SET    iptal = true
  WHERE  referans_tipi = 'drug_administration'
    AND  referans_id   = p_admin_id::text
    AND  NOT iptal;

  -- Kaydı sil (ON DELETE CASCADE: yoksa gün silerken zaten temizlenir ama burada explicit)
  DELETE FROM public.drug_administrations WHERE id = p_admin_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_drug_administration TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 024 — LINK DRUG TO STOCK RPC
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. link_drug_to_stock(p_drug_id uuid, p_stock_item_id text)
--    - drugs.stock_item_id günceller (NULL göndermek bağlantıyı koparır)
--    - p_stock_item_id NULL ise bağlantı kaldırılır
--    - stok kaydı yoksa hata döner
-- ══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.link_drug_to_stock(uuid, text);

CREATE OR REPLACE FUNCTION public.link_drug_to_stock(
  p_drug_id        uuid,
  p_stock_item_id  text   -- NULL = bağlantıyı kaldır
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_drug  record;
BEGIN
  SELECT * INTO v_drug FROM public.drugs WHERE id = p_drug_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kaydı bulunamadı');
  END IF;

  -- Stok kaydı var mı kontrolü (NULL ise atla — bağlantı kaldırma)
  IF p_stock_item_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.stok WHERE id = p_stock_item_id) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
    END IF;
  END IF;

  UPDATE public.drugs
  SET stock_item_id = p_stock_item_id
  WHERE id = p_drug_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.link_drug_to_stock TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 025 — TREATMENT DAY TIME COLUMN
-- EgeSüt ERP — 2026-03-25
--
-- Değişiklikler:
-- 1. treatment_days.treatment_time (time) kolonu eklendi
-- 2. update_treatment_time RPC eklendi
--
-- NOT: treatment_timeline view'ı yeniden tanımlanmıyor —
-- gerçek DB şeması repo'daki migration 022 ile tam örtüşmüyor
-- (drug_administrations kolon adları farklı). MCP erişimi
-- sağlandıktan sonra view güncellenecek.
-- ══════════════════════════════════════════════════════════════

-- 1. Kolon ekle
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS treatment_time time;

COMMENT ON COLUMN public.treatment_days.treatment_time IS 'Tedavi saati (örn. 08:00) — opsiyonel';

-- 2. RPC: tedavi günü saatini güncelle
DROP FUNCTION IF EXISTS public.update_treatment_time(uuid, time);
CREATE OR REPLACE FUNCTION public.update_treatment_time(
  p_day_id        uuid,
  p_treatment_time time
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.treatment_days
  SET treatment_time = p_treatment_time
  WHERE id = p_day_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi günü bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_treatment_time TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 026 — treatment_timeline view'a treatment_time ekle
-- EgeSüt ERP — 2026-03-25
--
-- Sorun: treatment_days.treatment_time kolonu view'a dahil
--        edilmemişti. JS tarafı r.treatment_time okuyunca
--        undefined alıyor, saat hiç gösterilmiyordu.
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.treatment_timeline AS
SELECT
  h.id              AS animal_id,
  h.kupe_no,
  c.id              AS case_id,
  c.status          AS case_status,
  c.start_date      AS case_start,
  dis.name          AS disease,
  dis.category      AS disease_category,
  td.id             AS day_id,
  td.day_no,
  td.treatment_date,
  dp.id             AS drug_id,
  COALESCE(dp.brand_name, s.urun_adi, '?') AS drug,
  da.id             AS administration_id,
  da.dose,
  da.unit,
  da.route,
  da.notes          AS admin_notes,
  da.stok_id,
  td.treatment_time
FROM treatment_days td
  JOIN  cases             c   ON c.id   = td.case_id
  JOIN  hayvanlar         h   ON h.id   = c.animal_id
  JOIN  diseases          dis ON dis.id = c.disease_id
  LEFT JOIN drug_administrations da  ON da.treatment_day_id = td.id
  LEFT JOIN drug_products        dp  ON dp.id = da.drug_product_id
  LEFT JOIN stok                 s   ON s.id  = da.stok_id;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 026 — Grup/Padok düzeltmeleri + Gebe trigger
-- EgeSüt ERP — 2026-03-26
--
-- Değişiklikler:
-- 1. dogum_kaydet: buzağı grup 'Süt İçen Buzağılar' → 'Süt İçen Buzağı'
--                 buzağı padok 'Buzağı Ahırı' → 'Buzağı Padok (Süt İçenler)'
-- 2. dogum_kaydet: anne doğum sonrası grup → 'Sağmal (Laktasyonda)'
-- 3. Trigger: tohumlama.sonuc = 'Gebe' olunca düve grubundaki
--            hayvanlar otomatik 'Gebe Düve' grubuna geçer
-- ══════════════════════════════════════════════════════════════

-- ── 1+2. dogum_kaydet — buzağı + anne grup/padok ──────────────
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

  -- 3. Buzağıyı sürüye ekle (P2: düzeltilmiş grup + padok isimleri)
  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, p_baba, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  -- 4. Anne grup + padok güncelle (P3: artık grup da güncelleniyor)
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

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 14,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 3. Gebe trigger — düve → Gebe Düve otomatik geçiş ─────────
CREATE OR REPLACE FUNCTION public.fn_gebe_grup_guncelle()
RETURNS TRIGGER AS $$
BEGIN
  -- Sadece sonuc 'Gebe' olarak değiştirildiğinde tetiklenir
  IF NEW.sonuc = 'Gebe' AND (OLD.sonuc IS DISTINCT FROM 'Gebe') THEN
    UPDATE public.hayvanlar
    SET
      grup  = CASE
                WHEN grup IN ('Düve (Büyük)', 'Düve (Küçük)') THEN 'Gebe Düve'
                ELSE grup
              END,
      padok = CASE
                WHEN grup IN ('Düve (Büyük)', 'Düve (Küçük)') THEN 'Kuru/Gebe Padok'
                ELSE padok
              END
    WHERE id = NEW.hayvan_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_gebe_grup ON public.tohumlama;
CREATE TRIGGER trg_gebe_grup
  AFTER UPDATE ON public.tohumlama
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_gebe_grup_guncelle();

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 027 — Besi padok ayrımı + trigger kaldır + dogum_kaydet baba auto-fill
-- EgeSüt ERP — 2026-03-26
--
-- Değişiklikler:
-- 1. trg_gebe_grup trigger'ı ve fn_gebe_grup_guncelle fonksiyonu kaldırıldı
--    (Süt veren inekler de tohumlanabiliyor — grup otomasyonu yanlıştı)
-- 2. Mevcut Besi hayvanları padok güncellendi:
--    Erkek → 'Besi Padok (Erkek)', Dişi → 'Besi Padok (Dişi)'
-- 3. dogum_kaydet: p_baba artık isteğe bağlı (UI'den gönderilmeyecek)
--    Aktif Gebe tohumlamadan sperma otomatik baba_bilgi olarak kullanılıyor
-- ══════════════════════════════════════════════════════════════

-- ── 1. Trigger + fonksiyonu kaldır ──────────────────────────
DROP TRIGGER IF EXISTS trg_gebe_grup ON public.tohumlama;
DROP FUNCTION IF EXISTS public.fn_gebe_grup_guncelle();

-- ── 2. Mevcut Besi hayvanları padok düzelt ──────────────────
UPDATE public.hayvanlar
SET padok = CASE
  WHEN cinsiyet = 'Erkek' THEN 'Besi Padok (Erkek)'
  ELSE 'Besi Padok (Dişi)'
END
WHERE grup = 'Besi';

-- ── 3. dogum_kaydet — baba_bilgi aktif Gebe tohumlamadan al ─
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

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 14,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
-- Fix: tohumlama UPDATE trigger 'Doğum Yaptı' güncellemesini ABORT_KAYDI değil DOGUM_KAYDI olarak loglasın
-- Sorun: dogum_kaydet RPC tohumlama.sonuc='Doğum Yaptı' yaparken trigger her UPDATE'i ABORT_KAYDI yazıyordu

CREATE OR REPLACE FUNCTION public.fn_islem_log()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip        text;
  v_hayvan_id  uuid;
  v_snapshot   jsonb;
  v_ref_id     uuid;
  v_ref_tablo  text;
BEGIN
  CASE TG_TABLE_NAME

    WHEN 'hayvanlar' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hayvanlar';

    WHEN 'dogum' THEN
      v_tip       := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'dogum';

    WHEN 'tohumlama' THEN
      v_tip := CASE
        WHEN TG_OP = 'UPDATE' AND NEW.sonuc = 'Abort'       THEN 'ABORT_KAYDI'
        WHEN TG_OP = 'UPDATE' AND NEW.sonuc = 'Doğum Yaptı' THEN 'DOGUM_KAYDI'
        WHEN TG_OP = 'UPDATE'                                THEN 'TOHUMLAMA_GUNCELLENDI'
        ELSE 'TOHUMLAMA'
      END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'tohumlama';

    WHEN 'hastalik_log' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HASTALIK_KAYDI' ELSE 'HASTALIK_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hastalik_log';

    WHEN 'kizginlik_log' THEN
      v_tip       := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'kizginlik_log';

    ELSE
      v_tip       := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := TG_TABLE_NAME;
  END CASE;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, ref_id, ref_tablo)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_ref_id, v_ref_tablo);

  RETURN NEW;
END;
$$;
-- Migration 029: geri_al RPC (restore from drift)
-- Bu fonksiyon migration 013'te SQL Editor üzerinden uygulandı,
-- repo'ya hiç eklenmemişti. DB reset'e karşı kalıcı hale getiriliyor.

CREATE OR REPLACE FUNCTION public.geri_al(p_islem_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_snapshot  jsonb;
  v_item      jsonb;
  v_tablo     text;
  v_pk        text;
  v_onceki    jsonb;
  v_col       text;
  v_val       text;
  v_set_parts text[] := '{}';
  v_sql       text;
BEGIN
  -- İşlem kaydını al
  SELECT snapshot INTO v_snapshot
  FROM islem_log
  WHERE id = p_islem_id;

  IF v_snapshot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'islem bulunamadi');
  END IF;

  -- Oluşturulan kayıtları sil
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';
    EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
  END LOOP;

  -- Güncellenen kayıtları geri al
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'guncellenen')
  LOOP
    v_tablo  := v_item->>'tablo';
    v_pk     := v_item->>'id';
    v_onceki := v_item->'onceki';
    v_set_parts := '{}';

    FOR v_col, v_val IN SELECT key, value #>> '{}' FROM jsonb_each(v_onceki)
    LOOP
      v_set_parts := array_append(
        v_set_parts,
        format('%I = %L', v_col, v_val)
      );
    END LOOP;

    IF array_length(v_set_parts, 1) > 0 THEN
      v_sql := format(
        'UPDATE %I SET %s WHERE id = $1',
        v_tablo,
        array_to_string(v_set_parts, ', ')
      );
      EXECUTE v_sql USING v_pk;
    END IF;
  END LOOP;

  -- İşlem durumunu güncelle
  UPDATE islem_log SET durum = 'geri_alindi' WHERE id = p_islem_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.geri_al(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
-- Migration: tohumlama event stack — önceki Bekliyor→Boş + islem_log snapshot + tohumlama_sonuc_gebe RPC
-- Etkiler: tohumlama_kaydet RPC (güncelleme), tohumlama_sonuc_gebe RPC (yeni)
--          Tablolar: tohumlama, gorev_log, islem_log, hayvanlar
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_gebe(text);
--                          DROP FUNCTION tohumlama_kaydet(text,date,text,text,text);
--                          (eski versiyonu migration 20260326000028'den yeniden uygula)

BEGIN;

-- 1. tohumlama_kaydet: DROP + yeniden oluştur
--    Değişiklikler:
--      a) Yeni tohumlama INSERT'ten önce: önceki Bekliyor kayıtları Boş yap
--      b) gorev_log için önceden ID üret (v_gorev1_id, v_gorev2_id)
--      c) islem_log INSERT ekle — tohumlama + gorev_log ID'leri olusturulan array'inde
--      d) Dönüş değerine islem_id eklendi

DROP FUNCTION IF EXISTS public.tohumlama_kaydet(text, date, text, text, text);

CREATE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id    text,
  p_tarih        date,
  p_sperma       text,
  p_hekim_id     text    DEFAULT NULL,
  p_irk_bilgisi  text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan    record;
  v_yas_gun   integer;
  v_deneme    integer;
  v_toh_id    uuid := gen_random_uuid();
  v_gorev1_id uuid := gen_random_uuid();
  v_gorev2_id uuid := gen_random_uuid();
  v_islem_id  text := gen_random_uuid()::text;
  v_stok_id   uuid;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvana tohumlama yapılamaz');
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan 12 aydan küçük — tohumlama yapılamaz');
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan zaten gebe — önce gebeliği kapatın');
  END IF;

  -- Önceki Bekliyor tohumlamaları Boş yap (event stack kuralı)
  UPDATE public.tohumlama
  SET sonuc = 'Boş'
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor';

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (v_gorev1_id, p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (v_gorev2_id, p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
    'Tohumlama — ' || v_hayvan.kupe_no, false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1
  RETURNING id INTO v_stok_id;

  -- islem_log: tohumlama + gorev_log ID'leri olusturulan array'ine ekle (geri alınabilmesi için)
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA',
    p_hayvan_id,
    v_toh_id::text,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama',  'id', v_toh_id::text),
        jsonb_build_object('tablo', 'gorev_log',  'id', v_gorev1_id::text),
        jsonb_build_object('tablo', 'gorev_log',  'id', v_gorev2_id::text)
      ) ||
      CASE WHEN v_stok_id IS NOT NULL
        THEN jsonb_build_array(jsonb_build_object('tablo', 'stok_hareket', 'id', v_stok_id::text))
        ELSE '[]'::jsonb
      END,
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh_id, 'deneme_no', v_deneme, 'islem_id', v_islem_id);
END;
$$;

-- 2. tohumlama_sonuc_gebe: yeni RPC
--    Sadece son + Bekliyor tohumlamayı Gebe yapar,
--    hayvanlar.tohumlama_durumu günceller,
--    islem_log'a guncellenen snapshot ile kaydeder (geri alınabilir)

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh          record;
  v_son_toh_id   text;
  v_islem_id     text := gen_random_uuid()::text;
  v_onceki_durum text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir');
  END IF;

  -- Bu hayvanın son tohumlaması mı? (FOR UPDATE: race condition önleme)
  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY deneme_no DESC
  LIMIT 1
  FOR UPDATE;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  -- AND durum = 'Aktif' guard: pasif/ölü hayvan işlemi engellensin
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id::uuid
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;

  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Gebe'
  WHERE id = v_toh.hayvan_id::uuid;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'GEBE_ATAMA',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_toh.sonuc)
        ),
        jsonb_build_object(
          'tablo', 'hayvanlar',
          'id', v_toh.hayvan_id,
          'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum)
        )
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
