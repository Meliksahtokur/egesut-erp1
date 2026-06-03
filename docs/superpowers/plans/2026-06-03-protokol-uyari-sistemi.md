# Protokol Uyarı Sistemi — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eksik protokol adımlarını tespit eden scanner, global görev dinleme mekanizması, case-free hızlı ilaç uygulama ve bildirim UI oluşturmak.

**Architecture:** 3 katmanlı: (A) `_gorev_dinle` — herhangi bir ilaç/aşı uygulaması gerçekleştiğinde `etken_kod` bazında eşleşen açık görevi otomatik kapatır, (B) `protokol_eksik_tara` — veri durumuna bakarak eksik protokol adımlarını tespit eder, (C) `hizli_uygulama` — case açmadan tek seferlik ilaç/vitamin kaydı. UI: zil ikonu + tam sayfa protokol uyarı ekranı + hayvan kartı hızlı uygulama butonu.

**Tech Stack:** PostgreSQL (plpgsql RPC + trigger), Supabase (migration + RLS), Vanilla JS (ui.js), IndexedDB (offline-first)

**Spec:** `docs/superpowers/specs/2026-06-03-protokol-uyari-sistemi-design.md`

---

## File Structure

| Dosya | Rol |
|-------|-----|
| `supabase/migrations/20260603000001_protokol_etken_kod.sql` | Task 1-5: gorev_log kolonlar + `_etken_kod_bul` + `_gorev_dinle` + backfill + dogum/gebe etken_kod |
| `supabase/migrations/20260603000002_uygulama_log.sql` | Task 6-8: uygulama_log tablo + `hizli_uygulama` + `hizli_uygulama_geri_al` RPC |
| `supabase/migrations/20260603000003_dinleme_trigger.sql` | Task 9: 3 AFTER INSERT trigger (vaccination_log, uygulama_log, drug_administrations) |
| `supabase/migrations/20260603000004_protokol_scanner.sql` | Task 10-11: protokol_dismiss tablo + `protokol_eksik_tara` RPC |
| `js/ui.js` | Task 12-16: Zil ikonu, protokol ekranı, uygula formu, hayvan kartı hızlı uygulama |
| `index.html` | Task 12: Zil ikonu butonu topbar'a ekleme |
| `supabase/migrations/99999999999999_ground_truth.sql` | Task 17: Tüm yeni tablo/fonksiyon/trigger tanımlarını sync |

---

## Task 1: `gorev_log` Kolon Ekleme

**Files:**
- Modify: `supabase/migrations/20260603000001_protokol_etken_kod.sql` (create)

- [ ] **Step 1: Migration dosyası oluştur — kolon ekleme**

```sql
-- Migration: gorev_log'a etken_kod + kapatan_ref kolonları
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS etken_kod text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS kapatan_ref text;

CREATE INDEX IF NOT EXISTS idx_gorev_log_etken ON public.gorev_log(hayvan_id, etken_kod)
  WHERE tamamlandi = false AND iptal = false AND etken_kod IS NOT NULL;

COMMENT ON COLUMN public.gorev_log.etken_kod IS 'Görevin beklediği etken madde kodu (OKSITOSIN, PG, E_VIT, ADEMIN, KALSIYUM, ROTA)';
COMMENT ON COLUMN public.gorev_log.kapatan_ref IS 'Görevi kapatan kaydın referansı (ör: uygulama_log:uuid, vaccination_log:uuid)';
```

- [ ] **Step 2: Migration'ı Supabase'e uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

Expected: Migration applied successfully, no errors.

- [ ] **Step 3: Doğrula — kolonlar eklendi**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT column_name, data_type FROM information_schema.columns
  WHERE table_name = 'gorev_log' AND column_name IN ('etken_kod','kapatan_ref');
