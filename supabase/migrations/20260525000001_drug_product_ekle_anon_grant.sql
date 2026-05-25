-- Fix: drug_product_ekle RPC anon role'e açılıyor
-- Sorun: Yalnızca authenticated'e GRANT edilmişti, app anon key kullandığı için
--        stok_ekle başarıyla geçiyordu ama drug_product_ekle permission denied veriyordu.

GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID)
  TO anon;
