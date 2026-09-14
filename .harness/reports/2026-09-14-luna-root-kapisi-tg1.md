VERDICT: DÜZELTME

## Kapı tablosu

| # | PASS/FAIL | kanıt |
|---|---|---|
| 1 | PASS | Hedef worktree `5c9d6ba7c6637fc564b3296fb28c5e5eb4665256` üzerinde temiz. `package.json:test:unit` `node --test tests/unit/*.test.js`; doğrudan koşum `DIRECT_EXIT=0`, `tests 892`, `pass 892`, `fail 0`; `_gmGroupHtml: DÜN ...` testi geçti (`tests/unit/gecmis-pipeline.test.js` kapsamı, koşum log satırı 313). |
| 2 | FAIL | Playwright tekrar koşulmadı. Hedef spec'te `tests/tarihe-git.spec.js:28` hâlâ `test.skip(!IS_DEMO, ...)` var. Teslim raporu da tek ve tutarlı bir koşum sunmuyor: §5 `18 passed / 2 skipped / 0 failed`, W3/lead kapanışı `20 passed / 1 skipped / 0 failed`; rapor ayrıca iki geliştirme koşumunu belgeliyor (`.harness/reports/2026-09-14-tarihe-git-f1.md:88-96,177-181,219`). |
| 3 | FAIL | İstenen komut çıktısı: `1 ?v=` ve `23 ?v=20260914-02`; boş eşleşme `index.html:2229` damga yorumundan geliyor, dolayısıyla tek değer kapısı geçmiyor. Damga-pin unit testleri full suite içinde geçti; teslim raporunun eski §5 çıktısı ayrıca `20260914-01` diyor. |
| 4 | PASS | `grep -rn 'type="date"' index.html js/` çıktı vermedi, `TYPE_DATE_GREP_EXIT=1` (0 eşleşme). |
| 5 | PASS | `git diff --stat main...agent/tarihe-git-faz1 -- supabase/ 'js/degisiklikler*'` boş çıktı. Hedef diff'inde `supabase/` ve `js/degisiklikler*` yok. |
| 6 | PASS | `git merge-tree --write-tree main agent/tarihe-git-faz1` → `d51af24d6d7bf05ee7cd28b81b9cecd77f2d279b`, `MERGE_TREE_EXIT=0`; çakışma çıktısı yok. |
| 7 | PASS | Önceki 4 kritik + 6 orta bulgunun tamamı aşağıdaki tabloda `KAPALI`; her biri için hedef kod ve test/fixture kanıtı doğrulandı. |
| 8 | PASS | `main...agent/tarihe-git-faz1` diff'i 13 dosya: 12'si goal manifestinde, biri doğrudan bu zincirin önceki luna review raporu. İlgisiz ürün/DB dosyası veya `.gitignore` hijyeni yok; `git diff --check` de `EXIT=0`. |

## 4K+6O takibi

F1 | KAPALI | `js/gecmis.js:284-292` ref doluyken yalnız `id|gün`, ref boşken hayvan+gün fallback uygular; `tests/unit/gecmis-gun.test.js:242-262` W3 adversarial testi aynı gün/farklı gün/eşleşmeyen ref vakalarını ve boş-ref fallback'ını doğrular.

F2 | KAPALI | `js/gecmis.js:294-300` stok baskılamasını `referans_tipi='tohumlama'` ve aynı gün/id ile sınırlar; `tests/unit/gecmis-gun.test.js:264-280` non-primary, tipsiz ve aile dışı stokların görünür kaldığını doğrular.

F3 | KAPALI | `js/ui.js:3833-3898` hekim, sonuç, tedavi etiketi, görev, uygulama ve bilinmeyen işlem metinlerini `esc`/`escAttr` ile taşır; `tests/unit/gecmis-xss.test.js:47-88` altı adversarial metin testidir.

F4 | KAPALI | `js/ui.js:3901-3931` beş yeni kartta inline `onclick` yerine `data-action="gm-det"` + `data-det` kullanır, `js/utils/handlers.js:114-116` merkezi delegasyonu taşır; `tests/unit/gecmis-xss.test.js:90-105` kimlik enjeksiyonunu doğrular.

F5 | KAPALI | `js/utils/handlers.js:110-112` DÜN action'ı `dAgo(1)` kullanır; `tests/tarihe-git.spec.js:109-119` oracle'ı aynı doğru ifadeyi kullanır.

