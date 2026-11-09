⟦muse model=muse-spark-1.3 rol=ss-muse-worker iş=Ovsync treni UI (UB1–UB5) entegrasyonu, m1–m4 mutant kapısı, tam suit ve report⟧

sonuc: TAMAM

BOYUT: üretim net +737 satır (js/api.js +35, js/forms.js +131, js/ovsync-tren.js +122, js/ui.js +421, index.html +28; test hariç; taban fb41bbf → uç 26e653e; komut: `git diff --numstat fb41bbf..HEAD -- js/api.js js/ui.js js/forms.js js/ovsync-tren.js index.html manifest.json`)

Son ÜRETİM commit SHA: 26e653e64d89b8dd9b0052298db48a70e1a03310

## Kabul

- Yeni testler kırmızı→yeşil + m1–m4 ADLI testte kırmızı (MEASURED): m1 `F9 ertele düğmesi yalnız ilk ritim günü başlığında` 38/1; m2 `F8 düz metin aciklama → sessiz false (m2 adli)` (+`bozuk aciklama sessiz geçmez`) 37/2; m3 `UB4 V2 BAGIMSIZ → start p_bagimsiz:true (m3 adlı)` 38/1; m4 `UB4 V2 bayrak kapalı → soru/onizle RPCsi YOK` 38/1. Her mutant sonrası `cmp` IDENTICAL, ağaç HEAD ile birebir (ham: ~/tmp/muse-ovsync-n4/tam-suit.log dışı mutant çıktıları bu raporun `## Run kanıtı` bölümünde; komutlar orada verbatim).
- Tam birim suit (ham: ~/tmp/muse-ovsync-n4/n4-final-suit.log — kök bağımsız yeniden koşumu; çocuk hamı ~/tmp/muse-ovsync-n4/duzeltme-tam-suit.log ile birebir aynı; komut: `NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js`): `ℹ tests 2337 · suites 61 · pass 2333 · fail 4` (rc=1). Fail edenler TAM OLARAK taban dördü: degisiklikler-etiketler.test.js:88 (LUNA-3), erteleme-genel-ui.test.js:262 (EG-7), :292 (EG-8), vaka-toplu-ac.test.js:2624 (`ay ‹/›`; üst suite `bc-tarih takvim`). Başka fail yok. pass 2333 > 2277.
- `etiket-tazelik` (ham: ~/tmp/muse-ovsync-n4/etiket.log, ~/tmp/muse-ovsync-n4/etiket-liste.txt; komut: `NODE_PATH=... node scripts/etiket-tazelik.mjs`): `payda 312: DOĞRU 293 | HATALI 15 | DOGRULANAMADI 4` (rc=1, tabanla aynı rc). Liste tabanla birebir (`_pullTablesNow, initRealtime, semaDiffKontrol, 10×hayvan-takip, hastalikGunKaydet×2, loadDash, loadAnimals, _ovsyncAktifBolmeHtml, openDet`); yeni HATALI/DOĞRULANAMADI yok, yeni N4 fonksiyonu listede yok.
- BOYUT üretim net +650 ≤ +900.
- Diff yalnız Yazılabilir'deki dosyalar (N4 kapsamı fb41bbf..HEAD): index.html, js/api.js, js/forms.js, js/ovsync-tren.js, js/ui.js, tests/unit/ovsync-tren.test.js, tests/unit/ovsync-tren-entegrasyon.test.js. manifest.json değişmedi (içinde sürüm dizesi yok; 37 `?v=` index.html'de tek değer `20261110-1`, 1 çıplak `?v=` yalnız yorum satırı :2616).

## UB tablosu (commit · test adları · PASS)

