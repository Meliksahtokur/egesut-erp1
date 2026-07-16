# EgeSüt ERP

> Offline-tolerant web management system for a working dairy farm — herd, reproduction, clinic, pharmacy, and automated task workflows in one app.

**This is not a portfolio project.** A 157-head dairy farm runs its daily operations on it. As of 16 July 2026: 2,674 recorded operations, 586 of them in the last 30 days, active on 66 of the last 90 days.

**The person who decided what this schema should look like is the veterinarian who does the work.** That is the reason the data model looks the way it does. The drug catalog is grouped the way a pharmacologist groups drugs — β-lactams, macrolides, fluoroquinolones — not the way a developer would guess. The vaccination engine decides whether an animal is immunologically naive by walking the vaccine→disease graph, because "two different vaccines covering the same disease" is a clinical fact before it is a data-modelling decision. Nobody gathered these rules in a requirements workshop and nobody had to.

That distinction shows up in the guardrails more than the features. `scripts/ground-truth-audit.sh` diffs the live database against the checked-in schema, because drift already happened once. Bulk-repair RPCs sit behind a `p_dry_run` flag so nothing destructive runs on deploy. Migration `20260710000001` opens by explaining why the previous three fixes for the same bug regressed. Those aren't things you build because you enjoy writing SQL; they're things you build when you are the one who has to answer for the data being wrong.

Built solo, in roughly four months of working time.

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

Database objects, live: **48 tables · 13 views · 180 functions · 35 triggers · 117 indexes**, built up over **220 versioned migrations**.

---

## The domain model

Most of the engineering in this project is not in the screens. It's here.

### Drugs are a four-level taxonomy, not a text field

```
stok_kategorileri  (16)   Category            "Antimikrobiyaller (Antibiyotikler)"
   └── drug_classes (48)   Group / Class / Active ingredient
                                               "Beta-Laktamlar" → Seftiofur
        └── drug_products (27)  Brand, concentration, route, unit
                                               "Sefanel", IM, ml
             └── stok (41)      Stock item — the physical bottle on the shelf
                  └── stok_hareket (363)  Append-only ledger
```

Every level is a foreign key. There is no free-text drug name anywhere in the system, which is what makes "how much ceftiofur did we use this year" a question with an answer rather than a text-mining exercise.

The rule is enforced in the database, not the UI: `ilac_ekle()` raises an exception if `drug_class_id` is null — *a drug cannot enter stock without being catalogued first*. The same call writes the stock item, the catalog product, and the audit entry in one transaction.

### The clinic closes the loop back to the shelf

```
diseases (41)  ⇄  sablon_hastalik_eslem (11)  ⇄  tedavi_sablonu (3)
                                                    └── tedavi_sablonu_kalem (16)
                                                        day · time · dose · unit · route
                                                        → drug_products → stok
```

Pick a disease, and `tedavi_sablon_uygula(case_id, sablon_id)` materialises a multi-day treatment plan — each day, each hour, each dose bound to a specific product and a specific stock item. Recording an administration deducts the stock and writes the ledger row **in the same transaction as the administration itself** (`add_drug_administration`), so a phone that dies mid-write cannot leave a drug given but never deducted.

Diseases map to templates many-to-many, so one protocol can serve several diagnoses without duplication.

### Vaccination is protocol-driven, and knows what an animal has already seen

```
vaccines (12)          brand · active ingredient · protocol type · mandatory · booster interval
  ├── vaccine_diseases (17)        many-to-many → diseases
  ├── vaccine_protocol_steps (14)  step no · day offset  (multi-dose primers)
  └── vaccination_schedule (5)     target class · timing · sequence
       └── vaccination_log (378)
```

`add_vaccination()` doesn't ask "has this vaccine been given before?" — it asks whether *any* previously administered vaccine shares a target disease with this one, through the `vaccine_diseases` graph. If none does, the animal is naive and gets the primer's step-2 offset; otherwise it gets the booster interval. The follow-up task is then generated automatically, guarded against duplicates.

### Tasks are generated and retired by the database

1,621 tasks so far, and the application has never created one. Triggers do:

| Event | Trigger | Effect |
|---|---|---|
| Confirmed pregnant | `trg_tohumlama_gebe_gorev` | Creates the pre-calving protocol tasks |
| Animal leaves the herd | `trg_hayvan_cikis_gorev_iptal` | Cancels every open task for it |
| Moved to another paddock | `trg_padok_transfer_gorev` | Closes the transfer task |
| Parent task completed | `trg_gorev_parent_kapandi` | Closes its children |
| Any task write | `gorev_log_cycle_guard` | Refuses to create a task cycle |

Calving alone (`dogum_kaydet`) fans out into 16 tasks in one transaction: the postpartum drug protocol (day 0 oxytocin/AD3E/calcium, PG on days 2, 25 and 39 for Presynch-14), heat watch at day 58, and a parent "first-day calf care" task with six children — colostrum, navel disinfection, tagging, and so on.

And the system audits itself: `protokol_eksik_tara()` walks every animal against its expected protocol and reports the steps that were **missed**, late, or upcoming — checking the task log, the application log, and the drug administrations independently, so a step recorded through any path counts as done.

### Nothing is hardcoded

| Table | What it makes configurable |
|---|---|
| `irk_esik` (7) | Insemination and weaning day thresholds, per breed |
| `protokol_ayar` (9) | Protocol parameters, each with `min_deger`/`max_deger` bounds |
| `diseases`, `drug_classes`, `drug_products`, `vaccines` | The entire clinical vocabulary |

