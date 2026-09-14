// tests/unit/gecmis-xss.test.js
// TG1-W3 (luna F3/F4) + U1: geçmiş kartı render'ının DB kaynaklı metinlerinde ham
// tag/attribute enjeksiyonu ÜRETEMEMESinin adversarial birim testleri.
//
// Saldırı vektörleri luna denetim raporundan (2026-09-14-tarihe-git-f1-review):
//   F3 — hekim adı, dogum_tipi/sonuc, tedavi etiketi (_lbl), gorev_tipi
//        (class+metin), uygulama alanları (doz/birim/rota), bilinmeyen islem
//        tipleri: `<img src=x onerror=...>` çıktıda ham tag üretmemeli.
//   F4 — yeni aşı/kızgınlık/çıkış/sütten/protokol kartları DB kimliğini inline
//        onclick'e gömmemeli: `'A' onmouseover=...` attribute enjeksiyonu
//        üretmemeli (dataset + data-action delegasyonu).
//   U1 — TÜM geçmiş kartları dataset-delegasyonlu (gm-islem/gm-case/gm-toh/
//        gm-stok/gm-kupe/gm-det; inline onclick YOK) + katlı toplu kart
//        (_gmKatKartHtml): küpe/ürün etiketleri ham tag üretmemeli, data-kat
//        anahtarı attribute kıramamalı; bilinmeyen islem tipi yedeği (etiket
//        fonksiyonu) ham kod/tag taşımamalı.
//
// Not: esc/escAttr aynaları ui-pure.test.js ile aynı (helpers.js birebir).
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { fmtTarih, fmtTarihSaat } = require('../../js/utils/helpers.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

// gecmis.js'i ÖNCE yükle — etiket/ikon haritası GERÇEK kaynak fonksiyonlarla
// enjekte edilir (testte ikinci bir harita kopyası yaşatılmaz — U1 tek-kaynak).
const gm = loadBrowserModule('js/gecmis.js', {
  expose: ['_GM_KATEGORI_TR', '_GM_KATEGORI_EMOJI'],
});

// Tam modül BİR KEZ yükle; _gecmisEntryHtml/_gmKatKartHtml dışarı çıkar.
// HEKIMLER/getState config/state kaynaklı — burada kontrollü enjeksiyon
// (hostile hekim adı dahil).
const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
  extra: {
    esc: escMirror,
    escAttr: escAttrMirror,
    fmtTarih, fmtTarihSaat,
    HEKIMLER: [],
    getState: () => [], // state.js sözleşmesi: getState(key) değer döner (animals → dizi)
    _gmUndoButtonHtml: () => '',
    _gmIslemTipEtiket: gm.sandbox._gmIslemTipEtiket,
    _gmIslemTipEmoji: gm.sandbox._gmIslemTipEmoji,
    _GM_KATEGORI_TR: gm.exposed._GM_KATEGORI_TR,
    _GM_KATEGORI_EMOJI: gm.exposed._GM_KATEGORI_EMOJI,
  },
  expose: ['_gecmisEntryHtml', '_gmKatKartHtml'],
});
const { _gecmisEntryHtml, _gmKatKartHtml } = exposed;

const IMG = '<img src=x onerror=alert(1)>';
// F4 vektörü — attribute bağlamından çıkmaya çalışan kimlik
const EVIL_ID = `A' onmouseover='alert(3) x='`;

function render(type, data, extra = {}) {
  return _gecmisEntryHtml({ type, data, eventAt: '2025-11-17T08:00:00Z', ...extra });
}

test('F3: hekim adı DB kaynaklı — çıktıda ham tag YOK (hkName yolu)', () => {
  sandbox.HEKIMLER = [{ id: 'H1', ad: IMG }];
  const h = render('dogum', { anne_id: 'A1', yavru_kupe: 'Y1', dogum_tipi: 'Normal', hekim_id: 'H1' });
  assert.ok(!h.includes('<img'), 'hekim adı escape edilmeli');
  assert.ok(h.includes('&lt;img'), 'escape edilmiş biçimde görünmeli');
});

test('F3: dogum_tipi ve tohumlama sonucu — ham tag YOK', () => {
  const d = render('dogum', { anne_id: 'A1', yavru_kupe: 'Y1', dogum_tipi: IMG });
  assert.ok(!d.includes('<img'), 'dogum_tipi escape edilmeli');
  const t = render('tohumlama', { hayvan_id: 'A1', sonuc: IMG, tarih: '2025-11-17' }, { sourceKey: 'tohumlama' });
  assert.ok(!t.includes('<img'), 'tohumlama sonucu escape edilmeli');
  const s = render('tohumlama', { hayvan_id: 'A1', sonuc: 'Gebe', tarih: '2025-11-17' }, { sourceKey: 'tohumlama_sonuc' });
  assert.ok(!s.includes('<img'), 'sonuç kalemi de güvenli (sonuc alanı yok — sabit metin)');
});

