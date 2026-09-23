-- ============================================================================
-- supabase/tests/ovsync_pg_kabul.sql — Ovsync / PG / Tohumlama SQL kabul betiği
-- SPEC: docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md (R3) — S-1…S-10
-- Matris: R1 §9 (T01–T25), R2 §3 (T26–T31); SPEC'in yeniden tanımladıkları
--         T13', T14', T28' ve §0 sahip/mimar kararları. UREME_KONTROL düştü.
--
-- Sözleşme:
--   * Betik migration'ları UYGULAMAZ ve kendi içinde BEGIN/COMMIT/ROLLBACK
--     taşımaz. Çağıran sarmalayıcı BEGIN … ROLLBACK ile koşar (README).
--   * Her test bir DO bloğudur; başarı → NOTICE 'PASS …', başarısızlık →
--     EXCEPTION 'FAIL <id>: beklenen … gerçek …' (ilk FAIL koşumu durdurur).
--   * Her test kendi fixture'ını kurar (benzersiz 'KB-' kimlikleri); geçmiş
--     olaylar CURRENT_DATE'e göre geriye kurulur. now() transaction boyunca
--     sabittir; saate bağlı beklentiler now()'dan hesaplanır ya da iç
--     yardımcılar sabit anla çağrılarak deterministik yapılır.
--   * Bölüm 1 bayrak 0 (MK5), bölüm 2+ bayrak 1.
--   * Yardımcılar pg_temp şemasındadır (oturum sonunda/ROLLBACK'te yok olur).
-- ============================================================================

SET LOCAL client_min_messages = notice;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000cafe', true);

-- ── Yardımcılar (pg_temp) ───────────────────────────────────────────────────
-- PASS sayacı: her başarılı kb_ok çağrısı bir satır ekler; betiğin sonunda
-- sayılır ve 'OZET: N PASS' ile basılır. ROLLBACK ile birlikte yok olur.
CREATE TEMP TABLE kb_gecti (id serial PRIMARY KEY);

CREATE FUNCTION pg_temp.kb_ok(p_kosul boolean, p_test text, p_beklenen text, p_gercek text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_kosul IS NOT TRUE THEN
    RAISE EXCEPTION 'FAIL %: beklenen % gerçek %', p_test, p_beklenen, COALESCE(p_gercek, '<NULL>');
  END IF;
  INSERT INTO pg_temp.kb_gecti DEFAULT VALUES;
END $f$;

CREATE FUNCTION pg_temp.kb_id(p_on text) RETURNS text LANGUAGE sql VOLATILE AS $f$
  SELECT p_on || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 10)
$f$;

-- Dişi, yaşı p_yas_gun, verilen durumda test hayvanı (hayvan_ekle'nin iki
-- overload'u isimli çağrıda belirsiz → doğrudan INSERT; tüm trigger'lar yürür).
CREATE FUNCTION pg_temp.kb_hayvan(p_yas_gun int DEFAULT 1500, p_durum text DEFAULT 'Aktif',
                                  p_kisir boolean DEFAULT false)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text := pg_temp.kb_id('KB');
BEGIN
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, dogum_tarihi, durum, irk, kisir)
  VALUES (v, v, 'Dişi', CURRENT_DATE - p_yas_gun, p_durum, 'Holstein', p_kisir);
  RETURN v;
END $f$;

-- Europe/Istanbul yerel gün+saat → timestamptz
CREATE FUNCTION pg_temp.kb_yerel(p_gun date, p_saat time) RETURNS timestamptz
LANGUAGE sql IMMUTABLE AS $f$ SELECT (p_gun + p_saat) AT TIME ZONE 'Europe/Istanbul' $f$;

-- Kabul ortamı sabitleri (canlı katalog kopyası)
CREATE FUNCTION pg_temp.kb_c(p_ad text) RETURNS text LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE p_ad
    WHEN 'PG_STOK'        THEN '86bb424c-a517-45b7-94f9-6fce2beb98e8'  -- PGs (alke), Kloprostenol
    WHEN 'PG_URUN'        THEN 'ef49ec29-4592-43df-9252-48c05da142c5'
    WHEN 'DALMAZIN_URUN'  THEN '11fdc54e-fc8b-41a0-b3ba-2cd50e0c502b'  -- Dinoprost
    WHEN 'FLU_STOK'       THEN '03673401-9eff-4e3b-80c3-514e2cb0e5fa'  -- Flunixin (PG değil)
    WHEN 'OVSYNC_SABLON'  THEN 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'
    WHEN 'MASTIT_SABLON'  THEN '61328bb5-1075-4d40-a6df-4afbf9ce8375'
    WHEN 'OVSYNC_HASTALIK' THEN 'c346e115-35ff-4430-92b8-874c505d857e'
    WHEN 'MASTIT_HASTALIK' THEN '1bb109ce-27b9-4cad-8acf-87cc871e285a'
  END
$f$;

-- Ovsync vakasını gerçek toplu RPC ile açar (vaka + şablon seansları + TAI); case_id döner.
CREATE FUNCTION pg_temp.kb_ovsync_vaka(p_hayvan text, p_tarih date DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v_r jsonb;
BEGIN
  v_r := public.vaka_toplu_ac(p_animal_ids := ARRAY[p_hayvan],
                              p_disease_id := pg_temp.kb_c('OVSYNC_HASTALIK')::uuid,
                              p_sablon_id  := pg_temp.kb_c('OVSYNC_SABLON')::uuid,
                              p_tarih      := p_tarih);
  IF (v_r->>'basari')::int IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'FIXTURE: vaka_toplu_ac başarısız: %', v_r;
  END IF;
  RETURN (v_r->'acilan'->0->>'case_id')::uuid;
END $f$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 0 — Şema/katalog önkoşulları (bayraktan bağımsız)
-- ════════════════════════════════════════════════════════════════════════════

-- S-1: bayrak satırı ve okuyucu
DO $t$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM public.protokol_ayar WHERE anahtar = 'ovsync_pg_kurallari_aktif';
  PERFORM pg_temp.kb_ok(FOUND, 'S1-a', 'bayrak satırı var', 'yok');
  PERFORM pg_temp.kb_ok(r.deger = 0 AND r.birim = 'bool' AND r.min_deger = 0 AND r.max_deger = 1,
    'S1-a', 'deger=0 birim=bool min=0 max=1', format('%s %s %s %s', r.deger, r.birim, r.min_deger, r.max_deger));
  PERFORM pg_temp.kb_ok(public._ovsync_pg_aktif() IS FALSE, 'S1-b', '_ovsync_pg_aktif()=false', public._ovsync_pg_aktif()::text);
  RAISE NOTICE 'PASS S1: bayrak satırı deger=0, _ovsync_pg_aktif()=false';
END $t$;

-- S-2: katalog backfill (6 sistem etken madde, sınıf kodları, Kloprostenol etken_kod)
DO $t$
DECLARE v_n int; v_kod text; v_ek text;
BEGIN
  SELECT count(*) INTO v_n FROM public.drug_classes WHERE sistem;
  PERFORM pg_temp.kb_ok(v_n = 6, 'S2-backfill', '6 sistem satırı', v_n::text);
  SELECT count(*) INTO v_n FROM public.drug_classes
   WHERE (active_ingredient ILIKE 'Dinoprost%'   AND farmakolojik_sinif_kodu = 'PGF2A')
      OR (active_ingredient ILIKE 'Kloprostenol%' AND farmakolojik_sinif_kodu = 'PGF2A')
      OR (active_ingredient ILIKE 'Gonadorelin%'  AND farmakolojik_sinif_kodu = 'GNRH')
      OR (active_ingredient ILIKE 'Buserelin%'    AND farmakolojik_sinif_kodu = 'GNRH')
      OR (active_ingredient ILIKE 'Oksitosin%'    AND farmakolojik_sinif_kodu = 'OKSITOSIN')
      OR (active_ingredient ILIKE 'Progesteron%'  AND farmakolojik_sinif_kodu = 'PROGESTERON');
  PERFORM pg_temp.kb_ok(v_n = 6, 'S2-backfill', '6 kodlu satır', v_n::text);
  SELECT etken_kod, farmakolojik_sinif_kodu INTO v_ek, v_kod FROM public.drug_classes
   WHERE active_ingredient ILIKE 'Kloprostenol%';
  PERFORM pg_temp.kb_ok(v_ek = 'PG' AND v_kod = 'PGF2A', 'S2-backfill',
    'Kloprostenol etken_kod=PG, kod=PGF2A', format('%s/%s', v_ek, v_kod));
  -- KÖ: bugün BELIRSIZ üreten (ürün bağı olmayan PG adlı) stok 0
  SELECT count(*) INTO v_n FROM public.stok s
   WHERE s.id NOT LIKE 'KB-%' AND public._pg_urun_durumu(s.id, NULL) = 'BELIRSIZ';
  PERFORM pg_temp.kb_ok(v_n = 0, 'S2-belirsiz-0', 'BELIRSIZ stok 0', v_n::text);
  RAISE NOTICE 'PASS S2-backfill: 6 sistem etken madde kodlu, Kloprostenol etken_kod NULL→PG, BELIRSIZ stok 0';
END $t$;

-- S-3: şablon ailesi (OVSYNC tek aktif şablon)
DO $t$
DECLARE v_n int; v_aile text;
BEGIN
  SELECT protokol_ailesi INTO v_aile FROM public.tedavi_sablonu WHERE id = pg_temp.kb_c('OVSYNC_SABLON')::uuid;
  PERFORM pg_temp.kb_ok(v_aile = 'OVSYNC', 'S3-sema', 'Ovsynch şablonu protokol_ailesi=OVSYNC', v_aile);
  SELECT count(*) INTO v_n FROM public.tedavi_sablonu WHERE protokol_ailesi = 'OVSYNC' AND aktif;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S3-sema', 'tek aktif OVSYNC şablonu', v_n::text);
  RAISE NOTICE 'PASS S3-sema: Ovsynch şablonu OVSYNC, tek aktif';
END $t$;

-- T11: PG kimliği (farmakolojik sınıf; etken_kod NULL bypass değil) + _pg_urun_durumu dalları
DO $t$
DECLARE
  v_dal  text := pg_temp.kb_id('KB-STK');
  v_bel  text := pg_temp.kb_id('KB-STK');
  v_bag  text := pg_temp.kb_id('KB-STK');
BEGIN
  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar, drug_product_id)
  VALUES (v_dal, 'KB Dalmazin', 'Diğer İlaç', 50, pg_temp.kb_c('DALMAZIN_URUN')::uuid),
         (v_bel, 'KB Enzaprost yeni', 'Diğer İlaç', 50, NULL),
         (v_bag, 'KB Vitamin', 'Vitamin', 50, NULL);
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(v_dal, NULL) = 'PG', 'T11', 'Dalmazin (dinoprost) → PG', public._pg_urun_durumu(v_dal, NULL));
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(pg_temp.kb_c('PG_STOK'), NULL) = 'PG', 'T11', 'PGs (alke) (kloprostenol) → PG', public._pg_urun_durumu(pg_temp.kb_c('PG_STOK'), NULL));
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(NULL, pg_temp.kb_c('PG_URUN')::uuid) = 'PG', 'T11', 'stoksuz PG ürünü → PG', public._pg_urun_durumu(NULL, pg_temp.kb_c('PG_URUN')::uuid));
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(pg_temp.kb_c('FLU_STOK'), NULL) = 'DEGIL', 'T11', 'Flunixin → DEGIL', public._pg_urun_durumu(pg_temp.kb_c('FLU_STOK'), NULL));
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(v_bel, NULL) = 'BELIRSIZ', 'T11', 'ürünsüz PG adlı stok → BELIRSIZ', public._pg_urun_durumu(v_bel, NULL));
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(v_bag, NULL) = 'DEGIL', 'T11', 'ürünsüz PG-dışı stok → DEGIL', public._pg_urun_durumu(v_bag, NULL));
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu('KB-YOK-STOK', NULL) = 'BELIRSIZ', 'T11', 'bulunamayan stok → BELIRSIZ', public._pg_urun_durumu('KB-YOK-STOK', NULL));
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(NULL, gen_random_uuid()) = 'BELIRSIZ', 'T11', 'kataloğa çözülmeyen ürün → BELIRSIZ', public._pg_urun_durumu(NULL, gen_random_uuid()));
  RAISE NOTICE 'PASS T11: Dalmazin/PGs → PG (sınıf kodu), Flunixin DEGIL, çözülemeyen → BELIRSIZ (fail-closed)';
END $t$;

-- T23 + KATALOG_SINIF_KODU_KILITLI: sistem kaydı RPC/REST ile değişmez/silinmez
DO $t$
DECLARE
  v_klop uuid; v_prog uuid; v_diger uuid; v_hata text; v_r jsonb; v_grp text;
BEGIN
  SELECT id INTO v_klop FROM public.drug_classes WHERE active_ingredient ILIKE 'Kloprostenol%';
  SELECT id INTO v_prog FROM public.drug_classes WHERE active_ingredient ILIKE 'Progesteron%';
  SELECT id INTO v_diger FROM public.drug_classes WHERE NOT sistem ORDER BY id LIMIT 1;

  -- RPC: drug_class_guncelle (etken madde adı değişimi)
  v_hata := NULL;
  BEGIN
    PERFORM public.drug_class_guncelle(p_id := v_klop, p_active_ingredient := 'KB Değişmiş');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'SISTEM_ETKEN_MADDE:%', 'T23', 'drug_class_guncelle → SISTEM_ETKEN_MADDE', v_hata);

  -- RPC: drug_class_sil (preparatı olmayan sistem satırı → trigger reddi)
  v_hata := NULL;
  BEGIN
    PERFORM public.drug_class_sil(v_prog);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'SISTEM_ETKEN_MADDE:%', 'T23', 'drug_class_sil → SISTEM_ETKEN_MADDE', v_hata);

  -- REST eşdeğeri: doğrudan UPDATE / DELETE
  v_hata := NULL;
  BEGIN
    UPDATE public.drug_classes SET etken_kod = NULL WHERE id = v_klop;
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'SISTEM_ETKEN_MADDE:%', 'T23', 'UPDATE etken_kod → SISTEM_ETKEN_MADDE', v_hata);
  v_hata := NULL;
  BEGIN
    DELETE FROM public.drug_classes WHERE id = v_prog;
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'SISTEM_ETKEN_MADDE:%', 'T23', 'DELETE → SISTEM_ETKEN_MADDE', v_hata);

  -- Sınıf kodu / sistem bayrağı HER satırda kilitli
  v_hata := NULL;
  BEGIN
    UPDATE public.drug_classes SET farmakolojik_sinif_kodu = 'PGF2A' WHERE id = v_diger;
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'KATALOG_SINIF_KODU_KILITLI:%', 'T23', 'sistem-dışı satırda kod UPDATE → KATALOG_SINIF_KODU_KILITLI', v_hata);
  v_hata := NULL;
  BEGIN
    UPDATE public.drug_classes SET sistem = true WHERE id = v_diger;
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'KATALOG_SINIF_KODU_KILITLI:%', 'T23', 'sistem bayrağı UPDATE → KATALOG_SINIF_KODU_KILITLI', v_hata);

  -- group_name serbest (grup yeniden adlandırma çalışır)
  v_r := public.drug_class_guncelle(p_id := v_klop, p_group_name := 'KB Grup Yeni Ad');
  SELECT group_name INTO v_grp FROM public.drug_classes WHERE id = v_klop;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_grp = 'KB Grup Yeni Ad', 'T23', 'sistem satırında group_name serbest', v_r::text || ' ' || v_grp);

  -- Bakım kaçışı
  PERFORM set_config('egesut.katalog_bakim', 'on', true);
  UPDATE public.drug_classes SET group_name = 'Hormonlar ve Üreme İlaçları', etken_kod = 'PG' WHERE id = v_klop;
  PERFORM set_config('egesut.katalog_bakim', 'off', true);
  RAISE NOTICE 'PASS T23: sistem etken maddesi RPC/UPDATE/DELETE açık hatayla reddedilir; sınıf kodu tüm satırlarda kilitli; group_name serbest; bakım kaçışı çalışır';
END $t$;

-- S-2: drug_class_ekle yeni imza + kod mirası
DO $t$
DECLARE v_r jsonb; v_kod text; v_n int; v_urun uuid := gen_random_uuid(); v_stok text := pg_temp.kb_id('KB-STK');
BEGIN
  SELECT count(*) INTO v_n FROM pg_proc WHERE proname = 'drug_class_ekle' AND pronamespace = 'public'::regnamespace;
  PERFORM pg_temp.kb_ok(v_n = 1 AND to_regprocedure('public.drug_class_ekle(text,text,text,uuid,text)') IS NOT NULL,
    'S2-ekle', 'tek overload (5 argüman)', v_n::text);
  -- eski frontend çağrısı (isimli 3 argüman) + miras
  v_r := public.drug_class_ekle(p_group_name := 'Hormonlar ve Üreme İlaçları', p_class_name := 'Prostaglandinler',
                                p_active_ingredient := 'KB Yeni Prostaglandin');
  SELECT farmakolojik_sinif_kodu INTO v_kod FROM public.drug_classes WHERE id = (v_r->>'id')::uuid;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_kod = 'PGF2A' AND v_r->>'farmakolojik_sinif_kodu' = 'PGF2A',
    'S2-ekle', 'Prostaglandinler altına eklenen → PGF2A (miras)', v_r::text);
  -- yeni madde ile ürün+stok → kapıya girer
  INSERT INTO public.drug_products (id, drug_class_id, brand_name) VALUES (v_urun, (v_r->>'id')::uuid, 'KB Yeni PG Marka');
  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar, drug_product_id) VALUES (v_stok, 'KB Yeni PG Marka', 'Diğer İlaç', 10, v_urun);
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(v_stok, NULL) = 'PG', 'S2-ekle', 'miras kodlu yeni ürün → PG', public._pg_urun_durumu(v_stok, NULL));
  -- kodsuz sınıfa eklenen → NULL
  v_r := public.drug_class_ekle(p_group_name := 'KB Grup', p_class_name := 'KB Sınıf', p_active_ingredient := 'KB Madde');
  SELECT farmakolojik_sinif_kodu INTO v_kod FROM public.drug_classes WHERE id = (v_r->>'id')::uuid;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_kod IS NULL, 'S2-ekle', 'kodsuz sınıf → NULL', v_r::text);
  -- geçersiz kod → ok:false
  v_r := public.drug_class_ekle('KB Grup', 'KB Sınıf', 'KB Madde 2', NULL, 'XYZ');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean IS FALSE, 'S2-ekle', 'geçersiz kod → ok:false', v_r::text);
  RAISE NOTICE 'PASS S2-ekle: drug_class_ekle 5 argüman, isimli 3 argüman çözülür, kategoriden PGF2A mirası, geçersiz kod reddi';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 1 — BAYRAK 0 (MK5: eski davranış; yalnız S-3 damgası + S-6 + önizleme)
