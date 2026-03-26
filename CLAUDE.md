# EgeSüt ERP — Claude Instructions

## Session Start Skills

At session start, activate the following skills based on context:

- **superpowers:brainstorming** — yeni özellik fikirleri için
- **superpowers:writing-plans** — plan çıkarmak için
- **superpowers:executing-plans** — planı uygulamak için
- **superpowers:dispatching-parallel-agents** — keşif aşamasında paralel analiz
- **superpowers:systematic-debugging** — bug bulma
- **superpowers:test-driven-development** — her yeni fonksiyon/RPC implementasyonundan önce
- **superpowers:verification-before-completion** — "düzelttim/tamamladım" demeden önce kanıt topla
- **coderabbit:code-review** — push öncesi otomatik review
- **commit-commands:commit-push-pr** — commit + push + PR tek adımda
- **frontend-design** — UI geliştirirken
- **feature-dev** — özellik geliştirme sürecinde

---

## Project Conventions

### Stack
- Vanilla JS PWA, Supabase backend, IndexedDB local cache, offline-first
- No build step — direct browser JS, single `index.html`
- Turkish UI language throughout (labels, toasts, error messages)

### Data Access Pattern
- **Reads**: `idbGetAll('table')` → IndexedDB; `getState('animals')` → in-memory cache
- **Writes**: Always use Supabase RPC functions, never direct REST PATCH/INSERT
  - Tohumlama: `tohumlama_kaydet` RPC only
  - Doğum: `dogum_kaydet` RPC only
  - State transitions: dedicated RPCs (gebe, boş, abort)

### Domain Rules
- Full business logic documented in `.claude/domain-rules.md` — read before touching reproduction/animal modules
- 8 critical rules in section 13 of that file; backend also enforces them

### Code Quality Rules
- Before patching a function, grep for its name across all JS files — duplicate definitions cause silent bugs
- One fix per commit; commit after each verified fix
- Do not bypass tohumlama state machine — guards exist for a reason

### Plan-First Workflow
- Non-trivial changes → update `SONARCLOUD_REMEDIATION_PLAN.md` first, then implement
- Architecture decisions belong in the plan file, not in memory

### Session End
- Update this file with any new project decisions or conventions
- Update `.claude/session-learnings.md` with: what worked, what didn't, MCP patterns, what to avoid
