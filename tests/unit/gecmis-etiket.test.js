// tests/unit/gecmis-etiket.test.js
// U1 md.1 — islem_log tip → Türkçe etiket/ikon TEK kaynak (js/gecmis.js).
//
// Kilitlenen sözleşmeler:
//   1. Harita TAM: eski iki kopyanın (ui.js _ISLEM_ETK/_ISLEM_ICO 6 tip +
//      openIslemDetay yerel LABEL/ICO 14 tip) birleşimi + geri-alma rotaları
//      (_GM_UNDO_ISLEM_TIPLERI, HAYVAN/TOHUMLAMA/GÖREV GUNCELLENDI) + trigger/
//      RPC yazıcıları (TEDAVI_GUN_EKLENDI, TEDAVI_SEANS_TAMAM/IPTAL,
//      HASTALIK_GUNCELLENDI) — bilinen HER tipin Türkçe etiketi VAR.
//   2. Ham BUYUK_HARF_KOD hiçbir kartta görünmez: bilinen tipte etiket ≠ kod,
//      '_' içermez; bilinmeyen tipte okunur yedek ('İşlem: ...' — küçük harf).
//   3. Her etiketin emojisi VAR (_GM_ISLEM_TIP_EMOJI birebir anahtar kümesi).
//
// RED-BEFORE: _GM_ISLEM_TIP_ETIKET gecmis.js'te yokken §A testleri kırmızıdır.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { exposed } = loadBrowserModule('js/gecmis.js', {
  expose: ['_GM_ISLEM_TIP_ETIKET', '_GM_ISLEM_TIP_EMOJI', '_gmIslemTipEtiket', '_gmIslemTipEmoji'],
});
const { _GM_ISLEM_TIP_ETIKET, _GM_ISLEM_TIP_EMOJI, _gmIslemTipEtiket, _gmIslemTipEmoji } = exposed;

// ── §A: harita tam — bilinen tüm tipler Türkçe ──────────────────────

// Eski LABEL haritası (openIslemDetay yerel kopyası — kaldırıldı) anahtar kümesi
const ESKI_LABEL = [
  'HAYVAN_EKLENDI', 'TOHUMLAMA', 'DOGUM_KAYDI', 'HASTALIK_KAYDI', 'TEDAVI_GUNCELLE',
  'KIZGINLIK', 'ABORT_KAYDI', 'SATIS_KAYDI', 'OLUM_KAYDI', 'SUTTEN_KESME',
  'KISIR_ISARETLE', 'KISIR_KALDIR', 'VAKA_ACILDI', 'TEDAVI_GUN_EKLENDI',
];
// Eski _ISLEM_ETK/_ISLEM_ICO (ui.js — kaldırıldı) anahtar kümesi
const ESKI_ETK = ['HAYVAN_EKLENDI', 'ABORT_KAYDI', 'KIZGINLIK_KAYDI', 'ASI_KAYDI', 'ASI_ERTELEME', 'TOPLU_ILAC'];
// Geri-alma rotaları + trigger/RPC yazıcıları (migration taraması; _GM_UNDO_ISLEM_TIPLERI
// zaten haritada olanları içerir — burada yalnız ek anahtarlar). GOREV_TAMAMLA ve
// VAKA_TOHUMLAMA_EKLE canlı demo verisinde de gözlendi (13.09 gün görünümü — U1
// ekran kanıtı); geri_al/temizlik komutları islem_log INSERT taramasından.
const ROTA_EKLERI = [
  'HAYVAN_GUNCELLENDI', 'TOHUMLAMA_GUNCELLENDI', 'HASTALIK_GUNCELLENDI',
  'GOREV_GUNCELLENDI', 'GOREV_EKLENDI', 'GOREV_GUNCELLE', 'GOREV_TAMAMLA', 'GOREV_OTOKAPAT',
  'TEDAVI_SEANS_TAMAM', 'TEDAVI_SEANS_IPTAL', 'SEANS_EKLENDI', 'SEANS_GUNCELLENDI', 'SEANS_SILINDI',
  'VAKA_TOHUMLAMA_EKLE', 'KIZGINLIK_VAKA_ACILDI', 'GEBELIK_MANUEL', 'DOGUM_OTOMATIK',
  'TOHUMLAMA_SONUC', 'TOHUMLAMA_OTOMATIK_BOS', 'TOHUMLAMA_PLANLI_IPTAL', 'TOHUMLAMA_ERTELE',
  'TOHUMLAMA_DURUMU_ONAYLA', 'TOHUMLAMA_DUPLICATE_TEMIZLE',
  'ASI_EKLE', 'ASI_GUNCELLE', 'ASI_SIL', 'ASI_GOREV_PLAN', 'ASI_RAPEL_DUPE_CLEANUP',
  'TEDAVI_GUNCELLENDI', 'TEDAVI_GUN_TAMAMLA', 'TEDAVI_SIL', 'SUTTEN_KESME_GERI_AL',
];

