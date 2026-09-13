'use strict';
// Değişiklikler saf katmanı — Türkçe tablo/alan etiketleri (G-20260913-SURUM-GECMISI kabul 4).
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule');

const { sandbox } = loadBrowserModule('js/degisiklikler/etiketler.js');
const { tabloEtiketi, alanEtiketi, islemEtiketi, tabloSecenekleri } = sandbox;

test('tabloEtiketi: bilinen iş tabloları Türkçe', () => {
  assert.strictEqual(tabloEtiketi('hayvanlar'), 'Hayvan');
  assert.strictEqual(tabloEtiketi('dogum'), 'Doğum');
  assert.strictEqual(tabloEtiketi('stok_hareket'), 'Stok hareketi');
  assert.strictEqual(tabloEtiketi('cases'), 'Vaka');
});

test('tabloEtiketi: bilinmeyen tablo insanlaştırılır, çökmez', () => {
  assert.strictEqual(tabloEtiketi('yeni_tablo_adi'), 'Yeni tablo adi');
  assert.strictEqual(tabloEtiketi('islem_x'), 'İslem x', 'Türkçe büyük İ');
  assert.strictEqual(tabloEtiketi(''), '—');
  assert.strictEqual(tabloEtiketi(null), '—');
  assert.strictEqual(tabloEtiketi('__proto__'), 'Proto', 'prototip anahtarı etiket sözlüğünden sızmaz');
});

test('alanEtiketi: tabloya özgü etiket ortak etiketi ezer', () => {
  assert.strictEqual(alanEtiketi('hayvanlar', 'kupe_no'), 'Küpe no');
  assert.strictEqual(alanEtiketi('hayvanlar', 'devlet_kupe'), 'Devlet küpesi');
  assert.strictEqual(alanEtiketi('dogum', 'tarih'), 'Doğum tarihi');
  assert.strictEqual(alanEtiketi('tohumlama', 'tarih'), 'Tohumlama tarihi');
  assert.strictEqual(alanEtiketi('kizginlik_log', 'tarih'), 'Tarih', 'özel yoksa ortak');
});

test('alanEtiketi: ortak alanlar tablo bağımsız', () => {
  assert.strictEqual(alanEtiketi('gorev_log', 'hayvan_id'), 'Hayvan');
  assert.strictEqual(alanEtiketi('cases', 'animal_id'), 'Hayvan');
  assert.strictEqual(alanEtiketi('bilinmeyen', 'created_at'), 'Oluşturulma');
  assert.strictEqual(alanEtiketi('stok', 'updated_at'), 'Güncellenme');
});

test('alanEtiketi: bilinmeyen alan insanlaştırılır; boş/tuhaf girdi çökmez', () => {
  assert.strictEqual(alanEtiketi('hayvanlar', 'yeni_kolon'), 'Yeni kolon');
  assert.strictEqual(alanEtiketi(undefined, undefined), '—');
  assert.strictEqual(alanEtiketi('hayvanlar', 'constructor'), 'Constructor');
  assert.strictEqual(alanEtiketi('toString', 'id'), 'Kayıt no');
});

test('islemEtiketi: I/U/D Türkçe, bilinmeyen kod aynen', () => {
  assert.strictEqual(islemEtiketi('I'), 'Ekleme');
  assert.strictEqual(islemEtiketi('U'), 'Güncelleme');
  assert.strictEqual(islemEtiketi('D'), 'Silme');
  assert.strictEqual(islemEtiketi('X'), 'X');
  assert.strictEqual(islemEtiketi(null), '—');
});

test('tabloSecenekleri: tekil kodlar, Türkçe alfabetik sıra', () => {
  const s = JSON.parse(JSON.stringify(tabloSecenekleri()));
  const kodlar = s.map(x => x.kod);
  assert.strictEqual(new Set(kodlar).size, kodlar.length);
  assert.ok(kodlar.includes('hayvanlar') && kodlar.includes('stok_hareket'));
  const etiketler = s.map(x => x.etiket);
  const sirali = [...etiketler].sort((a, b) => a.localeCompare(b, 'tr'));
  assert.deepStrictEqual(etiketler, sirali);
});
