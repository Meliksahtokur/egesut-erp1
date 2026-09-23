-- ============================================================================
-- Migration: 20260924000002_dryrun_bayrak_bagimsiz
-- Tarih: 2026-09-24
-- Otorite: root promptu §C3 (SAHİP KAPISI 5: "açmadan önce dry-run çıktısını
--          sahibe göster") — prod kapı-5 koşumunda hata bulundu:
--          _acik_disi_ovsync_hedef bayrak KAPALIYken NULL döndüğünden
--          ilk_tohumlama_zamanlayici(p_dry_run:=true) her zaman
--          acilacak_sayisi=0 / duve_tabansiz=0 gösteriyordu. Demo'da fark
--          edilmedi (bayrak açıktı).
--
-- Düzeltme: uygunluk hesabı bayrak-yoksayan iç fonksiyona ayrılır
-- (_acik_disi_hedef_ic); _acik_disi_ovsync_hedef = bayrak kapısı + ic.
-- Zamanlayıcının DRY-RUN dalı ic'yi çağırır (bayraktan bağımsız önizleme);
-- GERÇEK koşum dalı bayrak kapısını korur (yeni iş yaratma MK5 altında kalır).
--
-- ACL: ikisi de iç yardımcı — authenticated'a kapalı. NOTIFY ile biter.
-- ROLLBACK: 20260924000001'deki _acik_disi_ovsync_hedef gövdesine dön,
--   _acik_disi_hedef_ic DROP, zamanlayıcı 000001 gövdesine dön.
-- ============================================================================

CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_h   record;
  v_son text;
  v_k   date;
BEGIN
  -- Bayrak YOKSAYAN uygunluk (dry-run önizleme). Yeni iş yaratmaz.
  SELECT durum, cinsiyet INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' THEN
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

  v_k := public._ovsync_kural_tarihi(p_hayvan_id);
  IF v_k IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN GREATEST(v_k, (now() AT TIME ZONE 'Europe/Istanbul')::date);
END;
$fn$;

COMMENT ON FUNCTION public._acik_disi_hedef_ic(text) IS
  'R3.2 SK7 bayrak-yoksayan uygunluk (yalnız dry-run önizleme; iş yaratmaz).';
REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public._acik_disi_ovsync_hedef(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN NULL;
  END IF;
  RETURN public._acik_disi_hedef_ic(p_hayvan_id);
END;
$fn$;

COMMENT ON FUNCTION public._acik_disi_ovsync_hedef(text) IS
  'R3.2 SK7: açık dişi hedefi. Bayrak kapalı → NULL (MK5). Hesap _acik_disi_hedef_ic.';
REVOKE ALL ON FUNCTION public._acik_disi_ovsync_hedef(text) FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────────────────────────
-- Zamanlayıcı: yalnız DRY-RUN dalı _acik_disi_hedef_ic kullanır (bayrak
-- yoksayan önizleme). Gerçek koşum dalı değişmez (bayrak kapısı MK5).
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.ilk_tohumlama_zamanlayici();

CREATE OR REPLACE FUNCTION public.ilk_tohumlama_zamanlayici(p_dry_run boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  c_limit       constant integer := 200;
  c_tarama_ust  constant integer := 200;   -- taramada açılacak görev üst sınırı
  v_bugun       date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  r             record;
  v_res         jsonb;
  v_islenen     integer := 0;
  v_baslatilan  integer := 0;
  v_atlanan     integer := 0;
  v_zaten       integer := 0;
  v_kalan       integer := 0;
  v_basl_liste  jsonb := '[]'::jsonb;
  v_atl_liste   jsonb := '[]'::jsonb;
  v_hatalar     jsonb := '[]'::jsonb;
  v_ozet        jsonb;
  -- tarama
  v_acilan      integer := 0;
  v_acil_liste  jsonb := '[]'::jsonb;
  v_taranan     integer := 0;
  v_tabansiz    integer := 0;
BEGIN
  -- ── DRY-RUN: bayraktan bağımsız, salt-okuma listesi ──────────────────
  IF p_dry_run THEN
    FOR r IN
      SELECT h.id, h.kupe_no,
             public._ovsync_kural_tarihi(h.id) AS kural
        FROM public.hayvanlar h
       WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
       ORDER BY h.id
       LIMIT 1000
    LOOP
      v_taranan := v_taranan + 1;
      IF r.kural IS NULL THEN
        -- tabansız: uygun olsa bile görev alamaz (rapor). NULL sonucu NOT IN
        -- tuzagina dusmez (IS DISTINCT FROM). (dry-run: bayrak-yoksayan ic)
        IF public._acik_disi_hedef_ic(r.id) IS NULL
           AND NOT EXISTS (SELECT 1 FROM public.gorev_log g
                            WHERE g.hayvan_id = r.id AND g.gorev_tipi = 'OVSYNC_BASLAT'
                              AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
           AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = r.id
                 ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
               IS DISTINCT FROM 'Gebe'
           AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = r.id
                 ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
               IS DISTINCT FROM 'Bekliyor'
           AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = r.id
                            AND c.status='active' AND c.protocol_family IS NOT NULL) THEN
          v_tabansiz := v_tabansiz + 1;
        END IF;
      ELSIF public._acik_disi_hedef_ic(r.id) IS NOT NULL THEN
        v_acilan := v_acilan + 1;
        IF v_acilan <= c_tarama_ust THEN
          v_acil_liste := v_acil_liste || jsonb_build_array(jsonb_build_object(
            'hayvan_id', r.id, 'kupe_no', r.kupe_no,
            'kural_tarihi', r.kural,
            'hedef_tarih', GREATEST(r.kural, v_bugun)));
        END IF;
      END IF;
    END LOOP;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gorev_id', g.id, 'hayvan_id', g.hayvan_id, 'kupe_no', h.kupe_no,
             'hedef_tarih', g.hedef_tarih, 'kaynak', g.kaynak) ORDER BY g.hedef_tarih DESC, g.id),
           '[]'::jsonb)
      INTO v_basl_liste
      FROM public.gorev_log g
      JOIN public.hayvanlar h ON h.id = g.hayvan_id
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= v_bugun
       LIMIT c_limit;

    RETURN jsonb_build_object(
      'ok', true, 'dry_run', true, 'tarih', v_bugun,
      'taranan', v_taranan, 'acilacak_sayisi', v_acilan,
      'acilacaklar', v_acil_liste, 'acilacak_listesi_kesildi', v_acilan > c_tarama_ust,
      'duve_tabansiz', v_tabansiz,
      'baslatilacak_sayisi', jsonb_array_length(v_basl_liste),
      'baslatilacaklar', v_basl_liste);
  END IF;

  IF NOT public._ovsync_pg_aktif() THEN
    RETURN jsonb_build_object('ok', true, 'atlandi', 'KAPALI');
  END IF;

  -- ── (b) hedefi gelen görevleri başlat (önce; bu koşumun taraması aynı
  --       koşumda başlatılmaz — kural: tarama yeni görev açar, başlatma
  --       bir sonraki koşumda/farklı kaynakta) ────────────────────────────
  FOR r IN
    SELECT g.id, g.hayvan_id, g.hedef_tarih
      FROM public.gorev_log g
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= v_bugun
     ORDER BY g.hedef_tarih DESC, g.id
     LIMIT c_limit
  LOOP
    v_islenen := v_islenen + 1;
    BEGIN
      v_res := public.start_first_service_protocol(r.id);
      IF v_res ? 'atlandi' THEN
        v_atlanan := v_atlanan + 1;
        v_atl_liste := v_atl_liste || jsonb_build_array(jsonb_build_object(
          'gorev_id', r.id, 'hayvan_id', r.hayvan_id, 'neden', v_res->>'atlandi'));
      ELSIF COALESCE((v_res->>'zaten')::boolean, false) THEN
        v_zaten := v_zaten + 1;
      ELSE
        v_baslatilan := v_baslatilan + 1;
        v_basl_liste := v_basl_liste || jsonb_build_array(jsonb_build_object(
          'gorev_id', r.id, 'hayvan_id', r.hayvan_id, 'case_id', v_res->'case_id',
          'tohumlama_gorev_id', v_res->'tohumlama_gorev_id'));
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
        'gorev_id', r.id, 'hayvan_id', r.hayvan_id, 'hedef_tarih', r.hedef_tarih,
        'sqlstate', SQLSTATE, 'mesaj', SQLERRM));
    END;
  END LOOP;

  IF v_islenen = c_limit THEN
    SELECT count(*) - c_limit INTO v_kalan
    FROM public.gorev_log g
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= v_bugun;
    v_kalan := GREATEST(v_kalan, 0);
  END IF;

  -- ── (a) açık dişi taraması: görevi eksik her uygun hayvana görev aç ──
  FOR r IN
    SELECT h.id, h.kupe_no
      FROM public.hayvanlar h
     WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
     ORDER BY h.id
     LIMIT 1000
  LOOP
    v_taranan := v_taranan + 1;
    EXIT WHEN v_acilan >= c_tarama_ust;
    IF public._acik_disi_ovsync_hedef(r.id) IS NOT NULL THEN
      BEGIN
        IF public._acik_disi_gorev_kur(r.id) IS NOT NULL THEN
          v_acilan := v_acilan + 1;
          v_acil_liste := v_acil_liste || jsonb_build_array(jsonb_build_object(
            'hayvan_id', r.id, 'kupe_no', r.kupe_no));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
          'tarama', true, 'hayvan_id', r.id, 'kupe_no', r.kupe_no,
          'sqlstate', SQLSTATE, 'mesaj', SQLERRM));
      END;
    END IF;
  END LOOP;

  -- Tabansız düve sayısı (rapor; sessiz kalmasın)
  SELECT count(*) INTO v_tabansiz
    FROM public.hayvanlar h
   WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
     AND public._ovsync_kural_tarihi(h.id) IS NULL
     AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = h.id
           ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
         IS DISTINCT FROM 'Gebe'
     AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = h.id
           ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
         IS DISTINCT FROM 'Bekliyor'
     AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = h.id
                      AND c.status = 'active' AND c.protocol_family IS NOT NULL)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = h.id
                      AND g.gorev_tipi = 'OVSYNC_BASLAT'
                      AND COALESCE(g.tamamlandi, false) = false
                      AND COALESCE(g.iptal, false) = false);

  v_ozet := jsonb_build_object(
    'ok', jsonb_array_length(v_hatalar) = 0,
    'tarih', v_bugun, 'limit', c_limit, 'islenen', v_islenen,
    'baslatilan', v_baslatilan, 'atlanan', v_atlanan, 'zaten', v_zaten,
    'hata_sayisi', jsonb_array_length(v_hatalar), 'kalan', v_kalan,
    'taranan', v_taranan, 'tarama_acilan', v_acilan, 'duve_tabansiz', v_tabansiz,
    'acilanlar', v_acil_liste,
    'baslatilanlar', v_basl_liste, 'atlananlar', v_atl_liste, 'hatalar', v_hatalar);

  IF v_islenen > 0 OR v_acilan > 0 THEN
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_CRON', NULL, NULL, 'gorev_log', v_ozet, '{}'::jsonb);
  END IF;

  RETURN v_ozet;
END;
$fn$;

COMMENT ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) IS
  'R3.2 SK8: yedek zamanlayıcı — (a) açık dişi taraması (cap 200) + (b) hedefi gelen OVSYNC_BASLAT başlatma. p_dry_run: bayraktan bağımsız salt-okuma listeleme.';

REVOKE ALL ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) TO authenticated, service_role;


NOTIFY pgrst, 'reload schema';

-- EOF 20260924000002
