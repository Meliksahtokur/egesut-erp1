# Bulunan Dış Skill'ler — find-skills Taraması (2026-06-10)

> **Amaç:** `npx skills find` ile UI/UX kategorisinde keşfedilen, kurulabilir
> external skill'lerin listesi. Her biri için install sayısı, kaynak
> güvenilirliği, EgeSüt ERP'ye uygunluk değerlendirmesi.
>
> **Tarama:** 9 anahtar kelime (ui design, ux review, accessibility,
> design system, frontend, vanilla js, css design tokens, lighthouse,
> modal/toast, mobile-first, lit-html)
>
> **Kural (find-skills SKILL.md):** 1K+ install tercih edilir, <100
> install şüpheli. Resmi kaynaklar (vercel-labs, anthropics,
> microsoft, addyosmani) güvenilir.

---

## ⭐ Tier 1 — Yüksek Öncelik (1K+ install, güvenilir kaynak)

| # | Skill | Install | Kaynak | Kategori | Neden önemli? |
|---|---|---|---|---|---|
| 1 | **`anthropics/skills@frontend-design`** | **522.6K** | Anthropic (resmi) | Frontend Design | Açık ara lider. Anthropic'in kendi UI tasarım rehberi. |
| 2 | **`leonxlnx/taste-skill@design-taste-frontend`** | 129K | Topluluk | Frontend Design | "Taste" — kaliteli frontend estetiği için rehber |
| 3 | `leonxlnx/taste-skill@imagegen-frontend-web` | 68.3K | Topluluk | Frontend Design | Web görseli tasarım kalıpları |
| 4 | `leonxlnx/taste-skill@imagegen-frontend-mobile` | 66.6K | Topluluk | Mobile | Mobil görsel tasarım kalıpları |
| 5 | `pbakaus/impeccable@frontend-design` | 53.7K | Topluluk | Frontend Design | "Hatasız" frontend design kuralları |
| 6 | `leonxlnx/taste-skill@design-taste-frontend-v1` | 33.7K | Topluluk | Frontend Design | v1 — hâlâ aktif |
| 7 | **`nextlevelbuilder/ui-ux-pro-max-skill@ckm:design-system`** | **26.9K** | Topluluk | Design System | En popüler design system skill'i |
| 8 | **`addyosmani/web-quality-skills@accessibility`** | **26.7K** | Addy Osmani (Google) | Accessibility | A11y kontrolü — Google'ın web quality ekibinden |
| 9 | `leonxlnx/taste-skill@design-taste-frontend-v1` | (yukarıda) | — | — | — |
| 10 | `refoundai/lenny-skills@design-systems` | 1.5K | Topluluk | Design System | Lenny's podcast'ten design system dersleri |
| 11 | `chromedevtools/chrome-devtools-mcp@a11y-debugging` | 1.1K | Google (Chrome DevTools) | Accessibility + Debug | Chrome DevTools MCP ile a11y debug — **MCP tool olarak mevcut** |
| 12 | `hoodini/ai-agents-skills@mobile-responsiveness` | 736 | Topluluk | Mobile | Mobile responsive kontrol listesi |
| 13 | `kostja94/marketing-skills@mobile-friendly` | 734 | Topluluk | Mobile | Mobile-friendly rehber |
| 14 | `aj-geddes/useful-ai-prompts@responsive-web-design` | 731 | Topluluk | Mobile | Responsive design prompt'ları |
| 15 | `aj-geddes/useful-ai-prompts@mobile-first-design` | 626 | Topluluk | Mobile | Mobile-first design pattern'ları |
| 16 | `davila7/claude-code-templates@accessibility` | 323 | Topluluk | Accessibility | a11y template/checklist |
| 17 | `secondsky/claude-skills@mobile-first-design` | 320 | Topluluk | Mobile | Mobile-first design |
| 18 | `shajith003/awesome-claude-skills@ui-design` | 2.8K | Topluluk | UI Design | Genel UI design rehberi |

---

## 🟡 Tier 2 — Orta Öncelik (100-1K install, kaynak değerlendirmesi gerekli)

