-- ============================================================================
-- Migration: 20260924000001_ovsync_pg_r32_acik_disi
-- Tarih: 2026-09-24
-- Otorite: docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md §R3.2
--          (SK6–SK10, sahip kararları 2026-09-24) + root promptu
--          docs/plans/2026-09-24-ovsync-pg-root-ultracode-prompt.md §A1.
-- Tabanlar:
--   _ilk_tohumlama_rota_kur, dogum_kaydet, tohumlama_abort,
--   start_first_service_protocol, ilk_tohumlama_zamanlayici
--     → 20260923000006 gövdeleri (kanonik; canlı değil).
--   tohumlama_sonuc_bos(text,text)  → canlı pg_get_functiondef (2026-09-23).
--   hayvan_ekle(15 argüman, padok_id'li) → canlı pg_get_functiondef (2026-09-23).
--     14 argümanlı legacy overload js/ çağrısız (forms.js:151 padok_id'li tek
--     çağrı); dokunulmaz — UI yolu değildir.
--   _vaka_kapat → 20260923000005.
--
-- NE YAPAR (SK6–SK10):
--   SK6  Gün sayımı: inekte başlangıç = son doğum/abort + 51 gün; düvede
--        dogum_tarihi + 12 ay + 21 gün. TAI şablondan (başlangıç + 10, 10:00).
--   SK7  _ovsync_kural_tarihi / _acik_disi_ovsync_hedef / _acik_disi_gorev_kur:
--        açık dişi kuralı — Boş çıkanlar dahil; muaf Gebe/Bekliyor/aktif
--        senkronizasyon/Aktif değil/açık OVSYNC_BASLAT. Hedef =
--        GREATEST(kural, bugün). Tabanı olmayan (dogum_tarihi NULL) raporlanır.
--   SK8  Tetikler (birincil = olay): dogum_kaydet anne +51 VE dişi buzağı →
--        düve kuralı; tohumlama_abort +51; tohumlama_sonuc_bos → kural fonksiyonu;
--        hayvan_ekle (15 arg) → uygunsa görev. Zamanlayıcı yalnız yedek:
--        (a) açık dişi taraması (cap 200) + (b) hedefi gelenleri başlatma.
--        p_dry_run parametresi: yazmadan listeler, BAYRAKTAN BAĞIMSIZ çalışır.
--        İmza değişti → eski () imzası DROP; cron komutu aynı kalır (DEFAULT).
--   SK9  ovsync_baslat_uyarilari() salt-okuma RPC: OVSYNC_BASLAT görevleri
--        hedef−2 günden itibaren (bayraktan bağımsız görünürlük; görev ancak
--        bayrak açıkken doğar).
--   SK10 _ovsync_gecis_sk10() + migration sonu çalıştırma: başlangıcından sonra
--        tohumlanmış ve AÇIK SEANSI OLMAYAN aktif Ovsync vakaları
--        _vaka_kapat(…,'TOHUMLAMA',…) ile kapatılır (bayraktan bağımsız, MK8).
--        Prod ölçümü 2026-09-24 (root): 10 vaka [OBSERVED]. Küpe 002'nin
--        vakası açık seansı olduğu için otomatik dışlanır.
--   start_first_service_protocol: muafiyet seti değişti — TOHUMLAMA_VAR KALKAR,
--        BEKLIYOR eklenir (SK7): AKTIF_DEGIL / GEBE / BEKLIYOR / AKTIF_SENKRONIZASYON.
--
-- MK5/MK8: yeni iş yaratan her adım bayrak (_ovsync_pg_aktif) arkasında;
--   kapanış/geçiş (SK10) bayraktan bağımsız. Bayrak kapalıyken tüm
--   recreate edilen fonksiyonlar 000006/canlı gövdeleriyle aynı yan etkiyi üretir.
-- MK9 kilit sırası korunur (hayvan → vaka → görev).
--
-- İdempotent: tüm CREATE OR REPLACE; DROP'lar IF EXISTS; SK10 ikinci koşumda 0.
-- ACL: REVOKE ALL FROM PUBLIC, anon; RPC'ler authenticated+service_role;
--   _ önekli iç yardımcılar authenticated'a kapalı. GRANT ... ON ALL FUNCTIONS YOK.
-- İç transaction deyimi YOK.
--
-- ROLLBACK (elle):
--   SELECT cron.unschedule('ilk-tohumlama-ovsync-baslat');
--   DROP FUNCTION IF EXISTS public.ovsync_baslat_uyarilari();
--   DROP FUNCTION IF EXISTS public._ovsync_gecis_sk10();
--   DROP FUNCTION IF EXISTS public._acik_disi_gorev_kur(text);
--   DROP FUNCTION IF EXISTS public._acik_disi_ovsync_hedef(text);
--   DROP FUNCTION IF EXISTS public._ovsync_baslat_gorev_kur(text, date, text, date);
--   DROP FUNCTION IF EXISTS public._ovsync_kural_tarihi(text);
--   20260923000006'daki gövdelere geri dön (ilk_tohumlama_zamanlayici(), _ilk_
--   tohumlama_rota_kur, dogum_kaydet, start_first_service_protocol;
--   tohumlama_sonuc_bos ve hayvan_ekle canlı gövdeye).
--   cron yeniden: SELECT cron.schedule('ilk-tohumlama-ovsync-baslat','0 4 * * *',
--     'select public.ilk_tohumlama_zamanlayici()');
--   NOTIFY pgrst, 'reload schema';
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════════
-- SK6/SK7  _ovsync_kural_tarihi — kural tarihi (salt hesap, uygunluk yok)
-- ════════════════════════════════════════════════════════════════════════════
-- İnek: GREATEST(son doğum, son abort) + 51. Düve (doğum/abort kaydı yok):
-- dogum_tarihi + 12 ay + 21 gün; dogum_tarihi NULL → NULL (görev açılmaz,
-- taramada raporlanır).
CREATE OR REPLACE FUNCTION public._ovsync_kural_tarihi(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_dogum date;
  v_abort date;
  v_dt    date;
BEGIN
  IF p_hayvan_id IS NULL THEN RETURN NULL; END IF;

  SELECT max(tarih) INTO v_dogum FROM public.dogum WHERE anne_id = p_hayvan_id;

  SELECT max(abort_tarihi) INTO v_abort FROM public.tohumlama
   WHERE hayvan_id = p_hayvan_id AND sonuc = 'Abort' AND abort_tarihi IS NOT NULL;

  IF v_dogum IS NOT NULL OR v_abort IS NOT NULL THEN
    RETURN GREATEST(COALESCE(v_dogum, '-infinity'::date),
                    COALESCE(v_abort, '-infinity'::date)) + 51;
  END IF;

  SELECT dogum_tarihi INTO v_dt FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF v_dt IS NULL THEN RETURN NULL; END IF;
  RETURN (v_dt + interval '12 months 21 days')::date;
END;
$fn$;

COMMENT ON FUNCTION public._ovsync_kural_tarihi(text) IS
  'R3.2 SK6: inek = GREATEST(son doğum, son abort) + 51; düve = dogum_tarihi + 12ay + 21g. Taban yoksa NULL.';

REVOKE ALL ON FUNCTION public._ovsync_kural_tarihi(text) FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- SK7/SK8  _ovsync_baslat_gorev_kur — çekirdek görev kurucu
-- ════════════════════════════════════════════════════════════════════════════
-- p_kural_tarihi = kural tarihi (SK6); hedef = GREATEST(kural, bugün) (MK11:
-- geç kalan ya da Boş çıkan hayvan bekletilmez). p_baslangic = olay/taban
-- tarihi (instance başlangıcı; start_first_service_protocol olay tarihi olarak
-- kullanır). Bayrak kapalı → NULL, yan etki yok (MK5).
CREATE OR REPLACE FUNCTION public._ovsync_baslat_gorev_kur(p_hayvan_id text, p_baslangic date, p_kaynak_ref text, p_kural_tarihi date)
 RETURNS uuid
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_inst_id     uuid;
  v_gorev_id    uuid;
  v_iptal_gorev uuid[];
  v_iptal_inst  uuid[];
  v_hedef       date;
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN NULL;
  END IF;

  IF p_hayvan_id IS NULL OR p_baslangic IS NULL OR p_kural_tarihi IS NULL
     OR COALESCE(p_kaynak_ref, '') = '' THEN
    RAISE EXCEPTION 'OVSYNC_BASLAT_PARAMETRE:%', jsonb_build_object(
      'hayvan_id', p_hayvan_id, 'baslangic', p_baslangic,
      'kaynak_ref', p_kaynak_ref, 'kural_tarihi', p_kural_tarihi);
  END IF;

  -- Idempotens önce (000006 kalıbı): aynı olay ikinci kez gelirse dokunulmaz
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'ILK_TOHUMLAMA', p_kaynak_ref, p_baslangic, 'aktif')
  ON CONFLICT (kaynak_ref) DO NOTHING
  RETURNING id INTO v_inst_id;
  IF v_inst_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Yeni rota eski açık rotanın yerine geçer
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

  v_hedef := GREATEST(p_kural_tarihi, (now() AT TIME ZONE 'Europe/Istanbul')::date);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat,
                                tamamlandi, kaynak, protokol_instance_id)
  VALUES (gen_random_uuid(), p_hayvan_id, 'OVSYNC_BASLAT',
          'Ovsynch-56 başlat (ilk tohumlama hedefi +10 gün)',
          v_hedef, '10:00'::time, false, p_kaynak_ref, v_inst_id)
  RETURNING id INTO v_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_ROUTE_CREATED', p_hayvan_id, v_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', v_gorev_id, 'protokol_instance_id', v_inst_id,
            'kaynak_ref', p_kaynak_ref, 'baslangic', p_baslangic,
            'kural_tarihi', p_kural_tarihi, 'hedef_tarih', v_hedef, 'hedef_saat', '10:00',
            'iptal_edilen_gorev_ids', to_jsonb(v_iptal_gorev),
            'iptal_edilen_instance_ids', to_jsonb(v_iptal_inst)),
          '{}'::jsonb);

  RETURN v_gorev_id;
