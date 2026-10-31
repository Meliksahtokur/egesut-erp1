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
function sahne({ takipAcik = false, openCaseRed = false, htRed = false, createHata = null, caseId = 'C-9', kizginlikId = null, muayene = null, bagHata = null, sablonId = null, sablonHata = null, pgKapi = false, pullRed = false, openDetRed = false } = {}) {
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
        if (ad === 'hayvan_takip_muayene_vaka' && bagHata) throw new Error(bagHata);
        if (ad === 'tedavi_sablon_uygula' && sablonHata) throw new Error(sablonHata);
        return { ok: true, case_id: caseId };
      },
      pullTables: async () => { if (pullRed) { rec.olay.push('pull reddetti'); throw new Error('pull'); } return { ok: true, failed: [] }; },
      history: { state: null, back() {} },
      openDet: async () => { rec.olay.push('openDet'); if (openDetRed) throw new Error('kart'); },
      _pgKapiHata: pgKapi ? (e, cagri) => { rec.pgKapi = cagri; return /^PG_KAPI:/.test(e.message); } : undefined,
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
      _htTazele: async () => { rec.olay.push('tazele'); },
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
  sandbox._htMuayeneVaka = muayene;
  sandbox._seciliSablonId = sablonId;
  vm.runInContext(extractFunctionSource('js/utils/modal.js', 'closeM'), sandbox);
  vm.runInContext(extractFunctionSource('js/hayvan-takip-pencere.js', 'htMuayeneVakaBagla'), sandbox);
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

// ── Muayeneden vakaya bağ (Yol A) ────────────────────────────
const MUAYENE = { gorevId: 'g1', hayvanId: 'H-1', not: 'şişlik' };
const BAG = 'rpc:hayvan_takip_muayene_vaka';
const BAG_DIZI = ['openCaseDet başladı', 'openCaseDet bitti', BAG, 'htVakaSonrasi'];
const baglar = rec => rec.rpc.filter(r => r.ad === 'hayvan_takip_muayene_vaka').map(r => r.p);

test('HT-V-10: bağlam yalnız m-disease kapanışıyla düşer', () => {
  const { sandbox } = sahne({ muayene: MUAYENE });
  sandbox.closeM('m-ht-sonuc');
  sandbox.closeM('m-insem-degil');
  assert.strictEqual(sandbox._htMuayeneVaka, MUAYENE);
  sandbox.closeM('m-disease');
  assert.strictEqual(sandbox._htMuayeneVaka, null);
});

test('HT-V-11: form başka hayvana çevrildiyse vaka açılmaz, bağlam ve düğme kalır', async () => {
  const { sandbox, rec } = sahne({ muayene: { ...MUAYENE, hayvanId: 'H-BASKA' } });
  const btn = makeElement('button');
  await sandbox.submitCase(btn);
  assert.strictEqual(createSayisi(rec), 0);
  assert.deepStrictEqual(baglar(rec), []);
  assert.deepStrictEqual(hataToastlari(rec), ['⚠️ Bu vaka muayene edilen hayvana açılmalı']);
  assert.ok(sandbox._htMuayeneVaka, 'form açık, bağlam durur');
  assert.notStrictEqual(btn.disabled, true);
});

test('HT-V-12: başarı kolunda bağ detaydan sonra, sorudan önce; bağlam kapanışta düşer, sonraki elle vaka bağlanmaz', async () => {
  const { sandbox, rec, formDoldur } = sahne({ muayene: MUAYENE });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(sonuc(rec, ...BAG_DIZI), BAG_DIZI);
  assert.deepStrictEqual(baglar(rec), [{ p_gorev_id: 'g1', p_case_id: 'C-9', p_not: 'şişlik' }]);
  assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']]);
  assert.strictEqual(sandbox._htMuayeneVaka, null);
  assert.deepStrictEqual(hataToastlari(rec), []);
  formDoldur();
  await sandbox.submitCase(null);
  assert.strictEqual(baglar(rec).length, 1, 'ikinci vaka bağlanmaz');
});

test('HT-V-13: caseTakipRetry kolu aynı noktadan bağlar; onaydan önce bağ yok, kapanış bağlamı düşürse de korunur', async () => {
  const { sandbox, rec } = sahne({ muayene: MUAYENE, takipAcik: true, caseId: 'C-R' });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(baglar(rec), []);
  assert.ok(sandbox._htMuayeneVaka, 'onay beklerken form açık');
  const donen = await rec.retry(false);
  assert.strictEqual(donen.case_id, 'C-R');
  assert.deepStrictEqual(sonuc(rec, ...BAG_DIZI), BAG_DIZI);
  assert.deepStrictEqual(baglar(rec), [{ p_gorev_id: 'g1', p_case_id: 'C-R', p_not: 'şişlik' }]);
  assert.strictEqual(sandbox._htMuayeneVaka, null);
});

for (const takipAcik of [false, true]) {
  test(`HT-V-14 (${takipAcik ? 'retry' : 'başarı'}): bağ hatası toast verir, akış sürer: soru yine sorulur, vaka ikinci kez açılmaz`, async () => {
    const { sandbox, rec } = sahne({ muayene: MUAYENE, takipAcik, bagHata: 'HT_VAKA_UYUMSUZ' });
    await assert.doesNotReject(sandbox.submitCase(null));
    if (takipAcik) await assert.doesNotReject(rec.retry(false));
    assert.deepStrictEqual(hataToastlari(rec), ['⚠️ Vaka kayıtlı, takip bağlanamadı']);
    assert.deepStrictEqual(sonuc(rec, BAG, 'htVakaSonrasi'), [BAG, 'htVakaSonrasi']);
    assert.strictEqual(createSayisi(rec), takipAcik ? 2 : 1);
    assert.deepStrictEqual(rec.ht, [['H-1', 'C-9']]);
  });
}

