// js/utils/events.js
// Merkezi event delegation — her event tipi icin ayri attribute

const ACTIONS = {};

/**
 * Belirtilen adlı aksiyona (action) verilen işleyiciyi (handler) kaydeden fonksiyondur.
 * @param {string} action Kaydedilecek aksiyonun adı.
 * @param {Function} handler Aksiyon tetiklendiğinde çalışacak işleyici fonksiyonu.
 * @returns {void}
 */
function registerAction(action, handler) {
  ACTIONS[action] = handler;
}

/**
 * Verilen map nesnesindeki tüm girişleri ACTIONS nesnesine atar.
 * @param {Object} map Kaydedilecek girişleri içeren nesne.
 * @returns {void}
 */
function registerActions(map) {
  Object.entries(map).forEach(([k, v]) => ACTIONS[k] = v);
}

// Click delegation — data-action
document.addEventListener('click', e => {
  const el = e.target.closest('[data-action]');
  if (!el || !ACTIONS[el.dataset.action]) return;
  // Form elemanlarının default davranışını engelleme (checkbox, input, select vb.)
  const tag = e.target.tagName;
  if (tag !== 'INPUT' && tag !== 'SELECT' && tag !== 'TEXTAREA' && tag !== 'LABEL') e.preventDefault();
  ACTIONS[el.dataset.action](el, e);
});

// Input delegation — data-input
document.addEventListener('input', e => {
  const el = e.target.closest('[data-input]');
  if (!el || !ACTIONS[el.dataset.input]) return;
  ACTIONS[el.dataset.input](el, e);
});

// Focus delegation — data-focus
document.addEventListener('focusin', e => {
  const el = e.target.closest('[data-focus]');
  if (!el || !ACTIONS[el.dataset.focus]) return;
  ACTIONS[el.dataset.focus](el, e);
});

// Keydown delegation — data-keydown
document.addEventListener('keydown', e => {
  const el = e.target.closest('[data-keydown]');
  if (!el || !ACTIONS[el.dataset.keydown]) return;
  ACTIONS[el.dataset.keydown]({ key: e.key, event: e });
});

// Change delegation — data-change
document.addEventListener('change', e => {
  const el = e.target.closest('[data-change]');
  if (!el || !ACTIONS[el.dataset.change]) return;
  ACTIONS[el.dataset.change](el, e);
});