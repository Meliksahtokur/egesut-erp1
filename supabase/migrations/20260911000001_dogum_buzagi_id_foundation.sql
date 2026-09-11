-- 20260911000001_dogum_buzagi_id_foundation.sql
-- Goal: G-20260911-PEDIGREE-P1-TEMEL / Task 0.5 (gate G0b)
-- Kontrat: .claude/specs/2026-09-11-dogum-buzagi-id-teklif.md (Rev 2, owner KABUL 2026-09-11)
-- Plan: .claude/plans/2026-09-10-pedigree-genetics-impl.md L339-377 (Task 0.5)
--
-- 1) dogum.buzagi_id text NULL -> hayvanlar(id) ON DELETE SET NULL
-- 2) partial unique index dogum_buzagi_id_uidx (WHERE buzagi_id IS NOT NULL)
-- 3) dogum_kaydet ayni transaction'da yazar (canli demo govdesi pg_get_functiondef(20705) + tek UPDATE satiri)
-- 4) konservatif backfill (spec 2b): yalniz kupe exact + tarih eslesme + TEK aday -> yazar;
--    cok-aday / tarih-uyumsuz / aday-yok -> NULL kalir, 4 sayac RAISE NOTICE ile raporlanir
-- 5) geri_al uyumu: prosedurel degisiklik YOK — geri_al whitelist'inde dogum yoktur; calf
--    DELETE'inde SET NULL FK'i kendisi temizler (canli geri_al govdesi 20725 uzerinde dogrulandi)
--
-- Replay-safe: her adim idempotent (column/constraint guard, IF NOT EXISTS index, OR REPLACE fn,
-- backfill yalniz buzagi_id IS NULL satirlara yazar).

BEGIN;

-- (1) kolon + FK — SET NULL (Rev 2 duzeltme 1): calf silinirse dogum kaydi KALIR, bag NULL olur
DO $mig$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'dogum' AND column_name = 'buzagi_id'
  ) THEN
    ALTER TABLE public.dogum
      ADD COLUMN buzagi_id text NULL
      CONSTRAINT dogum_buzagi_id_fkey
      REFERENCES public.hayvanlar(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.dogum'::regclass AND conname = 'dogum_buzagi_id_fkey'
  ) THEN
    ALTER TABLE public.dogum
      ADD CONSTRAINT dogum_buzagi_id_fkey
      FOREIGN KEY (buzagi_id) REFERENCES public.hayvanlar(id) ON DELETE SET NULL;
  END IF;
END
$mig$;

-- (2) partial unique (Rev 2 duzeltme 2): iki dogum satiri ayni calf'i claim edemez
CREATE UNIQUE INDEX IF NOT EXISTS dogum_buzagi_id_uidx
  ON public.dogum (buzagi_id)
  WHERE buzagi_id IS NOT NULL;

COMMENT ON COLUMN public.dogum.buzagi_id IS
  'Yavru buzaginin hayvanlar.id baglantisi (Task 0.5, spec Rev 2). ON DELETE SET NULL: dogum tarihsel olaydir, calf silinirse kayit kalir bag NULL olur. Konservatif backfill: yalniz kupe exact + dogum.tarih = hayvanlar.dogum_tarihi + tek aday AUTO yazilir.';

-- (3) dogum_kaydet — canli demo DB govdesi (pg_get_functiondef, oid 20705) + tek UPDATE satiri
-- (asagidaki 'buzagi_id baglama' yorumu); geri kalan byte-ayni. CREATE OR REPLACE ACL'leri korur.
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

  -- buzagi_id baglama (Task 0.5, spec Rev 2 par.2): dogum satirini buzagiya ayni transaction icinde bagla
  UPDATE public.dogum SET buzagi_id = v_buzagi_id WHERE id = v_dogum_id;

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
    SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
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
    'gorev_sayisi', (CASE WHEN v_anne_yan_etki THEN 10 ELSE 0 END) + 7,
    'anne_inst_id', v_anne_inst_id,
    'buzagi_inst_id', v_buzagi_inst_id, 'tohumlama_kapatildi', v_sayac,
    'coklu_dogum', v_ikinci, 'olay_id', v_olay_id, 'yavru_sirasi', v_yavru_sirasi
  );
END;
$function$;

-- (3b) Konservatif backfill (spec 2b, Rev 2 duzeltme 3):
--   auto          = kupe_no exact TEK aday AND hayvanlar.dogum_tarihi = dogum.tarih AND calf baska dogum tarafindan claim edilmemis
--   cok-aday      = kupe ile 2+ hayvanlar adayi VEYA calf baska bir dogum tarafindan claim edilmis
--   tarih-uyumsuz = TEK aday var ama dogum_tarihi eslesmiyor (NULL dahil)
--   aday-yok      = kupa ile hic hayvanlar adayi yok
-- Eski 4 kriterli ranking burada KULLANILMAZ (sadece suggested_candidate olabilir).
-- Idempotent: yalniz buzagi_id IS NULL satirlara dokunur; ikinci kosum yazmaz.
DO $mig$
DECLARE
  r        record;
  v_aday   integer;
  v_calf   text;
  v_auto   integer := 0;
  v_cok    integer := 0;
  v_tarih  integer := 0;
  v_yok    integer := 0;
BEGIN
  FOR r IN
    SELECT d.id, d.yavru_kupe, d.tarih
    FROM public.dogum d
    WHERE d.buzagi_id IS NULL
  LOOP
    SELECT count(*) INTO v_aday
    FROM public.hayvanlar h
    WHERE h.kupe_no = r.yavru_kupe;

    IF v_aday = 0 THEN v_yok := v_yok + 1; CONTINUE; END IF;
    IF v_aday > 1 THEN v_cok := v_cok + 1; CONTINUE; END IF;

    SELECT h.id INTO v_calf
    FROM public.hayvanlar h
    WHERE h.kupe_no = r.yavru_kupe
      AND h.dogum_tarihi = r.tarih;

    IF v_calf IS NULL THEN v_tarih := v_tarih + 1; CONTINUE; END IF;

    -- unique index oncesi guven: ayni calf'i baska bir dogum zaten claim ettiyse yazma
    IF EXISTS (
      SELECT 1 FROM public.dogum d2
      WHERE d2.buzagi_id = v_calf AND d2.id <> r.id
    ) THEN
      v_cok := v_cok + 1; CONTINUE;
    END IF;

    UPDATE public.dogum SET buzagi_id = v_calf WHERE id = r.id;
    v_auto := v_auto + 1;
  END LOOP;

  RAISE NOTICE 'buzagi_id backfill: auto=% cok-aday=% tarih-uyumsuz=% aday-yok=%',
    v_auto, v_cok, v_tarih, v_yok;
END
$mig$;

COMMIT;