-- ════════════════════════════════════════════════════════════════════════════

-- S-10: D11 → D39 (gövde assert'i + yeni doğum 2/25/39 PG, 11 yok + tarayıcı)
DO $t$
DECLARE
  v_def text; v_a text := pg_temp.kb_hayvan(); v_r jsonb; v_d date := CURRENT_DATE - 45;
  v_gunler int[]; v_n int; v_tara jsonb;
BEGIN
  v_def := pg_get_functiondef('public.dogum_kaydet(text,date,text,text,text,numeric,text,text)'::regprocedure);
  PERFORM pg_temp.kb_ok(v_def !~ 'p_tarih \+ 11\M', 'S10', 'dogum_kaydet gövdesi "+ 11" içermez', 'içeriyor');
  PERFORM pg_temp.kb_ok(v_def ~ 'p_tarih \+ 39\M' AND v_def LIKE '%39. Gün PG (Presynch-14 senkron)%', 'S10', 'gövde "+ 39" ve tarayıcı açıklamasını içerir', 'yok');

  v_r := public.dogum_kaydet(v_a, v_d, pg_temp.kb_id('KBY'));
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'gorev_sayisi')::int = 15, 'S10', 'ok, gorev_sayisi 15', v_r::text);
  SELECT array_agg(hedef_tarih - v_d ORDER BY hedef_tarih) INTO v_gunler
    FROM public.gorev_log WHERE hayvan_id = v_a AND etken_kod = 'PG';
  PERFORM pg_temp.kb_ok(v_gunler = ARRAY[2,25,39], 'S10', 'PG görev günleri {2,25,39}', v_gunler::text);
  -- MK5: bayrak 0 → ilk tohumlama rotası yok
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'OVSYNC_BASLAT';
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK5-dogum', 'bayrak 0: OVSYNC_BASLAT yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.protokol_instance WHERE hayvan_id = v_a AND alttip = 'ILK_TOHUMLAMA';
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK5-dogum', 'bayrak 0: ILK_TOHUMLAMA instance yok', v_n::text);

  -- protokol_eksik_tara: PG adımları yapılmışsa (görevler kapalı) eksik PG raporlamaz
  UPDATE public.gorev_log SET tamamlandi = true, tamamlanma_tarihi = now() - interval '3 days'
   WHERE hayvan_id = v_a AND etken_kod = 'PG';
  v_tara := public.protokol_eksik_tara();
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_tara) e
   WHERE e->>'hayvan_id' = v_a AND e->>'etken_kod' = 'PG' AND e->>'durum' = 'eksik';
  PERFORM pg_temp.kb_ok(v_n = 0, 'S10', 'protokol_eksik_tara eksik PG raporlamaz', v_n::text);
  RAISE NOTICE 'PASS S10: gövde D39 (D11 yok); yeni doğum PG 2/25/39; tarayıcı eksik PG raporlamaz; bayrak 0 rota yok (MK5)';
END $t$;

-- MK5 S-4: bayrak 0 → hizli_uygulama / bulk_ilac / seans_tamamla / geri_al eski davranış
DO $t$
DECLARE
  v_g text := pg_temp.kb_hayvan(); v_c text := pg_temp.kb_hayvan(); v_r jsonb; v_n int;
  v_stok text := pg_temp.kb_id('KB-STK'); v_case uuid; v_seans uuid; v_toh uuid;
BEGIN
  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar, drug_product_id)
  VALUES (v_stok, 'KB PG MK5', 'Diğer İlaç', 100, pg_temp.kb_c('PG_URUN')::uuid);
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_g, CURRENT_DATE - 60, 'Gebe', 'KB-SP') RETURNING id INTO v_toh;
  PERFORM pg_temp.kb_ok(public._pg_kapi(v_g, v_stok, NULL, false)->>'karar' = 'KAPALI', 'MK5-kapi', '_pg_kapi → KAPALI', public._pg_kapi(v_g, v_stok, NULL, false)::text);

  -- hizli_uygulama: 6 pozisyonel argüman (asistan kalıbı), Gebe + PG → geçer (eski davranış)
  v_r := public.hizli_uygulama(v_g, v_stok, 2, 'ml', 'IM', 'kb mk5');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(v_r) k) = ARRAY['etken_kod','id','ok','stok_kalan'],
    'MK5-hizli', 'ok + {etken_kod,id,ok,stok_kalan}', v_r::text);
  -- geri al (bayrak 0)
  v_r := public.hizli_uygulama_geri_al((v_r->>'id')::uuid);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'MK5-geri-al', 'ok', v_r::text);

  -- bulk_ilac: 4 isimli argüman (forms.js kalıbı), Gebe dahil ikisi de uygulanır
  v_r := public.bulk_ilac(p_animal_ids := ARRAY[v_g, v_c], p_ilac_stok_id := v_stok, p_miktar := 2, p_notlar := 'kb mk5');
  PERFORM pg_temp.kb_ok((v_r->>'success')::int = 2 AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(v_r) k) = ARRAY['errors','ok','success','total'],
    'MK5-bulk', 'success 2, anahtarlar {errors,ok,success,total}', v_r::text);

  -- seans_tamamla (3 isimli argüman), Gebe + PG seansı → tamamlanır
  v_case := pg_temp.kb_ovsync_vaka(v_g);
  SELECT id INTO v_seans FROM public.treatment_day_uygulamalar WHERE case_id = v_case AND stok_id = pg_temp.kb_c('PG_STOK') ORDER BY planned_date LIMIT 1;
  v_r := public.seans_tamamla(p_seans_admin_id := v_seans, p_uygulanmadi := false, p_not := NULL);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'MK5-seans', 'Gebe + PG seansı tamamlanır', v_r::text);

  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id IN (v_g, v_c);
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK5-S4', 'pg_application_event yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id IN (v_g, v_c) AND kaynak LIKE 'PG_TOHUMLAMA:%';
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK5-S4', 'PG_TOHUMLAMA görevi yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE ana_hayvan_id IN (v_g, v_c) AND tip LIKE 'PG\_%';
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK5-S4', 'PG_* islem_log yok', v_n::text);
  RAISE NOTICE 'PASS MK5-S4: bayrak 0 → dört uygulama yolu eski davranış (event/görev/log yok, dönüş anahtarları aynı)';
END $t$;

-- S-3 (bayraktan bağımsız) provenance + ikinci şablon ezmez + T02 Mastit NULL; MK5 S-7 tohumlama_kaydet
DO $t$
DECLARE
  v_a text := pg_temp.kb_hayvan(); v_case uuid; v_mastit uuid; v_c record; v_r jsonb; v_gorev uuid; v_n int;
BEGIN
  v_case := pg_temp.kb_ovsync_vaka(v_a);
  SELECT * INTO v_c FROM public.cases WHERE id = v_case;
  PERFORM pg_temp.kb_ok(v_c.source_template_id = pg_temp.kb_c('OVSYNC_SABLON')::uuid AND v_c.protocol_family = 'OVSYNC',
    'S3-prov', 'source_template_id=Ovsync, protocol_family=OVSYNC', format('%s/%s', v_c.source_template_id, v_c.protocol_family));
  PERFORM pg_temp.kb_ok(v_c.protocol_snapshot ?& ARRAY['sablon_id','ad','protokol_ailesi','tohumlama_plani','kalemler','uygulama_at','baslangic']
                        AND jsonb_array_length(v_c.protocol_snapshot->'kalemler') = 4
                        AND (v_c.protocol_snapshot->>'baslangic')::date = v_c.start_date,
    'S3-prov', 'snapshot {sablon_id,ad,protokol_ailesi,tohumlama_plani,kalemler[4],uygulama_at,baslangic}', v_c.protocol_snapshot::text);
  -- ikinci şablon uygulaması ilkini ezmez
  v_r := public.tedavi_sablon_uygula(v_case, pg_temp.kb_c('MASTIT_SABLON')::uuid);
  SELECT * INTO v_c FROM public.cases WHERE id = v_case;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_c.source_template_id = pg_temp.kb_c('OVSYNC_SABLON')::uuid
                        AND v_c.protocol_snapshot->>'sablon_id' = pg_temp.kb_c('OVSYNC_SABLON') AND v_c.protocol_family = 'OVSYNC',
    'S3-ezmez', 'ikinci şablon provenance''ı ezmez', format('%s %s', v_c.source_template_id, v_c.protocol_snapshot->>'ad'));
  -- T02: Mastit vakası protocol_family NULL
  v_r := public.vaka_toplu_ac(p_animal_ids := ARRAY[v_a], p_disease_id := pg_temp.kb_c('MASTIT_HASTALIK')::uuid,
                              p_sablon_id := pg_temp.kb_c('MASTIT_SABLON')::uuid);
  v_mastit := (v_r->'acilan'->0->>'case_id')::uuid;
  SELECT * INTO v_c FROM public.cases WHERE id = v_mastit;
  PERFORM pg_temp.kb_ok(v_c.protocol_family IS NULL AND v_c.source_template_id = pg_temp.kb_c('MASTIT_SABLON')::uuid,
    'T02-S3', 'Mastit: protocol_family NULL, kaynak şablon damgalı', format('%s/%s', v_c.protocol_family, v_c.source_template_id));

  -- MK5 S-7: bayrak 0 → tohumlama vakayı kapatmaz, dönüşte yeni anahtar yok, OVSYNC_BASLAT dokunulmaz
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (v_a, 'OVSYNC_BASLAT', 'kb', CURRENT_DATE + 3, '10:00', false, false, pg_temp.kb_id('ILK-TOH-KB')) RETURNING id INTO v_gorev;
  v_r := public.tohumlama_kaydet(v_a, CURRENT_DATE, 'KB-SP');
  PERFORM pg_temp.kb_ok(NOT (v_r ? 'kapatilan_senkronizasyon_vakalari')
                        AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(v_r) k)
                            = ARRAY['deneme_no','inst_id','ok','otomatik_bos_sayisi','otomatik_iptal_instance','tohumlama_id'],
    'MK5-S7', 'dönüş eski 6 anahtar', v_r::text);
  SELECT count(*) INTO v_n FROM public.cases WHERE animal_id = v_a AND status = 'active';
  PERFORM pg_temp.kb_ok(v_n = 2, 'MK5-S7', 'iki vaka da aktif', v_n::text);
  -- temizlik yolu bayraktan bağımsız: açık OVSYNC_BASLAT tohumlamayla muaf edilir
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_gorev AND iptal AND tamamlandi AND kapatan_ref = 'ILK_TOH_MUAF:TOHUMLAMA';
  PERFORM pg_temp.kb_ok(v_n = 1, 'MK5-S7', 'bayrak 0: OVSYNC_BASLAT temizliği yine çalışır (ILK_TOH_MUAF:TOHUMLAMA)', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE ana_hayvan_id = v_a AND tip = 'CASE_CLOSED_BY_TOHUMLAMA';
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK5-S7', 'CASE_CLOSED_BY_TOHUMLAMA yok', v_n::text);
  RAISE NOTICE 'PASS S3/T02/MK5-S7: provenance damgası (bayrak 0), ikinci şablon ezmez, Mastit NULL; bayrak 0 tohumlama vakayı kapatmaz (OVSYNC_BASLAT temizliği çalışır)';
END $t$;

-- R3.1 (#12): ilk şablon ailesiz (Mastit) → protocol_family NULL kalır; ikinci
-- şablon (Ovsync) uygulanınca source_template_id EZİLMEZ (Mastit kalır),
-- yalnız protocol_family ayrı UPDATE ile doldurulur.
DO $t$
DECLARE v_a text := pg_temp.kb_hayvan(); v_r jsonb; v_case uuid; v_c record;
BEGIN
  v_r := public.vaka_toplu_ac(p_animal_ids := ARRAY[v_a], p_disease_id := pg_temp.kb_c('MASTIT_HASTALIK')::uuid,
                              p_sablon_id := pg_temp.kb_c('MASTIT_SABLON')::uuid);
  v_case := (v_r->'acilan'->0->>'case_id')::uuid;
  SELECT * INTO v_c FROM public.cases WHERE id = v_case;
  PERFORM pg_temp.kb_ok(v_c.source_template_id = pg_temp.kb_c('MASTIT_SABLON')::uuid AND v_c.protocol_family IS NULL,
    'R3.1-12', 'fixture: Mastit damgalı, protocol_family NULL', row_to_json(v_c)::text);
  v_r := public.tedavi_sablon_uygula(v_case, pg_temp.kb_c('OVSYNC_SABLON')::uuid);
  SELECT * INTO v_c FROM public.cases WHERE id = v_case;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_c.source_template_id = pg_temp.kb_c('MASTIT_SABLON')::uuid
                        AND v_c.protocol_family = 'OVSYNC' AND v_c.protocol_snapshot->>'sablon_id' = pg_temp.kb_c('MASTIT_SABLON'),
    'R3.1-12', 'source_template_id ezilmez (Mastit kalır), protocol_family geç-doldurulur (OVSYNC)', row_to_json(v_c)::text);
  RAISE NOTICE 'PASS R3.1-12: ikinci şablon ailesi, boş protocol_family''ı doldurur; provenance ezilmez';
END $t$;

-- MK5 S-8 (abort/start/zamanlayıcı) + S-6 ve önizleme bayraktan bağımsız
DO $t$
DECLARE
  v_b text := pg_temp.kb_hayvan(); v_toh uuid; v_r jsonb; v_n int; v_hata text; v_g uuid; v_gebe text := pg_temp.kb_hayvan();
BEGIN
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_b, CURRENT_DATE - 60, 'Gebe', 'KB-SP') RETURNING id INTO v_toh;
  v_r := public.tohumlama_abort(p_tohumlama_id := v_toh::text, p_notlar := 'kb', p_abort_tarihi := CURRENT_DATE - 3);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'MK5-abort', 'abort ok', v_r::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_b AND gorev_tipi = 'OVSYNC_BASLAT';
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK5-abort', 'bayrak 0: OVSYNC_BASLAT yok', v_n::text);

  v_hata := NULL;
  BEGIN PERFORM public.start_first_service_protocol(gen_random_uuid());
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'OZELLIK_KAPALI:%', 'MK5-start', 'OZELLIK_KAPALI', v_hata);
  v_r := public.ilk_tohumlama_zamanlayici();
  PERFORM pg_temp.kb_ok(v_r = '{"ok": true, "atlandi": "KAPALI"}'::jsonb, 'MK5-cron', '{ok:true, atlandi:KAPALI}', v_r::text);

  -- pg_uyari_kontrol bayraktan bağımsız
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_gebe, CURRENT_DATE - 40, 'Gebe', 'KB-SP');
  v_r := public.pg_uyari_kontrol(ARRAY[v_gebe], pg_temp.kb_c('PG_STOK'));
  PERFORM pg_temp.kb_ok(v_r->>'pg' = 'PG' AND v_r->'hayvanlar'->0->>'karar' = 'BLOCK_PREGNANT', 'MK5-onizleme', 'bayrak 0: önizleme BLOCK_PREGNANT', v_r::text);

  -- tohumlama_gorev_ertele bayraktan bağımsız
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (v_b, 'TOHUMLAMA_PLANLI', 'kb', CURRENT_DATE + 2, '10:00', false, false, 'MANUEL-KB') RETURNING id INTO v_g;
  v_r := public.tohumlama_gorev_ertele(v_g, CURRENT_DATE + 3, NULL);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'hedef_tarih')::date = CURRENT_DATE + 3, 'MK5-ertele', 'bayrak 0: erteleme çalışır', v_r::text);
  RAISE NOTICE 'PASS MK5-S8: bayrak 0 abort rota kurmaz, start OZELLIK_KAPALI, zamanlayıcı KAPALI; önizleme ve erteleme bayraktan bağımsız';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BAYRAK 1
-- ════════════════════════════════════════════════════════════════════════════
UPDATE public.protokol_ayar SET deger = 1 WHERE anahtar = 'ovsync_pg_kurallari_aktif';

DO $t$
BEGIN
  PERFORM pg_temp.kb_ok(public._ovsync_pg_aktif(), 'S1-c', 'bayrak 1 → true', public._ovsync_pg_aktif()::text);
  RAISE NOTICE 'PASS S1-c: bayrak açıldı';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 2 — S-4 PG güvenlik kapısı ve gerçekleşme kaydı
-- ════════════════════════════════════════════════════════════════════════════

-- T06: Gebe + hızlı PG → açık ret; uygulama/stok/event/görev YOK. Gebe + PG-dışı → geçer.
DO $t$
DECLARE
  v_g text := pg_temp.kb_hayvan(); v_toh uuid; v_r jsonb; v_hata text; v_det jsonb; v_n int;
