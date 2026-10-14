// tests/unit/k10-hizli-faz-hata-toast.test.js
// ERT1 (IMPL-K10-B-F3 RULING 3): RPC basarili + hizli faz treatment_days
// cekemezse "günü açıldı" toast'u ATILMAZ; yerine "kaydedildi, ekran
// yenilenemedi — yenile" + ikinci fazda treatment_days yeniden denenir.
// Yontem: extract + vm — js/ui.js'e dokunmadan davranis probu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { extractFunctionSource, makeDomStub } = require('./support/loadModule.js');

function hataCtx() {
  const govde = 'var _hgKayitKilit=false;\n' + ['hastalikGunKaydet', 'hgEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  doc.__setEl('hg-gun', { value: '7' });
  doc.__setEl('hg-hastalik', { value: 'd1' });
  doc.__setEl('hg-hastalik-ad', { value: 'İnaktif Ovaryum' });
  doc.__setEl('hg-tarih', { value: '2026-10-13' });
  doc.__setEl('hg-tai-chip', { getAttribute: () => '2026-10-15' });
  doc.__setEl('hg-vit-doz', { value: '' });
  doc.__setEl('hg-ilac-liste', { children: [] });
  doc.__setEl('hastalik-modal', { remove() {} });
  const pulls = [];
  const toasts = [];
  let cagri = 0;
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    rpc: async () => ({ ok: true, gun_id: 'gun-hata', mevcut: false, ertelenen: 1, ilac: 0 }),
    // Hizli faz treatment_days'i CEKEMEZ: failed ile cozulur (gercek
    // pullTables kontrati — tablo hatasi reject ETMEZ).
    pullTables: async (t) => {
      cagri += 1;
      pulls.push((t || []).slice());
      if (cagri === 1) return { ok: [], failed: ['treatment_days', 'drug_administrations'] };
      return { ok: (t || []).slice(), failed: [] };
    },
    renderSafe: () => {},
    RPC_TABLES: { ovsync_hastalik_gunu_ekle: ['cases', 'treatment_days', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log', 'islem_log'] },
    idbGetAll: async () => [],
    renderCaseTimeline: async () => {},
    loadDash: () => {},
    _curCase: { id: 'v-ana' },
    dFwd: (iso, n) => { const d = new Date(iso + 'T00:00:00'); d.setDate(d.getDate() + n); const p = (x) => String(x).padStart(2, '0'); return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); },
    _pgKapiHata: () => false, _ertelemeOfflineGuard: () => false,
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'hizli-hata-ctx' });
  return { ctx, pulls, toasts };
}

test('k10-hizli-faz-hata-toast', async () => {
  const t = hataCtx();
  await vm.runInContext(`hastalikGunKaydet('v-ana')`, t.ctx);
  const basari = t.toasts.filter(m => m.includes('günü açıldı') || m.includes('✅'));
  assert.strictEqual(basari.length, 0, 'hizli faz dustuyse basari toastu YOK, olculen: ' + JSON.stringify(t.toasts));
  const hata = t.toasts.filter(m => /kaydedildi/i.test(m) && /yenilenemedi/i.test(m));
  assert.ok(hata.length >= 1, 'hata toastu ("kaydedildi, ekran yenilenemedi — yenile"), olculen: ' + JSON.stringify(t.toasts));
  assert.ok(t.pulls.length >= 2, 'ikinci faz kostu, olculen pullar: ' + JSON.stringify(t.pulls));
  const ikinci = t.pulls.slice(1).flat();
  assert.ok(ikinci.includes('treatment_days'), 'ikinci faz treatment_days yeniden dene, olculen: ' + JSON.stringify(t.pulls));
});
