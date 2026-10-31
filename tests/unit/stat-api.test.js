// tests/unit/stat-api.test.js — istatistik AP1 (T8): js/api.js atölye RPC sarmalayıcıları.
// Supabase'e ağ çağrısı yok; createClient stub'u + makeClient kalıbı api.test.js'ten.
// Test adları plan Task 8 Step 1 ile birebir (docs/plans/2026-10-17-istatistik-ap1-saglik-plan.md).
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { loadBrowserModule, makeStorage } = require('./support/loadModule.js');

function loadApi(rpcHandlers = {}) {
  const calls = { rpc: [] };
  const client = {
    rpc: async (name, params) => {
      calls.rpc.push({ name, params });
      const h = rpcHandlers[name];
      if (!h) return { data: null, error: { message: `stub: rpc "${name}" yok` } };
      return await h(params);
    },
    from: () => { throw new Error('test: db.from kullanılmamalı'); },
    channel: () => { throw new Error('test: db.channel kullanılmamalı'); },
  };
  const loaded = loadBrowserModule('js/api.js', {
    storage: makeStorage(),
    extra: {
      supabase: { createClient: () => client },
      navigator: { onLine: true, userAgent: 'node-test' },
      toast() {}, getUserMessage: e => e.message,
      renderFromLocal() {}, updateSyncBar() {}, hideSyncBar() {},
    },
  });
  return { ...loaded, calls };
}

const plain = v => JSON.parse(JSON.stringify(v));
const CUMLE = { v: 1, alan: 'saglik', hastalik: { tip: 'tumu' }, olculer: ['saglik_basari'], kirilim: 'yok' };
const SERI = { zarflar: [{ olcu: 'saglik_basari' }], kombinasyon: null, fiyat_eksik: [] };
const okSeri = () => ({ data: SERI, error: null });

test('seri_parametre', async () => {
  const { sandbox, calls } = loadApi({ stat_atolye_seri: okSeri });
  const gecici = { ilac_fiyat: { 'a-b': 12.5 } };
  const r = await sandbox.statAtolyeSeri(CUMLE, gecici);
  assert.deepStrictEqual(plain(r), SERI);
  assert.strictEqual(calls.rpc.length, 1);
  assert.strictEqual(calls.rpc[0].name, 'stat_atolye_seri');
  assert.deepStrictEqual(plain(calls.rpc[0].params), { p_cumle: CUMLE, p_gecici: gecici });
  // gecici verilmezse {} gider
  await sandbox.statAtolyeSeri({ ...CUMLE, kirilim: 'zaman_ay' });
  assert.deepStrictEqual(plain(calls.rpc[1].params.p_gecici), {});
});

test('seri_onbellek', async () => {
  const { sandbox, calls } = loadApi({ stat_atolye_seri: okSeri });
  await sandbox.statAtolyeSeri(CUMLE, { ilac_fiyat: { x: 1 } });
  await sandbox.statAtolyeSeri(CUMLE, { ilac_fiyat: { x: 1 } });
  assert.strictEqual(calls.rpc.length, 1);
});

test('seri_gecici_anahtar', async () => {
  const { sandbox, calls } = loadApi({ stat_atolye_seri: okSeri });
  await sandbox.statAtolyeSeri(CUMLE, { ilac_fiyat: { x: 1 } });
  await sandbox.statAtolyeSeri(CUMLE, { ilac_fiyat: { x: 2 } });
  assert.strictEqual(calls.rpc.length, 2);
  assert.deepStrictEqual(plain(calls.rpc[1].params.p_gecici), { ilac_fiyat: { x: 2 } });
});

test('seri_yenile', async () => {
  let n = 0;
  const { sandbox, calls } = loadApi({ stat_atolye_seri: () => ({ data: { tur: ++n }, error: null }) });
  assert.strictEqual((await sandbox.statAtolyeSeri(CUMLE, {})).tur, 1);
  assert.strictEqual((await sandbox.statAtolyeSeri(CUMLE, {}, { yenile: true })).tur, 2);
  assert.strictEqual(calls.rpc.length, 2);
  // yenile önbelleğin üzerine yazdı: düz çağrı yeni sonucu önbellekten verir
  assert.strictEqual((await sandbox.statAtolyeSeri(CUMLE, {})).tur, 2);
  assert.strictEqual(calls.rpc.length, 2);
});

