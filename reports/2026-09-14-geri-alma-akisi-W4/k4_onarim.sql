-- L4-W4 k4_onarim — G-20260914-GERI-ALMA-AKISI "Onarım turu sözleşmesi" kabul koşumu.
-- W1 raporu §3'teki 22 vakanın TAMAMI, luna L4-01/02/03/04/06 onarımı sonrası
-- YENİ sözleşme beklentileriyle yeniden üretilir + A1..A6 adversarial vakalar.
-- (W1'in özgün k4_l4_motoru.sql kaynağı hiçbir worktree'de kalmadı; vakalar
--  W1 raporu §3 tablosundan + k3_geri_alma.sql deseninden yeniden kuruldu.)
--
-- Yeni sözleşme gereği beklentisi DEĞİŞEN vakalar (dürüst yeniden ölçüm):
--   V4a/V4b: doğumun tohumlama'ya FK'sı YOK → doğum artık zincire girmez,
--            bağımsız kayıt olarak HAYATTA kalır (eski beklenti: BAGIMLI_ADIM).
--   V6a/V6c: payload.orijinal_tip artık GERÇEK islem_log tipi (köprüden) ya da
--            hedef tablo+işlem etiketi (fallback); 'I,U' harf kümesi yok.
--   V5a/V5b: rehber adımları artık bayrak TAŞIMAZ; gevşetme yetkisi sunucunun
--            surum_gizli.l4_rehber_adimlari kaydından gelir (L4-01) ve yalnız
--            satır seviyesinde geçerlidir (L4-04).
--
-- NOT rollback-wrapped: revert testleri GERÇEK ayrı txid ister; sentetik
-- satırlar 'k4-' işaretli, degisim_log kayıtları app.istemci_etiketi=
-- 'k4-onarim-testi' ile damgalı; TEMİZLİK bölümü operatör düzeyinde (trigger
-- disable) tüm izleri siler (k1b/k3 S11 deseni).
--
-- Koşum: DEMO (vtzqjmazsvurxdeondmi) — PROD'a hiçbir bağlantı yok.
\set ON_ERROR_STOP 1

SELECT set_config('app.istemci_etiketi', 'k4-onarim-testi', false) AS etiket_kurulumu;
CREATE TEMP TABLE k4 (vaka text, beklenen text, bulunan text, sonuc text, detay text);
CREATE TEMP TABLE k4_idler (id text);

-- ── idempotency önluğu: önceki yarıda kalmış k4 izleri silinir ─────────────
DELETE FROM public.grup_padok_eslem WHERE grup LIKE 'k4-G-%';
DELETE FROM public.vaccination_log WHERE notes LIKE 'k4-%';
DELETE FROM public.dogum WHERE yavru_kupe LIKE 'k4-%';
DELETE FROM public.tohumlama WHERE sperma LIKE 'k4-%';
DELETE FROM public.padoklar WHERE ad LIKE 'k4-%';
DELETE FROM public.hayvanlar WHERE id LIKE 'k4-%';
DO $do$
BEGIN
  ALTER TABLE public.islem_log DISABLE TRIGGER USER;
  DELETE FROM public.islem_log WHERE payload ->> 'k4onarim' IS NOT NULL;
  ALTER TABLE public.islem_log ENABLE TRIGGER USER;
EXCEPTION WHEN others THEN
  ALTER TABLE public.islem_log ENABLE TRIGGER USER;
  RAISE;
END;
$do$;
DO $do$
BEGIN
  ALTER TABLE public.degisim_log DISABLE TRIGGER USER;
  DELETE FROM public.degisim_log WHERE kaynak ->> 'istemci_etiketi' = 'k4-onarim-testi';
  ALTER TABLE public.degisim_log ENABLE TRIGGER USER;
EXCEPTION WHEN others THEN
  ALTER TABLE public.degisim_log ENABLE TRIGGER USER;
  RAISE;
END;
$do$;
-- yetim jeton adımları (girişi silinmiş, 1 saatten eski) süpürülür
DELETE FROM surum_gizli.l4_rehber_adimlari a
 WHERE NOT EXISTS (SELECT 1 FROM public.degisim_log d
                    WHERE d.tablo_adi = a.tablo AND d.satir_pk IS NOT DISTINCT FROM a.satir_pk
                      AND d.txid = a.txid)
   AND a.olusturma < now() - interval '1 hour';

-- ── işaretli tohumlama/dogum/hayvan/vaccination iş trigger'ları: SADELEŞTİR
--    (trg_degisim_log AÇIK kalır — motor gerçek log üretsin; iş islem_log
--    satırları yalnız kontrollü V2/V6 sahnelerinde elle yazılır) ──────────────
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_hayvan_cikis_gorev_iptal;
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_hayvan_grup_padok_sync;
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_hayvanlar_guard;
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_islem_hayvanlar;
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_padok_transfer_gorev;
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_pedigree_hayvan_insert;
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_sutten_kesme_kapat;
ALTER TABLE public.hayvanlar     DISABLE TRIGGER trg_sutten_kesme_normalize;
ALTER TABLE public.tohumlama     DISABLE TRIGGER tohumlama_cycle_iptal_trigger;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_deneme_no;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_islem_tohumlama_abort;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_islem_tohumlama_insert;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_tohumlama_gebe_gorev;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_tohumlama_gebe_sessiz_iptal;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_tohumlama_guard;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_tohumlama_kizginlik;
ALTER TABLE public.tohumlama     DISABLE TRIGGER trg_tohumlama_sessiz_iptal;
ALTER TABLE public.dogum         DISABLE TRIGGER trg_dogum_guard;
ALTER TABLE public.dogum         DISABLE TRIGGER trg_islem_dogum;
ALTER TABLE public.vaccination_log DISABLE TRIGGER trg_dinle_vaccination;
ALTER TABLE public.vaccination_log DISABLE TRIGGER trg_vaccination_stok;

-- ── S0 öncesi gizli durum anlığı (k3 S11/S14 deseni) ───────────────────────
CREATE TEMP TABLE k4_sifre_once AS SELECT * FROM surum_gizli.sahip_sifresi;
CREATE TEMP TABLE k4_bilet_once AS SELECT * FROM surum_gizli.geri_alma_bileti;
SELECT count(*) AS sifrevardi FROM k4_sifre_once \gset