"
```

Expected: 2 rows: `etken_kod | text` and `kapatan_ref | text`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000001_protokol_etken_kod.sql
git commit -m "$(cat <<'EOF'
feat(db): gorev_log'a etken_kod + kapatan_ref kolonları ekle

Protokol uyarı sistemi altyapısı — görev-uygulama eşleştirmesi için.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `_etken_kod_bul` Helper Fonksiyonu

**Files:**
- Modify: `supabase/migrations/20260603000001_protokol_etken_kod.sql`

- [ ] **Step 1: Fonksiyonu migration'a ekle**

```sql
CREATE OR REPLACE FUNCTION public._etken_kod_bul(
  p_stok_id text DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_name text;
  v_group_name text;
  v_active_ing text;
  v_stok_ad text;
  v_vaccine_name text;
BEGIN
  -- Aşı yolu
  IF p_vaccine_id IS NOT NULL THEN
    SELECT name INTO v_vaccine_name FROM public.vaccines WHERE id = p_vaccine_id;
    IF v_vaccine_name ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;
    RETURN NULL;
  END IF;

  -- İlaç yolu: stok → drug_products → drug_classes
  IF p_stok_id IS NOT NULL THEN
    SELECT s.urun_adi INTO v_stok_ad FROM public.stok s WHERE s.id = p_stok_id;

    SELECT dc.group_name, dc.class_name, dc.active_ingredient
    INTO v_group_name, v_class_name, v_active_ing
    FROM public.drug_products dp
    JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE dp.id = (
      SELECT drug_product_id FROM public.drug_administrations
      WHERE stok_id = p_stok_id LIMIT 1
    )
    OR dp.brand_name ILIKE '%' || COALESCE(v_stok_ad,'') || '%'
    LIMIT 1;

    -- Sınıf bazlı eşleşme
    IF v_class_name ILIKE '%oksitosin%' OR v_active_ing ILIKE '%oxytocin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%' OR v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%' THEN RETURN 'PG'; END IF;
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;
```

- [ ] **Step 2: Migration'ı Supabase'e uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula — fonksiyon çalışıyor**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT public._etken_kod_bul(NULL, (SELECT id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1));
"
```

Expected: `ROTA`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000001_protokol_etken_kod.sql
git commit -m "$(cat <<'EOF'
feat(db): _etken_kod_bul helper — stok/aşı → etken_kod eşleştirme

drug_classes + vaccines üzerinden içerik bazlı eşleşme yapar.
Marka bağımsız: herhangi bir PG ürünü → 'PG', Yeldif dahil E vitamini → 'E_VIT'.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `_gorev_dinle` Fonksiyonu

**Files:**
- Modify: `supabase/migrations/20260603000001_protokol_etken_kod.sql`

- [ ] **Step 1: Fonksiyonu migration'a ekle**

```sql
CREATE OR REPLACE FUNCTION public._gorev_dinle(
  p_hayvan_id text,
  p_etken_kod text,
  p_ref text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev_id text;
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
  ORDER BY hedef_tarih ASC
  LIMIT 1;

  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true,
        tamamlanma_tarihi = now(),
        kapatan_ref = p_ref
    WHERE id = v_gorev_id;
  END IF;
END;
$$;
```

- [ ] **Step 2: Migration'ı Supabase'e uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula — fonksiyon mevcut**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT routine_name FROM information_schema.routines
  WHERE routine_name = '_gorev_dinle' AND routine_schema = 'public';
"
```

Expected: 1 row: `_gorev_dinle`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000001_protokol_etken_kod.sql
git commit -m "$(cat <<'EOF'
feat(db): _gorev_dinle — global görev kapatma mekanizması

etken_kod bazında eşleşen en yakın tarihli açık görevi kapatır.
Kaynak bağımsız: aşı, ilaç, hızlı uygulama — hepsi tetikler.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Mevcut Görevlere `etken_kod` Backfill

**Files:**
- Modify: `supabase/migrations/20260603000001_protokol_etken_kod.sql`

- [ ] **Step 1: Backfill UPDATE'leri migration'a ekle**

```sql
-- Backfill: mevcut açık görevlere etken_kod ata
UPDATE public.gorev_log SET etken_kod = 'OKSITOSIN'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%Oksitosin%';

UPDATE public.gorev_log SET etken_kod = 'PG'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%PG%'
  AND aciklama NOT ILIKE '%Ademin%';

UPDATE public.gorev_log SET etken_kod = 'ADEMIN'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND (aciklama ILIKE '%Ademin%' AND aciklama NOT ILIKE '%Yeldif%' AND aciklama NOT ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'E_VIT'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND (aciklama ILIKE '%Yeldif%' OR aciklama ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'KALSIYUM'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%Kalsiyum%';

UPDATE public.gorev_log SET etken_kod = 'ROTA'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%Rota%';
```

**Dikkat:** "Doğum günü: Oksitosin + Ademin + Kalsiyum" → bu görev birden fazla etken madde içeriyor. Bu görev zaten tek bir görev olarak kaydediliyor — backfill'de `OKSITOSIN` olarak atanır çünkü ilk eşleşen o. Bu görev Task 5'te multi-etken olarak ayrılacak.

- [ ] **Step 2: Migration'ı Supabase'e uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula — backfill sayısı**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT etken_kod, COUNT(*) FROM gorev_log
  WHERE etken_kod IS NOT NULL AND tamamlandi = false
  GROUP BY etken_kod ORDER BY etken_kod;
"
```

Expected: Her etken_kod için sayı (sıfır olmayan en az birkaç satır)

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000001_protokol_etken_kod.sql
git commit -m "$(cat <<'EOF'
feat(db): mevcut açık görevlere etken_kod backfill

Görev açıklamasından pattern matching ile etken_kod atanır.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `dogum_kaydet` ve `fn_gebe_gorev_yarat` Güncelleme

**Files:**
- Modify: `supabase/migrations/20260603000001_protokol_etken_kod.sql`

Bu adımda `dogum_kaydet` RPC'sinin görev INSERT satırlarına `etken_kod` eklenir. Mevcut "Doğum günü: Oksitosin + Ademin + Kalsiyum" tek görevi 3 ayrı göreve bölünür. `fn_gebe_gorev_yarat` trigger fonksiyonuna da `etken_kod` eklenir.

- [ ] **Step 1: dogum_kaydet CREATE OR REPLACE — etken_kod eklenmiş**

`dogum_kaydet` fonksiyonunun tamamını yeniden yaz. Değişen kısımlar:
1. `gorev_log` INSERT'lerine `etken_kod` kolonu eklenir
2. "Doğum günü: Oksitosin + Ademin + Kalsiyum" → 3 ayrı satıra bölünür
3. Toplam anne görev sayısı 7→9 olur (3 ayrı + 3 PG + 2 vitamin + 1 kızgınlık)
4. `gorev_sayisi` return değeri 14→16 olur

```sql
CREATE OR REPLACE FUNCTION public.dogum_kaydet(
  p_anne_id    text,
  p_tarih      date,
  p_kupe       text,
  p_cins       text    DEFAULT 'Dişi',
  p_tip        text    DEFAULT 'Normal',
  p_kg         numeric DEFAULT NULL,
  p_baba       text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_anne        record;
  v_dogum_id    uuid := gen_random_uuid();
  v_buzagi_id   text;
  v_ana_gorev   uuid := gen_random_uuid();
  v_sayac       integer;
  v_dup         text;
  v_baba_bilgi  text;
BEGIN
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı');
  END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE kupe_no = p_kupe OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe);
  END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi
    FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe'
    ORDER BY tarih DESC LIMIT 1;
  ELSE
    v_baba_bilgi := p_baba;
  END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi);

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  UPDATE public.hayvanlar
  SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok'
  WHERE id = p_anne_id;

  -- Anne protokol görevleri (9 görev — etken_kod ile)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih, false, 'DOGUM-' || p_anne_id, 'OKSITOSIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih, false, 'DOGUM-' || p_anne_id, 'KALSIYUM'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '11. Gün PG',            p_tarih + 11, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Ademin',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '54. Gün: Yeldif',       p_tarih + 54, false, 'DOGUM-' || p_anne_id, 'E_VIT'),
    (gen_random_uuid(), p_anne_id, 'DIGER', '⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL);

  -- Buzağı ana görev
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'DOGUM-' || p_anne_id);

  -- Buzağı alt görevler (6 görev)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id);

  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 16,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: fn_gebe_gorev_yarat — etken_kod eklenmiş**

```sql
CREATE OR REPLACE FUNCTION public.fn_gebe_gorev_yarat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
BEGIN
  IF NEW.sonuc != 'Gebe' OR OLD.sonuc = 'Gebe' THEN
    RETURN NEW;
  END IF;

  SELECT stock_item_id INTO v_stok_id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1;

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
         '💉 Rota-Corona Aşısı (1. doz)', NEW.tarih::date + 240, false, v_stok_id, 1, 'ILERI_GEBE', 'ROTA'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND tamamlandi = false
  );

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 SC Ademin uygulaması', NEW.tarih::date + 260, false, 'ILERI_GEBE', 'ADEMIN'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND tamamlandi = false
  );

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 IM E Vitamini uygulaması', NEW.tarih::date + 265, false, 'ILERI_GEBE', 'E_VIT'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND tamamlandi = false
  );

  RETURN NEW;
