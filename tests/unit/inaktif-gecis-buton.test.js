// tests/unit/inaktif-gecis-buton.test.js
// Faz 2b + F turu (KAPI-1 bloklayan, KAPI-4 mockup M1/M2/M3).
'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const vm = require('node:vm');
const { extractFunctionSource, loadExtractedFunction, makeDomStub } = require('./support/loadModule.js');

const sheet = (secenek) => loadExtractedFunction('js/ui.js', 'inaktifGecisSheetHtml',
  { extra: { escAttr: String, esc: String } })('v-ana', secenek);

const INAKTIF = { hastaliklar: [{ id: 'd1', name: 'İnaktif Ovaryum' }, { id: 'd2', name: 'Kistik Over' }], vitaminStok: { id: 's1', urun_adi: 'CAROFERTIN-E' } };

test('inaktif-gecis-buton-gun-sorusu', () => {
  const html = sheet({ ...INAKTIF, kupeNo: '31', taiEski: '2026-10-07' });
  assert.match(html, /id="ig-gun"[^>]*value="7"/, 'gün sorusu, varsayılan 7 (karar 5)');
  assert.match(html, /id="ig-vit-doz"[^>]*value="20"/, 'CAROFERTIN-E 20 ml ön-dolu (karar 7)');
  assert.ok(html.includes('İnaktif Ovaryum') && html.includes('CAROFERTIN-E'), 'karar 6-7 seçenekleri');
  assert.ok(html.includes('İnaktif Ovaryum — Küpe 31'), 'M2 başlığı (M no: M2)');
  const kaydet = extractFunctionSource('js/ui.js', 'inaktifGecisKaydet');
  assert.ok(kaydet.includes("rpc('inaktif_alt_vaka_ac'") && kaydet.includes('p_gun'), 'aç-RPC p_gun ile');
  assert.ok(!kaydet.includes('vaka_kalan_gunleri_kaydir'), 'kaydır RPC çağrılmaz');
});

// F turu KAPI-1 (BLOKLAYAN, M3): kist seçiminde ilaç BOŞ başlar.
test('kist-ilac-bos-baslar', () => {
  const html = sheet({ hastalik: { id: 'd2', name: 'Kistik Over' }, kupeNo: '31', taiEski: '2026-10-07', vitaminStok: { id: 's1', urun_adi: 'CAROFERTIN-E' } });
  assert.ok(html.includes('Kist — Küpe 31'), 'M3 başlığı');
  assert.ok(html.includes('İLAÇ (BOŞ BAŞLAR, EKLENEBİLİR)'), 'M3 ilaç başlığı');
  assert.ok(html.includes('Henüz ilaç yok'), 'M3 boş ilaç metni');
  assert.ok(html.includes('+ İlaç ekle'), 'M3 ekle düğmesi');
  assert.ok(!html.includes('id="ig-vit-doz"'), 'kistte ön-dolu doz YOK');
  const inaktif = sheet({ ...INAKTIF, kupeNo: '31', taiEski: '2026-10-07' });
  assert.ok(inaktif.includes('İLAÇ (ÖN-DOLU, DEĞİŞTİRİLEBİLİR)'), 'M2 ilaç başlığı');
  assert.match(inaktif, /id="ig-vit-doz"[^>]*value="20"/, 'inaktifte CAROFERTIN-E 20 ml ön-dolu KALIR (M2)');
});

// F turu KAPI-1 davranış: boşken RPC'ye vitamin parametresi gitmez.
function kaydetCtx(els, rpcCagrilari) {
  const govde = ['inaktifGecisKaydet', 'vitaminStokIdBul']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  for (const [id, el] of Object.entries(els)) doc.__setEl(id, el);
  const pulls = [];
  const toasts = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    rpc: async (ad, p) => { rpcCagrilari.push({ ad, p }); return { ok: true }; },
    pullTables: async (t) => { pulls.push(t); return { ok: [], failed: [] }; },
    renderSafe: () => {},
    RPC_TABLES: { inaktif_alt_vaka_ac: ['cases', 'treatment_days'] },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'kaydet-ctx' });
  return { ctx, pulls, toasts };
}

