// tests/unit/hayvan-takip-vaka.test.js — Hayvan Takip F5: elle tek hayvanlık vakadan sonra açık takipleri soran pencere.
// Spec §5.5, §6; domain-rules §20.5. forms.js ve closeM gerçektir; rpc, pull, kart, vaka detayı ve htVakaSonrasi sahtedir.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { loadBrowserModule, makeDomStub, makeElement, extractFunctionSource } = require('./support/loadModule.js');
const { getDisplayKupe, bugun } = require('../../js/utils/helpers.js');

const REPO_ROOT = path.join(__dirname, '..', '..');
const DIZI = ['openCaseDet başladı', 'openCaseDet bitti', 'htVakaSonrasi'];
const TAKIP_HATA = 'TAKIP_ACIK:{"muayene_tarihi":"2026-10-20"}';

// openCaseDet modalı await'lerden sonra açar (js/ui.js); sahte de gecikmeli çözülür.
function sahne({ takipAcik = false, openCaseRed = false, htRed = false, createHata = null, caseId = 'C-9', kizginlikId = null } = {}) {
  const rec = { olay: [], rpc: [], toast: [], ht: [], takipHata: 0, retry: null };
  const document = makeDomStub();
  const input = (id, val) => { const el = makeElement('input'); el.value = val; document.__setEl(id, el); };
  const formDoldur = () => { input('d-hid', '12345'); input('d-disease-id', 'DS-1'); };
  formDoldur();
  document.__setEl('d-disease-cat', makeElement('div'));
  let ilkCreate = true;

  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: {
      g: id => document.getElementById(id),
      v: id => { const el = document.getElementById(id); return (el && el.value) || ''; },
      cl: id => { const el = document.getElementById(id); if (el) el.value = ''; },
      esc: s => String(s || ''),
      getState: () => [],
      setState: () => {},
      toast: (m, h) => { rec.toast.push([m, !!h]); },
      getUserMessage: e => 'JENERIK:' + (e?.message || String(e)),
      rpc: async (ad, p) => {
        rec.rpc.push({ ad, p: JSON.parse(JSON.stringify(p)) });
        rec.olay.push('rpc:' + ad);
        if (ad === 'create_case') {
          if (ilkCreate && takipAcik) { ilkCreate = false; throw new Error(TAKIP_HATA); }
          if (createHata) throw new Error(createHata);
        }
        return { ok: true, case_id: caseId };
      },
      pullTables: async () => ({ ok: true, failed: [] }),
      history: { state: null, back() {} },
      openDet: async () => { rec.olay.push('openDet'); },
      openCaseDet: async id => {
        rec.olay.push('openCaseDet başladı');
        rec.acilanVaka = id;
        await new Promise(r => setTimeout(r, 5));
        if (openCaseRed) { rec.olay.push('openCaseDet reddetti'); throw new Error('detay açılamadı'); }
        rec.olay.push('openCaseDet bitti');
      },
      htVakaSonrasi: async (hayvanId, vakaId) => {
        rec.olay.push('htVakaSonrasi');
        rec.ht.push([hayvanId, vakaId]);
        if (htRed) throw new Error('idb okunamadı');
      },
      _takipAcikHata: (e, retry) => {
        if (!/^TAKIP_ACIK:/.test(e?.message || '')) return false;
        rec.takipHata++;
        rec.olay.push('_takipAcikHata');
        rec.retry = retry;
        return true;
      },
      _detAcik: () => false,
      hayvanByKupeRef: hid => (hid === '12345' ? { id: 'H-1', kupe_no: '12345' } : null),
      loadDrugsCache: async () => {},
      getDisplayKupe,
      bugun,
      idbGetAll: async () => [],
      db: {},
    },
  });
  sandbox.navigator.onLine = true;
  sandbox._kizginlikTedaviId = kizginlikId;
  vm.runInContext(extractFunctionSource('js/utils/modal.js', 'closeM'), sandbox);
  return { sandbox, rec, formDoldur };
}

