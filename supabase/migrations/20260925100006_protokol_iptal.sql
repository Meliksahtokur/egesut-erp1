-- ============================================================================
-- Migration: 20260925100006_protokol_iptal
-- Tarih: 2026-09-25 · Erteleme-genel turu E4-DB (zarf E4 / plan-db.md Adım 5)
-- Etkiler:
--   1. cases.close_reason CHECK kısıtı: uzaya 'IPTAL' eklenir (M5-sonrası liste
--      üzerinden: ERKEN_KAPANIS/TOHUMLAMA/PG → +IPTAL)
--   2. public._vaka_kapat yeniden tanımı (E3/M5 SONRASI canlı gövdeden başlar —
--      000008 tuzağı; 'PG' dalı KORUNUR): 'IPTAL' dalı + CASE_CLOSED_BY_IPTAL
--   3. yeni RPC public.protokol_iptal(uuid, boolean, text) — SECDEF,
--      authenticated'a açık (UI × butonu E4-UI'de bağlanır)
--
-- Amaç (S2): Ovsync/tedavi zincirinden çıkışın temiz yolu — aktif protokol
--   vakasını İPTAL et (vaka + kalan seans/görev/gün + stok iadesi + hayvan
--   seviyesi ILK_TOHUMLAMA instance kapanışı) ve istenirse TEK yeni
--   OVSYNC_BASLAT görevi kur (yeniden başlat). × butonunun yalnız gorev_log
--   PATCH'leyip instance'ı aktif bırakan mevcut davranışının DB tarafı.
--
-- Yeniden başlat tek-görev garantisi: _ovsync_baslat_gorev_kur çekirdeği
--   (protokol_instance.kaynak_ref UNIQUE + ON CONFLICT DO NOTHING; kısırlık/
--   Aktif/Dişi guard'ları 20260925000012/000016'dan gelir). Kaynak anahtarı
--   'PROTOKOL-IPTAL-<case_id>' — vaka başına bir kez (status guard'ı yeniden
--   çağrıyı zaten reddeder) → çift görev üretilemez.
--
-- Hata ailesi: PROTOKOL_IPTAL_EDILEMEZ:<json> (VAKA_ACIK_DEGIL /
--   PROTOKOL_VAKASI_DEGIL).
-- Audit: _vaka_kapat 'IPTAL' dalı CASE_CLOSED_BY_IPTAL + RPC düzeyinde
--   PROTOKOL_IPTAL (tohumlama_kaydet → _vaka_kapat iki-audit kalıbı).
--
-- Geri alınabilir: RPC DROP + CHECK eski liste + önceki _vaka_kapat gövdesi.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) close_reason uzayı: 'IPTAL' ─────────────────────────────────────
ALTER TABLE public.cases DROP CONSTRAINT IF EXISTS cases_close_reason_check;
ALTER TABLE public.cases ADD CONSTRAINT cases_close_reason_check
  CHECK (close_reason = ANY (ARRAY['ERKEN_KAPANIS'::text, 'TOHUMLAMA'::text, 'PG'::text, 'IPTAL'::text]));

-- ── 2) _vaka_kapat: M5-sonrası canlı gövde + 'IPTAL' dalı ──────────────
CREATE OR REPLACE FUNCTION public._vaka_kapat(p_case_id uuid, p_close_reason text, p_not text, p_ref jsonb)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
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
  IF p_close_reason IS NULL OR p_close_reason NOT IN ('ERKEN_KAPANIS', 'TOHUMLAMA', 'PG', 'IPTAL') THEN
    RAISE EXCEPTION '_vaka_kapat: geçersiz close_reason: %', p_close_reason;
  END IF;

  -- Kilit (yazma değil). Kilit sırası (MK9): vaka (burada) → seans/stok/gün
  -- (aşağıdaki UPDATE'ler) → görev (adım 5/5b) → vaka satırının kendisi (zaten
  -- kilitli). ERKEN_KAPANIS canlıdaki gibi durumdan bağımsız ilerler — TEK
  -- istisna: tohumlama ile kapanmış vaka (R3.1, T21) → no-op. TOHUMLAMA/PG/IPTAL
  -- zaten kapalı/olmayan vakada hiçbir şey yazmaz.
  SELECT id, animal_id, status, close_reason INTO v_case
    FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF p_close_reason IN ('TOHUMLAMA', 'PG', 'IPTAL') AND (NOT FOUND OR v_case.status IS DISTINCT FROM 'active') THEN
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
    WHEN 'PG' THEN 'Bağımsız PG uygulaması ile sonlandırıldı' || COALESCE(': ' || p_not, '')
    WHEN 'IPTAL' THEN 'Protokol iptal edildi' || COALESCE(': ' || p_not, '')
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
    AND da.uygulanmadi IS DISTINCT FROM (true);

  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_days td
  WHERE td.id = da.treatment_day_id
    AND td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false
    AND da.uygulanmadi IS DISTINCT FROM (true);

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
  ELSIF p_close_reason = 'PG' THEN
    -- E3 (S3): bağımsız PG kapanışı.
    v_closed_at := now();
    INSERT INTO public.islem_log(tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES (
      'CASE_CLOSED_BY_PG', v_case.animal_id,
      p_case_id::text, 'cases',
      jsonb_build_object(
        'case_id',           p_case_id,
        'pg_event_id',       p_ref->>'pg_event_id',
        'close_reason',      p_close_reason,
        'iptal_seans',       v_remaining_count,
        'iptal_gorev',       v_iptal_gorev,
        'gerceklesen_seans', v_gerceklesen,
        'closed_at',         v_closed_at
      ),
      '{}'::jsonb
    );
  ELSIF p_close_reason = 'IPTAL' THEN
    -- E4 (S2): protokol iptali — protokol_iptal RPC'sinden çağrılır.
    v_closed_at := now();
    INSERT INTO public.islem_log(tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES (
      'CASE_CLOSED_BY_IPTAL', v_case.animal_id,
      p_case_id::text, 'cases',
      jsonb_build_object(
        'case_id',           p_case_id,
        'protokol_iptal',    p_ref ? 'protokol_iptal',
        'close_reason',      p_close_reason,
        'iptal_seans',       v_remaining_count,
        'iptal_gorev',       v_iptal_gorev,
        'gerceklesen_seans', v_gerceklesen,
        'closed_at',         v_closed_at
      ),
      '{}'::jsonb
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

-- ── 3) protokol_iptal RPC ─────────────────────────────────────────────
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
  --    _ovsync_baslat_gorev_kur çekirdeğinden — guard takılırsa sessiz NULL)
  IF p_yeniden_baslat THEN
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

-- ── Kapı kuralları ─────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public._vaka_kapat(uuid, text, text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.protokol_iptal(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protokol_iptal(uuid, boolean, text) TO authenticated;

COMMIT;
