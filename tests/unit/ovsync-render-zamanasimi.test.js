// tests/unit/ovsync-render-zamanasimi.test.js — TB-3: ovsync render zaman aşımı + hata dalı
// (G-20261002-OVSYNC-SONRASI-BORC kalem 7). Sorun [INFERRED]: loadOvsyncDash →
// _ovsyncBaglamYukle (getData ×3 = idbGetAll) hiç tamamlanmazsa #ovsync-root süresiz spinner'da
// kalıyordu; reddedilirse sessizce boş bağlam kuruluyordu (satırlar "bilinmiyor", hata görünmez).
// Sözleşme:
//   * askıda kalan okuma → zamanAsimiMs sonra açık hata + "Tekrar Dene" (loadOvsyncDash() ile),
//     spinner kalmaz
//   * reddedilen okuma → aynı hata dalı
//   * zaman aşımından SONRA gelen geç sonuç ekranı ezmez, bağlamı da kurmaz
//   * sağlıklı yol değişmez (render çizilir, hata yok)
// Süre enjekte edilir (loadOvsyncDash(zamanAsimiMs)); gerçek zamanlayıcı, kısa değer.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadBrowserModule, makeElement, makeDomStub } = require('./support/loadModule.js');

const UI = 'js/ui.js';
const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const SPINNER = '<div class="loader"><div class="spin"></div></div>';
const KISA = 30; // ms — testte enjekte edilen zaman aşımı

function kur(getDataImpl) {
  const dom = makeDomStub();
  const root = makeElement('div');
  root.innerHTML = SPINNER;
  dom.__setEl('ovsync-root', root);
  dom.__setEl('pg-ovsync', makeElement('div'));
  const { sandbox, window } = loadBrowserModule(UI, {
    dom,
    extra: {
      esc: escMirror, escAttr: escAttrMirror,
      getData: getDataImpl,
      getState: () => [],
      ovsyncTakipGetir: async () => ({ veri: { bayrak_kapali: false, kpa: {} } }),
    },
  });
  return { sandbox, window, root };
}

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));

// loadOvsyncDash'i bekçi ile koşar: askıda kalırsa süitin 60 sn takılması yerine net FAIL verir.
async function kos(sandbox, arg, bekciMs = 1000) {
  let t;
  const bekci = new Promise((_, rej) => { t = setTimeout(() => rej(new Error('loadOvsyncDash ' + bekciMs + ' ms içinde dönmedi (süresiz spinner)')), bekciMs); });
  try { await Promise.race([sandbox.loadOvsyncDash(arg), bekci]); } finally { clearTimeout(t); }
}

test('TB-3 (i): okuma askıda kalırsa zaman aşımı sonrası hata + Tekrar Dene (spinner kalmaz)', async () => {
  const { sandbox, root } = kur(() => new Promise(() => {})); // asla resolve etmez
  const t0 = Date.now();
  await kos(sandbox, KISA);
  assert.ok(Date.now() - t0 >= KISA - 5, 'zaman aşımı beklenmeden dönmemeli');
  assert.doesNotMatch(root.innerHTML, /class="spin"/, 'spinner ekranda kalmamalı');
  assert.match(root.innerHTML, /yerel veri/i, 'açık hata mesajı');
  assert.match(root.innerHTML, /Tekrar Dene/, 'yeniden dene düğmesi');
  assert.match(root.innerHTML, /onclick="loadOvsyncDash\(\)"/, 'düğme loadOvsyncDash() çağırır');
  assert.doesNotMatch(root.innerHTML, /ovs-kpa/, 'veri render edilmemeli');
});

test('TB-3 (ii): okuma reddedilirse aynı hata dalı (sessiz boş bağlam YOK)', async () => {
  const { sandbox, window, root } = kur(async () => { throw new Error('IDB kapalı'); });
  await kos(sandbox, KISA);
  assert.match(root.innerHTML, /yerel veri/i);
  assert.match(root.innerHTML, /Tekrar Dene/);
  assert.doesNotMatch(root.innerHTML, /ovs-kpa/);
  assert.equal(window._ovsyncBaglam, undefined, 'başarısız yüklemede bağlam kurulmaz');
});

test('TB-3 (iii): zaman aşımından sonra gelen geç sonuç ekranı ve bağlamı ezmez', async () => {
  let coz;
  const { sandbox, window, root } = kur(() => new Promise((r) => { coz = r; }));
  await kos(sandbox, KISA);
  const hataHtml = root.innerHTML;
  assert.match(hataHtml, /Tekrar Dene/);
  coz([]); // geç gelen sonuç
  await bekle(20);
  assert.equal(root.innerHTML, hataHtml, 'geç sonuç ekranı ezmemeli');
  assert.equal(window._ovsyncBaglam, undefined, 'geç sonuç bağlamı kurmamalı');
});

test('TB-3 (iv): sağlıklı yol değişmez — hızlı okuma render çizer, hata yok', async () => {
  const { sandbox, window, root } = kur(async () => []);
  await kos(sandbox, KISA);
  assert.match(root.innerHTML, /ovs-kpa/);
  assert.doesNotMatch(root.innerHTML, /Tekrar Dene/);
  assert.ok(window._ovsyncBaglam, 'bağlam kurulur');
});

test('TB-3 (v): zaman aşımı argümansız çağrıda makul varsayılan (>=5 sn) — olay argümanı sayı sayılmaz', async () => {
  const { sandbox, root } = kur(async () => []);
  await kos(sandbox, { type: 'click' }); // onclick/olay argümanı → varsayılan süre
  assert.match(root.innerHTML, /ovs-kpa/);
  const src = require('node:fs').readFileSync(path.join(__dirname, '..', '..', UI), 'utf8');
  const m = src.match(/OVSYNC_ZAMAN_ASIMI_MS\s*=\s*(\d+)/);
  assert.ok(m && Number(m[1]) >= 5000 && Number(m[1]) <= 60000, 'sabit 5–60 sn aralığında');
});
