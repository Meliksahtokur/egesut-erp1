// tests/unit/sut-buzagi-band.test.js
// _dashSutBuzagiBandi — dashboard 🍼 Süt İçen Buzağılar bandının saf birim testleri.
// Bugün sabit ('2026-09-02'); tüm tarih hesapları today parametresi üzerinden deterministik.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');
const { fmtTarih } = require('../../js/utils/helpers.js');

const { sandbox } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror, fmtTarih },
  expose: [],
});
const { _dashSutBuzagiBandi } = sandbox;

const TODAY = '2026-09-02';
const VAX = [
  { id: 'v-bvd', name: 'BVD Aşısı', is_mandatory: true },
  { id: 'v-sarbon', name: 'Şarbon Aşısı', is_mandatory: true },
  { id: 'v-cog', name: 'Coglavax', is_mandatory: true },
  { id: 'v-feedlot', name: 'Vac-Sules Feedlot', is_mandatory: true },
];
// Buzağı yaş takvimi: BVD 60+120, Şarbon 180. Düve hedefli satır filtrelenmeli.
const SCH = [
  { vaccine_id: 'v-bvd', target_type: 'buzağı', timing_type: 'yas', timing_days: 60 },
  { vaccine_id: 'v-bvd', target_type: 'buzağı', timing_type: 'yas', timing_days: 120 },
  { vaccine_id: 'v-sarbon', target_type: 'buzağı', timing_type: 'yas', timing_days: 180 },
  { vaccine_id: 'v-bvd', target_type: 'düve', timing_type: 'yas', timing_days: 365 },
];

const hizli = (over = {}) => _dashSutBuzagiBandi(
  over.animals ?? [], over.vaccines ?? VAX, over.vaxLogs ?? [], over.tasks ?? [],
  over.schRows ?? SCH, over.esik ?? 60, TODAY
);
const satirlar = (html) => html.split('<div class="arow"').slice(1);

test('boş kümede bant yok', () => {
  assert.equal(hizli(), '');
});

