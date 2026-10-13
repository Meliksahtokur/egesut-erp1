'use strict';
const test = require('node:test'); const assert = require('node:assert');
const { extractFunctionSource } = require('./support/loadModule.js');
test('pg-kapi-sarmal-kilidi', () => {
  for (const [dosya, fn] of [['js/ui.js', '_tedaviGunExecute'], ['js/ui.js', 'caseDayTamamla'],
      ['js/ui.js', 'caseDrugKaydet'], ['js/ui.js', 'caseSablonUygula'], ['js/forms.js', 'submitCase']]) {
    assert.ok(extractFunctionSource(dosya, fn).includes('_pgKapiHata('), fn + ': PG kapı sarmalı (§18.8)');
  }
});
// Madde 2 (IMPL-A-F1): submitCase — PG reddinde return YOK, akış kapanışa düşer.
// KAPI madde 2: create_case commit olmuşken closeM/_seciliSablonId/pullTables/openCaseDet atlanmamalı.
// F2 (KAPI-2 işaretli 1): dilim taraması — HER kapıdan sonraki ilk tazeleme satırına
// kadar return YOK; kapı→kapanış (closeM) taraması İKİ kapıda da (:831 ve :887).
test('pg-return-kapanis-kilidi', () => {
  const govde = extractFunctionSource('js/forms.js', 'submitCase');
  const satirlar = govde.split('\n');
  const kapiIdxler = satirlar
    .map((s, i) => (s.includes('_pgKapiHata(') ? i : -1))
    .filter(i => i !== -1);
  assert.ok(kapiIdxler.length >= 2,
    'submitCase: iki PG kapısı sarmalı beklenir (:831 ve :887), bulunan: ' + kapiIdxler.length);
  for (const i of kapiIdxler)
    assert.ok(!satirlar[i].includes('return'), 'PG kapısı satırında return YOK: ' + satirlar[i].trim());
  for (const parca of ["closeM(", '_seciliSablonId', 'pullTables(', 'openCaseDet('])
    assert.ok(govde.includes(parca), 'kapanış erişilebilir: ' + parca);
  // F2: HER kapı için kapı satırından sonraki ilk tazeleme (pullTables) satırına
  // kadarki DİLİMDE return YOK (kapı satırı ±2 dilimi YASAK — mB çok satırlı return'ü kaçırıyordu).
  for (const kapi of kapiIdxler) {
    const tazele = satirlar.findIndex((s, i) => i > kapi && s.includes('pullTables('));
    assert.ok(tazele > kapi, 'kapı satırı ' + (kapi + 1) + ': ardından tazeleme (pullTables) gelir');
    const dilim = satirlar.slice(kapi, tazele + 1).join('\n');
    assert.ok(!/\breturn\b/.test(dilim),
      'kapı→tazeleme diliminde return YOK (satır ' + (kapi + 1) + '→' + (tazele + 1) + ')');
    // F2: kapı→kapanış (closeM) taraması yalnız ilk kapıda değil, İKİ kapıda da.
    const kapanis = satirlar.findIndex((s, i) => i > kapi && s.includes('closeM('));
    assert.ok(kapanis > kapi, 'kapı satırı ' + (kapi + 1) + ': ardından kapanış (closeM) gelir');
    assert.ok(kapanis < tazele, 'kapı satırı ' + (kapi + 1) + ': kapanış tazeleme öncesinde');
    const kapiKapanis = satirlar.slice(kapi, kapanis + 1).join('\n');
    assert.ok(!/\breturn\b/.test(kapiKapanis),
      'kapı→kapanış diliminde return YOK (satır ' + (kapi + 1) + '→' + (kapanis + 1) + ')');
  }
});
// Madde 3 (IMPL-A-F1): caseDrugKaydet — PG reddinde döngüden break, tazeleme yine koşar.
// KAPI madde 3: tazeleme (:13500-13509) atlanırsa tekrar Kaydet mükerrer ilaç yazar.
// F2 (KAPI-2 işaretli 1): kapı satırı ±2 dilimi YASAK — kapı satırından tazeleme
// satırına kadarki DİLİMDE return tara (mA tazeleme-öncesi return'ü kaçırıyordu).
test('drug-return-kilidi', () => {
  const govde = extractFunctionSource('js/ui.js', 'caseDrugKaydet');
  const satirlar = govde.split('\n');
  const kapiIdx = satirlar.findIndex(s => s.includes('_pgKapiHata('));
  assert.ok(kapiIdx !== -1, 'caseDrugKaydet: PG kapısı sarmalı (§18.8)');
  const tazeleIdx = satirlar.findIndex((s, i) => i > kapiIdx && s.includes('pullTables('));
  assert.ok(tazeleIdx > kapiIdx, 'kapıdan sonra tazeleme (pullTables) gelir');
  const dilim = satirlar.slice(kapiIdx, tazeleIdx + 1).join('\n');
  assert.ok(!/\breturn\b/.test(dilim),
    'kapı→tazeleme diliminde return YOK (tazeleme atlanırsa mükerrer ilaç)');
  assert.ok(govde.includes('break'), 'PG reddinde döngüden break ile çıkılır');
  // Tazeleme bloğu döngü sonrasında koşar.
  const forIdx = satirlar.findIndex(s => s.includes('for (const item of secililar)'));
  assert.ok(forIdx !== -1 && tazeleIdx !== -1 && tazeleIdx > forIdx,
    'tazeleme (pullTables) döngü sonrasında');
  assert.ok(/kapıda durdu/.test(govde), 'toast k/n sayısıyla kapıda durduğunu bildirir');
});
// ── Faz 4 (Kapı 5 ekleri 1-2): Veri Trafiği eş-op kuralı ─────────────────────
// dataTrafficSil ilaç silerken _esBul ile eşi de siler; dataTrafficTekGonder
// kuyrukta ilacı bekleyen eş stok satırını tek başına göndermez; TekGonder
// catch'inde düz toast'tan ÖNCE _pgKapiHata (onaylı tekrar kaydı düşürür).
// RPC_MAP tek kaynak (api.js); ui.js yerel kopyası YOK.
// Adli mutantlar: MUT-TG-ESBUL-SONUCSUZ, MUT-TG-ES-TEK, MUT-SIL-ES-YETIM.
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');
const { makeDomStub } = require('./support/loadModule.js');

