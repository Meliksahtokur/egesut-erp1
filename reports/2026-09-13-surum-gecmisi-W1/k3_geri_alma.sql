-- Acceptance 3 (G-20260913-SURUM-GECMISI): ticketed revert engine on DEMO.
-- Covers: password/ticket flow (wrong pw, unset pw, expired, invalid, NULL,
-- multi-use), alan/satir/islem revert levels, revert-of-revert (alan AND
-- islem), CAKISMA, BAGIMLILIK_ENGELI (ENGEL + KADEMELI), stok_uyari,
-- composite-PK targets (vaccine_diseases, pedigree_meta — satir_pk object),
-- HEDEF_BULUNAMADI (missing pk, pre-system row, empty txid), GECERSIZ_SEVIYE,
-- GECERSIZ_HEDEF (out-of-scope table, bad pk type, alan-on-insert),
-- degisim_listele filters, kullanım records, revert kaynak stamp.
--
-- NOT rollback-wrapped: revert tests need REAL distinct txids (a revert is
-- reverted by targeting the revert's own txid), so scenarios commit. All
-- synthetic rows carry traceable markers and the log rows carry
-- app.istemci_etiketi='k3-geri-alma-testi'; S11 cleanup removes every trace
-- (degisim_log purge is an explicit operator action with triggers disabled,
-- same pattern as the k1b red-before).
--
-- Run: dpsql -f reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql
\set ON_ERROR_STOP 1

SELECT set_config('app.istemci_etiketi', 'k3-geri-alma-testi', false) AS etiket_kurulumu;
CREATE TEMP TABLE k3 (vaka text, beklenen text, bulunan text, sonuc text, detay text);

-- ── captured initial state ─────────────────────────────────────────────────
SELECT telefon AS h3tel, aktif::text AS h3aktif FROM public.hekimler WHERE id = 'H3' \gset
SELECT ad AS h2ad FROM public.hekimler WHERE id = 'H2' \gset
SELECT id AS stok1 FROM public.stok ORDER BY id LIMIT 1 \gset

-- ── idempotency prelude: wipe leftovers of any earlier k3 run ──────────────
UPDATE public.hekimler SET telefon = :'h3tel', aktif = :'h3aktif'::boolean WHERE id = 'H3';
UPDATE public.hekimler SET ad = :'h2ad' WHERE id = 'H2';
DELETE FROM public.grup_padok_eslem WHERE grup LIKE 'k3-%';
DELETE FROM public.padoklar WHERE ad LIKE 'k3-%';
DELETE FROM public.tedavi_sablonu WHERE ad LIKE 'k3-%';
DELETE FROM public.stok_hareket WHERE notlar LIKE 'k3-%';
DELETE FROM public.pedigree_meta WHERE key = 'k3-composite';
DO $do$
BEGIN
  ALTER TABLE public.degisim_log DISABLE TRIGGER USER;
  DELETE FROM public.degisim_log WHERE kaynak ->> 'istemci_etiketi' = 'k3-geri-alma-testi';
  ALTER TABLE public.degisim_log ENABLE TRIGGER USER;
EXCEPTION WHEN others THEN
  ALTER TABLE public.degisim_log ENABLE TRIGGER USER;
  RAISE;
END;
$do$;
-- LUNA-4: paylaşılan gizli durum koşum başında anlık görüntülenir; temizlik
-- yalnız bu koşumun ürettiği kayıtlara dokunur (önceden var olan bilet,
-- kullanım ve sahip şifresi korunur — S11/S11b).
CREATE TEMP TABLE k3_biletler_once AS SELECT bilet FROM surum_gizli.geri_alma_bileti;
CREATE TEMP TABLE k3_sifre_once AS SELECT hash FROM surum_gizli.sahip_sifresi;
SELECT EXISTS (SELECT 1 FROM k3_sifre_once) AS sifrevardi \gset

-- ══ S0: password + ticket flow ═════════════════════════════════════════════
WITH c AS (SELECT public.geri_alma_bileti_al('herhangi-bir-sey') AS j)
INSERT INTO k3 SELECT 'S0a bilet: şifre durumu (ayarlı değilse SIFRE_AYARLI_DEGİL)',
  'paylaşılan-demo uyumlu',
  coalesce(j ->> 'hata', 'ok=true') || ' sifrevardi=' || :'sifrevardi',
  CASE WHEN (:'sifrevardi' = 't' AND NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'SIFRE_HATALI')
        OR (:'sifrevardi' <> 't' AND NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'SIFRE_AYARLI_DEGIL')
       THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;

DO $do$
BEGIN
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM public.sahip_sifresi_ayarla('k3-deneme-sifresi');
    INSERT INTO k3 VALUES ('S0b setup RPC authenticated ile', 'permission denied', 'çağrı kabul edildi', 'FAIL', '');
    RESET ROLE;
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO k3 VALUES ('S0b setup RPC authenticated ile', 'permission denied', 'permission denied', 'PASS', SQLSTATE);
    RESET ROLE;
  WHEN others THEN
    INSERT INTO k3 VALUES ('S0b setup RPC authenticated ile', 'permission denied', SQLSTATE, 'FAIL', SQLERRM);
    RESET ROLE;
  END;
END;
$do$;

DO $do$
BEGIN
  BEGIN
    SET LOCAL ROLE anon;
    PERFORM public.geri_alma_bileti_al('x');
    INSERT INTO k3 VALUES ('S0c bilet RPC anon ile', 'permission denied', 'çağrı kabul edildi', 'FAIL', '');
    RESET ROLE;
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO k3 VALUES ('S0c bilet RPC anon ile', 'permission denied', 'permission denied', 'PASS', SQLSTATE);
    RESET ROLE;
  WHEN others THEN
    INSERT INTO k3 VALUES ('S0c bilet RPC anon ile', 'permission denied', SQLSTATE, 'FAIL', SQLERRM);
    RESET ROLE;
  END;
END;
$do$;

WITH c AS (SELECT public.sahip_sifresi_ayarla('k3-sifre-2026!x') AS j)
INSERT INTO k3 SELECT 'S0d setup RPC (postgres) şifre kur', 'ok=true',
  coalesce(j ->> 'hata', 'ok=' || coalesce(j ->> 'ok', '?')),
  CASE WHEN (j ->> 'ok')::bool THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

WITH c AS (SELECT public.geri_alma_bileti_al('yanlis-sifre') AS j)
INSERT INTO k3 SELECT 'S0e bilet: yanlış şifre', 'SIFRE_HATALI',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'SIFRE_HATALI' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

WITH c AS (SELECT public.geri_alma_bileti_al('k3-sifre-2026!x') AS j)
SELECT j ->> 'ok' AS bok, coalesce(j ->> 'hata', '-') AS bhat, j ->> 'bilet' AS bilet, j ->> 'kalan_sn' AS kalan FROM c \gset
INSERT INTO k3 SELECT 'S0f bilet: doğru şifre', 'ok=true, kalan_sn≈3600',
  coalesce(:'bhat', 'ok=' || coalesce(:'bok', '?') || ' kalan=' || coalesce(:'kalan', '?')),
  CASE WHEN :'bok' = 'true' AND :'kalan'::int BETWEEN 3590 AND 3600 THEN 'PASS' ELSE 'FAIL' END, '';

INSERT INTO surum_gizli.geri_alma_bileti (son_gecerlilik)
VALUES (now() - interval '5 minutes') RETURNING bilet::text AS ebilet \gset
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3'),
                                          'satir', :'ebilet'::uuid, 'k3 süresi dolmuş') AS j)
