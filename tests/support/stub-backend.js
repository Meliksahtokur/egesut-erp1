// tests/support/stub-backend.js
// Demo-Mirror Supabase projesi erişilemez olduğunda (ör. paused → HTTP 540 /
// NXDOMAIN, 2026-09-01'de yaşandığı gibi) E2E spec'lerini KOŞULABİLİR kılan
// tarayıcı-içi sahte backend.
//
// İlkeler:
//   - YALNIZ demo origin'ini yakalar (vtzqjmazsvurxdeondmi.supabase.co) —
//     prod'a giden hiçbir istek üretilmez/engellenmez, prod DB'ye dokunulmaz.
//   - Gerçek ağ yok: page.route karşılarsa istek asla ağa çıkmaz → docker
//     ağ kısıtlarından ve demo pause'undan bağımsız.
//   - Aktifleştirme: PLAYWRIGHT_STUB_BACKEND=1 (PLAYWRIGHT_DEMO_MODE=1 ile
//     birlikte — storageState demo bayrağını ve IS_DEMO sabitlerini besler).
//     Demo projesi ayakta olduğunda bu bayrak KULLANILMAZ; spec'ler gerçek
//     demo klon DB'sine koşar.
//
// Sağladığı mini-PostgREST davranışı:
//   GET  /rest/v1/<table|view>      → store satırları (view adları eşlenir)
//   POST /rest/v1/<table>           → store'a INSERT + kayıt (insertLog)
//   PATCH /rest/v1/<t>?id=eq.<id>   → store'da UPDATE, temsilî [{id}] dönüşü
//   POST /rest/v1/rpc/<fn>          → fn başına iş kuralı mutasyonu + {ok:true}
//   POST /auth/v1/token             → sahte GoTrue oturumu (demo autologin)

// ─── Deterministik fixture verisi (veri-agnosticliğin stub'daki hali) ───────
const D = (n) => {
  const d = new Date(); d.setDate(d.getDate() - n);
  return d.toISOString().slice(0, 10);
};

const H_GEBE = '11111111-1111-4111-8111-111111111111'; // dişi — gebe
const H_BEKLIYOR = '22222222-2222-4222-8222-222222222222'; // dişi — bekliyor tohumlama
const H_ERKEK = '33333333-3333-4333-8333-333333333333'; // erkek — filtre ayrışımı için
const T_GEBE = 'aaaaaaa1-0000-4000-8000-000000000001';
const T_BEKLIYOR = 'aaaaaaa2-0000-4000-8000-000000000002';

function freshStore() {
  return {
    hayvanlar: [
      { id: H_GEBE, kupe_no: 'E2E1', devlet_kupe: 'TR-E2E-1', cinsiyet: 'Dişi', grup: 'Gebe İnek', padok: '', irk: 'Simental', durum: 'Aktif', kisir: false },
      { id: H_BEKLIYOR, kupe_no: 'E2E2', devlet_kupe: 'TR-E2E-2', cinsiyet: 'Dişi', grup: 'Düve (Büyük)', padok: '', irk: 'Holştayn', durum: 'Aktif', kisir: false },
      { id: H_ERKEK, kupe_no: 'E2E3', devlet_kupe: 'TR-E2E-3', cinsiyet: 'Erkek', grup: 'Boğa', padok: '', irk: 'Simental', durum: 'Aktif', kisir: false },
    ],
    tohumlama: [
      { id: T_GEBE, hayvan_id: H_GEBE, sperma: 'E2E Sperma A', tarih: D(40), sonuc: 'Gebe', deneme_no: 1 },
      { id: T_BEKLIYOR, hayvan_id: H_BEKLIYOR, sperma: 'E2E Sperma B', tarih: D(3), sonuc: 'Bekliyor', deneme_no: 1 },
    ],
    gorev_log: [],
    // geri kalan tablolar boş — uygulama bunlarla açılır (loadHekimler fallback
    // config kullanır, boş listeler 'yok' state'i render eder)
  };
}

// View → gerçek tablo eşlemesi (api.js FETCHERS view adlarıyla çeker)
const VIEW_MAP = {
  hayvan_durum_view: 'hayvanlar',
  v_gorev_log_sync: 'gorev_log',
  stok_tuketim_view: 'stok',
};

const DEMO_ORIGIN = 'https://vtzqjmazsvurxdeondmi.supabase.co';

// Worker başına tek store (route handler'ı ile test aynı worker sürecinde).
// Nesne kimliği sabit, içerik resetStore ile tazelenir — her test deterministik
// fixture ile başlar (paralel/tekrar koşumdan bağımsız).
export const store = {};
export const insertLog = []; // {table, rows, ts}
export const rpcLog = []; // {fn, params, ts}

export function resetStore() {
  Object.keys(store).forEach(k => delete store[k]);
  Object.assign(store, freshStore());
  insertLog.length = 0;
  rpcLog.length = 0;
}

function json(route, status, body) {
  return route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
}

