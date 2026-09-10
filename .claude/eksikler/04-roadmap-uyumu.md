# ReFactorRoadmap.md ile Envanter Uyumu

Bu dosya, mevcut `.claude/ReFactorRoadmap.md` ile bu envanterdeki
eksikler listesinin eşleşmesini gösterir. Hangi aşama tamamlandı,
hangisi yarım kaldı, hangisi roadmap'de yok.

## Aşama 1 — Altyapı ve Kod Organizasyonu

| Madde | Roadmap durumu | Envanter eşleşmesi | Gerçek durum |
|---|---|---|---|
| 1.1 Global → State | Planlandı | Eksik #4 (utils/) | **Kısmen tamam** — `state.js` var, ama global'ler hâlâ kullanımda |
| 1.2 Sabitler → config.js | Planlandı | Eksik #2 (design tokens) | **Kısmen tamam** — JS sabitleri config.js'te, CSS sabitleri (renk/spacing) inline |
| 1.3 Helper → utils/ | Planlandı | Eksik #4 | **Tamamlanmamış** — g(), v(), cl() hâlâ ui.js'te global |
| 1.4 Autocomplete tekilleştirme | Planlandı | Eksik #1 (component kütüphanesi) | **Tamamlanmamış** — 4 kopya hâlâ var |

**Aşama 1 özet:** ~%30 tamam. JS state/sabit tarafı iyi, ama utils
ayrıştırma + autocomplete tekilleştirme beklemede.

## Aşama 2 — Veri Yönetimi

| Madde | Roadmap durumu | Envanter eşleşmesi | Gerçek durum |
|---|---|---|---|
| 2.1 write() bölünmesi | Planlandı | — (UI değil, veri katmanı) | Kapsam dışı (bu envanter UI odaklı) |
| 2.2 Sync motoru (retry) | Planlandı | — | Kapsam dışı |
| 2.3 IDB index optimizasyonu | Planlandı | — | Kapsam dışı |
| 2.4 RPC optimistic update | Planlandı | — | Kapsam dışı |

**Aşama 2 özet:** UI envanteri kapsamı dışında. Veri katmanı işi.

## Aşama 3 — UI ve Render

| Madde | Roadmap durumu | Envanter eşleşmesi | Gerçek durum |
|---|---|---|---|
| 3.1 Render motoru | Planlandı | Eksik #5 | **Tamamlanmamış** — innerHTML full replace devam |
| 3.2 Olay yönetimi (delegation) | Planlandı | Eksik #1 dolaylı | **Tamamlanmamış** — HTML onclick'ler hâlâ yaygın |
| 3.3 Modal → sınıf | Planlandı | Eksik #1 | **Tamamlanmamış** |
| 3.4 Toast geliştirme | Planlandı | Eksik #1 | **Tamamlanmamış** |

**Aşama 3 özet:** Hemen hemen hiç tamamlanmamış. En büyük fırsat alanı.

## Roadmap'de OLMAYAN ama eksikler envanterinde OLAN

| Envanter # | Eksik | Neden roadmap'de yok |
|---|---|---|
| 2 | CSS + design tokens | Roadmap sadece JS odaklı, CSS atlanmış |
| 3 | UI/UX review skill | Roadmap süreç/akış değil, kod değişikliği odaklı |
| 6 | a11y kontrolü | Hiç düşünülmemiş |
| 7 | i18n altyapısı | MVP-TR olduğu için roadmap'e alınmamış |
| 8 | Component dev ortamı | Storybook/MDX gibi tooling MVP gerekmiyor |
| 9 | Performance budget | Lighthouse/CWV ölçümü roadmap'te yok |
| 10 | Mock fixtures | Offline development roadmap'te yok |
| 11 | Breakpoint standardı | Mobile-first tasarım kararı verilmemiş |
| 12-15 | Tool eksikleri | Custom MCP tool geliştirme roadmap'te yok |

## Birleşik yol haritası önerisi

Eğer tüm UI/Tasarım/Refactor eksiklerini kapatmak istersek, roadmap'in
genişletilmiş hali:

### Faz A — Hızlı kazanımlar (1-2 hafta)

1. **utils/ dizini** (Eksik #4) — 1 oturum
2. **UI/UX review skill** (Eksik #3) — 1 oturum
3. **Component dev ortamı** (Eksik #8) — yarım oturum
4. **Breakpoint standardı + ADR** (Eksik #11) — yarım oturum

### Faz B — Component kütüphanesi (2-3 hafta)

5. **Autocomplete.js** (Roadmap 1.4 + Eksik #1 parça)
6. **Modal.js** (Roadmap 3.3 + Eksik #1 parça)
7. **Toast.js** (Roadmap 3.4 + Eksik #1 parça)
8. **Event delegation** (Roadmap 3.2) — onclick'leri temizle

### Faz C — CSS + Render (2-3 hafta)

9. **Design tokens** (Eksik #2) — `css/tokens.css` + `js/design-tokens.js`
10. **CSS ayrıştırma** (Eksik #2 devam) — `css/{layout,components,pages}.css`
11. **Render motoru** (Roadmap 3.1 + Eksik #5) — lit-html veya morphdom
12. **a11y geçişi** (Eksik #6) — modal/buton/input'a aria + focus trap

### Faz D — Ölçüm ve kalite (1 hafta)

13. **Performance budget** (Eksik #9) — Lighthouse CI
14. **Mock fixtures** (Eksik #10) — dev ortamı
15. **i18n altyapısı** (Eksik #7) — geleceğe yatırım

### Faz E — Tool otomasyonu (sürekli)

16-19. **ui-snapshot, token validator, A/B test, visual regression**
(ihtiyaç oldukça)

## Notlar

- Bu envanter **UI/Refactor** odaklı. Veri katmanı (Aşama 2) ve mimari
  kararlar (ADR'ler) kapsam dışı.
- Öncelikler "MVP'yi bitir" hedefiyle — i18n, A/B test gibi post-MVP
  öğeler bilinçli olarak öteleniyor.
- Her Faz → spec-writer → conductor → worker → tester → reviewer
  standart akışıyla yürütülmeli.
