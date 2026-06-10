# Önerilen Yol Haritası — UI/Tasarım/Refactor (2026-06-10)

> **Amaç:** find-skills taraması + mevcut envanter birleştirilerek
> EgeSüt ERP'nin UI/tasarım/refactor ihtiyaçları için sıralı, efor-tahminli
> bir yol haritası.
>
> **Girdiler:** `01-mevcut-araclar.md`, `03-eksikler-detay.md`,
> `04-roadmap-uyumu.md`, `05-bulunan-skill-listesi.md`,
> `06-eksikler-done-durumu.md`
>
> **Kapsam:** UI/UX odaklı. Veri katmanı (Aşama 2) kapsam dışı.

---

## Prensip

1. **Hızlı kazanımlar önce** — Dış skill kurulumu + düşük efor = anlık değer
2. **Manuel/özel geliştirme sonra** — Component kütüphanesi, design tokens
3. **Ölçüm her zaman** — Performance budget, a11y skoru her aşamada
4. **Commit + push = iş kanıtı** — her önemli adım
5. **Onay gate** — DB/feature değişikliği öncesi orkestratör onayı

---

## Faz 0 — Hemen (1 oturum, ~30 dakika)

**Amaç:** Dış skill'leri kur, envanteri yeşert, baseline ölç.

### Adımlar

| # | İş | Komut/Süre | Dış Skill |
|---|---|---|---|
| 0.1 | Tier 1 UI skill'leri kur | 4 ayrı `npx skills add` | `anthropics/skills@frontend-design` (522.6K) |
| 0.2 | a11y skill'i kur | `npx skills add` | `addyosmani/web-quality-skills@accessibility` (26.7K) |
| 0.3 | Design system skill'i kur | `npx skills add` | `nextlevelbuilder/ui-ux-pro-max-skill` (26.9K) |
| 0.4 | Frontend best practice | `npx skills add` | `pbakaus/impeccable@frontend-design` (53.7K) |
| 0.5 | Envanteri commit + push | `git add . && git commit -m "..."` | (manuel) |

### Çıktılar
- `~/.claude/skills/` altında 4 yeni skill yüklü
- `.claude/eksikler/` dizininde 7 dosyalı envanter
- Git history'de yeşil checklist

### Onay
Bu adım **onay gerektirmez** — sadece dış skill kurulumu + envanter yazma.

---

## Faz A — Hızlı Kazanımlar (1-2 hafta, 4-5 oturum)

**Amaç:** Düşük efor / yüksek değer işler.

| # | İş | Efor | Dış Skill | Envanter # |
|---|---|---|---|---|
| A.1 | **utils/ dizini oluştur** | 1 oturum | (dış skill yok — `pbakaus/impeccable` rehberliğinde) | #4 |
| A.2 | **UI/UX review skill'i yaz** | 1 oturum | `nextlevelbuilder` + `nickcrew/claude-ctx-plugin@ux-review` rehberliğinde | #3 |
| A.3 | **Component dev ortamı (kitchen sink)** | Yarım oturum | (dış skill yok) | #8 |
| A.4 | **Mobile-first breakpoint ADR** | Yarım oturum | `secondsky/claude-skills@mobile-first-design` | #11 |
| A.5 | **a11y baseline ölçümü** | Yarım oturum | `addyosmani/web-quality-skills@accessibility` | #6 |
| A.6 | **Performance baseline (Lighthouse)** | Yarım oturum | `tech-leads-club/agent-skills@perf-lighthouse` | #9 |

### Standart iş akışı (her oturum)
```
1. find-skills (gerekirse yeni skill keşfi)
2. spec-writer recipe → spec yaz
3. ast_grep_search + gitnexus_impact → risk analizi
4. orchestrator/conductor → iş böl
5. worker (egesut) → implement
6. tester → test raporu
7. reviewer → kabul/ret
8. session-update → memory + handoff
9. git commit + push
```

### Çıktılar
- `js/utils/{helpers,dom,modal,formatters}.js` — yeni dosyalar
- `~/.claude/skills/ui-review/SKILL.md` — yeni internal skill
- `dev-components.html` — kitchen sink
- `.claude/arch-decisions/ADR-008-mobile-first.md` — yeni ADR
- `lighthouse-baseline.md` — ilk ölçüm raporu

---

## Faz B — Component Kütüphanesi (2-3 hafta, 5-6 oturum)

**Amaç:** ui.js 2804 satırdan component'lere geçiş.

