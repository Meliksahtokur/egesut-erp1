// tests/unit/geri-al-baslik.test.js
// L4-W2 — işlem dili başlık şablonu (zarf B; plan §5).
//
// Sözleşme: `${olayEtiketi} — ${gg.aa ss:dd} · ${kim}` — TEK kaynak
// _gmIslemBaslikSatiri (js/gecmis.js). Ham UUID/tx/BUYUK_HARF_KOD asla görünmez;
// GERI_ALINDI "X geri alındı" kalıbıyla anlatır (sahibin örnek başlığı).

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { exposed } = loadBrowserModule('js/gecmis.js', {
  expose: ['_gmGeriAlBaglam', '_gmGeriAlindiEtiketi', '_gmIslemBaslikSatiri', '_GM_ISLEM_TIP_ETIKET'],
});
const { _gmGeriAlBaglam, _gmGeriAlindiEtiketi, _gmIslemBaslikSatiri, _GM_ISLEM_TIP_ETIKET } = exposed;

test('başlık şablonu: etiket — gg.aa ss:dd · küpe', () => {
  const baglam = _gmGeriAlBaglam({
    tip: 'GOREV_TAMAMLA',
    created_at: '2026-09-14T17:25:00+03:00',
    snapshot: { kupe_no: '4019' },
  });
  const b = _gmIslemBaslikSatiri(baglam);
  assert.strictEqual(b, 'Görev Tamamlandı — 14.09 17:25 · 4019');
});

test('başlıkta ham UUID ASLA yok — kim çözülemiyorsa parça hiç girmez', () => {
  const baglam = _gmGeriAlBaglam({ tip: 'TOHUMLAMA', created_at: '2026-09-13T09:30:00Z' });
  const b = _gmIslemBaslikSatiri(baglam);
  assert.ok(!/[0-9a-f]{8}-[0-9a-f]{4}/i.test(b), 'uuid sızıntısı: ' + b);
  assert.strictEqual(b, 'Tohumlama — 13.09 12:30');
});

test('zamansız entryde başlık yalnız etikettir', () => {
  assert.strictEqual(_gmIslemBaslikSatiri({ olayEtiketi: 'Doğum', zaman: '', kim: '' }), 'Doğum');
  assert.strictEqual(_gmIslemBaslikSatiri(null), 'İşlem');
});

test('GERI_ALINDI: payload.orijinal_tip → "Tohumlama geri alındı"', () => {
  const etiket = _gmGeriAlindiEtiketi({
    tip: 'GERI_ALINDI',
    payload: { orijinal_tip: 'TOHUMLAMA', seviye: 'islem', adim: 2 },
  });
  assert.strictEqual(etiket, 'Tohumlama geri alındı');
  const baglam = _gmGeriAlBaglam({
    tip: 'GERI_ALINDI',
    payload: { orijinal_tip: 'GOREV_TAMAMLA' },
    created_at: '2026-09-14T18:02:00+03:00',
    snapshot: { kupe_no: '4019' },
  });
  assert.strictEqual(baglam.olayEtiketi, 'Görev Tamamlandı geri alındı');
  const b = _gmIslemBaslikSatiri(baglam);
  assert.strictEqual(b, 'Görev Tamamlandı geri alındı — 14.09 18:02 · 4019');
});

test('L4-06 — orijinal_tip gerçek tipi etiketler; harf-kümesi kalıntısı nötr "Kayıt geri alındı"', () => {
  // W1'in eski SQL'i orijinal_tip'e I,U,D harf-kümesi yazıyordu; W4 gerçek tip
  // yazar. Çözücü harf-kümesini (ve eksik/bilinmeyeni) işlem tipi GİBİ
  // etiketLEMEZ — nötr 'Kayıt' döner ("İşlem: i,u,d geri alındı" üretmez).
  assert.strictEqual(_gmGeriAlindiEtiketi({ tip: 'GERI_ALINDI', payload: { orijinal_tip: 'I,U,D' } }), 'Kayıt geri alındı');
  assert.strictEqual(_gmGeriAlindiEtiketi({ tip: 'GERI_ALINDI', payload: { orijinal_tip: 'I' } }), 'Kayıt geri alındı');
  assert.strictEqual(_gmGeriAlindiEtiketi({ tip: 'GERI_ALINDI', payload: { orijinal_tip: 'I, U ,D' } }), 'Kayıt geri alındı');
  assert.strictEqual(_gmGeriAlindiEtiketi({ tip: 'GERI_ALINDI', payload: { orijinal_tip: '' } }), 'Kayıt geri alındı');
  assert.strictEqual(_gmGeriAlindiEtiketi({ tip: 'GERI_ALINDI' }), 'Kayıt geri alındı');
  assert.strictEqual(_gmGeriAlindiEtiketi(null), 'Kayıt geri alındı');
  // gerçek tip aynen etiketlenir (W4 sözleşmesi)
  assert.strictEqual(_gmGeriAlindiEtiketi({ tip: 'GERI_ALINDI', payload: { orijinal_tip: 'ASI_KAYDI' } }), 'Aşı Kaydı geri alındı');
});

test('GERI_ALINDI tip haritada: etiket Türkçe, ham kod yok', () => {
  assert.strictEqual(_GM_ISLEM_TIP_ETIKET.GERI_ALINDI, 'Geri Alındı');
});

test('kim override: çağıranın verdiği küpe önceliklidir', () => {
  const baglam = _gmGeriAlBaglam({ tip: 'TOHUMLAMA', snapshot: { kupe_no: 'eski' } }, 'yeni-4019');
  assert.strictEqual(baglam.kim, 'yeni-4019');
});
