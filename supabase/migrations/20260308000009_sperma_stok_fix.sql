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
