// js/pedigree/pedigree-api.js
// P2 Task 4 — Pedigree API wrapper + oturumluk memory cache.
// Plan: .claude/plans/2026-09-10-pedigree-genetics-impl.md (Rev 3.1, Task 4).
//
// Arayüz (W3 pedigree-adapter buna karşı kodluyor — birebir korunur):
//   pedigreeApi.subgraphForAnimal(hayvanId, ancestorDepth?, descendantDepth?)
//   pedigreeApi.subgraphForNode(nodeId, ancestorDepth?, descendantDepth?)
//   pedigreeApi.integrityReport()
//   pedigreeApi.invalidateCache()
//
// Davranış (W2-fix, cache-first — lead demo kapısı ölçümüyle netleşti; goal G5
// "zaten açılmış görünüm memory cache'ten"): sıcak cache anahtarı ağa hiç
// gitmeden servis edilir (meta.cached=true); cache miss'te network RPC denenir
// → başarıda cache'e yazılır (meta.cached=false döner); miss + ağ hatasında
// açık "çevrimdışı" hatası (js/api.js rpc()'nin hatası — mevcut tohumlama
// RPC'lerinin offline reddiyle aynı desen). Graph-write sonrası invalidateCache
// cache'i tamamen boşalttığı için tazelik write noktasında garanti altındadır
// (kablolar P3'te). Domain hesabı client'a taşınmaz: depth clamp/max guard
// yalnız RPC'de.
//
// BİLİNEN SINIRLAR (bilinçli tasarım — plan 4.2): cache oturumluk ve TEK
// SEKME ölçeğindedir — başka sekme/cihazdan yapılan parentage değişikliği bu
// sekmede write tetiklenene (invalidate) ya da sekme kapanana kadar yeniden
// doğrulanmaz; invalidateCache yalnız kendi sekmesinin Map'ini boşaltır.
//
// YASAKLAR (Rev 3 küçültme — geri dönme): js/api.js'e DB_VER/IDB dokunuşu,
// RPC_TABLES'a pseudo tablo, auth.js, epoch/protokol değişikliği.
//
// Yükleme sırası: js/api.js'ten SONRA (network katmanı = api.js'in global
// rpc() wrapper'ı — hata normalleştirme tek noktada kalır).
'use strict';

// B2 (lead kapı düzeltmesi): planın js/config.js'teki PEDIGREE_FARM_ID sabiti
// YOK ve config.js goal manifest'i dışında → sabit modül-içinde tutulur.
// Tek-çiftlik dağıtımı; farm-scope önek anahtar çakışmasını önler.
const PEDIGREE_FARM_ID = 'default';

// Cache anahtarı sürümü: projection/algo davranışı değişince artırılır,
// eski anahtarlar doğal bayatlar (oturumluk cache — kalıcılık yok).
const PEDIGREE_ALGO_VERSION = 1;

// RPC defaultları (Task 3 imzası: p_ancestor_depth default 4, p_descendant_depth
// default 1). Wrapper aynen iletir; clamp YOK — guard RPC'nin işi.
const PEDIGREE_DEFAULT_ANCESTOR_DEPTH = 4;
const PEDIGREE_DEFAULT_DESCENDANT_DEPTH = 1;

// Oturumluk memory cache — feature scope'unda TEK Map. Buildless ders: classic
// script'te top-level const globalThis'a çıkmaz; sekmeler-arası paylaşılmaması
// istenen davranıştır (plan 4.2). Logout/sekme kapanışıyla doğal olarak ölür.
const PEDIGREE_CACHE = new Map();

// Anahtar: farm:<farm_id>:<rpc>:<focus>:<params>:v<algo_version>
// params anahtar-sıra-bağımsız serileştirilir (deterministik anahtar).
function _pedigreeCacheKey(rpcName, focus, params) {
  const sorted = {};
  Object.keys(params).sort().forEach(k => {
    sorted[k] = params[k] === undefined ? null : params[k];
  });
  return 'farm:' + PEDIGREE_FARM_ID + ':' + rpcName + ':' + focus + ':' +
    JSON.stringify(sorted) + ':v' + PEDIGREE_ALGO_VERSION;
}

