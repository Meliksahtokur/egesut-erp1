// tests/unit/ovsync-uifix1.test.js — ui-fix1: yürüyüşte bulunan 6 ürün hatası (K1–K6)
//   K1 S4 katlama span/onclick · K2 🔔 sheet kapat→goTo · K3 birleşik kapıda PG kapısı etiketi
//   K4 bayat etiketinde saat · K5 popstate'te ovsync sheet kapanışı · K6 S0 kartı TAI tarihi
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const helpers = require('../../js/utils/helpers.js');
const { extractFunctionSource, makeDomStub, makeElement, loadBrowserModule, makeStorage } = require('./support/loadModule.js');

const REPO = path.join(__dirname, '..', '..');
const fn = (f, n) => extractFunctionSource(f, n);
const esc = v => String(v == null ? '' : v);

function ctxKur(src, extra = {}) {
  const ctx = { console, Math, JSON, Date, esc, escAttr: esc, ...extra };
  ctx.window = extra.window || {};
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  return ctx;
}

// ── K1 ──
test('K1: S4 başlığı .ovs-katla span + onclick içerir; kapalı ▸, açık ▾', () => {
  const src = fn('js/ui.js', '_ovsyncBolumHtml');
  for (const [acik, isaret] of [[false, '▸'], [true, '▾']]) {
    const ctx = ctxKur(src, { _ovsyncSatirHtml: () => '<i/>', window: { _curOvsyncBolum: { acik: { S4: acik } } } });
    const h = ctx._ovsyncBolumHtml('S4', [{}], '2026-10-01', null, null);
    assert.ok(h.includes('<span class="ovs-katla" onclick="_ovsyncS4Katla()">' + isaret + '</span>'), h);
  }
  const ctx = ctxKur(src, { _ovsyncSatirHtml: () => '<i/>', window: {} });
  assert.ok(!ctx._ovsyncBolumHtml('S1', [{}], '2026-10-01', null, null).includes('ovs-katla'));
});

// ── K2 ──
test('K2: _protokolOvsyncGit sheet kapatma fonksiyonunu goTo\'dan ÖNCE çağırır', () => {
  const sira = [];
  const doc = makeDomStub(); doc.__setEl('protokol-bs', makeElement('div'));
  const ctx = ctxKur(fn('js/ui.js', '_protokolOvsyncGit'), {
    document: doc, history: { state: null },
    _closeProtokolListe: () => sira.push('kapat'), goTo: p => sira.push('goTo:' + p),
  });
  ctx._protokolOvsyncGit();
  assert.deepStrictEqual(sira, ['kapat', 'goTo:ovsync']);
});
test('K2: history.back gerekiyorsa goTo geri-geçiş tüketildikten sonra (_modalBackDevam) koşar', () => {
  const sira = [];
  const doc = makeDomStub(); doc.__setEl('protokol-bs', makeElement('div'));
  const ctx = ctxKur(fn('js/ui.js', '_protokolOvsyncGit'), {
    document: doc, history: { state: { protokol: true } },
    _closeProtokolListe: () => sira.push('kapat'), goTo: p => sira.push('goTo:' + p),
  });
  ctx._protokolOvsyncGit();
  assert.deepStrictEqual(sira, ['kapat']);
  ctx._modalBackDevam();
  assert.deepStrictEqual(sira, ['kapat', 'goTo:ovsync']);
});
test('K2: iki "Tüm takibi aç →" linki de _protokolOvsyncGit çağırır (doğrudan goTo yok)', () => {
  const src = fs.readFileSync(path.join(REPO, 'js/ui.js'), 'utf8');
  assert.strictEqual((src.match(/onclick="_protokolOvsyncGit\(\)"[^>]*>Tüm takibi aç/g) || []).length, 2);
  assert.ok(!/onclick="goTo\('ovsync'\)"[^>]*>Tüm takibi aç/.test(src));
});

