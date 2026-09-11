// js/pedigree/pedigree-style.js
// Cytoscape style yapılandırması (Task 6). index.html'deki tema token'larını
// (:root değişkenleri) okur — renkler tek kaynaktan (tema) gelir; token
// okunamazsa aynı tonlarda fallback devrede. Açık/koyu tema body.dark ile
// değişir; init anında okunan değerle çizilir (canlı tema geçişi P4 kapsamı).
'use strict';

// CSS değişkenini oku; yoksa fallback'e düş. getComputedStyle yoksa (sandbox)
// yalnız fallback'ler kullanılır.
function _pedigreeToken(name, fallback) {
  try {
    const cs = getComputedStyle(document.documentElement).getPropertyValue(name);
    const t = cs && cs.trim();
    return t || fallback;
  } catch (e) {
    return fallback;
  }
}

// Tema token kümesi — fallback değerleri index.html :root paletinin aynasıdır.
function pedigreeThemeTokens() {
  return {
    card: _pedigreeToken('--card', '#f7f4ee'),
    card2: _pedigreeToken('--card2', '#edeae2'),
    card3: _pedigreeToken('--card3', '#e2ddd3'),
    ink: _pedigreeToken('--ink', '#1a1f14'),
    ink2: _pedigreeToken('--ink2', '#3d4a32'),
    ink3: _pedigreeToken('--ink3', '#6b7a5c'),
    green: _pedigreeToken('--green', '#4e9a2a'),
    green2: _pedigreeToken('--green2', '#6abf3d'),
    green3: _pedigreeToken('--green3', '#98d96e'),
    blue: _pedigreeToken('--blue', '#2a6bb5'),
    amber: _pedigreeToken('--amber', '#c97d0a'),
    purple: _pedigreeToken('--purple', '#7c3aed'),
  };
}

// Cytoscape style dizisi. farm/external ayrımı yalnız renkle değil — ŞEKİL
// (ellipse ↔ round-hexagon) + KENAR (düz ↔ kesikli) ile de yapılır (renk-körü
// erişilebilirlik). focus düğümü mavi kalın kenarla öne çıkar.
function pedigreeStyle() {
  const t = pedigreeThemeTokens();
  return [
    {
      selector: 'node',
      style: {
        label: 'data(label)',
        'font-size': 10,
        color: t.ink,
        'text-background-color': t.card,
        'text-background-opacity': 0.85,
        'text-background-padding': 2,
        'text-valign': 'bottom',
        'text-margin-y': 4,
        width: 34,
        height: 34,
        'background-color': t.green3,
        'border-width': 2,
        'border-color': t.green,
      },
    },
    {
      selector: 'node.farm',
      style: {
        shape: 'ellipse',
        'background-color': t.green3,
        'border-color': t.green,
      },
    },
    {
      // Dış kaynak: farklı şekil + kesikli kenar — farm'dan renk dışında da ayrışır.
      selector: 'node.external',
      style: {
        shape: 'round-hexagon',
        'background-color': t.card2,
        'border-style': 'dashed',
        'border-color': t.ink3,
        color: t.ink2,
      },
    },
    {
      selector: 'node.focus',
      style: {
        'border-width': 4,
        'border-color': t.blue,
        width: 42,
        height: 42,
        'font-weight': 'bold',
      },
    },
    {
      // Ebeveyn rolü: dam/sire kenar tonu (ince ayrım — birincil ayrım farm/external).
      selector: 'node.dam',
      style: { 'border-color': t.purple },
    },
    {
      selector: 'node.sire',
      style: { 'border-color': t.amber },
    },
    {
      selector: 'node.shared',
      style: { 'background-color': t.green2 },
    },
    {
      // kind'i bilinmeyen düğüm: nötr gri + kesikli (unknown veri açık görünür).
      selector: 'node.unknown',
      style: {
        'background-color': t.card3,
        'border-style': 'dashed',
        'border-color': t.ink3,
      },
    },
    {
      selector: 'edge',
      style: {
        width: 1.5,
        'line-color': t.ink3,
        'curve-style': 'bezier',
        'target-arrow-shape': 'triangle',
        'arrow-scale': 0.8,
        'target-arrow-color': t.ink3,
      },
    },
    {
      // Dam (anne) kenarı düz, sire (baba) kenarı noktalı — rol kenarda da okunur.
      selector: 'edge[role = "sire"]',
      style: {
        'line-style': 'dotted',
      },
    },
  ];
}
