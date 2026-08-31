const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { _ymd, bugun, dAgo, dFwd } = require('../../js/utils/helpers.js');

// dAgo(n) bugünden n gün önce (tek argüman), dFwd(base, n) base+'n gün' (iki argüman).
// Beklentiler de bugun() ile üretilir — toISOString() UTC'dir, 21:00-23:59 UTC'te
// (İstanbul 00:00-02:59) dünkü tarihi verip testi gece kırdırdı (B4).

test('bugun(): Y-M-D format sözleşmesi', () => {
  assert.match(bugun(), /^\d{4}-\d{2}-\d{2}$/);
});

test('bugun(): cihaz yerel tarihini temsil eder (yıl/ay/gün bileşenleri)', () => {
  const d = new Date();
  assert.strictEqual(bugun(), `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`);
});

test('_ymd: Date -> Y-M-D (yerel bileşenler)', () => {
  assert.strictEqual(_ymd(new Date(2026, 7, 31, 1, 30)), '2026-08-31'); // ay indeksi 7 = Ağustos
  assert.strictEqual(_ymd(new Date(2026, 0, 5, 23, 59)), '2026-01-05');
});

test('dAgo: sınır — 0 gün = bugün (YYYY-MM-DD)', () => {
  assert.strictEqual(dAgo(0), bugun());
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
    const back = dAgo(n);
    const fwd = dFwd(back, n);
    assert.strictEqual(fwd, bugun());
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

test('dFwd(null, n) = bugün + n (yerel gün aritmetiği)', () => {
  assert.strictEqual(dFwd(null, 1), dFwd(bugun(), 1));
});
