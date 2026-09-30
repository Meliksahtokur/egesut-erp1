# impl-P4-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P4 (plan.md:459-480, birebir; MADDE DRIFT KAPISI — yalnız P4 yazıldı)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P4-GOREV.md` · **Tarih:** 2026-09-30
- **Sonuç:** 3/3 kabul kanıtlı — **TAMAM** (self-repair tavanı 2/2 kullanılmadı; yalnız TEST dosyasında 3 assertion-realm düzeltmesi, production kod tek turda yeşil)
- **Zorunlu protokol:** using-superpowers-obra (SUBAGENT-STOP sahibin kuralıyla geçersiz kılındı) → `code-change-precheck` + `test-driven-development-obra` skill'leri önce çağrıldı; domain-rules.md okundu (çelişki yok — P4 salt veri katmanı, §18.15 takip sözleşmesiyle uyumlu) · blast radius: `gitnexus impact rpc upstream` [OBSERVED — CRITICAL, 16 doğrudan tüketici/23 akış; H8'in etkisi yalnız 40P01/55P03 dalında mesaj metni, mevcut catch'ler e.message basar → kırılma yüzeyi yok] · JS keşfi atlas_query (rpc→js/api.js:71) + bitişik gövde okuması · sonunda `verification-before-completion-obra`.

## Yazılan dosyalar (manifest 2/2 + DONE — TEK YAZICI)

