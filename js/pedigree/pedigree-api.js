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
// Davranış (plan 4.1): network RPC denenir → başarıda memory cache'e yazılır;
// network yok/iletim hatasında cache'te varsa aynı payload döner, yoksa açık
// "çevrimdışı" hatası (js/api.js rpc()'nin 'İnternet bağlantısı gerekli'
// hatası — mevcut tohumlama RPC'lerinin offline reddiyle aynı desen).
// Domain hesabı client'a taşınmaz: depth clamp/max guard yalnız RPC'de.
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

// B23 ile aynı sınıflandırma: yalnız gerçek iletim hataları "offline" sayılır.
// İki yol tanınır: (1) rpc()'nin iletim istisnalarına verdiği
// 'İnternet bağlantısı gerekli'; (2) _trErr haritasının (js/api.js) iletim
// sınıfı error gövdelerine verdiği 'Sunucuya ulaşılamıyor' — review bulgusu,
// aksi hâlde bu sınıf fallback'i atlar. Domain hataları (ok:false gövdeleri,
// 'Yetkisiz işlem' vb.) buraya girmez — cache'ten servis EDİLMEZ.
function _isTransportError(err) {
  const m = String((err && err.message) || err || '');
  return m.indexOf('İnternet bağlantısı') !== -1 ||
    m.indexOf('Sunucuya ulaşılamıyor') !== -1 ||
    /failed to fetch|networkerror|load failed/i.test(m);
}

// Ortak akış: dene → yaz; iletim hatası + cache isabeti → aynı payload
// (değer olarak — aşağıdaki savunma kopyaları yüzünden farklı nesne);
// aksi hâlde hatayı yükselt.
async function _pedigreeFetchCached(rpcName, focus, params) {
  const key = _pedigreeCacheKey(rpcName, focus, params);
  try {
    const data = await rpc(rpcName, params);
    // Savunma kopyaları (review bulgusu): çağıran (W3 adapter — cytoscape
    // element dönüşümü) payload'ı mutate edebilir; cache ve çağıran birbirinden
    // bağımsız kopyalar alır, "aynı payload" değeri olarak korunur.
    const snapshot = structuredClone(data);
    PEDIGREE_CACHE.set(key, snapshot);
    return structuredClone(snapshot);
  } catch (err) {
    if (_isTransportError(err) && PEDIGREE_CACHE.has(key)) {
      return structuredClone(PEDIGREE_CACHE.get(key));
    }
    throw err;
  }
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
