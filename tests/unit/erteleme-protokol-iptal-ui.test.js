// tests/unit/erteleme-protokol-iptal-ui.test.js — E4-UI (erteleme-genel):
// ovsyncIptal × butonu — eski gorev_log REST PATCH yolu KALKTI; vaka bağlamına
// göre iki dal:
//   A) aktif protokol vakası VAR  → rpc('protokol_iptal', {p_vaka_id,
//      p_yeniden_baslat, p_not}) — onay + özet + isteğe bağlı yeniden başlat;
//   B) vaka YOK (önü-başlangıç; vaka start_first_service_protocol anında
//      açılır) → rpc('gorev_tamamla', {p_gorev_id, p_iptal:true}) T5 dalı.
// Offline (E6): RPC ÇAĞRILMAZ.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const { extractFunctionSource } = require('./support/loadModule.js');

const UI = 'js/ui.js';
const MSJ = 'İnternet yok — erteleme yapılamadı';

function iptalCtxYap({ goruldu = [], vakalar = [], gunler = [], seanslar = [], cevaplar = [], online = true } = {}) {
  const rpcCagri = [], toastlar = [], pullar = [], badge = [], tasks = [], dash = [];
  let cevapIx = 0;
  const konsol = { log() {}, warn() {}, error() {}, info() {}, debug() {} };
  const ctx = {
    Math, JSON, Number, Date,
    console: konsol,
    navigator: { onLine: online },
    getData: async (tablo) => (tablo === 'gorev_log' ? goruldu : tablo === 'cases' ? vakalar : []),
    idbGetAll: async (tablo) => (tablo === 'treatment_days' ? gunler : tablo === 'treatment_day_uygulamalar' ? seanslar : []),
    confirm: () => { const c = cevaplar[cevapIx++]; return c === undefined ? false : c; },
    rpc: async (...a) => { rpcCagri.push(a); return { ok: true, kapanan_gorev: 9, kapanan_seans: 4, iade: 2, yeni_gorev_id: 'yeni-g', yeniden_not: null }; },
    toast: (m, e) => toastlar.push({ m, e }),
    pullTables: async (t) => { pullar.push(t); },
    RPC_TABLES: { protokol_iptal: ['gorev_log', 'islem_log', 'cases', 'treatment_days'] },
    updateTaskBadge: () => badge.push(1),
    loadTasks: (...a) => { tasks.push(a); },
    loadDash: () => { dash.push(1); },
    getUserMessage: e => String(e?.message || e),
    _curTaskFilter: 'today',
    window: {},
  };
  vm.createContext(ctx);
  for (const n of ['_ertelemeOnline', '_ertelemeOfflineGuard', '_protokolIptalAkisi', 'ovsyncIptal']) {
    vm.runInContext(extractFunctionSource(UI, n), ctx, { filename: `${UI}#${n}` });
  }
  return { ctx, rpcCagri, toastlar, pullar, badge, tasks, dash };
}

// ── A dalı: aktif protokol vakası → protokol_iptal RPC ─────────────────

