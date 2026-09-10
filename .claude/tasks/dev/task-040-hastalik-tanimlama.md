# TASK-040 — El ile Hastalık Tanımlama / Gruplama

**Durum:** ✅ TAMAMLANDI  
**Öncelik:** Orta  
**Tarih:** 2026-05-27  
**Tamamlanma:** 2026-05-29 — Tanımlar paneli sprint

---

## Problem

Tedavi vakası açılırken hastalık/teşhis bilgisi serbest metin olarak giriliyor. Standart hastalık listesi yok, raporlama ve gruplama yapılamıyor.

---

## Beklenen Davranış

- Hastalık/teşhis için önceden tanımlanmış kategori listesi
- Tedavi vakasına hastalık kodu/adı bağlanabilmeli
- Hastalık bazlı istatistik görülebilmeli (en sık görülen, sezon dağılımı vb.)

---

## Notlar

- `diseases` veya `hastalik_tanimlari` tablosu oluşturulabilir
- Mevcut `cases` tablosuna `disease_id` FK eklenebilir
- UI: dropdown/autocomplete ile hızlı seçim