INSERT INTO k3 SELECT 'S0g bilet: süresi dolmuş', 'BILET_SURESI_DOLMUS',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'BILET_SURESI_DOLMUS' THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;
SELECT count(*) AS ebkayit FROM surum_gizli.geri_alma_kullanim WHERE bilet = :'ebilet'::uuid
   AND sonuc ->> 'hata' = 'BILET_SURESI_DOLMUS' \gset
INSERT INTO k3 SELECT 'S0h dolmuş bilet kullanım kaydı', '1 kayıt', :'ebkayit',
  CASE WHEN :'ebkayit' = '1' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3'),
                                          'satir', gen_random_uuid(), NULL) AS j)
INSERT INTO k3 SELECT 'S0i bilet: bilinmeyen uuid', 'BILET_GECERSIZ',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'BILET_GECERSIZ' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3'),
                                          'satir', NULL, NULL) AS j)
INSERT INTO k3 SELECT 'S0j bilet: NULL', 'BILET_GECERSIZ',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'BILET_GECERSIZ' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

-- ══ S1: alan seviyesi + CAKISMA + revert-of-revert (hekimler H3) ═══════════
UPDATE public.hekimler SET telefon = coalesce(telefon, '') || '~T1' WHERE id = 'H3'
RETURNING txid_current()::text AS t1 \gset
UPDATE public.hekimler SET telefon = telefon || '~T2' WHERE id = 'H3'
RETURNING txid_current()::text AS t2 \gset

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3',
                                                            'alan', 'telefon', 'txid', :'t1'),
                                         'alan', :'bilet'::uuid, 'k3 S1a') AS j)
INSERT INTO k3 SELECT 'S1a alan revert eski tx (sonra T2 var)', 'CAKISMA',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'CAKISMA' THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3', 'alan', 'telefon'),
                                         'alan', :'bilet'::uuid, 'k3 S1b') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim FROM c \gset
SELECT telefon AS tel FROM public.hekimler WHERE id = 'H3' \gset
INSERT INTO k3 SELECT 'S1b alan revert (son değişiklik T2)', 'ok=true adim=1 telefon=~T1',
  format('ok=%s hat=%s adim=%s tel=%s', :'ok', :'hat', :'adim', :'tel'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '1' AND :'tel' = '5550000~T1' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3', 'alan', 'telefon'),
                                         'alan', :'bilet'::uuid, 'k3 S1c') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat FROM c \gset