test('F3: tedavi etiketi (_lbl — gorev aciklama JSON) — ham tag YOK', () => {
  const g = render('gorev', { hayvan_id: 'A1', gorev_tipi: 'TEDAVI_GUN', tamamlandi: true, _lbl: IMG, _gunNo: 1 });
  assert.ok(!g.includes('<img'), 'tedavi etiketi escape edilmeli');
});

test('F3: gorev_tipi pill — class VE metin bağlamında enjeksiyon YOK', () => {
  const v = `X" onmouseover="alert(2)`;
  const g = render('gorev', { hayvan_id: 'A1', gorev_tipi: v, tamamlandi: true, aciklama: '{"label":"L"}' });
  // class attribute değeri escAttr ile taşınmalı: ham tırnak YOK → kırılım YOK
  const m = g.match(/<span class="pill ([^"]*)">/);
  assert.ok(m, 'pill span bulunmalı');
  assert.strictEqual(m[1], escAttrMirror(v), 'class değeri birebir escAttr çıkışı — ham tırnak içeremez');
  // metin bağlamında tag çıkışı YOK (esc <>& kaçırır; metinde tırnak zararsızdır)
  const g2 = render('gorev', { hayvan_id: 'A1', gorev_tipi: `<img src=y onerror=alert(2)>`, tamamlandi: true, aciklama: '{"label":"L"}' });
  assert.ok(!g2.includes('<img'), 'metin bağlamı escape edilmeli');
});

test('F3: uygulama alanları (doz/birim/rota) — ham tag YOK', () => {
  const u = render('uygulama', { hayvan_id: 'A1', _stokAdi: 'İlaç', doz: 2, birim: `<b>${IMG}</b>`, rota: 'IM' });
  assert.ok(!u.includes('<img'), 'birim/rota/doz escape edilmeli');
});

test('F3: bilinmeyen islem tipi — ham tip metni tag üretmez', () => {
  const i = render('islem', { ana_hayvan_id: 'A1', tip: `<img src=y onerror=alert(9)>` });
  assert.ok(!i.includes('<img'), 'bilinmeyen islem tipi escape edilmeli');
});

test('F4: yeni kart kimlikleri inline onclick YOK — dataset + escAttr', () => {
  const asi = render('asi', { animal_id: EVIL_ID, _asiAdi: 'Aşı' });
  const kiz = render('kizginlik', { hayvan_id: EVIL_ID, belirti: 'b' });
  const cik = render('cikis', { id: EVIL_ID, kupe_no: 'K1', cikis_tipi: 'Satıldı' });
  const sk = render('sutten', { id: EVIL_ID, kupe_no: 'K1' });
  const pr = render('protokol', { hayvan_id: EVIL_ID, kupe_no: 'K1' }, { sourceKey: 'protokol_instance' });
  [asi, kiz, cik, sk, pr].forEach((h, i) => {
    assert.ok(!h.includes('onclick='), `kart ${i}: inline onclick olmamalı`);
    assert.ok(h.includes('data-action="gm-det"'), `kart ${i}: dataset delegasyonu taşınmalı`);
    // attribute kırılım ölçümü: data-det değeri birebir escAttr çıkışı — ham
    // tırnak içeremez (tırnak kaçışı olmadan attribute'tan çıkılamaz; değer
    // içindeki onmouseover=... artık ölü bir alt-dizgidir)
    const m = h.match(/data-det="([^"]*)"/);
    assert.ok(m, `kart ${i}: data-det attribute bulunmalı`);
    assert.strictEqual(m[1], escAttrMirror(EVIL_ID), `kart ${i}: kimlik escAttr ile taşınmalı`);
  });
});

// ── U1: tüm geçmiş kartları dataset-delegasyonlu + katlı kart güvenliği ──

