# Task-dev-006: BUG-005 — stok update RPC'ye taşı

**Durum:** bekliyor
**Session:** dev
**Branch:** gwen/dev-006 (main'e dokunma — branch'e push et, done dosyası yaz, merge Claude yapar)

---

## Sorun

`js/forms.js:795` satırında stok tablosuna hâlâ direkt REST yapılıyor:

```js
await db.from('stok').update({ drug_product_id: dp }).eq('id', stokId);
```

Bu `drug_product_ekle` RPC'sinin içine taşınmalı.

---

## Migration güncelle

`supabase/migrations/20260401000001_drug_product_ekle.sql` dosyasına `p_stok_id` parametresi **zaten eklenmiş** olabilir. Önce kontrol et:

```bash
grep "p_stok_id" supabase/migrations/20260401000001_drug_product_ekle.sql
```

**Eğer yoksa** — migration'a yeni bir patch migration yaz:

`supabase/migrations/20260401000002_drug_product_ekle_stok.sql`:

```sql
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
  IF p_brand_name IS NULL OR trim(p_brand_name) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;

  IF EXISTS (
    SELECT 1 FROM drug_products
    WHERE LOWER(brand_name) = LOWER(p_brand_name)
      AND drug_class_id = p_drug_class_id
  ) THEN
    RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
  END IF;

  INSERT INTO drug_products (
    drug_class_id, brand_name, concentration,
    concentration_unit, default_route, default_unit
  ) VALUES (
    p_drug_class_id, p_brand_name, p_concentration,
    p_concentration_unit, p_default_route, p_default_unit
  )
  RETURNING id INTO v_id;

  IF p_stok_id IS NOT NULL THEN
    UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID)
  TO anon, authenticated;
```

```bash
supabase db push
```

---

## forms.js güncelle

`js/forms.js` içinde `drug_product_ekle` RPC çağrısını bul. `p_stok_id` ekle ve sonrasındaki `db.from('stok').update(...)` satırını sil:

```js
const dp = await rpc('drug_product_ekle', {
  p_drug_class_id:      etkenId,
  p_brand_name:         urun,
  p_concentration:      konst ? Number.parseFloat(konst) : null,
  p_concentration_unit: konst || null,
  p_default_route:      route,
  p_default_unit:       birim,
  p_stok_id:            stokId || null,   // ← ekle
});
if (!dp) throw new Error('İlaç kaydı oluşturulamadı');
_drugsCache = [];
// db.from('stok').update(...)  ← bu satırı SİL
```

---

## Test + push

```bash
node --check js/forms.js
git checkout -b gwen/dev-006
git add js/forms.js supabase/migrations/
git commit -m "fix: BUG-005 — stok update drug_product_ekle RPC içine taşındı"
git push -u origin gwen/dev-006
```

---

## Kabul Kriterleri

- [ ] `db.from('stok').update(...)` bu bağlamda yok
- [ ] `p_stok_id` RPC'de var
- [ ] `node --check` temiz
- [ ] Branch: `gwen/dev-006` — main'e dokunulmadı

## Tamamlandığında

`/root/egesut-erp1-main/.claude/gwen-tasks/task-dev-006-done.md` yaz.