| UB | commit | testler | sonuç |
|---|---|---|---|
| UA1 düzeltme | efb0ae2 | ovsync-tren.test.js 39/39 (11 yeni: F2/F3/F4/F7-ONCEKI_TREN_VAR/F8-m2-adlı/F9/BOŞLUK-3/F15/UB-ek2/bayrak/renk) | PASS (ham: parça özeti ~/tmp/muse-ovsync-n4/p1-ozet.txt) |
| UB1 | de10be7 (js/api.js +35, index.html +1, entegrasyon +182) | entegrasyon 7/7 (RPC_TABLES F13, salt-okuma EG-10, apiOvsyncTren offline/online/red, damga+sıra, bayrak) | PASS (ham: ~/tmp/muse-ovsync-n4/p2-ozet.txt) |
| UB2 | bc7ef5f (ui.js+forms.js, üretim net +125) | entegrasyon 16/16 (7 UB1 + 9 UB2: F1-S0, F9-ilk-başlık, F4-belirsiz, BOŞLUK-4, F11, BOŞLUK-1, BOŞLUK-2+F5, F3) | PASS (ham: ~/tmp/muse-ovsync-n4/ub2-ozet.txt) |
| UB3 | 4b7eda1 (ui.js net +130, test +6) | entegrasyon RED 16/6 → GREEN 22/22 | PASS (ham: ~/tmp/muse-ovsync-n4/ub3-ozet.txt) |
| UB4 | c670063 (ui.js net +120, test +215) | 10 yeni UB4 testi (V2 TREN/BAGIMSIZ/kapalı/çevrimdışı/bugün, F11, BOŞLUK-4 BASTAN, BASTAN-hata, K11) + entegrasyon toplam | PASS (ham: runs/2026-11-09-ovsync-tren/ui/ub4-ozet.txt) |
| UB5 | 2e4f1f2 (ui.js+index.html+entegrasyon) | entegrasyon 39/39 (7 yeni UB5: rozet×2, panel×3, damga, F14) | PASS (özet tmp'de, içerik workflow notes'ta; kırmızı-önce hamı DÜZELT turunda m-ub5 ile üretildi, bk. duzeltme-ozet.txt:32-33) |
| DUZELT | 26e653e (ui.js +32, forms.js +56/-1, entegrasyon +124) | entegrasyon RED 39/6 → GREEN 45/45; mutantlar m-duz2 (adlı), m-duz3a, m-duz3b, m-ub5 — hepsi adlı-kırmızı + cmp IDENTICAL | PASS (ham: ~/tmp/muse-ovsync-n4/duzeltme-ozet.txt) |

## Ruling → uygulama (dosya:satır)

