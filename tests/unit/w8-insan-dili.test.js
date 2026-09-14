// tests/unit/w8-insan-dili.test.js
// L4-W8 — insan dili paketi (root R1 düzeltmesi, D1+D3+D4) saf birim testleri.
//
// Sözleşmeler (zarf L4-W8-D1-D3-D4 + R1):
//   D1: tx detay başlık liste kartıyla AYNI üreticiden (_dgKartBaslik) + zaman
//       + kim (küpe); görünür alanda ham UUID / "tablo (n)" özeti / kaynak
//       dizesi YOK; 'Kayıt no' (id) satırı teknik katlamada; bilinen kod
//       DEĞERLERİ gecmis.js TEK haritadan Türkçeleşir (olmayan aynen).
//   D3: hayvan referansı ham id/UUID değil; çözülemeyen '?' DEĞİL nötr kısa
//       etiket; gorev boş etiket → tip etiketi ("Görev Tamamlandı").
//   D4: zincir adım fiilleri GUNCELLE/SIL/EKLE → Güncellendi/Silindi/Eklendi;
//       U adımlarında eski/yeni'den ilk anlamlı 1-2 alan özeti.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const HAM_UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;

const diff = loadBrowserModule('js/degisiklikler/diff.js', { extra: {} });
const etiket = loadBrowserModule('js/degisiklikler/etiketler.js', { extra: {} });
const gecmis = loadBrowserModule('js/gecmis.js', {
  extra: {},
  expose: ['gmKodDegerEtiketi', 'gmHayvanEtiketVeya', 'gmNotlarGorunur', '_gmIslemBaslikSatiri'],
});
const dg = loadBrowserModule('js/degisiklikler/degisiklikler.js', {
  extra: {
    registerActions: () => {},
    esc: escMirror,
    fmtTarihSaat: () => '12.09.2026 12:05',
    tabloEtiketi: etiket.sandbox.tabloEtiketi,
    alanEtiketi: etiket.sandbox.alanEtiketi,
    islemEtiketi: etiket.sandbox.islemEtiketi,
    degerMetni: diff.sandbox.degerMetni,
    pkKisa: diff.sandbox.pkKisa,
    islemOzeti: diff.sandbox.islemOzeti,
    dgAlanSirala: diff.sandbox.dgAlanSirala,
  },
  expose: ['dgAlanSatiriGorunurMu', 'dgTxKimMetni', 'dgDetayBaslikMetni', 'dgZincirAdimEtiketi', 'dgZincirAlanOzeti'],
});

const { gmKodDegerEtiketi, gmHayvanEtiketVeya, gmNotlarGorunur, _gmIslemBaslikSatiri } = gecmis.exposed;
const { dgAlanSatiriGorunurMu, dgTxKimMetni, dgDetayBaslikMetni, dgZincirAdimEtiketi, dgZincirAlanOzeti } = dg.exposed;

// ── D1/D3: kod DEĞER → TR (gecmis.js TEK harita; uydurma yok) ──────────
test('gmKodDegerEtiketi: TEDAVI GUN (boşluklu senaryo değeri) → Tedavi Günü', () => {
  assert.strictEqual(gmKodDegerEtiketi('gorev_tipi', 'TEDAVI GUN'), 'Tedavi Günü');
  assert.strictEqual(gmKodDegerEtiketi('gorev_tipi', 'TEDAVI_GUN'), 'Tedavi Günü');
});

test('gmKodDegerEtiketi: diğer gorev_tipi değerleri haritalı', () => {
  assert.strictEqual(gmKodDegerEtiketi('gorev_tipi', 'ILERI_GEBE_ASI'), 'İleri Gebe Aşısı');
  assert.strictEqual(gmKodDegerEtiketi('gorev_tipi', 'PADOK_DEGISIM'), 'Padok Değişimi');
  assert.strictEqual(gmKodDegerEtiketi('durum', 'active'), 'Aktif');
  assert.strictEqual(gmKodDegerEtiketi('status', 'closed'), 'Kapandı');
});

