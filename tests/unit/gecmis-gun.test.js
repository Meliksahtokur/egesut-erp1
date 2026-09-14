// tests/unit/gecmis-gun.test.js
// js/gecmis.js — "Tarihe git" Faz 1 (TG1) tek-gün görünümü birim testleri.
//
// Kilitlenen sözleşmeler (zarf TG1-W2 md.1-4; W2 raporu §D.c):
//   1. olayGunu(sourceKey,row) — SAF olay-günü kuralı: date kolonları değeriyle,
//      timestamptz kolonları TR (Europe/Istanbul) günüyle; _GM_TZ_ESNEK
//      disiplini (Z/offset dönüşür, timezone'suz yazımı korur).
//   2. Defter dateKey/eventAt davranışı DEĞİŞMEZ (ayrı test dosyası +
//      buradaki dokunulmazlık testleri).
//   3. Tek-gün görünümü kendi politika setiyle 5 yeni kaynağı da kapsar;
//      DEDUP öncelik tablosu: vaccination_log>islem.ASI_KAYDI,
//      kizginlik_log>islem.KIZGINLIK_KAYDI, hayvanlar.suttten>islem.SUTEN_KESME,
//      tohumlama>islem.TOHUMLAMA(ref), cases>islem.VAKA_ACILDI,
//      kaynak>stok_hareket(referans_id bağlantılı).
//   4. todayKey sözleşmesi: DÜN todayKey'ten türetilir (gerçek saatten değil).
//
// RED-BEFORE: bu dosya impl'den ÖNCE yazıldı — olayGunu /
// _gmGunEntriesFromSources sandbox'ta yokken tüm §A/§B testleri kırmızıdır
// (kanıt: teslim raporu red-before koşum çıktısı).

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { sandbox } = loadBrowserModule('js/gecmis.js');

// ── §A: olayGunu saf kuralı ─────────────────────────────────────────

