-- ═══════════════════════════════════════════════════════
-- GROUND TRUTH MIGRATION — REFERANS, CALISTIRMAYIN
-- Tarih: 2026-05-13
-- Tum migration'larin birlestirilmis hali, sifirdan kurulum icin referans.
-- ═══════════════════════════════════════════════════════

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
  durum text DEFAULT 'Aktif',
  etiketler text[] DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_hayvanlar_etiketler
  ON public.hayvanlar USING GIN(etiketler);

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
  iptal boolean DEFAULT false,
  etken_kod text,
  kapatan_ref text
);

-- uygulama_log: Case-free hızlı ilaç/vitamin uygulama kaydı (Task 6)
CREATE TABLE IF NOT EXISTS public.uygulama_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  stok_id text REFERENCES public.stok(id),
  etken_kod text,
  doz numeric NOT NULL,
  birim text NOT NULL,
  rota text NOT NULL CHECK (rota IN ('IM','IV','SC','PO','Topikal','Intrauterin')),
  tarih date NOT NULL DEFAULT CURRENT_DATE,
  notlar text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_uygulama_log_hayvan ON public.uygulama_log(hayvan_id);
CREATE INDEX IF NOT EXISTS idx_uygulama_log_tarih ON public.uygulama_log(tarih);
ALTER TABLE public.uygulama_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_all_uygulama_log ON public.uygulama_log FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.uygulama_log TO anon, authenticated;

-- protokol_dismiss: Kullanıcı tarafından geçersiz kılınan protokol uyarıları (Task 10)
CREATE TABLE IF NOT EXISTS public.protokol_dismiss (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  etken_kod text NOT NULL,
  protokol text NOT NULL,
  tarih timestamptz DEFAULT now(),
  neden text,
  UNIQUE(hayvan_id, etken_kod, protokol)
);
ALTER TABLE public.protokol_dismiss ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_all_protokol_dismiss ON public.protokol_dismiss FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.protokol_dismiss TO anon, authenticated;

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
  deneme_no integer DEFAULT 1,
  vwp_override boolean DEFAULT false
);

ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS ek_uygulamalar jsonb DEFAULT '[]'::jsonb;

ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS case_id uuid REFERENCES public.cases(id) ON DELETE SET NULL;

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
  SELECT COALESCE(COUNT(*), 0) + 1 INTO NEW.deneme_no
  FROM public.tohumlama
  WHERE hayvan_id = NEW.hayvan_id
    AND tarih > COALESCE(
      (SELECT MAX(tarih) FROM public.tohumlama
       WHERE hayvan_id = NEW.hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
      '1900-01-01'::date
    );
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
  v_hayvan       record;
  v_yas_gun      integer;
  v_son_dogum    date;
  v_dogum_gun    integer := NULL;
  v_sonuc        text := 'GOZLEMLENDI';
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvanlarda kızgınlık kaydı yapılamaz');
  END IF;

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

  -- Son doğum tarihini kontrol et (dogum tablosundan)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_dogum_gun := p_tarih - v_son_dogum;
    IF v_dogum_gun >= 0 AND v_dogum_gun < 55 THEN
      v_sonuc := 'POSTPARTUM_GOZLEM';
    END IF;
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar, sonuc)
  VALUES (gen_random_uuid()::text, p_hayvan_id, p_tarih, p_belirti, p_notlar, v_sonuc);

  RETURN jsonb_build_object(
    'ok', true,
    'postpartum', v_sonuc = 'POSTPARTUM_GOZLEM',
    'dogum_gun', v_dogum_gun
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.kizginlik_kaydet(text, date, text, text) TO anon, authenticated;

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
  p_hayvan_id      text,
  p_tarih          date,
  p_sperma         text,
  p_hekim_id       text    DEFAULT NULL,
  p_irk_bilgisi    text    DEFAULT NULL,
  p_ek_uygulamalar jsonb   DEFAULT '[]'::jsonb,
  p_vwp_override   boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
  v_ek       jsonb;
  v_ek_stok  uuid;
  v_son_dogum date;
  v_vwp_gun  integer;
BEGIN
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  -- VWP kontrolü (55 gün)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme, p_ek_uygulamalar,
     CASE WHEN v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 THEN true ELSE false END);

  -- VWP override loglama
  IF v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 AND p_vwp_override THEN
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
    VALUES (
      gen_random_uuid()::text,
      'VWP_OVERRIDE',
      p_hayvan_id,
      jsonb_build_object(
        'tohumlama_id', v_toh_id,
        'vwp_gun', p_tarih - v_son_dogum,
        'son_dogum', v_son_dogum
      )
    );
  END IF;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  IF p_ek_uygulamalar IS NOT NULL AND jsonb_array_length(p_ek_uygulamalar) > 0 THEN
    FOR v_ek IN SELECT * FROM jsonb_array_elements(p_ek_uygulamalar) LOOP
      IF (v_ek->>'stok_id') IS NOT NULL AND (v_ek->>'stok_id') <> '' THEN
        v_ek_stok := (v_ek->>'stok_id')::uuid;
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
        VALUES (
          v_ek_stok,
          'Tohumlama',
          COALESCE((v_ek->>'doz')::numeric, 1),
          'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
          false
        );
      END IF;
    END LOOP;
  END IF;

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
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) TO anon, authenticated;
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
-- 0. STOK_KATEGORİLERİ — Dinamik kategori tanımları
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stok_kategorileri (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad         text UNIQUE NOT NULL,
  sira       integer DEFAULT 0,
  tip        text NOT NULL DEFAULT 'genel',
  created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.stok_kategorileri IS 'Stok kategori tanımları — tip: ilac|genel, Tanımlar panelinden yönetilir';
ALTER TABLE public.stok_kategorileri ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stok_kategorileri' AND policyname='stok_kat_select') THEN
    CREATE POLICY stok_kat_select ON public.stok_kategorileri FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stok_kategorileri' AND policyname='stok_kat_all') THEN
    CREATE POLICY stok_kat_all ON public.stok_kategorileri FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
INSERT INTO public.stok_kategorileri (ad, sira, tip) VALUES
  ('Antibiyotik',1,'ilac'),('NSAID',2,'ilac'),('Hormon',3,'ilac'),('Vitamin',4,'ilac'),
  ('Antiparaziter',5,'ilac'),('Diğer İlaç',6,'ilac'),('Aşı',7,'genel'),('Sperma',8,'genel'),
  ('Yem',9,'genel'),('Sarf',10,'genel'),('Ekipman',11,'genel'),('Diğer',12,'genel'),
  ('Tohumlama',13,'genel'),('Metabolik',14,'ilac'),('GI İlaçlar',15,'ilac'),
  ('Topikal',16,'ilac'),('Anestezik / Sedatif',17,'ilac')
ON CONFLICT (ad) DO NOTHING;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stok_kategorileri TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 0a. DRUG_CLASSES — Etken madde sınıflandırma (3-seviye: group → class → ingredient)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_classes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_name        text NOT NULL,
  class_name        text,
  active_ingredient text,
  kategori_id       uuid REFERENCES public.stok_kategorileri(id),
  created_at        timestamptz DEFAULT now(),
  CONSTRAINT uq_drug_classes_combo UNIQUE (group_name, class_name, active_ingredient)
);

COMMENT ON TABLE  public.drug_classes IS 'Veteriner farmakoloji etken madde sınıflandırması — group_name → class_name → active_ingredient';
COMMENT ON COLUMN public.drug_classes.kategori_id IS 'stok_kategorileri FK — otomatik kategori eşleme';

ALTER TABLE public.drug_classes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_classes' AND policyname='anon_read_drug_classes') THEN
    CREATE POLICY anon_read_drug_classes ON public.drug_classes FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_classes' AND policyname='anon_insert_drug_classes') THEN
    CREATE POLICY anon_insert_drug_classes ON public.drug_classes FOR INSERT WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.drug_classes TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 0b. DRUG_PRODUCTS — Ticari preparat (brand_name + drug_class_id FK)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_products (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drug_class_id      uuid NOT NULL REFERENCES public.drug_classes(id),
  brand_name         text NOT NULL,
  concentration      numeric,
  concentration_unit text,
  default_route      text,
  default_unit       text,
  created_at         timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_drug_products_brand_class
  ON drug_products (LOWER(brand_name), drug_class_id);

COMMENT ON TABLE  public.drug_products IS 'Ticari ilaç preparatları — drug_classes FK ile sınıflandırılır';

ALTER TABLE public.drug_products ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_products' AND policyname='anon_read_drug_products') THEN
    CREATE POLICY anon_read_drug_products ON public.drug_products FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_products' AND policyname='anon_insert_drug_products') THEN
    CREATE POLICY anon_insert_drug_products ON public.drug_products FOR INSERT WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.drug_products TO anon, authenticated;

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
  kategori       text,
  created_at     timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.drugs                IS 'Controlled ilaç listesi — free text yasak';
COMMENT ON COLUMN public.drugs.stock_item_id  IS 'stok.id FK — NULL ise stok düşümü yapılmaz';
COMMENT ON COLUMN public.drugs.default_route  IS 'IM | IV | SC | PO | Topikal | Intrauterin';
COMMENT ON COLUMN public.drugs.kategori       IS 'İlaç sınıfı — stok_kategorileri.ad (tip=ilac) ile eşleşir';

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
  plan_notu   text,
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

-- done tracking (migration 20260525000002)
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS tamamlandi         boolean     DEFAULT false,
  ADD COLUMN IF NOT EXISTS tamamlanma_tarihi  timestamptz,
  ADD COLUMN IF NOT EXISTS tamamlanma_notu    text;

-- planned_time (migration 20260528000001)
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS planned_time TIME;

-- ──────────────────────────────────────────────────────────────
-- 5. DRUG ADMINISTRATIONS — İlaç uygulama (controlled FK)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_administrations (
  id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id  uuid    NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  stok_id           text    REFERENCES public.stok(id),
  drug_product_id   uuid    REFERENCES public.drug_products(id),
  dose              numeric NOT NULL CHECK (dose > 0),
  unit              text    NOT NULL,
  route             text,
  notes             text,
  uygulanmadi       boolean DEFAULT false,
  created_at        timestamptz DEFAULT now(),
  CONSTRAINT drug_administrations_route_check
    CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin'))
);

COMMENT ON TABLE  public.drug_administrations  IS 'İlaç uygulama — stok_id + drug_product_id FK (drug_id kaldırıldı)';
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
-- 7. TRIGGER: drug_administration → stok_hareket (KALDIRILDI)
--
-- stok hareketi artık RPC içinde yapılıyor:
--   add_drug_administration() → kendisi INSERT INTO stok_hareket
--   delete_treatment_day()    → UPDATE stok_hareket SET iptal=true
--   geri_al()                 → UPDATE stok_hareket SET iptal=true
-- Trigger kaldırıldı çünkü drug_id kolonu yok (stok_id + drug_product_id kullanılıyor)
-- ──────────────────────────────────────────────────────────────
-- Trigger kaldırıldı: stok hareketi add_drug_administration RPC içinde yapılıyor
CREATE OR REPLACE FUNCTION public.drug_administration_stok_dusum()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- This trigger is disabled. Stock ledger is handled by RPC.
  RETURN NEW;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 8. VIEW: treatment_timeline
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.treatment_timeline CASCADE;
CREATE VIEW public.treatment_timeline AS
SELECT
  h.id            AS animal_id,
  h.kupe_no,
  c.id            AS case_id,
  c.status        AS case_status,
  c.start_date    AS case_start,
  dis.name        AS disease,
  dis.category    AS disease_category,
  td.id           AS day_id,
  td.day_no,
  td.treatment_date,
  dp.id           AS drug_id,
  COALESCE(dp.brand_name, s.urun_adi, '?'::text) AS drug,
  da.id           AS administration_id,
  da.dose,
  da.unit,
  da.route,
  da.notes        AS admin_notes,
  da.stok_id,
  td.treatment_time
FROM public.treatment_days td
JOIN public.cases                c   ON c.id   = td.case_id
JOIN public.hayvanlar            h   ON h.id   = c.animal_id
JOIN public.diseases             dis ON dis.id = c.disease_id
LEFT JOIN public.drug_administrations da ON da.treatment_day_id = td.id
LEFT JOIN public.drug_products       dp ON dp.id = da.drug_product_id
LEFT JOIN public.stok                s  ON s.id  = da.stok_id;

COMMENT ON VIEW public.treatment_timeline IS 'Vaka → gün → ilaç timeline (drug_products + stok), frontend için hazır';

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

  -- islem_log: geri alma icin snapshot
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'VAKA_ACILDI',
    p_animal_id,
    v_new_id::text,
    'cases',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'cases', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$$;

-- Kızgınlık bağlamından vaka açma RPC (Plan-B)
CREATE OR REPLACE FUNCTION public.kizginlik_vaka_ac(
  p_kizginlik_id   text,
  p_tani           text,
  p_tohumlama_id   text    DEFAULT NULL,
  p_notlar         text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_kiz       record;
  v_case_id   uuid;
  v_disease   record;
BEGIN
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- Hastalık adından disease_id bul (case-insensitive)
  SELECT * INTO v_disease FROM public.diseases
  WHERE name ILIKE p_tani OR p_tani ILIKE '%' || name || '%'
  ORDER BY length(name) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.diseases (name, category)
    VALUES (p_tani, 'Üreme')
    RETURNING * INTO v_disease;
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, start_date, status, notes, created_at)
  VALUES (
    v_kiz.hayvan_id,
    v_disease.id,
    CURRENT_DATE,
    'active',
    COALESCE(p_notlar, 'Tohumlama sırasında tespit edildi'),
    now()
  )
  RETURNING id INTO v_case_id;

  UPDATE public.kizginlik_log
  SET tedavi_case_id = v_case_id
  WHERE id = p_kizginlik_id;

  IF p_tohumlama_id IS NOT NULL AND p_tohumlama_id <> '' THEN
    UPDATE public.tohumlama
    SET case_id = v_case_id
    WHERE id = p_tohumlama_id;
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'KIZGINLIK_VAKA_ACILDI',
    v_kiz.hayvan_id,
    p_kizginlik_id,
    'kizginlik_log',
    jsonb_build_object(
      'case_id', v_case_id,
      'tani', p_tani,
      'kizginlik_id', p_kizginlik_id,
      'tohumlama_id', p_tohumlama_id
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text) TO anon, authenticated;

-- 9b. add_treatment_day
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date);
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date, time);
CREATE OR REPLACE FUNCTION public.add_treatment_day(
  p_case_id      uuid,
  p_date         date,
  p_planned_time time DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id        uuid;
  v_gorev_id      uuid;
  v_prev_gorev_id uuid := NULL;
  v_day_no        int;
  v_case          record;
  v_gecmis        boolean;
BEGIN
  SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
  FROM public.treatment_days
  WHERE case_id = p_case_id;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya gün eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  -- Zincir: önceki günün gorev_log ID'sini bul
  IF v_day_no > 1 THEN
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id
      AND td.day_no  = v_day_no - 1
      AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  INSERT INTO public.treatment_days(id, case_id, day_no, treatment_date, tamamlandi, tamamlanma_tarihi, planned_time)
  VALUES (
    gen_random_uuid(), p_case_id, v_day_no, p_date,
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
    p_planned_time
  )
  RETURNING id INTO v_day_id;

  INSERT INTO public.gorev_log(
    id, gorev_tipi, hayvan_id, hedef_tarih, aciklama,
    tamamlandi, tamamlanma_tarihi, parent_id
  )
  VALUES (
    gen_random_uuid(),
    'TEDAVI_GUN',
    v_case.animal_id,
    p_date,
    jsonb_build_object(
      'day_id',       v_day_id,
      'gun_no',       v_day_no,
      'label',        'Gün ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY'),
      'planned_time', COALESCE(p_planned_time::text, '')
    )::text,
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
    v_prev_gorev_id  -- NULL = ilk gün, dolu = önceki günün gorev_id
  )
  RETURNING id INTO v_gorev_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'TEDAVI_GUN_EKLENDI',
    v_case.animal_id,
    v_day_id::text,
    'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log',      'id', v_gorev_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'day_id', v_day_id, 'day_no', v_day_no, 'gecmis', v_gecmis);
END;
$$;

-- 9c. add_drug_administration (stok_id + drug_product_id — drug_id kaldırıldı)
DROP FUNCTION IF EXISTS public.add_drug_administration(uuid, text, uuid, numeric, text, text);
CREATE OR REPLACE FUNCTION public.add_drug_administration(
  p_day_id           uuid,
  p_stok_id          text,
  p_drug_product_id  uuid,
  p_dose             numeric,
  p_unit             text,
  p_route            text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.drug_administrations (treatment_day_id, drug_product_id, stok_id, dose, unit, route)
  VALUES (p_day_id, p_drug_product_id, p_stok_id, p_dose, p_unit, p_route)
  RETURNING id INTO v_id;

  IF p_stok_id IS NOT NULL AND p_dose > 0 THEN
    INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
    VALUES (p_stok_id, 'Tedavi', p_dose, 'drug_admin:' || v_id::text);
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
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

-- 9e. treatment_day_tamamla
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text);
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);
CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_day       public.treatment_days%ROWTYPE;
  v_onceki    boolean;
  v_admin_id  uuid;
  v_stok_id   text;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;

  IF v_day.tamamlandi THEN
    RAISE EXCEPTION 'Bu tedavi günü zaten tamamlandı';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id
      AND day_no  < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;

  IF v_onceki THEN
    RAISE EXCEPTION 'Önceki tedavi günleri tamamlanmadan bu gün tamamlanamaz';
  END IF;

  UPDATE public.treatment_days
  SET tamamlandi        = true,
      tamamlanma_tarihi = now(),
      tamamlanma_notu   = p_not
  WHERE id = p_day_id;

  -- YENİ: Uygulanmayan ilaçlar — uygulanmadi=true + stok iadesi --
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id
      RETURNING stok_id INTO v_stok_id;

      IF v_stok_id IS NOT NULL THEN
        UPDATE public.stok_hareket
        SET iptal = true
        WHERE notlar = 'drug_admin:' || v_admin_id::text
          AND iptal = false;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

