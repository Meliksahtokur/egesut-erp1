// tests/unit/ileri-gebe-duve-siralama.test.js
// _dashIleriGebeBandi — 🤰 İleri Gebeler bandında düve sıralama/renk (K2.1-K2.5, F1 EK).
// Düve ayrımı yalnız grup adından; sıra: inekler (gün DESC) → kuruya alınmış
// düveler mavi D-n (gün DESC) → kuruya alınmamış düveler en altta sarı (.duve, gün DESC).
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const { sandbox } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror },
  expose: [],
});
const { _dashIleriGebeBandi } = sandbox;

const satirlar = (html) => html.split(/<div class="arow(?=[\s"])/).slice(1);
// Satırdaki küpe nosunu bul (fikstür küpeleri benzersizdir).
const kupeOf = (row, kupeler) => kupeler.find((k) => row.includes(`>${k}<`));

// RPC sırası (gebelik_gun DESC): 8 Sağmal(Kuru) + araya serpili 3 'Düve (Büyük)'
// 207/206/201 + 2 Sağmal(Laktasyonda) 903/175 = 13 satır.
const G13 = [
  { hayvan_id: 'h1', kupe_no: '101', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 250 },
  { hayvan_id: 'h2', kupe_no: '102', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 249 },
  { hayvan_id: 'h3', kupe_no: '103', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 248 },
  { hayvan_id: 'd1', kupe_no: '207', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 247 },
  { hayvan_id: 'h4', kupe_no: '104', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 246 },
  { hayvan_id: 'd2', kupe_no: '206', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 245 },
  { hayvan_id: 'h5', kupe_no: '105', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 244 },
  { hayvan_id: 'd3', kupe_no: '201', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 243 },
  { hayvan_id: 'h6', kupe_no: '106', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 242 },
  { hayvan_id: 'h7', kupe_no: '107', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 241 },
  { hayvan_id: 'h8', kupe_no: '108', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 240 },
  { hayvan_id: 'l1', kupe_no: '903', grup: 'Sağmal (Laktasyonda)', padok: 'Sağmal Padok', gebelik_gun: 239 },
  { hayvan_id: 'l2', kupe_no: '175', grup: 'Sağmal (Laktasyonda)', padok: 'Sağmal Padok', gebelik_gun: 238 },
];
const INEK_SIRA = ['101', '102', '103', '104', '105', '106', '107', '108', '903', '175'];

test('kuruya alınmamış düveler en altta, .duve sınıflı; inek sırası değişmez', () => {
  const html = _dashIleriGebeBandi(G13);
  const rows = satirlar(html);
  assert.equal(rows.length, 13);
  const kupeler = rows.map((r) => kupeOf(r, [...INEK_SIRA, '207', '206', '201']));
  assert.deepEqual(kupeler.slice(0, 10), INEK_SIRA);
  assert.deepEqual(kupeler.slice(10), ['207', '206', '201']);
  assert.ok(rows.slice(10).every((r) => r.startsWith(' duve"')));
  assert.ok(rows.slice(0, 10).every((r) => r.startsWith('"')));
  assert.ok(rows[10].includes('>D-1)</span>'));
  assert.ok(rows[11].includes('>D-2)</span>'));
  assert.ok(rows[12].includes('>D-3)</span>'));
  assert.ok(rows[0].includes('>1)</span>') && rows[9].includes('>10)</span>'));
});

test('kırmızı Transfer uyarısı aynen kalır (inek + sarı düve çakışması okunur)', () => {
  const html = _dashIleriGebeBandi(G13);
  const rows = satirlar(html);
  const r903 = rows.find((r) => r.includes('>903<'));
  assert.ok(r903.includes('🔴 Transfer!'));
  const clash = _dashIleriGebeBandi([
    { hayvan_id: 'dx', kupe_no: '299', grup: 'Düve (Büyük)', padok: 'Sağmal Padok', gebelik_gun: 244 },
  ]);
  const drow = satirlar(clash)[0];
  assert.ok(drow.includes('🔴 Transfer!'));
  assert.ok(drow.startsWith(' duve"'));
});

