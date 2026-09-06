'use strict';
// tests/unit/protokol-dismiss-gorev.test.js
// _protokolDismiss bir adımı ✕ ile dismiss ettiğinde artık yalnız
// protokol_dismiss upsert'i yapmamalı: aynı hayvan+etken için gorev_log'daki
// AÇIK görevler detayIptal deseniyle (tamamlandi+iptal PATCH, alt görevler
// parent_id ile) kapatılmalı, ardından görev verisi tazelenmeli.
// Kök neden: loadTasks (js/ui.js loadTasks) dismiss kaydına hiç bakmaz;
// protokol_eksik_tara dismiss'u görünce uyarıyı bastırıyor ama görev listede
// kalıyordu.
//
// Yükleme deseni: tests/unit/ui-pure.test.js ile aynı — loadBrowserModule ile
// tam js/ui.js yüklenir, api.js (write/getData/pullTables/db) ve helpers.js
// (toast) global'leri test stubu olarak enjekte edilir.
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

// ── db.from() stubu ──────────────────────────────────────────────────
// supabase-js PostgrestBuilder thenable'dır: await builder → { data, error }.
// gorev_log için select/eq zinciri; diğer tablolar (protokol_dismiss) için
// upsert destekler. Gelen filtreler test doğrulaması için kaydedilir.
function makeDbStub({ upsertError = null, gorevler = [], gorevQueryError = null } = {}) {
  const calls = { upserts: [], queries: [] };
  const db = {
    from(table) {
      if (table === 'gorev_log') {
        const filters = [];
        const builder = {
          select(cols) { builder._cols = cols; return builder; },
          eq(k, v) { filters.push([k, v]); return builder; },
          then(res, rej) {
            calls.queries.push({ table, cols: builder._cols, filters });
            const result = gorevQueryError
              ? { data: null, error: gorevQueryError }
              : { data: gorevler, error: null };
            return Promise.resolve(result).then(res, rej);
          },
        };
        return builder;
      }
      return {
        upsert: async (payload, opts) => {
          calls.upserts.push({ table, payload, opts });
          return { data: null, error: upsertError };
        },
      };
    },
  };
  return { db, calls };
}

// ── Tam kurulum: ui.js'i stub global'lerle yükle, dismiss çağrısını hazırla ──
function loadDismissScene({ dbArgs = {}, uyarilar = [], gorevIdb = [], dom = null } = {}) {
  const { db, calls } = makeDbStub(dbArgs);
  const rec = {
    writeCalls: [], pulls: [], toasts: [], refresh: [],
    loadTasks: [], loadDash: [],
  };
  const document = dom || makeDomStub();
  const { sandbox } = loadBrowserModule('js/ui.js', {
    dom: document,
    extra: {
      db,
      toast: (msg, err) => rec.toasts.push([msg, !!err]),
      confirm: () => true,
      write: async (table, data, method, filter) => {
        rec.writeCalls.push({ table, data, method, filter });
        return [data];
      },
      getData: async (table, fn) => gorevIdb.filter(fn),
      pullTables: async (tables) => { rec.pulls.push(tables); return {}; },
      rpc: async () => ({ data: [], error: null }),
    },
  });
  // ui.js içi çağrıların çözüleceği in-sandbox fonksiyonları izole et
  sandbox._islemSonrasiRefresh = async () => { rec.refresh.push(1); };
  sandbox.loadTasks = async (...a) => { rec.loadTasks.push(a); };
  sandbox.loadDash = async () => { rec.loadDash.push(1); };
  // _curTaskFilter ui.js'te bildirimsiz implicit global'dir (bkz. loadTasks:604);
  // tarayıcıda görevler sayfası açıldığında oluşur. tasks-body elementi olan
  // sahneler bunu set etmeli — yoksa referans okuması ReferenceError verir
  // (tarayıcıda da loadTasks hiç koşmadıysa aynıdır; o sahnede tasks-body de yoktur).
  sandbox._curTaskFilter = 'today';
  sandbox.window.__protokolUyarilar = uyarilar;
  return { sandbox, document, calls, rec };
}