const F4_KOK = path.join(__dirname, '..', '..');
const F4_UI_YOLU = () => process.env.UI_YOLU || path.join(F4_KOK, 'js/ui.js');

function f4KaynakCek(abs, ad) {
  const src = fs.readFileSync(abs, 'utf8');
  const start = src.search(new RegExp('^\\s*(?:async\\s+)?function\\s+' + ad + '\\s*\\(', 'm'));
  if (start === -1) throw new Error('kirmizi: function ' + ad + ' yok (' + abs + ')');
  let i = src.indexOf('{', start);
  let depth = 0, str = null, esc = false, lc = false, bc = false;
  for (; i < src.length; i++) {
    const c = src[i], n = src[i + 1];
    if (lc) { if (c === '\n') lc = false; continue; }
    if (bc) { if (c === '*' && n === '/') { bc = false; i++; } continue; }
    if (str) {
      if (esc) { esc = false; continue; }
      if (c === '\\') { esc = true; continue; }
      if (c === str) str = null;
      continue;
    }
    if (c === '/' && n === '/') { lc = true; i++; continue; }
    if (c === '/' && n === '*') { bc = true; i++; continue; }
    if (c === "'" || c === '"' || c === '`') { str = c; continue; }
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) return src.slice(start, i + 1); }
  }
  throw new Error(ad + ': govde kapanmadi');
}

// api.js sözleşmesi (plan Faz 4 Interfaces): _esBul(q, op) -> op|null —
// RPC'ye yönelen her drug_administrations POST'unun eş stok_hareket op'u
// (notlar 'DrugAdmin:' + ilaç id); değilse null.
function f4EsBul(q, op) {
  if (!op || op.table !== 'drug_administrations' || op.method !== 'POST') return null;
  const id = op.data && op.data[0] && op.data[0].id;
  if (!id) return null;
  return (q || []).find(o => o.table === 'stok_hareket' && o.data && o.data[0] && o.data[0].notlar === 'DrugAdmin:' + id) || null;
}