test('HT-V-15: bayat kapalı görevde bağ hata göstermez, tazeler, akış sürer', async () => {
  const { sandbox, rec } = sahne({ muayene: MUAYENE, bagHata: 'HT_GOREV_KAPALI' });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(hataToastlari(rec), []);
  assert.deepStrictEqual(sonuc(rec, BAG, 'tazele', 'htVakaSonrasi'), [BAG, 'tazele', 'htVakaSonrasi']);
});

test('HT-V-16: kızgınlık kolu bağlam taşımaz: işaret varken eski bağlam bağlanmaz, pencere de açılmaz', async () => {
  const { sandbox, rec } = sahne({ muayene: MUAYENE, kizginlikId: 'K-1' });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(baglar(rec), []);
  assert.deepStrictEqual(rec.ht, []);
  assert.strictEqual(baglantilar(rec).length, 1);
});

test('HT-V-17: vaka hatasında hiçbir şey yazılmaz, görev açık kalır, bağlam durur; vazgeçince düşer', async () => {
  const { sandbox, rec } = sahne({ muayene: MUAYENE, createHata: 'Zaten aktif' });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(baglar(rec), []);
  assert.deepStrictEqual(rec.ht, []);
  assert.ok(sandbox._htMuayeneVaka);
  sandbox.closeM('m-disease');
  assert.strictEqual(sandbox._htMuayeneVaka, null);
});

test('HT-V-18: elle vakada bağlam yok, bağ RPC\'si çağrılmaz (mevcut akış aynı)', async () => {
  const { sandbox, rec } = sahne();
  await sandbox.submitCase(null);
  assert.deepStrictEqual(baglar(rec), []);
  assert.deepStrictEqual(sonuc(rec, ...DIZI), DIZI);
  assert.deepStrictEqual(rec.toast, [['✅ Vaka açıldı', false]]);
});

test('HT-V-19: detay hatası bağı kesmez: vaka kayıtlı, bağ kurulur', async () => {
  const det = sahne({ muayene: MUAYENE, openCaseRed: true });
  await det.sandbox.submitCase(null);
  assert.deepStrictEqual(sonuc(det.rec, 'openCaseDet reddetti', BAG, 'htVakaSonrasi'), ['openCaseDet reddetti', BAG, 'htVakaSonrasi']);
});

test('HT-V-20: vaka kimliği yoksa bağ yok', async () => {
  const { sandbox, rec } = sahne({ muayene: MUAYENE, caseId: null });
  await sandbox.submitCase(null);
  assert.deepStrictEqual(baglar(rec), []);
});

// ── Vaka kayıtlıyken ara hatalar (U2 kapı turu) ──────────────
const KOLLAR = [['başarı', false], ['retry', true]];
const kos = async (o, takipAcik) => {
  const k = sahne({ muayene: MUAYENE, takipAcik, ...o });
  await assert.doesNotReject(k.sandbox.submitCase(null));
  if (takipAcik) await assert.doesNotReject(k.rec.retry(false));
  return k;
};

for (const [ad, takipAcik] of KOLLAR) {
  test(`HT-V-21 (${ad}): şablon reddi kayıtlı vakayı bozmaz: uyarı çıkar, form kapanır, bağ ve soru koşar, ikinci basış ikinci vaka açmaz`, async () => {
    const { sandbox, rec } = await kos({ sablonId: 'S-1', sablonHata: 'stok yok', pgKapi: true }, takipAcik);
    assert.deepStrictEqual(hataToastlari(rec), ['Vaka açıldı ama şablon uygulanamadı: stok yok']);
    assert.deepStrictEqual(sonuc(rec, ...BAG_DIZI), BAG_DIZI);
    assert.strictEqual(sandbox._seciliSablonId, null);
    assert.strictEqual(sandbox._htMuayeneVaka, null, 'form kapandı');
    const sayi = createSayisi(rec);
    await sandbox.submitCase(null);
    assert.strictEqual(createSayisi(rec), sayi, 'ikinci vaka yok');
  });

  test(`HT-V-22 (${ad}): PG kapısı reddi kapı ekranına gider; onaylı tekrar aynı vaka ve şablonla gider, bağ ve soru koşar`, async () => {
    const { rec } = await kos({ sablonId: 'S-1', sablonHata: 'PG_KAPI:REQUIRE_ACK_PENDING:{}', pgKapi: true }, takipAcik);
    assert.deepStrictEqual(hataToastlari(rec), []);
    assert.deepStrictEqual(sonuc(rec, BAG, 'htVakaSonrasi'), [BAG, 'htVakaSonrasi']);
    rec.rpc.length = 0;
    await rec.pgKapi(true, 'gerekçe').catch(() => {});
    assert.deepStrictEqual(rec.rpc, [{ ad: 'tedavi_sablon_uygula', p: { p_case_id: 'C-9', p_sablon_id: 'S-1', p_pg_onay: true, p_pg_gerekce: 'gerekçe' } }]);
  });
}