BEGIN
  v_r := public.tohumlama_kaydet(v_g, CURRENT_DATE - 40, 'KB-SP');
  v_toh := (v_r->>'tohumlama_id')::uuid;
  v_r := public.tohumlama_sonuc_gebe(v_toh::text);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'T06', 'fixture gebe', v_r::text);

  v_hata := NULL;
  BEGIN
    PERFORM public.hizli_uygulama(v_g, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb t06');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'PG_KAPI:BLOCK_PREGNANT:%', 'T06', 'PG_KAPI:BLOCK_PREGNANT:<json>', v_hata);
  v_det := substr(v_hata, length('PG_KAPI:BLOCK_PREGNANT:') + 1)::jsonb;
  PERFORM pg_temp.kb_ok(v_det->>'hayvan_id' = v_g AND v_det->>'kupe_no' = v_g AND v_det->>'tohumlama_id' = v_toh::text
                        AND (v_det->>'gun')::int = 40 AND v_det ? 'tohumlama_tarihi',
    'T06', 'detay {hayvan_id,kupe_no,tohumlama_id,gun=40,…}', v_det::text);

  SELECT count(*) INTO v_n FROM public.uygulama_log WHERE hayvan_id = v_g;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T06', 'uygulama_log yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.stok_hareket WHERE notlar LIKE 'Hızlı Uygulama — ' || v_g || '%';
  PERFORM pg_temp.kb_ok(v_n = 0, 'T06', 'stok hareketi yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_g;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T06', 'event yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_g AND gorev_tipi = 'TOHUMLAMA_PLANLI';
  PERFORM pg_temp.kb_ok(v_n = 0, 'T06', 'yeni görev yok', v_n::text);

  v_r := public.hizli_uygulama(v_g, pg_temp.kb_c('FLU_STOK'), 5, 'ml', 'IM', 'kb t06 flu');
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_g;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_n = 0, 'T06', 'Gebe + Flunixin geçer, event yok', v_r::text);
  RAISE NOTICE 'PASS T06: Gebe + hızlı PG → PG_KAPI:BLOCK_PREGNANT, yazma yok; PG-dışı ilaç geçer';
END $t$;

-- T07: Gebe + seans PG → aynı kural; seans açık kalır, stok değişmez; uygulanmadı yolu kapısız
DO $t$
DECLARE
  v_g text := pg_temp.kb_hayvan(); v_case uuid; v_seans uuid; v_hata text; v_det jsonb; v_n int; v_r jsonb; v_sh_once int; v_sh_sonra int;
BEGIN
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_g, CURRENT_DATE - 70, 'Gebe', 'KB-SP');
  v_case := pg_temp.kb_ovsync_vaka(v_g);
  SELECT id INTO v_seans FROM public.treatment_day_uygulamalar WHERE case_id = v_case AND stok_id = pg_temp.kb_c('PG_STOK') ORDER BY planned_date LIMIT 1;
  SELECT count(*) INTO v_sh_once FROM public.stok_hareket sh JOIN public.drug_administrations da ON sh.notlar = 'drug_admin:' || da.id::text
   WHERE da.seans_admin_id = v_seans AND NOT sh.iptal;

  v_hata := NULL;
  BEGIN
    PERFORM public.seans_tamamla(p_seans_admin_id := v_seans, p_uygulanmadi := false, p_not := NULL);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'PG_KAPI:BLOCK_PREGNANT:%', 'T07', 'PG_KAPI:BLOCK_PREGNANT', v_hata);
  v_det := substr(v_hata, length('PG_KAPI:BLOCK_PREGNANT:') + 1)::jsonb;
  PERFORM pg_temp.kb_ok(v_det->>'seans_admin_id' = v_seans::text AND v_det->>'case_id' = v_case::text AND v_det->>'hayvan_id' = v_g,
    'T07', 'detay seans_admin_id/case_id/hayvan_id', v_det::text);
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar WHERE id = v_seans AND uygulama_tamamlandi_at IS NULL AND NOT uygulanmadi;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T07', 'seans açık kalır', v_n::text);
  SELECT count(*) INTO v_sh_sonra FROM public.stok_hareket sh JOIN public.drug_administrations da ON sh.notlar = 'drug_admin:' || da.id::text
   WHERE da.seans_admin_id = v_seans AND NOT sh.iptal;
  PERFORM pg_temp.kb_ok(v_sh_sonra = v_sh_once, 'T07', 'stok hareketi değişmez', format('%s→%s', v_sh_once, v_sh_sonra));
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_g;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T07', 'event yok', v_n::text);

  v_r := public.seans_tamamla(p_seans_admin_id := v_seans, p_uygulanmadi := true, p_not := 'kb gebe');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'T07', 'uygulanmadı yolu kapısız', v_r::text);
  RAISE NOTICE 'PASS T07: Gebe + seans PG → RAISE, seans açık, stok aynı; "uygulanmadı" işaretlenebilir';
END $t$;

-- T08: toplu PG — gebe blocked, onaysız Bekliyor requires_ack, temiz + onaylı applied; stok yalnız uygulananlar
DO $t$
DECLARE
  v_g text := pg_temp.kb_hayvan(); v_b text := pg_temp.kb_hayvan(); v_c text := pg_temp.kb_hayvan(); v_b2 text := pg_temp.kb_hayvan();
  v_stok text := pg_temp.kb_id('KB-STK'); v_r jsonb; v_n int; v_kalan numeric; v_sh numeric; v_ids text[];
BEGIN
  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar, drug_product_id)
  VALUES (v_stok, 'KB PG toplu', 'Diğer İlaç', 100, pg_temp.kb_c('PG_URUN')::uuid);
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES
    (v_g, CURRENT_DATE - 60, 'Gebe', 'KB-SP'), (v_b, CURRENT_DATE - 12, 'Bekliyor', 'KB-SP'), (v_b2, CURRENT_DATE - 30, 'Bekliyor', 'KB-SP');

  v_r := public.bulk_ilac(ARRAY[v_g, v_b, v_c, v_b2], v_stok, 2, 'kb t08', ARRAY[v_b2], 'kb gerekçe');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'total')::int = 4 AND (v_r->>'success')::int = 2
                        AND jsonb_array_length(v_r->'errors') = 0,
    'T08', 'ok, total 4, success 2, errors []', v_r::text);
  SELECT array_agg(e->>'hayvan_id' ORDER BY e->>'hayvan_id') INTO v_ids FROM jsonb_array_elements(v_r->'applied') e;
  PERFORM pg_temp.kb_ok(v_ids = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[v_c, v_b2]) x), 'T08', 'applied = {temiz, onaylı}', v_ids::text);
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_r->'blocked') = 1 AND v_r->'blocked'->0->>'hayvan_id' = v_g
                        AND v_r->'blocked'->0->>'kod' = 'BLOCK_PREGNANT' AND v_r->'blocked'->0 ? 'tohumlama_id',
    'T08', 'blocked = [gebe, BLOCK_PREGNANT, gerekçeli]', v_r->>'blocked');
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_r->'requires_ack') = 1 AND v_r->'requires_ack'->0->>'hayvan_id' = v_b
                        AND v_r->'requires_ack'->0->>'kod' = 'REQUIRE_ACK_PENDING' AND (v_r->'requires_ack'->0->>'gun')::int = 12,
    'T08', 'requires_ack = [Bekliyor, gun 12]', v_r->>'requires_ack');

  SELECT baslangic_miktar INTO v_kalan FROM public.stok WHERE id = v_stok;
  SELECT sum(miktar) INTO v_sh FROM public.stok_hareket WHERE stok_id = v_stok AND NOT iptal;
  PERFORM pg_temp.kb_ok(v_kalan = 96 AND v_sh = 4, 'T08', 'stok 100→96, hareket 4 (2 hayvan × 2)', format('%s / %s', v_kalan, v_sh));
  SELECT count(*) INTO v_n FROM public.islem_log WHERE tip = 'TOPLU_ILAC' AND kullanici_notu = 'kb t08';
  PERFORM pg_temp.kb_ok(v_n = 2, 'T08', '2 TOPLU_ILAC log (yalnız uygulananlar)', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE tip = 'TOPLU_ILAC' AND kullanici_notu = 'kb t08' AND ana_hayvan_id IN (v_g, v_b);
  PERFORM pg_temp.kb_ok(v_n = 0, 'T08', 'atlananlara yazma yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.pg_application_event e JOIN public.islem_log l ON l.id = e.source_id
   WHERE e.source_type = 'TOPLU_ILAC' AND e.hayvan_id IN (v_c, v_b2);
  PERFORM pg_temp.kb_ok(v_n = 2, 'T08', '2 TOPLU_ILAC event, source_id = islem_log id', v_n::text);
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_b2 AND karar = 'ACK_PENDING' AND ack_gerekce = 'kb gerekçe';
  PERFORM pg_temp.kb_ok(v_n = 1, 'T08', 'onaylı hayvan event ACK_PENDING + gerekçe', v_n::text);
  RAISE NOTICE 'PASS T08: toplu PG satır bazında applied/blocked/requires_ack; stok ve log yalnız uygulananlar kadar (MK4 event)';
END $t$;

-- T09: Bekliyor D10/D26/D35 → her yaşta onay şartı; onayla ACK_PENDING + GEBELIK_KONTROL iptali
DO $t$
DECLARE
  v_h text; v_gun int; v_r jsonb; v_hata text; v_toh uuid; v_ev record; v_n int; v_log jsonb;
BEGIN
  FOREACH v_gun IN ARRAY ARRAY[10, 26, 35] LOOP
    v_h := pg_temp.kb_hayvan();
    v_r := public.tohumlama_kaydet(v_h, CURRENT_DATE - v_gun, 'KB-SP');
    v_toh := (v_r->>'tohumlama_id')::uuid;
    v_hata := NULL;
    BEGIN
      PERFORM public.hizli_uygulama(v_h, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb t09');
    EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
    PERFORM pg_temp.kb_ok(v_hata LIKE 'PG_KAPI:REQUIRE_ACK_PENDING:%'
                          AND (substr(v_hata, length('PG_KAPI:REQUIRE_ACK_PENDING:') + 1)::jsonb->>'gun')::int = v_gun,
      'T09', format('D%s onaysız → REQUIRE_ACK_PENDING (gun %s)', v_gun, v_gun), v_hata);
  END LOOP;

  -- son hayvan (D35): onaylı uygulama
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE kaynak = 'TOH-' || v_toh AND gorev_tipi = 'GEBELIK_KONTROL' AND NOT tamamlandi AND NOT iptal;
  PERFORM pg_temp.kb_ok(v_n = 2, 'T09', 'fixture: 2 açık GEBELIK_KONTROL', v_n::text);
  v_r := public.hizli_uygulama(p_hayvan_id := v_h, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                               p_notlar := 'kb t09 onay', p_pg_onay := true, p_pg_gerekce := 'kb kızgınlık görüldü');
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_type = 'HIZLI_UYGULAMA' AND source_id = v_r->>'id';
  PERFORM pg_temp.kb_ok(v_ev.karar = 'ACK_PENDING' AND v_ev.ack_tohumlama_id = v_toh::text AND v_ev.ack_gerekce = 'kb kızgınlık görüldü'
                        AND v_ev.gorev_sonuc = 'OLUSTU',
    'T09', 'event ACK_PENDING, ack_tohumlama_id, gerekçe, görev OLUSTU', row_to_json(v_ev)::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE kaynak = 'TOH-' || v_toh AND gorev_tipi = 'GEBELIK_KONTROL'
     AND iptal AND tamamlandi AND kapatan_ref = 'PG_ONAY:' || v_ev.id;
  PERFORM pg_temp.kb_ok(v_n = 2, 'T09', '2 GEBELIK_KONTROL PG_ONAY ile iptal', v_n::text);
  SELECT payload INTO v_log FROM public.islem_log WHERE tip = 'PG_APPLICATION_ACKNOWLEDGED' AND ref_id = v_ev.id::text;
  PERFORM pg_temp.kb_ok((v_log->>'iptal_gorev_sayisi')::int = 2 AND v_log->>'tohumlama_id' = v_toh::text AND v_log->>'gerekce' = 'kb kızgınlık görüldü',
    'T09', 'PG_APPLICATION_ACKNOWLEDGED payload', v_log::text);
  PERFORM pg_temp.kb_ok((SELECT sonuc FROM public.tohumlama WHERE id = v_toh) = 'Bekliyor', 'T09', 'tohumlama Bekliyor kalır',
    (SELECT sonuc FROM public.tohumlama WHERE id = v_toh));
  RAISE NOTICE 'PASS T09: Bekliyor D10/D26/D35 onaysız ret (25 gün bypass yok); onayla ACK_PENDING + GEBELIK_KONTROL iptali + audit';
END $t$;

-- T10: UI önizleme sonrası gebe değişikliği → commit anında yeniden kontrol; kapı hayvan satırını kilitler
DO $t$
DECLARE
  v_t text := pg_temp.kb_hayvan(); v_r jsonb; v_toh uuid; v_hata text;
BEGIN
  v_r := public.tohumlama_kaydet(v_t, CURRENT_DATE - 30, 'KB-SP');
  v_toh := (v_r->>'tohumlama_id')::uuid;
  v_r := public.pg_uyari_kontrol(ARRAY[v_t], pg_temp.kb_c('PG_STOK'));
  PERFORM pg_temp.kb_ok(v_r->>'pg' = 'PG' AND v_r->'hayvanlar'->0->>'karar' = 'REQUIRE_ACK_PENDING'
                        AND v_r->'hayvanlar'->0->>'kupe_no' = v_t AND (v_r->'hayvanlar'->0->>'gun')::int = 30
                        AND v_r->'hayvanlar'->0->>'tohumlama_id' = v_toh::text AND v_r->'hayvanlar'->0 ? 'sperma'
                        AND v_r->'hayvanlar'->0 ? 'deneme_no' AND v_r->'hayvanlar'->0 ? 'tohumlama_tarihi',
    'T10', 'önizleme {pg:PG, hayvanlar:[{karar:REQUIRE_ACK_PENDING, kupe_no, tohumlama_id, gun:30, sperma, deneme_no,…}]}', v_r::text);
  v_r := public.pg_uyari_kontrol(ARRAY[v_t, 'KB-YOK-HAYVAN'], pg_temp.kb_c('PG_STOK'));
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_r->'hayvanlar') = 2 AND v_r->'hayvanlar'->1->>'hayvan_id' = 'KB-YOK-HAYVAN'
                        AND v_r->'hayvanlar'->1->>'karar' = 'HAYVAN_BULUNAMADI',
    'T10', 'bilinmeyen hayvan → karar HAYVAN_BULUNAMADI satırı (RAISE yok)', v_r::text);
  -- önizlemeden sonra gebelik onaylanır
  v_r := public.tohumlama_sonuc_gebe(v_toh::text);
  v_hata := NULL;
  BEGIN
    PERFORM public.hizli_uygulama(v_t, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb t10', true, 'eski önizleme onayı');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'PG_KAPI:BLOCK_PREGNANT:%', 'T10', 'commit yeniden kontrol → BLOCK_PREGNANT (onay gebeyi aşamaz)', v_hata);
  v_r := public.bulk_ilac(ARRAY[v_t], pg_temp.kb_c('PG_STOK'), 2, 'kb t10', ARRAY[v_t], 'x');
  PERFORM pg_temp.kb_ok((v_r->>'success')::int = 0 AND v_r->'blocked'->0->>'kod' = 'BLOCK_PREGNANT', 'T10', 'toplu yolda da satır reddi', v_r::text);
  -- TOCTOU: kapı hayvan satırını FOR UPDATE kilitler (tek oturumda eşzamanlılık kurulamaz →
  -- gövde assert'i; aynı transaction'daki xmax kilit kanıtı değildir)
  PERFORM pg_temp.kb_ok(pg_get_functiondef('public._pg_kapi(text,text,uuid,boolean)'::regprocedure) ~ 'FROM public\.hayvanlar h WHERE h\.id = p_hayvan_id FOR (NO KEY )?UPDATE',
    'T10', '_pg_kapi hayvan satırını FOR [NO KEY] UPDATE ile kilitler', 'kilit yok');
  RAISE NOTICE 'PASS T10: önizleme sonrası gebe değişikliği commit anında reddedilir (tekil+toplu); kapı hayvan satırını kilitler';
END $t$;

-- T30 (DB kısmı): [Boş ata] = tohumlama_sonuc_bos (2 argüman) → PG riskten düşer
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_r jsonb; v_toh uuid;
BEGIN
  v_r := public.tohumlama_kaydet(v_h, CURRENT_DATE - 31, 'KB-SP');
  v_toh := (v_r->>'tohumlama_id')::uuid;
  PERFORM pg_temp.kb_ok(public.pg_uyari_kontrol(ARRAY[v_h], pg_temp.kb_c('PG_STOK'))->'hayvanlar'->0->>'karar' = 'REQUIRE_ACK_PENDING', 'T30', '31 gün Bekliyor → uyarı', NULL);
  v_r := public.tohumlama_sonuc_bos(v_toh::text, 'kb boş ata');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'T30', 'tohumlama_sonuc_bos ok', v_r::text);
  v_r := public.pg_uyari_kontrol(ARRAY[v_h], pg_temp.kb_c('PG_STOK'));
  PERFORM pg_temp.kb_ok(v_r->'hayvanlar'->0->>'karar' = 'ALLOW' AND v_r->'hayvanlar'->0->>'tohumlama_sonuc' = 'Boş', 'T30', 'Boş → ALLOW', v_r::text);
  v_r := public.hizli_uygulama(v_h, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb t30');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'T30', 'onaysız PG geçer', v_r::text);
  RAISE NOTICE 'PASS T30-DB: Boş ata (tohumlama_sonuc_bos) sonrası önizleme ALLOW, PG onaysız geçer';
END $t$;

-- MK3: tohumlama_durumu='gebe' ama son sonuç 'Doğum Yaptı' → ALLOW (kolon kapıda kullanılmaz)
DO $t$
DECLARE v_m text := pg_temp.kb_hayvan(); v_r jsonb; v_ev record;
BEGIN
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_m, CURRENT_DATE - 310, 'Gebe', 'KB-SP');
  v_r := public.dogum_kaydet(v_m, CURRENT_DATE - 30, pg_temp.kb_id('KBY'));
  UPDATE public.hayvanlar SET tohumlama_durumu = 'gebe' WHERE id = v_m;
  PERFORM pg_temp.kb_ok((SELECT sonuc FROM public.tohumlama WHERE hayvan_id = v_m) = 'Doğum Yaptı', 'MK3', 'fixture son sonuç Doğum Yaptı', NULL);
  v_r := public.hizli_uygulama(v_m, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb mk3');
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_id = v_r->>'id';
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_ev.karar = 'ALLOW', 'MK3', 'ALLOW', coalesce(row_to_json(v_ev)::text, v_r::text));
  RAISE NOTICE 'PASS MK3: tohumlama_durumu=gebe + son sonuç Doğum Yaptı → ALLOW';
END $t$;

-- BLOCK_CATALOG_UNRESOLVED: çözülemeyen katalog → tekil yolda fail-closed ret
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_stok text := pg_temp.kb_id('KB-STK'); v_hata text; v_n int;
BEGIN
  INSERT INTO public.stok (id, urun_adi, kategori, baslangic_miktar) VALUES (v_stok, 'KB Lutalyse ürünsüz', 'Diğer İlaç', 10);
  v_hata := NULL;
  BEGIN PERFORM public.hizli_uygulama(v_h, v_stok, 2, 'ml', 'IM', 'kb bel');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'PG_KAPI:BLOCK_CATALOG_UNRESOLVED:%', 'T11-fc', 'PG_KAPI:BLOCK_CATALOG_UNRESOLVED', v_hata);
  SELECT count(*) INTO v_n FROM public.uygulama_log WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T11-fc', 'uygulama yok', v_n::text);
  RAISE NOTICE 'PASS T11-fc: BELIRSIZ katalog tekil yolda fail-closed';
END $t$;

-- S-4: ilaç bilgisi olmayan seans (stok_id ve drug_product_id NULL) → DEGIL, kapıdan geçer
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_r jsonb; v_case uuid; v_seans uuid; v_n int;
BEGIN
  PERFORM pg_temp.kb_ok(public._pg_urun_durumu(NULL, NULL) = 'DEGIL', 'R3.1-ilacsiz', '_pg_urun_durumu(NULL,NULL) → DEGIL', public._pg_urun_durumu(NULL, NULL));
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_h, CURRENT_DATE - 60, 'Gebe', 'KB-SP');
  v_r := public._vaka_ac_tek(v_h, pg_temp.kb_c('MASTIT_HASTALIK')::uuid, 'kb ilaçsız', CURRENT_DATE);
  v_case := (v_r->>'case_id')::uuid;
  v_r := public.add_treatment_day_with_sessions(v_case, CURRENT_DATE, '[{"planned_time":"10:00","dose":1,"unit":"ml"}]'::jsonb, NULL);
  v_seans := (v_r->'admin_ids'->>0)::uuid;
  PERFORM pg_temp.kb_ok((SELECT stok_id IS NULL AND drug_product_id IS NULL FROM public.treatment_day_uygulamalar WHERE id = v_seans), 'S4-ilacsiz', 'fixture ilaçsız seans', NULL);
  v_r := public.seans_tamamla(v_seans);
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_n = 0, 'S4-ilacsiz', 'gebe hayvanda ilaçsız seans tamamlanır, event yok', v_r::text);
  RAISE NOTICE 'PASS S4-ilacsiz: stok/ürün bilgisi olmayan seans DEGIL sayılır';
