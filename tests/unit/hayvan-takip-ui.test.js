// tests/unit/hayvan-takip-ui.test.js — Hayvan Takip F4: js/ui.js bağlantıları (kart, band, görev yönü).
// ui.js, config.js, hayvan-takip.js, pencere ve gecmis.js gerçektir; yalnız DOM, veri ve ekran yan etkileri sahtedir.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { loadBrowserModule, loadExtractedFunction, extractFunctionSource, makeDomStub, makeElement } = require('./support/loadModule.js');
const { fmtTarih, getDisplayKupe, kuceDogalKarsilastir } = require('../../js/utils/helpers.js');

const REPO_ROOT = path.join(__dirname, '..', '..');
const oku = yol => fs.readFileSync(path.join(REPO_ROOT, yol), 'utf8');
const escMirror = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = s => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const BUGUN = '2026-10-31';
const YENI = 'HAYVAN_TAKIP_MUAYENE';
const XSS = '<img src=x onerror=1>';
const XSS_KACISLI = '&lt;img src=x onerror=1&gt;';

const hayvan = (ek = {}) => ({ id: 'H1', kupe_no: '157', durum: 'Aktif', grup: 'Sağmal', padok: 'P1', ...ek });
const takip = (id, ek = {}) => ({ id, hayvan_id: 'H1', sebep_kodu: 'TOPALLIK', aciklama: null, acilis_tarihi: '2026-10-20T08:00:00Z', kapanis_tarihi: null, ...ek });
const gorev = (id, ek = {}) => ({ id, hayvan_id: 'H1', gorev_tipi: YENI, ref_takip_id: 't1', aciklama: 'Topallık takibi muayenesi', hedef_tarih: BUGUN, tamamlandi: false, iptal: false, ...ek });
const say = (metin, parca) => metin.split(parca).length - 1;

/** Gerçek modülleri aynı sandbox'a yükler; document her kimliğe eleman verir. */
function kur(o = {}) {
  const dom = makeDomStub();
  const els = new Map();
  dom.getElementById = id => {
    if (!els.has(id)) { const e = makeElement('div'); e.id = id; els.set(id, e); }
    return els.get(id);
  };
  const k = { els, dom, veri: o.veri || {}, toastlar: [], acilan: [], pulllar: [], rpcler: [] };
  const hepsi = t => k.veri[t] || [];
  const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
    dom,
    expose: ['_katTipMap', '_dashBands', 'TARIH_ALANLARI', '_DET_TABLOLAR'],
    extra: {
      navigator: { userAgent: 'node-test', onLine: o.onLine !== false },
      esc: escMirror, escAttr: escAttrMirror, fmtTarih, fmtTarihSaat: fmtTarih, getDisplayKupe, kuceDogalKarsilastir,
      _istanbulGunNo: loadExtractedFunction('js/utils/helpers.js', '_istanbulGunNo'),
      getUserMessage: e => String(e?.message || e),
      trLower: s => String(s).toLocaleLowerCase('tr'),
      bugun: () => BUGUN, dAgo: () => BUGUN, dFwd: t => t,
      g: id => dom.getElementById(id), cl: id => { dom.getElementById(id).value = ''; },
      toast: (m, e) => k.toastlar.push([m, !!e]),
      openM: id => k.acilan.push(id), closeM: () => {},
      getState: s => (s === 'animals' ? hepsi('hayvanlar') : s === 'currentPage' ? 'dash' : null),
      setState: () => {},
      idbGetAll: async t => hepsi(t),
      getData: async (t, pred) => hepsi(t).filter(pred || (() => true)),
      pullTables: async (t, opts) => { k.pulllar.push({ t, opts: opts || null }); return { ok: [...t], failed: [] }; },
      rpc: async (ad, p) => { k.rpcler.push({ ad, p }); return []; },
      write: async () => [],
      _customHekimler: [],
      aktifHayvanSatirlari: loadExtractedFunction('js/utils/helpers.js', 'aktifHayvanSatirlari'),
    },
  });
  ['js/config.js', 'js/hayvan-takip.js', 'js/hayvan-takip-pencere.js', 'js/gecmis.js'].forEach(yol => vm.runInContext(oku(yol), sandbox, { filename: yol }));
  k.sandbox = sandbox;
  k.exposed = exposed;
  k.sonucCagri = [];
  k.muayeneCagri = [];
  k.doneCagri = [];
  sandbox.doneTask = async (...a) => { k.doneCagri.push(a); };
  sandbox._muayeneSonucAc = async id => { k.muayeneCagri.push(id); return true; };
  k.sonucSahte = (donus = true) => { sandbox.htSonucAc = async id => { k.sonucCagri.push(id); return donus; }; };
  return k;
}

