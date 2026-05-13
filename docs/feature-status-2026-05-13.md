# EgeSüt ERP — Özellik Durum Raporu (2026-05-13)

## Özet

| # | Konu | Durum | Notlar |
|---|------|-------|--------|
| 1 | Padok değiştirme | ✅ Tamam | Hayvan kartı + padok içi + yönetim paneli + toplu |
| 2 | Kısır/satılabilir statüsü | ❌ Yok | Hiç başlanmadı |
| 3 | 210. gün laktasyon görevi | ✅ Tamam | ileri_gebe_gorev_kontrol RPC (240/260/261/265. gün) |
| 4 | 60. gün buzağı sütten kesme | ❌ Yok | Hiç başlanmadı |
| 5 | Toplu padok UI | ✅ Tamam | Toplu işlemler ekranı + modal + RPC |

---

## 1. Padok Değiştirme — ✅ Tamam

### Hayvan kartından padok değiştirme
- `js/ui.js:851-895` — `padokDegistir()` fonksiyonu
- `index.html:1468-1502` — `m-padok-det` modali, `det-padok-select` dropdown

### Padok içinden hayvan ekleme/çıkarma
- `js/ui.js:3873-3950` — `renderPadokHayvanlar()`, `padokTekliTasi()`, `padokTopluTasi()`
- `index.html:1504-1520` — `m-padok-transfer` modali

### Toplu padok değişimi
- `js/ui.js:3928-3975` — `padokTopluTasi()`, `padokTransferOnayla()`
- `supabase/migrations/20260512000002_padok_degistir_toplu_rpc.sql` — `padok_degistir_toplu()` RPC

### Tekil padok değişimi RPC
- `supabase/migrations/20260512000001_padok_degistir_rpc.sql` — `padok_degistir()`, transactional + islem_log

### Padok yönetim paneli
- `js/ui.js:3794-4029` — CRUD (ekle, düzenle, sil) + grup-padok eşlemeleri

---

## 2. Kısır / Satılabilir Statüsü — ❌ Yok

**Ne gerekiyor:**
- `hayvanlar` tablosuna kolon (örn. `kisir bool`, `satilabilir bool` veya `durum_ek text`)
- Hayvan kartında gösterim + düzenleme
- Hayvan listesinde filtre desteği
- Zorunlu değil ama yararlı: RPC veya view desteği

**Mevcut `hayvanlar.durum`:** `'Aktif'`, `'Çıktı'`, `'Ölü'` — kısır için ayrı flag daha temiz.

---

## 3. 210. Gün Laktasyon Görevi — ✅ Tamam

- `supabase/migrations/20260509000001_ileri_gebe_gorev.sql` — `ileri_gebe_gorev_kontrol()` RPC
- 240/260/261/265. günlerde otomatik görev oluşturma (ileri gebe hayvanlar)
- `supabase/migrations/20260509000004_gebe_gorev_trigger.sql` — gebe olunca otomatik tetikleme
- `docs/superpowers/specs/2026-05-09-ileri-gebe-gorevler.md` — orijinal spec

---

## 4. 60. Gün Buzağı Sütten Kesme — ❌ Yok

**Mevcut:** `hayvanlar` şemasında `suttten_kesme_tarihi` kolonu var (view'da görünüyor) ama otomatik uyarı/görev yok.

**Ne gerekiyor:**
- Yeni RPC: `buzagi_sutten_kesme_gorev_kontrol()` — 60. günü geçen buzağılara görev aç
- `ileri_gebe_gorev_kontrol()` benzeri yapı — referans olarak kullanılabilir
- Trigger veya manuel tetikleme (görevler ekranından "Kontrol Et" butonu)
- Frontend: görevler listesinde görünsün (mevcut görev sistemi yeterli)

---

## Bekleyen İşler (Goose-ready)

### A) Kısır/Satılabilir Statüsü
- Effort: S
- Migration + hayvan kartı UI + filtre
- Bağımsız, herhangi bir sırada yapılabilir

### B) 60. Gün Buzağı Sütten Kesme
- Effort: M
- RPC + trigger + frontend görev kartı
- `ileri_gebe_gorev_kontrol()` → referans al, aynı pattern
