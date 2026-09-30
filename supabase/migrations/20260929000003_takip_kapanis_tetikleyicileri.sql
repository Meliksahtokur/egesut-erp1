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

-- ============================================================================
-- P3b — giriş kapıları (plan.md:399-457 birebir; impl-P3b zarfı, 2026-09-30)
--   jenerik gorev_tamamla guard'ı + D4 birleşik preflight + C2 onay parametre
--   geçişi + H4 standart deseni + MK9 start_first düzeltmesi + C4 kizginlik
--   fail-closed kapısı + C5 imza/ACL geçişi.
--   Canlı zemin: 7 RPC'nin TÜM gövdeleri pg_get_functiondef ile demo'dan
--   okundu (2026-09-30) — migration ≁ canlı olabileceği için düzenlemeler
--   canlı gövde üzerinden yapıldı (imzalar plan.md:413-419 tablosuyla birebir
--   doğrulandı [OBSERVED demo pg_get_function_identity_arguments]).
--
-- H6 gorev_tamamla guard'ı: YALNIZ tamamlama dalı (p_iptal IS NOT TRUE) +
--   yalnız GEBELIK_KONTROL/TAKIP_MUAYENE; KİLİTSİZ tek okuma, FOR UPDATE'ten
--   ÖNCE (mevcut kilit sırası GT6:39-42/84-87 DEĞİŞMEZ — §10h H1: eski yol,
--   kilit düzenine dokunulmaz). T5 iptal dalı (js/ui.js:1841-1844 offline
--   replay) ve SUTTEN_KESME/padok dalları guard DIŞI (üç dal kapsama matrisi
--   prova kanıtıyla).
--
-- D4 birleşik preflight (hizli_uygulama/seans_tamamla): mevcut _pg_kapi çağrı
--   noktasının yanında; TAKIP_ACIK keşfi KİLİTSİZ (yalnız okur); birleşik
--   payload P2b sarmal deseniyle birebir (20260929000002:986-998):
--   'PG_KAPI:TAKIP_ACIK:' + {pg_kapi:_pg_kapi_detay, takip_acik:{muayene_tarihi,
--   muayene_saat}}; yalnız takip engeli → 'TAKIP_ACIK:' + {muayene_tarihi,
--   muayene_saat}. Onaylı → _takip_kapat(neden='PG') İLK YAZMADAN ÖNCE
--   (uygulama_log INSERT / tdu UPDATE'ten önce; tetikleyici güvenlik ağı kalır).
--
-- D4 bulk (bulk_ilac/vaka_toplu_ac — satır-sonucu deseni): mevcut döngü/kilit
--   DEĞİŞMEZ; fonksiyon başında açık-takipliler KİLİTSİZ okunur; p_takip_onaylar
--   DIŞINDA açık-takipli satır İŞLENMEZ + satır sonucu 'takip_acik[]' listesine
--   {hayvan_id, kupe_no|kupe, kod:'TAKIP_ACIK', muayene_tarihi, muayene_saat};
--   onaylılar için _takip_kapat(neden='PG'|'OVSYNC') satır işlenmeden hemen
--   ÖNCE (satır alt-transaction'ının İLK deyimi — satır hatasında kapanış da
--   geri alınır). bulk_ilac dönüşüne ayrıca 'takip_onay_listesi' eklenir:
--   hayvan-bazlı birleşik {hayvan_id, pg_kapi_karar, takip_acik, takip_bilgi}.
--   retry = onaylı alt kümeyle yeni çağrı; boyut sınırı YOK (mevcut 200 aynen).
--   Liste-dışı onay id → RAISE 'TAKIP_ONAY_KUME_UYUMSUZ:{liste_disi_id}'.
--
-- MK9 start_first düzeltmesi (plan.md:424-428): görev KİLİTSİZ okunur (hızlı
--   retler aynı sırada: GOREV_BULUNAMADI → GOREV_TIPI_UYUMSUZ → zaten →
--   OVSYNC_ERKEN) → hayvan İLK kilit FOR NO KEY UPDATE (MK9-N: hayvan satırında
--   ASLA FOR UPDATE) → protokol_instance okuması (kilit değil) → görev FOR NO
--   KEY UPDATE + tip/tamamlandi/iptal yeniden doğrulama → muafiyet karar+zincir
--   birebir → akışın kalanı v_g2 üzerinden birebir. Eski ihlal: görev FOR
--   UPDATE (ST17:44/ST26:53) → hayvan FOR UPDATE (ST17:62/ST26:82) = AB/BA.
--
-- C4 kizginlik_vaka_ac (plan.md:452): TANIDAN BAĞIMSIZ fail-closed kapı —
--   H4 deseni (kilitsiz kızgınlık keşfi + aynı hızlı ret → hayvan NKU →
--   kızgınlık satırı FOR UPDATE + yeniden doğrulama) → açık takip + onaysız →
--   TAKIP_ACIK (P3a tetikleyici ağı keyfi p_tani'yi KAÇIRIR — kapı gövdede
--   ZORUNLU); onaylı → _takip_kapat(neden='OVSYNC') vaka INSERT'ten önce.
--   Eski kaskad (diseases çözümü/INSERT, cases INSERT, kizginlik/tohumlama
--   UPDATE, islem_log) birebir.
--
-- C2 imza geçişi (7 RPC): eski overload DROP + yeni CREATE OR REPLACE +
--   ACL yeniden (REVOKE PUBLIC,anon + GRANT authenticated,service_role — canlı
--   proacl demo'da doğrulandı: postgres+authenticated+service_role, anon/PUBLIC
--   yok [OBSERVED 2026-09-30]; hedef ACL mevcut durumu korur). Yeni
--   parametreler DEFAULT'lu → mevcut SQL/REST/JS çağrıları geriye-uyumlu
--   (atlas: gorev_tamamla 7 JS çağıran, kizginlik 1 — imza-değişen 6 RPC'nin
--   çağıranları P4'te bağlanır).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ═══ 1) gorev_tamamla — H6 guard (imza DEĞİŞMEZ → ACL aynen kalır) ═══════
CREATE OR REPLACE FUNCTION public.gorev_tamamla(p_gorev_id text, p_padok_hedef text DEFAULT NULL::text, p_iptal boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev record; v_hayvan record; v_snapshot jsonb;
  v_stok_dusuldu boolean := false; v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb; v_guncellenen jsonb := '[]'::jsonb;
  v_padok_id uuid;
  v_hedef_padok text;
  v_yeni_grup text;
  v_guard_tip text;
BEGIN
  -- ═══ P3b H6 guard — MUAYENE_SONUC_GEREKLI (plan.md:407 birebir) ═══
  -- Yalnız TAMAMLAMA dalı (p_iptal false/NULL) + yalnız muayene tipleri.
  -- Kilitsiz tek okuma — ilk (kilitli) tablo erişiminden ÖNCE; mevcut kilit
  -- sırası (gorev_log FOR UPDATE → koşullu hayvanlar FOR UPDATE) DEĞİŞMEZ
  -- (§10h H1: gorev_tamamla eski yoldur). Görev yalnız muayene sonuc RPC'si
  -- (tohumlama_bos_ve_devam muayene yolu) üzerinden kapanır (§18.17).
  -- p_iptal=true dalı (T5 offline-replay iptali) ve SUTTEN_KESME/padok
  -- dalları bu guard'a GİRMEZ — davranışları aynen korunur.
  IF p_iptal IS NOT TRUE THEN
    SELECT gorev_tipi INTO v_guard_tip
      FROM public.gorev_log
     WHERE id = p_gorev_id::uuid;
    IF v_guard_tip IN ('GEBELIK_KONTROL', 'TAKIP_MUAYENE') THEN
      RAISE EXCEPTION 'MUAYENE_SONUC_GEREKLI:%', v_guard_tip;
    END IF;
  END IF;

  SELECT * INTO v_gorev
    FROM public.gorev_log
   WHERE id = p_gorev_id::uuid
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id; END IF;

  -- ═══ T5 branşı (cila 20260925000006) — offline kuyruk replay'i iptal-PATCH'i
  --     İPTAL olarak kapatır; mevcut mantık ikame EDİLMEZ. Konum: NOT FOUND
  --     kontrolünün hemen ardından, tamamlandi/iptal erken-dönüşlerinden ÖNCE.
  --     REVIEW DÜŞÜK-1 düzeltmesi (2026-09-25): tamamlandi-guard'ı — zaten
  --     tamamlanmış (gerçek tamamlanma) görev, sonradan replay edilen bayat
  --     iptal-PATCH'le İPTAL'e çevrİLMEZ; erken-dönüşe düşer ('zaten tamamlanmış').
  --     İç IF NOT FOUND ölü koddur (dış FOR UPDATE zaten raise eder) — kaldırıldı.
  IF p_iptal IS TRUE AND v_gorev.tamamlandi IS NOT TRUE THEN
    UPDATE public.gorev_log
       SET tamamlandi = true,
           tamamlanma_tarihi = COALESCE(tamamlanma_tarihi, now()),
           iptal = true
     WHERE id = p_gorev_id::uuid;
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
    VALUES ('GOREV_TAMAMLA', v_gorev.hayvan_id, p_gorev_id, 'gorev_log',
            '{"olusturulan":[],"guncellenen":[],"silinen":[]}'::jsonb,
            'Görev iptal edildi (offline replay)');
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'iptal', true);
  END IF;
  IF v_gorev.tamamlandi THEN RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış'); END IF;
  IF v_gorev.iptal THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz'); END IF;

  IF v_gorev.gorev_tipi = 'SUTTEN_KESME' AND v_gorev.hayvan_id IS NOT NULL THEN
    PERFORM public.buzagi_sutten_kesme_onayla(v_gorev.hayvan_id);
    UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=COALESCE(tamamlanma_tarihi, now())
      WHERE id=p_gorev_id::uuid AND tamamlandi=false;
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'sutten_kesme', true);
  END IF;

  v_hedef_padok := COALESCE(NULLIF(btrim(p_padok_hedef), ''), NULLIF(btrim(v_gorev.padok_hedef), ''));

  IF v_gorev.gorev_tipi = 'PADOK_DEGISIM'
     AND v_gorev.hayvan_id IS NOT NULL
     AND v_hedef_padok IS NULL THEN
    RAISE EXCEPTION 'Padok değişim görevinin hedef padoku boş: %', p_gorev_id
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_hedef_padok IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan
      FROM public.hayvanlar
     WHERE id = v_gorev.hayvan_id
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Görevin hayvanı bulunamadı: %', v_gorev.hayvan_id
        USING ERRCODE = 'foreign_key_violation';
    ELSE
      SELECT id INTO v_padok_id
        FROM public.padoklar
       WHERE ad = v_hedef_padok;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Hedef padok bulunamadı: %', v_hedef_padok
          USING ERRCODE = 'foreign_key_violation';
      END IF;

      v_yeni_grup := v_hayvan.grup;
      IF v_gorev.gorev_tipi = 'PADOK_DEGISIM'
         AND v_gorev.aciklama ILIKE '%Kuru döneme%' THEN
        v_yeni_grup := 'Sağmal (Kuru)';
      END IF;

      IF EXISTS (SELECT 1 FROM public.grup_padok_eslem WHERE grup = v_yeni_grup)
         AND NOT EXISTS (
           SELECT 1
             FROM public.grup_padok_eslem
            WHERE grup = v_yeni_grup
              AND padok_id = v_padok_id
         ) THEN
        RAISE EXCEPTION 'Grup % için hedef padok geçersiz: %', v_yeni_grup, v_hedef_padok
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;

  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo','gorev_log','id',p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi',v_gorev.tamamlandi,'tamamlanma_tarihi',v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi',true,'tamamlanma_tarihi',now())
  );
  UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=now() WHERE id=p_gorev_id::uuid;

  -- ASI_PLANLI muaf: planlı görevin stok düşümü yalnız asi_planli_tamamla üzerinden
  -- olur (plan rezervasyonu + gerçek uygulama); generic 'Görev' satırı çift düşüm olurdu
  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0
     AND v_gorev.gorev_tipi IS DISTINCT FROM 'ASI_PLANLI' THEN
    v_stok_dusuldu := true;
    INSERT INTO public.stok_hareket (id,stok_id,tur,miktar,notlar,iptal)
    VALUES (gen_random_uuid(),v_gorev.stok_id,'Görev',v_gorev.miktar,'GorevID:'||p_gorev_id,false);
  END IF;

  IF v_hedef_padok IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    v_padok_guncellendi := true;
    v_guncellenen := v_guncellenen || jsonb_build_object(
      'tablo','hayvanlar','id',v_gorev.hayvan_id,
      'onceki',jsonb_build_object('grup',v_hayvan.grup,'padok',v_hayvan.padok,'padok_id',v_hayvan.padok_id),
      'sonraki',jsonb_build_object('grup',v_yeni_grup,'padok',v_hedef_padok,'padok_id',v_padok_id)
    );

    UPDATE public.hayvanlar
       SET grup = v_yeni_grup,
           padok = v_hedef_padok,
           padok_id = v_padok_id
     WHERE id = v_gorev.hayvan_id;
  END IF;

  v_snapshot := jsonb_build_object('olusturulan',v_olusturulan,'guncellenen',v_guncellenen,'silinen','[]'::jsonb);
  INSERT INTO public.islem_log (tip,ana_hayvan_id,ref_id,ref_tablo,snapshot,kullanici_notu)
  VALUES ('GOREV_TAMAMLA',v_gorev.hayvan_id,p_gorev_id,'gorev_log',v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object('ok',true,'gorev_id',p_gorev_id,'stok_dusuldu',v_stok_dusuldu,'padok_guncellendi',v_padok_guncellendi);
END;
$function$;

COMMENT ON FUNCTION public.gorev_tamamla(text, text, boolean) IS
  'P3b H6: tamamlama dalinda GEBELIK_KONTROL/TAKIP_MUAYENE gorevleri MUAYENE_SONUC_GEREKLI ile reddedilir (kilitsiz guard — kilit sirasi degismedi); gorev yalniz tohumlama_bos_ve_devam muayene yoluyla kapanir. T5 iptal dali + SUTTEN_KESME/padok dallari aynen.';

-- ═══ 2) hizli_uygulama — D4 preflight + C2 imza (tekil) ══════════════════
DROP FUNCTION IF EXISTS public.hizli_uygulama(text, text, numeric, text, text, text, boolean, text, timestamp with time zone);
CREATE OR REPLACE FUNCTION public.hizli_uygulama(p_hayvan_id text, p_stok_id text, p_doz numeric, p_birim text, p_rota text, p_notlar text, p_pg_onay boolean DEFAULT false, p_pg_gerekce text DEFAULT NULL::text, p_occurred_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hayvan hayvanlar%ROWTYPE;
  v_stok   record;
  v_etken  text;
  v_id     uuid;
  v_kalan  numeric;
  -- [OVSYNC-PG S-4] bayrak tek kez okunur (fonksiyon boyunca tutarlı karar)
  v_pg_aktif boolean := public._ovsync_pg_aktif();
  v_pg_kapi  jsonb;
  -- [OVSYNC-PG R3.1 MK7] PG anı; yalnız event'in occurred_at'ını etkiler
  v_occurred_at timestamptz;
  -- [P3b D4] açık takip keşfi (kilitsiz)
  v_takip record;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  -- [OVSYNC-PG S-4] güvenlik kapısı (MK6: blok → RAISE PG_KAPI:<KOD>:<json>)
  -- [OVSYNC-PG R3.1 MK7] PG anı doğrulaması aynı kapıda: NULL → now(); gelecekte
  -- >5dk ya da geçmişte >7g → PG_ZAMAN_GECERSIZ. Bayrak kapalıyken kontrol edilmez
  -- (MK5: eski davranış, p_occurred_at yok sayılır).
  IF v_pg_aktif THEN
    IF p_occurred_at IS NULL THEN
      v_occurred_at := now();
    ELSIF p_occurred_at > now() + interval '5 minutes'
       OR p_occurred_at < now() - interval '7 days' THEN
      RAISE EXCEPTION 'PG_ZAMAN_GECERSIZ:%', jsonb_build_object(
        'p_occurred_at', p_occurred_at, 'simdi', now());
    ELSE
      v_occurred_at := p_occurred_at;
    END IF;

    v_pg_kapi := public._pg_kapi(p_hayvan_id, p_stok_id, NULL, COALESCE(p_pg_onay, false));

    -- ═══ P3b D4 TAKIP_ACIK preflight (plan.md:408) — KİLİTSİZ keşif (yalnız
    -- okur); İLK YAZMADAN (uygulama_log INSERT) ÖNCE; _pg_kapi çağrı noktasının
    -- yanında [20260923000004:134-149 sırası korunur]. Birleşik payload P2b
    -- sarmal deseniyle birebir (20260929000002:986-998). Onaylı → _takip_kapat
    -- (neden='PG') — tek satır, idempotent; hayvan kilidi YOK (H4).
    SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;

    IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      IF FOUND AND NOT COALESCE(p_takip_onay, false) THEN
        -- birleşik kapı: tek RAISE, tek onay penceresi (p_pg_onay + p_takip_onay)
        RAISE EXCEPTION 'PG_KAPI:TAKIP_ACIK:%',
          jsonb_build_object(
            'pg_kapi', public._pg_kapi_detay(v_pg_kapi, p_hayvan_id, v_hayvan.kupe_no),
            'takip_acik', jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                                             'muayene_saat', v_takip.hedef_saat)
          )::text;
      END IF;
      RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
        public._pg_kapi_detay(v_pg_kapi, p_hayvan_id, v_hayvan.kupe_no);
    END IF;

    IF FOUND THEN
      IF NOT COALESCE(p_takip_onay, false) THEN
        RAISE EXCEPTION 'TAKIP_ACIK:%',
          jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                             'muayene_saat', v_takip.hedef_saat)::text;
      END IF;
      PERFORM public._takip_kapat(v_takip.id, 'PG');
    END IF;
  END IF;

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- [OVSYNC-PG S-4] PG gerçekleşme kaydı (+ACK, +S-5 görev); PG değilse no-op
  -- [OVSYNC-PG R3.1 MK7] now() yerine doğrulanmış v_occurred_at
  IF v_pg_aktif THEN
    PERFORM public._pg_olay_isle('HIZLI_UYGULAMA', v_id::text, p_hayvan_id, p_stok_id,
      v_stok.drug_product_id, v_occurred_at, v_pg_kapi, p_pg_gerekce);
  END IF;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES (
    'HIZLI_UYGULAMA',
    p_hayvan_id,
    v_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','uygulama_log','id',v_id::text)),
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb
    ),
    format('Hızlı Uygulama — %s — %s %s %s', v_hayvan.kupe_no, v_stok.urun_adi, p_doz, p_birim)
  );

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz,
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
$function$;