-- ══ S0: şifre + bilet (W1 k4 'S0 şifre kur') ═══════════════════════════════
WITH c AS (SELECT public.sahip_sifresi_ayarla('k4-sifre-2026!x') AS j)
INSERT INTO k4 SELECT 'S0 şifre kur', 'ok=true',
  coalesce(j ->> 'hata', 'ok=' || coalesce(j ->> 'ok', '?')),
  CASE WHEN (j ->> 'ok')::bool THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;
WITH c AS (SELECT public.geri_alma_bileti_al('k4-sifre-2026!x') AS j)
SELECT j ->> 'bilet' AS bilet FROM c \gset

-- ══ temel sahnenler: hayvanlar ═════════════════════════════════════════════
INSERT INTO public.hayvanlar (id, kupe_no, durum) VALUES
  ('k4-H1', 'k4-1', 'Aktif'),
  ('k4-H2', 'k4-2', 'Aktif'),
  ('k4-H6', 'k4-6', 'Aktif');
INSERT INTO k4_idler SELECT unnest(ARRAY['k4-H1','k4-H2','k4-H6']);

-- ══ V2 + V6 köprü sahnesi: tohumlama T1 + AYNI tx'te kontrollü islem_log ═══
BEGIN;
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-v2-sperma', 'k4-test')
RETURNING id AS tid, txid_current()::text AS ttx \gset
INSERT INTO public.islem_log (tip, ref_id, ref_tablo, ana_hayvan_id, payload, snapshot)
VALUES ('TOHUMLAMA', :'tid', 'tohumlama', 'k4-H1', '{"k4onarim":"v2"}', '{}'::jsonb)
RETURNING degisim_txid AS dtx \gset
COMMIT;
INSERT INTO k4_idler VALUES (:'tid');
SELECT txid::text AS logtx FROM public.degisim_log
 WHERE tablo_adi='tohumlama' AND satir_pk ->> 'id' = :'tid' ORDER BY id LIMIT 1 \gset
INSERT INTO k4 SELECT 'V2 köprü: iş satırı + islem_log aynı tx → degisim_txid == degisim_log.txid',
  'eşit', format('islem_log=%s degisim_log=%s', :'dtx', :'logtx'),
  CASE WHEN :'dtx' = :'logtx' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ V1 zaman hedefi sahnesi: padok P5 ══════════════════════════════════════
INSERT INTO public.padoklar (ad) VALUES ('k4-P5') RETURNING id AS p5, txid_current()::text AS p5t \gset
UPDATE public.padoklar SET ad = 'k4-P5-b' WHERE id = :'p5' RETURNING txid_current()::text AS p5u \gset
INSERT INTO k4_idler VALUES (:'p5');
SELECT kayit_zamani::text AS z1 FROM public.degisim_log
 WHERE tablo_adi='padoklar' AND satir_pk ->> 'id' = :'p5' AND txid::text = :'p5t' \gset

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','padoklar','pk',:'p5','zaman',:'z1'), 'satir') AS j)
INSERT INTO k4 SELECT 'V1a zaman: kayit_zamani verilir → aynı tx eşleşir',
  'ok=true hedef.txid=INSERT tx', format('ok=%s hedef=%s', j ->> 'ok', j -> 'hedef' ->> 'txid'),
  CASE WHEN (j ->> 'ok')::bool AND j -> 'hedef' ->> 'txid' = :'p5t' THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','padoklar','pk',:'p5','zaman','2020-01-01 00:00:00+00'), 'satir') AS j)
INSERT INTO k4 SELECT 'V1b zaman: 120 sn aşan → HEDEF_BULUNAMADI + ZAMAN_ESLESME_YOK (en_yakin dolu)',
  'HEDEF_BULUNAMADI/ZAMAN_ESLESME_YOK',
  format('%s/%s enyakin=%s', j ->> 'hata', j -> 'detay' ->> 'neden', (j -> 'detay' ->> 'en_yakin') IS NOT NULL),
  CASE WHEN j ->> 'hata' = 'HEDEF_BULUNAMADI' AND j -> 'detay' ->> 'neden' = 'ZAMAN_ESLESME_YOK'
            AND j -> 'detay' -> 'en_yakin' IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','padoklar','pk',:'p5','txid',:'p5u','zaman','2020-01-01 00:00:00+00'), 'satir') AS j)
INSERT INTO k4 SELECT 'V1c txid + zaman birlikte → txid kazanır',
  'ok=true hedef.txid=UPDATE tx', format('ok=%s hedef=%s', j ->> 'ok', j -> 'hedef' ->> 'txid'),
  CASE WHEN (j ->> 'ok')::bool AND j -> 'hedef' ->> 'txid' = :'p5u' THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','hayvanlar','pk','k4-yok-hayvan'), 'satir') AS j)
INSERT INTO k4 SELECT 'V1d olmayan (geçerli-tip) pk → neden=SATIR_YOK',
  'HEDEF_BULUNAMADI/SATIR_YOK', format('%s/%s', j ->> 'hata', j -> 'detay' ->> 'neden'),
  CASE WHEN j ->> 'hata' = 'HEDEF_BULUNAMADI' AND j -> 'detay' ->> 'neden' = 'SATIR_YOK'
       THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

DO $do$
BEGIN
  ALTER TABLE public.padoklar DISABLE TRIGGER trg_degisim_log;
  INSERT INTO public.padoklar (ad) VALUES ('k4-P5-logsuz');
  ALTER TABLE public.padoklar ENABLE TRIGGER trg_degisim_log;
EXCEPTION WHEN others THEN
  ALTER TABLE public.padoklar ENABLE TRIGGER trg_degisim_log;
  RAISE;
END;
$do$;
SELECT id AS p5b FROM public.padoklar WHERE ad = 'k4-P5-logsuz' \gset
INSERT INTO k4_idler VALUES (:'p5b');
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','padoklar','pk',:'p5b'), 'satir') AS j)
INSERT INTO k4 SELECT 'V1e var olan ama logsuz satır → neden=LOG_YOK',
  'HEDEF_BULUNAMADI/LOG_YOK', format('%s/%s', j ->> 'hata', j -> 'detay' ->> 'neden'),
  CASE WHEN j ->> 'hata' = 'HEDEF_BULUNAMADI' AND j -> 'detay' ->> 'neden' = 'LOG_YOK'
       THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('txid','999999999999'), 'zincir') AS j)
INSERT INTO k4 SELECT 'V1f zincir boş txid → neden=LOG_YOK',
  'HEDEF_BULUNAMADI/LOG_YOK', format('%s/%s', j ->> 'hata', j -> 'detay' ->> 'neden'),
  CASE WHEN j ->> 'hata' = 'HEDEF_BULUNAMADI' AND j -> 'detay' ->> 'neden' = 'LOG_YOK'
       THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

