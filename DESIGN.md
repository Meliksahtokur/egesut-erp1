# Design Notes — why this system is built the way it is

> Companion to [`README.md`](README.md). The README says *what* exists; this says *why*, and what each decision cost.
> Written for anyone evaluating the codebase — including future me, who will have forgotten.

The context that drives every decision below: this app is used by farm workers, standing in a barn, on cheap Android phones, with one bar of signal, often with wet or gloved hands, while an animal is in front of them. Nobody there wants to use software. They want to record a fact and get back to work. Every architectural choice here falls out of that.

---

## 1. All business logic lives in PostgreSQL

**The rule:** the browser renders and collects input. It does not calculate, validate, or run state machines. Every business rule lives in the database as an RPC function, a trigger, or a view.

**Why.** A dairy herd is a state machine with real consequences. An animal is inseminated, then either confirmed pregnant, or not, then calves, or aborts. Getting a transition wrong doesn't produce a UI glitch — it produces a cow that nobody inseminates for three months because the system thinks she's already pregnant. That is real money and a real animal.

If those rules live in JavaScript, they are enforced only for clients that run my JavaScript. The moment a second client appears — an admin panel, a script, the AI assistant, a curl command, a future mobile app — every rule has to be reimplemented, and the reimplementations drift. Rules in the database are enforced for every caller, forever, including callers I haven't written yet.

There's a second reason, specific to this project: **I ship alone, and I ship often.** A constraint that lives in the schema cannot be forgotten during a refactor at 1 a.m. The database refuses. That refusal has caught me more times than I'd like to admit.

**What it costs.** Business logic in SQL is harder to write, harder to debug, and much harder to unit-test than the equivalent JavaScript. Stack traces are worse. There is no step debugger. The skill floor is higher — and if someone else inherits this, they need to be comfortable in PL/pgSQL, not just React. I accepted that trade because correctness beat convenience here.

---

## 2. Writes go through RPC, not table access

**The rule:** the client calls `create_case(...)`, not `INSERT INTO cases`. Direct table writes from the browser are forbidden.

**Why.** A single write is almost never a single write. Recording a drug administration must also deduct stock, append to the immutable ledger, and log the operation for audit. If the client does that as four separate calls, then a phone that loses signal after call two leaves the database describing a world that never happened: a drug given but never deducted.

One RPC call means one transaction. It either all happened or none of it did. On a connection that drops constantly, this is not a nicety — it is the only way the data stays true.

It also puts validation in exactly one place. `add_drug_administration` checks the case is still open. Every caller gets that check, whether or not the caller remembered it existed.

**What it costs.** ~180 functions is a lot of surface area to maintain, and a schema change can ripple through several of them. Signature changes are migrations, not refactors. This is why `scripts/ground-truth-audit.sh` exists — it diffs the live database against the checked-in canonical schema, because with this many objects, drift is not hypothetical. It happened, in June 2026, and the audit is what caught it.

**Where it's violated.** The insemination module has three write paths and two of them bypass RPC — a leftover from before this rule was firm. UI guards paper over it. It's the next refactor, and it's listed in the README's limitations rather than quietly omitted, because a reader deserves to know which rules the codebase actually keeps.

---

## 3. The stock ledger is append-only

**The rule:** `stok_hareket` rows are never updated and never deleted. Corrections are new rows. Current stock is *always* computed as `initial − SUM(movements)`, never stored in a column.

**Why.** Two reasons, and the second is the one that matters.

First, a stored `quantity` column is a cache, and caches drift. Any bug, any partial failure, any concurrent write, and the number on the screen stops matching reality. A derived total cannot drift — it is recomputed from the facts every time.

Second, and more important: **this is a pharmacy.** These are controlled veterinary drugs going into animals that produce milk for people. "How much of this antibiotic do we have?" is a question with a boring answer. "Who administered what, to which animal, on what date, and did anyone alter that record afterward?" is a question with a regulatory answer. An append-only ledger answers the second question. A mutable quantity column destroys the evidence needed to answer it.

So a mistake isn't erased — it's corrected by a compensating entry, and both rows survive. The history tells the truth, including the truth that someone made a mistake on a Tuesday.

**What it costs.** Every stock read is an aggregation over the ledger rather than a single-column select. At 363 movements this is free; at 500,000 it would need a materialized view or periodic snapshots. That's a real future cost, knowingly deferred — the ledger is the source of truth, and a snapshot layer can always be added on top of a correct log. The reverse is not true: you cannot reconstruct a history you never recorded.

---

## 4. Controlled entities, never free text

**The rule:** diseases, drugs, and animals are foreign keys with dropdowns. There is no free-text field for any of them.

**Why.** Free text seems kind to the user right up until you try to answer a question. Three workers typing a drug name produce `Penisilin`, `penicillin`, and `pen.`. Now "how much penicillin did we use this year" has no answer — not a wrong answer, *no* answer, and no way to recover one without a human re-reading every row.

