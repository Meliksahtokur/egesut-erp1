// tests/unit/toast.test.js
// Toast kuyruğu sözleşmesi (js/utils/helpers.js — ReFactorRoadmap Aşama 3.4).
//
// VM TUZAĞI: loader sandbox'a YÜKLEME ANINDAKİ global setTimeout/clearTimeout
// referanslarını kopyalar. node:test mock timer'ları mevcut globali değiştirdiği
// için sıra ZORUNLU: t.mock.timers.enable() ÖNCE, loadBrowserModule() SONRA
// (bkz. helpers-extra.test.js debounce bölümü — probe ile doğrulanmıştı).
//
// Zaman çizelgesi (sözleşme): gösterim t=0'da başlar, TOAST_MS(3200)'de gizlenir,
// TOAST_GAP_MS(300) sonra sıradaki gösterilir → tam döngü = 3500ms/toast.
const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const {
  loadBrowserModule,
  makeDomStub,
  makeElement,
} = require('./support/loadModule.js');

const HELPERS = 'js/utils/helpers.js';
const CYCLE = 3500; // TOAST_MS + TOAST_GAP_MS

// Toast elementini textContent/className atama geçmişini kaydeden düğüme
// dönüştür: history'ye yalnız BOŞ OLMAYAN className ataması (yani bir mesajın
// gösterilişi) düşer — textContent o ana kadar yazılmış olan mesajla birlikte.
function instrument(el) {
  const history = [];
  let text = '', cls = '';
  Object.defineProperty(el, 'textContent', {
    configurable: true,
    get: () => text,
    set: v => { text = String(v); },
  });
  Object.defineProperty(el, 'className', {
    configurable: true,
    get: () => cls,
    set: v => { cls = String(v); if (cls) history.push({ text, cls }); },
  });
  return history;
}

function loadToast(t) {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  t.after(() => t.mock.timers.reset());
  return freshToastModule();
}

// Mock timer'lar ZATEN enable edilmişken taze bir modül+element kurar.
// (fc property iterasyonları için: enable test başına BİR kez yapılır —
// iterasyon ortasında assert kırılıp reset atlansa bile ikinci enable
// ERR_INVALID_STATE fırlatmasın.)
function freshToastModule() {
  const doc = makeDomStub();
  const el = doc.__setEl('toast', makeElement());
  const history = instrument(el);
  const { sandbox } = loadBrowserModule(HELPERS, { dom: doc });
  return { sandbox, el, history };
}

// Kuyruk tamamen boşalana dek saati 10ms adımlarla ilerlet (zincirli
// setTimeout'lar her atışta yeniden planlandığından tek tickLarge yetmez).
function drain(t) {
  for (let i = 0; i < 1200; i++) t.mock.timers.tick(10);
}

// ── Temel gösterim ────────────────────────────────────────────────────

test('toast: tek çağrı → mesaj görünür, sınıf "on"; gizlenince sınıf boşalır', (t) => {
  const { sandbox, el, history } = loadToast(t);
  sandbox.toast('Kayıt eklendi');
  assert.strictEqual(el.textContent, 'Kayıt eklendi');
  assert.strictEqual(el.className, 'on');
  t.mock.timers.tick(3200);
  assert.strictEqual(el.className, '');            // TOAST_MS sonunda gizlenir
  t.mock.timers.tick(300);
  assert.strictEqual(el.className, '');            // kuyruk boş → yeni gösterim yok
  assert.deepStrictEqual(history.map(h => h.text), ['Kayıt eklendi']);
});

test('toast: err=true → "on err" sınıfı (renk kontratı korunur)', (t) => {
  const { sandbox, el } = loadToast(t);
  sandbox.toast('Sunucu hatası', true);
  assert.strictEqual(el.className, 'on err');
});

test('toast: #toast elementi yoksa sessiz no-op — throw etmez, timer kurmaz', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { sandbox } = loadBrowserModule(HELPERS, { dom: makeDomStub() });
  t.after(() => t.mock.timers.reset());
  assert.doesNotThrow(() => sandbox.toast('yok', true));
  t.mock.timers.tick(10000); // hiçbir şey patlamamalı
});

// ── Kuyruk davranışı ──────────────────────────────────────────────────

test('toast: görünür mesaj EZİLMEZ — ikinci mesaj kuyruğa girer, sırası gelince görünür', (t) => {
  const { sandbox, el } = loadToast(t);
  sandbox.toast('birinci');
  sandbox.toast('ikinci');
  assert.strictEqual(el.textContent, 'birinci');  // ezilmedi
  t.mock.timers.tick(3200);
  assert.strictEqual(el.className, '');            // fade-out boşluğu
  t.mock.timers.tick(300);
  assert.strictEqual(el.textContent, 'ikinci');
  assert.strictEqual(el.className, 'on');
});

