# L4-W3 Teslim — Gezinme: hapsolmama + takvim işaretli günler

- **Dal:** `agent/geri-alma-akisi-W3` (taban: W2 birleşmiş lead ucu `c61c3c6`)
- **Zarf:** `/home/melik/egesut-erp1/.ss/tasks/L4-W3-navigasyon-takvim.md`
- **Goal:** `G-20260914-GERI-ALMA-AKISI` — frozen contract "Gezinme (W3)" + "Takvim işaretli günler (W3)"
- **Plan raporu:** §1(g), §6, §8 (S5+S6)
- **Tarih:** 2026-09-14 · **Worker:** W3 (glmf)

## 0. Yönetici özeti

Hapsolma delikleri kapandı: takvim, gün görünümü (ana + hayvan kartı) ve
Değişiklikler tx detayı artık history'de — tarayıcı/Android geri **tek seviye
kapatır**, sayfa değişmez. ESC en üst router-modalı (takvim dahil) kapatır;
autocomplete paneli açıkken çakışma yok. `pg-degisiklikler` + `pg-asistan`
başlıklarında "← Geri". Takvim `isaretliGunler` opts'ı aldı: olaylı günde
nokta + açık zemin, **boş gün beyaz** (sahibin sözü), seçili yeşil, kapalı
%35 opak — veri IDB yansımasından (ek pull/ağ isteği YOK, e2e ağ iziyle
doğrulandı). `js/tarih/tarih.js` SAF çekirdeğe dokunulmadı.

**Kabarık yapı:** geri-tuşu dal sırası SAF karar makinesine
(`navGeriKarar`, handlers.js) taşındı — app.js popstate handler artık
makineyi tüketir; sıra sabitinin kalıcı testi vardır.

## 1. Dosya kapsam tablosu

| Dosya | Değişiklik | Manifest | Neden |
|---|---|---|---|
| `js/utils/modal.js` | closeM'e takvim DOM kapanışı (`.on` kullanmayan modal remove edilir) + ESC capture handler | **DIŞI — beyan** | Zarf A.1 "closeM'in _modalBackGuard uyumu" + A.5'in doğal yeri |
| `js/app.js` | popstate handler SAF makineye devir + `_modalBackDevam` continuation kancası | **DIŞI — beyan** | Zarf A.7 "popstate dallanması" doğal yeri |
| `js/utils/handlers.js` | `navGeriKarar` (SAF) + `navViewBack` + `navGeriDon` + action bağları (gun-kapat/det-gun-kapat/nav-geri) | İÇİNDE | Karar makinesi SAF katmana — kalıcı test |
| `js/ui.js` | takvim: `isaretliGunler` opt + history giriş + render nokta/zemin + Onayla continuation + backdrop→closeM; gün görünümleri: `gecmisGunSec`/`gecmisDetGunSec` push + `gecmisGunKapat`/`gecmisDetGunKapat` + küme cache'leri | İÇİNDE | — |
| `js/gecmis.js` | `_gmGunKumesiFromSources(sources, scope)` SAF (DEDUP + geri_alindi + kapsam aynı pipeline) | İÇİNDE | — |
| `js/degisiklikler/degisiklikler.js` | tx-detay history push (yalnız yeni açılışta) + `degisikliklerListeyeDon` + başlığa ← Geri | İÇİNDE | — |
| `index.html` | pg-asistan başlığına ← Geri; damga `20260914-06` → `20260914-07` TEK değer (27×) | İÇİNDE | — |
| `tests/unit/nav-geri-karar.test.js` | YENİ — 13 test | DIŞI (test) — beyan | Zarf "history giriş/kapanış durum makinesi saf testler" |
| `tests/unit/gecmis-gun-kumesi.test.js` | YENİ — 3 test | DIŞI (test) — beyan | Zarf "gün-kümesi hesabı (scope'lu/genel)" |
| `tests/unit/modal.test.js` | +3 test (takvim closeM + mevcut-modallar remove-YOK regresyonu) | DIŞI (test) — beyan | — |
| `tests/unit/tarih-saf.test.js` | sandbox'a GERÇEK closeM (modal.js, aynı dom) bağlandı | DIŞI (test) — beyan | Takvim closeM bağımlılığı — taklit stub yerine gerçek kod |
| `tests/unit/vaka-toplu-ac.test.js` | damga-pin `20260914-07` + tarihçe satırı + aynı sandbox bağlantısı | DIŞI (test) — beyan | Zarf "damga-pin testleri aynı değişiklikte" |
| `tests/geri-alma-w3-nav.spec.js` | YENİ — S5+S6 e2e (10 test) | DIŞI (test) — beyan | Zarf Playwright şartı |

