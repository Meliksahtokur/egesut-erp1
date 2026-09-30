-- ============================================================================
-- Migration: 20260929000002_takip_gorev_ve_bos_devam (P2a katmanı)
-- Tarih: 2026-09-29 · Plan: docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md P2a
--   (G-20260930-OVSYNC-TAKIP-IMPL; P2b aynı dosyayı DEVRALIR — tek migration,
--   iki madde; P2b modları TOHUMLAMA_BOS_VE_DEVAM bu P2a zarfında YOKTUR)
-- Spec: design.md §6c.2-6c.3, §18.15 (domain-rules §18); DEGISMEZLER 1, 8;
--   MK9-N kilit sözleşmesi §10h H1/H3 + D5 (v7); #16 bölünme (şema/çekirdek yarısı)
--
-- Kapsam (P2a):
--   1) gorev_log.takip_kapanis_nedeni text NULL
--      (sözleşme değerleri: YENI_TOHUMLAMA|PG|OVSYNC|CIKIS|GEBE_BULUNDU —
--       CHECK DEĞİL, serbest text; liste sözleşmedir)
--   2) _takip_gorev_kur: guard'lı TAKIP_MUAYENE görev kurucu
--   3) _takip_kapat: idempotent takip kapatıcı (P3a tetikleyicileri + onay yolları
--      tek yardımcı)
--   4) _acik_disi_hedef_ic muafiyet genişletmesi: açık TAKIP_MUAYENE olan hayvan →
--      NULL (DEGISMEZ 1; zamanlayıcı + reconcile + dry-run yolları tek gövdede — S2c)
--   5) gorev_ertele_kural seed: TAKIP_MUAYENE ertelenebilir (erteleme yalnız birleşik
--      sonuç ekranından — P2b ERTALE; GEBELIK_KONTROL seed EKLENMEZ: §10d #3 karar)
--   6) ACL: DEGISMEZ 8 kalıbı — anon/PUBLIC EXECUTE yok
--
-- farm_id (D8 sahibin ölçüm kararı, 2026-09-29): dokunulan tabloların (gorev_log,
--   hayvanlar) HİÇBİRİNDE kolon ölçülmedi [OBSERVED egesut_lsp aynası
--   information_schema, 2026-09-30] → §14 gereği MEVCUT tabloya kolon EKLENMEZ,
--   gorev_log INSERT'ünden damga ÇIKARILMAZ. Aşağıdaki gövdede bu ad yalnız
--   yorumda geçer; SQL deyimlerinde yoktur.
--
-- MK9-N kilit sözleşmesi (§10h H1/H3 + D5, v7) — bu iki yardımcı DEĞİŞMEZ 13
--   kapsam (a) yardımcılarıdır:
--   • RPC yollarından çağrıldıklarında çağıran sarmal (P2b tohumlama_bos_ve_devam
--     ve onay yolları) `hayvanlar` satırını İLK `FOR NO KEY UPDATE` ile kilitler
--     (hayvan başına muteks); yardımcılar ek hayvan kilidi ALMAZ.
--   • H3 yön kuralı (istisna): tohumlama satırı, takip gorev_log satırından ÖNCE
--     kilitlenir (provalar T-72/T-72b).
--   • _takip_kapat tetikleyici yolundan (P3a) tek başına çağrıldığında hayvan
--     kilidi ALMAZ (§10h H3 — MK9-T geri alındı): yalnız hedef gorev_log satırını
--     `FOR NO KEY UPDATE` kilitler ve günceller; tek satır tipi, idempotent.
--
-- ACL (DEGISMEZ 8): yardımcılarda anon/PUBLIC EXECUTE yok; kalıp
--   20260926000003:106-107 (REVOKE PUBLIC,anon,authenticated + GRANT
--   authenticated,service_role). Yeni migration anon GRANT yazmaz.
--   _acik_disi_hedef_ic iç helper'dır — mevcut REVOKE'lu durumu korunur
--   (authenticated'a da verilmez; 20260925000001:78 kalıbı).
--
-- Revert (sahip kapısıyla, sırayla):
--   DROP FUNCTION public._takip_gorev_kur(uuid,text,int,time);
--   DROP FUNCTION public._takip_kapat(uuid,text);
--   -- _acik_disi_hedef_ic gövdesini 20260925000007 gövdesiyle (T1'li, TAKIP'siz)
--   CREATE OR REPLACE ... ile geri yaz
--   DELETE FROM public.gorev_ertele_kural WHERE gorev_tipi='TAKIP_MUAYENE';
--   ALTER TABLE public.gorev_log DROP COLUMN IF EXISTS takip_kapanis_nedeni;
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) gorev_log.takip_kapanis_nedeni ──────────────────────────────────
-- Zarf/plan birebir: text NULL; CHECK KISITI YOK (değer listesi sözleşme).
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS takip_kapanis_nedeni text;

COMMENT ON COLUMN public.gorev_log.takip_kapanis_nedeni IS
  'Takip muayenesi gorevinin kapanis nedeni. Sozlesme degerleri: YENI_TOHUMLAMA|PG|OVSYNC|CIKIS|GEBE_BULUNDU (CHECK yok — serbest text). Yazici: yalniz _takip_kapat.';

-- ── 2) _takip_gorev_kur — guard'lı kurucu ──────────────────────────────
-- Redler (mesaj ön eki UI zincirlerinin sözleşmesi):
--   hayvan yok        → TAKIP_HAYVAN_YOK
--   açık TAKIP_MUAYENE → TAKIP_ACIK:ZATEN_ACIK:{json: gorev_id, hedef_tarih, hedef_saat}
CREATE OR REPLACE FUNCTION public._takip_gorev_kur(
  p_hayvan_id     uuid,
  p_tohumlama_id  text,
  p_gun           int,
  p_saat          time
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev record;
  v_id    uuid;
BEGIN
  -- Guard 1: hayvan var mı (hayvanlar.id text; param uuid → ::text).
  IF NOT EXISTS (SELECT 1 FROM public.hayvanlar WHERE id = p_hayvan_id::text) THEN
    RAISE EXCEPTION 'TAKIP_HAYVAN_YOK';
  END IF;

  -- Guard 2: açık TAKIP_MUAYENE var mı — P1 takiptekiler kümesiyle birebir koşul
  -- (gorev_tipi + !tamamlandi + !iptal; 20260929000001:288-294).
  SELECT g.id, g.hedef_tarih, g.hedef_saat
    INTO v_gorev
    FROM public.gorev_log g
   WHERE g.hayvan_id = p_hayvan_id::text
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND THEN
    RAISE EXCEPTION 'TAKIP_ACIK:ZATEN_ACIK:%',
      jsonb_build_object(
        'gorev_id',    v_gorev.id,
        'hedef_tarih', v_gorev.hedef_tarih,
        'hedef_saat',  v_gorev.hedef_saat
      )::text;
  END IF;

  -- Kurulum. MK9-N: hayvan kilidi çağıran RPC sarmalına aittir (yukarıdaki
  -- sözleşme) — bu gövde kilitlemez. farm_id damgası YOK (D8): kolon ölçülmedi.
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat,
     tamamlandi, iptal, kaynak, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id::text, 'TAKIP_MUAYENE',
     'Takip muayenesi', CURRENT_DATE + p_gun, p_saat,
     false, false, 'TAKIP:' || p_tohumlama_id, p_tohumlama_id)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;

