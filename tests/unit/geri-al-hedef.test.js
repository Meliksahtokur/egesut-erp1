// tests/unit/geri-al-hedef.test.js
// L4-W2 — _gmGeriAlHedef çözücü tablosu (tip × kaynak durumu; zarf A.2).
//
// Sözleşme (goal frozen contract "Hedef çözücü"):
//   1. Öncelik: degisim_txid → ref_tablo+ref_id(+created_at zaman) → tip fallback.
//   2. Çıktı: {tablo,pk,txid} | {tablo,pk,zaman} | {txid} | null.
//   3. GERI_ALINDI kartının hedefi = geri alma tx'i ({txid} — akış f).
//   4. null = buton YOK (ham UUID/tx içeren hedef asla üretilmez; tip fallback'te
//      pk çözülemeyen DOGUM/KIZGINLIK kaydı null döner → yönlendirme yoluna düşer).
//
// RED-BEFORE: _gmGeriAlHedef gecmis.js'te yokken bu dosya kırmızıdır.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { exposed } = loadBrowserModule('js/gecmis.js', {
  expose: ['_gmGeriAlHedef', '_gmGeriAlBaglam', '_gmGeriAlindiEtiketi', '_gmIslemBaslikSatiri'],
});
const { _gmGeriAlHedef } = exposed;

test('öncelik 1 — degisim_txid varsa kesin köprü: {tablo,pk,txid}', () => {
  const h = _gmGeriAlHedef({
    id: 'l1', tip: 'TOHUMLAMA', ref_tablo: 'tohumlama', ref_id: 'toh-9',
    degisim_txid: '12345678901', created_at: '2026-09-13T17:25:00+03:00',
  });
  assert.strictEqual(JSON.stringify(h), JSON.stringify({ tablo: 'tohumlama', pk: 'toh-9', txid: '12345678901' }));
});

test('öncelik 1 — txidli entryde ref yoksa hedef yalnız txid taşır', () => {
  const h = _gmGeriAlHedef({ id: 'l2', tip: 'GOREV_TAMAMLA', degisim_txid: '999' });
  assert.strictEqual(JSON.stringify(h), JSON.stringify({ txid: '999' }));
});

test('öncelik 1 — txid sayısal olmayan değerse güvenli null', () => {
  assert.strictEqual(_gmGeriAlHedef({ tip: 'TOHUMLAMA', degisim_txid: 'abc' }), null);
  assert.strictEqual(_gmGeriAlHedef({ tip: 'TOHUMLAMA', degisim_txid: '  ' }), null);
});

test('GERI_ALINDI kartı — hedef = geri alma tx işlemi ({txid}); ref bilgisi taşınmaz', () => {
  const h = _gmGeriAlHedef({
    id: 'l3', tip: 'GERI_ALINDI', ref_tablo: 'tohumlama', ref_id: 'toh-9',
    degisim_txid: '888777', payload: { orijinal_tip: 'TOHUMLAMA', seviye: 'islem', adim: 2 },
  });
  assert.strictEqual(JSON.stringify(h), JSON.stringify({ txid: '888777' }));
});

test('öncelik 2 — ref_tablo+ref_id doluysa zaman created_at işleminin ardından kurulur', () => {
  const h = _gmGeriAlHedef({
    id: 'l4', tip: 'HASTALIK_KAYDI', ref_tablo: 'cases', ref_id: 'case-1',
    created_at: '2026-09-13T19:37:00Z', tarih: '2026-09-12',
  });
  assert.strictEqual(JSON.stringify(h), JSON.stringify({ tablo: 'cases', pk: 'case-1', zaman: '2026-09-13T19:37:00Z' }));
});

test('öncelik 2 — created_at yoksa hedef zamansız döner (sunucu yönlendirir)', () => {
  const h = _gmGeriAlHedef({ tip: 'HASTALIK_KAYDI', ref_tablo: 'cases', ref_id: 'case-1' });
  assert.strictEqual(JSON.stringify(h), JSON.stringify({ tablo: 'cases', pk: 'case-1' }));
});

// ── Tip fallback tablosu (ref boş — plan raporu §2 istisnaları) ──────
test('fallback — DOGUM_KAYDI: snapshot.id → {tablo:dogum, pk, zaman}', () => {
  const h = _gmGeriAlHedef({
    tip: 'DOGUM_KAYDI', ana_hayvan_id: 'anne-1',
    snapshot: { id: 'dogum-5', yavru_kupe: 'Y1' }, created_at: '2026-09-13T10:00:00Z',
  });
  assert.strictEqual(JSON.stringify(h), JSON.stringify({ tablo: 'dogum', pk: 'dogum-5', zaman: '2026-09-13T10:00:00Z' }));
});

test('fallback — DOGUM_KAYDI: pk çözülemiyorsa NULL (buton yok, yönlendirme)', () => {
  assert.strictEqual(_gmGeriAlHedef({ tip: 'DOGUM_KAYDI', ana_hayvan_id: 'anne-1' }), null);
});

test('fallback — KIZGINLIK/KIZGINLIK_KAYDI: snapshot.id → kizginlik_log', () => {
  for (const tip of ['KIZGINLIK', 'KIZGINLIK_KAYDI']) {
    const h = _gmGeriAlHedef({ tip, snapshot: { id: 'kiz-1' } });
    assert.strictEqual(h.tablo, 'kizginlik_log');
    assert.strictEqual(h.pk, 'kiz-1');
  }
});

test('fallback — TOHUMLAMA ailesi ref boşsa snapshot.id ile tohumlama satırı', () => {
  for (const tip of ['TOHUMLAMA', 'TOHUMLAMA_GUNCELLENDI', 'ABORT_KAYDI']) {
    const h = _gmGeriAlHedef({ tip, snapshot: { id: 'toh-3' } });
    assert.strictEqual(h.tablo, 'tohumlama');
    assert.strictEqual(h.pk, 'toh-3');
  }
});

test('fallback — HAYVAN_EKLENDI/GUNCELLENDI: ana_hayvan_id → hayvanlar', () => {
  for (const tip of ['HAYVAN_EKLENDI', 'HAYVAN_GUNCELLENDI']) {
    const h = _gmGeriAlHedef({ tip, ana_hayvan_id: 'hv-1', created_at: '2026-09-13T09:00:00Z' });
    assert.strictEqual(h.tablo, 'hayvanlar');
    assert.strictEqual(h.pk, 'hv-1');
    assert.strictEqual(h.zaman, '2026-09-13T09:00:00Z');
  }
});

test('fallback — GOREV_TAMAMLA: ref_id → gorev_log (degisim_txid yoksa)', () => {
  const h = _gmGeriAlHedef({ tip: 'GOREV_TAMAMLA', ref_id: 'gorev-7' });
  assert.strictEqual(h.tablo, 'gorev_log');
  assert.strictEqual(h.pk, 'gorev-7');
});

test('fallback — SUTTEN_KESME: ana_hayvan_id → hayvanlar', () => {
  const h = _gmGeriAlHedef({ tip: 'SUTTEN_KESME', ana_hayvan_id: 'buzagi-2' });
  assert.strictEqual(h.tablo, 'hayvanlar');
  assert.strictEqual(h.pk, 'buzagi-2');
});

test('bilinmeyen/hedefsiz tip → null (buton yok kuralı)', () => {
  assert.strictEqual(_gmGeriAlHedef(null), null);
  assert.strictEqual(_gmGeriAlHedef(undefined), null);
  assert.strictEqual(_gmGeriAlHedef({ tip: 'BILINMEYEN_TIPI' }), null);
  assert.strictEqual(_gmGeriAlHedef({}), null);
});
