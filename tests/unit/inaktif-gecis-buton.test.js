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
  assert.ok(html.includes('İnaktif Ovarium — Küpe 31'), 'M2 başlığı (M no: M2)');
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
  const ctx = {
    console, JSON, Math, Date,
    document: doc, window: {},
    esc: s => String(s ?? ''), escAttr: s => String(s ?? ''),
    toast: () => {},
    rpc: async (ad, p) => { rpcCagrilari.push({ ad, p }); return { ok: true }; },
    pullTables: async (t) => { pulls.push(t); return { ok: [], failed: [] }; },
    renderSafe: () => {},
    RPC_TABLES: { inaktif_alt_vaka_ac: ['cases', 'treatment_days'] },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'kaydet-ctx' });
  return { ctx, pulls };
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
    ['MUAYENEDE SORUN VARSA ALT VAKA AÇ', 'M1'], ['İnaktif Ovarium', 'M1'],
    ['Vitamin desteği + erteleme · Ovsync devam eder', 'M1'], ['Kist', 'M1'],
    ['Kist tedavisi alt vaka olarak bağlanır', 'M1'],
  ]) assert.ok(s1.includes(metin), mno + ': ' + metin);
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

// F turu KAPI-5: mor kalıp fallback'siz (index.html:24 --purple tanımlı).
test('mor-buton-fallbacksuz', () => {
  const src = extractFunctionSource('js/ui.js', '_inaktifGecisBtnSync');
  assert.ok(!/var\(--purple,/.test(src), 'var(--purple) fallback YOK');
  assert.ok(src.includes('var(--purple)'), 'mor kalıp korunur');
  assert.ok(/background:none/.test(src), 'mor kalıp background:none aynen');
});
