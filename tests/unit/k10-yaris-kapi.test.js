// tests/unit/k10-yaris-kapi.test.js
// Faz UI-0 (karar 10) + UI-2 uyarlaması: U2 küpe başlığı + U3/U4 yarış kapısı
// yeni hastalık-günü kaydet zincirinde (hastalikGunKaydet/hastalikGunAc).
// Yöntem: loadModule/extract — js/ui.js'e dokunmadan davranış probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, loadExtractedFunction, makeDomStub } = require('./support/loadModule.js');

// ── Ortak: kaydet zinciri, yavaş pull + IDB gün doğrulaması ──
// Yarış varsa kayıt IDB'ye düşmeden taze render koşar; kilit bunu engeller.
function yarisCtx() {
  const govde = 'var _hgKayitKilit=false;\n' + ['hastalikGunKaydet', 'hgEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  doc.__setEl('hg-gun', { value: '7' });
  doc.__setEl('hg-hastalik', { value: 'd1' });
  doc.__setEl('hg-hastalik-ad', { value: 'İnaktif Ovaryum' });
  doc.__setEl('hg-tarih', { value: '2026-10-13' });
  doc.__setEl('hg-tai-chip', { getAttribute: () => '2026-10-15' });
  doc.__setEl('hg-ilac-liste', { children: [] });
  doc.__setEl('hastalik-modal', { remove() {} });
  const gunIdb = [];
  const pulls = [];
  const toasts = [];
  const sira = [];
  const idbGetAll = async (t) => (t === 'treatment_days' ? gunIdb.slice() : []);
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    rpc: async () => ({ ok: true, gun_id: 'gun-yaris', mevcut: false, ertelenen: 1, ilac: 0 }),
    // Yavaş pull: sunucu durumu IDB'ye YALNIZ pull bitince düşer (gerçek yarış).
    // ERT3: sahte pull istenen tabloya göre davranır (tablo-bağımsız ekleme YOK).
    pullTables: async (t) => {
      pulls.push((t || []).slice());
      await new Promise(r => setTimeout(r, 60));
      if ((t || []).indexOf('treatment_days') !== -1) gunIdb.push({ id: 'gun-yaris', case_id: 'v-ana' });
      sira.push('pull-bitti');
      return { ok: (t || []).slice(), failed: [] };
    },
    renderSafe: () => {},
    RPC_TABLES: { ovsync_hastalik_gunu_ekle: ['cases', 'treatment_days'] },
    idbGetAll,
    renderCaseTimeline: async () => { sira.push('taze-render'); },
    loadDash: () => {},
    _curCase: { id: 'v-ana' },
    dFwd: (iso, n) => { const d = new Date(iso + 'T00:00:00'); d.setDate(d.getDate() + n); const p = (x) => String(x).padStart(2, '0'); return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); },
    _pgKapiHata: () => false, _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'yaris-kaydet-ctx' });
  return { ctx, pulls, toasts, sira };
}

test('yavas-detay-yaris-yok', async () => {
  const t = yarisCtx();
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  const kotu = t.toasts.filter(m => m.includes('bulunamadı'));
  assert.strictEqual(kotu.length, 0, '"Vaka bulunamadı" yarışı YOK, ölçülen: ' + JSON.stringify(t.toasts));
  assert.ok(t.sira.includes('taze-render'), 'pull + IDB doğrulamasından SONRA taze render');
  assert.ok(t.pulls.length >= 1, 'pull koştu');
  assert.ok(
    t.sira.indexOf('pull-bitti') !== -1 && t.sira.indexOf('pull-bitti') < t.sira.indexOf('taze-render'),
    'sıra: önce pull, sonra render — ölçülen: ' + JSON.stringify(t.sira)
  );
});

// ── U2: modal yolunda başlık küpesi kart/_curCase'ten gelir ──
function kupeCtx() {
  const govde = ['hastalikGunAc', 'hastalikSheetHtml', '_hgVitSatir', '_hgTaiChip']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  const toasts = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    fmtTarih: (iso) => { const p = String(iso || '').slice(0, 10).split('-'); return p.length === 3 ? p[2] + '.' + p[1] + '.' + p[0] : String(iso); },
    toast: (m) => { toasts.push(String(m)); },
    // _curCase ham cases satırıdır (kupe_no YOK — gerçek U2 durumu).
    _curCase: { id: 'v-ana', animal_id: 'H-31', status: 'active', protocol_family: 'OVSYNC' },
    getState: (k) => (k === 'animals' ? [{ id: 'H-31', kupe_no: '31' }] : []),
    idbGetAll: async (t) => {
      if (t === 'diseases') return [{ id: 'd1', name: 'İnaktif Ovaryum' }];
      if (t === 'cases') return [{ id: 'v-ana', animal_id: 'H-31', status: 'active', protocol_family: 'OVSYNC' }];
      return [];
    },
    bugun: () => '2026-10-13',
    _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'kupe-ac-ctx' });
  return { ctx, doc, toasts };
}

test('kupe-baslik-dolu', async () => {
  const t = kupeCtx();
  await vm.runInContext(`hastalikGunAc('v-ana')`, t.ctx);
  const box = t.doc.body.children.find(e => e && e.id === 'hastalik-modal');
  assert.ok(box, 'sheet açılır');
  assert.ok(box.innerHTML.includes('Küpe 31'), 'başlık kart küpesini taşır (U2)');
  assert.ok(!box.innerHTML.includes('bilinmiyor'), 'bilinmiyor YOK, ölçülen başlık: '
    + (box.innerHTML.match(/— Küpe [^<]*/) || ['?'])[0]);
});
