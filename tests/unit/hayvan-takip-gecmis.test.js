// tests/unit/hayvan-takip-gecmis.test.js — Hayvan Takip F3: Geçmiş ve değişiklik etiketleri.
// R6 / domain-rules §20.7: üç islem tipinde Geçmiş'te geri alma düğmesi yoktur;
// Değişiklikler sayfası (parolalı motor) bu kararın dışındadır.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadBrowserModule, loadExtractedFunction } = require('./support/loadModule.js');

const REPO_ROOT = path.join(__dirname, '..', '..');
const SEMA_MIGRATION = 'supabase/migrations/20261031200001_hayvan_takip_sema.sql';
const UC_TIP = ['HAYVAN_TAKIP_ACILDI', 'HAYVAN_TAKIP_KAPANDI', 'HAYVAN_TAKIP_MUAYENE'];

function gecmisYukle() {
  const { HAYVAN_TAKIP_SEBEPLER, HAYVAN_TAKIP_GOREV_TIPI } = loadBrowserModule('js/config.js', {
    expose: ['HAYVAN_TAKIP_SEBEPLER', 'HAYVAN_TAKIP_GOREV_TIPI'],
  }).exposed;
  const { sandbox: ht } = loadBrowserModule('js/hayvan-takip.js', {
    extra: { HAYVAN_TAKIP_SEBEPLER, HAYVAN_TAKIP_GOREV_TIPI },
  });
  return loadBrowserModule('js/gecmis.js', {
    expose: ['_GM_ISLEM_TIPLERI'],
    extra: { htSebepEtiket: ht.htSebepEtiket },
  });
}

const satir = (tip, ek = {}) => ({
  id: 'il-1', tip, ana_hayvan_id: 'h-1', ref_tablo: 'hayvan_takip', ref_id: 't-1', tarih: '2026-10-31T08:00:00Z', ...ek,
});

test('HT-GM-01: üç tip izin listesinde, politika kabul eder, geri_alindi reddedilir', () => {
  const { sandbox, exposed } = gecmisYukle();
  for (const tip of UC_TIP) {
    assert.ok(exposed._GM_ISLEM_TIPLERI.includes(tip), `${tip} izin listesinde`);
    assert.strictEqual(sandbox._gmPolicyRow('islem_log', { tip }), true, tip);
    assert.strictEqual(sandbox._gmPolicyRow('islem_log', { tip, durum: 'geri_alindi' }), false, `${tip} geri_alindi`);
  }
});

test('HT-GM-02: etiket ve emoji', () => {
  const { sandbox } = gecmisYukle();
  const beklenen = {
    HAYVAN_TAKIP_ACILDI: ['Takibe Alındı', '📌'],
    HAYVAN_TAKIP_KAPANDI: ['Takip Kapandı', '✓'],
    HAYVAN_TAKIP_MUAYENE: ['Takip Muayenesi', '🔍'],
  };
  for (const [tip, [etiket, emoji]] of Object.entries(beklenen)) {
    assert.strictEqual(sandbox._gmIslemTipEtiket(tip), etiket);
    assert.strictEqual(sandbox._gmIslemTipEmoji(tip), emoji);
  }
});

test('HT-GM-03: üç tipte _gmUndoRef null (köprü txid olsa da); ABORT_KAYDI değişmez', () => {
  const { sandbox } = gecmisYukle();
  for (const tip of UC_TIP) {
    assert.strictEqual(sandbox._gmUndoRef('islem', satir(tip)), null, tip);
    assert.strictEqual(sandbox._gmUndoRef('islem', satir(tip, { degisim_txid: '123' })), null, `${tip} txid`);
  }
  const abort = sandbox._gmUndoRef('islem', { id: 'il-2', tip: 'ABORT_KAYDI', ref_tablo: 'tohumlama', ref_id: 'toh-1' });
  assert.strictEqual(abort.kind, 'l2');
  assert.strictEqual(abort.id, 'il-2');
});

// Kartın ikinci kapısı: gm-islem → _openIslemDetayRow, _gmUndoRef'e uğramadan
// _gmGeriAlHedef'e bakar. Kart düğmesi kapanıp panel düğmesi açık kalamaz.
test('HT-GM-03b: Geçmiş detay panelinde üç tipte geri al yok, ABORT_KAYDI panelinde var', () => {
  const { sandbox } = gecmisYukle();
  const panelHtml = l => {
    let panel = null;
    const fn = loadExtractedFunction('js/ui.js', '_openIslemDetayRow', {
      extra: {
        _gmGeriAlHedef: sandbox._gmGeriAlHedef,
        _gmIslemTipEmoji: sandbox._gmIslemTipEmoji,
        _gmIslemTipEtiket: sandbox._gmIslemTipEtiket,
        _islemDetaySatirlariHtml: () => '',
        esc: String, escAttr: String,
        document: { querySelector: () => null, createElement: () => ({}), getElementById: () => null },
      },
    });
    fn(l, { insertAdjacentElement: (_, p) => { panel = p; } });
    return panel.innerHTML;
  };
  for (const tip of UC_TIP) {
    assert.ok(!panelHtml(satir(tip)).includes('dg-det-geri-al'), tip);
    assert.strictEqual(sandbox._gmGeriAlHedef(satir(tip, { degisim_txid: '123' })), null, `${tip} çözücü`);
  }
  assert.ok(panelHtml({ id: 'il-2', tip: 'ABORT_KAYDI', ref_tablo: 'tohumlama', ref_id: 'toh-1' }).includes('dg-det-geri-al'));
});