test('olayGunu: date kolonları değerin kendisi (TZ dönüşümü YOK)', () => {
  const { olayGunu } = sandbox;
  assert.strictEqual(olayGunu('dogum', { tarih: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('tohumlama', { tarih: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('vaccination_log', { vaccination_date: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('kizginlik_log', { tarih: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('uygulama_log', { tarih: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('cases', { start_date: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('hayvanlar', { cikis_tarihi: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('hayvanlar_sutten', { suttten_kesme_tarihi: '2025-11-17' }), '2025-11-17');
  assert.strictEqual(olayGunu('protokol_instance', { baslangic: '2025-11-17' }), '2025-11-17');
});

test('olayGunu: timestamptz kolonları TR (Europe/Istanbul) gününe çevirir', () => {
  const { olayGunu } = sandbox;
  // UTC 21:30 = İstanbul 00:30 (ertesi takvim günü) — defter dateKey ile aynı kural
  assert.strictEqual(olayGunu('islem_log', { tarih: '2026-09-08T21:30:00Z' }), '2026-09-09');
  assert.strictEqual(olayGunu('gorev_log', { tamamlanma_tarihi: '2026-09-08T21:30:00Z' }), '2026-09-09');
  assert.strictEqual(olayGunu('cases_kapanis', { closed_at: '2026-09-08T21:30:00Z' }), '2026-09-09');
  assert.strictEqual(olayGunu('stok_hareket', { tarih: '2026-09-08T21:30:00Z' }), '2026-09-09');
  assert.strictEqual(olayGunu('protokol_instance_kapanis', { kapandi_at: '2026-09-08T21:30:00Z' }), '2026-09-09');
  // explicit offset = Z ile aynı; İstanbul offset'i zaten yerel
  assert.strictEqual(olayGunu('islem_log', { tarih: '2026-09-08T21:30:00+00:00' }), '2026-09-09');
  assert.strictEqual(olayGunu('islem_log', { tarih: '2026-09-08T21:30:00+03:00' }), '2026-09-08');
  // gün içi UTC aynı takvim gününde kalır
  assert.strictEqual(olayGunu('islem_log', { tarih: '2026-09-08T09:00:00Z' }), '2026-09-08');
});

test('olayGunu: timezone\'suz yerel yazım aynen korunur (_GM_TZ_ESNEK disiplini)', () => {
  const { olayGunu } = sandbox;
  assert.strictEqual(olayGunu('islem_log', { tarih: '2026-09-08T23:59:00' }), '2026-09-08');
  assert.strictEqual(olayGunu('tohumlama', { tarih: '2026-08-30T00:00:00' }), '2026-08-30');
});

test('olayGunu: tohumlama_sonuc sonuc türüne göre sonuç kolonunu seçer', () => {
  const { olayGunu } = sandbox;
  assert.strictEqual(olayGunu('tohumlama_sonuc', { sonuc: 'Gebe', kontrol_tarihi: '2025-12-01', dogum_tarihi: null, abort_tarihi: null }), '2025-12-01');
  assert.strictEqual(olayGunu('tohumlama_sonuc', { sonuc: 'Boş', kontrol_tarihi: '2025-12-01' }), '2025-12-01');
  assert.strictEqual(olayGunu('tohumlama_sonuc', { sonuc: 'Abort', kontrol_tarihi: '2025-12-01', abort_tarihi: '2025-11-25' }), '2025-11-25');
  assert.strictEqual(olayGunu('tohumlama_sonuc', { sonuc: 'Doğum Yaptı', kontrol_tarihi: '2025-12-01', dogum_tarihi: '2026-02-10' }), '2026-02-10');
  // sonuç tarihi yoksa olay günü yoktur (entry üretmez)
  assert.strictEqual(olayGunu('tohumlama_sonuc', { sonuc: 'Gebe', kontrol_tarihi: null }), '');
});

test('olayGunu: boş satır / boş kolon → boş string', () => {
  const { olayGunu } = sandbox;
  assert.strictEqual(olayGunu('dogum', null), '');
  assert.strictEqual(olayGunu('dogum', {}), '');
  assert.strictEqual(olayGunu('bilinmeyen_kaynak', { tarih: '2025-11-17' }), '');
});

test('olayGunu ≠ defter dateKey: geri tarihli tohumlama OLAY gününde (rapor §D.c kabul ölçütü 2)', () => {
  const { olayGunu, _gmEntriesFromSources } = sandbox;
  // canlıda 252/282 satır: created_at (kayıt anı) ≠ tarih (olay günü)
  const row = { id: 'T1', sonuc: 'Gebe', tarih: '2025-11-10', created_at: '2025-11-17T08:00:00Z' };
  assert.strictEqual(olayGunu('tohumlama', row), '2025-11-10');
  // defterin dateKey'i kayıt anını esas alır — İKİSİ FARKLI, ikisi de doğru
  const defter = _gmEntriesFromSources({ tohumlama: [row] });
  assert.strictEqual(defter[0].dateKey, '2025-11-17');
});

// ── §B: _gmGunEntriesFromSources — tek-gün görünümü hattı ───────────

test('gün hattı: 5 yeni kaynak entry üretir, kategori/sourceKey doğru', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const sources = {
    vaccination_log: [{ id: 'V1', animal_id: 'A1', vaccine_id: 'VC1', vaccination_date: '2025-11-17' }],
    kizginlik_log: [{ id: 'K1', hayvan_id: 'A1', tarih: '2025-11-17', belirti: 'akış' }],
    stok_hareket: [{ id: 'S1', stok_id: 'ST1', tur: 'Tedavi', miktar: 5, tarih: '2025-11-17T08:00:00Z' }],
    hayvanlar: [
      { id: 'A2', kupe_no: 'TR-2', cikis_tarihi: '2025-11-17', cikis_tipi: 'Satıldı' },
      { id: 'A3', kupe_no: 'TR-3', suttten_kesme_tarihi: '2025-11-17' },
    ],
    protokol_instance: [{ id: 'P1', hayvan_id: 'A1', baslangic: '2025-11-17' }],
  };
  const out = _gmGunEntriesFromSources(sources);
  // NOT: vm sandbox dizileri farklı Array.prototype'a sahip olduğundan
  // deepStrictEqual yerine birleştirilmiş string karşılaştırması (mevcut
  // gecmis-pipeline.test.js:135 konvansiyonu).
  const kategoriler = out.map(e => e.sourceKey + '>' + e.category).sort().join(',');
  assert.strictEqual(kategoriler, [
    'hayvanlar>cikis', 'hayvanlar_sutten>sutten', 'kizginlik_log>kizginlik',
    'protokol_instance>protokol', 'stok_hareket>stok', 'vaccination_log>asi',
  ].join(','));
  // her entry'de olayGunu dolu ve filtrelenebilir
  assert.ok(out.every(e => e.olayGunu === '2025-11-17'), 'hepsi seçili gün anahtarını taşır');
});

test('gün hattı: mevcut kaynaklar da olay-günü anahtarıyla gelir (olayGunu alanı)', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    dogum: [{ id: 'D1', anne_id: 'A1', tarih: '2025-11-17' }],
    gorev_log: [{ id: 'G1', hayvan_id: 'A1', tamamlandi: true, tamamlanma_tarihi: '2025-11-17T09:00:00Z' }],
    islem_log: [{ id: 'I1', tip: 'HAYVAN_EKLENDI', ana_hayvan_id: 'A1', tarih: '2025-11-17T10:00:00Z' }],
    uygulama_log: [{ id: 'U1', hayvan_id: 'A1', tarih: '2025-11-17' }],
  });
  assert.strictEqual(out.length, 4);
  assert.ok(out.every(e => e.olayGunu === '2025-11-17'));
  assert.ok(out.every(e => typeof e.sourceKey === 'string' && e.sourceKey), 'sourceKey her entryde dolu');
});

test('gün hattı: cases — açık vakanın açılış günü görünür; kapalı vaka açılış+kapanış 2 kalem', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    cases: [
      { id: 'C1', animal_id: 'A1', status: 'active', start_date: '2025-11-17' },
      { id: 'C2', animal_id: 'A2', status: 'closed', start_date: '2025-11-10', closed_at: '2025-11-17T12:00:00Z' },
    ],
  });
  const c1 = out.filter(e => e.data.id === 'C1');
  assert.strictEqual(c1.length, 1, 'aktif vaka yalnız açılış kalemi');
  const c2 = out.filter(e => e.data.id === 'C2');
  assert.strictEqual(c2.length, 2, 'kapalı vaka: açılış + kapanış');
  assert.strictEqual(c2.map(e => e.olayGunu).sort().join(','), '2025-11-10,2025-11-17');
  assert.strictEqual(c2.find(e => e.sourceKey === 'cases_kapanis').olayGunu, '2025-11-17', 'kapanış TR-günü');
});

test('gün hattı: tohumlama — Bekliyor dahil görünür; terminal sonuç kendi gününde ayrı kalem', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    tohumlama: [
      { id: 'T1', hayvan_id: 'A1', sonuc: 'Bekliyor', tarih: '2025-11-17' },
      { id: 'T2', hayvan_id: 'A2', sonuc: 'Gebe', tarih: '2025-11-01', kontrol_tarihi: '2025-11-17' },
    ],
  });
  const t1 = out.filter(e => e.data.id === 'T1');
  assert.strictEqual(t1.length, 1, 'Bekliyor tohumlama olay gününde görünür (defterde görünmezdi)');
  const t2 = out.filter(e => e.data.id === 'T2');
  assert.strictEqual(t2.length, 2, 'işlem + sonuç iki kalem');
  assert.strictEqual(t2.find(e => e.sourceKey === 'tohumlama').olayGunu, '2025-11-01');
  assert.strictEqual(t2.find(e => e.sourceKey === 'tohumlama_sonuc').olayGunu, '2025-11-17');
});

test('gün hattı: gorev pending girmez; iptal/geri_alindi girmez', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    gorev_log: [
      { id: 'PEND', tamamlandi: false, hedef_tarih: '2025-11-17' },
      { id: 'IPTAL', tamamlandi: true, tamamlanma_tarihi: '2025-11-17T09:00:00Z', iptal: true },
      { id: 'OK', tamamlandi: true, tamamlanma_tarihi: '2025-11-17T10:00:00Z' },
    ],
    islem_log: [{ id: 'I1', tip: 'TOPLU_ILAC', ana_hayvan_id: 'A1', tarih: '2025-11-17T11:00:00Z', durum: 'geri_alindi' }],
  });
  assert.strictEqual(out.map(e => e.data.id).join(','), 'OK');
});

test('gün hattı DEDUP: aşı — vaccination_log kazanır, aynı gün+hayvan islem ASI_KAYDI baskılanır', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const sources = {
    vaccination_log: [{ id: 'V1', animal_id: 'A1', vaccination_date: '2025-11-17' }],
    islem_log: [
      { id: 'I1', tip: 'ASI_KAYDI', ana_hayvan_id: 'A1', tarih: '2025-11-17T08:00:00Z' }, // aynı hayvan+gün → baskılanır
      { id: 'I2', tip: 'ASI_KAYDI', ana_hayvan_id: 'A2', tarih: '2025-11-17T08:30:00Z' }, // farklı hayvan → kalır
      { id: 'I3', tip: 'ASI_KAYDI', ana_hayvan_id: 'A1', tarih: '2025-11-18T08:00:00Z' }, // farklı gün → kalır
    ],
  };
  const out = _gmGunEntriesFromSources(sources);
  const asi = out.filter(e => e.category === 'asi' || (e.sourceKey === 'islem_log' && e.data.tip === 'ASI_KAYDI'));
  assert.strictEqual(asi.length, 3, 'V1 + I2 + I3 (yalnız I1 baskılandı)');
  assert.ok(asi.some(e => e.sourceKey === 'vaccination_log'), 'vaccination_log kalemi kalır');
  assert.ok(!asi.some(e => e.data.id === 'I1'), 'aynı hayvan+gün islem aşı kaydı baskılanır');
});

