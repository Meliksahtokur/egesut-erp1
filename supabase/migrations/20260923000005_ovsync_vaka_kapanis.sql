-- ============================================================================
-- Migration: 20260923000005_ovsync_vaka_kapanis
-- Tarih: 2026-09-23
-- Otorite: docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md (R3) §0 MK5, S-3, S-7,
--   R3.1 (MK8 temizlik bayraktan bağımsız, MK9 kilit sırası, #12 tedavi_sablon_uygula
--   protocol_family geç-doldurma) — bağlayıcı.
-- Kanonik taban: canlı prod pg_get_functiondef (2026-09-23) — close_case_with_remaining,
--   tedavi_sablon_uygula, tohumlama_kaydet, planli_tohumlama_kaydet. Migration
--   geçmişi/ground_truth taban DEĞİLDİR.
-- Bağımlılık: 20260923000002 (cases.source_template_id / protocol_family /
--   protocol_snapshot / close_reason, tedavi_sablonu.protokol_ailesi,
--   _ovsync_pg_aktif()).
--
-- NE YAPAR:
--   S-7  _vaka_kapat(uuid, text, text, jsonb) — YENİ iç fonksiyon. Canlı
--        close_case_with_remaining gövdesinin tamamı buraya taşındı; iki dal:
--          ERKEN_KAPANIS → canlı yan etkiler birebir (iptal_nedeni metni,
--                          CASE_CLOSED_EARLY snapshot'ı) + cases.close_reason.
--          TOHUMLAMA     → iptal_nedeni 'Tohumlama ile sonlandırıldı'; tek audit
--                          CASE_CLOSED_BY_TOHUMLAMA (CASE_CLOSED_EARLY YAZILMAZ);
--                          vaka zaten kapalı/yok → hiçbir yazma, {zaten_kapali:true}.
--          T21: ERKEN_KAPANIS ile close_reason='TOHUMLAMA' olan kapalı vakaya
--          çağrılırsa da no-op (audit ezilmez) — bkz. close_case_with_remaining.
--   S-7  close_case_with_remaining(uuid, text) — imza/dönüş/yan etki aynı;
--        _vaka_kapat(…,'ERKEN_KAPANIS',…) sarmalayıcısı.
--   S-7  tohumlama_kaydet — canlı gövde + MK9 kilit (aşağıda) +
--        (yalnız bayrak AÇIKKEN) protokol vakalarının kapanış döngüsü ve dönüşe
--        additive 'kapatilan_senkronizasyon_vakalari'. Bayrak kapalı → anahtar
--        yok, kapanış döngüsü çalışmaz.
--        MK9: bayrak açıkken fonksiyonun EN BAŞINDA, ilk tablo erişiminden önce
--        hayvan `FOR NO KEY UPDATE` kilitlenir (kilit sırası: hayvan → vaka/
--        seans → görev). Bayrak kapalıyken bu satır YOK (MK5).
--        MK8 (R3.1): açık OVSYNC_BASLAT görevi ve ILK_TOHUMLAMA instance'ının
--        iptali artık BAYRAKTAN BAĞIMSIZ çalışır (yalnız yeni iş yaratan vaka
--        kapanış döngüsü bayrak arkasında kalır). Bayrak hiç açılmadıysa S-8
--        hiç OVSYNC_BASLAT/ILK_TOHUMLAMA üretmediği için 0 satır etkiler, MK5
--        bit-bit korunur.
--   S-3  tedavi_sablon_uygula — canlı gövde + provenance damgası
--        (cases.source_template_id IS NULL ise). Bayraktan bağımsız; dönüş aynı.
--        R3.1 (#12): source_template_id ZATEN doluysa (ikinci+ uygulama)
--        provenance/snapshot ezilmez (değişmedi); YENİ — protocol_family hâlâ
--        NULL ve bu şablonun ailesi doluysa, protocol_family AYRI bir UPDATE
--        ile geç doldurulur (source_template_id/snapshot bu dalda dokunulmaz).
--   planli_tohumlama_kaydet DEĞİŞMEDİ: canlı gövde `v_result || {gorev_id}`
--        döndürür → 'kapatilan_senkronizasyon_vakalari' olduğu gibi geçer (T04).
--
-- MK5 (bayrak kapalı): tohumlama_kaydet bit bit eski davranış — MK9 kilit satırı
--   ve S-7 kapanış döngüsü/additive anahtar yok. Bayraktan bağımsız yalnız: S-3
--   metadata damgası (+ #12 geç-doldurma), close_reason kolonu, MK8 temizliği
--   (0 satır etkiler çünkü flag hiç açılmadıysa hedef satırlar hiç oluşmaz).
--
-- search_path: dört fonksiyon da canlıda proconfig=NULL idi; hepsine
--   `SET search_path = public, pg_temp` eklendi (gövdeler zaten public. nitelikli).
-- ACL: canlı proacl = {postgres, authenticated, service_role}; CREATE OR REPLACE
--   korur. REVOKE/GRANT canlıda no-op, taze ortamda aynı ACL'i kurar. _vaka_kapat
--   iç yardımcıdır: postgres default ACL yeni fonksiyona authenticated=X verdiği
--   için authenticated'dan açıkça REVOKE edilir.
-- İç transaction deyimi YOK.
--
-- ROLLBACK (elle): canlı close_case_with_remaining / tohumlama_kaydet /
--   tedavi_sablon_uygula gövdelerini (2026-09-23 pg_get_functiondef) yeniden
--   CREATE OR REPLACE et; DROP FUNCTION public._vaka_kapat(uuid, text, text, jsonb);
--   NOTIFY pgrst, 'reload schema'. Yazılmış provenance/close_reason verisi kalır
--   (kolonlar 000002'nin; zararsız metadata).
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════════
-- S-7  _vaka_kapat — vaka kapanış çekirdeği (iç)
-- ════════════════════════════════════════════════════════════════════════════
-- Canlı close_case_with_remaining adımları sırası ve WHERE koşulları DEĞİŞMEDEN
-- korunur; yalnız (a) iptal_nedeni metni dala göre, (b) cases UPDATE'ine
-- close_reason, (c) audit dala göre, (d) sayaçlar (GET DIAGNOSTICS, yazma değil).
-- Gerçekleşmiş seanslar (uygulama_tamamlandi_at NOT NULL) ve tamamlanmış günler
-- hiçbir adımda seçilmez → stokları dokunulmaz; yalnız açık olanların
-- 'drug_admin:<id>' stok hareketi iade (iptal) edilir.
CREATE OR REPLACE FUNCTION public._vaka_kapat(p_case_id uuid, p_close_reason text, p_not text, p_ref jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_remaining_count int;
  v_case            record;
  v_iptal_nedeni    text;
  v_n               int;
  v_stok_iade       int := 0;
  v_iptal_gorev     int := 0;
  v_gerceklesen     int;
  v_closed_at       timestamptz;
BEGIN
  IF p_close_reason IS NULL OR p_close_reason NOT IN ('ERKEN_KAPANIS', 'TOHUMLAMA') THEN
    RAISE EXCEPTION '_vaka_kapat: geçersiz close_reason: %', p_close_reason;
  END IF;

  -- Kilit (yazma değil). Kilit sırası (MK9): vaka (burada) → seans/stok/gün
  -- (aşağıdaki UPDATE'ler) → görev (adım 5/5b) → vaka satırının kendisi (zaten
  -- kilitli). ERKEN_KAPANIS canlıdaki gibi durumdan bağımsız ilerler — TEK
  -- istisna: tohumlama ile kapanmış vaka (R3.1, T21) → no-op. TOHUMLAMA zaten
  -- kapalı/olmayan vakada hiçbir şey yazmaz.
  SELECT id, animal_id, status, close_reason INTO v_case
    FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF p_close_reason = 'TOHUMLAMA' AND (NOT FOUND OR v_case.status IS DISTINCT FROM 'active') THEN
    RETURN jsonb_build_object('case_id', p_case_id, 'zaten_kapali', true);
  END IF;
  IF p_close_reason = 'ERKEN_KAPANIS' AND FOUND
     AND v_case.status = 'closed' AND v_case.close_reason = 'TOHUMLAMA' THEN
    -- Yazma yok, audit yok: tek audit CASE_CLOSED_BY_TOHUMLAMA kalır, iptal_nedeni
    -- 'Tohumlama ile sonlandırıldı' ezilmez. Diğer kapalı vakalar canlıdaki gibi
    -- yeniden yazılır (MK5).
    RETURN jsonb_build_object('case_id', p_case_id, 'zaten_kapali', true,
      'iptal_seans', 0, 'iptal_gorev', 0, 'gerceklesen_seans', NULL, 'stok_iade', 0);
  END IF;

  v_iptal_nedeni := CASE p_close_reason
    WHEN 'ERKEN_KAPANIS' THEN 'Vaka erken kapatildi' || COALESCE(': ' || p_not, '')
    ELSE 'Tohumlama ile sonlandırıldı'
  END;

  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_day_uygulamalar tdu
    ON tdu.id = da.seans_admin_id
  WHERE tdu.case_id = p_case_id
    AND tdu.uygulanmadi = false
    AND tdu.uygulama_tamamlandi_at IS NULL
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_stok_iade := v_stok_iade + v_n;

  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false
    AND (da.uygulanmadi IS NULL OR da.uygulanmadi = false)
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_stok_iade := v_stok_iade + v_n;

  UPDATE public.treatment_day_uygulamalar
  SET uygulanmadi = true,
      iptal_nedeni = v_iptal_nedeni,
      updated_at = now()
  WHERE case_id = p_case_id
    AND uygulanmadi = false
    AND uygulama_tamamlandi_at IS NULL;

  GET DIAGNOSTICS v_remaining_count = ROW_COUNT;

  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_day_uygulamalar tdu
  WHERE tdu.id = da.seans_admin_id
    AND tdu.case_id = p_case_id
    AND tdu.uygulanmadi = true
    AND da.uygulanmadi IS DISTINCT FROM true;

  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_days td
  WHERE td.id = da.treatment_day_id
    AND td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false
    AND da.uygulanmadi IS DISTINCT FROM true;

  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE case_id = p_case_id AND tamamlandi = false;

  -- 5. gorev_log kalan acik gorevler — gorev_tipi guard (JSON-olmayan aciklama'lari cast'ten ele)
  UPDATE public.gorev_log g
  SET tamamlandi = true, tamamlanma_tarihi = now()
  FROM public.treatment_days td
  WHERE td.case_id = p_case_id
    AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
    AND (CASE WHEN g.aciklama IS JSON OBJECT
              THEN (g.aciklama::jsonb->>'day_id') END)::uuid = td.id
    AND g.tamamlandi = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_iptal_gorev := v_iptal_gorev + v_n;

  -- 5b. Planlı tohumlama gorevi bagimsiz (parent_id/day_id yok) — adim 5'in
  -- treatment_days JOIN'i onu GOREMEZ. Vaka kapaninca acikta kalmasin.
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now()
  WHERE gorev_tipi = 'TOHUMLAMA_PLANLI'
    AND kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':%'
    AND tamamlandi = false AND iptal = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_iptal_gorev := v_iptal_gorev + v_n;

  UPDATE public.cases
  SET status = 'closed', closed_at = now(), close_reason = p_close_reason
  WHERE id = p_case_id;

  SELECT count(*) INTO v_gerceklesen
    FROM public.treatment_day_uygulamalar
   WHERE case_id = p_case_id AND uygulama_tamamlandi_at IS NOT NULL;

  IF p_close_reason = 'ERKEN_KAPANIS' THEN
    INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (
      gen_random_uuid()::text, 'CASE_CLOSED_EARLY',
      (SELECT animal_id FROM public.cases WHERE id = p_case_id),
      p_case_id::text, 'cases',
      jsonb_build_object(
        'iptal_edilen_seans', v_remaining_count,
        'stok_iade_edildi', v_remaining_count > 0,
        'not', p_not
      )
    );
  ELSE
    v_closed_at := now();
    INSERT INTO public.islem_log(tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES (
      'CASE_CLOSED_BY_TOHUMLAMA', v_case.animal_id,
      p_case_id::text, 'cases',
      jsonb_build_object(
        'case_id',           p_case_id,
        'tohumlama_id',      p_ref->>'tohumlama_id',
        'close_reason',      p_close_reason,
        'iptal_seans',       v_remaining_count,
        'iptal_gorev',       v_iptal_gorev,
        'gerceklesen_seans', v_gerceklesen,
        'closed_at',         v_closed_at
      ),
      '{}'::jsonb
    );
  END IF;

  RETURN jsonb_build_object(
    'case_id',           p_case_id,
    'iptal_seans',       v_remaining_count,
    'iptal_gorev',       v_iptal_gorev,
    'gerceklesen_seans', v_gerceklesen,
    'stok_iade',         v_stok_iade
  );
END;
$function$;

COMMENT ON FUNCTION public._vaka_kapat(uuid, text, text, jsonb) IS
  'S-7: vaka kapanış çekirdeği (iç). ERKEN_KAPANIS = canlı close_case_with_remaining '
  'davranışı + close_reason; TOHUMLAMA = ''Tohumlama ile sonlandırıldı'' + '
  'CASE_CLOSED_BY_TOHUMLAMA, zaten kapalı vakada yazma yok. Dönüş: '
  '{case_id, iptal_seans, iptal_gorev, gerceklesen_seans, stok_iade(iade edilen stok_hareket sayısı)}.';

REVOKE ALL ON FUNCTION public._vaka_kapat(uuid, text, text, jsonb) FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- S-7  close_case_with_remaining — sarmalayıcı (imza + dönüş canlıyla aynı)
-- ════════════════════════════════════════════════════════════════════════════
-- Canlı dönüş: {ok:true, iptal_edilen_seans:<tdu iptal sayısı>}.
-- R3.1: close_reason='TOHUMLAMA' ile kapanmış vaka → no-op,
--   {ok:true, iptal_edilen_seans:0, zaten_kapali:true} (additive anahtar yalnız bu dalda).
CREATE OR REPLACE FUNCTION public.close_case_with_remaining(p_case_id uuid, p_not text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_r jsonb;
BEGIN
  v_r := public._vaka_kapat(p_case_id, 'ERKEN_KAPANIS', p_not, '{}'::jsonb);
  RETURN jsonb_build_object('ok', true, 'iptal_edilen_seans', (v_r->>'iptal_seans')::int)
      || CASE WHEN COALESCE((v_r->>'zaten_kapali')::boolean, false)
              THEN jsonb_build_object('zaten_kapali', true)
              ELSE '{}'::jsonb
         END;
END;
$function$;

REVOKE ALL ON FUNCTION public.close_case_with_remaining(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_case_with_remaining(uuid, text) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- S-7  tohumlama_kaydet — canlı gövde + bayrak arkası vaka kapanışı
-- ════════════════════════════════════════════════════════════════════════════
-- Canlı satırlar yeniden yazılmadı. Ekler: search_path; 4 DECLARE değişkeni;
-- RETURN'den önce IF _ovsync_pg_aktif() bloğu; RETURN ifadesine additive
-- `|| CASE … END` (bayrak kapalı → '{}' → dönüş canlıyla bit bit aynı).
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_hayvan         record;
  v_yas_gun        integer;
  v_deneme         integer;
  v_toh_id         uuid := gen_random_uuid();
  v_ek             jsonb;
  v_ek_stok        uuid;
  v_son_dogum      date;
  v_son_abort      date;
  v_anchor_tip     text;
  v_anchor_date    date;
  v_vwp_gun        integer;
  v_inst_id        uuid;
  v_kaynak         text;
  v_eski_tohumlama record;
  v_iptal_gorev    integer := 0;
  v_iptal_inst     integer := 0;
  v_islem_id       text    := gen_random_uuid()::text;
  v_snapshot       jsonb;
  -- S-7 (bayrak arkası)
  v_ovsync_aktif   boolean := false;
  v_vaka           record;
  v_kapat          jsonb;
  v_kapatilan      jsonb   := '[]'::jsonb;
BEGIN
  -- MK9 (bayrak açıkken): kilit sırası hayvan → vaka/seans → görev. Bu
  -- fonksiyon hayvanı ilk olarak kilitler; ilk tablo erişiminden önce, tek
  -- satır. Bayrak kapalıyken bu satır YOK (MK5: eski davranış bit bit).
  IF public._ovsync_pg_aktif() THEN
    PERFORM 1 FROM public.hayvanlar WHERE id = p_hayvan_id FOR NO KEY UPDATE;
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar
    WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.cinsiyet = 'Erkek' THEN RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz'; END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  SELECT MAX(d.tarih) INTO v_son_dogum FROM public.dogum d WHERE d.anne_id = p_hayvan_id;
  SELECT MAX(t.abort_tarihi) INTO v_son_abort FROM public.tohumlama t
    WHERE t.hayvan_id = p_hayvan_id AND t.sonuc = 'Abort' AND t.abort_tarihi IS NOT NULL;
  v_anchor_tip := NULL; v_anchor_date := NULL; v_vwp_gun := NULL;
  IF v_son_abort IS NOT NULL AND (v_son_dogum IS NULL OR v_son_abort > v_son_dogum) THEN
    v_anchor_tip := 'ABORT'; v_anchor_date := v_son_abort;
    v_vwp_gun := p_tarih - v_son_abort;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'ABORT_VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  ELSIF v_son_dogum IS NOT NULL THEN
    v_anchor_tip := 'DOGUM'; v_anchor_date := v_son_dogum;
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  -- OTOMATIK BOS + ORPHAN TEMIZLEME
  FOR v_eski_tohumlama IN
    SELECT id, deneme_no, tarih, sperma
    FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Bekliyor'
    FOR UPDATE
  LOOP
    UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id = v_eski_tohumlama.id;

    UPDATE public.gorev_log
      SET iptal = true
      WHERE kaynak = 'TOH-' || v_eski_tohumlama.id::text
        AND tamamlandi = false
        AND iptal = false;
    GET DIAGNOSTICS v_iptal_gorev = ROW_COUNT;

    UPDATE public.protokol_instance
      SET durum = 'iptal'
      WHERE kaynak_ref = 'TOH-' || v_eski_tohumlama.id::text
        AND durum = 'aktif';
    GET DIAGNOSTICS v_iptal_inst = ROW_COUNT;

    v_snapshot := jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', v_toh_id::text, 'veri', jsonb_build_object(
          'hayvan_id', p_hayvan_id, 'tarih', p_tarih, 'sperma', p_sperma,
          'hekim_id', p_hekim_id, 'irk_bilgisi', p_irk_bilgisi,
          'sonuc', 'Bekliyor', 'deneme_no', v_deneme
        ))
      ),
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama', 'id', v_eski_tohumlama.id::text,
          'onceki', jsonb_build_object('sonuc', 'Bekliyor'),
          'sonraki', jsonb_build_object('sonuc', 'Boş', 'sebep', 'OTOMATIK_YENI_TOHUMLAMA')
        )
      ),
      'iptal_gorev_sayisi', v_iptal_gorev,
      'iptal_instance_sayisi', v_iptal_inst,
      'notlar', 'Yeni tohumlama girildi — eski Bekliyor cycle otomatik kapatildi'
    );
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (v_islem_id, 'TOHUMLAMA_OTOMATIK_BOS', p_hayvan_id,
            v_eski_tohumlama.id::text, 'tohumlama', v_snapshot);
  END LOOP;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme,
     p_ek_uygulamalar,
     CASE WHEN v_anchor_tip IS NOT NULL AND v_vwp_gun < 55 THEN true ELSE false END);

  IF v_anchor_tip IS NOT NULL AND v_vwp_gun < 55 AND p_vwp_override THEN
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
    VALUES (
      gen_random_uuid()::text, 'VWP_OVERRIDE', p_hayvan_id,
      jsonb_build_object('tohumlama_id', v_toh_id, 'vwp_gun', v_vwp_gun, 'anchor_tip', v_anchor_tip, 'anchor_date', v_anchor_date)
    );
  END IF;

  v_kaynak := 'TOH-' || v_toh_id::text;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'TOHUMLAMA', v_kaynak, p_tarih, 'aktif')
  RETURNING id INTO v_inst_id;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_kaynak, v_inst_id),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_kaynak, v_inst_id);

  -- BUG-002 (M2): matcher paylasilan helper'a baglandi — bos/whitespace ad
  -- dusurmez, exact once, sonra substring; kategori='Sperma' kapsami helper'da.
  -- Canli notlar metni (kupe_no) birebir korunur.
  PERFORM public.fn_sperma_stok_dus(
    p_sperma,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id)
  );

  IF p_ek_uygulamalar IS NOT NULL AND jsonb_array_length(p_ek_uygulamalar) > 0 THEN
    FOR v_ek IN SELECT * FROM jsonb_array_elements(p_ek_uygulamalar) LOOP
      IF (v_ek->>'stok_id') IS NOT NULL AND (v_ek->>'stok_id') <> '' THEN
        v_ek_stok := (v_ek->>'stok_id')::uuid;
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
        VALUES (
          v_ek_stok, 'Tohumlama',
          COALESCE((v_ek->>'doz')::numeric, 1),
          'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
          false
        );
      END IF;
    END LOOP;
  END IF;

  -- Hayvan dogrudan (gorev uzerinden degil) tohumlandiysa acik planli tohumlama
  -- gorevi artik konusuz kalir. planli_tohumlama_kaydet bu fonksiyonu icerden
  -- cagirir ve HEMEN ARDINDAN kendi gorevini iptal=false + tamamlandi=true
  -- yapar; sirali oldugu icin dogru sonuc kazanir.
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now()
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi = 'TOHUMLAMA_PLANLI'
    AND tamamlandi = false AND iptal = false;

  -- S-7 (MK5: yalnız bayrak AÇIKKEN). Tohumlama INSERT'i ve yukarıdaki tüm
  -- adımlardan sonra, aynı transaction'da: tohumlama tarihinde başlamış aktif
  -- senkronizasyon (protocol_family dolu) vakaları kapanır; protocol_family NULL
  -- vakalar (Mastit vb. / UNKNOWN) dokunulmaz. Açık OVSYNC_BASLAT görevleri
  -- (S-8 D50 zinciri) muaf edilir. Bayrak kapalı → hiçbir yazma, anahtar yok.
  IF public._ovsync_pg_aktif() THEN
    v_ovsync_aktif := true;

    FOR v_vaka IN
      SELECT c.id
        FROM public.cases c
       WHERE c.animal_id = p_hayvan_id
         AND c.status = 'active'
         AND c.protocol_family IS NOT NULL
         AND c.start_date <= p_tarih
       ORDER BY c.start_date, c.id
       FOR UPDATE
    LOOP
      v_kapat := public._vaka_kapat(v_vaka.id, 'TOHUMLAMA', NULL,
                                    jsonb_build_object('tohumlama_id', v_toh_id));
      IF NOT COALESCE((v_kapat->>'zaten_kapali')::boolean, false) THEN
        v_kapatilan := v_kapatilan || jsonb_build_array(jsonb_build_object(
          'case_id',     v_vaka.id,
          'iptal_seans', v_kapat->'iptal_seans',
          'iptal_gorev', v_kapat->'iptal_gorev'));
      END IF;
    END LOOP;
  END IF;

  -- MK8 (R3.1): temizlik bayraktan BAĞIMSIZ — yalnız yeni iş yaratan adımlar
  -- (vaka kapanış döngüsü yukarıda, dönüşteki 'kapatilan_senkronizasyon_vakalari'
  -- anahtarı) bayrak arkasındadır; açık OVSYNC_BASLAT görevi ve ILK_TOHUMLAMA
  -- instance'ının iptali her zaman çalışır. Bayrak hiç açılmadıysa S-8 hiçbir
  -- OVSYNC_BASLAT/ILK_TOHUMLAMA satırı üretmediği için 0 satır etkiler — MK5
  -- bozulmaz.
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now(),
      kapatan_ref = 'ILK_TOH_MUAF:TOHUMLAMA'
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi = 'OVSYNC_BASLAT'
    AND tamamlandi = false AND iptal = false;

  -- Muaf edilen rotanın instance'ı da kapanır (açık kalırsa orphan denetimine düşer).
  UPDATE public.protokol_instance
  SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_MUAF:TOHUMLAMA'
  WHERE hayvan_id = p_hayvan_id
    AND tip = 'UREME' AND alttip = 'ILK_TOHUMLAMA'
    AND durum = 'aktif';

  RETURN jsonb_build_object(
    'ok',                       true,
    'tohumlama_id',             v_toh_id,
    'deneme_no',                v_deneme,
    'inst_id',                  v_inst_id,
    'otomatik_bos_sayisi',      v_iptal_gorev,
    'otomatik_iptal_instance',  v_iptal_inst
  ) || CASE WHEN v_ovsync_aktif
            THEN jsonb_build_object('kapatilan_senkronizasyon_vakalari', v_kapatilan)
            ELSE '{}'::jsonb
       END;
