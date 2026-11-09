⟦ss-sub model=opus effort=high rol=ss-worker-high iş=Tren ekranı yerleşimini mockup 02a/02b'ye uydur ve "Ovsync ekranında düzenle →" linkini görev sheet'ine sızdırmadan hayvana odakla⟧
sonuc: TAMAM

MUSE-YEDEK: N4 UI işinde Muse 3 tur kullandı; bu tur Opus (ss-worker-high).
commit: 0f8cfd4 (kod + test), report + PNG commit'i bunun ardından (aynı dal, push yok).

## Gelen iş denetimi
Bulgu yok (plan uygulanabilir, dosyalar yazılabilir listede, kabul ölçülebilir). Tek not: e2e `tests/e2e/ovsync-tren.spec.js:233` `h2 "Trenler"` ve `:292` `h2:text-is("Bağımsız")` seçicilerine bağlı; e2e yazılabilir listede değil → iki h2 metni korundu (bkz. Kırıntılar decision).

## Ne değişti (CONFIRMED, diff 0f8cfd4)
- `js/ovsync-tren.js`: yeni `ovsyncTrenIsEtiketi(tren,bugunIso)` (Y2): üyelerin `sonraki_is.tarih` en erkeni bugünse `bugün: <iş>` (`ovs-tren-bugun`), değilse `<Gün gg Ay>: <iş>` (`ovs-tren-is`); tür adı GNRH1→başlangıç günü, PG1→PG günü, PG2→2. PG günü, GNRH2→2. GnRH günü, TAI→PG+48 tohumlama; aynı gün farklı işler ` + `; bilinmeyen tür ham kodla. Hiç `sonraki_is` yoksa eski D0 gün-farkı kuralı. `ovsyncTrenBaslikHtml` bunu kullanır.
- `js/ui.js`:
  - `renderOvsyncSayfa` (yalnız tren dalı): trendeki üyelerin S3 satırları ayrılır → trene kart; S3 listesinde kalmaz (Y3). Bayrak kapalı dal dokunulmadı.
  - `_ovsyncTrenGovdeHtml`: S0∪S1∪S3 gruplanır; her trende `uyeler.length ≠ kart` ise görünür `⚠ Sunucu N hayvan diyor, ekranda M kart (takip satırı yok: küpeler)` + `console.warn` (Y3). Bağımsız: `<h2>Bağımsız</h2>` + `· N hayvan` + mockup 02b açıklaması; alt satır kartın içinde (Y4/Y5).
  - `_ovsyncTrenSatirHtml` + yeni `_ovsyncKartaEkle`: aksiyon/PG+48 satırı kartın kapanış div'inden ÖNCE; kart kökü `data-ovs-hayvan` (Y4, B1).
  - yeni `_ovsyncTrenBaslatKartHtml`: aşama-0 tren kartı (küpe · grup · taban, `başlamadı · başlangıç gg.aa`, mevcut ▶ Başlat/pencere/kısır kilidi + ✕; Ertele yok).
  - yeni `_ovsyncDuzenleYakala` (capture fazında `document.addEventListener('click',…,true)`): `[data-ovt-aksiyon="DUZENLE"]` → `stopPropagation` + `preventDefault` + mevcut dispatcher (B1).
  - yeni `_ovsyncOdakTuket(root)`; `loadOvsyncDash` sonunda (kaydırma geri yüklemesinden SONRA) çağrılır: kartı `scrollIntoView({block:'center'})`, başlığa 2.5 sn `ovs-odak` (yalnız yazı rengi), değişken `null`; kart yoksa konsol uyarısı + yine temizlenir.
- `index.html`: F14 bloğunun ÖNÜNE yerleşim bloğu (flex başlık, kalın ad, link görünümlü düğme sıfırlaması, `.ovs-asama` satırı, not/alt satır boyutları); F14 bloğuna yalnız renk: `.ovs-tren-is`, `.ovs-tren-uyari`, `.ovs-odak`. Yeni zemin/şerit/çerçeve rengi YOK (düğme sıfırlaması `background:none` hariç; F14 testi geçer).

## Görsel kabul — mockup ↔ canlı (demo vitrin `vtzqjmazsvurxdeondmi`, bugün Pzt 9 Kas 2026)
PNG'ler: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/f4/`
- `f4-mobil-ovsync-tam.png` (390 geniş, tam sayfa), `f4-mobil-ovsync-ust.png` (390×844)
- `f4-masa-ovsync-tam.png` (1280 geniş, tam sayfa), `f4-masa-ovsync-ust.png` (1280×800)
- madde 7: `f4-mobil-madde7-gorevler.png`, `f4-mobil-madde7-ovsync.png`, `f4-masa-madde7-gorevler.png`, `f4-masa-madde7-ovsync.png`
- DOM ölçümü: `f4-mobil.json`, `f4-masa.json`

