// tests/unit/saat-alani.test.js — U2-S1: programdaki tek saat alanı standardı.
// Yardımcılar gerçektir (js/utils/helpers.js, js/utils/events.js, js/config.js);
// DOM küçük bir sahtedir: üretilen HTML'den input ve çipler çıkarılır.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadBrowserModule, loadExtractedFunction, makeElement } = require('./support/loadModule.js');

const REPO_ROOT = path.join(__dirname, '..', '..');
const oku = yol => fs.readFileSync(path.join(REPO_ROOT, yol), 'utf8');
const { HIZLI_SAATLER } = loadBrowserModule('js/config.js', { expose: ['HIZLI_SAATLER'] }).exposed;

// Çip HTML'inden öznitelikleri ayıklar.
function cipleriOku(html) {
  return [...String(html).matchAll(/<button\b[^>]*>/g)].map(m => {
    const a = ad => (new RegExp(`\\s${ad}="([^"]*)"`).exec(m[0]) || [])[1];
    const c = makeElement('button');
    c.className = a('class') || '';
    c.className.split(/\s+/).filter(Boolean).forEach(s => c.classList.add(s));
    Object.assign(c.dataset, { action: a('data-action'), hedef: a('data-hedef'), t: a('data-t') });
    if (a('data-bos')) c.dataset.bos = a('data-bos');
    return c;
  });
}

// Küçük sahne: yardımcılar + tek saat alanı.
function kur() {
  const els = new Map();
  const toastlar = [];
  const dom = {
    getElementById: id => els.get(id) || null,
    addEventListener() {},
    querySelectorAll: () => dom.statikler || [],
  };
  const { sandbox: s } = loadBrowserModule('js/utils/helpers.js', {
    dom,
    extra: { HIZLI_SAATLER, Event },
  });
  s.toast = (m, e) => toastlar.push({ m, e: !!e }); // helpers.js kendi toast'unu DOM'a yazar
  const alan = (id, deger = '', parent = null) => {
    const i = makeElement('input');
    i.id = id; i.type = 'time'; i.value = deger;
    i.olaylar = [];
    i.dispatchEvent = ev => { i.olaylar.push(ev); };
    i.cipler = [];
    i.parentElement = parent || { dataset: {}, querySelector: () => i.cipler[0] || null, querySelectorAll: () => i.cipler };
    i.insertAdjacentHTML = (yer, html) => { i.eklenenYer = yer; i.cipler.push(...cipleriOku(html)); };
    els.set(id, i);
    return i;
  };
  const yerlesik = (id, opts) => {
    const html = s.saatAlaniHtml(id, opts);
    const i = alan(id, (/\svalue="([^"]*)"/.exec(html) || [])[1] || '');
    i.cipler = cipleriOku(html);
    return { i, html };
  };
  return { s, dom, els, toastlar, alan, yerlesik };
}
const aktifler = i => i.cipler.filter(c => c.classList.contains('aktif')).map(c => c.dataset.t);

test('S-01: yardımcı input + HIZLI_SAATLER çipleri üretir, test regex sırası korunur', () => {
  const { s } = kur();
  const html = s.saatAlaniHtml('x-saat');
  assert.match(html, /^<div class="saat-alani"><input id="x-saat" class="fi" type="time"/);
  const cipler = cipleriOku(html);
  assert.deepStrictEqual(cipler.map(c => c.dataset.t), [...HIZLI_SAATLER]);
  for (const c of cipler) {
    assert.ok(c.classList.contains('ek-chip'), 'mevcut çip dili');
    assert.ok(c.classList.contains('saat-chip'));
    assert.strictEqual(c.dataset.action, 'saat-chip');
    assert.strictEqual(c.dataset.hedef, 'x-saat');
  }
});

test('S-02: dolu değer input\'a yazılır, eşleşen çip aktif gelir; boş ya da eşleşmeyen değerde hiçbiri', () => {
  const { s } = kur();
  const dolu = s.saatAlaniHtml('x', { deger: '16:00' });
  assert.match(dolu, /type="time" value="16:00"/);
  assert.deepStrictEqual(cipleriOku(dolu).filter(c => c.classList.contains('aktif')).map(c => c.dataset.t), ['16:00']);
  assert.ok(!cipleriOku(s.saatAlaniHtml('x')).some(c => c.classList.contains('aktif')));
  assert.ok(!cipleriOku(s.saatAlaniHtml('x', { deger: '09:00' })).some(c => c.classList.contains('aktif')));
});

