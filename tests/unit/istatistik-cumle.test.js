'use strict';
// İstatistik Atölyesi AP1 Task 9 — js/istatistik/cumle.js birim testleri.
// Cümle modeli saf modüldür: varsayılan açılış (spec §4.4), slot güncelleme kuralları
// (plan P4), okunur başlık, sunucu doğrulayıcısı stat_cumle_dogrula'nın istemci aynası
// (supabase/migrations/20261017000002_stat_atolye_seri.sql), kararlı anahtar ve sonuç
// etiketleri (tek kaynak, bilinmeyen değer → 'Diğer').
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const KOK = path.join(__dirname, '..', '..');
const KAYNAK = path.join(KOK, 'js', 'istatistik', 'cumle.js');
let M = {};
try { M = require(KAYNAK); } catch (e) { M = {}; }

const ENT = 'aaaaaaaa-0000-4000-8000-0000000000e1';
const PNO = 'aaaaaaaa-0000-4000-8000-0000000000b2';
const SEC = {
  donem: { bas: '2025-10-18', bit: '2026-10-18' },
  toplam_n: 31,
  // Bilerek n sırasız: en çok vakalı olan ilk eleman değil.
  hastaliklar: [
    { id: PNO, ad: 'Pnömoni', kategori: 'Solunum', n: 9 },
    { id: ENT, ad: 'Enterit', kategori: 'Sindirim', n: 22 },
  ],
  kategoriler: [{ ad: 'Sindirim', n: 22 }, { ad: 'Solunum', n: 9 }],
  x_adaylari: [], y_adaylari: [],
};

function derinDondur(o) {
  if (o && typeof o === 'object') {
    Object.values(o).forEach(derinDondur);
    Object.freeze(o);
  }
  return o;
}
function kopya(o) { return JSON.parse(JSON.stringify(o)); }
function cumleOrnek(over) {
  const c = {
    v: 1, alan: 'saglik',
    hastalik: { tip: 'hastalik', deger: ENT },
    ilac: { duzey: 'etken', x: null, y: null },
    kiyas_grubu: 'tumu',
    olculer: ['saglik_basari', 'saglik_kapanma_gunu', 'saglik_vaka_tl'],
    kirilim: 'ilac',
    donem: { tip: 'son_ay', n: 12 },
    kiyas_duzeyi: ['biz'],
  };
  return Object.assign(c, over || {});
}

// ── varsayılan ───────────────────────────────────────────────────────────────
test('varsayilan_en_cok', () => {
  const c = M.cumleVarsayilan(SEC);
  assert.deepStrictEqual(c, cumleOrnek());
  assert.deepStrictEqual(M.cumleIstemciDogrula(c), []);
  // Ölçü listesi: 5 etkin + pasif doz (P8)
  assert.deepStrictEqual(M.ATOLYE_OLCULER.map(o => o.ad),
    ['saglik_basari', 'saglik_kapanma_gunu', 'saglik_tedavi_suresi', 'saglik_vaka_tl', 'saglik_basari_tl', 'doz']);
  assert.deepStrictEqual(M.ATOLYE_OLCULER.filter(o => o.pasif).map(o => o.ad), ['doz']);
});

test('varsayilan_bos_secenek', () => {
  for (const s of [null, undefined, {}, { hastaliklar: [] }, { hastaliklar: [{ id: null, ad: 'x', n: 50 }] }]) {
    const c = M.cumleVarsayilan(s);
    assert.deepStrictEqual(c.hastalik, { tip: 'tumu', deger: null }, JSON.stringify(s));
    assert.strictEqual(c.kirilim, 'ilac');
    assert.deepStrictEqual(M.cumleIstemciDogrula(c), []);
  }
});

