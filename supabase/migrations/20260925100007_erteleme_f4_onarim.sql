-- ============================================================================
-- Migration: 20260925100007_erteleme_f4_onarim
-- Tarih: 2026-09-25 · Erteleme-genel turu F4 TEK ONARIM TURU (F3 onaylı
--   bulgular: A-1/B-1 ACL ORTA, C-2 seed ORTA, A-2/A-3/A-4 DÜŞÜK)
--
-- İçerik (tek transaction):
--   1. [A-1/B-1 ORTA] public.gorev_ertele_kural_get(text) ACL kapatma:
--      canlı proacl'de authenticated EXECUTE AÇIKTI (Supabase pg_default_acl
--      tuzağı — CREATE anında default privilege; 100004 yalnız PUBLIC/anon
--      revoke etmişti) [OBSERVED kırmızı probe: auth=true]. İç yardımcıdır
--      (yalnız gorev_ertele/gorev_ertele_kural_listele çağırır) → authenticated
--      EXECUTE kapanır. Serideki (100001-100006) diğer iç yardımcılar canlıdan
--      tarandı: _vaka_kapat auth=false, _pg_olay_isle auth=false → TEMİZ,
--      ek REVOKE gerekmez [OBSERVED]. postgres/service_role korunur.
--   2. [C-2 ORTA] gorev_ertele_kural seed tamamlama +3 satır: ASI_HATIRLATMA,
--      DOGUM_TAKIP, ILAC_UYGULAMA — hepsi ertelenebilir=t, pencere 'yok'
--      (S1 'kapalı önerilenler de AÇIK' + plan-db §3.1 notu; üçü de tekil
--      ertelemede teknik engeli olmayan görev tipleri). Seed 20 → 23 satır;
--      fail-closed kapsamı daralır, kural kaynağı 'tablo' olur.
--   3. [A-4 DÜŞÜK] protokol_iptal yeniden-başlat bacağı protocol_family='OVSYNC'
--      koşuluna bağlanır (canlı DEMO gövdesinden yeniden tanım — 000008 tuzağı;
--      gövde 100006 ile canlı birebir doğrulandı). Farklı aileden gelen
--      yeniden-başlat isteği HATA DEĞİL, not-la atlanır [kırmızı: PRESYNC vakada
--      yeni_gorev_id c1ff902f üretilmişti].
--   4. [A-2 DÜŞÜK] add_treatment_day_with_sessions gövdesindeki İKİ guardsız
--      aciklama::jsonb cast noktasına left(aciklama,1)='{' guardı (canlı
--      gövdeden yeniden tanım; mevcut DELETE guardı deseni — 100002:120-123):
--      (a) önceki-gün lookup JOIN'i, (b) UPDATE dalı TEDAVI_GUN WHERE'u.
--      [kırmızı: sentetik legacy JSON-dışı TEDAVI_GUN satırı update dalını
--      'invalid input syntax for type json' ile kırıyordu]
--   5. [A-3 DÜŞÜK] aynı fonksiyonun update dalı TEDAVI_GUN görevini koşulsuz
--      yeniden açar (tamamlandi=false) AMA gün satırını açmıyordu → görev/gün
--      tutarlılığı: update dalında treatment_days.tamamlandi=false +
--      tamamlanma_tarihi=NULL resetlenir (görev hedef_tarih = p_date zaten;
--      gün treatment_date = p_date → aynı gün).
--
-- Dokunulmazlar: tohumlama_gorev_ertele, hayvan_tohumlama_ertele,
--   _tohumlama_pencere, _vaka_kapat (100006 hali), gorev_ertele karar akışı,
--   add_treatment_day_with_sessions INSERT dalı/seans kurulum döngüsü/stok
--   hareketleri/audit/RETURN sözleşmesi — değişmez.
--
-- KAPSAM DIŞI keşif (kırıntı 2026-09-25, DONE sahip kapısına): demo canlıda
--   cases INSERT'i _guard_cases_kisir_ovsync INSERT dalında kırık
--   (cases.animal_id TEXT vs _kisir_ovsync_guard(uuid,boolean)) — bu turda
--   DOKUNULMAZ (kapı gündemi dışı kapsam genişletme yasağı).
--
-- Geri alınabilir: REVOKE'lar yeniden GRANT ile; seed 3 satır DELETE ile;
--   fonksiyonlar CREATE OR REPLACE (önceki gövde 100002/100006 dosyalarında).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) [A-1/B-1] İç yardımcı ACL kapatma ───────────────────────────────
REVOKE ALL ON FUNCTION public.gorev_ertele_kural_get(text) FROM PUBLIC, anon, authenticated;

