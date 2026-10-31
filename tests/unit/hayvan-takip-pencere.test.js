// tests/unit/hayvan-takip-pencere.test.js — Hayvan Takip F2: dört pencere ve index.html bağlantısı.
// F1 yardımcıları gerçektir (js/hayvan-takip.js); yalnız DOM, rpc, pull ve ekran yükleyicileri sahtedir.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadBrowserModule, loadExtractedFunction, makeElement } = require('./support/loadModule.js');
const { fmtTarih, getDisplayKupe, kuceDogalKarsilastir } = require('../../js/utils/helpers.js');

const REPO_ROOT = path.join(__dirname, '..', '..');
const oku = yol => fs.readFileSync(path.join(REPO_ROOT, yol), 'utf8');
const escMirror = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = s => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const duz = v => JSON.parse(JSON.stringify(v));
const BUGUN = '2026-10-31';
const TABLOLAR = ['hayvan_takip', 'gorev_log', 'islem_log'];
const TARIH_MODAL = { 'm-ht-ac': 'ht-ac-tarih', 'm-ht-muayene': 'ht-mu-tarih', 'm-ht-sonuc': 'ht-so-tarih' };

const takip = (id, ek = {}) => ({ id, hayvan_id: 'H1', sebep_kodu: 'TOPALLIK', aciklama: null, acilis_tarihi: '2026-10-20T08:00:00Z', kapanis_tarihi: null, ...ek });
const gorev = (id, ek = {}) => ({ id, hayvan_id: 'H1', gorev_tipi: 'HAYVAN_TAKIP_MUAYENE', ref_takip_id: 't1', aciklama: 'Topallık takibi muayenesi', tamamlandi: false, iptal: false, ...ek });

// innerHTML'e yazılan checkbox'ları gerçek tarayıcı gibi querySelectorAll ile geri veren eleman.
function eleman(id) {
  const e = makeElement('div');
  e.id = id;
  let html = '';
  let kutular = [];
  Object.defineProperty(e, 'innerHTML', {
    get: () => html,
    set: v => {
      html = v;
      kutular = [...String(v).matchAll(/<input[^>]*type="checkbox"[^>]*>/g)].map(m => ({
        value: /value="([^"]*)"/.exec(m[0])[1],
        checked: /\schecked\b/.test(m[0]),
      }));
    },
  });
  e.querySelectorAll = sel => (sel === 'button' ? e.dugmeler || [] : kutular);
  return e;
}

function f1() {
  const c = loadBrowserModule('js/config.js', { expose: ['HAYVAN_TAKIP_GOREV_TIPI', 'HAYVAN_TAKIP_SEBEPLER'] }).exposed;
  const y = loadBrowserModule('js/hayvan-takip.js', {
    expose: ['HT_HATA_METINLERI'],
    extra: {
      HAYVAN_TAKIP_SEBEPLER: c.HAYVAN_TAKIP_SEBEPLER,
      HAYVAN_TAKIP_GOREV_TIPI: c.HAYVAN_TAKIP_GOREV_TIPI,
      _istanbulGunNo: loadExtractedFunction('js/utils/helpers.js', '_istanbulGunNo'),
      band: (s, b, g) => `${s}|${b}|${g}`,
      esc: escMirror,
      escAttr: escAttrMirror,
      fmtTarih,
      getDisplayKupe,
      kuceDogalKarsilastir,
      getUserMessage: e => 'JENERIK:' + (e?.message || String(e)),
    },
  });
  const s = y.sandbox;
  return {
    HAYVAN_TAKIP_SEBEPLER: c.HAYVAN_TAKIP_SEBEPLER,
    HT_HATA_METINLERI: y.exposed.HT_HATA_METINLERI,
    htAcikTakipler: s.htAcikTakipler,
    htSebepEtiket: s.htSebepEtiket,
    htGunSayisi: s.htGunSayisi,
    htKapatOnSecim: s.htKapatOnSecim,
    htVarsayilanSonrakiTarih: s.htVarsayilanSonrakiTarih,
    htHataMetni: s.htHataMetni,
    htAktifVakaHtml: s.htAktifVakaHtml,
  };
}

function kur(o = {}) {
  const els = new Map();
  const g = id => { if (!els.has(id)) els.set(id, eleman(id)); return els.get(id); };
  const k = {
    g, els,
    rpcler: [], toastlar: [], pulllar: [], acilan: [], kapanan: [], olay: [], sira: [],
    yuklenenGorev: [], dash: 0, openDet: 0, onLine: o.onLine !== false,
    idb: { hayvan_takip: o.takipler || [], gorev_log: o.gorevler || [], cases: o.vakalar || [], diseases: o.hastaliklar || [] },
    sayfa: o.sayfa || 'dash',
  };
  const openMAyna = id => {
    k.acilan.push(id);
    const t = TARIH_MODAL[id];
    if (t && !g(t).value) g(t).value = BUGUN; // utils/modal.js:26 davranışı
  };
  const openMGercek = () => {
    Object.entries(TARIH_MODAL).forEach(([m, t]) => { g(m).querySelectorAll = () => [g(t)]; });
    const { sandbox } = loadBrowserModule('js/utils/modal.js', { extra: { g, bugun: () => BUGUN } });
    return id => { k.acilan.push(id); sandbox.openM(id); };
  };
  const yuklu = loadBrowserModule('js/hayvan-takip-pencere.js', {
    extra: {
      ...f1(),
      g,
      cl: id => { g(id).value = ''; },
      esc: escMirror,
      escAttr: escAttrMirror,
      getDisplayKupe,
      bugun: () => BUGUN,
      navigator: { get onLine() { return k.onLine; } },
      toast: (m, e) => { k.toastlar.push({ m, e: !!e }); },
      rpc: async (ad, p) => {
        k.rpcler.push({ ad, p: duz(p) });
        if (o.rpc) return o.rpc(ad, p);
        return { ok: true, kapanan: 1 };
      },
      pullTables: async t => {
        k.pulllar.push([...t]);
        k.olay.push('pull');
        k.sira.push('pull');
        if (o.pull) return o.pull(t);
        return { ok: [...t], failed: [] };
      },
      idbGetAll: async t => { if (o.idb) return o.idb(t, k); return k.idb[t] || []; },
      getState: a => (a === 'animals' ? [{ id: 'H1', kupe_no: 'K-1' }] : a === 'currentPage' ? k.sayfa : undefined),
      loadDash: async () => { k.dash++; k.olay.push('dash'); k.sira.push('dash'); },
      loadTasks: async f => { k.yuklenenGorev.push(f); k.olay.push('tasks'); },
      openDet: () => { k.openDet++; },
      openM: o.gercekOpenM ? openMGercek() : openMAyna,
      closeM: id => { k.kapanan.push(id); k.sira.push('closeM:' + id); },
      openMWithHayvan: (...a) => { k.sira.push(['openMWithHayvan', ...a]); },
      _htVakaSonrasiGuvenli: async (...a) => { k.sira.push(['soru', ...a]); },
      _curTaskFilter: 'today',
    },
  });
  k.s = yuklu.sandbox;
  return k;
}

