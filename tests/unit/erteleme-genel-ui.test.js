// tests/unit/erteleme-genel-ui.test.js — E1-UI (erteleme-genel):
// genel erteleme UI. Kural TEK kaynak canlı gorev_ertele_kural_listele RPC'si
// (cache AppState'te); JS'e tip listesi KOPYALANMAZ. Kapsam:
//   * kural cache davranışı (yenileme/fail-closed/cooldown/offline),
//   * _erteleBtnHtml tip açılımı (t → butonlu; f/kayıtsız → butonsuz),
//   * _erteleModal: pencere önizlemesi YALNIZ pencere_kurali='tohumlama',
//     başlık 'Görevi Ertele', ertelenemez tip toast'u,
//   * _erteleKaydet → rpc('gorev_ertele') + toplam_erteleme_gun/uyari (D18),
//   * PG_HATA_SOZLUGÜ kayıtları (GOREV_ERTELENEMEZ ailesi + GECMIS_TARIH),
//   * api tutarlılığı (SMELL-002: RPC_TABLES ↔ RPC_MAP senkron denetimi).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const { extractFunctionSource, makeElement, loadBrowserModule } = require('./support/loadModule.js');

const UI = 'js/ui.js';
const escAttrMirror = s => String(s);
const _ovsyncTarihOkuMirror = v => { const m = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(String(v || '').trim()); return m ? `${m[3]}-${m[2]}-${m[1]}` : null; };

// ── kardeş yükleyici (K8-5 izole-kardeş deseni; E6 çekirdeği hazır gelir) ──
function yukle(isimler, ctxExtra) {
  const ctx = { Math, JSON, Number, parseInt, Date, ...ctxExtra };
  vm.createContext(ctx);
  for (const n of ['_ertelemeOnline', '_ertelemeOfflineGuard', ...isimler]) {
    vm.runInContext(extractFunctionSource(UI, n), ctx, { filename: `${UI}#${n}` });
  }
  return ctx;
}

// ═══ 1. Kural cache davranışı ═══════════════════════════════════════════

test('EG-1: ertelemeKurallariYenile — rpc çekip setState ile cache kurar; pencere yoksa "yok" varsayılır', async () => {
  const rpcCagri = [], setler = [];
  const ctx = yukle(['ertelemeKurallariGetir', 'ertelemeKuralGetir', 'ertelemeKurallariYenile'], {
    navigator: { onLine: true },
    rpc: async (...a) => { rpcCagri.push(a); return [
      { gorev_tipi: 'TOHUMLAMA_PLANLI', ertelenebilir: true,  pencere_kurali: 'tohumlama' },
      { gorev_tipi: 'ASI_PLANLI',       ertelenebilir: true,  pencere_kurali: null },        // RPC NULL dönebilir
      { gorev_tipi: 'TEDAVI_GUN',       ertelenebilir: false, pencere_kurali: 'yok' },
    ]; },
    setState: (k, v) => setler.push({ k, v }),
    getState: () => ({}),
    _ertelemeKuralSonDeneme: 0,
    console: { warn() {}, log() {} },
  });
  await ctx.ertelemeKurallariYenile(true);
  assert.strictEqual(rpcCagri.length, 1, 'tek rpc çağrısı');
  assert.strictEqual(rpcCagri[0][0], 'gorev_ertele_kural_listele', 'salt-okuma RPC adı');
  assert.strictEqual(rpcCagri[0][1] && Object.keys(rpcCagri[0][1]).length, 0, 'parametresiz');
  assert.strictEqual(setler.length, 1, 'setState bir kez');
  assert.strictEqual(setler[0].k, 'ertelemeKurallari');
  // vm-nesne prototipi farkı deepStrictEqual'ı bozar → JSON turu ile karşılaştır
  assert.deepStrictEqual(JSON.parse(JSON.stringify(setler[0].v)), {
    TOHUMLAMA_PLANLI: { ertelenebilir: true, pencere_kurali: 'tohumlama' },
    ASI_PLANLI:       { ertelenebilir: true, pencere_kurali: 'yok' },
    TEDAVI_GUN:       { ertelenebilir: false, pencere_kurali: 'yok' },
  }, 'cache haritası — pencere NULL → "yok"');
});

