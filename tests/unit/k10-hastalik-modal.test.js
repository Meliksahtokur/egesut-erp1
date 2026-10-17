// tests/unit/k10-hastalik-modal.test.js
// Faz UI-2 (karar 10): N2 vaka detayı + N3/N3b "+ Hastalık" modalı (tek akış).
// Silinen alt-vaka yüzeyinin yerine hastalık-günü akışı.
// Yöntem: loadModule/extract + vm — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const { extractFunctionSource, loadExtractedFunction, makeDomStub } = require('./support/loadModule.js');

const ESC = { esc: s => String(s ?? ''), escAttr: s => String(s ?? '') };
const SECENEK = {
  hastaliklar: [{ id: 'd1', name: 'İnaktif Ovaryum' }, { id: 'd2', name: 'Kistik Over' }],
  seciliId: 'd1', kupeNo: '31', taiEski: '2026-10-15', tarih: '2026-10-13', gun: 7,
  vitaminStok: { id: 's1', urun_adi: 'CAROFERTIN-E', urun_id: null, birim: 'ml' },
  ilacStoklar: [],
};
const FMTTARIH = (iso) => { const p = String(iso || '').slice(0, 10).split('-'); return p.length === 3 ? p[2] + '.' + p[1] + '.' + p[0] : String(iso); };
function sheet(o = {}) {
  const govde = ['hastalikSheetHtml', '_hgVitSatir', '_hgTaiChip']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const ctx = { console, fmtTarih: FMTTARIH, ...ESC };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'hastalik-sheet-ctx' });
  return vm.runInContext(`hastalikSheetHtml('v-ana', ${JSON.stringify({ ...SECENEK, ...o })})`, ctx);
}

test('hastalik-modal-oneri-inaktif', () => {
  const h = sheet();
  assert.ok(h.includes('+ Hastalık — Küpe 31'), 'başlık N3');
  assert.ok(h.includes('id="hg-hastalik"'), 'hastalık seçici');
  assert.ok(h.includes('CAROFERTIN-E'), 'inaktif ön-öneri dolu');
  assert.ok(h.includes('hg-vit-doz'), 'ön-öneri doz girdisi');
  assert.ok(h.includes('+ İlaç ekle'), 'ek satır düğmesi');
  assert.ok(h.includes('TAI') && h.includes('15.10') && h.includes('22.10'), 'TAI önce→sonra önizleme (eski+gün kuralı), ölçülen: ' + (h.match(/TAI[^<]*/) || ['?'])[0]);
  assert.ok(h.includes('Vazgeç') && h.includes('Ekle'), 'alt düğmeler');
  assert.ok(h.includes('13.10.2026'), 'TARİH kanonik görünüm (native date YOK)');
  assert.ok(!/background:(#fff|white)/i.test(h), 'beyaz/krem zemin YOK');
});

test('hastalik-modal-bos-kist', () => {
  const h = sheet({ seciliId: 'd2' });
  assert.ok(h.includes('Henüz ilaç yok'), 'kist boş başlar (N3b)');
  assert.ok(!h.includes('CAROFERTIN-E'), 'kistte ön-dolu dayatma YOK');
  assert.ok(h.includes('+ İlaç ekle'), 'kistte eklenebilir');
});

test('tai-once-sonra', () => {
  const doc = makeDomStub();
  doc.__setEl('hg-gun', { value: '7' });
  const chip = { textContent: '', innerHTML: '', getAttribute: (a) => (a === 'data-tai-eski' ? '2026-10-15' : null) };
  doc.__setEl('hg-tai-chip', chip);
  const govde = ['hgGunDegisti', '_hgTaiChip']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const ctx = { document: doc, ...ESC };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'hg-gun-ctx' });
  vm.runInContext('hgGunDegisti()', ctx);
  assert.ok(chip.innerHTML.includes('15.10') && chip.innerHTML.includes('22.10'), 'önizleme 15.10→22.10, ölçülen: ' + chip.innerHTML);
  doc.__setEl('hg-gun', { value: '10' });
  vm.runInContext('hgGunDegisti()', ctx);
  assert.ok(chip.innerHTML.includes('25.10'), 'gün değişince yeni hesaplanır, ölçülen: ' + chip.innerHTML);
});

