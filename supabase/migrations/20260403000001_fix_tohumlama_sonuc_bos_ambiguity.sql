-- Migration: tohumlama_sonuc_bos ambiguity fix
-- Sorun: İki farklı imzalı fonksiyon tanımlı, PostgreSQL hangisini çağıracağını bilemiyor
-- Çözüm: Eski tek parametreli imzayı DROP et, yeni imza (DEFAULT NULL ile) kalsın
-- Geri alınabilir: evet — eski migration'dan tek param imzayı yeniden ekle

DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text);

-- Yeni imza zaten migration 0330'dan var, yeniden oluşturmaya gerek yok
-- Doğrulama:
-- SELECT proname, pronargs FROM pg_proc WHERE proname = 'tohumlama_sonuc_bos';
-- 1 satır dönmeli: pronargs = 2