SELECT telefon AS tel FROM public.hekimler WHERE id = 'H3' \gset
INSERT INTO k3 SELECT 'S1c revert-in-revert (alan, hedef=revert değişikliği)', 'ok=true telefon=~T1~T2',
  format('ok=%s hat=%s tel=%s', :'ok', :'hat', :'tel'),
  CASE WHEN :'ok' = 'true' AND :'tel' = '5550000~T1~T2' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ S2: satır seviyesi + stok_uyari + kaynak damgası ═══════════════════════
INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, referans_id)
VALUES (:'stok1', 'k3', 1, 'k3-uyari', 'H3') RETURNING txid_current()::text AS t3 \gset

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3'), 'satir') AS j)
SELECT (j ->> 'ok') AS ok, (j ->> 'geri_alinabilir') AS ga,
       jsonb_array_length(j -> 'stok_uyari') AS su, jsonb_array_length(j -> 'cakismalar') AS ck FROM c \gset
INSERT INTO k3 SELECT 'S2a satır önizleme: stok_uyari, çakışma yok', 'ok=true ga=true stok_uyari>=1 cakisma=0',
  format('ok=%s ga=%s stok_uyari=%s cakisma=%s', :'ok', :'ga', :'su', :'ck'),
  CASE WHEN :'ok' = 'true' AND :'ga' = 'true' AND :'su'::int >= 1 AND :'ck' = '0' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3'),
                                         'satir', :'bilet'::uuid, 'k3 S2b gerekçe') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim FROM c \gset
SELECT telefon AS tel FROM public.hekimler WHERE id = 'H3' \gset
INSERT INTO k3 SELECT 'S2b satır revert (son değişiklik = S1c reverti)', 'ok=true adim=1 telefon=~T1',
  format('ok=%s hat=%s adim=%s tel=%s', :'ok', :'hat', :'adim', :'tel'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '1' AND :'tel' = '5550000~T1' THEN 'PASS' ELSE 'FAIL' END, '';

SELECT kaynak -> 'geri_alma' ->> 'bilet' AS kb, kaynak -> 'geri_alma' ->> 'gerekce' AS kg
  FROM public.degisim_log
 WHERE tablo_adi = 'hekimler' AND kaynak -> 'geri_alma' IS NOT NULL
 ORDER BY id DESC LIMIT 1 \gset
INSERT INTO k3 SELECT 'S2c revert kaynağı damgası (bilet MASKELİ ilk-8, LUNA-1; gerekçe tam)',
  'bilet=left8+…, gerekçe eşleşir',
  format('bilet=%s gerekce=%s', :'kb', :'kg'),
  CASE WHEN :'kb' = left(:'bilet', 8) || '…' AND :'kg' = 'k3 S2b gerekçe' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ S3: işlem seviyesi + revert-of-revert (islem) ══════════════════════════
BEGIN;
UPDATE public.hekimler SET aktif = NOT aktif WHERE id = 'H3' RETURNING txid_current()::text AS t4 \gset
INSERT INTO public.padoklar (ad) VALUES ('k3-padok-T4')
RETURNING txid_current()::text AS t4b, id AS p4 \gset
COMMIT;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('txid', :'t4'), 'islem') AS j)
SELECT (j ->> 'ok') AS ok, (j ->> 'geri_alinabilir') AS ga,
       jsonb_array_length(j -> 'plan') AS pn FROM c \gset
INSERT INTO k3 SELECT 'S3a işlem önizleme (2 satır tek tx)', 'ok=true ga=true plan=2',
  format('ok=%s ga=%s plan=%s', :'ok', :'ga', :'pn'),
  CASE WHEN :'ok' = 'true' AND :'ga' = 'true' AND :'pn' = '2' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('txid', :'t4'),
                                         'islem', :'bilet'::uuid, 'k3 S3b') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim,
       coalesce(j ->> 'geri_alma_txid', '-') AS rtx FROM c \gset
SELECT count(*) AS pn FROM public.padoklar WHERE id = :'p4' \gset
SELECT aktif::text AS ak FROM public.hekimler WHERE id = 'H3' \gset
INSERT INTO k3 SELECT 'S3b işlem revert', 'ok=true adim=2 padok silindi aktif=true',
  format('ok=%s hat=%s adim=%s padok=%s aktif=%s', :'ok', :'hat', :'adim', :'pn', :'ak'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '2' AND :'pn' = '0' AND :'ak' = 'true' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('txid', :'rtx'),
                                         'islem', :'bilet'::uuid, 'k3 S3c') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim FROM c \gset