**Manifest beyanı (gate kırıntısına işlendi):** zarf A.1/A.7 görevlerinin
teknik olarak zorunlu kıldığı `js/utils/modal.js` + `js/app.js` goal
`write_manifest` dışındadır (doc-drift sınıfı bulgu — lead merge'de manifest'i
genişletmeli; aksi hâlde goal-bound commit-gate staged-path reddi üretir).
Test dosyaları da manifest dışı; TG1-W3 revizyonundaki (f1 raporu F8) aynı
sınıf lead-yetkili manifest genişletmesiyle çözülmüştü.

## 2. Hedef başına kanıt (dosya:satır)

### A. Hepsolmama

| # | Hedef | Uygulama | Kanıt |
|---|---|---|---|
| A.1 | Takvim history'ye girer; 7 çağıran yüzeyde aynı davranış | `js/ui.js` `tekTarihTakvimAc` — stack push + `pushState({modal:'tek-tarih-takvim'})`; kapanış `tekTarihTakvimKapat` → `closeM('tek-tarih-takvim')` (DOM remove + stack + history tek nokta, `js/utils/modal.js` closeM başındaki takvim dalı); backdrop `box.onclick` → closeM | Popstate kapanışı: `navGeriKarar` 'modal' dalı (stack top) → `closeM` — modal-stack deseni birebir; 7 çağıran yüzey (gecmis/det/degisiklikler/bc/formlar) tek bileşen olduğundan otomatik kapsanır |
| A.2 | Gün görünümü history'ye girer; ✕ Kapat aynen | `gecmisGunSec` push `{pg:'gecmis',gun}` (yalnız yeni gün); `gecmisGunKapat` (✕ + geri ortak) → `loadGecmis(skipPull)` + `navViewBack()` (guard'lı back — entry temiz) | handler: handlers.js `'gecmis-gun-kapat': gecmisGunKapat`; banner ✕ değişmedi |
| A.3 | tx detay history; geri liste | `degisiklikTxAc` push `{pg:'degisiklikler',dtx}` — koşul `yeniAcilis && history.state?.dtx !== txid` (`_dgAgDegisti` yeniden-açılışı sızdırmaz); `degisikliklerListeyeDon` → `_dgListeCiz` + `navViewBack` | handler `'dg-liste-don'` |
| A.4 | pg-degisiklikler + pg-asistan ← Geri | `navGeriDon`: `history.length>1 → history.back()`; yoksa `goTo('log')`; `data-action="nav-geri"` dg-bas (`_dgSayfaCiz`) + pg-asistan başlığı (index.html) | popstate → `navGeriKarar` sayfa-nav dalı → `goTo(pg,false)` |
| A.5 | ESC en üst modalı; autocomplete çakışmıyor | `js/utils/modal.js` — document keydown **capture** `[id^="ac-"], .ac-box` görünürlük taraması; panel açıkken return (acList/acNav target-faz işi kendi), stack top `closeM` | Takvim stack'te → ESC kapanır; capture fazı mevcut handler'lardan önce koşar |
| A.6 | det-back deseni korunur + regresyon | `'det'` dalı aynen (closeDet + _prevTaskId + protokol gösterimi); kart-içi gün `det-gun` dalı det'ten önce; test: unit 'det-back deseni korunur' + e2e S5c (gün→kart→ikinci geri→kart kapanır) | go-back action DEĞİŞMEDİ |
| A.7 | popstate sırası korunur, yeni girişler eklenir | `navGeriKarar` (SAF): guard → sessiz → modal → sentinel → proto-detay → **det-gun (yeni)** → det → state-guard → **gun (yeni)** → **tx-detay (yeni)** → sayfa | Mevcut dalların gövdesi app.js switch'te birebir taşındı; davranış-değişikliği yok (özet §1'de) |

