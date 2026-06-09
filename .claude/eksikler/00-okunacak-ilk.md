# UI / Tasarım / Refactor — Eksikler Envanteri

> **Amaç:** EgeSüt ERP'de UI değişikliği, tasarım veya refactor işi
> geldiğinde elimizdeki araçları görmek, eksiklerimizi bilmek ve
> işleri standart bir kombinasyonla yürütmek.
>
> **Kapsam:** Recipes, skills, tools-bank MCP tool'ları, proje-içi
> dokümanlar, kod varlıkları + eksikler.
>
> **Tarih:** 2026-06-09
> **Yazar:** Goose worker (Pi-new orkestratör talebiyla)
> **Konum:** `/root/egesut-erp1/.claude/eksikler/`

## Dosya haritası

| Dosya | İçerik |
|---|---|
| `00-okunacak-ilk.md` | Bu dosya — özet, kritik eksikler, hızlı rehber |
| `01-mevcut-araclar.md` | Recipe + Skill + MCP tool envanteri (detaylı tablo) |
| `02-kombinasyonlar.md` | 5 tipik senaryo için adım adım tarifler |
| `03-eksikler-detay.md` | 15 eksik için detaylı analiz, öneriler, öncelik |
| `04-roadmap-uyumu.md` | ReFactorRoadmap.md ile bu envanterin eşleşmesi |

## Hızlı cevap: En büyük 3 eksiğimiz

1. **Component kütüphanesi yok** — Modal, Toast, Autocomplete 4 ayrı
   kopya, hâlâ fonksiyon-bazlı (ReFactorRoadmap 1.4 + 3.3 tamamlanmamış).
2. **CSS ayrıştırılmamış + design token sistemi yok** — Tüm stiller
   `index.html` `<style>` içinde inline, renk/spacing her yerde tekrarlı.
3. **UI/UX review skill'i yok** — `spec-writer`/`reviewer` kod odaklı,
   görsel/UX review yapacak özelleşmiş bir skill mevcut değil.

## Envanter özeti (tek bakışta)

| Kategori | Mevcut | Yeterli mi? |
|---|---|---|
| Recipes (orchestration) | 9 adet | ✅ Conductor + orchestrator + worker üçlüsü güçlü |
| Skills (UI/Refactor) | 11 ilgili | ✅ feature-dev + gitnexus-refactoring + session-update iyi |
| tools-bank MCP tool'ları | 55+ | ✅ gitnexus_impact, ast_grep, sonar_duplications güçlü |
| Proje-içi doküman | 7 ilgili dosya | ✅ ReFactorRoadmap, ui-map, ADR'ler mükemmel |
| Component kütüphanesi | ❌ YOK | ❌ Kritik eksik |
| Design token sistemi | ❌ YOK | ❌ Kritik eksik |
| CSS modüler yapı | ❌ YOK (inline) | ❌ Kritik eksik |
| UI/UX review skill'i | ❌ YOK | ❌ Eksik |
| a11y kontrolü | ❌ YOK | ⚠️ İkincil |
| Visual regression testi | ❌ YOK | ⚠️ İkincil |

## Ne zaman bu envanteri okumalıyım?

- Yeni bir UI feature isteği geldiğinde → "Hangi recipe'i çalıştırayım?"
  sorusu için **02-kombinasyonlar.md**
- Refactor kararı vermeden önce → "Nereden başlayayım?" için
  **03-eksikler-detay.md** + **04-roadmap-uyumu.md**
- Hangi tool/skill var, hangisi yok sorusu için → **01-mevcut-araclar.md**

## İlgili diğer dosyalar (bu dizinin dışında)

- `/root/egesut-erp1/.claude/ReFactorRoadmap.md` — 3 aşamalı refactor yol haritası
- `/root/egesut-erp1/.claude/ui-map.md` — ui.js 2804 satır bölüm haritası
- `/root/egesut-erp1/.claude/ideas/` — 9 fikir dosyası (refactor adayları)
- `/root/egesut-erp1/.claude/arch-decisions/ADR-006, 007` — Telsiz mimarisi
- `/root/egesut-erp1/.claude/skills/egesut-erp-architecture/` — Mimari felsefe
