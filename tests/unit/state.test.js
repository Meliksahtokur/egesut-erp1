const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { loadBrowserModule } = require('./support/loadModule.js');

// js/state.js tarayıcı-global modüldür (module.exports yok) — vm loader ile yüklenir.
// AppState sınıfı lexical'tir, expose ile dışarı çıkarılır. Loader aynı zamanda
// sandbox üzerinde getState/setState fonksiyonlarını ve globalThis.__state
// singleton'ını hazır hale getirir. Her test kendi taze AppState örneğini yaratır.
const { sandbox, exposed } = loadBrowserModule('js/state.js', { expose: ['AppState'] });
const AppState = exposed.AppState;

// ── Başlangıç değerleri ─────────────────────────────────────────
test('AppState: başlangıç değerleri — sayfa, filtre, sıralama ve sekmeler', () => {
  const app = new AppState();
  assert.strictEqual(app.get('currentPage'), 'dash');
  assert.strictEqual(app.get('suruFilter'), 'tumuu');
  assert.strictEqual(app.get('suruSiralama'), 'kupe');
  assert.strictEqual(app.get('currentUremeTab'), 'kizginlik');
  assert.strictEqual(app.get('currentHistoryFilter'), 'hepsi');
  assert.strictEqual(app.get('currentTaskFilter'), 'today');
  assert.strictEqual(app.get('currentNotificationTab'), 'bekliyor');
});

test('AppState: başlangıç değerleri — null alanlar ve boş koleksiyonlar', () => {
  const app = new AppState();
  assert.strictEqual(app.get('curStok'), null);
  assert.strictEqual(app.get('currentTaskDetail'), null);
  assert.strictEqual(app.get('currentDisease'), null);
  assert.strictEqual(app.get('currentInsem'), null);
  // NOT: koleksiyonlar vm realm'inde yaratılır — host instanceof/deepStrictEqual
  // cross-realm çalışmaz; Array.isArray ve yapısal kontroller kullanılır.
  for (const k of ['animals', 'stock', 'gebeIds', 'tedaviPlan']) {
    assert.ok(Array.isArray(app.get(k)), `${k} dizi olmalı`);
    assert.strictEqual(app.get(k).length, 0, `${k} boş başlamalı`);
  }
  const hastaIds = app.get('hastaIds');
  assert.strictEqual(typeof hastaIds.has, 'function', 'hastaIds Set arayüzü taşır (.has)');
  assert.strictEqual(typeof hastaIds.add, 'function', 'hastaIds Set arayüzü taşır (.add)');
  assert.strictEqual(hastaIds.size, 0);
  const undo = app.get('aktifSeansUndo');
  assert.strictEqual(typeof undo.get, 'function', 'aktifSeansUndo Map arayüzü taşır (.get)');
  assert.strictEqual(typeof undo.set, 'function', 'aktifSeansUndo Map arayüzü taşır (.set)');
  assert.strictEqual(undo.size, 0);
});

test('AppState: her yeni örnek bağımsızdır — state ve dinleyiciler paylaşılır değil', () => {
  const a = new AppState();
  const b = new AppState();
  a.set('currentPage', 'x');
  assert.strictEqual(b.get('currentPage'), 'dash');
  // koleksiyonlar da örnek başına yeniden yaratılır
  assert.notStrictEqual(a.get('animals'), b.get('animals'));
  a.get('hastaIds').add('H1');
  assert.strictEqual(b.get('hastaIds').size, 0);
  // dinleyiciler de örneye özeldir: b'nin set'i a'nın dinleyicisini tetiklemez
  let fired = 0;
  a.on('*', () => fired++);
  b.set('currentPage', 'y');
  assert.strictEqual(fired, 0);
});

// ── get / getAll ────────────────────────────────────────────────
test('get: bilinen anahtar değerini, bilinmeyen anahtar undefined döner', () => {
  const app = new AppState();
  assert.strictEqual(app.get('currentPage'), 'dash');
  assert.strictEqual(app.get('boyleBirAnahtarYok'), undefined);
});

