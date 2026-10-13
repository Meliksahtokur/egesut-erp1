// tests/unit/ileri-gebe-duve-siralama.test.js
// _dashIleriGebeBandi — 🤰 İleri Gebeler bandında düve görünümü/sıralama (F2).
// SAHİP NİHAİ KURALI (F2): satır zemini/sol şerit YOK (ineklerle aynı satır);
// TÜM düvelerde mavi D-n (.duve-mavi) + amber alt satır (.duve-alt, .arow-sub);
// sıra: kuruya alınmış düve RPC yerinde (ineklerle aynı blok), kuruya
// alınmamış düveler en altta gruplu (gün DESC); D sayacı ekran sırasına göre.
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

test('F2 kuruya alınmamış düveler en altta gruplu (gün DESC); inek sırası RPC aynen', () => {
  const html = _dashIleriGebeBandi(G13);
  const rows = satirlar(html);
  assert.equal(rows.length, 13);
  const kupeler = rows.map((r) => kupeOf(r, [...INEK_SIRA, '207', '206', '201']));
  assert.deepEqual(kupeler.slice(0, 10), INEK_SIRA);
  assert.deepEqual(kupeler.slice(10), ['207', '206', '201']);
  assert.ok(rows[10].includes('>D-1)</span>'));
  assert.ok(rows[11].includes('>D-2)</span>'));
  assert.ok(rows[12].includes('>D-3)</span>'));
  assert.ok(rows[0].includes('>1)</span>') && rows[9].includes('>10)</span>'));
});

test('F2 düve satırında zemin/şerit sınıfı YOK: tüm satırlar inekle aynı class', () => {
  const html = _dashIleriGebeBandi(G13);
  const rows = satirlar(html);
  assert.ok(rows.every((r) => r.startsWith('"')), 'hiçbir satırda ek row class yok');
  assert.ok(!html.includes(' duve"'), 'sarı .duve satır class’ı yok');
  assert.ok(!html.includes('duve-kuru'), 'eski kuru class’ı yok');
});

test('F2 TÜM düvelerde mavi numara (duve-mavi) + amber alt satır (duve-alt)', () => {
  const html = _dashIleriGebeBandi(G13);
  const rows = satirlar(html);
  const duveRows = rows.slice(10);
  assert.ok(duveRows.every((r) => r.includes('arow-no duve-mavi')),
    'alttaki tüm düvelerde mavi numara sınıfı');
  assert.ok(duveRows.every((r) => r.includes('arow-sub duve-alt')),
    'alttaki tüm düvelerde amber alt satır sınıfı');
  assert.ok(rows.slice(0, 10).every((r) => !r.includes('duve-mavi')),
    'inek numarasında mavi sınıf yok');
  assert.ok(rows.slice(0, 10).every((r) => !r.includes('duve-alt')),
    'inek alt satırında amber sınıf yok');
});

test('F2 kuru düve RPC yerinde: ineklerle aynı blok, sıra değişmez', () => {
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
  // F2: kuru düveler RPC yerinde — bloktan ÇIKARILMAZ, alta atılmaz.
  assert.deepEqual(rows.map((r) => kupeOf(r, ['101', '501', '102', '502', '103'])),
    ['101', '501', '102', '502', '103']);
  assert.ok(rows[1].includes('arow-no duve-mavi'), 'yerindeki kuru düvede mavi numara');
  assert.ok(rows[3].includes('arow-no duve-mavi'), 'yerindeki ikinci kuru düvede mavi numara');
  assert.ok(rows[1].includes('arow-sub duve-alt'), 'yerindeki kuru düvede amber alt satır');
  assert.ok(rows[3].includes('arow-sub duve-alt'), 'yerindeki ikinci kuru düvede amber alt satır');
  assert.ok(rows.every((r) => r.startsWith('"')), 'kuru düve satırı da inekle aynı class');
  // Ekran sırasına göre sayaç: 501 üstte D-1, 502 altta D-2.
  assert.ok(rows[1].includes('>D-1)</span>') && rows[3].includes('>D-2)</span>'));
  // İnek sayacı değişmez: kuru düve inek numarası tüketmez.
  assert.ok(rows[0].includes('>1)</span>') && rows[2].includes('>2)</span>') && rows[4].includes('>3)</span>'));
});

