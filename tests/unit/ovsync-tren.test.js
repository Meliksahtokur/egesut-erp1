// tests/unit/ovsync-tren.test.js
// js/ovsync-tren.js — Ovsync treni saf HTML/karar yardımcıları (PLAN 2026-11-09 N3/UA1).
// Mockup kaynağı (G-MOCK onaylı): runs/2026-11-09-ovsync-tren/mockup/gen.js + _tren-yeni.css.
// Sözleşme: DOM/rpc'ye dokunan fonksiyonlar bağımlılıklarını argümanla alır; tarih hesabı
// yalnız parametre olarak gelen ISO günle (bugunIso) yapılır, sistem saatine bakılmaz (TZ).
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { loadBrowserModule } = require('./support/loadModule.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const gidilen = [];
const { sandbox: S } = loadBrowserModule('js/ovsync-tren.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror, goTo: (p) => gidilen.push(p) },
});

// HTML → görünen metin (etiketler atılır, boşluk sadeleşir, entity'ler çözülür)
const metin = (h) => String(h).replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<')
  .replace(/&gt;/g, '>').replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, ' ').trim();
// vm bağlamında üretilen dizi/nesneler başka realm'in prototipini taşır → karşılaştırmada normalize et
const jn = (x) => JSON.parse(JSON.stringify(x));

// ── Örnek veri (mockup README: 19 Kas treni = 36, 38, 169, 5708) ─────────────
const ONIZLEME = {
  ok: true, aktif: true, bugun: '2026-11-16', tren_gunu: '2026-11-19', tren_bugun_mu: false,
  uye_sayisi: 4, gorev: { id: 'g-212', hedef_tarih: '2026-11-19' },
  kupe_no: '212', kural_tarihi: '2026-11-17', uye_kupeler: ['36', '38', '169', '5708'],
};
const uye = (hayvan_id, kupe_no, asama, ek) => Object.assign({ hayvan_id, kupe_no, case_id: 'c-' + kupe_no, gorev_id: null, asama }, ek || {});
const TREN19 = { tren_gunu: '2026-11-19', ritim_disi: false,
  uyeler: [uye('h36', '36', 2), uye('h38', '38', 2), uye('h169', '169', 1), uye('h5708', '5708', 1)] };
const TREN26 = { tren_gunu: '2026-11-26', ritim_disi: false, uyeler: [uye('h212', '212', 0), uye('h418', '418', 0)] };
const TREN20_RD = { tren_gunu: '2026-11-20', ritim_disi: true, uyeler: [uye('h77', '77', 1)] };
const TREN_VERI = { ok: true, aktif: true, capa: '2026-11-12', bugun: '2026-11-26',
  trenler: [TREN26, TREN20_RD, TREN19], bagimsizlar: [uye('h1203', '1203', 1), uye('h88', '88', 2)], ileri_sayisi: 0 };

const PLAN_N1 = { tren: '2026-11-26', yeni_tren: '2026-11-27', ileri_gorevler: [], uyeler: [
  uye('h169', '169', 1, { sonuc: 'KAYAR', yeni_tarih: '2026-11-27' }),
  uye('h36', '36', 2, { sonuc: 'SECIM', yeni_tarih: null }),
  uye('h212', '212', 0, { sonuc: 'KAYAR', yeni_tarih: '2026-11-27' }),
] };
const PLAN_N2 = { tren: '2026-11-26', yeni_tren: '2026-11-28', ileri_gorevler: [], uyeler: [
  uye('h169', '169', 1, { sonuc: 'BASTAN', yeni_tarih: '2026-11-28' }),
  uye('h5708', '5708', 1, { sonuc: 'KAYAR', yeni_tarih: '2026-11-28' }),
  uye('h36', '36', 2, { sonuc: 'SECIM', yeni_tarih: null }),
] };

// ── ovsyncTrenAktif ──────────────────────────────────────────────────────────
test('trenAktif: iki bayrak 1 → true; biri 0/eksik → false', () => {
  const r = (a, b) => [{ anahtar: 'ovsync_tren_aktif', deger: a }, { anahtar: 'ovsync_pg_kurallari_aktif', deger: b }];
  assert.strictEqual(S.ovsyncTrenAktif(r(1, 1)), true);
  assert.strictEqual(S.ovsyncTrenAktif(r('1', '1')), true);
  assert.strictEqual(S.ovsyncTrenAktif(r(1, 0)), false);
  assert.strictEqual(S.ovsyncTrenAktif(r(0, 1)), false);
  assert.strictEqual(S.ovsyncTrenAktif([{ anahtar: 'ovsync_tren_aktif', deger: 1 }]), false);
  assert.strictEqual(S.ovsyncTrenAktif(null), false);
});

// ── K8 sorusu ────────────────────────────────────────────────────────────────
test('soru gerekli değil: tren bugün (R4); gerekli: tren ≠ bugün; kapalı → değil', () => {
  assert.strictEqual(S.ovsyncTrenSoruGerekli(ONIZLEME, '2026-11-19'), false);
  assert.strictEqual(S.ovsyncTrenSoruGerekli(ONIZLEME, '2026-11-16'), true);
  assert.strictEqual(S.ovsyncTrenSoruGerekli({ ok: true, aktif: false }, '2026-11-16'), false);
});

test('soru html: TREN ön seçili, iki düğme, mockup 1a metinleri', () => {
  const h = S.ovsyncTrenSoruHtml(ONIZLEME);
  const secimler = h.match(/data-secim="[A-Z]+"/g);
  assert.deepStrictEqual(secimler, ['data-secim="TREN"', 'data-secim="BAGIMSIZ"']);
  assert.match(h, /data-secim="TREN"[^>]*aria-checked="true"/);
  assert.match(h, /data-secim="BAGIMSIZ"[^>]*aria-checked="false"/);
  assert.match(h, /class="ovs-radyo on"/);
  const t = metin(h);
  assert.ok(t.includes('▶ Ovsync başlat — 212'), t);
  assert.ok(t.includes('Kural günü Sal 17 Kas · tren her Perşembe'), t);
  assert.ok(t.includes('🚆 Trene bin — Per 19 Kas (4 hayvan)'), t);
  assert.ok(t.includes('Bu trende: 36 · 38 · 169 · 5708.'), t);
  assert.ok(t.includes('(3 gün sonra)'), t);
  assert.ok(t.includes('Bağımsız başlat — bugün'), t);
  assert.ok(t.includes('Bugün Pzt 16 Kas başlar.'), t);
  assert.match(h, /data-ovt-aksiyon="VAZGEC"/);
  assert.match(h, /data-ovt-aksiyon="BASLAT"/);
});