END;
$$;
```

- [ ] **Step 3: Migration'ı Supabase'e uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 4: Doğrula — dogum_kaydet yeni görev sayısı**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT prosrc FROM pg_proc WHERE proname = 'dogum_kaydet' ORDER BY oid DESC LIMIT 1;
" | grep -c 'etken_kod'
```

Expected: Multiple matches (etken_kod appears in each INSERT row)

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260603000001_protokol_etken_kod.sql
git commit -m "$(cat <<'EOF'
feat(db): dogum_kaydet + fn_gebe_gorev_yarat etken_kod desteği

Doğum günü görev 3'e bölündü (Oksitosin/Ademin/Kalsiyum ayrı).
İleri gebe görevlerine ROTA/ADEMIN/E_VIT atandı.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `uygulama_log` Tablosu

**Files:**
- Create: `supabase/migrations/20260603000002_uygulama_log.sql`

- [ ] **Step 1: Migration dosyası oluştur**

```sql
-- uygulama_log: case-free ilaç/vitamin uygulama kaydı
CREATE TABLE IF NOT EXISTS public.uygulama_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  stok_id text REFERENCES public.stok(id),
  etken_kod text,
  doz numeric NOT NULL,
  birim text NOT NULL,
  rota text NOT NULL CHECK (rota IN ('IM','IV','SC','PO','Topikal','Intrauterin')),
  tarih date NOT NULL DEFAULT CURRENT_DATE,
  notlar text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_uygulama_log_hayvan ON public.uygulama_log(hayvan_id);
CREATE INDEX IF NOT EXISTS idx_uygulama_log_tarih ON public.uygulama_log(tarih);

COMMENT ON TABLE public.uygulama_log IS 'Case-free hızlı ilaç/vitamin uygulama kaydı — görev dinleme trigger tetikler';

ALTER TABLE public.uygulama_log ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='uygulama_log' AND policyname='anon_all_uygulama_log') THEN
    CREATE POLICY anon_all_uygulama_log ON public.uygulama_log FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.uygulama_log TO anon, authenticated;
```

- [ ] **Step 2: Migration'ı uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT table_name FROM information_schema.tables WHERE table_name = 'uygulama_log';
"
```

Expected: 1 row: `uygulama_log`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000002_uygulama_log.sql
git commit -m "$(cat <<'EOF'
feat(db): uygulama_log tablosu — case-free ilaç/vitamin kaydı

Hızlı uygulama için yeni tablo. Case sistemi dışında tek seferlik kayıt.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `hizli_uygulama` RPC

**Files:**
- Modify: `supabase/migrations/20260603000002_uygulama_log.sql`

- [ ] **Step 1: RPC fonksiyonunu migration'a ekle**

```sql
CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_rota text,
  p_notlar text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_stok record;
  v_etken text;
  v_id uuid;
  v_kalan numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  IF p_notlar IS NULL OR TRIM(p_notlar) = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Not alanı zorunludur');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- Stok düşüm
  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid()::text, p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0)
  );
END;
$$;
```

- [ ] **Step 2: Migration'ı uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula — fonksiyon mevcut**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT routine_name FROM information_schema.routines WHERE routine_name = 'hizli_uygulama';
"
```

Expected: 1 row

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000002_uygulama_log.sql
git commit -m "$(cat <<'EOF'
feat(db): hizli_uygulama RPC — case-free ilaç/vitamin kaydı + stok düşüm

Otomatik etken_kod türetir, stok düşer, trigger üzerinden _gorev_dinle tetiklenir.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `hizli_uygulama_geri_al` RPC

**Files:**
- Modify: `supabase/migrations/20260603000002_uygulama_log.sql`

- [ ] **Step 1: RPC fonksiyonunu migration'a ekle**

```sql
CREATE OR REPLACE FUNCTION public.hizli_uygulama_geri_al(
  p_uygulama_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uyg record;
  v_hayvan record;
BEGIN
  SELECT * INTO v_uyg FROM public.uygulama_log WHERE id = p_uygulama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Uygulama kaydı bulunamadı');
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_uyg.hayvan_id;

  -- Stok iade (ters hareket)
  IF v_uyg.stok_id IS NOT NULL THEN
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid()::text, v_uyg.stok_id, 'İade (Hızlı Uyg.)', -v_uyg.doz,
            'Geri Al — ' || COALESCE(v_hayvan.kupe_no, v_uyg.hayvan_id), false);
  END IF;

  -- Bu uygulama ile kapanan görevi tekrar aç
  UPDATE public.gorev_log
  SET tamamlandi = false,
      tamamlanma_tarihi = NULL,
      kapatan_ref = NULL
  WHERE kapatan_ref = 'uygulama_log:' || p_uygulama_id::text;

  DELETE FROM public.uygulama_log WHERE id = p_uygulama_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;
```

- [ ] **Step 2: Migration'ı uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT routine_name FROM information_schema.routines WHERE routine_name = 'hizli_uygulama_geri_al';
"
```

Expected: 1 row

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000002_uygulama_log.sql
git commit -m "$(cat <<'EOF'
feat(db): hizli_uygulama_geri_al — uygulama geri alma + stok iade + görev restore

Uygulama silindi → stok iade → kapatan_ref ile eşleşen görev tekrar açılır.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Dinleme Trigger'ları

**Files:**
- Create: `supabase/migrations/20260603000003_dinleme_trigger.sql`

3 AFTER INSERT trigger: `vaccination_log`, `uygulama_log`, `drug_administrations` tablolarına.

- [ ] **Step 1: Migration dosyası oluştur**

```sql
-- Trigger: vaccination_log INSERT → _gorev_dinle
CREATE OR REPLACE FUNCTION public.fn_dinle_vaccination()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
BEGIN
  v_etken := public._etken_kod_bul(NULL, NEW.vaccine_id);
  IF v_etken IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.animal_id, v_etken, 'vaccination_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dinle_vaccination ON public.vaccination_log;