test('EG-2: ertelemeKurallariYenile — offline rpc ÇAĞIRMAZ; cache doluysa no-op; hata sonrası 60sn sükunet', async () => {
  // offline: rpc 0 çağrı
  let rpcAdet = 0;
  const off = yukle(['ertelemeKurallariGetir', 'ertelemeKurallariYenile'], {
    navigator: { onLine: false },
    rpc: async () => { rpcAdet++; return []; },
    setState: () => {}, getState: () => ({}),
    _ertelemeKuralSonDeneme: 0, console: { warn() {}, log() {} },
  });
  await off.ertelemeKurallariYenile(true);
  assert.strictEqual(rpcAdet, 0, 'offline → rpc ÇAĞRILMAZ (mevcut cache korunur)');
  // cache dolu + zorla değil → no-op
  let rpcAdet2 = 0;
  const dolu = yukle(['ertelemeKurallariGetir', 'ertelemeKurallariYenile'], {
    navigator: { onLine: true },
    rpc: async () => { rpcAdet2++; return []; },
    setState: () => {}, getState: () => ({ TOHUMLAMA_PLANLI: { ertelenebilir: true, pencere_kurali: 'tohumlama' } }),
    _ertelemeKuralSonDeneme: 0, console: { warn() {}, log() {} },
  });
  await dolu.ertelemeKurallariYenile();
  assert.strictEqual(rpcAdet2, 0, 'cache dolu + zorla değil → no-op (loadTasks giriş kancası ucuz)');
  // rpc hata verir: setState yok + hemen ikinci deneme cooldown'a düşer
  let rpcAdet3 = 0;
  const hata = yukle(['ertelemeKurallariGetir', 'ertelemeKurallariYenile'], {
    navigator: { onLine: true },
    rpc: async () => { rpcAdet3++; throw new Error('rpc yok'); },
    setState: () => { throw new Error('setState çağrılmamalı'); },
    getState: () => ({}),
    _ertelemeKuralSonDeneme: 0,
    console: { warn() {}, log() {} },
  });
  await hata.ertelemeKurallariYenile();      // ilk deneme → rpc hata
  await hata.ertelemeKurallariYenile();      // 60 sn sükunet → rpc tekrar YOK
  assert.strictEqual(rpcAdet3, 1, 'hata sonrası cooldown — her loadTasks\'te çekiştirmez');
});

// ═══ 2. _erteleBtnHtml — tip açılımı kural cache'ten ════════════════════

test('EG-3: _erteleBtnHtml — kural ertelenebilir tipte buton VAR; f tipi ve KAYITSIZ tip BUTONSUZ (fail-closed)', () => {
  const kural = tip => ({
    TOHUMLAMA_PLANLI: { ertelenebilir: true,  pencere_kurali: 'tohumlama' },
    OVSYNC_BASLAT:    { ertelenebilir: true,  pencere_kurali: 'tohumlama' },
    ASI_PLANLI:       { ertelenebilir: true,  pencere_kurali: 'yok' },
    TEDAVI_GUN:       { ertelenebilir: false, pencere_kurali: 'yok' },
    TEDAVI_SEANS:     { ertelenebilir: false, pencere_kurali: 'yok' },
  }[tip] || null);   // kayıtsız tip → null (fail-closed ayna)
  const btn = yukle(['_erteleBtnHtml'], { navigator: { onLine: true }, escAttr: escAttrMirror, ertelemeKuralGetir: kural })._erteleBtnHtml;
  const acik = tip => ({ id: 'g1', gorev_tipi: tip, tamamlandi: false, iptal: false });
  // t tipleri → butonlu
  for (const tip of ['TOHUMLAMA_PLANLI', 'OVSYNC_BASLAT', 'ASI_PLANLI']) {
    const html = btn(acik(tip));
    assert.ok(html.includes('🗓️ Ertele'), `${tip} → buton üretilir`);
    assert.ok(html.includes('data-ertele'), `${tip} → canlı-DOM görünürlük rozeti`);
    assert.ok(html.includes('_erteleModal'), `${tip} → modal açışına kablolu`);
  }
  // kural f tipleri (TEDAVI_GUN/SEANS — plan "kural f") + kayıtsız tip → butonsuz
  assert.strictEqual(btn(acik('TEDAVI_GUN')), '', 'TEDAVI_GUN kartına ÇİZİLMEZ (kural f)');
  assert.strictEqual(btn(acik('TEDAVI_SEANS')), '', 'TEDAVI_SEANS kartına ÇİZİLMEZ (kural f)');
  assert.strictEqual(btn(acik('BILINMEYEN_TIP')), '', 'kayıtsız tip → BUTONSUZ (fail-closed)');
  // kuralda ertelenebilir=false genel durumu
  const kuralKapali = () => ({ ertelenebilir: false, pencere_kurali: 'yok' });
  const btnKapali = yukle(['_erteleBtnHtml'], { navigator: { onLine: true }, escAttr: escAttrMirror, ertelemeKuralGetir: kuralKapali })._erteleBtnHtml;
  assert.strictEqual(btnKapali(acik('ASI_PLANLI')), '', 'ertelenebilir=false → butonsuz');
  // durum kilidi
  assert.strictEqual(btn({ ...acik('TOHUMLAMA_PLANLI'), tamamlandi: true }), '', 'tamamlanmış → butonsuz');
  assert.strictEqual(btn({ ...acik('TOHUMLAMA_PLANLI'), iptal: true }), '', 'iptal → butonsuz');
  // cache hiç yoksa ( getState yok → harita {} ) → her tip butonsuz
  const btnCacheYok = yukle(['_erteleBtnHtml', 'ertelemeKurallariGetir', 'ertelemeKuralGetir'], {
    navigator: { onLine: true }, escAttr: escAttrMirror, getState: () => undefined,
  })._erteleBtnHtml;
  assert.strictEqual(btnCacheYok(acik('TOHUMLAMA_PLANLI')), '', 'cache yok → BUTONSUZ (ilk açılış yarışı fail-closed)');
});