// ── K3 ──
function takipCtx() {
  const doc = makeDomStub();
  const gercek = doc.createElement.bind(doc);
  doc.createElement = t => { const el = gercek(t); let id0 = ''; Object.defineProperty(el, 'id', { get: () => id0, set: v => { if (id0 === v) return; id0 = v; if (v) doc.__setEl(v, el); }, configurable: true }); return el; };
  const src = ['_tohGunNormalize', '_takipPgKararEtiket', '_takipKisaGun', '_takipAcikMetin', '_takipAcikAc']
    .map(n => fn('js/ui.js', n)).join('\n');
  const ctx = ctxKur(src, { document: doc, history: { pushState() {}, state: null }, fmtTarih: helpers.fmtTarih });
  return { ctx, doc };
}
const TA = { muayene_tarihi: '2026-10-05', muayene_saat: '14:35:00' };
test('K3: karar alansız yük + REQUIRE_ACK_PENDING kodu → etiket bilinmiyor DEĞİL', () => {
  const { ctx, doc } = takipCtx();
  ctx._takipAcikAc({ birlesik: true, pg_kapi: { kupe_no: 'x' }, pg_kapi_kod: 'PG_KAPI:REQUIRE_ACK_PENDING', takip_acik: TA }, () => {});
  const h = doc.getElementById('takip-acik-bs').innerHTML;
  assert.ok(h.includes('PG kapısı: Son tohumlama sonucu Bekliyor — PG onayı gerekli'), h);
  assert.ok(!h.includes('bilinmiyor'));
});
test('K3: karar çözülemiyor + tohumlama_sonuc var → "Son tohumlama sonucu <sonuc>"', () => {
  const { ctx, doc } = takipCtx();
  ctx._takipAcikAc({ birlesik: true, pg_kapi: { tohumlama_sonuc: 'Bekliyor' }, takip_acik: TA }, () => {});
  assert.ok(doc.getElementById('takip-acik-bs').innerHTML.includes('PG kapısı: Son tohumlama sonucu Bekliyor'));
});
test('K3: hiçbiri yoksa fail-closed "bilinmiyor"; pg_kapi.karar varsa o kullanılır', () => {
  let t = takipCtx();
  t.ctx._takipAcikAc({ birlesik: true, pg_kapi: {}, takip_acik: TA }, () => {});
  assert.ok(t.doc.getElementById('takip-acik-bs').innerHTML.includes('PG kapısı: bilinmiyor'));
  t = takipCtx();
  t.ctx._takipAcikAc({ birlesik: true, pg_kapi: { karar: 'BLOCK_PREGNANT' }, takip_acik: TA }, () => {});
  assert.ok(t.doc.getElementById('takip-acik-bs').innerHTML.includes('Gebe inekte PG uygulanamaz'));
});

// ── K4 ──
test('K4: önbellek varken RPC hatası → zaman taşınır; etiket "çevrimdışı · HH:MM verisi"', async () => {
  const client = { rpc: async () => ({ data: null, error: { message: 'offline' } }), from() { throw new Error('x'); }, channel() { throw new Error('x'); } };
  const { sandbox } = loadBrowserModule('js/api.js', { storage: makeStorage(), extra: { supabase: { createClient: () => client }, navigator: { onLine: true, userAgent: 't' }, toast: () => {} } });
  const z = new Date(2026, 9, 1, 9, 5).getTime();
  sandbox.window.__ovsyncTakip = { veri: { a: 1 }, zaman: z };
  const r = await sandbox.ovsyncTakipGetir();
  assert.strictEqual(r.bayat, true); assert.strictEqual(r.zaman, z); assert.deepStrictEqual(r.veri, { a: 1 });
  const et = ctxKur(fn('js/ui.js', '_ovsyncBayatEtiket'))._ovsyncBayatEtiket(r.zaman);
  assert.strictEqual(et, 'çevrimdışı · 09:05 verisi');
  sandbox.window.__ovsyncTakip = null;
  const r2 = await sandbox.ovsyncTakipGetir();
  assert.strictEqual(r2.veri, null); assert.strictEqual(r2.zaman, null);
});

