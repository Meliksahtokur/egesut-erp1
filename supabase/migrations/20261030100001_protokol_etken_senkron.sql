-- ════════════════════════════════════════════════════════════════════
-- Görev ↔ protokol uyarısı senkronu (G-20261030-PROTOKOL-ETKEN). Taban: canlı gövdeler (2026-10-30,
-- md5 gebelik 75e9c8ea, hizli dab11827; migration geçmişinden fark yalnız tek yorum satırı).
-- F1: gebelik_protokol_kontrol 1. doz Rota / Ademin / E Vit görevleri etken_kod yazar (protokol_eksik_tara
--     ve _gorev_dinle yalnız etken_kod ile eşler). F2: hizli_uygulama p_occurred_at'ı uygulama_log.tarih'e yazar.
-- Tarama penceresi değişmez. Veri onarımı bu migration'da YOK (prod apply ayrı sahip kapısı).
-- ════════════════════════════════════════════════════════════════════
BEGIN;

CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_padok_kuru  text;
  v_stok_id     text;
  v_g_kuru   constant numeric := public._ayar('kuru_donem_gun', 210);
  v_g_asi1   constant numeric := public._ayar('ileri_gebe_asi1_gun', 240);
  v_g_asi2   constant numeric := public._ayar('ileri_gebe_asi2_gun', 261);
  v_g_ademin constant numeric := public._ayar('ileri_gebe_ademin_gun', 260);
  v_g_evit   constant numeric := public._ayar('ileri_gebe_evit_gun', 265);
  v_g_besle  constant numeric := public._ayar('besleme_baslangic_gun', 260);
