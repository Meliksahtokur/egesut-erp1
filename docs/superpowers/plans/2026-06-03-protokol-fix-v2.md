# Protokol Uyarı Sistemi Fix v2 — Implementation Plan

> **For agentic workers:** Use `/skill:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix broken protokol uyarı sistemi — IDB crash, uuid=text error, duplicate alerts, missing integration with existing task modals, and add navigation between screens.

**Architecture:** Fix DB type mismatches and backfill data first (Tasks 1-3), then fix scanner SQL (Task 4), then refactor UI to integrate with existing modal system and add screen stack navigation (Tasks 5-8), finally sync ground_truth (Task 9).

**Tech Stack:** PostgreSQL (Supabase migrations), Vanilla JS (ui.js, api.js, app.js), IndexedDB

---

## Execution Batches

| Batch | Tasks | İçerik | Bağımlılık |
|-------|-------|--------|------------|
| **Batch 1** | Task 1-4 | DB fixes: IDB + migration + deploy + test | Yok — önce çalışır |
| **Batch 2** | Task 5-7 | UI: satır tıklama + popstate + güncelleme | Batch 1 tamamlanmalı |
| **Batch 3** | Task 9 | ground_truth sync | Batch 1-2 tamamlanmalı |

## Tools-Bank Araç Haritası

Bu planda kullanılacak tools-bank MCP araçları:

| Araç | Kullanım | Örnek |
|------|----------|-------|
| `file_read(path)` | Dosya oku — edit öncesi ZORUNLU | `file_read("/root/egesut-erp1/js/api.js")` |
| `file_write(path, content, patch?)` | Dosya yaz/patch | `file_write("/root/egesut-erp1/js/api.js", "...", true)` |
| `supabase_migrate(sql)` | SQL migration deploy (Management API) | `supabase_migrate("CREATE OR REPLACE FUNCTION...")` |
| `supabase_query(table, filters, select, limit)` | SELECT sorgusu — test/doğrulama | `supabase_query("protokol_dismiss", "", "*", 10)` |
| `supabase_rpc(function_name, params)` | RPC çağrısı — test | `supabase_rpc("protokol_eksik_tara", "{}")` |
| `memory_search(query)` | Bağlam ara (önceki kararlar/hatalar) | `memory_search("uuid text cast")` |
| `semantic_search(query)` | Kod arama (vektör) | `semantic_search("protokol ekranı bottom sheet")` |

### Referans Dosyalar (edit öncesi oku)

```
file_read("/root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql")
file_read("/root/egesut-erp1/.claude/rpc-reference.md")
file_read("/root/egesut-erp1/.claude/domain-rules.md")
```

### Commit Kuralı

Her commit sonrası: `cd /root/egesut-erp1 && git push origin main`

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `js/api.js:9-13` | IDB TABLES + DB_VER | Modify |
| `supabase/migrations/20260603000005_protokol_fix_v2.sql` | All DB fixes: uuid cast, backfill, scanner, indexes | Create |
| `js/ui.js:705-919` | Protokol ekranı + iş detay + aksiyon butonları | Modify |
| `js/app.js:100-118` | popstate handler — protokol bottom-sheet support | Modify |
| `supabase/migrations/99999999999999_ground_truth.sql` | Canonical reference sync | Modify |

---

### Task 1: IDB Store Fix

**Files:**
- Modify: `js/api.js:9-13`

**Tools:** `file_read` → `file_write`

- [ ] **Step 1: Dosyayı oku**

```
file_read("/root/egesut-erp1/js/api.js")
```

Satır 9-13 arasında `DB_VER` ve `TABLES` dizisini bul.

- [ ] **Step 2: Add `uygulama_log` to TABLES and bump DB_VER**

`js/api.js:9-13` — mevcut TABLES dizisine `'uygulama_log'` ekle ve `DB_VER` 20→21 yap:

```javascript
const DB_VER  = 21;
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','padoklar','grup_padok_eslem','hekimler','treatment_days','stok_kategorileri',
                  'uygulama_log'];
