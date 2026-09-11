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
const H_ANNEANNE = '44444444-4444-4444-8444-444444444444'; // dişi — büyükanne (pedigree farm)
const H_DEVANNE = '55555555-5555-4555-8555-555555555555'; // dişi — dev büyükanne (pedigree farm)
const T_GEBE = 'aaaaaaa1-0000-4000-8000-000000000001';
const T_BEKLIYOR = 'aaaaaaa2-0000-4000-8000-000000000002';

// ─── Pedigree projection fixture'ı (G-20260911-PEDIGREE-P2, W3-fix F2) ──────
// KONTRAT-ŞEKLİ (foundation chk_pedigree_nodes_kind_invariant birebir):
// farm_animal → farm_animal_id DOLU (freshStore hayvanlarına bağlı: E2E1/E2E2/
// E2E4/E2E5), external_animal → farm_animal_id null. 4 ata kuşağı; her kuşakta
// external sire. W3-fix öncesi GD/GGD farm_animal+null id idi — invariant ihlali.
const PED_F = '99999999-1111-4111-8111-000000000001';
const PED_D = '99999999-1111-4111-8111-000000000002';
const PED_S = '99999999-1111-4111-8111-000000000003';
const PED_GD = '99999999-1111-4111-8111-000000000004';
const PED_GS = '99999999-1111-4111-8111-000000000005';
const PED_GGD = '99999999-1111-4111-8111-000000000006';
const PED_GGS = '99999999-1111-4111-8111-000000000007';
const PED_GGGD = '99999999-1111-4111-8111-000000000008';

const PED_NODES = [
  { id: PED_F, kind: 'farm_animal', farm_animal_id: H_GEBE, label: 'E2E1', sex: 'Dişi', breed: 'Simental', birth_date: null },
  { id: PED_D, kind: 'farm_animal', farm_animal_id: H_BEKLIYOR, label: 'E2E2', sex: 'Dişi', breed: 'Simental', birth_date: null },
  { id: PED_S, kind: 'external_animal', farm_animal_id: null, label: 'EXT-BOGA-1', sex: 'Erkek', breed: 'Simental', birth_date: null },
  { id: PED_GD, kind: 'farm_animal', farm_animal_id: H_ANNEANNE, label: 'E2E4', sex: 'Dişi', breed: 'Simental', birth_date: null },
  { id: PED_GS, kind: 'external_animal', farm_animal_id: null, label: 'EXT-BOGA-2', sex: 'Erkek', breed: 'Simental', birth_date: null },
  { id: PED_GGD, kind: 'farm_animal', farm_animal_id: H_DEVANNE, label: 'E2E5', sex: 'Dişi', breed: 'Simental', birth_date: null },
  { id: PED_GGS, kind: 'external_animal', farm_animal_id: null, label: 'EXT-BOGA-3', sex: 'Erkek', breed: 'Simental', birth_date: null },
  { id: PED_GGGD, kind: 'external_animal', farm_animal_id: null, label: 'EXT-DIS-ATA', sex: 'Dişi', breed: 'Holştayn', birth_date: null },
];
const PED_EDGES = [
  { id: 'ped-e-1', source: PED_D, target: PED_F, role: 'dam', source_type: 'birth' },
  { id: 'ped-e-2', source: PED_S, target: PED_F, role: 'sire', source_type: 'birth' },
  { id: 'ped-e-3', source: PED_GD, target: PED_D, role: 'dam', source_type: 'birth' },
  { id: 'ped-e-4', source: PED_GS, target: PED_D, role: 'sire', source_type: 'birth' },
  { id: 'ped-e-5', source: PED_GGD, target: PED_GD, role: 'dam', source_type: 'birth' },
  { id: 'ped-e-6', source: PED_GGS, target: PED_GD, role: 'sire', source_type: 'birth' },
  { id: 'ped-e-7', source: PED_GGGD, target: PED_GGD, role: 'dam', source_type: 'birth' },
];
const PED_KNOWN_NODES = new Set(PED_NODES.map(n => n.id));
const PED_FARM_BY_NODE = new Map([
  [PED_F, H_GEBE], [PED_D, H_BEKLIYOR], [PED_GD, H_ANNEANNE], [PED_GGD, H_DEVANNE],
]);