END;
$fn$;

COMMENT ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date) IS
  'R3.2: OVSYNC_BASLAT görevi + ILK_TOHUMLAMA instance çekirdeği. Hedef = GREATEST(kural, bugün). Bayrak kapalı → NULL.';

REVOKE ALL ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date) FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- SK8  _ilk_tohumlama_rota_kur — olay kancası sarmalayıcısı (imza aynı;
--      000006'daki dogum_kaydet/tohumlama_abort çağrıları değişmez)
-- ════════════════════════════════════════════════════════════════════════════
-- p_olay_tarihi = olay (doğum/abort) tarihi. Kural tarihi hesaplanır:
--   anne (doğum) → dogum satırı işlenmiştir → +51;
--   dişi buzağı → doğum/abort kaydı yoktur → düve kuralı (dogum_tarihi + 12a21g);
--   abort → abort_tarihi işlenmiştir → +51.
-- Kural hesaplanamıyorsa (veri yarışı) olay + 51'e düşer (fail-safe).
CREATE OR REPLACE FUNCTION public._ilk_tohumlama_rota_kur(p_hayvan_id text, p_olay_tarihi date, p_kaynak_ref text)
 RETURNS uuid
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_kural date;
BEGIN
  v_kural := COALESCE(public._ovsync_kural_tarihi(p_hayvan_id), p_olay_tarihi + 51);
  RETURN public._ovsync_baslat_gorev_kur(p_hayvan_id, p_olay_tarihi, p_kaynak_ref, v_kural);
END;
$fn$;

COMMENT ON FUNCTION public._ilk_tohumlama_rota_kur(text, date, text) IS
  'R3.2 SK8: olay (doğum/abort/buzağı) kancası. Kural SK6 ile hesaplanır; hedef GREATEST(kural, bugün). Bayrak kapalı → NULL.';

REVOKE ALL ON FUNCTION public._ilk_tohumlama_rota_kur(text, date, text) FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- SK7  _acik_disi_ovsync_hedef — açık dişi hedefi (uygunluk dahil, salt-okuma)
-- ════════════════════════════════════════════════════════════════════════════
-- Uygunluk: Aktif + Dişi; son tohumlama (MK3 sıralaması) Gebe/Bekliyor değil;
-- aktif protocol_family vakası yok; açık OVSYNC_BASLAT yok; kural tabanı var.
-- Dönüş: hedef tarihi (GREATEST(kural, bugün)); uygun değilse NULL.
-- Bayrak kapalı → NULL (yeni iş yaratma adımıdır, MK5).
CREATE OR REPLACE FUNCTION public._acik_disi_ovsync_hedef(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_h   record;
  v_son text;
  v_k   date;
BEGIN
  IF NOT public._ovsync_pg_aktif() THEN
    RETURN NULL;
  END IF;

  SELECT durum, cinsiyet INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RETURN NULL;
  END IF;

  -- MK3: gebelik otoritesi = son tohumlamanın sonucu
  SELECT t.sonuc INTO v_son FROM public.tohumlama t
   WHERE t.hayvan_id = p_hayvan_id
   ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
   LIMIT 1;
  IF v_son IN ('Gebe', 'Bekliyor') THEN
    RETURN NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM public.cases c
              WHERE c.animal_id = p_hayvan_id
                AND c.status = 'active'
                AND c.protocol_family IS NOT NULL) THEN
    RETURN NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM public.gorev_log g
              WHERE g.hayvan_id = p_hayvan_id
                AND g.gorev_tipi = 'OVSYNC_BASLAT'
                AND COALESCE(g.tamamlandi, false) = false
                AND COALESCE(g.iptal, false) = false) THEN
    RETURN NULL;
  END IF;

  v_k := public._ovsync_kural_tarihi(p_hayvan_id);
  IF v_k IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN GREATEST(v_k, (now() AT TIME ZONE 'Europe/Istanbul')::date);
