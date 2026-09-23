-- ============================================================================
-- Migration: 20260923000002_ovsync_pg_sema
-- Tarih: 2026-09-23
-- Otorite: docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md (R3)
--          Kanonik taban: canlı prod pg_get_functiondef (2026-09-23).
--
-- NE YAPAR (şema + backfill + koruma; iş kuralı fonksiyonları BURADA DEĞİL):
--   S-1  protokol_ayar bayrak satırı 'ovsync_pg_kurallari_aktif' (deger=0 =
--        KAPALI) + public._ovsync_pg_aktif() okuyucusu.
--   S-2  drug_classes.farmakolojik_sinif_kodu + drug_classes.sistem kolonları;
--        6 sistem etken madde backfill'i (PGF2A/GNRH/OKSITOSIN/PROGESTERON);
--        Kloprostenol etken_kod NULL → 'PG'; trg_drug_classes_sistem_koru
--        koruma trigger'ı; drug_class_ekle yeni imza (+p_farmakolojik_sinif_kodu
--        DEFAULT NULL, NULL ise aynı group_name+class_name'den miras).
--        drug_class_guncelle / drug_class_sil gövdelerine dokunulmaz: sistem
--        satırında trigger RAISE eder (ok:false değil, PostgREST hatası döner).
--        _pg_urun_durumu → 20260923000003.
--   S-3  tedavi_sablonu.protokol_ailesi (+ "Ovsynch" şablon(lar)ı → 'OVSYNC');
--        cases.source_template_id / protocol_family / protocol_snapshot /
--        close_reason; cases backfill (tek aileli hastalık eşlemesi).
--        tedavi_sablon_uygula → 20260923000005.
--   S-4  pg_application_event tablosu (constraint/index/RLS/GRANT). Kapı ve
--        olay fonksiyonları → 20260923000003.
--
-- DAVRANIŞ: bayrak kapalı doğar; bu dosyadaki tek davranış değişiklikleri
--   bayraktan bağımsızdır ve SPEC'te öyle tanımlıdır: (a) sistem etken madde
--   koruması, (b) drug_class_ekle'nin kod mirası. Eski frontend çağrısı
--   (isimli 3/4 argüman) yeni imzaya DEFAULT ile çözülür.
--
-- İDEMPOTENT: IF NOT EXISTS / DO-blok varlık kontrolü / DROP IF EXISTS /
--   CREATE OR REPLACE; backfill'ler yalnız hedef durumda olmayan satırı günceller.
--   İç transaction deyimi yok.
--
-- ROLLBACK (elle, ters sırayla; veri kaybı: yalnız bu dosyanın eklediği kolonlar):
--   DROP TABLE IF EXISTS public.pg_application_event;
--   ALTER TABLE public.cases DROP COLUMN IF EXISTS close_reason,
--     DROP COLUMN IF EXISTS protocol_snapshot, DROP COLUMN IF EXISTS protocol_family,
--     DROP COLUMN IF EXISTS source_template_id;
--   ALTER TABLE public.tedavi_sablonu DROP COLUMN IF EXISTS protokol_ailesi;
--   DROP FUNCTION IF EXISTS public.drug_class_ekle(text, text, text, uuid, text);
--     + canlı 4'lü gövdeyi (drug_class_ekle(text,text,text,uuid)) yeniden yarat,
--       REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated, service_role.
--   DROP TRIGGER IF EXISTS trg_drug_classes_sistem_koru ON public.drug_classes;
--   DROP FUNCTION IF EXISTS public._trg_drug_classes_sistem_koru();
--   ALTER TABLE public.drug_classes DROP COLUMN IF EXISTS sistem,
--     DROP COLUMN IF EXISTS farmakolojik_sinif_kodu;
--   (Kloprostenol etken_kod='PG' geri alınmaz: _etken_kod_bul ILIKE fallback'i
--    bugün de 'PG' döndürüyor — davranış eşdeğer.)
--   DROP FUNCTION IF EXISTS public._ovsync_pg_aktif();
--   DELETE FROM public.protokol_ayar WHERE anahtar = 'ovsync_pg_kurallari_aktif';
--   NOTIFY pgrst, 'reload schema';
--   Not: 000003..000006 bu nesnelere bağımlıdır; önce onlar geri alınmalı.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════════
-- S-1  Özellik bayrağı
-- ════════════════════════════════════════════════════════════════════════════
-- protokol_ayar PK = (anahtar) [canlı pg_constraint: protokol_ayar_pkey] →
-- ON CONFLICT (anahtar) geçerli. Açma: protokol_ayar_guncelle('ovsync_pg_kurallari_aktif', 1)
-- — frontend yayınından SONRA, sahip kapısı.