const btn = (ek = {}) => { const b = makeElement('button'); b.textContent = 'Kaydet'; Object.assign(b.dataset, ek); return b; };
const son = k => k.toastlar[k.toastlar.length - 1]?.m || '';

function hazirAc(k, sebep = 'TOPALLIK', aciklama = '') {
  k.s.htAcPencere('H1');
  k.g('ht-ac-sebep').value = sebep;
  k.g('ht-ac-aciklama').value = aciklama;
}

const BIR = () => [takip('t1')];
const IKI = () => [takip('t1'), takip('t2', { sebep_kodu: 'ZAYIFLAMA', acilis_tarihi: '2026-10-10T08:00:00Z' })];

// ── Çevrimdışı ───────────────────────────────────────────────
test('HT-P-01: çevrimdışıyken dört gönderim rpc çağırmaz, toast İnternet', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')] });
  hazirAc(k);
  await k.s.htMuayenePencere('H1');
  k.g('ht-mu-tarih').value = BUGUN;
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  await k.s.htSonucAc('g1');
  k.onLine = false;
  for (const [fn, b] of [['htAcGonder', btn()], ['htMuayeneGonder', btn()], ['htKapatGonder', btn()], ['htSonucGonder', btn({ sonuc: 'KAPANSIN' })]]) {
    k.toastlar.length = 0;
    await k.s[fn](b);
    assert.match(son(k), /İnternet/, fn);
    assert.strictEqual(k.toastlar[0].e, true, fn + ' hata toast');
  }
  assert.strictEqual(k.rpcler.length, 0);
});

// ── Takibe al ────────────────────────────────────────────────
test('HT-P-02: DIGER boş açıklama rpc çağırmaz; boşluk da boştur', async () => {
  const k = kur();
  hazirAc(k, 'DIGER', '   ');
  await k.s.htAcGonder(btn());
  assert.strictEqual(k.rpcler.length, 0);
  assert.match(son(k), /açıklama gerekli/);
  assert.deepStrictEqual(k.kapanan, []);
});

test('HT-P-02b: sebep seçilmeden rpc çağrılmaz; DIGER dışı açıklamasız geçer', async () => {
  const k = kur();
  hazirAc(k, '');
  await k.s.htAcGonder(btn());
  assert.strictEqual(k.rpcler.length, 0);
  assert.match(son(k), /Sebep seçilmedi/);
  hazirAc(k, 'ZAYIFLAMA', '');
  await k.s.htAcGonder(btn());
  assert.strictEqual(k.rpcler.length, 1);
});

test('HT-P-03: htAcGonder parametreleri tam; boşlar null, dolular geçer', async () => {
  const k = kur();
  hazirAc(k, 'TOPALLIK', '');
  await k.s.htAcGonder(btn());
  assert.deepStrictEqual(k.rpcler[0], {
    ad: 'hayvan_takip_ac',
    p: { p_hayvan_id: 'H1', p_sebep_kodu: 'TOPALLIK', p_aciklama: null, p_muayene_tarihi: null, p_muayene_saati: null },
  });
  hazirAc(k, 'DIGER', ' kulak şişliği ');
  k.g('ht-ac-tarih').value = '2026-11-01';
  k.g('ht-ac-saat').value = '08:30';
  await k.s.htAcGonder(btn());
  assert.deepStrictEqual(k.rpcler[1].p, { p_hayvan_id: 'H1', p_sebep_kodu: 'DIGER', p_aciklama: 'kulak şişliği', p_muayene_tarihi: '2026-11-01', p_muayene_saati: '08:30' });
});

test('HT-P-03b: başarıda pencere kapanır, üç tablo çekilir, dashboard yüklenir; görev sekmesi yoksa loadTasks yok', async () => {
  const k = kur();
  hazirAc(k);
  await k.s.htAcGonder(btn());
  assert.deepStrictEqual(k.kapanan, ['m-ht-ac']);
  assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
  assert.deepStrictEqual(k.olay, ['pull', 'dash']);
  assert.deepStrictEqual(k.yuklenenGorev, []);
  assert.strictEqual(k.openDet, 0, 'kart tazelemesi yalnız pullTables yoluyla');
});

test('HT-P-03c: görev sekmesi açıkken başarı loadTasks çağırır (geçerli süzgeç)', async () => {
  const k = kur({ sayfa: 'tasks' });
  hazirAc(k);
  await k.s.htAcGonder(btn());
  assert.deepStrictEqual(k.olay, ['pull', 'dash', 'tasks']);
  assert.deepStrictEqual(k.yuklenenGorev, ['today']);
});

test('HT-P-03d: gönderim süresince düğme kilitli, bitince eski metne döner', async () => {
  let cozum;
  const k = kur({ rpc: () => new Promise(r => { cozum = r; }) });
  hazirAc(k);
  const b = btn();
  const p = k.s.htAcGonder(b);
  await new Promise(r => setImmediate(r));
  assert.strictEqual(b.disabled, true);
  cozum({ ok: true });
  await p;
  assert.strictEqual(b.disabled, false);
  assert.strictEqual(b.textContent, 'Kaydet');
});

test('HT-P-04: HT_SEBEP_ZATEN_ACIK toast verir, pencere açık kalır, düğme açılır', async () => {
  const k = kur({ rpc: () => { throw new Error('HT_SEBEP_ZATEN_ACIK'); } });
  hazirAc(k);
  const b = btn();
  await k.s.htAcGonder(b);
  assert.match(son(k), /Bu sebeple zaten takipte/);
  assert.deepStrictEqual(k.kapanan, []);
  assert.deepStrictEqual(k.pulllar, []);
  assert.strictEqual(b.disabled, false);
});

// ── Muayene planla ───────────────────────────────────────────
test('HT-P-05: çok takipte seçici görünür ve boş; seçimsiz gönderim yok', async () => {
  const k = kur({ takipler: IKI() });
  await k.s.htMuayenePencere('H1');
  assert.notStrictEqual(k.g('ht-mu-secici').style.display, 'none');
  assert.strictEqual(k.g('ht-mu-takip').value, '');
  assert.deepStrictEqual(k.acilan, ['m-ht-muayene']);
  k.g('ht-mu-tarih').value = BUGUN;
  await k.s.htMuayeneGonder(btn());
  assert.strictEqual(k.rpcler.length, 0);
  assert.match(son(k), /Takip seçin/);
});

