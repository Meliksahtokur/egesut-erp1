⟦muse model=muse-spark-1.3 rol=ss-muse-worker iş=N4-F2 tren ekranı bağlaması: B1 veri çekimi, B2 toptan/tekil eylemler, tren ayarı, K4-K8, q2⟧

sonuc: KISMI
BOYUT: net +1781 (taban fb41bbf → uç 4c51b43; yalnız üretim: js/ui.js +1346/-22, js/forms.js +246/-12, js/ovsync-tren.js +126/-38, js/api.js +35/-0, index.html +28/-36; bütçe ≤+1250 → +531 AŞIM).

## Fan-out

- Parça 1 (Spark xhigh): B1 `loadOvsyncDash` + 4 test → ui.js, entegrasyon.test.js.
- Parça 4 (Spark xhigh, P1 ile paralel — ayrı dosya): K4/K5 → ovsync-tren.js, ovsync-tren.test.js.
- Parça 2 (Spark xhigh, P1 sonrası — aynı dosya): B2 toptan + ERTELE/SONRAKI_TREN/PG48 + 12 test.
- Parça 3 (Spark xhigh, P2 sonrası): tren ayarı paneli (mockup 06) + 6 test.
- Parça 5 (Spark xhigh, P3 sonrası): K6/K7/K8 + q2 (ui.js/forms.js; yeni test yok, mevcut suit yeşil kilit).
- Parça 6 (Spark xhigh, salt-okur): entegrasyon — mutant özeti, çağıransız tablosu, tam suit, etiket, BOYUT.
- Parça 7 (Spark xhigh, salt-okur): self-review — B1/B2 zinciri + çağıransız tablosu ayrıca doğrulandı.
- Açılan çocuk: 7 workflow çocuğu (tamamı muse-spark-1.3 xhigh; Wonder yok). Kök inline araç çağrısı: ~12 (özet okuma, spot grep, BOYUT, commit). İş dosyalarına kök editi YOK.

## Yapılan

- B1 (CONFIRMED js/ui.js:660): `loadOvsyncDash` bayrak açıkken `ovsync_tren_listele` takip çağrısıyla PARALEL (`Promise.allSettled`) çekilir. Sonuç `aktif===true` ise `renderOvsyncSayfa(veri, bugunIso, trenVeri)` (js/ui.js:1963, 3. argüman). Hata/`aktif!==true`/offline → 3. argüman `undefined`, eski "Dalga:" yolu birebir (bayat dalı dahil). Bayrak kapalıyken `ovsync_tren_listele` ÇAĞRILMAZ.
- B2 (CONFIRMED js/ui.js:2284,2387): delegated dinleyici `_ovsyncTrenAksiyonTikla` tüm `data-` eylemlere kol alır; yeni modal HTML'lerinde inline onclick 0 (MEASURED `grep -c data-ovsync-aksiyon`=16 dinleyici tarafı; `onclick` yeni bloklarda yok).
  - TOPTAN (js/ui.js:2597): N seçici (1..7) → `ovsync_tren_ertele_onizle(p_tarih, p_n)` → modal; SECIM `secimler`'e yazılır, gövde yeniden çizilir; `ovsyncToptanOnayAcikMi` false iken ONAYLA disabled + neden; ONAYLA → `ovsync_tren_ertele(p_tarih, p_n, p_secimler)`; başarı F5 metni (`ileri_vakalar`, `iptal_tai`, `basladi:false`+`yeniden_hedef`) + kapanış + `_ovsyncTrenYenile` (js/ui.js:2710: invalidate + `loadOvsyncDash`); `OVSYNC_TREN_ERTELE_DUSTU` → modal AÇIK, düşen küpeler + sebep.
  - ERTELE (aşama1: 1..`pg_pay`) / SONRAKI_TREN (p_gun=1 sunucuda, PLAN D6) / bağımsız (1..7, `ovsyncTekErteleAraligi`) → `ovsync_hayvan_ertele`; PG48 → `ovsync_pg48_tohumla`, `tai_hedef` toast (BOŞLUK-1 sonrası). BASTAN/DUZENLE korunur. Offline (`_ertelemeOnline` false) → düğmeler ÇİZİLMEZ. Tüm yazmalardan sonra invalidate + tazeleme (js/ui.js:2702,2806,2828,2850,3079).