END;
$fn$;

COMMENT ON FUNCTION public._acik_disi_ovsync_hedef(text) IS
  'R3.2 SK7: açık dişi Ovsync hedefi. Muaf: Gebe/Bekliyor/aktif senkronizasyon/açık OVSYNC_BASLAT/Aktif değil/tabansız.';

REVOKE ALL ON FUNCTION public._acik_disi_ovsync_hedef(text) FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- SK8  _acik_disi_gorev_kur — sonuc_bos / hayvan_ekle / tarama sarmalayıcısı
-- ════════════════════════════════════════════════════════════════════════════
-- İdempotency anahtarı: 'ACIK-DISI-<hayvan_id>-<kural tarihi>' (protokol_
-- instance.kaynak_ref UNIQUE). Kural tarihi değişmedikçe ikinci çağrı NULL.
CREATE OR REPLACE FUNCTION public._acik_disi_gorev_kur(p_hayvan_id text)
 RETURNS uuid
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_hedef  date;
  v_kural  date;
  v_taban  date;
  v_dogum  date;
  v_abort  date;
BEGIN
  v_hedef := public._acik_disi_ovsync_hedef(p_hayvan_id);
  IF v_hedef IS NULL THEN
    RETURN NULL;
  END IF;

  v_kural := public._ovsync_kural_tarihi(p_hayvan_id);

  SELECT max(tarih) INTO v_dogum FROM public.dogum WHERE anne_id = p_hayvan_id;
  SELECT max(abort_tarihi) INTO v_abort FROM public.tohumlama
   WHERE hayvan_id = p_hayvan_id AND sonuc = 'Abort' AND abort_tarihi IS NOT NULL;

  IF v_dogum IS NOT NULL OR v_abort IS NOT NULL THEN
    v_taban := GREATEST(COALESCE(v_dogum, '-infinity'::date),
                        COALESCE(v_abort, '-infinity'::date));
  ELSE
    SELECT dogum_tarihi INTO v_taban FROM public.hayvanlar WHERE id = p_hayvan_id;
  END IF;

  RETURN public._ovsync_baslat_gorev_kur(
    p_hayvan_id, v_taban,
    'ACIK-DISI-' || p_hayvan_id || '-' || v_kural::text, v_kural);
