-- ════════════════════════════════════════════════════════════════════
-- Ovsync paketi Faz 2a — İnaktif ovaryum/kist alt vaka modeli + kısır zincir-bitirici
-- (sahip kararları 2026-10-13, karar 4-7: ana Ovsync açık kalır, alt vaka yeni
-- cases satırı, açık TAI iptalsiz ötelenir, dönüş yalnız inaktif_alt_vaka_kapat,
-- kısır işareti açık ana+alt vakayı ERKEN_KAPANIS ile kapatır)
--
-- Gövde türetme: CANLI pg_get_functiondef (Mgmt API, yalnız SELECT, 2026-10-13 MEASURED):
--   tohumlama_gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time DEFAULT NULL)
--     — yerinde öteleme, iptal yazmaz; kapalı/iptal görevde GOREV_ERTELENEMEZ RAISE.
--   hayvan_guncelle 18-arg (sonda p_kisir boolean DEFAULT NULL) — SET
--     `kisir = COALESCE(p_kisir, kisir)`; kısır işaretleme yalnız UPDATE ile olur.
--   hayvan_kisir_isaretle(p_hayvan_id text, p_kisir boolean) — yalın
--     `UPDATE hayvanlar SET kisir = ...` + islem_log; iki yol da AFTER UPDATE OF kisir
--     tetiğini ateşler.
--   add_drug_administration Faz-1 imzası (uuid,uuid,text,numeric,text,text,boolean,text) —
--     vitamin (PG-dışı ürün) kapıya takılmaz, mevcut ilaç zincirinden yazılır.
-- Canlı diseases Üreme 12 kayıt (MEASURED): `İnaktif Ovaryum` 75a678be-… (karar 7),
--   kist için `Kistik Over` — aynı RPC, ayrı RPC yok (karar 6).
-- cases canlı kısıtları (MEASURED): status active/closed; close_reason
--   ERKEN_KAPANIS|TOHUMLAMA|PG|IPTAL; id/case default gen_random_uuid().
-- Eski migration dosyasına dokunulmadı. `tohumlama_bos_ve_devam`'a dal EKLENMEDİ (tek-yer).
-- İç yardımcılar (_ önekli) authenticated'a AÇILMADI; yeni imzalara anon EXECUTE YOK.
-- Tarihler Istanbul günü: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- squawk hijyeni: yeniden tanım öncesinde timeout'lar (emsal 20261013000001:14-18)
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. Alt vaka bağı: cases.kaynak_vaka_id ─────────────────────────────
ALTER TABLE public.cases
  ADD COLUMN IF NOT EXISTS kaynak_vaka_id uuid NULL;
-- Öz-FK: cases.id tekil olan gerçek şemalarda (canlı/parite) kurulur;
-- constraint-free doğrulama aynasında (Neon: PK/FK/CHECK yok — Global
-- Constraints :25 MEASURED) hedef tekil olmadığı için atlanır. Kolon her
-- yerde eklenir; başvuru niyeti korunur, sessiz eksik-FK YOK (aşağıda NOTICE).
DO $do$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'cases_kaynak_vaka_id_fkey') THEN
    IF EXISTS (SELECT 1 FROM pg_index i
                WHERE i.indrelid = 'public.cases'::regclass AND i.indisunique
                  AND i.indkey::text = (SELECT a.attnum::text FROM pg_attribute a
                    WHERE a.attrelid = 'public.cases'::regclass AND a.attname = 'id')) THEN
      ALTER TABLE public.cases ADD CONSTRAINT cases_kaynak_vaka_id_fkey
        FOREIGN KEY (kaynak_vaka_id) REFERENCES public.cases(id);
    ELSE
      RAISE NOTICE 'OVSYNC-PAKETI: cases.id tekil değil (constraint-free ayna) — cases_kaynak_vaka_id_fkey atlandı';
    END IF;
  END IF;
END $do$;

