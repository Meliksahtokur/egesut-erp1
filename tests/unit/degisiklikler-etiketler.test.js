'use strict';
// Değişiklikler saf katmanı — Türkçe tablo/alan etiketleri (G-20260913-SURUM-GECMISI kabul 4).
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule');

const { sandbox } = loadBrowserModule('js/degisiklikler/etiketler.js');
const { tabloEtiketi, alanEtiketi, islemEtiketi, tabloSecenekleri, kapsamHaritalari } = sandbox;
const KAPSAM_KOLONLARI = require('./support/degisiklikler-kapsam-kolonlari.json');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');

// LUNA-3: canlı DEMO bağlantısı — ETIKET_LIVE_URL env'i kazanır; yoksa lead
// makinesi gelenegi olan ana-checkout .env'inden kur. Bilgi yoksa test
// ATLANIR (çevrimdışı unit koşumu bozulmaz).
function canliPsqlArgumanlari() {
  if (process.env.ETIKET_LIVE_URL) return [process.env.ETIKET_LIVE_URL];
  const envYolu = '/home/melik/egesut-erp1/.env';
  if (!fs.existsSync(envYolu)) return null;
  const env = {};
  for (const satir of fs.readFileSync(envYolu, 'utf8').split('\n')) {
    const m = satir.match(/^([A-Z_]+)=(.*)$/);
    if (m) env[m[1]] = m[2];
  }
  if (!env.SUPABASE_DEMO_REF || !env.SUPABASE_DEMO_DB_PASSWORD || !env.SUPABASE_DEMO_POOLER) return null;
  return [`postgresql://postgres.${env.SUPABASE_DEMO_REF}:${env.SUPABASE_DEMO_DB_PASSWORD}@${env.SUPABASE_DEMO_POOLER}:5432/postgres`];
}

const CANLI = canliPsqlArgumanlari();

test('tabloEtiketi: bilinen iş tabloları Türkçe', () => {
  assert.strictEqual(tabloEtiketi('hayvanlar'), 'Hayvan');
  assert.strictEqual(tabloEtiketi('dogum'), 'Doğum');
  assert.strictEqual(tabloEtiketi('stok_hareket'), 'Stok hareketi');
  assert.strictEqual(tabloEtiketi('cases'), 'Vaka');
});

test('LUNA-2/A3: canlı kapsam (39 tablo / 393 kolon) TAMAMI açık etiketli', () => {
  // Snapshot: canlı DEMO trg_degisim_log attach listesi + tüm kolonlar
  // (2026-09-13; üretim: psql information_schema sorgusu, kırıntıda).
  // YENİ KOLON EKLENDİĞİNDE: kolonu bu fixture'a ekle + etiketler.js'e Türkçe
  // girdi yaz — fixture'da olmayan kolon testi geçırir, o yüzden fixture'ı
  // şema değişiminde güncellemek mecburidir (kırılma noktası burası).
  const { tabloEtiketleri, ortakAlanlar, tabloOzelAlanlar } = kapsamHaritalari();
  const eksikTablo = [];
  const eksikKolon = [];
  for (const [tablo, kolonlar] of Object.entries(KAPSAM_KOLONLARI)) {
    if (tabloEtiketleri[tablo] === undefined) eksikTablo.push(tablo);
    for (const kolon of kolonlar) {
      const ozel = tabloOzelAlanlar[tablo] && tabloOzelAlanlar[tablo][kolon] !== undefined;
      const ortak = ortakAlanlar[kolon] !== undefined;
      if (!ozel && !ortak) eksikKolon.push(`${tablo}.${kolon}`);
    }
  }
  assert.deepStrictEqual(eksikTablo, [], `haritadan eksik tablolar: ${eksikTablo.join(', ')}`);
  assert.deepStrictEqual(eksikKolon, [], `açık etiketi olmayan kolonlar: ${eksikKolon.join(', ')}`);
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

test('LUNA-3: canlı DEMO information_schema ↔ harita (haritasız canlı kolon = KIRMIZI)', { skip: CANLI ? false : 'canlı DEMO bağlantı bilgisi yok — test atlanır' }, () => {
  const tabloListesi = Object.keys(KAPSAM_KOLONLARI).map(t => `'${t}'`).join(',');
  const sorgu = `SELECT DISTINCT c.relname||'.'||a.attname FROM pg_attribute a ` +
    `JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace ` +
    `WHERE n.nspname='public' AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped ` +
    `AND c.relname IN (${tabloListesi}) ORDER BY 1`;
  const cikti = execFileSync('psql', [CANLI[0], '-t', '-A', '-c', sorgu], { timeout: 60000 }).toString();
  const ciftler = cikti.trim().split('\n').filter(Boolean);
  assert.ok(ciftler.length > 0, 'canlı sorgu boş döndü — bağlantı/şema sorunu');
  const { tabloEtiketleri, ortakAlanlar, tabloOzelAlanlar } = kapsamHaritalari();
  const eksik = [];
  for (const satir of ciftler) {
    const nokta = satir.indexOf('.');
    const tablo = satir.slice(0, nokta);
    const kolon = satir.slice(nokta + 1);
    if (tabloEtiketleri[tablo] === undefined) { eksik.push(`${tablo} (tablo başlığı)`); continue; }
    const ozel = tabloOzelAlanlar[tablo] && tabloOzelAlanlar[tablo][kolon] !== undefined;
    if (!ozel && ortakAlanlar[kolon] === undefined) eksik.push(`${tablo}.${kolon}`);
  }
  assert.deepStrictEqual(eksik, [], `canlı DEMO'da haritasız kolon: ${eksik.join(', ')}`);
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
