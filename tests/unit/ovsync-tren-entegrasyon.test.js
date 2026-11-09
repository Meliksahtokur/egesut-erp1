// tests/unit/ovsync-tren-entegrasyon.test.js — N4 UB1: tren API sarmalayıcı + RPC_TABLES + modül yükleme
// Kapsam (PLAN UB1 :481-490 + F13 + bayrak-kapalı regresyon); js/ui.js, js/forms.js'e DOKUNMAZ.
// Desen: tests/unit/ovsync-api.test.js loadApi kopyası (vm + supabase stub; ağ yok).
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const {
  loadBrowserModule,
  makeStorage,
  makeDomStub,
  makeElement,
} = require('./support/loadModule.js');

const API = 'js/api.js';
const REPO_ROOT = path.join(__dirname, '..', '..');
const apiKaynagi = fs.readFileSync(path.join(REPO_ROOT, API), 'utf8');
const htmlKaynagi = fs.readFileSync(path.join(REPO_ROOT, 'index.html'), 'utf8');

// F13: PLAN 9 tablosu ∪ drug_administrations ∪ start_first_service_protocol /
// protokol_iptal / seans_tamamla haritalarının tabloları (api.js:418,:428-432,:499 kalıbı).
const F13_SET = ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'drug_administrations',
  'gorev_log', 'islem_log', 'stok', 'stok_hareket', 'diseases', 'drugs', 'tedavi_sablonu',
  'protokol_ayar', 'protokol_instance'];
const YAZMA_RPCLERI = ['ovsync_tren_ertele', 'ovsync_hayvan_ertele', 'ovsync_bastan_baslat',
  'ovsync_pg48_tohumla', 'ovsync_tren_ayar_guncelle'];
// Salt-okuma tren RPC'leri haritaya GİRMEZ (EG-10 invariantı; PLAN UB1 :486-489).
const SALT_OKUMA_RPCLERI = ['ovsync_tren_listele', 'ovsync_tren_onizle', 'ovsync_tren_ertele_onizle',
  'dogum_sonrasi_pg_hatirlatma', 'ovsync_tren_yeniden_hedefle'];

// ── Sahteler ──────────────────────────────────────────────────────────

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

function loadApi(rpcHandlers = {}, { onLine = true } = {}) {
  const sb = makeClientStub(rpcHandlers);
  const loaded = loadBrowserModule(API, {
    storage: makeStorage(),
    expose: ['RPC_TABLES', 'TABLES'],
    extra: {
      supabase: { createClient: sb.createClient },
      navigator: { onLine, userAgent: 'node-test' },
      toast: () => {},
    },
  });
  return { ...loaded, calls: sb.calls };
}

function rpcMapBolumu() {
  const bas = apiKaynagi.indexOf('const RPC_MAP = {');
  assert.ok(bas > -1, 'RPC_MAP bloğu api.js\'te bulunamadı');
  return apiKaynagi.slice(bas, apiKaynagi.indexOf('};', bas));
}

// ══ RPC_TABLES F13 ══

test('UB1 RPC_TABLES: 5 tren yazma RPCsi F13 birleşim setiyle mapli', () => {
  const { exposed } = loadApi();
  const { RPC_TABLES, TABLES } = exposed;
  const tabloKumesi = new Set(TABLES);
  for (const ad of YAZMA_RPCLERI) {
    assert.ok(Array.isArray(RPC_TABLES[ad]) && RPC_TABLES[ad].length > 0, `${ad} RPC_TABLES'te yok`);
    assert.deepStrictEqual([...RPC_TABLES[ad]].sort(), [...F13_SET].sort(), `${ad} pull seti F13 birleşimi değil`);
    for (const t of RPC_TABLES[ad]) {
      assert.ok(tabloKumesi.has(t), `${ad} → "${t}" TABLES listesinde yok`);
    }
  }
});

test('UB1 RPC_TABLES: salt-okuma tren RPCsi haritada DEĞİL (EG-10)', () => {
  const { exposed } = loadApi();
  for (const ad of SALT_OKUMA_RPCLERI) {
    assert.strictEqual(exposed.RPC_TABLES[ad], undefined, `salt-okuma ${ad} haritaya girdi — invariant ihlali`);
  }
  const rm = rpcMapBolumu();
  assert.ok(!rm.includes('ovsync'), 'RPC_MAP (offline kuyruk replay) tren RPCsi içermez — online-only');
});

// ══ apiOvsyncTren ══

test('UB1 apiOvsyncTren: offline → Error(İnternet yok), rpc yok, kuyruk yok', async () => {
  const { sandbox, window, calls } = loadApi({}, { onLine: false });
  assert.strictEqual(typeof sandbox.apiOvsyncTren, 'function', 'apiOvsyncTren api.js\'te yok');
  window.__ovsyncTakip = { veri: { eski: 1 }, zaman: 1 };
  await assert.rejects(
    () => sandbox.apiOvsyncTren('ovsync_hayvan_ertele', { p_hayvan_id: 'h1', p_gun: 1 }),
    (e) => {
      assert.strictEqual(e?.message, 'İnternet yok');
      return true;
    },
  );
  assert.strictEqual(calls.length, 0, 'offline yolda rpc çağrılmamalı');
  assert.deepStrictEqual(window.__ovsyncTakip, { veri: { eski: 1 }, zaman: 1 }, 'offline yolda cache korunmalı');
});

test('UB1 apiOvsyncTren: online → rpc birebir taşınır, yazma sonrası cache bozulur', async () => {
  const cikti = { ok: true, asama: 1, sonuc: 'KAYDI', yeni_tarih: '2026-11-20' };
  const { sandbox, window, calls } = loadApi({
    ovsync_hayvan_ertele: () => ({ data: cikti, error: null }),
  });
  window.__ovsyncTakip = { veri: { eski: 1 }, zaman: 1 };
  const params = { p_hayvan_id: 'h1', p_gun: 1 };
  const donen = await sandbox.apiOvsyncTren('ovsync_hayvan_ertele', params);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0].name, 'ovsync_hayvan_ertele');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(calls[0].params)), params, 'params birebir taşınmalı');
  assert.deepStrictEqual(donen, cikti, 'dönüş aynen taşınmalı (F10 alanları dahil)');
  assert.strictEqual(window.__ovsyncTakip, null, 'yazma sonrası takip cachei bozulmalı');
});

test('UB1 apiOvsyncTren: sunucu reddi (ok:false) → throw, e.data korunur', async () => {
  const red = { ok: false, mesaj: 'OVSYNC_TREN_KAPALI:{"rpc":"ovsync_hayvan_ertele"}' };
  const { sandbox } = loadApi({
    ovsync_hayvan_ertele: () => ({ data: red, error: null }),
  });
  await assert.rejects(
    () => sandbox.apiOvsyncTren('ovsync_hayvan_ertele', { p_hayvan_id: 'h1', p_gun: 1 }),
    (e) => {
      assert.ok(e.data, 'rpc ok:false gövdesi e.data ile taşınmalı');
      assert.match(e.data.mesaj, /OVSYNC_TREN_KAPALI/);
      return true;
    },
  );
});

// ══ index.html modül yükleme ══

test('UB1 index.html: ovsync-tren.js ui.js’ten önce, aynı damga, tek ?v=', () => {
  const srcs = [...htmlKaynagi.matchAll(/<script src="([^"]+)"/g)].map((m) => m[1]);
  const yerel = srcs.map((s) => s.split('?')[0]);
  const tren = srcs.indexOf('js/ovsync-tren.js?v=20261110-2');
  assert.ok(tren >= 0, 'js/ovsync-tren.js etiketi mevcut damgayla (20261110-2) yok');
  const ui = yerel.indexOf('js/ui.js');
  assert.ok(ui >= 0, 'js/ui.js etiketi yok');
  assert.ok(tren < ui, 'ovsync-tren.js ui.js’ten ÖNCE yüklenmeli');
  // Bitişik bloklara dokunma: istatistik bloğu degisiklikler.js sonrası/app.js öncesi bitişik kalmalı
  const deg = yerel.indexOf('js/degisiklikler/degisiklikler.js');
  const app = yerel.indexOf('js/app.js');
  assert.ok(deg >= 0 && app > deg, 'degisiklikler/app etiketleri yok');
  assert.strictEqual(yerel[deg + 1], 'vendor/chart.umd.min.js', 'istatistik bloğu başı kaydı');
  assert.strictEqual(yerel[app - 1], 'js/istatistik/atolye.js', 'istatistik bloğu sonu kaydı');
  // ?v= tek değer kuralı (UB5 toplu bumpı: 20261110-2)
  const damgalar = [...htmlKaynagi.matchAll(/\?v=([0-9]{8}-[0-9]+)/g)].map((m) => m[1]);
  assert.deepStrictEqual([...new Set(damgalar)], ['20261110-2'], 'karışık damga: ' + [...new Set(damgalar)].join(' / '));
});

// ══ Bayrak kapalı → eski yol/html birebir (UB1 yalnız ekler) ══

test('UB1 bayrak kapalı: mevcut RPC_TABLES haritaları + imza aynen, markup tek ek satır', () => {
  const { exposed, sandbox } = loadApi();
  // F13'ün birleşime kattığı mevcut haritalar değişmedi
  assert.deepStrictEqual([...exposed.RPC_TABLES.start_first_service_protocol].sort(),
    ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'gorev_log',
      'islem_log', 'stok', 'stok_hareket', 'diseases', 'drugs', 'tedavi_sablonu'].sort());
  assert.deepStrictEqual([...exposed.RPC_TABLES.protokol_iptal].sort(),
    ['gorev_log', 'islem_log', 'cases', 'treatment_days', 'treatment_day_uygulamalar',
      'drug_administrations', 'stok', 'stok_hareket', 'protokol_instance'].sort());
  assert.deepStrictEqual([...exposed.RPC_TABLES.seans_tamamla].sort(),
    ['treatment_day_uygulamalar', 'stok', 'stok_hareket', 'gorev_log', 'treatment_days'].sort());
  assert.deepStrictEqual([...exposed.RPC_TABLES.gorev_ertele], ['gorev_log', 'islem_log']);
  // İmza/fonksiyon adı değişmedi (loadExtractedFunction kilidi)
  assert.strictEqual(typeof sandbox.rpc, 'function');
  assert.strictEqual(typeof sandbox.rpcOptimistic, 'function');
  // Markup: dosyada tek 'ovsync-tren' geçişi = yeni script satırı (bayrak kapalı DOM aynen)
  const gecisler = htmlKaynagi.match(/ovsync-tren/g) || [];
  assert.strictEqual(gecisler.length, 1, `'ovsync-tren' geçiş sayısı (tek script satırı olmalı): ${gecisler.length}`);
  const scriptDisi = htmlKaynagi.split('\n').filter((l) => !l.trim().startsWith('<script'));
  assert.ok(!scriptDisi.some((l) => l.includes('ovsync-tren.js')), 'script dışı markup ovsync-tren taşımamalı');
});

// ══ UB2 tren ekranı (js/ui.js + js/forms.js; PLAN UB3 davranışları N4-UB2 parçasında) ══
// Desen: extractFunctionSource ile tren yolu + UA1 yardımcıları tek vm ctx'te
// (render ailesi birbirini çağırır; tarayıcı globali yok).
const vm = require('node:vm');
const { extractFunctionSource, loadExtractedFunction } = require('./support/loadModule.js');

const UB2_UI_FN = [
  '_ovsyncGunAy', '_ovsyncKpaHtml', '_ovsyncDenemeRozeti', '_ovsyncSapmaRozeti',
  '_ovsyncTakipteRozeti', '_ovsyncMuayeneHtml', '_ovsyncSonlanmaRozeti', '_ovsyncGunDurumu',
  '_ovsyncGunSinif', '_ovsyncGunlerHtml', '_ovsyncS0Tip', '_ovsyncS0SatirHtml', '_ovsyncS1SatirHtml',
  '_ovsyncS2SatirHtml', '_ovsyncS3SatirHtml', '_ovsyncS4SatirHtml', '_ovsyncBilinmeyenSatirHtml',
  '_ovsyncSatirHtml', '_ovsyncBolumHtml', '_ovsyncDalgaGrupla', '_ovsyncTabanEtiketi',
  '_ovsyncBaglamAl', '_ovsyncMuayeneSatirAc', '_ovsyncBaslatKilitHtml', '_ovsyncBaslatPencereGunu',
  '_erteleBtnHtml', '_ertelemeOnline', 'renderOvsyncSayfa',
  // UB2 yeni: tren dalı kapısı + satır sarmalayıcı + PG+48 satırı + toptan gövde eki
  '_ovsyncTrenSayfaAcik', '_ovsyncPg48SatirHtml', '_ovsyncTrenSatirHtml',
  '_ovsyncTrenGovdeHtml', '_ovsyncToptanGovdeHtml',
  // N4-F4: aşama-0 tren kartı + kart içine ekleme
  '_ovsyncTrenBaslatKartHtml', '_ovsyncKartaEkle',
];
const UB2_UA1_FN = [
  '_ovtGunNo', '_ovtIso', '_ovtGunEkle', '_ovtFark', '_ovtGunAd', '_ovtGunAdEk', '_ovtHaftaGunu',
  '_ovtGunAy', '_ovtE', '_ovtHataBildir', '_ovtTrenBugunIs', 'ovsyncToptanTarih', '_ovtRitimDisiNot',
  'ovsyncIlkToptanTarih', 'ovsyncToptanBaslikTreni', 'ovsyncTrenBaslikHtml', 'ovsyncTrenGrupla', '_ovtSecimGecerli',
  'ovsyncToptanOnayAcikMi', '_ovtOnSatir', '_ovtVazgecOnaySatiri', 'ovsyncToptanOnizlemeHtml',
  'ovsyncAsamaAksiyonHtml', 'ovsyncTrenIsEtiketi',
];
const UB2_FORMS_FN = [
  '_ovsyncTrenTarihAd', '_ovsyncBastanSonucMetni', '_ovsyncErteleSonucMetni', '_ovsyncToptanSonucMetni',
];

const UB2_BUGUN = '2026-11-19'; // Perşembe — mockup 02a ile aynı tren günü

function ub2UiCtx(ekstra = {}) {
  // UA1 modül sabitleri (fonksiyon değil; extract listesine giremez — tek satırlık const'lar)
  const ua1Kaynak = fs.readFileSync(path.join(REPO_ROOT, 'js/ovsync-tren.js'), 'utf8');
  const sabitler = ua1Kaynak.match(/^const _OVT_(GUN_KISA|GUN_UZUN|AY|AY_EK|TREN_IS)\b.*$/gm) || [];
  const src = [
    ...sabitler,
    ...UB2_UI_FN.map((n) => extractFunctionSource('js/ui.js', n)),
    ...UB2_UA1_FN.map((n) => extractFunctionSource('js/ovsync-tren.js', n)),
  ].join('\n');
  const ctx = {
    console, Math, JSON, Date, Intl,
    esc: (v) => String(v == null ? '' : v),
    escAttr: (v) => String(v == null ? '' : v),
    bugun: () => UB2_BUGUN,
    window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: null },
    ...ekstra,
  };
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(src, ctx, { filename: 'ub2-tren-ctx' });
  return ctx;
}

function ub2Render(veri, trenVeri) {
  const ctx = ub2UiCtx();
  const tv = trenVeri === undefined ? 'undefined' : JSON.stringify(trenVeri);
  return vm.runInContext(
    `renderOvsyncSayfa(${JSON.stringify(veri)}, '${UB2_BUGUN}', ${tv})`, ctx,
  );
}

function ub2FormsCtx() {
  const src = UB2_FORMS_FN.map((n) => extractFunctionSource('js/forms.js', n)).join('\n');
  const ctx = { console, Math, JSON, Date, esc: (v) => String(v == null ? '' : v) };
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(src, ctx, { filename: 'ub2-forms-ctx' });
  return ctx;
}

// Sabit fikstür: 2 tren (bugün + gelecek hafta) + 1 bağımsız
function ub2TrenVerisi() {
  return {
    aktif: true, bugun: UB2_BUGUN, capa: '2026-11-12',
    trenler: [
      {
        tren_gunu: '2026-11-19', ritim_disi: false,
        uyeler: [
          {
            hayvan_id: 'h1', kupe_no: '36', case_id: 'c1', asama: 2, ovsync_tren: '2026-11-19',
            sonraki_is: { tarih: '2026-11-19', saat: '18:00', tur: 'TAI' }, pg_pay: null,
            pg1_zaman: '2026-11-17T06:40:00.000Z', ritim_disi_neden: null,
          },
          {
            hayvan_id: 'h2', kupe_no: '38', case_id: 'c2', asama: 1, ovsync_tren: '2026-11-19',
            sonraki_is: { tarih: '2026-11-19', saat: '18:00', tur: 'PG1' }, pg_pay: 1,
            pg1_zaman: null, ritim_disi_neden: null,
          },
        ],
      },
      {
        tren_gunu: '2026-11-26', ritim_disi: false,
        uyeler: [
          {
            hayvan_id: 'h3', kupe_no: '169', case_id: 'c3', asama: 0, ovsync_tren: '2026-11-26',
            sonraki_is: null, pg_pay: null, pg1_zaman: null, ritim_disi_neden: null,
          },
          {
            hayvan_id: 'h6', kupe_no: '5708', case_id: 'c6', asama: 1, ovsync_tren: '2026-11-26',
            sonraki_is: { tarih: '2026-11-26', saat: '18:00', tur: 'PG1' }, pg_pay: 0,
            pg1_zaman: null, ritim_disi_neden: null,
          },
        ],
      },
    ],
    bagimsizlar: [
      {
        hayvan_id: 'h9', kupe_no: '1203', case_id: 'c9', asama: 0, ovsync_tren: null,
        sonraki_is: { tarih: '2026-11-24', saat: '18:00', tur: 'GNRH1' }, pg_pay: null,
        pg1_zaman: null, ritim_disi_neden: null,
      },
    ],
    ileri_sayisi: 0,
  };
}

function ub2TakipVerisi() {
  return {
    kpa: { aktif: 5, bugun: 1, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 0 },
    satirlar: [
      { bolum: 'S0', hayvan_id: 'h1', kupe_no: '36', grup: 'Sağmal', gunler: [], gecikme_gun: 0 },
      { bolum: 'S1', hayvan_id: 'h2', kupe_no: '38', grup: 'Sağmal', taban_turu: 'dogum', gunler: [], dalga_anahtari: '2026-11-12' },
      { bolum: 'S1', hayvan_id: 'h3', kupe_no: '169', grup: 'Sağmal', taban_turu: 'duve', gunler: [], dalga_anahtari: '2026-11-12' },
      { bolum: 'S1', hayvan_id: 'h6', kupe_no: '5708', grup: 'Sağmal', taban_turu: 'duve', gunler: [] },
      { bolum: 'S1', hayvan_id: 'h9', kupe_no: '1203', grup: 'Sağmal', taban_turu: 'duve', gunler: [] },
    ],
  };
}

test('UB2 F1: S0 üyesi tren başlığında, başlık sayısı uyeler.length, S0 kartta aksiyon', () => {
  // h2 takip satırı yok → başlık yine uyeler.length (2) demeli (BOŞLUK-5)
  const veri = ub2TakipVerisi();
  veri.satirlar = veri.satirlar.filter((s) => s.hayvan_id !== 'h2');
  const html = ub2Render(veri, ub2TrenVerisi());
  assert.ok(html.includes('Tren · Per 19 Kas'), 'ilk tren başlığı yok');
  assert.ok(html.includes('2 hayvan'), 'başlık sayısı uyeler.length olmalı (takip satırı eksikken)');
  assert.ok(html.includes('ovs-asama'), 'S0 karta ovsyncAsamaAksiyonHtml eklenmedi (F1)');
  assert.ok(html.includes('36'), 'S0 üyesi (36) tren grubunda görünmeli');
});

test('UB2 F9: ertele düğmesi yalnız bugünden itibaren üyeli ilk ritim günü başlığında', () => {
  const html = ub2Render(ub2TakipVerisi(), ub2TrenVerisi());
  const dugmeler = html.match(/data-ovt-aksiyon="TOPTAN"/g) || [];
  assert.strictEqual(dugmeler.length, 1, `ertele düğmesi 1 olmalı, bulundu: ${dugmeler.length}`);
  assert.ok(
    html.indexOf('data-ovt-aksiyon="TOPTAN"') < html.indexOf('Per 26 Kas'),
    'ertele düğmesi ilk başlıkta olmalı',
  );
});

test('UB2 F4: belirsiz üye → onay kapalı + baştan başlat satırı', () => {
  const ctx = ub2UiCtx();
  const plan = {
    tren: '2026-11-19', yeni_tren: '2026-11-26',
    uyeler: [{
      hayvan_id: 'h1', kupe_no: '36', case_id: 'c1', asama: null,
      sonuc: null, yeni_tarih: null, ovsync_tren: '2026-11-19',
    }],
    tren_sayisi: 1, dokunulmaz: { bagimsiz: 0, ritim_disi: 0 },
    ileri_gorevler: [], ileri_vakalar: [],
  };
  const html = vm.runInContext(
    `_ovsyncToptanGovdeHtml(${JSON.stringify(plan)}, {}, '${UB2_BUGUN}')`, ctx,
  );
  assert.ok(html.includes('Aşama belirsiz — Baştan başlat'), 'belirsiz satır metni yok');
  assert.ok(html.includes('data-ovt-aksiyon="BASTAN"'), 'belirsiz satırda baştan başlat eylemi yok');
  assert.ok(html.includes('data-ovt-aksiyon="ONAYLA" disabled'), 'belirsiz varken onay açık olmamalı (F4)');
  assert.ok(html.includes('onay açılmaz'), 'onay kapalılığı metinle söylenmeli (F4)');
});

test('UB2 BOŞLUK-4: eylem öncesi tarih yok; sonrası hedef_tarih/başladı metni', () => {
  const html = ub2Render(ub2TakipVerisi(), ub2TrenVerisi());
  // payı dolmuş aşama-1 (5708) düğmesi tarihsiz etiketi taşır
  assert.ok(html.includes('Baştan başlat → trene bin'), 'öncesi etiketi yok');
  assert.ok(
    !/Baştan başlat → [A-ZÇĞİÖŞÜ]/.test(html),
    'eylem öncesi hiçbir "Baştan başlat" tarih göstermemeli (BOŞLUK-4)',
  );
  const fctx = ub2FormsCtx();
  const treneBiner = vm.runInContext(
    `_ovsyncBastanSonucMetni({hedef_tarih:'2026-12-03',basladi:true}, '${UB2_BUGUN}')`, fctx,
  );
  assert.strictEqual(treneBiner, 'Per 3 Ara treninde başlar.', 'sonrası hedef_tarih metni yanlış');
  const bugunBasladi = vm.runInContext(
    `_ovsyncBastanSonucMetni({hedef_tarih:'${UB2_BUGUN}',basladi:true}, '${UB2_BUGUN}')`, fctx,
  );
  assert.strictEqual(bugunBasladi, 'bugün başladı.', 'hedef bugünse metin yanlış');
});

