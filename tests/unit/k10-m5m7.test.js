// tests/unit/k10-m5m7.test.js
// Faz UI-3 (karar 10): M5/M6/M7 yeni-modele metin uyarlaması.
// M6 S4 devam rozeti: 'alt vaka' dili kalktı; öğeler treatment_days satırıdır
// (RPC alt_vakalar öğesi {id, hastalik, status}; hastalik = diseases.name,
// bağ treatment_days.disease_id) — rozet 'Ovsync içinde hastalık günü' der ve
// ebeveyn vaka detayına çıkar (gün id'si hedef olmaz).
// Yöntem: loadModule/extract + vm — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { extractFunctionSource, loadExtractedFunction } = require('./support/loadModule.js');

function s4() {
  return loadExtractedFunction('js/ui.js', '_ovsyncS4SatirHtml', {
    extra: {
      _ovsyncBaglamAl: () => ({ vakaKapali: new Map([['h1', { id: 'v-ana' }]]) }),
      esc: String, escAttr: String,
      _ovsyncSonlanmaRozeti: () => '', _ovsyncDenemeRozeti: () => '',
    },
  });
}
const TEK = { hayvan_id: 'h1', kupe_no: 'E2E-95', bolum: 'S4', alt_vakalar: [{ id: 'gun-1', hastalik: 'İnaktif Ovaryum', status: 'acik' }] };
const COK = {
  hayvan_id: 'h1', kupe_no: 'E2E-95', bolum: 'S4',
  alt_vakalar: [{ id: 'gun-1', hastalik: 'İnaktif Ovaryum', status: 'acik' }, { id: 'gun-2', hastalik: 'Kistik Over', status: 'acik' }],
};
const BOS = { hayvan_id: 'h1', kupe_no: 'E2E-95', bolum: 'S4', alt_vakalar: [] };

test('k10-m6-yeni-metin', () => {
  const f = s4();
  const tek = f(TEK, '2026-10-13');
  assert.ok(tek.includes('Ovsync içinde hastalık günü'), 'yeni rozet metni, ölçülen: ' + tek.slice(tek.indexOf('🦠') - 40, tek.indexOf('🦠') + 80));
  assert.ok(tek.includes('İnaktif Ovaryum'), 'tek günde hastalık adı (disease_id okuma)');
  assert.ok(tek.includes("openCaseDet('v-ana')"), 'rozet ebeveyn detayına çıkar');
  assert.ok(!tek.includes('gun-1'), 'gün id hedefte geçmez');
  const cok = f(COK, '2026-10-13');
  assert.ok(cok.includes('Ovsync içinde hastalık günü'), 'çok günde rozet metni');
  assert.ok(cok.includes('(2)'), 'çok günde sayaç, ölçülen: ' + (cok.match(/\(\d+\)/) || ['?'])[0]);
  assert.ok(!cok.includes('gun-1') && !cok.includes('gun-2'), 'gün id hedefte geçmez');
  const bos = f(BOS, '2026-10-13');
  assert.ok(!bos.includes('Ovsync içinde hastalık günü'), 'gün yoksa rozet çizilmez');
});

test('k10-m6-eski-metin-yok', () => {
  const src = extractFunctionSource('js/ui.js', '_ovsyncS4SatirHtml');
  assert.ok(!src.includes('alt vaka'), 'eski etiket kaynakta YOK, ölçülen eşleşme: ' + JSON.stringify(src.match(/alt.vaka/gi)));
  const f = s4();
  for (const [ad, satir] of [['tek', TEK], ['cok', COK], ['bos', BOS]]) {
    const h = f(satir, '2026-10-13');
    assert.ok(!h.includes('alt vaka'), ad + ': eski etiket HTMLde YOK');
    assert.ok(!h.includes('🔗'), ad + ': eski zincir simgesi YOK');
  }
});
