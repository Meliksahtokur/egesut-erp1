-- İstatistik F2 T7: motor ölçümlerini aç (Kaplan-Meier + protokol farkı); veriyi stat-motor yazar (T6).
-- Rollback: UPDATE public.stat_olcum_kayit SET aktif = false WHERE ad IN ('stat_tedavi_sagkalim','stat_tedavi_protokol_fark');
UPDATE public.stat_olcum_kayit SET aktif = true
 WHERE ad IN ('stat_tedavi_sagkalim', 'stat_tedavi_protokol_fark');