test('kist-kaydet-vitaminsiz-rpc', async () => {
  // Kist + ek ilaç yok: doz satırı DOM'da yok → vitamin anahtarları YOK.
  const rpcCagrilari = [];
  const { ctx } = kaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd2' },
    'inaktif-gecis-modal': { remove() {} },
  }, rpcCagrilari);
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, ctx);
  assert.strictEqual(rpcCagrilari.length, 1, 'tek RPC');
  const p = rpcCagrilari[0].p;
  assert.ok(!('p_vitamin_doz_ml' in p),
    'p_vitamin_doz_ml YOK (katı), ölçülen: ' + JSON.stringify(p));
  assert.ok(!('p_vitamin_stok_id' in p),
    'p_vitamin_stok_id YOK (katı), ölçülen: ' + JSON.stringify(p));
  // İnaktif: doz satırı var → 20 ml + stok gider (M2 ön-dolu korunur).
  const rpc2 = [];
  const t2 = kaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd1' },
    'ig-vit-doz': { value: '20' },
    'ig-vit-stok': { value: 's1' },
    'inaktif-gecis-modal': { remove() {} },
  }, rpc2);
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t2.ctx);
  assert.strictEqual(rpc2[0].p.p_vitamin_doz_ml, 20, 'inaktifte doz 20 gider');
  assert.strictEqual(rpc2[0].p.p_vitamin_stok_id, 's1', 'inaktifte stok gider');
});

// F turu KAPI-4: mockup M1/M2/M3 birebir metin kilitleri.
test('inaktif-sheet-mockup-kilitleri', () => {
  const m2 = sheet({ ...INAKTIF, kupeNo: '31', taiEski: '2026-10-07' });
  for (const [metin, mno] of [
    ['HASTALIK (SABİT)', 'M2'], ['KAÇ GÜN ERTELENSİN?', 'M2'],
    ['TAI 10-07 → 10-14', 'M2'], ['+ İlaç ekle', 'M2'],
    ['5. gün PG elle girilebilir (opsiyonel) · Ovsync kapanmaz, tohumlamaya bağlanır', 'M2/M3'],
    ['Kaydet', 'M2/M3'], ['Vazgeç', 'M2/M3'],
  ]) assert.ok(m2.includes(metin), mno + ': ' + metin);
  assert.ok(!m2.includes('Alt Vakayı Aç'), 'düğme mockup adıyla Kaydet (M2)');
  assert.ok(!m2.includes('<select'), 'hastalık select YOK — sabit (M2)');
  const m3 = sheet({ hastalik: { id: 'd2', name: 'Kistik Over' }, kupeNo: '31', taiEski: '2026-10-07', vitaminStok: { id: 's1', urun_adi: 'CAROFERTIN-E' } });
  assert.ok(m3.includes('HASTALIK (SABİT)') && m3.includes('Kistik Over'), 'M3 sabit hastalık');
  // ROOT RULING 1: yeni HTML'de zemin yazımı yok (p7 kilidiyle aynı dil).
  for (const [html, mno] of [[m2, 'M2'], [m3, 'M3']]) {
    const izinli = html.replace(/background:var\(--/g, '');
    assert.ok(!/background/.test(izinli), mno + ': yasak background yazımı');
    // KAPI K7: Kaydet yeşili + beyaz yazı mockup ile aynı — color:#fff metin serbest, zemin kilitlenir.
    for (const pat of [/white/, /krem/, /#f5e/, /#faf/]) assert.ok(!pat.test(html), mno + ': yasak yazım ' + pat);
  }
  // M1: S1 kartında iki seçenek kartı (tek buton yerine).
  const s1 = extractFunctionSource('js/ui.js', '_ovsyncS1SatirHtml');
  for (const [metin, mno] of [
    ['MUAYENEDE SORUN VARSA ALT VAKA AÇ', 'M1'], ['İnaktif Ovaryum', 'M1'],
    ['Vitamin desteği + erteleme · Ovsync devam eder', 'M1'], ['Kist', 'M1'],
    ['Kist tedavisi alt vaka olarak bağlanır', 'M1'],
  ]) assert.ok(s1.includes(metin), mno + ': ' + metin);
});

// F2 KAPI-2 madde 3: kist algılaması ad-soyad değil seçimden; Kistik Over kaydı
// bulunamazsa sessiz inaktif yedeği YOK → açık hata toast + sheet açılmaz (fail-closed).
// Adli mutant: MUT-B (seçim ters — kist isteyene inaktif sheet) → FAIL.
function inaktifAcCtx(diseases) {
  const govde = ['inaktifGecisSheetHtml', 'inaktifGecisAc']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  const toasts = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    idbGetAll: async (t) => (t === 'diseases' ? diseases : []),
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'inaktif-ac-ctx' });
  return { ctx, doc, toasts };
}
const acikSheetVarMi = (doc) => doc.body.children.some(e => e && e.id === 'inaktif-gecis-modal');

test('kist-secimi-fail-closed', async () => {
  // Kistik Over IDB'de YOK + secim kist → sheet YOK + açık hata toast.
  {
    const t = inaktifAcCtx([{ id: 'd1', name: 'İnaktif Ovaryum' }]);
    await vm.runInContext(`inaktifGecisAc('v-ana',{secim:'kist',kupeNo:'31',taiEski:'2026-10-07'})`, t.ctx);
    assert.strictEqual(acikSheetVarMi(t.doc), false, 'Kistik Over yoksa sheet açılmaz (fail-closed)');
    assert.ok(t.toasts.some(m => /Kistik Over/i.test(m) && /bulunamad/i.test(m)),
      'açık hata toast, ölçülen: ' + JSON.stringify(t.toasts));
  }
  // Kistik Over VARKEN secim kist → Kist sheet'i doğru hastalık id'siyle açılır.
  {
    const t = inaktifAcCtx([{ id: 'd1', name: 'İnaktif Ovaryum' }, { id: 'd2', name: 'Kistik Over' }]);
    await vm.runInContext(`inaktifGecisAc('v-ana',{secim:'kist',kupeNo:'31',taiEski:'2026-10-07'})`, t.ctx);
    assert.strictEqual(acikSheetVarMi(t.doc), true, 'kist kaydı varken sheet açılır');
    const box = t.doc.body.children.find(e => e && e.id === 'inaktif-gecis-modal');
    assert.ok(box.innerHTML.includes('Kist — Küpe 31'), 'M3 başlığı (seçimden)');
    assert.ok(box.innerHTML.includes('value="d2"'), 'Kistik Over id taşınır, ölçülen: ' + box.innerHTML.slice(0, 400));
  }
});

// F2 KAPI-2 madde 8: toast hastalığa göre ('Kist alt vakası açıldı' /
// 'İnaktif ovaryum alt vakası açıldı').
test('kaydet-toast-hastaliga-gore', async () => {
  const rpc1 = [];
  const t1 = kaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd2' },
    'ig-kist': { value: '1' },
    'inaktif-gecis-modal': { remove() {} },
  }, rpc1);
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t1.ctx);
  assert.ok(t1.toasts.some(m => /Kist alt vakası açıldı/.test(m)),
    'kist toast, ölçülen: ' + JSON.stringify(t1.toasts));
  const rpc2 = [];
  const t2 = kaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd1' },
    'ig-vit-doz': { value: '20' },
    'ig-vit-stok': { value: 's1' },
    'inaktif-gecis-modal': { remove() {} },
  }, rpc2);
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t2.ctx);
  assert.ok(t2.toasts.some(m => /İnaktif ovaryum alt vakası açıldı/.test(m)),
    'inaktif toast, ölçülen: ' + JSON.stringify(t2.toasts));
});

