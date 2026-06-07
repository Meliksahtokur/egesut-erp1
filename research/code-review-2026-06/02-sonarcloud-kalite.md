# Aşama 2 — SonarCloud Kalite Analizi

**Tarih:** 2026-06-07  
**Proje:** Meliksahtokur_egesut-erp1  
**Son Analiz:** SonarCloud Cloud (güncel)

---

## Quality Gate

**Durum:** ❌ ERROR

| Koşul | Değer | Eşik | Durum |
|-------|-------|------|-------|
| new_reliability_rating | 3 (C) | 1 (A) | ❌ FAIL |
| new_duplicated_lines_density | 48.6% | 3% | ❌ FAIL |
| new_security_hotspots_reviewed | 0% | 100% | ❌ FAIL |
| new_security_rating | 1 (A) | — | ✅ PASS |
| new_maintainability_rating | 1 (A) | — | ✅ PASS |

---

## Metrikler

| Metrik | Değer | Değerlendirme |
|--------|-------|---------------|
| Satır Sayısı (ncloc) | 33.144 | — |
| Bug | **31** | ⚠️ Yüksek |
| Vulnerability | 4 | ⚠️ Tümü tooling dosyalarında |
| Code Smell | 1.162 | 🔴 Çok Yüksek |
| Coverage | **0%** | 🔴 Test yok |
| Duplikasyon | **45.1%** | 🔴 Kritik (SQL migration ağırlıklı) |
| Cognitive Complexity | **3.605** | 🔴 Çok Yüksek |
| Teknik Borç (sqale_index) | **8.628 dk (~144 saat)** | 🔴 Yüksek |
| Reliability Rating | 4.0 (D) | ⚠️ Zayıf |
| Security Rating | 5.0 (E) | 🔴 Hotspot'lar review edilmedi |

---

## Kritik JS Bug'lar (CRITICAL + MAJOR)

Sadece `js/` ve `index.html` — migration dosyaları hariç.

| # | Dosya:Satır | Önem | Açıklama |
|---|-------------|------|----------|
| 1 | js/forms.js:920 | CRITICAL | **Fonksiyon 3 argüman bekliyor, 6 ile çağrılıyor** — runtime bug, sessiz hata üretir |
| 2 | js/ui.js:2800 | CRITICAL | `Array.sort()` compare function eksik + localeCompare kullanılmıyor — Türkçe sıralama bozulur |
| 3 | js/ui.js:2818 | CRITICAL | Aynı sort sorunu |
| 4 | js/ui.js:4211,4488,4523,4555 | CRITICAL | sort() compare function eksik — 4 lokasyon |
| 5 | js/ui.js:2544 | CRITICAL | sort() compare function eksik |
| 6 | js/forms.js:1493 | CRITICAL | sort() compare function eksik |
| 7 | js/forms.js:1380 | CRITICAL | sort() compare function eksik |
| 8 | js/forms.js:433 | CRITICAL | sort() localeCompare eksik — Türkçe sıralama bozulur |
| 9 | js/ui.js:996 | MAJOR | `try` içinde `await` eksik — promise hatası yakalanmıyor |
| 10 | js/ui.js:2467 | MAJOR | `=` yerine `+=` mı olmalı? — olası değer atama bug'u |
| 11 | js/forms.js:1625 | MAJOR | `const idKey` değiştirilmeye çalışılıyor — `let` olmalı |
| 12 | js/app.js:492 | MAJOR | Koşullu ifade her zaman aynı değer döndürüyor — ölü kod veya mantık hatası |
| 13 | js/ui.js:3369 | MAJOR | Sol tarafta sabit truthy değer — mantık hatası |
| 14 | index.html:368 | MAJOR | CSS `display` property'si iki kez tanımlı |

---

## Güvenlik Hotspot'ları (12 adet)

