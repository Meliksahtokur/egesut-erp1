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

// ui.js'ten tek fonksiyonu gerçek yardımcılarla çalıştırıp body'ye eklenen HTML'i döner.
function uiHtml(fn, args, ek = {}) {
  const { s } = kur();
  const eklenen = [];
  const document = {
    getElementById: () => null,
    createElement: t => makeElement(t),
    body: { appendChild: e => { eklenen.push(e); return e; } },
    ...ek.document,
  };
  loadExtractedFunction('js/ui.js', fn, {
    extra: { document, saatAlaniHtml: s.saatAlaniHtml, setTimeout: () => {}, ...ek.extra },
  })(...args);
  return { html: eklenen.map(e => e.innerHTML).join(''), eklenen };
}

test('G3 #9: saat-input yardımcıda; mevcut saat dolu ve çipi aktif, boşken hiçbiri', () => {
  const dolu = uiHtml('caseDaySaatAc', ['d1', '16:00:00']).html;
  assert.match(dolu, /<input id="saat-input" class="fi" type="time" value="16:00"/);
  assert.deepStrictEqual(cipleriOku(dolu).filter(c => c.classList.contains('aktif')).map(c => c.dataset.t), ['16:00']);
  const bos = uiHtml('caseDaySaatAc', ['d1', null]).html;
  assert.match(bos, /<input id="saat-input" class="fi" type="time" value=""/);
  assert.ok(!cipleriOku(bos).some(c => c.dataset.action === 'saat-chip' && c.classList.contains('aktif')));
});

test('G3 #10: cdt-saat yardımcıda, 08:00 dolu; yarım saat gönderilmez, boş 08:00 kalır', async () => {
  const kutu = makeElement('div');
  uiHtml('caseTohumlamaEkleAc', [], {
    document: { getElementById: id => (id === 'cd-gun-bolum' ? kutu : null) },
    extra: { _curCase: { id: 'c1' }, bugun: () => '2026-10-31', fmtTarih: x => x },
  });
  const html = kutu.children[0].innerHTML;
  assert.match(html, /<input id="cdt-saat" class="fi" type="time" value="08:00"/);
  assert.ok(!/<label[^>]*>(?:(?!<\/label>).)*saat-chip/s.test(html), 'çip label içinde değil');

  const calis = async (saatEl) => {
    const rpcler = [];
    const k = kur();
    k.els.set('cdt-tarih', { value: '2026-11-01' });
    k.els.set('cdt-saat', saatEl);
    await loadExtractedFunction('js/ui.js', 'caseTohumlamaEkleOnayla', {
      extra: {
        _curCase: { id: 'c1' }, toast() {}, rpc: async (a, p) => { rpcler.push(p); }, pullTables: async () => {},
        renderCaseTimeline: async () => {}, updateTaskBadge() {}, saatYarimMi: k.s.saatYarimMi,
        document: { getElementById: id => k.els.get(id) || null },
      },
    })(null);
    return { rpcler, toastlar: k.toastlar };
  };
  const yarim = await calis({ value: '', validity: { badInput: true } });
  assert.strictEqual(yarim.rpcler.length, 0);
  assert.strictEqual(yarim.toastlar.length, 1);
  const bos = await calis({ value: '', validity: { badInput: false } });
  assert.strictEqual(bos.rpcler[0].p_saat, '08:00', 'boş=08:00 korunur');
});

