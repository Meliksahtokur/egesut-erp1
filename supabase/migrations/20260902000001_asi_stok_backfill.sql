-- 20260902000001_asi_stok_backfill.sql
-- Coglavax / Vac-Sules Feedlot katalog aşılarına stok kalemi + vaccines.stock_item_id bağlantısı
-- (2026-09-02 kullanıcı onayı — gorev-asi-akisi fix'inin kök veri adımı)
--
-- Bağlam: 20260619000012_asi_seed_backfill.sql katalog satırlarını ekledi ama stok kalemi
-- yaratmadı → stock_item_id NULL kalınca vaccination_stok_dusum trigger'ı bu aşılar için
-- stok düşümünü sessizce atlıyordu ("Ledger kaydı yapmadan geç").
--
-- SONUÇ DAVRANIŞI DEĞİŞİR: bağlantı sonrası bu aşıların uygulamaları da stokla sınırlanır
-- (guncel < doz → 'Yetersiz stok' EXCEPTION — diğer 10 katalog aşısıyla aynı mevcut kontrat).
-- Başlangıç stoku bilinçli 0: kullanıcı Stok Girişi ile elle girecek; stok_ekleme negatif
-- stok_hareket yazar ve trigger'ın guncel formülünde stok artar.
--
-- Idempotent: tekrar koşum güvenli (INSERT koşullu, UPDATE yalnız NULL alanı doldurur).

INSERT INTO public.stok (id, urun_adi, birim, baslangic_miktar, esik, kategori)
SELECT 'STOK-AŞI-' || v.id, v.name, COALESCE(v.unit, 'ml'), 0, 0, 'Aşı'
FROM public.vaccines v
WHERE v.name IN ('Coglavax', 'Vac-Sules Feedlot')
  AND v.stock_item_id IS NULL
ON CONFLICT (id) DO NOTHING;

UPDATE public.vaccines v
SET stock_item_id = 'STOK-AŞI-' || v.id
WHERE v.name IN ('Coglavax', 'Vac-Sules Feedlot')
  AND v.stock_item_id IS NULL
  AND EXISTS (SELECT 1 FROM public.stok s WHERE s.id = 'STOK-AŞI-' || v.id);
