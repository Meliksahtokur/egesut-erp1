# Kombinasyon Tarifleri — 5 Tipik Senaryo

## Senaryo A — "Modal'ı yeniden tasarla" (feature/UX değişikliği)

```
1. find-skills (load_skill)               → "modal/ux skill var mı?"
2. feature-dev (load_skill)              → explore → clarify → design → implement
3. ast_grep_search("openM($$$)", path=js/) → modal çağrı yerleri
4. gitnexus_context("openM")              → callers/callees
5. gitnexus_impact("openM", upstream)     → blast radius
6. spec-writer recipe                     → tasarımı spec'e dök
7. worker (egesut recipe)                 → implement
8. tester recipe                          → test raporu
9. reviewer recipe                        → kabul/ret
10. session-update (load_skill)           → memory + handoff güncelle
```

**Çıktılar:**
- Spec: `.claude/specs/{tarih}-{konu}.md`
- Code: `js/ui.js` (veya yeni `js/components/Modal.js`)
- Test raporu: `/root/tools-bank/reports/test-{spec-id}.md`
- Review: `.claude/reviews/{review-id}.md`
- Memory: tools-bank memory_search'te erişilebilir

## Senaryo B — "ui.js'i parçala" (büyük refactor — yol haritası Aşama 3)

```
1. gitnexus-refactoring (load_skill)      → rename/extract/split kuralları
2. sonar_duplications                     → duplikasyon adayları
3. gitnexus_impact her hedef sembol için  → kırılma riski
4. ui-map.md oku                          → paralel dispatch haritası
5. orchestrator recipe                    → spec tasarla (adımlar + recipe ataması)
6. conductor recipe                       → adımları sırayla worker'lara dağıt
   ├─ worker (modül-1: openM/closeM → utils/modal.js)
   ├─ worker (modül-2: autocomplete'ler → components/Autocomplete.js)
   └─ worker (modül-3: render fonksiyonları → ui/ klasörü)
   NOT: ui-map.md'ye göre paralel worker'lar AYNI dosyaya yazmamalı
7. tester her adım sonrası
8. reviewer son kalite kontrol
9. session-update                         → refactor kararları memory'ye
10. hookify.check-duplicates              → duplikasyon guard aktif mi kontrol
```

**Kritik guard:** `ui-map.md` "Aynı dosyaya iki worker yazmamalı" diyor
(örn. 126-540 satır aralığını iki agent'a parçala).

## Senaryo C — "UI bug'ı" (debug + fix)

```
1. gitnexus-debugging (load_skill)        → trace protokolü
2. memory_search "bu bug daha önce çıktı mı"
3. gitnexus_query("bug semptomu")         → etkilenen flow
4. gitnexus_context(suspect symbol)       → 360°
5. ast_grep_search                        → semptomun tekrar ettiği yerler
6. gitnexus_impact                        → düzeltmenin yan etkisi
7. spec-writer                            → fix spec
8. worker (egesut)                        → uygula
9. tester → reviewer → session-update
```

## Senaryo D — "Yeni component ekle" (örn. YeniCombobox)

```
1. feature-dev (load_skill)
2. ast_grep_search("setupAutocomplete")   → mevcut pattern
3. gitnexus_context("setupAutocomplete")  → callers
4. ReFactorRoadmap.md 1.4 oku            → hedef API imzası
5. spec-writer                            → component spec
6. worker (egesut)                        → js/components/Combobox.js + entegrasyon
7. tester + reviewer
8. session-update                         → component kütüphanesi kararı
```

## Senaryo E — "CSS'i ayrıştır + design token sistemi kur" (Aşama 1.2 tamamla)

```
1. ast_grep_search("#[0-9a-f]{3,6}", path=index.html) → renk tekrarları
2. sonar_duplications                     → CSS duplikasyonu
3. gitnexus_query("style", "css")         → mevcut CSS dağılımı
4. orchestrator                           → büyük refactor spec'i
   ├─ Adım 1: design-tokens.js (renkler, spacing, typography)
   ├─ Adım 2: css/tokens.css (token consumer)
   ├─ Adım 3: css/{layout,components,pages}.css
   └─ Adım 4: index.html inline <style> kaldır, <link> ekle
5. conductor → worker (paralel: farklı CSS dosyalarına yaz)
6. tester + reviewer + session-update
7. memory_add("design token kararları", category=tech_stack)
```

## Genel kurallar (her senaryo için)

1. **Onay al** — DB değişikliği veya feature eklenmeden önce orkestratöre sor
2. **Hookify aktif** — `blast-radius-guard`, `block-direct-writes`, `check-duplicates`, `protect-critical-files`
3. **Commit + push** — her önemli adım
4. **session-update** — oturum sonunda memory + handoff
5. **ui-map.md** — ui.js'e dokunmadan önce oku
6. **ReFactorRoadmap.md** — refactor kararı öncesi oku
7. **GitNexus index staleness** — uyarı gelirse `npx gitnexus analyze`
