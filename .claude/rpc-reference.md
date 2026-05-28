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

**`add_treatment_day(p_case_id, p_date, p_planned_time time?)`**
→ Vakaya tedavi günü ekler (day_no otomatik). planned_time varsa gorev_log JSON'a eklenir.

**`treatment_day_tamamla(p_day_id, p_not?, p_uygulanmadi_ids uuid[]?)`**
→ Tedavi gününü tamamlar (sequential check + tamamlandi). p_uygulanmadi_ids'deki ilaçlar uygulanmadi=true + stok_hareket iptal.

**`case_plan_notu_guncelle(p_case_id, p_plan_notu)`**
→ cases.plan_notu güncelle.

**`add_drug_administration(p_day_id uuid, p_drug_id uuid, p_dose, p_unit, p_route?)`**
→ İlaç uygulaması kaydeder + stok düşer.

**`close_case(p_case_id uuid)`**
→ Vakayı kapatır (status='closed').

---

## Diğer

**`geri_al(p_islem_id)`**
→ islem_log'dan işlemi geri alır (önceki state'e döner).

**`irk_listesi()`**
→ `TABLE(irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi)` — ırk referans listesi.

**`hekim_ekle(p_id, p_ad, p_telefon?)`**
→ Veteriner kaydı ekler.
