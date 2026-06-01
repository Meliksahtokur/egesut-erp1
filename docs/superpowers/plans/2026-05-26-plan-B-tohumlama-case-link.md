# Tohumlama–Tedavi Bağlantı Altyapısı — Plan B

> Topoloji: Hierarchical | 4 task | 0 paralel blok
> Model: deepseek-chat (flash)
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** `tohumlama` tablosuna `case_id` kolonu eklenir; tohumlama yapılırken bağlı kızgınlığın case'i varsa trigger bu case'e otomatik not düşer; yeni `kizginlik_vaka_ac` RPC kızgınlık bağlamından case açmayı ve çapraz bağlantı kurmayı sağlar.

**Etkilenen dosyalar:**
- Yeni migration: `supabase/migrations/20260526000002_tohumlama_case_link.sql`
- `supabase/migrations/99999999999999_ground_truth.sql`

**Bağımlılık:** Plan-A tamamlanmış olmalı (kizginlik_log.sonuc kolonu mevcut).

---

## Başlamadan Önce

Sırayla oku:
```bash
# 1. tohumlama tablosunun mevcut kolonları
sed -n '76,84p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
sed -n '207,214p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql

# 2. Kızgınlık kapat trigger'ı (varsa)
grep -n "_tohumlama_kizginlik_kapat\|kizginlik.*cozuldu\|cozuldu.*true" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | head -20

# 3. kizginlik_tedavi_baglanti_kur mevcut RPC
grep -n "kizginlik_tedavi_baglanti_kur" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql

# 4. cases tablosu yapısı
grep -n "CREATE TABLE.*cases\|ALTER TABLE.*cases" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | head -10

# 5. rpc-reference.md
cat /root/egesut-erp1/.claude/rpc-reference.md
```

Trigger adını ve cases tablosu yapısını doğruladıktan sonra devam et. Farklı bir şey varsa sor.

---

## Task 1 — tohumlama.case_id Kolonu + Trigger Güncelleme

**Uygulama:**

```sql
-- Migration: tohumlama_case_link
-- 1. tohumlama tablosuna case_id FK eklenir
-- 2. Kızgınlık kapatan trigger güncellenir: case varsa not düşer

-- 1. Kolon ekle
ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS case_id text REFERENCES public.cases(id) ON DELETE SET NULL;

-- 2. Kızgınlığı kapatan trigger fonksiyonunu güncelle
-- Önce mevcut trigger adını doğrula (Başlamadan Önce adımında grep yap)
-- Aşağıdaki mantığı mevcut trigger'a ekle:

-- Mevcut trigger fonksiyonunun UPDATE kizginlik_log SET cozuldu=true bloğundan SONRA:
-- IF kizginlik_log.tedavi_case_id IS NOT NULL THEN
--   INSERT INTO case_notes veya cases'a not düşür
-- Bunu Task 1 okuma adımında gördüğün trigger fonksiyonuna entegre et.
```

> **NOT:** Trigger fonksiyonunun tam adını Başlamadan Önce adımında grep ile bul.
> Eğer trigger yoksa (tohumlama→kizginlik kapatma DB'de değil JS'de yapılıyorsa), bu adımı atla ve Task 3'e geç.

`supabase_migrate({sql: "ALTER TABLE..."})` ile case_id kolonunu deploy et.

**Doğrulama:**
```
supabase_query({
  table: "tohumlama",
  select: "id,hayvan_id,case_id",
  limit: 1
})
```
→ `case_id` kolonu dönmeli (null değerle)

---

## Task 2 — Trigger: Kızgınlık Kapanırken Case'e Not Düş

**Okuma:**
Başlamadan Önce adımındaki grep sonucuna göre trigger fonksiyonunu oku:
```bash
grep -n "CREATE.*FUNCTION.*kizginlik_kapat\|FUNCTION.*_tohumlama_kizginlik" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# Satır numarasını bul → sed ile oku
```

**Uygulama:**

Trigger fonksiyonuna `tedavi_case_id` kontrolü ekle. Cases tablosunda `notes` veya `notlar` kolonu varsa direkt güncelle; yoksa `islem_log`'a yaz:

```sql
-- Trigger içine eklenecek blok (kizginlik cozuldu=true yapıldıktan sonra):
IF OLD.tedavi_case_id IS NOT NULL THEN
  -- Case'e otomatik not: tohumlama yapıldı, kızgınlık kapatıldı
  UPDATE public.cases
  SET updated_at = now()
  WHERE id = OLD.tedavi_case_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'KIZGINLIK_TOHUMLAMA_KAPANDI',
    OLD.hayvan_id,
    OLD.id,
    'kizginlik_log',
    jsonb_build_object(
      'kizginlik_id', OLD.id,
      'case_id', OLD.tedavi_case_id,
      'mesaj', 'Kızgınlık tohumlama ile kapatıldı — bağlı vaka mevcut'
    )
  );
END IF;
```

> Cases tablosunda `notes` array/jsonb kolonu varsa (Başlamadan Önce adımında kontrol et) doğrudan oraya da yaz.

**ground_truth.sql güncelle** — trigger fonksiyon bloğunu yeni versiyon ile değiştir.

---

## Task 3 — Yeni RPC: kizginlik_vaka_ac

Bu RPC; kızgınlık bağlamından case açar, kızgınlık + tohumlama arasında çift yönlü bağlantı kurar.

**Uygulama:**

```sql
CREATE OR REPLACE FUNCTION public.kizginlik_vaka_ac(
  p_kizginlik_id   text,
  p_tani           text,
  p_tohumlama_id   text    DEFAULT NULL,
  p_notlar         text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_kiz      record;
  v_case_id  uuid := gen_random_uuid();
BEGIN
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- Case oluştur
  -- cases tablosunun kolon adlarını Başlamadan Önce adımında doğrula
  INSERT INTO public.cases (id, hayvan_id, status, category, disease_name, notes, created_at)
  VALUES (
    v_case_id::text,
    v_kiz.hayvan_id,
    'active',
    'Üreme',
    p_tani,
    COALESCE(p_notlar, 'Tohumlama sırasında tespit edildi'),
    now()
  );

  -- Kızgınlığı bu case'e bağla
  UPDATE public.kizginlik_log
  SET tedavi_case_id = v_case_id::text
  WHERE id = p_kizginlik_id;

  -- Tohumlama kaydını da bağla (varsa)
  IF p_tohumlama_id IS NOT NULL THEN
    UPDATE public.tohumlama
    SET case_id = v_case_id::text
    WHERE id = p_tohumlama_id;
  END IF;

  -- islem_log
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'KIZGINLIK_VAKA_ACILDI',
    v_kiz.hayvan_id,
    p_kizginlik_id,
    'kizginlik_log',
    jsonb_build_object(
      'case_id', v_case_id,
      'tani', p_tani,
      'kizginlik_id', p_kizginlik_id,
      'tohumlama_id', p_tohumlama_id
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text) TO anon, authenticated;
```

> **cases tablosu kolon adlarını kontrol et** — `disease_name` yerine `tani`, `notes` yerine `notlar` olabilir. Okuma adımında görülen gerçek kolonları kullan.

`supabase_migrate({sql: "..."})` ile deploy et.

**Doğrulama:**
```
supabase_rpc({
  function_name: "kizginlik_vaka_ac",
  params: '{"p_kizginlik_id":"VAR_OLMAYAN_ID","p_tani":"Test"}'
})
```
→ `{"ok": false, "mesaj": "Kızgınlık kaydı bulunamadı"}` dönmeli

---

## Task 4 — ground_truth.sql + Migration Dosyası Commit

**Uygulama:**

Migration dosyası: `supabase/migrations/20260526000002_tohumlama_case_link.sql` — Task 1 + Task 2 + Task 3'teki tüm SQL bloklarını bu dosyaya yaz (sırayla).

`ground_truth.sql`'de:
- `tohumlama` tablo tanımından sonra `case_id` `ALTER TABLE` satırını ekle
- Trigger fonksiyonunu güncelle (Task 2)
- `kizginlik_vaka_ac` RPC'yi ekle (diğer RPC'lerin yanına)

**Commit:**
```bash
git add supabase/migrations/20260526000002_tohumlama_case_link.sql \
        supabase/migrations/99999999999999_ground_truth.sql
git commit -m "feat(db): tohumlama-case bağlantı altyapısı — case_id FK, trigger güncellemesi, kizginlik_vaka_ac RPC"
git push origin main
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "Plan-B tamamlandı: tohumlama.case_id eklendi, kizginlik kapatan trigger case'e islem_log yazar, kizginlik_vaka_ac RPC kızgınlık+tohumlama+case üçlü bağlantı kurar. cases tablosu kolon adları ground_truth'tan doğrulandı.",
  category: "code_change",
  priority: "medium",
  tags: "tohumlama,case,kizginlik,trigger,rpc"
})
```