-- ══ V4a/V4b/V6a/V6b: çapraz-satır zincir (K1 YENİ) + telafi gerçek tip ═════
BEGIN;
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H2', 'k4-v4-sperma', 'k4-test')
RETURNING id AS t8, txid_current()::text AS t8a \gset
INSERT INTO public.islem_log (tip, ref_id, ref_tablo, ana_hayvan_id, payload, snapshot)
VALUES ('TOHUMLAMA', :'t8', 'tohumlama', 'k4-H2', '{"k4onarim":"v4"}', '{}'::jsonb) \gset
COMMIT;
UPDATE public.tohumlama SET sperma = 'k4-v4-sperma2' WHERE id = :'t8'
RETURNING txid_current()::text AS t8b \gset
BEGIN;
INSERT INTO public.dogum (anne_id, yavru_kupe, yavru_cins, baba_bilgi)
VALUES ('k4-H2', 'k4-buzagu-8', 'Dişi', 'k4-test')
RETURNING id AS d8, txid_current()::text AS t8c \gset
COMMIT;
INSERT INTO k4_idler VALUES (:'t8'), (:'d8');

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','tohumlama','pk',:'t8','txid',:'t8a'), 'zincir') AS j)
SELECT j ->> 'ok' AS ok, jsonb_array_length(j -> 'plan') AS pn,
       (SELECT count(*) FROM jsonb_array_elements(j -> 'plan') p WHERE p ->> 'tablo' = 'dogum') AS dplan,
       (SELECT count(*) FROM jsonb_array_elements(j -> 'bagimliliklar') b WHERE b ->> 'tablo' = 'dogum') AS dbag,
       (j -> 'plan')::text AS plantxt FROM c \gset
INSERT INTO k4 SELECT 'V4a zincir çapraz-satır (K1 YENİ): dogum FK''sı YOK → plana GİRMEZ',
  'ok=true plan=2 (yalnız tohumlama); dogum ne planda ne bağımlılıkta',
  format('ok=%s plan=%s dogum_plan=%s dogum_bag=%s', :'ok', :'pn', :'dplan', :'dbag'),
  CASE WHEN :'ok' = 'true' AND :'pn' = '2' AND :'dplan' = '0' AND :'dbag' = '0'
       THEN 'PASS' ELSE 'FAIL' END, left(:'plantxt', 200);

SELECT to_jsonb(il) AS ilonce FROM public.islem_log il WHERE il.ref_id = :'t8' AND il.tip = 'TOHUMLAMA' \gset
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','tohumlama','pk',:'t8','txid',:'t8a'),
                                          'zincir', :'bilet'::uuid, 'k4 V4b') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata','-') AS hat, coalesce(j ->> 'uygulanan_adim','0') AS adim,
       coalesce(j ->> 'zincir_adim','0') AS zadim, coalesce(j ->> 'geri_alma_txid','-') AS rtx,
       j::text AS jtxt FROM c \gset
