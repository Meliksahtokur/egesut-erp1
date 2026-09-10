# Eksikler — Detaylı Analiz

## KRİTİK EKSİKLER (Öncelik: Yüksek)

### 1. Component kütüphanesi yok

**Sorun:** Modal, Toast, Autocomplete 4 ayrı kopya, hâlâ fonksiyon-bazlı.

**Etki:**
- Yeni modal eklemek = 3 dosyada değişiklik (ui.js, forms.js, index.html)
- Autocomplete mantığı `acHayvan`, `acSperma`, `acIlac`, `acDisease` olarak
  4 kopya
- Bug fix bir yerde düzeltilse diğer 3 kopyada kalıyor
- Refactor hızı düşük (her değişiklikte 4 yere git)

**Referans:** ReFactorRoadmap.md 1.4 (Autocomplete Tekilleştirme) +
3.3 (Modal Sınıflara Dönüştürme) — ikisi de tamamlanmamış.

**Çözüm önerisi:**
- `js/components/Modal.js` — sınıf bazlı (Aşama 3.3)
- `js/components/Autocomplete.js` — `setupAutocomplete(inputId, options)`
  (Aşama 1.4)
- `js/components/Toast.js` — kuyruk bazlı (Aşama 3.4)
- `js/components/FormField.js` — input + label + error

**Efor:** 2-3 oturum (parça parça, kademeli)

---

### 2. CSS ayrıştırılmamış + design token sistemi yok

**Sorun:** Tüm stiller `index.html` `<style>` içinde inline, renk/spacing
her yerde tekrarlı.

**Etki:**
- Tema değişikliği (örn. koyu tema) imkansız gibi
- Tasarım tutarsızlığı (her ekran farklı padding/margin)
- Vendor prefix'ler, animation tanımları 5+ yerde kopyalanmış
- GitHub Pages CDN-only olduğu için style bundle'ı da küçülmeli

**Referans:** ReFactorRoadmap.md 1.2 (Sabitlerin Merkezileştirilmesi)
yarım — JS sabitleri config.js'e taşındı ama CSS sabitleri (renk, spacing)
hiç dokunulmadı.

**Çözüm önerisi:**
- `js/design-tokens.js` — JS tarafı (örn. `TOKENS.color.primary`)
- `css/tokens.css` — CSS değişkenleri (örn. `--color-primary`)
- `css/{layout,components,pages}.css` — bölünmüş
- `index.html` inline `<style>` → `<link>` ile değiştir

**Efor:** 1-2 oturum (yüksek ama tek oturumda kapsam dışı)

---

### 3. UI/UX review skill'i yok

**Sorun:** `spec-writer` ve `reviewer` recipe'leri kod odaklı. Görsel/UX
review yapacak özelleşmiş bir skill mevcut değil.

**Etki:**
- "Buton çok küçük", "renk kontrastı düşük", "mobile'da taşıyor" gibi
  UX problemleri review aşamasında yakalanmıyor
- Son kullanıcı şikayetleri ancak prod'da ortaya çıkıyor
- Design system kararları tutarsız

**Çözüm önerisi:**
- `~/.claude/skills/ui-review/SKILL.md` oluştur
  - Checklist: spacing, color, typography, a11y, mobile, performance
  - tools: visual diff (manuel + sonradan otomatik), a11y checker
  - recipes ile entegre: `reviewer` + `ui-review` paralel

**Efor:** 1 oturum (skill dokümanı + basit checklist)

---

### 4. `utils/` dizini yok, helper'lar dağınık

**Sorun:** ReFactorRoadmap.md 1.3 (Yardımcı Fonksiyonların Ayrıştırılması)
yarım. `g()`, `v()`, `cl()`, `dAgo()`, `dFwd()`, `fmtTarih()`, `toast()`,
`showDebug()` hâlâ ui.js'in üstünde global.

**Etki:**
- Test edilemez (global window.*)
- Tree-shaking imkansız
- Helper isim çakışması riski

**Çözüm önerisi:**
- `js/utils/helpers.js` (g, v, cl, dAgo, dFwd, fmtTarih)
- `js/utils/modal.js` (openM, closeM, mClose)
- `js/utils/dom.js` (DOM manipülasyon yardımcıları)

**Efor:** 1 oturum

---

### 5. Render motoru hâlâ `innerHTML` full replace

**Sorun:** ReFactorRoadmap.md 3.1 (Render Motorunun Hafifletilmesi) —
mevcut `innerHTML` atamaları her değişiklikte tüm listeyi yeniden çiziyor.

**Etki:**
- Hayvan listesi (130+ kayıt) her render'da titriyor
- Scroll pozisyonu kayboluyor
- Focus/input value sıfırlanıyor
- Performance: O(n) her etkileşimde

**Çözüm önerisi:**
- lit-html (1.5KB CDN) veya morphdom (3KB) entegre et
- `insertAdjacentHTML` ile parçalı güncelleme (acil)
- Uzun vadede: virtual scrolling (130+ için gerekli olabilir)

