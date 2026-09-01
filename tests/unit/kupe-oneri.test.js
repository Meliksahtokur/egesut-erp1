const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { loadBrowserModule } = require('./support/loadModule.js');

// js/config.js tarayıcı-global modülüdür — üst-seviye `function` bildirimleri
// sandbox property'si olur; `const` sabitler expose ile dışarı çıkarılır.
const { sandbox, exposed } = loadBrowserModule('js/config.js', {
  expose: ['KUPE_ERKEK_MIN', 'KUPE_ERKEK_MAX'],
});
const { bosKupeOner, erkekKupeUygunMu } = sandbox;
const { KUPE_ERKEK_MIN, KUPE_ERKEK_MAX } = exposed;

// ═════════════════════════════════════════════════════════════════
// Spec: .claude/specs/2026-09-01-buzagi-kupe-revizyon-kararlar.md
// K5  Erkek + sayısal küpe → 500-599 zorunlu (sayısal OLMAYAN serbest)
// K9  Sıfır-trick: "02" ve "002" aynı 2'yi işgal eder sayılır (sayısal uzay)
// K10 Dişi havuzu = 1..999 \ 500..599, öneri KÜÇÜKTEN BÜYÜĞE
// K11 Erkek havuzu = yalnız 500..599
// Havuzda YOK: aktiflerin elindeki numaralar; VAR: çıkmışlarınkiler
// ═════════════════════════════════════════════════════════════════

// ── erkekKupeUygunMu (K5) ─────────────────────────────────────────
test('erkekKupeUygunMu: erkek + sayısal 500-599 dışı → false', () => {
  assert.strictEqual(erkekKupeUygunMu('612', 'Erkek'), false);
  assert.strictEqual(erkekKupeUygunMu('499', 'Erkek'), false);
  assert.strictEqual(erkekKupeUygunMu('1', 'Erkek'), false);
  assert.strictEqual(erkekKupeUygunMu('999', 'Erkek'), false);
});

test('erkekKupeUygunMu: erkek + 500-599 → true; sınır değerler dahil', () => {
  assert.strictEqual(erkekKupeUygunMu('500', 'Erkek'), true);
  assert.strictEqual(erkekKupeUygunMu('599', 'Erkek'), true);
  assert.strictEqual(erkekKupeUygunMu('550', 'Erkek'), true);
});

test('erkekKupeUygunMu: dişi her sayısal küpeye uygun (5xx dahil)', () => {
  assert.strictEqual(erkekKupeUygunMu('612', 'Dişi'), true);
  assert.strictEqual(erkekKupeUygunMu('5', 'Dişi'), true);
  assert.strictEqual(erkekKupeUygunMu('999', 'Dişi'), true);
});

test('erkekKupeUygunMu: sayısal OLMAYAN küpe her cinsiyet için serbest (kural yalnız sayısala)', () => {
  assert.strictEqual(erkekKupeUygunMu('Test', 'Erkek'), true);
  assert.strictEqual(erkekKupeUygunMu('TR-01', 'Erkek'), true);
  assert.strictEqual(erkekKupeUygunMu('', 'Erkek'), true);
  assert.strictEqual(erkekKupeUygunMu(null, 'Erkek'), true);
  assert.strictEqual(erkekKupeUygunMu(undefined, 'Erkek'), true);
});

test('erkekKupeUygunMu: cinsiyet null/boş → kural uygulanmaz', () => {
  assert.strictEqual(erkekKupeUygunMu('612', null), true);
  assert.strictEqual(erkekKupeUygunMu('612', ''), true);
  assert.strictEqual(erkekKupeUygunMu('612', undefined), true);
});

// ── bosKupeOner — erkek havuzu (K11) ──────────────────────────────
test('bosKupeOner: erkek → yalnız 500-599 arası, boşlar küçükten büyüğe', () => {
  const oneri = bosKupeOner([], 'Erkek', 5);
  assert.deepEqual(oneri, ['500', '501', '502', '503', '504']);
});

test('bosKupeOner: erkek → 500-599 aralığı DIŞINA asla taşmaz (tam havuz = 100 eleman)', () => {
  const tumu = bosKupeOner([], 'Erkek', 1000);
  assert.strictEqual(tumu.length, 100);
  assert.strictEqual(tumu[0], '500');
  assert.strictEqual(tumu[99], '599');
});

