// tests/unit/errorHandler.test.js
// js/utils/errorHandler.js birim testleri — merkezi hata yönetimi.
//
// Notlar:
// - getUserMessage / withErrorHandling / showDebug üst-seviye function bildirimi
//   oldukları için sandbox üzerinde erişilebilir.
// - debugMode yükleme anında localStorage.getItem('debug') === 'true' ile belirlenir
//   (makeStorage({ debug: 'true' }) ile açılır; varsayılan makeStorage() kapalıdır).
// - toast / g / esc tarayıcıda başka scriptlerden gelen bare global'lerdir →
//   opts.extra ile stublanır. console da extra ile stublanarak sessizleştirilir.
//   Dikkat: showDebug modülün KENDİ bildirimidir, extra stub'ı onu gölgelemez —
//   debug dalı testlerinde g üzerinden sahte panel verilir.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeElement, makeStorage } = require('./support/loadModule.js');

// Her test taze modül yükler: debugMode bir kez okunur, window listener'ları
// yükleme anında bağlanır (loader bunları .listeners içinde yakalar).
function yukle(extra = {}, storage) {
  const toastCalls = [];
  const consoleErrors = [];
  const opts = {
    extra: {
      toast: (msg, isErr) => toastCalls.push({ msg, isErr }),
      console: { error: (...a) => consoleErrors.push(a) },
      g: () => null,
      ...extra,
    },
  };
  if (storage) opts.storage = storage;
  const mod = loadBrowserModule('js/utils/errorHandler.js', opts);
  return { ...mod, toastCalls, consoleErrors };
}

// ── getUserMessage: bilinen anahtarlar ───────────────────────────

test('getUserMessage: "Failed to fetch" → internet bağlantısı mesajı', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  const out = sandbox.getUserMessage(new TypeError('Failed to fetch'));
  assert.ok(out.includes('İnternet bağlantısı kesildi'), `beklenen mesaj yerine: ${out}`);
});

test('getUserMessage: "NetworkError" → sunucuya ulaşılamıyor mesajı', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  const out = sandbox.getUserMessage(new Error('NetworkError when attempting to fetch resource.'));
  assert.ok(out.includes('Sunucuya ulaşılamıyor'), `beklenen mesaj yerine: ${out}`);
});

test('getUserMessage: "timeout" → işlem zaman aşımı mesajı', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  const out = sandbox.getUserMessage(new Error('Request timeout after 30s'));
  assert.ok(out.includes('İşlem zaman aşımına uğradı'), `beklenen mesaj yerine: ${out}`);
});

test('getUserMessage: "duplicate key" → kayıt zaten mevcut mesajı', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  const err = { message: 'duplicate key value violates unique constraint "hayvanlar_kupe_no_key"' };
  const out = sandbox.getUserMessage(err);
  assert.ok(out.includes('Bu kayıt zaten mevcut'), `beklenen mesaj yerine: ${out}`);
});

test('getUserMessage: "PGRST" → veritabanı işlemi mesajı', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  const out = sandbox.getUserMessage({ message: 'PGRST-202: schema cache missed' });
  assert.ok(out.includes('Veritabanı işlemi başarısız'), `beklenen mesaj yerine: ${out}`);
});

test('getUserMessage: hiçbir anahtar eşleşmezse genel fallback döner', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  assert.strictEqual(
    sandbox.getUserMessage(new Error('tamamen bilinmeyen hata')),
    'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.'
  );
});

test('getUserMessage: birden çok anahtar eşleşirse Object.entries sırası kazanır', () => {
  // ŞÜPHELİ DAVRANIŞ: eşleşme Object.entries(USER_FRIENDLY) insertion sırasına bağlı.
  // Mesaj hem 'timeout' (3. anahtar) hem 'PGRST' (5. anahtar) içeriyor; listede önce
  // gelen 'timeout' kazanır. Anahtar sırası değişirse davranış değişir — order-dependency.
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  const out = sandbox.getUserMessage(new Error('timeout aşıldı, PGRST-202 döndü'));
  assert.ok(out.includes('İşlem zaman aşımına uğradı'), `kazanan 'timeout' olmalıydı: ${out}`);
  assert.ok(!out.includes('Veritabanı'), `'PGRST' mesajı kazanmamalıydı: ${out}`);
});