test('S-03: cipler:false sade input döner, sarmalayıcı ve düğme yok; attr input\'a gider', () => {
  const { s } = kur();
  const html = s.saatAlaniHtml('x', { cipler: false, attr: 'style="width:100%"' });
  assert.match(html, /^<input id="x" class="fi" type="time" value="" style="width:100%">$/);
  assert.ok(!/button/.test(html));
});

test('S-03b: id ve değer öznitelik kaçışından geçer', () => {
  const { s } = kur();
  const html = s.saatAlaniHtml('a"b', { deger: '"><x' });
  assert.ok(!html.includes('"><x'));
  assert.ok(html.includes('a&quot;b'));
});

test('S-04: çip HH:MM yazar, kabarcıklı input ve change üretir, aktif tekil olur', () => {
  const { s, yerlesik } = kur();
  const { i } = yerlesik('x', { deger: '08:00' });
  s.saatCipSec(i.cipler[1]);
  assert.strictEqual(i.value, '16:00');
  assert.match(i.value, /^([01]\d|2[0-3]):[0-5]\d$/);
  assert.deepStrictEqual(aktifler(i), ['16:00']);
  assert.deepStrictEqual(i.olaylar.map(e => e.type), ['input', 'change']);
  assert.ok(i.olaylar.every(e => e.bubbles === true), 'kabarcıklı');
});

test('S-05: boş anlamlı alanda aktif çipe ikinci dokunuş boşaltır; boş anlamı yoksa değer kalır', () => {
  const { s, yerlesik } = kur();
  const a = yerlesik('a', { bosIzinli: true }).i;
  s.saatCipSec(a.cipler[0]);
  assert.strictEqual(a.value, '08:00');
  s.saatCipSec(a.cipler[0]);
  assert.strictEqual(a.value, '');
  assert.deepStrictEqual(aktifler(a), []);
  assert.strictEqual(a.olaylar.length, 4, 'boşaltma da olay üretir');
  const b = yerlesik('b', {}).i;
  s.saatCipSec(b.cipler[0]);
  s.saatCipSec(b.cipler[0]);
  assert.strictEqual(b.value, '08:00');
  assert.deepStrictEqual(aktifler(b), ['08:00']);
});

test('S-06: elle yazım çip aktifliğini değerle eşitler (events.js belge dinleyicisi)', () => {
  const { s, yerlesik } = kur();
  const { i } = yerlesik('x', { deger: '08:00' });
  i.closest = () => null;
  const dinleyen = {};
  const dom = { addEventListener: (t, f) => { (dinleyen[t] = dinleyen[t] || []).push(f); } };
  loadBrowserModule('js/utils/events.js', { dom, extra: { saatCipEsitle: s.saatCipEsitle } });
  i.value = '20:00';
  dinleyen.input.forEach(f => f({ target: i }));
  assert.deepStrictEqual(aktifler(i), ['20:00']);
  i.value = '19:30';
  dinleyen.input.forEach(f => f({ target: i }));
  assert.deepStrictEqual(aktifler(i), []);
  // Saat dışı giriş yok sayılır, hata atmaz.
  const metin = makeElement('input'); metin.type = 'text'; metin.closest = () => null;
  dinleyen.input.forEach(f => f({ target: metin }));
});

test('S-07: programatik saatYaz ve cl çipi eşitler, olay üretmez', () => {
  const { s, yerlesik } = kur();
  const { i } = yerlesik('x', { deger: '08:00' });
  s.saatYaz('x', '16:00');
  assert.deepStrictEqual(aktifler(i), ['16:00']);
  s.cl('x');
  assert.strictEqual(i.value, '');
  assert.deepStrictEqual(aktifler(i), []);
  assert.strictEqual(i.olaylar.length, 0);
  s.saatYaz('yok', '08:00'); // alan yoksa sessiz
});

