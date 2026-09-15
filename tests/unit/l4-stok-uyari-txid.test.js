// tests/unit/l4-stok-uyari-txid.test.js
// L4-W6 mini onarım — luna 2. tur L4-07 alt bulgusu (MEDIUM): stok_uyari
// `metin`ine gömülü `(txid %s)` görünür "📦 Stok uyarısı" bloğunda basılıyordu
// (luna Node render probu: visible_has_txid=true).
//
// Sözleşme (G-20260914-GERI-ALMA-AKISI md.7 + W6 zarfı):
//   1. SQL (20260914000004): `(txid %s)` metin parçası KALKAR; txid AYRI alan
//      ('txid'), aynı-tx döngüsünün ham hareket UUID'i de AYRI alan
//      ('hareket_id') — `metin` alanı korunur, tanımlayıcı içermez.
//      Fonksiyon gövdeleri 0003'ün birebir kopyası, tek fark uyarı satırları.
//   2. UI: txid/hareket_id YALNIZ _dgTeknikDetayHtml katlamasında; görünür
//      alanda txid/UUID YOK.
//
// 1 numaradaki "birebir gövde" iddiası REVERSE-normalizasyonla pinlenir:
// 0004 gövdesine ters ikame uygulanıp 0003 ile byte-eşitliği ölçülür.

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadBrowserModule } = require('./support/loadModule.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const HAM_UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;

// ── UI render probu (luna'nın Node probu tarzı — degisiklikler.js) ──
const diff = loadBrowserModule('js/degisiklikler/diff.js', { extra: {} });
const etiket = loadBrowserModule('js/degisiklikler/etiketler.js', { extra: {} });
const dg = loadBrowserModule('js/degisiklikler/degisiklikler.js', {
  extra: {
    registerActions: () => {},
    esc: escMirror,
    fmtTarihSaat: () => '14.09.2026 10:30',
    tabloEtiketi: etiket.sandbox.tabloEtiketi,
    alanEtiketi: etiket.sandbox.alanEtiketi,
    islemEtiketi: etiket.sandbox.islemEtiketi,
    degerMetni: diff.sandbox.degerMetni,
    pkKisa: diff.sandbox.pkKisa,
  },
  expose: ['_dgTeknikDetayHtml', '_dgOnizleHtml'],
});
const { _dgTeknikDetayHtml, _dgOnizleHtml } = dg.exposed;

// Sunucunun 0004 sonrası üreteceği uyarı biçimi: metin temiz, kimlik ayrı alanda
const STOK_UYARI_0004 = [
  { stok_id: 'stok-aabbccdd-1122-3344-5566-778899aabbcc',
    metin: 'tohumlama kaydına bağlı stok hareketi bu geri almaya dahil değil; stok elle kontrol edilmeli',
    txid: '987654' },
  { stok_id: 'stok-aabbccdd-1122-3344-5566-778899aabbcc',
    metin: 'Aynı işlemdeki stok hareketi bu geri almaya dahil değil; stok elle kontrol edilmeli',
    hareket_id: 'ff11ff11-2233-4455-6677-8899aabbccdd' },
];

test('W6 — görünür önizlemede stok uyarı txid/UUID YOK (luna probunun ölçtüğü sızıntı kapalı)', () => {
  const on = {
    geri_alinabilir: true,
    plan: [{ sira: 1, tablo: 'tohumlama', pk: 'aabbccdd-1122-3344-5566-778899aabbcc', islem: 'U', yapilacak: 'Kayıt geri alınacak' }],
    stok_uyari: STOK_UYARI_0004,
  };
  const h = _dgOnizleHtml(on, { seviye: 'satir', hedef: { tablo: 'tohumlama', pk: 'aabbccdd-1122-3344-5566-778899aabbcc', txid: '424242' } });
  const detayBaslangic = h.indexOf('<details class="dg-teknik"');
  assert.ok(detayBaslangic !== -1, 'teknik katlama üretilmelidir');
  const gorunur = h.slice(0, detayBaslangic);
  assert.ok(gorunur.includes('Stok uyarısı'), 'stok uyarı bloğu görünür alanda');
  assert.ok(gorunur.includes('987654') === false, 'luna bulgusu: txid görünürde SIZDI');
  assert.ok(HAM_UUID.test(gorunur) === false, 'görünür alanda ham UUID (hareket/stok id): ' + gorunur.match(HAM_UUID));
  assert.ok(h.includes('987654'), 'txid teknik katlamada KALIR');
});

test('W6 — teknik katlama: stok uyarı txid + hareket kimliği katlama İÇİNDE', () => {
  const t = _dgTeknikDetayHtml({ tablo: 'tohumlama', pk: 'aabbccdd', txid: '424242' }, { stok_uyari: STOK_UYARI_0004 });
  assert.ok(t.includes('Stok uyarı txid') && t.includes('987654'), 'txid satırı');
  assert.ok(t.includes('Stok hareket') && t.includes('ff11ff11'), 'hareket_id satırı (pkKisa)');
  // katlama zaten <details> içinde — satırlar details kapanışından önce
  const kapanis = t.indexOf('</details>');
  assert.ok(t.indexOf('987654') < kapanis, 'txid details gövdesinde');
});

test('W6 — stok_uyari boşsa katlamada stok satırı üretilmez (eski davranış korunur)', () => {
  const t = _dgTeknikDetayHtml({ tablo: 'tohumlama', pk: 'aabbccdd' }, {});
  assert.ok(!t.includes('Stok uyarı txid'), 'stok satırı yok');
  const t2 = _dgTeknikDetayHtml(null, { stok_uyari: [null, { metin: 'sadece metin' }] });
  assert.ok(!t2.includes('Stok uyarı txid') && !t2.includes('Stok hareket'), 'null/alanız uyarı satır üretmez');
});

// ── SQL pin: 0004 gövdesi 0003'ün birebir kopyası, tek fark uyarı satırları ──
const ROOT = path.join(__dirname, '..', '..');
const M0003 = fs.readFileSync(path.join(ROOT, 'supabase/migrations/20260914000003_l4_onarim.sql'), 'utf8');
const M0004 = fs.readFileSync(path.join(ROOT, 'supabase/migrations/20260914000004_l4_stok_uyari_txid.sql'), 'utf8');

function fonksiyonGovdesi(sql, ad) {
  const bas = sql.indexOf(`CREATE OR REPLACE FUNCTION surum_gizli.${ad}(`);
  assert.ok(bas !== -1, ad + ' bulunamadı');
  const son = sql.indexOf('$$;', bas);
  assert.ok(son !== -1, ad + ' gövde sonu yok');
  return sql.slice(bas, son + 3);
}

// ters ikame: 0004'teki yeni satırları 0003'ün eskilerine çevir
const LOOP_A_NEW = `        'metin', 'Aynı işlemdeki stok hareketi bu geri almaya dahil değil; stok elle kontrol edilmeli',
        'hareket_id', e.satir_pk ->> 'id');
`;
const LOOP_A_OLD = `        'metin', format('Aynı işlemdeki stok hareketi (%s) bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        e.satir_pk ->> 'id'));
`;
const LOOP_B_NEW = `        'metin', format('%s kaydına bağlı stok hareketi bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        r.tablo_adi),
        'txid', e.txid::text);
`;
const LOOP_B_OLD = `        'metin', format('%s kaydına bağlı stok hareketi (txid %s) bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        r.tablo_adi, e.txid));
`;

test('W6 — _degisim_plan gövdesi 0003 birebir; tek fark stok uyarı satırları (reverse-normalize byte-eşit)', () => {
  const yeni = fonksiyonGovdesi(M0004, '_degisim_plan');
  assert.ok(yeni.includes(LOOP_A_NEW), 'yeni loop-A satırları (metin + hareket_id)');
  assert.ok(yeni.includes(LOOP_B_NEW), 'yeni loop-B satırları (metin + txid)');
  const geri = yeni.replace(LOOP_A_NEW, LOOP_A_OLD).replace(LOOP_B_NEW, LOOP_B_OLD);
  assert.strictEqual(geri, fonksiyonGovdesi(M0003, '_degisim_plan'), '0004 _degisim_plan gövdesi 0003 dışında farklı');
});

test('W6 — _l4_zincir gövdesi 0003 birebir; tek fark stok uyarı satırları', () => {
  const yeni = fonksiyonGovdesi(M0004, '_l4_zincir');
  assert.ok(yeni.includes(LOOP_B_NEW), 'yeni loop satırları');
  assert.ok(!yeni.includes(LOOP_A_NEW) && !yeni.includes(LOOP_A_OLD), 'zincirde loop-A (aynı-tx) üretimi yok — birebir kopya korunur');
  const geri = yeni.replace(LOOP_B_NEW, LOOP_B_OLD);
  assert.strictEqual(geri, fonksiyonGovdesi(M0003, '_l4_zincir'), '0004 _l4_zincir gövdesi 0003 dışında farklı');
});

test('W6 — 0004 SQL kodunda (txid %s) YOK (yorum satırları hariç); replay-safe şekil', () => {
  const kod = M0004.split('\n').filter(l => !l.trim().startsWith('--')).join('\n');
  assert.ok(!kod.includes('(txid %s)'), 'metin parçası SQL kodunda kalmamalı');
  assert.ok(!/format\('Aynı işlemdeki stok hareketi \(%s\)/.test(kod), 'ham hareket UUID metne gömülmemeli');
  assert.strictEqual((kod.match(/CREATE OR REPLACE FUNCTION/g) || []).length, 2, 'yalnız iki fonksiyon tanımlanır');
  assert.ok(/^\s*BEGIN;|\nBEGIN;/.test(M0004) && /\nCOMMIT;/.test(M0004), 'transaction-wrap (replay-safe)');
  assert.strictEqual((kod.match(new RegExp(LOOP_B_NEW.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) || []).length, 2, 'loop-B yeni satırları iki fonksiyonda');
});
