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

// ═══ F1 CARRY-OVER (F3, G-20260913) — kapaliGun/temizlenebilir DOM davranışı ═══
// Kanonik bileşenin (js/ui.js tekTarihTakvim*) kapalı-gün + temizleme UI
// sözleşmesinin otomatik kilidi — F1 tesliminde duman-testiyle doğrulanmış,
// kalıcı testi yoktu. Yöntem: TESTING-01 loadBrowserModule vm-sandbox'ı
// (gerçek tarih.js saf katmanı extra olarak enjekte edilir; Playwright
// yerine seçildi — ünite hattında kalır, demo-DB bağımsız).
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

function tekTakvimSandboxi(kapaliGun, opts = {}) {
  const doc = makeDomStub();
  const toasts = [];
  const onSecSecimleri = [];
  const { sandbox } = loadBrowserModule('js/ui.js', {
    dom: doc,
    extra: {
      bugun: () => '2026-09-13',
      toast: (m, isErr) => toasts.push({ m: String(m), isErr: !!isErr }),
      esc: (s) => String(s || ''),
      escAttr: (s) => String(s || ''),
      fmtTarih: (iso) => { if (!iso) return '—'; const p = String(iso).slice(0, 10).split('-'); return p.length === 3 ? p[2] + '.' + p[1] + '.' + p[0] : iso; },
      tarihAyIzgara, TARIH_AY_ADLARI, TARIH_GUN_ADLARI,
      tarihGecerliMi, tarihParse, tarihAraliktaMi, tarihIsoTr, tarihYilKaydir,
    },
  });
  // appendChild'lanan kutuyu getElementById köprüsüyle bul (W20 testköprüsü deseni).
  const origGet = doc.getElementById.bind(doc);
  doc.getElementById = (id) => origGet(id) || doc.body.children.find(c => c.id === id) || null;
  sandbox.__toasts = toasts;
  sandbox.__onSecSecimleri = onSecSecimleri; // canlı dizi — iddialar bunu okur
  sandbox.__onSec = (iso) => onSecSecimleri.push(iso);
  sandbox.__ac = () => sandbox.tekTarihTakvimAc({
    baslik: '📅 Test',
    deger: opts.deger !== undefined ? opts.deger : '2026-09-15',
    min: opts.min || null,
    max: opts.max || null,
    temizlenebilir: opts.temizlenebilir === true,
    kapaliGun: kapaliGun || null,
    onSec: sandbox.__onSec,
  });
  return sandbox;
}

const TIK = (fn, iso) => fn + '(&#39;' + iso + '&#39;)';

test('DOM kapaliGun: kapalı hücreler onclick\'siz + not-allowed çizilir, açık hücreler tıklanabilir', () => {
  const sb = tekTakvimSandboxi(iso => iso === '2026-09-13' || iso === '2026-09-20');
  sb.__ac();
  const kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu, 'kutu açılır');
  assert.ok(!kutu.innerHTML.includes(TIK('tekTarihTakvimSec', '2026-09-13')), 'kapalı gün 13 onclick taşımaz');
  assert.ok(!kutu.innerHTML.includes(TIK('tekTarihTakvimSec', '2026-09-20')), 'kapalı gün 20 onclick taşımaz');
  assert.ok(kutu.innerHTML.includes('not-allowed'), 'kapalı hücre imleci not-allowed');
  assert.ok(kutu.innerHTML.includes(TIK('tekTarihTakvimSec', '2026-09-15')), 'açık gün tıklanabilir çizilir');
});

test('DOM kapaliGun: kapalı hücreye tık (doğrudan çağrı) seçimi DEĞİŞTİRMEZ — derinlik savunması', () => {
  const sb = tekTakvimSandboxi(iso => iso === '2026-09-13');
  sb.__ac();
  sb.tekTarihTakvimSec('2026-09-13');
  const kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu.innerHTML.includes('Seçilen: 15.09.2026'), 'seçim değişmedi');
  assert.strictEqual(sb.__onSecSecimleri?.length || 0, 0, 'onSec hiç çağrılmadı');
});