-- ── 2) [C-2] Seed tamamlama: +3 satır (20 → 23) ────────────────────────
INSERT INTO public.gorev_ertele_kural
  (gorev_tipi, ertelenebilir, pencere_kurali, zincir_tetikler)
VALUES
  ('ASI_HATIRLATMA', true, 'yok', '{}'::jsonb),
  ('DOGUM_TAKIP',    true, 'yok', '{}'::jsonb),
  ('ILAC_UYGULAMA',  true, 'yok', '{}'::jsonb);

-- ── 3) [A-4] protokol_iptal: yeniden-başlat bacağı OVSYNC koşullu ──────
CREATE OR REPLACE FUNCTION public.protokol_iptal(p_vaka_id uuid, p_yeniden_baslat boolean DEFAULT false, p_not text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_case        public.cases%ROWTYPE;
  v_kapat       jsonb;
  v_iade        integer := 0;
  v_inst_kapali integer := 0;
  v_yeni_gorev  uuid;
  v_kural       date;
  v_taban       date;
  v_dogum       date;
  v_abort       date;
  v_yeniden_not text;
BEGIN
  -- 1) Vaka kilitle + doğrula: yalnız AKTİF PROTOROL vakası iptal edilir
  SELECT * INTO v_case FROM public.cases WHERE id = p_vaka_id FOR UPDATE;
  IF NOT FOUND OR v_case.status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'PROTOKOL_IPTAL_EDILEMEZ:%', jsonb_build_object(
      'case_id', p_vaka_id, 'sebep', 'VAKA_ACIK_DEGIL',
      'status', v_case.status);
  END IF;
  IF v_case.protocol_family IS NULL THEN
    RAISE EXCEPTION 'PROTOKOL_IPTAL_EDILEMEZ:%', jsonb_build_object(
      'case_id', p_vaka_id, 'sebep', 'PROTOKOL_VAKASI_DEGIL',
      'protocol_family', v_case.protocol_family);
  END IF;

  -- 2) Vaka kapanışı: kalan seans/görev/gün + stok iadesi + cases +
  --    CASE_CLOSED_BY_IPTAL audit (_vaka_kapat generic adımları — çift yazma yok)
  v_kapat := public._vaka_kapat(p_vaka_id, 'IPTAL', p_not,
                                jsonb_build_object('protokol_iptal', true));
  v_iade  := COALESCE((v_kapat->>'stok_iade')::int, 0);

  -- 3) Hayvan-seviyesi ILK_TOHUMLAMA instance kapanışı (E0 q6: vaka-bağlı
  --    instance satırı yok — instance hayvan seviyesinde yaşar)
  UPDATE public.protokol_instance
     SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'PROTOKOL_IPTAL'
   WHERE hayvan_id = v_case.animal_id
     AND alttip = 'ILK_TOHUMLAMA'
     AND durum = 'aktif';
  GET DIAGNOSTICS v_inst_kapali = ROW_COUNT;

  -- 4) Yeniden başlat: TEK yeni OVSYNC_BASLAT (kaynak_ref idempotensi:
  --    'PROTOKOL-IPTAL-<case_id>'; kısırlık/Aktif/Dişi + bayrak guard'ları
  --    _ovsync_baslat_gorev_kur çekirdeğinden — guard takılırsa sessiz NULL).
  --    [F4/A-4] Bacak protocol_family='OVSYNC' koşuluna bağlı: farklı aileden
  --    gelen yeniden-başlat isteği HATA DEĞİL, not-la atlanır — OVSYNC dışı
  --    aileden OVSYNC görevi türetilmez (kırmızı probe: PRESYNC vakada görev
  --    üretilmişti; yeşil: AILE_ATLANDI notu + yeni_gorev NULL).
  IF p_yeniden_baslat THEN
    IF v_case.protocol_family = 'OVSYNC' THEN
      v_kural := public._ovsync_kural_tarihi(v_case.animal_id);
      SELECT max(tarih) INTO v_dogum FROM public.dogum WHERE anne_id = v_case.animal_id;
      SELECT max(abort_tarihi) INTO v_abort FROM public.tohumlama
       WHERE hayvan_id = v_case.animal_id AND sonuc = 'Abort' AND abort_tarihi IS NOT NULL;
      IF v_dogum IS NOT NULL OR v_abort IS NOT NULL THEN
        v_taban := GREATEST(COALESCE(v_dogum, '-infinity'::date),
                            COALESCE(v_abort, '-infinity'::date));
      ELSE
        SELECT dogum_tarihi INTO v_taban FROM public.hayvanlar WHERE id = v_case.animal_id;
      END IF;
      IF v_kural IS NULL OR v_taban IS NULL THEN
        v_yeniden_not := 'TABANSIZ — kural/taban tarihi çözülemedi, görev açılmadı';
      ELSE
        v_yeni_gorev := public._ovsync_baslat_gorev_kur(
          v_case.animal_id, v_taban,
          'PROTOKOL-IPTAL-' || p_vaka_id::text, v_kural);
        IF v_yeni_gorev IS NULL THEN
          v_yeniden_not := 'GUARD — bayrak kapalı ya da hayvan uygun değil (kisir/Aktif değil/Dişi değil)';
        END IF;
      END IF;
    ELSE
      v_yeniden_not := 'AILE_ATLANDI — yeniden başlat yalnız OVSYNC ailesinde desteklenir (protocol_family='
                       || v_case.protocol_family || '); istek hata değil, sessiz atlandı';
    END IF;
  END IF;

  -- 5) RPC düzeyi audit (tohumlama_kaydet → _vaka_kapat iki-audit kalıbı)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('PROTOKOL_IPTAL', v_case.animal_id, p_vaka_id::text, 'cases',
          jsonb_build_object(
            'case_id',          p_vaka_id,
            'protocol_family',  v_case.protocol_family,
            'yeniden_baslat',   p_yeniden_baslat,
            'not',              p_not,
            'kapanan_seans',    v_kapat->'iptal_seans',
            'kapanan_gorev',    v_kapat->'iptal_gorev',
            'iade_stok_hareket', v_iade,
            'kapanan_instance', v_inst_kapali,
            'yeni_gorev_id',    v_yeni_gorev,
            'yeniden_not',      v_yeniden_not),
          jsonb_build_object(
            'olusturulan', CASE WHEN v_yeni_gorev IS NOT NULL
              THEN jsonb_build_array(jsonb_build_object('tablo', 'gorev_log', 'id', v_yeni_gorev::text, 'gorev_tipi', 'OVSYNC_BASLAT'))
              ELSE '[]'::jsonb END,
            'guncellenen', jsonb_build_array(
              jsonb_build_object('tablo', 'cases', 'id', p_vaka_id::text,
                                 'sonraki', jsonb_build_object('status', 'closed', 'close_reason', 'IPTAL')),
              jsonb_build_object('tablo', 'protokol_instance', 'adet', v_inst_kapali,
                                 'kosul', 'hayvan ILK_TOHUMLAMA aktif -> iptal')),
            'silinen', '[]'::jsonb));

  RETURN jsonb_build_object(
    'ok',            true,
    'case_id',       p_vaka_id,
    'kapanan_gorev', COALESCE((v_kapat->>'iptal_gorev')::int, 0),
    'kapanan_seans', COALESCE((v_kapat->>'iptal_seans')::int, 0),
    'kapanan_instance', v_inst_kapali,
    'iade',          v_iade,
    'yeni_gorev_id', v_yeni_gorev,
    'yeniden_not',   v_yeniden_not);
