# TASK-042 — Manuel İlaç Ekleme / Düzenleme

**Durum:** ✅ KISMEN TAMAMLANDI  
**Öncelik:** Orta  
**Tarih:** 2026-05-27  
**Tamamlanma:** 2026-05-30 — İlaç Sınıflandırma Faz 1 (drug_classes CRUD + drug_products + stok entegrasyonu)  
**Kalan:** update_drug_administration ve remove_drug_administration RPC'leri hâlâ kırık (ground_truth'ta da). Ayrı task olarak ele alınmalı.

---

## Problem

Tedavi günü ilaç uygulaması eklendikten sonra düzenlenemiyor veya silinemiyor. Yanlış doz/ilaç girişi düzeltilemez.

---

## Beklenen Davranış

- Eklenen ilaç uygulaması düzenlenebilmeli (doz, birim, yol)
- Silinebilmeli (stok iadesi iptal=true ile)
- `update_drug_administration` ve `remove_drug_administration` RPC'leri çalışır hale getirilmeli

---

## Notlar

- **Pre-existing bug:** `update_drug_administration` → `da.drug_id` referansı kırık (kolon yok)
- **Pre-existing bug:** `remove_drug_administration` → `referans_tipi/referans_id` ile arama yapıyor, yeni notlar formatıyla (`drug_admin:{uuid}`) uyumsuz
- Bu iki RPC ground_truth'ta da kırık, canlıda da — ayrı migration ile düzeltilmeli
- GRANT eksikleri de bu task'ta tamamlanabilir (`delete_treatment_day`, `update_drug_administration`)