test('HT-P-05b: tek takipte seçici gizli, takip seçili; parametreler tam', async () => {
  const k = kur({ takipler: BIR() });
  await k.s.htMuayenePencere('H1');
  assert.strictEqual(k.g('ht-mu-secici').style.display, 'none');
  assert.strictEqual(k.g('ht-mu-takip').value, 't1');
  k.g('ht-mu-tarih').value = '2026-11-02';
  await k.s.htMuayeneGonder(btn());
  assert.deepStrictEqual(k.rpcler[0], { ad: 'hayvan_takip_muayene_planla', p: { p_takip_id: 't1', p_tarih: '2026-11-02', p_saat: null } });
  assert.deepStrictEqual(k.kapanan, ['m-ht-muayene']);
});

test('HT-P-05c: tarih boşken gönderim yok; açık takip yoksa pencere açılmaz; başka hayvan ve kapalı sayılmaz', async () => {
  const k = kur({ takipler: [takip('t1'), takip('x', { hayvan_id: 'H2' }), takip('y', { kapanis_tarihi: '2026-10-21T00:00:00Z' })] });
  await k.s.htMuayenePencere('H1');
  assert.strictEqual(k.g('ht-mu-takip').value, 't1');
  assert.strictEqual(k.g('ht-mu-secici').style.display, 'none');
  await k.s.htMuayeneGonder(btn());
  assert.strictEqual(k.rpcler.length, 0);
  assert.match(son(k), /Muayene tarihi gerekli/);
  const bos = kur({ takipler: [takip('x', { hayvan_id: 'H2' })] });
  await bos.s.htMuayenePencere('H1');
  assert.deepStrictEqual(bos.acilan, []);
  assert.match(son(bos), /Açık takip yok/);
});

// ── Takibi kapat ─────────────────────────────────────────────
const kutular = k => k.g('ht-ka-liste').querySelectorAll('input[type=checkbox]');

test('HT-P-06: vaka bağlamı hiçbiri işaretli değil, Açık kalsın görünür', async () => {
  const k = kur({ takipler: BIR() });
  await k.s.htKapatPencere('H1', { baglam: 'vaka', caseId: 'c1' });
  assert.deepStrictEqual(kutular(k).map(x => x.checked), [false]);
  assert.notStrictEqual(k.g('ht-ka-acik-kalsin').style.display, 'none');
  assert.deepStrictEqual(k.acilan, ['m-ht-kapat']);
});

test('HT-P-06b: kart bağlamı Açık kalsın gizli; tek takip işaretli, çok takipte hiçbiri', async () => {
  const k = kur({ takipler: BIR() });
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  assert.strictEqual(k.g('ht-ka-acik-kalsin').style.display, 'none');
  assert.deepStrictEqual(kutular(k).map(x => [x.value, x.checked]), [['t1', true]]);
  const c = kur({ takipler: IKI() });
  await c.s.htKapatPencere('H1', { baglam: 'kart' });
  assert.deepStrictEqual(kutular(c).map(x => x.checked), [false, false]);
});

test('HT-P-06c: liste en eski takip önce; süre satırda; htAcikKalsin yalnız kapat penceresini kapatır, rpc yok', async () => {
  const k = kur({ takipler: IKI() });
  await k.s.htKapatPencere('H1', { baglam: 'vaka', caseId: 'c1' });
  assert.deepStrictEqual(kutular(k).map(x => x.value), ['t2', 't1']);
  assert.match(k.g('ht-ka-liste').innerHTML, /Zayıflama · \d+ gün/);
  const b = kur({ takipler: [takip('t9', { acilis_tarihi: new Date(Date.now() - 5 * 86400000).toISOString() })] });
  await b.s.htKapatPencere('H1', { baglam: 'kart' });
  assert.match(b.g('ht-ka-liste').innerHTML, /Topallık · 5 gün/);
  k.s.htAcikKalsin();
  assert.deepStrictEqual(k.kapanan, ['m-ht-kapat']);
  assert.strictEqual(k.rpcler.length, 0);
});

test('HT-P-07: Tümünü seç hepsini işaretler; seçimsiz gönderim rpc çağırmaz', async () => {
  const k = kur({ takipler: IKI() });
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  await k.s.htKapatGonder(btn());
  assert.strictEqual(k.rpcler.length, 0);
  assert.match(son(k), /seçilmedi/);
  k.s.htTumunuSec();
  assert.deepStrictEqual(kutular(k).map(x => x.checked), [true, true]);
  await k.s.htKapatGonder(btn());
  assert.deepStrictEqual(k.rpcler[0].p.p_takip_ids, ['t2', 't1']);
});

test('HT-P-08: vaka bağlamı p_kapatan_vaka_id=caseId; not geçer', async () => {
  const k = kur({ takipler: BIR() });
  await k.s.htKapatPencere('H1', { baglam: 'vaka', caseId: 'c1' });
  kutular(k)[0].checked = true;
  k.g('ht-ka-not').value = ' iyileşti ';
  await k.s.htKapatGonder(btn());
  assert.deepStrictEqual(k.rpcler[0], { ad: 'hayvan_takip_kapat', p: { p_takip_ids: ['t1'], p_not: 'iyileşti', p_kapatan_vaka_id: 'c1' } });
  assert.deepStrictEqual(k.kapanan, ['m-ht-kapat'], 'vaka detayı kapanmaz');
});

test('HT-P-08b: kart bağlamı null; vaka sonrası açılan kart penceresi eski caseId taşımaz', async () => {
  const k = kur({ takipler: BIR() });
  await k.s.htKapatPencere('H1', { baglam: 'vaka', caseId: 'c1' });
  await k.s.htKapatPencere('H1', { baglam: 'kart', caseId: 'c1' });
  await k.s.htKapatGonder(btn());
  assert.deepStrictEqual(k.rpcler[0].p, { p_takip_ids: ['t1'], p_not: null, p_kapatan_vaka_id: null });
});

test('HT-P-08c: kapanan=1 başarı toast verir, liste tazelenir', async () => {
  const k = kur({ takipler: BIR(), rpc: () => ({ ok: true, kapanan: 1 }) });
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  await k.s.htKapatGonder(btn());
  assert.match(son(k), /1 takip kapatıldı/);
  assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
});

test('HT-P-14b: kapanan=0 (başkası kapatmış) toast yok, pencere kapanır, tazeleme var', async () => {
  const k = kur({ takipler: BIR(), rpc: () => ({ ok: true, kapanan: 0 }) });
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  await k.s.htKapatGonder(btn());
  assert.strictEqual(k.toastlar.length, 0);
  assert.deepStrictEqual(k.kapanan, ['m-ht-kapat']);
  assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
  assert.strictEqual(k.dash, 1);
});

