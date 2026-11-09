-- Migration: Ovsync treni — başlatma yolları ve K8 sunucu tarafı (ovsync treni D4)
-- Tarih: 2026-11-09. Spec docs/plans/2026-11-09-ovsync-tren/design.md (K8, §5 üyelik, §6); PLAN.md D4, R3/R4/R11/R19.
--   Önceki migration: 20261110100003. BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısında.
-- Değişen 3 fonksiyon, gövdeleri prod (kanit/fn) gövdesinden kopyalandı; yalnız "D4" yorumlu satırlar değişti:
--   start_first_service_protocol (DROP + CREATE, + p_bagimsiz; dönüşe ovsync_tren), tedavi_sablon_uygula (OVSYNC şablonunda
--   cases.ovsync_tren), _vaka_ac_tek (oturum saat dilimli bugün → TR günü). Yeni RPC: ovsync_tren_onizle(p_hayvan_id) (K8 modal verisi;
--   sözleşme eki 2026-11-09: kupe_no, kural_tarihi, uye_kupeler).
-- Bayrak (ovsync_tren_aktif) 0 iken davranış eski ile birebir (p_bagimsiz yok sayılır, etiket yazılmaz, ayar okunmaz);
--   R19 gereği bayraktan bağımsız tek düzeltme: _vaka_ac_tek TR tarihi. vaka_toplu_ac ve tedavi_sablon_uygula imzaları DEĞİŞMEZ.
-- D4-EK (root ruling D4 notları, RL-11): TREN yolunda hedefi geçmiş ya da tren günü olmayan görev bugünden itibaren ilk
--   trene bağlanır (R9 formülü, kural günü dahil; tren bugünse başlar, ileride ise iç bayrakla gorev_ertele ile yeniden hedeflenir, basladi:false); TREN
--   yolunda NULL üyelik OVSYNC_TREN_UYELIK_YOK; önizleme gorev_hedef_eski + uye_sayisi = uye_kupeler kümesi.
-- Önkoşul: 3 canlı gövdenin md5'i D0 tabanı (govde-taban.md); değilse <FN>_GOVDE_FARKLI ile durur.
-- Tarih yalnız TR: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ROLLBACK: DROP FUNCTION public.ovsync_tren_onizle(text), public.start_first_service_protocol(uuid,boolean,boolean);
--   üç fonksiyonu kanit/fn/<ad>.sql gövdeleriyle yeniden kur (start: CREATE (uuid,boolean)); ACL'yi geri ver
--   (start/tedavi: authenticated + service_role; _vaka_ac_tek: authenticated + service_role).

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.start_first_service_protocol(uuid,boolean)', '9c7344bbb42e53246f63bcd7999b7525', 'START_FIRST_SERVICE_PROTOCOL_GOVDE_FARKLI'),
    ('public.tedavi_sablon_uygula(uuid,uuid,date,boolean,text)', '7cc9e46508c3f4fab10516a5676d026e', 'TEDAVI_SABLON_UYGULA_GOVDE_FARKLI'),
    ('public._vaka_ac_tek(text,uuid,text,date)', 'f9be42278a02581ade0f55230ea37aee', 'VAKA_AC_TEK_GOVDE_FARKLI')) AS v(imza, md5, kod) LOOP
    IF NOT COALESCE((SELECT md5(p.prosrc) FROM pg_catalog.pg_proc p WHERE p.oid = to_regprocedure(r.imza)) = r.md5, false) THEN
      RAISE EXCEPTION '%: canlı gövde D0 tabanı değil (govde-taban.md: %), D4 durdu', r.kod, r.imza;
    END IF;
  END LOOP;
END $$;

