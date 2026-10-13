// tests/unit/inaktif-gecis-buton.test.js
'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const { extractFunctionSource, loadExtractedFunction } = require('./support/loadModule.js');
test('inaktif-gecis-buton-gun-sorusu', () => {
  const html = loadExtractedFunction('js/ui.js', 'inaktifGecisSheetHtml', { extra: { escAttr: String, esc: String } })('v-ana',
    { hastaliklar: [{ id: 'd1', name: 'İnaktif Ovaryum' }, { id: 'd2', name: 'Kistik Over' }], vitaminStok: { id: 's1', urun_adi: 'CAROFERTIN-E' } });
  assert.match(html, /id="ig-gun"[^>]*value="7"/, 'gün sorusu, varsayılan 7 (karar 5)');
  assert.match(html, /id="ig-vit-doz"[^>]*value="20"/, 'CAROFERTIN-E 20 ml ön-dolu (karar 7)');
  assert.ok(['İnaktif Ovaryum', 'Kistik Over', 'CAROFERTIN-E'].every(t => html.includes(t)), 'karar 6-7 seçenekleri');
  const kaydet = extractFunctionSource('js/ui.js', 'inaktifGecisKaydet');
  assert.ok(kaydet.includes("rpc('inaktif_alt_vaka_ac'") && kaydet.includes('p_gun'), 'aç-RPC p_gun ile');
  assert.ok(!kaydet.includes('vaka_kalan_gunleri_kaydir'), 'kaydır RPC çağrılmaz');
});
test('donus-ui-public-rpc', () => {
  const ui = fs.readFileSync(path.join(__dirname, '..', '..', 'js/ui.js'), 'utf8');
  assert.ok(extractFunctionSource('js/ui.js', 'inaktifAltVakaDonus').includes("rpc('inaktif_alt_vaka_kapat'"));
  assert.ok(!/rpc\w*\('_/.test(ui), 'UI _önekli iç yardımcı çağırmaz');
});
test('yetim-ovsync-rozeti', () => {
  const f = loadExtractedFunction('js/ui.js', '_ovsyncYetimMi');
  const v = { id: 'v1', status: 'active', protocol_family: 'OVSYNC' };
  assert.strictEqual(f(v, [], []), true, 'açık TAI/seans yok + alt yok → yetim');
  assert.strictEqual(f(v, [{ gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: false, iptal: false }], []), false);
  assert.strictEqual(f(v, [{ gorev_tipi: 'TEDAVI_SEANS', tamamlandi: false, iptal: false }], []), false);
  assert.strictEqual(f(v, [{ gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: true, iptal: true }], []), true, 'iptal TAI sayılmaz');
  assert.strictEqual(f(v, [], [{ status: 'active' }]), false, 'açık alt vaka varken yetim değil');
  assert.strictEqual(f({ ...v, status: 'closed' }, [], []), false);
});
