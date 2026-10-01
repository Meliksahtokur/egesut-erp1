-- ============================================================================
-- 20261001000001_takip_yerel_gun_duzeltme (P12b / HATA-2 — impl-P12b-GOREV)
--
-- BUG: 4 yazma noktası hedef tarihleri CURRENT_DATE (sunucu oturumu TZ=UTC)
-- ile hesaplıyordu; TR 00:00–08:00 arası yapılan işlemler bir gün geride
-- KALICI yazılıyor [OBSERVED canlı: 10-08 beklenirken 10-07].
-- FIX: etkilenen fonksiyon gövdelerinde Europe/Istanbul yerel takvim günü:
--   ((now() AT TIME ZONE 'Europe/Istanbul')::date + p_gun) kalıbı.
--
-- Etkilenen 4 gövde (canlıyla birebir pariteli kaynak; tek fark TZ deseni):
--   1. _takip_gorev_kur(uuid,text,int,time)            [20260929000002:119]
--      takip görevi hedef_tarih = kurulum günü + p_gun
--   2. tohumlama_bos_ve_devam(text,uuid,...) ERTALE    [20260929000002:808]
--      v_yeni_hedef = gün + COALESCE(p_gun,7)
--   3. vaka_toplu_ac(...) geçmiş-tarih guard           [20260929000003:1457]
--      p_tarih < yerel bugün reddi
--   4. kizginlik_vaka_ac(text,text,text,text,boolean)  [20260929000003:1987]
--      cases.start_date = yerel bugün
--
-- KASITLI OLARAK DOKUNULMAZ: 20260929000001 (ovsync_takip_listele) CURRENT_DATE'leri —
-- kaynak fonksiyon paritesi T-45 gereği kasıtlı (migration kendi yorumu :16, :206);
-- okuma penceresi gece ±1'i geçici görünümdür, kalıcı veri yazmaz.
--
-- Disiplin: ACL + imza DEĞİŞMEZ (her gövde için kaynak migration'ın REVOKE/GRANT
-- satırları aynen yeniden onaylanır — CREATE OR REPLACE şablonu); anon GRANT YOK
-- (2026-09-14 lockdown sonrası şablon). PROD yok (sahip kapısı).
--
-- Revert (sahip kapısıyla): 4 gövdeyi 20260929000002 / 20260929000003'teki
-- mevcut tanımlarla CREATE OR REPLACE ile geri yaz.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) _takip_gorev_kur — takip görevi hedef_tarih (yerel gün) ──────────
CREATE OR REPLACE FUNCTION public._takip_gorev_kur(
  p_hayvan_id     uuid,
  p_tohumlama_id  text,
  p_gun           int,
  p_saat          time
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev record;
  v_id    uuid;
BEGIN
  -- Guard 1: hayvan var mı (hayvanlar.id text; param uuid → ::text).
  IF NOT EXISTS (SELECT 1 FROM public.hayvanlar WHERE id = p_hayvan_id::text) THEN
    RAISE EXCEPTION 'TAKIP_HAYVAN_YOK';
  END IF;

  -- Guard 2: açık TAKIP_MUAYENE var mı — P1 takiptekiler kümesiyle birebir koşul
  -- (gorev_tipi + !tamamlandi + !iptal; 20260929000001:288-294).
  SELECT g.id, g.hedef_tarih, g.hedef_saat
    INTO v_gorev
    FROM public.gorev_log g
   WHERE g.hayvan_id = p_hayvan_id::text
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND THEN
    RAISE EXCEPTION 'TAKIP_ACIK:ZATEN_ACIK:%',
      jsonb_build_object(
        'gorev_id',    v_gorev.id,
        'hedef_tarih', v_gorev.hedef_tarih,
        'hedef_saat',  v_gorev.hedef_saat
      )::text;
  END IF;

  -- Kurulum. MK9-N: hayvan kilidi çağıran RPC sarmalına aittir (yukarıdaki
  -- sözleşme) — bu gövde kilitlemez. farm_id damgası YOK (D8): kolon ölçülmedi.
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat,
     tamamlandi, iptal, kaynak, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id::text, 'TAKIP_MUAYENE',
     'Takip muayenesi', (((now() AT TIME ZONE 'Europe/Istanbul')::date) + p_gun), p_saat,
     false, false, 'TAKIP:' || p_tohumlama_id, p_tohumlama_id)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;