// Doğum protokolü görevi üretici (migration 20260605000001 deseni)
function gorev(id, etken, extra = {}) {
  return {
    id, hayvan_id: 'H-1', gorev_tipi: 'ILAC', aciklama: 'test ' + id,
    hedef_tarih: '2026-09-01', tamamlandi: false, kaynak: 'DOGUM-H-1',
    etken_kod: etken, iptal: false, ...extra,
  };
}

test('gorev-dismiss-01: dismiss upsert sonrası eşleşen açık görevler PATCH ile kapanır (tamamlandi+iptal)', async () => {
  const ana = gorev('g-ana', 'PG');
  const { sandbox, calls, rec } = loadDismissScene({
    uyarilar: [{ hayvan_id: 'H-1', etken_kod: 'PG', protokol: 'DOGUM' }],
    dbArgs: { gorevler: [ana] },
  });
  await sandbox._protokolDismiss(0);

  // upsert bugünkü gibi yapıldı
  assert.strictEqual(calls.upserts.length, 1, 'protokol_dismiss upsert bekleniyor');
  assert.strictEqual(calls.upserts[0].payload.etken_kod, 'PG');
  // gorev_log açık görev sorgusu doğru filtrelerle yapıldı
  assert.strictEqual(calls.queries.length, 1, 'gorev_log select bekleniyor');
  assert.deepStrictEqual(calls.queries[0].filters, [
    ['hayvan_id', 'H-1'], ['etken_kod', 'PG'], ['tamamlandi', false], ['iptal', false],
  ]);
  // eşleşen görev detayIptal deseniyle PATCH'lenir
  const patchAna = rec.writeCalls.find(w => w.filter === `id=eq.${ana.id}`);
  assert.ok(patchAna, 'ana görev PATCH çağrısı yok');
  assert.strictEqual(patchAna.method, 'PATCH');
  assert.strictEqual(patchAna.table, 'gorev_log');
  assert.strictEqual(patchAna.data.tamamlandi, true);
  assert.strictEqual(patchAna.data.iptal, true);
  assert.ok(patchAna.data.tamamlanma_tarihi, 'tamamlanma_tarihi doldurulmalı (detayIptal deseni)');
});

test('gorev-dismiss-02: alt görevler (parent_id) de kapatılır', async () => {
  const ana = gorev('g-ana', 'PG');
  const alt = gorev('g-alt', 'PG', { parent_id: 'g-ana' });
  const kapaliAlt = gorev('g-alt-kapali', 'PG', { parent_id: 'g-ana', tamamlandi: true });
  const { sandbox, rec } = loadDismissScene({
    uyarilar: [{ hayvan_id: 'H-1', etken_kod: 'PG', protokol: 'DOGUM' }],
    dbArgs: { gorevler: [ana] },
    gorevIdb: [alt, kapaliAlt], // getData (IndexedDB) içeriği — detayIptal deseni
  });
  await sandbox._protokolDismiss(0);

  const patchAlt = rec.writeCalls.find(w => w.filter === `id=eq.${alt.id}`);
  assert.ok(patchAlt, 'alt görev PATCH çağrısı yok');
  assert.strictEqual(patchAlt.data.tamamlandi, true);
  assert.strictEqual(patchAlt.data.iptal, true);
  // zaten tamamlanmış alt göreve dokunulmaz
  assert.ok(!rec.writeCalls.find(w => w.filter === `id=eq.${kapaliAlt.id}`), 'tamamlanmış alt göreve PATCH yapılmamalı');
  // hem ana hem alt kapatıldı
  assert.strictEqual(rec.writeCalls.length, 2, 'tam 2 PATCH bekleniyor (ana+alt)');
});