// ── Kaydet zinciri: tek RPC ovsync_hastalik_gunu_ekle ──
function kaydetCtx(els, rpcImpl) {
  const govde = 'var _hgKayitKilit=false;\n' + ['hastalikGunKaydet', 'hgEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  const base = {
    'hg-gun': { value: '7' }, 'hg-hastalik': { value: 'd1' },
    'hg-hastalik-ad': { value: 'İnaktif Ovaryum' }, 'hg-tarih': { value: '2026-10-13' },
    'hg-vit-doz': { value: '20' }, 'hg-vit-stok': { value: 's1' },
    'hg-tai-chip': { getAttribute: () => '2026-10-15' },
    'hg-ilac-liste': { children: [] },
    'hastalik-modal': { remove() { this.gitti = true; } },
    ...els,
  };
  for (const [id, el] of Object.entries(base)) doc.__setEl(id, el);
  const rpcCagrilari = [], toasts = [], pulls = [], sira = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    ...ESC, _hgKayitKilit: false,
    toast: (m) => { toasts.push(String(m)); },
    rpc: rpcImpl(rpcCagrilari),
    pullTables: async (t) => { pulls.push(t); sira.push('pull-bitti'); return { ok: [], failed: [] }; },
    renderSafe: () => {},
    RPC_TABLES: { ovsync_hastalik_gunu_ekle: ['cases', 'treatment_days'] },
    idbGetAll: async (t) => (t === 'treatment_days' ? [{ id: 'gun-1' }] : []),
    renderCaseTimeline: async () => { sira.push('taze-render'); },
    loadDash: () => {}, _curCase: { id: 'v-ana' },
    dFwd: (iso, n) => { const d = new Date(iso + 'T00:00:00'); d.setDate(d.getDate() + n); const p = (x) => String(x).padStart(2, '0'); return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); },
    _pgKapiHata: () => false, _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'hastalik-kaydet-ctx' });
  return { ctx, doc, rpcCagrilari, toasts, pulls, sira };
}

test('hastalik-kaydet-tek-rpc', async () => {
  const t = kaydetCtx({}, (log) => async (ad, p) => { log.push({ ad, p }); return { ok: true, gun_id: 'gun-1', mevcut: false, ertelenen: 1, ilac: 1 }; });
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.strictEqual(t.rpcCagrilari.length, 1, 'tek RPC');
  assert.strictEqual(t.rpcCagrilari[0].ad, 'ovsync_hastalik_gunu_ekle');
  const p = t.rpcCagrilari[0].p;
  assert.strictEqual(p.p_case_id, 'v-ana');
  assert.strictEqual(p.p_hastalik_id, 'd1');
  assert.strictEqual(p.p_gun, 7);
  assert.ok(Array.isArray(p.p_ilaclar) && p.p_ilaclar.length === 1, 'vitamin ilaç listesinde');
  assert.ok(t.toasts.some(m => m.includes('TAI') && m.includes('15.10') && m.includes('22.10')), 'başarı toast TAI önce→sonra, ölçülen: ' + JSON.stringify(t.toasts));
  assert.ok(t.sira.indexOf('pull-bitti') !== -1 && t.sira.indexOf('pull-bitti') < t.sira.indexOf('taze-render'), 'sıra: önce pull, sonra taze render');
});

test('f3-ok-false-kismi-basari', async () => {
  // MUT-OK-FALSE-SAYILIR bekçisi: ok:false başarı SAYILMAZ.
  const t = kaydetCtx({}, () => async () => ({ ok: false, error: 'GUN_NEGATIF' }));
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.ok(!t.toasts.some(m => m.startsWith('✅')), 'başarı toast YOK, ölçülen: ' + JSON.stringify(t.toasts));
  assert.ok(t.toasts.some(m => m.includes('❌')), 'hata toast var');
  assert.strictEqual(t.pulls.length, 0, 'başarısız kayıtta pull YOK');
});