-- 9f. treatment_day_not_guncelle
DROP FUNCTION IF EXISTS public.treatment_day_not_guncelle(uuid, text);
CREATE OR REPLACE FUNCTION public.treatment_day_not_guncelle(
  p_day_id  uuid,
  p_notes   text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.treatment_days
  SET notes = p_notes
  WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;
END;
$$;

-- 9g. case_plan_notu_guncelle
CREATE OR REPLACE FUNCTION public.case_plan_notu_guncelle(
  p_case_id   uuid,
  p_plan_notu text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.cases
  SET plan_notu = p_plan_notu
  WHERE id = p_case_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vaka bulunamadı: %', p_case_id;
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
GRANT EXECUTE ON FUNCTION public.add_drug_administration(uuid, text, uuid, numeric, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.close_case              TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla   TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.treatment_day_not_guncelle TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.case_plan_notu_guncelle(uuid, text) TO anon, authenticated;

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
INSERT INTO public.drugs (name, default_unit, default_route, kategori) VALUES
  ('Enrofloksasin',    'ml',  'IM', 'Antibiyotik'),
  ('Oksitetrasiklin',  'ml',  'IM', 'Antibiyotik'),
  ('Penisilin',        'ml',  'IM', 'Antibiyotik'),
  ('Makrovil',         'ml',  'IM', 'Antibiyotik'),
  ('Enrolen',          'ml',  'IM', 'Antibiyotik'),
  ('Florkem',          'ml',  'IM', 'Antibiyotik'),
  ('Meloksikam',       'ml',  'IV', 'NSAID'),
  ('Ketoprofen',       'ml',  'IM', 'NSAID'),
  ('Flunixin',         'ml',  'IV', 'NSAID'),
  ('Deksametazon',     'ml',  'IM', 'Kortikosteroid'),
  ('B Kompleks',       'ml',  'IM', 'Vitamin'),
  ('B12 Vitamini',     'ml',  'IM', 'Vitamin'),
  ('AD3E Vitamini',    'ml',  'IM', 'Vitamin'),
  ('Vitamin AD3E',     'ml',  'IM', 'Vitamin'),
  ('Vitamin C',        'ml',  'IV', 'Vitamin'),
  ('Kalsiyum Boroglukonat', 'ml', 'IV', 'Metabolik'),
  ('Magnezyum Sülfat', 'ml',  'IV', 'Metabolik'),
  ('Glukoz %50',       'ml',  'IV', 'Metabolik'),
  ('Elektrolit',       'gr',  'PO', 'Metabolik'),
  ('Rumen Stimülanı',  'ml',  'PO', 'Metabolik'),
  ('Oksitoksin',       'ml',  'IM', 'Hormon'),
  ('Progesteron',      'ml',  'IM', 'Hormon'),
  ('GnRH',             'ml',  'IM', 'Hormon'),
  ('PGF2α',            'ml',  'IM', 'Hormon'),
  ('Albendazol',       'ml',  'PO', 'Antiparaziter'),
  ('İvermektin',       'ml',  'SC', 'Antiparaziter')
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

  -- Bağlı stok_hareket satırlarını iptal et
  -- add_drug_administration: notlar='drug_admin:{id}'
  -- update_drug_administration delta: notlar='drug_admin:{id}:duz:*'
  UPDATE public.stok_hareket
  SET    iptal = true
  WHERE  notlar LIKE 'drug_admin:' || p_admin_id::text || '%'
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

-- ── 3. dogum_kaydet — etken_kod'lu + 10 anne görevi (gorev_sayisi 17) ─
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
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı');
  END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE kupe_no = p_kupe OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe);
  END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi
    FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe'
    ORDER BY tarih DESC LIMIT 1;
  ELSE
    v_baba_bilgi := p_baba;
  END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi);

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  UPDATE public.hayvanlar
  SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok'
  WHERE id = p_anne_id;

  -- Anne protokol görevleri (10 görev — etken_kod ile)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih, false, 'DOGUM-' || p_anne_id, 'OKSITOSIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih, false, 'DOGUM-' || p_anne_id, 'KALSIYUM'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '11. Gün PG',            p_tarih + 11, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Ademin',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Yeldif',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '54. Gün: Yeldif',       p_tarih + 54, false, 'DOGUM-' || p_anne_id, 'E_VIT'),
    (gen_random_uuid(), p_anne_id, 'DIGER', '⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL);

  -- Buzağı ana görev
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'DOGUM-' || p_anne_id);

  -- Buzağı alt görevler (6 görev)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id);

  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 17,
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
  SELECT snapshot INTO v_snapshot
  FROM islem_log
  WHERE id = p_islem_id;

  IF v_snapshot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'islem bulunamadi');
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';

    IF v_tablo = 'treatment_days' THEN
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        WHERE da.treatment_day_id = v_pk::uuid
      );
      DELETE FROM public.treatment_days WHERE id = v_pk::uuid;

    ELSIF v_tablo = 'cases' THEN
      DELETE FROM public.gorev_log g
      WHERE g.gorev_tipi = 'TEDAVI_GUN'
        AND EXISTS (
          SELECT 1 FROM public.treatment_days td
          WHERE td.case_id = v_pk::uuid
            AND g.aciklama IS NOT NULL
            AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
        );

      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        JOIN public.treatment_days td ON da.treatment_day_id = td.id
        WHERE td.case_id = v_pk::uuid
      );

      DELETE FROM public.cases WHERE id = v_pk::uuid;

    ELSE
      BEGIN
        EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
      EXCEPTION WHEN others THEN
        EXECUTE format('DELETE FROM %I WHERE id = $1::uuid', v_tablo) USING v_pk;
      END;
    END IF;
  END LOOP;

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

  UPDATE islem_log SET durum = 'geri_alindi' WHERE id = p_islem_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.geri_al(text) TO anon, authenticated;
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
  v_hayvan      record;
  v_yas_gun     integer;
  v_deneme      integer;
  v_toh_id      uuid := gen_random_uuid();
  v_gorev1_id   uuid := gen_random_uuid();
  v_gorev2_id   uuid := gen_random_uuid();
  v_islem_id    text := gen_random_uuid()::text;
  v_stok_id     uuid;
  v_gebe_toh    record;
  v_uyari       text := NULL;
  v_auto_close  boolean := false;
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

  -- Gebe kontrolü: 260+ gün auto-close, <260 gün blok
  SELECT * INTO v_gebe_toh FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ORDER BY tarih DESC LIMIT 1;

  IF FOUND THEN
    IF (CURRENT_DATE - v_gebe_toh.tarih::date) > 260 THEN
      -- Auto-close: 260 günü geçmiş gebelik otomatik kapatılır
      UPDATE public.tohumlama
      SET sonuc = 'Doğum Yaptı'
      WHERE id = v_gebe_toh.id;

      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
      VALUES (
        gen_random_uuid()::text,
        'DOGUM_OTOMATIK',
        p_hayvan_id,
        v_gebe_toh.id::text,
        'tohumlama',
        jsonb_build_object(
          'olusturulan', '[]'::jsonb,
          'guncellenen', jsonb_build_array(
            jsonb_build_object(
              'tablo', 'tohumlama',
              'id', v_gebe_toh.id::text,
              'degisim', 'sonuc: Gebe → Doğum Yaptı'
            )
          )
        )
      );

      v_uyari := '260+ günlük gebelik otomatik kapatıldı (Doğum Yaptı). Yeni tohumlama kaydediliyor.';
      v_auto_close := true;
      -- Devam et — yeni tohumlama kaydedilecek
    ELSE
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan zaten gebe — önce gebeliği kapatın');
    END IF;
  END IF;

  -- Önceki Bekliyor tohumlamaları Boş yap (event stack kuralı)
  UPDATE public.tohumlama
  SET sonuc = 'Boş'
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor';

  -- Deneme no: per-cycle (son Doğum/Abort sonrası tohumlama sayısı)
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND tarih > COALESCE(
      (SELECT MAX(tarih) FROM public.tohumlama
       WHERE hayvan_id = p_hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
      '1900-01-01'::date
    );

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

  -- islem_log
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

  RETURN jsonb_build_object(
    'ok', true,
    'tohumlama_id', v_toh_id,
    'deneme_no', v_deneme,
    'islem_id', v_islem_id,
    'uyari', v_uyari
  );
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
-- Migration: Tohumlama sonuç RPC'leri — Boş ve Bekliyor durumları
-- Etkiler: Yeni RPC'ler: tohumlama_sonuc_bos, tohumlama_sonuc_bekliyor
--          Tablolar: tohumlama, hayvanlar, islem_log
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_bos(text); DROP FUNCTION tohumlama_sonuc_bekliyor(text);

BEGIN;

-- 1. tohumlama_sonuc_bos: Tohumlama sonucu Boş yap
--    - Tohumlama sonucu 'Bekliyor' → 'Boş' güncelle
--    - Hayvanlar.tohumlama_durumu → 'Boş' yap
--    - islem_log kaydı ekle (geri alınabilir)

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh             record;
  v_islem_id        text := gen_random_uuid()::text;
  v_onceki_durum    text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Sadece Bekliyor durumundaki tohumlama Boş yapılabilir
  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama Boş yapılabilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  -- AND durum = 'Aktif' guard: pasif/ölü hayvan işlemi engellensin
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucu Boş yap
  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;

  -- Hayvanlar.tohumlama_durumu Boş yap
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Boş'
  WHERE id = v_toh.hayvan_id;

  -- islem_log: değişikliği geri alınabilir hale getir
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'BOS_ATAMA',
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

-- 2. tohumlama_sonuc_bekliyor: Hatalı tohumlama kaydını Bekliyor'a al ve önceki duruma dön
--    - Tohumlama sonucu 'Gebe' veya diğer → 'Bekliyor' güncelle
--    - Hayvanlar.tohumlama_durumu → önceki duruma dön
--    - islem_log kaydı ekle (geri alınabilir)
--    Not: Bu genellikle sistem hatası veya operatör hatasını düzeltmek için kullanılır

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bekliyor(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh             record;
  v_islem_id        text := gen_random_uuid()::text;
  v_onceki_durum    text;
  v_onceki_toh_sonuc text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Sadece Gebe veya Boş durumundaki tohumlama Bekliyor yapılabilir
  -- (Doğum Yaptı ve Abort değiştirilemez — domain kuralı)
  IF v_toh.sonuc NOT IN ('Gebe', 'Boş') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe veya Boş durumundaki tohumlama Bekliyor yapılabilir');
  END IF;

  -- Hayvanın mevcut tohumlama_durumu kaydet (geri alınabilmesi için)
  -- AND durum = 'Aktif' guard: pasif/ölü hayvan işlemi engellensin
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucu önceki değerini kaydet
  v_onceki_toh_sonuc := v_toh.sonuc;

  -- Tohumlama sonucu Bekliyor yap
  UPDATE public.tohumlama SET sonuc = 'Bekliyor' WHERE id::text = p_tohumlama_id;

  -- Hayvanlar.tohumlama_durumu 'Tohumlanabilir' haline getir
  -- (Bu, sistem hatası düzeltme işlemi olduğundan, güvenli default olarak tohumlanabilir yapıyoruz)
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Tohumlanabilir'
  WHERE id = v_toh.hayvan_id;

  -- islem_log: değişikliği geri alınabilir hale getir
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'BEKLIYOR_ATAMA',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_onceki_toh_sonuc)
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
-- Bu migration Gwen tarafından 2026-03-27 19:58:14'te direkt DB'ye uygulandı.
-- Dosya oluşturulmadan DB'ye basıldığı için CI/CD version uyuşmazlığı oluştu.
-- İçerik remote DB'de mevcut — bu dosya sadece supabase migration history
-- ile local dosya listesini eşleştirmek için oluşturuldu.
-- Gerçek içeriği görmek için: supabase db pull veya migration history tablosunu sorgula.
-- Migration: tohumlama sonuç RPCs — tohumlama_sonuc_bos + tohumlama_abort
-- Etkiler: tohumlama_sonuc_bos RPC (yeni), tohumlama_abort RPC (yeni)
--          Tablolar: tohumlama, hayvanlar, islem_log
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_bos(text,text);
--                          DROP FUNCTION tohumlama_abort(text,text);

BEGIN;

-- 1. tohumlama_sonuc_bos: Tohumlama sonucunu "Boş" olarak işaretle
--    - Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir
--    - hayvanlar.tohumlama_durumu günceller (Boş'a döner)
--    - islem_log'a guncellenen snapshot ile kaydeder (geri alınabilir)

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh          record;
  v_islem_id     text := gen_random_uuid()::text;
  v_onceki_durum text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id::uuid
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucunu Boş yap
  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;

  -- Hayvanın tohumlama_durumu güncelle
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Boş'
  WHERE id = v_toh.hayvan_id::uuid;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA_SONUC',
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
      ),
      'notlar', p_notlar
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

-- 2. tohumlama_abort: Abort / erken doğum kaydı
--    - Sadece Gebe durumundaki tohumlama abort edilebilir
--    - tohumlama.sonuc = 'Abort' olarak günceller
--    - hayvanlar.tohumlama_durumu ve tohumlama_onay_tarihi sıfırlar
--    - islem_log'a guncellenen snapshot ile kaydeder (geri alınabilir)

CREATE OR REPLACE FUNCTION public.tohumlama_abort(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh           record;
  v_islem_id      text := gen_random_uuid()::text;
  v_onceki_durum  text;
  v_onceki_tarih  date;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Gebe' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe durumundaki tohumlama abort edilebilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  SELECT tohumlama_durumu, tohumlama_onay_tarihi INTO v_onceki_durum, v_onceki_tarih
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id::uuid
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucunu Abort yap
  UPDATE public.tohumlama
  SET sonuc = 'Abort', abort_notlar = p_notlar
  WHERE id::text = p_tohumlama_id;

  -- Hayvanın tohumlama_durumu ve onay tarihini sıfırla
  UPDATE public.hayvanlar
  SET tohumlama_durumu = NULL,
      tohumlama_onay_tarihi = NULL
  WHERE id = v_toh.hayvan_id::uuid;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ABORT_KAYDI',
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
          'onceki', jsonb_build_object(
            'tohumlama_durumu', v_onceki_durum,
            'tohumlama_onay_tarihi', v_onceki_tarih
          )
        )
      ),
      'notlar', p_notlar
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
-- Migration: Agent DB Telemetry Publication
-- Tarih: 2026-03-31
-- Açıklama: Gwen agent'ın DB değişikliklerini izlemesi için CDC publication
-- Geri alınabilir: evet — DROP PUBLICATION gwen_db_watch;

BEGIN;

-- Mevcut publication'ı temizle
DROP PUBLICATION IF EXISTS gwen_db_watch;

-- Agent için publication oluştur
-- Kritik tablolar: islem_log, stok_hareket, gorev_log, hayvanlar
CREATE PUBLICATION gwen_db_watch FOR TABLE 
  public.islem_log, 
  public.stok_hareket, 
  public.gorev_log,
  public.hayvanlar;

-- Realtime replication'i aktif et
ALTER PUBLICATION gwen_db_watch 
  SET (publish = 'insert, update, delete');

COMMIT;

-- Doğrulama
SELECT pubname, puballtables 
FROM pg_publication 
WHERE pubname = 'gwen_db_watch';
-- Migration: Aşılama Modülü — Controlled vaccine entity + protocol + log
-- Etkiler: vaccines tablosu, vaccination_schedule, vaccination_log, RPC'ler
--          gorev_log ile entegrasyon (otomatik aşı görevleri)
-- Geri alınabilir: evet — DROP TABLE vaccination_log, vaccination_schedule, vaccines

BEGIN;