test('E4-1: vaka VAR → onay+yeniden-başlat → rpc("protokol_iptal") parametreleri doğru; özet onayında açık gün/seans sayısı; pull tetiklenir', async () => {
  const g = { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1', tamamlandi: false, iptal: false };
  const v = { id: 'cv1', animal_id: 'h1', status: 'active', protocol_family: 'OVSYNC' };
  const { ctx, rpcCagri, toastlar, pullar } = iptalCtxYap({
    goruldu: [g], vakalar: [v],
    gunler: [{ case_id: 'cv1', tamamlandi: false }, { case_id: 'cv1', tamamlandi: false }, { case_id: 'cv1', tamamlandi: true }],
    seanslar: [{ case_id: 'cv1', uygulanmadi: false, uygulama_tamamlandi_at: null }, { case_id: 'cv1', uygulanmadi: false, uygulama_tamamlandi_at: 'x' }],
    cevaplar: [true, true],          // 1) iptal onayı  2) yeniden başlat EVET
  });
  let onayMetni = '';
  ctx.confirm = (m) => { if (m && m.includes('Protokol vakası')) onayMetni = m; return true; };
  await ctx.ovsyncIptal('g1');
  assert.strictEqual(rpcCagri.length, 1, 'tek RPC çağrısı');
  assert.strictEqual(rpcCagri[0][0], 'protokol_iptal', 'RPC adı');
  const p = rpcCagri[0][1];   // vm-nesne → alan karşılaştırması (prototip tuzağı yok)
  assert.strictEqual(p.p_vaka_id, 'cv1', 'p_vaka_id');
  assert.strictEqual(p.p_yeniden_baslat, true, 'p_yeniden_baslat (canlı protokol_iptal imzası)');
  assert.strictEqual(p.p_not, null, 'p_not');
  assert.ok(onayMetni.includes('2 açık tedavi günü'), 'özet: açık gün sayısı — ' + onayMetni.replace(/\n/g, ' '));
  assert.ok(onayMetni.includes('1 uygulanmamış seans'), 'özet: uygulanmamış seans sayısı');
  assert.ok(onayMetni.includes('iade'), 'özet: stok iadesi bilgisi');
  const t = toastlar.find(x => !x.e);
  assert.ok(t && t.m.includes('Protokol iptal edildi'), 'sonuç toast: ' + (t && t.m));
  assert.ok(t.m.includes('9 görev'), 'kapanan görev sayısı gösterilir');
  assert.ok(t.m.includes('yeniden başlat görevi kuruldu'), 'yeni görev bildirimi');
  assert.deepStrictEqual(pullar, [['gorev_log', 'islem_log', 'cases', 'treatment_days']], 'etkilenen tablolar pull (RPC_TABLES.protokol_iptal seti)');
});

test('E4-2: yeniden başlat HAYIR → p_yeniden_baslat:false', async () => {
  const g = { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1', tamamlandi: false, iptal: false };
  const v = { id: 'cv1', animal_id: 'h1', status: 'active', protocol_family: 'OVSYNC' };
  const { ctx, rpcCagri } = iptalCtxYap({ goruldu: [g], vakalar: [v], cevaplar: [true, false] });
  await ctx.ovsyncIptal('g1');
  assert.strictEqual(rpcCagri.length, 1);
  assert.strictEqual(rpcCagri[0][1].p_yeniden_baslat, false, 'ikinci onay red → yeniden başlat YOK');
});

test('E4-3: iptal onayı RED → RPC ÇAĞRILMAZ', async () => {
  const g = { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1', tamamlandi: false, iptal: false };
  const v = { id: 'cv1', animal_id: 'h1', status: 'active', protocol_family: 'OVSYNC' };
  const { ctx, rpcCagri } = iptalCtxYap({ goruldu: [g], vakalar: [v], cevaplar: [false] });
  await ctx.ovsyncIptal('g1');
  assert.strictEqual(rpcCagri.length, 0, 'onay red → hiçbir RPC çağrılmaz');
});

// ── B dalı: vaka yok (önü-başlangıç) → gorev_tamamla T5 dalı ───────────

test('E4-4: vaka YOK → rpc("gorev_tamamla", {p_iptal:true}) — önü-başlangıç görev kapanışı (RPC+audit)', async () => {
  const g = { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1', tamamlandi: false, iptal: false };
  const { ctx, rpcCagri, toastlar } = iptalCtxYap({ goruldu: [g], vakalar: [], cevaplar: [true] });
  await ctx.ovsyncIptal('g1');
  assert.strictEqual(rpcCagri.length, 1, 'tek RPC');
  assert.strictEqual(rpcCagri[0][0], 'gorev_tamamla', 'önü-başlangıç: gorev_tamamla T5 iptal dalı (REST PATCH değil)');
  assert.strictEqual(rpcCagri[0][1].p_gorev_id, 'g1', 'p_gorev_id');
  assert.strictEqual(rpcCagri[0][1].p_iptal, true, 'p_iptal=true');
  assert.ok(toastlar.some(t => !t.e && t.m.includes('iptal')), 'iptal toast');
});

test('E4-5: görev bulunamazsa → toast + RPC yok', async () => {
  const { ctx, rpcCagri, toastlar } = iptalCtxYap({ goruldu: [], vakalar: [], cevaplar: [true] });
  await ctx.ovsyncIptal('yok-gorev');
  assert.strictEqual(rpcCagri.length, 0);
  assert.ok(toastlar.some(t => t.e && t.m.includes('Görev bulunamadı')), 'hata toast');
});

// ── offline (E6) + eski PATCH yolunun kalktığı ─────────────────────────

test('E4-6: offline → RPC ÇAĞRILMAZ + birleşik E6 toast', async () => {
  const g = { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1', tamamlandi: false, iptal: false };
  const v = { id: 'cv1', animal_id: 'h1', status: 'active', protocol_family: 'OVSYNC' };
  const { ctx, rpcCagri, toastlar } = iptalCtxYap({ goruldu: [g], vakalar: [v], cevaplar: [true, true], online: false });
  await ctx.ovsyncIptal('g1');
  assert.strictEqual(rpcCagri.length, 0, 'offline: RPC ÇAĞRILMAZ');
  assert.ok(toastlar.some(t => t.e && t.m === MSJ), 'birleşik offline toast');
});

test('E4-7: eski gorev_log REST PATCH yolu KALKTI — ovsyncIptal/_protokolIptalAkisi gövdelerinde write(...PATCH) yok', () => {
  for (const ad of ['ovsyncIptal', '_protokolIptalAkisi']) {
    const src = extractFunctionSource(UI, ad);
    assert.ok(!src.includes("write('gorev_log'"), `${ad}: write('gorev_log') YOK`);
    assert.ok(!/,\s*'PATCH'/.test(src), `${ad}: PATCH yöntemi YOK`);
    assert.ok(!src.includes('id=eq.'), `${ad}: REST filtre ifadesi YOK`);
  }
  const ipt = extractFunctionSource(UI, 'ovsyncIptal');
  const akis = extractFunctionSource(UI, '_protokolIptalAkisi');
  assert.ok(akis.includes("rpc('protokol_iptal'"), 'A dalı RPC\'ye kablolu (_protokolIptalAkisi)');
  assert.ok(ipt.includes('_protokolIptalAkisi('), 'ovsyncIptal A dalını akışa devreder');
  assert.ok(ipt.includes("rpc('gorev_tamamla'"), 'B dalı RPC\'ye kablolu');
});

test('E4-8: vaka bağlamı çözümü — yalnız AKTİF + protocol_family\'li vaka A dalına girer', async () => {
  const g = { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1', tamamlandi: false, iptal: false };
  // kapalı protokol vakası + başka hayvanın aktif vakası → A dalına GİRMEMELİ
  const { ctx, rpcCagri } = iptalCtxYap({
    goruldu: [g],
    vakalar: [
      { id: 'ck', animal_id: 'h1', status: 'closed', protocol_family: 'OVSYNC' },
      { id: 'cb', animal_id: 'h2', status: 'active', protocol_family: 'OVSYNC' },
    ],
    cevaplar: [true],
  });
  await ctx.ovsyncIptal('g1');
  assert.strictEqual(rpcCagri.length, 1);
  assert.strictEqual(rpcCagri[0][0], 'gorev_tamamla', 'uygun vaka yok → B dalı (önü-başlangıç iptali)');
});