-- 1) start_first_service_protocol: + p_bagimsiz (K8/R4). Eski imza düşer (default'lu ek parametre CREATE OR REPLACE ile
--    overload doğururdu). Cron ilk_tohumlama_zamanlayici (r.id) ve JS (adlandırılmış) çağrıları default ile çözülür.
DROP FUNCTION public.start_first_service_protocol(uuid, boolean);
CREATE FUNCTION public.start_first_service_protocol(p_gorev_id uuid, p_takip_onay boolean DEFAULT false, p_bagimsiz boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g           record;
  v_g2          record;
  v_h           record;
  v_takip       record;
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
  v_bagimsiz     boolean;   -- D4 (K8/R4): tren açık + kullanıcı "bağımsız" seçti
  v_tren         date;      -- D4: vakanın tren etiketi (dönüş alanı)
  v_eski         boolean := false;  -- D4-EK: görev hedefi geçmiş ya da ritim dışı (TREN yolu)
  v_ilk_tren     date;      -- D4-EK: bugünden itibaren ilk tren
  v_ic_onceki    text;      -- D4-EK: iç bayrağın önceki değeri (geri yüklenir)
  v_ayar        jsonb;     -- D4-EK tur 2: tren ayarı (R9)
  v_er          jsonb;     -- D4-EK tur 2: gorev_ertele dönüşü
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RAISE EXCEPTION 'OZELLIK_KAPALI:%', jsonb_build_object(
      'bayrak', 'ovsync_pg_kurallari_aktif', 'gorev_id', p_gorev_id);
  END IF;

  -- ═══ P3b MK9 düzeltmesi (plan.md:424-428; §10f C3): görev KİLİTSİZ okunur;
  -- hızlı retler kilitsiz veriyle aynı sırada. Eski gövde görevi ÖNCE FOR
  -- UPDATE (:44/:53) alıp hayvanı SONRA FOR UPDATE (:62/:82) kilitliyordu —
  -- bilinen tek kurucu MK9 ihlali (sarmal: hayvan→görev; start: görev→hayvan).
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id;
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

  -- D4 (K8/R4): bağımsız başlatma yalnız tren açıkken anlamlıdır; kapalıyken p_bagimsiz yok sayılır (eski davranış).
  v_bagimsiz := COALESCE(p_bagimsiz, false) AND public._ovsync_tren_aktif();
  -- D4-EK (root ruling D4 notları / RL-11): TREN yolunda (açık, bağımsız değil) hedefi geçmiş ya da tren günü olmayan görev
  -- erken-çağrı kapısına takılmaz; bugünden itibaren ilk trene bağlanır (aşağıda, muafiyetlerden sonra).
  IF public._ovsync_tren_aktif() AND NOT v_bagimsiz THEN
    v_eski := COALESCE(v_g.hedef_tarih < v_bugun OR NOT public._ovsync_tren_gunu_mu(v_g.hedef_tarih), false);
  END IF;

  -- K4 (2026-09-26): erken-çağrı kapısı — hedefe 2 günden çok varsa RET.
  -- Pencere hedef−2 gün AÇIK (dahil): v_bugun < hedef-2 → red. T13: gelecek-
  -- hedefli görev sessizce zincir açıyordu (v_s := GREATEST geleceği kabulleniyor).
  IF NOT v_bagimsiz AND NOT v_eski AND v_bugun < v_g.hedef_tarih - 2 THEN   -- D4: bağımsızda, D4-EK: eski hedefte kapı atlanır
    RAISE EXCEPTION 'OVSYNC_ERKEN:%', jsonb_build_object(
      'gorev_id', p_gorev_id,
      'hedef_tarih', v_g.hedef_tarih,
      'kalan_gun', (v_g.hedef_tarih - v_bugun),
      'acilisa_kalan_gun', (v_g.hedef_tarih - v_bugun - 2));
  END IF;

  -- ═══ Hayvan İLK kilit (MK9-N muteks — hayvan satırında ASLA FOR UPDATE:
  -- FK KEY SHARE'i bloklar; eski :62'nin yukarı alınmış + NKU'ye dönüşmüş hali).
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_g.hayvan_id FOR NO KEY UPDATE;

  -- protokol_instance okuması hayvan kilidinden SONRA (vaka/seans katmanı
  -- okuması — kilit değil, alt sıra serbest).
  SELECT baslangic INTO v_olay FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  v_olay := COALESCE(v_olay, v_g.hedef_tarih - 51);

  -- ═══ Görev yeniden kilit + yeniden doğrulama: kilitsiz okuma ile arada
  -- kapanmışsa zaten-kapalı dönüşü; açık kalmışsa v_g2 üzerinden devam.
  SELECT * INTO v_g2 FROM public.gorev_log WHERE id = p_gorev_id FOR NO KEY UPDATE;
  IF v_g2.gorev_tipi IS DISTINCT FROM 'OVSYNC_BASLAT' THEN
    RAISE EXCEPTION 'GOREV_TIPI_UYUMSUZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g2.gorev_tipi);
  END IF;
  IF COALESCE(v_g2.tamamlandi, false) OR COALESCE(v_g2.iptal, false) THEN
    RETURN jsonb_build_object('ok', true, 'zaten', true, 'gorev_id', p_gorev_id,
      'iptal', COALESCE(v_g2.iptal, false), 'kapatan_ref', v_g2.kapatan_ref);
  END IF;

  -- ── Otomatik muafiyetler (SK7 final seti — v_h üzerinden; IF zinciri birebir)
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSIF COALESCE(v_h.kisir, false) THEN
    v_neden := 'KISIR';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu
    SELECT t.sonuc INTO v_son_sonuc FROM public.tohumlama t
     WHERE t.hayvan_id = v_g2.hayvan_id
       ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
       LIMIT 1;
    IF v_son_sonuc = 'Gebe' THEN
      v_neden := 'GEBE';
    ELSIF v_son_sonuc = 'Bekliyor' THEN
      v_neden := 'BEKLIYOR';
    ELSIF EXISTS (SELECT 1 FROM public.cases c
                   WHERE c.animal_id = v_g2.hayvan_id
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
     WHERE id = v_g2.protokol_instance_id AND durum = 'aktif';
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_SKIPPED', v_g2.hayvan_id, p_gorev_id::text, 'gorev_log',
            jsonb_build_object('gorev_id', p_gorev_id, 'neden', v_neden,
              'kaynak', v_g2.kaynak, 'olay_tarihi', v_olay, 'hedef_tarih', v_g2.hedef_tarih),
            '{}'::jsonb);
    RETURN jsonb_build_object('ok', true, 'atlandi', v_neden, 'gorev_id', p_gorev_id);
  END IF;

  -- D4-EK (RL-11 düzeltilmiş): eski hedefli görev → R9 formülüyle ilk tren (kural günü dahil; öne çekme ≤ ayar). Tren bugünse
  -- bugün başlar; ileride ise başlatılmaz, görev iç bayrakla
  -- gorev_ertele üzerinden o güne yeniden hedeflenir (GOREV_ERTELE soyu korunur; OVSYNC_ERKEN değil). Takip kapısı ve
  -- hiçbir yazma bundan önce yok. İç bayrak çağrıdan sonra önceki değerine döner.
  IF v_eski THEN
    v_ayar := public._ovsync_tren_ayar();
    v_ilk_tren := public._ovsync_tren_gunu_ic(GREATEST(public._ovsync_kural_tarihi(v_g2.hayvan_id), v_g2.hedef_tarih),
                    (v_ayar->>'capa')::date, (v_ayar->>'one_cekme')::int, v_bugun);   -- kural NULL → yalnız eski hedef
    IF v_ilk_tren > v_bugun THEN
      v_ic_onceki := current_setting('app.ovsync_tren_ic', true);
      PERFORM public._ovsync_ic_ac();
      v_er := public.gorev_ertele(p_gorev_id, v_ilk_tren);
      PERFORM set_config('app.ovsync_tren_ic', COALESCE(v_ic_onceki, ''), true);
      RETURN jsonb_build_object('ok', true, 'basladi', false, 'gorev_id', p_gorev_id,
                                'yeniden_hedef', (v_er->>'hedef_tarih')::date, 'ovsync_tren', NULL::date);
    END IF;
  END IF;

  -- ═══ P3b takip kapısı (C2 tekil desen; ilk yazmadan ÖNCE — _vaka_ac_tek'in
  -- cases INSERT'i P3a Ovsync tetikleyicisini ateşlemeden kapı burada çalışır;
  -- onaylı → _takip_kapat(neden='OVSYNC') vaka-yolu kapanış sınıfı).
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = v_g2.hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND THEN
    IF NOT COALESCE(p_takip_onay, false) THEN
      RAISE EXCEPTION 'TAKIP_ACIK:%',
        jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                           'muayene_saat', v_takip.hedef_saat)::text;
    END IF;
    PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
  END IF;

  -- ── Başlangıç, şablon, hastalık (birebir) ─────────────────────────────
  -- D4: bağımsız → başlangıç bugün (TR); üyelik tedavi_sablon_uygula içinde D0 tarihinden yazılır (R4).
  v_s := CASE WHEN v_bagimsiz THEN v_bugun WHEN v_eski THEN v_ilk_tren   -- D4-EK: eski hedef → ilk tren (= bugün)
              ELSE GREATEST(v_g2.hedef_tarih, v_bugun) END;

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

  -- ── Atomik zincir (birebir) ────────────────────────────────────────────
  v_res := public._vaka_ac_tek(v_g2.hayvan_id, v_disease_id, 'İlk tohumlama zinciri', v_s);
  IF (v_res->>'ok') IS DISTINCT FROM 'true' OR (v_res->>'case_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_ACILAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'hayvan_id', v_g2.hayvan_id, 'sonuc', v_res);
  END IF;
  v_case_id := (v_res->>'case_id')::uuid;

  UPDATE public.cases
     SET protocol_family = 'OVSYNC'
   WHERE id = v_case_id
     AND protocol_family IS NULL;

  v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                       p_baslangic_tarihi := v_s);
  IF (v_sab->>'ok') IS DISTINCT FROM 'true'
     OR COALESCE((v_sab->>'seans_sayisi')::int, 0) = 0
     OR COALESCE(jsonb_array_length(v_sab->'atlanan'), 0) > 0 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_UYGULANAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_sab);
  END IF;

  -- D4: vakanın tren etiketi (dönüş alanı). D4-EK (root ruling): TREN yolunda (açık, bağımsız değil) üyelik dolu olmalı;
  -- NULL kalırsa fail-closed (sessiz bağımsız vaka yok).
  SELECT c.ovsync_tren INTO v_tren FROM public.cases c WHERE c.id = v_case_id;
  IF public._ovsync_tren_aktif() AND NOT v_bagimsiz AND v_tren IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_TREN_UYELIK_YOK:%', jsonb_build_object('gorev_id', p_gorev_id, 'case_id', v_case_id, 'd0', v_s);
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

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_D58_IPTAL'
     WHERE hayvan_id = v_g2.hayvan_id
       AND kaynak = 'DOGUM-' || v_g2.hayvan_id
       AND gorev_tipi = 'DIGER'
       AND aciklama ILIKE '%kızgınlık takibi%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
       AND hedef_tarih BETWEEN v_olay + 50 AND v_olay + 70
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_d58 FROM u;

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true,
           kapatan_ref = 'ILK_TOH_PROTOKOL_YERINE:' || v_case_id::text
     WHERE hayvan_id = v_g2.hayvan_id
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND kaynak LIKE 'PG_TOHUMLAMA:%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_gorev_iptal FROM u;

  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = 'case:' || v_case_id::text
   WHERE id = p_gorev_id;
  UPDATE public.protokol_instance
     SET durum = 'tamamlandi', kapandi_at = now(), kapandi_sebep = 'case:' || v_case_id::text
   WHERE id = v_g2.protokol_instance_id AND durum = 'aktif';

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_PROTOCOL_STARTED', v_g2.hayvan_id, v_case_id::text, 'cases',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'case_id', v_case_id,
            'sablon_id', v_sablon_id, 'disease_id', v_disease_id,
            'baslangic', v_s, 'olay_tarihi', v_olay, 'kaynak', v_g2.kaynak,
            'tohumlama_gorev_id', v_tai_id,
            'seans_sayisi', (v_sab->>'seans_sayisi')::int,
            'd58_iptal', to_jsonb(v_d58),
            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal)),
          '{}'::jsonb);

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id, 'tohumlama_gorev_id', v_tai_id,
                            'baslangic', v_s, 'd58_iptal', to_jsonb(v_d58),
                            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal),
                            'ovsync_tren', v_tren);   -- D4
