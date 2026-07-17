-- Grup/padok invariant'i:
-- - Tek eslemeli gruplarda padok ve padok_id DB tarafinda atomik senkronlanir.
-- - Cok eslemeli gruplarda (Besi) secim korunur ve esleme tablosuna gore dogrulanir.
-- - Dogum ve kuru donem gorev akislari UI parametresine bagimli kalmaz.

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_hayvan_grup_padok_sync()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_eslem_sayisi integer;
  v_tekil_padok_id uuid;
  v_tekil_padok_ad text;
  v_id_padok_ad text;
  v_ad_padok_id uuid;
  v_secili_padok_id uuid;
  v_secili_padok_ad text;
  v_id_degisti boolean := false;
  v_ad_degisti boolean := false;
BEGIN
  IF NEW.grup IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT count(*)::integer, min(g.padok_id::text)::uuid, min(p.ad)
    INTO v_eslem_sayisi, v_tekil_padok_id, v_tekil_padok_ad
    FROM public.grup_padok_eslem g
    JOIN public.padoklar p ON p.id = g.padok_id
   WHERE g.grup = NEW.grup;

  -- Eslemesi tanimlanmamis legacy gruplara dokunma.
  IF v_eslem_sayisi = 0 THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_id_degisti := NEW.padok_id IS DISTINCT FROM OLD.padok_id;
    v_ad_degisti := NEW.padok IS DISTINCT FROM OLD.padok;
  END IF;

  IF v_eslem_sayisi = 1 THEN
    -- Legacy hayvanlar.padok DEFAULT'u INSERT'te P1 uretebilir; tekil grupta grup
    -- kanoniktir ve INSERT degeri ezilir. UPDATE'te acik uyumsuz tasima reddedilir.
    IF TG_OP = 'UPDATE' AND v_id_degisti AND NEW.padok_id IS DISTINCT FROM v_tekil_padok_id THEN
      RAISE EXCEPTION 'Grup % icin secilen padok_id gecersiz', NEW.grup
        USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'UPDATE' AND v_ad_degisti AND NEW.padok IS DISTINCT FROM v_tekil_padok_ad THEN
      RAISE EXCEPTION 'Grup % icin secilen padok gecersiz: %', NEW.grup, NEW.padok
        USING ERRCODE = 'check_violation';
    END IF;

    NEW.padok_id := v_tekil_padok_id;
    NEW.padok := v_tekil_padok_ad;
    RETURN NEW;
  END IF;

  -- Cok eslemeli gruplarda acik secim zorunlu; id ve ad birlikte verildiyse
  -- ayni padogu gostermeleri gerekir.
  IF TG_OP = 'INSERT' OR v_id_degisti THEN
    IF NEW.padok_id IS NOT NULL THEN
      SELECT p.ad
        INTO v_id_padok_ad
        FROM public.grup_padok_eslem g
        JOIN public.padoklar p ON p.id = g.padok_id
       WHERE g.grup = NEW.grup
         AND g.padok_id = NEW.padok_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Grup % icin secilen padok_id gecersiz', NEW.grup
          USING ERRCODE = 'check_violation';
      END IF;
      v_secili_padok_id := NEW.padok_id;
      v_secili_padok_ad := v_id_padok_ad;
    END IF;
  END IF;

  IF TG_OP = 'INSERT' OR v_ad_degisti THEN
    IF NEW.padok IS NOT NULL THEN
      SELECT g.padok_id
        INTO v_ad_padok_id
        FROM public.grup_padok_eslem g
        JOIN public.padoklar p ON p.id = g.padok_id
       WHERE g.grup = NEW.grup
         AND p.ad = NEW.padok;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Grup % icin secilen padok gecersiz: %', NEW.grup, NEW.padok
          USING ERRCODE = 'check_violation';
      END IF;
      IF v_secili_padok_id IS NOT NULL AND v_secili_padok_id IS DISTINCT FROM v_ad_padok_id THEN
        RAISE EXCEPTION 'Padok ve padok_id ayni padogu gostermiyor'
          USING ERRCODE = 'check_violation';
      END IF;
      v_secili_padok_id := v_ad_padok_id;
      v_secili_padok_ad := NEW.padok;
    END IF;
  END IF;

  -- Grup degisimi sirasinda padok alanlari aynen kaldiysa, eski secim yeni grup
  -- icin de gecerliyse koru. Ayni-grup self-heal icin de mevcut degeri cozer.
  IF v_secili_padok_id IS NULL AND NEW.padok_id IS NOT NULL THEN
    SELECT p.ad
      INTO v_secili_padok_ad
      FROM public.grup_padok_eslem g
      JOIN public.padoklar p ON p.id = g.padok_id
     WHERE g.grup = NEW.grup
       AND g.padok_id = NEW.padok_id;
    IF FOUND THEN
      v_secili_padok_id := NEW.padok_id;
    END IF;
  END IF;

  IF v_secili_padok_id IS NULL AND NEW.padok IS NOT NULL THEN
    SELECT g.padok_id, p.ad
      INTO v_secili_padok_id, v_secili_padok_ad
      FROM public.grup_padok_eslem g
      JOIN public.padoklar p ON p.id = g.padok_id
     WHERE g.grup = NEW.grup
       AND p.ad = NEW.padok;
  END IF;

  IF v_secili_padok_id IS NULL THEN
    RAISE EXCEPTION 'Grup % icin gecerli bir padok secilmelidir', NEW.grup
      USING ERRCODE = 'check_violation';
  END IF;

  NEW.padok_id := v_secili_padok_id;
  NEW.padok := v_secili_padok_ad;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_hayvan_grup_padok_sync() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_hayvan_grup_padok_sync ON public.hayvanlar;
