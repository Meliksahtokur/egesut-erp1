// G-20260913-TARIH-SECICI F1 — saf tarih katmanı birim testleri (TESTING-01:
// saf fonksiyonlar node --test altında doğrudan require; DOM yok).
const test = require('node:test');
const assert = require('node:assert');
const {
  TARIH_AY_ADLARI, TARIH_GUN_ADLARI,
  tarihArtikYilMi, tarihAyGunSayisi, tarihGecerliMi, tarihIsoTr,
  tarihParse, tarihAraliktaMi, tarihAyIzgara, tarihYilKaydir
} = require('../../js/tarih/tarih.js');

// ── VERİ ──

test('TARIH_AY_ADLARI: 12 ay, Ocak ile Aralık', () => {
  assert.strictEqual(TARIH_AY_ADLARI.length, 12);
  assert.strictEqual(TARIH_AY_ADLARI[0], 'Ocak');
  assert.strictEqual(TARIH_AY_ADLARI[11], 'Aralık');
});

test('TARIH_GUN_ADLARI: Pazartesi-önce 7 gün', () => {
  assert.deepStrictEqual(TARIH_GUN_ADLARI, ['Pt','Sa','Ca','Pe','Cu','Ct','Pz']);
});

// ── ARTIK YIL / AY GÜN SAYISI ──

test('tarihArtikYilMi: Gregorjen kuralı — 400/100/4', () => {
  assert.strictEqual(tarihArtikYilMi(2000), true);   // ÷400
  assert.strictEqual(tarihArtikYilMi(1900), false);  // ÷100 ama ÷400 değil
  assert.strictEqual(tarihArtikYilMi(2024), true);   // ÷4
  assert.strictEqual(tarihArtikYilMi(2026), false);
});

test('tarihAyGunSayisi: tablo + Şubat artık yılı', () => {
  assert.strictEqual(tarihAyGunSayisi(2026, 1), 31);
  assert.strictEqual(tarihAyGunSayisi(2026, 2), 28);
  assert.strictEqual(tarihAyGunSayisi(2024, 2), 29);
  assert.strictEqual(tarihAyGunSayisi(1900, 2), 28); // yüzyıl kuralı
  assert.strictEqual(tarihAyGunSayisi(2000, 2), 29); // 400 kuralı
  assert.strictEqual(tarihAyGunSayisi(2026, 4), 30);
  assert.strictEqual(tarihAyGunSayisi(2026, 12), 31);
  assert.strictEqual(tarihAyGunSayisi(2026, 0), 0);
  assert.strictEqual(tarihAyGunSayisi(2026, 13), 0);
});

// ── GEÇERLİLİK / GÖSTERİM ──

test('tarihGecerliMi: biçim kısa/esnek KABUL EDİLMEZ', () => {
  assert.strictEqual(tarihGecerliMi('2026-02-05'), true);
  assert.strictEqual(tarihGecerliMi('2026-2-05'), false);   // 1 haneli ay
  assert.strictEqual(tarihGecerliMi('2026-2-5'), false);
  assert.strictEqual(tarihGecerliMi('26-02-05'), false);    // kısa yıl
  assert.strictEqual(tarihGecerliMi('2026/02/05'), false);  // yanlış ayraç
  assert.strictEqual(tarihGecerliMi(''), false);
  assert.strictEqual(tarihGecerliMi(null), false);
  assert.strictEqual(tarihGecerliMi('garbage'), false);
});

test('tarihGecerliMi: gerçek takvim tarihi — 31.02 YOK, 29.02 artık yılda VAR', () => {
  assert.strictEqual(tarihGecerliMi('2026-02-31'), false);
  assert.strictEqual(tarihGecerliMi('2026-02-29'), false);  // 2026 artık değil
  assert.strictEqual(tarihGecerliMi('2024-02-29'), true);   // artık yıl
  assert.strictEqual(tarihGecerliMi('2026-04-31'), false);  // Nisan 30 çeker
  assert.strictEqual(tarihGecerliMi('2026-04-30'), true);
  assert.strictEqual(tarihGecerliMi('2026-13-01'), false);
  assert.strictEqual(tarihGecerliMi('2026-00-10'), false);
  assert.strictEqual(tarihGecerliMi('2026-01-00'), false);
});

test('tarihGecerliMi/tarihParse: yıl 1..9999 — 0000 red (ızgara temsilsiz ay çökmesine yol açamaz)', () => {
  assert.strictEqual(tarihGecerliMi('0000-01-01'), false);
  assert.strictEqual(tarihGecerliMi('0001-01-01'), true);
  assert.strictEqual(tarihGecerliMi('9999-12-31'), true);
  const r = tarihParse('05.02.0000');
  assert.strictEqual(r.ok, false);
  assert.match(r.error, /Yıl 1-9999/);
  assert.strictEqual(tarihParse('05.02.9999').ok, true);
});

