// tests/unit/ovsync-takip-kapi.test.js
// P10 — TAKIP_ACIK/PG_KAPI birleşik onay kapısı (ui.js + forms.js).
// Bölümler:
//   * KAPI ENVANTERİ — sunucu üreticileri (P3b migration) ≡ UI işleyen dallar
//   * BİRLEŞİK PAYLOAD — _takipAcikHata ayrıştırması + _takipAcikAc sheet copy (mockup 04)
//   * RETRY PARAM SETİ — hizli_uygulama onaylı tekrarı (yalın + birleşik)
//   * BULK ALT-KÜME — _takipTopluSheet onaylı alt kümeyle YENİ ÇAĞRI (D4)
//   * YASAKLAR — confirm() yok, düz 'Hata' toast yok (P10 fonksiyon ailesinde)
//
// Sunucu sözleşme kaynakları (varsayım YOK):
//   - H5 alan adı tablosu: runs/2026-09-28-ovsync-takip/impl-P3b-DONE.md §7
//   - Sarmal tek p_onay: supabase/migrations/20260929000002 (:989 birleşik RAISE)
//   - 7 üretici imzası: supabase/migrations/20260929000003 (C2)
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');
const helpers = require('../../js/utils/helpers.js');
const { extractFunctionSource, makeDomStub, makeElement } = require('./support/loadModule.js');

const REPO_ROOT = path.join(__dirname, '..', '..');
const MIG_P3B = 'supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql';
const MIG_P2B = 'supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql';

// P3b C4-v5 kapı listesi (plan.md:651 birebir) — sunucudaki her TAKIP_ACIK üreticisi.
const P3B_KAPI_LISTESI = [
  'hizli_uygulama',
  'seans_tamamla',
  'bulk_ilac',
  'start_first_service_protocol',
  'create_case',
  'vaka_toplu_ac',
  'kizginlik_vaka_ac',
];

// UI çağrı noktası eşlemesi (GOREV madde 2 + plan.md:651; her satır
// "RPC üreticisi → işleyen UI fonksiyonu" ikilisi).
const KAPI_NOKTALARI = [
  { rpc: 'hizli_uygulama', dosya: 'js/ui.js', fn: '_hayvanHizliUygulaKaydet', isleyici: '_takipAcikHata' },
  { rpc: 'hizli_uygulama', dosya: 'js/ui.js', fn: '_protokolUygulaKaydet', isleyici: '_takipAcikHata' },
  { rpc: 'hizli_uygulama', dosya: 'js/ui.js', fn: '_gorevStokTamamlaSubmit', isleyici: '_takipAcikHata' },
  { rpc: 'seans_tamamla', dosya: 'js/forms.js', fn: 'seansTamamla', isleyici: '_takipAcikHata' },
  { rpc: 'bulk_ilac', dosya: 'js/forms.js', fn: 'submitBulkIlac', isleyici: '_takipTopluSheet' },
  { rpc: 'start_first_service_protocol', dosya: 'js/ui.js', fn: 'ovsyncBaslat', isleyici: '_takipAcikHata' },
  { rpc: 'create_case', dosya: 'js/forms.js', fn: 'submitCase', isleyici: '_takipAcikHata' },
  { rpc: 'vaka_toplu_ac', dosya: 'js/forms.js', fn: 'submitBulkCase', isleyici: '_takipTopluSheet' },
  { rpc: 'kizginlik_vaka_ac', dosya: 'js/ui.js', fn: 'sorunVakaAc', isleyici: '_takipAcikHata' },
];