| # | İş | Efor | Dış Skill | Envanter # |
|---|---|---|---|---|
| B.1 | **Autocomplete.js** (4 kopya → 1) | 1 oturum | `pbakaus/impeccable` (component pattern) | #1 |
| B.2 | **Modal.js** (4 kopya → 1, sınıf bazlı) | 1 oturum | `nextlevelbuilder/ui-ux-pro-max-skill` (modal pattern) | #1 |
| B.3 | **Toast.js** (kuyruk bazlı) | Yarım oturum | `membranedev/application-skills@toast` (56) | #1 |
| B.4 | **FormField.js** (input + label + error) | Yarım oturum | (manuel) | #1 |
| B.5 | **Event delegation** (onclick'leri temizle) | 1-2 oturum | (dış skill yok) | #3.2 |
| B.6 | **Component test'leri** (Playwright) | 1 oturum | (CI zaten var) | #1 |

### Öncelik sırası
1. **B.1 Autocomplete** (en çok kopya, en basit API)
2. **B.2 Modal** (en karmaşık — doğru başlamak önemli)
3. **B.3 Toast** (küçük, bağımsız)
4. **B.4 FormField** (Modal/Form'lar bittikten sonra)
5. **B.5 Event delegation** (büyük refactor — sadece ihtiyaç oldukça)
6. **B.6 Test'ler** (sürekli)

### Çıktılar
- `js/components/{Autocomplete,Modal,Toast,FormField}.js` — yeni sınıflar
- `js/components/index.js` — barrel export
- `js/ui.js` 2804 → ~2000 satır (kademeli düşüş)

---

## Faz C — Design Tokens + CSS Ayrıştırma (1-2 hafta, 3-4 oturum)

**Amaç:** Tema/renk/spacing tutarlılığı + CDN bundle optimizasyonu.

| # | İş | Efor | Dış Skill | Envanter # |
|---|---|---|---|---|
| C.1 | **Token envanteri** (renkler, spacing, typography) | Yarım oturum | `dylanfeltus/skills@design-tokens` (145) | #2 |
| C.2 | **css/tokens.css** (CSS değişkenleri) | Yarım oturum | `nextlevelbuilder/ui-ux-pro-max-skill@ckm:design-system` | #2 |
| C.3 | **js/design-tokens.js** (JS tüketiciler) | Yarım oturum | (manuel) | #2 |
| C.4 | **css/{layout,components,pages}.css** bölünmüş | 1 oturum | (dış skill yok) | #2 |
| C.5 | **index.html inline `<style>` → `<link>`** | Yarım oturum | (dış skill yok) | #2 |

### Çıktılar
- `css/tokens.css` — `:root { --color-primary: ...; }`
- `js/design-tokens.js` — `TOKENS.color.primary`
- `css/{layout,components,pages}.css` — 3 dosya
- `index.html` — `<link rel="stylesheet" href="css/...">`
- Koyu tema desteği (gelecekte)

---

## Faz D — Render Motoru (1-2 hafta, 2-3 oturum)

**Amaç:** 130+ hayvan listesinde performans, focus kaybı çözümü.

| # | İş | Efor | Dış Skill | Envanter # |
|---|---|---|---|---|
| D.1 | **lit-html veya morphdom kararı** | Yarım oturum | `rodydavis/skills@lit-and-monaco-editor` (41) | #5 |
| D.2 | **insertAdjacentHTML ile parçalı güncelleme** (acil) | 1 oturum | (dış skill yok) | #5 |
| D.3 | **lit-html/morphdom entegrasyonu** | 1-2 oturum | `rodydavis` | #5 |

### Çıktılar
- `js/render/diff.js` — minimal diff
- Render süresi ölçümü (lighthouse-baseline.md karşılaştırması)
- Focus/scroll pozisyon korunmuş

---

## Faz E — Kalite & Ölçüm (sürekli, haftalık)

**Amaç:** Regresyonu önlemek, kaliteyi sürdürmek.

| # | İş | Efor | Sıklık |
|---|---|---|---|
| E.1 | **Lighthouse CI** (PR'larda otomatik) | 1 oturum kurulum + sürekli | her PR |
| E.2 | **axe-core CI** (a11y testi) | Yarım oturum + sürekli | her PR |
| E.3 | **Bundle size guard** | Yarım oturum | her commit |
| E.4 | **ui-snapshot MCP tool** | 1 oturum (Claude yapar) | ihtiyaç oldukça |
| E.5 | **ui-review skill aktif kullanım** | sürekli | her refactor öncesi |

### Çıktılar
- `.github/workflows/lighthouse.yml`
- `tools-bank/mcp_server/server.py` — yeni `ui_snapshot` tool
- `tools-bank/memory/` — Lighthouse raporları

---

## Faz F — Gelecek / Post-MVP (N hafta, gerektiğinde)

**Amaç:** Uzun vadeli, MVP sonrası.

| # | İş | Öncelik |
|---|---|---|
| F.1 | i18n altyapısı (TR/EN) | 🟢 MVP sonrası |
| F.2 | Mock fixtures + offline dev | 🟢 MVP sonrası |
| F.3 | Virtual scrolling (130+ liste) | 🟡 Performans kritikleşirse |
| F.4 | A/B test altyapısı | 🟢 MVP sonrası |
| F.5 | Visual regression testi | 🟡 Görsel regresyon sık olursa |

---

## Toplam Tahmin

| Faz | Oturum | Süre | Çıktı |
|---|---|---|---|
| Faz 0 | 1 | 30 dk | Dış skill kurulumu |
| Faz A | 4-5 | 1-2 hafta | utils/, ui-review skill, ADR, baseline ölçüm |
| Faz B | 5-6 | 2-3 hafta | Component kütüphanesi |
| Faz C | 3-4 | 1-2 hafta | Design tokens + CSS |
| Faz D | 2-3 | 1-2 hafta | Render motoru |
| Faz E | sürekli | haftalık | CI + ölçüm |
| Faz F | gerektiğinde | — | Gelecek |
| **Toplam (Faz 0-E)** | **~20** | **~8 hafta** | Modern UI/UX sistemi |

---

## Karar Noktaları (Orchestrator'a Sor)

Şu an Faz 0'dayız. **Hangi Faz'dan başlamak istiyorsun?**

- **Seçenek 1:** Faz 0'ı hemen uygula (skill kurulumu), sonra Faz A'ya geç
- **Seçenek 2:** Faz 0 + Faz A.6 (a11y baseline) — hızlı değer
- **Seçenek 3:** Doğrudan Faz B.1 (Autocomplete) — en yüksek kopya sayısı
- **Seçenek 4:** Sadece envanteri yeşert, roadmap'i onayla — sonra karar ver

---

*Oluşturuldu: 2026-06-10 06:40 | Goose worker*
