# Dashboard — Aktif Vakalar Bölümü

**Tarih:** 2026-05-25  
**Durum:** Fikir — henüz planlanmadı  
**Motivasyon:** Şu an aktif vakalara sadece Geçmiş sekmesinden erişiliyor. Dashboard'dan direkt görünürlük yok.

---

## Mevcut Sorun

- Aktif vaka = acil bilgi. Dashboard'da hiç görünmüyor.
- Kullanıcı her sabah vakaları görmek için Geçmiş → hayvan detayı → vaka zincirinden geçmek zorunda.
- Tedavi done sistemi eklendi ama "bugün hangi tedaviler var?" sorusu dashboard'dan cevaplanamıyor.

---

## Önerilen: Dashboard Band

Dashboard'daki diğer band'ların (muayene gerekli, yaklaşan doğumlar vb.) yanına:

```
🏥 Aktif Vakalar (2)
┌─────────────────────────────────────────┐
│ 🐄 #156  Topallık (Laminit)            │ →
│ ████████░░  Gün 2/3 · 1 kaldı          │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ 🐄 #089  Mastitis                      │ →
│ ██░░░░░░░░  Gün 1/4 · 3 kaldı          │
└─────────────────────────────────────────┘
```

- Progress bar: tamamlanan gün / toplam gün
- "N kaldı" → kaç gün daha var
- Tıkla → direkt `openCaseDet(caseId)`
- 0 aktif vaka → band görünmez (diğer band'larla tutarlı)

---

## Veri

`cases` tablosunda `status = 'active'` filtresi. IDB'den okunur (`idbGetAll('cases')`).
`treatment_days` join ile progress hesaplanır.

`_dashBands` fonksiyonuna yeni bir blok eklenir — mevcut pattern:
```js
if ((aktifVakalar||[]).length) {
  html += _band('🏥 Aktif Vakalar', aktifVakalar.map(...).join(''));
}
```

---

## Alternatif: Hayvan Detayını İyileştir

Hayvan detayında zaten kırmızı chip var (`🏥 Mastitis` gibi). Ama bu yeterli değil — dashboard'dan geçmeden bu chip'e ulaşılamıyor.

Seçenek: Chip'i daha büyük/belirgin yap + progress bar ekle (hayvan detayı içi). Dashboard band'a ek olarak veya yerine.

---

## İlgili Dosyalar

- `js/ui.js` → `_dashBands()`, `_dashStatRow()`, `loadDashboard()` (~satır 150–260)
- `js/ui.js` → `openCaseDet()` (satır 2587)
- `supabase/migrations/99999999999999_ground_truth.sql:2694` → `cases` tablosu
- `supabase/migrations/99999999999999_ground_truth.sql:2715` → `treatment_days` tablosu

---

## Bağımlılık

Bu feature, `treatment_days.tamamlandi` kolonunun mevcut olmasını gerektiriyor.
✅ 2026-05-25 done sistemi commit'iyle eklendi (`400d4bd`).