function f4TrafikCtx(kanca = {}) {
  const adlar = ['dataTrafficTekGonder', 'dataTrafficSil', 'dataTrafficYenile',
    '_pgKapiHata', '_pgKapiAc', '_pgKapiKapat', '_pgKapiOnayliTekrar'];
  const govde = adlar.map(a => f4KaynakCek(F4_UI_YOLU(), a)).join('\n');
  const doc = makeDomStub();
  const histYigin = [null]; let histIdx = 0;
  const hist = {
    get length() { return histYigin.length; },
    get state() { return histYigin[histIdx]; },
    pushState(s) { histYigin.splice(histIdx + 1); histYigin.push(s); histIdx++; },
    replaceState(s) { histYigin[histIdx] = s; },
    back() { if (histIdx > 0) histIdx--; },
  };
  const toasts = [];
  const rpcCagrilari = [];
  const kuyruk = kanca.kuyruk || [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, history: hist, window: {},
    esc: s => String(s ?? ''), fmtTarih: s => String(s ?? ''),
    toast: m => { toasts.push(String(m)); },
    confirm: () => true,
    getQueue: async () => kuyruk,
    removeFromQueue: async qid => {
      const i = kuyruk.findIndex(o => o._qid === qid);
      if (i !== -1) kuyruk.splice(i, 1);
    },
    // RPC_MAP tek kaynak api.js (RPC_TABLES yanı) — test, güncel içeriğin
    // birebirini globalden verir; ui.js yereli kalkar.
    RPC_MAP: {
      hayvanlar: { POST: 'hayvan_ekle', PATCH: 'hayvan_guncelle' },
      tohumlama: { POST: 'tohumlama_kaydet' },
      dogum: { POST: 'dogum_kaydet' },
      gorev_log: { PATCH: 'gorev_tamamla' },
      stok_hareket: { POST: 'stok_hareket_ekle' },
      kizginlik_log: { POST: 'kizginlik_kaydet', DELETE: 'kizginlik_sil' },
      cases: { POST: 'create_case' },
      drug_administrations: { POST: 'add_drug_administration', PATCH: 'update_drug_administration' },
    },
    RPC_TABLES: {},
    _esBul: f4EsBul,
    buildRpcParams: (ad, veri) => ({ ...(veri || {}) }),
    rpc: kanca.rpc || (async (ad, p) => { rpcCagrilari.push({ ad, p }); return { ok: true }; }),
    pullTables: async () => ({ ok: [], failed: [] }),
    renderSafe: () => {},
    updateSyncBar: () => {},
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'pg-trafik-ctx' });
  return { ctx, doc, hist, toasts, rpcCagrilari, kuyruk };
}

// Gerçek çevrimdışı caseDrugKaydet biçimi (js/ui.js:13695-13713).
const f4IlacOp = (qid, id) => ({
  _qid: qid, table: 'drug_administrations', method: 'POST',
  data: [{ id, day_id: 'gun-1', stok_id: 's1', dose: 2, unit: 'ml' }],
});
const f4EsOp = (qid, id) => ({
  _qid: qid, table: 'stok_hareket', method: 'POST',
  data: [{ id: 'sh-' + id, stok_id: 's1', tur: 'Ilac', miktar: 2, notlar: 'DrugAdmin:' + id, iptal: false }],
});

function f4KutuyuBagla(doc) {
  const box = doc.body.children.find(e => e && e.id === 'pg-kapi-bs');
  assert.ok(box, 'pg-kapi-bs kutusu DOMda');
  doc.__setEl('pg-kapi-bs', box);
  return box;
}

