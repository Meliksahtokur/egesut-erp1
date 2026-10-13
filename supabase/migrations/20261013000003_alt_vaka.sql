-- ════════════════════════════════════════════════════════════════════
-- Ovsync paketi — Hastalık günü modeli (sahip kararı 10, 2026-10-13 öğleden sonra;
-- karar 4/6'nın "alt vaka" kısmı GEÇERSİZ): hastalık, Ovsync vakasının İÇİNDE bir
-- treatment_days satırıdır (`disease_id IS NOT NULL` olan gün); ayrı tablo YOK,
-- ayrı vaka AÇILMAZ. `cases.kaynak_vaka_id`, `inaktif_alt_vaka_ac/kapat`,
-- `_inaktif_alt_vaka_donus_hazirla` HİÇ DOĞMAZ (aşağıda IF EXISTS DROP'larla
-- mühürlü — eski 000003 artığı varsa düşer). İSTİSNA: `_kisir_zincir_bitir` +
-- tetiği alt-vaka nesnesi DEĞİL domain davranışıdır — mühür DIŞI, §4'te YAŞAR
-- (kök neden hükmü; gövde düşürülen `kaynak_vaka_id` kolundan arındırıldı).
--
-- Dal A (tek RPC): `ovsync_hastalik_gunu_ekle` — gün-aç + ilaçlar + TAI ertele
-- tek transaction; idempotency DB kısmi unique ile (ikinci çağrı mevcut günü
-- döner, ilaç tekrar yazılmaz, ertele tekrarlanmaz). İlaçlar
-- `add_drug_administration` üzerinden (PG sarmalı dahil); TAI yalnız
-- `tohumlama_gorev_ertele` ile ötelenir (iptal YOK). `treatment_day_tamamla` ve
-- `_pg_sonrasi_tohumlama` DEĞİŞMEZ (bu dosyada değinilmez).
-- Faz 0 OLCUM notu bu yaprağa ulaşmadı; plan Produces birincil adayı (tek RPC)
-- yazıldı — bileşim istenirse bu dosya daraltılır.
-- İç yardımcı: yalnız `_kisir_zincir_bitir` (tetik, §4); authenticated'a kapalı,
-- anon EXECUTE YOK. Yeni imzaya anon EXECUTE YOK.
-- Tarihler Istanbul günü: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- squawk hijyeni: yeniden tanım öncesinde timeout'lar (emsal 20261013000001:14-18)
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 0. Alt-vaka artığı mührü (IF EXISTS — prod zincirinde no-op) ──────────
-- Sıra: önce tetik düşer, sonra fonksiyonlar; kolon en son.
-- NOT: `trg_hayvan_kisir_zincir_bitir` + `_kisir_zincir_bitir()` mühür DIŞI
-- (domain davranışı, §4) — burada DROP EDİLMEZ.
DROP FUNCTION IF EXISTS public.inaktif_alt_vaka_kapat(uuid);
DROP FUNCTION IF EXISTS public._inaktif_alt_vaka_donus_hazirla(uuid);
DROP FUNCTION IF EXISTS public.inaktif_alt_vaka_ac(uuid, integer, uuid, text, numeric);
DROP FUNCTION IF EXISTS public.inaktif_alt_vaka_ac(uuid, integer, uuid, text, numeric, boolean);
ALTER TABLE public.cases DROP COLUMN IF EXISTS kaynak_vaka_id;

-- ── 1. Hastalık günü bağı: treatment_days.disease_id ─────────────────────
-- Kalıp: cases.disease_id (20260312000022_case_management.sql:58); FK hedefi
-- diseases; hastalık günü = disease_id IS NOT NULL; timeline/kart/S4 rozeti
-- bu kolondan okur.
ALTER TABLE public.treatment_days
  ADD COLUMN disease_id uuid NULL;
-- Öz-FK: diseases.id tekil olan gerçek şemalarda (canlı) kurulur;
-- constraint-free doğrulama aynasında hedef tekil olmadığı için atlanır
-- (emsal: eski 000003 cases_kaynak_vaka_id_fkey kalıbı). Kolon her yerde
-- eklenir; başvuru niyeti korunur, sessiz eksik-FK YOK (aşağıda NOTICE).
DO $do$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'treatment_days_disease_id_fkey') THEN
    IF EXISTS (SELECT 1 FROM pg_index i
                WHERE i.indrelid = 'public.diseases'::regclass AND i.indisunique
                  AND i.indkey::text = (SELECT a.attnum::text FROM pg_attribute a
                    WHERE a.attrelid = 'public.diseases'::regclass AND a.attname = 'id')) THEN
      ALTER TABLE public.treatment_days ADD CONSTRAINT treatment_days_disease_id_fkey
        FOREIGN KEY (disease_id) REFERENCES public.diseases(id);
    ELSE
      RAISE NOTICE 'OVSYNC-PAKETI: diseases.id tekil değil (constraint-free ayna) — treatment_days_disease_id_fkey atlandı';
    END IF;
  END IF;