// F2 KAPI-2 madde 4: igGunDegisti canlı TAI önizlemesi — gün değişince önizleme
// güncellenir ('TAI <eski> → <yeni>'). Adli mutant: MUT-C (bir gün eksik) → FAIL.
test('ig-gun-degisti-tai-onizleme', () => {
  const govde = extractFunctionSource('js/ui.js', 'igGunDegisti');
  const doc = makeDomStub();
  const gun = { value: '14' };
  const chip = {
    textContent: '',
    getAttribute: (a) => (a === 'data-tai-eski' ? '2026-10-07' : null),
  };
  doc.__setEl('ig-gun', gun);
  doc.__setEl('ig-tai-chip', chip);
  const ctx = { console, JSON, Math, Date, document: doc };
  vm.createContext(ctx);
  vm.runInContext(govde + '\nigGunDegisti();', ctx, { filename: 'ig-gun-ctx' });
  assert.strictEqual(chip.textContent, 'TAI 10-07 → 10-21', '14 gün: 07→21');
  gun.value = '7';
  vm.runInContext('igGunDegisti();', ctx, { filename: 'ig-gun-ctx2' });
  assert.strictEqual(chip.textContent, 'TAI 10-07 → 10-14', 'gün değişince önizleme güncellenir');
  const chip2 = {
    textContent: '',
    getAttribute: () => null,
  };
  doc.__setEl('ig-tai-chip', chip2);
  vm.runInContext('igGunDegisti();', ctx, { filename: 'ig-gun-ctx3' });
  assert.strictEqual(chip2.textContent, '7 gün ertelenecek', 'eski tarih yoksa gün metni');
});

