# PLAN S4 — İlk Tohumlama satırı hayvan kartına gider + Ovsynch-56/TAI yardım balonu + yaş denetimi

> **Kaynak spec:** `docs/plans/2026-09-24-ovsync-cila/spec-s4.md` (**v1.1 onarım turu**) · Girdi planı: `reports/plans/ovsync-cila-plan-3.md`
> **Onarım turu (2026-09-24):** bu plan da onarım turundan geçti — 0a worktree-analyze kuralı, 0b 33-çağrı beklentisi, Adım 1 E.2 kapsam düzeltmesi, Adım 2 e2e RPC-stub şartı, Adım 3 E.6 stopPropagation iddiası, Adım 4 pencere KANAL+GÜN-bağlı teslim notu (F10 + tutarlılık-turu kanal ayrıştırması), kanıt tablosu tazelemesi (§9). Spec tarafı: spec-s4.md §13.
> **Dal:** `ovysch-feature-cila-turu` · **Prod push/merge YASAK.** Commit'ler yalnız bu dala, her anlamlı adımdan sonra.
> **Migration YOK** (spec §6.1): bu planda `supabase/migrations/*` üreten adım yoktur; `scripts/db-validate.sh` kapısı **N/A**dır — yine de Adım 4'te "migration üretilmedi" kanıtı istenir (bir dosya belirdiyse spec sapmasıdır, kapı zorunlu olur).
> **Tek-yazıcı zarf:** Bu planın dosya seti (`js/ui.js`, `js/utils/handlers.js`, `js/app.js`, `tests/unit/ovsync-pg-ui.test.js`, `tests/modal-router.spec.js`, `index.html`) **yalnız bu zarfa aittir**. Eşzamanlı agent sayısı 10 olabilir → başka bir lane aynı dosyalarda commit görürse bu plan koşulmaz/askıya alınır ve ENGEL olarak raporlanır (§3).

## 0. Yasak listesi (spec §4 birebir — her adımda geçerli)

Dokunma: `js/api.js`, `js/forms.js`, `js/state.js`, `js/config.js`, tüm `supabase/migrations/*`,
RPC imzaları (`ovsync_baslat_uyarilari`, `start_first_service_protocol`), `openDet` imzası,
`js/utils/helpers.js` toast sözleşmesi, `sw.js`, `js/utils/modal.js`.

**Kesişim disiplini (S1 ile):** S1 (kısır blok) UI kilidi bu yazının tarihi itibarıyla **uygulanmamış** —
commit `c2348b1` yalnız `spec-s1.md` ekledi (CONFIRMED `git show --stat c2348b1`: 1 dosya,
`docs/plans/.../spec-s1.md`), `js/ui.js:1834-1844` `_ovSatir` içinde `kisir` okuması yok
(CONFIRMED grep, HEAD `f0cfa3b`). Adım 1 satırı çıkarırken **kısır kilidi EKLENMEZ** (o S1'in
tek-yazıcı işidir); S1 sonradan aynı satıra UI kilidi eklemişse S4 uygulayıcısı mevcut satırı
okuyup üstüne yazar, kilidi silmez (spec §10 satır 1).

## 1. Adım 0 — Ön uçuş (kod-yazımı YOK)

