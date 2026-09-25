// tests/unit/cd-protokol-iptal-ui.test.js — C-1 (E4 onarım, 2026-09-25):
// 'Protokolü iptal et' bugün yalnız AÇIK OVSYNC_BASLAT kartındaki ✕ butonundan
// erişilebilirdi; protokol başlayınca (görev tamamlanır) yüzey kalmıyordu —
// E4 ölçütü 'aktif ovsync vakasında Protokolü iptal et' karşılanmıyordu.
// Yüzey: vaka detayındaki #cd-protokol-iptal-btn — AKTİF + protocol_family'li
// vakada görünür (openCaseDet + ertelemeBtnGuncelle; E0 cd-kaydir-btn deseni),
// akış mevcut _protokolIptalAkisi A dalına devreder (rpc protokol_iptal) —
// İKİNCİ AKIŞ KOPYASI YOK. Offline (E6): buton gizli; yine tetiklenirse
// toast + RPC ÇAĞRILMAZ.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const { extractFunctionSource, makeElement } = require('./support/loadModule.js');

const UI = 'js/ui.js';
const MSJ = 'İnternet yok — erteleme yapılamadı';

// Akış ctx'i — cdProtokolIptal + _protokolIptalAkisi + E6 guard kardeşleri
// (erteleme-protokol-iptal-ui iptalCtxYap deseni + _curCase/closeM eklemesi).
function cdIptalCtxYap({ vaka = null, gunler = [], seanslar = [], cevaplar = [], online = true } = {}) {
  const rpcCagri = [], toastlar = [], kapatilan = [];
  let cevapIx = 0;
  const ctx = {
    Math, JSON, Number, Date,
    console: { log() {}, warn() {}, error() {}, info() {}, debug() {} },
    navigator: { onLine: online },
    idbGetAll: async (tablo) => (tablo === 'treatment_days' ? gunler : tablo === 'treatment_day_uygulamalar' ? seanslar : []),
    confirm: () => { const c = cevaplar[cevapIx++]; return c === undefined ? false : c; },
    rpc: async (...a) => { rpcCagri.push(a); return { ok: true, kapanan_gorev: 3, kapanan_seans: 2, iade: 1, yeni_gorev_id: null, yeniden_not: null }; },
    toast: (m, e) => toastlar.push({ m, e }),
    pullTables: async () => {},
    RPC_TABLES: { protokol_iptal: ['gorev_log', 'islem_log', 'cases', 'treatment_days'] },
    updateTaskBadge: () => {},
    loadTasks: () => {},
    loadDash: () => {},
    _curTaskFilter: 'today',
    getUserMessage: e => String(e?.message || e),
    closeM: (id) => { kapatilan.push(id); },
    window: {},
    _curCase: vaka,
  };
  vm.createContext(ctx);
  for (const n of ['_ertelemeOnline', '_ertelemeOfflineGuard', '_protokolIptalAkisi', 'cdProtokolIptal']) {
    vm.runInContext(extractFunctionSource(UI, n), ctx, { filename: `${UI}#${n}` });
  }
  return { ctx, rpcCagri, toastlar, kapatilan };
}

// Görünürlük ctx'i — ertelemeBtnGuncelle + _ertelemeOnline kardeşi (E0-UI-3 deseni)
function gorunurlukFn(ctxExtra) {
  const ctx = { Math, JSON, Number, ...ctxExtra };
  vm.createContext(ctx);
  vm.runInContext(extractFunctionSource(UI, '_ertelemeOnline'), ctx, { filename: `${UI}#_ertelemeOnline` });
  vm.runInContext(extractFunctionSource(UI, 'ertelemeBtnGuncelle'), ctx, { filename: `${UI}#ertelemeBtnGuncelle` });
  return ctx.ertelemeBtnGuncelle;
}

