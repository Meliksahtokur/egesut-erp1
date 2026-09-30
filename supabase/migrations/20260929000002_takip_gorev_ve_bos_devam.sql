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

-- EOF 20260929000002_takip_gorev_ve_bos_devam (P2a)