**0a — gitnexus indeks tazeleme (TÜM adımların kapısı).** Spec §8: spec yazımında indeks
`d6a41c0`'daydı, HEAD'den geride. Uygulayıcı: `gitnexus analyze` ile indeksi dal ucuna
(HEAD `f0cfa3b` + varsa aradaki commit'ler) eşitler. **Worktree-yolu kuralı (onarım turu):**
kayıtlı indeks ana checkout'a (`/home/melik/egesut-erp1`, branch `main`) bağlıdır — analyze orada
koşarsa MAIN'i indeksler, bu dalın ucunu değil. Analyze **bu worktree yolunda** koşturulmalıdır
(onarım turu OBSERVED: kayıt main checkout, lastCommit `d6a41c0`). Kapı kuralı: indeks HEAD'e eş
değilse hiçbir 1-3 adımına başlanmaz. İş bittikten sonra (Adım 4) **tekrar** analyze edilir.
**0b — blast-radius teyidi:** `gitnexus context openDet` (imza + çağrı envanteri; beklenti:
spec B10 onarım-turu sayımı — `js/ui.js:3220` tanım, **ui.js içinde 23 çağrı satırı + çapraz-modül
10 (pedigree-controller 2, forms 5, handlers 2, degisiklikler/degisiklikler.js 1) = 33 çağrı**)
ve `gitnexus impact _ovsyncBildirim` /
`gitnexus impact _ovsyncBaslatBtnHtml` (upstream; beklenti: B4/B16 envanteriyle birebir —
`ovsyncBaslat` çağrıları yalnız `js/ui.js:1164` ve `:1841`, CONFIRMED grep HEAD `f0cfa3b`).
Sapma görürse DURMA-devam etme değil: sapmayı çıktıda raporla, koda dokunmadan değerlendir.
**0c — `code-change-precheck` skill'i** (ui.js/handlers/app.js düzeni öncesi, repo sözleşmesi).
**0d — V-1 canlı şablon teyidi (DEMO kanalı: `SUPABASE_DEMO_PAT` Mgmt query endpoint veya demo pooler psql — tools-bank `supabase_*` PROD'a bağlıdır, KULLANILMAZ: spec-s1 KANAL KURALI + plan-s2 F7; salt-okunur):** `tedavi_sablonu` aktif OVSYNC şablonunun
(`id=a152f7fe-…` beklenir) `tedavi_sablonu_kalem` sayısı → yardım metnindeki seans sayısı bu
ölçüme yazılır (B24: 4 seans OBSERVED 2026-09-24; şablon kullanıcı-düzenlenebilir).
**0e — Y2 ölçüm SQL (demo, SELECT-only):** spec §6.2 sorgusu aynen koşulur; çıktı rapor dosyası
olarak saklanır (sahibe sunulacak; Plan 1 S1 ile AYNI koşum — iki spec tek çıktı paylaşır).
**Bağımlılık:** 0e çıktısı yalnız Adım 4 kabul 12'yi besler — Adım 1-3'ü BLOKLAMAZ; paralel koşabilir.
**0f — çalışma anı tazeleme:** Adım 1'e geçmeden `_ovSatir` (ui.js:1834-1844) güncel halini yeniden
oku (S1/another-lane commit'i gelmiş olabilir; §0 kesişim disiplini).

Doğrulama: `gitnexus list_repos` indeks tarihi/commit'i = HEAD; 0d-0e çıktıları kayıtlı.
Commit: YOK (ölçüm adımı; 0e raporu teslim zarfına gider).

## 2. Adım 1 — ui.js: satır navigasyonu + insan-dili metin (N1 + M1)

**Dosya:** `js/ui.js` (tek yazıcı). **Ön koşul:** Adım 0a tamam.

1. **Extract (B23):** closure-içi `const _ovSatir = u => …` (`_showProtokolEkran` içinde,
   ui.js:1834-1844) modül-seviyesi `function _ovUyariSatirHtml(u){ … }` olarak çıkar; yeri:
   `_protoDetayHayvanGit` bloğunun hemen altı (ui.js:1940 sonrası — protokol sheet yardımcıları
   kümesinde). `_showProtokolEkran` içindeki kullanım `ovList.map(_ovUyariSatirHtml).join('')`
   olur (ui.js:1845). İçerikteki `esc/escAttr/fmtTarih` zaten modül kapsamında — değişmez.
2. **N1 — satır tıklaması:** satır div açılışı
   `<div class="arow" style="border-left:3px solid var(--green);margin-bottom:6px;padding:8px 10px;cursor:pointer"
   onclick="_protoDetayHayvanGit('${escAttr(u.hayvan_id)}')">` olur.
   Kalıp kaynağı spec B12: `_protoDetayHayvanGit` (ui.js:1934-1940) detay-sheet yokken güvenli
   (`if (detayBs)` guard'lı) ve popstate 'det' vakası paneli geri getirir (app.js:162-173, B11).
   `_protoDetayHayvanGit` ismi KORUNUR (opsiyonel rename yapılmaz — spec §3.1; 2 çağrı noktası:
   ui.js:1920 linki + yeni satır). Sessiz-sheet kalıbı (`_sessizSheetGizle`) KULLANILMAZ.
3. **Buton hücresi stopPropagation (B13):** satırdaki buton sarmalı
   `<div style="display:flex;gap:6px;align-items:center" onclick="event.stopPropagation()">`
   olur (birebir `_satirHtml` deseni, ui.js:1820). Başlat/İptal butonlarının kendi davranışı
   bu adımda DEĞİŞMEZ (data-h/2-arg Adım 3'te).
4. **M1 — metin:** ui.js:1837 satırı yerine:
   `Başlat: Ovsynch-56 senkronu (56 günlük program) · Hedef: ${fmtTarih(u.hedef_tarih)}${u.hedef_saat ? ' ' + String(u.hedef_saat).slice(0, 5) : ''} · Zamanlanmış tohumlama (TAI): ${fmtTarih(u.tai_tarihi)}`
   — "Ovsynch-56" adı KORUNUR (sahip kararı); koşullu saat B5/S3 çift-ayraç kozmetiğini kapatır.
5. **Taban etiketi satırı (ui.js:1838) AYNEN korunur.**

**Test (tests/unit/ovsync-pg-ui.test.js):** mevcut `loadBrowserModule('js/ui.js', …)` çağrısının
`expose` listesi ve destructure satırına (satır 12-16) `_ovUyariSatirHtml` eklenir (module-level
`function` olduğundan `sandbox._ovUyariSatirHtml` yeterli — expose şart değil ama tutarlılık için).
Yeni testler:
- **E.1:** html `onclick="_protoDetayHayvanGit(` + `cursor:pointer` içerir.
- **E.2 (kapsam düzeltmesi, onarım turu):** bu adımda yalnız BUTON HÜCRESİ sarmalı doğrulanır —
  `_ovUyariSatirHtml` çıktısı `onclick="event.stopPropagation()"` sarmallı hücre içerir ve
  Başlat/İptal butonları bu sarmalın içinde kalır. **"Panel Başlat butonunun onclick'i
  `event.stopPropagation();` ile başlar" iddiası burada YOKTUR** — panel Başlat'a stopPropagation
  Adım 3'te eklenir (E.6'da doğrulanır); panel İptal'e HİÇ eklenmez (satır-tıklamasından hücre
  sarmalı korur — B13 kalıbı). Bu cümle Adım 1'de test içinde kalırsa kırmızı yanar (v1.0 plan
  hatası).
- **E.3:** M1 metni iki vaka — `hedef_saat:'10:00'` → ` 10:00` basılır; `hedef_saat:null` → saat
  bölümü hiç yok (çift ayraç/boşluk yok). Test verisi kisir'siz hayvanla yazılır (spec §10).
- **XSS (B21 kalıbı):** `hayvan_id:"x'\"<y>"` verildiğinde ham id html'de geçmez (`escAttr`).

**Kapı:** code-change-precheck (Adım 0c) — ui.js düzeni öncesi.
**Doğrulama:** `npm run test:unit` yeşil; `grep -n "_ovSatir" js/ui.js` boş döner (ad kalmadı);
`git diff --stat` yalnız `js/ui.js` + `tests/unit/ovsync-pg-ui.test.js` gösterir.
**Commit:** `spec: S4 adım 1 — İlk Tohumlama satırı hayvan kartına gider + insan-dili metin (N1+M1)`

## 3. Adım 2 — Yardım katmanı (M2/M3) + geri-tuş vakası

**Dosyalar:** `js/ui.js`, `js/utils/handlers.js`, `js/app.js`, iki test dosyası. **Ön koşul:** Adım 1.

1. **ui.js — `_showOvsyncYardim()`:** `_showProtokolDetay` öncülü (B15, ui.js:1866-1932) birebir
   kalıp: `id='ovsync-yardim-bs'`, `z-index:350`, `background:rgba(0,0,0,.55)`, alt-sheet
   (`border-radius:18px 18px 0 0`, safe-area padding), `existedBefore=!!document.getElementById('ovsync-yardim-bs')`
   guard'lı `history.pushState({ovsync_yardim:true}, '', '')` (öksüz girdi yok), backdrop tap +
   ✕ → `_closeOvsyncYardim()`.
2. **ui.js — `_closeOvsyncYardim()`:** `box.remove()` + `if (history.state?.ovsync_yardim) {
   globalThis._modalBackGuard = true; history.back(); }` — `_closeProtokolDetay` ile aynı desen
   (ui.js:1784-1789, B14).
3. **ui.js — `?` rozeti:** ovHtml bölüm başlığına (ui.js:1845) eklenir:
   `🌱 İlk Tohumlama (N) <button onclick="_showOvsyncYardim()" style="margin-left:6px;width:18px;height:18px;border:1px solid var(--ink3);border-radius:50%;background:none;color:var(--ink3);font-size:.65rem;cursor:pointer;line-height:1">?</button>`.
4. **İçerik (statik; seans sayısı Adım 0d ölçümünden):**
   1. **"Ovsynch-56"** — "İneklerde doğum sonrası ilk tohumlama zamanlaması için kullanılan senkron
      programı. Başlat'a dokununca 4 seanslı hormon zinciri (1./8./9./10. gün) ve tohumlama görevi açılır."
   2. **"TAI (Zamanlanmış Tohumlama)"** — "Zincirin sonunda planlanan tohumlama. Ekrandaki tarih,
      başlatma hedefinin 10 gün sonrasıdır." (B8: migration `:1105`).
   3. **"Neden bu hayvan?"** — "Düve: doğumdan 12 ay 21 gün sonra. İnek: son doğum/aborttan 51 gün
      sonra. Görev, hedeften 2 gün önce listede belirir." (B9 `:74-104` + B7 `:1117`).
5. **handlers.js — navGeriKarar (js/utils/handlers.js:507-529):** iki mikro-diff:
   - `if (ctx.protoDetayAcik) return { tur: 'proto-detay' };` (satır 519) hemen sonrasına
     `if (ctx.ovsyncYardimAcik) return { tur: 'ovsync-yardim' };` eklenir.
   - yut satırına (satır 524) `state.ovsync_yardim` eklenir:
     `if (state.protokol || state.proto_detay || state.ovsync_yardim || state.modal) return { tur: 'yut' };`
   - JSDoc ctx/dönüş satırlarına (503-506) `ovsyncYardimAcik` / `'ovsync-yardim'` işlenir.
6. **app.js — popstate:** ctx nesnesine (js/app.js:123-134) `ovsyncYardimAcik: !!document.getElementById('ovsync-yardim-bs'),`
   alanı eklenir; switch'e (js/app.js:151-158 'proto-detay' case'i yanına):
   `case 'ovsync-yardim': { const _oyb = document.getElementById('ovsync-yardim-bs'); if (_oyb) _oyb.remove(); return; }`
   — panel `protokol-bs` ekranda kalır (yardım katmanı paneli gizlemez; spec kabul 8).

**Test:**
- `tests/unit/nav-geri-karar.test.js` matrisine 2 satır: `{ovsyncYardimAcik:true}` → `{tur:'ovsync-yardim'}`;
  `{state:{ovsync_yardim:true}}` (DOM yok) → `{tur:'yut'}`.
- **E.4:** `tests/unit/ovsync-pg-ui.test.js` — `_showOvsyncYardim` sandbox'ta tanımlı; html üretimi
  DOM stub ile ya da içerik fonksiyonu üzerinden 3 madde metninin varlığı doğrulanır
  ("Ovsynch-56", "TAI", "12 ay 21", "51", "2 gün").
- **e2e (RPC-stub ŞARTI, onarım turu bulgusu):** `tests/modal-router.spec.js` — mevcut
  `injectProtokolUyari` yardımcısı (satır 27-37) TEK BAŞINA YETMEZ: o yardımcı yalnız
  `window.__protokolUyarilar`'ı besler (Gecikmiş/Yaklaşan/Tamam bölümleri), ama `?` rozetinin
  yaşadığı İlk Tohumlama bölümü `_showProtokolEkran` içindeki
  `await rpc('ovsync_baslat_uyarilari')` sonucuyla kurulur (ui.js:1830-1845). Canlı demo penceresi
  KANAL+GÜN BAĞILIDIR (spec V-5/F10 — 2026-09-24 iki ölçüm FARKLI kanallardan: DEMO psql 0 satır
  [29 açık, min hedef 2026-10-06], tools-bank/PROD 1 satır [kupe 32, hedef 2026-09-26]) → canlı veriyle test deterministik DEĞİL. Yeni test ÖNCE RPC'yi stub'lar:
  `page.route('**/rest/v1/rpc/ovsync_baslat_uyarilari**', …fulfill({ok:true, uyarilar:[{gorev_id,
  hayvan_id, kupe_no, kategori, hedef_tarih, hedef_saat:'10:00', tai_tarihi, kaynak:'ILK-TOH-DUVE-e2e',
  taban_turu:'duve'}]}))` (yalnız bu testin scope'unda; `injectProtokolUyari` sonrası `_showProtokolEkran`
  yeniden çağrılır), sonra: `?` tıkla → `#ovsync-yardim-bs` attached → `page.goBack()` → sheet
  detached VE `#protokol-bs` hâlâ attached (dash'e atlamaz; B22 invariantı).

**Doğrulama:** `npm run test:unit` yeşil; modal-router e2e `npm run test:docker:demo` ile yeşil
(ortam: Playwright Docker zorunlu — WebKit/ICU; memory kaydı). `gitnexus detect_changes` beklenen
semboller: `_showOvsyncYardim`, `_closeOvsyncYardim`, `navGeriKarar`, popstate case.
**Commit:** `spec: S4 adım 2 — Ovsynch-56/TAI yardım katmanı + geri-tuş vakası (M2/M3)`

## 4. Adım 3 — Bildirim hayvan kartına gider (N2) + `?v=` damgası

**Dosyalar:** `js/ui.js`, `index.html`. **Ön koşul:** Adım 2.

1. **`ovsyncBaslat` imzası (ui.js:1173):** `async function ovsyncBaslat(gorevId, hayvanId)` —
   `if(!gorevId) return;` korunur. Başarı kolunda (ui.js:1182) `_ovsyncBildirim(...)` çağrısına
   3./4. argüman: `_ovsyncBildirim('İlk tohumlama protokolü başlatıldı', 'Ovsynch-56 seansları açıldı. TAI hedefi: '+fmtTarih(...), hayvanId)`.
   `hayvanId` boşsa davranış bugünkü hale düşer (kabul 11 — akış kırılmaz).
2. **İki buton aynı zarfta `data-h` taşır (B16):**
   - `_ovsyncBaslatBtnHtml` (ui.js:1164): `data-h="${escAttr(t.hayvan_id)}"` +
     `onclick="event.stopPropagation();ovsyncBaslat(this.dataset.g,this.dataset.h)"`.
   - Panel satırı (Adım 1'de çıkarılan `_ovUyariSatirHtml` içindeki Başlat): aynı ek.
   - İptal butonları değişmez.
3. **`_ovsyncBildirim(baslik, govde, hayvanId, kupeNo)` (ui.js:1201):**
   - `granted` kolunda `const notif = new Notification(...)`; ardından
     `notif.onclick = () => { try { window.focus(); openDet(hayvanId); } catch(e){} };`
     (yalnız `hayvanId` varken; V-3: PWA teslimi best-effort — kabul 9, teslim notuna yazılır).
   - İzin yok/default VE `hayvanId` varken: `_ovsyncBildirimBanner(hayvanId, kupeNo)` çağrılır
     (fire-and-forget).
4. **YENİ `_ovsyncBildirimBanner(hayvanId, kupeNo)` (async):** spec §3.2 birebir —
   `id='ovsync-bildirim-bs'`, `z-index:310`, alt-sheet görsel dili, **pushState YOK**;
   içerik: "✅ İlk tohumlama protokolü başlatıldı" + tıklanabilir satır
   `🌱 {kupe_no} · TAI {tarih} — Hayvan kartına git →` (kupe çözümü `await getData('hayvanlar')`
   içinden `id===hayvanId`; bulunamazsa `—` — satır yine tıklanır); satır onclick:
   `banner.remove(); openDet(hayvanId)`; backdrop tap: `remove()`; `setTimeout(() => box.remove(), 10000)`
   — timer değişkeni banner node'una iliştirilir (elle kapanış timer'ı etkisiz kalır).
   Fonksiyon yeri: `_ovsyncBildirim` altı.
5. **`index.html` damga:** `?v=20260924-01` → `?v=20260925-01`, tek değer TÜM etiketlerde
   (manifest link satır 11 dahil; script bloğu satır 2325-2331+) — tek `sed` geçişi; iki farklı
   değer KALMAZ (B20, V-4: ui.js+handlers+app.js üçü değişti).

**Test:** **E.5** banner html hayvan-kartı aksiyonu taşır (`openDet(` string'i) + escAttr disiplini
(ham id basılmaz; test `extra`'ya `getData: async () => [{id:'h1', kupe_no:'K1'}]` stub'ı eklenir);
**E.6** `_ovsyncBaslatBtnHtml` çıktısı `data-h=` + 2-arg çağrı içerir VE **panel Başlat butonu
(`_ovUyariSatirHtml` çıktısı) bu adımdan itibaren `onclick="event.stopPropagation();ovsyncBaslat(...)"
ile başlar** (Adım 1 E.2'sinden buraya taşındı — onarım turu); mevcut P3/P6 testleri
(satır 40-49) güncel imzayla yeşil kalır.

**Kapı:** code-change-precheck; **db-validate N/A kanıtı** Adım 4'e saklandı (bu adımda migration
dosyası ÜRETİLMEZ).
**Doğrulama:** `npm run test:unit` yeşil; `grep -c "20260924-01" index.html` = 0;
`grep -c "20260925-01" index.html` > 0. **Commit:**
`spec: S4 adım 3 — ovsyncBaslat bildirimi hayvan kartına gider (app-içi banner + Notification onclick) + ?v damgası`

## 5. Adım 4 — Son kapı: tam doğrulama + teslim zarfı (+ son review)

Kod yazımı bu adımda YALNIZ Adım 1-3 çıktısında beklenen-etki dışı bulgu çıkarsa fix olarak yapılır.

1. `npm run test:unit` — TÜM suite yeşil (E.1-E.6 dahil ≥5 yeni test, kabul 14).
2. `npm run test:docker:demo` — modal-router spec (mevcut B21 maddeleri + yeni yardım-sheet e2esi) yeşil (kabul 15).
3. `gitnexus detect_changes` — etki yalnız beklenen semboller: `_ovUyariSatirHtml`, `_ovsyncBildirim`,
   `ovsyncBaslat`, `_showOvsyncYardim`, `navGeriKarar`, popstate case (kabul 17). `openDet`'in imza
   değişikliği YOK (kabul 4); dokunulmayan 33 çağrı noktasında (23 ui.js + 10 çapraz-modül, B10)
   davranış değişikliği görülmemelidir.
4. **db-validate kapısı kanıtı:** `git diff --stat main...HEAD -- supabase/migrations/` BOŞ (migration
   yok kanıtı; bir dosya belirdiyse spec sapması — dur ve raporla).
5. **Kabul checklist'i** (spec §7 A1-A4, B5-B8, C9-C11, D12-D13) madde madde işaretlenir; C9 için
   "PWA Notification tıklaması tarayıcıya bağlıdır — birincil yol app-içi banner" notu, D12 için
   Adım 0e Y2 raporu (`sapma<0` satır YA yok YA kök-neden kolonlarıyla açıklanmış), kabul 16 için
   "sahip yürüyüşü öncesi hard-reload" notu teslim metnine yazılır. **Pencere KANAL+GÜN-bağlı teslim
   notu (onarım turu + F10 kanal-düzeltmesi, OBSERVED 2026-09-24):** Sahibin yürüyüşü DEMO üzerinedir;
   DEMO'da pencere bugünkü veriyle ~2026-10-04'e kadar BOŞTUR (demo açık görevlerin en yakın hedefi
   2026-10-06 — spec-s1 K12; RPC 0 satır). "Kupe 32 / hedef 2026-09-26" gözlemi tools-bank
   kanalındandır = **PROD** — demo panelinde görünmez. Teslim anında `ovsync_baslat_uyarilari` satır
   sayısı (DEMO kanalından) yeniden
   ölçülür; pencere o an boşsa satır navigasyonu/yardım katmanının sahip yürüyüşü için
   sentetik e2e kanıtı (RPC stub'lı modal-router testi) + Adım 0e Y2 raporu birincil kanıttır —
   teslim metnine açıkça yazılır. **U-1 yanıtı (OBSERVED):** açık görevlerde `hedef_saat IS NULL`
   oranı 0 (DEMO 0/29 + PROD 0/31 — kanal-bazlı payda, F10) — koşullu-basım kuralı pratikte nötr, Y2 raporuna
   bilgi satırı olarak eklenir.
6. **Teslim zarfı:** değişen dosya listesi + commit SHA'ları + Y2 raporu + test çıktıları; "demo teste
   hazır" ibaresiyle sahibe sunulur. **Son review kapısı:** iş bittikten sonra ayrı bir review turu
   (sahip isteği — kod incelemesi + kabullerin bağımsız teyidi) geçmeden iş "bitti" ilan edilmez.
7. **gitnexus yeniden analyze** (Adım 0a'nın aynası — indeks her zaman çalışılan commit'i yansıtsın).
**Commit (yalnız fix varsa):** `spec: S4 adım 4 — doğrulama düzeltmeleri`

## 6. Bağımlılık grafiği

```
0a (indeks) ──► Adım 1 ──► Adım 2 ──► Adım 3 ──► Adım 4 ──► son review kapısı
0b/0c (pre-check, Adım 1 öncesi tamamlanır)
0d (V-1 şablon teyidi) ──► Adım 2 (yardım metni seans sayısı)
0e (Y2 ölçüm, paralel koşabilir) ──► Adım 4 (kabul 12)  [Adım 1-3'ü BLOKLAMAZ]
0f (satırın güncel halini oku) ──► Adım 1 içinde
S1 lane (kısır UI kilidi) → S4 üstüne yazar; S4 kilidi silmez (§0)
```

## 7. Engeller ve yedek yollar

- **Eşzamanlılık:** 10 agent senaryosunda bu zarfın dosyalarında yabancı commit görünürse koşum
  durdurulur, ENGEL olarak raporlanır (tek-yazıcı sözleşmesi, AGENTS.md/harness).
- **Notification tıklaması PWA'da teslim edilmeyebilir (V-3, INFERRED):** birincil yol app-içi
  banner; kabul 9 bilinçli best-effort — ENGEL değil, belgelenir.
- **Y2'de `sapma<0` satır çıkarsa:** filtre YAZILMAZ (Y1 — tek otorite sunucu); satırlar kök-neden
  kolonlarıyla raporda tek tek açıklanır (kabul 12); kural düzeltmesi bu spec DIŞI (Plan 1).
- **Canlı demo penceresi kanal+gün-bağlı (onarım turu gözlemi + F10 kanal-düzeltmesi):** RPC
  `ovsync_baslat_uyarilari` 2026-09-24'te iki kanaldan iki ölçüm: DEMO psql 0 satır, tools-bank(=PROD)
  1 satır (doluluk hedef−2 kuralına göre kanal ve gün bazında değişir). Bu ENGEL DEĞİLDİR — unit testler (E.1-E.6) veriyle beslenir,
  e2e RPC stub ile deterministik açılır (Adım 2); sahip yürüyüşü notu Adım 4'ün 5. maddesinde.
- **GEBELIK_KONTROL bildirim metni sahipliği (U-3, UNKNOWN):** bu planda YOK; decomposition'da
  tek sahibe bağlanmalı — buraya sürüklenirse ENGEL olarak işaretlenir.

## 8. Geri dönüş (spec §9)

Yüzey yalnız istemci dosyaları → `git revert <adım-commit'leri>`; DB'de geri alınacak hiçbir şey yok.
Kısmi: yardım katmanı sorunluysa Adım 2 commit'i bütünüyle revert (ui.js + handlers + app.js AYNI
commit'te — **ayrık revert YASAK**; öksüz `{ovsync_yardim}` girdisi bırakır). Banner sorunluysa
`_ovsyncBildirim`'in izin-yok kolu tek satırla banner'sız eski davranışa döner (kabul 11 yolu).

## 9. Kendi kanıt tablosu (bu plan yazımında doğrulananlar)

| # | İddia | Etiket |
|---|---|---|
| 1 | `_ovSatir` closure-içi, ui.js:1834-1844; onclick yok | CONFIRMED okuma, HEAD f0cfa3b |
| 2 | `_protoDetayHayvanGit` ui.js:1934-1940, guard'lı; popstate 'det' paneli geri getirir app.js:162-173 | CONFIRMED okuma |
| 3 | `ovsyncBaslat` çağrıları yalnız ui.js:1164 ve :1841; tanım :1173 | CONFIRMED grep |
| 4 | `_ovsyncBildirim` ui.js:1201-1207, yalnız Notification API, onclick yok | CONFIRMED okuma |
| 5 | navGeriKarar handlers.js:507-529; proto-detay dönüşü :519; yut satırı :524 | CONFIRMED okuma |
| 6 | popstate ctx/switch app.js:103-184; 'proto-detay' case :151-158 | CONFIRMED okuma |
| 7 | S1 UI kilidi uygulanmamış (c2348b1 yalnız spec dosyası) | CONFIRMED `git show --stat` |
| 8 | `?v=20260924-01` index.html:11 ve 2326-2331+ tek değer | CONFIRMED grep |
| 9 | Unit altyapı `loadBrowserModule` function'ları sandbox'a koyar; test dosyası ui.js'i expose'la yüklüyor | CONFIRMED tests/unit/support/loadModule.js:10-12,168 + ovsync-pg-ui.test.js:12-16 |
| 10 | e2e koşum `npm run test:docker:demo` (PLAYWRIGHT_DEMO_MODE) | CONFIRMED package.json scripts |
| 11 | Y2 sorgusunun tablo/kolon adları (gorev_log, hayvanlar, dogum, tohumlama, `_ovsync_kural_tarihi`) | CONFIRMED spec §6.2 + **canlı demo'da SORGU BÜTÜNÜ koştu (OBSERVED 2026-09-24):** 29-31 açık görev (iki ölçüm; canlı veri kayar), hata yok — uygulayıcı 0e'de yeniden koşar |
| 12 | Canlı demo OVSYNC şablonu 4 seans | OBSERVED 2026-09-24 (B24, iki kez: spec yazımı + onarım turu) — 0d'de teyit |
| 13 | `openDet` çağrı yüzeyi: ui.js 23 + çapraz-modül 10 = 33 satır; tanım `js/ui.js:3220` | CONFIRMED grep, onarım turu (spec B10) |
| 14 | RPC penceresi kanal+gün-bağlı: 2026-09-24 iki ölçüm FARKLI kanallardan — DEMO psql 0 satır (29 açık, min hedef 2026-10-06), tools-bank/PROD **1 satır** (kupe 32, hedef 2026-09-26, tai 2026-10-06); DEMO penceresi ~2026-10-04'e kadar boş | OBSERVED demo psql + tools-bank(=PROD) RPC 2026-09-24 (spec V-5/F10 kanal-düzeltmesi; spec-s1 K12: demo 29 / prod 31) |
| 15 | U-1 yanıtı: açık görevlerde `hedef_saat IS NULL` = 0 (DEMO 0/29 + PROD 0/31; kanal-bazlı payda) | OBSERVED demo psql + tools-bank(=PROD) SELECT 2026-09-24 |
| 16 | `start_first_service_protocol` canlı gövdesinin başarı RETURN clause'unda `hayvan_id` yok; `ovsync_baslat_uyarilari` canlı gövdesi `hayvan_id`/`taban_turu`/pencere (+2) içerir | OBSERVED canlı demo `pg_get_functiondef` 2026-09-24 |
| 17 | `injectProtokolUyari` yalnız `window.__protokolUyarilar` besler; İlk Tohumlama bölümü RPC kaynaklıdır → e2e'ye RPC stub şart | CONFIRMED `tests/modal-router.spec.js:27-37` + `js/ui.js:1830-1845` okuma |
| 18 | Toast aralığı: `_toastPump` :55, textContent :63, `toast()` :72-86 (`js/utils/helpers.js`) | CONFIRMED grep, onarım turu ikinci düzeltme |
| 19 | `getData('hayvanlar')` konumları `js/ui.js:9687, :10234`; `:1193` `getData('gorev_log')` (ovsyncIptal) | CONFIRMED sed, onarım turu (spec F1 ile uyumlu) |
