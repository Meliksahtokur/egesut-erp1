-- Migration: Ovsync treni — görev doğumu, ACIK-DISI anahtarı, G7/G9 (ovsync treni D3)
-- Tarih: 2026-11-09. Spec docs/plans/2026-11-09-ovsync-tren/design.md (K2, §5 tek hesap noktası + anahtar yan düzeltmesi);
--   PLAN.md D3, R8/R10/R19. Önceki migration: 20261110100002. BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar.
--   Prod apply sahip kapısında.
-- Değişen 6 fonksiyon, gövdeleri prod (kanit/fn) gövdesinden kopyalandı; yalnız "D3" yorumlu satırlar değişti:
--   _ovsync_baslat_gorev_kur (DROP + CREATE, + p_hemen), _acik_disi_gorev_kur (DROP + CREATE, + p_hemen, R10 anahtarı),
--   _acik_disi_hedef_ic, ovsync_baslat_uyarilari, protokol_iptal, tohumlama_bos_ve_devam (imzalar aynı).
-- Bayrak (ovsync_tren_aktif) 0 iken davranış eski ile birebir; R19 gereği bayraktan bağımsız iki düzeltme: R10 anahtarı
--   (eski anahtar çakışmasıyla takılı hayvanlara ilk cron'da görev doğar — runbook P1(c)) ve G7 fail-closed
--   (OVSYNC_GOREV_ACILAMADI). İmzalara eklenen p_hemen default'ludur; eski çağrılar aynı sonucu verir.
-- Önkoşul: 6 canlı gövdenin md5'i D0 tabanı (govde-taban.md); değilse <FN>_GOVDE_FARKLI ile durur.
-- Tarih yalnız TR: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ROLLBACK: DROP FUNCTION public._ovsync_baslat_gorev_kur(text,date,text,date,boolean), public._acik_disi_gorev_kur(text,boolean);
--   altı fonksiyonu kanit/fn/<ad>.sql gövdeleriyle yeniden kur; ACL'yi (iç yardımcılar service_role, RPC'ler authenticated) geri ver.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public._ovsync_baslat_gorev_kur(text,date,text,date)', '66e46e679f85afada875808607a28dac', 'OVSYNC_BASLAT_GOREV_KUR_GOVDE_FARKLI'),
    ('public._acik_disi_gorev_kur(text)', 'cb7b8182151602505b48615148592b2a', 'ACIK_DISI_GOREV_KUR_GOVDE_FARKLI'),
    ('public._acik_disi_hedef_ic(text)', '5082fc8884d9ad96a8fa4f16d457c9f5', 'ACIK_DISI_HEDEF_IC_GOVDE_FARKLI'),
    ('public.ovsync_baslat_uyarilari()', '869dcfef020a01c6446359d13aa988ed', 'OVSYNC_BASLAT_UYARILARI_GOVDE_FARKLI'),
    ('public.protokol_iptal(uuid,boolean,text)', 'e5487897bf66b1f8f361792cb4bcf74a', 'PROTOKOL_IPTAL_GOVDE_FARKLI'),
    ('public.tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean)', 'ba1ba4bb7b870171e190013d7fc090c8', 'TOHUMLAMA_BOS_VE_DEVAM_GOVDE_FARKLI')) AS v(imza, md5, kod) LOOP
    IF NOT COALESCE((SELECT md5(p.prosrc) FROM pg_catalog.pg_proc p WHERE p.oid = to_regprocedure(r.imza)) = r.md5, false) THEN
      RAISE EXCEPTION '%: canlı gövde D0 tabanı değil (govde-taban.md: %), D3 durdu', r.kod, r.imza;
    END IF;
  END LOOP;
END $$;

