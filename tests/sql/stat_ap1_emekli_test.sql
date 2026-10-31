-- tests/sql/stat_ap1_emekli_test.sql
-- İstatistik Atölyesi AP1 Task 7 — F0-F2 emeklilik + tanım kartları (spec v2 §4.7, §4.9; plan Task 7, P2, P3).
--
-- HEDEF: YALNIZ demo (ref vtzqjmazsvurxdeondmi). Test vaka verisi okumaz/yazmaz; fixture (stat_saglik_fixture.sql)
-- GEREKMEZ (T6 ruling kalıbı). Tek yazma `idempotent` kodundaki migration'ın ikinci uygulamasıdır
-- (\ir ../../supabase/migrations/20261017000005_stat_ap1_emekli.sql; dosya yoksa FAIL).
-- KOŞUM:
--   psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_ap1_emekli_test.sql
--   (stat_fixture_ok verilmemiş/false → hiçbir şey koşmaz, tüm kodlar UNMEASURED kalır.)
-- SONUÇ: _stat_durum(kod, PASS|FAIL|UNMEASURED, etiket); kod başına bir satır. Her test bir DO bloğu; blok içi hata
--   → FAIL + hata metni (migration yokken kırmızı FAIL verir, UNMEASURED'da kalmaz).
-- Beklenen tanım kartları plan Task 7 tablosundan birebir (_st7_bek).

\if :{?stat_fixture_ok}
\else
\set stat_fixture_ok false
\endif
\echo '=== stat_ap1_emekli testi ===' stat_fixture_ok= :stat_fixture_ok

DROP TABLE IF EXISTS _stat_durum;
CREATE TEMP TABLE _stat_durum(kod text PRIMARY KEY, deger text, etiket text);
DROP TABLE IF EXISTS _st7_emekli;
CREATE TEMP TABLE _st7_emekli(ad text PRIMARY KEY, imza text NOT NULL);
INSERT INTO _st7_emekli VALUES
  ('stat_tedavi_ozet',             'public.stat_tedavi_ozet(date,date,jsonb)'),
  ('stat_tedavi_protokol',         'public.stat_tedavi_protokol(date,date,jsonb)'),
  ('stat_tedavi_sure_dagilim',     'public.stat_tedavi_sure_dagilim(date,date,jsonb)'),
  ('stat_tedavi_dislanan_dipnot',  'public.stat_tedavi_dislanan_dipnot(date,date,jsonb)'),
  ('stat_ayikla_tedavi_vaka_ozet', 'public.stat_ayikla_tedavi_vaka_ozet()'),
  ('stat_ayikla_tedavi_vaka',      'public.stat_ayikla_tedavi_vaka(uuid[])'),
  ('stat_protokol_etiket',         'public.stat_protokol_etiket(text[],integer,text)'),
  ('stat_filtre_dogrula',          'public.stat_filtre_dogrula(jsonb,text[])');
INSERT INTO _stat_durum(kod, deger, etiket)
  SELECT 'emekli_' || ad || '_yok', 'UNMEASURED', imza || ' to_regprocedure NULL ve adla pg_proc 0' FROM _st7_emekli;
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('kalan_v_stat_vaka_var',        'UNMEASURED', 'view var + SELECT count(*) çalışır (dondurulmuş)'),
  ('kalan_stat_sonuc_oku_var',     'UNMEASURED', 'stat_sonuc_oku(text,jsonb) var + pasif motor satırıyla çağrılır'),
  ('kalan_stat_zarf_bos_var',      'UNMEASURED', 'stat_zarf_bos(text,text,integer,text[]) var + çağrılır'),
  ('kalan_stat_donem_dogrula_var', 'UNMEASURED', 'stat_donem_dogrula(date,date) var + çağrılır'),
  ('kalan_stat_analiz_sonuc_var',  'UNMEASURED', 'tablo var'),
  ('kalan_stat_motor_kosum_var',   'UNMEASURED', 'tablo var'),
  ('kalan_stat_motor_var',         'UNMEASURED', 'rol stat_motor var (LOGIN migration dışı, yalnız etikette)'),
  ('kolonlar',                     'UNMEASURED', 'stat_olcum_kayit: birim, tanim, kume text'),
  ('kayit_5_yeni',                 'UNMEASURED', '5 satır birebir: alan saglik, tip sql, surum sql:20261017000005, aktif, sira 10..50, baslik/birim/kume/tanim'),
  ('kayit_sql_eski_yok',           'UNMEASURED', '3 SQL satırı (stat_tedavi_ozet/_protokol/_sure_dagilim) yok; tip=sql yalnız 5 yeni'),
  ('kayit_motor_pasif',            'UNMEASURED', '2 motor satırı var, aktif=false'),
  ('listele_alanlar',              'UNMEASURED', 'stat_olcum_listele: 5 aktif satır sırayla, birim/tanim/kume/surum dolu, motor yok'),
  ('listele_acl',                  'UNMEASURED', 'stat_olcum_listele INVOKER + search_path + STABLE; anon 0, PUBLIC 0, authenticated 1'),
  ('tanim_uc_sart',                'UNMEASURED', 'saglik_basari tanımı: "30 gün", "ölmedi ya da kesilmedi", "yeniden açılmadı" (Stitch #1)'),
  ('protokol_kelimesi_yok',        'UNMEASURED', '5 tanım (baslik/kume/tanim) "protokol" içermez'),
  ('tanim_tedavi_degisti',         'UNMEASURED', 'TS1: başarı tanımı ve kapanma kümesi/tanımı tedavi değişti kuralını yazar; "protokol" yok'),
  ('tanim_ilacsiz',                'UNMEASURED', 'TK1 R1: iki ₺ kartında kume "ilaç uygulanmış" + tanim "İlaç uygulanmamış vaka hesaba girmez."; diğer 3 kartta yok'),
  ('idempotent',                   'UNMEASURED', 'migration ikinci kez: hata yok, kayıt/listele/fonksiyon kümesi aynı, upsert koştu'),
  ('artik',                        'UNMEASURED', 'E2E-ST2- artık = 0');

DROP TABLE IF EXISTS _st7_bek;
CREATE TEMP TABLE _st7_bek(ad text PRIMARY KEY, baslik text, birim text, sira int, kume text, tanim text);
INSERT INTO _st7_bek VALUES
  ('saglik_basari', 'Başarı oranı', '%', 10,
   'Sonuçlanmış vakalar; kapanıştan 30 gün dolmamış ve olay görülmemiş vakalar hariç.',
   'Başarı: vaka kapandı, kapanıştan sonra 30 gün içinde hayvan ölmedi ya da kesilmedi ve aynı hastalık 30 gün içinde yeniden açılmadı. Kapanıştan sonra 24 saat içinde aynı hastalık için yeni vaka açılırsa tedavi değişti sayılır ve vaka başarısızdır. Vaka açıkken ölen ya da kesilen hayvanın vakası başarısız sayılır. Oranın yanında %95 Wilson aralığı verilir; 5''ten az vakada sonuç gösterilmez.'),
  ('saglik_kapanma_gunu', 'Kapanma hızı', 'gün', 20,
   'Kapanmış vakalar (başarısız ve 30 günü dolmamış dahil); 24 saat içinde yeniden açılan (tedavi değişti) vakalar hariç.',
   'Vaka açılışından kapanışına kadar geçen gün; medyan ve çeyrekler (Q1–Q3) verilir. Toplu kapatılmış vakada kapanış günü son ilaç günü + normal vakalarda ölçülen gecikme ile tahmin edilir. Açık vakalar hesaba girmez. Kapanıştan sonra 24 saat içinde aynı hastalık için yeni vaka açıldıysa vaka bu ölçüye girmez.'),
  ('saglik_tedavi_suresi', 'Tedavi süresi', 'gün', 30,
   'İlaç uygulanmış, sonuçlanmış vakalar.',
   'İlk ve son ilaç uygulaması arasındaki gün sayısı (iki uç dahil); vaka süresinden farklıdır. Medyan ve çeyrekler verilir.'),
  ('saglik_vaka_tl', 'Vaka başı ₺', '₺', 40,
   'İlaç uygulanmış, sonuçlanmış ve ilaç fiyatı bilinen vakalar.',
   'Vakada uygulanan ilaç miktarı × birim fiyat toplamı; medyan ve çeyrekler verilir. Fiyatı bilinmeyen tek bir uygulama varsa vaka hesaba girmez. İlaç uygulanmamış vaka hesaba girmez. Elle girilen fiyat geçicidir, kaydedilmez.'),
  ('saglik_basari_tl', 'Başarı başına ₺', '₺', 50,
   'Başarı oranına giren, ilaç uygulanmış ve ilaç fiyatı bilinen vakalar.',
   'Bu vakaların toplam ilaç maliyeti bölü ilaç fiyatı bilinen başarılı vaka sayısı. İlaç uygulanmamış vaka hesaba girmez. Fiyatı bilinen başarılı vaka 5''ten azsa gösterilmez.');

\if :stat_fixture_ok
CREATE FUNCTION pg_temp._st7_yaz(p_kod text, p_ok boolean, p_etiket text) RETURNS void LANGUAGE sql AS $f$
  UPDATE _stat_durum SET deger = CASE WHEN p_ok THEN 'PASS' ELSE 'FAIL' END, etiket = p_etiket WHERE kod = p_kod;
$f$;
CREATE FUNCTION pg_temp._st7_artik() RETURNS int LANGUAGE sql AS $f$
  SELECT ((SELECT count(*) FROM gorev_log WHERE hayvan_id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM cases WHERE animal_id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM hayvanlar WHERE id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM stok WHERE id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM drug_products WHERE id::text LIKE 'e2e57203-%')
        + (SELECT count(*) FROM drug_classes WHERE id::text LIKE 'e2e57202-%')
        + (SELECT count(*) FROM tedavi_sablonu WHERE ad LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM sablon_hastalik_eslem WHERE sablon_id::text LIKE 'e2e57204-%')
        + (SELECT count(*) FROM diseases WHERE name LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM stat_olcum_kayit WHERE ad LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM stat_kayitli_grafik WHERE baslik LIKE 'E2E-ST2-%'))::int;
$f$;
-- idempotent karşılaştırması için durum özeti (kayıt satırları + listele + stat_% fonksiyon imzaları)
CREATE FUNCTION pg_temp._st7_ozet() RETURNS TABLE(kayit_n int, kayit_md5 text, listele_md5 text, fn_md5 text, xminler text)
LANGUAGE sql AS $f$
  SELECT (SELECT count(*)::int FROM stat_olcum_kayit),
         (SELECT md5(string_agg(row(k.id, k.ad, k.alan, k.baslik, k.tip, k.surum, k.aktif, k.sira,
                                    to_jsonb(k)->>'birim', to_jsonb(k)->>'tanim', to_jsonb(k)->>'kume')::text, '|' ORDER BY k.id))
            FROM stat_olcum_kayit k),
         (SELECT md5(public.stat_olcum_listele()::text)),
         (SELECT md5(string_agg(p.oid::regprocedure::text, '|' ORDER BY p.oid::regprocedure::text))
            FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname LIKE 'stat\_%'),
         (SELECT string_agg(k.ad || '=' || k.xmin::text, ',' ORDER BY k.ad) FROM stat_olcum_kayit k
           WHERE k.ad IN (SELECT ad FROM _st7_bek));
$f$;

-- ── emekli_<ad>_yok ─────────────────────────────────────────────────────────
DO $t$
DECLARE e record; v_reg regprocedure; v_n int;
BEGIN
  FOR e IN SELECT * FROM _st7_emekli LOOP
    BEGIN
      v_reg := to_regprocedure(e.imza);
      SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = e.ad;
      PERFORM pg_temp._st7_yaz('emekli_' || e.ad || '_yok', v_reg IS NULL AND v_n = 0,
                               format('to_regprocedure=%s adla pg_proc=%s', coalesce(v_reg::text, 'NULL'), v_n));
    EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('emekli_' || e.ad || '_yok', false, 'hata: ' || SQLERRM);
    END;
  END LOOP;
END $t$;

-- ── kalan_<ad>_var ──────────────────────────────────────────────────────────
DO $t$
DECLARE v_n bigint;
BEGIN
  EXECUTE 'SELECT count(*) FROM public.v_stat_vaka' INTO v_n;
  PERFORM pg_temp._st7_yaz('kalan_v_stat_vaka_var', to_regclass('public.v_stat_vaka') IS NOT NULL,
                           'view var, satır=' || v_n);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kalan_v_stat_vaka_var', false, 'hata: ' || SQLERRM);
END $t$;
DO $t$
DECLARE v jsonb;
BEGIN
  v := public.stat_sonuc_oku('stat_tedavi_sagkalim', '{}'::jsonb);
  PERFORM pg_temp._st7_yaz('kalan_stat_sonuc_oku_var',
    to_regprocedure('public.stat_sonuc_oku(text,jsonb)') IS NOT NULL AND jsonb_typeof(v) = 'object',
    'çağrı jsonb tipi=' || coalesce(jsonb_typeof(v), 'NULL'));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kalan_stat_sonuc_oku_var', false, 'hata: ' || SQLERRM);
END $t$;
DO $t$
DECLARE v jsonb;
BEGIN
  v := public.stat_zarf_bos('x', 'sql:-', 0, ARRAY[]::text[]);
  PERFORM pg_temp._st7_yaz('kalan_stat_zarf_bos_var',
    to_regprocedure('public.stat_zarf_bos(text,text,integer,text[])') IS NOT NULL AND jsonb_typeof(v) = 'object',
    'çağrı jsonb tipi=' || coalesce(jsonb_typeof(v), 'NULL'));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kalan_stat_zarf_bos_var', false, 'hata: ' || SQLERRM);
END $t$;
DO $t$
BEGIN
  PERFORM public.stat_donem_dogrula('2026-01-01'::date, '2026-02-01'::date);
  PERFORM pg_temp._st7_yaz('kalan_stat_donem_dogrula_var',
    to_regprocedure('public.stat_donem_dogrula(date,date)') IS NOT NULL, 'var, geçerli dönemle çağrı hatasız');
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kalan_stat_donem_dogrula_var', false, 'hata: ' || SQLERRM);
END $t$;
DO $t$
DECLARE r record;
BEGIN
  PERFORM pg_temp._st7_yaz('kalan_stat_analiz_sonuc_var', to_regclass('public.stat_analiz_sonuc') IS NOT NULL,
                           'to_regclass=' || coalesce(to_regclass('public.stat_analiz_sonuc')::text, 'NULL'));
  PERFORM pg_temp._st7_yaz('kalan_stat_motor_kosum_var', to_regclass('public.stat_motor_kosum') IS NOT NULL,
                           'to_regclass=' || coalesce(to_regclass('public.stat_motor_kosum')::text, 'NULL'));
  SELECT count(*) AS n, bool_or(rolcanlogin) AS login INTO r FROM pg_roles WHERE rolname = 'stat_motor';
  -- LOGIN migration dışıdır (20261006000001 başlığı, F2-S3: ortam başına elle); yalnız varlık ölçülür
  PERFORM pg_temp._st7_yaz('kalan_stat_motor_var', r.n = 1, format('rol=%s login=%s', r.n, coalesce(r.login::text, '-')));
EXCEPTION WHEN OTHERS THEN
  UPDATE _stat_durum SET deger = 'FAIL', etiket = 'hata: ' || SQLERRM
   WHERE kod IN ('kalan_stat_analiz_sonuc_var', 'kalan_stat_motor_kosum_var', 'kalan_stat_motor_var') AND deger = 'UNMEASURED';
END $t$;

-- ── kolonlar ────────────────────────────────────────────────────────────────
DO $t$
DECLARE v text;
BEGIN
  SELECT string_agg(column_name || ':' || data_type, ',' ORDER BY column_name) INTO v
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'stat_olcum_kayit' AND column_name IN ('birim', 'tanim', 'kume');
  PERFORM pg_temp._st7_yaz('kolonlar', v = 'birim:text,kume:text,tanim:text', coalesce(v, 'kolon yok'));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kolonlar', false, 'hata: ' || SQLERRM);
END $t$;

-- ── kayit_5_yeni ────────────────────────────────────────────────────────────
DO $t$
DECLARE v_esit int; v_fark text;
BEGIN
  SELECT count(*) FILTER (WHERE k.ad IS NOT NULL AND k.alan = 'saglik' AND k.tip = 'sql' AND k.surum = 'sql:20261017000005'
                            AND k.aktif IS TRUE AND k.sira = b.sira AND k.baslik = b.baslik
                            AND to_jsonb(k)->>'birim' = b.birim AND to_jsonb(k)->>'kume' = b.kume
                            AND to_jsonb(k)->>'tanim' = b.tanim
                            AND k.farm_id = public.current_farm_id()),
         string_agg(b.ad, ',' ORDER BY b.sira) FILTER (WHERE k.ad IS NULL OR NOT (k.alan = 'saglik' AND k.tip = 'sql'
                            AND k.surum = 'sql:20261017000005' AND k.aktif IS TRUE AND k.sira = b.sira AND k.baslik = b.baslik
                            AND to_jsonb(k)->>'birim' = b.birim AND to_jsonb(k)->>'kume' = b.kume
                            AND to_jsonb(k)->>'tanim' = b.tanim AND k.farm_id = public.current_farm_id())
                            OR to_jsonb(k)->>'tanim' IS NULL)
    INTO v_esit, v_fark
    FROM _st7_bek b LEFT JOIN public.stat_olcum_kayit k ON k.ad = b.ad;
  PERFORM pg_temp._st7_yaz('kayit_5_yeni', v_esit = 5, format('birebir=%s/5 uymayan=%s', v_esit, coalesce(v_fark, '-')));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kayit_5_yeni', false, 'hata: ' || SQLERRM);
END $t$;

-- ── kayit_sql_eski_yok ──────────────────────────────────────────────────────
DO $t$
DECLARE v_eski int; v_sql text;
BEGIN
  SELECT count(*) INTO v_eski FROM public.stat_olcum_kayit
   WHERE ad IN ('stat_tedavi_ozet', 'stat_tedavi_protokol', 'stat_tedavi_sure_dagilim');
  SELECT string_agg(ad, ',' ORDER BY ad) INTO v_sql FROM public.stat_olcum_kayit WHERE tip = 'sql';
  PERFORM pg_temp._st7_yaz('kayit_sql_eski_yok',
    v_eski = 0 AND v_sql = (SELECT string_agg(ad, ',' ORDER BY ad) FROM _st7_bek),
    format('eski=%s tip_sql=%s', v_eski, coalesce(v_sql, '-')));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kayit_sql_eski_yok', false, 'hata: ' || SQLERRM);
END $t$;

-- ── kayit_motor_pasif ───────────────────────────────────────────────────────
DO $t$
DECLARE v text;
BEGIN
  SELECT string_agg(ad || ':' || tip || ':' || coalesce(aktif::text, 'NULL'), ',' ORDER BY ad) INTO v
    FROM public.stat_olcum_kayit WHERE ad IN ('stat_tedavi_sagkalim', 'stat_tedavi_protokol_fark');
  PERFORM pg_temp._st7_yaz('kayit_motor_pasif',
    v = 'stat_tedavi_protokol_fark:motor:false,stat_tedavi_sagkalim:motor:false', coalesce(v, 'satır yok'));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('kayit_motor_pasif', false, 'hata: ' || SQLERRM);
END $t$;

-- ── listele_alanlar ─────────────────────────────────────────────────────────
DO $t$
DECLARE v jsonb; v_sira text; v_bek text; v_dolu int; v_esit int; v_anahtar text;
BEGIN
  v := public.stat_olcum_listele();
  SELECT string_agg(e->>'ad', ',' ORDER BY o) INTO v_sira FROM jsonb_array_elements(v) WITH ORDINALITY AS t(e, o);
  SELECT string_agg(ad, ',' ORDER BY sira) INTO v_bek FROM _st7_bek;
  SELECT count(*) FILTER (WHERE coalesce(e->>'birim', '') <> '' AND coalesce(e->>'tanim', '') <> ''
                            AND coalesce(e->>'kume', '') <> '' AND coalesce(e->>'surum', '') <> ''),
         count(*) FILTER (WHERE e->>'birim' = b.birim AND e->>'tanim' = b.tanim AND e->>'kume' = b.kume
                            AND e->>'surum' = 'sql:20261017000005' AND e->>'baslik' = b.baslik
                            AND e->>'alan' = 'saglik' AND e->>'tip' = 'sql')
    INTO v_dolu, v_esit
    FROM jsonb_array_elements(v) AS t(e) LEFT JOIN _st7_bek b ON b.ad = t.e->>'ad';
  SELECT string_agg(k, ',' ORDER BY k) INTO v_anahtar FROM jsonb_object_keys(v->0) AS k;
  PERFORM pg_temp._st7_yaz('listele_alanlar',
    jsonb_array_length(v) = 5 AND v_sira = v_bek AND v_dolu = 5 AND v_esit = 5
      AND v_anahtar = 'aciklama,ad,alan,baslik,birim,kume,surum,tanim,tip',
    format('n=%s sira=%s dolu=%s/5 birebir=%s/5 anahtarlar=%s', jsonb_array_length(v), coalesce(v_sira, '-'),
           v_dolu, v_esit, coalesce(v_anahtar, '-')));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('listele_alanlar', false, 'hata: ' || SQLERRM);
END $t$;

-- ── listele_acl ─────────────────────────────────────────────────────────────
DO $t$
DECLARE r record;
BEGIN
  SELECT NOT p.prosecdef AS invoker, 'search_path=public, pg_temp' = ANY (p.proconfig) AS sp, p.provolatile = 's' AS stable,
         has_function_privilege('anon', p.oid, 'EXECUTE') AS anon,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') AS au,
         EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE a.grantee = 0) AS pub
    INTO r FROM pg_proc p WHERE p.oid = 'public.stat_olcum_listele()'::regprocedure;
  PERFORM pg_temp._st7_yaz('listele_acl', r.invoker AND r.sp AND r.stable AND NOT r.anon AND r.au AND NOT r.pub,
    format('invoker=%s search_path=%s stable=%s anon=%s authenticated=%s public=%s', r.invoker, r.sp, r.stable, r.anon, r.au, r.pub));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('listele_acl', false, 'hata: ' || SQLERRM);
