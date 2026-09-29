// etiket-tazelik-v23c.test.js — V23C: dış review (DIS-REVIEW-V23B) onarım testleri.
// Kalem 2: nitelikli yardımcı çağrı (x.getData) → DOĞRULANAMADI (bugün sessiz DOĞRU — kırmızı).
// Kalem 3: K7 adsizEkleme kırmızı kolu (sentetik fixture) + ATLANDI sayacı çıktıda görünür.
// Kalem 4: iç review 3 minör — (a) adsizEkleme kolunda '(koşullu)' kalıntısı gider;
//          (b) K4/K6 belirsiz-fn satırını seçmez; (c) belirsizlik mesajı satır no taşır +
//              timeout catch'i sebebi korur.
// TDD: her davranış testi ÖNCE KIRMIZI koşuldu; kapı sonra genişletildi.
// Koşum: npm run test:unit (ya da node --test tests/unit/etiket-tazelik-v23c.test.js)
import { test } from 'node:test';
import assert from 'node:assert';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const REPO = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const KAPI = path.join(REPO, 'scripts', 'etiket-tazelik.mjs');
const TIMEOUT_MS = 15000;

// Hüküm özeti döndüren koşum (v23b koş() ile aynı sözleşme + timeout)
function koş(jsdocSatirlari, govde, timeoutMs = TIMEOUT_MS) {
  const dizin = mkdtempSync(path.join(tmpdir(), 'etiket-v23c-'));
  const dosya = path.join(dizin, 'ornek.js');
  writeFileSync(dosya,
    `/**\n${jsdocSatirlari.map(s => ` * ${s}`).join('\n')}\n */\nfunction ornekV23c(kayit){\n${govde}\n}\n`, 'utf8');
  try {
    const sonuc = spawnSync('node', [KAPI, '--dosya', dosya], { encoding: 'utf8', timeout: timeoutMs });
    if (sonuc.error) assert.fail(`kapı ${timeoutMs} ms içinde dönmedi: ${sonuc.error.code || sonuc.error.message}`);
    const ham = sonuc.stdout || '';
    const satir = ham.split('\n').find(l => l.startsWith('payda '));
    assert.ok(satir, 'kapı çıktısında payda satırı yok: ' + ham.slice(0, 300));
    const m = satir.match(/DOĞRU (\d+) \| HATALI (\d+) \| DOGRULANAMADI (\d+)/);
    return { dogru: +m[1], hatali: +m[2], dogrulanamadi: +m[3], ham };
  } finally {
    rmSync(dizin, { recursive: true, force: true });
  }
}

// --kirmizi modunu sentetik dosya üzerinde koşturur (kol çıktısı gerekli)
function kirmiziKos(jsdocSatirlari, govde) {
  const dizin = mkdtempSync(path.join(tmpdir(), 'etiket-v23c-k-'));
  const dosya = path.join(dizin, 'ornek.js');
  writeFileSync(dosya,
    `/**\n${jsdocSatirlari.map(s => ` * ${s}`).join('\n')}\n */\nfunction ornekK23c(kayit){\n${govde}\n}\n`, 'utf8');
  try {
    const sonuc = spawnSync('node', [KAPI, '--kirmizi', '--dosya', dosya], { encoding: 'utf8', timeout: TIMEOUT_MS });
    if (sonuc.error) assert.fail(`kapı ${TIMEOUT_MS} ms içinde dönmedi: ${sonuc.error.code || sonuc.error.message}`);
    return { exit: sonuc.status, ham: sonuc.stdout || '', hata: sonuc.stderr || '' };
  } finally {
    rmSync(dizin, { recursive: true, force: true });
  }
}

// --- Kalem 2: nitelikli yardımcı çağrı fail-closed ---

test('v23c nitelikli yardımcı çağrı: api.getData(\'hekimler\') → satır DOĞRULANAMADI (sessiz DOĞRU yasak)', () => {
  const s = koş(['@tablo hekimler (okuma)'],
    `return api.getData('hekimler');`);
  assert.strictEqual(s.dogrulanamadi, 1, s.ham);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogru, 0, s.ham);
  assert.ok(s.ham.includes('nitelikli') || s.ham.includes('BELİRSİZ'), s.ham);
});

test('v23c nitelikli + bilinen çıplak tablo birlikte: satır DOĞRULANAMADI (dış review sentetik vakası)', () => {
  const s = koş(['@tablo cases (select)'],
    `const c = db.from('cases').select('*');
     return api.pullTables(['cases']);`);
  // çıplak .from('cases') (select) kanıtlı ama nitelikli çağrı küme güvenilirliğini bitirir
  assert.strictEqual(s.dogrulanamadi, 1, s.ham);
});

// --- Kalem 3: K7 adsizEkleme kırmızı kolu + ATLANDI sayacı ---

test('v23c K7 kolü koşar ve adsizEkleme yolunu yakalar (sentetik fixture; gerçek ağaçta aday yok)', () => {
  const s = kirmiziKos(['@rpc a_rpci'], `return rpc('a_rpci');`);
  // v23d (D2 — dış review Önemli-2): pin KOL-SPESİFİK — 'YAKALANDI' metni K1'in satırından
  // da gelebilir; K7'nin KENDİ satırında aranır, aksi halde K7 bozulsa test yeşil kalır
  const k7 = s.ham.split('\n').find(l => l.includes('K7'));
  assert.ok(k7, 'çıktıda K7 kolu yok: ' + s.ham);
  assert.ok(k7.includes('YAKALANDI'), 'K7 satırı YAKALANDI değil: ' + k7);
  assert.strictEqual(s.exit, 0, 'kırmızı kontrol exit 0 olmalı: ' + s.ham + s.hata);
});

