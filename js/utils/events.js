// js/utils/events.js
// Merkezi event delegation

const ACTIONS = {};

function registerAction(action, handler) {
  ACTIONS[action] = handler;
}

function registerActions(map) {
  Object.entries(map).forEach(([k, v]) => ACTIONS[k] = v);
}

// Click delegation — data-action="..." (data-action-event OLMADAN)
document.addEventListener('click', e => {
  const el = e.target.closest('[data-action]');
  if (!el || el.dataset.actionEvent) return;
  const action = el.dataset.action;
  if (ACTIONS[action]) { e.preventDefault(); ACTIONS[action](el, e); }
});

// Input delegation — data-action="..." data-action-event="input"
document.addEventListener('input', e => {
  const el = e.target.closest('[data-action][data-action-event="input"]');
  if (!el || !ACTIONS[el.dataset.action]) return;
  ACTIONS[el.dataset.action](el, e);
});

// Change delegation
document.addEventListener('change', e => {
  const el = e.target.closest('[data-action][data-action-event="change"]');
  if (!el || !ACTIONS[el.dataset.action]) return;
  ACTIONS[el.dataset.action](el, e);
});

// Focus delegation
document.addEventListener('focusin', e => {
  const el = e.target.closest('[data-action][data-action-event="focus"]');
  if (!el || !ACTIONS[el.dataset.action]) return;
  ACTIONS[el.dataset.action](el, e);
});

// Keydown delegation
document.addEventListener('keydown', e => {
  const el = e.target.closest('[data-action][data-action-event="keydown"]');
  if (!el || !ACTIONS[el.dataset.action]) return;
  ACTIONS[el.dataset.action](el, { key: e.key, event: e });
});