test('UB2 F11: basladi:false dönüşünde case_id yok — çağıran yeniden_hedefe dayanır', () => {
  const fctx = ub2FormsCtx();
  // case_id ALANI YOK (sözleşme M4:185); metin çökmemeli, yeniden_hedefi söylemeli
  const metin = vm.runInContext(
    `_ovsyncBastanSonucMetni({basladi:false,yeniden_hedef:'2026-11-26'})`, fctx,
  );
  assert.ok(metin.includes('Per 26 Kas'), `yeniden_hedef metinde olmalı: ${metin}`);
  assert.ok(metin.includes('başlamadı'), `başlamama durumu metinde olmalı: ${metin}`);
});

test('UB2 BOŞLUK-1: pg1_zaman varsa ≈ <gün> <saat>, yoksa yalnız PG1 + 48 s metni', () => {
  const ctx = ub2UiCtx();
  const tahmini = vm.runInContext(
    `_ovsyncPg48SatirHtml({asama:2,pg1_zaman:'2026-11-17T06:40:00.000Z'})`, ctx,
  );
  assert.ok(tahmini.startsWith('<span class="ovs-asama-etiket">≈ '), `≈ öneki yok: ${tahmini}`);
  assert.ok(tahmini.includes('09:40'), `+48 s saati (TR 09:40) yok: ${tahmini}`);
  const yoksul = vm.runInContext(`_ovsyncPg48SatirHtml({asama:2,pg1_zaman:null})`, ctx);
  assert.ok(
    yoksul.includes('<span class="ovs-asama-etiket">PG1 + 48 s\'te tohumla</span>'),
    `tarihsiz dal yalnız metin olmalı: ${yoksul}`,
  );
  const sonucCtx = ub2FormsCtx();
  // uygulandıktan sonra yanıttaki tai_hedef gösterilir
  const taiMetni = vm.runInContext(`_ovsyncErteleSonucMetni({tai_hedef:'2026-11-19'})`, sonucCtx);
  assert.ok(taiMetni.includes('Per 19 Kas'), `tai_hedef metinde olmalı: ${taiMetni}`);
});

test('UB2 BOŞLUK-2 + F5: dokunulmaz sayısı ve ileri_vakalar önizleme/sonuç metninde', () => {
  const ctx = ub2UiCtx();
  const plan = {
    tren: '2026-11-19', yeni_tren: '2026-11-26',
    uyeler: [{
      hayvan_id: 'h2', kupe_no: '38', case_id: 'c2', asama: 1,
      sonuc: 'KAYAR', yeni_tarih: '2026-11-26', ovsync_tren: '2026-11-19',
    }],
    tren_sayisi: 1, dokunulmaz: { bagimsiz: 2, ritim_disi: 1 },
    ileri_gorevler: [], ileri_vakalar: [{ case_id: 'cx', hayvan_id: 'hx', kupe_no: '5708', eski: '2026-11-19', yeni: '2026-11-26' }],
  };
  const govde = vm.runInContext(
    `_ovsyncToptanGovdeHtml(${JSON.stringify(plan)}, {}, '${UB2_BUGUN}')`, ctx,
  );
  assert.ok(govde.includes('Dokunulmaz: 2 bağımsız · 1 ritim dışı'), 'BOŞLUK-2 sayı satırı yok');
  assert.ok(!govde.includes('1203'), 'dokunulmaz küpe listesi olmamalı (BOŞLUK-2)');
  assert.ok(govde.includes('5708'), 'ileri_vakalar küpesi önizlemede olmalı (F5)');
  const fctx = ub2FormsCtx();
  const sonuc = vm.runInContext(
    `_ovsyncToptanSonucMetni({islenen:[{hayvan_id:'h2',kupe_no:'38',sonuc:'KAYAR',yeni_tarih:'2026-11-26',detay:{iptal_tai:['t1'],basladi:false,yeniden_hedef:'2026-11-26'}}],ileri_vakalar:[{kupe_no:'5708'}]})`,
    fctx,
  );
  assert.ok(sonuc.includes('iptal'), `iptal_tai sonuçta olmalı (F5): ${sonuc}`);
  assert.ok(sonuc.includes('5708'), `ileri_vakalar sonuçta olmalı (F5): ${sonuc}`);
  assert.ok(sonuc.includes('Per 26 Kas'), `yeniden_hedef sonuçta olmalı (F5): ${sonuc}`);
});

test('UB2 F3: ertele sonucu yanıttaki yeni_tarih ile söylenir', () => {
  const fctx = ub2FormsCtx();
  const metin = vm.runInContext(
    `_ovsyncErteleSonucMetni({sonuc:'KAYDI',yeni_tarih:'2026-11-20'})`, fctx,
  );
  assert.strictEqual(metin, 'Cum 20 Kas tarihine ertelendi.', `yeni_tarih metni yanlış: ${metin}`);
});

test('UB2 bayrak kapalı: eski html birebir (tren dalı çalışmaz)', () => {
  const veri = ub2TakipVerisi();
  const eski = ub2Render(veri, undefined);
  const kapali = ub2Render(veri, { aktif: false });
  assert.strictEqual(kapali, eski, 'bayrak kapalı dal tren yoluna düşmemeli (m4 kilidi)');
  assert.ok(eski.includes('Dalga:'), 'eski S1 dalga başlığı korunmalı');
  assert.ok(!eski.includes('ovs-tren-bas'), 'eski yolda tren başlığı olmamalı');
  assert.ok(!eski.includes('ovs-asama'), 'eski yolda aşama aksiyonu olmamalı');
});

// ══ UB3 görev/vaka kartı (js/ui.js; BOŞLUK-3 + F10 + F15 + F8) ══
// Desen: UB2 ctx'i genişletir (yeni ui.js yardımcıları + K8 modal/baglanti UA1
// fonksiyonları tek vm ctx'te; tarayıcı globali yok).
const UB3_UI_EK = [
  '_ovsyncK8GunAd', '_ovsyncBagimsizAltSatirHtml', '_ovsyncK8HayvanSayisi',
  '_ovsyncK8GecikmisNotHtml', '_ovsyncK8ModalHtml', '_ovsyncTrenKartErteleHtml',
  '_ovsyncTrenAksiyonTikla', '_ovsyncDuzenleYakala', '_ovsyncOdakTuket',
];

function ub3UiCtx() {
  // UA1 tam modül yüklenir (ovsyncTrenGorevMu regex'i extract edilemez —
  // loadModule.js yalnızca tam yüklemede fallback önerir); ui.js cerrahi
  // fonksiyonlar aynı sandbox'ta üzerine koşulur.
  const gidilen = [];
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => UB2_BUGUN,
      goTo: (p) => gidilen.push(p),
    },
  });
  const uiSrc = [...UB2_UI_FN, ...UB3_UI_EK]
    .map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, loaded.sandbox, { filename: 'ub3-ui-ctx' });
  return { ctx: loaded.sandbox, gidilen };
}

function ub3Render(veri, trenVeri) {
  const { ctx } = ub3UiCtx();
  const tv = trenVeri === undefined ? 'undefined' : JSON.stringify(trenVeri);
  return vm.runInContext(
    `renderOvsyncSayfa(${JSON.stringify(veri)}, '${UB2_BUGUN}', ${tv})`, ctx,
  );
}

function ub3TrenVerisi() {
  const tv = ub2TrenVerisi();
  tv.bagimsizlar = [{
    hayvan_id: 'h9', kupe_no: '1203', case_id: 'c9', asama: 0, ovsync_tren: null,
    sonraki_is: { tarih: '2026-11-24', saat: '18:00', tur: 'GNRH1' },
    pg_pay: null, pg1_zaman: null, ritim_disi_neden: 'PG +1 gün',
  }];
  return tv;
}

test('UB3 BOŞLUK-3: bağımsız alt satır küpe + sonraki iş/tarih; neden/hastalık YOK', () => {
  const { ctx } = ub3UiCtx();
  const uye = {
    hayvan_id: 'h9', kupe_no: '1203', case_id: 'c9', asama: 0, ovsync_tren: null,
    sonraki_is: { tarih: '2026-11-24', saat: '18:00', tur: 'GNRH1' },
    ritim_disi_neden: 'PG +1 gün', hastalik: 'İnaktif Ovaryum', neden: 'bağımsız başlatıldı',
  };
  const html = vm.runInContext(`_ovsyncBagimsizAltSatirHtml(${JSON.stringify(uye)})`, ctx);
  assert.ok(html.includes('ovs-bagimsiz-alt'), 'alt satır sınıfı yok');
  assert.ok(html.includes('1203'), 'küpe alt satırda olmalı');
  assert.ok(html.includes('GNRH1'), 'sonraki iş türü olmalı');
  assert.ok(html.includes('24.11'), 'sonraki iş tarihi olmalı');
  assert.ok(!html.includes('PG +1 gün'), 'ritim_disi_neden sızmamalı (BOŞLUK-3)');
  assert.ok(!html.includes('İnaktif Ovaryum'), 'hastalık adı sızmamalı (BOŞLUK-3)');
  assert.ok(!html.includes('bağımsız başlatıldı'), 'türetilmiş neden sızmamalı (BOŞLUK-3)');
  const bos = vm.runInContext(
    `_ovsyncBagimsizAltSatirHtml(${JSON.stringify({ hayvan_id: 'h9', kupe_no: '1203' })})`, ctx,
  );
  assert.strictEqual(bos, '', 'sonraki iş yoksa alt satır çizilmez');
});

test('UB3 BOŞLUK-3 tel: bağımsız blokta alt satır var, telde neden satırı yok', () => {
  const html = ub3Render(ub2TakipVerisi(), ub3TrenVerisi());
  // N4-F4 Y5: başlık mockup 02b "Bağımsız · N hayvan" (h2 + sayı span'i; e2e h2:text-is("Bağımsız") korunur)
  assert.ok(f4Gorunen(html).includes('Bağımsız · 1 hayvan'), 'bağımsız başlığı + sayısı olmalı');
  assert.ok(html.includes('<h2>Bağımsız</h2>'), 'e2e seçicisi için h2 yalnız "Bağımsız"');
  assert.ok(html.includes('ovs-bagimsiz-alt'), 'bağımsız kartta alt satır olmalı');
  assert.ok(html.includes('GNRH1'), 'alt satır sonraki işi göstermeli');
  assert.ok(!html.includes('PG +1 gün'), 'telde neden satırı olmamalı (BOŞLUK-3)');
});

test('UB3 F10: gecikmiş görevde modal taşınma cümlesi; sayı uye_kupeler.length', () => {
  const { ctx } = ub3UiCtx();
  const oniz = {
    ok: true, aktif: true, bugun: '2026-11-16', tren_gunu: '2026-11-19',
    uye_sayisi: 999, uye_kupeler: ['36', '38', '169', '5708'],
    gorev: { id: 'g-212', hedef_tarih: '2026-11-10' }, gorev_hedef_eski: true, kupe_no: '212',
  };
  const html = vm.runInContext(`_ovsyncK8ModalHtml(${JSON.stringify(oniz)})`, ctx);
  assert.ok(
    html.includes('Görev Sal 10 Kas yerine Per 19 Kas trenine taşınır.'),
    `F10 cümlesi yok: ${html.slice(0, 200)}`,
  );
  assert.ok(html.includes('(4 hayvan)'), 'sayı uye_kupeler.length olmalı');
  assert.ok(!html.includes('(999 hayvan)'), 'bayat uye_sayisi kullanılmamalı (F10)');
  assert.ok(html.includes('🚆 Trene bin — Per 19 Kas (4 hayvan)'), 'taban modal korunmalı');
  const normal = vm.runInContext(
    `_ovsyncK8ModalHtml(${JSON.stringify({ ...oniz, gorev_hedef_eski: false })})`, ctx,
  );
  assert.ok(!normal.includes('trenine taşınır'), 'gecikme yokken taşınma cümlesi çıkmamalı');
  const sayisal = vm.runInContext(`_ovsyncK8HayvanSayisi(${JSON.stringify({ uye_sayisi: 4 })})`, ctx);
  assert.strictEqual(sayisal, 4, 'uye_kupeler yoksa uye_sayisi korunur');
});

test('UB3 F8: düz-metin açıklama kartta false + sessiz; bozuk JSON görünür hatayla false', () => {
  const { ctx } = ub3UiCtx();
  vm.runInContext(`globalThis.__ub3HataSayisi = 0;
    globalThis.__ub3K = { hayvanIdSet: new Set(), gunIdSet: new Set(['gun-1']), aktif: true,
      hata: function () { globalThis.__ub3HataSayisi++; } };`, ctx);
  const duz = vm.runInContext(`_ovsyncTrenKartErteleHtml({ id: 'g1', gorev_tipi: 'TEDAVI_SEANS',
    hayvan_id: 'h1', aciklama: 'Gün 10 — Ovsync 4. uygulama' }, globalThis.__ub3K)`, ctx);
  assert.strictEqual(duz, null, 'düz metin Ovsync görevi değil → eski yol (null)');
  assert.strictEqual(
    vm.runInContext('globalThis.__ub3HataSayisi', ctx), 0, 'düz metin sessiz olmalı (F8)',
  );
  vm.runInContext(`globalThis.__ub3K.hayvanIdSet.add('h1');`, ctx);
  const link = vm.runInContext(`_ovsyncTrenKartErteleHtml({ id: 'g2', gorev_tipi: 'TOHUMLAMA_PLANLI',
    hayvan_id: 'h1' }, globalThis.__ub3K)`, ctx);
  assert.ok(
    String(link).includes('Ovsync ekranında düzenle'), `Ovsync TAI linklenmeli: ${link}`,
  );
  const bozuk = vm.runInContext(`_ovsyncTrenKartErteleHtml({ id: 'g3', gorev_tipi: 'TEDAVI_GUN',
    hayvan_id: 'h1', aciklama: '{"day_id":' }, globalThis.__ub3K)`, ctx);
  assert.strictEqual(bozuk, null, 'bozuk JSON fail-closed eski yol');
  assert.strictEqual(
    vm.runInContext('globalThis.__ub3HataSayisi', ctx), 1, 'bozuk veri görünür hata bildirmeli',
  );
});

test('UB3 F15: DUZENLE delegated bağlanır; diğer aksiyonlar yutulmaz', () => {
  const { ctx, gidilen } = ub3UiCtx();
  const duzenle = vm.runInContext(`_ovsyncTrenAksiyonTikla({ target: { closest: function () {
    return { dataset: { ovtAksiyon: 'DUZENLE', hayvan: 'h36' } }; } } })`, ctx);
  assert.strictEqual(duzenle, true, 'DUZENLE tüketilmeli');
  assert.deepStrictEqual(gidilen, ['ovsync'], 'DUZENLE Ovsync ekranına gitmeli');
  assert.strictEqual(vm.runInContext('window._ovsyncOdakHayvan', ctx), 'h36', 'odak hayvan bırakılmalı');
  const ertele = vm.runInContext(`_ovsyncTrenAksiyonTikla({ target: { closest: function (s) {
    return s === '[data-ovt-aksiyon]'
      ? { dataset: { ovtAksiyon: 'ERTELE', hayvan: 'h1' }, getAttribute: function () { return 'ERTELE'; } }
      : null; } } })`, ctx);
  assert.strictEqual(ertele, false, 'UB3 dışı aksiyon yutulmaz (UB4 akışları)');
  const bos = vm.runInContext(`_ovsyncTrenAksiyonTikla({ target: { closest: function () {
    return null; } } })`, ctx);
  assert.strictEqual(bos, false, 'aksiyon dışı tıklama yok sayılır');
});

test('UB3 bayrak kapalı: bağımsız alt satır/F10/kart kararı eski yolu bozmaz', () => {
  const { ctx } = ub3UiCtx();
  const veri = ub2TakipVerisi();
  const html = vm.runInContext(
    `renderOvsyncSayfa(${JSON.stringify(veri)}, '${UB2_BUGUN}', { aktif: false })`, ctx,
  );
  assert.ok(!html.includes('ovs-bagimsiz-alt'), 'kapalı yolda alt satır olmamalı');
  assert.ok(!html.includes('trenine taşınır'), 'kapalı yolda F10 cümlesi olmamalı');
  assert.ok(!html.includes('data-ovt-aksiyon="DUZENLE"'), 'kapalı yolda tren bağlantısı olmamalı');
  const kapaliKart = vm.runInContext(`_ovsyncTrenKartErteleHtml({ id: 'g2',
    gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1' }, { aktif: false })`, ctx);
  assert.strictEqual(kapaliKart, null, 'bayrak kapalı → eski yol (OVSYNC_BASLAT bile linklenmez)');
});

// ══ UB4 tren eylemleri (js/ui.js; V2 kancası + BASTAN akışı + F11 + K11 pini) ══
// Desen: UA1 tam modül + ui.js cerrahi extract tek vm ctx'te (ub3UiCtx kalıbı);
// rpc/toast/getData/apiOvsyncTren sahteleriyle V2 dalları + BASTAN akışı.
// F7 ONCEKI_TREN_VAR / F5 ileri-iptal / BOŞLUK-4 sonrası METİN pinleri UB2 +
// ovsync-tren.test.js F7 testinde (kapsanır, burada yinelenmez); bu bölüm
// metinleri EYLEM seviyesinde (toast/RPC) kilitler.
const UB4_UI_EK = [
  '_ovsyncK8GunAd', '_ovsyncTrenAksiyonTikla', '_ovsyncBaslatSecimi', '_ovsyncK8ModalAc',
  '_ovsyncBastanBaslatAkisi', '_ertelemeOnline', '_ertelemeOfflineGuard', 'ovsyncBaslat',
];

const UB4_ACIK_AYAR = [
  { anahtar: 'ovsync_tren_aktif', deger: 1 },
  { anahtar: 'ovsync_pg_kurallari_aktif', deger: 1 },
];

function ub4Onizle(ust = {}) {
  return Object.assign({
    ok: true, aktif: true, bugun: UB2_BUGUN, tren_gunu: '2026-11-26',
    uye_sayisi: 4, uye_kupeler: ['36', '38', '169', '5708'], kupe_no: '212',
  }, ust);
}

function ub4UiCtx(sahte = {}) {
  const rpcCalls = [];
  const toastlar = [];
  const gidilen = [];
  const onizle = sahte.onizle === undefined ? ub4Onizle() : sahte.onizle;
  const startSonuc = sahte.startSonuc === undefined
    ? { ok: true, case_id: 'c-yeni', tohumlama_gorev_id: 't-yeni', baslangic: '2026-11-26', ovsync_tren: '2026-11-26' }
    : sahte.startSonuc;
  const bastanSonuc = sahte.bastanSonuc === undefined
    ? { ok: true, hedef_tarih: '2026-12-03', basladi: true, iptal_tai: [] }
    : sahte.bastanSonuc;
  const ayarlar = sahte.ayarlar === undefined ? UB4_ACIK_AYAR : sahte.ayarlar;
  const acModalSecim = sahte.acModalSecim === undefined ? 'TREN' : sahte.acModalSecim;
  const acModalCalls = [];
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => UB2_BUGUN,
      goTo: (p) => gidilen.push(p),
      toast: (m, e) => toastlar.push({ mesaj: String(m), hata: !!e }),
      rpc: async (ad, prm) => {
        rpcCalls.push({ ad, prm });
        if (ad === 'ovsync_tren_onizle') return onizle;
        if (ad === 'start_first_service_protocol') return startSonuc;
        throw new Error('test stub: rpc "' + ad + '" tanımlı değil');
      },
      apiOvsyncTren: async (ad, prm) => {
        rpcCalls.push({ ad, prm });
        if (ad === 'ovsync_bastan_baslat') return bastanSonuc;
        throw new Error('test stub: apiOvsyncTren "' + ad + '" tanımlı değil');
      },
      getData: async (t) => (t === 'protokol_ayar' ? ayarlar : []),
      getState: () => [],
      pullTables: async () => {},
      closeM: () => {},
      updateTaskBadge: () => {},
      loadTasks: () => {},
      loadDash: () => {},
      fmtTarih: (s) => String(s || ''),
      getUserMessage: (e) => String((e && e.message) || e),
      _takipAcikHata: () => false,
      _ovsyncBildirim: () => {},
      _curTaskFilter: null,
      navigator: sahte.cevrimdisi ? { onLine: false } : { userAgent: 'node-test' },
    },
  });
  const uiSrc = [...UB2_UI_FN, ...UB3_UI_EK, ...UB4_UI_EK]
    .map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, loaded.sandbox, { filename: 'ub4-ui-ctx' });
  // UB4 eylem metinleri forms.js tek kaynağından (UB2 pinli sözler)
  const formsSrc = ['_ovsyncTrenTarihAd', '_ovsyncBastanSonucMetni']
    .map((n) => extractFunctionSource('js/forms.js', n)).join('\n');
  vm.runInContext(formsSrc, loaded.sandbox, { filename: 'ub4-forms-ctx' });
  vm.runInContext(
    'globalThis.__ub4AcModal = function (h, o) { globalThis.__ub4AcModalCalls.push(o); return Promise.resolve(globalThis.__ub4AcModalSecim); };',
    loaded.sandbox,
  );
  loaded.sandbox.__ub4AcModalCalls = acModalCalls;
  loaded.sandbox.__ub4AcModalSecim = acModalSecim;
  return { ctx: loaded.sandbox, rpcCalls, toastlar, gidilen, acModalCalls };
}

function ub4Baslat(ctx) {
  return vm.runInContext(
    'ovsyncBaslat("g1", "h1", globalThis.__ub4AcModal)', ctx,
  );
}

test('UB4 V2 BAGIMSIZ → start p_bagimsiz:true (m3 adlı)', async () => {
  const t = ub4UiCtx({ acModalSecim: 'BAGIMSIZ' });
  await ub4Baslat(t.ctx);
  const start = t.rpcCalls.filter((c) => c.ad === 'start_first_service_protocol');
  assert.strictEqual(start.length, 1, 'start bir kez çağrılmalı: ' + JSON.stringify(t.rpcCalls));
  assert.deepStrictEqual(
    JSON.parse(JSON.stringify(start[0].prm)), { p_gorev_id: 'g1', p_bagimsiz: true },
    'BAGIMSIZ kolu p_bagimsiz:true taşımalı (m3 hedefi)',
  );
  assert.ok(t.acModalCalls.length >= 1, 'BAGIMSIZ için soru sorulmalı');
});