- Tren ayarı (CONFIRMED js/ui.js:2950 `ovsyncAyarAc`): panel — aktif anahtar + çapa (kanonik takvim + hidden; `type=date` YOK, tarih-saf F4); Önizle → `ovsync_tren_yeniden_hedefle(p_kuru:true, p_capa)` özet; Kaydet → `ovsync_tren_ayar_guncelle(p_aktif, p_capa)`; hata `OVSYNC_TREN_AYAR` metinli.
- K4 (CONFIRMED js/ovsync-tren.js:721,725): `_ovtHataMetniImpl` tüm büyük harfli token'ları `matchAll` ile gezer, `_OVT_HATA`'da ilk bulunanı seçer.
- K5: 3 JSDoc bitişikliği düzeltildi (grep -B2 doğrulandı).
- K6 (js/ui.js:14299): `cdKaydirAc` guard en başta, OVSYNC-aktif vaka muafiyetiyle (brief istisnası). K7 (js/forms.js:868): `submitCase` offline snapshot'ı IDB okumasından ÖNCE. K8 (js/ui.js:2241): ölü `TEDAVI_GUN`/`TEDAVI_SEANS` kolu kaldırıldı.
- q2 (js/ui.js:15453, js/forms.js:671,693,700-704): `caseSablonUygula` başına V5 erken dalı; otomatik sargı kaldırıldı, gövdeler uyumluluk için korundu (üretimde çağrılmaz — tabloya işlendi).
- q1 YAPILMADI (kaldı — gerekçe aşağıda, SORU-1).

## Kabul karşılaştırması