test('getUserMessage: err.message yok → String(err) yolu', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  // String err: String(err) bizzat mesaj olur ve eşleşebilir
  assert.ok(sandbox.getUserMessage('timeout oldu').includes('İşlem zaman aşımına uğradı'));
  // .message içermeyen nesne → '[object Object]' → fallback
  assert.strictEqual(sandbox.getUserMessage({}), 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
  // null / undefined → 'null' / 'undefined' → fallback
  assert.strictEqual(sandbox.getUserMessage(null), 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
  assert.strictEqual(sandbox.getUserMessage(undefined), 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
  // Boş mesajlı Error → falsy message → String(err) = 'Error' → fallback
  assert.strictEqual(sandbox.getUserMessage(new Error('')), 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
});

test('getUserMessage: eşleşme BÜYÜK/küçük harfe duyarlıdır', () => {
  // NOT (davranış kaydı): 'failed to fetch' küçük harfle yazıldığında
  // 'Failed to fetch' anahtarıyla eşleşMEZ → genel fallback döner.
  // Gerçek tarayıcı hataları genelde doğru casingde geldiği için çalışır,
  // ama küçük harfli varyant sessizce genel mesaja düşer.
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js');
  assert.strictEqual(
    sandbox.getUserMessage(new Error('failed to fetch')),
    'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.'
  );
});

// ── withErrorHandling ────────────────────────────────────────────

test('withErrorHandling: fonksiyon döner; senkron başarılı sonuç ve argümanlar aynen geçer', async () => {
  const mod = yukle();
  const wrapped = mod.sandbox.withErrorHandling((a, b) => a + b, 'topla');
  assert.strictEqual(typeof wrapped, 'function');
  assert.strictEqual(await wrapped(2, 3), 5);
  assert.strictEqual(mod.toastCalls.length, 0, 'başarıda toast atmamalı');
  assert.strictEqual(mod.consoleErrors.length, 0, 'başarıda console.error atmamalı');
});

test('withErrorHandling: async fn başarılı sonuç aynen geçer', async () => {
  const mod = yukle();
  const wrapped = mod.sandbox.withErrorHandling(async (v) => v * 2, 'ciftle');
  assert.strictEqual(await wrapped(21), 42);
});

test('withErrorHandling: fırlatan fn → null resolve + toast tam 1 kez + console.error', async () => {
  const mod = yukle();
  const wrapped = mod.sandbox.withErrorHandling(() => {
    throw new TypeError('Failed to fetch');
  }, 'kaydet');
  const res = await wrapped();
  assert.strictEqual(res, null);
  assert.strictEqual(mod.toastCalls.length, 1, 'toast tam 1 kez çağrılmalı');
  assert.ok(mod.toastCalls[0].msg.includes('İnternet bağlantısı kesildi'));
  assert.strictEqual(mod.toastCalls[0].isErr, true, 'toast hata bayrağı true olmalı');
  assert.strictEqual(mod.consoleErrors.length, 1, 'console.error tam 1 kez çağrılmalı');
});

test('withErrorHandling: context verilirse console.error öneki "[EgeSüt] context:" olur', async () => {
  const mod = yukle();
  await mod.sandbox.withErrorHandling(() => { throw new Error('x'); }, 'baglam')();
  assert.strictEqual(mod.consoleErrors[0][0], '[EgeSüt] baglam:');
});

test('withErrorHandling: context yoksa önek "[EgeSüt] ?:" olur', async () => {
  const mod = yukle();
  await mod.sandbox.withErrorHandling(() => { throw new Error('x'); })();
  assert.strictEqual(mod.consoleErrors[0][0], '[EgeSüt] ?:');
});

test('withErrorHandling: debugMode kapalıyken showDebug dalı çalışmaz (panel boş kalır)', async () => {
  const panel = makeElement('div');
  const mod = yukle({ g: (id) => (id === 'debugPanel' ? panel : null) }); // varsayılan storage → debug kapalı
  const res = await mod.sandbox.withErrorHandling(() => { throw new Error('x'); }, 'c')();
  assert.strictEqual(res, null);
  assert.strictEqual(panel.children.length, 0, 'debug kapalıyken panele girdi eklenmemeli');
  assert.strictEqual(mod.toastCalls.length, 1, 'toast yine atılmalı');
});

test('withErrorHandling: debugMode açık + panel → panele debug girdisi eklenir (modül kendi escape’i)', async () => {
  // WP-9 fix: showDebug artık global esc stub'ına değil kendi _dbgEsc'ine
  // güveniyor — ham <>& kaçırılır
  const panel = makeElement('div');
  const mod = yukle(
    { g: (id) => (id === 'debugPanel' ? panel : null) },
    makeStorage({ debug: 'true' })
  );
  const res = await mod.sandbox.withErrorHandling(() => { throw new Error('<boom> & "x"'); }, 'testCtx')();
  assert.strictEqual(res, null);
  assert.strictEqual(panel.children.length, 1, 'panele 1 girdi eklenmeli');
  assert.strictEqual(panel.children[0].className, 'debug-entry');
  assert.match(panel.children[0].innerHTML, /testCtx/);
  assert.match(panel.children[0].innerHTML, /&lt;boom&gt;/);
  assert.ok(!/<boom>/.test(panel.children[0].innerHTML), 'ham HTML girmemeli');
});

test('withErrorHandling: esc tanımsız ortamda bile REJECT olmaz (WP-9 — self-contained)', async () => {
  // DÜZELTİLDİ: eskiden showDebug bare global esc'e takılıp ReferenceError ile
  // reject ediyordu ("hata yakalanır, null döner" sözleşmesi bozuluyordu).
  const panel = makeElement('div');
  const mod = yukle({ g: () => panel }, makeStorage({ debug: 'true' })); // esc bilinçli verilmiyor
  const res = await mod.sandbox.withErrorHandling(() => { throw new Error('x'); }, 'c')();
  assert.strictEqual(res, null);
  assert.strictEqual(panel.children.length, 1);
  assert.strictEqual(mod.toastCalls.length, 1);
});

// ── window global yakalayıcıları ─────────────────────────────────

test('yükleme anında window üzerine error ve unhandledrejection dinleyicileri eklenir', () => {
  const mod = yukle();
  assert.strictEqual(mod.listeners.error.length, 1);
  assert.strictEqual(mod.listeners.unhandledrejection.length, 1);
});

test('unhandledrejection dinleyicisi: toast "Beklenmeyen bir hata oluştu." + console.error', () => {
  const mod = yukle();
  const reason = new Error('asenkron patlama');
  mod.listeners.unhandledrejection[0]({ reason });
  assert.strictEqual(mod.toastCalls.length, 1);
  assert.strictEqual(mod.toastCalls[0].msg, 'Beklenmeyen bir hata oluştu.');
  assert.strictEqual(mod.toastCalls[0].isErr, true);
  assert.strictEqual(mod.consoleErrors.length, 1);
  assert.strictEqual(mod.consoleErrors[0][0], '[EgeSüt] Unhandled:');
  assert.strictEqual(mod.consoleErrors[0][1], reason);
});

test('error dinleyicisi: "[EgeSüt] Global error:" ile loglar, toast atmaz (debug kapalı)', () => {
  const mod = yukle();
  mod.listeners.error[0]({ message: 'pat', filename: 'a.js', lineno: 7, error: new Error('pat') });
  assert.strictEqual(mod.consoleErrors.length, 1);
  assert.deepStrictEqual(mod.consoleErrors[0], ['[EgeSüt] Global error:', 'pat', 'a.js', 7]);
  assert.strictEqual(mod.toastCalls.length, 0, 'error dinleyicisi toast atmamalı');
});