CREATE TRIGGER trg_dinle_vaccination
  AFTER INSERT ON public.vaccination_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_vaccination();


-- Trigger: uygulama_log INSERT → _gorev_dinle
CREATE OR REPLACE FUNCTION public.fn_dinle_uygulama()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.etken_kod IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.hayvan_id, NEW.etken_kod, 'uygulama_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dinle_uygulama ON public.uygulama_log;
CREATE TRIGGER trg_dinle_uygulama
  AFTER INSERT ON public.uygulama_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_uygulama();


-- Trigger: drug_administrations INSERT → _gorev_dinle
CREATE OR REPLACE FUNCTION public.fn_dinle_drug_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
  v_animal_id text;
BEGIN
  v_etken := public._etken_kod_bul(NEW.stok_id, NULL);
  IF v_etken IS NULL THEN
    RETURN NEW;
  END IF;

  -- hayvan_id: drug_administrations → treatment_days → cases → animal_id
  SELECT c.animal_id INTO v_animal_id
  FROM public.treatment_days td
  JOIN public.cases c ON c.id = td.case_id
  WHERE td.id = NEW.treatment_day_id;

  IF v_animal_id IS NOT NULL THEN
    PERFORM public._gorev_dinle(v_animal_id, v_etken, 'drug_admin:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dinle_drug_admin ON public.drug_administrations;
CREATE TRIGGER trg_dinle_drug_admin
  AFTER INSERT ON public.drug_administrations
  FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_drug_admin();
```

- [ ] **Step 2: Migration'ı uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula — trigger'lar mevcut**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT trigger_name, event_object_table FROM information_schema.triggers
  WHERE trigger_name LIKE 'trg_dinle_%' ORDER BY trigger_name;
"
```

Expected: 3 rows: `trg_dinle_drug_admin`, `trg_dinle_uygulama`, `trg_dinle_vaccination`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000003_dinleme_trigger.sql
git commit -m "$(cat <<'EOF'
feat(db): 3 dinleme trigger — vaccination_log, uygulama_log, drug_administrations

Her INSERT'te _gorev_dinle çağırır → eşleşen açık görev otomatik kapanır.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: `protokol_dismiss` Tablosu

**Files:**
- Create: `supabase/migrations/20260603000004_protokol_scanner.sql`

- [ ] **Step 1: Migration dosyası oluştur**

```sql
CREATE TABLE IF NOT EXISTS public.protokol_dismiss (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  etken_kod text NOT NULL,
  protokol text NOT NULL,
  tarih timestamptz DEFAULT now(),
  neden text,
  UNIQUE(hayvan_id, etken_kod, protokol)
);

COMMENT ON TABLE public.protokol_dismiss IS 'Kullanıcı tarafından geçersiz kılınan protokol uyarıları';

ALTER TABLE public.protokol_dismiss ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='protokol_dismiss' AND policyname='anon_all_protokol_dismiss') THEN
    CREATE POLICY anon_all_protokol_dismiss ON public.protokol_dismiss FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.protokol_dismiss TO anon, authenticated;
```

- [ ] **Step 2: Migration'ı uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "
  SELECT table_name FROM information_schema.tables WHERE table_name = 'protokol_dismiss';
"
```

Expected: 1 row

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000004_protokol_scanner.sql
git commit -m "$(cat <<'EOF'
feat(db): protokol_dismiss tablosu — geçersiz kılma kaydı

Kullanıcı uyarıyı geçersiz kılarsa neden ile birlikte saklanır.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: `protokol_eksik_tara` Scanner RPC

**Files:**
- Modify: `supabase/migrations/20260603000004_protokol_scanner.sql`

Bu en büyük ve en kritik RPC. 3 protokolü tarar: doğum sonrası (A), ileri gebe (B), kızgınlık takibi (C).

- [ ] **Step 1: Scanner RPC'yi migration'a ekle**

```sql
CREATE OR REPLACE FUNCTION public.protokol_eksik_tara()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
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
           unnest(ARRAY[
             ROW(0,  'OKSITOSIN', 'Doğum günü: Oksitosin')::record,
             ROW(0,  'ADEMIN',    'Doğum günü: Ademin')::record,
             ROW(0,  'KALSIYUM',  'Doğum günü: Kalsiyum')::record,
             ROW(2,  'PG',        '2. Gün PG')::record,
             ROW(11, 'PG',        '11. Gün PG')::record,
             ROW(25, 'PG',        '25. Gün PG')::record,
             ROW(53, 'ADEMIN',    '53. Gün: Ademin')::record,
             ROW(53, 'E_VIT',     '53. Gün: Yeldif')::record,
             ROW(54, 'E_VIT',     '54. Gün: Yeldif')::record
           ]) AS adim
    FROM public.dogum d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    WHERE d.tarih >= v_today - 70
      AND d.tarih <= v_today
  LOOP
    DECLARE
      v_gun int := (v_rec.adim).f1;
      v_ek text := (v_rec.adim).f2;
      v_aciklama text := (v_rec.adim).f3;
      v_hedef date := v_rec.dogum_tarihi + v_gun;
      v_gecikme int;
      v_durum text;
    BEGIN
      IF v_hedef > v_today + 7 THEN CONTINUE; END IF;

      v_found := false;
      v_tamamlanma := NULL;
      v_kapatan := NULL;

      -- 1. gorev_log tamamlanmış mı?
      SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
      INTO v_found, v_tamamlanma, v_kapatan
      FROM gorev_log g
      WHERE g.hayvan_id = v_rec.hayvan_id
        AND g.etken_kod = v_ek
        AND g.tamamlandi = true
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
      LIMIT 1;

      -- 2. uygulama_log
      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM uygulama_log u
        WHERE u.hayvan_id = v_rec.hayvan_id
          AND u.etken_kod = v_ek
          AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      -- 3. drug_administrations (case üzerinden)
      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM drug_administrations da
        JOIN treatment_days td ON td.id = da.treatment_day_id
        JOIN cases c ON c.id = td.case_id
        WHERE c.animal_id = v_rec.hayvan_id
          AND public._etken_kod_bul(da.stok_id, NULL) = v_ek
          AND da.created_at::date BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      -- 4. protokol_dismiss
      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM protokol_dismiss pd
        WHERE pd.hayvan_id = v_rec.hayvan_id
          AND pd.etken_kod = v_ek
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
        'adim', v_aciklama,
        'etken_kod', v_ek,
        'hedef_tarih', v_hedef,
        'gecikme_gun', GREATEST(v_gecikme, 0),
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
      v_adimlar record[];
      v_a record;
    BEGIN
      -- 240: ROTA, 260: ADEMIN, 265: E_VIT
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
        BEGIN
          IF v_hedef > v_today + 7 THEN CONTINUE; END IF;

          v_found := false;
          v_tamamlanma := NULL;
          v_kapatan := NULL;

          SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
          INTO v_found, v_tamamlanma, v_kapatan
          FROM gorev_log g
          WHERE g.hayvan_id = v_rec.hayvan_id
            AND g.etken_kod = v_a.ek
            AND g.tamamlandi = true
            AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
          LIMIT 1;

          IF NOT v_found AND v_a.ek = 'ROTA' THEN
            SELECT true INTO v_found
            FROM vaccination_log vl
            JOIN vaccines v ON v.id = vl.vaccine_id
            WHERE vl.animal_id = v_rec.hayvan_id
              AND v.name ILIKE '%Rota%'
              AND vl.vaccination_date BETWEEN v_hedef - 7 AND v_hedef + 7
            LIMIT 1;
          END IF;

          IF NOT v_found THEN
            SELECT true INTO v_found
            FROM uygulama_log u
            WHERE u.hayvan_id = v_rec.hayvan_id
              AND u.etken_kod = v_a.ek
              AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF NOT v_found THEN
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
            'gecikme_gun', GREATEST(v_gecikme, 0),
            'durum', v_durum,
            'tamamlanma_tarihi', v_tamamlanma,
            'kapatan_ref', v_kapatan
          );
        END;
      END LOOP;
    END;
  END LOOP;

  -- ═══ C. KIZGINLIK TAKİBİ (58-70 gün) ═══
  FOR v_rec IN
    SELECT d.id AS dogum_id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi,
           h.kupe_no, h.grup
    FROM public.dogum d
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
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 7
      LIMIT 1;

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM kizginlik_log k
        WHERE k.hayvan_id = v_rec.hayvan_id
          AND k.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM tohumlama t
        WHERE t.hayvan_id = v_rec.hayvan_id
          AND t.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
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
        'gecikme_gun', GREATEST(v_gecikme, 0),
        'durum', v_durum,
        'tamamlanma_tarihi', v_tamamlanma,
        'kapatan_ref', v_kapatan
      );
    END;
  END LOOP;

  RETURN v_result;