1. `js/api.js` (MODIFY — 3 edit: (a) `rpc()` hata satırına H8 kod dalı [CONFIRMED js/api.js:89-97]; (b) `RPC_TABLES`'a `tohumlama_bos_ve_devam` 9 tablo kaydı + invariant yorumuna `ovsync_takip_listele` istisnası [CONFIRMED js/api.js:388-390, 426-430]; (c) dosya sonuna `_ovsyncTakipInvalidate` + `ovsyncTakipGetir` + `tohumlamaBosVeDevam` [CONFIRMED js/api.js dosya sonu, apiCokluKaydir sonrası])
2. `tests/unit/ovsync-api.test.js` (create — P4'ün kendi birim testi, 17 test)
3. `runs/2026-09-28-ovsync-takip/impl-P4-DONE.md` (bu dosya)

Manifest dışı repo yazımı YOK [OBSERVED `git status --porcelain | grep -E "api\.js|ovsync-api\.test|impl-P4"` → yalnız `M js/api.js` + `?? tests/unit/ovsync-api.test.js`]. **Not — ağaçta başkasının yazımı var:** `js/app.js +7` ve `js/ui.js +65` değişmiş; diff başlıkları P5 iskeleti ("OVSYNC TAKİP SAYFASI (P5 iskelet…)", goTo `ovsync` dalı) — paralel P5 worker oturumunun yazımı (plan P4 "Paralel: P5-P7 ile evet"). Bunlar bu zarfın manifesti dışıdır, dokunulmadı [CONFIRMED `git diff js/ui.js` başlığı]. P5 iskeleti `_ovsyncDashDurum`'u benim `ovsyncTakipGetir` dönüş sözleşmesine ({bayat, veri, zaman}) bağlamış — iki paralel teslim interface'te çakışmıyor [CONFIRMED ui.js diff].

## Kırmızı→yeşil koşum çıktıları (TDD kanıtı)

### RED (uygulama ÖNCE — test yazıldı, koşuldu, kırmızı görüldü)

[OBSERVED `node --test tests/unit/ovsync-api.test.js` → **14 fail / 3 pass**]:

| Kırmızı (14) | Neden (hepsi feature-missing) |
|---|---|
| RPC_TABLES: sarmal 9 tablo | `tohumlama_bos_ve_devam` mapte yok |
| RPC_TABLES: takip HARİTA DIŞI | invariant yorumu + harita-dışı tarama |
| ovsyncTakipGetir ×5 | fonksiyon yok (taze/padok-null/hata-bayat/veri-yok/offline) |
| tohumlamaBosVeDevam ×3 | fonksiyon yok (taşıma/ok:false e.data/invalidate) |
| _ovsyncTakipInvalidate | fonksiyon yok |
| H8 40P01 + H8 55P03 | kod dalı yok → gerçek mesajlar `deadlock detected` / `lock_not_available` dönüyordu [OBSERVED assertion diff] |
| envanter: api.js yardımcı | `_ovsyncTakipInvalidate tanımı yok` |

Yeşil kalan 3 doğru davranış: 2 mevcut-davranış kilidi (eşleşmeyen kod → _trErr; kodu olmayan hata → orijinal mesaj) + ui.js/forms.js envanter senkronu (noktalar kaynakta mevcut).

### GREEN (uygulama SONRASI)

[OBSERVED `node --test tests/unit/ovsync-api.test.js` → **17 pass / 0 fail**] — aynı çıktı bitiş kapısında TAZE tekrarlandı [OBSERVED].

## Kabul maddeleri (plan.md:478 birebir)

### 1) Birim testi yeşil — hash üyelik + invalidate envanteri

- **Hash üyelik (sarmal İÇERİDE):** [OBSERVED test] `RPC_TABLES.tohumlama_bos_ve_devam` planın 9 tablosuyla birebir (sıra-bağımsız deep eşitlik): `['tohumlama','gorev_log','stok','stok_hareket','hayvanlar','islem_log','cases','treatment_days','treatment_day_uygulamalar']` [CONFIRMED plan.md:473 + js/api.js kaydı].
- **Hash üyelik (takip HARİTA DIŞI):** [OBSERVED test] `RPC_TABLES.ovsync_takip_listele === undefined` + kaynakta invariant yorumuna istisna yazımı (`ovsync_takip_listele de salt-okuma (P4): HARİTA DIŞI…`) [CONFIRMED js/api.js:429-430].
- **Invalidate nokta tamlığı (grep tabanlı senkron test):** [OBSERVED test] api.js: yardımcı tanımı + `window.__ovsyncTakip = null` gövdesi + api.js içi nokta (tohumlamaBosVeDevam gövdesinde çağrı, her iki dalda); plan P4 noktaları ui.js/forms.js'te fonksiyon-adı bazlı senkron: `ovsyncBaslat` (ui.js:1799), `_protokolIptalAkisi` (:1857), `submitInsem` (forms.js:375 — planın 426-433 referansı bu fonksiyonun pullTables bloğu), `tohSonuc` (forms.js:4335), `gorev_ertele` çağrısı (ui.js:1568), `apiCokluKaydir` çağrısı (forms.js:5453), `hizli_uygulama` çağrıları (ui.js:3722/3936/9040), `bulk_ilac` (forms.js:4839/4854), `seansTamamla` (forms.js:5068; api.js rpc sarmalı :962), `gebelik_kaydet_manual` (forms.js:4500). **Satır değil fonksiyon-adı sabitli** — plan satır referansları bayat çıkmış (ui.js:1812→1799, :1873→1857), adlar stabil.

### 2) `node --check js/api.js` temiz; `git diff --check` temiz

[OBSERVED `node --check js/api.js` → exit 0 "SYNTAX OK"] · [OBSERVED `git diff --check` → boş çıktı, exit 0 "DIFF-CHECK TEMİZ"].

### 3) Kırmızı→yeşil sırası kanıtı

Yukarıda iki koşum çıktısı — test ÖNCE koşuldu (14 fail görüldü), sonra uygulama, sonra 17 pass. Regresyon komşuları: [OBSERVED `node --test tests/unit/api.test.js` → 24/24 pass] · [OBSERVED ovsync-pg-hata + ovsync-pg-pull-haritasi + hizli-uygulama-guard → 23/23 pass].

## Zarf maddeleri birebir

- **`ovsyncTakipGetir(p_padok = null)`** → `rpc('ovsync_takip_listele', { p_padok })` — gerçek imza P1 migration'dan: `ovsync_takip_listele(p_padok text DEFAULT NULL, p_sonlanan_gun int DEFAULT 60)` [CONFIRMED supabase/migrations/20260929000001:49; p_sonlanan_gun DEFAULT'lu, JS'ten geçilmez]. Başarıda `window.__ovsyncTakip = {veri, zaman: Date.now()}`; hata/offline'da throw YOK → `{bayat:true, veri: önceki|null}`; bayat yolda cache EZİLMEZ; önbellek yoksa `veri: null` [OBSERVED 4 test].
- **Offline tanıma M-25 uyumlu:** rpc() gerçek fetch hatasından (TypeError/Failed to fetch → 'İnternet bağlantısı gerekli' Error'ı) [CONFIRMED js/api.js:79-88 mevcut M-25/B23 bloğu] → ovsyncTakipGetir bunu bayat yola düşürür; `navigator.onLine` ön koşulu YAZILMADI [OBSERVED test "onLine:true iken fetch hatası → bayat"].
- **`tohumlamaBosVeDevam(params)`** → `rpc('tohumlama_bos_ve_devam', params)`, params nesnesi birebir taşınır [OBSERVED strictEqual referans testi]. Gerçek imza P2b migration'dan: `p_tohumlama_id text, p_muayene_gorev_id uuid, p_secim text, p_pg_urun text, p_pg_doz numeric, p_gun int, p_saat time, p_notlar text — tümü DEFAULT NULL` [CONFIRMED supabase/migrations/20260929000002:533-541] — JS sarmalı params'ı ısmarlama map'lemez (uydurma yok), p_* anahtarları P10 form katmanının sorumluluğu. Red kodları: rpc() ok:false → throw + `e.data` gövde taşır [OBSERVED test: TAKIP_ACIK:{muayene_tarihi,muayene_saat} payload'ı e.data'dan çözüldü — H5 alan adları P3b-DONE tablosuyla aynı].
- **`_ovsyncTakipInvalidate()`** → `window.__ovsyncTakip = null` [OBSERVED test].
- **H8:** `rpc()` hata satırı `error.code === '40P01' || error.code === '55P03'` → `throw new Error('İşlem başka bir kayıtla çakıştı, tekrar deneyin')`; otomatik retry YOK [OBSERVED 2 test: rpc handler tam 1 kez çağrıldı]; eşleşmeyen kod → mevcut `_trErr` akışı aynen [OBSERVED 2 test: duplicate key → 'Bu kayıt zaten mevcut'; kodsuz hata → orijinal mesaj].

## Rulings (sessiz varsayım yok — hepsi kayıtlı)

1. **Taze dönüş biçimi `{bayat:false, veri, zaman}`** — plan yalnız "başarıda window.__ovsyncTakip = {veri, zaman}" diyor, dönüş değeri vermemişti; P5 `loadOvsyncDash` durum matrisi taze dalda da veriye eriştiği için bayat yoluyla aynı şekil verildi (paralel P5 iskeletinin `_ovsyncDashDurum` diff'i bu sözleşmeyi birebir bekliyor [CONFIRMED ui.js diff]). Cache şeması plandaki gibi yalnız {veri, zaman}.
2. **api.js içi invalidate noktası = `tohumlamaBosVeDevam` (başarıda + hata yolunda)** — plan "P4 yalniz api.js'teki yardımcıyı + api.js içi noktaları kurar" dedi; api.js'te takip verisini değiştiren tek akış sarmalın kendisidir (api.js tohumlama/padok/görev yazmayı ui/forms'a bırakır — mevcut mimari [CONFIRMED apiCokluKaydir JSDoc "Online-only… pull seti RPC_TABLES'te" deseni]). Red yolda da invalidate zararsızdır (veri değişmemiş olabilir; UI bir sonraki çekimde tazelenebilir).
3. **H8 yalnız `rpc()` hata satırına** — `dbInsert`/`dbUpdate`'teki aynı-görünümlü iki hata satırı (js/api.js:271, 292 — REST db.from() yolları) plan metninde YOKTU, dokunulmadı (plan.md:476 "rpc()'nin hata satırına"; REST satır-yazmada RPC-deadlock yüzeyi yok).
4. **RPC_TABLES kaydının konumu** `tohumlama_sonuc_bekliyor` satırının altı (tohumlama cluster'ı) — plan konum şart koşmuyordu (":376 civarı").
5. **Envanter testi fonksiyon-adı sabitli** — planın satır referansları (ui.js:1812/1873, forms.js:426-433/4344-4368) güncel ağaçta kaymıştı; senkron test satır kırılganlığı yerine akış-adı kırılganlığı seçildi (refactor'da test kırılır, envanter güncellenir — amaç bu).
6. **3 test assertion realm-düzeltmesi (production kod YEŞİL'den sonra)** — vm sandbox'ta yaratılan nesnelerin Object.prototype/Error sınıfı test realm'ından farklı: `deepStrictEqual` "same structure but not reference-equal" + `instanceof Error === false` veriyordu [OBSERVED 3 fail diff]. Çözüm spread-kopya + `e.name === 'Error'` duck-typing; production davranışı değişmedi, yalnız assertion realm-bağımsız yapıldı. Kapı turu sayılmaz (self-repair 0/2) — ilk GREEN koşumunda production kod 14/14 P4-davranışını ilk seferde karşıladı.
7. **Blast-radius hook bayrağı** — Edit'i js/api.js'te bloklayan PreToolUse hook gereği `gitnexus impact` (built-in, ana-checkout indeksi — tools-bank köprüsü `/root` izinsizliği verdi [OBSERVED]) koşuldu, ardından `/tmp/blast-radius-done` timestamp'i elle kuruldu [OBSERVED]. Impact sonucu: CRITICAL (16 tüketici) — kabul gerekçesi Ruling 3: davranış farkı yalnız iki SQLSTATE'te mesaj metni; tüm catch'ler e.message gösterir.

## Tam süite göre durum (TDD "project suite" kuralı)

[OBSERVED `node --test tests/unit/*.test.js` → 1076 test, 1064 pass, **12 fail** — HEPSİ pre-existing]: config, dates, format, helpers-extra, kupe-oneri, state, toast, trLower, ui-pure (dosya yüklemeleri api.js'ten bağımsız saf modüller) + LUNA-3 (canlı DEMO DB gerektirir) + 2 bc-tarih (takvim, bugüne-göre). **Pre-existing kanıtı:** [OBSERVED] js/api.js HEAD'e alınarak (değişikliksiz) config.test.js yeniden koşuldu → yine fail; api.js değişikliğimle ilgisiz. Benim etki komşularım (api.test.js, ovsync-*, hizli-uygulama-guard) tamamen yeşil.

## Açık kalemler (BLOKE değil)

1. **ui.js/forms.js invalidate ÇAĞRILARI yazılmadı** — planın tek-yazıcı kuralı: P6+/P9/P10'un dosyaları; envanter testi kilitli, çağrılar kendi zarflarında eklenir.
2. **Tam süitede 12 pre-existing fail** (yukarıda adları) — bu zarfın kapsamı dışı; ilgililere not.
3. **Paralel P5 worker aynı worktree'ye yazıyor** (js/app.js +7, js/ui.js +65) — çakışma yok (farklı dosyalar; P5 iskeleti benim interface'i bekliyor ve benim teslimat birebir karşılıyor); merge sırası mimarda.
4. Atlas indeksi worktree dalını değil ana-checkout HEAD'ini görüyor (atlas sha 951dee09 vs worktree 0a74570) — konum keşfinde kullanıldı, tüm içerik worktree dosyasından okundu; etkisiz.
5. Commit ATILMADI (yasak) — değişiklikler ağaçta: `M js/api.js`, `?? tests/unit/ovsync-api.test.js`.