END;
$function$;

-- ── 4+5) [A-2/A-3] add_treatment_day_with_sessions: cast guardları + gün reset ──
CREATE OR REPLACE FUNCTION public.add_treatment_day_with_sessions(p_case_id uuid, p_date date, p_sessions jsonb DEFAULT NULL::jsonb, p_existing_day_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_day_id         uuid;
  v_gorev_id       uuid;
  v_prev_gorev_id  uuid := NULL;
  v_day_no         int;
  v_case           record;
  v_gecmis         boolean;
  v_session        jsonb;
  v_seans_sayisi   smallint;
  v_admin_ids      uuid[] := '{}';
  v_admin_id       uuid;
  v_first_time     time;
  v_is_update      boolean := false;
  v_drug_admin_id  uuid;
  v_stok_id        text;
  v_stok_hareket_id text;
BEGIN
  v_is_update := p_existing_day_id IS NOT NULL;

  IF v_is_update THEN
    SELECT day_no INTO v_day_no
    FROM public.treatment_days
    WHERE id = p_existing_day_id AND case_id = p_case_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Mevcut gun bulunamadi');
    END IF;
  ELSE
    SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
    FROM public.treatment_days WHERE case_id = p_case_id;
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadi');
  END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapali vakaya gun eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  IF v_day_no > 1 THEN
    -- [F4/A-2] Önceki-gün lookup JOIN'ine JSON guardı (DELETE guardı deseni):
    -- legacy JSON-dışı aciklama satırları cast'i kırıyordu.
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td
      ON left(g.aciklama, 1) = '{'
     AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id AND td.day_no = v_day_no - 1 AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  v_seans_sayisi := CASE WHEN p_sessions IS NULL THEN NULL ELSE jsonb_array_length(p_sessions)::smallint END;
  v_first_time   := CASE
    WHEN p_sessions IS NULL THEN NULL
    ELSE (p_sessions->0->>'planned_time')::time
  END;

  IF v_is_update THEN
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.treatment_day_id = p_existing_day_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;

    DELETE FROM public.drug_administrations WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.gorev_log
    WHERE gorev_tipi = 'TEDAVI_SEANS'
      AND left(aciklama, 1) = '{'
      AND (aciklama::jsonb->>'day_id')::uuid = p_existing_day_id;

    -- [F4/A-3] Görev/gün tutarlılığı: update dalı aşağıda TEDAVI_GUN görevini
    -- koşulsuz yeniden açar (tamamlandi=false) — gün satırı tamamlanmışsa o da
    -- açılır (tamamlanma damgası temizlenir). Zaten açıksa no-op.
    UPDATE public.treatment_days
    SET planned_time = v_first_time,
        seans_sayisi = v_seans_sayisi,
        treatment_date = p_date,
        tamamlandi = false,
        tamamlanma_tarihi = NULL
    WHERE id = p_existing_day_id
    RETURNING id INTO v_day_id;

    -- [F4/A-2] UPDATE dalı TEDAVI_GUN WHERE'una JSON guardı (DELETE guardı deseni).
    UPDATE public.gorev_log
    SET hedef_tarih = p_date,
        tamamlandi = false,
        tamamlanma_tarihi = NULL,
        aciklama = jsonb_build_object(
          'day_id', v_day_id, 'gun_no', v_day_no,
          'label', 'Gun ' || v_day_no || ' tedavisi - ' || to_char(p_date, 'DD.MM.YYYY'),
          'planned_time', COALESCE(v_first_time::text, ''),
          'seans_sayisi', v_seans_sayisi,
          'recete_guncellendi', true
        )::text
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND left(aciklama, 1) = '{'
      AND (aciklama::jsonb->>'day_id')::uuid = v_day_id
    RETURNING id INTO v_gorev_id;
  ELSE
    INSERT INTO public.treatment_days(
      id, case_id, day_no, treatment_date, tamamlandi,
      tamamlanma_tarihi, planned_time, seans_sayisi
    )
    VALUES (
      gen_random_uuid(), p_case_id, v_day_no, p_date,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_first_time, v_seans_sayisi
    )
    RETURNING id INTO v_day_id;
  END IF;

  IF NOT v_is_update THEN
    INSERT INTO public.gorev_log(
      id, gorev_tipi, hayvan_id, hedef_tarih, aciklama,
      tamamlandi, tamamlanma_tarihi, parent_id
    )
    VALUES (
      gen_random_uuid(), 'TEDAVI_GUN', v_case.animal_id, p_date,
      jsonb_build_object(
        'day_id', v_day_id, 'gun_no', v_day_no,
        'label', 'Gun ' || v_day_no || ' tedavisi - ' || to_char(p_date, 'DD.MM.YYYY'),
        'planned_time', COALESCE(v_first_time::text, ''),
        'seans_sayisi', v_seans_sayisi
      )::text,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_prev_gorev_id
    )
    RETURNING id INTO v_gorev_id;
  END IF;

  IF p_sessions IS NOT NULL THEN
    FOR v_session IN SELECT * FROM pg_catalog.jsonb_array_elements(p_sessions)
    LOOP
      INSERT INTO public.treatment_day_uygulamalar(
        treatment_day_id, case_id, planned_time, planned_date,
        stok_id, drug_product_id, dose, unit, route
      )
      VALUES (
        v_day_id, p_case_id,
        (v_session->>'planned_time')::time, p_date,
        v_session->>'stok_id',
        (v_session->>'drug_product_id')::uuid,
        (v_session->>'dose')::numeric,
        v_session->>'unit',
        v_session->>'route'
      )
      RETURNING id INTO v_admin_id;

      v_admin_ids := array_append(v_admin_ids, v_admin_id);

      INSERT INTO public.drug_administrations(
        treatment_day_id, stok_id, drug_product_id, dose, unit, route,
        seans_admin_id
      )
      VALUES (
        v_day_id,
        v_session->>'stok_id',
        (v_session->>'drug_product_id')::uuid,
        (v_session->>'dose')::numeric,
        v_session->>'unit',
        v_session->>'route',
        v_admin_id
      )
      RETURNING id INTO v_drug_admin_id;

      v_stok_id := v_session->>'stok_id';
      IF v_stok_id IS NOT NULL AND (v_session->>'dose')::numeric > 0 THEN
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
        VALUES (v_stok_id, 'Tedavi', (v_session->>'dose')::numeric,
                'drug_admin:' || v_drug_admin_id::text)
        RETURNING id INTO v_stok_hareket_id;
      END IF;

      INSERT INTO public.gorev_log(
        id, gorev_tipi, hayvan_id, hedef_tarih, hedef_saat,
        aciklama, tamamlandi, parent_id, seans_admin_id
      )
      VALUES (
        gen_random_uuid(), 'TEDAVI_SEANS', v_case.animal_id, p_date,
        (v_session->>'planned_time')::time,
        jsonb_build_object(
          'day_id', v_day_id,
          'planned_time', v_session->>'planned_time',
          'label', 'Gun ' || v_day_no || ' - Seans (' || (v_session->>'planned_time') || ')',
          'admin_id', v_admin_id
        )::text,
        false, v_gorev_id, v_admin_id
      );
    END LOOP;
  END IF;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    CASE WHEN v_is_update THEN 'RECETE_GUNCELLENDI' ELSE 'TEDAVI_GUN_EKLENDI' END,
    v_case.animal_id,
    v_day_id::text, 'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev_id::text)
      ) || COALESCE((
        SELECT jsonb_agg(jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', id::text))
        FROM pg_catalog.unnest(v_admin_ids) AS id
      ), '[]'::jsonb),
      'seans_sayisi', v_seans_sayisi,
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object(
    'ok', true, 'day_id', v_day_id, 'day_no', v_day_no,
    'seans_sayisi', v_seans_sayisi, 'admin_ids', v_admin_ids,
    'gorev_id', v_gorev_id, 'gecmis', v_gecmis
  );
END;
$function$;

-- ── Kapı kuralları ─────────────────────────────────────────────────────
-- protokol_iptal: UI RPC — PUBLIC/anon kapalı, authenticated açık (100006 hali).
REVOKE ALL ON FUNCTION public.protokol_iptal(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protokol_iptal(uuid, boolean, text) TO authenticated;
-- add_treatment_day_with_sessions: UI RPC sarmalı var — 100002 hali.
REVOKE ALL ON FUNCTION public.add_treatment_day_with_sessions(uuid, date, jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_treatment_day_with_sessions(uuid, date, jsonb, uuid) TO authenticated;

COMMIT;