test('soru html: küpe/sayı escape', () => {
  const h = S.ovsyncTrenSoruHtml(Object.assign({}, ONIZLEME, {
    kupe_no: '<b>x</b>', uye_sayisi: '<i>4</i>', uye_kupeler: ['<s>36</s>'] }));
  assert.ok(!h.includes('<b>x</b>'));
  assert.ok(!h.includes('<i>4</i>'));
  assert.ok(!h.includes('<s>36</s>'));
  assert.ok(h.includes('&lt;b&gt;x&lt;/b&gt;'));
});

test('ovsyncTrenSor offline: toast "İnternet yok", rpc çağrılmaz, null', async () => {
  const toasts = []; let rpcSay = 0; let modalSay = 0;
  const r = await S.ovsyncTrenSor({ hayvanId: 'h212', online: false,
    rpc: async () => { rpcSay++; return ONIZLEME; }, toast: (m) => toasts.push(m), acModal: async () => { modalSay++; return 'TREN'; } });
  assert.strictEqual(r, null);
  assert.strictEqual(rpcSay, 0);
  assert.strictEqual(modalSay, 0);
  assert.deepStrictEqual(toasts, ['İnternet yok']);
});

test('ovsyncTrenSor: bayrak kapalı → {TREN, null} (eski yol), modal yok', async () => {
  let modalSay = 0; const cagri = [];
  const r = await S.ovsyncTrenSor({ hayvanId: 'h212', online: true,
    rpc: async (ad, p) => { cagri.push([ad, p]); return { data: { ok: true, aktif: false }, error: null }; },
    toast: () => {}, acModal: async () => { modalSay++; return 'TREN'; } });
  assert.deepStrictEqual({ ...r }, { secim: 'TREN', tarih: null });
  assert.strictEqual(modalSay, 0);
  assert.deepStrictEqual(jn(cagri), [['ovsync_tren_onizle', { p_hayvan_id: 'h212' }]]);
  // yerel bayrak kapalı bilgisi → rpc hiç çağrılmaz (offline'da da eski yol)
  let rpcSay = 0;
  const r2 = await S.ovsyncTrenSor({ hayvanId: 'h212', online: false, aktif: false,
    rpc: async () => { rpcSay++; }, toast: () => {}, acModal: async () => 'TREN' });
  assert.deepStrictEqual({ ...r2 }, { secim: 'TREN', tarih: null });
  assert.strictEqual(rpcSay, 0);
});

test('ovsyncTrenSor: tren bugün → modal yok, TREN + bugün (R4)', async () => {
  let modalSay = 0;
  const on = Object.assign({}, ONIZLEME, { bugun: '2026-11-19', tren_bugun_mu: true });
  const r = await S.ovsyncTrenSor({ hayvanId: 'h212', online: true, rpc: async () => on,
    toast: () => {}, acModal: async () => { modalSay++; return 'BAGIMSIZ'; } });
  assert.deepStrictEqual({ ...r }, { secim: 'TREN', tarih: '2026-11-19' });
  assert.strictEqual(modalSay, 0);
});

test('ovsyncTrenSor: modal seçimi TREN/BAGIMSIZ/vazgeç', async () => {
  const sor = (cevap) => S.ovsyncTrenSor({ hayvanId: 'h212', online: true, rpc: async () => ONIZLEME,
    toast: () => {}, acModal: async (html) => { assert.match(html, /data-secim="TREN"/); return cevap; } });
  assert.deepStrictEqual({ ...(await sor('TREN')) }, { secim: 'TREN', tarih: '2026-11-19' });
  assert.deepStrictEqual({ ...(await sor('BAGIMSIZ')) }, { secim: 'BAGIMSIZ', tarih: '2026-11-16' });
  assert.strictEqual(await sor(null), null);
});

test('ovsyncTrenSor: rpc hatası → toast (hata metni), null; sessiz yok', async () => {
  const toasts = [];
  const r = await S.ovsyncTrenSor({ hayvanId: 'h212', online: true,
    rpc: async () => ({ data: null, error: { message: 'OVSYNC_TREN_AYAR:{"anahtar":"ovsync_tren_capa","deger":20261131,"sebep":"GECERSIZ_TARIH"}' } }),
    toast: (m) => toasts.push(m), acModal: async () => 'TREN' });
  assert.strictEqual(r, null);
  assert.strictEqual(toasts.length, 1);
  assert.match(toasts[0], /ayar/i);
  // aktif ama tren_gunu yok → hata toast'ı
  const t2 = [];
  const r2 = await S.ovsyncTrenSor({ hayvanId: 'h', online: true, rpc: async () => ({ ok: true, aktif: true, bugun: '2026-11-16' }),
    toast: (m) => t2.push(m), acModal: async () => 'TREN' });
  assert.strictEqual(r2, null);
  assert.strictEqual(t2.length, 1);
});

// ── Tren başlığı ─────────────────────────────────────────────────────────────
test('başlık: "Tren · Per 19 Kas · 4 hayvan · bugün: PG günü" + ertele düğmesi (X = bugün)', () => {
  const h = S.ovsyncTrenBaslikHtml(TREN19, '2026-11-26');
  assert.match(h, /class="ovs-tren-bas"/);
  const ad = h.match(/<span class="ovs-tren-ad">([\s\S]*?)<\/span><button|<span class="ovs-tren-ad">([\s\S]*)<\/span><\/div>/);
  assert.ok(ad, h);
  assert.strictEqual(metin(ad[1] || ad[2]), 'Tren · Per 19 Kas · 4 hayvan · bugün: PG günü');
  assert.match(h, /class="ovs-tren-bugun"/);
  assert.match(h, /<button class="ovs-tren-ertele" data-ovt-aksiyon="TOPTAN" data-tarih="2026-11-26"[^>]*>Tren gününü ertele…<\/button>/);
});

test('başlık: bugün iş yok → son parça yok; ertele hedefi sıradaki ritim günü', () => {
  const h = S.ovsyncTrenBaslikHtml(TREN19, '2026-11-22');
  assert.ok(metin(h).startsWith('Tren · Per 19 Kas · 4 hayvan'), metin(h));
  assert.ok(!metin(h).includes('bugün'), metin(h));
  assert.match(h, /data-tarih="2026-11-26"/);
  // başlangıç günü
  assert.ok(metin(S.ovsyncTrenBaslikHtml(TREN26, '2026-11-26')).includes('bugün: başlangıç günü'));
  // trenin işi bitti (D7 geçti) → toptan erteleme düğmesi yok
  assert.ok(!S.ovsyncTrenBaslikHtml(TREN19, '2026-11-28').includes('ovs-tren-ertele'));
});