const hataToastlari = rec => rec.toast.filter(([, hata]) => hata).map(([m]) => m);
const sonuc = (rec, ...adlar) => rec.olay.filter(o => adlar.includes(o));
const createSayisi = rec => rec.rpc.filter(r => r.ad === 'create_case').length;

test('HT-V-01: başarı kolu openCaseDet bitmeden pencere açılmaz, bir kez sorulur', async () => {
  const { sandbox, rec } = sahne();
  await sandbox.submitCase(null);
  assert.deepStrictEqual(sonuc(rec, ...DIZI), DIZI);
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']]);
  assert.strictEqual(rec.acilanVaka, 'C-9');
  assert.deepStrictEqual(hataToastlari(rec), []);
});

test('HT-V-02: caseTakipRetry kolu aynı sırada, kendi vakasıyla sorar', async () => {
  const { sandbox, rec } = sahne({ takipAcik: true, caseId: 'C-R' });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(sonuc(rec, ...DIZI), [], 'onaydan önce vaka detayı ve pencere yok');
  const donen = await rec.retry(false);
  assert.strictEqual(donen.case_id, 'C-R', 'retry res2 döndürmeye devam eder');
  assert.deepStrictEqual(sonuc(rec, ...DIZI), DIZI);
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-R']]);
  assert.strictEqual(rec.acilanVaka, 'C-R');
});

test('HT-V-03: htVakaSonrasi reddederse vaka toast\'u korunur, tek uyarı çıkar, istisna dışarı çıkmaz', async () => {
  const { sandbox, rec } = sahne({ htRed: true });
  await assert.doesNotReject(sandbox.submitCase(null));
  assert.ok(rec.toast.some(([m, h]) => m === '✅ Vaka açıldı' && !h), 'vaka toast\'u');
  assert.deepStrictEqual(hataToastlari(rec), ['⚠️ Vaka kayıtlı, takip penceresi açılamadı']);
  assert.strictEqual(rec.takipHata, 0);
  assert.strictEqual(createSayisi(rec), 1);
});

test('HT-V-03b: caseTakipRetry kolunda da pencere hatası retry\'ı reddettirmez', async () => {
  const { sandbox, rec } = sahne({ takipAcik: true, htRed: true });
  await sandbox.submitCase(null);
  const donen = await rec.retry(false);
  assert.strictEqual(donen.case_id, 'C-9');
  assert.deepStrictEqual(hataToastlari(rec), ['⚠️ Vaka kayıtlı, takip penceresi açılamadı']);
  assert.strictEqual(createSayisi(rec), 2);
});

test('HT-V-06: başarı kolunda openCaseDet reddederse hata toast\'u yok, pencere yine bir kez', async () => {
  const { sandbox, rec } = sahne({ openCaseRed: true });
  await assert.doesNotReject(sandbox.submitCase(null));
  assert.deepStrictEqual(hataToastlari(rec), []);
  assert.strictEqual(rec.takipHata, 0, '_takipAcikHata çağrılmaz');
  assert.strictEqual(createSayisi(rec), 1, 'create_case yeniden çağrılmaz');
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']]);
  assert.deepStrictEqual(sonuc(rec, 'openCaseDet reddetti', 'htVakaSonrasi'), ['openCaseDet reddetti', 'htVakaSonrasi']);
});

test('HT-V-06b: caseTakipRetry kolunda openCaseDet reddederse retry çözülür, ikinci vaka açılmaz, pencere bir kez', async () => {
  const { sandbox, rec } = sahne({ takipAcik: true, openCaseRed: true });
  await sandbox.submitCase(null);
  const donen = await rec.retry(false);
  assert.strictEqual(donen.case_id, 'C-9');
  assert.deepStrictEqual(hataToastlari(rec), []);
  assert.strictEqual(rec.takipHata, 1, 'yalnız ilk TAKIP_ACIK için');
  assert.strictEqual(createSayisi(rec), 2, 'ilk red + tek onaylı çağrı');
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']]);
});

