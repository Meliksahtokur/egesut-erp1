# Ground Truth SQL Güncelleme Planı

> Topoloji: Hierarchical | 4 task | 0 paralel blok
> Model: deepseek-chat (flash)
> Soru varsa sor. Bu plan sadece dosya güncelleme — DB değişikliği yok.

**Hedef:** `supabase/migrations/99999999999999_ground_truth.sql` dosyasını canlı DB ile senkronize et.
**Etkilenen dosyalar:** `supabase/migrations/99999999999999_ground_truth.sql` sadece.

---

## Başlamadan Önce

Şu migration'ları sırayla oku (en son deploy edilenler, canonical kaynak):
```
20260312000022_case_management.sql       → orijinal case/drug şeması
20260403000002_delete_treatment_day.sql  → delete_treatment_day (BUG'lu versiyon — ground_truth'ta YENİSİNİ yaz)
20260525000002_treatment_day_done.sql    → treatment_day_tamamla RPC
20260527000001_vaka_geri_alma_islem_log.sql → create_case + geri_al + add_treatment_day (eski)
20260527000002_stok_iade_gecmis_tarih.sql   → add_treatment_day geçmiş tarih (bu da geçersiz — 000003 geçerli)
20260527000003_geri_al_chain_ve_stok_iptal.sql → SON VERSİYON: geri_al, add_treatment_day, delete_treatment_day
```

**ÖNEMLI:** Her fonksiyon için ground_truth'ta güncelleme yaparken en son migration'daki versiyonu kullan.

---

## Task 1 — `drug_administrations` tablo şemasını güncelle

**Sorun:** ground_truth'ta `drug_administrations.drug_id` var, canlıda `stok_id` var.

**Canlı şemayı doğrula:**
```
supabase_query({table: "drug_administrations", limit: 1})
```
→ Dönen sütunları not et: `id, treatment_day_id, dose, unit, route, notes, created_at, drug_product_id, stok_id`

**ground_truth'ta güncelle:**
`drug_administrations` CREATE TABLE bloğunu bul ve `drug_id uuid NOT NULL REFERENCES public.drugs(id)` satırını kaldır,
yerine:
```sql
  stok_id           text    REFERENCES public.stok(id),
  drug_product_id   uuid    REFERENCES public.drug_products(id),
```
ekle.

**Trigger güncelle:**
`drug_administration_stok_dusum` trigger fonksiyonunu bul ve içeriği sil — bu trigger canlıda çalışmıyor
(drug_id kolonu yok). Yerine boş stub koy veya tamamen kaldır:
```sql
-- Trigger kaldırıldı: stok hareketi add_drug_administration RPC içinde yapılıyor
```

**Doğrulama:**
ground_truth'ta `drug_administrations` bölümünü oku, `drug_id` kelimesi kalmamış olmalı.

---

## Task 2 — RPC'leri güncelle (son versiyonlar)

Aşağıdaki 4 fonksiyonu ground_truth'ta `CREATE OR REPLACE FUNCTION` ile güncelle.
Her birinin son versiyonu `20260527000003_geri_al_chain_ve_stok_iptal.sql` dosyasında.

### 2a — `geri_al`
ground_truth'taki eski versiyonu (`DROP IF EXISTS` + yeni versiyon) ile değiştir.
Yeni versiyonda:
- `treatment_days` → `UPDATE stok_hareket SET iptal=true` + DELETE treatment_days
- `cases` → DELETE TEDAVI_GUN gorevler + `UPDATE stok_hareket SET iptal=true` + DELETE cases
- ELSE → generic text/uuid try-catch

### 2b — `add_treatment_day`
Son versiyon: `p_case_id uuid, p_date date` parametreli, `v_gecmis` kontrolü, `v_prev_gorev_id` zinciri, `parent_id` eklendi.

### 2c — `delete_treatment_day`
Son versiyon: `UPDATE stok_hareket SET iptal=true` (pozitif iade bug fix), TEDAVI_GUN gorev silme, sonra DELETE.

### 2d — `create_case` (islem_log snapshot)
`20260527000001_vaka_geri_alma_islem_log.sql` içindeki `create_case` güncellemesini bul.
ground_truth'taki eski `create_case`'e `-- islem_log snapshot` bloğunu ekle.

### 2e — `treatment_day_tamamla`
`20260525000002_treatment_day_done.sql` dosyasındaki versiyonu ground_truth'ta yoksa ekle.

**Doğrulama:** Her fonksiyon için ground_truth'ta `GRANT EXECUTE` satırı da olduğunu kontrol et.

---

## Task 3 — `add_drug_administration` RPC güncellemesi

**Sorun:** ground_truth'taki `add_drug_administration` `drug_id` parametresi kullanıyor.
Canlıda UI `p_stok_id` ve `p_drug_product_id` ile çağırıyor.

**Canlı imzayı kontrol et:**
```
supabase_rpc({function_name: "add_drug_administration", params: '{"p_day_id":"00000000-0000-0000-0000-000000000000","p_stok_id":null,"p_dose":1,"p_unit":"ml"}'})
```
→ Dönen hatadan imzayı çıkar.

**ground_truth'u güncelle:**
Eski `add_drug_administration(p_day_id uuid, p_drug_id uuid, ...)` imzasını kaldır,
canlıdaki `(p_day_id uuid, p_stok_id text, p_drug_product_id uuid, p_dose numeric, p_unit text, p_route text)` imzasıyla değiştir.

İçeriği `20260526000003_ek_uygulama_stok.sql` veya ilgili migration'dan kontrol ederek yaz.

---

## Task 4 — Son kontrol ve commit

**Kontrol listesi:**
- [ ] `drug_administrations` tablosunda `drug_id` kelimesi yok
- [ ] `geri_al` fonksiyonu son versiyon (iptal=true, gorev orphan fix)
- [ ] `add_treatment_day` parent_id zinciri var
- [ ] `delete_treatment_day` iptal=true var
- [ ] `create_case` islem_log INSERT var
- [ ] `treatment_day_tamamla` var
- [ ] `add_drug_administration` doğru imza

**Syntax kontrol:**
```bash
# SQL syntax için pg_format veya basit grep
grep -n "drug_id" /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# → Sonuç boş olmalı (sadece yorum satırlarında olabilir)
```

**Commit:**
```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "docs(db): ground_truth senkronize — drug_id→stok_id, geri_al v3, add_treatment_day zinciri"
git push origin main
```

**Checkpoint:**
```
memory_add({
  content: "ground_truth güncellendi: drug_administrations.stok_id, geri_al v3 (iptal=true+gorev orphan), add_treatment_day parent_id zinciri, delete_treatment_day stok fix",
  category: "code_change",
  priority: "medium",
  tags: "ground_truth,drug_administrations,geri_al"
})
```

---

## Referans

| Değişiklik | Migration Dosyası | Satır Aralığı |
|-----------|-------------------|---------------|
| geri_al v3 | `20260527000003_...sql` | baştan |
| add_treatment_day v3 | `20260527000003_...sql` | ortada |
| delete_treatment_day fix | `20260527000003_...sql` | sonda |
| create_case islem_log | `20260527000001_...sql` | ortada |
| treatment_day_tamamla | `20260525000002_...sql` | baştan |
| drug_administrations şema | `20260312000022_...sql` | orijinal + değişiklikler |
