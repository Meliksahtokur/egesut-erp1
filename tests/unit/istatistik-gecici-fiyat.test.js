'use strict';
// İstatistik Atölyesi AP1 Task 14 — geçici ilaç fiyatı paneli (js/istatistik/gecici-fiyat.js).
// İlk altı test plan Step 1 adlarıdır; devamı ek sınır testleridir. Sahte kök panel HTML'inden
// kurulur: HTML üreticisi ile okuyucunun aynı öznitelikte buluştuğunu da ölçer.
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const DOSYA = path.join(__dirname, '..', '..', 'js', 'istatistik', 'gecici-fiyat.js');
const METIN = fs.readFileSync(DOSYA, 'utf8');

// helpers.js esc (textContent→innerHTML: & < > kaçar, tırnak kaçmaz, falsy → '') ve escAttr davranışı
const esc = s => String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttr = s => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const entityCoz = s => s.replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');

function yukle() {
  const cagri = { yenile: 0 };
  const ctx = {
    esc, escAttr, console,
    window: { _atolye: { gecici: { ilac_fiyat: { eski: 9 } }, cumle: { v: 1, alan: 'saglik' } } },
    kurucuYenile: () => { cagri.yenile += 1; },
    module: { exports: {} },
  };
  vm.createContext(ctx);
  vm.runInContext(METIN, ctx, { filename: 'js/istatistik/gecici-fiyat.js' });
  return { m: ctx.module.exports, ctx, cagri };
}
const duz = o => JSON.parse(JSON.stringify(o));

/** Panel HTML'inden sahte kök: input[data-stok-id] ve [data-gecici="…"] düğmeleri. */
function sahteKok(html, alanlar = {}) {
  const girdiler = [...html.matchAll(/<input\b[^>]*>/g)].map(g => {
    const id = /data-stok-id="([^"]*)"/.exec(g[0]);
    const v = /\bvalue="([^"]*)"/.exec(g[0]);
    const stokId = id ? entityCoz(id[1]) : undefined;
    return { dataset: { stokId }, value: Object.prototype.hasOwnProperty.call(alanlar, stokId) ? alanlar[stokId] : (v ? entityCoz(v[1]) : '') };
  }).filter(g => g.dataset.stokId !== undefined);
  const dugmeler = {};
  for (const d of html.matchAll(/<button\b[^>]*data-gecici="(\w+)"[^>]*>/g)) dugmeler[d[1]] = { onclick: null };
  if (html.includes('data-gecici="uyari"')) dugmeler.uyari = { textContent: '', hidden: true };
  return {
    girdiler, dugmeler,
    querySelectorAll(sec) { assert.ok(sec.includes('data-stok-id'), 'beklenmeyen seçici: ' + sec); return girdiler; },
    querySelector(sec) {
      const r = /data-gecici="?(\w+)"?/.exec(sec);
      assert.ok(r, 'beklenmeyen seçici: ' + sec);
      return dugmeler[r[1]] || null;
    },
  };
}
const SATIR = [
  { stok_id: 'a1', urun_adi: 'Enrolen', birim: 'ml', vaka_n: 12, gecici_deger: null },
  { stok_id: 'b2', urun_adi: 'Pendistrep', birim: 'gr', vaka_n: 5, gecici_deger: null },
];
const okuDegerler = (alanlar) => {
  const { m } = yukle();
  const ids = Object.keys(alanlar);
  const html = m.geciciFiyatPanelHtml(ids.map((id, i) => ({ stok_id: id, urun_adi: 'U' + i, birim: 'ml', vaka_n: 1 })), {});
  assert.ok(html, 'panel boş döndü');
  return duz(m.geciciFiyatOku(sahteKok(html, alanlar)));
};

// ── Plan Step 1 ──
test('oku_virgul', () => {
  assert.deepStrictEqual(okuDegerler({ a: '12,5', b: '3.25', c: ' 7 ' }), { ilac_fiyat: { a: 12.5, b: 3.25, c: 7 } });
});

test('oku_bos_sifir_negatif_atla', () => {
  assert.deepStrictEqual(okuDegerler({ a: '', b: '0', c: '-4', d: 'abc', e: '0,0', f: '2' }), { ilac_fiyat: { f: 2 } });
});