// F2 KAPI-2 madde 6: vaka detay düğmesi kist seçeneği sunar + taiEski geçirir
// (önizleme 'TAI <eski> → <yeni>'). Adli mutant: MUT-TAIESKI-YOK (taiEski
// geçirilmezse / kist düğmesi yoksa) → FAIL.
test('vaka-detay-kist-secenegi-tai', async () => {
  const govde = extractFunctionSource('js/ui.js', '_inaktifGecisBtnSync');
  const doc = makeDomStub();
  const { makeElement } = require('./support/loadModule.js');
  const parent = makeElement('div');
  const kaydir = makeElement('button');
  parent.appendChild(kaydir);
  doc.__setEl('cd-kaydir-btn', kaydir);
  const acislar = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    navigator: { onLine: true },
    _curCase: { id: 'v-ana', animal_id: 'H-31', status: 'active', protocol_family: 'OVSYNC', kaynak_vaka_id: null },
    idbGetAll: async (t) => (t === 'gorev_log'
      ? [{ id: 'g1', hayvan_id: 'H-31', gorev_tipi: 'TOHUMLAMA_PLANLI', hedef_tarih: '2026-10-20', hedef_saat: '10:00', tamamlandi: false, iptal: false }]
      : []),
    inaktifGecisAc: (vakaId, sec) => { acislar.push({ vakaId, sec }); },
    inaktifAltVakaDonus: () => {},
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'detay-btn-ctx' });
  await vm.runInContext('_inaktifGecisBtnSync()', ctx);
  // Stub byId kaydı yapmaz (createElement __setEl'den geçmez) — ebeveyn taranır.
  const bul = (id) => parent.children.find(e => e && e.id === id) || null;
  const inaktifBtn = bul('cd-inaktif-gecis-btn');
  const kistBtn = bul('cd-kist-gecis-btn');
  assert.ok(inaktifBtn, 'detayda inaktif düğmesi');
  assert.ok(kistBtn, 'detayda KİST düğmesi (madde 6)');
  assert.strictEqual(typeof inaktifBtn.onclick, 'function', 'inaktif tıklanabilir');
  assert.strictEqual(typeof kistBtn.onclick, 'function', 'kist tıklanabilir');
  assert.strictEqual(inaktifBtn.style.display, 'block', 'aktif OVSYNC detayı inaktif görünür');
  assert.strictEqual(kistBtn.style.display, 'block', 'aktif OVSYNC detayı kist görünür');
  inaktifBtn.onclick();
  kistBtn.onclick();
  assert.strictEqual(acislar.length, 2, 'iki düğme iki açılış');
  assert.strictEqual(acislar[0].sec.secim, 'inaktif', 'inaktif seçim taşınır');
  assert.strictEqual(acislar[1].sec.secim, 'kist', 'kist seçim taşınır');
  for (const a of acislar)
    assert.strictEqual(a.sec.taiEski, '2026-10-20', 'taiEski geçirilir (önizleme TAI eski → yeni): ' + JSON.stringify(a.sec));
});

