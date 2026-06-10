# Eksikler — Done Durumu + Dış Skill Eşleşmesi

> **Amaç:** `.claude/eksikler/03-eksikler-detay.md` listesindeki 15
> eksikten hangisinin **kapatıldığını**, hangisinin **hâlâ açık**
> olduğunu ve dışarıdan hangi skill ile kapatılabileceğini göstermek.
>
> **Tarih:** 2026-06-10 (Güncelleme: find-skills taraması sonrası)

---

## ✅ Yapılan İşler (Done)

| # | İş | Tarih | Referans |
|---|---|---|---|
| 1 | Envanter oluşturma (mevcut araçlar, eksikler, kombinasyonlar, roadmap) | 2026-06-09 | `01`, `02`, `03`, `04` |
| 2 | find-skills ile dış UI/UX skill taraması | 2026-06-10 | `05-bulunan-skill-listesi.md` |
| 3 | 11 farklı keyword için 52+ skill keşfi | 2026-06-10 | (yukarıdaki dosya) |
| 4 | Tier 1-2-3 sınıflandırması (install sayısına göre) | 2026-06-10 | (yukarıdaki dosya) |
| 5 | Envanter #1-#15 için dış skill eşleşme matrisi | 2026-06-10 | `05`, aşağıdaki tablo |
| 6 | Envanter #1-#15 için done/in-progress/open durumu | 2026-06-10 | aşağıdaki tablo |

---

## 📊 Eksiklerin Done Durumu (Güncel)

### 🔴 KRİTİK EKSİKLER (Hâlâ Açık)

| # | Eksik | Durum | Dış Çözüm |
|---|---|---|---|
| **1** | Component kütüphanesi yok (Modal×4, Toast×4, Autocomplete×4 kopya) | 🟡 **Kısmen** — `pbakaus/impeccable@frontend-design` kurulabilir, ama implementasyon gerekiyor | `pbakaus/impeccable@frontend-design` (53.7K) + `nextlevelbuilder/ui-ux-pro-max-skill@ckm:design-system` (26.9K) |
| **2** | CSS + design token sistemi yok | 🟡 **Kısmen** — `dylanfeltus/skills@design-tokens` (145 install) + `nextlevelbuilder` (26.9K) rehber olarak kurulabilir | `dylanfeltus/skills@design-tokens` + `nextlevelbuilder/ui-ux-pro-max-skill@ckm:design-system` |
| **3** | UI/UX review skill'i yok | 🟡 **Kısmen** — `nextlevelbuilder` (26.9K) + `nickcrew/claude-ctx-plugin@ux-review` (63) rehber olarak | `nextlevelbuilder/ui-ux-pro-max-skill` + `nickcrew/claude-ctx-plugin@ux-review` |
| **4** | `utils/` dizini yok, helper'lar ui.js'te global | ❌ **Açık** — Manuel gerekli | (dış skill yok) |
| **5** | Render motoru `innerHTML` full replace | ❌ **Açık** — lit-html/morphdom entegre edilmeli | `rodydavis/skills@lit-and-monaco-editor` (41) + `pbakaus/impeccable` |

### 🟡 İKİNCİL EKSİKLER

| # | Eksik | Durum | Dış Çözüm |
|---|---|---|---|
| **6** | Accessibility (a11y) kontrolü yok | ✅ **ÇÖZÜLEBİLİR** — `addyosmani/web-quality-skills@accessibility` (26.7K) kurulumu hazır | `addyosmani/web-quality-skills@accessibility` + `chromedevtools/chrome-devtools-mcp@a11y-debugging` (1.1K MCP) |
| **7** | i18n altyapısı yok | ❌ **Açık** — Dış skill bulunamadı, manuel yazılmalı | (yok) |
| **8** | Storybook eşdeğeri yok | ❌ **Açık** — Manuel "kitchen sink" sayfası yazılacak | (yok) |
| **9** | Performance budget yok | ✅ **ÇÖZÜLEBİLİR** — `tech-leads-club/agent-skills@perf-lighthouse` (168) + `onnokh/lighthouse@lighthouse` (283) kurulumu hazır | `tech-leads-club/agent-skills@perf-lighthouse` |
| **10** | Mock fixtures yok | ❌ **Açık** — Manuel | (yok) |
| **11** | Mobile-first breakpoint standardı yok | ✅ **ÇÖZÜLEBİLİR** — `secondsky/claude-skills@mobile-first-design` (320) + `aj-geddes/useful-ai-prompts@mobile-first-design` (626) | `secondsky/claude-skills@mobile-first-design` |