BEGIN
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih, t.id
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    IF v_gun >= v_g_kuru
       AND v_hayvan.grup ILIKE '%Sağmal%'
       AND v_hayvan.grup NOT ILIKE '%Kuru%'
    THEN
      v_hedef := v_toh.tarih::date + v_g_kuru::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'PADOK_DEGISIM',
             '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün gebelik) — Kuru/Gebe padoğuna transfer',
             v_hedef, false, v_padok_kuru, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'PADOK_DEGISIM'
          AND aciklama ILIKE '%Kuru döneme%'
          AND iptal = false
          AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_asi1 THEN
      v_hedef := v_toh.tarih::date + v_g_asi1::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id, etken_kod)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_toh.id::text,
             'ROTA'
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_asi2 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + v_g_asi2::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id, etken_kod)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_toh.id::text,
             'ROTA_2DOZ'
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND etken_kod = 'ROTA_2DOZ'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_ademin THEN
      v_hedef := v_toh.tarih::date + v_g_ademin::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id, etken_kod)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false, v_toh.id::text,
             'ADEMIN'
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_evit THEN
      v_hedef := v_toh.tarih::date + v_g_evit::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id, etken_kod)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false, v_toh.id::text,
             'E_VIT'
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_besle THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'BESLEME'
          AND aciklama = '🌅 Anyonik Besleme (Sabah)'
          AND hedef_tarih = CURRENT_DATE
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;

      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌙 Anyonik Besleme (Akşam)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'BESLEME'
          AND aciklama = '🌙 Anyonik Besleme (Akşam)'
          AND hedef_tarih = CURRENT_DATE
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'olusturulan', v_olusturulan,
    'hayvanlar', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'hayvan_id',    t.hayvan_id,
          'tarih',        t.tarih::text,
          'gebelik_gun',  CURRENT_DATE - t.tarih::date,
          'kupe_no',      h.kupe_no,
          'devlet_kupe',  h.devlet_kupe,
          'grup',         h.grup,
          'padok',        h.padok
        )
        ORDER BY CURRENT_DATE - t.tarih::date DESC
      )
      FROM tohumlama t
      JOIN hayvanlar h ON h.id = t.hayvan_id
      WHERE t.sonuc = 'Gebe'
        AND h.durum = 'Aktif'
        AND CURRENT_DATE - t.tarih::date >= v_g_kuru
        AND t.tarih = (
          SELECT MAX(t2.tarih) FROM tohumlama t2
          WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe'
        )
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.hizli_uygulama(p_hayvan_id text, p_stok_id text, p_doz numeric, p_birim text, p_rota text, p_notlar text, p_pg_onay boolean DEFAULT false, p_pg_gerekce text DEFAULT NULL::text, p_occurred_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hayvan hayvanlar%ROWTYPE;
  v_stok   record;
  v_etken  text;
  v_id     uuid;
  v_kalan  numeric;
  -- [OVSYNC-PG S-4] bayrak tek kez okunur (fonksiyon boyunca tutarlı karar)
  v_pg_aktif boolean := public._ovsync_pg_aktif();
  v_pg_kapi  jsonb;
  -- [OVSYNC-PG R3.1 MK7] PG anı; yalnız event'in occurred_at'ını etkiler
  v_occurred_at timestamptz;
  -- [P3b D4] açık takip keşfi (kilitsiz)
  v_takip record;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  -- [OVSYNC-PG S-4] güvenlik kapısı (MK6: blok → RAISE PG_KAPI:<KOD>:<json>)
  -- [OVSYNC-PG R3.1 MK7] PG anı doğrulaması aynı kapıda: NULL → now(); gelecekte
  -- >5dk ya da geçmişte >7g → PG_ZAMAN_GECERSIZ. Bayrak kapalıyken kontrol edilmez
  -- (MK5: PG olayı yok; uygulama_log.tarih yine p_occurred_at'tan yazılır).
  IF v_pg_aktif THEN
    IF p_occurred_at IS NULL THEN
      v_occurred_at := now();
    ELSIF p_occurred_at > now() + interval '5 minutes'
       OR p_occurred_at < now() - interval '7 days' THEN
      RAISE EXCEPTION 'PG_ZAMAN_GECERSIZ:%', jsonb_build_object(
        'p_occurred_at', p_occurred_at, 'simdi', now());
    ELSE
      v_occurred_at := p_occurred_at;
    END IF;

    v_pg_kapi := public._pg_kapi(p_hayvan_id, p_stok_id, NULL, COALESCE(p_pg_onay, false));

    -- ═══ P3b D4 TAKIP_ACIK preflight (plan.md:408) — KİLİTSİZ keşif (yalnız
    -- okur); İLK YAZMADAN (uygulama_log INSERT) ÖNCE; _pg_kapi çağrı noktasının
    -- yanında [20260923000004:134-149 sırası korunur]. Birleşik payload P2b
    -- sarmal deseniyle birebir (20260929000002:986-998). Onaylı → _takip_kapat
    -- (neden='PG') — tek satır, idempotent; hayvan kilidi YOK (H4).
    SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;

    IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      IF FOUND AND NOT COALESCE(p_takip_onay, false) THEN
        -- birleşik kapı: tek RAISE, tek onay penceresi (p_pg_onay + p_takip_onay)
        RAISE EXCEPTION 'PG_KAPI:TAKIP_ACIK:%',
          jsonb_build_object(
            'pg_kapi', public._pg_kapi_detay(v_pg_kapi, p_hayvan_id, v_hayvan.kupe_no),
            'takip_acik', jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                                             'muayene_saat', v_takip.hedef_saat)
          )::text;
      END IF;
      RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
        public._pg_kapi_detay(v_pg_kapi, p_hayvan_id, v_hayvan.kupe_no);
    END IF;

    IF FOUND THEN
      IF NOT COALESCE(p_takip_onay, false) THEN
        RAISE EXCEPTION 'TAKIP_ACIK:%',
          jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                             'muayene_saat', v_takip.hedef_saat)::text;
      END IF;
      PERFORM public._takip_kapat(v_takip.id, 'PG');
    END IF;
  END IF;

  -- [PROTOKOL-ETKEN F2] girilen an İstanbul gününe yazılır; boşsa kolon varsayılanı (CURRENT_DATE)
  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar, tarih)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar,
          COALESCE((p_occurred_at AT TIME ZONE 'Europe/Istanbul')::date, CURRENT_DATE))
  RETURNING id INTO v_id;

  -- [OVSYNC-PG S-4] PG gerçekleşme kaydı (+ACK, +S-5 görev); PG değilse no-op
  -- [OVSYNC-PG R3.1 MK7] now() yerine doğrulanmış v_occurred_at
  IF v_pg_aktif THEN
    PERFORM public._pg_olay_isle('HIZLI_UYGULAMA', v_id::text, p_hayvan_id, p_stok_id,
      v_stok.drug_product_id, v_occurred_at, v_pg_kapi, p_pg_gerekce);
  END IF;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES (
    'HIZLI_UYGULAMA',
    p_hayvan_id,
    v_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','uygulama_log','id',v_id::text)),
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb
    ),
    format('Hızlı Uygulama — %s — %s %s %s', v_hayvan.kupe_no, v_stok.urun_adi, p_doz, p_birim)
  );

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0)
  );
END;
$function$;

COMMIT;