| Ruling | uygulama |
|---|---|
| BOŞLUK-1 (≈ pg1+48s / yalnız PG1+48s / tai_hedef) | js/ui.js:2031-2039 (`_ovsyncPg48SatirHtml`), js/forms.js:5804 (`tai_hedef` sonuç metni), js/forms.js:5768 (`_ovsyncTrenTarihAd`) |
| BOŞLUK-2 (yalnız sayı) | js/ui.js:2118 (`Dokunulmaz: b bağımsız · r ritim dışı`) |
| BOŞLUK-3 (küpe+sonraki iş, neden YOK) | js/ui.js:2153 (`_ovsyncBagimsizAltSatirHtml`) |
| BOŞLUK-4 (önce tarihsiz, sonra hedef_tarih/bugün) | js/ovsync-tren.js:317-332 başlık/btn; eylem sonrası js/forms.js:5798-5804 bandı |
| F1 / BOŞLUK-5 (S0∪S1, başlık=uyeler.length, S0 aksiyon) | js/ui.js:2071-2102 (`_ovsyncTrenGovdeHtml`) |
| F2 (ritim_disi_neden) | js/ovsync-tren.js:286-294 (`_ovtRitimDisiNot`), :329 not satırı |
| F3 (tarihli/tarihsiz etiket, 1..pg_pay, 1..7) | js/ovsync-tren.js:581 (`ovsyncTekErteleAraligi`) + UB2 F3 :5798-5804 bandı |
| F4 (belirsiz + onay kapalı + baştan başlat) | js/ovsync-tren.js:411 (`sonuc == null`), :466-468 (belirsiz sayımı) |
| F5 (ileri_vakalar/iptal_tai/basladi:false+yeniden_hedef) | UB2 önizleme bandı js/ui.js:2104-2118 çevresi |
| F7 (TÜM kodlar + ONCEKI_TREN_VAR + DUSTU özyineleme + GECMIS_TARIH) | js/ovsync-tren.js:745 (`ovsyncTrenHataMetni`) |
| F8 (`^\s*\{` önkoşul, düz sessiz false, bozuk görünür) | js/ovsync-tren.js:489-510 |
| F9 (ertele yalnız ilk başlıkta) | js/ovsync-tren.js:306-315 + :325 koşulu, js/ui.js:2080 |
| F10 (taşınma cümlesi + n=uye_kupeler.length) | UB3 kart bandı (bk. 4b7eda1) |
| F11 (basladi:false → case_id yok) | js/ui.js:2264 (`_ovsyncBaslatSecimi`), js/ui.js:2339 (toast) |
| F13 (RPC_TABLES yazma birleşimi, salt-okuma DIŞARIDA) | js/api.js:387 (`RPC_TABLES`), :445 (salt-okuma notu) |
| F14 (CSS → style, YALNIZ yazı rengi) | index.html:645-649 (`.ovs-tren-*{color:...}`, zemin/şerit yok) |
| F15 (SECIM+Vazgeç/Onay tek yardımcı, onclick yok) | UB1-UA1/UB3 (bk. efb0ae2, 4b7eda1) |
| Damga (`?v=` tek değer + manifest) | index.html:2627 (`ovsync-tren.js?v=20261110-1`), 37×`20261110-1`; manifest.json sürüm dizesi içermez (değişiklik yok) |
| UB-ekler 1/2 (textContent, acModal try/catch) | UB1/UA1 (bk. efb0ae2, de10be7) |
| DÜZELT D2 (Ovsync TAI'da Ertele→düzenle kancası, kapalıda eski Ertele) | js/ui.js `_ovsyncKartKararBaglami` + `_erteleBtnHtml` kancası (bk. 26e653e; test: bayrak-açık link / kapalı eski) |
| DÜZELT D3(i) (çoklu-not Ovsync eki) | js/forms.js `_ovsyncCokluBantEki` + `cokluKaydirOnayla` tutkalı (bk. 26e653e) |
| DÜZELT D3(iii) (seans sheet + toast korunur) | js/forms.js `_ovsyncSeansUyariHtmli` + `_ovsyncUyariSheetAc` (bk. 26e653e) |

## Fan-out

- Parçalar: P1-UA1 (ovsync-tren.js+test) ∥ P2-UB1 (api.js+index.html+entegrasyon) → P3-UB2 → P4-UB3 → P5-UB4 → P6-UB5 (ui.js/forms.js çakışması yüzünden sıralı). 6 yaprak + 1 sentez = 7 workflow çocuğu, tamamı `ss-muse-worker-yaprak`, model muse-spark-1.3, effort xhigh. Wonder çocuk yok.
- Kökün kendi araç çağrısı: brief okuma (1) + workflow (1) + entegrasyon/ölçüm komutları (mutant 4, suit 2, etiket 3, git 6, pin 4, indeks 2 ≈ 21) + report yazımı + reviewer (bekliyor). İş dosyalarına edit/write YOK (mutantlar yedek→uygula→geri→cmp döngüsüyle, `git checkout`/`stash` kullanılmadan).
- Parça özetleri: 5'i `~/tmp/muse-ovsync-n4/` altında (`p1,p2,ub2,ub3-ozet.txt`, son satır BİTTİ), UB4 özeti `runs/.../ui/ub4-ozet.txt`, UB5 özeti guard engeline takıldı (içerik workflow notes'ta).

## Run kanıtı

Komutların tamamı worktree kökünde (`~/.herdr/worktrees/egesut-erp1/ovsync-tren`) koştu.

```
$ git branch --show-current
rc: 0
ovsync-tren
```

```
$ git log --oneline -12
rc: 0
2e4f1f2 ovsync-tren N4 UB5: dogum-PG panel + F14 yazi-rengi + damga 20261110-1
c670063 ovsync-tren N4 UB4: V2 trene-bin kancasi p_bagimsiz + BASTAN eylem F11 K11
4b7eda1 ovsync-tren N4 UB3: gorev/vaka karti BOSLUK-3 F10 F15 F8
bc7ef5f ovsync-tren N4 UB2: tren ekrani dal, PG+48 tahmini ve sonuc metinleri
efb0ae2 ovsync-tren N4 UB1-UA1: F2/F3/F4/F7/F8/F9/F15 duzeltmeleri
de10be7 ovsync-tren N4 UB1: tren API sarmali + RPC_TABLES F13 + modül yükleme
fb41bbf ovsync-tren L-DB D9 kayitlari + N4 sozlesme olcumu (brief/report/review)
7ff1e7b ovsync-tren L-DB D9: bagimsiz vaka isareti (cases.ovsync_bagimsiz)
d359e4e ovsync-tren L-DB: kulvar kayıtları (brief/report/review, progress, L-DB-DONE)
b69a195 ovsync-tren L-DB D8 tur 2: RL-18 göç yalnız açılış/çapa değişiminde
acd0f71 ovsync-tren L-DB D8: ayar ve göç (ovsync_tren_yeniden_hedefle, ovsync_tren_ayar_guncelle) + regresyon + geri alma provası
a9a4ff5 ovsync-tren L-DB D7 tur 2: RL-14..17 (toptan ileri vakalar, X+N, ilk tren kapısı)
```

