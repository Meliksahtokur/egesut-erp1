# EgeSüt ERP

> Web-based management system for a 130+ head dairy farm — herd, reproduction, clinic, inventory, and automated task workflows in one offline-first app.

[![Live Demo](https://img.shields.io/badge/demo-live-4e9a2a?style=flat-square&logo=github&logoColor=white)](https://meliksahtokur.github.io/egesut-erp1/)
[![GitHub stars](https://img.shields.io/github/stars/Meliksahtokur/egesut-erp1?style=flat-square&logo=github)](https://github.com/Meliksahtokur/egesut-erp1/stargazers)
[![License](https://img.shields.io/badge/license-ISC-blue?style=flat-square)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Meliksahtokur/egesut-erp1?style=flat-square&logo=git)](https://github.com/Meliksahtokur/egesut-erp1/commits/main)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=flat-square&logo=supabase&logoColor=white)](https://supabase.com)
[![Playwright](https://img.shields.io/badge/Playwright-E2E-2EAD33?style=flat-square&logo=playwright&logoColor=white)](https://playwright.dev)

**Live app:** https://meliksahtokur.github.io/egesut-erp1/
**Backend:** Supabase (PostgreSQL)
**Repo:** github.com/Meliksahtokur/egesut-erp1

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Vanilla JavaScript, single `index.html` — no framework, no build step, no dependencies |
| Backend | Supabase (PostgreSQL) — RPC + REST |
| Data model | 50 tables, 170+ server-side functions, triggers, RLS policies |
| Offline Cache | IndexedDB (`egesut_v9`) |
| Hosting | GitHub Pages (static frontend), Supabase (database) |
| Migrations | 222 versioned SQL files, CI-deployed via Supabase CLI |
| Testing | Playwright E2E (sharded across 3 runners), `node:test` unit tests |
| Quality | SonarCloud static analysis |

---

## Modules & Status

| Module | Status | Description |
|--------|--------|-------------|
| **Herd** | ✅ Complete | Individual animal records, identity cards, group/paddock assignment, filtering across 130+ animals, full historical timeline per animal |
| **Reproduction** | ✅ Complete | Heat detection → insemination → pregnancy tracking → calving → calf registration. State transitions guarded by database triggers |
| **Clinical / Cases** | ✅ Complete | Open a case, add daily treatment sessions, prescribe from a controlled drug catalog, close the case. Treatment templates and undo support |
| **Inventory / Pharmacy** | ✅ Complete | Drug and material entry, automatic stock deduction on administration, critical-stock alerts. Vaccines and semen stock tracked. Immutable ledger — corrections entered as new movements |
| **Tasks** | ✅ Complete | Database-generated recurring and event-driven tasks (vaccinations, follow-ups, protocol steps). Color-coded status, one-tap completion, immutable audit log |
| **Vaccination** | ✅ Complete | Content-driven protocol management: vaccines, target diseases, protocol steps (primer + booster), equivalent products, multi-dose support |
| **Reports** | ✅ Complete | Herd summary, reproductive efficiency (Heifer/Cow ×3), semen/PI indices, per-animal and per-event historical timelines |
| **AI Assistant** | ✅ Complete | In-app assistant — runs read-only SQL queries against the live schema, drafts plans, requires human-in-the-loop confirmation for write actions |
| **Demo-Mirror** | ✅ Complete | `postgres_fdw` bridge for read-only clone of live data, one-click atomic cloning, demo login, drift warning |
| **Notifications** | ✅ Complete | Unified inbox of pending alerts — upcoming tasks, low stock, open cases |

---

## Architecture Highlights

- **Business logic in the database.** The browser never runs business rules — no state machines, no calculations, no validation on the client. All logic lives in PostgreSQL (RPC + trigger + view).
- **RPC-only writes.** Direct INSERT/UPDATE/DELETE against tables is forbidden. Every mutation calls a PostgreSQL function; validation, authorization, and side effects are enforced server-side in one place.
- **Controlled entities.** Diseases, drugs, and animals are never free-text; foreign keys and dropdowns keep the dataset clean and reportable.
- **Immutable stock ledger.** Stock movements are append-only; corrections are entered as new ledger entries, preserving a complete audit trail.
- **Offline-first.** Reads are served from IndexedDB and reconciled with the server when online; a service worker keeps the app shell available with no connection. Designed for use in a barn with spotty signal.
- **Versioned schema, CI-deployed.** Migrations live in `supabase/migrations/` and are pushed to production by a GitHub Actions workflow on every merge to `main`. The canonical schema is captured in `supabase/migrations/99999999999999_ground_truth.sql`.
- **Multi-tenant foundations.** A `farm_id` discipline and tenant-scoped RLS policies are in place for future multi-farm expansion.
- **Demo environment.** A read-only demo mirror with a live-data clone (`demo_klonla()` RPC over `postgres_fdw`) lets prospective users explore the real schema without touching production.
- **Zero build step.** No transpiler, no bundler, no dependency resolution at deploy time — the static assets ship as written, keeping the surface area small.

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
supabase/migrations/             — 222 migration files (PostgreSQL)
scripts/                       — LSP, ground-truth-audit, sql-lsp daemon, etc.
tests/                         — Playwright E2E + node:test unit tests
demo/                          — Demo-Mirror SQL (00_grants, 01_fdw, 02_klonla, 03_sema_diff)
```

## Database Overview

**50 public tables** (live, LSP-verified).

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
agent_threads + agent_messages + agent_plans  — AI Assistant memory + plan engine
prod_fdw                                       — Demo-Mirror FDW bridge
diseases / drugs                               — controlled lists
```

Architecture decisions: [`ARCHITECTURE.md`](ARCHITECTURE.md)
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

**Melik Şah Tokur** — freelance full-stack developer

- GitHub: [@Meliksahtokur](https://github.com/Meliksahtokur)
- Repository: [egesut-erp1](https://github.com/Meliksahtokur/egesut-erp1)
- Live demo: https://meliksahtokur.github.io/egesut-erp1/

Available for freelance and contract work on internal tools, line-of-business applications, and data-driven web apps. This repository is a working example — a production system running a real operation, not a demo project.

---

> 🇹🇷 Türkçe sürüm: [`README.md`](README.md)