test('başlık: ritim_disi → "ritim dışı" etiketi, ertele düğmesi yok, açıklama notu', () => {
  const h = S.ovsyncTrenBaslikHtml(TREN20_RD, '2026-11-26');
  const t = metin(h);
  assert.ok(t.startsWith('Tren · Cum 20 Kas · 1 hayvan · ritim dışı'), t);
  assert.match(h, /class="ovs-tren-ritimdisi">ritim dışı</);
  assert.ok(!h.includes('ovs-tren-ertele'));
  assert.match(h, /class="ovs-tren-not"/);
  assert.ok(t.includes('Toptan ertelemeye girmez; kendi satırından düzenlenir.'), t);
});

test('başlık: çevrimdışı → ertele düğmesi yok', () => {
  assert.ok(!S.ovsyncTrenBaslikHtml(TREN19, '2026-11-26', false).includes('ovs-tren-ertele'));
});

test('bugunIso UTC gece: "2026-11-12" parametresiyle başlık bugün PG günü (TZ)', () => {
  const tren = { tren_gunu: '2026-11-05', ritim_disi: false, uyeler: [uye('h1', '1', 1)] };
  const t = metin(S.ovsyncTrenBaslikHtml(tren, '2026-11-12'));
  assert.ok(t.startsWith('Tren · Per 5 Kas · 1 hayvan · bugün: PG günü'), t);
  // Sistem saat dilimi farklı süreçte de aynı sonuç (tarih aritmetiği yalnız UTC/ISO)
  const kod = `
    const { loadBrowserModule } = require(${JSON.stringify(path.join(__dirname, 'support/loadModule.js'))});
    const e = (s) => String(s ?? '');
    const { sandbox } = loadBrowserModule('js/ovsync-tren.js', { extra: { esc: e, escAttr: e } });
    process.stdout.write(sandbox.ovsyncTrenBaslikHtml(${JSON.stringify(tren)}, '2026-11-12').replace(/<[^>]*>/g, ''));`;
  for (const tz of ['Pacific/Kiritimati', 'America/Los_Angeles', 'Europe/Istanbul']) {
    const r = spawnSync(process.execPath, ['-e', kod], { env: Object.assign({}, process.env, { TZ: tz }), encoding: 'utf8' });
    assert.strictEqual(r.status, 0, r.stderr);
    assert.ok(r.stdout.replace(/\s+/g, ' ').startsWith('Tren · Per 5 Kas · 1 hayvan · bugün: PG günü'), tz + ': ' + r.stdout);
  }
});

// ── Gruplama ─────────────────────────────────────────────────────────────────
test('grupla: bağımsız ayrı, tren sırası artan, eşleşmeyen tekil', () => {
  const satirlar = ['h212', 'h36', 'h77', 'h1203', 'h38', 'h999', 'h169', 'h5708', 'h88', 'h418']
    .map(h => ({ hayvan_id: h, bolum: 'S1' }));
  const g = S.ovsyncTrenGrupla(satirlar, TREN_VERI);
  assert.deepStrictEqual(jn(g.gruplar.map(x => x[0])), ['2026-11-19', '2026-11-20', '2026-11-26']);
  assert.deepStrictEqual(jn(g.gruplar[0][1].map(s => s.hayvan_id)), ['h36', 'h38', 'h169', 'h5708']);
  assert.strictEqual(g.gruplar[0][2], TREN19);
  assert.deepStrictEqual(jn(g.gruplar[1][1].map(s => s.hayvan_id)), ['h77']);
  assert.deepStrictEqual(jn(g.gruplar[2][1].map(s => s.hayvan_id)), ['h212', 'h418']);
  assert.deepStrictEqual(jn(g.bagimsiz.map(s => s.hayvan_id)), ['h1203', 'h88']);
  assert.deepStrictEqual(jn(g.tekil.map(s => s.hayvan_id)), ['h999']);
  // tren verisi yok → hepsi tekil
  const g2 = S.ovsyncTrenGrupla(satirlar, null);
  assert.strictEqual(g2.gruplar.length, 0);
  assert.strictEqual(g2.tekil.length, satirlar.length);
});

// ── Toptan erteleme ──────────────────────────────────────────────────────────
test('toptan: SECIM satırı seçimsiz → onay kapalı; seçilince açık', () => {
  assert.strictEqual(S.ovsyncToptanOnayAcikMi(PLAN_N1, {}), false);
  assert.strictEqual(S.ovsyncToptanOnayAcikMi(PLAN_N1, { 'c-36': 'PG48' }), true);
  assert.strictEqual(S.ovsyncToptanOnayAcikMi(PLAN_N1, { 'c-36': 'BASTAN' }), true);
  assert.strictEqual(S.ovsyncToptanOnayAcikMi(PLAN_N1, { 'c-36': 'BASKA' }), false);
  // bilinmeyen sonuç ya da boş plan → kapalı (fail-closed)
  const bozuk = { tren: 'x', yeni_tren: 'y', uyeler: [uye('h1', '1', 0, { sonuc: '?' })] };
  assert.strictEqual(S.ovsyncToptanOnayAcikMi(bozuk, {}), false);
  assert.strictEqual(S.ovsyncToptanOnayAcikMi({ uyeler: [] }, {}), false);
  assert.strictEqual(S.ovsyncToptanOnayAcikMi(null, {}), false);
});