test('gmKodDegerEtiketi: haritada olmayan değer/alân null — çağıran aynen gösterir', () => {
  assert.strictEqual(gmKodDegerEtiketi('gorev_tipi', 'BILINMEYEN_TIP'), null);
  assert.strictEqual(gmKodDegerEtiketi('bilinmeyen_alan', 'active'), null);
  assert.strictEqual(gmKodDegerEtiketi('gorev_tipi', ''), null);
  assert.strictEqual(gmKodDegerEtiketi('gorev_tipi', null), null);
});

// ── D1: görünür alan satırı kilidi ──────────────────────────────────────
test('dgAlanSatiriGorunurMu: id (Kayıt no) satırı görünmez', () => {
  assert.strictEqual(dgAlanSatiriGorunurMu({ alan: 'id', durum: 'eklendi', yeni: '193a0625-4d3f-44ae-b9d6-73ba7fbeeee6' }), false);
});

test('dgAlanSatiriGorunurMu: ham UUID değerli hücre görünmez (S4-02 Kayıt no vakası)', () => {
  assert.strictEqual(dgAlanSatiriGorunurMu({ alan: 'protokol_instance_id', durum: 'eklendi', yeni: 'b134a06b-e850-4b61-b8bb-6400df42f08f' }), false);
  assert.strictEqual(dgAlanSatiriGorunurMu({ alan: 'notlar', durum: 'degisti', eski: '5bbea43e-8ec2-4469-a760-547c9929b2d9', yeni: 'ok' }), false);
});

test('dgAlanSatiriGorunurMu: normal alan görünür; null fark görünmez', () => {
  assert.strictEqual(dgAlanSatiriGorunurMu({ alan: 'gorev_tipi', durum: 'eklendi', yeni: 'TEDAVI GUN' }), true);
  assert.strictEqual(dgAlanSatiriGorunurMu({ alan: 'padok', durum: 'degisti', eski: 'A', yeni: 'B' }), true);
  assert.strictEqual(dgAlanSatiriGorunurMu(null), false);
});

// ── D1: tx kim (küpe) çözümü ────────────────────────────────────────────
test('dgTxKimMetni: hayvanlar satırının KENDİ küpesi (pk’dan) önce gelir', () => {
  const rows = [{ tablo_adi: 'hayvanlar', yeni: { id: 'abc', kupe_no: 'L4Y-01' } }];
  assert.strictEqual(dgTxKimMetni(rows, () => 'BAŞKA'), 'L4Y-01');
});

test('dgTxKimMetni: hayvan referans alanından çözülür (coz enjekte edilir)', () => {
  const rows = [{ tablo_adi: 'gorev_log', yeni: { hayvan_id: 'l4y-anne', gorev_tipi: 'TEDAVI GUN' } }];
  assert.strictEqual(dgTxKimMetni(rows, id => (id === 'l4y-anne' ? 'L4Y-01' : '')), 'L4Y-01');
});

test('dgTxKimMetni: çözülemeyen → boş (başlıkta parça hiç girmez, ? yok)', () => {
  const rows = [{ tablo_adi: 'gorev_log', yeni: { hayvan_id: '193a0625-4d3f-44ae-b9d6-73ba7fbeeee6' } }];
  assert.strictEqual(dgTxKimMetni(rows, () => ''), '');
  assert.strictEqual(dgTxKimMetni([], () => 'x'), '');
});