// F2 KAPI-2 madde 7 (mockup yerleşim): M1 kartlarında radyo dairesi + alt metin
// ayrı satır; Kaydet/Vazgeç ALT ALTA (M2/M3); zemin mevcut stil.
test('mockup-m7-yerlesim', () => {
  const s1 = extractFunctionSource('js/ui.js', '_ovsyncS1SatirHtml');
  assert.ok(s1.includes('border-radius:100%'), 'M1 radyo dairesi stili (50% YASAK — eşik kilidi)');
  const radyoKullanim = (s1.match(/radyoDaire/g) || []).length;
  assert.ok(radyoKullanim >= 3, 'M1 iki kart radyo sabitini kullanır (tanım+2), ölçülen: ' + radyoKullanim);
  assert.ok(s1.includes('display:block'), 'M1 alt metin ayrı satır (display:block)');
  const m2 = sheet({ ...INAKTIF, kupeNo: '31', taiEski: '2026-10-07' });
  assert.ok(m2.includes('flex-direction:column'), 'M2/M3 Kaydet-Vazgeç alt alta');
  assert.ok(m2.includes('Kaydet') && m2.includes('Vazgeç'), 'iki düğme korunur');
  const m3 = sheet({ hastalik: { id: 'd2', name: 'Kistik Over' }, kupeNo: '31', taiEski: '2026-10-07', vitaminStok: { id: 's1', urun_adi: 'CAROFERTIN-E' } });
  assert.ok(m3.includes('flex-direction:column'), 'M3 Kaydet-Vazgeç alt alta');
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

// F2 madde 1 (çoklu ilaç, RULING 1'): kaydet zinciri — ek ilaç varsa
// p_gun_ac=true ile aç-RPC, dönen gun_id'ye add_drug_administration (PG kapı
// sarmalı dahil); kısmi başarıda alt vaka kalır, 'k/n ilaç eklendi' + alt detay.
function madde1KaydetCtx(els, acDonus) {
  const govde = ['inaktifGecisKaydet', 'vitaminStokIdBul', 'igEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  for (const [id, el] of Object.entries(els)) doc.__setEl(id, el);
  const rpcCagrilari = [];
  const toasts = [];
  const acilan = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
    rpc: async (ad, p) => { rpcCagrilari.push({ ad, p }); return ad === 'inaktif_alt_vaka_ac' ? acDonus : { ok: true }; },
    pullTables: async (t) => ({ ok: [], failed: [] }),
    renderSafe: () => {},
    RPC_TABLES: { inaktif_alt_vaka_ac: ['cases', 'treatment_days'] },
    openCaseDet: async (id) => { acilan.push(id); },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'madde1-kaydet-ctx' });
  return { ctx, doc, rpcCagrilari, toasts, acilan };
}
function madde1Satir(stokId, urunId, doz) {
  const { makeElement } = require('./support/loadModule.js');
  const r = makeElement('div');
  r._ek = { stok_id: stokId, urun_id: urunId, doz: doz, birim: 'ml', yol: null };
  return r;
}
function madde1Liste(...satirlar) {
  const { makeElement } = require('./support/loadModule.js');
  const l = makeElement('div');
  satirlar.forEach(s => l.appendChild(s));
  return l;
}

test('madde1-kist-ilacsiz-gun-yok', async () => {
  // (a) kist + 0 ek ilaç → p_gun_ac=false, ek add YOK, gun_id null, alt detay açılır.
  const t = madde1KaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd2' },
    'ig-kist': { value: '1' },
    'ig-ilac-liste': madde1Liste(),
    'inaktif-gecis-modal': { remove() {} },
  }, { ok: true, alt_vaka_id: 'alt-a', gun_id: null, ertelenen: 0 });
  const r = await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t.ctx);
  assert.strictEqual(r.gun_id, null, 'gun_id null döner');
  assert.strictEqual(t.rpcCagrilari[0].p.p_gun_ac, false, 'ek yoksa gün istenmez');
  assert.strictEqual(t.rpcCagrilari.filter(c => c.ad === 'add_drug_administration').length, 0, 'ek add YOK');
  assert.deepStrictEqual(t.acilan, ['alt-a'], 'alt vaka detayı açılır');
  assert.ok(t.toasts.includes('✅ Kist alt vakası açıldı'), 'kist toast, ölçülen: ' + JSON.stringify(t.toasts));
});

test('madde1-kist-iki-ilac-ayni-gune', async () => {
  // (b) kist + 2 ek ilaç → p_gun_ac=true, 2 add DOĞRU gun_id ile, '2/2' toast.
  const t = madde1KaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd2' },
    'ig-kist': { value: '1' },
    'ig-ilac-liste': madde1Liste(madde1Satir('sA', 'uA', 5), madde1Satir('sB', 'uB', 10)),
    'inaktif-gecis-modal': { remove() {} },
  }, { ok: true, alt_vaka_id: 'alt-b', gun_id: 'gun-1', ertelenen: 0 });
  const r = await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t.ctx);
  assert.strictEqual(r.gun_id, 'gun-1', 'gun_id taşınır');
  assert.strictEqual(t.rpcCagrilari[0].p.p_gun_ac, true, 'ek varsa p_gun_ac=true (MUT-GUN-AC-YOK bekçisi)');
  const adds = t.rpcCagrilari.filter(c => c.ad === 'add_drug_administration');
  assert.strictEqual(adds.length, 2, '2 ek satır yazılır');
  for (const a of adds) assert.strictEqual(a.p.p_day_id, 'gun-1', 'DOĞRU gun_id: ' + JSON.stringify(a.p));
  assert.deepStrictEqual(adds.map(a => a.p.p_stok_id).sort(), ['sA', 'sB'], 'stoklar taşınır');
  assert.ok(t.toasts.some(m => /2\/2 ilaç eklendi/.test(m)), 'k/n toast, ölçülen: ' + JSON.stringify(t.toasts));
  assert.deepStrictEqual(t.acilan, ['alt-b'], 'alt vaka detayı açılır');
});