-- 1) _ovsync_baslat_gorev_kur: imza + p_hemen (R8). Eski imza düşer; default'lu ek parametre CREATE OR REPLACE ile
--    yeni overload doğururdu (belirsiz çağrı). 4-arg çağıran (_ilk_tohumlama_rota_kur) default ile çözülür.
DROP FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date);
CREATE FUNCTION public._ovsync_baslat_gorev_kur(p_hayvan_id text, p_baslangic date, p_kaynak_ref text, p_kural_tarihi date, p_hemen boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inst_id     uuid;
  v_gorev_id    uuid;
  v_iptal_gorev uuid[];
  v_iptal_inst  uuid[];
  v_hedef       date;
  v_h           record;
  v_tren        date;      -- D3: bayrak açıkken tren günü (kapalıyken NULL)
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN NULL;
  END IF;

  IF p_hayvan_id IS NULL OR p_baslangic IS NULL OR p_kural_tarihi IS NULL
     OR COALESCE(p_kaynak_ref, '') = '' THEN
    RAISE EXCEPTION 'OVSYNC_BASLAT_PARAMETRE:%', jsonb_build_object(
      'hayvan_id', p_hayvan_id, 'baslangic', p_baslangic,
      'kaynak_ref', p_kaynak_ref, 'kural_tarihi', p_kural_tarihi);
  END IF;

  -- K3 (2026-09-25): kısır/Aktif değil/Dişi değil hayvana zincir görevi AÇILMAZ.
  --   En alt ortak halka: dogum_kaydet/tohumlama_abort kancaları _ilk_tohumlama_rota_kur
  --   sarmalayıcısı üzerinden buraya iner; açık-dişi üretimi (_acik_disi_gorev_kur) de
  --   aynı çekirdeği kullanır. Mimar B1: 000001:17-19 yorumunun düzeltmesi — olay
  --   kancaları artık bu gövdenin guard'ından beslenir. Sessiz NULL (bayrak-kapalı deseni).
  -- [F4 2026-09-25] Guard parametre doğrulamasının ARDINA taşındı (K3 bulgusu):
  --   bayrak açıkken parametre ihlali yeniden OVSYNC_BASLAT_PARAMETRE üretir;
  --   guard yalnız doğrulanmış girdiler üzerinde kısır/Aktif/Dişi kararını verir.
  SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
    INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif'
     OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' OR v_h.kisir THEN
    RETURN NULL;
  END IF;

  -- C5 (cila2, fail-closed): kural günü gelmeden görev SATIRI doğmaz. Sahip
  -- kuralı "uyarılar 2 gün önceden ekrana düşmeli" — erken dönem görünürlüğü
  -- görevde değil panel uyarısındadır (ovsync_baslat_uyarilari görevsiz kol).
  -- 12 aylık düveye hedefi +21 gün ileride görev açılması bu kapıyla biter.
  -- D3 / R8 (ovsync treni 2026-11-09): tren açıkken hedef _ovsync_tren_gunu(kural); satır tren−2 ≤ bugün olunca doğar.
  --   p_hemen (G7 Boş sonrası, G9 yeniden başlat, ovsync_bastan_baslat — kullanıcı iradesi) bu kapıyı atlar, hedef yine
  --   tren günüdür. Tren kapalı: C5 kapısı birebir, p_hemen yok sayılır. Ayar bozuksa OVSYNC_TREN_AYAR (sessiz düşüş yok).
  IF public._ovsync_tren_aktif() THEN
    v_tren := public._ovsync_tren_gunu(p_kural_tarihi);
    IF NOT COALESCE(p_hemen, false) AND v_tren - 2 > (now() AT TIME ZONE 'Europe/Istanbul')::date THEN
      RETURN NULL;
    END IF;
  ELSIF p_kural_tarihi > (now() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RETURN NULL;
  END IF;

  -- Idempotens önce (000006 kalıbı): aynı olay ikinci kez gelirse dokunulmaz
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'ILK_TOHUMLAMA', p_kaynak_ref, p_baslangic, 'aktif')
  ON CONFLICT (kaynak_ref) DO NOTHING
  RETURNING id INTO v_inst_id;
  IF v_inst_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Yeni rota eski açık rotanın yerine geçer
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_YENI_OLAY'
     WHERE hayvan_id = p_hayvan_id
       AND gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_iptal_gorev FROM u;

  WITH u AS (
    UPDATE public.protokol_instance
       SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_YENI_OLAY'
     WHERE hayvan_id = p_hayvan_id
       AND alttip = 'ILK_TOHUMLAMA'
       AND durum = 'aktif'
       AND id <> v_inst_id
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_iptal_inst FROM u;

  v_hedef := COALESCE(v_tren, GREATEST(p_kural_tarihi, (now() AT TIME ZONE 'Europe/Istanbul')::date));

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat,
                                tamamlandi, kaynak, protokol_instance_id)
  VALUES (gen_random_uuid(), p_hayvan_id, 'OVSYNC_BASLAT',
          'Ovsynch-56 başlat (ilk tohumlama hedefi +10 gün)',
          v_hedef, '10:00'::time, false, p_kaynak_ref, v_inst_id)
  RETURNING id INTO v_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_ROUTE_CREATED', p_hayvan_id, v_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', v_gorev_id, 'protokol_instance_id', v_inst_id,
            'kaynak_ref', p_kaynak_ref, 'baslangic', p_baslangic,
            'kural_tarihi', p_kural_tarihi, 'hedef_tarih', v_hedef, 'hedef_saat', '10:00',
            'iptal_edilen_gorev_ids', to_jsonb(v_iptal_gorev),
            'iptal_edilen_instance_ids', to_jsonb(v_iptal_inst))
          || CASE WHEN v_tren IS NOT NULL THEN jsonb_build_object('tren_gunu', v_tren) ELSE '{}'::jsonb END,
          '{}'::jsonb);

  RETURN v_gorev_id;
