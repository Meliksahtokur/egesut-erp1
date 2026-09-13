# W3 — F3 Teslim: Kopyaların kanonik çekirdeğe birleştirilmesi (G-20260913-TARIH-SECICI)

## 1. Dal + son commit

- Dal: `agent/tarih-secici-standardi-W3`
- Kod teslim commit'i: **`243e0ae`** (feat(tarih): F3 — 6 dosya, +320/−189)
- Son commit: bu raporu taşıyan commit (kendi SHA'sını içeremez; ekranda
  raporlanır).
- Taban: `3850209` (agent/tarih-secici-standardi ucu — F1+F2 merge'li; W3 dalı
  buradan açıldı, kod commit'i + bu rapor commit'i eklendi).

## 2. Değişen dosyalar (git diff --stat, taban 3850209)

```text
 index.html                       |  46 ++++++-------
 js/forms.js                      | 139 +++++++++++----------------------------
 js/ui.js                         |  40 ++++++-----
 js/utils/handlers.js             |   2 +-
 tests/unit/tarih-saf.test.js     | 115 ++++++++++++++++++++++++++++++++
 tests/unit/vaka-toplu-ac.test.js | 128 ++++++++++++++++++++++-------------
 6 files changed, 284 insertions(+), 186 deletions(-)
```

Commit dışı bilinçli bırakılan: `.ss/tarih-secici-standardi-W3-BOARD.md`
(worker panosu, write manifest dışı — F1/W1 uygulamasıyla aynı).

