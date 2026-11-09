-- ============================================================================
-- prod/geri-al.sql — N7 P11 geri alma dosyası (HAZIR, KOŞULMAZ). Kaynak: runs/2026-11-09-ovsync-tren/db/geri-al.sql (D8 provası),
-- aşağıya birebir kopya. N7 P2 doğrulaması (2026-11-09, prod salt-okuma yedeği ovsync-tren-prod-yedek-20261109T191249Z):
--   16 gövdenin md5(prosrc) = P2 prod yedeği (16/16 eşit, MEASURED); ACL deseni = P2 prod proacl (MEASURED).
-- Koşma: yalnız sahip kararıyla, BEGIN … COMMIT içinde; kolon DROP (adım 5) sahip son onayı ister.
-- ============================================================================
-- ============================================================================
-- geri-al.sql — Ovsync treni geri alma (PLAN.md N7-P11; D8 provası). Üretildi: D8 (gen: ~/tmp/ovsync-tren-db/gen_geri_al.py).
--
-- HIZLI GERİ (ayrı koşulur; bu dosyada yorum): bayrak kapanır, Faz 0 görev yolu geri açılır. R19: R10 anahtar biçimi + G7
-- fail-closed, _vaka_ac_tek TR tarihi ve yeni imzalar hızlı geriyle DÖNMEZ (yalnız aşağıdaki tam geri).
--   SELECT public.ovsync_tren_ayar_guncelle(false, NULL);
--   UPDATE public.protokol_ayar SET deger = 1 WHERE anahtar = 'dogum_sonrasi_pg_gorev_aktif';
--
-- TAM GERİ (bu dosya). BEGIN/COMMIT TAŞIMAZ: çağıran tek transaction'a sarar (prod: P2 yedeği sonrası; md5 doğrulaması
-- tutmazsa RAISE → tümü geri). Adımlar: (1) D3/D4'ün DROP+CREATE ettiği 3 yeni imza DROP; (2) seri ile gelen 24 yeni
-- fonksiyon DROP (D6 ovsync_bastan_baslat p_hedef'li imza dahil); (3) 16 fonksiyon D0 gövdesi (govde-taban.md; kaynak
-- tedavi-arge kanit/fn, prod = demo = kanit md5) CREATE OR REPLACE — 3'ü eski imzasıyla yeniden yaratılır; (4) ACL prod
-- desenine (16 fonksiyon; MEASURED prod proacl 2026-11-09); (5) cases.ovsync_tren + cases.ovsync_bagimsiz (D9) DROP COLUMN — **sahip son onayı**;
-- (6) 5 ayar satırı DELETE; (7) doğrulama: 16 md5 = D0, yeni fonksiyon yok, eski imzalar var, kolon/ayar yok.
-- Veri notu: kolon DROP tren etiketlerini ve bağımsız işaretlerini siler; GOREV_ERTELE ile taşınmış görev hedefleri geri alınmaz (islem_log soyu kalır).
-- ============================================================================
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

-- (1) yeni imzalar (eski imzalar adım 3'te yeniden yaratılır)
DROP FUNCTION public._acik_disi_gorev_kur(text, boolean);
DROP FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date, boolean);
DROP FUNCTION public.start_first_service_protocol(uuid, boolean, boolean);

-- (2) seri ile gelen yeni fonksiyonlar
DROP FUNCTION public._ovsync_asama(uuid);
DROP FUNCTION public._ovsync_gorev_mu(uuid);
DROP FUNCTION public._ovsync_ic_ac();
DROP FUNCTION public._ovsync_ic_mi();
DROP FUNCTION public._ovsync_kilit_gorev(uuid);
DROP FUNCTION public._ovsync_kilit_vaka(uuid);
DROP FUNCTION public._ovsync_pg1_kayma(uuid);
DROP FUNCTION public._ovsync_tren_aktif();
DROP FUNCTION public._ovsync_tren_ayar();
DROP FUNCTION public._ovsync_tren_ertele_plan(date, integer);
DROP FUNCTION public._ovsync_tren_gunu(date);
DROP FUNCTION public._ovsync_tren_gunu_ic(date, date, integer, date);
DROP FUNCTION public._ovsync_tren_gunu_mu(date);
DROP FUNCTION public._ovsync_tren_uye_vaka(uuid, integer);
DROP FUNCTION public.dogum_sonrasi_pg_hatirlatma();
DROP FUNCTION public.ovsync_bastan_baslat(uuid, boolean, text, date);
DROP FUNCTION public.ovsync_hayvan_ertele(text, integer);
DROP FUNCTION public.ovsync_pg48_tohumla(uuid);
DROP FUNCTION public.ovsync_tren_ayar_guncelle(boolean, date);
DROP FUNCTION public.ovsync_tren_ertele(date, integer, jsonb);
DROP FUNCTION public.ovsync_tren_ertele_onizle(date, integer);
DROP FUNCTION public.ovsync_tren_listele();
DROP FUNCTION public.ovsync_tren_onizle(text);
DROP FUNCTION public.ovsync_tren_yeniden_hedefle(boolean, date);