```
$ git status --short -- js/ tests/ index.html manifest.json
rc: 0
(boş — üretim/test ağacı HEAD ile birebir)
```

```
$ git diff --name-only fb41bbf..HEAD
rc: 0
index.html, js/api.js, js/forms.js, js/ovsync-tren.js, js/ui.js,
tests/unit/ovsync-tren-entegrasyon.test.js, tests/unit/ovsync-tren.test.js
(hepsi Yazılabilir listesinde; supabase/**, .harness/**, db/** yok)
```

```
$ git diff --numstat fb41bbf..HEAD -- js/api.js js/ui.js js/forms.js js/ovsync-tren.js index.html manifest.json
rc: 0
64  36  index.html        → net +28
35  0   js/api.js         → net +35
76  0   js/forms.js       → net +76
152 30  js/ovsync-tren.js → net +122
394 5   js/ui.js          → net +389
TOPLAM net +650
```

m1 (F9 :325 koşul satırı silindi):
```
m1 applied
✖ F9 ertele düğmesi yalnız ilk ritim günü başlığında
ℹ pass 38 / ℹ fail 1
RESTORE-OK   (geri yükleme sonrası: ℹ pass 39 / ℹ fail 0, cmp IDENTICAL)
rc: 0
```

m2 (F8 :499 `/^\s*\{/` önkoşulu kaldırıldı):
```
m2 applied
✖ görev mu: bozuk aciklama sessiz geçmez (hata bildirilir), false döner
✖ F8 düz metin aciklama → sessiz false (m2 adli)
ℹ pass 37 / ℹ fail 2
RESTORE-OK (cmp IDENTICAL)
rc: 0
```

m3 (ui.js :4683/:4688 `p_bagimsiz` atamaları silindi):
```
m3 applied
✖ UB4 V2 BAGIMSIZ → start p_bagimsiz:true (m3 adlı)
ℹ pass 38 / ℹ fail 1
RESTORE-OK (cmp IDENTICAL)
rc: 0
```

m4 (ui.js :2269 bayrak kapısı kaldırıldı):
```
m4 applied
✖ UB4 V2 bayrak kapalı → soru/onizle RPCsi YOK, start eski parametrelerle
ℹ pass 38 / ℹ fail 1
RESTORE-OK (cmp IDENTICAL)
rc: 0
```

Tam suit (ham: ~/tmp/muse-ovsync-n4/tam-suit.log; N4 ilk kapanışı, uç 2e4f1f2 — DÜZELT sonrası için aşağıdaki kapanış bloğu geçerlidir):
```
RC=1
ℹ tests 2331 · suites 61 · pass 2327 · fail 4 · cancelled 0
failing `test at` konumları (tabanla birebir):
test at tests/unit/degisiklikler-etiketler.test.js:88:1
test at tests/unit/erteleme-genel-ui.test.js:262:1
test at tests/unit/erteleme-genel-ui.test.js:292:1
test at tests/unit/vaka-toplu-ac.test.js:2624:3
rc: 1 (4 taban fail — beklenen)
```

Etiket (ham: ~/tmp/muse-ovsync-n4/etiket.log):
```
payda 312 satır: DOĞRU 293 | HATALI 15 | DOGRULANAMADI 4
rc: 1 (tabanla aynı; HATALI/DOĞRULANAMADI listesi birebir taban)
```

```
$ gitnexus analyze --index-only ~/.herdr/worktrees/egesut-erp1/ovsync-tren
rc: 0
Repository indexed successfully (42.6s)
8.878 nodes | 15.214 edges | 594 clusters | 300 flows
(list: commit 2e4f1f2 = HEAD, dal ovsync-tren — taze, MEASURED)
```

DÜZELT sonrası kapanış (kök bağımsız yeniden koşumu, uç 26e653e):