SELECT count(*) AS pn FROM public.padoklar WHERE id = :'p4' \gset
SELECT aktif::text AS ak FROM public.hekimler WHERE id = 'H3' \gset
INSERT INTO k3 SELECT 'S3c revert-in-revert (islem seviyesi)', 'ok=true adim=2 padok geri geldi aktif=false',
  format('ok=%s hat=%s adim=%s padok=%s aktif=%s', :'ok', :'hat', :'adim', :'pn', :'ak'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '2' AND :'pn' = '1' AND :'ak' = 'false' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ S4: KADEMELI bağımlılık (aynı tx'te doğan çocuk) ═══════════════════════
BEGIN;
INSERT INTO public.padoklar (ad) VALUES ('k3-padok-T5')
RETURNING txid_current()::text AS t5, id AS p5 \gset
INSERT INTO public.grup_padok_eslem (grup, padok_id) VALUES ('k3-G5', :'p5')
RETURNING txid_current()::text AS t5b \gset
COMMIT;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'padoklar', 'pk', :'p5', 'txid', :'t5'), 'satir') AS j)
SELECT (j ->> 'ok') AS ok, (j ->> 'geri_alinabilir') AS ga, jsonb_array_length(j -> 'plan') AS pn,
       (SELECT count(*) FROM jsonb_array_elements(j -> 'bagimliliklar') b WHERE b ->> 'etki' = 'KADEMELI') AS kademeli FROM c \gset
INSERT INTO k3 SELECT 'S4a satır önizleme: KADEMELI çocuk plana girer', 'ok=true ga=true plan=2 kademeli>=1',
  format('ok=%s ga=%s plan=%s kademeli=%s', :'ok', :'ga', :'pn', :'kademeli'),
  CASE WHEN :'ok' = 'true' AND :'ga' = 'true' AND :'pn' = '2' AND :'kademeli'::int >= 1 THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'padoklar', 'pk', :'p5', 'txid', :'t5'),
                                         'satir', :'bilet'::uuid, 'k3 S4b') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim FROM c \gset
SELECT count(*) AS pg FROM public.padoklar WHERE id = :'p5' \gset
SELECT count(*) AS gg FROM public.grup_padok_eslem WHERE grup = 'k3-G5' \gset
INSERT INTO k3 SELECT 'S4b kademeli revert (baba+çocuk silinir)', 'ok=true adim=2 ikisi de gitti',
  format('ok=%s hat=%s adim=%s padok=%s grup=%s', :'ok', :'hat', :'adim', :'pg', :'gg'),
  CASE WHEN :'ok' = 'true' AND :'adim' = '2' AND :'pg' = '0' AND :'gg' = '0' THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ S5: ENGEL bağımlılık (sonradan değişmiş çocuk) ═════════════════════════
BEGIN;
INSERT INTO public.padoklar (ad) VALUES ('k3-padok-T6')
RETURNING txid_current()::text AS t6, id AS p6 \gset
INSERT INTO public.grup_padok_eslem (grup, padok_id) VALUES ('k3-G6', :'p6') \gset
COMMIT;
UPDATE public.grup_padok_eslem SET grup = 'k3-G6-dg' WHERE grup = 'k3-G6'
RETURNING txid_current()::text AS t7 \gset

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'padoklar', 'pk', :'p6', 'txid', :'t6'),
                                         'satir', :'bilet'::uuid, 'k3 S5') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat,
       (SELECT count(*) FROM jsonb_array_elements(COALESCE(j -> 'detay' -> 'bagimliliklar', '[]'::jsonb)) b
         WHERE b ->> 'etki' = 'ENGEL') AS engel FROM c \gset
INSERT INTO k3 SELECT 'S5 satır revert: sonradan değişen çocuk engel', 'BAGIMLILIK_ENGELI, ENGEL>=1',
  format('ok=%s hat=%s engel=%s', :'ok', :'hat', :'engel'),
  CASE WHEN :'ok' = 'false' AND :'hat' = 'BAGIMLILIK_ENGELI' AND :'engel'::int >= 1 THEN 'PASS' ELSE 'FAIL' END,
  format('ok=%s hata=%s engel=%s', :'ok', :'hat', :'engel');

-- ══ S6: composite PK hedefleri (satir_pk nesne) ════════════════════════════
SELECT vaccine_id AS vdv, disease_id AS vdd FROM public.vaccine_diseases ORDER BY 1 LIMIT 1 \gset
SELECT id AS vdd2 FROM public.diseases
 WHERE id NOT IN (SELECT disease_id FROM public.vaccine_diseases WHERE vaccine_id = :'vdv')
 ORDER BY id LIMIT 1 \gset
UPDATE public.vaccine_diseases SET disease_id = :'vdd2'
 WHERE vaccine_id = :'vdv' AND disease_id = :'vdd'
RETURNING txid_current()::text AS t8 \gset

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'vaccine_diseases', 'pk',
                                                            jsonb_build_object('vaccine_id', :'vdv',
                                                                               'disease_id', :'vdd2')),
                                         'satir', :'bilet'::uuid, 'k3 S6a composite') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim FROM c \gset
SELECT count(*) AS geri FROM public.vaccine_diseases
 WHERE vaccine_id = :'vdv' AND disease_id = :'vdd' \gset
INSERT INTO k3 SELECT 'S6a composite PK revert (vaccine_diseases, nesne pk)', 'ok=true adim=1 eski çift geri geldi',
  coalesce(:'hat', format('ok=%s adim=%s eski_cift=%s', :'ok', :'adim', :'geri')),
  CASE WHEN :'ok' = 'true' AND :'adim' = '1' AND :'geri' = '1' THEN 'PASS' ELSE 'FAIL' END, '';

