-- Medium-severity backend fix'leri (task-047 backlog)
-- M-2(BE): padok_degistir_toplu — p_yeni_grup=NULL iken grup-padok guard atlanıyordu.
-- M-4(BE): tedavi_guncelle — islem_log audit kaydı yoktu (BE-H-1'in kardeşi).
-- M-11: cikis_yap — sadece olum/satis kabul ediyordu, Kesildi/Kayıp 'olum'a sıkıştırılıyordu.
-- M-19: asistan_plan_iptal — yeni RPC, "Vazgeç" sadece DOM'dan siliyordu, DB'de pending kalıyordu.
-- M-20: asistan_tumunu_sil — yeni RPC, client-side 1000-satır limiti + N+1 delete yerine tek DELETE.
-- M-7: cozulmemis_kizginlik_view — 3 günlük pencere, frontend zaten 48s'te kesiyordu (gereksiz fetch).
--
-- M-1(BE) BİLİNÇLİ OLARAK BU MİGRATION'DA YOK: canlı veride doğrulandı (19 çıkışlı hayvan,
-- 0 açık görev) — whitelist eksikliği şu an zarar vermiyor, hayvan çıkışında TÜM görevlerin
-- iptali zaten doğru davranış (BE-H-3 ile aynı aile, backlog'a not düşüldü, kod değişikliği yok).

-- ── M-2(BE): padok_degistir_toplu — per-hayvan grup-padok uyum kontrolü ──
CREATE OR REPLACE FUNCTION public.padok_degistir_toplu(p_hayvan_ids text[], p_yeni_padok_id uuid, p_etiketler text[] DEFAULT NULL::text[], p_yeni_grup text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_yeni_padok   padoklar%ROWTYPE;
  v_aktif_sayisi integer;
  v_hayvan_id    text;
  v_hayvan       hayvanlar%ROWTYPE;
  v_eslem_var    boolean;
  v_hedef_grup   text;
BEGIN
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi + array_length(p_hayvan_ids, 1) > v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   (v_aktif_sayisi + array_length(p_hayvan_ids, 1))::text
                   || '/' || v_yeni_padok.kapasite::text
      );
    END IF;
  END IF;

  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı: ' || v_hayvan_id);
    END IF;
    IF v_hayvan.padok_id = p_yeni_padok_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta: ' || v_hayvan_id);
    END IF;

    -- M-2(BE) FIX: p_yeni_grup NULL ise hayvanın MEVCUT grubu hedef padok ile uyumlu mu kontrol et
    -- (eskiden bu dal hiç çalışmıyordu, guard tamamen atlanıyordu).
    v_hedef_grup := COALESCE(p_yeni_grup, v_hayvan.grup);
    IF v_hedef_grup IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1 FROM grup_padok_eslem
        WHERE grup = v_hedef_grup AND padok_id = p_yeni_padok_id
      ) INTO v_eslem_var;
      IF NOT v_eslem_var THEN
        RETURN jsonb_build_object(
          'success', false, 'error', 'grup_padok_uyumsuz',
          'hayvan_id', v_hayvan_id, 'grup', v_hedef_grup
        );
      END IF;
    END IF;
  END LOOP;

  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;

    UPDATE hayvanlar
       SET padok_id   = p_yeni_padok_id,
           padok      = v_yeni_padok.ad,
           grup       = COALESCE(p_yeni_grup, grup),
           updated_at = now()
     WHERE id = v_hayvan_id;

    INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('padok_degisim', v_hayvan_id, v_hayvan_id, '{}'::jsonb,
            'Toplu padok değişimi → ' || v_yeni_padok.ad
            || COALESCE(' (grup: ' || p_yeni_grup || ')', ''));
  END LOOP;

  IF p_etiketler IS NOT NULL AND array_length(p_etiketler, 1) > 0 THEN
    UPDATE hayvanlar
       SET etiketler = array(
             SELECT DISTINCT unnest(COALESCE(etiketler, '{}') || p_etiketler)
           )
     WHERE id = ANY(p_hayvan_ids);
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'hayvan_sayisi', array_length(p_hayvan_ids, 1),
    'yeni_padok',    v_yeni_padok.ad,
    'yeni_padok_id', p_yeni_padok_id,
    'yeni_grup',     p_yeni_grup
  );
