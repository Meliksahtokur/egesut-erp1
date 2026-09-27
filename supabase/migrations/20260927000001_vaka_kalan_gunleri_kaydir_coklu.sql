-- ============================================================================
-- Migration: 20260927000001_vaka_kalan_gunleri_kaydir_coklu
-- Tarih: 2026-09-27 · Çoklu kaydırma turu Task 1 (SDD plan → uygulama)
-- Etkiler: yeni RPC public.vaka_kalan_gunleri_kaydir_coklu(uuid[], integer)
--   (SECDEF plpgsql VOLATILE, SET search_path = public, pg_temp — tırnaksız)
--
-- Amaç: birden çok AKTİF tedavi vakasını TEK çağrıda +N gün kaydırmak.
--   Girdi görev (gorev_log.id) listesidir: UI, görev kartlarındaki
--   checkbox'lardan seçilen açık TEDAVI_GUN/TEDAVI_SEANS görevlerini geçirir;
--   bu fonksiyon her görevi vakaya çözümleyip, DISTINCT vaka kümesinin her
--   üyesini mevcut tekli RPC public.vaka_kalan_gunleri_kaydir(uuid, integer)
--   (20260925100001, DEĞİŞTİRİLMEDİ — yalnız çağrılır, SELECT INTO ile jsonb
--   sonucu yakalanır) ile kaydırır.
--
-- Kısmi başarı sözleşmesi (partial success):
--   - Tek vakanın kaydırma hatası ÇAĞRIYI DÜŞÜRMEZ; o vakanın alt-işlemi geri
--     sarılır, sonuç hatalar dizisine {case_id, sebep: SQLERRM} satırı olur.
--   - VAKA_ACIK_DEGIL ile düşen vaka ayrıca atlanan sayacına eklenir.
--   - Çözülemeyen görevler hatalara {gorev_id, sebep:'GOREV_COZULEMEDI'}
--     satırı olur (ayrı başlık RAISE EDİLMEZ — hata dizisinde döner).
--   - Dedup: aynı vakaya bağlı birden çok görev TEK kaydırmaya indirgenir
--     (DISTINCT case_id); detaylar'da vaka başına 1 satır.
--
-- Dönüş birimleri: toplam = çözümlenen DISTINCT vaka sayısı; kaydirilan +
--   atlanan + vaka-başına hata satırları = toplam. gorev-başına
--   GOREV_COZULEMEDI satırları ek kalem olarak hatalar'dadır.
--
-- Hata ailesi: tekli RPC ile AYNI — VAKA_KAYDIRILAMAZ:<json>. Fail-fast
--   guard sebepleri: BOS_LISTE / GECERSIZ_GUN (p_gun 1..31) / LIMIT_ASIM
--   (girdi > 200 görev). Vaka-başına sebepler iç RPC'nin SQLERRM'i AYNEN
--   taşınır (VAKA_BULUNAMADI / VAKA_ACIK_DEGIL / GECMIS_TARIH ...).
--
-- Audit: TEK islem_log kaydı tip 'VAKA_KAYDIR_TOPLU' (ref_tablo 'cases',
--   payload özet: gun/toplam/kaydirilan/atlanan/hatalar). Vaka-başına
--   'VAKA_KAYDIR' kayıtları iç RPC'den gelir — burada İKİNCİ KEZ yazılmaz.
--
-- farm_id damgası YOK: fonksiyon yeni tenant satırı üretmez (tüm veri
--   güncellemesi iç RPC'de UPDATE-only); islem_log farm_id kolonu taşımayan
--   global log — 20260925100001 ile aynı gerekçe.
--
-- Geri alınabilir: evet — DROP FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(uuid[], integer);
--   (migration yalnız nesne tanımıdır; kaydırılan veriye dokunmaz — veriyi
--   tekli RPC taşır, DROP geçmiş kaydırmaları geri alamaz).
--
-- Kaynak: docs/plans/2026-09-27-coklu-kaydirma-PLAN.md (Task 1)
--         docs/plans/2026-09-27-coklu-kaydirma-SPEC.md (sahip onaylı)
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(p_gorev_ids uuid[], p_gun integer)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
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

-- Kapı kuralları: PUBLIC/anon kapalı, yalnız authenticated (UI'ın çağırdığı RPC)
REVOKE ALL ON FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(uuid[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(uuid[], integer) TO authenticated;

COMMIT;