```

NOT: `protokol_dismiss` IDB'ye eklenmeyecek — sadece RPC/insert ile kullanılıyor, client-side cache'e gerek yok.

`file_write` ile `js/api.js` dosyasını güncelle. Sadece değişen satırları patch olarak gönder.

- [ ] **Step 3: Test — hayvan kartı açılıyor mu**

Tarayıcıyı aç → Dashboard → herhangi bir hayvanın adına tıkla → hayvan kartı açılmalı (IDB hatasız). Konsol'da `object store was not found` hatası OLMAMALI.

NOT: DB_VER artırıldığı için tarayıcı IDB'yi upgrade edecek. Eski versiyon kullanıcıları ilk açılışta auto-upgrade alır.

- [ ] **Step 4: Commit + Push**

```bash
cd /root/egesut-erp1 && git add js/api.js && git commit -m "fix: add uygulama_log to IDB TABLES, bump DB_VER to 21" && git push origin main
```

---

### Task 2: uuid=text Fix + Trigger Tip Kontrolü

**Files:**
- Create: `supabase/migrations/20260603000005_protokol_fix_v2.sql`

**Tools:** `file_read` (ground_truth referans) → `file_write` (migration oluştur) → `supabase_migrate` (deploy)

- [ ] **Step 1: Referans dosyayı oku**

```
file_read("/root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql")
```

`ileri_gebe_asi_tamamla` fonksiyonunu bul — satır ~6356-6410. `WHERE id = p_gorev_id::uuid` satırlarını not et.

- [ ] **Step 2: Create migration with uuid cast fixes**

`supabase/migrations/20260603000005_protokol_fix_v2.sql` dosyasını oluştur. Bu migration TÜM DB fix'lerini içerecek (Task 2-4 SQL'leri tek dosyada).

Önce `ileri_gebe_asi_tamamla` fonksiyonundaki `::uuid` cast hatasını düzelt. Sorun: `gorev_log.id` text ama fonksiyon `p_gorev_id::uuid` cast yapıp text ile karşılaştırıyor → `operator does not exist: uuid = text`.

`supabase/migrations/20260603000005_protokol_fix_v2.sql` dosyasının başına yaz:

```sql
-- Migration: Protokol Fix v2 — uuid cast, backfill, scanner, indexes
-- Sorunlar: ileri_gebe_asi_tamamla uuid=text, eksik backfill, scanner duplikasyon
BEGIN;

-- ============================================================
-- Fix 1: ileri_gebe_asi_tamamla — uuid cast kaldır
-- gorev_log.id TEXT, ::uuid cast text ile karşılaştırılamaz
-- ============================================================

CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(
  p_gorev_id   text,
  p_vaccine_id uuid,
  p_tarih      date    DEFAULT CURRENT_DATE,
  p_doz        numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_result  jsonb;
  v_rapel_id    uuid;
  v_rapel_tarih date;
  v_is_first    boolean;
BEGIN
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  SELECT public.add_vaccination(
    v_gorev.hayvan_id::text, p_vaccine_id, p_tarih, p_doz, 'GorevID:' || p_gorev_id
  ) INTO v_vax_result;

  IF (v_vax_result->>'ok')::boolean = false THEN
    RETURN v_vax_result;
  END IF;

  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id;

  v_is_first := v_gorev.aciklama ILIKE '%1. doz%';
  IF v_is_first THEN
    v_rapel_tarih := p_tarih + 21;
    v_rapel_id := gen_random_uuid();
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak)
    VALUES (
      v_rapel_id,
      v_gorev.hayvan_id,
      'ILERI_GEBE_ASI',
      '💉 Rota-Corona Aşısı (2. doz)',
      v_rapel_tarih,
      false,
      v_gorev.stok_id,
      v_gorev.miktar,
      NULL,
      'ILERI_GEBE'
    );
  END IF;

  v_rapel_tarih := COALESCE(v_rapel_tarih, NULL);
  RETURN jsonb_build_object(
    'ok', true,
    'mesaj', 'Aşı kaydedildi',
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;
```

DEĞİŞEN SATIRLAR (öncekiyle karşılaştırma):
- Satır `WHERE id = p_gorev_id::uuid` → `WHERE id = p_gorev_id` (2 yerde)
- Geri kalan fonksiyon AYNI — değişiklik sadece `::uuid` kaldırma

- [ ] **Step 3: Not — henüz DEPLOY ETME ve COMMIT ETME, Task 3-4 SQL'leri de aynı migration dosyasına eklenecek**

---

### Task 3: Backfill — Tamamlanmış Görevlere etken_kod + Eski Doğum Dismiss

**Files:**
- Modify: `supabase/migrations/20260603000005_protokol_fix_v2.sql` (Task 2'de oluşturuldu)

**Tools:** `file_read` → `file_write` (migration'a append) → `supabase_query` (doğrulama)

- [ ] **Step 1: Tamamlanmış görevlere etken_kod backfill SQL ekle**

`20260603000005_protokol_fix_v2.sql` dosyasına, `ileri_gebe_asi_tamamla` fonksiyonundan SONRA ekle:

```sql
-- ============================================================
-- Fix 2: Tamamlanmış görevlere etken_kod backfill
-- İlk migration sadece tamamlandi=false görevleri güncelledi
-- Scanner tamamlandi=true + etken_kod ile arar → eski tamamlanmış görevler invisible
-- ============================================================

UPDATE public.gorev_log SET etken_kod = 'OKSITOSIN'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%Oksitosin%';

UPDATE public.gorev_log SET etken_kod = 'PG'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%PG%'
  AND aciklama NOT ILIKE '%Ademin%';

UPDATE public.gorev_log SET etken_kod = 'ADEMIN'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND (aciklama ILIKE '%Ademin%' AND aciklama NOT ILIKE '%Yeldif%' AND aciklama NOT ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'E_VIT'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND (aciklama ILIKE '%Yeldif%' OR aciklama ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'KALSIYUM'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%Kalsiyum%';

UPDATE public.gorev_log SET etken_kod = 'ROTA'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%Rota%';
```

- [ ] **Step 2: Eski doğum dismiss backfill SQL ekle**

Aynı dosyaya devam et:

```sql
-- ============================================================
-- Fix 3: Eski doğum dismiss backfill
-- Son 4 buzağı (küpe 80,79,78,77) anneleri HARİÇ tüm eski doğumlar dismiss
-- Scanner bunları artık "eksik" göstermeyecek
-- ============================================================

-- Doğum protokol adımları dismiss
INSERT INTO public.protokol_dismiss (hayvan_id, etken_kod, protokol, neden)
SELECT DISTINCT d.anne_id, a.ek, 'DOGUM_PROTOKOL', 'Otomatik: migration öncesi doğum'
FROM public.dogum d
CROSS JOIN (VALUES
  ('OKSITOSIN'), ('ADEMIN'), ('KALSIYUM'), ('PG'), ('E_VIT')
) AS a(ek)
WHERE d.tarih >= CURRENT_DATE - 70
  AND d.tarih <= CURRENT_DATE
  AND d.yavru_kupe NOT IN ('80','79','78','77')
ON CONFLICT (hayvan_id, etken_kod, protokol) DO NOTHING;

-- Kızgınlık takibi dismiss (etken_kod 'MANUAL' olarak saklanır)
INSERT INTO public.protokol_dismiss (hayvan_id, etken_kod, protokol, neden)
SELECT DISTINCT d.anne_id, 'MANUAL', 'KIZGINLIK_TAKIP', 'Otomatik: migration öncesi doğum'
FROM public.dogum d
WHERE (CURRENT_DATE - d.tarih) BETWEEN 55 AND 75
  AND d.yavru_kupe NOT IN ('80','79','78','77')
ON CONFLICT (hayvan_id, etken_kod, protokol) DO NOTHING;
```

- [ ] **Step 3: Not — henüz DEPLOY ETME, Task 4 SQL'leri de aynı dosyaya eklenecek**

---

### Task 4: Scanner Düzeltmeleri — DISTINCT ON, E_VIT, Index'ler + TÜM SQL DEPLOY

**Files:**
- Modify: `supabase/migrations/20260603000005_protokol_fix_v2.sql` (devam)

**Tools:** `file_read` → `file_write` (append) → `supabase_migrate` (TÜM migration deploy) → `supabase_rpc` + `supabase_query` (test)

- [ ] **Step 1: Düzeltilmiş scanner fonksiyonunu ekle**

Aynı migration dosyasına ekle. Bu, `protokol_eksik_tara` fonksiyonunun düzeltilmiş versiyonudur.

3 değişiklik:
1. Bölüm A'da `DISTINCT ON (d.anne_id)` — ikiz doğum duplikasyonu engellenir
2. VALUES listesinden `(53, 'E_VIT', '53. Gün: Yeldif')` satırı kaldırıldı — sadece +54 kalır
3. Bölüm C kızgınlık aralığı 55-75 korunuyor (değişiklik YOK)

```sql
-- ============================================================
-- Fix 4: protokol_eksik_tara — DISTINCT ON + E_VIT tutarsızlığı
-- ============================================================

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
  -- DISTINCT ON: aynı anne için sadece en son doğumu al (ikiz doğum fix)
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
      (11, 'PG',        '11. Gün PG'),
      (25, 'PG',        '25. Gün PG'),
      (53, 'ADEMIN',    '53. Gün: Ademin'),
      (54, 'E_VIT',     '54. Gün: Yeldif')
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
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
      LIMIT 1;

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM uygulama_log u
        WHERE u.hayvan_id = v_rec.hayvan_id
          AND u.etken_kod = v_rec.ek
          AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM drug_administrations da
        JOIN treatment_days td ON td.id = da.treatment_day_id
        JOIN cases c ON c.id = td.case_id
        WHERE c.animal_id = v_rec.hayvan_id
          AND public._etken_kod_bul(da.stok_id, NULL) = v_rec.ek
          AND da.created_at::date BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
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
        'gecikme_gun', GREATEST(v_gecikme, 0),
        'durum', v_durum,
        'tamamlanma_tarihi', v_tamamlanma,
        'kapatan_ref', v_kapatan
      );
    END;
  END LOOP;

  -- ═══ B. İLERI GEBE PROTOKOL (240-265 gün) ═══
  -- (değişiklik yok, aynen korunuyor)
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

  -- ═══ C. KIZGINLIK TAKİBİ (55-75 gün — geniş aralık korunuyor) ═══
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

DEĞİŞİKLİKLER (önceki versiyonla karşılaştırma):
1. Bölüm A: `FROM public.dogum d` → `FROM (SELECT DISTINCT ON (anne_id) * FROM public.dogum ORDER BY anne_id, tarih DESC) d`
2. Bölüm A VALUES: `(53, 'E_VIT', '53. Gün: Yeldif')` satırı SİLİNDİ, `(54, 'E_VIT', '54. Gün: Yeldif')` KALDI
3. Bölüm C: aynı DISTINCT ON pattern eklendi

- [ ] **Step 2: Ek index'leri ekle**

Aynı dosyaya devam et:

```sql
-- ============================================================
-- Fix 5: Ek index'ler — scanner performansı
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dogum_anne_tarih
  ON public.dogum(anne_id, tarih DESC);

CREATE INDEX IF NOT EXISTS idx_tohumlama_hayvan_sonuc
  ON public.tohumlama(hayvan_id, sonuc, tarih);

COMMIT;
```

- [ ] **Step 3: Migration'ı Supabase'e deploy et**

Migration dosyasının TAMAMINI `supabase_migrate` ile deploy et:

```
file_read("/root/egesut-erp1/supabase/migrations/20260603000005_protokol_fix_v2.sql")
```

Dosya içeriğini oku, sonra:

```
supabase_migrate(sql="<dosyanın tam içeriği>")
```

**ÖNEMLİ:** `BEGIN;` ve `COMMIT;` satırlarını çıkar — `supabase_migrate` zaten transaction içinde çalışır.

- [ ] **Step 4: Test — scanner düzeltmeleri**

Scanner'ı çağır:
```
supabase_rpc("protokol_eksik_tara", "{}")
```

Kontrol et:
- 901 numaralı hayvan her adım için sadece 1 kere görünmeli (duplikasyon YOK)
- Eski doğumlar (küpe 80/79/78/77 HARİÇ) "eksik" olarak görünmemeli
- `+53 E_VIT` satırı artık yok, sadece `+54 E_VIT` var

Dismiss kayıtlarını doğrula:
```
supabase_query("protokol_dismiss", "neden=eq.Otomatik: migration öncesi doğum", "*", 10)
```
Sonuç > 0 satır olmalı.

Backfill'i doğrula:
```
supabase_query("gorev_log", "tamamlandi=eq.true,etken_kod=neq.null", "id,hayvan_id,etken_kod,aciklama", 10)
```

- [ ] **Step 5: Commit + Push**

```bash
cd /root/egesut-erp1 && git add supabase/migrations/20260603000005_protokol_fix_v2.sql && git commit -m "fix: uuid cast, etken_kod backfill, dismiss backfill, scanner DISTINCT ON" && git push origin main
```

---

### Task 5: UI — Protokol Ekranı Satır Tıklama + İş Detay Bottom-Sheet

**Files:**
- Modify: `js/ui.js:705-750` (`_showProtokolEkran` fonksiyonu)

**Tools:** `file_read` → `file_write`

Bu task protokol listesindeki satırları tıklanabilir yapar ve iş detay bottom-sheet'ini oluşturur.

- [ ] **Step 1: Dosyayı oku**

```
file_read("/root/egesut-erp1/js/ui.js")
```

`_showProtokolEkran` fonksiyonunu bul (satır ~705), `_satirHtml` alt fonksiyonunu bul (satır ~727-738).

- [ ] **Step 2: `_showProtokolEkran` satır HTML'ini güncelle**

`js/ui.js` dosyasında `_showProtokolEkran` fonksiyonundaki `_satirHtml` fonksiyonunu bul (satır ~727-738). Satırın tamamını tıklanabilir yap — butonlar hariç gövdeye tıklayınca `_showProtokolDetay` açılır.

`_satirHtml` fonksiyonunu şununla DEĞİŞTİR:

```javascript
  const _satirHtml = (d, i) => `<div class="arow" style="border-left:3px solid ${_renk(d)};margin-bottom:6px;padding:8px 10px;cursor:pointer" onclick="_showProtokolDetay('${d.hayvan_id}','${esc(d.protokol)}',${i})">
    <div style="flex:1">
      <div style="font-weight:700;font-size:.8rem">${_ikon(d)} ${esc(d.kupe_no||'?')} <span style="font-size:.6rem;opacity:.6">${esc(d.grup||'')}</span></div>
      <div style="font-size:.7rem;color:var(--ink3)">${esc(d.adim)} · ${_gun(d)}</div>
      <div style="font-size:.6rem;opacity:.5">${esc(d.protokol)}</div>
    </div>
    <div style="display:flex;gap:6px;align-items:center" onclick="event.stopPropagation()">
      ${d.durum !== 'tamamlandi' && d.etken_kod ? `<button onclick="_protokolUygula(${i})" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--blue);background:rgba(30,100,200,.1);color:var(--blue);cursor:pointer">💉 Uygula</button>` : ''}
      ${d.durum !== 'tamamlandi' ? `<button onclick="_protokolDismiss(${i})" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>` : ''}
      ${d.durum === 'tamamlandi' && d.kapatan_ref ? `<button onclick="_protokolGeriAl('${esc(d.kapatan_ref)}')" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer">↩ Geri Al</button>` : ''}
    </div>
  </div>`;
```

DEĞİŞİKLİKLER:
- Satır `<div class="arow">`'a `cursor:pointer` ve `onclick="_showProtokolDetay(...)` eklendi
- Buton container'a `onclick="event.stopPropagation()"` eklendi — butonlara tıklayınca detay açılmaz

- [ ] **Step 3: `_showProtokolDetay` fonksiyonunu ekle**

`js/ui.js` dosyasında `_showProtokolEkran` fonksiyonundan HEMEN SONRA (satır ~750'den sonra, `_ETKEN_FILTERE`'den ÖNCE) şu fonksiyonu ekle. `file_write` ile patch olarak ekle:

```javascript
function _showProtokolDetay(hayvanId, protokol, activeIdx){
  const data = window.__protokolUyarilar;
  if (!data) return;

  const items = data.filter(d => d.hayvan_id === hayvanId && d.protokol === protokol);
  if (!items.length) return;

  const d0 = items[0];
  const _renk = d => d.durum === 'eksik' ? 'var(--red2)' : d.durum === 'yaklasan' ? '#b8860b' : '#2e7d32';
  const _ikon = d => d.durum === 'eksik' ? '🔴' : d.durum === 'yaklasan' ? '🟡' : '✅';

  let box = document.getElementById('proto-detay-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'proto-detay-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:350;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) { box.remove(); history.back(); } };

  const _adimHtml = items.map((d, i) => {
    const globalIdx = data.indexOf(d);
    const tamamTarih = d.tamamlanma_tarihi ? fmtTarih(d.tamamlanma_tarihi) : '';
    const gecikme = d.durum === 'eksik' ? `<span style="color:var(--red2);font-weight:700">${d.gecikme_gun} gün gecikmiş</span>` :
                    d.durum === 'yaklasan' ? `<span style="color:#b8860b">${Math.abs(d.gecikme_gun||0)} gün kaldı</span>` :
                    `<span style="color:#2e7d32">${tamamTarih}</span>`;
    const butonlar = d.durum !== 'tamamlandi' && d.etken_kod
      ? `<button onclick="_protokolUygula(${globalIdx})" style="font-size:.6rem;font-weight:700;padding:3px 8px;border-radius:6px;border:1px solid var(--blue);background:rgba(30,100,200,.1);color:var(--blue);cursor:pointer">💉</button>
         <button onclick="_protokolDismiss(${globalIdx})" style="font-size:.6rem;padding:3px 6px;border-radius:6px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`
      : d.durum !== 'tamamlandi'
      ? `<button onclick="_protokolDismiss(${globalIdx})" style="font-size:.6rem;padding:3px 6px;border-radius:6px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`
      : d.kapatan_ref
      ? `<button onclick="_protokolGeriAl('${esc(d.kapatan_ref)}')" style="font-size:.6rem;padding:3px 8px;border-radius:6px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer">↩</button>`
      : '';

    return `<div style="display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:1px solid var(--card2)">
      <div style="font-size:1rem">${_ikon(d)}</div>
      <div style="flex:1">
        <div style="font-size:.78rem;font-weight:600">${esc(d.adim)}</div>
        <div style="font-size:.65rem;color:var(--ink3)">${fmtTarih(d.hedef_tarih)} · ${gecikme}</div>
      </div>
      <div style="display:flex;gap:4px">${butonlar}</div>
    </div>`;
  }).join('');

  const protokolLabel = protokol === 'DOGUM_PROTOKOL' ? 'Doğum Protokolü' :
                        protokol === 'ILERI_GEBE_PROTOKOL' ? 'İleri Gebe Protokolü' :
                        'Kızgınlık Takibi';

  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:75vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
      <div>
        <div style="font-weight:800;font-size:.95rem">
          <a href="javascript:void(0)" onclick="_protoDetayHayvanGit('${hayvanId}')" style="color:var(--blue);text-decoration:underline">${esc(d0.kupe_no||'?')}</a>
          <span style="font-size:.65rem;opacity:.6;margin-left:6px">${esc(d0.grup||'')}</span>
        </div>
        <div style="font-size:.72rem;color:var(--ink3);margin-top:2px">${protokolLabel}</div>
      </div>
      <button onclick="document.getElementById('proto-detay-bs')?.remove()" style="background:none;border:none;font-size:1.2rem;cursor:pointer;color:var(--ink3)">✕</button>
    </div>
    ${_adimHtml}
  </div>`;

  history.pushState({proto_detay:true}, '', '');
  document.body.appendChild(box);
}

function _protoDetayHayvanGit(hayvanId){
  const detayBs = document.getElementById('proto-detay-bs');
  if (detayBs) detayBs.style.display = 'none';
  const protokolBs = document.getElementById('protokol-bs');
  if (protokolBs) protokolBs.style.display = 'none';
  openDet(hayvanId);
}
```

