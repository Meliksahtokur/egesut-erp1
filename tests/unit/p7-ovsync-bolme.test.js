// tests/unit/p7-ovsync-bolme.test.js — Faz 5 P7 (PLAN ### Faz 5 Step 1 birebir)
// + ROOT RULING 1 metin kilidi (beyaz/krem zemin YOK).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { extractFunctionSource, loadExtractedFunction } = require('./support/loadModule.js');
test('p7-ovsync-bolmesi-ayri-gosterir', () => {
  assert.ok(extractFunctionSource('js/ui.js', '_showProtokolEkran').includes('_ovsyncAktifBolmeHtml('));
  const f = loadExtractedFunction('js/ui.js', '_ovsyncAktifBolmeHtml', { extra: { esc: String, escAttr: String } });
  assert.strictEqual(f([]), '', 'boş liste → bölme yok');
  const h = f([{ hayvan_id: 'h1', kupe_no: 'E2E-31', gorev_tipi: 'TOHUMLAMA_PLANLI', hedef_tarih: '2026-10-20' }]);
  assert.ok(h.includes('🔄 Aktif Ovsync') && h.includes('E2E-31'));
});
test('p7-metin-kilidi-zemin-yok', () => {
  const src = extractFunctionSource('js/ui.js', '_ovsyncAktifBolmeHtml');
  for (const pat of [/background/, /#fff/, /white/, /krem/, /#f5e/, /#faf/]) {
    assert.ok(!pat.test(src), 'yasak yazım var: ' + pat);
  }
});
// Review-düzeltme (j): kilit yalnız _ovsyncAktifBolmeHtml'deydi; TÜM yeni
// üreticilere genişler. Yasak = `background` yazımı;
// İSTİSNA `background:var(--` (mevcut palet).
test('p7-metin-kilidi-tum-ureticiler', () => {
  for (const fn of ['_ovsyncAktifBolmeHtml', 'inaktifGecisSheetHtml', '_ovsyncYetimRozetHtml', '_ovsyncS4SatirHtml']) {
    const src = extractFunctionSource('js/ui.js', fn);
    const izinli = src.replace(/background:var\(--/g, '');
    assert.ok(!/background/.test(izinli), fn + ': yasak background yazımı (wash) — vurgu yalnız yazı rengi');
  }
});
