const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { fmtTarih, fmtTarihSaat, getDisplayKupe } = require('../../js/utils/helpers.js');

// ── fmtTarih ───────────────────────────────────────────────────
test('fmtTarih: boş/null girdi → em-dash', () => {
  assert.strictEqual(fmtTarih(null), '—');
  assert.strictEqual(fmtTarih(''), '—');
  assert.strictEqual(fmtTarih(undefined), '—');
});

test('fmtTarih: ISO tarih → DD.MM.YYYY', () => {
  assert.strictEqual(fmtTarih('2026-03-12'), '12.03.2026');
  assert.strictEqual(fmtTarih('2026-01-01T10:30:00Z'), '01.01.2026');
});

test('fmtTarih: bozuk format aynen geri döner (parse edilemezse)', () => {
  assert.strictEqual(fmtTarih('gecersiz'), 'gecersiz');
});

test('fmtTarih: property — geçerli YYYY-MM-DD girdisinde her zaman 3 parça DD.MM.YYYY üretir', () => {
  fc.assert(fc.property(
    fc.date({ min: new Date('2000-01-01'), max: new Date('2099-12-31'), noInvalidDate: true }),
    (d) => {
      const iso = d.toISOString().split('T')[0];
      const out = fmtTarih(iso);
      const parts = out.split('.');
      assert.strictEqual(parts.length, 3);
      assert.strictEqual(parts[0].length, 2);
      assert.strictEqual(parts[1].length, 2);
      assert.strictEqual(parts[2], iso.split('-')[0]);
    }
  ));
});

// ── fmtTarihSaat ───────────────────────────────────────────────
test('fmtTarihSaat: boş/null girdi → em-dash', () => {
  assert.strictEqual(fmtTarihSaat(null), '—');
  assert.strictEqual(fmtTarihSaat(''), '—');
});

test('fmtTarihSaat: parse edilemeyen tarih "Invalid Date" döner (try/catch tetiklenmez — Date ctor throw etmez)', () => {
  assert.strictEqual(fmtTarihSaat('gecersiz'), 'Invalid Date');
});

test('fmtTarihSaat: geçerli ISO datetime → tarih + saat içerir', () => {
  const out = fmtTarihSaat('2026-03-12T14:30:00Z');
  assert.match(out, /^\d{2}\.\d{2}\.\d{4}/); // DD.MM.YYYY ile başlar
  assert.match(out, /\d{2}:\d{2}$/); // HH:MM ile biter
});

// ── getDisplayKupe ─────────────────────────────────────────────
test('getDisplayKupe: null/undefined hayvan → fallback ya da em-dash', () => {
  assert.strictEqual(getDisplayKupe(null), '—');
  assert.strictEqual(getDisplayKupe(null, 'X-1'), 'X-1');
  assert.strictEqual(getDisplayKupe(undefined), '—');
});

test('getDisplayKupe: öncelik sırası — kupe_no > devlet_kupe > id > fallback', () => {
  assert.strictEqual(getDisplayKupe({ kupe_no: 'K1', devlet_kupe: 'D1', id: 'ID1' }), 'K1');
  assert.strictEqual(getDisplayKupe({ devlet_kupe: 'D1', id: 'ID1' }), 'D1');
  assert.strictEqual(getDisplayKupe({ id: 'ID1' }), 'ID1');
  assert.strictEqual(getDisplayKupe({}, 'FB'), 'FB');
  assert.strictEqual(getDisplayKupe({}), '—');
});

test('getDisplayKupe: property — boş olmayan kupe_no varsa her zaman onu döner', () => {
  fc.assert(fc.property(
    fc.string({ minLength: 1 }),
    fc.option(fc.string(), { nil: undefined }),
    (kupeNo, devletKupe) => {
      const out = getDisplayKupe({ kupe_no: kupeNo, devlet_kupe: devletKupe });
      assert.strictEqual(out, kupeNo);
    }
  ));
});
