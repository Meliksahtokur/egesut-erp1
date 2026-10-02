// tests/unit/demo-sema-diff.test.js — K8b / TB-2: demo_sema_diff 401 düzeltmesi.
// demo_sema_diff() yalnız `authenticated` rolüne EXECUTE verir (demo/03_sema_diff.sql:26;
// anon'a GRANT YASAK). js/demo.js oturum açılmadan (anon JWT) çağırınca 401 düşüyordu.
// Sözleşme: oturum yoksa RPC ÇAĞRILMAZ; oturum sonradan açılırsa (onAuthStateChange)
// drift kontrolü TAM BİR KEZ koşar; oturum varsa doğrudan bir kez koşar.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement, makeStorage } = require('./support/loadModule.js');

const DRIFT = { eksik_tablo: ['t1'], eksik_kolon: ['c1', 'c2'] };

// Demo sayfası iskeleti: #topbar (insertAdjacentElement destekli) + sahte db.
function kur({ session }) {
  const dom = makeDomStub();
  const topbar = dom.__setEl('topbar', makeElement('div'));
  dom.__setEl('demo-klonla', makeElement('button')); // innerHTML'den doğmayan düğmeler
  dom.__setEl('demo-cikis', makeElement('button'));
  const eklenen = [];
  const ekle = (_pos, el) => { eklenen.push(el); if (el.id) dom.__setEl(el.id, el); return el; };
  topbar.insertAdjacentElement = ekle;
  const mk = dom.createElement;
  dom.createElement = tag => Object.assign(mk(tag), { insertAdjacentElement: ekle }); // #demo-bar da ekleyebilsin

  const durum = { session, rpcCagri: [], aboneler: [], unsub: 0 };
  const db = {
    auth: {
      getSession: async () => ({ data: { session: durum.session } }),
      onAuthStateChange: cb => {
        durum.aboneler.push(cb);
        return { data: { subscription: { unsubscribe: () => { durum.unsub++; } } } };
      },
    },
    rpc: async name => {
      durum.rpcCagri.push(name);
      return { data: DRIFT, error: null };
    },
  };
  loadBrowserModule('js/demo.js', { dom, storage: makeStorage({ EGESUT_DEMO_POPUP_OFF: '1' }), extra: { IS_DEMO: true, db } });
  return { durum, eklenen };
}

// Mikro/makro görev kuyruğunu boşalt (setTimeout(0) ile ertelenen kontrol dahil)
const bosalt = () => new Promise(r => setTimeout(r, 15));

test('TB-2: oturum yokken demo_sema_diff RPC çağrılmaz (anon 401 engellenir)', async () => {
  const { durum } = kur({ session: null });
  await bosalt();
  assert.deepStrictEqual(durum.rpcCagri, []);
});

test('TB-2: oturum sonradan açılınca (SIGNED_IN) RPC tam bir kez çağrılır ve drift uyarısı eklenir', async () => {
  const { durum, eklenen } = kur({ session: null });
  await bosalt();
  assert.strictEqual(durum.aboneler.length, 1, 'oturum-hazır olayına abone olunmalı');

  durum.session = { user: { id: 'u1' } };
  durum.aboneler[0]('SIGNED_IN', durum.session);
  durum.aboneler[0]('SIGNED_IN', durum.session); // tekrarlanan olay (sekme odağı vb.)
  await bosalt();

  assert.deepStrictEqual(durum.rpcCagri, ['demo_sema_diff']);
  assert.ok(eklenen.some(e => String(e.textContent).includes('Şema drift')), 'uyarı bandı eklenmeli');
  assert.ok(durum.unsub >= 1, 'abonelik temizlenmeli');
});

test('TB-2: oturumsuz olay (SIGNED_OUT / session=null) RPC tetiklemez', async () => {
  const { durum } = kur({ session: null });
  await bosalt();
  durum.aboneler[0]('SIGNED_OUT', null);
  durum.aboneler[0]('INITIAL_SESSION', null);
  await bosalt();
  assert.deepStrictEqual(durum.rpcCagri, []);
});

test('TB-2: oturum zaten varsa RPC doğrudan bir kez çağrılır, abonelik açılmaz', async () => {
  const { durum } = kur({ session: { user: { id: 'u1' } } });
  await bosalt();
  assert.deepStrictEqual(durum.rpcCagri, ['demo_sema_diff']);
  assert.strictEqual(durum.aboneler.length, 0);
});