test('HT-UI-01: _erteleBtnHtml yeni tipte boş, düz görevde düğme', () => {
  const { sandbox } = kur();
  sandbox.ertelemeKuralGetir = () => ({ ertelenebilir: true });
  sandbox._ertelemeOnline = () => true;
  assert.strictEqual(sandbox._erteleBtnHtml({ id: 'g1', gorev_tipi: YENI }), '');
  assert.match(sandbox._erteleBtnHtml({ id: 'g2', gorev_tipi: 'DIGER' }), /data-ertele/);
});

test('HT-UI-02: renderTask yeni tipte ✓ çizmez, kart yine sonuç yoluna tıklanır', () => {
  const { sandbox } = kur();
  const yeni = sandbox.renderTask(gorev('g1'));
  assert.ok(!yeni.includes('togglePendingDone'), yeni);
  assert.ok(yeni.includes("openTaskDet('g1')"));
  assert.ok(sandbox.renderTask(gorev('g2', { gorev_tipi: 'DIGER' })).includes('togglePendingDone'));
});

test('HT-UI-03: openTaskDet yeni tipte sonuç penceresine gider, jenerik detaya yazmaz', async () => {
  const k = kur({ veri: { gorev_log: [gorev('g1')], hayvanlar: [hayvan()] } });
  k.sonucSahte(true);
  await k.sandbox.openTaskDet('g1');
  assert.deepStrictEqual(k.sonucCagri, ['g1']);
  assert.strictEqual(k.dom.getElementById('td-hayvan').textContent, '');
  assert.ok(!k.acilan.includes('m-task-det'));
  assert.strictEqual(vm.runInContext('_curTaskDet && _curTaskDet.id', k.sandbox), 'g1');
});

test('HT-UI-04: çevrimdışı ya da false dönüşünde m-task-det açılmaz', async () => {
  // Gerçek htSonucAc: çevrimdışı uyarır, RPC ve pencere yok.
  const cevrimdisi = kur({ onLine: false, veri: { gorev_log: [gorev('g1')], hayvanlar: [hayvan()] } });
  await cevrimdisi.sandbox.openTaskDet('g1');
  assert.deepStrictEqual(cevrimdisi.acilan, []);
  assert.ok(cevrimdisi.toastlar.some(([m]) => m.includes('İnternet')), JSON.stringify(cevrimdisi.toastlar));
  assert.strictEqual(cevrimdisi.dom.getElementById('td-hayvan').textContent, '');

  // false dönüşü: görev bu arada kapanmış olabilir, jenerik yedek açılmaz.
  const yanlis = kur({ veri: { gorev_log: [gorev('g1')], hayvanlar: [hayvan()] } });
  yanlis.sonucSahte(false);
  await yanlis.sandbox.openTaskDet('g1');
  assert.ok(!yanlis.acilan.includes('m-task-det'));
});

test('HT-UI-05: detayTamamla yeni tipte doneTask çağırmaz, tamam düğmesi kaynakta gizli', async () => {
  const k = kur({ veri: { gorev_log: [gorev('g1')] } });
  k.sonucSahte(true);
  vm.runInContext(`_curTaskDet = ${JSON.stringify(gorev('g1'))}`, k.sandbox);
  await k.sandbox.detayTamamla();
  assert.deepStrictEqual(k.doneCagri, []);
  assert.deepStrictEqual(k.sonucCagri, ['g1']);
  // R5 yüzünden çalışma anında ulaşılmaz; savunma satırı kaynaktan kilitlenir.
  const kaynak = extractFunctionSource('js/ui.js', 'openTaskDet');
  assert.match(kaynak, /'HAYVAN_TAKIP_MUAYENE'\)&&tamamBtn\) tamamBtn\.style\.display='none'/);
});

