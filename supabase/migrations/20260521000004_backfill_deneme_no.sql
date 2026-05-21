-- Migration: Mevcut tohumlama kayıtlarının deneme_no backfill
-- Sorun: Eski trigger MAX(deneme_no)+1 kullandığı için kayıtlar INSERT sırasına
--        göre numara aldı. Toplu veri girişinde ters sıra → yanlış numaralar.
-- Çözüm: Tüm mevcut kayıtları tarih sırasıyla, per-cycle (doğum/abort sonrası
--        sıfırlanır) olarak yeniden numaralandır.
-- Etki: Sadece tohumlama.deneme_no kolonu güncellenir. Başka tablo/kolon etkilenmez.
-- Geri alınabilir: evet — eski değerler zaten yanlış, istenen değer 1-N kronolojik

BEGIN;

WITH cycle_boundaries AS (
  -- Her kayıt için: o kayıttan önce o hayvanda son 'Doğum Yaptı' veya 'Abort' tarihi
  -- Yoksa '1900-01-01' (hayvanın tüm geçmişi tek döngü sayılır)
  SELECT
    id,
    hayvan_id,
    tarih,
    COALESCE(
      (SELECT MAX(t2.tarih)
       FROM public.tohumlama t2
       WHERE t2.hayvan_id = t.hayvan_id
         AND t2.sonuc IN ('Doğum Yaptı', 'Abort')
         AND t2.tarih < t.tarih),
      '1900-01-01'::date
    ) AS cycle_start
  FROM public.tohumlama t
),
ranked AS (
  -- Aynı döngü içinde tarih sırasına göre numara ver (eşit tarihte id ile ayırt)
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY hayvan_id, cycle_start
      ORDER BY tarih ASC, id ASC
    ) AS new_deneme_no
  FROM cycle_boundaries
)
UPDATE public.tohumlama t
SET deneme_no = r.new_deneme_no::integer
FROM ranked r
WHERE t.id = r.id
  AND t.deneme_no IS DISTINCT FROM r.new_deneme_no::integer;

COMMIT;