-- ── 2) tohumlama_bos_ve_devam — ERTALE v_yeni_hedef (yerel gün) ─────────
CREATE OR REPLACE FUNCTION public.tohumlama_bos_ve_devam(
  p_tohumlama_id      text    DEFAULT NULL,
  p_muayene_gorev_id  uuid    DEFAULT NULL,
  p_secim             text    DEFAULT NULL,
  p_pg_urun           text    DEFAULT NULL,
  p_pg_doz            numeric DEFAULT NULL,
  p_gun               int     DEFAULT NULL,
  p_saat              time    DEFAULT NULL,
  p_notlar            text    DEFAULT NULL,
  p_onay              bool    DEFAULT false
)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE
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
    v_ovsync_id := public._acik_disi_gorev_kur(v_hayvan_id);

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

-- ── 3) vaka_toplu_ac — geçmiş-tarih guard (yerel gün) ───────────────────
CREATE OR REPLACE FUNCTION public.vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_items jsonb DEFAULT NULL::jsonb, p_sablon_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text, p_tarih date DEFAULT NULL::date, p_tohumlama boolean DEFAULT false, p_tohumlama_gun_offset integer DEFAULT 0, p_tohumlama_saat text DEFAULT NULL::text, p_tohumlama_cakisma text DEFAULT 'ekle'::text, p_takip_onaylar text[] DEFAULT '{}'::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_list          text[] := ARRAY[]::text[];
  v_seen          text[] := ARRAY[]::text[];
  v_id            text;
  v_toplam        int;
  v_basari        int := 0;
  v_acilan        jsonb := '[]'::jsonb;
  v_atlanan       jsonb := '[]'::jsonb;
  v_hatalar       jsonb := '[]'::jsonb;
  v_kupe          text;
  v_res           jsonb;
  v_r             jsonb;
  v_case_id       uuid;
  v_sab           jsonb;
  v_sab_obj       jsonb;
  v_manuel_obj    jsonb;
  v_top           jsonb;
  v_ok            boolean;
  v_tohumlama_var boolean;
  v_tohu_ekle_var boolean;
  v_start_date    date;
  v_tohu_tarih    date;
  v_tohu_res      jsonb;
  v_tohu_obj      jsonb;
  v_sess          jsonb;
  v_item          jsonb;
  v_idx           int;
  v_day           jsonb;
  v_days_sorted   jsonb;
  v_dup_gun       int;
  v_gun_sayisi    int;
  v_seans_toplam  int;
  v_err_gun       int;
  v_cakisma       jsonb;
  v_uzerine       jsonb;
  v_c             record;
  -- [P3b D4] takip satır-sonucu desen (bulk_ilac ile aynı; §10h H5)
  v_takip            record;
  v_takip_map        jsonb := '{}'::jsonb;  -- onaylı açık-takipliler: hayvan_id → gorev_id
  v_takip_islenenmez text[] := '{}'::text[];-- İŞLENMEYECEK hayvan id'leri
  v_takip_acik_list  jsonb := '[]'::jsonb;  -- satır sonucu TAKIP_ACIK satırları
