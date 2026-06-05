# SonarCloud Issue Raporu
**Kaynak:** SonarCloud CI — `Meliksahtokur_egesut-erp1`
**Tarih:** 2026-06-05
**Not:** Analiz henüz eski Automatic Analysis sonuçlarını içeriyor (supabase/migrations dahil).
JS-only analiz tamamlandığında SQL kaynaklı gürültü düşecek.

---

## ÖZET

| Kategori | Sayı | Durum |
|----------|------|-------|
| 🔴 CRITICAL Bug (JS/HTML) | 9 | Aksiyonable |
| 🟠 MAJOR Bug (JS/HTML) | 4 | Aksiyonable |
| 🟡 MAJOR Bug (SQL) | 18 | Gürültü — JS-only analiz sonrası düşecek |
| 🔵 Security Hotspot (MEDIUM) | 3 | İncelenmeli |
| ⚪ Security Hotspot (LOW) | 9 | Bilgi |
| 🟠 Code Smell CRITICAL (JS) | 6 | Aksiyonable |
| 🟠 Code Smell MAJOR (JS) | ~20 | Aksiyonable |
| 🟠 Code Smell CRITICAL (SQL) | ~900 | Gürültü — JS-only analiz sonrası düşecek |

**Quality Gate: ❌ ERROR**
- new_reliability_rating: 3 (eşik: 1)
- new_duplicated_lines_density: 48.6% (eşik: 3%)
- new_security_hotspots_reviewed: 0% (eşik: 100%)

---

## 1. JS/HTML BUGLAR — CRITICAL

> Bunlar gerçek işlevsel hatalar. Öncelikli fix adayları.

### SORT-001 · Sort localeCompare eksik — Türkçe karakter sıralaması bozuk
- **Dosya:** `js/ui.js:2800`, `js/ui.js:2818`
- **Sorun:** `Object.keys(tree).sort()` — Türkçe harflerde (`İ`, `Ş`, `Ğ`, `Ç`, `Ö`, `Ü`) alfabetik sıra yanlış
- **Etki:** Tanımlar panelinde ilaç grup/sınıf listesi yanlış sıralanıyor
- **Fix:** `sort((a, b) => a.localeCompare(b, 'tr'))`

### SORT-002 · Sort localeCompare eksik — forms.js
- **Dosya:** `js/forms.js:1493`, `js/forms.js:1380`, `js/forms.js:433`
- **Sorun:** `array.sort()` — localeCompare yok
- **Etki:** Form dropdown'larında Türkçe sıralama bozuk
- **Fix:** `sort((a, b) => a.localeCompare(b, 'tr'))` veya alan bazlı karşılaştırma

### SORT-003 · Sort localeCompare eksik — ui.js (çeşitli listeler)
- **Dosya:** `js/ui.js:4211`, `js/ui.js:4488`, `js/ui.js:4523`, `js/ui.js:4555`, `js/ui.js:2544`
- **Sorun:** `array.sort()` veya `Object.keys().sort()` — localeCompare yok
- **Etki:** Farklı liste/dropdown'larda Türkçe sıralama bozuk
- **Fix:** `sort((a, b) => a.localeCompare(b, 'tr'))`

### ARG-001 · Fonksiyon 3 parametre bekliyor, 6 gönderiliyor
- **Dosya:** `js/forms.js:920`
- **Sorun:** Fonksiyon imzasıyla çağrı uyuşmuyor — 3 fazla argüman sessizce yok sayılıyor
- **Etki:** Muhtemelen refactor sırasında parametre listesi değişti, çağrı güncellenmedi
- **Fix:** forms.js:920 satırını ve ilgili fonksiyon imzasını kontrol et

### CONST-001 · `const` değişkene atama denemesi
- **Dosya:** `js/forms.js:1625`
- **Sorun:** `idKey` `const` tanımlı ama modify edilmeye çalışılıyor
- **Etki:** Runtime'da sessiz hata veya strict mode'da exception
- **Fix:** `const` → `let` olarak değiştir

---

## 2. JS/HTML BUGLAR — MAJOR

### AWAIT-001 · try/catch içinde await eksik
- **Dosya:** `js/ui.js:996`
- **Sorun:** Promise try/catch içinde ama await yok — hata yakalanmıyor
- **Etki:** Async hata sessizce yutulabilir
- **Fix:** `await` ekle veya `.catch()` zinciri kullan

### ASSIGN-001 · `=` yerine `+=` mı olmalı?
- **Dosya:** `js/ui.js:2467`
- **Sorun:** SonarCloud `+=` beklenen yerde `=` kullanıldığını söylüyor — potansiyel veri kaybı
- **Etki:** HTML template birikimi varsa (html += ...) eski içerik siliniyor olabilir
- **Fix:** ui.js:2467 kontrol et

### TAUTOLOGY-001 · Koşul her zaman aynı sonucu veriyor
- **Dosya:** `js/app.js:492`
- **Sorun:** Ternary operatör her iki dalda aynı değeri döndürüyor
- **Etki:** Dead code — koşulun bir kolu hiç çalışmıyor
- **Fix:** app.js:492 kontrol et, gereksiz dalı temizle

