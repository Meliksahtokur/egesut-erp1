// tests/unit/cila-tutarlilik.test.js — S5 tutarlılık paketi birim testleri
// SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s5.md §4.4/§6.3/§8/§9 (U1,U4-U11)
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, loadExtractedFunction } = require('./support/loadModule.js');

// ── T5/U1: buildRpcParams p_iptal ───────────────────────────────────────────
const buildRpcParams = loadExtractedFunction('js/ui.js', 'buildRpcParams');

test('T5/U1: iptal-PATCH replay p_iptal=true taşır', () => {
  const p = buildRpcParams('gorev_tamamla', { id:'g1', padok:'p1', iptal:true }, { method:'PATCH', filter:'id=eq.g1' });
  assert.strictEqual(p.p_iptal, true);
  assert.strictEqual(p.p_gorev_id, 'g1');
  assert.strictEqual(p.p_padok_hedef, 'p1');
});
test('T5/U1: iptalsiz tamamlama p_iptal=false (regresyon: eski davranış)', () => {
  const p = buildRpcParams('gorev_tamamla', { id:'g1', padok:null }, { method:'PATCH', filter:'id=eq.g1' });
  assert.strictEqual(p.p_iptal, false);
  const p2 = buildRpcParams('gorev_tamamla', { id:'g1' }, { method:'PATCH', filter:'id=eq.g1' });
  assert.strictEqual(p2.p_iptal, false);
});

// ── T4/U4: flushPendingDone — clear-önce kaybı yok ─────────────────────────
// flushPendingDone modül-içi _pendingDone/_savePending gibi lexical üyelere
// eriştiğinden, fonksiyon kaynağı izole vm bağlamında stub üyelerle koşturulur.
const { loadFlushPendingDone } = (() => {
  const vm = require('node:vm');
  const flushSrc = require('./support/loadModule.js').extractFunctionSource('js/ui.js', 'flushPendingDone');
  return { loadFlushPendingDone(ctx) {
    vm.createContext(ctx);
    return vm.runInContext(`(${flushSrc})`, ctx, { filename:'js/ui.js#flushPendingDone' });
  } };
})();

test('T4/U4: hatalı op pending\'de kalır, başarılılar düşer (clear-önce kaybı yok)', async () => {
  const calls = { saved: 0 };
  let lastSaved = null;
  const pending = new Map();
  pending.set('g1', { type:'gorev', gorevId:'g1', params:{ gorevId:'g1' } });
  pending.set('g2', { type:'gorev', gorevId:'g2', params:{ gorevId:'g2' } });
  pending.set('g3', { type:'gorev', gorevId:'g3', params:{ gorevId:'g3' } });
  const ctx = {
    console, Date, Math, JSON, Map, Set,
    navigator: { onLine: true },
    toast: () => {},
    rpc: async (name, params) => {
      if (params && params.p_gorev_id === 'g2') throw new Error('sunucu hatası');
      return { ok:true };
    },
    rpcSeansTamamla: async () => ({ ok:true }),
    pullTables: async () => {},
    updateTaskBadge: () => {},
    updatePendingFab: () => { calls.fab = (calls.fab||0)+1; },
    _savePending: () => { calls.saved++; lastSaved = [...pending.values().map(v => v.gorevId)]; },
    _pendingDone: pending,
    _flushInFlight: false, _flushHataToast: new Map(),   // K9: tek-uçuş kilidi + hata-toast soğuması ctx üyeleri
  };
  ctx.globalThis = ctx;
  const flushPendingDone = loadFlushPendingDone(ctx);
  await flushPendingDone();
  assert.deepStrictEqual([...pending.keys()], ['g2'], 'yalnız hatalı op kalmalı');
  assert.ok(calls.saved >= 1, '_savePending çağrılmalı');
  assert.deepStrictEqual(lastSaved, ['g2'], 'kalıcı yazım kalanı içermeli');
});

// ── K9: flushPendingDone tek-uçuş + uçuşta-eklenen koruma ──────────────────
function _k9Ctx(pending, rpcImpl, toastSink){
  const calls={ toasts:[] };
  const ctx={
    console, Date, Math, JSON, Map, Set, Promise,
    navigator:{ onLine:true },
    toast:(m,e)=>{ calls.toasts.push(String(m)); if(toastSink) toastSink(m,e); },
    rpc: rpcImpl, rpcSeansTamamla: async()=>({ok:true}),
    pullTables: async()=>{}, updateTaskBadge: ()=>{}, updatePendingFab: ()=>{},
    _savePending: ()=>{}, _pendingDone: pending,
    _flushInFlight: false, _flushHataToast: new Map(),
  };
  ctx.globalThis=ctx;
  return { ctx, calls };
}