test('G4 #8: şablon tohumlama saati yardımcıda, kendi satırında; çipin change olayı mevcut handler\'a gider', () => {
  const ui = oku('js/ui.js');
  const satir = ui.split('\n').find(l => l.includes("saatAlaniHtml('sablon-tohumlama-saat'"));
  assert.ok(satir, 'yardımcıya alındı');
  assert.match(satir, /deger: tohumlama\.planned_time/);
  assert.match(satir, /data-change="sablon-tohumlama-saat"/);
  assert.match(satir, /display:flex;[^"]*flex-wrap:wrap/, 'dar satır sarar');
  assert.match(satir, /<div style="flex:1 1 100%">\$\{saatAlaniHtml/, 'çipler kendi satırında sığar');
  assert.match(oku('js/utils/handlers.js'), /'sablon-tohumlama-saat':\s*\(el\) => sablonTohumlamaSaat\(el\.value\)/);
});

test('G4 #8: yarım şablon saati şablon kaydını durdurur', async () => {
  const k = kur();
  k.alan('sablon-tohumlama-saat').validity = { badInput: true };

  await loadExtractedFunction('js/ui.js', 'sablonKaydet', {
    extra: { saatYarimMi: k.s.saatYarimMi, _sablonEdit: { ad: 'A', gunler: [] }, toast() { throw new Error('ad uyarısına inmemeli'); } },
  })();
  assert.strictEqual(k.toastlar.length, 1);
  assert.match(k.toastlar[0].m, /Saat/);
});

test('G4 #11: seans düzenleme saati yardımcıda, kendi satırında; mevcut saat dolu ve id korunur', () => {
  const { s } = kur();
  const row = makeElement('div');
  loadExtractedFunction('js/ui.js', 'seansDuzenleAc', {
    extra: {
      saatAlaniHtml: s.saatAlaniHtml,
      _seansAddCtx: { dayId: 'd1' },
      _cdDayData: { d1: { sessions: [{ id: 's1', planned_time: '20:00:00', dose: 1, unit: 'ml', route: 'IM', drug_product_id: 'p' }] } },
      fmtSeansSaat: t => String(t).slice(0, 5),
      esc: x => String(x),
      _dozHintBtnHtml: () => '',
      _curCase: null,
      document: { getElementById: id => (id === 'seans-mevcut-s1' ? row : null) },
    },
  })('s1');
  assert.match(row.innerHTML, /<div style="flex:1 1 100%"><div class="saat-alani"><input id="sd-time-s1" class="fi" type="time" value="20:00"/);
  assert.deepStrictEqual(cipleriOku(row.innerHTML).filter(c => c.classList.contains('aktif')).map(c => c.dataset.t), ['20:00']);
});

test('G6 kabul: tek yardımcı, 14 alan korunur, pu-saat çipsiz', () => {
  // js/ içinde type="time" yalnız yardımcıda; index.html'de yalnız dört statik alan.
  const kaynaklar = [];
  const gez = d => {
    for (const a of fs.readdirSync(path.join(REPO_ROOT, d), { withFileTypes: true })) {
      if (a.name === '_archive') continue;
      const y = path.join(d, a.name);
      if (a.isDirectory()) gez(y);
      else if (a.name.endsWith('.js')) kaynaklar.push(y);
    }
  };
  gez('js');
  const zamanli = kaynaklar.filter(y => /type="time"/.test(oku(y)));
  assert.deepStrictEqual(zamanli, ['js/utils/helpers.js']);
  assert.strictEqual((oku('js/utils/helpers.js').match(/type="time"/g) || []).length, 1);
  assert.deepStrictEqual(
    [...oku('index.html').matchAll(/<input id="([^"]+)"[^>]*type="time"/g)].map(m => m[1]).sort(),
    ['bc-tohum-saat', 'ht-ac-saat', 'ht-mu-saat', 'ht-so-saat'],
  );
  const js = kaynaklar.map(oku).join('\n');
  for (const id of ['bc-gsaat', 'seans-add-time', 'sbs-time', 'sablon-tohumlama-saat', 'saat-input', 'cdt-saat', 'ert-saat', 'devam-ertele-saat', 'pu-saat']) {
    assert.ok(js.includes(`saatAlaniHtml('${id}'`), id);
  }
  assert.ok(js.includes("saatAlaniHtml('sd-time-' + seansId"), 'sd-time-<id>');
  assert.match(js, /saatAlaniHtml\('pu-saat', \{ cipler: false,/);
  // Yarım giriş kontrolü boş anlamı olan her alanda.
  for (const id of ['ht-ac-saat', 'ht-mu-saat', 'ht-so-saat', 'bc-tohum-saat', 'cdt-saat', 'ert-saat', 'devam-ertele-saat', 'pu-saat', 'sablon-tohumlama-saat']) {
    assert.ok(js.includes(`saatYarimMi('${id}')`), id);
  }
  assert.strictEqual((oku('js/forms.js').match(/tohumIste && saatYarimMi\('bc-tohum-saat'\)/g) || []).length, 2, 'şablon ve toplu vaka');
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
