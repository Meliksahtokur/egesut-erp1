// tests/unit/k10-hastalik-hizli-render.test.js
// IMPL-K10-B-F2 RULING-2 (F-2): RPC ok sonrası vaka detayı timeline + kart
// ≤1.5 sn (demo) — tam 7-tablo pull beklenmeden hızlı render + toast, kalan
// tablolar arkadan yakınsar. UI-0 yarış kapısı korunur (render'dan önce
// pull — yalnız daraltılmış hızlı set).
// Yöntem: extract + vm — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, makeDomStub } = require('./support/loadModule.js');

const HIZLI = ['treatment_days', 'drug_administrations'];

function hizliCtx() {
  const govde = 'var _hgKayitKilit=false;\n' + ['hastalikGunKaydet', 'hgEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  doc.__setEl('hg-gun', { value: '7' });
  doc.__setEl('hg-hastalik', { value: 'd1' });
  doc.__setEl('hg-hastalik-ad', { value: 'İnaktif Ovaryum' });
  doc.__setEl('hg-tarih', { value: '2026-10-13' });
  doc.__setEl('hg-tai-chip', { getAttribute: () => '2026-10-15' });
  doc.__setEl('hg-vit-doz', { value: '20' });
  doc.__setEl('hg-vit-stok', { value: 's1' });
  doc.__setEl('hg-ilac-liste', { children: [] });
  doc.__setEl('hastalik-modal', { remove() {} });
  const pulls = [], toasts = [], sira = [];
  let yavasBirak = null;
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); sira.push('toast'); },
    rpc: async () => ({ ok: true, gun_id: 'gun-hizli', mevcut: false, ertelenen: 1, ilac: 1 }),
    // Hızlı set hemen döner; tam set (islem_log'lu yavaş zemin) test
    // bırakana dek askıda kalır (gerçek yavaş pull).
    pullTables: (t) => {
      pulls.push(t.slice());
      if (t.length <= HIZLI.length && t.every(x => HIZLI.includes(x))) {
        sira.push('hizli-pull-bitti');
        return Promise.resolve({ ok: t, failed: [] });
      }
      sira.push('yavas-pull-basladi');
      return new Promise(res => { yavasBirak = () => { sira.push('yavas-pull-bitti'); res({ ok: t, failed: [] }); }; });
    },
    renderSafe: () => {},
    RPC_TABLES: { ovsync_hastalik_gunu_ekle: ['cases', 'treatment_days', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log', 'islem_log'] },
    idbGetAll: async (t) => (t === 'treatment_days' ? [{ id: 'gun-hizli' }] : []),
    renderCaseTimeline: async () => { sira.push('taze-render'); },
    loadDash: () => {},
    _curCase: { id: 'v-ana' },
    dFwd: (iso, n) => { const d = new Date(iso + 'T00:00:00'); d.setDate(d.getDate() + n); const p = (x) => String(x).padStart(2, '0'); return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); },
    _pgKapiHata: () => false, _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'hizli-render-ctx' });
  return { ctx, pulls, toasts, sira, birak: () => yavasBirak && yavasBirak() };
}

test('k10-hastalik-aninda-render', async () => {
  const t = hizliCtx();
  const bitis = vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  // Yavaş pull askıdayken hızlı faz bitmiş olmalı (anında render).
  await new Promise(r => setTimeout(r, 50));
  assert.ok(t.pulls.length >= 1, 'en az bir pull koştu');
  // vm-sınırındaki dizi ev sahibi prototipini taşımaz — karşılaştırma kopyayla.
  assert.deepStrictEqual(Array.from(t.pulls[0]), HIZLI, 'ilk pull hızlı set (timeline tabloları), ölçülen: ' + JSON.stringify(t.pulls[0]));
  assert.ok(t.sira.includes('taze-render'), 'yavaş pull bitmeden taze render, ölçülen sıra: ' + JSON.stringify(t.sira));
  assert.ok(t.sira.indexOf('taze-render') < t.sira.indexOf('toast'), 'toast render SONRASI (tutarlılık), ölçülen sıra: ' + JSON.stringify(t.sira));
  assert.ok(!t.sira.includes('yavas-pull-bitti'), 'hızlı faz yavaş pullu beklemez');
  // Yakınsama: yavaş pull bitince kalan tablolar + ikinci render.
  t.birak();
  await bitis;
  const yavas = t.pulls.find(p => p.length > HIZLI.length) || [];
  assert.ok(!yavas.some(x => HIZLI.includes(x)), 'yavaş faz kalan tablolar (tekrar YOK), ölçülen: ' + JSON.stringify(yavas));
  assert.ok(t.sira.filter(x => x === 'taze-render').length >= 2, 'yakınsama renderı, ölçülen sıra: ' + JSON.stringify(t.sira));
});
