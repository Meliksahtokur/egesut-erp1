# Task-dev-005 Revize 3 (Son)

**Durum:** revize
**Branch:** gwen/dev-005-clean (aynı branch, düzelt + force push)

---

## Değiştirilecek dosya: migration

`supabase/migrations/20260401000001_drug_product_ekle.sql` dosyasını **tamamen şununla değiştir:**

```sql
-- drug_product_ekle RPC
-- Yeni ilaç ürünü ekler, duplikat kontrolü yapar, stok bağlantısı kurar

-- Unique index (race condition önleme)
CREATE UNIQUE INDEX IF NOT EXISTS idx_drug_products_brand_class
  ON drug_products (LOWER(brand_name), drug_class_id);

CREATE OR REPLACE FUNCTION drug_product_ekle(
  p_drug_class_id      UUID,
  p_brand_name         TEXT,
  p_concentration      NUMERIC DEFAULT NULL,
  p_concentration_unit TEXT    DEFAULT NULL,
  p_default_route      TEXT    DEFAULT 'IM',
  p_default_unit       TEXT    DEFAULT NULL,
  p_stok_id            UUID    DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  -- Validation
  IF p_brand_name IS NULL OR trim(p_brand_name) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;

  -- Duplikat kontrolü
  IF EXISTS (
    SELECT 1 FROM drug_products
    WHERE LOWER(brand_name) = LOWER(p_brand_name)
      AND drug_class_id = p_drug_class_id
  ) THEN
    RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
  END IF;

  -- Kayıt ekle
  INSERT INTO drug_products (
    drug_class_id, brand_name, concentration,
    concentration_unit, default_route, default_unit
  ) VALUES (
    p_drug_class_id, p_brand_name, p_concentration,
    p_concentration_unit, p_default_route, p_default_unit
  )
  RETURNING id INTO v_id;

  -- Stok bağlantısı (atomik — aynı transaction içinde)
  IF p_stok_id IS NOT NULL THEN
    UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID)
  TO anon, authenticated;
```

Migration push:
```bash
supabase db push
```

---

## Değiştirilecek dosya: forms.js

`js/forms.js` içinde ilaç ekleme bloğunu bul (şu an `db.rpc('drug_product_ekle', ...)` olan kısım).

`p_stok_id` parametresini RPC çağrısına ekle ve stok için ayrı `db.from('stok').update(...)` satırını **sil**:

```js
// DOĞRU — stok_id RPC'ye geçiliyor, ayrı update satırı YOK
const dp = await rpc('drug_product_ekle', {
  p_drug_class_id:      etkenId,
  p_brand_name:         urun,
  p_concentration:      konst ? Number.parseFloat(konst) : null,
  p_concentration_unit: konst || null,
  p_default_route:      route,
  p_default_unit:       birim,
  p_stok_id:            stokId || null,
});
if (!dp) throw new Error('İlaç kaydı oluşturulamadı');
_drugsCache = [];
```

**Kontrol:** Bu blokta `db.from('stok').update(...)` satırı kalmamalı.

---

## Test + push

```bash
node --check js/forms.js
git add js/forms.js supabase/migrations/20260401000001_drug_product_ekle.sql
git commit --amend --no-edit
git push origin gwen/dev-005-clean --force
```

---

## Kabul Kriterleri

- [ ] Migration'da `SECURITY DEFINER` var
- [ ] Migration'da `GRANT EXECUTE TO anon, authenticated` var
- [ ] Migration'da unique index var
- [ ] Migration'da `p_stok_id` parametresi var, stok UPDATE RPC içinde
- [ ] `forms.js`'de `db.from('stok').update(...)` bu bağlamda yok
- [ ] `forms.js`'de `etkenId` kullanılıyor (etakenId yok)
- [ ] `node --check js/forms.js` temiz

## Tamamlandığında

`/root/egesut-erp1-main/.claude/gwen-tasks/task-dev-005-done.md` yaz.
