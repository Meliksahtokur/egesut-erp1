-- 20260902000002_asi_stok_serbest_dusum.sql
-- Aşı stoku serbest düşüm: 'Yetersiz stok' kilidi kaldırıldı (2026-09-02 kullanıcı kararı)
--
-- Bağlam: vaccination_stok_dusum trigger'ı güncel stok < doz olduğunda RAISE EXCEPTION ile
-- aşı uygulamasını reddediyordu. Kullanıcı kararı: ilaç/seans/tohumlama akışlarıyla aynı
-- serbest davranışa geçsin — aşı stoku eksiye düşebilsin, uygulama asla stok yüzünden
-- engellenmesin. Ledger kaydı (stok_hareket) aynen devam eder; net stok eksi gösterir.
--
-- Değişiklik tek satırlık: guard bloğu (v_guncel hesabı + RAISE EXCEPTION) ve artık
-- kullanılmayan v_guncel değişkeni kaldırıldı. Idempotent — CREATE OR REPLACE.
-- Not: add_vaccination / ileri_gebe_asi_tamamla bu trigger üzerinden düşüm yaptığı için
-- ek RPC değişikliği gerekmez.

CREATE OR REPLACE FUNCTION public.vaccination_stok_dusum()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_stok_id      text;
  v_vaccine_name text;
  v_kupe_no      text;
BEGIN
  -- Aşının stok bağlantısını kontrol et
  SELECT v.stock_item_id, v.name
  INTO   v_stok_id, v_vaccine_name
  FROM   public.vaccines v
  WHERE  v.id = NEW.vaccine_id;

  -- Stok bağlantısı yoksa ledger kaydı yapmadan geç
  IF v_stok_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Hayvan küpe no'sunu bul (notlar için)
  SELECT kupe_no INTO v_kupe_no
  FROM   public.hayvanlar
  WHERE  id = NEW.animal_id;

  -- Ledger: pozitif = kullanım. Serbest düşüm — net stok eksiye düşebilir
  -- (kullanıcı kararı 2026-09-02: ilaç/seans akışlarıyla uyum, uygulama engellenmez).
  INSERT INTO public.stok_hareket (
    stok_id, tur, miktar, notlar, iptal,
    referans_tipi, referans_id
  ) VALUES (
    v_stok_id,
    'Aşı',
    NEW.dose_given,
    v_vaccine_name || ' — ' || COALESCE(v_kupe_no, NEW.animal_id),
    false,
    'vaccination',
    NEW.id::text
  );

  RETURN NEW;
END;
$function$;
