// tests/unit/ovsync-pg-karar.test.js — TB-5 UI ayağı (K5B): sunucu birleşik yükündeki
// pg_kapi.karar (migration 20261002000002) takip onay penceresinde doğru etiketle görünür;
// karar YOKKEN (N-1 sunucu) yedek davranış (tohumlama_sonuc / bilinmiyor) aynen korunur.
// Karar → etiket sözleşmesi: runs/2026-10-02-ovsync-sonrasi/k5a-TB5-SQL-DONE.md §2.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const helpers = require('../../js/utils/helpers.js');
const { extractFunctionSource, makeDomStub } = require('./support/loadModule.js');

const fn = n => extractFunctionSource('js/ui.js', n);
const esc = v => String(v == null ? '' : v);

const ETIKET = {
  REQUIRE_ACK_PENDING: 'Son tohumlama sonucu Bekliyor — PG onayı gerekli',
  BLOCK_PREGNANT: 'Gebe inekte PG uygulanamaz',
  BLOCK_CATALOG_UNRESOLVED: 'Ürünün PG katalog bağı belirsiz',
};
const TA = { muayene_tarihi: '2026-10-05', muayene_saat: '14:35:00' };

// Sunucunun _pg_kapi_detay çıktısı (20261002000002 sonrası 10 anahtar; karar opsiyonel -> N-1 = 9 anahtar).
function pgDetay(karar, ekstra = {}) {
  const d = { kupe_no: '197', hayvan_id: 'h-1', tohumlama_id: 't-1', tohumlama_tarihi: '2026-08-20',
    tohumlama_sonuc: 'Bekliyor', deneme_no: 2, seans_admin_id: null, urun_id: 'u-1', pg_kapi_aktif: true, ...ekstra };
  if (karar !== undefined) d.karar = karar;
  return d;
}
const birlesikMsg = pg => 'PG_KAPI:TAKIP_ACIK:' + JSON.stringify({ pg_kapi: pg, takip_acik: TA });

function kur() {
  const doc = makeDomStub();
  const gercek = doc.createElement.bind(doc);
  doc.createElement = t => { const el = gercek(t); let id0 = ''; Object.defineProperty(el, 'id', { get: () => id0, set: v => { if (id0 === v) return; id0 = v; if (v) doc.__setEl(v, el); }, configurable: true }); return el; };
  const src = ['_tohGunNormalize', '_takipPgKararEtiket', '_takipKisaGun', '_takipAcikMetin', '_takipDetayCoz', '_takipAcikAc', '_takipAcikHata', '_pgKapiAc']
    .map(fn).join('\n');
  const ctx = { console, Math, JSON, Date, esc, escAttr: esc, document: doc, history: { pushState() {}, state: null },
    fmtTarih: helpers.fmtTarih, window: {}, rpc: (...a) => { ctx.__rpc.push(a); return Promise.resolve({}); }, __rpc: [] };
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  return { ctx, doc, html: () => doc.getElementById('takip-acik-bs').innerHTML };
}
const pgSatiri = h => (/💉 PG kapısı: ([^<]*)</.exec(h) || [])[1];

