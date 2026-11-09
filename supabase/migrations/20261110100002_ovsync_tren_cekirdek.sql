-- Migration: Ovsync treni çekirdeği (ovsync treni D2)
-- Tarih: 2026-11-09. Spec docs/plans/2026-11-09-ovsync-tren/design.md (K1, K2, K5, K10, §5, §7); PLAN.md D2, R1/R3/R5/R6/R18.
-- Önceki migration: 20261110100001. BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısında.
-- Yalnız YENİ nesne: 4 ayar tohumu, cases.ovsync_tren kolonu, 12 iç yardımcı. Mevcut fonksiyon gövdesi değişmez
-- (md5 koruması gerekmez); davranış ovsync_tren_aktif = 0 iken hiçbir yolda değişmez (yardımcıları henüz kimse çağırmıyor).
-- Tarih yalnız TR: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ROLLBACK: DROP FUNCTION aşağıdaki 12 iç yardımcı; ALTER TABLE public.cases DROP COLUMN ovsync_tren;
--   DELETE FROM protokol_ayar WHERE anahtar IN ('ovsync_tren_aktif','ovsync_tren_capa','ovsync_tren_one_cekme_gun','ovsync_pg_erteleme_tolerans_gun').

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- 1) Ayar tohumları (varsa dokunulmaz; db-validate baseline'ında protokol_ayar PK'si olmadığından insert-eksikse kalıbı, D1 emsali)
INSERT INTO public.protokol_ayar (anahtar, deger, birim, min_deger, max_deger, aciklama)
SELECT v.anahtar, v.deger, v.birim, v.mn, v.mx, v.aciklama
  FROM (VALUES
    ('ovsync_tren_aktif', 0::numeric, 'bool', 0::numeric, 1::numeric,
     'Ovsync treni: 1 = Ovsync başlangıçları haftalık tren gününde toplanır (Ovsync-PG kuralları da açık olmalı); 0 = eski davranış.'),
    ('ovsync_tren_capa', 20261112, 'YYYYMMDD', 20260101, 20991231,
     'Ovsync tren ritminin çapası (YYYYMMDD). Tren günleri = çapa + 7k. Toptan erteleme çapayı N gün kaydırır.'),
    ('ovsync_tren_one_cekme_gun', 2, 'gün', 0, 2,
     'Kural günü en fazla bu kadar gün öne çekilerek trene bindirilir.'),
    ('ovsync_pg_erteleme_tolerans_gun', 1, 'gün', 0, 2,
     'Ovsync aşama 1: PG1 toplam (birikimli) erteleme toleransı; fazlası baştan başlat.')
  ) AS v(anahtar, deger, birim, mn, mx, aciklama)
 WHERE NOT EXISTS (SELECT 1 FROM public.protokol_ayar a WHERE a.anahtar = v.anahtar);

-- 2) Tren üyeliği (R3)
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS ovsync_tren date;
COMMENT ON COLUMN public.cases.ovsync_tren IS
  'Ovsync tren etiketi (R3): vakanın GnRH1 planlı günü, ritim sınıfı. NULL = bağımsız/eski. Günler k gün kayınca aynı işlemde += k; hastalık günü (K9) NULL yapar.';
-- D9 (RD9-1/3): bağımsız işareti. Bayrak açıkken başlatılan aktif OVSYNC vakada ovsync_tren IS NULL ⇔ ovsync_bagimsiz; true geri dönmez.
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS ovsync_bagimsiz boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.cases.ovsync_bagimsiz IS
  'Ovsync bağımsız vaka (K8/K9): true = trene hiçbir yoldan bağlanmaz (R14 göçü dahil). false + ovsync_tren NULL = eski (bayrak öncesi).';

-- 3) Bayrak ve ayar
CREATE OR REPLACE FUNCTION public._ovsync_tren_aktif()
 RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public._ovsync_pg_aktif() AND public._ayar('ovsync_tren_aktif', 0) = 1;
$function$;

-- {capa date, one_cekme int, tolerans int}; eksik/geçersiz → OVSYNC_TREN_AYAR:{anahtar, deger, sebep} (R1, spec §7).
CREATE OR REPLACE FUNCTION public._ovsync_tren_ayar()
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_k    text;
  v_v    numeric;
  v_s    text;
  v_capa date;
  v_d    jsonb := '{}'::jsonb;
