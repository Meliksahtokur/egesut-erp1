-- ============================================================================
-- Migration: 20260925000005_ureme_temizlik_reconcile
-- Tarih: 2026-09-25 · SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s3.md §5
-- Tek-seferlik DEMO temizlik aracı (sahip onaylı koşum); prod'a uygulanmaz.
-- ============================================================================
-- Migration: ureme_temizlik_reconcile — stale sessiz görevleri + kısır zincirleri tek-seferlik,
-- dry-run'lı tasfiye RPC'si. SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s3.md §5 (S-3).
-- Kurallar: R1 (aktif protocol_family vakalı hayvanın açık SESSIZ görevi),
--           R2 (son tohumlama Gebe/Bekliyor olan hayvanın açık SESSIZ görevi),
--           KISIR (kisir=true hayvanın aktif UREME instance'ları + açık zincir görevleri).
-- R3: ILAC görevleri ve aktif akışa ait TEDAVI zincirleri ASLA dokunulmaz (188 kasıtlı çift zincir).
-- Silme YOK — yalnız iptal + kapatan_ref + islem_log audit. Cron yeniden-üretimi Adım 1-2
-- (kısır blok + v_eligible yeniden sınıflandırma) merge'ünden sonra doğal olarak kesilir;
-- bu RPC yalnız tarihsel kiri kapatır.
BEGIN;

CREATE OR REPLACE FUNCTION public.ureme_temizlik_reconcile(
  p_dry_run boolean DEFAULT true,
  p_gruplar text[] DEFAULT ARRAY['R1', 'R2', 'KISIR']
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  r record;
  v_r1          jsonb := '[]'::jsonb;
  v_r2          jsonb := '[]'::jsonb;
  v_k_inst      jsonb := '[]'::jsonb;
  v_k_gorev     jsonb := '[]'::jsonb;
  v_gunc        jsonb := '[]'::jsonb;
  v_say_r1      integer := 0;
  v_say_r2      integer := 0;
  v_say_inst    integer := 0;
  v_say_gorev   integer := 0;
BEGIN
  -- ── R1: aktif protocol_family vakası olan hayvanın açık SESSIZ vet-kontrol görevi ──
  IF 'R1' = ANY (p_gruplar) THEN
    FOR r IN
      SELECT g.id, g.hayvan_id, h.kupe_no, g.aciklama
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'VETERINER_KONTROL'
         AND g.kaynak LIKE 'SESSIZ-%'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND EXISTS (SELECT 1 FROM public.cases c
                      WHERE c.animal_id = g.hayvan_id
                        AND c.status = 'active'
                        AND c.protocol_family IS NOT NULL)
       ORDER BY g.hayvan_id, g.id
    LOOP
      v_r1 := v_r1 || jsonb_build_object('gorev_id', r.id, 'hayvan_id', r.hayvan_id,
                 'kupe_no', r.kupe_no, 'aciklama', r.aciklama);
      v_say_r1 := v_say_r1 + 1;
      IF NOT p_dry_run THEN
        UPDATE public.gorev_log
           SET iptal = true, kapatan_ref = 'OVSYNC_KAPLANDI'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'gorev_log', 'id', r.id::text,
                   'onceki', jsonb_build_object('iptal', false, 'kapatan_ref', NULL),
                   'sonraki', jsonb_build_object('iptal', true, 'kapatan_ref', 'OVSYNC_KAPLANDI'));
      END IF;
    END LOOP;
  END IF;

  -- ── R2: son tohumlama Gebe/Bekliyor (MK3 sıralaması) olan hayvanın açık SESSIZ görevi ──
  --    R1 kapsamındaki hayvanlar R2'de tekrar sayılmaz (R1 önceliği, çift-kapatma yok).
  IF 'R2' = ANY (p_gruplar) THEN
    FOR r IN
      SELECT g.id, g.hayvan_id, h.kupe_no, g.aciklama, v_son.sonuc
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
        LEFT JOIN LATERAL (
          SELECT t.sonuc
            FROM public.tohumlama t
           WHERE t.hayvan_id = g.hayvan_id
           ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
           LIMIT 1
        ) v_son ON true
       WHERE g.gorev_tipi = 'VETERINER_KONTROL'
         AND g.kaynak LIKE 'SESSIZ-%'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND v_son.sonuc IN ('Gebe', 'Bekliyor')
         AND NOT EXISTS (SELECT 1 FROM public.cases c
                          WHERE c.animal_id = g.hayvan_id
                            AND c.status = 'active'
                            AND c.protocol_family IS NOT NULL)
       ORDER BY g.hayvan_id, g.id
    LOOP
      v_r2 := v_r2 || jsonb_build_object('gorev_id', r.id, 'hayvan_id', r.hayvan_id,
                 'kupe_no', r.kupe_no, 'aciklama', r.aciklama, 'son_tohumlama_sonuc', r.sonuc);
      v_say_r2 := v_say_r2 + 1;
      IF NOT p_dry_run THEN
        UPDATE public.gorev_log
           SET iptal = true, kapatan_ref = 'TOHUMLAMA_SONUCU_VAR'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'gorev_log', 'id', r.id::text,
                   'onceki', jsonb_build_object('iptal', false, 'kapatan_ref', NULL),
                   'sonraki', jsonb_build_object('iptal', true, 'kapatan_ref', 'TOHUMLAMA_SONUCU_VAR'));
      END IF;
    END LOOP;
  END IF;

  -- ── KISIR-A: kısır hayvanın aktif UREME instance'ları (ILERI_GEBE vb.) ──
  IF 'KISIR' = ANY (p_gruplar) THEN
    FOR r IN
      SELECT pi.id, pi.kaynak_ref, pi.hayvan_id, h.kupe_no, pi.tip, pi.alttip, pi.baslangic
        FROM public.protokol_instance pi
        JOIN public.hayvanlar h ON h.id = pi.hayvan_id
       WHERE h.kisir IS TRUE
         AND pi.durum = 'aktif'
       ORDER BY pi.hayvan_id, pi.id
    LOOP
      v_k_inst := v_k_inst || jsonb_build_object('instance_id', r.id, 'kaynak_ref', r.kaynak_ref,
                   'hayvan_id', r.hayvan_id, 'kupe_no', r.kupe_no, 'tip', r.tip,
                   'alttip', r.alttip, 'baslangic', r.baslangic);
      v_say_inst := v_say_inst + 1;
      IF NOT p_dry_run THEN
        UPDATE public.protokol_instance
           SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'KISIR_TEMIZLIK'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'protokol_instance', 'id', r.id::text,
                   'onceki', jsonb_build_object('durum', 'aktif', 'kapandi_at', NULL, 'kapandi_sebep', NULL),
                   'sonraki', jsonb_build_object('durum', 'iptal', 'kapandi_sebep', 'KISIR_TEMIZLIK'));
      END IF;
    END LOOP;

    -- ── KISIR-B: kısır hayvanın açık zincir görevleri (instance bağlı olsun olmasın) ──
    FOR r IN
      SELECT g.id, g.hayvan_id, h.kupe_no, g.gorev_tipi, g.aciklama
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE h.kisir IS TRUE
         -- ONARIM (2026-09-25): TOHUMLAMA_PLANLI eklendi — spec §6 taban çizgisi
         -- kısır hayvanların 3 açık TOHUMLAMA_PLANLI görevini kümede SAYIYORDU
         -- (27=24+3) ama §5.1 taslağın IN-listesi onu kapsamıyordu; kısır
         -- hayvanın planlı tohumlama görevi zincirin parçasıdır (sahibe kararı:
         -- kısır zincirleri kapatılır). K24: TOHUMLAMA_PLANLI'nın açık çocuğu
         -- yok → cascade no-op, D-2 sıralaması güvenli kalır.
         AND g.gorev_tipi IN ('OVSYNC_BASLAT', 'TEDAVI_GUN', 'TEDAVI_SEANS', 'TOHUMLAMA_PLANLI')
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
       ORDER BY g.hayvan_id, g.gorev_tipi DESC, g.id  -- D-2: SEANS (çocuk) GUN (ebeveyn)'den ÖNCE; bkz. §5.1 tasarım notları
    LOOP
      v_k_gorev := v_k_gorev || jsonb_build_object('gorev_id', r.id, 'hayvan_id', r.hayvan_id,
                    'kupe_no', r.kupe_no, 'gorev_tipi', r.gorev_tipi, 'aciklama', r.aciklama);
      v_say_gorev := v_say_gorev + 1;
      IF NOT p_dry_run THEN
        UPDATE public.gorev_log
           SET iptal = true, kapatan_ref = 'KISIR_TEMIZLIK'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'gorev_log', 'id', r.id::text,
                   'onceki', jsonb_build_object('iptal', false, 'kapatan_ref', NULL),
                   'sonraki', jsonb_build_object('iptal', true, 'kapatan_ref', 'KISIR_TEMIZLIK'));
      END IF;
    END LOOP;
  END IF;

  -- ── Audit: gerçek koşumda tek islem_log satırı (L4 geri-alma snapshot deseni) ──
  IF NOT p_dry_run AND (v_say_r1 + v_say_r2 + v_say_inst + v_say_gorev) > 0 THEN
    INSERT INTO public.islem_log (tip, ref_tablo, snapshot, kullanici_notu)
    VALUES ('UREME_TEMIZLIK', 'gorev_log',
            jsonb_build_object(
              'olusturulan', '[]'::jsonb,
              'silinen', '[]'::jsonb,
              'guncellenen', v_gunc),
            format('Üreme temizlik koşumu: R1=%s, R2=%s, KISIR-instance=%s, KISIR-gorev=%s',
                   v_say_r1, v_say_r2, v_say_inst, v_say_gorev));
  END IF;

  RETURN jsonb_build_object(
    'dry_run', p_dry_run,
    'gruplar', to_jsonb(p_gruplar),
    'R1',            jsonb_build_object('sayi', v_say_r1,    'kapatan_ref', 'OVSYNC_KAPLANDI',      'kayitlar', v_r1),
    'R2',            jsonb_build_object('sayi', v_say_r2,    'kapatan_ref', 'TOHUMLAMA_SONUCU_VAR', 'kayitlar', v_r2),
    'KISIR_INSTANCE',jsonb_build_object('sayi', v_say_inst,  'kapandi_sebep','KISIR_TEMIZLIK',      'kayitlar', v_k_inst),
    'KISIR_GOREV',   jsonb_build_object('sayi', v_say_gorev, 'kapatan_ref', 'KISIR_TEMIZLIK',       'kayitlar', v_k_gorev),
    'zaman', now());
END;
$fn$;

REVOKE ALL ON FUNCTION public.ureme_temizlik_reconcile(boolean, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ureme_temizlik_reconcile(boolean, text[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
-- EOF 20260925000005_ureme_temizlik_reconcile (S-3; içerik spec §5.1 birebir, b02f28ff taslağı)