-- ══════════════════════════════════════════════════════════════
-- 1. VACCINES — Controlled aşı listesi
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vaccines (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text        UNIQUE NOT NULL,
  disease_target      text,                    -- Hangi hastalığa karşı
  dose                numeric     NOT NULL,    -- Standart doz
  unit                text        NOT NULL,    -- ml, gr, vb.
  route               text        NOT NULL,    -- IM, SC, PO, vb.
  repeat_interval_days integer,                -- Tekrar aralığı (gün)
  is_mandatory        boolean     DEFAULT true, -- Zorunlu aşı mı?
  stock_item_id       text        REFERENCES public.stok(id) ON DELETE SET NULL,
  created_at          timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.vaccines           IS 'Controlled aşı listesi — free text yasak';
COMMENT ON COLUMN public.vaccines.disease_target IS 'Hedef hastalık (örn: Şarbon, BVD, IBR)';
COMMENT ON COLUMN public.vaccines.repeat_interval_days IS 'Yıllık=365, 6 aylık=180, vb. NULL=tek doz';
COMMENT ON COLUMN public.vaccines.stock_item_id IS 'stok.id FK — NULL ise stok düşümü yapılmaz';

-- ══════════════════════════════════════════════════════════════
-- 2. VACCINATION_SCHEDULE — Aşı protokol tanımları
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vaccination_schedule (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  vaccine_id          uuid        NOT NULL REFERENCES public.vaccines(id) ON DELETE CASCADE,
  target_type         text        NOT NULL,    -- 'buzağı' | 'düve' | 'inek' | 'tüm'
  timing_type         text        NOT NULL,    -- 'yas' | 'gebelik' | 'dogum_sonra'
  timing_days         integer,                 -- Doğumdan/gébelenen kaç gün sonra
  sequence_order      integer,                 -- Protokol sırası (1,2,3...)
  notes               text,
  created_at          timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.vaccination_schedule IS 'Aşı protokol tanımları — otomatik görev üretimi için';
COMMENT ON COLUMN public.vaccination_schedule.target_type IS 'Hedef grup: buzağı | düve | inek | tüm';
COMMENT ON COLUMN public.vaccination_schedule.timing_type IS 'Zamanlama: yas (doğumdan) | gebelik (gebelikten) | dogum_sonra';
COMMENT ON COLUMN public.vaccination_schedule.timing_days IS 'Zamanlama günü (timing_type''a göre)';
COMMENT ON COLUMN public.vaccination_schedule.sequence_order IS 'Protokol sırası — 1=ilk aşı, 2=ikinci aşı';

CREATE INDEX IF NOT EXISTS vac_schedule_vaccine_id_idx ON public.vaccination_schedule(vaccine_id);

-- ══════════════════════════════════════════════════════════════
-- 3. VACCINATION_LOG — Yapılan aşı kayıtları
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vaccination_log (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  animal_id           text        NOT NULL REFERENCES public.hayvanlar(id),
  vaccine_id          uuid        NOT NULL REFERENCES public.vaccines(id),
  vaccination_date    date        NOT NULL DEFAULT CURRENT_DATE,
  dose_given          numeric     NOT NULL,
  unit                text        NOT NULL,
  route               text        NOT NULL,
  next_due_date       date,                    -- Bir sonraki aşı tarihi
  notes               text,
  created_at          timestamptz DEFAULT now(),
  created_by          text                     -- Kullanıcı ID (opsiyonel)
);

COMMENT ON TABLE  public.vaccination_log IS 'Yapılan aşı kayıtları — hayvan başına aşı geçmişi';
COMMENT ON COLUMN public.vaccination_log.next_due_date IS 'repeat_interval_days + vaccination_date';

CREATE INDEX IF NOT EXISTS vac_log_animal_id_idx ON public.vaccination_log(animal_id);
CREATE INDEX IF NOT EXISTS vac_log_vaccine_id_idx ON public.vaccination_log(vaccine_id);
CREATE INDEX IF NOT EXISTS vac_log_date_idx ON public.vaccination_log(vaccination_date);

-- ══════════════════════════════════════════════════════════════
-- 4. TRIGGER: vaccination_log → stok_hareket (ledger)
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.vaccination_stok_dusum()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id   text;
  v_vaccine_name text;
  v_kupe_no   text;
  v_guncel    numeric;
BEGIN
  -- Aşının stok bağlantısını kontrol et
  SELECT v.stock_item_id, v.name
  INTO   v_stok_id, v_vaccine_name
  FROM   public.vaccines v
  WHERE  v.id = NEW.vaccine_id;

  -- Stok bağlantısı yoksa ledger kaydı yapmadan geç
  IF v_stok_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Hayvan küpe no'sunu bul (notlar için)
  SELECT kupe_no INTO v_kupe_no
  FROM   public.hayvanlar
  WHERE  id = NEW.animal_id;

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

  IF v_guncel < NEW.dose_given THEN
    RAISE EXCEPTION 'Yetersiz stok: % (mevcut: %, istenen: %)',
      v_vaccine_name, v_guncel, NEW.dose_given;
  END IF;

  -- Ledger: pozitif = kullanım
  INSERT INTO public.stok_hareket (
    stok_id, tur, miktar, notlar, iptal,
    referans_tipi, referans_id
  ) VALUES (
    v_stok_id,
    'Aşı',
    NEW.dose_given,
    v_vaccine_name || ' — ' || COALESCE(v_kupe_no, NEW.animal_id),
    false,
    'vaccination',
    NEW.id::text
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vaccination_stok ON public.vaccination_log;
CREATE TRIGGER trg_vaccination_stok
  AFTER INSERT ON public.vaccination_log
  FOR EACH ROW EXECUTE FUNCTION public.vaccination_stok_dusum();

-- ══════════════════════════════════════════════════════════════
-- 5. RPC: add_vaccination — Aşı uygula + stok düş + görev üret
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.add_vaccination(
  p_animal_id     text,
  p_vaccine_id    uuid,
  p_date          date    DEFAULT CURRENT_DATE,
  p_dose_override numeric DEFAULT NULL,  -- NULL ise vaccine.dose kullan
  p_notes         text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_vaccine     record;
  v_new_id      uuid;
  v_next_due    date;
  v_dose        numeric;
  v_animal      record;
  v_islem_id    text := gen_random_uuid()::text;
BEGIN
  -- Hayvan kontrolü
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  -- Aşı bilgilerini al
  SELECT * INTO v_vaccine FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşı kaydı bulunamadı');
  END IF;

  -- Doz belirle (override veya default)
  v_dose := COALESCE(p_dose_override, v_vaccine.dose);

  -- Bir sonraki aşı tarihi (tekrar aralığı varsa)
  IF v_vaccine.repeat_interval_days IS NOT NULL THEN
    v_next_due := p_date + (v_vaccine.repeat_interval_days || ' days')::interval;
  END IF;

  -- Aşı kaydı oluştur
  INSERT INTO public.vaccination_log (
    animal_id, vaccine_id, vaccination_date, dose_given, unit, route, next_due_date, notes
  ) VALUES (
    p_animal_id, p_vaccine_id, p_date, v_dose,
    v_vaccine.unit, v_vaccine.route, v_next_due, p_notes
  )
  RETURNING id INTO v_new_id;

  -- Otomatik görev üret (bir sonraki aşı hatırlatması)
  IF v_next_due IS NOT NULL THEN
    INSERT INTO public.gorev_log (
      hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi
    ) VALUES (
      p_animal_id,
      'ASI_HATIRLATMA',
      v_vaccine.name || ' — Tekrar dozu',
      v_next_due,
      false
    );
  END IF;

  -- islem_log kaydı (geri al için)
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ASI_KAYDI',
    p_animal_id,
    v_new_id::text,
    'vaccination_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'vaccination_log', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb,
      'vaccine_name', v_vaccine.name,
      'next_due', v_next_due
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_new_id,
    'next_due', v_next_due,
    'islem_id', v_islem_id
  );
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- 6. RPC: get_vaccination_schedule — Hayvan için protokol öner
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_vaccination_schedule(
  p_animal_id text
) RETURNS TABLE(
  vaccine_id        uuid,
  vaccine_name      text,
  disease_target    text,
  dose              numeric,
  unit              text,
  route             text,
  schedule_date     date,
  is_due            boolean,
  notes             text
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_animal        record;
  v_birth_date    date;
  v_today         date := CURRENT_DATE;
  v_age_days      integer;
  v_schedule_rec  record;
  v_last_vac_date date;
BEGIN
  -- Hayvan bilgilerini al
  SELECT * INTO v_animal
  FROM public.hayvanlar
  WHERE id = p_animal_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_birth_date := v_animal.dogum_tarihi;
  v_age_days := CASE
    WHEN v_birth_date IS NOT NULL
    THEN v_today - v_birth_date
    ELSE 0
  END;

  -- Her aşı protokolü için
  FOR v_schedule_rec IN
    SELECT vs.*, v.name as vaccine_name, v.disease_target, v.dose, v.unit, v.route
    FROM public.vaccination_schedule vs
    JOIN public.vaccines v ON v.id = vs.vaccine_id
    WHERE vs.target_type IN ('tüm', v_animal.cinsiyet,
      CASE WHEN v_animal.cinsiyet = 'Dişi' AND v_animal.yas_gun < 365 THEN 'buzağı'
           WHEN v_animal.cinsiyet = 'Dişi' AND v_animal.yas_gun < 730 THEN 'düve'
           ELSE 'inek' END)
    ORDER BY vs.sequence_order
  LOOP
    -- Zamanlama tipi göre tarih hesapla
    IF v_schedule_rec.timing_type = 'yas' AND v_birth_date IS NOT NULL THEN
      schedule_date := v_birth_date + (v_schedule_rec.timing_days || ' days')::interval;
    ELSIF v_schedule_rec.timing_type = 'dogum_sonra' THEN
      -- Son doğum tarihini bul
      SELECT MAX(tarih) INTO v_last_vac_date
      FROM public.dogum
      WHERE hayvan_id = p_animal_id;
      
      IF v_last_vac_date IS NOT NULL THEN
        schedule_date := v_last_vac_date + (v_schedule_rec.timing_days || ' days')::interval;
      ELSE
        CONTINUE; -- Doğum yoksa bu protokolü atla
      END IF;
    ELSE
      CONTINUE; -- Diğer timing_type'lar henüz implement değil
    END IF;

    -- Geçmiş mi, gelecek mi?
    is_due := schedule_date <= v_today;

    vaccine_id := v_schedule_rec.vaccine_id;
    vaccine_name := v_schedule_rec.vaccine_name;
    disease_target := v_schedule_rec.disease_target;
    dose := v_schedule_rec.dose;
    unit := v_schedule_rec.unit;
    route := v_schedule_rec.route;
    notes := v_schedule_rec.notes;

    RETURN NEXT;
  END LOOP;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- 7. RPC: list_vaccinations — Hayvan aşı geçmişi
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.list_vaccinations(
  p_animal_id text
) RETURNS TABLE(
  id              uuid,
  vaccine_name    text,
  disease_target  text,
  vaccination_date date,
  dose_given      numeric,
  unit            text,
  route           text,
  next_due_date   date,
  notes           text
) LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN QUERY
  SELECT
    vl.id,
    v.name,
    v.disease_target,
    vl.vaccination_date,
    vl.dose_given,
    vl.unit,
    vl.route,
    vl.next_due_date,
    vl.notes
  FROM public.vaccination_log vl
  JOIN public.vaccines v ON v.id = vl.vaccine_id
  WHERE vl.animal_id = p_animal_id
  ORDER BY vl.vaccination_date DESC;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- 8. RLS
-- ══════════════════════════════════════════════════════════════
ALTER TABLE public.vaccines             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccination_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccination_log      ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vaccines_select             ON public.vaccines;
DROP POLICY IF EXISTS vac_schedule_select         ON public.vaccination_schedule;
DROP POLICY IF EXISTS vac_log_all                 ON public.vaccination_log;

CREATE POLICY vaccines_select         ON public.vaccines             FOR ALL USING (true);
CREATE POLICY vac_schedule_select     ON public.vaccination_schedule FOR ALL USING (true);
CREATE POLICY vac_log_all             ON public.vaccination_log      FOR ALL USING (true);

-- SECURITY DEFINER GRANTS
GRANT EXECUTE ON FUNCTION public.add_vaccination       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_vaccination_schedule TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_vaccinations     TO anon, authenticated;

-- ══════════════════════════════════════════════════════════════
-- 9. SEED DATA — Türkiye'de yaygın sığır aşıları
-- ══════════════════════════════════════════════════════════════
INSERT INTO public.vaccines (name, disease_target, dose, unit, route, repeat_interval_days, is_mandatory) VALUES
  ('Şarbon Aşısı',           'Şarbon',              2, 'ml', 'SC', 365, true),
  ('BVD Aşısı',              'BVD (Viral Diare)',   2, 'ml', 'IM', 365, true),
  ('IBR Aşısı',              'IBR (Rinotracheitis)', 2, 'ml', 'IM', 365, true),
  ('Leptospirosis Aşısı',    'Leptospirosis',       2, 'ml', 'IM', 365, true),
  ('BRSV Aşısı',             'BRSV (Solunum)',      2, 'ml', 'IM', 365, false),
  ('Piogen Aşısı',           'Piogen (Yavru Atma)', 2, 'ml', 'IM', 365, false),
  ('Clostridium Aşısı',      'Clostridial Hast.',   5, 'ml', 'IM', 365, false),
  ('E. coli Aşısı',          'E. coli (Buzağı)',    2, 'ml', 'IM', 365, false),
  ('Rotavirus Aşısı',        'Rotavirus (Buzağı)',  2, 'ml', 'IM', 365, false),
  ('Coronavirus Aşısı',      'Coronavirus (Buzağı)',2, 'ml', 'IM', 365, false)
ON CONFLICT (name) DO NOTHING;

-- ══════════════════════════════════════════════════════════════
-- 10. SEED DATA — Aşı protokolü (örnek)
-- ══════════════════════════════════════════════════════════════
-- Buzağı protokolü: 2-4-6 aylık
INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'buzağı', 'yas', 60, 1, 'İlk BVD dozu'
FROM public.vaccines v WHERE v.name = 'BVD Aşısı'
ON CONFLICT DO NOTHING;

INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'buzağı', 'yas', 120, 2, 'İkinci BVD dozu (pekiştirme)'
FROM public.vaccines v WHERE v.name = 'BVD Aşısı'
ON CONFLICT DO NOTHING;

INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'buzağı', 'yas', 180, 3, 'Şarbon ilk doz'
FROM public.vaccines v WHERE v.name = 'Şarbon Aşısı'
ON CONFLICT DO NOTHING;

-- Düve protokolü: Tohumlama öncesi
INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'düve', 'yas', 365, 4, 'Tohumlama öncesi IBR'
FROM public.vaccines v WHERE v.name = 'IBR Aşısı'
ON CONFLICT DO NOTHING;

-- Doğum sonrası protokol
INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'inek', 'dogum_sonra', 30, 5, 'Doğum sonrası Leptospirosis'
FROM public.vaccines v WHERE v.name = 'Leptospirosis Aşısı'
ON CONFLICT DO NOTHING;

COMMIT;

-- PostgREST schema cache yenile
NOTIFY pgrst, 'reload schema';
-- drug_product_ekle RPC v2 — security hardening

CREATE UNIQUE INDEX IF NOT EXISTS idx_drug_products_brand_class
  ON drug_products (LOWER(brand_name), drug_class_id);

CREATE OR REPLACE FUNCTION drug_product_ekle(
  p_drug_class_id      UUID,
  p_brand_name         TEXT,
  p_concentration      NUMERIC DEFAULT NULL,
  p_concentration_unit TEXT    DEFAULT NULL,
  p_default_route      TEXT    DEFAULT 'IM',
  p_default_unit       TEXT    DEFAULT NULL,
  p_stok_id            UUID    DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  IF p_brand_name IS NULL OR trim(p_brand_name) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;

  BEGIN
    INSERT INTO drug_products (
      drug_class_id, brand_name, concentration,
      concentration_unit, default_route, default_unit
    ) VALUES (
      p_drug_class_id, p_brand_name, p_concentration,
      p_concentration_unit, p_default_route, p_default_unit
    )
    RETURNING id INTO v_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
  END;

  IF p_stok_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stok WHERE id = p_stok_id::text) THEN
      RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
    END IF;
    UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id::text;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID)
  TO anon, authenticated;
-- Migration: Realtime publication aktif (idempotent)
-- Tablolar zaten publication'daysa hata vermez

DO $$
DECLARE
  t text;
  tables text[] := ARRAY['hayvanlar','gorev_log','stok','stok_hareket','tohumlama','dogum','islem_log'];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END;
$$;
-- Migration: UI Telemetry Logger
-- Tarih: 2026-04-01
-- Açıklama: Test sırasında kullanıcı hareketleri ve UI hatalarını loglar

-- Tablo oluştur
create table if not exists public.ui_logs (
  id bigserial primary key,
  level text not null,        -- 'error' | 'warn' | 'action' | 'info'
  message text not null,
  source text,                -- dosya:satır (hata için)
  payload jsonb,              -- ek veri (form değerleri, tıklanan element vb.)
  session_id text,            -- test session'ı ayırt etmek için
  created_at timestamptz default now()
);

-- Index: session_id ve created_at ile hızlı sorgu
create index if not exists idx_ui_logs_session on public.ui_logs(session_id, created_at desc);

-- RLS aktif et
alter table public.ui_logs enable row level security;

-- Anon kullanıcı insert ve select yapabilir (test için)
create policy "anon insert" on public.ui_logs for insert to anon with check (true);
create policy "anon select" on public.ui_logs for select to anon using (true);
-- Migration: tohumlama_sonuc_bos ambiguity fix
-- Sorun: İki farklı imzalı fonksiyon tanımlı, PostgreSQL hangisini çağıracağını bilemiyor
-- Çözüm: Eski tek parametreli imzayı DROP et, yeni imza (DEFAULT NULL ile) kalsın
-- Geri alınabilir: evet — eski migration'dan tek param imzayı yeniden ekle

DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text);

-- Yeni imza zaten migration 0330'dan var, yeniden oluşturmaya gerek yok
-- Doğrulama:
-- SELECT proname, pronargs FROM pg_proc WHERE proname = 'tohumlama_sonuc_bos';
-- 1 satır dönmeli: pronargs = 2-- Migration: delete_treatment_day RPC
-- Etkiler: Yeni RPC — tedavi günü + ilaçları sil, stok ledger'ı tersle
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.delete_treatment_day(uuid);

CREATE OR REPLACE FUNCTION public.delete_treatment_day(
  p_day_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Stok iade: iptal=true (audit trail, çift düşüm bug'u fix)
  UPDATE public.stok_hareket
  SET iptal = true
  WHERE notlar IN (
    SELECT 'drug_admin:' || da.id::text
    FROM public.drug_administrations da
    WHERE da.treatment_day_id = p_day_id
  );

  -- Bağlı TEDAVI_GUN gorevini de sil
  DELETE FROM public.gorev_log
  WHERE gorev_tipi = 'TEDAVI_GUN'
    AND aciklama IS NOT NULL
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id;

  -- Kayıtları sil
  DELETE FROM public.drug_administrations WHERE treatment_day_id = p_day_id;
  DELETE FROM public.treatment_days WHERE id = p_day_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Migration: update_drug_administration RPC
-- Etkiler: Yeni RPC — ilaç uygulaması güncelle, stok delta kaydet
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.update_drug_administration(uuid, numeric, text, text);
-- Fix: Mevcut fonksiyon DEFAULT parametrelerle tanımlı — önce DROP, sonra CREATE

-- Tüm overload'ları temizle (DEFAULT farkından kaynaklanan 42P13 hatası)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure FROM pg_proc WHERE proname = 'update_drug_administration' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.oid::regprocedure; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.update_drug_administration(
  p_admin_id  uuid,
  p_dose      numeric,
  p_unit      text,
  p_route     text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin  record;
  v_delta  numeric;
BEGIN
  -- Fix: drug_id kolonu yok — drug_administrations.stok_id direkt kullan
  SELECT * INTO v_admin
  FROM drug_administrations
  WHERE id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kayıt bulunamadı');
  END IF;

  -- Doz farkı varsa stok hareketi ekle
  v_delta := p_dose - v_admin.dose;
  IF v_delta <> 0 AND v_admin.stok_id IS NOT NULL THEN
    INSERT INTO stok_hareket (stok_id, tur, miktar, notlar)
    VALUES (
      v_admin.stok_id,
      'Tedavi Düzelt',
      ABS(v_delta),
      'drug_admin:' || p_admin_id::text || ':duz:' || v_delta::text
    );
  END IF;

  UPDATE drug_administrations
  SET dose = p_dose, unit = p_unit, route = p_route
  WHERE id = p_admin_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;-- Migration: link_drug_to_stock RPC
-- Etkiler: Yeni RPC — ilacı stok kalemi ile ilişkilendir
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.link_drug_to_stock(uuid, text);

CREATE OR REPLACE FUNCTION public.link_drug_to_stock(
  p_drug_id       uuid,
  p_stock_item_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE drugs SET stock_item_id = p_stock_item_id::uuid WHERE id = p_drug_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'İlaç bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;-- BUG-6: tohumlama_sonuc_gebe — operator does not exist: text = uuid
-- Sebep: hayvan_id TEXT iken hayvanlar.id UUID olarak tanımlı. ::uuid cast
-- başarısız oluyor çünkü 'H000013' gibi string UUID değil.
-- Çözüm: TEXT->UUID cast yerine TEXT karşılaştırma yap.
BEGIN;

-- Eski fonksiyonu yeniden yaz
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

  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY deneme_no DESC
  LIMIT 1
  FOR UPDATE;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  -- TEXT karşılaştırma — ::uuid cast kaldırıldı (hayvanlar.id artık TEXT)
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;

  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Gebe'
  WHERE id = v_toh.hayvan_id;

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
END;
-- BUG-6b: tohumlama_sonuc_bos — aynı ::uuid cast hatası
-- hayvanlar.id TEXT olduğu için ::uuid cast başarısız
BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh          record;
  v_islem_id     text := gen_random_uuid()::text;
  v_onceki_durum text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  END IF;

  -- TEXT karşılaştırma — ::uuid cast kaldırıldı
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;

  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Boş'
  WHERE id = v_toh.hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA_SONUC',
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
END;
-- kizginlik_log: RLS SELECT policy eksikti — pullTables boş dönüyordu
-- allow_all policy bir noktada silinmiş, sadece INSERT kalmıştı
DO $$ BEGIN
  CREATE POLICY "anon select kizginlik_log"
    ON public.kizginlik_log
    FOR SELECT
    TO anon
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- Migration: tohumlama_sonuc_bekliyor RPC
-- Reverts tohumlama from 'Boş' to 'Bekliyor' state
-- Reverts hayvanlar.tohumlama_durumu from islem_log snapshot

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bekliyor(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_islem_id          text := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_onceki_toh_sonuc  text;
  v_snapshot          jsonb;
  v_hayvan_snapshot   jsonb;
BEGIN
  -- 1. Find tohumlama by id, require sonuc is 'Boş'
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Only 'Boş' can be reverted to 'Bekliyor'
  IF v_toh.sonuc != 'Boş' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Boş durumundaki tohumlama Bekliyor yapılabilir');
  END IF;

  -- Save current tohumlama.sonuc for logging
  v_onceki_toh_sonuc := v_toh.sonuc;

  -- 2. Get previous hayvanlar.tohumlama_durumu from islem_log (snapshot of BOS_ATAMA event)
  SELECT snapshot INTO v_snapshot
  FROM public.islem_log
  WHERE ref_id = p_tohumlama_id
    AND ref_tablo = 'tohumlama'
    AND tip = 'TOHUMLAMA_SONUC'
  ORDER BY tarih DESC
  LIMIT 1;

  IF v_snapshot IS NOT NULL THEN
    -- Extract previous tohumlama_durumu from snapshot
    SELECT elem->'onceki'->>'tohumlama_durumu' INTO v_onceki_durum
    FROM jsonb_array_elements(v_snapshot->'guncellenen') AS elem
    WHERE elem->>'tablo' = 'hayvanlar';
  END IF;

  -- Fallback: if no snapshot found, default to 'Tohumlanabilir'
  IF v_onceki_durum IS NULL THEN
    v_onceki_durum := 'Tohumlanabilir';
  END IF;

  -- 3. Set tohumlama.sonuc = 'Bekliyor'
  UPDATE public.tohumlama SET sonuc = 'Bekliyor' WHERE id::text = p_tohumlama_id;

  -- 4. Revert hayvanlar.tohumlama_durumu to prior state
  UPDATE public.hayvanlar
  SET tohumlama_durumu = v_onceki_durum
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  -- 5. Write islem_log with tip='TOHUMLAMA_SONUC'
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA_SONUC',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_onceki_toh_sonuc)
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
-- Drop orphan columns no longer used by the clinical system
-- (new system uses cases/drug_administrations tables)
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_stok_id;
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_miktar;
-- ============================================================
-- Bulk Vaccination RPC
-- Allows vaccinating multiple animals at once via a single RPC call.
-- Reads existing add_vaccination function for pattern reference:
--   migration 20260331000032_vaccination_module.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.bulk_vaccination(
  p_animal_ids  text[],
  p_vaccine_id  text,
  p_date        date,
  p_dose_ml     numeric DEFAULT NULL,
  p_notes       text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_animal_id   text;
  v_result      jsonb;
  v_success     int := 0;
  v_errors      jsonb := '[]'::jsonb;
BEGIN
  FOREACH v_animal_id IN ARRAY p_animal_ids LOOP
    v_result := public.add_vaccination(v_animal_id, p_vaccine_id::uuid, p_date, p_dose_ml, p_notes);
    IF (v_result->>'ok')::boolean THEN
      v_success := v_success + 1;
    ELSE
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('animal_id', v_animal_id, 'error', v_result->>'mesaj')
      );
    END IF;
  END LOOP;
  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$$;

-- Allow anon/authenticated clients to call this RPC
GRANT EXECUTE ON FUNCTION public.bulk_vaccination TO anon, authenticated;-- ============================================================
-- Bulk Ilac RPC — Toplu Ilac Uygulama (FIXED)
-- Fix: explicit ::uuid casts on all gen_random_uuid() calls
--       and ::text casts on stok_id references
-- ============================================================

CREATE OR REPLACE FUNCTION public.bulk_ilac(
  p_animal_ids   text[],
  p_ilac_stok_id text,
  p_miktar       numeric,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_animal_id       text;
  v_stok            record;
  v_success         int := 0;
  v_errors          jsonb := '[]'::jsonb;
  v_total_miktar    numeric;
  v_stok_urun_adi   text;
  v_log_id          text;
  v_stok_hareket_id uuid;
BEGIN
  -- Verify stok exists
  SELECT id, urun_adi, baslangic_miktar INTO v_stok
  FROM public.stok
  WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  v_stok_urun_adi := v_stok.urun_adi;
  v_total_miktar := p_miktar * array_length(p_animal_ids, 1);

  -- Check stock availability (baslangic_miktar - consumed via stok_hareket)
  IF (
    COALESCE(v_stok.baslangic_miktar, 0)
    < v_total_miktar
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.baslangic_miktar, 0) || ' mevcut, ' || v_total_miktar || ' gerekli'
    );
  END IF;

  -- Apply to each animal
  FOREACH v_animal_id IN ARRAY p_animal_ids LOOP
    BEGIN
      -- Log to islem_log with TOPLU_ILAC tip
      v_log_id := gen_random_uuid()::text;
      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, tarih, kullanici_notu, snapshot, ref_id, ref_tablo)
      VALUES (
        v_log_id,
        'TOPLU_ILAC',
        v_animal_id,
        now(),
        p_notlar,
        jsonb_build_object(
          'ilac_stok_id', p_ilac_stok_id,
          'ilac_adi', v_stok_urun_adi,
          'miktar', p_miktar
        ),
        v_log_id,              -- ref_id = islem_log.id
        'islem_log'            -- ref_tablo
      );
      v_success := v_success + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('animal_id', v_animal_id, 'error', SQLERRM)
      );
    END;
  END LOOP;

  -- Deduct total from stok (single operation for efficiency)
  IF v_success > 0 THEN
    UPDATE public.stok
    SET baslangic_miktar = baslangic_miktar - (p_miktar * v_success)
    WHERE id = p_ilac_stok_id;

    -- Log stok hareket
    v_stok_hareket_id := gen_random_uuid();
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (
      v_stok_hareket_id,
      p_ilac_stok_id,
      'TOPLU_ILAC',
      p_miktar * v_success,
      v_success || ' hayvana toplu ilaç uygulaması (' || COALESCE(v_stok_urun_adi, p_ilac_stok_id) || ')',
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$$;

-- Allow anon/authenticated clients to call this RPC
GRANT EXECUTE ON FUNCTION public.bulk_ilac TO anon, authenticated;
-- Migration: Vaccines stok backend integration — create real stock pools for vaccines
-- Fixes: All 10 vaccine seeds have stock_item_id=NULL, so vaccination_stok_dusum trigger
--        skips stock deduction entirely.
-- Solution: Auto-create stok items for vaccines and link them.
-- Revertable: YES — undo via DELETE + UPDATE (see ROLLBACK section)

BEGIN;

-- ══════════════════════════════════════════════════════════════
-- 1. Create stok items for vaccines where stock_item_id IS NULL
-- ══════════════════════════════════════════════════════════════
-- For each vaccine without a stock pool, create one with initial qty 1000 units

INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
SELECT
  'STOK-AŞI-' || v.id::text,
  v.name,
  'Aşı',
  v.unit,
  1000,   -- initial stock: 1000 units (configurable)
  100    -- low-stock threshold
FROM public.vaccines v
WHERE v.stock_item_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.stok s
    WHERE s.id = 'STOK-AŞI-' || v.id::text
  );

-- ══════════════════════════════════════════════════════════════
-- 2. Update vaccines.stock_item_id to point to the new stok items
-- ══════════════════════════════════════════════════════════════
UPDATE public.vaccines
SET stock_item_id = 'STOK-AŞI-' || id::text
WHERE stock_item_id IS NULL;

-- ══════════════════════════════════════════════════════════════
-- 3. Verification query (run manually to check)
-- ══════════════════════════════════════════════════════════════
-- SELECT v.name, v.stock_item_id, s.baslangic_miktar
-- FROM public.vaccines v
-- JOIN public.stok s ON s.id = v.stock_item_id;

-- ══════════════════════════════════════════════════════════════
-- ROLLBACK (manual — run only if reverting)
-- ══════════════════════════════════════════════════════════════
-- UPDATE public.vaccines SET stock_item_id = NULL WHERE stock_item_id LIKE 'STOK-AŞI-%';
-- DELETE FROM public.stok WHERE id LIKE 'STOK-AŞI-%';

COMMIT;

-- PostgREST schema cache yenile
NOTIFY pgrst, 'reload schema';
-- Formal migration: tohumlama_sonuc_bos RPC standalone contract
-- Etkiler: tohumlama_sonuc_bos RPC (CREATE OR REPLACE)
-- Tablolar: tohumlama, hayvanlar, islem_log
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_bos(text,text);

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh          record;
  v_islem_id     text := gen_random_uuid()::text;
  v_onceki_durum text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  END IF;

  -- TEXT karşılaştırma — ::uuid cast kaldırıldı (hayvanlar.id TEXT)
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucunu Boş yap
  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;

  -- Hayvanın tohumlama_durumu güncelle
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Boş'
  WHERE id = v_toh.hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA_SONUC',
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
      ),
      'notlar', p_notlar
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
-- Formal migration: tohumlama_abort RPC standalone contract
-- Etkiler: tohumlama_abort RPC (CREATE OR REPLACE)
-- Tablolar: tohumlama, hayvanlar, islem_log
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_abort(text,text);

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_abort(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh           record;
  v_islem_id      text := gen_random_uuid()::text;
  v_onceki_durum  text;
  v_onceki_tarih  date;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Gebe' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe durumundaki tohumlama abort edilebilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  SELECT tohumlama_durumu, tohumlama_onay_tarihi INTO v_onceki_durum, v_onceki_tarih
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucunu Abort yap
  UPDATE public.tohumlama
  SET sonuc = 'Abort', abort_notlar = p_notlar
  WHERE id::text = p_tohumlama_id;

  -- Hayvanın tohumlama_durumu ve onay tarihini sıfırla
  UPDATE public.hayvanlar
  SET tohumlama_durumu = NULL,
      tohumlama_onay_tarihi = NULL
  WHERE id = v_toh.hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ABORT_KAYDI',
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
          'onceki', jsonb_build_object(
            'tohumlama_durumu', v_onceki_durum,
            'tohumlama_onay_tarihi', v_onceki_tarih
          )
        )
      ),
      'notlar', p_notlar
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
-- Migration: 20260502000003_drop_orphan_objects.sql
-- Date: 2026-05-02
-- Purpose: Clean up dead DB objects documented as unused in ARCHITECTURE.md §4.4
--
-- Removed objects:
--   1. buzagi_takip table — orphan, never referenced in application code
--   2. hastalik_log.ilac_stok_id — orphan column (system uses tedavi/cases/drug_administrations)
--   3. hastalik_log.ilac_miktar — orphan column (same as above)
--
-- References:
--   - ARCHITECTURE.md §4.4 (technical debt)
--   - egesut-deep-status-2026-05-02.md §3d

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop orphan table buzagi_takip
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.buzagi_takip;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Drop orphan columns from hastalik_log
-- Note: mig-011 already dropped ilac_stok_id and ilac_miktar in 2026-04-27;
-- IF EXISTS is safe in case migration 011 was not yet applied.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_stok_id;
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_miktar;-- Migration: kizginlik_postpartum
-- 1. Add sonuc column to kizginlik_log
-- 2. Create kizginlik_yok_kaydet RPC for yoktu recordings

-- ============================================================
-- 1. Add sonuc column
-- ============================================================
ALTER TABLE public.kizginlik_log
  ADD COLUMN IF NOT EXISTS sonuc text DEFAULT 'GOZLEMLENDI';

-- ============================================================
-- 2. Create kizginlik_yok_kaydet RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public.kizginlik_yok_kaydet(
  p_hayvan_id  text,
  p_dogum_id   text,
  p_notlar     text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_id     text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar, sonuc)
  VALUES (v_id, p_hayvan_id, CURRENT_DATE, NULL, p_notlar, 'YOKTU');

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_yok_kaydet TO anon, authenticated;-- Migration: Add dismiss columns to vaccination_log + vaccination_dismiss RPC
-- spec: spec-egesut-asi-dismiss Step 1

-- 1. Add dismiss columns to vaccination_log
ALTER TABLE public.vaccination_log
  ADD COLUMN IF NOT EXISTS ertelendi boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS erteleme_notu text;

-- 2. Create RPC vaccination_dismiss
CREATE OR REPLACE FUNCTION public.vaccination_dismiss(
  p_vaccination_id  uuid,
  p_note            text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_log   record;
  v_islem text := gen_random_uuid()::text;
BEGIN
  SELECT vl.*, v.name AS vaccine_name
  INTO v_log
  FROM public.vaccination_log vl
  LEFT JOIN public.vaccines v ON v.id = vl.vaccine_id
  WHERE vl.id = p_vaccination_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  UPDATE public.vaccination_log
  SET ertelendi = true, erteleme_notu = p_note
  WHERE id = p_vaccination_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem,
    'ASI_ERTELEME',
    v_log.animal_id,
    p_vaccination_id::text,
    'vaccination_log',
    jsonb_build_object(
      'vaccine_name',    v_log.vaccine_name,
      'original_due',    v_log.next_due_date,
      'erteleme_notu',   p_note,
      'dismissed_at',    CURRENT_DATE
    )
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.vaccination_dismiss TO anon, authenticated;-- Migration: ileri_gebe_gorev_kontrol RPC + tohumlama_sonuc_gebe fix
-- Etkiler:
--   1. ileri_gebe_gorev_kontrol: yeni RPC — 240/260/261/265. gün görevleri (idempotent)
--   2. tohumlama_sonuc_gebe: 'Bekliyor' zorunluluğu kaldırıldı
-- Geri alınabilir: evet — DROP FUNCTION ileri_gebe_gorev_kontrol();

BEGIN;

-- 1. ileri_gebe_gorev_kontrol
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
BEGIN
  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- 240. gün: Rota-Corona 1. doz (tüm gebeler)
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (sadece düveler)
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin (tüm gebeler)
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: IM E Vitamini (tüm gebeler)
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

-- 2. tohumlama_sonuc_gebe: 'Bekliyor' zorunluluğunu kaldır
--    Import'tan 'Boş' gelen kayıtlar da gebe yapılabilsin.
--    Kalan kural: sadece hayvanın en son tohumlaması gebe yapılabilir.
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

  -- Zaten Gebe ise erken dön
  IF v_toh.sonuc = 'Gebe' THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Zaten Gebe olarak işaretli');
  END IF;

  -- Sadece en son tohumlama gebe yapılabilir
  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY tarih DESC, deneme_no DESC
  LIMIT 1
  FOR UPDATE;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;

  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Gebe'
  WHERE id = v_toh.hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'GEBE_ATAMA', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo','tohumlama','id',p_tohumlama_id,'onceki',jsonb_build_object('sonuc',v_toh.sonuc)),
        jsonb_build_object('tablo','hayvanlar','id',v_toh.hayvan_id,'onceki',jsonb_build_object('tohumlama_durumu',v_onceki_durum))
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

END;
-- Migration: ileri_gebe_gorev_kontrol — ILERI_GEBE_ASI tipi + stok_id
-- Etkiler:
--   1. Mevcut tamamlanmamış 1. doz Rota-Corona görevlerini ILERI_GEBE_ASI + stok_id ile güncelle
--   2. ileri_gebe_gorev_kontrol RPC'yi aynı şekilde yeniden yaz
-- Geri alınabilir: evet

BEGIN;

-- 1. Mevcut tamamlanmamış 1. doz görevlerini güncelle
UPDATE gorev_log
SET
  gorev_tipi = 'ILERI_GEBE_ASI',
  stok_id    = (
    SELECT v.stock_item_id FROM vaccines v
    WHERE v.name ILIKE '%Rota%' LIMIT 1
  ),
  miktar     = 1
WHERE gorev_tipi = 'ILERI_GEBE'
  AND aciklama ILIKE '%Rota-Corona%1. doz%'
  AND tamamlandi = false;

-- 2. Mevcut tamamlanmamış 2. doz (düve) görevlerini güncelle
UPDATE gorev_log
SET
  gorev_tipi = 'ILERI_GEBE_ASI',
  stok_id    = (
    SELECT v.stock_item_id FROM vaccines v
    WHERE v.name ILIKE '%Rota%' LIMIT 1
  ),
  miktar     = 1
WHERE gorev_tipi = 'ILERI_GEBE'
  AND aciklama ILIKE '%Rota-Corona%2. doz%'
  AND tamamlandi = false;

-- 3. ileri_gebe_gorev_kontrol — ILERI_GEBE_ASI tipi + stok_id ile yeniden yaz
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_stok_id     text;
BEGIN
  -- Rota-Corona aşısının stock_item_id'sini bul
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v
  WHERE v.name ILIKE '%Rota%'
  LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- 240. gün: Rota-Corona 1. doz (tüm gebeler) — ILERI_GEBE_ASI tipi + stok_id
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (sadece düveler) — ILERI_GEBE_ASI tipi + stok_id
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin (tüm gebeler) — ILERI_GEBE tipi (ilaç, aşı değil)
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: IM E Vitamini (tüm gebeler) — ILERI_GEBE tipi (ilaç, aşı değil)
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
-- Migration: ileri_gebe_asi_tamamla RPC
-- Etkiler:
--   Yeni RPC: ileri_gebe_asi_tamamla — aşı kayıt + gorev tamamlama + rapel oluşturma
-- Bağımlılık: add_vaccination RPC (20260331000032_vaccination_module.sql)
-- Not: gorev_log.id uuid tipinde — v_rapel_id uuid olmalı
-- Geri alınabilir: DROP FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric);

BEGIN;

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

  -- 4. 1. doz ise rapel görevi oluştur (21 gün sonra)
  v_is_first := v_gorev.aciklama ILIKE '%1. doz%';
  IF v_is_first THEN
    v_rapel_tarih := p_tarih + 21;
    v_rapel_id := gen_random_uuid();
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak)
    VALUES (
      v_rapel_id,
      v_gorev.hayvan_id,
      'ILERI_GEBE_ASI',
      '💉 Rota-Corona Aşısı (2. doz)',
      v_rapel_tarih,
      false,
      v_gorev.stok_id,
      1,
      v_gorev.id,
      'ILERI_GEBE'
    )
    ON CONFLICT DO NOTHING;
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

END;
-- Migration: DB trigger — tohumlama Gebe olunca ileri gebe görevleri yarat
-- Etkiler:
--   1. fn_gebe_gorev_yarat(): 1. doz + SC Ademin + E Vitamini yarat (2. doz rapeli RPC yaratır)
--   2. trg_tohumlama_gebe_gorev: AFTER UPDATE ON tohumlama trigger
--   3. "2. doz — düve" catch-up görevleri silindi (rapel sadece RPC'den gelir)
-- Geri alınabilir: DROP TRIGGER trg_tohumlama_gebe_gorev ON tohumlama; DROP FUNCTION fn_gebe_gorev_yarat();

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_gebe_gorev_yarat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
BEGIN
  IF NEW.sonuc != 'Gebe' OR OLD.sonuc = 'Gebe' THEN
    RETURN NEW;
  END IF;

  SELECT stock_item_id INTO v_stok_id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1;

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
         '💉 Rota-Corona Aşısı (1. doz)', NEW.tarih::date + 240, false, v_stok_id, 1, 'ILERI_GEBE', 'ROTA'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND tamamlandi = false
  );

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 SC Ademin uygulaması', NEW.tarih::date + 260, false, 'ILERI_GEBE', 'ADEMIN'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND tamamlandi = false
  );

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 IM E Vitamini uygulaması', NEW.tarih::date + 265, false, 'ILERI_GEBE', 'E_VIT'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND tamamlandi = false
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tohumlama_gebe_gorev ON tohumlama;
CREATE TRIGGER trg_tohumlama_gebe_gorev
  AFTER UPDATE ON tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.fn_gebe_gorev_yarat();