test('HT-P-15: vaka bağlamı RPC hatası uyarı verir; vaka detayı ve pencere durur, rpc tek', async () => {
  const k = kur({ takipler: BIR(), rpc: () => { throw new Error('HT_VAKA_UYUMSUZ'); } });
  await k.s.htKapatPencere('H1', { baglam: 'vaka', caseId: 'c1' });
  await k.s.htTumunuSec();
  await k.s.htKapatGonder(btn());
  assert.match(son(k), /Vaka kayıtlı/);
  assert.match(son(k), /Vaka bu hayvana ait değil/);
  assert.strictEqual(k.toastlar[0].e, true);
  assert.ok(!k.kapanan.includes('m-case-det'));
  assert.deepStrictEqual(k.kapanan, [], 'yeniden denenebilir');
  assert.deepStrictEqual(k.rpcler.map(r => r.ad), ['hayvan_takip_kapat'], 'vaka yazma yok');
});

test('HT-P-15b: kart bağlamı aynı hatada Vaka kayıtlı demez', async () => {
  const k = kur({ takipler: BIR(), rpc: () => { throw new Error('HT_FARKLI_HAYVAN'); } });
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  await k.s.htKapatGonder(btn());
  assert.ok(!/Vaka/.test(son(k)));
});

// ── Muayene sonucu ───────────────────────────────────────────
test('HT-P-09: htSonucAc sonraki tarih +3 dolu, true döner, pencere açılır', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')] });
  assert.strictEqual(await k.s.htSonucAc('g1'), true);
  assert.strictEqual(k.g('ht-so-tarih').value, '2026-11-03');
  assert.deepStrictEqual(k.acilan, ['m-ht-sonuc']);
  assert.match(k.g('ht-so-bilgi').textContent, /Topallık/);
});

test('HT-P-09b: kapalı ya da iptal ya da bulunmayan görevde false + toast + pull, pencere yok', async () => {
  for (const liste of [[gorev('g1', { tamamlandi: true })], [gorev('g1', { iptal: true })], []]) {
    const k = kur({ gorevler: liste });
    assert.strictEqual(await k.s.htSonucAc('g1'), false);
    assert.match(son(k), /kapanmış/);
    assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
    assert.deepStrictEqual(k.acilan, []);
  }
});

test('HT-P-09c: çevrimdışı false + toast, pull yok', async () => {
  const k = kur({ onLine: false, gorevler: [gorev('g1')] });
  assert.strictEqual(await k.s.htSonucAc('g1'), false);
  assert.match(son(k), /İnternet/);
  assert.deepStrictEqual(k.pulllar, []);
  assert.deepStrictEqual(k.acilan, []);
});

test('HT-P-09d: DIGER takibinde pencere sebep olarak açıklamayı gösterir (R12)', async () => {
  const k = kur({ takipler: [takip('t1', { sebep_kodu: 'DIGER', aciklama: 'kulak şişliği' })], gorevler: [gorev('g1', { aciklama: 'Diğer takibi muayenesi' })] });
  await k.s.htSonucAc('g1');
  assert.match(k.g('ht-so-bilgi').textContent, /kulak şişliği/);
});

test('HT-P-10: SURSUN boş tarih p_sonraki_tarih:null gönderir', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')] });
  await k.s.htSonucAc('g1');
  k.g('ht-so-tarih').value = '';
  await k.s.htSonucGonder(btn({ sonuc: 'SURSUN' }));
  assert.deepStrictEqual(k.rpcler[0], { ad: 'hayvan_takip_muayene_sonuc', p: { p_gorev_id: 'g1', p_sonuc: 'SURSUN', p_not: null, p_sonraki_tarih: null, p_sonraki_saat: null } });
  assert.deepStrictEqual(k.kapanan, ['m-ht-sonuc']);
  assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
});

test('HT-P-10b: SURSUN dolu tarih ve saat geçer; KAPANSIN tarih ve saat göndermez, not geçer', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')] });
  await k.s.htSonucAc('g1');
  k.g('ht-so-saat').value = '09:15';
  k.g('ht-so-not').value = ' daha iyi ';
  await k.s.htSonucGonder(btn({ sonuc: 'SURSUN' }));
  assert.deepStrictEqual(k.rpcler[0].p, { p_gorev_id: 'g1', p_sonuc: 'SURSUN', p_not: 'daha iyi', p_sonraki_tarih: '2026-11-03', p_sonraki_saat: '09:15' });
  await k.s.htSonucAc('g1');
  assert.strictEqual(k.g('ht-so-saat').value, '', 'açılışta eski saat kalmaz');
  assert.strictEqual(k.g('ht-so-not').value, '', 'açılışta eski not kalmaz');
  k.g('ht-so-not').value = 'iyileşti';
  await k.s.htSonucGonder(btn({ sonuc: 'KAPANSIN' }));
  assert.deepStrictEqual(k.rpcler[1].p, { p_gorev_id: 'g1', p_sonuc: 'KAPANSIN', p_not: 'iyileşti' });
});

test('HT-P-10c: HT_TAKIP_KAPALI toast + tazeleme, pencere kapanır', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], rpc: () => { throw new Error('HT_TAKIP_KAPALI'); } });
  await k.s.htSonucAc('g1');
  await k.s.htSonucGonder(btn({ sonuc: 'SURSUN' }));
  assert.match(son(k), /Bu takip kapanmış/);
  assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
  assert.deepStrictEqual(k.kapanan, ['m-ht-sonuc']);
});

test('HT-P-10d: HT_GOREV_KAPALI ve HT_GECMIS_TARIH ayrımı: ilki tazeler, ikincisi formda kalır', async () => {
  const a = kur({ gorevler: [gorev('g1')], rpc: () => { throw new Error('HT_GOREV_KAPALI'); } });
  await a.s.htSonucAc('g1');
  await a.s.htSonucGonder(btn({ sonuc: 'KAPANSIN' }));
  assert.deepStrictEqual(a.pulllar, [TABLOLAR]);
  const b = kur({ gorevler: [gorev('g1')], rpc: () => { throw new Error('HT_GECMIS_TARIH'); } });
  await b.s.htSonucAc('g1');
  await b.s.htSonucGonder(btn({ sonuc: 'SURSUN' }));
  assert.match(son(b), /geçmişte olamaz/);
  assert.deepStrictEqual(b.pulllar, []);
  assert.deepStrictEqual(b.kapanan, []);
});

// ── Muayeneden vakaya bağ ────────────────────────────────────
const dokun = () => new Promise(r => setImmediate(r));
const vaka = (id, ek = {}) => ({ id, animal_id: 'H1', disease_id: 'd1', status: 'active', start_date: '2026-10-20', ...ek });
const HASTALIK = [{ id: 'd1', name: 'Mastitis' }, { id: 'd2', name: 'Metrit' }];
const satirKimlik = k => [...k.g('ht-so-vakalar').innerHTML.matchAll(/data-case-id="([^"]*)"/g)].map(m => m[1]);