CREATE TRIGGER trg_hayvan_grup_padok_sync
  BEFORE INSERT OR UPDATE OF grup, padok, padok_id ON public.hayvanlar
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_hayvan_grup_padok_sync();

-- Bir BEFORE trigger, UPDATE komutunun SET listesinde bulunmayan padok_id'yi
-- degistirebilir. Bu nedenle listener UPDATE OF padok_id ile sinirlanamaz;
-- WHEN kosulu gercek satir degisimini filtreler.
DROP TRIGGER IF EXISTS trg_padok_transfer_gorev ON public.hayvanlar;
CREATE TRIGGER trg_padok_transfer_gorev
  AFTER UPDATE ON public.hayvanlar
  FOR EACH ROW
  WHEN (NEW.padok_id IS DISTINCT FROM OLD.padok_id)
  EXECUTE FUNCTION public.fn_padok_transfer_gorev_kapat();

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

  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0 THEN
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
$function$;

GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text) TO anon, authenticated;

-- Yalniz aktif hayvanlari duzelt; cikisli hayvanlar tarihsel padok kaydini korur.
WITH tekil_eslem AS (
  SELECT g.grup, min(g.padok_id::text)::uuid AS padok_id, min(p.ad) AS padok_ad
    FROM public.grup_padok_eslem g
    JOIN public.padoklar p ON p.id = g.padok_id
   GROUP BY g.grup
  HAVING count(*) = 1
), duzeltilecek AS MATERIALIZED (
  SELECT h.id, h.grup, h.padok AS eski_padok, h.padok_id AS eski_padok_id,
         t.padok_ad, t.padok_id
    FROM public.hayvanlar h
    JOIN tekil_eslem t ON t.grup = h.grup
   WHERE h.durum = 'Aktif'
     AND (h.padok IS DISTINCT FROM t.padok_ad OR h.padok_id IS DISTINCT FROM t.padok_id)
), guncellenen AS (
  UPDATE public.hayvanlar h
     SET padok = d.padok_ad,
         padok_id = d.padok_id
    FROM duzeltilecek d
   WHERE h.id = d.id
  RETURNING h.id, h.grup, d.eski_padok, d.eski_padok_id, h.padok, h.padok_id
)
INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
SELECT 'GRUP_PADOK_UYUMLAMA', g.id, g.id, 'hayvanlar',
       jsonb_build_object(
         'olusturulan','[]'::jsonb,
         'silinen','[]'::jsonb,
         'guncellenen',jsonb_build_array(jsonb_build_object(
           'tablo','hayvanlar','id',g.id,
           'onceki',jsonb_build_object('grup',g.grup,'padok',g.eski_padok,'padok_id',g.eski_padok_id),
           'sonraki',jsonb_build_object('grup',g.grup,'padok',g.padok,'padok_id',g.padok_id)
         ))
       ),
       'Aktif hayvan grup/padok eşlemesi otomatik uyumlandı'
  FROM guncellenen g;

COMMIT;