END;
$function$;

-- ── M-4(BE): tedavi_guncelle — islem_log audit kaydı ekle ──
CREATE OR REPLACE FUNCTION public.tedavi_guncelle(p_tedavi_id text, p_miktar numeric DEFAULT NULL::numeric, p_uygulama_yolu text DEFAULT NULL::text, p_bekleme_gun integer DEFAULT NULL::integer, p_hekim_id text DEFAULT NULL::text, p_notlar text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_tedavi  record;
  v_stok    record;
  v_fark    numeric;
  v_yeni_miktar numeric;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  v_yeni_miktar := COALESCE(p_miktar, v_tedavi.miktar);
  v_fark := v_tedavi.miktar - v_yeni_miktar;

  IF v_fark <> 0 THEN
    SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

    IF v_fark < 0 AND v_stok.miktar < ABS(v_fark) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.urun_adi,'?'));
    END IF;

    INSERT INTO public.stok_hareket (
      id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
    ) VALUES (
      gen_random_uuid(),
      v_tedavi.ilac_stok_id,
      'Tedavi Düzeltme',
      v_fark,
      'Tedavi güncellendi — ' || COALESCE(v_tedavi.tani, '?'),
      false,
      'tedavi_duzeltme',
      p_tedavi_id
    );

    UPDATE public.stok SET miktar = miktar + v_fark WHERE id = v_tedavi.ilac_stok_id;
  END IF;

  UPDATE public.tedavi SET
    miktar             = v_yeni_miktar,
    uygulama_yolu      = COALESCE(p_uygulama_yolu,  uygulama_yolu),
    bekleme_suresi_gun = COALESCE(p_bekleme_gun,     bekleme_suresi_gun),
    sut_yasagi_bitis   = CASE
                           WHEN p_bekleme_gun IS NOT NULL AND p_bekleme_gun > 0
                           THEN tarih + p_bekleme_gun
                           ELSE sut_yasagi_bitis
                         END,
    hekim_id           = COALESCE(p_hekim_id,        hekim_id),
    notlar             = COALESCE(p_notlar,           notlar)
  WHERE id::text = p_tedavi_id;

  -- M-4(BE) FIX: audit trail — BE-H-1 (tedavi_sil) ile aynı desen
  INSERT INTO public.islem_log (
    tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu, durum
  ) VALUES (
    'TEDAVI_GUNCELLENDI',
    v_tedavi.hayvan_id,
    p_tedavi_id,
    'tedavi',
    jsonb_build_object('eski_miktar', v_tedavi.miktar, 'yeni_miktar', v_yeni_miktar),
    format('Tedavi güncellendi — %s', COALESCE(v_tedavi.tani, '?')),
    'aktif'
  );

  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- ── M-11: cikis_yap — Kesildi/Kayıp için ayrı tip, bilgi kaybı olmasın ──
CREATE OR REPLACE FUNCTION public.cikis_yap(p_hayvan_id text, p_cikis_tipi text, p_cikis_tarihi date DEFAULT ((now() AT TIME ZONE 'Europe/Istanbul'::text))::date, p_cikis_sebebi text DEFAULT NULL::text, p_satis_fiyati numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_durum_yeni      text;
  v_iptal_gorev_say integer;
  v_iptal_inst_say  integer;
BEGIN
  IF p_cikis_tipi = 'olum' THEN
    v_durum_yeni := 'Ölü';
  ELSIF p_cikis_tipi = 'satis' THEN
    v_durum_yeni := 'Satıldı';
  ELSIF p_cikis_tipi = 'kesim' THEN
    v_durum_yeni := 'Kesildi';
  ELSIF p_cikis_tipi = 'kayip' THEN
    v_durum_yeni := 'Kayıp';
  ELSE
    RAISE EXCEPTION 'Geçersiz çıkış tipi: % (beklenen: olum, satis, kesim veya kayip)', p_cikis_tipi;
  END IF;

  UPDATE public.hayvanlar
  SET durum        = v_durum_yeni,
      cikis_tipi   = p_cikis_tipi,
      cikis_tarihi = p_cikis_tarihi,
      cikis_sebebi = p_cikis_sebebi,
      satis_fiyati = CASE WHEN p_cikis_tipi = 'satis' THEN p_satis_fiyati ELSE satis_fiyati END
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif hayvan bulunamadı: ' || p_hayvan_id);
  END IF;

  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false;

  GET DIAGNOSTICS v_iptal_gorev_say = ROW_COUNT;

  UPDATE public.protokol_instance
  SET durum = 'iptal',
      kapandi_at = now(),
      kapandi_sebep = upper(p_cikis_tipi)
  WHERE hayvan_id = p_hayvan_id
    AND durum = 'aktif';

  GET DIAGNOSTICS v_iptal_inst_say = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok',              true,
    'hayvan_id',       p_hayvan_id,
    'durum',           v_durum_yeni,
    'iptal_gorev',     v_iptal_gorev_say,
    'iptal_protokol',  v_iptal_inst_say
  );
