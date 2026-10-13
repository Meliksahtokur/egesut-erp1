'use strict';
// tests/unit/pg-kapi-onay-tekrar.test.js
// Faz 4 — ROOT RULING 3 (IMPL-A-KAPI madde 5) + ROOT RULING 4 (IMPL-A-KAPI-2 madde 3).
//
// RULING 3: `_pgKapiHata` modali saklanan tekrar kapanisini (cagri) onay
// dugmesiyle `p_pg_onay=true` + `p_pg_gerekce` ile cagirmali (§18.8).
// Davranis testi: stub `rpc` ile olculur (yalniz metin kilidi YETMEZ).
// Adli mutant: MUT-ONAY-TEKRARSIZ.
//
// RULING 4: PG reddinde history'de bayat kayit kalmasin — reddet→kapat
// akisinda `history.length` artisi net 0 (ya da tek kayit).
// Adli mutant: MUT-PG-CIFT-PUSH.
//
// Yontem: ui.js'den yalniz ilgili fonksiyonlar cikarilip vm'de kosar
// (stub document/history/rpc). `UI_YOLU` env ile mutant kopyaya yonlenir.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { makeDomStub } = require('./support/loadModule.js');

const KOK = path.join(__dirname, '..', '..');
const UI_YOLU = () => process.env.UI_YOLU || path.join(KOK, 'js/ui.js');

// Dengeli-suslu-parantez fonksiyon cikarma (support/loadModule.js ile ayni algoritma;
// env-override'lu yol gerektigi icin yerelde).
function kaynakCek(abs, ad) {
  const src = fs.readFileSync(abs, 'utf8');
  const start = src.search(new RegExp('^\\s*(?:async\\s+)?function\\s+' + ad + '\\s*\\(', 'm'));
  if (start === -1) throw new Error('kirmizi: function ' + ad + ' yok (' + abs + ')');
  let i = src.indexOf('{', start);
  let depth = 0, str = null, esc = false, lc = false, bc = false;
  for (; i < src.length; i++) {
    const c = src[i], n = src[i + 1];
    if (lc) { if (c === '\n') lc = false; continue; }
    if (bc) { if (c === '*' && n === '/') { bc = false; i++; } continue; }
    if (str) {
      if (esc) { esc = false; continue; }
      if (c === '\\') { esc = true; continue; }
      if (c === str) str = null;
      continue;
    }
    if (c === '/' && n === '/') { lc = true; i++; continue; }
    if (c === '/' && n === '*') { bc = true; i++; continue; }
    if (c === "'" || c === '"' || c === '`') { str = c; continue; }
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) return src.slice(start, i + 1); }
  }
  throw new Error(ad + ': govde kapanmadi');
}

// Gercek history semantigi: pushState length'i +1 artirir, back() artirmaz.
function tarihceStub() {
  return {
    _yigin: [null], _idx: 0, pushSayisi: 0, backSayisi: 0,
    get length() { return this._yigin.length; },
    get state() { return this._yigin[this._idx]; },
    pushState(s) {
      this.pushSayisi++;
      this._yigin = this._yigin.slice(0, this._idx + 1);
      this._yigin.push(s); this._idx++;
    },
    replaceState(s) { this._yigin[this._idx] = s; },
    back() { this.backSayisi++; if (this._idx > 0) this._idx--; },
  };
}

function kapiCtx(kanca = {}) {
  const adlar = ['_pgKapiAc', '_pgKapiHata', '_pgKapiKapat', '_pgKapiOnayliTekrar'];
  const govde = adlar.map(a => kaynakCek(UI_YOLU(), a)).join('\n');
  const doc = makeDomStub();
  const hist = tarihceStub();
  const toasts = [];
  const pulls = [];
  let renders = 0;
  const ctx = {
    console, JSON, Math, Date,
    document: doc, history: hist, window: {},
    esc: s => String(s ?? ''), fmtTarih: s => String(s ?? ''),
    toast: m => { toasts.push(String(m)); },
    rpc: kanca.rpc || (async () => { throw new Error('stub rpc tanimsiz'); }),
    pullTables: async (t) => { pulls.push(t); return { ok: [], failed: [] }; },
    renderSafe: () => { renders++; },
    RPC_TABLES: {
      hizli_uygulama: ['uygulama_log', 'stok_hareket', 'gorev_log'],
      add_drug_administration: ['stok', 'stok_hareket', 'drug_administrations'],
      tedavi_sablon_uygula: ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log', 'islem_log'],
      tohumlama_bos_ve_devam: ['tohumlama', 'gorev_log', 'stok', 'stok_hareket', 'hayvanlar', 'islem_log', 'cases', 'treatment_days', 'treatment_day_uygulamalar'],
    },
  };
  vm.createContext(ctx);
  vm.runInContext(govde, ctx, { filename: 'pg-kapi-ctx' });
  return { ctx, doc, hist, toasts, pulls, renders: () => renders };
}

