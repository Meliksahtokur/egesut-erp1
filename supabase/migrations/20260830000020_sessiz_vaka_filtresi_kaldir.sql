-- Migration: v_eligible — aktif vaka sürgününü kaldır
-- Tarih: 2026-08-30
-- Canlı prod view tanımı (assets/v_eligible_canli.sql) birebir alınmış, TEK fark:
-- aktif vaka sürgün filtresi (EXISTS ... status='active') çıkarıldı. Üreme takibi
-- hastalık/tedavi durumundan bağımsız çalışmalı. Kolon sırası DEĞİŞMEDİ.

CREATE OR REPLACE VIEW public.v_eligible AS
 SELECT h.id,
    h.kupe_no,
    h.grup,
    h.padok,
    son_dogum.tarih AS son_dogum_tarihi,
    CURRENT_DATE - son_dogum.tarih AS dogum_gun,
    son_aktivite.tarih AS son_aktivite_tarihi,
        CASE
            WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
            WHEN son_dogum.tarih IS NOT NULL THEN CURRENT_DATE - son_dogum.tarih
            WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
            ELSE NULL::integer
        END AS sessiz_gun
   FROM hayvanlar h
     LEFT JOIN LATERAL ( SELECT max(d.tarih) AS tarih
           FROM dogum d
          WHERE d.anne_id = h.id) son_dogum ON true
     LEFT JOIN LATERAL ( SELECT max(aktivite.tarih) AS tarih
           FROM ( SELECT tohumlama.tarih
                   FROM tohumlama
                  WHERE tohumlama.hayvan_id = h.id
                UNION ALL
                 SELECT kizginlik_log.tarih
                   FROM kizginlik_log
                  WHERE kizginlik_log.hayvan_id = h.id) aktivite) son_aktivite ON true
  WHERE h.cinsiyet = 'Dişi'::text AND h.durum = 'Aktif'::text AND h.kisir IS NOT TRUE AND h.grup !~~* '%buzağı%'::text AND h.grup !~~* '%buzagi%'::text AND h.grup !~~* '%Küçük%'::text AND h.grup !~~* '%Kucuk%'::text AND (h.dogum_tarihi IS NULL OR h.dogum_tarihi <= (CURRENT_DATE - '1 year 1 mon'::interval)) AND NOT (EXISTS ( SELECT 1
           FROM tohumlama t
          WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'::text)) AND (son_dogum.tarih IS NULL OR son_dogum.tarih < (CURRENT_DATE - 55));

NOTIFY pgrst, 'reload schema';
