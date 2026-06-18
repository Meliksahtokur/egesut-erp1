-- Migration: Toplu grup+padok değişimi + transfer görev uzlaştırma
-- EgeSüt ERP — 2026-06-18
-- 1. padok_degistir_toplu: p_yeni_grup opsiyonel parametresi
-- 2. gorev_tamamla: BUG A (grup adı) + BUG B (padok_id) fix
-- 3. fn_padok_transfer_gorev_kapat + trigger (görev listener)
-- 4. padok_transfer_gorev_uzlastir (reconciliation scan)
-- Geri alınabilir: evet

BEGIN;

-- ══════════════════════════════════════════════════════════════
-- 1. padok_degistir_toplu — p_yeni_grup eklendi
-- ══════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.padok_degistir_toplu(text[], uuid, text[]);
CREATE OR REPLACE FUNCTION public.padok_degistir_toplu(
  p_hayvan_ids text[],
  p_yeni_padok_id uuid,
  p_etiketler text[] DEFAULT NULL,
  p_yeni_grup text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_yeni_padok   padoklar%ROWTYPE;
  v_aktif_sayisi integer;
  v_hayvan_id    text;
  v_hayvan       hayvanlar%ROWTYPE;
  v_eslem_var    boolean;
BEGIN
  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Grup-padok uyum guard (UI bypass koruması)
  IF p_yeni_grup IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM grup_padok_eslem
      WHERE grup = p_yeni_grup AND padok_id = p_yeni_padok_id
    ) INTO v_eslem_var;
    IF NOT v_eslem_var THEN
      RETURN jsonb_build_object('success', false, 'error', 'grup_padok_uyumsuz');
    END IF;
  END IF;

  -- Kapasite hard block (validasyon, yazma yok)
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi + array_length(p_hayvan_ids, 1) > v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   (v_aktif_sayisi + array_length(p_hayvan_ids, 1))::text
                   || '/' || v_yeni_padok.kapasite::text
      );
    END IF;
  END IF;

  -- Hayvan validasyonları (validasyon, yazma yok)
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı: ' || v_hayvan_id);
    END IF;
    IF v_hayvan.padok_id = p_yeni_padok_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta: ' || v_hayvan_id);
    END IF;
  END LOOP;

  -- Tüm validasyonlar geçti — yazma işlemleri
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    UPDATE hayvanlar
       SET padok_id   = p_yeni_padok_id,
           padok      = v_yeni_padok.ad,
           grup       = COALESCE(p_yeni_grup, grup),
           updated_at = now()
     WHERE id = v_hayvan_id;

    INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('padok_degisim', v_hayvan_id, v_hayvan_id, '{}'::jsonb,
            'Toplu padok değişimi → ' || v_yeni_padok.ad
            || COALESCE(' (grup: ' || p_yeni_grup || ')', ''));
  END LOOP;

  -- Etiket güncelleme (varsa, mevcut etiketlerle birleştir)
  IF p_etiketler IS NOT NULL AND array_length(p_etiketler, 1) > 0 THEN
    UPDATE hayvanlar
       SET etiketler = array(
             SELECT DISTINCT unnest(COALESCE(etiketler, '{}') || p_etiketler)
           )
     WHERE id = ANY(p_hayvan_ids);
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'hayvan_sayisi', array_length(p_hayvan_ids, 1),
    'yeni_padok',    v_yeni_padok.ad,
    'yeni_padok_id', p_yeni_padok_id,
    'yeni_grup',     p_yeni_grup
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir_toplu(text[], uuid, text[], text) TO anon, authenticated;

COMMIT;

-- ══════════════════════════════════════════════════════════════
-- 2. gorev_tamamla — BUG A (grup adı) + BUG B (padok_id) fix
-- ══════════════════════════════════════════════════════════════
BEGIN;

CREATE OR REPLACE FUNCTION public.gorev_tamamla(
  p_gorev_id text,
  p_padok_hedef text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev record; v_hayvan record; v_snapshot jsonb;
  v_stok_dusuldu boolean := false; v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb; v_guncellenen jsonb := '[]'::jsonb;
  v_padok_id uuid;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id; END IF;
  IF v_gorev.tamamlandi THEN RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış'); END IF;
  IF v_gorev.iptal THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz'); END IF;

  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo','gorev_log','id',p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi',v_gorev.tamamlandi,'tamamlanma_tarihi',v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi',true,'tamamlanma_tarihi',now())
  );
  UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=now() WHERE id=p_gorev_id::uuid;

  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0 THEN
    v_stok_dusuldu := true;
    INSERT INTO public.stok_hareket (id,stok_id,tur,miktar,notlar,iptal)
    VALUES (gen_random_uuid(),v_gorev.stok_id,'Görev',v_gorev.miktar,'GorevID:'||p_gorev_id,false);
  END IF;

  IF p_padok_hedef IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id=v_gorev.hayvan_id;
    IF FOUND THEN
      v_padok_guncellendi := true;
      -- BUG B fix: padok_id de güncellenir
      SELECT id INTO v_padok_id FROM public.padoklar WHERE ad=p_padok_hedef;
      UPDATE public.hayvanlar
         SET padok=p_padok_hedef, padok_id=COALESCE(v_padok_id, padok_id)
       WHERE id=v_gorev.hayvan_id;
      -- BUG A fix: 'Sağmal (Kuru Dönem)' yerine eslem-kanonik 'Sağmal (Kuru)'
      IF v_gorev.gorev_tipi='PADOK_DEGISIM' AND v_gorev.aciklama ILIKE '%Kuru döneme%' THEN
        UPDATE public.hayvanlar SET grup='Sağmal (Kuru)' WHERE id=v_gorev.hayvan_id;
      END IF;
    END IF;
  END IF;

  v_snapshot := jsonb_build_object('olusturulan',v_olusturulan,'guncellenen',v_guncellenen,'silinen','[]'::jsonb);
  INSERT INTO public.islem_log (tip,ana_hayvan_id,ref_id,ref_tablo,snapshot,kullanici_notu)
  VALUES ('GOREV_TAMAMLA',v_gorev.hayvan_id,p_gorev_id,'gorev_log',v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object('ok',true,'gorev_id',p_gorev_id,'stok_dusuldu',v_stok_dusuldu,'padok_guncellendi',v_padok_guncellendi);
END;
$$;
GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text,text) TO anon, authenticated;

COMMIT;

-- ══════════════════════════════════════════════════════════════
-- 3. Görev listener — padok_id değişince eşleşen PADOK_DEGISIM görevi kapat
-- ══════════════════════════════════════════════════════════════
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_padok_transfer_gorev_kapat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now()
   WHERE hayvan_id = NEW.id
     AND gorev_tipi = 'PADOK_DEGISIM'
     AND tamamlandi = false
     AND iptal = false
     AND padok_hedef = NEW.padok;

  IF FOUND THEN
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('GOREV_OTOKAPAT', NEW.id, NEW.id, '{}'::jsonb,
            'Padok değişimi → ' || NEW.padok || ' (transfer görevi otomatik kapatıldı)');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_padok_transfer_gorev ON public.hayvanlar;
CREATE TRIGGER trg_padok_transfer_gorev
  AFTER UPDATE OF padok_id ON public.hayvanlar
  FOR EACH ROW
  WHEN (NEW.padok_id IS DISTINCT FROM OLD.padok_id)
  EXECUTE FUNCTION public.fn_padok_transfer_gorev_kapat();

COMMIT;
