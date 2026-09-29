'use strict';
// tests/unit/det-tazeleme-forms.test.js
// kart-tazeleme T3: forms.js çağrı noktalarının temizliği (SPEC §2 R3/R4, §4).
//
// Kontrat:
//   R3  — kayıt sonrası kart KAPANMAZ: suttenKesTekil'in closeDet()'i kalkar;
//         pullTables sonu kancası (T1/T2) kartı yerinde tazeler.
//   R4  — TEK istisna çıkış kaydı: submitCikis closeDet'i pullTables'tan ÖNCE
//         çağırmaya devam eder (dokunulmaz — regresyon pini).
//   A3  — keepTab=koşullu 4 yol (submitAnimal/submitCase/abortKaydet/hayvanNotEkle):
//         kart AÇIKken openDet(id, true) — yerinde tazeleme, aktif sekme korunur;
//         kart KAPALIyken keepTab falsy (ilk açış semantiği, A12).
//   §4  — tohSonuc'un doğrudan openDet'i kalkar (kanca çizer; çifte çizim temizliği).
//   —   — doneTask zaten doğrudan openDet çağırmaz (kanca kapsamı — pin).
//
// Yükleme deseni: forms-validation.test.js setupForms kalıbı (tam js/forms.js +
// extra stub'lar) + hizli-uygulama-guard.test.js rec/monkeypatch kalıbı.
// _detAcik() Task 2 üretimidir (js/ui.js:4322) — sahne bayrağıyla stub'lanır;
// forms.js çalışma-anında global'e erişir (classic script, window property).

const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');
const { getDisplayKupe, bugun } = require('../../js/utils/helpers.js');

// ── forms.js sahne fabrikası ─────────────────────────────────────────
// rec.order: closeDet/pullTables sıralı kayıt (R4 sıra kanıtı — A5).
function loadForms({ kartAcik = false, state = {} } = {}) {
  const rec = {
    rpcs: [], toasts: [], pulls: [], openDet: [], closeDet: [], closeM: [],
    openCaseDet: [], refresh: [],
    renderSafe: 0, renderFromLocal: 0, loadDash: 0, loadAnimals: 0, closeAnimalEdit: 0,
    order: [],
  };
  const document = makeDomStub();

  const input = (id, val) => { const el = makeElement('input'); el.value = val; document.__setEl(id, el); return el; };
  // Çıkış formu (submitCikis)
  input('cx-math-ok', '7'); input('cx-math-ans', '7');
  input('cx-hid', 'H-1'); input('cx-tip', 'Satıldı');
  input('cx-tarih', '2026-09-29'); input('cx-sebep', 'test'); input('cx-fiyat', '100');
  // Not formu (hayvanNotEkle)
  input('not-input', 'Dikkat edilmeli');
  // Vaka formu (submitCase)
  input('d-hid', '12345'); input('d-disease-id', 'DS-1');
  document.__setEl('d-disease-cat', makeElement('div'));
  // Hayvan düzenleme modalı (submitAnimal editId kaynağı)
  const mAnimal = makeElement('div'); mAnimal.dataset.editId = 'H-1'; document.__setEl('m-animal', mAnimal);
  // Hayvan kartı (#det) — kart AÇIK/KAPALI sahnesi (keep-01/temiz-02)
  const det = makeElement('div'); if (kartAcik) det.classList.add('on'); document.__setEl('det', det);

  const stateBag = Object.assign({
    animals: [{ id: 'H-1', kupe_no: '12345', dogum_tarihi: '2026-01-01', suttten_kesme_tarihi: null }],
  }, state);

  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: {
      g: id => document.getElementById(id),
      v: id => { const el = document.getElementById(id); return (el && el.value) || ''; },
      cl: id => { const el = document.getElementById(id); if (el) el.value = ''; },
      esc: s => String(s || ''),
      getState: k => stateBag[k],
      setState: (k, val) => { stateBag[k] = val; },
      toast: (msg, err) => rec.toasts.push([msg, !!err]),
      rpc: async (name, params) => { rec.rpcs.push({ name, params }); return { ok: true, case_id: 'C-9' }; },
      pullTables: async tables => {
        // Array.from: sandbox-realm diziyi host-realm'e çevir (deepStrictEqual prototip şartı)
        rec.pulls.push(Array.from(tables)); rec.order.push(['pull', Array.from(tables)]);
        await new Promise(r => setTimeout(r, 0)); return {};
      },
      renderSafe: () => { rec.renderSafe++; rec.order.push(['renderSafe']); },
      renderFromLocal: async () => { rec.renderFromLocal++; rec.order.push(['renderFromLocal']); },
      closeM: id => { rec.closeM.push(id); rec.order.push(['closeM', id]); },
      closeDet: () => { rec.closeDet.push(1); rec.order.push(['closeDet']); },
      openDet: (...a) => { rec.openDet.push(a); rec.order.push(['openDet', a.slice()]); },
      openCaseDet: id => { rec.openCaseDet.push(id); },
      closeAnimalEdit: () => { rec.closeAnimalEdit++; },
      _islemSonrasiRefresh: () => { rec.refresh.push(1); rec.order.push(['refresh']); },
      loadDash: () => { rec.loadDash++; },
      loadAnimals: async () => { rec.loadAnimals++; },
      // Task 2 üretimi — sahne bayrağıyla: forms.js karta "zaten açık mı"yı buradan sorar
      _detAcik: () => kartAcik,
      getDisplayKupe,
      bugun,
      getIrkValue: () => '',
      erkekKupeUygunMu: () => true,
      hayvanByKupeRef: hid => (hid === '12345' ? { id: 'H-1', kupe_no: '12345' } : null),
      loadDrugsCache: async () => {},
      getData: async () => [{ id: 'T-1', tarih: '2026-01-01' }],
      idbGetAll: async () => [],
      db: {},
    },
  });
  sandbox.navigator.onLine = true;
  sandbox.confirm = () => true;
  sandbox.prompt = () => bugun();
  sandbox._curToh = { id: 'T-1', hayvan_id: 'H-1', sonuc: 'Bekliyor' };
  return { sandbox, rec };
}