-- (3) 16 fonksiyonun D0 gövdesi (birebir; md5(prosrc) adım 7'de doğrulanır)
-- _acik_disi_gorev_kur · _acik_disi_gorev_kur(text) · md5 cb7b8182151602505b48615148592b2a
CREATE OR REPLACE FUNCTION public._acik_disi_gorev_kur(p_hayvan_id text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;

-- _acik_disi_hedef_ic · _acik_disi_hedef_ic(text) · md5 5082fc8884d9ad96a8fa4f16d457c9f5
CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_h   record;
  v_son text;
  v_k   date;
BEGIN
  -- Bayrak YOKSAYAN uygunluk (dry-run önizleme). Yeni iş yaratmaz.
  SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
    INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RETURN NULL;
  END IF;

  -- S1/M1: kısır hayvan üreme planına girmez (kisir kolonu; işaret kalkınca normal kural)
  IF v_h.kisir THEN
    RETURN NULL;
  END IF;

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

  -- ═══ T1 ek koşulu (cila 20260925000007) — açık senkron-protokol görevi varken
  --     yeni açık-dişi hedef ÜRETME. 188 kasıtlı zinciri etkilemez: OVSYNC_BASLAT
  --     bloğu yukarıda zaten NULL döndürür; bu koşul yalnız zincir çalışırken
  --     (ILAC/TOHUMLAMA_HAZIRLIK, 'senkron' damgalı) üretimi durdurur; görevler
  --     kapanınca zamanlayıcı normal üretimine döner (spec-s5 §7.1 sahibin kararı:
  --     kasıtlı ardışık zincirler korunur). Canlı damga deseni: aciklama
  --     '39. Gün PG (Presynch-14 senkron)' — kaynak-alanı damgası canlıda 0 satır,
  --     OR bacağı zararsız (spec §7.2-V3).
  IF EXISTS (
    SELECT 1 FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id
       AND g.gorev_tipi IN ('ILAC', 'TOHUMLAMA_HAZIRLIK')
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%')
  ) THEN
    RETURN NULL;
  END IF;

  -- ═══ TAKIP muafiyeti (P2a, takip-ekranı) — açık TAKIP_MUAYENE görevi varken
  --     yeni açık-dişi hedef ÜRETME (DEGISMEZ 1; §6c.5 + S2c): takipteki Boş
  --     hayvana zamanlayıcı/reconcile OVSYNC_BASLAT AÇMAZ; takip kapanınca
  --     üretim normal kuralına döner. Koşul P1 'takiptekiler' kümesiyle birebir
  --     (gorev_tipi + !tamamlandi + !iptal; 20260929000001:288-294).
  IF EXISTS (
    SELECT 1 FROM public.gorev_log g
     WHERE g.hayvan_id = p_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
  ) THEN
    RETURN NULL;
  END IF;

  v_k := public._ovsync_kural_tarihi(p_hayvan_id);
  IF v_k IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN GREATEST(v_k, (now() AT TIME ZONE 'Europe/Istanbul')::date);
END;
$function$;

-- _ovsync_baslat_gorev_kur · _ovsync_baslat_gorev_kur(text,date,text,date) · md5 66e46e679f85afada875808607a28dac
CREATE OR REPLACE FUNCTION public._ovsync_baslat_gorev_kur(p_hayvan_id text, p_baslangic date, p_kaynak_ref text, p_kural_tarihi date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inst_id     uuid;
  v_gorev_id    uuid;
  v_iptal_gorev uuid[];
  v_iptal_inst  uuid[];
  v_hedef       date;
  v_h           record;
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

  -- K3 (2026-09-25): kısır/Aktif değil/Dişi değil hayvana zincir görevi AÇILMAZ.
  --   En alt ortak halka: dogum_kaydet/tohumlama_abort kancaları _ilk_tohumlama_rota_kur
  --   sarmalayıcısı üzerinden buraya iner; açık-dişi üretimi (_acik_disi_gorev_kur) de
  --   aynı çekirdeği kullanır. Mimar B1: 000001:17-19 yorumunun düzeltmesi — olay
  --   kancaları artık bu gövdenin guard'ından beslenir. Sessiz NULL (bayrak-kapalı deseni).
  -- [F4 2026-09-25] Guard parametre doğrulamasının ARDINA taşındı (K3 bulgusu):
  --   bayrak açıkken parametre ihlali yeniden OVSYNC_BASLAT_PARAMETRE üretir;
  --   guard yalnız doğrulanmış girdiler üzerinde kısır/Aktif/Dişi kararını verir.
  SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
    INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif'
     OR v_h.cinsiyet IS DISTINCT FROM 'Dişi' OR v_h.kisir THEN
    RETURN NULL;
  END IF;

  -- C5 (cila2, fail-closed): kural günü gelmeden görev SATIRI doğmaz. Sahip
  -- kuralı "uyarılar 2 gün önceden ekrana düşmeli" — erken dönem görünürlüğü
  -- görevde değil panel uyarısındadır (ovsync_baslat_uyarilari görevsiz kol).
  -- 12 aylık düveye hedefi +21 gün ileride görev açılması bu kapıyla biter.
  IF p_kural_tarihi > (now() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RETURN NULL;
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
$function$;

-- _vaka_ac_tek · _vaka_ac_tek(text,uuid,text,date) · md5 f9be42278a02581ade0f55230ea37aee
CREATE OR REPLACE FUNCTION public._vaka_ac_tek(p_hayvan_id text, p_disease_id uuid, p_notes text DEFAULT NULL::text, p_tarih date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_new_id  uuid;
  v_animal  record;
  v_disease record;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_disease FROM public.diseases WHERE id = p_disease_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık kaydı bulunamadı');
  END IF;

  -- Aynı hayvanda aynı hastalıkta zaten aktif vaka var mı?
  IF EXISTS (
    SELECT 1 FROM public.cases
    WHERE animal_id = p_hayvan_id
      AND disease_id = p_disease_id
      AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hayvan için zaten aktif bir ' || v_disease.name || ' vakası mevcut');
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, notes, start_date)
  VALUES (p_hayvan_id, p_disease_id, p_notes, COALESCE(p_tarih, CURRENT_DATE))
  RETURNING id INTO v_new_id;

  -- islem_log: geri alma icin snapshot
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'VAKA_ACILDI',
    p_hayvan_id,
    v_new_id::text,
    'cases',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'cases', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$function$;

-- dogum_kaydet · dogum_kaydet(text,date,text,text,text,numeric,text,text) · md5 756c56afb83401721521e42e613ab7f9
CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip text DEFAULT 'Normal'::text, p_kg numeric DEFAULT NULL::numeric, p_baba text DEFAULT NULL::text, p_hekim_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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

  -- İKİZ GUARD: aynı anne + aynı yavru küpesi AKTİF yavruda kayıtlıysa reddet (typo → yanlış ikiz engeli).
  -- Çıkmış yavrunun küpesi serbest (K1, sahip 2026-10-31); buzagi_id boş satır engellemez.
  IF EXISTS (SELECT 1 FROM public.dogum d JOIN public.hayvanlar h ON h.id = d.buzagi_id
             WHERE d.anne_id = p_anne_id AND d.yavru_kupe = p_kupe AND h.durum = 'Aktif') THEN
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

  v_buzagi_id := gen_random_uuid()::text;

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

-- gorev_ertele · gorev_ertele(uuid,date,time without time zone) · md5 2af93dfba299268b912175c628d4b05c
CREATE OR REPLACE FUNCTION public.gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time without time zone DEFAULT NULL::time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g          public.gorev_log%ROWTYPE;
  v_bugun      date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_kural      jsonb;
  v_saat       time;
  v_hedef      timestamptz;
  v_yerel      timestamp;
  v_yeni_tarih date;
  v_yeni_saat  time;
  v_ilk_hedef  date;
  v_toplam     integer;
  v_max        integer;
  v_asim       integer;
  v_uyari      text;
  v_zincir     jsonb := '{}'::jsonb;
BEGIN
  -- 1) Görevi kilitle
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'GOREV_BULUNAMADI');
  END IF;
  IF p_yeni_tarih IS NULL THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'YENI_TARIH_BOS');
  END IF;

  -- 2) Kural: fail-closed (kayıtsız tip ASLA ertelenemez)
  v_kural := public.gorev_ertele_kural_get(v_g.gorev_tipi);
  IF NOT COALESCE((v_kural->>'ertelenebilir')::boolean, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'TIP_ERTELENEMEZ',
      'gorev_tipi', v_g.gorev_tipi,
      'kural_kaynagi', CASE WHEN v_kural ? 'gorev_tipi' THEN 'tablo'
                            ELSE 'fail-closed-default' END);
  END IF;

  -- 3) Yalnız AÇIK görev
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'GOREV_ACIK_DEGIL');
  END IF;

  -- 4) Geçmiş tarih — TÜM tiplerde red
  IF p_yeni_tarih < v_bugun THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
      'yeni_tarih', p_yeni_tarih, 'bugun', v_bugun);
  END IF;

  -- 5) Pencere: 'tohumlama' → _tohumlama_pencere yuvarlaması (dokunmadan çağır)
  IF v_kural->>'pencere_kurali' = 'tohumlama' THEN
    v_saat  := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
    v_hedef := public._tohumlama_pencere((p_yeni_tarih + v_saat) AT TIME ZONE 'Europe/Istanbul');
    IF v_hedef < now() THEN
      RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object(
        'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
        'yeni_tarih', p_yeni_tarih, 'yeni_saat', v_saat,
        'hedef_at', v_hedef, 'simdi', now());
    END IF;
    v_yerel      := v_hedef AT TIME ZONE 'Europe/Istanbul';
    v_yeni_tarih := v_yerel::date;
    v_yeni_saat  := v_yerel::time;
  ELSE
    v_yeni_tarih := p_yeni_tarih;
    v_yeni_saat  := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
  END IF;

  -- İlk hedef soyu: GOREV_ERTELE + TOHUMLAMA_ERTELE kayıtları (süreklilik —
  -- önceki RPC ile ertelenmiş görevin soyu yeni RPC'de devam eder)
  SELECT (l.payload->>'eski_tarih')::date INTO v_ilk_hedef
    FROM public.islem_log l
   WHERE l.tip IN ('GOREV_ERTELE', 'TOHUMLAMA_ERTELE')
     AND l.ref_tablo = 'gorev_log'
     AND l.ref_id = p_gorev_id::text
     AND l.payload ? 'eski_tarih'
   ORDER BY l.tarih ASC, l.degisim_txid ASC NULLS LAST
   LIMIT 1;
  v_ilk_hedef := COALESCE(v_ilk_hedef, v_g.hedef_tarih, v_yeni_tarih);
  v_toplam    := v_yeni_tarih - v_ilk_hedef;

  -- 6) Sert sınır (NULL = sınır YOK / MK2) ve uyarı eşiği
  v_max  := NULLIF(v_kural->>'max_erteleme_gun', '')::integer;
  v_asim := COALESCE(NULLIF(v_kural->>'asimi_uyari_gun', '')::integer, 7);
  IF v_max IS NOT NULL AND v_toplam > v_max THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'MAX_ASIM',
      'gorev_tipi', v_g.gorev_tipi, 'max_erteleme_gun', v_max,
      'toplam_erteleme_gun', v_toplam, 'ilk_hedef_tarih', v_ilk_hedef);
  END IF;
  v_uyari := CASE WHEN v_toplam > v_asim
                  THEN 'ERTELEME_' || v_asim || '_GUN_ASILDI' END;

  -- 7) Görevi taşı
  UPDATE public.gorev_log
     SET hedef_tarih = v_yeni_tarih, hedef_saat = v_yeni_saat
   WHERE id = p_gorev_id;

  -- 8) OVSYNC_BASLAT zincir raporu — kaynak anahtarı BİLİNÇLİ korunur
  --    (çift-görev koruması idempotans katmanlarındadır; kırıntı 17:35)
  IF v_g.gorev_tipi = 'OVSYNC_BASLAT' THEN
    v_zincir := jsonb_build_object(
      'ovsync_baslat', true,
      'kaynak_ref', (SELECT pi.kaynak_ref FROM public.protokol_instance pi
                      WHERE pi.id = v_g.protokol_instance_id),
      'cift_gorev_korumasi', jsonb_build_array(
        'protokol_instance_kaynak_unique',
        'acik_disi_hedef_ic_acik_gorev_kontrolu'),
      'not', 'Anahtar bilincli korunur: acik OVSYNC_BASLAT = zincir baslamamis; TAI start_first_service_protocol aninda turetilir.');
  END IF;

  -- Audit (TOHUMLAMA_ERTELE kalıbının geneli)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES ('GOREV_ERTELE', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
            'eski_tarih', v_g.hedef_tarih, 'eski_saat', v_g.hedef_saat,
            'yeni_tarih', v_yeni_tarih, 'yeni_saat', v_yeni_saat,
            'ilk_hedef_tarih', v_ilk_hedef,
            'toplam_erteleme_gun', v_toplam, 'uyari', v_uyari,
            'zincir', v_zincir),
          jsonb_build_object(
            'olusturulan', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object(
              'tablo', 'gorev_log', 'id', p_gorev_id::text,
              'onceki',  jsonb_build_object('hedef_tarih', v_g.hedef_tarih, 'hedef_saat', v_g.hedef_saat),
              'sonraki', jsonb_build_object('hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat))),
            'silinen', '[]'::jsonb),
          format('Gorev ertelendi (%s): %s %s -> %s %s',
                 v_g.gorev_tipi, v_g.hedef_tarih, v_g.hedef_saat, v_yeni_tarih, v_yeni_saat));

  RETURN jsonb_build_object(
    'ok', true, 'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
    'hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat,
    'ilk_hedef_tarih', v_ilk_hedef, 'toplam_erteleme_gun', v_toplam,
    'uyari', v_uyari, 'zincir', v_zincir);
END;
$function$;

-- ovsync_baslat_uyarilari · ovsync_baslat_uyarilari() · md5 869dcfef020a01c6446359d13aa988ed
CREATE OR REPLACE FUNCTION public.ovsync_baslat_uyarilari()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH bugun AS (
    SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS d
  ), gorevli AS (
    SELECT g.id AS gorev_id, g.hayvan_id, h.kupe_no, COALESCE(h.kategori, h.grup) AS kategori,
           COALESCE(h.kisir, false) AS kisir, g.hedef_tarih, g.hedef_saat,
           g.hedef_tarih + 10 AS tai_tarihi, g.kaynak,
           CASE WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%' THEN 'duve'
                WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'
                WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'
                ELSE 'acik_disi' END AS taban_turu
      FROM public.gorev_log g
      JOIN public.hayvanlar h ON h.id = g.hayvan_id
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= (SELECT d + 2 FROM bugun)
  ), gorevsiz AS (
    -- C5 (cila2): görev kural günü doğduğu için hedef−2 penceresinde görev
    -- henüz YOK — uyarı 2 gün önceden düşsün diye görevsiz uygun açık dişiler
    -- kural tarihinden listelenir. Başlatma kural günü mümkün olur.
    SELECT NULL::uuid AS gorev_id, h.id AS hayvan_id, h.kupe_no, COALESCE(h.kategori, h.grup) AS kategori,
           COALESCE(h.kisir, false) AS kisir,
           (SELECT public._ovsync_kural_tarihi(h.id)) AS hedef_tarih,
           NULL::time AS hedef_saat,
           (SELECT public._ovsync_kural_tarihi(h.id)) + 10 AS tai_tarihi,
           'ACIK-DISI-ONERI:' || h.id AS kaynak,
           CASE WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'dogum'
                WHEN EXISTS (SELECT 1 FROM public.tohumlama t
                              WHERE t.hayvan_id = h.id AND t.sonuc = 'Abort'
                                AND t.abort_tarihi IS NOT NULL) THEN 'abort'
                WHEN h.dogum_tarihi IS NOT NULL THEN 'duve'
                ELSE 'acik_disi' END AS taban_turu
      FROM public.hayvanlar h
     WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi' AND COALESCE(h.kisir, false) = false
       AND public._acik_disi_ovsync_hedef(h.id) IS NOT NULL
       AND (SELECT public._ovsync_kural_tarihi(h.id)) >= (SELECT d FROM bugun)
       AND (SELECT public._ovsync_kural_tarihi(h.id)) <= (SELECT d + 2 FROM bugun)
       AND NOT EXISTS (SELECT 1 FROM public.gorev_log g2
                        WHERE g2.hayvan_id = h.id AND g2.gorev_tipi = 'OVSYNC_BASLAT'
                          AND COALESCE(g2.tamamlandi, false) = false
                          AND COALESCE(g2.iptal, false) = false)
  )
  SELECT jsonb_build_object(
    'ok', true,
    'uyarilar', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'gorev_id', u.gorev_id,
               'hayvan_id', u.hayvan_id,
               'kupe_no', u.kupe_no,
               'kategori', u.kategori,
               'kisir', u.kisir,
               'hedef_tarih', u.hedef_tarih,
               'hedef_saat', u.hedef_saat,
               'tai_tarihi', u.tai_tarihi,
               'kaynak', u.kaynak,
               'taban_turu', u.taban_turu)
               ORDER BY u.hedef_tarih, u.hayvan_id)
        FROM (SELECT * FROM gorevli UNION ALL SELECT * FROM gorevsiz) u
    ), '[]'::jsonb)
  );
$function$;

-- ovsync_hastalik_gunu_ekle · ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text) · md5 1765d756f499e3ecc36740e74a65d804
CREATE OR REPLACE FUNCTION public.ovsync_hastalik_gunu_ekle(p_case_id uuid, p_hastalik_id uuid DEFAULT NULL::uuid, p_tarih date DEFAULT NULL::date, p_gun integer DEFAULT 7, p_ilaclar jsonb DEFAULT '[]'::jsonb, p_pg_onay boolean DEFAULT NULL::boolean, p_pg_gerekce text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_case      record;
  v_kisir     boolean;
  v_hastalik  uuid;
  v_tarih     date := COALESCE(p_tarih, (now() AT TIME ZONE 'Europe/Istanbul')::date);
  v_gun       integer := COALESCE(p_gun, 7);
  v_day_id    uuid;
  v_ilac      jsonb;
  v_yazilan   integer := 0;
  v_g         record;
  v_ertelenen integer := 0;
BEGIN
  IF v_gun < 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'GUN_NEGATIF');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OVSYNC_VAKA_BULUNAMADI');
  END IF;
  IF v_case.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'VAKA_KAPALI');
  END IF;
  -- Vaka kabulü = yedek-Ovsync tanımı (TEK yer: _vaka_ovsync_mu).
  IF NOT public._vaka_ovsync_mu(p_case_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ANA_ACIK_OVSYNC_DEGIL');
  END IF;
  SELECT COALESCE(kisir, false) INTO v_kisir FROM public.hayvanlar WHERE id = v_case.animal_id;
  IF COALESCE(v_kisir, false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'KISIR_HAYVANA_HASTALIK_GUNU_YOK');
  END IF;

  v_hastalik := p_hastalik_id;
  IF v_hastalik IS NULL THEN
    SELECT id INTO v_hastalik FROM public.diseases WHERE name = 'İnaktif Ovaryum' LIMIT 1;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'INAKTIF_HASTALIK_YOK');
    END IF;
  ELSIF NOT EXISTS (SELECT 1 FROM public.diseases WHERE id = v_hastalik) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'HASTALIK_BULUNAMADI');
  END IF;

  -- Idempotent gün-aç: vaka satır kilidi çift-tık yarışını seriler; yine de
  -- araya giren yazma unique'e takılırsa mevcut gün okunur (kayıp güncelleme yok).
  SELECT id INTO v_day_id FROM public.treatment_days
   WHERE case_id = p_case_id AND disease_id = v_hastalik AND treatment_date = v_tarih;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', true,
      'ertelenen', 0, 'ilac', 0);
  END IF;
  BEGIN
    -- id açık üretilir: constraint-free aynalarda kolon DEFAULT'u yoktur;
    -- gerçek şemalarda explicit değer default'u ezmesi zararsızdır.
    INSERT INTO public.treatment_days(id, case_id, treatment_date, disease_id)
      VALUES (gen_random_uuid(), p_case_id, v_tarih, v_hastalik) RETURNING id INTO v_day_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT id INTO v_day_id FROM public.treatment_days
     WHERE case_id = p_case_id AND disease_id = v_hastalik AND treatment_date = v_tarih;
    RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', true,
      'ertelenen', 0, 'ilac', 0);
  END;

  -- İlaçlar o günün altına (PG sarmalı add_drug_administration içindedir;
  -- PG_KAPI:* blokları istisna olarak yükselir, burada yutulmaz).
  FOR v_ilac IN SELECT * FROM jsonb_array_elements(COALESCE(p_ilaclar, '[]'::jsonb)) LOOP
    PERFORM public.add_drug_administration(v_day_id,
      (v_ilac->>'drug_product_id')::uuid, v_ilac->>'stok_id',
      (v_ilac->>'dose')::numeric, v_ilac->>'unit', v_ilac->>'route',
      p_pg_onay, p_pg_gerekce);
    v_yazilan := v_yazilan + 1;
  END LOOP;

  -- Açık TAI'leri ötele (iptal YOK; kaydır RPC çağrılmaz). §7.2: yalnız AKTİF
  -- TAI (iptal/tamamlanmış/kapatan_ref'li hariç).
  FOR v_g IN SELECT id, hedef_tarih, hedef_saat FROM public.gorev_log
              WHERE hayvan_id = v_case.animal_id AND gorev_tipi = 'TOHUMLAMA_PLANLI'
                AND NOT COALESCE(tamamlandi, false) AND NOT COALESCE(iptal, false)
                AND kapatan_ref IS NULL
              ORDER BY id
              FOR UPDATE LOOP
    PERFORM public.tohumlama_gorev_ertele(v_g.id, v_g.hedef_tarih + v_gun, v_g.hedef_saat);
    v_ertelenen := v_ertelenen + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', false,
    'ertelenen', v_ertelenen, 'ilac', v_yazilan);