// Yeniden-merkezleme (F2): istenen odak için GERÇEK alt graf — focus + atalar
// (istenen ancestor_depth'e kadar, kuşak katmanlı) + focus'un doğrudan
// yavruları (descendant_depth ≥ 1 ise). Odak VE derinlik değişince düğüm/kenar
// kümesi değişir; meta EFEKTİF değerleri taşır (W1 Task 3.2 sözleşmesi).
function pedigreeSubgraphFor(pFocusNodeId, pAncDepth, pDescDepth) {
  const ancLimit = Number.isInteger(pAncDepth) && pAncDepth >= 0 ? pAncDepth : 4;
  const descDepth = Number.isInteger(pDescDepth) && pDescDepth >= 0 ? pDescDepth : 1;
  const seviye = new Map([[pFocusNodeId, 0]]);
  let frontier = [pFocusNodeId];
  while (frontier.length) {
    const next = [];
    for (const id of frontier) {
      for (const e of PED_EDGES) {
        if (e.target === id && !seviye.has(e.source) && seviye.get(id) + 1 <= ancLimit) {
          seviye.set(e.source, seviye.get(id) + 1);
          next.push(e.source);
        }
      }
    }
    frontier = next;
  }
  const ids = new Set(seviye.keys());
  let yavruKusak = 0;
  if (descDepth >= 1) {
    for (const e of PED_EDGES) {
      if (e.source === pFocusNodeId) { ids.add(e.target); yavruKusak = 1; }
    }
  }
  return {
    focus: pFocusNodeId,
    nodes: PED_NODES.filter(n => ids.has(n.id)),
    edges: PED_EDGES.filter(e => ids.has(e.source) && ids.has(e.target)),
    meta: {
      ancestor_depth: Math.max(0, ...seviye.values()),
      descendant_depth: yavruKusak,
      truncated: false,
    },
  };
}

// W1 depth guard'ı (projection_rpc.sql:80,83): NULL/negatif reddedilir —
// kontrat-sadık 400; yalnız çağrıda hiç verilmemişse (undefined) default uygulanır.
function pedigreeDerinlik(v, varsayilan, ad) {
  if (v === undefined) return varsayilan;
  if (!Number.isInteger(v) || v < 0) {
    return { __httpStatus: 400, body: { message: `gecersiz ${ad} depth (NULL/negatif reddedilir): ${v}`, code: 'P0001' } };
  }
  return v;
}

// RPC çağrı sayaçları — E2E'de 4-kuşak focal akışının gerçekten RPC attığını
// kanıtlar (fake-arm karşıtı): tests/unit/pedigree-stub-backend.test.js iddia
// eder; e2e spec'leri tests/support/app.js re-export'u üzerinden okur;
// resetStore ile tazelenir.
export const pedigreeRpcCounts = {
  pedigree_subgraph: 0,
  pedigree_subgraph_for_animal: 0,
  pedigree_integrity_report: 0,
};

function pedigreeFixtureForNode(pFocusNodeId, pAncDepth, pDescDepth) {
  if (!PED_KNOWN_NODES.has(pFocusNodeId)) {
    // W1 kontratı: RAISE EXCEPTION (varsayılan errcode P0001 — projection_rpc.sql
    // USING ERRCODE kullanmaz; 'P0002' yanlış olurdu, review turunda düzeltildi)
    return { __httpStatus: 400, body: { message: `focus node bulunamadi ya da farkli farm: ${pFocusNodeId}`, code: 'P0001' } };
  }
  const anc = pedigreeDerinlik(pAncDepth, 4, 'ancestor');
  if (anc && anc.__httpStatus) return anc;
  const desc = pedigreeDerinlik(pDescDepth, 1, 'descendant');
  if (desc && desc.__httpStatus) return desc;
  return pedigreeSubgraphFor(pFocusNodeId, anc, desc);
}

