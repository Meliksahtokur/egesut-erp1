// tests/unit/gecmis-pipeline.test.js
// js/gecmis.js — Geçmiş sekmesi ortak veri hattı birim testleri.
// Spesifikasyon: .claude/plans/2026-09-09-gecmis-sekmesi-tasarim.md (rev 2)
// Plan: .claude/plans/2026-09-09-gecmis-sekmesi-impl.md (Görev 1-4)
//
// Modül saf (DOM yazımı yok) — loadBrowserModule ile yüklenir; üst-seviye
// `function` bildirimleri sandbox property'si olur.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { sandbox } = loadBrowserModule('js/gecmis.js');

// ── Görev 1: _gmPolicyRow + _gmEntriesFromSources ────────────────

test('gorev_log politika: yalnızca tamamlandi===true VE tamamlanma_tarihi dolu kabul', () => {
  const { _gmPolicyRow } = sandbox;
  assert.strictEqual(_gmPolicyRow('gorev_log', { tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z' }), true);
  // tarihsiz tamamlanma reddedilir
  assert.strictEqual(_gmPolicyRow('gorev_log', { tamamlandi: true }), false);
  // hedef_tarih fallback YOK — bekleyen görev hiç girmaz (pending sızıntısı kuralı)
  assert.strictEqual(_gmPolicyRow('gorev_log', { tamamlandi: false, hedef_tarih: '2099-01-01' }), false);
  // geri alınmış kayıt geçmez (D11)
  assert.strictEqual(_gmPolicyRow('gorev_log', { tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z', durum: 'geri_alindi' }), false);
  // iptal edilmiş görev "yapılmış iş" değildir (impl-review bulgu 2; canlı şema: gorev_log.iptal)
  assert.strictEqual(_gmPolicyRow('gorev_log', { tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z', iptal: true }), false);
  assert.strictEqual(_gmPolicyRow('gorev_log', { tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z', iptal: false }), true);
});

test('tohumlama politika: sonuc allow-list (Gebe/Boş/Doğum Yaptı/Abort), Bekliyor reddedilir', () => {
  const { _gmPolicyRow } = sandbox;
  assert.strictEqual(_gmPolicyRow('tohumlama', { sonuc: 'Gebe' }), true);
  assert.strictEqual(_gmPolicyRow('tohumlama', { sonuc: 'Boş' }), true);
  assert.strictEqual(_gmPolicyRow('tohumlama', { sonuc: 'Doğum Yaptı' }), true);
  assert.strictEqual(_gmPolicyRow('tohumlama', { sonuc: 'Abort' }), true);
  assert.strictEqual(_gmPolicyRow('tohumlama', { sonuc: 'Bekliyor' }), false);
  assert.strictEqual(_gmPolicyRow('tohumlama', { sonuc: null }), false);
  // geri alınmış tohumlama geçmez (D11)
  assert.strictEqual(_gmPolicyRow('tohumlama', { sonuc: 'Gebe', durum: 'geri_alindi' }), false);
});

test('cases politika: status=closed VE closed_at dolu şart — closed_at boşsa veri kalitesi sinyali olarak reddedilir', () => {
  const { _gmPolicyRow } = sandbox;
  assert.strictEqual(_gmPolicyRow('cases', { status: 'closed', closed_at: '2026-09-01T12:00:00Z' }), true);
  assert.strictEqual(_gmPolicyRow('cases', { status: 'closed', closed_at: null }), false);
  assert.strictEqual(_gmPolicyRow('cases', { status: 'active', closed_at: '2026-09-01T12:00:00Z' }), false);
});

test('islem_log politika: 5 tip kabul, geri_alindi reddedilir, diğer tipler reddedilir', () => {
  const { _gmPolicyRow } = sandbox;
  for (const tip of ['HAYVAN_EKLENDI', 'ABORT_KAYDI', 'KIZGINLIK_KAYDI', 'ASI_KAYDI', 'TOPLU_ILAC']) {
    assert.strictEqual(_gmPolicyRow('islem_log', { tip }), true, `${tip} kabul edilmeli`);
    assert.strictEqual(_gmPolicyRow('islem_log', { tip, durum: 'geri_alindi' }), false, `${tip} geri_alindi reddedilmeli`);
  }
  assert.strictEqual(_gmPolicyRow('islem_log', { tip: 'TOHUMLAMA' }), false, '5 tip dışı reddedilmeli');
  assert.strictEqual(_gmPolicyRow('islem_log', { tip: 'SATIS_KAYDI' }), false);
});

test('dogum/uygulama_log politika: hepsi kabul', () => {
  const { _gmPolicyRow } = sandbox;
  assert.strictEqual(_gmPolicyRow('dogum', { tarihi: null }), true);
  assert.strictEqual(_gmPolicyRow('uygulama_log', {}), true);
});

test('entry üretimi: eventAt öncelik sırası kaynak bazlı doğru', () => {
  const { _gmEntriesFromSources } = sandbox;
  // gorev: tamamlanma_tarihi (hedef_tarih fallback YOK)
  const gorev = _gmEntriesFromSources({ gorev_log: [{ id: 'G1', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z', hedef_tarih: '2026-09-01' }] });
  assert.strictEqual(gorev.length, 1);
  assert.strictEqual(gorev[0].eventAt, '2026-09-08T09:00:00Z');

  // tohumlama: created_at || tarih(T00:00:00)
  const toh = _gmEntriesFromSources({
    tohumlama: [
      { id: 'T1', sonuc: 'Gebe', created_at: '2026-09-01T10:00:00Z', tarih: '2026-08-30' },
      { id: 'T2', sonuc: 'Boş', tarih: '2026-08-30' },
    ],
  });
  assert.strictEqual(toh.find(e => e.data.id === 'T1').eventAt, '2026-09-01T10:00:00Z');
  assert.strictEqual(toh.find(e => e.data.id === 'T2').eventAt, '2026-08-30T00:00:00');

  // dogum/uygulama: created_at || tarih
  const dg = _gmEntriesFromSources({ dogum: [{ id: 'D1', created_at: '2026-09-02T08:00:00Z', tarih: '2026-09-01' }] });
  assert.strictEqual(dg[0].eventAt, '2026-09-02T08:00:00Z');
  const dg2 = _gmEntriesFromSources({ dogum: [{ id: 'D2', tarih: '2026-09-01' }] });
  assert.strictEqual(dg2[0].eventAt, '2026-09-01');

  // islem_log: tarih || created_at
  const isl = _gmEntriesFromSources({ islem_log: [{ id: 'I1', tip: 'ASI_KAYDI', tarih: '2026-09-03', created_at: '2026-09-03T07:00:00Z' }] });
  assert.strictEqual(isl[0].eventAt, '2026-09-03');
});

test('entry üretimi: eventAt boş kalan satır asla entry üretmez', () => {
  const { _gmEntriesFromSources } = sandbox;
  const out = _gmEntriesFromSources({
    dogum: [{ id: 'D1' }],
    uygulama_log: [{ id: 'U1' }],
    tohumlama: [{ id: 'T1', sonuc: 'Gebe' }], // sonuc uygun ama tarih yok
  });
  assert.strictEqual(out.length, 0);
});

test('entry sözleşmesi: {type, category, eventAt, dateKey, data} — dateKey eventAt string dilimidir', () => {
  const { _gmEntriesFromSources } = sandbox;
  const out = _gmEntriesFromSources({ gorev_log: [{ id: 'G1', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z' }] });
  assert.strictEqual(out.length, 1);
  const e = out[0];
  assert.strictEqual(e.type, 'gorev');
  assert.strictEqual(e.category, 'gorev');
  assert.strictEqual(e.eventAt, '2026-09-08T09:00:00Z');
  // dateKey = eventAt.slice(0,10) — kaynak ISO yazımındaki (yerel) gün korunur,
  // new Date() TZ kayması bilinçli olarak önlendi (plan Görev 1 kararı).
  assert.strictEqual(e.dateKey, '2026-09-08');
  assert.strictEqual(e.data.id, 'G1');
});

test('cases → hastalik entry tipine dönüşür, eventAt=closed_at', () => {
  const { _gmEntriesFromSources } = sandbox;
  const out = _gmEntriesFromSources({ cases: [{ id: 'C1', status: 'closed', closed_at: '2026-09-05T15:30:00Z' }] });
  assert.strictEqual(out.length, 1);
  assert.strictEqual(out[0].type, 'hastalik');
  assert.strictEqual(out[0].eventAt, '2026-09-05T15:30:00Z');
  assert.strictEqual(out[0].dateKey, '2026-09-05');
});

test('entry sıralaması: eventAt desc (yeni → eski)', () => {
  const { _gmEntriesFromSources } = sandbox;
  const out = _gmEntriesFromSources({
    gorev_log: [
      { id: 'E', tamamlandi: true, tamamlanma_tarihi: '2026-09-01T09:00:00Z' },
      { id: 'A', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z' },
      { id: 'C', tamamlandi: true, tamamlanma_tarihi: '2026-09-05T09:00:00Z' },
    ],
  });
  // NOT: vm sandbox dizileri farklı Array.prototype'a sahip olduğundan
  // deepStrictEqual yerine birleştirilmiş string karşılaştırması kullanılır.
  assert.strictEqual(out.map(e => e.data.id).join(','), 'A,C,E');
});

test('hayvan kapsamı (scope.animalId): kaynak bazında mevcut eşleşme aynen uygulanır', () => {
  const { _gmEntriesFromSources } = sandbox;
  const sources = {
    tohumlama: [{ id: 'T1', sonuc: 'Gebe', created_at: '2026-09-01T10:00:00Z', hayvan_id: 'A1' },
                { id: 'T2', sonuc: 'Boş', created_at: '2026-09-02T10:00:00Z', hayvan_id: 'A2' }],
    dogum: [{ id: 'D1', tarih: '2026-09-03', anne_id: 'A1' }, { id: 'D2', tarih: '2026-09-04', anne_id: 'A2' }],
    cases: [{ id: 'C1', status: 'closed', closed_at: '2026-09-05T15:30:00Z', animal_id: 'A1' },
            { id: 'C2', status: 'closed', closed_at: '2026-09-06T15:30:00Z', animal_id: 'A2' }],
    gorev_log: [{ id: 'G1', tamamlandi: true, tamamlanma_tarihi: '2026-09-07T09:00:00Z', hayvan_id: 'A1' },
                { id: 'G2', tamamlandi: true, tamamlanma_tarihi: '2026-09-07T10:00:00Z' }], // G2 hayvansız
    uygulama_log: [{ id: 'U1', created_at: '2026-09-08T09:00:00Z', hayvan_id: 'A1' }],
    islem_log: [{ id: 'I1', tip: 'ASI_KAYDI', tarih: '2026-09-09', ana_hayvan_id: 'A1' },
                { id: 'I2', tip: 'ASI_KAYDI', tarih: '2026-09-09', ana_hayvan_id: 'A2' }],
  };
  const out = _gmEntriesFromSources(sources, { animalId: 'A1' });
  assert.strictEqual(
    out.map(e => e.type + ':' + e.data.id).sort().join(','),
    'dogum:D1,gorev:G1,hastalik:C1,islem:I1,tohumlama:T1,uygulama:U1'
  );
  // kapsam yokken hepsi gelir (ana sekme)
  const tumu = _gmEntriesFromSources(sources);
  assert.strictEqual(tumu.length, 11);
});

// ── Görev 2: undoRef türetimi + geri al butonu ───────────────────

test('undoRef islem: yalnızca route edilen tiplerde {kind:islem,id}', () => {
  const { _gmUndoRef } = sandbox;
  for (const tip of ['TOHUMLAMA', 'TOHUMLAMA_GUNCELLENDI', 'HASTALIK_KAYDI', 'VAKA_ACILDI', 'TEDAVI_GUN_EKLENDI', 'ABORT_KAYDI']) {
    assert.strictEqual(JSON.stringify(_gmUndoRef('islem', { id: 'IL1', tip })), JSON.stringify({ kind: 'islem', id: 'IL1' }), `${tip} geri alınabilir olmalı`);
  }
  assert.strictEqual(_gmUndoRef('islem', { id: 'IL2', tip: 'ASI_KAYDI' }), null);
  assert.strictEqual(_gmUndoRef('islem', { id: 'IL3', tip: 'TOPLU_ILAC' }), null);
  assert.strictEqual(_gmUndoRef('islem', { tip: 'HASTALIK_KAYDI' }), null, 'idsiz kayıt buton alamaz');
});

test('undoRef tohumlama: islem ref > yalnız Bekliyor-son kayıt toh:; terminal sonuç/iptal asla doğrudan silinmez', () => {
  const { _gmUndoRef } = sandbox;
  const ctx = { latestTohIdByAnimal: { A1: 'T9' }, islemRefByTohId: { T9: 'IL5' } };
  // islem_log referansı varsa o id ile geri alınır
  assert.strictEqual(JSON.stringify(_gmUndoRef('tohumlama', { id: 'T9', sonuc: 'Gebe', hayvan_id: 'A1' }, ctx)), JSON.stringify({ kind: 'islem', id: 'IL5' }));
  // referans yok + SON kayıt + sonuç Bekliyor → doğrudan silme yolu (openTohDet kuralı)
  assert.strictEqual(
    JSON.stringify(_gmUndoRef('tohumlama', { id: 'T9', sonuc: 'Bekliyor', hayvan_id: 'A1' }, { latestTohIdByAnimal: { A1: 'T9' }, islemRefByTohId: {} })),
    JSON.stringify({ kind: 'toh', id: 'T9' })
  );
  // impl-review bulgu 1: referans yok + SON kayıt ama sonuç TERMINAL (Gebe/Boş/…)
  // → doğrudan toh: silme yolu ÜRETİLMEZ (üretim guard'ı yalnız Bekliyor'a izin verir)
  for (const sonuc of ['Gebe', 'Boş', 'Doğum Yaptı', 'Abort']) {
    assert.strictEqual(
      _gmUndoRef('tohumlama', { id: 'T9', sonuc, hayvan_id: 'A1' }, { latestTohIdByAnimal: { A1: 'T9' }, islemRefByTohId: {} }),
      null,
      `${sonuc} sonuçlu son kayıt toh: almamalı`
    );
  }
  // eski kayıt → buton yok
  assert.strictEqual(_gmUndoRef('tohumlama', { id: 'T7', sonuc: 'Bekliyor', hayvan_id: 'A1' }, ctx), null);
  // son tohumlama ama abort muhafazalı → buton yok
  assert.strictEqual(
    _gmUndoRef('tohumlama', { id: 'T9', sonuc: 'Bekliyor', hayvan_id: 'A1' }, { latestTohIdByAnimal: { A1: 'T9' }, abortGuardedByTohId: { T9: true } }),
    null
  );
});

test('undoRef diğer tipler: null (buton yok)', () => {
  const { _gmUndoRef } = sandbox;
  for (const t of ['gorev', 'hastalik', 'dogum', 'uygulama']) {
    assert.strictEqual(_gmUndoRef(t, { id: 'X1' }, {}), null, `${t} buton almamalı`);
  }
});

test('entry üretimi undoRef bağlamını ham kaynaklardan kurar', () => {
  const { _gmEntriesFromSources } = sandbox;
  const out = _gmEntriesFromSources({
    tohumlama: [
      { id: 'T9', sonuc: 'Gebe', created_at: '2026-09-01T10:00:00Z', hayvan_id: 'A1' },
      { id: 'T7', sonuc: 'Boş', created_at: '2026-08-01T10:00:00Z', hayvan_id: 'A1' },
    ],
    islem_log: [{ id: 'IL5', tip: 'TOHUMLAMA', ref_id: 'T9', tarih: '2026-09-01' }],
  });
  const t9 = out.find(e => e.data.id === 'T9');
  const t7 = out.find(e => e.data.id === 'T7');
  assert.strictEqual(JSON.stringify(t9.undoRef), JSON.stringify({ kind: 'islem', id: 'IL5' }));
  assert.strictEqual(t7.undoRef, null, 'eski tohumlama buton almaz');
  // TOHUMLAMA tipindeki islem_log satırı politika gereği entry ÜRETMEZ ama bağlam kurar
  assert.strictEqual(out.filter(e => e.type === 'islem').length, 0);
});

test('_gmUndoButtonHtml: ref null → boş string; değerler dataset\'te, onclick sabit (helpers escAttr-inline yasağı)', () => {
  const { _gmUndoButtonHtml } = sandbox;
  assert.strictEqual(_gmUndoButtonHtml(null), '');
  const html = _gmUndoButtonHtml({ kind: 'islem', id: 'IL5' });
  // impl-review bulgu 4: entity-escape edilmiş değer inline JS string'ine konmaz —
  // this.dataset deseni (helpers.js:90-96 kuralı); onclick gövdesi SABİT stringdir
  assert.ok(html.includes('data-kind="islem"') && html.includes('data-id="IL5"'), 'data-kind/data-id attribute');
  assert.ok(html.includes('gmUndoClick(this.dataset.kind,this.dataset.id)'), 'onclick dataset okur');
  assert.ok(!/gmUndoClick\('/.test(html), 'inline JS string literali olmamalı');
  assert.ok(html.includes('stopPropagation'), 'stopPropagation olmalı (kart onclick inden kaçış)');
  assert.ok(html.startsWith('<button'), 'buton elementi olmalı');
  // toh yolu
  const tohHtml = _gmUndoButtonHtml({ kind: 'toh', id: 'T9' });
  assert.ok(tohHtml.includes('data-kind="toh"') && tohHtml.includes('data-id="T9"'));
});

test('_gmUndoButtonHtml: offline seçeneğinde buton gizlenir (D13)', () => {
  const { _gmUndoButtonHtml } = sandbox;
  assert.strictEqual(_gmUndoButtonHtml({ kind: 'islem', id: 'IL5' }, { offline: true }), '');
  assert.ok(_gmUndoButtonHtml({ kind: 'islem', id: 'IL5' }, { offline: false }).includes('gmUndoClick'));
});

// ── Görev 3: cap + gün gruplama + sayaçlar + arama ───────────────

test('_gmCap: ilk n kayıt görünür, toplam cap öncesi uzunluk', () => {
  const { _gmCap } = sandbox;
  const girdi = [{ eventAt: '4' }, { eventAt: '3' }, { eventAt: '2' }, { eventAt: '1' }, { eventAt: '0' }];
  const sonuc = _gmCap(girdi, 3);
  assert.strictEqual(sonuc.visible.length, 3);
  assert.strictEqual(sonuc.visible[0].eventAt, '4', 'slice sıralı girdinin başından alır');
  assert.strictEqual(sonuc.total, 5);
  // varsayılan limit 300
  assert.strictEqual(_gmCap(girdi).visible.length, 5);
  assert.strictEqual(_gmCap(girdi).total, 5);
  assert.strictEqual(_gmCap([], 300).total, 0);
});

test('_gmGroup: dateKey bazlı sıralı gruplar, grup içi sayaçlar yalnız mevcut kategoriler', () => {
  const { _gmGroup } = sandbox;
  const gorunen = [
    { dateKey: '2026-09-09', category: 'dogum' },
    { dateKey: '2026-09-09', category: 'gorev' },
    { dateKey: '2026-09-09', category: 'gorev' },
    { dateKey: '2026-09-08', category: 'tohumlama' },
  ];
  const gruplar = _gmGroup(gorunen);
  assert.strictEqual(gruplar.length, 2);
  assert.strictEqual(gruplar[0].dateKey, '2026-09-09');
  assert.strictEqual(gruplar[0].entries.length, 3);
  // sayaç: mevcut kategori anahtarları yalnız o grubun görünen kayıtlarından
  assert.strictEqual(JSON.stringify(gruplar[0].counters), JSON.stringify({ dogum: 1, gorev: 2 }));
  assert.strictEqual(JSON.stringify(gruplar[1].counters), JSON.stringify({ tohumlama: 1 }));
  assert.strictEqual(gruplar[1].entries.length, 1);
});

test('_gmGroupHtml: <details + <summary, BUGÜN/DÜN/d MMMM gün etiketi, emoji sayaçlar, entry kartları', () => {
  const { _gmGroupHtml } = sandbox;
  const grup = {
    dateKey: '2026-09-09',
    entries: [{ id: 'E1' }, { id: 'E2' }],
    counters: { dogum: 1, gorev: 1 },
  };
  const kart = e => `<div class="kart">${e.id}</div>`;
  const html = _gmGroupHtml(grup, kart, { todayKey: '2026-09-09' });
  assert.ok(html.startsWith('<details'), 'details ile başlamalı');
  assert.ok(html.includes('open'), 'varsayılan açık olmalı');
  assert.ok(html.includes('<summary'), 'summary başlık olmalı');
  assert.ok(html.includes('BUGÜN'), 'bugün etiketi');
  assert.ok(html.includes('🐄 1') && html.includes('✅ 1'), 'emoji sayaçlar');
  assert.ok(html.includes('<div class="kart">E1</div>') && html.includes('<div class="kart">E2</div>'), 'entryHtmlFn çıktıları injecting edilmeli');

  // DÜN
  const dun = _gmGroupHtml({ dateKey: '2026-09-08', entries: [], counters: {} }, kart, { todayKey: '2026-09-09' });
  assert.ok(dun.includes('DÜN'));
  // tarihli gün: 2026-09-07 = Pazartesi
  const eski = _gmGroupHtml({ dateKey: '2026-09-07', entries: [], counters: {} }, kart, { todayKey: '2026-09-09' });
  assert.ok(eski.includes('7 Eylül Pazartesi'), `alde etiket: ${eski}`);
  // kapalı grup (aramada açık zorunlu; normalde son grup açık kalabilir)
  const kapali = _gmGroupHtml({ dateKey: '2026-09-07', entries: [], counters: {} }, kart, { todayKey: '2026-09-09', open: false });
  assert.ok(!/\<details[^>]*\sopen/.test(kapali), 'open:false ile details açık olmamalı');
});

test('_gmSearch: çok terimli AND, Türkçe küçük harf (İ→i), boş sorgu → tamamı', () => {
  const { _gmSearch } = sandbox;
  const girdi = [
    { searchText: 'tohumlama 1234 düzenova gebe' },
    { searchText: 'dogum 5678 kırmızı' },
    { searchText: 'aşı 1234 ibarsa' },
  ];
  assert.strictEqual(_gmSearch(girdi, '').length, 3, 'boş sorgu → tümü');
  assert.strictEqual(_gmSearch(girdi, '1234').length, 2);
  assert.strictEqual(_gmSearch(girdi, '1234 gebe').length, 1);
  // Türkçe İ: 'KIZGINLIK' kaydı 'kızgınlık' ile bulunmalı (trLower kuralları)
  const tr = [{ searchText: 'kısmet kızgınlık kaydı' }];
  assert.strictEqual(_gmSearch(tr, 'KIZGINLIK').length, 1);
  assert.strictEqual(_gmSearch(tr, 'kızginlik').length, 0, 'ı harfi birebir: sorgu ı ile yazılmadan bulunmaz');
  assert.strictEqual(_gmSearch(girdi, 'yoktur').length, 0);
});

// ── Görev 4: CSV üretimi (spec D) ────────────────────────────────

test('_gmCsvEscape: ; " newline sarmalanır, iç " ikilenir, formül önekleri apostrof alır', () => {
  const { _gmCsvEscape } = sandbox;
  assert.strictEqual(_gmCsvEscape('a;b'), '"a;b"');
  assert.strictEqual(_gmCsvEscape('say "hi"'), '"say ""hi"""');
  assert.strictEqual(_gmCsvEscape('a\nb'), '"a\nb"', 'satır sonu tırnak içinde kalmalı');
  assert.strictEqual(_gmCsvEscape('düz'), 'düz');
  assert.strictEqual(_gmCsvEscape('=cmd'), "'=cmd");
  assert.strictEqual(_gmCsvEscape('+toplam'), "'+toplam");
  assert.strictEqual(_gmCsvEscape('-1'), "'-1");
  assert.strictEqual(_gmCsvEscape('@x'), "'@x");
  assert.strictEqual(_gmCsvEscape(null), '');
  assert.strictEqual(_gmCsvEscape(42), '42');
});

test('_gmCsvEscape formül öneki + tırnak: apostrof öneklendikten sonra sarmalama uygulanır', () => {
  const { _gmCsvEscape } = sandbox;
  assert.strictEqual(_gmCsvEscape('=a;b'), '"\'=a;b"');
});

test('_gmCsv: BOM + başlık + CRLF + satır başına bir kayıt + DD.MM.YYYY / HH:MM', () => {
  const { _gmCsv } = sandbox;
  const gorunen = [
    { category: 'tohumlama', eventAt: '2026-09-08T09:05:00Z' },
    { category: 'dogum', eventAt: '2026-09-01' }, // saat yok
  ];
  const csv = _gmCsv(gorunen, {
    kupe: e => 'TR-1234',
    detay: e => e.category === 'tohumlama' ? 'KIRMIZI — <b>Düzenova</b>' : 'ANNE → YAVRU (Dişi)',
    ek: e => '1. Tohumlama · Gebe',
    hekim: () => 'Dr. Ayşe',
    tip: () => '',
  });
  // BOM + başlık
  assert.ok(csv.startsWith('\uFEFFTarih;Saat;Kategori;Küpe;Detay;Ek Bilgi;Hekim;Tip\r\n'), 'BOM + başlık + CRLF');
  // satır sayısı: başlık + 2 kayıt + sondaki CRLF boş parça
  const satirlar = csv.split('\r\n');
  assert.strictEqual(satirlar.length, 4, 'başlık + 2 satır + trailing');
  assert.strictEqual(satirlar[1].split(';').length, 8, '8 sütun');
  assert.ok(satirlar[1].startsWith('08.09.2026;12:05;'), 'tarih DD.MM.YYYY saat HH:MM (Europe/Istanbul — 09:05Z = 12:05)');
  assert.ok(satirlar[1].includes('Tohumlama'), 'kategori etiketi TR');
  assert.ok(satirlar[1].includes('KIRMIZI — Düzenova'), 'detay HTML etiketsiz');
  assert.ok(satirlar[2].startsWith('01.09.2026;;'), 'saatsiz kayıtta saat sütunu boş');
  assert.ok(satirlar[2].includes('Doğum'), 'dogum kategorisi');
});

test('_gmCsv meta verilmezse hücreler boş kalır, çökmez', () => {
  const { _gmCsv } = sandbox;
  const csv = _gmCsv([{ category: 'gorev', eventAt: '2026-09-08T09:05:00Z' }]);
  assert.ok(csv.includes('08.09.2026;12:05;Görev;;;;;'), `satır: ${JSON.stringify(csv.split('\r\n')[1])}`);
});

test('dateKey + CSV saati Europe/Istanbul kuralı (impl-review 5/7): UTC akşamı → ertesi gün', () => {
  const { _gmEntriesFromSources, _gmCsvTarih, _gmCsvSaat } = sandbox;
  // 21:30Z = Istanbul 00:30 (ertesi takvim günü) — kart fmtTarihSaat ile aynı kural
  const out = _gmEntriesFromSources({ gorev_log: [{ id: 'G1', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T21:30:00Z' }] });
  assert.strictEqual(out[0].dateKey, '2026-09-09', 'UTC 21:30 Istanbul 00:30 → ertesi gün');
  assert.strictEqual(_gmCsvTarih('2026-09-08T21:30:00Z'), '09.09.2026');
  assert.strictEqual(_gmCsvSaat('2026-09-08T21:30:00Z'), '00:30');
  // gün içi UTC öğleden sonra aynı günde kalır
  assert.strictEqual(_gmEntriesFromSources({ gorev_log: [{ id: 'G2', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z' }] })[0].dateKey, '2026-09-08');
  // timezone'suz yerel yazım aynen korunur (dönüşüm uygulanmaz)
  assert.strictEqual(_gmCsvTarih('2026-08-30T00:00:00'), '30.08.2026');
  assert.strictEqual(_gmCsvSaat('2026-08-30T00:00:00'), '00:00');
  assert.strictEqual(_gmCsvSaat('2026-08-30'), '', 'saat dilimi yoksa sütun boş');
  // impl-review-r2: explicit offset formları da Istanbul'a çevrilir (yalnız Z değil)
  assert.strictEqual(_gmEntriesFromSources({ gorev_log: [{ id: 'G3', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T21:30:00+00:00' }] })[0].dateKey, '2026-09-09', '+00:00 = Z ile aynı');
  assert.strictEqual(_gmCsvTarih('2026-09-08T21:30:00+00:00'), '09.09.2026');
  assert.strictEqual(_gmCsvSaat('2026-09-08T21:30:00+00:00'), '00:30');
  // Istanbul offset'i zaten yerel: aynı kalır
  assert.strictEqual(_gmCsvTarih('2026-09-08T21:30:00+03:00'), '08.09.2026');
  assert.strictEqual(_gmCsvSaat('2026-09-08T21:30:00+03:00'), '21:30');
});

// ── D15: Klasik görünüm modu (eski düz-liste davranışı) ──────────

test('klasik mod: bekleyen tohumlama ve aktif vaka görünür, defter politikası bypass edilir', () => {
  const { _gmEntriesFromSources } = sandbox;
  const sources = {
    tohumlama: [{ id: 'T1', sonuc: 'Bekliyor', created_at: '2026-09-08T10:00:00Z', hayvan_id: 'A1' }],
    cases: [{ id: 'C1', status: 'active', start_date: '2026-09-08', created_at: '2026-09-08T08:00:00Z' }],
    gorev_log: [{ id: 'G1', tamamlandi: false, hedef_tarih: '2099-01-01' }],
  };
  // defter (default): hiçbiri geçmez
  assert.strictEqual(_gmEntriesFromSources(sources).length, 0);
  // klasik: tohumlama (Bekliyor) ve aktif vaka girer; pending gorev tumu=false'da girmez
  const k = _gmEntriesFromSources(sources, null, { mode: 'klasik', tumu: false });
  assert.strictEqual(k.map(e => e.type + ':' + e.data.id).sort().join(','), 'hastalik:C1,tohumlama:T1');
});

test('klasik mod gorev: tumu=false → tamamlandı+parentsız; tumu=true → pending ve alt görev dahil, iptal yine hariç', () => {
  const { _gmEntriesFromSources } = sandbox;
  const sources = { gorev_log: [
    { id: 'DONE', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T09:00:00Z' },
    { id: 'PEND', tamamlandi: false, hedef_tarih: '2026-09-10' },
    { id: 'CHILD', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T07:00:00Z', parent_id: 'ana' },
    { id: 'IPTAL', tamamlandi: true, tamamlanma_tarihi: '2026-09-08T06:00:00Z', iptal: true },
  ]};
  const kapali = _gmEntriesFromSources(sources, null, { mode: 'klasik', tumu: false }).map(e => e.data.id).join(',');
  assert.strictEqual(kapali, 'DONE', 'eski default: tamamlandı ve parentsız');
  const acik = _gmEntriesFromSources(sources, null, { mode: 'klasik', tumu: true }).map(e => e.data.id).sort().join(',');
  assert.strictEqual(acik, 'CHILD,DONE,PEND', 'tümü açık: pending + alt görev girer, iptal girmez');
});

test('klasik mod eventAt: eski fallback zincirleri (gorev tamamlanma→created_at→hedef; vaka created_at→start_date)', () => {
  const { _gmEntriesFromSources } = sandbox;
  const g = _gmEntriesFromSources({ gorev_log: [{ id: 'G1', tamamlandi: false, created_at: '2026-09-07T12:00:00Z', hedef_tarih: '2026-09-10' }] }, null, { mode: 'klasik', tumu: true });
  assert.strictEqual(g[0].eventAt, '2026-09-07T12:00:00Z', 'pending görevde created_at esas');
  const c = _gmEntriesFromSources({ cases: [{ id: 'C1', status: 'active', start_date: '2026-09-05', created_at: '2026-09-05T09:00:00Z' }] }, null, { mode: 'klasik' });
  assert.strictEqual(c[0].eventAt, '2026-09-05T09:00:00Z');
});