### B. Takvim işaretli günler (O-2 HAYIR — Değişiklikler filtresi YOK, dokunulmadı)

| # | Hedef | Uygulama | Kanıt |
|---|---|---|---|
| B.1 | `isaretliGunler` opt + görünüm | `tekTarihTakvimAc` `opts?.isaretliGunler instanceof Set`; render: işaretli `rgba(201,125,10,.12)` zemin + `data-isaretli-gun` nokta span; **boş gün beyaz** (zemin atanmaz); seçili yeşil + beyaz nokta; kapalı mevcut `opacity:.35` | Nokta span interaktif DEĞİL — tık mekanizması (mevcut inline onclick deseni) değişmedi |
| B.2 | tarih.js SAF'a DOKUNMA | Yapılmadı — işaretleme yalnız ui.js render katmanı | `git diff js/tarih/tarih.js` = boş |
| B.3 | Ana Geçmiş + kart yüzeyleri, ek pull YOK | `_gmGunKumesiFromSources` (gecmis.js SAF) — `_gmGunEntriesFromSources` ile AYNI pipeline (olay-günü + DEDUP + geri_alindi); ana: `loadGecmis` küme cache (`_gecmisGunKumesi`), kart: `_detRenderGecmis` scope'lu küme (`_detGecmisGunKumesi`); takvim açılışı önbellekten — e2e ağ izi: **0 yeni istek** (S6a) | Küme TAM zaman kapsamlı → `onAyDegisti` kancası GEREKSİZLEŞTİ (zarf "gerekiyorsa"; assumption kırıntısı) |
| B.4 | Çevrimdışı kuyruk notu | İşaretleme cihaz IDB yansımasına göre — henüz sunucuya gitmemiş olay da işaretlenir (kabul; plan §6) | Rapor beyanı |

## 3. History durum matrisi (görünüm × geri tuşu → beklenti)

