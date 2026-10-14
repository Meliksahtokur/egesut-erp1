// tests/unit/k10-case-kapat-yeniden-acma.test.js
// IMPL-K10-B-F2 RULING-1 (Y-M5M7): vaka kapatıldıktan sonra test/kullanıcı
// detay modalını kapatırsa, kapatma RPC'sinin geç dönen tazeleme adımı
// (pull → openCaseDet → openM) modalı YENİDEN açmamalı — overlay pointer'ı
// keser, `.ovs-katla` tıklaması hedefi şaşırır (e2e Y-M5M7).
// Deterministik repro: yavaş pull askıdayken closeM, sonra pull bırakılır.
// Yöntem: extract + vm — js/ui.js + js/utils/modal.js'e dokunmadan prob.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, makeDomStub, makeElement } = require('./support/loadModule.js');

const FMTTARIH = (iso) => { const p = String(iso || '').slice(0, 10).split('-'); return p.length === 3 ? p[2] + '.' + p[1] + '.' + p[0] : String(iso); };

function kapatCtx() {
  const govde = ['caseKapat', 'openCaseDet'].map(a => extractFunctionSource('js/ui.js', a)).join('\n')
    + '\n' + ['openM', 'closeM'].map(a => extractFunctionSource('js/utils/modal.js', a)).join('\n');
  const doc = makeDomStub();
  for (const id of ['cd-hayvan', 'cd-disease', 'cd-notes', 'cd-meta', 'cd-gun-bolum', 'cd-kapat-bolum', 'cd-geri-al-btn', 'm-case-det'])
    doc.__setEl(id, makeElement('div'));
  const sira = [], toasts = [], pulls = [];
  let yavasBirak = null;
  const history = { state: {}, pushState(s) { this.state = s; }, back() { sira.push('history-back'); } };
  const vaka = { id: 'v-ana', animal_id: 'H-1', status: 'active', protocol_family: 'OVSYNC', disease_id: 'd1', start_date: '2026-10-13', notes: '' };
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {}, history,
    g: (id) => doc.getElementById(id),
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    fmtTarih: FMTTARIH,
    confirm: () => true,
    rpc: async () => ({ ok: true }),
    toast: (m) => { toasts.push(String(m)); },
    // caseKapat'ın kapanış pull'u (cases+diseases+kizginlik_log) yavaş zeminde
    // askıda kalır; detay-içi pull'lar hemen döner.
    pullTables: (t) => {
      pulls.push(t.slice());
      if (t.includes('cases') && t.includes('kizginlik_log')) {
        sira.push('kapanis-pull-basladi');
        return new Promise(res => { yavasBirak = () => { sira.push('kapanis-pull-bitti'); res({ ok: t, failed: [] }); }; });
      }
      return Promise.resolve({ ok: t, failed: [] });
    },
    renderSafe: () => {},
    idbGetAll: async (t) => {
      if (t === 'cases') return [{ ...vaka }];
      if (t === 'diseases') return [{ id: 'd1', name: 'Ovsync' }];
      return [];
    },
    getState: (k) => (k === 'animals' ? [{ id: 'H-1', kupe_no: 'K1' }] : []),
    ertelemeBtnGuncelle: () => {},
    _hastalikBtnSync: () => {},
    loadDrugsCache: async () => {},
    renderCaseTimeline: async () => { sira.push('taze-render'); },
    _updateKapatBtn: () => {},
    bugun: () => '2026-10-13',
    _curCase: { ...vaka },
    _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'kapat-yeniden-acma-ctx' });
  return { ctx, doc, sira, toasts, pulls, birak: () => yavasBirak && yavasBirak() };
}

test('k10-kapat-sonrasi-yeniden-acma-yok', async () => {
  const t = kapatCtx();
  await vm.runInContext(`openCaseDet('v-ana')`, t.ctx);
  const modal = t.doc.getElementById('m-case-det');
  assert.ok(modal.classList.contains('on'), 'zemin: detay açık');
  // Kapat RPC'si uçar; pull askıdayken kullanıcı/test modalı kapatır.
  const bitis = vm.runInContext(`caseKapat()`, t.ctx);
  await new Promise(r => setTimeout(r, 50));
  assert.ok(t.sira.includes('kapanis-pull-basladi'), 'kapanış pullu askıda, ölçülen: ' + JSON.stringify(t.sira));
  await vm.runInContext(`closeM('m-case-det')`, t.ctx);
  assert.ok(!modal.classList.contains('on'), 'kapanış sonrası kapalı');
  t.birak();
  await bitis;
  assert.ok(!modal.classList.contains('on'), 'geç dönen tazeleme modalı YENİDEN açmaz, ölçülen sıra: ' + JSON.stringify(t.sira));
  assert.ok(t.sira.includes('taze-render'), 'tazeleme renderı yine koşar (ekran bayat kalmaz)');
});