END $t$;

-- T12: planlama (şablon uygulama / drug_administrations INSERT) event ve +48s görevi üretmez
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_case uuid; v_n int;
BEGIN
  INSERT INTO public.dogum (anne_id, tarih) VALUES (v_h, CURRENT_DATE - 100);
  v_case := pg_temp.kb_ovsync_vaka(v_h);
  SELECT count(*) INTO v_n FROM public.drug_administrations da JOIN public.treatment_days td ON td.id = da.treatment_day_id
   WHERE td.case_id = v_case AND da.stok_id = pg_temp.kb_c('PG_STOK');
  PERFORM pg_temp.kb_ok(v_n = 2, 'T12', 'fixture: 2 planlı PG drug_administration', v_n::text);
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T12', 'event yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_h AND kaynak LIKE 'PG_TOHUMLAMA:%';
  PERFORM pg_temp.kb_ok(v_n = 0, 'T12', '+48s görevi yok', v_n::text);
  RAISE NOTICE 'PASS T12: şablon PG planı gerçek uygulama olayı/+48s görevi üretmez';
END $t$;

-- T15: aynı uygulama olayı iki kez → tek event, tek türev görev; _pg_sonrasi_tohumlama idempotent
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_e1 uuid; v_e2 uuid; v_n int; v_src text := pg_temp.kb_id('KB-SRC');
BEGIN
  INSERT INTO public.dogum (anne_id, tarih) VALUES (v_h, CURRENT_DATE - 100);
  v_e1 := public._pg_olay_isle('HIZLI_UYGULAMA', v_src, v_h, pg_temp.kb_c('PG_STOK'), NULL, now(),
                               public._pg_kapi(v_h, pg_temp.kb_c('PG_STOK'), NULL, false), NULL);
  v_e2 := public._pg_olay_isle('HIZLI_UYGULAMA', v_src, v_h, pg_temp.kb_c('PG_STOK'), NULL, now(),
                               public._pg_kapi(v_h, pg_temp.kb_c('PG_STOK'), NULL, false), NULL);
  PERFORM public._pg_sonrasi_tohumlama(v_e1);
  PERFORM pg_temp.kb_ok(v_e1 IS NOT NULL AND v_e2 IS NULL, 'T15', 'ilk çağrı event, ikinci NULL', format('%s/%s', v_e1, v_e2));
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T15', 'tek event', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_h AND gorev_tipi = 'TOHUMLAMA_PLANLI';
  PERFORM pg_temp.kb_ok(v_n = 1, 'T15', 'tek türev görev', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE ana_hayvan_id = v_h AND tip = 'PG_TOHUMLAMA_GOREVI';
  PERFORM pg_temp.kb_ok(v_n = 1, 'T15', 'tek PG_TOHUMLAMA_GOREVI log', v_n::text);
  RAISE NOTICE 'PASS T15: aynı kaynak iki kez → tek event, tek görev, tek audit';
END $t$;

-- hizli_uygulama_geri_al: event geri alınır, PG görevi iptal, yerine geçilen görev CANLANMAZ → PG_CYCLE_REVIEW_REQUIRED
DO $t$
DECLARE
  v_h text := pg_temp.kb_hayvan(); v_tai uuid; v_r jsonb; v_uyg uuid; v_ev record; v_n int; v_log jsonb; v_pg_gorev uuid;
BEGIN
  INSERT INTO public.dogum (anne_id, tarih) VALUES (v_h, CURRENT_DATE - 100);
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (v_h, 'TOHUMLAMA_PLANLI', 'kb TAI', CURRENT_DATE + 5, '10:00', false, false, 'MANUEL-KB') RETURNING id INTO v_tai;
  v_r := public.hizli_uygulama(v_h, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb geri al');
  v_uyg := (v_r->>'id')::uuid;
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_type = 'HIZLI_UYGULAMA' AND source_id = v_uyg::text;
  v_pg_gorev := v_ev.tohumlama_gorev_id;
  PERFORM pg_temp.kb_ok((SELECT kapatan_ref FROM public.gorev_log WHERE id = v_tai) = 'PG_YERINE:' || v_ev.id, 'S4-geri-al', 'fixture: TAI PG_YERINE', NULL);

  v_r := public.hizli_uygulama_geri_al(v_uyg);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'S4-geri-al', 'ok', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT geri_alindi_at IS NOT NULL FROM public.pg_application_event WHERE id = v_ev.id), 'S4-geri-al', 'event geri_alindi_at dolu', NULL);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_pg_gorev AND iptal AND kapatan_ref = 'PG_GERI_AL:' || v_ev.id;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S4-geri-al', 'PG görevi iptal (PG_GERI_AL)', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_tai AND iptal AND kapatan_ref = 'PG_YERINE:' || v_ev.id;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S4-geri-al', 'yerine geçilen TAI canlanmaz', v_n::text);
  SELECT payload INTO v_log FROM public.islem_log WHERE tip = 'PG_CYCLE_REVIEW_REQUIRED' AND ref_id = v_ev.id::text;
  PERFORM pg_temp.kb_ok(v_log->'yerine_gecilen_gorev_ids' @> to_jsonb(ARRAY[v_tai]) AND v_log->'iptal_edilen_pg_gorev_ids' @> to_jsonb(ARRAY[v_pg_gorev]),
    'S4-geri-al', 'PG_CYCLE_REVIEW_REQUIRED (yerine geçilen + iptal edilen id''ler)', coalesce(v_log::text, '<log yok>'));
  SELECT count(*) INTO v_n FROM public.uygulama_log WHERE id = v_uyg;
  PERFORM pg_temp.kb_ok(v_n = 0, 'S4-geri-al', 'uygulama_log silindi', v_n::text);
  RAISE NOTICE 'PASS S4-geri-al: event geri alındı, PG görevi iptal, TAI canlanmadı, PG_CYCLE_REVIEW_REQUIRED yazıldı';
END $t$;


-- geri alma temizliği bayraktan bağımsız (uygulama_log DELETE): ACK'li PG geri alınınca
-- PG_ONAY ile iptal edilen GEBELIK_KONTROL görevleri geri açılır; PG görevi iptal
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_r jsonb; v_toh uuid; v_ev record; v_n int;
BEGIN
  v_r := public.tohumlama_kaydet(v_h, CURRENT_DATE - 30, 'KB-SP');
  v_toh := (v_r->>'tohumlama_id')::uuid;
  v_r := public.hizli_uygulama(p_hayvan_id := v_h, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                               p_notlar := 'kb ack geri al', p_pg_onay := true, p_pg_gerekce := 'kb');
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_type = 'HIZLI_UYGULAMA' AND source_id = v_r->>'id';
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE kaynak = 'TOH-' || v_toh AND gorev_tipi = 'GEBELIK_KONTROL' AND iptal;
  PERFORM pg_temp.kb_ok(v_ev.karar = 'ACK_PENDING' AND v_n = 2, 'S4-geri-al-ack', 'fixture: ACK + 2 GEBELIK_KONTROL iptal', v_n::text);

  UPDATE public.protokol_ayar SET deger = 0 WHERE anahtar = 'ovsync_pg_kurallari_aktif';
  v_r := public.hizli_uygulama_geri_al((v_ev.source_id)::uuid);
  UPDATE public.protokol_ayar SET deger = 1 WHERE anahtar = 'ovsync_pg_kurallari_aktif';

  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT geri_alindi_at IS NOT NULL FROM public.pg_application_event WHERE id = v_ev.id),
    'S4-geri-al-ack', 'bayrak 0''da da event geri_alindi_at dolu', v_r::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_ev.tohumlama_gorev_id AND iptal;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S4-geri-al-ack', 'PG görevi iptal', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE kaynak = 'TOH-' || v_toh AND gorev_tipi = 'GEBELIK_KONTROL' AND NOT iptal AND NOT tamamlandi;
  PERFORM pg_temp.kb_ok(v_n = 2, 'S4-geri-al-ack', 'PG_ONAY ile iptal edilen 2 GEBELIK_KONTROL geri açılır', v_n::text);
  RAISE NOTICE 'PASS S4-geri-al-ack: geri alma temizliği bayraktan bağımsız; ACK iptalleri geri açılır';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 3 — S-5 PG +48s tohumlama görevi
-- ════════════════════════════════════════════════════════════════════════════

-- T13' (1/2): MK1 pencere yuvarlama (kapalı aralıklar, asla erkene çekilmez)
DO $t$
DECLARE
  d date := CURRENT_DATE; r record; v_sonuc timestamp;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      (time '00:00',    d,     time '09:00'), (time '07:00',    d,     time '09:00'),
      (time '09:00',    d,     time '09:00'), (time '10:00',    d,     time '10:00'),
      (time '12:00',    d,     time '12:00'), (time '12:00:01', d,     time '18:00'),
      (time '14:30',    d,     time '18:00'), (time '17:59',    d,     time '18:00'),
      (time '18:00',    d,     time '18:00'), (time '21:00',    d,     time '21:00'),
      (time '21:00:01', d + 1, time '09:00'), (time '23:30',    d + 1, time '09:00')
    ) AS x(girdi, bek_gun, bek_saat)
  LOOP
    v_sonuc := public._tohumlama_pencere(pg_temp.kb_yerel(d, r.girdi)) AT TIME ZONE 'Europe/Istanbul';
    PERFORM pg_temp.kb_ok(v_sonuc = r.bek_gun + r.bek_saat, 'T13''-pencere',
      format('%s → %s %s', r.girdi, r.bek_gun, r.bek_saat), v_sonuc::text);
  END LOOP;
  RAISE NOTICE 'PASS T13''-pencere: [09:00,12:00] ve [18:00,21:00] kapalı aralık; dışı → sonraki pencere başı';
END $t$;

-- T13' (2/2): protokolsüz PG, D50+ → tek TOHUMLAMA_PLANLI, +48s pencereye yuvarlı (gerçek yol);
--            deterministik an ile 14:30 → 18:00, 22:15 → ertesi 09:00; genç hayvan → UYGUNSUZ
DO $t$
DECLARE
  v_h text := pg_temp.kb_hayvan(); v_r jsonb; v_ev record; v_g record; v_bek timestamp; v_n int; v_y text := pg_temp.kb_hayvan(300);
  v_h2 text := pg_temp.kb_hayvan(); v_h3 text := pg_temp.kb_hayvan();
BEGIN
  INSERT INTO public.dogum (anne_id, tarih) VALUES (v_h, CURRENT_DATE - 60), (v_h2, CURRENT_DATE - 100), (v_h3, CURRENT_DATE - 100);
  v_r := public.hizli_uygulama(v_h, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb t13');
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_type = 'HIZLI_UYGULAMA' AND source_id = v_r->>'id';
  PERFORM pg_temp.kb_ok(v_ev.karar = 'ALLOW' AND v_ev.gorev_sonuc = 'OLUSTU' AND v_ev.occurred_at = now(), 'T13''', 'event ALLOW/OLUSTU, occurred_at=now()', row_to_json(v_ev)::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_h AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT iptal AND NOT tamamlandi;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T13''', 'tek açık TOHUMLAMA_PLANLI', v_n::text);
  SELECT * INTO v_g FROM public.gorev_log WHERE id = v_ev.tohumlama_gorev_id;
  v_bek := date_trunc('minute', public._tohumlama_pencere(now() + interval '48 hours')) AT TIME ZONE 'Europe/Istanbul';
  PERFORM pg_temp.kb_ok(v_g.hedef_tarih + v_g.hedef_saat = v_bek AND v_g.kaynak = 'PG_TOHUMLAMA:' || v_ev.id
                        AND v_g.aciklama LIKE 'PG sonrası tohumlama%'
                        AND (v_g.hedef_saat BETWEEN '09:00' AND '12:00' OR v_g.hedef_saat BETWEEN '18:00' AND '21:00')
                        AND v_g.hedef_tarih + v_g.hedef_saat >= date_trunc('minute', (now() + interval '48 hours') AT TIME ZONE 'Europe/Istanbul'),
    'T13''', format('hedef %s (pencere içinde, +48s''den erken değil)', v_bek), format('%s %s %s', v_g.hedef_tarih, v_g.hedef_saat, v_g.kaynak));
  SELECT count(*) INTO v_n FROM public.islem_log WHERE tip = 'PG_TOHUMLAMA_GOREVI' AND ref_id = v_g.id::text AND payload->>'event_id' = v_ev.id::text;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T13''', 'PG_TOHUMLAMA_GOREVI audit', v_n::text);

  -- deterministik (gerçek yol, p_occurred_at): dün 14:30 → yarın 18:00
  v_r := public.hizli_uygulama(p_hayvan_id := v_h2, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                               p_notlar := 'kb t13 14:30', p_occurred_at := pg_temp.kb_yerel(CURRENT_DATE - 1, '14:30'));
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_type = 'HIZLI_UYGULAMA' AND source_id = v_r->>'id';
  SELECT * INTO v_g FROM public.gorev_log WHERE id = v_ev.tohumlama_gorev_id;
  PERFORM pg_temp.kb_ok(v_ev.occurred_at = pg_temp.kb_yerel(CURRENT_DATE - 1, '14:30') AND v_g.hedef_tarih = CURRENT_DATE + 1 AND v_g.hedef_saat = '18:00',
    'T13''', 'dün 14:30 PG → yarın 18:00 (occurred_at = verilen an)', format('%s | %s %s', v_ev.occurred_at, v_g.hedef_tarih, v_g.hedef_saat));
  -- dün 22:15 → +48s = yarın 22:15 → öbür gün 09:00
  v_r := public.hizli_uygulama(p_hayvan_id := v_h3, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                               p_notlar := 'kb t13 22:15', p_occurred_at := pg_temp.kb_yerel(CURRENT_DATE - 1, '22:15'));
  SELECT g.* INTO v_g FROM public.gorev_log g JOIN public.pg_application_event e ON e.tohumlama_gorev_id = g.id
   WHERE e.source_type = 'HIZLI_UYGULAMA' AND e.source_id = v_r->>'id';
  PERFORM pg_temp.kb_ok(v_g.hedef_tarih = CURRENT_DATE + 2 AND v_g.hedef_saat = '09:00', 'T13''', 'dün 22:15 PG → +2g 09:00', format('%s %s', v_g.hedef_tarih, v_g.hedef_saat));

  -- uygunsuz hayvan (12 aydan küçük) → event UYGUNSUZ, görev yok
  v_r := public.hizli_uygulama(v_y, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb t13 genç');
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_id = v_r->>'id';
  PERFORM pg_temp.kb_ok(v_ev.gorev_sonuc = 'UYGUNSUZ' AND v_ev.gorev_sonuc_detay LIKE '%12 aydan küçük%' AND v_ev.tohumlama_gorev_id IS NULL,
    'T13''', 'genç hayvan → UYGUNSUZ, görev yok', row_to_json(v_ev)::text);
  RAISE NOTICE 'PASS T13'': protokolsüz D50+ PG → tek TOHUMLAMA_PLANLI pencereye yuvarlı (+48s); p_occurred_at dün 14:30→yarın 18:00, dün 22:15→+2g 09:00; uygunsuz → UYGUNSUZ';
END $t$;

-- MK7: p_occurred_at sınır doğrulaması — >+5dk gelecek ya da >7g geçmiş → PG_ZAMAN_GECERSIZ; uygulama/event yazılmaz
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_hata text; v_n int;
BEGIN
  v_hata := NULL;
  BEGIN
    PERFORM public.hizli_uygulama(p_hayvan_id := v_h, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                                  p_notlar := 'kb mk7 gelecek', p_occurred_at := now() + interval '6 minutes');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'PG_ZAMAN_GECERSIZ:%', 'MK7-zaman', '+6dk gelecek → PG_ZAMAN_GECERSIZ', v_hata);

  v_hata := NULL;
  BEGIN
    PERFORM public.hizli_uygulama(p_hayvan_id := v_h, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                                  p_notlar := 'kb mk7 gecmis', p_occurred_at := now() - interval '8 days');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'PG_ZAMAN_GECERSIZ:%', 'MK7-zaman', '-8g geçmiş → PG_ZAMAN_GECERSIZ', v_hata);

  SELECT count(*) INTO v_n FROM public.uygulama_log WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK7-zaman', 'geçersiz zamanda uygulama_log yazılmaz', v_n::text);
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK7-zaman', 'geçersiz zamanda event yazılmaz', v_n::text);

  -- sınır içi: tam +5dk (katı değil) geçer
  PERFORM public.hizli_uygulama(p_hayvan_id := v_h, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                                p_notlar := 'kb mk7 sinir', p_occurred_at := now() + interval '5 minutes');
  SELECT count(*) INTO v_n FROM public.uygulama_log WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok(v_n = 1, 'MK7-zaman', 'tam +5dk sınırda geçer', v_n::text);
  RAISE NOTICE 'PASS MK7-zaman: p_occurred_at >+5dk ya da >7g geçmiş → PG_ZAMAN_GECERSIZ, yazma yok; sınırda geçer';
