-- Migration: Ovsync treni — aşama RPC'leri (K4/K5/K6) + K11 geç tamamlama (ovsync treni D6)
-- Tarih: 2026-11-09. Spec docs/plans/2026-11-09-ovsync-tren/design.md (K4, K5, K6, K11, §5, §7); PLAN.md D6, R3/R5/R6/R11/R12/R13/R18;
--   progress.md RL-1 (etiket yalnız vaka_kalan_gunleri_kaydir içinde artar), R6-EK, sözleşme eki 2026-11-09 (ovsync_uyari alanları).
--   Önceki migration: 20261110100005. BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısında.
-- Değişen 1 fonksiyon (imza aynı), gövdesi prod (kanit/fn) gövdesinden kopyalandı; yalnız "D6" yorumlu satırlar değişti:
--   seans_tamamla (R13: tren açık + aktif OVSYNC vaka seansında PG olay anı now(); PG1 tolerans aşımı → dönüşe ovsync_uyari).
-- Yeni RPC'ler (SECDEF, iç bayrak + advisory kilit ile başlar, tren kapalı → OVSYNC_TREN_KAPALI):
--   ovsync_hayvan_ertele(p_hayvan_id, p_gun), ovsync_pg48_tohumla(p_case_id), ovsync_bastan_baslat(p_case_id, p_bagimsiz, p_not, p_hedef).
-- Bayrak (ovsync_tren_aktif) 0 iken seans_tamamla davranışı eski ile birebir (LEAST korunur, ayar okunmaz, dönüş alanı eklenmez).
-- Önkoşul: seans_tamamla canlı gövdesinin md5'i D0 tabanı (govde-taban.md); değilse SEANS_TAMAMLA_GOVDE_FARKLI ile durur.
-- Tarih yalnız TR: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ROLLBACK: DROP FUNCTION public.ovsync_hayvan_ertele(text,integer), public.ovsync_pg48_tohumla(uuid),
--   public.ovsync_bastan_baslat(uuid,boolean,text,date); seans_tamamla'yı kanit/fn/seans_tamamla.sql gövdesiyle CREATE OR REPLACE et (ACL aynı).

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
BEGIN
  IF NOT COALESCE((SELECT md5(p.prosrc) FROM pg_catalog.pg_proc p
                    WHERE p.oid = to_regprocedure('public.seans_tamamla(uuid,boolean,text,boolean,text,boolean)'))
                  = '4afb2221a7e95235e754b7ff508d0379', false) THEN
    RAISE EXCEPTION 'SEANS_TAMAMLA_GOVDE_FARKLI: canlı gövde D0 tabanı değil (govde-taban.md: public.seans_tamamla(uuid,boolean,text,boolean,text,boolean)), D6 durdu';
  END IF;
END $$;