test('gün hattı DEDUP: kızgınlık — kizginlik_log kazanır; sütten kesme — hayvanlar kazanır', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    kizginlik_log: [{ id: 'K1', hayvan_id: 'A1', tarih: '2025-11-17' }],
    hayvanlar: [{ id: 'A1', suttten_kesme_tarihi: '2025-11-17' }],
    islem_log: [
      { id: 'I1', tip: 'KIZGINLIK_KAYDI', ana_hayvan_id: 'A1', tarih: '2025-11-17T09:00:00Z' },   // baskılanır
      { id: 'I2', tip: 'SUTEN_KESME', ana_hayvan_id: 'A1', tarih: '2025-11-17T10:00:00Z' },      // baskılanır
      { id: 'I3', tip: 'SUTEN_KESME', ana_hayvan_id: 'A1', tarih: '2025-12-01T10:00:00Z' },      // farklı gün → kalır
    ],
  });
  assert.ok(!out.some(e => e.data.id === 'I1'), 'KIZGINLIK_KAYDI aynı gün baskılanır');
  assert.ok(!out.some(e => e.data.id === 'I2'), 'SUTEN_KESME aynı gün baskılanır');
  assert.ok(out.some(e => e.data.id === 'I3'), 'farklı gün SUTEN_KESME kalır');
});

