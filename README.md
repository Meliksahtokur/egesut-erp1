# EgeSüt ERP

> Offline-tolerant web management system for a working dairy farm — herd, reproduction, clinic, inventory, and automated task workflows in one app.

**This is not a portfolio project.** A 157-head dairy farm runs its daily operations on it. As of 16 July 2026: 2,674 recorded operations, 586 of them in the last 30 days, active on 66 of the last 90 days.

[![Live Demo](https://img.shields.io/badge/demo-live-4e9a2a?style=flat-square&logo=github&logoColor=white)](https://meliksahtokur.github.io/egesut-erp1/)
[![GitHub stars](https://img.shields.io/github/stars/Meliksahtokur/egesut-erp1?style=flat-square&logo=github)](https://github.com/Meliksahtokur/egesut-erp1/stargazers)
[![License](https://img.shields.io/badge/license-ISC-blue?style=flat-square)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Meliksahtokur/egesut-erp1?style=flat-square&logo=git)](https://github.com/Meliksahtokur/egesut-erp1/commits/main)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=flat-square&logo=supabase&logoColor=white)](https://supabase.com)
[![Playwright](https://img.shields.io/badge/Playwright-E2E-2EAD33?style=flat-square&logo=playwright&logoColor=white)](https://playwright.dev)

**Live app:** https://meliksahtokur.github.io/egesut-erp1/
**Backend:** Supabase (PostgreSQL)
**Repo:** github.com/Meliksahtokur/egesut-erp1

> 🇹🇷 Türkçe sürüm: [`README.tr.md`](README.tr.md)

---

## What's actually running

Read from the live database, not estimated.

| | |
|---|---|
| Animals under management | 157 |
| Tasks generated and tracked | 1,621 |
| Breeding events | 258 |
| Calvings | 63 |
| Clinical cases | 37 — across 120 treatment days and 158 drug administrations |
| Stock ledger entries | 363 |
| Total logged operations | 2,674 |

Database objects, live: **48 tables · 13 views · 180 functions · 35 triggers**, built up over **221 versioned migrations**.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Vanilla JavaScript, single `index.html` — no framework, no build step, no bundler |
| Backend | Supabase (PostgreSQL) — RPC + REST |
| Data model | 48 tables, 180 server-side functions, 35 triggers, RLS enabled |
| Offline cache | IndexedDB (`egesut_v9`) — reads served locally, reconciled when online |
| Hosting | GitHub Pages (static frontend), Supabase (database) |
| Migrations | 221 versioned SQL files, CI-deployed via Supabase CLI |
| Testing | Playwright E2E (sharded across 3 runners), `node:test` unit tests |
| Quality | SonarCloud static analysis |

---

## Modules & Status

| Module | Status | Description |
|--------|--------|-------------|
| **Herd** | ✅ In production | Individual animal records, identity cards, group/paddock assignment, filtering across 157 animals, full historical timeline per animal |
| **Reproduction** | ✅ In production | Heat detection → insemination → pregnancy tracking → calving → calf registration. State transitions guarded by database triggers |
| **Clinical / Cases** | ✅ In production | Open a case, add daily treatment sessions, prescribe from a controlled drug catalog, close the case. Treatment templates and undo support |
| **Inventory / Pharmacy** | ✅ In production | Drug and material entry, automatic stock deduction on administration, critical-stock alerts. Vaccines and semen stock tracked. Immutable ledger — corrections entered as new movements |
| **Tasks** | ✅ In production | Database-generated recurring and event-driven tasks (vaccinations, follow-ups, protocol steps). Color-coded status, one-tap completion, immutable audit log |
| **Vaccination** | ✅ In production | Content-driven protocol management: vaccines, target diseases, protocol steps (primer + booster), equivalent products, multi-dose support |
| **Reports** | ✅ In production | Herd summary, reproductive efficiency (Heifer/Cow ×3), semen/PI indices, per-animal and per-event historical timelines |
| **AI Assistant** | ✅ In production | In-app assistant — runs read-only SQL against the live schema, drafts plans, requires human-in-the-loop confirmation before any write. 26 threads to date |
| **Demo-Mirror** | ✅ In production | `postgres_fdw` bridge to a read-only clone of live data, one-click atomic cloning, demo login, drift warning |
| **Notifications** | ✅ In production | Unified inbox of pending alerts — upcoming tasks, low stock, open cases |

---

## Architecture Highlights

The reasoning behind these choices — and what each one costs — is written up in [`DESIGN.md`](DESIGN.md).

- **Business logic lives in the database.** The browser never runs business rules — no state machines, no calculations, no validation on the client. Logic lives in PostgreSQL as RPC functions, triggers, and views.
- **Writes go through RPC.** Application code calls a PostgreSQL function rather than writing to tables directly, so validation, authorization, and side effects are enforced server-side in one place. *(One known exception: the insemination module still has write paths that bypass RPC — see "Known limitations".)*
- **Controlled entities.** Diseases, drugs, and animals are never free-text; foreign keys and dropdowns keep the dataset clean and reportable.
- **Immutable stock ledger.** Stock movements are append-only. Corrections are entered as new ledger rows, never edits or deletes, so the audit trail stays complete. Current stock is always derived, never stored.
- **Offline-tolerant reads.** Reads are served from IndexedDB and reconciled with the server when a connection is available — the app stays usable in a barn with weak signal. *(The app shell itself still requires a network fetch — see "Known limitations".)*
- **Versioned schema, CI-deployed.** Migrations live in `supabase/migrations/` and are pushed to production by GitHub Actions on every merge to `main`. The canonical schema is captured in `supabase/migrations/99999999999999_ground_truth.sql` and audited against the live database by `scripts/ground-truth-audit.sh`.
- **Row Level Security.** RLS is enabled on 47 of 48 tables. The assistant's tables (`agent_threads`, `agent_messages`, `agent_plans`) enforce true per-user isolation via `auth.uid()`, including a correlated policy that scopes messages through their parent thread. Three tables are deliberately policy-less: RLS on with no policy means no direct client access at all, reachable only through `SECURITY DEFINER` RPCs.
- **Zero build step.** No transpiler, no bundler, no dependency resolution at deploy time — static assets ship as written, keeping the deployable surface small.

---

## Known limitations

Stated plainly, because a system that claims no weaknesses isn't being honest about itself.

- **Single-tenant today.** The farm domain runs one tenant, and its RLS policies are permissive (`USING(true)`) rather than tenant-scoped — 69 of 73 policies are open by design, because there is exactly one farm. A `farm_id` column discipline and a `current_farm_id()` helper are in place as groundwork, but **no policy is farm-scoped yet.** Multi-farm isolation is planned work, not shipped work.
- **No service worker.** Offline reads come from IndexedDB, but the application shell is fetched over the network — the app does not cold-start without a connection. A service worker was deliberately removed; the code actively unregisters stale ones.
- **Insemination write paths.** Three write paths exist, two of which bypass the RPC layer everything else goes through. UI guards cover it for now; consolidating onto `tohumlama_*` RPCs is the next refactor.
- **Polling, not realtime.** Sync runs on a 5-second interval rather than Supabase Realtime channels. Fine for current single-operator use; would need to change for concurrent multi-user editing.

---

## Source Files

```
index.html                    — HTML + CSS + all modals
js/
  config.js                   — Constants and configuration
  state.js                    — AppState
  api.js                      — Supabase client, IDB sync, RPC wrapper
  app.js                      — App initialization + routing
  ui.js                       — All rendering
  forms.js                    — Form submit + validation
  auth.js                     — Login gate, registration, password reset
  ai-asistan.js               — AI Assistant frontend
  demo.js                     — Demo-Mirror UI
  utils/
    helpers.js                — DOM, toast, autocomplete, debounce
    modal.js                  — openM/closeM/mClose
    errorHandler.js           — withErrorHandling
    handlers.js               — Global event handlers
    events.js                 — Event emitter
supabase/migrations/          — 221 migration files (PostgreSQL)
scripts/                      — LSP, ground-truth-audit, sql-lsp daemon, etc.
tests/                        — Playwright E2E + node:test unit tests
demo/                         — Demo-Mirror SQL (00_grants, 01_fdw, 02_klonla, 03_sema_diff)
```

## Database Overview

```
hayvanlar (core)
  ├── tohumlama          — breeding events (per-cycle state machine)
  ├── dogum              — calving records
  ├── kizginlik_log      — heat tracking
  ├── gorev_log          — task system (cascade/orphan guard)
  └── cases              — clinical cases
        ├── treatment_days → drug_administrations → drugs → stock
        ├── tedavi_sablon_*, tedavi_sablon_uygulama — template engine
        └── tedavi (legacy, cleaned)

stock
  └── stok_hareket       — ledger (immutable, append-only)

vaccines + vaccine_diseases + protocol_steps  — vaccination management (content-driven)
agent_threads + agent_messages + agent_plans  — AI Assistant memory + plan engine (per-user RLS)
prod_fdw                                      — Demo-Mirror FDW bridge
diseases / drugs                              — controlled lists
```

Design rationale: [`DESIGN.md`](DESIGN.md)
Architecture reference (Turkish): [`ARCHITECTURE.md`](ARCHITECTURE.md)
`ground_truth` reference: [`supabase/migrations/99999999999999_ground_truth.sql`](supabase/migrations/99999999999999_ground_truth.sql)

---

## Getting Started

### Prerequisites
- A Supabase project (or any PostgreSQL 14+ with the Supabase runtime)
- Node.js 18+ for running the test suite
- Python 3 for the optional local static server

### Run the app locally
The frontend is plain static files — serve the repository root with any static server:

```bash
python3 -m http.server 8080
# open http://127.0.0.1:8080/
```

Point `js/config.js` at your Supabase project URL and anon key to connect to your own database.

### Apply the database schema
The canonical schema and all migrations live under `supabase/migrations/`. With the Supabase CLI:

```bash
supabase link --project-ref <your-project-ref>
supabase db push --include-all
```

### Run the tests
```bash
npm install
npm test                 # Playwright E2E
npm run test:unit        # node:test unit tests
npm run test:docker      # E2E in the official Playwright Docker image
```

---

## CI/CD

| Workflow | Purpose |
|---------|---------|
| `test.yml` | Playwright E2E across 3 shards on every push and pull request |
| `deploy.yml` | Pushes pending migrations to Supabase on merge to `main` |
| `pages.yml` | Publishes the static frontend to GitHub Pages |
| `sonarcloud.yml` | Static analysis and code-quality gates |
| `db-backup.yml` | Scheduled database backups |
| `test-migration-ready.yml` | Validates migrations before they ship |

[![E2E Tests](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/test.yml)
[![Deploy to Supabase](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/deploy.yml)
[![GitHub Pages](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/pages.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/pages.yml)
[![SonarCloud](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/sonarcloud.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/sonarcloud.yml)

---

## License

Distributed under the ISC license. See `package.json` for details. The database schema, migrations, and application source in this repository are provided as-is.

---

## Contact

**Melik Şah Tokur** — backend & automation engineer

I build the parts that have to be right: database schemas that enforce their own rules, workflows that run unattended, and data pipelines that survive the source changing shape.

- GitHub: [@Meliksahtokur](https://github.com/Meliksahtokur)
- Live demo: https://meliksahtokur.github.io/egesut-erp1/

Available for contract work on internal tools, business process automation, and PostgreSQL-backed applications. This repository is the reference — a real operation depends on it, every day.