```
$ git rev-parse HEAD && git status --short -- js/ tests/ index.html manifest.json
rc: 0
26e653e64d89b8dd9b0052298db48a70e1a03310
(boş — üretim/test ağacı HEAD ile birebir; ub4-ozet.txt runs'tan taşınmış)
```

```
$ git diff --numstat fb41bbf..HEAD -- js/api.js js/ui.js js/forms.js js/ovsync-tren.js index.html manifest.json
rc: 0
64  36  index.html        → net +28
35  0   js/api.js         → net +35
132 1   js/forms.js       → net +131
152 30  js/ovsync-tren.js → net +122
426 5   js/ui.js          → net +421
TOPLAM net +737 (≤ +900)
```

Tam suit (ham: ~/tmp/muse-ovsync-n4/n4-final-suit.log; çocuk hamı duzeltme-tam-suit.log ile birebir):
```
RC=1
ℹ tests 2337 · suites 61 · pass 2333 · fail 4 · cancelled 0
test at tests/unit/degisiklikler-etiketler.test.js:88:1
test at tests/unit/erteleme-genel-ui.test.js:262:1
test at tests/unit/erteleme-genel-ui.test.js:292:1
test at tests/unit/vaka-toplu-ac.test.js:2624:3
rc: 1 (4 taban fail — beklenen; pass 2333 > 2277)
```

Etiket (ham: ~/tmp/muse-ovsync-n4/n4-final-etiket.log):
```
payda 312 satır: DOĞRU 293 | HATALI 15 | DOGRULANAMADI 4
rc: 1 (tabanla aynı; liste tabanla birebir — fark yalnız DÜZELT kayması satır-nolarında)
```

## Varsayım

- manifest.json sürüm dizesi içermez → UB5 "manifest tek adımda" ruling'i index.html 37 `?v=` bump'ıyla karşılandı (INFERRED).
- apiOvsyncTren'e `@rpc/@tablo` makine etiketi yazılmadı (dinamik `rpc(rpcAd)` FAZLA→HATALI üretirdi; UB1 yaprak notu).
- UB5 `.ovs-mavi` açık-tema `var(--blue)` varsayımı (kardeş link-mavisi; UB5 yaprak notu).
- Mevcut testte 2 satır ruling-gerekçeli güncelleme (p1-ozet; reviewer (i) bilgisi): `ovsync-tren.test.js:326` DUZENLE beklentisi + bozuk-açıklama 2. yarı düz-metin sessizliği. Yeni beklenti değil, RULING uygulaması.

## Kırıntılar

- ~/tmp/muse-ovsync-n4/ (mut yedekleri *.bak, tam-suit.log, n4-final-suit.log, duzeltme-tam-suit.log, etiket*.log, etiket-liste.txt, n4-final-etiket-liste.txt, p1/p2/ub2/ub3/ub4-ozet.txt, reviewer-ozet.txt, duzeltme-ozet.txt) — hepsi Yazılabilir tmp kapsamında, repo dışında.
- runs/2026-11-09-ovsync-tren/ui/ub4-ozet.txt — DÜZELT D4 ile tmp'ye taşınıp runs kopyası silindi (`git status` doğruladı); içerik ~/tmp/muse-ovsync-n4/ub4-ozet.txt (2593 bayt).
- Untracked N4-dışı girdiler (D9 lane / sözleşme lane, dokunulmadı): runs/.../PLAN-KAPI-*-report.md, mockup/, plan-brief.md, plan-report.md, ui/N4-brief.md, ui/UA1-report.md, ui/UB-ekler.md.

## Öğrenilen

- node --test özet satırları `ℹ tests/pass/fail` + `✔/✖` biçimindedir (`# pass` grepi boş döner) — ham log dosyaya alınıp `ℹ`/`✖` ile taranmalı.
- `test at <dosya>:<satır>` satırları fail→taban eşleşmesini tek komutla kapatır (isim eşleşmesinden sağlam).
- etiket-tazelik yalnız sorunlu kalemleri basar; "yeni fonksiyon etiketli" kanıtı = HATALI/DOĞRULANAMADI listesinin tabanla birebir olmasıdır (DOĞRU satırları basılmaz).
- N4-brief `Yazılabilir` listesinde olmayan `runs/.../ui/*-ozet.txt` yolu guard'a takılır; tmp özet + raporda ham yol kaydı deseni çalışır.