test('f3-istisna-sheet-kapanir', async () => {
  const pg = [];
  const e = new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"a":1}');
  const t = kaydetCtx({}, (log) => async (ad) => { log.push({ ad }); throw e; });
  t.ctx._pgKapiHata = (ee, cagri, sonra, ad) => { pg.push({ ad, cagriVar: typeof cagri === 'function', sonraVar: typeof sonra === 'function' }); return true; };
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  assert.strictEqual(pg.length, 1, 'PG kapısına düştü');
  assert.strictEqual(pg[0].ad, 'ovsync_hastalik_gunu_ekle');
  assert.ok(pg[0].cagriVar && pg[0].sonraVar, 'onaylı tekrar + başarı kapanışı taşındı');
  assert.ok(t.doc.getElementById('hastalik-modal').gitti, 'sheet kapandı');
  assert.ok(!t.toasts.some(m => m.startsWith('✅')), 'başarı toast YOK');
});

test('hastalik-cift-ekle-tek-cagri', async () => {
  // MUT-HASTALIK-CIFT-EKLE bekçisi: kilit kalkınca çift gün doğardı.
  let n = 0;
  const t = kaydetCtx({}, () => async () => {
    n++;
    await new Promise(r => setTimeout(r, 30));
    return { ok: true, gun_id: 'gun-1', mevcut: false, ertelenen: 0, ilac: 0 };
  });
  await Promise.all([
    vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx),
    vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx),
  ]);
  assert.strictEqual(n, 1, 'çift tık tek çağrı, ölçülen: ' + n);
});

test('hastalik-ac-offline-gizli', async () => {
  // §18.10: çevrimdışıyken erteleme/hastalık-günü girişi gizlidir —
  // sheet açılmaz, IDB/RPC'ye dokunulmaz.
  const govde = extractFunctionSource('js/ui.js', 'hastalikGunAc');
  const iz = [];
  const ctx = {
    console,
    _ertelemeOfflineGuard: (alan) => { iz.push(alan); return true; },
    idbGetAll: async (t) => { iz.push('idb:' + t); return []; },
    document: { getElementById: () => null, createElement: () => { throw new Error('acilmamali'); }, body: { appendChild: () => { throw new Error('acilmamali'); } } },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'hastalik-ac-offline-ctx' });
  await vm.runInContext(`hastalikGunAc('v-ana')`, ctx);
  assert.deepStrictEqual(iz, ['hastalik-gun'], 'guard sonrası dönüş, ölçülen: ' + JSON.stringify(iz));
});

test('hastalik-kaydet-offline-durur', async () => {
  // §18.10: çevrimdışı Ekle RPC üretmez.
  const govde = 'var _hgKayitKilit=false;\n' + extractFunctionSource('js/ui.js', 'hastalikGunKaydet');
  const rpcCagrilari = [];
  const ctx = {
    console,
    _ertelemeOfflineGuard: () => true,
    rpc: async (ad) => { rpcCagrilari.push(ad); return {}; },
    toast: () => {},
    document: {},
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'hastalik-kaydet-offline-ctx' });
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, ctx);
  assert.strictEqual(rpcCagrilari.length, 0, 'çevrimdışı RPC YOK, ölçülen: ' + JSON.stringify(rpcCagrilari));
});

