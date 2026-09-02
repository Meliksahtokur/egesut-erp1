-- 20260902000003_asi_planli_gorev.sql
-- Planlı aşı görevi: aşı + doz planlama anında belirlenir, stok REZERVE edilir,
-- görev iptal edilirse iade edilir (kullanıcı onayı 2026-09-02 — ilaç modeli:
-- add_treatment_day_with_sessions plan anında düşer / remove_treatment_session flip ile iade eder).
--
-- Bileşenler:
--   1. asi_gorev_planla(p_hayvan_id, p_vaccine_id, p_doz, p_tarih, p_aciklama)
--      → ASI_PLANLI görevi (stok_id + miktar dolu) + 'asi_plan' stok rezervasyonu + islem_log
--   2. asi_planli_tamamla(p_gorev_id, p_tarih, p_doz?, p_vaccine_id?)
--      → rezervasyonu kapatır + add_vaccination (gerçek uygulama) + görevi tamamlar; atomik
--   3. trg_gorev_asip_iade — gorev_log.iptal TRUE geçişinde rezervasyonu iade eder
--      (detayIptal RPC'siz doğrudan PATCH attığı için tetikleyici zorunlu)
--   4. Legacy: elle oluşturulmuş ILERI_GEBE_ASI görevleri ASI_PLANLI'ya taşınır
--   5. gorev_tamamla'ya ASI_PLANLI stok-muafiyeti (çift düşüm kilidi) — ayrı bölümde,
--      canlı gövdeden programatik üretilir (bu dosyanın sonuna script ekler)

-- ── 1) Planlama ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.asi_gorev_planla(
  p_hayvan_id text,
  p_vaccine_id uuid,
  p_doz numeric,
  p_tarih date,
  p_aciklama text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_vax      record;
  v_hayvan   text;
  v_gorev_id uuid := gen_random_uuid(); -- gorev_log.id uuid'dir (GT 'text' bayat)
BEGIN
  IF p_doz IS NULL OR p_doz <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Doz pozitif olmalı');
  END IF;

  SELECT * INTO v_vax FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşı bulunamadı');
  END IF;
  IF v_vax.stock_item_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşının stok bağlantısı yok: ' || v_vax.name);
  END IF;

  IF p_hayvan_id IS NOT NULL THEN
    SELECT id INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
    END IF;
  END IF;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak)
  VALUES
    (v_gorev_id, p_hayvan_id, 'ASI_PLANLI',
     COALESCE(NULLIF(btrim(p_aciklama), ''), '💉 ' || v_vax.name || ' (planlı)'),
     p_tarih, false, v_vax.stock_item_id, p_doz, 'MANUEL');

  -- Rezervasyon: pozitif = kullanım; iptal/iade flip'i trigger ve tamamla RPC'sinde
  INSERT INTO public.stok_hareket
    (stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id)
  VALUES
    (v_vax.stock_item_id, 'Aşı (Plan)', p_doz, 'GorevID:' || v_gorev_id::text, false, 'asi_plan', v_gorev_id::text);

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_GOREV_PLAN', p_hayvan_id, v_gorev_id::text, 'gorev_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev_id)),
      'vaccine', v_vax.name, 'doz', p_doz, 'tarih', p_tarih),
    'Planlı aşı görevi: ' || v_vax.name || ' ' || p_doz || 'ml');

  RETURN jsonb_build_object('ok', true, 'gorev_id', v_gorev_id::text);
END;
$function$;

