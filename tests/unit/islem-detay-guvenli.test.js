// tests/unit/islem-detay-guvenli.test.js
// L4-W5 onarım turu L4-07 — işlem detay ve Değişiklikler render'ında
// stored-XSS + ham UUID sızıntısının ADVERSARIAL birim testleri.
//
// Sözleşme (onarım turu sözleşmesi md.7):
//   1. _openIslemDetayRow payload değerleri esc()'li — <img onerror> payload'ı
//      html üretmez (luna L4-07: `${v}` ham innerHTML'e yazılıyordu).
//   2. Hayvan referans alanları (hayvan_id, ana_hayvan_id, buzagi_id,
//      farm_animal_id, anne_id) küpe etiketine dönüşür (_gmHayvanKupeById
//      deseni; çözülmezse '?') — ham UUID ASLA.
//   3. Değişiklikler detayında _dgDegerMetni "kupe (uuid-önek)" göstermez;
//      çözülemeyen UUID '?'e düşer. pkKisa/ham pk YALNIZ teknik katlamada —
//      önizleme plan kartı görünür satırda pk basmaz.
//
// esc/escAttr aynaları ui-pure.test.js / gecmis-xss.test.js ile aynı (helpers.js birebir).

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeElement } = require('./support/loadModule.js');
const { fmtTarih, fmtTarihSaat } = require('../../js/utils/helpers.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const HAM_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const IMG = '<img src=x onerror=alert(1)>';

// ── ui.js — _islemDetaySatirlariHtml (işlem detay paneli payload satırları) ──
const gm = loadBrowserModule('js/gecmis.js', {
  expose: ['_gmGeriAlHedef', '_gmIslemTipEtiket', '_gmIslemTipEmoji', '_GM_KATEGORI_TR', '_GM_KATEGORI_EMOJI'],
});
const ui = loadBrowserModule('js/ui.js', {
  extra: {
    esc: escMirror,
    escAttr: escAttrMirror,
    fmtTarih, fmtTarihSaat,
    HEKIMLER: [],
    getState: () => [],
    _gmUndoButtonHtml: () => '',
    _gmIslemTipEtiket: gm.sandbox._gmIslemTipEtiket,
    _gmIslemTipEmoji: gm.sandbox._gmIslemTipEmoji,
    _GM_KATEGORI_TR: gm.exposed._GM_KATEGORI_TR,
    _GM_KATEGORI_EMOJI: gm.exposed._GM_KATEGORI_EMOJI,
    _gmGeriAlHedef: gm.exposed._gmGeriAlHedef,
  },
  expose: ['_islemDetaySatirlariHtml'],
});
const { _islemDetaySatirlariHtml } = ui.exposed;

test('L4-06×07 — telafi payload\'ı işlem dilli: orijinal_tip/seviye/adim ham kod DEĞİL (review Minor-1)', () => {
  ui.sandbox._gmHayvanKupeById = {};
  const h = _islemDetaySatirlariHtml({ orijinal_tip: 'TOHUMLAMA', seviye: 'satir', adim: 1 });
  assert.ok(h.includes('Geri alınan olay'), 'anahtar etiketi Türkçe');
  assert.ok(h.includes('Tohumlama') && !h.includes('TOHUMLAMA'), 'tip değeri etiketli — ham kod yok: ' + h);
  assert.ok(h.includes('Kapsam') && h.includes('Kayıt'), 'seviye etiketli (satir → Kayıt)');
  assert.ok(h.includes('Adım') && h.includes('>1<'), 'adım satırı görünür');
});

// ── review Minor-4 kilidi: detay paneli Geri Al butonu ÖLÜ kalmasın ──
// Kök neden (W5 onarımı): eski `['*'].includes(l.tip)` her zaman false üretiyordu.
// Bu test çözücü→buton kablolamasını kilitler (regresyonda sessiz geri düşmesin).
test('ölü-buton kilidi — hedef üreten entryde panel Geri Al butonu RENDER edilir', () => {
  const yakalanan = [];
  const anchor = makeElement('div');
  anchor.insertAdjacentElement = (poz, el) => { yakalanan.push(el); };
  ui.sandbox._openIslemDetayRow({
    id: 'l9', tip: 'HAYVAN_GUNCELLENDI', ref_tablo: 'hayvanlar', ref_id: 'hv-1',
    ana_hayvan_id: 'hv-1', tarih: '2026-09-14T10:00:00Z', payload: { notlar: 'küpe yenilendi' },
  }, anchor);
  assert.strictEqual(yakalanan.length, 1, 'panel html üretildi');
  assert.ok(yakalanan[0].innerHTML.includes('dg-det-geri-al'), 'Geri Al butonu VAR (çözücü hedef üretti)');
});

test('ölü-buton kilidi — hedef üretmeyen entryde buton YOK (yanlış pozitif koruması)', () => {
  const yakalanan = [];
  const anchor = makeElement('div');
  anchor.insertAdjacentElement = (poz, el) => { yakalanan.push(el); };
  ui.sandbox._openIslemDetayRow({ id: 'l10', tip: 'BILINMEYEN_TIPI' }, anchor);
  assert.strictEqual(yakalanan.length, 1, 'panel yine açılır');
  assert.ok(!yakalanan[0].innerHTML.includes('dg-det-geri-al'), 'çözülemeyen kartta buton YOK');
});

test('L4-07 — payload değeri adversarial: <img onerror> ham tag üretmez (esc\'li)', () => {
  const h = _islemDetaySatirlariHtml({ notlar: IMG });
  assert.ok(!h.includes('<img'), 'stored-XSS: ham tag sızdı — ' + h);
  assert.ok(h.includes('&lt;img'), 'escape edilmiş biçimde GÖRÜNMELİ');
});

test('L4-07 — alan adı adversarial: bilinmeyen anahtar esc\'siz basılmaz', () => {
  const h = _islemDetaySatirlariHtml({ [IMG]: 'deger' });
  assert.ok(!h.includes('<img'), 'payload anahtarı da escape edilmeli');
  assert.ok(h.includes('&lt;img'), 'anahtar escape edilmiş görünür');
});

test('L4-07 — hayvan referansı küpe etiketine dönüşür (_gmHayvanKupeById deseni)', () => {
  ui.sandbox._gmHayvanKupeById = { '12345678-1234-1234-1234-123456789abc': '4019' };
  for (const alan of ['hayvan_id', 'ana_hayvan_id', 'buzagi_id', 'farm_animal_id', 'anne_id']) {
    const h = _islemDetaySatirlariHtml({ [alan]: '12345678-1234-1234-1234-123456789abc' });
    assert.ok(h.includes('>4019<'), alan + ' küpe gösterilmeli — ' + h);
    assert.ok(!HAM_UUID.test(h.replace(/&[a-z]+;/g, '')), alan + ' ham UUID sızdı');
  }
});

test('L4-07 — çözülemeyen hayvan referansı "?" — ham UUID ASLA', () => {
  ui.sandbox._gmHayvanKupeById = {};
  const h = _islemDetaySatirlariHtml({ buzagi_id: 'aabbccdd-1122-3344-5566-778899aabbcc' });
  assert.ok(h.includes('>&lt;?') === false && h.includes('?'), 'nötr ? gösterilir');
  assert.ok(!/[0-9a-f]{8}-[0-9a-f]{4}/i.test(h), 'uuid sızıntısı: ' + h);
});

test('L4-07 — payload.id (kendi pk) listede YOK; düz değerler aynen görünür', () => {
  ui.sandbox._gmHayvanKupeById = {};
  const h = _islemDetaySatirlariHtml({
    id: '99112233-4455-6677-8899-aabbccddeeff',
    sonuc: 'Gebe',
    deneme_no: 2,
  });
  assert.ok(!h.includes('99112233'), 'kendi pk teknik değerdir — listede yok');
  assert.ok(h.includes('Gebe') && h.includes('>2<'), 'düz değerler korunur');
});

// ── degisiklikler.js — _dgDegerMetni + teknik katlama (L4-07'in diğer yüzü) ──
const diff = loadBrowserModule('js/degisiklikler/diff.js', { extra: {} });
const etiket = loadBrowserModule('js/degisiklikler/etiketler.js', { extra: {} });
const dg = loadBrowserModule('js/degisiklikler/degisiklikler.js', {
  extra: {
    registerActions: () => {},
    esc: escMirror,
    escAttr: escAttrMirror,
    fmtTarih, fmtTarihSaat,
    tabloEtiketi: etiket.sandbox.tabloEtiketi,
    alanEtiketi: etiket.sandbox.alanEtiketi,
    islemEtiketi: etiket.sandbox.islemEtiketi,
    degerMetni: diff.sandbox.degerMetni,
    pkKisa: diff.sandbox.pkKisa,
    hayvanByKupeRef: (ref) => ref === '12345678-1234-1234-1234-123456789abc'
      ? { id: ref, kupe_no: '4019' } : null,
  },
  expose: ['_dgDegerMetni', '_dgTeknikDetayHtml', '_dgOnizleHtml'],
});
const { _dgDegerMetni, _dgTeknikDetayHtml, _dgOnizleHtml } = dg.exposed;

test('L4-07 — _dgDegerMetni: küpe çözülürse SADECE küpe (uuid-önek parantezi YOK)', () => {
  const v = _dgDegerMetni('cases', 'hayvan_id', '12345678-1234-1234-1234-123456789abc');
  assert.strictEqual(v, '4019');
  assert.ok(!/\(/.test(v), 'eski "kupe (önek)" biçimi kalktı');
});

test('L4-07 — _dgDegerMetni: çözülmeyen UUID "?" (buzagi_id/farm_animal_id dâhil)', () => {
  assert.strictEqual(_dgDegerMetni('dogum', 'buzagi_id', 'aabbccdd-1122-3344-5566-778899aabbcc'), '?');
  assert.strictEqual(_dgDegerMetni('hayvanlar', 'farm_animal_id', 'aabbccdd-1122-3344-5566-778899aabbcc'), '?');
  assert.strictEqual(_dgDegerMetni('hayvanlar', 'id', 'aabbccdd-1122-3344-5566-778899aabbcc'), '?');
});

test('L4-07 — _dgDegerMetni: UUID olmayan referans metni aynen kalır (küpe değeri girdisi)', () => {
  assert.strictEqual(_dgDegerMetni('cases', 'hayvan_id', '4019'), '4019');
});

test('L4-07 — önizleme plan kartı görünür satırda pk basmaz; pk YALNIZ teknik katlamada', () => {
  const on = {
    geri_alinabilir: true,
    plan: [{ sira: 1, tablo: 'tohumlama', pk: 'aabbccdd-1122-3344-5566-778899aabbcc', islem: 'D', yapilacak: 'Kayıt silinecek' }],
  };
  const h = _dgOnizleHtml(on, { seviye: 'satir', hedef: { tablo: 'tohumlama', pk: 'aabbccdd-1122-3344-5566-778899aabbcc' } });
  // görünür plan kartında pk yok — teknik <details> bloğunda var
  const detayBaslangic = h.indexOf('<details class="dg-teknik"');
  const gorunur = detayBaslangic === -1 ? h : h.slice(0, detayBaslangic);
  assert.ok(!/[0-9a-f]{8}-[0-9a-f]{4}/i.test(gorunur), 'görünür alanda ham UUID: ' + gorunur);
  assert.ok(!/dg-pk/.test(gorunur), 'pk çipi görünürde değil');
  assert.ok(h.includes('aabbccdd'), 'teknik katlamada pk KALIR (denetlenebilirlik)');
  assert.ok(h.includes('Teknik ayrıntı'), 'teknik katlama üretilir');
});

test('L4-07 — teknik katlama: plan adımlarının pk listesi blok İÇİNDE', () => {
  const t = _dgTeknikDetayHtml(
    { txid: '424242' },
    { plan: [{ sira: 1, tablo: 'dogum', pk: 'dd0dd0dd-0000-1111-2222-333344445555' }] },
  );
  assert.ok(t.includes('Plan adımı 1'), 'adım etiketi');
  assert.ok(t.includes('dd0dd0dd'), 'adım pk katlamada');
});