Y1–Y5 (OBSERVED: PNG'leri Read ile gördüm; MEASURED: json):
- Y1 mockup'ta "Tren · Per 19 Kas · 4 hayvan · bugün: PG günü" kalın başlık + sağda "Tren gününü ertele…" → canlıda "**Tren · Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü**" kalın, sayı yeşil yazı, aynı satırın sağında mavi "Tren gününü ertele…" (yalnız F9 ilk ritim treni; 8 başlıktan 1'inde). Zemin/şerit yok.
- Y1 mockup'ta başlık altında trenin tüm kartları → canlıda 8 trenin 8'inde başlık N = altındaki kart sayısı (1/1, 1/1, 2/2, 1/1, 1/1, 1/1, 3/3, 2/2; json `basliklar[].n == kart`), uyarı 0.
- Y2 mockup'ta "bugün: PG günü" → canlıda "Pzt 9 Kas · … · bugün: başlangıç günü" (kırmızı yazı) ve ileri gün "Per 5 Kas · 2 hayvan · Per 12 Kas: PG günü", "Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü" → Perşembe 12 Kas işi iki başlıktan okunuyor (DM2 BULGU-2'nin sorusu).
- Y3 mockup'ta 212/418 "Başlamadı: Sonraki trene aktar → Per 3 Ara" kart içinde → canlıda 5708 / E2E-TREN-UI-01 / UI-02 kartları Per 12 Kas başlığı altında, kart içinde "Başlamadı: Sonraki trene aktar → Per 19 Kas"; S3'te UI-01/UI-02 tekrar yok (json `s3Tekrar: []`).
- Y4 mockup'ta aksiyon ("PG bugün: PG'yi ertele · en çok +1 gün", "PG yapıldı · erteleme yok: PG1 + 48 s'te tohumla / Baştan başlat") kartın içinde → canlıda aynı satırlar kartın içinde; kart dışı `.ovs-asama`/`.ovs-bagimsiz-alt` = 0 (json `yetim: 0`). Eski "PG 05.11: PG'yi ertele" yetim satırı yok.
- Y5 mockup 02b'de "Tren · Cum 20 Kas · 1 hayvan · ritim dışı" + açıklama; "Bağımsız · 2 hayvan" + açıklama → canlıda "Tren · Cum 6 Kas · 1 hayvan · ritim dışı · Cum 13 Kas: PG günü" + "Ritim dışı (PG +1 gün). Toptan ertelemeye girmez…"; "Bağımsız · 5 hayvan" + "Trene sayılmaz. Tren ertelemesi bunlara dokunmaz; aşama kuralları…".
- Madde 7 (B1) mockup 5a: link → Ovsync ekranı → canlıda görev kartındaki "Ovsync ekranında düzenle →" tıklandı: görev sheet AÇILMADI (`sheet: null`), Ovsync ekranı açıldı, hayvan kartı görünür alanda (mobil y=392/844, masa y=401/800), küpe mavi yazıyla vurgulu (`vurgu: true`), `_ovsyncOdakHayvan` = null. Konsol hatası 0.