SELECT count(*) AS t8k FROM public.tohumlama WHERE id = :'t8' \gset
SELECT count(*) AS d8k FROM public.dogum WHERE id = :'d8' \gset
SELECT count(*) AS h2k FROM public.hayvanlar WHERE id = 'k4-H2' \gset
INSERT INTO k4 SELECT 'V4b çapraz zincir uygula (K1 YENİ): 2 adım tek tx; tohumlama=0 dogum=1 hayvan=1',
  'ok=true adim=2 tek-rtx; doğum BAĞIMSIZ kayıt olarak kalır',
  format('ok=%s hat=%s adim=%s tohumlama=%s dogum=%s hayvan=%s',
         :'ok', :'hat', :'adim', :'t8k', :'d8k', :'h2k'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '2' AND :'t8k' = '0' AND :'d8k' = '1' AND :'h2k' = '1'
       THEN 'PASS' ELSE 'FAIL' END, :'jtxt';

-- V6a: telafi kaydı — orijinal_tip GERÇEK tip (köprüden), 'I,U' DEĞİL
SELECT payload ->> 'orijinal_tip' AS otip, payload ->> 'seviye' AS sev,
       payload ->> 'adim' AS adim, ana_hayvan_id AS ahv, ref_id AS rid, ref_tablo AS rtab,
       degisim_txid::text AS dtx, tip AS ttip
  FROM public.islem_log WHERE tip = 'GERI_ALINDI' AND ref_id = :'t8' \gset
INSERT INTO k4 SELECT 'V6a telafi: GERI_ALINDI + orijinal_tip=TOHUMLAMA (GERÇEK tip, harf kümesi YOK)',
  'orijinal_tip=TOHUMLAMA seviye=zincir adim=2 ana_hayvan=k4-H2; telafi degisim_txid=geri_alma_txid',
  format('otip=%s seviye=%s adim=%s ahv=%s rtx_esit=%s',
         :'otip', :'sev', :'adim', :'ahv', (:'dtx' = :'rtx')),
  CASE WHEN :'otip' = 'TOHUMLAMA' AND :'otip' NOT IN ('I','U','D','I,U')
        AND :'sev' = 'zincir' AND :'adim' = '2' AND :'ahv' = 'k4-H2'
        AND :'rtab' = 'tohumlama' AND :'dtx' = :'rtx' THEN 'PASS' ELSE 'FAIL' END,
  format('tip=%s ref=%s/%s dtx=%s', :'ttip', :'rtab', :'rid', :'dtx');

-- V6b: orijinal islem_log satırı değişmedi (tam-satır)
SELECT to_jsonb(il) AS ilsonra FROM public.islem_log il WHERE il.ref_id = :'t8' AND il.tip = 'TOHUMLAMA' \gset
INSERT INTO k4 SELECT 'V6b orijinal islem_log satırı değişmedi (tam-satır karşılaştırma)',
  'birebir aynı', format('ayni=%s', (:'ilonce' IS NOT DISTINCT FROM :'ilsonra')),
  CASE WHEN :'ilonce' IS NOT DISTINCT FROM :'ilsonra' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ V8a/V8b: çakışma listeleri (tohumlama T9) ══════════════════════════════
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-v8-s1', 'k4-test') RETURNING id AS t9, txid_current()::text AS t9a \gset
UPDATE public.tohumlama SET sperma = 'k4-v8-s2' WHERE id = :'t9' RETURNING txid_current()::text AS t9b \gset
UPDATE public.tohumlama SET sperma = 'k4-v8-s3' WHERE id = :'t9' RETURNING txid_current()::text AS t9c \gset
INSERT INTO k4_idler VALUES (:'t9');

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','tohumlama','pk',:'t9','txid',:'t9a'), 'satir') AS j)
SELECT j -> 'cakismalar' AS ck, j::text AS jtxt FROM c \gset
INSERT INTO k4 SELECT 'V8a satır hedef E1 → çakışma TAM liste (E2 VE E3) + zaman/degisen_alanlar/islem/log_id',
  'cakisma=2, her kayıt zengin', format('cakisma=%s ilk_alan=%s', jsonb_array_length(:'ck'::jsonb),
         :'ck'::jsonb -> 0 ->> 'degisen_alanlar'),
  CASE WHEN jsonb_array_length(:'ck'::jsonb) = 2
        AND :'ck'::jsonb -> 0 ? 'zaman' AND :'ck'::jsonb -> 0 ? 'degisen_alanlar'
        AND :'ck'::jsonb -> 0 ? 'islem' AND :'ck'::jsonb -> 0 ? 'log_id'
       THEN 'PASS' ELSE 'FAIL' END, left(:'jtxt', 200);

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','tohumlama','pk',:'t9','txid',:'t9b','alan','sperma'), 'alan') AS j)
SELECT j -> 'cakismalar' AS ck, j::text AS jtxt FROM c \gset
INSERT INTO k4 SELECT 'V8b alan hedef (E2/sperma) → sperma''ya dokunan TÜM sonraki değişiklikler (E3)',
  'cakisma=1 (E3)', format('cakisma=%s', jsonb_array_length(:'ck'::jsonb)),
  CASE WHEN jsonb_array_length(:'ck'::jsonb) = 1
        AND :'ck'::jsonb -> 0 ->> 'log_id' IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
  left(:'jtxt', 200);

-- ══ V3a/V3b/V6c: aynı-satır zincir + fallback orijinal_tip (padok P3) ══════
INSERT INTO public.padoklar (ad) VALUES ('k4-P3') RETURNING id AS p3, txid_current()::text AS p3a \gset
UPDATE public.padoklar SET ad = 'k4-P3-b' WHERE id = :'p3' RETURNING txid_current()::text AS p3b \gset
UPDATE public.padoklar SET ad = 'k4-P3-c' WHERE id = :'p3' RETURNING txid_current()::text AS p3c \gset
INSERT INTO k4_idler VALUES (:'p3');

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','padoklar','pk',:'p3','txid',:'p3a'), 'zincir') AS j)
SELECT j ->> 'ok' AS ok, jsonb_array_length(j -> 'plan') AS pn,
       j -> 'plan' -> 0 ->> 'islem' AS s0, j -> 'plan' -> 2 ->> 'islem' AS s2,
       (j -> 'plan' -> 0 ->> 'log_id') AS lid0, (j -> 'plan' -> 2 ->> 'log_id') AS lid2 FROM c \gset
INSERT INTO k4 SELECT 'V3a zincir aynı-satır: 3 adım, sira E3→E2→E1',
  'ok=true plan=3 plan[0]=U plan[2]=I',
  format('ok=%s plan=%s s0=%s s2=%s', :'ok', :'pn', :'s0', :'s2'),
  CASE WHEN :'ok' = 'true' AND :'pn' = '3' AND :'s0' = 'U' AND :'s2' = 'I'
        AND :'lid0'::bigint > :'lid2'::bigint THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','padoklar','pk',:'p3','txid',:'p3a'),
                                         'zincir', :'bilet'::uuid, 'k4 V3b') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata','-') AS hat, coalesce(j ->> 'uygulanan_adim','0') AS adim,
       coalesce(j ->> 'geri_alma_txid','-') AS rtx FROM c \gset
SELECT count(*) AS p3k FROM public.padoklar WHERE id = :'p3' \gset
INSERT INTO k4 SELECT 'V3b zincir uygula: TEK transaction, tek geri_alma_txid, satır silinir',
  'ok=true adim=3 padok=0', format('ok=%s hat=%s adim=%s padok=%s', :'ok', :'hat', :'adim', :'p3k'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '3' AND :'p3k' = '0' THEN 'PASS' ELSE 'FAIL' END, '';

-- V6c: padok telafi — köprüden islem_log ÇÖZÜLEMEZ → fallback etiket
SELECT payload ->> 'orijinal_tip' AS otip, payload ->> 'adim' AS adim
  FROM public.islem_log WHERE tip = 'GERI_ALINDI' AND ref_id = :'p3' \gset
INSERT INTO k4 SELECT 'V6c padok zincirinin telafi kaydı: orijinal_tip = hedef tablo + işlem etiketi (fallback)',
  'orijinal_tip=padoklar ekleme, guncelleme (adim=3; harf kümesi YOK)',
  format('otip=%s adim=%s', :'otip', :'adim'),
  CASE WHEN :'otip' = 'padoklar ekleme, guncelleme' AND :'adim' = '3'
        AND :'otip' NOT LIKE 'I,U%' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ V5a/V5b: kaymalı zincir → sıralı rehber + jeton kaydı + bayraksız tekil ═
-- Sahne: AYNI tx'te T1 + T2 (iki tohumlama satırı); T2 kaymalı (logsız
-- güncelleme) → zincir bloklanır; rehber yalnız T1'i içerir (kaymalı dışarıda).
BEGIN;
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-v5-t1', 'k4-test') RETURNING id AS t1v, txid_current()::text AS t1tx \gset
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-v5-t2', 'k4-test') RETURNING id AS t2v \gset
COMMIT;
DO $do$
BEGIN
  ALTER TABLE public.tohumlama DISABLE TRIGGER trg_degisim_log;
  UPDATE public.tohumlama SET sperma = 'k4-v5-t2-DRIFT' WHERE sperma = 'k4-v5-t2';
  ALTER TABLE public.tohumlama ENABLE TRIGGER trg_degisim_log;
EXCEPTION WHEN others THEN
  ALTER TABLE public.tohumlama ENABLE TRIGGER trg_degisim_log;
  RAISE;
