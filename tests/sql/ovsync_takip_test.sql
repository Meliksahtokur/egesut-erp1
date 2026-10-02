-- tests/sql/ovsync_takip_test.sql
-- Ovsync Takip Ekranı — demo DB-SQL senaryoları (plan v7 P12; katalog T-80, T-08..T-10, T-72,
-- T-19/T-23, T-74, T-90, T-92, T-93 katmanları; zarf: runs/2026-09-28-ovsync-takip/test-uygulanabilir-GOREV.md)
--
-- HEDEF: YALNIZ demo (Supabase Demo-Mirror, proje ref vtzqjmazsvurxdeondmi). PROD'a bu betikle
-- erişilmez; yazmalar E2E-TAKIP- önekli kendi fixture'larıyla sınırlıdır (marker'sız veriye dokunmaz).
--
-- KOŞUM (demo pooler):
--   export OVS_DEMO_DB_URL='postgresql://postgres.vtzqjmazsvurxdeondmi:<PAROLA>@aws-0-eu-west-1.pooler.supabase.com:5432/postgres'
--   foks=$( [[ "$OVS_DEMO_DB_URL" == *vtzqjmazsvurxdeondmi* ]] && echo true || echo false )
--   psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v ovs_fixture_ok=$foks -f tests/sql/ovsync_takip_test.sql
--   (ovs_fixture_ok=false / verilmemişse BETİK YALNIZ OKUR — fixture yazmaları kapalı, senaryolar UNMEASURED düşer.)
--
-- KIRMIZI SEMANTİĞİ (zarf kuralı): ürün implementasyonu (P1..P3b) başlamadan sarmal RPC
-- (tohumlama_bos_ve_devam), gorev_log.takip_kapanis_nedeni kolonu ve P3a tetikleyicileri demo'da
-- YOKTUR. Buna bağlı assertion'lar bugün RED çıkar; RED = beklenen-öncesi durumdur, PASS SAYILMAZ.
-- Özet bölümü her senaryoyu PASS / RED(beklenen) / KISMI / UNMEASURED olarak ayrı yazar.
--
-- TEMİZLİK: her fixture bloğu başta ve sonda kendi E2E-TAKIP-% kayıtlarını siler (idempotent,
-- tekrar koşulabilir). Bağımlılık sırası: gorev_log → tohumlama → hayvanlar.
-- Tip gerçekleri (demo information_schema, 2026-09-29 ölçüm): hayvanlar.id=text; tohumlama.id=uuid,
-- hayvan_id=text; gorev_log.id=uuid, hayvan_id=text. Tablo aramalarında table_schema='public'
-- (prod_fdw aynası aynı tablo adlarını taşır — kariştir).
-- REST probe çıktıları ${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum/ altına yazılır (/tmp sabit yazım yok).

\if :{?ovs_fixture_ok}
\else
\set ovs_fixture_ok false
\endif
\echo '=== OVSYNC TAKIP — demo DB-SQL testi (ovs_fixture_ok=:ovs_fixture_ok) ==='

-- ── S0. Ortam envanteri + hedef doğrulama (salt-okuma) ──────────────────────
DROP TABLE IF EXISTS _ovs_durum;
CREATE TEMP TABLE _ovs_durum(kodsatir text PRIMARY KEY, deger text, etiket text);

INSERT INTO _ovs_durum
SELECT 'baglanti', current_database()||'@'||coalesce(inet_server_addr()::text,'(unix)')||' user='||current_user, 'hedef-iz'
UNION ALL
SELECT 'bayrak_ovsync', coalesce((SELECT deger::text FROM protokol_ayar WHERE anahtar='ovsync_pg_kurallari_aktif'),'(yok)'), 'T-46 önkoşul'
UNION ALL
SELECT 'esik_muayene', coalesce((SELECT deger::text FROM protokol_ayar WHERE anahtar='sessiz_tohumlama_muafiyet_gun'),'(yok)'), 'T-43/T-45 eşik'
UNION ALL
SELECT 'sarmal_rpc_var', (SELECT count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='tohumlama_bos_ve_devam'), 'P2b var mı (0=RED zemini)'
UNION ALL
SELECT 'takip_kolonu_var', (SELECT count(*)::text FROM information_schema.columns WHERE table_schema='public' AND table_name='gorev_log' AND column_name='takip_kapanis_nedeni'), 'P2a var mı'
UNION ALL
SELECT 'takip_tetik_var', (SELECT count(*)::text FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal AND t.tgname ILIKE '%takip%'), 'P3a var mı'
UNION ALL
SELECT 'ovsync_disease', coalesce((SELECT string_agg(name,', ') FROM diseases WHERE name IN ('Ovsync','Ovsync Protokol')),'(yok)'), 'P3a cases tetikleyici ad-çözümü (demo katalog adı ölçüldü: Ovsync Protokol)'
UNION ALL
SELECT 'kizginlik_acl', 'anon='||(SELECT has_function_privilege('anon','public.kizginlik_vaka_ac(text,text,text,text)','EXECUTE')::text)||' auth='||(SELECT has_function_privilege('authenticated','public.kizginlik_vaka_ac(text,text,text,text)','EXECUTE')::text), 'T-90 anon ACL'
UNION ALL
SELECT 'S1_T80','UNMEASURED','T-80 tek üretici'
UNION ALL
SELECT 'S2_T08','UNMEASURED','T-08 atomiklik'
UNION ALL
SELECT 'S2_XOR','UNMEASURED','T-72 XOR guard'
UNION ALL
SELECT 'S3_KAPANIS','UNMEASURED','T-19/T-23 kapanış'
UNION ALL
SELECT 'S4_DAL1','UNMEASURED','T-74 dal1 guard'
UNION ALL
SELECT 'S4_DAL2','UNMEASURED','T-74 dal2 iptal'
UNION ALL
SELECT 'S4_DAL3','UNMEASURED','T-74 dal3 sutten'
UNION ALL
SELECT 'S5_H5','UNMEASURED','T-93 H5 satır-sonucu';

\echo '--- S0 ortam ---'
SELECT kodsatir||' = '||deger||'  ['||etiket||']' FROM _ovs_durum WHERE kodsatir NOT LIKE 'S%' ORDER BY kodsatir;

-- ── S1 (T-80). ≥40 g TEK ÜRETİCİ: tohumlama_kaydet RPC'si GEBELIK_KONTROL doğurmaz ──
-- NOT: +21/+35 üretimi RPC gövdesindedir (20260923000005:438-444) — doğrudan tablo INSERT'i
-- ölçmez; bu senaryo RPC yolunu çağırır (P2c'nin gerçek hedefi).
\echo '--- S1 T-80 tek üretici (RPC yolu) ---'
\if :ovs_fixture_ok
DO $do$
DECLARE
  v_h text; v_res jsonb; v_gk int;
BEGIN
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';

  v_h := 'E2E-TAKIP-H-'||substr(gen_random_uuid()::text,1,8);
  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
  VALUES (v_h, 'E2E-TAKIP-80', 'Dişi', CURRENT_DATE - 400, 'Sağmal (Laktasyonda)');

  -- yeni tohumlama kaydı — RPC yolu (VWP: doğum 400 g önce → OK; yaş 400 g → OK)
  v_res := public.tohumlama_kaydet(v_h, CURRENT_DATE, 'E2E-SPERMA-PROBE');

  SELECT count(*) INTO v_gk FROM gorev_log
   WHERE hayvan_id = v_h AND gorev_tipi='GEBELIK_KONTROL' AND NOT iptal;

  IF v_gk = 0 THEN
    RAISE NOTICE 'S1/T-80: PASS — tohumlama_kaydet sonrası GEBELIK_KONTROL=0 (P2c uygulanmış)';
    UPDATE _ovs_durum SET deger='PASS', etiket='T-80 tek üretici (RPC)' WHERE kodsatir='S1_T80';
  ELSE
    RAISE NOTICE 'S1/T-80: RED (beklenen-öncesi) — % adet GEBELIK_KONTROL doğdu; +21/+35 üretimi hâlâ canlı (P2c bekleniyor)', v_gk;
    UPDATE _ovs_durum SET deger='RED(beklenen): '||v_gk||' görev doğdu (RPC yolu)', etiket='T-80 — P2c bekleniyor' WHERE kodsatir='S1_T80';
  END IF;

  -- temizlik (protokol_instance kaynak_ref kolonu yoksa TRY ile geç)
  DELETE FROM gorev_log WHERE hayvan_id = v_h;
  DELETE FROM tohumlama WHERE hayvan_id = v_h;
  BEGIN
    DELETE FROM protokol_instance WHERE kaynak_ref IN (SELECT 'TOH-'||id FROM tohumlama WHERE hayvan_id = v_h);
  EXCEPTION WHEN OTHERS THEN NULL; END;
  DELETE FROM hayvanlar WHERE id = v_h;
EXCEPTION WHEN OTHERS THEN
  UPDATE _ovs_durum SET deger='HATA/KISMI: tohumlama_kaydet koşamadı: '||SQLSTATE||' '||SQLERRM, etiket='S1 T-80' WHERE kodsatir='S1_T80';
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  BEGIN
    DELETE FROM protokol_instance WHERE kaynak_ref IN (SELECT 'TOH-'||id FROM tohumlama WHERE hayvan_id LIKE 'E2E-TAKIP-H-%');
  EXCEPTION WHEN OTHERS THEN NULL; END;
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';
END
$do$;
\else
\echo 'S1 atlandı (fixture kapalı → UNMEASURED)'
\endif

-- ── S2 (T-08/T-10 + T-72 girişi). Boş+seçim ATOMİKLİĞİ: sarmal RPC ──
\echo '--- S2 T-08..T-10 sarmal atomiklik ---'
\if :ovs_fixture_ok
DO $do$
DECLARE
  v_h text; v_toh text; v_res jsonb; v_msg text; v_patladi boolean; v_sonuc text;
BEGIN
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';

  v_h := 'E2E-TAKIP-H-'||substr(gen_random_uuid()::text,1,8);
  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
  VALUES (v_h, 'E2E-TAKIP-08', 'Dişi', CURRENT_DATE - 400, 'Sağmal (Laktasyonda)');
  INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler)
  VALUES (gen_random_uuid(), v_h, CURRENT_DATE, 'Bekliyor', 1, '[]'::jsonb);
  -- (tarih=CURRENT_DATE: tablo yaş-guard'ı tohumlama tarihine göre sayar — -45 tarih 355 gün
  --  yaşla '12 aydan küçük' red üretir; doğru davranış, fixture bu red'i istemez.)
  SELECT id::text INTO v_toh FROM tohumlama WHERE hayvan_id = v_h LIMIT 1;

  -- T-08: PG dalında hata → Boş ATANMAZ (tek transaction). Bugün fonksiyon yok → RED(beklenen).
  v_patladi := false;
  BEGIN
    v_res := public.tohumlama_bos_ve_devam(p_tohumlama_id => v_toh, p_secim => 'PG', p_pg_urun => 'E2E-OLMAYAN-URUN');
    v_msg := 'hata KURULUMU patlamadı: ok='||coalesce(v_res->>'ok','?')||' — atomiklik sınanamadı (KISMI)';
  EXCEPTION WHEN OTHERS THEN
    v_patladi := true; v_msg := SQLSTATE||' '||SQLERRM;
  END;
  SELECT sonuc INTO v_sonuc FROM tohumlama WHERE id::text = v_toh;
  IF v_patladi AND v_msg LIKE '%does not exist%' THEN
    RAISE NOTICE 'S2/T-08: RED (beklenen-öncesi) — sarmal RPC yok; atomiklik henüz sınanamadı (%.60)', v_msg;
    UPDATE _ovs_durum SET deger='RED(beklenen): RPC yok — atomiklik P2b sonrası sınanır', etiket='T-08 atomiklik' WHERE kodsatir='S2_T08';
  ELSIF v_patladi AND v_sonuc = 'Bekliyor' THEN
    RAISE NOTICE 'S2/T-08: PASS — PG dalı hatada Boş atanmadı (ret: %)', v_msg;
    UPDATE _ovs_durum SET deger='PASS', etiket='T-08 atomiklik' WHERE kodsatir='S2_T08';
  ELSIF NOT v_patladi THEN
    RAISE NOTICE 'S2/T-08: KISMI — %', v_msg;
    UPDATE _ovs_durum SET deger='KISMI: hata kurulumu patlamadı, atomiklik sınanmadı', etiket='T-08' WHERE kodsatir='S2_T08';
  ELSE
    RAISE NOTICE 'S2/T-08: RED — ret=%, sonuc=% (beklenen: red + Bekliyor)', v_msg, v_sonuc;
    UPDATE _ovs_durum SET deger='RED: '||v_msg, etiket='T-08 atomiklik' WHERE kodsatir='S2_T08';
  END IF;

  -- T-72 girişi: XOR guard (iki id birden → GIRIS_CIFT_ANLAMLI)
  BEGIN
    v_res := public.tohumlama_bos_ve_devam(p_tohumlama_id => v_toh, p_muayene_gorev_id => gen_random_uuid(), p_secim => 'OVSYNC');
    v_msg := 'beklenmedik başarı';
  EXCEPTION WHEN OTHERS THEN v_msg := SQLSTATE||' '||SQLERRM; END;
  IF v_msg LIKE '%GIRIS_CIFT_ANLAMLI%' THEN
    UPDATE _ovs_durum SET deger='PASS', etiket='T-72 XOR guard' WHERE kodsatir='S2_XOR';
    RAISE NOTICE 'S2/XOR: PASS — GIRIS_CIFT_ANLAMLI';
  ELSE
    UPDATE _ovs_durum SET deger='RED: '||v_msg, etiket='T-72 XOR — P2b bekleniyor' WHERE kodsatir='S2_XOR';
    RAISE NOTICE 'S2/XOR: RED (beklenen-öncesi) — ret=%', v_msg;
  END IF;

  DELETE FROM gorev_log WHERE hayvan_id = v_h;
  DELETE FROM tohumlama WHERE hayvan_id = v_h;
  DELETE FROM hayvanlar WHERE id = v_h;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'S2: RED (beklenen-öncesi) — sarmal RPC yok: % %', SQLSTATE, SQLERRM;
  UPDATE _ovs_durum SET deger='RED(beklenen): tohumlama_bos_ve_devam yok ('||SQLSTATE||')', etiket='T-08/T-72 — P2b bekleniyor' WHERE kodsatir='S2_T08';
  UPDATE _ovs_durum SET deger='RED(beklenen): fonksiyon yok', etiket='T-72 XOR — P2b bekleniyor' WHERE kodsatir='S2_XOR';
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';
END
$do$;
\else
\echo 'S2 atlandı (fixture kapalı → UNMEASURED)'
\endif

-- ── S3 (T-19/T-23). Takip otomatik kapanışı: tohumlama INSERT → sessiz kapanış + neden ──
\echo '--- S3 T-19/T-23 kapanış tetikleyicisi ---'
\if :ovs_fixture_ok
DO $do$
DECLARE
  v_h text; v_g uuid; v_neden text; v_iptal boolean;
BEGIN
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';

  v_h := 'E2E-TAKIP-H-'||substr(gen_random_uuid()::text,1,8);
  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
  VALUES (v_h, 'E2E-TAKIP-19', 'Dişi', CURRENT_DATE - 400, 'Sağmal (Laktasyonda)');

  v_g := gen_random_uuid();
  INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
  VALUES (v_g, v_h, 'TAKIP_MUAYENE', 'E2E-TAKIP-takip-gorev', CURRENT_DATE + 7, false, false, 'TAKIP:E2E-TOH');

  INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler)
  VALUES (gen_random_uuid(), v_h, CURRENT_DATE, 'Bekliyor', 1, '[]'::jsonb);

  SELECT iptal INTO v_iptal FROM gorev_log WHERE id = v_g;
  BEGIN
    SELECT takip_kapanis_nedeni INTO v_neden FROM gorev_log WHERE id = v_g;
  EXCEPTION WHEN undefined_column THEN v_neden := '(kolon yok — P2a bekleniyor)'; END;

  IF v_iptal AND v_neden = 'YENI_TOHUMLAMA' THEN
    RAISE NOTICE 'S3/T-19: PASS — sessiz kapanış + neden kayıtlı';
    UPDATE _ovs_durum SET deger='PASS', etiket='T-19/T-23 kapanış+neden' WHERE kodsatir='S3_KAPANIS';
  ELSE
    RAISE NOTICE 'S3/T-19: RED (beklenen-öncesi) — iptal=%, neden=%', v_iptal, v_neden;
    UPDATE _ovs_durum SET deger='RED(beklenen): iptal='||v_iptal||', neden='||v_neden, etiket='T-19/T-23 — P2a/P3a bekleniyor' WHERE kodsatir='S3_KAPANIS';
  END IF;

  DELETE FROM gorev_log WHERE hayvan_id = v_h;
  DELETE FROM tohumlama WHERE hayvan_id = v_h;
  DELETE FROM hayvanlar WHERE id = v_h;
EXCEPTION WHEN OTHERS THEN
  UPDATE _ovs_durum SET deger='HATA: '||SQLERRM, etiket='S3 beklenmedik' WHERE kodsatir='S3_KAPANIS';
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';
END
$do$;
\else
\echo 'S3 atlandı (fixture kapalı → UNMEASURED)'
\endif

-- ── S4 (T-74/H6). Muayene guard ÜÇ DAL: gorev_tamamla ──
\echo '--- S4 T-74 guard üç dal ---'
\if :ovs_fixture_ok
DO $do$
DECLARE
  v_h text; v_gk uuid; v_gi uuid; v_gs uuid;
BEGIN
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';
  v_h := 'E2E-TAKIP-H-'||substr(gen_random_uuid()::text,1,8);
  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
  VALUES (v_h, 'E2E-TAKIP-74', 'Dişi', CURRENT_DATE - 400, 'Sağmal (Laktasyonda)');
  v_gk := gen_random_uuid(); v_gi := gen_random_uuid(); v_gs := gen_random_uuid();
  INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
  VALUES (v_gk, v_h, 'GEBELIK_KONTROL', 'E2E-TAKIP-gk', CURRENT_DATE, false, false, 'GEBELIK-KONTROL-E2E')
       , (v_gi, v_h, 'TAKIP_MUAYENE',    'E2E-TAKIP-tp', CURRENT_DATE, false, false, 'TAKIP:E2E-TOH')
       , (v_gs, v_h, 'SUTTEN_KESME',     'E2E-TAKIP-sk', CURRENT_DATE, false, false, 'E2E');

  -- DAL 1: jenerik tamamlama + muayene tipi → MUAYENE_SONUC_GEREKLI red beklenir
  BEGIN
    PERFORM public.gorev_tamamla(v_gk::text);
    IF (SELECT tamamlandi FROM gorev_log WHERE id = v_gk) THEN
      UPDATE _ovs_durum SET deger='RED(beklenen): görev sonuçsuz kapandı (guard yok)', etiket='T-74 dal1 — P3b bekleniyor' WHERE kodsatir='S4_DAL1';
      RAISE NOTICE 'S4/dal1: RED (beklenen-öncesi) — jenerik tamamlama kapanıyor';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%MUAYENE_SONUC_GEREKLI%' AND NOT (SELECT tamamlandi FROM gorev_log WHERE id = v_gk) THEN
      UPDATE _ovs_durum SET deger='PASS', etiket='T-74 dal1 guard' WHERE kodsatir='S4_DAL1';
      RAISE NOTICE 'S4/dal1: PASS — MUAYENE_SONUC_GEREKLI';
    ELSE
      UPDATE _ovs_durum SET deger='RED: beklenmedik red: '||SQLERRM, etiket='T-74 dal1' WHERE kodsatir='S4_DAL1';
      RAISE NOTICE 'S4/dal1: RED — beklenmedik red: %', SQLERRM;
    END IF;
  END;

  -- DAL 2: p_iptal=true + muayene tipi → iptal BAŞARILI (T5 sözleşmesi; H6 korur — bugün de yeşil)
  BEGIN
    PERFORM public.gorev_tamamla(v_gi::text, NULL, true);
    IF (SELECT iptal FROM gorev_log WHERE id = v_gi) THEN
      UPDATE _ovs_durum SET deger='PASS', etiket='T-74 dal2 p_iptal iptali' WHERE kodsatir='S4_DAL2';
      RAISE NOTICE 'S4/dal2: PASS — p_iptal=true iptali çalışıyor';
    ELSE
      UPDATE _ovs_durum SET deger='RED: iptal uygulanmadı', etiket='T-74 dal2' WHERE kodsatir='S4_DAL2';
      RAISE NOTICE 'S4/dal2: RED — iptal uygulanmadı';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    UPDATE _ovs_durum SET deger='RED: '||SQLERRM, etiket='T-74 dal2' WHERE kodsatir='S4_DAL2';
    RAISE NOTICE 'S4/dal2: RED — %', SQLERRM;
  END;

  -- DAL 3: SUTTEN_KESME tamamlaması → mevcut davranış (H6 guard dokunmaz)
  BEGIN
    PERFORM public.gorev_tamamla(v_gs::text);
    IF (SELECT tamamlandi FROM gorev_log WHERE id = v_gs) THEN
      UPDATE _ovs_durum SET deger='PASS', etiket='T-74 dal3 mevcut davranış' WHERE kodsatir='S4_DAL3';
      RAISE NOTICE 'S4/dal3: PASS — SUTTEN_KESME mevcut davranış';
    ELSE
      UPDATE _ovs_durum SET deger='RED: kapanmadı', etiket='T-74 dal3' WHERE kodsatir='S4_DAL3';
      RAISE NOTICE 'S4/dal3: RED — kapanmadı';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    UPDATE _ovs_durum SET deger='HATA: '||SQLERRM, etiket='T-74 dal3' WHERE kodsatir='S4_DAL3';
    RAISE NOTICE 'S4/dal3: HATA — %', SQLERRM;
  END;

  DELETE FROM gorev_log WHERE hayvan_id = v_h;
  DELETE FROM hayvanlar WHERE id = v_h;
EXCEPTION WHEN OTHERS THEN
  UPDATE _ovs_durum SET deger='HATA: '||SQLERRM, etiket='S4 beklenmedik' WHERE kodsatir='S4_DAL1';
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-%';
END
$do$;
\else
\echo 'S4 atlandı (fixture kapalı → UNMEASURED)'
\endif

-- ── S5 (T-93). H5 satır-sonucu: bulk karışık liste onaysız açık-takipli satır işlenmez ──
\echo '--- S5 T-93 H5 satır-sonucu (fail-closed) ---'
DO $do$
BEGIN
  -- Sözleşme zemini: takip kolonu (P2a) ve sarmal yoksa bu senaryo koşulamaz —
  -- TAKIP_ACIK satır JSON alanı P3b'de makine-okunur sabitlenecek (rereview5 ÖNEMLİ #2).
  -- Betik alan adı varsaymaz; koşum P2a/P3b zeminine bırakılır (fail-closed — zarf kuralı).
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='gorev_log' AND column_name='takip_kapanis_nedeni') = 0 THEN
    RAISE NOTICE 'S5/T-93: RED(beklenen) — takip_kapanis_nedeni kolonu yok (P2a); TAKIP_ACIK satır sözleşmesi P3b''de sabitlenecek';
    UPDATE _ovs_durum SET deger='RED(beklenen): P2a/P3b bekleniyor — satır sözleşmesi açık', etiket='T-93 H5 satır-sonucu' WHERE kodsatir='S5_H5';
  ELSE
    RAISE NOTICE 'S5/T-93: KISMI — P2a var; koşum P3b satır sözleşmesiyle (bu betik sürümünde yazılmadı — alan adı plandan sonra pinlenir)';
    UPDATE _ovs_durum SET deger='KISMI: P2a var, koşum P3b sonrası', etiket='T-93 H5 satır-sonucu' WHERE kodsatir='S5_H5';
  END IF;