END;
$function$;

-- 2) _acik_disi_gorev_kur: imza + p_hemen, anahtar R10. 1-arg çağıranlar (hayvan_ekle, ilk_tohumlama_zamanlayici,
--    tohumlama_sonuc_bos, tedavi_sablon_bos_ata_uygula) default ile çözülür.
DROP FUNCTION public._acik_disi_gorev_kur(text);
CREATE FUNCTION public._acik_disi_gorev_kur(p_hayvan_id text, p_hemen boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hedef  date;
  v_kural  date;
  v_taban  date;
  v_dogum  date;
  v_abort  date;
  v_son_toh text;
BEGIN
  v_hedef := public._acik_disi_ovsync_hedef(p_hayvan_id);
  IF v_hedef IS NULL THEN
    RETURN NULL;
  END IF;

  v_kural := public._ovsync_kural_tarihi(p_hayvan_id);

  SELECT max(tarih) INTO v_dogum FROM public.dogum WHERE anne_id = p_hayvan_id;
  SELECT max(abort_tarihi) INTO v_abort FROM public.tohumlama
   WHERE hayvan_id = p_hayvan_id AND sonuc = 'Abort' AND abort_tarihi IS NOT NULL;

  IF v_dogum IS NOT NULL OR v_abort IS NOT NULL THEN
    v_taban := GREATEST(COALESCE(v_dogum, '-infinity'::date),
                        COALESCE(v_abort, '-infinity'::date));
  ELSE
    SELECT dogum_tarihi INTO v_taban FROM public.hayvanlar WHERE id = p_hayvan_id;
  END IF;

  -- D3 / R10 (bayraktan bağımsız hata düzeltmesi): anahtar son tohumlamayı da taşır. Eski 'ACIK-DISI-<h>-<kural>'
  --   biçimi kural günü değişmeyen hayvanda (düve, Boş sonrası) ikinci rotayı ON CONFLICT ile sessizce yutuyordu.
  SELECT t.id::text INTO v_son_toh FROM public.tohumlama t
   WHERE t.hayvan_id = p_hayvan_id
   ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
   LIMIT 1;

  RETURN public._ovsync_baslat_gorev_kur(
    p_hayvan_id, v_taban,
    'ACIK-DISI-' || p_hayvan_id || '-' || v_kural::text || '-' || COALESCE(v_son_toh, '0'), v_kural, p_hemen);
END;
$function$;

-- 3) _acik_disi_hedef_ic: son satır tek hesap noktasına (imza aynı).
CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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

  -- D3 (ovsync treni): tek hesap noktası; tren kapalıyken GREATEST(v_k, bugün_TR) ile birebir.
  RETURN public._ovsync_tren_gunu(v_k);
END;
$function$;