test('madde1-inaktif-vitamin-gunu-yeniden', async () => {
  // (c) inaktif + vitamin + 1 ek → vitamin günü (dönen gun_id) yeniden kullanılır.
  const t = madde1KaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd1' },
    'ig-vit-doz': { value: '20' },
    'ig-vit-stok': { value: 's1' },
    'ig-ilac-liste': madde1Liste(madde1Satir('sC', 'uC', 3)),
    'inaktif-gecis-modal': { remove() {} },
  }, { ok: true, alt_vaka_id: 'alt-c', gun_id: 'gun-V', ertelenen: 0 });
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t.ctx);
  assert.strictEqual(t.rpcCagrilari[0].p.p_vitamin_stok_id, 's1', 'vitamin aynen gider');
  assert.strictEqual(t.rpcCagrilari[0].p.p_gun_ac, true, 'ek varsa p_gun_ac=true');
  const adds = t.rpcCagrilari.filter(c => c.ad === 'add_drug_administration');
  assert.strictEqual(adds.length, 1, '1 ek satır');
  assert.strictEqual(adds[0].p.p_day_id, 'gun-V', 'vitamin günü yeniden kullanılır');
  assert.strictEqual(adds[0].p.p_stok_id, 'sC', 'ek stok taşınır');
  assert.ok(t.toasts.some(m => /1\/1 ilaç eklendi/.test(m)), 'k/n toast, ölçülen: ' + JSON.stringify(t.toasts));
});

test('madde1-bos-stok-id-gonderilmez', async () => {
  // MUT-A bekçisi: stok id boş ek satır add'e DÜŞMEZ (gönderen varyant → FAIL).
  const t = madde1KaydetCtx({
    'ig-gun': { value: '7' },
    'ig-hastalik': { value: 'd2' },
    'ig-kist': { value: '1' },
    'ig-ilac-liste': madde1Liste(madde1Satir('', null, 5)),
    'inaktif-gecis-modal': { remove() {} },
  }, { ok: true, alt_vaka_id: 'alt-d', gun_id: 'gun-2', ertelenen: 0 });
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t.ctx);
  const adds = t.rpcCagrilari.filter(c => c.ad === 'add_drug_administration');
  assert.strictEqual(adds.length, 0, 'boş stok id yazılmaz, ölçülen: ' + JSON.stringify(adds.map(a => a.p)));
  assert.ok(t.toasts.some(m => /0\/1 ilaç eklendi/.test(m)), 'k/n dürüst sayar, ölçülen: ' + JSON.stringify(t.toasts));
});

test('madde1-igIlacEkle-cok-satir', () => {
  // '+ İlaç ekle' çok-satırlı: ek satır listeye eklenir, okuyucu bulur (kistte
  // CAROFERTIN dayatması yok — stok çağrıdan gelir).
  const govde = ['igIlacEkle', 'igEkIlaclariOku']
    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = makeDomStub();
  const { makeElement } = require('./support/loadModule.js');
  const liste = makeElement('div');
  doc.__setEl('ig-ilac-liste', liste);
  const toasts = [];
  const ctx = {
    console, JSON, Math, Date, document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: (m) => { toasts.push(String(m)); },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'madde1-ekle-ctx' });
  vm.runInContext(`igIlacEkle({stok_id:'s9',urun_id:'u9',ad:'X-ILAC',doz:5})`, ctx);
  vm.runInContext(`igIlacEkle({stok_id:'s8',urun_id:'u8',ad:'Y-ILAC',doz:7})`, ctx);
  const ekler = vm.runInContext('igEkIlaclariOku()', ctx);
  assert.strictEqual(ekler.length, 2, 'iki satır birikir');
  assert.strictEqual(ekler.map(e => e.stok_id).join(','), 's9,s8', 'stoklar çağrıdan (dayatma yok)');
});