test('UB4 V2 TREN → start eski parametrelerle aynen (p_bagimsiz anahtarı YOK)', async () => {
  const t = ub4UiCtx({ acModalSecim: 'TREN' });
  await ub4Baslat(t.ctx);
  const start = t.rpcCalls.filter((c) => c.ad === 'start_first_service_protocol');
  assert.strictEqual(start.length, 1, 'start bir kez çağrılmalı');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(start[0].prm)), { p_gorev_id: 'g1' }, 'TREN kolu eski çağrıyı değiştirmemeli');
});

test('UB4 V2 bayrak kapalı → soru/onizle RPCsi YOK, start eski parametrelerle', async () => {
  const t = ub4UiCtx({ ayarlar: [], acModalSecim: 'BAGIMSIZ' });
  await ub4Baslat(t.ctx);
  assert.ok(!t.rpcCalls.some((c) => c.ad === 'ovsync_tren_onizle'), 'kapalıyken onizle RPCsi atılmamalı');
  assert.strictEqual(t.acModalCalls.length, 0, 'kapalıyken soru sorulmamalı');
  const start = t.rpcCalls.filter((c) => c.ad === 'start_first_service_protocol');
  assert.strictEqual(start.length, 1, 'eski yol startı çağırmalı');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(start[0].prm)), { p_gorev_id: 'g1' }, 'kapalı yol parametreyi değiştirmemeli');
});

test('UB4 V2 çevrimdışı → İnternet toast, rpc YOK, kuyruk YOK', async () => {
  const t = ub4UiCtx({ cevrimdisi: true });
  await ub4Baslat(t.ctx);
  assert.strictEqual(t.rpcCalls.length, 0, 'çevrimdışıyken hiçbir RPC atılmamalı');
  assert.ok(t.toastlar.some((x) => x.mesaj.includes('İnternet')), 'çevrimdışı toast atılmalı');
});

test('UB4 V2 tren bugün → modal yok, start eski parametrelerle', async () => {
  const t = ub4UiCtx({ onizle: ub4Onizle({ tren_gunu: UB2_BUGUN }) });
  await ub4Baslat(t.ctx);
  assert.strictEqual(t.acModalCalls.length, 0, 'tren bugünken soru sorulmamalı (R4)');
  const start = t.rpcCalls.filter((c) => c.ad === 'start_first_service_protocol');
  assert.strictEqual(start.length, 1, 'sorusuz start çağrılmalı');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(start[0].prm)), { p_gorev_id: 'g1' }, 'sorusuz yol parametreyi değiştirmemeli');
});

test('UB4 F11 V2 basladi:false → yeniden_hedef toast (case_id YOK)', async () => {
  const t = ub4UiCtx({
    startSonuc: {
      ok: true, basladi: false, gorev_id: 'g1', yeniden_hedef: '2026-11-26', ovsync_tren: null,
    },
  });
  await ub4Baslat(t.ctx);
  const metin = t.toastlar.map((x) => x.mesaj).join(' ');
  assert.ok(metin.includes('Per 26 Kas'), 'yeniden_hedef toastta olmalı: ' + metin);
  assert.ok(metin.includes('başlamadı'), 'başlamama durumu toastta olmalı: ' + metin);
});

test('UB4 BOŞLUK-4 BASTAN akışı → hedef_tarih/basladi toast (eylem sonrası)', async () => {
  const t = ub4UiCtx();
  const ok = await vm.runInContext('_ovsyncBastanBaslatAkisi("c1")', t.ctx);
  assert.strictEqual(ok, true, 'akış toast atmalı');
  assert.deepStrictEqual(
    JSON.parse(JSON.stringify(t.rpcCalls)), [{ ad: 'ovsync_bastan_baslat', prm: { p_case_id: 'c1' } }],
    'tek RPC p_case_id ile atılmalı',
  );
  assert.ok(
    t.toastlar.some((x) => x.mesaj === 'Per 3 Ara treninde başlar.'),
    'sonrası hedef_tarih metni olmalı: ' + JSON.stringify(t.toastlar),
  );
  const t2 = ub4UiCtx({ bastanSonuc: { ok: true, basladi: false, yeniden_hedef: '2026-11-26' } });
  await vm.runInContext('_ovsyncBastanBaslatAkisi("c2")', t2.ctx);
  const m2 = t2.toastlar.map((x) => x.mesaj).join(' ');
  assert.ok(m2.includes('Per 26 Kas') && m2.includes('başlamadı'), 'basladi:false taşınma metni: ' + m2);
  const t3 = ub4UiCtx({ cevrimdisi: true });
  const kapali = await vm.runInContext('_ovsyncBastanBaslatAkisi("c3")', t3.ctx);
  assert.strictEqual(kapali, false, 'çevrimdışı akış çalışmamalı');
  assert.strictEqual(t3.rpcCalls.length, 0, 'çevrimdışı RPC atılmamalı');
});

test('UB4 BASTAN hata → ovsyncTrenHataMetni toast (sessiz yok)', async () => {
  const t = ub4UiCtx({
    bastanSonuc: null,
  });
  t.ctx.apiOvsyncTren = async (ad, prm) => {
    t.rpcCalls.push({ ad, prm });
    throw new Error('OVSYNC_TREN_KAPALI:{"rpc":"ovsync_bastan_baslat"}');
  };
  const ok = await vm.runInContext('_ovsyncBastanBaslatAkisi("c9")', t.ctx);
  assert.strictEqual(ok, false, 'hata akışı false dönmeli');
  assert.ok(
    t.toastlar.some((x) => x.mesaj.includes('Ovsync treni kapalı')),
    'hata metni toast olmalı: ' + JSON.stringify(t.toastlar),
  );
});

test('UB4 K11 sheet bastan_tren_gunu YOK (kural-yok-sayar tarih gösterilmez)', () => {
  const { ctx } = ub4UiCtx();
  const html = vm.runInContext(`ovsyncGecTamamlamaUyariHtml({ kod: 'PG1_TOLERANS_ASILDI',
    gecikme_gun: 2, kupe_no: '169', case_id: 'c1', planlanan_tarih: '2026-11-26',
    tamamlanan_tarih: '2026-11-28', bastan_tren_gunu: '2026-12-03' })`, ctx);
  assert.ok(!html.includes('2026-12-03'), 'ham bastan tarihi sheetta olmamalı');
  assert.ok(!html.includes('3 Ara'), 'bastan_tren_gunu günü sheetta olmamalı (BOŞLUK-4)');
  assert.ok(html.includes('Baştan başlat'), 'çıkış düğmesi korunmalı');
});

// ══ UB5 🔔 panel + F14 + damga (js/ui.js panel eki; index.html style/damga) ══
// Desen: UA1 tam modül + ui.js panel yardımcısı tek vm ctx'te (ub3UiCtx kalıbı);
// damga/F14 salt-kaynak (UB1 markup testi kalıbı).
const UB5_HTML_KAYNAGI = fs.readFileSync(path.join(REPO_ROOT, 'index.html'), 'utf8');
const UB5_YENI_DAMGA = '20261110-2';

function ub5UiCtx() {
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => UB2_BUGUN,
      goTo: () => {},
    },
  });
  const uiSrc = ['_ovsyncDogumPgSatirlari', '_rozetTopla']
    .map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, loaded.sandbox, { filename: 'ub5-ui-ctx' });
  return { ctx: loaded.sandbox };
}

const UB5_SATIRLAR = [
  { hayvan_id: 'h1', kupe_no: '1840', dogum_tarihi: '2026-11-24', gun: 2 },
  { hayvan_id: 'h2', kupe_no: '1702', dogum_tarihi: '2026-11-01', gun: 25 },
];

test('UB5 rozet: C4 2-kaynak kilidi aynen (3. argüman yok sayılır)', () => {
  const { ctx } = ub5UiCtx();
  assert.strictEqual(vm.runInContext('_rozetTopla(2, 3)', ctx), 5, '2-arg toplam korunmalı');
  assert.strictEqual(vm.runInContext('_rozetTopla(3, undefined)', ctx), 3, 'undefined 2. arg korunmalı');
  assert.strictEqual(vm.runInContext('_rozetTopla(3, 2, 4)', ctx), 5, 'C4-1: 3. argüman yok sayılır');
});

test('UB5 rozet+panel wiring: hatırlatma çağrı yerinde eklenir, C4 montajı korunur', () => {
  const src = fs.readFileSync(path.join(REPO_ROOT, 'js/ui.js'), 'utf8');
  assert.ok(
    src.includes('_rozetTopla(aktif.length, ovSayi) + pgSayi'),
    'R15: rozet 2-kaynak toplam + hatırlatma (C4-1 fonksiyon kilidi aynen)',
  );
  assert.ok(
    src.includes("'dogum_sonrasi_pg_hatirlatma'"),
    'ui.js hatırlatma RPCsini çağırmalı',
  );
  assert.ok(
    src.includes('ovHtml = ovHtml + pgHtml'),
    '💉 bölüm 🌱 bloğunun yanına ov-slotuna katlanmalı (mockup 7a sırası)',
  );
  assert.ok(
    src.includes('${ovHtml}${eksikHtml}${yakHtml}${tamHtml}'),
    'C4-3 montaj kilidi aynen korunmalı',
  );
});

test('UB5 panel: satır varken bölüm HTMLi, boşken satır yok', async () => {
  const { ctx } = ub5UiCtx();
  const satirlar = await vm.runInContext(
    `_ovsyncDogumPgSatirlari(async () => ({ ok: true, aktif: true, satirlar: ${JSON.stringify(UB5_SATIRLAR)} }))`,
    ctx,
  );
  // vm-dışı karşılaştırma (cross-realm prototip farkı deepStrictEqual bozar)
  assert.deepStrictEqual(JSON.parse(JSON.stringify(satirlar)), UB5_SATIRLAR, 'satırlar aynen taşınmalı');
  const html = vm.runInContext(`dogumPgHatirlatmaHtml(${JSON.stringify(satirlar)})`, ctx);
  assert.ok(html.includes('Doğum sonrası PG hatırlatma (2)'), 'bölüm başlığı + sayısı olmalı');
  assert.ok(html.includes('1840'), 'küpe satırda olmalı');
  const bos = await vm.runInContext(
    '_ovsyncDogumPgSatirlari(async () => ({ ok: true, aktif: true, satirlar: [] }))',
    ctx,
  );
  assert.deepStrictEqual(JSON.parse(JSON.stringify(bos)), [], 'boş yanıt boş dizi olmalı');
  assert.strictEqual(vm.runInContext('dogumPgHatirlatmaHtml([])', ctx), '', 'satır yoksa bölüm yok');
});

test('UB5 panel: rpc hatası → boş dizi (sessiz, eski panel korunur)', async () => {
  const { ctx } = ub5UiCtx();
  const satirlar = await vm.runInContext(
    '_ovsyncDogumPgSatirlari(async () => { throw new Error("ağ yok"); })',
    ctx,
  );
  assert.deepStrictEqual(JSON.parse(JSON.stringify(satirlar)), [], 'hata sessiz [] olmalı (throw sızmaz)');
  assert.strictEqual(vm.runInContext('dogumPgHatirlatmaHtml([])', ctx), '', 'hata paneli değiştirmemeli');
});

test('UB5 bayrak kapalı: aktif:false + boş satırlar → bölüm yok (panel birebir)', async () => {
  const { ctx } = ub5UiCtx();
  const satirlar = await vm.runInContext(
    '_ovsyncDogumPgSatirlari(async () => ({ ok: true, aktif: false, satirlar: [] }))',
    ctx,
  );
  assert.deepStrictEqual(JSON.parse(JSON.stringify(satirlar)), [], 'kapalı yanıtta satır olmamalı');
  assert.strictEqual(
    vm.runInContext(`dogumPgHatirlatmaHtml(${JSON.stringify(satirlar)})`, ctx), '',
    'kapalı panel eski html ile birebir olmalı (katkı yok)',
  );
});

test('UB5 damga: tüm ?v= + manifest tek adımda 20261110-2', () => {
  const damgalar = [...UB5_HTML_KAYNAGI.matchAll(/\?v=([0-9]{8}-[0-9]+)/g)].map((m) => m[1]);
  assert.ok(damgalar.length >= 36, 'dosyada ?v= sayısı en az 36 olmalı, bulunan: ' + damgalar.length);
  assert.deepStrictEqual([...new Set(damgalar)], [UB5_YENI_DAMGA], 'karışık damga: ' + [...new Set(damgalar)].join(' / '));
  assert.ok(
    UB5_HTML_KAYNAGI.includes('manifest.json?v=' + UB5_YENI_DAMGA),
    'manifest damgası aynı adımda olmalı',
  );
  const srcs = [...UB5_HTML_KAYNAGI.matchAll(/<script src="([^"]+)"/g)].map((m) => m[1]);
  assert.ok(
    srcs.includes('js/ovsync-tren.js?v=' + UB5_YENI_DAMGA),
    'tren modülü yeni damgayla yüklenmeli',
  );
});

test('UB5 F14: style tren yazı-renkleri var; zemin/sol şerit yok', () => {
  const isaret = 'OVSYNC TRENİ (F14)';
  const bas = UB5_HTML_KAYNAGI.indexOf(isaret);
  assert.ok(bas > 0, 'F14 style bloğu işaretli olmalı');
  const son = UB5_HTML_KAYNAGI.indexOf('/* ═══ İSTATİSTİK', bas);
  assert.ok(son > bas, 'F14 bloğu İSTATİSTİK bölümünden önce bitmeli');
  const blok = UB5_HTML_KAYNAGI.slice(bas, son);
  for (const sinif of ['.ovs-mavi', '.ovs-kayar', '.ovs-bastan', '.ovs-secim',
    '.ovs-tren-bugun', '.ovs-tren-ritimdisi', '.ovs-duzenle-link', '.ovs-tren-ertele']) {
    assert.ok(blok.includes(sinif), 'F14 yazı rengi eksik: ' + sinif);
  }
  assert.ok(!blok.includes('background'), 'F14 zemin rengi YOK (sahip kuralı)');
  assert.ok(!blok.includes('border-left'), 'F14 sol şerit YOK (sahip kuralı)');
});

test('UB4 BASTAN dispatcher → akış çalışır; ERTELE hâlâ yutulmaz', async () => {
  const t = ub4UiCtx();
  const tik = vm.runInContext(`_ovsyncTrenAksiyonTikla({ target: { closest: function () {
    return { dataset: { ovtAksiyon: 'BASTAN', case: 'c1' } }; } } })`, t.ctx);
  assert.strictEqual(tik, true, 'BASTAN tüketilmeli');
  await new Promise((r) => setImmediate(r));
  assert.ok(
    t.rpcCalls.some((c) => c.ad === 'ovsync_bastan_baslat' && c.prm.p_case_id === 'c1'),
    'BASTAN tıklaması RPC atmalı: ' + JSON.stringify(t.rpcCalls),
  );
  const ertele = vm.runInContext(`_ovsyncTrenAksiyonTikla({ target: { closest: function (s) {
    return s === '[data-ovt-aksiyon]'
      ? { dataset: { ovtAksiyon: 'ERTELE', hayvan: 'h1' }, getAttribute: function () { return 'ERTELE'; } }
      : null; } } })`, t.ctx);
  assert.strictEqual(ertele, false, 'ERTELE hâlâ yutulmamalı');
});

// ══ DÜZELT-2: _erteleBtnHtml Ovsync kancası (üretimde kart yardımcısı çağrısızdı) ══
const DUZ2_UI_EK = ['_erteleBtnHtml', '_ovsyncTrenKartErteleHtml', '_ovsyncKartKararBaglami'];
const DUZ2_ACIK_AYAR = [
  { anahtar: 'ovsync_tren_aktif', deger: 1 },
  { anahtar: 'ovsync_pg_kurallari_aktif', deger: 1 },
];

function duz2Ctx({ ayarlar = DUZ2_ACIK_AYAR, vakaHayvanlar = [] } = {}) {
  // UA1 tam modül yüklenir (ovsyncTrenGorevMu gövdesindeki `/^\s*\{/` regex'i
  // extract edilemez — ub3UiCtx kalıbı); ui.js cerrahi extract aynı sandbox'ta.
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => UB2_BUGUN,
      goTo: () => {},
      ertelemeKuralGetir: () => ({ ertelenebilir: true }),
      _ertelemeOnline: () => true,
      getState: (k) => (k === 'protokol_ayar' ? ayarlar : undefined),
      _ovsyncBaglamAl: () => ({
        vakaAktif: new Map(vakaHayvanlar.map((h) => [h, { animal_id: h }])),
        vakaKapali: new Map(), kisir: new Set(),
      }),
    },
  });
  const uiSrc = DUZ2_UI_EK.map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, loaded.sandbox, { filename: 'duz2-ctx' });
  return loaded.sandbox;
}

function duz2Ertele(ctx, gorev) {
  return vm.runInContext(`_erteleBtnHtml(${JSON.stringify(gorev)})`, ctx);
}