test('getAll: shallow copy — kopya üzerindeki atama state\'i etkilemez', () => {
  const app = new AppState();
  const copy = app.getAll();
  assert.notStrictEqual(copy, app.getAll(), 'her çağrı yeni bir nesne döner');
  copy.currentPage = 'degisti';
  copy.curStok = { x: 1 };
  assert.strictEqual(app.get('currentPage'), 'dash');
  assert.strictEqual(app.get('curStok'), null);
});

test('getAll: kopya içerik olarak state ile birebir aynıdır; iç içe referanslar paylaşılır (shallow)', () => {
  const app = new AppState();
  assert.deepStrictEqual(app.getAll(), app.getAll());
  // shallow copy semantiği: dizi/Set/Map referansları kopyayla paylaşılır (mevcut davranış)
  assert.strictEqual(app.getAll().hastaIds, app.get('hastaIds'));
  assert.strictEqual(app.getAll().animals, app.get('animals'));
});

// ── set ─────────────────────────────────────────────────────────
test('set: değer değişince key event (value, old) ve ardından "*" event (key, value, old) tetiklenir', () => {
  const app = new AppState();
  const calls = [];
  app.on('currentPage', (...a) => calls.push(['key', ...a]));
  calls.length = 0; // on() anındaki mevcut-değer çağrısını temizle
  app.on('*', (...a) => calls.push(['star', ...a]));
  app.set('currentPage', 'hayvanlar');
  assert.deepStrictEqual(calls, [
    ['key', 'hayvanlar', 'dash'],
    ['star', 'currentPage', 'hayvanlar', 'dash'],
  ]);
});

test('set: aynı değeri tekrar atamak hiçbir event tetiklemez', () => {
  const app = new AppState();
  let fired = 0;
  app.on('suruFilter', () => fired++); // anında çağrı → 1
  app.on('*', () => fired++);          // "*" anında çağrılmaz
  fired = 0;
  app.set('suruFilter', 'tumuu'); // varsayılanla aynı
  assert.strictEqual(fired, 0);
  assert.strictEqual(app.get('suruFilter'), 'tumuu');
});

test('set: state\'te olmayan yeni anahtar — old undefined ile tetiklenir', () => {
  const app = new AppState();
  const args = [];
  app.on('yeniAnahtar', (...a) => args.push(a)); // undefined → anında çağrı olmaz
  app.set('yeniAnahtar', 42);
  assert.deepStrictEqual(args, [[42, undefined]]);
  assert.strictEqual(app.get('yeniAnahtar'), 42);
});

test('set: property — set sonrası get her zaman atanan değeri döner', () => {
  fc.assert(fc.property(
    fc.string().map(s => 'kp_' + s), // '__proto__' gibi özel anahtarları ele
    fc.string(),
    (k, v) => {
      const app = new AppState();
      app.set(k, v);
      assert.strictEqual(app.get(k), v);
    }
  ));
});

test('set: property — aynı değerin ikinci ataması event üretmez', () => {
  fc.assert(fc.property(
    fc.string().map(s => 'kp_' + s),
    fc.string(),
    (k, v) => {
      const app = new AppState();
      let fired = 0;
      app.on(k, () => fired++); // k henüz state'te yok → anında çağrı olmaz
      app.set(k, v);            // değişim → tam 1 tetiklenme
      assert.strictEqual(fired, 1);
      app.set(k, v);            // aynı değer → yeni tetiklenme yok
      assert.strictEqual(fired, 1);
    }
  ));
});

// ── on ──────────────────────────────────────────────────────────
test('on: anahtar aboneliği anında mevcut değerle çağrılır (non-"*")', () => {
  const app = new AppState();
  const got = [];
  app.on('suruSiralama', v => got.push(v));
  assert.deepStrictEqual(got, ['kupe']);
});