// F turu KAPI-5: mor kalıp fallback'siz (index.html:24 --purple tanımlı).
test('mor-buton-fallbacksuz', () => {
  const src = extractFunctionSource('js/ui.js', '_inaktifGecisBtnSync');
  assert.ok(!/var\(--purple,/.test(src), 'var(--purple) fallback YOK');
  assert.ok(src.includes('var(--purple)'), 'mor kalıp korunur');
  assert.ok(/background:none/.test(src), 'mor kalıp background:none aynen');
});

// Madde 1 picker kablosu (davranışsal prob — gerçek sheet HTML + stub DOM,
// verifier MEASURED akışı): '+ İlaç ekle' her tıkta stok <select>'li satır
// ekler, kistte CAROFERTIN dayatması YOK, seçim+doldur okuyucuya düşer,
// kaydet zinciri p_gun_ac=true ile açılır.
function pickerAttrEl(tag) {
  const { makeElement } = require('./support/loadModule.js');
  const el = makeElement(tag);
  const attrs = new Map();
  el.setAttribute = (k, v) => { attrs.set(String(k), String(v)); };
  el.getAttribute = (k) => (attrs.has(String(k)) ? attrs.get(String(k)) : null);
  el.removeAttribute = (k) => { attrs.delete(String(k)); };
  return el;
}
function pickerDoc() {
  const doc = makeDomStub();
  doc.createElement = (tag) => pickerAttrEl(tag);
  return doc;
}
function pickerCocukBul(kok, pred) {
  const kids = (kok && kok.children) || [];
  for (const c of kids) {
    if (!c) continue;
    if (pred(c)) return c;
    const alt = pickerCocukBul(c, pred);
    if (alt) return alt;
  }
  return null;
}
const pickerSinifVar = (c, s) => String(c.className || '').split(/\s+/).indexOf(s) !== -1;
const pickerSelBul = (kok) => pickerCocukBul(kok, (c) => c.tagName === 'SELECT' && pickerSinifVar(c, 'ig-ek-stok'));
const pickerDozBul = (kok) => pickerCocukBul(kok, (c) => c.tagName === 'INPUT' && pickerSinifVar(c, 'ig-ek-doz'));
const pickerVitBul = (kok) => pickerCocukBul(kok, (c) => c.id === 'ig-vit-doz');
const pickerEscAttr = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function pickerAttrCek(html, ad) {
  const m = html.match(new RegExp(ad + '="([^"]*)"'));
  if (!m) return null;
  return m[1].replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
}
const PICKER_STOK = [
  { id: 'sA', urun_adi: 'A-ILAC', birim: 'ml', urun_id: 'uA' },
  { id: 'sB', urun_adi: 'B-ILAC', birim: 'ml', urun_id: 'uB' },
];
const pickerKistSec = () => ({ hastalik: { id: 'd2', name: 'Kistik Over' }, kupeNo: '31', taiEski: '2026-10-07', vitaminStok: { id: 's1', urun_adi: 'CAROFERTIN-E' }, ilacStoklar: PICKER_STOK });
function pickerCtx(secenek) {
  const htmlFn = loadExtractedFunction('js/ui.js', 'inaktifGecisSheetHtml', { extra: { escAttr: pickerEscAttr, esc: String } });
  const html = htmlFn('v-ana', secenek);
  const govde = ['igIlacEkle', 'igEkIlaclariOku', 'inaktifGecisKaydet', 'vitaminStokIdBul']
    .map((a) => extractFunctionSource('js/ui.js', a)).join('\n');
  const doc = pickerDoc();
  const liste = pickerAttrEl('div');
  liste.id = 'ig-ilac-liste';
  for (const ad of ['data-vit-stok', 'data-vit-ad', 'data-ilac-stoklar']) {
    const v = pickerAttrCek(html, ad);
    if (v !== null) liste.setAttribute(ad, v);
  }
  doc.__setEl('ig-ilac-liste', liste);
  const rpcCagrilari = [];
  const toasts = [];
  const acilan = [];
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: String, escAttr: pickerEscAttr,
    toast: (m) => { toasts.push(String(m)); },
    rpc: async (ad, p) => { rpcCagrilari.push({ ad, p }); return ad === 'inaktif_alt_vaka_ac' ? { ok: true, alt_vaka_id: 'alt-p', gun_id: 'gun-1', ertelenen: 0 } : { ok: true }; },
    pullTables: async () => ({ ok: [], failed: [] }),
    renderSafe: () => {},
    RPC_TABLES: { inaktif_alt_vaka_ac: ['cases', 'treatment_days'] },
    openCaseDet: async (id) => { acilan.push(id); },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'picker-ctx' });
  return { ctx, doc, html, liste, rpcCagrilari, toasts, acilan };
}

