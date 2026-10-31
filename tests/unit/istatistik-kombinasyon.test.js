'use strict';
// İstatistik Atölyesi AP1 Task 13 — kombinasyon paneli (js/istatistik/kombinasyon.js).
// Gerçek cumle.js + grafik.js + kombinasyon.js vm'de; esc/escAttr helpers.js davranışında stub,
// kurucuSlotDegis (T12 global) stub.
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const KOK = path.join(__dirname, '..', '..');
const oku = rel => fs.readFileSync(path.join(KOK, rel), 'utf8');
const KAYNAK = oku('js/istatistik/kombinasyon.js');

function yukle() {
  const cagrilar = [];
  const ctx = vm.createContext({
    console,
    // helpers.js:161 davranışı: & < > kaçar, tırnak kaçırmaz, falsy → ''
    esc: s => String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'),
    escAttr: s => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
      .replace(/</g, '&lt;').replace(/>/g, '&gt;'),
    trLower: s => s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase(),
    kurucuSlotDegis: (slot, deger) => cagrilar.push([slot, deger]),
  });
  for (const f of ['cumle', 'grafik', 'kombinasyon']) vm.runInContext(oku(`js/istatistik/${f}.js`), ctx, { filename: f });
  ctx.cagrilar = cagrilar;
  return ctx;
}
const M = yukle();

const grup = (n, k, bn, y, hn, hm, tn, tm) => ({
  n, basari: { k, n: bn, y }, hiz: { n: hn, medyan: hm }, tl: { n: tn, medyan: tm },
});
const dolu = () => grup(10, 8, 10, 80, 9, 7.5, 8, 410.5);
const satir = (y, a, b, yetersiz = false) => ({ y, a, b, yetersiz });
const komb = (...satirlar) => ({ x: 'Enrolen', duzey: 'preparat', satirlar });
const sade = h => h.replace(/<[^>]+>/g, '|');
// Satır/alt satır dilimleri (kapanış div sayımına güvenmeden düğme ve sınıf sınırından)
const satirlarOf = h => h.split('<div class="atolye-komb-satir').slice(1);
const altlarOf = s => s.split('<div class="atolye-komb-alt').slice(1);

test('bos_null', () => {
  assert.strictEqual(M.kombinasyonHtml(null, {}), '');
  assert.strictEqual(M.kombinasyonHtml(null), '');
  assert.strictEqual(M.kombinasyonHtml(undefined, { gecici: { ilac_fiyat: {} } }), '');
});

test('satir_sira_korunur', () => {
  const h = M.kombinasyonHtml(komb(satir('Zeta', dolu(), dolu()), satir('Alfa', dolu(), dolu()), satir('Mu', dolu(), dolu())), {});
  const adlar = [...h.matchAll(/data-komb-y="([^"]*)"/g)].map(r => r[1]);
  assert.deepStrictEqual(adlar, ['Zeta', 'Alfa', 'Mu'], 'SQL sırası yeniden sıralanmaz');
});