END;
$do$;
INSERT INTO k4_idler VALUES (:'t1v'), (:'t2v');

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('txid',:'t1tx'), 'zincir') AS j)
SELECT j ->> 'ok' AS ok, (j ->> 'geri_alinabilir') AS ga,
       CASE WHEN jsonb_typeof(j -> 'sirali_rehber') = 'array' THEN jsonb_array_length(j -> 'sirali_rehber') ELSE 0 END AS rn,
       (j -> 'sirali_rehber' -> 0 -> 'hedef' ->> 'txid') AS rh0tx,
       (j -> 'sirali_rehber' -> 0 -> 'hedef' ->> 'tablo') AS rh0t,
       coalesce(j -> 'sirali_rehber' -> 0 ->> 'neden_dahil_degil','-') AS rnd,
       (j -> 'sirali_rehber')::text AS rtxt FROM c \gset
INSERT INTO k4 SELECT 'V5a rehber: kaymalı zincirde geri_alinabilir=false, rehber sıralı (kaymalı T2 dışarıda)',
  'ok=true ga=false rehber=1 (yalnız T1; hedef BAYRAKSIZ)',
  format('ok=%s ga=%s rehber=%s r0=%s/%s neden=%s bayrak=%s',
         :'ok', :'ga', :'rn', :'rh0t', :'rh0tx', :'rnd',
         (:'rtxt' LIKE '%l4_rehber%')),
  CASE WHEN :'ok' = 'true' AND :'ga' = 'false' AND :'rn' = '1'
        AND :'rh0t' = 'tohumlama' AND :'rtxt' NOT LIKE '%l4_rehber%'
       THEN 'PASS' ELSE 'FAIL' END, left(:'rtxt', 200);

SELECT count(*) AS j1 FROM surum_gizli.l4_rehber_adimlari
 WHERE tablo='tohumlama' AND satir_pk ->> 'id' = :'t1v' \gset
SELECT count(*) AS j2 FROM surum_gizli.l4_rehber_adimlari
 WHERE tablo='tohumlama' AND satir_pk ->> 'id' = :'t2v' \gset
INSERT INTO k4 SELECT 'V5a2 jeton kaydı (L4-01): sunucu rehber adımını kayda geçti',
  'kayit(T1)=1 kayit(T2)=0', format('T1=%s T2=%s', :'j1', :'j2'),
  CASE WHEN :'j1' = '1' AND :'j2' = '0' THEN 'PASS' ELSE 'FAIL' END, '';

-- V5b: rehber adımını BAYRAKSIZ {tablo,pk,txid} + satir seviyesiyle geri al
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','tohumlama','pk',:'t1v','txid',:'t1tx'),
                                         'satir', :'bilet'::uuid, 'k4 V5b') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata','-') AS hat, coalesce(j ->> 'uygulanan_adim','0') AS adim FROM c \gset
SELECT count(*) AS t1k FROM public.tohumlama WHERE id = :'t1v' \gset
INSERT INTO k4 SELECT 'V5b rehber sırasıyla tekil geri alma (satir, bayraksız — L4-01/L4-04 uyumu)',
  'ok=true adim=1 T1 silinir', format('ok=%s hat=%s adim=%s T1=%s', :'ok', :'hat', :'adim', :'t1k'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '1' AND :'t1k' = '0' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ V5c: 3-adım rehber — üçüncü adım İZ-ÇİFTİ gevşetmesini kanıtlar ════════
-- Sahne: tx tX içinde T3 (INSERT) + T4 (INSERT, başka satır); SONRA T3 üzerinde
-- iki ayrı UPDATE (txB, txC). Zincir {T3, tX}: T4 kaymalı (logsız) → blok
-- T4'te; rehber = [T3@txC, T3@txB, T3@tX] — en yeni önce. Sırayla 3/3.
BEGIN;
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-v5c-t3', 'k4-test') RETURNING id AS t3, txid_current()::text AS t3a \gset
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-v5c-t4', 'k4-test') RETURNING id AS t4 \gset
COMMIT;
UPDATE public.tohumlama SET sperma = 'k4-v5c-t3-2' WHERE id = :'t3' RETURNING txid_current()::text AS t3b \gset
UPDATE public.tohumlama SET sperma = 'k4-v5c-t3-3' WHERE id = :'t3' RETURNING txid_current()::text AS t3c \gset
DO $do$
BEGIN
  ALTER TABLE public.tohumlama DISABLE TRIGGER trg_degisim_log;
  UPDATE public.tohumlama SET sperma = 'k4-v5c-t4-DRIFT' WHERE sperma = 'k4-v5c-t4';
  ALTER TABLE public.tohumlama ENABLE TRIGGER trg_degisim_log;
EXCEPTION WHEN others THEN
  ALTER TABLE public.tohumlama ENABLE TRIGGER trg_degisim_log;
  RAISE;
END;
$do$;
INSERT INTO k4_idler VALUES (:'t3'), (:'t4');

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('txid',:'t3a'), 'zincir') AS j)
SELECT (j ->> 'geri_alinabilir') AS ga,
       CASE WHEN jsonb_typeof(j -> 'sirali_rehber') = 'array' THEN jsonb_array_length(j -> 'sirali_rehber') ELSE 0 END AS rn,
       (j -> 'sirali_rehber' -> 0 -> 'hedef' ->> 'txid') AS u0,
       (j -> 'sirali_rehber' -> 1 -> 'hedef' ->> 'txid') AS u1,
       (j -> 'sirali_rehber' -> 2 -> 'hedef' ->> 'txid') AS u2 FROM c \gset
INSERT INTO k4 SELECT 'V5c-0 rehber: [T3@txC, T3@txB, T3@tX] (blok T4''te, kaymalı dışarıda)',
  'ga=false rehber=3 u0=txC u1=txB u2=tX',
  format('ga=%s rn=%s u0=%s u1=%s u2=%s', :'ga', :'rn',
         (:'u0' = :'t3c'), (:'u1' = :'t3b'), (:'u2' = :'t3a')),
  CASE WHEN :'ga' = 'false' AND :'rn' = '3' AND :'u0' = :'t3c'
        AND :'u1' = :'t3b' AND :'u2' = :'t3a' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','tohumlama','pk',:'t3','txid',:'t3c'),
                                         'satir', :'bilet'::uuid, 'k4 V5c-1') AS j)
SELECT coalesce(j ->> 'ok','false') AS ok1, coalesce(j ->> 'hata','-') AS hat1 FROM c \gset
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','tohumlama','pk',:'t3','txid',:'t3b'),
                                         'satir', :'bilet'::uuid, 'k4 V5c-2') AS j)
