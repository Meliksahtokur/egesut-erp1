# impl-P4 — GOREV zarfı: api.js takip veri katmanı + §6c kaydı + invalidate

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P4** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:459-480` (MADDE DRIFT KAPISI: yalnız P4; P5+ maddeleri YOK)
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P4-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P4-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `js/api.js` (MODIFY — RPC_TABLES :376 civarı; yeni fonksiyonlar dosya sonuna)
2. `tests/unit/ovsync-api.test.js` (create — P11 kırmızı iskelet, P4'ün kendi testi)
3. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P4-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod değişikliği öncesi:** `.harness/references/domain-rules.md` oku + `code-change-precheck` skill'i (js/api.js sembol değişikliği — blast radius); egesut'ta JS keşfi için ÖNCE `atlas_query` (atlas skill deseni), sonra bitişik JSDoc+gövde oku.
3. **Kırmızı test ÖNCE (plan P11 sözleşmesi):** RPC_TABLES üyelik + invalidate envanteri testlerini YAZ, KOŞ, KIRMIZI gör — sonra uygulama; yeşile çevir.
4. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli; `node --check js/api.js` + birim test koşumu kanıtı.

## Görev (plan P4 birebir — plan.md:466-476)

**Arayüzler (Produces):**
- `async function ovsyncTakipGetir(p_padok = null)` → `rpc('ovsync_takip_listele', …)`; başarıda `window.__ovsyncTakip = {veri, zaman: Date.now()}`; hata/offline'da throw DEĞİL `{bayat: true, veri: önceki|null}`; önbellek yoksa `veri: null` (UI açık mesaj).
- `async function tohumlamaBosVeDevam(params)` → `rpc('tohumlama_bos_ve_devam', params)`; `e.data` ile sunucu red kodlarını taşır.
- `function _ovsyncTakipInvalidate()` → `window.__ovsyncTakip = null`.

**İş:**
1. `RPC_TABLES`'a `tohumlama_bos_ve_devam: ['tohumlama','gorev_log','stok','stok_hareket','hayvanlar','islem_log','cases','treatment_days','treatment_day_uygulamalar']`. **`ovsync_takip_listele` HARİTA'YA GİRMEZ** (invariant `js/api.js:417-420` yanına yorum).
2. Invalidate noktaları — ortak yardımcı `_ovsyncTakipInvalidate()`: `ovsyncBaslat` [ui.js:1812], `_protokolIptalAkisi` [:1873], tohumlama kaydı [forms.js:426-433], `tohSonuc` gebe/bos [:4344-4368], muayene sonuç akışları (K15: `tohumlamaBosVeDevam` çağrılan her yer + görev tamamlama özel akışı P9 — P4 yalniz kendi invalidate çağrı noktalarını ekler; P9/P10 kendi akışlarını getirir), `gorev_ertele` + `vaka_kalan_gunleri_kaydir(_coklu)`, hızlı/seans/toplu PG, gebelik muayenesi sonucu (GEBE modu dahil). DİKKAT: ui.js/forms.js'teki invalidate ÇAĞRI NOKTALARI P9/P10'un işi — P4 yalniz api.js'teki yardımcıyı + api.js içi noktaları kurar; diğer dosyaların çağrıları grep-envanter testinde listelenir ama P4 zarfında YAZILMAZ (tek-yazıcı: ui.js P6+'nın, forms.js P9'un).
3. Offline: rpc() gerçek fetch hatasından tanınır (`navigator.onLine` ön koşulu YAZILMAZ — M-25).
4. **H8 — istemci 40P01/55P03 eşlemesi:** `rpc()`'nin hata satırında [js/api.js:93] kod dalı: `error.code === '40P01' || error.code === '55P03'` → `throw new Error('İşlem başka bir kayıtla çakıştı, tekrar deneyin')` — otomatik retry YOK; eşleşmezse mevcut `_trErr` akışı aynen [js/api.js:44-62 referans]. Birim testi: kod dalı + mesaj sabiti + retry yok.

## Kabul ölçütleri (plan.md:478 birebir)

1. Birim testi yeşil: hash üyelik (takip RPC harita dışında, sarmal içeride), invalidate nokta tamlığı (grep tabanlı senkron test).
2. `node --check js/api.js` temiz; `git diff --check` temiz.
3. Kırmızı→yeşil sırası kanıtı (test önce kirmizi, sonra yesil — DONE'da iki koşum çıktısı).

## Yasaklar

- `js/ui.js`, `js/forms.js` yazımı (P6+/P9'un dosyaları — api.js dışına yazma; test dosyası hariç).
- RPC imzalarını uydurma — P2b/P3b DONE'larındaki gerçek imzalar (H5 alan tablosu P3b DONE'ında).
- Commit atma; PROD erişimi; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P4-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · kırmızı→yeşil koşum çıktıları · yazılan dosyalar · açık kalem.
