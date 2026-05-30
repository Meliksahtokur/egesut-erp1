# İlaç Sınıflandırma Sistemi Refactor — Faz 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tek tutarlı ilaç sınıflandırma sistemi: drug_classes → drug_products → stok zinciri, veteriner farmakoloji referansına uygun seed, Tanımlar accordion tree UI, dinamik GRUPLAR.

**Architecture:** 4 migration (kategori fix, yeni kategoriler, drug_classes FK değişikliği, seed), 4 yeni RPC (drug_class CRUD), 2 mevcut RPC'ye validate ekleme, UI'da Tanımlar "İlaç Sınıfları" accordion tree + Stok panelinde dinamik GRUPLAR.

**Tech Stack:** PostgreSQL (Supabase), vanilla JS (ui.js), IndexedDB cache (api.js)

**Spec:** `docs/superpowers/specs/2026-05-30-ilac-siniflandirma-refactor.md`

---

## File Structure

| Dosya | Sorumluluk | Değişiklik |
|-------|-----------|------------|
| `supabase/migrations/20260530000001_ilac_kategori_fix.sql` | Create: kategori tutarsızlıkları + yeni kategoriler + drug_classes FK | Migration 1-3 |
| `supabase/migrations/20260530000002_ilac_seed.sql` | Create: ders kitabı seed data | Migration 4 |
| `supabase/migrations/20260530000003_ilac_rpcler.sql` | Create: drug_class CRUD RPC'leri + stok validate | RPC'ler |
| `js/ui.js:2057-2070` | Modify: setTanimlarTab — yeni tab ekleme | Tab routing |
| `js/ui.js:2138-2142` | Modify: _tanimVarsayilanBtn — drug_classes için özelleştirme | Varsayılana dön |
| `js/ui.js:2200-2207` | Modify: _tanimVarsayilan — drug_classes desteği | Varsayılana dön RPC |
| `js/ui.js:2209-2262` | Modify: _renderIlaclar → _renderIlacSiniflari (accordion tree) | Ana UI değişikliği |
| `js/ui.js:2264-2329` | Modify: _drugEditForm/_drugSave/_drugDelete → drug_class RPC'leri | CRUD |
| `js/ui.js:2442-2459` | Modify: GRUPLAR hardcoded → dinamik | Stok panel |
| `js/ui.js:2010-2014` | Modify: KAT_MAP → drug_classes.kategori_id resolve | Stok form |
| `index.html:576` | Modify: tab label "İlaçlar" → "İlaç Sınıfları" | Tab adı |
| `js/api.js:234-283` | Modify: RPC_TABLES — yeni RPC'ler ekleme | Cache invalidation |
| `supabase/migrations/99999999999999_ground_truth.sql` | Modify: yeni tabloları ve RPC'leri yansıtma | Canonical referans |

---

### Task 1: Migration — Kategori Tutarsızlıkları ve Yeni Kategoriler

**Files:**
- Create: `supabase/migrations/20260530000001_ilac_kategori_fix.sql`

Bu migration 3 işi birden yapar: (1) "Diğer İlaçlar" → "Diğer İlaç" rename, "Mide Koruyucular" silme, (2) yeni kategoriler ekleme, (3) stok tablosundaki "Diger Ilac" → "Diğer İlaç" düzeltme, (4) drug_classes.drug_id → kategori_id FK değişikliği.

- [ ] **Step 1: Migration dosyasını oluştur**

```sql
-- 20260530000001_ilac_kategori_fix.sql
-- İlaç sınıflandırma refactor Faz 1: kategori düzeltmeleri + drug_classes FK

BEGIN;

-- ══ 1. Kategori Tutarsızlıkları ══

-- "Diğer İlaçlar" → "Diğer İlaç" rename
UPDATE public.stok_kategorileri SET ad = 'Diğer İlaç' WHERE ad = 'Diğer İlaçlar';

-- Stok tablosundaki tutarsız değerleri düzelt
UPDATE public.stok SET kategori = 'Diğer İlaç' WHERE kategori = 'Diger Ilac';

-- "Mide Koruyucular" → sil (GI İlaçlar ile değiştirilecek)
-- Önce bağlı stok varsa GI İlaçlar'a taşı
UPDATE public.stok SET kategori = 'GI İlaçlar' WHERE kategori = 'Mide Koruyucular';
DELETE FROM public.stok_kategorileri WHERE ad = 'Mide Koruyucular';

-- ══ 2. Yeni Kategoriler Ekle ══

INSERT INTO public.stok_kategorileri (ad, sira, tip) VALUES
  ('Metabolik', 14, 'ilac'),
  ('GI İlaçlar', 15, 'ilac'),
  ('Topikal', 16, 'ilac'),
  ('Anestezik / Sedatif', 17, 'ilac')
ON CONFLICT DO NOTHING;

-- ══ 3. drug_classes: drug_id → kategori_id FK ══

-- Yeni kolon ekle
ALTER TABLE public.drug_classes ADD COLUMN IF NOT EXISTS kategori_id UUID REFERENCES public.stok_kategorileri(id);

-- Backfill: group_name → stok_kategorileri eşleştirmesi
UPDATE public.drug_classes dc SET kategori_id = sk.id
FROM public.stok_kategorileri sk
WHERE sk.ad = CASE dc.group_name
  WHEN 'Antibiyotik' THEN 'Antibiyotik'
  WHEN 'NSAID' THEN 'NSAID'
  WHEN 'Hormon' THEN 'Hormon'
  WHEN 'Vitamin' THEN 'Vitamin'
  WHEN 'Antiparaziter' THEN 'Antiparaziter'
  WHEN 'Kortikosteroid' THEN 'Hormon'
  WHEN 'Metabolik' THEN 'Metabolik'
  WHEN 'Rumen' THEN 'GI İlaçlar'
  WHEN 'Elektrolit' THEN 'Metabolik'
  ELSE 'Diğer İlaç'
END;

-- Eski drug_id kolonunu kaldır
ALTER TABLE public.drug_classes DROP COLUMN IF EXISTS drug_id;

COMMIT;
```

- [ ] **Step 2: Migration'ı uygula**

```bash
cd /root/egesut-erp1
cat supabase/migrations/20260530000001_ilac_kategori_fix.sql | \
  # supabase_migrate tool ile uygula
```