END;
$function$;

-- protokol_iptal · protokol_iptal(uuid,boolean,text) · md5 e5487897bf66b1f8f361792cb4bcf74a
CREATE OR REPLACE FUNCTION public.protokol_iptal(p_vaka_id uuid, p_yeniden_baslat boolean DEFAULT false, p_not text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_case        public.cases%ROWTYPE;
  v_kapat       jsonb;
  v_iade        integer := 0;
  v_inst_kapali integer := 0;
  v_yeni_gorev  uuid;
  v_kural       date;
  v_taban       date;
  v_dogum       date;
  v_abort       date;
  v_yeniden_not text;
BEGIN
  -- 1) Vaka kilitle + doğrula: yalnız AKTİF PROTOROL vakası iptal edilir
  SELECT * INTO v_case FROM public.cases WHERE id = p_vaka_id FOR UPDATE;
  IF NOT FOUND OR v_case.status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'PROTOKOL_IPTAL_EDILEMEZ:%', jsonb_build_object(
      'case_id', p_vaka_id, 'sebep', 'VAKA_ACIK_DEGIL',
      'status', v_case.status);
  END IF;
  IF v_case.protocol_family IS NULL THEN
    RAISE EXCEPTION 'PROTOKOL_IPTAL_EDILEMEZ:%', jsonb_build_object(
      'case_id', p_vaka_id, 'sebep', 'PROTOKOL_VAKASI_DEGIL',
      'protocol_family', v_case.protocol_family);
  END IF;

  -- 2) Vaka kapanışı: kalan seans/görev/gün + stok iadesi + cases +
  --    CASE_CLOSED_BY_IPTAL audit (_vaka_kapat generic adımları — çift yazma yok)
  v_kapat := public._vaka_kapat(p_vaka_id, 'IPTAL', p_not,
                                jsonb_build_object('protokol_iptal', true));
  v_iade  := COALESCE((v_kapat->>'stok_iade')::int, 0);

  -- 3) Hayvan-seviyesi ILK_TOHUMLAMA instance kapanışı (E0 q6: vaka-bağlı
  --    instance satırı yok — instance hayvan seviyesinde yaşar)
  UPDATE public.protokol_instance
     SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'PROTOKOL_IPTAL'
   WHERE hayvan_id = v_case.animal_id
     AND alttip = 'ILK_TOHUMLAMA'
     AND durum = 'aktif';
  GET DIAGNOSTICS v_inst_kapali = ROW_COUNT;

  -- 4) Yeniden başlat: TEK yeni OVSYNC_BASLAT (kaynak_ref idempotensi:
  --    'PROTOKOL-IPTAL-<case_id>'; kısırlık/Aktif/Dişi + bayrak guard'ları
  --    _ovsync_baslat_gorev_kur çekirdeğinden — guard takılırsa sessiz NULL).
  --    [F4/A-4] Bacak protocol_family='OVSYNC' koşuluna bağlı: farklı aileden
  --    gelen yeniden-başlat isteği HATA DEĞİL, not-la atlanır — OVSYNC dışı
  --    aileden OVSYNC görevi türetilmez (kırmızı probe: PRESYNC vakada görev
  --    üretilmişti; yeşil: AILE_ATLANDI notu + yeni_gorev NULL).
  IF p_yeniden_baslat THEN
    IF v_case.protocol_family = 'OVSYNC' THEN
      v_kural := public._ovsync_kural_tarihi(v_case.animal_id);
      SELECT max(tarih) INTO v_dogum FROM public.dogum WHERE anne_id = v_case.animal_id;
      SELECT max(abort_tarihi) INTO v_abort FROM public.tohumlama
       WHERE hayvan_id = v_case.animal_id AND sonuc = 'Abort' AND abort_tarihi IS NOT NULL;
      IF v_dogum IS NOT NULL OR v_abort IS NOT NULL THEN
        v_taban := GREATEST(COALESCE(v_dogum, '-infinity'::date),
                            COALESCE(v_abort, '-infinity'::date));
      ELSE
        SELECT dogum_tarihi INTO v_taban FROM public.hayvanlar WHERE id = v_case.animal_id;
      END IF;
      IF v_kural IS NULL OR v_taban IS NULL THEN
        v_yeniden_not := 'TABANSIZ — kural/taban tarihi çözülemedi, görev açılmadı';
      ELSE
        v_yeni_gorev := public._ovsync_baslat_gorev_kur(
          v_case.animal_id, v_taban,
          'PROTOKOL-IPTAL-' || p_vaka_id::text, v_kural);
        IF v_yeni_gorev IS NULL THEN
          v_yeniden_not := 'GUARD — bayrak kapalı ya da hayvan uygun değil (kisir/Aktif değil/Dişi değil)';
        END IF;
      END IF;
    ELSE
      v_yeniden_not := 'AILE_ATLANDI — yeniden başlat yalnız OVSYNC ailesinde desteklenir (protocol_family='
                       || v_case.protocol_family || '); istek hata değil, sessiz atlandı';
    END IF;
  END IF;

  -- 5) RPC düzeyi audit (tohumlama_kaydet → _vaka_kapat iki-audit kalıbı)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('PROTOKOL_IPTAL', v_case.animal_id, p_vaka_id::text, 'cases',
          jsonb_build_object(
            'case_id',          p_vaka_id,
            'protocol_family',  v_case.protocol_family,
            'yeniden_baslat',   p_yeniden_baslat,
            'not',              p_not,
            'kapanan_seans',    v_kapat->'iptal_seans',
            'kapanan_gorev',    v_kapat->'iptal_gorev',
            'iade_stok_hareket', v_iade,
            'kapanan_instance', v_inst_kapali,
            'yeni_gorev_id',    v_yeni_gorev,
            'yeniden_not',      v_yeniden_not),
          jsonb_build_object(
            'olusturulan', CASE WHEN v_yeni_gorev IS NOT NULL
              THEN jsonb_build_array(jsonb_build_object('tablo', 'gorev_log', 'id', v_yeni_gorev::text, 'gorev_tipi', 'OVSYNC_BASLAT'))
              ELSE '[]'::jsonb END,
            'guncellenen', jsonb_build_array(
              jsonb_build_object('tablo', 'cases', 'id', p_vaka_id::text,
                                 'sonraki', jsonb_build_object('status', 'closed', 'close_reason', 'IPTAL')),
              jsonb_build_object('tablo', 'protokol_instance', 'adet', v_inst_kapali,
                                 'kosul', 'hayvan ILK_TOHUMLAMA aktif -> iptal')),
            'silinen', '[]'::jsonb));

  RETURN jsonb_build_object(
    'ok',            true,
    'case_id',       p_vaka_id,
    'kapanan_gorev', COALESCE((v_kapat->>'iptal_gorev')::int, 0),
    'kapanan_seans', COALESCE((v_kapat->>'iptal_seans')::int, 0),
    'kapanan_instance', v_inst_kapali,
    'iade',          v_iade,
    'yeni_gorev_id', v_yeni_gorev,
    'yeniden_not',   v_yeniden_not);
END;
$function$;

-- seans_tamamla · seans_tamamla(uuid,boolean,text,boolean,text,boolean) · md5 4afb2221a7e95235e754b7ff508d0379
CREATE OR REPLACE FUNCTION public.seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi boolean DEFAULT false, p_not text DEFAULT NULL::text, p_pg_onay boolean DEFAULT false, p_pg_gerekce text DEFAULT NULL::text, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_seans      public.treatment_day_uygulamalar%ROWTYPE;
  v_all_done   boolean;
  v_total      int;
  v_done       int;
  v_tip        text;
  -- [OVSYNC-PG S-4]
  v_pg_aktif   boolean := public._ovsync_pg_aktif();
  v_pg_kapi    jsonb;
  v_pg_hayvan  text;
  v_pg_kupe    text;
  -- [OVSYNC-PG R3.1 MK7]
  v_occurred_at timestamptz;
  -- [P3b D4] açık takip keşfi (kilitsiz)
  v_takip      record;
  v_takip_var  boolean;   -- FOUND hemen yakalanır (ara SELECT ezmesin)
BEGIN
  -- [OVSYNC-PG R3.1 MK9] kilit sırası: hayvan → seans → görev. Bayrak açıkken
  -- seansın hayvanını kilitsiz çözüp hayvanlar satırını FOR NO KEY UPDATE ile
  -- kilitleriz; sonra (aşağıda) mevcut seans FOR UPDATE'e geçilir. p_uygulanmadi
  -- dalından bağımsız — sıra her zaman aynı olmalı (deadlock önleme).
  IF v_pg_aktif THEN
    SELECT c.animal_id INTO v_pg_hayvan
      FROM public.treatment_day_uygulamalar t
      JOIN public.cases c ON c.id = t.case_id
     WHERE t.id = p_seans_admin_id;
    IF v_pg_hayvan IS NOT NULL THEN
      PERFORM 1 FROM public.hayvanlar h WHERE h.id = v_pg_hayvan FOR NO KEY UPDATE;
    END IF;
  END IF;

  -- RACE CONDITION GUARD
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar
  WHERE id = p_seans_admin_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadi');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans zaten kapatilmis', 'race', true);
  END IF;

  IF p_uygulanmadi THEN
    -- Seans tablosunu isaretle
    UPDATE public.treatment_day_uygulamalar
    SET uygulanmadi = true, iptal_nedeni = p_not, updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;

    -- drug_admins senkron
    UPDATE public.drug_administrations
    SET uygulanmadi = true
    WHERE seans_admin_id = p_seans_admin_id
      AND uygulanmadi IS DISTINCT FROM (true);  /* statik-çözümleyici yerleşimi: DISTINCT-true yanlış-pozitifi; semantik birebir */

    -- Stok iade: stok_hareket_ref kolonu Faz 1'de yok.
    -- Bunun yerine drug_admins.notlar pattern'i ile bul:
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.seans_admin_id = p_seans_admin_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;
    v_tip := 'TEDAVI_SEANS_IPTAL';
  ELSE
    -- [OVSYNC-PG S-4] kapı yalnız uygulandı yolunda (p_uygulanmadi=false).
    -- Blok → RAISE; seans açık kalır, kullanıcı 'uygulanmadı' işaretleyebilir.
    -- [OVSYNC-PG R3.1 MK9] v_pg_hayvan yukarıda (kilit sırası bloğunda) zaten
    -- çözüldü; burada yalnız NULL koruması tekrarlanır (case_id yok/silinmiş).
    IF v_pg_aktif THEN
      IF v_pg_hayvan IS NULL THEN
        RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'SEANS_HAYVAN_YOK',
          'seans_admin_id', p_seans_admin_id, 'case_id', v_seans.case_id);
      END IF;
      v_pg_kapi := public._pg_kapi(v_pg_hayvan, v_seans.stok_id, v_seans.drug_product_id, COALESCE(p_pg_onay, false));

      -- ═══ P3b D4 TAKIP_ACIK preflight (plan.md:408) — KİLİTSİZ keşif; İLK
      -- YAZMADAN (tdu UPDATE) ÖNCE; birleşik payload P2b sarmal deseni.
      SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
        FROM public.gorev_log g
       WHERE g.hayvan_id = v_pg_hayvan
         AND g.gorev_tipi = 'TAKIP_MUAYENE'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
       ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
       LIMIT 1;
      v_takip_var := FOUND;

      IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
        SELECT h.kupe_no INTO v_pg_kupe FROM public.hayvanlar h WHERE h.id = v_pg_hayvan;
        IF v_takip_var AND NOT COALESCE(p_takip_onay, false) THEN
          RAISE EXCEPTION 'PG_KAPI:TAKIP_ACIK:%',
            jsonb_build_object(
              'pg_kapi', public._pg_kapi_detay(v_pg_kapi, v_pg_hayvan, v_pg_kupe)
                         || jsonb_build_object('seans_admin_id', p_seans_admin_id,
                                               'case_id', v_seans.case_id),
              'takip_acik', jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                                               'muayene_saat', v_takip.hedef_saat)
            )::text;
        END IF;
        RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
          public._pg_kapi_detay(v_pg_kapi, v_pg_hayvan, v_pg_kupe)
            || jsonb_build_object('seans_admin_id', p_seans_admin_id, 'case_id', v_seans.case_id);
      END IF;

      IF v_takip_var THEN
        IF NOT COALESCE(p_takip_onay, false) THEN
          RAISE EXCEPTION 'TAKIP_ACIK:%',
            jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                               'muayene_saat', v_takip.hedef_saat)::text;
        END IF;
        PERFORM public._takip_kapat(v_takip.id, 'PG');
      END IF;
    END IF;
    -- Seans tamamlandi
    UPDATE public.treatment_day_uygulamalar
    SET uygulama_tamamlandi_at = now(),
        uygulama_notu = p_not,
        gerceklesme_saati = NOW()::time,
        updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans baska biri tarafindan kapatilmis', 'race', true);
    END IF;
    -- [OVSYNC-PG S-4] PG gerçekleşme kaydı; source_id = seans id
    -- [OVSYNC-PG R3.1 MK7] occurred_at = LEAST(now(), planlanan an) — kaydın geç
    -- girilmesi TAI'yi ileri kaydırmasın.
    IF v_pg_aktif THEN
      v_occurred_at := LEAST(now(), (v_seans.planned_date + v_seans.planned_time) AT TIME ZONE 'Europe/Istanbul');
      PERFORM public._pg_olay_isle('TEDAVI_SEANS', p_seans_admin_id::text, v_pg_hayvan,
        v_seans.stok_id, v_seans.drug_product_id, v_occurred_at, v_pg_kapi, p_pg_gerekce);
    END IF;
    v_tip := 'TEDAVI_SEANS_TAMAM';
  END IF;

  -- Gorev log kapat
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE seans_admin_id = p_seans_admin_id AND tamamlandi = false;

  -- Tum seanslar done mi?
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
  INTO v_total, v_done
  FROM public.treatment_day_uygulamalar
  WHERE treatment_day_id = v_seans.treatment_day_id;

  v_all_done := (v_total = v_done);

  IF v_all_done THEN
    -- Gun seviyesi tamamlandi
    UPDATE public.treatment_days
    SET tamamlandi = true,
        tamamlanma_tarihi = now()
    WHERE id = v_seans.treatment_day_id AND tamamlandi = false;

    UPDATE public.gorev_log
    SET tamamlandi = true, tamamlanma_tarihi = now()
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND tamamlandi = false
      AND (aciklama::jsonb->>'day_id')::uuid = v_seans.treatment_day_id;
  END IF;

  -- Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, v_tip,
    (SELECT animal_id FROM public.cases WHERE id = v_seans.case_id),
    p_seans_admin_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', p_seans_admin_id::text)
      ),
      'gun_tamam', v_all_done
    )
  );

  RETURN jsonb_build_object('ok', true, 'seans_done', true, 'gun_tamam', v_all_done);
