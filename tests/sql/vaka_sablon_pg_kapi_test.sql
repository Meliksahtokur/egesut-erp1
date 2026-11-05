-- Şablonlu vakada PG kapısı "Boş ata ve uygula" (domain-rules §18.8, 20261031200007) DB sözleşme testi.
-- BEGIN/ROLLBACK taşımaz: hayvan_takip_kos.sh sarar. Her senaryo kendi alt işleminde koşar ve geri sarılır.
-- Dosya yalnız "<id> PASS" NOTICE'ı yazar; düşen senaryo "<id> FAIL: ..." ile durur. Fixture: E2E-VS-*.
CREATE FUNCTION pg_temp.vs_id(p text, i int) RETURNS uuid LANGUAGE sql IMMUTABLE
  AS $f$ SELECT ('e2e00000-0000-4000-8000-00000' || p || '0' || lpad(i::text, 5, '0'))::uuid $f$;
CREATE FUNCTION pg_temp.vs_gun() RETURNS date LANGUAGE sql STABLE AS $f$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $f$;
CREATE FUNCTION pg_temp.vs_esit(p_gercek text, p_beklenen text, p_mesaj text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN IF p_gercek IS DISTINCT FROM p_beklenen THEN RAISE EXCEPTION '%: gerçek=% beklenen=%', p_mesaj, COALESCE(p_gercek, '<NULL>'), COALESCE(p_beklenen, '<NULL>'); END IF; END $f$;
CREATE FUNCTION pg_temp.vs_test(p_id text, p_govde text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    EXECUTE 'DO ' || quote_literal(p_govde);
    RAISE EXCEPTION USING ERRCODE = 'VSGER', MESSAGE = 'geri sar';
  EXCEPTION
    WHEN SQLSTATE 'VSGER' THEN NULL;
    WHEN OTHERS THEN RAISE EXCEPTION '% FAIL: % [%]', p_id, SQLERRM, SQLSTATE;
  END;
  RAISE NOTICE '% PASS', p_id;
END $f$;
-- Çağrının reddini doğrular: hata metni p_onek ile başlamalı; red kendi alt işleminde geri sarılır.
CREATE FUNCTION pg_temp.vs_red(p_onek text, p_sql text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN EXECUTE p_sql; v := '<hata yok>';
  EXCEPTION WHEN OTHERS THEN IF left(SQLERRM, length(p_onek)) = p_onek THEN RETURN; END IF; v := SQLERRM; END;
  RAISE EXCEPTION 'red bekleniyordu % gerçek %', p_onek, v;
END $f$;
-- Hayvanın yazım izi: tohumlama sonuçları, hayvan durumu, açık görevler, plan günü/PG seansı, PG olayı.
CREATE FUNCTION pg_temp.vs_iz(h text) RETURNS text LANGUAGE sql AS $f$
  SELECT format('toh=%s durum=%s ovsync=%s gebk=%s gun=%s pg_seans=%s pg_olay=%s islem=%s',
    (SELECT string_agg(sonuc, ',' ORDER BY tarih) FROM public.tohumlama WHERE hayvan_id = h),
    (SELECT tohumlama_durumu FROM public.hayvanlar WHERE id = h),
    (SELECT count(*) FROM public.gorev_log WHERE hayvan_id = h AND gorev_tipi = 'OVSYNC_BASLAT' AND NOT COALESCE(tamamlandi, false) AND NOT COALESCE(iptal, false)),
    (SELECT count(*) FROM public.gorev_log WHERE hayvan_id = h AND gorev_tipi = 'GEBELIK_KONTROL' AND NOT COALESCE(tamamlandi, false) AND NOT COALESCE(iptal, false)),
    (SELECT count(*) FROM public.treatment_days d JOIN public.cases c ON c.id = d.case_id WHERE c.animal_id = h),
    (SELECT count(*) FROM public.treatment_day_uygulamalar u JOIN public.treatment_days d ON d.id = u.treatment_day_id
       JOIN public.cases c ON c.id = d.case_id WHERE c.animal_id = h AND public._pg_urun_durumu(u.stok_id, u.drug_product_id) = 'PG'),
    (SELECT count(*) FROM public.pg_application_event WHERE hayvan_id = h),
    (SELECT count(*) FROM public.islem_log WHERE ana_hayvan_id = h AND tip = 'TOHUMLAMA_SONUC')) $f$;

-- Fixture: PG ve PG-dışı ürün; şablonlar: 1 = OVSYNC aileli PG'li, 2 = ailesiz PG'li, 3 = PG'siz.
-- Hayvan i: düve (800 g, kural günü geçti), son tohumlaması Bekliyor (−20 g), açık GEBELIK_KONTROL, aktif vaka (ailesiz).
INSERT INTO public.protokol_ayar(anahtar, deger) VALUES ('ovsync_pg_kurallari_aktif', 1) ON CONFLICT (anahtar) DO UPDATE SET deger = 1;
INSERT INTO public.diseases(id, name, category) VALUES (pg_temp.vs_id('1', 1), 'E2E-VS-Ovsync', 'Üreme');
INSERT INTO public.drug_classes(id, group_name, class_name, farmakolojik_sinif_kodu, etken_kod)
  VALUES (pg_temp.vs_id('2', 1), 'E2E-VS', 'PG', 'PGF2A', 'PG'), (pg_temp.vs_id('2', 2), 'E2E-VS', 'VIT', NULL, NULL);
INSERT INTO public.drug_products(id, drug_class_id, brand_name)
  VALUES (pg_temp.vs_id('f', 1), pg_temp.vs_id('2', 1), 'E2E-VS-PG'), (pg_temp.vs_id('f', 2), pg_temp.vs_id('2', 2), 'E2E-VS-VIT');
INSERT INTO public.stok(id, urun_adi, kategori, birim, baslangic_miktar, drug_product_id)
  VALUES ('E2E-VS-STK-PG', 'E2E-VS-PG', 'İlaç', 'ml', 100, pg_temp.vs_id('f', 1)), ('E2E-VS-STK-VIT', 'E2E-VS-VIT', 'İlaç', 'ml', 100, pg_temp.vs_id('f', 2));
INSERT INTO public.tedavi_sablonu(id, ad, protokol_ailesi)
  VALUES (pg_temp.vs_id('3', 1), 'E2E-VS-OVSYNC', 'OVSYNC'), (pg_temp.vs_id('3', 2), 'E2E-VS-AILESIZ-PG', NULL), (pg_temp.vs_id('3', 3), 'E2E-VS-PGSIZ', NULL);
INSERT INTO public.tedavi_sablonu_kalem(sablon_id, gun_no, planned_time, stok_id, drug_product_id, dose, unit, route)
  VALUES (pg_temp.vs_id('3', 1), 1, '10:00', 'E2E-VS-STK-VIT', pg_temp.vs_id('f', 2), 2, 'ml', 'IM'),
         (pg_temp.vs_id('3', 1), 8, '10:00', 'E2E-VS-STK-PG', pg_temp.vs_id('f', 1), 2, 'ml', 'IM'),
         (pg_temp.vs_id('3', 2), 1, '10:00', 'E2E-VS-STK-PG', pg_temp.vs_id('f', 1), 2, 'ml', 'IM'),
         (pg_temp.vs_id('3', 3), 1, '10:00', 'E2E-VS-STK-VIT', pg_temp.vs_id('f', 2), 2, 'ml', 'IM');
INSERT INTO public.hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
  SELECT 'E2E-VS-H-' || i, 'E2E-VS-' || i, 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.vs_gun() - 800 FROM generate_series(1, 4) i;
INSERT INTO public.tohumlama(id, hayvan_id, tarih, sperma, sonuc)
  SELECT pg_temp.vs_id('4', i), 'E2E-VS-H-' || i, pg_temp.vs_gun() - 20, 'E2E-VS', 'Bekliyor' FROM generate_series(1, 4) i;
INSERT INTO public.gorev_log(hayvan_id, gorev_tipi, aciklama, hedef_tarih, kaynak)
  SELECT 'E2E-VS-H-' || i, 'GEBELIK_KONTROL', 'E2E-VS', pg_temp.vs_gun() + 20, 'E2E-VS-GK:' || i FROM generate_series(1, 4) i;
INSERT INTO public.cases(id, animal_id, disease_id, start_date, status)
  SELECT pg_temp.vs_id('a', i), 'E2E-VS-H-' || i, pg_temp.vs_id('1', 1), pg_temp.vs_gun(), 'active' FROM generate_series(1, 4) i;
CREATE FUNCTION pg_temp.vs_cagir(p_vaka int, p_sablon int, p_toh text, p_gerekce text DEFAULT 'E2E-VS gerekçe') RETURNS jsonb LANGUAGE sql AS $f$
  SELECT public.tedavi_sablon_bos_ata_uygula(pg_temp.vs_id('a', p_vaka), pg_temp.vs_id('3', p_sablon), p_toh, p_gerekce) $f$;

-- VS01: kapı gerçekten açılıyor (ön koşul): Bekliyor tohumlamada şablon planı PG_KAPI:REQUIRE_ACK_PENDING ile durur.
SELECT pg_temp.vs_test('VS01', $t$ BEGIN
  PERFORM pg_temp.vs_red('PG_KAPI:REQUIRE_ACK_PENDING:', format('SELECT public.tedavi_sablon_uygula(%L, %L)', pg_temp.vs_id('a', 1), pg_temp.vs_id('3', 1)));
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-1'), 'toh=Bekliyor durum= ovsync=0 gebk=1 gun=0 pg_seans=0 pg_olay=0 islem=0', 'kapıda yazma yok');
END $t$);

-- VS02: başarı (OVSYNC aileli): tek işlemde Boş + plan; plandaki PG tek PG, kapı PG uygulamaz, OVSYNC_BASLAT açılmaz.
SELECT pg_temp.vs_test('VS02', $t$ DECLARE r jsonb; BEGIN
  r := pg_temp.vs_cagir(1, 1, pg_temp.vs_id('4', 1)::text);
  PERFORM pg_temp.vs_esit(r->>'ok', 'true', 'ok');
  PERFORM pg_temp.vs_esit(r->>'gun_sayisi', '2', 'gun_sayisi');
  PERFORM pg_temp.vs_esit(r->>'tohumlama_id', pg_temp.vs_id('4', 1)::text, 'tohumlama_id');
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-1'), 'toh=Boş durum=Boş ovsync=0 gebk=0 gun=2 pg_seans=1 pg_olay=0 islem=1', 'iz');
  PERFORM pg_temp.vs_esit((SELECT protocol_family FROM public.cases WHERE id = pg_temp.vs_id('a', 1)), 'OVSYNC', 'vaka ailesi');
  PERFORM pg_temp.vs_esit((SELECT snapshot->>'gerekce' FROM public.islem_log WHERE id = r->>'islem_id'), 'E2E-VS gerekçe', 'islem_log gerekçe');
  PERFORM pg_temp.vs_esit((SELECT snapshot->'guncellenen'->0->'onceki'->>'sonuc' FROM public.islem_log WHERE id = r->>'islem_id'), 'Bekliyor', 'geri alma izi');
END $t$);

-- VS03: ailesiz PG şablonu: plandan sonra açık dişi görevi normal Boş yoluyla aynı kurulur (§18.12 rotası; root kararı
-- 2026-11-05). Kıyas: ikiz hayvanda (H-3) tohumlama_sonuc_bos'un açtığı görevle kaynak deseni, hedef günü ve saati aynı.
SELECT pg_temp.vs_test('VS03', $t$ DECLARE a text; b text; BEGIN
  PERFORM pg_temp.vs_cagir(2, 2, pg_temp.vs_id('4', 2)::text);
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-2'), 'toh=Boş durum=Boş ovsync=1 gebk=0 gun=1 pg_seans=1 pg_olay=0 islem=1', 'iz');
  PERFORM public.tohumlama_sonuc_bos(pg_temp.vs_id('4', 3)::text);
  SELECT replace(kaynak, 'E2E-VS-H-2', 'H') || '@' || hedef_tarih || ' ' || hedef_saat INTO a FROM public.gorev_log
   WHERE hayvan_id = 'E2E-VS-H-2' AND gorev_tipi = 'OVSYNC_BASLAT' AND NOT COALESCE(iptal, false);
  SELECT replace(kaynak, 'E2E-VS-H-3', 'H') || '@' || hedef_tarih || ' ' || hedef_saat INTO b FROM public.gorev_log
   WHERE hayvan_id = 'E2E-VS-H-3' AND gorev_tipi = 'OVSYNC_BASLAT' AND NOT COALESCE(iptal, false);
  PERFORM pg_temp.vs_esit(a, b, 'normal Boş ile aynı görev');
  PERFORM pg_temp.vs_esit((a LIKE 'ACIK-DISI-H-%')::text, 'true', 'açık dişi kaynağı ' || COALESCE(a, '<yok>'));
END $t$);

-- VS10: vaka detayından uygulama (caseSablonUygula) başlangıç gününü taşır: plan günü seçilen tarihten başlar.
SELECT pg_temp.vs_test('VS10', $t$ DECLARE r jsonb; BEGIN
  r := public.tedavi_sablon_bos_ata_uygula(pg_temp.vs_id('a', 1), pg_temp.vs_id('3', 1), pg_temp.vs_id('4', 1)::text, 'E2E-VS', pg_temp.vs_gun() + 3);
  PERFORM pg_temp.vs_esit((SELECT min(d.treatment_date)::text FROM public.treatment_days d WHERE d.case_id = pg_temp.vs_id('a', 1)),
    (pg_temp.vs_gun() + 3)::text, 'ilk plan günü');
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-1'), 'toh=Boş durum=Boş ovsync=0 gebk=0 gun=2 pg_seans=1 pg_olay=0 islem=1', 'iz');
END $t$);

-- VS04: çift çağrı: ikinci çağrı TOH_SONUCLU ile reddedilir, ikinci plan ve ikinci Boş izi yok.
SELECT pg_temp.vs_test('VS04', $t$ BEGIN
  PERFORM pg_temp.vs_cagir(1, 1, pg_temp.vs_id('4', 1)::text);
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:TOH_SONUCLU:', format('SELECT pg_temp.vs_cagir(1, 1, %L)', pg_temp.vs_id('4', 1)));
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-1'), 'toh=Boş durum=Boş ovsync=0 gebk=0 gun=2 pg_seans=1 pg_olay=0 islem=1', 'iz');
END $t$);

-- VS05: PG'siz şablon: Boş atamanın gerekçesi yok, PG_YOK; hiçbir şey yazılmaz.
SELECT pg_temp.vs_test('VS05', $t$ BEGIN
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:PG_YOK:', format('SELECT pg_temp.vs_cagir(1, 3, %L)', pg_temp.vs_id('4', 1)));
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-1'), 'toh=Bekliyor durum= ovsync=0 gebk=1 gun=0 pg_seans=0 pg_olay=0 islem=0', 'iz');
END $t$);

-- VS06: ön koşul ihlalleri: boş gerekçe, kapalı/olmayan vaka, son olmayan tohumlama, başka hayvanın tohumlaması, sonuçlu son tohumlama.
SELECT pg_temp.vs_test('VS06', $t$ DECLARE i1 text; i4 text; BEGIN
  INSERT INTO public.tohumlama(id, hayvan_id, tarih, sperma, sonuc) VALUES (pg_temp.vs_id('5', 1), 'E2E-VS-H-1', pg_temp.vs_gun() - 60, 'E2E-VS', 'Boş');
  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id = pg_temp.vs_id('4', 4);
  UPDATE public.cases SET status = 'closed' WHERE id = pg_temp.vs_id('a', 3);
  i1 := pg_temp.vs_iz('E2E-VS-H-1'); i4 := pg_temp.vs_iz('E2E-VS-H-4');
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:GEREKCE_GEREKLI', format('SELECT pg_temp.vs_cagir(1, 1, %L, %L)', pg_temp.vs_id('4', 1), '  '));
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:GEREKCE_GEREKLI', format('SELECT pg_temp.vs_cagir(1, 1, %L, NULL)', pg_temp.vs_id('4', 1)));
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:VAKA_YOK:', format('SELECT pg_temp.vs_cagir(9, 1, %L)', pg_temp.vs_id('4', 1)));
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:VAKA_YOK:', format('SELECT pg_temp.vs_cagir(3, 1, %L)', pg_temp.vs_id('4', 3)));
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:TOH_SON_DEGIL:', format('SELECT pg_temp.vs_cagir(1, 1, %L)', pg_temp.vs_id('4', 2)));
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:TOH_SON_DEGIL:', format('SELECT pg_temp.vs_cagir(1, 1, %L)', pg_temp.vs_id('5', 1)));
  PERFORM pg_temp.vs_red('PG_KAPI_BOS_ATA:TOH_SONUCLU:', format('SELECT pg_temp.vs_cagir(4, 1, %L)', pg_temp.vs_id('4', 4)));
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-1'), i1, 'H-1 iz değişmez');
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-4'), i4, 'H-4 iz değişmez');
  PERFORM pg_temp.vs_esit((i1 LIKE 'toh=Boş,Bekliyor % gun=0 pg_seans=0 pg_olay=0 islem=0')::text, 'true', 'H-1 fixture ' || i1);
END $t$);

-- VS07: atomik: plan reddedilirse (kısır + OVSYNC şablonu) Boş da geri alınır.
SELECT pg_temp.vs_test('VS07', $t$ DECLARE i1 text; BEGIN
  UPDATE public.hayvanlar SET kisir = true WHERE id = 'E2E-VS-H-1';
  i1 := pg_temp.vs_iz('E2E-VS-H-1');
  PERFORM pg_temp.vs_red('KISIR', format('SELECT pg_temp.vs_cagir(1, 1, %L)', pg_temp.vs_id('4', 1)));
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-1'), i1, 'iz değişmez');
  PERFORM pg_temp.vs_esit((i1 LIKE 'toh=Bekliyor % gun=0 pg_seans=0 pg_olay=0 islem=0')::text, 'true', 'fixture ' || i1);
END $t$);

-- VS08: tohumlama_sonuc_bos davranışı değişmedi: Boş + açık dişi görevi (OVSYNC_BASLAT) ve üç ok:false dönüşü.
SELECT pg_temp.vs_test('VS08', $t$ DECLARE r jsonb; i3 text; BEGIN
  r := public.tohumlama_sonuc_bos(pg_temp.vs_id('4', 2)::text);
  PERFORM pg_temp.vs_esit(r->>'ok', 'true', 'ok');
  PERFORM pg_temp.vs_esit((SELECT count(*)::text FROM public.islem_log WHERE id = r->>'islem_id' AND tip = 'TOHUMLAMA_SONUC' AND NOT snapshot ? 'gerekce'), '1', 'islem_log');
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-2'), 'toh=Boş durum=Boş ovsync=1 gebk=0 gun=0 pg_seans=0 pg_olay=0 islem=1', 'iz');
  PERFORM pg_temp.vs_esit(public.tohumlama_sonuc_bos(pg_temp.vs_id('4', 2)::text)::text,
    '{"ok": false, "error": "Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir"}', 'sonuçlu');
  PERFORM pg_temp.vs_esit(public.tohumlama_sonuc_bos('yok')::text, '{"ok": false, "error": "Tohumlama bulunamadı"}', 'yok');
  UPDATE public.hayvanlar SET durum = 'Satıldı' WHERE id = 'E2E-VS-H-3';
  i3 := pg_temp.vs_iz('E2E-VS-H-3');
  PERFORM pg_temp.vs_esit(public.tohumlama_sonuc_bos(pg_temp.vs_id('4', 3)::text)::text, '{"ok": false, "error": "Hayvan aktif değil"}', 'pasif');
  PERFORM pg_temp.vs_esit(pg_temp.vs_iz('E2E-VS-H-3'), i3, 'pasif iz değişmez');
END $t$);

-- VS09: ACL ve tanım: yeni RPC authenticated'a açık, anon/PUBLIC'e kapalı; iç yardımcı yalnız sahibine; SECURITY DEFINER + search_path.
SELECT pg_temp.vs_test('VS09', $t$ DECLARE f text; BEGIN
  PERFORM pg_temp.vs_esit(has_function_privilege('authenticated', 'public.tedavi_sablon_bos_ata_uygula(uuid,uuid,text,text,date)', 'EXECUTE')::text, 'true', 'authenticated');
  PERFORM pg_temp.vs_esit(has_function_privilege('anon', 'public.tedavi_sablon_bos_ata_uygula(uuid,uuid,text,text,date)', 'EXECUTE')::text, 'false', 'anon');
  FOREACH f IN ARRAY ARRAY['public.tedavi_sablon_bos_ata_uygula(uuid,uuid,text,text,date)', 'public._tohumlama_bos_cekirdek(text,text)'] LOOP
    PERFORM pg_temp.vs_esit((SELECT COALESCE(bool_or(a LIKE '=%'), false)::text FROM pg_proc p, unnest(p.proacl::text[]) a WHERE p.oid = f::regprocedure), 'false', f || ' PUBLIC');
    PERFORM pg_temp.vs_esit((SELECT (prosecdef AND 'search_path=public, pg_temp' = ANY(proconfig))::text FROM pg_proc WHERE oid = f::regprocedure), 'true', f || ' definer');
  END LOOP;
  PERFORM pg_temp.vs_esit(has_function_privilege('authenticated', 'public._tohumlama_bos_cekirdek(text,text)', 'EXECUTE')::text, 'false', 'iç yardımcı');
  PERFORM pg_temp.vs_esit(has_function_privilege('authenticated', 'public.tohumlama_sonuc_bos(text,text)', 'EXECUTE')::text, 'true', 'eski RPC ACL');
END $t$);