-- ═══ 3) seans_tamamla — D4 preflight + C2 imza (tekil) ═══════════════════
DROP FUNCTION IF EXISTS public.seans_tamamla(uuid, boolean, text, boolean, text);
CREATE OR REPLACE FUNCTION public.seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi boolean DEFAULT false, p_not text DEFAULT NULL::text, p_pg_onay boolean DEFAULT false, p_pg_gerekce text DEFAULT NULL::text, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_seans      public.treatment_day_uygulamalar%ROWTYPE;
  v_all_done   boolean;
  v_total      int;
  v_done       int;
  v_tip        text;
  -- [OVSYNC-PG S-4]
  v_pg_aktif   boolean := public._ovsync_pg_aktif();
  v_pg_kapi    jsonb;
  v_pg_hayvan  text;
  v_pg_kupe    text;
  -- [OVSYNC-PG R3.1 MK7]
  v_occurred_at timestamptz;
  -- [P3b D4] açık takip keşfi (kilitsiz)
  v_takip      record;
  v_takip_var  boolean;   -- FOUND hemen yakalanır (ara SELECT ezmesin)
BEGIN
  -- [OVSYNC-PG R3.1 MK9] kilit sırası: hayvan → seans → görev. Bayrak açıkken
  -- seansın hayvanını kilitsiz çözüp hayvanlar satırını FOR NO KEY UPDATE ile
  -- kilitleriz; sonra (aşağıda) mevcut seans FOR UPDATE'e geçilir. p_uygulanmadi
  -- dalından bağımsız — sıra her zaman aynı olmalı (deadlock önleme).
  IF v_pg_aktif THEN
    SELECT c.animal_id INTO v_pg_hayvan
      FROM public.treatment_day_uygulamalar t
      JOIN public.cases c ON c.id = t.case_id
     WHERE t.id = p_seans_admin_id;
    IF v_pg_hayvan IS NOT NULL THEN
      PERFORM 1 FROM public.hayvanlar h WHERE h.id = v_pg_hayvan FOR NO KEY UPDATE;
    END IF;
  END IF;

  -- RACE CONDITION GUARD
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar
  WHERE id = p_seans_admin_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadi');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans zaten kapatilmis', 'race', true);
  END IF;

  IF p_uygulanmadi THEN
    -- Seans tablosunu isaretle
    UPDATE public.treatment_day_uygulamalar
    SET uygulanmadi = true, iptal_nedeni = p_not, updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;

    -- drug_admins senkron
    UPDATE public.drug_administrations
    SET uygulanmadi = true
    WHERE seans_admin_id = p_seans_admin_id
      AND uygulanmadi IS DISTINCT FROM (true);  /* statik-çözümleyici yerleşimi: DISTINCT-true yanlış-pozitifi; semantik birebir */

    -- Stok iade: stok_hareket_ref kolonu Faz 1'de yok.
    -- Bunun yerine drug_admins.notlar pattern'i ile bul:
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.seans_admin_id = p_seans_admin_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;
    v_tip := 'TEDAVI_SEANS_IPTAL';
  ELSE
    -- [OVSYNC-PG S-4] kapı yalnız uygulandı yolunda (p_uygulanmadi=false).
    -- Blok → RAISE; seans açık kalır, kullanıcı 'uygulanmadı' işaretleyebilir.
    -- [OVSYNC-PG R3.1 MK9] v_pg_hayvan yukarıda (kilit sırası bloğunda) zaten
    -- çözüldü; burada yalnız NULL koruması tekrarlanır (case_id yok/silinmiş).
    IF v_pg_aktif THEN
      IF v_pg_hayvan IS NULL THEN
        RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'SEANS_HAYVAN_YOK',
          'seans_admin_id', p_seans_admin_id, 'case_id', v_seans.case_id);
      END IF;
      v_pg_kapi := public._pg_kapi(v_pg_hayvan, v_seans.stok_id, v_seans.drug_product_id, COALESCE(p_pg_onay, false));

      -- ═══ P3b D4 TAKIP_ACIK preflight (plan.md:408) — KİLİTSİZ keşif; İLK
      -- YAZMADAN (tdu UPDATE) ÖNCE; birleşik payload P2b sarmal deseni.
      SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
        FROM public.gorev_log g
       WHERE g.hayvan_id = v_pg_hayvan
         AND g.gorev_tipi = 'TAKIP_MUAYENE'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
       ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
       LIMIT 1;
      v_takip_var := FOUND;

      IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
        SELECT h.kupe_no INTO v_pg_kupe FROM public.hayvanlar h WHERE h.id = v_pg_hayvan;
        IF v_takip_var AND NOT COALESCE(p_takip_onay, false) THEN
          RAISE EXCEPTION 'PG_KAPI:TAKIP_ACIK:%',
            jsonb_build_object(
              'pg_kapi', public._pg_kapi_detay(v_pg_kapi, v_pg_hayvan, v_pg_kupe)
                         || jsonb_build_object('seans_admin_id', p_seans_admin_id,
                                               'case_id', v_seans.case_id),
              'takip_acik', jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                                               'muayene_saat', v_takip.hedef_saat)
            )::text;
        END IF;
        RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
          public._pg_kapi_detay(v_pg_kapi, v_pg_hayvan, v_pg_kupe)
            || jsonb_build_object('seans_admin_id', p_seans_admin_id, 'case_id', v_seans.case_id);
      END IF;

      IF v_takip_var THEN
        IF NOT COALESCE(p_takip_onay, false) THEN
          RAISE EXCEPTION 'TAKIP_ACIK:%',
            jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                               'muayene_saat', v_takip.hedef_saat)::text;
        END IF;
        PERFORM public._takip_kapat(v_takip.id, 'PG');
      END IF;
    END IF;
    -- Seans tamamlandi
    UPDATE public.treatment_day_uygulamalar
    SET uygulama_tamamlandi_at = now(),
        uygulama_notu = p_not,
        gerceklesme_saati = NOW()::time,
        updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans baska biri tarafindan kapatilmis', 'race', true);
    END IF;
    -- [OVSYNC-PG S-4] PG gerçekleşme kaydı; source_id = seans id
    -- [OVSYNC-PG R3.1 MK7] occurred_at = LEAST(now(), planlanan an) — kaydın geç
    -- girilmesi TAI'yi ileri kaydırmasın.
    IF v_pg_aktif THEN
      v_occurred_at := LEAST(now(), (v_seans.planned_date + v_seans.planned_time) AT TIME ZONE 'Europe/Istanbul');
      PERFORM public._pg_olay_isle('TEDAVI_SEANS', p_seans_admin_id::text, v_pg_hayvan,
        v_seans.stok_id, v_seans.drug_product_id, v_occurred_at, v_pg_kapi, p_pg_gerekce);
    END IF;
    v_tip := 'TEDAVI_SEANS_TAMAM';
  END IF;

  -- Gorev log kapat
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE seans_admin_id = p_seans_admin_id AND tamamlandi = false;

  -- Tum seanslar done mi?
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
  INTO v_total, v_done
  FROM public.treatment_day_uygulamalar
  WHERE treatment_day_id = v_seans.treatment_day_id;

  v_all_done := (v_total = v_done);

  IF v_all_done THEN
    -- Gun seviyesi tamamlandi
    UPDATE public.treatment_days
    SET tamamlandi = true,
        tamamlanma_tarihi = now()
    WHERE id = v_seans.treatment_day_id AND tamamlandi = false;

    UPDATE public.gorev_log
    SET tamamlandi = true, tamamlanma_tarihi = now()
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND tamamlandi = false
      AND (aciklama::jsonb->>'day_id')::uuid = v_seans.treatment_day_id;
  END IF;

  -- Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, v_tip,
    (SELECT animal_id FROM public.cases WHERE id = v_seans.case_id),
    p_seans_admin_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', p_seans_admin_id::text)
      ),
      'gun_tamam', v_all_done
    )
  );

  RETURN jsonb_build_object('ok', true, 'seans_done', true, 'gun_tamam', v_all_done);
