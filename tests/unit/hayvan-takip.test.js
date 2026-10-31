// tests/unit/hayvan-takip.test.js — Hayvan Takip F1: veri katmanı ve saf yardımcılar.
// Yükleyiciler test içinde çağrılır: sembol eksikken dosya değil ilgili test kırmızı olur.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadBrowserModule, loadExtractedFunction } = require('./support/loadModule.js');
const { fmtTarih, getDisplayKupe, kuceDogalKarsilastir } = require('../../js/utils/helpers.js');

const REPO_ROOT = path.join(__dirname, '..', '..');
const RPC_MIGRATION = 'supabase/migrations/20261031200002_hayvan_takip_rpc.sql';
const ETIKET_MIGRATION = 'supabase/migrations/20261031200004_hayvan_takip_halsizlik_etiket.sql';
const RPC_LERI = ['hayvan_takip_ac', 'hayvan_takip_kapat', 'hayvan_takip_muayene_planla', 'hayvan_takip_muayene_sonuc'];

// helpers.js esc()'inin saf aynası (ui-pure.test.js deseni; asıl esc DOM ister).
const escMirror = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = s => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const duz = v => JSON.parse(JSON.stringify(v));
const gunOnce = n => new Date(Date.now() - n * 86400000).toISOString();

function config() {
  return loadBrowserModule('js/config.js', { expose: ['HAYVAN_TAKIP_GOREV_TIPI', 'HAYVAN_TAKIP_SEBEPLER'] }).exposed;
}

function ht(extra = {}) {
  return loadBrowserModule('js/hayvan-takip.js', {
    expose: ['HT_HATA_METINLERI'],
    extra: {
      HAYVAN_TAKIP_SEBEPLER: config().HAYVAN_TAKIP_SEBEPLER,
      HAYVAN_TAKIP_GOREV_TIPI: config().HAYVAN_TAKIP_GOREV_TIPI,
      _istanbulGunNo: loadExtractedFunction('js/utils/helpers.js', '_istanbulGunNo'),
      band: loadExtractedFunction('js/ui.js', 'band'),
      esc: escMirror,
      escAttr: escAttrMirror,
      fmtTarih,
      getDisplayKupe,
      kuceDogalKarsilastir,
      getUserMessage: e => 'JENERIK:' + (e?.message || String(e)),
      ...extra,
    },
  });
}

function api() {
  const fromCagrilari = [];
  const onCagrilari = [];
  const secimler = [];
  const zincir = {
    select: arg => { secimler.push(arg); return zincir; },
    eq: () => zincir, gte: () => zincir, order: () => zincir, limit: () => zincir, range: () => zincir,
    then: (res, rej) => Promise.resolve({ data: [], error: null }).then(res, rej),
  };
  const kanal = {
    on: (olay, filtre, cb) => { onCagrilari.push({ olay, filtre, cb }); return kanal; },
    subscribe: () => kanal,
  };
  const client = {
    from: t => { fromCagrilari.push(t); return zincir; },
    channel: () => kanal,
    rpc: async () => ({ data: null, error: null }),
  };
  const yuklu = loadBrowserModule('js/api.js', {
    expose: ['TABLES', 'DB_VER', 'RPC_TABLES', 'REALTIME_TABLES', 'RPC_MAP'],
    extra: {
      supabase: { createClient: () => client },
      navigator: { onLine: true, userAgent: 'node-test' },
    },
  });
  return { ...yuklu, fromCagrilari, onCagrilari, secimler };
}

// ── HT-S-01 ──
test('HT-S-01: gün sayısı İstanbul takvim gününe göre, UTC gününe kaymaz', () => {
  const { sandbox: s } = ht();
  assert.strictEqual(s.htGunSayisi('2026-10-30T21:30:00Z', '2026-10-31'), 0);
  assert.strictEqual(s.htGunSayisi('2026-10-30T20:59:00Z', '2026-10-31'), 1);
});