- [ ] **Step 4: Commit + Push**

```bash
cd /root/egesut-erp1 && git add js/ui.js && git commit -m "feat: protokol satır tıklama → iş detay timeline bottom-sheet" && git push origin main
```

---

### Task 6: UI — Geri Tuşu (popstate) + State Koruma

**Files:**
- Modify: `js/app.js:100-118` (popstate handler)
- Modify: `js/ui.js` (`_showProtokolEkran` — pushState ekle)

**Tools:** `file_read` → `file_write`

- [ ] **Step 1: Dosyaları oku**

```
file_read("/root/egesut-erp1/js/app.js")
file_read("/root/egesut-erp1/js/ui.js")
```

`app.js` satır ~100-118: mevcut popstate handler'ı bul.
`ui.js`: `_showProtokolEkran` fonksiyonunda `document.body.appendChild(box)` satırını bul.

- [ ] **Step 2: popstate handler'a protokol bottom-sheet desteği ekle**

`js/app.js:100-118` — mevcut popstate handler'ın başına (sentinel kontrolünden SONRA, det kontrolünden ÖNCE) protokol kontrolleri ekle:

`js/app.js` dosyasında `window.addEventListener('popstate', e => {` bloğunun içinde, `if (e.state?.sentinel)` bloğundan SONRA, `const det = document.getElementById('det');` satırından ÖNCE şu bloğu ekle:

```javascript
  // Protokol iş detay bottom-sheet açıksa kapat, protokol ekranına dön
  const protoDetay = document.getElementById('proto-detay-bs');
  if (protoDetay && protoDetay.style.display !== 'none') {
    protoDetay.remove();
    // Protokol ekranı ve hayvan kartı tekrar göster
    const protokolBs = document.getElementById('protokol-bs');
    if (protokolBs) protokolBs.style.display = 'flex';
    return;
  }

  // Hayvan kartı açıksa ve protokol ekranı gizliyse — kartı kapat, protokol ekranlarını göster
  const det = document.getElementById('det');
  if (det?.classList.contains('on')) {
    closeDet();
    window._prevTaskId = null;
    const protokolBs2 = document.getElementById('protokol-bs');
    if (protokolBs2 && protokolBs2.style.display === 'none') {
      protokolBs2.style.display = 'flex';
      const protoDetay2 = document.getElementById('proto-detay-bs');
      if (protoDetay2) protoDetay2.style.display = 'flex';
    }
    return;
  }
```

Bu, mevcut det kontrolünün YERİNE geçer. Yani eski `const det = ...` bloğunu (satır ~112-118) sil ve yukarıdakiyle değiştir.

Mevcut silinen kod:
```javascript
  // Detay paneli açıksa önce onu kapat
  const det = document.getElementById('det');
  if (det?.classList.contains('on')) {
    closeDet();
    window._prevTaskId = null;
    return;
  }
```