INSERT INTO public.protokol_ayar (anahtar, deger, birim, min_deger, max_deger, aciklama)
VALUES ('ovsync_pg_kurallari_aktif', 0, 'bool', 0, 1,
        'Ovsync/PG/tohumlama kuralları (PG kapısı, PG+48s tohumlama görevi, '
        'tohumlama ile senkronizasyon vakası kapanışı, D50 ilk tohumlama zinciri). '
        '0 = kapalı (eski davranış), 1 = açık.')
ON CONFLICT (anahtar) DO NOTHING;

CREATE OR REPLACE FUNCTION public._ovsync_pg_aktif()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT COALESCE(
    (SELECT deger FROM public.protokol_ayar
      WHERE anahtar = 'ovsync_pg_kurallari_aktif') = 1,
    false);
$function$;

COMMENT ON FUNCTION public._ovsync_pg_aktif() IS
  'S-1: ovsync_pg_kurallari_aktif bayrağı (deger=1 → true; satır yok/0 → false). İç yardımcı.';

-- İç yardımcı: postgres default ACL yeni fonksiyona authenticated=X veriyor
-- [canlı pg_default_acl] → açıkça geri alınır.
REVOKE ALL ON FUNCTION public._ovsync_pg_aktif() FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- S-2  Katalog: farmakolojik sınıf kodu + sistem etken maddeleri
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.drug_classes ADD COLUMN IF NOT EXISTS farmakolojik_sinif_kodu text;
ALTER TABLE public.drug_classes ADD COLUMN IF NOT EXISTS sistem boolean NOT NULL DEFAULT false;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.drug_classes'::regclass
                    AND conname  = 'drug_classes_farmakolojik_sinif_kodu_check') THEN
    ALTER TABLE public.drug_classes
      ADD CONSTRAINT drug_classes_farmakolojik_sinif_kodu_check
      CHECK (farmakolojik_sinif_kodu IN ('PGF2A','GNRH','OKSITOSIN','PROGESTERON'));
  END IF;
END $$;

COMMENT ON COLUMN public.drug_classes.farmakolojik_sinif_kodu IS
  'S-2: farmakolojik sınıf (PGF2A|GNRH|OKSITOSIN|PROGESTERON). PG kimliğinin birincil kaynağı.';
COMMENT ON COLUMN public.drug_classes.sistem IS
  'S-2: true → sistem etken maddesi; kimlik alanları trg_drug_classes_sistem_koru ile korunur.';

-- ── Backfill (koruma trigger'ından ÖNCE; yeniden koşumda trigger varsa bakım
--    kaçışı açılır, blok sonunda kapatılır) ─────────────────────────────────
-- Canlı ön-ölçüm 2026-09-23: 52 drug_classes satırı; desenler tam 6 satıra
-- (hepsi 'Hormonlar ve Üreme İlaçları') eşleşir; Dinoprost etken_kod='PG',
-- Oksitosin etken_kod='OKSITOSIN', Kloprostenol sodyum etken_kod NULL.
DO $$
DECLARE
  r        record;
  v_upd    integer;
  v_eslesen integer;
