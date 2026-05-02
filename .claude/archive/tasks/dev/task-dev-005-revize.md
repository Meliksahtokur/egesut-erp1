# Task-dev-005 Revize 2

**Durum:** revize
**Branch:** gwen/dev-005-clean (yeni temiz branch — önceki kirli branch'i bırak)

---

## Adım 1 — Temiz branch oluştur

```bash
cd /root/egesut-erp1
git checkout main
git pull origin main
git checkout -b gwen/dev-005-clean
git cherry-pick ff39594
```

Cherry-pick sonrası aşağıdaki düzeltmeleri yap.

---

## Adım 2 — forms.js typo düzelt

`js/forms.js:848` satırında:

```js
// YANLIŞ:
p_drug_class_id: etakenId,

// DOĞRU:
p_drug_class_id: etkenId,
```

---

## Adım 3 — Migration düzelt

`supabase/migrations/20260401000001_drug_product_ekle.sql` dosyasını aç ve şu 3 şeyi ekle:

**a) `SECURITY DEFINER` ekle** — `$$ LANGUAGE plpgsql;` satırını şöyle değiştir:
```sql
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**b) `GRANT EXECUTE` ekle** — dosyanın sonuna ekle:
```sql
GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT) TO anon, authenticated;
```

**c) Unique constraint ekle** — `INSERT` bloğundan önce ekle:
```sql
-- Race condition önleme: unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_drug_products_brand_class
  ON drug_products (LOWER(brand_name), drug_class_id);
```

Migration push:
```bash
supabase db push
```

---

## Adım 4 — Test + commit + push

```bash
node --check js/forms.js
git add js/forms.js supabase/migrations/20260401000001_drug_product_ekle.sql
git commit --amend --no-edit
git push -u origin gwen/dev-005-clean
```

---

## Kabul Kriterleri

- [ ] `etkenId` kullanılıyor (etakenId yok)
- [ ] Migration'da `SECURITY DEFINER` var
- [ ] Migration'da `GRANT EXECUTE TO anon, authenticated` var
- [ ] `unique index` oluşturuldu
- [ ] `node --check` temiz
- [ ] `git diff main..gwen/dev-005-clean --name-only` → 5 dosya (forms.js, bugs.md, migration, .gitignore, task dosyası)

## Tamamlandığında

`/root/egesut-erp1-main/.claude/gwen-tasks/task-dev-005-done.md` yaz.
