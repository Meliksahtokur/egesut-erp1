'use strict';
// Değişiklikler saf katmanı — Türkçe tablo/alan etiketleri (G-20260913-SURUM-GECMISI kabul 4).
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule');

const { sandbox } = loadBrowserModule('js/degisiklikler/etiketler.js');
const { tabloEtiketi, alanEtiketi, islemEtiketi, tabloSecenekleri } = sandbox;

test('tabloEtiketi: bilinen iş tabloları Türkçe', () => {
  assert.strictEqual(tabloEtiketi('hayvanlar'), 'Hayvan');
  assert.strictEqual(tabloEtiketi('dogum'), 'Doğum');
  assert.strictEqual(tabloEtiketi('stok_hareket'), 'Stok hareketi');
  assert.strictEqual(tabloEtiketi('cases'), 'Vaka');
});

test('LUNA-2: kapsam (39 tablo) TAMAMI haritada — fallback kullanılmaz', () => {
  // Canlı DEMO trg_degisim_log attach listesi (2026-09-13, 39 tablo).
  const KAPSAM = ['cases','diseases','dogum','drug_administrations','drug_classes',
    'drug_products','drugs','gorev_log','grup_padok_eslem','hastalik_log',
    'hayvan_override','hayvanlar','hekimler','irk_esik','kizginlik_log','padoklar',
    'pedigree_meta','pedigree_nodes','pedigree_parentage','protokol_ayar',
    'protokol_dismiss','protokol_instance','sablon_hastalik_eslem','semen_catalog',
    'stok','stok_hareket','stok_kategorileri','tedavi','tedavi_sablonu',
    'tedavi_sablonu_kalem','tohumlama','treatment_day_uygulamalar','treatment_days',
    'uygulama_log','vaccination_log','vaccination_schedule','vaccine_diseases',
    'vaccine_protocol_steps','vaccines'];
  const insanlastir = (ad) => { const s = String(ad).replace(/_+/g, ' ').trim();
    return s.charAt(0) === 'i' ? 'İ' + s.slice(1) : s.charAt(0).toUpperCase() + s.slice(1); };
  // Üyelik testi insanlaştırma sezgisiyle değil, haritanın kendisiyle yapılır
  // (tedavi/tohumlama gibi tek-kelimelik Türkçe adlarda etiket == insanlaştırma
  //  olabilir — bu bir eksiklik değildir).
  const kodlar = new Set(tabloSecenekleri().map(x => x.kod));
  const eksik = KAPSAM.filter(t => !kodlar.has(t));
  const fallbackaDusen = KAPSAM.filter(t => tabloEtiketi(t) === insanlastir(t)
    && !['tedavi', 'tohumlama'].includes(t));
  assert.deepStrictEqual(eksik, [], `haritadan eksik tablolar: ${eksik.join(', ')}`);
  assert.deepStrictEqual(fallbackaDusen, [], `fallback'a düşen tablolar: ${fallbackaDusen.join(', ')}`);
});

test('LUNA-2: luna bulgusu alanları artık Türkçe', () => {
  assert.strictEqual(alanEtiketi('pedigree_nodes', 'display_name'), 'Görünen ad');
  assert.strictEqual(alanEtiketi('pedigree_parentage', 'source_ref'), 'Kaynak referansı');
  assert.strictEqual(alanEtiketi('semen_catalog', 'code'), 'Kod');
  assert.strictEqual(alanEtiketi('vaccination_schedule', 'target_type'), 'Hedef tipi');
  assert.strictEqual(alanEtiketi('vaccine_protocol_steps', 'label'), 'Etiket');
});