BEGIN
  FOREACH v_k IN ARRAY ARRAY['ovsync_tren_capa', 'ovsync_tren_one_cekme_gun', 'ovsync_pg_erteleme_tolerans_gun'] LOOP
    v_v := (SELECT a.deger FROM public.protokol_ayar a WHERE a.anahtar = v_k);
    v_s := CASE WHEN v_v IS NULL THEN 'EKSIK'
                WHEN v_v <> trunc(v_v) THEN 'TAMSAYI_DEGIL'
                WHEN v_k <> 'ovsync_tren_capa' AND (v_v < 0 OR v_v > 2) THEN 'ARALIK_DISI' END;
    IF v_s IS NULL AND v_k = 'ovsync_tren_capa' THEN
      BEGIN  -- PG ≥10 to_date('20261131') 22008 atar: yakalanır, ham hata dışarı çıkmaz
        v_capa := to_date(v_v::bigint::text, 'YYYYMMDD');
        IF to_char(v_capa, 'YYYYMMDD') <> v_v::bigint::text THEN v_s := 'TARIH_GECERSIZ'; END IF;
      EXCEPTION WHEN others THEN
        v_s := 'TARIH_GECERSIZ';
      END;
    END IF;
    IF v_s IS NOT NULL THEN
      RAISE EXCEPTION 'OVSYNC_TREN_AYAR:%', jsonb_build_object('anahtar', v_k, 'deger', v_v, 'sebep', v_s)::text;
    END IF;
    v_d := v_d || jsonb_build_object(v_k, v_v);
  END LOOP;
  RETURN jsonb_build_object('capa', v_capa,
                            'one_cekme', (v_d->>'ovsync_tren_one_cekme_gun')::int,
                            'tolerans', (v_d->>'ovsync_pg_erteleme_tolerans_gun')::int);
END;
$function$;

-- 4) Tren günü: tek hesap noktası (K1/K2). İlk tren ≥ max(kural − öne çekme, bugün).
CREATE OR REPLACE FUNCTION public._ovsync_tren_gunu_ic(p_kural date, p_capa date, p_one_cekme integer, p_bugun date)
 RETURNS date LANGUAGE sql IMMUTABLE STRICT
AS $function$
  SELECT a + (((p_capa - a) % 7) + 7) % 7
    FROM (SELECT GREATEST(p_kural - p_one_cekme, p_bugun) AS a) s;
$function$;

-- Kapalı: GREATEST(kural, bugün_TR) — bugünkü çağıranlarla birebir; ayar okunmaz.
CREATE OR REPLACE FUNCTION public._ovsync_tren_gunu(p_kural date)
 RETURNS date LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_b date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_a jsonb;
BEGIN
  IF NOT public._ovsync_tren_aktif() THEN
    RETURN GREATEST(p_kural, v_b);
  END IF;
  v_a := public._ovsync_tren_ayar();
  RETURN public._ovsync_tren_gunu_ic(p_kural, (v_a->>'capa')::date, (v_a->>'one_cekme')::int, v_b);
END;
$function$;

CREATE OR REPLACE FUNCTION public._ovsync_tren_gunu_mu(p_tarih date)
 RETURNS boolean LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_tarih IS NULL OR NOT public._ovsync_tren_aktif() THEN
    RETURN false;
  END IF;
  RETURN ((p_tarih - (public._ovsync_tren_ayar()->>'capa')::date) % 7 + 7) % 7 = 0;
END;
$function$;