Veya tools-bank MCP üzerinden:
```
mcp__tools-bank__supabase_migrate(sql="<migration içeriği>")
```

- [ ] **Step 3: Doğrulama sorguları çalıştır**

```
supabase_query(table="stok_kategorileri", select="ad,sira,tip", order="sira.asc")
```
Expected: 16 satır (eski 13 - 1 silinen + 4 yeni = 16). "Metabolik", "GI İlaçlar", "Topikal", "Anestezik / Sedatif" mevcut.

```
supabase_query(table="stok", filters="kategori=eq.Diger Ilac")
```
Expected: 0 satır (hepsi "Diğer İlaç" olmalı).

```
supabase_query(table="drug_classes", select="id,group_name,kategori_id", limit=5)
```
Expected: Tüm satırlarda kategori_id dolu, drug_id kolonu yok.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260530000001_ilac_kategori_fix.sql
git commit -m "migration: kategori tutarsızlıkları fix + yeni kategoriler + drug_classes FK"
```

---

### Task 2: Migration — Ders Kitabı Seed

**Files:**
- Create: `supabase/migrations/20260530000002_ilac_seed.sql`

Veteriner farmakoloji referansına göre 9 grup, ~35+ etken madde seed'i. Mevcut veriler korunur (ON CONFLICT DO NOTHING mantığı — group_name+class_name+active_ingredient unique combo ile kontrol).

- [ ] **Step 1: Önce mevcut drug_classes verilerini kontrol et**

```
supabase_query(table="drug_classes", select="group_name,class_name,active_ingredient", order="group_name.asc", limit=50)
```

Mevcut 29 kayıt. Hangileri seed'de var, hangileri ek gerekiyor not al.

- [ ] **Step 2: Unique constraint ekle ve seed migration dosyasını oluştur**

```sql
-- 20260530000002_ilac_seed.sql
-- Ders kitabı referans seed — veteriner farmakoloji

BEGIN;

-- Unique constraint: aynı group+class+ingredient tekrarı önle
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_drug_classes_combo') THEN
    ALTER TABLE public.drug_classes ADD CONSTRAINT uq_drug_classes_combo
      UNIQUE (group_name, class_name, active_ingredient);
  END IF;
END $$;

-- Seed — mevcut verilerle çakışanlar ON CONFLICT ile atlanır
-- Her INSERT'e kategori_id subquery ile ekleniyor

