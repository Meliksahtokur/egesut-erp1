'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const KOK = path.join(__dirname, '..', '..');
test('pg-uzatma-kapatmaz-metin-kilidi', () => {
  const dr = fs.readFileSync(path.join(KOK, '.harness/references/domain-rules.md'), 'utf8');
  assert.match(dr, /PG uzatır, vaka açık kalır/);
  assert.ok(!dr.includes('close_reason = PG`, protokol görevleri kapanır'), '§18.7 eski metni kalkar');
});