COMMENT ON FUNCTION public._takip_gorev_kur(uuid, text, int, time) IS
  'MK9-N (Degismez 13a): hayvan kilidi cagiran sarmala ait (FOR NO KEY UPDATE ONCE; H3: tohumlama satiri gorev_log satirindan ONCE). Guard: TAKIP_HAYVAN_YOK / TAKIP_ACIK:ZATEN_ACIK:{json}. TAKIP_MUAYENE gorevi kurar; kaynak=TAKIP:<tohumlama_id>.';

-- ── 3) _takip_kapat — idempotent kapatıcı ──────────────────────────────
CREATE OR REPLACE FUNCTION public._takip_kapat(
  p_gorev_id uuid,
  p_neden    text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_dur record;
BEGIN
  -- Yalnız hedef gorev_log satırını kilitler (MK9-N: tetikleyici yolu hayvan
  -- kilidi ALMAZ — §10h H3).
  SELECT COALESCE(iptal, false) AS iptal, COALESCE(tamamlandi, false) AS tamam
    INTO v_dur
    FROM public.gorev_log
   WHERE id = p_gorev_id
   FOR NO KEY UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TAKIP_GOREV_YOK:%', p_gorev_id;
  END IF;

  -- Idempotent: zaten iptal/tamamlandı → DOKUNMAZ (ikinci çağrı değişiklik yok).
  IF v_dur.iptal OR v_dur.tamam THEN
    RETURN;
  END IF;

  UPDATE public.gorev_log
     SET iptal = true,
         takip_kapanis_nedeni = p_neden
   WHERE id = p_gorev_id;
END;
$function$;

COMMENT ON FUNCTION public._takip_kapat(uuid, text) IS
  'MK9-N (Degismez 13a): idempotent takip kapatma — iptal/tamamlandi ise DOKUNMAZ; degilse iptal=true + takip_kapanis_nedeni. Tetikleyici yolu (P3a) hayvan kilidi ALMAZ; yalniz hedef gorev_log satirini FOR NO KEY UPDATE kilitler. RPC onay yollari hayvan muteksini kendileri alir.';

-- ── 4) _acik_disi_hedef_ic muafiyet genişletmesi ───────────────────────
-- Kalıp: 20260925000007:110-116 (T1 senkron muafiyet bloğu). Canlı gövde
-- (T1'li) birebir korunur; yalnız TAKIP_MUAYENE bloğu EKLENİR (DEGISMEZ 1;
-- zamanlayıcı + reconcile + dry-run yolları bu tek gövdeden beslenir — S2c).
CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_h   record;
  v_son text;
  v_k   date;
BEGIN
  -- Bayrak YOKSAYAN uygunluk (dry-run önizleme). Yeni iş yaratmaz.
  SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
    INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RETURN NULL;
  END IF;

  -- S1/M1: kısır hayvan üreme planına girmez (kisir kolonu; işaret kalkınca normal kural)
  IF v_h.kisir THEN
    RETURN NULL;
  END IF;

  SELECT t.sonuc INTO v_son FROM public.tohumlama t
   WHERE t.hayvan_id = p_hayvan_id
   ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
   LIMIT 1;
  IF v_son IN ('Gebe', 'Bekliyor') THEN
    RETURN NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM public.cases c
              WHERE c.animal_id = p_hayvan_id
                AND c.status = 'active'
                AND c.protocol_family IS NOT NULL) THEN
    RETURN NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM public.gorev_log g
              WHERE g.hayvan_id = p_hayvan_id
                AND g.gorev_tipi = 'OVSYNC_BASLAT'
                AND COALESCE(g.tamamlandi, false) = false
                AND COALESCE(g.iptal, false) = false) THEN
    RETURN NULL;
  END IF;

  -- ═══ T1 ek koşulu (cila 20260925000007) — açık senkron-protokol görevi varken
  --     yeni açık-dişi hedef ÜRETME. 188 kasıtlı zinciri etkilemez: OVSYNC_BASLAT
  --     bloğu yukarıda zaten NULL döndürür; bu koşul yalnız zincir çalışırken
  --     (ILAC/TOHUMLAMA_HAZIRLIK, 'senkron' damgalı) üretimi durdurur; görevler
  --     kapanınca zamanlayıcı normal üretimine döner (spec-s5 §7.1 sahibin kararı:
  --     kasıtlı ardışık zincirler korunur). Canlı damga deseni: aciklama
  --     '39. Gün PG (Presynch-14 senkron)' — kaynak-alanı damgası canlıda 0 satır,
  --     OR bacağı zararsız (spec §7.2-V3).
  IF EXISTS (
    SELECT 1 FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id
       AND g.gorev_tipi IN ('ILAC', 'TOHUMLAMA_HAZIRLIK')
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%')
  ) THEN
    RETURN NULL;
  END IF;

  -- ═══ TAKIP muafiyeti (P2a, takip-ekranı) — açık TAKIP_MUAYENE görevi varken
  --     yeni açık-dişi hedef ÜRETME (DEGISMEZ 1; §6c.5 + S2c): takipteki Boş
  --     hayvana zamanlayıcı/reconcile OVSYNC_BASLAT AÇMAZ; takip kapanınca
  --     üretim normal kuralına döner. Koşul P1 'takiptekiler' kümesiyle birebir
  --     (gorev_tipi + !tamamlandi + !iptal; 20260929000001:288-294).
  IF EXISTS (
    SELECT 1 FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
  ) THEN
    RETURN NULL;
  END IF;

  v_k := public._ovsync_kural_tarihi(p_hayvan_id);
  IF v_k IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN GREATEST(v_k, (now() AT TIME ZONE 'Europe/Istanbul')::date);
END;
$function$;

