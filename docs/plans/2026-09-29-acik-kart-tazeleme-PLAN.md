# Açık Kart Tazeleme — Implementasyon Planı (2026-09-29)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hayvan kartı (`#det`) açıkken veri katmanına yerleşen her başarılı değişiklikte kartın aktif sekmeyi koruyarak yerinde tazelenmesi (`pullTables` sonu kancası Y1).

**Architecture:** `pullTables` run sonunda üçlü `(requested, ok, failed)` + `detInternal` işaretini gevşek kancaya taşır; `js/ui.js` kanca fonksiyonu bastırma/çizim predicate'leri + trailing-edge debounce (~250 ms) + epoch-başlı ara-çizim cap'i (≤2) ile `openDet(_detOpenId, true)` çizer. `openDet`/`closeDet` generation/epoch protokolüyle yarışları kapatır; forms.js çağrı noktaları çifte çizimden temizlenir.

**Tech Stack:** Vanilla JS (classic script, browser-global), Supabase REST, node:test + vm sandbox (`tests/unit/support/loadModule.js`).

**Spec:** `/home/melik/.herdr/worktrees/egesut-erp1/minik-fixler/docs/plans/2026-09-29-acik-kart-tazeleme-SPEC.md` (v6, luna-KABUL'lü — §2 sözleşme R1-R6, §3 mekanizma, §6 kabul A1-A16). Plan spec'ten argued; executor ikisini de okur.

## Global Constraints

- Dal: `minik-fixler` (worktree `/home/melik/.herdr/worktrees/egesut-erp1/minik-fixler`), taban `b507645`. Push/merge YOK — yalnız task commit'i.
- **A9 pinned unit komutu (kelimesi kelimesine, `--prefix` YASAK):**
  `cd /home/melik/.herdr/worktrees/egesut-erp1/minik-fixler && NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit`
  Taban: 1231/1228/3 (bilinen 3 fail: LUNA-3 + 2 bc-tarih). Her task sonunda bu komutla yeni testler dahil yeşil (fail = 3 + yeni-katkı 0). Geçerlilik şartı: `ℹ tests` toplamı taban+yeni; fast-check modülleri yüklü.
- Test kalıbı: `tests/unit/support/loadModule.js` → `loadBrowserModule(dosya, {dom, extra, expose})`; DOM stub `makeDomStub` + `document.__setEl('id', el)`; `sandbox.openDet = spy` monkeypatch; referans dosyalar `tests/unit/hizli-uygulama-guard.test.js` (tam modül + stub sahne) ve `tests/unit/cila-tutarlilik.test.js` (extract + izole ctx).
- `docs/plans/` ve `runs/` gitignore kapsamında — task commit'lerine dahil EDİLMEZ (sadece kod + test commit edilir).
- Her task: kırmızı-önce (test yaz → koş → FAIL gör → impl → PASS gör → commit). Commit öncesi `git diff --cached --stat` doğrulaması.
- JS dosyası düzenlemeden ÖNCE `code-change-precheck` skill'i zorunlu (proje kuralı).
- Commit mesajı Türkçe, `kart-tazeleme T<N>: ...` öneki + `Co-Authored-By: Claude Code <noreply@anthropic.com>` satırı.
- GLM koltuk işleri 09:00-13:00 durur: iş o saate yaklaşırsa adımı bitir, ILERLEME notu yaz, dur.

## Review Focus

1. **Kart kapalıyken sıfır maliyet (R5):** kanca kart kapalıysa timer KURMAZ — test: kapalı kartta qualified çağrı → 0 draw. → Task 2.
2. **Aynı-ID hızlı close/reopen yarışı (A6d):** gen-1'in geç devamı gen-2 DOM'unu ezemez — test: askıya alınmış pull çözülünce eski openDet yazmaz. → Task 2.
3. **Timer'lar kapalı kartı yeniden AÇMAZ (A15):** draw yolu `openDet(_detOpenId, true)` ve `_detOpenId=null` guard'ı — test: closeDet sonrası bekleyen timer fire → 0 draw. → Task 2.
4. **Evren-dışı/kısmi-hata (A8/A14):** `protokol_ayar` başarıyı tek başına çizdirmez; `hayvanlar` fetch hatası flush'ı bastırır, `protokol_ayar` hatası bastırmaz. → Task 1 + Task 2.
5. **Nihai durum her zaman çizilir (R1/A7):** burst sonunda son veriyle bir çizim garanti; sayaç dolmuşken gelen pull sessizce yutulmaz — trailing onay timer'ı çizer. → Task 2.

---

### Task 1: api.js — pullTables üçlü kontrat + detInternal işareti + gevşek kanca

**Kabul bağı:** A6(a/b) tedarik, A14 tedarik, R2/R6 tedarik, A9.

**Files:**
- Modify: `js/api.js:513-519` (`pullTables`), `js/api.js:557+` (`_pullTablesNow` — failed-set toplama)
- Test: `tests/unit/det-tazeleme-api.test.js` (yeni)

**Interfaces:**
- Produces (Task 2 ve formlar buna yaslanır):
  - `pullTables(tables = [], opts = {})` — geriye dönük uyumlu; `opts.detInternal === true` içsel run işareti.
  - `_pullTablesNow(tables)` dönüşü: `{ ok: string[], failed: string[] }` (tablo adları; ok = başarıyla fetch+IDB yazımı yapanlar).
  - Run tamamlandığında (resolve; reject'te ÇAĞRILMAZ — "tam red'de kanca doğal olarak çağrılmaz"): `window._detAciksaTazele?.(requested, ok, failed, detInternal)` — 4. argüman boolean. `tables.length===0` erken dönüşte kanca çağrılmaz. Kanca çağrısı `try/catch` içinde (gevşek bağ; api.js DOM bilmez).

- [ ] **Step 1: Kırmızı test** — `tests/unit/det-tazeleme-api.test.js`; `js/api.js` tam modül `loadBrowserModule` ile yüklenir (stub supabase client `tests/unit/api.test.js:45-62` `makeClient` kalıbı + `makeIdbStub` `api.test.js:68-98` + `_idb` enjeksiyonu `api.test.js:126-128`). `extra.window._detAciksaTazele` yerine sandbox window stub'una kanca kaydedici takılır (`rec.kanca`). Testler:
  1. `hook-01`: başarılı pull (`['hayvanlar','gorev_log']`) → kanca bir kez, `requested` aynı dizi, `ok` bu tabloları içerir, `failed` boş, `detInternal===false`.
  2. `hook-02`: bir tablonun fetcher'ı reject eder (stub client o tablo için hata verir) → run RESOLVE olur, kanca `failed` içinde o tabloyu taşır.
  3. `hook-03`: `pullTables(t, {detInternal:true})` → kanca `detInternal===true` ile çağrılır (bastırma ui.js tarafında; api bayrağı dürüst taşır).
  4. `hook-04`: `pullTables([])` → kanca çağrılmaz.
  5. `hook-05`: tek argümanlı mevcut çağrı biçimi çalışır (geriye dönük uyum — mevcut `protokol-dismiss-gorev.test.js` zaten regression'tır, burada yalnız imza).
- [ ] **Step 2: Koş → FAIL** (kanca hiç çağrılmaz / `_pullTablesNow` set döndürmez).
- [ ] **Step 3: İmplement** — `pullTables` imzasına `opts={}` ekle; `_pullTablesNow` içinde mevcut `hataSayisi` akışını koruyarak başarılı/başarısız tablo adlarını topla ve `{ok, failed}` döndür; `pullTables` run'ının `.then(...)`'sında yukarıdaki kontratla kancayı çağır. FETCHERS döngüsünün mevcut yapısı (sıralı/allsettled ne ise) değiştirilmez — yalnız set toplama eklenir.
- [ ] **Step 4: Koş → PASS** (yalnız yeni dosya: `node --test tests/unit/det-tazeleme-api.test.js`).
- [ ] **Step 5: Tam unit** — pinned A9 komutu → taban+5 yeni test, fail yine 3.
- [ ] **Step 6: Commit** — `kart-tazeleme T1: api.js pullTables üçlü kontrat (requested/ok/failed) + detInternal işareti + gevşek _detAciksaTazele kancası`.

### Task 2: ui.js — kanca, epoch/gen protokolü, cap, çağrı temizliği

**Kabul bağı:** A6(a)-(f), A7 (mekanik cap), A8, A12, A14 (tüketim), A15, A16 (mekanik kısım), R1/R3/R5.

**Files:**
- Modify: `js/ui.js` — `:4291` civarı state bloğu; `openDet` `:4930-4999`; `closeDet` `:5005-5014`; `_hayvanHizliUygulaKaydet` `:3998-4003`; yeni yardımcılar.
- Test: `tests/unit/det-tazeleme-kanca.test.js` (yeni)

**Interfaces:**
- Consumes: Task 1'in kanca kontratı (testlerde `pullTables` stub'lanır — Task 1'e çalışma-anı bağımlılığı yok).
- Produces: `window._detAciksaTazele(requested, ok, failed, detInternal)` (global function declaration); `_detAcik()` → kart açık mı boolean (Task 3 kullanır); `window.__detSayac = {openDet: 0, epoch: 0}` test/demo sayacı (A1/A7/A16 oracle'ı).

**Yorum kararı (SPEC §3.2 — luna'ya bayrakla):** cap mekaniği iki fazlı trailing-edge'tir: nitelikli pull t1 debounce timer'ını yeniden başlatır; t1 fire'da `_detAraSayac<2` ise ARA çizim (sayaç++), aksi halde ikinci bir onay timer'ı (t2, yine ~250 ms) kurulur — t2 süresi içinde yeni nitelikli pull gelirse t2 iptal edilip t1 yeniden başlar; t2 fire'ında NİHAİ çizim yapılır. Tek burst'te (ör. 0/300/600/900 ms pull'ları) toplam çizim ≤3 mekanik garantidir (2 ara + 1 onaylı nihai); ARA toplamı epoch başına ≤2 (sayaç yalnız epoch değişince sıfırlanır); çoklu burst'te her burst sonunda bir nihai çizim doğar (R1 nihai doğruluk). A16'nın "≤3 pull seti" ölçümü tek-zincir senaryosundadır.

- [ ] **Step 1: Kırmızı testler** — `tests/unit/det-tazeleme-kanca.test.js`; tam `js/ui.js` `loadBrowserModule` ile (hizli-uygulama-guard sahne kalıbı): `document.__setEl('det'|'det-name'|'det-meta'|'det-chips'|'tab-ozet'|...)`; `extra` stub: `pullTables` (kayıt+istenen deferred), `getData`, `idbGetAll`, `rpc`, `toast`; monkeypatch: `sandbox.openDet = spy` (kanca draw'larını sayar), `_detRenderGecmis`, `showTab`, `pedigreeSetFocus`. `vm.runInContext('_DET_TAZELE_DEBOUNCE_MS = 5', sandbox)` ile hızlı debounce (bu yüzden sabit `let` tanımlanır, değer 250). Kart açık/kapalı `det` el'inin `classList.toggle('on')`'uyla kurulur; kart-open senaryosunda gerçek `openDet` sandbox'tan çağrılıp `_detOpenId` kurulur (pull stub'ı anında resolve). Testler (her biri SPEC maddesine bağlı):
  1. `kapali-01` (R5): kart kapalı + qualified kanca → debounce süresi bekle → 0 draw, timer kurulmamış (ara durum sorgulanamazsa sonuç: 0 draw yeter).
  2. `ic-01` (A6a): `detInternal=true` → 0 draw; hemen ardından qualified DIŞ kanca → draw olur (A6b — içsel pull dış flush'ı silmez).
  3. `bastir-01` (A14): `failed=['hayvanlar']` → 0 draw; `failed=['protokol_ayar']` (evren-dışı) + `ok=['hayvanlar']` → draw.
  4. `evren-01` (A8): `ok=['protokol_ayar']` yalnız → 0 draw; `ok=['stok']` → draw (stok evren İÇİ).
  5. `merge-01`: 3 qualified pull debounce penceresi içinde → 1 draw `(_detOpenId, true)`.
  6. `cap-01` (A6f/A7): 4 qualified pull, araları debounce'tan büyük (ör. 0/6/12/18 ms, debounce 5) → toplam draw === 3; 10 pull'luk zincirde de === 3; draw'ların hepsi `keepTab===true`.
  7. `epoch-01` (A6f): 2 ara + nihai sonrası yeni burst → 1 nihai daha (ara toplam hâlâ 2); `closeDet()` + yeniden aç → epoch arttı (`window.__detSayac.epoch`), yeni burst ara sayacı sıfırdan (ara çizimler yeniden mümkün).
  8. `close-01` (A15): qualified → debounce dolmadan `closeDet()` → bekle → 0 draw.
  9. `race-01` (A6c/d/e): gerçek `openDet(A)` pull stub'ı askıda; `openDet(B)` çağrılır (gen artar); A'nın pull'u resolve edilir → A devamı DOM'a yazmaz (patch'li render kaydedicileri boş / `det-name` B akışından önce yazılmadı); askı çözülünce B çizilir. Aynı-ID varyantı: `openDet(A)` askıda → `closeDet()` → `openDet(A)` → gen-1 çözülünce ezme yok.
  10. `hist-01` (A12): kanca draw'u (gerçek openDet `keepTab=true`) `history.pushState` çağırmaz (`(keepTab=false)` ilk açış çağırır — sandbox history stub kayıt).
  11. `flush-01` (A13 sözleşme): `_DET_TABLOLAR` ∩ flushPendingDone pull seti (`gorev_log, treatment_days, treatment_day_uygulamalar, drug_administrations, stok, stok_hareket, cases`) ≠ ∅ — statik üyelik testi.
  12. `temiz-01`: `_hayvanHizliUygulaKaydet` akışı (rpc ok) → doğrudan `openDet` ÇAĞRILMAZ (spy boş), `_islemSonrasiRefresh` çağrılır (çifte çizim temizliği).
- [ ] **Step 2: Koş → FAIL.**
- [ ] **Step 3: İmplement** — `js/ui.js`:
  - State bloğu (`:4291` yanı): `let _detGen=0; let _detEpoch=0; let _detAraSayac=0; let _detTazeleTimer=null; let _detNihaiTimer=null; let _DET_TAZELE_DEBOUNCE_MS=250;` + `const _DET_TABLOLAR=[...]` (19 tablo, SPEC §3.3: `hayvanlar, cases, diseases, dogum, gorev_log, tohumlama, kizginlik_log, uygulama_log, vaccination_log, vaccines, drugs, drug_products, drug_classes, islem_log, stok_hareket, treatment_days, drug_administrations, protokol_instance, stok` — her grup kaynak yorumuyla: openDet pull+getData evreni / `_gecmisCollectSources` evreni) + `window.__detSayac={openDet:0,epoch:0};` + `function _detAcik(){...}`.
  - `_detAciksaTazele(requested, ok, failed, detInternal)`: `if(detInternal) return;` → kart kapalı/`_detOpenId` yoksa çık → bastırma predicate'i (`failed ∩ _DET_TABLOLAR`) → çizim predicate'i (`ok ∩ _DET_TABLOLAR`) → `clearTimeout(t1); clearTimeout(t2); t1=setTimeout(_detTazeleFire, _DET_TAZELE_DEBOUNCE_MS)`.
  - `_detTazeleFire()`: tekrar-doğrulama (`#det.on` + `_detOpenId`); `_detAraSayac<2` → `++_detAraSayac; openDet(_detOpenId, true)`; değilse `clearTimeout(t2); t2=setTimeout(_detTazeleNihai, _DET_TAZELE_DEBOUNCE_MS)`. `_detTazeleNihai()`: tekrar-doğrulama + `openDet(_detOpenId, true)`.
  - `openDet`: girişte `const myGen=++_detGen; _detOpenId=id; window.__detSayac.openDet++;` `if(!keepTab){ clearTimeout(t1); clearTimeout(t2); _detEpoch++; window.__detSayac.epoch=_detEpoch; _detAraSayac=0; }` — `:4953` pull çağrısına `{detInternal:true}`; `:4954` ve `:4969` `if(_detOpenId!==id) return;` guard'ları `if(myGen!==_detGen) return;` ile DEĞİŞTİRİLİR; `await idbGetAll(...)`/`_detSaglikRender` sonrası DOM yazım bloğu öncesi (`:4988` civarı) bir guard daha.
  - `closeDet`: mevcut gövdenin BAŞINA `clearTimeout(t1); clearTimeout(t2); _detTazeleTimer=null; _detNihaiTimer=null; _detOpenId=null; _detGen++; _detEpoch++; _detAraSayac=0; window.__detSayac.epoch=_detEpoch;` (mevcut `.remove('on')` + sessiz-sheet bloğu korunur).
  - `_hayvanHizliUygulaKaydet` `:4003`: `openDet(hayvanId, true);` satırı SİLİNİR (`_islemSonrasiRefresh()` kalır — pull seti evren içi, kanca çizer).
- [ ] **Step 4: Koş → PASS** (yeni dosya).
- [ ] **Step 5: Tam unit** — pinned komut; fail 3 (bilinen).
- [ ] **Step 6: Commit** — `kart-tazeleme T2: ui.js _detAciksaTazele kancası + _detEpoch/_detGen protokolü + ara-çizim cap≤2 + closeDet temizliği + hızlı-uygulama çifte çizim temizliği`.

### Task 3: forms.js — çağrı noktalarının temizliği

**Kabul bağı:** R3 (A3), R4 (A5 sıra), §4 forms envanteri, A4-aile tedariki.

**Files:**
- Modify: `js/forms.js` — `:161-165` (submitAnimal güncelleme dalı), `:856-859` (submitCase), `:3354-3357` (abortKaydet), `:3377-3382` (hayvanNotEkle), `:3566-3568` (suttenKesTekil), `:4412-4418` (tohSonuc)
- Test: `tests/unit/det-tazeleme-forms.test.js` (yeni)

**Interfaces:**
- Consumes: `_detAcik()` (Task 2 üretimi; forms.js çalışma-anında global'e erişir).
- Produces: yok (davranış değişikliği).

- [ ] **Step 1: Kırmızı testler** — `tests/unit/det-tazeleme-forms.test.js`; `js/forms.js` `loadBrowserModule` ile (`tests/unit/forms-validation.test.js` sahne kalıbı; `extra` stub: `rpc`, `pullTables`, `renderSafe`, `renderFromLocal`, `toast`, `closeM`, `cl`, `getDisplayKupe`, `loadDrugsCache` vb.; monkeypatch kaydedici: `sandbox.openDet`, `sandbox.closeDet`, `sandbox._islemSonrasiRefresh`, `sandbox.loadDash`, `sandbox.loadAnimals`, `sandbox.openCaseDet`). Testler:
  1. `r3-01` (A3): `suttenKesTekil` rpc ok → `closeDet` ÇAĞRILMAZ; `pullTables(['hayvanlar','gorev_log','protokol_instance'])` çağrılır.
  2. `r4-01` (A5): `submitCikis` rpc ok → `closeDet` pullTables'tan ÖNCE (kayıt sırası assert).
  3. `keep-01`: `abortKaydet` / `hayvanNotEkle` / `submitAnimal`(güncelleme) / `submitCase` — kart AÇIK sahnede `openDet(id, true)` (keepTab true); kart KAPALI sahnede keepTab falsy.
  4. `temiz-02`: `tohSonuc` (gebe/boş sonucu, `_curToh` kurulu, kart açık sahne) → doğrudan `openDet` ÇAĞRILMAZ (kanca çizer); `closeM('m-toh-det')` ve `renderFromLocal` korunur.
  5. `done-01`: `doneTask` rpc ok → doğrudan `openDet` yok; `pullTables(['gorev_log','hayvanlar'])` + `_islemSonrasiRefresh` + `loadDash` korunur (kanja kapsamı).
- [ ] **Step 2: Koş → FAIL.**
- [ ] **Step 3: İmplement** — `js/forms.js`:
  - `submitAnimal :165`: `openDet(editId);` → `openDet(editId, _detAcik());`
  - `submitCase :857`: `await openDet(hayvan.id);` → `await openDet(hayvan.id, _detAcik());` (ardındaki `openCaseDet(res.case_id)` korunur)
  - `abortKaydet :3357`: `openDet(hayvanId);` → `openDet(hayvanId, _detAcik());`
  - `hayvanNotEkle :3382`: `openDet(hayvanId);` → `openDet(hayvanId, _detAcik());`
  - `suttenKesTekil :3567`: `if (typeof closeDet === 'function') closeDet();` satırı SİLİNİR.
  - `tohSonuc :4414-4417`: `const detEl=...` kontrol bloğu + `await openDet(_curToh.hayvan_id, true);` SİLİNİR (`closeM`, `pullTables`, `renderFromLocal` kalır).
  - `doneTask` ve `submitCikis` DOKUNULMAZ.
- [ ] **Step 4: Koş → PASS.**
- [ ] **Step 5: Tam unit** — pinned komut; fail 3.
- [ ] **Step 6: Commit** — `kart-tazeleme T3: forms.js çağrı temizliği — keepTab=koşullu 4 yol, suttenKesTekil closeDet kaldırıldı (R3), tohSonuc direkt tazeleme kalktı; submitCikis/doneTask dokunulmaz (R4)`.

### Task 4: index.html — damga bump

**Kabul bağı:** A10.

**Files:**
- Modify: `index.html` (26 adet `?v=20260927-09` → `?v=20260929-01`), `tests/unit/vaka-toplu-ac.test.js:2296-2321` (yalnızca damga changelog yorum satırı ekleme)

- [ ] **Step 1: Doğrula** — `grep -o '?v=[0-9A-Za-z-]*' index.html | sort | uniq -c` → 26× `20260927-09` + 1 çıplak (yorum). Değer-bağımsız damga testleri (`vaka-toplu-ac.test.js:2286-2332`, `coklu-kaydir-ui.test.js:585-602`) bump'la kırılmaz — kırmızı test YOK (bu task doğrulama-bazlıdır).
- [ ] **Step 2: Bump** — tüm `?v=20260927-09` → `?v=20260929-01`; `vaka-toplu-ac.test.js` changelog yorum bloğuna satır: `20260929-01 — kart tazeleme kancası (api/ui/forms)`.
- [ ] **Step 3: Doğrula** — grep → tek değer `20260929-01` (26 adet) + 1 çıplak yorum; pinned unit komutu → damga testleri PASS, fail 3.
- [ ] **Step 4: Commit** — `kart-tazeleme T4: ?v= damgası 20260929-01 (tek değer, 26 konum) + changelog satırı`.

---

## Yürütme protokolü (mimar → executor zarfları)

- Sıra: **T1 → T2 → T3 → T4** (dizisel; tek-yazıcı-per-dosya, commit sırası). Her task ayrı builtin subagent (erp-implementer), zarfı: planın task bölümü AYNEN + Global Constraints + yazılabilir dosya listesi (Task'ın Files sütunu + kendi test dosyası) + GOREV/DONE mutlak yolları (`runs/2026-09-29-kart-tazeleme-impl/GOREV-T<n>.md`, `DONE-T<n>.md`).
- Executor ilk işi: `using-superpowers-obra` + `code-change-precheck`; her task sonunda DONE dosyasına: yapılanlar, test sayıları (pinned komut çıktısının kuyruğu), commit sha.
- Mimar kapı (B8-son): pinned A9 koşusu + artifact `runs/2026-09-29-kart-tazeleme-impl/unit-baseline-<sha>.txt` + damga grep — sonra review döngüsü (B8b): ss-lead-codex (gpt-5.6-luna/max) resume `01a0ed27-a583-75e0-a1ce-8c98e776c1e4`, zarf + DONE mutlak yollu; PASS'e kadar aynı oturumda tur; **3. RED'de DUR ve sahip bekle** (sahip yönergesi 2026-09-29).
- A11 glmf-max UI kapısı (B9) review sonrası ayrı kalem — sahibe demo öncesi PASS şartı sürer.
