// etiket-tazelik-v23b.test.js — V23 review minör notlarının mikro-turu (EGESUT-V23B-KAPI).
// TDD: not 1 ve not 4 testleri ÖNCE KIRMIZI koşuldu (sessiz atlama / sessiz filtre vardı),
// sonra kapı (scripts/etiket-tazelik.mjs) fail-closed'a çevrildi ve YEŞİLE döndü.
// Not 2 testleri SABİTLEYİCİDİR: iç-ice ternary / || fallback bilinçli tanınmaz (atlas.mjs
// sözleşmesi birebir korunur); bu testler o sınırın hangi sonuca düştüğünü kilitler.
// Not 3: spawnSync 15 sn timeout — timeout dolarsa test KIRMIZI.
// Kanonik koşum: npm run test:unit (ya da node --test tests/unit/etiket-tazelik-v23b.test.js)
import { test } from 'node:test';
import assert from 'node:assert';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const REPO = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const KAPI = path.join(REPO, 'scripts', 'etiket-tazelik.mjs');

// Test-başına gövde: her iddia kendi gövdesiyle kurulur (iki yönlü küme eşitliği
// paydaları karışmasın). timeoutMs: not 3 — kapı 15 sn'de donarsa test KIRMIZI
// (spawnSync error yolu açıkça kırmıya çevrilir; ETIMEDOUT sessiz yeşil yapmaz).
function koş(jsdocSatirlari, govde, timeoutMs = 15000) {
  const dizin = mkdtempSync(path.join(tmpdir(), 'etiket-v23b-'));
  const dosya = path.join(dizin, 'ornek.js');
  writeFileSync(
    dosya,
    `/**\n${jsdocSatirlari.map(s => ` * ${s}`).join('\n')}\n */\nfunction ornekV23b(kayit){\n${govde}\n}\n`,
    'utf8');
  try {
    // spawnSync: kapı HATALI'da exit 1 verir (sözleşme) — fırlatma yok, çıktı yine okunur
    const sonuc = spawnSync('node', [KAPI, '--dosya', dosya], { encoding: 'utf8', timeout: timeoutMs });
    if (sonuc.error) {
      assert.fail(`kapı ${timeoutMs} ms içinde dönmedi: ${sonuc.error.code || sonuc.error.message}`);
    }
    const ham = sonuc.stdout || '';
    const satir = ham.split('\n').find(l => l.startsWith('payda '));
    assert.ok(satir, 'kapı çıktısında payda satırı yok: ' + ham.slice(0, 300));
    const m = satir.match(/DOĞRU (\d+) \| HATALI (\d+) \| DOGRULANAMADI (\d+)/);
    return { dogru: +m[1], hatali: +m[2], dogrulanamadi: +m[3], ham };
  } finally {
    rmSync(dizin, { recursive: true, force: true });
  }
}

// --- Not 1: yardımcı dizi literalinde string-olmayan eleman sessiz atlanamaz ---

test('v2.3b yardımcı dizide string-olmayan eleman → satır DOĞRULANAMADI (sessiz atlama yasak)', () => {
  const s = koş(['@tablo gorev_log (tazeleme)'],
    `return pullTables(['gorev_log', kayit.ekstraTablo]);`);
  assert.strictEqual(s.dogrulanamadi, 1, s.ham);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.ok(s.ham.includes('string olmayan eleman'), s.ham);
});

test('v2.3b yardımcıya literal-olmayan skalar arg → satır DOĞRULANAMADI (HATALI gerekçesi düzelir)', () => {
  const s = koş(['@tablo hekimler (okuma)'],
    `return getData(kayit.tabloAdi);`);
  // eski davranış: çağrı hiç sayılmaz → etiket FAZLA → HATALI (yanlış gerekçe);
  // yeni: çağrı belirsiz → DOĞRULANAMADI
  assert.strictEqual(s.dogrulanamadi, 1, s.ham);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.ok(s.ham.includes('literal-olmayan girdi'), s.ham);
});

