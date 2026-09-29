// etiket-tazelik-v23e.test.js — V23E: x[degisken] köşesi fail-closed (root kararı).
// E2: computed + literal-olmayan üye çağrısı (x[degisken](...)) yardımcı adı taşımaz;
// eski davranışta kapı 'degisken' adını sözlükte arayıp bulamayınca SESSİZ kalıyordu
// (etiket varsa yanlış gerekçeyle HATALI, etiketsiz satırda hiç görünmüyordu).
// Yeni: belirsizYardimci → satır DOĞRULANAMADI (E1 atlas ile birebir: dinamik sınıf).
// TDD: testler ÖNCE KIRMIZI koşuldu; sonra kapıya bilinmeyen-computed-üye kolu eklendi.
// Mutant kanıtı: kural devre dışıyken testler KIRMIZI (V23D D2 desenindeki gibi).
// Koşum: npm run test:unit (ya da node --test tests/unit/etiket-tazelik-v23e.test.js)
import { test } from 'node:test';
import assert from 'node:assert';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const REPO = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const KAPI = path.join(REPO, 'scripts', 'etiket-tazelik.mjs');
const TIMEOUT_MS = 15000;

function koş(jsdocSatirlari, govde) {
  const dizin = mkdtempSync(path.join(tmpdir(), 'etiket-v23e-'));
  const dosya = path.join(dizin, 'ornek.js');
  writeFileSync(dosya,
    `/**\n${jsdocSatirlari.map(s => ` * ${s}`).join('\n')}\n */\nfunction ornekV23e(kayit){\n${govde}\n}\n`, 'utf8');
  try {
    const sonuc = spawnSync('node', [KAPI, '--dosya', dosya], { encoding: 'utf8', timeout: TIMEOUT_MS });
    if (sonuc.error) assert.fail(`kapı ${TIMEOUT_MS} ms içinde dönmedi: ${sonuc.error.code || sonuc.error.message}`);
    const ham = sonuc.stdout || '';
    const satir = ham.split('\n').find(l => l.startsWith('payda '));
    assert.ok(satir, 'kapı çıktısında payda satırı yok: ' + ham.slice(0, 300));
    const m = satir.match(/DOĞRU (\d+) \| HATALI (\d+) \| DOGRULANAMADI (\d+)/);
    return { dogru: +m[1], hatali: +m[2], dogrulanamadi: +m[3], ham };
  } finally {
    rmSync(dizin, { recursive: true, force: true });
  }
}

// --- E2: bilinmeyen endeksli üye çağrı fail-closed ---

test('v23e bracket-değişken üye: x[degisken](\'cases\') → satır DOĞRULANAMADI (sessiz/HATALI değil)', () => {
  const s = koş(['@tablo cases (okuma)'],
    `return x[degisken]('cases');`);
  assert.strictEqual(s.dogrulanamadi, 1, s.ham);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.ok(s.ham.includes('endeksli'), s.ham);
});

test('v23e bilinen çıplak tablo + bilinmeyen endeksli üye birlikte: satır yine DOĞRULANAMADI', () => {
  const s = koş(['@tablo cases (select)'],
    `const c = db.from('cases').select('*');
     return x[degisken]('cases');`);
  assert.strictEqual(s.dogrulanamadi, 1, s.ham);
  assert.strictEqual(s.hatali, 0, s.ham);
});

test('v23e kontrol kolu: bracket-string-literal davranışı değişmedi (x[\'getData\'] → DOĞRULANAMADI, nitelikli)', () => {
  const s = koş(['@tablo hekimler (okuma)'],
    `return x['getData']('hekimler');`);
  assert.strictEqual(s.dogrulanamadi, 1, s.ham);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.ok(s.ham.includes('nitelikli'), s.ham);
});
