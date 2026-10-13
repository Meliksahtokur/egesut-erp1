// tests/unit/k10-n1-kart.test.js
// Faz UI-1 (karar 10, N1): hayvan kartında Ovsync satırı altında girintili
// hastalık alt-satırı ("└ İnaktif Ovaryum · 13.10 (Ovsync içinde)");
// ayrı 🏥 vaka satırı YOK. Görsel dil: mevcut .gm-kat-acik + yazı rengi
// (var(--amber)); yeni zemin/şerit YOK.
// Yöntem: loadModule/extract — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource } = require('./support/loadModule.js');

// fmtTarih gerçeği gibi GG.AA.YYYY üretir (kısa biçim _devamKisaTarih'te kırpılır).
function n1Ctx() {
  const govde = ['renderCasesForAnimal', '_devamKisaTarih']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const BASE = {
    vakalar: [
      { id: 'v-ov', animal_id: 'H-1', status: 'active', protocol_family: 'OVSYNC',
        disease_id: 'd-ov', start_date: '2026-10-08', created_at: '2026-10-08T10:00:00', notes: '' },
      { id: 'v-diger', animal_id: 'H-1', status: 'active', protocol_family: null,
        disease_id: 'd-mastit', start_date: '2026-10-09', created_at: '2026-10-09T10:00:00', notes: '' },
    ],
    gunler: [
      { id: 'g1', case_id: 'v-ov', disease_id: 'd-inaktif', treatment_date: '2026-10-13', day_no: 1 },
      { id: 'g0', case_id: 'v-ov', disease_id: null, treatment_date: '2026-10-08', day_no: 0 },
    ],
    hastaliklar: [
      { id: 'd-ov', name: 'Ovsync' },
      { id: 'd-inaktif', name: 'İnaktif Ovaryum' },
      { id: 'd-mastit', name: 'Mastit' },
    ],
  };
  const ctx = {
    console, JSON, Math, Date,
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    fmtTarih: (iso) => {
      const s = String(iso || '').slice(0, 10);
      const [y, m, d] = s.split('-');
      return `${d}.${m}.${y}`;
    },
    idbGetAll: async (t) => {
      if (t === 'cases') return BASE.vakalar.slice();
      if (t === 'treatment_days') return BASE.gunler.slice();
      if (t === 'diseases') return BASE.hastaliklar.slice();
      return [];
    },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'n1-kart-ctx' });
  return ctx;
}

test('k10-n1-girintili-satir', async () => {
  const ctx = n1Ctx();
  const html = await vm.runInContext(`renderCasesForAnimal('H-1')`, ctx);
  assert.ok(html.includes('gm-kat-acik'), 'girinti sınıfı var, ölçülen: ' + html.slice(0, 200));
  assert.ok(html.includes('└'), 'dirsek glifi var');
  assert.ok(html.includes('İnaktif Ovaryum'), 'hastalık adı var');
  assert.ok(html.includes('13.10'), 'kısa tarih (GG.AA) var, ölçülen: '
    + (html.match(/└[^<]*/) || ['?'])[0]);
  assert.ok(html.includes('(Ovsync içinde)'), 'Ovsync-içi ibaresi var');
  assert.ok(html.includes('color:var(--amber)'), 'vurgu yalnız yazı rengi (amber)');
  const alt = html.match(/<div class="gm-kat-acik"[^]*?<\/div>/) || [''];
  assert.ok(!alt[0].includes('background'), 'alt-satırda zemin/şerit YOK, ölçülen: ' + alt[0].slice(0, 160));
});

test('k10-n1-ayri-satir-yok', async () => {
  const ctx = n1Ctx();
  const html = await vm.runInContext(`renderCasesForAnimal('H-1')`, ctx);
  const satir = (html.match(/hist-row/g) || []).length;
  assert.strictEqual(satir, 2, 'yalnız iki vaka satırı (hastalık günü ayrı satır DEĞİL), ölçülen: ' + satir);
  assert.ok(!html.includes('🏥'), 'kartta ayrı 🏥 hastalık satırı YOK');
  const ovBlok = html.split('v-ov')[1].split('v-diger')[0];
  assert.ok(ovBlok.includes('gm-kat-acik'), 'alt-satır Ovsync satırının bloğunda');
});