END $do$;
CREATE UNIQUE INDEX treatment_days_hastalik_gun_uniq
  ON public.treatment_days(case_id, disease_id, treatment_date) WHERE disease_id IS NOT NULL;

-- ── 2. Public: ovsync_hastalik_gunu_ekle (tek RPC, Dal A) ─────────────────
-- Tek transaction: açık Ovsync vakasına hastalık günü aç + ilaçları güne yaz
-- + hayvanın açık TOHUMLAMA_PLANLI'larını p_gun kadar ötele (iptal yazılmaz).
-- Idempotent: aynı vaka+hastalık+tarih varsa mevcut günü döner
-- ({ok, gun_id, mevcut:true, ertelenen:0} — ilaç/ertele tekrarlanmaz).
-- Doğrulama hataları ok:false döner (istisna DEĞİL — api.js ok:false kolu);
-- PG kapısı blokları add_drug_administration içinden PG_KAPI:* istisnası
-- olarak YÜKSELİR (onay penceresi bu istisnayı bekler).
-- TEK imza: aşağıdaki 7-arg dışı overload varsa önce DROP edilir.
DROP FUNCTION IF EXISTS public.ovsync_hastalik_gunu_ekle(uuid, uuid, date, integer, jsonb, boolean, text);
CREATE FUNCTION public.ovsync_hastalik_gunu_ekle(p_case_id uuid, p_hastalik_id uuid DEFAULT NULL,
  p_tarih date DEFAULT NULL, p_gun integer DEFAULT 7, p_ilaclar jsonb DEFAULT '[]'::jsonb,
  p_pg_onay boolean DEFAULT NULL, p_pg_gerekce text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_case      record;
  v_kisir     boolean;
  v_hastalik  uuid;
  v_bugun     date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_tarih     date := COALESCE(p_tarih, (now() AT TIME ZONE 'Europe/Istanbul')::date);
  v_gun       integer := COALESCE(p_gun, 7);
  v_day_id    uuid;
  v_ilac      jsonb;
  v_yazilan   integer := 0;
  v_g         record;
  v_ertelenen integer := 0;
BEGIN
  IF v_gun < 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'GUN_NEGATIF');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OVSYNC_VAKA_BULUNAMADI');
  END IF;
  IF v_case.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'VAKA_KAPALI');
  END IF;
  -- NULL-aile açık kuralı (Review Focus): yalnız ADLI başka aile reddedilir.
  IF v_case.protocol_family IS NOT NULL AND v_case.protocol_family IS DISTINCT FROM 'OVSYNC' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ANA_ACIK_OVSYNC_DEGIL');
  END IF;
  SELECT COALESCE(kisir, false) INTO v_kisir FROM public.hayvanlar WHERE id = v_case.animal_id;
  IF COALESCE(v_kisir, false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'KISIR_HAYVANA_HASTALIK_GUNU_YOK');
  END IF;

  v_hastalik := p_hastalik_id;
  IF v_hastalik IS NULL THEN
    SELECT id INTO v_hastalik FROM public.diseases WHERE name = 'İnaktif Ovaryum' LIMIT 1;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'INAKTIF_HASTALIK_YOK');
    END IF;
  ELSIF NOT EXISTS (SELECT 1 FROM public.diseases WHERE id = v_hastalik) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'HASTALIK_BULUNAMADI');
  END IF;

  -- Idempotent gün-aç: vaka satır kilidi çift-tık yarışını seriler; yine de
  -- araya giren yazma unique'e takılırsa mevcut gün okunur (kayıp güncelleme yok).
  SELECT id INTO v_day_id FROM public.treatment_days
   WHERE case_id = p_case_id AND disease_id = v_hastalik AND treatment_date = v_tarih;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', true,
      'ertelenen', 0, 'ilac', 0);
  END IF;
  BEGIN
    -- id açık üretilir: constraint-free aynalarda kolon DEFAULT'u yoktur;
    -- gerçek şemalarda explicit değer default'u ezmesi zararsızdır.
    INSERT INTO public.treatment_days(id, case_id, treatment_date, disease_id)
      VALUES (gen_random_uuid(), p_case_id, v_tarih, v_hastalik) RETURNING id INTO v_day_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT id INTO v_day_id FROM public.treatment_days
     WHERE case_id = p_case_id AND disease_id = v_hastalik AND treatment_date = v_tarih;
    RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', true,
      'ertelenen', 0, 'ilac', 0);
  END;

  -- İlaçlar o günün altına (PG sarmalı add_drug_administration içindedir;
  -- PG_KAPI:* blokları istisna olarak yükselir, burada yutulmaz).
  FOR v_ilac IN SELECT * FROM jsonb_array_elements(COALESCE(p_ilaclar, '[]'::jsonb)) LOOP
    PERFORM public.add_drug_administration(v_day_id,
      (v_ilac->>'drug_product_id')::uuid, v_ilac->>'stok_id',
      (v_ilac->>'dose')::numeric, v_ilac->>'unit', v_ilac->>'route',
      p_pg_onay, p_pg_gerekce);
    v_yazilan := v_yazilan + 1;
  END LOOP;

  -- Açık TAI'leri ötele (iptal YOK; kaydır RPC çağrılmaz). §7.2: yalnız AKTİF
  -- TAI (iptal/tamamlanmış/kapatan_ref'li hariç).
  FOR v_g IN SELECT id, hedef_tarih, hedef_saat FROM public.gorev_log
              WHERE hayvan_id = v_case.animal_id AND gorev_tipi = 'TOHUMLAMA_PLANLI'
                AND NOT COALESCE(tamamlandi, false) AND NOT COALESCE(iptal, false)
                AND kapatan_ref IS NULL
              ORDER BY id
              FOR UPDATE LOOP
    PERFORM public.tohumlama_gorev_ertele(v_g.id, v_g.hedef_tarih + v_gun, v_g.hedef_saat);
    v_ertelenen := v_ertelenen + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', false,
    'ertelenen', v_ertelenen, 'ilac', v_yazilan);
