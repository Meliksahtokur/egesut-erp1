const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { dAgo, dFwd } = require('../../js/utils/helpers.js');

// dAgo(n) bugünden n gün önce (tek argüman), dFwd(base, n) base+'n gün' (iki argüman)

test('dAgo: sınır — 0 gün = bugün (YYYY-MM-DD)', () => {
  const today = new Date().toISOString().split('T')[0];
  assert.strictEqual(dAgo(0), today);
});

test('dFwd(d, 0) = d', () => {
  fc.assert(fc.property(fc.integer({min: 0, max: 365}), (n) => {
    const base = '2026-06-15';
    assert.strictEqual(dFwd(base, 0), base);
  }));
});

test('dAgo/dFwd tutarlılığı: dFwd(dAgo(n), n) ≈ bugün', () => {
  // Bugünden n gün öncesine git, n gün ileri al → bugüne dön
  fc.assert(fc.property(fc.integer({min: 0, max: 365}), (n) => {
    const today = new Date().toISOString().split('T')[0];
    const back = dAgo(n);
    const fwd = dFwd(back, n);
    assert.strictEqual(fwd, today);
  }));
});

test('dAgo monoton: n1 < n2 → dAgo(n1) >= dAgo(n2)', () => {
  fc.assert(fc.property(
    fc.integer({min: 0, max: 365}),
    fc.integer({min: 0, max: 365}),
    (a, b) => {
      const [lo, hi] = a <= b ? [a, b] : [b, a];
      assert.ok(dAgo(lo) >= dAgo(hi), `${dAgo(lo)} >= ${dAgo(hi)}`);
    }
  ));
});