### ⏸️ TOOL / OTOMASYON EKSİKLERİ

| # | Eksik | Durum | Dış Çözüm |
|---|---|---|---|
| **12** | `ui-snapshot` MCP tool yok | ❌ **Açık** — tools-bank MCP'ye eklenmeli (Claude yapar) | (yok) |
| **13** | Design token validator yok | ❌ **Açık** — Custom ast-grep pattern | (yok) |
| **14** | A/B test yok | ❌ **Açık** — Öncelik düşük | (yok) |
| **15** | Visual regression testi yok | ❌ **Açık** — Manuel screenshot diff workflow'u | (yok) |

---

## 🎯 Anlık Eyleme Geçirilebilir Olanlar (Quick Wins)

Dış skill ile **hemen** kapatılabilecek 4 eksik:

| # | Eksik | Dış Skill | Komut | Etki |
|---|---|---|---|---|
| **6** | a11y kontrolü yok | `addyosmani/web-quality-skills@accessibility` | `npx skills add addyosmani/web-quality-skills@accessibility -g -y` | WCAG uyumu + axe-core entegrasyonu |
| **9** | Performance budget yok | `tech-leads-club/agent-skills@perf-lighthouse` | `npx skills add tech-leads-club/agent-skills@perf-lighthouse -g -y` | Lighthouse CI entegrasyonu |
| **11** | Mobile-first standardı yok | `secondsky/claude-skills@mobile-first-design` | `npx skills add secondsky/claude-skills@mobile-first-design -g -y` | Breakpoint karar rehberi |
| **Genel** | UI design rehberi yok | `anthropics/skills@frontend-design` | `npx skills add anthropics/skills@frontend-design -g -y` | 522.6K install — temel UI rehberi |

---

## 🛠️ Manuel / Özel Geliştirme Gerektirenler

Aşağıdaki eksikler dış skill ile kapatılamaz, **kendi skill'imizi yazmamız** veya **manuel implement** gerekir:

| # | Eksik | Neden Manuel | Tahmini Efor |
|---|---|---|---|
| 1 | Component kütüphanesi | Vanilla JS — proje-spesifik, genel skill yok | 2-3 oturum |
| 2 | Design tokens | Tasarım kararı proje-spesifik | 1-2 oturum |
| 3 | UI/UX review skill | Mevcut skill'ler genel, bizim `ui-map.md` + `ReFactorRoadmap.md` ile entegre özel bir tane yazılabilir | 1 oturum |
| 4 | utils/ dizini | Kod organizasyon kararı, refactor | 1 oturum |
| 5 | Render motoru | lit-html/morphdom kararı + implement | 2-3 oturum |
| 7 | i18n | Türkçe-İngilizce çeviri dosyaları özel | 1+N oturum |
| 8 | Component dev ortamı | `dev-components.html` manual | Yarım oturum |
| 10 | Mock fixtures | Supabase şemasına bağımlı | Yarım oturum |
| 12 | `ui-snapshot` MCP tool | tools-bank MCP'ye yeni tool ekleme (Claude) | 1 oturum |
| 13 | Token validator | ast-grep custom pattern | Yarım oturum |
| 15 | Visual regression | Manuel screenshot diff | 1 oturum |

---

## 📈 İlerleme Özeti (Yüzde)

| Kategori | Tamamlanan | Kısmen | Açık |
|---|---|---|---|
| Kritik (1-5) | 0 | 3 | 2 |
| İkincil (6-11) | 0 | 3 (dış skill ile çözülebilir) | 3 |
| Tool/Otomasyon (12-15) | 0 | 0 | 4 |
| **Toplam** | **0 (0%)** | **6 (40%)** | **9 (60%)** |

**Dış skill kurulumu ile %40'a ulaşılabilir**, kalan %60 manuel/özel geliştirme.

---

## 🔄 Hangi Aşamada Ne Yapılacak?

### Faz 0 — Şimdi (Hemen, 10 dakika)
- Tier 1 dış skill'lerin hepsini kur (`npx skills add ... -g -y`)
- Bu envanteri + skill listesini commit et

### Faz A — Hızlı Kazanımlar (1-2 hafta)
- Dış skill'lerden gelen rehberi `nextlevelbuilder` ile ui-map üzerinde uygula
- utils/ dizini + component dev ortamı (kitchen sink)

### Faz B-C — Daha büyük işler
- Component kütüphanesi (Faz B)
- Design tokens + CSS ayrıştırma (Faz C)

Detay: `07-onerilen-yol-haritasi.md`

---

*Durum: 2026-06-10 06:35 | Goose worker*