END;
$fn$;

COMMENT ON FUNCTION public._acik_disi_gorev_kur(text) IS
  'R3.2 SK8: açık dişi için OVSYNC_BASLAT görevi (kaynak ACIK-DISI-<hayvan>-<kural>). Uygun değil → NULL.';

REVOKE ALL ON FUNCTION public._acik_disi_gorev_kur(text) FROM PUBLIC, anon, authenticated;


-- ════════════════════════════════════════════════════════════════════════════
-- SK8  dogum_kaydet — taban 20260923000006; tek fark: dişi buzağı kancası
--      (buzagi satırı doğduktan sonra, v_anne_yan_etki dışında — her dişi
--      buzağı düve rotasını alır; ikinci yavru da buzagi_id'si farklı olduğundan
--      kendi kaydını alır)
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

    UPDATE public.gorev_log SET iptal = true
    WHERE hayvan_id = p_anne_id AND gorev_tipi = 'BESLEME' AND tamamlandi = false AND iptal = false;

    UPDATE public.protokol_instance SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'DOGUM'
    WHERE hayvan_id = p_anne_id AND alttip = 'BESLEME' AND durum = 'aktif';

    -- S-8/R3.2: anne ilk tohumlama rotası (kural = bu doğum + 51). Bayrak
    -- kapalıyken NULL (MK5). İkiz/üçüz ikinci yavru bu dala girmez; girse de
    -- kaynak_ref (olay_id) UNIQUE ile idempotent.
    PERFORM public._ilk_tohumlama_rota_kur(p_anne_id, p_tarih, 'ILK-TOH-DOGUM-' || v_olay_id::text);
  END IF;

  -- R3.2 SK8: DİŞİ BUZAĞI → düve rotası (kural = dogum_tarihi + 12 ay 21 gün;
  -- _ovsync_kural_tarihi buzağı için düve dalına düşer). Kaynak buzağıya özgü
  -- olduğundan ikiz dişi yavruların her biri kendi rotasını alır. Erkek buzağı
  -- ve bayrak kapalı → NULL, yan etki yok.
  IF p_cins = 'Dişi' THEN
    PERFORM public._ilk_tohumlama_rota_kur(v_buzagi_id, p_tarih, 'ILK-TOH-DUVE-' || v_buzagi_id);
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
-- SK8  tohumlama_sonuc_bos — taban canlı gövde; farklar:
--      (1) SET search_path  (2) başarılı Boş sonucunda açık dişi görevi
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(p_tohumlama_id text, p_notlar text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_toh               record;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Boş' WHERE id = v_toh.hayvan_id;

  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'TOHUMLAMA_SONUC', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
      ),
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'bos'
    )
  );

  -- R3.2 SK8: Boş çıkan açık dişidir — kural fonksiyonuyla görev (bayrak
  -- kapalıyken NULL, yan etki yok). K3 "Boş ata" modalı bu RPC'yi çağırır;
  -- görev aynı akışta kurulur.
  PERFORM public._acik_disi_gorev_kur(v_toh.hayvan_id);

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.tohumlama_sonuc_bos(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_bos(text, text) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- SK8  hayvan_ekle (15 argüman, padok_id'li — UI yolu) — taban canlı gövde;
--      farklar: (1) SET search_path  (2) dişi kayıtta açık dişi görevi.
--      14 argümanlı legacy overload js/ çağrısızdır; dokunulmaz.
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.hayvan_ekle(p_kupe_no text DEFAULT NULL::text, p_devlet_kupe text DEFAULT NULL::text, p_irk text DEFAULT NULL::text, p_cinsiyet text DEFAULT NULL::text, p_dogum_tarihi date DEFAULT NULL::date, p_grup text DEFAULT 'Genel'::text, p_padok text DEFAULT NULL::text, p_dogum_kg numeric DEFAULT NULL::numeric, p_anne_id text DEFAULT NULL::text, p_baba_bilgi text DEFAULT NULL::text, p_canli_agirlik numeric DEFAULT NULL::numeric, p_boy numeric DEFAULT NULL::numeric, p_renk text DEFAULT NULL::text, p_ayirici_ozellik text DEFAULT NULL::text, p_padok_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_id text;
  v_padok_id uuid;
  v_padok_ad text;
  v_yas_gun integer;
  v_chk jsonb;
BEGIN
  -- Küpe çakışma kontrolü (K1/K2): işletme=aktif-filtreli, devlet=global
  SELECT public.kupe_musait_mi(p_kupe_no, p_devlet_kupe) INTO v_chk;
  IF NOT (v_chk->>'musait')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      CASE WHEN v_chk->>'kupe_cakisma_id' IS NOT NULL
        THEN 'İşletme küpesi zaten kayıtlı (aktif): ' || COALESCE(p_kupe_no,'')
        ELSE 'Devlet küpesi zaten kayıtlı: ' || COALESCE(p_devlet_kupe,'') END);
  END IF;

  -- H-11: Yaş/grup validasyonu (js/forms.js:66-77 birebir)
  IF p_dogum_tarihi IS NOT NULL THEN
    v_yas_gun := floor((current_date - p_dogum_tarihi));
    IF v_yas_gun < 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Doğum tarihi ileri tarih olamaz');
    END IF;
    IF p_grup = 'Süt İçen Buzağı' AND v_yas_gun > 180 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', '6 aylıktan büyük hayvan "Süt İçen Buzağı" grubuna eklenemez');
    END IF;
    IF (p_grup = 'Süt İçen Buzağı' OR p_grup = 'Sütten Kesilmiş Buzağı') AND v_yas_gun > 365 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', '12 aylıktan büyük hayvan buzağı grubuna eklenemez');
    END IF;
  END IF;

  v_id := gen_random_uuid()::text;

  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
    IF v_padok_id IS NULL THEN
      v_padok_ad := p_padok;
    END IF;
  END IF;

  INSERT INTO hayvanlar (
    id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
    grup, padok, padok_id, durum, dogum_kg, anne_id, baba_bilgi,
    canli_agirlik, boy, renk, ayirici_ozellik
  ) VALUES (
    v_id, NULLIF(p_kupe_no,''), NULLIF(p_devlet_kupe,''),
    NULLIF(p_irk,''), p_cinsiyet, p_dogum_tarihi,
    p_grup, v_padok_ad, v_padok_id, 'Aktif', p_dogum_kg, p_anne_id, p_baba_bilgi,
    p_canli_agirlik, p_boy, p_renk, p_ayirici_ozellik
  );

  -- R3.2 SK8: dişi kayıt → açık dişi görevi (dogum_tarihi NULL ise kural
  -- tabanı yok → _acik_disi_gorev_kur NULL; taramada raporlanır).
  -- Bayrak kapalıyken NULL, yan etki yok.
  IF p_cinsiyet = 'Dişi' THEN
    PERFORM public._acik_disi_gorev_kur(v_id);
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.hayvan_ekle(text, text, text, text, date, text, text, numeric, text, text, numeric, numeric, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hayvan_ekle(text, text, text, text, date, text, text, numeric, text, text, numeric, numeric, text, text, uuid) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- SK7  start_first_service_protocol — taban 20260923000006; tek fark:
--      muafiyet seti. TOHUMLAMA_VAR KALKAR (SK7), BEKLIYOR eklenir:
--      AKTIF_DEGIL / GEBE / BEKLIYOR / AKTIF_SENKRONIZASYON.
--      (tohumlama_kaydet'in açık OVSYNC_BASLAT'ı ILK_TOH_MUAF:TOHUMLAMA ile
--      kapatması S-7'de kalır — o yol değişmez.)
-- ════════════════════════════════════════════════════════════════════════════
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

  -- Olay tarihi = rota instance başlangıcı (yoksa hedef − 51, SK6)
  SELECT baslangic INTO v_olay FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  v_olay := COALESCE(v_olay, v_g.hedef_tarih - 51);

  -- ── Otomatik muafiyetler (SK7 final seti) ─────────────────────────────
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_g.hayvan_id FOR UPDATE;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu
    SELECT t.sonuc INTO v_son_sonuc FROM public.tohumlama t
     WHERE t.hayvan_id = v_g.hayvan_id
       ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
       LIMIT 1;
    IF v_son_sonuc = 'Gebe' THEN
      v_neden := 'GEBE';
    ELSIF v_son_sonuc = 'Bekliyor' THEN
      v_neden := 'BEKLIYOR';
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
  v_res := public._vaka_ac_tek(v_g.hayvan_id, v_disease_id, 'İlk tohumlama zinciri', v_s);
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

  -- ── R3.1: tek açık TAI kartı — açık PG sonrası görevleri iptal et
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
  'R3.2: açık OVSYNC_BASLAT görevinden atomik Ovsync zinciri. Muafiyetler: AKTIF_DEGIL/GEBE/BEKLIYOR/AKTIF_SENKRONIZASYON (TOHUMLAMA_VAR kalktı, SK7).';

REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid) TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- SK8  ilk_tohumlama_zamanlayici — imza değişir (p_dry_run), eski () DROP.
--      Yedek zamanlayıcı: (a) açık dişi taraması + (b) hedefi gelenleri
--      başlatma. p_dry_run=true → HİÇBİR ŞEY YAZMAZ, listeler; bayraktan
--      bağımsız çalışır (sahip kapısı 5 önizlemesi).
-- ════════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.ilk_tohumlama_zamanlayici();

CREATE OR REPLACE FUNCTION public.ilk_tohumlama_zamanlayici(p_dry_run boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  c_limit       constant integer := 200;
  c_tarama_ust  constant integer := 200;   -- taramada açılacak görev üst sınırı
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
  -- tarama
  v_acilan      integer := 0;
  v_acil_liste  jsonb := '[]'::jsonb;
  v_taranan     integer := 0;
  v_tabansiz    integer := 0;
BEGIN
  -- ── DRY-RUN: bayraktan bağımsız, salt-okuma listesi ──────────────────
  IF p_dry_run THEN
    FOR r IN
      SELECT h.id, h.kupe_no,
             public._ovsync_kural_tarihi(h.id) AS kural
        FROM public.hayvanlar h
       WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
       ORDER BY h.id
       LIMIT 1000
    LOOP
      v_taranan := v_taranan + 1;
      IF r.kural IS NULL THEN
        -- tabansız: uygun olsa bile görev alamaz (rapor). NULL sonucu NOT IN
        -- tuzagina dusmez (IS DISTINCT FROM).
        IF public._acik_disi_ovsync_hedef(r.id) IS NULL
           AND NOT EXISTS (SELECT 1 FROM public.gorev_log g
                            WHERE g.hayvan_id = r.id AND g.gorev_tipi = 'OVSYNC_BASLAT'
                              AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
           AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = r.id
                 ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
               IS DISTINCT FROM 'Gebe'
           AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = r.id
                 ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
               IS DISTINCT FROM 'Bekliyor'
           AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = r.id
                            AND c.status='active' AND c.protocol_family IS NOT NULL) THEN
          v_tabansiz := v_tabansiz + 1;
        END IF;
      ELSIF public._acik_disi_ovsync_hedef(r.id) IS NOT NULL THEN
        v_acilan := v_acilan + 1;
        IF v_acilan <= c_tarama_ust THEN
          v_acil_liste := v_acil_liste || jsonb_build_array(jsonb_build_object(
            'hayvan_id', r.id, 'kupe_no', r.kupe_no,
            'kural_tarihi', r.kural,
            'hedef_tarih', GREATEST(r.kural, v_bugun)));
        END IF;
      END IF;
    END LOOP;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gorev_id', g.id, 'hayvan_id', g.hayvan_id, 'kupe_no', h.kupe_no,
             'hedef_tarih', g.hedef_tarih, 'kaynak', g.kaynak) ORDER BY g.hedef_tarih DESC, g.id),
           '[]'::jsonb)
      INTO v_basl_liste
      FROM public.gorev_log g
      JOIN public.hayvanlar h ON h.id = g.hayvan_id
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= v_bugun
       LIMIT c_limit;

    RETURN jsonb_build_object(
      'ok', true, 'dry_run', true, 'tarih', v_bugun,
      'taranan', v_taranan, 'acilacak_sayisi', v_acilan,
      'acilacaklar', v_acil_liste, 'acilacak_listesi_kesildi', v_acilan > c_tarama_ust,
      'duve_tabansiz', v_tabansiz,
      'baslatilacak_sayisi', jsonb_array_length(v_basl_liste),
      'baslatilacaklar', v_basl_liste);
  END IF;

  IF NOT public._ovsync_pg_aktif() THEN
    RETURN jsonb_build_object('ok', true, 'atlandi', 'KAPALI');
  END IF;

  -- ── (b) hedefi gelen görevleri başlat (önce; bu koşumun taraması aynı
  --       koşumda başlatılmaz — kural: tarama yeni görev açar, başlatma
  --       bir sonraki koşumda/farklı kaynakta) ────────────────────────────
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

  -- ── (a) açık dişi taraması: görevi eksik her uygun hayvana görev aç ──
  FOR r IN
    SELECT h.id, h.kupe_no
      FROM public.hayvanlar h
     WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
     ORDER BY h.id
     LIMIT 1000
  LOOP
    v_taranan := v_taranan + 1;
    EXIT WHEN v_acilan >= c_tarama_ust;
    IF public._acik_disi_ovsync_hedef(r.id) IS NOT NULL THEN
      BEGIN
        IF public._acik_disi_gorev_kur(r.id) IS NOT NULL THEN
          v_acilan := v_acilan + 1;
          v_acil_liste := v_acil_liste || jsonb_build_array(jsonb_build_object(
            'hayvan_id', r.id, 'kupe_no', r.kupe_no));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
          'tarama', true, 'hayvan_id', r.id, 'kupe_no', r.kupe_no,
          'sqlstate', SQLSTATE, 'mesaj', SQLERRM));
      END;
    END IF;
  END LOOP;

  -- Tabansız düve sayısı (rapor; sessiz kalmasın)
  SELECT count(*) INTO v_tabansiz
    FROM public.hayvanlar h
   WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
     AND public._ovsync_kural_tarihi(h.id) IS NULL
     AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = h.id
           ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
         IS DISTINCT FROM 'Gebe'
     AND (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = h.id
           ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1)
         IS DISTINCT FROM 'Bekliyor'
     AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = h.id
                      AND c.status = 'active' AND c.protocol_family IS NOT NULL)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = h.id
                      AND g.gorev_tipi = 'OVSYNC_BASLAT'
                      AND COALESCE(g.tamamlandi, false) = false
                      AND COALESCE(g.iptal, false) = false);

  v_ozet := jsonb_build_object(
    'ok', jsonb_array_length(v_hatalar) = 0,
    'tarih', v_bugun, 'limit', c_limit, 'islenen', v_islenen,
    'baslatilan', v_baslatilan, 'atlanan', v_atlanan, 'zaten', v_zaten,
    'hata_sayisi', jsonb_array_length(v_hatalar), 'kalan', v_kalan,
    'taranan', v_taranan, 'tarama_acilan', v_acilan, 'duve_tabansiz', v_tabansiz,
    'acilanlar', v_acil_liste,
    'baslatilanlar', v_basl_liste, 'atlananlar', v_atl_liste, 'hatalar', v_hatalar);

  IF v_islenen > 0 OR v_acilan > 0 THEN
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_CRON', NULL, NULL, 'gorev_log', v_ozet, '{}'::jsonb);
  END IF;

  RETURN v_ozet;