test('yetersiz_gri_metin', () => {
  // a dolu, b n=3: satır gri; b hücreleri "yetersiz (n=k)"; a değerleri korunur (plan: "n<5 hücrede").
  const h = M.kombinasyonHtml(komb(satir('Halocur', dolu(), grup(3, 2, 3, 66.7, 3, 4, 3, 100), true)), {});
  const [s] = satirlarOf(h);
  assert.ok(s.startsWith(' atolye-yetersiz"'), 'satır .atolye-yetersiz');
  const [a, b] = altlarOf(s);
  // .atolye-komb-alt rengi doğrudan --ink set eder: gri, alt satırın kendi sınıfında olmalı (index.html kural sırası)
  assert.ok(a.startsWith(' atolye-yetersiz"') && b.startsWith(' atolye-yetersiz"'), 'gri alt satırın kendisinde');
  assert.match(a, /%80,0 \(8\/10\)/, 'a n≥5: değer durur');
  assert.strictEqual((b.match(/yetersiz \(n=3\)/g) || []).length, 3, 'b: başarı, hız, ₺ hücreleri metin');
  assert.ok(!b.includes('66,7') && !b.includes('medyan') && !b.includes('₺'), 'b: değer basılmaz');
  assert.ok(!b.includes('atolye-cubuk'), 'b: değer yok → çubuk yok');
  assert.ok(!/background|#[0-9a-f]{3,6}\b/i.test(h), 'satır zemini / sabit renk yok');
  const css = oku('index.html');
  assert.ok(css.indexOf('.atolye-yetersiz{') > css.indexOf('.atolye-komb-alt{'), 'CSS sırası gri kazanır');
});

test('fiyatsiz_metin', () => {
  // ₺ n=0 ama sonuçlanmış vaka var: fiyat yok (yetersiz değil; T10 ruling sırası)
  const h = M.kombinasyonHtml(komb(satir('Halocur', dolu(), grup(10, 8, 10, 80, 9, 7, 0, null))), {});
  const [a, b] = altlarOf(satirlarOf(h)[0]);
  assert.match(a, /₺410,50/);
  assert.match(b, /fiyat yok/);
  assert.ok(!b.includes('₺'), 'fiyatsızda ₺ değeri yok');
  assert.ok(!b.includes('yetersiz'), 'fiyatsız ≠ yetersiz');
});

test('cumleye_ekle_y', () => {
  const m = yukle();
  const y = `Ha"lo'cur`;
  const h = m.kombinasyonHtml(komb(satir(y, dolu(), dolu())), {});
  const r = h.match(/<button[^>]*data-komb-y="([^"]*)"[^>]*>([^<]*)<\/button>/);
  assert.ok(r, 'düğme var');
  assert.strictEqual(r[2], 'Cümleye ekle');
  assert.ok(/type="button"/.test(r[0]) && /class="atolye-eylem"/.test(r[0]));
  const cozulmus = r[1].replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
  const dugme = { dataset: { kombY: cozulmus } };
  m.kombinasyonBagla({ querySelectorAll(sec) { assert.strictEqual(sec, '[data-komb-y]'); return [dugme]; } });
  dugme.onclick();
  assert.deepStrictEqual(m.cagrilar, [['y', y]]);
  m.kombinasyonBagla(null);   // kök yoksa sessiz no-op
});

test('kacis', () => {
  const k = { x: '<b>x</b>', duzey: 'etken', satirlar: [satir('<i>y"</i>', dolu(), dolu())] };
  const h = M.kombinasyonHtml(k, {});
  assert.ok(!h.includes('<b>') && !h.includes('<i>'), 'ham etiket yok');
  assert.ok(h.includes('&lt;b&gt;x&lt;/b&gt; içeren vakalarda'), 'başlık kaçışlı');
  assert.ok(h.includes('&lt;b&gt;x&lt;/b&gt; + &lt;i&gt;y"&lt;/i&gt; içeren'), 'alt satır kaçışlı');
  assert.ok(h.includes('data-komb-y="&lt;i&gt;y&quot;&lt;/i&gt;"'), 'öznitelik escAttr');
});

test('neden_fiili_yok', () => {
  const h = M.kombinasyonHtml(komb(satir('Halocur', dolu(), dolu())), {});
  const yasak = /sağla|sagla|etkili|karşılığı|karsiligi/i;
  assert.ok(!yasak.test(h), 'çıktıda nedensellik fiili yok');
  assert.ok(!yasak.test(KAYNAK), 'kaynakta nedensellik fiili yok');
  assert.ok(!/protokol/i.test(KAYNAK) && !/protokol/i.test(h), 'yasak kelime 0');
});

// ── Ek testler ──
test('imza_korunur', () => {
  assert.strictEqual(M.kombinasyonHtml.length, 1);
  assert.strictEqual(M.kombinasyonBagla.length, 1);
});

test('baslik_ve_alt_satir_u5', () => {
  const h = M.kombinasyonHtml(komb(satir('Halocur', dolu(), dolu())), {});
  assert.ok(h.startsWith('<section class="atolye-komb">'), 'kök .atolye-komb (T12 buraya kaydırır)');
  assert.ok(h.includes('Enrolen içeren vakalarda birlikte kullanılan ilaçlar'));
  assert.ok(h.includes('Enrolen + Halocur içeren'));
  assert.ok(h.includes("Enrolen içeren, Halocur'suz"), 'plan U5 birebir');
});

