const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { loadBrowserModule } = require('./support/loadModule.js');

// js/config.js tarayıcı-global modüldür (module.exports yok) — vm loader ile yüklenir,
// let/const sabitler expose ile dışarı çıkarılır. Modül yüklenirken DB'ye erişilmez:
// loadPadokConfig / loadHekimlerFromDB yalnız çağrılınca çalışır.
const { exposed } = loadBrowserModule('js/config.js', {
  expose: ['HEKIMLER', 'HASTALIK_LISTESI', 'HASTALIK_KAT', 'LOKASYON_KAT', 'SPERMA_LISTESI', 'GRUP_PADOK', 'VARSAYILAN_HEKIM'],
});
const { HEKIMLER, HASTALIK_LISTESI, HASTALIK_KAT, LOKASYON_KAT, SPERMA_LISTESI, GRUP_PADOK, VARSAYILAN_HEKIM } = exposed;

// ── HASTALIK_LISTESI ↔ HASTALIK_KAT bütünlüğü ───────────────────
test('HASTALIK_KAT: kategorilerdeki her hastalık HASTALIK_LISTESI içinde (yazım hatası yok)', () => {
  for (const [kat, list] of Object.entries(HASTALIK_KAT)) {
    for (const h of list) {
      assert.ok(
        HASTALIK_LISTESI.includes(h),
        `"${h}" (${kat}) HASTALIK_LISTESI içinde yok — yazım hatası olabilir`
      );
    }
  }
});

test('HASTALIK_KAT: listedeki her hastalık en az bir dolu kategoride yer alır (öksüz kayıt yok)', () => {
  const doluKategoriler = Object.values(HASTALIK_KAT).filter(l => l.length > 0);
  assert.ok(doluKategoriler.length > 0, 'en az bir dolu kategori olmalı');
  for (const h of HASTALIK_LISTESI) {
    assert.ok(
      doluKategoriler.some(l => l.includes(h)),
      `"${h}" hiçbir dolu kategoride görünmüyor — listede öksüz kayıt`
    );
  }
});

test('HASTALIK_LISTESI: tekrar eden kayıt yok', () => {
  assert.strictEqual(
    new Set(HASTALIK_LISTESI).size,
    HASTALIK_LISTESI.length,
    'HASTALIK_LISTESI içinde aynı hastalık iki kez listelenmiş'
  );
  for (const h of HASTALIK_LISTESI) {
    assert.ok(typeof h === 'string' && h.trim().length > 0, 'boş hastalık adı olmamalı');
  }
});

test('Bilinen çakışma: üç hastalık hem "Metabolik" hem "Sindirim" kategorisinde (ŞÜPHELİ DAVRANIŞ)', () => {
  // ŞÜPHELİ DAVRANIŞ: 'Ruminal Asidoz', 'Timpani', 'Şirden Deplasmanı' İKİ kategoride birden
  // listeleniyor. Bilinçli tasarım olabilir (klinik sınıflandırma belirsizliği) ancak kategori
  // bazlı filtreleme/istatistikte çift sayım riski taşır. Mevcut durum aynen assert edilir.
  const ortak = ['Ruminal Asidoz', 'Timpani', 'Şirden Deplasmanı'];
  for (const h of ortak) {
    assert.ok(HASTALIK_KAT['Metabolik'].includes(h), `"${h}" Metabolik içinde olmalı`);
    assert.ok(HASTALIK_KAT['Sindirim'].includes(h), `"${h}" Sindirim içinde olmalı`);
  }
  // çoklu kategoride görünen hastalık kümesi tam olarak bu üçlüdür
  const counts = new Map();
  for (const list of Object.values(HASTALIK_KAT)) {
    for (const h of list) counts.set(h, (counts.get(h) || 0) + 1);
  }
  const coklu = [...counts.entries()].filter(([, c]) => c > 1).map(([h]) => h).sort();
  assert.deepStrictEqual(coklu, [...ortak].sort());
});

// ── LOKASYON_KAT ────────────────────────────────────────────────
test('LOKASYON_KAT: anahtarlar tam olarak Meme, Ayak, Göz; "Göz" HASTALIK_KAT anahtarı DEĞİLDİR (ŞÜPHELİ DAVRANIŞ notu)', () => {
  // ŞÜPHELİ DAVRANIŞ notu: LOKASYON_KAT'te 'Göz' kategorisi var ama HASTALIK_KAT'te yok.
  // Göz konumlu bir hastalık kaydı kategori haritasında karşılıksız kalabilir
  // (UI'da hastalık kategorisi lokasyondan türetiliyorsa 'Göz' boşa düşer). Mevcut durum assert edilir.
  assert.deepStrictEqual(Object.keys(LOKASYON_KAT).sort(), ['Ayak', 'Göz', 'Meme']);
  assert.ok(!('Göz' in HASTALIK_KAT), '"Göz" HASTALIK_KAT anahtarı OLMAMALI (mevcut davranış)');
  // buna karşılık Meme ve Ayak iki haritada da ortaktır
  assert.ok('Meme' in HASTALIK_KAT, '"Meme" HASTALIK_KAT içinde olmalı');
  assert.ok('Ayak' in HASTALIK_KAT, '"Ayak" HASTALIK_KAT içinde olmalı');
});