-- 1) seans_tamamla (imza aynı): K11/R13
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
  -- D6 (K11/R13): tren açık + aktif OVSYNC vaka seansı → olay anı gerçek tamamlama anı; PG1 geç → ovsync_uyari
  v_bugun      date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_tren_ovs   boolean := false;
  v_pg1        record;
  v_gecikme    integer;
  v_uyari      jsonb;
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
      -- D6 (K11/R13): tren açık ve seans aktif OVSYNC vakasının → olay anı now() (LEAST kalkar; T1 tuzağı). Diğer her durum eski.
      v_tren_ovs := public._ovsync_tren_aktif() AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id = v_seans.case_id
                      AND c.status = 'active' AND c.protocol_family = 'OVSYNC');
      v_occurred_at := CASE WHEN v_tren_ovs THEN now()
                            ELSE LEAST(now(), (v_seans.planned_date + v_seans.planned_time) AT TIME ZONE 'Europe/Istanbul') END;
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

  -- D6 (K11/R13): PG1 seansı (R6 gün#2) tamamlandı → gecikme = tamamlanma günü TR − (GnRH1 çapası + 7) (R18 çapası, birikimli).
  --   kayma = PG1 günü − (çapa + 7) olduğundan gecikme = bugün − PG1 günü + kayma. Aşama belirsizse (kayma NULL) uyarı yok.
  --   Tolerans aşılırsa dönüşe ovsync_uyari eklenir; işlem yine başarılıdır (karar kullanıcının, spec K11).
  IF v_tren_ovs THEN
    SELECT d.id, d.treatment_date INTO v_pg1 FROM public.treatment_days d
     WHERE d.case_id = v_seans.case_id AND d.disease_id IS NULL
     ORDER BY d.treatment_date, d.day_no OFFSET 1 LIMIT 1;
    IF v_pg1.id = v_seans.treatment_day_id THEN
      v_gecikme := v_bugun - v_pg1.treatment_date + public._ovsync_pg1_kayma(v_seans.case_id);
      IF v_gecikme > (public._ovsync_tren_ayar()->>'tolerans')::int THEN
        v_uyari := jsonb_build_object('kod', 'PG1_TOLERANS_ASILDI', 'gecikme_gun', v_gecikme, 'oneri', 'BASTAN_BASLAT',
                     'case_id', v_seans.case_id, 'kupe_no', (SELECT h.kupe_no FROM public.hayvanlar h WHERE h.id = v_pg_hayvan),
                     'planlanan_tarih', v_pg1.treatment_date, 'tamamlanan_tarih', v_bugun,
                     'bastan_tren_gunu', public._ovsync_tren_gunu(v_bugun));   -- sözleşme eki 2026-11-09
      END IF;
    END IF;
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

  RETURN jsonb_build_object('ok', true, 'seans_done', true, 'gun_tamam', v_all_done)
         || CASE WHEN v_uyari IS NOT NULL THEN jsonb_build_object('ovsync_uyari', v_uyari) ELSE '{}'::jsonb END;   -- D6
END;
$function$;

-- 2) ovsync_hayvan_ertele (K4/K5/K6, Ovsync ekranı tek hayvan): aşamaya göre erteleme. Vaka varsa vaka esastır; yoksa açık OVSYNC_BASLAT.
--    Etiket (ovsync_tren) yalnız vaka_kalan_gunleri_kaydir içinde artar (RL-1); burada ayrıca artırılmaz.
CREATE FUNCTION public.ovsync_hayvan_ertele(p_hayvan_id text, p_gun integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bugun  date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_ayar   jsonb;
  v_c      record;
  v_g      record;
  v_asama  smallint;
  v_d0     date;
  v_yeni   date;
  v_kayma  integer;
  v_er     jsonb;
BEGIN
  PERFORM public._ovsync_ic_ac();
  PERFORM pg_advisory_xact_lock(hashtext('ovsync_tren'));
  IF NOT public._ovsync_tren_aktif() THEN
    RAISE EXCEPTION 'OVSYNC_TREN_KAPALI:%', jsonb_build_object('rpc', 'ovsync_hayvan_ertele', 'hayvan_id', p_hayvan_id)::text;
  END IF;
  v_ayar := public._ovsync_tren_ayar();
  IF p_gun IS NULL OR p_gun < 1 OR p_gun > 7 THEN
    RAISE EXCEPTION 'OVSYNC_TREN_N_GECERSIZ:%', jsonb_build_object('gun', p_gun, 'min', 1, 'max', 7)::text;
  END IF;
  -- Kilit sırası seans_tamamla ile aynı (hayvan → vaka/seans → görev): aşama okunduktan sonra seans araya giremez.
  PERFORM 1 FROM public.hayvanlar h WHERE h.id = p_hayvan_id FOR NO KEY UPDATE;

  SELECT c.id, c.ovsync_tren INTO v_c FROM public.cases c
   WHERE c.animal_id = p_hayvan_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC'
   ORDER BY c.start_date DESC, c.created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    -- Aşama 0, vaka yok: açık OVSYNC_BASLAT → sonraki tren (öne çekme yok), gorev_ertele ile (GOREV_ERTELE soyu).
    SELECT g.id, g.hedef_tarih INTO v_g FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id AND g.gorev_tipi = 'OVSYNC_BASLAT'
       AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
     ORDER BY g.hedef_tarih, g.created_at LIMIT 1;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'OVSYNC_VAKA_YOK:%', jsonb_build_object('hayvan_id', p_hayvan_id)::text;
    END IF;
    v_yeni := public._ovsync_tren_gunu_ic(v_g.hedef_tarih + p_gun, (v_ayar->>'capa')::date, 0, v_bugun);
    v_er := public.gorev_ertele(v_g.id, v_yeni);
    RETURN jsonb_build_object('ok', true, 'asama', 0, 'sonuc', 'SONRAKI_TREN', 'yeni_tarih', (v_er->>'hedef_tarih')::date);
  END IF;

  v_asama := public._ovsync_asama(v_c.id);
  IF v_asama = 1 THEN
    v_kayma := public._ovsync_pg1_kayma(v_c.id);
  END IF;
  IF v_asama IS NULL OR (v_asama = 1 AND v_kayma IS NULL) THEN
    RAISE EXCEPTION 'OVSYNC_ASAMA_BELIRSIZ:%', jsonb_build_object('case_id', v_c.id, 'oneri', 'BASTAN_BASLAT')::text;
  ELSIF v_asama = 2 THEN
    RAISE EXCEPTION 'OVSYNC_ASAMA2_ERTELEME_YOK:%',
      jsonb_build_object('case_id', v_c.id, 'secenekler', jsonb_build_array('PG48', 'BASTAN'))::text;
  ELSIF v_asama = 1 AND v_kayma + p_gun > (v_ayar->>'tolerans')::int THEN
    -- K5/R18: tolerans hayvan başına birikimli (GnRH1 çapasından), çağrı başına değil
    RAISE EXCEPTION 'OVSYNC_ASAMA1_TOLERANS:%', jsonb_build_object('tolerans', (v_ayar->>'tolerans')::int, 'mevcut_kayma', v_kayma,
      'istenen', p_gun, 'oneri', 'BASTAN_BASLAT', 'case_id', v_c.id)::text;
  END IF;

  IF v_asama = 0 AND v_c.ovsync_tren IS NOT NULL THEN
    -- Aşama 0 trende: D0 (gün#1) sonraki trene; fark kadar kaydır (etiket += fark aynı işlemde, RL-1)
    SELECT d.treatment_date INTO v_d0 FROM public.treatment_days d
     WHERE d.case_id = v_c.id AND d.disease_id IS NULL ORDER BY d.treatment_date, d.day_no LIMIT 1;
    v_yeni := public._ovsync_tren_gunu_ic(v_d0 + p_gun, (v_ayar->>'capa')::date, 0, v_bugun);
    PERFORM public.vaka_kalan_gunleri_kaydir(v_c.id, v_yeni - v_d0);
  ELSE
    -- Aşama 0 bağımsız: serbest p_gun; aşama 1: tolerans içinde p_gun (trendeyse etiket += p_gun, RL-1)
    PERFORM public.vaka_kalan_gunleri_kaydir(v_c.id, p_gun);
  END IF;
  -- yeni_tarih: aşama 0 → gün#1 (GnRH1), aşama 1 → gün#2 (PG1) kaydırma sonrası tarihi
  SELECT d.treatment_date INTO v_yeni FROM public.treatment_days d
   WHERE d.case_id = v_c.id AND d.disease_id IS NULL ORDER BY d.treatment_date, d.day_no OFFSET v_asama LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'asama', v_asama,
    'sonuc', CASE WHEN v_asama = 0 AND v_c.ovsync_tren IS NOT NULL THEN 'SONRAKI_TREN' ELSE 'KAYDI' END,
    'yeni_tarih', v_yeni);
END;
$function$;

-- 3) ovsync_pg48_tohumla (K6a/R12): aşama 2 → PG1 + 48 s TAI'si kalır, kalan açık Ovsync seansları "uygulanmadı" (stok iadesi
--    seans_tamamla yolundan). TAI = hayvanın açık PG_TOHUMLAMA:* görevi (§18.6 son PG kazanır).
CREATE FUNCTION public.ovsync_pg48_tohumla(p_case_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_c      record;
  v_asama  smallint;
  v_tai    record;
  v_s      uuid;
  v_r      jsonb;
  v_n      integer := 0;
BEGIN
  PERFORM public._ovsync_ic_ac();
  PERFORM pg_advisory_xact_lock(hashtext('ovsync_tren'));
  IF NOT public._ovsync_tren_aktif() THEN
    RAISE EXCEPTION 'OVSYNC_TREN_KAPALI:%', jsonb_build_object('rpc', 'ovsync_pg48_tohumla', 'case_id', p_case_id)::text;
  END IF;
  -- Hayvan kilidi vaka durumu okunmadan önce (ovsync_hayvan_ertele sırası): kilitten sonra kapanmış vaka üzerinde devam edilmez.
  PERFORM 1 FROM public.hayvanlar h WHERE h.id = (SELECT c.animal_id FROM public.cases c WHERE c.id = p_case_id) FOR NO KEY UPDATE;
  SELECT c.id, c.animal_id INTO v_c FROM public.cases c
   WHERE c.id = p_case_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_YOK:%', jsonb_build_object('case_id', p_case_id)::text;
  END IF;

  v_asama := public._ovsync_asama(p_case_id);
  IF v_asama IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'OVSYNC_ASAMA2_DEGIL:%', jsonb_build_object('case_id', p_case_id, 'asama', v_asama)::text;
  END IF;
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_tai FROM public.gorev_log g
   WHERE g.hayvan_id = v_c.animal_id AND g.gorev_tipi = 'TOHUMLAMA_PLANLI' AND g.kaynak LIKE 'PG_TOHUMLAMA:%'
     AND NOT COALESCE(g.tamamlandi, false) AND NOT COALESCE(g.iptal, false)
   ORDER BY g.hedef_tarih DESC, g.hedef_saat DESC NULLS LAST, g.created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OVSYNC_PG48_TAI_YOK:%', jsonb_build_object('case_id', p_case_id, 'hayvan_id', v_c.animal_id)::text;
  END IF;
  -- Hedef anı TR yerel; saatsiz görev gün sonu sayılır (o gün hâlâ tohumlanabilir)
  IF (v_tai.hedef_tarih + COALESCE(v_tai.hedef_saat, time '23:59')) AT TIME ZONE 'Europe/Istanbul' < now() THEN
    RAISE EXCEPTION 'OVSYNC_PG48_GECMIS:%', jsonb_build_object('case_id', p_case_id, 'tai_gorev_id', v_tai.id,
      'tai_hedef', v_tai.hedef_tarih, 'tai_saat', v_tai.hedef_saat)::text;
  END IF;

  FOR v_s IN
    SELECT u.id FROM public.treatment_day_uygulamalar u JOIN public.treatment_days d ON d.id = u.treatment_day_id
     WHERE d.case_id = p_case_id AND d.disease_id IS NULL
       AND u.uygulama_tamamlandi_at IS NULL AND NOT COALESCE(u.uygulanmadi, false)
     ORDER BY d.treatment_date, d.day_no, u.planned_time
  LOOP
    v_r := public.seans_tamamla(p_seans_admin_id := v_s, p_uygulanmadi := true, p_not := 'OVSYNC_PG48');
    IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN   -- hayvan kilidi altında yarış beklenmez; yine de sessiz geçilmez
      RAISE EXCEPTION 'OVSYNC_PG48_SEANS_KAPANMADI:%', jsonb_build_object('case_id', p_case_id, 'seans_admin_id', v_s, 'sonuc', v_r)::text;
    END IF;
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'tai_gorev_id', v_tai.id, 'tai_hedef', v_tai.hedef_tarih, 'kapanan_seans', v_n);
END;
$function$;

