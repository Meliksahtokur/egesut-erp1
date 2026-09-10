-- 20260910000003_gebelik_kaydet_manual_42804_fix.sql
-- BUG-003: gebelik_kaydet_manual canlıda SQLSTATE 42804 ile kırık (2026-09-10).
-- 🤰 Gebelik Ekle modalı (js/forms.js:3602) canlıda kullanılamıyor; bilinen
-- workaround tohumlama + islem_log doğrudan INSERT.
--
-- Kök neden (canlı ölçüm, 2026-09-10): canlıda public.tohumlama.id **uuid**
-- iken gövde `v_tohumlama_id text` bildirip `gen_random_uuid()::text` atıyor.
-- INSERT'te text → uuid ataması 42804 üretiyor:
--   ERROR: column "id" is of type uuid but expression is of type text
--   (PL/pgSQL function gebelik_kaydet_manual(text,date,text) line 28)
--
-- Düzeltme (minimal tür mekanizması, davranış değişmez) — kardeş fonksiyon
-- tohumlama_kaydet'in canlı idiom'una hizalı (v_toh_id uuid := gen_random_uuid()):
--   1. `v_tohumlama_id text`                → `v_tohumlama_id uuid`
--   2. `:= gen_random_uuid()::text`         → `:= gen_random_uuid()`
--   3. snapshot `'id', v_tohumlama_id`      → `'id', v_tohumlama_id::text`
--      (snapshot JSON çıktısı önceki amaçlanan text formuyla aynı kalır)
-- JS tüketimi etkilenmez: js/forms.js:3602 dönüş değerini kullanmıyor;
-- tohumlama_id JSON'da string olarak serileşir.
--
-- Gövde canlıdan (pg_get_functiondef, 2026-09-10) kelimesi kelimesine alınmış,
-- yalnız yukarıdaki 3 nokta değiştirildi. Idempotent — CREATE OR REPLACE
-- (aditif; DROP yok, ACL/owner korunur). Not: bilinen drift — tracked ground
-- truth tohumlama.id'yi text gösteriyor; canlı otoritedir (BUGS.md SMELL-003).
-- PROD deploy ayrı kapıdır (owner).

CREATE OR REPLACE FUNCTION public.gebelik_kaydet_manual(
  p_hayvan_id text,
  p_tarih date,
  p_sperma text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $gebelik_fix$
DECLARE
  v_hayvan record;
  v_tohumlama_id uuid;
  v_snapshot jsonb;
  v_deneme integer;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;
  IF v_hayvan.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RAISE EXCEPTION 'Sadece dişi hayvanlara gebelik kaydedilebilir';
  END IF;
  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'İleri tarih girilemez: %', p_tarih;
  END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RAISE EXCEPTION 'Hayvanın aktif gebeliği bulunuyor';
  END IF;

  v_tohumlama_id := gen_random_uuid();

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, deneme_no)
  VALUES (v_tohumlama_id, p_hayvan_id, p_tarih, p_sperma, 'Gebe', v_deneme);

  v_snapshot := jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'tohumlama', 'id', v_tohumlama_id::text,
      'veri', jsonb_build_object(
        'hayvan_id', p_hayvan_id, 'tarih', p_tarih,
        'sperma', p_sperma, 'sonuc', 'Gebe', 'deneme_no', v_deneme
      )
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('GEBELIK_MANUEL', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot,
    format('Manuel gebelik kaydı (tarih: %s, sperma: %s)', p_tarih, COALESCE(p_sperma, '-')));

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_tohumlama_id);
END;
$gebelik_fix$;
