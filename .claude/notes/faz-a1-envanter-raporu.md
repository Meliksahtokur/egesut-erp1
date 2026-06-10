# Faz A.1 — Analiz Raporu

> **Tarih:** 2026-06-10
> **Yöntem:** Salt okunur analiz (ast_grep_search + grep)
> **Kapsam:** `js/utils/` envanter + js/* duplicate taraması + eksik helper analizi
> **Plan ref:** `.claude/plans/faz-a1-utils-envanter-ve-refactor.md`

---

## 1. js/utils/ Mevcut Durum

| Dosya | Satır | function | arrow | window export | Not |
|-------|-------|----------|-------|---------------|-----|
| `errorHandler.js` | 54 | 3 | 0 | 0 | `getUserMessage`, `withErrorHandling`, `showDebug` |
| `events.js` | 49 | 2 | 0 | 0 | `registerAction`, `registerActions` (pub/sub) |
| `handlers.js` | 301 | ~20 | 0 | 1 (`_prevTaskId`) | Geniş — click/event handler kütüphanesi |
| `helpers.js` | 98 | 13 | 0 | 0 | DOM/date/format/toast/esc helpers |
| `modal.js` | 64 | 3 | 0 | 0 | `openM`, `closeM`, `mClose` |
| **Toplam** | **566** | **~41** | **0** | **1** | — |

**Çıkarım:** utils/ iyi organize, **0 arrow function** (tüm fonksiyonlar `function` declaration). Vanilla JS global scope kuralıyla uyumlu.

### 1.1 helpers.js API yüzeyi (13 fn)

```javascript
// DOM query (3)
g(id)            // document.getElementById
v(id)            // g(id)?.value || ''
cl(id)           // g(id) value clear

// Date (3)
dAgo(n)          // n gün önce (ISO date)
dFwd(base, n)    // base + n gün
fmtTarih(iso)    // ISO → DD.MM.YYYY
fmtTarihSaat(iso)// ISO → DD.MM.YYYY HH:mm (tr-TR)

// Display (2)
getDisplayKupe(h, fallback)  // küpe no öncelik sırasıyla
trLower(s)                    // Türkçe-aware lower

// UI (2)
toast(msg, err)   // Snackbar
showDebug(msg)    // console.warn wrapper
esc(str)          // XSS escape

// Async (2)
debounce(fn, ms)  // 300ms default
throttle(fn, ms)  // 1000ms default

// Component (1)
setupAutocomplete(inputId, opts)  // + iç load/render/select
```

**Yorum:** Tek dosyada (helpers.js) tarih + format + DOM + async + UI hepsi var. 07 yol haritasının önerdiği **ayrı dosya yapısı gerekli değil** — zaten helpers.js iyi yapılandırılmış.

---

## 2. Duplicate / Inline Helper Adayları

### 2.1 ui.js içinde inline `new Date().toISOString().split('T')[0]`

**7 satır:** ui.js:239, 413, 529, 535, 551, 1646, 1764, 1841, 2013

**utils/ muadili:** `dAgo(0)` veya `dFwd(null, 0)` — ikisi de aynı sonucu veriyor

**Risk:** DÜŞÜK (sıfır davranış değişikliği, sadece inline → helper çağrısı)

**Öneri (Faz A.1b'ye):** `bugun()` alias'ı ekle veya mevcut çağrıları `dAgo(0)`'a çevir. **9 satır refactor.**

### 2.2 ui.js içinde inline `toLocaleString('tr-TR', ...)`

**1-2 satır:** ui.js:3588 ve başka yerlerde

**utils/ muadili:** `fmtTarihSaat()` zaten aynı pattern'i kullanıyor — **konsolide edilebilir**

**Risk:** DÜŞÜK

**Öneri (Faz A.1b'ye):** Inline kopyaları `fmtTarihSaat` ile değiştir. ~2-3 satır refactor.

### 2.3 ui.js/forms.js içinde inline `getElementById(...)`

**0 satır** — hepsi `g(id)` helper'ı kullanıyor ✅

**Yorum:** utils iyi tasarlanmış, **kimse inline duplicate yazmıyor**.

### 2.4 utils fonksiyon kullanım istatistikleri

| Fonksiyon | ui.js kullanım | forms.js | app.js | Toplam |
|-----------|----------------|----------|--------|--------|
| `g(id)` | 50+ | 30+ | 20+ | **100+** |
| `esc(str)` | 100+ | 50+ | 10+ | **160+** |
| `fmtTarih(iso)` | 20+ | 5+ | 2+ | **27+** |
| `dAgo(n)` | 5+ | 0 | 0 | **5+** |
| `toast()` | 30+ | 10+ | 10+ | **50+** |
| `getDisplayKupe` | 5+ | 2+ | 0 | **7+** |
| `debounce/throttle` | 1-2 | 0 | 0 | **1-2** |
| `setupAutocomplete` | 3-4 | 1 | 0 | **4-5** |

**Yorum:** utils fonksiyonları **yoğun şekilde kullanılıyor** — bu iyi bir mimari sinyal (herkes aynı helper'ı çağırıyor, kendi kopyasını yazmıyor).

---

## 3. Eksik Helper Gerçek Durumu

| 07 yol haritası | Gerçek | Karar |
|-----------------|--------|-------|
| `format.js` (para/sayı) | `helpers.js` içinde tarih formatı var (`fmtTarih`, `fmtTarihSaat`). Para/sayı formatı **yok ama ihtiyaç da düşük** — `toFixed()` inline kullanılıyor | ❌ Ayrı dosya gerekmez |
| `dom.js` (debounce, throttle, query) | Hepsi `helpers.js` içinde (`g`, `v`, `cl`, `debounce`, `throttle`) | ❌ Ayrı dosya gerekmez |
| `validation.js` | Yok | ❌ İhtiyaç analizi: form validation inline yapılıyor, ayrı helper'a gerek yok (her form kendine özgü) |

**Sonuç:** Mevcut utils/ **eksiksiz**. Yeni dosya ekleme gerekmez.

---

## 4. Blast Radius (Atlandı — Gerek Yok)

Neden atlandı:
- Bu plan **implementasyon yapmadı** (salt analiz)
- Yeni dosya eklenmedi
- Mevcut fonksiyon taşınmadı
- Sadece **bilgi** üretildi

Eğer Faz A.1b'de implementasyon yapılırsa (örn. `bugun()` helper'ı eklerse), o zaman `gitnexus_impact` ile kontrol edilmeli.

---

## 5. Çıkarımlar (Bilgi, Karar Değil)

1. **utils/ iyi tasarlanmış** — 5 dosya, 566 satır, 41 fonksiyon. Single Responsibility ihlali yok, her dosyanın net amacı var.
2. **Kullanım oranı yüksek** — `esc` 160+ yerde, `g` 100+ yerde çağrılıyor. Bu "doğru mimari" göstergesi.
3. **07 yol haritası gerçeği yansıtmıyor** — `format.js`/`dom.js` ayrı dosya önerisi pratikte gerekli değil, helpers.js zaten kapsıyor.
4. **Inline duplicate az** — sadece 9 satırlık `toISOString().split('T')[0]` tekrarı var, o da düşük riskli.
5. **Refactor iştahı düşük olmalı** — "bozulmamışsa tamir etme" prensibi. utils/ dokunulmaz.

---

## 6. Faz A.1b'ye Devredilecek İşler (Öneri, Karar Değil)

| # | İş | Kapsam | Risk | Öncelik |
|---|-----|--------|------|---------|
| 1 | `new Date().toISOString().split('T')[0]` → `dAgo(0)` veya `bugun()` | 9 satır, ui.js | DÜŞÜK | LOW |
| 2 | Inline `toLocaleString('tr-TR', ...)` → `fmtTarih()` | 2-3 satır | DÜŞÜK | LOW |
| 3 | (İsteğe bağlı) `bugun()` alias'ı helpers.js'e ekle | 1 satır | DÜŞÜK | LOW |

> ⚠️ **Bu işler YAPILMAMALI** aktif bug'lar (BUG-061+) bitmeden. Sadece **bilgi** olarak Faz A.1b backlog'unda.

---

## 7. Açık Sorular

- **Yok.** Analiz tamamlandı, utils/ durumu net.

---

## 8. Sonuç

- ✅ Adım 1 (envanter): 5 dosya, 41 fonksiyon
- ✅ Adım 2 (duplicate): 9 satır düşük riskli inline kopya (Faz A.1b'ye)
- ✅ Adım 3 (eksik): Yok — utils/ eksiksiz
- ⊘ Adım 4 (blast radius): Atlandı (gerek yok)
- ✅ Adım 5 (rapor): Bu dosya

**Genel değerlendirme:** utils/ sağlam. Refactor için acil ihtiyaç yok. Aktif bug'lar ve feature work öncelikli.