test('DOM kapaliGun: kapalı seçimle Onayla REDDEDER — onSec\'e ulaşmaz, kutu açık kalır, hata satır içi', () => {
  // Açılış değeri BİREBİR kapalı gün: Onayla yolu kapalı-gün kontrolüne girer.
  const sb = tekTakvimSandboxi(iso => iso === '2026-09-20', { deger: '2026-09-20' });
  sb.__ac();
  sb.tekTarihTakvimOnayla();
  const kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu, 'Onayla kutuyu kapatmadı');
  assert.ok(kutu.innerHTML.includes('Seçili gün kapalı — başka bir gün seçin'), 'satır içi hata');
  assert.strictEqual(sb.__onSecSecimleri.length, 0, 'onSec REDDİ onaylamadı');
  // Açık güne geçişten sonra Onayla normal akışa döner.
  sb.tekTarihTakvimSec('2026-09-18');
  sb.tekTarihTakvimOnayla();
  assert.deepStrictEqual(sb.__onSecSecimleri, ['2026-09-18'], 'geçerli seçim onSec\'e gitti');
  assert.strictEqual(sb.document.getElementById('tek-tarih-takvim'), null, 'kutu kapandı');
});

test('DOM kapaliGun: kapalı gün EL GİRİŞİYLE de seçilemez (Uygula → satır içi hata, seçim değişmez)', () => {
  const sb = tekTakvimSandboxi(iso => iso === '2026-09-13');
  // Stub DOM innerHTML'i parse etmez — giriş alanını el ile kaydet (render
  // listener'ı bu el üzerinde çalışır, Uygula değerini buradan okur).
  const inp = sb.document.__setEl('tek-tarih-giris', makeElement('input'));
  sb.__ac();
  inp.value = '13.09.2026';
  sb.tekTarihTakvimGirisUygula();
  const kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu.innerHTML.includes('Seçili gün kapalı — başka bir gün seçin'), 'kapalı-gün el girişi reddi');
  assert.ok(kutu.innerHTML.includes('Seçilen: 15.09.2026'), 'seçim değişmedi');
  assert.ok(kutu.innerHTML.includes('value="13.09.2026"'), 'yazdığı korunur (sessiz düzeltme yok)');
});

test('DOM temizlenebilir: Temizle butonu çizilir; Temizle → Onayla onSec(null) verir', () => {
  const sb = tekTakvimSandboxi(null, { temizlenebilir: true });
  sb.__ac();
  let kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu.innerHTML.includes('tekTarihTakvimTemizle()'), 'Temizle butonu var');
  sb.tekTarihTakvimTemizle();
  kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu.innerHTML.includes('Seçilen: —'), 'seçim boşaldı');
  sb.tekTarihTakvimOnayla();
  assert.deepStrictEqual(sb.__onSecSecimleri, [null], 'onSec(null) — temizleme sözleşmesi');
  assert.strictEqual(sb.document.getElementById('tek-tarih-takvim'), null, 'kutu kapandı');
});

test('DOM temizlenebilir: false ise Temizle butonu HİÇ çizilmez (eski W20 yüzeyi gibi)', () => {
  const sb = tekTakvimSandboxi(null, { temizlenebilir: false });
  sb.__ac();
  const kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(!kutu.innerHTML.includes('tekTarihTakvimTemizle()'), 'Temizle yok');
  assert.ok(!kutu.innerHTML.includes('Temizle'), 'Temizle etiketi de yok');
});

test('DOM kapaliGun plumbing: tarihAlaniTakvimAc şemadaki kapaliGun fonksiyonunu bileşene iletir (F2 carry-over)', () => {
  const sb = tekTakvimSandboxi(null); // __ac kullanılmaz — bağlama katmanı doğrudan sürülür
  const el = sb.document.__setEl('plumbing-tarih', makeElement('input'));
  sb.tarihAlaniTakvimAc(el, { kapaliGun: iso => iso === '2026-09-20' });
  let kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu, 'bağlama katmanı kanonik bileşeni açar');
  assert.ok(!kutu.innerHTML.includes(TIK('tekTarihTakvimSec', '2026-09-20')), 'kapaliGun fonksiyonu iletildi — 20 kapalı çizilir');
  assert.ok(kutu.innerHTML.includes(TIK('tekTarihTakvimSec', '2026-09-15')), '15 açık çizilir');
  // Fonksiyon olmayan kapaliGun → null (sözleşme: yalnız fonksiyon iletilir,
  // şemaya yanlış yazılan değer kapalı-gün katmanını sessizce devre dışı bırakır)
  sb.tekTarihTakvimKapat();
  sb.tarihAlaniTakvimAc(el, { kapaliGun: 'gecersiz-kural' });
  kutu = sb.document.getElementById('tek-tarih-takvim');
  assert.ok(kutu.innerHTML.includes(TIK('tekTarihTakvimSec', '2026-09-20')), 'fonksiyon olmayan kapaliGun → kapalı hücre yok');
});