test('bosKupeOner: erkek → aktif erkeğin 5xx numarası havuzda YOK', () => {
  const dolu = [
    { kupe_no: '500', durum: 'Aktif', cinsiyet: 'Erkek' },
    { kupe_no: '503', durum: 'Aktif', cinsiyet: 'Erkek' },
  ];
  assert.deepEqual(bosKupeOner(dolu, 'Erkek', 3), ['501', '502', '504']);
});

test('bosKupeOner: erkek → ÇIKMIŞ hayvanın 5xx numarası havuza DÖNER (recycle K1/K12)', () => {
  const dolu = [
    { kupe_no: '500', durum: 'Satıldı', cinsiyet: 'Erkek' },
    { kupe_no: '501', durum: 'Öldü', cinsiyet: 'Erkek' },
  ];
  assert.deepEqual(bosKupeOner(dolu, 'Erkek', 3), ['500', '501', '502']);
});

// ── bosKupeOner — dişi havuzu (K10) ───────────────────────────────
test("bosKupeOner: dişi → 1'den başlar ascending, 500-599 ASLA önerilmez", () => {
  const oneri = bosKupeOner([{ kupe_no: '1', durum: 'Aktif' }], 'Dişi', 5);
  assert.deepEqual(oneri, ['2', '3', '4', '5', '6']);
});

test('bosKupeOner: dişi → 499 doluysa sıradaki 600 (5xx atlanır)', () => {
  const dolu = [];
  for (let n = 1; n <= 499; n++) dolu.push({ kupe_no: String(n), durum: 'Aktif' });
  const oneri = bosKupeOner(dolu, 'Dişi', 3);
  assert.deepEqual(oneri, ['600', '601', '602']);
});

test('bosKupeOner: dişi → tam havuz 1..999 \\ 500..599 = 899 eleman', () => {
  const tumu = bosKupeOner([], 'Dişi', 2000);
  assert.strictEqual(tumu.length, 899);
  assert.strictEqual(tumu[898], '999');
  assert.ok(!tumu.some(k => { const n = parseInt(k, 10); return n >= 500 && n <= 599; }),
    'dişi havuzunda 5xx numara olmamalı');
});

// ── bosKupeOner — doluluk uzayı (K9 sıfır-trick) ──────────────────
test('bosKupeOner: aktif "02" → sayısal uzayda 2 dolu sayılır (K9 sıfır-trick)', () => {
  const dolu = [{ kupe_no: '02', durum: 'Aktif' }];
  assert.deepEqual(bosKupeOner(dolu, 'Dişi', 3), ['1', '3', '4']);
});

test("bosKupeOner: aktif \"002\" da aynı 2'yi işgal eder — \"02\" ile \"002\" birlikte 2'yi bloklar", () => {
  const dolu = [{ kupe_no: '002', durum: 'Aktif' }, { kupe_no: '02', durum: 'Aktif' }];
  assert.deepEqual(bosKupeOner(dolu, 'Dişi', 3), ['1', '3', '4']);
});

test('bosKupeOner: sayısal olmayan küpeler (ör. "Test") havuz hesabını etkilemez', () => {
  const dolu = [{ kupe_no: 'Test', durum: 'Aktif' }, { kupe_no: 'TR-5', durum: 'Aktif' }];
  assert.deepEqual(bosKupeOner(dolu, 'Dişi', 2), ['1', '2']);
});

test('bosKupeOner: NULL/boş küpeli ve durumSUZ kayıtlar dolu sayılmaz', () => {
  const dolu = [
    { kupe_no: null, durum: 'Aktif' },
    { kupe_no: '', durum: 'Aktif' },
    { kupe_no: '1' },                       // durum alanı yok → Aktif değil sayılır
    null,                                    // bozuk kayıt — patlamamalı
  ];
  assert.deepEqual(bosKupeOner(dolu, 'Dişi', 2), ['1', '2']);
});

test('bosKupeOner: hayvanlar null/undefined → boş liste gibi davranır', () => {
  assert.deepEqual(bosKupeOner(null, 'Dişi', 2), ['1', '2']);
  assert.deepEqual(bosKupeOner(undefined, 'Erkek', 2), ['500', '501']);
});

test('bosKupeOner: default adet = 10', () => {
  assert.strictEqual(bosKupeOner([], 'Dişi').length, 10);
  assert.strictEqual(bosKupeOner([], 'Erkek').length, 10);
});