| # | Dosya:Satır | Önem | Kategori | Açıklama |
|---|-------------|------|----------|----------|
| 1 | js/app.js:8 | MEDIUM | Kriptografi | `Math.random()` — kriptografik değil, güvenli rastgelelik gerektiren yerde kullanılmamalı |
| 2 | js/ui.js:2747-2748 | MEDIUM | Kriptografi | `Math.random()` — aynı sorun, 2 lokasyon |
| 3 | .github/workflows/*.yml | LOW | Supply Chain | GitHub Actions action'larda tam commit SHA yerine tag kullanılıyor (3 workflow) |
| 4 | .github/workflows/*.yml | LOW | CI/CD | `${{ secrets.* }}` run block içinde expand ediliyor (2 workflow) |
| 5 | index.html:17,1663 | LOW | Web Güvenlik | `<link>` tag'lerinde `integrity` (SRI) hash yok |

---

## 4 BLOCKER Vulnerability — Tooling Dosyaları

> ⚠️ Bu bulgular main ERP kodu (`js/`, `index.html`) değil, geliştirici araçları ve script dosyalarında.

| # | Dosya:Satır | Açıklama |
|---|-------------|----------|
| 1 | tools-bank/memory/search_tool.py:292 | Bearer Authentication token hardcoded |
| 2 | .claude/scripts/supa-query.js:10 | Supabase API token hardcoded |
| 3 | .claude/scripts/supa-query.sh:8 | Supabase API token hardcoded |
| 4 | patch.py:29 | Path traversal riski — user-controlled data'dan path oluşturuluyor |

---

## SQL Migration Bug'ları (Özet)

| Kural | Sayı | Açıklama |
|-------|------|----------|
| IS NULL / IS NOT NULL eksik | 12 | `= NULL` yerine `IS NULL` kullanılmalı — SQL standard |
| Duplicate literal (CRITICAL CODE_SMELL) | ~40+ | SQL string literalleri tekrarlı — migration dosyası stilistik |

> Not: Migration bug'larının büyük kısmı SonarCloud'un SQL kurallarından kaynaklanıyor. Aktif çalışan `ground_truth.sql` canonical referans olduğundan bu sorunlar production etkisi bakımından değerlendirilmeli.

---

## Semgrep ↔ SonarCloud Örtüşme

| Dosya | Semgrep Bulgusu | SonarCloud Bulgusu | Önem |
|-------|----------------|-------------------|------|
| js/ui.js | 4× onclick XSS (WARNING) | 14 BUG + 30+ code smell | **Yüksek Güven — Bu dosya en riskli** |
| js/api.js | anon key hardcoded (INFO) | — (BLOCKER'lar farklı dosyada) | Orta |
| js/forms.js | — | CRITICAL bug (920. satır: 6 arg), 3× sort bug | Yüksek |
| js/app.js | — | 1 BUG (492. satır ternary), 3× Math.random() hotspot | Orta |

**Yüksek Güven Bulgu:** `js/ui.js` her iki araçta da en yoğun problem dosyası — 2800+ satır monolith, 14 bug, yüksek cognitive complexity.

---

## Kalite Skoru (0-100)

**Formül:**
- Quality Gate ERROR → +10 taban
- Bug 31 adet (her biri -3, max -30): -30
- Vulnerability 4 adet (her biri -5, max -20): -20 (tümü tooling'de)
- Coverage 0% → +0
- Duplikasyon 45.1% > 15% → +0

**Ham skor:** 10 - 30 - 20 = -40 → **minimum 0**

**Bağlam düzeltmesi:** 4 BLOCKER vulnerability main ERP kodunda değil (`tools-bank/`, `.claude/scripts/`). ERP kodu kendi başına değerlendirilirse: 10 - 30 - 0 = **-20 → minimum 5**.

**Kalite Skoru: 15/100**

> Düşüklüğün temel kaynakları: 31 bug (8'i CRITICAL sort sorunları), 45% duplikasyon (SQL migration ağırlıklı), sıfır test coverage, 3605 cognitive complexity. Teknik borç: 144 saat.

---

## Sonraki Aşamaya Bağlam

SonarCloud'da yüksek complexity işaretlenen fonksiyonlar (GitNexus impact analizi yapılacak):

- **`js/ui.js`** — 14 bug, 2800+ satır, sort/await sorunları; GitNexus'ta blast radius analizi kritik
- **`js/forms.js`** — CRITICAL bug (forms.js:920 — 6 argüman hatası), sort sorunları
- **`js/app.js`** — Math.random() hotspot + ternary bug (492. satır)
- **`js/forms.js:1625`** — const→let mutation bug: GitNexus'ta bağımlı semboller araştırılacak
- **SQL sort sorunları:** Türkçe sıralama bozukluğu (Türkçe Unicode fix'i yapılmış olmasına rağmen sort() compare function eksikliği var)
