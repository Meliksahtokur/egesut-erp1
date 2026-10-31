-- ============================================================================
-- Migration: 20261017000005_stat_ap1_emekli
-- 2026-10-17 · İstatistik Atölyesi AP1 Task 7 (spec v2 §4.7 tanım kartları, §4.9 F0-F2 nesnelerinin kaderi;
--   plan Task 7, P2, P3; ruling R-MIG (b): eski 8 migration dosyasına dokunulmaz, ileri temizlik burada).
-- Etkiler:
--   DROP (imzalı, IF EXISTS, CASCADE YOK; önce çağıranlar): stat_tedavi_ozet, stat_tedavi_protokol,
--     stat_tedavi_sure_dagilim, stat_tedavi_dislanan_dipnot (date,date,jsonb); stat_ayikla_tedavi_vaka_ozet(),
--     stat_ayikla_tedavi_vaka(uuid[]); stat_protokol_etiket(text[],integer,text); stat_filtre_dogrula(jsonb,text[]).
--     Demo kataloğunda bu 8 fonksiyona pg_depend bağımlısı yok; çağıranları yalnız birbirleri (MEASURED T7).
--   KALIR: v_stat_vaka (dondurulmuş), stat_sonuc_oku, stat_zarf_bos, stat_donem_dogrula, stat_analiz_sonuc,
--     stat_motor_kosum, rol stat_motor.
--   stat_olcum_kayit: + birim, tanim, kume (text). 3 SQL satırı silinir; 2 motor satırı aktif=false (P2);
--     5 saglik_* satırı ON CONFLICT (ad) DO UPDATE (alan saglik, tip sql, surum sql:20261017000005, sira 10..50).
--   stat_olcum_listele(): CREATE OR REPLACE — birim, tanim, kume da döner; yalnız aktif satırlar.
-- ACL: stat_olcum_listele SECURITY INVOKER + SET search_path = public, pg_temp, STABLE;
--   REVOKE ALL FROM PUBLIC, anon, authenticated; GRANT EXECUTE yalnız authenticated. anon GRANT yok.
--   stat_olcum_kayit tablo ACL'i değişmez (authenticated SELECT, stat_motor SELECT).
-- Idempotent: DROP FUNCTION IF EXISTS, ADD COLUMN IF NOT EXISTS, DELETE/UPDATE koşullu, upsert, CREATE OR REPLACE.
-- Geri alma: düşürülen 8 fonksiyon için 20261005000003..000005 + 20261006000002 gövdeleri yeniden koşulur ve
--   ölçüm satırları 20261005000005 / 20261006000003 haliyle yeniden yazılır; DELETE FROM stat_olcum_kayit
--   WHERE ad LIKE 'saglik\_%'; ALTER TABLE stat_olcum_kayit DROP COLUMN birim, tanim, kume (listele önce eski gövdeye).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. Emekli fonksiyonlar (P3; sıra: önce çağıranlar) ───────────────────────
DROP FUNCTION IF EXISTS public.stat_tedavi_ozet(date, date, jsonb);
DROP FUNCTION IF EXISTS public.stat_tedavi_protokol(date, date, jsonb);
DROP FUNCTION IF EXISTS public.stat_tedavi_sure_dagilim(date, date, jsonb);
DROP FUNCTION IF EXISTS public.stat_tedavi_dislanan_dipnot(date, date, jsonb);
DROP FUNCTION IF EXISTS public.stat_ayikla_tedavi_vaka_ozet();
DROP FUNCTION IF EXISTS public.stat_ayikla_tedavi_vaka(uuid[]);
DROP FUNCTION IF EXISTS public.stat_protokol_etiket(text[], integer, text);
DROP FUNCTION IF EXISTS public.stat_filtre_dogrula(jsonb, text[]);

-- ── 2. Tanım kartı kolonları (spec §4.7) ────────────────────────────────────
ALTER TABLE public.stat_olcum_kayit
  ADD COLUMN IF NOT EXISTS birim text,
  ADD COLUMN IF NOT EXISTS tanim text,
  ADD COLUMN IF NOT EXISTS kume  text;

COMMENT ON COLUMN public.stat_olcum_kayit.birim IS 'Tanım kartı: değerin birimi (%, gün, ₺).';
COMMENT ON COLUMN public.stat_olcum_kayit.tanim IS 'Tanım kartı: ölçünün tek paragraf Türkçe tanımı (ekranda "Tanım" satırı).';
COMMENT ON COLUMN public.stat_olcum_kayit.kume  IS 'Tanım kartı: hesaba hangi vakaların girdiği.';

-- ── 3. Kayıt satırları (P2) ─────────────────────────────────────────────────
DELETE FROM public.stat_olcum_kayit
 WHERE ad IN ('stat_tedavi_ozet', 'stat_tedavi_protokol', 'stat_tedavi_sure_dagilim');