test('S-08: statik alanlar açılışta çip alır, iki kez kurulum çoğaltmaz, boş anlamı taşınır', () => {
  const k = kur();
  const a = k.alan('a', '08:00');
  a.parentElement.dataset.bos = '1';
  const b = k.alan('b', '');
  k.dom.statikler = [a, b];
  k.s.saatAlanlariKur();
  k.s.saatAlanlariKur();
  assert.strictEqual(a.eklenenYer, 'afterend');
  assert.deepStrictEqual(a.cipler.map(c => c.dataset.t), [...HIZLI_SAATLER]);
  assert.deepStrictEqual(aktifler(a), ['08:00']);
  assert.ok(a.cipler.every(c => c.dataset.bos === '1'));
  assert.deepStrictEqual(aktifler(b), []);
  assert.ok(b.cipler.every(c => c.dataset.bos === undefined));
});

test('S-09: yarım giriş uyarır ve true döner; geçerli, boş ya da olmayan alan false', () => {
  const k = kur();
  const i = k.alan('x');
  assert.strictEqual(k.s.saatYarimMi('x'), false);
  i.validity = { badInput: false };
  assert.strictEqual(k.s.saatYarimMi('x'), false);
  assert.strictEqual(k.s.saatYarimMi('yok'), false);
  assert.strictEqual(k.toastlar.length, 0);
  i.validity = { badInput: true };
  assert.strictEqual(k.s.saatYarimMi('x'), true);
  assert.strictEqual(k.toastlar.length, 1);
  assert.ok(k.toastlar[0].e, 'hata tonu');
  assert.match(k.toastlar[0].m, /Saat/);
});

test('G2 #4-7: kopyalar kalktı, tek çip dili; dolu başlangıçlar korunur', () => {
  const { s } = kur();
  const birlesik = ['js/forms.js', 'js/ui.js', 'js/utils/handlers.js'].map(oku).join('\n');
  for (const eski of ['bcSeansSaatChip', 'bcTohumSaatChipsRender', 'seansAddSaatSec', 'sablonSaatChip', 'bc-saat-chip', 'bc-tohum-saat-chip', 'sablon-saat-chip', 'bc-tohum-saat-chips']) {
    assert.ok(!birlesik.includes(eski) && !oku('index.html').includes(eski), eski);
  }
  const html = loadExtractedFunction('js/forms.js', '_bcSeansFormHtml', {
    extra: { saatAlaniHtml: s.saatAlaniHtml, _bcSeansDrugGruplariHtml: () => '' },
  })(1);
  assert.match(html, /<input id="bc-gsaat" class="fi" type="time" value="09:00"/);
  const cipler = cipleriOku(html).filter(c => c.dataset.action === 'saat-chip');
  assert.deepStrictEqual(cipler.map(c => c.dataset.t), [...HIZLI_SAATLER]);
  assert.ok(!cipler.some(c => c.classList.contains('aktif')), '09:00 çipte yok');
  const ui = oku('js/ui.js');
  assert.match(ui, /saatAlaniHtml\('sbs-time', \{ deger: HIZLI_SAATLER\[0\] \}\)/);
  assert.match(ui, /saatAlaniHtml\('seans-add-time', \{ deger: HIZLI_SAATLER\[0\] \}\)/);
  assert.match(oku('index.html'), /<div class="saat-alani"><input id="bc-tohum-saat" class="fi" type="time" value="08:00"[^>]*><\/div>/);
  const forms = oku('js/forms.js');
  assert.match(forms, /saatYaz\('bc-tohum-saat', '08:00'\)/);
  assert.match(forms, /saatYaz\('bc-tohum-saat', plan\.tohumlama\.planned_time\)/);
  assert.match(forms, /saatYaz\('bc-gsaat', '09:00'\)/);
});

test('S-10: tek genel handler ve statik bağlama', () => {
  assert.match(oku('js/utils/handlers.js'), /'saat-chip':\s*\(el\)\s*=>\s*saatCipSec\(el\)/);
  const html = oku('index.html');
  for (const id of ['ht-ac-saat', 'ht-mu-saat', 'ht-so-saat']) {
    assert.match(html, new RegExp(`<div class="saat-alani" data-bos="1"><input id="${id}" class="fi" type="time"></div>`), id);
  }
  assert.match(html, /\.saat-alani\{[^}]*flex-wrap:wrap/);
  const kural = html.match(/\.saat-alani\{[^}]*\}/)[0];
  assert.ok(!/background/.test(kural), 'zemin yok');
  assert.match(oku('js/app.js'), /addEventListener\('load', withErrorHandling\(async \(\) => \{\s+saatAlanlariKur\(\);/);
});
