-- 20260929000005_gebelik_gorev_temizlik.sql
-- P2d (plan.md:360-376) — açık +21/+35 GEBELIK_KONTROL görevlerinin veri temizliği.
-- Kural (§18.13, sahip 2026-09-29): GEBELIK_KONTROL görevinin TEK üreticisi ≥40 g cron
-- (gebelik_muayene_gorev_uret, 20260925000002:327-386). Eski üretim (+21/+35, tohumlama_kaydet)
-- kod tarafında P2c ile kaldırıldı (20260929000004); bu dosya KOD-ÜSTÜ VERİ temizliğidir
-- (§10d #1 veri temizliği ≠ kod fix — ayrı madde).
--
-- Seçim ölçütü (deterministik, KAYNAK-ÖNCELİKLİ):
--   gorev_tipi = 'GEBELIK_KONTROL' AND NOT tamamlandi AND NOT iptal AND kaynak LIKE 'TOH-%'
--   — eski tohumlama_kaydet üretimi kaynak='TOH-<tohumlama_id>' yazar; cron kaynağı
--   'GEBELIK-KONTROL-<tohumlama_id>' öneklidir (20260925000002:374) → ölçüt cron görevlerine
--   dokunmaz. Açıklama ('21. Gün gebelik kontrolü' / '35. Gün gebelik kontrolü') yalnız
--   ÇAPRAZ DOĞRULAMA amaçlıdır: kaynak/açıklama uyuşmazsa KAYNAK kazanır.
--
-- İz: her temizlenmiş satıra kapatan_ref='p2d-veri-temizligi' (trg_gorev_parent_kapandi
-- 'parent-kapandi' deseniyle uyumlu; gorev_log'da notlar kolonu yoktur) + tek toplu islem_log
-- kaydı (tip='GOREV_GUNCELLENDI', snapshot: adet + ölçüt + '§10d #1 veri temizliği' +
-- temizlenen id/hayvan listesi).
--
-- Idempotent: aday koşulu iptal=false gerektirir → ikinci koşum 0 satır UPDATE,
-- islem_log izi de yazılmaz (adet=0 koruması).
--
-- Yan etki emniyeti (2026-09-30 demo doğrulaması):
--   - trg_gorev_asip_iade: yalnız referans_tipi='asi_plan' stok hareketlerine dokunur
--     (GEBELIK_KONTROL'de eşleşme yok → no-op).
--   - trg_gorev_parent_kapandi: iptal flip'inde yalnız görevin ÇOCUKLARINI iptal eder;
--     demo'da adayların tümü ana görevdir (parent_id NULL = 40/40, çocuksu = 0) → no-op.
--   - trg_degisim_log (audit) yalnız degisim izi yazar.
--   - PROD apply SAHİP KAPISIDIR — bu dosya yalnız plan-uygulama kapısında koşar.

DO $$
DECLARE
  v_adet      integer;
  v_ids       jsonb;
  v_hayvanlar jsonb;
BEGIN
  WITH temizlenen AS (
    UPDATE public.gorev_log
       SET iptal = true,
           kapatan_ref = 'p2d-veri-temizligi'
     WHERE gorev_tipi = 'GEBELIK_KONTROL'
       AND tamamlandi = false
       AND iptal = false
       AND kaynak LIKE 'TOH-%'
    RETURNING id, hayvan_id
  )
  SELECT count(*)::int,
         jsonb_agg(id),
         jsonb_agg(DISTINCT hayvan_id)
    INTO v_adet, v_ids, v_hayvanlar
  FROM temizlenen;

  IF v_adet > 0 THEN
    INSERT INTO public.islem_log
      (id, tip, ana_hayvan_id, tarih, kullanici_notu, durum, snapshot, ref_tablo)
    VALUES
      (gen_random_uuid()::text,
       'GOREV_GUNCELLENDI',
       NULL,
       now(),
       'P2d: eski +21/+35 GEBELIK_KONTROL görevleri iptal edildi (tek üretici ≥40 g cron)',
       'aktif',
       jsonb_build_object(
         'adet', v_adet,
         'olcut', 'gorev_tipi=''GEBELIK_KONTROL'' AND NOT tamamlandi AND NOT iptal AND kaynak LIKE ''TOH-%''',
         'kaynak_oncelikli', true,
         'aciklama_capraz_dogrulama', jsonb_build_array(
            '21. Gün gebelik kontrolü',
            '35. Gün gebelik kontrolü'),
         'etiket', '§10d #1 veri temizliği',
         'temizlenen_gorev_id', v_ids,
         'etkilenen_hayvan', v_hayvanlar),
       'gorev_log');
    RAISE NOTICE 'P2D-TEMIZLIK: iptal-edilen=%', v_adet;
  ELSE
    RAISE NOTICE 'P2D-TEMIZLIK: iptal-edilen=0 (idempotent no-op — aday yok)';
  END IF;
END;
$$;
