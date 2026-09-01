-- ═════════════════════════════════════════════════════════════════════════════
-- GT v5 REGEN HAZIRLIK PAKETİ — FONKSİYON TASLAKLARI (2. jenerasyon / DELTA)
-- ═════════════════════════════════════════════════════════════════════════════
--
--  ⛔⛔⛔  BU DOSYA ASLA ÇALIŞTIRILMAZ / DEPLOY EDİLMEZ  ⛔⛔⛔
--
--  Amaç: GT v5 denetimli-regen oturumuna hazır girdi. Her blok, canlı şemaya
--  GT'ye eklenmesi önerilen NESNE taslağıdır — imza kaynağı 2026-08-31 canlı
--  snapshot'ı, gövde kaynağı supabase/migrations/ kanonik sırasının SON KAZANANI
--  (transkripsiyonsuz, dosyadan birebir çıkarımdır).
--
--  Delta durumu (2026-09-02, worktree e6d8782): 2026-09-01-gt-v5-audit.md'nin
--  17 denetimli-regen maddesinin TAMAMI hâlâ AÇIK (ara oturumlar GT'yi bu
--  maddeler için düzeltmedi). Buna karşılık ikiz doğum + küpe revizyonu GT'ye
--  kısmen senkronlandı: dogum_kaydet v2 ve hayvan_belirsiz_ureme_listele EŞİT;
--  kupe_musait_mi / hayvan_ekle(15p) / hayvan_guncelle(18p) / asistan_hayvan_detay
--  GT'de ESKİ gövde (Bölüm D).
--
--  NOT: Canlı gövde ile migration gövdesi arasında bilinmeyen farklar olabilir
--  (canlıya migrations dışında dokunulmuşsa). Denetimli oturum, her taslağı
--  canlı pg_get_functiondef çıktısıyla karşılaştırmadan GT'ye işlemez.
--  "GÖVDE CANLIDAN ALINMALI" işaretli bloklar için migration kaynağı YOKTUR.

-- ══════════════════════════════════════════════════════════════════════════
-- BÖLÜM A — Audit #1-11: canlıda VAR, GT'de YOK (imza: 2026-08-31 snapshot; gövde: migration)
-- ══════════════════════════════════════════════════════════════════════════

-- ── #1  _guard_dogum_ileri_tarih() :: trigger
-- Audit #1 · kaynak: 20260831000003:63 · GT'de yok.
-- İlişkili trigger: trg_dogum_guard (dogum B/I/U) — aynı migration'da.
CREATE OR REPLACE FUNCTION public._guard_dogum_ileri_tarih()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tarih IS NOT NULL
     AND NEW.tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Doğum tarihi ileri tarih olamaz: %', NEW.tarih;
  END IF;
  RETURN NEW;
END $$;

-- ── #2  _guard_hayvanlar_cinsiyet_grup() :: trigger
-- Audit #2 · kaynak: 20260831000003:16 · GT'de yok.
-- İlişkili trigger: trg_hayvanlar_guard (hayvanlar B/I/U).
CREATE OR REPLACE FUNCTION public._guard_hayvanlar_cinsiyet_grup()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.cinsiyet = 'Erkek' AND (NEW.grup ILIKE 'Sağmal%' OR NEW.grup ILIKE 'Gebe%') THEN
    RAISE EXCEPTION 'Erkek hayvan Sağmal/Gebe grubuna eklenemez (grup: %)', NEW.grup;
  END IF;
  IF NEW.dogum_tarihi IS NOT NULL
     AND NEW.dogum_tarihi > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Doğum tarihi ileri tarih olamaz: %', NEW.dogum_tarihi;
  END IF;
  RETURN NEW;
END $$;

-- ── #3  _guard_tohumlama_yas_cinsiyet() :: trigger
-- Audit #3 · kaynak: 20260831000003:36 · GT'de yok.
-- İlişkili trigger: trg_tohumlama_guard (tohumlama B/I/U).
CREATE OR REPLACE FUNCTION public._guard_tohumlama_yas_cinsiyet()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_cinsiyet text;
  v_dogum    date;