UPDATE public.stat_olcum_kayit SET aktif = false
 WHERE ad IN ('stat_tedavi_sagkalim', 'stat_tedavi_protokol_fark') AND aktif IS NOT FALSE;

INSERT INTO public.stat_olcum_kayit (ad, alan, baslik, birim, sira, kume, tanim, tip, surum, aktif)
SELECT v.ad, 'saglik', v.baslik, v.birim, v.sira, v.kume, v.tanim, 'sql', 'sql:20261017000005', true
FROM (VALUES
  ('saglik_basari', 'Başarı oranı', '%', 10,
   'Sonuçlanmış vakalar; kapanıştan 30 gün dolmamış ve olay görülmemiş vakalar hariç.',
   'Başarı: vaka kapandı, kapanıştan sonra 30 gün içinde hayvan ölmedi ya da kesilmedi ve aynı hastalık 30 gün içinde yeniden açılmadı. Kapanıştan sonra 24 saat içinde aynı hastalık için yeni vaka açılırsa tedavi değişti sayılır ve vaka başarısızdır. Vaka açıkken ölen ya da kesilen hayvanın vakası başarısız sayılır. Oranın yanında %95 Wilson aralığı verilir; 5''ten az vakada sonuç gösterilmez.'),
  ('saglik_kapanma_gunu', 'Kapanma hızı', 'gün', 20,
   'Kapanmış vakalar (başarısız ve 30 günü dolmamış dahil); 24 saat içinde yeniden açılan (tedavi değişti) vakalar hariç.',
   'Vaka açılışından kapanışına kadar geçen gün; medyan ve çeyrekler (Q1–Q3) verilir. Toplu kapatılmış vakada kapanış günü son ilaç günü + normal vakalarda ölçülen gecikme ile tahmin edilir. Açık vakalar hesaba girmez. Kapanıştan sonra 24 saat içinde aynı hastalık için yeni vaka açıldıysa vaka bu ölçüye girmez.'),
  ('saglik_tedavi_suresi', 'Tedavi süresi', 'gün', 30,
   'İlaç uygulanmış, sonuçlanmış vakalar.',
   'İlk ve son ilaç uygulaması arasındaki gün sayısı (iki uç dahil); vaka süresinden farklıdır. Medyan ve çeyrekler verilir.'),
  ('saglik_vaka_tl', 'Vaka başı ₺', '₺', 40,
   'İlaç uygulanmış, sonuçlanmış ve ilaç fiyatı bilinen vakalar.',
   'Vakada uygulanan ilaç miktarı × birim fiyat toplamı; medyan ve çeyrekler verilir. Fiyatı bilinmeyen tek bir uygulama varsa vaka hesaba girmez. İlaç uygulanmamış vaka hesaba girmez. Elle girilen fiyat geçicidir, kaydedilmez.'),
  ('saglik_basari_tl', 'Başarı başına ₺', '₺', 50,
   'Başarı oranına giren, ilaç uygulanmış ve ilaç fiyatı bilinen vakalar.',
   'Bu vakaların toplam ilaç maliyeti bölü ilaç fiyatı bilinen başarılı vaka sayısı. İlaç uygulanmamış vaka hesaba girmez. Fiyatı bilinen başarılı vaka 5''ten azsa gösterilmez.')
) AS v(ad, baslik, birim, sira, kume, tanim)
ON CONFLICT (ad) DO UPDATE
   SET alan = EXCLUDED.alan, baslik = EXCLUDED.baslik, birim = EXCLUDED.birim, sira = EXCLUDED.sira,
       kume = EXCLUDED.kume, tanim = EXCLUDED.tanim, tip = EXCLUDED.tip, surum = EXCLUDED.surum,
       aktif = EXCLUDED.aktif;

-- ── 4. stat_olcum_listele (tanım kartı alanlarıyla) ─────────────────────────
CREATE OR REPLACE FUNCTION public.stat_olcum_listele()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'ad', k.ad, 'alan', k.alan, 'baslik', k.baslik, 'aciklama', k.aciklama,
           'tip', k.tip, 'surum', k.surum, 'birim', k.birim, 'tanim', k.tanim, 'kume', k.kume)
           ORDER BY k.sira, k.ad), '[]'::jsonb)
  FROM public.stat_olcum_kayit k
  WHERE k.farm_id = public.current_farm_id() AND k.aktif IS TRUE;
$$;

COMMENT ON FUNCTION public.stat_olcum_listele() IS
  'Aktif ölçüm kayıtları (tanım kartları, spec §4.7): ad, alan, baslik, aciklama, tip, surum, birim, tanim, kume; '
  'sira, ad sırasıyla.';

REVOKE ALL ON FUNCTION public.stat_olcum_listele() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_olcum_listele() TO authenticated;

COMMIT;
