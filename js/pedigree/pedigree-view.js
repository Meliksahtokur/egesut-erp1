// js/pedigree/pedigree-view.js
// Cytoscape görünüm yaşam döngüsü (Task 6): init/destroy, breadthfirst layout
// (P2'de BAŞKA layout kütüphanesi YOK — ELK P4 bandı), resize/re-layout,
// zoom-to-fit ve node tık dinleyicisi. View hesap yapmaz; adapter'ın ürettiği
// element setini çizer.
'use strict';

// breadthfirst layout yapılandırması. directed=true: parent→child kenar yönü
// yerleşimi belirler; roots verilmezse kökleri kendisi seçer (girişsiz düğümler
// = projenin en uç ataları). opts: {roots: selector|collection, fit, padding}
/**
 * Soy ağacı grafiği için Cytoscape breadthfirst (genişlik öncelikli) yerleşim yapılandırma nesnesi oluşturur.
 * @param {Object} [opts] - Yapılandırmayı özelleştiren seçenekler.
 * @param {boolean} [opts.fit] - Grafiğin görünüme sığdırılıp sığdırılmayacağı; false değilse true olur.
 * @param {number} [opts.padding] - Yerleşim dolgusu (padding) değeri; tanımsızsa 24 kullanılır.
 * @param {*} [opts.roots] - Yerleşimin kök düğüm veya düğümleri; verilirse yapılandırmaya eklenir.
 * @returns {Object} Yerleşim yapılandırma nesnesi.
 */
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
/**
 * Cytoscape.js tabanlı bir soy ağacı (pedigree) görselleştirme başlatır.
 * Cytoscape kütüphanesi yüklü değilse hata fırlatır.
 * @param {HTMLElement} container Görselleştirmenin yerleştirileceği DOM elementi.
 * @param {Object} elements Nodes ve edges içeren nesne; nodes ve edges özellikleri dizi olmalıdır.
 * @param {Object} opts Seçenekler nesnesi; layout konfigürasyonu gibi ek ayarlar içerebilir.
 * @returns {Object} Cytoscape instance'ı ve çeşitli işlemler (relayout, fit, resize, destroy, onTapNode) içeren nesne.
 */
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
    /**
     * Pedigree düzenini yeniden hesaplar ve ekrana uygular.
     * @returns {void} Fonksiyon bir değer döndürmez.
     */
    relayout: function () {
      cy.layout(pedigreeLayoutConfig({ fit: false })).run();
      handle.fit();
    },
    /**
     * Graf üzerindeki tüm elemanları 24 piksel dolgu payıyla görünüme sığdırır.
     * @returns {void}
     */
    fit: function () {
      cy.fit(undefined, 24);
    },
    /**
     * Grafik (cy) alanını yeniden boyutlandırır.
     * @returns {void}
     */
    resize: function () {
      cy.resize();
    },
    /**
     * Pedigree nesnesini temizler ve yok eder.
     * @returns {void}
     */
    destroy: function () {
      try { cy.destroy(); } catch (e) { console.warn('[pedigree] destroy:', e && e.message); }
    },
    /**
     * Cytoscape.js'de bir düğüm (node) üzerine tıklama olayını yakalar ve verilen işlevi tetikler.
     * @param {Function} fn Tıklanan düğümün olayı tetiklendiğinde çağrılacak işlev.
     * @returns {undefined} Hiçbir değer döndürmez.
     */
    onTapNode: function (fn) {
      cy.on('tap', 'node', function (evt) { fn(evt.target); });
    },
  };
  cy.layout(pedigreeLayoutConfig(opts)).run();
  return handle;
}