// ── D1: tx detay başlık — R1 unit kilidi ────────────────────────────────
test('dgDetayBaslikMetni: _dgKartBaslik + zaman + kim; ham özet/kaynak/UUID YOK', () => {
  const listeOzeti = { baslik: 'gorev_log (1)', islemler: { I: 1 } };
  const rows = [{
    tablo_adi: 'gorev_log', islem: 'I', zaman: '2026-09-12T09:05:00+00:00',
    satir_pk: '193a0625-4d3f-44ae-b9d6-73ba7fbeeee6',
    yeni: { hayvan_id: 'l4y-anne', gorev_tipi: 'TEDAVI GUN' },
  }];
  const kaynak = { app_name: 'Supavisor', istemci_etiketi: 'l4-yuruyus' };
  const b = dgDetayBaslikMetni(listeOzeti, rows, kaynak, id => (id === 'l4y-anne' ? 'L4Y-01' : ''), _gmIslemBaslikSatiri);
  // biçim: "<işlem dilli başlık> — gg.aa ss:dd · <küpe>"
  assert.match(b, / — 12\.09 \d{2}:\d{2} · L4Y-01$/);
  assert.doesNotMatch(b, HAM_UUID, 'ham UUID başlıkta yok');
  assert.doesNotMatch(b, /\w+ \(\d+\)/, 'tablo-özet kalıbı ("gorev_log (1)") başlıkta yok');
  assert.ok(!/Supavisor|istemci_etiket|l4-yuruyus/i.test(b), 'kaynak dizesi başlıkta yok: ' + b);
  assert.ok(!/gorev_log/.test(b), 'ham tablo adı başlıkta yok');
});

test('dgDetayBaslikMetni: listeOzeti yoksa ham başlık satırdan kurulur (doğrudan açılış)', () => {
  const rows = [{ tablo_adi: 'paddocks', islem: 'U', zaman: '2026-09-15T01:07:00+00:00', yeni: { ad: 'B' }, eski: { ad: 'A' } }];
  const b = dgDetayBaslikMetni(null, rows, null, () => '', _gmIslemBaslikSatiri);
  assert.ok(b.length > 0 && !HAM_UUID.test(b));
  assert.match(b, / — 15\.09 \d{2}:\d{2}$/); // kim çözülemedi → parça yok
});

test('dgDetayBaslikMetni: boş rows → nötr İşlem', () => {
  assert.strictEqual(dgDetayBaslikMetni(null, [], null, () => '', _gmIslemBaslikSatiri), 'İşlem');
});

// ── D3: hayvan referans nötr etiketi ────────────────────────────────────
test('gmHayvanEtiketVeya: id → küpe; kupe_no eşleşmesi; IDB indeksi yedeği', () => {
  const animals = [{ id: 'l4y-anne', kupe_no: 'L4Y-01' }, { id: 'x', kupe_no: 'TR093' }];
  const kupeById = { eski: 'ESKI-01' };
  assert.strictEqual(gmHayvanEtiketVeya('l4y-anne', null, animals, kupeById), 'L4Y-01');
  assert.strictEqual(gmHayvanEtiketVeya('TR093', null, animals, kupeById), 'TR093'); // kupe_no birebir
  assert.strictEqual(gmHayvanEtiketVeya('eski', null, animals, kupeById), 'ESKI-01');
});

test('gmHayvanEtiketVeya: çözülemeyen → nötr kısa etiket (ham id/UUID asla, ? asla)', () => {
  assert.strictEqual(gmHayvanEtiketVeya('193a0625-4d3f-44ae-b9d6-73ba7fbeeee6', null, [], {}), 'Hayvan');
  assert.strictEqual(gmHayvanEtiketVeya('193a0625-4d3f-44ae-b9d6-73ba7fbeeee6', 'Anne', [], {}), 'Anne');
  assert.strictEqual(gmHayvanEtiketVeya(null, 'Yavru', [], {}), 'Yavru');
  assert.strictEqual(gmHayvanEtiketVeya(undefined, undefined, [], {}), 'Hayvan');
});

// ── D3: notlara gömülü makine referansı (PW görünür-UUID bulgusu: stok alt
// satırı "−10 ml · Tedavi · drug_admin:<uuid>") ──────────────────────────
test('gmNotlarGorunur: drug_admin:<uuid> tokenı atılır, okunur metin kalır', () => {
  assert.strictEqual(gmNotlarGorunur('Tedavi · drug_admin:3bcbad16-6463-40c4-ab00-a6a0d0863aff'), 'Tedavi');
  assert.strictEqual(gmNotlarGorunur('Tohumlama · stok_hareket:752eb547-8b8a-431f-8054-37f0550ee46b ·Elle'), 'Tohumlama · Elle');
});