test('seri_hata_onbelleksiz', async () => {
  let n = 0;
  const { sandbox, calls } = loadApi({
    stat_atolye_seri: () => (++n === 1 ? { data: null, error: { message: 'STAT_CUMLE:olculer:bos' } } : okSeri()),
  });
  await assert.rejects(sandbox.statAtolyeSeri(CUMLE, {}), /STAT_CUMLE:olculer:bos/);
  const r = await sandbox.statAtolyeSeri(CUMLE, {});
  assert.deepStrictEqual(plain(r), SERI);
  assert.strictEqual(calls.rpc.length, 2);
});

test('invalidate_hepsi', async () => {
  const { sandbox, window, calls } = loadApi({
    stat_atolye_seri: okSeri,
    stat_atolye_secenekler: () => ({ data: { hastaliklar: [] }, error: null }),
    stat_olcum_listele: () => ({ data: [{ ad: 'saglik_basari' }], error: null }),
  });
  await sandbox.statAtolyeSeri(CUMLE, {});
  await sandbox.statAtolyeSecenekler(CUMLE);
  await sandbox.statOlcumListele();
  await sandbox.statAtolyeSeri(CUMLE, {});
  await sandbox.statAtolyeSecenekler(CUMLE);
  await sandbox.statOlcumListele();
  assert.strictEqual(calls.rpc.length, 3);
  sandbox._statInvalidate();
  assert.strictEqual(window.__statOlcumler, null);
  assert.deepStrictEqual(plain(window.__statCache), {});
  assert.deepStrictEqual(plain(window.__statSecenekCache), {});
  await sandbox.statAtolyeSeri(CUMLE, {});
  await sandbox.statAtolyeSecenekler(CUMLE);
  await sandbox.statOlcumListele();
  assert.strictEqual(calls.rpc.length, 6);
  assert.deepStrictEqual(calls.rpc.map(c => c.name).slice(3),
    ['stat_atolye_seri', 'stat_atolye_secenekler', 'stat_olcum_listele']);
});

test('grafik_kaydet_parametre', async () => {
  const { sandbox, window, calls } = loadApi({ stat_grafik_kaydet: () => ({ data: 'uuid-1', error: null }) });
  window.__statCache = { k: 1 };
  const id = await sandbox.statGrafikKaydet(null, 'Başlık', CUMLE);
  assert.strictEqual(id, 'uuid-1');
  assert.strictEqual(calls.rpc[0].name, 'stat_grafik_kaydet');
  assert.deepStrictEqual(plain(calls.rpc[0].params), { p_id: null, p_baslik: 'Başlık', p_cumle: CUMLE });
  // yazan RPC hesap önbelleğini boşaltmaz
  assert.deepStrictEqual(plain(window.__statCache), { k: 1 });
});

test('hata_kodu_cumle', () => {
  const { sandbox } = loadApi({});
  assert.deepStrictEqual(plain(sandbox.statHataKodu(new Error('STAT_CUMLE:ilac.y:x_yok'))),
    { tip: 'cumle', yol: 'ilac.y', neden: 'x_yok' });
  assert.deepStrictEqual(plain(sandbox.statHataKodu(new Error('STAT_CUMLE:gecici.ilac_fiyat:pozitif_sayi_degil'))),
    { tip: 'cumle', yol: 'gecici.ilac_fiyat', neden: 'pozitif_sayi_degil' });
  // tanınmayan hata → genel
  assert.deepStrictEqual(plain(sandbox.statHataKodu(new Error('boom'))), { tip: 'genel' });
  assert.deepStrictEqual(plain(sandbox.statHataKodu(null)), { tip: 'genel' });
});

test('hata_kodu_grafik', () => {
  const { sandbox } = loadApi({});
  assert.deepStrictEqual(plain(sandbox.statHataKodu(new Error('STAT_GRAFIK:yok'))), { tip: 'grafik', neden: 'yok' });
  assert.deepStrictEqual(plain(sandbox.statHataKodu(new Error('STAT_GRAFIK:sira_kumesi'))),
    { tip: 'grafik', neden: 'sira_kumesi' });
});

