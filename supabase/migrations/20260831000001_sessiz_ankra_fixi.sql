-- Migration: v_eligible sessiz ankraj fixi — son event artık max(kızgınlık, tohumlama, abort_tarihi, dogum_tarihi(tohumlama), dogum tablosu); doğum/abort sonrası inek eski tohumlamadan sayılmaz
-- Tarih: 2026-08-31

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
           WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
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
  AND (son_event.tarih IS NULL OR son_event.tarih < (CURRENT_DATE - 55));
