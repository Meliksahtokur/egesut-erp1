# impl-P5 — GOREV zarfı: sayfa iskeleti + gezinme sözleşmesi

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P5** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:482-5xx` (P5 bölümünün tamamı — MADDE DRIFT KAPISI: yalnız P5; render P6'nın)
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P5-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P5-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `index.html` (MODIFY — yeni `#pg-ovsync` bloğu, .pg deseni [index.html:68-70])
2. `js/app.js` (MODIFY — goTo zinciri :124-129'a dal; scroll kancası :104-132)
3. `js/ui.js` (MODIFY — YALNIZ `loadOvsyncDash()` iskeleti; render P6'nın işi — dar kapsam istisnası, plan Files listesi gereği)
4. `js/utils/handlers.js` (MODIFY — `data-action` kayıtları)
5. `tests/unit/ovsync-gezinti.test.js` (create — P11 kırmızı iskeleti: offline/bayat durum matrisi)
6. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P5-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod değişikliği öncesi:** `.harness/references/domain-rules.md` + `.harness/references/ui-map.md` + `code-change-precheck` skill; JS keşfinde ÖNCE `atlas_query`, sonra bitişik JSDoc+gövde.
3. **Kırmızı test ÖNCE:** offline/bayat durum matrisi testi kirmizi görülür, sonra uygulama.
4. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli; `node --check` tüm değişen JS + test koşumu.

## Görev (plan P5 birebir — plan.md:492-500+; bölümün tamamını oku)

**Arayüz (Produces):**
- `async function loadOvsyncDash()` — durum üretimi: (i) `bayrak_kapali` → açık mesaj "Ovsync/PG kuralları kapalı — takip verisi yok"; (ii) `{bayat:true, veri}` → bayat etiket `"çevrimdışı · HH:MM verisi"` + bayat içerik; (iii) `veri:null` → "İnternet yok — takip verisi alınamadı"; (iv) taze → render (P6 — P5'te yer tutucu).

**İş:**
1. `#pg-ovsync` iskeleti: başlıkta `‹` geri butonu `data-action="nav-geri"` (mevcut handler history.back [handlers.js:48,562-564] — R13: `goTo('dash')` DEĞİL, dokunma).
2. `goTo` zincirine `else if (pg === 'ovsync') { loadOvsyncDash(); }`; pushState/popstate jenerik akışa katılır [app.js:221].
3. Scroll sözleşmesi: ovsync'ten ayrılırken `window._ovsyncScrollY` kaydet; `loadOvsyncDash` render sonrası geri yükle (§6b).
4. Gezinme durumu: `window._curOvsyncPadok`, `window._curOvsyncBolum{acik}`.
5. handlers.js'e yeni `data-action` kayıtları (yalnız iskeletin gerektirdikler).

## Kabul ölçütleri

1. Durum matrisi testi yeşil (4 durum: bayrak_kapalı / bayat / veri:null / taze-yer-tutucu).
2. `node --check` tüm değişen JS; `git diff --check` temiz.
3. Kırmızı→yeşil sırası kanıtı (DONE'da iki koşum çıktısı).
4. R13 geri buton sözleşmesi: history.back — goTo('dash') YOK [CONFIRMED satır kanıtı].

## Yasaklar

- `js/api.js` yazımı (P4'ün dosyası); render implementasyonu (P6); `js/forms.js` (P9); `js/config.js`/`js/state.js` (yalnız planın atadığı maddeler — P5 değil).
- Router-managed modal deseni dışı link; mevcut .pg desenini bozma (üretim örneği index.html:68-70'den).
- Commit atma; PROD; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P5-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · kırmızı→yeşil çıktıları · yazılan dosyalar · açık kalem.