test('U1: islem kartı gm-islem dataset\'li — EVIL id inline onclick KIRMADAN taşınır', () => {
  const i = render('islem', { id: EVIL_ID, ana_hayvan_id: 'A1', tip: 'TEDAVI_GUN_EKLENDI', snapshot: { kupe_no: 'K1' } });
  assert.ok(!i.includes('onclick='), 'inline onclick olmamalı');
  assert.ok(i.includes('data-action="gm-islem"'), 'gm-islem delegasyonu taşınmalı');
  const m = i.match(/data-det="([^"]*)"/);
  assert.ok(m, 'data-det bulunmalı');
  assert.strictEqual(m[1], escAttrMirror(EVIL_ID), 'islem id escAttr ile taşınmalı');
  assert.ok(i.includes('Tedavi Günü Eklendi'), 'etiket tek haritadan gelmeli');
  assert.ok(!/TEDAVI_GUN_EKLENDI/.test(i.replace(/data-[^=]*="[^"]*"/g, '')), 'görünür metinde ham kod YOK');
});

test('U1: hastalik/tohumlama kartları gm-case/gm-toh — EVIL id escAttr', () => {
  const h = render('hastalik', { id: EVIL_ID, animal_id: 'A1', status: 'active', disease_name: 'Mastit' }, { sourceKey: 'cases' });
  const t = render('tohumlama', { id: EVIL_ID, hayvan_id: 'A1', sperma: 'S', sonuc: 'Bekliyor' }, { sourceKey: 'tohumlama' });
  [h, t].forEach((x, i) => {
    assert.ok(!x.includes('onclick='), `kart ${i}: inline onclick olmamalı`);
    const m = x.match(/data-action="gm-(case|toh)" data-det="([^"]*)"/);
    assert.ok(m, `kart ${i}: gm-case/gm-toh dataset'i bulunmalı`);
    assert.strictEqual(m[2], escAttrMirror(EVIL_ID), `kart ${i}: id escAttr ile taşınmalı`);
  });
});

test('U1: stok kartı gm-stok — EVIL stok_id escAttr; metin alanları esc', () => {
  const s = render('stok', { stok_id: EVIL_ID, tur: 'Çıkış', miktar: 2, _urunAdi: `${IMG}`, _birim: 'ml' });
  assert.ok(!s.includes('onclick='), 'inline onclick olmamalı');
  assert.ok(!s.includes('<img'), 'ürün adı escape edilmeli');
  const m = s.match(/data-action="gm-stok" data-det="([^"]*)"/);
  assert.ok(m, 'gm-stok dataset\'i bulunmalı');
  assert.strictEqual(m[1], escAttrMirror(EVIL_ID), 'stok_id escAttr ile taşınmalı');
});

test('U1: dogum kartı spans — anne/yavru kimlikleri inline onclick YOK, escAttr', () => {
  const d = render('dogum', { anne_id: EVIL_ID, yavru_kupe: `K" onmouseover="alert(4)`, yavru_cins: 'Dişi' });
  assert.ok(!d.includes('onclick='), 'dogum kartında inline onclick olmamalı');
  assert.ok(d.includes('data-action="gm-det"'), 'anne span gm-det taşımalı');
  assert.ok(d.includes('data-action="gm-kupe"'), 'yavru span gm-kupe taşımalı');
  const anne = d.match(/data-action="gm-det" data-det="([^"]*)"/);
  assert.strictEqual(anne[1], escAttrMirror(EVIL_ID), 'anne id escAttr');
  const yavru = d.match(/data-action="gm-kupe" data-det="([^"]*)"/);
  assert.strictEqual(yavru[1], escAttrMirror(`K" onmouseover="alert(4)`), 'yavru küpe escAttr');
});

test('U1: katlı kart — hostile küpe/ürün etiketi ham tag ÜRETMEZ, data-kat kıramaz', () => {
  const girdiler = [1, 2, 3].map(i => ({
    type: 'islem', category: 'islem', sourceKey: 'islem_log',
    eventAt: '2026-09-13T06:00:0' + i + 'Z', dateKey: '2026-09-13', olayGunu: '2026-09-13',
    undoRef: null,
    data: { id: 'isl-' + i, tip: 'TEDAVI_GUN_EKLENDI', ana_hayvan_id: 'A' + i, snapshot: { kupe_no: `${IMG}${i}` } },
  }));
  const kat = _gmKatKartHtml({ grup: true, tip: 'TEDAVI_GUN_EKLENDI', sourceKey: 'islem_log', dakika: '09:00', dateKey: '2026-09-13', eventAt: '2026-09-13T06:00:00Z', entries: girdiler, count: 3 });
  assert.ok(!kat.includes('<img'), 'katlı kart küpe listesi escape edilmeli');
  assert.ok(kat.includes('&lt;img'), 'escape edilmiş biçimde görünmeli');
  assert.ok(!kat.includes('onclick='), 'katlı kartta inline onclick olmamalı');
  const k = kat.match(/data-kat="([^"]*)"/);
  assert.ok(k && /^gm-kat-[a-zA-Z0-9-]*$/.test(k[1]), 'data-kat deterministik-temiz anahtar olmalı: ' + (k && k[1]));
  assert.ok(kat.includes('— 3 hayvan'), 'grup başlığı sayaç taşımalı');
});