test('F2 999 RPC yerinde: 182 ile 155 arasında D-1 mavi; alttakiler D-2/D-3/D-4', () => {
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
  // F2 ekran sırası: ana blok RPC aynen → 999 yerinde; altta sarılar (gün DESC).
  assert.deepEqual(rows.map((r) => kupeOf(r, ['163', '182', '999', '155', '154', '207', '206', '201'])),
    ['163', '182', '999', '155', '154', '207', '206', '201']);
  const rowOf = (k) => rows.find((r) => r.includes(`>${k}<`));
  const idx = (k) => rows.findIndex((r) => r.includes(`>${k}<`));
  assert.ok(idx('999') === 2, '999 RPC yerinde (182 ile 155 arasında)');
  assert.ok(rowOf('999').includes('arow-no duve-mavi'), '999 mavi numaralı');
  assert.ok(rowOf('999').includes('arow-sub duve-alt'), '999 amber alt satırlı');
  assert.ok(rowOf('999').startsWith('"'), '999 satırı inekle aynı class');
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

test('F2 kırmızı Transfer uyarısı aynen kalır (inek + düve; satır class’ı aynı)', () => {
  const html = _dashIleriGebeBandi(G13);
  const rows = satirlar(html);
  const r903 = rows.find((r) => r.includes('>903<'));
  assert.ok(r903.includes('🔴 Transfer!'));
  assert.ok(r903.includes('background:rgba(239,68,68,.04)'), 'inek Transfer satırında kırmızı zemin');
  const clash = _dashIleriGebeBandi([
    { hayvan_id: 'dx', kupe_no: '299', grup: 'Düve (Büyük)', padok: 'Sağmal Padok', gebelik_gun: 244 },
  ]);
  const drow = satirlar(clash)[0];
  assert.ok(drow.includes('🔴 Transfer!'), 'düve Transfer chip’i var');
  assert.ok(drow.includes('background:rgba(239,68,68,.04)'), 'düve Transfer satırında kırmızı zemin (ineklerle aynı)');
  assert.ok(drow.startsWith('"'), 'Transfer’li düve satırı da inekle aynı class');
  assert.ok(drow.includes('arow-no duve-mavi'), 'Transfer’li düvede de mavi numara');
  assert.ok(drow.includes('arow-sub duve-alt'), 'Transfer’li düvede de amber alt satır');
});

test('F2 Transfer uyarısız düve satırında inline kırmızı zemin YOK', () => {
  const html = _dashIleriGebeBandi([
    { hayvan_id: 'd1', kupe_no: '207', grup: 'Düve (Büyük)', padok: 'Kuru/Gebe Padok', gebelik_gun: 247 },
  ]);
  const rows = satirlar(html);
  assert.equal(rows.length, 1);
  assert.ok(!rows[0].includes('background:rgba(239,68,68,.04)'), 'inline kırmızı zemin yok');
  assert.ok(rows[0].startsWith('"'), 'satır class’ı inekle aynı');
  assert.ok(rows[0].includes('arow-no duve-mavi'), 'mavi numara');
  assert.ok(rows[0].includes('arow-sub duve-alt'), 'amber alt satır');
});

test('boş kümede bant yok', () => {
  assert.equal(_dashIleriGebeBandi([]), '');
  assert.equal(_dashIleriGebeBandi(null), '');
});

// F2.1: satır zemini/sol şerit TAMAMEN kalktı — .arow.duve kuralı yok.
test('F2.1 satır zemini/sol şerit YOK: index.html’de .arow.duve kuralı bulunmaz', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const css = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
  assert.ok(!css.includes('.arow.duve'), '.arow.duve kuralı kalktı');
});

// F2.2: TÜM düvelerde mavi D-n — .arow-no.duve-mavi var(--blue), koyu temada #8ec6ff.
test('F2.2 mavi D-n: .arow-no.duve-mavi var(--blue), body.dark #8ec6ff', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const css = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
  const kural = css.match(/\.arow-no\.duve-mavi\s*\{[^}]*\}/);
  assert.ok(kural, '.arow-no.duve-mavi kural bloğu bulunur');
  assert.ok(kural[0].includes('var(--blue)'), 'açık tema mavi var(--blue)');
  assert.ok(css.includes('body.dark .arow-no.duve-mavi'), 'koyu tema mavi numara override var');
  const dark = css.match(/body\.dark\s+\.arow-no\.duve-mavi\s*\{[^}]*\}/);
  assert.ok(dark, 'body.dark .arow-no.duve-mavi kural bloğu bulunur');
  assert.ok(dark[0].toLowerCase().includes('#8ec6ff'), 'kontrast rengi #8ec6ff');
});

// F2.3: TÜM düvelerde amber alt satır — .arow-sub.duve-alt var(--amber), zemin yok.
test('F2.3 amber alt satır: .arow-sub.duve-alt yazı rengi var(--amber), zemin yok', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const css = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
  const kural = css.match(/\.arow-sub\.duve-alt\s*\{[^}]*\}/);
  assert.ok(kural, '.arow-sub.duve-alt kural bloğu bulunur');
  assert.ok(/color\s*:[^;}]*var\(--amber\)/.test(kural[0]), 'yazı rengi --amber');
  assert.ok(!/background/.test(kural[0]), 'zemin yok');
});

// F2.4: ?v= tek değer 20261013-03.
test('F2.4 ?v= tek değer 20261013-03', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const html = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
  const tum = [...html.matchAll(/\?v=([0-9-]+)/g)].map((m) => m[1]);
  assert.ok(tum.length > 0, '?v= damgası var');
  assert.ok(tum.every((v) => v === '20261013-03'), `tek değer 20261013-03 (bulunan: ${[...new Set(tum)]})`);
});