test('HT-V-04: TAKIP_ACIK onayı vaka öncesinde kalır; retry onaydan sonra çalışır', async () => {
  const { sandbox, rec } = sahne({ takipAcik: true });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(rec.olay, ['rpc:create_case', '_takipAcikHata'], 'onay öncesi başka adım yok');
  assert.strictEqual(rec.rpc[0].p.p_takip_onay, undefined, 'ilk çağrı onaysız');
  assert.deepStrictEqual(rec.ht, []);
  await rec.retry(false);
  assert.strictEqual(rec.rpc[1].p.p_takip_onay, true, 'ikinci çağrı onaylı');
  const sira = rec.olay.indexOf('_takipAcikHata');
  assert.ok(sira < rec.olay.lastIndexOf('rpc:create_case'), 'onaylı create_case onaydan sonra');
  assert.ok(rec.olay.lastIndexOf('rpc:create_case') < rec.olay.indexOf('openDet'), 'kart vakadan sonra');
  assert.ok(rec.olay.indexOf('openDet') < rec.olay.indexOf('openCaseDet başladı'), 'detay karttan sonra');
});

test('HT-V-05: toplu, kızgınlık ve otomatik yollar pencere açmaz; tek giriş submitCase', () => {
  const toplu = extractFunctionSource('js/forms.js', 'submitBulkCase');
  const gonderIdx = toplu.indexOf('const gonder = async');
  assert.ok(gonderIdx > 0, 'gonder gövdesi submitBulkCase içinde bulunmalı');
  const govdeler = {
    submitBulkCase: toplu,
    gonder: toplu.slice(gonderIdx),
    sorunVakaAc: extractFunctionSource('js/ui.js', 'sorunVakaAc'),
    submitKizginlik: extractFunctionSource('js/forms.js', 'submitKizginlik'),
    kizginlikTedaviAc: extractFunctionSource('js/ui.js', 'kizginlikTedaviAc'),
  };
  assert.ok(govdeler.gonder.includes("rpc('vaka_toplu_ac'"), 'tarama doğru gövdede');
  assert.ok(govdeler.sorunVakaAc.includes("rpc('kizginlik_vaka_ac'"), 'tarama doğru gövdede');
  for (const [ad, g] of Object.entries(govdeler)) {
    assert.ok(!/htVakaSonrasi|_vakaSonrasiAkis|htKapatPencere/.test(g), ad + ' pencere açmamalı');
  }
  // Otomatik yol: js/ altında htVakaSonrasi'nin tek çağıranı sarmal, sarmalın tek çağıranı submitCase.
  const js = path.join(REPO_ROOT, 'js');
  const dosyalar = fs.readdirSync(js, { recursive: true }).filter(f => f.endsWith('.js') && !f.startsWith('_archive'));
  const say = re => dosyalar.reduce((t, f) => t + (fs.readFileSync(path.join(js, f), 'utf8').match(re) || []).length, 0);
  assert.strictEqual(say(/\bhtVakaSonrasi\(/g), 2, 'tanım + _htVakaSonrasiGuvenli');
  assert.strictEqual(say(/\b_vakaSonrasiAkis\(/g), 3, 'tanım + submitCase iki kolu');
  assert.strictEqual((extractFunctionSource('js/forms.js', 'submitCase').match(/_vakaSonrasiAkis\(/g) || []).length, 2);
});

test('HT-V-07: vaka açılmadıysa pencere yok', async () => {
  const red = sahne({ createHata: 'BASKA_HATA' });
  await red.sandbox.submitCase(null);
  assert.deepStrictEqual(hataToastlari(red.rec), ['JENERIK:BASKA_HATA']);
  assert.deepStrictEqual(red.rec.ht, []);

  const kimliksiz = sahne({ caseId: null });
  await kimliksiz.sandbox.submitCase(null);
  assert.deepStrictEqual(kimliksiz.rec.ht, []);
  assert.deepStrictEqual(sonuc(kimliksiz.rec, ...DIZI), []);
});

test('HT-V-06c: caseTakipRetry kolunda detay ve pencere birlikte reddederse retry yine çözülür, ikinci vaka açılmaz', async () => {
  const { sandbox, rec } = sahne({ takipAcik: true, openCaseRed: true, htRed: true });
  await sandbox.submitCase(null);
  await assert.doesNotReject(rec.retry(false));
  assert.strictEqual(createSayisi(rec), 2);
});

const baglantilar = rec => rec.rpc.filter(r => r.ad === 'kizginlik_tedavi_baglanti_kur').map(r => r.p);

test('HT-V-08: kızgınlık Tedavi yolu pencere açmaz; bağlantı, kapanıştan sonra da kurulur; sonraki elle vaka sorar', async () => {
  const { sandbox, rec, formDoldur } = sahne({ kizginlikId: 'K-1' });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(rec.ht, []);
  assert.deepStrictEqual(sonuc(rec, ...DIZI), DIZI.slice(0, 2));
  assert.deepStrictEqual(baglantilar(rec), [{ p_kayit_id: 'K-1', p_case_id: 'C-9' }]);
  assert.strictEqual(sandbox._kizginlikTedaviId, null);
  assert.deepStrictEqual(hataToastlari(rec), []);

  formDoldur();
  await sandbox.submitCase(null);
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']], 'sonraki elle vaka sorar');
  assert.strictEqual(baglantilar(rec).length, 1, 'elle vaka eski kayda bağlanmaz');
});

test('HT-V-08b: onaylı kızgınlık vakası pencere açmaz, bağlantı kurmaz (mevcut); sonraki elle vaka sorar', async () => {
  const { sandbox, rec, formDoldur } = sahne({ takipAcik: true, kizginlikId: 'K-1' });
  await sandbox.submitCase(null);
  assert.strictEqual(sandbox._kizginlikTedaviId, 'K-1', 'onay beklerken form açık, işaret durur');
  await rec.retry(false);
  assert.deepStrictEqual(rec.ht, []);
  assert.deepStrictEqual(sonuc(rec, ...DIZI), DIZI.slice(0, 2));
  assert.deepStrictEqual(baglantilar(rec), []);
  assert.strictEqual(sandbox._kizginlikTedaviId, null);

  formDoldur();
  await sandbox.submitCase(null);
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']]);
  assert.deepStrictEqual(baglantilar(rec), []);
});

test('HT-V-08c: Tedavi formu X/backdrop ile kapanınca işaret silinir, elle yeni vaka sorar ve bağlanmaz', async () => {
  const { sandbox, rec } = sahne({ kizginlikId: 'K-1' });
  sandbox.closeM('m-disease');
  assert.strictEqual(sandbox._kizginlikTedaviId, null);
  await sandbox.submitCase(null);
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']]);
  assert.deepStrictEqual(baglantilar(rec), []);
});

test('HT-V-08d: başka pencere kapanması ve başarısız kayıt işareti silmez; düzeltilen kayıt kızgınlık sayılır', async () => {
  const { sandbox, rec } = sahne({ kizginlikId: 'K-1', createHata: 'BASKA_HATA' });
  sandbox.closeM('m-insem-degil');
  assert.strictEqual(sandbox._kizginlikTedaviId, 'K-1');
  await sandbox.submitCase(null);
  assert.strictEqual(sandbox._kizginlikTedaviId, 'K-1', 'form açık, işaret durur');

  const ikinci = sahne({ kizginlikId: 'K-1' });
  await ikinci.sandbox.submitCase(null);
  assert.deepStrictEqual(ikinci.rec.ht, []);
  assert.deepStrictEqual(rec.ht, []);
});