test('on: "*" aboneliği anında çağrılmaz', () => {
  const app = new AppState();
  let fired = 0;
  app.on('*', () => fired++);
  assert.strictEqual(fired, 0);
});

test('on: undefined değerli anahtara abonelik anında çağrılmaz', () => {
  const app = new AppState();
  let fired = 0;
  app.on('boyleBirAnahtarYok', () => fired++);
  assert.strictEqual(fired, 0);
});

test('on: dönen fonksiyon aboneliği kaldırır (unsubscribe)', () => {
  const app = new AppState();
  let fired = 0;
  const unsub = app.on('currentPage', () => fired++);
  fired = 0; // anında çağrıyı temizle
  unsub();
  app.set('currentPage', 'test');
  assert.strictEqual(fired, 0);
});

// ── off ─────────────────────────────────────────────────────────
test('off: callback kaldırılır — sonraki set tetiklemez', () => {
  const app = new AppState();
  let fired = 0;
  const cb = () => fired++;
  app.on('currentPage', cb); // anında çağrı → 1
  app.off('currentPage', cb);
  fired = 0;
  app.set('currentPage', 'x');
  assert.strictEqual(fired, 0);
});

test('off: kayıtlı olmayan event/listener için no-op (hata fırlatmaz)', () => {
  const app = new AppState();
  assert.doesNotThrow(() => app.off('yokBoyleBirEvent', () => {}));
});

// ── emit ────────────────────────────────────────────────────────
test('emit: yalnızca o event\'in dinleyicileri bilgilendirilir', () => {
  const app = new AppState();
  const gotA = [], gotB = [];
  app.on('evtA', (...a) => gotA.push(a)); // undefined anahtar → anında çağrı olmaz
  app.on('evtB', (...a) => gotB.push(a));
  app.emit('evtA', 1, 2);
  assert.deepStrictEqual(gotA, [[1, 2]]);
  assert.deepStrictEqual(gotB, []);
  app.emit('evtB', 'x');
  assert.deepStrictEqual(gotB, [['x']]);
  assert.strictEqual(gotA.length, 1);
});

test('emit: dinleyicisi olmayan event no-op (hata fırlatmaz)', () => {
  const app = new AppState();
  assert.doesNotThrow(() => app.emit('hicDinleyiciYok', 1, 2, 3));
});

// ── setBatch ────────────────────────────────────────────────────
test('setBatch: yalnızca değişen anahtarlar key event tetikler, değişmeyenler tetiklemez', () => {
  const app = new AppState();
  const events = [];
  app.on('currentPage', () => events.push('currentPage'));
  app.on('suruFilter', () => events.push('suruFilter'));
  events.length = 0; // on() anındaki çağrıları temizle
  app.setBatch({ currentPage: 'hayvanlar', suruFilter: 'tumuu' }); // yalnız currentPage değişir
  assert.deepStrictEqual(events, ['currentPage']);
  assert.strictEqual(app.get('currentPage'), 'hayvanlar');
  assert.strictEqual(app.get('suruFilter'), 'tumuu');
});

test('setBatch: tamamen no-op batch hiçbir event tetiklemez (key de "*" da)', () => {
  const app = new AppState();
  let starFired = 0, keyFired = 0;
  app.on('*', () => starFired++);
  app.on('currentPage', () => keyFired++);   // anında → 1
  app.on('suruSiralama', () => keyFired++);  // anında → 2
  keyFired = 0;
  app.setBatch({ currentPage: 'dash', suruSiralama: 'kupe' }); // ikisi de varsayılanla aynı
  assert.strictEqual(starFired, 0);
  assert.strictEqual(keyFired, 0);
});

