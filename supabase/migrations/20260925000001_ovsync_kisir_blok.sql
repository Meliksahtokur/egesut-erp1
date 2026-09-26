-- ============================================================================
-- Migration: 20260925000001_ovsync_kisir_blok
-- Tarih: 2026-09-25
-- SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s1.md (sahip kararları bağlayıcı)
-- Amaç: kisir=true hayvanda ovsync üretim/başlatma bloğu (M1 uygunluk + M2
--       Başlat muafiyeti + M3 dry-run rapor doğruluğu + U1 RPC kisir alanı).
-- Kapsam: yalnız bu dört fonksiyon; şema/privilej değişikliği yok; anon GRANT yok.
-- Kırılganlık: gövdeler 20260924000001/20260924000002 repo bloklarının birebir
--   kopyası + plan diff'leri (spec §6). Imzalar değişmez, DROP yok.
-- ROLLBACK (spec §9): dört gövdenin kisir-öncesi halleri repo migration'larında
--   (_ic → 20260924000002:L21-73; start_first → 20260924000001:L662-851;
--    zamanlayıcı → 20260924000002:L99-301; uyarılar → 20260924000001:L1089-1126);
--   tek transaction'da CREATE OR REPLACE ile geri yazılır; veri taşınmadı.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- M1 — _acik_disi_hedef_ic: kısır kontrolü Aktif/Dişi kontrolünün hemen ardından
-- (tek uygunluk noktası; gerçek üretim + dry-run önizleme + olay kancaları
--  bu gövdeden beslenir — spec §4.1)
-- ─────────────────────────────────────────────────────────────────────────────
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

  v_k := public._ovsync_kural_tarihi(p_hayvan_id);
  IF v_k IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN GREATEST(v_k, (now() AT TIME ZONE 'Europe/Istanbul')::date);
END;
$fn$;

COMMENT ON FUNCTION public._acik_disi_hedef_ic(text) IS
  'R3.2 SK7 bayrak-yoksayan uygunluk (yalnız dry-run önizleme; iş yaratmaz). Muaf: kısır, Aktif değil/Dişi değil, Gebe/Bekliyor, aktif senkronizasyon vakası, açık OVSYNC_BASLAT, tabansız.';
REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────────────────────────
-- M2 — start_first_service_protocol: KISIR muafiyeti ELSIF'i (AKTIF_DEGIL'den
-- sonra, MK3 GEBE/BEKLIYOR/AKTIF_SENKRON'dan ÖNCE — spec §4.2 sıra kararı)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.start_first_service_protocol(p_gorev_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_g           record;
  v_h           record;
  v_olay        date;
  v_neden       text;
  v_son_sonuc   text;
  v_bugun       date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_s           date;
  v_sablon_id   uuid;
  v_disease_id  uuid;
  v_n           integer;
  v_res         jsonb;
  v_sab         jsonb;
  v_top         jsonb;
  v_case_id     uuid;
  v_tai_id      uuid;
  v_d58         uuid[];
  v_pg_gorev_iptal uuid[];
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RAISE EXCEPTION 'OZELLIK_KAPALI:%', jsonb_build_object(
      'bayrak', 'ovsync_pg_kurallari_aktif', 'gorev_id', p_gorev_id);
  END IF;

  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_BULUNAMADI:%', jsonb_build_object('gorev_id', p_gorev_id);
  END IF;
  IF v_g.gorev_tipi IS DISTINCT FROM 'OVSYNC_BASLAT' THEN
    RAISE EXCEPTION 'GOREV_TIPI_UYUMSUZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RETURN jsonb_build_object('ok', true, 'zaten', true, 'gorev_id', p_gorev_id,
      'iptal', COALESCE(v_g.iptal, false), 'kapatan_ref', v_g.kapatan_ref);
  END IF;

  -- Olay tarihi = rota instance başlangıcı (yoksa hedef − 51, SK6)
  SELECT baslangic INTO v_olay FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  v_olay := COALESCE(v_olay, v_g.hedef_tarih - 51);

  -- ── Otomatik muafiyetler (SK7 final seti) ─────────────────────────────
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_g.hayvan_id FOR UPDATE;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSIF COALESCE(v_h.kisir, false) THEN
    v_neden := 'KISIR';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu
    SELECT t.sonuc INTO v_son_sonuc FROM public.tohumlama t
     WHERE t.hayvan_id = v_g.hayvan_id
       ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
       LIMIT 1;
    IF v_son_sonuc = 'Gebe' THEN
      v_neden := 'GEBE';
    ELSIF v_son_sonuc = 'Bekliyor' THEN
      v_neden := 'BEKLIYOR';
    ELSIF EXISTS (SELECT 1 FROM public.cases c
                   WHERE c.animal_id = v_g.hayvan_id
                     AND c.status = 'active'
                     AND c.protocol_family IS NOT NULL) THEN
      v_neden := 'AKTIF_SENKRONIZASYON';
    END IF;
  END IF;

  IF v_neden IS NOT NULL THEN
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = p_gorev_id;
    UPDATE public.protokol_instance
       SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = v_g.protokol_instance_id AND durum = 'aktif';
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_SKIPPED', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
            jsonb_build_object('gorev_id', p_gorev_id, 'neden', v_neden,
              'kaynak', v_g.kaynak, 'olay_tarihi', v_olay, 'hedef_tarih', v_g.hedef_tarih),
            '{}'::jsonb);
    RETURN jsonb_build_object('ok', true, 'atlandi', v_neden, 'gorev_id', p_gorev_id);
  END IF;

  -- ── Başlangıç, şablon, hastalık ───────────────────────────────────────
  v_s := GREATEST(v_g.hedef_tarih, v_bugun);

  SELECT count(*), (array_agg(id))[1] INTO v_n, v_sablon_id
    FROM public.tedavi_sablonu
   WHERE protokol_ailesi = 'OVSYNC' AND aktif IS TRUE;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'aktif_ovsync_sablon_sayisi', v_n);
  END IF;

  SELECT count(DISTINCT disease_id), (array_agg(DISTINCT disease_id))[1] INTO v_n, v_disease_id
    FROM public.sablon_hastalik_eslem
   WHERE sablon_id = v_sablon_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_HASTALIK_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sablon_id', v_sablon_id, 'hastalik_sayisi', v_n);
  END IF;

  -- ── Atomik zincir ──────────────────────────────────────────────────────
  v_res := public._vaka_ac_tek(v_g.hayvan_id, v_disease_id, 'İlk tohumlama zinciri', v_s);
  IF (v_res->>'ok') IS DISTINCT FROM 'true' OR (v_res->>'case_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_ACILAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'hayvan_id', v_g.hayvan_id, 'sonuc', v_res);
  END IF;
  v_case_id := (v_res->>'case_id')::uuid;

  v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                       p_baslangic_tarihi := v_s);
  IF (v_sab->>'ok') IS DISTINCT FROM 'true'
     OR COALESCE((v_sab->>'seans_sayisi')::int, 0) = 0
     OR COALESCE(jsonb_array_length(v_sab->'atlanan'), 0) > 0 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_UYGULANAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_sab);
  END IF;

  v_top := public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                                     p_baslangic_tarihi := v_s);
  IF (v_top->>'ok') IS DISTINCT FROM 'true'
     OR (v_top->>'olustu') IS DISTINCT FROM 'true'
     OR (v_top->>'gorev_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_TAI_OLUSMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_top);
  END IF;
  v_tai_id := (v_top->>'gorev_id')::uuid;

  -- ── SK4: doğum protokolünün 58. gün kızgınlık takibi iptal (53. gün E-vit kalır)
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_D58_IPTAL'
     WHERE hayvan_id = v_g.hayvan_id
       AND kaynak = 'DOGUM-' || v_g.hayvan_id
       AND gorev_tipi = 'DIGER'
       AND aciklama ILIKE '%kızgınlık takibi%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
       AND hedef_tarih BETWEEN v_olay + 50 AND v_olay + 70
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_d58 FROM u;

  -- ── R3.1: tek açık TAI kartı — açık PG sonrası görevleri iptal et
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true,
           kapatan_ref = 'ILK_TOH_PROTOKOL_YERINE:' || v_case_id::text
     WHERE hayvan_id = v_g.hayvan_id
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND kaynak LIKE 'PG_TOHUMLAMA:%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_gorev_iptal FROM u;

  -- ── Görev ve rota kapanışı + audit ───────────────────────────────────
  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = 'case:' || v_case_id::text
   WHERE id = p_gorev_id;
  UPDATE public.protokol_instance
     SET durum = 'tamamlandi', kapandi_at = now(), kapandi_sebep = 'case:' || v_case_id::text
   WHERE id = v_g.protokol_instance_id AND durum = 'aktif';

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_PROTOCOL_STARTED', v_g.hayvan_id, v_case_id::text, 'cases',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'case_id', v_case_id,
            'sablon_id', v_sablon_id, 'disease_id', v_disease_id,
            'baslangic', v_s, 'olay_tarihi', v_olay, 'kaynak', v_g.kaynak,
            'tohumlama_gorev_id', v_tai_id,
            'seans_sayisi', (v_sab->>'seans_sayisi')::int,
            'd58_iptal', to_jsonb(v_d58),
            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal)),
          '{}'::jsonb);

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id, 'tohumlama_gorev_id', v_tai_id,
                            'baslangic', v_s, 'd58_iptal', to_jsonb(v_d58),
                            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal));
