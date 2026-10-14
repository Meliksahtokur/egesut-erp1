// tests/unit/k10-hastalik-aninda-render.test.js
// Parça E3 kilit (ROOT RULING, MUT-K10-HIZLI-TAM-PULL): ≤1.5 sn hedefinin
// kilidi yapısal birim testtir — hızlı fazın İLK pull çağrısı HIZLI
// tablolarıdır (tam `tables` değil). Üretimde `pullTables(HIZLI)` →
// `pullTables(tables)` mutantı bu testi FAIL'a çevirir; restore PASS'a
// döndürür. (ERT2 6/6 probu ek kanıt olarak kalır.)
// Yöntem: extract + vm — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, makeDomStub } = require('./support/loadModule.js');

const HIZLI = ['treatment_days', 'drug_administrations'];

function kilitCtx() {
  const govde = 'var _hgKayitKilit=false;\n' + ['hastalikGunKaydet', 'hgEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  doc.__setEl('hg-gun', { value: '7' });
  doc.__setEl('hg-hastalik', { value: 'd1' });
  doc.__setEl('hg-hastalik-ad', { value: 'İnaktif Ovaryum' });
  doc.__setEl('hg-tarih', { value: '2026-10-13' });
  doc.__setEl('hg-tai-chip', { getAttribute: () => '2026-10-15' });
  doc.__setEl('hg-vit-doz', { value: '' });
  doc.__setEl('hg-ilac-liste', { children: [] });
  doc.__setEl('hastalik-modal', { remove() {} });
  const pulls = [];
  const toasts = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    rpc: async () => ({ ok: true, gun_id: 'gun-kilit', mevcut: false, ertelenen: 1, ilac: 0 }),
    // Çağrı argümanları kaydedilir (E3 kilit probu).
    pullTables: async (t) => {
      pulls.push((t || []).slice());
      return { ok: (t || []).slice(), failed: [] };
    },
    renderSafe: () => {},
    RPC_TABLES: { ovsync_hastalik_gunu_ekle: ['cases', 'treatment_days', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log', 'islem_log'] },
    idbGetAll: async (t) => (t === 'treatment_days' ? [{ id: 'gun-kilit' }] : []),
    renderCaseTimeline: async () => {},
    loadDash: () => {},
    _curCase: { id: 'v-ana' },
    dFwd: (iso, n) => { const d = new Date(iso + 'T00:00:00'); d.setDate(d.getDate() + n); const p = (x) => String(x).padStart(2, '0'); return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); },
    _pgKapiHata: () => false, _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'kilit-aninda-render-ctx' });
  return { ctx, pulls, toasts };
}

test('k10-hastalik-aninda-render', async () => {
  const t = kilitCtx();
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.ok(t.pulls.length >= 1, 'en az bir pull koştu, ölçülen: ' + JSON.stringify(t.pulls));
  // vm-sınırındaki dizi ev sahibi prototipini taşımaz — karşılaştırma kopyayla.
  const ilk = Array.from(t.pulls[0]);
  assert.deepStrictEqual(ilk, HIZLI, 'ilk pull HIZLI set (tam tables DEĞİL), ölçülen: ' + JSON.stringify(ilk));
  assert.ok(!ilk.some(x => HIZLI.indexOf(x) === -1), 'ilk pullda yavaş tablo YOK, ölçülen: ' + JSON.stringify(ilk));
});
