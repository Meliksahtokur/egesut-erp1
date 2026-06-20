-- Backfill: grup 'Sütten Kesilmiş Buzağı' ama suttten_kesme_tarihi NULL olan ~9 aktif buzağı
-- Tahmini tarih: islem_log GOREV_TAMAMLA → yoksa dogum+esik; gelecekse bugüne clamp
-- UPDATE trigger'ı tetikler: padok/grup normalize + açık görev/instance kapanışı
BEGIN;

UPDATE public.hayvanlar h
SET suttten_kesme_tarihi = LEAST(
  COALESCE((SELECT max(tarih)::date FROM public.islem_log l
             WHERE l.ana_hayvan_id=h.id AND l.tip='GOREV_TAMAMLA'),
           h.dogum_tarihi + public._ayar('sutten_kesme_gun',60)::int),
  CURRENT_DATE)
WHERE h.durum='Aktif' AND h.grup='Sütten Kesilmiş Buzağı' AND h.suttten_kesme_tarihi IS NULL
  AND h.dogum_tarihi IS NOT NULL;

-- audit
INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
SELECT 'SUTEN_KESME', h.id, h.id, 'hayvanlar',
  jsonb_build_object('olusturulan','[]'::jsonb,'silinen','[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object('tablo','hayvanlar','id',h.id,
      'sonraki', jsonb_build_object('suttten_kesme_tarihi', h.suttten_kesme_tarihi)))),
  'Backfill — tahmini tarih, doğrulanmalı'
FROM public.hayvanlar h
WHERE h.durum='Aktif' AND h.grup='Sütten Kesilmiş Buzağı'
  AND h.suttten_kesme_tarihi IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.islem_log l WHERE l.ana_hayvan_id=h.id AND l.tip='SUTEN_KESME');
COMMIT;