| # | Skill | Install | Kategori | Not |
|---|---|---|---|---|
| 19 | `jeffallan/claude-skills@vue-expert-js` | 2.3K | Component | Vue.js — **biz Vanilla JS, ama component pattern ilhamı** |
| 20 | `jwynia/agent-skills@frontend-design` | 2.3K | Frontend Design | Alternatif frontend design rehberi |
| 21 | `hairyf/skills@motion` | 850 | Animation | Motion/animation skill'i |
| 22 | `asyrafhussin/agent-skills@web-design-guidelines` | 186 | Web Design | Web design guidelines |
| 23 | `tech-leads-club/agent-skills@perf-lighthouse` | 168 | Performance | Lighthouse performans |
| 24 | `guia-matthieu/clawfu-skills@lighthouse-audit` | 133 | Performance | Lighthouse audit |
| 25 | `dylanfeltus/skills@design-tokens` | 145 | Design Tokens | **Doğrudan ihtiyacımız** — design token sistemi |
| 26 | `erichowens/some_claude_skills@design-system-creator` | 137 | Design System | Design system oluşturma |
| 27 | `yonatangross/orchestkit@design-system-tokens` | 107 | Design Tokens | Design system tokens |
| 28 | `travisjneuman/.claude@accessibility-a11y` | 111 | Accessibility | a11y |
| 29 | `akillness/oh-my-skills@frontend-design-system` | 258 | Design System | Frontend design system |
| 30 | `onnokh/lighthouse@lighthouse` | 283 | Performance | Lighthouse |
| 31 | `yonatangross/orchestkit@interaction-patterns` | 96 | UX Patterns | Modal/dialog pattern'ları |
| 32 | `gohypergiant/agent-skills@accelint-design-foundation` | 84 | Design System | Accelint design foundation |
| 33 | `laurigates/claude-plugins@design-tokens` | 75 | Design Tokens | Design tokens |
| 34 | `nickcrew/claude-ctx-plugin@ux-review` | 63 | UX Review | UX review checklist |
| 35 | `eyadsibai/ltk@accessibility` | 59 | Accessibility | a11y |
| 36 | `shinpr/claude-code-workflows@recipe-front-design` | 48 | Frontend Design | Frontend design recipe |
| 37 | `majesticlabs-dev/majestic-marketplace@dialog-patterns` | 40 | UX Patterns | Dialog patterns |
| 38 | `faionfaion/faion-network@faion-ux-ui-designer` | 29 | UX/UI | UX/UI designer |
| 39 | `404kidwiz/claude-supercode-skills@ui-designer` | 121 | UI Designer | UI designer |

---

## 🟢 Tier 3 — Düşük Öncelik (<100 install, dikkatli değerlendir)

| # | Skill | Install | Kategori | Not |
|---|---|---|---|---|
| 40 | `yunshu0909/yunshu_skillshub@ui-design` | 88 | UI Design | — |
| 41 | `mthines/agent-skills@ux` | 16 | UX | UX |
| 42 | `omer-metin/skills-for-antigravity@ui-design` | 55 | UI Design | — |
| 43 | `sjnims/bootstrap-expert@bootstrap-components` | 68 | Component | Bootstrap — biz Vanilla |
| 44 | `membranedev/application-skills@toast` | 56 | Component | Toast pattern |
| 45 | `ancoleman/ai-design-components@providing-feedback` | 44 | UX | Feedback pattern |
| 46 | `yiyousiow000814/xauusd-calendar-agent@ui-check-framework` | 40 | UI | UI check framework |
| 47 | `membranedev/application-skills@lighthouse` | 67 | Performance | Lighthouse |
| 48 | `santiagoxor/pintureria-digital@lighthouse-audit` | 18 | Performance | — |
| 49 | `bbeierle12/skill-mcp-claude@form-vanilla` | 51 | Form | Vanilla form |
| 50 | `farmage/opencode-skills@vue-expert-js` | 42 | Component | Vue |
| 51 | `gopherguides/gopher-ai@templui` | 39 | Component | TemplUI |
| 52 | `rodydavis/skills@*` (lit-and-*) | 40-54 | Lit-html | Lit-html örnekleri (render motoru) |

---

## 🎯 EgeSüt ERP'ye En Uygun 10 Skill (Sıralı Öneri)

