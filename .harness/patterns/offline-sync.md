# OFFLINE-SYNC-01 — Offline-first data flow

The app is offline-first: every write lands in IndexedDB before it reaches
Supabase, every read renders from IndexedDB, and a durable queue drains when
connectivity returns. Business rules stay server-side; the client only
collects, renders, and replays.

## Invariants

- All local writes go through `write()` (`js/api.js:write`), never a direct
  `db.from(...)` call in UI code. `write()` dispatches to `_writePost`
  (client uuid, `idbPut`, then `dbInsert`, else queue) or `_writePatch`
  (requires an `id=eq.` filter, merges into the IDB row, then `dbUpdate`,
  else queue).
- PATCH without an `id=eq.` filter is a hard error, not a silent no-op.
- Queue drain (`js/api.js:syncNow`) is re-entrancy guarded, continues past
  per-op failures, dead-letters after repeated consecutive failures, and
  drops ops whose target row was deleted server-side (`deadTarget`).
- Pulls are serialized through the pull chain (`js/api.js:pullTables` /
  `_pullTablesNow`) so a slow earlier snapshot cannot overwrite a newer one.
- `TABLES` and `FETCHERS` must stay consistent: a `TABLES` entry without a
  fetcher silently no-ops; a fetcher without a store throws on first pull.
  Locked by tests/unit/api.test.js.
- Rendering reads only local state (`js/api.js:getData`,
  `js/app.js:renderFromLocal`); a pull finishes with a re-render, never a
  direct DOM write from network data.
- RPC writes go through the wrapper (`js/api.js:rpc`) — it never returns
  `ok:false`, it throws with the body on `.data` — or `js/api.js:rpcOptimistic`
  for RPC + affected-table refresh via `RPC_TABLES`.
- Adding a synced table is the three-line recipe: bump `js/api.js:DB_VER`,
  append the table to `js/api.js:TABLES`, add a fetcher to `FETCHERS`
  (exemplar: `vaccination_schedule`, commit d1de3e8).

## Exemplars

- Write path: `js/api.js:write` → `js/api.js:_writePost` / `js/api.js:_writePatch`
- Queue: `js/api.js:queueOp`, `js/api.js:syncNow`
- Pull path: `js/api.js:pullTables`, `js/api.js:rpcOptimistic`
- Storage: `js/api.js:openDB`, `js/api.js:idbClearAndPut`
- Boot: `js/app.js:renderFromLocal`, `js/api.js:initRealtime`

## Anti-patterns

- Calling `db.from(...).insert/update` directly from UI or form code: the
  write bypasses the IDB mirror and the queue, so it is lost offline and the
  next pull silently reverts the screen.
- Mutating `TABLES` without a matching fetcher (or the reverse).
- Reading Supabase directly inside a render function instead of `getData`.
- Building a second queue or sync path instead of extending `RPC_TABLES` and
  the manual-replay RPC map together.