END;
$fn$;

COMMENT ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) IS
  'R3.2 SK8: yedek zamanlayıcı — (a) açık dişi taraması (cap 200) + (b) hedefi gelen OVSYNC_BASLAT başlatma. p_dry_run: bayraktan bağımsız salt-okuma listeleme.';

REVOKE ALL ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ilk_tohumlama_zamanlayici(boolean) TO authenticated, service_role;

-- cron komutu aynı kalır (DEFAULT parametre ile () çağrısı çözülür); job'ı tazele
DO $$
BEGIN
  IF to_regclass('cron.job') IS NULL
     OR to_regprocedure('cron.schedule(text, text, text)') IS NULL
     OR to_regprocedure('cron.unschedule(text)') IS NULL THEN
    RAISE NOTICE 'R3.2: pg_cron yok — job tazelenmedi';
    RETURN;
  END IF;
  PERFORM cron.unschedule('ilk-tohumlama-ovsync-baslat')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ilk-tohumlama-ovsync-baslat');
  PERFORM cron.schedule('ilk-tohumlama-ovsync-baslat', '0 4 * * *',
                        'select public.ilk_tohumlama_zamanlayici()');
END $$;


-- ════════════════════════════════════════════════════════════════════════════
-- SK9  ovsync_baslat_uyarilari — protokol uyarıları ekranı veri kaynağı
-- ════════════════════════════════════════════════════════════════════════════
-- OVSYNC_BASLAT görevleri hedef−2 günden itibaren (bayraktan bağımsız;
-- görev ancak bayrak açıkken doğar, RPC görünürlüğü serbest). TAI tarihi
-- bilgisine göre (hedef+10) gösterilir; kategori inek/düve ayrımı için
-- hayvanlar.kategori ve kural tabanı türü döner.
CREATE OR REPLACE FUNCTION public.ovsync_baslat_uyarilari()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'ok', true,
    'uyarilar', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'gorev_id', g.id,
               'hayvan_id', g.hayvan_id,
               'kupe_no', h.kupe_no,
               'kategori', COALESCE(h.kategori, h.grup),
               'hedef_tarih', g.hedef_tarih,
               'hedef_saat', g.hedef_saat,
               'tai_tarihi', g.hedef_tarih + 10,
               'kaynak', g.kaynak,
               'taban_turu', CASE WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%' THEN 'duve'
                                  WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'
                                  WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'
                                  ELSE 'acik_disi' END)
               ORDER BY g.hedef_tarih, g.id)
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND g.hedef_tarih <= ((now() AT TIME ZONE 'Europe/Istanbul')::date + 2)
    ), '[]'::jsonb)
  );
