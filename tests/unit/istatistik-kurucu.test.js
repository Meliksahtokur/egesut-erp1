'use strict';
// İstatistik Atölyesi AP1 Task 12 — kurucu ekranı (js/istatistik/kurucu.js).
// Plan Step 1 testleri + akış testleri. cumle.js ve grafik.js gerçek; kardeş modüller ve RPC'ler stub.
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const KOK = path.join(__dirname, '..', '..');
const oku = rel => fs.readFileSync(path.join(KOK, rel), 'utf8');
const DOSYA = 'js/istatistik/kurucu.js';

// ── Sahte DOM: innerHTML içindeki id'ler eleman olur; dış kapsayıcı yazılınca iç id'ler düşer ──
function sahteBelge() {
  const idler = new Map();
  function eleman(id) {
    const siniflar = new Set();
    const e = {
      id, _html: '', hidden: false, dataset: {}, cizimler: [], kaydirma: 0, scrollTop: 0, dinleyici: {},
      classList: { add: c => siniflar.add(c), remove: c => siniflar.delete(c), contains: c => siniflar.has(c),
        toggle: (c, f) => (f ? siniflar.add(c) : siniflar.delete(c)) },
      addEventListener(t, f) { (e.dinleyici[t] = e.dinleyici[t] || []).push(f); },
      scrollIntoView() { e.kaydirma += 1; },
      focus() {},
      contains: x => !!x && x.panelIci === e,
      querySelector(sec) {
        const sec_ = /^select\[data-kurucu-slot="(\w+)"\]$/.exec(sec);
        if (sec_) {
          if (!e._html.includes(`<select data-kurucu-slot="${sec_[1]}"`)) return null;
          return { focus(o) { belge.activeElement = { tagName: 'SELECT', dataset: { kurucuSlot: sec_[1] }, panelIci: e }; belge.odakSecenek = o; } };
        }
        if (sec === '.atolye-hata') return e._html.includes('atolye-hata') ? { remove() { e._html = e._html.replace(/<div class="atolye-hata"[\s\S]*?<\/div>/, ''); } } : null;
        if (sec === '.loader') return e._html.includes('class="loader"') ? {} : null;
        throw new Error('beklenmeyen seçici: ' + sec);
      },
      querySelectorAll(sec) {
        if (sec === 'button,select,input') return denetimler(e);
        assert.strictEqual(sec, 'canvas[data-kurucu-kart]');
        return [...e._html.matchAll(/<canvas[^>]*data-kurucu-kart="(\d+)"/g)].map(m => {
          const onceki = e.cizimler[Number(m[1])];
          return onceki || (e.cizimler[Number(m[1])] = { dataset: { kurucuKart: m[1] } });
        });
      },
      get innerHTML() { return e._html; },
      set innerHTML(v) { e._html = v; e.cizimler = []; icKur(e, v); },
      get outerHTML() { return e._html; },
      // Gerçek outerHTML düğümü değiştirir: kaydırma sıfırlanır, içindeki odak BODY'ye düşer.
      set outerHTML(v) {
        e._html = v; e.scrollTop = 0;
        if (belge.activeElement && belge.activeElement.panelIci === e) belge.activeElement = { tagName: 'BODY', dataset: {} };
        icKur(e, v);
      },
    };
    return e;
  }
  // Panel HTML'indeki denetimler; focus gerçek tarayıcı gibi activeElement'i taşır. Nitelikler kebab→camel dataset'e.
  function denetimler(e) {
    return [...e._html.matchAll(/<(button|select|input)\b([^>]*)>(?:([^<]*)<\/button>)?/g)].map(m => {
      const dataset = {};
      for (const a of m[2].matchAll(/\sdata-([\w-]+)="([^"]*)"/g)) dataset[a[1].replace(/-(\w)/g, (_, h) => h.toUpperCase())] = a[2];
      const el = { tagName: m[1].toUpperCase(), dataset, id: (/\sid="([^"]+)"/.exec(m[2]) || [])[1], metin: m[3], panelIci: e,
        setSelectionRange(a, b) { Object.assign(el, { secim: [a, b], selectionStart: a, selectionEnd: b }); },
        focus(o) { belge.activeElement = el; belge.odakSecenek = o; } };
      return el;
    });
  }
  function icKur(sahip, html) {
    const dusur = ust => { for (const [id, el] of [...idler]) { if (el.sahip === ust) { idler.delete(id); dusur(el); } } };
    dusur(sahip);
    for (const m of html.matchAll(/\sid="([^"]+)"([^>]*)>/g)) {
      if (m[1] === sahip.id) continue;                    // outerHTML: eleman kendini korur, yalnız içi yenilenir
      const el = eleman(m[1]);
      el.sahip = sahip;
      el.hidden = /\shidden\b/.test(m[2]);
      const deger = /\svalue="([^"]*)"/.exec(m[2]);      // gerçek input gibi: value özniteliği alanın değeridir
      if (deger) el.value = deger[1];
      el._html = html.slice(m.index + m[0].length);       // yaklaşık iç metin (ilk yükleme çarkı için yeter)
      idler.set(m[1], el);
    }
  }
  const kok = eleman('atolye-icerik');
  idler.set('atolye-icerik', kok);
  const belge = { getElementById: id => idler.get(id) || null, kok, idler, activeElement: { tagName: 'BODY', dataset: {} } };
  return belge;
}