test('DUZELT-2 OVSYNC_BASLAT + bayrak açık → Ertele YOK, düzenle linki (m-duz2 adlı)', () => {
  const ctx = duz2Ctx();
  const html = duz2Ertele(ctx, { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1' });
  assert.ok(html.includes('Ovsync ekranında düzenle'), 'düzenle linki olmalı: ' + html);
  assert.ok(!html.includes('Ertele'), 'Ertele düğmesi olmamalı: ' + html);
});

test('DUZELT-2 bayrak kapalıyken OVSYNC_BASLAT bile eski Ertele (m-duz2 adlı)', () => {
  const ctx = duz2Ctx({ ayarlar: [] });
  const html = duz2Ertele(ctx, { id: 'g1', gorev_tipi: 'OVSYNC_BASLAT', hayvan_id: 'h1' });
  assert.ok(html.includes('Ertele'), 'kapalı yol eski düğmeyi korumalı: ' + html);
  assert.ok(!html.includes('Ovsync ekranında'), 'kapalı yolda tren bağlantısı olmamalı');
});

test('DUZELT-2 OVSYNC-dışı TAI → eski Ertele (bulaşma yok)', () => {
  const ctx = duz2Ctx({ vakaHayvanlar: [] });
  const html = duz2Ertele(ctx, { id: 'g2', gorev_tipi: 'TOHUMLAMA_PLANLI', hayvan_id: 'h9' });
  assert.ok(html.includes('Ertele'), 'Ovsync olmayan satır eski yolu korumalı');
});

test('DUZELT-2 aktif OVSYNC hayvanın TAI satırı → düzenle linki', () => {
  const ctx = duz2Ctx({ vakaHayvanlar: ['h1'] });
  const html = duz2Ertele(ctx, { id: 'g2', gorev_tipi: 'TOHUMLAMA_PLANLI', hayvan_id: 'h1' });
  assert.ok(html.includes('Ovsync ekranında düzenle'), 'aktif OVSYNC TAI linklenmeli: ' + html);
  assert.ok(!html.includes('data-ertele'), 'Ertele aksiyonu olmamalı');
});

// ══ N4-F3 H1: Ovsync ekranı hiç açılmadan Görevler kartı (demo e2e spec:409) ══
// Üretimde Ovsync ekranı açılmadıysa _ovsyncBaglamAl boş harita döner (vakaHayvanlar []);
// kart kümesi Görevler/Ana sayfa yüklemesinin IDB vakalarından kurulur (R5 b aynası).
const F3_VAKALAR = [
  { id: 'c1', animal_id: 'h1', status: 'active', protocol_family: 'OVSYNC' },
  { id: 'c2', animal_id: 'h2', status: 'closed', protocol_family: 'OVSYNC' },
  { id: 'c3', animal_id: 'h3', status: 'active', protocol_family: null },
];
function f3H1Ctx(opts) {
  const ctx = duz2Ctx(opts);
  vm.runInContext(extractFunctionSource('js/ui.js', '_ovsyncKartHayvanKur'), ctx, { filename: 'f3h1-ctx' });
  vm.runInContext(`_ovsyncKartHayvanKur(${JSON.stringify(F3_VAKALAR)})`, ctx);
  return ctx;
}

test('Görevler ekranı Ovsync bağlamı yokken Ovsync TAI → düzenle linki, Ertele yok', () => {
  const ctx = f3H1Ctx();
  const tai = duz2Ertele(ctx, { id: 'g5', gorev_tipi: 'TOHUMLAMA_PLANLI', hayvan_id: 'h1' });
  assert.ok(tai.includes('Ovsync ekranında düzenle'), 'Ovsync TAI düzenle linki almalı: ' + tai);
  assert.ok(!tai.includes('data-ertele'), 'Ovsync TAI kartında Ertele olmamalı: ' + tai);
  // R5 (b) dışı: kapalı OVSYNC vakası ya da OVSYNC-dışı aktif vaka → eski Ertele
  for (const h of ['h2', 'h3']) {
    const html = duz2Ertele(ctx, { id: 'g6', gorev_tipi: 'TOHUMLAMA_PLANLI', hayvan_id: h });
    assert.ok(html.includes('data-ertele'), h + ' eski Ertele yolunda kalmalı: ' + html);
  }
});

test('N4-F3 H1 bayrak kapalıyken Ovsync TAI → eski Ertele birebir', () => {
  const ctx = f3H1Ctx({ ayarlar: [] });
  const ovsync = duz2Ertele(ctx, { id: 'g5', gorev_tipi: 'TOHUMLAMA_PLANLI', hayvan_id: 'h1' });
  const duz = duz2Ertele(ctx, { id: 'g5', gorev_tipi: 'TOHUMLAMA_PLANLI', hayvan_id: 'h9' });
  assert.strictEqual(ovsync, duz, 'kapalı bayrakta Ovsync TAI düz TAI ile birebir aynı olmalı');
  assert.ok(ovsync.includes('data-ertele'));
});

test('N4-F3 H1 Görevler ve Ana sayfa yüklemesi kart kümesini IDB vakalarından kurar', () => {
  assert.match(extractFunctionSource('js/ui.js', 'loadTasks'), /_ovsyncKartHayvanKur\(_allTaskCases\)/);
  assert.match(extractFunctionSource('js/ui.js', 'loadDash'), /_ovsyncKartHayvanKur\(_dtCases\)/);
});

// ══ N4-F3 H2: geçen haftanın D7'si = bu haftanın D0'ı → iki başlık aynı X (demo DM1 BULGU-2) ══
test('iki başlık aynı X\'i işaret ederken tek ertele düğmesi', () => {
  const ctx = ub2UiCtx();
  const uyeF3 = (h, k, asama, tren) => ({
    hayvan_id: h, kupe_no: k, case_id: 'c' + k, asama, ovsync_tren: tren,
    sonraki_is: null, pg_pay: null, pg1_zaman: null, ritim_disi_neden: null,
  });
  const tv = {
    aktif: true, bugun: '2026-11-09', capa: '2026-11-12', ileri_sayisi: 0, bagimsizlar: [],
    trenler: [
      { tren_gunu: '2026-11-04', ritim_disi: false, uyeler: [uyeF3('h1', '36', 2, '2026-11-04')] },
      { tren_gunu: '2026-11-11', ritim_disi: false, uyeler: [uyeF3('h2', '38', 0, '2026-11-11')] },
    ],
  };
  const grp = { S0: [], S1: [
    { bolum: 'S1', hayvan_id: 'h1', kupe_no: '36', grup: 'Sağmal', gunler: [] },
    { bolum: 'S1', hayvan_id: 'h2', kupe_no: '38', grup: 'Sağmal', gunler: [] },
  ] };
  const html = vm.runInContext(
    `_ovsyncTrenGovdeHtml(${JSON.stringify(grp)}, '2026-11-09', ${JSON.stringify(tv)})`, ctx);
  const basliklar = html.split('<div class="ovs-tren-bas">').slice(1).map((b) => b.split('</div>')[0]);
  assert.strictEqual(basliklar.length, 2, 'iki tren başlığı çizilmeli');
  const dugmeli = basliklar.filter((b) => b.includes('ovs-tren-ertele'));
  assert.strictEqual(dugmeli.length, 1, 'ekranda tek "Tren gününü ertele…" olmalı: ' + JSON.stringify(dugmeli));
  assert.ok(dugmeli[0].includes('11 Kas') && dugmeli[0].includes('data-tarih="2026-11-11"'),
    'düğme X\'in kendi treninin (11 Kas) başlığında olmalı: ' + dugmeli[0]);
});

// ══ DÜZELT-3(i): çoklu kaydırma Ovsync atlanan notu (üretimde çağrısızdı) ══
test('DUZELT-3(i) atlanan Ovsync görevi → not bandı eki (m-duz3a adlı)', () => {
  const src = [
    extractFunctionSource('js/ovsync-tren.js', 'ovsyncCokluAtlananNot'),
    extractFunctionSource('js/ovsync-tren.js', '_ovtE'),
    extractFunctionSource('js/forms.js', '_ovsyncCokluBantEki'),
  ].join('\n');
  const ctx = {
    console, Math, JSON,
    esc: (v) => String(v == null ? '' : v),
    escAttr: (v) => String(v == null ? '' : v),
  };
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(src, ctx, { filename: 'duz3a-ctx' });
  const dolu = vm.runInContext(
    `_ovsyncCokluBantEki({ ok: true, ovsync_atlanan: [{ kupe_no: '36' }, { kupe_no: '37' }] })`, ctx,
  );
  assert.ok(dolu.includes('2 Ovsync görevi atlandı'), 'sayı notta olmalı: ' + dolu);
  assert.ok(dolu.includes('36'), 'küpeler notta olmalı');
  assert.ok(dolu.includes('Ovsync ekranı'), 'ekran bağlantısı olmalı');
  const bos = vm.runInContext('_ovsyncCokluBantEki({ ok: true })', ctx);
  assert.strictEqual(bos, '', 'atlanan yoksa ek boş olmalı');
});

// ══ DÜZELT-3(iii): seans ovsync_uyarı → sheet (üretimde okunmuyordu) ══
test('DUZELT-3(iii) seans uyarısı → sheet HTML; yoksa boş (m-duz3b adlı)', () => {
  const src = [
    extractFunctionSource('js/ovsync-tren.js', 'ovsyncGecTamamlamaUyariHtml'),
    extractFunctionSource('js/ovsync-tren.js', '_ovtE'),
    extractFunctionSource('js/forms.js', '_ovsyncSeansUyariHtmli'),
    extractFunctionSource('js/forms.js', '_ovsyncUyariSheetAc'),
  ].join('\n');
  const eklenen = [];
  const sahteEl = () => ({
    style: {},
    setAttribute() {},
    querySelectorAll: () => [],
    remove() {},
  });
  const ctx = {
    console, Math, JSON,
    esc: (v) => String(v == null ? '' : v),
    escAttr: (v) => String(v == null ? '' : v),
    document: {
      getElementById: () => null,
      createElement: () => sahteEl(),
      body: { appendChild: (el) => eklenen.push(el) },
    },
  };
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(src, ctx, { filename: 'duz3b-ctx' });
  const uyari = { kod: 'PG1_TOLERANS_ASILDI', gecikme_gun: 2, case_id: 'c1', kupe_no: '36' };
  const html = vm.runInContext(`_ovsyncSeansUyariHtmli({ ok: true, ovsync_uyari: ${JSON.stringify(uyari)} })`, ctx);
  assert.ok(html.includes('baştan başlat'), 'uyarı sheeti öneri taşımalı: ' + html.slice(0, 120));
  const yok = vm.runInContext('_ovsyncSeansUyariHtmli({ ok: true })', ctx);
  assert.strictEqual(yok, '', 'uyarı yoksa sheet açılmamalı');
  const acildi = vm.runInContext('_ovsyncUyariSheetAc("x")', ctx);
  assert.strictEqual(acildi, true, 'sheet açılmalı');
  assert.strictEqual(eklenen.length, 1, 'gövdeye bir kutu eklenmeli');
});

// ══ N4-F1 Parça 1: D1 forms.js kancaları V3/V4/V5/V6 (PLAN UB2 :501-503) ══
// Desen: vaka-sablon-pg-kapi.test.js (extractFunctionSource + vm sahte sahne).
// Soru çekirdeği (ovsyncTrenSor) burada SAHTEDİR — bu bölüm kanca kablolamasını
// (bayrak+seçim → soru → RPC parametresi) sınar; çekirdek UA1 testlidir.
// Bayrak KAPALIYKEN hiçbir yol/metin/parametre değişmez (her yol tabloda).
const { makeDomStub: n4f1MakeDom, makeElement: n4f1MakeEl } = require('./support/loadModule.js');

const N4F1_TREN = '2026-11-26';
const N4F1_KULLANICI_TARIH = '2026-11-20';
const N4F1_FORMS_FNS = ['_ovsyncAileHastalikIdleri', '_ovsyncAileHastalikIdSet',
  '_ovsyncKancaDurumu', '_ovsyncKancaSor', '_vakaBosAtaKanca'];

// IDB sahtesi: protokol_ayar bayrağı + OVSYNC şablon/hastalık eşlemi.
function n4f1Idb({ bayrak = true } = {}) {
  return async (tablo) => {
    if (tablo === 'protokol_ayar') return bayrak
      ? [{ anahtar: 'ovsync_tren_aktif', deger: 1 }, { anahtar: 'ovsync_pg_kurallari_aktif', deger: 1 }]
      : [{ anahtar: 'ovsync_tren_aktif', deger: 0 }, { anahtar: 'ovsync_pg_kurallari_aktif', deger: 1 }];
    if (tablo === 'tedavi_sablonu') return [
      { id: 'S-OV', protokol_ailesi: 'OVSYNC' },
      { id: 'S-N', protokol_ailesi: 'STANDART' },
    ];
    if (tablo === 'sablon_hastalik_eslem') return [{ sablon_id: 'S-OV', disease_id: 'D-OV' }];
    return [];
  };
}

// Ortak vm bağlamı: gerçek yardımcılar + gerçek ovsyncTrenAktif, soru sahte.
function n4f1Baglam(fns, ekstra = {}) {
  const rec = { rpc: [], toast: [], soru: [], soruAnindaRpc: -1, closeM: [] };
  const ctx = {
    document: {}, window: {}, console, Promise, JSON, setTimeout,
    navigator: { onLine: true, userAgent: 'node-test' },
    _drugsCache: [],
    toast: (m, h) => { rec.toast.push([m, !!h]); },
    getUserMessage: (e) => 'JENERIK:' + (e && e.message ? e.message : String(e)),
    idbGetAll: n4f1Idb({ bayrak: true }),
    ovsyncTrenSor: async (p) => { rec.soru.push(p); rec.soruAnindaRpc = rec.rpc.length; if (p.acModal) return p.acModal(); return { secim: 'TREN', tarih: N4F1_TREN }; },
    rpc: async (ad, p) => { rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) }); return { ok: true }; },
    ...ekstra,
  };
  ctx.globalThis = ctx;
  ctx.window = ctx;
  vm.createContext(ctx);
  const src = [...N4F1_FORMS_FNS, ...fns]
    .map((n) => extractFunctionSource('js/forms.js', n)).join('\n')
    + '\n' + extractFunctionSource('js/ovsync-tren.js', 'ovsyncTrenAktif');
  vm.runInContext(src, ctx, { filename: 'n4f1-ctx' });
  return { ctx, rec };
}

// ── V3 submitCase sahnesi ──
function n4f1V3Sahne({ soru, bayrak = true, onLine = true } = {}) {
  const document = n4f1MakeDom();
  const koy = (id, deger) => { const el = n4f1MakeEl('input'); el.value = deger; document.__setEl(id, el); };
  koy('d-hid', '12345'); koy('d-disease-id', 'D-OV'); koy('d-case-notes', '');
  document.__setEl('d-disease-cat', n4f1MakeEl('div'));
  document.__setEl('d-sablon-blok', n4f1MakeEl('div'));
  const { ctx, rec } = n4f1Baglam(['submitCase'], {
    document,
    navigator: { onLine, userAgent: 'node-test' },
    _seciliSablonId: 'S-OV',
    idbGetAll: n4f1Idb({ bayrak }),
    ovsyncTrenSor: async (p) => { rec.soru.push(p); rec.soruAnindaRpc = rec.rpc.length; if (p.acModal) return p.acModal(); return soru === undefined ? { secim: 'TREN', tarih: N4F1_TREN } : soru; },
    rpc: async (ad, p) => {
      rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) });
      if (ad === 'create_case') return { ok: true, case_id: 'C-1' };
      if (ad === 'tedavi_sablon_uygula') return { ok: true, gun_sayisi: 4 };
      if (ad === 'tedavi_sablon_tohumlama_gorev_ekle') return { ok: true, olustu: false };
      return { ok: true };
    },
    v: (id) => { const el = document.getElementById(id); return el ? String(el.value || '') : ''; },
    g: (id) => document.getElementById(id),
    cl: () => {},
    closeM: (id) => { rec.closeM.push(id); },
    hayvanByKupeRef: () => ({ id: 'H-1', kupe_no: '36', kisir: false }),
    _vakaSablonSonu: async () => {},
    _pgKapiHata: () => false,
    _vakaPlanUygulanmadi: () => {},
    _vakaSablonOnaySonu: async () => {},
    _takipAcikHata: () => false,
    _vakaTazele: async (adim) => { await adim(); },
    pullTables: async () => {},
    loadDrugsCache: async () => {},
    openDet: async () => {},
    _detAcik: () => false,
    _vakaSonrasiAkis: async () => {},
    openCaseDet: async () => {},
  });
  return { ctx, rec };
}

// ── V4 submitBulkCase sahnesi ──
function n4f1V4Sahne({ soru, bayrak = true } = {}) {
  const { ctx, rec } = n4f1Baglam(['submitBulkCase'], {
    _bcHayvanlar: [{ id: 'H-1', kupe: '36' }],
    _bcSeciliSablonId: 'S-OV',
    idbGetAll: n4f1Idb({ bayrak }),
    ovsyncTrenSor: async (p) => { rec.soru.push(p); rec.soruAnindaRpc = rec.rpc.length; if (p.acModal) return p.acModal(); return soru === undefined ? { secim: 'TREN', tarih: N4F1_TREN } : soru; },
    rpc: async (ad, p) => {
      rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) });
      return { ok: true, basari: 1, acilan: ['H-1'] };
    },
    v: (id) => (id === 'bc-disease-id' ? 'D-X' : ''),
    g: () => null,
    bcGunlardenItems: () => ({ hatalar: [], items: [] }),
    bcTarihDeger: () => N4F1_KULLANICI_TARIH,
    bcGecmisPlanTarihiMi: () => false,
    bugun: () => '2026-11-09',
    bcTohumBlokDurumu: () => ({ mod: 'kapali' }),
    saatYarimMi: () => false,
    bcTohumHedefTarih: (t) => t,
    bcTohumUygunOlmayanlar: () => [],
    bcMukerrerBul: () => [],
    bcTohumCakismaBul: () => [],
    bcCakismaRadyosu: () => null,
    bcCakismaPayloadDegeri: () => 'ekle',
    openConfirm: () => { throw new Error('uyarısız yolda openConfirm beklenmez'); },
    bcSonucSatirlari: () => [],
    bcSonucBantlari: () => '',
    pullTables: async () => {},
    loadDrugsCache: async () => {},
    renderSafe: () => {},
    _takipTopluSheet: () => { throw new Error('takip sheet beklenmez'); },
    bcButonMetni: () => 'x',
  });
  return { ctx, rec };
}

// ── V5/V6 sahnesi (sargı + kanca) ──
function n4f1V56Sahne({ soru, bayrak = true } = {}) {
  return n4f1Baglam(['_ovsyncV5Sargili', '_ovsyncV5KancaKur'], {
    _cdSablonTarih: N4F1_KULLANICI_TARIH,
    idbGetAll: n4f1Idb({ bayrak }),
    ovsyncTrenSor: async (p) => { throw new Error('soru bu sahnede parametreyle verilir'); },
  });
}

test('N4-F1 V3 TREN p_baslangic_tarihi', async () => {
  const { ctx, rec } = n4f1V3Sahne({});
  await ctx.submitCase(null, async () => ({ secim: 'TREN', tarih: N4F1_TREN }));
  assert.strictEqual(rec.soru.length, 1, 'Ovsync seçiminde soru bir kez sorulur');
  assert.strictEqual(rec.soruAnindaRpc, 0, 'soru create_case ÖNCESİ sorulur');
  assert.strictEqual(rec.soru[0].hayvanId, 'H-1', 'önizleme vaka hayvanıyla sorulur');
  const uyg = rec.rpc.find((r) => r.ad === 'tedavi_sablon_uygula');
  assert.ok(uyg, 'tedavi_sablon_uygula çağrıldı');
  assert.strictEqual(uyg.p.p_baslangic_tarihi, N4F1_TREN, 'TREN dalı tren tarihini taşır');
});

test('N4-F1 V3 BAGIMSIZ eski çağrı', async () => {
  const { ctx, rec } = n4f1V3Sahne({});
  await ctx.submitCase(null, async () => ({ secim: 'BAGIMSIZ', tarih: '2026-11-09' }));
  assert.strictEqual(rec.soru.length, 1, 'Ovsync seçiminde soru sorulur');
  const uyg = rec.rpc.find((r) => r.ad === 'tedavi_sablon_uygula');
  assert.ok(uyg, 'tedavi_sablon_uygula çağrıldı');
  assert.deepStrictEqual(uyg.p,
    { p_case_id: 'C-1', p_sablon_id: 'S-OV', p_pg_onay: false, p_pg_gerekce: null },
    'BAGIMSIZ mevcut çağrı birebir (tarih anahtarı yok)');
});

test('N4-F1 V3 offline Ovsync kuyruğa yazmaz', async () => {
  const { ctx, rec } = n4f1V3Sahne({ onLine: false });
  await ctx.submitCase(null, async () => ({ secim: 'TREN', tarih: N4F1_TREN }));
  assert.strictEqual(rec.rpc.length, 0, 'çevrimdışı hiçbir RPC yok (kuyruk da yazılmaz — tek yazma kanalı rpc)');
  assert.strictEqual(rec.soru.length, 0, 'çevrimdışı önizleme sorusu yok');
  assert.ok(rec.toast.some(([m]) => m === 'İnternet yok'), 'Ovsync çevrimdışı toast metni');
  assert.deepStrictEqual(rec.closeM, [], 'form açık kalır');
});

test('N4-F1 V4 TREN p_tarih', async () => {
  const { ctx, rec } = n4f1V4Sahne({});
  await ctx.submitBulkCase(null, async () => ({ secim: 'TREN', tarih: N4F1_TREN }));
  assert.strictEqual(rec.soru.length, 1, 'Ovsync şablonda soru bir kez');
  assert.strictEqual(rec.soruAnindaRpc, 0, 'soru gönderimden önce');
  const ac = rec.rpc.find((r) => r.ad === 'vaka_toplu_ac');
  assert.ok(ac, 'vaka_toplu_ac çağrıldı');
  assert.strictEqual(ac.p.p_tarih, N4F1_TREN, 'TREN dalı p_tarih tren günüdür');
});

test('N4-F1 V4 BAGIMSIZ kullanıcı tarihi', async () => {
  const { ctx, rec } = n4f1V4Sahne({});
  await ctx.submitBulkCase(null, async () => ({ secim: 'BAGIMSIZ', tarih: '2026-11-09' }));
  assert.strictEqual(rec.soru.length, 1, 'Ovsync şablonda soru sorulur');
  const ac = rec.rpc.find((r) => r.ad === 'vaka_toplu_ac');
  assert.ok(ac, 'vaka_toplu_ac çağrıldı');
  assert.strictEqual(ac.p.p_tarih, N4F1_KULLANICI_TARIH, 'BAGIMSIZ kullanıcının tarihi korunur');
});

test('N4-F1 V5 TREN p_baslangic_tarihi', async () => {
  const { ctx, rec } = n4f1V56Sahne({});
  ctx.ovsyncTrenSor = async (p) => { rec.soru.push(p); if (p.acModal) return p.acModal(); return { secim: 'TREN', tarih: N4F1_TREN }; };
  const gorulen = [];
  const orig = async (sid) => { gorulen.push({ sid, tarih: ctx._cdSablonTarih }); return 'tamam'; };
  const donen = await ctx._ovsyncV5Sargili('S-OV', orig, async () => ({ secim: 'TREN', tarih: N4F1_TREN }));
  assert.strictEqual(donen, 'tamam', 'özgün akış sonucu taşınır');
  assert.strictEqual(rec.soru.length, 1, 'OVSYNC şablonda soru bir kez');
  assert.deepStrictEqual(gorulen, [{ sid: 'S-OV', tarih: N4F1_TREN }], 'TREN tarihi özgün çağrıya taşınır');
  assert.strictEqual(ctx._cdSablonTarih, N4F1_KULLANICI_TARIH, 'genel çapa tarih geri yüklenir');
});

test('N4-F1 V5 sargı bir kez kurulur (çift soru yok)', () => {
  const { ctx } = n4f1V56Sahne({});
  ctx.caseSablonUygula = async () => 'orig';
  assert.strictEqual(ctx._ovsyncV5KancaKur(), true, 'ilk kurulum sarar');
  assert.strictEqual(ctx.caseSablonUygula._ovsyncV5, true, 'sargı işaretli');
  assert.strictEqual(ctx._ovsyncV5KancaKur(), false, 'ikinci kurulum yok');
});

test('N4-F1 V6 TREN p_baslangic_tarihi', async () => {
  const { ctx, rec } = n4f1Baglam([], {
    _cdSablonTarih: N4F1_KULLANICI_TARIH,
    idbGetAll: n4f1Idb({ bayrak: true }),
    ovsyncTrenSor: async (p) => { rec.soru.push(p); if (p.acModal) return p.acModal(); return { secim: 'TREN', tarih: N4F1_TREN }; },
    rpc: async (ad, p) => { rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) }); return { ok: true }; },
  });
  const yazilan = [];
  const kanca = ctx._vakaBosAtaKanca('C-1', 'S-OV', async (x) => { yazilan.push(x); return x; }, undefined, async () => ({ secim: 'TREN', tarih: N4F1_TREN }));
  await kanca('T-1', 'gerekçe');
  assert.strictEqual(rec.soru.length, 1, 'tarih kararsızsa soru sorulur');
  assert.deepStrictEqual(rec.rpc.map((r) => r.ad), ['tedavi_sablon_bos_ata_uygula'], 'tek RPC');
  assert.strictEqual(rec.rpc[0].p.p_baslangic_tarihi, N4F1_TREN, 'TREN dalı tren tarihini taşır');
  assert.strictEqual(yazilan.length, 1, 'yaz kapanışı koşar');
});

test('N4-F1 bayrak kapalı → soru yok, eski parametreler (V3/V4/V5/V6)', async () => {
  const yasakSoru = async () => { throw new Error('bayrak kapalıyken soru YOK'); };
  const yasakModal = async () => { throw new Error('bayrak kapalıyken modal YOK'); };
  { // V3
    const { ctx, rec } = n4f1V3Sahne({ bayrak: false });
    ctx.ovsyncTrenSor = yasakSoru;
    await ctx.submitCase(null, yasakModal);
    const uyg = rec.rpc.find((r) => r.ad === 'tedavi_sablon_uygula');
    assert.ok(uyg, 'V3 bayrak kapalı eski çağrı koşar');
    assert.ok(!('p_baslangic_tarihi' in uyg.p), 'V3 bayrak kapalı tarih anahtarı eklemez');
  }
  { // V3 çevrimdışı eski metin
    const { ctx, rec } = n4f1V3Sahne({ bayrak: false, onLine: false });
    ctx.ovsyncTrenSor = yasakSoru;
    await ctx.submitCase(null, yasakModal);
    assert.ok(rec.toast.some(([m]) => m === '⚠️ İnternet bağlantısı gerekli'), 'V3 bayrak kapalı eski çevrimdışı metni');
  }
  { // V4
    const { ctx, rec } = n4f1V4Sahne({ bayrak: false });
    ctx.ovsyncTrenSor = yasakSoru;
    await ctx.submitBulkCase(null, yasakModal);
    const ac = rec.rpc.find((r) => r.ad === 'vaka_toplu_ac');
    assert.ok(ac, 'V4 bayrak kapalı eski çağrı koşar');
    assert.strictEqual(ac.p.p_tarih, N4F1_KULLANICI_TARIH, 'V4 kullanıcı tarihi birebir');
  }
  { // V5
    const { ctx } = n4f1V56Sahne({ bayrak: false });
    ctx.ovsyncTrenSor = yasakSoru;
    let gorulen = null;
    await ctx._ovsyncV5Sargili('S-OV', async () => { gorulen = ctx._cdSablonTarih; }, yasakModal);
    assert.strictEqual(gorulen, N4F1_KULLANICI_TARIH, 'V5 bayrak kapalı özgün çapa tarihi');
  }
  { // V6
    const { ctx, rec } = n4f1Baglam([], {
      idbGetAll: n4f1Idb({ bayrak: false }),
      ovsyncTrenSor: yasakSoru,
      rpc: async (ad, p) => { rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) }); return { ok: true }; },
    });
    await ctx._vakaBosAtaKanca('C-1', 'S-OV', async (x) => x, undefined, yasakModal)('T-1', null);
    assert.strictEqual(rec.rpc[0].p.p_baslangic_tarihi, null, 'V6 bayrak kapalı null tarih (eski çağrı)');
  }
});