test('gorev-dismiss-03: eşleşen görev yoksa write çağrılmaz, akış hatasız', async () => {
  const { sandbox, rec } = loadDismissScene({
    uyarilar: [{ hayvan_id: 'H-1', etken_kod: 'PG', protokol: 'DOGUM' }],
    dbArgs: { gorevler: [] },
  });
  await sandbox._protokolDismiss(0); // fırlatmamalı
  assert.strictEqual(rec.writeCalls.length, 0, 'eşleşme yokken PATCH yapılmamalı');
  assert.strictEqual(rec.refresh.length, 1, 'dismiss akışı (refresh) bozulmamalı');
  assert.deepStrictEqual(rec.toasts[0], ['Uyarı geçersiz kılındı', false]);
});

test('gorev-dismiss-04: upsert hatalıysa görev PATCH yapılmaz (erken-return korunur)', async () => {
  const ana = gorev('g-ana', 'PG');
  const { sandbox, rec } = loadDismissScene({
    uyarilar: [{ hayvan_id: 'H-1', etken_kod: 'PG', protokol: 'DOGUM' }],
    dbArgs: { upsertError: { message: 'rls hatası' }, gorevler: [ana] },
  });
  await sandbox._protokolDismiss(0);
  assert.strictEqual(rec.writeCalls.length, 0, 'upsert hatasında görev PATCH olmamalı');
  assert.strictEqual(rec.pulls.length, 0, 'upsert hatasında görev pull olmamalı');
  assert.strictEqual(rec.refresh.length, 0, 'upsert hatasında akış erken dönmeli');
  assert.strictEqual(rec.toasts.length, 1);
  assert.strictEqual(rec.toasts[0][1], true, 'hata toastı bekleniyor');
});

test('gorev-dismiss-05: dismiss sonrası görev tazelemesi — pullTables([gorev_log]) + loadTasks/loadDash', async () => {
  const ana = gorev('g-ana', 'PG');
  const dom = makeDomStub();
  dom.__setEl('tasks-body', makeElement('div')); // görev ekranı açık senaryosu
  const { sandbox, rec } = loadDismissScene({
    dom,
    uyarilar: [{ hayvan_id: 'H-1', etken_kod: 'PG', protokol: 'DOGUM' }],
    dbArgs: { gorevler: [ana] },
  });

  await sandbox._protokolDismiss(0);
  assert.ok(rec.pulls.some(p => p.length === 1 && p[0] === 'gorev_log'),
    "pullTables(['gorev_log']) çağrısı bekleniyor");
  assert.strictEqual(rec.loadTasks.length, 1, 'loadTasks tazelemesi bekleniyor');
  assert.strictEqual(rec.loadDash.length, 1, 'loadDash tazelemesi bekleniyor');
});

test('gorev-dismiss-06: etken_kod boş (MANUAL dismiss) ise görev eşleştirme yapılmaz', async () => {
  const { sandbox, calls, rec } = loadDismissScene({
    uyarilar: [{ hayvan_id: 'H-1', etken_kod: '', protokol: 'DOGUM' }],
    dbArgs: { gorevler: [gorev('g-ana', 'PG')] },
  });
  await sandbox._protokolDismiss(0);
  // dismiss kaydı yine yazılır (bugünkü davranış)
  assert.strictEqual(calls.upserts.length, 1);
  assert.strictEqual(calls.upserts[0].payload.etken_kod, 'MANUAL');
  // ama görev sorgusu/PATCH/pull hiç yapılmaz
  assert.strictEqual(calls.queries.length, 0, 'gorev_log sorgusu yapılmamalı');
  assert.strictEqual(rec.writeCalls.length, 0, 'görev PATCH yapılmamalı');
  assert.strictEqual(rec.pulls.length, 0, "pullTables(['gorev_log']) yapılmamalı");
  assert.strictEqual(rec.refresh.length, 1, 'dismiss akışı (refresh) bozulmamalı');
});