// ── sabitler ──────────────────────────────────────────────────────
test('KUPE_ERKEK_MIN/MAX = 500/599 (spec K5/K11)', () => {
  assert.strictEqual(KUPE_ERKEK_MIN, 500);
  assert.strictEqual(KUPE_ERKEK_MAX, 599);
});

// ── property tabanlı kapsama (fast-check) ─────────────────────────
test('property: önerilen HER numara cinsiyet havuzunda ve dolu sayılmaz', () => {
  fc.assert(fc.property(
    fc.array(fc.record({
      kupe_no: fc.option(fc.constantFrom(...['1', '02', '002', '5', '500', '550', '599', '7', 'Test', '999', '600']), { nil: undefined }),
      durum: fc.option(fc.constantFrom(...['Aktif', 'Satıldı', 'Öldü', 'Çıkarıldı']), { nil: undefined }),
    }), { maxLength: 20 }),
    fc.constantFrom(...['Erkek', 'Dişi']),
    fc.integer({ min: 1, max: 50 }),
    (dolu, cins, adet) => {
      const temizDolu = (dolu || []).filter(a => a && a.durum === 'Aktif' && a.kupe_no && /^\d+$/.test(String(a.kupe_no)));
      const doluSet = new Set(temizDolu.map(a => parseInt(a.kupe_no, 10)));
      const oneri = bosKupeOner(dolu, cins, adet);
      assert.ok(oneri.length <= adet);
      for (const k of oneri) {
        const n = parseInt(k, 10);
        assert.ok(/^\d+$/.test(k), `öneri sayısal olmalı: ${k}`);
        assert.ok(!doluSet.has(n), `dolu numara önerildi: ${k}`);
        if (cins === 'Erkek') assert.ok(n >= 500 && n <= 599, `erkek 5xx dışı önerildi: ${k}`);
        else assert.ok(n >= 1 && n <= 999 && !(n >= 500 && n <= 599), `dişi havuz dışı önerildi: ${k}`);
      }
      // ascending sıra
      const sayisal = oneri.map(Number);
      for (let i = 1; i < sayisal.length; i++) assert.ok(sayisal[i] > sayisal[i - 1], 'öneri ascending olmalı');
    }
  ), { numRuns: 200 });
});

test('property: erkekKupeUygunMu ↔ bosKupeOner erkek havuzu tutarlı', () => {
  fc.assert(fc.property(fc.integer({ min: 1, max: 999 }), (n) => {
    const k = String(n);
    // erkek için: öneri havuzundaki (500-599) her numara uygun, dışındaki sayısal numara uygun değil
    assert.strictEqual(erkekKupeUygunMu(k, 'Erkek'), n >= 500 && n <= 599);
    // dişi için sayısal her zaman uygun
    assert.strictEqual(erkekKupeUygunMu(k, 'Dişi'), true);
  }), { numRuns: 300 });
});

// ── ui.js hayvanByKupeRef (K7 aktif-öncelik resolver) ────────────
// Cerrahi extraction: ui.js'in tamamı yüklenmeden sadece bu fonksiyon test edilir.
// Fonksiyon gövdesi global getState kullanır — kaynak metni getState stub'lı
// taze vm context'inde değerlendirip hayvan listesini enjekte ediyoruz.
test('hayvanByKupeRef: aktif-öncelik + id/küpe/devlet eşleşmesi (K7)', () => {
  const { extractFunctionSource } = require('./support/loadModule.js');
  const vm = require('node:vm');
  const src = extractFunctionSource('js/ui.js', 'hayvanByKupeRef');
  const mk = (list) => vm.runInContext(`(${src})`, vm.createContext({ getState: () => list }));

  const aktif = { id: 'h-yeni', kupe_no: '7', devlet_kupe: 'TR-7', durum: 'Aktif' };
  const cikan = { id: 'h-eski', kupe_no: '7', devlet_kupe: 'TR-9', durum: 'Öldü' };

  const fKarishik = mk([cikan, aktif]);
  assert.strictEqual(fKarishik('7'), aktif, 'küpe eşleşmesinde aktif önce (sıra ne olursa olsun)');
  assert.strictEqual(fKarishik('h-eski'), cikan, 'id eşleşmesi aynen çalışır');
  assert.strictEqual(fKarishik('TR-7'), aktif, 'devlet küpesi eşleşmesi aynen çalışır');
  assert.strictEqual(fKarishik('TR-9'), cikan, 'çıkışlı hayvanın devlet küpesi hâlâ bulunur');

  const fSadeceCikan = mk([cikan]);
  assert.strictEqual(fSadeceCikan('7'), cikan, 'aktif yoksa çıkışlı bulunur (geriye uyumlu)');

  assert.strictEqual(mk([])('7'), undefined, 'boş listede undefined');
  assert.strictEqual(mk([aktif])(null), undefined, 'null referans → undefined');
  assert.strictEqual(mk([null, aktif])('7'), aktif, 'bozuk (null) kayıt patlatmaz');
});

