// tests/unit/k10-ilac-bar-yalniz-ovsync.test.js
// RULING 1 (IMPL-K10-B-F1, KAPI BLOK1): "+ İlaç"/bar yalnız Ovsync vakasında.
// js/ui.js:1713-1714 Ovsync koşulu taşımıyordu → mastit vb. her aktif vaka
// detayında "+ İlaç"/hastalık barı çıkıyordu. Görünürlük, aynı fonksiyondaki
// Ovsync kabul koşuluna (_hastalikKabulMu: damga ya da NULL-yedek canlı
// denetim) bağlanır. Yöntem: extract + vm — js/ui.js'e dokunmadan prob.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, makeDomStub, makeElement } = require('./support/loadModule.js');

function barCtx(vaka, idb) {
  const govde = ['_hastalikBtnSync', '_hastalikKabulMu', '_hgSonGunId']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  const wrap = makeElement('div');
  const kapat = makeElement('div');
  wrap.appendChild(kapat);
  doc.__setEl('cd-kapat-bolum', kapat);
  const bar = makeElement('div');
  doc.__setEl('cd-hastalik-bar', bar);
  const ctx = {
    console, document: doc,
    _curCase: vaka,
    idbGetAll: async (t) => ((idb && idb[t]) || []),
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'ilac-bar-ctx' });
  return { ctx, bar };
}
function disp(bar, id) {
  const b = bar.children.find(c => c && c.id === id);
  return b ? b.style.display : undefined;
}

test('k10-ilac-bar-yalniz-ovsync', async () => {
  // 1) Mastit, NULL-aile, Ovsync izsiz aktif vaka → iBtn + bar gizli.
  {
    const vaka = { id: 'v-mastit', status: 'active', protocol_family: null, disease_id: 'd-mastit' };
    const t = barCtx(vaka, {});
    await vm.runInContext('_hastalikBtnSync()', t.ctx);
    assert.strictEqual(disp(t.bar, 'cd-hastalik-btn'), 'none', 'mastit: + Hastalık gizli');
    assert.strictEqual(disp(t.bar, 'cd-ilac-btn'), 'none', 'mastit: + İlaç gizli, ölçülen: ' + disp(t.bar, 'cd-ilac-btn'));
    assert.strictEqual(t.bar.style.display, 'none', 'mastit: bar gizli, ölçülen: ' + t.bar.style.display);
  }
  // 2) Ovsync vakası → görünür.
  {
    const vaka = { id: 'v-ov', status: 'active', protocol_family: 'OVSYNC' };
    const t = barCtx(vaka, {});
    await vm.runInContext('_hastalikBtnSync()', t.ctx);
    assert.strictEqual(disp(t.bar, 'cd-hastalik-btn'), 'block', 'ovsync: + Hastalık görünür');
    assert.strictEqual(disp(t.bar, 'cd-ilac-btn'), 'block', 'ovsync: + İlaç görünür');
    assert.strictEqual(t.bar.style.display, 'flex', 'ovsync: bar görünür');
  }
  // 3) NULL-aile + şablon TAI izli vaka → görünür.
  {
    const vaka = { id: 'v-t', status: 'active', protocol_family: null, disease_id: 'd9' };
    const t = barCtx(vaka, { gorev_log: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v-t:7' }] });
    await vm.runInContext('_hastalikBtnSync()', t.ctx);
    assert.strictEqual(disp(t.bar, 'cd-ilac-btn'), 'block', 'null+TAI: + İlaç görünür');
    assert.strictEqual(t.bar.style.display, 'flex', 'null+TAI: bar görünür');
  }
});
