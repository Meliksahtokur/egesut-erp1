// js/pedigree/pedigree-view.js
// Cytoscape görünüm yaşam döngüsü (Task 6): init/destroy, breadthfirst layout
// (P2'de BAŞKA layout kütüphanesi YOK — ELK P4 bandı), resize/re-layout,
// zoom-to-fit ve node tık dinleyicisi. View hesap yapmaz; adapter'ın ürettiği
// element setini çizer.
'use strict';

// breadthfirst layout yapılandırması. directed=true: parent→child kenar yönü
// yerleşimi belirler; roots verilmezse kökleri kendisi seçer (girişsiz düğümler
// = projenin en uç ataları). opts: {roots: selector|collection, fit, padding}
function pedigreeLayoutConfig(opts) {
  opts = opts || {};
  const cfg = {
    name: 'breadthfirst',
    directed: true,
    fit: opts.fit !== false,
    padding: opts.padding !== undefined ? opts.padding : 24,
    spacingFactor: 1.15,
    animate: false,
  };
  if (opts.roots) cfg.roots = opts.roots;
  return cfg;
}

// Konteyner + element seti ile graf kurar. Dönen handle: {cy, relayout, fit,
// resize, destroy, onTapNode}. cytoscape globali yoksa (vendor yüklenmedi/
// 404) açık hata — sessiz boş ekran değil.
function pedigreeViewInit(container, elements, opts) {
  if (typeof globalThis.cytoscape !== 'function') {
    throw new Error('Cytoscape yüklenemedi (vendor/cytoscape.min.js)');
  }
  opts = opts || {};
  const cy = globalThis.cytoscape({
    container: container,
    elements: [].concat(elements.nodes || [], elements.edges || []),
    style: pedigreeStyle(),
    wheelSensitivity: 0.2,
    minZoom: 0.2,
    maxZoom: 2.5,
  });
  const handle = {
    cy: cy,
    relayout: function () {
      cy.layout(pedigreeLayoutConfig({ fit: false })).run();
      handle.fit();
    },
    fit: function () {
      cy.fit(undefined, 24);
    },
    resize: function () {
      cy.resize();
    },
    destroy: function () {
      try { cy.destroy(); } catch (e) { console.warn('[pedigree] destroy:', e && e.message); }
    },
    onTapNode: function (fn) {
      cy.on('tap', 'node', function (evt) { fn(evt.target); });
    },
  };
  cy.layout(pedigreeLayoutConfig(opts)).run();
  return handle;
}