test('panel_kaydedilmez_metni', () => {
  const html = yukle().m.geciciFiyatPanelHtml(SATIR, {});
  assert.ok(html.includes('İlaç birim fiyatı (geçici)'), 'başlık');
  assert.ok(html.includes('Bu değerler kaydedilmez; yalnız bu hesapta kullanılır.'), 'açıklama');
  assert.ok(html.includes('Hesapla') && html.includes('Temizle'), 'düğmeler');
});

test('panel_kacis', () => {
  const html = yukle().m.geciciFiyatPanelHtml([{ stok_id: 'x"><i>', urun_adi: '<b>İlaç</b>', birim: '<u>ml', vaka_n: 1, gecici_deger: '"><s>' }], {});
  assert.ok(!html.includes('<b>İlaç') && html.includes('&lt;b&gt;İlaç'), 'urun_adi kaçmalı');
  assert.ok(!html.includes('<u>') && html.includes('&lt;u&gt;ml'), 'birim kaçmalı');
  assert.ok(!html.includes('<i>') && html.includes('data-stok-id="x&quot;&gt;&lt;i&gt;"'), 'stok_id öznitelik kaçışı');
  assert.ok(!html.includes('<s>'), 'değer öznitelik kaçışı');
  assert.strictEqual(sahteKok(html).girdiler[0].dataset.stokId, 'x"><i>', 'kaçış okuyucuda geri açılır');
});

test('depolama_yok', () => {
  for (const k of ['localStorage', 'indexedDB', 'sessionStorage']) {
    assert.strictEqual(METIN.toLowerCase().split(k.toLowerCase()).length - 1, 0, k + ' dosyada geçmemeli');
  }
});

test('temizle_bos', () => {
  const { m, ctx, cagri } = yukle();
  const kok = sahteKok(m.geciciFiyatPanelHtml(SATIR, {}), { a1: '5' });
  m.geciciFiyatBagla(kok);
  kok.dugmeler.temizle.onclick();
  assert.deepStrictEqual(duz(ctx.window._atolye.gecici), { ilac_fiyat: {} });
  assert.strictEqual(cagri.yenile, 1, 'kurucuYenile bir kez');
  assert.deepStrictEqual(kok.girdiler.map(g => g.value), ['', ''], 'yanıt gelmese de alanlar boşalır');
});

// ── Ek ──
test('panel_bos_dizi', () => {
  const { m } = yukle();
  for (const v of [[], null, undefined, {}]) assert.strictEqual(m.geciciFiyatPanelHtml(v, {}), '');
});

test('panel_satir_bicimi', () => {
  const html = yukle().m.geciciFiyatPanelHtml([SATIR[0]], undefined);
  assert.ok(html.includes('Enrolen · ₺ / ml'), 'satır metni');
  assert.match(html, /<input\b[^>]*inputmode="decimal"/);
  assert.match(html, /<input\b[^>]*\bmin="0"/);
  assert.match(html, /<input\b[^>]*type="text"/, 'virgül tarayıcıda kaybolmasın diye type=number değil');
  assert.ok(html.includes('class="atolye-fiyat"') && html.includes('atolye-fiyat-satir'), 'T11 sözlüğü');
});

test('panel_birimsiz_satir', () => {
  const html = yukle().m.geciciFiyatPanelHtml([{ ...SATIR[0], birim: null }], {});
  assert.ok(html.includes('Enrolen · ₺<'), 'birim yoksa "/" kalmaz: ' + html);
  assert.ok(!html.includes('null'));
});

test('panel_vaka_n_sirasi_girdi_degismez', () => {
  const girdi = [
    { stok_id: 'az', urun_adi: 'Az', birim: 'ml', vaka_n: 2 },
    { stok_id: 'cok', urun_adi: 'Çok', birim: 'ml', vaka_n: 30 },
    { stok_id: 'orta', urun_adi: 'Orta', birim: 'ml', vaka_n: 9 },
  ];
  const once = JSON.stringify(girdi);
  const html = yukle().m.geciciFiyatPanelHtml(girdi, {});
  assert.deepStrictEqual(sahteKok(html).girdiler.map(g => g.dataset.stokId), ['cok', 'orta', 'az']);
  assert.strictEqual(JSON.stringify(girdi), once, 'girdi dizisi değişmez');
});

