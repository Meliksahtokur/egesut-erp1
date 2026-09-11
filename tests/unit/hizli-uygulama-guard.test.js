'use strict';
// tests/unit/hizli-uygulama-guard.test.js
// hızlı uygulama submit akışlarında çift-gönderim koruması: rpc uçuştayken ikinci
// tık butonu disabled gördüğü için ikinci hizli_uygulama çağrısı AÇILMAMALI
// (907 vakası: 15 sn arayla iki uygulama_log + iki stok düşümü — islem_log
// 1978c04d + 895f8c8d, 2026-09-11). Yama repo'daki mevcut deseni izler
// (asiUygulaVeTamamla/_tedaviGunExecute: btn.disabled + 'İşleniyor…').
//
// Yükleme deseni: protokol-dismiss-gorev.test.js ile aynı — loadBrowserModule
// ile tam js/ui.js yüklenir; document/toast/rpc stub'ları enjekte edilir.
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

// ── Sahne kurulumu ──────────────────────────────────────────────────
// rpcImpl: testin promise kontrolü istediği anlarda çağrılır (pending senaryosu).
function loadScene({ rpcImpl = null } = {}) {
  const rec = { rpcs: [], toasts: [], refresh: [], openDet: [], closeM: [], pulls: [], loadTasks: [], loadDash: [] };
  const document = makeDomStub();
  const btn = makeElement('button');
  btn.textContent = 'Kaydet';

  // form alanları
  for (const [id, val] of [['pu-stok', 'S-1'], ['pu-doz', '5'], ['pu-birim', 'ml'], ['pu-rota', 'IM']]) {
    const el = makeElement('input');
    el.value = val;
    document.__setEl(id, el);
  }
  document.__setEl('pu-kaydet-btn', btn);

  const { sandbox } = loadBrowserModule('js/ui.js', {
    dom: document,
    extra: {
      db: {},
      toast: (msg, err) => rec.toasts.push([msg, !!err]),
      confirm: () => true,
      write: async () => [],
      getData: async () => [],
      pullTables: async (t) => { rec.pulls.push(t); return {}; },
      rpc: async (name, args) => {
        rec.rpcs.push({ name, args });
        return rpcImpl ? rpcImpl(name) : { ok: true };
      },
      idbGetAll: async () => [],
    },
  });
  sandbox._islemSonrasiRefresh = async () => { rec.refresh.push(1); };
  sandbox.openDet = (...a) => { rec.openDet.push(a); };
  sandbox.closeM = (...a) => { rec.closeM.push(a); };
  sandbox.loadTasks = async (...a) => { rec.loadTasks.push(a); };
  sandbox.loadDash = () => { rec.loadDash.push(1); };
  sandbox._curTaskFilter = 'today';
  sandbox.window.__protokolUyarilar = [];
  return { sandbox, document, btn, rec };
}

test('guard-01: rpc uçuşta iken ikinci çağrı yok sayılır (tek rpc)', async () => {
  let bırak;
  const { sandbox, btn, rec } = loadScene({
    rpcImpl: () => new Promise(res => { bırak = () => res({ ok: true }); }),
  });
  const p1 = sandbox._protokolUygulaKaydet('H-1', 0);
  assert.strictEqual(rec.rpcs.length, 1, 'ilk çağrı rpc açmalı');
  assert.strictEqual(btn.disabled, true, 'buton uçuşta disabled olmalı');
  assert.strictEqual(btn.textContent, 'İşleniyor…');

  const p2 = sandbox._protokolUygulaKaydet('H-1', 0); // çift tık
  assert.strictEqual(await p2, undefined, 'ikinci çağrı erken dönmeli (async → Promise<undefined>)');
  assert.strictEqual(rec.rpcs.length, 1, 'ikinci rpc AÇILMAMALI');

  bırak();
  await p1;
  assert.deepStrictEqual(rec.toasts[0], ['✅ Uygulama kaydedildi', false]);
});