test('v23d K7 gerçek ağaçta sabitlenir: kol satırı YAKALANDI + özet 7 canlı/7 kol/0 ATLANDI + exit 0', () => {
  const sonuc = spawnSync('node', [KAPI, '--kirmizi'], { encoding: 'utf8', timeout: TIMEOUT_MS });
  if (sonuc.error) assert.fail(`kapı ${TIMEOUT_MS} ms içinde dönmedi: ${sonuc.error.code || sonuc.error.message}`);
  const ham = sonuc.stdout || '';
  const k7 = ham.split('\n').find(l => l.includes('K7'));
  assert.ok(k7, 'gerçek ağaç koşumunda K7 kolu yok: ' + ham.slice(-400));
  assert.ok(k7.includes('YAKALANDI'), 'K7 gerçek ağaçta YAKALANDI değil: ' + k7);
  assert.ok(
    ham.includes('kırmızı kontrol: YAKALANDI (7 canlı kol / 7 kol, 0 ATLANDI)'),
    'özet sözleşmesi (7 canlı / 7 kol / 0 ATLANDI) bozuldu: ' + ham.split('\n').filter(l => l.includes('kırmızı kontrol')).join(' | '));
  assert.strictEqual(sonuc.status, 0, 'gerçek ağaç kırmızı kontrol exit 0 olmalı');
});

test('v23c ATLANDI kolu sayaca görünür: çıktı canlı/kol/ATLANDI ayrımını taşır', () => {
  // Bu sentetik dosyada K3 (olay kolu) için olay satırı yok → K3 ATLANDI beklenir
  const s = kirmiziKos(['@rpc a_rpci'], `return rpc('a_rpci');`);
  // ATLANDI sayacı ÖZET satırında: "... (X canlı kol / Y kol, Z ATLANDI)" — tekil [kirmizi]
  // satırları değil, özetin kendisini sabitler (tekil ATLANDI satırı bugün de var)
  assert.ok(/kırmızı kontrol: .* \(\d+ canlı kol \/ \d+ kol, \d+ ATLANDI\)/.test(s.ham), 'özet ATLANDI sayacı yok: ' + s.ham);
});

test('v23c K4 belirsiz-fn satırını seçmez: belirsiz fn önce, temiz fn sonra → K4 temizini seçip YAKALAR', () => {
  const dizin = mkdtempSync(path.join(tmpdir(), 'etiket-v23c-k4-'));
  const dosya = path.join(dizin, 'ornek.js');
  // fn A (önce): belirsiz yardımcılı; fn B (sonra): temiz işlemli tablo satırı
  writeFileSync(dosya, [
    '/**\n * @tablo hekimler (okuma)\n */',
    'function belirsizFn(kayit){',
    '  return getData(kayit.tablo);',
    '}',
    '/**\n * @tablo cases (select)\n */',
    'function temizFn(){',
    "  return db.from('cases').select('*');",
    '}',
  ].join('\n'), 'utf8');
  try {
    const sonuc = spawnSync('node', [KAPI, '--kirmizi', '--dosya', dosya], { encoding: 'utf8', timeout: TIMEOUT_MS });
    if (sonuc.error) assert.fail('kapı dönmedi: ' + (sonuc.error.code || sonuc.error.message));
    const ham = sonuc.stdout || '';
    const k4 = ham.split('\n').find(l => l.includes('K4'));
    assert.ok(k4, 'K4 kolü yok: ' + ham);
    assert.ok(k4.includes('YAKALANDI'), 'K4 belirsiz satırı seçti (bozma kayboldu): ' + ham);
  } finally {
    rmSync(dizin, { recursive: true, force: true });
  }
});

// --- Kalem 4a: adsizEkleme kolunda '(koşullu)' kalıntısı gider ---

test("v23c adsizEkleme kaydında yalnız adsız FAZLA var — '(koşullu)' kalıntı satırı YOK", () => {
  const s = koş(['@rpc a_rpci, (koşullu)'], `return rpc('a_rpci');`);
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes('boşalttı'), s.ham);
  assert.ok(!s.ham.includes("rpc('(koşullu)') yok"), 'koşullu kalıntısı hâlâ FAZLA satırı üretiyor: ' + s.ham);
});

// --- Kalem 4c-i: belirsizlik mesajı çağrı satırını taşır ---

test('v23c belirsizlik sorunu çağrı satır no’sunu taşır (çok yardımcılı fn’de daraltma)', () => {
  const s = koş(['@tablo gorev_log (tazeleme)'],
    `return pullTables(['gorev_log', kayit.ekstra]);`);
  // gerçek biçim: "… (satır 5) — tablo kümesi bilinemez" (parantezli satır işareti)
  assert.ok(/satır \d+\)/.test(s.ham), 'belirsizlik mesajında çağrı satırı yok: ' + s.ham);
});

// --- Kalem 4c-ii: timeout catch sebebi korur (v23b son testinin onarımı) ---

test('v23c koş() timeout yolu ETIMEDOUT’u adıyla raporlar (sebep kaybolmaz)', () => {
  let yakalandi = false;
  try {
    koş(['@rpc herhangi'], `return rpc('herhangi');`, 1);
  } catch (e) {
    if (/kapı .* ms içinde dönmedi/.test(e.message)) yakalandi = true;
    else throw new Error('timeout yolu beklenmedik sebeple düştü — sebep: ' + e.message);
  }
  assert.ok(yakalandi, '1ms bütçe kapıyı kesmedi — error yolu kanıtlanamadı');
});
