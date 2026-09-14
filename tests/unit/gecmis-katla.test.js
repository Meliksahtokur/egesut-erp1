// tests/unit/gecmis-katla.test.js
// U1 md.3 + md.4 — _gmGunKatla (saf katlama) + _gmGunKategoriSayac (çip sayaçları).
//
// Kilitlenen sözleşmeler (zarf U1-tg1-gecmis-ux md.3):
//   1. Aynı gün + aynı kaynak + aynı tip + AYNI DAKİKA'dan ≥3 satır → TEK grup
//      düğümü ({grup:true, count:n, entries:n elemanlı}).
//   2. <3 satır → tek-tek {tek:true} düğümleri (katlanmaz).
//   3. Farklı tip / farklı dakika / farklı kaynak / farklı gün → AYRI düğüm.
//   4. islem entry'lerinde katlama anahtarı data.tip'tir (entry type 'islem' ortak).
//   5. Saat damgası olmayan satır (yalnız date kolonu) ASLA katılmaz — "aynı
//      dakika" kanıtı yokken birleştirmek bilgi yutar.
//   6. Giriş eventAt-desc sıralıysa çıkış sırası korunur (grup ilk üyesinin
//      yerine oturur) — SAF fonksiyon, DOM yazmaz.
//   7. _gmGunKategoriSayac: kategori → sayaç; boş/girişsiz → {}.
//
// RED-BEFORE: _gmGunKatla gecmis.js'te yokken tüm testler kırmızıdır.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { exposed } = loadBrowserModule('js/gecmis.js', {
  expose: ['_gmGunKatla', '_gmGunKategoriSayac'],
});
const { _gmGunKatla, _gmGunKategoriSayac } = exposed;

// yardımcı: islem_log satır entry'si üret (gün hattı çıktısıyla aynı alanlar)
const islemEntry = (tip, eventAt, kupeNo = 'K1') => ({
  type: 'islem', category: 'islem', sourceKey: 'islem_log',
  eventAt, dateKey: eventAt.slice(0, 10), olayGunu: eventAt.slice(0, 10),
  undoRef: null, data: { id: 'isl-' + kupeNo + '-' + eventAt, tip, ana_hayvan_id: 'A-' + kupeNo, snapshot: { kupe_no: kupeNo } },
});
const stokEntry = (eventAt, urun = 'Enrolen') => ({
  type: 'stok', category: 'stok', sourceKey: 'stok_hareket',
  eventAt, dateKey: eventAt.slice(0, 10), olayGunu: eventAt.slice(0, 10),
  undoRef: null, data: { stok_id: 'S1', tur: 'Çıkış', miktar: 1, _urunAdi: urun },
});

test('≥3 aynı tip+kaynak+dakika → TEK grup (U1 md.3: "🩺 Tedavi Günü Eklendi — 12 hayvan")', () => {
  const net = ['2026-09-13T06:00:00Z', '2026-09-13T06:00:30Z', '2026-09-13T06:00:59Z'] // TR 09:00 dakikası
    .map(t => islemEntry('TEDAVI_GUN_EKLENDI', t));
  const d = _gmGunKatla(net);
  assert.strictEqual(d.length, 1, '3 satır tek düğüm olmalı');
  assert.strictEqual(d[0].grup, true);
  assert.strictEqual(d[0].count, 3);
  assert.strictEqual(d[0].tip, 'TEDAVI_GUN_EKLENDI');
  assert.strictEqual(d[0].sourceKey, 'islem_log');
  assert.strictEqual(d[0].entries.length, 3);
  assert.strictEqual(d[0].dakika, '09:00');
});

test('<3 satır katlanmaz: 2 özdeş satır → 2 tek düğüm', () => {
  const girdi = [
    islemEntry('ASI_KAYDI', '2026-09-13T06:00:00Z', 'K1'),
    islemEntry('ASI_KAYDI', '2026-09-13T06:00:30Z', 'K2'),
  ];
  const d = _gmGunKatla(girdi);
  assert.strictEqual(d.length, 2);
  d.forEach(n => { assert.strictEqual(n.tek, true); assert.strictEqual(n.entry.data.tip, 'ASI_KAYDI'); });
});