INSERT INTO public.pedigree_meta (farm_id, key, value)
VALUES ('400b9107-a85e-4126-af2c-fd7fe73fb68e', 'k3-composite', 'v1')
RETURNING txid_current()::text AS t9 \gset
UPDATE public.pedigree_meta SET value = 'v2' WHERE key = 'k3-composite'
RETURNING txid_current()::text AS t10 \gset

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'pedigree_meta', 'pk',
                                                            jsonb_build_object('farm_id', '400b9107-a85e-4126-af2c-fd7fe73fb68e',
                                                                               'key', 'k3-composite'),
                                                            'txid', :'t10'),
                                         'satir', :'bilet'::uuid, 'k3 S6b composite') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat FROM c \gset
SELECT coalesce(value, '-') AS val FROM public.pedigree_meta WHERE key = 'k3-composite' \gset
INSERT INTO k3 SELECT 'S6b composite PK revert (pedigree_meta, nesne pk + txid)', 'ok=true value=v1',
  coalesce(:'hat', format('ok=%s value=%s', :'ok', :'val')),
  CASE WHEN :'ok' = 'true' AND :'val' = 'v1' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'pedigree_meta', 'pk',
                                                            jsonb_build_object('farm_id', '400b9107-a85e-4126-af2c-fd7fe73fb68e',
                                                                               'key', 'k3-composite'),
                                                            'txid', :'t9'),
                                         'satir', :'bilet'::uuid, 'k3 S6c') AS j)
INSERT INTO k3 SELECT 'S6c composite PK: INSERT revert, sonraki değişiklik var', 'CAKISMA',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'CAKISMA' THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;

-- ══ S7: hata yolları ═══════════════════════════════════════════════════════
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'hekimler', 'pk', 'k3-yok-pk'), 'satir') AS j)
INSERT INTO k3 SELECT 'S7a olmayan pk', 'HEDEF_BULUNAMADI',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'HEDEF_BULUNAMADI' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

DO $do$
BEGIN
  ALTER TABLE public.hekimler DISABLE TRIGGER trg_degisim_log;
  UPDATE public.hekimler SET ad = 'H2-once-sistem-A' WHERE id = 'H2';
  UPDATE public.hekimler SET ad = 'H2-once-sistem-B' WHERE id = 'H2';
  ALTER TABLE public.hekimler ENABLE TRIGGER trg_degisim_log;
EXCEPTION WHEN others THEN
  ALTER TABLE public.hekimler ENABLE TRIGGER trg_degisim_log;
  RAISE;
END;
$do$;
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H2'),
                                         'satir', :'bilet'::uuid, 'k3 S7b') AS j)
INSERT INTO k3 SELECT 'S7b sistem-kurulumu-öncesi değişiklik (logsuz satır)', 'HEDEF_BULUNAMADI',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'HEDEF_BULUNAMADI' THEN 'PASS' ELSE 'FAIL' END,
  j::text FROM c;
UPDATE public.hekimler SET ad = :'h2ad' WHERE id = 'H2';

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('txid', '999999999999'), 'islem') AS j)
INSERT INTO k3 SELECT 'S7c boş txid', 'HEDEF_BULUNAMADI',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'HEDEF_BULUNAMADI' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'hekimler', 'pk', 'H3'), 'sur') AS j)
INSERT INTO k3 SELECT 'S7d geçersiz seviye', 'GECERSIZ_SEVIYE',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'GECERSIZ_SEVIYE' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'islem_log', 'pk', 'x'), 'satir') AS j)
INSERT INTO k3 SELECT 'S7e kapsam dışı tablo', 'GECERSIZ_HEDEF',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'GECERSIZ_HEDEF' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'hekimler', 'pk', jsonb_build_array(1, 2)), 'satir') AS j)
INSERT INTO k3 SELECT 'S7f geçersiz pk şekli (dizi)', 'GECERSIZ_HEDEF',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'GECERSIZ_HEDEF' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

INSERT INTO public.padoklar (ad) VALUES ('k3-padok-I8') RETURNING id AS p8 \gset
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'padoklar', 'pk', :'p8', 'alan', 'ad'), 'alan') AS j)
INSERT INTO k3 SELECT 'S7g alan hedefi INSERT kaydında', 'GECERSIZ_HEDEF',
  coalesce(j ->> 'hata', 'ok=true'),
  CASE WHEN NOT (j ->> 'ok')::bool AND j ->> 'hata' = 'GECERSIZ_HEDEF' THEN 'PASS' ELSE 'FAIL' END, j::text FROM c;

-- ══ S8: degisim_listele ════════════════════════════════════════════════════
WITH c AS (SELECT public.degisim_listele(jsonb_build_object('txid', :'t4')) AS j)
SELECT (j ->> 'ok') AS ok, coalesce(j ->> 'detay', '-') AS detay, jsonb_array_length(j -> 'kayitlar') AS n,
       (j -> 'kayitlar' -> 0 ? 'teknikal_mi') AS tmi FROM c \gset