test('HT-UI-06: TAKIP_MUAYENE ve GEBELIK_KONTROL eski yoldan _muayeneSonucAc', async () => {
  for (const tip of ['TAKIP_MUAYENE', 'GEBELIK_KONTROL']) {
    const k = kur({ veri: { gorev_log: [gorev('g1', { gorev_tipi: tip })], hayvanlar: [hayvan()] } });
    k.sonucSahte(true);
    await k.sandbox.openTaskDet('g1');
    assert.deepStrictEqual(k.muayeneCagri, ['g1'], tip);
    assert.deepStrictEqual(k.sonucCagri, [], tip);

    k.muayeneCagri.length = 0;
    vm.runInContext(`_curTaskDet = ${JSON.stringify(gorev('g1', { gorev_tipi: tip }))}`, k.sandbox);
    await k.sandbox.detayTamamla();
    assert.deepStrictEqual(k.muayeneCagri, ['g1'], `${tip} detayTamamla`);
    assert.deepStrictEqual(k.doneCagri, [], tip);
  }
});

test('HT-UI-07: openDoneTaskDet yeni tipte geri al kapalı, düz görevde açık', async () => {
  const bugunIso = new Date().toISOString();
  const k = kur({
    veri: {
      gorev_log: [
        gorev('g1', { tamamlandi: true, tamamlanma_tarihi: bugunIso }),
        gorev('g2', { gorev_tipi: 'DIGER', tamamlandi: true, tamamlanma_tarihi: bugunIso }),
      ],
      hayvanlar: [hayvan()],
    },
  });
  const dugme = k.dom.getElementById('dd-geri-al-btn');
  await k.sandbox.openDoneTaskDet('g1');
  assert.strictEqual(dugme.disabled, true);
  assert.strictEqual(dugme.textContent, 'Muayene sonucu geri alınamaz');
  await k.sandbox.openDoneTaskDet('g2');
  assert.strictEqual(dugme.disabled, false);
  assert.strictEqual(dugme.textContent, '↩️ Geri Al');
});

test('HT-UI-08: _dashBands bandı Negatif Stok önünde; boşta yok; eski çağrılar çalışır', () => {
  const k = kur();
  const db = k.exposed._dashBands;
  const satirlar = k.sandbox.htDashSatirlari([takip('t1')], [hayvan()]);
  const h = db(2, [], [], [], [], 0, [], [], {}, [], [], {}, [], null, null, satirlar);
  assert.ok(h.includes('📌 Takipteki hayvanlar (1)'), h);
  assert.ok(h.indexOf('📌 Takipteki') < h.indexOf('Negatif Stok'), 'band negatif stoktan önce');
  assert.ok(!db(2, [], [], [], [], 0, [], [], {}, [], [], {}, [], null, null, []).includes('📌'));
  assert.ok(db(2, [], [], [], [], 0, [], [], {}, [], [], {}, []).includes('Negatif Stok'), '13 argüman');
  assert.ok(db(2, [], [], [], [], 0, [], [], {}, [], [], {}, [], null, []).includes('Negatif Stok'), '15 argüman');
});

test('HT-UI-09: _katTipMap.muayene yeni tipi içerir, ureme içermez', () => {
  const { exposed: { _katTipMap } } = kur();
  assert.ok(_katTipMap.muayene.includes(YENI));
  assert.ok(!_katTipMap.ureme.includes(YENI));
});