// P10 ui.js fonksiyon ailesi — TEK ctx'te yaşar (birbirini çağırır).
const P10_UI_FNS = [
  '_tohGunNormalize',     // P9 tarih normalize (P10 kısa gün görüntüsü buna dayanır)
  '_takipPgKararEtiket',  // PG karar kodu → kullanıcı metni (_pgKapiAc copy dili)
  '_takipKisaGun',        // '2026-10-05' → '05.10' (mockup 04 "05.10 14:35" copy)
  '_takipAcikMetin',      // mockup 04 metin şablonu (küpe+zaman+fiil)
  '_takipAcikHata',       // e ayrıştırıcı: TAKIP_ACIK + PG_KAPI:TAKIP_ACIK
  '_takipAcikAc',         // birleşik/tekil onay bottom-sheet (mockup 04 birebir)
  '_takipOnayUygula',     // "Evet, takibi kapat ve uygula" butonu
  '_takipAcikKapat',
  '_takipTopluSheet',     // D4: bulk satır-bazlı onay listesi
  '_takipTopluCek',       // satır checkbox state kaptanı (DOM-sorgusuz seçim)
  '_takipTopluUygula',    // "Evet, seçilenleri uygula" → retryFn(onaylı alt küme)
  '_takipTopluRender',    // retry sonrası satır sonuçları (uygulandı / uygulanmadı)
  '_takipTopluKapat',
];

// ══════════════════════════════════════════════════════════════════════════
// vm kaptan — P10 ailesi + çağrı noktası (isteğe bağlı) TEK ctx'te
// ══════════════════════════════════════════════════════════════════════════
function p10Ctx(ekstra = {}) {
  const cagri = {
    rpc: [], toast: [], pull: [], refresh: [], openDet: [], retry: [],
  };
  const doc = ekstra.doc || makeDomStub();
  // Bulk sheet satır seçimi DOM-sorgusuz kaptanla (onchange) — querySelectorAll
  // yine de gerçek kontratla override edilebilir (test istemezse boş).
  doc.querySelectorAll = () => [];
  // Gerçek DOM davranışı: id'li element appendChild'tan ÖNCE oluşturulur ve
  // getElementById ile bulunur — stub'ta createElement→id atamasını kaydet.
  // (__setEl'in el.id ataması setter'ı yeniden tetikler — aynı değerde no-op.)
  const gercekCreate = doc.createElement.bind(doc);
  doc.createElement = tag => {
    const el = gercekCreate(tag);
    let id0 = el.id || '';
    Object.defineProperty(el, 'id', {
      get: () => id0,
      set: v => {
        if (id0 === v) return;
        id0 = v;
        if (v) doc.__setEl(v, el);
      },
      configurable: true,
    });
    return el;
  };

  const stubs = {
    esc: v => String(v == null ? '' : v),
    escAttr: v => String(v == null ? '' : v),
    fmtTarih: helpers.fmtTarih,
    toast: (m, err) => { cagri.toast.push([m, !!err]); },
    getState: () => [],   // çağrı noktaları kupe araması yapar; boş sürü → kupe ''
    pullTables: async t => { cagri.pull.push(t); },
    loadDash: () => {},
    loadTasks: () => {},
    getUserMessage: e => String((e && e.message) || e),
    _islemSonrasiRefresh: () => { cagri.refresh.push(1); },
    openDet: id => { cagri.openDet.push(id); },
    RPC_TABLES: {},
    history: { pushState() {}, back() {}, state: null },
    // rpc kaptanı: rpcDavranis kuyruğu — Error elemanı throw, null/objele döner
    rpc: async (ad, params) => {
      cagri.rpc.push([ad, params]);
      const dav = (ekstra.rpcDavranis || []).shift();
      if (dav instanceof Error) throw dav;
      return dav === undefined ? { ok: true } : dav;
    },
    _curTaskFilter: 'today',
  };
  const src = P10_UI_FNS.map(n => extractFunctionSource('js/ui.js', n)).join('\n')
    + (ekstra.noktaFns || []).map(n => extractFunctionSource(n.dosya, n.fn)).join('\n');
  const ctx = { console, Math, JSON, Date, ...stubs, ...(ekstra.globals || {}) };
  ctx.document = doc;
  ctx.window = ekstra.window || {};
  ctx.globalThis = ctx;
  ctx.globalThis.window = ctx.window;
  vm.createContext(ctx);
  vm.runInContext(src, ctx, { filename: 'js/ui.js#p10-kapi' });
  return { ctx, cagri, doc };
}