test('picker-kist-tik-secim-satri-dayatma-yok', () => {
  // (a) kist sheet'te buton tıkı → select'li satır VAR, vitamin satırı YOK.
  const t = pickerCtx(pickerKistSec());
  assert.ok(t.html.includes('onclick="igIlacEkle()"'), 'buton argsız picker çağrısı');
  assert.ok(!t.html.includes('id="ig-vit-doz"'), 'kist sheet vitamin satırı YOK (M3)');
  vm.runInContext('igIlacEkle()', t.ctx);
  assert.strictEqual(t.liste.children.length, 1, 'ilk tık 1 satır ekler');
  const satir = t.liste.children[0];
  const sel = pickerSelBul(satir);
  assert.ok(sel, 'satırda stok <select> var');
  const opts = sel.children.filter((c) => c && c.tagName === 'OPTION' && c.value);
  assert.strictEqual(opts.length, 2, 'seçenekler stok listesinden, ölçülen: ' + JSON.stringify(sel.children.map((c) => c && c.value)));
  assert.ok(!pickerVitBul(satir), 'CAROFERTIN dayatması YOK');
  assert.strictEqual(satir.getAttribute('data-ek-stok'), 'sA', 'satır okuyucu özniteliği taşır (stok)');
  vm.runInContext('igIlacEkle()', t.ctx);
  assert.strictEqual(t.liste.children.length, 2, 'ikinci tık no-op DEĞİL — 2 satır');
  // İnaktif: ön-dolu aynen + eklenebilir (M2).
  const t2 = pickerCtx({ ...INAKTIF, kupeNo: '31', taiEski: '2026-10-07', ilacStoklar: PICKER_STOK });
  assert.ok(t2.html.includes('id="ig-vit-doz"'), 'inaktifte ön-dolu KALIR (M2)');
  const vit = pickerAttrEl('input');
  vit.id = 'ig-vit-doz';
  t2.liste.appendChild(vit);
  t2.doc.__setEl('ig-vit-doz', vit);
  vm.runInContext('igIlacEkle()', t2.ctx);
  assert.strictEqual(t2.liste.children.length, 2, 'ön-dolu varken de satır eklenir');
  assert.strictEqual(t2.liste.children[0], vit, 'ön-dolu satır aynen durur');
  assert.ok(pickerSelBul(t2.liste.children[1]), 'eklenen satır seçimli');
});

test('picker-secim-doldur-okuyucu', () => {
  // (b) seçim+doldur → okuyucu [{stok,doz}] döner.
  const t = pickerCtx(pickerKistSec());
  vm.runInContext('igIlacEkle()', t.ctx);
  const satir = t.liste.children[0];
  const sel = pickerSelBul(satir);
  assert.ok(sel, 'seçim kutusu var');
  sel.value = 'sB';
  if (typeof sel.onchange === 'function') sel.onchange();
  const doz = pickerDozBul(satir);
  assert.ok(doz, 'doz girdisi var');
  doz.value = '5';
  if (typeof doz.oninput === 'function') doz.oninput();
  const ekler = vm.runInContext('igEkIlaclariOku()', t.ctx);
  // vm-realm prototip farkı için JSON normalizasyonu (alan bazında birebir).
  assert.deepStrictEqual(JSON.parse(JSON.stringify(ekler)), [{ stok_id: 'sB', urun_id: 'uB', doz: 5, birim: 'ml', yol: null }]);
});

test('picker-kaydet-gun-ac', async () => {
  // (c) seçimli satırla kaydet → aç-RPC p_gun_ac=true, add doğru güne.
  const t = pickerCtx(pickerKistSec());
  t.doc.__setEl('ig-gun', { value: '7' });
  t.doc.__setEl('ig-hastalik', { value: 'd2' });
  t.doc.__setEl('ig-kist', { value: '1' });
  t.doc.__setEl('inaktif-gecis-modal', { remove() {} });
  vm.runInContext('igIlacEkle()', t.ctx);
  const sel = pickerSelBul(t.liste.children[0]);
  sel.value = 'sB';
  if (typeof sel.onchange === 'function') sel.onchange();
  const doz = pickerDozBul(t.liste.children[0]);
  doz.value = '5';
  if (typeof doz.oninput === 'function') doz.oninput();
  await vm.runInContext(`inaktifGecisKaydet('v-ana')`, t.ctx);
  assert.strictEqual(t.rpcCagrilari[0].ad, 'inaktif_alt_vaka_ac', 'önce aç-RPC');
  assert.strictEqual(t.rpcCagrilari[0].p.p_gun_ac, true, 'ek satır varken p_gun_ac=true');
  const adds = t.rpcCagrilari.filter((c) => c.ad === 'add_drug_administration');
  assert.strictEqual(adds.length, 1, '1 ek satır yazılır, ölçülen: ' + JSON.stringify(adds.map((a) => a.p)));
  assert.strictEqual(adds[0].p.p_stok_id, 'sB', 'seçilen stok taşınır');
  assert.strictEqual(adds[0].p.p_day_id, 'gun-1', 'açılan güne yazılır');
  assert.ok(t.toasts.some((m) => /1\/1 ilaç eklendi/.test(m)), 'k/n toast, ölçülen: ' + JSON.stringify(t.toasts));
});