END $t$;

-- ── tanim_uc_sart ───────────────────────────────────────────────────────────
DO $t$
DECLARE v text;
BEGIN
  SELECT to_jsonb(k)->>'tanim' INTO v FROM public.stat_olcum_kayit k WHERE k.ad = 'saglik_basari';
  PERFORM pg_temp._st7_yaz('tanim_uc_sart',
    strpos(v, '30 gün') > 0 AND strpos(v, 'ölmedi ya da kesilmedi') > 0 AND strpos(v, 'yeniden açılmadı') > 0,
    format('30 gün=%s ölmedi ya da kesilmedi=%s yeniden açılmadı=%s', strpos(v, '30 gün') > 0,
           strpos(v, 'ölmedi ya da kesilmedi') > 0, strpos(v, 'yeniden açılmadı') > 0));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('tanim_uc_sart', false, 'hata: ' || SQLERRM);
END $t$;

-- ── protokol_kelimesi_yok ───────────────────────────────────────────────────
DO $t$
DECLARE v_n int; v_prot int;
BEGIN
  SELECT count(*) FILTER (WHERE to_jsonb(k)->>'tanim' IS NOT NULL),
         count(*) FILTER (WHERE lower(concat_ws(' ', k.baslik, to_jsonb(k)->>'kume', to_jsonb(k)->>'tanim')) LIKE '%protokol%')
    INTO v_n, v_prot
    FROM public.stat_olcum_kayit k WHERE k.ad IN (SELECT ad FROM _st7_bek);
  PERFORM pg_temp._st7_yaz('protokol_kelimesi_yok', v_n = 5 AND v_prot = 0, format('tanımlı=%s/5 protokol geçen=%s', v_n, v_prot));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('protokol_kelimesi_yok', false, 'hata: ' || SQLERRM);
