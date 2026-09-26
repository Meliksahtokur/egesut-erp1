-- ============================================================================
-- Migration: 20260925100004_gorev_ertele_rpcs
-- Tarih: 2026-09-25 · Erteleme-genel turu E1-b (zarf E1 / plan-db.md Adım 3)
-- Etkiler: yeni RPC'ler
--   public.gorev_ertele_kural_get(text)            — iç yardımcı (STABLE SECDEF)
--   public.gorev_ertele(uuid, date, time)       — genel erteleme (VOLATILE SECDEF)
--   public.gorev_ertele_kural_listele()         — UI kural kaynağı (STABLE SECDEF)
--
-- Amaç: S1 sahip kararı — teknik engeli olmayan HER görev tipi tekil
--   ertelenebilir; kural kataloğu gorev_ertele_kural'dan (M3) okunur.
--   NOT (ad): yardımcı plandaki `_gorev_ertele_kural` adı YERİNE
--   `gorev_ertele_kural_get` kullanır — M3 tablosu oluşturunca PG otomatik
--   `_gorev_ertele_kural` DİZİ tipini yaratır; baş-altçizgili fonksiyon adı
--   tiplenmemiş literal'li çağrılarda tip-dönüşümü olarak çözümlenip
--   "malformed array literal" üretir [OBSERVED 2026-09-25].
--   S2: TEDAVI_GUN/TEDAVI_SEANS katalogda kapalı → GOREV_ERTELENEMEZ:
--   TIP_ERTELENEMEZ (yerine E0 zincir kaydırma / E4 protokol iptal).
--   tohumlama_gorev_ertele sözleşmesi DEĞİŞMEZ (ayrı fonksiyon, dokunulmaz);
--   TOHUMLAMA_PLANLI yeni RPC'den de ertelenebilir (pencere aynı çekirdek).
--
-- Karar akışı (plan §3.2):
--   1. gorev_log FOR UPDATE → yok: GOREV_BULUNAMADI; p_yeni_tarih NULL: YENI_TARIH_BOS
--   2. kural (fail-closed) → kapalı: TIP_ERTELENEMEZ (tip + kural_kaynagi)
--   3. tamamlandi/iptal → GOREV_ACIK_DEGIL
--   4. p_yeni_tarih < bugun → GECMIS_TARIH (TÜM tipler)
--   5. pencere_kurali='tohumlama' → _tohumlama_pencere yuvarlaması (DOKUNMADAN
--      çağrılır); yuvarlanmış an < now() → GECMIS_TARIH (yalnız pencere tipleri,
--      mevcut S-6 kalıbı); diğerlerinde saat = COALESCE(girdi, görev saati, 09:00)
--   6. max_erteleme_gun DOLU ve aşıldı → MAX_ASIM sert red (NULL = sınır YOK,
--      MK2 — seed'de tümü NULL); asimi_uyari_gun (default 7) aşımı → yalnız uyari
--   7. UPDATE gorev_log SET hedef_tarih/hedef_saat
--   8. OVSYNC_BASLAT: kaynak anahtarı (protokol_instance.kaynak_ref /
--      gorev_log.kaynak, 'ACIK-DISI-<id>-<kural-tarihi>') BİLİNÇLİ YAZILMAZ —
--      kırıntı kararı 2026-09-25 17:35: canlı kanıtla çift-görev koruması zaten
--      iki bağımsız katman (protokol_instance_kaynak_unique + _acik_disi_hedef_ic
--      açık-görev kontrolü); anahtarı yeniden yazmak ESKİ kural-tarihi anahtarını
--      serbest bırakıp idempotansı zayıflatırdı. Açık OVSYNC_BASLAT = zincir
--      başlamamış (TAI start_first_service_protocol anında türetilir) → türetilmiş
--      TAI senkronu vacuous. Korumalar RETURN 'zincir' alanında raporlanır;
--      ZORUNLU çift-görev kabul testi prob'la kanıtlanır.
--
-- Hata ailesi: GOREV_ERTELENEMEZ:<json> (GOREV_BULUNAMADI / YENI_TARIH_BOS /
--   TIP_ERTELENEMEZ / GOREV_ACIK_DEGIL / MAX_ASIM) + GECMIS_TARIH:<json>.
-- Audit: islem_log tip 'GOREV_ERTELE' (TOHUMLAMA_ERTELE kalıbının geneli;
--   ilk_hedef soyu HER İKİ tip kaydından okunur — süreklilik).
--
-- Geri alınabilir: DROP FUNCTION üçü de (veri yazmaz; tanımdır).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) İç yardımcı: kural okuma (fail-closed) ──────────────────────────
CREATE OR REPLACE FUNCTION public.gorev_ertele_kural_get(p_tip text)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  -- Fail-closed: kayıtsız/bilinmeyen tip → ertelenebilir=FALSE. COALESCE
  -- default'u AÇIKÇA görünür (sessiz varsayım yasağı); kural satırı
  -- bulunamayan tip ASLA ertelenemez. max_erteleme_gun=0 belt-and-suspenders.
  SELECT COALESCE(
    (SELECT to_jsonb(k) - 'guncellendi'
       FROM public.gorev_ertele_kural k
      WHERE k.gorev_tipi = p_tip),
    '{"ertelenebilir": false, "pencere_kurali": "yok", "max_erteleme_gun": 0,
      "asimi_uyari_gun": 7, "zincir_tetikler": {}}'::jsonb
  );
$function$;

-- ── 2) Genel erteleme RPC ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time without time zone DEFAULT NULL::time without time zone)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
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

-- ── 3) UI kural kaynağı (JS'e kural kopyası YAZILMAZ) ──────────────────
CREATE OR REPLACE FUNCTION public.gorev_ertele_kural_listele()
RETURNS TABLE(gorev_tipi text, ertelenebilir boolean, pencere_kurali text, max_erteleme_gun integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT k.gorev_tipi, k.ertelenebilir, k.pencere_kurali, k.max_erteleme_gun
    FROM public.gorev_ertele_kural k
   ORDER BY k.gorev_tipi;
$function$;

-- ── Kapı kuralları ─────────────────────────────────────────────────────
-- İç yardımcı: EXECUTE grant'i YOK; PUBLIC/anon kapalı.
REVOKE ALL ON FUNCTION public.gorev_ertele_kural_get(text) FROM PUBLIC, anon;
-- UI'ın çağırdığı RPC'ler: authenticated'a açık.
REVOKE ALL ON FUNCTION public.gorev_ertele(uuid, date, time without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_ertele(uuid, date, time without time zone) TO authenticated;
REVOKE ALL ON FUNCTION public.gorev_ertele_kural_listele() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_ertele_kural_listele() TO authenticated;

COMMIT;
