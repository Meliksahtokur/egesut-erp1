-- 20260910000002_sperma_eslesme_sertlestirme.sql
-- G-20260910-UREME-STOK-BUGFIX / W2+W2b (BUG-002) — iki legacy tohumlama
-- yolunun paylaşılan matcher'a bağlanması (SAF REWIRING).
--
-- Ne yapar (W2b sonrası): YALNIZ iki `CREATE OR REPLACE FUNCTION` —
-- `tohumlama_kaydet` ve `tohumlama_tekrar_kaydet` gövdelerindeki inline
-- `INSERT INTO stok_hareket ... ILIKE '%'||p_sperma||'%'` blokları
-- `PERFORM public.fn_sperma_stok_dus(...)` çağrısıyla değiştirilir; gövdenin
-- KALANI dump'tan birebir korunur (pg_get_functiondef, 2026-09-10 ölçümü).
-- Helper'ın kendisi M1'de (20260910000001) final imzasıyla kurulur; bu dosyada
-- helper CREATE/DROP'ı YOKTUR. W2b (review düzeltme turu) yapı kararı:
--   * DROP yok (review B2/B3): (text) overload'ı asla doğmaz → 42725 belirsizliği
--     ve DROP kaynaklı ACL/owner kaybı imkânsızlaşır; zincir M1'den replay
--     edilse bile helper tek imzada kalır.
--   * Oturum-düzeyi mesaj SET satırı yok (review B4): session-artığı sızdırmaz;
--     kaldırılma nedeni olan "does not exist, skipping" NOTICE'i de artık yoktur.
--   * BEGIN/COMMIT sargısı (review B5): dosya kendi içinde atomiktir —
--     `psql -f` dış transaction açmadığından tek CREATE'in geçip ikisinin
--     kalması imkânsızdır (Postgres'te fonksiyon DDL'i transactioneldir).
--
-- Notlar (çağıran taraf): M1'in sabit notlar'ına bağlanmak denetim izi
-- kaybettireceği için (canlıda tohumlama_kaydet kupe_no, tekrar yolu deneme
-- sayısı yazar) iki yol, notları canlı metinleriyle helper'a verir; bu,
-- M1 sözleşmesi (d) maddesinin notlar için uygulanmasıdır (W2 gate bulgusu).
--
-- Böylece üç tohumlama yolu tek eşleşme kuralına bağlanır:
--   - tohumlama_kaydet          → doğrudan helper
--   - tohumlama_tekrar_kaydet   → doğrudan helper
--   - planli_tohumlama_kaydet   → delege (koşulsuz tohumlama_kaydet çağırır;
--     gövdesinde stok düşümü yoktur — W1 kanıtı, karar 398ff5c7) → miras alır
--
-- Eşleşme kuralı (helper'da yaşar, M1'de): boş/whitespace/NULL ad HİÇ düşmez;
-- exact `urun_adi` önce; exact yoksa substring ILIKE; kategori='Sperma';
-- eşleşme yok sessiz geçer; stok eksiye düşebilir (emsal 20260902000002).
--
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f <bu dosya>

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan         record;
  v_yas_gun        integer;
  v_deneme         integer;
  v_toh_id         uuid := gen_random_uuid();
  v_ek             jsonb;
  v_ek_stok        uuid;
  v_son_dogum      date;
  v_son_abort      date;
  v_anchor_tip     text;
  v_anchor_date    date;
  v_vwp_gun        integer;
  v_inst_id        uuid;
  v_kaynak         text;
  v_eski_tohumlama record;
  v_iptal_gorev    integer := 0;
  v_iptal_inst     integer := 0;
  v_islem_id       text    := gen_random_uuid()::text;
  v_snapshot       jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar
    WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.cinsiyet = 'Erkek' THEN RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz'; END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  SELECT MAX(d.tarih) INTO v_son_dogum FROM public.dogum d WHERE d.anne_id = p_hayvan_id;
  SELECT MAX(t.abort_tarihi) INTO v_son_abort FROM public.tohumlama t
    WHERE t.hayvan_id = p_hayvan_id AND t.sonuc = 'Abort' AND t.abort_tarihi IS NOT NULL;
  v_anchor_tip := NULL; v_anchor_date := NULL; v_vwp_gun := NULL;
  IF v_son_abort IS NOT NULL AND (v_son_dogum IS NULL OR v_son_abort > v_son_dogum) THEN
    v_anchor_tip := 'ABORT'; v_anchor_date := v_son_abort;
    v_vwp_gun := p_tarih - v_son_abort;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'ABORT_VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  ELSIF v_son_dogum IS NOT NULL THEN
    v_anchor_tip := 'DOGUM'; v_anchor_date := v_son_dogum;
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  -- OTOMATIK BOS + ORPHAN TEMIZLEME
  FOR v_eski_tohumlama IN
    SELECT id, deneme_no, tarih, sperma
    FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Bekliyor'
    FOR UPDATE
  LOOP
    UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id = v_eski_tohumlama.id;

    UPDATE public.gorev_log
      SET iptal = true
      WHERE kaynak = 'TOH-' || v_eski_tohumlama.id::text
        AND tamamlandi = false
        AND iptal = false;
    GET DIAGNOSTICS v_iptal_gorev = ROW_COUNT;

    UPDATE public.protokol_instance
      SET durum = 'iptal'
      WHERE kaynak_ref = 'TOH-' || v_eski_tohumlama.id::text
        AND durum = 'aktif';
    GET DIAGNOSTICS v_iptal_inst = ROW_COUNT;

    v_snapshot := jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', v_toh_id::text, 'veri', jsonb_build_object(
          'hayvan_id', p_hayvan_id, 'tarih', p_tarih, 'sperma', p_sperma,
          'hekim_id', p_hekim_id, 'irk_bilgisi', p_irk_bilgisi,
          'sonuc', 'Bekliyor', 'deneme_no', v_deneme
        ))
      ),
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama', 'id', v_eski_tohumlama.id::text,
          'onceki', jsonb_build_object('sonuc', 'Bekliyor'),
          'sonraki', jsonb_build_object('sonuc', 'Boş', 'sebep', 'OTOMATIK_YENI_TOHUMLAMA')
        )
      ),
      'iptal_gorev_sayisi', v_iptal_gorev,
      'iptal_instance_sayisi', v_iptal_inst,
      'notlar', 'Yeni tohumlama girildi — eski Bekliyor cycle otomatik kapatildi'
    );
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (v_islem_id, 'TOHUMLAMA_OTOMATIK_BOS', p_hayvan_id,
            v_eski_tohumlama.id::text, 'tohumlama', v_snapshot);
  END LOOP;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme,
     p_ek_uygulamalar,
     CASE WHEN v_anchor_tip IS NOT NULL AND v_vwp_gun < 55 THEN true ELSE false END);

  IF v_anchor_tip IS NOT NULL AND v_vwp_gun < 55 AND p_vwp_override THEN
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
    VALUES (
      gen_random_uuid()::text, 'VWP_OVERRIDE', p_hayvan_id,
      jsonb_build_object('tohumlama_id', v_toh_id, 'vwp_gun', v_vwp_gun, 'anchor_tip', v_anchor_tip, 'anchor_date', v_anchor_date)
    );
  END IF;

  v_kaynak := 'TOH-' || v_toh_id::text;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'TOHUMLAMA', v_kaynak, p_tarih, 'aktif')
  RETURNING id INTO v_inst_id;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_kaynak, v_inst_id),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_kaynak, v_inst_id);

  -- BUG-002 (M2): matcher paylasilan helper'a baglandi — bos/whitespace ad
  -- dusurmez, exact once, sonra substring; kategori='Sperma' kapsami helper'da.
  -- Canli notlar metni (kupe_no) birebir korunur.
  PERFORM public.fn_sperma_stok_dus(
    p_sperma,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id)
  );

  IF p_ek_uygulamalar IS NOT NULL AND jsonb_array_length(p_ek_uygulamalar) > 0 THEN
    FOR v_ek IN SELECT * FROM jsonb_array_elements(p_ek_uygulamalar) LOOP
      IF (v_ek->>'stok_id') IS NOT NULL AND (v_ek->>'stok_id') <> '' THEN
        v_ek_stok := (v_ek->>'stok_id')::uuid;
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
        VALUES (
          v_ek_stok, 'Tohumlama',
          COALESCE((v_ek->>'doz')::numeric, 1),
          'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
          false
        );
      END IF;
    END LOOP;
  END IF;

  -- Hayvan dogrudan (gorev uzerinden degil) tohumlandiysa acik planli tohumlama
  -- gorevi artik konusuz kalir. planli_tohumlama_kaydet bu fonksiyonu icerden
  -- cagirir ve HEMEN ARDINDAN kendi gorevini iptal=false + tamamlandi=true
  -- yapar; sirali oldugu icin dogru sonuc kazanir.
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now()
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi = 'TOHUMLAMA_PLANLI'
    AND tamamlandi = false AND iptal = false;

  RETURN jsonb_build_object(
    'ok',                       true,
    'tohumlama_id',             v_toh_id,
    'deneme_no',                v_deneme,
    'inst_id',                  v_inst_id,
    'otomatik_bos_sayisi',      v_iptal_gorev,
    'otomatik_iptal_instance',  v_iptal_inst
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.tohumlama_tekrar_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan record;
  v_toh record;
  v_eski jsonb;
  v_yeni_denemeler jsonb;
BEGIN
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF p_tarih > CURRENT_DATE THEN RAISE EXCEPTION 'Tarih ileri olamaz'; END IF;

  SELECT * INTO v_toh
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor'
    AND tarih >= CURRENT_DATE - INTERVAL '15 days'
  ORDER BY tarih DESC, created_at DESC, id::text DESC
  LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Son 15 gün içinde Bekliyor tohumlama bulunamadı'; END IF;

  v_eski := jsonb_build_object('no', v_toh.deneme_sayisi, 'tarih', v_toh.tarih, 'sperma', v_toh.sperma, 'hekim_id', v_toh.hekim_id);
  v_yeni_denemeler := v_toh.denemeler || jsonb_build_array(v_eski);

  UPDATE public.tohumlama
  SET tarih = p_tarih, sperma = p_sperma, hekim_id = COALESCE(p_hekim_id, hekim_id),
      irk_bilgisi = COALESCE(p_irk_bilgisi, irk_bilgisi),
      deneme_sayisi = deneme_sayisi + 1, denemeler = v_yeni_denemeler
  WHERE id = v_toh.id;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = p_hayvan_id AND tamamlandi = false AND iptal = false
    AND gorev_tipi IN ('TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL');

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL', '21. Gün gebelik kontrolü', p_tarih + 21, false, v_toh.id::text),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL', '35. Gün gebelik kontrolü', p_tarih + 35, false, v_toh.id::text);

  -- BUG-002 (M2): matcher paylasilan helper'a baglandi (canli notlar metni
  -- korunur); bos/whitespace ad artik rastgele Sperma satirindan dusmez.
  PERFORM public.fn_sperma_stok_dus(
    p_sperma,
    'Tekrar Aşım ' || (v_toh.deneme_sayisi + 1) || '. deneme — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id)
  );

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh.id, 'deneme_sayisi', v_toh.deneme_sayisi + 1);
END;
$function$;

COMMIT;
