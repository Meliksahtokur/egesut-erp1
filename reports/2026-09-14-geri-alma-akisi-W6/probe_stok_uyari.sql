-- W6 probe_stok_uyari — DEMO canlı yoklama (ROLLBACK-tabanlı; İZ BIRAKMAZ).
-- 20260914000004 uygulandıktan SONRA koşulur. Sentetik degisim_log satırları
-- tek tx içinde yazılır ve ROLLBACK ile geri alınır (tabloya kalıcı satır yok).
--
-- Ölçer (0004 sonrası sözleşme):
--   W6-A  aynı-tx döngüsü: metin temiz (txid parçası YOK, UUID YOK);
--         hareket_id AYRI alanda.
--   W6-B  bağlı-stok döngüsü: metin temiz; txid AYRI alanda (hareket tx'i).
--   W6-C  ok:true + stok_uyari üretilir (probe'un kendisi sağlam).
--
-- NOT: _l4_zincir'in stok döngüsü aynı satırların birebir kopyasıdır
-- (tests/unit/l4-stok-uyari-txid.test.js byte-eşitliği pinler); burada
-- ayrıca koşulmaz — probe'un kapsamı _degisim_plan'ın iki uyarı yoludur.
--
-- Koşum: psql "$DEMO_DSN" -v ON_ERROR_STOP=1 -f reports/2026-09-14-geri-alma-akisi-W6/probe_stok_uyari.sql

BEGIN;

-- Sentetik veri: üç ayrı "tx" (sabit bigint txid; probe tek gerçek tx'te koşar)
--   990001: T1 tohumlama U + S1 stok_hareket I (referans_id BAŞKA kayıt → plana girmez)
--   990002: T2 tohumlama U (hedef-1)
--   990003: S2 stok_hareket I (referans_id = T2 → 990002 planına bağlı-stok uyarısı)
INSERT INTO public.degisim_log
  (txid, kayit_zamani, tablo_adi, satir_pk, islem, eski, yeni, degisen_alanlar, kaynak)
VALUES
  (990001, now() - interval '3 min', 'tohumlama',
   jsonb_build_object('id', 'w6-probe-t1'), 'U',
   jsonb_build_object('id', 'w6-probe-t1', 'notlar', 'eski'),
   jsonb_build_object('id', 'w6-probe-t1', 'notlar', 'yeni'),
   ARRAY['notlar'],
   jsonb_build_object('app_name', 'egesut-web', 'probe', 'w6')),
  (990001, now() - interval '3 min', 'stok_hareket',
   jsonb_build_object('id', 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'), 'I',
   NULL,
   jsonb_build_object('id', 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
                      'stok_id', 'stok-11111111-2222-4333-8444-555555555555',
                      'referans_id', 'w6-probe-baska-kayit'),
   NULL,
   jsonb_build_object('app_name', 'egesut-web', 'probe', 'w6')),
  (990002, now() - interval '2 min', 'tohumlama',
   jsonb_build_object('id', 'w6-probe-t2'), 'U',
   jsonb_build_object('id', 'w6-probe-t2', 'notlar', 'eski'),
   jsonb_build_object('id', 'w6-probe-t2', 'notlar', 'yeni'),
   ARRAY['notlar'],
   jsonb_build_object('app_name', 'egesut-web', 'probe', 'w6')),
  (990003, now() - interval '1 min', 'stok_hareket',
   jsonb_build_object('id', '99999999-8888-4777-8666-555555555555'), 'I',
   NULL,
   jsonb_build_object('id', '99999999-8888-4777-8666-555555555555',
                      'stok_id', 'stok-11111111-2222-4333-8444-555555555555',
                      'referans_id', 'w6-probe-t2'),
   NULL,
   jsonb_build_object('app_name', 'egesut-web', 'probe', 'w6'));

-- W6-A: aynı-tx vaka — hedef T1 (tx 990001); S1 aynı tx'te ama plana giremez
-- (referans_id T1'e değil) → uyarı: metin TEMİZ + hareket_id AYRI alanda.
SELECT 'W6-A' AS vaka,
  (p ->> 'ok') = 'true'
  AND jsonb_array_length(p -> 'stok_uyari') = 1
  AND (p -> 'stok_uyari' -> 0 ->> 'metin') NOT LIKE '%txid%'
  AND (p -> 'stok_uyari' -> 0 ->> 'metin') !~ '[0-9a-f]{8}-[0-9a-f]{4}'
  AND (p -> 'stok_uyari' -> 0 ->> 'hareket_id') = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
  AS sonuc
FROM (SELECT surum_gizli._degisim_plan(
        jsonb_build_object('tablo', 'tohumlama', 'txid', '990001',
                           'pk', jsonb_build_object('id', 'w6-probe-t1')),
        'satir') AS p) s;

-- W6-B: bağlı-stok vaka — hedef T2 (tx 990002); S2 ayrı tx'te (990003) ve
-- referans_id T2 → uyarı: metin TEMİZ + txid AYRI alanda (S2'nin tx'i).
SELECT 'W6-B' AS vaka,
  (p ->> 'ok') = 'true'
  AND jsonb_array_length(p -> 'stok_uyari') = 1
  AND (p -> 'stok_uyari' -> 0 ->> 'metin') NOT LIKE '%txid%'
  AND (p -> 'stok_uyari' -> 0 ->> 'metin') !~ '[0-9a-f]{8}-[0-9a-f]{4}'
  AND (p -> 'stok_uyari' -> 0 ->> 'txid') = '990003'
  AS sonuc
FROM (SELECT surum_gizli._degisim_plan(
        jsonb_build_object('tablo', 'tohumlama', 'txid', '990002',
                           'pk', jsonb_build_object('id', 'w6-probe-t2')),
        'satir') AS p) s;

-- W6-C: fonksiyon tanımı sentetik veriden BAĞIMSIZ kanıt — gövdede
-- metin-parçası kalmamış olmalı (apply sonrası canlı tanım).
SELECT 'W6-C' AS vaka,
  pg_get_functiondef('surum_gizli._degisim_plan(jsonb,text)'::regprocedure) !~ '\(txid %s\)'
  AND pg_get_functiondef('surum_gizli._l4_zincir(jsonb)'::regprocedure) !~ '\(txid %s\)'
  AS sonuc;

ROLLBACK;