test('hata_kodu_cevrimdisi', async () => {
  // uçtan uca: db.rpc iletim hatası → rpc() yeniden atar → statHataKodu
  let mod = 'throw';
  const { sandbox } = loadApi({
    stat_atolye_seri: () => {
      if (mod === 'throw') throw new TypeError('Failed to fetch');   // rpc(): 'İnternet bağlantısı gerekli'
      // supabase-js fetch hatasını throw etmez, '<name>: <message>' olarak döndürür (postgrest-js 2.x)
      if (mod === 'safari') return { data: null, error: { message: 'TypeError: Load failed' } };   // _ERR_MAP eşlemez
      return { data: null, error: { message: 'Failed to fetch' } };   // _trErr: 'Sunucuya ulaşılamıyor'
    },
  });
  const yakala = async () => { try { await sandbox.statAtolyeSeri(CUMLE, {}); } catch (e) { return e; } assert.fail('reject beklenirdi'); };
  assert.deepStrictEqual(plain(sandbox.statHataKodu(await yakala())), { tip: 'cevrimdisi' });
  mod = 'error';
  assert.deepStrictEqual(plain(sandbox.statHataKodu(await yakala())), { tip: 'cevrimdisi' });
  mod = 'safari';
  assert.deepStrictEqual(plain(sandbox.statHataKodu(await yakala())), { tip: 'cevrimdisi' });
  // rpc dışı TypeError programlama hatasıdır (B23) → genel; sandbox realm'ında üretilir
  const tipHatasi = vm.runInContext("new TypeError('x is undefined')", sandbox);
  assert.deepStrictEqual(plain(sandbox.statHataKodu(tipHatasi)), { tip: 'genel' });
  assert.deepStrictEqual(plain(sandbox.statHataKodu(vm.runInContext("new TypeError('Failed to fetch')", sandbox))),
    { tip: 'genel' });
  sandbox.navigator.onLine = false;
  assert.deepStrictEqual(plain(sandbox.statHataKodu(new Error('boom'))), { tip: 'cevrimdisi' });
});

test('eski_api_yok', () => {
  const { sandbox } = loadApi({});
  assert.strictEqual(typeof sandbox.statOlcumCagir, 'undefined');
  assert.strictEqual(typeof sandbox.statSonucOku, 'undefined');
});

// ── plan listesine ek (Produces imzalarının geri kalanı) ──
test('ek_secenekler_onbellek_ve_vakalar_onbelleksiz', async () => {
  const { sandbox, calls } = loadApi({
    stat_atolye_secenekler: () => ({ data: { hastaliklar: [] }, error: null }),
    stat_atolye_vakalar: () => ({ data: [], error: null }),
  });
  await sandbox.statAtolyeSecenekler(CUMLE);
  await sandbox.statAtolyeSecenekler(CUMLE);
  assert.strictEqual(calls.rpc.length, 1);
  assert.deepStrictEqual(plain(calls.rpc[0].params), { p_cumle: CUMLE });
  await sandbox.statAtolyeVakalar(CUMLE, 'g1');
  await sandbox.statAtolyeVakalar(CUMLE, 'g1');
  assert.strictEqual(calls.rpc.length, 3);
  assert.strictEqual(calls.rpc[1].name, 'stat_atolye_vakalar');
  assert.deepStrictEqual(plain(calls.rpc[1].params), { p_cumle: CUMLE, p_grup: 'g1' });
});

test('ek_grafik_listele_sil_sirala_parametre', async () => {
  const ok = () => ({ data: null, error: null });
  const { sandbox, calls } = loadApi({
    stat_grafik_listele: () => ({ data: [], error: null }), stat_grafik_sil: ok, stat_grafik_sirala: ok,
  });
  await sandbox.statGrafikListele();
  await sandbox.statGrafikListele();
  await sandbox.statGrafikSil('u1');
  await sandbox.statGrafikSirala(['u2', 'u1']);
  assert.deepStrictEqual(plain(calls.rpc), [
    { name: 'stat_grafik_listele', params: {} },
    { name: 'stat_grafik_listele', params: {} },
    { name: 'stat_grafik_sil', params: { p_id: 'u1' } },
    { name: 'stat_grafik_sirala', params: { p_idler: ['u2', 'u1'] } },
  ]);
});

test('ek_ucusta_invalidate_bayat_yazmaz', async () => {
  let birak;
  const bekle = new Promise(r => { birak = r; });
  const { sandbox, window, calls } = loadApi({
    stat_atolye_seri: async () => { await bekle; return okSeri(); },
    stat_atolye_secenekler: async () => { await bekle; return { data: { a: 1 }, error: null }; },
  });
  const p1 = sandbox.statAtolyeSeri(CUMLE, {});
  const p2 = sandbox.statAtolyeSecenekler(CUMLE);
  sandbox._statInvalidate();   // senkron araya girer (ör. sync drain)
  birak();
  assert.deepStrictEqual(plain(await p1), SERI);   // çağırana sonuç yine döner
  await p2;
  assert.deepStrictEqual(plain(window.__statCache), {});
  assert.deepStrictEqual(plain(window.__statSecenekCache), {});
  await sandbox.statAtolyeSeri(CUMLE, {});
  assert.strictEqual(calls.rpc.length, 3);   // bayat sonuç önbellekte kalmadı → yeniden rpc
});