Constraining input at entry is mildly annoying once. Unconstrained input is permanently expensive, and the cost lands on the person who needs a report, long after the typist has moved on.

**What it costs.** Someone has to maintain the catalogs, and a drug that isn't in the list can't be recorded until it is added — friction at exactly the wrong moment, when a worker is standing in front of an animal. That's a real usability tax. It buys a dataset that is still queryable years later, which for a system whose entire value is its history, is the right side of the trade.

---

## 5. Offline-tolerant, but honestly so

**The rule:** reads are served from IndexedDB and reconciled when a connection exists. There is no service worker.

**Why.** Barns have bad signal. If the app only works online, it doesn't work — a spinner in front of a cow is a system nobody will use twice. So the read path is local and always fast.

But the app shell still requires a network fetch. A service worker was tried and deliberately removed: it introduced a stale-cache failure mode that is genuinely nasty in this context — a worker's phone silently running last month's business rules, writing plausible-looking wrong data, with no visible symptom. The trade was "cold-start offline" versus "certainty about which version of the rules is executing." For a system where the rules are the product, certainty won. The code still actively unregisters stale service workers from old deployments, because that failure already happened once.

This is why the README says **offline-tolerant** and not offline-first. The distinction is small and I'd rather be precise than flattering.

**What it costs.** No connection at all means no cold start. Reads work once loaded; a fresh launch needs a network. That's a real gap, accepted with open eyes.

---

## 6. Versioned schema, deployed by CI

**The rule:** every schema change is a numbered, idempotent migration in `supabase/migrations/`, applied to production by GitHub Actions on merge to `main`. Nothing is typed into the SQL editor.

**Why.** Because I did it the other way first, and it broke. Two early migrations (013, 014) were applied by hand and never committed. The result: the repo described one database and production ran another. Debugging against a schema that doesn't exist is a special kind of waste.

That drift was resolved in June 2026 by regenerating `99999999999999_ground_truth.sql` from the live database — 19 stale signatures dropped, 35 added, duplicate views and an orphan table removed. `scripts/ground-truth-audit.sh` now diffs file against live so it can't rot silently again.

Migrations are idempotent (`DROP IF EXISTS` + `CREATE OR REPLACE`) because a migration that only works once is a migration that can't be tested.

**What it costs.** Slower iteration. Changing a function means writing a migration, not editing a thing. That friction is the point: it's what keeps the checked-in schema equal to the running one.

---

## 7. Row Level Security — what's real and what isn't

Being exact here, because RLS is easy to gesture at and hard to actually get right.

**What's real:** RLS is enabled on 47 of 48 tables. The AI assistant's tables enforce genuine per-user isolation — `agent_threads` and `agent_plans` scope on `auth.uid()`, and `agent_messages` scopes through a correlated subquery on its parent thread, so a user cannot read messages belonging to someone else's conversation even though messages carry no owner column of their own. Three tables (`bildirim_log`, `hayvan_override`, `cop_kutusu`) have RLS on and *no* policy at all — a deliberate deny-all, making them unreachable from any client and available only through `SECURITY DEFINER` RPCs.

**What isn't:** the farm domain is single-tenant. Its policies are `USING(true)` — 69 of 73 policies are open. There is exactly one farm, one operator, and a login gate in front of the whole app, so tenant-scoped policies would currently be ceremony protecting nothing from nobody.

The groundwork is laid — a `farm_id` column discipline and a `current_farm_id()` helper — so that multi-farm isolation is a policy rewrite rather than a schema migration. **But it is not done, and the README says so.** Writing `USING(current_farm_id())` across 47 tables without a second tenant to test against is how you ship a policy that looks right and leaks. It's real work, and it belongs to the release where a second farm actually exists.

---

## 8. No framework, no build step

**The rule:** vanilla JavaScript, one `index.html`, no bundler, no transpiler, no dependency resolution at deploy.

**Why.** The dependency surface is the maintenance surface. This app is maintained by one person alongside other work; a build chain would demand its own upkeep — version bumps, breaking changes, audit noise — and pay back nothing this app needs. There's no component tree deep enough to justify a virtual DOM, and no bundle worth splitting.

What ships is what I wrote. When something breaks in production, the file in the browser is the file in the repo — no source maps, no transpilation gap. On a phone in a barn, "no build output" also means "no 900KB of framework before the first row appears."

**What it costs.** Real. `js/ui.js` does its own DOM work, and state management is hand-rolled (`state.js`), currently living alongside an older `_appState` object mid-migration. A framework would give better ergonomics for complex interactions and a much larger hiring pool. For a UI that is mostly forms and lists over a database that holds all the logic, the trade held. For a UI with heavy client-side state, it wouldn't — and I'd choose differently.

---

## In one line

The database is the product. The frontend is a window onto it. Everything above follows from taking that seriously — including the parts that aren't finished, which are named in the README rather than hidden.