-- 5) Aşama (R6): hastalık-dışı günler (treatment_date, day_no) sırasıyla; gün#1 GnRH1, gün#2 PG1.
--    R6-EK (root SORU-3): Y = tamamlandi ve (tüm seanslar uygulandı ya da hiçbiri uygulanmamış ve uygulanmadı işareti yok —
--    geriye tarihli kayıt); N = hiç seansı uygulanmamış ve (gün tamamlanmadı ya da uygulanmadı işaretli seans var);
--    X = diğer (kısmi seans vb., belirsiz). Seanssız gün X.
--    0 = NNNN, 1 = YNNN, 2 = YY.., gün sayısı ≠ 4 ya da başka desen → NULL. Aktif OVSYNC vaka değilse NULL.
CREATE OR REPLACE FUNCTION public._ovsync_asama(p_case_id uuid)
 RETURNS smallint LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH s AS (
    SELECT u.treatment_day_id,
           count(*) AS n,
           count(*) FILTER (WHERE u.uygulama_tamamlandi_at IS NOT NULL) AS uygulandi,
           count(*) FILTER (WHERE u.uygulama_tamamlandi_at IS NULL AND COALESCE(u.uygulanmadi, false)) AS uygulanmadi
      FROM public.treatment_day_uygulamalar u
     WHERE u.treatment_day_id IN (SELECT d.id FROM public.treatment_days d WHERE d.case_id = p_case_id)
     GROUP BY u.treatment_day_id
  ), g AS (
    SELECT d.treatment_date, d.day_no,
           CASE WHEN COALESCE(d.tamamlandi, false) AND s.n > 0
                     AND (s.uygulandi = s.n OR (s.uygulandi = 0 AND s.uygulanmadi = 0)) THEN 'Y'
                WHEN s.n > 0 AND s.uygulandi = 0 AND (NOT COALESCE(d.tamamlandi, false) OR s.uygulanmadi > 0) THEN 'N'
                ELSE 'X' END AS durum
      FROM public.cases c
      JOIN public.treatment_days d ON d.case_id = c.id AND d.disease_id IS NULL
      LEFT JOIN s ON s.treatment_day_id = d.id
     WHERE c.id = p_case_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC'
  ), k AS (
    SELECT count(*) AS n, string_agg(durum, '' ORDER BY treatment_date, day_no) AS desen FROM g
  )
  SELECT (CASE WHEN n <> 4 THEN NULL
               WHEN desen = 'NNNN' THEN 0
               WHEN desen = 'YNNN' THEN 1
               WHEN desen LIKE 'YY__' THEN 2 END)::smallint
    FROM k;
$function$;

-- 6) PG1 birikimli kayma (R18) = PG1 günü − (GnRH1 çapası + 7). Çapa (R6-EK): GnRH1 seanslarının en geç uygulanma anının
--    TR günü; seansları işaretsiz tamamlanmış (geriye tarihli) günde treatment_date. LEAST yok.
--    GnRH1 yapılmamışsa (aşama 0) ya da aşama belirsizse NULL.
CREATE OR REPLACE FUNCTION public._ovsync_pg1_kayma(p_case_id uuid)
 RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH g AS (
    SELECT d.id, d.treatment_date, row_number() OVER (ORDER BY d.treatment_date, d.day_no) AS sira
      FROM public.treatment_days d
     WHERE d.case_id = p_case_id AND d.disease_id IS NULL
  )
  SELECT g2.treatment_date
         - (COALESCE(((SELECT max(u.uygulama_tamamlandi_at) FROM public.treatment_day_uygulamalar u WHERE u.treatment_day_id = g1.id)
                       AT TIME ZONE 'Europe/Istanbul')::date, g1.treatment_date) + 7)
    FROM g g1 JOIN g g2 ON g1.sira = 1 AND g2.sira = 2
   WHERE public._ovsync_asama(p_case_id) IN (1, 2);
$function$;

-- 7) K10 iç bayrağı (R5): işlem-yerel GUC; Ovsync ekranı RPC'leri ve iç zincirler kilidi bununla aşar.
CREATE OR REPLACE FUNCTION public._ovsync_ic_ac()
 RETURNS void LANGUAGE sql
AS $function$
  SELECT set_config('app.ovsync_tren_ic', '1', true);
$function$;

CREATE OR REPLACE FUNCTION public._ovsync_ic_mi()
 RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT COALESCE(current_setting('app.ovsync_tren_ic', true), '') = '1';
$function$;

