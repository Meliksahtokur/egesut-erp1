// tests/unit/hasta-filtre.test.js
// T2 — Dashboard "Aktif Hastalık" kartı → sürü + 🏥 Hasta tag; dinamik hastalık filtresi.
//
// Kapsam: ui.js'teki hasta modu saf çekirdeği
//   _hastaHastalikSecenekleri — aktif vakalardan hastalık seçenekleri (dinamik türetme)
//   _aktifVakaAcilisMap       — hayvan başına en yeni vaka açılış tarihi
//   _hastaModuUygula          — seçim filtresi + açılış tarihine göre sıralama
//   _dashStatRow              — kartın showHasta()'ya bağlandığının regresyon kilidi
//
// Canlı şema (2026-09-02 doğrulandı): cases.start_date (date, açılış),
// cases.created_at (timestamptz), cases.disease_id (uuid) → diseases.name.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

// ui.js modül yükleminin ihtiyacı olan saf yardımcılar (ui-pure.test.js ile aynı yaklaşım)
const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const { sandbox } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror },
});
const { _hastaHastalikSecenekleri, _aktifVakaAcilisMap, _hastaModuUygula, _dashStatRow } = sandbox;

// ── Test verisi ──
const DISEASES = [
  { id: 'd-metrit', name: 'Metritis', category: 'Rahim' },
  { id: 'd-mastitis', name: 'Mastitis', category: 'Meme' },
  { id: 'd-lame', name: 'Ayak Hastalığı', category: 'Ayak' },
  { id: 'd-abort', name: 'Abort', category: 'Üreme' }, // vakalarda YOK — seçenekte çıkmamalı
];
// A1: en yeni vaka 2026-09-01 · A2: 2026-08-20 · A3: iki vakası var (en yeni 2026-08-25)
const VAKALAR = [
  { id: 'c1', animal_id: 'A1', disease_id: 'd-metrit',   start_date: '2026-09-01', status: 'active' },
  { id: 'c2', animal_id: 'A2', disease_id: 'd-mastitis', start_date: '2026-08-20', status: 'active' },
  { id: 'c3', animal_id: 'A3', disease_id: 'd-lame',     start_date: '2026-08-10', status: 'active' },
  { id: 'c4', animal_id: 'A3', disease_id: 'd-metrit',   start_date: '2026-08-25', status: 'active' },
];

// ═══════════════════════════════════════════════════════════════
// _hastaHastalikSecenekleri
// ═══════════════════════════════════════════════════════════════
test('seçenekler: aktif vakalardan türetilir — vakası olmayan hastalık listede yok', () => {
  const sec = _hastaHastalikSecenekleri(VAKALAR, DISEASES);
  const adlar = sec.map(s => s.name);
  assert.deepEqual(adlar.sort(), ['Ayak Hastalığı', 'Mastitis', 'Metritis'].sort());
  assert.ok(!adlar.includes('Abort'), 'vakası olmayan hastalık seçeneklere girmemeli');
});

test('seçenekler: hayvan değil vaka bazlı sayım — A3\'ün iki vakası 2 saydırılır', () => {
  const sec = _hastaHastalikSecenekleri(VAKALAR, DISEASES);
  const metrit = sec.find(s => s.id === 'd-metrit');
  assert.strictEqual(metrit.sayi, 2, 'Metritis 2 vakada geçiyor (A1 + A3)');
  assert.strictEqual(sec.find(s => s.id === 'd-lame').sayi, 1);
});

test('seçenekler: isim eşlemesi diseases listesinden, bilinmeyen id "?" düşer', () => {
  const sec = _hastaHastalikSecenekleri(
    [{ animal_id: 'A1', disease_id: 'd-bilinmez' }],
    DISEASES
  );
  assert.strictEqual(sec.length, 1);
  assert.strictEqual(sec[0].name, '?');
});

test('seçenekler: boş vaka/disease girdisi → boş dizi (null/undefined patlamaz)', () => {
  assert.deepEqual(_hastaHastalikSecenekleri([], DISEASES), []);
  // diseases boşsa ad '?' düşer; vaka bazlı gruplama korunur (metrit 2 vakada)
  const adSiz = _hastaHastalikSecenekleri(VAKALAR, []);
  assert.deepEqual(adSiz.map(s => s.id).sort(), ['d-lame', 'd-mastitis', 'd-metrit'].sort());
  assert.strictEqual(adSiz.find(s => s.id === 'd-metrit').sayi, 2);
  assert.deepEqual(_hastaHastalikSecenekleri(null, null), []);
});

test('seçenekler: isme göre tr-alfabetik sıralı', () => {
  const sec = _hastaHastalikSecenekleri(VAKALAR, DISEASES);
  const adlar = sec.map(s => s.name);
  const sirali = [...adlar].sort((a, b) => a.localeCompare(b, 'tr'));
  assert.deepEqual(adlar, sirali);
});