Farklar / açık noktalar (bilerek kapsam dışı):
- Mockup'ta S1 başlığı "S1 · Aktif zincirler"; canlıda "Trenler" kaldı (e2e seçici, decision kırıntısı).
- Aşama-0 kartında mockup gün şeridi (0/4 uygulandı, 1–4. uygulama tarihleri) yok: vaka henüz açılmadı, S3 satırında `gunler` yok → uydurulmadı; kart "başlamadı · başlangıç 12.11" yazar.
- Bağımsız kart alt satırı ham tür kodu ("008 · PG2 01.11") — BOŞLUK-3 sözleşmesi, bu turda değişmedi.
- S0 BUGÜN/GECİKEN kartlarının mevcut renkli zemin/sol şeridi (önceki koddan; mockup notu "S0 kartları değişmiyor") olduğu gibi.
- Madde 7 için DM2'nin X-5 TAI görevi IDB'de yok (`taiGorev: null`, OBSERVED) → betik Görevler/bugün listesindeki ilk düzenle linkli Ovsync kartını kullandı: E2E-TREN-UI-08 (OVSYNC_BASLAT). Akış aynı (TAI kartı için de aynı düğme/dinleyici).
- Masaüstü koşusunda 36 kartında "vaka bağlantısı bilinmiyor" ve 38 kartında ▶ Başlat yok, mobilde var: IDB bağlam yüklemesi zamanlaması (DM2'de de OBSERVED, INFERRED: bu değişiklikle ilgisiz).

## Testler (TDD)
RED (ilk koşu, kod yokken): `iş etiketi bugün / ileri gün` FAIL (başlıkta iş etiketi yok); entegrasyon 51 FAIL (yeni fonksiyonlar yok — çıkarma bağlamı kuruluyor). GREEN: `ovsync-tren.test.js` 42/42, `ovsync-tren-entegrasyon.test.js` 102/102.
Adlı testler: `tren bloğu: başlık altında tüm üyelerin kartı, N=kart sayısı`, `aşama 0 üye trende kart + Sonraki trene aktar, S3'te tekrar yok`, `aksiyon kart içinde, yetim satır yok`, `iş etiketi bugün / ileri gün`, `düzenle linki görev sheet açmaz`, `odak hayvana kaydırır ve temizlenir`. Güncellenen eski assert: `UB3 BOŞLUK-3 tel` "Bağımsız · 1 hayvan" görünen metinle + `<h2>Bağımsız</h2>` kilidi.

Mutantlar (`$HOME/tmp/n4f4/mutant.sh`, MEASURED):
```
== m13: aşama-0 (S3) üyeler gruptan çıkarıldı
✖ aşama 0 üye trende kart + Sonraki trene aktar, S3'te tekrar yok
✖ tren bloğu: başlık altında tüm üyelerin kartı, N=kart sayısı
ℹ fail 2
m13 geri: IDENTICAL
== m14: B1 stopPropagation kaldırıldı
✖ düzenle linki görev sheet açmaz
ℹ fail 1
m14 geri: IDENTICAL
```
Tam suit (MEASURED): taban 2391/2387/fail 4 → şimdi tests 2397, pass 2393, fail 4 (aynı dört: LUNA-3, EG-7, EG-8, bc-tarih/ay ‹/›). etiket-tazelik: DOĞRU 297 | HATALI 15 | DOGRULANAMADI 4 (15/4 taban).

BOYUT: bütçe 150 · gerçek 135 (net: index.html +17, js/ovsync-tren.js +31/−3, js/ui.js +100/−10; JSDoc dahil) · bütçe içinde

## Kırıntılar
- assumption: sonraki_is olmayan trende iş etiketi eski D0 kuralına düşer; geçmiş en erken gün tarihle yazılır ("Per 29 Eki · … · Per 5 Kas: PG günü"). (ss-crumbs kaydı; araç workspace'i cwd'den `tedavi-arge` yazdı)
- decision: `Trenler` ve `Bağımsız` h2 metinleri e2e seçicileri için korundu.
- measurement: demo vitrinde 8 başlık N=kart, yetim 0, S3 tekrar 0, madde 7 sheet yok + görünür + vurgu.
- open_item: aşama-0 kart gün şeridi (mockup 0/4) için sunucu planlı gün verisi yok — istenirse RPC işi (bu brief SQL değiştirmez).
- open_item: X-5 TAI görevi demoda yok; DM2 madde 7 yeniden koşusunda başka Ovsync görevi seçilmeli ya da vitrin yenilenmeli.
- hijyen: betikler `~/tmp/n4f4/` (`run.sh`, `w/wF4.cjs`, `mutant.sh`, `suit.sh`, `run-kaniti.sh`); arka plan işi yok (http.server `run.sh` sonunda kill+wait). Demo verisine yazma yok (salt okuma).
- progress: tamam; sıradaki adım root PNG göz kontrolü, ardından DM2 madde 1/7/ZV1b yeniden.

## Run kanıtı
(Ağır komut kancası gereği üç komut `ram-ultracode exec --class test --wait 1800 -- bash ~/tmp/n4f4/run-kaniti.sh` içinde birebir koşuldu.)

cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -6
rc: 1
```
    code: 'ERR_ASSERTION',
    actual: false,
    expected: true,
    operator: '==',
    diff: 'simple'
  }
```
(rc 1 = taban dört FAIL; `tail -6` hata ayrıntısının sonudur. Aynı koşunun özet satırları, `$HOME/tmp/n4f4/suit2.txt`:)
```
ℹ tests 2397
ℹ pass 2393
ℹ fail 4
✖ LUNA-3: canlı DEMO information_schema ↔ harita (haritasız canlı kolon = KIRMIZI)
✖ EG-7: _erteleKaydet — rpc("gorev_ertele") çağrısı + toplam_erteleme_gun ve uyari toast'ta
✖ EG-8: _erteleKaydet — toplam 0 / uyari yok → ek metin YOK (kirli süreç yok)
✖ ay ‹/› : etiket değişir, seçim korunur (kanonik sayfalama — W20 dili; bugüne-göre, tarihe sabit DEĞİL)
```

cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node scripts/etiket-tazelik.mjs 2>&1 | tail -3
rc: 1
```
  [HATALI] js/ui.js:openDet@8924 → @tablo cases (okuma), cases (tazeleme), diseases (tazeleme), dogum (okuma), drug_classes (tazeleme), drug_products (tazeleme), drugs (tazeleme), gorev_log (okuma), gorev_log (tazeleme), hayvanlar (okuma), kizginlik_log (okuma), kizginlik_log (tazeleme), tohumlama (okuma), uygulama_log (okuma), uygulama_log (tazeleme), vaccination_log (okuma), vaccination_log (tazeleme), vaccines (tazeleme)
      EKSİK: gövdede .from('hayvan_takip') var, etikette yok
payda 316 satır: DOĞRU 297 | HATALI 15 | DOGRULANAMADI 4
```

ls ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/f4/
rc: 0
```
f4-masa.json
f4-masa-madde7-gorevler.png
f4-masa-madde7-ovsync.png
f4-masa-ovsync-tam.png
f4-masa-ovsync-ust.png
f4-mobil.json
f4-mobil-madde7-gorevler.png
f4-mobil-madde7-ovsync.png
f4-mobil-ovsync-tam.png
f4-mobil-ovsync-ust.png
```