END;
$$;
```

**Not:** Bu fonksiyon `unnest(ARRAY[ROW(...)::record])` kullanıyor. PostgreSQL 14+'ta çalışır. Eğer uyumluluk sorunu çıkarsa, `VALUES` + `LATERAL` yapısına çevrilebilir. İlk deploy'da hata olursa alternatif yapıyı kullanın (doğum sonrası protokol adımlarını ayrı ayrı döngüyle tara).

- [ ] **Step 2: Migration'ı uygula**

Run: `cd /root/egesut-erp1 && npx supabase db push --linked`

- [ ] **Step 3: Doğrula — scanner çağrılabilir**

Run:
```bash
cd /root/egesut-erp1 && npx supabase db execute --linked -c "SELECT public.protokol_eksik_tara();"
```

Expected: JSON array (boş `[]` veya uyarı listesi)

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000004_protokol_scanner.sql
git commit -m "$(cat <<'EOF'
feat(db): protokol_eksik_tara scanner — doğum/ileri gebe/kızgınlık gap detection

3 protokol tarar, 6 kaynağı kontrol eder (gorev_log, vaccination_log, uygulama_log,
drug_administrations, kizginlik_log, protokol_dismiss). Fallback mekanizması.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Zil İkonu + Badge (Dashboard Header)

**Files:**
- Modify: `index.html:365-369` — topbar'a zil butonu ekle
- Modify: `js/ui.js:231-293` — loadDash'e scanner çağrısı ekle

- [ ] **Step 1: index.html — topbar'a zil butonu ekle**

`index.html:368` satırında `ayarlarbtn` butonundan ÖNCE zil butonunu ekle:

```html
<button id="bellbtn" onclick="_showProtokolEkran()" style="position:relative;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.12);color:var(--ink3);padding:5px 10px;border-radius:20px;font-size:.85rem;cursor:pointer">🔔<span id="bellbadge" style="display:none;position:absolute;top:-4px;right:-4px;background:var(--red2);color:#fff;font-size:.55rem;font-weight:800;min-width:16px;height:16px;border-radius:8px;display:flex;align-items:center;justify-content:center;padding:0 4px">0</span></button>
```

- [ ] **Step 2: ui.js — loadDash'e protokol scanner çağrısı ekle**

`loadDash()` fonksiyonunun sonunda, `el.innerHTML=h||...` satırından SONRA, `} catch(e){` ÖNCE:

```javascript
    // Protokol uyarı scanner
    try {
      const proto = await rpc('protokol_eksik_tara', {});
      window.__protokolUyarilar = Array.isArray(proto) ? proto : [];
      const aktif = window.__protokolUyarilar.filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
      const bb = document.getElementById('bellbadge');
      if (bb) {
        bb.textContent = aktif.length > 99 ? '99+' : aktif.length;
        bb.style.display = aktif.length > 0 ? 'flex' : 'none';
      }
    } catch(e) { console.warn('protokol_eksik_tara:', e.message); }
```

- [ ] **Step 3: Test — dashboard'u yükle, zil ikonunu gör**

Tarayıcıda dashboard'u yenile. Zil ikonu topbar'da görünmeli. Scanner sonucuna göre badge sayısı gösterilmeli veya gizlenmeli.

- [ ] **Step 4: Commit**

```bash
git add index.html js/ui.js
git commit -m "$(cat <<'EOF'
feat(ui): zil ikonu + protokol uyarı badge

Dashboard yüklendiğinde protokol_eksik_tara çağrılır, badge güncellenir.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Protokol Uyarı Ekranı (Tam Sayfa)

**Files:**
- Modify: `js/ui.js` — `_showProtokolEkran()` fonksiyonu ekle

- [ ] **Step 1: _showProtokolEkran fonksiyonunu ui.js'e ekle**

`_showSessizList` fonksiyonundan sonra (satır ~693), yeni fonksiyonu ekle:

```javascript
async function _showProtokolEkran(){
  let data = window.__protokolUyarilar;
  if (!data || !data.length) {
    try { data = await rpc('protokol_eksik_tara', {}); } catch(e) { toast('Hata: '+e.message, true); return; }
  }
  if (!data || !data.length) { toast('Protokol uyarısı yok'); return; }

  let box = document.getElementById('protokol-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'protokol-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) box.remove(); };

  const eksik = data.filter(u => u.durum === 'eksik');
  const yaklasan = data.filter(u => u.durum === 'yaklasan');
  const tamamlandi = data.filter(u => u.durum === 'tamamlandi');

  const _renk = d => d.durum === 'eksik' ? 'var(--red2)' : d.durum === 'yaklasan' ? '#b8860b' : '#2e7d32';
  const _ikon = d => d.durum === 'eksik' ? '🔴' : d.durum === 'yaklasan' ? '🟡' : '✅';
  const _gun = d => d.durum === 'eksik' ? d.gecikme_gun + ' gün gecikmiş' : d.durum === 'yaklasan' ? Math.abs(d.gecikme_gun || 0) + ' gün kaldı' : '';

  const _satirHtml = (d, i) => `<div class="arow" style="border-left:3px solid ${_renk(d)};margin-bottom:6px;padding:8px 10px">
    <div style="flex:1">
      <div style="font-weight:700;font-size:.8rem">${_ikon(d)} ${esc(d.kupe_no||'?')} <span style="font-size:.6rem;opacity:.6">${esc(d.grup||'')}</span></div>
      <div style="font-size:.7rem;color:var(--ink3)">${esc(d.adim)} · ${_gun(d)}</div>
      <div style="font-size:.6rem;opacity:.5">${esc(d.protokol)}</div>
    </div>
    <div style="display:flex;gap:6px;align-items:center">
      ${d.durum !== 'tamamlandi' && d.etken_kod ? `<button onclick="_protokolUygula(${i})" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--blue);background:rgba(30,100,200,.1);color:var(--blue);cursor:pointer">💉 Uygula</button>` : ''}
      ${d.durum !== 'tamamlandi' ? `<button onclick="_protokolDismiss(${i})" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>` : ''}
      ${d.durum === 'tamamlandi' && d.kapatan_ref ? `<button onclick="_protokolGeriAl('${esc(d.kapatan_ref)}')" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer">↩ Geri Al</button>` : ''}
    </div>
  </div>`;

  const eksikHtml = eksik.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:var(--red2)">🔴 Gecikmiş (${eksik.length})</div>${eksik.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';
  const yakHtml = yaklasan.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:#b8860b">🟡 Yaklaşan (${yaklasan.length})</div>${yaklasan.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';
  const tamHtml = tamamlandi.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:#2e7d32">✅ Son 24 Saat (${tamamlandi.length})</div>${tamamlandi.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';

  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:85vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
      <div style="font-weight:800;font-size:1rem">🔔 Protokol Uyarıları</div>
      <button onclick="document.getElementById('protokol-bs').remove()" style="background:none;border:none;font-size:1.2rem;cursor:pointer;color:var(--ink3)">✕</button>
    </div>
    ${eksikHtml}${yakHtml}${tamHtml}
    ${!eksik.length && !yaklasan.length && !tamamlandi.length ? '<div style="text-align:center;padding:40px;color:var(--ink3)">Protokol uyarısı yok</div>' : ''}
  </div>`;
  document.body.appendChild(box);
}
```

- [ ] **Step 2: Test — zil ikonuna tıkla, ekranı gör**

Dashboard'da zil ikonuna tıkla. Tam sayfa bottom-sheet açılmalı: gecikmiş (kırmızı), yaklaşan (sarı), tamamlanan (yeşil) bölümleriyle.

- [ ] **Step 3: Commit**

```bash
git add js/ui.js
git commit -m "$(cat <<'EOF'
feat(ui): protokol uyarı ekranı — tam sayfa bottom-sheet