BEGIN
  IF p_animal_ids IS NULL OR array_length(p_animal_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan listesi boş');
  END IF;
  IF array_length(p_animal_ids, 1) > 200 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'En fazla 200 hayvan');
  END IF;

  -- V1.1: şablon ile manuel ilaç listesi karşılıklı dışlanır
  IF p_items IS NOT NULL AND p_sablon_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Şablon ve manuel ilaç listesi aynı anda verilemez');
  END IF;

  -- V1.2: p_tarih = planlanan başlangıç. NULL → bugün; geçmiş reddedilir
  -- (fail-fast — hiç vaka açılmadan).
  IF p_tarih IS NOT NULL AND p_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçmiş tarih planlanamaz');
  END IF;

  -- V1.2: tohumlama parametreleri (fail-fast)
  IF p_tohumlama_gun_offset IS NULL
     OR p_tohumlama_gun_offset < 0 OR p_tohumlama_gun_offset > 365 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Tohumlama gün ofseti 0-365 aralığında olmalı');
  END IF;
  IF p_tohumlama_saat IS NOT NULL
     AND p_tohumlama_saat !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz saat');
  END IF;

  -- V2.2: çakışma modu (fail-fast — hiç vaka açılmadan). DEFAULT 'ekle'
  -- mevcut davranışı korur; mod p_tohumlama=false iken etki etmez.
  IF p_tohumlama_cakisma IS NULL OR
     p_tohumlama_cakisma NOT IN ('ekle', 'uzerine_yaz', 'atla') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz çakışma modu');
  END IF;

  -- V2: p_items doğrulama + motor biçimine normalize (fail-fast — henüz
  -- hiç vaka açılmadan döner). p_items artık GÜN objeleri dizisidir:
  -- [{gun, saat?, kalemler:[...]}]. Her kalem V1.1 kalem kontrollerinden
  -- geçer (mesajlar aynen, index '<gün>.<kalem>'); kalem saati motor için
  -- zorunlu planned_time'a COALESCE(kalem.saat, gün.saat, '09:00') ile
  -- çevrilir (treatment_day_uygulamalar.planned_time NOT NULL,
  -- 20260611000001). DÜZ (V1.1) dizi şekli kabul edilmez: gun anahtarı
  -- olmayan ilk eleman 'Geçersiz plan: gün 1..31' ile düşer.
  IF p_items IS NOT NULL THEN
    IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj',
        'Geçersiz plan: boş olmayan bir jsonb dizisi bekleniyor');
    END IF;
    FOR v_day, v_idx IN
      SELECT value, ord - 1
      FROM pg_catalog.jsonb_array_elements(p_items) WITH ORDINALITY AS t(value, ord)
    LOOP
      IF jsonb_typeof(v_day) IS DISTINCT FROM 'object' THEN
        RETURN jsonb_build_object('ok', false, 'mesaj',
          'Geçersiz plan: ' || v_idx || ': gün elemanı obje olmalı');
      END IF;
      -- gun: JSON sayısı ve tam sayı yazımı, 1..31 (düz V1.1 kalemleri burada
      -- düşer — gun anahtarı yok)
      IF COALESCE(jsonb_typeof(v_day->'gun'), '') <> 'number'
         OR (v_day->>'gun') !~ '^[0-9]+$'
         OR (v_day->>'gun')::numeric < 1
         OR (v_day->>'gun')::numeric > 31 THEN
        RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz plan: gün 1..31');
      END IF;
      IF v_day->>'saat' IS NOT NULL
         AND (v_day->>'saat') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
        RETURN jsonb_build_object('ok', false, 'mesaj',
          'Geçersiz plan: gün ' || (v_day->>'gun') || ': saat');
      END IF;
      IF COALESCE(jsonb_typeof(v_day->'kalemler'), '') <> 'array'
         OR jsonb_array_length(v_day->'kalemler') < 1 THEN
        RETURN jsonb_build_object('ok', false, 'mesaj',
          'Geçersiz plan: Gün ' || (v_day->>'gun') || ' kalemleri boş');
      END IF;
      -- V1.1 kalem kontrolleri — mesajlar aynen, index '<gün>.<kalem>'
      -- (kalem 1 tabanlı); kalem saati V2 üslubuyla denetlenir
      FOR v_item, v_idx IN
        SELECT value, ord
        FROM pg_catalog.jsonb_array_elements(v_day->'kalemler') WITH ORDINALITY AS t(value, ord)
      LOOP
        IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': dizi elemanı obje olmalı');
        END IF;
        IF COALESCE(v_item->>'drug_product_id', '') = '' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': drug_product_id zorunlu (uuid)');
        END IF;
        IF (v_item->>'drug_product_id') !~*
            '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': drug_product_id geçerli bir uuid değil');
        END IF;
        IF COALESCE(v_item->>'stok_id', '') = '' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': stok_id zorunlu');
        END IF;
        IF v_item->>'dose' IS NULL
           OR (v_item->>'dose') !~ '^[0-9]+([.][0-9]+)?$'
           OR (v_item->>'dose')::numeric <= 0 THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': dose pozitif sayısal olmalı (dose > 0)');
        END IF;
        IF COALESCE(v_item->>'unit', '') = '' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz ilaç kalemi: ' || (v_day->>'gun') || '.' || v_idx ||
            ': unit zorunlu');
        END IF;
        IF v_item->>'saat' IS NOT NULL
           AND (v_item->>'saat') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
          RETURN jsonb_build_object('ok', false, 'mesaj',
            'Geçersiz plan: gün ' || (v_day->>'gun') || ' kalem ' || v_idx || ': saat');
        END IF;
      END LOOP;
    END LOOP;
    -- Günler dizide tekil olmalı (buraya gelindiğinde tüm gun değerleri
    -- 1..31 aralığında geçerli tam sayılar)
    SELECT min(g)
      INTO v_dup_gun
      FROM (
        SELECT (d->>'gun')::int AS g
        FROM pg_catalog.jsonb_array_elements(p_items) d
        GROUP BY 1
        HAVING count(*) > 1
      ) t;
    IF v_dup_gun IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'mesaj',
        'Geçersiz plan: gün ' || v_dup_gun || ' tekrar ediyor');
    END IF;
    -- Yürütme planı (bir kez, döngü dışında): günler gun ASC sıralanır,
    -- her günün seans dizisi kurulur — kalem başına planned_time :=
    -- COALESCE(kalem.saat, gün.saat, '09:00'). Motor kalemleri birebir aynı
    -- anahtarlarla okur (20260611000002_bug059_rpcs.sql).
    v_days_sorted := '[]'::jsonb;
    FOR v_day IN
      SELECT value
      FROM pg_catalog.jsonb_array_elements(p_items)
      ORDER BY (value->>'gun')::int
    LOOP
      v_sess := '[]'::jsonb;
      FOR v_item IN SELECT * FROM pg_catalog.jsonb_array_elements(v_day->'kalemler')
      LOOP
        v_sess := v_sess || jsonb_build_array(jsonb_build_object(
          'drug_product_id', v_item->>'drug_product_id',
          'stok_id',         v_item->>'stok_id',
          'dose',            v_item->>'dose',
          'unit',            v_item->>'unit',
          'route',           NULLIF(v_item->>'route', ''),
          'planned_time',    COALESCE(NULLIF(v_item->>'saat', ''),
                                    NULLIF(v_day->>'saat', ''), '09:00')));
      END LOOP;
      v_days_sorted := v_days_sorted || jsonb_build_array(jsonb_build_object(
        'gun',  (v_day->>'gun')::int,
        'sess', v_sess));
    END LOOP;
  END IF;

  -- Dedupe: girdi sırası korunur
  FOREACH v_id IN ARRAY p_animal_ids LOOP
    IF v_id IS NOT NULL AND NOT (v_id = ANY (v_seen)) THEN
      v_seen := v_seen || v_id;
      v_list := v_list || v_id;
    END IF;
  END LOOP;
  v_toplam := array_length(v_list, 1);
  IF v_toplam IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan listesi boş');
  END IF;

  -- ═══ [P3b C2] p_takip_onaylar ⊆ p_animal_ids — liste-dışı id sessiz YOK
  -- sayılmaz (tüm mevcut fail-fast'lerden SONRA: mevcut hata sözleşmelerinin
  -- önceliği korunur).
  FOREACH v_id IN ARRAY COALESCE(p_takip_onaylar, '{}'::text[]) LOOP
    IF v_id IS NOT NULL AND NOT (v_id = ANY(p_animal_ids)) THEN
      RAISE EXCEPTION 'TAKIP_ONAY_KUME_UYUMSUZ:%',
        jsonb_build_object('liste_disi_id', v_id)::text;
    END IF;
  END LOOP;

  -- ═══ [P3b D4 satır-sonucu deseni — bulk_ilac ile birebir; H5 geri alımı:
  -- mevcut döngü/kilit DEĞİŞMEZ] fonksiyon başında açık-takipliler KİLİTSİZ
  -- okunur; p_takip_onaylar DIŞINDAKİ açık-takipli satır İŞLENMEZ + satır
  -- sonucu 'takip_acik[]'; onaylılar v_takip_map'e (döngüde satır öncesi
  -- kapanış). retry = onaylı alt kümeyle yeni çağrı.
  FOREACH v_id IN ARRAY v_list LOOP
    SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = v_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;
    IF FOUND THEN
      IF v_id = ANY(COALESCE(p_takip_onaylar, '{}'::text[])) THEN
        v_takip_map := v_takip_map || jsonb_build_object(v_id, v_takip.id);
      ELSE
        v_takip_islenenmez := v_takip_islenenmez || v_id;
        v_kupe := NULL;
        SELECT kupe_no INTO v_kupe FROM public.hayvanlar WHERE id = v_id;
        v_takip_acik_list := v_takip_acik_list || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_id, 'kupe', v_kupe, 'kod', 'TAKIP_ACIK',
          'muayene_tarihi', v_takip.hedef_tarih, 'muayene_saat', v_takip.hedef_saat));
      END IF;
    END IF;
  END LOOP;

  -- GT'de olmayan opsiyonel helper'lar canlıdaysa uygula (pg_proc guard — bir
  -- kez, döngü dışında; helper yoksa ilgili yol güvenli düşer)
  SELECT EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc
    WHERE proname = 'tedavi_sablon_tohumlama_gorev_ekle'
      AND pronamespace = 'public'::regnamespace
  ) INTO v_tohumlama_var;
  SELECT EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc
    WHERE proname = 'vaka_tohumlama_ekle'
      AND pronamespace = 'public'::regnamespace
  ) INTO v_tohu_ekle_var;

  FOREACH v_id IN ARRAY v_list LOOP
    -- ═══ [P3b D4] onaysız açık-takipli satır İŞLENMEZ (satır sonucu yukarıda
    -- takip_acik[]'a yazıldı).
    IF v_id = ANY(v_takip_islenenmez) THEN
      CONTINUE;
    END IF;
    SELECT kupe_no INTO v_kupe FROM public.hayvanlar WHERE id = v_id;
    v_ok         := true;
    v_case_id    := NULL;
    v_sab_obj    := NULL;
    v_manuel_obj := NULL;
    v_start_date := NULL;
    v_tohu_obj   := NULL;
    BEGIN
      -- [P3b D4] onaylı açık-takipli satır: kapanış satır işlenmeden HEMEN ÖNCE
      -- (alt-transaction'ın ilk deyimi; neden='OVSYNC' — vaka-yolu sınıfı).
      IF v_takip_map ? v_id THEN
        PERFORM public._takip_kapat((v_takip_map ->> v_id)::uuid, 'OVSYNC');
      END IF;
      v_res := public._vaka_ac_tek(v_id, p_disease_id, p_notes, p_tarih);
      IF (v_res->>'ok') <> 'true' THEN
        v_ok := false;
        v_atlanan := v_atlanan || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', v_res->>'mesaj'));
      ELSE
        v_case_id := (v_res->>'case_id')::uuid;
        -- V1.2: vakanın GERÇEK start_date'i (p_tarih ya da bugün) — tohumlama
        -- hedefi ve acilan[i].tarih buna çapar
        SELECT start_date INTO v_start_date FROM public.cases WHERE id = v_case_id;
        IF p_sablon_id IS NOT NULL THEN
          BEGIN
            v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := p_sablon_id);
            v_sab_obj := jsonb_build_object(
              'gun_sayisi',   v_sab->'gun_sayisi',
              'seans_sayisi', v_sab->'seans_sayisi',
              'atlanan',      v_sab->'atlanan');
            IF v_tohumlama_var THEN
              v_top := public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := p_sablon_id);
              v_sab_obj := v_sab_obj || jsonb_build_object(
                'toplanti_uygulandi', COALESCE((v_top->>'olustu') = 'true', false),
                'toplanti_sebep',     v_top->'sebep');
            ELSE
              v_sab_obj := v_sab_obj || jsonb_build_object('toplanti_uygulandi', false);
            END IF;
          EXCEPTION WHEN OTHERS THEN
            -- Şablon hatası tek hayvanı hatalar'a düşürür; vaka açık kalır.
            v_ok := false;
            v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
              'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM, 'case_id', v_case_id));
          END;
        ELSIF p_items IS NOT NULL THEN
          -- V2: çoklu gün manuel plan — günler gun ASC (v_days_sorted), her
          -- gün bug059 motoruyla vakanın start_date + (gun - 1) tarihine
          -- işlenir (start_date = p_tarih ya da bugün — V1.2 çapası).
          -- KISMİ GÜN SEMANTİĞİ: HER GÜN kendi BEGIN/EXCEPTION alt bloğunda
          -- işlenir — bir günde motor ok:false ya da EXCEPTION → hayvan
          -- hatalar'a düşer (case_id + gün bilgisiyle), vaka AÇIK kalır ve
          -- ÖNCEKİ günlerin satırları (treatment_days, uygulamalar, ilaç
          -- kayıtları, stok hareketleri, görevler) DURAR (gün alt bloğu
          -- yalnız kendi gününü geri alır); kalan günler denenmez,
          -- sıradaki hayvana geçilir. Böyle bir hayvan acilan'a girmez
          -- (V1.1 tek-gün deseninin çoklu-gün genelleştirmesi).
          v_gun_sayisi   := 0;
          v_seans_toplam := 0;
          v_err_gun      := NULL;
          FOR v_day IN SELECT * FROM pg_catalog.jsonb_array_elements(v_days_sorted)
          LOOP
            EXIT WHEN NOT v_ok;
            v_err_gun := (v_day->>'gun')::int;
            BEGIN
              v_r := public.add_treatment_day_with_sessions(
                p_case_id         := v_case_id,
                p_date            := v_start_date + (v_err_gun - 1),
                p_sessions        := v_day->'sess',
                p_existing_day_id := NULL);
              IF (v_r->>'ok') <> 'true' THEN
                v_ok := false;
                v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
                  'hayvan_id', v_id, 'kupe', v_kupe,
                  'mesaj', COALESCE(v_r->>'mesaj', 'Tedavi günü eklenemedi'),
                  'case_id', v_case_id, 'gun', v_err_gun));
              ELSE
                v_gun_sayisi   := v_gun_sayisi + 1;
                v_seans_toplam := v_seans_toplam
                                  + COALESCE((v_r->>'seans_sayisi')::int, 0);
              END IF;
            EXCEPTION WHEN OTHERS THEN
              v_ok := false;
              v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
                'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM,
                'case_id', v_case_id, 'gun', v_err_gun));
            END;
          END LOOP;
          IF v_ok THEN
            v_manuel_obj := jsonb_build_object(
              'gun_sayisi',   v_gun_sayisi,
              'seans_sayisi', v_seans_toplam);
          END IF;
        END IF;

        -- V1.2: planlı tohumlama — HER başarılı açılan vaka için, şablon/
        -- manuel'den SONRA, yalnız p_tohumlama iken. Yumuşak: sonuç asla
        -- hatalar'a sayılmaz, vaka açık kalır; sebep acilan[i].tohumlama'ya
        -- yazılır (uygunluk reddi / RPC yok / beklenmeyen hata).
        -- V2.2: p_tohumlama_cakisma modu — 'ekle' (default, davranış
        -- değişmez) | 'atla' (eski açık görev varsa YENİSİ AÇILMAZ) |
        -- 'uzerine_yaz' (eski açık görevler YUMUŞAK İPTAL + görev başına
        -- islem_log denetimi, sonra yeni görev açılır).
        IF p_tohumlama THEN
          BEGIN
            IF v_tohu_ekle_var THEN
              -- Çakışma taraması (yalnız mod <> 'ekle'; ekle hiç taramaz —
              -- regresyon birebir): hayvanın AÇIK TOHUMLAMA_PLANLI görevleri
              -- HER VAKADAN (kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:%'), YENİ
              -- açılan vakanın kendi satırları HARİÇ — şablon yolu aynı RPC
              -- çağrısında az önce görev açtıysa o "eski" değildir; aynı-vaka
              -- tekrarı vaka_tohumlama_ekle'nin mevcut guard'ında kalır.
              -- Sıra hedef_tarih ASC (en eski önce; NULL en son).
              v_uzerine := NULL;
              v_tohu_obj := NULL;
              IF p_tohumlama_cakisma <> 'ekle' THEN
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                  'id', g.id::text, 'hedef_tarih', g.hedef_tarih)
                                ORDER BY g.hedef_tarih ASC, g.id ASC),
                               '[]'::jsonb)
                  INTO v_cakisma
                  FROM public.gorev_log g
                 WHERE g.hayvan_id = v_id
                   AND g.gorev_tipi = 'TOHUMLAMA_PLANLI'
                   AND g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:%'
                   AND g.kaynak NOT LIKE
                       'TEDAVI_SABLON_TOHUMLAMA:' || v_case_id::text || ':%'
                   AND g.tamamlandi = false
                   AND g.iptal = false;

                IF p_tohumlama_cakisma = 'atla' AND v_cakisma <> '[]'::jsonb THEN
                  -- Sahip kararı: 'Atla' = yenisi AÇILMAZ; eski planın hedef
                  -- tarihi (en eski açık görev) sebebe yazılır.
                  v_tohu_obj := jsonb_build_object(
                    'olustu', false,
                    'sebep', 'Açık planlı tohumlama vardı — atlandı (eski plan: '
                             || COALESCE(to_char(
                                  (v_cakisma->0->>'hedef_tarih')::date, 'DD.MM'),
                                  '?')
                             || ')');
                ELSIF p_tohumlama_cakisma = 'uzerine_yaz'
                      AND v_cakisma <> '[]'::jsonb THEN
                  -- Sahip kararı: 'Üzerine yaz' = eski görev YUMUŞAK İPTAL.
                  -- Kapanış şekli close_case_with_remaining 5b adımının
                  -- (TOHUMLAMA_PLANLI iptali: iptal+tamamlandi+tarih)
                  -- aynası; kapatan_ref trg_gorev_parent_kapandi
                  -- konvansiyonuyla. Görev başına islem_log denetimi
                  -- (GOREV_IPTAL önceli yok — ip'ler GOREV_EKLENDI/
                  -- GOREV_TAMAMLA/GOREV_OTOKAPAT).
                  v_uzerine := '[]'::jsonb;
                  FOR v_c IN
                    SELECT x.id, x.hedef_tarih
                    FROM pg_catalog.jsonb_to_recordset(v_cakisma)
                         AS x(id text, hedef_tarih date)
                  LOOP
                    UPDATE public.gorev_log
                       SET iptal = true,
                           tamamlandi = true,
                           tamamlanma_tarihi = now(),
                           kapatan_ref = 'toplu-vaka-uzerine-yaz'
                     WHERE id::text = v_c.id
                       AND tamamlandi = false
                       AND iptal = false;
                    IF FOUND THEN
                      INSERT INTO public.islem_log
                        (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
                      VALUES
                        (gen_random_uuid()::text,
                         'TOHUMLAMA_PLANLI_IPTAL',
                         v_id, v_c.id, 'gorev_log',
                         jsonb_build_object(
                           'sebep', 'toplu vaka üzerine yazma'));
                      v_uzerine := v_uzerine || to_jsonb(
                        COALESCE(to_char(v_c.hedef_tarih, 'DD.MM'), '?'));
                    END IF;
                  END LOOP;
                END IF;
              END IF;

              IF v_tohu_obj IS NULL THEN
                v_tohu_tarih := v_start_date + p_tohumlama_gun_offset;
                v_tohu_res := public.vaka_tohumlama_ekle(
                  p_case_id := v_case_id,
                  p_tarih   := v_tohu_tarih,
                  p_saat    := COALESCE(p_tohumlama_saat, '08:00')::time);
                IF (v_tohu_res->>'ok') = 'true' THEN
                  v_tohu_obj := jsonb_build_object(
                    'olustu', true, 'gorev_id', v_tohu_res->'gorev_id');
                  -- V2.2: üzerine yazıldıysa iptal edilen eski planların
                  -- tarihleri (eski→yeni) sonuca eklenir.
                  IF v_uzerine IS NOT NULL AND v_uzerine <> '[]'::jsonb THEN
                    v_tohu_obj := v_tohu_obj || jsonb_build_object(
                      'uzerine_yazildi', v_uzerine);
                  END IF;
                ELSE
                  v_tohu_obj := jsonb_build_object(
                    'olustu', false,
                    'sebep', COALESCE(v_tohu_res->>'mesaj', 'Bilinmeyen sebep'));
                END IF;
              END IF;
            ELSE
              -- vaka_tohumlama_ekle canlıda yok (GT drift): güvenli düşüm
              v_tohu_obj := jsonb_build_object(
                'olustu', false, 'sebep', 'Tohumlama RPC yok');
            END IF;
          EXCEPTION WHEN OTHERS THEN
            v_tohu_obj := jsonb_build_object('olustu', false, 'sebep', SQLERRM);
          END;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_ok := false;
      v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM));
    END;

    IF v_ok THEN
      v_basari := v_basari + 1;
      v_acilan := v_acilan || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_id, 'kupe', v_kupe, 'case_id', v_case_id,
        'tarih', v_start_date,
        'sablon', v_sab_obj, 'manuel', v_manuel_obj,
        'tohumlama', v_tohu_obj));
    END IF;
  END LOOP;

  IF v_tohumlama_var THEN
    RETURN jsonb_build_object('ok', true, 'toplam', v_toplam, 'basari', v_basari,
      'atlanan', v_atlanan, 'hatalar', v_hatalar, 'acilan', v_acilan,
      'takip_acik', v_takip_acik_list,
      'sablon', p_sablon_id IS NOT NULL, 'manuel', p_items IS NOT NULL,
      'tohumlama', p_tohumlama);
  END IF;

  -- Tohumlama (şablon) helper'ı canlıda yok: güvenli düşüm işareti
  RETURN jsonb_build_object('ok', true, 'toplam', v_toplam, 'basari', v_basari,
    'atlanan', v_atlanan, 'hatalar', v_hatalar, 'acilan', v_acilan,
    'takip_acik', v_takip_acik_list,
    'sablon', p_sablon_id IS NOT NULL, 'manuel', p_items IS NOT NULL,
    'toplanti_uygulandi', false, 'tohumlama', p_tohumlama);
