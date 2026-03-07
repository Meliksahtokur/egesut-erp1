-- ══════════════════════════════════════════════════════════════
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