BEGIN
  SELECT cinsiyet, dogum_tarihi INTO v_cinsiyet, v_dogum
    FROM public.hayvanlar WHERE id = NEW.hayvan_id;
  IF NOT FOUND THEN
    RETURN NEW; -- hayvan referansı çözülemiyor: FK/yetki katmanı ilgilenir
  END IF;
  IF v_cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama kaydı yapılamaz (hayvan: %)', NEW.hayvan_id;
  END IF;
  IF v_dogum IS NOT NULL AND (NEW.tarih - v_dogum) < 365 THEN
    RAISE EXCEPTION '12 aydan küçük hayvana tohumlama kaydı yapılamaz (tohumlama anındaki yaş: % gün)', (NEW.tarih - v_dogum);
  END IF;
  RETURN NEW;
END $$;

-- ── #4  _tohumlama_gorev_uygunluk(p_hayvan_id text, p_tarih date) :: text
-- Audit #4 · kaynak: 20260730000002:21 (tek tanım) · GT'de yok.
CREATE OR REPLACE FUNCTION public._tohumlama_gorev_uygunluk(p_hayvan_id text, p_tarih date)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $function$
DECLARE v_h record;
BEGIN
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum <> 'Aktif' THEN
    RETURN 'Hayvan aktif değil';
  END IF;
  IF v_h.cinsiyet = 'Erkek' THEN
    RETURN 'Erkek hayvana tohumlama görevi açılmaz';
  END IF;
  IF v_h.dogum_tarihi IS NOT NULL AND (p_tarih - v_h.dogum_tarihi) < 365 THEN
    RETURN 'Hayvan hedef tarihte 12 aydan küçük';
  END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RETURN 'Hayvan gebe';
  END IF;
  RETURN NULL;
END;
$function$;
GRANT EXECUTE ON FUNCTION public._tohumlama_gorev_uygunluk(text, date) TO anon, authenticated;

-- ── #5  agent_plans_prune() :: void
-- Audit #5 · kaynak: 20260622000001:31 (tek tanım) · GT'de yok.
CREATE OR REPLACE FUNCTION public.agent_plans_prune() RETURNS void AS $$
BEGIN
  UPDATE public.agent_plans
  SET durum = 'expired'
  WHERE durum = 'pending' AND created_at < now() - interval '30 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── #6  agent_threads_prune() :: void
-- Audit #6 · kaynak: 20260621000004:4 (tek tanım) · GT'de yok.
CREATE OR REPLACE FUNCTION public.agent_threads_prune()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- 90 günden eski
  DELETE FROM public.agent_threads WHERE updated_at < now() - interval '90 days';
  -- Kullanıcı başına 200 üstü (en eskiler)
  DELETE FROM public.agent_threads t
  USING (
    SELECT id, row_number() OVER (PARTITION BY kullanici_id ORDER BY updated_at DESC) AS rn
    FROM public.agent_threads
  ) ranked
  WHERE t.id = ranked.id AND ranked.rn > 200;
END $$;

