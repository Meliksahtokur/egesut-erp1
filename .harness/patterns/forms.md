# FORM-SUBMIT-01 — Form submission chain

Every modal form follows one chain. The exemplar to copy is
`js/forms.js:submitKizginlik`; the auto-refresh variant is
`js/ui.js:_diseaseSave` through `js/api.js:rpcOptimistic`.

## Invariants

- The chain is: offline guard → collect (`g`/`v`/`cl` helpers) → validate →
  busy state (disable button, "Kaydediliyor…") → submit through
  `js/api.js:rpc` → success toast + `closeM` + clear inputs → targeted
  `pullTables([...affected])` then `renderSafe` → `catch` with
  `getUserMessage(e)` and `e.data` payloads → `finally` re-enable the button.
- Write RPC failures arrive as thrown errors whose `.data` carries the jsonb
  body (`ok:false` is never a return value); business payloads such as
  recommendation objects ride on `e.data`.
- Never construct SQL or call `db.from(...)` write REST from form code; the
  only sanctioned generic table-write path is `js/api.js:write` for the
  established table-write sites (task rows, notification read flags, the
  legacy case-drug path).
- A submit handler must be idempotent under double-tap: the busy state is not
  optional.
- Refresh by pulling only the affected tables (`RPC_TABLES` names them for
  `rpcOptimistic`), never by a full `pullFromSupabase`.
- Pre-checks that need a server answer before submit (for example ear-tag
  availability) use a read RPC through the same wrapper contract, then the
  write RPC on confirm — see `js/forms.js:_kupeKontrolEt`.

## Exemplars

- Canonical chain: `js/forms.js:submitKizginlik`
- Dynamic RPC name on one form: `js/forms.js:submitInsem`
- Auto-refresh wrapper path: `js/ui.js:_diseaseSave`, `js/api.js:rpcOptimistic`
- Typed domain wrapper: `js/api.js:rpcSeansTamamla`

## Anti-patterns

- Checking `res.ok` after `rpc()` — dead code by contract.
- Raw `db.rpc` calls from forms (about ten legacy direct sites exist; they
  lose Turkish error translation and `ok:false` handling — do not add new
  ones).
- Resetting the whole UI instead of pulling the two affected tables.
- Skipping the busy state or the `finally` re-enable.
- Duplicating `buildRpcParams` logic inline; the offline-replay builder
  `js/ui.js:buildRpcParams` owns queued-op param shapes.