END;
$function$;

-- ═══ 4) bulk_ilac — D4 satır-sonucu + C2 imza (dizi) ═════════════════════
DROP FUNCTION IF EXISTS public.bulk_ilac(text[], text, numeric, text, text[], text);
CREATE OR REPLACE FUNCTION public.bulk_ilac(p_animal_ids text[], p_ilac_stok_id text, p_miktar numeric, p_notlar text DEFAULT NULL::text, p_pg_onaylar text[] DEFAULT '{}'::text[], p_pg_gerekce text DEFAULT NULL::text, p_takip_onaylar text[] DEFAULT '{}'::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_animal_id       text;
  v_stok            record;
  v_success         int := 0;
  v_errors          jsonb := '[]'::jsonb;
  v_total_miktar    numeric;
  v_stok_urun_adi   text;
  v_log_id          text;
  v_stok_hareket_id uuid;
  -- [OVSYNC-PG S-4]
  v_pg_aktif        boolean := public._ovsync_pg_aktif();
  v_pg_kapi         jsonb;
  v_pg_kapilar      jsonb := '{}'::jsonb;   -- hayvan_id → kapı (yalnız uygulanacaklar)
  v_pg_uygula_adet  int := 0;
  v_pg_urun         uuid;
  v_pg_kupe         text;
  v_pg_event        uuid;
  v_pg_applied      jsonb := '[]'::jsonb;
  v_pg_blocked      jsonb := '[]'::jsonb;
  v_pg_requires_ack jsonb := '[]'::jsonb;
  -- [OVSYNC-PG R3.1 MK9] deterministik kilit sırası için sıralanmış çalışma
  -- kopyası; bayrak kapalıyken p_animal_ids ile bit-bit aynı (MK5).
  v_animal_ids_calisma text[] := p_animal_ids;
  -- [P3b D4] takip satır-sonucu desen (bulk_ilac ≡ vaka_toplu_ac; §10h H5)
  v_takip           record;
  v_takip_var       boolean;                -- FOUND hemen yakalanır (ara SELECT ezmesin)
  v_takip_map       jsonb := '{}'::jsonb;   -- onaylı açık-takipliler: hayvan_id → gorev_id
  v_takip_islenenmez text[] := '{}'::text[];-- İŞLENMEYECEK hayvan id'leri (onaysız açık-takipli)
  v_takip_acik_list jsonb := '[]'::jsonb;   -- İŞLENMEYEN satırlar (satır sonucu TAKIP_ACIK)
  v_takip_liste     jsonb := '[]'::jsonb;   -- hayvan-bazlı birleşik onay listesi
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

  -- [P3b C2] p_takip_onaylar ⊆ p_animal_ids — liste-dışı id sessiz YOK sayılmaz
  FOREACH v_animal_id IN ARRAY COALESCE(p_takip_onaylar, '{}'::text[]) LOOP
    IF v_animal_id IS NOT NULL
       AND NOT (v_animal_id = ANY(COALESCE(p_animal_ids, '{}'::text[]))) THEN
      RAISE EXCEPTION 'TAKIP_ONAY_KUME_UYUMSUZ:%',
        jsonb_build_object('liste_disi_id', v_animal_id)::text;
    END IF;
  END LOOP;

  -- [OVSYNC-PG S-4] ön geçiş: hayvan başına kapı. Blok/onaysız hayvan atlanır
  -- (yazma yok); stok gereksinimi yalnız uygulanacak hayvan sayısıyla hesaplanır.
  IF v_pg_aktif THEN
    SELECT s.drug_product_id INTO v_pg_urun FROM public.stok s WHERE s.id = p_ilac_stok_id;
    -- [OVSYNC-PG R3.1 MK9] hayvan id'lerini işlemeden önce sırala (deterministik
    -- kilit sırası; _pg_kapi her hayvan için hayvanlar satırını kilitler).
    SELECT COALESCE(array_agg(x ORDER BY x NULLS LAST), '{}'::text[])
      INTO v_animal_ids_calisma
      FROM pg_catalog.unnest(p_animal_ids) AS x;
    FOREACH v_animal_id IN ARRAY v_animal_ids_calisma LOOP
      IF v_animal_id IS NULL THEN
        v_pg_kapi := jsonb_build_object('karar', 'PG_KAPI_IC_HATA', 'hata', 'HAYVAN_ID_BOS');
      ELSE
        BEGIN
          v_pg_kapi := public._pg_kapi(v_animal_id, p_ilac_stok_id, NULL,
                         v_animal_id = ANY(COALESCE(p_pg_onaylar, '{}'::text[])));
        EXCEPTION WHEN OTHERS THEN
          v_pg_kapi := jsonb_build_object('karar', 'PG_KAPI_IC_HATA', 'hata', SQLERRM);
        END;
      END IF;

      -- ═══ [P3b D4] takip keşfi (KİLİTSİZ — mevcut döngü/kilit DEĞİŞMEZ; kapı
      -- yalnız EK adımdır): onaysız açık-takipli satır İŞLENMEZ + satır sonucu
      -- TAKIP_ACIK; onaylı → v_takip_map (uygulama döngüsünde satır öncesi kapanış).
      SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
        FROM public.gorev_log g
       WHERE g.hayvan_id = v_animal_id
         AND g.gorev_tipi = 'TAKIP_MUAYENE'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
       ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
       LIMIT 1;
      v_takip_var := FOUND;

      IF v_takip_var AND NOT (v_animal_id = ANY(COALESCE(p_takip_onaylar, '{}'::text[]))) THEN
        v_takip_islenenmez := v_takip_islenenmez || v_animal_id;
        v_pg_kupe := NULL;
        SELECT h.kupe_no INTO v_pg_kupe FROM public.hayvanlar h WHERE h.id = v_animal_id;
        v_takip_acik_list := v_takip_acik_list || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_animal_id, 'kupe_no', v_pg_kupe, 'kod', 'TAKIP_ACIK',
          'muayene_tarihi', v_takip.hedef_tarih, 'muayene_saat', v_takip.hedef_saat));
      ELSIF v_takip_var THEN
        v_takip_map := v_takip_map || jsonb_build_object(v_animal_id, v_takip.id);
      END IF;

      v_takip_liste := v_takip_liste || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_animal_id,
        'pg_kapi_karar', v_pg_kapi->>'karar',
        'takip_acik', v_takip_var,
        'takip_bilgi', CASE WHEN v_takip_var THEN
          jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                             'muayene_saat', v_takip.hedef_saat)
        ELSE NULL END));

      IF v_pg_kapi->>'karar' IN ('ALLOW', 'ACK_PENDING') THEN
        -- [P3b D4] onaysız açık-takipli satır İŞLENMEZ (satır sonucu yukarıda
        -- takip_acik[]'a yazıldı; v_pg_kapilar'a GİRMEZ — uygulanmaz, stok
        -- hesabına girmez); onaylılar ve takipsizler uygulanır.
        IF v_animal_id = ANY(v_takip_islenenmez) THEN
          NULL;
        ELSE
          v_pg_kapilar := v_pg_kapilar || jsonb_build_object(v_animal_id, v_pg_kapi);
          v_pg_uygula_adet := v_pg_uygula_adet + 1;
        END IF;
      ELSE
        v_pg_kupe := NULL;
        SELECT h.kupe_no INTO v_pg_kupe FROM public.hayvanlar h WHERE h.id = v_animal_id;
        IF v_pg_kapi->>'karar' = 'REQUIRE_ACK_PENDING' THEN
          v_pg_requires_ack := v_pg_requires_ack || jsonb_build_array(
            public._pg_kapi_detay(v_pg_kapi, v_animal_id, v_pg_kupe)
              || jsonb_build_object('kod', v_pg_kapi->>'karar'));
        ELSE
          v_pg_blocked := v_pg_blocked || jsonb_build_array(
            public._pg_kapi_detay(v_pg_kapi, v_animal_id, v_pg_kupe)
              || jsonb_build_object('kod', COALESCE(v_pg_kapi->>'karar', 'PG_KAPI_IC_HATA'),
                                    'hata', v_pg_kapi->>'hata'));
        END IF;
      END IF;
    END LOOP;
    v_total_miktar := p_miktar * v_pg_uygula_adet;
  END IF;

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
  -- [OVSYNC-PG R3.1 MK9] bayrak kapalıyken v_animal_ids_calisma = p_animal_ids
  -- (aynı sıra, MK5); bayrak açıkken sıralanmış kopya (yukarıda).
  FOREACH v_animal_id IN ARRAY v_animal_ids_calisma LOOP
    -- [OVSYNC-PG S-4] kapıdan geçmeyen hayvan atlanır (satır bazında rapor)
    IF v_pg_aktif AND (v_pg_kapilar ? v_animal_id) IS NOT TRUE THEN
      CONTINUE;
    END IF;
    BEGIN
      -- [P3b D4] onaylı açık-takipli satır: kapanış satır işlenmeden HEMEN ÖNCE
      -- (satır alt-transaction'ının ilk deyimi — satır hatasında kapanış da
      -- geri alınır; neden='PG').
      IF v_takip_map ? v_animal_id THEN
        PERFORM public._takip_kapat((v_takip_map ->> v_animal_id)::uuid, 'PG');
      END IF;
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
        v_log_id,
        'islem_log'
      );
      -- [OVSYNC-PG S-4] event source_id = bu hayvan için yazılan islem_log id'si.
      -- Hata → alt-transaction geri alınır (islem_log dahil), errors[]'a düşer.
      IF v_pg_aktif THEN
        v_pg_event := public._pg_olay_isle('TOPLU_ILAC', v_log_id, v_animal_id, p_ilac_stok_id,
          v_pg_urun, now(), v_pg_kapilar -> v_animal_id, p_pg_gerekce);
        v_pg_applied := v_pg_applied || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_animal_id, 'islem_log_id', v_log_id,
          'karar', v_pg_kapilar -> v_animal_id ->> 'karar', 'pg_event_id', v_pg_event));
      END IF;
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

  -- [OVSYNC-PG S-4] mevcut anahtarlar korunur; ek applied[]/blocked[]/requires_ack[]
  -- [P3b D4] ek takip_acik[] (satır sonucu) + takip_onay_listesi[] (birleşik liste)
  IF v_pg_aktif THEN
    RETURN jsonb_build_object(
      'ok', true,
      'total', array_length(p_animal_ids, 1),
      'success', v_success,
      'errors', v_errors,
      'applied', v_pg_applied,
      'blocked', v_pg_blocked,
      'requires_ack', v_pg_requires_ack,
      'takip_acik', v_takip_acik_list,
      'takip_onay_listesi', v_takip_liste
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$function$;

-- ═══ 5) start_first_service_protocol — MK9 düzeltmesi + takip kapısı + C2 ══
DROP FUNCTION IF EXISTS public.start_first_service_protocol(uuid);
CREATE OR REPLACE FUNCTION public.start_first_service_protocol(p_gorev_id uuid, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g           record;
  v_g2          record;
  v_h           record;
  v_takip       record;
  v_olay        date;
  v_neden       text;
  v_son_sonuc   text;
  v_bugun       date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_s           date;
  v_sablon_id   uuid;
  v_disease_id  uuid;
  v_n           integer;
  v_res         jsonb;
  v_sab         jsonb;
  v_top         jsonb;
  v_case_id     uuid;
  v_tai_id      uuid;
  v_d58         uuid[];
  v_pg_gorev_iptal uuid[];
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RAISE EXCEPTION 'OZELLIK_KAPALI:%', jsonb_build_object(
      'bayrak', 'ovsync_pg_kurallari_aktif', 'gorev_id', p_gorev_id);
  END IF;

  -- ═══ P3b MK9 düzeltmesi (plan.md:424-428; §10f C3): görev KİLİTSİZ okunur;
  -- hızlı retler kilitsiz veriyle aynı sırada. Eski gövde görevi ÖNCE FOR
  -- UPDATE (:44/:53) alıp hayvanı SONRA FOR UPDATE (:62/:82) kilitliyordu —
  -- bilinen tek kurucu MK9 ihlali (sarmal: hayvan→görev; start: görev→hayvan).
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_BULUNAMADI:%', jsonb_build_object('gorev_id', p_gorev_id);
  END IF;
  IF v_g.gorev_tipi IS DISTINCT FROM 'OVSYNC_BASLAT' THEN
    RAISE EXCEPTION 'GOREV_TIPI_UYUMSUZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RETURN jsonb_build_object('ok', true, 'zaten', true, 'gorev_id', p_gorev_id,
      'iptal', COALESCE(v_g.iptal, false), 'kapatan_ref', v_g.kapatan_ref);
  END IF;

  -- K4 (2026-09-26): erken-çağrı kapısı — hedefe 2 günden çok varsa RET.
  -- Pencere hedef−2 gün AÇIK (dahil): v_bugun < hedef-2 → red. T13: gelecek-
  -- hedefli görev sessizce zincir açıyordu (v_s := GREATEST geleceği kabulleniyor).
  IF v_bugun < v_g.hedef_tarih - 2 THEN
    RAISE EXCEPTION 'OVSYNC_ERKEN:%', jsonb_build_object(
      'gorev_id', p_gorev_id,
      'hedef_tarih', v_g.hedef_tarih,
      'kalan_gun', (v_g.hedef_tarih - v_bugun),
      'acilisa_kalan_gun', (v_g.hedef_tarih - v_bugun - 2));
  END IF;

  -- ═══ Hayvan İLK kilit (MK9-N muteks — hayvan satırında ASLA FOR UPDATE:
  -- FK KEY SHARE'i bloklar; eski :62'nin yukarı alınmış + NKU'ye dönüşmüş hali).
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_g.hayvan_id FOR NO KEY UPDATE;

  -- protokol_instance okuması hayvan kilidinden SONRA (vaka/seans katmanı
  -- okuması — kilit değil, alt sıra serbest).
  SELECT baslangic INTO v_olay FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  v_olay := COALESCE(v_olay, v_g.hedef_tarih - 51);

  -- ═══ Görev yeniden kilit + yeniden doğrulama: kilitsiz okuma ile arada
  -- kapanmışsa zaten-kapalı dönüşü; açık kalmışsa v_g2 üzerinden devam.
  SELECT * INTO v_g2 FROM public.gorev_log WHERE id = p_gorev_id FOR NO KEY UPDATE;
  IF v_g2.gorev_tipi IS DISTINCT FROM 'OVSYNC_BASLAT' THEN
    RAISE EXCEPTION 'GOREV_TIPI_UYUMSUZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g2.gorev_tipi);
  END IF;
  IF COALESCE(v_g2.tamamlandi, false) OR COALESCE(v_g2.iptal, false) THEN
    RETURN jsonb_build_object('ok', true, 'zaten', true, 'gorev_id', p_gorev_id,
      'iptal', COALESCE(v_g2.iptal, false), 'kapatan_ref', v_g2.kapatan_ref);
  END IF;

  -- ── Otomatik muafiyetler (SK7 final seti — v_h üzerinden; IF zinciri birebir)
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSIF COALESCE(v_h.kisir, false) THEN
    v_neden := 'KISIR';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu
    SELECT t.sonuc INTO v_son_sonuc FROM public.tohumlama t
     WHERE t.hayvan_id = v_g2.hayvan_id
       ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
       LIMIT 1;
    IF v_son_sonuc = 'Gebe' THEN
      v_neden := 'GEBE';
    ELSIF v_son_sonuc = 'Bekliyor' THEN
      v_neden := 'BEKLIYOR';
    ELSIF EXISTS (SELECT 1 FROM public.cases c
                   WHERE c.animal_id = v_g2.hayvan_id
                     AND c.status = 'active'
                     AND c.protocol_family IS NOT NULL) THEN
      v_neden := 'AKTIF_SENKRONIZASYON';
    END IF;
  END IF;

  IF v_neden IS NOT NULL THEN
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = p_gorev_id;
    UPDATE public.protokol_instance
       SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = v_g2.protokol_instance_id AND durum = 'aktif';
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_SKIPPED', v_g2.hayvan_id, p_gorev_id::text, 'gorev_log',
            jsonb_build_object('gorev_id', p_gorev_id, 'neden', v_neden,
              'kaynak', v_g2.kaynak, 'olay_tarihi', v_olay, 'hedef_tarih', v_g2.hedef_tarih),
            '{}'::jsonb);
    RETURN jsonb_build_object('ok', true, 'atlandi', v_neden, 'gorev_id', p_gorev_id);
  END IF;

  -- ═══ P3b takip kapısı (C2 tekil desen; ilk yazmadan ÖNCE — _vaka_ac_tek'in
  -- cases INSERT'i P3a Ovsync tetikleyicisini ateşlemeden kapı burada çalışır;
  -- onaylı → _takip_kapat(neden='OVSYNC') vaka-yolu kapanış sınıfı).
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = v_g2.hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND THEN
    IF NOT COALESCE(p_takip_onay, false) THEN
      RAISE EXCEPTION 'TAKIP_ACIK:%',
        jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                           'muayene_saat', v_takip.hedef_saat)::text;
    END IF;
    PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
  END IF;

  -- ── Başlangıç, şablon, hastalık (birebir) ─────────────────────────────
  v_s := GREATEST(v_g2.hedef_tarih, v_bugun);

  SELECT count(*), (array_agg(id))[1] INTO v_n, v_sablon_id
    FROM public.tedavi_sablonu
   WHERE protokol_ailesi = 'OVSYNC' AND aktif IS TRUE;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'aktif_ovsync_sablon_sayisi', v_n);
  END IF;

  SELECT count(DISTINCT disease_id), (array_agg(DISTINCT disease_id))[1] INTO v_n, v_disease_id
   FROM public.sablon_hastalik_eslem
   WHERE sablon_id = v_sablon_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_HASTALIK_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sablon_id', v_sablon_id, 'hastalik_sayisi', v_n);
  END IF;

  -- ── Atomik zincir (birebir) ────────────────────────────────────────────
  v_res := public._vaka_ac_tek(v_g2.hayvan_id, v_disease_id, 'İlk tohumlama zinciri', v_s);
  IF (v_res->>'ok') IS DISTINCT FROM 'true' OR (v_res->>'case_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_ACILAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'hayvan_id', v_g2.hayvan_id, 'sonuc', v_res);
  END IF;
  v_case_id := (v_res->>'case_id')::uuid;

  UPDATE public.cases
     SET protocol_family = 'OVSYNC'
   WHERE id = v_case_id
     AND protocol_family IS NULL;

  v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                       p_baslangic_tarihi := v_s);
  IF (v_sab->>'ok') IS DISTINCT FROM 'true'
     OR COALESCE((v_sab->>'seans_sayisi')::int, 0) = 0
     OR COALESCE(jsonb_array_length(v_sab->'atlanan'), 0) > 0 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_UYGULANAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_sab);
  END IF;

  v_top := public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                                     p_baslangic_tarihi := v_s);
  IF (v_top->>'ok') IS DISTINCT FROM 'true'
     OR (v_top->>'olustu') IS DISTINCT FROM 'true'
     OR (v_top->>'gorev_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_TAI_OLUSMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_top);
  END IF;
  v_tai_id := (v_top->>'gorev_id')::uuid;

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_D58_IPTAL'
     WHERE hayvan_id = v_g2.hayvan_id
       AND kaynak = 'DOGUM-' || v_g2.hayvan_id
       AND gorev_tipi = 'DIGER'
       AND aciklama ILIKE '%kızgınlık takibi%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
       AND hedef_tarih BETWEEN v_olay + 50 AND v_olay + 70
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_d58 FROM u;

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true,
           kapatan_ref = 'ILK_TOH_PROTOKOL_YERINE:' || v_case_id::text
     WHERE hayvan_id = v_g2.hayvan_id
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND kaynak LIKE 'PG_TOHUMLAMA:%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_gorev_iptal FROM u;

  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = 'case:' || v_case_id::text
   WHERE id = p_gorev_id;
  UPDATE public.protokol_instance
     SET durum = 'tamamlandi', kapandi_at = now(), kapandi_sebep = 'case:' || v_case_id::text
   WHERE id = v_g2.protokol_instance_id AND durum = 'aktif';

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_PROTOCOL_STARTED', v_g2.hayvan_id, v_case_id::text, 'cases',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'case_id', v_case_id,
            'sablon_id', v_sablon_id, 'disease_id', v_disease_id,
            'baslangic', v_s, 'olay_tarihi', v_olay, 'kaynak', v_g2.kaynak,
            'tohumlama_gorev_id', v_tai_id,
            'seans_sayisi', (v_sab->>'seans_sayisi')::int,
            'd58_iptal', to_jsonb(v_d58),
            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal)),
          '{}'::jsonb);

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id, 'tohumlama_gorev_id', v_tai_id,
                            'baslangic', v_s, 'd58_iptal', to_jsonb(v_d58),
                            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal));