test('tarihIsoTr: ISO → gg.aa.yyyy; geçersiz → boş (bugün fallback yok)', () => {
  assert.strictEqual(tarihIsoTr('2026-02-05'), '05.02.2026');
  assert.strictEqual(tarihIsoTr('2024-02-29'), '29.02.2024');
  assert.strictEqual(tarihIsoTr('31.02.2026'), '');
  assert.strictEqual(tarihIsoTr(''), '');
  assert.strictEqual(tarihIsoTr(null), '');
});

// ── EL GİRİŞİ ÇÖZÜMLEYİCİ ──

test('tarihParse: üç ayraç da normalize edilir — mm/dd TUZAĞI: 05.02.2026 = 5 Şubat', () => {
  assert.deepStrictEqual(tarihParse('05.02.2026'), { ok:true, iso:'2026-02-05' });
  assert.deepStrictEqual(tarihParse('05/02/2026'), { ok:true, iso:'2026-02-05' });
  assert.deepStrictEqual(tarihParse('05-02-2026'), { ok:true, iso:'2026-02-05' });
});

test('tarihParse: 2 haneli yıl → 2000+yy', () => {
  assert.deepStrictEqual(tarihParse('05.02.26'), { ok:true, iso:'2026-02-05' });
  assert.deepStrictEqual(tarihParse('01.01.99'), { ok:true, iso:'2099-01-01' });
  assert.deepStrictEqual(tarihParse('31/12/00'), { ok:true, iso:'2000-12-31' });
});

test('tarihParse: tek haneli gün/ay anlaşılır (tek olası okuma)', () => {
  assert.deepStrictEqual(tarihParse('5.2.2026'), { ok:true, iso:'2026-02-05' });
  assert.deepStrictEqual(tarihParse('5-2-26'), { ok:true, iso:'2026-02-05' });
});

test('tarihParse: hayali tarihler SESSİZCE DÜZELTİLMEZ — açık hata döner', () => {
  for(const giris of ['31.02.2026', '29.02.2023', '30.02.2024', '32.01.2026',
                      '31.04.2026', '00.05.2026', '13.13.2026', '05.00.2026']){
    const r = tarihParse(giris);
    assert.strictEqual(r.ok, false, giris + ' kabul edilmiş olmamalıydı');
    assert.strictEqual(typeof r.error, 'string');
    assert.ok(r.error.length > 0, giris + ': hata mesajı boş');
    assert.ok(!('iso' in r) || r.iso === undefined, giris + ': hata yanında iso olmamalı');
  }
});

test('tarihParse: hata mesajı Türkçe ve somut — ay ve gün sınırı', () => {
  assert.match(tarihParse('05.13.2026').error, /1-12/);
  assert.match(tarihParse('05.13.2026').error, /girilen: 13/);
  assert.match(tarihParse('31.02.2026').error, /Şubat 2026 28 gün/);
  assert.match(tarihParse('29.02.2023').error, /Şubat 2023 28 gün/);
});

test('tarihParse: biçim dışı girişler — çöp, yıl-önce, karışık ayraç, artık', () => {
  for(const giris of ['abc', '', '   ', null, undefined, '2026.02.05',
                      '05.02.2026x', 'x05.02.2026', '05/02.2026', '05.02',
                      '05..02.2026', '5 2 2026', '05.02.20266', '5,2,2026']){
    const r = tarihParse(giris);
    assert.strictEqual(r.ok, false, JSON.stringify(giris) + ' kabul edilmiş olmamalıydı');
    assert.ok(String(r.error).length > 0);
  }
});

test('tarihParse: 2 haneli yıl girişinde hayali gün yine red — yıl 2000+yy ile hesap', () => {
  // 29.02.26 → 2026 artık DEĞİL → red; 29.02.24 → 2024 artık → kabul
  assert.strictEqual(tarihParse('29.02.26').ok, false);
  assert.deepStrictEqual(tarihParse('29.02.24'), { ok:true, iso:'2024-02-29' });
});

// ── MIN/MAX ARALIK ──

test('tarihAraliktaMi: içeride ve sınırda (dahil) kabul', () => {
  assert.deepStrictEqual(tarihAraliktaMi('2026-05-10', '2026-01-01', '2026-12-31'), { ok:true, error:null });
  assert.deepStrictEqual(tarihAraliktaMi('2026-01-01', '2026-01-01', '2026-12-31'), { ok:true, error:null });
  assert.deepStrictEqual(tarihAraliktaMi('2026-12-31', '2026-01-01', '2026-12-31'), { ok:true, error:null });
});

