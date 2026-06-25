const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { trLower } = require('../../js/utils/helpers.js');

// ── Bilinen Türkçe yer adları / özel karakterler ──────────────
test('trLower: bilinen Türkçe çiftler', () => {
  assert.strictEqual(trLower('İSTANBUL'), 'istanbul');
  assert.strictEqual(trLower('IĞDIR'), 'ığdır'); // Türkçe locale: I + Ğ → ığ (noktasız)
  assert.strictEqual(trLower('ÇÖĞÜŞ'), 'çöğüş');
  assert.strictEqual(trLower('ŞIŞLI'), 'şışlı'); // Ş + I + Ş + L + I → ı korunur (I → ı)
});

// ── Noktalı ı doğru yerlerde ─────────────────────────────────
test('trLower: noktalı ı doğru yerlerde', () => {
  assert.strictEqual(trLower('CI'), 'cı'); // Türkçe yer adı CI lower = cı (noktasız)
  assert.strictEqual(trLower('ÖĞRENCI'), 'öğrencı'); // aynı kural
  assert.strictEqual(trLower('CIN'), 'cın');
  assert.strictEqual(trLower('AIB'), 'aıb');
  assert.strictEqual(trLower('IĞDIR'), 'ığdır'); // IĞ → ığ (noktasız)
});

// ── İ (büyük noktalı İ) her zaman i olur ─────────────────────
test('trLower: İ (büyük noktalı) her zaman i olur', () => {
  assert.strictEqual(trLower('İ'), 'i');
  assert.strictEqual(trLower('İSTANBUL'), 'istanbul');
  assert.strictEqual(trLower('İĞNE'), 'iğne'); // İĞ → iğ (noktalı, doğru)
});

// ── İdempotent ───────────────────────────────────────────────
test('trLower: idempotent (iki kez = bir kez)', () => {
  fc.assert(fc.property(fc.string(), (s) => {
    assert.strictEqual(trLower(trLower(s)), trLower(s));
  }));
});

// ── Çıktıda büyük I/İ kalmaz ─────────────────────────────────
test('trLower: çıktıda büyük I/İ kalmaz', () => {
  fc.assert(fc.property(fc.string(), (s) => {
    const out = trLower(s);
    assert.ok(!/[Iİ]/.test(out), `out=${out}`);
  }));
});

// ── Property: I+I kombinasyonları idempotent + doğru ─────────
test('trLower: I/i adjacency property', () => {
  // fc.stringMatching ile 'I' ve 'i' içeren string üret, trLower sonrası büyük harf kalmamalı
  fc.assert(fc.property(
    fc.stringMatching(/^[a-zA-ZçğıöşüÇĞİÖŞÜIi]{0,30}$/),
    (s) => {
      const out = trLower(s);
      // out'ta büyük I/İ yok
      assert.ok(!/[Iİ]/.test(out), `uppercase survived: ${out}`);
      // idempotent
      assert.strictEqual(trLower(out), out);
    }
  ));
});

// ── Search use case: case-insensitive eşleşme ────────────────
test('trLower: case-insensitive search (gerçek kullanım)', () => {
  // arama: "ığdır" → "IĞDIR", "ığdır", "Iğdır", "ığdir" hepsi eşleşmeli
  const needle = 'ığdır';
  const haystacks = ['IĞDIR', 'ığdır', 'Iğdır', 'ığdır'.toLowerCase(), 'Iğdır'.toUpperCase()];
  for (const h of haystacks) {
    assert.ok(trLower(h).includes(needle), `expected "${h}".includes("${needle}"), got trLower="${trLower(h)}"`);
  }
});