// ═══ F4 — STANDART KİLİDİ (G-20260913-TARIH-SECICI) ═══
// Kanonik tarih seçimi artık tek yol: yeni type="date" girişi YASAK, kanonik
// dışı takvim kopyası YENİDEN DOĞAMAZ, saf katman saflığı block-comment'i de
// soyarak korunur. Bu bölüm F1/F2/F3 denetim bulgularını kalıcı olarak
// kilitler (block-comment + Date.now + kopya sembol pinleri).

// Yorum soyucu: block (/* */) + satır (//) — F1 denetim bulgusu: yalnız
// satır yorumu soyan muhafız, /* */ arkasına gizlenen ihlali kaçırmıştı.
function muhafizKaynagi(ham) {
  return ham
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\/\/[^\n]*/g, '');
}

function jsDosyalari(fs, path, kok) {
  // js/ altını ÖZYİNELEMELİ tarar (luna BULGU-8: düz çocuk taraması alt
  // dizindeki girişleri kaçırıyordu)
  const bul = [];
  const gez = (goreceli) => {
    const mutlak = path.join(kok, goreceli);
    for (const d of fs.readdirSync(mutlak, { withFileTypes: true })) {
      const yol = goreceli + '/' + d.name;
      if (d.isDirectory()) gez(yol);
      else if (d.name.endsWith('.js')) bul.push(yol);
    }
  };
  gez('js');
  return bul;
}

