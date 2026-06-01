# TEDAVI_GUN Görev UX — Backend Plan

## Durum: ✅ Tamamlandı (2026-05-28)

**Uygulayan:** DeepSeek (executing-plans skill)
**Review:** Sub-agent (deepseek-chat) — APPROVED

### Commits
- `15261b8` — feat(rpc): treatment_day_tamamla stok iade (uygulanmadi_ids), add_treatment_day planned_time, case_plan_notu_guncelle
- `9ddc169` — docs(db): ground_truth + rpc-reference sync — tedavi_gun_ux

### Review Notları
- `treatment_day_tamamla`'da `UPDATE ... RETURNING stok_id` ile iki sorgu bire indirildi
- `islem_log` stok iadesi ve `case_plan_notu_guncelle` için audit trail ileride eklenebilir
- `stok_hareket` eşleştirmede `referans_tipi/referans_id` yerine `notlar` alanı kullanılıyor (mevcut desenle tutarlı)
- Tüm RPC'ler geriye uyumlu (DEFAULT parametreler)

> Topoloji: Hierarchical | 5 task | 1 paralel blok (Task 2+3+4)
> Model: deepseek-chat (flash) — aksi belirtilmedi
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** TEDAVI_GUN görevi için ilaç bazlı uygulandı/uygulanmadı seçimi, uygulayıcı notu, stok iadesi ve saat bazlı sıralama altyapısı.

**Etkilenen dosyalar:**
- `supabase/migrations/20260528000001_tedavi_gun_ux.sql` (yeni)
- `supabase/migrations/99999999999999_ground_truth.sql` (sync)
- `.claude/rpc-reference.md` (güncelle)

---

## Başlamadan Önce

Sırayla oku:

```bash
# Sadece ilgili bölümleri oku (cases, treatment_days, drug_administrations, RPC'ler)
grep -n "CREATE TABLE.*cases\|CREATE TABLE.*treatment_days\|CREATE TABLE.*drug_admin\|treatment_day_tamamla\|add_treatment_day\|case_plan_notu" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | head -30

cat /root/egesut-erp1/.claude/rpc-reference.md
```

Mevcut imzalar (referans):
- `add_treatment_day(p_case_id uuid, p_date date)` → treatment_days + gorev_log oluşturur
- `treatment_day_tamamla(p_day_id uuid, p_not text DEFAULT NULL)` → sequential check + tamamlandi=true

Stok ledger kuralı: `stok_hareket.miktar pozitif = kullanım`. İade = `stok_hareket.iptal = true` (mevcut satırı iptal et, yeni satır ekleme).

Net olmayan şey varsa devam etmeden önce sor.

---

## Task 1 — Migration: Yeni Kolonlar

**Uygulama:**

`supabase_migrate` ile şu SQL'i deploy et:

```sql
-- ══════════════════════════════════════════════════════
-- Migration: 20260528000001_tedavi_gun_ux
-- TEDAVI_GUN UX: plan notu, saat, uygulanmadı kolonları
-- ══════════════════════════════════════════════════════

-- 1. cases.plan_notu — tüm tedavi planını kapsayan master planlayıcı notu
--    Her TEDAVI_GUN görevinde gösterilir (UI okur, görev modalında readonly)
ALTER TABLE public.cases
  ADD COLUMN IF NOT EXISTS plan_notu TEXT;

-- 2. treatment_days.planned_time — tedavi saati (sıralama için)
--    add_treatment_day RPC ile set edilir. Görev kartında ve dashboardda gösterilir.
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS planned_time TIME;

-- 3. drug_administrations.uygulanmadi — uygulayıcı bu ilacı atladıysa TRUE
--    TRUE olursa treatment_day_tamamla stok_hareket'i iptal eder (iade).
ALTER TABLE public.drug_administrations
  ADD COLUMN IF NOT EXISTS uygulanmadi BOOLEAN DEFAULT FALSE;
```

**Doğrulama:**
```
supabase_query({table: "cases", select: "id,plan_notu", limit: 1})
supabase_query({table: "treatment_days", select: "id,planned_time", limit: 1})
supabase_query({table: "drug_administrations", select: "id,uygulanmadi", limit: 1})
```
3 sorgu da hata vermeden dönmeli.