// ── güncelleme ───────────────────────────────────────────────────────────────
test('guncelle_x_kirilim_yok', () => {
  const c0 = cumleOrnek();
  const c1 = M.cumleGuncelle(c0, 'x', 'Enrofloksasin');
  assert.strictEqual(c1.ilac.x, 'Enrofloksasin');
  assert.strictEqual(c1.kirilim, 'yok');       // P4: ilaç kırılımı x ile birlikte olmaz
  assert.strictEqual(c1.ilac.y, null);
  assert.strictEqual(c1.kiyas_grubu, 'tumu');
  assert.deepStrictEqual(M.cumleIstemciDogrula(c1), []);
  // zaman kırılımı x seçilince korunur
  const c2 = M.cumleGuncelle(cumleOrnek({ kirilim: 'ay' }), 'x', 'Enrofloksasin');
  assert.strictEqual(c2.kirilim, 'ay');
  // x varken kırılım 'ilac' reddedilir: cümle aynen döner
  assert.strictEqual(M.cumleGuncelle(c1, 'kirilim', 'ilac'), c1);
  assert.strictEqual(M.cumleGuncelle(c1, 'kirilim', 'ceyrek').kirilim, 'ceyrek');
  // x kaldırılınca y düşer, kıyas tümü
  const c3 = M.cumleGuncelle(M.cumleGuncelle(c1, 'y', 'Halocur'), 'x', null);
  assert.strictEqual(c3.ilac.x, null);
  assert.strictEqual(c3.ilac.y, null);
  assert.strictEqual(c3.kiyas_grubu, 'tumu');
});

test('guncelle_y_x_y_siz', () => {
  const cx = M.cumleGuncelle(cumleOrnek(), 'x', 'Enrofloksasin');
  const cy = M.cumleGuncelle(cx, 'y', 'Halocur');
  assert.strictEqual(cy.ilac.y, 'Halocur');
  assert.strictEqual(cy.kiyas_grubu, 'x_y_siz');
  assert.deepStrictEqual(M.cumleIstemciDogrula(cy), []);
  // kıyası tümüne çevirmek serbest, y varken
  assert.strictEqual(M.cumleGuncelle(cy, 'kiyas_grubu', 'tumu').kiyas_grubu, 'tumu');
  // y kaldırılınca kıyas tümü
  const cn = M.cumleGuncelle(cy, 'y', null);
  assert.strictEqual(cn.ilac.y, null);
  assert.strictEqual(cn.kiyas_grubu, 'tumu');
  // x yokken y reddedilir; y = x reddedilir; y yokken x_y_siz reddedilir
  const c0 = cumleOrnek();
  assert.strictEqual(M.cumleGuncelle(c0, 'y', 'Halocur'), c0);
  assert.strictEqual(M.cumleGuncelle(cx, 'y', 'Enrofloksasin'), cx);
  assert.strictEqual(M.cumleGuncelle(cx, 'kiyas_grubu', 'x_y_siz'), cx);
});

test('guncelle_hastalik_xy_sifir', () => {
  const cy = M.cumleGuncelle(M.cumleGuncelle(cumleOrnek(), 'x', 'Enrofloksasin'), 'y', 'Halocur');
  const ch = M.cumleGuncelle(cy, 'hastalik', { tip: 'hastalik', deger: PNO });
  assert.deepStrictEqual(ch.hastalik, { tip: 'hastalik', deger: PNO });
  assert.deepStrictEqual(ch.ilac, { duzey: 'etken', x: null, y: null });
  assert.strictEqual(ch.kiyas_grubu, 'tumu');
  const cd = M.cumleGuncelle(cy, 'duzey', 'preparat');
  assert.deepStrictEqual(cd.ilac, { duzey: 'preparat', x: null, y: null });
  assert.strictEqual(cd.kiyas_grubu, 'tumu');
  assert.deepStrictEqual(M.cumleIstemciDogrula(ch), []);
  assert.deepStrictEqual(M.cumleIstemciDogrula(cd), []);
});

test('guncelle_duzey_gecersiz', () => {
  const cy = M.cumleGuncelle(M.cumleGuncelle(cumleOrnek(), 'x', 'Enrofloksasin'), 'y', 'Halocur');
  for (const d of ['marka', '', null, undefined, 'toString']) {
    assert.strictEqual(M.cumleGuncelle(cy, 'duzey', d), cy, String(d));   // reddedilir: cümle aynen, x/y korunur
  }
  assert.strictEqual(M.cumleGuncelle(cy, 'duzey', 'sinif').ilac.duzey, 'sinif');
});

test('guncelle_son_olcu_kalir', () => {
  const c0 = cumleOrnek({ olculer: ['saglik_basari'] });
  assert.strictEqual(M.cumleGuncelle(c0, 'olculer', []), c0);
  // pasif doz, bilinmeyen ve tekrar cümleye girmez (P8; sunucu RAISE eder)
  assert.strictEqual(M.cumleGuncelle(c0, 'olculer', ['doz']), c0);
  assert.strictEqual(M.cumleGuncelle(c0, 'olculer', ['saglik_basari', 'saglik_doz']), c0);
  assert.strictEqual(M.cumleGuncelle(c0, 'olculer', ['saglik_basari', 'saglik_basari']), c0);
  const c1 = M.cumleGuncelle(c0, 'olculer', ['saglik_tedavi_suresi', 'saglik_basari_tl']);
  assert.deepStrictEqual(c1.olculer, ['saglik_tedavi_suresi', 'saglik_basari_tl']);
});