-- 8) Ovsync görevi (R5, SQL ↔ JS ovsyncTrenGorevMu tek tanım; bayraktan bağımsız):
--    (a) OVSYNC_BASLAT; (b) TOHUMLAMA_PLANLI ve hayvanın aktif OVSYNC vakası var;
--    (c) TEDAVI_GUN/TEDAVI_SEANS ve aciklama->>'day_id' aktif OVSYNC vakanın günü. Bozuk JSON → false.
CREATE OR REPLACE FUNCTION public._ovsync_gorev_mu(p_gorev_id uuid)
 RETURNS boolean LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g   record;
  v_day uuid;
BEGIN
  SELECT g.gorev_tipi, g.hayvan_id, g.aciklama INTO v_g FROM public.gorev_log g WHERE g.id = p_gorev_id;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_g.gorev_tipi = 'OVSYNC_BASLAT' THEN RETURN true; END IF;
  IF v_g.gorev_tipi = 'TOHUMLAMA_PLANLI' THEN
    RETURN EXISTS (SELECT 1 FROM public.cases c
                    WHERE c.animal_id = v_g.hayvan_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC');
  END IF;
  IF v_g.gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS') AND v_g.aciklama ~ '^\s*\{' THEN
    BEGIN
      v_day := (v_g.aciklama::jsonb->>'day_id')::uuid;
    EXCEPTION WHEN data_exception THEN
      RETURN false;
    END;
    RETURN EXISTS (SELECT 1 FROM public.treatment_days d JOIN public.cases c ON c.id = d.case_id
                    WHERE d.id = v_day AND c.status = 'active' AND c.protocol_family = 'OVSYNC');
  END IF;
  RETURN false;
END;
$function$;

-- 9) K10 kilidi (R5): tren açık, iç değil ve Ovsync görevi/vakası → OVSYNC_TREN_EKRANI:{gorev_id|case_id, hayvan_id, tren_gunu}
CREATE OR REPLACE FUNCTION public._ovsync_kilit_gorev(p_gorev_id uuid)
 RETURNS void LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g    record;
  v_tren date;
BEGIN
  IF NOT public._ovsync_tren_aktif() OR public._ovsync_ic_mi() OR NOT public._ovsync_gorev_mu(p_gorev_id) THEN
    RETURN;
  END IF;
  SELECT g.hayvan_id, g.gorev_tipi, g.hedef_tarih INTO v_g FROM public.gorev_log g WHERE g.id = p_gorev_id;
  IF v_g.gorev_tipi = 'OVSYNC_BASLAT' THEN
    v_tren := v_g.hedef_tarih;
  ELSE
    SELECT c.ovsync_tren INTO v_tren FROM public.cases c
     WHERE c.animal_id = v_g.hayvan_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC'
     ORDER BY c.start_date DESC, c.created_at DESC LIMIT 1;
  END IF;
  RAISE EXCEPTION 'OVSYNC_TREN_EKRANI:%',
    jsonb_build_object('gorev_id', p_gorev_id, 'hayvan_id', v_g.hayvan_id, 'tren_gunu', v_tren)::text;
END;
$function$;

CREATE OR REPLACE FUNCTION public._ovsync_kilit_vaka(p_case_id uuid)
 RETURNS void LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_c record;
BEGIN
  IF NOT public._ovsync_tren_aktif() OR public._ovsync_ic_mi() THEN
    RETURN;
  END IF;
  SELECT c.animal_id, c.ovsync_tren INTO v_c FROM public.cases c
   WHERE c.id = p_case_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC';
  IF FOUND THEN
    RAISE EXCEPTION 'OVSYNC_TREN_EKRANI:%',
      jsonb_build_object('case_id', p_case_id, 'hayvan_id', v_c.animal_id, 'tren_gunu', v_c.ovsync_tren)::text;
  END IF;
END;
$function$;

-- 10) ACL: hepsi iç yardımcı (Supabase varsayılan yetkisi anon/authenticated'a EXECUTE verir)
REVOKE ALL ON FUNCTION public._ovsync_tren_aktif() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_tren_ayar() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_tren_gunu_ic(date, date, integer, date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_tren_gunu(date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_tren_gunu_mu(date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_asama(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_pg1_kayma(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_ic_ac() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_ic_mi() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_gorev_mu(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_kilit_gorev(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._ovsync_kilit_vaka(uuid) FROM PUBLIC, anon, authenticated;