SELECT coalesce(j ->> 'ok','false') AS ok2, coalesce(j ->> 'hata','-') AS hat2 FROM c \gset
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','tohumlama','pk',:'t3','txid',:'t3a'),
                                         'satir', :'bilet'::uuid, 'k4 V5c-3') AS j)
SELECT coalesce(j ->> 'ok','false') AS ok3, coalesce(j ->> 'hata','-') AS hat3 FROM c \gset
SELECT count(*) AS t3k FROM public.tohumlama WHERE id = :'t3' \gset
INSERT INTO k4 SELECT 'V5c rehber sırasıyla 3/3 (3. adım iz-çifti gevşetmesiyle geçer; bayrak yok)',
  'ok1 ok2 ok3 — T3 silinir', format('1=%s/%s 2=%s/%s 3=%s/%s T3=%s',
         :'ok1', :'hat1', :'ok2', :'hat2', :'ok3', :'hat3', :'t3k'),
  CASE WHEN :'ok1' = 'true' AND :'ok2' = 'true' AND :'ok3' = 'true' AND :'t3k' = '0'
       THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ V7/V7b: adım sınırı ════════════════════════════════════════════════════
INSERT INTO public.padoklar (ad) VALUES ('k4-P7') RETURNING id AS p7, txid_current()::text AS p7a \gset
INSERT INTO k4_idler VALUES (:'p7');
DO $do$
DECLARE i int; v_id text;
BEGIN
  SELECT id INTO v_id FROM public.padoklar WHERE ad = 'k4-P7' LIMIT 1;
  FOR i IN 1 .. 101 LOOP
    UPDATE public.padoklar SET ad = left(ad, 20) || '-' || i::text WHERE id = v_id::uuid;
  END LOOP;
END;
$do$;
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','padoklar','pk',:'p7','txid',:'p7a'), 'zincir') AS j)
INSERT INTO k4 SELECT 'V7 zincir >100 adım → GECERSIZ_HEDEF + ZINCIR_COK_UZUN',
  'GECERSIZ_HEDEF/ZINCIR_COK_UZUN', format('%s/%s', j ->> 'hata', j -> 'detay' ->> 'neden'),
  CASE WHEN j ->> 'hata' = 'GECERSIZ_HEDEF' AND j -> 'detay' ->> 'neden' = 'ZINCIR_COK_UZUN'
       THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

INSERT INTO public.padoklar (ad) VALUES ('k4-P8') RETURNING id AS p8 \gset
BEGIN;
SELECT txid_current()::text AS gtx \gset
INSERT INTO public.grup_padok_eslem (grup, padok_id)
SELECT 'k4-G-' || g, :'p8'::uuid FROM generate_series(1, 101) g;
COMMIT;
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('txid',:'gtx'), 'zincir') AS j)
INSERT INTO k4 SELECT 'V7b başlangıç adımı >100 (tx genişliği) → ZINCIR_COK_UZUN',
  'GECERSIZ_HEDEF/ZINCIR_COK_UZUN',
  format('%s/%s', j ->> 'hata', j -> 'detay' ->> 'neden'),
  CASE WHEN j ->> 'hata' = 'GECERSIZ_HEDEF' AND j -> 'detay' ->> 'neden' = 'ZINCIR_COK_UZUN'
       THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

-- ══ A1: ilgisiz aynı-hayvan INSERT (aşı) zincire GİRMEZ (K1 YENİ) ═══════════
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-a1-t', 'k4-test') RETURNING id AS t7, txid_current()::text AS t7a \gset
UPDATE public.tohumlama SET sperma = 'k4-a1-t2' WHERE id = :'t7'
RETURNING txid_current()::text AS t7b \gset
INSERT INTO public.vaccination_log (animal_id, vaccine_id, vaccination_date, dose_given, unit, route, notes)
SELECT 'k4-H1', v.id, CURRENT_DATE, 2, 'ml', 'sc', 'k4-a1-ilgisiz-asi'
  FROM public.vaccines v ORDER BY v.id LIMIT 1
RETURNING txid_current()::text AS t7v \gset
INSERT INTO k4_idler VALUES (:'t7');
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','tohumlama','pk',:'t7','txid',:'t7a'), 'zincir') AS j)
SELECT jsonb_array_length(j -> 'plan') AS pn, (j -> 'plan')::text AS plantxt,
       (j -> 'bagimliliklar')::text AS bagtxt FROM c \gset
INSERT INTO k4 SELECT 'A1 ilgisiz aynı-hayvan INSERT (aşı/kayıt) zincire GİRMEZ (K1 yeni)',
  'plan=2 (yalnız tohumlama); aşı ne planda ne bağımlılıkta',
  format('plan=%s asi_plan=%s asi_bag=%s', :'pn',
         (:'plantxt' LIKE '%vaccination_log%'), (:'bagtxt' LIKE '%vaccination_log%')),
  CASE WHEN :'pn' = '2' AND :'plantxt' NOT LIKE '%vaccination_log%'
        AND :'bagtxt' NOT LIKE '%vaccination_log%' THEN 'PASS' ELSE 'FAIL' END,
  left(:'plantxt', 200);

-- ══ A2: sahte l4_rehber — istemci bayrağı YOK SAYILIR (L4-01) ══════════════
-- Şekil 1: temiz sonraki girişi olan hedef (üye DEĞİL) + sahte bayrak
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan)
VALUES ('k4-H1', 'k4-a2-t5', 'k4-test') RETURNING id AS t5, txid_current()::text AS t5a \gset
UPDATE public.tohumlama SET sperma = 'k4-a2-t5-2' WHERE id = :'t5'
RETURNING txid_current()::text AS t5b \gset
INSERT INTO k4_idler VALUES (:'t5');
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','tohumlama','pk',:'t5','txid',:'t5a',
                                            'l4_rehber', true),
                                         'satir', :'bilet'::uuid, 'k4 A2-1 sahte bayrak') AS j)
INSERT INTO k4 SELECT 'A2-1 sahte l4_rehber (temiz sonraki giriş var, üye değil) → gevşetme YOK',
  'CAKISMA', coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN j ->> 'hata' = 'CAKISMA' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;
-- Şekil 2: kaymalı satır (üye değil) + sahte bayrak → durum kayması çakışma
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo','tohumlama','pk',:'t2v','txid',:'t1tx',
                                            'l4_rehber', true),
                                         'satir', :'bilet'::uuid, 'k4 A2-2 sahte bayrak') AS j)