// Acilan pg-kapi-bs kutusunu bulup getElementById'ye bagla (stub innerHTML parse etmez).
function kutuyuBagla(doc) {
  const box = doc.body.children.find(e => e && e.id === 'pg-kapi-bs');
  assert.ok(box, 'pg-kapi-bs kutusu DOMda');
  doc.__setEl('pg-kapi-bs', box);
  return box;
}

// Onay dugmesine kablolu onclick dizesini dondur (tiklama bunu calistirir).
function onaylaKodu(box) {
  const m = /id="pg-kapi-onayla"[^>]*onclick="([^"]+)"/.exec(box.innerHTML);
  assert.ok(m, 'onay dugmesi kablolu (onclick)');
  return m[1];
}

test('onay-dugmesi-cagriyi-pg-onayla-cagirir', async () => {
  // MUT-ONAY-TEKRARSIZ adli test: _pgKapiOnayliTekrar'daki tekrar(true, gerekce)
  // cagrisi silinirse stub rpc p_pg_onay===true'yi HIC gormez → FAIL.
  const rpcCagrilari = [];
  const { ctx, doc, hist } = kapiCtx({
    rpc: async (ad, p) => {
      rpcCagrilari.push({ ad, p });
      if (p && p.p_pg_onay === true) return { ok: true };
      throw new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01","tohumlama_tarihi":"2026-10-01","deneme_no":2}');
    },
  });
  // _tedaviGunExecute:11397 kalibi (p_pg_onay/p_pg_gerekce kapanisi).
  vm.runInContext(`async function cagri(onay, gerekce) {
    return rpc('treatment_day_tamamla', { p_day_id: 'gun-1', p_not: null,
      p_pg_onay: !!onay, p_pg_gerekce: gerekce || null });
  }`, ctx);
  doc.__setEl('pg-kapi-gerekce', { value: '35. gun kontrolu negatif' });
  const akis = await vm.runInContext(`(async () => {
    let hata = null;
    try { await cagri(false, null); } catch (e) { hata = e; }
    if (!hata) return { red: false };
    return { red: true, acildi: _pgKapiHata(hata, cagri) };
  })()`, ctx);
  assert.ok(akis.red && akis.acildi, 'onaysiz cagri PG kapisina takilir, modal acilir');
  const box = kutuyuBagla(doc);
  assert.ok(box.innerHTML.includes('pg-kapi-gerekce'), 'gerekce alani var');
  assert.strictEqual(hist.pushSayisi, 1, 'tek entry');
  // Tiklama: kablo (onclick dizesi) oldugu gibi calistirilir.
  await vm.runInContext(onaylaKodu(box), ctx);
  const onayli = rpcCagrilari.filter(c => c.p && c.p.p_pg_onay === true);
  assert.strictEqual(onayli.length, 1, 'rpc p_pg_onay===true ile tekrar cagrildi');
  assert.strictEqual(onayli[0].p.p_pg_gerekce, '35. gun kontrolu negatif', 'gerekce tasinir');
  assert.ok(!doc.body.children.includes(box), 'basarida modal kapanir');
});