-- ── 5) gorev_ertele_kural seed ─────────────────────────────────────────
-- Zarf/plan: ('TAKIP_MUAYENE', true, 'yok', NULL, 7, NULL, NULL) — kalıp
--   20260925100003:64-88. Fiziksel yazım kalıp biçiminde (açık kolon listesi):
--   asimi_uyari_gun=7 / zincir_tetikler={} / guncellendi=now() NOT NULL+
--   DEFAULT'lu kolonlar default'la gelir — ortaya çıkan satır zarf 7'lisinin
--   birebir karşılığıdır (NULL → "yok/default").
-- §10d #3 KARAR: GEBELIK_KONTROL seed EKLENMEZ — erteleme yalnız birleşik
--   sonuç ekranından (P2b ERTALE), varsayılan SAATSIZ; genel "ertele" butonu
--   her iki tipte de yoktur. Idempotentlik ON CONFLICT yerine WHERE NOT EXISTS
--   ile: baseline aynası constraint-free olduğundan izole validate DB'sinde
--   gorev_ertele_kural PK'sız kurulur (db-validate 1. tur bulgusu) — kalıp
--   20260925100003 da constraint'e dayanmayan düz INSERT kullanır.
--   7 kolon AÇIK yazılır (db-validate 2. tur bulgusu: baseline aynası DEFAULT
--   taşımıyor — NOT NULL kolonlara sözleşme değerleri explicit: asimi_uyari_gun=7,
--   zincir_tetikler='{}' [zarf "NULL"="yok"=boş katalog], guncellendi=now();
--   canlıda DEFAULT'lu üretimle birebir aynı satır).
INSERT INTO public.gorev_ertele_kural
  (gorev_tipi, ertelenebilir, pencere_kurali, max_erteleme_gun, asimi_uyari_gun, zincir_tetikler, guncellendi)
SELECT 'TAKIP_MUAYENE', true, 'yok', NULL, 7, '{}'::jsonb, now()
 WHERE NOT EXISTS (
  SELECT 1 FROM public.gorev_ertele_kural WHERE gorev_tipi = 'TAKIP_MUAYENE'
);

-- ── 6) ACL — DEGISMEZ 8 kalıbı (20260926000003:106-107 deseni) ─────────
REVOKE ALL ON FUNCTION public._takip_gorev_kur(uuid, text, int, time) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._takip_gorev_kur(uuid, text, int, time) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public._takip_kapat(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._takip_kapat(uuid, text) TO authenticated, service_role;

-- _acik_disi_hedef_ic: iç helper — mevcut REVOKE'lu durumu tazele (GRANT YOK).
REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ═════════════════════════════════════════════════════════════════════════════
-- Migration: 20260929000002_takip_gorev_ve_bos_devam (P2b katmanı)
-- Plan: docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md P2b (plan.md:279-342)
-- Spec: design.md §6c.1-6c.2, §6c.4; K15; §10c #2,#3,#4,#6,#7,#9,#10; S2-S10;
--   D1/D1-UI (§10e), C1/C6 (§10f), MK9-N/H1/H3/H4/H7 (§10g-§10h, v7)
--
-- Kapsam (P2b — üç fonksiyon, P2a transaction'ından AYRI transaction):
--   1) _tohumlama_gebe_uygula(p_tohumlama_id text, p_bos_duzeltme boolean DEFAULT false)
--      — D1 dahili çekirdek: tohumlama_sonuc_gebe'nin ortak gövdesi
--      [20260830000031:4-76] buraya taşınır; kilit-sonra-durum deseni TERS
--      (MK9-N hayvan NKU ÖNCE — plan.md:299); p_bos_duzeltme=true kolunda
--      D1 koşul seti (plan.md:304) + normatif bos_atama_tarihi çözücüsü
--      (plan.md:316-324 birebir) + snapshot.bos_duzeltme izi.
--   2) tohumlama_sonuc_gebe(text) — davranış BİTİŞİK yeniden tanım: gövde
--      çekirdeğe yönlendirir (p_bos_duzeltme=false; Bekliyor-only kural
--      çekirdekte yaşar). İmza/ACL davranışı değişmez (authenticated+service_role).
--   3) tohumlama_bos_ve_devam(...) — tek sarmal RPC (imza plan.md:288-297
--      birebir): XOR guard, TAKIP_ACIK/PG_KAPI (birleşik dahil), dry-run
--      (plan.md:300 alan seti birebir; C6 farm_id filtresi), seçim uzayı
--      açık tablosu (plan.md:301), Boş çekirdeği davranışı gövdede YENİ kod
--      [davranış referansı 20260924000001:508-570], OVSYNC/PG/TAKIP/ERTALE
--      modları, bayrak kapısı, MK9-N + H3 kilit sırası.
--   Mevcut tohumlama_sonuc_bos RPC'sine DOKUNULMAZ (§10h H1).
--
-- Kilit sözleşmesi (DEGISMEZ 13 daraltılmış + §10h H3/H4):
--   keşif (kilitsiz) → hayvanlar FOR NO KEY UPDATE → tohumlama FOR UPDATE →
--   gorev_log FOR UPDATE (H3 yön kuralı: tohumlama takip görevinden ÖNCE).
--   _tohumlama_gebe_uygula kendi muteksini kendisi alır (genel RPC yolundan
--   da çağrılabildiği için; sarmaldan çağrıda re-entrant maliyetsiz).
--
-- ACL (DEGISMEZ 8): üç fonksiyon da REVOKE PUBLIC,anon,authenticated;
--   _tohumlama_gebe_uygula GRANT'SIZ (yalnız sarmal + genel RPC gövdesi
--   ulaşır); tohumlama_sonuc_gebe ve tohumlama_bos_ve_devam'a GRANT
--   authenticated, service_role. Anon GRANT yok.
--
-- Revert (sahip kapısıyla, sırayla):
--   DROP FUNCTION public.tohumlama_bos_ve_devam(text,uuid,text,text,numeric,int,time,text,boolean);
--   -- tohumlama_sonuc_gebe: 20260830000031 gövdesi (canlı yedeği
--   -- assets/tohumlama_sonuc_gebe_canli.sql) CREATE OR REPLACE ile geri yazılır
--   DROP FUNCTION public._tohumlama_gebe_uygula(text, boolean);
-- ============================================================================
-- ── P2b 1) D1 çekirdeği: _tohumlama_gebe_uygula ────────────────────────────
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public._tohumlama_gebe_uygula(
  p_tohumlama_id  text,
  p_bos_duzeltme  boolean DEFAULT false
)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hayvan_id         text;
  v_toh               record;
  v_son_toh_id        text;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
  v_bos_atama_tarihi  date;
  v_eksikler          text[] := '{}';