The catalogs are managed from the app, by the user — `disease_ekle/guncelle/sil`, `drug_class_ekle/guncelle/sil`, `drug_product_ekle`, `tedavi_sablon_kaydet`. Defining a new active ingredient, a new disease, or a new treatment protocol is a task for the vet on a Tuesday afternoon, not a support ticket and a release.

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
- **Immutable stock ledger.** Stock movements are append-only. Corrections are entered as new ledger rows, never edits or deletes, so the audit trail stays complete. Current stock is always derived, never stored — this is a pharmacy holding controlled veterinary drugs, and "who gave what, to which animal, when, and did anyone alter the record afterwards" needs an answer that a mutable quantity column destroys.
- **Real-time stock, with a fallback.** Ten tables are published to Supabase Realtime; the app subscribes over WebSocket and pulls on `postgres_changes`. Administer a drug on one phone and the stock figure moves on another. If the channel errors or times out the client degrades to 30-second polling and says so, rather than silently going stale.
- **The audit log cannot be rewritten.** `islem_log` is protected by `_islem_log_immutable_guard` — a trigger, not a convention. Three tables (`bildirim_log`, `hayvan_override`, `cop_kutusu`) have RLS enabled with *no policy at all*: a deliberate deny-all that makes them unreachable from any client and available only through `SECURITY DEFINER` RPCs.
- **Migrations document root causes.** They aren't just schema deltas. `20260710000001` opens with why the previous three fixes for the same bug regressed, then lays down five layers of defence — an authoritative column, a recompute path, a repair RPC, a corrected generator, and a splitter for existing bad rows — with the bulk-repair steps behind a `p_dry_run` guard so nothing destructive runs on deploy.
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
- **No withdrawal-period tracking yet.** The system knows the drug, the dose, the animal and the stock movement — but not when that animal's milk or meat may re-enter the food chain. For a dairy this is the most conspicuous gap, and it is the next feature: schema and derivation logic are drafted in [`docs/drafts/`](docs/drafts/), deliberately kept out of the migrations directory until the values are entered from the product labels. Guessing them is a food-safety risk, so they will be entered, not inferred.
- **No lot or expiry tracking.** Stock is tracked by product, not by batch. A recall would have to be reasoned about by date, not traced by lot number.
- **No milk yield.** This is a health, reproduction and pharmacy system. Lactation curves, per-milking yield and bulk-tank data are not modelled — the farm records them elsewhere.
- **No ration module.** Feed and ration planning are not implemented. Planned, not shipped.
- **`drug_products.concentration` is unpopulated.** The column exists as groundwork for weight-based dose calculation (`hayvanlar.canli_agirlik` is already recorded); the feature is not built yet.

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
hayvanlar (157)              — core; padok_id → padoklar, anne_id → hayvanlar (dam lineage)
  ├── tohumlama (258)        — breeding events (per-cycle state machine)
  ├── dogum (63)             — calving records
  ├── kizginlik_log (12)     — heat tracking
  ├── gorev_log (1621)       — task system (parent/child, cycle guard, trigger-generated)
  ├── protokol_instance (83) — running protocol state per animal
  ├── vaccination_log (378)  — → vaccines
  └── cases (37)             — clinical cases → diseases
        └── treatment_days (120) → drug_administrations (158) → drug_products → stok

Drug taxonomy
  stok_kategorileri (16) → drug_classes (48) → drug_products (27) → stok (41)
                           group/class/active ingredient   brand/concentration/route
       └── stok_hareket (363)  — ledger (immutable, append-only; stock is derived, never stored)

Treatment templates
  tedavi_sablonu (3) ⇄ sablon_hastalik_eslem (11) ⇄ diseases (41)
       └── tedavi_sablonu_kalem (16)  — day/time/dose/route → drug_products + stok

Vaccination
  vaccines (12) ⇄ vaccine_diseases (17) ⇄ diseases
       ├── vaccine_protocol_steps (14)  — multi-dose primer schedule
       └── vaccination_schedule (5)     — target class + timing

Configuration
  irk_esik (7)       — per-breed insemination / weaning thresholds
  protokol_ayar (9)  — protocol parameters, min/max bounded

islem_log                                     — immutable audit log (trigger-guarded)
agent_threads + agent_messages + agent_plans  — AI Assistant memory + plan engine (per-user RLS)
prod_fdw                                      — Demo-Mirror FDW bridge
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

**Melik Şah Tokur** — veterinarian and systems designer
*Full-stack: PostgreSQL · JavaScript · Python · Supabase · Playwright · n8n*

I design the data model for domains that have real rules, and then I build it: schemas that enforce their own constraints, workflows that run unattended, and pipelines that survive the source changing shape.

Most systems that model a specialist domain are built by developers interviewing experts, and the gap shows up in the schema — in the field that should have been a foreign key, in the state machine missing the transition that happens twice a year. I came at this one from the other side. If your problem has a real domain underneath it, that's the part I'm interested in.

- GitHub: [@Meliksahtokur](https://github.com/Meliksahtokur)
- Live demo: https://meliksahtokur.github.io/egesut-erp1/

Available for contract work on internal tools, business process automation, and PostgreSQL-backed applications. This repository is the reference — a real operation depends on it, every day.
