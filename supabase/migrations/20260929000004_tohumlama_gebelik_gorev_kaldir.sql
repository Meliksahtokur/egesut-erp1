-- 20260929000004_tohumlama_gebelik_gorev_kaldir.sql
-- P2c (plan.md:344-358) — tohumlama_kaydet'ten +21/+35 g GEBELIK_KONTROL üretiminin kaldırılması.
-- Kural (§18.13, sahip 2026-09-29): GEBELIK_KONTROL görevini yalnız ≥40 g cron
-- (gebelik_muayene_gorev_uret, 20260925000002:327-386) doğurur.
-- Kaynak gövde: canlı DEMO pg_get_functiondef('public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)')
-- (2026-09-30 okundu) ≡ 20260923000005:292-543 — diff yalnız `SET search_path` sözdizimi
-- normalizasyonu (pg_get_functiondef çıktısı; davranış farkı yok).
-- Tek değişiklik: GEBELIK_KONTROL INSERT bloğu (canlı satır 147-153 ≡ kaynak migration 438-444)
-- çıkarıldı. protokol_instance UREME/TOHUMLAMA INSERT (kaynak 434-436) KALIR; VWP/oto-Bos
-- döngüsü/sperma stok/ek uygulama/TOHUMLAMA_PLANLI kapatma/OVSYNC vaka kapanışı birebir korunur.
-- BELGELENMİŞ TEK-SATIR SAPMA: gövde satırı `FROM jsonb_array_elements(...)` →
-- `FROM pg_catalog.jsonb_array_elements(...)` — davranış-aynı nitelikli çözüm (aynı fonksiyon,
-- search_path bağımsız); gerekçe: db-validate B-fazı statik çözümleyicisi pg_catalog
-- fonksiyon-FROM çağrısını çözümleyemediğinden INCONCLUSIVE veriyordu (rapor 43d5b406).
-- ACL: mevcut canlı state korunur — REVOKE PUBLIC,anon + GRANT authenticated,service_role
-- (canlı proacl {postgres=X,authenticated=X,service_role=X}, 2026-09-30 OBSERVED).
-- NOT: açık eski +21/+35 görevlerinin temizliği AYRI maddedir (P2d) — bu dosyada DML yok.
-- Tekrar-uygulanabilir: CREATE OR REPLACE.

CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
  -- S-7 (bayrak arkası)
  v_ovsync_aktif   boolean := false;
  v_vaka           record;
  v_kapat          jsonb;
  v_kapatilan      jsonb   := '[]'::jsonb;
BEGIN
  -- MK9 (bayrak açıkken): kilit sırası hayvan → vaka/seans → görev. Bu
  -- fonksiyon hayvanı ilk olarak kilitler; ilk tablo erişiminden önce, tek
  -- satır. Bayrak kapalıyken bu satır YOK (MK5: eski davranış bit bit).
  IF public._ovsync_pg_aktif() THEN
    PERFORM 1 FROM public.hayvanlar WHERE id = p_hayvan_id FOR NO KEY UPDATE;
  END IF;

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


  -- BUG-002 (M2): matcher paylasilan helper'a baglandi — bos/whitespace ad
  -- dusurmez, exact once, sonra substring; kategori='Sperma' kapsami helper'da.
  -- Canli notlar metni (kupe_no) birebir korunur.
  PERFORM public.fn_sperma_stok_dus(
    p_sperma,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id)
  );

  IF p_ek_uygulamalar IS NOT NULL AND jsonb_array_length(p_ek_uygulamalar) > 0 THEN
    FOR v_ek IN SELECT * FROM pg_catalog.jsonb_array_elements(p_ek_uygulamalar) LOOP
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

  -- S-7 (MK5: yalnız bayrak AÇIKKEN). Tohumlama INSERT'i ve yukarıdaki tüm
  -- adımlardan sonra, aynı transaction'da: tohumlama tarihinde başlamış aktif
  -- senkronizasyon (protocol_family dolu) vakaları kapanır; protocol_family NULL
  -- vakalar (Mastit vb. / UNKNOWN) dokunulmaz. Açık OVSYNC_BASLAT görevleri
  -- (S-8 D50 zinciri) muaf edilir. Bayrak kapalı → hiçbir yazma, anahtar yok.
  IF public._ovsync_pg_aktif() THEN
    v_ovsync_aktif := true;

    FOR v_vaka IN
      SELECT c.id
        FROM public.cases c
       WHERE c.animal_id = p_hayvan_id
         AND c.status = 'active'
         AND c.protocol_family IS NOT NULL
         AND c.start_date <= p_tarih
       ORDER BY c.start_date, c.id
       FOR UPDATE
    LOOP
      v_kapat := public._vaka_kapat(v_vaka.id, 'TOHUMLAMA', NULL,
                                    jsonb_build_object('tohumlama_id', v_toh_id));
      IF NOT COALESCE((v_kapat->>'zaten_kapali')::boolean, false) THEN
        v_kapatilan := v_kapatilan || jsonb_build_array(jsonb_build_object(
          'case_id',     v_vaka.id,
          'iptal_seans', v_kapat->'iptal_seans',
          'iptal_gorev', v_kapat->'iptal_gorev'));
      END IF;
    END LOOP;
  END IF;

  -- MK8 (R3.1): temizlik bayraktan BAĞIMSIZ — yalnız yeni iş yaratan adımlar
  -- (vaka kapanış döngüsü yukarıda, dönüşteki 'kapatilan_senkronizasyon_vakalari'
  -- anahtarı) bayrak arkasındadır; açık OVSYNC_BASLAT görevi ve ILK_TOHUMLAMA
  -- instance'ının iptali her zaman çalışır. Bayrak hiç açılmadıysa S-8 hiçbir
  -- OVSYNC_BASLAT/ILK_TOHUMLAMA satırı üretmediği için 0 satır etkiler — MK5
  -- bozulmaz.
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now(),
      kapatan_ref = 'ILK_TOH_MUAF:TOHUMLAMA'
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi = 'OVSYNC_BASLAT'
    AND tamamlandi = false AND iptal = false;

  -- Muaf edilen rotanın instance'ı da kapanır (açık kalırsa orphan denetimine düşer).
  UPDATE public.protokol_instance
  SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_MUAF:TOHUMLAMA'
  WHERE hayvan_id = p_hayvan_id
    AND tip = 'UREME' AND alttip = 'ILK_TOHUMLAMA'
    AND durum = 'aktif';

  RETURN jsonb_build_object(
    'ok',                       true,
    'tohumlama_id',             v_toh_id,
    'deneme_no',                v_deneme,
    'inst_id',                  v_inst_id,
    'otomatik_bos_sayisi',      v_iptal_gorev,
    'otomatik_iptal_instance',  v_iptal_inst
  ) || CASE WHEN v_ovsync_aktif
            THEN jsonb_build_object('kapatilan_senkronizasyon_vakalari', v_kapatilan)
            ELSE '{}'::jsonb
       END;
END;
$function$;

-- ── ACL — mevcut grant'ler korunur (P2c plan.md:353) ──
REVOKE ALL ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) TO authenticated, service_role;
