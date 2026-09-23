-- 20260923000003_ovsync_pg_yardimcilar.sql
-- SPEC: docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md (R3)
-- Kapsam (yalnız yardımcı fonksiyonlar; uygulama yolları 000004'te bağlanır):
--   S-2  _pg_urun_durumu(text, uuid)            'PG' | 'DEGIL' | 'BELIRSIZ'
--   S-4  _pg_kapi(text, text, uuid, boolean)     güvenlik kapısı (iç, kilitli)
--   S-4  pg_uyari_kontrol(text[], text)          RPC — kilitsiz önizleme, bayraktan bağımsız
--   S-4  _pg_olay_isle(...)                      pg_application_event kaydı + ACK + S-5 (iç)
--   S-5  _tohumlama_pencere(timestamptz)         MK1 saat penceresi (IMMUTABLE)
--   MK3  _son_tohumlama(text)                     hayvanın son tohumlaması (0/1 satır, iç)
--   S-5  _pg_sonrasi_tohumlama(uuid)             PG +48s TOHUMLAMA_PLANLI (SK1, SK2) (iç)
--   S-6  tohumlama_gorev_ertele(uuid,date,time)  RPC — görev seviyesi erteleme (SK3, MK2)
-- Bağımlılık: 20260923000002_ovsync_pg_sema.sql
--   (_ovsync_pg_aktif(), drug_classes.farmakolojik_sinif_kodu, pg_application_event).
-- Kanonik taban: canlı pg_get_functiondef (2026-09-23): _etken_kod_bul,
--   _tohumlama_gorev_uygunluk, tohumlama_kaydet (VWP 55 gün tabanı),
--   tedavi_sablon_tohumlama_gorev_ekle (gorev_log INSERT kolonları).
-- Kurallar: MK3 gebelik otoritesi = son tohumlama.sonuc (hayvanlar.tohumlama_durumu
--   KULLANILMAZ); MK5 bayrak kapalıyken yan etki yok; fail-closed (tanımsız
--   karar/sonuç → RAISE). islem_log yalnız INSERT (immutability trigger'ı).
-- ACL: her fonksiyonda REVOKE ALL FROM PUBLIC, anon. `_` iç yardımcılar ayrıca
--   authenticated'dan REVOKE edilir (postgres default privileges yeni fonksiyona
--   authenticated EXECUTE verir). Yalnız pg_uyari_kontrol ve tohumlama_gorev_ertele
--   authenticated'a açıktır.
-- İç transaction deyimi YOK.

-- ─────────────────────────────────────────────────────────────────────────────
-- S-5  _tohumlama_pencere — MK1: kapalı aralıklar [09:00,12:00], [18:00,21:00]
--      (Europe/Istanbul). Pencere dışı an bir sonraki pencerenin başına itilir;
--      asla erkene çekilmez.
-- Örnekler (yerel saat → sonuç):
--   10:00 → 10:00 | 12:00 → 12:00 | 12:01 → 18:00 | 21:00 → 21:00
--   21:01 → ertesi gün 09:00 | 08:00 → aynı gün 09:00
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._tohumlama_pencere(p_ts timestamptz)
 RETURNS timestamptz
 LANGUAGE plpgsql
 IMMUTABLE STRICT SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_yerel timestamp := p_ts AT TIME ZONE 'Europe/Istanbul';
  v_gun   date      := (p_ts AT TIME ZONE 'Europe/Istanbul')::date;
  v_saat  time      := (p_ts AT TIME ZONE 'Europe/Istanbul')::time;
  v_sonuc timestamp;
BEGIN
  IF v_saat < time '09:00' THEN
    v_sonuc := v_gun + time '09:00';
  ELSIF v_saat <= time '12:00' THEN
    v_sonuc := v_yerel;
  ELSIF v_saat < time '18:00' THEN
    v_sonuc := v_gun + time '18:00';
  ELSIF v_saat <= time '21:00' THEN
    v_sonuc := v_yerel;
  ELSE
    v_sonuc := (v_gun + 1) + time '09:00';
  END IF;
  RETURN v_sonuc AT TIME ZONE 'Europe/Istanbul';
END;
$fn$;

REVOKE ALL ON FUNCTION public._tohumlama_pencere(timestamptz) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- MK3  _son_tohumlama — hayvanın "son tohumlaması"nın TEK tanımı.
--   Sıralama: tarih DESC NULLS LAST, created_at DESC NULLS LAST.
--   SETOF + LIMIT 1: kayıt yoksa 0 satır döner → çağıran `SELECT * INTO v_t
--   FROM public._son_tohumlama(x); IF NOT FOUND` kullanabilir (tekil composite
--   dönüşte NULL-satır FOUND=true verirdi). Kilit almaz.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._son_tohumlama(p_hayvan_id text)
 RETURNS SETOF public.tohumlama
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
 ROWS 1
AS $fn$
  SELECT t.*
    FROM public.tohumlama t
   WHERE t.hayvan_id = p_hayvan_id
   ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
   LIMIT 1;
$fn$;

REVOKE ALL ON FUNCTION public._son_tohumlama(text) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-2  _pg_urun_durumu — ürün/stok PG mi?
--   1. Ürün = p_drug_product_id ya da stok.drug_product_id; sınıf PGF2A → PG.
--   2. _etken_kod_bul(stok) = 'PG' → PG (ek; üst küme). Stoksuz ürün için
--      sınıfın etken_kod'u 'PG' ise de PG.
--   3. Ürün bağı yok + stok adı PG kalıbına uyuyor → BELIRSIZ.
--   0. Stok da ürün de verilmedi (ilaçsız uygulama) → DEGIL: ilaç yoksa PG yok.
--   4. Stok id verildi ama bulunamadı ve ürün verilmedi → BELIRSIZ. Verilen ürün
--      katalogda yok → BELIRSIZ (fail-closed).
--   Diğer → DEGIL.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._pg_urun_durumu(p_stok_id text, p_drug_product_id uuid DEFAULT NULL)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_stok_var    boolean := false;
  v_stok_ad     text;
  v_stok_urun   uuid;
  v_urun        uuid;
  v_urun_var    boolean := false;
  v_sinif_kodu  text;
  v_etken_kod   text;
BEGIN
  -- 0. İlaç yok → PG uygulaması yok
  IF p_stok_id IS NULL AND p_drug_product_id IS NULL THEN
    RETURN 'DEGIL';
  END IF;

  IF p_stok_id IS NOT NULL THEN
    SELECT true, s.urun_adi, s.drug_product_id
      INTO v_stok_var, v_stok_ad, v_stok_urun
      FROM public.stok s WHERE s.id = p_stok_id;
    v_stok_var := COALESCE(v_stok_var, false);
  END IF;

  -- 4. Stok id verildi, bulunamadı ve ürün verilmedi → BELIRSIZ
  IF NOT v_stok_var AND p_drug_product_id IS NULL THEN
    RETURN 'BELIRSIZ';
  END IF;

  -- 1. Ürün zinciri: ürün → sınıf → farmakolojik_sinif_kodu
  v_urun := COALESCE(p_drug_product_id, v_stok_urun);
  IF v_urun IS NOT NULL THEN
    SELECT true, dc.farmakolojik_sinif_kodu, dc.etken_kod
      INTO v_urun_var, v_sinif_kodu, v_etken_kod
      FROM public.drug_products dp
      JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
     WHERE dp.id = v_urun;
    v_urun_var := COALESCE(v_urun_var, false);
    -- Verilen/bağlı ürün kataloğa çözülemiyor → fail-closed
    IF NOT v_urun_var THEN
      RETURN 'BELIRSIZ';
    END IF;
    IF v_sinif_kodu = 'PGF2A' THEN
      RETURN 'PG';
    END IF;
    -- 2 (stoksuz ürün yolu): sınıf etken_kod'u PG
    IF v_etken_kod = 'PG' THEN
      RETURN 'PG';
    END IF;
  END IF;

  -- 2. _etken_kod_bul üst kümesi (etken_kod + ILIKE güvenlik ağı)
  IF v_stok_var AND public._etken_kod_bul(p_stok_id, NULL) = 'PG' THEN
    RETURN 'PG';
  END IF;

  -- 3. Ürün bağı yok, ad PG'ye benziyor → BELIRSIZ
  IF v_urun IS NULL AND v_stok_ad ~* '(prostag|dinopros|kloprost|cloprost|enzaprost|dalmazin|estrumate|lutalyse|\mpgs?\M)' THEN
    RETURN 'BELIRSIZ';
  END IF;

  RETURN 'DEGIL';
END;
$fn$;

REVOKE ALL ON FUNCTION public._pg_urun_durumu(text, uuid) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-4  _pg_kapi — tekil/toplu yolun güvenlik kapısı (iç). Karar döner, RAISE
--      etmez (tekil yol çağıran tarafta PG_KAPI:<KOD>:<json> ile RAISE eder;
--      toplu yol satır bazında raporlar). Bayrak kapalı → {karar:'KAPALI'}, kilit yok.
--   Karar kümesi: KAPALI | ALLOW | ACK_PENDING | BLOCK_PREGNANT |
--                 REQUIRE_ACK_PENDING | BLOCK_CATALOG_UNRESOLVED
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._pg_kapi(p_hayvan_id text, p_stok_id text, p_drug_product_id uuid, p_onay boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_durum   text;
  v_kupe    text;
  v_t       record;
  v_karar   text;
  v_bugun   date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN jsonb_build_object('karar', 'KAPALI');
  END IF;

  v_durum := public._pg_urun_durumu(p_stok_id, p_drug_product_id);
  IF v_durum = 'DEGIL' THEN
    RETURN jsonb_build_object('karar', 'ALLOW', 'pg', false);
  ELSIF v_durum = 'BELIRSIZ' THEN
    RETURN jsonb_build_object('karar', 'BLOCK_CATALOG_UNRESOLVED', 'pg', NULL,
                              'urun_durumu', v_durum, 'hayvan_id', p_hayvan_id,
                              'stok_id', p_stok_id, 'drug_product_id', p_drug_product_id);
  ELSIF v_durum IS DISTINCT FROM 'PG' THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_URUN_DURUMU', 'urun_durumu', v_durum);
  END IF;

  -- TOCTOU (T10): hayvan satırı kilitlenir; eşzamanlı tohumlama/sonuç yazımı sıraya girer
  -- (tohumlama_kaydet de hayvanı FOR NO KEY UPDATE ile kilitler). FOR UPDATE değil:
  -- o, çocuk tablolardaki FK insert'lerinin KEY SHARE kilidini de bloklardı.
  SELECT h.kupe_no INTO v_kupe FROM public.hayvanlar h WHERE h.id = p_hayvan_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'HAYVAN_BULUNAMADI', 'hayvan_id', p_hayvan_id);
  END IF;

  -- MK3: gebelik otoritesi = son tohumlamanın sonucu.
  SELECT t.id, t.tarih, t.sperma, t.deneme_no, t.sonuc
    INTO v_t
    FROM public._son_tohumlama(p_hayvan_id) t;

  IF NOT FOUND THEN
    v_karar := 'ALLOW';
  ELSIF v_t.sonuc = 'Gebe' THEN
    v_karar := 'BLOCK_PREGNANT';
  ELSIF v_t.sonuc = 'Bekliyor' THEN
    v_karar := CASE WHEN COALESCE(p_onay, false) THEN 'ACK_PENDING' ELSE 'REQUIRE_ACK_PENDING' END;
  ELSIF v_t.sonuc IN ('Boş', 'Doğum Yaptı', 'Abort') THEN
    v_karar := 'ALLOW';
  ELSE
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_TOHUMLAMA_SONUCU',
      'hayvan_id', p_hayvan_id, 'tohumlama_id', v_t.id, 'sonuc', v_t.sonuc);
  END IF;

  RETURN jsonb_build_object(
    'karar', v_karar, 'pg', true, 'urun_durumu', v_durum,
    'hayvan_id', p_hayvan_id, 'kupe_no', v_kupe,
    'tohumlama_id', v_t.id, 'tohumlama_tarihi', v_t.tarih, 'tohumlama_sonuc', v_t.sonuc,
    'sperma', v_t.sperma, 'deneme_no', v_t.deneme_no,
    'gun', CASE WHEN v_t.tarih IS NULL THEN NULL ELSE v_bugun - v_t.tarih END
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public._pg_kapi(text, text, uuid, boolean) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-4  pg_uyari_kontrol — UI önizlemesi (RPC). Salt-okuma, KİLİTSİZ,
--      bayraktan bağımsız. Karar _pg_kapi ile aynı eşleme (onaysız varsayım).
--      Bilinmeyen hayvan id → o satır karar='HAYVAN_BULUNAMADI' (kupe_no NULL);
--      önizlemenin geri kalanı düşmez. Diğer tanımsız durumlar RAISE.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.pg_uyari_kontrol(p_hayvan_ids text[], p_stok_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_pg      text;
  v_id      text;
  v_kupe    text;
  v_t       record;
  v_var     boolean;
  v_karar   text;
  v_liste   jsonb := '[]'::jsonb;
  v_bugun   date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
BEGIN
  v_pg := public._pg_urun_durumu(p_stok_id, NULL);
  IF v_pg IS NULL OR v_pg NOT IN ('PG', 'DEGIL', 'BELIRSIZ') THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_URUN_DURUMU', 'urun_durumu', v_pg);
  END IF;

  FOR v_id IN
    SELECT u.hid FROM unnest(COALESCE(p_hayvan_ids, '{}'::text[])) WITH ORDINALITY AS u(hid, sira)
    ORDER BY u.sira
  LOOP
    SELECT h.kupe_no INTO v_kupe FROM public.hayvanlar h WHERE h.id = v_id;
    IF NOT FOUND THEN
      v_liste := v_liste || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_id, 'kupe_no', NULL, 'karar', 'HAYVAN_BULUNAMADI',
        'tohumlama_id', NULL, 'tohumlama_tarihi', NULL, 'tohumlama_sonuc', NULL,
        'sperma', NULL, 'deneme_no', NULL, 'gun', NULL));
      CONTINUE;
    END IF;

    SELECT t.id, t.tarih, t.sperma, t.deneme_no, t.sonuc
      INTO v_t
      FROM public._son_tohumlama(v_id) t;
    v_var := FOUND;

    IF v_pg = 'DEGIL' THEN
      v_karar := 'ALLOW';
    ELSIF v_pg = 'BELIRSIZ' THEN
      v_karar := 'BLOCK_CATALOG_UNRESOLVED';
    ELSIF NOT v_var THEN
      v_karar := 'ALLOW';
    ELSIF v_t.sonuc = 'Gebe' THEN
      v_karar := 'BLOCK_PREGNANT';
    ELSIF v_t.sonuc = 'Bekliyor' THEN
      v_karar := 'REQUIRE_ACK_PENDING';
    ELSIF v_t.sonuc IN ('Boş', 'Doğum Yaptı', 'Abort') THEN
      v_karar := 'ALLOW';
    ELSE
      RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_TOHUMLAMA_SONUCU',
        'hayvan_id', v_id, 'tohumlama_id', v_t.id, 'sonuc', v_t.sonuc);
    END IF;

    v_liste := v_liste || jsonb_build_array(jsonb_build_object(
      'hayvan_id', v_id, 'kupe_no', v_kupe, 'karar', v_karar,
      'tohumlama_id',     CASE WHEN v_var THEN v_t.id END,
      'tohumlama_tarihi', CASE WHEN v_var THEN v_t.tarih END,
      'tohumlama_sonuc',  CASE WHEN v_var THEN v_t.sonuc END,
      'sperma',           CASE WHEN v_var THEN v_t.sperma END,
      'deneme_no',        CASE WHEN v_var THEN v_t.deneme_no END,
      'gun',              CASE WHEN v_var AND v_t.tarih IS NOT NULL THEN v_bugun - v_t.tarih END
    ));
  END LOOP;

  RETURN jsonb_build_object('pg', v_pg, 'hayvanlar', v_liste);