test('LOKASYON_KAT: konum listelerinde tekrar eden eleman yok, içerik bilinen çeyrek/göz listeleri', () => {
  for (const [kat, list] of Object.entries(LOKASYON_KAT)) {
    assert.ok(Array.isArray(list) && list.length > 0, `${kat}: konum listesi boş olamaz`);
    assert.strictEqual(new Set(list).size, list.length, `${kat}: konum listesinde tekrar var`);
    for (const l of list) {
      assert.ok(typeof l === 'string' && l.trim().length > 0, `${kat}: boş konum adı`);
    }
  }
  const ceyrek = ['Sol Ön', 'Sol Arka', 'Sağ Ön', 'Sağ Arka'];
  // vm realm'inde yaratılan listeler — prototip farkı yüzünden loose deepEqual
  assert.deepEqual(LOKASYON_KAT['Meme'], ceyrek);
  assert.deepEqual(LOKASYON_KAT['Ayak'], ceyrek);
  assert.deepEqual(LOKASYON_KAT['Göz'], ['Sol Göz', 'Sağ Göz']);
});

// ── GRUP_PADOK ──────────────────────────────────────────────────
test('GRUP_PADOK: her değer boş olmayan, tekrarsız string dizisi; "Besi" tam 2 padoka eşlenir', () => {
  assert.ok(Object.keys(GRUP_PADOK).length > 0, 'GRUP_PADOK boş olamaz');
  for (const [grup, padoklar] of Object.entries(GRUP_PADOK)) {
    assert.ok(Array.isArray(padoklar), `${grup}: değer dizi olmalı`);
    assert.ok(padoklar.length > 0, `${grup}: padok listesi boş olamaz`);
    for (const p of padoklar) {
      assert.ok(typeof p === 'string' && p.trim().length > 0, `${grup}: boş padok adı`);
    }
    assert.strictEqual(new Set(padoklar).size, padoklar.length, `${grup}: tekrar eden padok`);
  }
  assert.strictEqual(GRUP_PADOK['Besi'].length, 2, '"Besi" tam 2 padoka eşlenmeli');
  assert.deepEqual(GRUP_PADOK['Besi'], ['Besi Padok (Erkek)', 'Besi Padok (Dişi)']);
});

test('GRUP_PADOK: property — rastgele bir grubun padok listesi boş, tekrarsız ve string dizisidir', () => {
  const gruplar = Object.keys(GRUP_PADOK);
  fc.assert(fc.property(fc.constantFrom(...gruplar), (g) => {
    const list = GRUP_PADOK[g];
    assert.ok(Array.isArray(list) && list.length > 0, `${g}: liste boş`);
    assert.strictEqual(new Set(list).size, list.length, `${g}: tekrar var`);
    for (const p of list) {
      assert.ok(typeof p === 'string' && p.length > 0, `${g}: boş padok adı`);
    }
  }));
});

// ── SPERMA_LISTESI ──────────────────────────────────────────────
test('SPERMA_LISTESI: tekrar eden kayıt yok, tüm elemanlar dolu string', () => {
  assert.ok(SPERMA_LISTESI.length > 0, 'SPERMA_LISTESI boş olamaz');
  assert.strictEqual(
    new Set(SPERMA_LISTESI).size,
    SPERMA_LISTESI.length,
    'SPERMA_LISTESI içinde aynı sperma iki kez listelenmiş'
  );
  for (const s of SPERMA_LISTESI) {
    assert.ok(typeof s === 'string' && s.trim().length > 0, 'boş sperma adı');
  }
});

// ── HEKIMLER / VARSAYILAN_HEKIM ─────────────────────────────────
test('HEKIMLER: id\'ler benzersiz, her kayıt dolu {id, ad} yapısında', () => {
  assert.ok(HEKIMLER.length > 0, 'HEKIMLER boş olamaz');
  const ids = HEKIMLER.map(h => h.id);
  assert.strictEqual(new Set(ids).size, ids.length, 'HEKIMLER içinde tekrar eden id var');
  for (const h of HEKIMLER) {
    assert.ok(typeof h.id === 'string' && h.id.length > 0, 'boş hekim id');
    assert.ok(typeof h.ad === 'string' && h.ad.trim().length > 0, 'boş hekim adı');
  }
});

test('VARSAYILAN_HEKIM: HEKIMLER id\'lerinden biridir', () => {
  assert.ok(
    HEKIMLER.some(h => h.id === VARSAYILAN_HEKIM),
    `VARSAYILAN_HEKIM="${VARSAYILAN_HEKIM}" HEKIMLER id'leri arasında yok`
  );
  assert.strictEqual(VARSAYILAN_HEKIM, 'H1');
});

// ── fast-check kapsama property'leri ────────────────────────────
test('HASTALIK_LISTESI: property — rastgele indeksteki hastalık her zaman en az bir kategoride kapsanır', () => {
  fc.assert(fc.property(fc.nat(HASTALIK_LISTESI.length - 1), (i) => {
    const h = HASTALIK_LISTESI[i];
    const kapsayan = Object.entries(HASTALIK_KAT).filter(([, l]) => l.includes(h));
    assert.ok(kapsayan.length >= 1, `"${h}" kapsayan kategori yok`);
  }));
});

test('HASTALIK_KAT: property — rastgele kategori/indeksteki hastalık her zaman HASTALIK_LISTESI üyesidir', () => {
  const ciftler = [];
  for (const [kat, list] of Object.entries(HASTALIK_KAT)) {
    for (let i = 0; i < list.length; i++) ciftler.push([kat, list[i]]);
  }
  assert.ok(ciftler.length > 0);
  fc.assert(fc.property(fc.nat(ciftler.length - 1), (idx) => {
    const [kat, h] = ciftler[idx];
    assert.ok(HASTALIK_LISTESI.includes(h), `${kat}/${h}: liste üyesi değil`);
  }));
});