$fn$;

COMMENT ON FUNCTION public.ovsync_baslat_uyarilari() IS
  'R3.2 SK9: hedef−2 günden itibaren açık OVSYNC_BASLAT görevleri (protokol uyarıları ekranı verisi). Salt-okuma.';

REVOKE ALL ON FUNCTION public.ovsync_baslat_uyarilari() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_baslat_uyarilari() TO authenticated, service_role;


-- ════════════════════════════════════════════════════════════════════════════
-- SK10  _ovsync_gecis_sk10 — tek seferlik geçiş (bayraktan bağımsız, MK8)
-- ════════════════════════════════════════════════════════════════════════════
-- Başlangıcından sonra tohumlanmış ve AÇIK SEANSI OLMAYAN aktif Ovsync
-- vakaları TOHUMLAMA nedeniyle kapatılır. İdempotent: kapanan vaka artık
-- 'active' değildir. Açık seansı olan (küpe 002) doğal olarak dışlanır.
CREATE OR REPLACE FUNCTION public._ovsync_gecis_sk10()
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  r      record;
  v_toh  text;
  v_say  integer := 0;
  v_ids  jsonb := '[]'::jsonb;
  v_res  jsonb;
BEGIN
  FOR r IN
    SELECT c.id, c.animal_id, c.start_date
      FROM public.cases c
     WHERE c.status = 'active'
       AND c.protocol_family = 'OVSYNC'
       AND EXISTS (SELECT 1 FROM public.tohumlama t
                    WHERE t.hayvan_id = c.animal_id
                      AND t.tarih >= c.start_date)
       AND NOT EXISTS (SELECT 1 FROM public.treatment_days td
                        WHERE td.case_id = c.id
                          AND COALESCE(td.tamamlandi, false) = false)
     ORDER BY c.start_date, c.id
  LOOP
    SELECT t.id::text INTO v_toh
      FROM public.tohumlama t
     WHERE t.hayvan_id = r.animal_id AND t.tarih >= r.start_date
     ORDER BY t.tarih ASC, t.created_at ASC
     LIMIT 1;

    v_res := public._vaka_kapat(r.id, 'TOHUMLAMA', NULL,
               jsonb_build_object('tohumlama_id', v_toh, 'gecis', 'SK10-2026-09-24'));
    v_say := v_say + 1;
    v_ids := v_ids || jsonb_build_array(r.id::text);
  END LOOP;

  RAISE NOTICE 'SK10 gecis: % Ovsync vakasi TOHUMLAMA ile kapatildi', v_say;
  RETURN jsonb_build_object('ok', true, 'kapatilan', v_say, 'case_ids', v_ids);
END;
$fn$;

COMMENT ON FUNCTION public._ovsync_gecis_sk10() IS
  'R3.2 SK10: tohumlanmış + açıksız seanslı aktif Ovsync vakalarını TOHUMLAMA ile kapat (tek seferlik geçiş; idempotent).';

REVOKE ALL ON FUNCTION public._ovsync_gecis_sk10() FROM PUBLIC, anon, authenticated;

-- Geçiş çalıştır (ikinci uygulamada 0 kapatır)
DO $$
DECLARE v_r jsonb;
BEGIN
  v_r := public._ovsync_gecis_sk10();
  RAISE NOTICE 'SK10: %', v_r->>'kapatilan';
END $$;


NOTIFY pgrst, 'reload schema';

-- EOF 20260924000001