test('HT-UI-10: _detOzetHtml düğmeleri takip ve aktiflik durumuna göre', () => {
  const { sandbox } = kur({ veri: { hayvanlar: [] } });
  const ozet = (a, aciklar) => sandbox._detOzetHtml(a, [], [], [], [], [], 100, '3 ay', a.kupe_no, aciklar);
  const AC = 'htAcPencere(this.dataset.hid)';
  const MU = 'htMuayenePencere(this.dataset.hid)';
  const KA = 'htKapatPencere(this.dataset.hid)';

  const takipsiz = ozet(hayvan(), []);
  assert.ok(takipsiz.includes(AC) && takipsiz.includes('📌 Takibe al'));
  assert.ok(!takipsiz.includes(MU) && !takipsiz.includes(KA));
  assert.ok(!takipsiz.includes('ht-kart-blok'));

  const acik = ozet(hayvan(), [takip('t1')]);
  assert.ok(acik.includes(AC) && acik.includes(MU) && acik.includes(KA), acik);
  assert.ok(acik.includes('🔍 Muayene planla') && acik.includes('✓ Takibi kapat'));
  assert.ok(acik.includes('ht-kart-blok'));
  // Kimlik onclick içine değil data özniteliğine yazılır ve kaçışlıdır.
  assert.ok(ozet(hayvan({ id: `H"1'` }), []).includes('data-hid="H&quot;1&#39;"'));

  const cikmis = ozet(hayvan({ durum: 'Satıldı' }), [takip('t1')]);
  assert.ok(!cikmis.includes(AC) && !cikmis.includes(MU) && !cikmis.includes(KA), cikmis);

  // Eski 9 argümanlı çağrı: blok yok, Takibe al var.
  const eski = sandbox._detOzetHtml(hayvan(), [], [], [], [], [], 100, '3 ay', '157');
  assert.ok(eski.includes(AC) && !eski.includes('ht-kart-blok'));
});

test('HT-UI-11: rozetlerde açıklama kaçışlı; _detChipsHtml eski çağrı çalışır', () => {
  const { sandbox } = kur();
  const a = hayvan({ kisir: true });
  const diger = takip('t2', { sebep_kodu: 'DIGER', aciklama: XSS });

  const chips = sandbox._detChipsHtml(a, [], 0, [], [takip('t1'), diger]);
  assert.ok(chips.includes('📌 Topallık'), chips);
  assert.ok(chips.includes(`📌 ${XSS_KACISLI}`), chips);
  assert.ok(!chips.includes('<img'), chips);
  assert.ok(chips.indexOf('💲 Kısır') < chips.indexOf('📌'), 'kısır rozetiyle aynı satırda, ardından');

  const eski = sandbox._detChipsHtml(a, [], 0, []);
  assert.ok(eski.includes('💲 Kısır') && !eski.includes('📌'), eski);

  sandbox.globalThis._htAcikMap = { H1: [takip('t1'), diger] };
  const tag = sandbox._animalTagsHtml(a, new Set());
  assert.ok(tag.includes('📌 Topallık'), tag);
  assert.ok(tag.includes(`📌 ${XSS_KACISLI}`) && !tag.includes('<img'), tag);
  sandbox.globalThis._htAcikMap = { H2: [takip('t9')] };
  assert.ok(!sandbox._animalTagsHtml(a, new Set()).includes('📌'), 'başka hayvanın rozeti gelmez');
  sandbox.globalThis._htAcikMap = undefined;
  assert.ok(!sandbox._animalTagsHtml(a, new Set()).includes('📌'), 'harita yokken çalışır');
});

test('HT-UI-12: tarih alanları, kart evreni ve açık kartın tazelenmesi', async () => {
  const k = kur();
  const { TARIH_ALANLARI, _DET_TABLOLAR } = k.exposed;
  for (const id of ['ht-ac-tarih', 'ht-mu-tarih', 'ht-so-tarih']) {
    assert.deepStrictEqual({ ...TARIH_ALANLARI[id] }, { min: 'bugun', temizlenebilir: true }, id);
  }
  assert.ok(_DET_TABLOLAR.includes('hayvan_takip'));

  const cizim = [];
  k.sandbox.openDet = (...a) => { cizim.push(a); };
  k.dom.getElementById('det').classList.add('on');
  vm.runInContext("_DET_TAZELE_DEBOUNCE_MS = 1; _detOpenId = 'H1'", k.sandbox);
  k.sandbox._detAciksaTazele(['hayvan_takip'], ['hayvan_takip'], [], false);
  await new Promise(c => setTimeout(c, 25));
  assert.deepStrictEqual(cizim, [['H1', true]]);
});

