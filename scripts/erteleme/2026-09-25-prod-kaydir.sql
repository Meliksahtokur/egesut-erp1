-- ============================================================================
-- 2026-09-25-prod-kaydir.sql — E0-Y YEDEK PLANI: vaka zincir kaydırma (tek-seferlik)
-- ============================================================================
-- AMAÇ : E0 RPC (vaka_kalan_gunleri_kaydir) 2026-09-25 akşamı prod'a çıkamazsa,
--        prod'da AKTİF vaka zincirlerinin kalan günlerini +N gün kaydırmak için
--        tek-seferlik, elle koşulan betik. K10 reçetesi birebir (U1-U6):
--        docs/plans/2026-09-25-cila-onarim/k10-sonuc.md
-- KAPSAM (vaka bazlı, aktif vaka):
--   U1  treatment_days.treatment_date            tamamlandi=false  → +N
--   U2  gorev_log.hedef_tarih (açık TEDAVI_GUN+TEDAVI_SEANS)      → +N (hedef_saat DOKUNMA)
--   U3  TEDAVI_GUN aciklama->label biçim-eşleşen tazeleme (tarih etikete gömülü)
--   U4  treatment_day_uygulamalar.planned_date   uygulama_tamamlandi_at IS NULL → +N
--   U5  şablon-türevi açık TAI (TOHUMLAMA_PLANLI, kaynak 'TEDAVI_SABLON_TOHUMLAMA:<case>:%')
--       → destekli RPC tohumlama_gorev_ertele(id, hedef_tarih+N, mevcut hedef_saat)
--   U6  audit islem_log ('VAKA_ZINCIR_KAYDIR'; RPC kendi TOHUMLAMA_ERTELE kaydını yazar)
-- DIŞARIDA BIRAKILANLAR (bilinçli):
--   - tamamlanmış günler + uygulanmış seanslar (geçmiş olgu, K10 aynı)
--   - hedef_saat / planned_time / treatment_time (saatler korunur)
--   - protokol_instance (tarih taşımaz; baslangic başlangıç olgusu — bu zincirlerde
--     instance satırı da yok; K10 da dokunmadı)
--   - OVSYNC_BASLAT görevleri (aktif vakada başlatılmış=kapalı olur; kalan 29 açık
--     görev başka hayvanların henüz başlamamış protokolleri, vaka zinciri değil)
-- ORTAM KİLİDİ (k4/k12 deseni — SQL içinden ref GÖRÜNMEZ, current_user=postgres
--   [OBSERVED demo probe]; mekanik işaret kullanılır):
--   DEMO ref : vtzqjmazsvurxdeondmi  → 20260925 migration ailesi YALNIZ demo'da kayıtlı
--   PROD ref : zqnexqbdfvbhlxzelzju  → seride kayıt YOK (2026-09-25 itibarıyla)
--   Varsayılan mod DEMO: işaret yoksa betik DURUR (demo-modu prod'da koşamaz).
--   PROD modu İKİ ayrı bilinçli düzenleme gerektirir: \set prod_mod true + aşağıdaki
--   $guard$ bloğu içinde v_prod_onay literal'i (dosyada tek yer); ayrıca ortamda
--   20260925 işaret sayısı 0 OLMALI (B-2/F4: sapmada EXCEPTION — mekanik duruş).
--   NOT: cila 20260925 serisi prod'a da uygulanırsa demo işareti zayıflar VE prod
--   dalı işaret zorlamasıyla DURUR — o durumda bu betik yeniden değerlendirilmelidir.
-- POOLER DİKKAT: gövdenin tamamı TEK transaction içinde (supavisor txn-modu: temp
--   tablolar otokomut cümleleri arasında yaşamaz [OBSERVED duman testi]). İşlem-sonrası
--   kontrol temp tablosuz, psql \gset değişkenleriyle yapılır.
--
-- KOŞUM — DEMO PROVA (varsayılan, COMMIT YOK):
--   mkdir -p /home/melik/tmp/erteleme-prod-kaydir
--   echo $SUPABASE_DEMO_REF   # → vtzqjmazsvurxdeondmi doğrula
--   bash -c 'set -a; source /home/melik/egesut-erp1/.env; set +a; \
--     PGPASSWORD="$SUPABASE_DEMO_DB_PASSWORD" psql \
--     "postgresql://postgres.${SUPABASE_DEMO_REF}:${SUPABASE_DEMO_DB_PASSWORD}@${SUPABASE_DEMO_POOLER}:6543/postgres" \
--     -X -v ON_ERROR_STOP=1 -f scripts/erteleme/2026-09-25-prod-kaydir.sql'
--
-- KOŞUM — PROD (SAHİP ELİYLE, yalnız E0 RPC çıkamazsa; agent PROD'DA KOŞMAZ):
--   1) Aşağıda \set prod_mod true yap
--   2) $guard$ bloğunda v_prod_onay := 'zqnexqbdfvbhlxzelzju' yap (dosyada tek yer)
--   3) \set vaka_ids '<prod aktif vaka id listesi>' — yalnız AKTİF vakalar
--   4) p_commit FALSE ile önce PROD PROVA koş (BEGIN…ROLLBACK) — çıktıyı incele
--   5) \set p_commit true → GERÇEK UYGULAMA (COMMIT)
--   6) Bağlantı: sahip kendi prod bağlantısıyla; ref'i bağlantı dizgesinden doğrula
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================ TEK DÜZENLEME NOKTASI ==========================
-- Vaka listesi (virgülle; provenans: 2026-09-25 demo provası — 1 ovsync + 1 normal;
-- F4 turunda güncellendi: 03b10e2a hayvanına ait İKİNCİ aktif vaka 2e89d269 aynı gün
-- açılmıştı — KAPSAM_DISI_ACIK_TEDAVI_GOREV guard'ı listeyi genişletmemizi istedi)
\set vaka_ids '03b10e2a-1800-43b0-864d-c392329727b3, 81a4376c-bd01-46fa-a411-aedd9f2ed2e9, 2e89d269-4b00-4ef9-a0dc-6702830698b4'
-- Kaydırma gün sayısı (>=1; tek yönlü İLERİ)
\set p_gun 2
-- false: PROVA (BEGIN…ROLLBACK) | true: GERÇEK UYGULAMA
\set p_commit false
-- false: DEMO kilidi | true: PROD (v_prod_onay da gerekir)
\set prod_mod false
-- Yedek CSV'leri (önceki değerler; rollback/geri-alma güvenliği; dizin önce açılır).
-- DİKKAT: \copy psql değişkenlerini interpolasyonlamaz (psql 18.6'da gözlemlendi:
-- tırnaksız :var cwd'de literal dosya adı oldu, tırnaklı :'var sunucu hatası verdi)
-- — yedek dizinini değiştirmek istersen ÜÇ \copy satırındaki yolu elle değiştir.
\set yedek_dizin /home/melik/tmp/erteleme-prod-kaydir
-- ============================================================================

\echo ===KAYNAK_PARAMETRELER=== p_gun=:p_gun p_commit=:p_commit prod_mod=:prod_mod
\echo vaka_ids=:'vaka_ids'
\echo yedek_dizin=:yedek_dizin

BEGIN;

-- Parametre/kapsam tabloları (txn içinde; pooler kuralı)
CREATE TEMP TABLE _kaydir_vaka (case_id uuid PRIMARY KEY) ON COMMIT DROP;
INSERT INTO _kaydir_vaka (case_id)
SELECT DISTINCT trim(x)::uuid FROM unnest(string_to_array(:'vaka_ids', ',')) AS t(x)
ON CONFLICT DO NOTHING;

CREATE TEMP TABLE _kaydir_param AS
SELECT :p_gun::int AS p_gun, :prod_mod::bool AS prod_mod, :'p_commit'::bool AS commit_flag;

-- ------------------------------- GUARD --------------------------------------
DO $guard$
DECLARE
  v_pgun int; v_prodmod bool; v_commitflag bool;
  v_n int; v_txt text; v_marker int;
  v_prod_onay text := 'YOK';  -- PROD koşusu için SAHİP bunu 'zqnexqbdfvbhlxzelzju' YAPAR (dosyada tek yer)
BEGIN
  SELECT p_gun, prod_mod, commit_flag INTO v_pgun, v_prodmod, v_commitflag FROM _kaydir_param;

  -- p_gun >= 1 reddi
  IF v_pgun IS NULL OR v_pgun < 1 THEN
    RAISE EXCEPTION 'P_GUN_GECERSIZ: p_gun=% (>=1 gerekli; kaydirma tek yonlu ileri)', v_pgun;
  END IF;

  SELECT count(*) INTO v_n FROM _kaydir_vaka;
  IF v_n = 0 THEN RAISE EXCEPTION 'VAKA_LISTESI_BOS: vaka_ids duzgun doldur'; END IF;

  -- Ortam kilidi (k4/k12 mekanik işareti)
  SELECT count(*) INTO v_marker FROM supabase_migrations.schema_migrations WHERE version LIKE '20260925%';
  IF NOT v_prodmod THEN
    IF v_marker = 0 THEN
      RAISE EXCEPTION 'HEDEF ORTAM DEMO DEGIL: 20260925 serisi bu veritabaninda yok (beklenen demo ref vtzqjmazsvurxdeondmi; prod zqnexqbdfvbhlxzelzju YASAK)';
    END IF;
  ELSE
    IF v_prod_onay IS DISTINCT FROM 'zqnexqbdfvbhlxzelzju' THEN
      RAISE EXCEPTION 'PROD_MOD_KILITLI: prod_mod=true ama guard icindeki v_prod_onay hala YOK — sahip eliyle ac';
    END IF;
    -- [F4/B-2] Ortam dogrulamasi: PROD modunda 20260925 isaret sayisi 0 OLMALI
    -- (betigin varlik nedeni: E0 RPC + serinin prod'da OLMAMASI). Isaret varsa
    -- ortam beklentisi bozulmustur (cila serisi prod'a girmis ya da hedef PROD
    -- degil — ornek. demo'ya karsi prod modu) → yanlis-ortam kosusu mekanik DURUR.
    IF v_marker <> 0 THEN
      RAISE EXCEPTION 'PROD_MOD_ISARET_UYUSMAZ: bu ortamda 20260925 isaret sayisi=% (PROD modunda 0 beklenir) — cila/erteleme serisi bu ortamda kayitli; yanlis-ortam kosusu mekanik durduruldu', v_marker;
    END IF;
    RAISE NOTICE 'PROD MOD acildi (sahip karari); 20260925 isaret sayisi=0 DOGRULANDI';
  END IF;

  -- Vaka varlık kontrolü
  SELECT string_agg(c.id::text, ',' ORDER BY c.id::text) INTO v_txt
    FROM _kaydir_vaka k LEFT JOIN public.cases c ON c.id = k.case_id
   WHERE c.id IS NULL;
  IF v_txt IS NOT NULL THEN RAISE EXCEPTION 'VAKA_BULUNAMADI: %', v_txt; END IF;

  -- KAPALI VAKA reddi (yalnız aktif vakalar kaydırılır)
  SELECT string_agg(c.id::text || '(' || c.status || ')', ',' ORDER BY c.id::text) INTO v_txt
    FROM _kaydir_vaka k JOIN public.cases c ON c.id = k.case_id
   WHERE c.status IS DISTINCT FROM 'active';
  IF v_txt IS NOT NULL THEN RAISE EXCEPTION 'KAPALI_VAKA: %', v_txt; END IF;

  -- Kısmen uygulanmış açık gün reddi (kaydırma temizliği; K10 doğrulamasının mekanikleşmiş hali)
  SELECT count(*) INTO v_n FROM public.treatment_days td
   WHERE td.case_id IN (SELECT case_id FROM _kaydir_vaka) AND td.tamamlandi = false
     AND EXISTS (SELECT 1 FROM public.treatment_day_uygulamalar u
                  WHERE u.treatment_day_id = td.id AND u.uygulama_tamamlandi_at IS NOT NULL);
  IF v_n > 0 THEN RAISE EXCEPTION 'KISMEN_UYGULANMIS_GUN: % acik gunun uygulanmis seansi var — zincir kaydirma bu araci asar, dur', v_n; END IF;

  -- Kapsama bağlı ama tipli dışı açık görev reddi (sessiz atlamayı önler)
  SELECT string_agg(DISTINCT g.gorev_tipi, ',') INTO v_txt
    FROM public.gorev_log g
   WHERE COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
     AND g.gorev_tipi NOT IN ('TEDAVI_GUN','TEDAVI_SEANS','TOHUMLAMA_PLANLI')
     AND ( (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid IN
             (SELECT td.id FROM public.treatment_days td
               WHERE td.case_id IN (SELECT case_id FROM _kaydir_vaka))
        OR g.kaynak LIKE ANY (SELECT 'TEDAVI_SABLON_TOHUMLAMA:' || v.case_id::text || ':%'
                                FROM _kaydir_vaka v) );
  IF v_txt IS NOT NULL THEN RAISE EXCEPTION 'BEKLENMEYEN_BAGLI_ACIK_GOREV: % — bu tipler kaydirilmiyor, kapsami yeniden dusun', v_txt; END IF;

  -- Aynı hayvanın kapsam-dışı açık TEDAVI görevi reddi (zincir yarım kalmasın)
  SELECT count(*) INTO v_n FROM public.gorev_log g
   WHERE g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
     AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
     AND g.hayvan_id IN (SELECT c.animal_id FROM public.cases c
                          WHERE c.id IN (SELECT case_id FROM _kaydir_vaka))
     AND ( (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid IS NULL
        OR (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid NOT IN
             (SELECT td.id FROM public.treatment_days td
               WHERE td.case_id IN (SELECT case_id FROM _kaydir_vaka)) );
  IF v_n > 0 THEN RAISE EXCEPTION 'KAPSAM_DISI_ACIK_TEDAVI_GOREV: ayni hayvanin % acik TEDAVI gorevi vaka-gun bagina oturmuyor — vaka listesini genislet ya da bilincli karar ver', v_n; END IF;

  -- TAI geçmiş-tarih ön kontrolü (RPC GECMIS_TARIH ile bütün txn'i zaten düşürür; erken ve net mesaj)
  SELECT string_agg(g.id::text || ':' || (g.hedef_tarih + v_pgun), ', ') INTO v_txt
    FROM public.gorev_log g
   WHERE g.gorev_tipi = 'TOHUMLAMA_PLANLI'
     AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
     AND g.kaynak LIKE ANY (SELECT 'TEDAVI_SABLON_TOHUMLAMA:' || v.case_id::text || ':%'
                              FROM _kaydir_vaka v)
     AND g.hedef_tarih + v_pgun < (now() AT TIME ZONE 'Europe/Istanbul')::date;
  IF v_txt IS NOT NULL THEN RAISE EXCEPTION 'TAI_GECMIS_TARIH: RPC yeni tarihi gecmise dusurur — %', v_txt; END IF;

  RAISE NOTICE 'GUARD PASS: p_gun=% vaka=% mod=% prova=% (isaret=%)',
    v_pgun, (SELECT count(*) FROM _kaydir_vaka),
    CASE WHEN v_prodmod THEN 'PROD' ELSE 'DEMO' END, (NOT v_commitflag), v_marker;
END
$guard$;

-- --------------------------- ÖNCE DURUM + ANLIK GÖRÜNTÜ ---------------------
\echo ===ORTAM_KIMLIGI===
SELECT current_database() AS db, current_user AS usr, session_user AS sess,
       (SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version LIKE '20260925%') AS isaret_20260925;

\echo ===ONCESI_VAKA_OZETI===
SELECT c.id AS vaka, c.animal_id AS hayvan, d.name AS hastalik,
       count(*) FILTER (WHERE td.tamamlandi = false) AS acik_gun,
       count(*) FILTER (WHERE td.tamamlandi = true)  AS tamamlanan_gun,
       min(td.treatment_date) FILTER (WHERE td.tamamlandi = false) AS ilk_acik_gun,
       max(td.treatment_date) FILTER (WHERE td.tamamlandi = false) AS son_acik_gun
  FROM public.cases c
  JOIN public.diseases d ON d.id = c.disease_id
  LEFT JOIN public.treatment_days td ON td.case_id = c.id
 WHERE c.id IN (SELECT case_id FROM _kaydir_vaka)
 GROUP BY 1, 2, 3 ORDER BY 2;

CREATE TEMP TABLE _once_gunler ON COMMIT DROP AS
SELECT td.id, td.case_id, td.day_no, td.treatment_date, td.tamamlandi
  FROM public.treatment_days td
 WHERE td.case_id IN (SELECT case_id FROM _kaydir_vaka);

CREATE TEMP TABLE _once_gorev ON COMMIT DROP AS
SELECT g.id, g.gorev_tipi, g.hedef_tarih, g.hedef_saat, td.case_id
  FROM public.gorev_log g
  JOIN public.treatment_days td
    ON td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
   AND td.case_id IN (SELECT case_id FROM _kaydir_vaka)
 WHERE g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
UNION ALL
SELECT g.id, g.gorev_tipi, g.hedef_tarih, g.hedef_saat, v.case_id
  FROM public.gorev_log g
  JOIN _kaydir_vaka v ON g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || v.case_id::text || ':%'
 WHERE g.gorev_tipi = 'TOHUMLAMA_PLANLI'
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false;

CREATE TEMP TABLE _once_seans ON COMMIT DROP AS
SELECT u.id, u.case_id, u.planned_date
  FROM public.treatment_day_uygulamalar u
 WHERE u.case_id IN (SELECT case_id FROM _kaydir_vaka)
   AND u.uygulama_tamamlandi_at IS NULL;

-- İşlem-sonrası doğrulama için özet/damgalar (psql değişkenleri txn'den bağımsız yaşar)
SELECT md5(string_agg(o.id::text || '|' || o.treatment_date::text, ',' ORDER BY o.id::text)) AS d_gun_once,
       md5(string_agg(o.id::text || '|' || (o.treatment_date + CASE WHEN o.tamamlandi THEN 0 ELSE p.p_gun END)::text, ',' ORDER BY o.id::text)) AS d_gun_beklenen
  FROM _once_gunler o CROSS JOIN _kaydir_param p \gset
SELECT md5(string_agg(o.id::text || '|' || o.gorev_tipi || '|' || o.hedef_tarih::text, ',' ORDER BY o.id::text)) AS d_gorev_once,
       md5(string_agg(o.id::text || '|' || o.gorev_tipi || '|' || (o.hedef_tarih + p.p_gun)::text, ',' ORDER BY o.id::text)) AS d_gorev_beklenen
  FROM _once_gorev o CROSS JOIN _kaydir_param p \gset
SELECT md5(string_agg(o.id::text || '|' || o.planned_date::text, ',' ORDER BY o.id::text)) AS d_seans_once,
       md5(string_agg(o.id::text || '|' || (o.planned_date + p.p_gun)::text, ',' ORDER BY o.id::text)) AS d_seans_beklenen
  FROM _once_seans o CROSS JOIN _kaydir_param p \gset
SELECT count(*) AS gecikmis_once
  FROM _once_gorev
 WHERE gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND hedef_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date \gset
SELECT count(*) AS gecikmis_ovsync_global_once
  FROM public.gorev_log g
  JOIN public.treatment_days td ON td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
  JOIN public.cases c ON c.id = td.case_id
  JOIN public.diseases d ON d.id = c.disease_id
 WHERE d.name ILIKE '%ovsync%' AND c.status = 'active'
   AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
   AND g.hedef_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date \gset

SELECT count(*) AS n_acik_gun FROM _once_gunler WHERE tamamlandi = false \gset
SELECT count(*) AS n_gorev FROM _once_gorev \gset
SELECT count(*) AS n_seans FROM _once_seans \gset
\echo ===ONCESI_SAYIMLAR=== acik_gun=:n_acik_gun acik_gorev=:n_gorev seans=:n_seans
\echo gecikmis_once=:gecikmis_once global_ovsync_gecikmis=:gecikmis_ovsync_global_once

-- --------------------------------- YEDEKLER ---------------------------------
\echo ===YEDEKLER=== (onceki degerler; dosya adlari yukarida)
SELECT (SELECT count(*) FROM public.treatment_days WHERE case_id IN (SELECT case_id FROM _kaydir_vaka)) AS gunler_satir,
       (SELECT count(*) FROM _once_gorev) AS gorev_satir,
       (SELECT count(*) FROM _once_seans) AS seans_satir;
\copy (SELECT * FROM public.treatment_days WHERE case_id IN (SELECT case_id FROM _kaydir_vaka) ORDER BY id) TO '/home/melik/tmp/erteleme-prod-kaydir/yedek_treatment_days.csv' WITH (FORMAT csv)
\copy (SELECT g.* FROM public.gorev_log g WHERE g.id IN (SELECT id FROM _once_gorev) ORDER BY g.id) TO '/home/melik/tmp/erteleme-prod-kaydir/yedek_gorev_log.csv' WITH (FORMAT csv)
\copy (SELECT u.* FROM public.treatment_day_uygulamalar u WHERE u.id IN (SELECT id FROM _once_seans) ORDER BY u.id) TO '/home/melik/tmp/erteleme-prod-kaydir/yedek_treatment_day_uygulamalar.csv' WITH (FORMAT csv)
\echo yedek yazildi: /home/melik/tmp/erteleme-prod-kaydir/yedek_treatment_days.csv + yedek_gorev_log.csv + yedek_treatment_day_uygulamalar.csv

-- ------------------------------ GÜNCELLEMELER -------------------------------
\echo ===U1_gunler_arti_N===
UPDATE public.treatment_days td
   SET treatment_date = treatment_date + p.p_gun
  FROM _kaydir_vaka k, _kaydir_param p
 WHERE k.case_id = td.case_id AND td.tamamlandi = false;

\echo ===U2_gorev_hedef_tarih_arti_N=== (hedef_saat DOKUNULMAZ)
UPDATE public.gorev_log g
   SET hedef_tarih = hedef_tarih + p.p_gun
  FROM public.treatment_days td, _kaydir_vaka k, _kaydir_param p
 WHERE td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
   AND k.case_id = td.case_id
   AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false;

\echo ===U3_TEDAVI_GUN_label_tazele=== (yalniz bicim-eslesenler)
UPDATE public.gorev_log g
   SET aciklama = (jsonb_set(g.aciklama::jsonb, '{label}',
         to_jsonb('Gun ' || (g.aciklama::jsonb->>'gun_no') || ' tedavisi - ' || to_char(td.treatment_date,'DD.MM.YYYY'))))::text
  FROM public.treatment_days td, _kaydir_vaka k
 WHERE td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
   AND k.case_id = td.case_id
   AND g.gorev_tipi = 'TEDAVI_GUN'
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
   AND (g.aciklama::jsonb->>'label') ~ '^Gun [0-9]+ tedavisi - [0-9]{2}\.[0-9]{2}\.[0-9]{4}$';

\echo ===U4_seans_planned_date_arti_N===
UPDATE public.treatment_day_uygulamalar u
   SET planned_date = planned_date + p.p_gun, updated_at = now()
  FROM _kaydir_vaka k, _kaydir_param p
 WHERE k.case_id = u.case_id
   AND u.uygulama_tamamlandi_at IS NULL;

\echo ===U5_TAI_RPC=== (tarih hedef+N, saat mevcut hedef_saat)
SELECT public.tohumlama_gorev_ertele(g.id, (g.hedef_tarih + p.p_gun), g.hedef_saat) AS tai_sonuc
  FROM public.gorev_log g, _kaydir_param p
 WHERE g.gorev_tipi = 'TOHUMLAMA_PLANLI'
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
   AND g.kaynak LIKE ANY (SELECT 'TEDAVI_SABLON_TOHUMLAMA:' || v.case_id::text || ':%'
                            FROM _kaydir_vaka v)
 ORDER BY g.id::text;

\echo ===U6_audit_islem_log===
INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
SELECT 'VAKA_ZINCIR_KAYDIR', c.animal_id, c.id::text, 'cases',
       jsonb_build_object(
         'p_gun', p.p_gun,
         'mod', CASE WHEN p.prod_mod THEN 'PROD' ELSE 'DEMO' END,
         'prova', NOT p.commit_flag,
         'script', 'scripts/erteleme/2026-09-25-prod-kaydir.sql',
         'recete', 'K10 U1-U6 (docs/plans/2026-09-25-cila-onarim/k10-sonuc.md)',
         'n_acik_gun', (SELECT count(*) FROM _once_gunler o WHERE o.tamamlandi = false),
         'n_acik_gorev', (SELECT count(*) FROM _once_gorev WHERE gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')),
         'n_seans', (SELECT count(*) FROM _once_seans),
         'n_tai', (SELECT count(*) FROM _once_gorev WHERE gorev_tipi = 'TOHUMLAMA_PLANLI')),
       '{}'::jsonb
  FROM public.cases c CROSS JOIN _kaydir_param p
 WHERE c.id IN (SELECT case_id FROM _kaydir_vaka);

-- ------------------------------- KABUL / SON --------------------------------
\echo ===SONRASI_GUN_OZETI_once_vs_sonra===
SELECT c.animal_id AS hayvan, o.case_id, o.day_no, o.tamamlandi,
       o.treatment_date AS once, td.treatment_date AS sonra,
       td.treatment_date - o.treatment_date AS delta
  FROM _once_gunler o
  JOIN public.treatment_days td ON td.id = o.id
  JOIN public.cases c ON c.id = o.case_id
 ORDER BY c.animal_id, o.day_no;

\echo ===SONRASI_ARALIKLAR=== (acik gunler arasi fark + TAI farki — DEGISMEMELI)
WITH once AS (
  SELECT case_id, day_no,
         treatment_date - lag(treatment_date) OVER (PARTITION BY case_id ORDER BY day_no) AS fark
    FROM _once_gunler WHERE tamamlandi = false),
sonra AS (
  SELECT o.case_id, o.day_no,
         td.treatment_date - lag(td.treatment_date) OVER (PARTITION BY o.case_id ORDER BY o.day_no) AS fark
    FROM _once_gunler o JOIN public.treatment_days td ON td.id = o.id
   WHERE o.tamamlandi = false)
SELECT c.animal_id AS hayvan, o.day_no, o.fark AS fark_once, s.fark AS fark_sonra
  FROM once o JOIN sonra s USING (case_id, day_no) JOIN public.cases c ON c.id = o.case_id
 ORDER BY c.animal_id, o.day_no;

\echo ===SONRASI_TAI_farklari===
SELECT c.animal_id AS hayvan,
       (SELECT max(o.treatment_date) FROM _once_gunler o
         WHERE o.case_id = c.id AND o.tamamlandi = false) AS son_acik_gun_once,
       (SELECT t.hedef_tarih FROM _once_gorev t
         WHERE t.case_id = c.id AND t.gorev_tipi = 'TOHUMLAMA_PLANLI' LIMIT 1) AS tai_once,
       (SELECT max(o.treatment_date + p.p_gun) FROM _once_gunler o, _kaydir_param p
         WHERE o.case_id = c.id AND o.tamamlandi = false) AS son_acik_gun_sonra,
       (SELECT t.hedef_tarih + p.p_gun FROM _once_gorev t, _kaydir_param p
         WHERE t.case_id = c.id AND t.gorev_tipi = 'TOHUMLAMA_PLANLI' LIMIT 1) AS tai_sonra
  FROM public.cases c
 WHERE c.id IN (SELECT case_id FROM _kaydir_vaka) ORDER BY 2;

\echo ===TAMAMLANMIS_GUN_DOKUNULMAMA_KANITI=== (beklenen 0)
SELECT count(*) AS degisen_tamamlanmis_gun
  FROM _once_gunler o JOIN public.treatment_days td ON td.id = o.id
 WHERE o.tamamlandi = true
   AND (td.treatment_date IS DISTINCT FROM o.treatment_date OR td.tamamlandi IS DISTINCT FROM o.tamamlandi);

\echo ===SON_DOGRULAMALARI=== (kural ihlali = EXCEPTION)
DO $son$
DECLARE
  v_n int; v_a text; v_b text; v_pgun int;
BEGIN
  SELECT p_gun INTO v_pgun FROM _kaydir_param;

  SELECT count(*) INTO v_n FROM _once_gunler o JOIN public.treatment_days td ON td.id = o.id
   WHERE o.tamamlandi = false AND td.treatment_date IS DISTINCT FROM o.treatment_date + v_pgun;
  IF v_n <> 0 THEN RAISE EXCEPTION 'SON1: acik gun +% eslesmeyen satir %', v_pgun, v_n; END IF;

  SELECT count(*) INTO v_n FROM _once_gunler o JOIN public.treatment_days td ON td.id = o.id
   WHERE o.tamamlandi = true
     AND (td.treatment_date IS DISTINCT FROM o.treatment_date OR td.tamamlandi IS DISTINCT FROM o.tamamlandi);
  IF v_n <> 0 THEN RAISE EXCEPTION 'SON2: tamamlanmis gun degismis %', v_n; END IF;

  SELECT count(*) INTO v_n FROM _once_gorev o JOIN public.gorev_log g ON g.id = o.id
   WHERE g.hedef_tarih IS DISTINCT FROM o.hedef_tarih + v_pgun;
  IF v_n <> 0 THEN RAISE EXCEPTION 'SON3: gorev hedef_tarih +% eslesmeyen %', v_pgun, v_n; END IF;

  SELECT count(*) INTO v_n FROM _once_gorev o JOIN public.gorev_log g ON g.id = o.id
   WHERE o.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
     AND (g.hedef_saat IS DISTINCT FROM o.hedef_saat
          OR COALESCE(g.tamamlandi,false) OR COALESCE(g.iptal,false));
  IF v_n <> 0 THEN RAISE EXCEPTION 'SON4: tedavi gorevinde saat/tamamlandi/iptal degismis %', v_n; END IF;

  SELECT count(*) INTO v_n FROM _once_seans o JOIN public.treatment_day_uygulamalar u ON u.id = o.id
   WHERE u.planned_date IS DISTINCT FROM o.planned_date + v_pgun;
  IF v_n <> 0 THEN RAISE EXCEPTION 'SON5: seans planned_date +% eslesmeyen %', v_pgun, v_n; END IF;

  SELECT string_agg(day_no || ':' || fark, ',' ORDER BY day_no) INTO v_a
    FROM (SELECT case_id, day_no, treatment_date - lag(treatment_date) OVER (PARTITION BY case_id ORDER BY day_no) AS fark
            FROM _once_gunler WHERE tamamlandi = false) x
   WHERE fark IS NOT NULL;
  SELECT string_agg(day_no || ':' || fark, ',' ORDER BY day_no) INTO v_b
    FROM (SELECT o.case_id, o.day_no, td.treatment_date - lag(td.treatment_date) OVER (PARTITION BY o.case_id ORDER BY o.day_no) AS fark
            FROM _once_gunler o JOIN public.treatment_days td ON td.id = o.id
           WHERE o.tamamlandi = false) x
   WHERE fark IS NOT NULL;
  IF v_a IS DISTINCT FROM v_b THEN RAISE EXCEPTION 'SON6: acik gun araliklari degisti once=[%] sonra=[%]', v_a, v_b; END IF;

  SELECT string_agg(hayvan || '=' || fark, ',' ORDER BY hayvan) INTO v_a
    FROM (SELECT c.animal_id AS hayvan,
                 (SELECT t.hedef_tarih FROM _once_gorev t
                   WHERE t.case_id = c.id AND t.gorev_tipi = 'TOHUMLAMA_PLANLI' LIMIT 1)
               - (SELECT max(o.treatment_date) FROM _once_gunler o
                   WHERE o.case_id = c.id AND o.tamamlandi = false) AS fark
            FROM public.cases c
           WHERE c.id IN (SELECT case_id FROM _kaydir_vaka)) z
   WHERE fark IS NOT NULL;
  SELECT string_agg(hayvan || '=' || fark, ',' ORDER BY hayvan) INTO v_b
    FROM (SELECT c.animal_id AS hayvan,
                 (SELECT g.hedef_tarih FROM _once_gorev t JOIN public.gorev_log g ON g.id = t.id
                   WHERE t.case_id = c.id AND t.gorev_tipi = 'TOHUMLAMA_PLANLI' LIMIT 1)
               - (SELECT max(o.treatment_date) + v_pgun FROM _once_gunler o
                   WHERE o.case_id = c.id AND o.tamamlandi = false) AS fark
            FROM public.cases c
           WHERE c.id IN (SELECT case_id FROM _kaydir_vaka)) z
   WHERE fark IS NOT NULL;
  IF v_a IS DISTINCT FROM v_b THEN RAISE EXCEPTION 'SON6b: TAI-son-acik-gun araligi degisti once=[%] sonra=[%]', v_a, v_b; END IF;

  SELECT count(*) INTO v_n
    FROM public.gorev_log g
    JOIN public.treatment_days td
      ON td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
    JOIN _kaydir_vaka k ON k.case_id = td.case_id
   WHERE g.gorev_tipi = 'TEDAVI_GUN'
     AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
     AND (g.aciklama::jsonb->>'label') ~ '^Gun [0-9]+ tedavisi - [0-9]{2}\.[0-9]{2}\.[0-9]{4}$'
     AND (g.aciklama::jsonb->>'label') IS DISTINCT FROM
         'Gun ' || (g.aciklama::jsonb->>'gun_no') || ' tedavisi - ' || to_char(td.treatment_date,'DD.MM.YYYY');
  IF v_n <> 0 THEN RAISE EXCEPTION 'SON7: bicim-eslesen label tarihi taze degil %', v_n; END IF;

  RAISE NOTICE 'SON DOGRULAMALARI PASS (SON1-SON7)';
END
$son$;

\echo ===GECIKMIS_ACIK_GOREV_SAYIMI=== (kapsamda; once vs sonra)
SELECT :gecikmis_once AS once,
       (SELECT count(*) FROM _once_gorev o JOIN public.gorev_log g ON g.id = o.id
         WHERE o.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
           AND g.hedef_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date) AS sonra;

-- ------------------------------ COMMIT / ROLLBACK ---------------------------
\if :p_commit
COMMIT;
\echo ===GERCEK_UYGULAMA — COMMIT=== (yedekler: /home/melik/tmp/erteleme-prod-kaydir/yedek_*.csv)
\else
ROLLBACK;
\echo ===PROVA — ROLLBACK===
\endif

-- ------------------- İŞLEM SONRASI KONTROL (temp'siz) -----------------------
-- Not: prova özeti/ölçümleri psql değişkenlerinde txn'den bağımsız yaşar.
\echo ===ISLEM_SONRASI_KONTROL=== (damga karsilastirmasi; PROVA=once, APPLY=beklenen)
SELECT md5(string_agg(td.id::text || '|' || td.treatment_date::text, ',' ORDER BY td.id::text)) AS d_gun_gercek
  FROM public.treatment_days td
 WHERE td.case_id IN (SELECT trim(x)::uuid FROM unnest(string_to_array(:'vaka_ids', ',')) AS t(x)) \gset
SELECT md5(string_agg(x.id::text || '|' || x.gorev_tipi || '|' || x.hedef_tarih::text, ',' ORDER BY x.id::text)) AS d_gorev_gercek
  FROM (SELECT g.id, g.gorev_tipi, g.hedef_tarih
          FROM public.gorev_log g
          JOIN public.treatment_days td
            ON td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
           AND td.case_id IN (SELECT trim(x)::uuid FROM unnest(string_to_array(:'vaka_ids', ',')) AS t(x))
         WHERE g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
           AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
        UNION ALL
        SELECT g.id, g.gorev_tipi, g.hedef_tarih
          FROM public.gorev_log g
         WHERE g.gorev_tipi = 'TOHUMLAMA_PLANLI'
           AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
           AND g.kaynak LIKE ANY (SELECT 'TEDAVI_SABLON_TOHUMLAMA:' || trim(x) || ':%'
                                    FROM unnest(string_to_array(:'vaka_ids', ',')) AS t(x))) x \gset
SELECT md5(string_agg(u.id::text || '|' || u.planned_date::text, ',' ORDER BY u.id::text)) AS d_seans_gercek
  FROM public.treatment_day_uygulamalar u
 WHERE u.case_id IN (SELECT trim(x)::uuid FROM unnest(string_to_array(:'vaka_ids', ',')) AS t(x))
   AND u.uygulama_tamamlandi_at IS NULL \gset

\echo gunler   gercek=:d_gun_gercek   once=:d_gun_once   beklenen=:d_gun_beklenen
\echo gorev    gercek=:d_gorev_gercek once=:d_gorev_once beklenen=:d_gorev_beklenen
\echo seans    gercek=:d_seans_gercek once=:d_seans_once beklenen=:d_seans_beklenen

SELECT CASE WHEN :'d_gun_gercek'    = CASE WHEN :'p_commit' = 'true' THEN :'d_gun_beklenen'    ELSE :'d_gun_once'    END THEN 'PASS gunler'    ELSE 'FAIL gunler'    END AS kontrol_1;
SELECT CASE WHEN :'d_gun_gercek'    = CASE WHEN :'p_commit' = 'true' THEN :'d_gun_beklenen'    ELSE :'d_gun_once'    END THEN 1 ELSE 1/0 END;
SELECT CASE WHEN :'d_gorev_gercek'  = CASE WHEN :'p_commit' = 'true' THEN :'d_gorev_beklenen'  ELSE :'d_gorev_once'  END THEN 'PASS gorev'     ELSE 'FAIL gorev'     END AS kontrol_2;
SELECT CASE WHEN :'d_gorev_gercek'  = CASE WHEN :'p_commit' = 'true' THEN :'d_gorev_beklenen'  ELSE :'d_gorev_once'  END THEN 1 ELSE 1/0 END;
SELECT CASE WHEN :'d_seans_gercek'  = CASE WHEN :'p_commit' = 'true' THEN :'d_seans_beklenen'  ELSE :'d_seans_once'  END THEN 'PASS seans'     ELSE 'FAIL seans'     END AS kontrol_3;
SELECT CASE WHEN :'d_seans_gercek'  = CASE WHEN :'p_commit' = 'true' THEN :'d_seans_beklenen'  ELSE :'d_seans_once'  END THEN 1 ELSE 1/0 END;

\echo ===GECIKMIS_SON_DURUM=== kapsam_gecikmis=
SELECT count(*) AS kapsam_gecikmis_son
  FROM public.gorev_log g
  JOIN public.treatment_days td
    ON td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
   AND td.case_id IN (SELECT trim(x)::uuid FROM unnest(string_to_array(:'vaka_ids', ',')) AS t(x))
 WHERE g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
   AND g.hedef_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date;

SELECT count(*) AS global_ovsync_gecikmis_son
  FROM public.gorev_log g
  JOIN public.treatment_days td ON td.id = (CASE WHEN g.aciklama LIKE '{%' THEN g.aciklama::jsonb->>'day_id' END)::uuid
  JOIN public.cases c ON c.id = td.case_id
  JOIN public.diseases d ON d.id = c.disease_id
 WHERE d.name ILIKE '%ovsync%' AND c.status = 'active'
   AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
   AND g.hedef_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date;

\echo ===BITTI=== p_commit=:p_commit — PROVA ise veri DEGISMEMIS olmali (yukaridaki PASS satirlari)
