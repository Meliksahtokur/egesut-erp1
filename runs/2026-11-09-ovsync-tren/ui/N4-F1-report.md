⟦muse model=muse-spark-1.3 rol=ss-muse-worker iş=N4 eksik iki PLAN maddesi: K8 kancaları V3–V6 G7 G9 + cdKaydirAc aşama dalları⟧

sonuc: TAMAM

BOYUT: üretim net +1065 satır (taban fb41bbf → uç d4f2c78; komut: `git diff --numstat fb41bbf..HEAD -- js/api.js js/ui.js js/forms.js js/ovsync-tren.js index.html manifest.json`; kırılım: index.html +28, js/api.js +35, js/forms.js +235, js/ovsync-tren.js +122, js/ui.js +645. Bu tur delta: forms +104, ui +224, test +832. NOT: N4 toplam +1000 bütçesini 65 satır aşıyor; parça payları tuttu (P1 ≤120 → +104, P2 ≤120 → +78, P3 ≤150 → +147). Bu turda bütçe gerekçesi geçersizdi (brief D1/D3 BLOKLAYAN).)

Son ÜRETİM commit SHA: d4f2c78c29ed9309fd8c4d2fba5f8f2f4ec7e1ec (dal ucu = bu reportun commit'i; BOYUT sayıları üretim commitinden sonra ölçüldü, report commiti sayılmaz)

## Kabul

- Yeni testler kırmızı→yeşil + m5–m8 ADLI testte kırmızı (MEASURED; ham: ~/tmp/muse-ovsync-n4f1/kok-m5-ham.log, kok-m6-ham.log, kok-m7-ham.log, kok-m8-ham.log — DÜZELT turunda ham loga alındı): m5 `N4-F1 V3 TREN p_baslangic_tarihi` 70/1; m6 `N4-F1 G7 BAGIMSIZ hata → toast throw yok` 70/1; m7 `N4-F1 bayrak kapalı → soru yok, eski parametreler (V3/V4/V5/V6)` 70/1 (`V4 bayrak kapalı eski çağrı koşar` assertiyle); m8 `N4-F1 D3ii asama 2 → kaydır yok, (a) PG48 + (b) Bastan baslat` 70/1. Her mutant sonrası yedekten geri yükleme + `cmp` IDENTICAL.
- Tam birim suit (ham: ~/tmp/muse-ovsync-n4f1/n4f1-tam-suit.log; komut: `NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js`): `ℹ tests 2363 · suites 61 · pass 2359 · fail 4` (rc=1). Fail edenler TAM OLARAK taban dördü: degisiklikler-etiketler.test.js:88 (LUNA-3), erteleme-genel-ui.test.js:262 (EG-7), :292 (EG-8), vaka-toplu-ac.test.js:2624 (`ay ‹/›`). Başka fail yok. pass 2359 > 2333.
- `etiket-tazelik` (ham: ~/tmp/muse-ovsync-n4f1/n4f1-etiket.log + n4f1-etiket-liste.txt; komut: `NODE_PATH=... node scripts/etiket-tazelik.mjs`): `payda 316: DOĞRU 297 | HATALI 15 | DOĞRULANAMADI 4` (rc=1). Liste tabanla birebir aynı 19 kalem (yalnız ui.js satır-noları eklentilerle kaydı: _ovsyncAktifBolmeHtml 5858→5936, loadDash 2386→2413, loadAnimals 5445→5523, openDet 8061→8139); hepsi dokunulmayan eski fonksiyonlarda, yeni borç yok.
- Report: `## Fan-out`, `## Self-review` (tek reviewer çocuğu — aşağıda), D1/D3(ii) madde → dosya:satır → test tablosu, `## Run kanıtı`; son commit SHA = dal ucu. Commit öneki `ovsync-tren N4-F1:`; dosya dosya `git add`, push YOK.

## D1/D3(ii) madde → dosya:satır → test

| Madde | Uygulama (dosya:satır) | Test adı |
|---|---|---|
| V3 TREN p_baslangic_tarihi | js/forms.js:855 (`submitCase`), :882-888 soru, :903/:958 TREN tarihi | N4-F1 V3 TREN p_baslangic_tarihi |
| V3 BAGIMSIZ eski çağrı | js/forms.js:903 (`...(tarih ? {...} : {})` yok) | N4-F1 V3 BAGIMSIZ eski çağrı |
| V3 offline Ovsync kuyruğa yazmaz | js/forms.js:860-862 (toast `İnternet yok`, return) | N4-F1 V3 offline Ovsync kuyruğa yazmaz |
| V4 TREN p_tarih | js/forms.js:3315 (`submitBulkCase`), :3353-3360 soru+TREN | N4-F1 V4 TREN p_tarih |
| V4 BAGIMSIZ kullanıcı tarihi | js/forms.js:3346 (`tarih` korunur) | N4-F1 V4 BAGIMSIZ kullanıcı tarihi |
| V5 TREN | js/forms.js:672 (`_ovsyncV5Sargili`), :690 (`_ovsyncV5KancaKur`) | N4-F1 V5 TREN p_baslangic_tarihi + sargı-bir-kez |
| V6 TREN | js/forms.js:1021 (`_vakaBosAtaKanca`), :1027-1038 soru/TREN | N4-F1 V6 TREN p_baslangic_tarihi |
| G7 TREN tohumlama_bos_ve_devam | js/ui.js:3963 (`_devamSeciciOnayla`), :3985-4000 soru | N4-F1 G7 TREN tohumlama_bos_ve_devam + R4 modal-yok |
| G7 BAGIMSIZ start p_bagimsiz | js/ui.js:4001-4015 (`start_first_service_protocol` p_bagimsiz:true) | N4-F1 G7 BAGIMSIZ start p_bagimsiz |
| G7 BAGIMSIZ hata → toast, throw yok | js/ui.js:4006-4015 catch (toast + kapat + pull) | N4-F1 G7 BAGIMSIZ hata → toast throw yok |
| G9 TREN / BAGIMSIZ true | js/ui.js:4845 (`_protokolIptalAkisi`), :4853-4871 bastan_baslat | N4-F1 G9 TREN + N4-F1 G9 BAGIMSIZ true |
| Bayrak kapalı → soru yok (tümü) | forms.js:639 (`_ovsyncKancaDurumu`), ui.js:2311 (`_ovsyncG7G9Sor`) | 3 bayrak-kapalı testi (V3/V4/V5/V6, G7/G9, D3ii) |
| Vazgeç → rpc yok | forms.js:884/1034, ui.js:3995/4859 (`if (!sor) return`) | 2 Vazgeç testi |
| D3(ii) aşama 0 → Sonraki trene aktar | js/ui.js:13614 (`cdKaydirAc`), :13757 (`_ovsyncKaydirDaliAc`), :13820 (`_ovsyncKaydirErtele`) | N4-F1 D3ii asama 0 → Sonraki trene aktar |
| D3(ii) aşama 1 → +N max pg_pay | js/ui.js:13732 (`_ovsyncKaydirSheetHtml` seçici 1..maks) | N4-F1 D3ii asama 1 → +N seçici + pay<=0 yalnız-Baştan |
| D3(ii) aşama 2 → kaydır yok, (a)(b) | js/ui.js:13745 dalı + :13833 (`cdKaydirOvsyncPg48`) + :13843 (`cdKaydirOvsyncBastan`) | N4-F1 D3ii asama 2 → kaydır yok, (a) PG48 + (b) |
| D3(ii) belirsiz → yalnız Baştan başlat | js/ui.js:13746 else dalı | N4-F1 D3ii belirsiz/üye yok → yalnız Baştan başlat |
| D3(ii) offline → kaydır yok + bağlantı | js/ui.js:13742 dalı + :13855 (`cdKaydirOvsyncDuzenle`) | N4-F1 D3ii offline/listele-hatası → kaydır yok + bağlantı |
| D3(ii) OVSYNC değil / bayrak kapalı → eski | js/ui.js:13619-13624 null→eski sheet | 2 eski-sheet testi |

## Fan-out

- Parçalar: P1 (forms.js V3/V4/V5/V6) → P2 (ui.js G7/G9) → P3 (ui.js cdKaydirAc), sıralı (aynı dosyalar). 3 yaprak = 3 workflow çocuğu, tamamı `ss-muse-worker-yaprak`, model muse-spark-1.3, effort xhigh. Wonder çocuk yok.
- Kökün kendi araç çağrısı: brief okuma (5) + dal/ham kontroller (4) + workflow (1) + entegrasyon/mutant/suit/etiket/blast komutları (≈14) + report + reviewer (bekliyor). İş dosyalarına kalıcı edit YOK (mutantlar yedek→uygula→geri→cmp; `git checkout`/`stash` kullanılmadı).
- Parça özetleri: ~/tmp/muse-ovsync-n4f1/1-ozet.txt, 2-ozet.txt, 3-ozet.txt (üçünde de son satır BİTTİ). Kırmızı-önce hamları: kirmizi-ham.txt (45/10), kirmizi-p2-ham.txt (55/8), kirmizi-p3-ham.txt (63/8).
- code-change-precheck kapısı (§4 komut-sonrası): atlas `etki` — submitCase←handlers.js:submit-case, submitBulkCase←submit-bulk-case, _devamSeciciOnayla←devam-secici-onayla, _protokolIptalAkisi←cdProtokolIptal+ovsyncIptal, _vakaBosAtaKanca←caseTakipRetry/submitCase/caseSablonUygula, caseSablonUygula←cd-sablon-uygula, cdKaydirAc←index.html:2384 inline. Dar yarıçap; imza değişikliği yok (yeni parametreler opsiyonel+sonda); tam suit + komşu 132/212/234 yeşil.

## Run kanıtı

Komutların tamamı worktree kökünde (`~/.herdr/worktrees/egesut-erp1/ovsync-tren`) koştu (ağır komutlar `ram-ultracode exec --class test --wait 900 -- bash <betik>`, betikler ~/tmp/muse-ovsync-n4f1/ altında).

```
$ git branch --show-current && git rev-parse HEAD
rc: 0
ovsync-tren
d4f2c78c29ed9309fd8c4d2fba5f8f2f4ec7e1ec
```

```
$ git diff --numstat fb41bbf..HEAD -- js/api.js js/ui.js js/forms.js js/ovsync-tren.js index.html manifest.json
rc: 0
64  36  index.html        → net +28
35  0   js/api.js         → net +35
247 12  js/forms.js       → net +235
152 30  js/ovsync-tren.js → net +122
657 12  js/ui.js          → net +645
TOPLAM net +1065
```

m5 (V3 TREN `ovsyncTrenTarihi = sor.tarih` → null):
```
m5 applied
✖ N4-F1 V3 TREN p_baslangic_tarihi
ℹ pass 70 / ℹ fail 1
RESTORE-IDENTICAL (cmp forms.js yedekle birebir)
rc: 0
```

m6 (G7 BAGIMSIZ try/catch kaldırıldı):
```
m6 applied
✖ N4-F1 G7 BAGIMSIZ hata → toast throw yok
ℹ pass 70 / ℹ fail 1
RESTORE-IDENTICAL
rc: 0
```

m7 (V4 `ovsyncSoruV4` bayrak kapısı kaldırıldı):
```
m7 applied
✖ N4-F1 bayrak kapalı → soru yok, eski parametreler (V3/V4/V5/V6)
  AssertionError: V4 bayrak kapalı eski çağrı koşar
ℹ pass 70 / ℹ fail 1
RESTORE-IDENTICAL
rc: 0
```

m8 (aşama 2 dalına kaydır düğmesi eklendi):
```
m8 applied
✖ N4-F1 D3ii asama 2 → kaydır yok, (a) PG48 + (b) Bastan baslat
ℹ pass 70 / ℹ fail 1
RESTORE-IDENTICAL
rc: 0
```

Tam suit (ham: ~/tmp/muse-ovsync-n4f1/n4f1-tam-suit.log):
```
SUIT-RC=1
ℹ tests 2363 · suites 61 · pass 2359 · fail 4 · cancelled 0
test at tests/unit/degisiklikler-etiketler.test.js:88:1
test at tests/unit/erteleme-genel-ui.test.js:262:1
test at tests/unit/erteleme-genel-ui.test.js:292:1
test at tests/unit/vaka-toplu-ac.test.js:2624:3
rc: 1 (4 taban fail — beklenen; pass 2359 > 2333)
```

Etiket (ham: ~/tmp/muse-ovsync-n4f1/n4f1-etiket.log):
```
payda 316 satır: DOĞRU 297 | HATALI 15 | DOGRULANAMADI 4
rc: 1 (tabanla aynı 15/4; diff kanıtı: taban-etiket-liste.txt [~/tmp/muse-ovsync-n4/n4-final-etiket-liste.txt kopyası] vs n4f1-etiket-liste.txt, satır-no normalize diff BOŞ — ETIKET-LISTE-TABANLA-BIREBIR)
```

## Self-review

Reviewer: TEK `ss-muse-reviewer` (Spark xhigh), verdict **DÜZELT** → 1 düzeltme turu (kök). Ham: ~/tmp/muse-ovsync-n4f1/reviewer-ozet.txt (BİTTİ; reviewer salt-okur olduğundan dosyayı kök kaydetti, içerik kelimesi kelimesine). Üretim kodu sağlam bulundu; DÜZELT gerekçeleri kanıt/commit eksikleri (kod bug'ı değil).

| Bulgu | durum | gerekçe/kanıt |
|---|---|---|
| (a) `## Self-review` başlığı yok; report untracked/commitlenmemiş | düzeltildi | Bu bölüm eklendi; report aşağıda ayrı commitleniyor |
| (c) `fb41bbf..HEAD` aralığında Yazılabilir-dışı dosyalar + BOYUT'taki index.html brief listesinde yok | kaldı (kapsam-dışı + gerekçeli) | F1 commit'i (d4f2c78) temiz — yalnız 3 Yazılabilir dosya. Aralık-içi diğer dosyalar önceki N4 commitlerinden (root kayıtları). index.html değişikliği N4 tur 1'den; BOYUT kapsamı brief emriyle üretim dosyaları (`taban fb41bbf, üretim dosyaları`) |
| (d) m5–m8 `70/1` ham çıktısı yok | düzeltildi | kok-m5/6/7/8-ham.log dosyaya alındı, Kabul satırı bağlandı |
| (d) etiket taban-birebirlik kanıtı yok | düzeltildi | taban-etiket-liste.txt kopyası + normalize diff BOŞ |
| (e) mutant kırmızı hamdan doğrulanamadı | düzeltildi | Yukarıdaki ham loglarla kapandı (yeniden koşum, cmp IDENTICAL) |
| (i) atlas `etki` ham çıktısı yok | düzeltildi | ~/tmp/muse-ovsync-n4f1/kok-etki-ham.log (7 sembol) |
| (j) minör notlar (`_ovsyncKancaSor` fallback etiketi, özyinelemede override düşmesi, V4 `!manuelVar`, aşama-0 p_gun=1, strict-equality) | kaldı (bloke değil) | Reviewer kendisi bloke saymadı; davranış briefle eşleşiyor, testlerle kilitli. (j) tam-okuma sınırı: ui.js 14k satırın tamamı tek tek okunmadı — örneklemeli düşmanca okuma + tam suit yeşil |
| (1) N4-F1-brief.md 1-satır kirini temizle | kaldı (kök metası) | `job_id:` satırı oturum açılışında vardı (P1 özeti m.8), root sevkiyat metası olabilir; `git checkout` briefçe YASAK; silmek root izini siler. Commitlenmedi, raporda kayıtlı |
| (k) +1065 bütçe aşımı (65 satır) | raporda dürüstçe yazılı | Brief bu turda bütçe gerekçesini geçersiz saydı; TAMAM koşulu (UB1–UB5 + D1/D3(ii) kodda ve testli) etkilenmez |

## Varsayım

- `ovsync_tren_listele` hatası da çevrimdışı sheet'ini açar (`İnternet yok` metniyle; brief ikisini aynı sheet'e bağlar — P3 özeti m.6, INFERRED).
- Offline + OVSYNC + inaktif vaka artık `Yalnız aktif vaka` toast'u verir (önceki `İnternet yok` yerine); ikili hiçbir mevcut testte yok (P3 özeti m.3, MEASURED).
- Manifest değişmedi (sürüm dizesi içermez — N4 kararı aynen).

## Kırıntılar

- ~/tmp/muse-ovsync-n4f1/ (1/2/3-ozet.txt, kirmizi/yesil/komsu hamları, kok-*.sh, n4f1-tam-suit.log, n4f1-etiket.log, n4f1-etiket-liste.txt, *.m5/m6/m7/m8yedek) — Yazılabilir tmp kapsamında, repo dışında.
- Untracked N4-dışı girdiler (dokunulmadı): runs/.../PLAN-KAPI-*-report.md, mockup/, plan-brief.md, plan-report.md.
- `runs/.../ui/N4-F1-brief.md` çalışma-ağacı 1 satırlık `job_id:` ekini ben yazmadım (oturum açılışında vardı); commitlenmedi.

## Öğrenilen

- `node --test` özet `ℹ tests/pass/fail` satırları `| tail` ile kaybolur; tam çıktı dosyaya alınıp `ℹ`/`test at` ile taranmalı (bu tur kok-tam-suit.sh önce kuyruğu kaydetti, kok-tam-suit2.sh ile düzeltildi).
- etiket-tazelik taban-karşılaştırması satır-no kaymalarını normalize etmeli (kalem adı aynı, no farklı → aynı kabul).