END $t$;

-- ── tanim_ilacsiz (TK1 R1) ──────────────────────────────────────────────────
DO $t$
DECLARE v_tl int; v_diger int;
BEGIN
  SELECT count(*) FILTER (WHERE k.ad IN ('saglik_vaka_tl', 'saglik_basari_tl')
                            AND strpos(to_jsonb(k)->>'kume', 'laç uygulanmış') > 0   -- İlaç / ilaç
                            AND strpos(to_jsonb(k)->>'tanim', 'İlaç uygulanmamış vaka hesaba girmez.') > 0),
         count(*) FILTER (WHERE k.ad NOT IN ('saglik_vaka_tl', 'saglik_basari_tl')
                            AND strpos(coalesce(to_jsonb(k)->>'tanim', ''), 'İlaç uygulanmamış') > 0)
    INTO v_tl, v_diger
    FROM public.stat_olcum_kayit k WHERE k.ad IN (SELECT ad FROM _st7_bek);
  PERFORM pg_temp._st7_yaz('tanim_ilacsiz', v_tl = 2 AND v_diger = 0, format('₺ kartı uygun=%s/2 diğer kartta cümle=%s', v_tl, v_diger));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('tanim_ilacsiz', false, 'hata: ' || SQLERRM);
END $t$;

-- ── tanim_tedavi_degisti (TS1) ──────────────────────────────────────────────
DO $t$
DECLARE v_b text; v_k text; v_t text;
BEGIN
  SELECT to_jsonb(k)->>'tanim' INTO v_b FROM public.stat_olcum_kayit k WHERE k.ad = 'saglik_basari';
  SELECT to_jsonb(k)->>'kume', to_jsonb(k)->>'tanim' INTO v_k, v_t FROM public.stat_olcum_kayit k WHERE k.ad = 'saglik_kapanma_gunu';
  PERFORM pg_temp._st7_yaz('tanim_tedavi_degisti',
    strpos(v_b, 'tedavi değişti sayılır ve vaka başarısızdır') > 0 AND strpos(v_k, 'tedavi değişti') > 0 AND strpos(v_k, 'tüm') = 0
      AND strpos(v_t, 'yeni vaka açıldıysa vaka bu ölçüye girmez') > 0 AND strpos(lower(v_b || v_k || v_t), 'protokol') = 0,
    format('kume=%s', v_k));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('tanim_tedavi_degisti', false, 'hata: ' || SQLERRM);
