// js/pedigree/pedigree-adapter.js
// Pedigree projection RPC çıktısı → Cytoscape element dizisi çevirisi (Task 6).
//
// SÖZLEŞME (G-20260911-PEDIGREE-P2-AGAC, W1 RPC dönüşü):
//   {focus: uuid, nodes: [{id, kind: farm_animal|external_animal,
//     farm_animal_id: <hayvanlar.id|null>, label, sex, breed, birth_date}],
//    edges: [{id, source(parent), target(child), role: dam|sire,
//     source_type: birth|…}], meta: {ancestor_depth, descendant_depth, truncated}}
//
// HESAP YOK: domain hesabı DB'de yapıldı; adapter yalnız çevirir. Sınıf
// ataması da hesap değil — yükteki yapısal sinyalin (kind, edge role'ü, aynı
// düğümün kaç çocuğu projede göründüğü) etiketlenmesidir.
//
// Güvenlik: değerler Cytoscape element data'sına düz JS string'i olarak girer
// (canvas'a çizilir, HTML'e interpolasyon yapılmaz); hiçbir alan markup
// üretmez. HTML bağlamına çıkacak değerler (external sheet) controller'da
// esc()/escAttr() ile kaçırılır — bu dosyanın sorumluluğu değil.
'use strict';

function _pedigreeSafeStr(val, fallback) {
  if (val === null || val === undefined) return fallback || '';
  const s = String(val);
  return s;
}

// Tek node kaydını Cytoscape node elementine çevirir. ctx: {focusId, childCount, childRoles}
function _pedigreeNodeToElement(n, ctx) {
  const id = _pedigreeSafeStr(n.id);
  if (!id) return null;
  const label = _pedigreeSafeStr(n.label) || _pedigreeSafeStr(n.farm_animal_id) || id;
  const kind = n.kind === 'farm_animal' || n.kind === 'external_animal' ? n.kind : null;
  const classes = [];
  if (ctx.focusId && id === ctx.focusId) classes.push('focus');
  classes.push(kind === 'farm_animal' ? 'farm' : kind === 'external_animal' ? 'external' : 'unknown');
  const roles = ctx.childRoles.get(id);
  if (roles && roles.has('dam')) classes.push('dam');
  if (roles && roles.has('sire')) classes.push('sire');
  if ((ctx.childCount.get(id) || 0) >= 2) classes.push('shared');
  return {
    group: 'nodes',
    data: {
      id: id,
      label: label,
      kind: kind || '',
      farm_animal_id: n.farm_animal_id === null || n.farm_animal_id === undefined ? '' : String(n.farm_animal_id),
      sex: _pedigreeSafeStr(n.sex),
      breed: _pedigreeSafeStr(n.breed),
      birth_date: _pedigreeSafeStr(n.birth_date),
    },
    classes: classes.join(' '),
  };
}

// RPC projection payload → {nodes:[], edges:[], meta:{}} Cytoscape element seti.
// Bozuk/eksik girdi patlamaz: null/{} → boş küme; uçları olmayan edge düşer.
function pedigreeToElements(payload) {
  const out = { nodes: [], edges: [], meta: (payload && typeof payload === 'object' && payload.meta) || {} };
  if (!payload || typeof payload !== 'object') return out;
  const rawNodes = Array.isArray(payload.nodes) ? payload.nodes : [];
  const rawEdges = Array.isArray(payload.edges) ? payload.edges : [];
  const focusId = payload.focus ? _pedigreeSafeStr(payload.focus) : '';

  // Paylaşılan ata tek element kalır — id başına ilk node kazanır.
  const seen = new Set();
  const nodes = [];
  for (const n of rawNodes) {
    if (!n || typeof n !== 'object') continue;
    const id = _pedigreeSafeStr(n.id);
    if (!id || seen.has(id)) continue;
    seen.add(id);
    nodes.push(n);
  }

  // Yapısal sinyaller: her düğümün projektindeki çocuk sayısı + rol kümesi.
  // Yalnız İKİ ucu da projeksiyonda görünen kenarlar sayılır — görünmeyen
  // çocuğa sahip ebeveyn hatalı 'shared' sınıfı almaz.
  const childCount = new Map();
  const childRoles = new Map(); // id -> Set(role)
  for (const e of rawEdges) {
    if (!e || typeof e !== 'object') continue;
    const src = _pedigreeSafeStr(e.source);
    const tgt = _pedigreeSafeStr(e.target);
    if (!src || !tgt || !seen.has(src) || !seen.has(tgt)) continue;
    childCount.set(src, (childCount.get(src) || 0) + 1);
    if (!childRoles.has(src)) childRoles.set(src, new Set());
    if (e.role) childRoles.get(src).add(String(e.role));
  }

  const ctx = { focusId: focusId, childCount: childCount, childRoles: childRoles };
  for (const n of nodes) {
    const el = _pedigreeNodeToElement(n, ctx);
    if (el) out.nodes.push(el);
  }

  // Edge yönü KORUNUR: source=parent → target=child (RPC'den birebir).
  // Uçları projeksiyonda görünmeyen edge Cytoscape'e giremez — düşürülür.
  const edgeSeen = new Set();
  for (const e of rawEdges) {
    if (!e || typeof e !== 'object') continue;
    const id = _pedigreeSafeStr(e.id);
    const source = _pedigreeSafeStr(e.source);
    const target = _pedigreeSafeStr(e.target);
    if (!source || !target || !seen.has(source) || !seen.has(target)) continue;
    const key = id || source + '→' + target;
    if (edgeSeen.has(key)) continue;
    edgeSeen.add(key);
    out.edges.push({
      group: 'edges',
      data: {
        id: key,
        source: source,
        target: target,
        role: e.role === null || e.role === undefined ? '' : String(e.role),
        source_type: e.source_type === null || e.source_type === undefined ? '' : String(e.source_type),
      },
    });
  }
  return out;
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, { pedigreeToElements });
}