-- 4) ovsync_baslat_uyarilari: görevsiz kol tren penceresi + her satıra tren_gunu, kural_tarihi (imza aynı).
CREATE OR REPLACE FUNCTION public.ovsync_baslat_uyarilari()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH bugun AS (
    SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS d,
           public._ovsync_tren_aktif() AS tren   -- D3 (ovsync treni)
  ), gorevli AS (
    SELECT g.id AS gorev_id, g.hayvan_id, h.kupe_no, COALESCE(h.kategori, h.grup) AS kategori,
           COALESCE(h.kisir, false) AS kisir, g.hedef_tarih, g.hedef_saat,
           g.hedef_tarih + 10 AS tai_tarihi, g.kaynak,
           CASE WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%' THEN 'duve'
                WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'
                WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'
                ELSE 'acik_disi' END AS taban_turu,
           CASE WHEN (SELECT tren FROM bugun) THEN g.hedef_tarih END AS tren_gunu,
           public._ovsync_kural_tarihi(g.hayvan_id) AS kural_tarihi
      FROM public.gorev_log g
      JOIN public.hayvanlar h ON h.id = g.hayvan_id
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= (SELECT d + 2 FROM bugun)
  ), aday AS (
    -- D3: görevsiz uygun açık dişiler (eski gorevsiz kolunun süzgeci); tren açıkken tren günü hesaplanır.
    SELECT a.id, a.kupe_no, a.kategori, a.grup, a.kisir, a.dogum_tarihi, a.kural,
           CASE WHEN (SELECT tren FROM bugun) THEN public._ovsync_tren_gunu(a.kural) END AS tren
      FROM (SELECT h.id, h.kupe_no, h.kategori, h.grup, h.kisir, h.dogum_tarihi,
                   (SELECT public._ovsync_kural_tarihi(h.id)) AS kural
              FROM public.hayvanlar h
             WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi' AND COALESCE(h.kisir, false) = false
               AND public._acik_disi_ovsync_hedef(h.id) IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM public.gorev_log g2
                                WHERE g2.hayvan_id = h.id AND g2.gorev_tipi = 'OVSYNC_BASLAT'
                                  AND COALESCE(g2.tamamlandi, false) = false
                                  AND COALESCE(g2.iptal, false) = false)) a
  ), gorevsiz AS (
    -- C5 (cila2): görev kural günü doğduğu için hedef−2 penceresinde görev
    -- henüz YOK — uyarı 2 gün önceden düşsün diye görevsiz uygun açık dişiler
    -- kural tarihinden listelenir. Başlatma kural günü mümkün olur.
    -- D3 / R8 (ovsync treni): tren açıkken pencere tren−2 ∈ [bugün, bugün+2], hedef = tren, TAI = tren+10
    --   (görev tren−2 günü doğar). Tren kapalı: kural ∈ [bugün, bugün+2], hedef = kural (eski, birebir).
    SELECT NULL::uuid AS gorev_id, a.id AS hayvan_id, a.kupe_no, COALESCE(a.kategori, a.grup) AS kategori,
           COALESCE(a.kisir, false) AS kisir,
           COALESCE(a.tren, a.kural) AS hedef_tarih,
           NULL::time AS hedef_saat,
           COALESCE(a.tren, a.kural) + 10 AS tai_tarihi,
           'ACIK-DISI-ONERI:' || a.id AS kaynak,
           CASE WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = a.id) THEN 'dogum'
                WHEN EXISTS (SELECT 1 FROM public.tohumlama t
                              WHERE t.hayvan_id = a.id AND t.sonuc = 'Abort'
                                AND t.abort_tarihi IS NOT NULL) THEN 'abort'
                WHEN a.dogum_tarihi IS NOT NULL THEN 'duve'
                ELSE 'acik_disi' END AS taban_turu,
           a.tren AS tren_gunu,
           a.kural AS kural_tarihi
      FROM aday a
     WHERE CASE WHEN (SELECT tren FROM bugun)
                THEN a.tren - 2 >= (SELECT d FROM bugun) AND a.tren - 2 <= (SELECT d + 2 FROM bugun)
                ELSE a.kural >= (SELECT d FROM bugun) AND a.kural <= (SELECT d + 2 FROM bugun) END
  )
  SELECT jsonb_build_object(
    'ok', true,
    'uyarilar', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'gorev_id', u.gorev_id,
               'hayvan_id', u.hayvan_id,
               'kupe_no', u.kupe_no,
               'kategori', u.kategori,
               'kisir', u.kisir,
               'hedef_tarih', u.hedef_tarih,
               'hedef_saat', u.hedef_saat,
               'tai_tarihi', u.tai_tarihi,
               'kaynak', u.kaynak,
               'taban_turu', u.taban_turu,
               'tren_gunu', u.tren_gunu,
               'kural_tarihi', u.kural_tarihi)
               ORDER BY u.hedef_tarih, u.hayvan_id)
        FROM (SELECT * FROM gorevli UNION ALL SELECT * FROM gorevsiz) u
    ), '[]'::jsonb)
  );