test('v2.3b tamamı-literal dizi tanınmaya devam eder (kontrol kolu — davranış değişmedi)', () => {
  const s = koş(['@tablo gorev_log (tazeleme), stok (tazeleme)'],
    `return pullTables(['gorev_log', 'stok']);`);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogrulanamadi, 0, s.ham);
  assert.strictEqual(s.dogru, 1);
});

// --- Not 2: iç-ice ternary / || fallback rpc adı — SABİTLEYİCİ (davranış korunur) ---

test('v2.3b SABİT: iç-ice ternary rpc adı tanınmaz — etiketliyse FAZLA/HATALI (sessiz-yeşil yok)', () => {
  const s = koş(['@rpc a_rpci, b_rpci'],
    `return rpc(kayit.dal ? 'a_rpci' : kayit.obek ? 'b_rpci' : 'c_rpci');`);
  // tanınmaz: gövde rpcler kümesi boş → etiket FAZLA ×2 → HATALI; DOĞRU/DOĞRULANAMADI'ya düşmez
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes("rpc('a_rpci') yok"), s.ham);
  assert.ok(s.ham.includes("rpc('b_rpci') yok"), s.ham);
});

test('v2.3b SABİT: || fallback rpc adı tanınmaz — etiketliyse FAZLA/HATALI', () => {
  const s = koş(['@rpc yedek_rpci'],
    `return rpc(kayit.adi || 'yedek_rpci');`);
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes("rpc('yedek_rpci') yok"), s.ham);
});

test('v2.3b SABİT: etiketsiz tanınmayan rpc biçimi kapıya görünmez (sınır: kapı etiket satırı denetler)', () => {
  const s = koş(['@rpc baska_rpci'],
    `rpc(kayit.adi || 'yedek_rpci');
     return rpc('baska_rpci');`);
  // tanınmayan biçim EKSİK üretmez (kapı yalnız tanıdığı biçimi arar) — etiketli ad DOĞRU
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogru, 1);
});

// --- Not 4: (koşullu) eki adı boşaltırsa → HATALI (fail-closed) ---

test('v2.3b (koşullu) eki adı boşaltırsa HATALI: @rpc a, (koşullu)', () => {
  const s = koş(['@rpc a_rpci, (koşullu)'],
    `return rpc('a_rpci');`);
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes('boşalttı'), s.ham);
});

test('v2.3b tek başına (koşullu) da HATALI — DOĞRULANAMADI değil (fail-closed)', () => {
  const s = koş(['@rpc (koşullu)'],
    `return rpc('bir_rpci');`);
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes('boşalttı'), s.ham);
});

test('v2.3b dolu koşullu ad davranışı değişmedi: @rpc a, b (koşullu) → DOĞRU', () => {
  const s = koş(['@rpc a_rpci, b_rpci (koşullu)'],
    `return rpc(kayit.dal ? 'a_rpci' : 'b_rpci');`);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogrulanamadi, 0, s.ham);
  assert.strictEqual(s.dogru, 1);
});

// --- Not 3: spawnSync timeout yolu — helper timeout'u taşır; timeout = KIRMIZI ---

test('v2.3b koş() timeout yolu: 1 ms bütçe kapıyı keser → test KIRMIZI (error yolu çalışıyor)', () => {
  // Bu test koş helper'ının timeout=KIRMIZI sözleşmesini kanıtlar: ETIMEDOUT'ta
  // assert.fail atılır (sessiz yeşil yok). Kapının kendisi için 15 sn varsayılan.
  let yakalandi = false;
  try {
    koş(['@rpc herhangi'], `return rpc('herhangi');`, 1);
  } catch (e) {
    yakalandi = /kapı 1 ms içinde dönmedi/.test(e.message);
  }
  assert.ok(yakalandi, '1 ms timeout kapıyı kesmedi — error yolu kanıtlanamadı');
});
