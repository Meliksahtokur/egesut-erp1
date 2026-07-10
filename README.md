# EgeSüt ERP

> Web-based management system for a 130+ head dairy farm — herd, reproduction, clinic, inventory, and automated task workflows in one offline-first app.

[![Live Demo](https://img.shields.io/badge/demo-live-4e9a2a?style=flat-square&logo=github&logoColor=white)](https://meliksahtokur.github.io/egesut-erp1/)
[![GitHub stars](https://img.shields.io/github/stars/Meliksahtokur/egesut-erp1?style=flat-square&logo=github)](https://github.com/Meliksahtokur/egesut-erp1/stargazers)
[![License](https://img.shields.io/badge/license-ISC-blue?style=flat-square)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Meliksahtokur/egesut-erp1?style=flat-square&logo=git)](https://github.com/Meliksahtokur/egesut-erp1/commits/main)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=flat-square&logo=supabase&logoColor=white)](https://supabase.com)
[![Playwright](https://img.shields.io/badge/Playwright-E2E-2EAD33?style=flat-square&logo=playwright&logoColor=white)](https://playwright.dev)

**Live app:** https://meliksahtokur.github.io/egesut-erp1/

EgeSüt ERP runs a real working dairy farm. It is built as a single-page, installable Progressive Web App with vanilla JavaScript on the front and a PostgreSQL database (Supabase) on the back. Every write goes through a versioned server-side function; the business logic lives in the database, not the browser. Field staff use it on phones in the barn, offline, and sync when connectivity returns.

---

## Features

### Herd Management
Individual animal records, identity cards, physical-location tracking (paddock and group assignments), and herd-wide filtering across 130+ animals. Each animal carries a full historical timeline.

### Reproduction
A complete breeding state machine: heat detection → insemination → pregnancy tracking → calving → calf registration. Status transitions are guarded by database triggers, so an invalid progression (for example, marking a non-pregnant animal as calved) is rejected at the data layer.

### Clinical Cases
A structured veterinary workflow: open a case, add daily treatment sessions, prescribe medication from a controlled catalog, and close the case. Treatment templates and an undo path are supported. Backed by a disease catalog grouped by body system (mammary, reproductive, metabolic, foot, respiratory, digestive, calf) and a veterinarian registry.

### Inventory and Pharmacy
Drug and material entry, automatic stock deduction on administration, and critical-stock threshold alerts. Vaccines and semen stock are tracked alongside consumables, with an immutable ledger so corrections are entered as new movements rather than edits.

### Automated Tasks
The database generates recurring and event-driven tasks — vaccinations, follow-ups, protocol steps — automatically. Tasks carry a color-coded status and are completed in one tap, with an immutable operation log for auditability.

### Vaccination Protocols
Content-driven protocol management linking vaccines, target diseases, and protocol steps (primer and booster schedules), with support for equivalent products and multi-dose administration.

### Notifications
A unified inbox of pending alerts — upcoming tasks, low stock, open cases — so nothing falls through the cracks.

### Reports and History
Operational dashboards and reports (herd summary, reproductive efficiency by parity, semen and pregnancy indices) plus per-animal and per-event historical timelines for traceability.

### AI Assistant
An in-app assistant that drafts plans and runs read-only queries against the live schema to help operators reason about the herd, with human-in-the-loop confirmation for any write action.

### Offline-first PWA
Installable on iOS and Android home screens, runs offline through a service worker and an IndexedDB cache, and shows a live connectivity indicator so the user always knows whether they are reading cached data or live.

---

## Tech Stack

| Layer | Technology |
|------|-----------|
| Frontend | Vanilla JavaScript, single `index.html` — no framework, no bundler, no build step |
| Backend | Supabase (PostgreSQL) — RPC + REST |
| Data model | 50 tables, 170+ server-side functions, triggers, RLS policies |
| Offline cache | IndexedDB (`egesut_v9`) |
| Hosting | GitHub Pages (static frontend), Supabase (database) |
| Migrations | 222 versioned SQL files, CI-deployed via Supabase CLI |
| Testing | Playwright E2E (sharded across 3 runners), `node:test` unit tests |
| Quality | SonarCloud static analysis |

---

## Architecture Highlights

- **RPC-only writes.** The browser never issues `INSERT`/`UPDATE`/`DELETE` against a table directly. Every mutation calls a PostgreSQL function, so validation, authorization, and side effects are enforced server-side in one place.
- **Business logic in the database.** State machines (reproduction, clinical cases, task generation), stock deduction, and protocol enforcement are implemented as triggers and functions. The frontend is a thin presentation layer — the same logic holds regardless of which client connects.
- **Controlled entities.** Diseases, drugs, and animals are never free-text; foreign keys and dropdowns are enforced, keeping the dataset clean and reportable.
- **Immutable stock ledger.** Stock movements are append-only; corrections are entered as new ledger entries, preserving a complete audit trail.
- **Offline-first.** Reads are served from IndexedDB and reconciled with the server when online; a service worker keeps the shell available with no connection. Designed for use in a barn with spotty signal.
- **Versioned schema, CI-deployed.** Migrations live in `supabase/migrations/` and are pushed to production by a GitHub Actions workflow on every merge to `main`. The canonical schema is captured in `supabase/migrations/99999999999999_ground_truth.sql`.
- **Multi-tenant foundations.** A `farm_id` discipline and tenant-scoped policies are in place for future multi-farm expansion.
- **Demo environment.** A read-only demo mirror with a live-data clone (`demo_klonla()` RPC over `postgres_fdw`) lets prospective users explore the real schema without touching production.
- **Zero build step.** No transpiler, no bundler, no dependency resolution at deploy time — the static assets ship as written, keeping the surface area small and the deploy pipeline trivial.

---

## Getting Started

### Prerequisites
- A Supabase project (or any PostgreSQL 14+ instance with the Supabase runtime)
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

## Screenshots

> Add screenshots under `docs/screenshots/` and reference them here — dashboard, animal card, reproduction timeline, clinical case, inventory alerts.

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