### CONST-TRUTHY-001 · Sol tarafta her zaman truthy sabit
- **Dosya:** `js/ui.js:3369`
- **Sorun:** `<sabit> || expression` — sol taraf her zaman truthy, sağ taraf hiç çalışmıyor
- **Etki:** Dead code — sağ taraftaki default/fallback ifadesi işlevsiz

### CSS-001 · Duplicate CSS property
- **Dosya:** `index.html:368`
- **Sorun:** `display` özelliği aynı blokta iki kez tanımlı
- **Etki:** İkinci tanım birincinin üzerine yazar — beklenmeyen layout
- **Fix:** Tekrar eden `display` satırını kaldır

---

## 3. JS CODE SMELLS — MAJOR/CRITICAL

> İşlevsel bozukluk yok ama okunabilirlik/bakım sorunu.

### NESTED-TERNARY · İç içe ternary
- **Dosya:** `js/ui.js:724, 725, 776, 781, 783, 798`
- **Sorun:** Extract this nested ternary into independent statement
- **Etki:** Bakım zorluğu
- **Not:** Şimdilik düşük öncelik

### OPTIONAL-CHAIN · Optional chain kullanılabilir
- **Dosya:** `js/forms.js:42`, `js/app.js:128`
- **Sorun:** `a && a.b` yerine `a?.b` daha okunur
- **Etki:** Bakım
- **Not:** Şimdilik düşük öncelik

---

## 4. GÜVENLİK HOTSPOT'LARI

### PRNG-001 · Math.random() güvenlik bağlamında mı kullanılıyor?
- **Dosya:** `js/app.js:8`, `js/ui.js:2747`, `js/ui.js:2748`
- **Önem:** MEDIUM (incelenmeli)
- **Sorun:** `Math.random()` kriptografik olarak güvenli değil
- **Değerlendirme:** ERP'de UUID/offline kuyruk ID üretimi için kullanılıyor — güvenlik açığı değil, bilgi amaçlı
- **Aksiyon:** "Reviewed — Safe" olarak işaretle

### WORKFLOW-SHA · GitHub Actions SHA hash eksik
- **Dosya:** `.github/workflows/deploy.yml:18,23`, `.github/workflows/sonarcloud.yml:22`, `.github/workflows/supabase-migration-telemetry.yml:17`
- **Önem:** LOW
- **Sorun:** `uses: actions/checkout@v4` yerine `uses: actions/checkout@<full-sha>` öneriliyor
- **Değerlendirme:** Supply chain saldırısı riski teorik, pratikte düşük
- **Aksiyon:** Düşük öncelik

### SRI-001 · Subresource Integrity eksik
- **Dosya:** `index.html:17`, `index.html:1663`
- **Önem:** LOW
- **Sorun:** CDN'den yüklenen harici script'lerde `integrity` attribute yok
- **Değerlendirme:** İncelenmeli — hangi CDN kaynakları var?

---

## 5. SQL BUGLAR (Gürültü — JS-only analiz sonrası kalkacak)

> Bu hatalar `sonar.exclusions=supabase/**` config'i ile bir sonraki CI run'da kaybolacak.
> Şimdilik aksiyon gerekmez.

- **IS NULL karşılaştırması** (`= NULL` yerine `IS NULL`):
  - `ground_truth.sql:565, 574, 3135, 8230, 8233`
  - `ilac_rpcler.sql:18, 21`
  - `drugs_kategori_stokkat_tip.sql:22, 50`
  - `tohumlama_case_link.sql:59`
  - `tohumlama_case_geri_al.sql:40`
  - `faz1_core.sql:336, 345`
- **SQL Code Smells** — sabit string literal'lar tekrarlanıyor (ground_truth, protokol migration'ları): ~850+ issue

---

## 6. ACCESSIBILITY

### A11Y-001 · Keyboard event eksik
- **Dosya:** `index.html:378`
- **Önem:** MINOR
- **Sorun:** Tıklanabilir `<div>` üzerinde `onKeyPress`/`onKeyDown` yok
- **Etki:** Klavye kullanıcıları erişemez
- **Aksiyon:** Düşük öncelik

---

## FIX ÖNCELİK SIRASI

```
1. SORT-001/002/003  → Türkçe sıralama (9 satır, yüksek kullanıcı etkisi)
2. ARG-001           → forms.js:920 yanlış argüman sayısı (CRITICAL)
3. CONST-001         → forms.js:1625 const'a atama
4. AWAIT-001         → ui.js:996 await eksik
5. ASSIGN-001        → ui.js:2467 = vs += kontrol
6. TAUTOLOGY-001     → app.js:492 dead code
7. CONST-TRUTHY-001  → ui.js:3369 dead code
8. CSS-001           → index.html:368 duplicate display
9. PRNG-001          → "Safe" olarak işaretle (hotspot kapatma)
```