test('filtre: yalnız süt içen buzağılar; kesilmiş/kayıtsız yaş hariç; sıralama yaşa göre', () => {
  const animals = [
    { id: 'c1', kupe_no: 'K60', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-06-27' },   // 67g
    { id: 'c2', kupe_no: 'K48', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-07-16' },   // 48g
    { id: 'c3', kupe_no: 'KESILMIS', grup: 'Sütten Kesilmiş Buzağı', dogum_tarihi: '2026-05-26' },
    { id: 'c4', kupe_no: 'KESIMLI', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-08-20', suttten_kesme_tarihi: '2026-09-01' },
    { id: 'c6', kupe_no: 'YASSIZ', grup: 'Süt İçen Buzağı', dogum_tarihi: null },
    { id: 'c5', kupe_no: 'DUVE23', grup: 'Düve (Küçük)', dogum_tarihi: '2026-08-10' },   // 23g — yaş kuralı
  ];
  const html = hizli({ animals });
  assert.ok(html.includes('Süt İçen Buzağılar (3)'), 'bant başlığı 3 buzağı saymalı');
  const rows = satirlar(html);
  assert.equal(rows.length, 3);
  assert.ok(rows[0].includes('K60'), 'en yaşlı üstte');
  assert.ok(rows[1].includes('K48'));
  assert.ok(rows[2].includes('DUVE23'), 'yaş≤180 kuralı gruptan bağımsız dahil eder');
  assert.ok(!html.includes('KESILMIS') && !html.includes('KESIMLI') && !html.includes('YASSIZ'));
});

test('takvim dozları: gecikmiş ⚠️, yaklaşan ⏰, uzak doz chip yok', () => {
  const animals = [
    { id: 'c1', kupe_no: 'K60', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-06-27' }, // BVD60 → 7g gecikme
    { id: 'c2', kupe_no: 'K48', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-07-16' }, // BVD60 → 12g kaldı
    { id: 'c5', kupe_no: 'DUVE23', grup: 'Düve (Küçük)', dogum_tarihi: '2026-08-10' }, // BVD60 → 37g: yok
  ];
  const html = hizli({ animals });
  const rows = satirlar(html);
  assert.ok(rows[0].includes('⚠️ BVD 7g gecikti'));
  assert.ok(!rows[0].includes('120'), 'karşılanmayan ilk doz gösterilir, uzak 2. doz gürültü yapmaz');
  assert.ok(!rows[0].includes('Şarbon'), '180g uzak doz chip üretmez');
  assert.ok(rows[1].includes('⏰ BVD 12g'));
  assert.ok(!rows[2].includes('BVD'), '37 gün sonra olan doz listeyi kirletmez');
});

test('kesim eşiği: 60. günde 🍼 kırmızı chip + bant kırmızı; eşik aşılırsa chip yok', () => {
  const animals = [{ id: 'c1', kupe_no: 'K60', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-06-27' }];
  const html = hizli({ animals, schRows: [] });            // aşı gürültüsü olmadan yalnız kesim
  assert.ok(html.includes('kesim vakti'));
  assert.ok(html.includes('aband-hdr red'));
  const html2 = hizli({ animals, schRows: [], esik: 68 });  // 67 < 68 → chip yok, bant amber
  assert.ok(!html2.includes('kesim vakti'));
  assert.ok(html2.includes('aband-hdr amber'));
});

test('tamamlanan dozlarda ✓; tüm doz bitince yıllık rapel next_due_date üstünden takip edilir', () => {
  const animals = [{ id: 'c8', kupe_no: 'K181', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-03-05' }];
  const vaxLogs = [
    { animal_id: 'c8', vaccine_id: 'v-bvd', vaccination_date: '2026-05-10', next_due_date: null },
    { animal_id: 'c8', vaccine_id: 'v-bvd', vaccination_date: '2026-07-10', next_due_date: null },
    // Şarbon 180g → 2026-09-01, henüz yapılmadı → 1g gecikti
  ];
  const html = hizli({ animals, vaxLogs });
  const row = satirlar(html)[0];
  assert.ok(row.includes('✓ BVD'), 'tüm dozları tamamlanan aşı ✓ ile görünür');
  assert.ok(row.includes('⚠️ Şarbon 1g gecikti'));
});

test('rapel: yıllık next_due_date yaklaşırken ⏰, geçerken ⚠️', () => {
  const animals = [{ id: 'c2', kupe_no: 'K48', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-07-16' }];
  const vaxLogs = [
    { animal_id: 'c2', vaccine_id: 'v-sarbon', vaccination_date: '2026-07-20', next_due_date: '2026-09-04' },
  ];
  const html = hizli({ animals, vaxLogs });
  assert.ok(satirlar(html)[0].includes('⏰ Şarbon rapel 2g'));

  const html2 = hizli({ animals, vaxLogs: [{ ...vaxLogs[0], next_due_date: '2026-08-30' }] });
  assert.ok(satirlar(html2)[0].includes('⚠️ Şarbon rapel 3g gecikti'));
});

test('ertelenen (ertelendi) kayıt yok sayılır — gecikmiş sanılmaz', () => {
  const animals = [{ id: 'c1', kupe_no: 'K60', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-06-27' }];
  const vaxLogs = [
    { animal_id: 'c1', vaccine_id: 'v-sarbon', vaccination_date: '2026-01-01', next_due_date: '2026-08-30', ertelendi: true },
  ];
  const html = hizli({ animals, vaxLogs });
  assert.ok(!satirlar(html)[0].includes('Şarbon'));
});

test('zorunlu aşı takvimde yoksa yalnız kayıt/görev varken görünür; açık ASI_PLANLI 📅 planlı', () => {
  const animals = [{ id: 'c2', kupe_no: 'K48', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-07-16' }];
  const tasks = [{
    id: 't1', gorev_tipi: 'ASI_PLANLI', hayvan_id: 'c2', stok_id: null,
    aciklama: '💉 Vac-Sules Feedlot 2. doz', tamamlandi: false, iptal: false,
  }];
  const html = hizli({ animals, tasks });
  assert.ok(satirlar(html)[0].includes('📅 Vac-Sules Feedlot'));
  assert.ok(!html.includes('Coglavax'), 'kaydı ve görevi olmayan zorunlu aşı listeyi kirletmez');
});

test('bant önceliği: gecikme yalnız ⏰/📅 iken amber', () => {
  const animals = [{ id: 'c2', kupe_no: 'K48', grup: 'Süt İçen Buzağı', dogum_tarihi: '2026-07-16' }];
  const html = hizli({ animals, schRows: [] }); // 48 gün: hiçbir uyarı yok
  assert.ok(html.includes('aband-hdr amber'));
  assert.ok(!html.includes('aband-hdr red'));
});