test('toptan html: KAYAR/BASTAN/SECIM metinleri, N seçici, ritim satırı, onay pasif', () => {
  const h1 = S.ovsyncToptanOnizlemeHtml(PLAN_N1, {}, '2026-11-26');
  const t1 = metin(h1);
  assert.ok(t1.includes('🚆 Tren gününü ertele — Per 26 Kas'), t1);
  assert.ok(t1.includes('Bugünün Ovsync işleri: 3 hayvan. Kaç gün?'), t1);
  assert.match(h1, /<button class="ovs-cip on" data-n="1">\+1<\/button>/);
  assert.strictEqual((h1.match(/class="ovs-cip[^"]*" data-n="\d"/g) || []).length, 7);
  assert.match(h1, /<span class="ovs-on-sonuc ovs-kayar">kayar → Cum 27 Kas<\/span>/);
  assert.match(h1, /<span class="ovs-on-sonuc ovs-secim">seçim gerekli<\/span>/);
  assert.ok(t1.includes('PG yapıldı, ertelenemez. Seçin:'), t1);
  assert.match(h1, /data-case="c-36" data-secim="PG48"/);
  assert.match(h1, /data-case="c-36" data-secim="BASTAN"/);
  assert.ok(t1.includes("(a) PG1 + 48 s'te tohumla"), t1);
  assert.ok(t1.includes('(b) Baştan başlat → Cum 27 Kas treni'), t1);
  assert.ok(t1.includes('🔁 Ritim kalıcı kayar: tren günü bundan sonra her Cuma (sonraki: Cum 4 Ara).'), t1);
  assert.ok(t1.includes('1 hayvan için (a) ya da (b) seçin.'), t1);
  assert.match(h1, /data-ovt-aksiyon="ONAYLA" disabled>Onayla \(3 hayvan\)/);
  assert.ok(t1.includes('Tek işlem: biri işlenemezse hiçbiri değişmez, düşen hayvan ve nedeni yazılır.'), t1);

  const h2 = S.ovsyncToptanOnizlemeHtml(PLAN_N2, { 'c-36': 'PG48' }, '2026-11-26');
  const t2 = metin(h2);
  assert.match(h2, /<span class="ovs-on-sonuc ovs-bastan">baştan başlar → Cmt 28 Kas<\/span>/);
  assert.match(h2, /<button class="ovs-cip on" data-n="2">\+2<\/button>/);
  assert.match(h2, /class="ovs-radyo on" data-case="c-36" data-secim="PG48"/);
  assert.match(h2, /<span class="ovs-on-sonuc ovs-kayar">tohumla/);
  assert.ok(t2.includes('her Cumartesi (sonraki: Cmt 5 Ara)'), t2);
  assert.match(h2, /data-ovt-aksiyon="ONAYLA">Onayla \(3 hayvan\)/);
  assert.ok(!t2.includes('seçin.'), t2);
  // BASTAN seçimi → baştan başlar
  const h3 = S.ovsyncToptanOnizlemeHtml(PLAN_N2, { 'c-36': 'BASTAN' }, '2026-11-26');
  assert.match(h3, /class="ovs-radyo on" data-case="c-36" data-secim="BASTAN"/);
  // X bugün değilse "Bugünün" yazmaz
  assert.ok(metin(S.ovsyncToptanOnizlemeHtml(PLAN_N1, {}, '2026-11-25')).includes('Per 26 Kas Ovsync işleri: 3 hayvan.'));
});

test('toptan html: escape + bilinmeyen sonuç sessiz düşmez', () => {
  const p = { tren: '2026-11-26', yeni_tren: '2026-11-27', uyeler: [uye('h', '<b>9</b>', 0, { sonuc: 'GARIP' })] };
  const h = S.ovsyncToptanOnizlemeHtml(p, {}, '2026-11-26');
  assert.ok(!h.includes('<b>9</b>'));
  assert.ok(metin(h).includes('bilinmeyen sonuç: GARIP'), metin(h));
  assert.match(h, /data-ovt-aksiyon="ONAYLA" disabled/);
});

// ── K10 Ovsync görevi tanımı (SQL TR-K10-9 ile aynı tablo) ───────────────────
test('görev mu: R5 tablosu (TR-K10-9 eşi)', () => {
  const k = { hayvanIdSet: new Set(['h36']), gunIdSet: new Set(['d-ovs-1']) };
  const g = (gorev_tipi, hayvan_id, aciklama) => ({ gorev_tipi, hayvan_id, aciklama });
  assert.strictEqual(S.ovsyncTrenGorevMu(g('OVSYNC_BASLAT', 'h999', null), k), true);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('TOHUMLAMA_PLANLI', 'h36', null), k), true);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('TOHUMLAMA_PLANLI', 'h1450', null), k), false);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('ILAC', 'h36', null), k), false);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('TEDAVI_GUN', 'h640', '{"day_id":"d-mastit"}'), k), false);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('TEDAVI_SEANS', 'h5708', '{"day_id":"d-ovs-1","seans":1}'), k), true);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('TEDAVI_GUN', 'h5708', '{"day_id":"d-ovs-1"}'), k), true);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('ASI', 'h36', null), k), false);
  assert.strictEqual(S.ovsyncTrenGorevMu(null, k), false);
  assert.strictEqual(S.ovsyncTrenGorevMu(g('OVSYNC_BASLAT', 'h1', null), undefined), true);
});

test('görev mu: bozuk aciklama sessiz geçmez (hata bildirilir), false döner', () => {
  const k = { hayvanIdSet: new Set(), gunIdSet: new Set(['d1']) };
  const hatalar = [];
  const r = S.ovsyncTrenGorevMu({ id: 'g-bozuk', gorev_tipi: 'TEDAVI_GUN', hayvan_id: 'h', aciklama: '{bozuk' },
    Object.assign({}, k, { hata: (m) => hatalar.push(m) }));
  assert.strictEqual(r, false);
  assert.strictEqual(hatalar.length, 1);
  assert.match(hatalar[0], /g-bozuk/);
  // geri çağırım yoksa console.error (bozuk JSON'da; F8: düz metin sessiz)
  const eski = console.error; const log = [];
  console.error = (...a) => log.push(a.join(' '));
  try {
    S.ovsyncTrenGorevMu({ id: 'g2', gorev_tipi: 'TEDAVI_SEANS', hayvan_id: 'h', aciklama: '{bozuk2' }, k);
    assert.strictEqual(log.length, 1);
    assert.match(log[0], /g2/);
    log.length = 0;
    assert.strictEqual(S.ovsyncTrenGorevMu({ id: 'g3', gorev_tipi: 'TEDAVI_GUN', hayvan_id: 'h', aciklama: 'düz metin' }, k), false);
    assert.strictEqual(log.length, 0);
  } finally { console.error = eski; }
});

// ── Görevler ekranı bağlantıları ─────────────────────────────────────────────
test('düzenle link: "Ovsync ekranında düzenle →", hayvan id data-attr ile escape', () => {
  const h = S.ovsyncDuzenleLinkHtml({ hayvan_id: "h'36\"" });
  assert.match(h, /^<button class="ovs-duzenle-link"/);
  assert.strictEqual(metin(h), 'Ovsync ekranında düzenle →');
  assert.ok(h.includes('data-hayvan="h&#39;36&quot;"'));
  assert.ok(h.includes('data-ovt-aksiyon="DUZENLE"'));
  gidilen.length = 0;
  S.ovsyncEkranindaDuzenle('h36');
  assert.deepStrictEqual(gidilen, ['ovsync']);
  assert.strictEqual(S.window._ovsyncOdakHayvan, 'h36');
});

test('çoklu not: 2 → "2 Ovsync görevi atlandı → Ovsync ekranı"; boş → ""', () => {
  const h = S.ovsyncCokluAtlananNot({ ovsync_atlanan: [
    { gorev_id: 'g1', case_id: 'c1', hayvan_id: 'h36', kupe_no: '36' },
    { gorev_id: 'g2', case_id: 'c2', hayvan_id: 'h5708', kupe_no: '5708' }] });
  const t = metin(h);
  assert.ok(t.includes('⏭ 2 Ovsync görevi atlandı (36, 5708)'), t);
  assert.ok(t.includes('Ovsync ekranı →'), t);
  assert.strictEqual(S.ovsyncCokluAtlananNot({ ovsync_atlanan: [] }), '');
  assert.strictEqual(S.ovsyncCokluAtlananNot({}), '');
  assert.strictEqual(S.ovsyncCokluAtlananNot(null), '');
});