- [ ] **Step 3: `_showProtokolEkran` fonksiyonuna history.pushState ekle**

`js/ui.js` dosyasında `_showProtokolEkran` fonksiyonunda, `document.body.appendChild(box);` satırından HEMEN ÖNCE şu satırı ekle:

```javascript
  history.pushState({protokol:true}, '', '');
```

- [ ] **Step 4: Test — ekran stack'i**

1. Dashboard → Zil ikonu → Protokol ekranı açılır
2. Bir satıra tıkla → İş detay bottom-sheet açılır (protokol ekranı arkada kalır)
3. Hayvan no'ya tıkla → Hayvan kartı açılır (iş detay + protokol gizlenir)
4. Android geri tuşu (veya tarayıcı back) → Hayvan kartı kapanır, iş detay + protokol tekrar görünür
5. Geri tuşu → İş detay kapanır, protokol ekranı kalır
6. Geri tuşu → Protokol ekranı kapanır, dashboard görünür

- [ ] **Step 5: Commit + Push**

```bash
cd /root/egesut-erp1 && git add js/app.js js/ui.js && git commit -m "feat: protokol ekran stack — geri tuşu ile state koruma" && git push origin main
```

---

### Task 7: UI — İşlem Sonrası Satır Güncelleme (Reload Yerine)

**Files:**
- Modify: `js/ui.js:805-826` (`_protokolUygulaKaydet`), `js/ui.js:828-845` (`_protokolDismiss`), `js/ui.js:847-865` (`_protokolGeriAl`)

**Tools:** `file_read` → `file_write`

Şu an işlem sonrası tüm ekranlar kapanıp `loadDash()` çağrılıyor. Bunun yerine sadece ilgili satır güncellenip ekranlar açık kalacak.

- [ ] **Step 1: Dosyayı oku**

```
file_read("/root/egesut-erp1/js/ui.js")
```

Üç fonksiyonu bul: `_protokolUygulaKaydet` (~805), `_protokolDismiss` (~828), `_protokolGeriAl` (~847).

- [ ] **Step 2: `_protokolUygulaKaydet` — işlem sonrası ekranları kapatma**

`js/ui.js` dosyasında `_protokolUygulaKaydet` fonksiyonundaki başarılı sonuç bloğunu (satır ~817-822) şununla DEĞİŞTİR:

Mevcut:
```javascript
    if (res?.ok) {
      toast('✅ Uygulama kaydedildi');
      document.getElementById('proto-mini')?.remove();
      document.getElementById('protokol-bs')?.remove();
      loadDash();
    }
```