END $t$;

-- ── idempotent (migration ikinci kez; psql seviyesinde, transaction kendi BEGIN/COMMIT'inde) ──
DROP TABLE IF EXISTS _st7_once;
CREATE TEMP TABLE _st7_once AS SELECT * FROM pg_temp._st7_ozet();
\set LAST_ERROR_SQLSTATE 00000
\set LAST_ERROR_MESSAGE ''
\ir ../../supabase/migrations/20261017000005_stat_ap1_emekli.sql
DROP TABLE IF EXISTS _st7_mig;
CREATE TEMP TABLE _st7_mig AS SELECT :'LAST_ERROR_SQLSTATE'::text AS st, :'LAST_ERROR_MESSAGE'::text AS msg;
DO $t$
DECLARE o record; s record; v_state text; v_msg text;
BEGIN
  SELECT st, msg INTO v_state, v_msg FROM _st7_mig;
  SELECT * INTO o FROM _st7_once;
  SELECT * INTO s FROM pg_temp._st7_ozet();
  PERFORM pg_temp._st7_yaz('idempotent',
    v_state = '00000' AND s.kayit_n = o.kayit_n AND s.kayit_md5 = o.kayit_md5 AND s.listele_md5 = o.listele_md5
      AND s.fn_md5 = o.fn_md5 AND s.xminler IS DISTINCT FROM o.xminler AND o.xminler IS NOT NULL,
    format('sqlstate=%s %s · kayıt %s→%s aynı=%s listele aynı=%s fn aynı=%s upsert koştu=%s',
           v_state, left(v_msg, 80), o.kayit_n, s.kayit_n, s.kayit_md5 = o.kayit_md5, s.listele_md5 = o.listele_md5,
           s.fn_md5 = o.fn_md5, s.xminler IS DISTINCT FROM o.xminler AND o.xminler IS NOT NULL));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st7_yaz('idempotent', false, 'hata: ' || SQLERRM);
END $t$;

-- ── artık ───────────────────────────────────────────────────────────────────
UPDATE _stat_durum SET deger = CASE WHEN pg_temp._st7_artik() = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'artık=' || pg_temp._st7_artik()
WHERE kod = 'artik';
\endif

\echo '=== ÖZET ==='
SELECT kod, deger, etiket FROM _stat_durum ORDER BY kod;
SELECT 'TOPLAM: PASS=' || count(*) FILTER (WHERE deger = 'PASS') || ' FAIL=' || count(*) FILTER (WHERE deger = 'FAIL')
       || ' UNMEASURED=' || count(*) FILTER (WHERE deger = 'UNMEASURED') AS ozet FROM _stat_durum;