test('panel_gecici_deger_alan_dolu', () => {
  const html = yukle().m.geciciFiyatPanelHtml([{ ...SATIR[0], gecici_deger: 12.5 }, SATIR[1]], {});
  const g = sahteKok(html).girdiler;
  assert.strictEqual(g[0].value, '12,5', 'ekran biçimi virgül: alan yeniden okununca aynı sayı');
  assert.strictEqual(g[1].value, '', 'gecici_deger null satır boş');
});

test('panel_degerler_alan_dolu', () => {
  const { m } = yukle();
  for (const degerler of [{ ilac_fiyat: { b2: 7 } }, { b2: 7 }]) {
    const g = sahteKok(m.geciciFiyatPanelHtml(SATIR, degerler)).girdiler;
    assert.deepStrictEqual(g.map(x => x.value), ['', '7'], JSON.stringify(degerler));
  }
  const g = sahteKok(m.geciciFiyatPanelHtml([{ ...SATIR[0], gecici_deger: 1 }], { ilac_fiyat: { a1: 2 } })).girdiler;
  assert.strictEqual(g[0].value, '2', 'bellekteki güncel değer yansımayı ezer');
});

test('oku_kati_bicim', () => {
  assert.deepStrictEqual(
    okuDegerler({ a: '12abc', b: '0x10', c: '1e3', d: '.', e: 'Infinity', f: '12,5,3', g: ',', h: '1.23,4', i: '0,5', j: '.5' }),
    { ilac_fiyat: { i: 0.5, j: 0.5 } });
});

// Kapı F3 Ö4: bin ayracı. Virgüllü biçim belirsiz değil; virgülsüz üç haneli nokta belirsiz, reddedilir ve söylenir.
const BELIRSIZ = '1.234 anlaşılamadı: 1234 ya da 1,234 yazın';

test('oku_binlik_virgullu_kabul', () => {
  assert.deepStrictEqual(
    okuDegerler({ a: '12,5', b: '1.234,5', c: '1.234,50', d: '12.345,75', e: '1.234.567,5', f: '1234,5', g: '1234.5' }),
    { ilac_fiyat: { a: 12.5, b: 1234.5, c: 1234.5, d: 12345.75, e: 1234567.5, f: 1234.5, g: 1234.5 } });
});

test('oku_binlik_belirsiz_red', () => {
  assert.deepStrictEqual(okuDegerler({ a: '1.234', b: '12.345', c: '123.456', d: '1.234.567' }), { ilac_fiyat: {} });
  assert.deepStrictEqual(okuDegerler({ a: '0.125', b: '1.23', c: '1.2345', d: '1,234' }),
    { ilac_fiyat: { a: 0.125, b: 1.23, c: 1.2345, d: 1.234 } }, 'üç haneli nokta dışı biçimler belirsiz değil');
});

function hesapla(alanlar, satirlar = SATIR) {
  const y = yukle();
  const kok = sahteKok(y.m.geciciFiyatPanelHtml(satirlar, {}), alanlar);
  y.m.geciciFiyatBagla(kok);
  kok.dugmeler.hesapla.onclick();
  return { ...y, kok };
}

test('red_panelde_metinle_sunucuya_gitmez', () => {
  const { ctx, kok, m, cagri } = hesapla({ a1: '1.234', b2: '5' });
  assert.deepStrictEqual(duz(ctx.window._atolye.gecici), { ilac_fiyat: { b2: 5 } }, 'reddedilen değer hesaba girmez, gecici anahtarı eklenmez');
  assert.strictEqual(cagri.yenile, 1);
  assert.strictEqual(kok.dugmeler.uyari.textContent, BELIRSIZ, 'yanıt gelmese de söylenir');
  assert.strictEqual(kok.dugmeler.uyari.hidden, false);
  const yeniden = m.geciciFiyatPanelHtml(SATIR, ctx.window._atolye.gecici);       // yanıt gelince yeniden çizim
  assert.ok(yeniden.includes(BELIRSIZ), 'yeniden çizimde metin kalır');
  const g = sahteKok(yeniden).girdiler;
  assert.deepStrictEqual(g.map(x => x.value), ['1.234', '5'], 'yazılan metin alanda kalır');
});