test('F1-EK kuruya alınmış düve inek bloğundan ÇIKAR, listenin sonunda mavi D-n', () => {
  const girdi = [
    { hayvan_id: 'h1', kupe_no: '101', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 250 },
    { hayvan_id: 'g1', kupe_no: '501', grup: 'Gebe Düve', padok: 'Kuru/Gebe Padok', gebelik_gun: 249 },
    { hayvan_id: 'h2', kupe_no: '102', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 248 },
    { hayvan_id: 'p1', kupe_no: '502', grup: 'Düve (Büyük)', padok: 'Kuru/Gebe Padok', gebelik_gun: 247 },
    { hayvan_id: 'h3', kupe_no: '103', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 246 },
  ];
  const html = _dashIleriGebeBandi(girdi);
  const rows = satirlar(html);
  assert.equal(rows.length, 5);
  // EK: inekler (gün DESC) → kuru düveler (gün DESC). 501/502 inek bloğunda DEĞİL.
  assert.deepEqual(rows.map((r) => kupeOf(r, ['101', '501', '102', '502', '103'])),
    ['101', '102', '103', '501', '502']);
  const kuruRows = [rows[3], rows[4]];
  assert.ok(kuruRows.every((r) => r.includes('duve-kuru')), 'iki kuru düve de mavi sınıflı');
  assert.ok(rows[3].includes('>D-1)</span>') && rows[4].includes('>D-2)</span>'), 'ekran sırasına göre D-1/D-2');
  assert.ok(rows[3].startsWith('"') && rows[4].startsWith('"'), 'kuru düve sarı satır DEĞİL');
  // İnek sayacı değişmez: kuru düve inek numarası tüketmez.
  assert.ok(rows[0].includes('>1)</span>') && rows[1].includes('>2)</span>') && rows[2].includes('>3)</span>'));
});

test('Transfer uyarısız düve satırında inline kırmızı zemin YOK, sarı class VAR', () => {
  const html = _dashIleriGebeBandi([
    { hayvan_id: 'd1', kupe_no: '207', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 247 },
  ]);
  const rows = satirlar(html);
  assert.equal(rows.length, 1);
  assert.ok(rows[0].startsWith(' duve"'), 'sarı satır class’ı');
  assert.ok(!rows[0].includes('background:rgba(239,68,68,.04)'), 'inline kırmızı zemin yok');
});

test('Transfer uyarılı düve satırında kırmızı zemin VAR + kırmızı chip VAR', () => {
  const html = _dashIleriGebeBandi([
    { hayvan_id: 'g1', kupe_no: '501', grup: 'Gebe Düve', padok: 'Sağmal Padok', gebelik_gun: 249 },
  ]);
  const rows = satirlar(html);
  assert.equal(rows.length, 1);
  assert.ok(rows[0].includes('background:rgba(239,68,68,.04)'), 'kırmızı zemin aynen');
  assert.ok(rows[0].includes('🔴 Transfer!'), 'kırmızı chip görünür');
  assert.ok(rows[0].includes('duve-kuru'), 'kuru düve mavi numaralı');
});

test('F1-EK karışık: inekler → kuru düve D-1 mavi → sarı düveler D-2/D-3', () => {
  const girdi = [
    { hayvan_id: 'h1', kupe_no: '101', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 250 },
    { hayvan_id: 'g1', kupe_no: '501', grup: 'Gebe Düve', padok: 'Kuru/Gebe Padok', gebelik_gun: 249 },
    { hayvan_id: 'h2', kupe_no: '102', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 248 },
    { hayvan_id: 'd1', kupe_no: '207', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 247 },
    { hayvan_id: 'd2', kupe_no: '206', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 246 },
    { hayvan_id: 'h3', kupe_no: '103', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 245 },
  ];
  const html = _dashIleriGebeBandi(girdi);
  const rows = satirlar(html);
  assert.equal(rows.length, 6);
  assert.deepEqual(rows.map((r) => kupeOf(r, ['101', '501', '102', '207', '206', '103'])),
    ['101', '102', '103', '501', '207', '206']);
  // F1-EK: ekran sırası — kuru düve D-1 (mavi, inek bloğundan sonra), sarılar D-2/D-3.
  assert.ok(rows[3].startsWith('"') && rows[3].includes('duve-kuru'));
  assert.ok(rows[3].includes('>D-1)</span>'));
  assert.ok(rows[4].startsWith(' duve"') && rows[5].startsWith(' duve"'));
  assert.ok(rows[4].includes('>D-2)</span>') && rows[5].includes('>D-3)</span>'));
  assert.ok(rows[0].includes('>1)</span>') && rows[1].includes('>2)</span>') && rows[2].includes('>3)</span>'));
});

test('boş kümede bant yok', () => {
  assert.equal(_dashIleriGebeBandi([]), '');
  assert.equal(_dashIleriGebeBandi(null), '');
});