test('HT-S-01b: bugün verilmezse şimdiki gün; gelecek ve bozuk girdi 0', () => {
  const { sandbox: s } = ht();
  assert.strictEqual(s.htGunSayisi(new Date().toISOString()), 0);
  assert.strictEqual(s.htGunSayisi(gunOnce(4)), 4);
  assert.strictEqual(s.htGunSayisi('2026-11-05T10:00:00Z', '2026-10-31'), 0);
  assert.strictEqual(s.htGunSayisi('bozuk', '2026-10-31'), 0);
  assert.strictEqual(s.htGunSayisi(null, '2026-10-31'), 0);
});

// ── htAcikTakipler ──
test('HT-S-14: htAcikTakipler yalnız kapanis_tarihi boş olanları, istenirse tek hayvanı verir', () => {
  const { sandbox: s } = ht();
  const liste = [
    { id: 'a', hayvan_id: 'H1', kapanis_tarihi: null },
    { id: 'b', hayvan_id: 'H1', kapanis_tarihi: '2026-10-30T10:00:00Z' },
    { id: 'c', hayvan_id: 'H2' },
  ];
  assert.deepStrictEqual(duz(s.htAcikTakipler(liste)).map(t => t.id), ['a', 'c']);
  assert.deepStrictEqual(duz(s.htAcikTakipler(liste, 'H1')).map(t => t.id), ['a']);
  assert.deepStrictEqual(duz(s.htAcikTakipler(null)), []);
});

// ── HT-S-02 ──
test('HT-S-02: en eski açık takibi olan hayvan üstte, satır içi eski önce, eşitlikte küpe', () => {
  const { sandbox: s } = ht();
  const animals = [
    { id: 'H1', kupe_no: '100', durum: 'Aktif' },
    { id: 'H2', kupe_no: '20', durum: 'Aktif' },
    { id: 'H3', kupe_no: '9', durum: 'Aktif' },
  ];
  const takipler = [
    { id: 't1', hayvan_id: 'H1', sebep_kodu: 'ZAYIFLAMA', acilis_tarihi: '2026-10-29T10:00:00Z' },
    { id: 't2', hayvan_id: 'H1', sebep_kodu: 'TOPALLIK', acilis_tarihi: '2026-10-20T10:00:00Z' },
    { id: 't3', hayvan_id: 'H2', sebep_kodu: 'TOPALLIK', acilis_tarihi: '2026-10-10T10:00:00Z' },
    { id: 't4', hayvan_id: 'H3', sebep_kodu: 'TOPALLIK', acilis_tarihi: '2026-10-10T10:00:00Z' },
  ];
  const satirlar = duz(s.htDashSatirlari(takipler, animals));
  assert.deepStrictEqual(satirlar.map(x => x.hayvan_id), ['H3', 'H2', 'H1'], '20 ve 9 eşit: küpe doğal sıra');
  assert.deepStrictEqual(satirlar[2].sebepler.map(x => x.takip_id), ['t2', 't1']);
  assert.strictEqual(satirlar[2].kupe, '100');
});

test('HT-S-02b: satır biçimi sözleşmedeki alanları taşır, gün hesaplanır', () => {
  const { sandbox: s } = ht();
  const satirlar = duz(s.htDashSatirlari(
    [{ id: 't1', hayvan_id: 'H1', sebep_kodu: 'TOPALLIK', acilis_tarihi: gunOnce(3) }],
    [{ id: 'H1', kupe_no: '100', durum: 'Aktif' }]
  ));
  assert.deepStrictEqual(satirlar, [
    { hayvan_id: 'H1', kupe: '100', sebepler: [{ takip_id: 't1', etiket: 'Topallık', gun: 3 }] },
  ]);
});