Yeni:
```javascript
    if (res?.ok) {
      toast('✅ Uygulama kaydedildi');
      document.getElementById('proto-mini')?.remove();
      // Scanner'ı arka planda yenile, ekranlar açık kalsın
      try {
        const proto = await rpc('protokol_eksik_tara', {});
        window.__protokolUyarilar = Array.isArray(proto) ? proto : [];
        // Badge güncelle
        const aktif = window.__protokolUyarilar.filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
        const bb = document.getElementById('bellbadge');
        if (bb) {
          bb.textContent = aktif.length > 99 ? '99+' : aktif.length;
          bb.style.display = aktif.length > 0 ? 'flex' : 'none';
        }
      } catch(e) { console.warn('scanner refresh:', e.message); }
      // İş detay açıksa yenile
      const detayBs = document.getElementById('proto-detay-bs');
      if (detayBs) {
        detayBs.remove();
        const d = window.__protokolUyarilar[idx];
        if (d) _showProtokolDetay(d.hayvan_id, d.protokol, idx);
      }
      // Protokol listesini yenile
      const protokolBs = document.getElementById('protokol-bs');
      if (protokolBs) { protokolBs.remove(); _showProtokolEkran(); }
    }
```

- [ ] **Step 3: `_protokolDismiss` — işlem sonrası ekranları kapatma**

`js/ui.js` dosyasında `_protokolDismiss` fonksiyonundaki başarılı sonuç bloğunu (satır ~841-843) şununla DEĞİŞTİR:

Mevcut:
```javascript
    toast('Uyarı geçersiz kılındı');
    document.getElementById('protokol-bs')?.remove();
    loadDash();
```

Yeni:
```javascript
    toast('Uyarı geçersiz kılındı');
    try {
      const proto = await rpc('protokol_eksik_tara', {});
      window.__protokolUyarilar = Array.isArray(proto) ? proto : [];
      const aktif = window.__protokolUyarilar.filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
      const bb = document.getElementById('bellbadge');
      if (bb) {
        bb.textContent = aktif.length > 99 ? '99+' : aktif.length;
        bb.style.display = aktif.length > 0 ? 'flex' : 'none';
      }
    } catch(e) { console.warn('scanner refresh:', e.message); }
    const detayBs = document.getElementById('proto-detay-bs');
    if (detayBs) {
      detayBs.remove();
      const d2 = window.__protokolUyarilar.find(x => x.hayvan_id === d.hayvan_id && x.protokol === d.protokol);
      if (d2) _showProtokolDetay(d2.hayvan_id, d2.protokol, window.__protokolUyarilar.indexOf(d2));
    }
    const protokolBs = document.getElementById('protokol-bs');
    if (protokolBs) { protokolBs.remove(); _showProtokolEkran(); }
```

- [ ] **Step 4: `_protokolGeriAl` — işlem sonrası ekranları kapatma**

`js/ui.js` dosyasında `_protokolGeriAl` fonksiyonundaki başarılı sonuç bloğunu (satır ~854-857) şununla DEĞİŞTİR:

Mevcut:
```javascript
      if (res?.ok) {
        toast('İşlem geri alındı');
        document.getElementById('protokol-bs')?.remove();
        loadDash();
      }
```

Yeni:
```javascript
      if (res?.ok) {
        toast('İşlem geri alındı');
        try {
          const proto = await rpc('protokol_eksik_tara', {});
          window.__protokolUyarilar = Array.isArray(proto) ? proto : [];
          const aktif = window.__protokolUyarilar.filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
          const bb = document.getElementById('bellbadge');
          if (bb) {
            bb.textContent = aktif.length > 99 ? '99+' : aktif.length;
            bb.style.display = aktif.length > 0 ? 'flex' : 'none';
          }
        } catch(e) { console.warn('scanner refresh:', e.message); }
        const protokolBs = document.getElementById('protokol-bs');
        if (protokolBs) { protokolBs.remove(); _showProtokolEkran(); }
      }
```

- [ ] **Step 5: Test — işlem sonrası ekran durumu**

1. Protokol ekranı → bir satıra "Uygula" → Kaydet → toast görünür, ekranlar kapanmaz, liste güncellenir
2. Protokol ekranı → "✕" dismiss → toast görünür, liste güncellenir
3. Badge sayısı işlem sonrası güncellenir

- [ ] **Step 6: Commit + Push**

```bash
cd /root/egesut-erp1 && git add js/ui.js && git commit -m "fix: protokol işlem sonrası ekranları kapatma yerine yerinde güncelle" && git push origin main
```

---

### Task 8: UI — Kızgınlık Takibi Uygula Butonu Kaldır

**Files:**
- Modify: `js/ui.js:727-738` (satır HTML) ve `js/ui.js` içindeki `_showProtokolDetay`

Kızgınlık takibi (etken_kod=NULL) için "Uygula" butonu gösterilmemeli — bu zaten mevcut kodda doğru çalışıyor çünkü `d.etken_kod ? ... : ''` kontrolü var. Ancak iş detay'da da aynı kontrol olmalı.

- [ ] **Step 1: Doğrulama — mevcut davranış doğru mu**