END;
$function$;

-- ═══ 6) create_case — takip kapısı (kilitsiz keşif; gövde kilit düzeni
--     DEĞİŞMEZ — H1 geri alımı: _vaka_ac_tek DOKUNULMAZ) + C2 imza ═════════
DROP FUNCTION IF EXISTS public.create_case(text, uuid, text);
CREATE OR REPLACE FUNCTION public.create_case(p_animal_id text, p_disease_id uuid, p_notes text DEFAULT NULL::text, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_takip record;
BEGIN
  -- ═══ P3b takip kapısı (plan.md:421a/451 — elle vaka yolları aynı kapı):
  -- KİLİTSİZ keşif (yalnız okur; eski yol — kilit düzeni değişmez) → onaysız
  -- RAISE TAKIP_ACIK; onaylı → _takip_kapat(neden='OVSYNC') tek satır
  -- (idempotent) → tetikleyici açık takip görmez. İlk yazmadan önce.
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = p_animal_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND AND NOT COALESCE(p_takip_onay, false) THEN
    RAISE EXCEPTION 'TAKIP_ACIK:%',
      jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                         'muayene_saat', v_takip.hedef_saat)::text;
  END IF;
  IF FOUND THEN
    PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
  END IF;

  RETURN public._vaka_ac_tek(p_animal_id, p_disease_id, p_notes, NULL);