// ── K11 geç tamamlama ────────────────────────────────────────────────────────
test('geç tamamlama: "⚠️ PG1 2 gün geç — baştan başlat önerilir" + iki aksiyon', () => {
  const h = S.ovsyncGecTamamlamaUyariHtml({ kod: 'PG1_TOLERANS_ASILDI', gecikme_gun: 2, oneri: 'BASTAN_BASLAT', case_id: 'c169', kupe_no: '169' });
  const t = metin(h);
  assert.ok(t.includes('⚠️ PG1 2 gün geç — baştan başlat önerilir'), t);
  assert.ok(t.includes('Kayıt alındı, protokol şu an devam ediyor.'), t);
  assert.match(h, /data-ovt-aksiyon="BASTAN" data-case="c169"/);
  assert.ok(t.includes('🔁 Baştan başlat → trene bin'), t);
  assert.ok(t.includes('Devam et (protokol sürsün)'), t);
  assert.strictEqual(S.ovsyncGecTamamlamaUyariHtml(null), '');
  // bilinmeyen kod → yine görünür uyarı (sessiz yok)
  assert.ok(metin(S.ovsyncGecTamamlamaUyariHtml({ kod: 'YENI_KOD' })).includes('YENI_KOD'));
});

// ── Aşama aksiyonları ────────────────────────────────────────────────────────
test('aşama aksiyon: 2 → kaydır yok, PG48+BASTAN var; 1 → ertele; 0 → sonraki tren; offline → ""', () => {
  const h2 = S.ovsyncAsamaAksiyonHtml(uye('h36', '36', 2), true);
  assert.match(h2, /^<div class="ovs-asama">/);
  assert.ok(!/data-ovt-aksiyon="(ERTELE|SONRAKI_TREN)"/.test(h2));
  assert.ok(!/kaydır/i.test(metin(h2)));
  assert.match(h2, /data-ovt-aksiyon="PG48" data-case="c-36"/);
  assert.match(h2, /data-ovt-aksiyon="BASTAN" data-case="c-36"/);
  assert.ok(metin(h2).includes("PG yapıldı · erteleme yok: PG1 + 48 s'te tohumla Baştan başlat"), metin(h2));

  const h1 = S.ovsyncAsamaAksiyonHtml(uye('h169', '169', 1, { sonraki_is: { tarih: '2026-11-26', tur: 'PG1' }, pg_pay: 1 }), true, '2026-11-26');
  assert.ok(metin(h1).includes("PG bugün: PG'yi ertele · en çok +1 gün"), metin(h1));
  assert.match(h1, /data-ovt-aksiyon="ERTELE" data-hayvan="h169"/);
  const h1b = S.ovsyncAsamaAksiyonHtml(uye('h1203', '1203', 1, { sonraki_is: { tarih: '2026-12-01', tur: 'PG1' } }), true, '2026-11-26');
  assert.ok(metin(h1b).startsWith("PG 01.12: PG'yi ertele"), metin(h1b));
  const h1c = S.ovsyncAsamaAksiyonHtml(uye('h77', '77', 1, { pg_pay: 0 }), true, '2026-11-26');
  assert.ok(metin(h1c).includes('Baştan başlat → trene bin'), metin(h1c));
  assert.ok(!h1c.includes('data-ovt-aksiyon="ERTELE"'));

  const h0 = S.ovsyncAsamaAksiyonHtml(uye('h212', '212', 0, { tren_gunu: '2026-11-26' }), true);
  assert.ok(metin(h0).includes('Başlamadı: Sonraki trene aktar → Per 3 Ara'), metin(h0));
  assert.match(h0, /data-ovt-aksiyon="SONRAKI_TREN" data-hayvan="h212"/);

  const hN = S.ovsyncAsamaAksiyonHtml(uye('h9', '9', null), true);
  assert.match(hN, /data-ovt-aksiyon="BASTAN"/);
  assert.ok(metin(hN).includes('Aşama belirsiz'), metin(hN));

  assert.strictEqual(S.ovsyncAsamaAksiyonHtml(uye('h36', '36', 2), false), '');
  assert.strictEqual(S.ovsyncAsamaAksiyonHtml(uye('h169', '169', 1), false), '');
});

// ── 🔔 Faz 0 ─────────────────────────────────────────────────────────────────
test('doğum PG hatırlatma: başlık sayısı, d2/d25 satırları, boş → ""', () => {
  const h = S.dogumPgHatirlatmaHtml([
    { hayvan_id: 'a', kupe_no: '1840', dogum_tarihi: '2026-11-24', gun: 2 },
    { hayvan_id: 'b', kupe_no: '<i>1702</i>', dogum_tarihi: '2026-11-01', gun: 25 }]);
  const t = metin(h);
  assert.ok(t.includes('💉 Doğum sonrası PG hatırlatma (2)'), t);
  assert.ok(t.includes('1840 · doğumun 2. günü'), t);
  assert.ok(t.includes('PG hatırlatması · doğum Sal 24 Kas'), t);
  assert.ok(t.includes('doğumun 25. günü'), t);
  assert.ok(t.includes('Yalnız hatırlatma'), t);
  assert.ok(!h.includes('<i>1702</i>'));
  assert.ok(!/onclick|✕|kapat/i.test(h), 'kapatma aksiyonu yok');
  assert.strictEqual(S.dogumPgHatirlatmaHtml([]), '');
  assert.strictEqual(S.dogumPgHatirlatmaHtml(null), '');
});

// ── Hata metinleri ───────────────────────────────────────────────────────────
test('hata metni: OVSYNC_TREN_ERTELE_DUSTU düşen küpeleri listeler', () => {
  const e = new Error('OVSYNC_TREN_ERTELE_DUSTU:{"dusenler":[{"hayvan_id":"h36","kupe_no":"36","sebep":"KAYDIR_HATA"},{"hayvan_id":"h5708","kupe_no":"5708","sebep":"X"}]}');
  const m = S.ovsyncTrenHataMetni(e);
  assert.ok(m.includes('36'), m);
  assert.ok(m.includes('5708'), m);
  assert.ok(m.includes('KAYDIR_HATA'), m);
  assert.match(m, /hiçbir hayvan değişmedi/);
});