INSERT INTO k4 SELECT 'A2-2 sahte l4_rehber (kaymalı satır, üye değil) → gevşetme YOK',
  'CAKISMA (GUNCEL_DURUM_FARKLI)', coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN j ->> 'hata' = 'CAKISMA' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

-- ══ A3: sahte GERI_ALINDI doğrudan INSERT → RED (L4-02b) ═══════════════════
DO $do$
BEGIN
  BEGIN
    INSERT INTO public.islem_log (tip, ref_id, ref_tablo, payload, snapshot)
    VALUES ('GERI_ALINDI', 'k4-sahte', 'tohumlama', '{"k4onarim":"a3"}', '{}'::jsonb);
    INSERT INTO k4 VALUES ('A3 sahte GERI_ALINDI doğrudan INSERT (postgres, GUC yok) → RED',
      'exception 42501', 'kabul edildi', 'FAIL', '');
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO k4 VALUES ('A3 sahte GERI_ALINDI doğrudan INSERT (postgres, GUC yok) → RED',
      'exception 42501', SQLSTATE, 'PASS', SQLERRM);
  WHEN others THEN
    INSERT INTO k4 VALUES ('A3 sahte GERI_ALINDI doğrudan INSERT (postgres, GUC yok) → RED',
      'exception 42501', SQLSTATE, 'FAIL', SQLERRM);
  END;
END;
$do$;

-- ══ A4: sahte degisim_txid → txid_current() EZİLİR (L4-02a) ════════════════
BEGIN;
WITH i AS (
  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, payload, degisim_txid, snapshot)
  VALUES ('PADOK_EKLE', 'k4-a4', 'padoklar', '{"k4onarim":"a4"}', 424242424, '{}'::jsonb)
  RETURNING degisim_txid AS dtx)
SELECT (SELECT dtx::text FROM i) AS a4dtx, txid_current()::text AS a4beklenen \gset
ROLLBACK;
INSERT INTO k4 SELECT 'A4 sahte degisim_txid (istemci değeri 424242424) → ezilir',
  'degisim_txid == txid_current() (≠ 424242424)',
  format('damga=%s beklenen=%s', :'a4dtx', :'a4beklenen'),
  CASE WHEN :'a4dtx' = :'a4beklenen' AND :'a4dtx' <> '424242424' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ A5: S3b yeni yorum — tohumlama+sonuc zinciri; doğum FK ölçümü ══════════
INSERT INTO public.tohumlama (hayvan_id, sperma, tohumlayan, sonuc)
VALUES ('k4-H6', 'k4-a5-t6', 'k4-test', 'Bekliyor') RETURNING id AS t6, txid_current()::text AS t6a \gset
UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id = :'t6' RETURNING txid_current()::text AS t6b \gset
BEGIN;
INSERT INTO public.dogum (anne_id, yavru_kupe, yavru_cins)
VALUES ('k4-H6', 'k4-buzagu-6', 'Erkek') RETURNING id AS d6, txid_current()::text AS t6c \gset
COMMIT;
INSERT INTO k4_idler VALUES (:'t6'), (:'d6');
-- dürüst FK ölçümü: tohumlama satırının silinmesi dogum'u ENGELLİYOR MU?
BEGIN;
DELETE FROM public.tohumlama WHERE id = :'t6';
SELECT count(*) AS a5silindi FROM public.tohumlama WHERE id = :'t6' \gset
ROLLBACK;
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo','tohumlama','pk',:'t6','txid',:'t6a'), 'zincir') AS j)
SELECT (SELECT count(*) FROM jsonb_array_elements(j -> 'plan') p WHERE p ->> 'tablo' = 'dogum') AS dplan,
       (SELECT count(*) FROM jsonb_array_elements(j -> 'bagimliliklar') b WHERE b ->> 'tablo' = 'dogum') AS dbag,
       (SELECT count(*) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j -> 'sirali_rehber') = 'array'
                                                        THEN j -> 'sirali_rehber' ELSE '[]'::jsonb END) rb
         WHERE rb -> 'hedef' ->> 'tablo' = 'dogum') AS dreh,
       (j -> 'plan')::text AS plantxt
  FROM c \gset
INSERT INTO k4 SELECT 'A5 K1-yeni: doğum FK''sız → plan/rehber/bağımlılık DIŞI; tohumlama silinimi dogum''u engellemiyor (ölçüm)',
  'dogum hiçbir listede yok; DELETE tohumlama engellenmez (satır sayısı silme sonrası 0)',
  format('dogum_plan=%s dogum_bag=%s dogum_rehber=%s silme_sonrasi_sayi=%s',
         :'dplan', :'dbag', :'dreh', :'a5silindi'),
  CASE WHEN :'dplan' = '0' AND :'dbag' = '0' AND :'dreh' = '0'
        AND :'a5silindi' = '0' THEN 'PASS' ELSE 'FAIL' END,
  format('silindi_rollback=%s plan=%s', :'a5silindi', left(:'plantxt', 120));

-- ══ A6: authenticated islem_log INSERT → RED (L4-02c) ══════════════════════
DO $do$
BEGIN
  BEGIN
    SET LOCAL ROLE authenticated;
    INSERT INTO public.islem_log (tip, ref_id, ref_tablo, payload, snapshot)
    VALUES ('PADOK_EKLE', 'k4-a6', 'padoklar', '{"k4onarim":"a6"}', '{}'::jsonb);
    INSERT INTO k4 VALUES ('A6 authenticated islem_log INSERT → RED',
      'permission denied', 'kabul edildi', 'FAIL', '');
    RESET ROLE;
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO k4 VALUES ('A6 authenticated islem_log INSERT → RED',
      'permission denied', SQLSTATE, 'PASS', SQLERRM);
    RESET ROLE;
  WHEN others THEN
    INSERT INTO k4 VALUES ('A6 authenticated islem_log INSERT → RED',
      'permission denied', SQLSTATE, 'FAIL', SQLERRM);
    RESET ROLE;
  END;
END;
$do$;

-- ══ TEMİZLİK (k1b/k3 S11 deseni — operatör düzeyinde) ══════════════════════
DELETE FROM public.grup_padok_eslem WHERE grup LIKE 'k4-G-%';
DELETE FROM public.vaccination_log WHERE notes LIKE 'k4-a1%';
DELETE FROM public.dogum WHERE yavru_kupe LIKE 'k4-%';
DELETE FROM public.tohumlama WHERE id::text IN (SELECT id FROM k4_idler)
   OR sperma LIKE 'k4-%';