test('HT-UI-13: openDet takipleri çeker, küpeyle açılışta da yalnız o hayvanın açıklarını çizer', async () => {
  const k = kur({
    veri: {
      hayvanlar: [hayvan()],
      hayvan_takip: [
        takip('t1'),
        takip('t2', { sebep_kodu: 'ZAYIFLAMA', kapanis_tarihi: '2026-10-25T08:00:00Z' }),
        takip('t3', { hayvan_id: 'H2', sebep_kodu: 'SUT_DUSUSU' }),
      ],
      gorev_log: [gorev('g1', { hedef_tarih: '2026-11-03' })],
    },
  });
  const { sandbox } = k;
  sandbox.showTab = () => {};
  sandbox._detSaglikRender = async () => {};
  sandbox._detRenderGecmis = async () => {};
  await sandbox.openDet('H1');
  const ozet = k.dom.getElementById('tab-ozet').innerHTML;
  const chips = k.dom.getElementById('det-chips').innerHTML;
  assert.ok(k.pulllar.some(p => p.t.includes('hayvan_takip') && p.opts?.detInternal), JSON.stringify(k.pulllar));
  assert.strictEqual(say(chips, '📌'), 1, chips);
  assert.ok(chips.includes('📌 Topallık'));
  assert.ok(ozet.includes('ht-kart-satir') && ozet.includes('03.11.2026'), ozet);
  assert.ok(!ozet.includes('Zayıflama') && !ozet.includes('Süt düşüşü'), ozet);

  await sandbox.openDet('157');
  assert.ok(k.dom.getElementById('det-chips').innerHTML.includes('📌 Topallık'), 'küpeyle açılış');
});

test('HT-UI-14: Geçmiş detay paneli notu gösterir; diğer tipler değişmez', () => {
  const { sandbox } = kur();
  const panel = l => {
    let p = null;
    sandbox._openIslemDetayRow(l, { insertAdjacentElement: (_, e) => { p = e; } });
    return p.innerHTML;
  };
  const html = panel({ id: 'il-1', tip: 'HAYVAN_TAKIP_MUAYENE', ref_tablo: 'hayvan_takip', ref_id: 't1', snapshot: { sebep_kodu: 'TOPALLIK', sonuc: 'SURSUN' }, kullanici_notu: XSS });
  assert.ok(html.includes('Topallık') && html.includes('Takip sürsün'), html);
  assert.ok(html.includes(XSS_KACISLI) && !html.includes('<img'), html);
  assert.ok(!html.includes('Detay yok'), html);
  assert.ok(!html.includes('dg-det-geri-al'), 'R6: geri al yok');
  assert.ok(panel({ id: 'il-2', tip: 'BILINMEYEN_TIPI' }).includes('Detay yok'));
});