function mkDoc(cdProtokol, cdKaydir) {
  return {
    getElementById: id => (id === 'cd-protokol-iptal-btn' ? cdProtokol : id === 'cd-kaydir-btn' ? cdKaydir : null),
    querySelectorAll: () => [],
  };
}

// ── Yüzey: index.html kablolaması ──────────────────────────────────────

test('C1-1: index.html — buton cd-gun-bolum içinde (aktif-vaka alanı), display:none başlar, onclick kablolu', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  const bolum = html.slice(html.indexOf('id="cd-gun-bolum"'), html.indexOf('id="cd-kapat-bolum"'));
  assert.ok(bolum.length > 0, 'cd-gun-bolum .. cd-kapat-bolum dilimi bulundu');
  assert.ok(bolum.includes('id="cd-protokol-iptal-btn"'), 'buton cd-gun-bolum içinde (yalnız aktif vakada görünen alan)');
  const btnDilim = bolum.slice(bolum.indexOf('id="cd-protokol-iptal-btn"'));
  assert.ok(/display:\s*none/.test(btnDilim), 'başlangıçta gizli — görünürlüğü JS kurar (erken-kapat deseni)');
  assert.ok(bolum.includes('onclick="cdProtokolIptal()"'), 'statik onclick deseni (cd-kaydir-btn emsali)');
});

// ── Görünürlük: yalnız AKTİF + protocol_family + online ────────────────

test('C1-2: ertelemeBtnGuncelle — protokol ailesi AKTİF vakada görünür; normal/kapalı vakada YOK; offline gizler', () => {
  const goster = (vaka, online) => {
    const el = makeElement('button'); el.style.display = 'none';
    const kaydir = makeElement('button');
    gorunurlukFn({ document: mkDoc(el, kaydir), navigator: { onLine: online }, _curCase: vaka })();
    return el.style.display;
  };
  assert.strictEqual(
    goster({ id: 'cv1', status: 'active', protocol_family: 'OVSYNC' }, true), 'block',
    'aktif + protocol_family + online → GÖRÜNÜR (E4 ölçütü: aktif ovsync vakasında iptal yüzeyi)');
  assert.strictEqual(
    goster({ id: 'cn', status: 'active', protocol_family: null }, true), 'none',
    'normal aktif vaka (protocol_family YOK) → buton YOK');
  assert.strictEqual(
    goster({ id: 'ck', status: 'closed', protocol_family: 'OVSYNC' }, true), 'none',
    'kapalı protokol vakası → buton YOK');
  assert.strictEqual(
    goster({ id: 'cv1', status: 'active', protocol_family: 'OVSYNC' }, false), 'none',
    'offline → gizli (E6 online-only)');
  // _curCase kurulmamış koşumda (vm-extract kardeşleri) çökmez
  const el = makeElement('button'); el.style.display = 'block';
  assert.doesNotThrow(() => gorunurlukFn({ document: mkDoc(el, null), navigator: { onLine: true } })());
  assert.strictEqual(el.style.display, 'none', 'vaka bağlamı yoksa gizli kalır');
});

// ── Akış: _protokolIptalAkisi A dalına devir ───────────────────────────

test('C1-3: protokol ailesi aktif vaka → onay+yeniden-başlat → rpc("protokol_iptal") doğru parametrelerle; vaka detayı kapanır', async () => {
  const v = { id: 'cv1', animal_id: 'h1', status: 'active', protocol_family: 'OVSYNC' };
  const { ctx, rpcCagri, kapatilan } = cdIptalCtxYap({
    vaka: v,
    gunler: [{ case_id: 'cv1', tamamlandi: false }],
    seanslar: [{ case_id: 'cv1', uygulanmadi: false, uygulama_tamamlandi_at: null }],
    cevaplar: [true, true],          // 1) iptal onayı  2) yeniden başlat EVET
  });
  await ctx.cdProtokolIptal();
  assert.strictEqual(rpcCagri.length, 1, 'tek RPC çağrısı');
  assert.strictEqual(rpcCagri[0][0], 'protokol_iptal', 'A dalı RPC adı (gorev_tamamla değil)');
  const p = rpcCagri[0][1];
  assert.strictEqual(p.p_vaka_id, 'cv1', 'p_vaka_id = açık vakanın id');
  assert.strictEqual(p.p_yeniden_baslat, true, 'p_yeniden_baslat');
  assert.strictEqual(p.p_not, null, 'p_not');
  assert.deepStrictEqual(kapatilan, ['m-case-det'], 'başarıda vaka detay ekranı kapanır (erken-kapat deseni)');
});