test('onayli-tekrar-basarida-cagirana-ozgu-tazeleme', async () => {
  // F turu KAPI-3 adli (MUT-TAZELEME-YOK): basari kolundaki pullTables +
  // renderSafe silinirse pulls/renders bos kalir → FAIL.
  const T = {
    hizli_uygulama: ['uygulama_log', 'stok_hareket', 'gorev_log'],
    add_drug_administration: ['stok', 'stok_hareket', 'drug_administrations'],
    tedavi_sablon_uygula: ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log', 'islem_log'],
    tohumlama_bos_ve_devam: ['tohumlama', 'gorev_log', 'stok', 'stok_hareket', 'hayvanlar', 'islem_log', 'cases', 'treatment_days', 'treatment_day_uygulamalar'],
  };
  const birlesim = [...new Set(['hizli_uygulama', 'add_drug_administration', 'tedavi_sablon_uygula', 'tohumlama_bos_ve_devam'].flatMap(a => T[a]))];
  // (a) rpcAd'siz cagri (forms.js kapilari): birlesim tazelenir.
  {
    const t = kapiCtx({ rpc: async (ad, p) => {
      if (p && p.p_pg_onay === true) return { ok: true };
      throw new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01"}');
    } });
    vm.runInContext(`async function cagri(onay, gerekce) {
      return rpc('treatment_day_tamamla', { p_day_id: 'gun-1',
        p_pg_onay: !!onay, p_pg_gerekce: gerekce || null });
    }`, t.ctx);
    t.doc.__setEl('pg-kapi-gerekce', { value: 'kontrol negatif' });
    await vm.runInContext(`(async () => {
      try { await cagri(false, null); } catch (e) { _pgKapiHata(e, cagri); }
    })()`, t.ctx);
    const box = kutuyuBagla(t.doc);
    await vm.runInContext(onaylaKodu(box), t.ctx);
    assert.strictEqual(t.pulls.length, 1, 'rpcAd yok: tek tazeleme, ölçülen: ' + t.pulls.length);
    // pulls[0] vm-realm dizisi — dış realm'e yayarak karşılaştır (prototip farkı).
    assert.deepStrictEqual([...t.pulls[0]], birlesim, 'liste RPC_TABLES birlesimi (sabit YOK)');
    assert.strictEqual(t.renders(), 1, 'render calisir');
  }
  // (b) rpcAd'li cagri: yalniz o RPC'nin seti tazelenir.
  {
    const t = kapiCtx({ rpc: async (ad, p) => {
      if (p && p.p_pg_onay === true) return { ok: true };
      throw new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01"}');
    } });
    vm.runInContext(`async function cagri2(onay, gerekce) {
      return rpc('hizli_uygulama', { p_pg_onay: !!onay, p_pg_gerekce: gerekce || null });
    }`, t.ctx);
    t.doc.__setEl('pg-kapi-gerekce', { value: 'kontrol negatif' });
    await vm.runInContext(`(async () => {
      try { await cagri2(false, null); } catch (e) { _pgKapiHata(e, cagri2, 'hizli_uygulama'); }
    })()`, t.ctx);
    const box = kutuyuBagla(t.doc);
    await vm.runInContext(onaylaKodu(box), t.ctx);
    assert.deepStrictEqual([...t.pulls[0]], T.hizli_uygulama, 'cagirana ozgu set');
    assert.strictEqual(t.renders(), 1, 'render calisir');
  }
});

// F2 KAPI-2 madde 2 (BLOKLAYAN): _pgKapiHata(e, cagri, sonra) — çağıran kendi başarı
// kapanışını geçirir; onaylı tekrar başarıda sonrayı çağırır (bayat ekran guard'ı).
// Adli mutant: MUT-SONRASIZ (sonra çağrısı silinirse __sonraSayi 0 kalır → FAIL).
test('sonra-onayli-tekrar-cagrilir', async () => {
  const rpcCagrilari = [];
  const { ctx, doc } = kapiCtx({
    rpc: async (ad, p) => {
      rpcCagrilari.push({ ad, p });
      if (p && p.p_pg_onay === true) return { ok: true };
      throw new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01"}');
    },
  });
  vm.runInContext(`var __sonraSayi = 0;
    async function cagri(onay, gerekce) {
      return rpc('treatment_day_tamamla', { p_day_id: 'gun-1',
        p_pg_onay: !!onay, p_pg_gerekce: gerekce || null });
    }
    async function sonra() { __sonraSayi++; }`, ctx);
  await vm.runInContext(`(async () => {
    try { await cagri(false, null); } catch (e) { _pgKapiHata(e, cagri, sonra); }
  })()`, ctx);
  const box = kutuyuBagla(doc);
  doc.__setEl('pg-kapi-gerekce', { value: 'kontrol negatif' });
  await vm.runInContext(onaylaKodu(box), ctx);
  assert.strictEqual(vm.runInContext('__sonraSayi', ctx), 1,
    'onaylı tekrar başarıda sonrayı 1 kez çağırır, ölçülen: ' + vm.runInContext('__sonraSayi', ctx));
  assert.ok(!doc.body.children.includes(box), 'başarıda modal kapanır');
});