-- ── 2. İç yardımcı: alt vaka dönüşü (TEK dönüş tetikleyicisi) ────────────
-- UI'dan ASLA çağrılmaz: REVOKE FROM PUBLIC, anon, authenticated.
CREATE OR REPLACE FUNCTION public._inaktif_alt_vaka_donus_hazirla(p_alt_vaka_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_alt   record;
  v_kisir boolean;
BEGIN
  SELECT * INTO v_alt FROM public.cases WHERE id = p_alt_vaka_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ALT_VAKA_BULUNAMADI');
  END IF;
  IF v_alt.kaynak_vaka_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ALT_VAKA_DEGIL');
  END IF;
  IF v_alt.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ALT_ACIK_DEGIL');
  END IF;
  SELECT COALESCE(kisir, false) INTO v_kisir FROM public.hayvanlar WHERE id = v_alt.animal_id;
  IF COALESCE(v_kisir, false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'KISIR_HAYVAN_DONUS_YOK');
  END IF;

  UPDATE public.cases
     SET status = 'closed', close_reason = 'ERKEN_KAPANIS'
   WHERE id = p_alt_vaka_id;

  RETURN jsonb_build_object('ok', true, 'alt_vaka_id', p_alt_vaka_id,
    'ana_vaka_id', v_alt.kaynak_vaka_id);
END;
$function$;
REVOKE ALL ON FUNCTION public._inaktif_alt_vaka_donus_hazirla(uuid) FROM PUBLIC, anon, authenticated;

-- ── 3. Public: inaktif/kist alt vakası aç ────────────────────────────────
-- Tek transaction: ana active+OVSYNC değilse ok:false; alt cases satırı
-- (kaynak_vaka_id = ana, protocol_family NULL); vitamin VARSA ya da
-- p_gun_ac=true ise bugünün treatment_days satırı kurulur (ikisi de yoksa
-- gün satırı YOK — boş gün satırı kurulmaz, RULING 1'); vitamin kolu
-- add_drug_administration ile yazılır, gun_ac kolu BOŞ gün bırakır (ek
-- ilaçların hedefi — UI dönen gun_id'ye yazar); hayvanın her açık
-- TOHUMLAMA_PLANLI'sı tohumlama_gorev_ertele ile p_gun kadar ötelenir
-- (kaydır RPC çağrılmaz, iptal yazılmaz). Dönüş {ok, alt_vaka_id,
-- gun_id (gün yoksa null), ertelenen}.
-- RULING 1' öncesi 5-arg imza DROP edilir — TEK imza (ikinci overload yok).
DROP FUNCTION IF EXISTS public.inaktif_alt_vaka_ac(uuid, integer, uuid, text, numeric);
CREATE OR REPLACE FUNCTION public.inaktif_alt_vaka_ac(p_ana_vaka_id uuid, p_gun integer DEFAULT 7,
  p_hastalik_id uuid DEFAULT NULL, p_vitamin_stok_id text DEFAULT NULL, p_vitamin_doz_ml numeric DEFAULT 20,
  p_gun_ac boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ana       record;
  v_kisir     boolean;
  v_hastalik  uuid;
  v_bugun     date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_gun       integer := COALESCE(p_gun, 7);
  v_alt_id    uuid;
  v_urun      uuid;
  v_day_id    uuid;
  v_g         record;
  v_ertelenen integer := 0;
BEGIN
  SELECT * INTO v_ana FROM public.cases WHERE id = p_ana_vaka_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ANA_VAKA_BULUNAMADI');
  END IF;
  IF v_ana.status IS DISTINCT FROM 'active' OR v_ana.protocol_family IS DISTINCT FROM 'OVSYNC' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ANA_ACIK_OVSYNC_DEGIL');
  END IF;
  SELECT COALESCE(kisir, false) INTO v_kisir FROM public.hayvanlar WHERE id = v_ana.animal_id;
  IF COALESCE(v_kisir, false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'KISIR_HAYVANA_ALT_VAKA_YOK');
  END IF;

  v_hastalik := p_hastalik_id;
  IF v_hastalik IS NULL THEN
    SELECT id INTO v_hastalik FROM public.diseases WHERE name = 'İnaktif Ovaryum' LIMIT 1;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'INAKTIF_HASTALIK_YOK');
    END IF;
  END IF;

  -- F2 KAPI-2 madde 10: VITAMIN_STOK_YOK kontrolü cases INSERT'ten ÖNCE —
  -- stok yoksa alt vaka satırı oluşmaz (erken RETURN, yazma yok).
  IF p_vitamin_stok_id IS NOT NULL THEN
    SELECT drug_product_id INTO v_urun FROM public.stok WHERE id = p_vitamin_stok_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'VITAMIN_STOK_YOK');
    END IF;
  END IF;

  INSERT INTO public.cases(animal_id, disease_id, start_date, status, kaynak_vaka_id)
    VALUES (v_ana.animal_id, v_hastalik, v_bugun, 'active', p_ana_vaka_id)
    RETURNING id INTO v_alt_id;

  -- Madde 1 (RULING 1'): gün YALNIZ vitamin VARSA ya da p_gun_ac=true ise
  -- kurulur; vitamin kolu dolar, gun_ac kolu BOŞ gün bırakır.
  IF p_vitamin_stok_id IS NOT NULL OR COALESCE(p_gun_ac, false) THEN
    INSERT INTO public.treatment_days(case_id, treatment_date)
      VALUES (v_alt_id, v_bugun) RETURNING id INTO v_day_id;
    IF p_vitamin_stok_id IS NOT NULL THEN
      PERFORM public.add_drug_administration(v_day_id, v_urun, p_vitamin_stok_id,
        COALESCE(p_vitamin_doz_ml, 20), 'ml');
    END IF;
  END IF;

  FOR v_g IN SELECT id, hedef_tarih, hedef_saat FROM public.gorev_log
              WHERE hayvan_id = v_ana.animal_id AND gorev_tipi = 'TOHUMLAMA_PLANLI'
                AND NOT COALESCE(tamamlandi, false) AND NOT COALESCE(iptal, false)
              ORDER BY id
              FOR UPDATE LOOP
    PERFORM public.tohumlama_gorev_ertele(v_g.id, v_g.hedef_tarih + v_gun, v_g.hedef_saat);
    v_ertelenen := v_ertelenen + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'alt_vaka_id', v_alt_id, 'gun_id', v_day_id, 'ertelenen', v_ertelenen);
END;
$function$;
REVOKE ALL ON FUNCTION public.inaktif_alt_vaka_ac(uuid, integer, uuid, text, numeric, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inaktif_alt_vaka_ac(uuid, integer, uuid, text, numeric, boolean) TO authenticated, service_role;

-- ── 4. Public: alt vaka kapat (dönüş) ────────────────────────────────────
-- Ana active kalır, kaynak_vaka_id izi korunur.
CREATE OR REPLACE FUNCTION public.inaktif_alt_vaka_kapat(p_alt_vaka_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_r jsonb;
BEGIN
  SELECT public._inaktif_alt_vaka_donus_hazirla(p_alt_vaka_id) INTO v_r;
  RETURN v_r;
END;
$function$;
REVOKE ALL ON FUNCTION public.inaktif_alt_vaka_kapat(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inaktif_alt_vaka_kapat(uuid) TO authenticated, service_role;

-- ── 5. Kısır zincir-bitirici: tek tetik, iki RPC yolunu da yakalar ───────
-- hayvan_guncelle (18-arg, COALESCE) + hayvan_kisir_isaretle ikisi de yalın
-- UPDATE yapar → AFTER UPDATE OF kisir ateşlenir. Açık OVSYNC ana vakası +
-- kaynağı ona bağlı açık alt vakalar closed / ERKEN_KAPANIS (§18.5 aynen;
-- yeni OVSYNC trg_cases_kisir_ovsync ile reddedilir).
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
     AND (alt.protocol_family = 'OVSYNC'
          OR EXISTS (SELECT 1 FROM public.cases ana
                      WHERE ana.id = alt.kaynak_vaka_id
                        AND ana.animal_id = NEW.id
                        AND ana.protocol_family = 'OVSYNC'));
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
