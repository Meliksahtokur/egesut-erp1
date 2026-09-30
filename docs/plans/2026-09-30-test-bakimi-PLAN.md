# PLAN — B12 test altyapısı bakımı (2026-09-30)

Sahip emri (2026-09-30 ~13:45): backlog "fixleyelim" + kapsam kararları — **5.07 SİL**, **testMatch düzelt**,
**demo workers DÜŞÜR**. Keşif: `runs/2026-09-30-test-bakim/KESIF-B12-raporu.md` (erp-explorer, dosya:satır kanıtlı).

## Girdiler (keşif kanıtları)
- `playwright.config.js`: testDir `./tests` (:18); **testMatch/testIgnore tanımsız** → PW default
  `*.spec.js` **+ `*.test.js`** toplar; workers `CI?1:undefined` (:21) → lokalde PW default = %50×32 = **16**;
  retries 1 (:20); fullyParallel `!CI` (:22). İki ağaç (worktree/ana checkout) birebir aynı [CONFIRMED keşif].
- 4 collect hatası: `tests/unit/etiket-tazelik-v23.js:5`, `v23b:8`, `v23c:9`, `v23e:9` — `node:test`
  import'u PW altında ReferenceError (kanıt `e2e-postmerge-c219c2a.txt:251-298`). Worktree'de v23+v23b
  (2 hata), main'de 4.
- 5.07: `tests/e2e.spec.js:557-566` "5.07 overlay dışına tıklanınca detay kapanmaz" — ortak openApp/navTo
  dışında bağımlılık yok; "5.07" başka kopya yok → temiz silme.
- 429: tek doğrudan — B17 `tests/offline-kuyruk.spec.js:90` AuthApiError "Request rate limit reached"
  (e2e-specs-postmerge-c219c2a.txt:1337); `:66` timeoutla dolaylı.

## Hedef
Dal **`test-bakim`** (main `c219c2a`'dan, worktree içinde açılır). Değişen yalnız 2 dosya:
`playwright.config.js` + `tests/e2e.spec.js`.

## Karar: workers = 8
Kaynak: PW default 16'nın yarısı; doğrudan 429 tek test (B17) — baskıyı yarıya indirmek ölçülebilir
ilk adım [INFERRED; yetersizse takip turunda 4'e düşürülür]. Sahip onayı "değer plan ölçümüyle" şeklinde.

## Maddeler

### T1 — playwright config: testMatch + workers
- `git checkout -b test-bakim main` (worktree; runs/ untracked kalır).
- **KIRMIZI (önce ölç, kayda geç):** PW listesi — `node /home/melik/egesut-erp1/node_modules/@playwright/test/cli.js test --list`
  (cwd worktree; tarayıcı gerekmez). Beklenen kırmızı: listede `tests/unit/etiket-tazelik-v23*.js` satırları
  VEYA collect error çıktısı.
- `playwright.config.js`'e: `testMatch: '**/*.spec.js'` (unit `*.test.js` PW toplanmasın) + `workers: 8`
  (lokalde sabit; CI kolu `CI?1` korunur — mevcut `workers: process.env.CI ? 1 : undefined` ifadesi
  `workers: process.env.CI ? 1 : 8` olur; yorum satırı ekle: "unit *.test.js node:test ile koşar; demo
  rate-limit için 8").
- **YEŞİL:** aynı `--list` komutu — unit dosyaları listede YOK, collect error 0.
- Commit: `test-bakim T1: playwright testMatch *.spec.js (unit collect 0) + workers 16→8 (demo rate-limit)`.

### T2 — 5.07 senaryosunun silinmesi
- **KIRMIZI:** `--list | grep "5.07"` → "5.07 overlay dışına tıklanınca detay kapanmaz" görünür.
- `tests/e2e.spec.js:557-566` test bloğunu sil (başlık+gövde, 10 satır; describe bloğuna dokunma).
- **YEŞİL:** `--list | grep 5.07` → boş; dosyada "5.07" geçmiyor.
- Commit: `test-bakim T2: e2e 5.07 silindi — kodda olmayan overlay-dışı-kapanma yolu (test borcu, sahip kararı 2026-09-30)`.

## Kapılar (sıralı)
- G1 (implementer dönüşünde): `git diff --stat main..test-bakim` yalnız 2 dosya; unit pinned worktree'de
  `NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit` → 1284/1281/3 (bilinen 3; worktree'de
  v23c/v23e dosyası olmadığından beklenen 1270/1267/3'tür — daldaki dosya setine göre raporla, sapmayı yaz).
- G2 (review): luna (ss-lead-codex resume) — diff 2 dosya; bulgu yok → KABUL.
- G3 (demo koşum, glmf-max): Docker PW kalıbı, ana checkout yerine **test-bakim dalı** servis edilir;
  sonuç JSON yedeği; ölçütler: collect error 0, 5.07 listede yok, workers=8, B17 offline-kuyruk:90 429 YOK.
  (Tam 60-pass eşiti aranmaz — veri-duyarlı B sınıfı bağımsız.)
- G4 (sahip): merge hazır komut — ana checkout `git merge --no-ff test-bakim` + push;Pages damgası gerekirse
  `?v=20260930-01` (index.html 26 konum — yalnız G4 öncesi istenirse; kod değişmediğinden damga ZORUNLU DEĞİL).

## Yasaklar / notlar
- Kod (js/*.js) ve DB'ye DOKUNULMAZ — yalnız config + test dosyası.
- Push/merge sahibin; implementer yalnız kendi commit'ini atar (Co-Authored-By satırı).
- `docs/plans/` gitignore → teslikte `git add -f`.
- Playwright tam koşumu tek Docker koşumu ("fanout yerine tek koşum"; Playwright bir kez yeter — G3 tekrarı yalnız FAIL düzeltmesinde).