const kacis = v => String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function yukle(ek = {}) {
  const belge = sahteBelge();
  const cagri = { seri: [], secenek: [], cizim: [], kaydet: [], toast: [], serit: [], temiz: 0, vakalar: [], invalidate: 0 };
  const c = {
    console, Date, Intl, String, Object, Array, JSON, Promise, Error, Number, Set, Math, RegExp, Boolean,
    document: belge,
    window: {},
    esc: v => (v ? kacis(v) : ''),                    // js/utils/helpers.js esc: tırnak kaçırmaz, falsy → ''
    escAttr: v => kacis(v ?? '').replace(/"/g, '&quot;').replace(/'/g, '&#39;'),   // js/utils/helpers.js escAttr ile aynı
    tarihIsoTr: s => (s ? `${s.slice(8, 10)}.${s.slice(5, 7)}.${s.slice(0, 4)}` : ''),
    tarihAlaniTakvimAc: (el, o) => { c._takvim = { el, o }; },
    bugun: () => '2026-10-31',
    _kombinasyonSiz: y => `${y}'EK`,                  // kombinasyon.js ünlü uyumu eki; gerçeği panel_kiyas_grubu_gercek_ek'te
    toast: (m, h) => cagri.toast.push([m, !!h]),
    atolyeHataSeridi: (e, k) => { cagri.serit.push(e.message); return {}; },
    atolyeHataTemizle: () => { cagri.temiz += 1; },
    atolyeHesapTarihi: iso => `Hesap tarihi: <${iso}>`,
    kombinasyonHtml: k => (k ? `<div class="komb">${k.x}</div>` : ''),
    kombinasyonBagla: k => { cagri.kombBagla = k; },
    geciciFiyatPanelHtml: (f, d) => { cagri.fiyatDeger = d; return f && f.length ? '<div class="atolye-fiyat">F</div>' : ''; },
    geciciFiyatBagla: k => { cagri.fiyatBagla = k; },
    statOlcumListele: async () => [TANIM_BASARI],
    statAtolyeSecenekler: async cu => { cagri.secenek.push(cu); return SECENEK; },
    statAtolyeSeri: async (cu, g, o) => { cagri.seri.push([cu, g, o]); return { zarflar: [zarfBasari()], kombinasyon: null, fiyat_eksik: [] }; },
    statAtolyeVakalar: async (cu, gr) => { cagri.vakalar.push(gr); return { toplam: 0, vakalar: [] }; },
    statGrafikKaydet: async (...a) => { cagri.kaydet.push(a); return 'uuid'; },
    _statInvalidate: () => { cagri.invalidate += 1; },
    Chart: function () {},
    ...ek,
  };
  vm.createContext(c);
  vm.runInContext(oku('js/istatistik/cumle.js'), c);
  vm.runInContext(oku('js/istatistik/grafik.js'), c);
  vm.runInContext(oku(DOSYA), c);
  // grafik.js'in DOM'lu iki fonksiyonu kayda çevrilir (Chart yok)
  c.grafikCiz = (cv, cfg) => { cagri.cizim.push([cv, cfg]); cv.__chart = { destroy() { cv.yokEdildi = (cv.yokEdildi || 0) + 1; } }; return cv.__chart; };
  c.temaRenkleri = () => ({ vurgu: 'V', kiyas: 'K', gri: 'G', metin: 'M', izgara: 'I' });
  c.window._atolye = { sekme: 'kurucu', cumle: null, secenekler: null, gecici: { ilac_fiyat: {} }, sonZarflar: null, onceki: [], jeton: 0 };
  return { c, cagri, belge, s: c.window._atolye };
}

const ID = '11111111-1111-4111-8111-111111111111';
const SECENEK = {
  donem: { bas: '2025-10-31', bit: '2026-10-31' }, toplam_n: 30,
  hastaliklar: [{ id: ID, ad: 'Enterit', kategori: 'Buzağı', n: 20 }, { id: '22222222-2222-4222-8222-222222222222', ad: 'Pnömoni', kategori: 'Solunum', n: 10 }],
  kategoriler: [{ ad: 'Buzağı', n: 20 }, { ad: 'Solunum', n: 10 }],
  x_adaylari: [{ deger: 'Enrofloksasin', n: 12 }, { deger: '(bilinmiyor)', n: 2 }],
  y_adaylari: [{ deger: 'Flunixin', n: 6 }],
};
const TANIM_BASARI = { ad: 'saglik_basari', baslik: 'Başarı oranı', tanim: 'Tanım metni <t>', kume: 'Küme metni', surum: 'sql:20261017000005' };

const cumleOrnek = (d = {}) => ({
  v: 1, alan: 'saglik', hastalik: { tip: 'hastalik', deger: ID }, ilac: { duzey: 'etken', x: null, y: null },
  kiyas_grubu: 'tumu', olculer: ['saglik_basari', 'saglik_kapanma_gunu', 'saglik_vaka_tl'], kirilim: 'ilac',
  donem: { tip: 'son_ay', n: 12 }, kiyas_duzeyi: ['biz'], ...d,
});
function zarfBasari(d = {}) {
  return {
    olcum: 'saglik_basari', hesap_at: '2026-10-31T06:05:00Z', surum: 'sql:20261017000002', n: 21, yetersiz: false,
    x: { ad: 'grup', deger: ['Enrolen içeren', 'Tüm Enterit vakaları'], anahtar: ['x', 'tumu'] },
    seriler: [{ ad: 'başarı %', n: [21, 22], k: [17, 18], y: [81, 81.8], alt: [60, 61], ust: [92, 93] }],
    sayac: { acik_n: 0, olgunlasmamis_n: 0, fiyatsiz_n: 0, kiyas_n: 22 },
    gecici: { var: false, ilac_fiyat: {} }, tanim: 'saglik_basari', dipnot: [], fiyat_kaynagi: null, egri: null, ...d,
  };
}
const tekGrup = d => zarfBasari({ n: 3, x: { ad: 'grup', deger: ['Tüm vakalar'], anahtar: ['tumu'] },
  seriler: [{ ad: 'başarı %', n: [3], k: [2], y: [null], alt: [null], ust: [null] }], sayac: { kiyas_n: null }, ...d });
const sifirBosluk = s => s.replace(/&quot;/g, '"');

// ── Plan Step 1: panel ──
test('panel_slot_sirasi', () => {
  const { c } = yukle();
  const h = c.kurucuCumlePanelHtml(cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrofloksasin', y: null }, kirilim: 'yok' }), SECENEK);
  const sira = [...h.matchAll(/data-slot="(\w+)"/g)].map(m => m[1]);
  assert.deepStrictEqual(sira, ['alan', 'hastalik', 'duzey', 'ilac', 'kiyas_grubu', 'olculer', 'kirilim', 'donem', 'kiyas_duzeyi']);
  assert.ok(h.indexOf('atolye-cumle-baslik') < h.indexOf('data-slot="alan"'), 'okunur cümle üstte');
  assert.ok(h.includes('Kaydettiğim grafiklere kaydet') && h.includes('Yeniden hesapla'));
  assert.ok(h.indexOf('Kaydettiğim grafiklere kaydet') > h.indexOf('data-slot="kiyas_duzeyi"'), 'alt satır');
  assert.ok(h.includes('atolye-cumle-baslik">Sağlık › Enterit vakalarında'), 'cumleBaslik');
});

test('panel_alan_tek_saglik', () => {
  const { c } = yukle();
  const h = c.kurucuCumlePanelHtml(cumleOrnek(), SECENEK);
  const alan = h.slice(h.indexOf('data-slot="alan"'), h.indexOf('data-slot="hastalik"'));
  assert.ok(alan.includes('Sağlık'));
  assert.ok(!/Üreme|Süt|Ekonomi/.test(h), 'başka alan çipi yok');
  assert.strictEqual((alan.match(/class="atolye-cip\b(?!ler)/g) || []).length, 1);
});

test('panel_hastalik_db_listesi', () => {
  const { c } = yukle();
  const h = c.kurucuCumlePanelHtml(cumleOrnek(), SECENEK);
  const s = h.slice(h.indexOf('data-slot="hastalik"'), h.indexOf('data-slot="duzey"'));
  assert.strictEqual((s.match(/<option/g) || []).length, SECENEK.hastaliklar.length + SECENEK.kategoriler.length + 1);
  assert.ok(s.includes('>Tüm hastalıklar<'));
  assert.ok(s.includes('>Buzağı (tümü) · 20<') && s.includes('>Enterit · 20<') && s.includes('>Pnömoni · 10<'));
  assert.ok(/<option[^>]*selected[^>]*>Enterit · 20</.test(s), 'seçili hastalık');
  assert.strictEqual(oku(DOSYA).includes('HASTALIK_KAT'), false, 'statik liste yok');
});

test('panel_hastalik_listede_yoksa_secim_gizlenmez', () => {
  const { c } = yukle();
  const yok = cumleOrnek({ hastalik: { tip: 'hastalik', deger: '33333333-3333-4333-8333-333333333333' } });
  const s = c.kurucuCumlePanelHtml(yok, SECENEK);
  assert.ok(/<option[^>]*selected[^>]*>Seçili hastalık · 0</.test(s), 'dönemde vakası yoksa da seçim görünür');
  assert.ok(/<option[^>]*selected[^>]*>Tüm hastalıklar</.test(c.kurucuCumlePanelHtml(cumleOrnek({ hastalik: { tip: 'tumu', deger: null } }), SECENEK)));
});

test('panel_y_yalniz_x_varken', () => {
  const { c } = yukle();
  const yok = c.kurucuCumlePanelHtml(cumleOrnek(), SECENEK);
  assert.ok(!yok.includes('+ ekle') && !yok.includes('Flunixin'), 'x yokken y yok');
  assert.ok(!yok.includes('data-slot="kiyas_grubu"'), 'x yokken kıyas grubu yok');
  const v = c.kurucuCumlePanelHtml(cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrofloksasin', y: null }, kirilim: 'yok' }), SECENEK);
  assert.ok(v.includes('+ ekle') && v.includes('>Flunixin · 6<'));
  assert.ok(v.includes('Hastalığın tüm vakaları'));
  assert.ok(!v.includes("'siz"), 'y yokken y\'siz kıyas yok');
  const xy = c.kurucuCumlePanelHtml(cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrofloksasin', y: 'Flunixin' }, kiyas_grubu: 'x_y_siz', kirilim: 'yok' }), SECENEK);
  assert.ok(xy.includes("Enrofloksasin içeren, Flunixin'EK"));
});

test('panel_kiyas_grubu_gercek_ek', () => {
  const { c } = yukle({ trLower: s => s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase() });
  vm.runInContext(oku('js/istatistik/kombinasyon.js'), c);       // T13 eki tek yer
  const panel = y => c.kurucuCumlePanelHtml(cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrolen', y }, kiyas_grubu: 'x_y_siz', kirilim: 'yok' }), SECENEK);
  assert.ok(panel('Halocur').includes("Enrolen içeren, Halocur'suz"), 'ünlü uyumu');
  assert.ok(panel('Flunixin').includes("Enrolen içeren, Flunixin'siz"));
  assert.ok(panel('(bilinmiyor)').includes("Enrolen içeren, Tanınamayan ilaç'sız"), 'okunur etiket eklenir');
  assert.ok(!/'siz`/.test(oku(DOSYA)), 'kurucu.js sabit ek taşımaz');
});

test('panel_kirilim_ilac_x_varken_yok', () => {
  const { c } = yukle();
  const parca = h => h.slice(h.indexOf('data-slot="kirilim"'), h.indexOf('data-slot="donem"'));
  const yok = parca(c.kurucuCumlePanelHtml(cumleOrnek(), SECENEK));
  ['Yok', 'İlaç', 'Ay', 'Çeyrek', 'Yıl'].forEach(a => assert.ok(yok.includes(`>${a}<`), a));
  const v = parca(c.kurucuCumlePanelHtml(cumleOrnek({ ilac: { duzey: 'etken', x: 'A', y: null }, kirilim: 'yok' }), SECENEK));
  assert.ok(!v.includes('>İlaç<') && v.includes('>Yok<') && v.includes('>Yıl<'));
});

test('panel_doz_pasif', () => {
  const { c } = yukle();
  const h = c.kurucuCumlePanelHtml(cumleOrnek(), SECENEK);
  const s = h.slice(h.indexOf('data-slot="olculer"'), h.indexOf('data-slot="kirilim"'));
  c.ATOLYE_OLCULER_LISTE = vm.runInContext('ATOLYE_OLCULER.map(o => o.etiket)', c);
  Array.from(c.ATOLYE_OLCULER_LISTE).forEach(e => assert.ok(s.includes(e), e));
  const doz = s.match(/<label class="([^"]*)"><input[^>]*data-kurucu-olcu="doz"[^>]*>/);
  assert.ok(doz && doz[1].includes('atolye-pasif'), 'Doz pasif sınıfı');
  assert.ok(!doz[0].includes('checked'), 'varsayılan seçili değil');
  assert.ok(!doz[0].includes('disabled'), 'seçilebilir: doz kartı');
  assert.strictEqual((s.match(/type="checkbox"/g) || []).length, 6);
  assert.strictEqual((s.match(/\schecked/g) || []).length, 3);
});

test('panel_son_olcu_kaldirilamaz', () => {
  const { c } = yukle();
  const h = c.kurucuCumlePanelHtml(cumleOrnek({ olculer: ['saglik_basari'] }), SECENEK);
  assert.ok(/data-kurucu-olcu="saglik_basari"[^>]*checked[^>]*disabled/.test(h));
});

test('panel_kacis_ve_bilinmiyor_etiketi', () => {
  const { c } = yukle();
  const sec = { ...SECENEK,
    hastaliklar: [{ id: ID, ad: '<b>Hasta"lık', kategori: 'K', n: 1 }],
    kategoriler: [{ ad: '<i>Kat', n: 1 }],
    x_adaylari: [{ deger: '<script>"x', n: 2 }, { deger: '(bilinmiyor)', n: 1 }] };
  const h = c.kurucuCumlePanelHtml(cumleOrnek(), sec);
  assert.ok(!/<b>|<i>|<script>/.test(h), 'kaçışsız DB değeri yok');
  assert.ok(h.includes('&lt;b&gt;Hasta"lık · 1'));
  assert.ok(!/value="[^"]*<script/.test(h) && h.includes('&quot;'), 'değer özniteliği escAttr');
  assert.ok(h.includes('>Tanınamayan ilaç · 1<'), 'bilinmiyor okunur etiketle');
  assert.ok(!h.includes('(bilinmiyor) ·'));
});

test('panel_donem_cipleri', () => {
  const { c } = yukle();
  const parca = cu => { const h = c.kurucuCumlePanelHtml(cu, SECENEK); return h.slice(h.indexOf('data-slot="donem"'), h.indexOf('data-slot="kiyas_duzeyi"')); };
  const s = parca(cumleOrnek());
  ['Son 3 ay', 'Son 6 ay', 'Son 12 ay', 'Son 24 ay', 'Takvim yılı', 'Özel aralık'].forEach(a => assert.ok(s.includes(a), a));
  assert.ok(/class="atolye-cip on"[^>]*>Son 12 ay</.test(s));
  const adlar = h => [...h.matchAll(/<(?:button|span)[^>]*atolye-cip[^>]*>([^<]*)</g)].map(m => m[1]);
  assert.deepStrictEqual(adlar(s), ['Son 3 ay', 'Son 6 ay', 'Son 12 ay', 'Son 24 ay', 'Tüm zamanlar', 'Takvim yılı', 'Özel aralık'], 'hep görünür, Son 24 aydan hemen sonra');
  assert.ok(!/class="atolye-cip on"[^>]*>Tüm zamanlar</.test(s), 'varsayılan dönemde vurgulu değil');
  const t = parca(cumleOrnek({ donem: { tip: 'tumu' } }));
  assert.ok(/class="atolye-cip on"[^>]*>Tüm zamanlar</.test(t), 'seçiliyken vurgulu');
  assert.strictEqual((t.match(/>Tüm zamanlar</g) || []).length, 1, 'seçiliyken tek çip');
  assert.ok(!/class="atolye-cip on"[^>]*>Son 12 ay</.test(t), 'tek vurgu');
  const y = parca(cumleOrnek({ donem: { tip: 'yil', yil: 2025 } }));
  assert.ok(/<option[^>]*selected[^>]*>2025</.test(y) && y.includes('>2026<'));
  const a = parca(cumleOrnek({ donem: { tip: 'aralik', bas: '2026-01-02', bit: '2026-03-04' } }));
  assert.ok(a.includes('02.01.2026') && a.includes('04.03.2026'));
  assert.ok(a.includes('data-kurucu-tarih="bas"') && a.includes('data-kurucu-tarih="bit"'));
});

// ── Plan Step 1: kart ──
function kartYukle(cumle = cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrolen', y: null }, kirilim: 'yok' })) {
  const t = yukle();
  t.s.cumle = cumle;
  return t;
}

test('kart_tamam_canvas_ozet', () => {
  const { c } = kartYukle();
  const z = zarfBasari();
  const h = c.kurucuKartHtml(z, TANIM_BASARI, 2);
  assert.ok(h.includes('atolye-kart-baslik">Başarı oranı<'));
  assert.ok(h.includes('atolye-rozet">n=21 / n=22<'), 'n rozeti');
  assert.strictEqual((h.match(/<canvas/g) || []).length, 1);
  assert.ok(h.includes('data-kurucu-kart="2"'));
  assert.ok(/class="atolye-grafik"><canvas/.test(h));
  assert.ok(h.includes(`atolye-ozet">${kacis(c.zarfOzetCumle(z))}<`), 'özet görünür');
  assert.ok(!h.includes('atolye-durum'));
});

test('kart_yetersiz_metin_eylem', () => {
  const { c } = kartYukle(cumleOrnek());
  const h = c.kurucuKartHtml(tekGrup(), TANIM_BASARI, 0);
  assert.ok(!h.includes('<canvas'));
  assert.ok(h.includes('atolye-durum') && h.includes('Yetersiz veri (n=3) — en az 5 vaka gerekir'));
  assert.ok(h.includes('Dönemi 24 aya çıkar') && h.includes('data-kurucu-slot="donem"'));
  assert.ok(sifirBosluk(h).includes('data-deger="{"n":24,"tip":"son_ay"}"'), 'eylem değeri');
  assert.ok(!/atolye-ozet/.test(h), 'durum ≠ tamam iken özet basılmaz (F2 madde 2)');
});

test('kart_hucre_yetersiz_metinle', () => {
  const { c } = kartYukle(cumleOrnek());
  const z = zarfBasari({ n: 21, x: { ad: 'grup', deger: ['A', 'B<b>', 'C'], anahtar: ['a', 'b', 'c'] },
    seriler: [{ n: [21, 3, 0], k: [17, 2, 0], y: [81, null, null], alt: [1, null, null], ust: [2, null, null] }], sayac: { kiyas_n: 3 } });
  const h = c.kurucuKartHtml(z, null, 0);
  assert.ok(h.includes('<canvas') && h.includes('B&lt;b&gt; yetersiz (n=3)') && h.includes('C yetersiz (n=0)'));
  assert.ok(!h.includes('A yetersiz'));
  // zaman: boş periyot yazılmaz (P12), n<5 periyot yazılır
  const zm = zarfBasari({ n: 9, x: { ad: 'ay', deger: ['2026-01', '2026-02', '2026-03'], anahtar: ['a', 'b', 'c'] },
    seriler: [{ ad: 'Tüm', anahtar: 'tumu', n: [9, 2, 0], k: [8, 1, 0], y: [88, null, null] }], sayac: {} });
  const hz = c.kurucuKartHtml(zm, null, 0);
  assert.ok(hz.includes('2026-02 yetersiz (n=2)') && !hz.includes('2026-03 yetersiz'));
});

test('kart_kontrast_canvas_ve_eylem', () => {
  const { c } = kartYukle();
  const z = zarfBasari({ sayac: { kiyas_n: 2 } });
  const h = c.kurucuKartHtml(z, null, 0);
  assert.ok(h.includes('<canvas') && h.includes('atolye-ozet'));
  assert.ok(h.includes('Karşı grup çok küçük (n=2)') && h.includes('data-kurucu-slot="kombinasyon"'));
});

test('kart_veri_yok_geri_yigin', () => {
  const { c, s } = kartYukle(cumleOrnek());
  const z = zarfBasari({ n: 0, seriler: [{ n: [0], k: [0], y: [null] }], x: { ad: 'grup', deger: ['G'], anahtar: ['tumu'] }, sayac: {} });
  const bos = c.kurucuKartHtml(z, null, 0);
  assert.ok(bos.includes('Bu seçimde vaka yok') && !bos.includes('data-kurucu-slot="geri"'), 'yığın boşken ölü düğme yok');
  s.onceki.push(cumleOrnek());
  assert.ok(c.kurucuKartHtml(z, null, 0).includes('data-kurucu-slot="geri"'));
});

test('kart_acik_sayac', () => {
  const { c } = kartYukle();
  const h = c.kurucuKartHtml(zarfBasari({ sayac: { acik_n: 3, kiyas_n: 22 } }), null, 0);
  assert.ok(h.includes('+3 açık vaka hesap dışı'));
  assert.ok(!c.kurucuKartHtml(zarfBasari(), null, 0).includes('açık vaka'));
});

test('kart_olgunlasmamis_sayac', () => {
  const { c } = kartYukle();
  const s = { olgunlasmamis_n: 4, kiyas_n: 22 };
  assert.ok(c.kurucuKartHtml(zarfBasari({ sayac: s }), null, 0).includes('4 vaka 30 gün dolmadı'));
  assert.ok(!c.kurucuKartHtml(zarfBasari({ olcum: 'saglik_kapanma_gunu', sayac: s, seriler: [{ n: [21, 22], y: [8, 9], q1: [6, 6], q3: [11, 12] }] }), null, 0).includes('30 gün dolmadı'), 'yalnız başarı kartında');
});

test('kart_gecici_bant', () => {
  const { c } = kartYukle();
  const tl = { olcum: 'saglik_vaka_tl', seriler: [{ n: [21, 22], y: [410, 360], q1: [1, 1], q3: [2, 2] }] };
  assert.ok(c.kurucuKartHtml(zarfBasari({ ...tl, fiyat_kaynagi: 'gecici', gecici: { var: true, ilac_fiyat: { a: 1 } } }), null, 0)
    .includes('atolye-gecici-bant">geçici, kaydedilmedi<'));
  assert.ok(!c.kurucuKartHtml(zarfBasari({ ...tl, fiyat_kaynagi: 'kayitli' }), null, 0).includes('atolye-gecici-bant'));
  assert.ok(!c.kurucuKartHtml(zarfBasari({ gecici: { var: true, ilac_fiyat: { a: 1 } } }), null, 0).includes('atolye-gecici-bant'), 'başarı kartında bant yok');
});

test('kart_fiyat_gir_kismi_fiyatsizda_da_ulasilir', () => {
  const { c } = kartYukle();
  const tl = { olcum: 'saglik_vaka_tl', fiyat_kaynagi: 'kayitli', sayac: { fiyatsiz_n: 4, kiyas_n: 22 }, seriler: [{ n: [21, 22], y: [410, 360], q1: [1, 1], q3: [2, 2] }] };
  const h = c.kurucuKartHtml(zarfBasari(tl), null, 0);
  assert.ok(h.includes('<canvas') && h.includes('data-kurucu-slot="fiyat_panel"'));
  assert.ok(!c.kurucuKartHtml(zarfBasari({ sayac: { fiyatsiz_n: 4, kiyas_n: 22 } }), null, 0).includes('fiyat_panel'), 'başarı kartında yok');
});

test('kart_tanim_satiri', () => {
  const { c } = kartYukle();
  const h = c.kurucuKartHtml(zarfBasari(), TANIM_BASARI, 0);
  const t = h.slice(h.indexOf('<details class="atolye-ayrinti"'), h.indexOf('</details>'));
  assert.ok(t.includes('<summary>Ayrıntı</summary>'));
  assert.ok(t.includes('Tanım metni &lt;t&gt;') && t.includes('Küme metni') && t.includes('sql:20261017000002'));
  assert.ok(t.includes('Hesap tarihi: &lt;2026-10-31T06:05:00Z&gt;'), 'hesap tarihi kaçışlı');
  assert.ok(t.includes('atolye-hesap'), 'hesap tarihi her kartta Ayrıntı altında (TFA G3)');
});

test('kart_kacis', () => {
  const { c } = kartYukle();
  const z = zarfBasari({ x: { ad: 'grup', deger: ['<b>Hastalık</b>', 'K"<i>'], anahtar: ['x"<', 'tumu'] }, dipnot: ['<u>dip</u>'] });
  const h = c.kurucuKartHtml(z, { baslik: '<s>B', tanim: '<a>', kume: '<c>' }, 0);
  assert.ok(!/<b>|<i>|<u>|<s>|<a>|<c>/.test(h), 'kaçışsız DB değeri yok');
  assert.ok(h.includes('&lt;b&gt;Hastalık&lt;/b&gt;'));
  assert.ok(h.includes('data-kurucu-vakalar="x&quot;&lt;"'), 'grup anahtarı escAttr');
});

test('kart_basari_hiz_ayri', () => {
  const { c } = kartYukle();
  const hiz = zarfBasari({ olcum: 'saglik_kapanma_gunu', tanim: 'saglik_kapanma_gunu', seriler: [{ n: [21, 22], y: [8, 9], q1: [6, 6], q3: [11, 12] }] });
  const h1 = c.kurucuKartHtml(zarfBasari(), null, 0);
  const h2 = c.kurucuKartHtml(hiz, null, 1);
  [h1, h2].forEach(h => {
    assert.strictEqual((h.match(/<canvas/g) || []).length, 1, 'kart başına tek canvas');
    assert.strictEqual((h.match(/atolye-kart-baslik/g) || []).length, 1, 'kart başına tek ölçü');
  });
  assert.ok(h1.includes('Başarı oranı') && !h1.includes('Kapanma hızı'));
  assert.ok(h2.includes('Kapanma hızı') && !h2.includes('Başarı oranı'));
});

test('kart_egri_anahtari_yalniz_hizda', () => {
  const { c } = kartYukle();
  const egri = [{ anahtar: 'x', gun: [1, 2], oran: [0.5, 1] }];
  const hiz = d => zarfBasari({ olcum: 'saglik_kapanma_gunu', seriler: [{ n: [21, 22], y: [8, 9], q1: [6, 6], q3: [11, 12] }], ...d });
  assert.ok(c.kurucuKartHtml(hiz({ egri }), null, 0).includes('Kapanma eğrisini göster'));
  assert.ok(!c.kurucuKartHtml(hiz({ egri: null }), null, 0).includes('Kapanma eğrisini göster'), 'zaman kırılımında eğri yok');
  assert.ok(!c.kurucuKartHtml(hiz({ egri: [{ anahtar: 'x', gun: [], oran: [] }] }), null, 0).includes('Kapanma eğrisini göster'), 'n<5 grup eğrisi gelmez');
  assert.ok(!c.kurucuKartHtml(zarfBasari({ egri }), null, 0).includes('Kapanma eğrisini göster'));
});

test('kart_tedavi_degisti_dipnotu_zarftan', () => {
  const { c } = kartYukle();
  const dip = '9 vaka 24 saat içinde yeniden açıldı (tedavi değişti).';
  const h = c.kurucuKartHtml(zarfBasari({ sayac: { tedavi_degisti_n: 9, kiyas_n: 22 }, dipnot: ['Ovsync dipnot.', dip] }), null, 0);
  assert.ok(h.includes(`<li>${dip}</li>`) && h.includes('<li>Ovsync dipnot.</li>'));
  const dipsiz = c.kurucuKartHtml(zarfBasari({ sayac: { tedavi_degisti_n: 9, kiyas_n: 22 }, dipnot: [] }), null, 0);
  assert.ok(!dipsiz.includes('yeniden açıldı') && !dipsiz.includes('atolye-dipnot'), 'ekranda yeniden üretilmez');
  assert.ok(!/basarisiz_|SONUC_ETIKETLERI/.test(oku(DOSYA)), 'sonuç listesi modüle kopyalanmaz');
});

test('kart_doz_durum', () => {
  const { c } = kartYukle();
  const h = c.kurucuKartHtml({ olcum: 'doz' }, null, 9);
  assert.ok(h.includes('atolye-kart-baslik">Doz<') && h.includes(kacis(c.dozMetni())) && !h.includes('<canvas'));
});

test('kart_rozet_cok_grup', () => {
  const { c } = kartYukle(cumleOrnek());
  const z = zarfBasari({ x: { ad: 'grup', deger: ['A', 'B', 'C'], anahtar: ['a', 'b', 'c'] },
    seriler: [{ n: [9, 8, 7], k: [1, 1, 1], y: [1, 2, 3] }], sayac: { kiyas_n: 8 } });
  const h = c.kurucuKartHtml(z, null, 0);
  assert.ok(h.includes('atolye-rozet">3 grup<'));
  assert.strictEqual((h.match(/data-kurucu-vakalar=/g) || []).length, 3, 'grup başına iz bağlantısı');
});

// ── Plan Step 1: kaydet + yarış ──
test('kaydet_yuku_gecicisiz', async () => {
  const { c, s, cagri, belge } = yukle();
  s.cumle = cumleOrnek();
  s.secenekler = SECENEK;
  s.gecici = { ilac_fiyat: { 'stok-1': 12.5 } };
  c._kurucuKabuk();
  await c.kurucuKaydet();                                  // 1. basış: satır içi başlık alanı açılır, kayıt yok
  assert.strictEqual(cagri.kaydet.length, 0);
  const alan = belge.getElementById('atolye-kaydet-baslik');
  alan.value = '  ';
  await c.kurucuKaydet();
  assert.strictEqual(cagri.kaydet.length, 1);
  const [id, baslik, cumle] = cagri.kaydet[0];
  assert.strictEqual(id, null);
  assert.strictEqual(baslik, c.cumleBaslik(s.cumle, SECENEK), 'boş başlık → cumleBaslik');
  assert.ok(!Object.prototype.hasOwnProperty.call(cumle, 'gecici'));
  assert.ok(!JSON.stringify(cagri.kaydet[0]).includes('stok-1'), 'geçici değer yükte yok');
  assert.deepStrictEqual(cagri.toast[0], ['Panoya kaydedildi', false]);
  assert.ok(!/\bprompt\s*\(/.test(oku(DOSYA)), 'prompt yok');
});

test('kaydet_cift_basis_tek_kayit_ve_hata_seridi', async () => {
  const { c, s, cagri, belge } = yukle();
  s.cumle = cumleOrnek(); s.secenekler = SECENEK;
  c._kurucuKabuk();
  await c.kurucuKaydet();
  belge.getElementById('atolye-kaydet-baslik').value = 'Başlığım';
  await Promise.all([c.kurucuKaydet(), c.kurucuKaydet()]);
  assert.strictEqual(cagri.kaydet.length, 1, 'çift basış tek kayıt');
  assert.strictEqual(cagri.kaydet[0][1], 'Başlığım');
  c.statGrafikKaydet = async () => { throw new Error('STAT_CUMLE:donem:ters'); };
  await c.kurucuKaydet();
  belge.getElementById('atolye-kaydet-baslik').value = 'x';
  await c.kurucuKaydet();
  assert.deepStrictEqual(cagri.serit, ['STAT_CUMLE:donem:ters']);
});

test('kaydet_alani_geri_ile_kapanir_eski_baslik_kalmaz', async () => {
  const { c, s, cagri, belge } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  await c.kurucuSlotDegis('donem', { tip: 'son_ay', n: 24 });
  await c.kurucuKaydet();
  const alan = belge.getElementById('atolye-kaydet-baslik');
  assert.ok(alan, 'alan açık');
  alan.value = c.cumleBaslik(s.cumle, s.secenekler);              // 24 aylık cümlenin başlığı
  await c.kurucuSlotDegis('geri', null);
  assert.strictEqual(s.cumle.donem.n, 12);
  assert.strictEqual(belge.getElementById('atolye-kaydet-baslik'), null, 'geri alan kapatır');
  await c.kurucuKaydet();
  const h = c.kurucuCumlePanelHtml(s.cumle, s.secenekler);
  assert.ok(h.includes(`value="${c.escAttr(c.cumleBaslik(s.cumle, s.secenekler))}"`), 'yeni cümlenin başlığı');
  assert.ok(!h.includes('son 24 ay'), 'eski başlık yok');
  assert.strictEqual(cagri.kaydet.length, 0);
});

test('kaydet_durumu_kurucu_acilinca_sifirlanir', async () => {
  const { c, s, belge } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  await c.kurucuKaydet();
  belge.getElementById('atolye-kaydet-baslik').value = 'Eski başlık';
  belge.kok.innerHTML = '<div class="atolye-pano">PANO</div>';    // pano'ya geçildi: alan DOM'dan gitti
  const pano = cumleOrnek({ kirilim: 'yil' });
  await c.kurucuAc(pano);                                         // "Kurucuda aç"
  assert.strictEqual(belge.getElementById('atolye-kaydet-baslik'), null, 'alan açık gelmez');
  const h = c.kurucuCumlePanelHtml(pano, s.secenekler);
  assert.ok(!h.includes('atolye-kaydet-baslik') && !h.includes('Eski başlık'));
});

test('yaris_eski_yanit_yazilmaz', async () => {
  const bekleyen = [];
  const { c, s, belge } = yukle({
    statAtolyeSeri: cu => new Promise(res => bekleyen.push({ cu, res })),
  });
  s.cumle = cumleOrnek();
  const ilk = c.kurucuYenile();
  s.cumle = cumleOrnek({ kirilim: 'yok' });
  const ikinci = c.kurucuYenile();
  assert.strictEqual(bekleyen.length, 2);
  bekleyen[1].res({ zarflar: [zarfBasari({ dipnot: ['YENI'] })], kombinasyon: null, fiyat_eksik: [] });
  await ikinci;
  bekleyen[0].res({ zarflar: [zarfBasari({ dipnot: ['ESKI'] })], kombinasyon: null, fiyat_eksik: [] });
  await ilk;
  const h = belge.getElementById('atolye-kartlar').innerHTML;
  assert.ok(h.includes('YENI') && !h.includes('ESKI'), 'eski yanıt yazılmadı');
  assert.strictEqual(JSON.stringify(s.sonZarflar[0].dipnot), '["YENI"]');
});

test('yaris_sekme_degisince_pano_ezilmez', async () => {
  let bitir;
  const { c, s, belge, cagri } = yukle({ statAtolyeSeri: () => new Promise(res => { bitir = res; }) });
  s.cumle = cumleOrnek();
  const p = c.kurucuYenile();
  belge.kok.innerHTML = '<div class="atolye-pano">PANO</div>';     // panoYukle içeriği değiştirdi
  bitir({ zarflar: [zarfBasari()], kombinasyon: null, fiyat_eksik: [] });
  await p;
  assert.ok(belge.kok.innerHTML.includes('PANO'));
  assert.strictEqual(cagri.cizim.length, 0);
  assert.strictEqual(cagri.temiz, 0);
});

// ── Akış ──
test('ac_null_varsayilan_tumu_son12_ile', async () => {
  const { c, s, cagri } = yukle();
  await c.kurucuAc(null);
  const tohum = cagri.secenek[0];
  assert.strictEqual(tohum.hastalik.tip, 'tumu');
  assert.strictEqual(tohum.donem.n, 12);
  assert.strictEqual(s.cumle.hastalik.deger, ID, 'en çok vakalı hastalık');
  assert.strictEqual(s.cumle.kirilim, 'ilac');
  assert.strictEqual(cagri.seri.length, 1, 'kurucuYenile çağrıldı');
  assert.strictEqual(JSON.stringify(cagri.seri[0][0]), JSON.stringify(s.cumle));
});

test('ac_verilen_cumle_yigini_sifirlar_ayni_cumle_korur', async () => {
  const { c, s } = yukle();
  const a = cumleOrnek();
  await c.kurucuAc(a);
  assert.strictEqual(s.cumle, a);
  await c.kurucuSlotDegis('kirilim', 'ay');
  assert.strictEqual(s.onceki.length, 1);
  await c.kurucuAc(s.cumle);                                  // sekme dönüşü: aynı cümle
  assert.strictEqual(s.onceki.length, 1, 'yığın korunur');
  const pano = cumleOrnek({ kirilim: 'yil' });
  s.cumle = pano;                                             // T15: _atolye.cumle yazıp atolyeSekme
  await c.kurucuAc(pano);
  assert.strictEqual(s.onceki.length, 0, 'başka cümle: yığın sıfır');
});

test('ac_hata_seridi_yeniden_dene', async () => {
  const { c, cagri, belge } = yukle({ statAtolyeSecenekler: async () => { throw new Error('İnternet bağlantısı gerekli'); } });
  await c.kurucuAc(null);
  assert.deepStrictEqual(cagri.serit, ['İnternet bağlantısı gerekli']);
  const h = belge.getElementById('atolye-kartlar').innerHTML;
  assert.ok(!h.includes('class="loader"') && h.includes('data-kurucu-eylem="yenile"'), 'çark kalmaz, yeniden dene var');
});

test('slot_yigin_geri', async () => {
  const { c, s, cagri } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuSlotDegis('donem', { tip: 'son_ay', n: 24 });
  assert.strictEqual(s.cumle.donem.n, 24);
  assert.strictEqual(s.onceki.length, 1);
  assert.strictEqual(cagri.seri.length, 1);
  await c.kurucuSlotDegis('donem', { tip: 'son_ay', n: 24 });  // aynı değer
  assert.strictEqual(s.onceki.length, 1, 'değişmeyen seçim yığına girmez');
  assert.strictEqual(cagri.seri.length, 1);
  await c.kurucuSlotDegis('geri', null);
  assert.strictEqual(s.cumle.donem.n, 12);
  assert.strictEqual(s.onceki.length, 0);
  assert.strictEqual(cagri.seri.length, 2);
  await c.kurucuSlotDegis('geri', null);                       // boş yığın
  assert.strictEqual(cagri.seri.length, 2);
});

test('slot_cumle_disi_yigina_girmez', async () => {
  const eksik = [{ stok_id: 'a' }];
  const { c, s, cagri, belge } = yukle({
    statAtolyeSeri: async (cu, g, o) => { cagri2.seri.push([cu, g, o]); return { zarflar: [zarfBasari()], kombinasyon: null, fiyat_eksik: eksik }; },
  });
  const cagri2 = cagri;
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const adet = cagri.seri.length;
  assert.strictEqual(belge.getElementById('atolye-fiyat-alan').hidden, true, 'panel eylemle açılır');
  await c.kurucuSlotDegis('fiyat_panel', null);
  const f = belge.getElementById('atolye-fiyat-alan');
  assert.strictEqual(f.hidden, false);
  assert.strictEqual(f.kaydirma, 1, 'fiyat paneline kaydırır');
  await c.kurucuSlotDegis('kombinasyon', null);
  assert.deepStrictEqual(cagri.toast[0], ['İlaç seçin', false], 'x yoksa ipucu');
  assert.strictEqual(belge.getElementById('atolye-komb-alan').kaydirma, 0);
  s.cumle = cumleOrnek({ ilac: { duzey: 'etken', x: 'A', y: null }, kirilim: 'yok' });
  await c.kurucuSlotDegis('kombinasyon', null);
  assert.strictEqual(belge.getElementById('atolye-komb-alan').kaydirma, 1, 'kombinasyona kaydırır');
  assert.strictEqual(s.onceki.length, 0, 'yığına girmez');
  assert.strictEqual(cagri.seri.length, adet, 'RPC yok');
  await c.kurucuYenile();
  assert.strictEqual(belge.getElementById('atolye-fiyat-alan').hidden, false, 'yeniden çizimde açık kalır');
});

test('slot_fiyat_panel_eksik_yoksa_olu_panel_acilmaz', async () => {
  const { c, s, cagri, belge } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  await c.kurucuSlotDegis('fiyat_panel', null);
  assert.strictEqual(belge.getElementById('atolye-fiyat-alan').hidden, true);
  assert.strictEqual(cagri.toast[0][0], 'Bu seçimde fiyatı girilebilecek ilaç yok');
});

test('slot_doz_rpc_cagirmaz_cumleye_girmez', async () => {
  const { c, s, cagri, belge } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const adet = cagri.seri.length;
  const once = JSON.stringify(s.cumle);
  await c.kurucuSlotDegis('doz', true);
  assert.strictEqual(cagri.seri.length, adet, 'P8: RPC yok');
  assert.strictEqual(JSON.stringify(s.cumle), once, 'cümleye girmez');
  const doz = belge.getElementById('atolye-doz-alan');   // TF G7: kart kendi alanına yazılır, kartlar yeniden çizilmez
  assert.ok(doz.innerHTML.includes(kacis(c.dozMetni())));
  assert.strictEqual(doz.hidden, false);
  await c.kurucuSlotDegis('doz', false);
  assert.ok(!doz.innerHTML.includes(kacis(c.dozMetni())));
  assert.strictEqual(doz.hidden, true, 'kapalıyken ızgarada boşluk bırakmaz');
});

test('yenile_parametre_ve_paneller', async () => {
  const { c, s, cagri, belge } = yukle({
    statAtolyeSeri: async (cu, g, o) => { cagri_.seri.push([cu, g, o]); return { zarflar: [zarfBasari()], kombinasyon: { x: 'X1' }, fiyat_eksik: [{ stok_id: 'a' }] }; },
  });
  const cagri_ = cagri;
  s.cumle = cumleOrnek();
  await c.kurucuYenile({ yenile: true });
  assert.strictEqual(cagri.seri[0][1], s.gecici, 'geçici yalnız parametre');
  assert.strictEqual(cagri.seri[0][2].yenile, true);
  assert.strictEqual(cagri.invalidate, 1, 'Yeniden hesapla seçenek önbelleğini de boşaltır');
  assert.strictEqual(cagri.fiyatDeger, s.gecici);
  const h = belge.getElementById('atolye-kartlar').innerHTML;
  assert.ok(h.includes('X1') && h.includes('atolye-fiyat'));
  assert.strictEqual(cagri.kombBagla, belge.getElementById('atolye-komb-alan'), 'bağlama taze alanda');
  assert.strictEqual(cagri.fiyatBagla, belge.getElementById('atolye-fiyat-alan'));
  assert.strictEqual(cagri.temiz, 1);
  await c.kurucuYenile();
  assert.strictEqual(cagri.invalidate, 1, 'normal yenile önbelleği boşaltmaz');
});

test('hata_cevrimdisi_son_kartlar_silinmez', async () => {
  const { c, s, cagri, belge } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const onceki = belge.getElementById('atolye-kartlar').innerHTML;
  assert.ok(onceki.includes('atolye-kart'));
  c.statAtolyeSeri = async () => { throw new Error('İnternet bağlantısı gerekli'); };
  await c.kurucuYenile();
  const k = belge.getElementById('atolye-kartlar');
  assert.strictEqual(k.innerHTML, onceki, 'kartlar kalır');
  assert.ok(!k.classList.contains('atolye-pasif'), 'bekleme işareti kalkar');
  assert.deepStrictEqual(cagri.serit, ['İnternet bağlantısı gerekli']);
});

test('grafik_sizinti_yok_ve_egri_gecis', async () => {
  const { c, s, cagri } = yukle({
    statAtolyeSeri: async () => ({ zarflar: [zarfBasari({ olcum: 'saglik_kapanma_gunu', seriler: [{ n: [21, 22], y: [8, 9], q1: [6, 6], q3: [11, 12] }],
      egri: [{ anahtar: 'x', gun: [1, 2], oran: [0.5, 1] }] })], kombinasyon: null, fiyat_eksik: [] }),
  });
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const [cv1, cfg1] = cagri.cizim[0];
  assert.strictEqual(cfg1.type, 'bar');
  await c.kurucuYenile();
  assert.strictEqual(cv1.yokEdildi, 1, 'önceki Chart yok edildi');
  c._kurucuEgriDegis(true);
  const son = cagri.cizim[cagri.cizim.length - 1][1];
  assert.strictEqual(son.data.datasets[0].stepped, true, 'eğri çizimi');
  c._kurucuEgriDegis(false);
  assert.strictEqual(cagri.cizim[cagri.cizim.length - 1][1].type, 'bar');
});

test('vakalar_liste_sonuc_durumla_ve_bilinmeyen', async () => {
  const satirlar = [
    { kupe_no: '<b>K1', hastalik: 'Enterit', baslangic: '2026-01-02', kapanis: '2026-01-09', durum: 'sonuclandi', sonuc: 'basarili', kapanma_vekil: false },
    { kupe_no: 'K2', hastalik: 'Enterit', baslangic: '2026-01-03', kapanis: '2026-01-10', durum: 'sonuclandi', sonuc: 'basarisiz_tedavi_degisti', kapanma_vekil: true },
    { kupe_no: 'K3', hastalik: 'Enterit', baslangic: '2026-01-04', kapanis: null, durum: 'acik', sonuc: null, kapanma_vekil: false },
    { kupe_no: 'K4', hastalik: 'Enterit', baslangic: '2026-01-05', kapanis: null, durum: 'kapali_tarihsiz', sonuc: null, kapanma_vekil: false },
    { kupe_no: 'K5', hastalik: 'Enterit', baslangic: '2026-01-06', kapanis: '2026-01-07', durum: 'sonuclandi', sonuc: '<yeni_sonuc>', kapanma_vekil: false },
  ];
  const { c, s, cagri, belge } = yukle({ statAtolyeVakalar: async (cu, g) => { cagri2.vakalar.push(g); return { toplam: 350, vakalar: satirlar }; } });
  const cagri2 = cagri;
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  await c.kurucuVakalarAc('x');
  assert.deepStrictEqual(cagri.vakalar, ['x']);
  const alan = belge.getElementById('atolye-vakalar-alan');
  assert.strictEqual(alan.hidden, false);
  const h = alan.innerHTML;
  assert.ok(h.includes('&lt;b&gt;K1') && !h.includes('<b>K1'));
  assert.ok(h.includes('Başarılı') && h.includes('Başarısız (tedavi değişti)') && h.includes('Açık') && h.includes('Kapanış tarihi yok'));
  assert.ok(h.includes('≈ 10.01.2026'), 'vekil işareti');
  assert.ok(h.includes('Diğer') && h.includes('&lt;yeni_sonuc&gt;'), 'bilinmeyen sonuç gizlenmez, uyarı');
  assert.ok(h.includes('ilk 5 / 350'), 'kesilen liste');
  assert.ok(!h.includes('basarisiz_tedavi_degisti'), 'ham değer basılmaz');
});

test('vakalar_basarida_hata_seridi_temizlenir', async () => {
  let dusur = true;
  const { c, s, cagri } = yukle({ statAtolyeVakalar: async () => {
    if (dusur) throw new Error('İnternet bağlantısı gerekli');
    return { toplam: 0, vakalar: [] };
  } });
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const once = cagri.temiz;
  await c.kurucuVakalarAc('x');
  assert.deepStrictEqual(cagri.serit, ['İnternet bağlantısı gerekli']);
  assert.strictEqual(cagri.temiz, once, 'hatada temizlenmez');
  dusur = false;
  await c.kurucuVakalarAc('x');
  assert.strictEqual(cagri.temiz, once + 1, 'başarıda şerit + bayat kalkar');
});

// Kapı F3 B1: çevrimdışı cümle değişimi. Kartlar eski cümlenin, panel yeninin; başarı uyarıyı kaldırmaz, liste kartın cümlesiyle.
async function bayatKartKur(ek = {}) {
  const sorgu = [];
  const y = yukle({ statAtolyeVakalar: async (cu, g) => { sorgu.push([cu, g]); return { toplam: 0, vakalar: [] }; }, ...ek });
  y.s.cumle = cumleOrnek();
  y.s.secenekler = SECENEK;
  await y.c.kurucuYenile();
  const kartCumle = y.s.cumle;
  const seriOrj = y.c.statAtolyeSeri;
  y.c.statAtolyeSeri = async () => { throw new Error('İnternet bağlantısı gerekli'); };
  await y.c.kurucuSlotDegis('kirilim', 'yok');
  assert.notStrictEqual(y.s.cumle, kartCumle, 'panel yeni cümlede');
  return { ...y, sorgu, kartCumle, seriOrj, temizOnce: y.cagri.temiz };
}

test('b1_vakalar_kartin_cumlesiyle_sorgular', async () => {
  const { c, sorgu, kartCumle } = await bayatKartKur();
  await c.kurucuVakalarAc('tumu');
  assert.strictEqual(sorgu.length, 1);
  assert.strictEqual(sorgu[0][0], kartCumle, 'liste kartların cümlesini gösterir, panelinkini değil');
  assert.strictEqual(sorgu[0][1], 'tumu');
});

test('b1_vakalar_basarisi_bayat_uyarisini_kaldirmaz', async () => {
  const { c, cagri, temizOnce, s, kartCumle } = await bayatKartKur();
  assert.deepStrictEqual(cagri.serit, ['İnternet bağlantısı gerekli']);
  await c.kurucuVakalarAc('tumu');
  assert.strictEqual(cagri.temiz, temizOnce, 'kartlar panelin cümlesinde değil: uyarı kalır');
  assert.notStrictEqual(s.cumle, kartCumle);
});

test('b1_kaydet_basarisi_bayat_uyarisini_kaldirmaz_kart_tazeyken_kaldirir', async () => {
  const { c, cagri, temizOnce, belge, seriOrj, s, sorgu } = await bayatKartKur();
  await c.kurucuKaydet();
  belge.getElementById('atolye-kaydet-baslik').value = 'Başlık';
  await c.kurucuKaydet();
  assert.strictEqual(cagri.kaydet.length, 1);
  assert.strictEqual(cagri.kaydet[0][2], s.cumle, 'kayıt panelin cümlesi');
  assert.strictEqual(cagri.temiz, temizOnce, 'kaydet başarısı eski kartların uyarısını kaldırmaz');

  c.statAtolyeSeri = seriOrj;                             // bağlantı döndü, yeni cümle çizildi
  await c.kurucuYenile();
  const taze = cagri.temiz;
  await c.kurucuVakalarAc('x');
  assert.strictEqual(sorgu[0][0], s.cumle, 'taze kartta liste güncel cümleyle');
  assert.strictEqual(cagri.temiz, taze + 1, 'kart ve panel aynı cümlede: uyarı kalkar');
  await c.kurucuKaydet();
  belge.getElementById('atolye-kaydet-baslik').value = 'İkinci';
  await c.kurucuKaydet();
  assert.strictEqual(cagri.temiz, taze + 2, 'kaydet de kaldırır');
});

test('vakalar_eski_yanit_yazilmaz', async () => {
  let bitir;
  const { c, s, belge } = yukle({ statAtolyeVakalar: () => new Promise(r => { bitir = r; }) });
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const p = c.kurucuVakalarAc('x');
  await c.kurucuYenile();                                       // cümle/kart yenilendi
  bitir({ toplam: 1, vakalar: [{ kupe_no: 'ESKI', durum: 'acik', sonuc: null }] });
  await p;
  assert.ok(!belge.getElementById('atolye-vakalar-alan').innerHTML.includes('ESKI'));
});

test('donem_tum_zamanlar_cipi_secilir_geri_doner', async () => {
  const { c, s, cagri } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const taban = cagri.seri.length;
  const h = c.kurucuCumlePanelHtml(s.cumle, SECENEK);
  const cip = h.match(/data-kurucu-slot="donem"[^>]*data-deger="([^"]*)"[^>]*>Tüm zamanlar</);
  assert.ok(cip, 'çip tıklanabilir donem slotunda');
  const deger = cip[1].replace(/&quot;|&#34;/g, '"');
  const hedef = dataset => { const t = { dataset }; return { target: { closest: () => t } }; };
  await c._kurucuTikla(hedef({ kurucuSlot: 'donem', deger }));
  assert.deepStrictEqual(JSON.parse(JSON.stringify(s.cumle.donem)), { tip: 'tumu' });
  assert.strictEqual(cagri.seri.length, taban + 1, 'yeni dönemle hesap');
  assert.strictEqual(JSON.stringify(cagri.seri[taban][0].donem), '{"tip":"tumu"}', 'RPC cümlesi');
  assert.ok(c.cumleBaslik(s.cumle, SECENEK).endsWith(' › tüm zamanlar'));
  await c.kurucuSlotDegis('geri', null);
  assert.deepStrictEqual(JSON.parse(JSON.stringify(s.cumle.donem)), { tip: 'son_ay', n: 12 }, 'Geri önceki döneme');
});

test('donem_tum_zamanlar_hastalik_listesi_suzgecsiz_sayilir', async () => {
  const { c, s, cagri } = yukle();
  const dar = { donem: { bas: '2026-06-27', bit: '2026-10-31' }, hastaliklar: [{ id: 'E', ad: 'Enterit', n: 18 }, { id: 'B', ad: 'Buzağı İshali', n: 17 }], kategoriler: [{ ad: 'Sindirim', n: 35 }], x_adaylari: [{ deger: 'Enrofloksasin', n: 16 }], y_adaylari: [] };
  const genis = { donem: { bas: '2024-01-01', bit: '2026-10-31' }, hastaliklar: [{ id: 'E', ad: 'Enterit', n: 18 }, { id: 'B', ad: 'Buzağı İshali', n: 22 }, { id: 'A', ad: 'Anoestrus', n: 1 }], kategoriler: [{ ad: 'Sindirim', n: 40 }, { ad: 'Üreme', n: 1 }], x_adaylari: [{ deger: 'BASKA', n: 99 }], y_adaylari: [] };
  c.statAtolyeSecenekler = async cu => { cagri.secenek.push(cu); return cu.hastalik.tip === 'tumu' ? genis : dar; };
  const h = { tip: 'hastalik', deger: '11111111-1111-4111-8111-111111111111' };

  s.cumle = cumleOrnek({ hastalik: h, donem: { tip: 'tumu' } });
  await c.kurucuYenile();
  assert.deepStrictEqual(cagri.secenek.map(cu => cu.hastalik.tip).sort(), ['hastalik', 'tumu']);
  assert.strictEqual(JSON.stringify(s.secenekler.hastaliklar), JSON.stringify(genis.hastaliklar), 'hastalık listesi tüm geçmiş');
  assert.strictEqual(JSON.stringify(s.secenekler.kategoriler), JSON.stringify(genis.kategoriler), 'kategori listesi tüm geçmiş');
  assert.strictEqual(JSON.stringify(s.secenekler.x_adaylari), JSON.stringify(dar.x_adaylari), 'ilaç adayları seçili hastalıktan');
  assert.strictEqual(JSON.stringify(s.secenekler.donem), JSON.stringify(dar.donem), 'dönem seçili hastalıktan');
  assert.strictEqual(s.cumle.hastalik.tip, 'hastalik', 'cümle değişmez');

  cagri.secenek.length = 0;
  s.cumle = cumleOrnek({ hastalik: h });
  await c.kurucuYenile();
  assert.strictEqual(cagri.secenek.length, 1, 'başka dönemde tek sorgu');
  assert.strictEqual(s.secenekler, dar);

  cagri.secenek.length = 0;
  s.cumle = cumleOrnek({ hastalik: { tip: 'tumu', deger: null }, donem: { tip: 'tumu' } });
  await c.kurucuYenile();
  assert.strictEqual(cagri.secenek.length, 1, 'süzgeç yoksa tek sorgu');
});

test('olay_tikla_slot_json_ve_eylemler', async () => {
  const { c, s, cagri } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const hedef = dataset => { const t = { dataset }; return { target: { closest: () => t } }; };
  await c._kurucuTikla(hedef({ kurucuSlot: 'donem', deger: '{"n":24,"tip":"son_ay"}' }));
  assert.strictEqual(s.cumle.donem.n, 24);
  await c._kurucuTikla(hedef({ kurucuVakalar: 'ilac:A"b' }));
  assert.deepStrictEqual(cagri.vakalar, ['ilac:A"b']);
  cagri.seri.length = 0;
  await c._kurucuTikla(hedef({ kurucuEylem: 'yenile' }));
  assert.strictEqual(cagri.seri[0][2].yenile, true);
  await c._kurucuTikla(hedef({ kurucuEylem: 'aralik' }));
  assert.deepStrictEqual(JSON.parse(JSON.stringify(s.cumle.donem)), { tip: 'aralik', bas: '2025-10-31', bit: '2026-10-31' }, 'aralık geçerli başlar');
  assert.doesNotThrow(() => c._kurucuTikla({ target: { closest: () => null } }));
});

test('olay_degis_select_olcu_tarih', async () => {
  const { c, s } = yukle();
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  await c._kurucuDegis({ target: { dataset: { kurucuSlot: 'x' }, value: '"Enrofloksasin"' } });
  assert.strictEqual(s.cumle.ilac.x, 'Enrofloksasin');
  assert.strictEqual(s.cumle.kirilim, 'yok', 'P4');
  await c._kurucuDegis({ target: { dataset: { kurucuSlot: 'x' }, value: 'null' } });
  assert.strictEqual(s.cumle.ilac.x, null);
  await c._kurucuDegis({ target: { dataset: { kurucuOlcu: 'saglik_kapanma_gunu' }, checked: false } });
  assert.deepStrictEqual(Array.from(s.cumle.olculer), ['saglik_basari', 'saglik_vaka_tl']);
  await c._kurucuDegis({ target: { dataset: { kurucuOlcu: 'saglik_kapanma_gunu' }, checked: true } });
  assert.deepStrictEqual(Array.from(s.cumle.olculer), ['saglik_basari', 'saglik_kapanma_gunu', 'saglik_vaka_tl'], 'sabit sıra');
  await c._kurucuDegis({ target: { dataset: { kurucuOlcu: 'doz' }, checked: true } });
  assert.ok(!s.cumle.olculer.includes('doz'), 'doz cümleye girmez');
  await c._kurucuDegis({ target: { dataset: { kurucuOlcu: 'doz' }, checked: false } });
  s.cumle = cumleOrnek({ donem: { tip: 'aralik', bas: '2026-01-01', bit: '2026-02-01' } });
  await c._kurucuDegis({ target: { dataset: { kurucuTarih: 'bit' }, value: '2026-03-01' } });
  assert.strictEqual(s.cumle.donem.bit, '2026-03-01');
  assert.strictEqual(s.cumle.donem.bas, '2026-01-01');
});

test('olay_aralik_takvim_kanonik_secici', async () => {
  const { c, s, belge } = yukle();
  s.cumle = cumleOrnek({ donem: { tip: 'aralik', bas: '2026-01-01', bit: '2026-02-01' } });
  await c.kurucuYenile();
  assert.ok(belge.getElementById('atolye-aralik-bas'));
  await c._kurucuTikla({ target: { closest: () => ({ dataset: { kurucuEylem: 'tarih', alan: 'bit' } }) } });
  assert.strictEqual(c._takvim.el, belge.getElementById('atolye-aralik-bit'));
  assert.strictEqual(c._takvim.o.min, '2026-01-01');
  assert.strictEqual(c._takvim.o.max, 'bugun');
  await c._kurucuTikla({ target: { closest: () => ({ dataset: { kurucuEylem: 'tarih', alan: 'bas' } }) } });
  assert.strictEqual(c._takvim.o.max, '2026-02-01');
});

test('telefon_katlama', async () => {
  const { c, s, belge } = yukle();
  s.cumle = cumleOrnek();
  const h = c.kurucuCumlePanelHtml(s.cumle, SECENEK);
  assert.ok(/class="atolye-cumle-panel katli"/.test(h), 'telefonda katlı başlar (.katli yalnız ≤600 px etkili)');
  assert.ok(h.includes('atolye-katla') && h.includes('Cümleyi düzenle'));
  await c.kurucuYenile();
  await c._kurucuTikla({ target: { closest: () => ({ dataset: { kurucuEylem: 'katla' } }) } });
  assert.ok(!/class="atolye-cumle-panel katli"/.test(c.kurucuCumlePanelHtml(s.cumle, SECENEK)));
  assert.ok(belge.getElementById('atolye-cumle-panel'));
});

test('yasak_kelime_renk_stil', () => {
  const m = oku(DOSYA);
  assert.ok(!/protokol/i.test(m));
  assert.ok(!/sağla|etkili|karşılığı/i.test(m));
  assert.ok(!/#[0-9a-f]{3,6}\b/i.test(m), 'sabit hex yok');
  assert.ok(!/style="/.test(m), 'satır içi stil yok');
  assert.ok(!/var\(--red\)/.test(m));
  assert.ok(!/localStorage|indexedDB|sessionStorage/.test(m), 'geçici değer depolanmaz');
  assert.ok(!/sonucEtiket\(\s*\w+(\.\w+)?\s*\)/.test(m), 'sonucEtiket her çağrıda durum alır');
  assert.ok(/sonucEtiket\(v\.sonuc, v\.durum\)/.test(m));
});

// ── TFA G1-G3 ──
const ILAC_X = l => ({ ad: 'grup', deger: l.map(a => `${a} içeren`), anahtar: l.map(a => `ilac:${a}`) });
const ilacZarf = d => zarfBasari({ n: 16, x: ILAC_X(['Enro', 'Flu<b>', 'Melo', 'Tilmi']),
  seriler: [{ ad: 'başarı %', n: [16, 4, 6, 1], k: [13, 4, 4, 1], y: [81.3, null, 66.7, null], alt: [57, null, 30, null], ust: [93, null, 90, null] }],
  sayac: { kiyas_n: 4 }, ...d });
const ayrinti = h => {
  const bas = '<details class="atolye-ayrinti"><summary>Ayrıntı</summary>';
  assert.strictEqual((h.match(/<details/g) || []).length, 1, 'tek kapalı alan, iç içe yok');
  assert.ok(h.includes(bas), 'kapalı Ayrıntı');
  return { once: h.slice(0, h.indexOf(bas)), ic: h.slice(h.indexOf(bas), h.indexOf('</details>')) };
};

test('kart_ilac_rozet_veri_az_satiri', () => {
  const { c } = kartYukle(cumleOrnek());
  const h = c.kurucuKartHtml(ilacZarf(), TANIM_BASARI, 0);
  assert.ok(h.includes('atolye-rozet">2/4 ilaçta yeterli veri<'));
  assert.ok(h.includes('<div class="atolye-veri-az">2 ilaçta veri az (&lt;5 vaka): Flu&lt;b&gt; 4 · Tilmi 1</div>'));
  assert.ok(!h.includes('yetersiz (n='), 'grup başına eski metin yok');
  assert.ok(!/<b>/.test(h), 'grup adı kaçışlı');
  assert.strictEqual((h.match(/data-kurucu-vakalar=/g) || []).length, 4, 'az gruplar da vaka listesine ulaşır');
  assert.strictEqual(ayrinti(h).once.includes('atolye-veri-az'), true, 'veri az satırı görünür alanda');
});

test('kart_ilac_yeterli_grup_yok_yetersiz_durumu', () => {
  const { c } = kartYukle(cumleOrnek());
  const z = ilacZarf({ n: 4, seriler: [{ ad: 'b', n: [4, 3, 2, 1], k: [1, 1, 1, 1], y: [null, null, null, null] }] });
  const h = c.kurucuKartHtml(z, TANIM_BASARI, 0);
  assert.ok(!h.includes('<canvas') && h.includes('Yetersiz veri (n=4) — en az 5 vaka gerekir'));
  assert.ok(h.includes('atolye-rozet">0/4 ilaçta yeterli veri<'));
  assert.ok(!h.includes('atolye-veri-az'), 'mevcut yetersiz durumu aynen');
});

test('kart_kiyas_rozet_ve_siniflar_eski_metin', () => {
  const { c } = kartYukle();
  const z = zarfBasari({ n: 21, seriler: [{ n: [21, 3], k: [17, 2], y: [81, null], alt: [1, null], ust: [2, null] }], sayac: { kiyas_n: 3 } });
  const h = c.kurucuKartHtml(z, null, 0);
  assert.ok(h.includes('atolye-rozet">n=21 / n=3<'));
  assert.ok(h.includes('<div class="atolye-veri-az">Tüm Enterit vakaları yetersiz (n=3)</div>'));
});

test('kart_gorunur_alan_sade_ayrinti_kapali', () => {
  const { c } = kartYukle();
  const dip = '9 vaka 24 saat içinde yeniden açıldı (tedavi değişti).';
  const z = zarfBasari({ sayac: { acik_n: 3, olgunlasmamis_n: 2, kiyas_n: 22 }, dipnot: ['Ovsync dipnot.', dip] });
  const { once, ic } = ayrinti(c.kurucuKartHtml(z, TANIM_BASARI, 0));
  assert.ok(once.includes('<canvas') && once.includes('atolye-ozet'));
  for (const m of ['açık vaka', '30 gün dolmadı', 'atolye-dipnot', 'Hesap tarihi', 'Tanım metni', 'Bu sayıya giren vakalar', 'data-kurucu-vakalar']) {
    assert.ok(!once.includes(m), `görünür alanda olmamalı: ${m}`);
    assert.ok(ic.includes(m), `Ayrıntı içinde olmalı: ${m}`);
  }
  assert.ok(ic.includes(`<li>${dip}</li>`) && ic.includes('<li>Ovsync dipnot.</li>'), 'tedavi değişti ayrı madde');
  assert.strictEqual((ic.match(/Hesap tarihi/g) || []).length, 1, 'hesap tarihi bir kez');
  assert.ok(!/\sopen\b/.test(ic), 'kapalı başlar');
  assert.ok(!/style=/.test(once + ic), 'satır içi stil yok');
});

// S4: örtüşme/gözlemsel dipnotu kapalı Ayrıntı'ya gömülmez; metin sunucudan, süzgeç JS'te.
const ORTUS = 'Gruplar örtüşür: bir vaka birden çok satırda sayılır.';
const GOZLEM = 'Karşılaştırma gözlemseldir; şiddet/yaş eşleştirmesi yok.';
test('kart_gozlem_uyarisi_gorunur_ayrintida_tekrarlanmaz', () => {
  const { c } = kartYukle();
  const z = zarfBasari({ dipnot: ['Ovsync dipnot.', ORTUS, '3 vaka tedavi değişti.', GOZLEM] });
  const { once, ic } = ayrinti(c.kurucuKartHtml(z, TANIM_BASARI, 0));
  const ozet = `<div class="atolye-ozet">${kacis(c.zarfOzetCumle(z))}</div>`;
  assert.ok(once.includes(`${ozet}<div class="atolye-veri-az">${ORTUS} ${GOZLEM}</div>`), 'özetin hemen altında tek satır');
  assert.ok(!ic.includes(ORTUS) && !ic.includes(GOZLEM), 'Ayrıntıda tekrar yok');
  assert.ok(ic.includes('<li>Ovsync dipnot.</li><li>3 vaka tedavi değişti.</li>'), 'ötekiler Ayrıntıda, sıra korunur');
  assert.ok(!/Gruplar örtüşür|gözlemseldir/.test(oku(DOSYA)), 'metin JS sabiti değil');
});

test('kart_gozlem_uyarisi_tek_dipnot_bos_liste_yok_cizilmeyende_kalir', () => {
  const { c } = kartYukle();
  for (const d of [ORTUS, GOZLEM, 'Gözlemsel <b>büyük harf']) {
    const { once, ic } = ayrinti(c.kurucuKartHtml(zarfBasari({ dipnot: [d] }), null, 0));
    assert.ok(once.includes(`<div class="atolye-veri-az">${kacis(d)}</div>`), 'seçilir, kaçışlı: ' + d);
    assert.ok(!ic.includes('atolye-dipnot'), 'boş <ul> oluşmaz');
  }
  assert.ok(c.kurucuKartHtml({ ...ilacZarf(), dipnot: [ORTUS] }, null, 0).includes(`<div class="atolye-veri-az">${ORTUS}</div><div class="atolye-veri-az">2 ilaçta`), 'veri az satırından önce');
  const oteki = ayrinti(c.kurucuKartHtml(zarfBasari({ dipnot: ['Ovsync dipnot.'] }), null, 0));
  assert.ok(!oteki.once.includes('atolye-veri-az') && oteki.ic.includes('<li>Ovsync dipnot.</li>'), 'seçilen yoksa satır yok');
  assert.ok(ayrinti(c.kurucuKartHtml(zarfBasari({ dipnot: [GOZLEM], sayac: { kiyas_n: 2 } }), null, 0)).once.includes(GOZLEM), 'kontrast_yok da çizilir');
  const yok = ayrinti(c.kurucuKartHtml(tekGrup({ dipnot: [ORTUS] }), null, 0));
  assert.ok(!yok.once.includes(ORTUS) && yok.ic.includes(`<li>${ORTUS}</li>`), 'grafik yokken dipnot kaybolmaz');
});

test('kart_gecici_bant_fiyat_gir_ayrinti_disinda', () => {
  const { c } = kartYukle();
  const tl = { olcum: 'saglik_vaka_tl', fiyat_kaynagi: 'gecici', sayac: { fiyatsiz_n: 4, kiyas_n: 22 }, seriler: [{ n: [21, 22], y: [410, 360], q1: [1, 1], q3: [2, 2] }] };
  const { once } = ayrinti(c.kurucuKartHtml(zarfBasari(tl), null, 0));
  assert.ok(once.includes('atolye-gecici-bant') && once.includes('data-kurucu-slot="fiyat_panel"'));
});

test('kart_durum_kutusu_ayrinti_disinda', () => {
  const { c } = kartYukle(cumleOrnek());
  const { once, ic } = ayrinti(c.kurucuKartHtml(tekGrup({ dipnot: ['D'] }), TANIM_BASARI, 0));
  assert.ok(once.includes('atolye-durum') && !ic.includes('atolye-durum'));
  assert.ok(ic.includes('<li>D</li>'));
});

const ZAMAN_SEYREK = () => zarfBasari({ n: 18, x: { ad: 'ay', deger: ['2026-06', '2026-07', '2026-08'], anahtar: ['a', 'b', 'c'] },
  seriler: [{ ad: 'Tüm', anahtar: 'tumu', n: [4, 8, 3], k: [2, 6, 1], y: [null, 75, null] }], sayac: {} });

test('kart_zaman_seyrek_metin_eylem', async () => {
  const { c, s, cagri } = kartYukle(cumleOrnek({ kirilim: 'ay' }));
  const z = ZAMAN_SEYREK();
  const h = c.kurucuKartHtml(z, null, 0);
  assert.ok(!h.includes('<canvas'), 'tek noktalı çizgi yok');
  assert.ok(h.includes('Başarı Tüm 2026-07: %75,0 (6/8). Çizgi için en az 2 dönemde 5 vaka gerekir.'));
  assert.ok(h.includes('>Çeyreklik göster<'));
  assert.ok(sifirBosluk(h).includes('data-kurucu-slot="kirilim" data-deger=""ceyrek""'));
  assert.ok(h.includes('2026-06 yetersiz (n=4)') && h.includes('2026-08 yetersiz (n=3)'), 'n<5 periyot metinle');
  s.secenekler = SECENEK;
  c._kurucuKabuk();
  await c._kurucuTikla({ target: { closest: () => ({ dataset: { kurucuSlot: 'kirilim', deger: '"ceyrek"' } }) } });
  assert.strictEqual(cagri.seri[cagri.seri.length - 1][0].kirilim, 'ceyrek', 'eylem mevcut slot akışıyla');
  assert.strictEqual(s.onceki.length, 1);
});

test('siralama_suzme_yalniz_grafikte', () => {
  for (const f of [DOSYA, 'js/istatistik/pano.js']) {
    assert.ok(!/\.sort\(/.test(oku(f)), `${f} sıralamaz`);
    assert.ok(!/ilac:/.test(oku(f)), `${f} grup anahtarını yorumlamaz`);
  }
});

// ── TFA review tur1 ──
test('b4_kart_veri_yok_fiyat_yok_rozetsiz', () => {
  const { c } = kartYukle(cumleOrnek());
  const bos = ilacZarf({ n: 0, seriler: [{ ad: 'b', n: [0, 0, 0, 0], k: [0, 0, 0, 0], y: [null, null, null, null] }] });
  const h = c.kurucuKartHtml(bos, TANIM_BASARI, 0);
  assert.ok(h.includes('Bu seçimde vaka yok') && !h.includes('atolye-rozet'));
  const tl = ilacZarf({ olcum: 'saglik_vaka_tl', n: 0, fiyat_kaynagi: 'fiyatsiz', sayac: { fiyatsiz_n: 18, kiyas_n: 0 },
    seriler: [{ ad: '₺', n: [0, 0, 0, 0], y: [null, null, null, null] }] });
  const f = c.kurucuKartHtml(tl, null, 0);
  assert.ok(f.includes('18 vakanın ilaç fiyatı yok') && !f.includes('atolye-rozet') && !f.includes('ilaçta yeterli veri'));
  // ilaç dışı kart n rozetini korur
  assert.ok(c.kurucuKartHtml(tekGrup({ n: 0, seriler: [{ n: [0], k: [0], y: [null] }] }), null, 0).includes('atolye-rozet">n=0<'));
});

// ── TFB G7: durum kaybı (E10, E10b, G6 ek) ──
const xliCumle = () => cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrofloksasin', y: null }, kirilim: 'yok' });

test('g7_select_odagi_yeniden_cizimde_ayni_denetimde', async () => {   // E10
  const { c, s, belge } = yukle();
  s.cumle = xliCumle();
  await c.kurucuYenile();
  const panel = belge.getElementById('atolye-cumle-panel');
  belge.activeElement = { tagName: 'SELECT', dataset: { kurucuSlot: 'y' }, panelIci: panel };
  await c.kurucuSlotDegis('y', 'Flunixin');                     // bekleme + yanıt: iki yeniden çizim
  assert.strictEqual(belge.activeElement.tagName, 'SELECT', 'odak BODY\'ye düşmez');
  assert.strictEqual(belge.activeElement.dataset.kurucuSlot, 'y', 'aynı denetim');
  assert.strictEqual(belge.odakSecenek.preventScroll, true, 'odak paneli kaydırmaz');
});

test('g7_select_kalkarsa_sessiz_dugme_odagi_alinmaz', async () => {   // E10
  const { c, s, belge } = yukle();
  s.cumle = cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrofloksasin', y: 'Flunixin' }, kirilim: 'yok' });
  await c.kurucuYenile();
  const panel = belge.getElementById('atolye-cumle-panel');
  belge.activeElement = { tagName: 'SELECT', dataset: { kurucuSlot: 'y' }, panelIci: panel };
  await c.kurucuSlotDegis('x', null);                           // y seçimi panelden kalkar
  assert.strictEqual(belge.activeElement.tagName, 'BODY');
  // panel dışındaki select'e dokunulmaz
  const dis = { tagName: 'SELECT', dataset: { kurucuSlot: 'hastalik' } };
  belge.activeElement = dis;
  await c.kurucuYenile();
  assert.strictEqual(belge.activeElement, dis);
});

test('g6_panel_kaydirmasi_yeniden_cizimde_korunur', async () => {   // TFC open_item
  const { c, s, belge } = yukle();
  s.cumle = xliCumle();
  await c.kurucuYenile();
  const panel = belge.getElementById('atolye-cumle-panel');
  panel.scrollTop = 340;
  await c.kurucuSlotDegis('kirilim', 'ay');
  assert.strictEqual(belge.getElementById('atolye-cumle-panel').scrollTop, 340);
});

test('g7_doz_acik_listeyi_yazili_fiyati_grafigi_korur', async () => {   // E10
  const { c, s, cagri, belge } = yukle({
    statAtolyeSeri: async () => ({ zarflar: [zarfBasari()], kombinasyon: null, fiyat_eksik: [{ stok_id: 'a' }] }),
    statAtolyeVakalar: async () => ({ toplam: 1, vakalar: [{ kupe_no: 'K1', durum: 'acik', sonuc: null }] }),
  });
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  await c.kurucuVakalarAc('x');
  await c.kurucuSlotDegis('fiyat_panel', null);
  const liste = belge.getElementById('atolye-vakalar-alan');
  const fiyat = belge.getElementById('atolye-fiyat-alan');
  const cizim = cagri.cizim.length;
  await c.kurucuSlotDegis('doz', true);
  assert.strictEqual(belge.getElementById('atolye-vakalar-alan'), liste, 'liste düğümü yerinde');
  assert.strictEqual(liste.hidden, false);
  assert.ok(liste.innerHTML.includes('K1'), 'satırlar duruyor');
  assert.strictEqual(belge.getElementById('atolye-fiyat-alan'), fiyat, 'yazılı fiyatın girdisi yerinde');
  assert.strictEqual(cagri.cizim.length, cizim, 'grafik yeniden çizilmez');
  await c.kurucuSlotDegis('doz', false);
  assert.strictEqual(belge.getElementById('atolye-vakalar-alan'), liste);
  // tam çizimde doz durumu kaybolmaz
  await c.kurucuSlotDegis('doz', true);
  await c.kurucuYenile();
  const doz = belge.getElementById('atolye-doz-alan');
  assert.strictEqual(doz.hidden, false);
  assert.ok(doz.innerHTML.includes(kacis(c.dozMetni())));
});

test('g7_ayni_cumleyle_donus_baslik_alani_ve_yazilan_kalir', async () => {   // E10b
  const { c, s, belge } = yukle();
  await c.kurucuAc(cumleOrnek());
  await c.kurucuKaydet();
  const alan = belge.getElementById('atolye-kaydet-baslik');
  assert.ok(alan, 'alan açık');
  alan.value = 'Yazdığım başlık';
  belge.kok.dinleyici.input[0]({ target: alan });
  belge.kok.innerHTML = '<div class="atolye-pano">PANO</div>';   // pano'ya geçildi: alan DOM'dan gitti
  await c.kurucuAc(s.cumle);                                     // aynı cümle
  assert.ok(belge.getElementById('atolye-kaydet-baslik'), 'alan açık kalır');
  assert.ok(belge.getElementById('atolye-cumle-panel').outerHTML.includes('value="Yazdığım başlık"'), 'yazılan başlık silinmez');
  // farklı cümle kapatmaya devam eder (T12 tur1 B1)
  const baska = cumleOrnek({ kirilim: 'yil' });
  s.cumle = baska;
  await c.kurucuAc(baska);
  assert.strictEqual(belge.getElementById('atolye-kaydet-baslik'), null, 'başka cümle: kapanır');
});

// ── TFB G8 A2: Hesapla düştü, ₺ kartı eski ──
function geciciGercekKur(y) {
  vm.runInContext(oku('js/istatistik/gecici-fiyat.js'), y.c);
  const bagla = y.c.geciciFiyatBagla;
  y.c.geciciFiyatBagla = () => {};                  // kart çizimi sahte düğüm bağlamasın; Hesapla aşağıda elle bağlanır
  y.c.geciciFiyatPanelHtml = () => '';
  const dugmeler = { hesapla: {}, temizle: {}, uyari: {} };
  const girdi = { dataset: { stokId: 's1' }, value: '12,5' };
  const kok = {
    querySelector: sec => dugmeler[/data-gecici="(\w+)"/.exec(sec)[1]] || null,
    querySelectorAll: () => [girdi],
  };
  bagla(kok);
  return { dugmeler, girdi };
}

test('a2_hesapla_dusunce_liste_basarisi_uyariyi_kaldirmaz', async () => {
  const y = yukle();
  const { c, s, cagri } = y;
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const { dugmeler } = geciciGercekKur(y);
  const seriOrj = c.statAtolyeSeri;
  c.statAtolyeSeri = async () => { throw new Error('İnternet bağlantısı gerekli'); };
  await dugmeler.hesapla.onclick();
  assert.deepStrictEqual(cagri.serit, ['İnternet bağlantısı gerekli']);
  const temiz = cagri.temiz;
  await c.kurucuVakalarAc('x');
  assert.strictEqual(cagri.temiz, temiz, 'liste başarısı uyarıyı kaldırmaz: ₺ kartı eski');
  await c.kurucuKaydet();
  y.belge.getElementById('atolye-kaydet-baslik').value = 'B';
  await c.kurucuKaydet();
  assert.strictEqual(cagri.temiz, temiz, 'kaydet başarısı da kaldırmaz');
  c.statAtolyeSeri = seriOrj;                       // bağlantı döndü, ₺ kartı güncellendi
  await dugmeler.hesapla.onclick();
  const taze = cagri.temiz;
  assert.ok(taze > temiz, 'hesap başarısı kaldırır');
  await c.kurucuVakalarAc('x');
  assert.strictEqual(cagri.temiz, taze + 1, 'kart güncelken liste başarısı eski davranışta');
});

test('a2_temizle_dusunce_de_uyari_kalir', async () => {
  const y = yukle();
  const { c, s, cagri } = y;
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  const { dugmeler } = geciciGercekKur(y);
  c.statAtolyeSeri = async () => { throw new Error('İnternet bağlantısı gerekli'); };
  await dugmeler.temizle.onclick();
  const temiz = cagri.temiz;
  await c.kurucuVakalarAc('x');
  assert.strictEqual(cagri.temiz, temiz);
});

test('a2_yeniden_hesapla_duserse_kart_verisi_ayni_liste_kaldirir', async () => {   // vakalar_basarida davranışı korunur
  const y = yukle();
  const { c, s, cagri } = y;
  s.cumle = cumleOrnek();
  await c.kurucuYenile();
  c.statAtolyeSeri = async () => { throw new Error('İnternet bağlantısı gerekli'); };
  await c.kurucuYenile({ yenile: true });
  const temiz = cagri.temiz;
  await c.kurucuVakalarAc('x');
  assert.strictEqual(cagri.temiz, temiz + 1);
});

// ── TFB G9 U21: liste başlığı ──
const satirlar = (acik, kapali) => [
  ...Array.from({ length: acik }, (_, i) => ({ kupe_no: 'A' + i, durum: 'acik', sonuc: null })),
  ...Array.from({ length: kapali }, (_, i) => ({ kupe_no: 'K' + i, durum: 'sonuclandi', sonuc: 'basarili' })),
];
async function listeAc(r, olcuN) {
  const y = yukle({ statAtolyeVakalar: async () => r });
  y.s.cumle = cumleOrnek();
  await y.c.kurucuYenile();
  await y.c._kurucuTikla({ target: { closest: () => ({ dataset: { kurucuVakalar: 'x', ...(olcuN === undefined ? {} : { olcuN }) } }) } });
  return y.belge.getElementById('atolye-vakalar-alan').innerHTML;
}

test('u21_baslik_vaka_olcu_acik', async () => {
  const h = await listeAc({ toplam: 20, vakalar: satirlar(4, 16) }, '16');
  assert.ok(h.includes("20 vaka · 16'sı bu ölçüde · 4'ü açık"), h.slice(0, 300));
  assert.ok(!h.includes('ölçü dışı'), 'kalan yokken yazılmaz');
});

test('u21_acik_sifirsa_parca_basilmaz', async () => {
  const h = await listeAc({ toplam: 16, vakalar: satirlar(0, 16) }, '16');
  assert.ok(h.includes("16 vaka · 16'sı bu ölçüde"));
  assert.ok(!/\d'.{1,2} açık/.test(h), 'açık 0');
});

test('u21_kalan_fark_durustce_yazilir', async () => {
  const h = await listeAc({ toplam: 20, vakalar: satirlar(4, 16) }, '14');
  assert.ok(h.includes("20 vaka · 14'ü bu ölçüde · 4'ü açık · 2'si ölçü dışı"), h.slice(0, 300));
});

test('u21_kesik_listede_acik_ve_kalan_uydurulmaz', async () => {
  const h = await listeAc({ toplam: 350, vakalar: satirlar(4, 196) }, '16');
  assert.ok(h.includes("ilk 200 / 350 · 16'sı bu ölçüde"));
  assert.ok(!h.includes('açık</') && !/\d'.{1,2} açık/.test(h) && !h.includes('ölçü dışı'));
});

test('u21_olcu_bilgisi_yoksa_olcu_parcasi_yok', async () => {
  const h = await listeAc({ toplam: 5, vakalar: satirlar(1, 4) }, undefined);
  assert.ok(h.includes("5 vaka · 1'i açık"));
  assert.ok(!h.includes('bu ölçüde') && !h.includes('ölçü dışı'));
});

test('u21_olcu_n_karttan_baglantiyla_gecer', () => {
  const { c } = yukle();
  c.window._atolye.cumle = cumleOrnek();
  // kartın kendi ölçü n'i; sayac.acik_n grupların birleşimidir, listeye taşınmaz
  const z = zarfBasari({ sayac: { acik_n: 30, kiyas_n: 22 } });
  const h = c.kurucuKartHtml(z, TANIM_BASARI, 0);
  assert.ok(h.includes('data-kurucu-vakalar="x" data-olcu-n="21"'), h);
  assert.ok(h.includes('data-kurucu-vakalar="tumu" data-olcu-n="22"'));
  // zaman kırılımında serinin dönem n'leri toplamı
  const zaman = zarfBasari({ x: { ad: 'ay', deger: ['2026-01', '2026-02'], anahtar: ['2026-01-01', '2026-02-01'] },
    seriler: [{ ad: 'A', anahtar: 'x', n: [6, 7], k: [3, 4], y: [50, 57], alt: [1, 1], ust: [2, 2] }], sayac: { kiyas_n: null } });
  assert.ok(c.kurucuKartHtml(zaman, TANIM_BASARI, 0).includes('data-kurucu-vakalar="x" data-olcu-n="13"'));
});

test('u21_grup_acigi_satirdan_birlesim_sayacindan_degil', async () => {
  const y = yukle({ statAtolyeVakalar: async () => ({ toplam: 6, vakalar: satirlar(1, 5) }),
    statAtolyeSeri: async () => ({ zarflar: [zarfBasari({ sayac: { acik_n: 30, kiyas_n: 22 } })], kombinasyon: null, fiyat_eksik: [] }) });
  y.s.cumle = cumleOrnek();
  await y.c.kurucuYenile();
  await y.c.kurucuVakalarAc('x', { olcuN: '5' });
  const h = y.belge.getElementById('atolye-vakalar-alan').innerHTML;
  assert.ok(h.includes("6 vaka · 5'i bu ölçüde · 1'i açık"), h.slice(0, 300));
});

test('u21_sayi_eki_turkce', () => {
  const { c } = yukle();
  const b = { 0: "0'ı", 1: "1'i", 2: "2'si", 3: "3'ü", 4: "4'ü", 5: "5'i", 6: "6'sı", 7: "7'si", 8: "8'i", 9: "9'u",
    10: "10'u", 16: "16'sı", 20: "20'si", 30: "30'u", 40: "40'ı", 50: "50'si", 60: "60'ı", 70: "70'i", 80: "80'i", 90: "90'ı",
    100: "100'ü", 200: "200'ü", 110: "110'u", 1000: "1000'i" };
  for (const [n, y] of Object.entries(b)) assert.strictEqual(c._kurucuSayiEk(Number(n)), y);
});

// ── BORC-UI ──
test('borc_u2_kart_dipnotu_tek_hesap', () => {
  const { c } = yukle();
  const asil = c.grafikDipnotAyir;
  let sayac = 0;
  c.grafikDipnotAyir = (...a) => { sayac += 1; return asil(...a); };
  c.kurucuKartHtml({ ...ilacZarf(), dipnot: [ORTUS, 'Öteki'] }, null, 0);
  assert.strictEqual(sayac, 1);
});

// U8: yeniden çizim select dışındaki denetimde de odağı bırakmaz.
const panelOdak = (belge, bul) => {
  const panel = belge.getElementById('atolye-cumle-panel');
  const el = panel.querySelectorAll('button,select,input').find(bul);
  belge.activeElement = el;
  return el;
};

test('borc_u8_cip_odagi_yeniden_cizimde_kalir', async () => {
  const { c, s, belge } = yukle();
  s.cumle = xliCumle();
  await c.kurucuYenile();
  panelOdak(belge, e => e.dataset.kurucuSlot === 'kirilim' && e.metin === 'Ay');
  await c.kurucuSlotDegis('kirilim', 'ay');
  assert.strictEqual(belge.activeElement.metin, 'Ay');
  assert.strictEqual(belge.activeElement.dataset.kurucuSlot, 'kirilim');
  assert.strictEqual(belge.odakSecenek.preventScroll, true);
});

test('borc_u8_baslik_alani_odak_ve_imlec_kalir', async () => {
  const { c, s, belge } = yukle();
  s.cumle = xliCumle();
  await c.kurucuYenile();
  await c.kurucuKaydet();                                        // başlık alanı açılır
  const el = panelOdak(belge, e => e.id === 'atolye-kaydet-baslik');
  Object.assign(el, { selectionStart: 3, selectionEnd: 5 });
  await c.kurucuYenile();
  assert.strictEqual(belge.activeElement.id, 'atolye-kaydet-baslik');
  assert.deepStrictEqual([...belge.activeElement.secim], [3, 5]);
});

test('borc_u8_denetim_kalkarsa_odak_alinmaz', async () => {
  const { c, s, belge } = yukle();
  s.cumle = xliCumle();
  await c.kurucuYenile();
  const panel = belge.getElementById('atolye-cumle-panel');
  belge.activeElement = { tagName: 'BUTTON', dataset: { kurucuEylem: 'olmayan' }, panelIci: panel };
  await c.kurucuYenile();
  assert.strictEqual(belge.activeElement.tagName, 'BODY');
});