test('F4 muhafızı — index.html + js/ (özyinelemeli) içinde type="date" girişi YASAK', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const kok = path.join(__dirname, '..', '..');
  const dosyalar = ['index.html', ...jsDosyalari(fs, path, kok)];
  const ihlaller = [];
  for (const d of dosyalar) {
    const src = muhafizKaynagi(fs.readFileSync(path.join(kok, d), 'utf8'));
    // HTML attribute deseni (çift VE tek tırnak) yasak — görünür + gizli her
    // şey. JS property ataması (.type = 'date') DEĞİL — o, gizli taşıyıcının
    // bilinçli istisnasıdır (bir sonraki test tek noktaya pinler).
    if (/(?<!\.)\btype\s*=\s*["']date["']/.test(src)) ihlaller.push(d);
  }
  assert.deepStrictEqual(ihlaller, [], 'native date girişi geri gelmez');
});

test('F4 muhafızı — gizli taşıyıcı runtime ataması tüm js/ içinde bilinçli TEK noktada kalır', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const kok = path.join(__dirname, '..', '..');
  // js/utils/modal.js:15 openM auto-fill kancası, runtime .type="date"
  // atamasıyla çalışır (F2 tasarım kararı). İstisna TÜM js/ ağacında toplam
  // 1 kez olabilir (luna BULGU-8: başka dosyada ikinci atama kaçmıştı) —
  // ikinci atama yeni native-surface demektir.
  const atamalar = jsDosyalari(fs, path, kok).reduce((toplam, d) => {
    const src = muhafizKaynagi(fs.readFileSync(path.join(kok, d), 'utf8'));
    return toplam + (src.match(/\.type\s*=\s*["']date["']/g) || []).length;
  }, 0);
  assert.strictEqual(atamalar, 1, 'gizli taşıyıcı .type="date" ataması tüm js/ içinde yalnız 1 yerde olabilir, bulunan: ' + atamalar);
});

test('F4 muhafızı — takvim-semantikli YENİ fonksiyon adı beyaz liste dışına çıkamaz', () => {
  // luna BULGU-6: yeniden adlandırılmış kopya takvim renderer'ı isim
  // muhafızına takılmıyordu. Takvim/gün-seçim semantiği taşıyan her yeni
  // `function` adı bu beyaz listede olmak zorunda — liste F1-F3 teslim
  // sonundaki meşru yüzeydir; yeni yüzey bu testin listesine bilinçli
  // eklenir (review kanıtıyla), sessiz kopya gelmez.
  const fs = require('node:fs');
  const path = require('node:path');
  const kok = path.join(__dirname, '..', '..');
  const beyazListe = new Set([
    'bcTakvimAc', 'bcTakvimAyDegistir', 'bcTakvimAyGosterim', 'bcTakvimAyKaydir',
    'bcTakvimBaslikTarihi', 'bcTakvimChipEtiketi', 'bcTakvimdenGunler', 'bcTakvimKapat',
    'bcTakvimOnayla', 'bcTakvimRender', 'bcTakvimSecimEkle', 'bcTakvimToggle',
    'cdSablonTarihTakvimAc', 'cdtTakvimAc', 'tarihAlaniTakvimAc', 'tekTarihTakvimAc',
    'tekTarihTakvimAyDegistir', 'tekTarihTakvimGirisUygula', 'tekTarihTakvimKapat',
    'tekTarihTakvimOnayla', 'tekTarihTakvimRender', 'tekTarihTakvimSec',
    'tekTarihTakvimTemizle', 'tekTarihTakvimYilDegistir', 'caseGunModalRender',
    'bcTarihSeciciAc',
  ]);
  const yabancilar = [];
  for (const d of jsDosyalari(fs, path, kok)) {
    const src = muhafizKaynagi(fs.readFileSync(path.join(kok, d), 'utf8'));
    for (const m of src.matchAll(/function\s+([A-Za-z0-9_$]+)/g)) {
      if (/Takvim|GunSecim/i.test(m[1]) && !beyazListe.has(m[1])) yabancilar.push(d + ':' + m[1]);
    }
  }
  assert.deepStrictEqual(yabancilar, [], 'beyaz liste dışı takvim fonksiyonu = kopya adayı');
});

test('F4 muhafızı — saf katmanda Date.now dahil tüm tarih-saat API’leri yasak (block-comment soyulmuş)', () => {
  const fs = require('node:fs');
  const src = muhafizKaynagi(fs.readFileSync(require.resolve('../../js/tarih/tarih.js'), 'utf8'));
  assert.ok(!/toLocale\w*\s*\(/.test(src), 'toLocale* kullanımı yasak');
  assert.ok(!/new\s+Date\s*\(/.test(src), 'new Date kullanımı yasak');
  assert.ok(!/Date\.now\s*\(/.test(src), 'Date.now kullanımı yasak (şimdiki zaman determinizmi bozar)');
  assert.ok(!/Intl\s*\./.test(src), 'Intl kullanımı yasak');
  assert.ok(!/\bdocument\b|\bwindow\b/.test(src), 'saf katmanda DOM yok');
});

test('F4 muhafızı — kaldırılan takvim kopyaları yeniden doğamaz; çoklu yüzeyler ortak çekirdeği çağırır', () => {
  const fs = require('node:fs');
  const ui = muhafizKaynagi(fs.readFileSync(require.resolve('../../js/ui.js'), 'utf8'));
  const forms = muhafizKaynagi(fs.readFileSync(require.resolve('../../js/forms.js'), 'utf8'));
  // F3'te kaldırılan tek-seçim kopyası geri gelemez
  assert.ok(!/function\s+bcTarihTakvim\w*/.test(forms), 'bcTarihTakvim* sembolü kaldırıldı — geri gelmez');
  // Çoklu-seçim yüzeyleri ortak ızgara çekirdeğini çağırmalı (F3 birleşmesi pini)
  assert.ok((forms.match(/tarihAyIzgara\s*\(/g) || []).length >= 1, 'bcTakvim* ortak çekirdekte olmalı');
  assert.ok((ui.match(/tarihAyIzgara\s*\(/g) || []).length >= 2, 'tekTarihTakvimAc + caseGunModalRender ortak çekirdekte olmalı');
});