test('siz_eki_unlu_uyumu', () => {
  const ek = y => {
    const h = M.kombinasyonHtml(komb(satir(y, dolu(), dolu())), {});
    return h.match(/Enrolen içeren, ([^<]*)/)[1];
  };
  assert.strictEqual(ek('Enrolen'), "Enrolen'siz");
  assert.strictEqual(ek('Meloksikam'), "Meloksikam'sız");
  assert.strictEqual(ek('Halocur'), "Halocur'suz");
  assert.strictEqual(ek('Tilmikosin'), "Tilmikosin'siz");
  assert.strictEqual(ek('Antibiyo'), "Antibiyo'suz");
  assert.strictEqual(ek('Gözlük'), "Gözlük'süz");
  assert.strictEqual(ek('Köpö'), "Köpö'süz");
  assert.strictEqual(ek('NSAİİ'), "NSAİİ'siz", 'büyük harf İ');
  assert.strictEqual(ek('KISIM'), "KISIM'sız", 'büyük harf I');
  assert.strictEqual(ek('B12'), "B12'siz", 'ünlüsüz: varsayılan');
});

test('sayi_bicimi', () => {
  const h = M.kombinasyonHtml(komb(satir('H', grup(12, 2, 3 + 3, 33.33, 6, 8, 5, 1234.5), dolu())), {});
  const [a] = altlarOf(satirlarOf(h)[0]);
  assert.match(a, />n=12</);
  assert.match(a, /%33,3 \(2\/6\)/);
  assert.match(a, /medyan 8,0 gün/);
  assert.match(a, /₺1\.234,50/);
});

test('olcu_n_kucuk_satir_gri_degil', () => {
  // Grup n≥5 ama başarı paydası <5 (olgunlaşmamışlar): satır gri değil, yalnız o hücre metin + gri yazı
  const h = M.kombinasyonHtml(komb(satir('H', grup(10, 2, 3, 66.7, 9, 7, 8, 100), dolu())), {});
  const [s] = satirlarOf(h);
  assert.ok(s.startsWith('"'), 'satır gri değil');
  const [a] = altlarOf(s);
  assert.ok(a.startsWith('"'), 'alt satır gri değil');
  assert.match(a, /<div class="atolye-yetersiz">yetersiz \(n=3\)<\/div>/);
  assert.ok(!a.includes('66,7'));
  assert.match(a, /medyan 7,0 gün/);
});

test('sifir_medyan_deger_null_medyan_yetersiz', () => {
  const h = M.kombinasyonHtml(komb(satir('H', grup(10, 0, 10, 0, 9, 0, 8, 0), grup(10, 8, 10, null, 9, null, 8, 5))), {});
  const [a, b] = altlarOf(satirlarOf(h)[0]);
  assert.match(a, /%0,0 \(0\/10\)/, 'gerçek sıfır gizlenmez');
  assert.match(a, /medyan 0,0 gün/);
  assert.match(a, /₺0,00/);
  assert.match(b, /yetersiz \(n=10\)/, 'null medyan 0 sayılmaz');
  assert.match(b, /yetersiz \(n=9\)/);
});

test('sonuclanmamis_grup_fiyat_yok_demez', () => {
  // Tüm vakalar açık: ₺ kümesi boş olmasının nedeni fiyat değil
  const h = M.kombinasyonHtml(komb(satir('H', dolu(), grup(6, 0, 0, null, 0, null, 0, null))), {});
  const [, b] = altlarOf(satirlarOf(h)[0]);
  assert.ok(!b.includes('fiyat yok'));
  assert.strictEqual((b.match(/yetersiz \(n=0\)/g) || []).length, 3);
});