// ── sunucu karar'ı VAR: her üç değer sunucu etiketiyle görünür ──
for (const [karar, etiket] of Object.entries(ETIKET)) {
  test('K5B: sunucu pg_kapi.karar=' + karar + ' → onay penceresi "' + etiket + '" gösterir', () => {
    const t = kur();
    assert.strictEqual(t.ctx._takipAcikHata(new Error(birlesikMsg(pgDetay(karar))), () => {}, { kupe: '197' }), true);
    assert.strictEqual(pgSatiri(t.html()), etiket, t.html());
    assert.ok(!t.html().includes('bilinmiyor'));
  });
}
test('K5B: karar tohumlama_sonuc\'tan ÖNCE gelir (BLOCK_PREGNANT + sonuç Gebe → "Son tohumlama sonucu" yedeği çıkmaz)', () => {
  const t = kur();
  t.ctx._takipAcikHata(new Error(birlesikMsg(pgDetay('BLOCK_PREGNANT', { tohumlama_sonuc: 'Gebe' }))), () => {});
  assert.strictEqual(pgSatiri(t.html()), ETIKET.BLOCK_PREGNANT);
  assert.ok(!t.html().includes('Son tohumlama sonucu Gebe'));
});
test('K5B: BLOCK_CATALOG_UNRESOLVED yükünde tohumlama_sonuc olmasa da etiket sunucu kararından gelir', () => {
  const t = kur();
  t.ctx._takipAcikHata(new Error(birlesikMsg(pgDetay('BLOCK_CATALOG_UNRESOLVED', { tohumlama_sonuc: null }))), () => {});
  assert.strictEqual(pgSatiri(t.html()), ETIKET.BLOCK_CATALOG_UNRESOLVED);
});
test('K5B: seans_tamamla birleşik yolu (_pgKapiAc→TAKIP_ACIK, seans_admin_id var) da sunucu kararını gösterir', () => {
  for (const [karar, etiket] of Object.entries(ETIKET)) {
    const t = kur();
    t.ctx._pgKapiAc('PG_KAPI:TAKIP_ACIK', JSON.stringify({ pg_kapi: pgDetay(karar, { seans_admin_id: 's-9' }), takip_acik: TA }), null);
    assert.strictEqual(pgSatiri(t.html()), etiket, karar);
  }
});

// ── karar YOK (N-1 sunucu): bugünkü yedek davranış aynen ──
test('K5B N-1: karar anahtarı YOK + tohumlama_sonuc → "Son tohumlama sonucu <sonuc>"', () => {
  const t = kur();
  t.ctx._takipAcikHata(new Error(birlesikMsg(pgDetay(undefined, { tohumlama_sonuc: 'Bekliyor' }))), () => {});
  assert.strictEqual(pgSatiri(t.html()), 'Son tohumlama sonucu Bekliyor');
});
test('K5B N-1: karar JSON null (NULL girdi savunması) + tohumlama_sonuc → aynı yedek', () => {
  const t = kur();
  t.ctx._takipAcikHata(new Error(birlesikMsg(pgDetay(null, { tohumlama_sonuc: 'Bekliyor' }))), () => {});
  assert.strictEqual(pgSatiri(t.html()), 'Son tohumlama sonucu Bekliyor');
});
test('K5B N-1: karar da tohumlama_sonuc da yok → fail-closed "bilinmiyor" (uydurma yok)', () => {
  const t = kur();
  t.ctx._takipAcikHata(new Error(birlesikMsg(pgDetay(undefined, { tohumlama_sonuc: null }))), () => {});
  assert.strictEqual(pgSatiri(t.html()), 'bilinmiyor');
});

// ── onay yolu karar'dan bağımsız (davranış DEĞİŞMEDİ) ──
test('K5B: onay yolu karar değerinden bağımsız — retry closure aynen saklanır, birleşik bayrak true', () => {
  for (const karar of [...Object.keys(ETIKET), undefined]) {
    const t = kur();
    const retry = () => {};
    t.ctx._takipAcikHata(new Error(birlesikMsg(pgDetay(karar))), retry);
    assert.strictEqual(t.ctx.window.__takipAcik.retry, retry, String(karar));
    assert.strictEqual(t.ctx.window.__takipAcik.birlesik, true, String(karar));
  }
});
test('K5B: yalın TAKIP_ACIK (pg_kapi yok) PG satırı basmaz; karar mantığı birleşik yola özgü', () => {
  const t = kur();
  t.ctx._takipAcikHata(new Error('TAKIP_ACIK:' + JSON.stringify(TA)), () => {});
  assert.ok(!t.html().includes('PG kapısı'));
  assert.strictEqual(t.ctx.window.__takipAcik.birlesik, false);
});
