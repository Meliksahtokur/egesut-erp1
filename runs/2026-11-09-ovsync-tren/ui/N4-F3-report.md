⟦ss-sub model=opus effort=high rol=ss-worker-high iş=Demo e2e'nin bulduğu iki UI hatasını (H1 Görevler Ovsync TAI'de Ertele, H2 çift toptan ertele düğmesi) düzelt⟧
sonuc: TAMAM
commit: 9411ca4 `ovsync-tren N4-F3: Görevler TAI kartı Ovsync ekranından bağımsız + tek toptan ertele düğmesi` (4 dosya tek tek `git add`, push yok). Bu report ayrı commit'te.
MUSE-YEDEK: N4 UI işinde Muse 3 turunu kullandı (tur1 KISMI, F1 DÜZELT, F2 KISMI). Demo e2e'nin bulduğu iki hata kural gereği Opus'a geldi.
BOYUT: bütçe +40 net · gerçek +39 net (45 ekleme, 6 silme; js/ui.js +24/−6, js/ovsync-tren.js +21) · bütçe içinde

Gelen iş denetimi: plan hatası yok, iş verilen dosyalarla yapılabilir, kabul ölçülebilir. İki not var:
- (a) H1 brief'i kararı "`ovsyncTrenGorevMu(t)` ile görev verisinin kendisinden" ister. Ancak TAI için R5 (b) "hayvanın aktif OVSYNC vakası" şartını taşır; bu bilgi görev satırında yok, vaka verisi gerekir.
  - Uygulanan: küme, Görevler yüklemesinin zaten okuduğu IDB vakalarından kuruldu. Karar `ovsyncTrenGorevMu(t,k)` ile aynen verilir; bayrak `ovsyncTrenAktif` ile aynen okunur.
- (b) H2 brief'i "X'in İLK geçtiği başlık (trenin kendi başlığı)" der. Gruplar tren_gunu'na göre artan sırada olduğu için ilk geçen başlık geçen haftanın trenidir; iki ifade çelişiyor. "Trenin kendi başlığı" esas alındı (assumption kırıntısı yazıldı).

## Kök neden (systematic-debugging, Faz 1)
- **H1 (CONFIRMED, birim yeniden üretim):**
  - Kart kararını veren `_ovsyncKartKararBaglami`, hayvan kümesini yalnız `_ovsyncBaglamAl().vakaAktif`'ten kuruyordu.
  - Bu bağlamı yalnız `loadOvsyncDash` → `_ovsyncBaglamYukle` dolduruyor. Ovsync ekranı hiç açılmamışsa `_ovsyncBaglamAl` boş harita döner.
  - Boş haritayla TAI için `ovsyncTrenGorevMu` false döner ve kart eski Ertele yoluna düşer.
  - Düzeltme öncesi probe (`~/tmp/n4f3/h1-probe.js`): bayrak açık, bağlam boş, TOHUMLAMA_PLANLI h1 → `<button data-g="g5" data-ertele="1" …>🗓️ Ertele</button>`.
- **H2 (CONFIRMED, kırmızı test):**
  - Bugün Pzt 9 Kas iken 4 Kas treni için `ovsyncToptanTarih` D7 = 11 Kas döner. Bu, `ovsyncIlkToptanTarih` = 11 Kas ile aynıdır.
  - `ovsyncTrenBaslikHtml`'in `ilkTarih` süzgeci iki başlığı da geçiriyor; bu yüzden iki düğme çiziliyor (DM1 BULGU-2 ile birebir).

## Değişiklik
- `js/ui.js`
  - Yeni `_ovsyncKartHayvanKur(vakalar)`: R5 (b) aynası. Aktif ve `protocol_family='OVSYNC'` olan vakaların hayvanlarını `globalThis._ovsyncKartHayvanlar` kümesine yazar.
  - `loadTasks` bu kümeyi `_allTaskCases` ile, `loadDash` ise `_dtCases` ile kurar. Her ikisi de render'dan önce ve `typeof` kapılıdır.
  - `_ovsyncKartKararBaglami` için küme = bu küme ∪ Ovsync ekranı bağlamının `vakaAktif`'i. Bağlam yalnız ek kaynaktır, bağlam yoksa `return null` artık yok.
  - Bayrak kapısı değişmedi: bayrak kapalıysa ya da okunamıyorsa null döner ve eski Ertele birebir çizilir.
  - `_ovsyncTrenGovdeHtml`: `ilkFor(tren)`, seçilen başlık dışındaki başlıklara `null` geçirir. `ovsyncTrenBaslikHtml` imzası değişmedi.