**Manifest sapması (beyan):** `js/utils/handlers.js` goal write_manifest'inde
yoktur; ancak `handlers.js:228` bcTarihTakvimAc'ın TEK prod çağırıcısıdır ve
görev zarfı "Find ALL its callers (grep before touching), repoint them"
buyruğu verir. Düzenlemeden bırakmak kırık buton (undefined çağrı) demekti.
Tek satır repoint yapıldı (rota anahtarı `bc-tarih-takvim` değişmedi —
index.html data-action'ı ve W21 testi aynı kalır). Root isterse manifest'e
işlensin.

## 3. Test kanıtları

Komut: `node --test --test-reporter=tap tests/unit/*.test.js`
(ortam: worktree `node_modules` → ana checkout sembolik bağı; F1 notu aynen)

| Aşama | tests | pass | fail |
|---|---|---|---|
| Baseline (temiz dal, hiçbir değişiklik öncesi) | 824 | 823 | 1 — bilinen kırmızı `tests/unit/gecmis-pipeline.test.js` `_gmGroupHtml` (zarfta tanımlı) |
| Final (tüm F3 değişiklikleri + review fixleri sonrası) | 831 | 830 | 1 — AYNI bilinen kırmızı; **+7 yeni test, sıfır yeni kırmızı** |

Tek kırmızı final koşusunda: `not ok 217 - _gmGroupHtml: <details + <summary…`
(gecmis-pipeline — baseline'da da kırmızıydı, kapsam dışı, dokunulmadı).
Review'in kök-neden ipucu (rapor eden ajan): o test gerçek saatten 'DÜN'
hesaplıyor (`js/gecmis.js:261` `_gmGroupLabel`, `todayKey`'i yok sayıyor) —
yani **tarihe-bağlı test** sınıfı; 2026-09-10'da kendiliğinden kızarmış.
F3 kapsamı dışıdır; sahibine/lead'e ayrı iş olarak işaretlenir.

**kapaliGun/temizlenebilir DOM testi (F1 carry-over):** 7 yeni test,
`tests/unit/tarih-saf.test.js` sonunda — **35/35 yeşil** (dosyanın tamamı).
Yöntem beyanı: TESTING-01 `loadBrowserModule` vm-sandbox seçildi (Playwright
DEĞİL); gerçek `js/tarih/tarih.js` saf katmanı `extra` ile enjekte edilir,
`js/ui.js` aynı document stub'ına yüklenir. Kilitlediği davranış:
kapalı hücre onclick'siz + not-allowed; kapalı hücreye tık seçimi DEĞİŞTİRMEZ;
kapalı seçimle Onayla onSec'e ulaşmaz (kutu açık kalır + satır içi hata);
kapalı gün el girişiyle de seçilemez (yazdığı korunur);
`temizlenebilir:true` → Temizle + Onayla → `onSec(null)`;
`temizlenebilir:false` → Temizle hiç çizilmez; **plumbing**:
`tarihAlaniTakvimAc` fonksiyon-`kapaliGun`'u bileşene iletir, fonksiyon
olmayanı null'a düşürür (F2 carry-over kilidi).

**Gate grep (zarfın istediği ham çıktı):**

```
$ grep -n "bcTarihTakvim" index.html js/*.js
(çıktı yok — EXIT=1)
```

Ek: repoda `bcTarihTakvim` stringi hiçbir .js/.html'de kalmadı (tests dahil;
`grep -rn --exclude-dir=node_modules` boş). `bc-tarih-takvim` (kısa çizgili
rota anahtarı) index.html:1185 + handlers.js:228'de bilinçli kalır — UI
çapasıdır, sembol değil; W21 testi bunu pinler.

## 4. Çağırıcı repoint tablosu

| Eski sembol/çağrı | Yeni çağrı | Dosya | Davranış delta'sı |
|---|---|---|---|
| `bcTarihTakvimAc()` (rota `bc-tarih-takvim`) | `bcTarihSeciciAc()` → `tekTarihTakvimAc({baslik:'📅 Tedavi Tarihi — Takvimden Seç', deger: bcTarihDeger()||bugun(), min: bugun(), max: dFwd(bugun(),365), onSec: yaz+ipucu+plan})` | js/utils/handlers.js:228 | (a) açılış ayı değerin ayı (eski hep bugünün ayı); (b) aralık dışı tık sessiz yoksayılır (hücre zaten kapalı çizilir; eski toast atardı). Diğer her şey korunur: min=bugun, maks=+365 (dahil), Temizle yok, Onayla bcTarihYaz+ipucu+plan |
| index.html `data-action="bc-tarih-takvim"` | DEĞİŞMEDİ (rota anahtarı UI çapasıdır) | index.html:1185 | yok |
| Test: `sb.bcTarihTakvimAc/Sec/Onayla/AyDegistir/Kapat` (4 it) | `sb.bcTarihSeciciAc()` + `sb.tekTarihTakvim*` (sandbox'a ui.js zincirleme) | tests/unit/vaka-toplu-ac.test.js:2391+ | yukarıdaki iki delta testte pinoledi; seçim/onay/ipucu/plan sözleşme iddiaları AYNEN korundu |
| Test: handler regex | `bcTarihSeciciAc` regexi | tests/unit/vaka-toplu-ac.test.js:2513 | yok |
| (komşu) `bcTarihSecimEkle` | KALDI (silinmedi) | js/forms.js:988 | prod çağırıcısı kalmadı (eski bileşenin SAF doğrulayıcısıydı) ama vaka-toplu-ac.test.js:2267+ hâlâ pinler — test-kilitli SAF yardımcı; zarf kapsamında olmadığından silinmedi (bkz. §8) |

## 5. Izgara sözleşmesi durumu

**Komşu-ay hücresi benimsenmedi — `ayIci:false` genişlemesi YAPILMADI.**
Neden: iki çoklu-seçim yüzey de komşu-ay hücresi gerektirmiyor —
`bcTakvimAyGosterim` sözleşmesi "komşu-ay hücresi ÜRETİLMEZ (disiMi daima
false)" diye pinli (8 test) ve `caseGunModalRender` seçimleri ay-İÇİ Set'te
tutuyor. F1'in varsayılanı korunur: ay-dışı konum = `null` (tarihAyIzgara
dokunulmadı; grid unit testlerinde değişiklik gerekmedi). Çekirdek sözleşmesi
bu teslimde DEĞİŞMEDİ.

## 6. ?v= damga durumu

- Yeni ortak değer: **`20260913-16`** (F2'nin `20260913-15` +1 stili).
- `grep -o 'v=[0-9]\{8\}-[0-9]*' index.html | sort | uniq -c` →
  `23  v=20260913-16` — TEK değer; 22 script + 1 manifest.json link dahil
  tüm damgalı kaynaklar aynı commit'te bump edildi; kısmi bump yok.
- Damga koruma testleri yerinde güncellendi (W18 testi -16 regex + geçmiş
  satırı; W21 manifest testi -16 + eski-listeye `20260913-15` eklendi).

## 4b. Üçüncü davranış delta'sı (review'in görünür kıldığı — kabul belgesi)

Eski W20 Onayla, saklanan değeri yeniden doğrulamadan geri yazıyordu;
kanonik Onayla seçimi min/max'e tabi tutar. Örnek: oturum gece yarısını
geçirip modal açılırsa ve pikli değer artık min'in altında kaldıysa, Onayla
artık sessizce YAZMAZ — satır içi '…tarihinden önce olamaz' verir, modal açık
kalır. Erişilmesi zor bir yoldur (`_bcTarihIso` oturumluk, kalıcılık yok) ve
iyileştirme niteliğindedir (yarım-geçersiz durumun yazılmasını engeller); iki
beyanlı delta'ya ek olarak bilinçli kabul edilir.

## 7. Review notu

`bulgu: builtin code-reviewer subagent (kendi diff'ime) — KRİTİK 0, ÖNEMLİ 0,
6 DÜŞÜK; "merge-ready, üretim kodunda kusur yok" değerlendirmesi. Düşüklerin
3'ü teslim ÖNCE giderildi: (1) sayfalama testi sabit '2026-09-26' pinine
göreli-tarihe (bugün+13, dinamik etiket hesabı) çevrildi — tarihe-bağlı-kırmızı
sınıfı önlandı; (2) 'geçmiş gün hücresi çizilir' iddiası ayın-1'i günlerinde
anlamsızlaşabileceği için koşullu not-allowed kanıtıyla güçlendirildi;
(3) F2 carry-over plumbing (tarihAlaniTakvimAc kapaliGun iletimi) için ayrı
bir test eklendi (+7. test). Kalan 3 düşük beyan/aşağı-ışınlama: üçüncü
davranış delta'sı belgelendi (bkz. §4b), bcTarihSecimEkle silme
kararı F4/lead'e bırakıldı, .ss/ commit dışı bırakıldı (açık dosya staging).
Review ayrıca ızgara birleştirmesini 1900-2100 her ay için eski new Date
matematiğine karşı ampirik doğruladı (0 uyumsuzluk; tek sapma 1-3 yıllarında
— eski kod orada YANLIŞTI, yeni çekirdek düzeltir) ve XSS yönünden yeni
dinamik enterpolasyon bulmadı.`

## 8. Açık riskler / ertelenenler

1. **`bcTarihSecimEkle` artık prod-öksüzü** (yalnız testler çağırıyor).
   Test-kilitli SAF kod — F3 zarfı yalnız `bcTarihTakvim*` kaldırmayı
   buyurduğu için silinmedi. F4 (guard test + docs) ya da lead kararıyla
   silinebilir; karar köşesinde bırakıldı.
2. **caseGunModalRender ay etiketi artık statik TR adlarından** (`TARIH_AY_ADLARI`)
   — çıktı birebir aynı ('Eylül 2026'); eski `toLocaleString('tr-TR')` zaten
   TR basıyordu, kullanıcıya görünür fark yok. Hafta başlıkları da tek
   kaynağa (TARIH_GUN_ADLARI) bağlandı — içerik birebir aynı.
3. **Yıl 1..9999 dışı sayfalama**: eski kod JS Date tuhaflığıyla çöp ama
   çökmeyen ızgara basardı; yeni kod boş ızgara basar (crash yok). Pratikte
   erişilemez (binlerce tık); test pinlemez.
4. **GitNexus indeksi bayat**: `tekTarihTakvimAc`/`bcTarihSeciciAc` indekste
   yok (F1'de bilinen kısıt) — doğrulama LSP + grep ile yapıldı; impact
   `bcTakvimAyGosterim` için gerçek koşuldu (CRITICAL — W13-pinned akışı
   besler; dönüş sözleşmesi birebir korunarak hafifletildi, 228 test yeşil).
   PreToolUse `blast-radius-check.sh` bu worktree'de aktif çıktı; gerçek
   analiz sonrası işaret tazelendi (F1/W1 uygulaması).
5. Ortam: worktree `node_modules` sembolik bağı yeniden kuruldu (F1 notu
   aynen geçerli; test hattı ana checkout'un node_modules'ını salt-okunur
   kullanır).
6. **Tarihe-bağlı test hijyeni (review kaynaklı):** F3'ün kendi testleri
   göreli tarihe çevrildi (bugün+13 seçim, dinamik etiket; koşullu hücre
   iddiası). Bilinen kırmızının kök nedeni de aynı sınıftır (§3'teki ipucu) —
   repo genelinde bu sınıfın temizliği ayrı iş; F3 dokunmadı.
