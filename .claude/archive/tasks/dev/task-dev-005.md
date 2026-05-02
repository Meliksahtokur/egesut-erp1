# Task-dev-005: Bug Tracker Güncelleme + drug_product_ekle RPC

## Zincir

### 1. bugs.md Güncelle (5 dk)
**Çözüldü işaretle:**
- ✅ BUG-002: openNotModal duplikat — çözüldü
- ✅ BUG-006: Direkt REST bypass — drugs update — çözüldü
- ✅ BUG-008: submitInsem sonrası UI refresh — çözüldü
- ✅ BUG-009: tohSonuc() direkt REST PATCH — çözüldü

### 2. drug_product_ekle RPC (20 dk)
**Backend:**
- [ ] `drug_product_ekle` RPC yaz (Supabase)
- [ ] Migration oluştur: `20260401_drug_product_ekle.sql`
- [ ] Push migration

**Frontend:**
- [ ] `forms.js:765` — direkt insert yerine RPC çağrısı
- [ ] Validasyon: duplikat kontrolü

## Branch
`gwen/dev-005`

## Commit
```
DONE: dev — drug_product_ekle RPC + bug tracker güncelleme
```

## Referans
- BUG-004: Direkt REST bypass — drug_products insert (forms.js:765)
- BUG-005: Direkt REST bypass — stok update (forms.js:775)

---

**Tarih:** 2026-04-01
**Durum:** Hazır