**Commit:**
```bash
git add supabase/migrations/20260528000001_tedavi_gun_ux.sql
git commit -m "feat(db): cases.plan_notu, treatment_days.planned_time, drug_administrations.uygulanmadi"
```

**Checkpoint:**
```
memory_add({content: "Task 1 tamamlandı: 3 yeni kolon — cases.plan_notu, treatment_days.planned_time, drug_administrations.uygulanmadi", category: "code_change", priority: "low", tags: "tedavi,migration"})
```

---

## Task 2 + 3 + 4 — RPC Güncellemeleri (Task 1 bittikten sonra)

> Tek migration dosyasına (20260528000001_tedavi_gun_ux.sql) ek olarak ya da yeni dosya olarak yaz.
> 3 bağımsız fonksiyon — sıralı yaz, birbirini etkilemiyor.

---

### Task 2 — `treatment_day_tamamla` güncelle

Mevcut imza bozulmadan yeni parametre eklenir (DEFAULT olduğu için geriye dönük uyumlu).

**Yeni imza:**
```sql
treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'
)
```

**Uygulama — tam fonksiyon:**

```sql
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text);
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);

CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_day       public.treatment_days%ROWTYPE;
  v_onceki    boolean;
  v_admin_id  uuid;
  v_stok_id   text;
BEGIN
  -- Mevcut logic (değişmedi) --
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;

  IF v_day.tamamlandi THEN
    RAISE EXCEPTION 'Bu tedavi günü zaten tamamlandı';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id
      AND day_no  < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;

  IF v_onceki THEN
    RAISE EXCEPTION 'Önceki tedavi günleri tamamlanmadan bu gün tamamlanamaz';
  END IF;

  UPDATE public.treatment_days
  SET tamamlandi        = true,
      tamamlanma_tarihi = now(),
      tamamlanma_notu   = p_not
  WHERE id = p_day_id;

  -- YENİ: Uygulanmayan ilaçlar — uygulanmadi=true + stok iadesi --
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      -- İlacı uygulanmadı olarak işaretle
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id;  -- güvenlik: sadece bu güne ait

      -- Stok_id'yi al
      SELECT stok_id INTO v_stok_id
      FROM public.drug_administrations
      WHERE id = v_admin_id;

      -- Stok hareketi varsa iptal et (iade)
      IF v_stok_id IS NOT NULL THEN
        UPDATE public.stok_hareket
        SET iptal = true
        WHERE notlar = 'drug_admin:' || v_admin_id::text
          AND iptal = false;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla(uuid, text, uuid[]) TO anon, authenticated;
```

**Doğrulama:**
```
-- İmzayı kontrol et
supabase_rpc({function_name: "treatment_day_tamamla", params: "{\"p_day_id\": \"00000000-0000-0000-0000-000000000000\"}"})
-- "Tedavi günü bulunamadı" hatası gelmeli (fonksiyon çalışıyor demek)
```

---

### Task 3 — `add_treatment_day` güncelle

**Yeni imza:**
```sql
add_treatment_day(
  p_case_id     uuid,
  p_date        date,
  p_planned_time time DEFAULT NULL
)
```

**Değişen satırlar (tam fonksiyon yazmana gerek yok, sadece farkları uygula):**

1. `DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date);` satırını koru, yeni imzayla ekle.

2. `INSERT INTO public.treatment_days(...)` satırına `planned_time` ekle:
```sql
INSERT INTO public.treatment_days(id, case_id, day_no, treatment_date, tamamlandi, tamamlanma_tarihi, planned_time)
VALUES (
  gen_random_uuid(), p_case_id, v_day_no, p_date,
  v_gecmis,
  CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
  p_planned_time
)
```

3. `jsonb_build_object` içinde `aciklama`'ya `planned_time` ekle:
```sql
jsonb_build_object(
  'day_id',       v_day_id,
  'gun_no',       v_day_no,
  'label',        'Gün ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY'),
  'planned_time', COALESCE(p_planned_time::text, '')
)::text
```

4. GRANT satırını yeni imzayla güncelle:
```sql
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date);
-- ... fonksiyon body ...
GRANT EXECUTE ON FUNCTION public.add_treatment_day(uuid, date, time) TO anon, authenticated;
```

**Doğrulama:**
```
supabase_query({table: "treatment_days", select: "id,planned_time,treatment_date", limit: 3, order: "created_at.desc"})
```
Mevcut kayıtlarda `planned_time` NULL olmalı (geriye uyumlu).