INSERT INTO k3 SELECT 'S8a listele txid → satır detayı (teknikal_mi dahil)', 'ok=true detay=true kayitlar=2 teknikal_mi alanı var',
  format('ok=%s detay=%s n=%s teknikal_mi=%s', :'ok', :'detay', :'n', :'tmi'),
  CASE WHEN :'ok' = 'true' AND :'detay' = 'true' AND :'n' = '2' AND :'tmi' = 't' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_listele(jsonb_build_object('tablo', 'padoklar')) AS j)
SELECT (j ->> 'ok') AS ok, (j ->> 'toplam') AS toplam FROM c \gset
INSERT INTO k3 SELECT 'S8b listele tablo filtresi', 'ok=true toplam>=3',
  format('ok=%s toplam=%s', :'ok', :'toplam'),
  CASE WHEN :'ok' = 'true' AND :'toplam'::int >= 3 THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_listele(jsonb_build_object('islem', 'D')) AS j)
SELECT (j ->> 'ok') AS ok, (j ->> 'toplam') AS toplam FROM c \gset
INSERT INTO k3 SELECT 'S8c listele işlem tipi filtresi (D)', 'ok=true toplam>=2',
  format('ok=%s toplam=%s', :'ok', :'toplam'),
  CASE WHEN :'ok' = 'true' AND :'toplam'::int >= 2 THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_listele(jsonb_build_object('baslangic', '2026-09-13', 'bitis', '2026-09-13')) AS j)
SELECT (j ->> 'ok') AS ok, (j ->> 'toplam') AS toplam FROM c \gset
INSERT INTO k3 SELECT 'S8d listele tarih aralığı (TR gün sınırı)', 'ok=true toplam>=1',
  format('ok=%s toplam=%s', :'ok', :'toplam'),
  CASE WHEN :'ok' = 'true' AND :'toplam'::int >= 1 THEN 'PASS' ELSE 'FAIL' END, '';

SELECT id AS hv FROM public.hayvanlar ORDER BY created_at DESC NULLS LAST LIMIT 1 \gset
UPDATE public.hayvanlar SET notlar = coalesce(notlar, '') || '~k3' WHERE id = :'hv'
RETURNING txid_current()::text AS t11 \gset
WITH c AS (SELECT public.degisim_listele(jsonb_build_object('hayvan_id', :'hv')) AS j)
SELECT (j ->> 'ok') AS ok, (j ->> 'toplam') AS toplam,
       coalesce(j -> 'kayitlar' -> 0 ->> 'txid', '-') AS ilktx FROM c \gset
INSERT INTO k3 SELECT 'S8e listele hayvan filtresi', 'ok=true toplam>=1 ilk txid eşleşir',
  format('ok=%s toplam=%s ilktx=%s', :'ok', :'toplam', left(coalesce(:'ilktx', '?'), 8)),
  CASE WHEN :'ok' = 'true' AND :'toplam'::int >= 1 AND :'ilktx' = :'t11' THEN 'PASS' ELSE 'FAIL' END, '';

DO $do$
DECLARE
  v_ok boolean;
BEGIN
  BEGIN
    SET LOCAL ROLE authenticated;
    v_ok := (public.degisim_listele('{}') ->> 'ok')::bool;
    RESET ROLE;
  EXCEPTION WHEN others THEN
    RESET ROLE;
    RAISE;
  END;
  INSERT INTO k3 VALUES ('S8f listele authenticated rolüyle', 'ok=true',
    CASE WHEN v_ok THEN 'ok=true' ELSE 'ok=false' END,
    CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END, '');
EXCEPTION WHEN others THEN
  INSERT INTO k3 VALUES ('S8f listele authenticated rolüyle', 'ok=true', SQLSTATE, 'FAIL', SQLERRM);
END;
$do$;

-- ══ S9: bilet çok kullanım + kullanım kayıtları ════════════════════════════
SELECT count(*) AS kn FROM surum_gizli.geri_alma_kullanim WHERE bilet = :'bilet'::uuid \gset
SELECT count(*) AS ko FROM surum_gizli.geri_alma_kullanim WHERE bilet = :'bilet'::uuid AND sonuc ->> 'ok' = 'true' \gset
INSERT INTO k3 SELECT 'S9a bilet çok kullanımlı, her deneme kayda geçer', 'kayıt>=10, başarılı>=7',
  format('kayit=%s basarili=%s', :'kn', :'ko'),
  CASE WHEN :'kn'::int >= 10 AND :'ko'::int >= 7 THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ S12: cascade-delete revert (review regression: EKLE parent-first) ══════
BEGIN;
INSERT INTO public.tedavi_sablonu (ad) VALUES ('k3-sablon')
RETURNING txid_current()::text AS t12, id AS s12 \gset
INSERT INTO public.tedavi_sablonu_kalem (sablon_id, gun_no, planned_time, dose, unit)
VALUES (:'s12', 1, '09:00', 1, 'ml') RETURNING txid_current()::text AS t12b \gset
COMMIT;
BEGIN;
DELETE FROM public.tedavi_sablonu WHERE id = :'s12'
RETURNING txid_current()::text AS t13 \gset
COMMIT;

WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('txid', :'t13'), 'islem') AS j)
SELECT (j ->> 'ok') AS ok, jsonb_array_length(j -> 'plan') AS pn,
       (j -> 'plan' -> 0 ->> 'tablo') AS ilk, (j -> 'plan' -> 1 ->> 'tablo') AS ikinci,
       (j ->> 'geri_alinabilir') AS ga FROM c \gset
INSERT INTO k3 SELECT 'S12a cascade silme önizleme: EKLE anne önce (topolojik)',
  'ok=true plan=2 ilk=tedavi_sablonu ikinci=tedavi_sablonu_kalem ga=true',
  format('ok=%s plan=%s ilk=%s ikinci=%s ga=%s', :'ok', :'pn', :'ilk', :'ikinci', :'ga'),
  CASE WHEN :'ok' = 'true' AND :'pn' = '2' AND :'ilk' = 'tedavi_sablonu'
        AND :'ikinci' = 'tedavi_sablonu_kalem' AND :'ga' = 'true' THEN 'PASS' ELSE 'FAIL' END, '';

WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('txid', :'t13'),
                                         'islem', :'bilet'::uuid, 'k3 S12b cascade') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim FROM c \gset
SELECT count(*) AS sn FROM public.tedavi_sablonu WHERE id = :'s12' \gset
SELECT count(*) AS kn FROM public.tedavi_sablonu_kalem WHERE sablon_id = :'s12' \gset
INSERT INTO k3 SELECT 'S12b cascade silme revert: anne+çocuk geri geldi', 'ok=true adim=2 sablon=1 kalem=1',
  coalesce(:'hat', format('ok=%s adim=%s sablon=%s kalem=%s', :'ok', :'adim', :'sn', :'kn')),
  CASE WHEN :'ok' = 'true' AND :'adim' = '2' AND :'sn' = '1' AND :'kn' = '1' THEN 'PASS' ELSE 'FAIL' END, '';

BEGIN;
DELETE FROM public.tedavi_sablonu WHERE id = :'s12'
RETURNING txid_current()::text AS t14 \gset
COMMIT;
-- önizlemede: plan 1 adım (yalnız anne) + kalan çocuk için UYARI
WITH c AS (SELECT public.degisim_onizle(jsonb_build_object('tablo', 'tedavi_sablonu', 'pk', :'s12', 'txid', :'t14'), 'satir') AS j)
SELECT (j ->> 'ok') AS ook, jsonb_array_length(j -> 'plan') AS pn,
       (SELECT count(*) FROM jsonb_array_elements(COALESCE(j -> 'bagimliliklar', '[]'::jsonb)) b
         WHERE b ->> 'etki' = 'UYARI') AS uyari FROM c \gset
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'tedavi_sablonu', 'pk', :'s12', 'txid', :'t14'),
                                         'satir', :'bilet'::uuid, 'k3 S12c kismi') AS j)
SELECT j ->> 'ok' AS ok, coalesce(j ->> 'hata', '-') AS hat, coalesce(j ->> 'uygulanan_adim', '0') AS adim FROM c \gset
SELECT count(*) AS sn FROM public.tedavi_sablonu WHERE id = :'s12' \gset
SELECT count(*) AS kn FROM public.tedavi_sablonu_kalem WHERE sablon_id = :'s12' \gset
INSERT INTO k3 SELECT 'S12c satır-seviyesi kısmi revert: kalan çocuk UYARI (engel değil)',
  'onizle plan=1 uyari>=1; revert ok=true adim=1 sablon=1 kalem=0',
  format('onizle=%s plan=%s uyari=%s | ok=%s hat=%s adim=%s sablon=%s kalem=%s',
         :'ook', :'pn', :'uyari', :'ok', :'hat', :'adim', :'sn', :'kn'),
  CASE WHEN :'ook' = 'true' AND :'pn' = '1' AND :'uyari'::int >= 1
        AND :'ok' = 'true' AND :'adim' = '1' AND :'sn' = '1' AND :'kn' = '0' THEN 'PASS' ELSE 'FAIL' END, '';
DELETE FROM public.tedavi_sablonu WHERE id = :'s12';

-- ══ S13 (LUNA-1): tam bilet degisim_log'a YAZILMAZ (maske) ══════════════════
UPDATE public.hekimler SET ad = 'k3-luna-1-maske' WHERE id = 'H2';
WITH c AS (SELECT public.degisim_geri_al(jsonb_build_object('tablo', 'hekimler', 'pk', 'H2'),
                                          'satir', :'bilet'::uuid, 'luna-1 bilet maske') AS j)
SELECT coalesce(j ->> 'ok', 'false') AS mok FROM c \gset
SELECT count(*) AS tamuuid FROM public.degisim_log
 WHERE kaynak::text LIKE '%' || :'bilet' || '%' \gset
SELECT count(*) AS maskeli FROM public.degisim_log
 WHERE kaynak -> 'geri_alma' ->> 'bilet' = left(:'bilet', 8) || '…' \gset