test('U1: katlı kart (stok) — ürün adı escape; bilinmeyen grup tipi yedek etikete düşer', () => {
  const girdiler = [1, 2, 3].map(i => ({
    type: 'stok', category: 'stok', sourceKey: 'stok_hareket',
    eventAt: '2026-09-13T06:00:0' + i + 'Z', dateKey: '2026-09-13', olayGunu: '2026-09-13',
    undoRef: null,
    data: { stok_id: 'S' + i, tur: 'Çıkış', miktar: 1, _urunAdi: `${IMG}`, _birim: 'ml' },
  }));
  const kat = _gmKatKartHtml({ grup: true, tip: 'BILINMEYEN_KAYNAK_TIPI', sourceKey: 'bilinmeyen_kaynak', dakika: '09:00', dateKey: '2026-09-13', eventAt: '2026-09-13T06:00:00Z', entries: girdiler, count: 3 });
  assert.ok(!kat.includes('<img'), 'ürün adı escape edilmeli');
  assert.ok(kat.includes('İşlem: bilinmeyen kaynak tipi'), 'bilinmeyen grup tipi okunur yedeğe düşmeli — ham kod YOK');
  assert.ok(!/BILINMEYEN_KAYNAK_TIPI/.test(kat.replace(/data-[^=]*="[^"]*"/g, '')), 'görünür metinde ham kod YOK');
});

// ── U1 root düzeltmeleri (2026-09-14): UUID YOK, hayvansız '? YOK' ──

test('root-1: kart başlığında ham UUID ASLA YOK — IDB küpe indeksi çözer, çözülmeyen ? olur', () => {
  sandbox._gmHayvanKupeById = { 'uuid-abc': '121' };
  const i = render('islem', { id: 'x1', ana_hayvan_id: 'uuid-abc', tip: 'GOREV_TAMAMLA', snapshot: {} });
  assert.ok(i.includes('121'), 'IDB indeksinden küpe çözülmeli');
  assert.ok(!/uuid-abc/.test(i), 'ham UUID görünmemeli');
  const j = render('islem', { id: 'x2', ana_hayvan_id: 'uuid-yok', tip: 'ASI_KAYDI', snapshot: {} });
  assert.ok(!/uuid-yok/.test(j), 'çözülemeyen hayvan UUID olarak da görünmez');
  assert.ok(j.includes('Genel'), 'çözülemeyen hayvansız başlık Genel\'e düşer (root-2) — ne UUID ne ?');
});

test('root-2: hayvansız islem kartı — snapshot etiketi yoksa Genel (>? YOK)', () => {
  const g = render('islem', { id: 'x3', tip: 'GOREV_TAMAMLA', snapshot: { aciklama: '{"label":"Sabah sağımı"}' } });
  assert.ok(g.includes('Sabah sağımı'), 'snapshot JSON etiketi gösterilmeli');
  const g2 = render('islem', { id: 'x4', tip: 'GOREV_TAMAMLA', snapshot: {} });
  assert.ok(g2.includes('Genel'), 'etiketsiz hayvansız → Genel');
  assert.ok(!g2.includes('>?</span>'), '? başlıkta YOK');
});

test('root-3: katlı kart küpe listesinde UUID YOK — indeksten küpe', () => {
  sandbox._gmHayvanKupeById = { 'uuid-k1': '04' };
  const girdiler = [1, 2, 3].map(i => ({
    type: 'islem', category: 'islem', sourceKey: 'islem_log',
    eventAt: '2026-09-13T06:00:0' + i + 'Z', dateKey: '2026-09-13', olayGunu: '2026-09-13',
    undoRef: null,
    data: { id: 'k' + i, tip: 'TEDAVI_GUN_EKLENDI', ana_hayvan_id: 'uuid-k1', snapshot: {} },
  }));
  const kat = _gmKatKartHtml({ grup: true, tip: 'TEDAVI_GUN_EKLENDI', sourceKey: 'islem_log', dakika: '09:00', dateKey: '2026-09-13', eventAt: '2026-09-13T06:00:00Z', entries: girdiler, count: 3 });
  assert.ok(kat.includes('04 · 04 · 04'), 'katlı listede küpe (04)');
  assert.ok(!/uuid-k1/.test(kat), 'UUID YOK');
});
