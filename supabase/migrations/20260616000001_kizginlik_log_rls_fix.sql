-- ════════════════════════════════════════════════════════════
-- BUG FIX: kizginlik_log tablosunda authenticated policy eksik
--
-- Tarih:      2026-06-16
-- Kök neden:  kizginlik_log tablosunda sadece {anon} role'ü
--             için RLS policy tanımlıydı:
--               - anon select kizginlik_log  (SELECT)
--               - anon insert kizginlik_log  (INSERT)
--             authenticated user'lar GRANT SELECT/UPDATE/INSERT/
--             DELETE sahip olmasına rağmen RLS policy olmadığı
--             için DEFAULT DENY alıyordu.
--             Sonuç: pullTables boş array alıyor, IndexedDB'ye
--             hiç kayıt yazılmıyordu, Üreme → Kızgınlık tab'ı
--             "Kızgınlık kaydı yok" gösteriyordu.
--
--             Diğer tablolarda (dogum, stok_hareket, tohumlama,
--             hayvanlar...) hem "anon_*" hem de "allow all to
--             public" policy'si vardı — bu yüzden çalışıyorlardı.
--
--             ground_truth.sql (canonical) da bu policy'yi
--             içermiyordu → regen bug'ı.
--
-- Düzeltme:   {public} role'ü için "allow all" policy ekle.
--             Mevcut anon policy'leri dokunulmaz (anon erişim
--             aynen korunur, anon GRANT'lar zaten migration
--             20260614000007 ile kaldırıldığı için etkisiz).
-- ════════════════════════════════════════════════════════════

CREATE POLICY "allow all" ON public.kizginlik_log
  AS PERMISSIVE FOR ALL TO public
  USING (true) WITH CHECK (true);