-- ── 2) Tamamlama: rezervasyon kapanır, gerçek uygulama yazılır (tek düşüm) ──
CREATE OR REPLACE FUNCTION public.asi_planli_tamamla(
  p_gorev_id text,
  p_tarih date,
  p_doz numeric DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_gorev      gorev_log%ROWTYPE;
  v_vaccine_id uuid;
  v_vax_result jsonb;
  v_doz        numeric;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.gorev_tipi IS DISTINCT FROM 'ASI_PLANLI' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev planlı aşı görevi değil');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;
  IF v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş');
  END IF;

  -- Aşı: form seçimi öncelikli; yoksa görevin stok bağlantısından çöz
  -- (stok_id serbest metin — bozuk formatta ham cast yerine zarif ok:false)
  IF p_vaccine_id IS NULL AND v_gorev.stok_id LIKE 'STOK-AŞI-%' THEN
    BEGIN
      v_vaccine_id := split_part(v_gorev.stok_id, 'STOK-AŞI-', 2)::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_vaccine_id := NULL;
    END;
  END IF;
  v_vaccine_id := COALESCE(p_vaccine_id, v_vaccine_id);
  IF v_vaccine_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görevde aşı bağlantısı yok');
  END IF;

  v_doz := COALESCE(p_doz, v_gorev.miktar);

  SELECT public.add_vaccination(v_gorev.hayvan_id, v_vaccine_id, p_tarih, v_doz, NULL)
    INTO v_vax_result;
  IF (v_vax_result->>'ok')::boolean IS NOT TRUE THEN
    RETURN v_vax_result; -- rezervasyon açık kalır (flip başarıdan SONRA — hayvan hatasında depozito yanmaz)
  END IF;

  -- gorev_geri_al aşıyı 'GorevID:' notundan bulur. Notu INSERT SONRASI yazıyoruz:
  -- add_vaccination'in rapel kararı (v_is_gorev_triggered) etkilenmez, yıllık rapel üretimi sürer.
  UPDATE public.vaccination_log
     SET notes = 'GorevID:' || p_gorev_id
   WHERE id = (v_vax_result->>'vaccination_id')::uuid;

  -- Rezervasyonu kapat → net düşüm = gerçek uygulama (add_vaccination trigger'ı yazar).
  -- Aynı transaction: add_vaccination istisna atarsa flip dahil her şey geri alınır.
  UPDATE public.stok_hareket
     SET iptal = true
   WHERE referans_tipi = 'asi_plan'
     AND referans_id = p_gorev_id
     AND NOT iptal;

  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now()
   WHERE id = p_gorev_id::uuid;

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_vax_result->>'vaccination_id',
    'next_due', v_vax_result->>'next_due'
  );
END;
$function$;

-- ── 3) İptal → iade tetikleyicisi ───────────────────────────────────────────
-- detayIptal (js/ui.js) RPC'siz doğrudan PATCH attığı için iade DB tetikleyicisinde;
-- gorev_orphan_temizle / parent-kapanışı gibi tüm iptal yollarını da kapsar.
CREATE OR REPLACE FUNCTION public.fn_gorev_asip_iade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.stok_hareket
     SET iptal = true
   WHERE referans_tipi = 'asi_plan'
     AND referans_id = NEW.id::text
     AND NOT iptal;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_gorev_asip_iade ON public.gorev_log;
CREATE TRIGGER trg_gorev_asip_iade
  AFTER UPDATE OF iptal ON public.gorev_log
  FOR EACH ROW
  WHEN (NEW.iptal AND NOT COALESCE(OLD.iptal, false))
  EXECUTE FUNCTION public.fn_gorev_asip_iade();

-- ── 4) Legacy: elle oluşturulan ILERI_GEBE_ASI görevleri planlı tipe taşınır ──
-- (RPC üretimi 'ILERI_GEBE-<uuid>' kaynaklıdır; MANUEL kaynaklılar bu tipe ait değildi)
UPDATE public.gorev_log
   SET gorev_tipi = 'ASI_PLANLI'
 WHERE gorev_tipi = 'ILERI_GEBE_ASI'
   AND kaynak = 'MANUEL';


-- ═══ 5) gorev_tamamla güncellemesi — canlı gövdeden programatik üretildi, tek koşul eklendi ═══