-- ── #7  planli_tohumlama_kaydet(p_gorev_id uuid, p_hayvan_id, p_tarih, p_sperma, p_hekim_id, p_irk_bilgisi, p_ek_uygulamalar, p_vwp_override) :: jsonb
-- Audit #7 · kaynak: 20260730000001:478 (son kazanan; 20260722000002/3 önceki) · GT'de yok.
-- Snapshot imzası 8 param ✓ uyumlu.
CREATE OR REPLACE FUNCTION public.planli_tohumlama_kaydet(p_gorev_id uuid, p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_gorev record; v_result jsonb; v_tohumlama_id text;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id=p_gorev_id FOR UPDATE;
  IF NOT FOUND OR v_gorev.gorev_tipi<>'TOHUMLAMA_PLANLI' THEN RAISE EXCEPTION 'Planlı tohumlama görevi bulunamadı'; END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN RAISE EXCEPTION 'Görev kapalı'; END IF;
  IF v_gorev.hayvan_id<>p_hayvan_id THEN RAISE EXCEPTION 'Görev hayvanı ile tohumlama hayvanı eşleşmiyor'; END IF;
  v_result:=public.tohumlama_kaydet(p_hayvan_id,p_tarih,p_sperma,p_hekim_id,p_irk_bilgisi,p_ek_uygulamalar,p_vwp_override);
  v_tohumlama_id:=v_result->>'tohumlama_id';
  UPDATE public.tohumlama SET gerceklesme_at=now() WHERE id=v_tohumlama_id::uuid;
  UPDATE public.gorev_log SET tamamlandi=true,iptal=false,tamamlanma_tarihi=now(),ref_tohumlama_id=v_tohumlama_id WHERE id=p_gorev_id;
  INSERT INTO public.islem_log(id,tip,ana_hayvan_id,ref_id,ref_tablo,snapshot)
  VALUES(gen_random_uuid()::text,'PLANLI_TOHUMLAMA_TAMAMLA',p_hayvan_id,p_gorev_id::text,'gorev_log',jsonb_build_object('tohumlama_id',v_tohumlama_id));
  RETURN v_result || jsonb_build_object('gorev_id',p_gorev_id);
END; $function$;

-- ── #10 tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid) :: jsonb
-- Audit #10 · kaynak: 20260730000002:45 (son kazanan; 20260730000001/22000002-3 önceki) · GT'de yok.
CREATE OR REPLACE FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_plan  jsonb;
  v_case  record;
  v_sebep text;
  v_id    uuid;
  v_date  date;
  v_time  time;
BEGIN
  -- nullif(...,'null'::jsonb): kolonda jsonb 'null' skaleri duruyor olabilir.
  SELECT nullif(tohumlama_plani, 'null'::jsonb) INTO v_plan
  FROM public.tedavi_sablonu WHERE id = p_sablon_id;
  IF v_plan IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;
  IF (v_plan->>'gun_ofset') IS NULL OR nullif(v_plan->>'planned_time','') IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Şablondaki tohumlama planı eksik');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vaka bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.gorev_log
             WHERE kaynak = 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text) THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;

  v_date := v_case.start_date + (v_plan->>'gun_ofset')::integer;
  v_time := (v_plan->>'planned_time')::time;

  -- Uygun değilse vaka açılışı patlamaz; görev açılmaz, sebep UI'a döner.
  v_sebep := public._tohumlama_gorev_uygunluk(v_case.animal_id, v_date);
  IF v_sebep IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', v_sebep);
  END IF;

  INSERT INTO public.gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES (gen_random_uuid(), v_case.animal_id, 'TOHUMLAMA_PLANLI', 'Planlı tohumlama', v_date, v_time, false,
          'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'olustu', true, 'gorev_id', v_id);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid) TO anon, authenticated;

-- ── #11 vaka_tohumlama_ekle(p_case_id uuid, p_tarih date, p_saat time) :: jsonb
-- Audit #11 · kaynak: 20260730000002 (tek tanım) · GT'de yok.
CREATE OR REPLACE FUNCTION public.vaka_tohumlama_ekle(
  p_case_id uuid,
  p_tarih   date,
  p_saat    time DEFAULT '08:00'::time
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  v_case  record;
  v_sebep text;
  v_id    uuid;
BEGIN
  IF p_tarih IS NULL OR p_saat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tarih ve saat zorunlu');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;
  IF v_case.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya tohumlama eklenemez');
  END IF;

  -- Vaka başına aynı anda tek açık planlı tohumlama.
  IF EXISTS (SELECT 1 FROM public.gorev_log
             WHERE gorev_tipi = 'TOHUMLAMA_PLANLI'
               AND kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':%'
               AND NOT tamamlandi AND NOT iptal) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu vakada zaten açık bir planlı tohumlama var');
  END IF;

  -- Elle eklemede uygunluk SESSİZ atlanmaz — kullanıcı bilerek istedi, sebebi görsün.
  v_sebep := public._tohumlama_gorev_uygunluk(v_case.animal_id, p_tarih);
  IF v_sebep IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', v_sebep);
  END IF;

  INSERT INTO public.gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES (gen_random_uuid(), v_case.animal_id, 'TOHUMLAMA_PLANLI', 'Planlı tohumlama', p_tarih, p_saat, false,
          'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':MANUEL')
  RETURNING id INTO v_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (gen_random_uuid()::text, 'VAKA_TOHUMLAMA_EKLE', v_case.animal_id, v_id::text, 'gorev_log',
          jsonb_build_object('case_id', p_case_id, 'hedef_tarih', p_tarih, 'hedef_saat', p_saat));

  RETURN jsonb_build_object('ok', true, 'gorev_id', v_id);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.vaka_tohumlama_ekle(uuid, date, time) TO anon, authenticated;

-- ── #8  search_code(query_embedding vector, match_count integer) :: TABLE  ⛔ STUB
-- ── #9  search_memory_notes(query_embedding vector, match_count integer, filter_category text) :: TABLE  ⛔ STUB
--
-- GÖVDE CANLIDAN ALINMALI — migrations/ zincirinde HİÇBİR tanım yok (backup/ dahil
-- tarandı). Bu fn'ler pgvector tabanlı tools-bank kod arama altyapısına ait ve
-- migration dışı (doğrudan DB/manuel kurulum) oluşturulmuş olmalı. Denetimli
-- oturumda pg_get_functiondef ile canlıdan çekilecek; TABLE kolon listesi de
-- canlıdan doğrulanmalı (snapshot yalnız "TABLE(...)" diyor).
--
-- CREATE OR REPLACE FUNCTION public.search_code(
--   query_embedding vector,
--   match_count integer DEFAULT 10
-- ) RETURNS TABLE(...)  -- ← kolon listesi CANLIDAN ALINMALI
-- GÖVDE CANLIDAN ALINMALI;
--
-- CREATE OR REPLACE FUNCTION public.search_memory_notes(
--   query_embedding vector,
--   match_count integer DEFAULT 10,
--   filter_category text DEFAULT NULL
-- ) RETURNS TABLE(...)  -- ← kolon listesi CANLIDAN ALINMALI
-- GÖVDE CANLIDAN ALINMALI;

-- ══════════════════════════════════════════════════════════════════════════
-- BÖLÜM B — Audit #12-13: ortak adda imza SAPMASI (canlı imza ≠ GT imzası)
-- ══════════════════════════════════════════════════════════════════════════

-- ── #12 tohumlama_abort — canlı ANA imza 3-param; GT 2-param (eski)
-- Son kazanan gövde: 20260830000034_review_fix_paketi.sql:9 (20260830000010 önceki).
-- NOT: canlıda eski 2-param overload DA duruyor (snapshot 178-179). GT regen
-- pg_get_functiondef her iki imzayı da üretmeli; aşağıdaki taslak ana (3-param)
-- imzadır.
CREATE OR REPLACE FUNCTION public.tohumlama_abort(p_tohumlama_id text, p_notlar text DEFAULT NULL::text, p_abort_tarihi date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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
  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$
;

-- ── #13 _gorev_dinle — canlıda 4-param (p_tarih date ekli); GT 3-param
-- Son kazanan gövde: 20260628000002_dogum_pg_etken_kod_link.sql:28.
-- NOT: snapshot'ta yalnız 4-param görünüyor → canlıda 3-param overload yok;
-- 20260628000002 imza değişikliğini (default'lu 4. parametre ekleyerek) yeni
-- overload olarak değil REPLACE ile mi uygulamış, denetimli oturumda
-- doğrulanmalı (pg_get_functiondef + pg_proc overload sayısı).
CREATE OR REPLACE FUNCTION public._gorev_dinle(p_hayvan_id text, p_etken_kod text, p_ref text DEFAULT NULL::text, p_tarih date DEFAULT NULL::date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_gorev_id uuid;
BEGIN
  IF p_etken_kod IS NULL OR p_hayvan_id IS NULL THEN
    RETURN;
  END IF;
  SELECT id INTO v_gorev_id
  FROM public.gorev_log
  WHERE hayvan_id = p_hayvan_id
    AND etken_kod = p_etken_kod
    AND tamamlandi = false
    AND iptal = false
  ORDER BY
    CASE WHEN p_tarih IS NULL THEN 0 ELSE abs(hedef_tarih - p_tarih) END ASC,  -- uygulama tarihine en yakın
    hedef_tarih ASC                                                            -- eşitlikte en erken
  LIMIT 1
  FOR UPDATE;
  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = p_ref
    WHERE id = v_gorev_id;
  END IF;
END;
$function$;

-- ══════════════════════════════════════════════════════════════════════════
-- BÖLÜM C — Audit #14-15: tablo id TİP sapması (canlı uuid, GT text) — ALTER taslakları
-- ══════════════════════════════════════════════════════════════════════════

-- ⛔ Bu ALTER taslakları mevcut VERİYİ dönüştürür — yalnız GT v5 regen
-- oturumunda, canlı zaten uuid olduğu için GT dosyasına DOĞRUDAN `id uuid
-- PRIMARY KEY` yazılması tercih edilir (canlıdan pg_dump bunu üretir).
-- Aşağıdaki ALTER'ler boş/kurgu bir text-şemayı uuid'ye çevirme senaryosu
-- içindir; CANLIDA ÇALIŞTIRILMAZ.

-- ── #14 tohumlama.id  text → uuid  (canlı: uuid — snapshot §Tablolar)
-- FK bağımlılığı YOK (hiçbir tablo tohumlama(id) REFERENCES etmiyor — GT taraması).
-- Gövde etkisi: fn'ler `WHERE id::text = p_tohumlama_id` pattern'i kullanıyor;
-- uuid id üzerinde `id::text` cast'i çalışmaya devam eder (geriye uyumlu).
-- ALTER TABLE public.tohumlama
--   ALTER COLUMN id DROP DEFAULT,
--   ALTER COLUMN id TYPE uuid USING id::uuid,
--   ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- ── #15 stok_hareket.id  text → uuid  (canlı: uuid — snapshot §Tablolar + DİKKAT notu)
-- FK bağımlılığı YOK. Canlıda uuid olduğu AGENTS.md'e işlendi (docs denetimi
-- çürütüldü). INSERT pattern'i: gen_random_uuid() (::text YOK).
-- ALTER TABLE public.stok_hareket
--   ALTER COLUMN id DROP DEFAULT,
--   ALTER COLUMN id TYPE uuid USING id::uuid,
--   ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- ══════════════════════════════════════════════════════════════════════════
-- BÖLÜM D — DELTA (audit-sonrası): 20260901000002 küpe revizyonu gövdeleri GT'de ESKİ
-- ══════════════════════════════════════════════════════════════════════════

-- ── D1 kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_hayvan_id) :: jsonb — üç durumlu (recycle K1/K2)
-- GT:2115 gövdesi ESKİ (v_kupe_cakisma/iki durumlu); migration gövdesi üç durumlu
-- (aktif-çakışma + geçmiş bilgi amaçlı kupe_gecmis_id/durum). rpc-reference güncel.
CREATE OR REPLACE FUNCTION public.kupe_musait_mi(
  p_kupe_no text, p_devlet_kupe text, p_hayvan_id text DEFAULT NULL)
RETURNS jsonb AS $func$
DECLARE
  v_aktif_cakisma text; v_devlet_cakisma text;
  v_gecmis_id text; v_gecmis_durum text;
BEGIN
  IF p_kupe_no IS NOT NULL AND p_kupe_no <> '' THEN
    SELECT id INTO v_aktif_cakisma FROM public.hayvanlar
     WHERE kupe_no = p_kupe_no AND durum = 'Aktif'
       AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
    IF v_aktif_cakisma IS NULL THEN
      SELECT id, durum INTO v_gecmis_id, v_gecmis_durum FROM public.hayvanlar
       WHERE kupe_no = p_kupe_no AND durum IS DISTINCT FROM 'Aktif'
         AND (p_hayvan_id IS NULL OR id <> p_hayvan_id)
       ORDER BY cikis_tarihi DESC NULLS LAST, id DESC LIMIT 1;
    END IF;
  END IF;
  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '' THEN
    SELECT id INTO v_devlet_cakisma FROM public.hayvanlar
     WHERE devlet_kupe = p_devlet_kupe
       AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
  END IF;
  RETURN jsonb_build_object(
    'musait', (v_aktif_cakisma IS NULL AND v_devlet_cakisma IS NULL),
    'kupe_cakisma_id', v_aktif_cakisma,
    'kupe_gecmis_id', v_gecmis_id,
    'kupe_gecmis_durum', v_gecmis_durum,
    'devlet_cakisma_id', v_devlet_cakisma);
END; $func$ LANGUAGE plpgsql;

-- ── D2 hayvan_ekle 15-param overload (…, p_padok_id uuid) — küpe/yaş ön kontrolü
-- GT:7125 (overload-2) gövdesi ESKİ; migration gövdesi v_yas_gun/v_chk + kupe_musait_mi
-- ön kontrolü içeriyor. 14-param base overload (GT:2171) migration'da değişmedi.
CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no text DEFAULT NULL::text,
  p_devlet_kupe text DEFAULT NULL::text,
  p_irk text DEFAULT NULL::text,
  p_cinsiyet text DEFAULT NULL::text,
  p_dogum_tarihi date DEFAULT NULL::date,
  p_grup text DEFAULT 'Genel'::text,
  p_padok text DEFAULT NULL::text,
  p_dogum_kg numeric DEFAULT NULL::numeric,
  p_anne_id text DEFAULT NULL::text,
  p_baba_bilgi text DEFAULT NULL::text,
  p_canli_agirlik numeric DEFAULT NULL::numeric,
  p_boy numeric DEFAULT NULL::numeric,
  p_renk text DEFAULT NULL::text,
  p_ayirici_ozellik text DEFAULT NULL::text,
  p_padok_id uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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
  -- Sadece doğum tarihi verildiğinde kontrol et (nullable alan — mevcut satırlar NULL olabilir)
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

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

-- ── D3 hayvan_guncelle 18-param overload (…, p_padok_id, p_kisir) — efektif_dt/grup + küpe kontrolü
-- GT:8219 (overload-3) gövdesi ESKİ; migration gövdesi v_efektif_dt/v_efektif_grup/v_yas_gun
-- + kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_id) kontrolü içeriyor.
CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id text,
  p_kupe_no text DEFAULT NULL::text,
  p_devlet_kupe text DEFAULT NULL::text,
  p_irk text DEFAULT NULL::text,
  p_cinsiyet text DEFAULT NULL::text,
  p_dogum_tarihi date DEFAULT NULL::date,
  p_grup text DEFAULT NULL::text,
  p_padok text DEFAULT NULL::text,
  p_dogum_kg numeric DEFAULT NULL::numeric,
  p_canli_agirlik numeric DEFAULT NULL::numeric,
  p_boy numeric DEFAULT NULL::numeric,
  p_renk text DEFAULT NULL::text,
  p_ayirici_ozellik text DEFAULT NULL::text,
  p_baba_bilgi text DEFAULT NULL::text,
  p_notlar text DEFAULT NULL::text,
  p_anne_id text DEFAULT NULL::text,
  p_padok_id uuid DEFAULT NULL::uuid,
  p_kisir boolean DEFAULT NULL::boolean
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
  v_gebe     boolean;
  v_efektif_dt   date;
  v_efektif_grup text;
  v_yas_gun integer;
  v_chk jsonb;
BEGIN
  -- Küpe değişiyorsa çakışma kontrolü (K1/K2) — kendi kaydı hariç (p_hayvan_id = p_id)
  IF (p_kupe_no IS NOT NULL AND p_kupe_no <> '') OR (p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '') THEN
    SELECT public.kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_id) INTO v_chk;
    IF NOT (v_chk->>'musait')::boolean THEN
      RETURN jsonb_build_object('ok', false, 'error',
        CASE WHEN v_chk->>'kupe_cakisma_id' IS NOT NULL
          THEN 'İşletme küpesi zaten kayıtlı (aktif): ' || COALESCE(p_kupe_no,'')
          ELSE 'Devlet küpesi zaten kayıtlı: ' || COALESCE(p_devlet_kupe,'') END);
    END IF;
  END IF;

  -- Kısır işaretleme validation: gebe hayvan kısır olamaz
  IF p_kisir IS NOT NULL AND p_kisir = true THEN
    SELECT EXISTS (
      SELECT 1 FROM tohumlama t
      WHERE t.hayvan_id = p_id AND t.sonuc = 'Gebe'
    ) INTO v_gebe;
    IF v_gebe THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Gebe hayvan kısır olarak işaretlenemez');
    END IF;
  END IF;

  -- H-11: Yaş/grup validasyonu (js/forms.js:66-77 birebir)
  -- p_dogum_tarihi VEYA p_grup güncelleniyorsa, EFEKTİF (yeni ya da mevcut
  -- satırdan gelen, COALESCE ile) değerler üzerinden kontrol et.
  -- Eğer ikisi de NULL geliyorsa (sadece diğer alanlar güncelleniyor), mevcut
  -- satırın değerleri kullanılır.
  IF p_dogum_tarihi IS NOT NULL OR p_grup IS NOT NULL THEN
    SELECT COALESCE(p_dogum_tarihi, h.dogum_tarihi),
           COALESCE(NULLIF(p_grup, ''), h.grup)
      INTO v_efektif_dt, v_efektif_grup
      FROM hayvanlar h
     WHERE h.id = p_id;

    IF v_efektif_dt IS NOT NULL THEN
      v_yas_gun := floor((current_date - v_efektif_dt));
      IF v_yas_gun < 0 THEN
        RETURN jsonb_build_object('ok', false, 'error', 'Doğum tarihi ileri tarih olamaz');
      END IF;
      IF v_efektif_grup = 'Süt İçen Buzağı' AND v_yas_gun > 180 THEN
        RETURN jsonb_build_object('ok', false, 'error', '6 aylıktan büyük hayvan "Süt İçen Buzağı" grubuna eklenemez');
      END IF;
      IF (v_efektif_grup = 'Süt İçen Buzağı' OR v_efektif_grup = 'Sütten Kesilmiş Buzağı') AND v_yas_gun > 365 THEN
        RETURN jsonb_build_object('ok', false, 'error', '12 aylıktan büyük hayvan buzağı grubuna eklenemez');
      END IF;
    END IF;
  END IF;

  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
  END IF;

  UPDATE hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),        kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),    devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),            irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),       cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,              dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),           grup),
    padok            = COALESCE(v_padok_ad,                  padok),
    padok_id         = COALESCE(v_padok_id,                  padok_id),
    dogum_kg         = COALESCE(p_dogum_kg,                  dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,             canli_agirlik),
    boy              = COALESCE(p_boy,                       boy),
    renk             = COALESCE(NULLIF(p_renk,''),           renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''),ayirici_ozellik),
    baba_bilgi       = COALESCE(NULLIF(p_baba_bilgi,''),     baba_bilgi),
    notlar           = COALESCE(NULLIF(p_notlar,''),         notlar),
    anne_id          = COALESCE(NULLIF(p_anne_id,''),        anne_id),
    kisir            = COALESCE(p_kisir,                     kisir)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- ── D4 asistan_hayvan_detay(p_kupe, p_id) :: jsonb — aktif-öncelik arama (K7)