test('red_metni_girilen_sayiya_gore_ve_kacis', () => {
  assert.strictEqual(hesapla({ a1: '2.500' }).kok.dugmeler.uyari.textContent, '2.500 anlaşılamadı: 2500 ya da 2,500 yazın');
  const { kok, m, ctx } = hesapla({ a1: '<b>x' });
  assert.strictEqual(kok.dugmeler.uyari.textContent, '<b>x anlaşılamadı: 1234 ya da 1,234 yazın', 'tanınmayan biçim de sessiz atlanmaz');
  const h = m.geciciFiyatPanelHtml(SATIR, ctx.window._atolye.gecici);
  assert.ok(!h.includes('<b>x') && h.includes('&lt;b&gt;x anlaşılamadı'), 'metin kaçar');
});

test('bos_sifir_negatif_sessiz_atlanir', () => {
  const { ctx, kok } = hesapla({ a1: '', b2: '0' });
  assert.deepStrictEqual(duz(ctx.window._atolye.gecici), { ilac_fiyat: {} });
  assert.strictEqual(kok.dugmeler.uyari.textContent, '');
  assert.strictEqual(kok.dugmeler.uyari.hidden, true);
  assert.strictEqual(hesapla({ a1: '-4', b2: '0,0' }).kok.dugmeler.uyari.textContent, '');
});

test('red_duzeltilince_ve_temizlede_metin_kalkar', () => {
  const { ctx, kok, m } = hesapla({ a1: '1.234' });
  kok.girdiler[0].value = '1234';
  kok.dugmeler.hesapla.onclick();
  assert.deepStrictEqual(duz(ctx.window._atolye.gecici), { ilac_fiyat: { a1: 1234 } });
  assert.strictEqual(kok.dugmeler.uyari.hidden, true);
  assert.ok(!m.geciciFiyatPanelHtml(SATIR, ctx.window._atolye.gecici).includes('anlaşılamadı'));

  const t = hesapla({ a1: '1.234' });
  t.kok.dugmeler.temizle.onclick();
  assert.strictEqual(t.kok.dugmeler.uyari.hidden, true);
  const h = t.m.geciciFiyatPanelHtml(SATIR, t.ctx.window._atolye.gecici);
  assert.ok(!h.includes('anlaşılamadı'));
  assert.deepStrictEqual(sahteKok(h).girdiler.map(x => x.value), ['', ''], 'temizle reddedilen metni de siler');
});

test('kabul_edilen_deger_yeniden_cizimden_sonra_reddedilmez', () => {
  // İleti "1,234 yazın" der: 1.234 sayısı alana noktayla dönseydi ikinci Hesapla onu reddederdi.
  const { ctx, m } = hesapla({ a1: '1,234', b2: '1.234,5' });
  assert.deepStrictEqual(duz(ctx.window._atolye.gecici), { ilac_fiyat: { a1: 1.234, b2: 1234.5 } });
  const kok2 = sahteKok(m.geciciFiyatPanelHtml(SATIR, ctx.window._atolye.gecici));
  assert.deepStrictEqual(kok2.girdiler.map(x => x.value), ['1,234', '1234,5']);
  m.geciciFiyatBagla(kok2);
  kok2.dugmeler.hesapla.onclick();
  assert.deepStrictEqual(duz(ctx.window._atolye.gecici), { ilac_fiyat: { a1: 1.234, b2: 1234.5 } });
  assert.strictEqual(kok2.dugmeler.uyari.textContent, '');
});

test('oku_kok_yok_ve_tur', () => {
  const { m } = yukle();
  assert.deepStrictEqual(duz(m.geciciFiyatOku(null)), { ilac_fiyat: {} });
  const html = m.geciciFiyatPanelHtml([{ ...SATIR[0], gecici_deger: 12.5 }], {});
  assert.deepStrictEqual(duz(m.geciciFiyatOku(sahteKok(html))), { ilac_fiyat: { a1: 12.5 } }, 'dolu gelen alan yeniden okunur');
});

