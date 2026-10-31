-- Migration: gorev_tamamla korumasına HAYVAN_TAKIP_MUAYENE
-- Tarih: 2026-10-31. Kaynak: spec §6; domain-rules §20.6. Önceki migration: 20261031200002.
-- BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısındadır.
--
-- Tek fark: guard listesine 'HAYVAN_TAKIP_MUAYENE'. Gövdenin geri kalanı canlı tanımdır
-- (md5(prosrc) 90e150e1ac402f7365fbb2d3ca86d27d, 20261013000004 ile birebir). p_iptal=true dalı aynen.
-- Bu tip guard'dan muaf bir yolla kapanır: hayvan_takip_muayene_sonuc görevi doğrudan yazar.
-- Gövde içindeki guard yorumu üreme akışını anlatır; tek satır farkı korumak için değiştirilmedi.
--
-- ROLLBACK (tek işlemde):
--   20261013000004_k8_gorev_senkron.sql içindeki CREATE OR REPLACE FUNCTION public.gorev_tamamla bloğu
--   yeniden koşulur; md5(prosrc) yukarıdaki değere dönmelidir. ACL aşağıdakiyle aynı kalır.
--   Not: Rollback sonrası açık HAYVAN_TAKIP_MUAYENE görevi genel yoldan sonuçsuz kapanabilir.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.gorev_tamamla(p_gorev_id text, p_padok_hedef text DEFAULT NULL::text, p_iptal boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev record; v_hayvan record; v_snapshot jsonb;
  v_stok_dusuldu boolean := false; v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb; v_guncellenen jsonb := '[]'::jsonb;
  v_padok_id uuid;
  v_hedef_padok text;
  v_yeni_grup text;
  v_guard_tip text;
  v_uygulama_etken text;
BEGIN
  -- ═══ P3b H6 guard — MUAYENE_SONUC_GEREKLI (plan.md:407 birebir) ═══
  -- Yalnız TAMAMLAMA dalı (p_iptal false/NULL) + yalnız muayene tipleri.
  -- Kilitsiz tek okuma — ilk (kilitli) tablo erişiminden ÖNCE; mevcut kilit
  -- sırası (gorev_log FOR UPDATE → koşullu hayvanlar FOR UPDATE) DEĞİŞMEZ
  -- (§10h H1: gorev_tamamla eski yoldur). Görev yalnız muayene sonuc RPC'si
  -- (tohumlama_bos_ve_devam muayene yolu) üzerinden kapanır (§18.17).
  -- p_iptal=true dalı (T5 offline-replay iptali) ve SUTTEN_KESME/padok
  -- dalları bu guard'a GİRMEZ — davranışları aynen korunur.
  IF p_iptal IS NOT TRUE THEN
    SELECT gorev_tipi INTO v_guard_tip
      FROM public.gorev_log
     WHERE id = p_gorev_id::uuid;
    IF v_guard_tip IN ('GEBELIK_KONTROL', 'TAKIP_MUAYENE', 'HAYVAN_TAKIP_MUAYENE') THEN
      RAISE EXCEPTION 'MUAYENE_SONUC_GEREKLI:%', v_guard_tip;
    END IF;
  END IF;

  SELECT * INTO v_gorev
    FROM public.gorev_log
   WHERE id = p_gorev_id::uuid
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id; END IF;

  -- ═══ T5 branşı (cila 20260925000006) — offline kuyruk replay'i iptal-PATCH'i
  --     İPTAL olarak kapatır; mevcut mantık ikame EDİLMEZ. Konum: NOT FOUND
  --     kontrolünün hemen ardından, tamamlandi/iptal erken-dönüşlerinden ÖNCE.
  --     REVIEW DÜŞÜK-1 düzeltmesi (2026-09-25): tamamlandi-guard'ı — zaten
  --     tamamlanmış (gerçek tamamlanma) görev, sonradan replay edilen bayat
  --     iptal-PATCH'le İPTAL'e çevrİLMEZ; erken-dönüşe düşer ('zaten tamamlanmış').
  --     İç IF NOT FOUND ölü koddur (dış FOR UPDATE zaten raise eder) — kaldırıldı.
  IF p_iptal IS TRUE AND v_gorev.tamamlandi IS NOT TRUE THEN
    UPDATE public.gorev_log
       SET tamamlandi = true,
           tamamlanma_tarihi = COALESCE(tamamlanma_tarihi, now()),
           iptal = true
     WHERE id = p_gorev_id::uuid;
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
    VALUES ('GOREV_TAMAMLA', v_gorev.hayvan_id, p_gorev_id, 'gorev_log',
            '{"olusturulan":[],"guncellenen":[],"silinen":[]}'::jsonb,
            'Görev iptal edildi (offline replay)');
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'iptal', true);
  END IF;
  IF v_gorev.tamamlandi THEN RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış'); END IF;
  IF v_gorev.iptal THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz'); END IF;

  -- ═══ K8 köprü (Faz 3): görev tamamlanınca uygulama_log satırı ───────
  -- İki iptal dönüşünden SONRA (yukarıdaki p_iptal dalı + iptal guardı).
  -- Dinleyici (trg_dinle_uygulama) bu satırla uyarıyı düşürür; _gorev_dinle
  -- yalnız açık + iptalsiz görevi kapattığı için tamamlanan görevde idempotent'tir.
  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0
     AND v_gorev.hayvan_id IS NOT NULL THEN
    v_uygulama_etken := COALESCE(v_gorev.etken_kod, public._etken_kod_bul(v_gorev.stok_id, NULL));
    INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
    VALUES (v_gorev.hayvan_id, v_gorev.stok_id, v_uygulama_etken, v_gorev.miktar, 'ml', 'IM',
            'GorevID:' || p_gorev_id);
  END IF;

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
$function$;

REVOKE ALL ON FUNCTION public.gorev_tamamla(text, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text, boolean) TO authenticated, service_role;