END $t$;

-- T14' (deterministik, gerçek seans yolu; seans occurred_at = LEAST(now(), planlanan an)):
--   Ovsync 8. gün PG → şablon TAI iptal, 10. gün 10:00; 9. gün PG → o da iptal, 11. gün 10:00 (= TAI)
DO $t$
DECLARE
  v_h text := pg_temp.kb_hayvan(); v_case uuid; v_s date := CURRENT_DATE - 9; v_tai record; v_s8 uuid; v_s9 uuid;
  v_e1 record; v_e2 record; v_g1 record; v_g2 record; v_n int; v_r jsonb;
BEGIN
  INSERT INTO public.dogum (anne_id, tarih) VALUES (v_h, CURRENT_DATE - 100);
  -- geçmiş başlangıçlı vaka: start_first_service_protocol'ün kullandığı aynı üç RPC
  v_r := public._vaka_ac_tek(v_h, pg_temp.kb_c('OVSYNC_HASTALIK')::uuid, 'kb t14', v_s);
  v_case := (v_r->>'case_id')::uuid;
  v_r := public.tedavi_sablon_uygula(v_case, pg_temp.kb_c('OVSYNC_SABLON')::uuid, v_s);
  v_r := public.tedavi_sablon_tohumlama_gorev_ekle(v_case, pg_temp.kb_c('OVSYNC_SABLON')::uuid, v_s);
  SELECT * INTO v_tai FROM public.gorev_log WHERE id = (v_r->>'gorev_id')::uuid;
  PERFORM pg_temp.kb_ok(v_tai.hedef_tarih = v_s + 10 AND v_tai.hedef_saat = '10:00', 'T14''', 'fixture TAI = 11. gün (başlangıç+10) 10:00', format('%s %s', v_tai.hedef_tarih, v_tai.hedef_saat));
  SELECT id INTO v_s8 FROM public.treatment_day_uygulamalar WHERE case_id = v_case AND planned_date = v_s + 7 AND stok_id = pg_temp.kb_c('PG_STOK');
  SELECT id INTO v_s9 FROM public.treatment_day_uygulamalar WHERE case_id = v_case AND planned_date = v_s + 8 AND stok_id = pg_temp.kb_c('PG_STOK');
  PERFORM pg_temp.kb_ok(v_s8 IS NOT NULL AND v_s9 IS NOT NULL, 'T14''', 'fixture 8./9. gün PG seansları', NULL);

  v_r := public.seans_tamamla(p_seans_admin_id := v_s8);
  SELECT * INTO v_e1 FROM public.pg_application_event WHERE source_type = 'TEDAVI_SEANS' AND source_id = v_s8::text;
  PERFORM pg_temp.kb_ok(v_e1.occurred_at = pg_temp.kb_yerel(v_s + 7, '10:00'), 'T14''', 'seans occurred_at = planlanan an (geçmiş)', coalesce(v_e1.occurred_at::text, v_r::text));
  SELECT * INTO v_g1 FROM public.gorev_log WHERE id = v_e1.tohumlama_gorev_id;
  PERFORM pg_temp.kb_ok(v_g1.hedef_tarih = v_s + 9 AND v_g1.hedef_saat = '10:00', 'T14''', '8. gün PG → 10. gün 10:00', format('%s %s', v_g1.hedef_tarih, v_g1.hedef_saat));
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_tai.id AND iptal AND tamamlandi AND kapatan_ref = 'PG_YERINE:' || v_e1.id;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T14''', 'şablon TAI PG_YERINE ile iptal', v_n::text);

  v_r := public.seans_tamamla(p_seans_admin_id := v_s9);
  SELECT * INTO v_e2 FROM public.pg_application_event WHERE source_type = 'TEDAVI_SEANS' AND source_id = v_s9::text;
  SELECT * INTO v_g2 FROM public.gorev_log WHERE id = v_e2.tohumlama_gorev_id;
  PERFORM pg_temp.kb_ok(v_g2.hedef_tarih = v_tai.hedef_tarih AND v_g2.hedef_saat = v_tai.hedef_saat, 'T14''', '9. gün PG → 11. gün 10:00 (= şablon TAI)', format('%s %s', v_g2.hedef_tarih, v_g2.hedef_saat));
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_g1.id AND iptal AND kapatan_ref = 'PG_YERINE:' || v_e2.id;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T14''', '8. gün PG görevi 9. gün PG ile iptal', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_h AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT iptal AND NOT tamamlandi;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T14''', 'tek açık TOHUMLAMA_PLANLI', v_n::text);
  PERFORM pg_temp.kb_ok((SELECT payload->'yerine_gecilen_gorev_ids' FROM public.islem_log WHERE tip = 'PG_TOHUMLAMA_GOREVI' AND payload->>'event_id' = v_e2.id::text)
                        = to_jsonb(ARRAY[v_g1.id]), 'T14''', 'audit yerine_gecilen = [8. gün PG görevi]', NULL);
  RAISE NOTICE 'PASS T14'': Ovsync 8. gün PG seansı → TAI iptal + 10. gün 10:00; 9. gün PG → 11. gün 10:00 (son PG kazanır)';
END $t$;

-- T14'/T07 gerçek seans yolu + T16: iki PG seansı → iki event, tek açık görev (sonuncusu)
DO $t$
DECLARE
  v_h text := pg_temp.kb_hayvan(); v_case uuid; v_s8 uuid; v_s9 uuid; v_r jsonb; v_e1 record; v_e2 record; v_tai uuid; v_n int; v_g record;
  v_bus uuid;
BEGIN
  INSERT INTO public.dogum (anne_id, tarih) VALUES (v_h, CURRENT_DATE - 100);
  v_case := pg_temp.kb_ovsync_vaka(v_h);
  SELECT id INTO v_tai FROM public.gorev_log WHERE kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || v_case || ':%';
  SELECT id INTO v_s8 FROM public.treatment_day_uygulamalar WHERE case_id = v_case AND stok_id = pg_temp.kb_c('PG_STOK') ORDER BY planned_date LIMIT 1;
  SELECT id INTO v_s9 FROM public.treatment_day_uygulamalar WHERE case_id = v_case AND stok_id = pg_temp.kb_c('PG_STOK') ORDER BY planned_date DESC LIMIT 1;
  -- GnRH (PG değil) seansı → event yok
  SELECT id INTO v_bus FROM public.treatment_day_uygulamalar WHERE case_id = v_case AND stok_id <> pg_temp.kb_c('PG_STOK') ORDER BY planned_date LIMIT 1;
  v_r := public.seans_tamamla(v_bus);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND NOT EXISTS (SELECT 1 FROM public.pg_application_event WHERE source_id = v_bus::text),
    'T07-ok', 'GnRH seansı: ok, event yok', v_r::text);

  v_r := public.seans_tamamla(p_seans_admin_id := v_s8);
  SELECT * INTO v_e1 FROM public.pg_application_event WHERE source_type = 'TEDAVI_SEANS' AND source_id = v_s8::text;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_e1.karar = 'ALLOW' AND v_e1.gorev_sonuc = 'OLUSTU' AND v_e1.hayvan_id = v_h
                        AND v_e1.drug_product_id = pg_temp.kb_c('PG_URUN')::uuid,
    'T07-ok', 'seans PG → TEDAVI_SEANS event (hayvan = cases.animal_id, ürün seanstan)', coalesce(row_to_json(v_e1)::text, v_r::text));
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_tai AND iptal AND kapatan_ref = 'PG_YERINE:' || v_e1.id;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T14''-seans', 'şablon TAI iptal', v_n::text);
  SELECT * INTO v_g FROM public.gorev_log WHERE id = v_e1.tohumlama_gorev_id;
  PERFORM pg_temp.kb_ok(v_g.hedef_tarih + v_g.hedef_saat = date_trunc('minute', public._tohumlama_pencere(now() + interval '48 hours')) AT TIME ZONE 'Europe/Istanbul',
    'T14''-seans', 'görev = pencere(now()+48s)', format('%s %s', v_g.hedef_tarih, v_g.hedef_saat));

  v_r := public.seans_tamamla(p_seans_admin_id := v_s9);
  SELECT * INTO v_e2 FROM public.pg_application_event WHERE source_type = 'TEDAVI_SEANS' AND source_id = v_s9::text;
  SELECT count(*) INTO v_n FROM public.pg_application_event WHERE hayvan_id = v_h;
  PERFORM pg_temp.kb_ok(v_n = 2, 'T16', 'iki event korunur', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_h AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT iptal AND NOT tamamlandi
     AND kaynak = 'PG_TOHUMLAMA:' || v_e2.id;
  PERFORM pg_temp.kb_ok(v_n = 1 AND (SELECT count(*) FROM public.gorev_log WHERE hayvan_id = v_h AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT iptal AND NOT tamamlandi) = 1,
    'T16', 'tek açık görev = son PG''nin', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_e1.tohumlama_gorev_id AND iptal AND kapatan_ref = 'PG_YERINE:' || v_e2.id;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T16', 'ilk PG görevi ikinci PG ile iptal', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE ana_hayvan_id = v_h AND tip = 'PG_TOHUMLAMA_GOREVI';
  PERFORM pg_temp.kb_ok(v_n = 2, 'T16', 'iki audit olayı', v_n::text);
  RAISE NOTICE 'PASS T07-ok/T14''-seans/T16: gerçek seans yolu event üretir, TAI iptal; iki PG → iki event, tek açık görev';
END $t$;

-- S-5 doğum protokolü D2/D25/D39 PG → VWP_ICINDE, görev yok
DO $t$
DECLARE v_gun int; v_h text; v_r jsonb; v_ev record; v_n int;
BEGIN
  FOREACH v_gun IN ARRAY ARRAY[2, 25, 39] LOOP
    v_h := pg_temp.kb_hayvan();
    v_r := public.dogum_kaydet(v_h, CURRENT_DATE - v_gun, pg_temp.kb_id('KBY'));
    v_r := public.hizli_uygulama(v_h, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb vwp');
    SELECT * INTO v_ev FROM public.pg_application_event WHERE source_id = v_r->>'id';
    PERFORM pg_temp.kb_ok(v_ev.gorev_sonuc = 'VWP_ICINDE' AND v_ev.tohumlama_gorev_id IS NULL AND v_ev.gorev_sonuc_detay LIKE 'VWP tabanı%',
      'S5-VWP', format('D%s PG → VWP_ICINDE', v_gun), coalesce(row_to_json(v_ev)::text, v_r::text));
    SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_h AND kaynak LIKE 'PG_TOHUMLAMA:%';
    PERFORM pg_temp.kb_ok(v_n = 0, 'S5-VWP', format('D%s: görev yok', v_gun), v_n::text);
  END LOOP;
  RAISE NOTICE 'PASS S5-VWP: doğum protokolü D2/D25/D39 PG → VWP_ICINDE, +48s görevi yok (SK1)';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 4 — S-6 görev erteleme
-- ════════════════════════════════════════════════════════════════════════════

-- T26 + saat yuvarlama + GECMIS_TARIH + GOREV_ERTELENEMEZ
DO $t$
DECLARE
  v_h text := pg_temp.kb_hayvan(); v_r jsonb; v_g record; v_eski record; v_log jsonb; v_hata text; v_gk uuid; v_kapali uuid;
BEGIN
  INSERT INTO public.dogum (anne_id, tarih) VALUES (v_h, CURRENT_DATE - 100);
  v_r := public.hizli_uygulama(v_h, pg_temp.kb_c('PG_STOK'), 2, 'ml', 'IM', 'kb t26');
  SELECT g.* INTO v_eski FROM public.gorev_log g JOIN public.pg_application_event e ON e.tohumlama_gorev_id = g.id WHERE e.source_id = v_r->>'id';
  v_r := public.tohumlama_gorev_ertele(v_eski.id, v_eski.hedef_tarih + 2);
  SELECT * INTO v_g FROM public.gorev_log WHERE id = v_eski.id;
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_g.hedef_tarih = v_eski.hedef_tarih + 2 AND v_g.hedef_saat = v_eski.hedef_saat
                        AND (v_r->>'toplam_erteleme_gun')::int = 2 AND v_r->>'uyari' IS NULL
                        AND (v_r->>'ilk_hedef_tarih')::date = v_eski.hedef_tarih,
    'T26', '+2 gün, saat korunur (pencere içinde), uyarı yok', v_r::text);
  SELECT payload INTO v_log FROM public.islem_log WHERE tip = 'TOHUMLAMA_ERTELE' AND ref_id = v_eski.id::text;
  PERFORM pg_temp.kb_ok(v_log ?& ARRAY['gorev_id','eski_tarih','eski_saat','yeni_tarih','yeni_saat','ilk_hedef_tarih']
                        AND (v_log->>'eski_tarih')::date = v_eski.hedef_tarih AND (v_log->>'yeni_tarih')::date = v_eski.hedef_tarih + 2,
    'T26', 'TOHUMLAMA_ERTELE log (gorev_id, eski/yeni tarih-saat, ilk_hedef)', coalesce(v_log::text, '<log yok>'));

  -- saat pencereye yuvarlanır: 13:00 → 18:00; 22:00 → ertesi gün 09:00
  v_r := public.tohumlama_gorev_ertele(v_eski.id, CURRENT_DATE + 5, '13:00');
  PERFORM pg_temp.kb_ok((v_r->>'hedef_tarih')::date = CURRENT_DATE + 5 AND (v_r->>'hedef_saat')::time = '18:00', 'T26', '13:00 → 18:00', v_r::text);
  v_r := public.tohumlama_gorev_ertele(v_eski.id, CURRENT_DATE + 5, '22:00');
  PERFORM pg_temp.kb_ok((v_r->>'hedef_tarih')::date = CURRENT_DATE + 6 AND (v_r->>'hedef_saat')::time = '09:00', 'T26', '22:00 → ertesi 09:00', v_r::text);

  v_hata := NULL;
  BEGIN PERFORM public.tohumlama_gorev_ertele(v_eski.id, CURRENT_DATE - 1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'GECMIS_TARIH:%', 'S6-GECMIS_TARIH', 'GECMIS_TARIH', v_hata);

  -- bugünün geçmiş saati de GECMIS_TARIH (yalnız yerel saat 09:00'ı geçtiyse sınanabilir)
  IF (now() AT TIME ZONE 'Europe/Istanbul')::time > time '09:00' THEN
    v_hata := NULL;
    BEGIN PERFORM public.tohumlama_gorev_ertele(v_eski.id, (now() AT TIME ZONE 'Europe/Istanbul')::date, '09:00');
    EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
    PERFORM pg_temp.kb_ok(v_hata LIKE 'GECMIS_TARIH:%', 'S6-GECMIS_TARIH', 'bugün geçmiş saat (09:00) → GECMIS_TARIH', v_hata);
  ELSE
    RAISE NOTICE 'ATLANDI S6-GECMIS_TARIH-saat: yerel saat 09:00 öncesi, geçmiş pencere anı yok';
  END IF;

  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
  VALUES (v_h, 'GEBELIK_KONTROL', 'kb', CURRENT_DATE + 5, false, false, 'KB') RETURNING id INTO v_gk;
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
  VALUES (v_h, 'TOHUMLAMA_PLANLI', 'kb', CURRENT_DATE + 5, true, false, 'KB') RETURNING id INTO v_kapali;
  v_hata := NULL;
  BEGIN PERFORM public.tohumlama_gorev_ertele(v_gk, CURRENT_DATE + 6);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'GOREV_ERTELENEMEZ:%TIP_UYGUN_DEGIL%', 'S6-GOREV_ERTELENEMEZ', 'tip uygun değil', v_hata);
  v_hata := NULL;
  BEGIN PERFORM public.tohumlama_gorev_ertele(v_kapali, CURRENT_DATE + 6);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'GOREV_ERTELENEMEZ:%GOREV_ACIK_DEGIL%', 'S6-GOREV_ERTELENEMEZ', 'kapalı görev', v_hata);
  v_hata := NULL;
  BEGIN PERFORM public.tohumlama_gorev_ertele(gen_random_uuid(), CURRENT_DATE + 6);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM; END;
  PERFORM pg_temp.kb_ok(v_hata LIKE 'GOREV_ERTELENEMEZ:%GOREV_BULUNAMADI%', 'S6-GOREV_ERTELENEMEZ', 'olmayan görev', v_hata);
  RAISE NOTICE 'PASS T26/S6: PG görevi +2 gün ertelenir (pencere içinde, log var); saat yuvarlanır; GECMIS_TARIH ve GOREV_ERTELENEMEZ';
END $t$;

-- T27: ilk hedeften 7 günü aşan erteleme → uyari (sınır yok, gizli erteleme yok)
DO $t$
DECLARE v_h text := pg_temp.kb_hayvan(); v_g uuid; v_d0 date := CURRENT_DATE + 2; v_r jsonb;
BEGIN
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (v_h, 'TOHUMLAMA_PLANLI', 'kb t27', v_d0, '10:00', false, false, 'MANUEL-KB') RETURNING id INTO v_g;
  v_r := public.tohumlama_gorev_ertele(v_g, v_d0 + 9);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'hedef_tarih')::date = v_d0 + 9 AND (v_r->>'toplam_erteleme_gun')::int = 9
                        AND v_r->>'uyari' = 'ERTELEME_7_GUN_ASILDI',
    'T27', '9 gün → uyari ERTELEME_7_GUN_ASILDI, erteleme yapılır', v_r::text);
  -- ikinci erteleme: ilk hedef ilk log'dan okunur
  v_r := public.tohumlama_gorev_ertele(v_g, v_d0 + 3);
  PERFORM pg_temp.kb_ok((v_r->>'ilk_hedef_tarih')::date = v_d0 AND (v_r->>'toplam_erteleme_gun')::int = 3 AND v_r->>'uyari' IS NULL,
    'T27', 'ikinci erteleme: ilk hedef korunur, toplam 3, uyarı yok', v_r::text);
  RAISE NOTICE 'PASS T27: 7 günü aşan erteleme uyarı döner; ilk hedef log''dan izlenir';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 5 — S-7 tohumlama ile senkronizasyon vakası kapanışı
