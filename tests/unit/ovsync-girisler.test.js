// tests/unit/ovsync-girisler.test.js — PLAN P7 (G-20260930-OVSYNC-TAKIP-IMPL):
// girişler — dashboard 6. stat hücresi (K7/design §6) + K14 kategori & vaka
// eşlemesi (§18.16) + K9 Görevler köprüsü + K10 🔔 "Tüm takibi aç" + loadDash
// ovsyncTakipGetir kablosu. Davranış testleri gerçek ui.js closures'ını kullanır
// (sandbox fonksiyonları lexical const'larını gerçek haliyle taşır).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const { loadBrowserModule } = require('./support/loadModule.js');

const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
  extra: {
    esc: s => String(s), escAttr: s => String(s), fmtTarih: s => String(s),
    // _dashStatRow bağımlılığı (helpers.js) — P7 testinde sayaç 0 deterministik
    suttenKesimeHazirSec: (a) => (a || []).filter(x => x && x.kesimVakti === true),
  },
  expose: ['_katTipMap', '_allKatTips', '_planliUremeTipler'],
});
const { _katTipMap, _allKatTips, _planliUremeTipler } = exposed;

// Kaynak bölgesi yardımcıları: mark ile başlayan üst-seviye fonksiyondan,
// sütun-0'daki sonraki fonksiyon bildirimine kadar dilim (kaynak kanıtı testleri).
const _bolge = (src, mark) => {
  const i0 = src.indexOf(mark);
  if (i0 < 0) return '';
  const sonraki = [src.indexOf('\nfunction ', i0 + 1), src.indexOf('\nasync function ', i0 + 1)]
    .filter(i => i >= 0);
  return src.slice(i0, sonraki.length ? Math.min(...sonraki) : src.length);
};

// ═════════════════════════════════════════════════════════════════════════════
// K7 — dashboard 6. stat hücresi: "🔄 Ovsync ›" + goTo('ovsync') + sınıf kuralı
// (R4: 2 kolonlu dash-row grid'inde 6. hücre son satırı tamamlar)
// ═════════════════════════════════════════════════════════════════════════════
const OV_ALERT = { sinif: 'alert', soru: false, sayi: 3 };
const OV_WARN = { sinif: 'warn', soru: false, sayi: 2 };
const OV_OK = { sinif: 'ok', soru: false, sayi: 0 };
const OV_BAYAT = { sinif: 'warn', soru: true, sayi: null };

const _ovHucresi = (html) =>
  /<div class="sc ([^"]*)" onclick="goTo\('ovsync'\)"><div class="sv">([^<]*)<\/div><div class="sl">([^<]*)<\/div><\/div>/.exec(html);

test('P7-K7: 6. stat hücresi çizilir — goTo(ovsync), alert sınıfı, aktif zincir sayısı, 🔄 Ovsync › etiketi', () => {
  const html = sandbox._dashStatRow([{ id: 'a' }], [], [], [], 0, OV_ALERT);
  const m = _ovHucresi(html);
  assert.ok(m, '6. .sc hücresi (onclick goTo ovsync) yok');
  assert.strictEqual(m[1], 'alert', 'S0>0 durumunda hücre sınıfı alert olmalı');
  assert.strictEqual(m[2], '3', 'aktif zincir sayısı hücrede görünmeli');
  assert.strictEqual(m[3], '🔄 Ovsync ›', 'hücre etiketi birebir');
});

test('P7-K7: yalnız bekleyen-başlatma > 0 → warn sınıfı', () => {
  const m = _ovHucresi(sandbox._dashStatRow([], [], [], [], 0, OV_WARN));
  assert.ok(m, '6. hücre yok');
  assert.strictEqual(m[1], 'warn');
  assert.strictEqual(m[2], '2');
});

test('P7-K7: sakin → ok sınıfı; sayı 0 "?" değil', () => {
  const m = _ovHucresi(sandbox._dashStatRow([], [], [], [], 0, OV_OK));
  assert.ok(m, '6. hücre yok');
  assert.strictEqual(m[1], 'ok');
  assert.strictEqual(m[2], '0', 'sakin 0 sayısı "?" olarak basılmamalı');
});

test('P7-K7: bayat/hata → warn sınıfı + "?" sayısı (sessiz varsayılan YASAK — §7.8)', () => {
  const m = _ovHucresi(sandbox._dashStatRow([], [], [], [], 0, OV_BAYAT));
  assert.ok(m, '6. hücre yok');
  assert.strictEqual(m[1], 'warn');
  assert.strictEqual(m[2], '?');
});

