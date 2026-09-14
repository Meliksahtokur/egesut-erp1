// tests/unit/geri-al-rehber.test.js
// L4-W2 — sıralı rehber hazırlığı (zarf C; K1: çıkımaz engel YOK).
//
// Sözleşme: sirali_rehber EN YENİ ÖNCE gelir ("önce 5'i, sonra 4'ü geri al");
// _dgRehberHazirla savunmacı olarak zaman azalan sıralar, 1..N numaralar,
// zamansız satırı sonda kendi sırasında tutar. SAF — DOM yazmaz.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const etiketSandbox = loadBrowserModule('js/degisiklikler/etiketler.js', { extra: {} });
const { sandbox, exposed } = loadBrowserModule('js/degisiklikler/degisiklikler.js', {
  extra: { registerActions: () => {}, tabloEtiketi: etiketSandbox.exposed.tabloEtiketi ?? etiketSandbox.sandbox.tabloEtiketi, islemEtiketi: etiketSandbox.exposed.islemEtiketi ?? etiketSandbox.sandbox.islemEtiketi },
  expose: ['_dgRehberHazirla', '_dgKartBaslik', '_dgRehberTokenlari'],
});
const { _dgRehberHazirla, _dgKartBaslik, _dgRehberTokenlari } = exposed;

const R = (id, zaman, ozet) => ({ hedef: { tablo: 'tohumlama', pk: id, txid: id }, zaman, ozet });

test('rehber sırası: en yeni önce + 1..N numara', () => {
  const girdi = [
    R('a', '2026-09-13T12:00:00+03:00', 'Tohumlama kaydı'),
    R('c', '2026-09-13T18:30:00+03:00', 'Doğum kaydı'),
    R('b', '2026-09-13T15:45:00+03:00', 'Tohumlama sonucu (Gebe)'),
  ];
  const cikti = _dgRehberHazirla(girdi);
  assert.strictEqual(JSON.stringify(cikti.map(r => r.no)), JSON.stringify([1, 2, 3]));
  assert.strictEqual(JSON.stringify(cikti.map(r => r.hedef.pk)), JSON.stringify(['c', 'b', 'a'])); // en yeni önce
  assert.strictEqual(cikti[0].ozet, 'Doğum kaydı');
});

test('rehber: zamansız satır sonda, kendi sırasında kalır', () => {
  const cikti = _dgRehberHazirla([
    R('a', '2026-09-13T12:00:00+03:00', 'zamanlı'),
    R('x', '', 'zamansız-1'),
    R('y', '', 'zamansız-2'),
  ]);
  assert.strictEqual(JSON.stringify(cikti.map(r => r.hedef.pk)), JSON.stringify(['a', 'x', 'y']));
  assert.strictEqual(JSON.stringify(cikti.map(r => r.no)), JSON.stringify([1, 2, 3]));
});

test('rehber: boş/bozuk giriş güvenli — hedefsiz satır düşürülür', () => {
  assert.strictEqual(_dgRehberHazirla(null).length, 0);
  assert.strictEqual(_dgRehberHazirla(undefined).length, 0);
  assert.strictEqual(_dgRehberHazirla([]).length, 0);
  const cikti = _dgRehberHazirla([{ zaman: '2026-09-13T12:00:00+03:00' }, R('a', '2026-09-13T13:00:00+03:00', 'x')]);
  assert.strictEqual(cikti.length, 1);
  assert.strictEqual(cikti[0].hedef.pk, 'a');
});

test('rehber: neden_dahil_degil metni aynen taşınır', () => {
  const cikti = _dgRehberHazirla([Object.assign(R('a', '2026-09-13T18:30:00+03:00', 'Doğum kaydı'), { neden_dahil_degil: 'bu geri almaya bağlı' })]);
  assert.strictEqual(cikti[0].neden, 'bu geri almaya bağlı');
});

// ── L4-04 (onarım turu): rehber satırı TEKİL hedef seviyesiyle çağrılır ──
// seviye 'satir' — 'islem' DEĞİL: 'islem' seviyesi tablo/pk'yi yok sayıp çok
// satırlı tx'in BÜTÜN degisim_log satırlarını geri alırdı (luna L4-04).
test('L4-04 — rehber tokenları seviye \'satir\' taşır (islem asla), hedef kesin', () => {
  const tokenlar = _dgRehberTokenlari([
    R('a', '2026-09-13T12:00:00+03:00', 'Tohumlama kaydı'),
    R('c', '2026-09-13T18:30:00+03:00', 'Doğum kaydı'),
  ]);
  assert.strictEqual(tokenlar.length, 2);
  tokenlar.forEach(t => {
    assert.strictEqual(t.seviye, 'satir', 'tekil hedef — islem seviyesi YASAK');
    assert.ok(!('alan' in t.hedef), 'alan seviyesi değildir');
    assert.strictEqual(t.hedef.tablo, 'tohumlama');
    assert.ok(t.hedef.pk && t.hedef.txid, 'hedef (tablo,pk,txid) tam gelir');
    assert.ok(t.etiket && typeof t.etiket === 'string', 'etiket işlem dilli');
  });
});

test('L4-04 — bozuk/boş girdide token üretimi güvenli', () => {
  assert.strictEqual(_dgRehberTokenlari(null).length, 0);
  assert.strictEqual(_dgRehberTokenlari([]).length, 0);
});

test('sandbox: degisiklikler.js modülü aksiyon kaydıyla yüklenir', () => {
  assert.strictEqual(typeof sandbox.dgGeriAlAkisi, 'function');
  assert.strictEqual(typeof sandbox.dgGeriAlFromEntry, 'function');
});

// ── Liste kartı başlığı — işlem dili (L4 entegrasyon dokunuşu, plan §5) ─────
test('kart başlığı: işlem dili; ham özet değil', () => {
  assert.strictEqual(_dgKartBaslik({ baslik: 'padoklar (1)', islemler: { I: 1 } }, null), 'Padok ekleme');
  assert.strictEqual(_dgKartBaslik({ baslik: 'tohumlama (1)', islemler: { U: 1 } }, { geri_alma: { bilet: 'x' } }), 'Tohumlama güncelleme — geri alındı');
  assert.strictEqual(_dgKartBaslik({ baslik: 'gorev_log (2)', islemler: { I: 1, U: 1 } }, null), 'Görev değişikliği');
  assert.strictEqual(_dgKartBaslik({ baslik: '?? (1)', islemler: {} }, null), '?? (1)'); // bilinmeyen biçim aynen geçer (savunmacı)
});
