# k7 TB-3 DONE — ovsync render zaman aşımı + hata dalı

Worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi (dal ovsync-sonrasi; commit/add YOK)

## Değişen dosyalar
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/js/ui.js (+35/-13)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/tests/unit/ovsync-render-zamanasimi.test.js (yeni, 5 test)
(`git diff --stat` çıktısında görünen ground_truth.sql ve tests/e2e/ovsync-takip.spec.js farkları BANA AİT DEĞİL — başka kalem/koltuk.)

## Değişen fonksiyonlar (js/ui.js)
- `loadOvsyncDash(zamanAsimiMs)` satır 619 (taze + bayat dalları bağlam başarısızsa hata HTML'i basar)
- `OVSYNC_ZAMAN_ASIMI_MS=15000` satır 880 (yeni sabit)
- `_ovsyncBaglamYukle(zamanAsimiMs)` satır 889 (Promise.race zaman aşımı; reddedilme → false; true/false döner)
- `_ovsyncBaglamHataHtml()` satır 910 (yeni; mesaj + Tekrar Dene)

## Kırmızı (hata dalı olmadan, ui.js HEAD)
[VERIFIED] 5 testten 4 FAIL: (i) "loadOvsyncDash 1000 ms içinde dönmedi (süresiz spinner)", (ii) reddedilince boş bağlamla KPA "bilinmiyor" render (hata yok), (iii) aynı askı, (v) sabit yok. (iv) sağlıklı-yol regresyon koruması geçti.
(İlk koşumda bekçisiz test 60 sn askıda kaldı = hatanın kendisi; sonra bekçi eklendi.)

## Yeşil
[VERIFIED] node --test tests/unit/ovsync-render-zamanasimi.test.js → 5/5 pass. node --check js/ui.js OK. git diff --check OK.

## Tüm süit
[VERIFIED] 1496 toplam / 1494 pass / 2 fail (baseline 1491/1489/2 + 5 yeni). 2 kırmızı baseline ile aynı: tests/unit/degisiklikler-etiketler.test.js (ay ‹/› + bc-tarih takvim) ve LUNA-3 canlı DEMO information_schema. Yeni kırmızı yok. HEAD ui.js ile kontrol: 1496/1490/6 (6 = 2 baseline + 4 benim kırmızı).

## Tasarım seçimleri
- Hata dalı mevcut `loadDash` kalıbını yeniden kullanır (`empty` + `btn btn-o` + "Tekrar Dene"); yeni stil yok. Etiket "Tekrar Dene" (projenin mevcut idiom'u), görev metnindeki "Yeniden dene" değil.
- Geç gelen sonuç: YOK SAYILIR (ekranı ezmez, `window._ovsyncBaglam` kurulmaz). Gerekçe: kullanıcıya hata gösterildi; sessizce sonradan render değişmesi tutarsız; Tekrar Dene taze okur. Bayrak (`vazgecildi`) + `oku.catch` ile unhandled rejection yok; zamanlayıcı finally'de temizlenir.
- Davranış değişikliği: eski kod IDB reddinde sessizce boş bağlamla render ediyordu (satırlar "bilinmiyor"); artık hata dalı (görev talimatı "reddedilirse aynı hata dalı").
- `loadOvsyncDash(zamanAsimiMs)`: sayı değilse (onclick/olay argümanı) varsayılan 15 sn.
- Kapsam dışı not [INFERRED]: `ovsyncTakipGetir` çağrısının kendisi (ağ) askıda kalırsa aynı spinner riski var; bu kalemde ele alınmadı (api.js timeout'una bağlı).

## index.html ?v= damgası
DAMGA GEREKLİ (JS değişti). Ben değiştirmedim; mimar sonda tek seferde verir.

## Tarayıcı yürüyüşü için test maddesi önerisi
1. Demo, Ovsync takip sayfası açılır → normal render (KPA şeridi + bölümler), hata kutusu YOK.
2. DevTools'ta IndexedDB okumasını askıya al (ör. `indexedDB.open` / `getData` override ile asla çözülmeyen promise) → sayfa aç → ~15 sn sonra spinner kaybolur, "⚠️ Yerel veri okunamadı — takip ekranı hazırlanamadı" + "Tekrar Dene" görünür.
3. Override kaldırılıp "Tekrar Dene" tıklanır → sayfa normal render olur, hata kutusu kaybolur.
4. (Beklenen) 15 sn dolmadan veri gelirse hata hiç görünmez.

SONUC: TAMAM
