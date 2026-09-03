# RPC-WRITE-01 — Write RPC call contract

Business rules, validation, state machines, and stock math live in
PostgreSQL. Write RPCs are `SECURITY DEFINER` functions returning jsonb
`{ ok, mesaj, ... }`. The frontend calls them through a layered wrapper
stack and never writes business data through REST.

## Invariants

- Call layers, lowest to highest: raw `db.rpc` (legacy, ~10 direct sites —
  no error translation, no `ok:false` handling; do not add new ones);
  `js/api.js:rpc` (throws on `ok:false` with the body on `.data`, translates
  transport errors); `js/api.js:rpcOptimistic` (adds toast plus targeted
  auto-refresh from `RPC_TABLES`); typed domain wrappers
  (`js/api.js:rpcSeansTamamla` and siblings) for multi-step flows.
- Parameters use `p_` names and jsonb arrays for lists (`p_items`,
  `p_sessions`); the canonical per-RPC parameter list is
  `.harness/references/rpc-reference.md`, and the live schema remains the
  only authority for signatures.
- `js/api.js:RPC_TABLES` is the write-impact map (which tables an RPC
  dirties). A new write RPC must be added there. The offline-replay map in
  `js/ui.js` (`js/ui.js:buildRpcParams` and its `RPC_MAP`) mirrors only the
  queueable subset — extend it only when the op can queue offline; keep both
  maps consistent when they overlap.
- New tenant-scoped write RPCs stamp `farm_id = public.current_farm_id()`
  per the harness contract; the client sends no farm scoping (today the app
  is deliberately single-tenant server-side).
- Edge functions are not RPCs: `supabase/functions/ai-agent` is called from
  `js/ai-asistan.js` as a streaming HTTP endpoint; `stat-hesapla` is not
  called by the frontend at all (the `stat_suru_ozet` RPC serves that data).

## Exemplars

- Wrapper stack: `js/api.js:rpc`, `js/api.js:rpcOptimistic`,
  `js/api.js:rpcSeansTamamla`
- Impact map: `js/api.js:RPC_TABLES`
- Queued-op param contract: `js/ui.js:buildRpcParams`

## Anti-patterns

- Bypassing `rpc()` with `db.rpc` for a write.
- Reimplementing a server state-machine rule client-side instead of trusting
  the RPC result and refreshing.
- Treating `.harness/references/rpc-reference.md` (or any tracked doc) as
  live-schema truth; a migration file in Git is not evidence of deployment.
- Adding a write RPC without registering its affected tables in
  `RPC_TABLES`.
