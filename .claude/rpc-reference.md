# RPC Quick Reference

Tüm RPC'ler `SECURITY DEFINER`, `jsonb` döndürür: `{ ok: boolean, ... }`
Frontend'de `api.js` üzerinden çağrılır. Asla doğrudan `db.from().insert/update` kullanılmaz.

---

## Hayvan Yönetimi

**`hayvan_ekle(p_kupe_no, p_devlet_kupe, p_irk, p_cinsiyet, p_dogum_tarihi, p_grup, p_padok, p_dogum_kg?, p_anne_id?, p_baba_bilgi?, p_canli_agirlik?, p_boy?, p_renk?, p_ayirici_ozellik?)`**
→ Yeni hayvan kaydı oluşturur, otomatik ID üretir.

**`hayvan_guncelle(p_id, p_kupe_no?, p_devlet_kupe?, p_irk?, p_cinsiyet?, p_dogum_tarihi?, p_grup?, p_padok?, p_dogum_kg?, p_canli_agirlik?, p_boy?, p_renk?, p_ayirici_ozellik?)`**
→ Hayvan bilgilerini günceller.

**`hayvan_not_ekle(p_hayvan_id, p_not)`**
→ Hayvana not ekler.

---

## Üreme

**`tohumlama_kaydet(p_hayvan_id, p_tarih, p_sperma, p_hekim_id?, p_irk_bilgisi?)`**
→ Tohumlama kaydeder. State machine: boş → gebe.

**`tohumlama_sonuc_gebe(p_tohumlama_id)`**
→ Tohumlama sonucunu "Gebe" yap. Hayvan durumu "Gebe" → islem_log kaydı.

**`tohumlama_sonuc_bos(p_tohumlama_id)`**
→ Tohumlama sonucunu "Boş" yap (muayenede gebe değil). Hayvan durumu "Boş" → islem_log kaydı.

**`tohumlama_sonuc_bekliyor(p_tohumlama_id)`**
→ Hatalı kaydı düzelt: sonuç → "Bekliyor", hayvan durumu → "Tohumlanabilir" → islem_log kaydı.

**`dogum_kaydet(p_anne_id, p_tarih, p_kupe, p_cins?, p_tip?, p_kg?, p_baba?, p_hekim_id?)`**
→ Doğum kaydeder + buzağı oluşturur + 14 doğum sonrası görev üretir.

**`abort_kaydet(p_tohumlama_id, p_notlar?)`**
→ Tohumlama abort'u kaydeder. State: gebe → boş.

**`kizginlik_kaydet(p_hayvan_id, p_tarih, p_belirti?, p_notlar?)`**
→ Kızgınlık gözlemi kaydeder.

---

## Hastalık (Legacy Sistem)

**`hastalik_kaydet(p_hayvan_id, p_tani, p_kategori?, p_siddet?, p_semptomlar?, p_lokasyon?, p_hekim_id?, p_ilaclar?, p_tedavi_gun?)`**
→ Hastalık vakası + tedaviler + follow-up görevler oluşturur.

**`hastalik_guncelle(p_id, p_tani, p_kategori, p_siddet, p_semptomlar, p_lokasyon, p_hekim_id, p_tarih?)`**
→ Vaka bilgilerini günceller.

**`hastalik_kapat(p_id)`**
→ Aktif vakayı kapatır.

**`hastalik_sil(p_id)`**
→ Vakayı + follow-up görevleri siler.

---

## Tedavi (Legacy Sistem)

**`tedavi_ekle(p_vaka_id, p_hayvan_id, p_ilac_stok_id, p_miktar, p_uygulama_yolu?, p_bekleme_gun?, p_hekim_id?, p_notlar?)`**
→ İlaç tedavisi ekler + stok ledger'dan düşer.

**`tedavi_sil(p_tedavi_id)`**
→ Tedaviyi siler + stoğu geri yükler.

**`tedavi_guncelle(p_tedavi_id, p_miktar?, p_uygulama_yolu?, p_bekleme_gun?, p_hekim_id?, p_notlar?)`**
→ Tedavi günceller + stok delta hesaplar.

**`update_treatment_time(p_day_id uuid, p_treatment_time time)`**
→ Tedavi saatini günceller.

---

## Vaka Sistemi (Yeni — Migration 022+)

**`create_case(p_animal_id, p_disease_id uuid, p_notes?)`**
→ Kontrollü hastalık listesinden yeni vaka oluşturur.