test('N4-F1 Vazgeç → rpc yok (V3/V4/V5/V6)', async () => {
  const vazgecModal = async () => null;
  { // V3
    const { ctx, rec } = n4f1V3Sahne({ soru: null });
    await ctx.submitCase(null, vazgecModal);
    assert.strictEqual(rec.rpc.length, 0, 'V3 vazgeç: hiçbir RPC çağrılmaz');
    assert.deepStrictEqual(rec.closeM, [], 'V3 vazgeç: form açık kalır');
  }
  { // V4
    const { ctx, rec } = n4f1V4Sahne({ soru: null });
    await ctx.submitBulkCase(null, vazgecModal);
    assert.strictEqual(rec.rpc.length, 0, 'V4 vazgeç: hiçbir RPC çağrılmaz');
  }
  { // V5
    const { ctx, rec } = n4f1V56Sahne({});
    ctx.ovsyncTrenSor = async (p) => { rec.soru.push(p); return null; };
    let cagrildi = false;
    const donen = await ctx._ovsyncV5Sargili('S-OV', async () => { cagrildi = true; }, vazgecModal);
    assert.strictEqual(donen, undefined, 'V5 vazgeç: özgün akış koşmaz');
    assert.strictEqual(cagrildi, false, 'V5 vazgeç: özgün çağrı yok');
  }
  { // V6
    const { ctx, rec } = n4f1Baglam([], {
      idbGetAll: n4f1Idb({ bayrak: true }),
      ovsyncTrenSor: async () => null,
      rpc: async (ad, p) => { rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) }); return { ok: true }; },
    });
    let yazildi = false;
    const donen = await ctx._vakaBosAtaKanca('C-1', 'S-OV', async (x) => { yazildi = true; return x; }, undefined, vazgecModal)('T-1', null);
    assert.strictEqual(donen, null, 'V6 vazgeç: sonuç yok');
    assert.strictEqual(rec.rpc.length, 0, 'V6 vazgeç: hiçbir RPC çağrılmaz');
    assert.strictEqual(yazildi, false, 'V6 vazgeç: yaz kapanışı koşmaz');
  }
});

// ══ N4-F1 Parça 2: G7/G9 (PLAN UB2 :504-505) ══
// Desen: ub4UiCtx (tam UA1 modülü + cerrahi ui.js extract + forms.js metin
// tek-kaynağı). Soru çekirdeği gerçektir (R4/bayrak/Vazgeç çekirdekte).
const N4F1_G7G9_UI = [
  '_ovsyncG7G9Sor', '_devamSeciciOnayla', '_devamRpcParams', '_devamRedIsle',
  '_devamButonEtiketi', '_takip21Onay', '_devamSeciciKapat', '_protokolIptalAkisi',
  '_ertelemeOnline',
];
const N4F1_G7G9_FORMS = ['_ovsyncTrenTarihAd', '_ovsyncBastanSonucMetni'];
const N4F1_G7G9_ONIZLE = {
  ok: true, aktif: true, bugun: '2026-11-19', tren_gunu: '2026-11-26',
  uye_sayisi: 4, uye_kupeler: ['36', '38', '169', '5708'], kupe_no: '212',
};

function n4f1G7G9Ctx(sahte = {}) {
  const rpcCalls = [];
  const toastlar = [];
  const tohumCalls = [];
  const acModalCalls = [];
  const confirmCalls = [];
  const onizle = sahte.onizle === undefined ? { ...N4F1_G7G9_ONIZLE } : sahte.onizle;
  const tohumSonuc = sahte.tohumSonuc === undefined
    ? { ok: true, secim: 'OVSYNC', tohumlama_id: 't1', islem_id: 'i1', ovsync_gorev_id: 'g-ov', takip_kapatildi: false }
    : sahte.tohumSonuc;
  const startSonuc = sahte.startSonuc === undefined
    ? { ok: true, case_id: 'c-yeni', tohumlama_gorev_id: 't-yeni', baslangic: '2026-11-26', ovsync_tren: '2026-11-26' }
    : sahte.startSonuc;
  const bastanSonuc = sahte.bastanSonuc === undefined
    ? { ok: true, hedef_tarih: '2026-12-03', basladi: true, iptal_tai: [] }
    : sahte.bastanSonuc;
  const ayarlar = sahte.ayarlar === undefined ? UB4_ACIK_AYAR : sahte.ayarlar;
  const acModalSecim = sahte.acModalSecim === undefined ? 'TREN' : sahte.acModalSecim;
  const confirmSeq = sahte.confirmSeq === undefined ? [true, true] : [...sahte.confirmSeq];
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => '2026-11-19',
      goTo: () => {},
      toast: (m, e) => toastlar.push({ mesaj: String(m), hata: !!e }),
      getData: async (t) => (t === 'protokol_ayar' ? ayarlar : []),
      getUserMessage: (e) => String((e && e.message) || e),
      pullTables: async () => {},
      updateTaskBadge: () => {},
      loadTasks: () => {},
      loadDash: () => {},
      fmtTarih: (s) => String(s || ''),
      _takipAcikHata: () => false,
      _curTaskFilter: null,
      navigator: { onLine: true, userAgent: 'node-test' },
    },
  });
  const sb = loaded.sandbox;
  sb.toast = (m, e) => toastlar.push({ mesaj: String(m), hata: !!e });
  sb.getData = async (t) => (t === 'protokol_ayar' ? ayarlar : []);
  sb.idbGetAll = async (t) => (t === 'treatment_days' || t === 'treatment_day_uygulamalar' ? [] : []);
  sb.tohumlamaBosVeDevam = async (p) => { tohumCalls.push(JSON.parse(JSON.stringify(p))); return tohumSonuc; };
  const kayitliRpc = async (ad, prm) => {
    rpcCalls.push({ ad, prm: JSON.parse(JSON.stringify(prm)) });
    if (ad === 'ovsync_tren_onizle') return onizle;
    if (ad === 'start_first_service_protocol') {
      if (sahte.startHata) throw sahte.startHata;
      return startSonuc;
    }
    if (ad === 'ovsync_bastan_baslat') {
      if (sahte.bastanHata) throw sahte.bastanHata;
      return bastanSonuc;
    }
    throw new Error('test stub: rpc "' + ad + '" tanımlı değil');
  };
  sb.rpc = kayitliRpc;
  sb.apiOvsyncTren = kayitliRpc;
  sb.confirm = (msg) => { confirmCalls.push(String(msg)); return confirmSeq.shift(); };
  sb.RPC_TABLES = {
    tohumlama_bos_ve_devam: ['tohumlama', 'gorev_log'],
    protokol_iptal: ['cases', 'gorev_log'],
    ovsync_bastan_baslat: ['cases', 'gorev_log'],
  };
  sb.bugun = () => '2026-11-19';
  sb.history = { state: {}, back() {} };
  sb.document = { getElementById: () => ({ disabled: false, textContent: '', remove() {} }) };
  sb.window = sb;
  sb.__n4f1AcModal = (h, o) => { acModalCalls.push(o); return Promise.resolve(acModalSecim); };
  const uiSrc = N4F1_G7G9_UI.map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, sb, { filename: 'n4f1-g7g9-ui' });
  const formsSrc = N4F1_G7G9_FORMS.map((n) => extractFunctionSource('js/forms.js', n)).join('\n');
  vm.runInContext(formsSrc, sb, { filename: 'n4f1-g7g9-forms' });
  return { ctx: sb, rpcCalls, toastlar, tohumCalls, acModalCalls, confirmCalls };
}

function n4f1G7Durum() {
  return {
    mod: 'bos', baglam: { tohumlama_id: 't1', kupe_no: '36' },
    onbilgi: { varsayilan_gun: 7, deneme_sayisi: 1 },
    secimler: ['OVSYNC', 'PG', 'TAKIP'], kilit: { kilitli: false, gerekce: null },
    secim: 'OVSYNC', erteleGun: 7, erteleSaat: '', pgStokId: null, pgDoz: '',
    onay21: false, acik: true, isleniyor: false,
  };
}

function n4f1G7Onayla(t, durum) {
  t.ctx.__n4f1Durum = durum;
  return vm.runInContext(
    'globalThis.__devamSecici = globalThis.__n4f1Durum; _devamSeciciOnayla(globalThis.__n4f1AcModal)', t.ctx);
}

const N4F1_G7_ESKI_PARAMS = {
  p_tohumlama_id: 't1', p_muayene_gorev_id: null, p_secim: 'OVSYNC',
  p_pg_urun: null, p_pg_doz: null, p_gun: null, p_saat: null,
  p_notlar: null, p_onay: false,
};

test('N4-F1 G7 TREN tohumlama_bos_ve_devam', async () => {
  const t = n4f1G7G9Ctx({ acModalSecim: 'TREN' });
  await n4f1G7Onayla(t, n4f1G7Durum());
  assert.strictEqual(t.acModalCalls.length, 1, 'Ovsync devamında soru bir kez sorulur');
  assert.strictEqual(t.tohumCalls.length, 1, 'mevcut tohumlama_bos_ve_devam koşar');
  assert.deepStrictEqual(t.tohumCalls[0], N4F1_G7_ESKI_PARAMS, 'TREN parametreleri birebir eski');
  assert.ok(!t.rpcCalls.some((c) => c.ad === 'start_first_service_protocol'), 'TREN start çağırmaz');
  assert.ok(t.toastlar.some((x) => x.mesaj === '✅ Sonuç ve devam adımı kaydedildi'), 'başarı toastı: ' + JSON.stringify(t.toastlar));
});

test('N4-F1 G7 R4 tren bugün → modal yok', async () => {
  const t = n4f1G7G9Ctx({ onizle: { ...N4F1_G7G9_ONIZLE, tren_gunu: '2026-11-19' }, acModalSecim: 'TREN' });
  await n4f1G7Onayla(t, n4f1G7Durum());
  assert.strictEqual(t.acModalCalls.length, 0, 'tren bugünken modal açılmamalı (R4)');
  assert.strictEqual(t.tohumCalls.length, 1, 'sorusuz eski çağrı koşar');
  assert.deepStrictEqual(t.tohumCalls[0], N4F1_G7_ESKI_PARAMS, 'sorusuz parametre birebir');
  assert.ok(!t.rpcCalls.some((c) => c.ad === 'start_first_service_protocol'), 'R4 start çağırmaz');
});

test('N4-F1 G7 BAGIMSIZ start p_bagimsiz', async () => {
  const t = n4f1G7G9Ctx({ acModalSecim: 'BAGIMSIZ' });
  await n4f1G7Onayla(t, n4f1G7Durum());
  assert.strictEqual(t.tohumCalls.length, 1, 'önce mevcut tohumlama_bos_ve_devam koşar');
  const start = t.rpcCalls.filter((c) => c.ad === 'start_first_service_protocol');
  assert.strictEqual(start.length, 1, 'BAGIMSIZ start bir kez çağrılmalı');
  assert.deepStrictEqual(start[0].prm, { p_gorev_id: 'g-ov', p_bagimsiz: true }, 'dönüşteki ovsync_gorev_id + p_bagimsiz:true');
});

test('N4-F1 G7 BAGIMSIZ hata → toast throw yok', async () => {
  const t = n4f1G7G9Ctx({
    acModalSecim: 'BAGIMSIZ',
    startHata: new Error('OVSYNC_GOREV_ACILAMADI:{"hayvan_id":"h1","sebep":"KURAMADI"}'),
  });
  await n4f1G7Onayla(t, n4f1G7Durum());
  assert.strictEqual(t.tohumCalls.length, 1, 'vaka/tohum kaydı durur (görev açık kalır)');
  assert.strictEqual(t.rpcCalls.filter((c) => c.ad === 'start_first_service_protocol').length, 1, 'start denendi');
  assert.ok(t.toastlar.some((x) => x.mesaj.startsWith('Görev açıldı, başlatılamadı: ')),
    'hata toastı önekli olmalı: ' + JSON.stringify(t.toastlar));
  assert.ok(t.toastlar.some((x) => x.mesaj.includes('Ovsync başlatma görevi açılamadı')),
    'OVSYNC_GOREV_ACILAMADI metinli olmalı: ' + JSON.stringify(t.toastlar));
});

test('N4-F1 G9 TREN', async () => {
  const t = n4f1G7G9Ctx({ acModalSecim: 'TREN' });
  t.ctx.__n4f1Vaka = { id: 'c1', protocol_family: 'OVSYNC', animal_id: 'h1' };
  const donen = await vm.runInContext(
    '_protokolIptalAkisi(globalThis.__n4f1Vaka, globalThis.__n4f1AcModal)', t.ctx);
  assert.strictEqual(donen, true, 'akış başarı dönmeli');
  assert.deepStrictEqual(
    t.rpcCalls.map((c) => c.ad), ['ovsync_tren_onizle', 'ovsync_bastan_baslat'],
    'soru önizlemesi + tek bastan_baslat: ' + JSON.stringify(t.rpcCalls));
  const bastan = t.rpcCalls.find((c) => c.ad === 'ovsync_bastan_baslat');
  assert.deepStrictEqual(bastan.prm, { p_case_id: 'c1' }, 'TREN p_bagimsiz anahtarı taşımaz');
  assert.ok(!t.rpcCalls.some((c) => c.ad === 'protokol_iptal'), 'G9 yolunda protokol_iptal koşmaz');
  assert.ok(t.toastlar.some((x) => x.mesaj === 'Per 3 Ara treninde başlar.'),
    'eylem sonrası hedef_tarih metni: ' + JSON.stringify(t.toastlar));
});

test('N4-F1 G9 BAGIMSIZ true', async () => {
  const t = n4f1G7G9Ctx({ acModalSecim: 'BAGIMSIZ' });
  t.ctx.__n4f1Vaka = { id: 'c1', protocol_family: 'OVSYNC', animal_id: 'h1' };
  await vm.runInContext('_protokolIptalAkisi(globalThis.__n4f1Vaka, globalThis.__n4f1AcModal)', t.ctx);
  const bastan = t.rpcCalls.filter((c) => c.ad === 'ovsync_bastan_baslat');
  assert.strictEqual(bastan.length, 1, 'bastan_baslat bir kez çağrılmalı');
  assert.deepStrictEqual(bastan[0].prm, { p_case_id: 'c1', p_bagimsiz: true }, 'BAGIMSIZ true taşınmalı');
});

test('N4-F1 bayrak kapalı → soru yok (G7/G9)', async () => {
  const yasakModal = async () => { throw new Error('bayrak kapalıyken modal YOK'); };
  { // G7
    const t = n4f1G7G9Ctx({ ayarlar: [] });
    t.ctx.__n4f1AcModal = yasakModal;
    await n4f1G7Onayla(t, n4f1G7Durum());
    assert.strictEqual(t.acModalCalls.length, 0, 'G7 kapalıyken soru yok');
    assert.ok(!t.rpcCalls.some((c) => c.ad === 'ovsync_tren_onizle'), 'G7 kapalıyken önizleme RPCsi yok');
    assert.strictEqual(t.tohumCalls.length, 1, 'G7 eski çağrı koşar');
    assert.deepStrictEqual(t.tohumCalls[0], N4F1_G7_ESKI_PARAMS, 'G7 parametreler birebir');
    assert.ok(!t.rpcCalls.some((c) => c.ad === 'start_first_service_protocol'), 'G7 kapalıyken start yok');
  }
  { // G9 OVSYNC vaka
    const t = n4f1G7G9Ctx({ ayarlar: [] });
    t.ctx.__n4f1AcModal = yasakModal;
    t.ctx.__n4f1Vaka = { id: 'c1', protocol_family: 'OVSYNC', animal_id: 'h1' };
    await vm.runInContext('_protokolIptalAkisi(globalThis.__n4f1Vaka, globalThis.__n4f1AcModal)', t.ctx);
    assert.ok(!t.rpcCalls.some((c) => c.ad === 'ovsync_tren_onizle'), 'G9 kapalıyken önizleme yok');
    const iptal = t.rpcCalls.filter((c) => c.ad === 'protokol_iptal');
    assert.strictEqual(iptal.length, 1, 'G9 kapalıyken eski iptal koşar');
    assert.deepStrictEqual(iptal[0].prm, { p_vaka_id: 'c1', p_yeniden_baslat: true, p_not: null }, 'eski parametreler birebir');
    assert.ok(!t.rpcCalls.some((c) => c.ad === 'ovsync_bastan_baslat'), 'G9 kapalıyken bastan yok');
  }
  { // G9 OVSYNC-dışı vaka (bayrak açık): eski yol
    const t = n4f1G7G9Ctx({});
    t.ctx.__n4f1Vaka = { id: 'c2', protocol_family: 'STANDART', animal_id: 'h1' };
    await vm.runInContext('_protokolIptalAkisi(globalThis.__n4f1Vaka, globalThis.__n4f1AcModal)', t.ctx);
    assert.strictEqual(t.acModalCalls.length, 0, 'OVSYNC-dışı vakada soru yok');
    assert.strictEqual(t.rpcCalls.filter((c) => c.ad === 'protokol_iptal').length, 1, 'eski iptal koşar');
    assert.ok(!t.rpcCalls.some((c) => c.ad === 'ovsync_bastan_baslat'), 'OVSYNC-dışı bastan yok');
  }
});

test('N4-F1 Vazgeç → rpc yok (G7/G9)', async () => {
  { // G7
    const t = n4f1G7G9Ctx({ acModalSecim: null });
    await n4f1G7Onayla(t, n4f1G7Durum());
    assert.strictEqual(t.tohumCalls.length, 0, 'G7 vazgeç: tohumlama RPCsi yok');
    assert.strictEqual(t.rpcCalls.length, 1, 'G7 vazgeç: yalnız önizleme RPCsi (yazma yok)');
    assert.deepStrictEqual(t.rpcCalls.map((c) => c.ad), ['ovsync_tren_onizle'], 'yazma RPCsi yok');
  }
  { // G9
    const t = n4f1G7G9Ctx({ acModalSecim: null });
    t.ctx.__n4f1Vaka = { id: 'c1', protocol_family: 'OVSYNC', animal_id: 'h1' };
    const donen = await vm.runInContext(
      '_protokolIptalAkisi(globalThis.__n4f1Vaka, globalThis.__n4f1AcModal)', t.ctx);
    assert.strictEqual(donen, undefined, 'G9 vazgeç: akış durur');
    assert.deepStrictEqual(t.rpcCalls.map((c) => c.ad), ['ovsync_tren_onizle'], 'G9 vazgeç: yazma RPCsi yok');
  }
});

// ══ N4-F1 Parça 3: D3(ii) cdKaydirAc OVSYNC vaka aşama dalları ══
// Desen: UA1 tam modül + ui.js cerrahi extract + forms.js metin tek-kaynağı
// (N4-F1 G7/G9 ctx kalıbı). Dal + sheet + eylemler aynı ctx'te sürülür.
const N4F1_D3II_UI = [
  '_ovsyncKaydirSheetHtml', '_ovsyncPg48SatirHtml',
  '_ovsyncKaydirDaliAc', '_ovsyncKaydirCagir', '_ovsyncKaydirBasari',
  '_ovsyncKaydirErtele', 'cdKaydirOvsyncPg48', 'cdKaydirOvsyncBastan',
  'cdKaydirOvsyncDuzenle', 'cdKaydirAc', 'cdKaydirSheetHtml',
  '_ertelemeOnline', '_ertelemeOfflineGuard', '_ovsyncBastanBaslatAkisi',
];
const N4F1_D3II_FORMS = ['_ovsyncTrenTarihAd', '_ovsyncBastanSonucMetni', '_ovsyncErteleSonucMetni'];
const N4F1_D3II_VAKA = { id: 'c1', animal_id: 'h1', status: 'active', protocol_family: 'OVSYNC' };
// F13 pull seti (api.js RPC_TABLES yazma girdileriyle birebir olmalı).
const N4F1_D3II_PULL = ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'drug_administrations',
  'gorev_log', 'islem_log', 'stok', 'stok_hareket', 'diseases', 'drugs', 'tedavi_sablonu',
  'protokol_ayar', 'protokol_instance'];

function n4f1D3iiUye(ust = {}) {
  return Object.assign({
    hayvan_id: 'h1', kupe_no: '36', case_id: 'c1', gorev_id: null, asama: 0,
    ovsync_tren: '2026-11-26', sonraki_is: null, pg_pay: null, pg1_zaman: null,
    ritim_disi_neden: null,
  }, ust);
}

function n4f1D3iiListe(uyeler, ust = {}) {
  return Object.assign({
    ok: true, aktif: true, capa: '2026-11-12', bugun: '2026-11-19',
    trenler: [{ tren_gunu: '2026-11-26', ritim_disi: false, uyeler }],
    bagimsizlar: [], ileri_sayisi: 0,
  }, ust);
}

function n4f1D3iiBelge(depo) {
  const belge = { _kutu: null };
  belge.getElementById = (id) => {
    if (id === 'kaydir-modal') return belge._kutu;
    if (id === 'kaydir-ovsync-n' && depo.select) {
      return {
        value: depo.select.deger,
        getAttribute: (a) => (a === 'data-maks' ? String(depo.select.maks) : null),
      };
    }
    return null;
  };
  belge.createElement = () => {
    const el = { _html: '', onclick: null, style: {} };
    Object.defineProperty(el, 'innerHTML', {
      get() { return el._html; },
      set(v) { el._html = String(v); },
      configurable: true,
    });
    el.remove = () => { if (belge._kutu === el) belge._kutu = null; };
    return el;
  };
  belge.body = { appendChild: (el) => { belge._kutu = el; depo.acilan.push(el._html); } };
  return belge;
}