// ── HT-S-03 ──
test('HT-S-03: aktif olmayan hayvan ve kapalı takip listelenmez; boş girdi []', () => {
  const { sandbox: s } = ht();
  const animals = [
    { id: 'H1', kupe_no: '1', durum: 'Aktif' },
    { id: 'H2', kupe_no: '2', durum: 'Satıldı' },
  ];
  const takipler = [
    { id: 't1', hayvan_id: 'H1', sebep_kodu: 'TOPALLIK', acilis_tarihi: gunOnce(1), kapanis_tarihi: gunOnce(0) },
    { id: 't2', hayvan_id: 'H2', sebep_kodu: 'TOPALLIK', acilis_tarihi: gunOnce(1) },
    { id: 't3', hayvan_id: 'YOK', sebep_kodu: 'TOPALLIK', acilis_tarihi: gunOnce(1) },
  ];
  assert.deepStrictEqual(duz(s.htDashSatirlari(takipler, animals)), []);
  assert.deepStrictEqual(duz(s.htDashSatirlari([], [])), []);
  assert.deepStrictEqual(duz(s.htDashSatirlari(null, null)), []);
});

// ── HT-S-04 ──
test('HT-S-04: bilinmeyen kod ham görünür, satır gizlenmez; DIGER açıklama gösterir', () => {
  const { sandbox: s } = ht();
  assert.strictEqual(s.htSebepEtiket({ sebep_kodu: 'YENI_KOD' }), 'YENI_KOD');
  assert.strictEqual(s.htSebepEtiket({ sebep_kodu: 'SUT_DUSUSU' }), 'Süt düşüşü');
  assert.strictEqual(s.htSebepEtiket({ sebep_kodu: 'DIGER', aciklama: 'Göz akıntısı' }), 'Göz akıntısı');
  assert.strictEqual(s.htSebepEtiket({ sebep_kodu: 'DIGER', aciklama: '  ' }), 'Diğer');
  const satirlar = duz(s.htDashSatirlari(
    [{ id: 't1', hayvan_id: 'H1', sebep_kodu: 'YENI_KOD', acilis_tarihi: gunOnce(1) }],
    [{ id: 'H1', kupe_no: '1', durum: 'Aktif' }]
  ));
  assert.strictEqual(satirlar[0].sebepler[0].etiket, 'YENI_KOD');
});

// ── HT-S-05, 06, 07 ──
const ORNEK_SATIRLAR = [
  { hayvan_id: 'H1', kupe: '100', sebepler: [{ takip_id: 't1', etiket: 'Topallık', gun: 3 }, { takip_id: 't2', etiket: 'Zayıflama', gun: 1 }] },
  { hayvan_id: 'H2', kupe: '200', sebepler: [{ takip_id: 't3', etiket: 'Süt düşüşü', gun: 0 }] },
];

test('HT-S-05: boş liste band çizmez; başlık hayvan sayısı, satır sebep · gün | sebep · gün, openDet', () => {
  const { sandbox: s } = ht();
  assert.strictEqual(s.htBandHtml([]), '');
  const html = s.htBandHtml(ORNEK_SATIRLAR);
  assert.ok(html.includes('📌 Takipteki hayvanlar (2)'), 'N takip değil hayvan sayısı');
  assert.ok(html.includes('Topallık · 3 gün | Zayıflama · 1 gün'));
  assert.ok(html.includes('>100<'), 'küpe görünür');
  assert.match(html, /data-hid="H1"[^>]*onclick="openDet\(this\.dataset\.hid\)"/);
});

test('HT-S-06: band satırında background yok, başlık aband-hdr takip sınıfı', () => {
  const { sandbox: s } = ht();
  const html = s.htBandHtml(ORNEK_SATIRLAR);
  assert.ok(html.includes('aband-hdr takip'));
  assert.ok(!/background/i.test(html));
});

test('HT-S-07: açıklama ve küpe bandda kaçışlı, hayvan id özniteliği kıramaz', () => {
  const { sandbox: s } = ht();
  const html = s.htBandHtml([{
    hayvan_id: `x"><img src=y>'`,
    kupe: '<b>k</b>',
    sebepler: [{ takip_id: 't', etiket: '<img onerror=x>', gun: 1 }],
  }]);
  assert.ok(!html.includes('<img'), 'etiket ve id kaçışsız değil');
  assert.ok(!html.includes('<b>k'), 'küpe kaçışsız değil');
  assert.ok(html.includes('&lt;img onerror=x&gt;'));
  assert.ok(!html.includes(`x">`), 'id özniteliği kırılmadı');
});