END
$do$;

-- ── S6 (T-90). Eski/yeni imza + anon ACL — DB katmanı (REST probe'lar S7'de) ──
\echo '--- S6 T-90 ACL (DB) ---'
SELECT CASE WHEN deger LIKE 'anon=false auth=true' THEN 'S6/T-90 ACL: PASS — anon EXECUTE yok, authenticated VAR [demo ölçüm]'
            ELSE 'S6/T-90 ACL: RED — beklenmedik ACL: '||deger END AS sonuc
FROM _ovs_durum WHERE kodsatir='kizginlik_acl';
-- Not (C5/T-90): "eski imza → PGRST202/404" assertion'ı eski overload DROP'larından SONRA yeşile
-- döner; bugün eski imza canlı olduğundan REST katmanı RED(beklenen). Gerçek demo yanıtları
-- S7'de kaydedilir (assertion kayda sabitlenir — §10g C5).

-- ── S7. REST probe: gerçek yanıt kaydı (PGRST202/404 pin + anon 401 + T-92 tanıdan bağımsız) ──
-- psql \! = /bin/sh. Çağrılar yazmasız: olmayan RPC / olmayan param / anon / olmayan kizginlik_id.
\echo '--- S7 REST probe kayıtları ---'
\! mkdir -p "${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum"
\! DEMO_URL="${OVS_DEMO_URL:-https://vtzqjmazsvurxdeondmi.supabase.co}"; ANON="${OVS_DEMO_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8}"; OUT="${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum"; TOK=$(curl -s -X POST "$DEMO_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H 'Content-Type: application/json' -d '{"email":"demo@egesut.web","password":"demo2026"}' | jq -r '.access_token // empty'); echo "$TOK" > "$OUT/.tok"; if [ -n "$TOK" ]; then echo "S7 auth: OK"; else echo "S7 auth: BAŞARISIZ — REST katmanı UNMEASURED"; fi
-- 7a) OLMAYAN RPC (ovsync_takip_listele) — PGRST202/HTTP 404 pin
\! OUT="${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum"; DEMO_URL="${OVS_DEMO_URL:-https://vtzqjmazsvurxdeondmi.supabase.co}"; ANON="${OVS_DEMO_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8}"; TOK=$(cat "$OUT/.tok" 2>/dev/null); CODE=$(curl -s -o "$OUT/pgrst-olmayan-rpc.json" -w '%{http_code}' -X POST "$DEMO_URL/rest/v1/rpc/ovsync_takip_listele" -H "apikey: $ANON" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{}'); RC=$(jq -r '.code // "?"' "$OUT/pgrst-olmayan-rpc.json" 2>/dev/null); echo "S7a olmayan-RPC: HTTP=$CODE code=$RC — beklenti 404+PGRST202 [demo gerçeğiyle pinli]"; if [ "$CODE" = "404" ] && [ "$RC" = "PGRST202" ]; then echo "S7a: PASS — pin tekrar üretildi"; else echo "S7a: KISMİ — kaydı incele (PostgREST sürümü gövdeyi değiştirebilir; kayıt öncelikli)"; fi
-- 7b) kizginlik_vaka_ac + YENİ param (p_takip_onay) — C5 eski-imza pin zemini
\! OUT="${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum"; DEMO_URL="${OVS_DEMO_URL:-https://vtzqjmazsvurxdeondmi.supabase.co}"; ANON="${OVS_DEMO_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8}"; TOK=$(cat "$OUT/.tok" 2>/dev/null); CODE=$(curl -s -o "$OUT/pgrst-yeni-param.json" -w '%{http_code}' -X POST "$DEMO_URL/rest/v1/rpc/kizginlik_vaka_ac" -H "apikey: $ANON" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{"p_kizginlik_id":"probe-yok","p_tani":"probe","p_tohumlama_id":null,"p_notlar":"probe","p_takip_onay":false}'); echo "S7b eski-imza+yeni-param: HTTP=$CODE code=$(jq -r '.code // "?"' "$OUT/pgrst-yeni-param.json" 2>/dev/null) — C5 DROP sonrası bu pin ESKİ-imza çağrısına sabitlenir; bugün eski imza canlı → bu assertion RED(beklenen)"
-- 7c) ANON çağrı — 401 + 42501 (ACL REST eşdeğeri)
\! OUT="${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum"; DEMO_URL="${OVS_DEMO_URL:-https://vtzqjmazsvurxdeondmi.supabase.co}"; ANON="${OVS_DEMO_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8}"; CODE=$(curl -s -o "$OUT/pgrst-anon.json" -w '%{http_code}' -X POST "$DEMO_URL/rest/v1/rpc/kizginlik_vaka_ac" -H "apikey: $ANON" -H 'Content-Type: application/json' -d '{"p_kizginlik_id":"probe-yok","p_tani":"probe","p_tohumlama_id":null,"p_notlar":"probe"}'); echo "S7c anon: HTTP=$CODE code=$(jq -r '.code // "?"' "$OUT/pgrst-anon.json" 2>/dev/null) — beklenti 401+42501"
-- 7d) T-92 C4 DB negatif (tanıdan bağımsız iki varyant) — P3b sonrası TAKIP_ACIK beklenir
\! OUT="${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum"; DEMO_URL="${OVS_DEMO_URL:-https://vtzqjmazsvurxdeondmi.supabase.co}"; ANON="${OVS_DEMO_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8}"; TOK=$(cat "$OUT/.tok" 2>/dev/null); CODE=$(curl -s -o "$OUT/t92-ovsync-tani.json" -w '%{http_code}' -X POST "$DEMO_URL/rest/v1/rpc/kizginlik_vaka_ac" -H "apikey: $ANON" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{"p_kizginlik_id":"E2E-probe-yok","p_tani":"💊 PG Protokolü","p_tohumlama_id":null,"p_notlar":"E2E probe — yazmasız: kizginlik_id yok → mevcut KIZGINLIK_YOK red","p_takip_onay":false}'); echo "S7d-1 T-92 Ovsync-tanı onaysız: HTTP=$CODE msg=$(jq -r '.message // "?"' "$OUT/t92-ovsync-tani.json" 2>/dev/null | cut -c1-70)… — P3b sonrası beklenti TAKIP_ACIK:*; bugün imza/giriş red = RED(beklenen)"
\! OUT="${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum"; DEMO_URL="${OVS_DEMO_URL:-https://vtzqjmazsvurxdeondmi.supabase.co}"; ANON="${OVS_DEMO_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8}"; TOK=$(cat "$OUT/.tok" 2>/dev/null); CODE=$(curl -s -o "$OUT/t92-serbest-tani.json" -w '%{http_code}' -X POST "$DEMO_URL/rest/v1/rpc/kizginlik_vaka_ac" -H "apikey: $ANON" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{"p_kizginlik_id":"E2E-probe-yok","p_tani":"+ Serbest Giriş: E2E-probe","p_tohumlama_id":null,"p_notlar":"E2E probe","p_takip_onay":false}'); echo "S7d-2 T-92 serbest-tanı onaysız: HTTP=$CODE — iki varyant da AYNI kapıdan geçmeli (tanıdan bağımsız); bugün RED(beklenen)"

-- ── S8 ÖZET ─────────────────────────────────────────────────────────────────
\echo ''
\echo '=== ÖZET (zarf kuralı: RED = beklenen-öncesi; PASS SAYILMAZ; UNMEASURED ayrı) ==='
SELECT kodsatir AS senaryo, deger AS sonuc, etiket FROM _ovs_durum
WHERE kodsatir IN ('S1_T80','S2_T08','S2_XOR','S3_KAPANIS','S4_DAL1','S4_DAL2','S4_DAL3','S5_H5')
ORDER BY kodsatir;
\echo 'S6/T-90 ACL + S7 REST pinleri yukarıdaki satır çıktılarındadır (kayıt: ${TMPDIR:-$HOME/tmp}/ovsync-takip-olcum/).'
\echo 'Yorum sözlüğü: PASS = gerçek yeşil; RED(beklenen) = ürün implementasyonu bekliyor; KISMI = koşul kurulamadı; UNMEASURED = fixture kapalı koşum.'

-- ═════════════════════════════════════════════════════════════════════════════
-- S9 (K5A / TB-5 SQL ayağı) — `_pg_kapi_detay` `karar` alanı (migration 20261002000002)
-- Sözleşme: birleşik `PG_KAPI:TAKIP_ACIK:{pg_kapi:{karar,…}, takip_acik:{…}}` yükünde
-- `pg_kapi.karar` = sunucunun PG kapı kararı ∈ {REQUIRE_ACK_PENDING, BLOCK_PREGNANT,
-- BLOCK_CATALOG_UNRESOLVED}; yalnız-ekleme (mevcut 9 anahtar aynen korunur).
-- Her senaryo: ön-koşul assert'i (kapı kararı `_pg_kapi`'dan BAĞIMSIZ okunur) + ters kanıt.
-- Migration uygulanmadan koşulursa K5A satırları FAIL düşer (kırmızı kanıtı); uygulanmışsa PASS.
-- Saf birim (K5A-1..4) fixture gerektirmez; entegrasyon (K5A-5..9) ovs_fixture_ok=true ister.
-- Fixture öneki E2E-TAKIP-K5A (başta+sonda temizlenir; marker'sız veriye dokunmaz).
-- ═════════════════════════════════════════════════════════════════════════════
\echo ''
\echo '=== S9 K5A — _pg_kapi_detay karar alanı ==='
DROP TABLE IF EXISTS _ovs_k5a;
CREATE TEMP TABLE _ovs_k5a(kod text PRIMARY KEY, sonuc text, kanit text);
CREATE OR REPLACE FUNCTION pg_temp._k5a_say(p_kod text, p_ok boolean, p_kanit text) RETURNS void
LANGUAGE sql AS $f$
  INSERT INTO _ovs_k5a VALUES (p_kod, CASE WHEN p_ok THEN 'PASS' ELSE 'FAIL' END, left(p_kanit, 300))
  ON CONFLICT (kod) DO UPDATE SET sonuc = EXCLUDED.sonuc, kanit = EXCLUDED.kanit;
$f$;

-- K5A-0 ön-koşul: imza / SECURITY DEFINER / IMMUTABLE / ACL (anon+authenticated EXECUTE YOK)
DO $do$
DECLARE v_p record;
BEGIN
  SELECT p.prosecdef, p.provolatile, p.proconfig::text AS cfg
    INTO v_p FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = '_pg_kapi_detay'
     AND pg_get_function_identity_arguments(p.oid) = 'p_kapi jsonb, p_hayvan_id text, p_kupe_no text';
  PERFORM pg_temp._k5a_say('K5A-0a imza+definer+immutable+search_path',
    FOUND AND v_p.prosecdef AND v_p.provolatile = 'i' AND v_p.cfg LIKE '%search_path=public, pg_temp%',
    coalesce(v_p::text, 'fonksiyon yok'));
  PERFORM pg_temp._k5a_say('K5A-0b ACL: anon/authenticated EXECUTE yok',
    NOT has_function_privilege('anon', 'public._pg_kapi_detay(jsonb,text,text)', 'EXECUTE')
    AND NOT has_function_privilege('authenticated', 'public._pg_kapi_detay(jsonb,text,text)', 'EXECUTE'),
    'anon='||has_function_privilege('anon', 'public._pg_kapi_detay(jsonb,text,text)', 'EXECUTE')
    ||' auth='||has_function_privilege('authenticated', 'public._pg_kapi_detay(jsonb,text,text)', 'EXECUTE'));
END
$do$;

-- K5A-1 saf birim: her karar değeri yükte AYNEN geri döner (3 bloklayıcı + 3 geçiren)
DO $do$
DECLARE v_k text; v_r jsonb;
BEGIN
  FOREACH v_k IN ARRAY ARRAY['REQUIRE_ACK_PENDING','BLOCK_PREGNANT','BLOCK_CATALOG_UNRESOLVED','ALLOW','ACK_PENDING','KAPALI'] LOOP
    v_r := public._pg_kapi_detay(jsonb_build_object('karar', v_k, 'hayvan_id', 'H1', 'kupe_no', 'K1'), 'H1', 'K1');
    PERFORM pg_temp._k5a_say('K5A-1 saf birim karar='||v_k, v_r->>'karar' IS NOT DISTINCT FROM v_k, v_r::text);
  END LOOP;
END
$do$;

-- K5A-2 ters kanıt: karar'sız / NULL kapı → anahtar VAR, değer JSON null (sessiz düşmez, uydurma yok)
DO $do$
DECLARE v_a jsonb; v_b jsonb;
BEGIN
  v_a := public._pg_kapi_detay(NULL, 'H1', 'K1');
  v_b := public._pg_kapi_detay('{}'::jsonb, 'H1', 'K1');
  PERFORM pg_temp._k5a_say('K5A-2 NULL kapı → karar anahtarı var, değer null',
    v_a ? 'karar' AND jsonb_typeof(v_a->'karar') = 'null' AND v_b ? 'karar' AND jsonb_typeof(v_b->'karar') = 'null',
    v_a::text||' | '||v_b::text);
END
$do$;

-- K5A-3 yalnız-ekleme: eski 9 anahtar değerleriyle aynen korunur; toplam anahtar sayısı 10
DO $do$
DECLARE v_r jsonb; v_beklenen jsonb;
BEGIN
  v_r := public._pg_kapi_detay(
    '{"karar":"BLOCK_PREGNANT","hayvan_id":"HX","kupe_no":"KX","tohumlama_id":"T1","tohumlama_tarihi":"2026-10-01","tohumlama_sonuc":"Gebe","gun":1,"sperma":"S","deneme_no":2,"urun_durumu":"PG"}'::jsonb,
    'IGNORE', 'IGNORE');
  v_beklenen := '{"hayvan_id":"HX","kupe_no":"KX","tohumlama_id":"T1","tohumlama_tarihi":"2026-10-01","tohumlama_sonuc":"Gebe","gun":1,"sperma":"S","deneme_no":2,"urun_durumu":"PG"}'::jsonb;
  PERFORM pg_temp._k5a_say('K5A-3 eski 9 anahtar korunur + toplam 10',
    (v_r - 'karar') = v_beklenen AND (SELECT count(*) FROM jsonb_object_keys(v_r)) = 10, v_r::text);
  -- hayvan_id/kupe_no yedek yolu (kapıda yoksa parametreden) bozulmadı
  v_r := public._pg_kapi_detay('{"karar":"ALLOW"}'::jsonb, 'HP', 'KP');
  PERFORM pg_temp._k5a_say('K5A-4 hayvan_id/kupe_no parametre yedeği korunur',
    v_r->>'hayvan_id' = 'HP' AND v_r->>'kupe_no' = 'KP' AND v_r->>'karar' = 'ALLOW', v_r::text);
END
$do$;

-- K5A-5..9 entegrasyon: gerçek RPC RAISE yükü (hizli_uygulama + bulk_ilac)
\if :ovs_fixture_ok
DO $do$
DECLARE
  v_h text := 'E2E-TAKIP-K5A-H-'||substr(gen_random_uuid()::text,1,8);
  v_pg_stok text; v_bel_stok text := 'E2E-TAKIP-K5A-STOK';
  v_msg text; v_pre text; v_payload jsonb; v_res jsonb; v_g uuid;
BEGIN
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-K5A%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-K5A%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-K5A%';
  DELETE FROM stok WHERE id = v_bel_stok;

  SELECT s.id INTO v_pg_stok FROM stok s WHERE public._pg_urun_durumu(s.id, NULL) = 'PG' ORDER BY s.id LIMIT 1;
  IF v_pg_stok IS NULL OR NOT public._ovsync_pg_aktif() THEN
    PERFORM pg_temp._k5a_say('K5A-5 ön-koşul: PG stok + bayrak AÇIK', false,
      'pg_stok='||coalesce(v_pg_stok,'(yok)')||' bayrak='||public._ovsync_pg_aktif()::text||' — entegrasyon UNMEASURED');
    RETURN;
  END IF;

  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
  VALUES (v_h, 'E2E-TAKIP-K5A', 'Dişi', CURRENT_DATE - 400, 'Sağmal (Laktasyonda)');
  -- sıra: ÖNCE tohumlama (yeni tohumlama açık takibi sessiz kapatır), SONRA takip görevi
  INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler)
  VALUES (gen_random_uuid(), v_h, CURRENT_DATE, 'Bekliyor', 1, '[]'::jsonb);
  v_g := gen_random_uuid();
  INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
  VALUES (v_g, v_h, 'TAKIP_MUAYENE', 'E2E-TAKIP-k5a', CURRENT_DATE + 7, false, false, 'TAKIP:E2E-K5A');

  -- ── K5A-5 REQUIRE_ACK_PENDING (son tohumlama Bekliyor, onaysız, takip açık) ──
  v_pre := public._pg_kapi(v_h, v_pg_stok, NULL, false)->>'karar';       -- kapı kararı detay'dan BAĞIMSIZ
  v_msg := NULL;
  BEGIN PERFORM public.hizli_uygulama(v_h, v_pg_stok, 1, 'ml', 'IM', 'E2E K5A');
  EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
  v_payload := CASE WHEN v_msg LIKE 'PG_KAPI:TAKIP_ACIK:%' THEN substr(v_msg, length('PG_KAPI:TAKIP_ACIK:') + 1)::jsonb END;
  PERFORM pg_temp._k5a_say('K5A-5 REQUIRE_ACK_PENDING birleşik yük',
    v_pre = 'REQUIRE_ACK_PENDING' AND v_payload #>> '{pg_kapi,karar}' = 'REQUIRE_ACK_PENDING'
      AND v_payload #>> '{takip_acik,muayene_tarihi}' IS NOT NULL,
    'ön-koşul _pg_kapi='||coalesce(v_pre,'?')||' | '||coalesce(left(v_msg,200),'RAISE yok'));

  -- ters kanıt: p_pg_onay=true → karar ACK_PENDING (bloklamaz) → yalın TAKIP_ACIK, pg_kapi anahtarı YOK
  v_msg := NULL;
  BEGIN PERFORM public.hizli_uygulama(v_h, v_pg_stok, 1, 'ml', 'IM', 'E2E K5A', true, 'E2E gerekçe', NULL, false);
  EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
  PERFORM pg_temp._k5a_say('K5A-5r ters: onaylı → yalın TAKIP_ACIK (pg_kapi yok)',
    v_msg LIKE 'TAKIP_ACIK:%' AND NOT ((substr(v_msg, length('TAKIP_ACIK:') + 1)::jsonb) ? 'pg_kapi'),
    coalesce(left(v_msg,200),'RAISE yok'));

  -- ── K5A-6 BLOCK_PREGNANT (son tohumlama Gebe) — onay kapıyı AÇMAZ ──
  UPDATE tohumlama SET sonuc = 'Gebe' WHERE hayvan_id = v_h;
  UPDATE gorev_log SET iptal = false, tamamlandi = false WHERE id = v_g;   -- sonuç değişimi takibi kapatmış olabilir; yeniden aç
  v_pre := public._pg_kapi(v_h, v_pg_stok, NULL, true)->>'karar';        -- onaylı bile BLOCK_PREGNANT
  v_msg := NULL;
  BEGIN PERFORM public.hizli_uygulama(v_h, v_pg_stok, 1, 'ml', 'IM', 'E2E K5A', true, 'E2E gerekçe', NULL, false);
  EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
  v_payload := CASE WHEN v_msg LIKE 'PG_KAPI:TAKIP_ACIK:%' THEN substr(v_msg, length('PG_KAPI:TAKIP_ACIK:') + 1)::jsonb END;
  PERFORM pg_temp._k5a_say('K5A-6 BLOCK_PREGNANT birleşik yük (onaylı bile)',
    v_pre = 'BLOCK_PREGNANT' AND v_payload #>> '{pg_kapi,karar}' = 'BLOCK_PREGNANT',
    'ön-koşul _pg_kapi(onaylı)='||coalesce(v_pre,'?')||' | '||coalesce(left(v_msg,200),'RAISE yok'));

  -- ── K5A-7 takip KAPALI: tekil PG_KAPI:<karar>:<detay> — önek ile detay.karar AYNI ──
  UPDATE gorev_log SET iptal = true WHERE id = v_g;
  v_msg := NULL;
  BEGIN PERFORM public.hizli_uygulama(v_h, v_pg_stok, 1, 'ml', 'IM', 'E2E K5A');
  EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
  v_payload := CASE WHEN v_msg LIKE 'PG_KAPI:BLOCK_PREGNANT:%' THEN substr(v_msg, length('PG_KAPI:BLOCK_PREGNANT:') + 1)::jsonb END;
  PERFORM pg_temp._k5a_say('K5A-7 takipsiz tekil RAISE: önek = detay.karar',
    v_payload->>'karar' = 'BLOCK_PREGNANT', coalesce(left(v_msg,200),'RAISE yok'));

  -- ── K5A-8 bulk_ilac satırları: blocked[].karar = kod = takip_onay_listesi[].pg_kapi_karar ──
  UPDATE gorev_log SET iptal = false, tamamlandi = false WHERE id = v_g;
  v_res := public.bulk_ilac(ARRAY[v_h], v_pg_stok, 1);
  PERFORM pg_temp._k5a_say('K5A-8 bulk_ilac blocked[].karar = kod = pg_kapi_karar',
    (v_res #>> '{blocked,0,karar}') = 'BLOCK_PREGNANT' AND (v_res #>> '{blocked,0,kod}') = 'BLOCK_PREGNANT'
      AND (v_res #>> '{takip_onay_listesi,0,pg_kapi_karar}') = 'BLOCK_PREGNANT',
    left(v_res::text, 300));

  -- ── K5A-9 BLOCK_CATALOG_UNRESOLVED (PG adlı, katalog bağsız stok) ──
  INSERT INTO stok(id, urun_adi, birim, baslangic_miktar) VALUES (v_bel_stok, 'E2E-TAKIP Prostag', 'ml', 10);
  UPDATE tohumlama SET sonuc = 'Boş' WHERE hayvan_id = v_h;                 -- kararın tohumlama durumundan bağımsız olduğunu da gösterir
  UPDATE gorev_log SET iptal = false, tamamlandi = false WHERE id = v_g;
  v_pre := public._pg_kapi(v_h, v_bel_stok, NULL, false)->>'karar';
  v_msg := NULL;
  BEGIN PERFORM public.hizli_uygulama(v_h, v_bel_stok, 1, 'ml', 'IM', 'E2E K5A');
  EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
  v_payload := CASE WHEN v_msg LIKE 'PG_KAPI:TAKIP_ACIK:%' THEN substr(v_msg, length('PG_KAPI:TAKIP_ACIK:') + 1)::jsonb END;
  PERFORM pg_temp._k5a_say('K5A-9 BLOCK_CATALOG_UNRESOLVED birleşik yük',
    v_pre = 'BLOCK_CATALOG_UNRESOLVED' AND v_payload #>> '{pg_kapi,karar}' = 'BLOCK_CATALOG_UNRESOLVED',
    'ön-koşul _pg_kapi='||coalesce(v_pre,'?')||' | '||coalesce(left(v_msg,200),'RAISE yok'));

  -- temizlik
  DELETE FROM gorev_log WHERE hayvan_id = v_h;
  DELETE FROM tohumlama WHERE hayvan_id = v_h;
  DELETE FROM hayvanlar WHERE id = v_h;
  DELETE FROM stok WHERE id = v_bel_stok;
EXCEPTION WHEN OTHERS THEN
  PERFORM pg_temp._k5a_say('K5A-ENT beklenmedik hata', false, SQLSTATE||' '||SQLERRM);
  DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-K5A%');
  DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-K5A%');
  DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-TAKIP-K5A%';
  DELETE FROM stok WHERE id = 'E2E-TAKIP-K5A-STOK';
END
$do$;
\else
\echo 'S9 entegrasyon atlandı (fixture kapalı → K5A-5..9 UNMEASURED)'
\endif

\echo '--- S9 ÖZET (K5A) ---'
SELECT kod AS senaryo, sonuc, kanit FROM _ovs_k5a ORDER BY kod;
SELECT 'K5A TOPLAM: PASS='||count(*) FILTER (WHERE sonuc='PASS')||' FAIL='||count(*) FILTER (WHERE sonuc='FAIL') AS ozet FROM _ovs_k5a;