function n4f1D3iiCtx(sahte = {}) {
  const rpcCalls = [];
  const toastlar = [];
  const pullar = [];
  const timeline = [];
  const gidilen = [];
  const depo = { acilan: [], select: sahte.select || null };
  const ayarlar = sahte.ayarlar === undefined ? UB4_ACIK_AYAR : sahte.ayarlar;
  const listele = sahte.listele === undefined ? n4f1D3iiListe([n4f1D3iiUye()]) : sahte.listele;
  const erteleSonuc = sahte.erteleSonuc === undefined
    ? { ok: true, asama: 0, sonuc: 'SONRAKI_TREN', yeni_tarih: '2026-12-03' } : sahte.erteleSonuc;
  const pg48Sonuc = sahte.pg48Sonuc === undefined
    ? { ok: true, tai_gorev_id: 't-tai', tai_hedef: '2026-11-28', kapanan_seans: 2 } : sahte.pg48Sonuc;
  const bastanSonuc = sahte.bastanSonuc === undefined
    ? { ok: true, hedef_tarih: '2026-12-03', basladi: true, iptal_tai: [] } : sahte.bastanSonuc;
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => '2026-11-19',
      console,
      goTo: (p) => gidilen.push(p),
      getData: async (t) => (t === 'protokol_ayar' ? ayarlar : []),
      pullTables: async (t) => { pullar.push(t); },
      renderCaseTimeline: async (id) => { timeline.push(id); },
      _updateKapatBtn: () => {},
      updateTaskBadge: () => {},
      loadTasks: () => {},
      loadDash: () => {},
      _curTaskFilter: null,
      navigator: sahte.cevrimdisi ? { onLine: false } : { userAgent: 'node-test' },
    },
  });
  const sb = loaded.sandbox;
  sb.esc = (v) => String(v == null ? '' : v);
  sb.escAttr = (v) => String(v == null ? '' : v);
  sb.bugun = () => '2026-11-19';
  sb.console = console;
  sb.toast = (m, e) => toastlar.push({ mesaj: String(m), hata: !!e });
  sb.getData = async (t) => (t === 'protokol_ayar' ? ayarlar : []);
  sb.pullTables = async (t) => { pullar.push(t); };
  sb.renderCaseTimeline = async (id) => { timeline.push(id); };
  sb._updateKapatBtn = () => {};
  sb.updateTaskBadge = () => {};
  sb.loadTasks = () => {};
  sb.loadDash = () => {};
  const kayitliRpc = async (ad, prm) => {
    rpcCalls.push({ ad, prm: JSON.parse(JSON.stringify(prm)) });
    if (ad === 'ovsync_tren_listele') {
      if (sahte.listeleHata) throw sahte.listeleHata;
      return listele;
    }
    if (ad === 'ovsync_hayvan_ertele') {
      if (sahte.erteleHata) throw sahte.erteleHata;
      return erteleSonuc;
    }
    if (ad === 'ovsync_pg48_tohumla') {
      if (sahte.pg48Hata) throw sahte.pg48Hata;
      return pg48Sonuc;
    }
    if (ad === 'ovsync_bastan_baslat') {
      if (sahte.bastanHata) throw sahte.bastanHata;
      return bastanSonuc;
    }
    throw new Error('test stub: rpc "' + ad + '" tanımlı değil');
  };
  sb.rpc = kayitliRpc;
  sb.apiOvsyncTren = kayitliRpc;
  sb.document = n4f1D3iiBelge(depo);
  sb.window = sb;
  sb._curCase = sahte.vaka === undefined ? { ...N4F1_D3II_VAKA } : sahte.vaka;
  const uiSrc = N4F1_D3II_UI.map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, sb, { filename: 'n4f1-d3ii-ui' });
  const formsSrc = N4F1_D3II_FORMS.map((n) => extractFunctionSource('js/forms.js', n)).join('\n');
  vm.runInContext(formsSrc, sb, { filename: 'n4f1-d3ii-forms' });
  return { ctx: sb, rpcCalls, toastlar, pullar, timeline, gidilen, depo };
}

test('N4-F1 D3ii asama 0 → Sonraki trene aktar (p_gun=1, yeni_tarih toast)', async () => {
  const t = n4f1D3iiCtx();
  await vm.runInContext('cdKaydirAc()', t.ctx);
  assert.strictEqual(t.depo.acilan.length, 1, 'OVSYNC sheet açılmalı');
  const html = t.depo.acilan[0];
  assert.ok(html.includes('Sonraki trene aktar'), 'aşama 0 düğmesi');
  assert.ok(!html.includes('caseKalanGunleriKaydir'), 'eski kaydır düğmesi YOK');
  assert.ok(!html.includes('data-gun'), '+N hızlı düğme YOK');
  assert.ok(!html.includes('kaydir-ozel'), 'özel gün girdisi YOK');
  assert.ok(t.rpcCalls.some((c) => c.ad === 'ovsync_tren_listele'), 'dal listele okur');
  await vm.runInContext('_ovsyncKaydirErtele(1)', t.ctx);
  const ertele = t.rpcCalls.filter((c) => c.ad === 'ovsync_hayvan_ertele');
  assert.strictEqual(ertele.length, 1, 'tek ertele RPCsi');
  assert.deepStrictEqual(ertele[0].prm, { p_hayvan_id: 'h1', p_gun: 1 }, 'F3: p_gun=1, hedefi sunucu hesaplar');
  assert.ok(t.toastlar.some((x) => !x.hata && x.mesaj.includes('3 Ara')), 'F3 sonrası yeni_tarih metni: ' + JSON.stringify(t.toastlar));
  assert.strictEqual(t.ctx.document._kutu, null, 'başarıda sheet kapanır');
  assert.deepStrictEqual([...t.pullar[0]].sort(), [...N4F1_D3II_PULL].sort(), 'F13 tazeleme seti');
  assert.deepStrictEqual(t.timeline, ['c1'], 'vaka çizelgesi tazelenir');
  { // sunucu reddi → hata toast, sheet açık kalır, pull yok
    const e = n4f1D3iiCtx({ erteleHata: new Error('OVSYNC_TREN_KAPALI:{"rpc":"ovsync_hayvan_ertele"}') });
    await vm.runInContext('cdKaydirAc()', e.ctx);
    await vm.runInContext('_ovsyncKaydirErtele(1)', e.ctx);
    assert.ok(e.toastlar.some((x) => x.hata && x.mesaj.includes('Ovsync treni kapalı')), 'red toastu: ' + JSON.stringify(e.toastlar));
    assert.notStrictEqual(e.ctx.document._kutu, null, 'hata sheeti kapatmaz');
    assert.strictEqual(e.pullar.length, 0, 'hatada pull yok');
  }
});

test('N4-F1 D3ii asama 1 → +N seçici 1..pg_pay (üst sınır dışı RPC yok)', async () => {
  const t = n4f1D3iiCtx({ listele: n4f1D3iiListe([n4f1D3iiUye({ asama: 1, pg_pay: 2 })]) });
  await vm.runInContext('cdKaydirAc()', t.ctx);
  assert.strictEqual(t.depo.acilan.length, 1, 'OVSYNC sheet açılmalı');
  const html = t.depo.acilan[0];
  assert.ok(html.includes('id="kaydir-ovsync-n"'), '+N seçici var');
  assert.ok(html.includes('data-maks="2"'), 'maks pg_pay');
  assert.ok(html.includes('<option value="1">+1</option>') && html.includes('<option value="2">+2</option>'), '1..2 seçenek');
  assert.ok(!html.includes('<option value="3">'), '+3 seçeneği YOK');
  assert.ok(!html.includes('caseKalanGunleriKaydir'), 'eski kaydır YOK');
  t.depo.select = { deger: '2', maks: 2 };
  await vm.runInContext('_ovsyncKaydirErtele()', t.ctx);
  const ertele = t.rpcCalls.filter((c) => c.ad === 'ovsync_hayvan_ertele');
  assert.strictEqual(ertele.length, 1, 'tek ertele RPCsi');
  assert.deepStrictEqual(ertele[0].prm, { p_hayvan_id: 'h1', p_gun: 2 }, 'seçili N taşınır');
  { // üst sınır dışı değer RPCye ulaşmaz
    const k = n4f1D3iiCtx({
      listele: n4f1D3iiListe([n4f1D3iiUye({ asama: 1, pg_pay: 2 })]),
      select: { deger: '5', maks: 2 },
    });
    await vm.runInContext('cdKaydirAc()', k.ctx);
    await vm.runInContext('_ovsyncKaydirErtele()', k.ctx);
    assert.ok(!k.rpcCalls.some((c) => c.ad === 'ovsync_hayvan_ertele'), 'üst sınır dışı değer RPCye ulaşmaz');
    assert.ok(k.toastlar.some((x) => x.hata), 'geçersiz seçim hata toastu');
  }
});

test('N4-F1 D3ii asama 2 → kaydır yok, (a) PG48 + (b) Bastan baslat', async () => {
  const t = n4f1D3iiCtx({ listele: n4f1D3iiListe([n4f1D3iiUye({ asama: 2, pg1_zaman: '2026-11-26T06:40:00.000Z' })]) });
  await vm.runInContext('cdKaydirAc()', t.ctx);
  assert.strictEqual(t.depo.acilan.length, 1, 'OVSYNC sheet açılmalı');
  const html = t.depo.acilan[0];
  assert.ok(!html.includes('caseKalanGunleriKaydir'), 'kaydır düğmesi YOK');
  assert.ok(!html.includes('data-gun'), '+N düğmesi YOK');
  assert.ok(!html.includes('kaydir-ozel'), 'özel girdi YOK');
  assert.ok(html.includes('≈'), 'BOŞLUK-1: pg1_zaman varsa ≈ <gün> <saat>');
  assert.ok(html.includes("PG1 + 48 s'te tohumla"), '(a) metni');
  assert.ok(html.includes('Baştan başlat'), '(b) metni');
  await vm.runInContext('cdKaydirOvsyncPg48()', t.ctx);
  const pg48 = t.rpcCalls.filter((c) => c.ad === 'ovsync_pg48_tohumla');
  assert.strictEqual(pg48.length, 1, 'tek PG48 RPCsi');
  assert.deepStrictEqual(pg48[0].prm, { p_case_id: 'c1' }, '(a) p_case_id ile çağrılır');
  assert.ok(t.toastlar.some((x) => !x.hata && x.mesaj.includes('tohumlaması')), 'tai_hedef sonuç metni: ' + JSON.stringify(t.toastlar));
  assert.strictEqual(t.ctx.document._kutu, null, 'başarıda sheet kapanır');
  { // pg1_zaman yoksa ≈ YOK, yalnız metin
    const z = n4f1D3iiCtx({ listele: n4f1D3iiListe([n4f1D3iiUye({ asama: 2, pg1_zaman: null })]) });
    await vm.runInContext('cdKaydirAc()', z.ctx);
    assert.ok(!z.depo.acilan[0].includes('≈'), 'pg1_zaman yoksa ≈ YOK');
    assert.ok(z.depo.acilan[0].includes("PG1 + 48 s'te tohumla"), 'yalnız metin korunur');
  }
});

test('N4-F1 D3ii belirsiz/üye yok → yalnız Baştan başlat (hedef_tarih toast)', async () => {
  for (const [ad, liste] of [
    ['asama-null', n4f1D3iiListe([n4f1D3iiUye({ asama: null })])],
    ['uye-yok', n4f1D3iiListe([n4f1D3iiUye({ case_id: 'baska', hayvan_id: 'hx' })])],
  ]) {
    const t = n4f1D3iiCtx({ listele: liste });
    await vm.runInContext('cdKaydirAc()', t.ctx);
    assert.strictEqual(t.depo.acilan.length, 1, ad + ': sheet açılmalı');
    const html = t.depo.acilan[0];
    assert.ok(html.includes('Baştan başlat'), ad + ': bastan var');
    assert.ok(!html.includes("PG1 + 48 s'te tohumla"), ad + ': (a) YOK');
    assert.ok(!html.includes('Sonraki trene aktar'), ad + ': sonraki YOK');
    assert.ok(!html.includes('kaydir-ovsync-n'), ad + ': +N YOK');
    assert.ok(!html.includes('caseKalanGunleriKaydir'), ad + ': eski kaydır YOK');
  }
  const t = n4f1D3iiCtx({ listele: n4f1D3iiListe([n4f1D3iiUye({ asama: null })]) });
  await vm.runInContext('cdKaydirAc()', t.ctx);
  await vm.runInContext('cdKaydirOvsyncBastan()', t.ctx);
  assert.deepStrictEqual(
    t.rpcCalls.filter((c) => c.ad === 'ovsync_bastan_baslat').map((c) => c.prm),
    [{ p_case_id: 'c1' }], 'bastan p_case_id ile çağrılır',
  );
  assert.ok(t.toastlar.some((x) => !x.hata && x.mesaj === 'Per 3 Ara treninde başlar.'), 'BOŞLUK-4 sonrası metin: ' + JSON.stringify(t.toastlar));
  assert.strictEqual(t.ctx.document._kutu, null, 'sheet kapanır');
  assert.deepStrictEqual(t.timeline, ['c1'], 'vaka tazelenir');
});

test('N4-F1 D3ii offline/listele-hatası OVSYNC → kaydır yok + Ovsync ekranı bağlantısı', async () => {
  const t = n4f1D3iiCtx({ cevrimdisi: true });
  await vm.runInContext('cdKaydirAc()', t.ctx);
  assert.strictEqual(t.rpcCalls.length, 0, 'çevrimdışı listele bile okunmaz');
  assert.strictEqual(t.depo.acilan.length, 1, 'çevrimdışı sheet açılır');
  const html = t.depo.acilan[0];
  assert.ok(html.includes('İnternet yok — Ovsync vakası çevrimiçi kaydırılır'), 'çevrimdışı metni');
  assert.ok(html.includes('Ovsync ekranında düzenle →'), 'bağlantı metni');
  assert.ok(!html.includes('caseKalanGunleriKaydir'), 'eski kaydıra DÜŞMEZ');
  await vm.runInContext('cdKaydirOvsyncDuzenle()', t.ctx);
  assert.deepStrictEqual(t.gidilen, ['ovsync'], 'Ovsync ekranına gider');
  assert.strictEqual(t.ctx._ovsyncOdakHayvan, 'h1', 'odak hayvan taşınır');
  assert.strictEqual(t.ctx.document._kutu, null, 'sheet kapanır');
  { // listele hatası → aynı çevrimdışı sheet, eski kaydıra DÜŞMEZ
    const h = n4f1D3iiCtx({ listeleHata: new Error('ağ hatası') });
    await vm.runInContext('cdKaydirAc()', h.ctx);
    assert.strictEqual(h.depo.acilan.length, 1, 'hata sheeti açılır');
    assert.ok(h.depo.acilan[0].includes('Ovsync ekranında düzenle →'), 'hata bağlantısı');
    assert.ok(!h.depo.acilan[0].includes('caseKalanGunleriKaydir'), 'hata eski kaydıra DÜŞMEZ');
    assert.ok(!h.rpcCalls.some((c) => c.ad === 'ovsync_hayvan_ertele'), 'hatada yazma RPCsi YOK');
  }
});

test('N4-F1 D3ii OVSYNC değil → eski sheet birebir (rpc yok)', async () => {
  const t = n4f1D3iiCtx({ vaka: { id: 'c9', animal_id: 'h9', status: 'active', protocol_family: 'STANDART' } });
  await vm.runInContext('cdKaydirAc()', t.ctx);
  assert.strictEqual(t.depo.acilan.length, 1, 'eski sheet açılır');
  const html = t.depo.acilan[0];
  assert.ok(html.includes('Kalan Günleri Kaydır'), 'eski başlık');
  assert.ok(html.includes('caseKalanGunleriKaydir(1)'), 'eski +1 kablosu');
  assert.ok(html.includes('data-gun="3"'), 'eski +3 düğmesi');
  assert.ok(!html.includes('Ovsync'), 'Ovsync dalı karışmaz');
  assert.strictEqual(t.rpcCalls.length, 0, 'listele okunmaz');
});

test('N4-F1 D3ii bayrak kapalı/sunucu kapalı → eski sheet (listele dalı kapalı)', async () => {
  const k = n4f1D3iiCtx({ ayarlar: [] });
  await vm.runInContext('cdKaydirAc()', k.ctx);
  assert.strictEqual(k.depo.acilan.length, 1, 'eski sheet açılır');
  assert.ok(k.depo.acilan[0].includes('caseKalanGunleriKaydir(1)'), 'kapalıyken eski sheet');
  assert.strictEqual(k.rpcCalls.length, 0, 'kapalıyken listele YOK');
  const s = n4f1D3iiCtx({ listele: n4f1D3iiListe([n4f1D3iiUye()], { aktif: false }) });
  await vm.runInContext('cdKaydirAc()', s.ctx);
  assert.ok(s.depo.acilan[0].includes('caseKalanGunleriKaydir(1)'), 'F12: sunucu kapalıysa eski sheet');
});

test('N4-F1 D3ii asama 1 pay<=0 → yalnız Baştan başlat (seçici kurulmaz)', async () => {
  const t = n4f1D3iiCtx({ listele: n4f1D3iiListe([n4f1D3iiUye({ asama: 1, pg_pay: 0 })]) });
  await vm.runInContext('cdKaydirAc()', t.ctx);
  assert.strictEqual(t.depo.acilan.length, 1, 'sheet açılır');
  const html = t.depo.acilan[0];
  assert.ok(!html.includes('kaydir-ovsync-n'), 'seçici YOK');
  assert.ok(html.includes('Baştan başlat'), 'bastan var');
  assert.ok(!html.includes('caseKalanGunleriKaydir'), 'eski kaydır YOK');
});

// ══ N4-F2 B1 loadOvsyncDash tren bağlaması (js/ui.js) ══
// Desen: tam ui.js modülü + UB2 UA1 seti tek vm ctx'te (tren render yolu UA1 ister);
// DOM gezinti stub'u; rpc/getData/ovsyncTakipGetir kayıtlı sahteler.
function n4f2B1Sahne({ bayrak = true, trenYaniti = 'aktif', onLine = true, bayat = false } = {}) {
  const rec = { rpc: [] };
  let paralel = false;
  const dom = makeDomStub();
  const root = makeElement('div');
  const pgEl = makeElement('div');
  dom.__setEl('ovsync-root', root);
  dom.__setEl('pg-ovsync', pgEl);
  const trenVerisi = ub2TrenVerisi();
  const { sandbox, window } = loadBrowserModule('js/ui.js', {
    dom,
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => UB2_BUGUN,
      getData: async (tablo) => (tablo === 'protokol_ayar' && bayrak
        ? [{ anahtar: 'ovsync_tren_aktif', deger: 1 }, { anahtar: 'ovsync_pg_kurallari_aktif', deger: 1 }]
        : []),
      getState: () => [],
      ovsyncTakipGetir: async () => {
        await new Promise((r) => setTimeout(r, 30));
        paralel = rec.rpc.some((c) => c.ad === 'ovsync_tren_listele');
        const veri = ub2TakipVerisi();
        return bayat ? { bayat: true, veri, zaman: Date.now() } : { veri };
      },
      rpc: async (ad, p) => {
        rec.rpc.push({ ad, p });
        if (ad === 'ovsync_tren_listele') {
          if (trenYaniti === 'hata') throw new Error('ağ hatası');
          if (trenYaniti === 'kapali') return { ok: true, aktif: false };
          return trenVerisi;
        }
        throw new Error('test stub: rpc "' + ad + '" tanımlı değil');
      },
      navigator: { userAgent: 'node-test', onLine },
      ovsyncTrenAktif: loadExtractedFunction('js/ovsync-tren.js', 'ovsyncTrenAktif'),
    },
  });
  const ua1Kaynak = fs.readFileSync(path.join(REPO_ROOT, 'js/ovsync-tren.js'), 'utf8');
  const sabitler = ua1Kaynak.match(/^const _OVT_(GUN_KISA|GUN_UZUN|AY|AY_EK|TREN_IS)\b.*$/gm) || [];
  const ua1src = [...sabitler, ...UB2_UA1_FN.map((n) => extractFunctionSource('js/ovsync-tren.js', n))].join('\n');
  vm.runInContext(ua1src, sandbox, { filename: 'n4f2-b1-ua1' });
  return { sandbox, window, root, rec, trenVerisi, paralelmi: () => paralel };
}

test('N4-F2 B1 bayrak açık → listele PARALEL çağrılır, render 3. argüman yanıt (m9 adlı)', async () => {
  const t = n4f2B1Sahne({ bayrak: true });
  await t.sandbox.loadOvsyncDash();
  assert.ok(t.rec.rpc.some((c) => c.ad === 'ovsync_tren_listele'), 'listele çağrılmalı');
  assert.ok(t.paralelmi(), 'listele takip bitmeden başlamalı (paralel)');
  assert.ok(t.root.innerHTML.includes('Tren · Per 19 Kas'), 'tren başlığı yok: ' + t.root.innerHTML.slice(0, 200));
  assert.ok(!t.root.innerHTML.includes('Dalga:'), 'tren yolunda eski Dalga başlığı olmamalı');
});

