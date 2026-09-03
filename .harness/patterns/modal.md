# MODAL-ROUTER-01 — Router-managed modals

The modal router is three small pieces: a delegated `data-action` dispatcher
(`js/utils/events.js` with the `ACTIONS` registry filled by one bulk call in
`js/utils/handlers.js`), the history-tracked open/close pair
(`js/utils/modal.js:openM` / `js/utils/modal.js:closeM` with the
`_modalStack`), and the Android-back popstate discipline in `js/app.js` that
closes only the top-most modal. `js/ui.js` and `js/forms.js` host openers,
not router mechanics.

## Invariants

- A router modal is declared as `<div id="m-X" class="mo"
  data-action="mclose-overlay">` wrapping a `.modal` sheet; backdrop taps and
  İptal/✕ buttons dispatch `data-action="close-X"` so every close path runs
  through `closeM` (stack pop, history sync, residue cleanup).
- Opening from static HTML uses `data-action="open-…"` registered in the
  handlers registry; opening from generated HTML uses an attribute `onclick`
  handler that carries its payload in `this.dataset.*` through a funnel like
  `js/ui.js:openMWithHayvan`.
- The ban is on DOM-property assignment `el.onclick =` for modal open/close
  wiring: it races `closeM` → `history.back()` (regression B22). Attribute
  `onclick` plus dataset is the established pattern, not a violation.
- Confirm-style yes/no flows reuse `js/ui.js:openConfirm` with its OK button
  wired as attribute `onclick="_confirmOk()"`; `#m-confirm` deliberately has
  no backdrop close.
- There is no global Escape-to-close; closing is İptal/✕, backdrop tap, or
  Android back. Do not add a competing close channel.
- Non-router overlays that remove themselves from the DOM and keep no history
  entry (silent sheet, protocol sheets, slide panels) are a separate
  sanctioned surface; do not convert them to router modals casually, and do
  not route router modals through direct DOM removal.

## Exemplars

- Router core: `js/utils/events.js:ACTIONS`, `js/utils/events.js:registerActions`,
  `js/utils/modal.js:openM`, `js/utils/modal.js:closeM`
- Confirm stack: `js/ui.js:openConfirm`, `js/ui.js:_confirmOk`
- Dataset-carrying opener: `js/ui.js:openMWithHayvan`
- Smallest full modal (copy this skeleton): `js/forms.js:openNotModal` with
  `index.html:m-not`; centered det-dialog variant: `index.html:m-hekim-det`

## Legitimate non-router onclick usage (do not flag these)

- Per-row edit buttons with dataset payload: `js/ui.js:caseDrugDuzenle`
- Dynamic list-row delete: `js/forms.js:ekUygulama_sil`
- Chip remove with dataset payload: `js/app.js:semptomKaldir`
- Option-chip builders: `js/app.js:selDis`
- Static chip toggles inside a modal: `index.html:ekChipSec`
- Self-dismissing non-router sheets assigned `box.onclick` for backdrop-tap
  removal only (direct DOM removal, no history) are sanctioned as-is.

## Anti-patterns

- Wiring modal open/close through `el.onclick =` DOM-property assignment.
- Building a second modal stack, a generic `open-modal` indirection (one
  exists unused), or per-modal close helpers that bypass `closeM`.
- Inventing a new confirm dialog instead of `openConfirm`.
- Known dead surface — do not imitate: `mClose` in `js/utils/modal.js` is dead
  code, `#m-gebelik` has no live opener, `m-tohum-ertele` is a phantom modal
  (opener exists, markup does not).