test('C1-4: NORMAL vaka (protocol_family YOK) → buton akışı tetiklense bile RPC ÇAĞRILMAZ', async () => {
  const { ctx, rpcCagri, kapatilan } = cdIptalCtxYap({
    vaka: { id: 'cn', status: 'active', protocol_family: null },
    cevaplar: [true, true],
  });
  await ctx.cdProtokolIptal();
  assert.strictEqual(rpcCagri.length, 0, 'normal vakada akış onaya hiç gelmez');
  assert.strictEqual(kapatilan.length, 0, 'modal dokunulmaz');
});

test('C1-5: offline → RPC ÇAĞRILMAZ + birleşik E6 toast', async () => {
  const v = { id: 'cv1', status: 'active', protocol_family: 'OVSYNC' };
  const { ctx, rpcCagri, toastlar, kapatilan } = cdIptalCtxYap({ vaka: v, cevaplar: [true, true], online: false });
  await ctx.cdProtokolIptal();
  assert.strictEqual(rpcCagri.length, 0, 'offline: RPC ÇAĞRILMAZ');
  assert.ok(toastlar.some(t => t.e && t.m === MSJ), 'birleşik offline toast');
  assert.strictEqual(kapatilan.length, 0, 'modal dokunulmaz');
});

test('C1-6: iptal onayı RED → RPC ÇAĞRILMAZ + vaka detayı AÇIK kalır', async () => {
  const v = { id: 'cv1', status: 'active', protocol_family: 'OVSYNC' };
  const { ctx, rpcCagri, kapatilan } = cdIptalCtxYap({ vaka: v, cevaplar: [false] });
  await ctx.cdProtokolIptal();
  assert.strictEqual(rpcCagri.length, 0, 'onay red → hiçbir RPC çağrılmaz');
  assert.strictEqual(kapatilan.length, 0, 'onay red → modal açık kalır');
});

// ── Kablolama: ikinci akış kopyası yok + veri bağımlılığı ──────────────

test('C1-7: cdProtokolIptal akışı KOPYALAMAZ — _protokolIptalAkisi A dalına devreder; protocol_family alanını vakadan okur', () => {
  const cd = extractFunctionSource(UI, 'cdProtokolIptal');
  assert.ok(cd.includes('_protokolIptalAkisi('), 'mevcut A-dal akışına devir (kopya-yapıştır yok)');
  assert.ok(!cd.includes("rpc('protokol_iptal'"), 'RPC çağrısı doğrudan DEĞİL — akış tek kaynak');
  assert.ok(cd.includes('protocol_family'), 'yüzey koşulu protocol_family kontrolü taşır');
  assert.ok(cd.includes("_ertelemeOfflineGuard("), 'E6 giriş guardı var');
  const guncelle = extractFunctionSource(UI, 'ertelemeBtnGuncelle');
  assert.ok(guncelle.includes('cd-protokol-iptal-btn'), 'online/offline görünürlük taraması yeni butonu kapsar');
  // veri bağımlılığı: cases pull protocol_family'i zaten taşır (select('*'))
  const api = fs.readFileSync('js/api.js', 'utf8');
  const casesPull = api.slice(api.indexOf('cases:'), api.indexOf('cases:') + 200);
  assert.ok(casesPull.includes("select('*')"), "cases çekimi select(*) → protocol_family UI'da mevcut (api.js değişikliği GEREKMEZ)");
});