Gecikmiş/yaklaşan/tamamlanan bölümleri, Uygula/Geçersiz/Geri Al butonları.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: "Uygula" Mini Form + "Geçersiz" + "Geri Al" Akışları

**Files:**
- Modify: `js/ui.js` — `_protokolUygula`, `_protokolDismiss`, `_protokolGeriAl` fonksiyonları

- [ ] **Step 1: _protokolUygula fonksiyonu — mini bottom-sheet form**

```javascript
async function _protokolUygula(idx){
  const d = window.__protokolUyarilar[idx];
  if (!d) return;

  const stoklar = await idbGetAll('stok');
  const filtered = d.etken_kod ? stoklar.filter(s => {
    const ad = (s.urun_adi||'').toLowerCase();
    switch(d.etken_kod) {
      case 'OKSITOSIN': return ad.includes('oksitosin') || ad.includes('oxytocin');
      case 'PG': return ad.includes('pg') || ad.includes('prostaglandin') || ad.includes('dinoprost') || ad.includes('estrumate') || ad.includes('cloprostenol');
      case 'E_VIT': return ad.includes('e vit') || ad.includes('yeldif');
      case 'ADEMIN': return ad.includes('ademin');
      case 'KALSIYUM': return ad.includes('kalsiyum') || ad.includes('calcium');
      default: return true;
    }
  }) : stoklar;

  let mini = document.getElementById('proto-mini');
  if (mini) mini.remove();
  mini = document.createElement('div');
  mini.id = 'proto-mini';
  mini.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:400;display:flex;align-items:flex-end';
  mini.onclick = e => { if (e.target === mini) mini.remove(); };

  const stokOpts = filtered.map(s => `<option value="${s.id}">${esc(s.urun_adi)} (${s.birim||''})</option>`).join('');
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin'].map(r => `<option value="${r}">${r}</option>`).join('');

  mini.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:12px">💉 Hızlı Uygulama — ${esc(d.kupe_no||'?')}</div>
    <div style="font-size:.7rem;color:var(--ink3);margin-bottom:10px">${esc(d.adim)}</div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Stok</label>
    <select id="pu-stok" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${stokOpts}</select>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Doz</label><input id="pu-doz" type="number" step="0.1" value="10" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Birim</label><input id="pu-birim" value="ml" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
    </div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Rota</label>
    <select id="pu-rota" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${rotaOpts}</select>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Not (zorunlu)</label>
    <input id="pu-not" placeholder="Uygulama notu..." style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:12px;font-size:.8rem">
    <button onclick="_protokolUygulaKaydet('${d.hayvan_id}',${idx})" class="btn" style="width:100%;padding:10px;font-weight:700">Kaydet</button>
  </div>`;
  document.body.appendChild(mini);
}

