-- ════════════════════════════════════════════════════════════════════
-- Ovsync paketi Faz 3 — Görev ↔ protokol uyarısı senkronu (K8)
-- (PLAN.md ### Faz 3; ARASTIRMA-report.md §K8; §16 Geçmiş görünürlüğü)
--
-- Gövde türetme: CANLI pg_get_functiondef (Mgmt API, yalnız SELECT, 2026-10-13 MEASURED):
--   gorev_tamamla(p_gorev_id text, p_padok_hedef text DEFAULT NULL, p_iptal boolean DEFAULT false)
--     — P3b H6 guard + T5 iptal dalı + SUTTEN_KESME/padok dalları aynen korunur;
--     EK: tamamlama dalında uygulama_log köprüsü (iki iptal dönüşünden SONRA).
--   fn_dinle_uygulama() — etken_kod NULL asimetrisi kalkar; simetrik recompute
--     COALESCE(NEW.etken_kod, _etken_kod_bul(NEW.stok_id, NULL)).
--   protokol_eksik_tara() — her tamamlandi eşleşmesine NOT COALESCE(g.iptal, false)
--     (B-bölümü instance sorgusundaki emsal :159 aynen).
--   _etken_kod_bul(p_stok_id text DEFAULT NULL, p_vaccine_id uuid DEFAULT NULL)
--     — DEĞİŞMEZ (salt referans); NULL aşı-argümanı stok yolunu işletir (canlı gövde).
-- Gerekçe (plan Interfaces): (i) gorev_log merkezli — uyarı görev
--   tamamlama/iptalinden türetilir, uygulama_log yalnız dinleyici tetikleyicisi
--   (SEÇİLDİ; §16 ile tutarlı); (ii) çift-yönlü eşit kaynak — ELENDİ
--   (iptal/uygulama çakışmasında çifte doğruluk).
-- İmza değişikliği YOK (yeni parametre yok) → DROP/overload yok; CREATE OR REPLACE
--   mevcut grant'leri korur, aşağıda REVOKE/GRANT ile mühürlenir.
-- Eski migration dosyasına dokunulmadı. `_` yardımcı authenticated'a AÇILMADI;
--   fn_dinle_uygulama grant'lerine dokunulmadı. `GRANT TO anon` YOK.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- squawk hijyeni: yeniden tanım öncesinde timeout'lar (emsal 20261013000001:14-18)
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. gorev_tamamla: tamamlama dalında uygulama_log köprüsü ──────────
-- Köprü, `IF v_gorev.iptal THEN RETURN` satırından SONRA kurulur: p_iptal dalı
-- (yukarıda RETURN) + iptal guardı bu noktaya iptal görev geçirmez; iptal edilen
-- görev köprü kurmaz, iptaller Geçmiş'e girmez (§16). Yalnız gerçek uygulama
-- (stok_id + miktar > 0) köprü kurar — tarihsel köprü kalıbı 20260604000001:156-160
-- (birim/rota görevde tutulmaz; kalıptaki 'ml'/'IM' varsayılanları korunur).
CREATE OR REPLACE FUNCTION public.gorev_tamamla(p_gorev_id text, p_padok_hedef text DEFAULT NULL::text, p_iptal boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev record; v_hayvan record; v_snapshot jsonb;
  v_stok_dusuldu boolean := false; v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb; v_guncellenen jsonb := '[]'::jsonb;
  v_padok_id uuid;
  v_hedef_padok text;
  v_yeni_grup text;
  v_guard_tip text;
  v_uygulama_etken text;
BEGIN
  -- ═══ P3b H6 guard — MUAYENE_SONUC_GEREKLI (plan.md:407 birebir) ═══
  -- Yalnız TAMAMLAMA dalı (p_iptal false/NULL) + yalnız muayene tipleri.
  -- Kilitsiz tek okuma — ilk (kilitli) tablo erişiminden ÖNCE; mevcut kilit
  -- sırası (gorev_log FOR UPDATE → koşullu hayvanlar FOR UPDATE) DEĞİŞMEZ
  -- (§10h H1: gorev_tamamla eski yoldur). Görev yalnız muayene sonuc RPC'si
  -- (tohumlama_bos_ve_devam muayene yolu) üzerinden kapanır (§18.17).
  -- p_iptal=true dalı (T5 offline-replay iptali) ve SUTTEN_KESME/padok
  -- dalları bu guard'a GİRMEZ — davranışları aynen korunur.
  IF p_iptal IS NOT TRUE THEN
    SELECT gorev_tipi INTO v_guard_tip
      FROM public.gorev_log
     WHERE id = p_gorev_id::uuid;
    IF v_guard_tip IN ('GEBELIK_KONTROL', 'TAKIP_MUAYENE') THEN
      RAISE EXCEPTION 'MUAYENE_SONUC_GEREKLI:%', v_guard_tip;
    END IF;
  END IF;

  SELECT * INTO v_gorev
    FROM public.gorev_log
   WHERE id = p_gorev_id::uuid
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id; END IF;

  -- ═══ T5 branşı (cila 20260925000006) — offline kuyruk replay'i iptal-PATCH'i
  --     İPTAL olarak kapatır; mevcut mantık ikame EDİLMEZ. Konum: NOT FOUND
  --     kontrolünün hemen ardından, tamamlandi/iptal erken-dönüşlerinden ÖNCE.
  --     REVIEW DÜŞÜK-1 düzeltmesi (2026-09-25): tamamlandi-guard'ı — zaten
  --     tamamlanmış (gerçek tamamlanma) görev, sonradan replay edilen bayat
  --     iptal-PATCH'le İPTAL'e çevrİLMEZ; erken-dönüşe düşer ('zaten tamamlanmış').
  --     İç IF NOT FOUND ölü koddur (dış FOR UPDATE zaten raise eder) — kaldırıldı.
  IF p_iptal IS TRUE AND v_gorev.tamamlandi IS NOT TRUE THEN
    UPDATE public.gorev_log
       SET tamamlandi = true,
           tamamlanma_tarihi = COALESCE(tamamlanma_tarihi, now()),
           iptal = true
     WHERE id = p_gorev_id::uuid;
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
    VALUES ('GOREV_TAMAMLA', v_gorev.hayvan_id, p_gorev_id, 'gorev_log',
            '{"olusturulan":[],"guncellenen":[],"silinen":[]}'::jsonb,
            'Görev iptal edildi (offline replay)');
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'iptal', true);
  END IF;
  IF v_gorev.tamamlandi THEN RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış'); END IF;
  IF v_gorev.iptal THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz'); END IF;

  -- ═══ K8 köprü (Faz 3): görev tamamlanınca uygulama_log satırı ───────
  -- İki iptal dönüşünden SONRA (yukarıdaki p_iptal dalı + iptal guardı).
  -- Dinleyici (trg_dinle_uygulama) bu satırla uyarıyı düşürür; _gorev_dinle
  -- yalnız açık + iptalsiz görevi kapattığı için tamamlanan görevde idempotent'tir.
  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0
     AND v_gorev.hayvan_id IS NOT NULL THEN
    v_uygulama_etken := COALESCE(v_gorev.etken_kod, public._etken_kod_bul(v_gorev.stok_id, NULL));
    INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
    VALUES (v_gorev.hayvan_id, v_gorev.stok_id, v_uygulama_etken, v_gorev.miktar, 'ml', 'IM',
            'GorevID:' || p_gorev_id);
  END IF;

  IF v_gorev.gorev_tipi = 'SUTTEN_KESME' AND v_gorev.hayvan_id IS NOT NULL THEN
    PERFORM public.buzagi_sutten_kesme_onayla(v_gorev.hayvan_id);
    UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=COALESCE(tamamlanma_tarihi, now())
      WHERE id=p_gorev_id::uuid AND tamamlandi=false;
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'sutten_kesme', true);
  END IF;

  v_hedef_padok := COALESCE(NULLIF(btrim(p_padok_hedef), ''), NULLIF(btrim(v_gorev.padok_hedef), ''));

  IF v_gorev.gorev_tipi = 'PADOK_DEGISIM'
     AND v_gorev.hayvan_id IS NOT NULL
     AND v_hedef_padok IS NULL THEN
    RAISE EXCEPTION 'Padok değişim görevinin hedef padoku boş: %', p_gorev_id
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_hedef_padok IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan
      FROM public.hayvanlar
     WHERE id = v_gorev.hayvan_id
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Görevin hayvanı bulunamadı: %', v_gorev.hayvan_id
        USING ERRCODE = 'foreign_key_violation';
    ELSE
      SELECT id INTO v_padok_id
        FROM public.padoklar
       WHERE ad = v_hedef_padok;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Hedef padok bulunamadı: %', v_hedef_padok
          USING ERRCODE = 'foreign_key_violation';
      END IF;

      v_yeni_grup := v_hayvan.grup;
      IF v_gorev.gorev_tipi = 'PADOK_DEGISIM'
         AND v_gorev.aciklama ILIKE '%Kuru döneme%' THEN
        v_yeni_grup := 'Sağmal (Kuru)';
      END IF;

      IF EXISTS (SELECT 1 FROM public.grup_padok_eslem WHERE grup = v_yeni_grup)
         AND NOT EXISTS (
           SELECT 1
             FROM public.grup_padok_eslem
            WHERE grup = v_yeni_grup
              AND padok_id = v_padok_id
         ) THEN
        RAISE EXCEPTION 'Grup % için hedef padok geçersiz: %', v_yeni_grup, v_hedef_padok
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;

  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo','gorev_log','id',p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi',v_gorev.tamamlandi,'tamamlanma_tarihi',v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi',true,'tamamlanma_tarihi',now())
  );
  UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=now() WHERE id=p_gorev_id::uuid;

  -- ASI_PLANLI muaf: planlı görevin stok düşümü yalnız asi_planli_tamamla üzerinden
  -- olur (plan rezervasyonu + gerçek uygulama); generic 'Görev' satırı çift düşüm olurdu
  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0
     AND v_gorev.gorev_tipi IS DISTINCT FROM 'ASI_PLANLI' THEN
    v_stok_dusuldu := true;
    INSERT INTO public.stok_hareket (id,stok_id,tur,miktar,notlar,iptal)
    VALUES (gen_random_uuid(),v_gorev.stok_id,'Görev',v_gorev.miktar,'GorevID:'||p_gorev_id,false);
  END IF;

  IF v_hedef_padok IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    v_padok_guncellendi := true;
    v_guncellenen := v_guncellenen || jsonb_build_object(
      'tablo','hayvanlar','id',v_gorev.hayvan_id,
      'onceki',jsonb_build_object('grup',v_hayvan.grup,'padok',v_hayvan.padok,'padok_id',v_hayvan.padok_id),
      'sonraki',jsonb_build_object('grup',v_yeni_grup,'padok',v_hedef_padok,'padok_id',v_padok_id)
    );

    UPDATE public.hayvanlar
       SET grup = v_yeni_grup,
           padok = v_hedef_padok,
           padok_id = v_padok_id
     WHERE id = v_gorev.hayvan_id;
  END IF;

  v_snapshot := jsonb_build_object('olusturulan',v_olusturulan,'guncellenen',v_guncellenen,'silinen','[]'::jsonb);
  INSERT INTO public.islem_log (tip,ana_hayvan_id,ref_id,ref_tablo,snapshot,kullanici_notu)
  VALUES ('GOREV_TAMAMLA',v_gorev.hayvan_id,p_gorev_id,'gorev_log',v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object('ok',true,'gorev_id',p_gorev_id,'stok_dusuldu',v_stok_dusuldu,'padok_guncellendi',v_padok_guncellendi);
END;
$function$;

REVOKE ALL ON FUNCTION public.gorev_tamamla(text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text, boolean) TO authenticated, service_role;

-- ── 2. fn_dinle_uygulama: etken_kod NULL'da da recompute ───────────────
-- Canlı asimetri (ARASTIRMA-report §K8): dinleyici yalnız etken_kod doluysa
-- ateşlenir, scanner ise stoktan recompute yapar → sınıflandırılamayan stokla
-- uygulama uyarıyı düşürür, görevi açık bırakır. Simetrik çağrı; _gorev_dinle
-- NULL etkende erken döndüğü için sınıflandırılamayan stokta davranış aynıdır
-- (no-op). Grant'lere dokunulmadı.
CREATE OR REPLACE FUNCTION public.fn_dinle_uygulama()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  PERFORM public._gorev_dinle(NEW.hayvan_id,
    COALESCE(NEW.etken_kod, public._etken_kod_bul(NEW.stok_id, NULL)),
    'uygulama_log:' || NEW.id::text, NEW.tarih);
  RETURN NEW;
END;
$function$;

-- ── 3. protokol_eksik_tara: iptal-kapanış uyarıyı bastırmaz ────────────
-- Canlı gövde + her tamamlandi eşleşmesinde `AND NOT COALESCE(g.iptal, false)`
-- (B-bölümü instance sorgusundaki emsal aynen; uygulanmamış iptal-kapanış
-- uyarıyı bastırmamalı — Review Focus Faz 3 satırı). v_today satırı canlı
-- gövdenin aynısıdır (yeni tarih mantığı yazılmadı).
CREATE OR REPLACE FUNCTION public.protokol_eksik_tara()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb := '[]'::jsonb;
  v_today date := CURRENT_DATE;
  v_rec record;
  v_found boolean;
  v_tamamlanma timestamptz;
  v_kapatan text;
BEGIN

  -- ═══ A. DOĞUM SONRASI PROTOKOL (0-63 gün) ═══
  FOR v_rec IN
    SELECT d.id AS dogum_id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi,
           h.kupe_no, h.grup,
           a.gun, a.ek, a.aciklama
    FROM (
      SELECT DISTINCT ON (anne_id) *
      FROM public.dogum
      ORDER BY anne_id, tarih DESC
    ) d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    CROSS JOIN (VALUES
      (0,  'OKSITOSIN', 'Doğum günü: Oksitosin'),
      (0,  'ADEMIN',    'Doğum günü: Ademin'),
      (0,  'KALSIYUM',  'Doğum günü: Kalsiyum'),
      (2,  'PG',        '2. Gün PG'),
      (39, 'PG',        '39. Gün PG (Presynch-14 senkron)'),
      (25, 'PG',        '25. Gün PG'),
      (53, 'E_VIT',     '53. Gün: E Vitamini')
    ) AS a(gun, ek, aciklama)
    WHERE d.tarih >= v_today - 70
      AND d.tarih <= v_today
  LOOP
    DECLARE
      v_hedef date := v_rec.dogum_tarihi + v_rec.gun;
      v_gecikme int;
      v_durum text;
    BEGIN
      IF v_hedef > v_today + 7 THEN CONTINUE; END IF;

      v_found := false;
      v_tamamlanma := NULL;
      v_kapatan := NULL;

      SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
      INTO v_found, v_tamamlanma, v_kapatan
      FROM gorev_log g
      WHERE g.hayvan_id = v_rec.hayvan_id
        AND g.etken_kod = v_rec.ek
        AND g.tamamlandi = true
        AND NOT COALESCE(g.iptal, false)
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
      LIMIT 1;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM uygulama_log u
        WHERE u.hayvan_id = v_rec.hayvan_id
          AND (u.etken_kod = v_rec.ek
               OR public._etken_kod_bul(u.stok_id, NULL) = v_rec.ek)
          AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM drug_administrations da
        JOIN treatment_days td ON td.id = da.treatment_day_id
        JOIN cases c ON c.id = td.case_id
        WHERE c.animal_id = v_rec.hayvan_id
          AND public._etken_kod_bul(da.stok_id, NULL) = v_rec.ek
          AND da.created_at::date BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM protokol_dismiss pd
        WHERE pd.hayvan_id = v_rec.hayvan_id
          AND pd.etken_kod = v_rec.ek
          AND pd.protokol = 'DOGUM_PROTOKOL'
        LIMIT 1;
      END IF;

      v_gecikme := v_today - v_hedef;

      IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now() - interval '24 hours' THEN
        v_durum := 'tamamlandi';
      ELSIF v_found THEN
        CONTINUE;
      ELSIF v_gecikme >= 0 THEN
        v_durum := 'eksik';
      ELSE
        v_durum := 'yaklasan';
      END IF;

      v_result := v_result || jsonb_build_object(
        'hayvan_id', v_rec.hayvan_id,
        'kupe_no', v_rec.kupe_no,
        'grup', v_rec.grup,
        'protokol', 'DOGUM_PROTOKOL',
        'adim', v_rec.aciklama,
        'etken_kod', v_rec.ek,
        'hedef_tarih', v_hedef,
        'gecikme_gun', v_gecikme,
        'durum', v_durum,
        'tamamlanma_tarihi', v_tamamlanma,
        'kapatan_ref', v_kapatan
      );
    END;
  END LOOP;

  -- ═══ B. İLERI GEBE PROTOKOL (240-265 gün) ═══
  FOR v_rec IN
    SELECT t.id AS toh_id, t.hayvan_id, t.tarih AS toh_tarihi,
           h.kupe_no, h.grup
    FROM public.tohumlama t
    JOIN public.hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
      AND (v_today - t.tarih::date) >= 230
  LOOP
    DECLARE
      v_a record;
    BEGIN
      FOR v_a IN
        SELECT * FROM (VALUES
          (240, 'ROTA',   '💉 Rota-Corona Aşısı'),
          (260, 'ADEMIN', '💊 SC Ademin uygulaması'),
          (265, 'E_VIT',  '💊 IM E Vitamini uygulaması')
        ) AS t(gun, ek, aciklama)
      LOOP
        DECLARE
          v_hedef date := v_rec.toh_tarihi::date + v_a.gun;
          v_gecikme int;
          v_durum text;
          v_task_exists boolean := false;
          v_task_tamamlandi boolean := false;
          v_task_hedef date;
        BEGIN
          IF v_hedef > v_today + 7 THEN CONTINUE; END IF;

          v_found := false;
          v_tamamlanma := NULL;
          v_kapatan := NULL;

          -- Mevcut aktif gebelik instance'ındaki gerçek görev otoritedir.
          -- Tamamlanan kayıt varsa onu; yoksa en yeni açık görevi seç.
          SELECT true, g.hedef_tarih, g.tamamlandi,
                 g.tamamlanma_tarihi, g.kapatan_ref
          INTO v_task_exists, v_task_hedef, v_task_tamamlandi,
               v_tamamlanma, v_kapatan
          FROM gorev_log g
          JOIN protokol_instance pi ON pi.id = g.protokol_instance_id
          WHERE g.hayvan_id = v_rec.hayvan_id
            AND g.etken_kod = v_a.ek
            AND NOT COALESCE(g.iptal, false)
            AND pi.hayvan_id = v_rec.hayvan_id
            AND pi.tip = 'UREME'
            AND pi.alttip = 'GEBELIK'
            AND pi.baslangic = v_rec.toh_tarihi::date
            AND pi.durum = 'aktif'
          ORDER BY g.tamamlandi DESC, g.created_at DESC
          LIMIT 1;

          IF v_task_exists IS TRUE THEN
            v_hedef := v_task_hedef;
            v_found := v_task_tamamlandi;
          ELSE
            -- Instance bağlantısı olmayan legacy görevler için mevcut davranış.
            SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
            INTO v_found, v_tamamlanma, v_kapatan
            FROM gorev_log g
            WHERE g.hayvan_id = v_rec.hayvan_id
              AND g.etken_kod = v_a.ek
              AND g.tamamlandi = true
              AND NOT COALESCE(g.iptal, false)
              AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE AND v_a.ek = 'ROTA' THEN
            SELECT true INTO v_found
            FROM vaccination_log vl
            JOIN vaccines v ON v.id = vl.vaccine_id
            WHERE vl.animal_id = v_rec.hayvan_id
              AND v.name ILIKE '%Rota%'
              AND vl.vaccination_date BETWEEN v_hedef - 7 AND v_hedef + 7
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE THEN
            SELECT true INTO v_found
            FROM uygulama_log u
            WHERE u.hayvan_id = v_rec.hayvan_id
              AND (u.etken_kod = v_a.ek
                   OR public._etken_kod_bul(u.stok_id, NULL) = v_a.ek)
              AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE THEN
            SELECT true INTO v_found
            FROM drug_administrations da
            JOIN treatment_days td ON td.id = da.treatment_day_id
            JOIN cases c ON c.id = td.case_id
            WHERE c.animal_id = v_rec.hayvan_id
              AND public._etken_kod_bul(da.stok_id, NULL) = v_a.ek
              AND da.created_at::date BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE THEN
            SELECT true INTO v_found
            FROM protokol_dismiss pd
            WHERE pd.hayvan_id = v_rec.hayvan_id
              AND pd.etken_kod = v_a.ek
              AND pd.protokol = 'ILERI_GEBE_PROTOKOL'
            LIMIT 1;
          END IF;

          v_gecikme := v_today - v_hedef;

          IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now() - interval '24 hours' THEN
            v_durum := 'tamamlandi';
          ELSIF v_found THEN
            CONTINUE;
          ELSIF v_gecikme >= 0 THEN
            v_durum := 'eksik';
          ELSE
            v_durum := 'yaklasan';
          END IF;

          v_result := v_result || jsonb_build_object(
            'hayvan_id', v_rec.hayvan_id,
            'kupe_no', v_rec.kupe_no,
            'grup', v_rec.grup,
            'protokol', 'ILERI_GEBE_PROTOKOL',
            'adim', v_a.aciklama,
            'etken_kod', v_a.ek,
            'hedef_tarih', v_hedef,
            'gecikme_gun', v_gecikme,
            'durum', v_durum,
            'tamamlanma_tarihi', v_tamamlanma,
            'kapatan_ref', v_kapatan
          );
        END;
      END LOOP;
    END;
  END LOOP;

  -- ═══ C. KIZGINLIK TAKİBİ (55-70 gün) ═══
  FOR v_rec IN
    SELECT d.id AS dogum_id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi,
           h.kupe_no, h.grup
    FROM (
      SELECT DISTINCT ON (anne_id) *
      FROM public.dogum
      ORDER BY anne_id, tarih DESC
    ) d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    WHERE (v_today - d.tarih) BETWEEN 55 AND 75
  LOOP
    DECLARE
      v_hedef date := v_rec.dogum_tarihi + 58;
      v_gecikme int := v_today - v_hedef;
      v_durum text;
    BEGIN
      v_found := false;
      v_tamamlanma := NULL;
      v_kapatan := NULL;

      SELECT true, g.tamamlanma_tarihi
      INTO v_found, v_tamamlanma
      FROM gorev_log g
      WHERE g.hayvan_id = v_rec.hayvan_id
        AND g.aciklama ILIKE '%kızgınlık%'
        AND g.tamamlandi = true
        AND NOT COALESCE(g.iptal, false)
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 7
      LIMIT 1;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM kizginlik_log k
        WHERE k.hayvan_id = v_rec.hayvan_id
          AND k.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM tohumlama t
        WHERE t.hayvan_id = v_rec.hayvan_id
          AND t.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM protokol_dismiss pd
        WHERE pd.hayvan_id = v_rec.hayvan_id
          AND pd.protokol = 'KIZGINLIK_TAKIP'
        LIMIT 1;
      END IF;

      IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now() - interval '24 hours' THEN
        v_durum := 'tamamlandi';
      ELSIF v_found THEN
        CONTINUE;
      ELSIF v_gecikme >= 0 THEN
        v_durum := 'eksik';
      ELSE
        v_durum := 'yaklasan';
      END IF;

      v_result := v_result || jsonb_build_object(
        'hayvan_id', v_rec.hayvan_id,
        'kupe_no', v_rec.kupe_no,
        'grup', v_rec.grup,
        'protokol', 'KIZGINLIK_TAKIP',
        'adim', '⚡ 58-63. gün kızgınlık takibi',
        'etken_kod', NULL,
        'hedef_tarih', v_hedef,
        'gecikme_gun', v_gecikme,
        'durum', v_durum,
        'tamamlanma_tarihi', v_tamamlanma,
        'kapatan_ref', v_kapatan
      );
    END;
  END LOOP;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.protokol_eksik_tara() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.protokol_eksik_tara() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
