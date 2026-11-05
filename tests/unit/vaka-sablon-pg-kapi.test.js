// tests/unit/vaka-sablon-pg-kapi.test.js — vaka detayından şablon uygulama (caseSablonUygula) PG kapısı.
// domain-rules §18.8 şablonlu vaka (sahip 2026-11-05): "Boş ata ve uygula" tek RPC'de Boş + seçilen planı yazar
// (tedavi_sablon_bos_ata_uygula, 20261031200007); kapı PG uygulamaz, plandaki PG tek PG'dir.
// ui.js kapı fonksiyonları, caseSablonUygula ve forms.js _vakaBosAtaKanca gerçektir; rpc, DOM ve tazeleme sahtedir.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { makeDomStub, makeElement, extractFunctionSource } = require('./support/loadModule.js');

const PG_RED_TOH = 'PG_KAPI:REQUIRE_ACK_PENDING:{"tohumlama_id":"T-1"}';
const BOS_ATA = 'tedavi_sablon_bos_ata_uygula';
const UYGUN = { ok: true, gun_sayisi: 4, atlanan: [] };

function sahne({ bosAtaYanit = () => UYGUN } = {}) {
  const rec = { rpc: [], toast: [], olay: [], bosVeDevam: [] };
  const document = makeDomStub();
  const gerekce = makeElement('input'); gerekce.value = 'gerekçe';
  document.__setEl('pg-kapi-gerekce', gerekce);
  const onay = makeElement('button');
  document.__setEl('pg-kapi-onayla', onay);
  const sandbox = vm.createContext({
    document, window: {}, console, Promise, JSON, setTimeout,
    navigator: { onLine: true },
    history: { state: null, back() {}, pushState() {} },
    _curCase: { id: 'C-7' }, _cdSablonTarih: '2026-11-08', _drugsCache: [],
    esc: s => String(s || ''), fmtTarih: x => String(x),
    toast: (m, h) => { rec.toast.push([m, !!h]); },
    getUserMessage: e => 'JENERIK:' + (e?.message || String(e)),
    rpc: async (ad, p) => {
      rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) });
      if (ad === 'tedavi_sablon_uygula' && !p.p_pg_onay) throw new Error(PG_RED_TOH);
      if (ad === 'tedavi_sablon_uygula') throw new Error('onaylı tekrar bu kapıda kullanılmaz');
      if (ad === BOS_ATA) return bosAtaYanit(p);
      return { ok: true, olustu: true };
    },
    tohumlamaBosVeDevam: async p => { rec.bosVeDevam.push(p); return { ok: true, son_pg: null }; },
    pullTables: async t => { rec.olay.push('pull:' + t.join(',')); },
    loadDrugsCache: async () => { rec.olay.push('drugs'); },
    renderCaseTimeline: async id => { rec.olay.push('render:' + id); },
    _updateKapatBtn: id => { rec.olay.push('kapat:' + id); },
  });
  sandbox.window = sandbox;
  for (const f of ['_pgKapiAc', '_pgKapiHata', '_pgKapiKapat', '_pgKapiOnayliTekrar', '_pgKapiBosAtaUygula', 'caseSablonUygula'])
    vm.runInContext(extractFunctionSource('js/ui.js', f), sandbox);
  vm.runInContext(extractFunctionSource('js/forms.js', '_vakaBosAtaKanca'), sandbox);
  return { sandbox, rec, onay, dokun: () => (onay.disabled ? null : sandbox._pgKapiBosAtaUygula()) };
}
const hatalar = rec => rec.toast.filter(([, h]) => h).map(([m]) => m);
const basarilar = rec => rec.toast.filter(([m, h]) => !h && m.startsWith('✅')).map(([m]) => m);

test('VSP-01: vaka detayında kapı açılır; Boş ata tek RPC\'de Boş + planı yazar, başlangıç günü taşınır, kapı PG uygulamaz', async () => {
  const { sandbox, rec, dokun } = sahne();
  await sandbox.caseSablonUygula('S-3');
  assert.strictEqual(sandbox.window.__pgKapiToh, 'T-1', 'kapı tohumlama bağlamıyla açık');
  assert.deepStrictEqual(hatalar(rec), [], 'düz hata toast\'u yok');
  rec.rpc.length = 0;
  await dokun();
  assert.deepStrictEqual(rec.rpc.map(r => r.ad), [BOS_ATA, 'tedavi_sablon_tohumlama_gorev_ekle']);
  assert.deepStrictEqual(rec.rpc[0].p, { p_case_id: 'C-7', p_sablon_id: 'S-3', p_tohumlama_id: 'T-1', p_gerekce: 'gerekçe', p_baslangic_tarihi: '2026-11-08' });
  assert.deepStrictEqual(rec.bosVeDevam, [], 'PG modu ve dry-run yok');
  assert.deepStrictEqual(basarilar(rec), ['✅ Şablon uygulandı (4 gün) + tohumlama'], 'tek ✅, plan sonucu sayısıyla');
  assert.ok(rec.olay.some(o => o.startsWith('pull:') && o.includes('tohumlama') && o.includes('hayvanlar')));
  assert.ok(rec.olay.includes('render:C-7') && rec.olay.includes('kapat:C-7'), 'plan ve Kapat düğmesi tazelenir');
  assert.ok(!sandbox.window.__pgKapiToh && !sandbox.window.__pgKapiBosAta, 'kapı kapandı, kanca temizlendi');
});

test('VSP-02: Boş ata reddedilirse kapı açık kalır, düğme açılır, görev yok; ikinci deneme başarılı', async () => {
  let n = 0;
  const { sandbox, rec, onay, dokun } = sahne({ bosAtaYanit: () => { if (!n++) throw new Error('PG_KAPI_BOS_ATA:TOH_SONUCLU:{}'); return UYGUN; } });
  await sandbox.caseSablonUygula('S-3');
  await dokun();
  assert.deepStrictEqual(hatalar(rec), ['❌ Boş atanmadı, plan yazılmadı: JENERIK:PG_KAPI_BOS_ATA:TOH_SONUCLU:{}']);
  assert.ok(sandbox.window.__pgKapiToh && !onay.disabled, 'kapı açık, düğme basılabilir');
  assert.strictEqual(rec.rpc.filter(r => r.ad === 'tedavi_sablon_tohumlama_gorev_ekle').length, 0);
  await dokun();
  assert.strictEqual(rec.rpc.filter(r => r.ad === BOS_ATA).length, 2);
  assert.strictEqual(rec.rpc.filter(r => r.ad === 'tedavi_sablon_tohumlama_gorev_ekle').length, 1);
});

test('VSP-03: çift dokunuşta Boş ata bir kez gider', async () => {
  let bitir;
  const { sandbox, rec, dokun } = sahne({ bosAtaYanit: () => new Promise(res => { bitir = () => res(UYGUN); }) });
  await sandbox.caseSablonUygula('S-3');
  const ilk = dokun();
  assert.strictEqual(dokun(), null);
  bitir();
  await ilk;
  assert.strictEqual(rec.rpc.filter(r => r.ad === BOS_ATA).length, 1);
});

test('VSP-04: vazgeçilirse kanca düşer, plan yazılmaz', async () => {
  const { sandbox, rec } = sahne();
  await sandbox.caseSablonUygula('S-3');
  sandbox._pgKapiKapat();
  assert.ok(!sandbox.window.__pgKapiBosAta);
  assert.strictEqual(rec.rpc.filter(r => r.ad === BOS_ATA).length, 0);
});
