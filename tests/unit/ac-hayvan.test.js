// tests/unit/ac-hayvan.test.js
// js/ui.js → acHayvan (modal küpe autocomplete) birim testleri.
// Görev/kızgınlık/tohumlama/vaka/aşı/doğum modallarının TÜM küpe dropdown'ları
// tek fonksiyondan geçer (handlers.js: taskadd/kizginlik/insem/disease/vaccine/birth).
//
// Sözleşme (srchDropdown ile ortak — helpers.js srchAdaySirala/vurguHtml):
// 1. Sorgu varken alaka katmanları + vurgu; uuid id ARANMAZ (alakasız satır üretirdi).
// 2. Sorgu boşken liste küpe sırasına göre (tr locale + numeric) — dizi sırası değil.
// 3. Irktan eşleşen satırda küpe vurgulanmaz, ırk vurgulanır.
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { trLower, srchAdaySirala, vurguHtml } = require('../../js/utils/helpers.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

// id'sinde "18" geçen uuid benzeri kayıt: id aranmadığı için "18" sorgusunda çıkmamalı
const HAYVANLAR = [
  { id: 'u-189', kupe_no: '189', devlet_kupe: '', irk: '', padok: 'Sağıl Padok' },
  { id: '9f18c2aa-01', kupe_no: '55', devlet_kupe: '', irk: '', padok: 'Düve Padok' },
  { id: 'u-18', kupe_no: '18', devlet_kupe: '', irk: '', padok: 'Sağıl Padok' },
  { id: 'u-018', kupe_no: '018', devlet_kupe: '', irk: '', padok: 'Sağıl Padok' },
  { id: 'u-67', kupe_no: '67', devlet_kupe: '', irk: 'Holstein', padok: 'Buzağı Padok' },
  { id: 'u-07', kupe_no: '07', devlet_kupe: '', irk: '', padok: 'Buzağı Padok' },
  { id: 'u-14', kupe_no: '14', devlet_kupe: 'TR093114016', irk: 'Holstein', padok: 'Düve Padok (Büyük)' },
  { id: 'u-201', kupe_no: '201', devlet_kupe: '', irk: 'Holstein', padok: 'Düve Padok (Büyük)' },
];

const store = new Map([['animals', HAYVANLAR], ['gebeIds', []]]);
const { sandbox, document: doc } = loadBrowserModule('js/ui.js', {
  extra: {
    esc: escMirror, escAttr: escAttrMirror,
    trLower, srchAdaySirala, vurguHtml,
    getState: (k) => store.get(k),
    setState: (k, v) => store.set(k, v),
  },
});

function kur(inputId, listId) {
  const inp = doc.__setEl(inputId, Object.assign(doc.createElement('input'), { value: '' }));
  const ac = doc.__setEl(listId, doc.createElement('div'));
  return { inp, ac };
}
const satirlar = (ac) => (ac.innerHTML.match(/data-kupe="[^"]*"/g) || []).map(m => m.replace(/data-kupe="|"/g, ''));

test('acHayvan: boş sorgu — küpe sırasına göre (numeric), dizi sırası değil', () => {
  const { inp, ac } = kur('ta-hid', 'ac-tahid');
  inp.value = '';
  sandbox.acHayvan('ta-hid', 'ac-tahid');
  // numeric: 07=7, 14, 18, 018=18 (eşitlikte kaynak sırası korunur), 55, 67, 189, 201
  assert.deepStrictEqual(satirlar(ac), ['07', '14', '18', '018', '55', '67', '189', '201']);
});

test('acHayvan: "18" — birebir önce, önek sonra; id içindeki 18 eşleşmez', () => {
  const { inp, ac } = kur('ta-hid', 'ac-tahid');
  inp.value = '18';
  sandbox.acHayvan('ta-hid', 'ac-tahid');
  assert.deepStrictEqual(satirlar(ac), ['18', '189', '018']);
  assert.ok(!ac.innerHTML.includes('9f18c2aa'), 'uuid id aranmamalı');
  assert.ok(ac.innerHTML.includes('<span class="ac-vurgu">18</span>'), 'birebir eşleşme vurgulanmalı');
});

test('acHayvan: ırktan eşleşme — küpe vurgusuz, ırk vurgulu, ayraç " · " doğru', () => {
  const { inp, ac } = kur('ta-hid', 'ac-tahid');
  inp.value = 'holst';
  sandbox.acHayvan('ta-hid', 'ac-tahid');
  const html = ac.innerHTML;
  assert.deepStrictEqual(satirlar(ac), ['14', '67', '201']); // hepsi tier 6; kısa küpe önce
  assert.ok(!html.includes('<span class="ac-vurgu">14'), 'kupe vurgulanmamalı');
  assert.ok(html.includes('<span class="ac-vurgu">Holst</span>ein · Düve Padok (Büyük)'), 'ırk vurgulu + ayraç');
  assert.ok(!html.includes(' · · '), 'çift ayraç olmamalı');
  assert.ok(!html.includes('text-align:right"> · '), 'sağ taraf ayraçla başlamamalı');
});

test('acHayvan: boş irk + dolu padok — baştaki " · " artığı yok', () => {
  const { inp, ac } = kur('ta-hid', 'ac-tahid');
  inp.value = '189';
  sandbox.acHayvan('ta-hid', 'ac-tahid');
  assert.ok(ac.innerHTML.includes('>Sağıl Padok<'), 'padok görünmeli');
  assert.ok(!ac.innerHTML.includes('> · Sağıl Padok'), 'başa ayraç düşmemeli');
});

test('acHayvan: Türkçe büyüklük duyarsız — "tR093114016" devlet küpesini bulur', () => {
  const { inp, ac } = kur('ta-hid', 'ac-tahid');
  inp.value = 'tR093114016';
  sandbox.acHayvan('ta-hid', 'ac-tahid');
  assert.deepStrictEqual(satirlar(ac), ['14']);
});

test('acHayvan: devlet küpesinden eşleşme — sağ tarafta vurgulu devlet görünür', () => {
  const { inp, ac } = kur('ta-hid', 'ac-tahid');
  inp.value = '931140'; // yalnız u-14'ün TR093114016'sında geçer; kupe '14' eşleşmez
  sandbox.acHayvan('ta-hid', 'ac-tahid');
  assert.deepStrictEqual(satirlar(ac), ['14']);
  const html = ac.innerHTML;
  assert.ok(html.includes('<span class="ac-vurgu">931140</span>'), 'devlet küpesi vurgulu gösterilmeli');
  assert.ok(!html.includes('<span class="ac-vurgu">14<'), 'kupe vurgulanmamalı');
});

test('acHayvan: eşleşme yok — uyarı mesajı', () => {
  const { inp, ac } = kur('ta-hid', 'ac-tahid');
  inp.value = 'zzz999';
  sandbox.acHayvan('ta-hid', 'ac-tahid');
  assert.ok(ac.innerHTML.includes('eşleşen hayvan bulunamadı'));
});