-- 4) ovsync_bastan_baslat (K5/K6b, G9): protokol_iptal + yeniden başlat görevi (hedef tren günü, p_hemen); bağımsız ya da hedef = bugün
--    → aynı işlemde start_first_service_protocol (T4 cron tuzağı içeride çözülür). Aşama kısıtı yok. Görev ya da vaka çıkmazsa
--    hepsi geri sarılır (fail-closed; vaka sessizce kapanıp Ovsync'siz kalmaz).
--    D7 tur 2 (RL-15): p_hedef (toptan erteleme) verilirse yeni görev bu tren gününe yeniden hedeflenir (gorev_ertele); p_hedef
--    kendi hedefinden erken, tren günü değil ya da bağımsızla birlikte → OVSYNC_BASTAN_HEDEF_GECERSIZ. Bugün değilse başlatma yok.
CREATE FUNCTION public.ovsync_bastan_baslat(p_case_id uuid, p_bagimsiz boolean DEFAULT false, p_not text DEFAULT NULL,
                                            p_hedef date DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bugun   date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_c       record;
  v_ip      jsonb;
  v_gid     uuid;
  v_hedef   date;
  v_st      jsonb;
  v_yeni    uuid;
  v_tai     uuid[] := '{}'::uuid[];   -- D7 (D6 review KÜÇÜK): iptal edilen PG TAI id'leri
BEGIN
  PERFORM public._ovsync_ic_ac();
  PERFORM pg_advisory_xact_lock(hashtext('ovsync_tren'));
  IF NOT public._ovsync_tren_aktif() THEN
    RAISE EXCEPTION 'OVSYNC_TREN_KAPALI:%', jsonb_build_object('rpc', 'ovsync_bastan_baslat', 'case_id', p_case_id)::text;
  END IF;
  -- Hayvan kilidi vaka durumu okunmadan önce (ovsync_hayvan_ertele sırası): kilitten sonra kapanmış vaka üzerinde devam edilmez.
  PERFORM 1 FROM public.hayvanlar h WHERE h.id = (SELECT c.animal_id FROM public.cases c WHERE c.id = p_case_id) FOR NO KEY UPDATE;
  SELECT c.id, c.animal_id INTO v_c FROM public.cases c
   WHERE c.id = p_case_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_YOK:%', jsonb_build_object('case_id', p_case_id)::text;
  END IF;

  v_ip := public.protokol_iptal(p_case_id, true, p_not);
  v_gid := (v_ip->>'yeni_gorev_id')::uuid;
  IF v_gid IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_BASTAN_BASLATILAMADI:%', jsonb_build_object('case_id', p_case_id, 'yeniden_not', v_ip->>'yeniden_not')::text;
  END IF;
  SELECT g.hedef_tarih INTO v_hedef FROM public.gorev_log g WHERE g.id = v_gid;
  IF p_hedef IS NOT NULL THEN   -- D7 tur 2 (RL-15)
    IF COALESCE(p_bagimsiz, false) OR p_hedef < v_hedef OR NOT public._ovsync_tren_gunu_mu(p_hedef) THEN
      RAISE EXCEPTION 'OVSYNC_BASTAN_HEDEF_GECERSIZ:%', jsonb_build_object('case_id', p_case_id, 'hedef', p_hedef,
        'en_erken', v_hedef, 'bagimsiz', COALESCE(p_bagimsiz, false))::text;
    END IF;
    IF p_hedef > v_hedef THEN
      PERFORM public.gorev_ertele(v_gid, p_hedef);
      SELECT g.hedef_tarih INTO v_hedef FROM public.gorev_log g WHERE g.id = v_gid;
    END IF;
  END IF;

  IF COALESCE(p_bagimsiz, false) OR v_hedef = v_bugun THEN
    v_st := public.start_first_service_protocol(v_gid, false, COALESCE(p_bagimsiz, false));
    v_yeni := (v_st->>'case_id')::uuid;
    v_tai := COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_st->'pg_gorev_iptal')::uuid), '{}'::uuid[]);   -- D7
    IF v_yeni IS NULL THEN   -- muafiyet / yeniden hedef: istenen başlatma olmadı → geri sar
      RAISE EXCEPTION 'OVSYNC_BASTAN_BASLATILAMADI:%', jsonb_build_object('case_id', p_case_id, 'yeni_gorev_id', v_gid,
        'yeniden_not', 'BASLATMA_OLMADI', 'sonuc', v_st)::text;
    END IF;
  ELSE
    -- RL-12 (K6 a/b dışlayıcı): başlamayan dalda da açık PG+48 TAI kalmaz; start_first_service_protocol'ün yolu/işareti
    -- (iptal + tamamlandi, ILK_TOH_PROTOKOL_YERINE). Henüz vaka yok → ref = yerine geçen OVSYNC_BASLAT görevi.
    --    D7: iptal edilen id'ler dönüşe ve islem_log'a (start yolunun pg_gorev_iptal kalıbı; islem_log değişmez → yeni satır).
    WITH u AS (
      UPDATE public.gorev_log
         SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_PROTOKOL_YERINE:' || v_gid::text
       WHERE hayvan_id = v_c.animal_id AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND kaynak LIKE 'PG_TOHUMLAMA:%'
         AND COALESCE(tamamlandi, false) = false AND COALESCE(iptal, false) = false
      RETURNING id
    )
    SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_tai FROM u;
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('OVSYNC_BASTAN_BEKLIYOR', v_c.animal_id, v_gid::text, 'gorev_log',
            jsonb_build_object('case_id', p_case_id, 'yeni_gorev_id', v_gid, 'hedef_tarih', v_hedef, 'iptal_tai', to_jsonb(v_tai)),
            '{}'::jsonb);
  END IF;

  RETURN jsonb_build_object('ok', true, 'kapanan_case_id', p_case_id, 'yeni_gorev_id', v_gid, 'hedef_tarih', v_hedef,
                            'basladi', v_yeni IS NOT NULL, 'yeni_case_id', v_yeni, 'iptal_tai', to_jsonb(v_tai));   -- D7
END;
$function$;

-- ACL (Supabase varsayılan yetkisi anon'a EXECUTE verir). Yeni RPC'ler ve CREATE OR REPLACE edilen seans_tamamla canlıdaki gibi
-- authenticated + service_role.
REVOKE ALL ON FUNCTION public.seans_tamamla(uuid, boolean, text, boolean, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.seans_tamamla(uuid, boolean, text, boolean, text, boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_hayvan_ertele(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_hayvan_ertele(text, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_pg48_tohumla(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_pg48_tohumla(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_bastan_baslat(uuid, boolean, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_bastan_baslat(uuid, boolean, text, date) TO authenticated, service_role;