**`add_treatment_day(p_case_id, p_date, p_planned_time time?)`** *(LEGACY — korundu)*
→ Vakaya tedavi günü ekler (day_no otomatik, planned_time opsiyonel). planned_time varsa gorev_log JSON'a eklenir. **Yeni akış için `add_treatment_day_with_sessions` tercih edilir.**

**`add_treatment_day_with_sessions(p_case_id, p_date, p_sessions jsonb, p_existing_day_id uuid?)`** *(BUG-059 — Faz 2, 2026-06-11)*
→ Sarmalayıcı RPC. `p_sessions` JSONB array: `[{planned_time, stok_id, drug_product_id?, dose, unit, route}]`. `p_sessions=NULL` ise eski tek-seans davranış (geriye uyumlu). `p_existing_day_id` doluysa günceller (recete revizyonu). `{ ok, day_id, gorev_id, admin_ids, seans_sayisi, mesaj }`

**`seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi boolean?, p_not text?)`** *(BUG-059 — Faz 2)*
→ Seans bazlı race-safe tamamla/iptal. SELECT FOR UPDATE ile eşzamanlılık koruması. `p_uygulanmandi=true` ise stok_hareket güncellenir, drug_admins senkronize edilir, tedavi günü otomatik tamamlanır. `{ ok, tamamlandi, gun_tamam, mesaj }`

**`recete_guncelle(p_case_id, p_yeni_plan jsonb)`** *(BUG-059 — Faz 2)*
→ Henüz tamamlanmamış tedavi günlerinin reçetesini günceller (DRY → `add_treatment_day_with_sessions`'a delege eder). `{ ok, guncellenen_gun_sayisi, mesaj }`

**`treatment_day_tamamla(p_day_id, p_not?, p_uygulanmadi_ids uuid[]?)`** *(BUG-059 — Faz 2, idempotent)*
→ Tedavi gününü tamamlar. **Idempotent** — zaten tamamlandıysa exception fırlatmaz, `{ ok: true }` döner. p_uygulanmadi_ids'deki ilaçlar uygulanmadi=true + stok_hareket iptal. Tüm seanslar tamamsa gun kapatılır, gorev_log güncellenir. `{ ok, day_id }`

**`case_plan_notu_guncelle(p_case_id, p_plan_notu)`**
→ cases.plan_notu güncelle.

**`add_drug_administration(p_day_id uuid, p_drug_id uuid, p_dose, p_unit, p_route?)`**
→ İlaç uygulaması kaydeder + stok düşer.

**`close_case(p_case_id uuid)`** *(LEGACY — korundu)*
→ Vakayı kapatır (status='closed'). **Eksik reçete uyarısı veren akıllı versiyon için `close_case_with_remaining` tercih edilir.**

**`close_case_with_remaining(p_case_id uuid, p_not text?)`** *(BUG-059 — Faz 2)*
→ Vakayı erken kapatır. Tamamlanmamış tedavi günlerindeki tüm seanslar `uygulanmadi=true` yapılır, stok iade edilir, drug_admins senkronize edilir, açık gorev_log'lar kapatılır. `{ ok, iptal_edilen_seans, iade_edilen_stok, mesaj }`

---

## Diğer

**`geri_al(p_islem_id)`**
→ islem_log'dan işlemi geri alır (önceki state'e döner).

**`irk_listesi()`**
→ `TABLE(irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi)` — ırk referans listesi.

**`hekim_ekle(p_id, p_ad, p_telefon?)`**
→ Veteriner kaydı ekler.

---

## İlaç Sınıflandırma (drug_classes)

**`drug_class_ekle(p_group_name, p_class_name, p_active_ingredient, p_kategori_id?)`**
→ Yeni etken madde sınıfı ekler. `{ ok, id, mesaj }`

**`drug_class_guncelle(p_id, p_group_name?, p_class_name?, p_active_ingredient?, p_kategori_id?)`**
→ Sınıf bilgilerini günceller. `{ ok, mesaj }`

**`drug_class_sil(p_id)`**
→ Sınıfı siler. drug_products bağlıysa engeller. `{ ok, mesaj }`

**`drug_class_varsayilan_yukle()`**
→ 44 referans etken maddeyi seed eder (ON CONFLICT DO NOTHING). `{ ok, eklenen }`

---

## Stok Yönetimi

**`stok_ekle(p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik?)`**
→ Yeni stok kaydı. Kategori stok_kategorileri'nde olmalı. `{ ok, id }`

**`stok_guncelle(p_stok_id, p_urun_adi?, p_kategori?, p_birim?, p_esik?)`**
→ Stok günceller. Kategori değiştiriliyorsa validate edilir. `{ ok }`