// ── htKartBlokHtml ──
test('HT-S-13: kart bloğu her açık takibi süre ve planlı muayeneyle listeler', () => {
  const { sandbox: s } = ht();
  const takipler = [
    { id: 't2', sebep_kodu: 'ZAYIFLAMA', acilis_tarihi: gunOnce(1) },
    { id: 't1', sebep_kodu: 'TOPALLIK', acilis_tarihi: gunOnce(3) },
  ];
  const gorevler = [
    { id: 'g1', gorev_tipi: 'HAYVAN_TAKIP_MUAYENE', ref_takip_id: 't1', hedef_tarih: '2026-11-03', hedef_saat: '14:30:00' },
  ];
  const html = s.htKartBlokHtml(takipler, gorevler);
  assert.ok(html.includes('Topallık · 3 gün'));
  assert.ok(html.includes('Zayıflama · 1 gün'));
  assert.ok(html.indexOf('Topallık') < html.indexOf('Zayıflama'), 'eski takip önce');
  assert.ok(html.includes('03.11.2026 14:30'));
  assert.ok(!/background/i.test(html));
  assert.strictEqual(s.htKartBlokHtml([], gorevler), '');
});

test('HT-S-13b: kapalı, iptal, başka takibin ya da başka tipin görevi muayene sayılmaz', () => {
  const { sandbox: s } = ht();
  const takip = [{ id: 't1', sebep_kodu: 'TOPALLIK', acilis_tarihi: gunOnce(1) }];
  const gorevler = [
    { gorev_tipi: 'HAYVAN_TAKIP_MUAYENE', ref_takip_id: 't1', hedef_tarih: '2026-11-01', tamamlandi: true },
    { gorev_tipi: 'HAYVAN_TAKIP_MUAYENE', ref_takip_id: 't1', hedef_tarih: '2026-11-02', iptal: true },
    { gorev_tipi: 'HAYVAN_TAKIP_MUAYENE', ref_takip_id: 't9', hedef_tarih: '2026-11-03' },
    { gorev_tipi: 'TAKIP_MUAYENE', ref_takip_id: 't1', hedef_tarih: '2026-11-04' },
  ];
  assert.ok(!/\d{2}\.11\.2026/.test(s.htKartBlokHtml(takip, gorevler)));
  assert.ok(!/\d{2}\.11\.2026/.test(s.htKartBlokHtml(takip, null)));
});

test('HT-S-13c: kart bloğunda açıklama kaçışlı', () => {
  const { sandbox: s } = ht();
  const html = s.htKartBlokHtml([{ id: 't', sebep_kodu: 'DIGER', aciklama: '<img onerror=x>', acilis_tarihi: gunOnce(0) }], []);
  assert.ok(!html.includes('<img'));
  assert.ok(html.includes('&lt;img onerror=x&gt;'));
});

// ── HT-S-08, 09 ──
test('HT-S-08: ön seçim kart+tek → o id; kart+çok → []; vaka → []', () => {
  const { sandbox: s } = ht();
  assert.deepStrictEqual(duz(s.htKapatOnSecim([{ id: 'a' }], 'kart')), ['a']);
  assert.deepStrictEqual(duz(s.htKapatOnSecim([{ id: 'a' }, { id: 'b' }], 'kart')), []);
  assert.deepStrictEqual(duz(s.htKapatOnSecim([{ id: 'a' }], 'vaka')), []);
  assert.deepStrictEqual(duz(s.htKapatOnSecim([], 'kart')), []);
});

test('HT-S-09: varsayılan sonraki tarih +3 gün, ay ve yıl sınırı', () => {
  const { sandbox: s } = ht();
  assert.strictEqual(s.htVarsayilanSonrakiTarih('2026-10-31'), '2026-11-03');
  assert.strictEqual(s.htVarsayilanSonrakiTarih('2026-12-30'), '2027-01-02');
});