// ═══ 3. _erteleModal — başlık + pencere önizleme koşulu + tip kilidi ════

function modalCtxYap(kuralMap, gorev) {
  const toastlar = [];
  const olusan = [];
  const tarihIn = makeElement('input'); tarihIn.value = '05.10.2026';
  const saatIn = makeElement('input'); saatIn.value = '09:00';
  const onizle = makeElement('div');
  const els = { 'ert-tarih': tarihIn, 'ert-saat': saatIn, 'ert-onizleme': onizle };
  const document = {
    getElementById: id => (id in els ? els[id] : null),
    createElement: tag => { const e = makeElement(tag); olusan.push(e); return e; },
    body: makeElement('body'),
  };
  const ctx = yukle(['_erteleModal'], {
    navigator: { onLine: true },
    document,
    getData: async (tablo) => (tablo === 'gorev_log' ? [gorev] : []),
    toast: (m, e) => toastlar.push({ m, e }),
    history: { pushState() {}, back() {} },
    escAttr: escAttrMirror,
    fmtTarih: s => s,
    _ovsyncTarihOku: _ovsyncTarihOkuMirror,
    pencereYuvarla: ts => 'YUVARLANDI:' + ts,       // gerçek ayna config.test.js'te; burada çağrılma olgusu
    ertelemeKuralGetir: tip => kuralMap[tip] || null,
  });
  return { ctx, toastlar, olusan, onizle, tarihIn };
}

