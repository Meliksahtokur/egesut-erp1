'use strict';
// Pedigree stub-backend birim testleri (W3-fix F1+F2 — luna review kapsamı).
//
// F1: RPC çağrı sayaçları artık iddialı — fake Playwright route/request ile
// gerçek dispatch yolu sürülür, sayaç artışı + resetStore sıfırlaması doğrulanır
// (E2E spec yüzeyi tests/support/app.js re-export'u; tüketen spec pedigree
// e2e'si yazıldığında bağlanacak — bkz. app.js yorumu).
//
// F2: fixture KONTRAT-ŞEKLİ — farm_animal → farm_animal_id dolu (foundation
// chk_pedigree_nodes_kind_invariant), external_animal → null; odak/derinlik
// değişince düğüm/kenar kümesi değişir (yeniden-merkezleme + depth guard);
// bilinmeyen hayvan/node id sessiz fallback değil kontrat-sadık 400 +
// {message, code:'P0001'} (W1 projection_rpc.sql:239 RAISE EXCEPTION —
// USING ERRCODE yok → PostgreSQL varsayılanı P0001, P0002 DEĞİL).
const { test } = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const STUB_PATH = pathToFileURL(path.join(__dirname, '..', 'support', 'stub-backend.js')).href;

const H_GEBE = '11111111-1111-4111-8111-111111111111';
const H_BEKLIYOR = '22222222-2222-4222-8222-222222222222';
const H_ANNEANNE = '44444444-4444-4444-8444-444444444444';
const H_DEVANNE = '55555555-5555-4555-8555-555555555555';
const PED_F = '99999999-1111-4111-8111-000000000001';
const PED_GD = '99999999-1111-4111-8111-000000000004';

// package.json "type" alanı typeless — ESM sözdizimli stub Node'un modül-tipi
// sezimine yaslanır (v22.7+/v26'ta sorunsuz; ≤22.6'da SyntaxError). O ortamda
// test dürüstçe skip olur — sahte yeşil değil.
let sbPromise = null;
function importGuvenli(t) {
  if (!sbPromise) {
    sbPromise = import(STUB_PATH).catch((e) => { sbPromise = null; throw e; });
  }
  return sbPromise.catch((e) => {
    t.skip(`stub-backend ESM import edilemedi (Node modül-tipi sezimi gerekli): ${e.message}`);
    return null;
  });
}

async function kur(t) {
  const sb = await importGuvenli(t);
  if (!sb) return null;
  let routeHandler = null;
  await sb.installStubBackend({ route: (glob, handler) => { routeHandler = handler; } });
  const fulfills = [];
  const route = { fulfill: (r) => fulfills.push(r) };
  const rpcIsteği = (fn, params) => routeHandler(route, {
    url: () => `https://vtzqjmazsvurxdeondmi.supabase.co/rest/v1/rpc/${fn}`,
    method: () => 'POST',
    postData: () => JSON.stringify(params),
  });
  const sonGovde = () => JSON.parse(fulfills[fulfills.length - 1].body);
  return { sb, routeHandler, fulfills, rpcIsteği, sonGovde };
}

function kontratSekliIddia(govde) {
  assert.ok(govde && Array.isArray(govde.nodes) && Array.isArray(govde.edges), 'RPC dönüş iskeleti');
  assert.ok(typeof govde.focus === 'string' && govde.focus, 'focus alanı dolu');
  for (const n of govde.nodes) {
    if (n.kind === 'farm_animal') {
      assert.ok(n.farm_animal_id, `farm düğüm farm_animal_id'siz olamaz (invariant): ${n.id}`);
    } else if (n.kind === 'external_animal') {
      assert.strictEqual(n.farm_animal_id, null, `external düğüm farm_animal_id taşımaz: ${n.id}`);
    } else {
      assert.fail(`bilinmeyen kind: ${n.kind}`);
    }
  }
  for (const e of govde.edges) {
    assert.ok(e.source && e.target, 'kenar uçları dolu');
    assert.ok(['dam', 'sire'].includes(e.role), 'rol dam|sire');
  }
}

test('sayaçlar iddialı: pedigree RPC dispatch sayaç artırır, resetStore sıfırlar', async (t) => {
  const ctx = await kur(t);
  if (!ctx) return;
  const { sb, rpcIsteği } = ctx;
  assert.strictEqual(sb.pedigreeRpcCounts.pedigree_subgraph_for_animal, 0, 'kurulum temiz başlar');
  await rpcIsteği('pedigree_subgraph_for_animal', { p_hayvan_id: H_GEBE, p_ancestor_depth: 4, p_descendant_depth: 1 });
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: PED_F });
  await rpcIsteği('pedigree_integrity_report', {});
  assert.strictEqual(sb.pedigreeRpcCounts.pedigree_subgraph_for_animal, 1);
  assert.strictEqual(sb.pedigreeRpcCounts.pedigree_subgraph, 1);
  assert.strictEqual(sb.pedigreeRpcCounts.pedigree_integrity_report, 1);
  sb.resetStore();
  assert.deepStrictEqual(sb.pedigreeRpcCounts, {
    pedigree_subgraph: 0, pedigree_subgraph_for_animal: 0, pedigree_integrity_report: 0,
  }, 'resetStore tüm sayaçları sıfırlar');
});