END;
$fn$;

REVOKE ALL ON FUNCTION public.pg_uyari_kontrol(text[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pg_uyari_kontrol(text[], text) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-5  _pg_sonrasi_tohumlama — PG gerçekleşmesinden +48s sonra TOHUMLAMA_PLANLI.
--   0. Bayrak kapalı (savunma) → gorev_sonuc='KAPALI', çık.
--   1. t = _tohumlama_pencere(occurred_at + 48h), dakikaya kesilmiş, yerel Europe/Istanbul.
--   2. VWP: taban = GREATEST(son doğum, son abort); t::date < taban + 55 → VWP_ICINDE.
--      (55 = tohumlama_kaydet sabiti; ikisi aynı kalmalı.)
--   3. _tohumlama_gorev_uygunluk NULL değil → UYGUNSUZ.
--   4. Hayvanın TÜM açık TOHUMLAMA_PLANLI görevleri PG_YERINE:<event> ile kapanır (SK2).
--   5. Yeni görev INSERT; 6. event OLUSTU + islem_log PG_TOHUMLAMA_GOREVI.
--   İdempotent: gorev_sonuc zaten doluysa no-op.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._pg_sonrasi_tohumlama(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_e          record;
  v_hedef      timestamptz;
  v_yerel      timestamp;
  v_tarih      date;
  v_saat       time;
  v_son_dogum  date;
  v_son_abort  date;
  v_taban      date;
  v_sebep      text;
  v_iptal_ids  uuid[];
  v_gorev_id   uuid;
BEGIN
  SELECT * INTO v_e FROM public.pg_application_event WHERE id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PG_OLAY_BULUNAMADI:%', jsonb_build_object('event_id', p_event_id);
  END IF;
  IF v_e.gorev_sonuc IS NOT NULL THEN
    RETURN;  -- zaten işlendi (idempotent)
  END IF;
  IF v_e.geri_alindi_at IS NOT NULL THEN
    RAISE EXCEPTION 'PG_OLAY_GERI_ALINMIS:%', jsonb_build_object('event_id', p_event_id);
  END IF;

  IF NOT public._ovsync_pg_aktif() THEN
    UPDATE public.pg_application_event SET gorev_sonuc = 'KAPALI' WHERE id = p_event_id;
    RETURN;
  END IF;

  -- 1. Hedef an (pencereye yuvarlandıktan sonra dakikaya kesilir: hedef_saat
  --    mikro-saniye taşımasın; pencere içi an kesilince yine pencere içindedir)
  v_hedef := date_trunc('minute', public._tohumlama_pencere(v_e.occurred_at + interval '48 hours'));
  v_yerel := v_hedef AT TIME ZONE 'Europe/Istanbul';
  v_tarih := v_yerel::date;
  v_saat  := v_yerel::time;

  -- 2. VWP (tohumlama_kaydet ile aynı taban ve 55 gün)
  SELECT MAX(d.tarih) INTO v_son_dogum FROM public.dogum d WHERE d.anne_id = v_e.hayvan_id;
  SELECT MAX(t.abort_tarihi) INTO v_son_abort FROM public.tohumlama t
   WHERE t.hayvan_id = v_e.hayvan_id AND t.sonuc = 'Abort' AND t.abort_tarihi IS NOT NULL;
  v_taban := GREATEST(v_son_dogum, v_son_abort);
  IF v_taban IS NOT NULL AND v_tarih < v_taban + 55 THEN
    UPDATE public.pg_application_event
       SET gorev_sonuc = 'VWP_ICINDE',
           gorev_sonuc_detay = format('VWP tabanı %s + 55 gün = %s; hedef %s', v_taban, v_taban + 55, v_tarih)
     WHERE id = p_event_id;
    RETURN;
  END IF;

  -- 3. Uygunluk
  v_sebep := public._tohumlama_gorev_uygunluk(v_e.hayvan_id, v_tarih);
  IF v_sebep IS NOT NULL THEN
    UPDATE public.pg_application_event
       SET gorev_sonuc = 'UYGUNSUZ', gorev_sonuc_detay = v_sebep
     WHERE id = p_event_id;
    RETURN;
  END IF;

  -- 4. SK2: açık planlı tohumlamaların yerine geçilir (şablon TAI, önceki PG görevi)
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'PG_YERINE:' || p_event_id::text
     WHERE hayvan_id = v_e.hayvan_id
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_iptal_ids FROM u;

  -- 5. Yeni görev
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES (gen_random_uuid(), v_e.hayvan_id, 'TOHUMLAMA_PLANLI',
          'PG sonrası tohumlama — PG sonrası östrus değişkendir; kızgınlık görülmezse ertele/değerlendir.',
          v_tarih, v_saat, false, 'PG_TOHUMLAMA:' || p_event_id::text)
  RETURNING id INTO v_gorev_id;

  -- 6. Event + audit
  UPDATE public.pg_application_event
     SET gorev_sonuc = 'OLUSTU', tohumlama_gorev_id = v_gorev_id
   WHERE id = p_event_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('PG_TOHUMLAMA_GOREVI', v_e.hayvan_id, v_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'event_id', p_event_id, 'gorev_id', v_gorev_id,
            'yerine_gecilen_gorev_ids', to_jsonb(v_iptal_ids),
            'hedef_tarih', v_tarih, 'hedef_saat', v_saat, 'hedef_at', v_hedef,
            'occurred_at', v_e.occurred_at,
            'source_type', v_e.source_type, 'source_id', v_e.source_id),
          '{}'::jsonb);
END;
$fn$;

REVOKE ALL ON FUNCTION public._pg_sonrasi_tohumlama(uuid) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-4  _pg_olay_isle — PG gerçekleşme kaydı (iç). Dönüş: yeni event id;
--      PG değil / bayrak kapalı / (source_type,source_id) çakışması → NULL.
--   Yalnız p_kapi.pg = true ve karar ∈ {ALLOW, ACK_PENDING} iken yazar.
--   Blok kararı buraya ulaşırsa (çağıran RAISE etmemiş) → PG_KAPI:<KOD>:<json>.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._pg_olay_isle(
  p_source_type text, p_source_id text, p_hayvan_id text, p_stok_id text,
  p_drug_product_id uuid, p_occurred_at timestamptz, p_kapi jsonb, p_gerekce text)
 RETURNS uuid
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_karar      text;
  v_pg         text;
  v_event_id   uuid;
  v_toh_id     text;
  v_iptal      integer := 0;
BEGIN
  IF p_kapi IS NULL OR jsonb_typeof(p_kapi) <> 'object' THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'KAPI_SONUCU_YOK');
  END IF;
  v_karar := p_kapi->>'karar';
  v_pg    := p_kapi->>'pg';

  IF v_karar = 'KAPALI' THEN
    RETURN NULL;
  ELSIF v_karar IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
    RAISE EXCEPTION 'PG_KAPI:%:%', v_karar, p_kapi;
  ELSIF v_karar NOT IN ('ALLOW', 'ACK_PENDING') OR v_karar IS NULL THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_KARAR', 'kapi', p_kapi);
  END IF;

  IF v_pg = 'false' AND v_karar = 'ALLOW' THEN
    RETURN NULL;  -- PG değil; olay yok
  ELSIF v_pg IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_PG_BAYRAGI', 'kapi', p_kapi);
  END IF;

  -- Kapı başka hayvan için alınmışsa reddet
  IF (p_kapi->>'hayvan_id') IS DISTINCT FROM p_hayvan_id THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'KAPI_HAYVAN_UYUSMAZ',
      'hayvan_id', p_hayvan_id, 'kapi', p_kapi);
  END IF;
  IF p_source_type IS NULL OR p_source_type NOT IN ('HIZLI_UYGULAMA', 'TEDAVI_SEANS', 'TOPLU_ILAC')
     OR p_source_id IS NULL OR p_occurred_at IS NULL THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'GECERSIZ_OLAY_PARAMETRESI',
      'source_type', p_source_type, 'source_id', p_source_id, 'occurred_at', p_occurred_at);
  END IF;

  IF v_karar = 'ACK_PENDING' THEN
    v_toh_id := p_kapi->>'tohumlama_id';
    IF v_toh_id IS NULL THEN
      RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'ACK_TOHUMLAMA_YOK', 'kapi', p_kapi);
    END IF;
  END IF;

  INSERT INTO public.pg_application_event
    (source_type, source_id, hayvan_id, stok_id, drug_product_id, occurred_at,
     karar, ack_tohumlama_id, ack_gerekce)
  VALUES
    (p_source_type, p_source_id, p_hayvan_id, p_stok_id, p_drug_product_id, p_occurred_at,
     v_karar, v_toh_id, CASE WHEN v_karar = 'ACK_PENDING' THEN p_gerekce END)
  ON CONFLICT (source_type, source_id) DO NOTHING
  RETURNING id INTO v_event_id;

  IF v_event_id IS NULL THEN
    RETURN NULL;  -- T15: aynı kaynak zaten kayıtlı; türev iş yok
  END IF;

  IF v_karar = 'ACK_PENDING' THEN
    -- Onaylanan (Bekliyor) tohumlamanın açık gebelik kontrolleri kapanır; tohumlama Bekliyor kalır.
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'PG_ONAY:' || v_event_id::text
     WHERE kaynak = 'TOH-' || v_toh_id
       AND gorev_tipi = 'GEBELIK_KONTROL'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false;
    GET DIAGNOSTICS v_iptal = ROW_COUNT;

    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('PG_APPLICATION_ACKNOWLEDGED', p_hayvan_id, v_event_id::text, 'pg_application_event',
            jsonb_build_object(
              'event_id', v_event_id, 'tohumlama_id', v_toh_id, 'gerekce', p_gerekce,
              'iptal_gorev_sayisi', v_iptal,
              'source_type', p_source_type, 'source_id', p_source_id),
            '{}'::jsonb);
  END IF;

  PERFORM public._pg_sonrasi_tohumlama(v_event_id);
  RETURN v_event_id;
