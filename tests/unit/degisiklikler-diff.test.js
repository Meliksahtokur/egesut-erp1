'use strict';
// Değişiklikler saf katmanı — diff üretimi (G-20260913-SURUM-GECMISI kabul 4).
// TESTING-01: loadBrowserModule ile product modülü yüklenir, kaynak kopyalanmaz.
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule');

const { sandbox } = loadBrowserModule('js/degisiklikler/diff.js');
const { diffSatirlari, islemOzeti, ozetMetni, degerMetni, pkKisa } = sandbox;

const plain = v => JSON.parse(JSON.stringify(v));

test('INSERT: eski yok → tüm alanlar eklendi, eski değer null', () => {
  const out = plain(diffSatirlari(null, { id: 'h1', kupe_no: '51' }));
  assert.deepStrictEqual(out, [
    { alan: 'id', eski: null, yeni: 'h1', durum: 'eklendi' },
    { alan: 'kupe_no', eski: null, yeni: '51', durum: 'eklendi' },
  ]);
});

test('DELETE: yeni yok → tüm alanlar silindi, yeni değer null', () => {
  const out = plain(diffSatirlari({ id: 'h1', durum: 'Aktif' }, null));
  assert.deepStrictEqual(out.map(r => [r.alan, r.durum, r.yeni]), [
    ['id', 'silindi', null], ['durum', 'silindi', null],
  ]);
});

test('UPDATE: yalnız farklı alan degisti, eşit alan ayni', () => {
  const out = plain(diffSatirlari(
    { id: 'h1', kupe_no: '4019', durum: 'Aktif' },
    { id: 'h1', kupe_no: '51', durum: 'Aktif' },
  ));
  assert.deepStrictEqual(out.map(r => [r.alan, r.durum]), [
    ['id', 'ayni'], ['kupe_no', 'degisti'], ['durum', 'ayni'],
  ]);
  const kupe = out.find(r => r.alan === 'kupe_no');
  assert.strictEqual(kupe.eski, '4019');
  assert.strictEqual(kupe.yeni, '51');
});

test('UPDATE: jsonb değer anahtar sırasından bağımsız karşılaştırılır', () => {
  const out = plain(diffSatirlari(
    { id: 1, denemeler: { a: 1, b: [1, 2] } },
    { id: 1, denemeler: { b: [1, 2], a: 1 } },
  ));
  assert.strictEqual(out.find(r => r.alan === 'denemeler').durum, 'ayni');
  const out2 = plain(diffSatirlari({ x: [1, 2] }, { x: [2, 1] }));
  assert.strictEqual(out2[0].durum, 'degisti', 'dizi sırası anlamlıdır');
});

test('UPDATE: null → değer değişimdir; alan yalnız bir tarafta ise eklendi/silindi', () => {
  const out = plain(diffSatirlari({ a: null, b: 1 }, { a: 'x', c: 2 }));
  assert.deepStrictEqual(out.map(r => [r.alan, r.durum]), [
    ['a', 'degisti'], ['b', 'silindi'], ['c', 'eklendi'],
  ]);
});

test('bozuk girdi çökmez: ikisi de yoksa ya da nesne değilse boş liste', () => {
  assert.strictEqual(diffSatirlari(null, null).length, 0);
  assert.strictEqual(diffSatirlari('x', 5).length, 0);
  assert.strictEqual(diffSatirlari([1], undefined).length, 0);
});

test('HTML içeren değer olduğu gibi döner (escape çağıranın işi, saf katman markup üretmez)', () => {
  const out = plain(diffSatirlari({ n: 'a' }, { n: '<img src=x onerror=alert(1)>' }));
  assert.strictEqual(out[0].yeni, '<img src=x onerror=alert(1)>');
});

test('islemOzeti: tablo ve satır tekilleştirilir, işlem tipleri sayılır', () => {
  const rows = [
    { tablo_adi: 'dogum', satir_pk: { id: 'd1' }, islem: 'I' },
    { tablo_adi: 'hayvanlar', satir_pk: { id: 'h9' }, islem: 'I' },
    { tablo_adi: 'hayvanlar', satir_pk: { id: 'h1' }, islem: 'U' },
    { tablo_adi: 'hayvanlar', satir_pk: { id: 'h1' }, islem: 'U' }, // aynı satırın 2. sürümü
    { tablo_adi: 'gorev_log', satir_pk: { id: 'g1' }, islem: 'I' },
    { tablo_adi: 'gorev_log', satir_pk: { id: 'g2' }, islem: 'D' },
  ];
  assert.deepStrictEqual(plain(islemOzeti(rows)), {
    tablo_sayisi: 3, satir_sayisi: 5, islemler: { I: 3, U: 2, D: 1 },
  });
  assert.strictEqual(ozetMetni(islemOzeti(rows)), '3 tablo · 5 satır');
});

test('islemOzeti: composite pk anahtar sırasından bağımsız aynı satır sayılır; boş/bozuk girdi', () => {
  const rows = [
    { tablo_adi: 't', satir_pk: { a: 1, b: 2 }, islem: 'U' },
    { tablo_adi: 't', satir_pk: { b: 2, a: 1 }, islem: 'U' },
    null,
    { tablo_adi: 't', satir_pk: { a: 9 }, islem: 'X' },
  ];
  const o = plain(islemOzeti(rows));
  assert.strictEqual(o.satir_sayisi, 2);
  assert.deepStrictEqual(o.islemler, { I: 0, U: 2, D: 0 });
  assert.deepStrictEqual(plain(islemOzeti(undefined)), { tablo_sayisi: 0, satir_sayisi: 0, islemler: { I: 0, U: 0, D: 0 } });
});

test('degerMetni: null/bool/tarih/zaman damgası/nesne gösterimi', () => {
  assert.strictEqual(degerMetni(null), '—');
  assert.strictEqual(degerMetni(undefined), '—');
  assert.strictEqual(degerMetni(true), 'Evet');
  assert.strictEqual(degerMetni(false), 'Hayır');
  assert.strictEqual(degerMetni(0), '0');
  assert.strictEqual(degerMetni('2026-06-02'), '02.06.2026');
  // 14:01 UTC → 17:01 İstanbul
  assert.strictEqual(degerMetni('2026-06-02T14:01:16+00:00'), '02.06.2026 17:01');
  assert.strictEqual(degerMetni('2026-06-02T14:01:16'), '02.06.2026 14:01', 'saat dilimsiz değer olduğu gibi');
  assert.strictEqual(degerMetni({ a: 1 }), '{"a":1}');
  assert.strictEqual(degerMetni(''), '""');
  assert.strictEqual(degerMetni('Aktif'), 'Aktif');
});

test('pkKisa: tek anahtar kısaltılır, composite birleşir', () => {
  assert.strictEqual(pkKisa({ id: 'aaaaaaaa-0000-4000' }), 'aaaaaaaa');
  assert.strictEqual(pkKisa({ vaccine_id: 'v1', disease_id: 'd1' }), 'v1/d1');
  assert.strictEqual(pkKisa(null), '—');
});