- `js/ovsync-tren.js`
  - Yeni `ovsyncToptanBaslikTreni(trenVeri, bugunIso)`. Düğmeyi X'in kendi treninin başlığı alır (tren_gunu = X).
  - O tren listede yoksa düğme X'i işaret eden ilk trenin başlığına konur (düğme kaybolmaz). X yoksa fonksiyon null döner.
- Testler:
  - `ovsync-tren-entegrasyon.test.js`: 4 test, H1 için 3 (adlı test, bayrak kapalı birebir, loadTasks/loadDash bağlantısı) ve H2 için adlı test. Ayrıca UB2 çıkarım listesine yeni fonksiyon eklendi.
  - `ovsync-tren.test.js`: `ovsyncToptanBaslikTreni` için 5 durum.

Karar (kırıntı): kart kümesi loadDash'te de kuruluyor, çünkü dash'teki TAI kartı aynı kusur sınıfında ve bunun maliyeti tek satır. Hayvan detayı kümeyi kendisi kurmuyor; açılışta renderFromLocal → loadDash kümeyi kurduğu için pratikte dolu olur (INFERRED, ölçülmedi; open_item kırıntısı yazıldı).

## TDD — kırmızı (düzeltme öncesi, ham)
Kırmızı koşu `~/tmp/n4f3/kirmizi.txt`: 138 test, 133 pass, 5 fail (eklenen 5 testin hepsi).
```
✖ Görevler ekranı Ovsync bağlamı yokken Ovsync TAI → düzenle linki, Ertele yok (11.849256ms)
  Error: js/ui.js: "function _ovsyncKartHayvanKur" bulunamadı
✖ iki başlık aynı X'i işaret ederken tek ertele düğmesi (59.562099ms)
  AssertionError [ERR_ASSERTION]: ekranda tek "Tren gününü ertele…" olmalı: ["<span class=\"ovs-tren-ad\">Tren · Çar 4 Kas · …<button class=\"ovs-tren-ertele\" data-ovt-aksiyon=\"TOPTAN\" data-tarih=\"2026-11-11\">Tren gününü ertele…</button>","…Tren · Çar 11 Kas · …<button class=\"ovs-tren-ertele\" … data-tarih=\"2026-11-11\">…"]
  2 !== 1
✖ N4-F3 H2 düğme başlığı: X'in kendi treni; yoksa X'i D7 sayan ilk tren; X yoksa null (0.314634ms)
  TypeError [Error]: S.ovsyncToptanBaslikTreni is not a function
```
H1'in davranışsal kırmızısı, yukarıdaki probe çıktısıdır (bağlam boşken Ertele çiziliyor).

Yeşil: iki dosya 138 test, 138 pass, 0 fail (`~/tmp/n4f3/yesil.txt`).

## Mutantlar
Her mutant için `ui.js` yedeklendi, mutant uygulandı, yalnız adlı test koşuldu, sonra yedekten geri yüklendi ve `cmp` ile karşılaştırıldı (`~/tmp/n4f3/mutant.sh`).
- **m1 (bağlam koşulunu geri getir):** kume satırı silindi, küme yine yalnız bağlamdan kuruluyor (MEASURED).
  ```
  ✖ Görevler ekranı Ovsync bağlamı yokken Ovsync TAI → düzenle linki, Ertele yok
    AssertionError [ERR_ASSERTION]: Ovsync TAI düzenle linki almalı: <button data-g="g5" data-ertele="1" …>🗓️ Ertele</button>
  IDENTICAL (geri yüklendi)
  ```
- **m2 (tekilleştirmeyi kaldır):** `ilkFor(g[2])` yerine yeniden `ilk` verildi (MEASURED).
  ```
  ✖ iki başlık aynı X'i işaret ederken tek ertele düğmesi
    AssertionError [ERR_ASSERTION]: ekranda tek "Tren gününü ertele…" olmalı: [… 4 Kas … 11 Kas …]
  IDENTICAL (geri yüklendi)
  ```

## Kabul
- **Tam birim süit (MEASURED, `~/tmp/n4f3/son.txt`):** 2391 test, 2387 pass, 4 fail.
  - Taban 2386 / 2382 / 4 (`taban.txt`).
  - Fail'ler taban dördüdür: degisiklikler-etiketler.test.js:88 (LUNA-3), erteleme-genel-ui.test.js:262 (EG-7), :292 (EG-8), vaka-toplu-ac.test.js:2624 (ay ‹/›). pass 2387 > 2382.