| Sıra | Skill | Neden | Kurulum |
|---|---|---|---|
| 1 | **`anthropics/skills@frontend-design`** (522.6K) | Açık ara en popüler. Anthropic resmi. UI genel rehberi. | `npx skills add anthropics/skills@frontend-design -g -y` |
| 2 | **`addyosmani/web-quality-skills@accessibility`** (26.7K) | **Eksik #6'yı (a11y) doğrudan kapatır.** Google'ın web quality ekibinden. | `npx skills add addyosmani/web-quality-skills@accessibility -g -y` |
| 3 | **`nextlevelbuilder/ui-ux-pro-max-skill@ckm:design-system`** (26.9K) | **Eksik #2 (design tokens) ve Eksik #3 (UI/UX review skill)** için rehber. | `npx skills add nextlevelbuilder/ui-ux-pro-max-skill -g -y` |
| 4 | **`pbakaus/impeccable@frontend-design`** (53.7K) | "Hatasız" frontend — best practices rehberi. ui.js 2804 satırı düzeltmek için iyi. | `npx skills add pbakaus/impeccable@frontend-design -g -y` |
| 5 | `chromedevtools/chrome-devtools-mcp@a11y-debugging` (1.1K) | **MCP tool olarak** a11y debug — bizim tools-bank MCP'ye entegre olabilir. | `npx skills add chromedevtools/chrome-devtools-mcp@a11y-debugging -g -y` |
| 6 | `leonxlnx/taste-skill@design-taste-frontend` (129K) | UI estetik rehberi — "taste" kavramı. | `npx skills add leonxlnx/taste-skill@design-taste-frontend -g -y` |
| 7 | `refoundai/lenny-skills@design-systems` (1.5K) | Design system stratejisi (Lenny's podcast). | `npx skills add refoundai/lenny-skills@design-systems -g -y` |
| 8 | `dylanfeltus/skills@design-tokens` (145) | **Eksik #2 (design tokens)** için spesifik skill. | `npx skills add dylanfeltus/skills@design-tokens -g -y` |
| 9 | `tech-leads-club/agent-skills@perf-lighthouse` (168) | **Eksik #9 (performance budget)** için. | `npx skills add tech-leads-club/agent-skills@perf-lighthouse -g -y` |
| 10 | `nickcrew/claude-ctx-plugin@ux-review` (63) | **Eksik #3 (UI/UX review skill)** için alternatif. | `npx skills add nickcrew/claude-ctx-plugin@ux-review -g -y` |

---

## 📦 Hangi Eksik Nereyle Kapanır?

| Envanter Eksik | Dış Skill Çözümü | Tür |
|---|---|---|
| #1 Component kütüphanesi | `pbakaus/impeccable@frontend-design` + Vanilla JS pattern'leri | Skill + Manuel |
| #2 Design token + CSS | `dylanfeltus/skills@design-tokens` + `nextlevelbuilder/ui-ux-pro-max-skill@ckm:design-system` | Skill |
| #3 UI/UX review skill | `nextlevelbuilder/ui-ux-pro-max-skill` + `nickcrew/claude-ctx-plugin@ux-review` | Skill |
| #4 utils/ dizini | (dış skill yok — manuel) | Manuel |
| #5 Render motoru | `rodydavis/skills@*` (lit-html örnekleri) + `pbakaus/impeccable` | Skill + Manuel |
| #6 a11y | **`addyosmani/web-quality-skills@accessibility`** + `chromedevtools/chrome-devtools-mcp@a11y-debugging` | Skill + MCP |
| #7 i18n | (dış skill bulunamadı) | Manuel |
| #8 Component dev ortamı | (Storybook yerine: `dev-components.html` manual) | Manuel |
| #9 Performance budget | `tech-leads-club/agent-skills@perf-lighthouse` + `onnokh/lighthouse@lighthouse` | Skill |
| #10 Mock fixtures | (dış skill bulunamadı) | Manuel |
| #11 Breakpoint standardı | `secondsky/claude-skills@mobile-first-design` + `aj-geddes/useful-ai-prompts@mobile-first-design` | Skill + Manuel |

---

## ⚠️ Bulunamayanlar

Aşağıdaki konularda yeterli install sayısına sahip bir skill **bulunamadı**:

- **i18n / localization** — dil altyapısı için spesifik skill yok
- **Mock data / fixtures** — geliştirme ortamı için spesifik skill yok
- **Storybook / component dev ortamı** — vanilla JS için izole geliştirme ortamı skill'i yok
- **Visual regression testi** — Percy/Chromatic eşdeğeri bulunamadı
- **i18n operasyonel tooling** — `t()` fonksiyonu pattern'ı için skill yok

Bu eksikler **manuel olarak** veya **kendi skill'imizi yazarak** kapatılmalı.

---

## 📥 Kurulum Planı (Önerilen Sıra)

```bash
# Tier 1 — Hemen kur (yüksek değer, düşük risk)
npx skills add anthropics/skills@frontend-design -g -y
npx skills add addyosmani/web-quality-skills@accessibility -g -y
npx skills add nextlevelbuilder/ui-ux-pro-max-skill -g -y
npx skills add pbakaus/impeccable@frontend-design -g -y

# Tier 2 — İhtiyaç oldukça
npx skills add chromedevtools/chrome-devtools-mcp@a11y-debugging -g -y
npx skills add dylanfeltus/skills@design-tokens -g -y
npx skills add tech-leads-club/agent-skills@perf-lighthouse -g -y

# Manuel / Özel
# i18n, fixtures, Storybook eşdeğeri → kendi skill'imizi yaz
```

---

## 🔍 Tarama Metodolojisi

Her arama için:
1. `npx skills find "<keyword>"` — sonuçları listele
2. Install sayısına göre sırala
3. Kaynak güvenilirliği (1K+ = güvenli, <100 = şüpheli)
4. EgeSüt ERP bağlamıyla eşleştir (Eksik # → Skill)

**Toplam aranan keyword sayısı:** 11
**Toplam bulunan unique skill sayısı:** 52
**EgeSüt için uygun bulunan:** 10 (Tier 1 + Tier 2 en iyileri)

---

*Araştırma: 2026-06-10 06:27 | Goose worker + find-skills skill*