-- ════════════════════════════════════════════════════════════════════════════

-- T01 + T02 + T21 + T22 + zaten kapalı vaka
DO $t$
DECLARE
  v_a text := pg_temp.kb_hayvan(); v_ov uuid; v_ma uuid; v_r jsonb; v_toh text; v_ilk uuid; v_tai uuid; v_n int; v_log jsonb;
  v_c record; v_log_once int;
BEGIN
  v_ov := pg_temp.kb_ovsync_vaka(v_a);
  v_r := public.vaka_toplu_ac(p_animal_ids := ARRAY[v_a], p_disease_id := pg_temp.kb_c('MASTIT_HASTALIK')::uuid,
                              p_sablon_id := pg_temp.kb_c('MASTIT_SABLON')::uuid);
  v_ma := (v_r->'acilan'->0->>'case_id')::uuid;
  SELECT id INTO v_tai FROM public.gorev_log WHERE kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || v_ov || ':%';
  -- ilk seans (1. gün GnRH) gerçekleşir
  SELECT id INTO v_ilk FROM public.treatment_day_uygulamalar WHERE case_id = v_ov ORDER BY planned_date, planned_time LIMIT 1;
  v_r := public.seans_tamamla(v_ilk);

  v_r := public.tohumlama_kaydet(v_a, CURRENT_DATE, 'KB-SP');
  v_toh := v_r->>'tohumlama_id';
  PERFORM pg_temp.kb_ok(jsonb_array_length(v_r->'kapatilan_senkronizasyon_vakalari') = 1
                        AND v_r->'kapatilan_senkronizasyon_vakalari'->0->>'case_id' = v_ov::text
                        AND v_r->'kapatilan_senkronizasyon_vakalari'->0 ?& ARRAY['iptal_seans','iptal_gorev']
                        AND v_r ?& ARRAY['ok','tohumlama_id','deneme_no','inst_id','otomatik_bos_sayisi','otomatik_iptal_instance'],
    'T01', 'dönüş: eski anahtarlar + kapatilan_senkronizasyon_vakalari=[Ovsync]', v_r::text);
  SELECT * INTO v_c FROM public.cases WHERE id = v_ov;
  PERFORM pg_temp.kb_ok(v_c.status = 'closed' AND v_c.close_reason = 'TOHUMLAMA' AND v_c.closed_at IS NOT NULL, 'T01', 'Ovsync vakası kapalı, close_reason TOHUMLAMA', row_to_json(v_c)::text);
  PERFORM pg_temp.kb_ok((SELECT status FROM public.cases WHERE id = v_ma) = 'active', 'T02', 'Mastit vakası açık kalır', (SELECT status FROM public.cases WHERE id = v_ma));
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar WHERE case_id = v_ma AND uygulanmadi;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T02', 'Mastit seansları dokunulmaz', v_n::text);
  -- gerçekleşen seans ve stoğu korunur; gelecekler iptal + stok iade
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar WHERE id = v_ilk AND uygulama_tamamlandi_at IS NOT NULL AND NOT uygulanmadi;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T01', 'gerçekleşen seans korunur', v_n::text);
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar
   WHERE case_id = v_ov AND id <> v_ilk AND NOT (uygulanmadi AND iptal_nedeni = 'Tohumlama ile sonlandırıldı');
  PERFORM pg_temp.kb_ok(v_n = 0, 'T01', 'kalan seanslar "Tohumlama ile sonlandırıldı" ile iptal', v_n::text);
  SELECT count(*) INTO v_n FROM public.stok_hareket sh JOIN public.drug_administrations da ON sh.notlar = 'drug_admin:' || da.id::text
   WHERE da.seans_admin_id = v_ilk AND sh.iptal;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T01', 'gerçekleşen seansın stoğu iade edilmez', v_n::text);
  SELECT count(*) INTO v_n FROM public.stok_hareket sh JOIN public.drug_administrations da ON sh.notlar = 'drug_admin:' || da.id::text
   JOIN public.treatment_day_uygulamalar u ON u.id = da.seans_admin_id
   WHERE u.case_id = v_ov AND u.id <> v_ilk AND NOT sh.iptal;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T01', 'açık seansların stoğu iade', v_n::text);
  PERFORM pg_temp.kb_ok((SELECT iptal FROM public.gorev_log WHERE id = v_tai), 'T01', 'şablon TAI görevi iptal', NULL);

  -- T21: tek audit
  SELECT count(*) INTO v_n FROM public.islem_log WHERE ref_id = v_ov::text AND tip = 'CASE_CLOSED_EARLY';
  PERFORM pg_temp.kb_ok(v_n = 0, 'T21', 'CASE_CLOSED_EARLY yok', v_n::text);
  SELECT count(*), min(payload::text)::jsonb INTO v_n, v_log FROM public.islem_log WHERE ref_id = v_ov::text AND tip = 'CASE_CLOSED_BY_TOHUMLAMA';
  PERFORM pg_temp.kb_ok(v_n = 1 AND v_log->>'tohumlama_id' = v_toh AND v_log->>'close_reason' = 'TOHUMLAMA' AND (v_log->>'gerceklesen_seans')::int = 1
                        AND v_log ?& ARRAY['case_id','iptal_seans','iptal_gorev','closed_at'],
    'T21', 'tek CASE_CLOSED_BY_TOHUMLAMA (payload tam)', format('%s %s', v_n, v_log));

  -- T22: tohumlama geri al → vaka ve seanslar canlanmaz
  v_r := public.tohumlama_geri_al(v_toh);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (SELECT status FROM public.cases WHERE id = v_ov) = 'closed', 'T22', 'geri al sonrası vaka kapalı', v_r::text);
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar WHERE case_id = v_ov AND id <> v_ilk AND NOT uygulanmadi;
  PERFORM pg_temp.kb_ok(v_n = 0, 'T22', 'seanslar canlanmaz', v_n::text);

  -- zaten kapalı vaka → yazma yok
  SELECT count(*) INTO v_log_once FROM public.islem_log;
  v_r := public._vaka_kapat(v_ov, 'TOHUMLAMA', NULL, '{}'::jsonb);
  PERFORM pg_temp.kb_ok((v_r->>'zaten_kapali')::boolean AND (SELECT count(*) FROM public.islem_log) = v_log_once, 'S7-zaten', 'zaten_kapali, yeni log yok', v_r::text);

  -- tohumlamayla kapanmış vakaya erken kapanış → no-op (close_reason/iptal_nedeni ezilmez, ikinci audit yok)
  v_r := public.close_case_with_remaining(v_ov, 'kb sonradan');
  PERFORM pg_temp.kb_ok(v_r = jsonb_build_object('ok', true, 'iptal_edilen_seans', 0, 'zaten_kapali', true),
    'T21-noop', 'dönüş {ok:true, iptal_edilen_seans:0, zaten_kapali:true}', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT close_reason FROM public.cases WHERE id = v_ov) = 'TOHUMLAMA'
                        AND NOT EXISTS (SELECT 1 FROM public.islem_log WHERE ref_id = v_ov::text AND tip = 'CASE_CLOSED_EARLY')
                        AND NOT EXISTS (SELECT 1 FROM public.treatment_day_uygulamalar WHERE case_id = v_ov AND iptal_nedeni LIKE 'Vaka erken%'),
    'T21-noop', 'TOHUMLAMA ile kapalı vakada close_case_with_remaining no-op', v_r::text);

  -- T21 (erken kapanış yolu): close_case_with_remaining imza/dönüş aynen, tek CASE_CLOSED_EARLY
  v_r := public.close_case_with_remaining(v_ma, 'kb not');
  PERFORM pg_temp.kb_ok((SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(v_r) k) = ARRAY['iptal_edilen_seans','ok'] AND (v_r->>'ok')::boolean,
    'T21-erken', 'dönüş {ok, iptal_edilen_seans}', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT close_reason FROM public.cases WHERE id = v_ma) = 'ERKEN_KAPANIS', 'T21-erken', 'close_reason ERKEN_KAPANIS', NULL);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE ref_id = v_ma::text AND tip = 'CASE_CLOSED_EARLY'
     AND snapshot->>'not' = 'kb not' AND (snapshot->>'iptal_edilen_seans')::int = (v_r->>'iptal_edilen_seans')::int;
  PERFORM pg_temp.kb_ok(v_n = 1 AND NOT EXISTS (SELECT 1 FROM public.islem_log WHERE ref_id = v_ma::text AND tip = 'CASE_CLOSED_BY_TOHUMLAMA'),
    'T21-erken', 'tek CASE_CLOSED_EARLY (canlı snapshot), BY_TOHUMLAMA yok', v_n::text);
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar WHERE case_id = v_ma AND uygulanmadi AND iptal_nedeni <> 'Vaka erken kapatildi: kb not';
  PERFORM pg_temp.kb_ok(v_n = 0, 'T21-erken', 'iptal_nedeni "Vaka erken kapatildi: kb not"', v_n::text);
  RAISE NOTICE 'PASS T01/T02/T21/T22: yalnız Ovsync vakası kapanır (gerçekleşen korunur, açıklar iade), Mastit açık; tek audit; geri al canlandırmaz; zaten kapalıda yazma yok';
END $t$;

-- T03: şablon kimliği belirsiz (protocol_family NULL) eski vaka otomatik kapanmaz;
--      başlangıcı tohumlamadan sonra olan vaka da kapanmaz
DO $t$
DECLARE v_a text := pg_temp.kb_hayvan(); v_b text := pg_temp.kb_hayvan(); v_r jsonb; v_eski uuid; v_ileri uuid;
BEGIN
  v_r := public._vaka_ac_tek(v_a, pg_temp.kb_c('OVSYNC_HASTALIK')::uuid, 'kb eski vaka', CURRENT_DATE - 5);
  v_eski := (v_r->>'case_id')::uuid;
  PERFORM pg_temp.kb_ok((SELECT protocol_family FROM public.cases WHERE id = v_eski) IS NULL, 'T03', 'fixture: protocol_family NULL', NULL);
  v_r := public.tohumlama_kaydet(v_a, CURRENT_DATE, 'KB-SP');
  PERFORM pg_temp.kb_ok((SELECT status FROM public.cases WHERE id = v_eski) = 'active' AND jsonb_array_length(v_r->'kapatilan_senkronizasyon_vakalari') = 0,
    'T03', 'belirsiz vaka açık kalır', v_r::text);

  v_ileri := pg_temp.kb_ovsync_vaka(v_b, CURRENT_DATE + 3);
  v_r := public.tohumlama_kaydet(v_b, CURRENT_DATE, 'KB-SP');
  PERFORM pg_temp.kb_ok((SELECT status FROM public.cases WHERE id = v_ileri) = 'active', 'T03', 'start_date > tohumlama tarihi → kapanmaz', v_r::text);
  RAISE NOTICE 'PASS T03: UNKNOWN (protocol_family NULL) vaka ve sonra başlayan vaka otomatik kapanmaz';
END $t$;

-- T04: planli_tohumlama_kaydet — seçili görev iptal=false,tamamlandi=true; doğru vaka kapanır; anahtar geçer
DO $t$
DECLARE v_a text := pg_temp.kb_hayvan(); v_ov uuid; v_tai uuid; v_r jsonb; v_g record;
BEGIN
  v_ov := pg_temp.kb_ovsync_vaka(v_a);
  SELECT id INTO v_tai FROM public.gorev_log WHERE kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || v_ov || ':%';
  v_r := public.planli_tohumlama_kaydet(v_tai, v_a, CURRENT_DATE, 'KB-SP');
  SELECT * INTO v_g FROM public.gorev_log WHERE id = v_tai;
  PERFORM pg_temp.kb_ok(v_g.tamamlandi AND NOT v_g.iptal AND v_g.ref_tohumlama_id = v_r->>'tohumlama_id', 'T04', 'görev iptal=false, tamamlandi=true', row_to_json(v_g)::text);
  PERFORM pg_temp.kb_ok(v_r->>'gorev_id' = v_tai::text AND v_r->'kapatilan_senkronizasyon_vakalari'->0->>'case_id' = v_ov::text,
    'T04', 'dönüş gorev_id + kapatilan_senkronizasyon_vakalari', v_r::text);
  PERFORM pg_temp.kb_ok((SELECT close_reason FROM public.cases WHERE id = v_ov) = 'TOHUMLAMA', 'T04', 'vaka TOHUMLAMA ile kapalı', NULL);
  RAISE NOTICE 'PASS T04: planlı tohumlama görevi tamamlanır, vaka kapanır, yeni anahtar dönüşe geçer';
END $t$;

-- T05: doğrudan tohumlama — açık planlı görevler iptal; dönüş geriye uyumlu
DO $t$
DECLARE v_a text := pg_temp.kb_hayvan(); v_r jsonb; v_n int;
BEGIN
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak) VALUES
    (v_a, 'TOHUMLAMA_PLANLI', 'kb 1', CURRENT_DATE + 1, '10:00', false, false, 'MANUEL-KB'),
    (v_a, 'TOHUMLAMA_PLANLI', 'kb 2', CURRENT_DATE + 4, '18:00', false, false, 'PG_TOHUMLAMA:' || gen_random_uuid());
  v_r := public.tohumlama_kaydet(v_a, CURRENT_DATE, 'KB-SP');
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT (iptal AND tamamlandi);
  PERFORM pg_temp.kb_ok(v_n = 0, 'T05', 'açık planlı görevler iptal', v_n::text);
  PERFORM pg_temp.kb_ok(v_r ?& ARRAY['ok','tohumlama_id','deneme_no','inst_id','otomatik_bos_sayisi','otomatik_iptal_instance']
                        AND v_r->'kapatilan_senkronizasyon_vakalari' = '[]'::jsonb,
    'T05', 'eski anahtarlar + boş kapatilan listesi', v_r::text);
  RAISE NOTICE 'PASS T05: doğrudan tohumlama açık planlı görevleri iptal eder, dönüş geriye uyumlu';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 6 — S-8 ilk tohumlama zinciri
-- ════════════════════════════════════════════════════════════════════════════

-- T28' + T19 + T18 (rota idempotensi): gebe onayı → görev YOK; doğum → OVSYNC_BASLAT D50; ikiz tek zincir
DO $t$
DECLARE
  v_a text := pg_temp.kb_hayvan(); v_toh uuid; v_r jsonb; v_r2 jsonb; v_n int; v_g record; v_d date := CURRENT_DATE - 1; v_olay text; v_i record;