END;
-- Migration: gorev_geri_al RPC
-- Etkiler: Tamamlanan görevi geri al — vaccination + stok + child sil
-- Geri alınabilir: DROP FUNCTION public.gorev_geri_al(text);

BEGIN;

CREATE OR REPLACE FUNCTION public.gorev_geri_al(
  p_gorev_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_id      uuid;
  v_child_count integer;
BEGIN
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF NOT v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten aktif');
  END IF;

  IF v_gorev.tamamlanma_tarihi < now() - interval '7 days' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', '7 günden eski görevler geri alınamaz');
  END IF;

  IF EXISTS (SELECT 1 FROM gorev_log WHERE parent_id = p_gorev_id::uuid AND tamamlandi = true) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Rapel görevi tamamlanmış, geri alınamaz');
  END IF;

  SELECT id INTO v_vax_id FROM vaccination_log
  WHERE notes LIKE '%GorevID:' || p_gorev_id || '%'
  ORDER BY created_at DESC LIMIT 1;

  IF v_vax_id IS NOT NULL THEN
    DELETE FROM stok_hareket WHERE referans_tipi = 'vaccination' AND referans_id = v_vax_id::text;
    DELETE FROM vaccination_log WHERE id = v_vax_id;
  END IF;

  SELECT COUNT(*) INTO v_child_count FROM gorev_log WHERE parent_id = p_gorev_id::uuid;
  DELETE FROM gorev_log WHERE parent_id = p_gorev_id::uuid;

  UPDATE gorev_log
  SET tamamlandi = false, tamamlanma_tarihi = null
  WHERE id = p_gorev_id::uuid;

  RETURN jsonb_build_object(
    'ok', true,
    'silinen_rapel', v_child_count,
    'silinen_asi_id', v_vax_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gorev_geri_al(text) TO anon, authenticated;

END;
-- Migration: padoklar + grup_padok_eslem tables, hayvanlar.padok_id FK, view update
-- Note: View DROP CASCADE was needed due to tohumlanabilir_hayvanlar dependency

BEGIN;

-- 1. padoklar tablosu
CREATE TABLE IF NOT EXISTS public.padoklar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ad text NOT NULL UNIQUE,
  kapasite integer,
  aktif boolean DEFAULT true,
  sira integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.padoklar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "padoklar_all" ON public.padoklar;
CREATE POLICY "padoklar_all" ON public.padoklar FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.padoklar TO anon, authenticated;

-- 2. Seed padoklar with exact Turkish chars
INSERT INTO public.padoklar (ad, sira) VALUES
  ('Sağmal Padok', 1),
  ('Kuru/Gebe Padok', 2),
  ('Düve Padok (Büyük)', 3),
  ('Düve Padok (Küçük)', 4),
  ('Buzağı Padok (Süt İçenler)', 5),
  ('Buzağı Padok (Sütten Kesilmiş)', 6),
  ('Besi Padok (Erkek)', 7),
  ('Besi Padok (Dişi)', 8)
ON CONFLICT (ad) DO NOTHING;

-- 3. grup_padok_eslem tablosu
CREATE TABLE IF NOT EXISTS public.grup_padok_eslem (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  grup text NOT NULL,
  padok_id uuid NOT NULL REFERENCES public.padoklar(id) ON DELETE CASCADE,
  UNIQUE(grup, padok_id)
);

ALTER TABLE public.grup_padok_eslem ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "gpe_all" ON public.grup_padok_eslem;
CREATE POLICY "gpe_all" ON public.grup_padok_eslem FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.grup_padok_eslem TO anon, authenticated;

-- 4. Seed grup_padok_eslem (Gebe İnek added — exists in production)
INSERT INTO public.grup_padok_eslem (grup, padok_id)
SELECT val.grup, p.id
FROM (VALUES
  ('Sağmal (Laktasyonda)', 'Sağmal Padok'),
  ('Sağmal (Kuru)', 'Kuru/Gebe Padok'),
  ('Gebe Düve', 'Kuru/Gebe Padok'),
  ('Gebe İnek', 'Kuru/Gebe Padok'),
  ('Düve (Büyük)', 'Düve Padok (Büyük)'),
  ('Düve (Küçük)', 'Düve Padok (Küçük)'),
  ('Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)'),
  ('Sütten Kesilmiş Buzağı', 'Buzağı Padok (Sütten Kesilmiş)'),
  ('Besi', 'Besi Padok (Erkek)'),
  ('Besi', 'Besi Padok (Dişi)')
) AS val(grup, padok_ad)
JOIN public.padoklar p ON p.ad = val.padok_ad
ON CONFLICT (grup, padok_id) DO NOTHING;

-- 5. hayvanlar.padok_id FK
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS padok_id uuid REFERENCES public.padoklar(id);

-- 6. Migrate existing TEXT values to padok_id
UPDATE public.hayvanlar h
SET padok_id = p.id
FROM public.padoklar p
WHERE h.padok = p.ad AND h.padok_id IS NULL;

END;

-- View update requires CASCADE (tohumlanabilir_hayvanlar depends on hayvan_durum_view)
DROP VIEW IF EXISTS public.tohumlanabilir_hayvanlar CASCADE;
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;

CREATE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id,
    h.kupe_no,
    h.devlet_kupe,
    h.irk,
    h.cinsiyet,
    h.dogum_tarihi,
    h.grup,
    h.padok_id,
    COALESCE(pk.ad, h.padok) AS padok,
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
    h.dogum_kg,
    h.canli_agirlik,
    h.boy,
    h.renk,
    h.ayirici_ozellik,
    h.baba_bilgi,
    h.abort_sayisi,
    CASE
      WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.padoklar pk ON pk.id = h.padok_id
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
  CASE
    WHEN y.cinsiyet = 'Dişi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (st.toh_sonuc IS NULL OR st.toh_sonuc = 'Boş')
    THEN true
    ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun BETWEEN 76 AND 180
    THEN true
    ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true
    ELSE false
  END AS dogum_yaklasti,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280
    ELSE 0
  END AS dogum_gecikme_gun,
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

CREATE VIEW public.tohumlanabilir_hayvanlar AS
SELECT id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
  grup, padok_id, padok, durum, anne_id, kategori,
  tohumlama_durumu, tohumlama_onay_tarihi, suttten_kesme_tarihi,
  cikis_tipi, cikis_tarihi, cikis_sebebi, satis_fiyati, notlar,
  dogum_kg, canli_agirlik, boy, renk, ayirici_ozellik, baba_bilgi, abort_sayisi,
  yas_gun, tohumlama_esik_gun,
  toh_id, toh_tarih, sperma, toh_sonuc, toh_gun,
  aktif_hastalik_sayisi, hesap_kategori,
  tohumlama_bildirisi_gerekli, suttten_kesme_bildirisi_gerekli,
  dogum_yaklasti, dogum_gecikme_gun, tohumlama_durumu_hesap
FROM hayvan_durum_view
WHERE tohumlama_durumu_hesap = 'tohumlanabilir';

GRANT SELECT ON public.tohumlanabilir_hayvanlar TO anon, authenticated;
-- Migration: hekimler tablosu oluştur (production'da yoktu) + hekim_sil + sperma_sil RPCs
BEGIN;

-- hekimler tablosu (lokal migration 009 DB'ye uygulanmamıştı)
CREATE TABLE IF NOT EXISTS public.hekimler (
  id      text PRIMARY KEY,
  ad      text NOT NULL,
  telefon text,
  aktif   boolean NOT NULL DEFAULT true
);

INSERT INTO public.hekimler (id, ad, aktif) VALUES
  ('H1', 'Melik Tokur',        true),
  ('H2', 'Hüseyin Aygün',      true),
  ('H3', 'Süleyman Kocabaş',   true)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.hekimler ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "hekimler_all" ON public.hekimler;
CREATE POLICY "hekimler_all" ON public.hekimler FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.hekimler TO anon, authenticated;

-- hekim_sil: constraint check then delete
CREATE OR REPLACE FUNCTION public.hekim_sil(p_hekim_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM hekimler WHERE id = p_hekim_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hekim bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydi olan hekim silinemez');
  END IF;
  IF EXISTS (SELECT 1 FROM dogum WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Dogum kaydi olan hekim silinemez');
  END IF;
  DELETE FROM hekimler WHERE id = p_hekim_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hekim_sil(text) TO anon, authenticated;

-- sperma_sil: check tohumlama references then delete from stok
CREATE OR REPLACE FUNCTION public.sperma_sil(p_stok_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_urun_adi text;
BEGIN
  SELECT urun_adi INTO v_urun_adi FROM stok WHERE id = p_stok_id AND kategori = 'Sperma';
  IF v_urun_adi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sperma stok kaydi bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE sperma = v_urun_adi LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydinda kullanilan sperma silinemez');
  END IF;
  DELETE FROM stok_hareket WHERE stok_id = p_stok_id;
  DELETE FROM stok WHERE id = p_stok_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sperma_sil(text) TO anon, authenticated;

END;
-- Migration: hayvan_ekle + hayvan_guncelle RPCs now accept p_padok_id (uuid)
-- Backward compat: p_padok text still works via name lookup
BEGIN;

CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no        text    DEFAULT NULL,
  p_devlet_kupe    text    DEFAULT NULL,
  p_irk            text    DEFAULT NULL,
  p_cinsiyet       text    DEFAULT NULL,
  p_dogum_tarihi   date    DEFAULT NULL,
  p_grup           text    DEFAULT 'Genel',
  p_padok          text    DEFAULT NULL,
  p_dogum_kg       numeric DEFAULT NULL,
  p_anne_id        text    DEFAULT NULL,
  p_baba_bilgi     text    DEFAULT NULL,
  p_canli_agirlik  numeric DEFAULT NULL,
  p_boy            numeric DEFAULT NULL,
  p_renk           text    DEFAULT NULL,
  p_ayirici_ozellik text   DEFAULT NULL,
  p_padok_id       uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
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
$$;

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
  p_ayirici_ozellik text    DEFAULT NULL,
  p_baba_bilgi      text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL,
  p_anne_id         text    DEFAULT NULL,
  p_padok_id        uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
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
    anne_id          = COALESCE(NULLIF(p_anne_id,''),        anne_id)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

END;
-- Migration: add_vaccination RPC — improved rapel gorev creation
-- Changes:
--   1. stok_id + miktar + kaynak='ASI_RAPEL' added to rapel gorev
--   2. Skip rapel when p_notes starts with 'GorevID:' (ileri_gebe handles its own)
--   3. Duplicate check: same hayvan_id + gorev_tipi + hedef_tarih + vaccine name
BEGIN;

CREATE OR REPLACE FUNCTION public.add_vaccination(
  p_animal_id     text,
  p_vaccine_id    uuid,
  p_date          date    DEFAULT CURRENT_DATE,
  p_dose_override numeric DEFAULT NULL,
  p_notes         text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_vaccine     record;
  v_new_id      uuid;
  v_next_due    date;
  v_dose        numeric;
  v_animal      record;
  v_islem_id    text := gen_random_uuid()::text;
  v_is_gorev_triggered boolean;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadi veya aktif degil');
  END IF;

  SELECT * INTO v_vaccine FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Asi kaydi bulunamadi');
  END IF;

  v_dose := COALESCE(p_dose_override, v_vaccine.dose);

  IF v_vaccine.repeat_interval_days IS NOT NULL THEN
    v_next_due := p_date + (v_vaccine.repeat_interval_days || ' days')::interval;
  END IF;

  INSERT INTO public.vaccination_log (
    animal_id, vaccine_id, vaccination_date, dose_given, unit, route, next_due_date, notes
  ) VALUES (
    p_animal_id, p_vaccine_id, p_date, v_dose,
    v_vaccine.unit, v_vaccine.route, v_next_due, p_notes
  )
  RETURNING id INTO v_new_id;

  -- Rapel gorev olustur SADECE:
  -- 1. repeat_interval_days varsa
  -- 2. ileri_gebe'den tetiklenmemisse (GorevID: prefix = ileri_gebe kendi rapelini yaratir)
  -- 3. Duplicate yoksa (ayni hayvan + ASI_RAPEL + ayni hedef tarih + ayni asi)
  v_is_gorev_triggered := (p_notes IS NOT NULL AND p_notes LIKE 'GorevID:%');

  IF v_next_due IS NOT NULL AND NOT v_is_gorev_triggered THEN
    INSERT INTO public.gorev_log (
      hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi,
      stok_id, miktar, kaynak
    )
    SELECT
      p_animal_id,
      'ASI_RAPEL',
      v_vaccine.name || ' (rapel)',
      v_next_due,
      false,
      v_vaccine.stock_item_id,
      v_dose,
      'ASI_RAPEL'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.gorev_log
      WHERE hayvan_id = p_animal_id
        AND gorev_tipi = 'ASI_RAPEL'
        AND hedef_tarih = v_next_due
        AND aciklama LIKE v_vaccine.name || '%'
        AND tamamlandi = false
    );
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ASI_KAYDI',
    p_animal_id,
    v_new_id::text,
    'vaccination_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'vaccination_log', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb,
      'vaccine_name', v_vaccine.name,
      'next_due', v_next_due
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_new_id,
    'next_due', v_next_due,
    'islem_id', v_islem_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_vaccination(text,uuid,date,numeric,text) TO anon, authenticated;

END;
-- Migration: stok_duzelt RPC for stock count correction
BEGIN;

CREATE OR REPLACE FUNCTION public.stok_duzelt(
  p_stok_id text,
  p_yeni_miktar numeric,
  p_not text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_guncel numeric;
  v_fark numeric;
BEGIN
  SELECT * INTO v_stok FROM stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadi');
  END IF;

  SELECT COALESCE(v_stok.baslangic_miktar, 0) - COALESCE(SUM(sh.miktar), 0)
  INTO v_guncel
  FROM stok_hareket sh
  WHERE sh.stok_id = p_stok_id AND NOT sh.iptal;

  v_guncel := COALESCE(v_guncel, COALESCE(v_stok.baslangic_miktar, 0));
  v_fark := v_guncel - p_yeni_miktar;

  IF v_fark = 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Miktar zaten aynı');
  END IF;

  INSERT INTO stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi)
  VALUES (p_stok_id, 'Duzeltme', v_fark, COALESCE(p_not, 'Sayim duzeltmesi'), false, 'duzeltme');

  RETURN jsonb_build_object('ok', true, 'eski', v_guncel, 'yeni', p_yeni_miktar, 'fark', v_fark);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stok_duzelt(text, numeric, text) TO anon, authenticated;

END;

CREATE OR REPLACE FUNCTION public.padok_degistir(
  p_hayvan_id text,
  p_yeni_padok_id uuid,
  p_not text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan        hayvanlar%ROWTYPE;
  v_yeni_padok    padoklar%ROWTYPE;
  v_aktif_sayisi  integer;
  v_doluluk_yuzde integer;
  v_kapasite_uyari boolean := false;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan FROM hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı');
  END IF;

  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Zaten aynı padokta mı?
  IF v_hayvan.padok_id = p_yeni_padok_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta');
  END IF;

  -- Kapasite kontrolü
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi >= v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   v_aktif_sayisi::text || '/' || v_yeni_padok.kapasite::text
      );
    END IF;

    v_doluluk_yuzde  := ROUND((v_aktif_sayisi::numeric / v_yeni_padok.kapasite) * 100);
    v_kapasite_uyari := v_doluluk_yuzde >= 80;
  END IF;

  -- Güncelle
  UPDATE hayvanlar
     SET padok_id   = p_yeni_padok_id,
         padok      = v_yeni_padok.ad,
         updated_at = now()
   WHERE id = p_hayvan_id;

  -- İşlem logu (correct columns for islem_log table)
  INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
  VALUES ('padok_degisim', p_hayvan_id, p_hayvan_id, '{}'::jsonb,
          COALESCE(p_not, 'Padok değiştirildi → ' || v_yeni_padok.ad));

  RETURN jsonb_build_object(
    'success',         true,
    'yeni_padok',      v_yeni_padok.ad,
    'yeni_padok_id',   p_yeni_padok_id,
    'kapasite_uyari',  v_kapasite_uyari
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir(text, uuid, text) TO anon, authenticated;

-- Drop old overload (without p_etiketler) to avoid ambiguity
DROP FUNCTION IF EXISTS public.padok_degistir_toplu(text[], uuid);

CREATE OR REPLACE FUNCTION public.padok_degistir_toplu(
  p_hayvan_ids text[],
  p_yeni_padok_id uuid,
  p_etiketler text[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_yeni_padok   padoklar%ROWTYPE;
  v_aktif_sayisi integer;
  v_hayvan_id    text;
  v_hayvan       hayvanlar%ROWTYPE;
BEGIN
  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Kapasite hard block (validasyon, yazma yok)
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi + array_length(p_hayvan_ids, 1) > v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   (v_aktif_sayisi + array_length(p_hayvan_ids, 1))::text
                   || '/' || v_yeni_padok.kapasite::text
      );
    END IF;
  END IF;

  -- Hayvan validasyonları (validasyon, yazma yok)
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı: ' || v_hayvan_id);
    END IF;
    IF v_hayvan.padok_id = p_yeni_padok_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta: ' || v_hayvan_id);
    END IF;
  END LOOP;

  -- Tüm validasyonlar geçti — yazma işlemleri
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    UPDATE hayvanlar
       SET padok_id   = p_yeni_padok_id,
           padok      = v_yeni_padok.ad,
           updated_at = now()
     WHERE id = v_hayvan_id;

    INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('padok_degisim', v_hayvan_id, v_hayvan_id, '{}'::jsonb,
            'Toplu padok değişimi → ' || v_yeni_padok.ad);
  END LOOP;

  -- Etiket güncelleme (varsa, mevcut etiketlerle birleştir)
  IF p_etiketler IS NOT NULL AND array_length(p_etiketler, 1) > 0 THEN
    UPDATE hayvanlar
       SET etiketler = array(
             SELECT DISTINCT unnest(COALESCE(etiketler, '{}') || p_etiketler)
           )
     WHERE id = ANY(p_hayvan_ids);
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'hayvan_sayisi', array_length(p_hayvan_ids, 1),
    'yeni_padok',    v_yeni_padok.ad,
    'yeni_padok_id', p_yeni_padok_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir_toplu(text[], uuid, text[]) TO anon, authenticated;

-- Migration: islem_log trigger'a OLD snapshot desteği
-- hayvanlar UPDATE ve gorev_log UPDATE için OLD+NEW kaydedilir
BEGIN;

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
      -- DEĞİŞİKLİK: UPDATE'te OLD + NEW, INSERT'te sadece NEW
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object(
          'old', to_jsonb(OLD),
          'new', to_jsonb(NEW)
        );
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    WHEN 'dogum' THEN
      v_tip       := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot  := to_jsonb(NEW);
    WHEN 'tohumlama' THEN
      v_tip       := CASE TG_OP WHEN 'UPDATE' THEN 'ABORT_KAYDI' ELSE 'TOHUMLAMA' END;
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
    WHEN 'gorev_log' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'GOREV_EKLENDI' ELSE 'GOREV_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      -- DEĞİŞİKLİK: UPDATE'te OLD + NEW, INSERT'te sadece NEW
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object(
          'old', to_jsonb(OLD),
          'new', to_jsonb(NEW)
        );
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
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
      WHEN 'GOREV_EKLENDI'      THEN 'task_created'
      WHEN 'GOREV_GUNCELLENDI'  THEN 'task_updated'
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

COMMIT;-- Migration: genel islem_geri_al — snapshot'taki old değerleri geri yükle
-- HAYVAN_GUNCELLENDI ve GOREV_GUNCELLENDI destekler
BEGIN;

CREATE OR REPLACE FUNCTION public.islem_geri_al(
  p_islem_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_islem record;
  v_old jsonb;
  v_tablo text;
  v_id text;
  v_col text;
  v_val jsonb;
  v_sets text[] := ARRAY[]::text[];
  v_pairs text;
BEGIN
  -- İşlemi bul
  SELECT * INTO v_islem FROM public.islem_log WHERE id = p_islem_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Islem bulunamadi');
  END IF;

  IF v_islem.durum = 'geri_alindi' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem zaten geri alinmis');
  END IF;

  -- Snapshot'ta old objesi var mı?
  v_old := v_islem.snapshot->'old';
  IF v_old IS NULL OR v_old = 'null'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem icin geri alma verisi bulunamadi. Sadece yeni islemler destekleniyor.');
  END IF;

  -- Hedef tabloyu belirle
  CASE v_islem.tip
    WHEN 'HAYVAN_GUNCELLENDI' THEN
      -- old'daki tüm kolonları geri yükle (id hariç)
      FOR v_col, v_val IN SELECT * FROM jsonb_each(v_old)
      LOOP
        IF v_col != 'id' THEN
          -- #>> '{}' jsonb değerini text'e çevirir (tırnakları kaldırır)
          v_sets := array_append(v_sets, format('%I = %L', v_col, v_val #>> '{}'));
        END IF;
      END LOOP;
      v_pairs := array_to_string(v_sets, ', ');
      EXECUTE format('UPDATE hayvanlar SET %s WHERE id = %L', v_pairs, v_old->>'id');

    WHEN 'GOREV_GUNCELLENDI' THEN
      -- Görev geri alma
      FOR v_col, v_val IN SELECT * FROM jsonb_each(v_old)
      LOOP
        IF v_col != 'id' THEN
          v_sets := array_append(v_sets, format('%I = %L', v_col, v_val #>> '{}'));
        END IF;
      END LOOP;
      v_pairs := array_to_string(v_sets, ', ');
      EXECUTE format('UPDATE gorev_log SET %s WHERE id = %L', v_pairs, v_old->>'id');

    ELSE
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem tipi icin geri alma desteklenmiyor: ' || v_islem.tip);
  END CASE;

  -- İşlemi geri alındı olarak işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi',
      geri_alma_tarihi = now()
  WHERE id = p_islem_id;

  RETURN jsonb_build_object('ok', true, 'mesaj', 'Islem geri alindi');
END;
$$;

GRANT EXECUTE ON FUNCTION public.islem_geri_al(text) TO anon, authenticated;

COMMIT;-- Migration: timeline view'da padok değişikliğini vurgula
-- HAYVAN_GUNCELLENDI event'lerinde snapshot->old->padok_id vs snapshot->new->padok_id karşılaştırması
BEGIN;

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
  d.id::text                       AS kaynak_id
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
  hl.id::text                       AS kaynak_id
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
  kl.id::text                       AS kaynak_id
FROM public.kizginlik_log kl

UNION ALL

-- Hayvan Güncellemeleri (islem_log'dan, PADOK_ODAKLI)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  CASE
    -- Padok değişikliği varsa detaya ekle
    WHEN il.snapshot ? 'old' AND il.snapshot->'old' ? 'padok_id'
         AND il.snapshot->'old'->>'padok_id' IS DISTINCT FROM il.snapshot->'new'->>'padok_id'
    THEN jsonb_build_object(
      'padok_degisti', true,
      'eski_padok', il.snapshot->'old'->>'padok',
      'yeni_padok', il.snapshot->'new'->>'padok',
      'eski_padok_id', il.snapshot->'old'->>'padok_id',
      'yeni_padok_id', il.snapshot->'new'->>'padok_id'
    )
    ELSE jsonb_build_object('padok_degisti', false)
  END                               AS detay,
  il.id::text                        AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('HAYVAN_GUNCELLENDI', 'HAYVAN_EKLENDI')

UNION ALL

-- Diğer islem_log tipleri (ABORT, SATIS, OLUM, SUTTEN_KESME)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  COALESCE(il.payload->'meta', il.snapshot) AS detay,
  il.id                             AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('ABORT_KAYDI', 'SATIS_KAYDI', 'OLUM_KAYDI', 'SUTTEN_KESME')

ORDER BY zaman DESC;

GRANT SELECT ON public.hayvan_timeline_view TO anon, authenticated;

COMMIT;-- Migration: tohumlama_sonuc_bos RPC
BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan_id text;
  v_toh_tarih date;
  v_sonuc text;
BEGIN
  -- Tohumlamayı bul
  SELECT hayvan_id, tarih, sonuc INTO v_hayvan_id, v_toh_tarih, v_sonuc
  FROM public.tohumlama WHERE id = p_tohumlama_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama bulunamadi');
  END IF;

  -- Sadece Bekliyor → Boş
  IF v_sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sadece Bekliyor durumundaki tohumlamalar Bos yapilabilir');
  END IF;

  -- Tohumlamayı güncelle
  UPDATE public.tohumlama
  SET sonuc = 'Bos', sonuc_tarihi = CURRENT_DATE
  WHERE id = p_tohumlama_id;

  -- islem_log'a yaz (trigger otomatik yazacak, manuel ek gerek yok)
  
  -- Event stack: Bekliyor → Boş → tohumlanabilir duruma geçir
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'tohumlanabilir'
  WHERE id = v_hayvan_id AND tohumlama_durumu = 'bekliyor';

  RETURN jsonb_build_object('ok', true, 'hayvan_id', v_hayvan_id, 'tohumlama_id', p_tohumlama_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_bos(text) TO anon, authenticated;

COMMIT;-- Migration: Fix _islem_log_yaz trigger — tohumlama UPDATE'lerde gereksiz ABORT_KAYDI engelle
-- Bug: Tohumlama sonucu Boş/Gebe/Bekliyor değişince trigger ABORT_KAYDI yazıyordu
--       + RPC'ler de kendi islem_log'unu yazıyor → çift kayıt + yanlış tip
-- Fix: RPC'ler kendi log'unu yaptığı için, trigger sadece INSERT(tohumlama) ve
--       RPC dışı abort UPDATE'lerde log yazar. Diğer UPDATE'leri sessizce geçer.
BEGIN;

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip          text;
  v_hayvan_id    text;
  v_snapshot     jsonb;
  v_payload      jsonb;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar' THEN
      v_tip := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    WHEN 'dogum' THEN
      v_tip := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'tohumlama' THEN
      -- FIX: UPDATE'lerde ABORT_KAYDI varsayma — tüm RPC'ler kendi islem_log'unu yapıyor
      IF TG_OP = 'INSERT' THEN
        v_tip := 'TOHUMLAMA';
      ELSE
        -- UPDATE: sadece abort (RPC dışı) durumunda logla
        -- RPC'ler (tohumlama_abort, tohumlama_sonuc_bos, vb.) kendi islem_log'unu INSERT eder
        IF NEW.sonuc = 'Abort' AND OLD.sonuc != 'Abort' THEN
          v_tip := 'ABORT_KAYDI';
        ELSE
          -- RPC tarafından yönetilen UPDATE — trigger sessizce geç
          RETURN NEW;
        END IF;
      END IF;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'hastalik_log' THEN
      v_tip := 'HASTALIK_KAYDI';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'kizginlik_log' THEN
      v_tip := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'gorev_log' THEN
      v_tip := CASE TG_OP WHEN 'INSERT' THEN 'GOREV_EKLENDI' ELSE 'GOREV_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    ELSE
      v_tip := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot := to_jsonb(NEW);
  END CASE;

  v_payload := jsonb_build_object(
    'event_type', CASE v_tip
      WHEN 'DOGUM_KAYDI' THEN 'birth_recorded'
      WHEN 'TOHUMLAMA' THEN 'insemination_performed'
      WHEN 'HASTALIK_KAYDI' THEN 'treatment_recorded'
      WHEN 'HAYVAN_EKLENDI' THEN 'animal_registered'
      WHEN 'HAYVAN_GUNCELLENDI' THEN 'animal_updated'
      WHEN 'ABORT_KAYDI' THEN 'abortion_recorded'
      WHEN 'KIZGINLIK' THEN 'estrus_detected'
      WHEN 'GOREV_EKLENDI' THEN 'task_created'
      WHEN 'GOREV_GUNCELLENDI' THEN 'task_updated'
      ELSE lower(v_tip)
    END,
    'entity_type', 'animal',
    'entity_id', v_hayvan_id,
    'meta', v_snapshot
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, payload)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_payload);

  RETURN NEW;
END;
$$;

COMMIT;
-- Migration: kisir flag + hayvan_kisir_isaretle RPC
BEGIN;

-- 1. Kolon ekle
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kisir boolean DEFAULT false;

-- 2. RPC: kısır işaretle/kaldır
CREATE OR REPLACE FUNCTION public.hayvan_kisir_isaretle(
  p_hayvan_id text,
  p_kisir boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_islem_id text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  IF v_hayvan.kisir = p_kisir THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Zaten bu durumda');
  END IF;

  UPDATE public.hayvanlar SET kisir = p_kisir WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
  VALUES (
    v_islem_id,
    CASE WHEN p_kisir THEN 'KISIR_ISARETLE' ELSE 'KISIR_KALDIR' END,
    p_hayvan_id,
    jsonb_build_object(
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo','hayvanlar','id',p_hayvan_id,'onceki',jsonb_build_object('kisir',v_hayvan.kisir))
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

END;
-- Migration: buzagi_sutten_kesme_kontrol RPC
-- Pattern: ileri_gebe_gorev_kontrol ile aynı yapı
-- Domain kuralı: 60 günden büyük "Süt İçen Buzağı" → sütten kesme görevi
-- İki görev üretir: (1) sütten kesme (2) padok transfer

BEGIN;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_parent_id   text;
BEGIN
  -- "Süt İçen Buzağı" grubundaki aktif hayvanları tara
  FOR v_hayvan IN
    SELECT h.*
    FROM hayvanlar h
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Süt İçen Buzağı%'
      AND h.dogum_tarihi IS NOT NULL
  LOOP
    v_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;

    -- 60. gün: sütten kesme zamanı
    IF v_gun >= 60 THEN
      v_hedef := v_hayvan.dogum_tarihi + 60;
      v_parent_id := gen_random_uuid()::text;

      -- Ana görev: Sütten Kesme
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT v_parent_id, v_hayvan.id, 'SUTTEN_KESME',
             '🍼 Sütten kesme zamanı (' || v_gun || '. gün)',
             v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_hayvan.id
          AND gorev_tipi = 'SUTTEN_KESME'
          AND NOT tamamlandi
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;

      -- Alt görev: Padok Transfer (Buzağı Ahırı → Sütten Kesilmiş)
      IF v_sayac > 0 THEN
        INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, padok_hedef)
        VALUES (
          gen_random_uuid()::text, v_hayvan.id, 'PADOK_DEGISIM',
          '➡️ Padok transfer: Sütten Kesilmiş Buzağı padoğuna taşı',
          v_hedef, false, v_parent_id,
          (SELECT ad FROM padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' LIMIT 1)
        );
        v_olusturulan := v_olusturulan + 1;
      END IF;

    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
-- Migration: laktasyon_kuru_kontrol RPC
-- 210+ gün laktasyondaki sağmal inekleri bulup kuru dönem transfer görevi oluşturur

BEGIN;

CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
  v_gun         int;
  v_hedef       date;
BEGIN
  -- Son doğumundan 210+ gün geçmiş, hala "Sağmal" grubundaki inekleri bul
  FOR v_rec IN
    SELECT h.id, h.kupe_no, h.grup, h.padok,
           MAX(d.tarih) AS son_dogum_tarihi
    FROM hayvanlar h
    JOIN dogum d ON d.anne_id = h.id
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Sağmal%'
      AND h.grup NOT ILIKE '%Kuru%'
    GROUP BY h.id, h.kupe_no, h.grup, h.padok
    HAVING CURRENT_DATE - MAX(d.tarih) >= 210
  LOOP
    v_gun := CURRENT_DATE - v_rec.son_dogum_tarihi;
    v_hedef := v_rec.son_dogum_tarihi + 210;

    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
    SELECT gen_random_uuid()::text, v_rec.id, 'PADOK_DEGISIM',
           '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün laktasyon) — Kuru/Gebe padoğuna transfer',
           v_hedef, false,
           (SELECT ad FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1)
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = v_rec.id
        AND gorev_tipi = 'PADOK_DEGISIM'
        AND aciklama ILIKE '%Kuru döneme%'
        AND NOT tamamlandi
    );
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
-- Migration: hayvan_durum_view'e kisir kolonu ekle
BEGIN;

DROP VIEW IF EXISTS public.tohumlanabilir_hayvanlar CASCADE;
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;

CREATE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id,
    h.kupe_no,
    h.devlet_kupe,
    h.irk,
    h.cinsiyet,
    h.dogum_tarihi,
    h.grup,
    h.padok_id,
    COALESCE(pk.ad, h.padok) AS padok,
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
    h.dogum_kg,
    h.canli_agirlik,
    h.boy,
    h.renk,
    h.ayirici_ozellik,
    h.baba_bilgi,
    h.abort_sayisi,
    h.kisir,
    CASE
      WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.padoklar pk ON pk.id = h.padok_id
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
  CASE
    WHEN y.cinsiyet = 'Dişi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (st.toh_sonuc IS NULL OR st.toh_sonuc = 'Boş')
    THEN true
    ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun BETWEEN 76 AND 180
    THEN true
    ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true
    ELSE false
  END AS dogum_yaklasti,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280
    ELSE 0
  END AS dogum_gecikme_gun,
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

CREATE VIEW public.tohumlanabilir_hayvanlar AS
SELECT id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
  grup, padok_id, padok, durum, anne_id, kategori,
  tohumlama_durumu, tohumlama_onay_tarihi, suttten_kesme_tarihi,
  cikis_tipi, cikis_tarihi, cikis_sebebi, satis_fiyati, notlar,
  dogum_kg, canli_agirlik, boy, renk, ayirici_ozellik, baba_bilgi, abort_sayisi,
  yas_gun, tohumlama_esik_gun, kisir,
  toh_id, toh_tarih, sperma, toh_sonuc, toh_gun,
  aktif_hastalik_sayisi, hesap_kategori,
  tohumlama_bildirisi_gerekli, suttten_kesme_bildirisi_gerekli,
  dogum_yaklasti, dogum_gecikme_gun, tohumlama_durumu_hesap
FROM hayvan_durum_view
WHERE tohumlama_durumu_hesap = 'tohumlanabilir';

GRANT SELECT ON public.tohumlanabilir_hayvanlar TO anon, authenticated;

END;
-- Migration: hayvan_guncelle RPC'ye p_kisir parametresi + gebe validation
BEGIN;

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
  p_ayirici_ozellik text    DEFAULT NULL,
  p_baba_bilgi      text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL,
  p_anne_id         text    DEFAULT NULL,
  p_padok_id        uuid    DEFAULT NULL,
  p_kisir           boolean DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
  v_gebe     boolean;
BEGIN
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
$$;

END;
-- Migration: laktasyon_kuru_kontrol RPC (revize) — dogum tablosu olmadan
-- Sağmal grupta olup gebe olmayan hayvanlar → kuru dönem transfer görevi
-- gorev_log.id uuid tipinde olduğu için gen_random_uuid() direkt kullanılır
BEGIN;

CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
  v_id          uuid;
BEGIN
  FOR v_rec IN
    SELECT h.id, h.kupe_no, h.grup, h.padok
    FROM hayvanlar h
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Sağmal%'
      AND h.grup NOT ILIKE '%Kuru%'
      AND NOT EXISTS (
        SELECT 1 FROM tohumlama t
        WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'
      )
  LOOP
    v_id := gen_random_uuid();
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
    SELECT v_id, v_rec.id, 'PADOK_DEGISIM',
           '⚠️ Kuru döneme geçiş zamanı — Kuru/Gebe padoğuna transfer',
           CURRENT_DATE, false,
           (SELECT ad FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1)
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = v_rec.id
        AND gorev_tipi = 'PADOK_DEGISIM'
        AND aciklama ILIKE '%Kuru döneme%'
        AND NOT tamamlandi
    );
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- TANIMLAR PANELİ — CRUD RPC'ler
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.disease_ekle(p_name text, p_category text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hastalık zaten var');
  END IF;
  INSERT INTO diseases (name, category) VALUES (p_name, p_category) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_guncelle(p_id uuid, p_name text, p_category text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir hastalık var');
  END IF;
  UPDATE diseases SET name = p_name, category = p_category WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık bulunamadı'); END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_sil(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_aktif integer; v_kapali integer;
BEGIN
  SELECT COUNT(*) FILTER (WHERE status='active'), COUNT(*) FILTER (WHERE status='closed')
  INTO v_aktif, v_kapali FROM cases WHERE disease_id = p_id;
  IF v_aktif > 0 OR v_kapali > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      format('Bu hastalığa ait %s vaka var (%s aktif, %s kapalı), silinemez', v_aktif+v_kapali, v_aktif, v_kapali));
  END IF;
  DELETE FROM diseases WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_ekle(p_name text, p_default_unit text DEFAULT NULL, p_default_route text DEFAULT NULL, p_stock_item_id text DEFAULT NULL, p_kategori text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu ilaç zaten var');
  END IF;
  INSERT INTO drugs (name, default_unit, default_route, stock_item_id, kategori)
  VALUES (p_name, p_default_unit, p_default_route, p_stock_item_id, p_kategori) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_guncelle(p_id uuid, p_name text DEFAULT NULL, p_default_unit text DEFAULT NULL, p_default_route text DEFAULT NULL, p_stock_item_id text DEFAULT NULL, p_kategori text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF p_name IS NOT NULL AND EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir ilaç var');
  END IF;
  UPDATE drugs SET name=COALESCE(NULLIF(trim(p_name),''),name), default_unit=p_default_unit, default_route=p_default_route, stock_item_id=p_stock_item_id, kategori=p_kategori WHERE id=p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı'); END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_sil(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_stok_id text; v_count integer;
BEGIN
  SELECT stock_item_id INTO v_stok_id FROM drugs WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı'); END IF;
  IF v_stok_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM drug_administrations WHERE stok_id = v_stok_id;
    IF v_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', format('Bu ilaç %s tedavi uygulamasında kullanılmış, silinemez', v_count));
    END IF;
  END IF;
  DELETE FROM drugs WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_ekle(p_ad text, p_tip text DEFAULT 'genel')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_ad)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kategori zaten var');
  END IF;
  INSERT INTO stok_kategorileri (ad, sira, tip) VALUES (p_ad, COALESCE((SELECT MAX(sira) FROM stok_kategorileri),0)+1, p_tip) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_guncelle(p_id uuid, p_new_ad text DEFAULT NULL, p_tip text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_old_ad text;
BEGIN
  IF p_new_ad IS NOT NULL AND EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_new_ad) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir kategori var');
  END IF;
  SELECT ad INTO v_old_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı'); END IF;
  IF p_new_ad IS NOT NULL THEN
    UPDATE stok SET kategori = p_new_ad WHERE kategori = v_old_ad;
    UPDATE stok_kategorileri SET ad = p_new_ad WHERE id = p_id;
  END IF;
  IF p_tip IS NOT NULL THEN
    UPDATE stok_kategorileri SET tip = p_tip WHERE id = p_id;
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_sil(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_ad text; v_count integer;
BEGIN
  SELECT ad INTO v_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı'); END IF;
  SELECT COUNT(*) INTO v_count FROM stok WHERE kategori = v_ad;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', format('Bu kategoride %s ürün var, silinemez', v_count));
  END IF;
  DELETE FROM stok_kategorileri WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.seed_defaults(p_tip text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count integer := 0;
BEGIN
  IF p_tip = 'diseases' THEN
    WITH ins AS (
      INSERT INTO diseases (name, category) VALUES
        ('Mastitis','Meme'),('Laminitis','Ayak'),('Metritis','Üreme'),('Retensio','Üreme'),
        ('Ketozis','Metabolik'),('Hipokalsemi','Metabolik'),('Pnömoni','Solunum'),
        ('İshal','Sindirim'),('Neonatal Zayıflık','Buzağı'),('Göbek İltihabı','Buzağı')
      ON CONFLICT (name) DO NOTHING RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;
  ELSIF p_tip = 'drugs' THEN
    WITH ins AS (
      INSERT INTO drugs (name, default_unit, default_route) VALUES
        ('Makrovil','ml','IM'),('Enrolen','ml','IM'),('Florkem','ml','IM'),('Penicilin','ml','IM'),
        ('Oksitetrasiklin','ml','IM'),('Meloksikam','ml','IV'),('Flunixin','ml','IV'),
        ('Deksametazon','ml','IM'),('Kalsiyum Boroglukonat','ml','IV'),
        ('B12 Vitamini','ml','IM'),('AD3E Vitamini','ml','IM'),
        ('Albendazol','ml','PO'),('İvermektin','ml','SC')
      ON CONFLICT (name) DO NOTHING RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;
  ELSIF p_tip = 'kategoriler' THEN
    WITH ins AS (
      INSERT INTO stok_kategorileri (ad, sira, tip) VALUES
        ('Antibiyotik',1,'ilac'),('NSAID',2,'ilac'),('Hormon',3,'ilac'),('Vitamin',4,'ilac'),
        ('Antiparaziter',5,'ilac'),('Diğer İlaç',6,'ilac'),('Aşı',7,'genel'),('Sperma',8,'genel'),
        ('Yem',9,'genel'),('Sarf',10,'genel'),('Ekipman',11,'genel'),('Diğer',12,'genel'),
        ('Tohumlama',13,'genel'),('Metabolik',14,'ilac'),('GI İlaçlar',15,'ilac'),
        ('Topikal',16,'ilac'),('Anestezik / Sedatif',17,'ilac')
      ON CONFLICT (ad) DO NOTHING RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;
  ELSE
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz tip: diseases | drugs | kategoriler');
  END IF;
  RETURN jsonb_build_object('ok', true, 'eklenen', v_count);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- drug_class CRUD RPCs
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.drug_class_ekle(
  p_group_name text,
  p_class_name text,
  p_active_ingredient text,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_group_name IS NULL OR p_group_name = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Grup adı zorunlu');
  END IF;
  IF p_active_ingredient IS NULL OR p_active_ingredient = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Etken madde adı zorunlu');
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.drug_classes
    WHERE group_name = p_group_name
      AND COALESCE(class_name,'') = COALESCE(p_class_name,'')
      AND active_ingredient = p_active_ingredient
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kombinasyon zaten mevcut');
  END IF;
  v_id := gen_random_uuid();
  INSERT INTO public.drug_classes (id, group_name, class_name, active_ingredient, kategori_id)
  VALUES (v_id, p_group_name, NULLIF(p_class_name,''), p_active_ingredient, p_kategori_id);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mesaj', 'Etken madde eklendi');
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_class_guncelle(
  p_id uuid,
  p_group_name text DEFAULT NULL,
  p_class_name text DEFAULT NULL,
  p_active_ingredient text DEFAULT NULL,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.drug_classes WHERE id = p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;
  UPDATE public.drug_classes SET
    group_name = COALESCE(NULLIF(p_group_name,''), group_name),
    class_name = COALESCE(p_class_name, class_name),
    active_ingredient = COALESCE(NULLIF(p_active_ingredient,''), active_ingredient),
    kategori_id = COALESCE(p_kategori_id, kategori_id)
  WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'mesaj', 'Güncellendi');
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_class_sil(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.drug_products WHERE drug_class_id = p_id;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Bu etken maddeye bağlı ' || v_count || ' preparat var. Önce preparatları başka sınıfa taşıyın.');
  END IF;
  DELETE FROM public.drug_classes WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'mesaj', 'Silindi');
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_class_varsayilan_yukle()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_before integer;
  v_after integer;
BEGIN
  SELECT COUNT(*) INTO v_before FROM public.drug_classes;
  INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
  VALUES
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Penisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Amoksisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Seftiofur', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tilmikosin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tulathromycin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Enrofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Marbofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Oksitetrasiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Doksisiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Aminoglikozidler', 'Gentamisin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Sulfonamidler', 'Trimetoprim-SMX', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Meloksikam', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Ketoprofen', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Flunixin', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'Kortikosteroidler', 'Deksametazon', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Prostaglandinler', 'Dinoprost', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'GnRH Agonistleri', 'Gonadorelin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Progestagenler', 'Progesteron', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Oksitosin', 'Oksitosin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'İvermektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'Doramektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Benzimidazoller', 'Albendazol', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B1 (Tiamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B6 (Piridoksin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B12 (Siyanokobalamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B Kompleks', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'C Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'E Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'AD3E Kombinasyon', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Mineraller / İz Elementler', 'Selenyum', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Metabolik / Sıvı Tedavi', 'Kalsiyum Preparatları', 'Kalsiyum Boroglukonat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Magnezyum', 'Magnezyum Sülfat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Glukoz %50', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Dekstroz %30', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'Oral Rehidrasyon Solüsyonu', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'IV Serum (İzotonik NaCl, Ringer Laktat)', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Gastrointestinal İlaçlar', 'Gastroprotektanlar', 'Sukralfat (Antepsin)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Rumen Stimülanları', 'Rumen Stimülanı', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Saccharomyces (Maya)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Probiyotik Preparatları', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Topikal / Harici İlaçlar', 'Merhemler', 'İhtiyol (Kara Merhem)', (SELECT id FROM stok_kategorileri WHERE ad='Topikal')),
    ('Anestezik / Sedatif', 'Sedatifler', 'Ksilazin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Genel Anestezikler', 'Ketamin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Lokal Anestezikler', 'Lidokain', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif'))
  ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;
  SELECT COUNT(*) INTO v_after FROM public.drug_classes;
  RETURN jsonb_build_object('ok', true, 'eklenen', v_after - v_before);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- stok_ekle / stok_guncelle — kategori validate
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stok_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
  END IF;
  v_id := gen_random_uuid()::text;
  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);
  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', v_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', v_id,
      'veri', jsonb_build_object('urun_adi', p_urun_adi, 'kategori', p_kategori, 'birim', p_birim, 'baslangic_miktar', p_baslangic_miktar, 'esik', p_esik)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni stok: ' || p_urun_adi);
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.stok_guncelle(
  p_stok_id text,
  p_urun_adi text DEFAULT NULL,
  p_kategori text DEFAULT NULL,
  p_birim text DEFAULT NULL,
  p_esik numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_onceki jsonb;
BEGIN
  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;
  IF p_kategori IS NOT NULL AND p_kategori != '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
    END IF;
  END IF;
  v_onceki := row_to_json(v_stok)::jsonb;
  UPDATE public.stok SET
    urun_adi = COALESCE(NULLIF(p_urun_adi, ''), urun_adi),
    kategori = COALESCE(NULLIF(p_kategori, ''), kategori),
    birim    = COALESCE(NULLIF(p_birim, ''), birim),
    esik     = COALESCE(p_esik, esik)
  WHERE id = p_stok_id;
  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_GUNCELLE', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', p_stok_id,
      'onceki', v_onceki,
      'sonraki', (SELECT row_to_json(stok)::jsonb FROM public.stok WHERE id = p_stok_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Stok güncellendi: ' || COALESCE(p_urun_adi, (SELECT urun_adi FROM public.stok WHERE id = p_stok_id)));
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.drug_class_ekle(text,text,text,uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_class_guncelle(uuid,text,text,text,uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_class_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_class_varsayilan_yukle() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stok_ekle(text,text,text,numeric,numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stok_guncelle(text,text,text,text,numeric) TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.disease_ekle(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_guncelle(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_ekle(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_guncelle(uuid, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_ekle(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_guncelle(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.seed_defaults(text) TO anon, authenticated;

-- ══════════════════════════════════════════════
-- STAT_GEBELIK_OZET — Sürü Gebelik İstatistikleri
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.stat_gebelik_ozet(
  p_donem_baslangic date DEFAULT CURRENT_DATE - INTERVAL '365 days',
  p_donem_bitis     date DEFAULT CURRENT_DATE,
  p_kategori        text DEFAULT NULL,
  p_grup            text DEFAULT NULL,
  p_sperma          text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb;
BEGIN
  WITH base AS (
    SELECT
      t.id,
      t.sonuc,
      t.deneme_no,
      LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
      CASE
        WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
        WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
        WHEN h.grup ILIKE '%inek%' OR h.grup LIKE '%İnek%'
             OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%'
             OR h.grup ILIKE '%kuru%' THEN 'İnek'
        ELSE 'Bilinmiyor'
      END AS kategori
    FROM public.tohumlama t
    JOIN public.hayvanlar h ON h.id = t.hayvan_id
    WHERE h.cinsiyet = 'Dişi'
      AND t.tarih BETWEEN p_donem_baslangic AND p_donem_bitis
      AND (p_kategori IS NULL OR
           CASE
             WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
             WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
             WHEN h.grup ILIKE '%inek%' OR h.grup LIKE '%İnek%'
             OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%'
             OR h.grup ILIKE '%kuru%' THEN 'İnek'
             ELSE 'Bilinmiyor'
           END = p_kategori)
      AND (p_grup IS NULL OR h.grup = p_grup)
      AND (p_sperma IS NULL OR LOWER(TRIM(split_part(t.sperma, '|', 1))) = LOWER(TRIM(p_sperma)))
  )
  SELECT jsonb_build_object(
    'ozet', jsonb_build_object(
      'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
      'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
      'bos',    COUNT(*) FILTER (WHERE sonuc = 'Boş'),
      'abort',  COUNT(*) FILTER (WHERE sonuc = 'Abort'),
      'bekleyen', COUNT(*) FILTER (WHERE sonuc = 'Bekliyor'),
      'oran',   ROUND(
                  100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                  / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
    ),
    'kategori', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', kategori,
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        GROUP BY kategori
      ) sub
    ),
    'sperma_top5', (
      SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', sperma_norm,
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        WHERE sonuc != 'Bekliyor'
        GROUP BY sperma_norm
        HAVING COUNT(*) >= 3
        ORDER BY ROUND(
                   100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                   / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC
        LIMIT 5
      ) sub
    ),
    'deneme', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'no', CASE WHEN deneme_no >= 3 THEN 3 ELSE deneme_no END,
          'gebe', COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'oran', ROUND(
                    100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                    / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        GROUP BY CASE WHEN deneme_no >= 3 THEN 3 ELSE deneme_no END
      ) sub
    )
  ) INTO v_result
  FROM base;

  RETURN COALESCE(v_result, '{"ozet":{"toplam":0,"gebe":0,"bos":0,"abort":0,"bekleyen":0,"oran":null},"kategori":[],"sperma_top5":[],"deneme":[]}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_gebelik_ozet(date, date, text, text, text) TO anon, authenticated;

-- ── v_ureme_dongusu v3 — cycle detection view + kısır filtresi ═══
CREATE OR REPLACE VIEW public.v_ureme_dongusu AS
WITH numbered AS (
  SELECT
    t.id,
    t.hayvan_id,
    t.tarih,
    t.sonuc,
    t.deneme_no,
    LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
    SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no
            ROWS UNBOUNDED PRECEDING) AS cycle_no,
    CASE
      WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
      WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
      WHEN h.grup ILIKE '%inek%' OR h.grup LIKE '%İnek%'
           OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%'
           OR h.grup ILIKE '%kuru%' THEN 'İnek'
      ELSE 'Bilinmiyor'
    END AS kategori,
    h.padok,
    h.durum
  FROM public.tohumlama t
  JOIN public.hayvanlar h ON h.id = t.hayvan_id
  WHERE h.cinsiyet = 'Dişi'
    AND h.kisir IS NOT TRUE
)
SELECT
  hayvan_id, padok, durum, kategori, cycle_no,
  MIN(tarih)           AS baslangic,
  MAX(tarih)           AS bitis,
  MAX(deneme_no)       AS deneme_sayisi,
  CASE
    WHEN bool_or(sonuc IN ('Gebe','Doğum Yaptı')) THEN 'Gebe'
    WHEN bool_or(sonuc = 'Abort')                 THEN 'Abort'
    WHEN bool_or(sonuc = 'Bekliyor')              THEN 'Bekliyor'
    ELSE 'Boş'
  END                  AS sonuc,
  MAX(CASE WHEN sonuc IN ('Gebe','Doğum Yaptı') THEN sperma_norm END) AS gebe_sperma,
  (ARRAY_AGG(sperma_norm ORDER BY deneme_no DESC))[1] AS son_sperma
FROM numbered
GROUP BY hayvan_id, padok, durum, kategori, cycle_no;

GRANT SELECT ON public.v_ureme_dongusu TO anon, authenticated;

-- ── stat_suru_ozet v4 — 42-gün + sperma_all + sessiz + görev tetikleme ═══
CREATE OR REPLACE FUNCTION public.stat_suru_ozet(
  p_padok     text    DEFAULT NULL,
  p_son_donem boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   jsonb;
  v_gebelik  jsonb;
  v_sessiz   integer;
BEGIN
  SELECT sessiz_hayvanlar_gorev_olustur() INTO v_sessiz;
  SELECT jsonb_build_object(
    'toplam', COUNT(*),
    'inek',   COUNT(*) FILTER (WHERE grup ILIKE '%inek%' OR grup LIKE '%İnek%' OR grup ILIKE '%sağmal%' OR grup ILIKE '%sagmal%' OR grup ILIKE '%kuru%' OR EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'duve',   COUNT(*) FILTER (WHERE (grup ILIKE '%düve%' OR grup ILIKE '%duve%') AND NOT EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'buzagi', COUNT(*) FILTER (WHERE grup ILIKE '%buzağı%' OR grup ILIKE '%buzagi%'),
    'erkek',  COUNT(*) FILTER (WHERE cinsiyet = 'Erkek'),
    'kisir',  COUNT(*) FILTER (WHERE kisir = true),
    'hasta',  (SELECT COUNT(DISTINCT c.animal_id) FROM public.cases c JOIN public.hayvanlar h2 ON h2.id = c.animal_id WHERE c.status = 'active' AND h2.durum = 'Aktif' AND (p_padok IS NULL OR h2.padok = p_padok)),
    'tohumlanan', (SELECT COUNT(DISTINCT t2.hayvan_id) FROM public.tohumlama t2 JOIN public.hayvanlar h3 ON h3.id = t2.hayvan_id WHERE h3.durum = 'Aktif' AND h3.cinsiyet = 'Dişi' AND (p_padok IS NULL OR h3.padok = p_padok)),
    'sessiz', (SELECT COUNT(*) FROM public.v_eligible e WHERE (p_padok IS NULL OR e.padok = p_padok) AND COALESCE(e.sessiz_gun, 9999) >= 55)
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif' AND (p_padok IS NULL OR h.padok = p_padok);
  WITH cycles AS (
    SELECT v.hayvan_id, v.kategori, v.sonuc, v.deneme_sayisi, v.gebe_sperma, v.son_sperma, v.cycle_no, v.baslangic
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif' AND (p_padok IS NULL OR v.padok = p_padok) AND v.baslangic < CURRENT_DATE - 42
    AND (NOT p_son_donem OR NOT EXISTS (SELECT 1 FROM public.v_ureme_dongusu v2 WHERE v2.hayvan_id = v.hayvan_id AND v2.cycle_no > v.cycle_no AND v2.sonuc IN ('Gebe','Doğum Yaptı')))
  ),
  hayvan_stat AS (SELECT DISTINCT ON (hayvan_id) hayvan_id, kategori, sonuc AS son_sonuc FROM cycles ORDER BY hayvan_id, cycle_no DESC)
  SELECT jsonb_build_object(
    'hayvan_ozet', jsonb_build_object(
      'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'),
      'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe'),
      'bos',    COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc IN ('Boş','Abort')),
      'devam_eden', (SELECT COUNT(DISTINCT v3.hayvan_id) FROM public.v_ureme_dongusu v3 WHERE v3.durum = 'Aktif' AND (p_padok IS NULL OR v3.padok = p_padok) AND v3.sonuc = 'Bekliyor'),
      'oran', ROUND(100.0 * COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe') / NULLIF(COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'), 0), 1)
    ),
    'cycle_ozet', (SELECT jsonb_build_object('toplam_cycle', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'basarisiz', COUNT(*) FILTER (WHERE sonuc IN ('Boş','Abort')), 'devam_eden', (SELECT COUNT(*) FROM public.v_ureme_dongusu v4 WHERE v4.durum = 'Aktif' AND (p_padok IS NULL OR v4.padok = p_padok) AND v4.sonuc = 'Bekliyor'), 'oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1), 'ort_deneme', ROUND(AVG(deneme_sayisi) FILTER (WHERE sonuc = 'Gebe'), 1)) FROM cycles),
    'kategori', (SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb) FROM (SELECT jsonb_build_object('ad', hs.kategori, 'hayvan_toplam', COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 'hayvan_gebe', COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe'), 'hayvan_oran', ROUND(100.0 * COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 0), 1), 'cycle_toplam', (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 'cycle_basarili', (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe'), 'cycle_oran', ROUND(100.0 * (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe') / NULLIF((SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM hayvan_stat hs GROUP BY hs.kategori) sub),
    'sperma_all', (SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb) FROM (SELECT jsonb_build_object('ad', COALESCE(gebe_sperma, son_sperma), 'cycle_toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'cycle_basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'cycle_oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM cycles WHERE sonuc != 'Bekliyor' GROUP BY COALESCE(gebe_sperma, son_sperma) HAVING COUNT(*) >= 3 ORDER BY ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC) sub),
    'deneme', (SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb) FROM (SELECT jsonb_build_object('no', deneme_sayisi, 'gebe', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM cycles WHERE sonuc != 'Bekliyor' GROUP BY deneme_sayisi) sub)
  ) INTO v_gebelik
  FROM hayvan_stat;
  RETURN jsonb_build_object(
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0,"tohumlanan":0,"sessiz":0}'::jsonb),
    'gebelik', COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_all":[],"deneme":[]}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════
-- Faz C: v_eligible view + sessiz hayvanlar RPC'leri
-- ═══════════════════════════════════════════════════════════════

-- ── v_eligible — tohumlama için uygun hayvanlar (buzağı hariç, 13+ ay) ──
CREATE OR REPLACE VIEW public.v_eligible AS
SELECT
  h.id, h.kupe_no, h.grup, h.padok,
  son_dogum.tarih                    AS son_dogum_tarihi,
  CURRENT_DATE - son_dogum.tarih     AS dogum_gun,
  son_aktivite.tarih                 AS son_aktivite_tarihi,
  CASE
    WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
    ELSE CASE
      WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END
  END                                AS sessiz_gun
FROM public.hayvanlar h
LEFT JOIN LATERAL (
  SELECT MAX(d.tarih) AS tarih FROM public.dogum d WHERE d.anne_id = h.id
) son_dogum ON true
LEFT JOIN LATERAL (
  SELECT MAX(tarih) AS tarih FROM (
    SELECT tarih FROM public.tohumlama WHERE hayvan_id = h.id
    UNION ALL
    SELECT tarih FROM public.kizginlik_log WHERE hayvan_id = h.id
  ) aktivite
) son_aktivite ON true
WHERE h.cinsiyet = 'Dişi'
  AND h.durum = 'Aktif'
  AND h.kisir IS NOT TRUE
  AND h.grup NOT ILIKE '%buzağı%' AND h.grup NOT ILIKE '%buzagi%'
  AND h.grup NOT ILIKE '%Küçük%' AND h.grup NOT ILIKE '%Kucuk%'
  AND (h.dogum_tarihi IS NULL OR h.dogum_tarihi <= CURRENT_DATE - INTERVAL '13 months')
  AND NOT EXISTS (SELECT 1 FROM public.tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe')
  AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = h.id AND c.status = 'active')
  AND (son_dogum.tarih IS NULL OR son_dogum.tarih < CURRENT_DATE - 55);
GRANT SELECT ON public.v_eligible TO anon, authenticated;

-- ── sessiz_hayvanlar_listele ──
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(
  p_padok   text    DEFAULT NULL,
  p_min_gun integer DEFAULT 55
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN (SELECT COALESCE(jsonb_agg(
    jsonb_build_object('hayvan_id', e.id, 'kupe_no', e.kupe_no, 'grup', e.grup, 'padok', e.padok,
      'sessiz_gun', COALESCE(e.sessiz_gun, 9999), 'son_aktivite', e.son_aktivite_tarihi)
    ORDER BY COALESCE(e.sessiz_gun, 9999) DESC), '[]'::jsonb)
  FROM public.v_eligible e
  WHERE (p_padok IS NULL OR e.padok = p_padok) AND COALESCE(e.sessiz_gun, 9999) >= p_min_gun);
END;
$$;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO anon, authenticated;

-- ── sessiz_hayvanlar_gorev_olustur ──
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_gorev_olustur()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count integer := 0; v_rec record;
BEGIN
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun FROM public.v_eligible e
    WHERE COALESCE(e.sessiz_gun, 9999) >= 55
      AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.id AND g.gorev_tipi = 'VETERINER_KONTROL' AND g.tamamlandi = false)
  LOOP
    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
    VALUES (gen_random_uuid(), v_rec.id, 'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', COALESCE(v_rec.sessiz_gun, 0), v_rec.kupe_no),
      CURRENT_DATE, false);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_gorev_olustur() TO anon, authenticated;

-- ── Gebelik kontrol görev iptali fix ─────────────────────────────────────────
-- Sorun: tohumlama_kaydet / sonuc_gebe / sonuc_bos, GEBELIK_KONTROL ve
--        TOHUMLAMA_HAZIRLIK görevlerini iptal etmiyordu.
-- Düzeltme: Sonuç yazılırken bekleyen kontrol görevleri otomatik iptal edilir,
--           sebep islem_log snapshot'a 'iptal_gorevler' olarak kaydedilir.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. tohumlama_kaydet (5-param) — eski kontrol görevlerini yeni kayıt öncesi iptal et
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
  v_hayvan            record;
  v_yas_gun           integer;
  v_deneme            integer;
  v_toh_id            uuid    := gen_random_uuid();
  v_gorev1_id         uuid    := gen_random_uuid();
  v_gorev2_id         uuid    := gen_random_uuid();
  v_islem_id          text    := gen_random_uuid()::text;
  v_stok_id           uuid;
  v_gebe_toh          record;
  v_uyari             text    := NULL;
  v_auto_close        boolean := false;
  v_iptal_gorev_ids   text[]  := '{}';
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

  -- Gebe kontrolü: 260+ gün auto-close, <260 gün blok
  SELECT * INTO v_gebe_toh FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ORDER BY tarih DESC LIMIT 1;

  IF FOUND THEN
    IF (CURRENT_DATE - v_gebe_toh.tarih::date) > 260 THEN
      UPDATE public.tohumlama SET sonuc = 'Doğum Yaptı' WHERE id = v_gebe_toh.id;
      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
      VALUES (gen_random_uuid()::text, 'DOGUM_OTOMATIK', p_hayvan_id, v_gebe_toh.id::text, 'tohumlama',
        jsonb_build_object('olusturulan', '[]'::jsonb, 'guncellenen', jsonb_build_array(
          jsonb_build_object('tablo', 'tohumlama', 'id', v_gebe_toh.id::text, 'degisim', 'sonuc: Gebe → Doğum Yaptı')
        )));
      v_uyari := '260+ günlük gebelik otomatik kapatıldı (Doğum Yaptı). Yeni tohumlama kaydediliyor.';
      v_auto_close := true;
    ELSE
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan zaten gebe — önce gebeliği kapatın');
    END IF;
  END IF;

  -- Önceki Bekliyor tohumlamaları Boş yap (event stack kuralı)
  UPDATE public.tohumlama SET sonuc = 'Boş'
  WHERE hayvan_id = p_hayvan_id AND sonuc = 'Bekliyor';

  -- Bekleyen gebelik kontrol görevlerini topla ve iptal et (yeni tohumlama — sebep: yeni_tohumlama)
  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  -- Deneme no: per-cycle
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND tarih > COALESCE(
      (SELECT MAX(tarih) FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
      '1900-01-01'::date
    );

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (v_gorev1_id, p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (v_gorev2_id, p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1, 'Tohumlama — ' || v_hayvan.kupe_no, false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1
  RETURNING id INTO v_stok_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'TOHUMLAMA', p_hayvan_id, v_toh_id::text, 'tohumlama',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', v_toh_id::text),
        jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev1_id::text),
        jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev2_id::text)
      ) || CASE WHEN v_stok_id IS NOT NULL
        THEN jsonb_build_array(jsonb_build_object('tablo', 'stok_hareket', 'id', v_stok_id::text))
        ELSE '[]'::jsonb END,
      'guncellenen', '[]'::jsonb,
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'yeni_tohumlama'
    )
  );

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh_id, 'deneme_no', v_deneme, 'islem_id', v_islem_id, 'uyari', v_uyari);
END;
$$;
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text) TO anon, authenticated;

-- 2. tohumlama_sonuc_gebe — Gebe atanınca bekleyen kontrol görevlerini iptal et
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_son_toh_id        text;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir');
  END IF;

  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY deneme_no DESC LIMIT 1 FOR UPDATE;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Gebe' WHERE id = v_toh.hayvan_id;

  -- Bekleyen gebelik kontrol görevlerini topla ve iptal et (sebep: gebe)
  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'GEBE_ATAMA', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
      ),
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'gebe'
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_gebe(text) TO anon, authenticated;

-- 3. tohumlama_sonuc_bos — Boş atanınca bekleyen kontrol görevlerini iptal et
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Boş' WHERE id = v_toh.hayvan_id;

  -- Bekleyen gebelik kontrol görevlerini topla ve iptal et (sebep: bos)
  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'TOHUMLAMA_SONUC', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
      ),
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'bos'
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_bos(text, text) TO anon, authenticated;

END;

-- ══════════════════════════════════════════════════════════════
-- Protokol Uyarı Sistemi (Task 1-11, 2026-06-03)
-- Yeni fonksiyonlar ve trigger'lar
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public._etken_kod_bul(
  p_stok_id text DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_name text;
  v_group_name text;
  v_active_ing text;
  v_stok_ad text;
  v_vaccine_name text;
BEGIN
  -- Aşı yolu
  IF p_vaccine_id IS NOT NULL THEN
    SELECT name INTO v_vaccine_name FROM public.vaccines WHERE id = p_vaccine_id;
    IF v_vaccine_name ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;
    RETURN NULL;
  END IF;

  -- İlaç yolu: stok → drug_products → drug_classes
  IF p_stok_id IS NOT NULL THEN
    SELECT s.urun_adi INTO v_stok_ad FROM public.stok s WHERE s.id = p_stok_id;

    SELECT dc.group_name, dc.class_name, dc.active_ingredient
    INTO v_group_name, v_class_name, v_active_ing
    FROM public.drug_products dp
    JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE dp.id = (
      SELECT drug_product_id FROM public.drug_administrations
      WHERE stok_id = p_stok_id LIMIT 1
    )
    OR dp.brand_name ILIKE '%' || COALESCE(v_stok_ad,'') || '%'
    LIMIT 1;

    -- Sınıf bazlı eşleşme
    IF v_class_name ILIKE '%oksitosin%' OR v_active_ing ILIKE '%oxytocin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%' OR v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%' THEN RETURN 'PG'; END IF;
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._gorev_dinle(
  p_hayvan_id text,
  p_etken_kod text,
  p_ref text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev_id text;
BEGIN
  IF p_etken_kod IS NULL OR p_hayvan_id IS NULL THEN
    RETURN;
  END IF;

  SELECT id INTO v_gorev_id
  FROM public.gorev_log
  WHERE hayvan_id = p_hayvan_id
    AND etken_kod = p_etken_kod
    AND tamamlandi = false
    AND iptal = false
  ORDER BY hedef_tarih ASC
  LIMIT 1;

  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true,
        tamamlanma_tarihi = now(),
        kapatan_ref = p_ref
    WHERE id = v_gorev_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_rota text,
  p_notlar text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_stok record;
  v_etken text;
  v_id uuid;
  v_kalan numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  IF p_notlar IS NULL OR TRIM(p_notlar) = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Not alanı zorunludur');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- Stok düşüm
  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid()::text, p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.hizli_uygulama_geri_al(
  p_uygulama_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uyg record;
  v_hayvan record;
BEGIN
  SELECT * INTO v_uyg FROM public.uygulama_log WHERE id = p_uygulama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Uygulama kaydı bulunamadı');
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_uyg.hayvan_id;

  -- Stok iade (ters hareket)
  IF v_uyg.stok_id IS NOT NULL THEN
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid()::text, v_uyg.stok_id, 'İade (Hızlı Uyg.)', -v_uyg.doz,
            'Geri Al — ' || COALESCE(v_hayvan.kupe_no, v_uyg.hayvan_id), false);
  END IF;

  -- Bu uygulama ile kapanan görevi tekrar aç
  UPDATE public.gorev_log
  SET tamamlandi = false,
      tamamlanma_tarihi = NULL,
      kapatan_ref = NULL
  WHERE kapatan_ref = 'uygulama_log:' || p_uygulama_id::text;

  DELETE FROM public.uygulama_log WHERE id = p_uygulama_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Protokol eksik tara scanner (Task 11)
CREATE OR REPLACE FUNCTION public.protokol_eksik_tara()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb := '[]'::jsonb;
  v_today date := CURRENT_DATE;
  v_rec record;
  v_found boolean;
  v_tamamlanma timestamptz;
  v_kapatan text;
BEGIN
  -- A. DOĞUM SONRASI PROTOKOL
  FOR v_rec IN
    SELECT d.id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi, h.kupe_no, h.grup, a.gun, a.ek, a.aciklama
    FROM public.dogum d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    CROSS JOIN (VALUES
      (0,'OKSITOSIN','Doğum günü: Oksitosin'),(0,'ADEMIN','Doğum günü: Ademin'),(0,'KALSIYUM','Doğum günü: Kalsiyum'),
      (2,'PG','2. Gün PG'),(11,'PG','11. Gün PG'),(25,'PG','25. Gün PG'),
      (53,'ADEMIN','53. Gün: Ademin'),(53,'E_VIT','53. Gün: Yeldif'),(54,'E_VIT','54. Gün: Yeldif')
    ) AS a(gun,ek,aciklama)
    WHERE d.tarih >= v_today - 70 AND d.tarih <= v_today
  LOOP
    DECLARE
      v_hedef date := v_rec.dogum_tarihi + v_rec.gun;
      v_gecikme int; v_durum text;
    BEGIN
      IF v_hedef > v_today + 7 THEN CONTINUE; END IF;
      v_found := false; v_tamamlanma := NULL; v_kapatan := NULL;

      SELECT true,g.tamamlanma_tarihi,g.kapatan_ref INTO v_found,v_tamamlanma,v_kapatan
      FROM gorev_log g WHERE g.hayvan_id=v_rec.hayvan_id AND g.etken_kod=v_rec.ek AND g.tamamlandi=true AND g.hedef_tarih BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1;

      IF NOT v_found THEN SELECT true INTO v_found FROM uygulama_log u WHERE u.hayvan_id=v_rec.hayvan_id AND u.etken_kod=v_rec.ek AND u.tarih BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1; END IF;
      IF NOT v_found THEN SELECT true INTO v_found FROM drug_administrations da JOIN treatment_days td ON td.id=da.treatment_day_id JOIN cases c ON c.id=td.case_id WHERE c.animal_id=v_rec.hayvan_id AND public._etken_kod_bul(da.stok_id,NULL)=v_rec.ek AND da.created_at::date BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1; END IF;
      IF NOT v_found THEN SELECT true INTO v_found FROM protokol_dismiss pd WHERE pd.hayvan_id=v_rec.hayvan_id AND pd.etken_kod=v_rec.ek AND pd.protokol='DOGUM_PROTOKOL' LIMIT 1; END IF;

      v_gecikme := v_today - v_hedef;
      IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now()-interval '24 hours' THEN v_durum:='tamamlandi';
      ELSIF v_found THEN CONTINUE;
      ELSIF v_gecikme >= 0 THEN v_durum:='eksik'; ELSE v_durum:='yaklasan'; END IF;

      v_result := v_result || jsonb_build_object('hayvan_id',v_rec.hayvan_id,'kupe_no',v_rec.kupe_no,'grup',v_rec.grup,'protokol','DOGUM_PROTOKOL','adim',v_rec.aciklama,'etken_kod',v_rec.ek,'hedef_tarih',v_hedef,'gecikme_gun',GREATEST(v_gecikme,0),'durum',v_durum,'tamamlanma_tarihi',v_tamamlanma,'kapatan_ref',v_kapatan);
    END;
  END LOOP;

  -- B. İLERI GEBE PROTOKOL
  FOR v_rec IN
    SELECT t.id,t.hayvan_id,t.tarih::date AS toh_tarihi,h.kupe_no,h.grup
    FROM public.tohumlama t JOIN public.hayvanlar h ON h.id=t.hayvan_id AND h.durum='Aktif'
    WHERE t.sonuc='Gebe' AND (v_today-t.tarih::date)>=230
  LOOP
    DECLARE v_a record;
    BEGIN
      FOR v_a IN SELECT * FROM (VALUES(240,'ROTA','Rota-Corona Aşısı'),(260,'ADEMIN','SC Ademin uygulaması'),(265,'E_VIT','IM E Vitamini uygulaması')) AS t(gun,ek,aciklama) LOOP
        DECLARE v_hedef date:=v_rec.toh_tarihi+v_a.gun; v_gecikme int; v_durum text;
        BEGIN
          IF v_hedef>v_today+7 THEN CONTINUE; END IF;
          v_found:=false; v_tamamlanma:=NULL; v_kapatan:=NULL;
          SELECT true,g.tamamlanma_tarihi,g.kapatan_ref INTO v_found,v_tamamlanma,v_kapatan FROM gorev_log g WHERE g.hayvan_id=v_rec.hayvan_id AND g.etken_kod=v_a.ek AND g.tamamlandi=true AND g.hedef_tarih BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1;
          IF NOT v_found AND v_a.ek='ROTA' THEN SELECT true INTO v_found FROM vaccination_log vl JOIN vaccines v ON v.id=vl.vaccine_id WHERE vl.animal_id=v_rec.hayvan_id AND v.name ILIKE '%Rota%' AND vl.vaccination_date BETWEEN v_hedef-7 AND v_hedef+7 LIMIT 1; END IF;
          IF NOT v_found THEN SELECT true INTO v_found FROM uygulama_log u WHERE u.hayvan_id=v_rec.hayvan_id AND u.etken_kod=v_a.ek AND u.tarih BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1; END IF;
          IF NOT v_found THEN SELECT true INTO v_found FROM protokol_dismiss pd WHERE pd.hayvan_id=v_rec.hayvan_id AND pd.etken_kod=v_a.ek AND pd.protokol='ILERI_GEBE_PROTOKOL' LIMIT 1; END IF;
          v_gecikme:=v_today-v_hedef;
          IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma>=now()-interval '24 hours' THEN v_durum:='tamamlandi'; ELSIF v_found THEN CONTINUE; ELSIF v_gecikme>=0 THEN v_durum:='eksik'; ELSE v_durum:='yaklasan'; END IF;
          v_result:=v_result||jsonb_build_object('hayvan_id',v_rec.hayvan_id,'kupe_no',v_rec.kupe_no,'grup',v_rec.grup,'protokol','ILERI_GEBE_PROTOKOL','adim',v_a.aciklama,'etken_kod',v_a.ek,'hedef_tarih',v_hedef,'gecikme_gun',GREATEST(v_gecikme,0),'durum',v_durum,'tamamlanma_tarihi',v_tamamlanma,'kapatan_ref',v_kapatan);
        END;
      END LOOP;
    END;
  END LOOP;

  -- C. KIZGINLIK TAKİBİ
  FOR v_rec IN
    SELECT d.id,d.anne_id AS hayvan_id,d.tarih AS dogum_tarihi,h.kupe_no,h.grup
    FROM public.dogum d JOIN public.hayvanlar h ON h.id=d.anne_id AND h.durum='Aktif'
    WHERE (v_today-d.tarih) BETWEEN 55 AND 70
  LOOP
    DECLARE v_hedef date:=v_rec.dogum_tarihi+58; v_gecikme int:=v_today-v_hedef; v_durum text;
    BEGIN
      v_found:=false; v_tamamlanma:=NULL; v_kapatan:=NULL;
      SELECT true,g.tamamlanma_tarihi INTO v_found,v_tamamlanma FROM gorev_log g WHERE g.hayvan_id=v_rec.hayvan_id AND g.aciklama ILIKE '%kizginlik%' AND g.tamamlandi=true AND g.hedef_tarih BETWEEN v_hedef-3 AND v_hedef+7 LIMIT 1;
      IF NOT v_found THEN SELECT true INTO v_found FROM kizginlik_log k WHERE k.hayvan_id=v_rec.hayvan_id AND k.tarih>=v_rec.dogum_tarihi+50 LIMIT 1; END IF;
      IF NOT v_found THEN SELECT true INTO v_found FROM tohumlama t WHERE t.hayvan_id=v_rec.hayvan_id AND t.tarih>=v_rec.dogum_tarihi+50 LIMIT 1; END IF;
      IF NOT v_found THEN SELECT true INTO v_found FROM protokol_dismiss pd WHERE pd.hayvan_id=v_rec.hayvan_id AND pd.protokol='KIZGINLIK_TAKIP' LIMIT 1; END IF;
      IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma>=now()-interval '24 hours' THEN v_durum:='tamamlandi'; ELSIF v_found THEN CONTINUE; ELSIF v_gecikme>=0 THEN v_durum:='eksik'; ELSE v_durum:='yaklasan'; END IF;
      v_result:=v_result||jsonb_build_object('hayvan_id',v_rec.hayvan_id,'kupe_no',v_rec.kupe_no,'grup',v_rec.grup,'protokol','KIZGINLIK_TAKIP','adim','58-63. gun kizginlik takibi','etken_kod',NULL,'hedef_tarih',v_hedef,'gecikme_gun',GREATEST(v_gecikme,0),'durum',v_durum,'tamamlanma_tarihi',v_tamamlanma,'kapatan_ref',v_kapatan);
    END;
  END LOOP;

  RETURN v_result;
END;
$$;

-- Dinleme trigger fonksiyonları + trigger'lar
CREATE OR REPLACE FUNCTION public.fn_dinle_vaccination()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
BEGIN
  v_etken := public._etken_kod_bul(NULL, NEW.vaccine_id);
  IF v_etken IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.animal_id, v_etken, 'vaccination_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_dinle_vaccination ON public.vaccination_log;
CREATE TRIGGER trg_dinle_vaccination AFTER INSERT ON public.vaccination_log FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_vaccination();

CREATE OR REPLACE FUNCTION public.fn_dinle_uygulama()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.etken_kod IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.hayvan_id, NEW.etken_kod, 'uygulama_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_dinle_uygulama ON public.uygulama_log;
CREATE TRIGGER trg_dinle_uygulama AFTER INSERT ON public.uygulama_log FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_uygulama();

CREATE OR REPLACE FUNCTION public.fn_dinle_drug_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
  v_animal_id text;
BEGIN
  v_etken := public._etken_kod_bul(NEW.stok_id, NULL);
  IF v_etken IS NULL THEN RETURN NEW; END IF;
  SELECT c.animal_id INTO v_animal_id
  FROM public.treatment_days td JOIN public.cases c ON c.id = td.case_id
  WHERE td.id = NEW.treatment_day_id;
  IF v_animal_id IS NOT NULL THEN
    PERFORM public._gorev_dinle(v_animal_id, v_etken, 'drug_admin:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_dinle_drug_admin ON public.drug_administrations;
CREATE TRIGGER trg_dinle_drug_admin AFTER INSERT ON public.drug_administrations FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_drug_admin();

-- Scanner performans index'leri (Review Fix — Task 17)
CREATE INDEX IF NOT EXISTS idx_dogum_anne_tarih ON public.dogum(anne_id, tarih);
CREATE INDEX IF NOT EXISTS idx_tohumlama_hayvan_sonuc_tarih ON public.tohumlama(hayvan_id, sonuc, tarih);