END;
$fn$;

REVOKE ALL ON FUNCTION public._pg_olay_isle(text, text, text, text, uuid, timestamptz, jsonb, text) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-6  tohumlama_gorev_ertele — açık TOHUMLAMA_PLANLI görevini erteler (RPC,
--      bayraktan bağımsız). hayvan_tohumlama_ertele (ay bazlı) DEĞİŞMEZ (SK3).
--   Hatalar: GOREV_ERTELENEMEZ:<json>, GECMIS_TARIH:<json>.
--   GECMIS_TARIH: yeni tarih bugünden önce YA DA pencereye yuvarlanmış yeni an
--   < now() (bugünün geçmiş saatine erteleme reddedilir; saat verilmezse
--   COALESCE(görev saati, 09:00) pencereye yuvarlanır ve gelecekte olmalıdır).
--   MK2: sınır yok; ilk hedeften > 7 gün → uyari='ERTELEME_7_GUN_ASILDI'.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tohumlama_gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_g          record;
  v_bugun      date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_saat       time;
  v_hedef      timestamptz;
  v_yerel      timestamp;
  v_yeni_tarih date;
  v_yeni_saat  time;
  v_ilk_hedef  date;
  v_toplam     integer;
  v_uyari      text;
BEGIN
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_BULUNAMADI');
  END IF;
  IF v_g.gorev_tipi IS DISTINCT FROM 'TOHUMLAMA_PLANLI' THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'TIP_UYGUN_DEGIL', 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_ACIK_DEGIL');
  END IF;
  IF p_yeni_tarih IS NULL THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'YENI_TARIH_BOS');
  END IF;
  IF p_yeni_tarih < v_bugun THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_tarih', p_yeni_tarih, 'bugun', v_bugun);
  END IF;

  v_saat  := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
  v_hedef := public._tohumlama_pencere((p_yeni_tarih + v_saat) AT TIME ZONE 'Europe/Istanbul');
  IF v_hedef < now() THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_tarih', p_yeni_tarih,
      'yeni_saat', v_saat, 'hedef_at', v_hedef, 'simdi', now());
  END IF;
  v_yerel := v_hedef AT TIME ZONE 'Europe/Istanbul';
  v_yeni_tarih := v_yerel::date;
  v_yeni_saat  := v_yerel::time;

  SELECT (l.payload->>'eski_tarih')::date INTO v_ilk_hedef
    FROM public.islem_log l
   WHERE l.tip = 'TOHUMLAMA_ERTELE'
     AND l.ref_tablo = 'gorev_log'
     AND l.ref_id = p_gorev_id::text
     AND l.payload ? 'eski_tarih'
   ORDER BY l.tarih ASC, l.degisim_txid ASC NULLS LAST
   LIMIT 1;
  v_ilk_hedef := COALESCE(v_ilk_hedef, v_g.hedef_tarih, v_yeni_tarih);

  v_toplam := v_yeni_tarih - v_ilk_hedef;
  v_uyari  := CASE WHEN v_toplam > 7 THEN 'ERTELEME_7_GUN_ASILDI' END;

  UPDATE public.gorev_log
     SET hedef_tarih = v_yeni_tarih, hedef_saat = v_yeni_saat
   WHERE id = p_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_ERTELE', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', p_gorev_id,
            'eski_tarih', v_g.hedef_tarih, 'eski_saat', v_g.hedef_saat,
            'yeni_tarih', v_yeni_tarih, 'yeni_saat', v_yeni_saat,
            'ilk_hedef_tarih', v_ilk_hedef,
            'toplam_erteleme_gun', v_toplam, 'uyari', v_uyari),
          jsonb_build_object(
            'olusturulan', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object(
              'tablo', 'gorev_log', 'id', p_gorev_id::text,
              'onceki',  jsonb_build_object('hedef_tarih', v_g.hedef_tarih, 'hedef_saat', v_g.hedef_saat),
              'sonraki', jsonb_build_object('hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat))),
            'silinen', '[]'::jsonb),
          format('Planlı tohumlama görevi ertelendi: %s %s → %s %s',
                 v_g.hedef_tarih, v_g.hedef_saat, v_yeni_tarih, v_yeni_saat));

  RETURN jsonb_build_object(
    'ok', true, 'gorev_id', p_gorev_id,
    'hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat,
    'ilk_hedef_tarih', v_ilk_hedef, 'toplam_erteleme_gun', v_toplam,
    'uyari', v_uyari);
END;
$fn$;

REVOKE ALL ON FUNCTION public.tohumlama_gorev_ertele(uuid, date, time) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_gorev_ertele(uuid, date, time) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- EOF 20260923000003