// ══════════════════════════════════════════════════════════════════════
// r3-01 (A3/R3): suttenKesTekil — kart KAPANMAZ, pullTables kanca seti
// ══════════════════════════════════════════════════════════════════════
test('r3-01: suttenKesTekil rpc ok → closeDet ÇAĞRILMAZ; pullTables([hayvanlar,gorev_log,protokol_instance]) kanca seti', async () => {
  const { sandbox, rec } = loadForms({ kartAcik: true }); // R3: kart açıkken de kapanmamalı
  await sandbox.suttenKesTekil('H-1', null);
  assert.deepStrictEqual(rec.rpcs.map(r => r.name), ['buzagi_sutten_kesme_onayla']);
  assert.strictEqual(rec.closeDet.length, 0, 'kayıt sonrası kart KAPANMAZ (R3 — kanca tazeler)');
  assert.deepStrictEqual(rec.pulls[0], ['hayvanlar', 'gorev_log', 'protokol_instance'],
    'pull seti kart okuma evreni İÇİ — kanca çizim koşulunu taşır');
  assert.deepStrictEqual(rec.toasts[0], ['✅ 12345 sütten kesildi', false]);
});

// ══════════════════════════════════════════════════════════════════════
// r4-01 (A5/R4): submitCikis — closeDet pullTables'tan ÖNCE (tek istisna, pin)
// ══════════════════════════════════════════════════════════════════════
test('r4-01: submitCikis rpc ok → closeDet pullTables\'tan ÖNCE çağrılır (R4 sıra kanıtı — kanca kartı kapalı görür)', async () => {
  const { sandbox, rec } = loadForms({ kartAcik: true });
  await sandbox.submitCikis(null);
  assert.deepStrictEqual(rec.rpcs.map(r => r.name), ['cikis_yap']);
  assert.strictEqual(rec.closeDet.length, 1, 'çıkışta kart kapanır (tek istisna)');
  const iClose = rec.order.findIndex(e => e[0] === 'closeDet');
  const iPull = rec.order.findIndex(e => e[0] === 'pull');
  assert.ok(iClose !== -1 && iPull !== -1, 'her iki adım da kayıtlı');
  assert.ok(iClose < iPull, 'closeDet pullTables\'tan ÖNCE — kanca kartı kapalı görüp yeniden AÇMAZ');
});