END;
$function$;

-- 2) tedavi_sablon_uygula (imza aynı): OVSYNC şablonunda tren üyeliği (R3).
CREATE OR REPLACE FUNCTION public.tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date DEFAULT NULL::date, p_pg_onay boolean DEFAULT NULL::boolean, p_pg_gerekce text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
  v_sablon_hayvan text;
  v_sablon_kupe   text;
  v_sablon_kalem  record;
  v_kapi          jsonb;
  v_bas           date;   -- D4: vakanın D0 günü
  v_tren          date;   -- D4: tren etiketi (R3)
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  -- 000018 (cila2 C1): OVSYNC-aile şablonu kısır hayvana uygulanamaz.
  -- Fail-closed: yumuşak dönüş değil, KISIR_HAYVAN_OVSYNC_YASAK exception.
  PERFORM public._kisir_ovsync_guard(
    v_case.animal_id,
    EXISTS (SELECT 1 FROM public.tedavi_sablonu s
             WHERE s.id = p_sablon_id AND s.protokol_ailesi = 'OVSYNC'));

  -- ── PG kapısı (hizli_uygulama deyimi): İLK yazmadan ÖNCE ──
  SELECT c.animal_id INTO v_sablon_hayvan FROM public.cases c WHERE c.id = p_case_id;
  FOR v_sablon_kalem IN
    SELECT k.stok_id AS stok_id, k.drug_product_id AS drug_product_id
      FROM public.tedavi_sablonu_kalem k
     WHERE k.sablon_id = p_sablon_id
       AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
       AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id))
       AND public._pg_urun_durumu(k.stok_id, k.drug_product_id) = 'PG'
  LOOP
    v_kapi := public._pg_kapi(v_sablon_hayvan, v_sablon_kalem.stok_id, v_sablon_kalem.drug_product_id, COALESCE(p_pg_onay, false));
    IF v_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      SELECT h.kupe_no INTO v_sablon_kupe FROM public.hayvanlar h WHERE h.id = v_sablon_hayvan;
      RAISE EXCEPTION 'PG_KAPI:%:%', v_kapi->>'karar',
        public._pg_kapi_detay(v_kapi, v_sablon_hayvan, v_sablon_kupe);
    END IF;
  END LOOP;

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

  -- D4 (R3/R4): Ovsync treni üyeliği yalnız D0 tarihinden. OVSYNC ailesi şablonda D0 bir tren günüyse (bayrak açık)
  -- ovsync_tren = D0, değilse NULL (bağımsız). Bayrak kapalıyken ayar okunmaz; değer değişmiyorsa satır güncellenmez
  -- (bayrak 0'da ek UPDATE/değişim kaydı doğmaz).
  IF EXISTS (SELECT 1 FROM public.tedavi_sablonu t WHERE t.id = p_sablon_id AND t.protokol_ailesi = 'OVSYNC') THEN
    v_bas  := COALESCE(p_baslangic_tarihi, v_case.start_date);
    v_tren := CASE WHEN public._ovsync_tren_aktif() THEN CASE WHEN public._ovsync_tren_gunu_mu(v_bas) THEN v_bas END END;
    -- D9 (RD9-3a): bayrak açık + etiket NULL → bağımsız işareti (true geri dönmez; işaretli vaka etiket almaz). Bayrak 0'da
    -- işaret değişmez (eski vaka false kalır, R14 açılışta bağlayabilir).
    UPDATE public.cases
       SET ovsync_tren = CASE WHEN ovsync_bagimsiz THEN NULL ELSE v_tren END,
           ovsync_bagimsiz = ovsync_bagimsiz OR (v_tren IS NULL AND public._ovsync_tren_aktif())
     WHERE id = p_case_id AND (ovsync_tren, ovsync_bagimsiz) IS DISTINCT FROM
           (CASE WHEN ovsync_bagimsiz THEN NULL ELSE v_tren END, ovsync_bagimsiz OR (v_tren IS NULL AND public._ovsync_tren_aktif()));
  END IF;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$function$;

-- 3) _vaka_ac_tek (imza aynı): p_tarih NULL → TR bugünü (eski varsayılan oturum saat dilimine bağlıydı; R19).
CREATE OR REPLACE FUNCTION public._vaka_ac_tek(p_hayvan_id text, p_disease_id uuid, p_notes text DEFAULT NULL::text, p_tarih date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_new_id  uuid;
  v_animal  record;
  v_disease record;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_disease FROM public.diseases WHERE id = p_disease_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık kaydı bulunamadı');
  END IF;

  -- Aynı hayvanda aynı hastalıkta zaten aktif vaka var mı?
  IF EXISTS (
    SELECT 1 FROM public.cases
    WHERE animal_id = p_hayvan_id
      AND disease_id = p_disease_id
      AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hayvan için zaten aktif bir ' || v_disease.name || ' vakası mevcut');
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, notes, start_date)
  VALUES (p_hayvan_id, p_disease_id, p_notes, COALESCE(p_tarih, (now() AT TIME ZONE 'Europe/Istanbul')::date))   -- D4: TR günü
  RETURNING id INTO v_new_id;

  -- islem_log: geri alma icin snapshot
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'VAKA_ACILDI',
    p_hayvan_id,
    v_new_id::text,
    'cases',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'cases', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$function$;

-- 4) ovsync_tren_onizle (R11, K8 modal verisi). Kapalı: {ok, aktif:false}. Açık: tren_gunu = hayvanın açık OVSYNC_BASLAT hedefi,
--    yoksa bugünden sonraki ilk tren (öne çekmesiz). D4-EK (root ruling D4 notları): görev hedefi geçmiş ya da tren günü
--    değilse tren_gunu = R9 _ic(GREATEST(kural, hedef), capa, öne_çekme, bugün) ve gorev_hedef_eski = true (start TREN yolu aynı trene bağlar).
--    Üyeler = o güne ovsync_tren'i olan aktif OVSYNC vaka + o güne hedefli açık OVSYNC_BASLAT, sorulan hayvan hariç;
--    uye_sayisi ve uye_kupeler bu tek kümeden (D4-EK; küpe uzunluğu + metin sırası). Sözleşme eki: kupe_no, kural_tarihi.
--    Ayar bozuksa OVSYNC_TREN_AYAR.
CREATE FUNCTION public.ovsync_tren_onizle(p_hayvan_id text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bugun   date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_ayar    jsonb;
  v_gid     uuid;
  v_ghedef  date;
  v_kupe    text;
  v_kural   date;
  v_tren    date;
  v_uye     integer;
  v_kupeler jsonb;
  v_eski    boolean := false;   -- D4-EK
BEGIN
  IF NOT public._ovsync_tren_aktif() THEN
    RETURN jsonb_build_object('ok', true, 'aktif', false);
  END IF;
  v_ayar := public._ovsync_tren_ayar();

  IF p_hayvan_id IS NOT NULL THEN
    SELECT g.id, g.hedef_tarih INTO v_gid, v_ghedef
      FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id AND g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false AND COALESCE(g.iptal, false) = false
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;
    SELECT h.kupe_no INTO v_kupe FROM public.hayvanlar h WHERE h.id = p_hayvan_id;
    v_kural := public._ovsync_kural_tarihi(p_hayvan_id);
  END IF;

  IF v_ghedef IS NOT NULL AND (v_ghedef < v_bugun OR NOT public._ovsync_tren_gunu_mu(v_ghedef)) THEN
    v_eski := true;                                        -- D4-EK: gecikmiş / ritim dışı görev → R9 ilk tren (start ile aynı)
    v_tren := public._ovsync_tren_gunu_ic(GREATEST(v_kural, v_ghedef), (v_ayar->>'capa')::date, (v_ayar->>'one_cekme')::int, v_bugun);
  ELSE
    v_tren := COALESCE(v_ghedef, public._ovsync_tren_gunu_ic(v_bugun, (v_ayar->>'capa')::date, 0, v_bugun));
  END IF;

  WITH uye AS (
    SELECT c.animal_id AS hayvan_id
      FROM public.cases c
     WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC' AND c.ovsync_tren = v_tren
    UNION
    SELECT g.hayvan_id
      FROM public.gorev_log g
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND g.hedef_tarih = v_tren
       AND COALESCE(g.tamamlandi, false) = false AND COALESCE(g.iptal, false) = false
  ), kupe AS (
    SELECT u.hayvan_id, COALESCE(h.kupe_no, u.hayvan_id) AS kupe_no
      FROM uye u LEFT JOIN public.hayvanlar h ON h.id = u.hayvan_id
  )
  SELECT count(*)::int,
         COALESCE(jsonb_agg(k.kupe_no ORDER BY length(k.kupe_no), k.kupe_no, k.hayvan_id), '[]'::jsonb)
    INTO v_uye, v_kupeler
    FROM kupe k
   WHERE p_hayvan_id IS NULL OR k.hayvan_id <> p_hayvan_id;   -- D4-EK: sayı ve küpeler tek küme

  RETURN jsonb_build_object(
    'ok', true, 'aktif', true, 'bugun', v_bugun, 'tren_gunu', v_tren,
    'tren_bugun_mu', v_tren = v_bugun, 'uye_sayisi', v_uye,
    'gorev', CASE WHEN v_gid IS NULL THEN NULL ELSE jsonb_build_object('id', v_gid, 'hedef_tarih', v_ghedef) END,
    'gorev_hedef_eski', v_eski,
    'kupe_no', v_kupe, 'kural_tarihi', v_kural, 'uye_kupeler', v_kupeler);
END;
$function$;

-- ACL (Supabase varsayılan yetkisi anon'a EXECUTE verir). DROP + CREATE edilen start canlıdaki gibi authenticated + service_role
-- (cron postgres/sahip ile çağırır); CREATE OR REPLACE edilen RPC'de satırlar tekrarlanır; _vaka_ac_tek iç yardımcı (çağıranların
-- hepsi SECURITY DEFINER, JS çağırmıyor) → authenticated kapanır, service_role korunur.
REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid, boolean, boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date, boolean, text) TO authenticated;
REVOKE ALL ON FUNCTION public._vaka_ac_tek(text, uuid, text, date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._vaka_ac_tek(text, uuid, text, date) TO service_role;
REVOKE ALL ON FUNCTION public.ovsync_tren_onizle(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_tren_onizle(text) TO authenticated, service_role;