END;
$function$;

-- ── M-19: asistan_plan_iptal — "Vazgeç" artık DB'de de plan'ı kapatıyor ──
CREATE OR REPLACE FUNCTION public.asistan_plan_iptal(p_plan_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_plan record;
BEGIN
  SELECT * INTO v_plan FROM public.agent_plans
  WHERE id = p_plan_id AND kullanici_id = auth.uid();
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Plan bulunamadı');
  END IF;
  IF v_plan.durum <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Plan zaten ' || v_plan.durum);
  END IF;

  UPDATE public.agent_plans
  SET durum = 'iptal'
  WHERE id = p_plan_id;

  RETURN jsonb_build_object('ok', true, 'plan_id', p_plan_id);
END;
$function$;

-- ── M-20: asistan_tumunu_sil — tek DELETE, 1000-satır limiti + N+1 sorunu yok ──
CREATE OR REPLACE FUNCTION public.asistan_tumunu_sil()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_sayi integer;
BEGIN
  DELETE FROM public.agent_threads WHERE kullanici_id = auth.uid();
  GET DIAGNOSTICS v_sayi = ROW_COUNT;
  -- agent_messages, agent_plans → thread_id FK ON DELETE CASCADE (otomatik silinir)
  RETURN jsonb_build_object('ok', true, 'silinen_thread', v_sayi);
END;
$function$;

-- ── M-7: cozulmemis_kizginlik_view — pencereyi frontend'in zaten uyguladığı
-- 48s eşiğine indir (3 gün'lük fazla veri çekilip client-side atılıyordu). ──
CREATE OR REPLACE VIEW public.cozulmemis_kizginlik_view AS
 SELECT DISTINCT ON (kl.hayvan_id) kl.id AS kizginlik_id,
    kl.hayvan_id,
    h.kupe_no,
    h.padok,
    h.grup,
    kl.tarih AS kizginlik_tarihi,
    kl.olusturma AS kizginlik_zamani,
    kl.belirti,
    EXTRACT(epoch FROM now() - kl.olusturma) / 3600::numeric AS gecen_saat,
        CASE
            WHEN kl.cozuldu = true THEN 'cozuldu'::text
            WHEN (EXISTS ( SELECT 1
               FROM tohumlama t
              WHERE t.hayvan_id = kl.hayvan_id AND COALESCE(t.created_at, t.tarih::timestamp with time zone) >= kl.olusturma AND COALESCE(t.created_at, t.tarih::timestamp with time zone) < (kl.olusturma + '12:00:00'::interval))) THEN 'cozuldu'::text
            WHEN (EXTRACT(epoch FROM now() - kl.olusturma) / 3600::numeric) > 24::numeric THEN 'bekleniyor'::text
            WHEN (EXTRACT(epoch FROM now() - kl.olusturma) / 3600::numeric) > 12::numeric THEN 'uyari'::text
            ELSE 'izleniyor'::text
        END AS durum
   FROM kizginlik_log kl
     JOIN hayvanlar h ON h.id = kl.hayvan_id AND h.durum = 'Aktif'::text
  WHERE kl.olusturma >= (now() - '2 days'::interval)
  ORDER BY kl.hayvan_id, kl.olusturma DESC;