test('tam eşik: 3. satır gelmeden katlanmaz, 3. ile grup olur', () => {
  const a = [islemEntry('TOPLU_ILAC', '2026-09-13T06:00:00Z'), islemEntry('TOPLU_ILAC', '2026-09-13T06:00:10Z')];
  assert.strictEqual(_gmGunKatla(a).length, 2, '2 satır → 2 tek');
  const b = [...a, islemEntry('TOPLU_ILAC', '2026-09-13T06:00:20Z')];
  const d = _gmGunKatla(b);
  assert.strictEqual(d.length, 1, '3 satır → 1 grup');
  assert.strictEqual(d[0].count, 3);
});

test('farklı tip → ayrı düğüm (islem: data.tip anahtarı)', () => {
  const girdi = [
    islemEntry('TEDAVI_GUN_EKLENDI', '2026-09-13T06:00:00Z'),
    islemEntry('TEDAVI_GUN_EKLENDI', '2026-09-13T06:00:30Z'),
    islemEntry('TEDAVI_GUN_EKLENDI', '2026-09-13T06:00:59Z'),
    islemEntry('TOPLU_ILAC', '2026-09-13T06:00:30Z'),
  ];
  const d = _gmGunKatla(girdi);
  assert.strictEqual(d.length, 2, 'aynı dakika ama farklı tip → grup + tek');
  assert.strictEqual(d[0].grup, true);
  assert.strictEqual(d[0].count, 3);
  assert.strictEqual(d[1].tek, true);
  assert.strictEqual(d[1].entry.data.tip, 'TOPLU_ILAC');
});

test('farklı dakika → ayrı; farklı kaynak → ayrı; farklı gün → ayrı', () => {
  const dakika = [
    islemEntry('TOPLU_ILAC', '2026-09-13T06:00:00Z'),  // TR 09:00 — yalnız
    islemEntry('TOPLU_ILAC', '2026-09-13T06:01:00Z'),  // TR 09:01 — 3'lü grup
    islemEntry('TOPLU_ILAC', '2026-09-13T06:01:30Z'),
    islemEntry('TOPLU_ILAC', '2026-09-13T06:01:59Z'),
  ];
  const d1 = _gmGunKatla(dakika);
  assert.strictEqual(d1.length, 2, 'farklı dakika → 1 tek + 1 grup');
  assert.strictEqual(d1[0].tek, true);
  assert.strictEqual(d1[1].grup, true);
  assert.strictEqual(d1[1].count, 3);

  const kaynak = [
    stokEntry('2026-09-13T06:00:00+03:00'),
    stokEntry('2026-09-13T06:00:30+03:00'),
    stokEntry('2026-09-13T06:00:59+03:00'),
    { ...islemEntry('TOPLU_ILAC', '2026-09-13T03:00:00Z') }, // TR 06:00 aynı dakika, başka kaynak
    { ...islemEntry('TOPLU_ILAC', '2026-09-13T03:00:30Z') },
    { ...islemEntry('TOPLU_ILAC', '2026-09-13T03:00:59Z') },
  ];
  const d2 = _gmGunKatla(kaynak);
  assert.strictEqual(d2.length, 2, 'farklı sourceKey → iki ayrı grup');
  assert.ok(d2.every(n => n.grup && n.count === 3));

  const gun = [
    islemEntry('ASI_KAYDI', '2026-09-12T06:00:00Z'),
    islemEntry('ASI_KAYDI', '2026-09-12T06:00:30Z'),
    islemEntry('ASI_KAYDI', '2026-09-12T06:00:59Z'),
    islemEntry('ASI_KAYDI', '2026-09-13T06:00:00Z'),
    islemEntry('ASI_KAYDI', '2026-09-13T06:00:30Z'),
    islemEntry('ASI_KAYDI', '2026-09-13T06:00:59Z'),
  ];
  const d3 = _gmGunKatla(gun);
  assert.strictEqual(d3.length, 2, 'farklı gün → iki ayrı grup');
  assert.ok(d3.every(n => n.grup && n.count === 3));
});