END;
$function$;

REVOKE ALL ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) TO authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- S-3  tedavi_sablon_uygula — canlı gövde + provenance damgası
-- ════════════════════════════════════════════════════════════════════════════
-- Snapshot: {sablon_id, ad, protokol_ailesi, tohumlama_plani, kalemler[],
-- uygulama_at, baslangic}. Yalnız başarılı yolda (RETURN ok:true öncesi) yazılır.
CREATE OR REPLACE FUNCTION public.tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_case         record;
  v_gun_no       smallint;
  v_date         date;
  v_sessions     jsonb;
  v_atlanan      jsonb := '[]'::jsonb;
  v_gun_atlanan  jsonb;
  v_gun_sayisi   int := 0;
  v_seans_sayisi int := 0;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  FOR v_gun_no IN
    SELECT DISTINCT gun_no FROM public.tedavi_sablonu_kalem
    WHERE sablon_id = p_sablon_id ORDER BY gun_no
  LOOP
    v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_gun_no - 1);

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'planned_time',    to_char(k.planned_time,'HH24:MI'),
             'stok_id',         k.stok_id,
             'drug_product_id', k.drug_product_id,
             'dose',            k.dose,
             'unit',            k.unit,
             'route',           k.route
           ) ORDER BY k.planned_time), '[]'::jsonb)
    INTO v_sessions
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
      AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id));

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gun_no', k.gun_no,
             'planned_time', to_char(k.planned_time,'HH24:MI'),
             'neden', 'silinmiş ilaç/stok')), '[]'::jsonb)
    INTO v_gun_atlanan
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND ((k.drug_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
        OR (k.stok_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id)));
    IF jsonb_array_length(v_gun_atlanan) > 0 THEN
      v_atlanan := v_atlanan || v_gun_atlanan;
    END IF;

    IF jsonb_array_length(v_sessions) > 0 THEN
      PERFORM public.add_treatment_day_with_sessions(p_case_id, v_date, v_sessions, NULL);
      v_gun_sayisi   := v_gun_sayisi + 1;
      v_seans_sayisi := v_seans_sayisi + jsonb_array_length(v_sessions);
    END IF;
  END LOOP;

  -- S-3 provenance (bayraktan bağımsız, salt metadata): vakanın İLK şablon
  -- uygulaması damgalanır; source_template_id doluysa ikinci uygulama BU
  -- provenance'ı (source_template_id, protocol_snapshot) EZMEZ (R3.1) — dal
  -- yalnız source_template_id IS NULL iken çalışır.
  UPDATE public.cases c
     SET source_template_id = t.id,
         protocol_family    = COALESCE(t.protokol_ailesi, c.protocol_family),
         protocol_snapshot  = jsonb_build_object(
           'sablon_id',       t.id,
           'ad',              t.ad,
           'protokol_ailesi', t.protokol_ailesi,
           'tohumlama_plani', t.tohumlama_plani,
           'kalemler', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                 'gun_no',          k.gun_no,
                                 'planned_time',    to_char(k.planned_time,'HH24:MI'),
                                 'stok_id',         k.stok_id,
                                 'drug_product_id', k.drug_product_id,
                                 'dose',            k.dose,
                                 'unit',            k.unit,
                                 'route',           k.route
                               ) ORDER BY k.gun_no, k.planned_time, k.id), '[]'::jsonb)
                          FROM public.tedavi_sablonu_kalem k
                         WHERE k.sablon_id = t.id),
           'uygulama_at',     now(),
           'baslangic',       COALESCE(p_baslangic_tarihi, v_case.start_date))
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NULL
     AND t.id = p_sablon_id;

  -- R3.1 (#12): source_template_id ZATEN doluysa (ikinci+ şablon uygulaması)
  -- yukarıdaki dal atlanır — provenance/snapshot ezilmez. Ama protocol_family
  -- hâlâ NULL ise (ör. ilk uygulanan şablon ailesizdi: Mastit gibi) ve bu
  -- şablonun ailesi doluysa, YALNIZ protocol_family ayrı bir UPDATE ile
  -- doldurulur; source_template_id ve protocol_snapshot bu dalda DOKUNULMAZ.
  UPDATE public.cases c
     SET protocol_family = t.protokol_ailesi
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NOT NULL
     AND c.protocol_family IS NULL
     AND t.protokol_ailesi IS NOT NULL
     AND t.id = p_sablon_id;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$function$;

REVOKE ALL ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date) TO authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- planli_tohumlama_kaydet — DEĞİŞİKLİK YOK (T04)
-- ════════════════════════════════════════════════════════════════════════════
-- Canlı gövde: v_result := tohumlama_kaydet(...); … RETURN v_result ||
-- jsonb_build_object('gorev_id', p_gorev_id); → içteki tüm anahtarlar
-- ('kapatilan_senkronizasyon_vakalari' dahil) olduğu gibi döner. Sıra notu:
-- tohumlama_kaydet (ve _vaka_kapat 5b) bu görevi iptal edebilir; planli hemen
-- ardından kendi görevini iptal=false, tamamlandi=true yapar (canlı davranış).

NOTIFY pgrst, 'reload schema';

-- EOF 20260923000005
