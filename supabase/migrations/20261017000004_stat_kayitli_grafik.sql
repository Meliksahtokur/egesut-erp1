-- ============================================================================
-- Migration: 20261017000004_stat_kayitli_grafik
-- 2026-10-17 · İstatistik Atölyesi AP1 Task 6 (spec v2 §4.7 kaydedilen grafik modeli, §4.5 RPC'ler, AK-11;
--   plan Task 6, Review Focus 3: geçici fiyat cümleye girmez).
-- Etkiler: YENİ tenant-scoped tablo stat_kayitli_grafik (+ (farm_id, sira) index + RLS + ACL);
--   YENİ fonksiyonlar stat_grafik_listele(), stat_grafik_kaydet(uuid,text,jsonb), stat_grafik_sil(uuid),
--   stat_grafik_sirala(uuid[]). Okur: stat_cumle_dogrula (20261017000002), current_farm_id(), auth.uid().
--   Kaydedilen şey cümledir, sonuç değil; `gecici` anahtarı stat_cumle_dogrula'da bilinmeyen anahtar → RAISE.
-- farm_id: domain-rules §14 — NOT NULL DEFAULT REAL_FARM_ID, FK YOK, policy USING(true) (Faz 2'de flip);
--   yazma fonksiyonları farm_id = current_farm_id() damgalar, okuma/güncelleme/silme/sıralama aynı süzgeçle.
-- ACL: tablo REVOKE ALL FROM PUBLIC, anon, authenticated; GRANT SELECT, INSERT, UPDATE, DELETE TO authenticated.
--   Fonksiyonlar SECURITY INVOKER + SET search_path = public, pg_temp; listele STABLE, diğerleri VOLATILE;
--   REVOKE ALL FROM PUBLIC, anon, authenticated; GRANT EXECUTE yalnız authenticated. anon GRANT yok.
-- Hata sözleşmesi: cümle → STAT_CUMLE:<yol>:<neden> (P13); kayıt yok → STAT_GRAFIK:yok; sıralama dizisi çiftliğin
--   tam ve tekrarsız kümesi değil → STAT_GRAFIK:sira_kumesi; başlık → tablo CHECK / NOT NULL.
-- Statik kapı notu (T3/T4 dersi): küme-dönen yerleşik fonksiyonlar FROM'da pg_catalog. önekiyle.
-- Idempotent: CREATE TABLE/INDEX IF NOT EXISTS, DROP POLICY IF EXISTS, CREATE OR REPLACE FUNCTION + REVOKE/GRANT.
-- Geri alma: DROP FUNCTION stat_grafik_sirala(uuid[]), stat_grafik_sil(uuid), stat_grafik_kaydet(uuid,text,jsonb),
--   stat_grafik_listele(); DROP TABLE stat_kayitli_grafik (kayıtlı grafikler kaybolur).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. Tablo (spec §4.7) ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stat_kayitli_grafik (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id       uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  baslik        text NOT NULL CHECK (length(btrim(baslik)) BETWEEN 1 AND 120),
  cumle         jsonb NOT NULL,
  cumle_surum   int NOT NULL,
  sira          int NOT NULL,
  olusturan     uuid DEFAULT auth.uid(),
  olusturma_at  timestamptz NOT NULL DEFAULT now(),
  guncelleme_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS stat_kayitli_grafik_farm_sira_idx ON public.stat_kayitli_grafik (farm_id, sira);

COMMENT ON TABLE public.stat_kayitli_grafik IS
  'İstatistik Atölyesi panosu (spec §4.7): kaydedilen şey cümledir (§4.4 şeması, stat_cumle_dogrula), sonuç değil; '
  'geçici fiyat saklanmaz. Çiftlik geneli, sahip-kullanıcı ayrımı yok. Uygulama yazmayı stat_grafik_* RPC''leriyle yapar; '
  'zorlanmaz (INVOKER için tablo DML GRANT''ı gerekli; domain §14 USING(true), Faz 2 RLS flip).';

ALTER TABLE public.stat_kayitli_grafik ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS stat_kayitli_grafik_all ON public.stat_kayitli_grafik;
CREATE POLICY stat_kayitli_grafik_all ON public.stat_kayitli_grafik FOR ALL USING (true) WITH CHECK (true);

REVOKE ALL ON TABLE public.stat_kayitli_grafik FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stat_kayitli_grafik TO authenticated;

-- ── 2. Listele ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_grafik_listele()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id', g.id, 'baslik', g.baslik, 'cumle', g.cumle,
                                               'cumle_surum', g.cumle_surum, 'sira', g.sira,
                                               'guncelleme_at', g.guncelleme_at)
                            ORDER BY g.sira, g.olusturma_at, g.id), '[]'::jsonb)
    FROM public.stat_kayitli_grafik g
   WHERE g.farm_id = public.current_farm_id();