test('HT-GM-04: gmHtIslemAlt not, sebep etiketi ve sonucu ham metin verir', () => {
  const { sandbox: { gmHtIslemAlt } } = gecmisYukle();
  const alt = (tip, snapshot, kullanici_notu) => gmHtIslemAlt(satir(tip, { snapshot, kullanici_notu }));

  const sursun = alt('HAYVAN_TAKIP_MUAYENE', { sebep_kodu: 'TOPALLIK', sonuc: 'SURSUN' }, 'tırnak bakıldı');
  assert.ok(sursun.includes('Topallık'), sursun);
  assert.ok(sursun.includes('Takip sürsün'), sursun);
  assert.ok(sursun.includes('tırnak bakıldı'), sursun);
  assert.ok(alt('HAYVAN_TAKIP_MUAYENE', { sebep_kodu: 'TOPALLIK', sonuc: 'KAPANSIN' }, null).includes('Takip kapansın'));
  assert.strictEqual(alt('HAYVAN_TAKIP_MUAYENE', { sebep_kodu: 'TOPALLIK', sonuc: 'VAKA' }, 'tedaviye alındı'), 'Topallık · Vakaya bağlandı · tedaviye alındı');

  // Not yoksa boşluk ya da ayraç artığı kalmaz; bilinmeyen sonuç uydurulmaz.
  assert.strictEqual(alt('HAYVAN_TAKIP_KAPANDI', { sebep_kodu: 'SUT_DUSUSU' }, '  '), 'Süt düşüşü');
  assert.strictEqual(alt('HAYVAN_TAKIP_MUAYENE', { sebep_kodu: 'SUT_DUSUSU', sonuc: 'BASKA' }, null), 'Süt düşüşü');

  // R12: DIGER sebep olarak açıklamayı gösterir. Açılışta not açıklamanın kopyasıdır, iki kez yazılmaz.
  assert.strictEqual(alt('HAYVAN_TAKIP_ACILDI', { sebep_kodu: 'DIGER', aciklama: 'Kulak yarası' }, 'Kulak yarası'), 'Kulak yarası');

  // Kaçışsız: kaçış çağıranındır (F4 esc uygular).
  assert.ok(alt('HAYVAN_TAKIP_KAPANDI', { sebep_kodu: 'TOPALLIK' }, '<b>x</b>').includes('<b>x</b>'));
});

test('HT-GM-04b: gmHtIslemAlt üç tip dışında ve bozuk girdide boş döner', () => {
  const { sandbox: { gmHtIslemAlt } } = gecmisYukle();
  assert.strictEqual(gmHtIslemAlt({ tip: 'GOREV_TAMAMLA', kullanici_notu: 'not' }), '');
  assert.strictEqual(gmHtIslemAlt(null), '');
  assert.strictEqual(gmHtIslemAlt({ tip: 'HAYVAN_TAKIP_KAPANDI', snapshot: null, kullanici_notu: 'yalnız not' }), 'yalnız not');
});

test('HT-GM-05: görev tipi kod-değer etiketi', () => {
  const { sandbox } = gecmisYukle();
  assert.strictEqual(sandbox.gmKodDegerEtiketi('gorev_tipi', 'HAYVAN_TAKIP_MUAYENE'), 'Hayvan Takip Muayenesi');
  assert.strictEqual(sandbox.gmKodDegerEtiketi('gorev_tipi', 'TAKIP_MUAYENE'), 'Takip Muayenesi', 'Ovsync etiketi ayrı kalır');
});

test('HT-GM-06: etiketler.js tablo, ref_takip_id ve hayvan_takip alanları açık etiketli', () => {
  const { sandbox: { tabloEtiketi, alanEtiketi, kapsamHaritalari } } = loadBrowserModule('js/degisiklikler/etiketler.js');
  assert.strictEqual(tabloEtiketi('hayvan_takip'), 'Hayvan takibi');

  const { ortakAlanlar, tabloOzelAlanlar } = kapsamHaritalari();
  assert.ok(tabloOzelAlanlar.gorev_log.ref_takip_id, 'gorev_log.ref_takip_id etiketsiz');
  assert.strictEqual(alanEtiketi('gorev_log', 'ref_takip_id'), tabloOzelAlanlar.gorev_log.ref_takip_id);

  // Kolon listesi migration'dan okunur: yeni kolon etiketsiz kalırsa bu test kızarır.
  const sql = fs.readFileSync(path.join(REPO_ROOT, SEMA_MIGRATION), 'utf8');
  const blok = sql.match(/CREATE TABLE public\.hayvan_takip \(([\s\S]*?)\n\);/)[1];
  const kolonlar = blok.split('\n').map(s => s.match(/^ {2}([a-z_]+) (?:uuid|text|timestamptz)\b/)?.[1]).filter(Boolean);
  assert.strictEqual(kolonlar.length, 12, kolonlar.join(','));
  const eksik = kolonlar.filter(k => !tabloOzelAlanlar.hayvan_takip?.[k] && !ortakAlanlar[k]);
  assert.deepStrictEqual(Array.from(eksik), [], `etiketsiz: ${eksik.join(', ')}`);
  assert.strictEqual(alanEtiketi('hayvan_takip', 'sebep_kodu'), 'Sebep');
  assert.strictEqual(alanEtiketi('hayvan_takip', 'kapanis_nedeni'), 'Kapanış nedeni');
});
