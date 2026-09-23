-- ============================================================================
-- Migration: 20260923000006_ilk_tohumlama_zinciri
-- Tarih: 2026-09-23
-- Otorite: docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md (R3) §0 SK4/SK5/MK5,
--          S-8 (ilk tohumlama zinciri), S-9 (mevcut sapma düzeltmeleri),
--          R3.1 (bağlayıcı, bağımsız inceleme sonrası) — aşağıdaki 4 madde.
-- Kanonik taban:
--   dogum_kaydet       → 20260923000001 gövdesi (S-10 D39 düzeltmesi dahil; canlı
--                        gövde DEĞİL). D39 satırı korunur.
--   tohumlama_abort    → canlı pg_get_functiondef (3 argümanlı, 2026-09-23).
--   _vaka_ac_tek, tedavi_sablon_uygula, tedavi_sablon_tohumlama_gorev_ekle
--                      → canlı dönüş biçimleri (değiştirilmez, yalnız çağrılır;
--                        tedavi_sablon_uygula provenance'ı 000005'te).
--
-- NE YAPAR:
--   S-8  _ilk_tohumlama_rota_kur(text, date, text)  iç: D50 OVSYNC_BASLAT görevi +
--        protokol_instance(UREME/ILK_TOHUMLAMA); kaynak_ref UNIQUE ile idempotent.
--   S-8  dogum_kaydet: yalnız v_anne_yan_etki dalında kanca
--        (kaynak 'ILK-TOH-DOGUM-<olay_id>'). + SET search_path (kasıtlı sertleştirme).
--   S-8  tohumlama_abort(text, text, date): başarılı abort sonrası kanca
--        (kaynak 'ILK-TOH-ABORT-<tohumlama_id>', D50 sayacı abort tarihinden).
--        + SET search_path.
--   S-8  start_first_service_protocol(uuid) RPC: D50'de atomik zincir
--        _vaka_ac_tek → tedavi_sablon_uygula → tedavi_sablon_tohumlama_gorev_ekle;
--        herhangi biri başarısız/eksikse RAISE (yarım zincir yok, TAI'siz zincir yok).
--        SK4: doğum protokolünün 58. gün DIGER kızgınlık takibi iptal; 53. gün E-vit kalır.
--   S-8  ilk_tohumlama_zamanlayici() RPC + pg_cron 'ilk-tohumlama-ovsync-baslat'
--        '0 4 * * *' (07:00 İstanbul). Görev başına izole alt blok, üst sınır 200.
--   S-9  tohumlama_abort(text, text) 2 argümanlı overload DROP (js/ tek çağrı
--        forms.js isimli 3 argüman; DB içinde çağıran yok).
--   S-9  abort_kaydet(text, text): EXECUTE authenticated'dan REVOKE (js/ çağrısı yok;
--        api.js'teki yalnız pull-tablo haritası girdisi; DB içinde çağıran yok).
--   SK5: gebe onayında rota YOK — tetik yalnız doğum ve abort.
--   R3.1 (#5) MK3 "son tohumlama" okuması (start_first_service_protocol'daki
--        gebelik otoritesi kontrolü): sıralama artık
--        `ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST`
--        (tarih NULL olan bir satır sıralamayı bozmasın).
--   R3.1 (#6) ilk_tohumlama_zamanlayici: görev seçimi `hedef_tarih DESC, id`
--        (en yeni önce). Gerekçe: kalıcı hatalı eski bir görev (her koşumda
--        BEGIN…EXCEPTION'a düşen) limit-200 kuyruğunun başında sonsuza kadar
--        oturup yeni hayvanların D50 başlangıcını geciktirmesin; görev başına
--        izolasyon (savepoint) korunduğu için sıra değişimi güvenli.
--   R3.1 (#7) start_first_service_protocol: zincir kurulduktan sonra hayvanın
--        açık `TOHUMLAMA_PLANLI` + `kaynak LIKE 'PG_TOHUMLAMA:%'` görevleri
--        (S-5 PG-sonrası görev) iptal edilir (`kapatan_ref='ILK_TOH_PROTOKOL_
--        YERINE:<case_id>'`); iptal edilen id'ler dönüşte (`pg_gorev_iptal`) ve
--        `FIRST_SERVICE_PROTOCOL_STARTED` payload'ında yer alır — tek açık D60
--        TAI kartı kalsın.
--   R3.1 (#8) tohumlama_abort kancası: `_ilk_tohumlama_rota_kur`'a geçen olay
--        tarihi artık `COALESCE(p_abort_tarihi, (now() AT TIME ZONE
--        'Europe/Istanbul')::date)` (fonksiyonun kendi `DEFAULT CURRENT_DATE`
--        parametresi UTC kalır — Kapsam dışı #6, dokunulmadı).
--
-- MK5: bayrak (_ovsync_pg_aktif) kapalıyken _ilk_tohumlama_rota_kur ilk satırda NULL
--   döner → dogum_kaydet ve tohumlama_abort yan etkileri tabanla bit bit aynı.
--   start_first_service_protocol bayrak kapalıyken OZELLIK_KAPALI hatası verir;
--   ilk_tohumlama_zamanlayici {ok:true, atlandi:'KAPALI'} döner (yazma yok).
--
-- Bağımlılık: 000001 (dogum_kaydet D39), 000002 (_ovsync_pg_aktif,
--   tedavi_sablonu.protokol_ailesi, cases.protocol_family), 000003, 000005.
-- ACL: tüm fonksiyonlarda REVOKE ALL FROM PUBLIC, anon. RPC'ler authenticated'a
--   açık; _ilk_tohumlama_rota_kur iç yardımcıdır (default ACL'in verdiği
--   authenticated EXECUTE açıkça geri alınır).
-- İç transaction deyimi YOK.
--
-- ROLLBACK (elle):
--   SELECT cron.unschedule('ilk-tohumlama-ovsync-baslat');  -- pg_cron varsa
--   DROP FUNCTION IF EXISTS public.ilk_tohumlama_zamanlayici();
--   DROP FUNCTION IF EXISTS public.start_first_service_protocol(uuid);
--   dogum_kaydet → 20260923000001 gövdesi; tohumlama_abort(text,text,date) → canlı
--     2026-09-23 gövdesi; tohumlama_abort(text,text) → canlı 2 argümanlı gövde
--     (gerekirse); GRANT EXECUTE ON FUNCTION public.abort_kaydet(text,text) TO authenticated;
--   DROP FUNCTION IF EXISTS public._ilk_tohumlama_rota_kur(text, date, text);
--   Veri: gorev_log gorev_tipi='OVSYNC_BASLAT' ve protokol_instance
--     alttip='ILK_TOHUMLAMA' satırları (bayrak açıldıktan sonra oluşur).
--   NOTIFY pgrst, 'reload schema';
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════════
-- S-8  _ilk_tohumlama_rota_kur — iç yardımcı
-- ════════════════════════════════════════════════════════════════════════════
-- Dönüş: oluşturulan OVSYNC_BASLAT görevinin id'si; bayrak kapalı ya da aynı
-- kaynak_ref zaten varsa (ikiz doğum T19, yarış T18) NULL.
-- protokol_instance.durum: CHECK yok; kullanılan değerler 'aktif' | 'iptal' |
-- 'tamamlandi' [canlı 2026-09-23]. kaynak_ref UNIQUE = protokol_instance_kaynak_unique.
-- gorev_log.gorev_tipi üzerinde CHECK yok [canlı] → 'OVSYNC_BASLAT' yeni tip.
CREATE OR REPLACE FUNCTION public._ilk_tohumlama_rota_kur(p_hayvan_id text, p_olay_tarihi date, p_kaynak_ref text)
 RETURNS uuid
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_inst_id       uuid;
  v_gorev_id      uuid;
  v_iptal_gorev   uuid[];
  v_iptal_inst    uuid[];
BEGIN
  -- MK5: bayrak kapalı → hiçbir yan etki yok
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN NULL;
  END IF;

  IF p_hayvan_id IS NULL OR p_olay_tarihi IS NULL OR COALESCE(p_kaynak_ref, '') = '' THEN
    RAISE EXCEPTION 'ILK_TOH_ROTA_PARAMETRE:%', jsonb_build_object(
      'hayvan_id', p_hayvan_id, 'olay_tarihi', p_olay_tarihi, 'kaynak_ref', p_kaynak_ref);
  END IF;

  -- Idempotens önce: aynı olay ikinci kez gelirse mevcut rotaya DOKUNULMAZ
  -- (önce iptal edip sonra çakışmaya düşmek doğru görevi öldürürdü).
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'ILK_TOHUMLAMA', p_kaynak_ref, p_olay_tarihi, 'aktif')
  ON CONFLICT (kaynak_ref) DO NOTHING
  RETURNING id INTO v_inst_id;
  IF v_inst_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Yeni olay eski rotanın yerine geçer: açık OVSYNC_BASLAT görevleri iptal
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_YENI_OLAY'
     WHERE hayvan_id = p_hayvan_id
       AND gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_iptal_gorev FROM u;

  -- ... ve hayvanın diğer aktif ILK_TOHUMLAMA instance'ları
  WITH u AS (
    UPDATE public.protokol_instance
       SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_YENI_OLAY'
     WHERE hayvan_id = p_hayvan_id
       AND alttip = 'ILK_TOHUMLAMA'
       AND durum = 'aktif'
       AND id <> v_inst_id
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_iptal_inst FROM u;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat,
                                tamamlandi, kaynak, protokol_instance_id)
  VALUES (gen_random_uuid(), p_hayvan_id, 'OVSYNC_BASLAT',
          'D50: Ovsynch-56 başlat (ilk tohumlama hedefi D60)',
          p_olay_tarihi + 50, '10:00'::time, false, p_kaynak_ref, v_inst_id)
  RETURNING id INTO v_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_ROUTE_CREATED', p_hayvan_id, v_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', v_gorev_id, 'protokol_instance_id', v_inst_id,
            'kaynak_ref', p_kaynak_ref, 'olay_tarihi', p_olay_tarihi,
            'hedef_tarih', p_olay_tarihi + 50, 'hedef_saat', '10:00',
            'iptal_edilen_gorev_ids', to_jsonb(v_iptal_gorev),
            'iptal_edilen_instance_ids', to_jsonb(v_iptal_inst)),
          '{}'::jsonb);

  RETURN v_gorev_id;
END;
$fn$;

COMMENT ON FUNCTION public._ilk_tohumlama_rota_kur(text, date, text) IS
  'S-8: doğum/abort → D50 OVSYNC_BASLAT görevi + UREME/ILK_TOHUMLAMA instance. Bayrak kapalı ya da kaynak_ref mevcut → NULL. İç yardımcı.';

REVOKE ALL ON FUNCTION public._ilk_tohumlama_rota_kur(text, date, text) FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- S-8  dogum_kaydet — taban 20260923000001 (D39); iki fark:
--      (1) SET search_path = public, pg_temp
--      (2) v_anne_yan_etki dalının sonunda _ilk_tohumlama_rota_kur kancası
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip text DEFAULT 'Normal'::text, p_kg numeric DEFAULT NULL::numeric, p_baba text DEFAULT NULL::text, p_hekim_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_anne           record;
  v_dogum_id       uuid := gen_random_uuid();
  v_buzagi_id      text;
  v_ana_gorev      uuid := gen_random_uuid();
  v_sayac          integer := 0;
  v_dup            text;
  v_baba_bilgi     text;
  v_anne_inst_id   uuid;
  v_buzagi_inst_id uuid;
  v_olay_id        uuid;
  v_ikinci         boolean := false;
  v_anne_yan_etki  boolean := true;
  v_yavru_sirasi   integer;
BEGIN
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı'); END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE (kupe_no = p_kupe AND durum = 'Aktif') OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe); END IF;

  -- K5: erkek buzağı sayısal küpesi 500-599 aralığında olmalı (::numeric — int4 overflow koruması)
  IF p_cins = 'Erkek' AND p_kupe ~ '^[0-9]+$'
     AND (p_kupe::numeric < 500 OR p_kupe::numeric > 599) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Erkek buzağı küpesi 500-599 aralığında olmalı (girilen: ' || p_kupe || ')');
  END IF;

  -- İKİZ GUARD: aynı anne + aynı yavru küpesi zaten kayıtlıysa reddet (typo → yanlış ikiz engeli)
  IF EXISTS (SELECT 1 FROM public.dogum WHERE anne_id = p_anne_id AND yavru_kupe = p_kupe) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe bu annenin yavrusu olarak zaten kayıtlı: ' || p_kupe);
  END IF;

  -- OLAY PENCERESİ (10 gün): yakın doğum varsa aynı olaya bağlanır (ikiz/üçüz)
  SELECT olay_id INTO v_olay_id FROM public.dogum
   WHERE anne_id = p_anne_id AND tarih BETWEEN p_tarih - 10 AND p_tarih
   ORDER BY tarih DESC LIMIT 1;
  v_ikinci := v_olay_id IS NOT NULL;

  -- ANNE GÖREV GUARD'I (60 gün): yakın doğum varsa anne yan etkileri ASLA tekrarlanmaz
  -- (9 görev + tohumlama kapatma + grup/padok + protokol + BESLEME iptali)
  IF EXISTS (SELECT 1 FROM public.dogum
             WHERE anne_id = p_anne_id AND tarih BETWEEN p_tarih - 60 AND p_tarih) THEN
    v_anne_yan_etki := false;
  END IF;

  IF NOT v_ikinci THEN v_olay_id := gen_random_uuid(); END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe' ORDER BY tarih DESC LIMIT 1;
    -- 2. yavru dalında Gebe tohumlama yoktur: babayı olayın ilk doğumundan al
    IF v_baba_bilgi IS NULL AND v_ikinci THEN
      SELECT baba_bilgi INTO v_baba_bilgi FROM public.dogum
      WHERE olay_id = v_olay_id AND baba_bilgi IS NOT NULL ORDER BY tarih DESC LIMIT 1;
    END IF;
  ELSE v_baba_bilgi := p_baba; END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi, olay_id)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi, v_olay_id);

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  -- buzagi_id baglama (Task 0.5, spec Rev 2 par.2): dogum satirini buzagiya ayni transaction icinde bagla
  UPDATE public.dogum SET buzagi_id = v_buzagi_id WHERE id = v_dogum_id;

  SELECT COUNT(*) INTO v_yavru_sirasi FROM public.dogum WHERE olay_id = v_olay_id;

  IF v_anne_yan_etki THEN
    UPDATE public.hayvanlar SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok' WHERE id = p_anne_id;

    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (p_anne_id, 'UREME', 'DOGUM', 'DOGUM-' || p_anne_id, p_tarih, 'aktif')
    ON CONFLICT (kaynak_ref) DO UPDATE SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
    RETURNING id INTO v_anne_inst_id;
    IF v_anne_inst_id IS NULL THEN
      SELECT id INTO v_anne_inst_id FROM public.protokol_instance WHERE kaynak_ref = 'DOGUM-' || p_anne_id;
    END IF;

    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
    VALUES
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih,      false, 'DOGUM-' || p_anne_id, 'OKSITOSIN', v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih,      false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih,      false, 'DOGUM-' || p_anne_id, 'KALSIYUM',  v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '39. Gün PG (Presynch-14 senkron)', p_tarih + 39, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: E Vitamini',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'DIGER','⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL, v_anne_inst_id);

    UPDATE public.tohumlama
    SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';
    GET DIAGNOSTICS v_sayac = ROW_COUNT;

    UPDATE public.gorev_log SET iptal = true
    WHERE hayvan_id = p_anne_id AND gorev_tipi = 'BESLEME' AND tamamlandi = false AND iptal = false;

    UPDATE public.protokol_instance SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'DOGUM'
    WHERE hayvan_id = p_anne_id AND alttip = 'BESLEME' AND durum = 'aktif';

    -- S-8: ilk tohumlama rotası (D50 OVSYNC_BASLAT). Bayrak kapalıyken NULL döner,
    -- yan etki yok (MK5). İkiz/üçüz ikinci yavru bu dala girmez; girse de
    -- kaynak_ref (olay_id) UNIQUE ile idempotent.
    PERFORM public._ilk_tohumlama_rota_kur(p_anne_id, p_tarih, 'ILK-TOH-DOGUM-' || v_olay_id::text);
  END IF;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (v_buzagi_id, 'BAKIM', 'BUZAGI', 'BUZAGI-' || v_buzagi_id, p_tarih, 'aktif')
  RETURNING id INTO v_buzagi_inst_id;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id);

  RETURN jsonb_build_object(
    'ok', true, 'buzagi_id', v_buzagi_id, 'dogum_id', v_dogum_id,
    'gorev_sayisi', (CASE WHEN v_anne_yan_etki THEN 8 ELSE 0 END) + 7,
    'anne_inst_id', v_anne_inst_id,
    'buzagi_inst_id', v_buzagi_inst_id, 'tohumlama_kapatildi', v_sayac,
    'coklu_dogum', v_ikinci, 'olay_id', v_olay_id, 'yavru_sirasi', v_yavru_sirasi
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.dogum_kaydet(text, date, text, text, text, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text, date, text, text, text, numeric, text, text) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- S-9  tohumlama_abort(text, text) — 2 argümanlı overload DROP
-- ════════════════════════════════════════════════════════════════════════════
-- Canlıda iki overload birlikte → 2 argümanlı çağrı 42725 'not unique'.
-- js/ doğrulaması (2026-09-23): tek çağrı js/forms.js:2645 rpc('tohumlama_abort',
-- {p_tohumlama_id, p_notlar, p_abort_tarihi}) — isimli, 3 argüman. DB içinde
-- tohumlama_abort çağıran fonksiyon yok. Eski gövde görev/instance temizliği yapmıyordu.
DROP FUNCTION IF EXISTS public.tohumlama_abort(text, text);


-- ════════════════════════════════════════════════════════════════════════════
-- S-8  tohumlama_abort(text, text, date) — taban canlı gövde; iki fark:
--      (1) SET search_path = public, pg_temp
--      (2) başarılı abort sonrası _ilk_tohumlama_rota_kur kancası
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.tohumlama_abort(p_tohumlama_id text, p_notlar text DEFAULT NULL::text, p_abort_tarihi date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_toh           record;
  v_islem_id      text := gen_random_uuid()::text;
  v_onceki_durum  text;
  v_onceki_tarih  date;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı'); END IF;
  IF v_toh.sonuc != 'Gebe' THEN RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe durumundaki tohumlama abort edilebilir'); END IF;
  IF p_abort_tarihi > CURRENT_DATE THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Abort tarihi ileri tarih olamaz');
  END IF;
  IF p_abort_tarihi < v_toh.tarih THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Abort tarihi, tohumlama tarihinden (' || v_toh.tarih || ') önce olamaz');
  END IF;
  SELECT tohumlama_durumu, tohumlama_onay_tarihi INTO v_onceki_durum, v_onceki_tarih FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil'); END IF;
  UPDATE public.tohumlama SET sonuc = 'Abort', abort_notlar = p_notlar, abort_tarihi = COALESCE(p_abort_tarihi, CURRENT_DATE) WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = NULL, tohumlama_onay_tarihi = NULL WHERE id = v_toh.hayvan_id;

  -- REVIEW #10: bu tohumlamadan doğan açık görev (21/35g gebelik kontrolü vb.)
  -- ve protokol scaffold'unu kapat — gebe/dogum yolları kendi temizliğini yapıyordu
  UPDATE public.gorev_log
  SET iptal = true
  WHERE kaynak = 'TOH-' || v_toh.id::text
    AND tamamlandi = false AND iptal = false;
  UPDATE public.protokol_instance
  SET durum = 'iptal'
  WHERE kaynak_ref = 'TOH-' || v_toh.id::text AND durum = 'aktif';

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (v_islem_id, 'ABORT_KAYDI', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object('olusturulan', '[]'::jsonb, 'guncellenen', jsonb_build_array(jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc, 'abort_tarihi', v_toh.abort_tarihi)), jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum, 'tohumlama_onay_tarihi', v_onceki_tarih))), 'notlar', p_notlar));

  -- S-8: ilk tohumlama rotası; D50 sayacı abort GERÇEKLEŞME tarihinden (K2).
  -- Bayrak kapalıyken NULL döner, yan etki yok (MK5). R3.1: olay tarihi
  -- İstanbul yerel bugünüyle (fonksiyonun kendi DEFAULT CURRENT_DATE'i UTC
  -- kalır — Kapsam dışı #6, dokunulmaz); yalnız NULL geldiğinde bu kanca
  -- İstanbul gününü kullanır.
  PERFORM public._ilk_tohumlama_rota_kur(v_toh.hayvan_id,
                                         COALESCE(p_abort_tarihi, (now() AT TIME ZONE 'Europe/Istanbul')::date),
                                         'ILK-TOH-ABORT-' || v_toh.id::text);
  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.tohumlama_abort(text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_abort(text, text, date) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- S-9  abort_kaydet — authenticated EXECUTE geri alınır
-- ════════════════════════════════════════════════════════════════════════════
-- js/ doğrulaması (2026-09-23): çağrı YOK. js/api.js:306 yalnız RPC→pull-tablo
-- haritası girdisi (çağrı değil). DB içinde çağıran fonksiyon yok. Eski yol:
-- SECURITY INVOKER, görev/instance temizliği ve islem_log yazmaz. DROP edilmez.
DO $$
BEGIN
  IF to_regprocedure('public.abort_kaydet(text, text)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.abort_kaydet(text, text) FROM PUBLIC, anon, authenticated';
  ELSE
    RAISE NOTICE 'S-9: public.abort_kaydet(text, text) yok — REVOKE atlandı';
  END IF;
END $$;


-- ════════════════════════════════════════════════════════════════════════════
-- S-8  start_first_service_protocol — D50 atomik zincir (RPC)
-- ════════════════════════════════════════════════════════════════════════════
-- Hata biçimi: RAISE EXCEPTION '<KOD>:<json detay>' (000003 üslubu). Herhangi bir
-- adım başarısızsa tüm zincir geri alınır (tek transaction; yarım zincir yok).
-- Dönüş şekli kontrolleri (canlı gövdeler):
--   _vaka_ac_tek                         {ok, case_id} | {ok:false, mesaj}
--   tedavi_sablon_uygula                 {ok, gun_sayisi, seans_sayisi, atlanan[]} | {ok:false, mesaj}
--       atlanan > 0 (silinmiş ilaç/stok) ya da seans 0 → eksik protokol → hata
--   tedavi_sablon_tohumlama_gorev_ekle   {ok:true, olustu:true, gorev_id} |
--       {ok:true, olustu:false[, sebep]} (plan yok/eksik, zaten var, uygunsuz) → hata (D60 TAI'siz zincir yok)
CREATE OR REPLACE FUNCTION public.start_first_service_protocol(p_gorev_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_g           record;
  v_h           record;
  v_olay        date;
  v_neden       text;
  v_son_sonuc   text;
  v_bugun       date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_s           date;
  v_sablon_id   uuid;
  v_disease_id  uuid;
  v_n           integer;
  v_res         jsonb;
  v_sab         jsonb;
  v_top         jsonb;
  v_case_id     uuid;
  v_tai_id      uuid;
  v_d58         uuid[];
  v_pg_gorev_iptal uuid[];
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RAISE EXCEPTION 'OZELLIK_KAPALI:%', jsonb_build_object(
      'bayrak', 'ovsync_pg_kurallari_aktif', 'gorev_id', p_gorev_id);
  END IF;

  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_BULUNAMADI:%', jsonb_build_object('gorev_id', p_gorev_id);
  END IF;
  IF v_g.gorev_tipi IS DISTINCT FROM 'OVSYNC_BASLAT' THEN
    RAISE EXCEPTION 'GOREV_TIPI_UYUMSUZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RETURN jsonb_build_object('ok', true, 'zaten', true, 'gorev_id', p_gorev_id,
      'iptal', COALESCE(v_g.iptal, false), 'kapatan_ref', v_g.kapatan_ref);
  END IF;

  -- Olay tarihi = rota instance başlangıcı (yoksa hedef − 50)
  SELECT baslangic INTO v_olay FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  v_olay := COALESCE(v_olay, v_g.hedef_tarih - 50);

  -- ── Otomatik muafiyetler (K4) ──────────────────────────────────────────
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_g.hayvan_id FOR UPDATE;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSIF EXISTS (SELECT 1 FROM public.tohumlama t
                 WHERE t.hayvan_id = v_g.hayvan_id
                   AND t.tarih >= v_olay
                   AND ('ILK-TOH-ABORT-' || t.id::text) IS DISTINCT FROM v_g.kaynak) THEN
    v_neden := 'TOHUMLAMA_VAR';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu
    SELECT t.sonuc INTO v_son_sonuc FROM public.tohumlama t
     WHERE t.hayvan_id = v_g.hayvan_id
     ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
     LIMIT 1;
    IF v_son_sonuc = 'Gebe' THEN
      v_neden := 'GEBE';
    ELSIF EXISTS (SELECT 1 FROM public.cases c
                   WHERE c.animal_id = v_g.hayvan_id
                     AND c.status = 'active'
                     AND c.protocol_family IS NOT NULL) THEN
      v_neden := 'AKTIF_SENKRONIZASYON';
    END IF;
  END IF;

  IF v_neden IS NOT NULL THEN
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = p_gorev_id;
    UPDATE public.protokol_instance
       SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'ILK_TOH_MUAF:' || v_neden
     WHERE id = v_g.protokol_instance_id AND durum = 'aktif';
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_SKIPPED', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
            jsonb_build_object('gorev_id', p_gorev_id, 'neden', v_neden,
              'kaynak', v_g.kaynak, 'olay_tarihi', v_olay, 'hedef_tarih', v_g.hedef_tarih),
            '{}'::jsonb);
    RETURN jsonb_build_object('ok', true, 'atlandi', v_neden, 'gorev_id', p_gorev_id);
  END IF;

  -- ── Başlangıç, şablon, hastalık ───────────────────────────────────────
  v_s := GREATEST(v_g.hedef_tarih, v_bugun);

  SELECT count(*), (array_agg(id))[1] INTO v_n, v_sablon_id
    FROM public.tedavi_sablonu
   WHERE protokol_ailesi = 'OVSYNC' AND aktif IS TRUE;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'aktif_ovsync_sablon_sayisi', v_n);
  END IF;

  SELECT count(DISTINCT disease_id), (array_agg(DISTINCT disease_id))[1] INTO v_n, v_disease_id
    FROM public.sablon_hastalik_eslem
   WHERE sablon_id = v_sablon_id;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'OVSYNC_HASTALIK_BELIRSIZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sablon_id', v_sablon_id, 'hastalik_sayisi', v_n);
  END IF;

  -- ── Atomik zincir ──────────────────────────────────────────────────────
  v_res := public._vaka_ac_tek(v_g.hayvan_id, v_disease_id, 'İlk tohumlama zinciri (D50)', v_s);
  IF (v_res->>'ok') IS DISTINCT FROM 'true' OR (v_res->>'case_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_ACILAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'hayvan_id', v_g.hayvan_id, 'sonuc', v_res);
  END IF;
  v_case_id := (v_res->>'case_id')::uuid;

  v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                       p_baslangic_tarihi := v_s);
  IF (v_sab->>'ok') IS DISTINCT FROM 'true'
     OR COALESCE((v_sab->>'seans_sayisi')::int, 0) = 0
     OR COALESCE(jsonb_array_length(v_sab->'atlanan'), 0) > 0 THEN
    RAISE EXCEPTION 'OVSYNC_SABLON_UYGULANAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_sab);
  END IF;

  v_top := public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := v_sablon_id,
                                                     p_baslangic_tarihi := v_s);
  IF (v_top->>'ok') IS DISTINCT FROM 'true'
     OR (v_top->>'olustu') IS DISTINCT FROM 'true'
     OR (v_top->>'gorev_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_TAI_OLUSMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'case_id', v_case_id, 'sablon_id', v_sablon_id, 'sonuc', v_top);
  END IF;
  v_tai_id := (v_top->>'gorev_id')::uuid;

  -- ── SK4: doğum protokolünün 58. gün kızgınlık takibi iptal (53. gün E-vit kalır)
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_D58_IPTAL'
     WHERE hayvan_id = v_g.hayvan_id
       AND kaynak = 'DOGUM-' || v_g.hayvan_id
       AND gorev_tipi = 'DIGER'
       AND aciklama ILIKE '%kızgınlık takibi%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
       AND hedef_tarih BETWEEN v_olay + 50 AND v_olay + 70
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_d58 FROM u;

  -- ── R3.1: zincir kuruldu — hayvanın açık PG sonrası TOHUMLAMA_PLANLI
  -- görevleri (S-5, kaynak 'PG_TOHUMLAMA:<event>') artık bu D60 TAI'nin
  -- yerine geçti; tek açık TAI kartı kalsın diye iptal edilir. Az önce
  -- tedavi_sablon_tohumlama_gorev_ekle ile açılan TAI görevi kaynak
  -- 'TEDAVI_SABLON_TOHUMLAMA:…' taşır → bu WHERE'e girmez.
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true,
           kapatan_ref = 'ILK_TOH_PROTOKOL_YERINE:' || v_case_id::text
     WHERE hayvan_id = v_g.hayvan_id
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND kaynak LIKE 'PG_TOHUMLAMA:%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_gorev_iptal FROM u;

  -- ── Görev ve rota kapanışı + audit ───────────────────────────────────
  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = 'case:' || v_case_id::text
   WHERE id = p_gorev_id;
  UPDATE public.protokol_instance
     SET durum = 'tamamlandi', kapandi_at = now(), kapandi_sebep = 'case:' || v_case_id::text
   WHERE id = v_g.protokol_instance_id AND durum = 'aktif';

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_PROTOCOL_STARTED', v_g.hayvan_id, v_case_id::text, 'cases',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'case_id', v_case_id,
            'sablon_id', v_sablon_id, 'disease_id', v_disease_id,
            'baslangic', v_s, 'olay_tarihi', v_olay, 'kaynak', v_g.kaynak,
            'tohumlama_gorev_id', v_tai_id,
            'seans_sayisi', (v_sab->>'seans_sayisi')::int,
            'd58_iptal', to_jsonb(v_d58),
            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal)),
          '{}'::jsonb);

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id, 'tohumlama_gorev_id', v_tai_id,
                            'baslangic', v_s, 'd58_iptal', to_jsonb(v_d58),
                            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal));
