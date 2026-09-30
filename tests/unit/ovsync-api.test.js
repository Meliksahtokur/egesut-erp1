// tests/unit/ovsync-api.test.js — PLAN P4: api.js takip veri katmanı sözleşmeleri
//   * ovsyncTakipGetir: taze → cache yazılır; hata/offline → throw YOK, {bayat:true, veri:önceki|null}
//   * tohumlamaBosVeDevam: params birebir taşınır; ok:false → throw + e.data (sunucu red kodları)
//   * _ovsyncTakipInvalidate: window.__ovsyncTakip = null
//   * RPC_TABLES üyeliği: sarmal İÇERİDE (9 tablo), takip listeleme HARİTA DIŞI (salt-okuma invariant)
//   * H8: rpc() 40P01/55P03 → tek nokta Türkçe çakışma mesajı, otomatik retry YOK
//   * invalidate envanteri: plan P4 nokta listesi kaynakla senkron (grep tabanlı)
// Desen: tests/unit/api.test.js loadApi kopyası (vm + supabase stub; ağ yok).
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const {
  loadBrowserModule,
  makeStorage,
} = require('./support/loadModule.js');

const API = 'js/api.js';
const REPO_ROOT = path.join(__dirname, '..', '..');

// ── Sahteler ──────────────────────────────────────────────────────────

// db.rpc(...) stub — api.js'in createClient(SB_URL, SB_KEY) sonucu client yüzeyi.
// rpcHandlers: { rpcAdi: (params) => ({ data, error }) }
function makeClientStub(rpcHandlers = {}) {
  const calls = [];
  const client = {
    rpc: async (name, params) => {
      calls.push({ name, params });
      const h = rpcHandlers[name];
      if (!h) return { data: null, error: { message: `test stub: rpc "${name}" tanımlı değil` } };
      return await h(params);
    },
    from: () => { throw new Error('test stub: db.from() bu testte kullanılmamalı'); },
    channel: () => { throw new Error('test stub: db.channel bu testte kullanılmamalı'); },
  };
  return { createClient: () => client, client, calls };
}

function loadApi(rpcHandlers = {}) {
  const sb = makeClientStub(rpcHandlers);
  const loaded = loadBrowserModule(API, {
    storage: makeStorage(),
    expose: ['RPC_TABLES'],
    extra: {
      supabase: { createClient: sb.createClient },
      navigator: { onLine: true, userAgent: 'node-test' },
      toast: () => {},
    },
  });
  return { ...loaded, calls: sb.calls };
}

// api.js kaynak metni (envanter testleri için)
const apiSrc = fs.readFileSync(path.join(REPO_ROOT, API), 'utf8');
const readFile = rel => fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');

// ══ RPC_TABLES üyeliği (hash üyelik: sarmal İÇERİDE, takip HARİTA DIŞI) ══

test('RPC_TABLES: tohumlama_bos_ve_devam mapte ve pull seti planın 9 tablosuyla birebir', () => {
  const { exposed } = loadApi();
  const beklenen = ['tohumlama','gorev_log','stok','stok_hareket','hayvanlar','islem_log','cases','treatment_days','treatment_day_uygulamalar'];
  assert.deepStrictEqual([...(exposed.RPC_TABLES.tohumlama_bos_ve_devam || [])].sort(), [...beklenen].sort(),
    'sarmal RPC pull seti eksik/fazla — P4 manifest kaydı');
});

test('RPC_TABLES: ovsync_takip_listele HARİTA DIŞI (salt-okuma invariant — pull istemez)', () => {
  const { exposed } = loadApi();
  assert.strictEqual(exposed.RPC_TABLES.ovsync_takip_listele, undefined,
    'salt-okuma listeleme RPC haritaya girdi — invariant ihlali');
  // invariant yorumu kaynakta güncellenmiş olmalı (ovsync_takip_listele istisnası yazılı)
  assert.ok(apiSrc.includes('ovsync_takip_listele'), 'invariant yorumunda ovsync_takip_listele istisnası yok');
});

// ══ ovsyncTakipGetir sözleşmesi ══