CREATE OR REPLACE FUNCTION public.gorev_tamamla(p_gorev_id text, p_padok_hedef text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_gorev record; v_hayvan record; v_snapshot jsonb;
  v_stok_dusuldu boolean := false; v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb; v_guncellenen jsonb := '[]'::jsonb;
  v_padok_id uuid;
  v_hedef_padok text;
  v_yeni_grup text;
BEGIN
  SELECT * INTO v_gorev
    FROM public.gorev_log
   WHERE id = p_gorev_id::uuid
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id; END IF;
  IF v_gorev.tamamlandi THEN RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış'); END IF;
  IF v_gorev.iptal THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz'); END IF;

  IF v_gorev.gorev_tipi = 'SUTTEN_KESME' AND v_gorev.hayvan_id IS NOT NULL THEN
    PERFORM public.buzagi_sutten_kesme_onayla(v_gorev.hayvan_id);
    UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=COALESCE(tamamlanma_tarihi, now())
      WHERE id=p_gorev_id::uuid AND tamamlandi=false;
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'sutten_kesme', true);
  END IF;

  v_hedef_padok := COALESCE(NULLIF(btrim(p_padok_hedef), ''), NULLIF(btrim(v_gorev.padok_hedef), ''));

  IF v_gorev.gorev_tipi = 'PADOK_DEGISIM'
     AND v_gorev.hayvan_id IS NOT NULL
     AND v_hedef_padok IS NULL THEN
    RAISE EXCEPTION 'Padok değişim görevinin hedef padoku boş: %', p_gorev_id
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_hedef_padok IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan
      FROM public.hayvanlar
     WHERE id = v_gorev.hayvan_id
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Görevin hayvanı bulunamadı: %', v_gorev.hayvan_id
        USING ERRCODE = 'foreign_key_violation';
    ELSE
      SELECT id INTO v_padok_id
        FROM public.padoklar
       WHERE ad = v_hedef_padok;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Hedef padok bulunamadı: %', v_hedef_padok
          USING ERRCODE = 'foreign_key_violation';
      END IF;

      v_yeni_grup := v_hayvan.grup;
      IF v_gorev.gorev_tipi = 'PADOK_DEGISIM'
         AND v_gorev.aciklama ILIKE '%Kuru döneme%' THEN
        v_yeni_grup := 'Sağmal (Kuru)';
      END IF;

      IF EXISTS (SELECT 1 FROM public.grup_padok_eslem WHERE grup = v_yeni_grup)
         AND NOT EXISTS (
           SELECT 1
             FROM public.grup_padok_eslem
            WHERE grup = v_yeni_grup
              AND padok_id = v_padok_id
         ) THEN
        RAISE EXCEPTION 'Grup % için hedef padok geçersiz: %', v_yeni_grup, v_hedef_padok
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;

  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo','gorev_log','id',p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi',v_gorev.tamamlandi,'tamamlanma_tarihi',v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi',true,'tamamlanma_tarihi',now())
  );
  UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=now() WHERE id=p_gorev_id::uuid;

  -- ASI_PLANLI muaf: planlı görevin stok düşümü yalnız asi_planli_tamamla üzerinden
  -- olur (plan rezervasyonu + gerçek uygulama); generic 'Görev' satırı çift düşüm olurdu
  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0
     AND v_gorev.gorev_tipi IS DISTINCT FROM 'ASI_PLANLI' THEN
    v_stok_dusuldu := true;
    INSERT INTO public.stok_hareket (id,stok_id,tur,miktar,notlar,iptal)
    VALUES (gen_random_uuid(),v_gorev.stok_id,'Görev',v_gorev.miktar,'GorevID:'||p_gorev_id,false);
  END IF;

  IF v_hedef_padok IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    v_padok_guncellendi := true;
    v_guncellenen := v_guncellenen || jsonb_build_object(
      'tablo','hayvanlar','id',v_gorev.hayvan_id,
      'onceki',jsonb_build_object('grup',v_hayvan.grup,'padok',v_hayvan.padok,'padok_id',v_hayvan.padok_id),
      'sonraki',jsonb_build_object('grup',v_yeni_grup,'padok',v_hedef_padok,'padok_id',v_padok_id)
    );

    UPDATE public.hayvanlar
       SET grup = v_yeni_grup,
           padok = v_hedef_padok,
           padok_id = v_padok_id
     WHERE id = v_gorev.hayvan_id;
  END IF;

  v_snapshot := jsonb_build_object('olusturulan',v_olusturulan,'guncellenen',v_guncellenen,'silinen','[]'::jsonb);
  INSERT INTO public.islem_log (tip,ana_hayvan_id,ref_id,ref_tablo,snapshot,kullanici_notu)
  VALUES ('GOREV_TAMAMLA',v_gorev.hayvan_id,p_gorev_id,'gorev_log',v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object('ok',true,'gorev_id',p_gorev_id,'stok_dusuldu',v_stok_dusuldu,'padok_guncellendi',v_padok_guncellendi);
END;
$function$
;
