const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const {
  loadBrowserModule,
  loadExtractedFunction,
  makeDomStub,
  makeElement,
} = require('./support/loadModule.js');

// js/utils/helpers.js — henüz test edilmemiş fonksiyonlar:
// escAttr, esc, debounce, throttle, g/v/cl
// (trLower, dAgo, dFwd, fmtTarih, fmtTarihSaat, getDisplayKupe diğer dosyalarda kaplı)

const HELPERS = 'js/utils/helpers.js';

// escAttr'ın ürettiği entity'leri geri çözen yardımcı (round-trip property'si için).
// ÖNEMLİ: &amp; EN SON çözülmeli — aksi halde '&amp;lt;' → '&lt;' → '<' gibi
// zincirlemeli yanlış çözüm oluşur.
function decodeEntities(s) {
  return String(s)
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

// Gerçek tarayıcı textContent→innerHTML semantiğini taklit eden sahte document:
// textContent üzerinden atanan metin innerHTML'e serileştirilirken yalnız
// & < > kaçırılır; tek/çift tırnak KAÇIRILMAZ (bkz. helpers.js:29-33 yorumu).
function makeEscDocument() {
  return {
    createElement: () => {
      const e = { textContent: '' };
      Object.defineProperty(e, 'innerHTML', {
        get() {
          return String(this.textContent ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
        },
      });
      return e;
    },
  };
}

// throttle'ın kullandığı Date.now()'ı elle ilerletilebilir yapan saat stub'ı.
// (vm realm'i kendi intrinsic Date'ine sahiptir; mock.timers buraya ulaşamaz.
//  extra: { Date } ile sandbox globaline stub yerleşir — probe ile doğrulandı.)
function makeClock(start = 1_000_000) {
  let t = start;
  return {
    date: { now: () => t },
    advance(ms) { t += ms; },
    get now() { return t; },
  };
}

// escAttr saf bir fonksiyon — dosya kapsamında bir kez yükle
const helpersSandbox = loadBrowserModule(HELPERS).sandbox;
const escAttr = helpersSandbox.escAttr;

// esc, sandbox stub elementinde innerHTML kaçırma taklit ETMEDİĞİNDEN
// loadExtractedFunction + sahte document ile yüklenir (talimat gereği).
const esc = loadExtractedFunction(HELPERS, 'esc', {
  extra: { document: makeEscDocument() },
});

// ── escAttr ──────────────────────────────────────────────────────────

test('escAttr: beş tehlikeli karakterin her biri doğru entityye kaçar', () => {
  assert.strictEqual(escAttr('&'), '&amp;');
  assert.strictEqual(escAttr('"'), '&quot;');
  assert.strictEqual(escAttr("'"), '&#39;');
  assert.strictEqual(escAttr('<'), '&lt;');
  assert.strictEqual(escAttr('>'), '&gt;');
  // birleşik girdi — & ilk sırada kaçtığı için entitylerin & işareti çift kaçmaz
  assert.strictEqual(escAttr('&<>"\''), '&amp;&lt;&gt;&quot;&#39;');
  // girdi zaten entity GİBİ görünse bile & kaçılır ( kör çözüm yapılmaz)
  assert.strictEqual(escAttr('&lt;'), '&amp;lt;');
});

test('escAttr: null/undefined → boş string', () => {
  assert.strictEqual(escAttr(null), '');
  assert.strictEqual(escAttr(undefined), '');
});

test('escAttr: sayı/boolean String() ile coerce edilir — ?? yalnız nullish yakalar', () => {
  assert.strictEqual(escAttr(0), '0'); // esc ile fark: esc(0) → ''
  assert.strictEqual(escAttr(123), '123');
  assert.strictEqual(escAttr(false), 'false');
  assert.strictEqual(escAttr(true), 'true');
});

test('escAttr: property — çıktıda ham < > " \' karakteri kalmaz', () => {
  fc.assert(fc.property(fc.string(), (s) => {
    const out = escAttr(s);
    assert.ok(!/[<>"']/.test(out), `out=${JSON.stringify(out)}`);
  }));
});

test('escAttr: property — entity decode round-trip orijinal girdiyi geri verir', () => {
  fc.assert(fc.property(fc.string(), (s) => {
    assert.strictEqual(decodeEntities(escAttr(s)), s, `s=${JSON.stringify(s)}`);
  }));
});

// ŞÜPHELİ DAVRANIŞ: escAttr idempotent DEĞİL. İlk geçişin ürettiği entity'lerin
// başındaki & ikinci geçişte yeniden kaçırılır: escAttr('&') = '&amp;' ama
// escAttr('&amp;') = '&amp;amp;'. Yani escape edilmiş metin üzerine bir daha
// escape uygulanırsa metin bozulur. Mevcut davranış aşağıda belgelenir.
test('escAttr: idempotent DEĞİL — ikinci geçiş entity & işaretini yeniden kaçırır (mevcut davranış)', () => {
  assert.strictEqual(escAttr(escAttr('&')), '&amp;amp;');
  assert.strictEqual(escAttr(escAttr('<')), '&amp;lt;');
  assert.strictEqual(escAttr(escAttr('"')), '&amp;quot;');
  assert.strictEqual(escAttr(escAttr("'")), '&amp;#39;');
});

test('escAttr: property — metakarakter (& < > " \') içermeyen girdide identity, dolayısıyla idempotent', () => {
  fc.assert(fc.property(fc.stringMatching(/^[^&<>"']*$/), (s) => {
    assert.strictEqual(escAttr(s), s, `s=${JSON.stringify(s)}`);
    assert.strictEqual(escAttr(escAttr(s)), escAttr(s));
  }));
});

// ── esc ──────────────────────────────────────────────────────────────

test('esc: null/undefined/boş string → boş string', () => {
  assert.strictEqual(esc(null), '');
  assert.strictEqual(esc(undefined), '');
  assert.strictEqual(esc(''), '');
});

test('esc: & < > kaçırılır, düz metin aynen döner', () => {
  assert.strictEqual(esc('&<>'), '&amp;&lt;&gt;');
  assert.strictEqual(esc('a&b<c>d'), 'a&amp;b&lt;c&gt;d');
  assert.strictEqual(esc('<script>'), '&lt;script&gt;');
  assert.strictEqual(esc('abc çğıöşü 123'), 'abc çğıöşü 123');
});

test('esc: tek/çift tırnak KAÇIRILMAZ — escAttr ile belgelenmiş fark (helpers.js:29-33)', () => {
  assert.strictEqual(esc('"\''), '"\'');
  assert.strictEqual(esc("a=\"b\" c='d'"), 'a="b" c=\'d\'');
  // kontrast: escAttr aynı girdide tırnakları da kaçırır
  assert.strictEqual(escAttr('"\''), '&quot;&#39;');
});

// ŞÜPHELİ DAVRANIŞ: esc `str || ''` kullanır — 0/false gibi falsy (ama nullish
// olmayan) girdiler ''ye düşer. esc(0) === '' iken escAttr(0) === '0'.
// Sayısal 0'ın gösterimi esc ile kaybolur. Mevcut davranış belgelenir.
test('esc: 0 ve false → boş string (falsy coerce, ŞÜPHELİ DAVRANIŞ); 123 → "123"', () => {
  assert.strictEqual(esc(0), '');
  assert.strictEqual(esc(false), '');
  assert.strictEqual(esc(123), '123');
});

// ── debounce ─────────────────────────────────────────────────────────
// Mock zamanlayıcı ENABLE edildikten SONRA modül yüklenmelidir — loader
// sandbox'a o anki global setTimeout referansını kopyalar (probe ile doğrulandı).

test('debounce: hızlı n çağrı → delay dolunca tam 1 kez, SON argümanlarla çalışır', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { sandbox } = loadBrowserModule(HELPERS);
  t.after(() => t.mock.timers.reset());

  let calls = 0, lastArgs = null;
  const d = sandbox.debounce((...a) => { calls++; lastArgs = a; }, 100);
  d('a'); d('b'); d('c');
  assert.strictEqual(calls, 0); // delay dolmadan çalışmaz
  t.mock.timers.tick(100);
  assert.strictEqual(calls, 1);
  assert.deepStrictEqual(lastArgs, ['c']); // son çağrının argümanları
});

test('debounce: hiç çağrı yoksa fn hiç çalışmaz', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { sandbox } = loadBrowserModule(HELPERS);
  t.after(() => t.mock.timers.reset());

  let calls = 0;
  sandbox.debounce(() => { calls++; }, 100);
  t.mock.timers.tick(1000);
  assert.strictEqual(calls, 0);
});

test('debounce: her yeni çağrı sayacı baştan başlatır (varsayılan delay = 300)', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { sandbox } = loadBrowserModule(HELPERS);
  t.after(() => t.mock.timers.reset());

  let calls = 0, lastArg = null;
  const d = sandbox.debounce((a) => { calls++; lastArg = a; }); // delay verilmedi → 300
  d(1);
  t.mock.timers.tick(299);
  assert.strictEqual(calls, 0);
  d(2); // sayaç sıfırlandı — yeniden 300 beklenir
  t.mock.timers.tick(299);
  assert.strictEqual(calls, 0);
  t.mock.timers.tick(1);
  assert.strictEqual(calls, 1);
  assert.strictEqual(lastArg, 2);
});

test('debounce: property — 1..50 hızlı çağrı her zaman tam 1 çalışmaya düşer', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { sandbox } = loadBrowserModule(HELPERS);
  t.after(() => t.mock.timers.reset());

  fc.assert(fc.property(fc.integer({ min: 1, max: 50 }), (n) => {
    let calls = 0, lastArg = null;
    const d = sandbox.debounce((a) => { calls++; lastArg = a; }, 50);
    for (let i = 0; i < n; i++) d(i);
    t.mock.timers.tick(50);
    assert.strictEqual(calls, 1, `n=${n}`);
    assert.strictEqual(lastArg, n - 1, `n=${n}`);
  }));
});

// ── throttle ─────────────────────────────────────────────────────────
// Date.now() elle ilerletilebilir saat stub'ıyla değiştirilir (makeClock).

test('throttle: leading edge — ilk çağrı anında çalışır ve argümanları iletir', () => {
  const clock = makeClock();
  const { sandbox } = loadBrowserModule(HELPERS, { extra: { Date: clock.date } });

  let calls = 0, lastArgs = null;
  const th = sandbox.throttle((...a) => { calls++; lastArgs = a; }, 100);
  th('x');
  assert.strictEqual(calls, 1);
  assert.deepStrictEqual(lastArgs, ['x']);
});

test('throttle: limit penceresi içindeki çağrılar sessizce düşürülür', () => {
  const clock = makeClock();
  const { sandbox } = loadBrowserModule(HELPERS, { extra: { Date: clock.date } });

  let calls = 0;
  const th = sandbox.throttle(() => { calls++; }, 100);
  th();                     // t=1.000.000 → leading, çalışır
  clock.advance(50);  th(); // 50 < 100 → düşer
  clock.advance(49);  th(); // toplam 99 < 100 → düşer
  assert.strictEqual(calls, 1);
});

test('throttle: pencere tam dolunca (>= limit) sonraki çağrı tekrar çalışır', () => {
  const clock = makeClock();
  const { sandbox } = loadBrowserModule(HELPERS, { extra: { Date: clock.date } });

  let calls = 0;
  const th = sandbox.throttle(() => { calls++; }, 100);
  th();                     // t=1.000.000 → çalışır (last=0 → now-0 >= limit)
  clock.advance(100); th(); // tam sınır — now-last = 100 >= 100 → çalışır
  assert.strictEqual(calls, 2);
  clock.advance(99);  th(); // 99 < 100 → düşer
  assert.strictEqual(calls, 2);
  clock.advance(1);   th(); // kalan 1ms ile sınır doldu → çalışır
  assert.strictEqual(calls, 3);
});

test('throttle: property — aynı anda n çağrı tam 1 çalışma; pencere geçince yeniden açılır', () => {
  const clock = makeClock();
  const { sandbox } = loadBrowserModule(HELPERS, { extra: { Date: clock.date } });

  fc.assert(fc.property(
    fc.integer({ min: 1, max: 50 }),
    fc.integer({ min: 1, max: 500 }),
    (n, limit) => {
      let calls = 0;
      const th = sandbox.throttle(() => { calls++; }, limit);
      for (let i = 0; i < n; i++) th(); // hepsi aynı anda → yalnız leading
      assert.strictEqual(calls, 1, `n=${n}, limit=${limit}`);
      clock.advance(limit); th();       // pencere doldu → yeniden çalışır
      assert.strictEqual(calls, 2, `n=${n}, limit=${limit}`);
      clock.advance(Math.max(0, limit - 1)); th(); // hâlâ pencere içi (limit-1 < limit) → düşer
      assert.strictEqual(calls, 2, `n=${n}, limit=${limit}`);
    }
  ));
});

// ── g / v / cl ───────────────────────────────────────────────────────

test('g: id varsa element referansını, yoksa null döner', () => {
  const doc = makeDomStub();
  const { sandbox } = loadBrowserModule(HELPERS, { dom: doc });
  const inp = doc.__setEl('f-kupe', makeElement('input'));

  assert.strictEqual(sandbox.g('f-kupe'), inp); // birebir aynı referans
  assert.strictEqual(sandbox.g('boyle-yok'), null);
});

test('v: element varsa value; element yoksa veya value boşsa boş string', () => {
  const doc = makeDomStub();
  const { sandbox } = loadBrowserModule(HELPERS, { dom: doc });
  const inp = doc.__setEl('f-kupe', makeElement('input'));

  inp.value = 'TR-1234';
  assert.strictEqual(sandbox.v('f-kupe'), 'TR-1234');
  inp.value = '';
  assert.strictEqual(sandbox.v('f-kupe'), '');
  assert.strictEqual(sandbox.v('boyle-yok'), ''); // element yok → hata değil ''
});

// ŞÜPHELİ DAVRANIŞ: v `g(id)?.value || ''` kullanır — value falsy ise (0, false)
// '0'/'false' değil '' döner. Gerçek DOM'da input.value her zaman string
// olduğundan pratik etkisi yok; ama stub/limitli ortamlarda kayıp veridir.
test('v: falsy value (0) → boş string, "0" değil (|| koalesansı, ŞÜPHELİ DAVRANIŞ)', () => {
  const doc = makeDomStub();
  const { sandbox } = loadBrowserModule(HELPERS, { dom: doc });
  const inp = doc.__setEl('f-sayi', makeElement('input'));

  inp.value = 0; // sayı — gerçek DOM'da olmaz, stub ortamında mümkün
  assert.strictEqual(sandbox.v('f-sayi'), '');
});

test('cl: element varsa yalnız valueyu temizler; element yoksa hata fırlamaz', () => {
  const doc = makeDomStub();
  const { sandbox } = loadBrowserModule(HELPERS, { dom: doc });
  const inp = doc.__setEl('f-kupe', makeElement('input'));
  inp.value = 'TR-1234';

  sandbox.cl('f-kupe');
  assert.strictEqual(inp.value, '');
  assert.strictEqual(doc.getElementById('f-kupe'), inp); // element DOM'da kalır

  assert.doesNotThrow(() => sandbox.cl('boyle-yok')); // sessizce boş geçer
});