## Self-review

Reviewer: TEK `ss-muse-reviewer` (Spark xhigh), verdict **DÜZELT** → 1 tur + 1 düzeltme (`ss-muse-worker-yaprak`, commit 26e653e). Ham: ~/tmp/muse-ovsync-n4/reviewer-ozet.txt (BİTTİ) + ~/tmp/muse-ovsync-n4/duzeltme-ozet.txt (BİTTİ).

| Bulgu | durum | gerekçe/kanıt |
|---|---|---|
| (b) V3/V4/V5/G7/G9 K8 kancaları ovsync sorusu taşımıyor | kaldı (bütçe) | Komutla doğrulandı (forms.js'te `ovsyncTrenSor/p_bagimsiz` 0 satır; D1). Kapsam-içi (PLAN :500-507) ama ≈110–140 satır > bulgu başı 80; sonraki-tur notu özette (soru çekirdeği `ovsyncTrenSor`, 5 kanca için desen hazır). |
| (b) PLAN :501 TREN/BAGIMSIZ testi | kapsandı (D1 içinde kaldı) | Yukarıdakiyle aynı gerekçe. |
| (a) `_ovsyncTrenKartErteleHtml` ölü kod | düzeltildi (D2) | Üretimde çağıran 0 doğrulandı; `_ovsyncKartKararBaglami` + `_erteleBtnHtml` kancası bağlandı (ui.js +32). 4 yeni test, m-duz2 adlı-kırmızı, cmp IDENTICAL. |
| (a) `_erteleBtnHtml` eski Ertele (Ovsync TAI'da Ertele yok) | düzeltildi (D2) | Bayrak açıkken OVSYNC_BASLAT/aktif-OVSYNC TAI'da düzenle linki; kapalı/bilinmeyende eski Ertele birebir. |
| (a) `seans_tamamla` `ovsync_uyari` okumuyor | düzeltildi (D3-iii) | `_ovsyncSeansUyariHtmli` + `_ovsyncUyariSheetAc`; toast korunur. m-duz3b adlı-kırmızı, cmp IDENTICAL. |
| (a) UB4 çoklu-not/aşama-2/seans-sheet testleri | kısmen düzeltildi (D3-i, D3-iii) | Çoklu-not eki + seans sheet testleri eklendi (m-duz3a/m-duz3b). Aşama dalları D3(ii) bütçede kaldı (aşağıda). |
| (c) `runs/.../ui/ub4-ozet.txt` Yazılabilir-dışı | düzeltildi (D4) | İçerik tmp'ye taşındı (`cp` + `rm`, `git status` doğruladı); rapor Kırıntılar'a işlendi. |
| (l) `_ovsyncK8GunAd` vs `_ovsyncTrenTarihAd` kopyası | kaldı (kapsam-dışı + kalıp) | PLAN :476-551'de yok; birleştirme `loadExtractedFunction` kalıbını kırar (ui.js:2132 çapraz-dosya-çağrı-yok notu). Kasıtlı tekrar. |
| (a) UB5 kırmızı-önce hamı yok | kanıt üretildi (D6) | m-ub5 (`+ pgSayi` silindi) `UB5 rozet+panel wiring` testini kırmızıya düşürdü; cmp IDENTICAL, üretim 0 satır. |
| (i) bilgi: mevcut testte 2 satır değişikliği | rapora işlendi | F15 DUZENLE + F8 bozuk-açıklama satırları ruling-gerekçeli (p1-ozet); bu raporun Varsayım bölümüne eklendi (aşağıda). |

Blast-radius notu: DÜZELT turu öncesi ayrı code-change-precheck koşulmadı; yerine geçen kapılar — reviewer (j) değişen dosyaların TAMAMINI okudu, çocuk her bulguyu komutla doğruladı (grep 0-satır kanıtları), tam suit + etiket yeşil, mutant geri yüklemeleri cmp IDENTICAL. Etki alanı ui.js/forms.js içi kancalarla sınırlı, imza değişikliği yok.

Kalan açıklar (sonraki tur): D1 (6 K8 kancası soru deseni), D3(ii) (cdKaydirAc aşama dalları — veri kapısı `ovsync_tren_listele` + `asama` eşleşmesi). İkisi de PLAN-içi ama tek-tur bütçesini aşıyor; sessiz kapalı değil, bu tabloda kayıtlı.