test('gün hattı DEDUP: tohumlama ref_id ile islem TOHUMLAMA baskılar; cases açılışı VAKA_ACILDI baskılar', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    tohumlama: [{ id: 'T1', hayvan_id: 'A1', sonuc: 'Gebe', tarih: '2025-11-17', kontrol_tarihi: '2025-12-01' }],
    cases: [{ id: 'C1', animal_id: 'A1', status: 'active', start_date: '2025-11-17' }],
    islem_log: [
      { id: 'I1', tip: 'TOHUMLAMA', ana_hayvan_id: 'A1', ref_id: 'T1', tarih: '2025-11-17T07:00:00Z' },   // ref + aynı gün → baskılanır
      { id: 'I2', tip: 'VAKA_ACILDI', ana_hayvan_id: 'A1', ref_id: 'C1', tarih: '2025-11-17T07:30:00Z' }, // ref + aynı gün → baskılanır
    ],
  });
  assert.ok(!out.some(e => e.data.id === 'I1'), 'ref bağlantılı TOHUMLAMA islem kaydı baskılanır');
  assert.ok(!out.some(e => e.data.id === 'I2'), 'ref bağlantılı VAKA_ACILDI baskılanır');
  assert.ok(out.some(e => e.sourceKey === 'tohumlama'), 'tohumlama kalemi kalır');
  assert.ok(out.some(e => e.sourceKey === 'cases'), 'vaka açılış kalemi kalır');
});

test('gün hattı DEDUP: referans_id bağlantılı stok düşüşü baskılanır; bağlantısız genel stok hareketi kalır (§E.3)', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    tohumlama: [{ id: 'T1', hayvan_id: 'A1', sonuc: 'Gebe', tarih: '2025-11-17' }],
    stok_hareket: [
      { id: 'S1', stok_id: 'ST1', tur: 'Tohumlama', miktar: 1, tarih: '2025-11-17T08:00:00Z', referans_id: 'T1' }, // baskılanır
      { id: 'S2', stok_id: 'ST2', tur: 'Tedavi', miktar: 5, tarih: '2025-11-17T09:00:00Z' },                        // bağlantısız → kalır
      { id: 'S3', stok_id: 'ST1', tur: 'Tohumlama', miktar: 1, tarih: '2025-12-01T08:00:00Z', referans_id: 'T1' }, // farklı gün → kalır
    ],
  });
  const stok = out.filter(e => e.sourceKey === 'stok_hareket');
  assert.strictEqual(stok.map(e => e.data.id).sort().join(','), 'S2,S3', 'yalnız aynı gün ref bağlantılı olan baskılanır');
});