test('setBatch: "*" payload\'u {key, value} DİZİSİDİR — set()\'in (key, value, old) argümanlarından FARKLI şekil', () => {
  // ŞÜPHELİ DAVRANIŞ: set() "*" dinleyicisine (key, value, old) pozisyonal argümalar gönderirken
  // setBatch() TEK dizi argümanı gönderir: [{key, value}, ...]. Aynı "*" dinleyicisi iki
  // farklı çağrım şekli alır — dinleyici tarafında şekil kontrolü yapılmadan kullanılırsa
  // hataya açıktır. Mevcut davranış aynen assert edilir.
  const app = new AppState();
  const starArgs = [];
  app.on('*', (...a) => starArgs.push(a));
  app.setBatch({ currentPage: 'stok', curStok: 'S1' });
  assert.strictEqual(starArgs.length, 1);   // "*" dinleyicisi TAM BİR kez çağrılır
  assert.strictEqual(starArgs[0].length, 1); // ve TEK argüman alır: değişiklik dizisi
  // vm realm'inde yaratılan dizi/nesneler — prototip farkı yüzünden loose deepEqual
  assert.deepEqual(starArgs[0][0], [
    { key: 'currentPage', value: 'stok' },
    { key: 'curStok', value: 'S1' },
  ]);
});

test('setBatch: key event tek argüman (value) alır — set() ise (value, old) verir', () => {
  // ŞÜPHELİ DAVRANIŞ (asimetri): setBatch'in anahtar event'i yalnızca YENİ değeri geçirir;
  // set() (value, old) geçirir. old değere ihtiyaç duyan bir dinleyici setBatch yolunda
  // old'u alamaz. Mevcut davranış aynen assert edilir.
  const app = new AppState();
  const args = [];
  app.on('currentTaskFilter', (...a) => args.push(a));
  args.length = 0; // anında çağrıyı temizle
  app.setBatch({ currentTaskFilter: 'all' });
  assert.deepStrictEqual(args, [['all']]);
});

test('setBatch: state güncellemesi tüm anahtarlara uygulanır, "*" bir kez tetiklenir', () => {
  const app = new AppState();
  let starCount = 0;
  app.on('*', () => starCount++);
  app.setBatch({
    currentPage: 'bildirim',
    currentNotificationTab: 'tamamlanan',
    tedaviPlan: [1, 2, 3],
  });
  assert.strictEqual(app.get('currentPage'), 'bildirim');
  assert.strictEqual(app.get('currentNotificationTab'), 'tamamlanan');
  assert.deepStrictEqual(app.get('tedaviPlan'), [1, 2, 3]);
  assert.strictEqual(starCount, 1);
});

test('setBatch: property — batch\'teki her anahtar değeri state\'e yazılır', () => {
  fc.assert(fc.property(
    fc.array(fc.tuple(fc.string().map(s => 'b_' + s), fc.string())),
    (pairs) => {
      const app = new AppState();
      const upd = Object.fromEntries(pairs);
      app.setBatch(upd);
      for (const [k, v] of Object.entries(upd)) {
        assert.strictEqual(app.get(k), v);
      }
    }
  ));
});

test('setBatch: property — hiçbir anahtar değişmezse "*" tetiklenmez', () => {
  const app = new AppState();
  let star = 0;
  app.on('*', () => star++);
  fc.assert(fc.property(fc.string(), (v) => {
    app.set('x_test', v);
    star = 0;
    app.setBatch({ x_test: v }); // az önce atananla aynı değer
    assert.strictEqual(star, 0);
  }));
});

// ── modül düzeyi: getState/setState + __state singleton ─────────
test('getState/setState: globalThis.__state singleton\'ına delege eder', () => {
  assert.strictEqual(sandbox.getState('currentPage'), 'dash');
  sandbox.setState('currentPage', 'hayvanlar');
  assert.strictEqual(sandbox.getState('currentPage'), 'hayvanlar');
  assert.strictEqual(sandbox.__state.get('currentPage'), 'hayvanlar');
});

test('__state: bir AppState örneğidir ve modül varsayılanlarını taşır', () => {
  assert.ok(sandbox.__state instanceof AppState);
  assert.strictEqual(sandbox.__state.get('suruFilter'), 'tumuu');
  assert.strictEqual(sandbox.__state.get('suruSiralama'), 'kupe');
});
