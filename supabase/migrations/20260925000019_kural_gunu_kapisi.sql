-- 20260925000019_kural_gunu_kapisi.sql — cila2 C5
-- Sahip kuralı: "doğumdan sonra 51. gün, düvelerde de 12 ay 21. gün uygulama
-- başlanmalı ve uyarılar 2 gün önceden ekrana düşmeli" + "32 nolu düve 12 aylık
-- neden sistem bana görev oluşturtmaya çalışıyor?"
--
-- 32'nin cevabı (demo, kanıtlı): OVSYNC_BASLAT görevi kaynak='ACIK-DISI-<id>-2026-09-26',
-- üretici _acik_disi_gorev_kur (çağıran: ilk_tohumlama_zamanlayıcı cron / hayvan_ekle
-- kancası), hedef = _ovsync_kural_tarihi düve bacağı = dogum_tarihi + 12 ay 21 gün
-- (=2025-09-05+386=2026-09-26 — kural HESABI doğru). Kusur: görev satırı kural
-- gününden HAFTALARCA ÖNCE doğuyordu (hedef=GREATEST(kural,bugün) + üretimde
-- kural pencere koşulu yok) — 12 aylık düve listelerde "başlat" davetli görev görüyor.
--
-- Bu migration (fail-closed):
--   1) _ovsync_baslat_gorev_kur: p_kural_tarihi > bugün ise görev KURULMAZ (NULL).
--      Tüm üretim yolları (cron, hayvan_ekle, dogum_kaydet ILK-TOH-DUVE kanca,
--      tohumlama_sonuc_bos) tek çekirdekten kural gününe bağlanır.
--   2) ovsync_baslat_uyarilari: görevsiz uygun açık dişiler için kuralı bugün+2
--      içinde olan satır üretir (uyarı 2 gün önceden panelde; görev kural günü doğar).
--   3) v_eligible düve eşiği: 13 ay (1 year 1 mon) → 12 ay 21 gün (tek eşik;
--      ovsync kuralıyla hizalı — 12a21g↔13ay çelişkisi kapanır).
-- İnek bacağı GREATEST(son doğum, son abort)+51 zaten kurala uygun (20260924000001:92-94).

BEGIN;

-- ── 1) _ovsync_baslat_gorev_kur — canlı gövde + kural-günü kapısı ────────────
CREATE OR REPLACE FUNCTION public._ovsync_baslat_gorev_kur(
  p_hayvan_id text,
  p_baslangic date,
  p_kaynak_ref text,
  p_kural_tarihi date)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

-- ── 2) ovsync_baslat_uyarilari — görevsiz kural-pencereli kol ───────────────
CREATE OR REPLACE FUNCTION public.ovsync_baslat_uyarilari()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
       AND (SELECT public._ovsync_kural_tarihi(h.id)) > (SELECT d FROM bugun)
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
$$;

-- ── 3) v_eligible — düve eşiği 13 ay → 12 ay 21 gün (tek eşik) ──────────────
CREATE OR REPLACE VIEW public.v_eligible AS
 SELECT h.id,
    h.kupe_no,
    h.grup,
    h.padok,
    son_dogum.tarih AS son_dogum_tarihi,
    CURRENT_DATE - son_dogum.tarih AS dogum_gun,
    son_event.tarih AS son_aktivite_tarihi,
        CASE
            WHEN son_event.tarih IS NOT NULL THEN CURRENT_DATE - son_event.tarih
            WHEN son_dogum.tarih IS NOT NULL THEN CURRENT_DATE - son_dogum.tarih
            WHEN h.dogum_tarihi IS NOT NULL THEN GREATEST(0, CURRENT_DATE - (h.dogum_tarihi + '1 year 21 days'::interval)::date)
            ELSE NULL::integer
        END AS sessiz_gun
   FROM hayvanlar h
     LEFT JOIN
     LATERAL ( SELECT max(d.tarih) AS tarih
           FROM dogum d
          WHERE d.anne_id = h.id) son_dogum ON true
     LEFT JOIN
     LATERAL ( SELECT max(ev.tarih) AS tarih
           FROM ( SELECT t.tarih
                   FROM tohumlama t
                  WHERE t.hayvan_id = h.id
                UNION ALL
                 SELECT k.tarih
                   FROM kizginlik_log k
                  WHERE k.hayvan_id = h.id
                UNION ALL
                 SELECT t.abort_tarihi
                   FROM tohumlama t
                  WHERE t.hayvan_id = h.id AND t.abort_tarihi IS NOT NULL
                UNION ALL
                 SELECT t.dogum_tarihi
                   FROM tohumlama t
                  WHERE t.hayvan_id = h.id AND t.dogum_tarihi IS NOT NULL
                UNION ALL
                 SELECT d.tarih
                   FROM dogum d
                  WHERE d.anne_id = h.id) ev) son_event ON true
  WHERE h.cinsiyet = 'Dişi'::text AND h.durum = 'Aktif'::text AND h.kisir IS NOT TRUE AND h.grup !~~* '%buzağı%'::text AND h.grup !~~* '%buzagi%'::text AND h.grup !~~* '%Küçük%'::text AND h.grup !~~* '%Kucuk%'::text AND (h.dogum_tarihi IS NULL OR h.dogum_tarihi <= (CURRENT_DATE - '1 year 21 days'::interval)) AND NOT (EXISTS ( SELECT 1
           FROM tohumlama t
          WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'::text)) AND COALESCE(( SELECT t.sonuc
           FROM tohumlama t
          WHERE t.hayvan_id = h.id
          ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
         LIMIT 1), ''::text) IS DISTINCT FROM 'Bekliyor'::text AND (son_event.tarih IS NULL OR son_event.tarih < (CURRENT_DATE - 50));

-- ── 4) ACL ───────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ovsync_baslat_uyarilari() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_baslat_uyarilari() TO authenticated, service_role;

COMMIT;
