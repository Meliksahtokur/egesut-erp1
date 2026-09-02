// tests/unit/sutten-kes-secim.test.js
// Sütten kesme seçim katmanı: helpers.js saf fonksiyonları (sutIcenBuzagiSec,
// suttenKesimeHazirSec, suttenKesListeSirala) + dashboard kartı (_dashStatRow)
// ile m-sutten-kes modalının küme tutarlılığı.
//
// SÖZLEŞME (helpers.js "SÜTTEN KESME" bloğu):
//   Kart sayacı = suttenKesimeHazirSec uzunluğu = modal listesindeki
//   'Kesim vakti' rozetli satır sayısı. Kart tıklanınca openSuttenKesModal açılır
//   (sürü listesi DEĞİL — T1 düzeltmesi).
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { sutIcenBuzagiSec, suttenKesimeHazirSec, suttenKesListeSirala } = require('../../js/utils/helpers.js');

// ── Tarih yardımcıları ──
// n*24h önceki an (tam ISO) — _sutGunYasi'nın ms matematiğiyle BİREBİR:
// yaş = n*24h + (ölçüm-üretim arası mikrosaniyeler) → floor her zaman n.
// Yerel takvim kullanırsan (UTC+3 gece 00:00-03:00) UTC-geceyarısı parse'ı
// sınırda titreme yapar — bu yüzden ms tabanlı (forms-validation gunOnce deseni).
function daysAgoIso(n) { return new Date(Date.now() - n * 86400000).toISOString(); }

const buzagi = (over = {}) => Object.assign({
  id: 'h1', durum: 'Aktif', grup: 'Süt İçen Buzağı', dogum_tarihi: daysAgoIso(10),
}, over);

// ═══════════════ sutIcenBuzagiSec (kanonik set) ═══════════════
test('sutIcenBuzagiSec: aktif + kesilmemiş + (grup Buzağı VEYA yaş≤180)', () => {
  const animals = [
    buzagi({ id: 'a1' }),                                                    // ✔ grup Buzağı'lı, 10g
    buzagi({ id: 'a2', durum: 'Satıldı' }),                                  // ✘ aktif değil
    buzagi({ id: 'a3', suttten_kesme_tarihi: '2026-08-01' }),                // ✘ kesilmiş
    buzagi({ id: 'a4', grup: 'Buzağı', dogum_tarihi: daysAgoIso(300) }),     // ✔ grup Buzağı (yaş>180 olsa da)
    buzagi({ id: 'a5', grup: 'Düve', dogum_tarihi: daysAgoIso(100) }),       // ✔ grup Buzağı değil ama yaş≤180
    buzagi({ id: 'a6', grup: 'İnek', dogum_tarihi: daysAgoIso(400) }),       // ✘ ne grup ne yaş
    buzagi({ id: 'a7', grup: 'Buzağı', dogum_tarihi: null }),                // ✔ grup Buzağı (yaş bilinmiyor)
  ];
  const ids = sutIcenBuzagiSec(animals).map(a => a.id);
  assert.deepStrictEqual(ids, ['a1', 'a4', 'a5', 'a7']);
});

test('sutIcenBuzagiSec: null/undefined/boş dizi güvenli', () => {
  assert.deepStrictEqual(sutIcenBuzagiSec(null), []);
  assert.deepStrictEqual(sutIcenBuzagiSec(undefined), []);
  assert.deepStrictEqual(sutIcenBuzagiSec([]), []);
  assert.deepStrictEqual(sutIcenBuzagiSec([null]), []);
});

// ═══════════════ suttenKesimeHazirSec (eşik) ═══════════════
test('suttenKesimeHazirSec: eşik sınırı — 60 gün dahil, 59 hariç', () => {
  const animals = [
    buzagi({ id: 'sinir', dogum_tarihi: daysAgoIso(60) }),   // tam eşik → dahil
    buzagi({ id: 'altinda', dogum_tarihi: daysAgoIso(59) }), // eşiğin altı → hariç
    buzagi({ id: 'uzerinde', dogum_tarihi: daysAgoIso(90) }),
  ];
  const ids = suttenKesimeHazirSec(animals, 60).map(a => a.id);
  assert.deepStrictEqual(ids, ['sinir', 'uzerinde']);
});

test('suttenKesimeHazirSec: varsayılan eşik 60, özel eşik (45/90) uygulanır', () => {
  const animals = [
    buzagi({ id: 'g50', dogum_tarihi: daysAgoIso(50) }),
    buzagi({ id: 'g100', dogum_tarihi: daysAgoIso(100) }),
  ];
  assert.deepStrictEqual(suttenKesimeHazirSec(animals).map(a => a.id), ['g100']);          // varsayılan 60
  assert.deepStrictEqual(suttenKesimeHazirSec(animals, 45).map(a => a.id), ['g50', 'g100']); // gevşek eşik
  assert.deepStrictEqual(suttenKesimeHazirSec(animals, 90).map(a => a.id), ['g100']);       // sıkı eşik
});

test('suttenKesimeHazirSec: dogum_tarihi olmayan (yaş? ) asla "kesim vakti" sayılmaz', () => {
  const animals = [buzagi({ id: 'yassiz', dogum_tarihi: null })];
  assert.deepStrictEqual(suttenKesimeHazirSec(animals, 60), []);
});