test('hata metni: plan kodlarının hepsi tanınır; bozuk JSON ve bilinmeyen sessiz değil', () => {
  const kodlar = ['OVSYNC_TREN_EKRANI', 'OVSYNC_ASAMA1_TOLERANS', 'OVSYNC_ASAMA2_ERTELEME_YOK', 'OVSYNC_ASAMA_BELIRSIZ',
    'OVSYNC_TREN_SECIM_EKSIK', 'OVSYNC_TREN_ERTELE_DUSTU', 'OVSYNC_TREN_AYAR', 'OVSYNC_PG48_TAI_YOK', 'OVSYNC_PG48_GECMIS',
    'OVSYNC_GOREV_ACILAMADI'];
  for (const k of kodlar) {
    const m = S.ovsyncTrenHataMetni({ message: k + ':{}' });
    assert.ok(m && !m.startsWith(k), k + ' → ' + m);
  }
  const tol = S.ovsyncTrenHataMetni({ message: 'OVSYNC_ASAMA1_TOLERANS:{"tolerans":1,"mevcut_kayma":1,"istenen":1,"oneri":"BASTAN_BASLAT"}' });
  assert.match(tol, /1 gün/);
  assert.match(S.ovsyncTrenHataMetni({ message: 'OVSYNC_TREN_SECIM_EKSIK:{"eksik":["c1","c2"]}' }), /2 hayvan/);
  // bozuk JSON → ham ayrıntı korunur
  const boz = S.ovsyncTrenHataMetni({ message: 'OVSYNC_TREN_ERTELE_DUSTU:{dusenler:[36' });
  assert.ok(boz.includes('{dusenler:[36'), boz);
  // bilinmeyen → ham mesaj; boş → genel metin
  assert.strictEqual(S.ovsyncTrenHataMetni(new Error('ZZZ_BILINMEYEN boom')), 'ZZZ_BILINMEYEN boom');
  assert.strictEqual(S.ovsyncTrenHataMetni('düz metin'), 'düz metin');
  assert.ok(S.ovsyncTrenHataMetni(null).length > 0);
});

// ── N4 UA1 düzeltmeleri (F2/F3/F4/F7/F8/F9/F15, UB-ek 2/3) ───────────────────
test('F2 ritim dışı notu ritim_disi_neden’den üretilir (sabit metin yok)', () => {
  const tren = { tren_gunu: '2026-11-20', ritim_disi: true,
    uyeler: [uye('h77', '77', 1, { ritim_disi_neden: 'PG +1 gün' })] };
  const t = metin(S.ovsyncTrenBaslikHtml(tren, '2026-11-26'));
  assert.ok(t.includes('ritim dışı'), t);
  assert.ok(t.includes('PG +1 gün'), t);
  assert.ok(!t.includes('Tek hayvan ertelemesiyle ritimden çıktı'), t);
  // neden yoksa genel not; yine sabit cümle yok, kural cümlesi korunur
  const t2 = metin(S.ovsyncTrenBaslikHtml(TREN20_RD, '2026-11-26'));
  assert.ok(!t2.includes('Tek hayvan ertelemesiyle ritimden çıktı'), t2);
  assert.ok(t2.includes('Toptan ertelemeye girmez'), t2);
});

test('F3 aşama 0 etiketi: ritim içiyse hedef tarihli, ritim dışıysa tarihsiz', () => {
  const t = metin(S.ovsyncAsamaAksiyonHtml(uye('h212', '212', 0, { tren_gunu: '2026-11-26' }), true));
  assert.ok(t.includes('Sonraki trene aktar → Per 3 Ara'), t);
  const tRd = metin(S.ovsyncAsamaAksiyonHtml(
    uye('h77', '77', 0, { tren_gunu: '2026-11-20', ritim_disi_neden: 'gecikmiş başlangıç' }), true));
  assert.ok(tRd.includes('Sonraki trene aktar'), tRd);
  assert.ok(!tRd.includes('→'), tRd);
});

test('F3 tekil ertele aralığı: aşama 1 → 1..pg_pay; bağımsız aşama 0 → 1..7', () => {
  assert.deepStrictEqual(jn(S.ovsyncTekErteleAraligi(uye('h169', '169', 1, { pg_pay: 1 }))), { min: 1, max: 1 });
  assert.deepStrictEqual(jn(S.ovsyncTekErteleAraligi(uye('h169', '169', 1, { pg_pay: 3 }))), { min: 1, max: 3 });
  assert.deepStrictEqual(jn(S.ovsyncTekErteleAraligi(uye('h1203', '1203', 0))), { min: 1, max: 7 });
  assert.strictEqual(S.ovsyncTekErteleAraligi(uye('h212', '212', 0, { tren_gunu: '2026-11-26' })), null);
  assert.strictEqual(S.ovsyncTekErteleAraligi(uye('h77', '77', 1, { pg_pay: 0 })), null);
  assert.strictEqual(S.ovsyncTekErteleAraligi(uye('h36', '36', 2)), null);
  assert.strictEqual(S.ovsyncTekErteleAraligi(uye('h9', '9', null)), null);
});

test('F4 sonuc null üye: "Aşama belirsiz — Baştan başlat" satırı + satırda eylem, onay kapalı', () => {
  const plan = { tren: '2026-11-26', yeni_tren: '2026-11-28', ileri_gorevler: [],
    uyeler: [uye('h169', '169', 1, { sonuc: 'KAYAR', yeni_tarih: '2026-11-28' }),
      uye('hX', 'X', null, { sonuc: null })] };
  const h = S.ovsyncToptanOnizlemeHtml(plan, {}, '2026-11-26');
  const t = metin(h);
  assert.ok(t.includes('Aşama belirsiz — Baştan başlat'), t);
  assert.match(h, /data-ovt-aksiyon="BASTAN" data-case="c-X"/);
  assert.ok(!t.includes('bilinmeyen sonuç'), t);
  assert.strictEqual(S.ovsyncToptanOnayAcikMi(plan, {}), false);
  assert.ok(t.includes('onay'), t);
});