$function$;

-- 5) protokol_iptal: yeniden başlat çekirdeğe p_hemen => true (G9; imza aynı).
CREATE OR REPLACE FUNCTION public.protokol_iptal(p_vaka_id uuid, p_yeniden_baslat boolean DEFAULT false, p_not text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
        -- D3 / R8 (G9): yeniden başlat kullanıcı iradesi → p_hemen; tren açıkken hedef _ovsync_tren_gunu(kural).
        v_yeni_gorev := public._ovsync_baslat_gorev_kur(
          v_case.animal_id, v_taban,
          'PROTOKOL-IPTAL-' || p_vaka_id::text, v_kural, p_hemen => true);
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

-- 6) tohumlama_bos_ve_devam: OVSYNC dalı p_hemen => true + R10 fail-closed (G7; imza aynı).
CREATE OR REPLACE FUNCTION public.tohumlama_bos_ve_devam(p_tohumlama_id text DEFAULT NULL::text, p_muayene_gorev_id uuid DEFAULT NULL::uuid, p_secim text DEFAULT NULL::text, p_pg_urun text DEFAULT NULL::text, p_pg_doz numeric DEFAULT NULL::numeric, p_gun integer DEFAULT NULL::integer, p_saat time without time zone DEFAULT NULL::time without time zone, p_notlar text DEFAULT NULL::text, p_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
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
    v_yeni_hedef := (((now() AT TIME ZONE 'Europe/Istanbul')::date) + COALESCE(p_gun, 7));

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
    -- D3 / R8 + R10 (G7, ovsync treni): Boş sonrası Ovsync kullanıcı iradesi → p_hemen (tren açıkken hedef tren günü).
    --   Fail-closed: görev kurulamazsa açık OVSYNC_BASLAT varsa onun id'si; yoksa OVSYNC_GOREV_ACILAMADI ve Boş
    --   ataması dahil işlem geri sarılır (eskiden ovsync_gorev_id sessizce NULL dönerdi).
    v_ovsync_id := public._acik_disi_gorev_kur(v_hayvan_id, p_hemen => true);
    IF v_ovsync_id IS NULL THEN
      SELECT g.id INTO v_ovsync_id
        FROM public.gorev_log g
       WHERE g.hayvan_id = v_hayvan_id
         AND g.gorev_tipi = 'OVSYNC_BASLAT'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
       ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
       LIMIT 1;
      IF v_ovsync_id IS NULL THEN
        RAISE EXCEPTION 'OVSYNC_GOREV_ACILAMADI:%',
          jsonb_build_object('hayvan_id', v_hayvan_id,
                             'sebep', CASE WHEN public._acik_disi_ovsync_hedef(v_hayvan_id) IS NULL
                                           THEN 'HEDEF_YOK' ELSE 'KURULAMADI' END)::text;
      END IF;
    END IF;

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

-- ACL (Supabase varsayılan yetkisi anon'a EXECUTE verir). DROP + CREATE edilen iç yardımcılar canlıdaki gibi yalnız
-- service_role'e açık; CREATE OR REPLACE edilen RPC'lerde satırlar tekrarlanır.
REVOKE ALL ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date, boolean) TO service_role;
REVOKE ALL ON FUNCTION public._acik_disi_gorev_kur(text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._acik_disi_gorev_kur(text, boolean) TO service_role;
REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ovsync_baslat_uyarilari() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_baslat_uyarilari() TO authenticated;
REVOKE ALL ON FUNCTION public.protokol_iptal(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protokol_iptal(uuid, boolean, text) TO authenticated;
REVOKE ALL ON FUNCTION public.tohumlama_bos_ve_devam(text, uuid, text, text, numeric, integer, time without time zone, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_bos_ve_devam(text, uuid, text, text, numeric, integer, time without time zone, text, boolean) TO authenticated;