test('gmNotlarGorunur: temiz metin ve boş girdi aynen', () => {
  assert.strictEqual(gmNotlarGorunur('sabah uygulandı'), 'sabah uygulandı');
  assert.strictEqual(gmNotlarGorunur(''), '');
  assert.strictEqual(gmNotlarGorunur(null), '');
  assert.strictEqual(gmNotlarGorunur(undefined), '');
});

// ── D4: zincir adım dili ────────────────────────────────────────────────
test('dgZincirAdimEtiketi: GUNCELLE/SIL/EKLE → Güncellendi/Silindi/Eklendi (S3-03)', () => {
  assert.strictEqual(dgZincirAdimEtiketi({ yapilacak: 'GUNCELLE' }), 'Güncellendi');
  assert.strictEqual(dgZincirAdimEtiketi({ yapilacak: 'SIL' }), 'Silindi');
  assert.strictEqual(dgZincirAdimEtiketi({ yapilacak: 'EKLE' }), 'Eklendi');
});

test('dgZincirAdimEtiketi: ham kod yoksa islem yedeği; uydurma yok', () => {
  assert.strictEqual(dgZincirAdimEtiketi({ islem: 'U' }), etiket.sandbox.islemEtiketi('U'));
  assert.strictEqual(dgZincirAdimEtiketi({}), '');
  assert.strictEqual(dgZincirAdimEtiketi(null), '');
});

test('dgZincirAdimEtiketi: serbest metin yapilacak aynen kalır (islem-detay yolu)', () => {
  assert.strictEqual(dgZincirAdimEtiketi({ islem: 'U', yapilacak: 'Kayıt geri alınacak' }), 'Kayıt geri alınacak');
  assert.strictEqual(dgZincirAdimEtiketi({ islem: 'D', yapilacak: 'Kayıt silinecek' }), 'Kayıt silinecek');
});

test('dgZincirAlanOzeti: U adımında ilk anlamlı 1-2 alan "Etiket: eski → yeni"', () => {
  const p = {
    islem: 'U', tablo: 'paddocks',
    alanlar: ['ad', 'kapasite', 'notlar'],
    eski: { ad: 'A Padok', kapasite: 10, notlar: '' },
    yeni: { ad: 'B Padok', kapasite: 12, notlar: 'yeni' },
  };
  const ozet = dgZincirAlanOzeti(p);
  const parcalar = ozet.split(' · ');
  assert.ok(parcalar.length <= 2, 'en çok 2 alan: ' + ozet);
  assert.ok(/: A Padok → B Padok/.test(ozet), 'eski → yeni biçimi: ' + ozet);
  assert.ok(!/\bid\b/.test(ozet), 'pk özeti görünmez');
});

test('dgZincirAlanOzeti: ham UUID/çözülemeyen referans değerli alan özete GİRMEZ (review I1)', () => {
  const p = {
    islem: 'U', tablo: 'gorev_log',
    alanlar: ['hayvan_id', 'gorev_tipi'],
    eski: { hayvan_id: '3bcbad16-6463-40c4-ab00-a6a0d0863aff', gorev_tipi: 'TEDAVI GUN' },
    yeni: { hayvan_id: '752eb547-8b8a-431f-8054-37f0550ee46b', gorev_tipi: 'MANUEL' },
  };
  const ozet = dgZincirAlanOzeti(p);
  assert.ok(!HAM_UUID.test(ozet), 'uuid sızıntısı: ' + ozet);
  assert.ok(/Görev tipi/.test(ozet), 'metin-değerli alan özette kalır: ' + ozet);
});

test('dgZincirAlanOzeti: yalnız U adımlarında; alanlar yoksa boş', () => {
  assert.strictEqual(dgZincirAlanOzeti({ islem: 'I', yeni: { ad: 'x' } }), '');
  assert.strictEqual(dgZincirAlanOzeti({ islem: 'U' }), '');
  assert.strictEqual(dgZincirAlanOzeti(null), '');
});