test('F7 ONCEKI_TREN_VAR metni + GECMIS_TARIH + DUSTU sebep özyinelemesi', () => {
  const m = S.ovsyncTrenHataMetni({ message: 'OVSYNC_TREN_GUNU_DEGIL:{"tarih":"2026-11-26","sebep":"ONCEKI_TREN_VAR","ilk_tren":"2026-11-19"}' });
  assert.match(m, /Önce Per 19 Kas treni ertelenmeli/);
  const g = S.ovsyncTrenHataMetni({ message: 'GECMIS_TARIH:{"tarih":"2026-11-01","bugun":"2026-11-26"}' });
  assert.ok(!g.startsWith('GECMIS_TARIH'), g);
  assert.match(g, /geçmiş/i);
  const d = S.ovsyncTrenHataMetni({ message: 'OVSYNC_TREN_ERTELE_DUSTU:{"dusenler":[{"hayvan_id":"h36","kupe_no":"36","sebep":"OVSYNC_ASAMA1_TOLERANS:{\\"tolerans\\":1}"}]}' });
  assert.ok(d.includes('36'), d);
  assert.ok(!d.includes('OVSYNC_ASAMA1_TOLERANS:{'), d);
  assert.match(d, /en çok 1 gün/);
  for (const k of ['OVSYNC_TREN_UYELIK_YOK', 'OVSYNC_BASTAN_HEDEF_GECERSIZ', 'OVSYNC_PG48_SEANS_KAPANMADI',
    'OVSYNC_VAKA_ACILAMADI', 'OVSYNC_SABLON_BELIRSIZ', 'OVSYNC_SABLON_UYGULANAMADI', 'OVSYNC_HASTALIK_BELIRSIZ',
    'OVSYNC_TAI_OLUSMADI', 'OVSYNC_SECIM_KISIR', 'OVSYNC_SECIM_TABAN_YOK', 'OVSYNC_SECIM_ERKEN',
    'OVSYNC_ERKEN', 'OVSYNC_BASLAT_PARAMETRE', 'TAKIP_ACIK', 'GOREV_BULUNAMADI', 'GOREV_TIPI_UYUMSUZ', 'OZELLIK_KAPALI']) {
    const t = S.ovsyncTrenHataMetni({ message: k + ':{}' });
    assert.ok(t && !t.startsWith(k), k + ' → ' + t);
  }
});

test('K4 önekli kod: P0001/HTTP 400 öneki ilk bulunan OVSYNC_TREN_KAPALI seçilir', () => {
  for (const m of ['P0001: OVSYNC_TREN_KAPALI', 'HTTP 400 OVSYNC_TREN_KAPALI']) {
    const t = S.ovsyncTrenHataMetni({ message: m });
    assert.ok(t.includes('tren') && t.includes('kapalı'), m + ' → ' + t);
    assert.ok(!t.includes('P0001') && !t.includes('HTTP'), m + ' → ' + t);
  }
});

test('F8 düz metin aciklama → sessiz false (m2 adli)', () => {
  const k = { hayvanIdSet: new Set(), gunIdSet: new Set(['d1']) };
  const hatalar = [];
  const r = S.ovsyncTrenGorevMu({ id: 'g-duz', gorev_tipi: 'TEDAVI_GUN', hayvan_id: 'h', aciklama: 'Gün 10 — Ovsync 4. uygulama' },
    Object.assign({}, k, { hata: (m) => hatalar.push(m) }));
  assert.strictEqual(r, false);
  assert.strictEqual(hatalar.length, 0);
});

test('F9 ertele düğmesi yalnız ilk ritim günü başlığında', () => {
  const veri = { trenler: [TREN19, TREN26], bagimsizlar: [] };
  const ilk = S.ovsyncIlkToptanTarih(veri, '2026-11-16');
  assert.strictEqual(ilk, '2026-11-19');
  assert.ok(S.ovsyncTrenBaslikHtml(TREN19, '2026-11-16', true, ilk).includes('ovs-tren-ertele'));
  assert.ok(!S.ovsyncTrenBaslikHtml(TREN26, '2026-11-16', true, ilk).includes('ovs-tren-ertele'));
  // 4. parametre yoksa eski davranış aynen
  assert.ok(S.ovsyncTrenBaslikHtml(TREN26, '2026-11-16').includes('ovs-tren-ertele'));
  assert.strictEqual(S.ovsyncIlkToptanTarih(null, '2026-11-16'), null);
});

test('N4-F3 H2 düğme başlığı: X\'in kendi treni; yoksa X\'i D7 sayan ilk tren; X yoksa null', () => {
  // bugün Pzt 9 Kas: 4 Kas treninin D7'si = 11 Kas = 11 Kas treninin D0'ı (iki başlık aynı X)
  const T04 = { tren_gunu: '2026-11-04', ritim_disi: false, uyeler: [uye('h1', '1', 2)] };
  const T11 = { tren_gunu: '2026-11-11', ritim_disi: false, uyeler: [uye('h2', '2', 0)] };
  assert.strictEqual(S.ovsyncToptanBaslikTreni({ trenler: [T04, T11] }, '2026-11-09'), '2026-11-11');
  // kendi treni listede yok → X yine 11 Kas, düğme 4 Kas başlığında kalır (kaybolmaz)
  assert.strictEqual(S.ovsyncToptanBaslikTreni({ trenler: [T04] }, '2026-11-09'), '2026-11-04');
  assert.strictEqual(S.ovsyncToptanBaslikTreni({ trenler: [TREN19, TREN26] }, '2026-11-16'), '2026-11-19');
  assert.strictEqual(S.ovsyncToptanBaslikTreni({ trenler: [TREN20_RD] }, '2026-11-16'), null);
  assert.strictEqual(S.ovsyncToptanBaslikTreni(null, '2026-11-16'), null);
});

test('BOŞLUK-3 bağımsız üyede neden/hastalık satırı yok', () => {
  const h = S.ovsyncAsamaAksiyonHtml(uye('h1203', '1203', 1,
    { sonraki_is: { tarih: '2026-12-01', tur: 'PG1' }, ritim_disi_neden: 'PG +1 gün' }), true, '2026-11-26');
  const t = metin(h);
  assert.ok(t.includes('PG 01.12'), t);
  assert.ok(!t.includes('PG +1 gün'), t);
});

test('F15 inline onclick yok, DUZENLE bağlama', () => {
  const h1 = S.ovsyncDuzenleLinkHtml({ hayvan_id: 'h36' });
  const h2 = S.ovsyncCokluAtlananNot({ ovsync_atlanan: [{ kupe_no: '36' }] });
  for (const h of [h1, h2, S.ovsyncTrenSoruHtml(ONIZLEME), S.ovsyncToptanOnizlemeHtml(PLAN_N1, {}, '2026-11-26')]) {
    assert.ok(!/onclick\s*=/.test(h), h);
  }
  assert.match(h1, /data-ovt-aksiyon="DUZENLE" data-hayvan="h36"/);
  assert.match(h2, /data-ovt-aksiyon="DUZENLE"/);
});

test('bayrak kapalı → eski yol birebir (rpc/modal yok)', async () => {
  let rpcSay = 0, modalSay = 0; const toasts = [];
  const r = await S.ovsyncTrenSor({ hayvanId: 'h212', online: true, aktif: false,
    rpc: async () => { rpcSay++; }, toast: (m) => toasts.push(m), acModal: async () => { modalSay++; return 'TREN'; } });
  assert.deepStrictEqual({ ...r }, { secim: 'TREN', tarih: null });
  assert.strictEqual(rpcSay, 0);
  assert.strictEqual(modalSay, 0);
  assert.deepStrictEqual(toasts, []);
});