test('hastalik-kabul-yedek', () => {
  const f = loadExtractedFunction('js/ui.js', '_hastalikKabulMu', { extra: ESC });
  const damga = { id: 'v1', status: 'active', protocol_family: 'OVSYNC' };
  assert.strictEqual(f(damga, {}), true, 'damga kazanır');
  const nul = { id: 'v2', status: 'active', protocol_family: null, disease_id: 'd9' };
  assert.strictEqual(f(nul, {}), false, 'NULL desteksiz kapalı (fail-closed)');
  assert.strictEqual(f(nul, { gorevler: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v2:7', iptal: false }], sablonlar: [{ id: '7', protokol_ailesi: 'OVSYNC' }] }), true, 'NULL + OVSYNC şablon tohumlama logu açık');
  assert.strictEqual(f(nul, { gorevler: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v2:7', iptal: false }] }), false, 'NULL + OVSYNC-dışı şablon logu kapalı (ovsync-mu-fix)');
  assert.strictEqual(f(nul, { eslem: [{ disease_id: 'd9', sablon_id: 's7' }], sablonlar: [{ id: 's7', protokol_ailesi: 'OVSYNC' }] }), true, 'NULL + şablon eşlemesi açık');
  assert.strictEqual(f({ ...nul, protocol_family: 'METRIT' }, { gorevler: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v2:7' }] }), false, 'OVSYNC-dışı damga kapalı');
  assert.strictEqual(f({ ...damga, status: 'closed' }, {}), false, 'kapalı vaka kapalı');
});

test('tai-ertele-notu', () => {
  const f = loadExtractedFunction('js/ui.js', '_taiErteleNotu', { extra: ESC });
  assert.strictEqual(f('g1', []), '', 'kayıt yoksa suffix yok');
  const logs = [{ tip: 'TOHUMLAMA_ERTELE', ref_tablo: 'gorev_log', ref_id: 'g1', payload: { eski_tarih: '2026-10-15', yeni_tarih: '2026-10-20', ilk_hedef_tarih: '2026-10-15' } }];
  assert.strictEqual(f('g1', logs), ' (15.10 → 20.10)', 'ilk→hedef notu');
  assert.strictEqual(f('g9', logs), '', 'başka görev etkilenmez');
});

test('s4-gun-hedefi-ebeveyn', () => {
  // Hastalık günleri treatment_days satırıdır: S4 rozeti gün id'sine DEĞİL ebeveyne çıkar.
  const src = extractFunctionSource('js/ui.js', '_ovsyncS4SatirHtml');
  assert.ok(src.includes('alt_vakalar'), 'RPC anahtarı okunur');
  assert.ok(!src.includes('altlar[0].id'), 'gün id hedefine detay YOK');
  const ctx = {
    _ovsyncBaglamAl: () => ({ vakaKapali: new Map([['h1', { id: 'v-ana' }]]) }),
    ...ESC, _ovsyncSonlanmaRozeti: () => '', _ovsyncDenemeRozeti: () => '',
  };
  const g = loadExtractedFunction('js/ui.js', '_ovsyncS4SatirHtml', { extra: ctx });
  const html = g({ hayvan_id: 'h1', kupe_no: 'E2E-95', bolum: 'S4', alt_vakalar: [{ id: 'gun-1', hastalik: 'İnaktif Ovaryum', status: 'acik' }] }, '2026-10-13');
  assert.ok(html.includes("openCaseDet('v-ana')"), 'rozet ebeveyn detayına çıkar');
  assert.ok(!html.includes('gun-1'), 'gün id hedefte geçmez');
});

test('yetim-rozet-baglamsiz', () => {
  // altAcik bağlamı kalktı: rozet yalnız açık-iş izine bakar.
  const ctx = { _ovsyncYetimMi: (v, g) => !(g && g.length), ...ESC };
  const f = loadExtractedFunction('js/ui.js', '_ovsyncYetimRozetHtml', { extra: ctx });
  const vaka = { id: 'v1', status: 'active', protocol_family: 'OVSYNC' };
  const s = { hayvan_id: 'h1' };
  assert.ok(f(s, { acikIs: new Set() }, vaka).includes('Takipsiz'), 'açık iş yoksa uyarı');
  assert.strictEqual(f(s, { acikIs: new Set(['h1']) }, vaka), '', 'açık iş varken rozet yok');
  assert.strictEqual(f(s, {}, vaka), '', 'izsiz bağlamda fail-closed');
});

// KAPI-3 madde 4: desen literali dosyada bütün hâlde geçmez (parçalı kurulur),
// test kendini eşlemez; kapsam js/ + tests/unit (e2e/sql Faz T/SQL yaprağında).
test('MUT-ALT-VAKA-KALINTI', () => {
  const P = ['kaynak' + '_vaka_id', 'inaktif' + '_alt_vaka_', 'inaktif' + 'Gecis',
    'igIlac' + 'Ekle', '_inaktif' + 'GecisBtnSync', 'ALT' + '_ACIK',
    'inaktif' + 'AltVakaDonus', 'alt' + '_vaka_id'].join('|');
  let out = '';
  try {
    out = execFileSync('git', ['grep', '-nE', P, '--', 'js/', 'tests/unit/',
      ':!tests/unit/k10-hastalik-modal.test.js'], { encoding: 'utf8' });
  } catch (e) {
    assert.strictEqual(e.status, 1, 'eşleşme yoksa exit 1 (ölçülen status: ' + e.status + ')');
    return;
  }
  assert.fail('alt-vaka kalıntısı:\n' + out);
});