test('HT-P-30: Vaka aç bağlamı yazar, kızgınlık işaretini siler, önce sonuç penceresi kapanır, sonra vaka formu açılır; yazma yok', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')] });
  await k.s.htSonucAc('g1');
  k.s._kizginlikTedaviId = 'K-1';
  k.g('ht-so-not').value = ' şişlik ';
  k.sira.length = 0;
  k.s.htSonucVakaAc();
  assert.deepStrictEqual(duz(k.s._htMuayeneVaka), { gorevId: 'g1', hayvanId: 'H1', not: 'şişlik' });
  assert.strictEqual(k.s._kizginlikTedaviId, null);
  assert.deepStrictEqual(duz(k.sira), ['closeM:m-ht-sonuc', ['openMWithHayvan', 'm-disease', 'd-hid', 'K-1']]);
  assert.deepStrictEqual(k.rpcler, []);
  k.g('ht-so-not').value = '   ';
  k.s.htSonucVakaAc();
  assert.strictEqual(k.s._htMuayeneVaka.not, null, 'boş not null');
});

test('HT-P-31: yalnız hayvanın aktif vakaları listelenir, aynı hastalıkla sınırlı değil; satırda hastalık ve tarih', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], hastaliklar: HASTALIK, vakalar: [
    vaka('c1'), vaka('c2', { disease_id: 'd2', start_date: '2026-10-25' }), vaka('c3', { status: 'closed' }), vaka('c4', { animal_id: 'H2' }),
  ] });
  await k.s.htSonucAc('g1');
  await dokun();
  assert.deepStrictEqual(satirKimlik(k), ['c2', 'c1']);
  assert.strictEqual(k.g('ht-so-vakalar').style.display, '');
  const html = k.g('ht-so-vakalar').innerHTML;
  assert.match(html, /Metrit · 25\.10\.2026/);
  assert.match(html, /Mastitis · 20\.10\.2026/);
  assert.strictEqual((html.match(/Bu vakaya bağla/g) || []).length, 2);
});

test('HT-P-32: aktif vaka yoksa bölüm görünmez; önceki açılışın satırı kalmaz', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], hastaliklar: HASTALIK, vakalar: [vaka('c1')] });
  await k.s.htSonucAc('g1');
  await dokun();
  assert.deepStrictEqual(satirKimlik(k), ['c1']);
  k.idb.cases = [vaka('c1', { status: 'closed' })];
  await k.s.htSonucAc('g1');
  assert.strictEqual(k.g('ht-so-vakalar').style.display, 'none', 'okuma bitmeden eski satır görünmez');
  await dokun();
  assert.strictEqual(k.g('ht-so-vakalar').style.display, 'none');
  assert.strictEqual(k.g('ht-so-vakalar').innerHTML, '');
});

test('HT-P-33: liste htSonucAc\'ı bekletmez: okuma bitmese de pencere açık, true döner', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')],
    idb: (t, kk) => (t === 'cases' ? new Promise(() => {}) : kk.idb[t] || []) });
  const zaman = new Promise(r => { setTimeout(r, 200, 'BEKLETTI').unref(); });
  assert.strictEqual(await Promise.race([k.s.htSonucAc('g1'), zaman]), true);
  assert.deepStrictEqual(k.acilan, ['m-ht-sonuc']);
  assert.strictEqual(k.g('ht-so-vakalar').style.display, 'none');
});

test('HT-P-34: vaka okunamazsa bölüm görünmez, hata toast\'u yok, pencere açık kalır', async () => {
  for (const tablo of ['cases', 'diseases']) {
    const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], vakalar: [vaka('c1')],
      idb: async (t, kk) => { if (t === tablo) throw new Error('idb'); return kk.idb[t] || []; } });
    assert.strictEqual(await k.s.htSonucAc('g1'), true);
    await dokun();
    assert.strictEqual(k.g('ht-so-vakalar').style.display, 'none', tablo);
    assert.deepStrictEqual(k.toastlar, [], tablo);
  }
});

test('HT-P-35: geç gelen liste başka göreve açılmış pencereye yazılmaz', async () => {
  let bitir;
  const bekle = new Promise(r => { bitir = r; });
  let ilk = true;
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1'), gorev('g2')], vakalar: [vaka('c1')],
    idb: async (t, kk) => { if (t === 'cases' && ilk) { ilk = false; await bekle; return [vaka('eski')]; } return kk.idb[t] || []; } });
  await k.s.htSonucAc('g1');
  await k.s.htSonucAc('g2');
  await dokun();
  assert.deepStrictEqual(satirKimlik(k), ['c1']);
  bitir();
  await dokun();
  assert.deepStrictEqual(satirKimlik(k), ['c1'], 'eski satır ezmez');
});

test('HT-P-36: mevcut vakaya bağ yalnız RPC; pencere kapanır, kalan takipler sorulur, liste tazelenir; vaka açılmaz', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], vakalar: [vaka('c1')] });
  await k.s.htSonucAc('g1');
  k.g('ht-so-not').value = ' tedavide ';
  k.sira.length = 0;
  await k.s.htVakaBagla(btn({ caseId: 'c1' }));
  assert.deepStrictEqual(k.rpcler, [{ ad: 'hayvan_takip_muayene_vaka', p: { p_gorev_id: 'g1', p_case_id: 'c1', p_not: 'tedavide' } }]);
  assert.deepStrictEqual(duz(k.sira), ['closeM:m-ht-sonuc', ['soru', 'H1', 'c1'], 'pull', 'dash']);
  assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
  assert.ok(k.toastlar.every(t => !t.e));
  assert.match(son(k), /Vakaya bağlandı/i);
  k.g('ht-so-not').value = '';
  await k.s.htVakaBagla(btn({ caseId: 'c1' }));
  assert.strictEqual(k.rpcler[1].p.p_not, null);
});

test('HT-P-37: mevcut vakaya bağ çevrimdışıyken RPC çağırmaz', async () => {
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')] });
  await k.s.htSonucAc('g1');
  k.onLine = false;
  await k.s.htVakaBagla(btn({ caseId: 'c1' }));
  assert.deepStrictEqual(k.rpcler, []);
  assert.match(son(k), /İnternet/);
  assert.deepStrictEqual(k.kapanan, []);
});