END;
$function$;

-- ── 4) kizginlik_vaka_ac — cases.start_date (yerel gün) ─────────────────
CREATE OR REPLACE FUNCTION public.kizginlik_vaka_ac(p_kizginlik_id text, p_tani text, p_tohumlama_id text DEFAULT NULL::text, p_notlar text DEFAULT NULL::text, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_kiz       record;
  v_case_id   uuid;
  v_disease   record;
  v_takip     record;
BEGIN
  -- (0) H4 standart deseni — KİLİTSİZ keşif; hızlı ret mevcut sözleşmeyle
  -- (aynı mesaj, aynı sırada).
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- hayvan İLK kilit (MK9-N muteks — FOR UPDATE ASLA); hayvan yoksa kilit
  -- alınmaz, eski akış cases INSERT'te FK ile düşer (yeni hata kodu YOK).
  PERFORM 1 FROM public.hayvanlar WHERE id = v_kiz.hayvan_id FOR NO KEY UPDATE;

  -- kızgınlık satırı yeniden doğrulama (arada silindiyse aynı red sözleşmesi)
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- (1) P3b C4 kapısı — TANIDAN BAĞIMSIZ, fail-closed (plan.md:452): keyfi
  -- p_tani metni P3a tetikleyici ağını KAÇIRIR → kapı RPC gövdesinde ZORUNLU;
  -- P3a tetikleyici kapsamından ÖNCE, ilk yazmadan (diseases INSERT / cases
  -- INSERT) önce. Onaysız açık takip → TAKIP_ACIK red.
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = v_kiz.hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND AND NOT COALESCE(p_takip_onay, false) THEN
    RAISE EXCEPTION 'TAKIP_ACIK:%',
      jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                         'muayene_saat', v_takip.hedef_saat)::text;
  END IF;
  -- (2) onaylı → aynı transaction'da ÖNCE kapanış (vaka-yolu sınıfı —
  -- create_case onaylı yoluyla aynı kod), sonra vaka INSERT.
  IF FOUND THEN
    PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
  END IF;

  -- Hastalık adından disease_id bul (case-insensitive) — eski kaskad birebir
  SELECT * INTO v_disease FROM public.diseases
  WHERE name ILIKE p_tani OR p_tani ILIKE '%' || name || '%'
  ORDER BY length(name) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.diseases (name, category)
    VALUES (p_tani, 'Üreme')
    RETURNING * INTO v_disease;
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, start_date, status, notes, created_at)
  VALUES (
    v_kiz.hayvan_id,
    v_disease.id,
    (now() AT TIME ZONE 'Europe/Istanbul')::date,
    'active',
    COALESCE(p_notlar, 'Tohumlama sırasında tespit edildi'),
    now()
  )
  RETURNING id INTO v_case_id;

  UPDATE public.kizginlik_log
  SET tedavi_case_id = v_case_id
  WHERE id = p_kizginlik_id;

  IF p_tohumlama_id IS NOT NULL AND p_tohumlama_id <> '' THEN
    UPDATE public.tohumlama
    SET case_id = v_case_id
    WHERE id = p_tohumlama_id;
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'KIZGINLIK_VAKA_ACILDI',
    v_kiz.hayvan_id,
    p_kizginlik_id,
    'kizginlik_log',
    jsonb_build_object(
      'case_id', v_case_id,
      'tani', p_tani,
      'kizginlik_id', p_kizginlik_id,
      'tohumlama_id', p_tohumlama_id
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id);
END;
$function$;