END;
$fn$;

COMMENT ON FUNCTION public.start_first_service_protocol(uuid) IS
  'S-8: açık OVSYNC_BASLAT görevinden Ovsync vakası + seanslar + D60 TAI görevini tek transaction''da kurar; muafiyetlerde görevi iptal eder.';

REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- S-8  ilk_tohumlama_zamanlayici — günlük toplu başlatıcı (RPC + pg_cron)
-- ════════════════════════════════════════════════════════════════════════════
-- Her görev kendi BEGIN … EXCEPTION alt bloğunda (savepoint): bir görevin hatası
-- yalnız o görevin yarım zincirini geri alır, hatalar[]'a yazılır; sessiz yutma yok.
-- Üst sınır 200/koşum; kalan sayı dönüşte ve audit'te raporlanır.
CREATE OR REPLACE FUNCTION public.ilk_tohumlama_zamanlayici()
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  c_limit       constant integer := 200;
  v_bugun       date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  r             record;
  v_res         jsonb;
  v_islenen     integer := 0;
  v_baslatilan  integer := 0;
  v_atlanan     integer := 0;
  v_zaten       integer := 0;
  v_kalan       integer := 0;
  v_basl_liste  jsonb := '[]'::jsonb;
  v_atl_liste   jsonb := '[]'::jsonb;
  v_hatalar     jsonb := '[]'::jsonb;
  v_ozet        jsonb;
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN jsonb_build_object('ok', true, 'atlandi', 'KAPALI');
  END IF;

  -- R3.1 (#6): en yeni görev önce. Kalıcı hatalı eski bir görev (ör. her koşumda
  -- OVSYNC_SABLON_BELIRSIZ ile patlayan) limit-200 kuyruğunun başında sonsuza
  -- kadar oturup yeni hayvanların D50 başlangıcını engellemesin; her görev kendi
  -- BEGIN…EXCEPTION alt bloğunda izole olduğu için sıra değişimi atomiklik/
  -- idempotens bozmaz, yalnız işlem önceliğini değiştirir.
  FOR r IN
    SELECT g.id, g.hayvan_id, g.hedef_tarih
      FROM public.gorev_log g
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= v_bugun
     ORDER BY g.hedef_tarih DESC, g.id
     LIMIT c_limit
  LOOP
    v_islenen := v_islenen + 1;
    BEGIN
      v_res := public.start_first_service_protocol(r.id);
      IF v_res ? 'atlandi' THEN
        v_atlanan := v_atlanan + 1;
        v_atl_liste := v_atl_liste || jsonb_build_array(jsonb_build_object(
          'gorev_id', r.id, 'hayvan_id', r.hayvan_id, 'neden', v_res->>'atlandi'));
      ELSIF COALESCE((v_res->>'zaten')::boolean, false) THEN
        v_zaten := v_zaten + 1;
      ELSE
        v_baslatilan := v_baslatilan + 1;
        v_basl_liste := v_basl_liste || jsonb_build_array(jsonb_build_object(
          'gorev_id', r.id, 'hayvan_id', r.hayvan_id, 'case_id', v_res->'case_id',
          'tohumlama_gorev_id', v_res->'tohumlama_gorev_id'));
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
        'gorev_id', r.id, 'hayvan_id', r.hayvan_id, 'hedef_tarih', r.hedef_tarih,
        'sqlstate', SQLSTATE, 'mesaj', SQLERRM));
    END;
  END LOOP;

  IF v_islenen = c_limit THEN
    SELECT count(*) - c_limit INTO v_kalan
      FROM public.gorev_log g
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= v_bugun;
    v_kalan := GREATEST(v_kalan, 0);
  END IF;

  v_ozet := jsonb_build_object(
    'ok', jsonb_array_length(v_hatalar) = 0,
    'tarih', v_bugun, 'limit', c_limit, 'islenen', v_islenen,
    'baslatilan', v_baslatilan, 'atlanan', v_atlanan, 'zaten', v_zaten,
    'hata_sayisi', jsonb_array_length(v_hatalar), 'kalan', v_kalan,
    'baslatilanlar', v_basl_liste, 'atlananlar', v_atl_liste, 'hatalar', v_hatalar);

  -- Özet audit yalnız iş bulunduğunda (boş günlük koşum islem_log'u şişirmez)
  IF v_islenen > 0 THEN
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_CRON', NULL, NULL, 'gorev_log', v_ozet, '{}'::jsonb);
  END IF;

  RETURN v_ozet;
END;
$fn$;

COMMENT ON FUNCTION public.ilk_tohumlama_zamanlayici() IS
  'S-8: hedefi gelmiş açık OVSYNC_BASLAT görevlerini (≤200) start_first_service_protocol ile başlatır; görev başına izole, hatalar dönüşte. Bayrak kapalı → atlandi:KAPALI.';

REVOKE ALL ON FUNCTION public.ilk_tohumlama_zamanlayici() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ilk_tohumlama_zamanlayici() TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- S-8  pg_cron: 'ilk-tohumlama-ovsync-baslat' '0 4 * * *' (UTC 04:00 = 07:00 İstanbul)
-- ════════════════════════════════════════════════════════════════════════════
-- Kalıp: 20260622000001_agent_plans.sql. cron şeması/fonksiyonları yoksa NOTICE.
DO $$
BEGIN
  IF to_regclass('cron.job') IS NULL
     OR to_regprocedure('cron.schedule(text, text, text)') IS NULL
     OR to_regprocedure('cron.unschedule(text)') IS NULL THEN
    RAISE NOTICE 'S-8: pg_cron yok — ilk-tohumlama-ovsync-baslat job''ı kurulmadı (elle: SELECT cron.schedule(''ilk-tohumlama-ovsync-baslat'',''0 4 * * *'',''select public.ilk_tohumlama_zamanlayici()''))';
    RETURN;
  END IF;
  PERFORM cron.unschedule('ilk-tohumlama-ovsync-baslat')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ilk-tohumlama-ovsync-baslat');
  PERFORM cron.schedule('ilk-tohumlama-ovsync-baslat', '0 4 * * *',
                        'select public.ilk_tohumlama_zamanlayici()');
END $$;


NOTIFY pgrst, 'reload schema';

-- EOF 20260923000006
