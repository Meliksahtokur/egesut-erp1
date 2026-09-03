# TESTING-01 — Test placement and the browser-module loader

Unit tests run under `node --test` with no browser; the browser-global
product scripts are loaded into a `node:vm` sandbox by
`tests/unit/support/loadModule.js` (`loadBrowserModule`) with stubs for
`document`, `localStorage`, the Supabase client, `fetch`, and friends. The
suite is the local acceptance gate; GitHub E2E is never a blocker.

## Invariants

- Product tests stay product-owned: they assert product behavior
  (a function, a filter, a param contract), never harness or governance
  assertions.
- Prefer pure functions. If the logic can be extracted or reached without
  DOM writes, test it in `tests/unit/`; DOM-heavy flows belong to the
  Playwright specs.
- Load with `loadBrowserModule(relPath, {dom, storage, expose, extra})`;
  top-level `function` declarations surface automatically, `let`/`const`
  need `expose: ["NAME"]`.
- Loader traps: load-time `setTimeout` is frozen into the sandbox — inject
  fakes through `opts.extra`, never rely on sandbox timers.
- When a module cannot load whole, use the surgical extractor
  (`loadExtractedFunction`) instead of copying source into the test.
- Param-name contracts against the live RPC signatures are locked as unit
  tests (exemplar: `js/ui.js:buildRpcParams` with
  tests/unit/buildRpcParams.test.js) — extend that file rather than
  asserting shapes ad hoc.
- E2E specs are read-only against production/GitHub Pages (writes are never
  submitted); flows that must write run only in demo mode
  (`PLAYWRIGHT_DEMO_MODE`) or against the local static server
  (`npm run test:local`).

## Exemplars

- Turkish casing and formatting: `js/utils/helpers.js:trLower`,
  `js/utils/helpers.js:fmtTarih`
- Pure data selection: `js/utils/helpers.js:aktifHayvanSatirlari`,
  `js/utils/helpers.js:srchAdaySirala`
- Config rules as functions: `js/config.js:bosKupeOner`,
  `js/config.js:erkekKupeUygunMu`
- RPC param contract: `js/ui.js:buildRpcParams`

## Anti-patterns

- Copying product source into a test instead of loading or extracting it.
- Unit-testing DOM structure that the Playwright specs already cover.
- Adding tests that stub the product so heavily they only assert the stub.
- Pointing write-path E2E at production; writes belong to demo/local runs.
