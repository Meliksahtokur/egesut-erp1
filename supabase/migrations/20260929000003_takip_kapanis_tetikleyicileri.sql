-- ============================================================================
-- Migration: 20260929000003_takip_kapanis_tetikleyicileri (P3a katmanı)
-- Tarih: 2026-09-29 · Plan: docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md P3a
--   (plan.md:378-397 birebir; G-20260930-OVSYNC-TAKIP-IMPL; P3b aynı dosyayı
--    DEVRALIR — tek migration, iki madde; P3b madde gövdeleri bu zarfta YOKTUR)
-- Spec: design.md §6c.3; DEGISMEZ 4; §10c #1; §10h H3 (MK9-T geri alındı); MK9-K
--   (§10g — tetikleyiciler bayraktan bağımsız); GOREV zarfı açık sözleşme maddesi
--   B (gorev_log_cycle_guard TAKIP_MUAYENE muafiyeti — P2b bulgusu,
--   impl-P2b-DONE.md:118)
--
-- Kapsam (P3a — 4 otomatik kapanış tetikleyicisi + 1 muafiyet):
--   1) tohumlama AFTER INSERT        → SESSİZ kapanış  (neden=YENI_TOHUMLAMA)
--   2) pg_application_event BEFORE INSERT → ONAYLI ret (RAISE TAKIP_ACIK:{...})
--   3) cases BEFORE INSERT (yalnız Ovsync) → ONAYLI ret (RAISE TAKIP_ACIK:{...})
--   4) hayvanlar çıkışı              → kapanış (neden=CIKIS; mevcut
--      _trg_hayvan_cikis_gorev_iptal gövdesine APPEND — 20260626000030 davranışı
--      birebir korunur, canlı gövde pg_get_functiondef ile okundu)
--   B) gorev_log_cycle_guard muafiyeti: TAKIP_MUAYENE görevleri Boş-tohumlama
--      iptal koşulundan MUAF (canlı gövde pg_get_functiondef ile okundu;
--      append: yalnız IF koşuluna tek AND)
--
-- Ad-çözümü kararı (cases tetikleyicisi — GOREV zarfı açık sözleşmesi, demo
--   ölçümü 2026-09-30):
--   • demo diseases: tek Ovsync öbeği 'Ovsync Protokol' (id c346e115-…, 35 vaka);
--     'Ovsync' adında hastalık yok [OBSERVED demo diseases ILIKE '%ovsync%'].
--   • demo cases.protocol_family: 148/148 NULL (p5b S-3 backfill demo'da etkisiz)
--     [OBSERVED demo GROUP BY] → tek başına ölçüt OLAMAZ.
--   • mevcut otorite public._ovsync_hastalik_mi(uuid) (şablon eşlemesi,
--     20260925000018 — kısır guard'ın kullandığı fonksiyon) demo'da FALSE döner
--     [OBSERVED demo çağrı: f] (demo'da sablon_hastalik_eslem→protokol_ailesi
--     eşlemesi yok) → tek başına demo'da yetmez.
--   KARAR — üç-bacaklı OR (fazla-ret güvenli tarafa hata yapar; az-ret kapanış
--   kaçırır): NEW.protocol_family='OVSYNC'  (yeni yolların açık damgası)
--            OR public._ovsync_hastalik_mi(NEW.disease_id) (prod otorite)
--            OR diseases.name ILIKE 'ovsync%' (demo gerçekliği — 'Ovsync' VE
--               'Ovsync Protokol' adlarını kapsar; demo ILIKE '%ovsync%' 1 kayıt)
--
-- Tetikleyici kilit sözleşmesi (§10h H3 — MK9-T GERİ ALINDI):
--   • Kapatıcı tetikleyici (tohumlama AFTER INSERT) hayvan kilidi ALMAZ; kapanışı
--     public._takip_kapat üstlenir (yalnız hedef gorev_log satırı FOR NO KEY
--     UPDATE; zaten kapalıya dokunmaz — idempotent; 20260929000002:131-166).
--   • BEFORE INSERT ret tetikleyicileri YALNIZ OKUR + RAISE eder; kilit almaz.
--   • Yön tutarlılığı (H3): AFTER INSERT anında tohumlama satırı ekleyen
--     transaction'ın kilidindedir; tetikleyici ondan SONRA gorev_log satırını
--     kilitler → "tohumlama takip gorev_log'dan ÖNCE" sırası korunur.
--   • Tetikleyicilere p_takip_onay parametresi EKLENMEZ (DEGISMEZ 4 — onay RPC
--     yüzeyinde; P3b).
--
-- MK9-K: TÜM tetikleyiciler ovsync_pg_kurallari_aktif bayrağını OKUMAZ — bayrak
--   KAPALIyken de çalışırlar (eski yollar tabloya yazdığında kapanış yine ateşlenir).
--
-- RAISE payload: P2b sarmal RPC ile birebir `TAKIP_ACIK:{"muayene_tarihi":…,
--   "muayene_saat":…}` [20260929000002:914-917,996-998]; H5 makine-okunur alan
--   sabitlemesi P3b başında yapılır (goal açık sözleşme girdisi) — P3a mevcut
--   kalıbı kopyalar, yeni format TANIMLAMAZ.
--
-- ACL (DEGISMEZ 8): 5 trigger fonksiyonuna da anon/PUBLIC/authenticated EXECUTE
--   YOK — REVOKE ALL ... FROM PUBLIC, anon, authenticated; GRANT YAZILMAZ
--   (kalıp: iç helper 20260925000001:78; trigger mekanizması EXECUTE hakkı
--   aramaz — create-time dışında).
--
-- farm_id: yeni tablo/kolon YOK; tetikleyiciler gorev_log (farm_id'siz) okur —
--   farm_id filtresi YOK (P2a D8 kararıyla aynı; §14 retrofit kapsam dışı).
--
-- Revert (sahip kapısıyla, sırayla):
--   DROP TRIGGER IF EXISTS trg_takip_yeni_tohumlama_kapat ON public.tohumlama;
--   DROP TRIGGER IF EXISTS trg_takip_pg_olay_kapisi ON public.pg_application_event;
--   DROP TRIGGER IF EXISTS trg_takip_ovsync_case_kapisi ON public.cases;
--   DROP FUNCTION public._trg_takip_yeni_tohumlama_kapat();
--   DROP FUNCTION public._trg_takip_pg_olay_kapisi();
--   DROP FUNCTION public._trg_takip_ovsync_case_kapisi();
--   -- _trg_hayvan_cikis_gorev_iptal: 20260626000030:3-14 gövdesi CREATE OR REPLACE
--   -- gorev_log_cycle_guard: 20260522000002 gövdesi CREATE OR REPLACE (muafiyetsiz)
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) tohumlama AFTER INSERT → SESSİZ kapanış (YENI_TOHUMLAMA) ──────────
-- Plan.md:386 birebir: tüm giriş yolları (RPC + REST) tablo düzeyinde kapsanır;
-- RPC gövdesine GÖMÜLMEZ. Sessiz: islem_log İZİ YAZILMAZ (_takip_kapat zaten
-- yazmaz). Keşif kilitsiz (H4 kalıbı); kilit+kilit-sonrası-yeniden-durum
-- kontrolü _takip_kapat içinde (FOR NO KEY UPDATE + idempotent branch).
CREATE OR REPLACE FUNCTION public._trg_takip_yeni_tohumlama_kapat()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev_id uuid;
BEGIN
  IF NEW.hayvan_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Açık TAKIP_MUAYENE (P1 'takiptekiler' koşuluyla birebir:
  -- gorev_tipi + !tamamlandi + !iptal; 20260929000001:288-294)
  SELECT g.id INTO v_gorev_id
    FROM public.gorev_log g
   WHERE g.hayvan_id = NEW.hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;

  IF FOUND THEN
    -- MK9-N/H3: hayvan kilidi ALMAZ — _takip_kapat yalnız gorev_log satırını
    -- kilitler; zaten kapalıysa DOKUNMAZ (idempotent — çift olay yarışı T-24).
    PERFORM public._takip_kapat(v_gorev_id, 'YENI_TOHUMLAMA');
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_takip_yeni_tohumlama_kapat ON public.tohumlama;
CREATE TRIGGER trg_takip_yeni_tohumlama_kapat
  AFTER INSERT ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public._trg_takip_yeni_tohumlama_kapat();

COMMENT ON FUNCTION public._trg_takip_yeni_tohumlama_kapat() IS
  'P3a tetikleyici 1 (plan.md:386): yeni tohumlama hayvanin acik TAKIP_MUAYENE gorevini SESSIZ kapatir (takip_kapanis_nedeni=YENI_TOHUMLAMA). MK9-N/H3: hayvan kilidi YOK; kapanis _takip_kapat ile (idempotent). MK9-K: bayrak okumaz.';

-- ── 2) pg_application_event BEFORE INSERT → ONAYLI ret ───────────────────
-- Plan.md:387 birebir: açık takip varken PG olay INSERT'i o an OLMAZ;
-- UI onay penceresi açar (P3b onay yolu); onayla RPC önce _takip_kapat
-- (neden='PG') yapar → tetikleyici açık takip GÖRMEZ, geçer. Hızlı PG kapısı
-- reddi bu tetikleyiciyle de aynı mesajı taşır: TAKIP_ACIK:{muayene_tarihi,
-- muayene_saat}. Yalnız OKUR + RAISE — kilit YOK (H3). source_type
-- (HIZLI_UYGULAMA/TEDAVI_SEANS/TOPLU_ILAC) ayrımı YAPMAZ: üç PG yolu tek kapı.
CREATE OR REPLACE FUNCTION public._trg_takip_pg_olay_kapisi()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev record;
BEGIN
  SELECT g.hedef_tarih, g.hedef_saat INTO v_gorev
    FROM public.gorev_log g
   WHERE g.hayvan_id = NEW.hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'TAKIP_ACIK:%',
      jsonb_build_object(
        'muayene_tarihi', v_gorev.hedef_tarih,
        'muayene_saat',   v_gorev.hedef_saat
      )::text;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_takip_pg_olay_kapisi ON public.pg_application_event;
CREATE TRIGGER trg_takip_pg_olay_kapisi
  BEFORE INSERT ON public.pg_application_event
  FOR EACH ROW EXECUTE FUNCTION public._trg_takip_pg_olay_kapisi();

COMMENT ON FUNCTION public._trg_takip_pg_olay_kapisi() IS
  'P3a tetikleyici 2 (plan.md:387): acik TAKIP_MUAYENE varken PG olay INSERT''ini RAISE TAKIP_ACIK:{muayene_tarihi,muayene_saat} ile REDDER (onay yolu once _takip_kapat yapar). Yalniz OKUR + RAISE — kilit YOK (H3). Uc PG yolu tek kapı.';

-- ── 3) cases BEFORE INSERT (yalnız Ovsync) → ONAYLI ret ──────────────────
-- Plan.md:388 birebir + ad-çözümü kararı (dosya başlığı): üç-bacaklı OR.
-- Onay yolu: vaka açma RPC'si önce _takip_kapat (neden='OVSYNC') yapar →
-- tetikleyici açık takip GÖRMEZ, geçer. Yalnız OKUR + RAISE — kilit YOK.
-- Sıra notu: cases'te mevcut BEFORE INSERT tetikleyicisi trg_cases_kisir_ovsync
-- ('k' < 't' → ÖNCE) kısır hayvanda vaka açılışını TAKIP_ACIK'tan önce reddeder
-- (§18.5 esnetilmez — ret yine de garanti; mesaj kısır gerekçesidir).
CREATE OR REPLACE FUNCTION public._trg_takip_ovsync_case_kapisi()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev  record;
  v_ovsync boolean;