END;
$function$;

-- ═══ 7) vaka_toplu_ac — D4 satır-sonucu + C2 imza (dizi; döngü/kilit
--     DEĞİŞMEZ — H5 geri alımı: ORDER BY-id retry yok) ════════════════════
DROP FUNCTION IF EXISTS public.vaka_toplu_ac(text[], uuid, jsonb, uuid, text, date, boolean, integer, text, text);
CREATE OR REPLACE FUNCTION public.vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_items jsonb DEFAULT NULL::jsonb, p_sablon_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text, p_tarih date DEFAULT NULL::date, p_tohumlama boolean DEFAULT false, p_tohumlama_gun_offset integer DEFAULT 0, p_tohumlama_saat text DEFAULT NULL::text, p_tohumlama_cakisma text DEFAULT 'ekle'::text, p_takip_onaylar text[] DEFAULT '{}'::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_list          text[] := ARRAY[]::text[];
  v_seen          text[] := ARRAY[]::text[];
  v_id            text;
  v_toplam        int;
  v_basari        int := 0;
  v_acilan        jsonb := '[]'::jsonb;
  v_atlanan       jsonb := '[]'::jsonb;
  v_hatalar       jsonb := '[]'::jsonb;
  v_kupe          text;
  v_res           jsonb;
  v_r             jsonb;
  v_case_id       uuid;
  v_sab           jsonb;
  v_sab_obj       jsonb;
  v_manuel_obj    jsonb;
  v_top           jsonb;
  v_ok            boolean;
  v_tohumlama_var boolean;
  v_tohu_ekle_var boolean;
  v_start_date    date;
  v_tohu_tarih    date;
  v_tohu_res      jsonb;
  v_tohu_obj      jsonb;
  v_sess          jsonb;
  v_item          jsonb;
  v_idx           int;
  v_day           jsonb;
  v_days_sorted   jsonb;
  v_dup_gun       int;
  v_gun_sayisi    int;
  v_seans_toplam  int;
  v_err_gun       int;
  v_cakisma       jsonb;
  v_uzerine       jsonb;
  v_c             record;
  -- [P3b D4] takip satır-sonucu desen (bulk_ilac ile aynı; §10h H5)
  v_takip            record;
  v_takip_map        jsonb := '{}'::jsonb;  -- onaylı açık-takipliler: hayvan_id → gorev_id
  v_takip_islenenmez text[] := '{}'::text[];-- İŞLENMEYECEK hayvan id'leri
  v_takip_acik_list  jsonb := '[]'::jsonb;  -- satır sonucu TAKIP_ACIK satırları