test('hesapla_yalniz_bellek', () => {
  // Review Focus 3: değer yalnız window._atolye.gecici'de; cümleye girmez. Kaydet yükü T12 kaydet_yuku_gecicisiz'de.
  const { m, ctx, cagri } = yukle();
  const cumleOnce = JSON.stringify(ctx.window._atolye.cumle);
  const kok = sahteKok(m.geciciFiyatPanelHtml(SATIR, {}), { a1: '12,5', b2: '' });
  m.geciciFiyatBagla(kok);
  assert.strictEqual(cagri.yenile, 0, 'bağlama hesap başlatmaz');
  kok.dugmeler.hesapla.onclick();
  assert.deepStrictEqual(duz(ctx.window._atolye.gecici), { ilac_fiyat: { a1: 12.5 } });
  assert.strictEqual(JSON.stringify(ctx.window._atolye.cumle), cumleOnce, 'cümle değişmez');
  assert.strictEqual(cagri.yenile, 1);
  assert.doesNotMatch(METIN, /statGrafikKaydet|\brpc\(|\bfetch\(/, 'modül sunucuya yazmaz');
});

test('bagla_tekrar_ve_bos_panel', () => {
  const { m, cagri } = yukle();
  const kok = sahteKok(m.geciciFiyatPanelHtml(SATIR, {}));
  m.geciciFiyatBagla(kok);
  m.geciciFiyatBagla(kok);
  kok.dugmeler.hesapla.onclick();
  assert.strictEqual(cagri.yenile, 1, 'iki kez bağlama iki hesap başlatmaz');
  assert.doesNotThrow(() => m.geciciFiyatBagla(sahteKok('')));
  assert.doesNotThrow(() => m.geciciFiyatBagla(null));
});

test('metin_kurallari', () => {
  const html = yukle().m.geciciFiyatPanelHtml(SATIR, {});
  const kucuk = METIN.toLocaleLowerCase('tr-TR');
  assert.ok(!kucuk.includes('protokol'), 'yasak kelime');
  assert.doesNotMatch(kucuk, /sağla|etkili|karşılığı/, 'nedensellik fiili');
  assert.doesNotMatch(METIN, /#[0-9a-fA-F]{3,8}\b/, 'sabit hex');
  assert.doesNotMatch(METIN, /style=|var\(--red|var\(--amber/, 'satır içi stil / kırmızı-amber');
  assert.doesNotMatch(METIN, /basarisiz_|sonucEtiket/, 'sonuç listesi kopyalanmaz');
  assert.doesNotMatch(html, /varsay|tahmin|kalıcı/i, 'varsayım/açıklama metni yok (spec §8 #8)');
});

test('imza_uzunluklari', () => {
  const { m } = yukle();
  assert.strictEqual(m.geciciFiyatPanelHtml.length, 2);
  assert.strictEqual(m.geciciFiyatOku.length, 1);
  assert.strictEqual(m.geciciFiyatBagla.length, 1);
});

// TFB A2: kurucu.js kartların hangi fiyatla çizildiğini nesne kimliğiyle ayırır; her basış yeni nesne yazmalı.
test('a2_hesapla_ve_temizle_yeni_nesne_yazar', () => {
  const { m, ctx } = yukle();
  const kok = sahteKok(m.geciciFiyatPanelHtml([{ stok_id: 'a', urun_adi: 'A', vaka_n: 1 }], null), { a: '5' });
  m.geciciFiyatBagla(kok);
  const once = ctx.window._atolye.gecici;
  kok.dugmeler.hesapla.onclick();
  const ilk = ctx.window._atolye.gecici;
  assert.notStrictEqual(ilk, once);
  kok.dugmeler.hesapla.onclick();
  assert.notStrictEqual(ctx.window._atolye.gecici, ilk, 'aynı değerle de yeni nesne');
  const son = ctx.window._atolye.gecici;
  kok.dugmeler.temizle.onclick();
  assert.notStrictEqual(ctx.window._atolye.gecici, son);
});