BEGIN
  -- Ad-çözümü (demo ölçümüyle — dosya başlığı): üç-bacaklı OR
  SELECT COALESCE(NEW.protocol_family, '') = 'OVSYNC'
         OR public._ovsync_hastalik_mi(NEW.disease_id)
         OR EXISTS (
              SELECT 1 FROM public.diseases d
               WHERE d.id = NEW.disease_id
                 AND d.name ILIKE 'ovsync%'
            )
    INTO v_ovsync;

  IF NOT COALESCE(v_ovsync, false) THEN
    RETURN NEW;  -- Ovsync-olmayan vaka: kapı YOK (sessiz geçiş)
  END IF;

  SELECT g.hedef_tarih, g.hedef_saat INTO v_gorev
    FROM public.gorev_log g
   WHERE g.hayvan_id = NEW.animal_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'TAKIP_ACIK:%',
      jsonb_build_object(
        'muayene_tarihi', v_gorev.hedef_tarih,
        'muayene_saat',   v_gorev.hedef_saat
      )::text;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_takip_ovsync_case_kapisi ON public.cases;
CREATE TRIGGER trg_takip_ovsync_case_kapisi
  BEFORE INSERT ON public.cases
  FOR EACH ROW EXECUTE FUNCTION public._trg_takip_ovsync_case_kapisi();