BEGIN
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_a, CURRENT_DATE - 280, 'Bekliyor', 'KB-SP') RETURNING id INTO v_toh;
  v_r := public.tohumlama_sonuc_gebe(v_toh::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'OVSYNC_BASLAT';
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_n = 0, 'T28''', 'gebe onayı → OVSYNC_BASLAT yok (SK5)', v_n::text);
  SELECT count(*) INTO v_n FROM public.protokol_instance WHERE hayvan_id = v_a AND alttip = 'ILK_TOHUMLAMA';
  PERFORM pg_temp.kb_ok(v_n = 0, 'T28''', 'gebe onayı → rota instance yok', v_n::text);

  v_r := public.dogum_kaydet(v_a, v_d, pg_temp.kb_id('KBY'));
  v_olay := v_r->>'olay_id';
  SELECT * INTO v_g FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'OVSYNC_BASLAT';
  PERFORM pg_temp.kb_ok(v_g.hedef_tarih = v_d + 50 AND v_g.hedef_saat = '10:00' AND v_g.kaynak = 'ILK-TOH-DOGUM-' || v_olay
                        AND NOT v_g.tamamlandi AND NOT v_g.iptal AND v_g.aciklama LIKE 'D50:%',
    'T28''', 'doğum → OVSYNC_BASLAT D50 10:00, kaynak ILK-TOH-DOGUM-<olay_id>', row_to_json(v_g)::text);
  SELECT * INTO v_i FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  PERFORM pg_temp.kb_ok(v_i.tip = 'UREME' AND v_i.alttip = 'ILK_TOHUMLAMA' AND v_i.kaynak_ref = v_g.kaynak AND v_i.baslangic = v_d AND v_i.durum = 'aktif',
    'T28''', 'protokol_instance UREME/ILK_TOHUMLAMA aktif', row_to_json(v_i)::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE ana_hayvan_id = v_a AND tip = 'FIRST_SERVICE_ROUTE_CREATED' AND ref_id = v_g.id::text;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T28''', 'FIRST_SERVICE_ROUTE_CREATED', v_n::text);

  -- T19 ikiz: aynı olay → ikinci zincir yok
  v_r2 := public.dogum_kaydet(v_a, v_d, pg_temp.kb_id('KBY'));
  PERFORM pg_temp.kb_ok((v_r2->>'coklu_dogum')::boolean AND v_r2->>'olay_id' = v_olay, 'T19', 'fixture: ikiz aynı olay', v_r2::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'OVSYNC_BASLAT';
  PERFORM pg_temp.kb_ok(v_n = 1, 'T19', 'ikiz → tek OVSYNC_BASLAT', v_n::text);

  -- T18 rota: aynı kaynak_ref tekrar (cron/refresh yarışı) → NULL, mevcut rotaya dokunulmaz
  PERFORM pg_temp.kb_ok(public._ilk_tohumlama_rota_kur(v_a, v_d, 'ILK-TOH-DOGUM-' || v_olay) IS NULL, 'T18', 'tekrar → NULL', NULL);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'OVSYNC_BASLAT' AND NOT iptal;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T18', 'tek açık OVSYNC_BASLAT', v_n::text);
  RAISE NOTICE 'PASS T28''/T19/T18-rota: gebe onayında görev yok; doğumda D50 OVSYNC_BASLAT; ikiz ve tekrar tek zincir';
END $t$;

-- D50 başlatma: atomik zincir + SK4 (D58 iptal, D53 kalır) + T18 (tekrar/zamanlayıcı tek vaka)
DO $t$
DECLARE
  v_b text := pg_temp.kb_hayvan(); v_d date := CURRENT_DATE - 50; v_bi date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_r jsonb; v_g record; v_c record; v_tai record; v_n int; v_s date; v_z jsonb; v_pgg uuid;
BEGIN
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_b, CURRENT_DATE - 330, 'Gebe', 'KB-SP');
  v_r := public.dogum_kaydet(v_b, v_d, pg_temp.kb_id('KBY'));
  SELECT * INTO v_g FROM public.gorev_log WHERE hayvan_id = v_b AND gorev_tipi = 'OVSYNC_BASLAT';
  v_s := GREATEST(v_g.hedef_tarih, v_bi);
  -- açık PG sonrası tohumlama görevi (protokol onun yerine geçer)
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (v_b, 'TOHUMLAMA_PLANLI', 'kb pg görevi', CURRENT_DATE + 1, '10:00', false, false, 'PG_TOHUMLAMA:' || gen_random_uuid())
  RETURNING id INTO v_pgg;

  v_r := public.start_first_service_protocol(v_g.id);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_r ?& ARRAY['case_id','tohumlama_gorev_id','baslangic','d58_iptal']
                        AND (v_r->>'baslangic')::date = v_s AND jsonb_array_length(v_r->'d58_iptal') = 1,
    'S8-start', 'dönüş {ok, case_id, tohumlama_gorev_id, baslangic, d58_iptal[1]}', v_r::text);
  SELECT * INTO v_c FROM public.cases WHERE id = (v_r->>'case_id')::uuid;
  PERFORM pg_temp.kb_ok(v_c.animal_id = v_b AND v_c.status = 'active' AND v_c.start_date = v_s AND v_c.protocol_family = 'OVSYNC'
                        AND v_c.source_template_id = pg_temp.kb_c('OVSYNC_SABLON')::uuid AND v_c.disease_id = pg_temp.kb_c('OVSYNC_HASTALIK')::uuid
                        AND v_c.notes = 'İlk tohumlama zinciri (D50)',
    'S8-start', 'Ovsync vakası (provenance damgalı)', row_to_json(v_c)::text);
  SELECT count(*) INTO v_n FROM public.treatment_day_uygulamalar WHERE case_id = v_c.id;
  PERFORM pg_temp.kb_ok(v_n = 4, 'S8-start', '4 şablon seansı', v_n::text);
  SELECT * INTO v_tai FROM public.gorev_log WHERE id = (v_r->>'tohumlama_gorev_id')::uuid;
  PERFORM pg_temp.kb_ok(v_tai.gorev_tipi = 'TOHUMLAMA_PLANLI' AND v_tai.hedef_tarih = v_s + 10 AND v_tai.hedef_saat = '10:00'
                        AND v_tai.kaynak = 'TEDAVI_SABLON_TOHUMLAMA:' || v_c.id || ':' || pg_temp.kb_c('OVSYNC_SABLON'),
    'S8-start', 'D60 TAI (başlangıç+10 10:00)', row_to_json(v_tai)::text);
  SELECT * INTO v_g FROM public.gorev_log WHERE id = v_g.id;
  PERFORM pg_temp.kb_ok(v_g.tamamlandi AND NOT v_g.iptal AND v_g.kapatan_ref = 'case:' || v_c.id, 'S8-start', 'OVSYNC_BASLAT tamamlandi, kapatan case:<id>', row_to_json(v_g)::text);
  PERFORM pg_temp.kb_ok((SELECT durum FROM public.protokol_instance WHERE id = v_g.protokol_instance_id) = 'tamamlandi', 'S8-start', 'rota instance tamamlandi', NULL);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_pgg AND iptal AND tamamlandi AND kapatan_ref LIKE 'ILK_TOH_PROTOKOL_YERINE%';
  PERFORM pg_temp.kb_ok(v_n = 1, 'S8-start', 'açık PG_TOHUMLAMA görevi ILK_TOH_PROTOKOL_YERINE ile iptal',
    (SELECT row_to_json(g)::text FROM public.gorev_log g WHERE id = v_pgg));
  -- SK4
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_b AND kaynak = 'DOGUM-' || v_b AND gorev_tipi = 'DIGER'
     AND iptal AND kapatan_ref = 'ILK_TOH_D58_IPTAL' AND hedef_tarih = v_d + 58;
  PERFORM pg_temp.kb_ok(v_n = 1, 'SK4', 'D58 kızgınlık takibi iptal', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_b AND etken_kod = 'E_VIT' AND hedef_tarih = v_d + 53 AND NOT iptal AND NOT tamamlandi;
  PERFORM pg_temp.kb_ok(v_n = 1, 'SK4', 'D53 E-vit açık kalır', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE tip = 'FIRST_SERVICE_PROTOCOL_STARTED' AND ref_id = v_c.id::text;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S8-start', 'FIRST_SERVICE_PROTOCOL_STARTED', v_n::text);

  -- T18: tekrar çağrı ve zamanlayıcı → ikinci vaka/TAI yok
  v_r := public.start_first_service_protocol(v_g.id);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND (v_r->>'zaten')::boolean, 'T18', 'tekrar → {ok, zaten}', v_r::text);
  v_z := public.ilk_tohumlama_zamanlayici();
  SELECT count(*) INTO v_n FROM public.cases WHERE animal_id = v_b;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T18', 'tek vaka', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_b AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT iptal;
  PERFORM pg_temp.kb_ok(v_n = 1, 'T18', 'tek D60 TAI görevi', v_n::text);
  RAISE NOTICE 'PASS S8-start/SK4/T18: D50 atomik zincir (vaka+4 seans+D60 TAI), D58 iptal/D53 kalır; tekrar ve cron tek vaka';
END $t$;

-- T29: abort → aynı kapı; D50 abort GERÇEKLEŞME tarihinden. S-9: 2 argümanlı çağrı tek overload'a çözülür
DO $t$
DECLARE v_c text := pg_temp.kb_hayvan(); v_toh uuid; v_r jsonb; v_g record; v_ad date := CURRENT_DATE - 3; v_n int; v_b2 uuid;
BEGIN
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_c, CURRENT_DATE - 60, 'Gebe', 'KB-SP') RETURNING id INTO v_toh;
  v_r := public.tohumlama_abort(p_tohumlama_id := v_toh::text, p_notlar := 'kb abort', p_abort_tarihi := v_ad);
  SELECT * INTO v_g FROM public.gorev_log WHERE hayvan_id = v_c AND gorev_tipi = 'OVSYNC_BASLAT';
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_g.hedef_tarih = v_ad + 50 AND v_g.hedef_saat = '10:00' AND v_g.kaynak = 'ILK-TOH-ABORT-' || v_toh,
    'T29', 'abort → OVSYNC_BASLAT abort_tarihi+50, kaynak ILK-TOH-ABORT-<id>', coalesce(row_to_json(v_g)::text, v_r::text));
  PERFORM pg_temp.kb_ok((SELECT baslangic FROM public.protokol_instance WHERE id = v_g.protokol_instance_id) = v_ad, 'T29', 'instance başlangıcı abort tarihi', NULL);

  SELECT count(*) INTO v_n FROM pg_proc WHERE proname = 'tohumlama_abort' AND pronamespace = 'public'::regnamespace;
  PERFORM pg_temp.kb_ok(v_n = 1 AND to_regprocedure('public.tohumlama_abort(text,text,date)') IS NOT NULL, 'S9', 'tohumlama_abort tek overload (3 argüman)', v_n::text);
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (pg_temp.kb_hayvan(), CURRENT_DATE - 10, 'Bekliyor', 'KB-SP') RETURNING id INTO v_b2;
  v_r := public.tohumlama_abort(v_b2::text, 'x');   -- 2 argüman: 42725 yok, 3'lüye DEFAULT ile çözülür
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean IS FALSE AND v_r->>'error' LIKE 'Sadece Gebe%', 'S9', '2 argümanlı çağrı çözülür (not unique yok)', v_r::text);
  RAISE NOTICE 'PASS T29/S9: abort → D50 abort tarihinden; tohumlama_abort tek overload';
END $t$;

-- T20: D50 öncesi tohumlama/gebelik → 50/60 görevleri iptal/skip; muafiyet kodları
DO $t$
DECLARE
  v_d text := pg_temp.kb_hayvan(); v_e text := pg_temp.kb_hayvan(); v_f text := pg_temp.kb_hayvan(); v_g text := pg_temp.kb_hayvan();
  v_p text := pg_temp.kb_hayvan(1500, 'Satıldı');
  v_r jsonb; v_gorev record; v_gid uuid; v_n int; v_h text; v_bek text;
BEGIN
  -- (a) tohumlama_kaydet açık OVSYNC_BASLAT'ı muaf eder (+ instance iptal)
  v_r := public.dogum_kaydet(v_d, CURRENT_DATE - 60, pg_temp.kb_id('KBY'));
  SELECT * INTO v_gorev FROM public.gorev_log WHERE hayvan_id = v_d AND gorev_tipi = 'OVSYNC_BASLAT';
  v_r := public.tohumlama_kaydet(v_d, CURRENT_DATE, 'KB-SP');
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_gorev.id AND iptal AND tamamlandi AND kapatan_ref = 'ILK_TOH_MUAF:TOHUMLAMA';
  PERFORM pg_temp.kb_ok(v_n = 1, 'T20', 'tohumlama → OVSYNC_BASLAT ILK_TOH_MUAF:TOHUMLAMA', v_n::text);
  PERFORM pg_temp.kb_ok((SELECT durum FROM public.protokol_instance WHERE id = v_gorev.protokol_instance_id) = 'iptal', 'T20', 'rota instance iptal', NULL);

  -- (b) start_first_service_protocol muafiyetleri
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_e, CURRENT_DATE - 5, 'Bekliyor', 'KB-SP');   -- TOHUMLAMA_VAR
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_f, CURRENT_DATE - 100, 'Gebe', 'KB-SP');     -- GEBE (olay öncesi)
  PERFORM pg_temp.kb_ovsync_vaka(v_g);                                                                                 -- AKTIF_SENKRONIZASYON
  FOR v_h, v_bek IN SELECT * FROM (VALUES (v_e, 'TOHUMLAMA_VAR'), (v_f, 'GEBE'), (v_g, 'AKTIF_SENKRONIZASYON'), (v_p, 'AKTIF_DEGIL')) x LOOP
    v_gid := public._ilk_tohumlama_rota_kur(v_h, CURRENT_DATE - 50, pg_temp.kb_id('ILK-TOH-KB'));
    IF v_h = v_e THEN
      -- rota tohumlamadan önce kurulmuş olsun: tohumlama olay tarihinden sonra
      NULL;
    END IF;
    v_r := public.start_first_service_protocol(v_gid);
    PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_r->>'atlandi' = v_bek, 'T20', 'atlandi=' || v_bek, v_r::text);
    SELECT * INTO v_gorev FROM public.gorev_log WHERE id = v_gid;
    PERFORM pg_temp.kb_ok(v_gorev.iptal AND v_gorev.tamamlandi AND v_gorev.kapatan_ref = 'ILK_TOH_MUAF:' || v_bek, 'T20', 'görev ILK_TOH_MUAF:' || v_bek, row_to_json(v_gorev)::text);
    PERFORM pg_temp.kb_ok((SELECT durum FROM public.protokol_instance WHERE id = v_gorev.protokol_instance_id) = 'iptal', 'T20', v_bek || ': instance iptal', NULL);
    SELECT count(*) INTO v_n FROM public.islem_log WHERE tip = 'FIRST_SERVICE_SKIPPED' AND ref_id = v_gid::text AND payload->>'neden' = v_bek;
    PERFORM pg_temp.kb_ok(v_n = 1, 'T20', v_bek || ': FIRST_SERVICE_SKIPPED (klinik gerekçe görünür)', v_n::text);
    SELECT count(*) INTO v_n FROM public.cases WHERE animal_id = v_h AND notes = 'İlk tohumlama zinciri (D50)';
    PERFORM pg_temp.kb_ok(v_n = 0, 'T20', v_bek || ': vaka açılmaz', v_n::text);
  END LOOP;
  RAISE NOTICE 'PASS T20: tohumlama OVSYNC_BASLAT''ı muaf eder; start TOHUMLAMA_VAR/GEBE/AKTIF_SENKRONIZASYON/AKTIF_DEGIL ile atlar (audit + instance iptal)';
END $t$;

-- T31: uygunsuz hayvanda da görev kurulur; elle iptal (REST PATCH yolu) denetim kaydına düşer
DO $t$
DECLARE v_k text := pg_temp.kb_hayvan(1500, 'Aktif', true); v_r jsonb; v_g uuid; v_n int;
BEGIN
  v_r := public.dogum_kaydet(v_k, CURRENT_DATE - 10, pg_temp.kb_id('KBY'));
  SELECT id INTO v_g FROM public.gorev_log WHERE hayvan_id = v_k AND gorev_tipi = 'OVSYNC_BASLAT' AND NOT iptal;
  PERFORM pg_temp.kb_ok(v_g IS NOT NULL, 'T31', 'kısır işaretli hayvanda da OVSYNC_BASLAT kurulur', NULL);
  -- frontend "iptal" yolu: gorev_log PATCH {tamamlandi, iptal}
  UPDATE public.gorev_log SET tamamlandi = true, tamamlanma_tarihi = now(), iptal = true WHERE id = v_g;
  SELECT count(*) INTO v_n FROM public.degisim_log WHERE tablo_adi = 'gorev_log' AND satir_pk->>'id' = v_g::text AND islem = 'U'
     AND 'iptal' = ANY (degisen_alanlar);
  PERFORM pg_temp.kb_ok(v_n = 1, 'T31', 'elle iptal degisim_log''a düşer (mevcut görev iptal yolu)', v_n::text);
  RAISE NOTICE 'PASS T31: uygunsuz hayvanda D50 görevi kurulur; elle iptal mevcut yolun denetim kaydına (degisim_log) düşer';
END $t$;

-- Zamanlayıcı: görev başına hata izolasyonu + sayaç + FIRST_SERVICE_CRON; cron job kaydı
DO $t$
DECLARE
  v_iyi text := pg_temp.kb_hayvan(); v_kotu text := pg_temp.kb_hayvan(300); v_gi uuid; v_gk uuid; v_z jsonb; v_n int; v_log jsonb;
BEGIN
  v_gi := public._ilk_tohumlama_rota_kur(v_iyi,  CURRENT_DATE - 50, pg_temp.kb_id('ILK-TOH-KB'));
  v_gk := public._ilk_tohumlama_rota_kur(v_kotu, CURRENT_DATE - 50, pg_temp.kb_id('ILK-TOH-KB'));   -- genç: D60 TAI uygunsuz → zincir hatası
  v_z := public.ilk_tohumlama_zamanlayici();
  PERFORM pg_temp.kb_ok((v_z->>'ok')::boolean IS FALSE AND (v_z->>'hata_sayisi')::int >= 1
                        AND (v_z->>'islenen')::int = (v_z->>'baslatilan')::int + (v_z->>'atlanan')::int + (v_z->>'zaten')::int + (v_z->>'hata_sayisi')::int,
    'S8-cron', 'ok:false, islenen = baslatilan+atlanan+zaten+hata', v_z::text);
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(v_z->'hatalar') e WHERE e->>'gorev_id' = v_gk::text AND e->>'mesaj' LIKE 'OVSYNC_TAI_OLUSMADI:%'),
    'S8-cron', 'kötü görev hatalar[] içinde (OVSYNC_TAI_OLUSMADI)', v_z->>'hatalar');
  PERFORM pg_temp.kb_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(v_z->'baslatilanlar') e WHERE e->>'gorev_id' = v_gi::text),
    'S8-cron', 'iyi görev başlatıldı', v_z->>'baslatilanlar');
  SELECT count(*) INTO v_n FROM public.cases WHERE animal_id = v_kotu;
  PERFORM pg_temp.kb_ok(v_n = 0, 'S8-cron', 'kötü hayvanda yarım zincir yok (vaka geri alındı)', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_gk AND NOT tamamlandi AND NOT iptal;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S8-cron', 'kötü görev açık kalır', v_n::text);
  SELECT count(*) INTO v_n FROM public.cases WHERE animal_id = v_iyi AND protocol_family = 'OVSYNC';
  PERFORM pg_temp.kb_ok(v_n = 1, 'S8-cron', 'iyi hayvanda vaka', v_n::text);
  SELECT payload INTO v_log FROM public.islem_log WHERE tip = 'FIRST_SERVICE_CRON' ORDER BY degisim_txid DESC NULLS LAST LIMIT 1;
  PERFORM pg_temp.kb_ok((v_log->>'hata_sayisi')::int = (v_z->>'hata_sayisi')::int AND (v_log->>'baslatilan')::int = (v_z->>'baslatilan')::int,
    'S8-cron', 'FIRST_SERVICE_CRON özeti = dönüş', coalesce(v_log::text, '<log yok>'));
  IF to_regclass('cron.job') IS NOT NULL THEN
    SELECT count(*) INTO v_n FROM cron.job WHERE jobname = 'ilk-tohumlama-ovsync-baslat' AND schedule = '0 4 * * *'
       AND command ILIKE '%ilk_tohumlama_zamanlayici()%';
    PERFORM pg_temp.kb_ok(v_n = 1, 'S8-cron', 'pg_cron job ilk-tohumlama-ovsync-baslat 0 4 * * *', v_n::text);
  END IF;
  RAISE NOTICE 'PASS S8-cron: zamanlayıcı hatayı görev başına izole eder, sayaçlar tutarlı, özet audit; cron job kayıtlı';
END $t$;

-- R3.1 (#6): zamanlayıcı en yeni hedef_tarih'li OVSYNC_BASLAT görevini önce işler
-- (hedef_tarih DESC, id) — kalıcı hatalı eski bir görev kuyruğun başında oturup
-- yeni hayvanların D50 başlangıcını geciktirmesin.
DO $t$
DECLARE
  v_h1 text := pg_temp.kb_hayvan(); v_h2 text := pg_temp.kb_hayvan(); v_h3 text := pg_temp.kb_hayvan();
  v_g1 uuid; v_g2 uuid; v_g3 uuid; v_z jsonb; v_sira uuid[];
BEGIN
  v_g1 := public._ilk_tohumlama_rota_kur(v_h1, CURRENT_DATE - 60, pg_temp.kb_id('ILK-TOH-KB'));  -- hedef CURRENT_DATE-10 (en eski)
  v_g2 := public._ilk_tohumlama_rota_kur(v_h2, CURRENT_DATE - 55, pg_temp.kb_id('ILK-TOH-KB'));  -- hedef CURRENT_DATE-5
  v_g3 := public._ilk_tohumlama_rota_kur(v_h3, CURRENT_DATE - 51, pg_temp.kb_id('ILK-TOH-KB'));  -- hedef CURRENT_DATE-1 (en yeni)
  v_z := public.ilk_tohumlama_zamanlayici();
  SELECT array_agg((e->>'gorev_id')::uuid ORDER BY ord) INTO v_sira
    FROM jsonb_array_elements(v_z->'baslatilanlar') WITH ORDINALITY AS t(e, ord)
   WHERE (e->>'gorev_id')::uuid IN (v_g1, v_g2, v_g3);
  PERFORM pg_temp.kb_ok(v_sira = ARRAY[v_g3, v_g2, v_g1], 'S8-cron-sira',
    'zamanlayıcı en yeni hedef_tarih''li görevi önce işler (hedef_tarih DESC, id)', v_sira::text);
  RAISE NOTICE 'PASS S8-cron-sira: ilk_tohumlama_zamanlayici en yeni görevi önce işler';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 7 — S-9 ve ACL
-- ════════════════════════════════════════════════════════════════════════════
DO $t$
DECLARE
  r record; v_rpc text[] := ARRAY[
    'public.drug_class_ekle(text,text,text,uuid,text)', 'public.pg_uyari_kontrol(text[],text)',
    'public.tohumlama_gorev_ertele(uuid,date,time)', 'public.hizli_uygulama(text,text,numeric,text,text,text,boolean,text,timestamptz)',
    'public.seans_tamamla(uuid,boolean,text,boolean,text)', 'public.bulk_ilac(text[],text,numeric,text,text[],text)',
    'public.hizli_uygulama_geri_al(uuid)', 'public.close_case_with_remaining(uuid,text)',
    'public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)', 'public.tedavi_sablon_uygula(uuid,uuid,date)',
    'public.dogum_kaydet(text,date,text,text,text,numeric,text,text)', 'public.tohumlama_abort(text,text,date)',
    'public.start_first_service_protocol(uuid)', 'public.ilk_tohumlama_zamanlayici()'];
  v_ic text[] := ARRAY[
    'public._ovsync_pg_aktif()', 'public._trg_drug_classes_sistem_koru()', 'public._tohumlama_pencere(timestamptz)',
    'public._pg_urun_durumu(text,uuid)', 'public._pg_kapi(text,text,uuid,boolean)', 'public._pg_sonrasi_tohumlama(uuid)',
    'public._pg_olay_isle(text,text,text,text,uuid,timestamptz,jsonb,text)', 'public._pg_kapi_detay(jsonb,text,text)',
    'public._vaka_kapat(uuid,text,text,jsonb)', 'public._ilk_tohumlama_rota_kur(text,date,text)',
    'public._trg_uygulama_log_pg_geri_al()', 'public._son_tohumlama(text)'];
  v_f text; v_oid oid;
BEGIN
  FOREACH v_f IN ARRAY v_rpc || v_ic LOOP
    v_oid := to_regprocedure(v_f);
    PERFORM pg_temp.kb_ok(v_oid IS NOT NULL, 'ACL', v_f || ' var', 'yok');
    PERFORM pg_temp.kb_ok(NOT has_function_privilege('anon', v_oid, 'EXECUTE'), 'ACL', v_f || ': anon EXECUTE yok', 'var');
    PERFORM pg_temp.kb_ok((SELECT array_to_string(proconfig, ',') LIKE '%search_path=public%' FROM pg_proc WHERE oid = v_oid), 'ACL', v_f || ': SET search_path', 'yok');
  END LOOP;
  FOREACH v_f IN ARRAY v_rpc LOOP
    PERFORM pg_temp.kb_ok(has_function_privilege('authenticated', to_regprocedure(v_f), 'EXECUTE'), 'ACL', v_f || ': authenticated EXECUTE', 'yok');
    PERFORM pg_temp.kb_ok((SELECT prosecdef FROM pg_proc WHERE oid = to_regprocedure(v_f)), 'ACL', v_f || ': SECURITY DEFINER', 'değil');
  END LOOP;
  FOREACH v_f IN ARRAY v_ic LOOP
    PERFORM pg_temp.kb_ok(NOT has_function_privilege('authenticated', to_regprocedure(v_f), 'EXECUTE'), 'ACL', v_f || ': iç yardımcı authenticated''a kapalı', 'açık');
  END LOOP;
  -- eski imzalar düştü
  FOREACH v_f IN ARRAY ARRAY['public.hizli_uygulama(text,text,numeric,text,text,text)',
                             'public.hizli_uygulama(text,text,numeric,text,text,text,boolean,text)',
                             'public.seans_tamamla(uuid,boolean,text)',
                             'public.bulk_ilac(text[],text,numeric,text)', 'public.drug_class_ekle(text,text,text,uuid)',
                             'public.tohumlama_abort(text,text)'] LOOP
    PERFORM pg_temp.kb_ok(to_regprocedure(v_f) IS NULL, 'ACL', v_f || ' DROP edildi', 'hâlâ var');
  END LOOP;
  -- S-9: abort_kaydet authenticated'a kapalı
  IF to_regprocedure('public.abort_kaydet(text,text)') IS NOT NULL THEN
    PERFORM pg_temp.kb_ok(NOT has_function_privilege('authenticated', 'public.abort_kaydet(text,text)'::regprocedure, 'EXECUTE')
                          AND NOT has_function_privilege('anon', 'public.abort_kaydet(text,text)'::regprocedure, 'EXECUTE'),
      'S9', 'abort_kaydet authenticated/anon EXECUTE yok', 'var');
  END IF;
  -- pg_application_event: RLS açık, authenticated yalnız SELECT, anon hiç
  PERFORM pg_temp.kb_ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.pg_application_event'::regclass), 'ACL', 'pg_application_event RLS açık', 'kapalı');
  PERFORM pg_temp.kb_ok(has_table_privilege('authenticated', 'public.pg_application_event', 'SELECT')
                        AND NOT has_table_privilege('authenticated', 'public.pg_application_event', 'INSERT,UPDATE,DELETE')
                        AND NOT has_table_privilege('anon', 'public.pg_application_event', 'SELECT,INSERT,UPDATE,DELETE'),
    'ACL', 'pg_application_event: authenticated SELECT-only, anon yok', 'farklı');
  RAISE NOTICE 'PASS ACL/S9: % RPC authenticated''a açık, % iç yardımcı kapalı; anon hiçbirinde yok; eski imzalar düştü; abort_kaydet kapalı',
    cardinality(v_rpc), cardinality(v_ic);
END $t$;

-- ════════════════════════════════════════════════════════════════════════════
-- BÖLÜM 8 — MK10 gerçek degisim_geri_al('satir') yolu (surum_gizli, koşullu)
-- ════════════════════════════════════════════════════════════════════════════
-- Başka bir ajan kabul DB'sine surum_gizli şemasını ayrıca kuruyor (DDL-only,
-- sahip şifresi ASLA taşınmaz — surum_gizli.sahip_sifresi bu DB'de 0 satırdır).
-- Bu blok, o satırı yalnız KENDİ (dışarıya sızmayan, rastgele üretilmiş, hiçbir
-- dosyaya yazılmayan) geçici test şifresiyle KENDİ transaction'ında doldurur;
-- sarmalayıcı ROLLBACK ile birlikte iz bırakmadan geri gider. İmza: js/ui.js
-- _protokolGeriAl (2080-2091) → dgGeriAlAkisi → js/api.js degisim_geri_al
-- RPC çağrısı; gerçek imza/gövde surum_gizli._degisim_uygula → DELETE FROM
-- uygulama_log → _trg_uygulama_log_pg_geri_al (MK10, 000004).
DO $t$
DECLARE
  v_schema_var  boolean := to_regnamespace('surum_gizli') IS NOT NULL
                            AND to_regprocedure('public.degisim_geri_al(jsonb,text,uuid,text)') IS NOT NULL
                            AND to_regprocedure('public.geri_alma_bileti_al(text)') IS NOT NULL;
  v_h      text; v_toh uuid; v_r jsonb; v_uyg uuid; v_sifre text;
  v_bilet  uuid; v_gr jsonb; v_ev record; v_n int; v_pg_gorev uuid;
BEGIN
  IF NOT v_schema_var THEN
    RAISE NOTICE 'ATLANDI: surum_gizli yok — gerçek degisim_geri_al(''satir'') yolu test edilemedi';
    RETURN;
  END IF;
  -- Sahip şifresi korunur (demo/prod'da satır var): geçici şifre yalnız boş tabloya
  -- yazılır; dolu tabloda UI yolu atlanır, MK10 trigger'ı S4-geri-al bloklarında test edilir.
  IF EXISTS (SELECT 1 FROM surum_gizli.sahip_sifresi) THEN
    RAISE NOTICE 'ATLANDI MK10-ui: surum_gizli.sahip_sifresi dolu (demo/prod) — sahip şifresine dokunulmaz';
    RETURN;
  END IF;

  -- fixture: Bekliyor tohumlama (D30, onay şartlı) + onaylı PG uygulaması → ACK_PENDING
  v_h := pg_temp.kb_hayvan();
  v_r := public.tohumlama_kaydet(v_h, CURRENT_DATE - 30, 'KB-SP');
  v_toh := (v_r->>'tohumlama_id')::uuid;
  v_r := public.hizli_uygulama(p_hayvan_id := v_h, p_stok_id := pg_temp.kb_c('PG_STOK'), p_doz := 2, p_birim := 'ml', p_rota := 'IM',
                               p_notlar := 'kb degisim_geri_al', p_pg_onay := true, p_pg_gerekce := 'kb ui yolu');
  v_uyg := (v_r->>'id')::uuid;
  SELECT * INTO v_ev FROM public.pg_application_event WHERE source_type = 'HIZLI_UYGULAMA' AND source_id = v_uyg::text;
  v_pg_gorev := v_ev.tohumlama_gorev_id;
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE kaynak = 'TOH-' || v_toh AND gorev_tipi = 'GEBELIK_KONTROL' AND iptal AND kapatan_ref = 'PG_ONAY:' || v_ev.id;
  PERFORM pg_temp.kb_ok(v_ev.karar = 'ACK_PENDING' AND v_pg_gorev IS NOT NULL AND v_n = 2,
    'MK10-ui', 'fixture: ACK_PENDING + PG görev + 2 GEBELIK_KONTROL iptal', row_to_json(v_ev)::text);

  -- gerçek UI yolu: geçici test şifresi (bu transaction'a özel, hiçbir dosyaya yazılmaz) → bilet → degisim_geri_al('satir')
  v_sifre := 'KB-KABUL-' || gen_random_uuid()::text;
  INSERT INTO surum_gizli.sahip_sifresi (id, hash) VALUES (1, extensions.crypt(v_sifre, extensions.gen_salt('bf')));
  v_gr := public.geri_alma_bileti_al(v_sifre);
  PERFORM pg_temp.kb_ok((v_gr->>'ok')::boolean, 'MK10-ui', 'geçici test şifresiyle bilet alınır', v_gr::text);
  v_bilet := (v_gr->>'bilet')::uuid;

  v_r := public.degisim_geri_al(jsonb_build_object('tablo', 'uygulama_log', 'pk', v_uyg::text), 'satir', v_bilet, 'kb ui geri al');
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean, 'MK10-ui', 'degisim_geri_al ok (gerçek UI/RLS-dışı motor)', v_r::text);

  SELECT count(*) INTO v_n FROM public.uygulama_log WHERE id = v_uyg;
  PERFORM pg_temp.kb_ok(v_n = 0, 'MK10-ui', 'uygulama_log satırı silinir (UI motoru)', v_n::text);
  PERFORM pg_temp.kb_ok((SELECT geri_alindi_at IS NOT NULL FROM public.pg_application_event WHERE id = v_ev.id),
    'MK10-ui', 'aynı trigger: event geri_alindi_at dolu', NULL);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_pg_gorev AND iptal AND kapatan_ref = 'PG_GERI_AL:' || v_ev.id;
  PERFORM pg_temp.kb_ok(v_n = 1, 'MK10-ui', 'PG görevi iptal (PG_GERI_AL)', v_n::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE kaynak = 'TOH-' || v_toh AND gorev_tipi = 'GEBELIK_KONTROL' AND NOT iptal AND NOT tamamlandi;
  PERFORM pg_temp.kb_ok(v_n = 2, 'MK10-ui', 'PG_ONAY ile iptal edilen 2 GEBELIK_KONTROL geri açılır', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE tip = 'GERI_ALINDI' AND ref_tablo = 'uygulama_log' AND ref_id = v_uyg::text;
  PERFORM pg_temp.kb_ok(v_n = 1, 'MK10-ui', 'GERI_ALINDI telafi kaydı (surum_gizli motoru)', v_n::text);

  -- iz bırakma: geçici şifre satırı da bu transaction'da temizlenir (ROLLBACK zaten gidecekti)
  DELETE FROM surum_gizli.sahip_sifresi WHERE id = 1 AND extensions.crypt(v_sifre, hash) = hash;
  RAISE NOTICE 'PASS MK10-ui: gerçek degisim_geri_al(''satir'') yolu (UI motoru) → event işaretli, PG görevi iptal, GEBELIK_KONTROL geri açık';
END $t$;


-- ════════════════════════════════════════════════════════════════════════════
-- ÖZET
-- ════════════════════════════════════════════════════════════════════════════
DO $t$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM pg_temp.kb_gecti;
  RAISE NOTICE 'OZET: % PASS', v_n;
  RAISE NOTICE 'KABUL TAMAM: tüm testler PASS';
END $t$;