$$;

-- ── 3. Kaydet (ekle / güncelle) ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_grafik_kaydet(p_id uuid, p_baslik text, p_cumle jsonb)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_farm uuid := public.current_farm_id();
  v_id uuid;
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);   -- fail-closed; `gecici` → STAT_CUMLE:gecici:bilinmeyen_anahtar
  IF p_id IS NULL THEN
    INSERT INTO public.stat_kayitli_grafik(farm_id, baslik, cumle, cumle_surum, sira)
    SELECT v_farm, p_baslik, p_cumle, (p_cumle->>'v')::int, COALESCE(max(g.sira), 0) + 1
      FROM public.stat_kayitli_grafik g
     WHERE g.farm_id = v_farm
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.stat_kayitli_grafik g
       SET baslik = p_baslik, cumle = p_cumle, cumle_surum = (p_cumle->>'v')::int, guncelleme_at = now()
     WHERE g.id = p_id AND g.farm_id = v_farm
    RETURNING g.id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'STAT_GRAFIK:yok'; END IF;
  END IF;
  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.stat_grafik_kaydet(uuid, text, jsonb) IS
  'Pano kaydı (spec §4.7): cümle stat_cumle_dogrula ile doğrulanır; p_id NULL → yeni kayıt (sira = çiftlikte max+1, '
  'cumle_surum = cumle.v); dolu → başlık/cümle/sürüm/guncelleme_at güncellenir, kayıt yoksa STAT_GRAFIK:yok.';

-- ── 4. Sil ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_grafik_sil(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  DELETE FROM public.stat_kayitli_grafik g WHERE g.id = p_id AND g.farm_id = public.current_farm_id();
  IF NOT FOUND THEN RAISE EXCEPTION 'STAT_GRAFIK:yok'; END IF;
END;
$$;

-- ── 5. Sırala ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_grafik_sirala(p_idler uuid[])
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_farm uuid := public.current_farm_id();
BEGIN
  -- dizi = çiftliğin tüm kayıtlarının tam ve tekrarsız kümesi (NULL dizi / NULL öğe / çok boyutlu dahil red)
  IF p_idler IS NULL OR array_ndims(p_idler) > 1 OR array_position(p_idler, NULL) IS NOT NULL
     OR (SELECT count(DISTINCT t.id) FROM pg_catalog.unnest(p_idler) AS t(id)) <> cardinality(p_idler)
     OR (SELECT count(*) FROM public.stat_kayitli_grafik g WHERE g.farm_id = v_farm) <> cardinality(p_idler)
     OR EXISTS (SELECT 1 FROM pg_catalog.unnest(p_idler) AS t(id)
                 WHERE NOT EXISTS (SELECT 1 FROM public.stat_kayitli_grafik g WHERE g.id = t.id AND g.farm_id = v_farm)) THEN
    RAISE EXCEPTION 'STAT_GRAFIK:sira_kumesi';
  END IF;
  UPDATE public.stat_kayitli_grafik g
     SET sira = t.n::int
    FROM pg_catalog.unnest(p_idler) WITH ORDINALITY AS t(id, n)
   WHERE g.id = t.id AND g.farm_id = v_farm;
END;
$$;

COMMENT ON FUNCTION public.stat_grafik_sirala(uuid[]) IS
  'Pano sırası (plan P9): p_idler çiftliğin tüm kayıtlarının tam ve tekrarsız kümesi olmalı, aksi STAT_GRAFIK:sira_kumesi; '
  'sira = dizideki konum (1..n).';

-- ── 6. ACL ──────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.stat_grafik_listele() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_grafik_kaydet(uuid, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_grafik_sil(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_grafik_sirala(uuid[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_grafik_listele() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_grafik_kaydet(uuid, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_grafik_sil(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_grafik_sirala(uuid[]) TO authenticated;

COMMIT;
