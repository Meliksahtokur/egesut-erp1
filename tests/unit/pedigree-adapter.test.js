'use strict';
// Pedigree adapter birim testleri (Task 6 — G3d birim düzeyi kanıt).
// RPC projection payload → Cytoscape element çevirisi sözleşmesini kilitler:
//   1. parent→child edge yönü korunur (source=parent, target=child)
//   2. shared node tek element kalır (duplicate edilmez)
//   3. HTML/user stringler element data'ya güvenli girer (düz string — markup üretimi yok)
//   4. missing optional fields crash etmez; bozuk payload boş küme döner
// TESTING-01: loadBrowserModule ile product modülü yüklenir, kaynak kopyalanmaz.
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule');

const { sandbox } = loadBrowserModule('js/pedigree/pedigree-adapter.js');
const toElements = sandbox.pedigreeToElements;

const F = 'aaaaaaaa-0000-4000-8000-00000000000f';
const D = 'aaaaaaaa-0000-4000-8000-00000000000d';
const S = 'aaaaaaaa-0000-4000-8000-000000000003';
const C1 = 'aaaaaaaa-0000-4000-8000-00000000000c';
const C2 = 'aaaaaaaa-0000-4000-8000-000000000004';

function temelPayload(over) {
  return Object.assign({
    focus: F,
    nodes: [
      { id: F, kind: 'farm_animal', farm_animal_id: 'H1', label: '136', sex: 'Dişi', breed: 'Simental', birth_date: '2024-01-01' },
      { id: D, kind: 'farm_animal', farm_animal_id: 'H2', label: 'E2E2', sex: 'Dişi' },
      { id: S, kind: 'external_animal', farm_animal_id: null, label: 'EXT-1', sex: 'Erkek' },
    ],
    edges: [
      { id: 'E1', source: D, target: F, role: 'dam', source_type: 'birth' },
      { id: 'E2', source: S, target: F, role: 'sire', source_type: 'birth' },
    ],
    meta: { ancestor_depth: 4, descendant_depth: 1, truncated: false },
  }, over);
}

test('edge yönü korunur: source=parent → target=child (RPC kontratı birebir)', () => {
  const out = toElements(temelPayload());
  assert.strictEqual(out.edges.length, 2);
  const dam = out.edges.find(e => e.data.id === 'E1');
  assert.strictEqual(dam.data.source, D, 'dam edge kaynağı anne düğümü olmalı');
  assert.strictEqual(dam.data.target, F, 'dam edge hedefi yavru düğümü olmalı');
  assert.strictEqual(dam.data.role, 'dam');
  assert.strictEqual(dam.data.source_type, 'birth');
  assert.strictEqual(dam.group, 'edges');
  assert.strictEqual(out.nodes[0].group, 'nodes');
});

test('sınıf ataması: focus/farm/external/dam/sire yükteki yapısal sinyalden gelir', () => {
  const out = toElements(temelPayload());
  const n = Object.fromEntries(out.nodes.map(n => [n.data.id, n]));
  assert.ok(n[F].classes.includes('focus'), 'focus sınıfı');
  assert.ok(n[F].classes.includes('farm'), 'farm sınıfı');
  assert.ok(n[D].classes.includes('farm') && n[D].classes.includes('dam'), 'dam ebeveyn');
  assert.ok(n[S].classes.includes('external') && n[S].classes.includes('sire'), 'external sire');
  assert.ok(!n[F].classes.includes('shared'), 'tek çocuğu olan düğüm shared değil');
});