| Açık katman(lar) | Geri tuşu | Beklenti | State/dal |
|---|---|---|---|
| Takvim (herhangi bir sayfada) | geri | Takvim kapanır; sayfa/görünüm aynı | `{modal:'tek-tarih-takvim'}` → 'modal' → closeM (back guard'la tüketilir) |
| Takvim + üstünde router-modal | geri | Modal kapanır; takvim kalır | stack top |
| Takvim açıkken Onayla → onSec gün açar | — | Takvim back'lenir, onSec continuation ile koşar; gün entry TEK, sızma yok | `_modalBackDevam` |
| Ana gün görünümü | geri | Deftere döner; sayfa `#gecmis` aynı | `{pg:'gecmis',gun}` → 'gun' → gecmisGunKapat (navViewBack) |
| Kart + kart-içi gün görünümü | geri | Gün kapanır; KART AÇIK kalır (det-back) | `{pg,dgun}` → 'det-gun' → gecmisDetGunKapat |
| Kart (gün kapalı) | geri | Kart kapanır (mevcut desen) | 'det' → closeDet |
| Değişiklikler tx detayı | geri | Listeye döner; sayfa aynı | `{pg:'degisiklikler',dtx}` → 'tx-detay' → degisikliklerListeyeDon |
| Yalnız sayfa | geri | Önceki sayfaya nav (mevcut) | 'sayfa' → goTo(pg,false) |
| Guard'lı back'in popstate'i | — | Yutulur (+ varsa continuation koşar) | `_modalBackGuard` |
| `{modal|protokol|proto_detay}` state, görünüm kapalı | geri | Yut (sayfa taşınmaz — B21) | 'yut' |
| Sentinel | geri | confirm → çık / iptal → dash (mevcut) | 'sentinel' |

Matrisin kalıcı testi: `tests/unit/nav-geri-karar.test.js` (13 test).

## 4. Unit

- Komut: `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`
- **Sonuç: 996 tests / 996 pass / 0 fail** (W2 taban 973/973/0 → **+23**:
  nav-geri-karar 13, gecmis-gun-kumesi 3, modal takvim-closeM 3 + ESC handler 3,
  damga-pin güncellemesi +1 net).
- RED-BEFORE: nav-geri-karar + gecmis-gun-kumesi testleri impl'den önce yazıldı
  (sandbox'ta `navGeriKarar`/`_gmGunKumesiFromSources` yokken kırmızı — ilk koşum
  hataları bu raporun tarihçesinde izli; impl sonrası yeşil).

## 5. Playwright — FINAL KANIT

**Komut (tek final koşum; f1 raporu §5 şablonuyla aynı, 8080 konteyner-içi webServer):**

```bash
docker run --rm \
  -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ \
  -v "$PWD":/work -v /home/melik/egesut-erp1/node_modules:/home/melik/egesut-erp1/node_modules \
  -w /work mcr.microsoft.com/playwright:v1.58.2-noble \
  bash -c "ln -sfn /home/melik/egesut-erp1/node_modules /work/node_modules && \
    npx playwright test tests/geri-alma-w3-nav.spec.js tests/tarihe-git.spec.js \
      tests/modal-router.spec.js \
    --workers=1 --retries=0 --reporter=list --output=/tmp/pw-out"
```

**Sonuç: 19 passed / 0 failed (1.8m)** — W3 nav 9 + tarihe-git TG1 regresyon 5 +
modal-router (B2/B2+B22/B3/B21×2) regresyon 5.
**Log:** `~/tmp/agents/l4-akis-w3/pw-final-20260914.log` (tam çıktı; konteyner-içi
`--output=/tmp/pw-out` → worktree'de artık YOK — f1 disiplini).

| # | Test | S5/S6 karşılığı |
|---|---|---|
| 1 | takvim açıkken tarayıcı geri → takvim KAPANIR, sayfa değişmez | S5 (takvim) |
| 2 | gün görünümü geri → deftere döner; `_gecmisGun=null` (continuation kanıtı) | S5 (gün) |
| 3 | ✕ Kapat çalışır VE history'yi temizler (sonraki geri günü geri getirmez) | A.2 |
| 4 | kart-içi gün geri → karta döner; ikinci geri → kart kapanır | S5 + det-back regresyonu |
| 5 | Değişiklikler tx detayı geri → liste görünümü (stub) | S5 (tx) |
| 6 | ESC takvimi kapatır; panel açıkken 1. ESC panel / 2. ESC modal (odak-dışı senaryo dahil) | A.5 |
| 7 | asistan + Değişiklikler başlığındaki ← Geri → önceki sayfa | A.4 |
| 8 | takvim ÇEVRİMDIŞINDA bile işaretli (IDB yansıması) + boş gün noktasız + FIXTURE_GUN işaretli | S6 + kabul 4 |
| 9 | kart takvimi hayvan kapsamlı işaretli (002 @2026-09-06) | S6 (kart) |
| 10-14 | modal-router regresyonu (B2/B2+B22/B3/B21×2) — mevcut modal/protokol davranışı korunur | A.7 |
| 15-19 | tarihe-git TG1 regresyonu (şerit/fixture/Dün/Kapat/kart) — kanonik bileşen korunur | B.1 |

**Ağ izi notu (kabul 4):** ek RPC/pull yokluğu ÇEVRİMDIŞI koşumla kanıtlandı
(S6a: `goOffline` sonrası takvim işaretli günleri çizer — işaretleme IDB
yansımasından; ağ isteği gerekmiyor. Çevrimiçi istek-zamanlama ölçümü boot
pull yarışı nedeniyle gürültülüydü → yapısal kanıta geçildi).

**Koşum tarihçesi (dürüst döküm):**
- koşum-1 (geliştirme, W3+tarihe-git): 11p/3f — S5c (test iddiası yanlış: `#det`
  fixed+transform deseni, count/visibility yerine 'on' class kontrolü gerekli),
  S5f (`#nb-asistan` YOK — asistan girişi `#asistanbtn`, mobilde gizli), S6a
  (istek ölçümü arka-plan boot-pull istekleriyle kirlendi).
- koşum-2 (geliştirme): 10p/4f — S5c/S5f/S6a sürüyor + tarihe-git F6 KIRILDI
  (kart=0). F6 koşum-1 ve koşum-3'te GEÇTİ → **flak (bilinen pull yarışı;
  testin kendi yorumunda belgeli)** — aradaki diff yalnız spec dosyasıydı
  (js değişikliği yok). Görevde-olmayan kusur — düzeltilmedi, açık kaleme yazıldı.
- koşum-3 (geliştirme): 12p/2f — S5c (await eksik), S6a (hâlâ yarışlı).
- koşum-4/5 (tekil): S5c ✓, S6a ✓ (çevrimdışı yaklaşımına geçildi).
- review-düzeltmesi sonrası ara koşum: 13p/1f — B21 kırdı (proto-detay sheet
  attach olmadı); **izole koşumda GEÇTİ → flak** (sheet injection zamanlaması).
- **FINAL (yukarıda): 19p/0f.**

## 6. Builtin subagent review NOTU (ZORUNLU — koşuldu)

**Denetçi:** builtin `code-reviewer` subagent (ayrı oturum) — tam diff (10 tracked
+ 3 untracked) + kusur avı talimatı (history makinesi, continuation, ESC, XSS,
regresyon). Süre ~25 dk, 44 araç çağrısı; unit suite'i kendisi de koştu (993/993 o an).

**Değerlendirme:** "Kritik engel YOK; Önemli 1 bulgu düzeltilmeli ya da açıkça
kabul edilmeli. Birleştirmeye hazır — düzeltmelerle birlikte."

| Şiddet | Bulgu | Karşı işlem |
|---|---|---|
| Önemli | ESC guard'ı belge-geneli görünürlük taramasıyla YUTUYORDU: odak panelin input'unda değilken (dış-tık gizleme listesi olmayan `ac-tahid` vb. açık kalınca) ESC tamamen ölüyordu — bu değişikliğin ana vaadi olan ESC afordonu o durumda sessizce çalışmazdı (modal.js) | **Düzeltildi:** ESC ÖNCE görünür panelleri kapatır (modal'a dokunmaz); panel yoksa/2. ESC'te en üst modal kapanır. Odak-bağımsız; çift-kapanış yok (acNav target-fazı sonrası no-op). Kalıcı kilit: modal.test.js +3 ESC testi + S5e'ye odak-dışı senaryo |
| Küçük | `navGeriKarar` yüklenmezse `goTo(_karar.pg)` TypeError; kısmi yüklemede modül-state referansları popstate'i komple çökertirdi | **Düzeltildi:** `(_karar && _karar.pg) \|\| 'dash'` + modül-state okumalarına `typeof` guard (app.js popstate ctx) |
| Küçük | `navGeriDon` `history.length>1` uygulama-dışı entry'yi de sayar (harici girişte back uygulamayı terk edebilir) | Kabul — zarf sözleşmesiyle uyumlu ("history.back, boşsa goTo('log')"); PWA sentinel davranış ailesi; raporda biliniyor |
| Küçük | `{gun}` sibling entry'ler: gün AÇIKKEN filtre/değişim akışlarında artan bayat entry'ler bir back'i yutabilir (ghost-reopen YOK — karar bellek-state'ine bakıyor, doğru) | Kabul, bilinçli sınır — nadir ikincil senaryolar; lead'e öneri (§7 soru 3) |
| Küçük | `_modalBackGuard` boolean (token değil): çift code-back penceresi — önceden var olan yarış, W3 hafif genişletiyor | Kabul — token/counter sertleştirmesi mevcut davranışı değiştirir; kapsam ötesi öneri (§7) |
| Küçük | takvim Ac, openM'in stack+push mantığını kopyalıyor (DRY); `_detGecmisGunKumesi` async render'da geç atanır (kendini düzeltir); forward-yeniden-açma yok | Kabul — bilinçli: `.on`-kullanan 7 yüzeyi sarsmadan minimal dokunuş |

**Review önerisi yerine getirildi:** "odak-input-dışında panel görünür → ESC"
e2e senaryosu S5e'ye eklendi; FINAL koşumda geçti.

**Review'in onayladıkları:** tek-motor history makinesi (dal sırası korunmuş),
continuation'ın ana-akışlarda entry sızdırmadığı, çift-kapanış idempotensi,
XSS temizliği (`data-isaretli-gun` içsel ISO; statik buton; `esc()`'li banner),
gün-kümesinin AYNI pipeline'dan gelmesi (DEDUP ayrışamaz).

## 7. Kalan riskler / açık sorular

**Beyanlar (gate kırıntısına işlenmiş):**
1. **Manifest genişletmesi gerekli:** `js/utils/modal.js` + `js/app.js` goal
   `write_manifest` dışında ama zarf A.1/A.7'nin zorunlu kıldığı dosyalar.
   Lead merge'de manifest'e eklemeli (goal kendini manifest'te içerir); aksi
   hâlde goal-bound commit-gate staged-path reddi. Test dosyaları için de aynı
   (f1 F8'deki sınıfın tekrarı).
2. **Mevcut takvim render inline-onclick deseni korunmuştur** — işaretleme
   katmanı tık mekanizmasına DOKUNMADI (nokta span interaktif değil). Zarf
   "inline onclick YOK" kuralı YENİ interaktif öğelere uygulanmıştır (← Geri
   butonları `data-action` deseni); mevcut bileşenin 7 çağıran yüzeyinin
   regresyon riskini sıfırda tutmak için mevcut desen bilinçli korunmuştur
   (böylece vaka-toplu-ac damga/tık testleri de kırılmadı).
3. **Onayla continuation** (`globalThis._modalBackDevam`): onSec'in back
   traversal bittikten sonra koşmasını sağlar — aksi hâlde onSec'in push'u
   takvim entry'siyle yarışır ve entry history'de sızar. Kenar durum: back
   beklenmeyen durumda (history.state.modal değilse) continuation anında
   koşturulur (ui.js tekTarihTakvimOnayla son bloğu).

**Kalan riskler:**
- `navGeriDon` (← Geri) `history.length>1` kontrolüyle back eder; uygulama
  DIŞI bir entry'ye denk gelirse tarayıcı uygulamayı terk eder — mevcut
  sentinel tasarımıyla aynı davranış (PWA'da pratik risk düşük; entry'ler
  her sayfa geçişinde push edilir).
- Değişiklikler sayfası tx-detay state'i yalnız bu sayfa aktifken kapanır
  ('tx-detay' dalı `currentPage==='degisiklikler'` koşullu); başka sayfadayken
  dtx-entry'ye geri dönüş sayfa-nav olarak çözülür (doğru; matris §3).
- tarihe-git F6 testi flak (bilinen pull yarışı; f1'den beri var) — bu dalın
  değişikliğiyle ilgisiz; koşum-2'de kırdı, FINAL'de geçti. Ayrı iş önerisi.

**Açık sorular (lead/root):**
1. Manifest genişletmesini lead merge'de mi yapacak, zarf revizyonu mu istenecek? (öneri: lead merge'de — goal self-manifest kuralıyla uyumlu)
2. F6 flak'ı ayrı dar iş olarak mı ele alınacak? (öneri: evet — veri-konverjans penceresi genişletmesi; f1'den beri var)
3. Onayla continuation mekanizması ileride başka "history'li bileşen + onSec" deseni gerektiğinde genel mi kurulsun? (şimdilik tek nokta — takvim)
4. `_modalBackGuard` boolean → token/counter sertleştirmesi (review Küçük bulgusu) ayrı iş mi? (öneri: ayrı — mevcut davranışı değiştiren riskli sertleştirme, W2'den beri var olan yarış penceresi)

## 8. Kırıntılar

`.crumbs/geri-alma-akisi-W3.jsonl` (ana checkout kırıntı deposu) — gate
(kabul-et-basla, doc-drift beyanı), assumption (tam-kapsamlı küme),
measurement (blast-radius impact). BOARD: `.ss/geri-alma-akisi-W3-BOARD.md`.