test('UB-ek2 acModal reddi yakalanır: toast + null, throw yok', async () => {
  const toasts = [];
  const r = await S.ovsyncTrenSor({ hayvanId: 'h212', online: true, rpc: async () => ONIZLEME,
    toast: (m) => toasts.push(m), acModal: async () => { throw new Error('kapandı'); } });
  assert.strictEqual(r, null);
  assert.strictEqual(toasts.length, 1);
});

// ── Renk kuralı (sahip: vurgu yalnız yazı rengi) ─────────────────────────────
test('renk: üretilen HTML\'de background/border-left şerit yok', () => {
  const ciktilar = [
    S.ovsyncTrenSoruHtml(ONIZLEME),
    S.ovsyncTrenBaslikHtml(TREN19, '2026-11-26'), S.ovsyncTrenBaslikHtml(TREN20_RD, '2026-11-26'),
    S.ovsyncToptanOnizlemeHtml(PLAN_N1, {}, '2026-11-26'), S.ovsyncToptanOnizlemeHtml(PLAN_N2, { 'c-36': 'PG48' }, '2026-11-26'),
    S.ovsyncDuzenleLinkHtml({ hayvan_id: 'h' }),
    S.ovsyncCokluAtlananNot({ ovsync_atlanan: [{ kupe_no: '36' }] }),
    S.ovsyncGecTamamlamaUyariHtml({ kod: 'PG1_TOLERANS_ASILDI', gecikme_gun: 2, case_id: 'c' }),
    S.ovsyncAsamaAksiyonHtml(uye('h', '1', 2), true), S.ovsyncAsamaAksiyonHtml(uye('h', '1', 1), true),
    S.ovsyncAsamaAksiyonHtml(uye('h', '1', 0), true),
    S.dogumPgHatirlatmaHtml([{ kupe_no: '1', dogum_tarihi: '2026-11-24', gun: 2 }]),
  ];
  for (const h of ciktilar) {
    assert.ok(h.length > 0);
    assert.ok(!/border-left\s*:/i.test(h), 'border-left: ' + h);
    const bg = h.match(/background(-color)?\s*:\s*[^;"]+/gi) || [];
    for (const b of bg) assert.match(b, /:\s*(none|transparent)\s*$/i, 'zemin: ' + b);
  }
});

// ── N4-F4 Y2: tren başlığı iş etiketi (üyelerin sonraki_is en erken günü) ────
test('iş etiketi bugün / ileri gün', () => {
  const si = (tarih, tur) => ({ tarih, saat: null, tur });
  const T5 = { tren_gunu: '2026-11-05', ritim_disi: false, uyeler: [
    uye('h03', '03', 1, { sonraki_is: si('2026-11-12', 'PG1') }),
    uye('h04', '04', 2, { sonraki_is: si('2026-11-13', 'TAI') })] };
  const T12 = { tren_gunu: '2026-11-12', ritim_disi: false, uyeler: [
    uye('h01', '01', 0, { sonraki_is: si('2026-11-12', 'GNRH1') }),
    uye('h02', '02', 0, { sonraki_is: si('2026-11-12', 'GNRH1') }),
    uye('h5708', '5708', 0, { sonraki_is: null })] };
  // ileri gün: "<Gün gg Ay>: <iş>", kırmızı "bugün" sınıfı yok
  const a = S.ovsyncTrenBaslikHtml(T5, '2026-11-09');
  assert.ok(metin(a).startsWith('Tren · Per 5 Kas · 2 hayvan · Per 12 Kas: PG günü'), metin(a));
  assert.ok(!a.includes('ovs-tren-bugun'), a);
  const b = metin(S.ovsyncTrenBaslikHtml(T12, '2026-11-09'));
  assert.ok(b.startsWith('Tren · Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü'), b);
  // bugün: "bugün: <iş>" kırmızı sınıfla
  const c = S.ovsyncTrenBaslikHtml(T12, '2026-11-12');
  assert.ok(metin(c).startsWith('Tren · Per 12 Kas · 3 hayvan · bugün: başlangıç günü'), metin(c));
  assert.match(c, /class="ovs-tren-bugun">bugün: başlangıç günü</);
  // TAI → PG+48 tohumlama; aynı gün iki iş → ikisi birlikte
  const T2 = { tren_gunu: '2026-11-05', ritim_disi: false, uyeler: [
    uye('h1', '1', 2, { sonraki_is: si('2026-11-14', 'TAI') }),
    uye('h2', '2', 1, { sonraki_is: si('2026-11-14', 'PG1') })] };
  const d = metin(S.ovsyncTrenBaslikHtml(T2, '2026-11-14'));
  assert.ok(d.includes('bugün: PG+48 tohumlama + PG günü') || d.includes('bugün: PG günü + PG+48 tohumlama'), d);
  // sonraki_is hiç yoksa eski D0 gün farkı kuralı (mockup başlık testleri) korunur
  assert.ok(metin(S.ovsyncTrenBaslikHtml(TREN26, '2026-11-26')).includes('bugün: başlangıç günü'));
});

// ── S2: geçmiş tarihli iş etiketi "gecikmiş · " + amber yazı rengi ──────────
test('iş etiketi gecikmiş: geçmiş tarih önekli+amber, bugün/ileri değişmez', () => {
  const si = (tarih, tur) => ({ tarih, saat: null, tur });
  const T = (tarih, ritimDisi) => ({ tren_gunu: tarih, ritim_disi: !!ritimDisi, uyeler: [
    { hayvan_id: 'h1', sonraki_is: si(tarih, 'GNRH1') }] });
  const g = S.ovsyncTrenBaslikHtml(T('2026-11-04'), '2026-11-09');
  assert.match(g, /<span class="ovs-tren-is ovs-tren-gecikmis" style="color:var\(--amber\)">gecikmiş · Çar 4 Kas: başlangıç günü<\/span>/, g);
  assert.ok(!/background|border/i.test(g), 'zemin/şerit yok: ' + g);
  assert.ok(!metin(S.ovsyncTrenBaslikHtml(T('2026-11-09'), '2026-11-09')).includes('gecikmiş'));
  assert.ok(metin(S.ovsyncTrenBaslikHtml(T('2026-11-09'), '2026-11-09')).includes('bugün: başlangıç günü'));
  const f = S.ovsyncTrenBaslikHtml(T('2026-11-12'), '2026-11-09');
  assert.ok(!f.includes('gecikmiş') && !f.includes('gecikmis') && f.includes('Per 12 Kas: başlangıç günü'), f);
  const rd = metin(S.ovsyncTrenBaslikHtml(T('2026-11-04', true), '2026-11-09'));
  assert.ok(rd.includes('ritim dışı') && rd.includes('gecikmiş · Çar 4 Kas'), rd);
});