test('N4-F2 B1 bayrak kapalı → listele ÇAĞRILMAZ, eski html birebir', async () => {
  const t = n4f2B1Sahne({ bayrak: false });
  await t.sandbox.loadOvsyncDash();
  assert.strictEqual(t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_listele').length, 0, 'kapalıyken listele YOK');
  assert.ok(t.root.innerHTML.includes('Dalga:'), 'eski S1 dalga başlığı korunmalı');
  assert.ok(!t.root.innerHTML.includes('ovs-tren-bas'), 'eski yolda tren başlığı olmamalı');
});

test('N4-F2 B1 listele hata → eski html, takip ekranı yine çizilir', async () => {
  const t = n4f2B1Sahne({ bayrak: true, trenYaniti: 'hata' });
  await t.sandbox.loadOvsyncDash();
  assert.ok(t.rec.rpc.some((c) => c.ad === 'ovsync_tren_listele'), 'listele denendi');
  assert.ok(t.root.innerHTML.includes('ovs-kpa'), 'takip ekranı çizilmeli');
  assert.ok(t.root.innerHTML.includes('Dalga:'), 'hatada eski Dalga yolu birebir');
});

test('N4-F2 B1 bayat dalda da aktif yanıt 3. argümanla trene düşer', async () => {
  const t = n4f2B1Sahne({ bayrak: true, bayat: true });
  await t.sandbox.loadOvsyncDash();
  assert.ok(t.root.innerHTML.includes('çevrimdışı ·'), 'bayat şeridi korunmalı');
  assert.ok(t.root.innerHTML.includes('Tren · Per 19 Kas'), 'bayat dalda da tren yolu');
});

// ══ N4-F2 B2 toptan + tekil eylem akışları (js/ui.js) ══
// Desen: UA1 tam modül + ui.js cerrahi extract tek vm ctx'te (ub3UiCtx kalıbı);
// document gerçek delegated dinleyiciye bağlı (doc.__dispatch click) — HTML
// üreticisini doğrudan çağırmak YETMEZ, tıklama → sahte rpc → DOM ölçülür.
const N4F2_B2_UI_EK = [
  '_ovsyncTrenCagir', '_ovsyncToptanOku', '_ovsyncErteleOku',
  '_ovsyncModalYaz', '_ovsyncModalKapat',
  'ovsyncToptanAc', '_ovsyncToptanGovdeYaz', 'ovsyncToptanN', 'ovsyncToptanSecim',
  '_ovsyncToptanDustuGoster', 'ovsyncToptanOnayla', '_ovsyncTrenYenile',
  '_ovsyncErteleAc', '_ovsyncErteleGovdeYaz',
  'ovsyncErteleN', 'ovsyncErteleOnayla', 'ovsyncSonrakiTren', 'ovsyncPg48',
  '_ertelemeOnline', '_ertelemeOfflineGuard',
];
const N4F2_B2_FORMS_EK = ['_ovsyncTrenTarihAd', '_ovsyncErteleSonucMetni', '_ovsyncToptanSonucMetni'];

function n4f2b2Plan(ust = {}) {
  return Object.assign({
    tren: '2026-11-19', yeni_tren: '2026-11-26',
    uyeler: [
      {
        hayvan_id: 'h2', kupe_no: '38', case_id: 'c2', asama: 1,
        sonuc: 'KAYAR', yeni_tarih: '2026-11-26', ovsync_tren: '2026-11-19',
      },
      {
        hayvan_id: 'h1', kupe_no: '36', case_id: 'c1', asama: 2,
        sonuc: 'SECIM', yeni_tarih: null, ovsync_tren: '2026-11-19',
      },
    ],
    tren_sayisi: 1, dokunulmaz: { bagimsiz: 0, ritim_disi: 0 },
    ileri_gorevler: [], ileri_vakalar: [],
  }, ust);
}

// getElementById body-altını da tarar (modal overlay createElement + appendChild ile kurulur).
function n4f2b2Dom() {
  const doc = makeDomStub();
  const taban = doc.getElementById;
  doc.getElementById = (id) => {
    const hazir = taban(id);
    if (hazir) return hazir;
    const tara = (el) => {
      if (!el) return null;
      if (el.id === id) return el;
      for (const c of (el.children || [])) { const b = tara(c); if (b) return b; }
      return null;
    };
    return tara(doc.body);
  };
  doc.__setEl('ovsync-root', makeElement('div'));
  return doc;
}

function n4f2b2Ctx(sahte = {}) {
  const rec = { rpc: [], toast: [], invalidate: 0, yenile: 0, bastan: [], gittigi: [] };
  const doc = n4f2b2Dom();
  const plan = sahte.plan === undefined ? n4f2b2Plan() : sahte.plan;
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    dom: doc,
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => UB2_BUGUN,
      goTo: (p) => rec.gittigi.push(p),
      toast: (m, e) => rec.toast.push({ mesaj: String(m), hata: !!e }),
      getData: async (t) => (t === 'protokol_ayar'
        ? [{ anahtar: 'ovsync_tren_aktif', deger: 1 }, { anahtar: 'ovsync_pg_kurallari_aktif', deger: 1 }]
        : []),
      _ovsyncTakipInvalidate: () => { rec.invalidate++; },
      loadOvsyncDash: async () => { rec.yenile++; },
      _ovsyncBastanBaslatAkisi: async (cid) => { rec.bastan.push(cid); return true; },
      rpc: async (ad, p) => {
        rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p || {})) });
        if (ad === 'ovsync_tren_listele') {
          if (sahte.listeleHata) throw new Error(sahte.listeleHata);
          return ub2TrenVerisi();
        }
        if (ad === 'ovsync_tren_ertele_onizle') {
          if (sahte.onizleHata) throw new Error(sahte.onizleHata);
          return typeof sahte.onizle === 'function' ? sahte.onizle(p) : (sahte.onizle !== undefined ? sahte.onizle : plan);
        }
        if (ad === 'ovsync_tren_ertele') {
          if (sahte.erteleHata) throw new Error(sahte.erteleHata);
          return sahte.erteleSonuc !== undefined ? sahte.erteleSonuc
            : { ok: true, tren: '2026-11-19', yeni_tren: '2026-11-26', islenen: [], ileri_vakalar: [] };
        }
        if (ad === 'ovsync_hayvan_ertele') {
          if (sahte.hayvanErteleHata) throw new Error(sahte.hayvanErteleHata);
          return sahte.hayvanErteleSonuc !== undefined ? sahte.hayvanErteleSonuc
            : { ok: true, asama: 1, sonuc: 'KAYDI', yeni_tarih: '2026-11-20' };
        }
        if (ad === 'ovsync_pg48_tohumla') {
          if (sahte.pg48Hata) throw new Error(sahte.pg48Hata);
          return sahte.pg48Sonuc !== undefined ? sahte.pg48Sonuc
            : { ok: true, tai_gorev_id: 't1', tai_hedef: '2026-11-19', kapanan_seans: 1 };
        }
        throw new Error('test stub: rpc "' + ad + '" tanımlı değil');
      },
      navigator: { userAgent: 'node-test', onLine: sahte.cevrimdisi ? false : true },
    },
  });
  const uiSrc = [...UB2_UI_FN, ...UB3_UI_EK, ...N4F2_B2_UI_EK]
    .map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, loaded.sandbox, { filename: 'n4f2-b2-ui' });
  const formsSrc = N4F2_B2_FORMS_EK.map((n) => extractFunctionSource('js/forms.js', n)).join('\n');
  vm.runInContext(formsSrc, loaded.sandbox, { filename: 'n4f2-b2-forms' });
  doc.addEventListener('click', loaded.sandbox._ovsyncTrenAksiyonTikla);
  return { ctx: loaded.sandbox, doc, rec };
}

function n4f2b2Attr(ds) {
  return (a) => {
    const k = String(a).replace(/^data-/, '').split('-')
      .map((w, i) => (i ? w[0].toUpperCase() + w.slice(1) : w)).join('');
    const v = ds[k];
    return v == null ? null : String(v);
  };
}

// Gerçek delegated dinleyiciye tıklama: target.closest üç seçiciyi de yanıtlar.
function n4f2b2Hedef(tur, ds) {
  return {
    closest: (sec) => {
      if (tur === 'aksiyon' && sec === '[data-ovt-aksiyon]') return { dataset: ds, getAttribute: n4f2b2Attr(ds) };
      if (tur === 'n' && sec === '[data-n]') return { dataset: ds, getAttribute: n4f2b2Attr(ds) };
      if (tur === 'radyo' && sec === '.ovs-radyo[data-case]') return { dataset: ds, getAttribute: n4f2b2Attr(ds) };
      return null;
    },
  };
}

async function n4f2b2Tikla(doc, tur, ds) {
  doc.__dispatch('click', { target: n4f2b2Hedef(tur, ds) });
  await new Promise((r) => setTimeout(r, 20));
}

function n4f2b2Modal(doc, id) {
  const kutu = doc.getElementById(id);
  return kutu ? String(kutu.innerHTML || '') : null;
}

test('N4-F2 B2 TOPTAN tık → ertele_onizle(p_tarih,p_n), modalda N + SECIM + ONAYLA', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'TOPTAN', tarih: '2026-11-19' });
  const onizle = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ertele_onizle');
  assert.strictEqual(onizle.length, 1, 'önizleme bir kez çağrılmalı: ' + JSON.stringify(t.rec.rpc));
  assert.deepStrictEqual(onizle[0].p, { p_tarih: '2026-11-19', p_n: 1 }, 'imza sözleşmeden birebir (M7)');
  const html = n4f2b2Modal(t.doc, 'ovt-toptan-bs');
  assert.ok(html, 'toptan modalı açılmalı');
  assert.ok(html.includes('data-n="7"'), 'N seçici 1..7 olmalı');
  assert.ok(html.includes('data-ovt-aksiyon="ONAYLA" disabled'), 'SECIM varken onay kapalı açılmalı (F4)');
  assert.ok(html.includes('data-case="c1"'), 'SECIM satırı case taşımalı');
  assert.ok(!html.includes('onclick'), 'modalda inline onclick YOK');
});

test('N4-F2 B2 SECIM seçilmeden ONAYLA → rpc YOK (m10 adlı)', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'TOPTAN', tarih: '2026-11-19' });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ONAYLA' });
  assert.ok(!t.rec.rpc.some((c) => c.ad === 'ovsync_tren_ertele'), 'onay kapalıyken ertele RPCsi YOK (m10 hedefi)');
});

test('N4-F2 B2 SECIM seçilince ONAYLA → ovsync_tren_ertele p_secimler dolu + F5 + tazeleme', async () => {
  const t = n4f2b2Ctx({
    erteleSonuc: {
      ok: true, tren: '2026-11-19', yeni_tren: '2026-11-26',
      islenen: [{ hayvan_id: 'h1', kupe_no: '36', case_id: 'c1', sonuc: 'PG48', yeni_tarih: '2026-11-19', detay: { iptal_tai: ['t9'], basladi: false, yeniden_hedef: '2026-11-26' } }],
      ileri_vakalar: [{ case_id: 'cx', hayvan_id: 'hx', kupe_no: '5708', eski: '2026-11-19', yeni: '2026-11-26' }],
    },
  });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'TOPTAN', tarih: '2026-11-19' });
  await n4f2b2Tikla(t.doc, 'radyo', { case: 'c1', secim: 'PG48' });
  const onizleSayi = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ertele_onizle').length;
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ONAYLA' });
  const ertele = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ertele');
  assert.strictEqual(ertele.length, 1, 'onay açıkken tek ertele RPCsi: ' + JSON.stringify(t.rec.rpc));
  assert.deepStrictEqual(ertele[0].p, { p_tarih: '2026-11-19', p_n: 1, p_secimler: { c1: 'PG48' } }, 'p_secimler dolu taşınmalı (M7)');
  assert.strictEqual(t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ertele_onizle').length, onizleSayi, 'SECIM önizleme RPCsi atmamalı');
  const metin = t.rec.toast.map((x) => x.mesaj).join(' ');
  assert.ok(metin.includes('1 hayvan işlendi'), 'işlenen sayısı sonuçta (F5): ' + metin);
  assert.ok(metin.includes('tohumlama iptal'), 'iptal_tai sonuçta (F5): ' + metin);
  assert.ok(metin.includes('Per 26 Kas'), 'yeniden_hedef sonuçta (F5): ' + metin);
  assert.ok(metin.includes('5708'), 'ileri_vakalar sonuçta (F5): ' + metin);
  assert.strictEqual(t.doc.getElementById('ovt-toptan-bs'), null, 'başarıda modal kapanır');
  assert.ok(t.rec.invalidate >= 1, 'yazma sonrası invalidate');
  assert.ok(t.rec.yenile >= 1, 'ekran yeniden yüklenir');
});

test('N4-F2 B2 N çipi → onizle p_n ile yeniden, secimler sıfırlanır', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'TOPTAN', tarih: '2026-11-19' });
  await n4f2b2Tikla(t.doc, 'radyo', { case: 'c1', secim: 'BASTAN' });
  await n4f2b2Tikla(t.doc, 'n', { n: '3' });
  const cagrilar = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ertele_onizle');
  assert.strictEqual(cagrilar.length, 2, 'N değişimi önizlemeyi yeniler: ' + JSON.stringify(t.rec.rpc));
  assert.deepStrictEqual(cagrilar[1].p, { p_tarih: '2026-11-19', p_n: 3 }, 'yeni N taşınmalı');
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ONAYLA' });
  assert.ok(!t.rec.rpc.some((c) => c.ad === 'ovsync_tren_ertele'), 'N sonrası secim sıfırlandığı için onay kapalı kalır');
});

test('N4-F2 B2 ERTELE_DUSTU → modal AÇIK, düşen küpe + sebep görünür (m11 adlı)', async () => {
  const dusen = 'OVSYNC_TREN_ERTELE_DUSTU:{"tren":"2026-11-19","n":1,"dusenler":[{"hayvan_id":"h2","kupe_no":"38","case_id":"c2","sebep":"OVSYNC_ASAMA1_TOLERANS:{\\"tolerans\\":1, \\"kayma\\":0}"}]}';
  const t = n4f2b2Ctx({
    plan: n4f2b2Plan({ uyeler: [n4f2b2Plan().uyeler[0]] }),
    erteleHata: dusen,
  });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'TOPTAN', tarih: '2026-11-19' });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ONAYLA' });
  assert.strictEqual(t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ertele').length, 1, 'ertele denendi');
  const html = n4f2b2Modal(t.doc, 'ovt-toptan-bs');
  assert.ok(html, 'DUSTU modalı KAPATMAZ (m11 hedefi)');
  assert.ok(html.includes('38'), 'düşen küpe görünür: ' + html.slice(0, 200));
  assert.ok(html.includes('PG en çok'), 'sebep metni çözülmüş: ' + html.slice(0, 300));
  assert.ok(!t.rec.toast.some((x) => x.mesaj.includes('38')), 'düşen listesi toastta değil modalda');
});

test('N4-F2 B2 ERTELE tık (aşama1) → N modalı → ONAYLA p_gun + yeni_tarih toast', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ERTELE', hayvan: 'h2', case: 'c2' });
  assert.ok(t.rec.rpc.some((c) => c.ad === 'ovsync_tren_listele'), 'üye için listele çekilir');
  const html = n4f2b2Modal(t.doc, 'ovt-ertele-bs');
  assert.ok(html, 'tekil ertele modalı açılır');
  assert.ok(html.includes('data-n="1"') && !html.includes('data-n="2"'), 'aşama1 pay=1 → yalnız +1 (F3): ' + html.slice(0, 200));
  await n4f2b2Tikla(t.doc, 'n', { n: '1' });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ERTELE_ONAYLA' });
  const cagrilar = t.rec.rpc.filter((c) => c.ad === 'ovsync_hayvan_ertele');
  assert.deepStrictEqual(cagrilar.map((c) => c.p), [{ p_hayvan_id: 'h2', p_gun: 1 }], 'p_gun taşınmalı');
  assert.ok(t.rec.toast.some((x) => x.mesaj.includes('Cum 20 Kas')), 'yeni_tarih toastta: ' + JSON.stringify(t.rec.toast));
  assert.strictEqual(t.doc.getElementById('ovt-ertele-bs'), null, 'başarıda modal kapanır');
  assert.ok(t.rec.invalidate >= 1 && t.rec.yenile >= 1, 'invalidate + yeniden yükleme');
});

test('N4-F2 B2 ERTELE bağımsız (aşama0) → 1..7 seçici (F3)', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ERTELE', hayvan: 'h9', case: 'c9' });
  const html = n4f2b2Modal(t.doc, 'ovt-ertele-bs');
  assert.ok(html && html.includes('data-n="7"'), 'bağımsız aşama0 1..7 seçici (F3): ' + String(html).slice(0, 200));
  await n4f2b2Tikla(t.doc, 'n', { n: '3' });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'ERTELE_ONAYLA' });
  const cagrilar = t.rec.rpc.filter((c) => c.ad === 'ovsync_hayvan_ertele');
  assert.deepStrictEqual(cagrilar.map((c) => c.p), [{ p_hayvan_id: 'h9', p_gun: 3 }], 'seçilen N taşınmalı');
});

test('N4-F2 B2 SONRAKI_TREN → p_gun:1, hedef sunucuda (D6)', async () => {
  const t = n4f2b2Ctx({ hayvanErteleSonuc: { ok: true, asama: 0, sonuc: 'SONRAKI_TREN', yeni_tarih: '2026-11-26' } });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'SONRAKI_TREN', hayvan: 'h3', case: 'c3' });
  const cagrilar = t.rec.rpc.filter((c) => c.ad === 'ovsync_hayvan_ertele');
  assert.deepStrictEqual(cagrilar.map((c) => c.p), [{ p_hayvan_id: 'h3', p_gun: 1 }], 'gün farkı sunucuya bırakılır (D6)');
  assert.ok(t.rec.toast.some((x) => x.mesaj.includes('Per 26 Kas')), 'yanıttaki yeni_tarih toastta: ' + JSON.stringify(t.rec.toast));
  assert.ok(t.rec.invalidate >= 1 && t.rec.yenile >= 1, 'invalidate + yeniden yükleme');
});

test('N4-F2 B2 PG48 tık → ovsync_pg48_tohumla, tai_hedef toast (BOŞLUK-1 sonrası)', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'PG48', hayvan: 'h1', case: 'c1' });
  const cagrilar = t.rec.rpc.filter((c) => c.ad === 'ovsync_pg48_tohumla');
  assert.deepStrictEqual(cagrilar.map((c) => c.p), [{ p_case_id: 'c1' }], 'tek RPC p_case_id ile');
  assert.ok(
    t.rec.toast.some((x) => x.mesaj.includes('Per 19 Kas') && x.mesaj.includes('48 s')),
    'tai_hedef toastta: ' + JSON.stringify(t.rec.toast),
  );
  assert.ok(t.rec.invalidate >= 1 && t.rec.yenile >= 1, 'invalidate + yeniden yükleme');
});

test('N4-F2 B2 BASTAN + DUZENLE korunur, bilinmeyen yutulmaz', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'BASTAN', case: 'c1', hayvan: 'h1' });
  assert.deepStrictEqual(t.rec.bastan, ['c1'], 'BASTAN akışı korunur');
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'DUZENLE', hayvan: 'h36' });
  assert.deepStrictEqual(t.rec.gittigi, ['ovsync'], 'DUZENLE ekrana gider');
  assert.strictEqual(t.ctx.window._ovsyncOdakHayvan, 'h36', 'odak bırakılır');
  t.doc.__dispatch('click', { target: n4f2b2Hedef('aksiyon', { ovtAksiyon: 'BILINMEYEN' }) });
  await new Promise((r) => setTimeout(r, 5));
  assert.strictEqual(t.rec.rpc.length, 0, 'bilinmeyen aksiyon rpc atmaz');
  assert.ok(!t.rec.toast.length, 'bilinmeyen aksiyon toast atmaz');
});

test('N4-F2 B2 offline → eylem düğmeleri çizilmez, giriş guardlı', async () => {
  const t = n4f2b2Ctx({ cevrimdisi: true });
  const html = vm.runInContext(
    `renderOvsyncSayfa(${JSON.stringify(ub2TakipVerisi())}, '${UB2_BUGUN}', ${JSON.stringify(ub2TrenVerisi())})`,
    t.ctx,
  );
  for (const ad of ['TOPTAN', 'ERTELE', 'SONRAKI_TREN', 'PG48']) {
    assert.ok(!html.includes('data-ovt-aksiyon="' + ad + '"'), 'çevrimdışı ' + ad + ' düğmesi çizilmez');
  }
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'TOPTAN', tarih: '2026-11-19' });
  assert.ok(!t.rec.rpc.length, 'çevrimdışı girişte RPC YOK');
  assert.strictEqual(n4f2b2Modal(t.doc, 'ovt-toptan-bs'), null, 'çevrimdışı modal YOK');
  assert.ok(t.rec.toast.some((x) => x.mesaj.includes('İnternet')), 'guard toast atar');
});

test('N4-F2 B2 VAZGEC → açık modal kapanır, K8 VAZGEC yutulmaz', async () => {
  const t = n4f2b2Ctx();
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'TOPTAN', tarih: '2026-11-19' });
  assert.ok(n4f2b2Modal(t.doc, 'ovt-toptan-bs'), 'önce modal açık');
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'VAZGEC' });
  assert.strictEqual(t.doc.getElementById('ovt-toptan-bs'), null, 'VAZGEC kapatır');
  assert.strictEqual(t.ctx.window._ovsyncToptan, null, 'durum sıfırlanır');
  assert.ok(!t.rec.rpc.some((c) => c.ad === 'ovsync_tren_ertele'), 'VAZGEC rpc atmaz');
});

// ══ N4-F2 Parca3 tren ayarı paneli (js/ui.js, mockup 06) ══
// Desen B2 ile aynı: UA1 tam modül + ui.js cerrahi extract tek vm ctx'te;
// document gerçek delegated dinleyiciye bağlı — tıklama → sahte rpc → DOM.
const N4F2_AYAR_UI_EK = [
  '_ovsyncK8GunAd',
  '_ovsyncAyarOku', '_ovsyncAyarHaftaGunu', '_ovsyncAyarSatirHtml',
  '_ovsyncAyarCapaOku', '_ovsyncAyarOzetHtml',
  'ovsyncAyarAc', '_ovsyncAyarGovdeYaz', 'ovsyncAyarCapaSec', 'ovsyncAyarSecim',
  'ovsyncAyarOnizle', 'ovsyncAyarKaydet',
];

function n4f2a3YenidenHedef() {
  return {
    ok: true, kuru: true, capa: '2026-12-03',
    gorevler: [
      { gorev_id: 'g905', hayvan_id: 'h905', kupe_no: '905', eski: '2026-12-03', yeni: '2026-12-04', durum: 'TASINIR' },
      { gorev_id: 'g3020', hayvan_id: 'h3020', kupe_no: '3020', eski: '2026-12-03', yeni: null, durum: 'KURAL_YOK' },
    ],
    uyelik: [],
    belirsiz_asama: [{ case_id: 'cb', hayvan_id: 'hb', kupe_no: '88' }],
    belirsiz_sayisi: 1,
  };
}