-- 1. Antimikrobiyaller (Antibiyotikler)
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Penisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Amoksisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Seftiofur', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tilmikosin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tulathromycin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Enrofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Marbofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Oksitetrasiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Doksisiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Aminoglikozidler', 'Gentamisin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Sulfonamidler', 'Trimetoprim-SMX', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 2. Anti-inflamatuar İlaçlar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Anti-inflamatuar İlaçlar', 'NSAID', 'Meloksikam', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
  ('Anti-inflamatuar İlaçlar', 'NSAID', 'Ketoprofen', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
  ('Anti-inflamatuar İlaçlar', 'NSAID', 'Flunixin', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
  ('Anti-inflamatuar İlaçlar', 'Kortikosteroidler', 'Deksametazon', (SELECT id FROM stok_kategorileri WHERE ad='Hormon'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 3. Hormonlar ve Üreme İlaçları
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Hormonlar ve Üreme İlaçları', 'Prostaglandinler', 'Dinoprost', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
  ('Hormonlar ve Üreme İlaçları', 'GnRH Agonistleri', 'Gonadorelin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
  ('Hormonlar ve Üreme İlaçları', 'Progestagenler', 'Progesteron', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
  ('Hormonlar ve Üreme İlaçları', 'Oksitosin', 'Oksitosin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 4. Antiparaziter İlaçlar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'İvermektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
  ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'Doramektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
  ('Antiparaziter İlaçlar', 'Benzimidazoller', 'Albendazol', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 5. Vitaminler ve Mineraller
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B1 (Tiamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B6 (Piridoksin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B12 (Siyanokobalamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B Kompleks', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'C Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'E Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'AD3E Kombinasyon', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Mineraller / İz Elementler', 'Selenyum', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 6. Metabolik / Sıvı Tedavi
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Metabolik / Sıvı Tedavi', 'Kalsiyum Preparatları', 'Kalsiyum Boroglukonat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Magnezyum', 'Magnezyum Sülfat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Glukoz %50', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Dekstroz %30', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'Oral Rehidrasyon Solüsyonu', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'IV Serum (İzotonik NaCl, Ringer Laktat)', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 7. Gastrointestinal İlaçlar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Gastrointestinal İlaçlar', 'Gastroprotektanlar', 'Sukralfat (Antepsin)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
  ('Gastrointestinal İlaçlar', 'Rumen Stimülanları', 'Rumen Stimülanı', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
  ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Saccharomyces (Maya)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
  ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Probiyotik Preparatları', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 8. Topikal / Harici İlaçlar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Topikal / Harici İlaçlar', 'Merhemler', 'İhtiyol (Kara Merhem)', (SELECT id FROM stok_kategorileri WHERE ad='Topikal'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 9. Anestezik / Sedatif
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Anestezik / Sedatif', 'Sedatifler', 'Ksilazin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
  ('Anestezik / Sedatif', 'Genel Anestezikler', 'Ketamin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
  ('Anestezik / Sedatif', 'Lokal Anestezikler', 'Lidokain', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- Mevcut eski group_name'leri yeni isimlere güncelle
-- (eski seed'den kalan kayıtlar — "Antibiyotik" → "Antimikrobiyaller (Antibiyotikler)" vb.)
UPDATE public.drug_classes SET group_name = 'Antimikrobiyaller (Antibiyotikler)' WHERE group_name = 'Antibiyotik';
UPDATE public.drug_classes SET group_name = 'Anti-inflamatuar İlaçlar', class_name = 'NSAID' WHERE group_name = 'NSAID';
UPDATE public.drug_classes SET group_name = 'Hormonlar ve Üreme İlaçları' WHERE group_name = 'Hormon';
UPDATE public.drug_classes SET group_name = 'Anti-inflamatuar İlaçlar', class_name = 'Kortikosteroidler' WHERE group_name = 'Kortikosteroid';
UPDATE public.drug_classes SET group_name = 'Antiparaziter İlaçlar', class_name = 'Makrosiklik Laktonlar' WHERE group_name = 'Antiparaziter' AND class_name = 'Makrosiklik';
UPDATE public.drug_classes SET group_name = 'Metabolik / Sıvı Tedavi' WHERE group_name = 'Metabolik';
UPDATE public.drug_classes SET group_name = 'Gastrointestinal İlaçlar', class_name = 'Rumen Stimülanları' WHERE group_name = 'Rumen';
UPDATE public.drug_classes SET group_name = 'Metabolik / Sıvı Tedavi', class_name = 'Elektrolitler' WHERE group_name = 'Elektrolit';

COMMIT;
```

**ÖNEMLİ:** Mevcut 29 kayıt eski group_name kullanıyor (örn. "Antibiyotik" vs yeni "Antimikrobiyaller (Antibiyotikler)"). Bu migration:
1. Önce yeni seed'i ekler (ON CONFLICT ile mevcut olanları atlar)
2. Sonra eski group_name'leri yeni karşılıklarına günceller

Bu sıra önemli çünkü ON CONFLICT unique constraint'e dayalı — eski isimlerle çakışma olmaz.

- [ ] **Step 3: Migration'ı uygula**

```
mcp__tools-bank__supabase_migrate(sql="<migration içeriği>")
```

- [ ] **Step 4: Doğrulama**

```
supabase_query(table="drug_classes", select="group_name,class_name,active_ingredient,kategori_id", order="group_name.asc", limit=50)
```
Expected: ~45-50 satır (29 mevcut + ~16-20 yeni). Tüm group_name'ler yeni formatta. Tüm kategori_id'ler dolu.

Duplicate kontrolü:
```sql
SELECT group_name, class_name, active_ingredient, COUNT(*)
FROM drug_classes
GROUP BY group_name, class_name, active_ingredient
HAVING COUNT(*) > 1;
```
Expected: 0 satır.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260530000002_ilac_seed.sql
git commit -m "migration: ders kitabı seed + eski group_name rename"
```

---

### Task 3: RPC'ler — drug_class CRUD + stok validate

**Files:**
- Create: `supabase/migrations/20260530000003_ilac_rpcler.sql`

4 yeni RPC: drug_class_ekle, drug_class_guncelle, drug_class_sil, drug_class_varsayilan_yukle.
2 mevcut RPC'ye validate ekleme: stok_ekle, stok_guncelle.

- [ ] **Step 1: RPC migration dosyasını oluştur**

```sql
-- 20260530000003_ilac_rpcler.sql
-- İlaç sınıflandırma CRUD RPC'leri + stok validate

BEGIN;

-- ══ 1. drug_class_ekle ══
CREATE OR REPLACE FUNCTION public.drug_class_ekle(
  p_group_name text,
  p_class_name text,
  p_active_ingredient text,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_group_name IS NULL OR p_group_name = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Grup adı zorunlu');
  END IF;
  IF p_active_ingredient IS NULL OR p_active_ingredient = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Etken madde adı zorunlu');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.drug_classes
    WHERE group_name = p_group_name
      AND COALESCE(class_name,'') = COALESCE(p_class_name,'')
      AND active_ingredient = p_active_ingredient
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kombinasyon zaten mevcut');
  END IF;

  v_id := gen_random_uuid();
  INSERT INTO public.drug_classes (id, group_name, class_name, active_ingredient, kategori_id)
  VALUES (v_id, p_group_name, NULLIF(p_class_name,''), p_active_ingredient, p_kategori_id);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mesaj', 'Etken madde eklendi');
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_ekle(text,text,text,uuid) TO anon, authenticated;

-- ══ 2. drug_class_guncelle ══
CREATE OR REPLACE FUNCTION public.drug_class_guncelle(
  p_id uuid,
  p_group_name text DEFAULT NULL,
  p_class_name text DEFAULT NULL,
  p_active_ingredient text DEFAULT NULL,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.drug_classes WHERE id = p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  UPDATE public.drug_classes SET
    group_name = COALESCE(NULLIF(p_group_name,''), group_name),
    class_name = COALESCE(p_class_name, class_name),
    active_ingredient = COALESCE(NULLIF(p_active_ingredient,''), active_ingredient),
    kategori_id = COALESCE(p_kategori_id, kategori_id)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'mesaj', 'Güncellendi');
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_guncelle(uuid,text,text,text,uuid) TO anon, authenticated;

-- ══ 3. drug_class_sil ══
CREATE OR REPLACE FUNCTION public.drug_class_sil(
  p_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.drug_products WHERE drug_class_id = p_id;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Bu etken maddeye bağlı ' || v_count || ' preparat var. Önce preparatları başka sınıfa taşıyın.');
  END IF;

  DELETE FROM public.drug_classes WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'mesaj', 'Silindi');
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_sil(uuid) TO anon, authenticated;

-- ══ 4. drug_class_varsayilan_yukle ══
CREATE OR REPLACE FUNCTION public.drug_class_varsayilan_yukle()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_before integer;
  v_after integer;
BEGIN
  SELECT COUNT(*) INTO v_before FROM public.drug_classes;

  -- Seed datayı tekrar ekle — mevcut olanlar unique constraint ile atlanır
  INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
  VALUES
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Penisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Amoksisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Seftiofur', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tilmikosin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tulathromycin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Enrofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Marbofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Oksitetrasiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Doksisiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Aminoglikozidler', 'Gentamisin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Sulfonamidler', 'Trimetoprim-SMX', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Meloksikam', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Ketoprofen', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Flunixin', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'Kortikosteroidler', 'Deksametazon', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Prostaglandinler', 'Dinoprost', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'GnRH Agonistleri', 'Gonadorelin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Progestagenler', 'Progesteron', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Oksitosin', 'Oksitosin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'İvermektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'Doramektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Benzimidazoller', 'Albendazol', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B1 (Tiamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B6 (Piridoksin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B12 (Siyanokobalamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B Kompleks', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'C Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'E Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'AD3E Kombinasyon', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Mineraller / İz Elementler', 'Selenyum', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Metabolik / Sıvı Tedavi', 'Kalsiyum Preparatları', 'Kalsiyum Boroglukonat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Magnezyum', 'Magnezyum Sülfat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Glukoz %50', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Dekstroz %30', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'Oral Rehidrasyon Solüsyonu', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'IV Serum (İzotonik NaCl, Ringer Laktat)', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Gastrointestinal İlaçlar', 'Gastroprotektanlar', 'Sukralfat (Antepsin)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Rumen Stimülanları', 'Rumen Stimülanı', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Saccharomyces (Maya)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Probiyotik Preparatları', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Topikal / Harici İlaçlar', 'Merhemler', 'İhtiyol (Kara Merhem)', (SELECT id FROM stok_kategorileri WHERE ad='Topikal')),
    ('Anestezik / Sedatif', 'Sedatifler', 'Ksilazin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Genel Anestezikler', 'Ketamin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Lokal Anestezikler', 'Lidokain', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif'))
  ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

  SELECT COUNT(*) INTO v_after FROM public.drug_classes;

  RETURN jsonb_build_object('ok', true, 'eklenen', v_after - v_before);
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_varsayilan_yukle() TO anon, authenticated;

-- ══ 5. stok_ekle — kategori validate ekle ══
CREATE OR REPLACE FUNCTION public.stok_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
BEGIN
  -- Kategori validate
  IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
  END IF;

  v_id := gen_random_uuid()::text;

  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', v_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', v_id,
      'veri', jsonb_build_object('urun_adi', p_urun_adi, 'kategori', p_kategori, 'birim', p_birim, 'baslangic_miktar', p_baslangic_miktar, 'esik', p_esik)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni stok: ' || p_urun_adi);

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stok_ekle(text, text, text, numeric, numeric) TO anon, authenticated;

-- ══ 6. stok_guncelle — kategori validate ekle ══
CREATE OR REPLACE FUNCTION public.stok_guncelle(
  p_stok_id text,
  p_urun_adi text DEFAULT NULL,
  p_kategori text DEFAULT NULL,
  p_birim text DEFAULT NULL,
  p_esik numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_onceki jsonb;
BEGIN
  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;

  -- Kategori validate (sadece değiştiriliyorsa)
  IF p_kategori IS NOT NULL AND p_kategori != '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
    END IF;
  END IF;

  v_onceki := row_to_json(v_stok)::jsonb;

  UPDATE public.stok SET
    urun_adi = COALESCE(NULLIF(p_urun_adi, ''), urun_adi),
    kategori = COALESCE(NULLIF(p_kategori, ''), kategori),
    birim    = COALESCE(NULLIF(p_birim, ''), birim),
    esik     = COALESCE(p_esik, esik)
  WHERE id = p_stok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_GUNCELLE', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', p_stok_id,
      'onceki', v_onceki,
      'sonraki', (SELECT row_to_json(stok)::jsonb FROM public.stok WHERE id = p_stok_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Stok güncellendi: ' || COALESCE(p_urun_adi, (SELECT urun_adi FROM public.stok WHERE id = p_stok_id)));

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stok_guncelle(text,text,text,text,numeric) TO anon, authenticated;

COMMIT;
```

- [ ] **Step 2: Migration'ı uygula**

```
mcp__tools-bank__supabase_migrate(sql="<migration içeriği>")
```

- [ ] **Step 3: RPC'leri test et**

```
supabase_rpc(function_name="drug_class_ekle", params='{"p_group_name":"Test","p_class_name":"TestClass","p_active_ingredient":"TestDrug"}')
```
Expected: `{"ok":true,"id":"...","mesaj":"Etken madde eklendi"}`

```
supabase_rpc(function_name="drug_class_ekle", params='{"p_group_name":"Test","p_class_name":"TestClass","p_active_ingredient":"TestDrug"}')
```
Expected: `{"ok":false,"mesaj":"Bu kombinasyon zaten mevcut"}`

Test kaydını temizle:
```sql
DELETE FROM drug_classes WHERE group_name='Test';
```

stok_ekle validate test:
```
supabase_rpc(function_name="stok_ekle", params='{"p_urun_adi":"Test","p_kategori":"OLMAYAN_KAT","p_birim":"ml","p_baslangic_miktar":0}')
```
Expected: `{"ok":false,"mesaj":"Geçersiz kategori: OLMAYAN_KAT"}`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260530000003_ilac_rpcler.sql
git commit -m "feat(rpc): drug_class CRUD + stok kategori validate"
```

---

### Task 4: api.js — RPC_TABLES güncelleme

**Files:**
- Modify: `js/api.js:234-283`

Yeni RPC'leri RPC_TABLES mapping'ine ekle — bu sayede rpcOptimistic çağrıldığında doğru IDB tablolar invalidate edilir.

- [ ] **Step 1: RPC_TABLES'a yeni satırlar ekle**

`js/api.js:283` civarında (mevcut son satırdan sonra) ekle:

```javascript
  // İlaç sınıflandırma RPC'leri
  drug_class_ekle:               ['drug_classes'],
  drug_class_guncelle:           ['drug_classes'],
  drug_class_sil:                ['drug_classes'],
  drug_class_varsayilan_yukle:   ['drug_classes'],
```

Mevcut `case_geri_al` satırından sonra, `};` kapanışından önce eklenecek.

- [ ] **Step 2: Doğrulama**

Dosyayı oku, RPC_TABLES objesinde yeni 4 satırın olduğunu doğrula.

- [ ] **Step 3: Commit**

```bash
git add js/api.js
git commit -m "feat(api): drug_class RPC'leri RPC_TABLES'a eklendi"
```

---

### Task 5: index.html — Tab label değişikliği

**Files:**
- Modify: `index.html:576`

- [ ] **Step 1: Tab label'ı değiştir**

`index.html:576` satırını değiştir:
```html
<!-- ESKİ -->
<button class="kat-btn" data-action="tanimlar-tab-ilaclar">💊 İlaçlar</button>
<!-- YENİ -->
<button class="kat-btn" data-action="tanimlar-tab-ilaclar">💊 İlaç Sınıfları</button>
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "ui: Tanımlar tab 'İlaçlar' → 'İlaç Sınıfları'"
```

---

### Task 6: UI — Tanımlar "İlaç Sınıfları" Accordion Tree

**Files:**
- Modify: `js/ui.js:2209-2329` — `_renderIlaclar` → accordion tree, `_drugEditForm/_drugSave/_drugDelete` → drug_class RPC'leri

Bu en büyük UI task'ı. `_renderIlaclar` fonksiyonu tamamen yeniden yazılacak — drugs tablosu yerine drug_classes'dan okuyacak, accordion tree gösterecek. Edit/Save/Delete fonksiyonları drug_class RPC'lerini kullanacak.

- [ ] **Step 1: _renderIlaclar → _renderIlacSiniflari**

`js/ui.js:2069` satırında routing'i güncelle:
```javascript
// ESKİ
else if(_tanimlarTab==='ilaclar') await _renderIlaclar(el);
// YENİ
else if(_tanimlarTab==='ilaclar') await _renderIlacSiniflari(el);
```

- [ ] **Step 2: Yeni _renderIlacSiniflari fonksiyonunu yaz**

`js/ui.js:2209-2262` arasındaki `_renderIlaclar` fonksiyonunu sil ve yerine:

```javascript
async function _renderIlacSiniflari(el){
  await pullTables(['drug_classes','drug_products','stok_kategorileri']);
  const allDC=await idbGetAll('drug_classes');
  const allDP=await idbGetAll('drug_products');
  const allKats=((await idbGetAll('stok_kategorileri'))||[]).filter(k=>k.tip==='ilac');

  if(!allDC.length){
    el.innerHTML='<div class="empty"><div class="empty-ico">💊</div>Henüz ilaç sınıfı tanımı yok</div>'+_tanimVarsayilanBtn('drug_classes');
    return;
  }

  const GRP_RENK={'Antimikrobiyaller (Antibiyotikler)':'#2196f3','Anti-inflamatuar İlaçlar':'#e91e63','Hormonlar ve Üreme İlaçları':'#9c27b0','Antiparaziter İlaçlar':'#ff9800','Vitaminler ve Mineraller':'#4caf50','Metabolik / Sıvı Tedavi':'#00bcd4','Gastrointestinal İlaçlar':'#795548','Topikal / Harici İlaçlar':'#607d8b','Anestezik / Sedatif':'#f44336'};

  // Grup → Alt Grup → Etken Madde ağacı
  const tree={};
  allDC.forEach(dc=>{
    const g=dc.group_name||'Diğer';
    const c=dc.class_name||'Genel';
    if(!tree[g]) tree[g]={};
    if(!tree[g][c]) tree[g][c]=[];
    tree[g][c].push(dc);
  });

  // Bağlı preparat sayısı (drug_products)
  const dpCount={};
  allDP.forEach(dp=>{dpCount[dp.drug_class_id]=(dpCount[dp.drug_class_id]||0)+1;});

  let html=_tanimSearchBar();
  const gruplar=Object.keys(tree).sort();

  gruplar.forEach(grp=>{
    const renk=GRP_RENK[grp]||'#607d8b';
    const altGruplar=tree[grp];
    const toplamMadde=Object.values(altGruplar).reduce((s,arr)=>s+arr.length,0);

    html+=`<div class="tanim-grup" style="margin-bottom:6px">
      <div onclick="this.nextElementSibling.style.display=this.nextElementSibling.style.display==='none'?'block':'none';this.querySelector('.tanim-chev').classList.toggle('tanim-chev-open')" style="display:flex;align-items:center;gap:8px;padding:9px 10px;background:${renk}15;border:1px solid ${renk}30;border-radius:8px;cursor:pointer;user-select:none">
        <span style="width:4px;height:22px;border-radius:2px;background:${renk};flex-shrink:0"></span>
        <span style="font-weight:800;font-size:.82rem;color:${renk};flex:1">${esc(grp)}</span>
        <span class="tanim-grup-count" style="background:var(--card3);color:var(--ink3);padding:1px 7px;border-radius:10px;font-size:.65rem;font-weight:700">${toplamMadde}</span>
        <button onclick="event.stopPropagation();_dcEditInline('group','${esc(grp)}',null)" style="padding:2px 6px;background:none;border:none;cursor:pointer;font-size:.7rem" title="Düzenle">✏️</button>
        <button onclick="event.stopPropagation();_dcDeleteGroup('${esc(grp)}')" style="padding:2px 6px;background:none;border:none;cursor:pointer;font-size:.7rem" title="Sil">🗑</button>
        <svg class="tanim-chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="${renk}" stroke-width="2.5" style="transition:transform .2s;flex-shrink:0"><path d="M6 9l6 6 6-6"/></svg>
      </div>
      <div style="display:none;padding:4px 0 0 0">`;

    Object.keys(altGruplar).sort().forEach(cls=>{
      const maddeler=altGruplar[cls];
      html+=`<div style="margin:4px 0 0 12px">
        <div onclick="const n=this.nextElementSibling;n.style.display=n.style.display==='none'?'block':'none';this.querySelector('.tanim-chev').classList.toggle('tanim-chev-open')" style="display:flex;align-items:center;gap:6px;padding:6px 8px;background:var(--card2);border-radius:6px;cursor:pointer;user-select:none">
          <span style="width:3px;height:16px;border-radius:2px;background:${renk}60;flex-shrink:0"></span>
          <span style="font-weight:700;font-size:.78rem;color:var(--ink);flex:1">${esc(cls)}</span>
          <span style="font-size:.6rem;color:var(--ink3)">${maddeler.length}</span>
          <button onclick="event.stopPropagation();_dcEditInline('class','${esc(grp)}','${esc(cls)}')" style="padding:2px 4px;background:none;border:none;cursor:pointer;font-size:.65rem" title="Düzenle">✏️</button>
          <button onclick="event.stopPropagation();_dcDeleteClass('${esc(grp)}','${esc(cls)}')" style="padding:2px 4px;background:none;border:none;cursor:pointer;font-size:.65rem" title="Sil">🗑</button>
          <svg class="tanim-chev" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--ink3)" stroke-width="2.5" style="transition:transform .2s;flex-shrink:0"><path d="M6 9l6 6 6-6"/></svg>
        </div>
        <div style="display:none;padding:2px 0 0 0">`;

      maddeler.forEach(dc=>{
        const dpBadge=dpCount[dc.id]?`<span style="background:rgba(78,154,42,.15);color:var(--green);padding:1px 5px;border-radius:4px;font-size:.58rem;font-weight:700">📦 ${dpCount[dc.id]}</span>`:'';
        html+=`<div class="tanimlar-card" data-search="${esc(dc.active_ingredient)} ${esc(grp)} ${esc(cls)}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${renk};border-radius:6px;padding:7px 10px;margin:3px 0 0 20px">
          <div style="display:flex;justify-content:space-between;align-items:center">
            <div>
              <span style="font-weight:700;font-size:.8rem;color:var(--ink)">${esc(dc.active_ingredient)}</span>
              ${dpBadge}
            </div>
            <div style="display:flex;gap:2px">
              <button onclick="_dcEditIngredient('${dc.id}')" style="padding:3px 6px;background:var(--card2);border:none;border-radius:5px;font-size:.65rem;cursor:pointer" title="Düzenle">✏️</button>
              <button onclick="_dcDeleteIngredient('${dc.id}')" style="padding:3px 6px;background:var(--card2);border:none;border-radius:5px;font-size:.65rem;cursor:pointer" title="Sil">🗑</button>
            </div>
          </div>
          <div id="tdf-dc-${dc.id}"></div>
        </div>`;
      });

      // + Etken Madde Ekle
      html+=`<button onclick="_dcAddIngredient('${esc(grp)}','${esc(cls)}')" style="display:block;width:calc(100% - 20px);margin:3px 0 0 20px;padding:6px;background:none;border:1px dashed var(--card3);border-radius:5px;color:var(--ink3);font-size:.7rem;cursor:pointer;text-align:left">＋ Etken Madde Ekle</button>`;

      html+=`</div></div>`;
    });

    // + Alt Grup Ekle
    html+=`<button onclick="_dcAddClass('${esc(grp)}')" style="display:block;width:calc(100% - 12px);margin:4px 0 0 12px;padding:6px;background:none;border:1px dashed var(--card3);border-radius:5px;color:var(--ink3);font-size:.7rem;cursor:pointer;text-align:left">＋ Alt Grup Ekle</button>`;

    html+=`</div></div>`;
  });

  // + Yeni Grup Ekle
  html+=`<button onclick="_dcAddGroup()" style="width:100%;padding:13px;background:rgba(78,154,42,.12);border:2px dashed rgba(78,154,42,.4);border-radius:10px;color:var(--green);font-size:.88rem;font-weight:800;cursor:pointer;margin-top:8px">＋ Yeni Grup Ekle</button>`;
  html+=_tanimVarsayilanBtn('drug_classes');
  el.innerHTML=html;
}
```

- [ ] **Step 3: Yeni CRUD fonksiyonlarını yaz**

`js/ui.js:2264-2329` arasındaki `_drugEditForm`, `_drugSave`, `_drugDelete` fonksiyonlarını sil ve yerine drug_class CRUD fonksiyonlarını yaz:

```javascript
// ── drug_class inline CRUD ──

async function _dcAddGroup(){
  const name=prompt('Yeni grup adı:');
  if(!name||!name.trim()) return;
  const res=await rpcOptimistic('drug_class_ekle',{p_group_name:name.trim(),p_class_name:'Genel',p_active_ingredient:'(tanımsız)'});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Grup eklendi');
  loadTanimlarPanel();
}

async function _dcAddClass(grp){
  const name=prompt('Yeni alt grup adı:');
  if(!name||!name.trim()) return;
  const res=await rpcOptimistic('drug_class_ekle',{p_group_name:grp,p_class_name:name.trim(),p_active_ingredient:'(tanımsız)'});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Alt grup eklendi');
  loadTanimlarPanel();
}

async function _dcAddIngredient(grp,cls){
  const name=prompt('Yeni etken madde adı:');
  if(!name||!name.trim()) return;
  const allKats=((await idbGetAll('stok_kategorileri'))||[]).filter(k=>k.tip==='ilac');
  const allDC=await idbGetAll('drug_classes');
  const sameGrp=allDC.find(dc=>dc.group_name===grp);
  const katId=sameGrp?sameGrp.kategori_id:null;
  const res=await rpcOptimistic('drug_class_ekle',{p_group_name:grp,p_class_name:cls,p_active_ingredient:name.trim(),p_kategori_id:katId});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Etken madde eklendi');
  loadTanimlarPanel();
}

async function _dcEditInline(level,grp,cls){
  if(level==='group'){
    const newName=prompt('Grup adını düzenle:',grp);
    if(!newName||!newName.trim()||newName.trim()===grp) return;
    const allDC=await idbGetAll('drug_classes');
    const targets=allDC.filter(dc=>dc.group_name===grp);
    for(const dc of targets){
      await rpcOptimistic('drug_class_guncelle',{p_id:dc.id,p_group_name:newName.trim()});
    }
    toast('Grup güncellendi');
    loadTanimlarPanel();
  } else if(level==='class'){
    const newName=prompt('Alt grup adını düzenle:',cls);
    if(!newName||!newName.trim()||newName.trim()===cls) return;
    const allDC=await idbGetAll('drug_classes');
    const targets=allDC.filter(dc=>dc.group_name===grp&&dc.class_name===cls);
    for(const dc of targets){
      await rpcOptimistic('drug_class_guncelle',{p_id:dc.id,p_class_name:newName.trim()});
    }
    toast('Alt grup güncellendi');
    loadTanimlarPanel();
  }
}

async function _dcEditIngredient(id){
  const allDC=await idbGetAll('drug_classes');
  const dc=allDC.find(x=>x.id===id);
  if(!dc) return;
  const newName=prompt('Etken madde adını düzenle:',dc.active_ingredient);
  if(!newName||!newName.trim()||newName.trim()===dc.active_ingredient) return;
  const res=await rpcOptimistic('drug_class_guncelle',{p_id:id,p_active_ingredient:newName.trim()});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Güncellendi');
  loadTanimlarPanel();
}

async function _dcDeleteGroup(grp){
  const allDC=await idbGetAll('drug_classes');
  const allDP=await idbGetAll('drug_products');
  const targets=allDC.filter(dc=>dc.group_name===grp);
  const linkedDP=allDP.filter(dp=>targets.some(dc=>dc.id===dp.drug_class_id));
  if(linkedDP.length){
    toast(`Bu grubun altında ${linkedDP.length} preparat bağlı. Önce preparatları taşıyın.`,'error');
    return;
  }
  const subCount=targets.length;
  if(!confirm(`"${grp}" grubu ve altındaki ${subCount} kayıt silinecek. Emin misiniz?`)) return;
  for(const dc of targets){
    await rpcOptimistic('drug_class_sil',{p_id:dc.id});
  }
  toast('Grup silindi');
  loadTanimlarPanel();
}

async function _dcDeleteClass(grp,cls){
  const allDC=await idbGetAll('drug_classes');
  const allDP=await idbGetAll('drug_products');
  const targets=allDC.filter(dc=>dc.group_name===grp&&dc.class_name===cls);
  const linkedDP=allDP.filter(dp=>targets.some(dc=>dc.id===dp.drug_class_id));
  if(linkedDP.length){
    toast(`Bu alt grupta ${linkedDP.length} preparat bağlı. Önce preparatları taşıyın.`,'error');
    return;
  }
  if(!confirm(`"${cls}" alt grubu ve altındaki ${targets.length} etken madde silinecek. Emin misiniz?`)) return;
  for(const dc of targets){
    await rpcOptimistic('drug_class_sil',{p_id:dc.id});
  }
  toast('Alt grup silindi');
  loadTanimlarPanel();
}

async function _dcDeleteIngredient(id){
  const allDP=await idbGetAll('drug_products');
  const linked=allDP.filter(dp=>dp.drug_class_id===id);
  if(linked.length){
    toast(`Bu etken maddeye ${linked.length} preparat bağlı. Önce preparatları taşıyın.`,'error');
    return;
  }
  if(!confirm('Bu etken maddeyi silmek istediğinize emin misiniz?')) return;
  const res=await rpcOptimistic('drug_class_sil',{p_id:id});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Silindi');
  loadTanimlarPanel();
}
```

- [ ] **Step 4: _tanimVarsayilan fonksiyonunu drug_classes desteği ile güncelle**

`js/ui.js:2200-2207` arasındaki `_tanimVarsayilan` fonksiyonunu güncelle:

```javascript
async function _tanimVarsayilan(tip){
  if(tip==='drug_classes'){
    // Matematik onay — varsayılana dön
    const a=Math.floor(Math.random()*10)+1;
    const b=Math.floor(Math.random()*10)+1;
    const ans=prompt(`Varsayılan sistem düzenine dönülecek. Özel sınıflarınız silinmeyecek, eksik varsayılanlar eklenecektir.\n\nDevam etmek için ${a} + ${b} = ? yazın:`);
    if(parseInt(ans)!==(a+b)){toast('Yanlış cevap — işlem iptal','warn');return;}
    const res=await rpcOptimistic('drug_class_varsayilan_yukle',{});
    if(res&&res.ok===false){toast(res.mesaj,'error');return;}
    toast(`${res.eklenen||0} yeni ilaç sınıfı eklendi`);
    loadTanimlarPanel();
    return;
  }
  const labels={diseases:'hastalık',drugs:'ilaç',kategoriler:'kategori'};
  if(!confirm(`Standart ${labels[tip]||tip} tanımları geri yüklenecek. Mevcut özel tanımlarınız silinmez. Devam?`)) return;
  const res=await rpcOptimistic('seed_defaults',{p_tip:tip});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast(`${res.eklenen||0} yeni ${labels[tip]} eklendi`);
  loadTanimlarPanel();
}
```

- [ ] **Step 5: Global scope'a yeni fonksiyonları ekle**

`js/ui.js`'de window'a expose edilen fonksiyonlar varsa (onclick handler'lar template literal'da kullanılıyor), `_dcAddGroup`, `_dcAddClass`, `_dcAddIngredient`, `_dcEditInline`, `_dcEditIngredient`, `_dcDeleteGroup`, `_dcDeleteClass`, `_dcDeleteIngredient` fonksiyonları dosya scope'unda tanımlandığı ve template literal'lardaki onclick'ler doğrudan fonksiyon adı kullandığı için çalışacaktır — ui.js zaten bu pattern'ı kullanıyor (window-scoped fonksiyonlar).

- [ ] **Step 6: Manuel test**

Tarayıcıda:
1. Tanımlar panelini aç
2. "İlaç Sınıfları" tab'ına tıkla
3. Accordion tree'nin doğru gösterildiğini kontrol et
4. Bir grubu aç → alt grupları gör → etken maddeleri gör
5. "＋ Etken Madde Ekle" → isim gir → kaydedildiğini doğrula
6. ✏️ ile bir etken madde düzenle
7. 🗑 ile bağlantısız bir etken madde sil
8. "🔄 Varsayılana Dön" → matematik sorusu → doğru cevapla → yeni seed eklenir

- [ ] **Step 7: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): Tanımlar İlaç Sınıfları accordion tree + CRUD"
```

---

### Task 7: UI — Stok Paneli GRUPLAR Dinamikleştirme

**Files:**
- Modify: `js/ui.js:2442-2459` — hardcoded GRUPLAR → dinamik

- [ ] **Step 1: GRUPLAR'ı dinamik oluşturacak şekilde değiştir**

`js/ui.js:2442-2459` arasını değiştir:

```javascript
  // Dinamik GRUPLAR — stok_kategorileri'nden üretilir
  const katlar=await idbGetAll('stok_kategorileri');
  const ilacKats=(katlar||[]).filter(k=>k.tip==='ilac').sort((a,b)=>(a.sira||0)-(b.sira||0));
  const GRUPLAR=[
    {baslik:'💊 Sağlık',alt:[
      {ad:'🐂 Sperma',         filtre:s=>s.kategori==='Sperma'},
      ...ilacKats.map(k=>({
        ad:'💊 '+k.ad,
        filtre:s=>s.kategori===k.ad
      })),
      {ad:'🔧 Sarf & Ekipman', filtre:s=>['Ekipman','Sarf','Diğer'].includes(s.kategori)},
    ]},
    {baslik:'💉 Aşılar',alt:[
      {ad:'💉 Aşı Ürünleri', filtre:s=>s.isVaccine||s.kategori==='Aşı'},
    ]},
    {baslik:'🐂 Tohumlama',alt:[
      {ad:'🐂 Tohumlama Ürünleri', filtre:s=>s.kategori==='Tohumlama'},
    ]},
    {baslik:'🌾 Yem',alt:[
      {ad:'🌾 Yem & Katkı', filtre:s=>s.kategori==='Yem'},
    ]},
  ];
```

**NOT:** Sperma emoji'si 💉 → 🐂 olarak değişti (spec kararı). Tohumlama da 🐂.

- [ ] **Step 2: pullTables çağrısına stok_kategorileri ekle**

`loadStokPanel` fonksiyonunun başında `pullTables` çağrısına `stok_kategorileri` eklenmeli. Bu fonksiyonun tam konumunu bul ve `pullTables(['stok', ...])` çağrısına ekle.

`js/ui.js`'de `loadStokPanel` fonksiyonunu bul (2442 civarında — GRUPLAR'ın hemen üstünde), `pullTables` çağrısında `'stok_kategorileri'` tablonun zaten olup olmadığını kontrol et; yoksa ekle.

- [ ] **Step 3: Manuel test**

1. Stok panelini aç
2. Yeni kategorilerin (Metabolik, GI İlaçlar, Topikal, Anestezik / Sedatif) görüntülendiğini doğrula
3. Sperma'nın 🐂 emoji'si ile göründüğünü doğrula
4. Aşı, Yem gruplarının çalıştığını doğrula
5. Eklenen yeni bir stok ürününün doğru grupta göründüğünü doğrula

- [ ] **Step 4: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): Stok GRUPLAR dinamik + emoji 🐂 sperma/tohumlama"
```

---

### Task 8: UI — KAT_MAP → drug_classes.kategori_id Resolve

**Files:**
- Modify: `js/ui.js:2010-2014` — stok ekleme formunda KAT_MAP hardcoded → drug_classes.kategori_id üzerinden resolve

- [ ] **Step 1: KAT_MAP'i kaldır ve kategori_id ile resolve et**

`js/ui.js:2010-2014` arasını değiştir:

```javascript
// ESKİ:
        const KAT_MAP = {Antibiyotik:'Antibiyotik',NSAID:'NSAID',Hormon:'Hormon',Vitamin:'Vitamin',Antiparaziter:'Antiparaziter'};
        sel.onchange = () => {
          const opt = sel.selectedOptions[0];
          if (katInp && opt) katInp.value = KAT_MAP[opt.dataset.group] || 'Diğer İlaç';
        };

// YENİ:
        const allKats = await idbGetAll('stok_kategorileri');
        sel.onchange = () => {
          const opt = sel.selectedOptions[0];
          if (!katInp || !opt || !opt.value) return;
          const dc = drugClasses.find(c => c.id === opt.value);
          if (dc && dc.kategori_id) {
            const kat = allKats.find(k => k.id === dc.kategori_id);
            if (kat) { katInp.value = kat.ad; return; }
          }
          katInp.value = 'Diğer İlaç';
        };
```

**NOT:** Bu fonksiyon `_stokTipSec` içinde ve zaten `async` — `await idbGetAll` çalışır.

- [ ] **Step 2: Doğrulama**

1. Stok panelinde "Yeni Ekle" → "İlaç" seç
2. Etken madde dropdown'ından bir antibiyotik seç → Kategori otomatik "Antibiyotik" olmalı
3. Hormon grubundan bir madde seç → Kategori otomatik "Hormon" olmalı
4. Yeni eklenen kategorileri (Metabolik, GI İlaçlar) kontrol et

- [ ] **Step 3: Commit**

```bash
git add js/ui.js
git commit -m "feat(ui): KAT_MAP hardcoded → drug_classes.kategori_id resolve"
```

---

### Task 9: Ground Truth Güncelleme

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

Ground truth dosyasına yeni yapıları yansıt: stok_kategorileri yeni satırlar, drug_classes yapısal değişiklik (kategori_id FK, drug_id kaldırıldı), yeni RPC'ler.

- [ ] **Step 1: Ground truth'a stok_kategorileri seed güncelle**

`99999999999999_ground_truth.sql` dosyasında `INSERT INTO public.stok_kategorileri` bölümünü bul ve yeni 4 kategoriyi ekle. "Diğer İlaçlar" → "Diğer İlaç" olarak güncelle. "Mide Koruyucular" satırını kaldır.

- [ ] **Step 2: drug_classes şemasını güncelle**

Ground truth'da drug_classes tablosu yoksa — drug_classes CREATE TABLE ve seed'i ekle:

```sql
-- drug_classes tablosu (eğer yoksa CREATE, varsa bu bölümü ground truth'a ekle)
CREATE TABLE IF NOT EXISTS public.drug_classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_name TEXT NOT NULL,
  class_name TEXT,
  active_ingredient TEXT NOT NULL,
  kategori_id UUID REFERENCES public.stok_kategorileri(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_drug_classes_combo UNIQUE (group_name, class_name, active_ingredient)
);
ALTER TABLE public.drug_classes ENABLE ROW LEVEL SECURITY;
-- RLS policies...
GRANT SELECT, INSERT, UPDATE, DELETE ON public.drug_classes TO anon, authenticated;
```

- [ ] **Step 3: Yeni RPC'leri ground truth'a ekle**

drug_class_ekle, drug_class_guncelle, drug_class_sil, drug_class_varsayilan_yukle fonksiyonlarını ekle. stok_ekle ve stok_guncelle validate versiyonlarını güncelle.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "docs(db): ground_truth — drug_classes FK, yeni kategoriler, CRUD RPC'leri"
```

---

### Task 10: Temizlik ve Son Kontroller

**Files:**
- Delete: `docs/brainstorm-ilac-tree-v2.md` (temp dosya)
- Delete: `docs/brainstorm-ilac-tree-vet-referans.md` (temp dosya)
- Delete: `docs/brainstorm-ilac-tree.md` (temp dosya)

- [ ] **Step 1: Temp dosyaları sil**

```bash
rm docs/brainstorm-ilac-tree-v2.md docs/brainstorm-ilac-tree-vet-referans.md docs/brainstorm-ilac-tree.md
```

- [ ] **Step 2: Tüm akışı test et**

End-to-end test planı:
1. **Stok paneli:** GRUPLAR dinamik mi? Yeni kategoriler (Metabolik, GI İlaçlar, Topikal, Anestezik/Sedatif) görünüyor mu?
2. **Stok ekleme:** İlaç seç → etken madde seç → kategori otomatik doluyor mu?
3. **Stok ekleme:** Geçersiz kategori → hata mesajı alınıyor mu?
4. **Tanımlar İlaç Sınıfları:** Accordion tree doğru gösteriliyor mu?
5. **Tanımlar CRUD:** Grup/alt grup/etken madde ekleme, düzenleme, silme çalışıyor mu?
6. **Silme koruması:** Bağlı preparat olan etken madde silinemiyor mu?
7. **Varsayılana Dön:** Matematik onay + seed ekleme çalışıyor mu?
8. **Emoji:** Sperma/tohumlama 🐂 görünüyor mu?

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: ilac siniflandirma refactor — temp dosya temizliği"
git push origin main
```