// meta.cached mührü (W2-fix) — yalnız DÖNÜŞ sınırında uygulanır; saklanan
// snapshot W1 RPC kontratından (ancestor_depth/descendant_depth/truncated)
// bozulmadan kalır. Ağdan gelenlerde false, cache'ten servis edilenlerde true.
function _sealCached(payload, cached) {
  if (payload && !Array.isArray(payload) && typeof payload === 'object') {
    if (!payload.meta || typeof payload.meta !== 'object') payload.meta = {};
    payload.meta.cached = cached;
  }
  return payload;
}

// Ortak akış (W2-fix, cache-first — lead demo kapısı ölçümü: 3 açılışta 3 RPC
// atılıyordu; goal G5 "zaten açılmış görünüm memory cache'ten" ONLİNE'da
// karşılanmalı): sıcak anahtar ağa HİÇ gitmez; ağ yalnız cache miss'te denenir.
// Miss + ağ hatası → rpc()'nin açık çevrimdışı hatası aynen yükselir
// ('İnternet bağlantısı gerekli' / _trErr 'Sunucuya ulaşılamıyor').
// Savunma kopyaları (review bulgusu) korunur: çağıran (W3 adapter — cytoscape
// element dönüşümü) payload'ı mutate edebilir; cache ve çağıran bağımsız
// kopyalar alır.
async function _pedigreeFetchCached(rpcName, focus, params) {
  const key = _pedigreeCacheKey(rpcName, focus, params);
  if (PEDIGREE_CACHE.has(key)) {
    return _sealCached(structuredClone(PEDIGREE_CACHE.get(key)), true);
  }
  const data = await rpc(rpcName, params);
  PEDIGREE_CACHE.set(key, structuredClone(data));
  return _sealCached(structuredClone(data), false);
}

/**
 * Hayvan id'sinden focal soy alt grafiğini getirir (cache'li).
 * @param {string} hayvanId - hayvanlar.id (text)
 * @param {number} [ancestorDepth=4]
 * @param {number} [descendantDepth=1]
 * @returns {Promise<{focus, nodes, edges, meta}>} Task 3 dönüş kontratı
 */
async function subgraphForAnimal(hayvanId, ancestorDepth = PEDIGREE_DEFAULT_ANCESTOR_DEPTH,
                                 descendantDepth = PEDIGREE_DEFAULT_DESCENDANT_DEPTH) {
  if (!hayvanId) throw new Error('hayvanId zorunlu');
  const params = {
    p_hayvan_id: String(hayvanId),
    p_ancestor_depth: ancestorDepth,
    p_descendant_depth: descendantDepth,
  };
  return _pedigreeFetchCached('pedigree_subgraph_for_animal', String(hayvanId), params);
}

/**
 * Node uuid'sinden focal soy alt grafiğini getirir (cache'li).
 * @param {string} nodeId - projection node uuid
 * @param {number} [ancestorDepth=4]
 * @param {number} [descendantDepth=1]
 * @returns {Promise<{focus, nodes, edges, meta}>}
 */
async function subgraphForNode(nodeId, ancestorDepth = PEDIGREE_DEFAULT_ANCESTOR_DEPTH,
                               descendantDepth = PEDIGREE_DEFAULT_DESCENDANT_DEPTH) {
  if (!nodeId) throw new Error('nodeId zorunlu');
  const params = {
    p_focus_node_id: String(nodeId),
    p_ancestor_depth: ancestorDepth,
    p_descendant_depth: descendantDepth,
  };
  return _pedigreeFetchCached('pedigree_subgraph', String(nodeId), params);
}

/**
 * Soy bütünlük raporu (p_focus yok — focus '-' anahtar diliminde).
 * @returns {Promise<object>} pedigree_integrity_report() sonucu
 */
async function integrityReport() {
  return _pedigreeFetchCached('pedigree_integrity_report', '-', {});
}

/**
 * Cache TAMAMEN boşaltılır (hedefli invalidation YOK — plan 4.3).
 * Graph-write RPC'leri (pedigree_parent_set, pedigree_external_upsert,
 * semen_catalog_upsert, dogum_kaydet) başarıdan sonra bunu çağırmalı.
 * P2'de yazma yolları P3'te: invalidate yüzeyi + unit test bu bandın kapsamı.
 */
function invalidateCache() {
  PEDIGREE_CACHE.clear();
}

const pedigreeApi = {
  subgraphForAnimal,
  subgraphForNode,
  integrityReport,
  invalidateCache,
};

window.pedigreeApi = pedigreeApi;