-- ═══ ACL yeniden onay (imza + ACL DEĞİŞMEZ; kaynak migration satırları aynen) ═══

-- _takip_gorev_kur [kalıp 20260929000002:288-289]
REVOKE ALL ON FUNCTION public._takip_gorev_kur(uuid, text, int, time) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._takip_gorev_kur(uuid, text, int, time) TO authenticated, service_role;

-- tohumlama_bos_ve_devam [kalıp 20260929000002:1032-1033]
REVOKE ALL ON FUNCTION public.tohumlama_bos_ve_devam(text, uuid, text, text, numeric, int, time, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tohumlama_bos_ve_devam(text, uuid, text, text, numeric, int, time, text, boolean) TO authenticated, service_role;

-- vaka_toplu_ac [kalıp 20260929000003:2041-2042]
REVOKE ALL ON FUNCTION public.vaka_toplu_ac(text[], uuid, jsonb, uuid, text, date, boolean, integer, text, text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_toplu_ac(text[], uuid, jsonb, uuid, text, date, boolean, integer, text, text, text[]) TO authenticated, service_role;

-- kizginlik_vaka_ac [kalıp 20260929000003:2044-2045]
REVOKE ALL ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text, boolean) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20261001000001_takip_yerel_gun_duzeltme (P12b HATA-2)
