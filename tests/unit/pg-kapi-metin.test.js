// tests/unit/pg-kapi-metin.test.js — PG kapısı (REQUIRE_ACK_PENDING) açıklama metni iki kolda.
// §18.8 şablonlu vaka: kanca (tedavi_sablon_bos_ata_uygula) verilen kolda kapı PG uygulamaz; Boş atar ve
// seçilen planı yazar — metin bunu söyler. Şablon dışı kolun (tohumlama_bos_ve_devam, PG zinciri) metni değişmez.
// ui.js kapı fonksiyonları ve caseSablonUygula gerçektir (kanca gerçek çağırandan gelir); rpc ve DOM sahtedir.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { makeDomStub, makeElement, extractFunctionSource } = require('./support/loadModule.js');

const PG_RED_TOH = 'PG_KAPI:REQUIRE_ACK_PENDING:{"tohumlama_id":"T-1"}';
const ESKI = 'PG gebeliği sonlandırabilir. "Boş ata ve uygula" tohumlamayı Boş yapıp PG\'yi aynı zincirde uygular.';
const SABLONLU = 'PG gebeliği sonlandırabilir. "Boş ata ve uygula": tohumlama Boş atanır ve seçilen tedavi planı yazılır.';

function sahne() {
  const document = makeDomStub();
  const aciklama = document.__setEl('pg-kapi-aciklama', makeElement('span'));
  const sandbox = vm.createContext({
    document, window: {}, console, Promise, JSON, setTimeout,
    navigator: { onLine: true },
    history: { state: null, back() {}, pushState() {} },
    _curCase: { id: 'C-7' }, _cdSablonTarih: '2026-11-08', _drugsCache: [],
    esc: s => String(s || ''), fmtTarih: x => String(x),
    toast: () => {}, getUserMessage: e => String(e?.message || e),
    rpc: async (ad, p) => { if (ad === 'tedavi_sablon_uygula' && !p.p_pg_onay) throw new Error(PG_RED_TOH); return { ok: true }; },
    pullTables: async () => {}, loadDrugsCache: async () => {},
    renderCaseTimeline: async () => {}, _updateKapatBtn: () => {},
  });
  sandbox.window = sandbox;
  for (const f of ['_pgKapiAc', '_pgKapiHata', '_pgKapiKapat', 'caseSablonUygula'])
    vm.runInContext(extractFunctionSource('js/ui.js', f), sandbox);
  vm.runInContext(extractFunctionSource('js/forms.js', '_vakaBosAtaKanca'), sandbox);
  const kutu = () => document.body.children.find(c => c.id === 'pg-kapi-bs');
  return { sandbox, aciklama, kutu };
}
const mikro = () => new Promise(r => setTimeout(r, 0));

test('PKM-01: şablonlu kol (kanca var) — metin Boş atama + seçilen plan, PG zinciri demez; düğme aynı', async () => {
  const { sandbox, aciklama, kutu } = sahne();
  await sandbox.caseSablonUygula('S-3');
  await mikro();
  assert.strictEqual(typeof sandbox.window.__pgKapiBosAta, 'function', 'kanca verildi');
  assert.match(kutu().innerHTML, /<span id="pg-kapi-aciklama"[^>]*>/, 'açıklama kimlikli');
  assert.strictEqual(aciklama.textContent, SABLONLU);
  assert.ok(!aciklama.textContent.includes('aynı zincirde'), 'PG uygulanır demez');
  assert.ok(kutu().innerHTML.includes('>Boş ata ve uygula</button>'), 'düğme etiketi değişmedi');
});

test('PKM-02: şablon dışı kol (kanca yok) — eski metin aynen, sonradan değiştirilmez', async () => {
  const { sandbox, aciklama, kutu } = sahne();
  assert.ok(sandbox._pgKapiHata(new Error(PG_RED_TOH), async () => {}));
  await mikro();
  assert.ok(!sandbox.window.__pgKapiBosAta, 'kanca yok');
  assert.ok(kutu().innerHTML.includes(ESKI), 'şablon dışı metin değişmedi');
  assert.strictEqual(aciklama.textContent, '', 'metin sonradan ezilmedi');
  assert.ok(kutu().innerHTML.includes('>Boş ata ve uygula</button>'));
});
