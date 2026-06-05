# Protokol Instance + Lifecycle Cancel Guarantee — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `protokol_instance` tablosu oluşturup tüm ilgili RPC'leri güncelleyerek hayvan çıkışında (ölüm/satış) tüm pending görevlerin iptal edilmesini ve protokol durumunun her zaman sorgulanabilir olmasını sağlamak.

**Architecture:** Yeni `protokol_instance` tablosu her protokol grubunu (UREME/TOHUMLAMA, BAKIM/BESLEME vb.) tek satırda temsil eder. `gorev_log.protokol_instance_id` UUID FK ile her görev kendi protokolünü bilir. `cikis_yap` RPC hayvan çıkışında tüm aktif instance'ları ve pending görevleri atom olarak kapatır.

**Tech Stack:** PostgreSQL PL/pgSQL, Supabase migrations, Vanilla JS (ui.js line 48-55, api.js line 10-14)

**Referans dosyalar:**
- Spec: `docs/superpowers/specs/2026-06-05-protokol-instance-lifecycle-design.md`
- Canonical DB: `supabase/migrations/99999999999999_ground_truth.sql`
- Latest tohumlama_kaydet: `supabase/migrations/20260605000002_timezone_fix.sql`
- Latest dogum_kaydet: `supabase/migrations/20260605000001_dogum_kaydet_besleme_fix.sql`
- Besleme: `supabase/migrations/20260521000005_besleme_gorevi.sql`

---

## File Map

| Dosya | İşlem |
|---|---|
| `supabase/migrations/20260605000003_protokol_instance_schema.sql` | CREATE: protokol_instance tablosu + gorev_log FK |
| `supabase/migrations/20260605000004_cikis_yap_rpc.sql` | CREATE: _protokol_kapat helper + cikis_yap RPC |
| `supabase/migrations/20260605000005_kaynak_backfill.sql` | UPDATE: kaynak standardize + protokol_instance backfill + gorev_log FK backfill |
| `supabase/migrations/20260605000006_dogum_kaydet_update.sql` | UPDATE: dogum_kaydet (2 instance, buzağı kaynak değişimi) |
| `supabase/migrations/20260605000007_tohumlama_kaydet_update.sql` | UPDATE: tohumlama_kaydet (TOHUMLAMA instance) |
| `supabase/migrations/20260605000008_gebe_trigger_update.sql` | UPDATE: fn_gebe_gorev_yarat + ileri_gebe_gorev_kontrol (GEBELIK instance) |
| `supabase/migrations/20260605000009_besleme_padok_update.sql` | UPDATE: gebelik_protokol_kontrol + besleme_tamam + padok_degistir (BAKIM instance) |
| `supabase/migrations/99999999999999_ground_truth.sql` | UPDATE: tüm değişiklikleri yansıt |
| `js/ui.js` | MODIFY: `_katTipMap` satır 48-55 (3 satır) |
| `js/api.js` | MODIFY: `TABLES` satır 10-14 — `protokol_instance` ekle |

---

## Task 0: DB Backup Al

**Files:** Supabase dashboard veya tools-bank MCP

- [ ] **Step 1: Mevcut DB durumunu kontrol et**

```bash
# Canlı DB'deki kritik tablo satır sayılarını kaydet
# tools-bank MCP ile:
supabase_query({table: "gorev_log", filters: "iptal=eq.false&tamamlandi=eq.false", select: "count"})
supabase_query({table: "protokol_instance", select: "count"})  # → "no such table" beklenir
```