// ── ui.js kupeOnerGoster/kupeOnerSec (K6 öneri butonu akışı) ────
// Her iki handler da cerrahi extraction ile alınır; document/getState/bosKupeOner
// stub+gerçek karışımı tek vm context'ine bağlanır. Chip'ler HTML attribute
// onclick ile render edilmeli (modal router kuralı — DOM property YASAK).
test('kupeOnerGoster/Sec: cinsiyete göre chip render, inline onclick, seçim inputa yazılır', () => {
  const { extractFunctionSource, makeDomStub, makeElement } = require('./support/loadModule.js');
  const vm = require('node:vm');
  const srcG = extractFunctionSource('js/ui.js', 'kupeOnerGoster');
  const srcS = extractFunctionSource('js/ui.js', 'kupeOnerSec');

  const doc = makeDomStub();
  const bInput = doc.__setEl('b-kupe', Object.assign(makeElement('input'), { value: '' }));
  doc.__setEl('b-cins', Object.assign(makeElement('select'), { value: 'Erkek' }));
  const bListe = doc.__setEl('b-kupe-oner-list', makeElement('div'));
  const aInput = doc.__setEl('a-kupe', Object.assign(makeElement('input'), { value: '' }));
  doc.__setEl('a-cinsiyet', Object.assign(makeElement('select'), { value: '' })); // cinsiyet BOŞ
  const aListe = doc.__setEl('a-kupe-oner-list', makeElement('div'));

  let kontrolTetiklenen = null;
  const ctx = vm.createContext({
    document: doc,
    getState: () => [{ id: 'h1', kupe_no: '500', durum: 'Aktif' }], // erkek 500 dolu
    bosKupeOner, // gerçek config.js fonksiyonu (drift olmasın)
    _kupeKontrolEt: (alan) => { kontrolTetiklenen = alan; },
  });
  const fns = vm.runInContext(`({ goster: ${srcG}, sec: ${srcS} })`, ctx);

  // Erkek havuzu: 500 dolu → ilk öneri 501; chip inline onclick attribute'lu
  fns.goster('b-kupe');
  assert.strictEqual(bListe.style.display, 'flex');
  assert.ok(bListe.innerHTML.includes('ek-chip'), 'mevcut chip sınıfı kullanılmalı');
  assert.ok(bListe.innerHTML.includes("kupeOnerSec('b-kupe','501')"),
    'chip HTML attribute onclick ile inline bağlanmalı (modal router kuralı)');
  assert.ok(!bListe.innerHTML.includes("'500'"), 'aktif hayvanın numarası önerilmez');

  // Tekrar tık → kapanır (toggle)
  fns.goster('b-kupe');
  assert.strictEqual(bListe.style.display, 'none');

  // Manuel form + cinsiyet boş → dişi havuzu + açıklayıcı not
  fns.goster('a-kupe');
  assert.strictEqual(aListe.style.display, 'flex');
  assert.ok(aListe.innerHTML.includes('Cinsiyet seçili değil'), 'dişi havuzu notu gösterilmeli');
  assert.ok(aListe.innerHTML.includes("kupeOnerSec('a-kupe','1')"), 'dişi havuzu 1 ile başlar');

  // Seçim → inputa yaz + liste kapanır + blur ön kontrolü tetiklenir
  fns.sec('b-kupe', '501');
  assert.strictEqual(bInput.value, '501');
  assert.strictEqual(bListe.style.display, 'none');
  assert.strictEqual(kontrolTetiklenen, 'b-kupe', 'seçim sonrası _kupeKontrolEt tetiklenmeli');
});
