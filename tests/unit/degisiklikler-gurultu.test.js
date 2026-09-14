// tests/unit/degisiklikler-gurultu.test.js
// L4-W2 — gürültü ayracı + öne çıkan alan sırası (zarf B; plan §5).
//
// Sözleşme:
//   1. Teknikal satırlar (teknikal_mi) ve uygulama-dışı kaynaklar
//      (app_name ≠ 'egesut-web') varsayılan GİZLİ; sayaç FİLTRE ÖNCESİ sayar.
//   2. Boş değerli diff satırı gizlenir (iki taraf da null/'').
//   3. dgAlanSirala: öne çıkan alanlar önce (liste sırasıyla), kalanlar
//      mevcut sırasında; kayıtsız tabloda giriş sırası korunur.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const diff = loadBrowserModule('js/degisiklikler/diff.js', {
  expose: ['dgUygulamaDisiMi', 'dgTeknikMi', 'dgGurultuAyir', 'dgAlanBosMu'],
}).exposed;
const etk = loadBrowserModule('js/degisiklikler/etiketler.js', {
  expose: ['DG_ONE_CIKAN_ALANLAR', 'oneCikanAlanlar', 'dgAlanSirala'],
}).exposed;

const { dgUygulamaDisiMi, dgTeknikMi, dgGurultuAyir, dgAlanBosMu } = diff;
const { DG_ONE_CIKAN_ALANLAR, oneCikanAlanlar, dgAlanSirala } = etk;

test('uygulama-dışı tespiti: app_name eksik ya da egesut-web → değil', () => {
  assert.strictEqual(dgUygulamaDisiMi({ app_name: 'egesut-web' }), false);
  assert.strictEqual(dgUygulamaDisiMi({ app_name: 'harici-panel' }), true);
  assert.strictEqual(dgUygulamaDisiMi({ rol: 'sahip' }), false);
  assert.strictEqual(dgUygulamaDisiMi(null), false);
  assert.strictEqual(dgUygulamaDisiMi(undefined), false);
});

test('teknik satır tespiti: teknikal_mi bayrağı', () => {
  assert.strictEqual(dgTeknikMi({ teknikal_mi: true }), true);
  assert.strictEqual(dgTeknikMi({ teknikal_mi: false }), false);
  assert.strictEqual(dgTeknikMi({}), false);
  assert.strictEqual(dgTeknikMi(null), false);
});

test('dgGurultuAyir: gizli sayacı filtre öncesi tam listeden gelir', () => {
  const liste = [
    { kaynak: { app_name: 'egesut-web' } },
    { kaynak: { app_name: 'harici-panel' } },
    { kaynak: { app_name: 'harici-panel' } },
    { kaynak: { app_name: 'egesut-web' } },
  ];
  // üretimdeki gibi: liste öğesi {kaynak} sarmalıdır → adaptörle çağrılır
  const { gorunen, gizli, gizliSayi } = dgGurultuAyir(liste, r => dgUygulamaDisiMi(r.kaynak));
  assert.strictEqual(gorunen.length, 2);
  assert.strictEqual(gizli.length, 2);
  assert.strictEqual(gizliSayi, 2);
  // vm sandbox prototip farkı: eleman kimliği JSON karşılaştırmasıyla
  assert.strictEqual(JSON.stringify(gizli.map(x => x.kaynak.app_name)), JSON.stringify(['harici-panel', 'harici-panel']));
});

test('dgGurultuAyir: boş liste ve testsiz çağrı güvenli', () => {
  const bos = dgGurultuAyir([], dgTeknikMi);
  assert.strictEqual(bos.gorunen.length, 0);
  assert.strictEqual(bos.gizli.length, 0);
  assert.strictEqual(bos.gizliSayi, 0);
  const { gorunen, gizliSayi } = dgGurultuAyir([{ a: 1 }]);
  assert.strictEqual(gorunen.length, 1);
  assert.strictEqual(gizliSayi, 0);
});

test('boş değer satırı: iki taraf da null/\'\' ise gizlenir', () => {
  assert.strictEqual(dgAlanBosMu({ eski: null, yeni: null }), true);
  assert.strictEqual(dgAlanBosMu({ eski: '', yeni: null }), true);
  assert.strictEqual(dgAlanBosMu({ eski: null, yeni: 'değer' }), false);   // ekleme
  assert.strictEqual(dgAlanBosMu({ eski: 'eski', yeni: '' }), false);      // temizleme
  assert.strictEqual(dgAlanBosMu(null), true);
});

test('dgAlanSirala: öne çıkan alanlar önce, kalanlar mevcut sırasında', () => {
  const cikti = dgAlanSirala('tohumlama', ['sonuc', 'id', 'tarih', 'sperma', 'notlar']);
  assert.strictEqual(JSON.stringify(cikti), JSON.stringify(['tarih', 'sperma', 'sonuc', 'id', 'notlar']));
});

test('dgAlanSirala: öne çıkan listede olmayan alan hiç gelmezse sorun yok', () => {
  const cikti = dgAlanSirala('tohumlama', ['notlar', 'id']);
  assert.strictEqual(JSON.stringify(cikti), JSON.stringify(['notlar', 'id']));
});

test('dgAlanSirala: kayıtsız tabloda giriş sırası aynen (yeni dizi)', () => {
  const g = ['b', 'a'];
  const cikti = dgAlanSirala('bilinmeyen_tablo', g);
  assert.strictEqual(JSON.stringify(cikti), JSON.stringify(['b', 'a']));
  assert.notStrictEqual(cikti, g, 'giriş dizisi mutasyona uğramamalı');
});

test('one-cikan haritası: her tablo 3-6 alan, boş liste yok', () => {
  const tablolar = Object.keys(DG_ONE_CIKAN_ALANLAR);
  assert.ok(tablolar.length >= 10, 'kapsam: en az 10 tablo');
  for (const t of tablolar) {
    const s = oneCikanAlanlar(t);
    assert.ok(s.length >= 3 && s.length <= 6, t + ' alan sayısı 3-6 arası olmalı: ' + s.length);
  }
});