// F1-EK: 999 (Gebe Düve, mavi) inek bloğunda DEĞİL — son inek (154) ile 207 arasında,
// ekran sırasına göre D-1; 207/206/201 sarı D-2/D-3/D-4. İnek sayacı değişmez.
test('F1-EK 999 inek bloğundan çıkar: son inek ile 207 arasında D-1 mavi', () => {
  const girdi = [
    { hayvan_id: 'h1', kupe_no: '163', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 282 },
    { hayvan_id: 'h2', kupe_no: '182', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 260 },
    { hayvan_id: 'g9', kupe_no: '999', grup: 'Gebe Düve', padok: 'Kuru/Gebe Padok', gebelik_gun: 255 },
    { hayvan_id: 'h3', kupe_no: '155', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 248 },
    { hayvan_id: 'd1', kupe_no: '207', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 247 },
    { hayvan_id: 'd2', kupe_no: '206', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 246 },
    { hayvan_id: 'd3', kupe_no: '201', grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)', gebelik_gun: 240 },
    { hayvan_id: 'h4', kupe_no: '154', grup: 'Sağmal (Kuru)', padok: 'Kuru/Gebe Padok', gebelik_gun: 238 },
  ];
  const html = _dashIleriGebeBandi(girdi);
  const rows = satirlar(html);
  assert.equal(rows.length, 8);
  // Ekran sırası: inekler (gün DESC) → 999 mavi → sarılar (gün DESC).
  assert.deepEqual(rows.map((r) => kupeOf(r, ['163', '182', '999', '155', '154', '207', '206', '201'])),
    ['163', '182', '155', '154', '999', '207', '206', '201']);
  const rowOf = (k) => rows.find((r) => r.includes(`>${k}<`));
  const idx = (k) => rows.findIndex((r) => r.includes(`>${k}<`));
  // 999 son inekten SONRA, ilk sarıdan ÖNCE.
  assert.ok(idx('999') > idx('154'), '999 son ineğin altında');
  assert.ok(idx('999') < idx('207'), '999 ilk sarının üstünde');
  assert.ok(rowOf('999').includes('duve-kuru'), '999 mavi sınıflı');
  assert.ok(rowOf('999').startsWith('"'), '999 sarı satır DEĞİL');
  assert.ok(rowOf('999').includes('>D-1)</span>'), '999 ekran sırasında D-1');
  assert.ok(rowOf('207').includes('>D-2)</span>'), 'alttaki ilk düve D-2');
  assert.ok(rowOf('206').includes('>D-3)</span>'), 'alttaki ikinci düve D-3');
  assert.ok(rowOf('201').includes('>D-4)</span>'), 'alttaki üçüncü düve D-4');
  // İnek sayacı değişmez: 163→1, 182→2, 155→3, 154→4.
  assert.ok(rowOf('163').includes('>1)</span>'));
  assert.ok(rowOf('182').includes('>2)</span>'));
  assert.ok(rowOf('155').includes('>3)</span>'));
  assert.ok(rowOf('154').includes('>4)</span>'));
});

// F1.1/F1.2: sarı şerit + koyu-tema override kuralları index.html'de.
test('F1.1 düve satırı sarı şeritli: .arow.duve kuralı ≥4px --amber sol şerit', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const css = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
  assert.ok(css.includes('.arow.duve'), '.arow.duve kuralı var');
  const sariKural = css.match(/\.arow\.duve\s*\{[^}]*\}/);
  assert.ok(sariKural, '.arow.duve kural bloğu bulunur');
  assert.ok(/border-left\s*:[^;}]*var\(--amber\)/.test(sariKural[0]), 'sol şerit --amber');
  const px = sariKural[0].match(/border-left\s*:\s*(\d+)px/);
  assert.ok(px && Number(px[1]) >= 4, 'şerit genişliği ≥4px');
  assert.ok(css.includes('body.dark .arow.duve'), 'koyu tema sarı zemin override var');
});

test('F1.2 koyu temada mavi D-n: body.dark .arow-no.duve-kuru kuralı #8ec6ff', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const css = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
  assert.ok(css.includes('body.dark .arow-no.duve-kuru'), 'koyu tema mavi numara override var');
  const kural = css.match(/body\.dark\s+\.arow-no\.duve-kuru\s*\{[^}]*\}/);
  assert.ok(kural, 'body.dark .arow-no.duve-kuru kural bloğu bulunur');
  assert.ok(kural[0].toLowerCase().includes('#8ec6ff'), 'kontrast rengi #8ec6ff');
});