test('guncelle_girdi_degismez', () => {
  const c0 = derinDondur(cumleOrnek());
  const once = JSON.stringify(c0);
  const adimlar = [
    ['x', 'Enrofloksasin'], ['y', 'Halocur'], ['kiyas_grubu', 'tumu'], ['hastalik', { tip: 'kategori', deger: 'Meme' }],
    ['duzey', 'sinif'], ['olculer', ['saglik_basari']], ['kirilim', 'yil'], ['donem', { tip: 'tumu' }],
  ];
  let c = c0;
  for (const [slot, deger] of adimlar) {
    const onceki = c;
    const yeni = M.cumleGuncelle(onceki, slot, deger);
    assert.notStrictEqual(yeni, onceki, slot);
    c = derinDondur(yeni);
  }
  assert.strictEqual(JSON.stringify(c0), once);
  assert.deepStrictEqual(c.donem, { tip: 'tumu' });
  assert.throws(() => M.cumleGuncelle(c0, 'bilinmeyen_slot', 1), /slot/);
  // Saf modül: kaynakta DOM / pencere / rpc yok; çıplak bağlamda yüklenip çalışır.
  const src = fs.readFileSync(KAYNAK, 'utf8');
  assert.doesNotMatch(src, /\bwindow\b|\bdocument\b|\brpc\s*\(|localStorage|fetch\s*\(/);
  const bag = { module: { exports: {} } };
  vm.runInNewContext(src, bag);
  const v = bag.module.exports.cumleVarsayilan(kopya(SEC));
  assert.strictEqual(bag.module.exports.cumleBaslik(v, kopya(SEC)),
    'Sağlık › Enterit vakalarında › Başarı oranı, Kapanma hızı, Vaka başı ₺ › etken maddeye göre › son 12 ay');
});

// ── başlık ───────────────────────────────────────────────────────────────────
test('baslik_tam', () => {
  const c = cumleOrnek({ ilac: { duzey: 'etken', x: 'Enrofloksasin', y: 'Halocur' }, kiyas_grubu: 'x_y_siz', kirilim: 'yok' });
  assert.strictEqual(M.cumleBaslik(c, SEC),
    'Sağlık › Enterit vakalarında › Enrofloksasin + Halocur içeren › Başarı oranı, Kapanma hızı, Vaka başı ₺ › son 12 ay');
});

test('baslik_kategori', () => {
  const c = cumleOrnek({ hastalik: { tip: 'kategori', deger: 'Meme' }, olculer: ['saglik_basari'], donem: { tip: 'yil', yil: 2026 } });
  assert.strictEqual(M.cumleBaslik(c, SEC), 'Sağlık › Meme vakalarında › Başarı oranı › etken maddeye göre › 2026 yılı');
  const t = cumleOrnek({ hastalik: { tip: 'tumu', deger: null }, olculer: ['saglik_basari'], kirilim: 'yok' });
  assert.strictEqual(M.cumleBaslik(t, SEC), 'Sağlık › Tüm hastalıklar vakalarında › Başarı oranı › son 12 ay');
  // seçeneklerde bulunmayan id → "Seçili hastalık"; seçenek yok da aynı
  const u = cumleOrnek({ hastalik: { tip: 'hastalik', deger: 'aaaaaaaa-0000-4000-8000-000000000999' }, kirilim: 'yok',
    olculer: ['saglik_basari_tl'] });
  assert.strictEqual(M.cumleBaslik(u, SEC), 'Sağlık › Seçili hastalık vakalarında › Başarı başına ₺ › son 12 ay');
  assert.strictEqual(M.cumleBaslik(u, null), 'Sağlık › Seçili hastalık vakalarında › Başarı başına ₺ › son 12 ay');
  // (bilinmiyor) okunur etiketle
  const b = cumleOrnek({ ilac: { duzey: 'etken', x: '(bilinmiyor)', y: null }, kirilim: 'yok', olculer: ['saglik_basari'] });
  assert.strictEqual(M.cumleBaslik(b, SEC), 'Sağlık › Enterit vakalarında › Tanınamayan ilaç içeren › Başarı oranı › son 12 ay');
});

test('baslik_ay_kirilim', () => {
  const b = k => M.cumleBaslik(cumleOrnek(k), SEC);
  assert.strictEqual(b({ kirilim: 'ay', olculer: ['saglik_tedavi_suresi'] }),
    'Sağlık › Enterit vakalarında › Tedavi süresi › aylık › son 12 ay');
  assert.match(b({ kirilim: 'ceyrek' }), / › çeyreklik › son 12 ay$/);
  assert.match(b({ kirilim: 'yil' }), / › yıllık › son 12 ay$/);
  assert.match(b({ ilac: { duzey: 'preparat', x: null, y: null } }), / › preparata göre › /);
  assert.match(b({ ilac: { duzey: 'sinif', x: null, y: null } }), / › sınıfa göre › /);
  assert.match(b({ donem: { tip: 'son_ay', n: 3 } }), / › son 3 ay$/);
});

test('baslik_aralik_tarih', () => {
  const c = cumleOrnek({ kirilim: 'yok', olculer: ['saglik_basari'], donem: { tip: 'aralik', bas: '2026-03-01', bit: '2026-06-30' } });
  assert.strictEqual(M.cumleBaslik(c, SEC), 'Sağlık › Enterit vakalarında › Başarı oranı › 01.03.2026–30.06.2026');
  const t = cumleOrnek({ kirilim: 'yok', olculer: ['saglik_basari'], donem: { tip: 'tumu' } });
  assert.strictEqual(M.cumleBaslik(t, SEC), 'Sağlık › Enterit vakalarında › Başarı oranı › tüm zamanlar');
});

// ── istemci doğrulama (stat_cumle_dogrula aynası) ───────────────────────────
test('dogrula_y_x_yok', async (t) => {
  const c = cumleOrnek({ ilac: { duzey: 'etken', x: null, y: 'Halocur' } });
  assert.ok(M.cumleIstemciDogrula(c).includes('ilac.y:x_yok'), JSON.stringify(M.cumleIstemciDogrula(c)));
  assert.deepStrictEqual(M.cumleIstemciDogrula(cumleOrnek()), []);

  // Sunucu kurallarının tamamı: her bozulma en az beklenen hata yolunu üretir.
  const B = (f) => { const x = cumleOrnek(); f(x); return x; };
  const durumlar = [
    ['cumle:nesne_degil', null], ['cumle:nesne_degil', []], ['cumle:nesne_degil', 'x'],
    ['gecici:bilinmeyen_anahtar', B(x => { x.gecici = {}; })],
    ['donem:eksik', B(x => { delete x.donem; })],
    ['v:surum', B(x => { x.v = 2; })],
    ['alan:gecersiz', B(x => { x.alan = 'ekonomi'; })],
    ['hastalik:nesne_degil', B(x => { x.hastalik = null; })],
    ['hastalik.ad:bilinmeyen_anahtar', B(x => { x.hastalik.ad = 'Enterit'; })],
    ['hastalik.deger:tumu_ile_deger', B(x => { x.hastalik = { tip: 'tumu', deger: 'Meme' }; })],
    ['hastalik.deger:metin_degil', B(x => { x.hastalik = { tip: 'kategori', deger: '  ' }; })],
    ['hastalik.deger:uuid_degil', B(x => { x.hastalik = { tip: 'hastalik', deger: 'Enterit' }; })],
    ['hastalik.tip:gecersiz', B(x => { x.hastalik = { tip: 'grup', deger: null }; })],
    ['ilac:nesne_degil', B(x => { x.ilac = 'etken'; })],
    ['ilac.z:bilinmeyen_anahtar', B(x => { x.ilac.z = 1; })],
    ['ilac.duzey:gecersiz', B(x => { x.ilac.duzey = 'marka'; })],
    ['ilac.x:metin_degil', B(x => { x.ilac.x = 5; })],
    ['ilac.y:metin_degil', B(x => { x.ilac.x = 'A'; x.ilac.y = ' '; x.kirilim = 'yok'; })],
    ['ilac.y:x_ile_ayni', B(x => { x.ilac.x = 'A'; x.ilac.y = 'A'; x.kirilim = 'yok'; })],
    ['kiyas_grubu:gecersiz', B(x => { x.kiyas_grubu = 'x_siz'; })],
    ['kiyas_grubu:y_yok', B(x => { x.kiyas_grubu = 'x_y_siz'; })],
    ['olculer:dizi_degil', B(x => { x.olculer = 'saglik_basari'; })],
    ['olculer:bos', B(x => { x.olculer = []; })],
    ['olculer:metin_degil', B(x => { x.olculer = [1]; })],
    ['olculer:doz_hesaplanmaz', B(x => { x.olculer = ['saglik_basari', 'saglik_doz']; })],
    ['olculer:bilinmeyen', B(x => { x.olculer = ['doz']; })],
    ['olculer:tekrar', B(x => { x.olculer = ['saglik_basari', 'saglik_basari']; })],
    ['kirilim:gecersiz', B(x => { x.kirilim = 'hafta'; })],
    ['kirilim:x_ile_ilac', B(x => { x.ilac.x = 'A'; })],
    ['donem:nesne_degil', B(x => { x.donem = 'son_ay'; })],
    ['donem.tip:gecersiz', B(x => { x.donem = { tip: 'hafta' }; })],
    ['donem.yil:bilinmeyen_anahtar', B(x => { x.donem = { tip: 'son_ay', n: 12, yil: 2026 }; })],
    ['donem.n:gecersiz', B(x => { x.donem = { tip: 'son_ay', n: 5 }; })],
    ['donem.n:gecersiz', B(x => { x.donem = { tip: 'son_ay', n: '12' }; })],
    ['donem.yil:gecersiz', B(x => { x.donem = { tip: 'yil', yil: 1800 }; })],
    ['donem.bas:tarih_degil', B(x => { x.donem = { tip: 'aralik', bas: '1.3.2026', bit: '2026-06-30' }; })],
    ['donem:tarih_degil', B(x => { x.donem = { tip: 'aralik', bas: '2026-02-30', bit: '2026-06-30' }; })],
    ['donem:ters', B(x => { x.donem = { tip: 'aralik', bas: '2026-06-30', bit: '2026-03-01' }; })],
    ['kiyas_duzeyi:yalniz_biz', B(x => { x.kiyas_duzeyi = ['biz', 'tr']; })],
  ];
  for (const [kod, cumle] of durumlar) {
    await t.test(`kural ${kod}`, () => {
      const h = M.cumleIstemciDogrula(cumle);
      assert.ok(h.includes(kod), `${kod} bekleniyordu, gelen ${JSON.stringify(h)}`);
    });
  }
  // Geçerli kenarlar: tumu deger yok, artık yıl, tek günlük aralık, tumu dönemi, büyük harf uuid
  for (const c of [
    B(x => { x.hastalik = { tip: 'tumu' }; }),
    B(x => { x.donem = { tip: 'aralik', bas: '2024-02-29', bit: '2024-02-29' }; }),
    B(x => { x.donem = { tip: 'tumu' }; }),
    B(x => { x.hastalik = { tip: 'hastalik', deger: ENT.toUpperCase() }; }),
  ]) assert.deepStrictEqual(M.cumleIstemciDogrula(c), [], JSON.stringify(c));
  // Ölçü listesi sunucu c_olcu dizisiyle aynı (SQL tek kaynak)
  const sql = fs.readFileSync(path.join(KOK, 'supabase/migrations/20261017000002_stat_atolye_seri.sql'), 'utf8');
  const blok = sql.match(/c_olcu CONSTANT text\[\] := ARRAY\[([^\]]+)\]/)[1];
  const sqlOlcu = blok.match(/'([a-z_]+)'/g).map(s => s.slice(1, -1));
  assert.deepStrictEqual(M.ATOLYE_OLCULER.filter(o => !o.pasif).map(o => o.ad), sqlOlcu);
});

// ── anahtar ──────────────────────────────────────────────────────────────────
test('anahtar_kararli', () => {
  const a = cumleOrnek();
  const b = {
    kiyas_duzeyi: ['biz'], donem: { n: 12, tip: 'son_ay' }, kirilim: 'ilac',
    olculer: ['saglik_basari', 'saglik_kapanma_gunu', 'saglik_vaka_tl'], kiyas_grubu: 'tumu',
    ilac: { y: null, x: null, duzey: 'etken' }, hastalik: { deger: ENT, tip: 'hastalik' }, alan: 'saglik', v: 1,
  };
  assert.strictEqual(M.cumleAnahtar(a), M.cumleAnahtar(b));
  assert.strictEqual(JSON.parse(M.cumleAnahtar(a)).donem.n, 12);
  // dizi sırası anlamlıdır (ölçü sırası = kart sırası)
  const c = cumleOrnek({ olculer: ['saglik_vaka_tl', 'saglik_basari', 'saglik_kapanma_gunu'] });
  assert.notStrictEqual(M.cumleAnahtar(a), M.cumleAnahtar(c));
  assert.notStrictEqual(M.cumleAnahtar(a), M.cumleAnahtar(cumleOrnek({ donem: { tip: 'son_ay', n: 24 } })));
});

// ── AK-5 ─────────────────────────────────────────────────────────────────────
test('protokol_kelimesi_yok', () => {
  const dizin = path.join(KOK, 'js', 'istatistik');
  const dosyalar = fs.readdirSync(dizin).filter(f => f.endsWith('.js'));
  assert.ok(dosyalar.includes('cumle.js'));
  for (const f of dosyalar) {
    const metin = fs.readFileSync(path.join(dizin, f), 'utf8');
    assert.strictEqual((metin.match(/protokol/gi) || []).length, 0, `js/istatistik/${f}`);
  }
});

// ── sonuç etiketleri (tek kaynak) ────────────────────────────────────────────
test('sonuc_etiket_bilinen', () => {
  // Anahtarlar v_stat_saglik_vaka sonuc CASE'iyle birebir (SQL tek kaynak)
  const sql = fs.readFileSync(path.join(KOK, 'supabase/migrations/20261017000001_stat_saglik_vaka.sql'), 'utf8');
  const vaka = sql.slice(sql.indexOf('sonuclu AS ('), sql.indexOf('END AS sonuc'));
  const sqlSonuc = [...new Set((vaka.match(/(?:THEN|ELSE) '[a-z_]+'/g) || []).map(s => s.slice(6, -1)))].sort();
  assert.deepStrictEqual(Object.keys(M.SONUC_ETIKETLERI).sort(), sqlSonuc);
  assert.deepStrictEqual(sqlSonuc, ['basarili', 'basarisiz_nuks', 'basarisiz_olum_kesim', 'basarisiz_tedavi_degisti', 'olgunlasmamis']);
  assert.deepStrictEqual(M.sonucEtiket('basarisiz_tedavi_degisti'), { etiket: 'Başarısız (tedavi değişti)', bilinmeyen: false });
  for (const k of sqlSonuc) {
    const e = M.sonucEtiket(k);
    assert.strictEqual(e.bilinmeyen, false, k);
    assert.strictEqual(e.etiket, M.SONUC_ETIKETLERI[k]);
    assert.ok(e.etiket && e.etiket !== 'Diğer', k);
  }
  // KF2-Ö2: 'Açık' yalnız durum 'acik' iken; durum geçilmez/bilinmezse fail-closed 'Diğer' (kapali_tarihsiz sızmaz)
  assert.deepStrictEqual(M.sonucEtiket(null, 'acik'), { etiket: 'Açık', bilinmeyen: false });
  assert.deepStrictEqual(M.sonucEtiket(undefined, 'acik'), { etiket: 'Açık', bilinmeyen: false });
  for (const d of [undefined, null, '', 'sonuclandi', 'ACIK', 'kapali']) {
    assert.deepStrictEqual(M.sonucEtiket(null, d), { etiket: 'Diğer', bilinmeyen: true }, String(d));
  }
  assert.deepStrictEqual(M.sonucEtiket(null), { etiket: 'Diğer', bilinmeyen: true });
  assert.deepStrictEqual(M.sonucEtiket(undefined), { etiket: 'Diğer', bilinmeyen: true });
  assert.deepStrictEqual(M.sonucEtiket('basarili', 'acik'), { etiket: M.SONUC_ETIKETLERI.basarili, bilinmeyen: false });
  // 'acik' bir durum değeridir, sonuc değeri değil (000001:138-144/168) → fail-closed 'Diğer'
  assert.deepStrictEqual(M.sonucEtiket('acik'), { etiket: 'Diğer', bilinmeyen: true });
  // kapalı ama kapanış tarihi yok: sonuc NULL ama açık değil (v_stat_saglik_vaka durum)
  assert.deepStrictEqual(M.sonucEtiket(null, 'kapali_tarihsiz'), { etiket: 'Kapanış tarihi yok', bilinmeyen: false });
});

test('sonuc_etiket_bilinmeyen_diger', () => {
  for (const d of ['basarisiz_yeni', 'BASARILI', '', 5, {}]) {
    assert.deepStrictEqual(M.sonucEtiket(d), { etiket: 'Diğer', bilinmeyen: true }, JSON.stringify(d));
  }
  assert.deepStrictEqual(M.sonucEtiket('toString'), { etiket: 'Diğer', bilinmeyen: true });
});
