// etiket-tazelik-v23.test.js — v2.3 sözlük testleri (ORNITH takibi: EGESUT-V23-ETIKET kalem 2).
// TDD: bu testler ÖNCE KIRMIZI koşuldu (koşullu eki + okuma/tazeleme işlemleri tanınmıyordu),
// sonra kapı (scripts/etiket-tazelik.mjs) genişletildi ve YEŞİLE döndü.
// Kanonik koşum: npm run test:unit (ya da node --test tests/unit/etiket-tazelik-v23.test.js)
import { test } from 'node:test';
import assert from 'node:assert';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const REPO = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const KAPI = path.join(REPO, 'scripts', 'etiket-tazelik.mjs');

// Test-başına gövde: her iddia kendi gövdesiyle kurulur (iki yönlü küme eşitliği
// paydaları karışmasın).
function koş(jsdocSatirlari, govde) {
  const dizin = mkdtempSync(path.join(tmpdir(), 'etiket-v23-'));
  const dosya = path.join(dizin, 'ornek.js');
  writeFileSync(
    dosya,
    `/**\n${jsdocSatirlari.map(s => ` * ${s}`).join('\n')}\n */\nfunction ornekV23(kayit){\n${govde}\n}\n`,
    'utf8');
  try {
    // spawnSync: kapı HATALI'da exit 1 verir (sözleşme) — fırlatma yok, çıktı yine okunur
    const sonuc = spawnSync('node', [KAPI, '--dosya', dosya], { encoding: 'utf8' });
    const ham = sonuc.stdout || '';
    const satir = ham.split('\n').find(l => l.startsWith('payda '));
    assert.ok(satir, 'kapı çıktısında payda satırı yok: ' + ham.slice(0, 300));
    const m = satir.match(/DOĞRU (\d+) \| HATALI (\d+) \| DOGRULANAMADI (\d+)/);
    return { dogru: +m[1], hatali: +m[2], dogrulanamadi: +m[3], ham };
  } finally {
    rmSync(dizin, { recursive: true, force: true });
  }
}

test('v2.3 koşullu rpc eki tanınır: @rpc a, b (koşullu) → DOĞRU', () => {
  const s = koş(['@rpc planli_tohumlama_kaydet, tohumlama_kaydet (koşullu)'],
    `const r = rpc(kayit.planli ? 'planli_tohumlama_kaydet' : 'tohumlama_kaydet', { id: kayit.id });
     return r;`);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogrulanamadi, 0, s.ham);
  assert.strictEqual(s.dogru, 1);
});

test('v2.3 koşullu satırda eksik/yanlış ad yakalanır (FAZLA)', () => {
  const s = koş(['@rpc planli_tohumlama_kaydet, tohumlama_kaydet, olmayan_rpc (koşullu)'],
    `const r = rpc(kayit.planli ? 'planli_tohumlama_kaydet' : 'tohumlama_kaydet');
     return r;`);
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes("rpc('olmayan_rpc') yok"), s.ham);
});

test('v2.3 koşullu eki olmayan satır koşullu adları taşır (geri-uyumlu)', () => {
  const s = koş(['@rpc planli_tohumlama_kaydet, tohumlama_kaydet'],
    `const r = rpc(kayit.planli ? 'planli_tohumlama_kaydet' : 'tohumlama_kaydet');
     return r;`);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogru, 1);
});

test('v2.3 okuma işlemi tanınır: getData("hekimler") ↔ (okuma)', () => {
  const s = koş(['@tablo hekimler (okuma)'], `return getData('hekimler');`);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogru, 1);
});

test('v2.3 tazeleme işlemi tanınır: pullTables(["gorev_log","stok"]) ↔ (tazeleme)', () => {
  const s = koş(['@tablo gorev_log (tazeleme), stok (tazeleme)'],
    `return pullTables(['gorev_log', 'stok']);`);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogru, 1);
});

test('v2.3 yanlış işlem yakalanır: okuma yerine tazeleme yazılırsa HATALI', () => {
  const s = koş(['@tablo hekimler (tazeleme)'], `return getData('hekimler');`);
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes("'tazeleme' yok"), s.ham);
});

test('v2.3 eksik tablo yakalanır (gövdede var, etikette yok → EKSİK)', () => {
  const s = koş(['@tablo hekimler (okuma)'],
    `const a = getData('hekimler');
     return pullTables(['gorev_log']);`);
  assert.strictEqual(s.hatali, 1, s.ham);
  assert.ok(s.ham.includes('EKSİK'), s.ham);
});

test('v2.2 biçimleri değişmedi: from/rpc/addEventListener + select işlemi DOĞRU', () => {
  const s = koş(['@rpc tohumlama_tekrar_kaydet', '@tablo cases (select)', '@olay click'],
    `const r = rpc('tohumlama_tekrar_kaydet');
     const c = db.from('cases').select('*');
     document.addEventListener('click', () => {});
     return [r, c];`);
  assert.strictEqual(s.hatali, 0, s.ham);
  assert.strictEqual(s.dogrulanamadi, 0, s.ham);
  assert.strictEqual(s.dogru, 3);
});