// ── K5 ──
function popstateBlok() {
  const s = fs.readFileSync(path.join(REPO, 'js/app.js'), 'utf8');
  const a = s.indexOf('// M24:'); const b = s.indexOf('// W3: dal sırası');
  assert.ok(a > 0 && b > a, 'M24 bloğu app.js popstate\'te yok');
  return s.slice(a, b);
}
function popstate(acikIdler, state) {
  const doc = makeDomStub(); acikIdler.forEach(i => doc.__setEl(i, makeElement('div')));
  const cagri = [];
  const g = { _devamSeciciKapat: () => cagri.push('devam'), _takipAcikKapat: () => cagri.push('takip'), _pgKapiKapat: () => cagri.push('pg') };
  const ctx = { document: doc, globalThis: g };
  vm.createContext(ctx);
  const donus = vm.runInContext('(function(e){' + popstateBlok() + ' return "devam-ediyor";})', ctx)({ state });
  return { cagri, donus };
}
test('K5: devam seçici açık + yeni state devam_secici değil → seçici kapanır, işleyici döner', () => {
  const r = popstate(['devam-secici-bs'], { pg: 'ovsync' });
  assert.deepStrictEqual(r.cagri, ['devam']); assert.strictEqual(r.donus, undefined);
});
test('K5: takip-acik-bs / pg-kapi-bs aynı kurala bağlı', () => {
  assert.deepStrictEqual(popstate(['takip-acik-bs'], { pg: 'x' }).cagri, ['takip']);
  assert.deepStrictEqual(popstate(['pg-kapi-bs'], { pg: 'x' }).cagri, ['pg']);
});
test('K5: sheet kapalı ya da state hâlâ sheet\'in kendisi → dokunmaz; ikinci Geri sayfa akışına düşer', () => {
  const r1 = popstate([], { pg: 'ovsync' });
  assert.deepStrictEqual(r1.cagri, []); assert.strictEqual(r1.donus, 'devam-ediyor');
  assert.deepStrictEqual(popstate(['devam-secici-bs'], { devam_secici: true }).cagri, []);
});

// ── K6 ──
function s0() {
  const bag = { vakaAktif: new Map() };
  return ctxKur(['_ovsyncS0Tip', '_ovsyncS0SatirHtml'].map(n => fn('js/ui.js', n)).join('\n'), {
    _ovsyncBaglamAl: () => bag, _ovsyncGunDurumu: () => 'bekliyor', _ovsyncSapmaRozeti: () => '', _ovsyncDenemeRozeti: () => '',
    _ovsyncGunlerHtml: () => '', gunFarkiEtiket: helpers.gunFarkiEtiket,
  })._ovsyncS0SatirHtml;
}
const satir = h => ({ hayvan_id: 'h1', kupe_no: 'K1', grup: 'g', gunler: [{}], tai: { gorev_id: 'g1', hedef_tarih: h, hedef_saat: '10:00:00', durum: 'bekliyor' } });
test('K6: TAI yarın → "TAI bugün" ve "▶ TAI kaydet" yok; göreli gün etiketi var', () => {
  const h = s0()(satir('2026-10-02'), '2026-10-01');
  assert.ok(!h.includes('TAI bugün')); assert.ok(!h.includes('▶ TAI kaydet'));
  assert.ok(h.includes('TAI 1 gün sonra 10:00'), h);
});
test('K6: TAI bugün → ikisi de var', () => {
  const h = s0()(satir('2026-10-01'), '2026-10-01');
  assert.ok(h.includes('TAI bugün 10:00')); assert.ok(h.includes('▶ TAI kaydet'));
});
test('K6: tai.hedef_tarih yoksa fail-closed — TAI metni/butonu uydurulmaz', () => {
  const h = s0()(satir(undefined), '2026-10-01');
  assert.ok(!h.includes('TAI bugün')); assert.ok(!h.includes('▶ TAI kaydet'));
});
