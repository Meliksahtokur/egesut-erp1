// tests/unit/dosage.test.js
// js/utils/helpers.js → dozOner (tedavi dozajlama helperi, spec
// .claude/plans/2026-09-09-tedavi-doz-gorev-design.md §3.2) birim testleri.
//
// Sözleşme:
// 1. 'ml/kg': doz = canlı ağırlık × std_dose; birim kart default_unit'i; ağırlık
//    yoksa/0 ise ok:false 'ağırlık' gerekçesi.
// 2. 'mg/kg': doz = ağırlık × std_dose ÷ concentration(mg/ml); birim her zaman ml;
//    concentration yoksa ok:false — asla yanlış veriyle hesap yapılmaz.
// 3. 'ml/hayvan': doz = std_dose (sabit) — ağırlık gerekmez.
// 4. Kartta std_dose yoksa ok:false. Sonuçlar 1 ondalığa yuvarlanır; ≤0 → ok:false.
// 5. Açıklama metni TR ondalık virgüllü ('650 kg × 2 ml/kg = 13 ml').
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { dozOner } = require('../../js/utils/helpers.js');

test('dozOner: ml/kg yolu — ağırlık × oran, birim karttan', () => {
  const kart = { std_dose: 2, std_dose_unit: 'ml/kg', default_unit: 'ml' };
  const r = dozOner(650, kart);
  assert.equal(r.ok, true);
  assert.equal(r.doz, 1300);
  assert.equal(r.birim, 'ml');
  assert.equal(r.aciklama, '650 kg × 2 ml/kg = 1300 ml');
});

test('dozOner: ml/kg ondalık yuvarlama (1 ondalık) + TR virgül', () => {
  const kart = { std_dose: 0.03, std_dose_unit: 'ml/kg', default_unit: 'ml' };
  const r = dozOner(548, kart);
  assert.equal(r.ok, true);
  assert.equal(r.doz, 16.4); // 548 × 0,03 = 16,44 → 16,4
  assert.equal(r.aciklama.includes('548 kg × 0,03 ml/kg = 16,4 ml'), true);
});

test('dozOner: mg/kg + konsantrasyon → ml çevirimi', () => {
  const kart = { std_dose: 2, std_dose_unit: 'mg/kg', concentration: 100, concentration_unit: 'mg/ml', default_unit: 'ml' };
  const r = dozOner(650, kart);
  assert.equal(r.ok, true);
  assert.equal(r.doz, 13); // 650×2=1300 mg ÷ 100 mg/ml = 13 ml
  assert.equal(r.birim, 'ml');
  assert.equal(r.aciklama, '650 kg × 2 mg/kg ÷ 100 mg/ml = 13 ml');
});

test('dozOner: mg/kg ama konsantrasyon yok — hesap YAPILMAZ', () => {
  const kart = { std_dose: 2, std_dose_unit: 'mg/kg', concentration: null, default_unit: 'ml' };
  const r = dozOner(650, kart);
  assert.equal(r.ok, false);
  assert.match(r.neden, /konsantrasyon/i);
});

test('dozOner: ml/hayvan — sabit doz, ağırlık gerekmez', () => {
  const kart = { std_dose: 2.5, std_dose_unit: 'ml/hayvan', default_unit: 'ml' };
  const r = dozOner(null, kart);
  assert.equal(r.ok, true);
  assert.equal(r.doz, 2.5);
  assert.equal(r.birim, 'ml');
  assert.equal(r.aciklama, 'sabit doz: 2,5 ml');
});

test('dozOner: kart yok / std_dose yok — ok:false', () => {
  assert.equal(dozOner(650, null).ok, false);
  assert.equal(dozOner(650, { std_dose: null, std_dose_unit: 'ml/kg' }).ok, false);
  assert.equal(dozOner(650, {}).ok, false);
});

test('dozOner: ağırlık yok / 0 / negatif — ml/kg ve mg/kg yollarında ok:false', () => {
  const mlkg = { std_dose: 2, std_dose_unit: 'ml/kg' };
  const mgkg = { std_dose: 2, std_dose_unit: 'mg/kg', concentration: 100 };
  for (const ag of [null, undefined, 0, -5, 'abc']) {
    assert.equal(dozOner(ag, mlkg).ok, false);
    assert.equal(dozOner(ag, mgkg).ok, false);
  }
  // ml/hayvan aynı koşulda OK — ağırlık kullanmıyor
  assert.equal(dozOner(null, { std_dose: 2, std_dose_unit: 'ml/hayvan' }).ok, true);
});

test('dozOner: sıfıra yuvarlanan doz ok:false (0,04 × 50 kg = 2 → OK; 0,001 × 50 → 0,1 OK; 0,0001 × 50 → 0)', () => {
  assert.equal(dozOner(50, { std_dose: 0.001, std_dose_unit: 'ml/kg' }).ok, true);  // 0,05 → 0,1 (yuvarlama 1 ondalık)
  assert.equal(dozOner(50, { std_dose: 0.0001, std_dose_unit: 'ml/kg' }).ok, false); // 0,005 → 0
});

test('dozOner: std_dose_unit eksikse varsayım ml/kg', () => {
  const r = dozOner(100, { std_dose: 1, default_unit: 'ml' });
  assert.equal(r.ok, true);
  assert.equal(r.doz, 100);
});
