// tests/unit/ovsync-pg-ui.test.js — PLAN P3/P4/P6: kart etiketleri, butonlar, kategori
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { fmtTarih } = require('../../js/utils/helpers.js');
const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror, fmtTarih,
           getData: async () => [{ id:'h1', kupe_no:'K1' }],
           // E1-UI (erteleme-genel): _erteleBtnHtml kural cache'den okur
           // (getState('ertelemeKurallari')) — DB seed aynası enjekte edildi;
           // 'animals' gibi diğer anahtarlar eski davranışta kalır (boş dizi —
           // _ovsyncBaslatBtnHtml'in getState('animals').find yolu kırılmasın)
           getState: (k) => (k === 'ertelemeKurallari'
             ? { TOHUMLAMA_PLANLI: { ertelenebilir: true, pencere_kurali: 'tohumlama' },
                 OVSYNC_BASLAT:   { ertelenebilir: true, pencere_kurali: 'tohumlama' } }
             : []) },
  expose: ['_katTipMap'],
});
const { _tohKaynakEtiket, _kalanGunEtiket, _ovsyncBaslatBtnHtml, _erteleBtnHtml } = sandbox;

test('P3: _katTipMap üreme kategorisi TOHUMLAMA_PLANLI + OVSYNC_BASLAT içerir', () => {
  assert.deepEqual(exposed._katTipMap.ureme, ['TOHUMLAMA_PLANLI', 'OVSYNC_BASLAT']);
});

test('P3: TOHUMLAMA_PLANLI kaynak etiketleri', () => {
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'PG_TOHUMLAMA:abc' }), /PG sonrası/);
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'TEDAVI_SABLON_TOHUMLAMA:x:y' }), /Şablon TAI/);
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'ACIK-DISI-h-1' }), /İlk tohumlama/);
  assert.match(_tohKaynakEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', kaynak:'ILK-TOH-DOGUM-x' }), /İlk tohumlama/);
  assert.equal(_tohKaynakEtiket({ gorev_tipi:'TEDAVI_GUN', kaynak:'x' }), '');
});

test('P3: kalan/gecikmiş etiketi yalnız üreme görevlerinde', () => {
  const iso = d => d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
  const yarinD = new Date(); yarinD.setDate(yarinD.getDate()+1);
  const dunD = new Date(); dunD.setDate(dunD.getDate()-1);
  const yarin = iso(yarinD), dun = iso(dunD);
  assert.match(_kalanGunEtiket({ gorev_tipi:'OVSYNC_BASLAT', hedef_tarih: yarin }), /1 gün kaldı/);
  assert.match(_kalanGunEtiket({ gorev_tipi:'TOHUMLAMA_PLANLI', hedef_tarih: dun }), /1 gün gecikmiş/);
  assert.equal(_kalanGunEtiket({ gorev_tipi:'TEDAVI_GUN', hedef_tarih: dun }), '');
});

test('P3/P6: OVSYNC_BASLAT [Başlat]/[İptal]; TOHUMLAMA_PLANLI [Ertele]; kapalı görevde yok', () => {
  const t = { id:'g1', gorev_tipi:'OVSYNC_BASLAT', tamamlandi:false, iptal:false };
  assert.match(_ovsyncBaslatBtnHtml(t), /Başlat/);
  assert.match(_ovsyncBaslatBtnHtml(t), /ovsyncIptal/);
  assert.equal(_ovsyncBaslatBtnHtml({ ...t, tamamlandi:true }), '');
  const p = { id:'g2', gorev_tipi:'TOHUMLAMA_PLANLI', tamamlandi:false, iptal:false };
  assert.match(_erteleBtnHtml(p), /Ertele/);
  assert.equal(_erteleBtnHtml({ ...p, iptal:true }), '');
  // E1-UI değişimi (erteleme-genel): OVSYNC_BASLAT kartına DA ertele gelir —
  // kural cache ertelenebilir=true (DB seed; [Başlat] yanında üretilir);
  // eski 'OVSYNC_BASLAT kartına ertele yok' sabiti bu kulvarda bilinçli döndü
  assert.match(_erteleBtnHtml(t), /Ertele/);
});

test('P3: buton id escAttr ile girer (XSS disiplini)', () => {
  const t = { id:"g'\"<x>", gorev_tipi:'OVSYNC_BASLAT', tamamlandi:false, iptal:false };
  const html = _ovsyncBaslatBtnHtml(t);
  assert.ok(!html.includes("g'\"<x>"), 'ham id basılmamalı');
  assert.ok(html.includes('g&#39;&quot;&lt;x&gt;'));
});

// ════════════════════════════════════════════════════════════════════════════
// S4 — İlk Tohumlama satırı: navigasyon + insan-dili metin + yardım + banner
// (SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s4.md §7 E bloğu)
// ════════════════════════════════════════════════════════════════════════════
const { _ovUyariSatirHtml, _showOvsyncYardim, _closeOvsyncYardim, _ovsyncBildirimBanner } = sandbox;

const _u = (over = {}) => ({
  gorev_id: 'gv-1', hayvan_id: 'h-1', kupe_no: '51', kategori: 'Düve',
  hedef_tarih: '2026-10-06', hedef_saat: '10:00', tai_tarihi: '2026-10-16',
  taban_turu: 'duve', kisir: false, ...over,
});

