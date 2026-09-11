'use strict';
// Pedigree style birim testleri (W3-fix F1 — luna review kapsamı).
// Stil konfigürasyonunda focus/farm/external ayrımı (selektör varlığı +
// ŞEKİL/KENAR farklılaşması — renk-tek-başına değil) ve tema token uyumu
// (fallback paleti index.html :root aynası; getComputedStyle okunduğunda
// token değeri devreye girer).
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule');

function yukle(extra) {
  return loadBrowserModule('js/pedigree/pedigree-style.js', { extra });
}

function seciciBul(style, selector) {
  return style.find(s => s.selector === selector);
}

test('tüm sınıf selektörleri mevcut: focus/farm/external/dam/sire/shared/unknown + edge', () => {
  const { sandbox } = yukle();
  const style = sandbox.pedigreeStyle();
  for (const sel of ['node', 'node.farm', 'node.external', 'node.focus', 'node.dam',
    'node.sire', 'node.shared', 'node.unknown', 'edge', 'edge[role = "sire"]']) {
    assert.ok(seciciBul(style, sel), 'selektör eksik: ' + sel);
  }
});

test('farm/external ayrımı renk-dışı: farklı şekil + kesikli kenar (erişilebilirlik)', () => {
  const { sandbox } = yukle();
  const style = sandbox.pedigreeStyle();
  const farm = seciciBul(style, 'node.farm').style;
  const ext = seciciBul(style, 'node.external').style;
  assert.notStrictEqual(farm.shape, ext.shape, 'şekiller farklı olmalı');
  assert.strictEqual(farm.shape, 'ellipse');
  assert.strictEqual(ext.shape, 'round-hexagon');
  assert.strictEqual(ext['border-style'], 'dashed', 'external kesikli kenarlı');
  assert.notStrictEqual(farm['border-style'] || 'solid', 'dashed');
});

test('focus düğümü tabandan ayrışır: kalın kenar + büyük boyut', () => {
  const { sandbox } = yukle();
  const style = sandbox.pedigreeStyle();
  const taban = seciciBul(style, 'node').style;
  const focus = seciciBul(style, 'node.focus').style;
  assert.ok(Number(focus['border-width']) > Number(taban['border-width']), 'focus kenarı daha kalın');
  assert.ok(Number(focus.width) > Number(taban.width), 'focus düğümü daha büyük');
});

test('sire kenarı damdan ayrışır: noktalı çizgi stili', () => {
  const { sandbox } = yukle();
  const style = sandbox.pedigreeStyle();
  const taban = seciciBul(style, 'edge').style;
  const sire = seciciBul(style, 'edge[role = "sire"]').style;
  assert.notStrictEqual(sire['line-style'] || taban['line-style'] || 'solid', (taban['line-style'] || 'solid'), 'sire kenar stili tabandan farklı');
});

test('tema token fallback\'leri index.html :root paletinin aynası (sandbox\'ta getComputedStyle yok)', () => {
  const { sandbox } = yukle();
  const style = sandbox.pedigreeStyle();
  const farm = seciciBul(style, 'node.farm').style;
  assert.strictEqual(farm['background-color'], '#98d96e', '--green3 fallback');
  assert.strictEqual(farm['border-color'], '#4e9a2a', '--green fallback');
  const focus = seciciBul(style, 'node.focus').style;
  assert.strictEqual(focus['border-color'], '#2a6bb5', '--blue fallback');
});

test('tema token okunabilir: getComputedStyle değeri stile taşınır', () => {
  const { sandbox } = yukle({
    getComputedStyle: () => ({
      getPropertyValue: (name) => (name === '--green' ? '#123456' : name === '--blue' ? '#abcdef' : ''),
    }),
  });
  const style = sandbox.pedigreeStyle();
  const farm = seciciBul(style, 'node.farm').style;
  assert.strictEqual(farm['border-color'], '#123456', '--green token okundu');
  const focus = seciciBul(style, 'node.focus').style;
  assert.strictEqual(focus['border-color'], '#abcdef', '--blue token okundu');
  // Okunamayan token fallback'e düşer
  assert.strictEqual(farm['background-color'], '#98d96e', '--green3 yok → fallback');
});