END;
$fn$;

COMMENT ON FUNCTION public.start_first_service_protocol(uuid) IS
  'R3.2: açık OVSYNC_BASLAT görevinden atomik Ovsync zinciri. Muafiyetler: AKTIF_DEGIL/KISIR/GEBE/BEKLIYOR/AKTIF_SENKRONIZASYON (TOHUMLAMA_VAR kalktı, SK7; KISIR S1).';

REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- M3 — ilk_tohumlama_zamanlayici: dry-run tarama SELECT'i + gerçek-dal
-- duve_tabansiz sayacı kisir filtresi (rapor doğruluğu; gerçek-dal tarama
-- SELECT'i bilinçli filtrelenmez — davranışı _ic NULL'u taşır, spec §6.3)
-- ─────────────────────────────────────────────────────────────────────────────
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
  'R3.2 SK8: yedek zamanlayıcı — (a) açık dişi taraması (cap 200) + (b) hedefi gelen OVSYNC_BASLAT başlatma. p_dry_run: bayraktan bağımsız salt-okuma listeleme.';

REVOKE ALL ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- U1 — ovsync_baslat_uyarilari: dönüşe 'kisir' alanı (UI kilidi veri zemini;
-- frontend ek sorgu yapmaz — spec §4.4)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ovsync_baslat_uyarilari()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'ok', true,
    'uyarilar', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'gorev_id', g.id,
               'hayvan_id', g.hayvan_id,
               'kupe_no', h.kupe_no,
               'kategori', COALESCE(h.kategori, h.grup),
               'kisir', COALESCE(h.kisir, false),
               'hedef_tarih', g.hedef_tarih,
               'hedef_saat', g.hedef_saat,
               'tai_tarihi', g.hedef_tarih + 10,
               'kaynak', g.kaynak,
               'taban_turu', CASE WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%' THEN 'duve'
                                  WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'
                                  WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'
                                  ELSE 'acik_disi' END)
               ORDER BY g.hedef_tarih, g.id)
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND g.hedef_tarih <= ((now() AT TIME ZONE 'Europe/Istanbul')::date + 2)
    ), '[]'::jsonb)
  );
$fn$;

COMMENT ON FUNCTION public.ovsync_baslat_uyarilari() IS
  'R3.2 SK9: hedef−2 günden itibaren açık OVSYNC_BASLAT görevleri (protokol uyarıları ekranı verisi). S1: kisir alanı eklendi (UI kilidi için). Salt-okuma.';
REVOKE ALL ON FUNCTION public.ovsync_baslat_uyarilari() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_baslat_uyarilari() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

-- EOF 20260925000001