function pedigreeFixtureForAnimal(pHayvanId, pAncDepth, pDescDepth) {
  let nodeId = null;
  for (const [k, hayvanId] of PED_FARM_BY_NODE) {
    if (hayvanId === pHayvanId) { nodeId = k; break; }
  }
  if (!nodeId) {
    // W1 kontratı: RAISE EXCEPTION (varsayılan errcode P0001)
    return { __httpStatus: 400, body: { message: `hayvan icin pedigree node bulunamadi ya da farkli farm: ${pHayvanId}`, code: 'P0001' } };
  }
  const anc = pedigreeDerinlik(pAncDepth, 4, 'ancestor');
  if (anc && anc.__httpStatus) return anc;
  const desc = pedigreeDerinlik(pDescDepth, 1, 'descendant');
  if (desc && desc.__httpStatus) return desc;
  return pedigreeSubgraphFor(nodeId, anc, desc);
}

function freshStore() {
  return {
    hayvanlar: [
      { id: H_GEBE, kupe_no: 'E2E1', devlet_kupe: 'TR-E2E-1', cinsiyet: 'Dişi', grup: 'Gebe İnek', padok: '', irk: 'Simental', durum: 'Aktif', kisir: false },
      { id: H_BEKLIYOR, kupe_no: 'E2E2', devlet_kupe: 'TR-E2E-2', cinsiyet: 'Dişi', grup: 'Düve (Büyük)', padok: '', irk: 'Holştayn', durum: 'Aktif', kisir: false },
      { id: H_ERKEK, kupe_no: 'E2E3', devlet_kupe: 'TR-E2E-3', cinsiyet: 'Erkek', grup: 'Boğa', padok: '', irk: 'Simental', durum: 'Aktif', kisir: false },
      { id: H_ANNEANNE, kupe_no: 'E2E4', devlet_kupe: 'TR-E2E-4', cinsiyet: 'Dişi', grup: 'Gebe İnek', padok: '', irk: 'Simental', durum: 'Aktif', kisir: false },
      { id: H_DEVANNE, kupe_no: 'E2E5', devlet_kupe: 'TR-E2E-5', cinsiyet: 'Dişi', grup: 'Düve (Büyük)', padok: '', irk: 'Simental', durum: 'Aktif', kisir: false },
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
  Object.keys(pedigreeRpcCounts).forEach(k => { pedigreeRpcCounts[k] = 0; });
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
  // ── Pedigree (Task 3 kontratı; G-20260911-PEDIGREE-P2) ──
  pedigree_subgraph: (p) => {
    pedigreeRpcCounts.pedigree_subgraph++;
    return pedigreeFixtureForNode(p && p.p_focus_node_id, p && p.p_ancestor_depth, p && p.p_descendant_depth);
  },
  pedigree_subgraph_for_animal: (p) => {
    pedigreeRpcCounts.pedigree_subgraph_for_animal++;
    return pedigreeFixtureForAnimal(p && p.p_hayvan_id, p && p.p_ancestor_depth, p && p.p_descendant_depth);
  },
  pedigree_integrity_report: () => {
    pedigreeRpcCounts.pedigree_integrity_report++;
    return { ok: true, issues: [] };
  },
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
    const out = handler(params);
    if (out && typeof out === 'object' && out.__httpStatus) {
      // Kontrat-sadık RPC hatası (gerçek RPC RAISE EXCEPTION → PostgREST 4xx +
      // {message, code}); supabase-js bunu {data: null, error} olarak verir.
      return json(route, out.__httpStatus, out.body || { message: 'rpc hata' });
    }
    return json(route, 200, out);
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
