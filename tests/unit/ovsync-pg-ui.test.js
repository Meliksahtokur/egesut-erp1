// tests/unit/ovsync-pg-ui.test.js — PLAN P3/P4/P6: kart etiketleri, butonlar, kategori
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { fmtTarih } = require('../../js/utils/helpers.js');
const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror, fmtTarih },
  expose: ['_katTipMap'],
});
const { _tohKaynakEtiket, _kalanGunEtiket, _ovsyncBaslatBtnHtml, _tohErteleBtnHtml } = sandbox;

test('P3: _katTipMap üreme kategorisi TOHUMLAMA_PLANLI + OVSYNC_BASLAT içerir', () => {
  assert.deepEqual(exposed._katTipMap.ureme, ['TOHUMLAMA_PLANLI', 'OVSYNC_BASLAT']);
});

test('P3: TOHUMLAMA_PLANLI kaynak etiketleri', () => {
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'PG_TOHUMLAMA:abc' }), /PG sonrası/);
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'TEDAVI_SABLON_TOHUMLAMA:x:y' }), /Şablon TAI/);
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'ACIK-DISI-h-1' }), /İlk tohumlama/);
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'ILK-TOH-DOGUM-x' }), /İlk tohumlama/);
  assert.equal(_tohKaynakEtiket({ gorev_tipi:'TEDAVI_GUN', kaynak:'x' }), '');
});

test('P3: kalan/gecikmiş etiketi yalnız üreme görevlerinde', () => {
  const iso = d => d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
  const yarinD = new Date(); yarinD.setDate(yarinD.getDate()+1);
  const dunD = new Date(); dunD.setDate(dunD.getDate()-1);
  const yarin = iso(yarinD), dun = iso(dunD);
  assert.match(_kalanGunEtiket({ gorev_tipi:'OVSYNC_BASLAT', hedef_tarih: yarin }), /1 gün kaldı/);
  assert.match(_kalanGunEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', hedef_tarih: dun }), /1 gün gecikmiş/);
  assert.equal(_kalanGunEtiket({ gorev_tipi:'TEDAVI_GUN', hedef_tarih: dun }), '');
});

test('P3/P6: OVSYNC_BASLAT [Başlat]/[İptal]; TOHUMLAMA_PLANLI [Ertele]; kapalı görevde yok', () => {
  const t = { id:'g1', gorev_tipi:'OVSYNC_BASLAT', tamamlandi:false, iptal:false };
  assert.match(_ovsyncBaslatBtnHtml(t), /Başlat/);
  assert.match(_ovsyncBaslatBtnHtml(t), /ovsyncIptal/);
  assert.equal(_ovsyncBaslatBtnHtml({ ...t, tamamlandi:true }), '');
  const p = { id:'g2', gorev_tipi:'TOHUMLAMA_PLANLI', tamamlandi:false, iptal:false };
  assert.match(_tohErteleBtnHtml(p), /Ertele/);
  assert.equal(_tohErteleBtnHtml({ ...p, iptal:true }), '');
  assert.equal(_tohErteleBtnHtml(t), '');   // OVSYNC_BASLAT kartına ertele yok
});

test('P3: buton id escAttr ile girer (XSS disiplini)', () => {
  const t = { id:"g'\"<x>", gorev_tipi:'OVSYNC_BASLAT', tamamlandi:false, iptal:false };
  const html = _ovsyncBaslatBtnHtml(t);
  assert.ok(!html.includes("g'\"<x>"), 'ham id basılmamalı');
  assert.ok(html.includes('g&#39;&quot;&lt;x&gt;'));
});