// ── Mockup 04 birleşik fikstür (H5 satır 5 alan adlarıyla) ──
const BIRLESIK_MSG = 'PG_KAPI:TAKIP_ACIK:' + JSON.stringify({
  pg_kapi: {
    karar: 'REQUIRE_ACK_PENDING', gun: 5, sperma: null, kupe_no: '197',
    deneme_no: 1, hayvan_id: 'h-197', urun_durumu: 'PG',
    tohumlama_id: 'T-197', tohumlama_sonuc: 'Bekliyor', tohumlama_tarihi: '2026-09-25',
  },
  takip_acik: { muayene_tarihi: '2026-10-05', muayene_saat: '14:35:00' },
});
const YALIN_MSG = 'TAKIP_ACIK:' + JSON.stringify({
  muayene_tarihi: '2026-10-05', muayene_saat: '14:35:00',
});

// ══════════════════════════════════════════════════════════════════════════
// 1) KAPI ENVANTERİ — sunucu üreticileri ≡ UI işleyen dallar
// ══════════════════════════════════════════════════════════════════════════

test('KAPI-ENVANTER: P3b migration\'daki p_takip_onay üreticileri listeyle birebir', () => {
  const sql = fs.readFileSync(path.join(REPO_ROOT, MIG_P3B), 'utf8');
  const uretici = new Set();
  for (const m of sql.matchAll(/^CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(/gm)) {
    // imza çok satırlı olabilir — CREATE satırından sonraki 500 karakter penceresi
    // tüm parametre bloğunu kapsar (en uzun imza ~400 karakter).
    const imza = sql.slice(m.index, m.index + 500);
    if (/p_takip_onay/.test(imza)) uretici.add(m[1]);
  }
  assert.deepStrictEqual([...uretici].sort(), [...P3B_KAPI_LISTESI].sort(),
    'sunucu TAKIP_ACIK üretici kümesi P3b listesiyle birebir olmalı (C2 imza tablosu)');
});

test('KAPI-ENVANTER: sarmal birleşik kapısı tek p_onay ile açılır (p_takip_onay param YOK)', () => {
  // 20260929000002:989 — birleşik RAISE; imza p_onay bool DEFAULT false (tek onay
  // parametresi). GOREV metnindeki sarmal "p_takip_onay" ifadesi imza gerçeğine
  // uymaz: PostgREST bilinmeyen argümanı PGRST202/404 ile reddeder (P3b kabul 5.4).
  const sql = fs.readFileSync(path.join(REPO_ROOT, MIG_P2B), 'utf8');
  const imza = sql.slice(sql.indexOf('CREATE OR REPLACE FUNCTION public.tohumlama_bos_ve_devam('),
    sql.indexOf('CREATE OR REPLACE FUNCTION public.tohumlama_bos_ve_devam(') + 500);
  assert.ok(/p_onay\s+bool\s+DEFAULT\s+false/.test(imza), 'sarmal p_onay taşır');
  assert.ok(!/p_takip_onay/.test(imza), 'sarmalda p_takip_onay parametresi YOK');
  assert.ok(/PG_KAPI:TAKIP_ACIK:/.test(sql), 'sarmal birleşik RAISE üretir');
});

test('KAPI-ENVANTER: her sunucu üreticisinin UI\'da işleyen dalı var (P3b listesiyle birebir)', () => {
  // Her üretici en az bir UI noktasıyla eşleşmeli + her noktada RPC adı ve
  // TAKIP_ACIK işleyicisi aynı fonksiyon gövdesinde yaşamalı.
  const kapsanan = new Set();
  for (const n of KAPI_NOKTALARI) {
    const govde = extractFunctionSource(n.dosya, n.fn);
    assert.ok(govde.includes(n.rpc), `${n.fn}: ${n.rpc} çağrısı gövdede olmalı`);
    assert.ok(govde.includes(n.isleyici + '('),
      `${n.fn}: TAKIP_ACIK işleyicisi (${n.isleyici}) gövdede çağrılmalı`);
    kapsanan.add(n.rpc);
  }
  for (const rpc of P3B_KAPI_LISTESI) {
    assert.ok(kapsanan.has(rpc), `üretici ${rpc} için UI noktası eksik`);
  }
});

test('KAPI-ENVANTER: sarmal yollarının UI ikizleri TAKIP_ACIK dalına bağlı (P8/P9 noktaları)', () => {
  const secici = extractFunctionSource('js/ui.js', '_devamSeciciOnayla');
  assert.ok(secici.includes('_takipAcikAc('),
    '_devamSeciciOnayla TAKIP_ACIK/PG_KAPI:TAKIP_ACIK dalı tek sheet\'e bağlanmalı');
  const pgBosAta = extractFunctionSource('js/ui.js', '_pgKapiBosAtaUygula');
  assert.ok(pgBosAta.includes('_takipAcikHata('),
    '_pgKapiBosAtaUygula (sarmal PG yazması) birleşik/yalın takip redini yakalamalı');
  const redIsle = extractFunctionSource('js/ui.js', '_devamRedIsle');
  assert.ok(redIsle.includes('PG_KAPI:TAKIP_ACIK'),
    '_devamRedIsle birleşik kodu kendi adıyla ayrıştırmalı (TAKIP_ACIK\'a düşmez)');
});

// ══════════════════════════════════════════════════════════════════════════
// 2) BİRLEŞİK PAYLOAD — ayrıştırma + sheet copy (mockup 04 birebir)
// ══════════════════════════════════════════════════════════════════════════

test('KISA-GUN: _takipKisaGun gg.aa kısa biçimi (mockup "05.10 14:35")', () => {
  const { ctx } = p10Ctx();
  assert.strictEqual(ctx._takipKisaGun('2026-10-05'), '05.10');
  // Z-suffix P9 normatifine göre İSTANBUL gününe düşer: UTC 21:30 = ertesi gün
  // (C1 — ilk-10 kesimi YASAK; sunucu payload'ı DATE olduğundan pratikte saatsız gelir).
  assert.strictEqual(ctx._takipKisaGun('2026-10-05T21:30:00Z'), '06.10');
  assert.strictEqual(ctx._takipKisaGun(null), '');
});

test('BIRLESIK: _takipAcikHata birleşik payloadı yakalar, sheet mockup 04 copy ile açılır', () => {
  const { ctx, doc } = p10Ctx();
  const retry = () => {};
  const yakaladi = ctx._takipAcikHata(new Error(BIRLESIK_MSG), retry, { islem: 'PG uygulansın mı?' });
  assert.strictEqual(yakaladi, true, 'birleşik red işleyiciye düşmeli');
  const box = doc.body.children.find(el => el.id === 'takip-acik-bs');
  assert.ok(box, 'takip-acik-bs sheet\'i DOM\'a basılmalı');
  const html = box.innerHTML;
  assert.ok(html.includes('🔍'), 'mockup ikonu');
  assert.ok(html.includes('Bu hayvan takipte'), 'mockup başlık birebir');
  assert.ok(html.includes('<b>Küpe 197</b>'), 'birleşik küpe pg_kapi.kupe_no\'dan (H5)');
  assert.ok(html.includes("05.10 14:35'te rektal muayene takibinde."), 'mockup metin satırı birebir');
  assert.ok(html.includes('Takip kapatılıp PG uygulansın mı?'), 'fiil şablonu (PG)');
  assert.ok(html.includes('Evet, takibi kapat ve uygula'), 'mockup onay butonu birebir');
  assert.ok(html.includes('Vazgeç'), 'mockup vazgeç butonu birebir');
  assert.strictEqual(typeof ctx.window.__takipAcik, 'object', 'retry closure saklanmalı');
  assert.strictEqual(ctx.window.__takipAcik.birlesik, true, 'birleşik bayrağı retry\'a taşınmalı');
});

test('BIRLESIK: sheet iki gerekceyi alt alta basar (PG_KAPI + TAKIP_ACIK)', () => {
  const { ctx, doc } = p10Ctx();
  ctx._takipAcikHata(new Error(BIRLESIK_MSG), () => {}, { islem: 'PG uygulansın mı?' });
  const html = doc.body.children.find(el => el.id === 'takip-acik-bs').innerHTML;
  assert.ok(html.includes('Son tohumlama sonucu Bekliyor'), 'PG gerekçesi (REQUIRE_ACK_PENDING)');
  assert.ok(html.includes('Rektal muayene takibi'), 'TAKIP_ACIK gerekçesi');
});

test('YALIN: _takipAcikHata yalın TAKIP_ACIK\'ı yakalar; kupe bağlamdan, islem default', () => {
  const { ctx, doc } = p10Ctx();
  const yakaladi = ctx._takipAcikHata(new Error(YALIN_MSG), () => {}, { kupe: '197' });
  assert.strictEqual(yakaladi, true);
  const html = doc.body.children.find(el => el.id === 'takip-acik-bs').innerHTML;
  assert.ok(html.includes('<b>Küpe 197</b>'), 'yalın redde kupe bağlam paramından gelir');
  assert.ok(html.includes("05.10 14:35'te rektal muayene takibinde."));
  assert.ok(html.includes('Takip kapatılıp uygulama yapılsın mı?'), 'varsayılan fiil');
  assert.strictEqual(ctx.window.__takipAcik.birlesik, false);
});

test('YALIN: kupe verilmemişse metin "Bu hayvan" der (payload\'da kupe alanı yok — H5)', () => {
  const { ctx, doc } = p10Ctx();
  ctx._takipAcikHata(new Error(YALIN_MSG), () => {});
  const html = doc.body.children.find(el => el.id === 'takip-acik-bs').innerHTML;
  assert.ok(html.includes('Bu hayvan'), 'kupe yoksa mockup metni hayvan vurgusuz kurulur');
});

test('AYRISTIRMA: TAKIP_ACIK olmayan hatalar false döner — mevcut hata akışı bozulmaz', () => {
  const { ctx } = p10Ctx();
  assert.strictEqual(ctx._takipAcikHata(new Error('İnternet yok'), () => {}), false);
  assert.strictEqual(ctx._takipAcikHata(new Error('PG_KAPI:BLOCK_PREGNANT:{}'), () => {}),
    false, 'yalnız-PG kapısı _pgKapiHata\'ya ait — mevcut davranış korunur');
  assert.strictEqual(ctx._takipAcikHata(null, () => {}), false);
});

test('AYRISTIRMA: muayene_tarihi taşımayan TAKIP_ACIK türevi (ZATEN_ACIK) sheet açmaz', () => {
  // Sarmal _takip_gorev_kur guard redi 'TAKIP_ACIK:ZATEN_ACIK:{gorev_id,...}' —
  // H5 muayene_tarihi alanı yok; sheet'e sokmak alan uydurma olur → false.
  const { ctx, doc } = p10Ctx();
  const n = doc.body.children.length;
  const yakaladi = ctx._takipAcikHata(new Error('TAKIP_ACIK:ZATEN_ACIK:{"gorev_id":"g1"}'), () => {});
  assert.strictEqual(yakaladi, false, 'ZATEN_ACIK türevi P10 sheet\'ine girmez');
  assert.strictEqual(doc.body.children.length, n);
});

test('ONAY-AKISI: Evet → retry(birlesik) çağrılır, sheet kapanır, liste tazelenir', async () => {
  const cagri2 = [];
  const retryCagri = [];
  const { ctx, doc } = p10Ctx({
    globals: { pullTables: async t => { cagri2.push(t); } },
  });
  ctx._takipAcikHata(new Error(YALIN_MSG), async birlesik => { retryCagri.push(birlesik); }, {});
  await ctx._takipOnayUygula();
  assert.deepStrictEqual(retryCagri, [false], 'yalın redde retry birleşik=false alır');
  assert.strictEqual(doc.body.children.find(el => el.id === 'takip-acik-bs'), undefined,
    'başarıda sheet kapanır');
  assert.strictEqual(ctx.window.__takipAcik, null, 'closure temizlenir');
  assert.ok(cagri2.length === 1 && cagri2[0].includes('gorev_log'), 'pullTables liste tazeler');
});

test('ONAY-AKISI: retry reddederse sheet açık kalır, buton geri açılır, hata toast', async () => {
  const { ctx, cagri, doc } = p10Ctx();
  ctx._takipAcikHata(new Error(YALIN_MSG), async () => { throw new Error('çakışma'); }, {});
  await ctx._takipOnayUygula();
  assert.ok(doc.body.children.find(el => el.id === 'takip-acik-bs'), 'hata: sheet açık kalmalı');
  assert.ok(cagri.toast.some(([m, err]) => err && m.includes('çakışma')), 'hata toast');
  assert.strictEqual(ctx.window.__takipAcik && ctx.window.__takipAcik.birlesik, false,
    'closure korunur — ikinci deneme mümkün');
});

// ══════════════════════════════════════════════════════════════════════════
// 3) RETRY PARAM SETİ — hizli_uygulama onaylı tekrarı (C2 imzaları)
// ══════════════════════════════════════════════════════════════════════════

function hizliCtx(rpcDavranis) {
  const stokEl = makeElement('select'); stokEl.value = 'stok-1';
  const dozEl = makeElement('input'); dozEl.value = '2.5';
  const birimEl = makeElement('input'); birimEl.value = 'ml';
  const rotaEl = makeElement('select'); rotaEl.value = 'IM';
  const btn = makeElement('button');
  const doc = makeDomStub();
  doc.__setEl('pu-stok', stokEl);
  doc.__setEl('pu-doz', dozEl);
  doc.__setEl('pu-birim', birimEl);
  doc.__setEl('pu-rota', rotaEl);
  doc.__setEl('pu-kaydet-btn', btn);
  return p10Ctx({
    rpcDavranis,
    doc,
    noktaFns: [{ dosya: 'js/ui.js', fn: '_hayvanHizliUygulaKaydet' }],
    globals: {},
    window: {},
  });
}

test('RETRY-PARAM: hizli_uygulama yalın TAKIP_ACIK → Evet → p_takip_onay=true tek param', async () => {
  const { ctx, cagri } = hizliCtx([new Error(YALIN_MSG), { ok: true }]);
  await ctx._hayvanHizliUygulaKaydet('h-197');
  assert.ok(ctx.window.__takipAcik, 'kapı sheet\'i açılmalı');
  await ctx._takipOnayUygula();
  const tekrar = cagri.rpc.filter(([ad]) => ad === 'hizli_uygulama')[1];
  assert.ok(tekrar, 'ikinci (onaylı) çağrı yapılmalı');
  assert.strictEqual(tekrar[1].p_takip_onay, true, 'C2: tekil yol p_takip_onay=true');
  assert.strictEqual(tekrar[1].p_pg_onay, undefined, 'yalın takipte PG onayı GÖNDERİLMEZ');
  assert.strictEqual(tekrar[1].p_hayvan_id, 'h-197', 'orijinal paramlar korunur');
  assert.strictEqual(tekrar[1].p_stok_id, 'stok-1');
});

test('RETRY-PARAM: hizli_uygulama birleşik red → Evet → p_pg_onay=true + p_takip_onay=true', async () => {
  const { ctx, cagri } = hizliCtx([new Error(BIRLESIK_MSG), { ok: true }]);
  await ctx._hayvanHizliUygulaKaydet('h-197');
  assert.strictEqual(ctx.window.__takipAcik.birlesik, true);
  await ctx._takipOnayUygula();
  const tekrar = cagri.rpc.filter(([ad]) => ad === 'hizli_uygulama')[1];
  assert.strictEqual(tekrar[1].p_pg_onay, true, 'birleşik: PG kapısı da aynı çağrıda onaylanır');
  assert.strictEqual(tekrar[1].p_takip_onay, true, 'birleşik: takip onayı da aynı çağrıda');
});

// ══════════════════════════════════════════════════════════════════════════
// 4) BULK ALT-KÜME — _takipTopluSheet (D4)
// ══════════════════════════════════════════════════════════════════════════

const BULK_ROWS = [
  { id: 'b1', kupe: '11', tarih: '2026-10-07', saat: '09:30:00', pgKarar: 'ALLOW' },
  { id: 'b2', kupe: '12', tarih: '2026-10-07', saat: '09:30:00', pgKarar: 'REQUIRE_ACK_PENDING' },
];

test('BULK-SHEET: satırlar küpe + iki gerekce alt alta; buton copy plan birebir', () => {
  const { ctx, doc } = p10Ctx();
  ctx._takipTopluSheet(BULK_ROWS, async () => ({ ok: true }));
  const html = doc.body.children.find(el => el.id === 'takip-toplu-bs').innerHTML;
  assert.ok(html.includes('🔍'), 'başlık ikonu');
  assert.ok(html.includes('Küpe 11') && html.includes('Küpe 12'), 'satır küpeleri');
  assert.ok(html.includes('Evet, seçilenleri uygula'), 'plan.md:652 buton copy birebir');
  assert.ok(html.includes('Rektal muayene takibi'), 'TAKIP_ACIK gerekçesi her satırda');
  assert.ok(html.includes('Son tohumlama sonucu Bekliyor'), 'b2\'de PG gerekçesi (alt alta)');
  assert.ok(html.includes('takip-toplu-onayla'), 'onay butonu id\'li — handler bağlanır');
});

test('BULK-ALT-KUME: Evet → retryFn yalnız onaylı alt kümeyle; onaysız satır "uygulanmadı"', async () => {
  const { ctx, doc } = p10Ctx();
  const retrySonuclari = [];
  ctx._takipTopluSheet(BULK_ROWS, async secilen => { retrySonuclari.push(secilen); return { ok: true }; });
  ctx._takipTopluCek('b1', { checked: true });   // yalnız b1 işaretli — b2 onaysız
  await ctx._takipTopluUygula();
  assert.deepStrictEqual(retrySonuclari, [['b1']], 'retry onaylı ALT KÜMEyle (p_animal_ids = p_takip_onaylar)');
  const html = doc.body.children.find(el => el.id === 'takip-toplu-bs').innerHTML;
  assert.ok(html.includes('uygulandı'), 'onaylı satır sonucu listede');
  assert.ok(html.includes('uygulanmadı'), 'onaysız satır TAKIP_ACIK — uygulanmadı');
  assert.ok(html.includes('Kapat'), 'iş bittiğinde buton Kapat\'a döner');
});

test('BULK-ALT-KUME: hiç satır seçilmezse retry çağrılmaz (uyarı toast)', async () => {
  const { ctx, cagri } = p10Ctx();
  const retrySonuclari = [];
  ctx._takipTopluSheet(BULK_ROWS, async secilen => { retrySonuclari.push(secilen); return { ok: true }; });
  await ctx._takipTopluUygula();
  assert.deepStrictEqual(retrySonuclari, [], 'seçimsiz gönderim YOK');
  assert.ok(cagri.toast.some(([m, err]) => err), 'uyarı toast');
});

test('BULK-HATA: retryFn reddederse sheet açık kalır, buton geri döner', async () => {
  const { ctx, cagri, doc } = p10Ctx();
  ctx._takipTopluSheet(BULK_ROWS, async () => { throw new Error('ağ hatası'); });
  ctx._takipTopluCek('b1', { checked: true });
  await ctx._takipTopluUygula();
  assert.ok(doc.body.children.find(el => el.id === 'takip-toplu-bs'), 'hata: sheet açık');
  assert.ok(cagri.toast.some(([m, err]) => err && m.includes('ağ hatası')));
  const html = doc.body.children.find(el => el.id === 'takip-toplu-bs').innerHTML;
  assert.ok(html.includes('Evet, seçilenleri uygula'), 'buton onay durumuna döner');
});

// ══════════════════════════════════════════════════════════════════════════
// 5) YASAKLAR — confirm() yok; düz 'Hata' toast yok
// ══════════════════════════════════════════════════════════════════════════

test('YASAK: P10 fonksiyon ailesinde confirm() çağrısı yok', () => {
  for (const fn of P10_UI_FNS) {
    const govde = extractFunctionSource('js/ui.js', fn);
    assert.ok(!/\bconfirm\s*\(/.test(govde), `${fn}: confirm() YASAK`);
  }
});

test('YASAK: P10 fonksiyon ailesinde düz "Hata" toast yok', () => {
  for (const fn of P10_UI_FNS) {
    const govde = extractFunctionSource('js/ui.js', fn);
    assert.ok(!/toast\(\s*(['"])Hata\1/.test(govde), `${fn}: düz 'Hata' toast YASAK`);
  }
});