DELETE FROM public.padoklar WHERE ad LIKE 'k4-%' OR id::text IN (SELECT id FROM k4_idler);
DELETE FROM public.hayvanlar WHERE id IN (SELECT id FROM k4_idler);

-- islem_log: immutable → operatör temizliği (yalnız bu koşumun satırları)
ALTER TABLE public.islem_log DISABLE TRIGGER USER;
DELETE FROM public.islem_log
 WHERE payload ->> 'k4onarim' IS NOT NULL
    OR ref_id IN (SELECT id FROM k4_idler)
    OR (tip = 'GERI_ALINDI' AND ref_id IN (SELECT id FROM k4_idler));
ALTER TABLE public.islem_log ENABLE TRIGGER USER;

-- degisim_log purge (yalnız k4-onarim-testi kayıtları)
ALTER TABLE public.degisim_log DISABLE TRIGGER USER;
DELETE FROM public.degisim_log WHERE kaynak ->> 'istemci_etiketi' = 'k4-onarim-testi';
ALTER TABLE public.degisim_log ENABLE TRIGGER USER;

-- jeton kayıtları: bu koşumun adımları + yetimler (girişi silinmiş her şey;
-- koşum kendi kendini temizler, önceki yarı koşumların izi kalmaz)
DELETE FROM surum_gizli.l4_rehber_adimlari
 WHERE satir_pk ->> 'id' IN (SELECT id FROM k4_idler);
DELETE FROM surum_gizli.l4_rehber_adimlari a
 WHERE NOT EXISTS (SELECT 1 FROM public.degisim_log d
                    WHERE d.tablo_adi = a.tablo AND d.satir_pk IS NOT DISTINCT FROM a.satir_pk
                      AND d.txid = a.txid);

-- gizli durum geri yükleme (k3 S11/S14)
DELETE FROM surum_gizli.geri_alma_kullanim
 WHERE bilet IN (SELECT bilet FROM surum_gizli.geri_alma_bileti
                  WHERE bilet NOT IN (SELECT bilet FROM k4_bilet_once));
DELETE FROM surum_gizli.geri_alma_bileti
 WHERE bilet NOT IN (SELECT bilet FROM k4_bilet_once);
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM k4_sifre_once) THEN
    UPDATE surum_gizli.sahip_sifresi
       SET hash = (SELECT hash FROM k4_sifre_once),
           guncelleme = (SELECT guncelleme FROM k4_sifre_once);
  ELSE
    DELETE FROM surum_gizli.sahip_sifresi;
  END IF;
END;
$do$;
INSERT INTO surum_gizli.geri_alma_bileti (bilet, olusturma, son_gecerlilik, kaynak)
SELECT bilet, olusturma, son_gecerlilik, kaynak FROM k4_bilet_once
ON CONFLICT (bilet) DO UPDATE
  SET olusturma = EXCLUDED.olusturma,
      son_gecerlilik = EXCLUDED.son_gecerlilik,
      kaynak = EXCLUDED.kaynak;

-- iş trigger'larını geri aç
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_hayvan_cikis_gorev_iptal;
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_hayvan_grup_padok_sync;
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_hayvanlar_guard;
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_islem_hayvanlar;
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_padok_transfer_gorev;
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_pedigree_hayvan_insert;
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_sutten_kesme_kapat;
ALTER TABLE public.hayvanlar     ENABLE TRIGGER trg_sutten_kesme_normalize;
ALTER TABLE public.tohumlama     ENABLE TRIGGER tohumlama_cycle_iptal_trigger;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_deneme_no;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_islem_tohumlama_abort;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_islem_tohumlama_insert;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_tohumlama_gebe_gorev;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_tohumlama_gebe_sessiz_iptal;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_tohumlama_guard;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_tohumlama_kizginlik;
ALTER TABLE public.tohumlama     ENABLE TRIGGER trg_tohumlama_sessiz_iptal;
ALTER TABLE public.dogum         ENABLE TRIGGER trg_dogum_guard;
ALTER TABLE public.dogum         ENABLE TRIGGER trg_islem_dogum;
ALTER TABLE public.vaccination_log ENABLE TRIGGER trg_dinle_vaccination;
ALTER TABLE public.vaccination_log ENABLE TRIGGER trg_vaccination_stok;

-- temizlik doğrulaması
SELECT count(*) AS logkalan FROM public.degisim_log
 WHERE kaynak ->> 'istemci_etiketi' = 'k4-onarim-testi' \gset
SELECT count(*) AS padokkalan FROM public.padoklar WHERE ad LIKE 'k4-%' \gset
SELECT count(*) AS hvkalan FROM public.hayvanlar WHERE id LIKE 'k4-%' \gset
SELECT count(*) AS iskalan FROM public.islem_log WHERE payload ->> 'k4onarim' IS NOT NULL \gset
SELECT count(*) AS jetkalan FROM surum_gizli.l4_rehber_adimlari
 WHERE satir_pk ->> 'id' IN (SELECT id FROM k4_idler) \gset
SELECT (SELECT row(hash, guncelleme) FROM surum_gizli.sahip_sifresi)
    IS NOT DISTINCT FROM (SELECT row(hash, guncelleme) FROM k4_sifre_once) AS sifretam \gset
INSERT INTO k4 SELECT 'TEMIZLIK: log=0 padok=0 hayvan=0 islem_log=0 jeton=0 (şifre metadata birebir)',
  'hepsi 0 / sifretam=t',
  format('log=%s padok=%s hayvan=%s islem=%s jeton=%s sifretam=%s',
         :'logkalan', :'padokkalan', :'hvkalan', :'iskalan', :'jetkalan', :'sifretam'),
  CASE WHEN :'logkalan' = '0' AND :'padokkalan' = '0' AND :'hvkalan' = '0'
        AND :'iskalan' = '0' AND :'jetkalan' = '0' AND :'sifretam' = 't'
       THEN 'PASS' ELSE 'FAIL' END, '';

\echo '== k4_onarim sonuç tablosu =='
SELECT vaka, beklenen, bulunan, sonuc, left(detay, 160) AS detay FROM k4 ORDER BY ctid;

\echo '== özet =='
SELECT count(*) FILTER (WHERE sonuc = 'PASS') AS pass,
       count(*) FILTER (WHERE sonuc <> 'PASS') AS fail,
       count(*) AS toplam FROM k4;
SELECT vaka, beklenen, bulunan, left(detay, 200) AS detay FROM k4 WHERE sonuc <> 'PASS';
