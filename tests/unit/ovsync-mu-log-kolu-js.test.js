// tests/unit/ovsync-mu-log-kolu-js.test.js
// ovsync-mu-fix (2026-10-17): JS aynası `_hastalikKabulMu` DB `_vaka_ovsync_mu`
// (20261017000001) ile aynı kural: log kolu yalnız anahtardaki şablon
// protokol_ailesi='OVSYNC' VE log iptal===false iken kabul; `:MANUEL` saymaz.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { loadExtractedFunction, extractFunctionSource, makeDomStub, makeElement } = require('./support/loadModule.js');

const SB = [{ id: 's-mastit', protokol_ailesi: null }, { id: 's-ovs', protokol_ailesi: 'OVSYNC' }];
const vaka = (id) => ({ id, status: 'active', protocol_family: null, disease_id: 'd-mastit' });
const log = (id, ek, iptal) => ({ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:' + id + ':' + ek, iptal });

test('ovsync-mu-log-kolu-js: kabul matrisi', () => {
  const f = loadExtractedFunction('js/ui.js', '_hastalikKabulMu');
  const m = [
    ['mastit şablonu iptal', log('v1', 's-mastit', true), false],
    ['mastit şablonu açık', log('v1', 's-mastit', false), false],
    ['MANUEL', log('v1', 'MANUEL', false), false],
    ['OVSYNC şablonu iptal', log('v1', 's-ovs', true), false],
    ['OVSYNC şablonu iptal yok (undefined)', log('v1', 's-ovs', undefined), false],
    ['OVSYNC şablonu iptal null', log('v1', 's-ovs', null), false],
    ['bilinmeyen şablon', log('v1', 's-yok', false), false],
    ['OVSYNC şablonu açık', log('v1', 's-ovs', false), true],
  ];
  for (const [ad, g, bek] of m) {
    assert.strictEqual(f(vaka('v1'), { gorevler: [g], sablonlar: SB }), bek, ad);
  }
  assert.strictEqual(f(vaka('v1'), { gorevler: [log('v2', 's-ovs', false)], sablonlar: SB }), false, 'başka vakanın logu');
  assert.strictEqual(f({ ...vaka('v1'), protocol_family: 'OVSYNC' }, {}), true, 'damga kolu aynen');
});

test('ovsync-mu-log-kolu-js: bağlam kabul kümesi', () => {
  const kur = loadExtractedFunction('js/ui.js', '_ovsyncBaglamKur', {
    extra: { _hastalikKabulMu: loadExtractedFunction('js/ui.js', '_hastalikKabulMu') },
  });
  const gorevler = [log('v-mastit', 's-mastit', true), log('v-ovs', 's-ovs', false)];
  const b = kur(gorevler, [vaka('v-mastit'), vaka('v-ovs')], [], { eslem: [], sablonlar: SB });
  assert.strictEqual(b.ovsyncKabul.has('v-mastit'), false, 'mastit kümede değil');
  assert.strictEqual(b.ovsyncKabul.has('v-ovs'), true, 'OVSYNC logu kümede');
});

test('ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni)', async () => {
  const govde = ['_hastalikBtnSync', '_hastalikKabulMu', '_hgSonGunId']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const kos = async (v, gl) => {
    const doc = makeDomStub(); const wrap = makeElement('div'); const kapat = makeElement('div');
    wrap.appendChild(kapat); doc.__setEl('cd-kapat-bolum', kapat);
    const bar = makeElement('div'); doc.__setEl('cd-hastalik-bar', bar);
    const idb = { gorev_log: gl, tedavi_sablonu: SB, sablon_hastalik_eslem: [] };
    const ctx = { console, document: doc, _curCase: v, idbGetAll: async (t) => idb[t] || [] };
    vm.createContext(ctx); vm.runInContext(govde, ctx); await vm.runInContext('_hastalikBtnSync()', ctx);
    const d = (id) => (bar.children.find(c => c && c.id === id) || { style: {} }).style.display;
    return [d('cd-hastalik-btn'), d('cd-ilac-btn'), bar.style.display].join('/');
  };
  assert.strictEqual(await kos(vaka('v-m'), [log('v-m', 's-mastit', true)]), 'none/none/none', 'mastit: gizli');
  assert.strictEqual(await kos(vaka('v-o'), [log('v-o', 's-ovs', false)]), 'block/block/flex', 'OVSYNC logu: görünür');
});