test('toast: err bayrağı kuyruktan korunarak gelir — normal→err ardışığı', (t) => {
  const { sandbox, el, history } = loadToast(t);
  sandbox.toast('önce bilgi');
  sandbox.toast('sonra hata', true);
  // Not: tek tick(3500) yetmez — node mock timer'lar işlenme sırasında YENİ
  // planlanan zincir timer'ı aynı pencerede ateşlemeyebilir; iki adımda ilerlet
  t.mock.timers.tick(3200);
  t.mock.timers.tick(300);
  assert.strictEqual(el.textContent, 'sonra hata');
  assert.strictEqual(el.className, 'on err');
  assert.deepStrictEqual(history.map(h => h.cls), ['on', 'on err']);
});

test('toast: FIFO — üç mesaj giriş sırasıyla gösterilir', (t) => {
  const { sandbox, history } = loadToast(t);
  sandbox.toast('a'); sandbox.toast('b'); sandbox.toast('c');
  drain(t);
  assert.deepStrictEqual(history.map(h => h.text), ['a', 'b', 'c']);
});

test('toast: gap fazında (gizli ama döngü çalışırken) gelen mesaj yine kuyruğa girer', (t) => {
  const { sandbox, el } = loadToast(t);
  sandbox.toast('a');
  t.mock.timers.tick(3200);      // 'a' gizlendi, 300ms gap sayacı işliyor
  assert.strictEqual(el.className, '');
  sandbox.toast('gap-te');       // _toastBusy hâlâ true → kuyruğa girmeli
  t.mock.timers.tick(300);
  assert.strictEqual(el.textContent, 'gap-te');
  assert.strictEqual(el.className, 'on');
});

// ── Kuyruk tavanı (sözleşme madde 4) ──────────────────────────────────

test('toast: kuyruk tavanı 3 — taşmada EN ESKİ bekleyen düşer, mesajlar kaybolur', (t) => {
  const { sandbox, history } = loadToast(t);
  // görünür: a; bekleyen b,c,d sonra e b'yi, f c'yi düşürür → kalan d,e,f
  ['a', 'b', 'c', 'd', 'e', 'f'].forEach(m => sandbox.toast(m));
  drain(t);
  assert.deepStrictEqual(history.map(h => h.text), ['a', 'd', 'e', 'f']);
});

// ── Dedupe (sözleşme madde 5) ─────────────────────────────────────────

test('toast: görünür mesajın birebir tekrarı yutulur — kuyruğa/kayanaya ikinci kez girmez', (t) => {
  const { sandbox, history } = loadToast(t);
  sandbox.toast('aynı hata');
  sandbox.toast('aynı hata');
  drain(t);
  assert.deepStrictEqual(history.map(h => h.text), ['aynı hata']); // 1 kez
});

test('toast: kuyruğun sonundakiyle birebir aynı mesaj yutulur', (t) => {
  const { sandbox, history } = loadToast(t);
  sandbox.toast('a');
  sandbox.toast('tekrar');
  sandbox.toast('tekrar');
  drain(t);
  assert.deepStrictEqual(history.map(h => h.text), ['a', 'tekrar']);
});

test('toast: aynı metin ama FARKLI err bayrağı ayrı mesaj sayılır', (t) => {
  const { sandbox, history } = loadToast(t);
  sandbox.toast('kayıt');
  sandbox.toast('kayıt', true);
  drain(t);
  assert.deepStrictEqual(history.map(h => h.text), ['kayıt', 'kayıt']);
  assert.deepStrictEqual(history.map(h => h.cls), ['on', 'on err']);
});

test('toast: araya başka mesaj girdikten sonra aynı mesaj YENİDEN gösterilir (dedupe yalnız görünür/tail)', (t) => {
  const { sandbox, history } = loadToast(t);
  sandbox.toast('a');
  sandbox.toast('ara');
  sandbox.toast('a');            // tail 'ara' ≠ 'a' → kuyruğa girer
  drain(t);
  assert.deepStrictEqual(history.map(h => h.text), ['a', 'ara', 'a']);
});

// ── Property ──────────────────────────────────────────────────────────

test('toast: property — n farklı mesaj → tam min(n,4) gösterim, FIFO alt kümesi, tekrarsız', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  t.after(() => t.mock.timers.reset());
  fc.assert(fc.property(fc.integer({ min: 1, max: 20 }), (n) => {
    const { sandbox, history } = freshToastModule();
    const msgs = Array.from({ length: n }, (_, i) => `m${i}`);
    msgs.forEach(m => sandbox.toast(m));
    drain(t);
    const shown = history.map(h => h.text);
    assert.strictEqual(shown.length, Math.min(n, 1 + 3), `n=${n}`);
    // n<=4: hepsi; n>4: ilk (anında görünen) + en yeni 3 bekleyen (madde 4:
    // taşmada EN ESKİ bekleyen düşer) — gösterim sırası FIFO korunur
    const expected = n <= 4 ? msgs.slice() : [msgs[0], ...msgs.slice(n - 3)];
    assert.deepStrictEqual(shown, expected, `n=${n}`);
    assert.strictEqual(new Set(shown).size, shown.length, `n=${n}`);      // tekrarsız
  }));
});