test('saat damgası olmayan satır (yalnız date kolonu) ASLA katılmaz', () => {
  const toh = (tarih, i) => ({
    type: 'tohumlama', category: 'tohumlama', sourceKey: 'tohumlama',
    eventAt: tarih, dateKey: tarih.slice(0, 10), olayGunu: tarih.slice(0, 10),
    undoRef: null, data: { id: 'T' + i, hayvan_id: 'A' + i, tarih, sonuc: 'Bekliyor' },
  });
  const girdi = [toh('2026-09-13', 1), toh('2026-09-13', 2), toh('2026-09-13', 3), toh('2026-09-13', 4)];
  const d = _gmGunKatla(girdi);
  assert.strictEqual(d.length, 4, 'aynı gün ama dakika kanıtı yok → 4 tek düğüm');
  assert.ok(d.every(n => n.tek));
});

test('sıra korunur: grup ilk üyesinin yerine oturur (desc giriş)', () => {
  const girdi = [
    islemEntry('ASI_KAYDI', '2026-09-13T10:00:00Z'),          // en yeni — tek
    islemEntry('TOPLU_ILAC', '2026-09-13T06:00:59Z'),          // grup üyesi (ilk)
    islemEntry('TOPLU_ILAC', '2026-09-13T06:00:30Z'),
    islemEntry('TOPLU_ILAC', '2026-09-13T06:00:00Z'),
    islemEntry('ASI_KAYDI', '2026-09-13T05:00:00Z'),           // en eski — tek
  ];
  const d = _gmGunKatla(girdi);
  // vm-realm dizini → join ile düz metin kıyas (deepStrictEqual realm-prototipi ister)
  assert.strictEqual(
    d.map(n => n.grup ? 'G(' + n.tip + ':' + n.count + ')' : 'T(' + n.entry.data.tip + ')').join('|'),
    ['T(ASI_KAYDI)', 'G(TOPLU_ILAC:3)', 'T(ASI_KAYDI)'].join('|'),
  );
});

test('boş/eksik giriş → boş düğüm listesi; sayaç boş nesne', () => {
  // not: vm-realm değerleri deepStrictEqual'e girmez (prototype farklı context'ten)
  // — uzunluk/anahtar üzerinden kıyas
  assert.strictEqual(Array.isArray(_gmGunKatla([])), true);
  assert.strictEqual(_gmGunKatla([]).length, 0);
  assert.strictEqual(_gmGunKatla().length, 0);
  assert.strictEqual(Object.keys(_gmGunKategoriSayac([])).length, 0);
  assert.strictEqual(Object.keys(_gmGunKategoriSayac()).length, 0);
});

test('çip sayaçları: kategori başına doğru sayı (filre ÖNCESİ tüm gün)', () => {
  const girdi = [
    islemEntry('TEDAVI_GUN_EKLENDI', '2026-09-13T06:00:00Z'),
    stokEntry('2026-09-13T06:00:00+03:00'),
    stokEntry('2026-09-13T07:00:00+03:00'),
    { type: 'asi', category: 'asi', sourceKey: 'vaccination_log', eventAt: '2026-09-13', dateKey: '2026-09-13', olayGunu: '2026-09-13', undoRef: null, data: { animal_id: 'A1', vaccination_date: '2026-09-13' } },
    { type: 'asi', category: 'asi', sourceKey: 'vaccination_log', eventAt: '2026-09-13', dateKey: '2026-09-13', olayGunu: '2026-09-13', undoRef: null, data: { animal_id: 'A2', vaccination_date: '2026-09-13' } },
  ];
  const s = _gmGunKategoriSayac(girdi);
  assert.strictEqual(s.islem, 1);
  assert.strictEqual(s.stok, 2);
  assert.strictEqual(s.asi, 2);
  assert.strictEqual(s.dogum, undefined, 'olmayan kategori anahtarı üretmez');
  // toplam sayaçların toplamı = entry sayısı
  assert.strictEqual(Object.values(s).reduce((a, b) => a + b, 0), girdi.length);
});
