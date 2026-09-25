-- ============================================================================
-- Migration: 20260925000016_baslat_guard_sira
-- Tarih: 2026-09-25 · Cila-onarım F4 onarım turu (K3 review bulgusu)
--
-- HATA (F4 bulgusu): 000012, K3 kısır/Aktif/Dişi guard'ını PARAMETRE
--   doğrulamasının ÖNCESİNE yerleştirdi; bayrak AÇIKKEN NULL/geçersiz
--   p_hayvan_id artık OVSYNC_BASLAT_PARAMETRE hatası yerine sessiz NULL
--   dönüyordu (taban 20260924000001 gövdesinde parametre kontrolü bayrak
--   RETURN NULL'dan hemen sonra, koşulsuzdu). Pratik çağrıcıların tümü
--   (dogum_kaydet, _acik_disi_gorev_kur, tohumlama_abort zinciri) non-NULL
--   geçtiğinden üretim etkisi yok — ancak sözleşme davranışı (parametre
--   ihlali = exception) sessizce değişmişti.
-- ONARIM: guard bloğu parametre doğrulamasının ARDINA taşınır. Gövde tabanı
--   = apply-öncesi CANLI demo gövdesi (2026-09-25 çekimi; 000012 gövdesiyle
--   birebir — K2 kapısı 0-fark). Tek diff: iki bloğun yer değişimi + bu not.
--   Bayrak kapalı → sessiz NULL; bayrak açık + parametre ihlali → exception;
--   bayrak açık + kısır/Aktif değil/Dişi değil → sessiz NULL (korunur).
-- PROD uygulama notu (davranış farkı): bayrak açık ortamda NULL parametreli
--   doğrudan çağrılar 000012 sonrası sessiz NULL dönerken bu migration'dan
--   sonra yeniden exception üretir (20260924000001 sözleşmesi geri gelir).
-- ACL yeniden beyan edilir (000012 ile birebir; anon/PUBLIC/authenticated
--   kapalı kalır, service_role dokunulmaz).
-- Geri alınabilir: 000012 gövdesi CREATE OR REPLACE ile geri yazılır.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

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
  'R3.2: OVSYNC_BASLAT görevi + ILK_TOHUMLAMA instance çekirdeği. Hedef = GREATEST(kural, bugün). Bayrak kapalı → NULL. Parametre ihlali → OVSYNC_BASLAT_PARAMETRE (F4 sıra düzeltmesi). Kısır/Aktif değil/Dişi değil → NULL (K3).';

REVOKE ALL ON FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000016_baslat_guard_sira (F4/K3)