test('guard-02: rpc hatasında buton tekrar aktif olur (retry mümkün)', async () => {
  const { sandbox, btn, rec } = loadScene({
    rpcImpl: () => Promise.resolve({ ok: false, mesaj: 'stok bulunamadı' }),
  });
  await sandbox._protokolUygulaKaydet('H-1', 0);
  assert.strictEqual(btn.disabled, false, 'hata sonrası buton aktif olmalı');
  assert.strictEqual(btn.textContent, 'Kaydet');
  assert.deepStrictEqual(rec.toasts[0], ['stok bulunamadı', true]);
});

test('guard-03: validasyon erken dönüşü butonu kilitlemez', async () => {
  const { sandbox, document, btn, rec } = loadScene();
  document.getElementById('pu-stok').value = ''; // stok seçilmedi
  await sandbox._protokolUygulaKaydet('H-1', 0);
  assert.strictEqual(rec.rpcs.length, 0, 'rpc açılmamalı');
  assert.strictEqual(btn.disabled, false, 'validasyon dönüşü butonu kilitlememeli');
});

test('guard-04: hayvan kartı hızlı uygulaması — aynı koruma + success akışı', async () => {
  let bırak;
  const { sandbox, btn, rec } = loadScene({
    rpcImpl: () => new Promise(res => { bırak = () => res({ ok: true }); }),
  });
  const p1 = sandbox._hayvanHizliUygulaKaydet('H-1');
  const p2 = sandbox._hayvanHizliUygulaKaydet('H-1');
  assert.strictEqual(await p2, undefined, 'ikinci çağrı erken dönmeli (async → Promise<undefined>)');
  assert.strictEqual(rec.rpcs.length, 1, 'ikinci rpc AÇILMAMALI');
  bırak();
  await p1;
  assert.strictEqual(rec.openDet.length, 1, 'success sonrası hayvan kartı yeniden açılmalı');
  assert.strictEqual(btn.disabled, false);
});

test('guard-05: görev-stok tamamlama — hizli_uygulama+gorev_tamamla çifti tek sefer', async () => {
  let bırak;
  const { sandbox, btn, rec } = loadScene({
    // yalnız hizli_uygulama elle çözülür; gorev_tamamla anında ok döner
    rpcImpl: (name) => name === 'hizli_uygulama'
      ? new Promise(res => { bırak = () => res({ ok: true }); })
      : Promise.resolve({ ok: true }),
  });
  const p1 = sandbox._gorevStokTamamlaSubmit('G-1', 'H-1', '');
  const p2 = sandbox._gorevStokTamamlaSubmit('G-1', 'H-1', '');
  assert.strictEqual(await p2, undefined, 'ikinci çağrı erken dönmeli (async → Promise<undefined>)');
  assert.strictEqual(rec.rpcs.length, 1, 'ikinci hizli_uygulama AÇILMAMALI');
  bırak();
  await p1;
  assert.deepStrictEqual(rec.rpcs.map(r => r.name), ['hizli_uygulama', 'gorev_tamamla'],
    'success yolunda tam iki rpc (hizli_uygulama + gorev_tamamla)');
  assert.strictEqual(rec.rpcs[0].args.p_notlar, 'Görev tamamlama');
  assert.strictEqual(rec.toasts[0][0], '✅ Görev tamamlandı');
  assert.strictEqual(btn.textContent, 'Tamamla', 'buton etiketi akışa özgü restore edilmeli');
});

test('guard-06: rpc fırlatınca (exception) buton yine aktif olur', async () => {
  const { sandbox, btn, rec } = loadScene({
    rpcImpl: () => Promise.reject(new Error('ağ hatası')),
  });
  await sandbox._protokolUygulaKaydet('H-1', 0); // fırlatmamalı (catch içerde)
  assert.strictEqual(rec.rpcs.length, 1);
  assert.strictEqual(btn.disabled, false, 'exception sonrası buton aktif olmalı');
  assert.strictEqual(rec.toasts[0][1], true, 'hata toastı bekleniyor');
});
