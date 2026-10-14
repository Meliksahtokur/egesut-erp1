// tests/unit/k10-modal-ert3.test.js
// RULING 4 (IMPL-K10-B-F1, KAPI ERT3) karakterizasyon: silinen kilitlerin geri
// gelmesi — yeni hastalık modalı üzerindeki üç koruma (bugünkü kod yeşil
// beklenir; her biri adlı mutantla FAIL üretir — MEASURED).
// Yöntem: extract + vm — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, makeDomStub } = require('./support/loadModule.js');

function ekRow(stok, doz) {
  return {
    getAttribute: (a) => (a === 'data-ek-stok' ? stok : (a === 'data-ek-urun' ? null : null)),
    dataset: {},
    _ek: null,
    querySelector: (sel) => (sel === '.hg-ek-doz' ? { value: doz } : null),
  };
}

function kaydetCtx(els, rpcImpl) {
  const govde = 'var _hgKayitKilit=false;\n' + ['hastalikGunKaydet', 'hgEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  const base = {
    'hg-gun': { value: '7' },
    'hg-hastalik': { value: 'd1' },
    'hg-hastalik-ad': { value: 'İnaktif Ovaryum' },
    'hg-tarih': { value: '2026-10-13' },
    'hg-vit-doz': { value: '20' },
    'hg-vit-stok': { value: 's1' },
    'hg-vit-urun': { value: '' },
    'hg-tai-chip': { getAttribute: () => '2026-10-15' },
    'hg-ilac-liste': { children: [] },
    'hastalik-modal': { remove() {} },
    ...els,
  };
  for (const [id, el] of Object.entries(base)) doc.__setEl(id, el);
  const rpcCagrilari = [], toasts = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    toast: (m) => { toasts.push(String(m)); },
    rpc: rpcImpl(rpcCagrilari),
    pullTables: async () => ({ ok: [], failed: [] }),
    renderSafe: () => {},
    RPC_TABLES: { ovsync_hastalik_gunu_ekle: ['cases'] },
    idbGetAll: async () => [],
    renderCaseTimeline: async () => {},
    loadDash: () => {}, _curCase: { id: 'v-ana' },
    dFwd: (iso) => iso,
    _pgKapiHata: () => false, _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'ert3-kaydet-ctx' });
  return { ctx, rpcCagrilari, toasts };
}
const OK_RPC = (log) => async (ad, p) => {
  log.push({ ad, p });
  return { ok: true, gun_id: 'g1', mevcut: false, ertelenen: 0, ilac: 1 };
};

// (a) doz ≤ 0 / boş → "Geçerli bir doz" uyarısı, RPC çağrılmaz (:1573, :1585).
test('k10-modal-doz-sifir-red', async () => {
  let t = kaydetCtx({ 'hg-vit-doz': { value: '0' } }, OK_RPC);
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.ok(t.toasts.some(m => m.includes('Geçerli bir doz')), 'vit-0 uyarı, ölçülen: ' + JSON.stringify(t.toasts));
  assert.strictEqual(t.rpcCagrilari.length, 0, 'vit-0 RPC YOK, ölçülen: ' + t.rpcCagrilari.length);
  t = kaydetCtx({ 'hg-vit-doz': { value: '' } }, OK_RPC);
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.ok(t.toasts.some(m => m.includes('Geçerli bir doz')), 'vit-boş uyarı, ölçülen: ' + JSON.stringify(t.toasts));
  assert.strictEqual(t.rpcCagrilari.length, 0, 'vit-boş RPC YOK');
  t = kaydetCtx({ 'hg-ilac-liste': { children: [ekRow('s9', '0')] } }, OK_RPC);
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.ok(t.toasts.some(m => m.includes('Geçerli bir doz')), 'ek-0 uyarı, ölçülen: ' + JSON.stringify(t.toasts));
  assert.strictEqual(t.rpcCagrilari.length, 0, 'ek-0 RPC YOK');
});

// (b) boş stok_id RPC payload'ına girmez (:1570).
test('k10-modal-bos-stok-gonderilmez', async () => {
  const t = kaydetCtx({ 'hg-ilac-liste': { children: [ekRow('', '5')] } }, OK_RPC);
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.strictEqual(t.rpcCagrilari.length, 1, 'kayıt tek RPC ile gider');
  const ilaclar = t.rpcCagrilari[0].p.p_ilaclar;
  assert.ok(Array.isArray(ilaclar), 'p_ilaclar dizi');
  assert.ok(ilaclar.every(i => i && i.stok_id), 'boş stok_id YOK, ölçülen: ' + JSON.stringify(ilaclar));
  assert.strictEqual(ilaclar.length, 1, 'yalnız vitamin gider, ölçülen: ' + ilaclar.length);
});

// (c) "İnaktif Ovaryum bulunamadı" kapısı (:1478) — RPC çağrılmaz, sheet açılmaz.
test('k10-modal-kist-fail-closed', async () => {
  const govde = extractFunctionSource('js/ui.js', 'hastalikGunAc');
  const toasts = [];
  let appends = 0;
  const doc = {
    getElementById: () => null,
    createElement: () => { appends++; return {}; },
    body: { appendChild: () => { appends++; } },
  };
  const ctx = {
    console,
    document: doc,
    toast: (m) => { toasts.push(String(m)); },
    idbGetAll: async (tablo) => (tablo === 'diseases' ? [{ id: 'd2', name: 'Kistik Over' }] : []),
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'ert3-ac-ctx' });
  await vm.runInContext(`hastalikGunAc('v-ana')`, ctx);
  assert.ok(toasts.some(m => m.includes('İnaktif Ovaryum hastalığı bulunamadı')),
    'fail-closed toast, ölçülen: ' + JSON.stringify(toasts));
  assert.strictEqual(appends, 0, 'sheet açılmadı, ölçülen: ' + appends);
});