END;
$function$;

-- start_first_service_protocol · start_first_service_protocol(uuid,boolean) · md5 9c7344bbb42e53246f63bcd7999b7525
CREATE OR REPLACE FUNCTION public.start_first_service_protocol(p_gorev_id uuid, p_takip_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g           record;
  v_g2          record;
  v_h           record;
  v_takip       record;
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

  -- ═══ P3b MK9 düzeltmesi (plan.md:424-428; §10f C3): görev KİLİTSİZ okunur;
  -- hızlı retler kilitsiz veriyle aynı sırada. Eski gövde görevi ÖNCE FOR
  -- UPDATE (:44/:53) alıp hayvanı SONRA FOR UPDATE (:62/:82) kilitliyordu —
  -- bilinen tek kurucu MK9 ihlali (sarmal: hayvan→görev; start: görev→hayvan).
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id;
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

  -- K4 (2026-09-26): erken-çağrı kapısı — hedefe 2 günden çok varsa RET.
  -- Pencere hedef−2 gün AÇIK (dahil): v_bugun < hedef-2 → red. T13: gelecek-
  -- hedefli görev sessizce zincir açıyordu (v_s := GREATEST geleceği kabulleniyor).
  IF v_bugun < v_g.hedef_tarih - 2 THEN
    RAISE EXCEPTION 'OVSYNC_ERKEN:%', jsonb_build_object(
      'gorev_id', p_gorev_id,
      'hedef_tarih', v_g.hedef_tarih,
      'kalan_gun', (v_g.hedef_tarih - v_bugun),
      'acilisa_kalan_gun', (v_g.hedef_tarih - v_bugun - 2));
  END IF;

  -- ═══ Hayvan İLK kilit (MK9-N muteks — hayvan satırında ASLA FOR UPDATE:
  -- FK KEY SHARE'i bloklar; eski :62'nin yukarı alınmış + NKU'ye dönüşmüş hali).
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = v_g.hayvan_id FOR NO KEY UPDATE;

  -- protokol_instance okuması hayvan kilidinden SONRA (vaka/seans katmanı
  -- okuması — kilit değil, alt sıra serbest).
  SELECT baslangic INTO v_olay FROM public.protokol_instance WHERE id = v_g.protokol_instance_id;
  v_olay := COALESCE(v_olay, v_g.hedef_tarih - 51);

  -- ═══ Görev yeniden kilit + yeniden doğrulama: kilitsiz okuma ile arada
  -- kapanmışsa zaten-kapalı dönüşü; açık kalmışsa v_g2 üzerinden devam.
  SELECT * INTO v_g2 FROM public.gorev_log WHERE id = p_gorev_id FOR NO KEY UPDATE;
  IF v_g2.gorev_tipi IS DISTINCT FROM 'OVSYNC_BASLAT' THEN
    RAISE EXCEPTION 'GOREV_TIPI_UYUMSUZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g2.gorev_tipi);
  END IF;
  IF COALESCE(v_g2.tamamlandi, false) OR COALESCE(v_g2.iptal, false) THEN
    RETURN jsonb_build_object('ok', true, 'zaten', true, 'gorev_id', p_gorev_id,
      'iptal', COALESCE(v_g2.iptal, false), 'kapatan_ref', v_g2.kapatan_ref);
  END IF;

  -- ── Otomatik muafiyetler (SK7 final seti — v_h üzerinden; IF zinciri birebir)
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSIF COALESCE(v_h.kisir, false) THEN
    v_neden := 'KISIR';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu
    SELECT t.sonuc INTO v_son_sonuc FROM public.tohumlama t
     WHERE t.hayvan_id = v_g2.hayvan_id
       ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
       LIMIT 1;
    IF v_son_sonuc = 'Gebe' THEN
      v_neden := 'GEBE';
    ELSIF v_son_sonuc = 'Bekliyor' THEN
      v_neden := 'BEKLIYOR';
    ELSIF EXISTS (SELECT 1 FROM public.cases c
                   WHERE c.animal_id = v_g2.hayvan_id
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
     WHERE id = v_g2.protokol_instance_id AND durum = 'aktif';
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('FIRST_SERVICE_SKIPPED', v_g2.hayvan_id, p_gorev_id::text, 'gorev_log',
            jsonb_build_object('gorev_id', p_gorev_id, 'neden', v_neden,
              'kaynak', v_g2.kaynak, 'olay_tarihi', v_olay, 'hedef_tarih', v_g2.hedef_tarih),
            '{}'::jsonb);
    RETURN jsonb_build_object('ok', true, 'atlandi', v_neden, 'gorev_id', p_gorev_id);
  END IF;

  -- ═══ P3b takip kapısı (C2 tekil desen; ilk yazmadan ÖNCE — _vaka_ac_tek'in
  -- cases INSERT'i P3a Ovsync tetikleyicisini ateşlemeden kapı burada çalışır;
  -- onaylı → _takip_kapat(neden='OVSYNC') vaka-yolu kapanış sınıfı).
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = v_g2.hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  IF FOUND THEN
    IF NOT COALESCE(p_takip_onay, false) THEN
      RAISE EXCEPTION 'TAKIP_ACIK:%',
        jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                           'muayene_saat', v_takip.hedef_saat)::text;
    END IF;
    PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
  END IF;

  -- ── Başlangıç, şablon, hastalık (birebir) ─────────────────────────────
  v_s := GREATEST(v_g2.hedef_tarih, v_bugun);

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

  -- ── Atomik zincir (birebir) ────────────────────────────────────────────
  v_res := public._vaka_ac_tek(v_g2.hayvan_id, v_disease_id, 'İlk tohumlama zinciri', v_s);
  IF (v_res->>'ok') IS DISTINCT FROM 'true' OR (v_res->>'case_id') IS NULL THEN
    RAISE EXCEPTION 'OVSYNC_VAKA_ACILAMADI:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'hayvan_id', v_g2.hayvan_id, 'sonuc', v_res);
  END IF;
  v_case_id := (v_res->>'case_id')::uuid;

  UPDATE public.cases
     SET protocol_family = 'OVSYNC'
   WHERE id = v_case_id
     AND protocol_family IS NULL;

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

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'ILK_TOH_D58_IPTAL'
     WHERE hayvan_id = v_g2.hayvan_id
       AND kaynak = 'DOGUM-' || v_g2.hayvan_id
       AND gorev_tipi = 'DIGER'
       AND aciklama ILIKE '%kızgınlık takibi%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
       AND hedef_tarih BETWEEN v_olay + 50 AND v_olay + 70
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_d58 FROM u;

  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true,
           kapatan_ref = 'ILK_TOH_PROTOKOL_YERINE:' || v_case_id::text
     WHERE hayvan_id = v_g2.hayvan_id
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND kaynak LIKE 'PG_TOHUMLAMA:%'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_gorev_iptal FROM u;

  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = 'case:' || v_case_id::text
   WHERE id = p_gorev_id;
  UPDATE public.protokol_instance
     SET durum = 'tamamlandi', kapandi_at = now(), kapandi_sebep = 'case:' || v_case_id::text
   WHERE id = v_g2.protokol_instance_id AND durum = 'aktif';

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
  VALUES ('FIRST_SERVICE_PROTOCOL_STARTED', v_g2.hayvan_id, v_case_id::text, 'cases',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'case_id', v_case_id,
            'sablon_id', v_sablon_id, 'disease_id', v_disease_id,
            'baslangic', v_s, 'olay_tarihi', v_olay, 'kaynak', v_g2.kaynak,
            'tohumlama_gorev_id', v_tai_id,
            'seans_sayisi', (v_sab->>'seans_sayisi')::int,
            'd58_iptal', to_jsonb(v_d58),
            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal)),
          '{}'::jsonb);

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id, 'tohumlama_gorev_id', v_tai_id,
                            'baslangic', v_s, 'd58_iptal', to_jsonb(v_d58),
                            'pg_gorev_iptal', to_jsonb(v_pg_gorev_iptal));
END;
$function$;