function sebepCaseSatirlari(dosya) {
  const sql = fs.readFileSync(path.join(REPO_ROOT, dosya), 'utf8');
  const blok = sql.slice(sql.indexOf('_hayvan_takip_sebep_etiket(p_kod text)'));
  const caseBlok = blok.slice(blok.indexOf('SELECT CASE p_kod'), blok.indexOf('ELSE p_kod'));
  return [...caseBlok.matchAll(/WHEN '([A-Z_]+)' THEN '([^']+)'/g)];
}

// ── HT-S-10 ──
test('HT-S-10: migration CASE kodları config listesinin alt kümesi, etiketler eş (tek yönlü)', () => {
  const { HAYVAN_TAKIP_SEBEPLER, HAYVAN_TAKIP_GOREV_TIPI } = config();
  assert.strictEqual(HAYVAN_TAKIP_GOREV_TIPI, 'HAYVAN_TAKIP_MUAYENE');
  assert.strictEqual(HAYVAN_TAKIP_SEBEPLER.length, 6);
  assert.strictEqual(HAYVAN_TAKIP_SEBEPLER.find(x => x.kod === 'HALSIZLIK')?.ad, 'Halsizlik');
  assert.strictEqual(HAYVAN_TAKIP_SEBEPLER.at(-1).kod, 'DIGER', 'DIGER son kalır');
  const satirlar = sebepCaseSatirlari(ETIKET_MIGRATION);
  assert.strictEqual(satirlar.length, 6, 'CASE ayrıştırıldı');
  for (const [, kod, etiket] of satirlar) {
    const c = HAYVAN_TAKIP_SEBEPLER.find(x => x.kod === kod);
    assert.ok(c, `${kod} config'te yok`);
    assert.strictEqual(c.ad, etiket);
  }
});