test('gün hattı: entry sıralaması eventAt desc', () => {
  const { _gmGunEntriesFromSources } = sandbox;
  const out = _gmGunEntriesFromSources({
    islem_log: [
      { id: 'I2', tip: 'HAYVAN_EKLENDI', ana_hayvan_id: 'A1', tarih: '2025-11-17T12:00:00Z' },
      { id: 'I1', tip: 'HAYVAN_EKLENDI', ana_hayvan_id: 'A2', tarih: '2025-11-17T08:00:00Z' },
    ],
    dogum: [{ id: 'D1', anne_id: 'A1', tarih: '2025-11-17' }],
  });
  assert.strictEqual(out.map(e => e.data.id).join(','), 'I2,I1,D1');
});

// ── §C: defter hattı dokunulmazlık ─────────────────────────────────

test('defter hattı: entry\'ler sourceKey taşır (tip-geri-çözüm YOK — açık taşıma)', () => {
  const { _gmEntriesFromSources } = sandbox;
  const out = _gmEntriesFromSources({
    cases: [{ id: 'C1', animal_id: 'A1', status: 'closed', closed_at: '2026-09-05T15:30:00Z' }],
    islem_log: [{ id: 'I1', tip: 'ASI_KAYDI', ana_hayvan_id: 'A1', tarih: '2026-09-09' }],
  });
  const h = out.find(e => e.type === 'hastalik');
  assert.strictEqual(h.sourceKey, 'cases', 'type hastalik ama sourceKey cases');
  const i = out.find(e => e.type === 'islem');
  assert.strictEqual(i.sourceKey, 'islem_log', 'type islem ama sourceKey islem_log');
});

test('defter hattı: yeni kaynaklar defter çıktısına SIZMAZ (dateKey/eventAt davranışı değişmez)', () => {
  const { _gmEntriesFromSources } = sandbox;
  const sources = {
    dogum: [{ id: 'D1', anne_id: 'A1', tarih: '2025-11-17' }],
    vaccination_log: [{ id: 'V1', animal_id: 'A1', vaccination_date: '2025-11-17' }],
    kizginlik_log: [{ id: 'K1', hayvan_id: 'A1', tarih: '2025-11-17' }],
    stok_hareket: [{ id: 'S1', stok_id: 'ST1', tur: 'Tedavi', miktar: 1, tarih: '2025-11-17T08:00:00Z' }],
    hayvanlar: [{ id: 'A1', cikis_tarihi: '2025-11-17', cikis_tipi: 'Satıldı', suttten_kesme_tarihi: '2025-11-17' }],
    protokol_instance: [{ id: 'P1', hayvan_id: 'A1', baslangic: '2025-11-17' }],
  };
  const out = _gmEntriesFromSources(sources);
  assert.strictEqual(out.map(e => e.type).join(','), 'dogum', 'defter yalnız mevcut 6 kaynağı işler');
});

// ── §D: todayKey sözleşmesi (DÜN time-bomb onarımı) ────────────────

test('_gmGroupLabel: DÜN todayKey\'ten türetilir — enjekte edilen bugün gerçek saatten bağımsız', () => {
  const { _gmGroupLabel } = sandbox;
  // Bugün ister gerçek 2026-09-14 olsun ister olmasın: todayKey=2026-09-09
  // verilince DÜN=2026-09-08'dir (gerçek saat karışmaz).
  assert.strictEqual(_gmGroupLabel('2026-09-08', '2026-09-09'), 'DÜN');
  assert.strictEqual(_gmGroupLabel('2026-09-09', '2026-09-09'), 'BUGÜN');
  // ay/yıl devri: todayKey ay başıysa DÜN önceki ayın son günü
  assert.strictEqual(_gmGroupLabel('2026-09-30', '2026-10-01'), 'DÜN');
  assert.strictEqual(_gmGroupLabel('2025-12-31', '2026-01-01'), 'DÜN');
  // daha eski gün tarih etiketine düşer
  assert.match(_gmGroupLabel('2026-09-07', '2026-09-09'), /7 Eylül Pazartesi/);
});