-- GT:519 gövdesi ESKİ; migration gövdesi kupe eşleşmesinde ORDER BY (durum='aktif') DESC, id
-- içeriyor.
CREATE OR REPLACE FUNCTION public.asistan_hayvan_detay(p_kupe text DEFAULT NULL::text, p_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_h record;
  v_out jsonb;
BEGIN
  SELECT * INTO v_h FROM hayvanlar
   WHERE (p_id IS NOT NULL AND id = p_id)
      OR (p_kupe IS NOT NULL AND kupe_no = p_kupe)
   ORDER BY (durum = 'Aktif') DESC, id
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('bulundu', false);
  END IF;

  v_out := jsonb_build_object(
    'bulundu', true,
    'hayvan', to_jsonb(v_h),
    'tohumlama', (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.tarih DESC), '[]'::jsonb)
                  FROM tohumlama t WHERE t.hayvan_id = v_h.id),
    'gorevler', (SELECT coalesce(jsonb_agg(to_jsonb(g) ORDER BY g.created_at DESC), '[]'::jsonb)
                 FROM gorev_log g WHERE g.hayvan_id = v_h.id),
    'uygulamalar', (SELECT coalesce(jsonb_agg(to_jsonb(u) ORDER BY u.created_at DESC), '[]'::jsonb)
                    FROM uygulama_log u WHERE u.hayvan_id = v_h.id),
    'islem_log', (SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.tarih DESC), '[]'::jsonb)
                  FROM islem_log i WHERE i.ana_hayvan_id = v_h.id)
  );
  RETURN v_out;