// ── HT-S-10b ──
test('HT-S-10b: 200004 yalnız etiket fonksiyonunu değiştirir; 200002 etiketleri ve öznitelikleri aynı', () => {
  const yeni = fs.readFileSync(path.join(REPO_ROOT, ETIKET_MIGRATION), 'utf8');
  const eski = fs.readFileSync(path.join(REPO_ROOT, RPC_MIGRATION), 'utf8');
  const kod = yeni.replace(/^\s*--.*$/gm, '');
  const deyimler = kod.match(/\b(?:CREATE|ALTER|DROP)\b/gi) ?? [];
  assert.strictEqual(deyimler.length, 1, `CREATE|ALTER|DROP deyimleri: ${deyimler}`);
  assert.match(kod, /\bCREATE OR REPLACE FUNCTION public\._hayvan_takip_sebep_etiket\(/);
  const yeniSatirlar = sebepCaseSatirlari(ETIKET_MIGRATION).map(m => [m[1], m[2]]);
  for (const [, k, e] of sebepCaseSatirlari(RPC_MIGRATION)) {
    assert.deepStrictEqual(yeniSatirlar.find(s => s[0] === k), [k, e], `${k} değişmemeli`);
  }
  const oznitelik = s => {
    const bas = s.indexOf('_hayvan_takip_sebep_etiket(p_kod text)');
    return s.slice(bas, s.indexOf('AS $function$', bas));
  };
  assert.strictEqual(oznitelik(yeni), oznitelik(eski));
  assert.match(kod, /ELSE p_kod/);
});

// ── HT-S-12 ──
test('HT-S-12: migration\'daki her HT_ kodu haritada ve jenerik yola düşmez', () => {
  const { sandbox: s, exposed } = ht();
  const sql = fs.readFileSync(path.join(REPO_ROOT, RPC_MIGRATION), 'utf8');
  const kodlar = new Set([...sql.matchAll(/\bHT_[A-Z_]+\b/g)].map(m => m[0]));
  assert.strictEqual(kodlar.size, 15, `kodlar: ${[...kodlar]}`);
  for (const kod of kodlar) {
    assert.ok(exposed.HT_HATA_METINLERI[kod.slice(3)], `${kod} haritada yok`);
    const metin = s.htHataMetni(new Error(kod));
    assert.strictEqual(metin, exposed.HT_HATA_METINLERI[kod.slice(3)]);
  }
});

test('HT-S-12b: HT_GECMIS_TARIH erteleme metnine düşmez, aktif değil jenerik olmaz', () => {
  const { sandbox: s } = ht();
  const gecmis = s.htHataMetni(new Error('HT_GECMIS_TARIH'));
  assert.strictEqual(gecmis, 'Muayene tarihi geçmişte olamaz.');
  assert.ok(!/erteleme/i.test(gecmis));
  assert.strictEqual(s.htHataMetni(new Error('HT_HAYVAN_AKTIF_DEGIL')), 'Hayvan aktif değil.');
  assert.strictEqual(s.htHataMetni('HT_SEBEP_ZATEN_ACIK'), 'Bu sebeple zaten takipte');
});

test('HT-S-12c: bilinmeyen HT_ kodu ayrı metin, HT_ olmayan getUserMessage', () => {
  const { sandbox: s } = ht();
  assert.strictEqual(s.htHataMetni(new Error('HT_X')), 'İşlem reddedildi: HT_X');
  assert.strictEqual(s.htHataMetni(new Error('TAKIP_ACIK: 3')), 'JENERIK:TAKIP_ACIK: 3');
  assert.strictEqual(s.htHataMetni(new Error('SHT_X')), 'JENERIK:SHT_X', 'kelime içi eşleşme yok');
});

test('HT-S-12d: getUserMessage GECMIS_TARIH metnini verse de htHataMetni önce çevirir', () => {
  const { sandbox: s } = ht({ getUserMessage: () => 'Geçmiş tarihe erteleme yapılamaz.' });
  assert.strictEqual(s.htHataMetni(new Error('HT_GECMIS_TARIH')), 'Muayene tarihi geçmişte olamaz.');
});

// ── HT-S-11 ──
test('HT-S-11: api.js haritaları hayvan_takip içerir, RPC_MAP yeni RPC taşımaz', () => {
  const { exposed } = api();
  assert.ok(exposed.TABLES.includes('hayvan_takip'));
  assert.ok(exposed.DB_VER >= 25);
  assert.ok(exposed.REALTIME_TABLES.includes('hayvan_takip'));
  for (const r of RPC_LERI) {
    assert.deepStrictEqual(duz(exposed.RPC_TABLES[r]), ['hayvan_takip', 'gorev_log', 'islem_log'], r);
  }
  const haritaMetni = JSON.stringify(exposed.RPC_MAP);
  for (const r of RPC_LERI) assert.ok(!haritaMetni.includes(r), `${r} RPC_MAP'te olmamalı`);
});

test('HT-S-11b: fetcher tabloyu tümüyle çeker, tarih aralığı yok', () => {
  const src = fs.readFileSync(path.join(REPO_ROOT, 'js/api.js'), 'utf8');
  assert.match(src, /hayvan_takip:\s*\(\)\s*=>\s*db\.from\('hayvan_takip'\)\.select\('\*'\),/);
});

test('HT-S-11c: initRealtime hayvan_takip değişiminde tabloyu çeker, ekranı tazeler', async () => {
  const { sandbox, onCagrilari } = api();
  sandbox.initRealtime();
  const kayit = onCagrilari.find(c => c.filtre.table === 'hayvan_takip');
  assert.ok(kayit, 'hayvan_takip dinleyicisi yok');
  assert.strictEqual(kayit.filtre.event, '*');
  const cekilen = [];
  let cizim = 0;
  sandbox.pullTables = async t => { cekilen.push(...t); };
  sandbox.renderSafe = () => { cizim++; };
  await kayit.cb();
  assert.deepStrictEqual(cekilen, ['hayvan_takip']);
  assert.strictEqual(cizim, 1, 'band tazelenmeli');
});
