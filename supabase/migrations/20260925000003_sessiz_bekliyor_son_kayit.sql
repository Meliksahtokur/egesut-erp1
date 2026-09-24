-- ════════════════════════════════════════════════════════════════════
-- S2-ONARIM (final review ORTA bulgusu) — v_eligible 'Bekliyor tam hariç'
-- filtresi SON-TOHUMLAMA bazına alınır.
-- Tarih: 2026-09-25 · Spec: docs/plans/2026-09-24-ovsync-cila/spec-s2.md
--
-- SORUN (final review, canlı demo vakalı):
--   S2 migration'ındaki 'Bekliyor tam hariç' filtresi HERHANGİ bir 'Bekliyor'
--   tohumlama satırına bakıyordu (NOT EXISTS t.sonuc='Bekliyor'). Hiç
--   sonuçlanmamış bayat bir 'Bekliyor' satırı, hayvanın sonraki tohumlamaları
--   'Boş'/'Abort'/'Doğum Yaptı' olsa bile hayvanı sessiz havuzundan kalıcı
--   çıkarıyordu. gebelik_muayene_listele/_uret ise yalnız SON tohumlamaya
--   baktığından (ORDER BY tarih DESC, created_at DESC LIMIT 1) aynı hayvan iki
--   akışın da kesişiminde tutarsız düşüyordu. Canlı demo vakası: 'Test inek 3'
--   (2026-01-01 'Bekliyor', 2026-06-06 'Doğum Yaptı' — yalnız Bekliyor-filtresi
--   dışarıda bırakıyordu).
--
-- FIX: filtre, gebelik_muayene RPC'lerindeki otorite sorgusuyla AYNI
--   son-tohumlama alt-sorgusuna bağlanır (tarih DESC, created_at DESC, LIMIT 1).
--   Sonuç hiç yoksa ('' COALESCE) hayvan havuzda KALIR — kapsamın sahibi
--   "yalnız Boş + durumu-bilinmeyen" kararının 'bilinmeyen' bacağı budur.
--
-- DOKUNULMADI (bilinçli):
--   · 'Gebe' any-record filtresi ön-existing ana-davranışıdır (20260831000002);
--     bu turda değişmedi — muayene RPC'leriyle hizalaması ayrı kayıt (BUGS.md).
--   · eşik 50, Bekliyor muafiyet penceresi seed'i, dört RPC, ACL — değişmez.
--
-- KANAL: yalnız DEMO (sahip onaylı); prod ayrı sahip kapısıdır.
-- anon GRANT YAZILMAZ (kural); bu migration GRANT/REVOKE taşımaz.
-- ROLLBACK: v_eligible'ı 20260925000002:41-76 tanımına (NOT EXISTS'li) döndür.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE VIEW public.v_eligible AS
SELECT h.id,
       h.kupe_no,
       h.grup,
       h.padok,
       son_dogum.tarih AS son_dogum_tarihi,
       CURRENT_DATE - son_dogum.tarih AS dogum_gun,
       son_event.tarih AS son_aktivite_tarihi,
       CASE
           WHEN son_event.tarih IS NOT NULL THEN CURRENT_DATE - son_event.tarih
           WHEN son_dogum.tarih IS NOT NULL THEN CURRENT_DATE - son_dogum.tarih
           WHEN h.dogum_tarihi IS NOT NULL THEN GREATEST(0, CURRENT_DATE - ((h.dogum_tarihi + INTERVAL '1 year 1 mon')::date))
           ELSE NULL::integer
       END AS sessiz_gun
FROM hayvanlar h
LEFT JOIN LATERAL (SELECT max(d.tarih) AS tarih FROM dogum d WHERE d.anne_id = h.id) son_dogum ON true
LEFT JOIN LATERAL (SELECT max(ev.tarih) AS tarih FROM (
       SELECT t.tarih FROM tohumlama t WHERE t.hayvan_id = h.id
       UNION ALL
       SELECT k.tarih FROM kizginlik_log k WHERE k.hayvan_id = h.id
       UNION ALL
       SELECT t.abort_tarihi FROM tohumlama t WHERE t.hayvan_id = h.id AND t.abort_tarihi IS NOT NULL
       UNION ALL
       SELECT t.dogum_tarihi FROM tohumlama t WHERE t.hayvan_id = h.id AND t.dogum_tarihi IS NOT NULL
       UNION ALL
       SELECT d.tarih FROM dogum d WHERE d.anne_id = h.id
     ) ev) son_event ON true
WHERE h.cinsiyet = 'Dişi'::text AND h.durum = 'Aktif'::text AND h.kisir IS NOT TRUE
  AND h.grup !~~* '%buzağı%' AND h.grup !~~* '%buzagi%' AND h.grup !~~* '%Küçük%' AND h.grup !~~* '%Kucuk%'
  AND (h.dogum_tarihi IS NULL OR h.dogum_tarihi <= (CURRENT_DATE - '1 year 1 mon'::interval))
  AND NOT EXISTS (SELECT 1 FROM tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'::text)
  -- S2: Bekliyor tam hariç — SON-TOHUMLAMA otoritesi (onarım fix'i): son kayıt
  -- 'Bekliyor' ise hayvan sessiz DEĞİLDİR; <40g muafiyet, ≥40g gebelik muayenesi
  -- akışı (gebelik_muayene_gorev_uret / _listele ile aynı otorite sorgusu).
  -- Eski any-record NOT EXISTS'in stale-Bekliyor kalıcı-saçımı burada biter.
  AND COALESCE((SELECT t.sonuc FROM tohumlama t WHERE t.hayvan_id = h.id
                 ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
                 LIMIT 1), '') IS DISTINCT FROM 'Bekliyor'::text
  -- S2: sessiz eşiği 55 → 50 (sahip kararı, sentez §5A)
  AND (son_event.tarih IS NULL OR son_event.tarih < (CURRENT_DATE - 50));

COMMIT;

NOTIFY pgrst, 'reload schema';

-- EOF 20260925000003
