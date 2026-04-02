# Task-dev-006 Revize — Migration güvenlik düzeltmeleri

**Durum:** revize
**Session:** dev
**Branch:** gwen/dev-006 (main'e dokunma — push et, merge Claude yapar)

---

## Tek dosya: migration

`supabase/migrations/20260401000001_drug_product_ekle.sql` dosyasını tamamen şununla değiştir:

```sql
-- drug_product_ekle RPC v2 — security hardening

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
  IF p_brand_name IS NULL OR trim(p_brand_name) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;

  BEGIN
    INSERT INTO drug_products (
      drug_class_id, brand_name, concentration,
      concentration_unit, default_route, default_unit
    ) VALUES (
      p_drug_class_id, p_brand_name, p_concentration,
      p_concentration_unit, p_default_route, p_default_unit
    )
    RETURNING id INTO v_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
  END;

  IF p_stok_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stok WHERE id = p_stok_id) THEN
      RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
    END IF;
    UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID)
  TO authenticated;
```

```bash
supabase db push
```

---

## forms.js — error handling iyileştir

`js/forms.js` içinde `drug_product_ekle` RPC çağrısını bul. Hata mesajı RPC'den gelsin:

```js
const { data: dp, error: dpErr } = await db.rpc('drug_product_ekle', {
  p_drug_class_id:      etkenId,
  p_brand_name:         urun,
  p_concentration:      konst ? Number.parseFloat(konst) : null,
  p_concentration_unit: konst || null,
  p_default_route:      route,
  p_default_unit:       birim,
  p_stok_id:            stokId || null,
});
if (dpErr) throw new Error(dpErr.message);
if (!dp) throw new Error('İlaç kaydı oluşturulamadı');
_drugsCache = [];
```

---

## Test + commit + push

```bash
node --check js/forms.js
git add supabase/migrations/20260401000001_drug_product_ekle.sql js/forms.js
git commit -m "fix: drug_product_ekle — SECURITY DEFINER, search_path, stok validation, unique_violation handler"
git push -u origin gwen/dev-006
```

---

## Kabul Kriterleri

- [ ] `SECURITY DEFINER SET search_path = public, pg_temp` var
- [ ] `GRANT EXECUTE TO authenticated` (anon yok)
- [ ] INSERT unique_violation exception handler var
- [ ] stok IF NOT EXISTS check var
- [ ] `node --check` temiz
- [ ] Branch: `gwen/dev-006` — main'e dokunulmadı

## Tamamlandığında

`/root/egesut-erp1-main/.claude/gwen-tasks/task-dev-006-done.md` dosyasını güncelle.