END;
$function$;
REVOKE ALL ON FUNCTION public.ovsync_hastalik_gunu_ekle(uuid, uuid, date, integer, jsonb, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_hastalik_gunu_ekle(uuid, uuid, date, integer, jsonb, boolean, text) TO authenticated, service_role;

-- ── 4. Kısır zincir-bitirici: domain davranışı (mühür DIŞI) ────────────────
-- Kök neden hükmü: kısır-kapanış trigger'ı alt-vaka nesnesi DEĞİL, domain
-- davranışıdır — mühür kapsamı dışındadır, yeni modelde YAŞAR.
-- Gövde: HEAD 000003 §5'ten minimal uyarlama — düşürülen `kaynak_vaka_id`
-- kolu (OR EXISTS alt-vaka dalı) çıkarıldı; açık OVSYNC kapatma aynen.
-- hayvan_guncelle (18-arg, COALESCE) + hayvan_kisir_isaretle ikisi de yalın
-- UPDATE yapar → AFTER UPDATE OF kisir ateşlenir. §18.5 reddi
-- (trg_cases_kisir_ovsync) ayrı guard'dadır, burada değinilmez.
-- `treatment_day_tamamla` ve `_pg_sonrasi_tohumlama` DEĞİŞMEZ (değinilmez).
CREATE OR REPLACE FUNCTION public._kisir_zincir_bitir()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.cases alt
     SET status = 'closed', close_reason = 'ERKEN_KAPANIS'
   WHERE alt.animal_id = NEW.id
     AND alt.status = 'active'
     AND alt.protocol_family = 'OVSYNC';
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public._kisir_zincir_bitir() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_hayvan_kisir_zincir_bitir ON public.hayvanlar;
CREATE TRIGGER trg_hayvan_kisir_zincir_bitir AFTER UPDATE OF kisir ON public.hayvanlar
  FOR EACH ROW WHEN (NEW.kisir IS TRUE AND OLD.kisir IS DISTINCT FROM TRUE)
  EXECUTE FUNCTION public._kisir_zincir_bitir();

NOTIFY pgrst, 'reload schema';
COMMIT;