INSERT INTO k3 SELECT 'S13 LUNA-1: tam bilet log''a yazılmaz (ilk-8 maske)',
  'tam-uuid=0, maskeli>=1',
  format('ok=%s tam=%s maske=%s', :'mok', :'tamuuid', :'maskeli'),
  CASE WHEN :'mok' = 'true' AND :'tamuuid' = '0' AND :'maskeli'::int >= 1 THEN 'PASS' ELSE 'FAIL' END, '';

-- ══ S11: temizlik — sentetik satırlar + k3 log kayıtları + şifre sıfırlama ══
UPDATE public.hekimler SET telefon = :'h3tel', aktif = :'h3aktif'::boolean WHERE id = 'H3';
UPDATE public.hekimler SET ad = :'h2ad' WHERE id = 'H2';
DELETE FROM public.grup_padok_eslem WHERE grup LIKE 'k3-%';
DELETE FROM public.padoklar WHERE ad LIKE 'k3-%';
DELETE FROM public.tedavi_sablonu WHERE ad LIKE 'k3-%';
DELETE FROM public.stok_hareket WHERE notlar LIKE 'k3-%';
DELETE FROM public.pedigree_meta WHERE key = 'k3-composite';
UPDATE public.hayvanlar SET notlar = regexp_replace(notlar, '~k3$', '')
 WHERE id = :'hv' AND notlar LIKE '%~k3';

-- purge this script's log rows (immutable by design — operator-level cleanup
-- disables the guards, exactly the k1b red-before pattern)
ALTER TABLE public.degisim_log DISABLE TRIGGER USER;
DELETE FROM public.degisim_log WHERE kaynak ->> 'istemci_etiketi' = 'k3-geri-alma-testi';
ALTER TABLE public.degisim_log ENABLE TRIGGER USER;
-- LUNA-4: yalnız bu koşumun ürettiği gizli kayıtlar silinir; koşum öncesi
-- varolan bilet/kullanım/sahip şifresi korunur (şifre üzerine yazıldıysa
-- anlık görüntüden geri yüklenir).
DELETE FROM surum_gizli.geri_alma_kullanim
 WHERE bilet IN (SELECT bilet FROM surum_gizli.geri_alma_bileti
                  WHERE bilet NOT IN (SELECT bilet FROM k3_biletler_once));
DELETE FROM surum_gizli.geri_alma_bileti
 WHERE bilet NOT IN (SELECT bilet FROM k3_biletler_once);
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM k3_sifre_once) THEN
    UPDATE surum_gizli.sahip_sifresi SET hash = (SELECT hash FROM k3_sifre_once);
  ELSE
    DELETE FROM surum_gizli.sahip_sifresi;
  END IF;
END;
$do$;

SELECT count(*) AS oncekibilet FROM surum_gizli.geri_alma_bileti
 WHERE bilet IN (SELECT bilet FROM k3_biletler_once) \gset
SELECT count(*) AS oncekisifre FROM surum_gizli.sahip_sifresi
 WHERE hash IN (SELECT hash FROM k3_sifre_once) \gset
INSERT INTO k3 SELECT 'S11b LUNA-4: önceden varolan gizli kayıt korundu',
  format('bilet=%s sifre=%s', (SELECT count(*) FROM k3_biletler_once), (SELECT count(*) FROM k3_sifre_once)),
  format('bilet=%s sifre=%s', :'oncekibilet', :'oncekisifre'),
  CASE WHEN :'oncekibilet' = (SELECT count(*)::text FROM k3_biletler_once)
        AND :'oncekisifre' = (SELECT count(*)::text FROM k3_sifre_once)
       THEN 'PASS' ELSE 'FAIL' END, '';

SELECT count(*) AS logkalan FROM public.degisim_log
 WHERE kaynak ->> 'istemci_etiketi' = 'k3-geri-alma-testi' \gset
SELECT count(*) AS padokkalan FROM public.padoklar WHERE ad LIKE 'k3-%' \gset
SELECT count(*) AS hekimok FROM public.hekimler
 WHERE id = 'H3' AND telefon = :'h3tel' AND aktif = :'h3aktif'::boolean \gset
INSERT INTO k3 SELECT 'S11 temizlik: demo başlangıç durumuna döndü',
  'log=0 padok=0 hekim=1', format('log=%s padok=%s hekim=%s', :'logkalan', :'padokkalan', :'hekimok'),
  CASE WHEN :'logkalan' = '0' AND :'padokkalan' = '0' AND :'hekimok' = '1' THEN 'PASS' ELSE 'FAIL' END, '';

\echo '== k3 sonuç tablosu =='
SELECT vaka, beklenen, bulunan, sonuc, left(detay, 160) AS detay FROM k3 ORDER BY ctid;

\echo '== özet =='
SELECT count(*) FILTER (WHERE sonuc = 'PASS') AS pass,
       count(*) FILTER (WHERE sonuc <> 'PASS') AS fail,
       count(*) AS toplam FROM k3;
SELECT vaka, beklenen, bulunan, left(detay, 200) AS detay FROM k3 WHERE sonuc <> 'PASS';