// ═══════════════════════════════════════════════════════════════
// _aktifVakaAcilisMap
// ═══════════════════════════════════════════════════════════════
test('açılış haritası: hayvan başına EN YENİ aktif vaka açılışı', () => {
  const m = _aktifVakaAcilisMap(VAKALAR);
  assert.strictEqual(m.get('A1'), '2026-09-01');
  assert.strictEqual(m.get('A2'), '2026-08-20');
  assert.strictEqual(m.get('A3'), '2026-08-25', 'A3 iki vakalı — en yenisi (08-25) kazanır');
});

test('açılış haritası: start_date yoksa created_at düşer, ikisi de yoksa satır atlanır', () => {
  const m = _aktifVakaAcilisMap([
    { animal_id: 'A1', created_at: '2026-08-30T10:00:00Z' },
    { animal_id: 'A2', start_date: null, created_at: null },
    { animal_id: 'A3', start_date: '2026-08-01' },
  ]);
  assert.strictEqual(m.get('A1'), '2026-08-30T10:00:00Z');
  assert.ok(!m.has('A2'));
  assert.strictEqual(m.get('A3'), '2026-08-01');
});

test('açılış haritası: boş/null vaka listesi → boş Map', () => {
  assert.strictEqual(_aktifVakaAcilisMap([]).size, 0);
  assert.strictEqual(_aktifVakaAcilisMap(null).size, 0);
});

// ═══════════════════════════════════════════════════════════════
// _hastaModuUygula
// ═══════════════════════════════════════════════════════════════
const HAYVANLAR = [
  { id: 'A1', kupe_no: '101' },
  { id: 'A2', kupe_no: '102' },
  { id: 'A3', kupe_no: '103' },
  { id: 'A4', kupe_no: '104' }, // hiç vakası yok
];

test('hasta modu: seçim boşken küme DEĞİŞMEZ, yalnız açılışa göre sıralanır (en yeni üstte)', () => {
  const out = _hastaModuUygula(HAYVANLAR, VAKALAR, new Set());
  assert.deepEqual(out.map(a => a.id), ['A1', 'A3', 'A2', 'A4']);
  assert.notStrictEqual(out, HAYVANLAR, 'girdi dizisi mutasyona uğramamalı — kopya dönmeli');
  assert.deepEqual([...HAYVANLAR].map(a => a.id), ['A1', 'A2', 'A3', 'A4']);
});

test('hasta modu: seçili hastalık yalnız o hastalığı taşıyanları bırakır', () => {
  const out = _hastaModuUygula(HAYVANLAR, VAKALAR, new Set(['d-metrit']));
  assert.deepEqual(out.map(a => a.id).sort(), ['A1', 'A3']);
  // Sıralama seçimle birlikte de açılış tarihine göre: A1 (09-01) üstte
  assert.strictEqual(out[0].id, 'A1');
});

test('hasta modu: çoklu seçim OR mantığı — hastalıklardan en az biri yetatif', () => {
  const out = _hastaModuUygula(HAYVANLAR, VAKALAR, new Set(['d-mastitis', 'd-lame']));
  assert.deepEqual(out.map(a => a.id).sort(), ['A2', 'A3']);
});

test('hasta modu: vaka listesi boşsa seçim olsa da olmasa da liste boşalır/sepete göre sıralanır', () => {
  assert.deepEqual(_hastaModuUygula(HAYVANLAR, [], new Set(['d-metrit'])).map(a => a.id), []);
  // seçimsiz + vakasız: tarih yok → sıralama stabil kopya
  assert.deepEqual(_hastaModuUygula(HAYVANLAR, [], new Set()).map(a => a.id), ['A1', 'A2', 'A3', 'A4']);
});

test('hasta modu: null seçim kümesi seçimsiz gibi davranır', () => {
  const out = _hastaModuUygula(HAYVANLAR, VAKALAR, null);
  assert.deepEqual(out.map(a => a.id), ['A1', 'A3', 'A2', 'A4']);
});

// ═══════════════════════════════════════════════════════════════
// _dashStatRow — "Aktif Hastalık" kartı sürü+hasta tag'ine bağlanmalı (regresyon kilidi)
// ═══════════════════════════════════════════════════════════════
test('dashboard kartı showHasta() çağırır — gecmis/hastalik sekmesine gitmez', () => {
  const html = _dashStatRow([], [], [{ id: 'c1' }], [], 0);
  assert.ok(html.includes('onclick="showHasta()"'), 'kart showHasta() olmalı');
  assert.ok(!html.includes("loadGecmis('hastalik')"), 'eski gecmis yönlendirmesi kalmamalı');
});