COMMENT ON FUNCTION public._trg_takip_ovsync_case_kapisi() IS
  'P3a tetikleyici 3 (plan.md:388): YALNIZ Ovsync kaynakli vaka INSERT''ini acik TAKIP_MUAYENE varken RAISE TAKIP_ACIK:{...} ile REDDER. Ovsync olcutu 3-bacakli OR: protocol_family=''OVSYNC'' OR _ovsync_hastalik_mi(disease_id) OR diseases.name ILIKE ''ovsync%'' (demo olcum karari — dosya basligi). Yalniz OKUR + RAISE.';

-- ── 4) hayvan çıkışı → kapanış (neden=CIKIS) ─────────────────────────────
-- Plan.md:389 birebir: mevcut _trg_hayvan_cikis_gorev_iptal (20260626000030)
-- canlı gövdesi pg_get_functiondef ile okundu (2026-09-30 demo); gövde
-- BİREBİR korunur + TAKIP_MUAYENE satırlarına takip_kapanis_nedeni='CIKIS'
-- UPDATE'i APPEND edilir. İkinci UPDATE yalnız birinci UPDATE'in az önce
-- iptal ettiği satırlara iz yazar (kapatan_ref='hayvan-cikis' + takip
-- nedeni hâlâ boş) → idempotent; başka yoldan (PG/OVSYNC/GEBE_BULUNDU)
-- kapanmış takiplere DOKUNMAZ. search_path/security: canlı gövde birebir
-- (eklenmedi — append-only sözleşmesi).
CREATE OR REPLACE FUNCTION public._trg_hayvan_cikis_gorev_iptal()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.durum <> 'Aktif' AND OLD.durum = 'Aktif' THEN
    UPDATE public.gorev_log
       SET iptal = true, kapatan_ref = 'hayvan-cikis'
     WHERE hayvan_id = NEW.id
       AND NOT tamamlandi AND NOT iptal;

    -- P3a (append): takip kapanış nedeni — yalnız bu çıkışın az önce
    -- kapatığı TAKIP_MUAYENE satırlarına (20260626000030 davranışı + iz).
    UPDATE public.gorev_log
       SET takip_kapanis_nedeni = 'CIKIS'
     WHERE hayvan_id = NEW.id
       AND gorev_tipi = 'TAKIP_MUAYENE'
       AND iptal = true
       AND kapatan_ref = 'hayvan-cikis'
       AND takip_kapanis_nedeni IS NULL;
  END IF;
  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public._trg_hayvan_cikis_gorev_iptal() IS
  'P3a: cikista acik tum gorevler iptal (20260626000030 davranisi birebir) + TAKIP_MUAYENE satirlarina takip_kapanis_nedeni=CIKIS izi (append). Idempotent; baska yoldan kapanmis takibe dokunmaz.';