`_satirHtml`'deki buton koşulunu kontrol et:
```javascript
${d.durum !== 'tamamlandi' && d.etken_kod ? `<button onclick="_protokolUygula...` : ''}
```

`d.etken_kod` NULL olduğunda (kızgınlık takibi) buton zaten gösterilmiyor. İş detay'daki (`_showProtokolDetay`) buton koşulu da aynı mantığı kullanıyor:
```javascript
const butonlar = d.durum !== 'tamamlandi' && d.etken_kod
```

Bu zaten doğru. Ek değişiklik gerekmiyor.

- [ ] **Step 2: Commit — bu task zaten tamamlandı, skip**

Ek commit gerekmiyor — Task 5'teki `_showProtokolDetay` kodu zaten doğru koşulu içeriyor.

---

### Task 9: ground_truth.sql Sync

**Files:**
- Modify: `supabase/migrations/99999999999999_ground_truth.sql`

**Tools:** `file_read` → `file_write`

- [ ] **Step 1: ground_truth dosyasını oku**

```
file_read("/root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql")
```

Büyük dosya — ilgili fonksiyonları bul: `ileri_gebe_asi_tamamla` (~satır 6356), `protokol_eksik_tara`.

- [ ] **Step 2: `ileri_gebe_asi_tamamla` fonksiyonunu güncelle**

`supabase/migrations/99999999999999_ground_truth.sql` dosyasında `ileri_gebe_asi_tamamla` fonksiyonunu bul (satır ~6356). İki yerde `p_gorev_id::uuid` → `p_gorev_id` olarak değiştir:

Satır ~6371:
```sql
-- ÖNCE:
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
-- SONRA:
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id;
```

Satır ~6391:
```sql
-- ÖNCE:
  UPDATE gorev_log SET tamamlandi = true, tamamlanma_tarihi = now() WHERE id = p_gorev_id::uuid;
-- SONRA:
  UPDATE gorev_log SET tamamlandi = true, tamamlanma_tarihi = now() WHERE id = p_gorev_id;
```

- [ ] **Step 3: `protokol_eksik_tara` fonksiyonunu güncelle**

ground_truth.sql dosyasında mevcut `protokol_eksik_tara` fonksiyonunu bul. Task 4'teki düzeltilmiş versiyon ile DEĞİŞTİR (DISTINCT ON + E_VIT fix). Bu fonksiyon zaten ground_truth'a eklenmiş olabilir — eğer öyleyse sadece DISTINCT ON ve VALUES değişikliğini yap.

Eğer fonksiyon ground_truth'ta yoksa, Task 4'teki tam fonksiyon kodunu scanner bölümüne ekle.

- [ ] **Step 4: Doğrulama — diğer yeni objeler ground_truth'ta var mı**

`supabase/migrations/99999999999999_ground_truth.sql` dosyasında şunların mevcut olduğunu doğrula (önceki migration'lar eklemişse):

- `uygulama_log` tablo tanımı (satır ~67-72 civarı) ✓
- `protokol_dismiss` tablo tanımı ✓
- `_etken_kod_bul` fonksiyonu ✓
- `_gorev_dinle` fonksiyonu ✓
- `hizli_uygulama` + `hizli_uygulama_geri_al` RPC'ler ✓
- `fn_dinle_vaccination` + `fn_dinle_uygulama` + `fn_dinle_drug_admin` trigger fonksiyonları ✓
- `dogum_kaydet` güncel (9 anne görevi + etken_kod) ✓
- `fn_gebe_gorev_yarat` güncel (etken_kod'lu) ✓
- `gorev_log` tablosunda `etken_kod text`, `kapatan_ref text` kolonları ✓

Eksik olan varsa ekle. Fazla olan (eski versiyon duplike fonksiyonlar) varsa son versiyonu bırak, öncekini sil.

- [ ] **Step 5: Commit + Push**

```bash
cd /root/egesut-erp1 && git add supabase/migrations/99999999999999_ground_truth.sql && git commit -m "fix: ground_truth sync — uuid cast fix, scanner DISTINCT ON, tüm yeni objeler" && git push origin main
```

---

## Self-Review Checklist

**Spec coverage:**
- §1.1 IDB Store → Task 1 ✓
- §1.2 uuid=text → Task 2 ✓
- §1.3 Duplike doğum → Task 4 (DISTINCT ON) ✓
- §1.4 Eski doğum dismiss → Task 3 ✓
- §1.5 Tamamlanmış görevlere etken_kod → Task 3 ✓
- §2.1 Ekran stack → Task 6 ✓
- §2.2 Satır tıklama + iş detay → Task 5 ✓
- §2.3 Aksiyon butonları → Task 5 (detay butonları) + mevcut _protokolUygula (stok filtreli, zaten çalışıyor) ✓
- §2.4 Hayvan kartı navigasyonu → Task 5 (`_protoDetayHayvanGit`) + Task 6 (popstate) ✓
- §3.1 E_VIT tutarsızlığı → Task 4 ✓
- §3.2 Stok ön-filtreleme → Zaten uygulanmış (ui.js:752-775, `_ETKEN_FILTERE` + filtreli stok listesi) ✓
- §3.3 Ek index'ler → Task 4 ✓
- §3.4 Kızgınlık aralığı → Değişiklik yok (korunuyor) ✓
- §4 ground_truth sync → Task 9 ✓

**Placeholder scan:** TBD/TODO yok. Tüm kod blokları tam.

**Type consistency:** `_showProtokolDetay` ve `_protoDetayHayvanGit` aynı isim her yerde. `proto-detay-bs` element ID tutarlı. `window.__protokolUyarilar` mevcut pattern korunuyor.