-- tedavi_sablon_uygula · tedavi_sablon_uygula(uuid,uuid,date,boolean,text) · md5 7cc9e46508c3f4fab10516a5676d026e
CREATE OR REPLACE FUNCTION public.tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date DEFAULT NULL::date, p_pg_onay boolean DEFAULT NULL::boolean, p_pg_gerekce text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_case         record;
  v_gun_no       smallint;
  v_date         date;
  v_sessions     jsonb;
  v_atlanan      jsonb := '[]'::jsonb;
  v_gun_atlanan  jsonb;
  v_gun_sayisi   int := 0;
  v_seans_sayisi int := 0;
  v_sablon_hayvan text;
  v_sablon_kupe   text;
  v_sablon_kalem  record;
  v_kapi          jsonb;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  -- 000018 (cila2 C1): OVSYNC-aile şablonu kısır hayvana uygulanamaz.
  -- Fail-closed: yumuşak dönüş değil, KISIR_HAYVAN_OVSYNC_YASAK exception.
  PERFORM public._kisir_ovsync_guard(
    v_case.animal_id,
    EXISTS (SELECT 1 FROM public.tedavi_sablonu s
             WHERE s.id = p_sablon_id AND s.protokol_ailesi = 'OVSYNC'));

  -- ── PG kapısı (hizli_uygulama deyimi): İLK yazmadan ÖNCE ──
  SELECT c.animal_id INTO v_sablon_hayvan FROM public.cases c WHERE c.id = p_case_id;
  FOR v_sablon_kalem IN
    SELECT k.stok_id AS stok_id, k.drug_product_id AS drug_product_id
      FROM public.tedavi_sablonu_kalem k
     WHERE k.sablon_id = p_sablon_id
       AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
       AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id))
       AND public._pg_urun_durumu(k.stok_id, k.drug_product_id) = 'PG'
  LOOP
    v_kapi := public._pg_kapi(v_sablon_hayvan, v_sablon_kalem.stok_id, v_sablon_kalem.drug_product_id, COALESCE(p_pg_onay, false));
    IF v_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      SELECT h.kupe_no INTO v_sablon_kupe FROM public.hayvanlar h WHERE h.id = v_sablon_hayvan;
      RAISE EXCEPTION 'PG_KAPI:%:%', v_kapi->>'karar',
        public._pg_kapi_detay(v_kapi, v_sablon_hayvan, v_sablon_kupe);
    END IF;
  END LOOP;

  FOR v_gun_no IN
    SELECT DISTINCT gun_no FROM public.tedavi_sablonu_kalem
    WHERE sablon_id = p_sablon_id ORDER BY gun_no
  LOOP
    v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_gun_no - 1);

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'planned_time',    to_char(k.planned_time,'HH24:MI'),
             'stok_id',         k.stok_id,
             'drug_product_id', k.drug_product_id,
             'dose',            k.dose,
             'unit',            k.unit,
             'route',           k.route
           ) ORDER BY k.planned_time), '[]'::jsonb)
    INTO v_sessions
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
      AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id));

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gun_no', k.gun_no,
             'planned_time', to_char(k.planned_time,'HH24:MI'),
             'neden', 'silinmiş ilaç/stok')), '[]'::jsonb)
    INTO v_gun_atlanan
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND ((k.drug_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
        OR (k.stok_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id)));
    IF jsonb_array_length(v_gun_atlanan) > 0 THEN
      v_atlanan := v_atlanan || v_gun_atlanan;
    END IF;

    IF jsonb_array_length(v_sessions) > 0 THEN
      PERFORM public.add_treatment_day_with_sessions(p_case_id, v_date, v_sessions, NULL);
      v_gun_sayisi   := v_gun_sayisi + 1;
      v_seans_sayisi := v_seans_sayisi + jsonb_array_length(v_sessions);
    END IF;
  END LOOP;

  -- S-3 provenance (bayraktan bağımsız, salt metadata): vakanın İLK şablon
  -- uygulaması damgalanır; source_template_id doluysa ikinci uygulama BU
  -- provenance'ı (source_template_id, protocol_snapshot) EZMEZ (R3.1) — dal
  -- yalnız source_template_id IS NULL iken çalışır.
  UPDATE public.cases c
     SET source_template_id = t.id,
         protocol_family    = COALESCE(t.protokol_ailesi, c.protocol_family),
         protocol_snapshot  = jsonb_build_object(
           'sablon_id',       t.id,
           'ad',              t.ad,
           'protokol_ailesi', t.protokol_ailesi,
           'tohumlama_plani', t.tohumlama_plani,
           'kalemler', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                 'gun_no',          k.gun_no,
                                 'planned_time',    to_char(k.planned_time,'HH24:MI'),
                                 'stok_id',         k.stok_id,
                                 'drug_product_id', k.drug_product_id,
                                 'dose',            k.dose,
                                 'unit',            k.unit,
                                 'route',           k.route
                               ) ORDER BY k.gun_no, k.planned_time, k.id), '[]'::jsonb)
                          FROM public.tedavi_sablonu_kalem k
                         WHERE k.sablon_id = t.id),
           'uygulama_at',     now(),
           'baslangic',       COALESCE(p_baslangic_tarihi, v_case.start_date))
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NULL
     AND t.id = p_sablon_id;

  -- R3.1 (#12): source_template_id ZATEN doluysa (ikinci+ şablon uygulaması)
  -- yukarıdaki dal atlanır — provenance/snapshot ezilmez. Ama protocol_family
  -- hâlâ NULL ise (ör. ilk uygulanan şablon ailesizdi: Mastit gibi) ve bu
  -- şablonun ailesi doluysa, YALNIZ protocol_family ayrı bir UPDATE ile
  -- doldurulur; source_template_id ve protocol_snapshot bu dalda DOKUNULMAZ.
  UPDATE public.cases c
     SET protocol_family = t.protokol_ailesi
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NOT NULL
     AND c.protocol_family IS NULL
     AND t.protokol_ailesi IS NOT NULL
     AND t.id = p_sablon_id;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$function$;

-- tohumlama_bos_ve_devam · tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean) · md5 ba1ba4bb7b870171e190013d7fc090c8
CREATE OR REPLACE FUNCTION public.tohumlama_bos_ve_devam(p_tohumlama_id text DEFAULT NULL::text, p_muayene_gorev_id uuid DEFAULT NULL::uuid, p_secim text DEFAULT NULL::text, p_pg_urun text DEFAULT NULL::text, p_pg_doz numeric DEFAULT NULL::numeric, p_gun integer DEFAULT NULL::integer, p_saat time without time zone DEFAULT NULL::time without time zone, p_notlar text DEFAULT NULL::text, p_onay boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bayrak      boolean := public._ovsync_pg_aktif();
  v_gorev       record;
  v_toh         record;
  v_hayvan      record;
  v_hayvan_id   text;
  v_toh_id      text;
  v_islem_id    text   := gen_random_uuid()::text;
  v_onceki_durum text;
  v_iptal_gorev_ids text[] := '{}';
  v_gecerli     boolean;
  v_tip         text;
  v_kural       date;
  v_bugun       date;
  v_takip       record;
  v_takip_var   boolean := false;
  v_pg_kapi     jsonb;
  v_hizli       jsonb;
  v_stok        record;
  v_pg_event    record;
  v_son_pg      jsonb;
  v_pg_adi      text;
  v_pg_doz_v    numeric;
  v_pg_birim    text;
  v_deneme      bigint;
  v_yeni_hedef  date;
  v_ilk         timestamptz;
  v_toplam      int;
  v_gebe        jsonb;
  v_takip_id    uuid;
  v_ovsync_id   uuid;
  v_kupe        text;
BEGIN
  -- ══ 0) XOR guard (#9 — plan.md:298) ══════════════════════════════════════
  IF (p_tohumlama_id IS NULL) = (p_muayene_gorev_id IS NULL) THEN
    RAISE EXCEPTION 'GIRIS_CIFT_ANLAMLI:%',
      jsonb_build_object(
        'p_tohumlama_id',     p_tohumlama_id,
        'p_muayene_gorev_id', p_muayene_gorev_id
      )::text;
  END IF;

  -- ══ 1) H4 kilitsiz keşif ═════════════════════════════════════════════════
  IF p_muayene_gorev_id IS NOT NULL THEN
    SELECT g.id, g.hayvan_id, g.gorev_tipi, g.hedef_tarih, g.hedef_saat, g.kaynak,
           g.ref_tohumlama_id,
           COALESCE(g.tamamlandi, false) AS tamam,
           COALESCE(g.iptal, false)      AS iptal
      INTO v_gorev
      FROM public.gorev_log g
     WHERE g.id = p_muayene_gorev_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TAKIP_KAPALI:%',
        jsonb_build_object('gorev_id', p_muayene_gorev_id, 'neden', 'GOREV_BULUNAMADI')::text;
    END IF;
    IF v_gorev.gorev_tipi NOT IN ('GEBELIK_KONTROL', 'TAKIP_MUAYENE') THEN
      RAISE EXCEPTION 'MUAYENE_GOREV_TIPI_UYUMSUZ:%',
        jsonb_build_object('gorev_tipi', v_gorev.gorev_tipi)::text;
    END IF;
    v_hayvan_id := v_gorev.hayvan_id;
  ELSE
    SELECT id::text, hayvan_id INTO v_toh_id, v_hayvan_id
      FROM public.tohumlama
     WHERE id::text = p_tohumlama_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TOH_YOK:%',
        jsonb_build_object('tohumlama_id', p_tohumlama_id)::text;
    END IF;
  END IF;

  -- ══ 2) MK9-N hayvan muteksi — İLK kilit (DEGISMEZ 13) ════════════════════
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_hayvan_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'TAKIP_HAYVAN_YOK:%', v_hayvan_id;
  END IF;

  -- ══ 3) Alt satır kilitleri — H3 yön kuralı: tohumlama FU ÖNCE, gorev_log FU
  --     SONRA (§10h H3; plan.md:299) ════════════════════════════════════════
  IF p_muayene_gorev_id IS NOT NULL THEN
    -- hedef tohumlama = görev.ref_tohumlama_id (cron P2a-dan GEBELIK_KONTROL ve
    --   P2a kurucu TAKIP_MUAYENE bu kolonu taşır — plan.md:147); yoksa son tohumlama
    SELECT t.* INTO v_toh
      FROM public.tohumlama t
     WHERE t.id::text = COALESCE(v_gorev.ref_tohumlama_id, (
              SELECT t2.id::text FROM public.tohumlama t2
               WHERE t2.hayvan_id = v_hayvan_id
               ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST
               LIMIT 1))
     FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TOH_YOK:%',
        jsonb_build_object('hayvan_id', v_hayvan_id, 'neden', 'GOREV_TOHUM_YOK')::text;
    END IF;
    v_toh_id := v_toh.id::text;

    IF v_gorev.ref_tohumlama_id IS NOT NULL AND v_gorev.ref_tohumlama_id != v_toh_id THEN
      RAISE EXCEPTION 'MUAYENE_TOH_UYUMSUZ:%',
        jsonb_build_object('gorev_tohum', v_gorev.ref_tohumlama_id,
                           'mevcut', v_toh_id,
                           'neden', 'GOREV_TOHUM_SON_DEGIL')::text;
    END IF;

    -- görev kilidi + yeniden doğrulama (TAKIP_KAPALI — yarışta ikinci oturum
    --   kilidi bekler, sonra kapalı/sonuçlu durumu GÖRÜR)
    SELECT COALESCE(tamamlandi, false) AS tamam, COALESCE(iptal, false) AS iptal
      INTO v_gorev.tamam, v_gorev.iptal
      FROM public.gorev_log
     WHERE id = p_muayene_gorev_id
     FOR UPDATE;
    IF v_gorev.tamam OR v_gorev.iptal THEN
      RAISE EXCEPTION 'TAKIP_KAPALI:%',
        jsonb_build_object('gorev_id', p_muayene_gorev_id,
                           'tamamlandi', v_gorev.tamam, 'iptal', v_gorev.iptal)::text;
    END IF;
  ELSE
    SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'TOH_YOK:%',
        jsonb_build_object('tohumlama_id', p_tohumlama_id, 'neden', 'GORUSTE_SILINDI')::text;
    END IF;
    v_toh_id := v_toh.id::text;
  END IF;

  -- ══ 4) Seçim uzayı — açık tablo (plan.md:301; K15/D3) ════════════════════
  -- (IF/ELSIF deyimi: CASE-expression PL/pgSQL'de atama yapılmamış record
  --   alanına IFade içinde bile dokunmaya kalkar — "record not assigned yet";
  --   v_tip: Boş yolunda NULL — payload güvenli erişim)
  v_tip := NULL;
  IF p_muayene_gorev_id IS NOT NULL THEN
    v_tip := v_gorev.gorev_tipi;
  END IF;
  IF p_secim IS NOT NULL THEN
    IF p_muayene_gorev_id IS NOT NULL THEN
      v_gecerli := CASE v_gorev.gorev_tipi
        WHEN 'GEBELIK_KONTROL' THEN p_secim IN ('GEBE', 'OVSYNC', 'PG', 'TAKIP', 'ERTALE')
        ELSE p_secim IN ('GEBE', 'OVSYNC', 'PG', 'ERTALE')
      END;
    ELSE
      v_gecerli := p_secim IN ('OVSYNC', 'PG', 'TAKIP');
    END IF;
    IF NOT v_gecerli THEN
      IF p_muayene_gorev_id IS NOT NULL AND v_tip = 'TAKIP_MUAYENE' AND p_secim = 'TAKIP' THEN
        RAISE EXCEPTION 'TAKIP_YENIDEN_SECILEMEZ:%',
          jsonb_build_object('gorev_id', p_muayene_gorev_id, 'gorev_tipi', v_tip)::text;
      END IF;
      RAISE EXCEPTION 'SECIM_TANIMSIZ:%',
        jsonb_build_object('secim', p_secim, 'gorev_tipi', v_tip)::text;
    END IF;
  END IF;

  -- ══ 5) Dry-run (p_secim=NULL — yan etki YOK; bayrak-bağımsız hesap) ══════
  IF p_secim IS NULL THEN
    v_bugun := (now() AT TIME ZONE 'Europe/Istanbul')::date;
    v_kural := public._ovsync_kural_tarihi(v_hayvan_id);

    -- son_pg (C6: pg_application_event farm_id TAŞIYAN tek tablo →
    --   farm_id = public.current_farm_id() filtresi ZORUNLU; index
    --   (farm_id, hayvan_id, occurred_at DESC) [20260923000002:498-499])
    SELECT * INTO v_pg_event
      FROM public.pg_application_event e
     WHERE e.hayvan_id = v_hayvan_id
       AND e.farm_id = public.current_farm_id()
     ORDER BY e.occurred_at DESC
     LIMIT 1;

    IF FOUND THEN
      v_pg_doz_v := NULL; v_pg_birim := NULL; v_pg_adi := NULL;
      IF v_pg_event.stok_id IS NOT NULL THEN
        SELECT urun_adi, birim INTO v_pg_adi, v_pg_birim
          FROM public.stok WHERE id = v_pg_event.stok_id;
      END IF;
      IF v_pg_event.source_type = 'HIZLI_UYGULAMA' THEN
        SELECT doz, birim INTO v_pg_doz_v, v_pg_birim
          FROM public.uygulama_log WHERE id::text = v_pg_event.source_id;
      ELSIF v_pg_event.source_type = 'TEDAVI_SEANS' THEN
        SELECT dose, unit INTO v_pg_doz_v, v_pg_birim
          FROM public.treatment_day_uygulamalar WHERE id::text = v_pg_event.source_id;
      ELSIF v_pg_event.source_type = 'TOPLU_ILAC' THEN
        SELECT (snapshot->>'miktar')::numeric, snapshot->>'ilac_adi'
          INTO v_pg_doz_v, v_pg_adi
          FROM public.islem_log WHERE id = v_pg_event.source_id;
      END IF;
      v_son_pg := jsonb_build_object('stok_id', v_pg_event.stok_id, 'urun_adi', v_pg_adi,
                                     'doz', v_pg_doz_v, 'birim', v_pg_birim);
    END IF;

    -- deneme_sayisi (DEGISMEZ 7 / §18.14: SON DOĞUMDAN beri; doğum yoksa ömür
    --   boyu — P1 hayvan_ureme CTE kalıbı birebir [20260929000001:314-320])
    SELECT count(*) INTO v_deneme
      FROM public.tohumlama t
     WHERE t.hayvan_id = v_hayvan_id
       AND ((SELECT max(d2.tarih) FROM public.dogum d2 WHERE d2.anne_id = v_hayvan_id) IS NULL
            OR t.tarih >= (SELECT max(d2.tarih) FROM public.dogum d2 WHERE d2.anne_id = v_hayvan_id));

    -- takip durumu (P1 takiptekiler koşuluyla birebir: tip + !tamamlandi + !iptal)
    SELECT g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = v_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;

    RETURN jsonb_build_object(
      'ok',             true,
      'bayrak_kapali',  NOT v_bayrak,
      'varsayilan_gun', 7,
      'ovsync_kilitli', COALESCE(v_hayvan.kisir, false) OR v_kural IS NULL OR v_kural > v_bugun,
      'kilit_gerekce',  CASE WHEN COALESCE(v_hayvan.kisir, false) THEN 'KISIR'
                             WHEN v_kural IS NULL                  THEN 'TABAN_YOK'
                             WHEN v_kural > v_bugun                THEN 'KURAL_GUNU' END,
      'kural_tarihi',   v_kural,
      'kalan_gun',      CASE WHEN v_kural IS NOT NULL AND v_kural > v_bugun THEN v_kural - v_bugun END,
      'son_pg',         v_son_pg,
      'deneme_sayisi',  v_deneme,
      'takip_acik',     FOUND,
      'takip_bilgi',    CASE WHEN FOUND THEN
                          jsonb_build_object('hedef_tarih', v_takip.hedef_tarih, 'hedef_saat', v_takip.hedef_saat)
                        END
    );
  END IF;

  -- ══ 6) Bayrak kapısı (#6 + MK9-K — plan.md:332) ══════════════════════════
  IF NOT v_bayrak THEN
    RAISE EXCEPTION 'OZELLIK_KAPALI';
  END IF;

  -- ══ 7) GEBE modu (muayene yolu — plan.md:302-304) ════════════════════════
  IF p_secim = 'GEBE' THEN
    -- D1 çekirdeği ÖNCE çağrılır (koşul 5 'açık takip zinciri' bu görevi
    --   kapsadığından — görev tamamlanırsa zincir bulunamaz); görev tamamlama
    --   SONRA. RAISE durumunda tümü geri alınır (tek transaction).
    IF v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN
      v_gebe := public._tohumlama_gebe_uygula(v_toh_id, true);
    ELSE
      v_gebe := public._tohumlama_gebe_uygula(v_toh_id, false);
    END IF;
    IF NOT COALESCE((v_gebe->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'GEBE_SONUC_RED:%',
        jsonb_build_object('mesaj', v_gebe->>'mesaj')::text;
    END IF;

    UPDATE public.gorev_log
       SET tamamlandi = true,
           tamamlanma_tarihi = now(),
           takip_kapanis_nedeni = CASE WHEN v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN 'GEBE_BULUNDU' END
     WHERE id = p_muayene_gorev_id;

    RETURN jsonb_build_object(
      'ok', true, 'secim', 'GEBE', 'gorev_id', p_muayene_gorev_id,
      'tohumlama_id', v_toh_id, 'islem_id', v_gebe->>'islem_id',
      'takip_kapanis', CASE WHEN v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN 'GEBE_BULUNDU' END
    );
  END IF;

  -- ══ 8) ERTALE (yalnız muayene yolu — plan.md:330) ════════════════════════
  IF p_secim = 'ERTALE' THEN
    v_yeni_hedef := (((now() AT TIME ZONE 'Europe/Istanbul')::date) + COALESCE(p_gun, 7));

    IF v_gorev.gorev_tipi = 'TAKIP_MUAYENE' THEN
      -- takip toplam süresi: zincirin İLK kuruluşundan yeni hedefe (S-7 eşik 21 g)
      SELECT min(created_at) INTO v_ilk
        FROM public.gorev_log
       WHERE gorev_tipi = 'TAKIP_MUAYENE' AND kaynak = v_gorev.kaynak;
      IF v_ilk IS NOT NULL THEN
        v_toplam := v_yeni_hedef - (v_ilk AT TIME ZONE 'Europe/Istanbul')::date;
        IF v_toplam >= 21 AND NOT COALESCE(p_onay, false) THEN
          RAISE EXCEPTION 'TAKIP_UZADI:%',
            jsonb_build_object('toplam_gun', v_toplam)::text;
        END IF;
      END IF;
    END IF;

    UPDATE public.gorev_log
       SET hedef_tarih = v_yeni_hedef,
           hedef_saat  = p_saat
     WHERE id = p_muayene_gorev_id;

    RETURN jsonb_build_object(
      'ok', true, 'secim', 'ERTALE', 'gorev_id', p_muayene_gorev_id,
      'tohumlama_id', v_toh_id, 'hedef_tarih', v_yeni_hedef, 'hedef_saat', p_saat
    );
  END IF;

  -- ══ 9) Muayene görevi tamamlanma sözleşmesi (plan.md:333 — ERTALE hariç)
  IF p_muayene_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
       SET tamamlandi = true, tamamlanma_tarihi = now()
     WHERE id = p_muayene_gorev_id;
  END IF;

  -- ══ 10) Boş çekirdeği davranışı — gövdede YENİ kod (§10h H1; davranış
  --      referansı 20260924000001:508-570 birebir) ═════════════════════════
  IF v_toh.sonuc = 'Bekliyor' THEN
    SELECT tohumlama_durumu INTO v_onceki_durum
      FROM public.hayvanlar WHERE id = v_hayvan_id AND durum = 'Aktif';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'HAYVAN_AKTIF_DEGIL:%', v_hayvan_id;
    END IF;

    UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = v_toh_id;
    UPDATE public.hayvanlar SET tohumlama_durumu = 'Boş' WHERE id = v_hayvan_id;

    SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
      FROM public.gorev_log
     WHERE hayvan_id = v_hayvan_id
       AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
       AND NOT tamamlandi AND NOT iptal;

    UPDATE public.gorev_log SET iptal = true
     WHERE hayvan_id = v_hayvan_id
       AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
       AND NOT tamamlandi AND NOT iptal;

    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (
      v_islem_id, 'TOHUMLAMA_SONUC', v_hayvan_id, v_toh_id, 'tohumlama',
      jsonb_build_object(
        'olusturulan', '[]'::jsonb,
        'guncellenen', jsonb_build_array(
          jsonb_build_object('tablo', 'tohumlama', 'id', v_toh_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
          jsonb_build_object('tablo', 'hayvanlar', 'id', v_hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
        ),
        'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
        'iptal_sebep', 'bos'
      )
    );
  ELSIF v_toh.sonuc IS DISTINCT FROM 'Boş' THEN
    -- sonucu zaten girilmiş tohumlama: HİÇBİR yazma olmaz (plan.md:298)
    RAISE EXCEPTION 'TOH_SONUCLU:%',
      jsonb_build_object('tohumlama_id', v_toh_id, 'sonuc', v_toh.sonuc)::text;
  END IF;
  -- (v_toh.sonuc = 'Boş' ise Boş atama adımı atlanır — muayene yolu zincirinde
  --   Boş zaten atanmış; devam işlemi yalnız.)

  -- ══ 11) TAKIP modu (plan.md:329 — _acik_disi_gorev_kur ATLANIR, DEGISMEZ 1)
  IF p_secim = 'TAKIP' THEN
    v_takip_id := public._takip_gorev_kur(
      v_hayvan_id::uuid, v_toh_id,
      COALESCE(p_gun, 7),
      COALESCE(p_saat, (now() AT TIME ZONE 'Europe/Istanbul')::time));
    RETURN jsonb_build_object(
      'ok', true, 'secim', 'TAKIP', 'tohumlama_id', v_toh_id,
      'islem_id', v_islem_id, 'gorev_id', v_takip_id
    );
  END IF;

  -- ══ 12) OVSYNC modu (plan.md:327) ════════════════════════════════════════
  IF p_secim = 'OVSYNC' THEN
    -- TAKIP_ACIK kapısı (DEGISMEZ 3 — hayvanın AÇIK BASKA takibi; görevin
    --   kendisi hariç — muayene yolu görevi zaten tamamlandı)
    SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
      FROM public.gorev_log g
     WHERE g.hayvan_id = v_hayvan_id
       AND g.gorev_tipi = 'TAKIP_MUAYENE'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND (p_muayene_gorev_id IS NULL OR g.id <> p_muayene_gorev_id)
     ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
     LIMIT 1;
    v_takip_var := FOUND;

    IF v_takip_var AND NOT COALESCE(p_onay, false) THEN
      RAISE EXCEPTION 'TAKIP_ACIK:%',
        jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                           'muayene_saat', v_takip.hedef_saat)::text;
    END IF;

    -- Ovsync hard block (DEGISMEZ 6 — kısır / kural günü gelmemiş / tabansız)
    IF COALESCE(v_hayvan.kisir, false) THEN
      RAISE EXCEPTION 'OVSYNC_SECIM_KISIR';
    END IF;
    v_bugun := (now() AT TIME ZONE 'Europe/Istanbul')::date;
    v_kural := public._ovsync_kural_tarihi(v_hayvan_id);
    IF v_kural IS NULL THEN
      RAISE EXCEPTION 'OVSYNC_SECIM_TABAN_YOK';
    END IF;
    IF v_kural > v_bugun THEN
      RAISE EXCEPTION 'OVSYNC_SECIM_ERKEN:%',
        jsonb_build_object('kural_gun', v_kural, 'kalan_gun', v_kural - v_bugun)::text;
    END IF;

    IF v_takip_var THEN
      PERFORM public._takip_kapat(v_takip.id, 'OVSYNC');
    END IF;

    -- kural tarihli OVSYNC_BASLAT (Boş çekirdeğinin mevcut davranışıyla aynı
    --   çağrı; TAKIP'te atlanmıştı — DEGISMEZ 1)
    v_ovsync_id := public._acik_disi_gorev_kur(v_hayvan_id);

    RETURN jsonb_build_object(
      'ok', true, 'secim', 'OVSYNC', 'tohumlama_id', v_toh_id,
      'islem_id', v_islem_id, 'ovsync_gorev_id', v_ovsync_id,
      'takip_kapatildi', v_takip_var
    );
  END IF;

  -- ══ 13) PG modu (plan.md:328 + 331 birleşik kapı) ════════════════════════
  -- p_pg_urun/p_pg_doz zorunlu (sessiz varsayılan YOK — DEGISMEZ 5)
  IF p_pg_urun IS NULL THEN
    RAISE EXCEPTION 'PG_URUN_GEREKLI';
  END IF;
  IF p_pg_doz IS NULL THEN
    RAISE EXCEPTION 'PG_DOZ_GEREKLI';
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_pg_urun;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PG_STOK_YOK:%', jsonb_build_object('stok_id', p_pg_urun)::text;
  END IF;
  IF v_stok.birim IS NULL THEN
    -- uygulama_log.birim NOT NULL [20260603000002:17]; sarmal imzasında birim
    --   parametresi yok → birimsiz stok yazılamaz (fail-closed, sessiz varsayilan YOK)
    RAISE EXCEPTION 'PG_BIRIM_YOK:%', jsonb_build_object('stok_id', p_pg_urun)::text;
  END IF;

  -- TAKIP_ACIK (aynı koşul — OVSYNC dalıyla birebir)
  SELECT g.id, g.hedef_tarih, g.hedef_saat INTO v_takip
    FROM public.gorev_log g
   WHERE g.hayvan_id = v_hayvan_id
     AND g.gorev_tipi = 'TAKIP_MUAYENE'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND (p_muayene_gorev_id IS NULL OR g.id <> p_muayene_gorev_id)
   ORDER BY g.hedef_tarih DESC NULLS LAST, g.created_at DESC NULLS LAST
   LIMIT 1;
  v_takip_var := FOUND;

  -- PG kapısı — hayvan artık Boş (Boş ataması yukarıda); kapı kararı bu
  --   durumdan okunur. _pg_kapi hayvan satırını NKU kilitler [20260923000003:
  --   200-202] — sarmalın muteksine re-entrant.
  v_pg_kapi := public._pg_kapi(v_hayvan_id, p_pg_urun, NULL, COALESCE(p_onay, false));
  v_kupe := v_hayvan.kupe_no;

  IF v_takip_var AND NOT COALESCE(p_onay, false) THEN
    IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      -- birleşik kapı (#4/DEGISMEZ 3 — plan.md:331): önce PG_KAPI detayı,
      --   altına TAKIP_ACIK detayı; tek RAISE, tek p_onay.
      RAISE EXCEPTION 'PG_KAPI:TAKIP_ACIK:%',
        jsonb_build_object(
          'pg_kapi', public._pg_kapi_detay(v_pg_kapi, v_hayvan_id, v_kupe),
          'takip_acik', jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                                           'muayene_saat', v_takip.hedef_saat)
        )::text;
    END IF;
    RAISE EXCEPTION 'TAKIP_ACIK:%',
      jsonb_build_object('muayene_tarihi', v_takip.hedef_tarih,
                         'muayene_saat', v_takip.hedef_saat)::text;
  END IF;

  IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
    RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
      public._pg_kapi_detay(v_pg_kapi, v_hayvan_id, v_kupe)::text;
  END IF;

  IF v_takip_var THEN
    PERFORM public._takip_kapat(v_takip.id, 'PG');
  END IF;

  -- PG çekirdeği (hizli_uygulama — stok düşüm + islem_log + PG event + +48 s
  --   TAI [§18.6] içinde); p_pg_onay=true: sarmal kendi kapısını yukarıda
  --   geçti. Birim: stok kaleminin kayıtlı birimi (sarmal imzasında birim
  --   yok — stok.birim; rota 'IM' sabit — PG enjeksiyonu). notlar: uygulama_log.
  --   notlar NOT NULL [20260603000002:20] — p_notlar NULL ise boş string.
  v_hizli := public.hizli_uygulama(
    v_hayvan_id, p_pg_urun, p_pg_doz, v_stok.birim, 'IM', COALESCE(p_notlar, ''),
    true, COALESCE(p_notlar, ''), NULL);
  IF NOT COALESCE((v_hizli->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'PG_UYGULAMA_RED:%',
      jsonb_build_object('mesaj', v_hizli->>'mesaj')::text;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'secim', 'PG', 'tohumlama_id', v_toh_id, 'islem_id', v_islem_id,
    'uygulama_id', v_hizli->>'id', 'stok_kalan', v_hizli->>'stok_kalan',
    'takip_kapatildi', v_takip_var
  );
END;
$function$;

-- tohumlama_gorev_ertele · tohumlama_gorev_ertele(uuid,date,time without time zone) · md5 d9b19df7d182ddd33bc67ccab7318b1e
CREATE OR REPLACE FUNCTION public.tohumlama_gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time without time zone DEFAULT NULL::time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g          record;
  v_bugun      date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_saat       time;
  v_hedef      timestamptz;
  v_yerel      timestamp;
  v_yeni_tarih date;
  v_yeni_saat  time;
  v_ilk_hedef  date;
  v_toplam     integer;
  v_uyari      text;
BEGIN
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_BULUNAMADI');
  END IF;
  IF v_g.gorev_tipi IS DISTINCT FROM 'TOHUMLAMA_PLANLI' THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'TIP_UYGUN_DEGIL', 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_ACIK_DEGIL');
  END IF;
  IF p_yeni_tarih IS NULL THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'YENI_TARIH_BOS');
  END IF;
  IF p_yeni_tarih < v_bugun THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_tarih', p_yeni_tarih, 'bugun', v_bugun);
  END IF;

  v_saat  := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
  v_hedef := public._tohumlama_pencere((p_yeni_tarih + v_saat) AT TIME ZONE 'Europe/Istanbul');
  IF v_hedef < now() THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_tarih', p_yeni_tarih,
      'yeni_saat', v_saat, 'hedef_at', v_hedef, 'simdi', now());
  END IF;
  v_yerel := v_hedef AT TIME ZONE 'Europe/Istanbul';
  v_yeni_tarih := v_yerel::date;
  v_yeni_saat  := v_yerel::time;

  SELECT (l.payload->>'eski_tarih')::date INTO v_ilk_hedef
    FROM public.islem_log l
   WHERE l.tip = 'TOHUMLAMA_ERTELE'
     AND l.ref_tablo = 'gorev_log'
     AND l.ref_id = p_gorev_id::text
     AND l.payload ? 'eski_tarih'
   ORDER BY l.tarih ASC, l.degisim_txid ASC NULLS LAST
   LIMIT 1;
  v_ilk_hedef := COALESCE(v_ilk_hedef, v_g.hedef_tarih, v_yeni_tarih);

  v_toplam := v_yeni_tarih - v_ilk_hedef;
  v_uyari  := CASE WHEN v_toplam > 7 THEN 'ERTELEME_7_GUN_ASILDI' END;

  UPDATE public.gorev_log
     SET hedef_tarih = v_yeni_tarih, hedef_saat = v_yeni_saat
   WHERE id = p_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_ERTELE', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', p_gorev_id,
            'eski_tarih', v_g.hedef_tarih, 'eski_saat', v_g.hedef_saat,
            'yeni_tarih', v_yeni_tarih, 'yeni_saat', v_yeni_saat,
            'ilk_hedef_tarih', v_ilk_hedef,
            'toplam_erteleme_gun', v_toplam, 'uyari', v_uyari),
          jsonb_build_object(
            'olusturulan', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object(
              'tablo', 'gorev_log', 'id', p_gorev_id::text,
              'onceki',  jsonb_build_object('hedef_tarih', v_g.hedef_tarih, 'hedef_saat', v_g.hedef_saat),
              'sonraki', jsonb_build_object('hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat))),
            'silinen', '[]'::jsonb),
          format('Planlı tohumlama görevi ertelendi: %s %s → %s %s',
                 v_g.hedef_tarih, v_g.hedef_saat, v_yeni_tarih, v_yeni_saat));

  RETURN jsonb_build_object(
    'ok', true, 'gorev_id', p_gorev_id,
    'hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat,
    'ilk_hedef_tarih', v_ilk_hedef, 'toplam_erteleme_gun', v_toplam,
    'uyari', v_uyari);
END;
$function$;

-- vaka_kalan_gunleri_kaydir · vaka_kalan_gunleri_kaydir(uuid,integer) · md5 0f6e319096b3905e56df52dc20bdddc4
CREATE OR REPLACE FUNCTION public.vaka_kalan_gunleri_kaydir(p_case_id uuid, p_gun integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_case          public.cases%ROWTYPE;
  v_gun_satiri    integer := 0;
  v_gorev         integer := 0;
  v_seans         integer := 0;
  v_uygulama      integer := 0;
  v_tai           integer := 0;
  v_ilk_eski      date;
  v_son_eski      date;
  v_ilk_yeni      date;
  v_son_yeni      date;
  v_tai_rec       record;
BEGIN
  -- 0) Parametre: tek yönlü ileri kaydırma (p_gun >= 1 zorunlu)
  IF p_gun IS NULL OR p_gun < 1 THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'case_id', p_case_id, 'gun', p_gun, 'sebep', 'GECERSIZ_GUN');
  END IF;

  -- 1) Vaka kilitle + doğrula
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'case_id', p_case_id, 'gun', p_gun, 'sebep', 'VAKA_BULUNAMADI');
  END IF;
  IF v_case.status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'case_id', p_case_id, 'gun', p_gun, 'sebep', 'VAKA_ACIK_DEGIL', 'status', v_case.status);
  END IF;

  -- 2) Özet: kaydırma ÖNCESİ açık gün tarih aralığı
  SELECT min(td.treatment_date), max(td.treatment_date) INTO v_ilk_eski, v_son_eski
    FROM public.treatment_days td
   WHERE td.case_id = p_case_id AND td.tamamlandi = false;

  -- 3) Gün satırları: yalnız TAMAMLANMAMIŞ günler (tamamlanmışa dokunma)
  UPDATE public.treatment_days td
     SET treatment_date = td.treatment_date + p_gun
   WHERE td.case_id = p_case_id
     AND td.tamamlandi = false;
  GET DIAGNOSTICS v_gun_satiri = ROW_COUNT;

  -- 4) Üst görevler: vakaya bağlı AÇIK TEDAVI_GUN (hedef_saat DOKUNMA)
  UPDATE public.gorev_log g
     SET hedef_tarih = g.hedef_tarih + p_gun
   WHERE g.gorev_tipi = 'TEDAVI_GUN'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND left(g.aciklama, 1) = '{'
     AND EXISTS (SELECT 1
                   FROM public.treatment_days td
                  WHERE td.case_id = p_case_id
                    AND td.id::text = g.aciklama::jsonb ->> 'day_id');
  GET DIAGNOSTICS v_gorev = ROW_COUNT;

  -- 5) Seans görevleri: vakaya bağlı AÇIK TEDAVI_SEANS (hedef_saat DOKUNMA)
  UPDATE public.gorev_log g
     SET hedef_tarih = g.hedef_tarih + p_gun
   WHERE g.gorev_tipi = 'TEDAVI_SEANS'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND left(g.aciklama, 1) = '{'
     AND EXISTS (SELECT 1
                   FROM public.treatment_days td
                  WHERE td.case_id = p_case_id
                    AND td.id::text = g.aciklama::jsonb ->> 'day_id');
  GET DIAGNOSTICS v_seans = ROW_COUNT;

  -- 6) TEDAVI_GUN etiket tazeleme: yalnız biçim-eşleşen 'Gun N tedavisi - DD.MM.YYYY'
  --    (TEDAVI_SEANS etiketi 'Gun N - Seans (HH:MM)' tarih taşımaz — dokunma).
  --    Tarih, 3. adımda kaydırılmış gün satırının YENİ treatment_date'inden üretilir.
  UPDATE public.gorev_log g
     SET aciklama = jsonb_set(
           g.aciklama::jsonb, '{label}',
           to_jsonb('Gun ' || td.day_no || ' tedavisi - '
                    || to_char(td.treatment_date, 'DD.MM.YYYY')))::text
    FROM public.treatment_days td
   WHERE td.case_id = p_case_id
     AND td.tamamlandi = false
     AND td.id::text = g.aciklama::jsonb ->> 'day_id'
     AND g.gorev_tipi = 'TEDAVI_GUN'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND left(g.aciklama, 1) = '{'
     AND g.aciklama::jsonb ->> 'label' ~ '^Gun [0-9]+ tedavisi - [0-9]{2}\.[0-9]{2}\.[0-9]{4}$';

  -- 7) Seans plan satırları: UYGULANMAMIŞ olanlar (uygulanmış = geçmiş, dokunma)
  UPDATE public.treatment_day_uygulamalar tdu
     SET planned_date = tdu.planned_date + p_gun
   WHERE tdu.case_id = p_case_id
     AND tdu.uygulama_tamamlandi_at IS NULL
     AND COALESCE(tdu.uygulanmadi, false) = false;
  GET DIAGNOSTICS v_uygulama = ROW_COUNT;

  -- 8) Şablon-türevi AÇIK TAI: destekli RPC ile (pencere + GECMIS_TARIH +
  --    TOHUMLAMA_ERTELE audit + ilk_hedef/toplam_erteleme_gun soyu devralır;
  --    K10 U5 deseni — demo'da 8/8 kanıtlı). RPC hatası tüm kaydı geri sarar.
  FOR v_tai_rec IN
    SELECT g.id, g.hedef_tarih, g.hedef_saat
      FROM public.gorev_log g
     WHERE g.gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':%'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.id
  LOOP
    PERFORM public.tohumlama_gorev_ertele(
      v_tai_rec.id, v_tai_rec.hedef_tarih + p_gun, v_tai_rec.hedef_saat);
    v_tai := v_tai + 1;
  END LOOP;

  -- 9) Özet: kaydırma SONRASI açık gün tarih aralığı
  SELECT min(td.treatment_date), max(td.treatment_date) INTO v_ilk_yeni, v_son_yeni
    FROM public.treatment_days td
   WHERE td.case_id = p_case_id AND td.tamamlandi = false;

  -- 10) Audit (islem_log immutable; farm_id taşımayan global log)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES (
    'VAKA_KAYDIR',
    v_case.animal_id,
    p_case_id::text,
    'cases',
    jsonb_build_object(
      'case_id', p_case_id,
      'gun', p_gun,
      'tasinan_gun_satiri', v_gun_satiri,
      'tasinan_gorev', v_gorev,
      'tasinan_seans', v_seans,
      'tasinan_uygulama_satiri', v_uygulama,
      'tai', v_tai,
      'eski_ilk_tarih', v_ilk_eski,
      'eski_son_tarih', v_son_eski,
      'yeni_ilk_tarih', v_ilk_yeni,
      'yeni_son_tarih', v_son_yeni),
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'adet', v_gun_satiri,
                           'kosul', 'case_id + tamamlandi=false, treatment_date+N'),
        jsonb_build_object('tablo', 'gorev_log', 'adet', v_gorev + v_seans,
                           'kosul', 'acik TEDAVI_GUN/TEDAVI_SEANS (day_id), hedef_tarih+N'),
        jsonb_build_object('tablo', 'gorev_log', 'adet', v_tai,
                           'kosul', 'acik TAI via tohumlama_gorev_ertele'),
        jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'adet', v_uygulama,
                           'kosul', 'uygulanmamis, planned_date+N')),
      'silinen', '[]'::jsonb),
    format('Vaka kalan gunleri kaydirildi: +%s gun | gun satiri %s, gorev %s, seans %s, uygulama %s, TAI %s | %s .. %s -> %s .. %s',
           p_gun, v_gun_satiri, v_gorev, v_seans, v_uygulama, v_tai,
           v_ilk_eski, v_son_eski, v_ilk_yeni, v_son_yeni));

  RETURN jsonb_build_object(
    'ok', true,
    'case_id', p_case_id,
    'gun', p_gun,
    'tasinan_gun_satiri', v_gun_satiri,
    'tasinan_gorev', v_gorev,
    'tasinan_seans', v_seans,
    'tasinan_uygulama_satiri', v_uygulama,
    'tai', v_tai,
    'ilk_tarih', v_ilk_yeni,
    'son_tarih', v_son_yeni);