test('tarihAraliktaMi: min altı ve max üstü — hata mesajı sınırı gg.aa.yyyy gösterir', () => {
  const alt = tarihAraliktaMi('2025-12-31', '2026-01-01', '2026-12-31');
  assert.strictEqual(alt.ok, false);
  assert.match(alt.error, /01\.01\.2026/);
  const ust = tarihAraliktaMi('2027-01-01', '2026-01-01', '2026-12-31');
  assert.strictEqual(ust.ok, false);
  assert.match(ust.error, /31\.12\.2026/);
});

test('tarihAraliktaMi: tek taraflı sınır — null/boş sınır yok sayılır', () => {
  assert.deepStrictEqual(tarihAraliktaMi('2020-01-01', null, '2026-12-31'), { ok:true, error:null });
  assert.deepStrictEqual(tarihAraliktaMi('2030-01-01', '2026-01-01', ''), { ok:true, error:null });
  assert.strictEqual(tarihAraliktaMi('2030-01-01', null, '2026-12-31').ok, false);
});

test('tarihAraliktaMi: geçersiz iso → ok:false', () => {
  assert.strictEqual(tarihAraliktaMi('31.02.2026', null, null).ok, false);
  assert.strictEqual(tarihAraliktaMi('', '2026-01-01', null).ok, false);
});

// ── YIL SEÇİM MATEMATİĞİ ──

test('tarihYilKaydir: ileri/geri ve sınırlarda kelepir', () => {
  assert.strictEqual(tarihYilKaydir(2026, -1), 2025);
  assert.strictEqual(tarihYilKaydir(2026, 1), 2027);
  assert.strictEqual(tarihYilKaydir(2026, -30), 1996);
  assert.strictEqual(tarihYilKaydir(1, -5), 1);        // alt kelepir
  assert.strictEqual(tarihYilKaydir(9999, 5), 9999);   // üst kelepir
  assert.strictEqual(tarihYilKaydir(2026, 1.9), 2027); // tam sayıya iner
  assert.strictEqual(tarihYilKaydir(2026, '3'), 2029); // sayı dizgesi
  assert.strictEqual(tarihYilKaydir(2026, 'x'), 2026); // sayı değil → 0 adım
});

// ── AY IZGARASI ÇEKİRDEĞİ ──

test('tarihAyIzgara: Ocak 2021 Cuma başlar — 4 önde null, 5 tam hafta', () => {
  const g = tarihAyIzgara(2021, 1);
  assert.strictEqual(g.yil, 2021); assert.strictEqual(g.ay, 1);
  assert.strictEqual(g.hucreler.length, 35);
  assert.strictEqual(g.hucreler[0], null);
  assert.strictEqual(g.hucreler[3], null);
  assert.deepStrictEqual(g.hucreler[4], { iso:'2021-01-01', gun:1, ayIci:true }); // Cuma
  assert.strictEqual(g.hucreler[34].iso, '2021-01-31'); // Pazar kapanış
  // Hafta içi dizilimi: ilk satır null,null,null,null,1,2,3 (Cu,Ct,Pz)
  assert.deepStrictEqual(g.hucreler.slice(0, 7),
    [null, null, null, null, g.hucreler[4], g.hucreler[5], g.hucreler[6]]);
  assert.strictEqual(g.hucreler[6].iso, '2021-01-03');
});

test('tarihAyIzgara: Ocak 2024 Pazartesi başlar — sıfır önde null, kuyruk tam hafta', () => {
  const g = tarihAyIzgara(2024, 1);
  assert.strictEqual(g.hucreler.length, 35);
  assert.deepStrictEqual(g.hucreler[0], { iso:'2024-01-01', gun:1, ayIci:true });
  assert.strictEqual(g.hucreler[30].iso, '2024-01-31');
  for(let i = 31; i < 35; i++) assert.strictEqual(g.hucreler[i], null);
});

test('tarihAyIzgara: Şubat 2024 artık yıl — 29 gün, Perşembe başlangıç', () => {
  const g = tarihAyIzgara(2024, 2);
  assert.strictEqual(g.hucreler.length, 35);
  assert.strictEqual(g.hucreler[0], null);              // Pt Sa Ca boş
  assert.strictEqual(g.hucreler[2], null);
  assert.deepStrictEqual(g.hucreler[3], { iso:'2024-02-01', gun:1, ayIci:true }); // Perşembe
  assert.strictEqual(g.hucreler[31].iso, '2024-02-29'); // artık gün içeride
  for(let i = 32; i < 35; i++) assert.strictEqual(g.hucreler[i], null);
});