test('ovsyncTakipGetir: taze çekim — rpc("ovsync_takip_listele", {p_padok}) çağrılır, cache yazılır, {bayat:false, veri, zaman} döner', async () => {
  const veri = { satirlar: [{ kupe: '121' }], toplam: 1 };
  const { sandbox, window, calls } = loadApi({
    ovsync_takip_listele: () => ({ data: veri, error: null }),
  });
  assert.ok(typeof sandbox.ovsyncTakipGetir === 'function', 'ovsyncTakipGetir api.js\'te yok');
  const donen = await sandbox.ovsyncTakipGetir('Sağmal Padok');
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0].name, 'ovsync_takip_listele');
  // spread: sandbox realm'ındaki nesneyi test realm'ına taşı (deepStrictEqual prototip kili)
  assert.deepStrictEqual({ ...calls[0].params }, { p_padok: 'Sağmal Padok' });
  assert.strictEqual(donen.bayat, false);
  assert.deepStrictEqual(donen.veri, veri);
  assert.ok(typeof donen.zaman === 'number');
  assert.deepStrictEqual({ ...window.__ovsyncTakip }, { veri, zaman: donen.zaman }, 'window cache {veri, zaman} şemasıyla yazılmalı (spread: realm kilidi)');
});

test('ovsyncTakipGetir: p_padok=null → rpc params {p_padok:null} (P1 imzası p_padok text DEFAULT NULL)', async () => {
  const { sandbox, calls } = loadApi({
    ovsync_takip_listele: () => ({ data: [], error: null }),
  });
  await sandbox.ovsyncTakipGetir();
  assert.deepStrictEqual({ ...calls[0].params }, { p_padok: null });
});

test('ovsyncTakipGetir: rpc hatasında throw ETMEZ — {bayat:true, veri:önceki} döner, cache korunur', async () => {
  const veri = { satirlar: ['eski'] };
  // önce taze çekimle cache kur, sonra aynı sandbox'ta hata yoluna geç
  let patla = false;
  const { sandbox, window } = loadApi({
    ovsync_takip_listele: () => {
      if (patla) return { data: null, error: { message: 'boom' } };
      return { data: veri, error: null };
    },
  });
  await sandbox.ovsyncTakipGetir(null);          // cache kuruldu
  patla = true;
  const donen = await sandbox.ovsyncTakipGetir(null);  // artık hata yolu
  assert.strictEqual(donen.bayat, true);
  assert.deepStrictEqual(donen.veri, veri, 'bayat veri önceki cache\'ten gelmeli');
  assert.deepStrictEqual(window.__ovsyncTakip.veri, veri, 'hata yolu cache\'i EZMEMELİ');
});

test('ovsyncTakipGetir: önbellek yokken hata → {bayat:true, veri:null} (UI açık mesaj)', async () => {
  const { sandbox } = loadApi({
    ovsync_takip_listele: () => ({ data: null, error: { message: 'boom' } }),
  });
  const donen = await sandbox.ovsyncTakipGetir(null);
  assert.strictEqual(donen.bayat, true);
  assert.strictEqual(donen.veri, null);
});

test('ovsyncTakipGetir: gerçek fetch hatası offline sayılır (M-25: navigator.onLine ön koşulu YOK)', async () => {
  const { sandbox } = loadApi({
    ovsync_takip_listele: () => { throw new TypeError('Failed to fetch'); },
  });
  const donen = await sandbox.ovsyncTakipGetir(null);
  assert.strictEqual(donen.bayat, true, 'fetch TypeError bayat yola düşmeli');
  assert.strictEqual(donen.veri, null);
});

// ══ tohumlamaBosVeDevam sözleşmesi ══

test('tohumlamaBosVeDevam: params birebir rpc("tohumlama_bos_ve_devam", params) taşınır, dönüş aynen', async () => {
  const cikti = { ok: true, takip_gorev_id: 'g1' };
  const { sandbox, calls } = loadApi({
    tohumlama_bos_ve_devam: () => ({ data: cikti, error: null }),
  });
  assert.ok(typeof sandbox.tohumlamaBosVeDevam === 'function', 'tohumlamaBosVeDevam api.js\'te yok');
  const params = { p_tohumlama_id: 't1', p_secim: 'TAKIP', p_gun: 7 };
  const donen = await sandbox.tohumlamaBosVeDevam(params);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0].name, 'tohumlama_bos_ve_devam');
  assert.strictEqual(calls[0].params, params, 'params nesnesi birebir taşınmalı');
  assert.deepStrictEqual(donen, cikti);
});