F6 | KAPALI | `tests/tarihe-git.spec.js:40-56,83-106` statik `2026-09-06 / 266` fixture'ını, kaynak temsil metinlerini ve DOM toplamını denetler; artık aynı ürün pipeline'ından dinamik en zengin gün sayısı üretmez.

F7 | KAPALI | Veri-bağımlı TG1 skip'i kaldırılmış, beş TG1 testi `tests/tarihe-git.spec.js:60-190` içinde sabit fixture/akışla tanımlı. Ancak `:28` demo guard'ı kaldığı için Kapı 2 ayrı olarak FAIL'dir.

F8 | KAPALI | Goal manifesti `.harness/goals/2026/G-20260914-TARIHE-GIT.md:11-25` içinde `js/utils/handlers.js`, `js/api.js`, gerçek unit dosyaları ve `vaka-toplu-ac.test.js` eklenmiş; W2 revizyonundaki manifest açığı kapanmış.

F9 | KAPALI | `js/ui.js:2671-2724` hayvan kartı için kanonik tarih seçici, gün filtresi, banner ve kapsamlı pipeline'ı uygular; `tests/unit/gecmis-gun.test.js:282-306` ve `tests/tarihe-git.spec.js:152-190` hayvan kapsamını doğrular.

F10 | KAPALI | `js/api.js:404-424,450` eski 100 satır cap'ini 1000'lük sayfalı tam çekimle değiştirir; `tests/tarihe-git.spec.js:40-56,83-106` 107 işlem içeren statik fixture ile bu yolu dolaylı olarak kapılar.

## DÜZELTME listesi

1. `index.html:2229`: root kapısının verdiği exact grep komutunu tek damgaya indirmeyen çıplak `?v=` metni var; kapı çıktısı `1 ?v=` + `23 ?v=20260914-02`.
2. `tests/tarihe-git.spec.js:28`: root kapısı açıkça `test.skip`/`fixme` taradığı halde demo guard'ı kalmış.
3. `.harness/reports/2026-09-14-tarihe-git-f1.md:88-96,177-181,219`: tek koşum kabulü için rapordaki `18/2` ile `20/1` Playwright sonuçları ve eski `20260914-01` damga anlatımı tek, tutarlı final kanıtına indirilmeli.
4. `.harness/goals/2026/G-20260914-TARIHE-GIT.md:3,43`: frontmatter `status: done`, gövde `Status: PENDING`; goal yaşam döngüsü belgesi uzlaştırılmalı.

## Koşulan komutlar

- `git -C /home/melik/.superset/worktrees/1dddb562-abe3-495c-970e-872567945510/agent/tarihe-git-faz1 status --short --branch && git -C ... rev-parse HEAD`: `## agent/tarihe-git-faz1`, `5c9d6ba7c6637fc564b3296fb28c5e5eb4665256`.
- `node -e "const p=require('.../package.json'); console.log(JSON.stringify(p.scripts,null,2))`: `test:unit = node --test tests/unit/*.test.js`.
- `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` (çıktı disk loguna yönlendirilip doğrudan exit okundu): `DIRECT_EXIT=0`, `tests 892`, `pass 892`, `fail 0`, `skipped 0`; `_gmGroupHtml` testi PASS.
- `grep -o '?v=[0-9-]*' index.html | sort | uniq -c`: `1 ?v=` ve `23 ?v=20260914-02`; `STAMP_PIPE_EXIT=0`.
- `grep -rn 'type="date"' index.html js/`: çıktı yok; `TYPE_DATE_GREP_EXIT=1`.
- `git diff --stat main...agent/tarihe-git-faz1 -- supabase/ 'js/degisiklikler*'`: çıktı yok.
- `git merge-tree --write-tree main agent/tarihe-git-faz1`: `d51af24d6d7bf05ee7cd28b81b9cecd77f2d279b`, `MERGE_TREE_EXIT=0`.
- `grep -nE 'test\.(skip|fixme)|test\.skip|test\.fixme|fixme' tests/tarihe-git.spec.js`: `28:test.skip(!IS_DEMO, ...)`, exit `0`.
- `git diff --name-status main...agent/tarihe-git-faz1`: 13 path; target `supabase/` ve `js/degisiklikler*` değişikliği yok.
- `git diff --check main...agent/tarihe-git-faz1`: `DIFF_CHECK_EXIT=0`.
- Playwright: sahip kuralı nedeniyle **TEKRAR KOŞULMADI**; yalnız teslim raporundaki belgelenmiş koşum/sonuç ve spec statik olarak kontrol edildi.
