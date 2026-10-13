// tests/unit/k10-yaris-kapi.test.js
// Faz UI-0 (karar 10): U2 küpe başlığı + U3/U4 "Vaka bulunamadı" yarış kapısı.
// Yöntem: loadModule/extract — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, loadExtractedFunction, makeDomStub } = require('./support/loadModule.js');

// ── Ortak: kaydet zinciri, yavaş pull + gerçek openCaseDet aynası ──
// Gerçek openCaseDet (js/ui.js:12203-12207): IDB'de yoksa 'Vaka bulunamadı'
// toast'u verir. Stub aynı sözleşmeyi taşır — yarış varsa toast düşer.
function yarisCtx() {
  const govde = ['inaktifGecisKaydet', 'vitaminStokIdBul', 'igEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  doc.__setEl('ig-gun', { value: '7' });
  doc.__setEl('ig-hastalik', { value: 'd1' });
  doc.__setEl('inaktif-gecis-modal', { remove() {} });
  const casesIdb = [{ id: 'v-ana', animal_id: 'H-31', status: 'active' }];
  const pulls = [];
  const toasts = [];
  const acilan = [];
  const sira = [];
  const idbGetAll = async (t) => (t === 'cases' ? casesIdb.slice() : []);
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    rpc: async (ad) => {
      if (ad === 'inaktif_alt_vaka_ac') return { ok: true, alt_vaka_id: 'alt-yaris', gun_id: null, ertelenen: 0 };
      return { ok: true };
    },
    // Yavaş pull: sunucu durumu IDB'ye YALNIZ pull bitince düşer (gerçek yarış).
    pullTables: async (t) => {
      pulls.push(t);
      await new Promise(r => setTimeout(r, 60));
      casesIdb.push({ id: 'alt-yaris', animal_id: 'H-31', status: 'active' });
      sira.push('pull-bitti');
      return { ok: [], failed: [] };
    },
    renderSafe: () => {},
    RPC_TABLES: { inaktif_alt_vaka_ac: ['cases', 'treatment_days'] },
    idbGetAll,
    openCaseDet: async (id) => {
      const tum = await idbGetAll('cases');
      if (!tum.some(x => x && x.id === id)) { toasts.push('Vaka bulunamadı'); return; }
      sira.push('detay-acildi');
      acilan.push(id);
    },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'yaris-kaydet-ctx' });
  return { ctx, pulls, toasts, acilan, sira };
}

test('yavas-detay-yaris-yok', async () => {
  const t = yarisCtx();
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t.ctx);
  const kotu = t.toasts.filter(m => m.includes('bulunamadı'));
  assert.strictEqual(kotu.length, 0, '"Vaka bulunamadı" yarışı YOK, ölçülen: ' + JSON.stringify(t.toasts));
  assert.deepStrictEqual(t.acilan, ['alt-yaris'], 'pull + IDB doğrulamasından SONRA detay açılır');
  assert.ok(t.pulls.length >= 1, 'pull koştu');
  assert.ok(
    t.sira.indexOf('pull-bitti') !== -1 && t.sira.indexOf('pull-bitti') < t.sira.indexOf('detay-acildi'),
    'sıra: önce pull, sonra detay — ölçülen: ' + JSON.stringify(t.sira)
  );
});

// ── U2: vaka detay yolunda başlık küpesi kart/_curCase'ten gelir ──
function kupeCtx() {
  const govde = ['inaktifGecisSheetHtml', 'inaktifGecisAc']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  const toasts = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    // _curCase ham cases satırıdır (kupe_no YOK — gerçek U2 durumu).
    _curCase: { id: 'v-ana', animal_id: 'H-31', status: 'active', protocol_family: 'OVSYNC' },
    getState: (k) => (k === 'animals' ? [{ id: 'H-31', kupe_no: '31' }] : []),
    idbGetAll: async (t) => (t === 'diseases'
      ? [{ id: 'd1', name: 'İnaktif Ovaryum' }]
      : []),
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'kupe-ac-ctx' });
  return { ctx, doc, toasts };
}

test('kupe-baslik-dolu', async () => {
  const t = kupeCtx();
  await vm.runInContext(`inaktifGecisAc('v-ana',{secim:'inaktif',kupeNo:null,taiEski:null})`, t.ctx);
  const box = t.doc.body.children.find(e => e && e.id === 'inaktif-gecis-modal');
  assert.ok(box, 'sheet açılır');
  assert.ok(box.innerHTML.includes('Küpe 31'), 'başlık kart küpesini taşır (U2)');
  assert.ok(!box.innerHTML.includes('bilinmiyor'), 'bilinmiyor YOK, ölçülen başlık: '
    + (box.innerHTML.match(/— Küpe [^<]*/) || ['?'])[0]);
});