test('EG-4: _erteleModal — başlık "Görevi Ertele"; pencere_kurali=tohumlama → pencereYuvarla önizlemesi', async () => {
  const { ctx, olusan, onizle } = modalCtxYap(
    { TOHUMLAMA_PLANLI: { ertelenebilir: true, pencere_kurali: 'tohumlama' } },
    { id: 'g1', gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-20', hedef_saat: '09:00:00' },
  );
  await ctx._erteleModal('g1');
  await new Promise(r => setTimeout(r, 15));
  assert.strictEqual(olusan.length, 1, 'modal kutusu üretildi');
  assert.ok(olusan[0].innerHTML.includes('Görevi Ertele'), 'başlık genel ("Tohumlamayı Ertele" değil)');
  assert.ok(!olusan[0].innerHTML.includes('Tohumlamayı Ertele'), 'eski tohumlama-özel başlık yok');
  assert.ok(onizle.textContent.includes('YUVARLANDI:2026-10-05 09:00'), 'pencere yuvarlaması devrede: ' + onizle.textContent);
  assert.ok(onizle.textContent.includes('(pencere yuvarlaması)'), 'yuvarlama notu görünür');
});

test('EG-5: _erteleModal — pencere_kurali≠tohumlama → saat OLDUĞU GİBİ (yuvarlama YOK)', async () => {
  const { ctx, onizle } = modalCtxYap(
    { ASI_PLANLI: { ertelenebilir: true, pencere_kurali: 'yok' } },
    { id: 'g1', gorev_tipi: 'ASI_PLANLI', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-20', hedef_saat: '14:30:00' },
  );
  await ctx._erteleModal('g1');
  await new Promise(r => setTimeout(r, 15));
  assert.strictEqual(onizle.textContent, 'Kaydedilecek: 2026-10-05 09:00', 'verilen tarih+saat aynen: ' + onizle.textContent);
  assert.ok(!onizle.textContent.includes('YUVARLANDI'), 'pencereYuvarla ÇAĞRILMADI');
});

test('EG-6: _erteleModal — ertelenemez tip (kural f) VE kayıtsız tip → "Görev ertelenemez" toast, modal YOK', async () => {
  for (const [ad, kuralMap, gorev] of [
    ['kural f (TEDAVI_GUN)', { TEDAVI_GUN: { ertelenebilir: false, pencere_kurali: 'yok' } },
      { id: 'g1', gorev_tipi: 'TEDAVI_GUN', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-20' }],
    ['kayıtsız tip', {},
      { id: 'g1', gorev_tipi: 'BILINMEYEN', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-20' }],
  ]) {
    const { ctx, toastlar, olusan } = modalCtxYap(kuralMap, gorev);
    await ctx._erteleModal('g1');
    await new Promise(r => setTimeout(r, 15));
    assert.ok(toastlar.some(t => t.e && t.m === 'Görev ertelenemez'), `${ad}: toast verildi`);
    assert.strictEqual(olusan.length, 0, `${ad}: modal üretilmedi (erken çıkış)`);
  }
});

// ═══ 4. _erteleKaydet — genel RPC + toplam/uyari gösterimi (D18) ═══════

test('EG-7: _erteleKaydet — rpc("gorev_ertele") çağrısı + toplam_erteleme_gun ve uyari toast\'ta', async () => {
  const rpcCagri = [], toastlar = [];
  const tarihIn = makeElement('input'); tarihIn.value = '05.10.2026';
  const saatIn = makeElement('input'); saatIn.value = '09:00';
  const btnEl = makeElement('button');
  const ctx = yukle(['_erteleKaydet'], {
    navigator: { onLine: true },
    document: { getElementById: id => (id === 'ert-tarih' ? tarihIn : id === 'ert-saat' ? saatIn : id === 'ert-btn' ? btnEl : null) },
    rpc: async (...a) => { rpcCagri.push(a); return { ok: true, gorev_id: 'g1', hedef_tarih: '2026-10-07', hedef_saat: '18:00:00', toplam_erteleme_gun: 4, uyari: 'ERTELEME_7_GUN_ASILDI' }; },
    toast: (m, e) => toastlar.push({ m, e }),
    _ovsyncTarihOku: _ovsyncTarihOkuMirror,
    getUserMessage: e => String(e?.message || e),
    fmtTarih: s => s,
    loadTasks: async () => {},
    _erteleKapat: () => {},
    _curTaskFilter: 'today',
  });
  await ctx._erteleKaydet('g1');
  assert.strictEqual(rpcCagri.length, 1, 'tek RPC çağrısı');
  assert.strictEqual(rpcCagri[0][0], 'gorev_ertele', 'genel erteleme RPC\'si');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(rpcCagri[0][1])),
    { p_gorev_id: 'g1', p_yeni_tarih: '2026-10-05', p_yeni_saat: '09:00' },
    'parametre imzası (canlı imza ile aynı)');
  const t = toastlar.find(x => !x.e);
  assert.ok(t, 'başarı toast var');
  assert.ok(t.m.includes('toplam 4 gün erteleme'), 'toplam_erteleme_gun gösterimi: ' + t.m);
  assert.ok(t.m.includes('ERTELEME_7_GUN_ASILDI'), 'uyari gösterimi (D18): ' + t.m);
  assert.ok(t.m.includes('2026-10-07'), 'yeni hedef tarihi gösterilir');
});

test('EG-8: _erteleKaydet — toplam 0 / uyari yok → ek metin YOK (kirli süreç yok)', async () => {
  const toastlar = [];
  const tarihIn = makeElement('input'); tarihIn.value = '05.10.2026';
  const ctx = yukle(['_erteleKaydet'], {
    navigator: { onLine: true },
    document: { getElementById: id => (id === 'ert-tarih' ? tarihIn : null) },
    rpc: async () => ({ ok: true, hedef_tarih: '2026-10-05', hedef_saat: null, toplam_erteleme_gun: 0, uyari: null }),
    toast: (m, e) => toastlar.push({ m, e }),
    _ovsyncTarihOku: _ovsyncTarihOkuMirror,
    getUserMessage: e => String(e?.message || e),
    fmtTarih: s => s,
    loadTasks: async () => {},
    _erteleKapat: () => {},
    _curTaskFilter: 'today',
  });
  await ctx._erteleKaydet('g1');
  const t = toastlar.find(x => !x.e);
  assert.ok(t && !t.m.includes('toplam') && !t.m.includes('⚠️'), '0 gün/uyari yok → ek süs yok: ' + (t && t.m));
});

// ═══ 5. PG_HATA_SOZLUGÜ — GOREV_ERTELENEMEZ ailesi + GECMIS_TARIH ══════

const cfg = loadBrowserModule('js/config.js', { expose: ['PG_HATA_SOZLUGU'] });
const eh = loadBrowserModule('js/utils/errorHandler.js', { extra: { PG_HATA_SOZLUGU: cfg.exposed.PG_HATA_SOZLUGU } });

test('EG-9: hata sözlüğü — GOREV_ERTELENEMEZ alt tipleri jenerik metne DÜŞMEZ (canlı RAISE biçimiyle)', () => {
  const durumlar = [
    ['TIP_ERTELENEMEZ', 'GOREV_ERTELENEMEZ:{"gorev_id":"x","sebep":"TIP_ERTELENEMEZ","gorev_tipi":"TEDAVI_GUN","kural_kaynagi":"tablo"}', /Bu görev tipi ertelenemez/],
    ['GOREV_ACIK_DEGIL', 'GOREV_ERTELENEMEZ:{"gorev_id":"x","sebep":"GOREV_ACIK_DEGIL"}', /Yalnız açık görevler ertelenebilir/],
    ['GOREV_BULUNAMADI', 'GOREV_ERTELENEMEZ:{"gorev_id":"x","sebep":"GOREV_BULUNAMADI"}', /Görev bulunamadı/],
    ['MAX_ASIM', 'GOREV_ERTELENEMEZ:{"gorev_id":"x","sebep":"MAX_ASIM","max_erteleme_gun":30,"toplam_erteleme_gun":31}', /Erteleme sınırı aşıldı/],
    ['GECMIS_TARIH', 'GECMIS_TARIH:{"gorev_id":"x","yeni_tarih":"2026-01-01","bugun":"2026-09-25"}', /Geçmiş tarihe erteleme yapılamaz/],
    ['PROTOKOL_IPTAL_EDILEMEZ', 'PROTOKOL_IPTAL_EDILEMEZ:{"case_id":"c","sebep":"VAKA_ACIK_DEGIL","status":"closed"}', /Protokol vakası iptal edilemedi/],
  ];
  for (const [ad, msg, re] of durumlar) {
    const m = eh.sandbox.getUserMessage(new Error(msg));
    assert.match(m, re, `${ad} → özel mesaj`);
    assert.ok(!/protokol\/zincir kuralı/.test(m), `${ad} → aile-jenerik metne düşmedi`);
    assert.ok(!/Bir hata oluştu/.test(m), `${ad} → jenerik fallback yok`);
  }
});

// ═══ 6. api tutarlılığı — SMELL-002 denetimi (RPC_TABLES ↔ RPC_MAP) ═══

const api = loadBrowserModule('js/api.js', {
  expose: ['RPC_TABLES'],
  extra: { supabase: { createClient: () => ({ from: () => { throw new Error('stub'); }, rpc: () => { throw new Error('stub'); }, auth: {} }) } },
});
const T = api.exposed.RPC_TABLES;

function rpcMapBolumu() {
  const src = fs.readFileSync(UI, 'utf8');
  const bas = src.indexOf('const RPC_MAP = {');
  assert.ok(bas > -1, 'RPC_MAP bloğu bulundu');
  return src.slice(bas, src.indexOf('};', bas));
}

test('EG-10: SMELL-002 — gorev_ertele RPC_TABLES\'ta dolu dizi; salt-okuma kural RPC\'si haritada DEĞİL; RPC_MAP\'te de DEĞİL (online-only)', () => {
  assert.deepStrictEqual([...T.gorev_ertele], ['gorev_log', 'islem_log'], 'tohumlama_gorev_ertele deseni');
  assert.ok(!('gorev_ertele_kural_listele' in T), 'salt-okuma kural RPC\'si RPC_TABLES\'a GİRMEZ (dolu dizi invariantı)');
  const rm = rpcMapBolumu();
  assert.ok(!rm.includes('gorev_ertele'), 'RPC_MAP (offline kuyruk replay) erteleme RPC\'si içermez — online-only (E6)');
  assert.ok(!rm.includes('gorev_ertele_kural_listele'), 'RPC_MAP kural RPC\'si içermez');
});

test('EG-11: SMELL-002 — protokol_iptal RPC_TABLES\'ta çekirdek tablolarla; RPC_MAP\'te DEĞİL (online-only)', () => {
  assert.ok(Array.isArray(T.protokol_iptal) && T.protokol_iptal.length, 'protokol_iptal pull seti var');
  for (const tab of ['gorev_log', 'cases', 'treatment_days', 'treatment_day_uygulamalar', 'stok', 'stok_hareket']) {
    assert.ok(T.protokol_iptal.includes(tab), `protokol_iptal → ${tab} eksik`);
  }
  const rm = rpcMapBolumu();
  assert.ok(!rm.includes('protokol_iptal'), 'RPC_MAP protokol_iptal içermez — online-only');
});

test('EG-12: kablolama — ui.js rpc() ile gorev_ertele/gorev_ertele_kural_listele/protokol_iptal çağırıyor; cache yenileme iki kancada', () => {
  const src = fs.readFileSync(UI, 'utf8');
  assert.ok(src.includes("rpc('gorev_ertele',"), '_erteleKaydet genel RPC\'ye kablolu');
  assert.ok(src.includes("rpc('gorev_ertele_kural_listele',"), 'kural cache RPC\'den besleniyor');
  assert.ok(src.includes("rpc('protokol_iptal',"), 'E4 protokol iptal RPC\'ye kablolu');
  assert.ok(!src.includes("rpc('tohumlama_gorev_ertele'"), 'eski tohumlama-özel RPC çağrısı UI\'dan kalktı (DB sözleşmesi dokunulmaz — RPC canlı)');
  // iki yenileme kancası: loadTasks girişi (cache boşsa) + loadDash (zorla)
  const lt = src.slice(src.indexOf('async function loadTasks'), src.indexOf('function _stokAdi'));
  assert.ok(lt.includes('await ertelemeKurallariYenile();'), 'loadTasks giriş kancası');
  const ld = src.slice(src.indexOf('async function loadDash'), src.indexOf('async function kizginlikYoktu'));
  assert.ok(ld.includes('ertelemeKurallariYenile(true)'), 'loadDash zorla-tazeleme kancası (rozet tarayıcı deseni)');
  // JS\'e erteleme tip kopyası YAZILMADI — kabul ölçütü: buton/modal
  // üreticilerinde hardcoded gorev_tipi karşılaştırması yok (karar kuraldan)
  for (const [ad, isim] of [['_erteleBtnHtml', '_erteleBtnHtml'], ['_erteleModal', '_erteleModal']]) {
    const s = extractFunctionSource(UI, isim);
    assert.ok(!/gorev_tipi\s*===?\s*['"]TOHUMLAMA_PLANLI['"]/.test(s) && !/gorev_tipi\s*!==?\s*['"]TOHUMLAMA_PLANLI['"]/.test(s),
      `${ad} — hardcoded tip kilidi YOK (kural cache'den karar)`);
  }
  assert.ok(src.includes("ertelenebilir: !!r.ertelenebilir"), 'kural satırı RPC cevabından dönüştürülür — hardcoded tip listesi yok');
});