- [ ] **Step 2: GitHub üzerinde backup al (mevcut son commit hash'i kaydet)**

```bash
cd /root/egesut-erp1
git log --oneline -1
# Bu hash'i not al — revert gerekirse: git revert <hash>
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: pre-migration checkpoint — protokol_instance implementation başlıyor"
git push origin main
```

---

## Task 1: protokol_instance Tablosu + gorev_log FK

**Files:**
- Create: `supabase/migrations/20260605000003_protokol_instance_schema.sql`

- [ ] **Step 1: Migration dosyasını oluştur**

```sql
-- supabase/migrations/20260605000003_protokol_instance_schema.sql
BEGIN;

-- 1. protokol_instance tablosu
CREATE TABLE public.protokol_instance (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  hayvan_id     text        NOT NULL REFERENCES public.hayvanlar(id) ON DELETE CASCADE,
  tip           text        NOT NULL,  -- UREME | BAKIM | SAGLIK
  alttip        text        NOT NULL,  -- KIZGINLIK|TOHUMLAMA|GEBELIK|DOGUM | BUZAGI|BESLEME|PADOK|SUTTEN_KESME | TEDAVI|ASI|MUAYENE
  kaynak_ref    text        NOT NULL,  -- gorev_log.kaynak ile eşleşen değer
  baslangic     date        NOT NULL,
  durum         text        NOT NULL DEFAULT 'aktif',  -- aktif | tamamlandi | iptal
  kapandi_at    timestamptz,
  kapandi_sebep text,                  -- DOGUM | OLUM | SATIS | MANUEL | TAMAMLANDI
  created_at    timestamptz DEFAULT now(),
  CONSTRAINT protokol_instance_kaynak_unique UNIQUE (kaynak_ref)
);

ALTER TABLE public.protokol_instance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "protokol_instance_all" ON public.protokol_instance;
CREATE POLICY "protokol_instance_all" ON public.protokol_instance FOR ALL USING (true) WITH CHECK (true);

CREATE INDEX idx_pi_hayvan_durum ON public.protokol_instance(hayvan_id, durum);
CREATE INDEX idx_pi_tip_alttip   ON public.protokol_instance(tip, alttip);
CREATE INDEX idx_pi_kaynak_ref   ON public.protokol_instance(kaynak_ref);

-- 2. gorev_log FK kolonu ekle
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS protokol_instance_id uuid
  REFERENCES public.protokol_instance(id) ON DELETE SET NULL;

CREATE INDEX idx_gorev_protokol ON public.gorev_log(protokol_instance_id)
  WHERE protokol_instance_id IS NOT NULL;

NOTIFY pgrst, 'reload schema';

COMMIT;
```

- [ ] **Step 2: Migration'ı uygula**

```bash
# tools-bank MCP ile:
supabase_migrate({sql: "<dosya içeriği>"})
```

Beklenen sonuç: `CREATE TABLE`, `ALTER TABLE`, `CREATE INDEX` başarılı. Hata yoksa devam.

- [ ] **Step 3: Doğrula**

```sql
-- tools-bank MCP ile:
supabase_query({table: "protokol_instance", limit: 1})
-- → boş sonuç (tablo yeni, satır yok) — tablo oluşmuş demek

supabase_query({table: "gorev_log", select: "id,protokol_instance_id", limit: 1})
-- → protokol_instance_id NULL gelir — kolon eklenmiş
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260605000003_protokol_instance_schema.sql
git commit -m "feat: protokol_instance tablosu + gorev_log FK kolonu"
git push origin main
```

---

## Task 2: `_protokol_kapat` Helper + `cikis_yap` RPC

**Files:**
- Create: `supabase/migrations/20260605000004_cikis_yap_rpc.sql`

- [ ] **Step 1: Migration dosyasını oluştur**

```sql
-- supabase/migrations/20260605000004_cikis_yap_rpc.sql
BEGIN;

-- ── 1. _protokol_kapat: tek kaynak_ref'e göre protokol kapat + görevleri iptal et ──
CREATE OR REPLACE FUNCTION public._protokol_kapat(
  p_kaynak_ref  text,
  p_sebep       text  -- DOGUM | OLUM | SATIS | MANUEL | TAMAMLANDI
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
  SET iptal = true
  WHERE kaynak = p_kaynak_ref
    AND tamamlandi = false
    AND iptal = false;

  UPDATE public.protokol_instance
  SET durum = 'iptal',
      kapandi_at = now(),
      kapandi_sebep = p_sebep
  WHERE kaynak_ref = p_kaynak_ref
    AND durum = 'aktif';
END;
$$;

GRANT EXECUTE ON FUNCTION public._protokol_kapat(text, text) TO anon, authenticated;

-- ── 2. cikis_yap: hayvan çıkışı — tüm pending görevler + tüm aktif protokoller iptal ──
-- Not: Bu RPC daha önce DB'de mevcut değildi. Frontend submitCikis fonksiyonu (forms.js:586)
--   bu param isimlerini kullanıyor: p_hayvan_id, p_cikis_tipi, p_cikis_tarihi, p_cikis_sebebi, p_satis_fiyati
CREATE OR REPLACE FUNCTION public.cikis_yap(
  p_hayvan_id    text,
  p_cikis_tipi   text,           -- 'olum' | 'satis'
  p_cikis_tarihi date    DEFAULT (NOW() AT TIME ZONE 'Europe/Istanbul')::date,
  p_cikis_sebebi text    DEFAULT NULL,
  p_satis_fiyati numeric DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_durum_yeni      text;
  v_iptal_gorev_say integer;
  v_iptal_inst_say  integer;
BEGIN
  IF p_cikis_tipi = 'olum' THEN
    v_durum_yeni := 'Ölü';
  ELSIF p_cikis_tipi = 'satis' THEN
    v_durum_yeni := 'Satıldı';
  ELSE
    RAISE EXCEPTION 'Geçersiz çıkış tipi: % (beklenen: olum veya satis)', p_cikis_tipi;
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

  -- TÜM pending görevleri iptal et (kaynak bağımsız)
  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false;

  GET DIAGNOSTICS v_iptal_gorev_say = ROW_COUNT;

  -- TÜM aktif protokol instance'larını kapat
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
$$;

GRANT EXECUTE ON FUNCTION public.cikis_yap(text, text, date, text, numeric) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
```

- [ ] **Step 2: Migration'ı uygula**

```bash
supabase_migrate({sql: "<dosya içeriği>"})
```

- [ ] **Step 3: cikis_yap'ı test et (test hayvana karşı — sadece SELECT ile doğrula)**

```sql
-- Önce test edilecek aktif hayvan bul
supabase_query({table: "hayvanlar", filters: "durum=eq.Aktif", select: "id,kupe_no", limit: 1})

-- Fonksiyonun imzasını doğrula (gerçek çağrı yapma — test)
supabase_rpc({function_name: "cikis_yap", params: '{"p_hayvan_id":"OLMAYAN_ID","p_cikis_tipi":"satis"}'})
-- → {"ok": false, "mesaj": "Aktif hayvan bulunamadı: OLMAYAN_ID"} beklenir
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260605000004_cikis_yap_rpc.sql
git commit -m "feat: cikis_yap RPC + _protokol_kapat helper — lifecycle cancel guarantee"
git push origin main
```

---

## Task 3: Kaynak Standardizasyonu + Backfill

**Files:**
- Create: `supabase/migrations/20260605000005_kaynak_backfill.sql`

Bu migration 3 iş yapar:
1. Mevcut `kaynak='ILERI_GEBE'` → `kaynak='ILERI_GEBE-{hayvan_id}'`
2. Mevcut `kaynak='BESLEME_OTOMATIK'` → `kaynak='BESLEME-{hayvan_id}'`
3. `protokol_instance` tablosunu mevcut kaynak değerlerinden backfill eder
4. `gorev_log.protokol_instance_id` FK'larını backfill eder

- [ ] **Step 1: Migration öncesi mevcut durumu kaydet**

```sql
-- tools-bank MCP ile — backfill sonrası karşılaştırma için
supabase_query({table: "gorev_log", filters: "kaynak=eq.ILERI_GEBE&iptal=eq.false", select: "count"})
supabase_query({table: "gorev_log", filters: "kaynak=eq.BESLEME_OTOMATIK&iptal=eq.false", select: "count"})
supabase_query({table: "gorev_log", filters: "kaynak=like.DOGUM-*&iptal=eq.false", select: "count"})
supabase_query({table: "gorev_log", filters: "kaynak=like.TOH-*&iptal=eq.false", select: "count"})
```

- [ ] **Step 2: Migration dosyasını oluştur**

```sql
-- supabase/migrations/20260605000005_kaynak_backfill.sql
BEGIN;

-- ── 1. ILERI_GEBE → ILERI_GEBE-{hayvan_id} ────────────────────────────────
-- Eski tekil kaynak tüm hayvanlarda aynı stringdi → UNIQUE constraint çakışır
-- Önce per-animal birleşik string'e rename et
UPDATE public.gorev_log
SET kaynak = 'ILERI_GEBE-' || hayvan_id
WHERE kaynak = 'ILERI_GEBE'
  AND hayvan_id IS NOT NULL;

-- ── 2. BESLEME_OTOMATIK → BESLEME-{hayvan_id} ─────────────────────────────
UPDATE public.gorev_log
SET kaynak = 'BESLEME-' || hayvan_id
WHERE kaynak = 'BESLEME_OTOMATIK'
  AND hayvan_id IS NOT NULL;

-- ── 3. Backfill: protokol_instance — DOGUM protokolleri (anne) ────────────
-- kaynak='DOGUM-{anne_id}' olan görevlerden instance türet
-- Buzağı görevleri de şimdilik bu kaynak altında — Task 6'da ayrılacak
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT DISTINCT ON (gl.kaynak)
  -- anne_id'yi DOGUM- prefix'inden çıkar
  substring(gl.kaynak FROM 7),   -- 'DOGUM-H000042' → 'H000042'
  'UREME',
  'DOGUM',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih), CURRENT_DATE),
  CASE
    WHEN EXISTS (
      SELECT 1 FROM public.gorev_log g2
      WHERE g2.kaynak = gl.kaynak AND g2.tamamlandi = false AND g2.iptal = false
    ) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'DOGUM-%'
  AND gl.hayvan_id IS NOT NULL
  AND substring(gl.kaynak FROM 7) IN (SELECT id FROM public.hayvanlar)
GROUP BY gl.kaynak
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 4. Backfill: protokol_instance — TOHUMLAMA ────────────────────────────
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT DISTINCT ON (gl.kaynak)
  gl.hayvan_id,
  'UREME',
  'TOHUMLAMA',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih) - 21, CURRENT_DATE),  -- 21. gün kontrolüne göre tarih tahmini
  CASE
    WHEN EXISTS (
      SELECT 1 FROM public.gorev_log g2
      WHERE g2.kaynak = gl.kaynak AND g2.tamamlandi = false AND g2.iptal = false
    ) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'TOH-%'
  AND gl.hayvan_id IS NOT NULL
GROUP BY gl.kaynak, gl.hayvan_id
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 5. Backfill: protokol_instance — ILERI_GEBE (UREME/GEBELIK) ──────────
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT DISTINCT ON (gl.kaynak)
  gl.hayvan_id,
  'UREME',
  'GEBELIK',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih) - 240, CURRENT_DATE),
  CASE
    WHEN EXISTS (
      SELECT 1 FROM public.gorev_log g2
      WHERE g2.kaynak = gl.kaynak AND g2.tamamlandi = false AND g2.iptal = false
    ) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'ILERI_GEBE-%'
  AND gl.hayvan_id IS NOT NULL
GROUP BY gl.kaynak, gl.hayvan_id
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 6. Backfill: protokol_instance — BESLEME (BAKIM/BESLEME) ─────────────
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT DISTINCT ON (gl.kaynak)
  gl.hayvan_id,
  'BAKIM',
  'BESLEME',
  gl.kaynak,
  COALESCE(MIN(gl.hedef_tarih), CURRENT_DATE),
  CASE
    WHEN EXISTS (
      SELECT 1 FROM public.gorev_log g2
      WHERE g2.kaynak = gl.kaynak AND g2.tamamlandi = false AND g2.iptal = false
    ) THEN 'aktif'
    ELSE 'tamamlandi'
  END
FROM public.gorev_log gl
WHERE gl.kaynak LIKE 'BESLEME-%'
  AND gl.hayvan_id IS NOT NULL
GROUP BY gl.kaynak, gl.hayvan_id
ON CONFLICT (kaynak_ref) DO NOTHING;

-- ── 7. Backfill: gorev_log.protokol_instance_id doldur ───────────────────
UPDATE public.gorev_log gl
SET protokol_instance_id = pi.id
FROM public.protokol_instance pi
WHERE gl.kaynak = pi.kaynak_ref
  AND gl.protokol_instance_id IS NULL;

COMMIT;
```

- [ ] **Step 3: Migration'ı uygula**

```bash
supabase_migrate({sql: "<dosya içeriği>"})
```

- [ ] **Step 4: Doğrula**

```sql
-- ILERI_GEBE renamelenmiş mi?
supabase_query({table: "gorev_log", filters: "kaynak=eq.ILERI_GEBE", limit: 1})
-- → boş sonuç beklenir

-- protokol_instance dolu mu?
supabase_query({table: "protokol_instance", select: "tip,alttip,durum,count", limit: 20})
-- → DOGUM, TOHUMLAMA, GEBELIK, BESLEME instance'ları görünmeli

-- gorev_log FK dolu mu?
supabase_query({table: "gorev_log", filters: "protokol_instance_id=not.is.null", select: "count"})
-- → 0'dan büyük bir sayı beklenir
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260605000005_kaynak_backfill.sql
git commit -m "feat: kaynak standardizasyonu + protokol_instance backfill (DOGUM/TOH/ILERI_GEBE/BESLEME)"
git push origin main
```

---

## Task 4: `dogum_kaydet` Güncelle — İki Instance, Buzağı Kaynak Ayrımı

**Files:**
- Create: `supabase/migrations/20260605000006_dogum_kaydet_update.sql`

- [ ] **Step 1: Migration dosyasını oluştur**

Mevcut `dogum_kaydet` (20260605000001_dogum_kaydet_besleme_fix.sql) baz alınarak, iki değişiklik:
1. Her çağrıda bir `UREME/DOGUM` (anne) + bir `BAKIM/BUZAGI` (buzağı) instance açılır
2. Buzağı görevleri artık `kaynak='BUZAGI-{buzagi_id}'` kullanır (eskiden `'DOGUM-{anne_id}'`)

```sql
-- supabase/migrations/20260605000006_dogum_kaydet_update.sql
BEGIN;

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
  v_anne         record;
  v_dogum_id     uuid := gen_random_uuid();
  v_buzagi_id    text;
  v_ana_gorev    uuid := gen_random_uuid();
  v_sayac        integer;
  v_dup          text;
  v_baba_bilgi   text;
  v_anne_inst_id uuid;
  v_buzagi_inst_id uuid;
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

  -- ── Instance 1: Anne protokolü (UREME/DOGUM) ──
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_anne_id, 'UREME', 'DOGUM', 'DOGUM-' || p_anne_id, p_tarih, 'aktif')
  ON CONFLICT (kaynak_ref) DO UPDATE SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
  RETURNING id INTO v_anne_inst_id;

  -- ── Instance 2: Buzağı bakım protokolü (BAKIM/BUZAGI) ──
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (v_buzagi_id, 'BAKIM', 'BUZAGI', 'BUZAGI-' || v_buzagi_id, p_tarih, 'aktif')
  RETURNING id INTO v_buzagi_inst_id;

  -- ── Anne protokol görevleri (kaynak='DOGUM-{anne_id}', instance=v_anne_inst_id) ──
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih,      false, 'DOGUM-' || p_anne_id, 'OKSITOSIN', v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih,      false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih,      false, 'DOGUM-' || p_anne_id, 'KALSIYUM',  v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '11. Gün PG',            p_tarih + 11, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Ademin',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Yeldif',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '54. Gün: Yeldif',       p_tarih + 54, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'DIGER','⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL, v_anne_inst_id);

  -- ── Buzağı görevleri (kaynak='BUZAGI-{buzagi_id}' — anne kaynağından AYRILDI) ──
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

  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  -- Doğumda aktif BESLEME görevlerini iptal et (anyonik besleme zinciri)
  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_anne_id
    AND gorev_tipi = 'BESLEME'
    AND tamamlandi = false
    AND iptal = false;

  -- BESLEME protokol instance'ını da kapat
  UPDATE public.protokol_instance
  SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'DOGUM'
  WHERE hayvan_id = p_anne_id AND alttip = 'BESLEME' AND durum = 'aktif';

  RETURN jsonb_build_object(
    'ok',           true,
    'buzagi_id',    v_buzagi_id,
    'dogum_id',     v_dogum_id,
    'gorev_sayisi', 17,
    'anne_inst_id', v_anne_inst_id,
    'buzagi_inst_id', v_buzagi_inst_id,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text,date,text,text,text,numeric,text,text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
```

- [ ] **Step 2: Migration'ı uygula ve doğrula**

```bash
supabase_migrate({sql: "<dosya içeriği>"})
```

Doğrulama — test bir doğum çağrısı yap (dikkat: gerçek veri oluşur, test ortamında yap):
```sql
-- Önce aktif gebe hayvan bul
supabase_query({table: "tohumlama", filters: "sonuc=eq.Gebe", select: "hayvan_id,tarih", limit: 1})

-- dogum_kaydet sonucu anne + buzağı instance oluşturmuş mu kontrol et
supabase_query({table: "protokol_instance", filters: "alttip=eq.DOGUM", select: "hayvan_id,kaynak_ref,durum", limit: 5})
supabase_query({table: "protokol_instance", filters: "alttip=eq.BUZAGI", select: "hayvan_id,kaynak_ref,durum", limit: 5})
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260605000006_dogum_kaydet_update.sql
git commit -m "feat: dogum_kaydet — UREME/DOGUM + BAKIM/BUZAGI instance, buzağı kaynak='BUZAGI-{id}'"
git push origin main
```

---

## Task 5: `tohumlama_kaydet` Güncelle — TOHUMLAMA Instance

**Files:**
- Create: `supabase/migrations/20260605000007_tohumlama_kaydet_update.sql`

Baz: `supabase/migrations/20260605000002_timezone_fix.sql` (en güncel versiyon)

- [ ] **Step 1: Migration dosyasını oluştur**

```sql
-- supabase/migrations/20260605000007_tohumlama_kaydet_update.sql
BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id      text,
  p_tarih          date,
  p_sperma         text,
  p_hekim_id       text    DEFAULT NULL,
  p_irk_bilgisi    text    DEFAULT NULL,
  p_ek_uygulamalar jsonb   DEFAULT '[]'::jsonb,
  p_vwp_override   boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan    record;
  v_yas_gun   integer;
  v_deneme    integer;
  v_toh_id    uuid := gen_random_uuid();
  v_ek        jsonb;
  v_ek_stok   uuid;
  v_son_dogum date;
  v_vwp_gun   integer;
  v_inst_id   uuid;
  v_kaynak    text;
BEGIN
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  -- VWP kontrolü (55 gün)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme,
     p_ek_uygulamalar,
     CASE WHEN v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 THEN true ELSE false END);

  -- VWP override loglama
  IF v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 AND p_vwp_override THEN
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
    VALUES (
      gen_random_uuid()::text, 'VWP_OVERRIDE', p_hayvan_id,
      jsonb_build_object('tohumlama_id', v_toh_id, 'vwp_gun', p_tarih - v_son_dogum, 'son_dogum', v_son_dogum)
    );
  END IF;

  -- ── UREME/TOHUMLAMA instance aç ──
  v_kaynak := 'TOH-' || v_toh_id::text;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'TOHUMLAMA', v_kaynak, p_tarih, 'aktif')
  RETURNING id INTO v_inst_id;

  -- Görevler — kaynak + protokol_instance_id birlikte
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_kaynak, v_inst_id),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_kaynak, v_inst_id);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id), false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  IF p_ek_uygulamalar IS NOT NULL AND jsonb_array_length(p_ek_uygulamalar) > 0 THEN
    FOR v_ek IN SELECT * FROM jsonb_array_elements(p_ek_uygulamalar) LOOP
      IF (v_ek->>'stok_id') IS NOT NULL AND (v_ek->>'stok_id') <> '' THEN
        v_ek_stok := (v_ek->>'stok_id')::uuid;
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
        VALUES (
          v_ek_stok, 'Tohumlama',
          COALESCE((v_ek->>'doz')::numeric, 1),
          'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
          false
        );
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh_id,
    'deneme_no',    v_deneme,
    'inst_id',      v_inst_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
```

- [ ] **Step 2: Migration'ı uygula**

```bash
supabase_migrate({sql: "<dosya içeriği>"})
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260605000007_tohumlama_kaydet_update.sql
git commit -m "feat: tohumlama_kaydet — UREME/TOHUMLAMA instance + kaynak='TOH-{id}'"
git push origin main
```

---

## Task 6: `fn_gebe_gorev_yarat` + `ileri_gebe_gorev_kontrol` Güncelle — GEBELIK Instance

**Files:**
- Create: `supabase/migrations/20260605000008_gebe_trigger_update.sql`

- [ ] **Step 1: Migration dosyasını oluştur**

```sql
-- supabase/migrations/20260605000008_gebe_trigger_update.sql
BEGIN;

-- ── 1. fn_gebe_gorev_yarat trigger — kaynak + protokol_instance_id ekle ──
-- Trigger: tohumlama.sonuc = 'Gebe' olduğunda ateşlenir
CREATE OR REPLACE FUNCTION public.fn_gebe_gorev_yarat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
  v_kaynak  text;
  v_inst_id uuid;
BEGIN
  IF NEW.sonuc != 'Gebe' OR OLD.sonuc = 'Gebe' THEN
    RETURN NEW;
  END IF;

  SELECT stock_item_id INTO v_stok_id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1;

  v_kaynak := 'ILERI_GEBE-' || NEW.hayvan_id;

  -- Instance aç veya güncelle (hayvan tekrar gebe olabilir)
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (NEW.hayvan_id, 'UREME', 'GEBELIK', v_kaynak, NEW.tarih::date, 'aktif')
  ON CONFLICT (kaynak_ref) DO UPDATE
    SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
  RETURNING id INTO v_inst_id;

  -- v_inst_id NULL ise (DO UPDATE durumu) — ayrı SELECT gerekir
  IF v_inst_id IS NULL THEN
    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;
  END IF;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
         '💉 Rota-Corona Aşısı (1. doz)', NEW.tarih::date + 240, false, v_stok_id, 1, v_kaynak, 'ROTA', v_inst_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND tamamlandi = false
  );

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 SC Ademin uygulaması', NEW.tarih::date + 260, false, v_kaynak, 'ADEMIN', v_inst_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND tamamlandi = false
  );

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 IM E Vitamini uygulaması', NEW.tarih::date + 265, false, v_kaynak, 'E_VIT', v_inst_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND tamamlandi = false
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tohumlama_gebe_gorev ON tohumlama;
CREATE TRIGGER trg_tohumlama_gebe_gorev
  AFTER UPDATE ON tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.fn_gebe_gorev_yarat();

-- ── 2. ileri_gebe_gorev_kontrol — kaynak + protokol_instance_id ekle ──
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_stok_id     text;
  v_kaynak      text;
  v_inst_id     uuid;
BEGIN
  SELECT v.stock_item_id INTO v_stok_id FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun   := CURRENT_DATE - v_toh.tarih::date;
    v_kaynak := 'ILERI_GEBE-' || v_toh.hayvan_id;

    -- Instance bul veya oluştur
    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (v_toh.hayvan_id, 'UREME', 'GEBELIK', v_kaynak, v_toh.tarih::date, 'aktif')
    ON CONFLICT (kaynak_ref) DO NOTHING;

    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;

    -- 240. gün: Rota-Corona 1. doz
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (düveler)
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: E Vitamini
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_gorev_kontrol() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
```

- [ ] **Step 2: Migration'ı uygula**

```bash
supabase_migrate({sql: "<dosya içeriği>"})
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260605000008_gebe_trigger_update.sql
git commit -m "feat: fn_gebe_gorev_yarat + ileri_gebe_gorev_kontrol — UREME/GEBELIK instance, kaynak='ILERI_GEBE-{id}'"
git push origin main
```

---

## Task 7: `gebelik_protokol_kontrol` (Besleme) + `padok_degistir` Güncelle — BAKIM Instance

**Files:**
- Create: `supabase/migrations/20260605000009_besleme_padok_update.sql`

`gebelik_protokol_kontrol` (20260521000005_besleme_gorevi.sql, satır 13) BESLEME görevleri oluşturuyor. `besleme_tamam` zincirleme yapıyor. `padok_degistir` + `padok_degistir_toplu` PADOK_DEGISIM görevi oluşturuyor.

- [ ] **Step 1: gebelik_protokol_kontrol'ün mevcut imzasını oku**

```bash
grep -n "CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol" supabase/migrations/99999999999999_ground_truth.sql
# → satır numarasını bul, sonra Read ile oku
```

- [ ] **Step 2: Migration dosyasını oluştur**

Aşağıdaki migration iki şeyi yapar:
1. `gebelik_protokol_kontrol` içindeki BESLEME INSERT'lerine `kaynak='BESLEME-{hayvan_id}'` + `protokol_instance_id` ekle
2. `besleme_tamam` zincirleme INSERT'ine aynı `kaynak` + `protokol_instance_id` ekle
3. `padok_degistir` içine PADOK_DEGISIM görevi oluştururken `protokol_instance_id` ekle

```sql
-- supabase/migrations/20260605000009_besleme_padok_update.sql
-- NOT: Bu dosyadaki fonksiyon gövdeleri ground_truth'tan kopyalanmalı,
--   sadece BESLEME ve PADOK_DEGISIM INSERT bloklarına aşağıdaki pattern eklenir:
--
-- BESLEME görevi INSERT'i (kaynak ekle):
--   ... kaynak, protokol_instance_id)
--   SELECT ..., 'BESLEME-' || v_toh.hayvan_id,
--     (SELECT id FROM protokol_instance WHERE kaynak_ref='BESLEME-'||v_toh.hayvan_id LIMIT 1)
--
-- PADOK_DEGISIM görevi INSERT'i:
--   Önce instance aç, sonra protokol_instance_id ile INSERT yap.
--
-- Bu task'ı implement eden agent:
--   1. ground_truth.sql satır 7071'den padok_degistir'i oku
--   2. Kendi versiyonunda sadece PADOK_DEGISIM INSERT bloğunu güncelle
--   3. gebelik_protokol_kontrol'ü aynı şekilde güncelle
--
-- Minimal değişiklik örneği (gebelik_protokol_kontrol içindeki BESLEME INSERT):

BEGIN;

-- gebelik_protokol_kontrol içinde BESLEME instance'ı aç + kaynak ekle
-- (tam fonksiyon ground_truth'tan alınacak, sadece INSERT satırları güncellenir)

-- Örnek: BESLEME görevi INSERT bloğu değişikliği
-- ÖNCE:
--   SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
--          '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, 'BESLEME_OTOMATIK'
-- SONRA (instance aç, kaynak güncelle):
--   (SELECT id FROM protokol_instance WHERE kaynak_ref='BESLEME-'||v_toh.hayvan_id LIMIT 1)
--   ve INSERT öncesinde:
--   INSERT INTO protokol_instance (hayvan_id,tip,alttip,kaynak_ref,baslangic,durum)
--   VALUES (v_toh.hayvan_id,'BAKIM','BESLEME','BESLEME-'||v_toh.hayvan_id,CURRENT_DATE,'aktif')
--   ON CONFLICT (kaynak_ref) DO NOTHING;

-- Bu migration implement sırasında tam olarak yazılacak (ground_truth incelendikten sonra).
-- Placeholder: aşağıdaki SELECT doğrulamayı gösterir.
SELECT 1;  -- migration çalışır (boş)

COMMIT;
```

> **ÖNEMLİ:** Bu task'ı implement eden agent `gebelik_protokol_kontrol`'ün tüm BESLEME INSERT bloklarını ve `besleme_tamam`'ın zincirleme INSERT'ini güncellemeli. Fonksiyon ~200 satır — Read tool ile ground_truth'tan oku ve her INSERT bloğuna `kaynak='BESLEME-'||hayvan_id` ile protokol_instance_id ekle.

- [ ] **Step 3: Migration'ı uygula**

```bash
supabase_migrate({sql: "<dosya içeriği>"})
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260605000009_besleme_padok_update.sql
git commit -m "feat: gebelik_protokol_kontrol + besleme_tamam — BAKIM/BESLEME instance; padok_degistir — BAKIM/PADOK instance"
git push origin main
```

---

## Task 8: `ground_truth.sql` Güncelle

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

- [ ] **Step 1: Değişen tüm fonksiyonları ground_truth'a yansıt**

`ground_truth.sql` canonical referans — her oturum bu dosyadan okunur. Yeni/güncellenmiş her şeyi buraya ekle:

1. `protokol_instance` CREATE TABLE bloğu
2. `gorev_log` ALTER TABLE protokol_instance_id kolonu
3. `_protokol_kapat` fonksiyonu
4. `cikis_yap` fonksiyonu
5. `dogum_kaydet` yeni versiyonu (Task 4)
6. `tohumlama_kaydet` yeni versiyonu (Task 5)
7. `fn_gebe_gorev_yarat` yeni versiyonu (Task 6)
8. `ileri_gebe_gorev_kontrol` yeni versiyonu (Task 6)
9. `gebelik_protokol_kontrol` yeni versiyonu (Task 7)
10. `besleme_tamam` yeni versiyonu (Task 7)

Strateji: ground_truth.sql'in sonuna (son `NOTIFY pgrst` ve `COMMIT` öncesine) yeni blokları ekle. Eski versiyonların üzerine CREATE OR REPLACE yazılmış olduğundan çakışma olmaz.

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "chore: ground_truth güncelle — protokol_instance schema + tüm RPC güncellemeleri"
git push origin main
```

---

## Task 9: Frontend — `_katTipMap` + `api.js` TABLES

**Files:**
- Modify: `js/ui.js` satır 48-55
- Modify: `js/api.js` satır 10-14

- [ ] **Step 1: ui.js `_katTipMap` güncelle (satır 48-55)**

Mevcut:
```javascript
const _katTipMap={
  asi:['ILERI_GEBE_ASI','ASI_HATIRLATMA','ASI_RAPEL'],
  vitamin:['ILERI_GEBE'],
  muayene:['MUAYENE'],
  tedavi:['TEDAVI','ILAC_UYGULAMA','TEDAVI_GUN'],
  bakim:['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP','BESLEME'],
  diger:null
};
```

Yeni:
```javascript
const _katTipMap={
  asi:    ['ILERI_GEBE_ASI','ASI_HATIRLATMA','ASI_RAPEL'],
  vitamin:['ILERI_GEBE','TOHUMLAMA_HAZIRLIK','ILAC'],
  muayene:['MUAYENE','GEBELIK_KONTROL','VETERINER_KONTROL'],
  tedavi: ['TEDAVI','ILAC_UYGULAMA','TEDAVI_GUN'],
  bakim:  ['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP','BESLEME','BUZAGI_BAKIM'],
  diger:  null
};
```

Edit tool ile tam olarak bu değişikliği yap.

- [ ] **Step 2: api.js TABLES listesine `protokol_instance` ekle (satır 10-14)**

Mevcut:
```javascript
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','padoklar','grup_padok_eslem','hekimler','treatment_days','stok_kategorileri',
                  'uygulama_log'];