test('P7-K7: ovsync verisi gelmediyse (5-arg eski çağrı) hücre yine dürüst — warn + "?"', () => {
  const m = _ovHucresi(sandbox._dashStatRow([], [], [], [], 0));
  assert.ok(m, 'ovsync parametresiz çağrıda bile hücre çizilmeli');
  assert.strictEqual(m[1], 'warn');
  assert.strictEqual(m[2], '?');
});

// ═════════════════════════════════════════════════════════════════════════════
// K14 — görev kategorisi eşlemesi (§18.16: "işin ucunda gebelik varsa üreme")
// ═════════════════════════════════════════════════════════════════════════════
test('P7-K14: _katTipMap.ureme dörtlü liste; muayene listesinden GEBELIK_KONTROL çıkar', () => {
  assert.deepEqual(_katTipMap.ureme,
    ['TOHUMLAMA_PLANLI', 'OVSYNC_BASLAT', 'GEBELIK_KONTROL', 'TAKIP_MUAYENE']);
  assert.deepEqual(_katTipMap.muayene, ['MUAYENE', 'VETERINER_KONTROL'],
    'GEBELIK_KONTROL Muayene kategorisinden çıkarılmalı');
});

test('P7-K14: GEBELIK_KONTROL + TAKIP_MUAYENE Üreme filtresinde; GEBELIK_KONTROL Muayene filtresinde DEĞİL (kabul 2)', () => {
  const gk = { gorev_tipi: 'GEBELIK_KONTROL' };
  const tm = { gorev_tipi: 'TAKIP_MUAYENE' };
  assert.strictEqual(sandbox._kategoriFiltreUygun(gk, 'ureme', new Set(), {}, {}), true,
    'GEBELIK_KONTROL 🌱 Üreme çipinde görünmeli');
  assert.strictEqual(sandbox._kategoriFiltreUygun(tm, 'ureme', new Set(), {}, {}), true,
    'TAKIP_MUAYENE 🌱 Üreme çipinde görünmeli');
  assert.strictEqual(sandbox._kategoriFiltreUygun(gk, 'muayene', new Set(), {}, {}), false,
    'GEBELIK_KONTROL 🩺 Muayene filtresinde OLMAMALI');
  assert.strictEqual(sandbox._kategoriFiltreUygun({ gorev_tipi: 'MUAYENE' }, 'muayene', new Set(), {}, {}),
    true, 'mevcut MUAYENE tipi Muayene\'de kalır');
});

test('P7-K14: _allKatTips türetilmiş listesi yeni tipleri taşır (çip sayıları otomatik izler)', () => {
  assert.ok(_allKatTips.includes('GEBELIK_KONTROL') && _allKatTips.includes('TAKIP_MUAYENE'),
    '_allKatTips yeni üreme tiplerini içermeli');
});

test('P7-K14: _planliUremeTipler türetim kaynağını izler (4 tip; ayrı pencere davranışı YOK)', () => {
  assert.deepEqual([..._planliUremeTipler].sort(),
    ['GEBELIK_KONTROL', 'OVSYNC_BASLAT', 'TAKIP_MUAYENE', 'TOHUMLAMA_PLANLI'],
    'pencere istisnası turetimden gelir — kaynak tek');
});

// ═════════════════════════════════════════════════════════════════════════════
// K14 — vaka filtresi: hastalık-adı kümesi {Ovsync, Kistik Over, Anoestrus};
// protocol_family='OVSYNC' damgası kazanır; C3 sızıntı kilidi korunur
// ═════════════════════════════════════════════════════════════════════════════
const ADI = {
  dOv: 'Ovsync', dKis: 'Kistik Over', dAno: 'Anoestrus',
  dMet: 'Metrit', dEnd: 'Endometrit', dPyo: 'Pyometra', dRfm: 'RFM',
  dRet: 'Retensiyo Sekundinarum', dHem: 'Postpartum Hemoraji', dMas: 'Mastit',
};

test('P7-K14-vaka: damgasız vaka hastalık adıyla küme girer (Ovsync/Kistik Over/Anoestrus)', () => {
  const cases = ['dOv', 'dKis', 'dAno'].map((d, i) => ({ id: 'c' + i, disease_id: d, protocol_family: null }));
  const s = sandbox._uremeVakaCaseIds(cases, ADI);
  assert.strictEqual(s.size, 3, 'üç ad kümede');
});

test('P7-K14-vaka: C3 sızıntı güveni — Metrit/Endometrit/Pyometra/RFM/Retensiyo/Postpartum Hemoraji küme DIŞI', () => {
  const disi = ['dMet', 'dEnd', 'dPyo', 'dRfm', 'dRet', 'dHem'];
  const cases = disi.map((d, i) => ({ id: 'x' + i, disease_id: d, protocol_family: null }));
  const s = sandbox._uremeVakaCaseIds(cases, ADI);
  assert.strictEqual(s.size, 0,
    'enfeksiyon/doğum-sonrası hastalık vakaları Üreme filtresine sızmamalı (BUG-UREME-FILTRE-SIZINTI)');
});