test('tohumlamaBosVeDevam: sunucu red kodu ok:false → throw edilir ve e.data payload\'ı taşır (TAKIP_ACIK alanları)', async () => {
  const red = { ok: false, mesaj: 'TAKIP_ACIK:{"muayene_tarihi":"2026-10-07","muayene_saat":"09:30:00"}' };
  const { sandbox } = loadApi({
    tohumlama_bos_ve_devam: () => ({ data: red, error: null }),
  });
  await assert.rejects(
    () => sandbox.tohumlamaBosVeDevam({ p_tohumlama_id: 't1', p_secim: 'PG' }),
    e => {
      // vm realm farkı: sandbox Error sınıfı test realm'ından farklı → instanceof değil duck-typing
      assert.strictEqual(e?.name, 'Error');
      assert.ok(e.data, 'rpc ok:false gövdesi e.data ile taşınmalı (P2b/P3b red kod sözleşmesi)');
      assert.match(e.data.mesaj, /TAKIP_ACIK/);
      const payload = JSON.parse(e.data.mesaj.replace(/^TAKIP_ACIK:/, ''));
      assert.strictEqual(payload.muayene_tarihi, '2026-10-07');
      assert.strictEqual(payload.muayene_saat, '09:30:00');
      return true;
    },
  );
});

test('tohumlamaBosVeDevam: çağrı takip verisini değiştirir — her iki yolda da cache invalidite edilir', async () => {
  const basarili = loadApi({ tohumlama_bos_ve_devam: () => ({ data: { ok: true }, error: null }) });
  basarili.window.__ovsyncTakip = { veri: { eski: 1 }, zaman: 1 };
  await basarili.sandbox.tohumlamaBosVeDevam({ p_tohumlama_id: 't1', p_secim: 'TAKIP' });
  assert.strictEqual(basarili.window.__ovsyncTakip, null, 'başarılı sarmal çağrı cache\'i bozmalı');

  const reddi = loadApi({ tohumlama_bos_ve_devam: () => ({ data: { ok: false, mesaj: 'OVSYNC_SECIM_KISIR' }, error: null }) });
  reddi.window.__ovsyncTakip = { veri: { eski: 1 }, zaman: 1 };
  await assert.rejects(() => reddi.sandbox.tohumlamaBosVeDevam({ p_tohumlama_id: 't1', p_secim: 'OVSYNC' }));
  assert.strictEqual(reddi.window.__ovsyncTakip, null, 'red yolunda da cache bozulmalı');
});

// ══ _ovsyncTakipInvalidate ══

test('_ovsyncTakipInvalidate: window.__ovsyncTakip = null yapar', () => {
  const { sandbox, window } = loadApi();
  window.__ovsyncTakip = { veri: { x: 1 }, zaman: 1 };
  sandbox._ovsyncTakipInvalidate();
  assert.strictEqual(window.__ovsyncTakip, null);
});

// ══ H8 — istemci 40P01/55P03 eşlemesi (rpc() hata satırı; otomatik retry YOK) ══

test('H8: error.code=40P01 (deadlock_detected) → Türkçe çakışma mesajı, rpc tam 1 kez çağrılır (retry YOK)', async () => {
  const { sandbox, calls } = loadApi({
    tohumlama_bos_ve_devam: () => ({ data: null, error: { code: '40P01', message: 'deadlock detected' } }),
  });
  await assert.rejects(
    () => sandbox.rpc('tohumlama_bos_ve_devam', {}),
    e => {
      assert.strictEqual(e.message, 'İşlem başka bir kayıtla çakıştı, tekrar deneyin');
      return true;
    },
  );
  assert.strictEqual(calls.length, 1, 'otomatik retry yasak — rpc tam 1 kez çağrılmalı');
});

test('H8: error.code=55P03 (lock_not_available) → aynı Türkçe mesaj, retry YOK', async () => {
  const { sandbox, calls } = loadApi({
    gorev_tamamla: () => ({ data: null, error: { code: '55P03', message: 'lock_not_available' } }),
  });
  await assert.rejects(
    () => sandbox.rpc('gorev_tamamla', {}),
    e => {
      assert.strictEqual(e.message, 'İşlem başka bir kayıtla çakıştı, tekrar deneyin');
      return true;
    },
  );
  assert.strictEqual(calls.length, 1);
});