function n4f2a3Ctx(sahte = {}) {
  const rec = { rpc: [], toast: [], invalidate: 0, yenile: 0, gittigi: [] };
  const doc = n4f2b2Dom();
  const loaded = loadBrowserModule('js/ovsync-tren.js', {
    dom: doc,
    extra: {
      esc: (v) => String(v == null ? '' : v),
      escAttr: (v) => String(v == null ? '' : v),
      bugun: () => UB2_BUGUN,
      goTo: (p) => rec.gittigi.push(p),
      toast: (m, e) => rec.toast.push({ mesaj: String(m), hata: !!e }),
      getData: async (t) => (t === 'protokol_ayar'
        ? [{ anahtar: 'ovsync_tren_aktif', deger: 1 }, { anahtar: 'ovsync_pg_kurallari_aktif', deger: 1 },
           { anahtar: 'ovsync_tren_one_cekme_gun', deger: 2 }, { anahtar: 'ovsync_pg_erteleme_tolerans_gun', deger: 1 }]
        : []),
      _ovsyncTakipInvalidate: () => { rec.invalidate++; },
      loadOvsyncDash: async () => { rec.yenile++; },
      _ovsyncBastanBaslatAkisi: async () => true,
      rpc: async (ad, p) => {
        rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p || {})) });
        if (ad === 'ovsync_tren_listele') {
          if (sahte.listeleHata) throw new Error(sahte.listeleHata);
          if (sahte.listele) return sahte.listele;
          return { ok: true, aktif: true, capa: '2026-12-03', bugun: UB2_BUGUN, trenler: [], bagimsizlar: [], ileri_sayisi: 0 };
        }
        if (ad === 'ovsync_tren_yeniden_hedefle') {
          if (sahte.onizleHata) throw new Error(sahte.onizleHata);
          return sahte.onizle !== undefined ? sahte.onizle : n4f2a3YenidenHedef();
        }
        if (ad === 'ovsync_tren_ayar_guncelle') {
          if (sahte.kaydetHata) throw new Error(sahte.kaydetHata);
          return sahte.kaydetSonuc !== undefined ? sahte.kaydetSonuc
            : { ok: true, aktif: true, capa: '2026-12-03', yeniden_hedef: null };
        }
        throw new Error('test stub: rpc "' + ad + '" tanımlı değil');
      },
      navigator: { userAgent: 'node-test', onLine: sahte.cevrimdisi ? false : true },
    },
  });
  const uiSrc = [...UB2_UI_FN, ...UB3_UI_EK, ...N4F2_B2_UI_EK, ...N4F2_AYAR_UI_EK]
    .map((n) => extractFunctionSource('js/ui.js', n)).join('\n');
  vm.runInContext(uiSrc, loaded.sandbox, { filename: 'n4f2-a3-ui' });
  const formsSrc = N4F2_B2_FORMS_EK.map((n) => extractFunctionSource('js/forms.js', n)).join('\n');
  vm.runInContext(formsSrc, loaded.sandbox, { filename: 'n4f2-a3-forms' });
  doc.addEventListener('click', loaded.sandbox._ovsyncTrenAksiyonTikla);
  return { ctx: loaded.sandbox, doc, rec };
}

async function n4f2a3Ac(t) {
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR' });
  return n4f2b2Modal(t.doc, 'ovt-ayar-bs');
}

test('N4-F2 Parca3 AYAR tık → listele, modalda anahtar + çapa + Önizle + Kaydet', async () => {
  const t = n4f2a3Ctx();
  const html = await n4f2a3Ac(t);
  const listele = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_listele');
  assert.strictEqual(listele.length, 1, 'giriş çapayı listele ile okur: ' + JSON.stringify(t.rec.rpc));
  assert.ok(html, 'ayar modalı açılır');
  assert.ok(html.includes('Tren ayarı'), 'başlık mockup 06');
  assert.ok(html.includes('data-ovt-aksiyon="AYAR_ACIK"'), 'açık anahtarı');
  assert.ok(html.includes('data-ovt-aksiyon="AYAR_KAPALI"'), 'kapalı anahtarı');
  assert.ok(html.includes('önceki:'), 'önceki çapa gösterilir: ' + html.slice(0, 400));
  assert.ok(html.includes('Per 3 Ara'), 'önceki çapa gün-adı (2026-12-03): ' + html.slice(0, 600));
  assert.ok(html.includes('Öne çekme en çok 2 gün'), 'genel ayar satırı mockup 06');
  assert.ok(html.includes('data-ovt-aksiyon="AYAR_ONIZLE"'), 'Önizle düğmesi');
  assert.ok(html.includes('data-ovt-aksiyon="AYAR_KAYDET"'), 'Kaydet düğmesi');
  assert.ok(html.includes('data-ovt-aksiyon="AYAR_TAKVIM"'), 'çapa kanonik takvim düğmesi (F4: native date YOK)');
  assert.ok(!html.includes('type="date"'), 'native date girişi YOK (tarih-saf F4)');
  assert.ok(!html.includes('onclick'), 'modalda inline onclick YOK');
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR_TAKVIM' });
  assert.strictEqual(t.rec.rpc.length, listele.length, 'takvim tıkı (çekirdeksiz ctx) rpc atmaz, çökmez');
  assert.ok(n4f2b2Modal(t.doc, 'ovt-ayar-bs'), 'takvim tıkı modalı kapatmaz');
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'VAZGEC' });
  assert.strictEqual(t.doc.getElementById('ovt-ayar-bs'), null, 'VAZGEC ayar modalını kapatır');
  assert.ok(!t.rec.rpc.some((c) => c.ad === 'ovsync_tren_ayar_guncelle'), 'VAZGEC kaydetmez');
});

test('N4-F2 Parca3 ayar Önizle → yeniden_hedefle(p_kuru:true,p_capa) + özet', async () => {
  const t = n4f2a3Ctx();
  await n4f2a3Ac(t);
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR_ONIZLE' });
  const onizle = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_yeniden_hedefle');
  assert.strictEqual(onizle.length, 1, 'kuru önizleme bir kez: ' + JSON.stringify(t.rec.rpc));
  assert.deepStrictEqual(onizle[0].p, { p_kuru: true, p_capa: '2026-12-03' }, 'imza sözleşmeden birebir (M8)');
  const html = n4f2b2Modal(t.doc, 'ovt-ayar-bs');
  assert.ok(html, 'önizlemede modal açık kalır');
  assert.ok(html.includes('905'), 'taşınır küpe satırda');
  assert.ok(html.includes('kural günü bulunamadı'), 'KURAL_YOK satırı mockup 06');
  assert.ok(html.includes('1 görev yeniden hedeflenecek'), 'taşınır sayısı özeti');
  assert.ok(html.includes('88'), 'belirsiz aşama küpesi listede');
  assert.ok(html.includes('Kaydet (1 görev)'), 'Kaydet etiketi taşınır sayısı: ' + html.slice(-300));
});

test('N4-F2 Parca3 anahtar tık → durum değişir, Kaydet p_aktif taşır', async () => {
  const t = n4f2a3Ctx();
  await n4f2a3Ac(t);
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR_KAPALI' });
  let html = n4f2b2Modal(t.doc, 'ovt-ayar-bs');
  assert.ok(html && html.includes('AYAR_KAPALI'), 'kapalı seçimi çizilir');
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR_KAYDET' });
  const kaydet = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ayar_guncelle');
  assert.strictEqual(kaydet.length, 1, 'kaydet bir kez');
  assert.deepStrictEqual(kaydet[0].p, { p_aktif: false, p_capa: '2026-12-03' }, 'p_aktif anahtardan taşınır (M8)');
});

test('N4-F2 Parca3 ayar Kaydet → ayar_guncelle + invalidate + yenileme (m12 adlı)', async () => {
  const t = n4f2a3Ctx();
  await n4f2a3Ac(t);
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR_ONIZLE' });
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR_KAYDET' });
  const kaydet = t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ayar_guncelle');
  assert.strictEqual(kaydet.length, 1, 'kaydet bir kez: ' + JSON.stringify(t.rec.rpc));
  assert.deepStrictEqual(kaydet[0].p, { p_aktif: true, p_capa: '2026-12-03' }, 'imza sözleşmeden birebir (M8)');
  const metin = t.rec.toast.map((x) => x.mesaj).join(' ');
  assert.ok(metin.includes('Tren ayarı kaydedildi'), 'başarı toastu: ' + metin);
  assert.strictEqual(t.doc.getElementById('ovt-ayar-bs'), null, 'başarıda modal kapanır');
  assert.ok(t.rec.invalidate >= 1, 'yazma sonrası invalidate');
  assert.ok(t.rec.yenile >= 1, 'ekran yeniden yüklenir');
});

test('N4-F2 Parca3 ayar hata → OVSYNC_TREN_AYAR metinli toast, modal AÇIK', async () => {
  const t = n4f2a3Ctx({ kaydetHata: 'OVSYNC_TREN_AYAR:{"anahtar":"p_capa","deger":"x","sebep":"TARIH_GECERSIZ"}' });
  await n4f2a3Ac(t);
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR_KAYDET' });
  assert.strictEqual(t.rec.rpc.filter((c) => c.ad === 'ovsync_tren_ayar_guncelle').length, 1, 'kaydet denendi');
  const metin = t.rec.toast.map((x) => x.mesaj).join(' ');
  assert.ok(metin.includes('eksik ya da geçersiz'), 'OVSYNC_TREN_AYAR Türkçe metni: ' + metin);
  assert.ok(n4f2b2Modal(t.doc, 'ovt-ayar-bs'), 'hata modalı KAPATMAZ');
  assert.strictEqual(t.rec.invalidate, 0, 'hatada invalidate YOK');
  assert.strictEqual(t.rec.yenile, 0, 'hatada yeniden yükleme YOK');
});

test('N4-F2 Parca3 offline → ayar düğmesi çizilmez, giriş guardlı', async () => {
  const t = n4f2a3Ctx({ cevrimdisi: true });
  const html = vm.runInContext(
    `renderOvsyncSayfa(${JSON.stringify(ub2TakipVerisi())}, '${UB2_BUGUN}', ${JSON.stringify(ub2TrenVerisi())})`,
    t.ctx,
  );
  assert.ok(!html.includes('data-ovt-aksiyon="AYAR"'), 'çevrimdışı ayar düğmesi çizilmez (PLAN UB3)');
  await n4f2b2Tikla(t.doc, 'aksiyon', { ovtAksiyon: 'AYAR' });
  assert.ok(!t.rec.rpc.length, 'çevrimdışı girişte RPC YOK');
  assert.strictEqual(n4f2b2Modal(t.doc, 'ovt-ayar-bs'), null, 'çevrimdışı modal YOK');
  assert.ok(t.rec.toast.some((x) => x.mesaj.includes('İnternet')), 'guard toast atar');
});

// ══ N4-F4: tren bloğu yerleşimi (mockup 02a/02b) + düzenle linki (DM2 BULGU-1/2) ══
// Vitrin benzeri fikstür (bugün Pzt 9 Kas): Per 5 Kas treni (03 aşama 1, 04 aşama 2),
// Per 12 Kas treni (A01, A02, A5708 aşama 0 — OVSYNC_BASLAT görevli, takipte S3),
// bağımsız 05; A08 trende olmayan başlatma bekleyen (S3'te kalmalı).
const F4_BUGUN = '2026-11-09';
function f4Uye(h, k, asama, tren, si, ek) {
  return Object.assign({
    hayvan_id: h, kupe_no: k, case_id: asama === 0 ? null : 'c' + k, gorev_id: asama === 0 ? 'g' + k : null,
    asama, ovsync_tren: tren, sonraki_is: si, pg_pay: null, pg1_zaman: null, ritim_disi_neden: null,
  }, ek || {});
}
function f4TrenVerisi() {
  return {
    aktif: true, bugun: F4_BUGUN, capa: '2026-11-12', ileri_sayisi: 0,
    trenler: [
      { tren_gunu: '2026-11-05', ritim_disi: false, uyeler: [
        f4Uye('h03', 'A03', 1, '2026-11-05', { tarih: '2026-11-12', saat: null, tur: 'PG1' }, { pg_pay: 1 }),
        f4Uye('h04', 'A04', 2, '2026-11-05', { tarih: '2026-11-14', saat: '10:00', tur: 'TAI' }),
      ] },
      { tren_gunu: '2026-11-12', ritim_disi: false, uyeler: [
        f4Uye('h01', 'A01', 0, '2026-11-12', { tarih: '2026-11-12', saat: null, tur: 'GNRH1' }),
        f4Uye('h02', 'A02', 0, '2026-11-12', { tarih: '2026-11-12', saat: null, tur: 'GNRH1' }),
        f4Uye('h5708', 'A5708', 0, '2026-11-12', { tarih: '2026-11-12', saat: null, tur: 'GNRH1' }),
      ] },
    ],
    bagimsizlar: [f4Uye('h05', 'A05', 1, null, { tarih: '2026-11-16', saat: null, tur: 'PG1' }, { pg_pay: 1 })],
  };
}
function f4TakipVerisi() {
  const s3 = (h, k, d) => ({ bolum: 'S3', hayvan_id: h, kupe_no: k, grup: 'Düve', taban_turu: 'duve', dalga_anahtari: d });
  return {
    kpa: { aktif: 3, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 4 },
    satirlar: [
      { bolum: 'S1', hayvan_id: 'h03', kupe_no: 'A03', grup: 'Sağmal', taban_turu: 'dogum', gunler: [] },
      { bolum: 'S1', hayvan_id: 'h04', kupe_no: 'A04', grup: 'Sağmal', taban_turu: 'dogum', gunler: [] },
      { bolum: 'S1', hayvan_id: 'h05', kupe_no: 'A05', grup: 'Sağmal', taban_turu: 'dogum', gunler: [] },
      s3('h01', 'A01', '2026-11-12'), s3('h02', 'A02', '2026-11-12'), s3('h5708', 'A5708', '2026-11-12'),
      s3('h08', 'A08', '2026-11-09'),
    ],
  };
}
function f4Render(veri, tv, ekstra) {
  const ctx = ub2UiCtx(ekstra || {});
  return vm.runInContext(`renderOvsyncSayfa(${JSON.stringify(veri)}, '${F4_BUGUN}', ${JSON.stringify(tv)})`, ctx);
}
// Tren başlığından bir sonraki başlığa / bölüme kadar olan blok
function f4TrenBloklari(html) {
  const parcalar = html.split('<div class="ovs-tren-bas">').slice(1);
  return parcalar.map((p) => {
    const son = p.search(/<div class="ovs-bolum">/);
    const govde = son >= 0 ? p.slice(0, son) : p;
    return { baslik: govde.split('</div>')[0], govde };
  });
}
const f4Gorunen = (h) => String(h).replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();

test('tren bloğu: başlık altında tüm üyelerin kartı, N=kart sayısı', () => {
  const html = f4Render(f4TakipVerisi(), f4TrenVerisi());
  const b = f4TrenBloklari(html);
  assert.strictEqual(b.length, 2, 'iki tren başlığı');
  assert.ok(f4Gorunen(b[0].baslik).startsWith('Tren · Per 5 Kas · 2 hayvan · Per 12 Kas: PG günü'), f4Gorunen(b[0].baslik));
  assert.ok(f4Gorunen(b[1].baslik).startsWith('Tren · Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü'), f4Gorunen(b[1].baslik));
  const kartlar = (g) => (g.match(/data-ovs-hayvan="([^"]+)"/g) || []).map((x) => x.split('"')[1]);
  assert.deepStrictEqual(kartlar(b[0].govde), ['h03', 'h04'], 'Per 5 Kas kartları');
  assert.deepStrictEqual(kartlar(b[1].govde).sort(), ['h01', 'h02', 'h5708'], 'Per 12 Kas kartları');
  assert.ok(!html.includes('ovs-tren-uyari'), 'sayılar eşit → uyarı yok');
  // takip satırı eksik üye → görünür uyarı + konsol (sessiz değil)
  const uyarilar = [];
  const veri = f4TakipVerisi();
  veri.satirlar = veri.satirlar.filter((s) => s.hayvan_id !== 'h02');
  const html2 = f4Render(veri, f4TrenVerisi(), { console: { ...console, warn: (...a) => uyarilar.push(a.join(' ')) } });
  const b2 = f4TrenBloklari(html2);
  assert.ok(b2[1].govde.includes('ovs-tren-uyari'), 'kart sayısı ≠ uyeler.length → görünür uyarı');
  assert.ok(f4Gorunen(b2[1].govde).includes('A02'), 'eksik üyenin küpesi uyarıda');
  assert.strictEqual(uyarilar.length, 1, 'konsol uyarısı bir kez');
});

test('aşama 0 üye trende kart + Sonraki trene aktar, S3\'te tekrar yok', () => {
  const html = f4Render(f4TakipVerisi(), f4TrenVerisi());
  const b = f4TrenBloklari(html);
  const kart01 = b[1].govde.split('data-ovs-hayvan="h01"')[1].split('data-ovs-hayvan=')[0];
  assert.ok(f4Gorunen(kart01).includes('A01'), 'kartta küpe');
  assert.ok(f4Gorunen(kart01).includes('Başlamadı: Sonraki trene aktar → Per 19 Kas'), f4Gorunen(kart01));
  const s3 = html.split('S3 · Başlatılmayı bekleyenler')[1] || '';
  assert.ok(s3.includes('A08'), 'trende olmayan bekleyen S3\'te kalır');
  for (const k of ['A01', 'A02', 'A5708']) assert.ok(!s3.includes(k), k + ' S3\'te tekrar görünmemeli');
  // bayrak kapalı: eski S3 aynen (tüm bekleyenler)
  const eski = f4Render(f4TakipVerisi(), { aktif: false });
  const s3e = eski.split('S3 · Başlatılmayı bekleyenler')[1] || '';
  for (const k of ['A01', 'A02', 'A5708', 'A08']) assert.ok(s3e.includes(k), 'kapalı yolda ' + k + ' S3\'te');
});

// Basit div ağacı: verilen sınıflı her öğenin atası .ovs-kart mı
function f4KartDisi(html, siniflar) {
  const yigin = []; const disarida = [];
  const re = /<(\/?)(div|span)\b([^>]*)>/g; let m;
  while ((m = re.exec(html))) {
    const kapanis = m[1] === '/'; const etiket = m[2];
    const sinif = ((m[3].match(/class="([^"]*)"/) || [])[1] || '').split(/\s+/);
    if (!kapanis && siniflar.some((s) => sinif.includes(s)) && !yigin.some((c) => c.includes('ovs-kart'))) {
      disarida.push(sinif.join(' ') + ' @' + m.index);
    }
    if (etiket !== 'div') continue;
    if (kapanis) yigin.pop(); else yigin.push(sinif);
  }
  return disarida;
}

test('aksiyon kart içinde, yetim satır yok', () => {
  const html = f4Render(f4TakipVerisi(), f4TrenVerisi());
  assert.ok(html.includes('class="ovs-asama"'), 'aksiyon satırı üretildi');
  assert.deepStrictEqual(f4KartDisi(html, ['ovs-asama', 'ovs-asama-etiket', 'ovs-bagimsiz-alt']), [],
    'aksiyon/alt satır kart dışında kaldı');
  // ub2 fikstürü (S0 + aşama 2 PG+48 satırı) de aynı kural
  const html2 = ub2Render(ub2TakipVerisi(), ub2TrenVerisi());
  assert.deepStrictEqual(f4KartDisi(html2, ['ovs-asama', 'ovs-asama-etiket', 'ovs-bagimsiz-alt']), []);
});

test('düzenle linki görev sheet açmaz', () => {
  const { ctx, gidilen } = ub3UiCtx();
  const acilan = [];
  const dugme = { dataset: { ovtAksiyon: 'DUZENLE', hayvan: 'h36' },
    getAttribute: (a) => (a === 'data-ovt-aksiyon' ? 'DUZENLE' : null) };
  dugme.closest = (sel) => (/data-ovt-aksiyon/.test(sel) ? dugme : null);
  const gorevKarti = { onclick: () => acilan.push('gorev-sheet') };
  const ev = { target: dugme, durdu: false, engel: false,
    stopPropagation() { this.durdu = true; }, preventDefault() { this.engel = true; } };
  // Tarayıcı sırası: document capture → hedef/kart (bubble, satır içi onclick) → document bubble
  ctx._ovsyncDuzenleYakala(ev);
  if (!ev.durdu) gorevKarti.onclick(ev);
  if (!ev.durdu) ctx._ovsyncTrenAksiyonTikla(ev);
  assert.deepStrictEqual(acilan, [], 'görev alt sayfası AÇILMAMALI');
  assert.ok(ev.engel, 'varsayılan engellenmeli');
  assert.deepStrictEqual(gidilen, ['ovsync'], 'Ovsync ekranına gidilmeli (bir kez)');
  assert.strictEqual(vm.runInContext('window._ovsyncOdakHayvan', ctx), 'h36');
  // başka tıklama yakalanmaz
  const ev2 = { target: { closest: () => null }, durdu: false, stopPropagation() { this.durdu = true; } };
  ctx._ovsyncDuzenleYakala(ev2);
  assert.strictEqual(ev2.durdu, false, 'DUZENLE dışı tıklama durdurulmaz');
  // capture fazında bağlanır (kartın onclick'inden önce)
  assert.match(fs.readFileSync(path.join(REPO_ROOT, 'js/ui.js'), 'utf8'),
    /addEventListener\('click',_ovsyncDuzenleYakala,true\)/);
});

test('odak hayvana kaydırır ve temizlenir', () => {
  const { ctx } = ub3UiCtx();
  const kaydirilan = []; const vurgu = [];
  const kart = (h) => {
    const bas = { classList: { add: (c) => vurgu.push(h + ':' + c), remove: () => {} } };
    return { getAttribute: (a) => (a === 'data-ovs-hayvan' ? h : null),
      scrollIntoView: (o) => kaydirilan.push(h + ':' + (o && o.block)), querySelector: () => bas };
  };
  const kok = { querySelectorAll: (s) => (s === '[data-ovs-hayvan]' ? [kart('h01'), kart('h02')] : []) };
  vm.runInContext('window._ovsyncOdakHayvan = "h02"', ctx);
  assert.strictEqual(ctx._ovsyncOdakTuket(kok), true);
  assert.deepStrictEqual(kaydirilan, ['h02:center'], 'yalnız odak hayvanın kartı kaydırılır');
  assert.deepStrictEqual(vurgu, ['h02:ovs-odak'], 'kart başlığı yazı rengiyle vurgulanır');
  assert.strictEqual(vm.runInContext('window._ovsyncOdakHayvan', ctx), null, 'değişken tüketilir');
  // ikinci çağrı: odak yok → hiçbir şey yapılmaz
  assert.strictEqual(ctx._ovsyncOdakTuket(kok), false);
  assert.deepStrictEqual(kaydirilan, ['h02:center']);
  // kart yoksa da temizlenir
  vm.runInContext('window._ovsyncOdakHayvan = "h99"', ctx);
  assert.strictEqual(ctx._ovsyncOdakTuket(kok), false);
  assert.strictEqual(vm.runInContext('window._ovsyncOdakHayvan', ctx), null);
  // tüketici render sonrası çağrılır; tren kartları hayvan kimliği taşır
  assert.match(extractFunctionSource('js/ui.js', 'loadOvsyncDash'), /_ovsyncOdakTuket\(root\)/);
  assert.ok(f4Render(f4TakipVerisi(), f4TrenVerisi()).includes('data-ovs-hayvan="h03"'));
});