test('HT-P-38: bağ hatasında soru sorulmaz; uyumsuz vakada pencere açık, bayat kapalıda kapanıp tazeler', async () => {
  for (const [hata, kapanir, metin] of [['HT_VAKA_UYUMSUZ', false, /ait değil ya da kapanmış/], ['BAGLANTI', false, /JENERIK:BAGLANTI/], ['HT_GOREV_KAPALI', true, /görevi kapanmış/], ['HT_TAKIP_KAPALI', true, /takip kapanmış/]]) {
    const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], rpc: () => { throw new Error(hata); } });
    await k.s.htSonucAc('g1');
    await k.s.htVakaBagla(btn({ caseId: 'c1' }));
    assert.ok(!k.sira.some(o => o[0] === 'soru'), hata);
    assert.match(son(k), metin, hata);
    assert.deepStrictEqual(k.kapanan, kapanir ? ['m-ht-sonuc'] : [], hata);
    assert.deepStrictEqual(k.pulllar, kapanir ? [TABLOLAR] : [], hata);
  }
});

test('HT-P-39: bağ yoldayken bütün düğmeler kilitli; bitince açılır, çift gönderim olmaz', async () => {
  let kilitliydi = null;
  const diger = makeElement('button');
  const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], rpc: () => { kilitliydi = diger.disabled; return { ok: true }; } });
  await k.s.htSonucAc('g1');
  k.g('m-ht-sonuc').dugmeler = [diger];
  const b = btn({ caseId: 'c1' });
  await k.s.htVakaBagla(b);
  assert.strictEqual(kilitliydi, true);
  assert.strictEqual(diger.disabled, false);
  assert.strictEqual(b.disabled, false);
});

test('HT-P-40: htMuayeneVakaBagla başarıda tazeler; genel hata metni birebir; bayat kapalı yalnız tazeler; asla fırlatmaz', async () => {
  const bag = { gorevId: 'g1', hayvanId: 'H1', not: 'n' };
  const a = kur();
  await a.s.htMuayeneVakaBagla(bag, 'c1');
  assert.deepStrictEqual(a.rpcler, [{ ad: 'hayvan_takip_muayene_vaka', p: { p_gorev_id: 'g1', p_case_id: 'c1', p_not: 'n' } }]);
  assert.deepStrictEqual(a.pulllar, [TABLOLAR]);
  assert.ok(a.toastlar.every(t => !t.e));

  for (const hata of ['HT_VAKA_UYUMSUZ', 'ag gitti', 'HT_TAKIP_YOK']) {
    const b = kur({ rpc: () => { throw new Error(hata); } });
    await assert.doesNotReject(b.s.htMuayeneVakaBagla(bag, 'c1'));
    assert.deepStrictEqual(b.toastlar, [{ m: '⚠️ Vaka kayıtlı, takip bağlanamadı', e: true }], hata);
    assert.deepStrictEqual(b.pulllar, [], hata);
  }
  for (const hata of ['HT_GOREV_KAPALI', 'HT_TAKIP_KAPALI']) {
    const c = kur({ rpc: () => { throw new Error(hata); } });
    await assert.doesNotReject(c.s.htMuayeneVakaBagla(bag, 'c1'));
    assert.deepStrictEqual(c.toastlar, [], hata);
    assert.deepStrictEqual(c.pulllar, [TABLOLAR], hata);
  }
});

// ── Vaka sonrası ─────────────────────────────────────────────
test('HT-P-11: açık takip yoksa pencere yok; hayvan_takip önce çekilir', async () => {
  const k = kur({ takipler: [takip('x', { hayvan_id: 'H2' })] });
  await k.s.htVakaSonrasi('H1', 'c1');
  assert.deepStrictEqual(k.acilan, []);
  assert.deepStrictEqual(k.pulllar, [['hayvan_takip']]);
  assert.strictEqual(k.toastlar.length, 0);
});

test('HT-P-11b: pullTables reddi dışarı çıkmaz, yalnız uyarı; yerel açık takip sorulur', async () => {
  const k = kur({ takipler: BIR(), pull: () => { throw new Error('ağ'); } });
  await k.s.htVakaSonrasi('H1', 'c1');
  assert.match(son(k), /tazelenemedi/);
  assert.deepStrictEqual(k.acilan, ['m-ht-kapat']);
  assert.ok(!k.kapanan.includes('m-case-det'));
});

test('HT-P-11c: tablo hatası failed listesinde gelirse de uyarı verir; açık takipte vaka bağlamı açılır', async () => {
  const k = kur({ takipler: BIR(), pull: t => ({ ok: [], failed: [...t] }) });
  await k.s.htVakaSonrasi('H1', 'c1');
  assert.match(son(k), /tazelenemedi/);
  assert.deepStrictEqual(kutular(k).map(x => x.checked), [false]);
  await k.s.htTumunuSec();
  await k.s.htKapatGonder(btn());
  assert.strictEqual(k.rpcler[0].p.p_kapatan_vaka_id, 'c1');
});

// ── Spec §6 hata durumları ───────────────────────────────────
test('HT-P-13: çıkmış hayvan toast + hayvanlar dahil tek pull; openDet yok', async () => {
  const k = kur({ rpc: () => { throw new Error('HT_HAYVAN_AKTIF_DEGIL'); } });
  hazirAc(k);
  await k.s.htAcGonder(btn());
  assert.match(son(k), /Hayvan aktif değil/);
  assert.deepStrictEqual(k.pulllar, [['hayvanlar', ...TABLOLAR]]);
  assert.strictEqual(k.openDet, 0);
  assert.deepStrictEqual(k.kapanan, ['m-ht-ac']);
});

test('HT-P-13b: muayene planlamada çıkmış hayvan aynı kol', async () => {
  const k = kur({ takipler: BIR(), rpc: () => { throw new Error('HT_HAYVAN_AKTIF_DEGIL'); } });
  await k.s.htMuayenePencere('H1');
  k.g('ht-mu-tarih').value = BUGUN;
  await k.s.htMuayeneGonder(btn());
  assert.deepStrictEqual(k.pulllar, [['hayvanlar', ...TABLOLAR]]);
  assert.strictEqual(k.openDet, 0);
});

test('HT-P-14: htMuayeneGonder HT_TAKIP_KAPALI toast + liste tazelenir', async () => {
  const k = kur({ takipler: BIR(), rpc: () => { throw new Error('HT_TAKIP_KAPALI'); } });
  await k.s.htMuayenePencere('H1');
  k.g('ht-mu-tarih').value = BUGUN;
  await k.s.htMuayeneGonder(btn());
  assert.match(son(k), /Bu takip kapanmış/);
  assert.deepStrictEqual(k.pulllar, [TABLOLAR]);
  assert.strictEqual(k.dash, 1);
});