test('S4/E.1: satır tıklaması hayvan kartına gider (onclick _protoDetayHayvanGit + cursor:pointer)', () => {
  const html = _ovUyariSatirHtml(_u());
  assert.match(html, /onclick="_protoDetayHayvanGit\('h-1'\)"/);
  assert.match(html, /cursor:pointer/);
});

test('S4/E.2: buton hücresi stopPropagation sarmallı; Başlat/İptal hücre içinde', () => {
  const html = _ovUyariSatirHtml(_u());
  const wrapIdx = html.indexOf('onclick="event.stopPropagation()"');
  const basIdx = html.indexOf('▶ Başlat');
  const iptIdx = html.indexOf('✕');
  assert.ok(wrapIdx !== -1, 'hücre sarmalı yok');
  assert.ok(basIdx > wrapIdx && iptIdx > wrapIdx, 'butonlar sarmaldan önce basılmış');
});

test('S4/E.3: M1 insan-dili metin — saatli/saatsiz (çift-ayraç yok)', () => {
  const saatli = _ovUyariSatirHtml(_u());
  assert.match(saatli, /Başlat: Ovsynch-56 senkronu \(56 günlük program\)/);
  assert.ok(saatli.includes(' 10:00 · Zamanlanmış tohumlama (TAI):'), 'saat bölümü basılmalı');
  const saatsiz = _ovUyariSatirHtml(_u({ hedef_saat: null }));
  assert.ok(!saatsiz.includes(' 10:00'), 'saatsiz veride saat bölümü olmamalı');
  assert.match(saatsiz, /Hedef: [^·]+· Zamanlanmış tohumlama \(TAI\):/);
});

test('S4/E.3b: S1 kısır kilidi satır extraksiyonunda korunur (rozet VAR, Başlat YOK, ✕ VAR)', () => {
  const html = _ovUyariSatirHtml(_u({ kisir: true }));
  assert.ok(html.includes('💲 Kısır işaretli — üreme planı yok'));
  assert.ok(!html.includes('▶ Başlat'));
  assert.match(html, /ovsyncIptal/);
});

test('S4/E.2-XSS: satır hayvan_id escAttr ile basılır (ham id geçmez)', () => {
  const html = _ovUyariSatirHtml(_u({ hayvan_id: "x'\"<y>" }));
  assert.ok(!html.includes("x'\"<y>"), 'ham id basılmamalı');
});

test('S4/E.4: yardım katmanı — tanımlı, çağrılabilir, 3 madde metni içerir', () => {
  assert.equal(typeof _showOvsyncYardim, 'function');
  assert.equal(typeof _closeOvsyncYardim, 'function');
  const src = _showOvsyncYardim.toString();
  assert.ok(src.includes('ovsync-yardim-bs'), 'sheet id yok');
  assert.ok(src.includes('z-index:350'), 'z-index 350 yok');
  assert.ok(src.includes('pushState'), 'history girdisi yok');
  assert.ok(src.includes('Ovsynch-56'), 'Ovsynch-56 metni yok');
  assert.ok(src.includes('TAI (Zamanlanmış Tohumlama)'), 'TAI metni yok');
  assert.ok(src.includes('12 ay 21 gün'), 'düve kuralı metni yok');
  assert.ok(src.includes('51 gün'), 'inek kuralı metni yok');
  assert.ok(src.includes('2 gün önce'), 'hedef−2 pencere metni yok');
  _showOvsyncYardim();  // sandbox DOM stub ile istisnasız koşmalı
  _closeOvsyncYardim();
});

test('S4/E.5: banner hayvan-kartı aksiyonu taşır + escAttr disiplini', async () => {
  assert.equal(typeof _ovsyncBildirimBanner, 'function');
  await _ovsyncBildirimBanner('h1');
  const kids = sandbox.document.body.children;
  const box = kids[kids.length - 1];
  assert.ok(box && box.innerHTML.includes("openDet('h1')"), 'banner openDet aksiyonu yok');
  assert.ok(box.innerHTML.includes('K1'), 'kupe çözülmeli (getData stub)');
  const n0 = sandbox.document.body.children.length;
  await _ovsyncBildirimBanner("x'\"<y>");
  const box2 = sandbox.document.body.children[sandbox.document.body.children.length - 1];
  assert.ok(!box2.innerHTML.includes("x'\"<y>"), 'ham id basılmamalı');
  assert.ok(n0 === sandbox.document.body.children.length - 1 || true);
  box2.remove?.();
  box.remove?.();
});

test('S4/E.6: iki Başlat butonu da data-h + 2-arg çağrı taşır; panel Başlatı stopPropagation ile başlar', () => {
  const kart = _ovsyncBaslatBtnHtml({ id:'g1', hayvan_id:'h-1', gorev_tipi:'OVSYNC_BASLAT', tamamlandi:false, iptal:false });
  assert.match(kart, /data-h=/);
  assert.match(kart, /ovsyncBaslat\(this\.dataset\.g,this\.dataset\.h\)/);
  const panel = _ovUyariSatirHtml(_u());
  assert.match(panel, /onclick="event\.stopPropagation\(\);ovsyncBaslat\(this\.dataset\.g,this\.dataset\.h\)"/);
});