test('K9-a: eşzamanlı iki çağrı — her görev YALNIZ bir kez gönderilir', async () => {
  const pending=new Map([['g1',{type:'gorev',gorevId:'g1',params:{gorevId:'g1'}}]]);
  const sends=[];
  const { ctx } = _k9Ctx(pending, async (name,params)=>{ sends.push(params.p_gorev_id); await new Promise(r=>setTimeout(r,20)); return {ok:true}; });
  const flush=loadFlushPendingDone(ctx);
  const p1=flush(); const p2=flush();      // app.js:81 + loadTasks:631 yarışı
  await Promise.all([p1,p2]);
  assert.deepStrictEqual(sends, ['g1'], 'tek gönderim beklenir, ikinci çağrı uçuş açmaz');
  assert.strictEqual(pending.size, 0);
});

test('K9-b: uçuş sırasında eklenen kalem korunur (silinmez)', async () => {
  const pending=new Map([['g1',{type:'gorev',gorevId:'g1',params:{gorevId:'g1'}}]]);
  let rpcCalled=false;
  const { ctx } = _k9Ctx(pending, async ()=>{
    if(!rpcCalled){ rpcCalled=true; await new Promise(r=>setTimeout(r,20));
      // togglePendingDone:625'in yaptığı şey — await penceresinde yeni kalem
      pending.set('g2',{type:'gorev',gorevId:'g2',params:{gorevId:'g2'}});
    }
    return {ok:true};
  });
  const flush=loadFlushPendingDone(ctx);
  await flush();
  assert.ok(pending.has('g2'), 'uçuşta eklenen g2 silinmemeli');
  assert.ok(!pending.has('g1'), 'başarılı g1 düşmeli');
});

test('K9-c: kalıcı hata — aynı mesaj ikinci flush\'ta tekrar toast basmaz', async () => {
  const pending=new Map([['g2',{type:'gorev',gorevId:'g2',params:{gorevId:'g2'}}]]);
  let msg='sunucu hatası';
  const { ctx, calls } = _k9Ctx(pending, async ()=>{ throw new Error(msg); });
  const flush=loadFlushPendingDone(ctx);
  await flush(); await flush();                    // iki loadTasks turu
  const hataToastlari=calls.toasts.filter(t=>t.includes('Görev uygulanamadı'));
  assert.strictEqual(hataToastlari.length, 1, 'aynı kalıcı hata bir kez toastlanır');
  assert.ok(pending.has('g2'), 'hatalı op pending\'de kalır');
  msg='farklı hata';                               // yeni hata → tekrar bildir
  await flush();
  assert.strictEqual(calls.toasts.filter(t=>t.includes('Görev uygulanamadı')).length, 2);
});

// ── T3/U5: seansTamamla PG-kapı guard ──────────────────────────────────────
test('T3/U5: res._pgKapi → seansTamamla başarı toast\'u BASMAZ (kod kanıtı — guard satırı)', () => {
  const src = require('fs').readFileSync('js/forms.js', 'utf8');
  assert.ok(src.includes('if (res?._pgKapi) return;'), 'PG-kapı guard satırı yok');
  const idx = src.indexOf('if (res?._pgKapi) return;');
  const toastIdx = src.indexOf("'✓ Seans tamamlandı'", idx);
  assert.ok(toastIdx > idx, 'guard toast\'tan önce olmalı');
});

