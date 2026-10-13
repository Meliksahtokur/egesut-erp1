// tests/unit/ileri-gebe-duve-siralama.test.js
// _dashIleriGebeBandi — 🤰 İleri Gebeler bandında düve sıralama/renk (K2.1-K2.5).
// Düve ayrımı yalnız grup adından; kuruya alınmamış düveler en altta sarı (.duve),
// kuruya alınmış düve inek bloğunda yerinde ve numarası mavi (.duve-kuru).
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

test('kuruya alınmış düve inek bloğunda yerinde, numarası mavi sınıflı', () => {
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
  // Yerinde: RPC sırası korunur (stabil partition kuruya alınmışı oynatmaz).
  assert.deepEqual(rows.map((r) => kupeOf(r, ['101', '501', '102', '502', '103'])),
    ['101', '501', '102', '502', '103']);
  const kuruRows = [rows[1], rows[3]];
  assert.ok(kuruRows.every((r) => r.includes('duve-kuru')), 'iki kuru düve de mavi sınıflı');
  assert.ok(kuruRows.every((r) => /D-\d+\)/.test(r)), 'kuru düve D-n alır');
  assert.ok(rows[1].startsWith('"') && rows[3].startsWith('"'), 'kuru düve sarı satır DEĞİL');
  assert.ok(rows[0].includes('>1)</span>') && rows[2].includes('>2)</span>') && rows[4].includes('>3)</span>'));
});

test('boş kümede bant yok', () => {
  assert.equal(_dashIleriGebeBandi([]), '');
  assert.equal(_dashIleriGebeBandi(null), '');
});
