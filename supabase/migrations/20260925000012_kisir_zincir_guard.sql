-- ============================================================================
-- Migration: 20260925000012_kisir_zincir_guard
-- Tarih: 2026-09-25 · Cila-onarım K3 (mimar incelemesi B1 + B2)
--
-- HATA (B1): dogum_kaydet / tohumlama_abort olay kancaları
--   _ilk_tohumlama_rota_kur → _ovsync_baslat_gorev_kur zinciri üzerinden
--   kısır hayvana bile OVSYNC_BASLAT görevi açabiliyordu (kayıt yalnızca
--   start_first_service_protocol'un KISIR muafiyetiyle kapanıyordu — görev
--   hiç açılmaması gerekirdi). 000001:17-19'daki "kancalar kısır filtresiyle
--   korunur" yorumu bu zincirde karşılıksızdı.
-- ONARIM (B1): guard zincirin EN ALT ORTAK HALKASINDA, tek noktada —
--   _ovsync_baslat_gorev_kur'da: kısır / Aktif değil / Dişi değil → sessiz
--   NULL (bayrak-kapalı deseni). Kancalar ve açık-dişi üretimi
--   (_acik_disi_gorev_kur) aynı çekirdekten beslendiğinden tek nokta yeter.
-- ONARIM (B2): ilk_tohumlama_zamanlayici dry-run `baslatilacaklar` listesi
--   kısır hayvanı artık listelemesin (rapor doğruluğu; gerçek-dal başlatma
--   start_first_service_protocol KISIR S1 muafiyetine zaten yaslanır —
--   gerçek-dal FOR-LOOP'una DOKUNULMAZ).
-- Gövde tabanları: apply-öncesi canlı demo gövdeleri (2026-09-25 çekimi;
--   _ovsync_baslat_gorev_kur = 20260924000001:116 gövdesi,
--   ilk_tohumlama_zamanlayici = 20260925000001:283 gövdesi — birebir).
-- Geri alınabilir: bu taban gövdeler CREATE OR REPLACE ile geri yazılır.
-- ACL'ler yeniden beyan edilir (değişiklik yok); anon/PUBLIC kapalı kalır.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── (a) _ovsync_baslat_gorev_kur: K3 guard (tek nokta) ─────────────────────
CREATE OR REPLACE FUNCTION public._ovsync_baslat_gorev_kur(p_hayvan_id text, p_baslangic date, p_kaynak_ref text, p_kural_tarihi date)
 RETURNS uuid
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_inst_id     uuid;
  v_gorev_id    uuid;
  v_iptal_gorev uuid[];
  v_iptal_inst  uuid[];
  v_hedef       date;
  v_h           record;
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN NULL;
  END IF;

  -- K3 (2026-09-25): kısır/Aktif değil/Dişi değil hayvana zincir görevi AÇILMAZ.
  -- En alt ortak halka: dogum_kaydet/tohumlama_abort kancaları _ilk_tohumlama_rota_kur
  -- sarmalayıcısı üzerinden buraya iner; açık-dişi üretimi (_acik_disi_gorev_kur) de
  -- aynı çekirdeği kullanır. Mimar B1: 000001:17-19 yorumunun düzeltmesi — olay
  -- kancaları artık bu gövdenin guard'ından beslenir. Sessiz NULL (bayrak-kapalı deseni).
  SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
    INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif'
     OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' OR v_h.kisir THEN
    RETURN NULL;
  END IF;

  IF p_hayvan_id IS NULL OR p_baslangic IS NULL OR p_kural_tarihi IS NULL
     OR COALESCE(p_kaynak_ref, '') = '' THEN
    RAISE EXCEPTION 'OVSYNC_BASLAT_PARAMETRE:%', jsonb_build_object(
      'hayvan_id', p_hayvan_id, 'baslangic', p_baslangic,
      'kaynak_ref', p_kaynak_ref, 'kural_tarihi', p_kural_tarihi);
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

  v_hedef := GREATEST(p_kural_tarihi, (now() AT TIME ZONE 'Europe/Istanbul')::date);

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
            'iptal_edilen_instance_ids', to_jsonb(v_iptal_inst)),
          '{}'::jsonb);

  RETURN v_gorev_id;
END;
$fn$;

COMMENT ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date) IS
  'R3.2: OVSYNC_BASLAT görevi + ILK_TOHUMLAMA instance çekirdeği. Hedef = GREATEST(kural, bugün). Bayrak kapalı → NULL. Kısır/Aktif değil/Dişi değil → NULL (K3).';

REVOKE ALL ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date) FROM PUBLIC, anon, authenticated;

-- ── (b) ilk_tohumlama_zamanlayici: dry-run baslatilacaklar kısır filtresi ──
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
       AND NOT COALESCE(h.kisir, false)
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
       AND NOT COALESCE(h.kisir, false)   -- K3 (B2): dry-run raporu kısır hayvanı listelemesin;
                                          -- gerçek-dal başlatma start_first_service_protocol
                                          -- muafiyetlerine (KISIR S1) zaten yaslanır.
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
     AND NOT COALESCE(h.kisir, false)
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
  'R3.2 SK8: yedek zamanlayıcı — (a) açık dişi taraması (cap 200) + (b) hedefi gelen OVSYNC_BASLAT başlatma. p_dry_run: bayraktan bağımsız salt-okuma listeleme. K3 (B2): dry-run baslatilacaklar kısır hayvan içermez.';

REVOKE ALL ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000012_kisir_zincir_guard (K3)