test('suttenKesimeHazirSec: kesim vakti kümesi her zaman süt içen kümenin alt kümesi', () => {
  const animals = [
    buzagi({ id: 'a1' }),
    buzagi({ id: 'a2', suttten_kesme_tarihi: '2026-08-01' }),
    buzagi({ id: 'a3', durum: 'Ölü' }),
    buzagi({ id: 'a4', grup: 'Buzağı', dogum_tarihi: daysAgoIso(200) }),
    buzagi({ id: 'a5', grup: 'Düve', dogum_tarihi: daysAgoIso(30) }),
  ];
  const set = new Set(sutIcenBuzagiSec(animals).map(a => a.id));
  for (const h of suttenKesimeHazirSec(animals, 60)) assert.ok(set.has(h.id), h.id + ' set dışında');
});

// ═══════════════ suttenKesListeSirala (modal sırası) ═══════════════
test('suttenKesListeSirala: kesim vakti gelenler önce, grup içi sıra korunur', () => {
  const animals = [
    buzagi({ id: 'genç1', dogum_tarihi: daysAgoIso(10) }),
    buzagi({ id: 'hazır1', dogum_tarihi: daysAgoIso(70) }),
    buzagi({ id: 'genç2', dogum_tarihi: daysAgoIso(20) }),
    buzagi({ id: 'hazır2', dogum_tarihi: daysAgoIso(65) }),
  ];
  const esik = 60;
  const sirali = suttenKesListeSirala(animals, esik).map(a => a.id);
  assert.deepStrictEqual(sirali, ['hazır1', 'hazır2', 'genç1', 'genç2']);
  // konum kanıtı: hazır olanlar ilk yarıda
  const ilkIki = new Set(sirali.slice(0, 2));
  assert.ok(ilkIki.has('hazır1') && ilkIki.has('hazır2'));
});

test('suttenKesListeSirala: hepsi hazırsa sıra değişmez, hiçbiri hazırsa da', () => {
  const hepsiHazir = [buzagi({ id: 'x1', dogum_tarihi: daysAgoIso(70) }), buzagi({ id: 'x2', dogum_tarihi: daysAgoIso(80) })];
  assert.deepStrictEqual(suttenKesListeSirala(hepsiHazir, 60).map(a => a.id), ['x1', 'x2']);
  const hicbiri = [buzagi({ id: 'y1', dogum_tarihi: daysAgoIso(10) }), buzagi({ id: 'y2', dogum_tarihi: daysAgoIso(20) })];
  assert.deepStrictEqual(suttenKesListeSirala(hicbiri, 60).map(a => a.id), ['y1', 'y2']);
});

// ═══════════════ _dashStatRow ↔ modal küme tutarlılığı ═══════════════
// ui.js sandbox'a SAF katman gerçek haliyle, eşik sabit stub olarak enjekte edilir.
const { sandbox: ui } = loadBrowserModule('js/ui.js', {
  extra: {
    suttenKesimeHazirSec,
    suttenKesmeEsigi: () => 60, // protokol_ayar stub'u — eşik değişkeni forms.js tarafında test edilmez
  },
});

test('_dashStatRow: sayaç = kesim vakti kümesi; >0 warn, 0 ok', () => {
  const animals = [
    buzagi({ id: 'g10' }),
    buzagi({ id: 'g70', dogum_tarihi: daysAgoIso(70) }),
    buzagi({ id: 'g90', dogum_tarihi: daysAgoIso(90) }),
    buzagi({ id: 'kesik', dogum_tarihi: daysAgoIso(90), suttten_kesme_tarihi: '2026-07-01' }),
  ];
  const beklenen = suttenKesimeHazirSec(animals, 60).length; // 2 (g70, g90)
  assert.strictEqual(beklenen, 2);

  const html = ui._dashStatRow(animals, [], [], [], 0);
  const sv = /<div class="sv">(\d+)<\/div><div class="sl">🍼 Sütten Kes/.exec(html);
  assert.ok(sv, 'sayaç HTML\'de bulunamadı');
  assert.strictEqual(+sv[1], beklenen, 'kart sayacı kesim vakti kümesiyle eşit değil');
  assert.match(html, /class="sc warn" onclick="openSuttenKesModal\(\)"/);
});

test('_dashStatRow: küme boşsa sayaç 0 ve sınıf ok — yine modalı açar', () => {
  const animals = [buzagi({ id: 'sadeceGenç', dogum_tarihi: daysAgoIso(20) })];
  const html = ui._dashStatRow(animals, [], [], [], 0);
  const sv = /<div class="sv">(\d+)<\/div><div class="sl">🍼 Sütten Kes/.exec(html);
  assert.strictEqual(+sv[1], 0);
  assert.match(html, /class="sc ok" onclick="openSuttenKesModal\(\)"/);
});

test('_dashStatRow: kart artık sürüye götürmez (goTo/filterA yok)', () => {
  const html = ui._dashStatRow([buzagi()], [], [], [], 0);
  const kart = /<div class="sc [^"]*" onclick="[^"]*"><div class="sv">\d+<\/div><div class="sl">🍼 Sütten Kes/.exec(html);
  assert.ok(kart, 'sütten kes kartı bulunamadı');
  assert.ok(!kart[0].includes("goTo('suru')"), 'kart hâlâ sürüye götürüyor');
  assert.ok(!kart[0].includes('filterA'), 'kart hâlâ filterA çağırıyor');
});
