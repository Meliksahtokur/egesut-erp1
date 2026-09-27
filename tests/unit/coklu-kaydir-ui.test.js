// tests/unit/coklu-kaydir-ui.test.js — F1 Task 2 (coklu-kaydirma):
// apiCokluKaydir RPC yardımcısı (js/api.js) + vaka_kalan_gunleri_kaydir_coklu
// pull seti (RPC_TABLES). Yardımcı online-only: offline RPC_MAP'e girmez
// (vaka_toplu_ac gerekçe kalıbı). Task 3/4 bu dosyaya UI testlerini ekler.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const { extractFunctionSource } = require('./support/loadModule.js');

// RPC_TABLES const'u cerrahi çıkarır (extractFunctionSource yalnız function
// bildirimi keser; const objesi için kaynak dilimleme + vm değerlendirme).
function rpcTables() {
  const src = fs.readFileSync('js/api.js', 'utf8');
  const start = src.indexOf('const RPC_TABLES = {');
  assert.ok(start !== -1, 'RPC_TABLES bildirimi api.js\'te bulunamadı');
  const end = src.indexOf('\n};', start);
  assert.ok(end !== -1, 'RPC_TABLES kapanışı bulunamadı');
  const objSrc = src.slice(src.indexOf('{', start), end + 2); // son ';' hariç — (obj) ifadesi geçerli kalsın
  const ctx = {};
  vm.createContext(ctx);
  return vm.runInContext(`(${objSrc})`, ctx, { filename: 'js/api.js#RPC_TABLES' });
}

// apiCokluKaydir'i izole ctx'te yükler; rpc mock'u çağrıları kaydeder
// (erteleme-kaydir-ui.test.js kaydirAkisFn deseni).
function apiCokluKaydirFn(rpcMock) {
  const src = extractFunctionSource('js/api.js', 'apiCokluKaydir');
  const ctx = { console, rpc: rpcMock };
  vm.createContext(ctx);
  return vm.runInContext(`(${src})`, ctx, { filename: 'js/api.js#apiCokluKaydir' });
}

test('F1-API-1: pull seti tanimli — coklu kaydir RPC_TABLES girisi', () => {
  // JSON köprüsü: vm-realm Array prototip farkı deepStrictEqual'i düşürür
  assert.deepStrictEqual(JSON.parse(JSON.stringify(rpcTables()['vaka_kalan_gunleri_kaydir_coklu'])),
    ['gorev_log', 'treatment_days', 'treatment_day_uygulamalar', 'islem_log']);
});

test('F1-API-2: parametre sirasi dogru — named args + sonuc aynen doner', async () => {
  const cagri = [];
  const sonucGövde = { ok: true, toplam: 2, kaydirilan: 2, atlanan: [], hatalar: [], detaylar: [] };
  const fn = apiCokluKaydirFn(async (name, params) => {
    cagri.push({ name, params });
    return sonucGövde;
  });
  const res = await fn(['g1', 'g2'], 3);
  assert.strictEqual(cagri.length, 1, 'tek RPC çağrısı');
  assert.strictEqual(cagri[0].name, 'vaka_kalan_gunleri_kaydir_coklu');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(cagri[0].params)),
    { p_gorev_ids: ['g1', 'g2'], p_gun: 3 },
    'p_gorev_ids + p_gun named args (vm-realm prototip farkı için JSON köprüsü)');
  assert.deepStrictEqual(res, sonucGövde, 'RPC gövdesi çağırana aynen döner');
});

test('F1-API-3: guard — boş/geçersiz liste ve gün RPC\'ye ulaşmaz', async () => {
  const cagri = [];
  const fn = apiCokluKaydirFn(async (name, params) => { cagri.push({ name, params }); return { ok: true }; });
  await assert.rejects(() => fn([], 3), 'boş liste reddedilir');
  await assert.rejects(() => fn('g1', 3), 'dizi olmayan liste reddedilir');
  await assert.rejects(() => fn(['g1'], 0), '0 gün reddedilir');
  await assert.rejects(() => fn(['g1'], 1.5), 'kesirli gün reddedilir');
  assert.strictEqual(cagri.length, 0, 'hiçbiri RPC\'ye ulaşmaz');
});