| Madde | Durum | Kanıt |
|---|---|---|
| B1/B2/K4 yeni testleri kırmızı→yeşil | PASS | 4+12+6+1 adlı test; kırmızı varyantların hepsi RED + `cmp IDENTICAL` |
| m9–m12 ADLI testte kırmızı | PASS | m9 fail 2 (ham: 1-ozet + b1-mutant-m9.sh reçete); m10 fail 1 (ham: mutant-m10.log:2133); m11 fail 1 (ham: mutant-m11.log:2178); m12 fail 1 (ham: a3-mutant-m12.log) |
| m1, m5, m8 yeniden kırmızı | PASS | m1 F9 fail 1, m5 V3 TREN fail 1, m8 D3ii fail 1 (reçete: p5-mutant-m1/m5/m8.sh; ham stdout workflow notes'ta — eksik, aşağıda not) |
| Tam suit fail 4 = taban dördü, pass > 2359 | PASS | tests 2386 · pass 2382 · fail 4 (ham: 6-tam-suit.log; fail: degisiklikler-etiketler.test.js:88, erteleme-genel-ui.test.js:262, :292, vaka-toplu-ac.test.js:2624) |
| etiket-tazelik HATALI 15 / DOĞRULANAMADI 4, liste tabanla aynı | PASS | payda 316: DOĞRU 297 (ham: 6-etiket.log, 6-etiket-isim.txt) |
| Çağıransız tablosu temiz | PASS | 0 boş-çağıranlı üretim satırı (tablo aşağıda) |
| BOYUT ≤ +1250 | KALDI | +1781 → +531 aşım (SORU-2) |
| q1+q2 | KISMEN | q2 PASS; q1 KALDI (SORU-1) |

## Bulgu → dosya:satır → test

| # | Bulgu | Dosya:satır | Test |
|---|---|---|---|
| B1 | Paralel listele + 3. argüman | js/ui.js:660,1963 | entegrasyon.test.js:1947,1956,1964,1972 (m9 adlı:1947) |
| B2-TOPTAN | Önizle/SECIM/onay kapısı/ertele + DUSTU modal-açık | js/ui.js:2597,2688,2691,2670 | entegrasyon.test.js:2119,2133 (m10),2140,2166,2178 (m11) |
| B2-tekil | ERTELE/SONRAKI_TREN/PG48 + offline | js/ui.js:2745,2796,2819,2841 | entegrasyon.test.js:2194,2210,2221,2230,2255 |
| AYAR | Panel + Önizle + Kaydet + hata | js/ui.js:2950,3053,3072 | entegrasyon.test.js:2357,2382,2398,2410 (m12),2425,2437 |
| K4 | matchAll ilk-bulunan | js/ovsync-tren.js:721,725 | ovsync-tren.test.js:506 |
| K6/K7/K8 | guard-first / snapshot-first / ölü kol | js/ui.js:14299, js/forms.js:868, js/ui.js:2241 | mevcut suit yeşil (N4-F1 D3ii/V3 kilitleri) + m5/m8/m1 mutantları |
| q2 | V5 erken dalı | js/ui.js:15453, js/forms.js:700-704 | mevcut suit yeşil |

## Çağıransız tablosu (MEASURED `grep -n`, test dosyaları sayılmaz; 0 boş-çağıranlı üretim satırı)

| Sembol | Üretim çağrı yeri |
|---|---|
| `ovsync_tren_listele` | js/ui.js:681 `rpc(...)`, :2729/:2953/:14451 sarmal |
| `ovsync_tren_ertele_onizle` | js/ui.js:2605/:2638 |
| `ovsync_tren_ertele` | js/ui.js:2691; js/api.js RPC_TABLES |
| `ovsync_hayvan_ertele` | js/ui.js:2796/:2819, :14512 kaydır; js/api.js RPC_TABLES |
| `ovsync_pg48_tohumla` | js/ui.js:2841, :14521 kaydır; js/api.js RPC_TABLES |
| `ovsync_bastan_baslat` | js/ui.js:2497, :5542/:5545 |
| `ovsync_tren_yeniden_hedefle` | js/ui.js:3053 (Önizle, `p_kuru:true`) |
| `ovsync_tren_ayar_guncelle` | js/ui.js:3072 (Kaydet); js/api.js RPC_TABLES |
| `_ovsyncTrenAksiyonTikla` | js/ui.js:2387 `addEventListener` + dispatcher kolları |
| `ovsyncToptanAc` / N / SECIM / Onayla / `ovsyncToptanOnayAcikMi` | js/ui.js:2597/:2631/:2654/:2685 + dinleyici; onay: ovsync-tren.js:378 + :2688 |
| `ovsyncTekErteleAraligi` | ovsync-tren.js:581 tanım; js/ui.js:2745 çağrı |
| `_ovsyncTrenCagir` / `_ovsyncTakipInvalidate` / `_ovsyncTrenYenile` | toptan/ertele/ayar/yazma-sonrası zinciri |
| `ovsyncAyarOnizle` / `ovsyncAyarKaydet` / `ovsyncErteleOnayla` / `ovsyncPg48` / `ovsyncSonrakiTren` | js/ui.js:3047/:3067/:2791/:2837/:2815 dinleyici kolları |
| `_ovsyncKaydirDaliAc` | cdKaydirAc zinciri |
| `_ovsyncV5Sargili` / `_ovsyncV5KancaKur` | forms.js:676/:698 tanım + :702 üretim sargısı (test-girişli uyumluluk; boş satır yok) |

## Run kanıtı

- `git diff --numstat fb41bbf -- js/api.js js/ui.js js/forms.js js/ovsync-tren.js index.html` → `rc:0` → 64/36 index.html, 35/0 api.js, 258/12 forms.js, 164/38 ovsync-tren.js, 1368/22 ui.js (ham: komut çıktısı; net +1781).
- Tam suit: `ram-ultracode exec --class test --wait 900 -- bash ~/tmp/muse-ovsync-n4f2/6-tam-suit.sh` → `rc:0` (iç SUIT_RC=1 beklenen) → ham tail (6-tam-suit.log):
  `ℹ tests 2386 · ℹ suites 61 · ℹ pass 2382 · ℹ fail 4 · ℹ cancelled 0`; fail: `degisiklikler-etiketler.test.js:88` (LUNA-3 canlı DEMO şema kayması — çevresel, kapsam dışı), `erteleme-genel-ui.test.js:262` (EG-7), `:292` (EG-8), `vaka-toplu-ac.test.js:2624` (MEASURED ham logdan).
- Etiket: `ram-ultracode exec --class test --wait 900 -- bash .../6-etiket.sh` → `rc:0` (iç ETIKET_RC=1) → `payda 316: DOĞRU 297 | HATALI 15 | DOGRULANAMADI 4` (ham: 6-etiket.log tail; isim listesi 6-etiket-isim.txt).
- m10 (ham: mutant-m10.log): `✖ N4-F2 B2 SECIM seçilmeden ONAYLA → rpc YOK (m10 adlı) ... fail 1` + `test at ...:2133:1`. m11 (ham: mutant-m11.log): `✖ N4-F2 B2 ERTELE_DUSTU ... fail 1` + `test at ...:2178:1`. m12 (ham: a3-mutant-m12.log tail): `actual: 0, expected: 1` RED + restore `cmp IDENTICAL` (3-ozet).
- m9: 1-ozet + reçete b1-mutant-m9.sh → 'bayrak açık' + 'bayat dal' fail 2/75, geri yükleme IDENTICAL (MEASURED 1-ozet; ham stdout workflow notes'ta, dosyada yok — eksik, not edildi).
- m1/m5/m8: P5 reçeteleri p5-mutant-m1/m5/m8.sh → her biri fail 1 + RESTORE-IDENTICAL (MEASURED 5-ozet; ham stdout dosyada yok — eksik, not edildi).
- Baz-dörtlü teşhisi (systematic-debugging Faz-1, düzeltme YOK — kapsam dışı): fail eden test dosyalarının hiçbiri diff'te yok (MEASURED `git diff --name-only -- tests/` → yalnız 2 N4 dosyası); `_erteleKaydet` diff'te 0 eşleşme (tanım js/ui.js:4899 aynen); aynı 4 fail P1→P6 arası 6 bağımsız suit koşusunda sabit (test sayısı 2368→2386 artarken); LUNA-3 mesajı canlı DEMO şema kayması (çevresel). Kök-neden: taban borcu + canlı şema kayması; N4-F2 değişikliği değil (INFERRED — taban committe tek tek koşulmadı, `stash` brief'te YASAK).

## Self-review (tek reviewer çocuğu P7 + kök spotları)

Reviewer (P7, Spark xhigh salt-okur) verdicti: B1/B2/K4/K5/K6/K7/K8/q2 DOGRULANDI (okundu); çağıransız tablo KABUL; BOYUT AŞIMI ölçüldü (+1781, +531). P7'nin `7-ozet.txt` dosyası yazılamadı (BITTI yok) — bulgular workflow sonucu üzerinden alındı (kayıtlı evidence c6); dosya eksikliği bu raporun notudur, bulguların kendisi okunmuş kod satırlarına dayanır.
Kök spot doğrulamaları (MEASURED): SONRAKI_TREN adlı testi mevcut (entegrasyon.test.js:2221) — reviewer'ın "tek tek doğrulanmadı" notu kapatıldı. q1 blok gerekçesi doğrulandı (loadModule.js:183-211 `extractFunctionSource` bağımlılık çekmez + liste sabitleri entegrasyon.test.js:609,1076,1372 — CONFIRMED). Yazılabilir-dışı değişiklik: `N4-F2-brief.md` 1 satır (`job_id:`) — harness kaydı, çocuklar dokunmadı (1-ozet:37); bu commit'e alınmadı, ağaçta kirli duruyor.
(a) Kabul maddeleri yukarıdaki tabloda tek tek — BOYUT ve q1 KALDI. (b) Test-önce adları birebir. (c) Yazılabilir dışı üretim değişikliği yok (brief satırı hariç, raporda). (d) Sayılar hamdan (BOYUT komut çıktısı, suit/etiket logları). (e) m9–m12 + m1/m5/m8 mutant-kırmızı mevcut. (f) Canlı yol canlı/kopya ölçümü: LUNA-3 canlı DEMO'ya karşı koştu (fail sebebi de bu). (g) Üretici betik: `6-tam-suit.sh`/`6-etiket.sh` commitli değil (scratch — yalnızca ham; raporun iddiası ham log dosyaları). (h) Adlar mevcut yazımla tutarlı. (i) Ana brief tuzakları: NODE_PATH + ram-ultracode kullanıldı; `render/gezinti` testlerine dokunulmadı; tıklama-simülasyonu kuralına uyuldu; özetler `~/tmp/muse-ovsync-n4f2` altında. (j) Değişen dosyalar okundu (spot + reviewer). (k) Sayılar yeniden hesaplandı (BOYUT +1781 kök ölçümü; suit 2386/2382/4 hamdan). (l) Tekrar taraması çocuklarda (dinleyici tekil; yardımcı önerisi q1'de takıldı). (m) Test tuzakları: sahte-canlı bağı yok (sahteler kayıtlı), yol yasağına uyuldu, mutantlar koştu, hata yolları testli (DUSTU/ayar-hata/offline).
Düzeltme turu: açılmadı (ÖNEMLİ bulgu = kapsam kararı gerektiren q1 + BOYUT; kod düzeltmesi değil → SORU).

## Kırıntılar

- `~/tmp/muse-ovsync-n4f2/` altında ham log/betik/özetler (b1-*, b2-*, a3-*, p5-*, 6-*, mutant-*.log, *.yedek, ui.js.b2yesil, ovsync-tren.js.K4YESIL) — kanıt, silinmedi.
- `N4-F2-brief.md` çalışır-ağaçta 1 satır kirli (`job_id:` harness kaydı) — commitlenmedi.
- `runs/2026-11-09-ovsync-tren/` altında D9 lane untracked girdileri (PLAN-KAPI-*, mockup/, plan-*) — bu işe ait değil, dokunulmadı.

## Öğrenilen

- [egesut-erp1] Cerrahi test ctx listeleri (`N4F1_FORMS_FNS`, `UB*_UI_EK`, `N4F1_G7G9_UI`) yeni yardımcıyı görünmez kılar — ortak yardımcı işi test-listesi değişikliği gerektirir; brief'e yazılmalıydı. (bellek notu: kişisel kapsamda bu tura ait not açılmadı — kalıcı ders brief-tasarımına ait, kod davranışına değil; yazılmadı.)
- [egesut-erp1] N4 kümülatif BOYUT (+1781) tur bütçesini (+1250) aştı — tur bazında değil taban-bazında izlenmeli.

SORU-1: q1 (üç K8 soru kurulumu tek yardımcıya) test-listesi değişmeden imkânsız (kanıt: loadModule.js:183-211 + entegrasyon.test.js:609,1076,1372) · seçenekler: (a) P5 tasarımıyla test listelerine ad ekleyip q1'i kapat, (b) q1'i kapsam dışına al · önerim: (a), sonraki turda.
SORU-2: BOYUT +531 aşımı (N4-F2 deltası +716, çoğu ui.js) · seçenekler: (a) aşımı kabul et (zincir testleri bunun karşılığı), (b) kırpma turu aç · önerim: (a), gerekçe B1/B2 zincir testleri bu turun ölçütüydü.

Son ÜRETİM commit: 4c51b43


## ROOT RULING (SORU-1/2 cevabı, 2026-11-09)
- Root nokta-ölçümü: `renderOvsyncSayfa(durum.veri,bugunIso,trenArg)` ui.js:694/:698; 8 tren RPC'sinin üretim çağrı yeri var (ui.js:2605, 2638, 2691, 2796, 2819, 2841, 2497, 3053, 3072); parametre adları SQL imzalarıyla birebir (006:251/333, 007:249/267, 008:19/113). B1/B2 CONFIRMED.
- SORU-1 → (b): q1 kapsam dışı; "N4 UI cila" kalemine (q1 ortak soru yardımcısı + q2 uyumluluk gövdeleri `_ovsyncV5Sargili`/`_ovsyncV5KancaKur` + BOYUT kırpma). Muse 3 turunu kullandı; bu tur kod yok.
- SORU-2 → (a): BOYUT +1781 (bütçe 1250) bu teslimde kabul; kırpma "N4 UI cila" kalemine.
- N4 kabulü: bağımsız ss-verifier K1/K2/K3 + m9/m10 yeniden koşumuna bağlı; uçtan uca asıl kanıt N6 demo yürüyüşü + zaman senaryosu.