test('tarihAyIzgara: yıl sınırı — Aralık 2020 sonu ve Ocak 2021 başı doğru ISO', () => {
  const ara = tarihAyIzgara(2020, 12);
  const sonu = ara.hucreler.filter(c => c).pop();
  assert.strictEqual(sonu.iso, '2020-12-31');
  const bas = tarihAyIzgara(2021, 1);
  const basi = bas.hucreler.filter(c => c)[0];
  assert.strictEqual(basi.iso, '2021-01-01');
  // Aralık 2021: 1'i Çarşamba, 31'i Cuma — yıl sonuna doğru hafta konumu
  const ar21 = tarihAyIzgara(2021, 12);
  assert.deepStrictEqual(ar21.hucreler[2], { iso:'2021-12-01', gun:1, ayIci:true }); // Çarşamba
  const ar21sonu = ar21.hucreler.filter(c => c).pop();
  assert.strictEqual(ar21sonu.iso, '2021-12-31');
});

test('tarihAyIzgara: hücre sözleşmesi — null dışı her hücre ayIci:true, iso/gun tutarlı', () => {
  for(const [yil, ay] of [[2021, 1], [2024, 2], [2026, 9], [2000, 2]]){
    const g = tarihAyIzgara(yil, ay);
    assert.strictEqual(g.hucreler.length % 7, 0, yil + '-' + ay + ' tam hafta değil');
    let oncekiGun = 0;
    for(const c of g.hucreler){
      if(c === null) continue;
      assert.strictEqual(c.ayIci, true);
      assert.match(c.iso, /^\d{4}-\d{2}-\d{2}$/);
      assert.ok(c.iso.startsWith(yil + '-' + String(ay).padStart(2, '0') + '-'), 'ay-dışı hücre sızdı: ' + c.iso);
      assert.strictEqual(c.gun, oncekiGun + 1, 'gün sırası bozuldu');
      assert.strictEqual(c.gun, Number(c.iso.slice(8, 10)), 'gun ↔ iso tutarsız');
      oncekiGun = c.gun;
    }
    assert.strictEqual(oncekiGun, tarihAyGunSayisi(yil, ay), 'son gün eksik');
  }
});

test('tarihAyIzgara: 1970 ÖNCESİ hafta hizalaması — negatif modulo kayması kilitlenir', () => {
  // 1 Haziran 1950 Perşembe → lead 3 (Pt Sa Ca boş); JS % işaret korur —
  // 27/27 yeşil iken gün-1'in hep Pt'ye düştüğü sistematik kaymanın gözü.
  const g50 = tarihAyIzgara(1950, 6);
  assert.strictEqual(g50.hucreler[0], null);
  assert.strictEqual(g50.hucreler[2], null);
  assert.deepStrictEqual(g50.hucreler[3], { iso:'1950-06-01', gun:1, ayIci:true }); // Perşembe
  assert.strictEqual(g50.hucreler[4].iso, '1950-06-02'); // Cuma
  // 1 Ocak 1900 Pazartesi → lead 0
  const g00 = tarihAyIzgara(1900, 1);
  assert.deepStrictEqual(g00.hucreler[0], { iso:'1900-01-01', gun:1, ayIci:true });
  // 1 Mayıs 1261 (proleptik Gregoryen) Pazar → lead 6 — derin geçmişte
  // negatif modulo sarması
  const gOrta = tarihAyIzgara(1261, 5);
  assert.strictEqual(gOrta.hucreler[5], null);
  assert.deepStrictEqual(gOrta.hucreler[6], { iso:'1261-05-01', gun:1, ayIci:true });
});

test('tarihAyIzgara: geçersiz girdi → null (sessiz uydurma yok)', () => {
  assert.strictEqual(tarihAyIzgara(2026, 0), null);
  assert.strictEqual(tarihAyIzgara(2026, 13), null);
  assert.strictEqual(tarihAyIzgara(0, 1), null);
  assert.strictEqual(tarihAyIzgara(10000, 1), null);
  assert.strictEqual(tarihAyIzgara(2026.5, 1), null);
  assert.strictEqual(tarihAyIzgara(2026, '3'), null);
});

// ── YEREL-BAĞIMSIZLIK MUHAFIZI (statik) ──

test('saf katman yerel API kullanmaz — toLocale*/new Date/Intl/DOM yasağı', () => {
  const fs = require('node:fs');
  const ham = fs.readFileSync(require.resolve('../../js/tarih/tarih.js'), 'utf8');
  // TÜM kontroller aynı yorum-soyulmuş kaynağa bakar — muhafız metne değil
  // içeriğe takılır (başlık yorumundaki örnekler yanlış kırmızı veremez).
  const src = ham.replace(/\/\/[^\n]*/g, '');
  assert.ok(!/toLocale\w*\s*\(/.test(src), 'toLocale* kullanımı yasak');
  assert.ok(!/new\s+Date\s*\(/.test(src), 'new Date kullanımı yasak');
  assert.ok(!/Intl\s*\./.test(src), 'Intl kullanımı yasak');
  assert.ok(!/\bdocument\b|\bwindow\b/.test(src), 'saf katmanda DOM yok');
});