test('HT-P-14c: ağ hatası pullTables çözümünde failed döner: uyarı verir, gönderim bozulmaz, dashboard yine yüklenir', async () => {
  const k = kur({ pull: t => ({ ok: [], failed: [...t] }) });
  hazirAc(k);
  await k.s.htAcGonder(btn());
  assert.match(son(k), /tazelenemedi/);
  assert.strictEqual(k.toastlar[k.toastlar.length - 1].e, true);
  assert.deepStrictEqual(k.kapanan, ['m-ht-ac']);
  assert.strictEqual(k.dash, 1);
});

test('HT-P-14d: kısmi failed de uyarır; failed boşsa uyarı yok; tam red de uyarır', async () => {
  const kismi = kur({ pull: () => ({ ok: ['gorev_log', 'islem_log'], failed: ['hayvan_takip'] }) });
  hazirAc(kismi);
  await kismi.s.htAcGonder(btn());
  assert.match(son(kismi), /tazelenemedi/);
  const temiz = kur();
  hazirAc(temiz);
  await temiz.s.htAcGonder(btn());
  assert.ok(!temiz.toastlar.some(t => /tazelenemedi/.test(t.m)));
  const red = kur({ pull: () => { throw new Error('ağ'); } });
  hazirAc(red);
  await red.s.htAcGonder(btn());
  assert.match(son(red), /tazelenemedi/);
  assert.deepStrictEqual(red.kapanan, ['m-ht-ac']);
});

test('HT-P-18: SURSUN yoldayken pencerenin bütün düğmeleri kilitli; KAPANSIN ikinci RPC göndermez, bitince açılır', async () => {
  let cozum;
  const k = kur({ gorevler: [gorev('g1')], rpc: () => new Promise(r => { cozum = r; }) });
  await k.s.htSonucAc('g1');
  const sursun = btn({ sonuc: 'SURSUN' });
  const kapansin = btn({ sonuc: 'KAPANSIN' });
  const iptal = btn();
  k.g('m-ht-sonuc').dugmeler = [sursun, kapansin, iptal];
  // Tarayıcıda disabled düğme click üretmez: tıklama bu koşulla modellenir.
  const tikla = b => (b.disabled ? undefined : k.s.htSonucGonder(b));
  const ilk = tikla(sursun);
  await new Promise(r => setImmediate(r));
  assert.deepStrictEqual([sursun.disabled, kapansin.disabled, iptal.disabled], [true, true, true]);
  await tikla(kapansin);
  assert.deepStrictEqual(k.rpcler.map(r => r.p.p_sonuc), ['SURSUN']);
  assert.strictEqual(sursun.textContent, 'Kaydediliyor…');
  assert.strictEqual(kapansin.textContent, 'Kaydet', 'yalnız tıklanan düğme metin değiştirir');
  cozum({ ok: true });
  await ilk;
  assert.deepStrictEqual([sursun.disabled, kapansin.disabled, iptal.disabled], [false, false, false]);
  assert.strictEqual(sursun.textContent, 'Kaydet');
});

test('HT-P-18b: RPC hatasında pencere açık kalır, bütün düğmeler yeniden açılır', async () => {
  const k = kur({ gorevler: [gorev('g1')], rpc: () => { throw new Error('HT_GECMIS_TARIH'); } });
  await k.s.htSonucAc('g1');
  const sursun = btn({ sonuc: 'SURSUN' });
  const kapansin = btn({ sonuc: 'KAPANSIN' });
  k.g('m-ht-sonuc').dugmeler = [sursun, kapansin];
  await k.s.htSonucGonder(sursun);
  assert.deepStrictEqual(k.kapanan, []);
  assert.deepStrictEqual([sursun.disabled, kapansin.disabled], [false, false]);
});

// ── Tarih alanları ───────────────────────────────────────────
for (const [ad, gercekOpenM] of [['ayna', false], ['gerçek utils/modal.js openM', true]]) {
  test(`HT-P-16 (${ad}): pencere açılışında tarih alanları boş; htSonucAc yalnız +3 yazar`, async () => {
    const k = kur({ takipler: BIR(), gorevler: [gorev('g1')], gercekOpenM });
    k.s.htAcPencere('H1');
    assert.strictEqual(k.g('ht-ac-tarih').value, '');
    await k.s.htMuayenePencere('H1');
    assert.strictEqual(k.g('ht-mu-tarih').value, '');
    await k.s.htSonucAc('g1');
    assert.strictEqual(k.g('ht-so-tarih').value, '2026-11-03');
  });
}

test('HT-P-16b: yeniden açılış önceki formu temizler', async () => {
  const k = kur({ takipler: BIR() });
  hazirAc(k, 'DIGER', 'eski');
  k.g('ht-ac-tarih').value = '2026-11-09';
  k.g('ht-ac-saat').value = '08:00';
  k.s.htAcPencere('H1');
  assert.strictEqual(k.g('ht-ac-sebep').value, '');
  assert.strictEqual(k.g('ht-ac-aciklama').value, '');
  assert.strictEqual(k.g('ht-ac-tarih').value, '');
  assert.strictEqual(k.g('ht-ac-saat').value, '');
  await k.s.htMuayenePencere('H1');
  k.g('ht-mu-saat').value = '10:00';
  await k.s.htMuayenePencere('H1');
  assert.strictEqual(k.g('ht-mu-saat').value, '');
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  k.g('ht-ka-not').value = 'eski';
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  assert.strictEqual(k.g('ht-ka-not').value, '');
});

// ── Kaçış ve sabitler ────────────────────────────────────────
test('HT-P-17: serbest açıklama seçici ve listede kaçışlı; sebep listesi config kaynaklı', async () => {
  const kotu = '<img src=x onerror=alert(1)>';
  const k = kur({ takipler: [takip('t1', { sebep_kodu: 'DIGER', aciklama: kotu }), takip('t2')] });
  await k.s.htMuayenePencere('H1');
  await k.s.htKapatPencere('H1', { baglam: 'kart' });
  for (const id of ['ht-mu-takip', 'ht-ka-liste']) {
    assert.ok(!k.g(id).innerHTML.includes('<img'), id);
    assert.ok(k.g(id).innerHTML.includes('&lt;img'), id);
  }
  k.s.htAcPencere('H1');
  for (const ad of ['Topallık', 'Süt düşüşü', 'Zayıflama', 'İştahsızlık', 'Halsizlik', 'Diğer']) {
    assert.ok(k.g('ht-ac-sebep').innerHTML.includes(ad), ad);
  }
  assert.match(k.g('ht-ac-title').textContent, /K-1/);
});