test('harita tam: eski iki kopyanın birleşimi + geri-alma rotaları + yazıcılar kapalı', () => {
  const bilinen = [...new Set([...ESKI_LABEL, ...ESKI_ETK, ...ROTA_EKLERI])];
  const eksik = bilinen.filter(t => !_GM_ISLEM_TIP_ETIKET[t]);
  assert.deepStrictEqual(eksik, [], 'bilinen tiplerin hepsi haritada olmalı — eksik: ' + eksik.join(','));
});

test('bilinen tipte etiket Türkçe: ham kod YOK, alt çizgi YOK, kodla AYNI değil', () => {
  for (const [tip, etiket] of Object.entries(_GM_ISLEM_TIP_ETIKET)) {
    assert.ok(etiket && etiket.length > 0, `${tip}: etiket boş olmamalı`);
    assert.ok(!etiket.includes('_'), `${tip}: etikette alt çizgi olmamalı (${etiket})`);
    assert.notStrictEqual(etiket, tip, `${tip}: etiket ham kodun kendisi olmamalı`);
    // ham kod biçimi = TAMAMEN BÜYÜK harf/alt çizgi dizisi; TR Title Case etiket asla bu biçimde değil
    assert.ok(!/^[A-ZÇĞİÖŞÜ_]+$/.test(etiket), `${tip}: etiket ham kod biçiminde olmamalı (${etiket})`);
  }
});

test('her etiketin emojisi VAR — emoji haritası birebir aynı anahtar kümesi', () => {
  assert.deepStrictEqual(
    Object.keys(_GM_ISLEM_TIP_EMOJI).sort(),
    Object.keys(_GM_ISLEM_TIP_ETIKET).sort(),
    'etiket ve emoji haritaları aynı tip kümesini kapsamalı',
  );
  for (const tip of Object.keys(_GM_ISLEM_TIP_ETIKET)) {
    assert.ok(_gmIslemTipEmoji(tip) && _gmIslemTipEmoji(tip) !== '📋',
      `${tip}: bilinen tip varsayılan 📋'ye düşmemeli`);
  }
});

// ── §B: bilinmeyen tip — okunur yedek, ham kod YOK ──────────────────

test('bilinmeyen tip: "İşlem: ..." yedeği — alt çizgi boşluk, küçük harf (düz toLowerCase)', () => {
  // kod ASCII'dir: GUN→gun, ISLEM→islem (harf DÖNÜŞÜMÜ yok — zarf örneği 'tedavi')
  assert.strictEqual(_gmIslemTipEtiket('TEDAVI_GUN_EKLENDI_BENZERI_YENI'), 'İşlem: tedavi gun eklendi benzeri yeni');
  assert.strictEqual(_gmIslemTipEtiket('YENI_ISLEM_TIPI'), 'İşlem: yeni islem tipi');
  assert.strictEqual(_gmIslemTipEtiket('ÜREME_KAYDI'), 'İşlem: üreme kaydi');
});

test('bilinmeyen tipte BUYUK_HARF kod kart başlığında ASLA görünmez (etiket fonksiyonu çıkışı)', () => {
  const t = _gmIslemTipEtiket('BILINMEYEN_TIPI');
  assert.ok(!/[A-Z_]/.test(t.replace('İşlem: ', '')), 'yedekte büyük harf/alt çizgi kalmamalı: ' + t);
  assert.strictEqual(_gmIslemTipEtiket(''), 'İşlem');
  assert.strictEqual(_gmIslemTipEtiket(null), 'İşlem');
  assert.strictEqual(_gmIslemTipEtiket(undefined), 'İşlem');
});

test('emoji yedeği: bilinmeyen tip → 📋; boş/eksik → 📋', () => {
  assert.strictEqual(_gmIslemTipEmoji('YENI_ISLEM_TIPI'), '📋');
  assert.strictEqual(_gmIslemTipEmoji(''), '📋');
  assert.strictEqual(_gmIslemTipEmoji(null), '📋');
});
