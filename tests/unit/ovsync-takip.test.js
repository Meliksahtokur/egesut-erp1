// tests/unit/ovsync-takip.test.js
// Ovsync takip ekranı birim testleri.
// Şu an yalnız KALEM 12 (P9b) — gunFarkiEtiket saf yardımcısı.
// Kalem 11 testleri (P9, _tohumlamaGecmisSatirlari) SONRA bu dosyaya EKLENECEK
// (zarf impl-P9b-yardimci-GOREV.md: sıralı, tek dosya).
//
// İstanbul sabit UTC+3'tür (2016'dan beri kalıcı yaz saati yok) — test girişleri
// Z-suffixed verilir ki makine saat diliminden bağımsız deterministik koşsun:
// "İstanbul 23:30" = "20:30Z", "İstanbul 00:30 (ertesi gün)" = "21:30Z".
const test = require('node:test');
const assert = require('node:assert');
const helpers = require('../../js/utils/helpers.js');

// KIRMIZI adımda işlev henüz yok — TypeError değil ASSERTION hatası düşsün
// diye tüm çağrılar bu kaptan geçer (eksik-özellik hatası = beklenen kırmızı).
function cagir(...args) {
  assert.strictEqual(typeof helpers.gunFarkiEtiket, 'function',
    'gunFarkiEtiket helpers.js dışa aktarılmalı');
  return helpers.gunFarkiEtiket(...args);
}

test('gunFarkiEtiket: bugün — aynı İstanbul takvim günü', () => {
  assert.strictEqual(cagir('2026-09-30T10:00:00Z', '2026-09-30'), 'bugün'); // 13:00 İstanbul
  assert.strictEqual(cagir('2026-09-30', '2026-09-30'), 'bugün');           // saatsiz tarih
});

test('gunFarkiEtiket: dün — önceki takvim günü', () => {
  assert.strictEqual(cagir('2026-09-29T20:30:00Z', '2026-09-30'), 'dün');   // 29 23:30 İstanbul
  assert.strictEqual(cagir('2026-09-29', '2026-09-30'), 'dün');             // saatsiz tarih
});

test('gunFarkiEtiket: gece yarısı sınırı — dün 23:30 vs bugün 00:30 fark 1', () => {
  // İki an arası gerçek fark yalnız 1 SAAT; takvim günü farkı 1.
  // Milisaniye-bölümü hesabı ikisini de aynı güne koyup 'bugün' verirdi — yanlış.
  assert.strictEqual(cagir('2026-09-29T20:30:00Z', '2026-09-30'), 'dün');   // 29 23:30 İstanbul
  assert.strictEqual(cagir('2026-09-29T21:30:00Z', '2026-09-30'), 'bugün'); // 30 00:30 İstanbul
});

test('gunFarkiEtiket: UTC sınırı — UTC 21:30 = İstanbul 00:30 ERTESİ gün', () => {
  // fmtTarih'in ilk-10-karakter kesimi '2026-09-29' okuyup 'dün' derdi — tuzak.
  assert.strictEqual(cagir('2026-09-29T21:30:00Z', '2026-09-30'), 'bugün'); // 30 00:30 İstanbul
  assert.strictEqual(cagir('2026-09-29T20:59:59Z', '2026-09-30'), 'dün');   // 29 23:59:59 İstanbul
});

test('gunFarkiEtiket: N gün önce — 1 kısaltması yalnız dünde', () => {
  assert.strictEqual(cagir('2026-09-15', '2026-09-30'), '15 gün önce');
  assert.strictEqual(cagir('2026-09-28', '2026-09-30'), '2 gün önce');
});

test('gunFarkiEtiket: ileri tarih — N gün sonra', () => {
  assert.strictEqual(cagir('2026-10-05', '2026-09-30'), '5 gün sonra');
});

test('gunFarkiEtiket: ay/yıl devri — takvim aritmetiği taşınmayı doğru sayar', () => {
  assert.strictEqual(cagir('2026-10-01', '2026-09-30'), '1 gün sonra');
  assert.strictEqual(cagir('2027-01-01', '2026-12-31'), '1 gün sonra');
  assert.strictEqual(cagir('2026-09-01', '2026-09-30'), '29 gün önce');
});