test('LUNA-2 tam süpürme: İngilizce-adlı ve diyakritik-hassas kolonlar Türkçe', () => {
  const CIFTLER = [
    ['drug_products', 'brand_name', 'Marka'],
    ['drug_products', 'std_dose', 'Standart doz'],
    ['drugs', 'default_route', 'Varsayılan rota'],
    ['pedigree_nodes', 'birth_date', 'Doğum tarihi'],
    ['pedigree_nodes', 'sex', 'Cinsiyet'],
    ['pedigree_parentage', 'confidence', 'Güven'],
    ['semen_catalog', 'supplier', 'Tedarikçi'],
    ['vaccines', 'is_mandatory', 'Zorunlu'],
    ['vaccines', 'repeat_interval_days', 'Tekrar aralığı (gün)'],
    ['dogum', 'buzagi_id', 'Buzağı kaydı'],
    ['irk_esik', 'suttten_kesme_gun', 'Sütten kesme günü'],
    ['protokol_ayar', 'deger', 'Değer'],
    ['hayvan_override', 'kupe_no', 'Küpe no'],
  ];
  for (const [tablo, alan, beklenen] of CIFTLER) {
    assert.strictEqual(alanEtiketi(tablo, alan), beklenen, `${tablo}.${alan}`);
  }
});

test('tabloEtiketi: bilinmeyen tablo insanlaştırılır, çökmez', () => {
  assert.strictEqual(tabloEtiketi('yeni_tablo_adi'), 'Yeni tablo adi');
  assert.strictEqual(tabloEtiketi('islem_x'), 'İslem x', 'Türkçe büyük İ');
  assert.strictEqual(tabloEtiketi(''), '—');
  assert.strictEqual(tabloEtiketi(null), '—');
  assert.strictEqual(tabloEtiketi('__proto__'), 'Proto', 'prototip anahtarı etiket sözlüğünden sızmaz');
});

test('alanEtiketi: tabloya özgü etiket ortak etiketi ezer', () => {
  assert.strictEqual(alanEtiketi('hayvanlar', 'kupe_no'), 'Küpe no');
  assert.strictEqual(alanEtiketi('hayvanlar', 'devlet_kupe'), 'Devlet küpesi');
  assert.strictEqual(alanEtiketi('dogum', 'tarih'), 'Doğum tarihi');
  assert.strictEqual(alanEtiketi('tohumlama', 'tarih'), 'Tohumlama tarihi');
  assert.strictEqual(alanEtiketi('kizginlik_log', 'tarih'), 'Tarih', 'özel yoksa ortak');
});

test('alanEtiketi: ortak alanlar tablo bağımsız', () => {
  assert.strictEqual(alanEtiketi('gorev_log', 'hayvan_id'), 'Hayvan');
  assert.strictEqual(alanEtiketi('cases', 'animal_id'), 'Hayvan');
  assert.strictEqual(alanEtiketi('bilinmeyen', 'created_at'), 'Oluşturulma');
  assert.strictEqual(alanEtiketi('stok', 'updated_at'), 'Güncellenme');
});

test('alanEtiketi: bilinmeyen alan insanlaştırılır; boş/tuhaf girdi çökmez', () => {
  assert.strictEqual(alanEtiketi('hayvanlar', 'yeni_kolon'), 'Yeni kolon');
  assert.strictEqual(alanEtiketi(undefined, undefined), '—');
  assert.strictEqual(alanEtiketi('hayvanlar', 'constructor'), 'Constructor');
  assert.strictEqual(alanEtiketi('toString', 'id'), 'Kayıt no');
});

test('islemEtiketi: I/U/D Türkçe, bilinmeyen kod aynen', () => {
  assert.strictEqual(islemEtiketi('I'), 'Ekleme');
  assert.strictEqual(islemEtiketi('U'), 'Güncelleme');
  assert.strictEqual(islemEtiketi('D'), 'Silme');
  assert.strictEqual(islemEtiketi('X'), 'X');
  assert.strictEqual(islemEtiketi(null), '—');
});

test('tabloSecenekleri: tekil kodlar, Türkçe alfabetik sıra', () => {
  const s = JSON.parse(JSON.stringify(tabloSecenekleri()));
  const kodlar = s.map(x => x.kod);
  assert.strictEqual(new Set(kodlar).size, kodlar.length);
  assert.ok(kodlar.includes('hayvanlar') && kodlar.includes('stok_hareket'));
  const etiketler = s.map(x => x.etiket);
  const sirali = [...etiketler].sort((a, b) => a.localeCompare(b, 'tr'));
  assert.deepStrictEqual(etiketler, sirali);
});