test('rpc-map-tek-kaynak', () => {
  const src = f4KaynakCek(F4_UI_YOLU(), 'dataTrafficTekGonder');
  assert.ok(!/const RPC_MAP\s*=\s*\{/.test(src), 'ui.js yerel RPC_MAP kopyasi YOK (tek kaynak api.js)');
  assert.ok(/RPC_MAP\[/.test(src), 'api.js RPC_MAP globali kullanilir');
});

test('tekgonder-es-birlikte-duser', async () => {
  // MUT-TG-ESBUL-SONUCSUZ adli: _esBul sonucu kullanilmazsa es kuyrukta kalir → FAIL.
  const t = f4TrafikCtx({ kuyruk: [f4IlacOp(11, 'd1'), f4EsOp(12, 'd1'),
    { _qid: 16, table: 'stok', method: 'POST', data: [{ id: 's9' }] }] });
  await vm.runInContext('dataTrafficTekGonder(11)', t.ctx);
  assert.deepStrictEqual(t.kuyruk.map(o => o._qid), [16], 'ilac + es birlikte duser');
  assert.strictEqual(t.rpcCagrilari.length, 1);
  assert.strictEqual(t.rpcCagrilari[0].ad, 'add_drug_administration');
});

test('tekgonder-yalniz-esi-gondermez', async () => {
  // MUT-TG-ES-TEK adli: yalniz es gonderilirse FAIL.
  const t = f4TrafikCtx({ kuyruk: [f4IlacOp(11, 'd1'), f4EsOp(12, 'd1')] });
  await vm.runInContext('dataTrafficTekGonder(12)', t.ctx);
  assert.strictEqual(t.rpcCagrilari.length, 0, 'es tek basina gonderilmez');
  assert.deepStrictEqual(t.kuyruk.map(o => o._qid), [11, 12], 'kuyruk degismez');
  assert.ok(t.toasts.some(m => /ilaç/i.test(m)), 'uyari toast: ' + JSON.stringify(t.toasts));
});

test('sil-esi-de-siler', async () => {
  // MUT-SIL-ES-YETIM adli: es silinmezse kuyrukta kalir → FAIL.
  const t = f4TrafikCtx({ kuyruk: [f4IlacOp(11, 'd1'), f4EsOp(12, 'd1'),
    { _qid: 16, table: 'stok', method: 'POST', data: [{ id: 's9' }] }] });
  await vm.runInContext('dataTrafficSil(11)', t.ctx);
  assert.deepStrictEqual(t.kuyruk.map(o => o._qid), [16], 'ilac silinirken esi de silinir');
});

test('tekgonder-pg-kapi-onay-tekrar', async () => {
  // TekGonder catch'inde _pgKapiHata: PG reddinde kayit + es kuyrukta kalir;
  // modal onay dugmesi p_pg_onay===true ile tekrarlar, basarida ikisi duser.
  const rpcCagrilari = [];
  const t = f4TrafikCtx({
    kuyruk: [f4IlacOp(11, 'd1'), f4EsOp(12, 'd1')],
    rpc: async (ad, p) => {
      rpcCagrilari.push({ ad, p });
      if (p && p.p_pg_onay === true) return { ok: true, id: 'srv-d1' };
      throw new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01"}');
    },
  });
  await vm.runInContext('dataTrafficTekGonder(11)', t.ctx);
  const box = f4KutuyuBagla(t.doc);
  assert.deepStrictEqual(t.kuyruk.map(o => o._qid), [11, 12], 'PG reddi: kayit + es kuyrukta kalir');
  t.doc.__setEl('pg-kapi-gerekce', { value: 'kontrol negatif' });
  const m = /id="pg-kapi-onayla"[^>]*onclick="([^"]+)"/.exec(box.innerHTML);
  assert.ok(m, 'onay dugmesi kablolu');
  await vm.runInContext(m[1], t.ctx);
  const onayli = rpcCagrilari.filter(c => c.p && c.p.p_pg_onay === true);
  assert.strictEqual(onayli.length, 1, 'onayli tekrar p_pg_onay===true ile gider');
  assert.deepStrictEqual(t.kuyruk.map(o => o._qid), [], 'onayli tekrar basarili: kayit + es duser');
});

// PLAN ### Faz 4 Step 1 birebir (review-düzeltme: TekGonder sarmalı bu dosyada;
// davranış ölçümü 'tekgonder-*' testlerinde — Kapı 5 eki 2).
test('replay-pg-kapi-sarmal', () => {
  const src = extractFunctionSource('js/ui.js', 'dataTrafficTekGonder');
  assert.ok(src.includes('_pgKapiHata('), 'PG kapı sarmalı');
  assert.ok(src.includes('_esBul('), 'manuel gönderimde eş stok_hareket op birlikte düşer (KAPI-4 #1)');
});

// Madde 6 (KAPI-2 işaretli 6): ilk kalem PG'de durursa (eklenen=0) toast nötr — ✅ YOK.
test('drug-pg-toast-notr-kilidi', () => {
  const govde = extractFunctionSource('js/ui.js', 'caseDrugKaydet');
  const satirlar = govde.split('\n');
  const toastIdx = satirlar.findIndex(s => s.includes('pgDurdu') && s.includes('toast('));
  assert.ok(toastIdx !== -1, 'PG-durma (pgDurdu) toast satırı bulunur');
  const satir = satirlar[toastIdx];
  // Koşulsuz '✅ ' öneki YASAK: toast satırı eklenen sayısına koşullu olmalı.
  assert.ok(/eklenen/.test(satir), 'pgDurdu toast eklenen sayısına koşullu olmalı: ' + satir.trim());
  // eklenen=0 kolundaki literal ✅ taşımamalı (üç yaygın koşul yazımı kapsanır).
  const l = "('[^']*'|\"[^\"]*\")";
  let sifirKol = null;
  let m = satir.match(new RegExp('eklenen\\s*===\\s*0\\s*\\?\\s*' + l + '\\s*:\\s*' + l));
  if (m) sifirKol = m[1];
  else if ((m = satir.match(new RegExp('eklenen\\s*>\\s*0\\s*\\?\\s*' + l + '\\s*:\\s*' + l)))) sifirKol = m[2];
  else if ((m = satir.match(new RegExp('eklenen\\s*\\?\\s*' + l + '\\s*:\\s*' + l)))) sifirKol = m[2];
  assert.ok(sifirKol !== null, 'eklenen=0 kolu seçilebilir olmalı: ' + satir.trim());
  assert.ok(!sifirKol.includes('✅'), 'eklenen=0 toast nötr (✅ YOK): ' + sifirKol);
});