// ══════════════════════════════════════════════════════════════════════
// keep-01 (A3): 4 yol — kart AÇIK → openDet(id, true); kart KAPALI → falsy
// ══════════════════════════════════════════════════════════════════════
const KEEP_YOLLAR = [
  ['abortKaydet',    s => s.abortKaydet('H-1', 'T-1')],
  ['hayvanNotEkle',  s => s.hayvanNotEkle('H-1', null)],
  ['submitAnimal',   s => s.submitAnimal(null)],
  ['submitCase',     s => s.submitCase(null)],
];
for (const [ad, cagir] of KEEP_YOLLAR) {
  test(`keep-01/${ad}: kart AÇIK sahnede openDet(id, true) — aktif sekme korunur`, async () => {
    const { sandbox, rec } = loadForms({ kartAcik: true });
    await cagir(sandbox);
    assert.strictEqual(rec.openDet.length, 1, `${ad} tam bir openDet çağırır`);
    assert.deepStrictEqual(rec.openDet[0], ['H-1', true],
      `${ad} kart-zaten-açıkken keepTab=true geçmeli (_detAcik kararını taşır)`);
  });
  test(`keep-01/${ad}: kart KAPALI sahnede keepTab falsy — ilk açış semantiği (A12)`, async () => {
    const { sandbox, rec } = loadForms({ kartAcik: false });
    await cagir(sandbox);
    assert.strictEqual(rec.openDet.length, 1);
    assert.ok(!rec.openDet[0][1], `${ad} kart kapalıyken keepTab falsy geçmeli`);
  });
}

// ══════════════════════════════════════════════════════════════════════
// temiz-02 (§4): tohSonuc — doğrudan openDet YOK (kanca çizer)
// ══════════════════════════════════════════════════════════════════════
test('temiz-02: tohSonuc (Boş, kart açık) → doğrudan openDet ÇAĞRILMAZ; closeM + renderFromLocal + pull korunur', async () => {
  const { sandbox, rec } = loadForms({ kartAcik: true });
  await sandbox.tohSonuc('Boş', null);
  assert.deepStrictEqual(rec.rpcs.map(r => r.name), ['tohumlama_sonuc_bos']);
  assert.strictEqual(rec.openDet.length, 0,
    'doğrudan openDet YOK (çifte çizim temizliği — pullTables sonu kancası çizer)');
  assert.ok(rec.closeM.includes('m-toh-det'), 'modal kapanışı korunur');
  assert.strictEqual(rec.renderFromLocal, 1, 'renderFromLocal korunur');
  assert.deepStrictEqual(rec.pulls[0], ['tohumlama', 'hayvanlar', 'islem_log'],
    'pull seti kart okuma evreni İÇİ — kanca çizim koşulunu taşır');
});

// ══════════════════════════════════════════════════════════════════════
// done-01: doneTask — doğrudan openDet yok (kanca kapsamı, pin)
// ══════════════════════════════════════════════════════════════════════
test('done-01: doneTask rpc ok → doğrudan openDet yok; pullTables([gorev_log,hayvanlar]) + _islemSonrasiRefresh + loadDash korunur', async () => {
  const { sandbox, rec } = loadForms({ kartAcik: true });
  const btn = makeElement('button');
  await sandbox.doneTask('G-1', 'H-1', '', '', '', btn);
  assert.deepStrictEqual(rec.rpcs.map(r => r.name), ['gorev_tamamla']);
  assert.strictEqual(rec.openDet.length, 0, 'doğrudan openDet YOK — kanca kapsamı');
  assert.deepStrictEqual(rec.pulls[0], ['gorev_log', 'hayvanlar'],
    'pull seti kart okuma evreni İÇİ — kanca çizim koşulunu taşır');
  assert.strictEqual(rec.refresh.length, 1, '_islemSonrasiRefresh korunur');
  assert.strictEqual(rec.loadDash, 1, 'loadDash korunur');
});