test('cubuk_genislik_kirpma_kiyas', () => {
  const h = M.kombinasyonHtml(komb(satir('H', grup(10, 8, 10, 80, 9, 7, 8, 200), grup(10, 8, 10, 140, 9, 7, 8, 50))), {});
  const [a, b] = altlarOf(satirlarOf(h)[0]);
  const gen = s => [...s.matchAll(/<span( class="kiyas")? style="width:([\d.]+)%"><\/span>/g)].map(r => [!!r[1], Number(r[2])]);
  assert.deepStrictEqual(gen(a), [[false, 80], [false, 100]], 'seçili: başarı %, ₺ en büyüğe göre');
  assert.deepStrictEqual(gen(b), [[true, 100], [true, 25]], 'kıyas .kiyas; >100 kırpılır');
  assert.ok(!/<canvas/.test(h) && !/new Chart/.test(KAYNAK), 'canvas yok');
});

test('tl_olcegi_yetersizi_saymaz', () => {
  // n<5 hücrenin ₺ değeri basılmıyorsa çubuk ölçeğinden de sızmaz
  const h = M.kombinasyonHtml(komb(satir('H', grup(10, 8, 10, 80, 9, 7, 8, 100), grup(3, 1, 3, 33, 3, 2, 3, 900), true)), {});
  const [a] = altlarOf(satirlarOf(h)[0]);
  assert.ok(a.includes('style="width:100%"'), '₺ en büyüğü gösterilen 100');
});

test('dipnot_birebir', () => {
  const h = M.kombinasyonHtml(komb(satir('H', dolu(), dolu())), {});
  assert.ok(h.includes('<ul class="atolye-dipnot"><li>Gruplar örtüşür; karşılaştırma gözlemseldir.</li></ul>'));
});

test('bos_satirlar_durum', () => {
  const h = M.kombinasyonHtml(komb(), {});
  assert.ok(h.includes('Enrolen içeren vakalarda birlikte kullanılan ilaçlar'));
  assert.ok(h.includes('class="atolye-durum"'));
  assert.ok(!h.includes('Gruplar örtüşür'), 'satır yokken dipnot yok');
  assert.ok(M.kombinasyonHtml({ x: 'E', duzey: 'etken' }, {}).includes('class="atolye-durum"'), 'satirlar eksik: patlamaz');
});

test('gecici_bant', () => {
  const k = komb(satir('H', dolu(), dolu()));
  const bant = 'class="atolye-gecici-bant">geçici, kaydedilmedi<';
  assert.ok(M.kombinasyonHtml(k, { gecici: { ilac_fiyat: { s1: 5 } } }).includes(bant));
  assert.ok(!M.kombinasyonHtml(k, { gecici: { ilac_fiyat: {} } }).includes(bant));
  assert.ok(!M.kombinasyonHtml(k, {}).includes(bant));
  assert.ok(!M.kombinasyonHtml(k).includes(bant));
});

test('x_bilinmiyor_okunur', () => {
  const h = M.kombinasyonHtml({ x: '(bilinmiyor)', duzey: 'etken', satirlar: [satir('H', dolu(), dolu())] }, {});
  assert.ok(sade(h).includes('Tanınamayan ilaç içeren vakalarda'));
  assert.ok(!h.includes('(bilinmiyor)'));
});

test('bagla_iki_kez_tek_cagri', () => {
  // kurucuYenile aynı köke yeniden çizer + bağlar; dinleyici birikmemeli
  const m = yukle();
  const dugme = { dataset: { kombY: 'H' } };
  const kok = { querySelectorAll: () => [dugme] };
  m.kombinasyonBagla(kok);
  m.kombinasyonBagla(kok);
  dugme.onclick();
  assert.deepStrictEqual(m.cagrilar, [['y', 'H']]);
});

test('kaynak_kurallari', () => {
  assert.ok(!/#[0-9a-f]{3,8}\b/i.test(KAYNAK), 'sabit hex yok');
  assert.ok(!/var\(--/.test(KAYNAK), 'tema rengi sınıflarda; inline renk yok');
  assert.ok(!/basarisiz_|SONUC_ETIKETLERI|sonucEtiket/.test(KAYNAK), 'sonuç listesi kopyalanmaz');
  const adlar = [...KAYNAK.matchAll(/^(?:async )?function (\w+)|^const (\w+)/gm)].map(r => r[1] || r[2]);
  for (const a of adlar) {
    assert.ok(a === 'kombinasyonHtml' || a === 'kombinasyonBagla' || /^_(kombinasyon|KOMBINASYON)/.test(a), `önek: ${a}`);
  }
});