```

Yeni (satır 14 sonuna `'protokol_instance'` ekle):
```javascript
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','padoklar','grup_padok_eslem','hekimler','treatment_days','stok_kategorileri',
                  'uygulama_log','protokol_instance'];
```

- [ ] **Step 3: Doğrula — tarayıcıda dashboard filtrelerini kontrol et**

Dashboard açıldığında:
- `GEBELIK_KONTROL` → 🩺 Muayene'de görünmeli (eskiden 📋 Diğer)
- `TOHUMLAMA_HAZIRLIK` → 💊 Takviye'de görünmeli
- `BUZAGI_BAKIM` → 🐄 Bakım'da görünmeli

- [ ] **Step 4: Commit**

```bash
git add js/ui.js js/api.js
git commit -m "fix: _katTipMap dashboard filtreleri genişlet (GEBELIK_KONTROL/VETERINER_KONTROL→Muayene, TOHUMLAMA_HAZIRLIK/ILAC→Takviye, BUZAGI_BAKIM→Bakım)"
git push origin main
```

---

## Kapsam Kontrolü (Spec vs Plan)

| Spec Gereksinimi | Task |
|---|---|
| `protokol_instance` tablo + index | Task 1 |
| `gorev_log.protokol_instance_id` FK | Task 1 |
| `_protokol_kapat` helper | Task 2 |
| `cikis_yap` RPC (sıfırdan) | Task 2 |
| `ILERI_GEBE` → `ILERI_GEBE-{id}` rename | Task 3 |
| `BESLEME_OTOMATIK` → `BESLEME-{id}` rename | Task 3 |
| Backfill: protokol_instance | Task 3 |
| Backfill: gorev_log.protokol_instance_id | Task 3 |
| `dogum_kaydet` — 2 instance + buzağı kaynak | Task 4 |
| `tohumlama_kaydet` — TOHUMLAMA instance | Task 5 |
| `fn_gebe_gorev_yarat` — GEBELIK instance | Task 6 |
| `ileri_gebe_gorev_kontrol` — GEBELIK instance | Task 6 |
| `gebelik_protokol_kontrol` — BESLEME instance | Task 7 |
| `padok_degistir` — PADOK instance | Task 7 |
| `ground_truth.sql` güncelle | Task 8 |
| `_katTipMap` dashboard fix | Task 9 |
| `api.js` TABLES güncelle | Task 9 |

**Spec'te "Açık Kalan" olarak işaretlenen (bu plan kapsamı dışında):**
- Tüm görevler tamamlandığında `protokol_instance.durum` → `tamamlandi` otomatik güncellemesi
- Dashboard'da protokol durumu görünümü
- `kizginlik_log` → `UREME/KIZGINLIK` instance bağlantısı