// F2 KAPI-2 madde 2: sonra yoksa eski genel tazeleme korunur (geri-uyumluluk kilidi).
test('sonrasiz-genel-tazeleme-korunur', async () => {
  const t = kapiCtx({ rpc: async (ad, p) => {
    if (p && p.p_pg_onay === true) return { ok: true };
    throw new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01"}');
  } });
  vm.runInContext(`async function cagri0(onay, gerekce) {
    return rpc('hizli_uygulama', { p_pg_onay: !!onay, p_pg_gerekce: gerekce || null });
  }`, t.ctx);
  await vm.runInContext(`(async () => {
    try { await cagri0(false, null); } catch (e) { _pgKapiHata(e, cagri0, 'hizli_uygulama'); }
  })()`, t.ctx);
  const box = kutuyuBagla(t.doc);
  t.doc.__setEl('pg-kapi-gerekce', { value: 'kontrol negatif' });
  await vm.runInContext(onaylaKodu(box), t.ctx);
  assert.deepStrictEqual([...t.pulls[0]],
    ['uygulama_log', 'stok_hareket', 'gorev_log'], 'sonrasız çağrıda genel tazeleme koşar');
  assert.strictEqual(t.pulls.length, 1, 'tek tazeleme');
  assert.strictEqual(t.renders(), 1, 'render çalışır');
});

test('reddet-kapat-history-tekligi', async () => {
  // ROOT RULING 4 — MUT-PG-CIFT-PUSH adli: _pgKapiAc'deki
  // "ustte pg_kapi varsa push YOK" korumasi kaldirilirsa ikinci red
  // (onayli-tekrar reddinde yeniden render) yeni entry iter → net +2 → FAIL.
  // F turu KAPI-2 (sıkılaştırma, MEASURED back=1/son=null): MUT-KAPAT-BACKSIZ
  // (_pgKapiKapat history.back silinirse) backSayisi 0 + bayat pg_kapi → FAIL.
  const { ctx, doc, hist } = kapiCtx({ rpc: async () => ({ ok: true }) });
  const taban = hist.length;
  await vm.runInContext(`_pgKapiHata(new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01"}'), async () => ({}))`, ctx);
  kutuyuBagla(doc);
  await vm.runInContext(`(async () => {
    const r = async () => ({});
    _pgKapiHata(new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"TR-01"}'), r);
    _pgKapiKapat();
  })()`, ctx);
  assert.ok(hist.length - taban <= 1,
    'reddet→kapat net 0 ya da tek kayit, olculen: ' + (hist.length - taban));
  assert.strictEqual(hist.backSayisi, 1, 'kapat tek back iter, ölçülen: ' + hist.backSayisi);
  assert.ok(!(hist.state && hist.state.pg_kapi), 'son state pg_kapi DEĞİL (bayat kayıt yok)');
});

test('pg-kapi-ilk-acilis-tek-entry', async () => {
  // Kilit: ilk acilis entry iter (Android geri yakalar); fazlasi YOK.
  const { ctx, hist } = kapiCtx({});
  const taban = hist.length;
  await vm.runInContext(`_pgKapiHata(new Error('PG_KAPI:BLOCK_PREGNANT:{"kupe_no":"TR-02"}'), null)`, ctx);
  assert.strictEqual(hist.pushSayisi, 1, 'ilk acilis tam bir entry');
  assert.strictEqual(hist.length - taban, 1);
  assert.strictEqual(hist.state && hist.state.pg_kapi, true);
});