test('P7-K14-vaka: protocol_family=OVSYNC damgası kazanır (hastalığı Metrit olsa da kümede kalır)', () => {
  const s = sandbox._uremeVakaCaseIds([{ id: 'cD', disease_id: 'dMet', protocol_family: 'OVSYNC' }], ADI);
  assert.ok(s.has('cD'), 'başlatılmış ovsync zinciri (damgalı) kümede kalmalı');
});

test('P7-K14-vaka: 1-arg çağrı (adiById yok) damga-only yol olarak bozulmaz (C3-6 sayı kanıtı)', () => {
  const s = sandbox._uremeVakaCaseIds([
    { id: 'cD', disease_id: 'dMet', protocol_family: 'OVSYNC' },
    { id: 'cX', disease_id: 'dOv', protocol_family: null },
  ]);
  assert.ok(s.has('cD'), 'damgalı kümede');
  assert.ok(!s.has('cX'), 'ad eşleşmesi olmadan damgasız küme dışı');
});

// ═════════════════════════════════════════════════════════════════════════════
// K9 — Görevler 🌱 Üreme çip başlığına "Tüm ovsync takibi →" köprüsü
// (yeni emoji YASAK — K9 varsayılanı)
// ═════════════════════════════════════════════════════════════════════════════
test('P7-K9: _uremeChipKopruHtml(true) — sh-link + goTo(ovsync) + "Tüm ovsync takibi →" (emoji yok)', () => {
  assert.equal(typeof sandbox._uremeChipKopruHtml, 'function', 'köprü üretici ui.js\'te tanımlı olmalı');
  const h = sandbox._uremeChipKopruHtml(true);
  assert.match(h, /class="sh-link"/, 'sh-link deseni (ui.js:472/480 kalıbı)');
  assert.match(h, /goTo\('ovsync'\)/);
  assert.ok(h.includes('Tüm ovsync takibi →'), 'köprü metni birebir');
  assert.ok(!/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u.test(h), 'köprüde emoji YASAK (K9 varsayılan: emoji yok)');
});

test('P7-K9: _uremeChipKopruHtml(false/undefined) boş döner — yalnız Üreme aktifken', () => {
  assert.strictEqual(sandbox._uremeChipKopruHtml(false), '');
  assert.strictEqual(sandbox._uremeChipKopruHtml(undefined), '');
});

test('P7-K9: setTaskKat + loadTasks köprü senkronunu çağırır (kablolar)', () => {
  const src = fs.readFileSync('js/ui.js', 'utf8');
  assert.match(_bolge(src, 'function setTaskKat'), /_uremeChipKopruSenkron\(\)/,
    'kategori değişiminde köprü senkronlanmalı');
  assert.match(_bolge(src, 'async function loadTasks'), /_uremeChipKopruSenkron\(\)/,
    'list yenilemede köprü senkronlanmalı');
});

// ═════════════════════════════════════════════════════════════════════════════
// K7/K10 — loadDash ovsyncTakipGetir kablosu + 🔔 🌱 "Tüm takibi aç →" sh-link
// ═════════════════════════════════════════════════════════════════════════════
test('P7: loadDash ovsyncTakipGetir çağırır, _ovsyncStatSinif ile 6. hücreye bağlar', () => {
  const src = fs.readFileSync('js/ui.js', 'utf8');
  const ld = _bolge(src, 'async function loadDash');
  assert.ok(ld, 'loadDash bulunamadı');
  assert.match(ld, /ovsyncTakipGetir\(/, 'loadDash takip verisini çekmeli');
  assert.match(ld, /_ovsyncStatSinif\(/, 'sınıf kuralı P6 yardımcısından gelmeli');
  assert.match(ld, /_dashStatRow\([^)]*,\s*ovStat\)/, '6. hücre verisi stat satırına geçmeli');
});

test('P7-K10: 🔔 🌱 İlk Tohumlama başlığı "Tüm takibi aç →" sh-link taşır (taze + önbellek kolu)', () => {
  const src = fs.readFileSync('js/ui.js', 'utf8');
  const spe = _bolge(src, 'async function _showProtokolEkran');
  assert.ok(spe, '_showProtokolEkran bulunamadı');
  assert.strictEqual((spe.match(/Tüm takibi aç →/g) || []).length, 2,
    'taze ve önbellek kollarının İKİSİNDE de link olmalı');
  assert.match(spe, /class="sh-link"/, 'sh-link deseni');
  assert.match(spe, /goTo\('ovsync'\)/, 'link ovsync sayfasına götürmeli');
});