---

### Task 4 — `case_plan_notu_guncelle` (yeni RPC)

```sql
CREATE OR REPLACE FUNCTION public.case_plan_notu_guncelle(
  p_case_id   uuid,
  p_plan_notu text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.cases
  SET plan_notu = p_plan_notu
  WHERE id = p_case_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vaka bulunamadı: %', p_case_id;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.case_plan_notu_guncelle(uuid, text) TO anon, authenticated;
```

**Doğrulama:**
```
-- Var olan bir case_id ile test et
supabase_query({table: "cases", select: "id", limit: 1})
-- Dönen id ile:
supabase_rpc({function_name: "case_plan_notu_guncelle", params: "{\"p_case_id\": \"[id]\", \"p_plan_notu\": \"Test notu\"}"})
-- Ardından:
supabase_query({table: "cases", filters: "id=eq.[id]", select: "plan_notu", limit: 1})
-- "Test notu" gelmeli, sonra geri al:
supabase_rpc({function_name: "case_plan_notu_guncelle", params: "{\"p_case_id\": \"[id]\", \"p_plan_notu\": null}"})
```

**Commit (Task 2+3+4 sonrası):**
```bash
git add supabase/migrations/
git commit -m "feat(rpc): treatment_day_tamamla stok iade (uygulanmadi_ids), add_treatment_day planned_time, case_plan_notu_guncelle"
```

**Checkpoint:**
```
memory_add({content: "Task 2+3+4 tamamlandı: treatment_day_tamamla p_uygulanmadi_ids[] aldı (stok_hareket.iptal=true), add_treatment_day p_planned_time aldı (gorev_log aciklama JSON'a eklendi), case_plan_notu_guncelle yeni RPC", category: "code_change", priority: "medium", tags: "tedavi,rpc,stok-iade"})
```

---

## Task 5 — ground_truth.sql + rpc-reference.md Güncelle

### ground_truth.sql

`cases` tablosu tanımına `plan_notu TEXT` ekle:
```sql
CREATE TABLE IF NOT EXISTS public.cases (
  ...
  notes       text,
  plan_notu   text,   -- ← ekle
  ...
```

`treatment_days` tablosu tanımına `planned_time TIME` ekle:
```sql
-- done tracking bloğunun altına ekle:
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS planned_time TIME;
```

`drug_administrations` tablosu tanımına `uygulanmadi BOOLEAN DEFAULT FALSE` ekle:
```sql
CREATE TABLE IF NOT EXISTS public.drug_administrations (
  ...
  notes             text,
  uygulanmadi       boolean DEFAULT false,  -- ← ekle
  created_at        timestamptz DEFAULT now(),
  ...
```

`treatment_day_tamamla` ve `add_treatment_day` fonksiyonlarını yeni imzalarla güncelle.

`case_plan_notu_guncelle` RPC'yi ekle (GRANT ile birlikte).

### rpc-reference.md

Şu satırları güncelle/ekle:
```
treatment_day_tamamla(p_day_id, p_not?, p_uygulanmadi_ids uuid[]?) → sequential check + tamamlandi + stok iade
add_treatment_day(p_case_id, p_date, p_planned_time time?) → treatment_days + gorev_log[TEDAVI_GUN]
case_plan_notu_guncelle(p_case_id, p_plan_notu) → cases.plan_notu güncelle
```

**Commit:**
```bash
git add supabase/migrations/99999999999999_ground_truth.sql .claude/rpc-reference.md
git commit -m "docs(db): ground_truth + rpc-reference sync — tedavi_gun_ux"
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "TEDAVI_GUN UX backend tamamlandı: (1) cases.plan_notu — master planlayıcı notu, her görevde görünür; (2) treatment_days.planned_time — saat bazlı görev sıralama; (3) drug_administrations.uygulanmadi — atlanmış ilaç; (4) treatment_day_tamamla p_uygulanmadi_ids[] ile stok iade (stok_hareket.iptal=true, NOT yeni satır); (5) case_plan_notu_guncelle yeni RPC. UI bunu kullanacak: gorev modal ilaç listesi, uygulayici_notu=tamamlanma_notu.",
  category: "code_change",
  priority: "medium",
  tags: "tedavi,gorev,stok-iade,plan,rpc"
})
```