END $function$
;

-- DOĞRULANAN SENKRON (taslak gerektirmez — fark-matrisi §B):
--   dogum_kaydet v2 (olay_id ikiz model + gorev_sayisi THEN 10 + buzagi_kupe)
--     GT:9743 ≡ 20260901000002:76 (normalize birebir; yalnız $function$/$$ ve
--     LANGUAGE konum biçim farkı). hayvan_belirsiz_ureme_listele GT:7971 ≡
--     20260901000001:153 (birebir).

-- ══════════════════════════════════════════════════════════════════════════
-- BÖLÜM E — Audit #16: hekim_listesi — KARAR GEREKLİ (bkz. hekim_listesi-karar.md)
-- ══════════════════════════════════════════════════════════════════════════

-- Canlıda YOK (185 adda değil) · GT:2610 CREATE'siz GRANT · tanım 20260308000009:321.
-- ÖNERİ: (b) TEMİZLEME — app.js:30 rpc çağrısı kod-temizlik görevinde silinir;
-- GT regen canlıdan üretildiği için GRANT zaten düşer. Geri yükleme seçeneği ve
-- gerekçeler: hekim_listesi-karar.md. Geri yükleme kararlanırsa taslak:
--
-- CREATE OR REPLACE FUNCTION public.hekim_listesi()
-- RETURNS TABLE(id text, ad text, telefon text, aktif boolean)
-- LANGUAGE sql SECURITY DEFINER AS $$
--   SELECT id, ad, telefon, aktif
--   FROM public.hekimler
--   WHERE aktif = true
--   ORDER BY ad;
-- $$;
-- GRANT EXECUTE ON FUNCTION public.hekim_listesi() TO anon, authenticated;
--
-- (Tanım 20260308000009:321'den aynen; mevcut hekimler(id text) şemasıyla uyumlu.)