-- ── B) gorev_log_cycle_guard — TAKIP_MUAYENE muafiyeti (GOREV zarfı Görev B)
-- Canlı gövde pg_get_functiondef ile okundu (2026-09-30 demo): ref_tohumlama_id
-- dolu her görev, bağlı tohumlama sonuc NOT IN (Bekliyor,Gebe) ise
-- NEW.iptal := true. TAKIP_MUAYENE tasarım gereği Boş tohumlamaya bağlanır →
-- kurulduğu an iptal ediliyordu (impl-P2b-DONE.md:118 — P1 takiptekiler kümesi
-- görevi göremiyor, zincir tıkalı). Muafiyet: yalnız IF koşuluna tek AND —
-- mevcut davranış (diğer görev tiplerinde Boş/Abort-ref görev iptali + SECURITY
-- DEFINER + search_path'siz biçim) BİREBİR korunur.
CREATE OR REPLACE FUNCTION public.gorev_log_cycle_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.ref_tohumlama_id IS NOT NULL
     AND COALESCE(NEW.gorev_tipi, '') <> 'TAKIP_MUAYENE' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tohumlama
      WHERE id::text = NEW.ref_tohumlama_id
        AND sonuc IN ('Bekliyor', 'Gebe')
    ) THEN
      NEW.iptal := true;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.gorev_log_cycle_guard() IS
  'P3a Gorev B: ref_tohumlama_id dolu gorev, bagli tohumlama Bekliyor/Gebe degilse iptal — TAKIP_MUAYENE MUAF (takip tasarim geregi Bos tohumlamaya baglanir; impl-P2b-DONE.md:118). Diger gorev tiplerinde mevcut davranis birebir.';

-- ── ACL (DEGISNEZ 8) — trigger fonksiyonlarına EXECUTE YOK ────────────────
-- Yeni 3 + yeniden-tanımlanan 2 fonksiyon: PUBLIC/anon/authenticated REVOKE;
-- GRANT YOK (iç tetikleyici yardımcıları; kalıp 20260925000001:78).
-- NOT: _trg_hayvan_cikis_gorev_iptal ve gorev_log_cycle_guard canlıda varsayılan
-- PUBLIC EXECUTE taşiyordu (20260626000030/20260522000002 REVOKE'suz) — bu
-- migration REVOKE ile DEGISNEZ 8 hizasına çeker (tetikleyici mekanizması
-- EXECUTE hakkı aramaz; davranış değişmez).
REVOKE ALL ON FUNCTION public._trg_takip_yeni_tohumlama_kapat() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._trg_takip_pg_olay_kapisi() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._trg_takip_ovsync_case_kapisi() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._trg_hayvan_cikis_gorev_iptal() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.gorev_log_cycle_guard() FROM PUBLIC, anon, authenticated;

COMMIT;

-- EOF 20260929000003_takip_kapanis_tetikleyicileri (P3a)
