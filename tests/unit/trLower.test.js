const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { trLower } = require('../../js/utils/helpers.js');

test('trLower: bilinen Türkçe çiftler', () => {
  assert.strictEqual(trLower('İSTANBUL'), 'istanbul');
  assert.strictEqual(trLower('IĞDIR'), 'ığdır');
  assert.strictEqual(trLower('ÇÖĞÜŞ'), 'çöğüş');
});

test('trLower: idempotent (iki kez = bir kez)', () => {
  fc.assert(fc.property(fc.string(), (s) => {
    assert.strictEqual(trLower(trLower(s)), trLower(s));
  }));
});

test('trLower: çıktıda büyük I/İ kalmaz', () => {
  fc.assert(fc.property(fc.string(), (s) => {
    const out = trLower(s);
    assert.ok(!/[Iİ]/.test(out));
  }));
});
