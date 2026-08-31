const test = require('node:test');
const assert = require('node:assert');
const { loadExtractedFunction } = require('./support/loadModule.js');

// B6: offline kuyruk replay parametre builder'ı — canlı pg_get_functiondef
// imzalarıyla (2026-08-31 doğrulandı) kilitlenir. Yanlış adlı anahtarı
// supabase-js sessizce yutar → Postgres DEFAULT/NULL → sessiz veri kaybı.

const buildRpcParams = loadExtractedFunction('js/ui.js', 'buildRpcParams');

test('hayvan_ekle: canlı imza alanları (p_grup/p_irk), p_grup_id/p_irk_id YOK', () => {
  const p = buildRpcParams('hayvan_ekle', { kupe_no: 'TR1', grup: 'Besi', irk: 'Simental', cinsiyet: 'Erkek' }, { method: 'POST' });
  assert.strictEqual(p.p_kupe_no, 'TR1');
  assert.strictEqual(p.p_grup, 'Besi');
  assert.strictEqual(p.p_irk, 'Simental');
  assert.ok(!('p_grup_id' in p), 'p_grup_id canlı imzada yok');
  assert.ok(!('p_irk_id' in p), 'p_irk_id canlı imzada yok');
  assert.strictEqual(p.p_cinsiyet, 'Erkek');
});

test('hayvan_ekle: padok_id yalnız varsa gönderilir (overload uyumu)', () => {
  const base = buildRpcParams('hayvan_ekle', { kupe_no: 'X' }, { method: 'POST' });
  assert.ok(!('p_padok_id' in base));
  const withPadok = buildRpcParams('hayvan_ekle', { kupe_no: 'X', padok_id: 'u-1' }, { method: 'POST' });
  assert.strictEqual(withPadok.p_padok_id, 'u-1');
});

test('hayvan_guncelle: tam-satır update, p_alan/p_deger YOK, p_id filterdan', () => {
  const p = buildRpcParams('hayvan_guncelle', { kupe_no: 'TR2', padok: 'Besi Padok' }, { method: 'PATCH', filter: 'id=eq.ABC' });
  assert.strictEqual(p.p_id, 'ABC');
  assert.strictEqual(p.p_padok, 'Besi Padok');
  assert.ok(!('p_alan' in p), 'p_alan canlı imzada yok');
  assert.ok(!('p_deger' in p), 'p_deger canlı imzada yok');
});

test('hayvan_guncelle: kisir yalnız tanımlıysa gider', () => {
  const p = buildRpcParams('hayvan_guncelle', { kupe_no: 'X', kisir: true }, { method: 'PATCH', filter: 'id=eq.K' });
  assert.strictEqual(p.p_kisir, true);
  const p2 = buildRpcParams('hayvan_guncelle', { kupe_no: 'X' }, { method: 'PATCH', filter: 'id=eq.K' });
  assert.ok(!('p_kisir' in p2));
});

test('tohumlama_kaydet: p_sperma zorunlu alan; p_sperma_kodu/p_teknisyen YOK', () => {
  const p = buildRpcParams('tohumlama_kaydet', { hayvan_id: 'H1', tarih: '2026-08-31', sperma: 'SIM-1' }, { method: 'POST' });
  assert.strictEqual(p.p_sperma, 'SIM-1');
  assert.ok(!('p_sperma_kodu' in p));
  assert.ok(!('p_teknisyen' in p));
  // vm realm dizisi — deepStrictEqual prototip farkından düşer, yapısal kontrol
  assert.strictEqual(JSON.stringify(p.p_ek_uygulamalar), '[]');
  assert.strictEqual(p.p_vwp_override, false);
});

test('dogum_kaydet: p_kupe/p_cins; p_buzagi_* YOK, legacy alan adlarına fallback', () => {
  const p = buildRpcParams('dogum_kaydet', { anne_id: 'A1', tarih: '2026-08-31', kupe: 'B1', cins: 'Dişi' }, { method: 'POST' });
  assert.strictEqual(p.p_kupe, 'B1');
  assert.strictEqual(p.p_cins, 'Dişi');
  assert.ok(!('p_buzagi_kupe' in p));
  assert.ok(!('p_buzagi_cinsiyet' in p));
  const legacy = buildRpcParams('dogum_kaydet', { anne_id: 'A1', buzagi_kupe: 'B2', buzagi_cinsiyet: 'Erkek' }, { method: 'POST' });
  assert.strictEqual(legacy.p_kupe, 'B2');
  assert.strictEqual(legacy.p_cins, 'Erkek');
});

test('create_case: p_animal_id/p_disease_id/p_notes; p_hayvan_id/p_tanis YOK', () => {
  const p = buildRpcParams('create_case', { animal_id: 'A1', disease_id: 'd-1', notes: 'not' }, { method: 'POST' });
  assert.strictEqual(p.p_animal_id, 'A1');
  assert.strictEqual(p.p_disease_id, 'd-1');
  assert.strictEqual(p.p_notes, 'not');
  assert.ok(!('p_hayvan_id' in p));
  assert.ok(!('p_tanis' in p));
});

test('add_drug_administration: p_time YOK (canlı imzada saat parametresi yok)', () => {
  const p = buildRpcParams('add_drug_administration', { day_id: 'day-1', drug_product_id: 'dp-1', stok_id: 's-1', dose: 5, unit: 'ml', route: 'IM', time: '10:00' }, { method: 'POST' });
  assert.ok(!('p_time' in p), 'p_time canlı imzada yok — sessizce düşmeli');
  assert.strictEqual(p.p_day_id, 'day-1');
  assert.strictEqual(p.p_stok_id, 's-1');
});

test('gorev_guncelle: p_id/p_aciklama/p_hedef_tarih/p_gorev_tipi (p_gorev_id YOK)', () => {
  const p = buildRpcParams('gorev_guncelle', { id: 'G1', aciklama: 'x', hedef_tarih: '2026-09-01' }, { method: 'PATCH' });
  assert.strictEqual(p.p_id, 'G1');
  assert.strictEqual(p.p_hedef_tarih, '2026-09-01');
  assert.ok(!('p_gorev_id' in p));
  assert.ok(!('p_padok_hedef' in p));
});