BEGIN
  IF p_animal_ids IS NULL OR array_length(p_animal_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan listesi boş');
  END IF;
  IF array_length(p_animal_ids, 1) > 200 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'En fazla 200 hayvan');
  END IF;

  -- V1.1: şablon ile manuel ilaç listesi karşılıklı dışlanır
  IF p_items IS NOT NULL AND p_sablon_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Şablon ve manuel ilaç listesi aynı anda verilemez');
  END IF;

  -- V1.2: p_tarih = planlanan başlangıç. NULL → bugün; geçmiş reddedilir
  -- (fail-fast — hiç vaka açılmadan).
  IF p_tarih IS NOT NULL AND p_tarih < CURRENT_DATE THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçmiş tarih planlanamaz');
  END IF;

  -- V1.2: tohumlama parametreleri (fail-fast)
  IF p_tohumlama_gun_offset IS NULL
     OR p_tohumlama_gun_offset < 0 OR p_tohumlama_gun_offset > 365 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Tohumlama gün ofseti 0-365 aralığında olmalı');
  END IF;
  IF p_tohumlama_saat IS NOT NULL
     AND p_tohumlama_saat !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz saat');
  END IF;

  -- V2.2: çakışma modu (fail-fast — hiç vaka açılmadan). DEFAULT 'ekle'
  -- mevcut davranışı korur; mod p_tohumlama=false iken etki etmez.
  IF p_tohumlama_cakisma IS NULL OR
     p_tohumlama_cakisma NOT IN ('ekle', 'uzerine_yaz', 'atla') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz çakışma modu');
  END IF;

  -- V2: p_items doğrulama + motor biçimine normalize (fail-fast — henüz
  -- hiç vaka açılmadan döner). p_items artık GÜN objeleri dizisidir:
  -- [{gun, saat?, kalemler:[...]}]. Her kalem V1.1 kalem kontrollerinden
  -- geçer (mesajlar aynen, index '<gün>.<kalem>'); kalem saati motor için
  -- zorunlu planned_time'a COALESCE(kalem.saat, gün.saat, '09:00') ile
  -- çevrilir (treatment_day_uygulamalar.planned_time NOT NULL,
  -- 20260611000001). DÜZ (V1.1) dizi şekli kabul edilmez: gun anahtarı
  -- olmayan ilk eleman 'Geçersiz plan: gün 1..31' ile düşer.
  IF p_items IS NOT NULL THEN
    IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj',
        'Geçersiz plan: boş olmayan bir jsonb dizisi bekleniyor');
    END IF;
    FOR v_day, v_idx IN
      SELECT value, ord - 1
      FROM pg_catalog.jsonb_array_elements(p_items) WITH ORDINALITY AS t(value, ord)
    LOOP
      IF jsonb_typeof(v_day) IS DISTINCT FROM 'object' THEN
        RETURN jsonb_build_object('ok', false, 'mesaj',
          'Geçersiz plan: ' || v_idx || ': gün elemanı obje olmalı');
      END IF;
      -- gun: JSON sayısı ve tam sayı yazımı, 1..31 (düz V1.1 kalemleri burada
      -- düşer — gun anahtarı yok)
      IF COALESCE(jsonb_typeof(v_day->'gun'), '') <> 'number'
         OR (v_day->>'gun') !~ '^[0-9]+$'
         OR (v_day->>'gun')::numeric < 1
         OR (v_day->>'gun')::numeric > 31 THEN
        RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz plan: gün 1..31');
      END IF;
      IF v_day->>'saat' IS NOT NULL
         AND (v_day->>'saat') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
        RETURN jsonb_build_object('ok', false, 'mesaj',
          'Geçersiz plan: gün ' || (v_day->>'gun') || ': saat');
      END IF;
      IF COALESCE(jsonb_typeof(v_day->'kalemler'), '') <> 'array'
         OR jsonb_array_length(v_day->'kalemler') < 1 THEN
        RETURN jsonb_build_object('ok', false, 'mesaj',
          'Geçersiz plan: Gün ' || (v_day->>'gun') || ' kalemleri boş');
      END IF;
      -- V1.1 kalem kontrolleri — mesajlar aynen, index '<gün>.<kalem>'
      -- (kalem 1 tabanlı); kalem saati V2 üslubuyla denetlenir
      FOR v_item, v_idx IN
        SELECT value, ord
        FROM pg_catalog.jsonb_array_elements(v_day->'kalemler') WITH ORDINALITY AS t(value, ord)
      LOOP
        IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': dizi elemanı obje olmalı');
        END IF;
        IF COALESCE(v_item->>'drug_product_id', '') = '' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': drug_product_id zorunlu (uuid)');
        END IF;
        IF (v_item->>'drug_product_id') !~*
            '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': drug_product_id geçerli bir uuid değil');
        END IF;
        IF COALESCE(v_item->>'stok_id', '') = '' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': stok_id zorunlu');
        END IF;
        IF v_item->>'dose' IS NULL
           OR (v_item->>'dose') !~ '^[0-9]+([.][0-9]+)?$'
           OR (v_item->>'dose')::numeric <= 0 THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': dose pozitif sayısal olmalı (dose > 0)');
        END IF;
        IF COALESCE(v_item->>'unit', '') = '' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': unit zorunlu');
        END IF;
        IF v_item->>'saat' IS NOT NULL
           AND (v_item->>'saat') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz plan: gün ' || (v_day->>'gun') || ' kalem ' || v_idx || ': saat');
        END IF;
      END LOOP;
    END LOOP;
    -- Günler dizide tekil olmalı (buraya gelindiğinde tüm gun değerleri
    -- 1..31 aralığında geçerli tam sayılar)
    SELECT min(g)
      INTO v_dup_gun
      FROM (
        SELECT (d->>'gun')::int AS g
        FROM pg_catalog.jsonb_array_elements(p_items) d
        GROUP BY 1
        HAVING count(*) > 1
      ) t;
    IF v_dup_gun IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'mesaj',
        'Geçersiz plan: gün ' || v_dup_gun || ' tekrar ediyor');
    END IF;
    -- Yürütme planı (bir kez, döngü dışında): günler gun ASC sıralanır,
    -- her günün seans dizisi kurulur — kalem başına planned_time :=
    -- COALESCE(kalem.saat, gün.saat, '09:00'). Motor kalemleri birebir aynı
    -- anahtarlarla okur (20260611000002_bug059_rpcs.sql).
    v_days_sorted := '[]'::jsonb;
    FOR v_day IN
      SELECT value
      FROM pg_catalog.jsonb_array_elements(p_items)
      ORDER BY (value->>'gun')::int
    LOOP
      v_sess := '[]'::jsonb;
      FOR v_item IN SELECT * FROM pg_catalog.jsonb_array_elements(v_day->'kalemler')
      LOOP
        v_sess := v_sess || jsonb_build_array(jsonb_build_object(
          'drug_product_id', v_item->>'drug_product_id',
          'stok_id',         v_item->>'stok_id',
          'dose',            v_item->>'dose',
          'unit',            v_item->>'unit',
          'route',           NULLIF(v_item->>'route', ''),
          'planned_time',    COALESCE(NULLIF(v_item->>'saat', ''),
                                    NULLIF(v_day->>'saat', ''), '09:00')));
      END LOOP;
      v_days_sorted := v_days_sorted || jsonb_build_array(jsonb_build_object(
        'gun',  (v_day->>'gun')::int,
        'sess', v_sess));
    END LOOP;
  END IF;

  -- Dedupe: girdi sırası korunur
  FOREACH v_id IN ARRAY p_animal_ids LOOP
    IF v_id IS NOT NULL AND NOT (v_id = ANY (v_seen)) THEN
      v_seen := v_seen || v_id;
      v_list := v_list || v_id;
    END IF;
  END LOOP;
  v_toplam := array_length(v_list, 1);
  IF v_toplam IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan listesi boş');
  END IF;

  -- ═══ [P3b C2] p_takip_onaylar ⊆ p_animal_ids — liste-dışı id sessiz YOK
  -- sayılmaz (tüm mevcut fail-fast'lerden SONRA: mevcut hata sözleşmelerinin
  -- önceliği korunur).
  FOREACH v_id IN ARRAY COALESCE(p_takip_onaylar, '{}'::text[]) LOOP
    IF v_id IS NOT NULL AND NOT (v_id = ANY(p_animal_ids)) THEN
      RAISE EXCEPTION 'TAKIP_ONAY_KUME_UYUMSUZ:%',
        jsonb_build_object('liste_disi_id', v_id)::text;
    END IF;
  END LOOP;

  -- ═══ [P3b D4 satır-sonucu deseni — bulk_ilac ile birebir; H5 geri alımı:
  -- mevcut döngü/kilit DEĞİŞMEZ] fonksiyon başında açık-takipliler KİLİTSİZ
  -- okunur; p_takip_onaylar DIŞINDAKİ açık-takipli satır İŞLENMEZ + satır
  -- sonucu 'takip_acik[]'; onaylılar v_takip_map'e (döngüde satır öncesi
  -- kapanış). retry = onaylı alt kümeyle yeni çağrı.
  FOREACH v_id IN ARRAY v_list LOOP
    SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = v_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;
    IF FOUND THEN
      IF v_id = ANY(COALESCE(p_takip_onaylar, '{}'::text[])) THEN
        v_takip_map := v_takip_map || jsonb_build_object(v_id, v_takip.id);
      ELSE
        v_takip_islenenmez := v_takip_islenenmez || v_id;
        v_kupe := NULL;
        SELECT kupe_no INTO v_kupe FROM public.hayvanlar WHERE id = v_id;
        v_takip_acik_list := v_takip_acik_list || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_id, 'kupe', v_kupe, 'kod', 'TAKIP_ACIK',
          'muayene_tarihi', v_takip.hedef_tarih, 'muayene_saat', v_takip.hedef_saat));
      END IF;
    END IF;
  END LOOP;

  -- GT'de olmayan opsiyonel helper'lar canlıdaysa uygula (pg_proc guard — bir
  -- kez, döngü dışında; helper yoksa ilgili yol güvenli düşer)
  SELECT EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc
    WHERE proname = 'tedavi_sablon_tohumlama_gorev_ekle'
      AND pronamespace = 'public'::regnamespace
  ) INTO v_tohumlama_var;
  SELECT EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc
    WHERE proname = 'vaka_tohumlama_ekle'
      AND pronamespace = 'public'::regnamespace
  ) INTO v_tohu_ekle_var;

  FOREACH v_id IN ARRAY v_list LOOP
    -- ═══ [P3b D4] onaysız açık-takipli satır İŞLENMEZ (satır sonucu yukarıda
    -- takip_acik[]'a yazıldı).
    IF v_id = ANY(v_takip_islenenmez) THEN
      CONTINUE;
    END IF;
    SELECT kupe_no INTO v_kupe FROM public.hayvanlar WHERE id = v_id;
    v_ok         := true;
    v_case_id    := NULL;
    v_sab_obj    := NULL;
    v_manuel_obj := NULL;
    v_start_date := NULL;
    v_tohu_obj   := NULL;
    BEGIN
      -- [P3b D4] onaylı açık-takipli satır: kapanış satır işlenmeden HEMEN ÖNCE
      -- (alt-transaction'ın ilk deyimi; neden='OVSYNC' — vaka-yolu sınıfı).
      IF v_takip_map ? v_id THEN
        PERFORM public._takip_kapat((v_takip_map ->> v_id)::uuid, 'OVSYNC');
      END IF;
      v_res := public._vaka_ac_tek(v_id, p_disease_id, p_notes, p_tarih);
      IF (v_res->>'ok') <> 'true' THEN
        v_ok := false;
        v_atlanan := v_atlanan || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', v_res->>'mesaj'));
      ELSE
        v_case_id := (v_res->>'case_id')::uuid;
        -- V1.2: vakanın GERÇEK start_date'i (p_tarih ya da bugün) — tohumlama
        -- hedefi ve acilan[i].tarih buna çapar
        SELECT start_date INTO v_start_date FROM public.cases WHERE id = v_case_id;
        IF p_sablon_id IS NOT NULL THEN
          BEGIN
            v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := p_sablon_id);
            v_sab_obj := jsonb_build_object(
              'gun_sayisi',   v_sab->'gun_sayisi',
              'seans_sayisi', v_sab->'seans_sayisi',
              'atlanan',      v_sab->'atlanan');
            IF v_tohumlama_var THEN
              v_top := public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := p_sablon_id);
              v_sab_obj := v_sab_obj || jsonb_build_object(
                'toplanti_uygulandi', COALESCE((v_top->>'olustu') = 'true', false),
                'toplanti_sebep',     v_top->'sebep');
            ELSE
              v_sab_obj := v_sab_obj || jsonb_build_object('toplanti_uygulandi', false);
            END IF;
          EXCEPTION WHEN OTHERS THEN
            -- Şablon hatası tek hayvanı hatalar'a düşürür; vaka açık kalır.
            v_ok := false;
            v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
              'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM, 'case_id', v_case_id));
          END;
        ELSIF p_items IS NOT NULL THEN
          -- V2: çoklu gün manuel plan — günler gun ASC (v_days_sorted), her
          -- gün bug059 motoruyla vakanın start_date + (gun - 1) tarihine
          -- işlenir (start_date = p_tarih ya da bugün — V1.2 çapası).
          -- KISMİ GÜN SEMANTİĞİ: HER GÜN kendi BEGIN/EXCEPTION alt bloğunda
          -- işlenir — bir günde motor ok:false ya da EXCEPTION → hayvan
          -- hatalar'a düşer (case_id + gün bilgisiyle), vaka AÇIK kalır ve
          -- ÖNCEKİ günlerin satırları (treatment_days, uygulamalar, ilaç
          -- kayıtları, stok hareketleri, görevler) DURAR (gün alt bloğu
          -- yalnız kendi gününü geri alır); kalan günler denenmez,
          -- sıradaki hayvana geçilir. Böyle bir hayvan acilan'a girmez
          -- (V1.1 tek-gün deseninin çoklu-gün genelleştirmesi).
          v_gun_sayisi   := 0;
          v_seans_toplam := 0;
          v_err_gun      := NULL;
          FOR v_day IN SELECT * FROM pg_catalog.jsonb_array_elements(v_days_sorted)
          LOOP
            EXIT WHEN NOT v_ok;
            v_err_gun := (v_day->>'gun')::int;
            BEGIN
              v_r := public.add_treatment_day_with_sessions(
                p_case_id         := v_case_id,
                p_date            := v_start_date + (v_err_gun - 1),
                p_sessions        := v_day->'sess',
                p_existing_day_id := NULL);
              IF (v_r->>'ok') <> 'true' THEN
                v_ok := false;
                v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
                  'hayvan_id', v_id, 'kupe', v_kupe,
                  'mesaj', COALESCE(v_r->>'mesaj', 'Tedavi günü eklenemedi'),
                  'case_id', v_case_id, 'gun', v_err_gun));
              ELSE
                v_gun_sayisi   := v_gun_sayisi + 1;
                v_seans_toplam := v_seans_toplam
                                  + COALESCE((v_r->>'seans_sayisi')::int, 0);
              END IF;
            EXCEPTION WHEN OTHERS THEN
              v_ok := false;
              v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
                'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM,
                'case_id', v_case_id, 'gun', v_err_gun));
            END;
          END LOOP;
          IF v_ok THEN
            v_manuel_obj := jsonb_build_object(
              'gun_sayisi',   v_gun_sayisi,
              'seans_sayisi', v_seans_toplam);
          END IF;
        END IF;

        -- V1.2: planlı tohumlama — HER başarılı açılan vaka için, şablon/
        -- manuel'den SONRA, yalnız p_tohumlama iken. Yumuşak: sonuç asla
        -- hatalar'a sayılmaz, vaka açık kalır; sebep acilan[i].tohumlama'ya
        -- yazılır (uygunluk reddi / RPC yok / beklenmeyen hata).
        -- V2.2: p_tohumlama_cakisma modu — 'ekle' (default, davranış
        -- değişmez) | 'atla' (eski açık görev varsa YENİSİ AÇILMAZ) |
        -- 'uzerine_yaz' (eski açık görevler YUMUŞAK İPTAL + görev başına
        -- islem_log denetimi, sonra yeni görev açılır).
        IF p_tohumlama THEN
          BEGIN
            IF v_tohu_ekle_var THEN
              -- Çakışma taraması (yalnız mod <> 'ekle'; ekle hiç taramaz —
              -- regresyon birebir): hayvanın AÇIK TOHUMLAMA_PLANLI görevleri
              -- HER VAKADAN (kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:%'), YENİ
              -- açılan vakanın kendi satırları HARİÇ — şablon yolu aynı RPC
              -- çağrısında az önce görev açtıysa o "eski" değildir; aynı-vaka
              -- tekrarı vaka_tohumlama_ekle'nin mevcut guard'ında kalır.
              -- Sıra hedef_tarih ASC (en eski önce; NULL en son).
              v_uzerine := NULL;
              v_tohu_obj := NULL;
              IF p_tohumlama_cakisma <> 'ekle' THEN
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                  'id', g.id::text, 'hedef_tarih', g.hedef_tarih)
                                ORDER BY g.hedef_tarih ASC, g.id ASC),
                               '[]'::jsonb)
                  INTO v_cakisma
                  FROM public.gorev_log g
                 WHERE g.hayvan_id = v_id
                   AND g.gorev_tipi = 'TOHUMLAMA_PLANLI'
                   AND g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:%'
                   AND g.kaynak NOT LIKE
                       'TEDAVI_SABLON_TOHUMLAMA:' || v_case_id::text || ':%'
                   AND g.tamamlandi = false
                   AND g.iptal = false;

                IF p_tohumlama_cakisma = 'atla' AND v_cakisma <> '[]'::jsonb THEN
                  -- Sahip kararı: 'Atla' = yenisi AÇILMAZ; eski planın hedef
                  -- tarihi (en eski açık görev) sebebe yazılır.
                  v_tohu_obj := jsonb_build_object(
                    'olustu', false,
                    'sebep', 'Açık planlı tohumlama vardı — atlandı (eski plan: '
                             || COALESCE(to_char(
                                  (v_cakisma->0->>'hedef_tarih')::date, 'DD.MM'),
                                  '?')
                             || ')');
                ELSIF p_tohumlama_cakisma = 'uzerine_yaz'
                      AND v_cakisma <> '[]'::jsonb THEN
                  -- Sahip kararı: 'Üzerine yaz' = eski görev YUMUŞAK İPTAL.
                  -- Kapanış şekli close_case_with_remaining 5b adımının
                  -- (TOHUMLAMA_PLANLI iptali: iptal+tamamlandi+tarih)
                  -- aynası; kapatan_ref trg_gorev_parent_kapandi
                  -- konvansiyonuyla. Görev başına islem_log denetimi
                  -- (GOREV_IPTAL önceli yok — ip'ler GOREV_EKLENDI/
                  -- GOREV_TAMAMLA/GOREV_OTOKAPAT).
                  v_uzerine := '[]'::jsonb;
                  FOR v_c IN
                    SELECT x.id, x.hedef_tarih
                    FROM pg_catalog.jsonb_to_recordset(v_cakisma)
                         AS x(id text, hedef_tarih date)
                  LOOP
                    UPDATE public.gorev_log
                       SET iptal = true,
                           tamamlandi = true,
                           tamamlanma_tarihi = now(),
                           kapatan_ref = 'toplu-vaka-uzerine-yaz'
                     WHERE id::text = v_c.id
                       AND tamamlandi = false
                       AND iptal = false;
                    IF FOUND THEN
                      INSERT INTO public.islem_log
                        (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
                      VALUES
                        (gen_random_uuid()::text,
                         'TOHUMLAMA_PLANLI_IPTAL',
                         v_id, v_c.id, 'gorev_log',
                         jsonb_build_object(
                           'sebep', 'toplu vaka üzerine yazma'));
                      v_uzerine := v_uzerine || to_jsonb(
                        COALESCE(to_char(v_c.hedef_tarih, 'DD.MM'), '?'));
                    END IF;
                  END LOOP;
                END IF;
              END IF;

              IF v_tohu_obj IS NULL THEN
                v_tohu_tarih := v_start_date + p_tohumlama_gun_offset;
                v_tohu_res := public.vaka_tohumlama_ekle(
                  p_case_id := v_case_id,
                  p_tarih   := v_tohu_tarih,
                  p_saat    := COALESCE(p_tohumlama_saat, '08:00')::time);
                IF (v_tohu_res->>'ok') = 'true' THEN
                  v_tohu_obj := jsonb_build_object(
                    'olustu', true, 'gorev_id', v_tohu_res->'gorev_id');
                  -- V2.2: üzerine yazıldıysa iptal edilen eski planların
                  -- tarihleri (eski→yeni) sonuca eklenir.
                  IF v_uzerine IS NOT NULL AND v_uzerine <> '[]'::jsonb THEN
                    v_tohu_obj := v_tohu_obj || jsonb_build_object(
                      'uzerine_yazildi', v_uzerine);
                  END IF;
                ELSE
                  v_tohu_obj := jsonb_build_object(
                    'olustu', false,
                    'sebep', COALESCE(v_tohu_res->>'mesaj', 'Bilinmeyen sebep'));
                END IF;
              END IF;
            ELSE
              -- vaka_tohumlama_ekle canlıda yok (GT drift): güvenli düşüm
              v_tohu_obj := jsonb_build_object(
                'olustu', false, 'sebep', 'Tohumlama RPC yok');
            END IF;
          EXCEPTION WHEN OTHERS THEN
            v_tohu_obj := jsonb_build_object('olustu', false, 'sebep', SQLERRM);
          END;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_ok := false;
      v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM));
    END;

    IF v_ok THEN
      v_basari := v_basari + 1;
      v_acilan := v_acilan || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_id, 'kupe', v_kupe, 'case_id', v_case_id,
        'tarih', v_start_date,
        'sablon', v_sab_obj, 'manuel', v_manuel_obj,
        'tohumlama', v_tohu_obj));
    END IF;
  END LOOP;

  IF v_tohumlama_var THEN
    RETURN jsonb_build_object('ok', true, 'toplam', v_toplam, 'basari', v_basari,
      'atlanan', v_atlanan, 'hatalar', v_hatalar, 'acilan', v_acilan,
      'takip_acik', v_takip_acik_list,
      'sablon', p_sablon_id IS NOT NULL, 'manuel', p_items IS NOT NULL,
      'tohumlama', p_tohumlama);
  END IF;

  -- Tohumlama (şablon) helper'ı canlıda yok: güvenli düşüm işareti
  RETURN jsonb_build_object('ok', true, 'toplam', v_toplam, 'basari', v_basari,
    'atlanan', v_atlanan, 'hatalar', v_hatalar, 'acilan', v_acilan,
    'takip_acik', v_takip_acik_list,
    'sablon', p_sablon_id IS NOT NULL, 'manuel', p_items IS NOT NULL,
    'toplanti_uygulandi', false, 'tohumlama', p_tohumlama);