- **etiket-tazelik:** HATALI 15, DOĞRULANAMADI 4 (MEASURED). rc 1, betikte `hatali > 0 ? 1 : 0` kuralından gelir (scripts/etiket-tazelik.mjs:459). Taban da HATALI 15 olduğu için rc 1 beklenir.
- **H1/H2 testleri** kırmızıdan yeşile döndü. İki mutant da adlı testi kırdı, geri yüklemelerin ikisi de IDENTICAL.
- **Demo tek test PASS (MEASURED):** ref `vtzqjmazsvurxdeondmi`, yalnız `-g "görevler ekranı: Ovsync TAI'de Ertele yok"`. Diğer 9 test koşulmadı.
  - Komut DM1 koşum betiği (`~/tmp/dm1/run-e2e.sh`, port 8139). Ham çıktı `~/tmp/n4f3/e2e-tek.txt`.
  - Koşum sonrası port 8139 serbest; yerel sunucuyu betik kapattı.
  ```
  Running 1 test using 1 worker
    ✓  1 [chromium] › tests/e2e/ovsync-tren.spec.js:409:5 › görevler ekranı: Ovsync TAI'de Ertele yok (20.9s)
    1 passed (54.6s)
  RC=0
  ```
  - Komut: `ram-ultracode exec --class test --wait 1800 -- bash ~/tmp/dm1/run-e2e.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren 8139 tests/e2e/ovsync-tren.spec.js ~/tmp/n4f3/e2e-tek.txt -g "görevler ekranı: Ovsync TAI'de Ertele yok"`
  - Demo verisine test dışında yazma yapılmadı. Seed ve geri dönüş spec'in kendi beforeAll/afterAll'ı ile yapıldı.
- Atlas etki (CLI, cwd worktree):
  - `_ovsyncKartKararBaglami` → `_erteleBtnHtml` → `renderTask`, `_ovsyncS3SatirHtml`.
  - `ovsyncTrenBaslikHtml` → `_ovsyncTrenGovdeHtml` → `renderOvsyncSayfa`.
  - MCP `etki` (main ağacı): `loadTasks` 94 ve `loadDash` 79 çağıran. Bu iki fonksiyondaki değişiklik eklemeli tek satır, yalnız global küme yazıyor.

## Run kanıtı
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -6
```
rc: 1
```
    code: 'ERR_ASSERTION',
    actual: false,
    expected: true,
    operator: '==',
    diff: 'simple'
  }
```
- Bu komut kancaya takıldığı için `ram-ultracode exec --class test -- bash ~/tmp/n4f3/run1.sh` ile birebir koşuldu (pipefail; rc = node rc).
- rc 1, taban dört fail'den gelir. tail -6 son fail'in ayrıntısına denk geliyor.
- Aynı ağacın özet satırları (`~/tmp/n4f3/son.txt`): `ℹ tests 2391 · ℹ pass 2387 · ℹ fail 4`.

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node scripts/etiket-tazelik.mjs 2>&1 | tail -3
```
rc: 1
```
  [HATALI] js/ui.js:openDet@8834 → @tablo cases (okuma), cases (tazeleme), diseases (tazeleme), dogum (okuma), drug_classes (tazeleme), drug_products (tazeleme), drugs (tazeleme), gorev_log (okuma), gorev_log (tazeleme), hayvanlar (okuma), kizginlik_log (okuma), kizginlik_log (tazeleme), tohumlama (okuma), uygulama_log (okuma), uygulama_log (tazeleme), vaccination_log (okuma), vaccination_log (tazeleme), vaccines (tazeleme)
      EKSİK: gövdede .from('hayvan_takip') var, etikette yok
payda 316 satır: DOĞRU 297 | HATALI 15 | DOGRULANAMADI 4
```

## Kırıntılar
Workspace `fable-rol-ve-davranislar`.
- assumption: H2'de "trenin kendi başlığı" esas alındı. Kendi treni listede yoksa düğme ilk eşleşen başlığa konur.
- decision: kart kümesi loadTasks'a ek olarak loadDash'te de kuruluyor. Hayvan detayı son kurulan kümeyi kullanıyor.
- measurement: süit 2391/2387/4; demo tek test PASS; mutant m1 ve m2 kırmızı, geri yüklemeler IDENTICAL.
- open_item: hayvan detayı ekranındaki Ovsync TAI kartı demo'da ölçülmedi (INFERRED dolu).

Not (INFERRED): worktree'de `runs/2026-11-09-ovsync-tren/ui/N4-F2-brief.md` başka bir yazıcı tarafından değiştirilmiş. Bu dosyaya dokunulmadı ve stage edilmedi.