test('F2: fixture kontrat-şekli — farm dolu id, external null, her odakta geçerli', async (t) => {
  const ctx = await kur(t);
  if (!ctx) return;
  const { rpcIsteği, sonGovde } = ctx;
  for (const hayvan of [H_GEBE, H_BEKLIYOR, H_ANNEANNE, H_DEVANNE]) {
    await rpcIsteği('pedigree_subgraph_for_animal', { p_hayvan_id: hayvan });
    kontratSekliIddia(sonGovde());
  }
});

test('F2: yeniden-merkezleme — odak değişince düğüm/kenar kümesi değişir', async (t) => {
  const ctx = await kur(t);
  if (!ctx) return;
  const { rpcIsteği, sonGovde } = ctx;
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: PED_F });
  const fGovde = sonGovde();
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: PED_GD });
  const gdGovde = sonGovde();
  assert.strictEqual(fGovde.focus, PED_F);
  assert.strictEqual(gdGovde.focus, PED_GD);
  const fIds = fGovde.nodes.map((n) => n.id).sort().join(',');
  const gdIds = gdGovde.nodes.map((n) => n.id).sort().join(',');
  assert.notStrictEqual(fIds, gdIds, 'farklı odak → farklı düğüm kümesi');
  const fEdgeIds = fGovde.edges.map((e) => e.id).sort().join(',');
  const gdEdgeIds = gdGovde.edges.map((e) => e.id).sort().join(',');
  assert.notStrictEqual(fEdgeIds, gdEdgeIds, 'farklı odak → farklı kenar kümesi');
  // meta EFEKTİF (default ancestor_depth 4 ile): F 4 ata kuşağı görür, GD yalnız 2
  assert.strictEqual(fGovde.meta.ancestor_depth, 4);
  assert.strictEqual(gdGovde.meta.ancestor_depth, 2);
});

test('F2: depth parametresi düğüm kümesini gerçekten kısar (fake-arm karşıtı)', async (t) => {
  const ctx = await kur(t);
  if (!ctx) return;
  const { rpcIsteği, sonGovde } = ctx;
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: PED_F, p_ancestor_depth: 1 });
  const birKusak = sonGovde();
  assert.strictEqual(birKusak.nodes.length, 3, 'focus + 1. kuşak (anne+baba)');
  assert.strictEqual(birKusak.meta.ancestor_depth, 1);
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: PED_F, p_ancestor_depth: 2 });
  const ikiKusak = sonGovde();
  assert.strictEqual(ikiKusak.nodes.length, 5, 'focus + 2 kuşak ata');
  assert.strictEqual(ikiKusak.meta.ancestor_depth, 2);
});

test('negatif/NULL depth → kontrat-sadık 400 (W1 depth guard\'ı)', async (t) => {
  const ctx = await kur(t);
  if (!ctx) return;
  const { fulfills, rpcIsteği } = ctx;
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: PED_F, p_ancestor_depth: -1 });
  let son = fulfills[fulfills.length - 1];
  assert.strictEqual(son.status, 400);
  assert.ok(JSON.parse(son.body).message.includes('gecersiz ancestor depth'));
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: PED_F, p_descendant_depth: null });
  son = fulfills[fulfills.length - 1];
  assert.strictEqual(son.status, 400);
  assert.ok(JSON.parse(son.body).message.includes('gecersiz descendant depth'));
});

test('F2: bilinmeyen hayvan id sessiz fallback DEĞİL — kontrat-sadık 400 + P0001', async (t) => {
  const ctx = await kur(t);
  if (!ctx) return;
  const { fulfills, rpcIsteği, sonGovde } = ctx;
  // Karşılaştırma noktası: bilinen hayvan 200 + graf döner
  await rpcIsteği('pedigree_subgraph_for_animal', { p_hayvan_id: H_GEBE });
  assert.strictEqual(fulfills[fulfills.length - 1].status, 200);
  assert.ok(sonGovde().nodes.length > 0);
  // Bilinmeyen hayvan: W1 RAISE EXCEPTION davranışı (4xx; USING ERRCODE yok → P0001)
  await rpcIsteği('pedigree_subgraph_for_animal', { p_hayvan_id: 'YOK-KI-123' });
  const son = fulfills[fulfills.length - 1];
  assert.strictEqual(son.status, 400, 'sessiz odak-grafiği fallback yok — 4xx');
  const hata = JSON.parse(son.body);
  assert.ok(hata.message.includes('hayvan icin pedigree node bulunamadi'), 'W1 hata mesajı birebir');
  assert.strictEqual(hata.code, 'P0001', 'RAISE EXCEPTION varsayılan errcode');
});

test('bilinmeyen node id için de 400 (subgraph node-ekseni)', async (t) => {
  const ctx = await kur(t);
  if (!ctx) return;
  const { fulfills, rpcIsteği } = ctx;
  await rpcIsteği('pedigree_subgraph', { p_focus_node_id: '00000000-0000-4000-8000-ffffffffffff' });
  const son = fulfills[fulfills.length - 1];
  assert.strictEqual(son.status, 400, 'RAISE EXCEPTION → 4xx');
  const hata = JSON.parse(son.body);
  assert.ok(hata.message.includes('focus node bulunamadi'), 'W1 hata mesajı birebir');
});