BEGIN
  PERFORM set_config('egesut.katalog_bakim', 'on', true);

  FOR r IN
    SELECT * FROM (VALUES
      ('PGF2A',       ARRAY['Dinoprost%','Kloprostenol%'], 2),
      ('GNRH',        ARRAY['Gonadorelin%','Buserelin%'],  2),
      ('OKSITOSIN',   ARRAY['Oksitosin%'],                 1),
      ('PROGESTERON', ARRAY['Progesteron%'],               1)
    ) AS t(kod, desenler, beklenen)
  LOOP
    SELECT count(*) INTO v_eslesen
      FROM public.drug_classes
     WHERE active_ingredient ILIKE ANY (r.desenler);

    UPDATE public.drug_classes
       SET farmakolojik_sinif_kodu = r.kod,
           sistem = true
     WHERE active_ingredient ILIKE ANY (r.desenler)
       AND (farmakolojik_sinif_kodu IS DISTINCT FROM r.kod OR sistem IS NOT TRUE);
    GET DIAGNOSTICS v_upd = ROW_COUNT;

    RAISE NOTICE 'S-2 backfill %: eşleşen % satır, güncellenen % satır (beklenen eşleşme %)',
      r.kod, v_eslesen, v_upd, r.beklenen;
    IF v_eslesen <> r.beklenen THEN
      RAISE WARNING 'S-2 backfill %: beklenen % eşleşme, bulunan % (desenler %) — katalog elle kontrol edilmeli',
        r.kod, r.beklenen, v_eslesen, r.desenler;
    END IF;
  END LOOP;

  -- Kloprostenol etken_kod NULL → 'PG' (_gorev_dinle tutarlılığı; bugün ILIKE
  -- fallback'iyle zaten 'PG' çözülüyor → davranış eşdeğer).
  UPDATE public.drug_classes
     SET etken_kod = 'PG'
   WHERE active_ingredient ILIKE 'Kloprostenol%'
     AND etken_kod IS NULL;
  GET DIAGNOSTICS v_upd = ROW_COUNT;
  RAISE NOTICE 'S-2 backfill Kloprostenol etken_kod NULL→PG: % satır (ilk koşumda beklenen 1)', v_upd;

  SELECT count(*) INTO v_eslesen
    FROM public.drug_classes
   WHERE active_ingredient ILIKE ANY (ARRAY['Dinoprost%','Kloprostenol%'])
     AND etken_kod IS DISTINCT FROM 'PG';
  IF v_eslesen > 0 THEN
    RAISE WARNING 'S-2: % PGF2A satırı etken_kod<>PG taşıyor (NULL değil, farklı kod) — elle kontrol',
      v_eslesen;
  END IF;

  PERFORM set_config('egesut.katalog_bakim', 'off', true);
END $$;

-- ── Koruma trigger'ı ──────────────────────────────────────────────────────
-- Kapsam (SPEC S-2 + mimar R3 eki): HER satırda UPDATE ile farmakolojik_sinif_kodu/sistem
-- değişimi reddi (KATALOG_SINIF_KODU_KILITLI; INSERT serbest). OLD.sistem satırında DELETE reddi; UPDATE'te class_name,
-- active_ingredient, etken_kod, farmakolojik_sinif_kodu, sistem değişirse reddi.
-- group_name ve kategori_id serbesttir (grup yeniden adlandırma çalışır).
-- Bakım kaçışı: SET LOCAL egesut.katalog_bakim = 'on'.
-- drug_class_guncelle/sil üzerinden gelen reddin mesajı PostgREST hatası olarak
-- aynen döner: 'SISTEM_ETKEN_MADDE: <madde> sistem kaydıdır, değiştirilemez/silinemez'.
CREATE OR REPLACE FUNCTION public._trg_drug_classes_sistem_koru()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $function$
BEGIN
  IF COALESCE(current_setting('egesut.katalog_bakim', true), '') = 'on' THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;

  -- Tüm satırlar (sistem olsun olmasın): sınıf kodu ve sistem bayrağı UPDATE ile
  -- değiştirilemez. INSERT serbest (drug_class_ekle mirası INSERT ile çalışır).
  IF TG_OP = 'UPDATE'
     AND (NEW.farmakolojik_sinif_kodu IS DISTINCT FROM OLD.farmakolojik_sinif_kodu
          OR NEW.sistem IS DISTINCT FROM OLD.sistem) THEN
    RAISE EXCEPTION 'KATALOG_SINIF_KODU_KILITLI: %', OLD.active_ingredient
      USING ERRCODE = 'P0001',
            DETAIL  = 'drug_classes.id=' || OLD.id::text
                      || ' farmakolojik_sinif_kodu/sistem UPDATE ile değiştirilemez',
            HINT    = 'Katalog bakımı migration ile (egesut.katalog_bakim=on) yapılır.';
  END IF;

  IF OLD.sistem IS NOT TRUE THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'SISTEM_ETKEN_MADDE: % sistem kaydıdır, değiştirilemez/silinemez',
      OLD.active_ingredient
      USING ERRCODE = 'P0001',
            DETAIL  = 'drug_classes.id=' || OLD.id::text || ' (DELETE)',
            HINT    = 'Sistem etken maddeleri migration ile yönetilir.';
  END IF;

  IF NEW.class_name              IS DISTINCT FROM OLD.class_name
  OR NEW.active_ingredient       IS DISTINCT FROM OLD.active_ingredient
  OR NEW.etken_kod               IS DISTINCT FROM OLD.etken_kod
  OR NEW.farmakolojik_sinif_kodu IS DISTINCT FROM OLD.farmakolojik_sinif_kodu
  OR NEW.sistem                  IS DISTINCT FROM OLD.sistem THEN
    RAISE EXCEPTION 'SISTEM_ETKEN_MADDE: % sistem kaydıdır, değiştirilemez/silinemez',
      OLD.active_ingredient
      USING ERRCODE = 'P0001',
            DETAIL  = 'drug_classes.id=' || OLD.id::text || ' (UPDATE)',
            HINT    = 'Sistem etken maddeleri migration ile yönetilir.';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public._trg_drug_classes_sistem_koru() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_drug_classes_sistem_koru ON public.drug_classes;
CREATE TRIGGER trg_drug_classes_sistem_koru
  BEFORE UPDATE OR DELETE ON public.drug_classes
  FOR EACH ROW EXECUTE FUNCTION public._trg_drug_classes_sistem_koru();

-- ── drug_class_ekle: yeni imza (+p_farmakolojik_sinif_kodu DEFAULT NULL) ────
-- Taban: canlı drug_class_ekle(text,text,text,uuid) gövdesi (davranış aynen;
-- eklenen: kod doğrulama + miras + SET search_path). Frontend çağrıları
-- (js/ui.js _dcAddGroup/_dcAddClass/_dcAddIngredient) isimli p_* argümanlarla
-- 3/4 argüman gönderir → yeni imzaya DEFAULT ile çözülür.
DROP FUNCTION IF EXISTS public.drug_class_ekle(text, text, text, uuid);

CREATE OR REPLACE FUNCTION public.drug_class_ekle(
  p_group_name text,
  p_class_name text,
  p_active_ingredient text,
  p_kategori_id uuid DEFAULT NULL::uuid,
  p_farmakolojik_sinif_kodu text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_id  uuid;
  v_kod text := NULLIF(upper(btrim(p_farmakolojik_sinif_kodu)), '');
BEGIN
  IF p_group_name IS NULL OR p_group_name = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Grup adı zorunlu');
  END IF;
  IF p_active_ingredient IS NULL OR p_active_ingredient = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Etken madde adı zorunlu');
  END IF;
  IF v_kod IS NOT NULL
     AND v_kod NOT IN ('PGF2A','GNRH','OKSITOSIN','PROGESTERON') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Geçersiz farmakolojik sınıf kodu: ' || p_farmakolojik_sinif_kodu);
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.drug_classes
    WHERE group_name = p_group_name
      AND COALESCE(class_name,'') = COALESCE(p_class_name,'')
      AND active_ingredient = p_active_ingredient
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kombinasyon zaten mevcut');
  END IF;

  -- Miras ("kategoriden alır"): kod verilmediyse aynı group_name + class_name
  -- altındaki kodlu satırlardan TEK bir kod varsa o alınır; çelişkili ya da
  -- hiç kod yoksa NULL kalır.
  IF v_kod IS NULL THEN
    SELECT CASE WHEN count(DISTINCT dc.farmakolojik_sinif_kodu) = 1
                THEN min(dc.farmakolojik_sinif_kodu) END
      INTO v_kod
      FROM public.drug_classes dc
     WHERE dc.group_name = p_group_name
       AND COALESCE(dc.class_name,'') = COALESCE(NULLIF(p_class_name,''),'')
       AND dc.farmakolojik_sinif_kodu IS NOT NULL;
  END IF;

  v_id := gen_random_uuid();
  INSERT INTO public.drug_classes
    (id, group_name, class_name, active_ingredient, kategori_id, farmakolojik_sinif_kodu)
  VALUES
    (v_id, p_group_name, NULLIF(p_class_name,''), p_active_ingredient, p_kategori_id, v_kod);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mesaj', 'Etken madde eklendi',
                            'farmakolojik_sinif_kodu', v_kod);
END;
$function$;

-- ACL canlıdaki 4'lü imzanın proacl'ı ile aynı: {authenticated=X, service_role=X}
-- (DROP ACL'i siler; kabul DB DROP öncesi proacl ile doğrulandı).
REVOKE ALL ON FUNCTION public.drug_class_ekle(text, text, text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.drug_class_ekle(text, text, text, uuid, text) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- S-3  Vaka provenance (yalnız şema + backfill)
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.tedavi_sablonu ADD COLUMN IF NOT EXISTS protokol_ailesi text;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.tedavi_sablonu'::regclass
                    AND conname  = 'tedavi_sablonu_protokol_ailesi_check') THEN
    ALTER TABLE public.tedavi_sablonu
      ADD CONSTRAINT tedavi_sablonu_protokol_ailesi_check
      CHECK (protokol_ailesi ~ '^[A-Z][A-Z0-9_]*$');
  END IF;
END $$;

COMMENT ON COLUMN public.tedavi_sablonu.protokol_ailesi IS
  'S-3: senkronizasyon protokol ailesi (ör. OVSYNC). NULL = protokol değil.';

ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS source_template_id uuid;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS protocol_family    text;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS protocol_snapshot  jsonb;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS close_reason       text;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.cases'::regclass
                    AND conname  = 'cases_source_template_id_fkey') THEN
    ALTER TABLE public.cases
      ADD CONSTRAINT cases_source_template_id_fkey
      FOREIGN KEY (source_template_id) REFERENCES public.tedavi_sablonu(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.cases'::regclass
                    AND conname  = 'cases_close_reason_check') THEN
    ALTER TABLE public.cases
      ADD CONSTRAINT cases_close_reason_check
      CHECK (close_reason IN ('ERKEN_KAPANIS','TOHUMLAMA'));
  END IF;
END $$;

COMMENT ON COLUMN public.cases.source_template_id IS 'S-3: vakayı kuran şablon (ilk uygulama; ezilmez).';
COMMENT ON COLUMN public.cases.protocol_family    IS 'S-3: senkronizasyon protokol ailesi; NULL = bilinmiyor/protokol değil (otomatik kapanmaz).';
COMMENT ON COLUMN public.cases.protocol_snapshot  IS 'S-3: şablon uygulama anındaki anlık görüntü; backfill edilmez.';
COMMENT ON COLUMN public.cases.close_reason       IS 'S-7: ERKEN_KAPANIS | TOHUMLAMA.';

-- ── Backfill: şablon ailesi ───────────────────────────────────────────────
-- Canlı ön-ölçüm 2026-09-23: tek eşleşme a152f7fe… "Sağmal inek: Ovsynch-56 + çift PGs".
DO $$
DECLARE
  v_eslesen integer;
  v_upd     integer;
  v_aktif   integer;
BEGIN
  SELECT count(*) INTO v_eslesen FROM public.tedavi_sablonu WHERE ad ILIKE '%ovsync%';

  UPDATE public.tedavi_sablonu
     SET protokol_ailesi = 'OVSYNC'
   WHERE ad ILIKE '%ovsync%'
     AND protokol_ailesi IS NULL;
  GET DIAGNOSTICS v_upd = ROW_COUNT;
  RAISE NOTICE 'S-3 backfill tedavi_sablonu OVSYNC: eşleşen %, güncellenen % (canlı beklenti 1)',
    v_eslesen, v_upd;

  IF v_eslesen = 0 THEN
    RAISE WARNING 'S-3: "Ovsynch" adlı şablon bulunamadı — protokol_ailesi backfill 0 satır; S-8 OVSYNC_SABLON_BELIRSIZ verecek';
  END IF;

  SELECT count(*) INTO v_aktif FROM public.tedavi_sablonu
   WHERE protokol_ailesi = 'OVSYNC' AND aktif IS TRUE;
  IF v_aktif <> 1 THEN
    RAISE WARNING 'S-3: aktif OVSYNC şablon sayısı % (S-8 tam 1 bekler)', v_aktif;
  END IF;
END $$;

-- ── Backfill: vakalar ─────────────────────────────────────────────────────
-- Kural (SPEC S-3): hastalığı sablon_hastalik_eslem'de protokol_ailesi dolu
-- TEK şablona eşlenen vakalar (aktif + kapalı) → protocol_family o aile.
-- source_template_id: gorev_log.kaynak 'TEDAVI_SABLON_TOHUMLAMA:<case>:<sablon>'
-- (MANUEL hariç — tedavi_sablonu.id ile join'lenemez) aynı aileden tek şablona
-- çözülürse. Snapshot backfill edilmez. Yalnız protocol_family NULL vakalar
-- (yeni tedavi_sablon_uygula provenance'ı ezilmez; yeniden koşum no-op).
-- Canlı ön-ölçüm 2026-09-23: "Ovsync Protokol" → 11 aktif + 7 kapalı = 18
-- OVSYNC; bunlardan 7'sinde (1 aktif + 6 kapalı) source_template_id çözülür.
DO $$
DECLARE
  v_upd     integer;
  v_src     integer;
  v_aktif   integer;
  v_kapali  integer;
  v_belirsiz integer;
BEGIN
  WITH aile AS (
    SELECT e.disease_id, min(t.protokol_ailesi) AS protokol_ailesi
      FROM public.sablon_hastalik_eslem e
      JOIN public.tedavi_sablonu t ON t.id = e.sablon_id
     WHERE t.protokol_ailesi IS NOT NULL
     GROUP BY e.disease_id
    HAVING count(DISTINCT e.sablon_id) = 1
  ), hedef AS (
    SELECT c.id AS case_id, a.protokol_ailesi,
           (SELECT CASE WHEN count(DISTINCT t2.id) = 1 THEN min(t2.id::text)::uuid END
              FROM public.gorev_log g
              JOIN public.tedavi_sablonu t2
                ON t2.id::text = split_part(g.kaynak, ':', 3)
             WHERE g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || c.id::text || ':%'
               AND t2.protokol_ailesi = a.protokol_ailesi) AS sablon_id
      FROM public.cases c
      JOIN aile a ON a.disease_id = c.disease_id
     WHERE c.protocol_family IS NULL
  )
  UPDATE public.cases c
     SET protocol_family    = h.protokol_ailesi,
         source_template_id = COALESCE(c.source_template_id, h.sablon_id)
    FROM hedef h
   WHERE c.id = h.case_id;
  GET DIAGNOSTICS v_upd = ROW_COUNT;

  SELECT count(*) FILTER (WHERE status = 'active'),
         count(*) FILTER (WHERE status = 'closed'),
         count(*) FILTER (WHERE source_template_id IS NOT NULL)
    INTO v_aktif, v_kapali, v_src
    FROM public.cases
   WHERE protocol_family = 'OVSYNC';

  RAISE NOTICE 'S-3 backfill cases: güncellenen %; OVSYNC toplam aktif % / kapalı % / source_template_id dolu % (canlı beklenti 11/7/7)',
    v_upd, v_aktif, v_kapali, v_src;

  IF v_aktif + v_kapali = 0 THEN
    RAISE WARNING 'S-3: hiç OVSYNC vakası yok — sablon_hastalik_eslem eşlemesi kontrol edilmeli';
  END IF;

  -- Birden çok aileli şablona eşlenen hastalıklar belirsiz kalır (protocol_family NULL).
  SELECT count(*) INTO v_belirsiz FROM (
    SELECT e.disease_id
      FROM public.sablon_hastalik_eslem e
      JOIN public.tedavi_sablonu t ON t.id = e.sablon_id
     WHERE t.protokol_ailesi IS NOT NULL
     GROUP BY e.disease_id
    HAVING count(DISTINCT e.sablon_id) > 1) x;
  IF v_belirsiz > 0 THEN
    RAISE WARNING 'S-3: % hastalık birden çok protokol şablonuna eşli — vakaları protocol_family NULL kaldı',
      v_belirsiz;
  END IF;
END $$;


-- ════════════════════════════════════════════════════════════════════════════
-- S-4  pg_application_event (yalnız tablo)
-- ════════════════════════════════════════════════════════════════════════════
-- Tenant-scoped operasyonel veri → farm_id (FK YOK; .claude/farm-id-discipline.md).
-- hayvanlar.id text PK [canlı hayvanlar_pkey]. ack_tohumlama_id SPEC gereği
-- text (tohumlama.id canlıda uuid — karşılaştırmada ::text kullanılmalı).

CREATE TABLE IF NOT EXISTS public.pg_application_event (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id             uuid        NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  source_type         text        NOT NULL
    CONSTRAINT pg_application_event_source_type_check
    CHECK (source_type IN ('HIZLI_UYGULAMA','TEDAVI_SEANS','TOPLU_ILAC')),
  source_id           text        NOT NULL,
  hayvan_id           text        NOT NULL
    CONSTRAINT pg_application_event_hayvan_id_fkey REFERENCES public.hayvanlar(id),
  stok_id             text        NULL,
  drug_product_id     uuid        NULL,
  occurred_at         timestamptz NOT NULL,
  karar               text        NOT NULL
    CONSTRAINT pg_application_event_karar_check
    CHECK (karar IN ('ALLOW','ACK_PENDING')),
  ack_tohumlama_id    text        NULL,
  ack_gerekce         text        NULL,
  gorev_sonuc         text        NULL
    CONSTRAINT pg_application_event_gorev_sonuc_check
    CHECK (gorev_sonuc IN ('OLUSTU','VWP_ICINDE','UYGUNSUZ','KAPALI')),
  gorev_sonuc_detay   text        NULL,
  tohumlama_gorev_id  uuid        NULL,
  geri_alindi_at      timestamptz NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pg_application_event_source_key UNIQUE (source_type, source_id)
);

CREATE INDEX IF NOT EXISTS idx_pg_application_event_farm_hayvan_ts
  ON public.pg_application_event (farm_id, hayvan_id, occurred_at DESC);

COMMENT ON TABLE public.pg_application_event IS
  'S-4: gerçekleşmiş PG uygulaması kaydı (hızlı uygulama / tedavi seansı / toplu ilaç). '
  'Yazma yalnız SECURITY DEFINER fonksiyonlarla; istemciye yalnız SELECT.';

-- RLS (USING true — repo politikası, pedigree kalıbı)
ALTER TABLE public.pg_application_event ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS allow_all ON public.pg_application_event;
CREATE POLICY allow_all ON public.pg_application_event
  FOR ALL USING (true) WITH CHECK (true);

-- Grant'lar: postgres default ACL yeni tabloya authenticated=arwdDxtm veriyor
-- [canlı pg_default_acl] → açıkça geri al; yalnız SELECT.
REVOKE ALL ON public.pg_application_event FROM anon, authenticated;
GRANT SELECT ON public.pg_application_event TO authenticated;


NOTIFY pgrst, 'reload schema';

-- EOF 20260923000002