END;
$function$;

-- ═══ 8) kizginlik_vaka_ac — C4 fail-closed kapı (tanıdan bağımsız) + H4
--     standart deseni + C2 imza ════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.kizginlik_vaka_ac(text, text, text, text);
CREATE OR REPLACE FUNCTION public.kizginlik_vaka_ac(p_kizginlik_id text, p_tani text, p_tohumlama_id text DEFAULT NULL::text, p_notlar text DEFAULT NULL::text, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_kiz       record;
  v_case_id   uuid;
  v_disease   record;
  v_takip     record;
BEGIN
  -- (0) H4 standart deseni — KİLİTSİZ keşif; hızlı ret mevcut sözleşmeyle
  -- (aynı mesaj, aynı sırada).
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- hayvan İLK kilit (MK9-N muteks — FOR UPDATE ASLA); hayvan yoksa kilit
  -- alınmaz, eski akış cases INSERT'te FK ile düşer (yeni hata kodu YOK).
  PERFORM 1 FROM public.hayvanlar WHERE id = v_kiz.hayvan_id FOR NO KEY UPDATE;

  -- kızgınlık satırı yeniden doğrulama (arada silindiyse aynı red sözleşmesi)
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- (1) P3b C4 kapısı — TANIDAN BAĞIMSIZ, fail-closed (plan.md:452): keyfi
  -- p_tani metni P3a tetikleyici ağını KAÇIRIR → kapı RPC gövdesinde ZORUNLU;
  -- P3a tetikleyici kapsamından ÖNCE, ilk yazmadan (diseases INSERT / cases
  -- INSERT) önce. Onaysız açık takip → TAKIP_ACIK red.
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = v_kiz.hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND AND NOT COALESCE(p_takip_onay, false) THEN
    RAISE EXCEPTION 'TAKIP_ACIK:%',
      jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                         'muayene_saat', v_takip.hedef_saat)::text;
  END IF;
  -- (2) onaylı → aynı transaction'da ÖNCE kapanış (vaka-yolu sınıfı —
  -- create_case onaylı yoluyla aynı kod), sonra vaka INSERT.
  IF FOUND THEN
    PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
  END IF;

  -- Hastalık adından disease_id bul (case-insensitive) — eski kaskad birebir
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
$function$;

-- ═══ C5 — imza geçişi ACL (her imza-değişen RPC; plan.md:450 birebir) ════
-- REVOKE PUBLIC,anon + GRANT authenticated,service_role — mevcut canlı ACL
-- (postgres sahibi + authenticated + service_role; anon/PUBLIC yok) korunur.
REVOKE ALL ON FUNCTION public.hizli_uygulama(text, text, numeric, text, text, text, boolean, text, timestamp with time zone, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hizli_uygulama(text, text, numeric, text, text, text, boolean, text, timestamp with time zone, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.seans_tamamla(uuid, boolean, text, boolean, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.seans_tamamla(uuid, boolean, text, boolean, text, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.bulk_ilac(text[], text, numeric, text, text[], text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bulk_ilac(text[], text, numeric, text, text[], text, text[]) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_case(text, uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_case(text, uuid, text, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.vaka_toplu_ac(text[], uuid, jsonb, uuid, text, date, boolean, integer, text, text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_toplu_ac(text[], uuid, jsonb, uuid, text, date, boolean, integer, text, text, text[]) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text, boolean) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260929000003_takip_kapanis_tetikleyicileri (P3a + P3b)