test('H8: eşleşmeyen kod mevcut _trErr akışında kalır (ör. duplicate key → Türkçe karşılık)', async () => {
  const { sandbox } = loadApi({
    hayvan_ekle: () => ({ data: null, error: { code: '23505', message: 'duplicate key value violates unique constraint' } }),
  });
  await assert.rejects(
    () => sandbox.rpc('hayvan_ekle', {}),
    e => {
      assert.strictEqual(e.message, 'Bu kayıt zaten mevcut');
      return true;
    },
  );
});

test('H8: kodu olmayan hata → _trErr orijinal mesajı aynen taşır (davranış değişmedi)', async () => {
  const { sandbox } = loadApi({
    deneme: () => ({ data: null, error: { message: 'Bu hayvan aktif değil' } }),
  });
  await assert.rejects(
    () => sandbox.rpc('deneme', {}),
    e => {
      assert.strictEqual(e.message, 'Bu hayvan aktif değil');
      return true;
    },
  );
});

// ══ Invalidate envanteri (grep tabanlı senkron test — plan P4 nokta listesi) ══
// P4 yalnız api.js'teki yardımcıyı + api.js içi noktayı kurar; ui.js/forms.js'teki
// ÇAĞRI noktaları P9/P10'un işi. Bu test planın NOKTA LİSTESİNİN kaynakla senkronunu
// kilitler: bir akış adı/satırı refactor ederse test kırılır ve envanter güncellenir.

test('invalidate envanteri: api.js yardımcısı + api.js içi nokta (tohumlamaBosVeDevam) kaynakta', () => {
  assert.match(apiSrc, /function _ovsyncTakipInvalidate\s*\(/, '_ovsyncTakipInvalidate tanımı yok');
  assert.match(apiSrc, /window\.__ovsyncTakip\s*=\s*null/, 'yardımcı gövdesi cache\'i null\'lamıyor');
  // api.js içi nokta: sarmal çağrı cache'i bozar (tohumlamaBosVeDevam gövdesinde çağrı)
  const bosVeDevamIdx = apiSrc.indexOf('async function tohumlamaBosVeDevam');
  assert.ok(bosVeDevamIdx !== -1, 'tohumlamaBosVeDevam yok');
  const sonraki = apiSrc.indexOf('async function', bosVeDevamIdx + 10);
  const govde = apiSrc.slice(bosVeDevamIdx, sonraki === -1 ? apiSrc.length : sonraki);
  assert.match(govde, /_ovsyncTakipInvalidate\s*\(/, 'api.js içi invalidate noktası (sarmal gövdesinde) yok');
});

test('invalidate envanteri: plan P4 noktaları ui.js/forms.js kaynakta senkron (P9/P10 çağrıları buraya düşecek)', () => {
  const NOKTALAR = [
    // [dosya, aranan, plan referansı]
    ['js/ui.js', 'async function ovsyncBaslat', 'plan P4 / ui.js:1812 (güncel 1799)'],
    ['js/ui.js', 'function _protokolIptalAkisi', 'plan P4 / ui.js:1873 (güncel 1857)'],
    ['js/ui.js', "rpc('gorev_ertele'", 'plan P4 / ui.js:1568'],
    ['js/ui.js', "rpc('hizli_uygulama'", 'plan P4 / ui.js:3722+ (hızlı/seans/toplu PG)'],
    ['js/forms.js', 'async function submitInsem', 'plan P4 / forms.js:426-433 tohumlama kaydı'],
    ['js/forms.js', 'async function tohSonuc', 'plan P4 / forms.js:4344-4368 gebe/bos'],
    ['js/forms.js', 'apiCokluKaydir(', 'plan P4 / vaka_kalan_gunleri_kaydir(_coklu)'],
    ['js/forms.js', "rpc('bulk_ilac'", 'plan P4 / toplu PG'],
    ['js/forms.js', 'async function seansTamamla', 'plan P4 / seans PG yolu'],
    ['js/forms.js', "rpc('gebelik_kaydet_manual'", 'plan P4 / gebelik muayenesi (GEBE modu dahil)'],
  ];
  for (const [dosya, aranan, kaynak] of NOKTALAR) {
    const src = readFile(dosya);
    assert.ok(src.includes(aranan), `${dosya}: "${aranan}" bulunamadı — invalidate envanteri kaynağıyla senkron dışı (${kaynak})`);
  }
});