// ── index.html ve handlers.js bağlantısı ─────────────────────
test('HT-P-12: index.html dört modal, iki script forms.js sonrası, tek damga', () => {
  const html = oku('index.html');
  for (const id of ['m-ht-ac', 'm-ht-muayene', 'm-ht-kapat', 'm-ht-sonuc']) {
    assert.strictEqual((html.match(new RegExp(`id="${id}"`, 'g')) || []).length, 1, id);
  }
  const srcs = [...html.matchAll(/<script src="([^"]+)"/g)].map(m => m[1].split('?')[0]);
  const f = srcs.indexOf('js/forms.js');
  const a = srcs.indexOf('js/hayvan-takip.js');
  const b = srcs.indexOf('js/hayvan-takip-pencere.js');
  assert.ok(f >= 0 && a > f && b > a, `sıra: forms ${f}, takip ${a}, pencere ${b}`);
  assert.strictEqual(new Set([...html.matchAll(/\?v=([0-9]{8}-[0-9]+)/g)].map(m => m[1])).size, 1);
});

test('HT-P-12b: z-index, tarih ve saat alanları, zeminsiz band başlığı', () => {
  const html = oku('index.html');
  for (const id of ['m-ht-kapat', 'm-ht-sonuc']) {
    assert.match(html, new RegExp(`id="${id}"[^>]*z-index:9998`), id);
  }
  for (const id of ['m-ht-ac', 'm-ht-muayene']) {
    assert.match(html, new RegExp(`<div id="${id}" class="mo" data-action="mclose-overlay"`), id);
  }
  for (const id of ['ht-ac-tarih', 'ht-mu-tarih', 'ht-so-tarih']) {
    assert.match(html, new RegExp(`<input id="${id}" class="fi" type="text"`), id);
  }
  for (const id of ['ht-ac-saat', 'ht-mu-saat', 'ht-so-saat']) {
    assert.match(html, new RegExp(`<input id="${id}" class="fi" type="time"`), id);
  }
  const kural = html.match(/\.aband-hdr\.takip\s*\{[^}]*\}/);
  assert.ok(kural, 'stil var');
  assert.match(kural[0], /color:var\(--blue\)/);
  assert.match(kural[0], /text-transform:none/);
  assert.ok(!/background/.test(kural[0]), 'zemin yok');
});

test('HT-P-12f: sonuç penceresi (9998) açıkken takvim (ui.js z-index:300) üstte kalır', () => {
  const html = oku('index.html');
  assert.match(html, /#m-ht-sonuc\.on~#tek-tarih-takvim\{z-index:9999!important\}/);
  assert.match(oku('js/ui.js'), /box\.id = 'tek-tarih-takvim';[\s\S]{0,120}z-index:300/, 'takvim hâlâ 300; kural gerekçesi geçerli');
});

test('HT-P-12c: her data-action="ht-*" handlers.js\'te kayıtlı ve doğru işleve gider', () => {
  const html = oku('index.html');
  const eylemler = [...new Set([...html.matchAll(/data-action="(ht-[a-z-]+)"/g)].map(m => m[1]))];
  const A = {};
  const cagri = [];
  const casus = ad => el => { cagri.push([ad, el]); };
  const fnler = ['htAcGonder', 'htMuayeneGonder', 'htKapatGonder', 'htSonucGonder', 'htTumunuSec', 'htAcikKalsin', 'htSonucVakaAc', 'htVakaBagla'];
  loadBrowserModule('js/utils/handlers.js', {
    extra: {
      registerActions: m => Object.assign(A, m),
      closeM: id => cagri.push(['closeM', id]),
      ...Object.fromEntries(fnler.map(f => [f, casus(f)])),
    },
  });
  assert.ok(eylemler.length >= 10, 'eylem sayısı: ' + eylemler.length);
  eylemler.forEach(e => assert.strictEqual(typeof A[e], 'function', e));
  const beklenen = {
    'ht-ac-gonder': 'htAcGonder', 'ht-mu-gonder': 'htMuayeneGonder', 'ht-ka-gonder': 'htKapatGonder',
    'ht-so-gonder': 'htSonucGonder', 'ht-tumunu-sec': 'htTumunuSec', 'ht-acik-kalsin': 'htAcikKalsin', 'ht-so-vaka-ac': 'htSonucVakaAc',
  };
  const el = { dataset: {} };
  for (const [e, f] of Object.entries(beklenen)) {
    cagri.length = 0;
    A[e](el);
    assert.strictEqual(cagri[0][0], f, e);
    if (/gonder/.test(e)) assert.strictEqual(cagri[0][1], el, e + ' düğmeyi geçirir');
  }
  // Satırlar çalışma anında üretilir, index.html'de yoktur; düğmeyi geçirir.
  cagri.length = 0;
  A['ht-so-vaka-bagla'](el);
  assert.deepStrictEqual(cagri, [['htVakaBagla', el]]);
  const iptal = { 'ht-ac-iptal': 'm-ht-ac', 'ht-mu-iptal': 'm-ht-muayene', 'ht-ka-iptal': 'm-ht-kapat', 'ht-so-iptal': 'm-ht-sonuc' };
  for (const [e, m] of Object.entries(iptal)) {
    cagri.length = 0;
    A[e](el);
    assert.deepStrictEqual(cagri, [['closeM', m]], e);
  }
});

test('HT-P-12d: pencere kodunun kullandığı her ht-/m-ht- kimliği index.html\'de var; SURSUN/KAPANSIN düğmeleri var', () => {
  const html = oku('index.html');
  const kod = oku('js/hayvan-takip-pencere.js');
  const kimlikler = [...new Set([...kod.matchAll(/'((?:m-)?ht-[a-z]+(?:-[a-z]+)*)'/g)].map(m => m[1]))];
  assert.ok(kimlikler.length >= 15, 'kimlik: ' + kimlikler.join(','));
  kimlikler.forEach(id => assert.ok(html.includes(`id="${id}"`), id));
  assert.match(html, /data-action="ht-so-gonder" data-sonuc="SURSUN"/);
  assert.match(html, /data-action="ht-so-gonder" data-sonuc="KAPANSIN"/);
  assert.match(html, /<button[^>]*data-action="ht-so-vaka-ac"[^>]*>🏥 Vaka aç \/ tedavi planı<\/button>/);
  assert.match(html, /<div id="ht-so-vakalar" style="display:none/);
  for (const metin of ['Tümünü seç', 'Açık kalsın', 'Takip sürsün', 'Takip kapansın']) {
    assert.ok(html.includes(metin), metin);
  }
});

test('HT-P-12e: pencere modülü yüklenirken global çağırmaz (forms.js sonrası tanımsız sembol yok)', () => {
  const { sandbox } = loadBrowserModule('js/hayvan-takip-pencere.js');
  for (const fn of ['htAcPencere', 'htAcGonder', 'htMuayenePencere', 'htMuayeneGonder', 'htKapatPencere', 'htKapatGonder', 'htAcikKalsin', 'htSonucAc', 'htSonucGonder', 'htVakaSonrasi', 'htTumunuSec']) {
    assert.strictEqual(typeof sandbox[fn], 'function', fn);
  }
});