EXCEPTION WHEN OTHERS THEN
  -- Tek EXCEPTION bloğu: orijinal SQLSTATE/message korunur (VAKA_KAYDIRILAMAZ /
  -- GECMIS_TARIH / GOREV_ERTELENEMEZ aileleri UI tarafında ayırt edilebilir kalır).
  -- COMMIT/ROLLBACK gövde içinde YOK — transaction migration dosyasına aittir.
  RAISE;
END;
$function$;

-- vaka_kalan_gunleri_kaydir_coklu · vaka_kalan_gunleri_kaydir_coklu(uuid[],integer) · md5 09875ad70b8d98bdd87061738355a964
CREATE OR REPLACE FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(p_gorev_ids uuid[], p_gun integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_sonuc         jsonb;
  v_gid           uuid;
  v_case_id       uuid;
  v_toplam        integer := 0;
  v_kaydirilan    integer := 0;
  v_atlanan       integer := 0;
  v_hatalar       jsonb   := '[]'::jsonb;
  v_detaylar      jsonb   := '[]'::jsonb;
BEGIN
  -- 0) Fail-fast guard'lar: hiçbir vaka dokunulmadan düşer — tekli RPC ile
  --    aynı VAKA_KAYDIRILAMAZ ailesi.
  IF p_gorev_ids IS NULL OR array_length(p_gorev_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object('sebep', 'BOS_LISTE');
  END IF;

  IF p_gun IS NULL OR p_gun < 1 OR p_gun > 31 THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object('sebep', 'GECERSIZ_GUN', 'gun', p_gun);
  END IF;

  IF cardinality(p_gorev_ids) > 200 THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'sebep', 'LIMIT_ASIM', 'istek', cardinality(p_gorev_ids), 'limit', 200);
  END IF;

  -- 1+2) Görev → vaka çözümleme (CTE): çözülemeyen görevler hata dizisine
  --    satır olarak düşer (fail-fast DEĞİL; NULL girdi elemanı dahil —
  --    DISTINCT sayesinde her biri bir kez).
  --    Yüzey yüklemi: açık (tamamlandi/iptal = false) TEDAVI_GUN/TEDAVI_SEANS
  --    + '{' ile başlayan JSON aciklama + day_id'sine eşlenen treatment_days
  --    satırı — iç RPC'nin kabul ettiği kümeyle birebir.
  --    Not: aciklama::jsonb cast'i CASE içinde değerlendirilir — cast'in
  --    'left(aciklama,1)=' kontrolünden önce çalışmasını planner
  --    sıralamasına bırakamaz (CASE değerlendirme sırasını garanti eder;
  --    NULL/bozuk aciklama hata değil çözülemedi demektir).
  FOR v_gid IN
    WITH giris AS (
        SELECT DISTINCT unnest(p_gorev_ids) AS gid)
      , cozulen AS (
        SELECT gi.gid, td.case_id
          FROM giris gi
          JOIN public.gorev_log g
            ON g.id = gi.gid
           AND g.gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
           AND COALESCE(g.tamamlandi, false) = false
           AND COALESCE(g.iptal, false) = false
           AND left(g.aciklama, 1) = '{'
          JOIN public.treatment_days td
            ON td.id::text =
               (CASE WHEN left(g.aciklama, 1) = '{'
                     THEN g.aciklama::jsonb ->> 'day_id' END))
    SELECT gid FROM (SELECT gid FROM giris EXCEPT SELECT gid FROM cozulen) k
    ORDER BY gid
  LOOP
    v_hatalar := v_hatalar || jsonb_build_object('gorev_id', v_gid, 'sebep', 'GOREV_COZULEMEDI');
  END LOOP;

  -- 3) DISTINCT sıralı vaka kümesi: dedup garantili (aynı vakaya bağlı çok
  --    görev tek kaydırma). Yüklem adım 1+2'deki 'cozulen' CTE'si ile BİREBİR
  --    aynıdır (tek tanım çıkarılamaz — CTE deyim-yereldir; iki kopya
  --    senkron tutulmalı). Vaka alt-işlemi: iç RPC raisesa yalnız o vakanın
  --    etkileri geri sarar (plpgsql EXCEPTION = alt-işlem), diğer vakalar
  --    yoluna devam eder → kısmi başarı.
  FOR v_case_id IN
    WITH giris AS (
        SELECT DISTINCT unnest(p_gorev_ids) AS gid)
      , cozulen AS (
        SELECT gi.gid, td.case_id
          FROM giris gi
          JOIN public.gorev_log g
            ON g.id = gi.gid
           AND g.gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
           AND COALESCE(g.tamamlandi, false) = false
           AND COALESCE(g.iptal, false) = false
           AND left(g.aciklama, 1) = '{'
          JOIN public.treatment_days td
            ON td.id::text =
               (CASE WHEN left(g.aciklama, 1) = '{'
                     THEN g.aciklama::jsonb ->> 'day_id' END))
    SELECT DISTINCT case_id
      FROM cozulen
     WHERE case_id IS NOT NULL
     ORDER BY case_id
  LOOP
    v_toplam := v_toplam + 1;
    BEGIN
      SELECT public.vaka_kalan_gunleri_kaydir(v_case_id, p_gun) INTO v_sonuc;
      v_kaydirilan := v_kaydirilan + 1;
      v_detaylar := v_detaylar || jsonb_build_object(
        'case_id', v_case_id,
        'ilk_tarih', v_sonuc -> 'ilk_tarih',
        'son_tarih', v_sonuc -> 'son_tarih',
        'tasinan_gun_satiri', v_sonuc -> 'tasinan_gun_satiri',
        'tasinan_gorev', v_sonuc -> 'tasinan_gorev',
        'tasinan_seans', v_sonuc -> 'tasinan_seans',
        'tasinan_uygulama_satiri', v_sonuc -> 'tasinan_uygulama_satiri',
        'tai', v_sonuc -> 'tai');
    EXCEPTION WHEN OTHERS THEN
      -- Kısmi başarı: hata satır olarak döner (SQLERRM AYNEN — iç RPC'nin
      -- VAKA_KAYDIRILAMAZ:<json> mesajı UI'da ayırt edilebilir kalır).
      v_hatalar := v_hatalar || jsonb_build_object('case_id', v_case_id, 'sebep', SQLERRM);
      IF position('VAKA_ACIK_DEGIL' IN SQLERRM) > 0 THEN
        v_atlanan := v_atlanan + 1;
      END IF;
    END;
  END LOOP;

  -- 4) Audit: TEK özet kaydı (vaka-başına VAKA_KAYDIR iç RPC'den gelir;
  --    islem_log immutable, farm_id taşımayan global log).
  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES (
    'VAKA_KAYDIR_TOPLU',
    NULL,
    'cases',
    jsonb_build_object(
      'gun', p_gun,
      'toplam', v_toplam,
      'kaydirilan', v_kaydirilan,
      'atlanan', v_atlanan,
      'hatalar', v_hatalar),
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb),
    format('Coklu vaka kaydirma: +%s gun | %s vaka isleme alindi, %s kaydirildi, %s atlandi, %s hata satiri',
           p_gun, v_toplam, v_kaydirilan, v_atlanan, jsonb_array_length(v_hatalar)));

  -- 5) Dönüş: kısmi başarı özeti (ok=true, ayrıntı hatalar/detaylar'da).
  RETURN jsonb_build_object(
    'ok', true,
    'toplam', v_toplam,
    'kaydirilan', v_kaydirilan,
    'atlanan', v_atlanan,
    'hatalar', v_hatalar,
    'detaylar', v_detaylar);
END;
$function$;

-- (4) ACL (prod deseni: anon/PUBLIC kapalı; iç yardımcı yalnız service_role; diğerleri authenticated + service_role)
REVOKE ALL ON FUNCTION public._acik_disi_gorev_kur(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._acik_disi_gorev_kur(text) TO service_role;
REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._acik_disi_hedef_ic(text) TO service_role;
REVOKE ALL ON FUNCTION public._ovsync_baslat_gorev_kur(text,date,text,date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._ovsync_baslat_gorev_kur(text,date,text,date) TO service_role;
REVOKE ALL ON FUNCTION public._vaka_ac_tek(text,uuid,text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public._vaka_ac_tek(text,uuid,text,date) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.dogum_kaydet(text,date,text,text,text,numeric,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text,date,text,text,text,numeric,text,text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.gorev_ertele(uuid,date,time without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_ertele(uuid,date,time without time zone) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_baslat_uyarilari() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_baslat_uyarilari() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.protokol_iptal(uuid,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protokol_iptal(uuid,boolean,text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.seans_tamamla(uuid,boolean,text,boolean,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.seans_tamamla(uuid,boolean,text,boolean,text,boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.start_first_service_protocol(uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_first_service_protocol(uuid,boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.tedavi_sablon_uygula(uuid,uuid,date,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_uygula(uuid,uuid,date,boolean,text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.tohumlama_gorev_ertele(uuid,date,time without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_gorev_ertele(uuid,date,time without time zone) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.vaka_kalan_gunleri_kaydir(uuid,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_kalan_gunleri_kaydir(uuid,integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(uuid[],integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(uuid[],integer) TO authenticated, service_role;

-- (5) tren üyeliği kolonu — SAHİP SON ONAYI (veri kaybı: etiketler)
ALTER TABLE public.cases DROP COLUMN ovsync_tren;
ALTER TABLE public.cases DROP COLUMN IF EXISTS ovsync_bagimsiz;   -- D9 (RD9-1)

-- (6) ayar satırları (D1 + D2 tohumları)
DELETE FROM public.protokol_ayar WHERE anahtar IN ('ovsync_tren_aktif', 'ovsync_tren_capa', 'ovsync_tren_one_cekme_gun', 'ovsync_pg_erteleme_tolerans_gun', 'dogum_sonrasi_pg_gorev_aktif');

-- (7) doğrulama (tutmazsa RAISE → çağıranın transaction'ı geri sarılır)
DO $geri$
DECLARE
  v_bek jsonb := '{"_acik_disi_gorev_kur(text)": "cb7b8182151602505b48615148592b2a", "_acik_disi_hedef_ic(text)": "5082fc8884d9ad96a8fa4f16d457c9f5", "_ovsync_baslat_gorev_kur(text,date,text,date)": "66e46e679f85afada875808607a28dac", "_vaka_ac_tek(text,uuid,text,date)": "f9be42278a02581ade0f55230ea37aee", "dogum_kaydet(text,date,text,text,text,numeric,text,text)": "756c56afb83401721521e42e613ab7f9", "gorev_ertele(uuid,date,time without time zone)": "2af93dfba299268b912175c628d4b05c", "ovsync_baslat_uyarilari()": "869dcfef020a01c6446359d13aa988ed", "ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text)": "1765d756f499e3ecc36740e74a65d804", "protokol_iptal(uuid,boolean,text)": "e5487897bf66b1f8f361792cb4bcf74a", "seans_tamamla(uuid,boolean,text,boolean,text,boolean)": "4afb2221a7e95235e754b7ff508d0379", "start_first_service_protocol(uuid,boolean)": "9c7344bbb42e53246f63bcd7999b7525", "tedavi_sablon_uygula(uuid,uuid,date,boolean,text)": "7cc9e46508c3f4fab10516a5676d026e", "tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean)": "ba1ba4bb7b870171e190013d7fc090c8", "tohumlama_gorev_ertele(uuid,date,time without time zone)": "d9b19df7d182ddd33bc67ccab7318b1e", "vaka_kalan_gunleri_kaydir(uuid,integer)": "0f6e319096b3905e56df52dc20bdddc4", "vaka_kalan_gunleri_kaydir_coklu(uuid[],integer)": "09875ad70b8d98bdd87061738355a964"}'::jsonb;
  v_k text; v_m text; v_n int;
BEGIN
  FOR v_k IN SELECT jsonb_object_keys(v_bek) LOOP
    SELECT md5(p.prosrc) INTO v_m FROM pg_proc p WHERE p.oid = to_regprocedure('public.' || v_k);
    IF v_m IS DISTINCT FROM v_bek->>v_k THEN
      RAISE EXCEPTION 'GERI_AL_GOVDE_FARKLI:%', jsonb_build_object('fn', v_k, 'beklenen', v_bek->>v_k, 'gercek', v_m)::text;
    END IF;
  END LOOP;
  SELECT count(*) INTO v_n FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('_ovsync_asama', '_ovsync_gorev_mu', '_ovsync_ic_ac', '_ovsync_ic_mi', '_ovsync_kilit_gorev', '_ovsync_kilit_vaka', '_ovsync_pg1_kayma', '_ovsync_tren_aktif', '_ovsync_tren_ayar', '_ovsync_tren_ertele_plan', '_ovsync_tren_gunu', '_ovsync_tren_gunu_ic', '_ovsync_tren_gunu_mu', '_ovsync_tren_uye_vaka', 'dogum_sonrasi_pg_hatirlatma', 'ovsync_bastan_baslat', 'ovsync_hayvan_ertele', 'ovsync_pg48_tohumla', 'ovsync_tren_ayar_guncelle', 'ovsync_tren_ertele', 'ovsync_tren_ertele_onizle', 'ovsync_tren_listele', 'ovsync_tren_onizle', 'ovsync_tren_yeniden_hedefle');
  IF v_n > 0 THEN RAISE EXCEPTION 'GERI_AL_YENI_FN_KALDI:%', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('_acik_disi_gorev_kur', '_ovsync_baslat_gorev_kur', 'start_first_service_protocol');
  IF v_n <> 3 THEN RAISE EXCEPTION 'GERI_AL_OVERLOAD:%', v_n; END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'cases' AND column_name IN ('ovsync_tren', 'ovsync_bagimsiz')) THEN
    RAISE EXCEPTION 'GERI_AL_KOLON_KALDI';
  END IF;
  IF EXISTS (SELECT 1 FROM public.protokol_ayar WHERE anahtar IN ('ovsync_tren_aktif', 'ovsync_tren_capa', 'ovsync_tren_one_cekme_gun', 'ovsync_pg_erteleme_tolerans_gun', 'dogum_sonrasi_pg_gorev_aktif')) THEN
    RAISE EXCEPTION 'GERI_AL_AYAR_KALDI';
  END IF;
  RAISE NOTICE 'GERI_AL TAMAM: 16 gövde D0 md5, 24 yeni fonksiyon + 3 yeni imza yok, cases.ovsync_tren + ovsync_bagimsiz yok, 5 ayar yok';
END $geri$;