async function _protokolUygulaKaydet(hayvanId, idx){
  const stok = document.getElementById('pu-stok')?.value;
  const doz = parseFloat(document.getElementById('pu-doz')?.value);
  const birim = document.getElementById('pu-birim')?.value;
  const rota = document.getElementById('pu-rota')?.value;
  const not_ = document.getElementById('pu-not')?.value?.trim();
  if (!stok || !doz || !birim || !rota || !not_) { toast('Tüm alanları doldurun', true); return; }

  try {
    const res = await rpc('hizli_uygulama', {
      p_hayvan_id: hayvanId, p_stok_id: stok, p_doz: doz, p_birim: birim, p_rota: rota, p_notlar: not_
    });
    if (res?.ok) {
      toast('✅ Uygulama kaydedildi');
      document.getElementById('proto-mini')?.remove();
      document.getElementById('protokol-bs')?.remove();
      loadDash();
    } else {
      toast(res?.mesaj || 'Hata', true);
    }
  } catch(e) { toast('Hata: '+e.message, true); }
}
```

- [ ] **Step 2: _protokolDismiss fonksiyonu**

```javascript
async function _protokolDismiss(idx){
  const d = window.__protokolUyarilar[idx];
  if (!d) return;
  const neden = prompt('Geçersiz kılma nedeni (opsiyonel):');
  if (neden === null) return; // iptal

  try {
    await db.from('protokol_dismiss').insert({
      hayvan_id: d.hayvan_id,
      etken_kod: d.etken_kod || 'MANUAL',
      protokol: d.protokol,
      neden: neden || null
    });
    toast('Uyarı geçersiz kılındı');
    document.getElementById('protokol-bs')?.remove();
    loadDash();
  } catch(e) { toast('Hata: '+e.message, true); }
}
```

- [ ] **Step 3: _protokolGeriAl fonksiyonu**

```javascript
async function _protokolGeriAl(ref){
  if (!confirm('Bu işlemi geri almak istediğinize emin misiniz?')) return;

  const parts = ref.split(':');
  if (parts[0] === 'uygulama_log' && parts[1]) {
    try {
      const res = await rpc('hizli_uygulama_geri_al', { p_uygulama_id: parts[1] });
      if (res?.ok) {
        toast('İşlem geri alındı');
        document.getElementById('protokol-bs')?.remove();
        loadDash();
      } else {
        toast(res?.mesaj || 'Hata', true);
      }
    } catch(e) { toast('Hata: '+e.message, true); }
  } else {
    toast('Bu işlem geri alınamaz (farklı kaynak)', true);
  }
}
```

- [ ] **Step 4: Test — Uygula/Geçersiz/Geri Al akışları**

1. Protokol ekranını aç → "Uygula" tıkla → mini form açılır → stok seç, doz gir, not yaz → Kaydet
2. "Geçersiz ✕" tıkla → neden sor → geçersiz kıl
3. Tamamlanan satırda "Geri Al" → onay → geri al

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "$(cat <<'EOF'
feat(ui): protokol uygula form + geçersiz kılma + geri alma akışları

Mini bottom-sheet: stok (etken_kod filtrelenmiş), doz, rota, zorunlu not.
Geçersiz: protokol_dismiss INSERT. Geri Al: hizli_uygulama_geri_al RPC.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Hayvan Kartı "Hızlı Uygulama" Butonu

**Files:**
- Modify: `js/ui.js` — `_detOzetHtml` veya hayvan detay aksiyon butonlarına ekle

- [ ] **Step 1: _detOzetHtml fonksiyonunu bul ve butonu ekle**

`_detOzetHtml` fonksiyonundaki mevcut aksiyon butonlarının yanına "💉 Hızlı Uygulama" butonu ekle. Buton `_hayvanHizliUygulama(hayvanId)` çağırır.

Mevcut butonları bul (ör: `🩺 Muayene`, `💉 Tohumla` vb. butonların bulunduğu HTML satırı) ve yanına ekle:

```javascript
`<button class="btn btn-o" onclick="_hayvanHizliUygulama('${a.id}')">💉 Hızlı Uygulama</button>`
```

- [ ] **Step 2: _hayvanHizliUygulama fonksiyonu**

```javascript
async function _hayvanHizliUygulama(hayvanId){
  const stoklar = await idbGetAll('stok');
  const ilaclar = stoklar.filter(s => s.kategori && !['Yem','Sperma'].includes(s.kategori));

  let mini = document.getElementById('hizli-uyg-bs');
  if (mini) mini.remove();
  mini = document.createElement('div');
  mini.id = 'hizli-uyg-bs';
  mini.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:400;display:flex;align-items:flex-end';
  mini.onclick = e => { if (e.target === mini) mini.remove(); };

  const stokOpts = ilaclar.map(s => `<option value="${s.id}">${esc(s.urun_adi)} (${s.birim||''})</option>`).join('');
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin'].map(r => `<option value="${r}">${r}</option>`).join('');

  mini.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:12px">💉 Hızlı Uygulama</div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Stok</label>
    <select id="hu-stok" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${stokOpts}</select>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Doz</label><input id="hu-doz" type="number" step="0.1" value="10" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Birim</label><input id="hu-birim" value="ml" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
    </div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Rota</label>
    <select id="hu-rota" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${rotaOpts}</select>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Not (zorunlu)</label>
    <input id="hu-not" placeholder="Uygulama notu..." style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:12px;font-size:.8rem">
    <button onclick="_hayvanHizliUygulaKaydet('${hayvanId}')" class="btn" style="width:100%;padding:10px;font-weight:700">Kaydet</button>
  </div>`;
  document.body.appendChild(mini);
}

async function _hayvanHizliUygulaKaydet(hayvanId){
  const stok = document.getElementById('hu-stok')?.value;
  const doz = parseFloat(document.getElementById('hu-doz')?.value);
  const birim = document.getElementById('hu-birim')?.value;
  const rota = document.getElementById('hu-rota')?.value;
  const not_ = document.getElementById('hu-not')?.value?.trim();
  if (!stok || !doz || !birim || !rota || !not_) { toast('Tüm alanları doldurun', true); return; }

  try {
    const res = await rpc('hizli_uygulama', {
      p_hayvan_id: hayvanId, p_stok_id: stok, p_doz: doz, p_birim: birim, p_rota: rota, p_notlar: not_
    });
    if (res?.ok) {
      toast('✅ Uygulama kaydedildi' + (res.etken_kod ? ' (' + res.etken_kod + ')' : ''));
      document.getElementById('hizli-uyg-bs')?.remove();
      openDet(hayvanId, true);
    } else {
      toast(res?.mesaj || 'Hata', true);
    }
  } catch(e) { toast('Hata: '+e.message, true); }
}
```

- [ ] **Step 3: Test — hayvan kartından hızlı uygulama**

Hayvan detay → "💉 Hızlı Uygulama" → form → doldur → Kaydet → toast + refresh

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "$(cat <<'EOF'
feat(ui): hayvan kartı hızlı uygulama butonu + bottom-sheet

Case açmadan tek seferlik ilaç/vitamin kaydı. Tüm stoklar listelenir (filtre yok).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Hayvan Kartı Uygulama Geçmişi

**Files:**
- Modify: `js/ui.js` — hayvan detay sağlık/geçmiş tab'ına `uygulama_log` listesi ekle

- [ ] **Step 1: openDet'te uygulama_log verisi çek**

`openDet` fonksiyonunun `Promise.all` listesine ekle:

```javascript
getData('uygulama_log', u => u.hayvan_id === id),
```

Destructuring'e `uygulamaLogs` ekle ve sağlık tab render'ına aktar.

- [ ] **Step 2: pullTables listesine uygulama_log ekle**

`openDet` fonksiyonundaki `pullTables` çağrısına `'uygulama_log'` ekle:

```javascript
await pullTables(['cases','diseases','drugs','vaccines','vaccination_log','kizginlik_log','gorev_log','uygulama_log'])
```

- [ ] **Step 3: Sağlık tab'ında uygulama geçmişi bölümü**

`_detSaglikRender` fonksiyonuna veya sağlık tab HTML'ine uygulama_log listesi ekle:

```javascript
const uygulamaHtml = uygulamaLogs.length ? `<div style="margin-top:16px">
  <div style="font-weight:700;font-size:.8rem;margin-bottom:8px">💉 Hızlı Uygulamalar</div>
  ${uygulamaLogs.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||'')).map(u => {
    const stok = stoklar.find(s => s.id === u.stok_id);
    return `<div class="arow" style="margin-bottom:4px"><div class="arow-left"><div class="arow-id" style="font-size:.75rem">${esc(stok?.urun_adi||'?')} — ${u.doz} ${u.birim} (${u.rota})</div><div class="arow-sub">${u.tarih||'?'} · ${esc(u.notlar||'')}</div></div></div>`;
  }).join('')}
