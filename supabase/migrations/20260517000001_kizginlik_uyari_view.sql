-- Kızgınlık Uyarı Sistemi — View + GRANT
-- ==========================================
-- Problem: Kızgınlık kaydı girilen hayvanların 12s içinde tohumlanıp
--          tohumlanmadığı takip edilemiyor.
-- Çözüm:  cozulmemis_kizginlik_view + frontend uyarı şeridi
--
-- Prensipler:
--   - İş mantığı backend'de (view), frontend sadece render + toggle
--   - DISTINCT ON (hayvan_id): aynı hayvanın en güncel kızgınlığı baz alınır
--   - Mevcut RPC'ler değişmez (kizginlik_kaydet, tohumlama_kaydet)
--   - Idempotent: tekrar çalıştırılabilir

BEGIN;

-- ==========================================
-- 1. Güvenlik: tohumlama.created_at (idempotent)
-- ==========================================
-- CI ground truth (.github/20260310000013_ground_truth.sql:30) zaten eklemiş
-- olabilir. IF NOT EXISTS sayesinde tekrar çalıştırma sorunsuz.
ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- ==========================================
-- 2. View
-- ==========================================
CREATE OR REPLACE VIEW public.cozulmemis_kizginlik_view AS
SELECT DISTINCT ON (kl.hayvan_id)
  kl.id AS kizginlik_id,
  kl.hayvan_id,
  h.kupe_no,
  h.padok,
  h.grup,
  kl.tarih AS kizginlik_tarihi,
  kl.olusturma AS kizginlik_zamani,
  kl.belirti,
  EXTRACT(EPOCH FROM (NOW() - kl.olusturma))/3600 AS gecen_saat,
  CASE
    WHEN kl.cozuldu = true THEN 'cozuldu'
    WHEN EXISTS (
      SELECT 1 FROM tohumlama t
      WHERE t.hayvan_id = kl.hayvan_id
        AND COALESCE(t.created_at, t.tarih::timestamptz) >= kl.olusturma
        AND COALESCE(t.created_at, t.tarih::timestamptz) < kl.olusturma + INTERVAL '12 hours'
    ) THEN 'cozuldu'
    WHEN EXTRACT(EPOCH FROM (NOW() - kl.olusturma))/3600 > 24 THEN 'bekleniyor'
    WHEN EXTRACT(EPOCH FROM (NOW() - kl.olusturma))/3600 > 12 THEN 'uyari'
    ELSE 'izleniyor'
  END AS durum
FROM kizginlik_log kl
JOIN hayvanlar h ON h.id = kl.hayvan_id AND h.durum = 'Aktif'
WHERE kl.olusturma >= NOW() - INTERVAL '3 days'
ORDER BY kl.hayvan_id, kl.olusturma DESC;

-- ==========================================
-- 3. GRANT — frontend anon key ile sorgulayacak
-- ==========================================
GRANT SELECT ON public.cozulmemis_kizginlik_view TO anon, authenticated;

COMMIT;
