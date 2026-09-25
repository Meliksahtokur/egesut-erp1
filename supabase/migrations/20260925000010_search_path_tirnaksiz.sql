-- ============================================================================
-- Migration: 20260925000010_search_path_tirnaksiz
-- Tarih: 2026-09-25 · Cila-onarım K5 (mimar incelemesi C1 + C3)
--
-- DÜZELTME NOTU: 20260925000004:25-26'daki "değer tırnaklı TEK string'tir —
-- ALTER FUNCTION SET grameri tek-değer alır; semantik CREATE FUNCTION'daki
-- list biçimiyle aynıdır" iddiası YANLIŞTIR. Tırnaklı 'public, pg_temp'
-- TEK, var olmayan "public, pg_temp" adlı şema olarak saklanır (canlı kanıt:
-- proconfig = search_path="public, pg_temp" ve current_schemas={pg_catalog},
-- mimar C1). Doğru biçim tırnaksız listedir: SET search_path = public, pg_temp
-- (CREATE ile ALTER aynı func_set gramer üretimini paylaşır). Bu migration
-- o iddiayı düzeltir; gövde değişmez, yalnızca proconfig düzelir.
--
-- Kapsam:
--   (a) protokol_ayar_guncelle(text,numeric): 000004'ün tırnaklı değeri tırnaksıza çevrilir.
--   (b) gorev_tamamla(text,text,boolean): 000006 SECDEF gövdesine SET search_path eklenir
--       (gövde tam-nitelikli, pratik risk düşük — mimar C3; ACL değişmez).
--
-- UYGULAMA BİÇİMİ NOTU: ALTER'lar varlık-guard'lı DO bloğu içinde koşar.
--   (1) sqlfluff (kapı Faz A) üst-düzey `ALTER FUNCTION ad(tipler) SET x = a, b`
--       desenini bu sürümde parse edemiyor (plpgsql gövdesi içinde sorunsuz);
--   (2) gorev_tamamla(text,text,boolean) imzası 20260925000006 ürünüdür — bu
--       migration prod sırasında 000006'dan SONRA koşar; doğrulama aynası
--       (prod-parite) 000006'yı henüz içermeyebilir. İmza yoksa NOTICE ile
--       atlanır (sessiz başarı yok), varsa statik ALTER koşar.
-- Geri alınabilir: ALTER FUNCTION ... SET search_path TO DEFAULT.
-- Anon GRANT yazılmaz; ACL'ye dokunulmaz.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $do$
BEGIN
  IF pg_catalog.to_regprocedure('public.protokol_ayar_guncelle(text, numeric)') IS NOT NULL THEN
    ALTER FUNCTION public.protokol_ayar_guncelle(text, numeric)
    SET search_path = public, pg_temp;
  ELSE
    RAISE NOTICE 'K5: protokol_ayar_guncelle(text,numeric) bu ortamda yok — ALTER atlandı';
  END IF;

  IF pg_catalog.to_regprocedure('public.gorev_tamamla(text, text, boolean)') IS NOT NULL THEN
    ALTER FUNCTION public.gorev_tamamla(text, text, boolean)
    SET search_path = public, pg_temp;
  ELSE
    RAISE NOTICE 'K5: gorev_tamamla(text,text,boolean) bu ortamda yok (000006 öncesi sıralama) — ALTER atlandı';
  END IF;
END
$do$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000010_search_path_tirnaksiz (K5)