</div>` : '';
```

- [ ] **Step 4: Test — hayvan kartında uygulama geçmişi**

Hayvan detay → Sağlık tab → "Hızlı Uygulamalar" bölümü görünmeli (eğer kayıt varsa).

- [ ] **Step 5: Commit**

```bash
git add js/ui.js
git commit -m "$(cat <<'EOF'
feat(ui): hayvan kartı uygulama geçmişi — uygulama_log listesi

Sağlık tab'ında hızlı uygulama kayıtları: tarih + stok + doz + rota + not.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: `ground_truth.sql` Sync

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

- [ ] **Step 1: Yeni tablo tanımlarını ground_truth'a ekle**

`gorev_log` CREATE TABLE'dan sonra şunları ekle:
- `gorev_log` kolonları: `etken_kod text`, `kapatan_ref text`
- `uygulama_log` CREATE TABLE
- `protokol_dismiss` CREATE TABLE

- [ ] **Step 2: Yeni fonksiyonları ground_truth'a ekle**

Fonksiyonlar bölümüne ekle:
- `_etken_kod_bul`
- `_gorev_dinle`
- `hizli_uygulama`
- `hizli_uygulama_geri_al`
- `protokol_eksik_tara`

- [ ] **Step 3: Trigger fonksiyonları ve trigger'ları ekle**

- `fn_dinle_vaccination` + `trg_dinle_vaccination`
- `fn_dinle_uygulama` + `trg_dinle_uygulama`
- `fn_dinle_drug_admin` + `trg_dinle_drug_admin`

- [ ] **Step 4: dogum_kaydet ve fn_gebe_gorev_yarat güncellemelerini yansıt**

Mevcut `dogum_kaydet` fonksiyonunu (satır ~3802) yeni versiyonla değiştir.
`fn_gebe_gorev_yarat` fonksiyonunu (satır ~6406) yeni versiyonla değiştir.

- [ ] **Step 5: Doğrula — ground_truth tutarlı**

Run: `grep -c 'etken_kod' supabase/migrations/99999999999999_ground_truth.sql`

Expected: Multiple matches (kolonlar + fonksiyonlar + trigger'lar)

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "$(cat <<'EOF'
chore(db): ground_truth sync — protokol uyarı sistemi tüm bileşenler

etken_kod, uygulama_log, protokol_dismiss, _gorev_dinle, hizli_uygulama,
protokol_eksik_tara, 3 dinleme trigger, dogum_kaydet + fn_gebe_gorev_yarat güncel.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Son Kontrol

Tüm task'lar tamamlandıktan sonra:

1. `npx supabase db push --linked` — tüm migration'lar uygulanmış mı?
2. Dashboard'u yenile → zil ikonu + badge doğru mu?
3. Zil → protokol ekranı → uygula/geçersiz/geri al çalışıyor mu?
4. Hayvan kartı → hızlı uygulama butonu → form → kaydet → toast?
5. Hayvan kartı → sağlık tab → uygulama geçmişi?
6. Bir aşı yap (toplu aşılama veya hayvan kartından) → ilgili görev otomatik kapandı mı?
7. `git log --oneline -20` — tüm commit'ler sıralı mı?