test('HT-UI-15: Geçmiş kartı not alt satırı kaçışlı, arama metnine girer; başka tipin notu girmez', () => {
  const { sandbox } = kur({ veri: { hayvanlar: [hayvan()] } });
  const giris = (tip, ek = {}) => ({ type: 'islem', eventAt: '2026-10-31', data: { id: 'il-1', tip, hayvan_id: 'H1', snapshot: { sebep_kodu: 'TOPALLIK' }, kullanici_notu: `Tırnak ${XSS}`, ...ek } });
  for (const tip of ['HAYVAN_TAKIP_ACILDI', 'HAYVAN_TAKIP_KAPANDI', 'HAYVAN_TAKIP_MUAYENE']) {
    const html = sandbox._gecmisEntryHtml(giris(tip));
    assert.ok(html.includes(`Topallık · Tırnak ${XSS_KACISLI}`), html);
    assert.ok(!html.includes('<img'), html);
    assert.ok(sandbox._gecmisSearchText(giris(tip)).includes('topallık'), tip);
    assert.ok(sandbox._gecmisSearchText(giris(tip)).includes('tırnak'), tip);
  }
  assert.ok(!sandbox._gecmisEntryHtml(giris('ASI_KAYDI', { snapshot: { vaccine_name: 'Aşı X' } })).includes('Tırnak'));
  assert.ok(!sandbox._gecmisSearchText(giris('ASI_KAYDI')).includes('tırnak'));
  assert.ok(sandbox._gecmisEntryHtml(giris('HAYVAN_EKLE', { snapshot: { irk: 'Holstein' } })).includes('Holstein'), 'başka tipin alt satırı değişmez');
});

test('HT-UI-16: loadAnimals yalnız açık takiplerden rozet haritası kurar', async () => {
  const k = kur({
    veri: {
      hayvanlar: [hayvan()],
      hayvan_takip: [takip('t1'), takip('t2', { sebep_kodu: 'ZAYIFLAMA', kapanis_tarihi: '2026-10-25T08:00:00Z' })],
    },
  });
  k.sandbox.renderAnimals = () => {};
  await k.sandbox.loadAnimals();
  const tag = k.sandbox._animalTagsHtml(hayvan(), new Set());
  assert.ok(tag.includes('📌 Topallık'), tag);
  assert.ok(!tag.includes('Zayıflama'), tag);
});

test('HT-UI-17: loadDash açık takipleri banda taşır, kapalı ve çıkmış hayvan girmez', async () => {
  const k = kur({
    veri: {
      hayvanlar: [hayvan(), hayvan({ id: 'H3', kupe_no: '300', durum: 'Satıldı' })],
      hayvan_takip: [
        takip('t1'),
        takip('t2', { sebep_kodu: 'ZAYIFLAMA', kapanis_tarihi: '2026-10-25T08:00:00Z' }),
        takip('t3', { hayvan_id: 'H3', sebep_kodu: 'SUT_DUSUSU' }),
      ],
    },
  });
  k.sandbox.suttenKesmeEsigi = () => 60;
  k.sandbox.suttenKesimeHazirSec = () => [];
  await k.sandbox.loadDash();
  const h = k.dom.getElementById('dash-body').innerHTML;
  assert.ok(h.includes('📌 Takipteki hayvanlar (1)'), h);
  assert.ok(h.includes('Topallık'), h);
  assert.ok(!h.includes('Zayıflama') && !h.includes('Süt düşüşü'), h);
});

test('HT-UI-18: çakışan iki loadAnimals tek rozet bırakır, yükleme sırasında harita boşalmaz', async () => {
  const k = kur({ veri: { hayvanlar: [hayvan()], hayvan_takip: [takip('t1')] } });
  const { sandbox } = k;
  sandbox.renderAnimals = () => {};
  const rozet = () => say(sandbox._animalTagsHtml(hayvan(), new Set()), '📌');
  await sandbox.loadAnimals();
  assert.strictEqual(rozet(), 1, 'ilk yükleme');

  // Her iki yükleme de hayvan_takip okumasında bekler; ikisi de oradayken kapı açılır.
  const gercekGetData = sandbox.getData;
  const kapilar = [];
  sandbox.getData = (t, pred) => (t === 'hayvan_takip'
    ? new Promise(ac => kapilar.push(() => ac(gercekGetData(t, pred))))
    : gercekGetData(t, pred));
  const yuklemeler = [sandbox.loadAnimals(), sandbox.loadAnimals()];
  while (kapilar.length < 2) await new Promise(c => setImmediate(c));
  assert.strictEqual(rozet(), 1, 'yükleme sürerken eski harita görünür kalır');

  kapilar.forEach(ac => ac());
  await Promise.all(yuklemeler);
  assert.strictEqual(rozet(), 1, 'çakışan yüklemeler çift rozet üretmez');
});