test('shared node duplicate edilmez: iki çocuğu olan ata tek element + shared sınıfı', () => {
  const B = 'bbbbbbbb-0000-4000-8000-00000000000b';
  const p = temelPayload({
    focus: C1,
    nodes: [
      { id: C1, kind: 'farm_animal', farm_animal_id: 'H1', label: 'C1' },
      { id: C2, kind: 'farm_animal', farm_animal_id: 'H2', label: 'C2' },
      { id: B, kind: 'external_animal', farm_animal_id: null, label: 'PAYLASILMIS-ATA' },
      { id: B, kind: 'external_animal', farm_animal_id: null, label: 'PAYLASILMIS-ATA' }, // kopya satır
    ],
    edges: [
      { id: 'E-B1', source: B, target: C1, role: 'sire', source_type: 'birth' },
      { id: 'E-B2', source: B, target: C2, role: 'sire', source_type: 'birth' },
    ],
  });
  const out = toElements(p);
  const bNodes = out.nodes.filter(n => n.data.id === B);
  assert.strictEqual(bNodes.length, 1, 'aynı id yükte iki kez olsa da tek element');
  assert.ok(bNodes[0].classes.includes('shared'), '≥2 çocuklı ata shared sınıfı alır');
  assert.strictEqual(out.edges.length, 2);

  // Görünmeyen uca giden kenar shared sayımına katılmaz (review bulgusu fix'i)
  const GHOST = 'cccccccc-0000-4000-8000-000000000009';
  const p2 = temelPayload({
    focus: C1,
    nodes: [
      { id: C1, kind: 'farm_animal', farm_animal_id: 'H1', label: 'C1' },
      { id: B, kind: 'external_animal', farm_animal_id: null, label: 'ATA' },
    ],
    edges: [
      { id: 'E-B1', source: B, target: C1, role: 'sire', source_type: 'birth' },
      { id: 'E-GHOST', source: B, target: GHOST, role: 'dam', source_type: 'birth' },
    ],
  });
  const out2 = toElements(p2);
  const b2 = out2.nodes.find(n => n.data.id === B);
  assert.ok(!b2.classes.includes('shared'), 'görünmeyen çocuğa kenar shared sayımı şişirmez');
  assert.ok(!b2.classes.includes('dam'), 'görünmeyen uca dam rolü yapışmaz');
});

test('HTML/user stringler element data\'ya düz string olarak girer — markup üretimi yok', () => {
  const xss = '<img src=x onerror=alert(1)>';
  const out = toElements(temelPayload({
    nodes: [{ id: F, kind: 'farm_animal', farm_animal_id: 'H1', label: xss }],
  }));
  const n = out.nodes[0];
  assert.strictEqual(n.data.label, xss, 'etiket birebir korunur (canvas çizimi ham metin ister)');
  assert.strictEqual(typeof n.data.label, 'string');
  // Adapter çıktısı veri taşıyıcısıdır — HTML üreten alan içermez
  for (const el of [].concat(out.nodes, out.edges)) {
    assert.ok(!('html' in el) && !('innerHTML' in el), 'element üzerinde markup alanı yok');
    assert.ok(!el.classes || !/[<>]/.test(el.classes), 'classes alanı markup taşımaz');
  }
});

test('missing optional fields crash etmez: label/sex/breed/farm_animal_id eksik', () => {
  const out = toElements({
    focus: F,
    nodes: [
      { id: F, kind: 'farm_animal' },                       // tüm opsiyoneller boş
      { id: D },                                            // kind bile yok → unknown
      { farm_animal_id: 'H9', label: 'idsiz' },             // id'siz → düşer
      null, 'dizi-değil', 42,                               // bozuk satırlar → düşer
    ],
    edges: [
      { id: 'E1', source: D, target: F },                   // role/source_type yok
      { id: 'E2', source: 'YOK', target: F, role: 'dam' },  // uçuşta olmayan uç → düşer
      null,                                                 // bozuk edge → düşer
    ],
  });
  assert.strictEqual(out.nodes.length, 2);
  const nF = out.nodes.find(n => n.data.id === F);
  assert.strictEqual(nF.data.label, F, 'labelsız düğüm id fallback kullanır');
  assert.strictEqual(nF.data.sex, '');
  assert.strictEqual(nF.data.farm_animal_id, '');
  const nD = out.nodes.find(n => n.data.id === D);
  assert.ok(nD.classes.includes('unknown'), 'kindsız düğüm unknown');
  assert.strictEqual(out.edges.length, 1, 'uçları olmayan edge düşer');
  assert.strictEqual(out.edges[0].data.role, '');
  assert.strictEqual(out.edges[0].data.source_type, '');
});

test('bozuk payload patlamaz: null/{} / alan-tipleri yanlış → boş küme', () => {
  for (const bad of [null, undefined, {}, { nodes: 'x' }, { nodes: [], edges: 5 }]) {
    const out = toElements(bad);
    assert.deepStrictEqual({ n: out.nodes.length, e: out.edges.length }, { n: 0, e: 0 }, JSON.stringify(bad));
  }
});

test('meta olduğu gibi geçer; meta yoksa boş nesne', () => {
  const meta = { ancestor_depth: 8, descendant_depth: 3, truncated: true };
  // vm sandbox farklı realm üretir — spread ile host-realm nesnesine taşınır
  assert.deepStrictEqual({ ...toElements(temelPayload({ meta })).meta }, meta);
  assert.deepStrictEqual({ ...toElements({ nodes: [], edges: [] }).meta }, {});
});
