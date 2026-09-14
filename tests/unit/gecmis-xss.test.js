// tests/unit/gecmis-xss.test.js
// TG1-W3 (luna F3/F4): geçmiş kartı render'ının DB kaynaklı metinlerinde ham
// tag/attribute enjeksiyonu ÜRETEMEMESinin adversarial birim testleri.
//
// Saldırı vektörleri luna denetim raporundan (2026-09-14-tarihe-git-f1-review):
//   F3 — hekim adı, dogum_tipi/sonuc, tedavi etiketi (_lbl), gorev_tipi
//        (class+metin), uygulama alanları (doz/birim/rota), bilinmeyen islem
//        tipleri: `<img src=x onerror=...>` çıktıda ham tag üretmemeli.
//   F4 — yeni aşı/kızgınlık/çıkış/sütten/protokol kartları DB kimliğini inline
//        onclick'e gömmemeli: `'A' onmouseover=...` attribute enjeksiyonu
//        üretmemeli (dataset + data-action delegasyonu).
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

// Tam modül BİR KEZ yükle; _gecmisEntryHtml dışarı çıkar. HEKIMLER/getState
// config/state kaynaklı — burada kontrollü enjeksiyon (hostile hekim adı dahil).
const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
  extra: {
    esc: escMirror,
    escAttr: escAttrMirror,
    fmtTarih, fmtTarihSaat,
    HEKIMLER: [],
    getState: () => [], // state.js sözleşmesi: getState(key) değer döner (animals → dizi)
    _gmUndoButtonHtml: () => '',
  },
  expose: ['_gecmisEntryHtml'],
});
const { _gecmisEntryHtml } = exposed;

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