**Efor:** 2-3 oturum (acil parça + uzun vadeli)

---

## İKİNCİL EKSİKLER (Öncelik: Orta)

### 6. Accessibility (a11y) kontrolü yok

**Sorun:** Modal/lar klavye ile kapatılamıyor olabilir, `aria-*` eksik,
focus trap yok, axe-core integration'ı yok.

**Etki:** Engelli kullanıcılar için erişilemez, WCAG uyumsuz.

**Çözüm:** `axe-core` CDN ile CI'a ekle, `ui-review` skill'ine a11y
checklist'i koy.

---

### 7. i18n altyapısı yok

**Sorun:** Hard-coded TR stringleri (örn. "Kaydet", "İptal", "Hayvan
Listesi") her dosyaya gömülü.

**Etki:** İngilizce (veya başka dil) eklemek = tüm dosyalarda find-replace.

**Çözüm:** `js/i18n.js` + `locales/tr.js`, `locales/en.js` — `t('key')`
fonksiyonu.

**Efor:** 1 oturum (altyapı) + her dosya için string extraction.

---

### 8. Storybook eşdeğeri yok

**Sorun:** Component'leri izole görmek/geliştirmek için ortam yok.

**Etki:** Component değişikliği = tüm app'i aç, sayfaya git, test et.

**Çözüm:** Vanilla JS için basit bir "kitchen sink" sayfası
(`dev-components.html` veya `index.html?dev=1`).

**Efor:** Yarım oturum.

---

### 9. Performance budget yok

**Sorun:** Render süresi, bundle boyutu, Lighthouse skoru takibi yok.

**Etki:** GitHub Pages CDN-only olduğu için her KB önemli. Yavaş render
fark edilmiyor.

**Çözüm:** `lighthouse-ci` + bundle-size guard, haftalık rapor.

---

### 10. Mock data / fixture yok

**Sorun:** Yeni component tasarlarken gerçek Supabase verisi olmadan
UI kuramıyoruz.

**Etki:** Offline geliştirme imkansız, demo/test zor.

**Çözüm:** `dev/fixtures/` altında JSON dosyaları + dev modunda inject.

---

### 11. Mobile-first breakpoint standardı yok

**Sorun:** Tablet/phone için tutarlı breakpoint kararları dokümante değil.

**Etki:** Her ekran kendi kafasına göre `@media` yazıyor.

**Çözüm:** `css/tokens.css` içinde breakpoint değişkenleri + ADR.

---

## TOOL / OTOMASYON EKSİKLERİ

### 12. `ui-snapshot` MCP tool yok

**İhtiyaç:** Mevcut UI state'ini JSON'a alıp refactor karşılaştırması
yapmak.

**Çözüm:** tools-bank MCP'ye yeni tool ekle (Claude yapabilir).

---

### 13. Design token validator yok

**İhtiyaç:** ui.js içinde hard-coded renk tespiti (örn. `#16a34a` kaç
yerde?).

**Çözüm:** Custom ast-grep pattern + rapor tool.

---

### 14. A/B veya variant test yok

**İhtiyaç:** "Eski tasarım vs yeni" ölçümü.

**Çözüm:** Feature flag + basit analytics. (Öncelik düşük — MVP için
gerekli değil.)

---

### 15. Visual regression testi yok

**İhtiyaç:** Sadece Playwright E2E var, lokal PRoot'ta çalışmaz. CSS
değişikliği sonrası görsel regresyon yakalanmıyor.

**Çözüm:** Percy/Chromatic (ücretli) veya manuel screenshot diff
workflow'u + `gitnexus_detect_changes` ile screenshot karşılaştırma.

---

## Öncelik matrisi

| # | Eksik | Etki | Efor | Öncelik |
|---|---|---|---|---|
| 1 | Component kütüphanesi | Yüksek | 2-3 oturum | 🔴 1 |
| 2 | CSS + design tokens | Yüksek | 1-2 oturum | 🔴 2 |
| 3 | UI/UX review skill | Orta | 1 oturum | 🔴 3 |
| 4 | utils/ dizini | Orta | 1 oturum | 🟡 4 |
| 5 | Render motoru | Yüksek | 2-3 oturum | 🟡 5 |
| 6 | a11y | Orta | 1-2 oturum | 🟡 6 |
| 7 | i18n | Düşük (MVP sonrası) | 1+N oturum | 🟢 7 |
| 8 | Component dev ortamı | Düşük | Yarım oturum | 🟢 8 |
| 9 | Performance budget | Orta | 1 oturum | 🟢 9 |
| 10 | Mock fixtures | Düşük | Yarım oturum | 🟢 10 |
| 11 | Breakpoint standardı | Düşük | Yarım oturum | 🟢 11 |
| 12-15 | Tool eksikleri | Çeşitli | Çeşitli | ⏸️ Gerektiğinde |