BEGIN
  -- ── H4 kilitsiz keşif: hayvan_id ──────────────────────────────────────────
  SELECT hayvan_id INTO v_hayvan_id
    FROM public.tohumlama
   WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama bulunamadı');
  END IF;

  -- ── MK9-N: hayvan muteksi — İLK kilit (DEGISMEZ 13; plan.md:299 "kilit-sonra-
  --    durum deseni TERS çevrilir") ──────────────────────────────────────────
  PERFORM 1 FROM public.hayvanlar WHERE id = v_hayvan_id FOR NO KEY UPDATE;

  -- ── Son tohumlama satır kilidi (sorgu 20260830000031:29-34 birebir — FU) ──
  SELECT id::text INTO v_son_toh_id
    FROM public.tohumlama
   WHERE hayvan_id = v_hayvan_id
   ORDER BY tarih DESC, created_at DESC
   LIMIT 1
   FOR UPDATE;

  -- Hedef satır kilidi + yeniden doğrulama (H4)
  SELECT * INTO v_toh
    FROM public.tohumlama
   WHERE id::text = p_tohumlama_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama bulunamadı');
  END IF;
  v_hayvan_id := v_toh.hayvan_id;

  IF p_bos_duzeltme THEN
    -- ── D1 koşul seti (plan.md:304 — HEPSİ zorunlu; eksik → BOS_DUZELTME_KOSUL)
    --    (3) hedef tohumlama hayvanın SON tohumlaması (plain != — v_son_toh_id
    --        pratikte NOT NULL: keşif satırı hayvanın kayıtlı tohumlaması;
    --        false-yol yazımıyla aynı biçim [20260830000031:36])
    IF v_son_toh_id != p_tohumlama_id THEN
      v_eksikler := v_eksikler || 'son_tohumlama_degil'::text;
    END IF;
    --    (4) hedef tohumlama sonuc='Boş'
    IF v_toh.sonuc IS DISTINCT FROM 'Boş' THEN
      v_eksikler := v_eksikler || 'sonuc_bos_degil'::text;
    END IF;
    --    (5) o tohumlamaya bağlı AÇIK takip zinciri
    IF NOT EXISTS (
      SELECT 1 FROM public.gorev_log
       WHERE kaynak = 'TAKIP:' || p_tohumlama_id
         AND COALESCE(tamamlandi, false) = false
         AND COALESCE(iptal, false) = false
    ) THEN
      v_eksikler := v_eksikler || 'acik_takip_yok'::text;
    END IF;
    --    aktif hayvan (gövde kalıbı 20260830000031:40-44; red sözleşmesi eksikler listesine girer)
    SELECT tohumlama_durumu INTO v_onceki_durum
      FROM public.hayvanlar
     WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
    IF NOT FOUND THEN
      v_eksikler := v_eksikler || 'hayvan_aktif_degil'::text;
    END IF;

    IF array_length(v_eksikler, 1) > 0 THEN
      RAISE EXCEPTION 'BOS_DUZELTME_KOSUL:%',
        jsonb_build_object('eksikler', to_jsonb(v_eksikler))::text;
    END IF;

    -- ── Normatif bos_atama_tarihi çözücüsü (plan.md:316-324 SQL birebir) ──
    SELECT (i.tarih AT TIME ZONE 'Europe/Istanbul')::date
      INTO v_bos_atama_tarihi
      FROM public.islem_log i
     WHERE i.tip = 'TOHUMLAMA_SONUC' AND i.ref_tablo = 'tohumlama'
       AND i.ref_id = p_tohumlama_id
       AND i.durum IS DISTINCT FROM 'geri_alindi'
       AND i.snapshot->>'iptal_sebep' = 'bos'
     ORDER BY i.tarih DESC, i.id DESC
     LIMIT 1;
  ELSE
    -- ── Bekliyor-only kural — DEGISMEZ (20260830000031:21-27 mesajlar birebir)
    IF v_toh.sonuc != 'Bekliyor' THEN
      RETURN jsonb_build_object('ok', false, 'mesaj',
        CASE
          WHEN v_toh.sonuc = 'Abort' THEN 'Bu tohumlama kaydı abort edildi — tekrar gebe işaretlenemez. Hayvanı tekrar tohumlamak için yeni bir tohumlama kaydı girin.'
          ELSE 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir'
        END);
    END IF;

    IF v_son_toh_id != p_tohumlama_id THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Sadece son tohumlama gebe ilanı alabilir');
    END IF;

    SELECT tohumlama_durumu INTO v_onceki_durum
      FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan aktif değil');
    END IF;
  END IF;

  -- ── Yan etkiler (20260830000031:46-58 birebir; düzeltme modunda da aynen) ──
  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Gebe' WHERE id = v_toh.hayvan_id;

  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
    FROM public.gorev_log
   WHERE hayvan_id = v_toh.hayvan_id
     AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK', 'TOHUMLAMA_PLANLI')
     AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
   WHERE hayvan_id = v_toh.hayvan_id
     AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK', 'TOHUMLAMA_PLANLI')
     AND NOT tamamlandi AND NOT iptal;

  -- ── Audit: GEBE_ATAMA (20260830000031:60-72 birebir; düzeltme modunda ek blok) ──
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
      'iptal_sebep', 'gebe',
      'bos_duzeltme', CASE WHEN p_bos_duzeltme THEN
        jsonb_build_object(
          'eski_sonuc', v_toh.sonuc,
          'bos_atama_tarihi', v_bos_atama_tarihi,
          'takip_kapanis', 'GEBE_BULUNDU'
        )
      END
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$;

COMMENT ON FUNCTION public._tohumlama_gebe_uygula(text, boolean) IS
  'P2b D1 cekirdek: tohumlama_sonuc_gebe ortak govdesi. p_bos_duzeltme=false: Bekliyor-only (davranis 20260830000031 bitisik). true: D1 kosul seti (plan.md:304) — son tohumlama + sonuc=Boş + acik TAKIP zinciri + aktif hayvan; Boş→Gebe + snapshot.bos_duzeltme izi (eski_sonuc, bos_atama_tarihi=Europe/Istanbul yerel gün normatif çözücüsünden, takip_kapanis=GEBE_BULUNDU). MK9-N: hayvan NKU ILK kilit. ACL: yalniz sarmal/cekirdek-cagiran ulasir (GRANT yok).';

-- D1 çekirdeği iç yardımcı: PUBLIC/anon/authenticated KAPALI (DEGISMEZ 8;
--   plan.md:303 "Çekirdek kendi başına REST'ten çağrılamaz").
REVOKE ALL ON FUNCTION public._tohumlama_gebe_uygula(text, boolean) FROM PUBLIC, anon, authenticated;

-- ── P2b 2) Genel tohumlama_sonuc_gebe — çekirdeğe yönlendirme ──────────────
-- Davranış BİTİŞİK: imza aynı (text→jsonb); gövde _tohumlama_gebe_uygula(id,
-- false) çağırır. Bekliyor-only kural çekirdeğin p_bos_duzeltme=false kolunda
-- yaşar (plan.md:303/337). search_path sertleşmesi DEGISMEZ 8 gereği; red
-- mesajları jsonb olarak birebir korunur.
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(p_tohumlama_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN public._tohumlama_gebe_uygula(p_tohumlama_id, false);
END;
$function$;

-- ACL: mevcut davranış korunur (js/forms.js authenticated çağırır; anon/PUBLIC yok)
REVOKE ALL ON FUNCTION public.tohumlama_sonuc_gebe(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_gebe(text) TO authenticated, service_role;

-- ── P2b 3) Sarmal RPC: tohumlama_bos_ve_devam ──────────────────────────────
CREATE OR REPLACE FUNCTION public.tohumlama_bos_ve_devam(
  p_tohumlama_id      text    DEFAULT NULL,
  p_muayene_gorev_id  uuid    DEFAULT NULL,
  p_secim             text    DEFAULT NULL,
  p_pg_urun           text    DEFAULT NULL,
  p_pg_doz            numeric DEFAULT NULL,
  p_gun               int     DEFAULT NULL,
  p_saat              time    DEFAULT NULL,
  p_notlar            text    DEFAULT NULL,
  p_onay              bool    DEFAULT false
)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bayrak      boolean := public._ovsync_pg_aktif();
  v_gorev       record;
  v_toh         record;
  v_hayvan      record;
  v_hayvan_id   text;
  v_toh_id      text;
  v_islem_id    text   := gen_random_uuid()::text;
  v_onceki_durum text;
  v_iptal_gorev_ids text[] := '{}';
  v_gecerli     boolean;
  v_tip         text;
  v_kural       date;
  v_bugun       date;
  v_takip       record;
  v_takip_var   boolean := false;
  v_pg_kapi     jsonb;
  v_hizli       jsonb;
  v_stok        record;
  v_pg_event    record;
  v_son_pg      jsonb;
  v_pg_adi      text;
  v_pg_doz_v    numeric;
  v_pg_birim    text;
  v_deneme      bigint;
  v_yeni_hedef  date;
  v_ilk         timestamptz;
  v_toplam      int;
  v_gebe        jsonb;
  v_takip_id    uuid;
  v_ovsync_id   uuid;
  v_kupe        text;
BEGIN
  -- ══ 0) XOR guard (#9 — plan.md:298) ══════════════════════════════════════
  IF (p_tohumlama_id IS NULL) = (p_muayene_gorev_id IS NULL) THEN
    RAISE EXCEPTION 'GIRIS_CIFT_ANLAMLI:%',
      jsonb_build_object(
        'p_tohumlama_id',     p_tohumlama_id,
        'p_muayene_gorev_id', p_muayene_gorev_id
      )::text;
  END IF;

  -- ══ 1) H4 kilitsiz keşif ═════════════════════════════════════════════════
  IF p_muayene_gorev_id IS NOT NULL THEN
    SELECT g.id, g.hayvan_id, g.gorev_tipi, g.hedef_tarih, g.hedef_saat, g.kaynak,
           g.ref_tohumlama_id,
           COALESCE(g.tamamlandi, false) AS tamam,
           COALESCE(g.iptal, false)      AS iptal
      INTO v_gorev
      FROM public.gorev_log g
     WHERE g.id = p_muayene_gorev_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TAKIP_KAPALI:%',
        jsonb_build_object('gorev_id', p_muayene_gorev_id, 'neden', 'GOREV_BULUNAMADI')::text;
    END IF;
    IF v_gorev.gorev_tipi NOT IN ('GEBELIK_KONTROL', 'TAKIP_MUAYENE') THEN
      RAISE EXCEPTION 'MUAYENE_GOREV_TIPI_UYUMSUZ:%',
        jsonb_build_object('gorev_tipi', v_gorev.gorev_tipi)::text;
    END IF;
    v_hayvan_id := v_gorev.hayvan_id;
  ELSE
    SELECT id::text, hayvan_id INTO v_toh_id, v_hayvan_id
      FROM public.tohumlama
     WHERE id::text = p_tohumlama_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TOH_YOK:%',
        jsonb_build_object('tohumlama_id', p_tohumlama_id)::text;
    END IF;
  END IF;

  -- ══ 2) MK9-N hayvan muteksi — İLK kilit (DEGISMEZ 13) ════════════════════
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_hayvan_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'TAKIP_HAYVAN_YOK:%', v_hayvan_id;
  END IF;

  -- ══ 3) Alt satır kilitleri — H3 yön kuralı: tohumlama FU ÖNCE, gorev_log FU
  --     SONRA (§10h H3; plan.md:299) ════════════════════════════════════════
  IF p_muayene_gorev_id IS NOT NULL THEN
    -- hedef tohumlama = görev.ref_tohumlama_id (cron P2a-dan GEBELIK_KONTROL ve
    --   P2a kurucu TAKIP_MUAYENE bu kolonu taşır — plan.md:147); yoksa son tohumlama
    SELECT t.* INTO v_toh
      FROM public.tohumlama t
     WHERE t.id::text = COALESCE(v_gorev.ref_tohumlama_id, (
              SELECT t2.id::text FROM public.tohumlama t2
               WHERE t2.hayvan_id = v_hayvan_id
               ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST
               LIMIT 1))
     FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TOH_YOK:%',
        jsonb_build_object('hayvan_id', v_hayvan_id, 'neden', 'GOREV_TOHUM_YOK')::text;
    END IF;
    v_toh_id := v_toh.id::text;

    IF v_gorev.ref_tohumlama_id IS NOT NULL AND v_gorev.ref_tohumlama_id != v_toh_id THEN
      RAISE EXCEPTION 'MUAYENE_TOH_UYUMSUZ:%',
        jsonb_build_object('gorev_tohum', v_gorev.ref_tohumlama_id,
                           'mevcut', v_toh_id,
                           'neden', 'GOREV_TOHUM_SON_DEGIL')::text;
    END IF;

    -- görev kilidi + yeniden doğrulama (TAKIP_KAPALI — yarışta ikinci oturum
    --   kilidi bekler, sonra kapalı/sonuçlu durumu GÖRÜR)
    SELECT COALESCE(tamamlandi, false) AS tamam, COALESCE(iptal, false) AS iptal
      INTO v_gorev.tamam, v_gorev.iptal
      FROM public.gorev_log
     WHERE id = p_muayene_gorev_id
     FOR UPDATE;
    IF v_gorev.tamam OR v_gorev.iptal THEN
      RAISE EXCEPTION 'TAKIP_KAPALI:%',
        jsonb_build_object('gorev_id', p_muayene_gorev_id,
                           'tamamlandi', v_gorev.tamam, 'iptal', v_gorev.iptal)::text;
    END IF;
  ELSE
    SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TOH_YOK:%',
        jsonb_build_object('tohumlama_id', p_tohumlama_id, 'neden', 'GORUSTE_SILINDI')::text;
    END IF;
    v_toh_id := v_toh.id::text;
  END IF;

  -- ══ 4) Seçim uzayı — açık tablo (plan.md:301; K15/D3) ════════════════════
  -- (IF/ELSIF deyimi: CASE-expression PL/pgSQL'de atama yapılmamış record
  --   alanına IFade içinde bile dokunmaya kalkar — "record not assigned yet";
  --   v_tip: Boş yolunda NULL — payload güvenli erişim)
  v_tip := NULL;
  IF p_muayene_gorev_id IS NOT NULL THEN
    v_tip := v_gorev.gorev_tipi;
  END IF;
  IF p_secim IS NOT NULL THEN
    IF p_muayene_gorev_id IS NOT NULL THEN
      v_gecerli := CASE v_gorev.gorev_tipi
        WHEN 'GEBELIK_KONTROL' THEN p_secim IN ('GEBE', 'OVSYNC', 'PG', 'TAKIP', 'ERTALE')
        ELSE p_secim IN ('GEBE', 'OVSYNC', 'PG', 'ERTALE')
      END;
    ELSE
      v_gecerli := p_secim IN ('OVSYNC', 'PG', 'TAKIP');
    END IF;
    IF NOT v_gecerli THEN
      IF p_muayene_gorev_id IS NOT NULL AND v_tip = 'TAKIP_MUAYENE' AND p_secim = 'TAKIP' THEN
        RAISE EXCEPTION 'TAKIP_YENIDEN_SECILEMEZ:%',
          jsonb_build_object('gorev_id', p_muayene_gorev_id, 'gorev_tipi', v_tip)::text;
      END IF;
      RAISE EXCEPTION 'SECIM_TANIMSIZ:%',
        jsonb_build_object('secim', p_secim, 'gorev_tipi', v_tip)::text;
    END IF;
  END IF;

  -- ══ 5) Dry-run (p_secim=NULL — yan etki YOK; bayrak-bağımsız hesap) ══════
  IF p_secim IS NULL THEN
    v_bugun := (now() AT TIME ZONE 'Europe/Istanbul')::date;
    v_kural := public._ovsync_kural_tarihi(v_hayvan_id);

    -- son_pg (C6: pg_application_event farm_id TAŞIYAN tek tablo →
    --   farm_id = public.current_farm_id() filtresi ZORUNLU; index
    --   (farm_id, hayvan_id, occurred_at DESC) [20260923000002:498-499])
    SELECT * INTO v_pg_event
      FROM public.pg_application_event e
     WHERE e.hayvan_id = v_hayvan_id
       AND e.farm_id = public.current_farm_id()
     ORDER BY e.occurred_at DESC
     LIMIT 1;

    IF FOUND THEN
      v_pg_doz_v := NULL; v_pg_birim := NULL; v_pg_adi := NULL;
      IF v_pg_event.stok_id IS NOT NULL THEN
        SELECT urun_adi, birim INTO v_pg_adi, v_pg_birim
          FROM public.stok WHERE id = v_pg_event.stok_id;
      END IF;
      IF v_pg_event.source_type = 'HIZLI_UYGULAMA' THEN
        SELECT doz, birim INTO v_pg_doz_v, v_pg_birim
          FROM public.uygulama_log WHERE id::text = v_pg_event.source_id;
      ELSIF v_pg_event.source_type = 'TEDAVI_SEANS' THEN
        SELECT dose, unit INTO v_pg_doz_v, v_pg_birim
          FROM public.treatment_day_uygulamalar WHERE id::text = v_pg_event.source_id;
      ELSIF v_pg_event.source_type = 'TOPLU_ILAC' THEN
        SELECT (snapshot->>'miktar')::numeric, snapshot->>'ilac_adi'
          INTO v_pg_doz_v, v_pg_adi
          FROM public.islem_log WHERE id = v_pg_event.source_id;
      END IF;
      v_son_pg := jsonb_build_object('stok_id', v_pg_event.stok_id, 'urun_adi', v_pg_adi,
                                     'doz', v_pg_doz_v, 'birim', v_pg_birim);
    END IF;

    -- deneme_sayisi (DEGISMEZ 7 / §18.14: SON DOĞUMDAN beri; doğum yoksa ömür
    --   boyu — P1 hayvan_ureme CTE kalıbı birebir [20260929000001:314-320])
    SELECT count(*) INTO v_deneme
      FROM public.tohumlama t
     WHERE t.hayvan_id = v_hayvan_id
       AND ((SELECT max(d2.tarih) FROM public.dogum d2 WHERE d2.anne_id = v_hayvan_id) IS NULL
            OR t.tarih >= (SELECT max(d2.tarih) FROM public.dogum d2 WHERE d2.anne_id = v_hayvan_id));

    -- takip durumu (P1 takiptekiler koşuluyla birebir: tip + !tamamlandi + !iptal)
    SELECT g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = v_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;

    RETURN jsonb_build_object(
      'ok',             true,
      'bayrak_kapali',  NOT v_bayrak,
      'varsayilan_gun', 7,
      'ovsync_kilitli', COALESCE(v_hayvan.kisir, false) OR v_kural IS NULL OR v_kural > v_bugun,
      'kilit_gerekce',  CASE WHEN COALESCE(v_hayvan.kisir, false) THEN 'KISIR'
                             WHEN v_kural IS NULL                  THEN 'TABAN_YOK'
                             WHEN v_kural > v_bugun                THEN 'KURAL_GUNU' END,
      'kural_tarihi',   v_kural,
      'kalan_gun',      CASE WHEN v_kural IS NOT NULL AND v_kural > v_bugun THEN v_kural - v_bugun END,
      'son_pg',         v_son_pg,
      'deneme_sayisi',  v_deneme,
      'takip_acik',     FOUND,
      'takip_bilgi',    CASE WHEN FOUND THEN
                          jsonb_build_object('hedef_tarih', v_takip.hedef_tarih, 'hedef_saat', v_takip.hedef_saat)
                        END
    );
  END IF;

  -- ══ 6) Bayrak kapısı (#6 + MK9-K — plan.md:332) ══════════════════════════
  IF NOT v_bayrak THEN
    RAISE EXCEPTION 'OZELLIK_KAPALI';
  END IF;

  -- ══ 7) GEBE modu (muayene yolu — plan.md:302-304) ════════════════════════
  IF p_secim = 'GEBE' THEN
    -- D1 çekirdeği ÖNCE çağrılır (koşul 5 'açık takip zinciri' bu görevi
    --   kapsadığından — görev tamamlanırsa zincir bulunamaz); görev tamamlama
    --   SONRA. RAISE durumunda tümü geri alınır (tek transaction).
    IF v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN
      v_gebe := public._tohumlama_gebe_uygula(v_toh_id, true);
    ELSE
      v_gebe := public._tohumlama_gebe_uygula(v_toh_id, false);
    END IF;
    IF NOT COALESCE((v_gebe->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'GEBE_SONUC_RED:%',
        jsonb_build_object('mesaj', v_gebe->>'mesaj')::text;
    END IF;

    UPDATE public.gorev_log
       SET tamamlandi = true,
           tamamlanma_tarihi = now(),
           takip_kapanis_nedeni = CASE WHEN v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN 'GEBE_BULUNDU' END
     WHERE id = p_muayene_gorev_id;

    RETURN jsonb_build_object(
      'ok', true, 'secim', 'GEBE', 'gorev_id', p_muayene_gorev_id,
      'tohumlama_id', v_toh_id, 'islem_id', v_gebe->>'islem_id',
      'takip_kapanis', CASE WHEN v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN 'GEBE_BULUNDU' END
    );
  END IF;

  -- ══ 8) ERTALE (yalnız muayene yolu — plan.md:330) ════════════════════════
  IF p_secim = 'ERTALE' THEN
    v_yeni_hedef := CURRENT_DATE + COALESCE(p_gun, 7);

    IF v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN
      -- takip toplam süresi: zincirin İLK kuruluşundan yeni hedefe (S-7 eşik 21 g)
      SELECT min(created_at) INTO v_ilk
        FROM public.gorev_log
       WHERE gorev_tipi = 'TAKIP_MUAYENE' AND kaynak = v_gorev.kaynak;
      IF v_ilk IS NOT NULL THEN
        v_toplam := v_yeni_hedef - (v_ilk AT TIME ZONE 'Europe/Istanbul')::date;
        IF v_toplam >= 21 AND NOT COALESCE(p_onay, false) THEN
          RAISE EXCEPTION 'TAKIP_UZADI:%',
            jsonb_build_object('toplam_gun', v_toplam)::text;
        END IF;
      END IF;
    END IF;

    UPDATE public.gorev_log
       SET hedef_tarih = v_yeni_hedef,
           hedef_saat  = p_saat
     WHERE id = p_muayene_gorev_id;

    RETURN jsonb_build_object(
      'ok', true, 'secim', 'ERTALE', 'gorev_id', p_muayene_gorev_id,
      'tohumlama_id', v_toh_id, 'hedef_tarih', v_yeni_hedef, 'hedef_saat', p_saat
    );
  END IF;

  -- ══ 9) Muayene görevi tamamlanma sözleşmesi (plan.md:333 — ERTALE hariç)
  IF p_muayene_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
       SET tamamlandi = true, tamamlanma_tarihi = now()
     WHERE id = p_muayene_gorev_id;
  END IF;

  -- ══ 10) Boş çekirdeği davranışı — gövdede YENİ kod (§10h H1; davranış
  --      referansı 20260924000001:508-570 birebir) ═════════════════════════
  IF v_toh.sonuc = 'Bekliyor' THEN
    SELECT tohumlama_durumu INTO v_onceki_durum
      FROM public.hayvanlar WHERE id = v_hayvan_id AND durum = 'Aktif';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'HAYVAN_AKTIF_DEGIL:%', v_hayvan_id;
    END IF;

    UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = v_toh_id;
    UPDATE public.hayvanlar SET tohumlama_durumu = 'Boş' WHERE id = v_hayvan_id;

    SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
      FROM public.gorev_log
     WHERE hayvan_id = v_hayvan_id
       AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
       AND NOT tamamlandi AND NOT iptal;

    UPDATE public.gorev_log SET iptal = true
     WHERE hayvan_id = v_hayvan_id
       AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
       AND NOT tamamlandi AND NOT iptal;

    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (
      v_islem_id, 'TOHUMLAMA_SONUC', v_hayvan_id, v_toh_id, 'tohumlama',
      jsonb_build_object(
        'olusturulan', '[]'::jsonb,
        'guncellenen', jsonb_build_array(
          jsonb_build_object('tablo', 'tohumlama', 'id', v_toh_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
          jsonb_build_object('tablo', 'hayvanlar', 'id', v_hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
        ),
        'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
        'iptal_sebep', 'bos'
      )
    );
  ELSIF v_toh.sonuc IS DISTINCT FROM 'Boş' THEN
    -- sonucu zaten girilmiş tohumlama: HİÇBİR yazma olmaz (plan.md:298)
    RAISE EXCEPTION 'TOH_SONUCLU:%',
      jsonb_build_object('tohumlama_id', v_toh_id, 'sonuc', v_toh.sonuc)::text;
  END IF;
  -- (v_toh.sonuc = 'Boş' ise Boş atama adımı atlanır — muayene yolu zincirinde
  --   Boş zaten atanmış; devam işlemi yalnız.)

  -- ══ 11) TAKIP modu (plan.md:329 — _acik_disi_gorev_kur ATLANIR, DEGISMEZ 1)
  IF p_secim = 'TAKIP' THEN
    v_takip_id := public._takip_gorev_kur(
      v_hayvan_id::uuid, v_toh_id,
      COALESCE(p_gun, 7),
      COALESCE(p_saat, (now() AT TIME ZONE 'Europe/Istanbul')::time));
    RETURN jsonb_build_object(
      'ok', true, 'secim', 'TAKIP', 'tohumlama_id', v_toh_id,
      'islem_id', v_islem_id, 'gorev_id', v_takip_id
    );
  END IF;

  -- ══ 12) OVSYNC modu (plan.md:327) ════════════════════════════════════════
  IF p_secim = 'OVSYNC' THEN
    -- TAKIP_ACIK kapısı (DEGISMEZ 3 — hayvanın AÇIK BASKA takibi; görevin
    --   kendisi hariç — muayene yolu görevi zaten tamamlandı)
    SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = v_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND (p_muayene_gorev_id IS NULL OR g.id <> p_muayene_gorev_id)
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;
    v_takip_var := FOUND;

    IF v_takip_var AND NOT COALESCE(p_onay, false) THEN
      RAISE EXCEPTION 'TAKIP_ACIK:%',
        jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                           'muayene_saat', v_takip.hedef_saat)::text;
    END IF;

    -- Ovsync hard block (DEGISMEZ 6 — kısır / kural günü gelmemiş / tabansız)
    IF COALESCE(v_hayvan.kisir, false) THEN
      RAISE EXCEPTION 'OVSYNC_SECIM_KISIR';
    END IF;
    v_bugun := (now() AT TIME ZONE 'Europe/Istanbul')::date;
    v_kural := public._ovsync_kural_tarihi(v_hayvan_id);
    IF v_kural IS NULL THEN
      RAISE EXCEPTION 'OVSYNC_SECIM_TABAN_YOK';
    END IF;
    IF v_kural > v_bugun THEN
      RAISE EXCEPTION 'OVSYNC_SECIM_ERKEN:%',
        jsonb_build_object('kural_gun', v_kural, 'kalan_gun', v_kural - v_bugun)::text;
    END IF;

    IF v_takip_var THEN
      PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
    END IF;

    -- kural tarihli OVSYNC_BASLAT (Boş çekirdeğinin mevcut davranışıyla aynı
    --   çağrı; TAKIP'te atlanmıştı — DEGISMEZ 1)
    v_ovsync_id := public._acik_disi_gorev_kur(v_hayvan_id);

    RETURN jsonb_build_object(
      'ok', true, 'secim', 'OVSYNC', 'tohumlama_id', v_toh_id,
      'islem_id', v_islem_id, 'ovsync_gorev_id', v_ovsync_id,
      'takip_kapatildi', v_takip_var
    );
  END IF;

  -- ══ 13) PG modu (plan.md:328 + 331 birleşik kapı) ════════════════════════
  -- p_pg_urun/p_pg_doz zorunlu (sessiz varsayılan YOK — DEGISMEZ 5)
  IF p_pg_urun IS NULL THEN
    RAISE EXCEPTION 'PG_URUN_GEREKLI';
  END IF;
  IF p_pg_doz IS NULL THEN
    RAISE EXCEPTION 'PG_DOZ_GEREKLI';
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_pg_urun;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PG_STOK_YOK:%', jsonb_build_object('stok_id', p_pg_urun)::text;
  END IF;
  IF v_stok.birim IS NULL THEN
    -- uygulama_log.birim NOT NULL [20260603000002:17]; sarmal imzasında birim
    --   parametresi yok → birimsiz stok yazılamaz (fail-closed, sessiz varsayilan YOK)
    RAISE EXCEPTION 'PG_BIRIM_YOK:%', jsonb_build_object('stok_id', p_pg_urun)::text;
  END IF;

  -- TAKIP_ACIK (aynı koşul — OVSYNC dalıyla birebir)
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = v_hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND (p_muayene_gorev_id IS NULL OR g.id <> p_muayene_gorev_id)
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  v_takip_var := FOUND;

  -- PG kapısı — hayvan artık Boş (Boş ataması yukarıda); kapı kararı bu
  --   durumdan okunur. _pg_kapi hayvan satırını NKU kilitler [20260923000003:
  --   200-202] — sarmalın muteksine re-entrant.
  v_pg_kapi := public._pg_kapi(v_hayvan_id, p_pg_urun, NULL, COALESCE(p_onay, false));
  v_kupe := v_hayvan.kupe_no;

  IF v_takip_var AND NOT COALESCE(p_onay, false) THEN
    IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      -- birleşik kapı (#4/DEGISMEZ 3 — plan.md:331): önce PG_KAPI detayı,
      --   altına TAKIP_ACIK detayı; tek RAISE, tek p_onay.
      RAISE EXCEPTION 'PG_KAPI:TAKIP_ACIK:%',
        jsonb_build_object(
          'pg_kapi', public._pg_kapi_detay(v_pg_kapi, v_hayvan_id, v_kupe),
          'takip_acik', jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                                           'muayene_saat', v_takip.hedef_saat)
        )::text;
    END IF;
    RAISE EXCEPTION 'TAKIP_ACIK:%',
      jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                         'muayene_saat', v_takip.hedef_saat)::text;
  END IF;

  IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
    RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
      public._pg_kapi_detay(v_pg_kapi, v_hayvan_id, v_kupe)::text;
  END IF;

  IF v_takip_var THEN
    PERFORM public._takip_kapat(v_takip.id, 'PG');
  END IF;

  -- PG çekirdeği (hizli_uygulama — stok düşüm + islem_log + PG event + +48 s
  --   TAI [§18.6] içinde); p_pg_onay=true: sarmal kendi kapısını yukarıda
  --   geçti. Birim: stok kaleminin kayıtlı birimi (sarmal imzasında birim
  --   yok — stok.birim; rota 'IM' sabit — PG enjeksiyonu). notlar: uygulama_log.
  --   notlar NOT NULL [20260603000002:20] — p_notlar NULL ise boş string.
  v_hizli := public.hizli_uygulama(
    v_hayvan_id, p_pg_urun, p_pg_doz, v_stok.birim, 'IM', COALESCE(p_notlar, ''),
    true, COALESCE(p_notlar, ''), NULL);
  IF NOT COALESCE((v_hizli->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'PG_UYGULAMA_RED:%',
      jsonb_build_object('mesaj', v_hizli->>'mesaj')::text;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'secim', 'PG', 'tohumlama_id', v_toh_id, 'islem_id', v_islem_id,
    'uygulama_id', v_hizli->>'id', 'stok_kalan', v_hizli->>'stok_kalan',
    'takip_kapatildi', v_takip_var
  );
END;
$function$;

-- ACL (DEGISMEZ 8 — kalıp 20260926000003:106-107): anon/PUBLIC yok
REVOKE ALL ON FUNCTION public.tohumlama_bos_ve_devam(text, uuid, text, text, numeric, int, time, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tohumlama_bos_ve_devam(text, uuid, text, text, numeric, int, time, text, boolean) TO authenticated, service_role;

COMMENT ON FUNCTION public.tohumlama_bos_ve_devam(text, uuid, text, text, numeric, int, time, text, boolean) IS
  'P2b sarmal RPC (plan.md:288-297): Bos yolu (p_tohumlama_id) — Boş + OVSYNC/PG/TAKIP tek transaction; muayene yolu (p_muayene_gorev_id: GEBELIK_KONTROL|TAKIP_MUAYENE) — GEBE/OVSYNC/PG/TAKIP/ERTALE (TAKIP_MUAYENE''de TAKIP hariç). p_secim=NULL dry-run (yan etki yok). Kilit: hayvan NKU ILK → tohumlama FU → gorev_log FU (H3). Redler: GIRIS_CIFT_ANLAMLI, MUAYENE_GOREV_TIPI_UYUMSUZ, TOH_SONUCLU, TAKIP_KAPALI, TAKIP_YENIDEN_SECILEMEZ, SECIM_TANIMSIZ, OZELLIK_KAPALI, OVSYNC_SECIM_KISIR/ERKEN, PG_KAPI[:TAKIP_ACIK], TAKIP_ACIK, TAKIP_UZADI, BOS_DUZELTME_KOSUL (cekirdek).';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260929000002_takip_gorev_ve_bos_devam (P2a + P2b)