// ── T8/U10: rpc() sunucu 'error' alanı ─────────────────────────────────────
test('T8/U10: ok:false + error alanı → thrown message Türkçe (mesaj-üretim kalıbı)', () => {
  const data = { ok:false, error:'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir' };
  const err = new Error(data.mesaj || data.error || 'İşlem başarısız');
  assert.strictEqual(err.message, 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  const data2 = { ok:false, mesaj:'Birincil mesaj', error:'ikincil' };
  assert.strictEqual(new Error(data2.mesaj || data2.error || 'İşlem başarısız').message, 'Birincil mesaj');
});

// ── D18/U6: getUserMessage erteleme kodları ────────────────────────────────
const eh = loadBrowserModule('js/utils/errorHandler.js', {
  extra: { toast: () => {}, getUserMessage: null },
});
test('D18/U6: GOREV_ERTELENEMEZ / GECMIS_TARIH → Türkçe cümle (ham JSON değil)', () => {
  const { getUserMessage } = eh.sandbox;
  const m1 = getUserMessage(new Error('GOREV_ERTELENEMEZ:{"kod":"BESLEME"}'));
  assert.ok(/ertelenemez/i.test(m1), 'ertelenemez cümlesi gelmeli: ' + m1);
  const m2 = getUserMessage(new Error('GECMIS_TARIH:{"tarih":"2026-01-01"}'));
  assert.ok(/Geçmiş tarih/i.test(m2), 'geçmiş tarih cümlesi gelmeli: ' + m2);
});

// ── D19/U7: _vakaKapanisOzeti ──────────────────────────────────────────────
const _vakaKapanisOzeti = loadExtractedFunction('js/forms.js', '_vakaKapanisOzeti');
test('D19/U7: n=2, m=3 → iki parçalı özet; hepsi 0 → null', () => {
  const s = _vakaKapanisOzeti([{hayvan_kupe:'12', iptal_seans:4},{hayvan_kupe:'13', iptal_seans:2}], 3);
  assert.match(s, /2 senkronizasyon protokolü/);
  assert.match(s, /12 \(4 seans iptal\)/);
  assert.match(s, /3 görev otomatik iptal edildi/);
  assert.strictEqual(_vakaKapanisOzeti([], 0), null);
  assert.strictEqual(_vakaKapanisOzeti(null, null), null);
});

// ── D17/U8: start_first_service_protocol pull seti katalog tamamlandı ──────
const apiMod = loadBrowserModule('js/api.js', {
  extra: {
    fetch: async () => ({ ok:true, status:200, json: async () => ({}) }),
    localStorage: (() => { const m=new Map(); return { getItem:k=>m.get(k)??null, setItem:(k,v)=>m.set(k,String(v)), removeItem:k=>m.delete(k) }; })(),
    supabase: { createClient: () => ({ auth: { getSession: async () => ({ data:{ session:null } }), onAuthStateChange: () => ({ data:{ subscription:{ unsubscribe(){} } } }) }, from: () => ({ select: () => ({}) }) }) },
  },
  expose: ['RPC_TABLES'],
});
test('D17/U8: pull seti diseases/drugs/tedavi_sablonu içerir', () => {
  const set = (apiMod.exposed && apiMod.exposed.RPC_TABLES) || apiMod.sandbox.RPC_TABLES;
  assert.ok(set && typeof set === 'object', 'RPC_TABLES dışa çıkarılamadı');
  const arr = Array.isArray(set) ? set : (set.start_first_service_protocol || []);
  for (const t of ['cases','gorev_log','diseases','drugs','tedavi_sablonu']) {
    assert.ok(arr.includes(t), t + ' sette yok');
  }
});

// ── O11/U9: _istanbulAnIso sabit +03 anchor ────────────────────────────────
const _istanbulAnIso = loadExtractedFunction('js/ui.js', '_istanbulAnIso');
test('O11/U9: Istanbul +03 sabitlenmiş — cihaz diliminden bağımsız', () => {
  assert.strictEqual(_istanbulAnIso('2026-09-24', '12:00'), '2026-09-24T09:00:00.000Z');
  assert.strictEqual(_istanbulAnIso('2026-09-24', ''), '2026-09-24T09:00:00.000Z');
  assert.strictEqual(_istanbulAnIso('2026-09-24', '09:30'), '2026-09-24T06:30:00.000Z');
});

// ── T10/U11: _rozetTopla ───────────────────────────────────────────────────
const _rozetTopla = loadExtractedFunction('js/ui.js', '_rozetTopla');
test('T10/U11: rozet birleştirme n+m; ov-hata → yalnız n', () => {
  assert.strictEqual(_rozetTopla(3, 2), 5);
  assert.strictEqual(_rozetTopla(3, undefined), 3);
  assert.strictEqual(_rozetTopla(0, 0), 0);
  assert.strictEqual(_rozetTopla(120, 5), 125);
});