const RPCS = {
  gorev_tamamla: (p) => {
    const row = store.gorev_log.find(r => r.id === p.p_gorev_id);
    if (row) { row.tamamlandi = true; row.tamamlanma_tarihi = new Date().toISOString(); }
    return { ok: true };
  },
  gorev_geri_al: (p) => {
    const row = store.gorev_log.find(r => r.id === p.p_gorev_id);
    if (row) { row.tamamlandi = false; row.tamamlanma_tarihi = null; }
    return { ok: true, silinen_rapel: 0 };
  },
  tohumlama_sonuc_gebe: (p) => {
    const row = store.tohumlama.find(t => t.id === p.p_tohumlama_id);
    if (row) row.sonuc = 'Gebe';
    return { ok: true };
  },
  tohumlama_sonuc_bos: (p) => {
    const row = store.tohumlama.find(t => t.id === p.p_tohumlama_id);
    if (row) row.sonuc = 'Boş';
    return { ok: true };
  },
  tohumlama_sonuc_bekliyor: (p) => {
    const row = store.tohumlama.find(t => t.id === p.p_tohumlama_id);
    if (row) row.sonuc = 'Bekliyor';
    return { ok: true };
  },
  protokol_eksik_tara: () => [],
};

function stubSession() {
  return {
    access_token: 'stub-access-token',
    refresh_token: 'stub-refresh-token',
    expires_in: 86400,
    expires_at: Math.floor(Date.now() / 1000) + 86400,
    token_type: 'Bearer',
    user: {
      id: '00000000-0000-4000-8000-0000000000ff',
      email: 'demo@stub.local',
      aud: 'authenticated', role: 'authenticated',
      app_metadata: { provider: 'email' }, user_metadata: {},
      created_at: '2026-01-01T00:00:00Z',
    },
  };
}

async function handleRest(route, request) {
  const url = new URL(request.url());
  const path = decodeURIComponent(url.pathname); // /rest/v1/<resource>
  const parts = path.split('/').filter(Boolean); // ['rest','v1',...]
  const method = request.method();

  // ── RPC ──
  if (parts[2] === 'rpc' && parts[3] && method === 'POST') {
    const fn = parts[3];
    let params = {};
    try { params = JSON.parse(request.postData() || '{}'); } catch { /* boş gövde */ }
    rpcLog.push({ fn, params, ts: Date.now() });
    const handler = RPCS[fn];
    if (!handler) return json(route, 200, { ok: true }); // bilinmeyen RPC: iyimser ok
    return json(route, 200, handler(params));
  }

  // ── Auth (demo autologin) — path: /auth/v1/... → parts[0]='auth' ──
  if (parts[0] === 'auth') {
    if (path.includes('/token')) return json(route, 200, stubSession());
    if (method === 'DELETE') return json(route, 204, {});
    return json(route, 200, {});
  }

  // ── Tablo işlemleri ──
  const resource = parts[2] || '';
  const table = VIEW_MAP[resource] || resource;
  if (!table || table.startsWith('_')) return json(route, 200, []);

  if (method === 'GET') {
    store[table] = store[table] || [];
    return json(route, 200, store[table]);
  }

  if (method === 'POST') {
    if (!store[table]) {
      // Var olmayan tablo → PostgREST 42P01 (B17 zehirli kayıt senaryosu)
      return json(route, 404, { message: `relation "${table}" does not exist`, code: '42P01', hint: null, details: null });
    }
    let rows = [];
    try { const b = JSON.parse(request.postData() || '[]'); rows = Array.isArray(b) ? b : [b]; } catch { rows = []; }
    rows.forEach(r => { if (!r.id) r.id = crypto.randomUUID(); store[table].push(r); });
    insertLog.push({ table, rows, ts: Date.now() });
    return json(route, 201, rows);
  }

  if (method === 'PATCH') {
    const idMatch = (url.searchParams.get('id') || '').match(/^eq\.(.+)$/);
    const targetId = idMatch ? idMatch[1] : null;
    let changes = {};
    try { const b = JSON.parse(request.postData() || '{}'); changes = Array.isArray(b) ? b[0] : b; } catch { /* boş */ }
    const arr = (store[table] = store[table] || []);
    const idx = arr.findIndex(r => r.id === targetId);
    if (idx === -1) return json(route, 200, []); // dead-target → dbUpdate hata fırlatır
    Object.assign(arr[idx], changes, { id: targetId });
    return json(route, 200, [{ id: targetId }]);
  }

  if (method === 'DELETE') {
    const idMatch = (url.searchParams.get('id') || '').match(/^eq\.(.+)$/);
    if (idMatch) store[table] = (store[table] || []).filter(r => r.id !== idMatch[1]);
    return json(route, 204, {});
  }

  return json(route, 200, []);
}

// Sayfa/context için stub'ı kur — goto'dan ÖNCE çağrılır; her kurulumda store
// taze fixture'a döner (testler arası sızıntı yok).
export async function installStubBackend(scope) {
  resetStore();
  await scope.route(DEMO_ORIGIN + '/**', handleRest);
}
