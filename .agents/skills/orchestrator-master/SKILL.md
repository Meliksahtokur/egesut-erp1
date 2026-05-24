---
name: orchestrator-master
description: "Complex multi-step work: parallel research, hierarchical implementation, or both. Auto-detects mode. Dispatches sub-agents with quotas, territories, and depth limits. Sub-agents communicate in English. User-facing output in user's language."
---

# Orchestrator-Master

**One skill, two operating modes.** Mode is auto-detected from the task.

| Task involves… | Mode |
|---|---|
| Web research, price checks, gap analysis, trend verification | **research** (flat, parallel) |
| Writing code, implementing features, multi-file refactoring | **hierarchical** (recursive, depth-controlled) |
| Both | Research first → hand off findings → hierarchical implementation |

**Language rules:**
- Skill body: English
- Sub-agent prompts & internal communication: **English**
- User-facing output: **user's language**

---

## Mode Selection

```yaml
if task contains [research, verify, check, find, analyze, compare]:
  mode: research

elif task contains [implement, write, create, refactor, build, feature]:
  mode: hierarchical

elif both:
  mode: research -> findings -> hierarchical
```

---

## Workflow: S.A.F.E.R.

| # | Phase | What I do |
|---|-------|-----------|
| **S** | **Scout** | Read workspace, instructions, create plan. |
| **A** | **Ask** | If ambiguous, ask the user. Wait. |
| **F** | **Fork** | Dispatch sub-agents (research = parallel explores; hierarchical = sub-orchestrators with quotas). **Topology selection** decides execution pattern: Hierarchical / Mesh / Ring / Star. |
| **E** | **Evaluate** | Collect results, cross-check, merge. Sub-agent output unavailable → manual verify. |
| **R** | **Review & Refine** | Self-score 1-10. < 8 → iterate. ≥ 8 → commit. |

---

## Phase Details

### S — Scout

**Search before read. MCP before file.**

In a 10k+ codebase, don't grep blindly. Understand WHERE to look first, then search.

Priority:
1. **Execution flow** — `gitnexus_query(query)`, `gitnexus_context(symbol)`, `gitnexus_impact(target)` — understand how code flows, which symbols exist, blast radius before touching anything
2. **Memory & Knowledge** — `memory_search(topic)`, `semantic_search(query)` — has this been solved before? What past decisions apply?
3. **Database** — `supabase_query(table)`, `supabase_rpc(functionname)` — live schema, not stale migrations
4. **Destination search** — `file_search(name)` to find files by name, `grep_files(pattern)` only when you know WHERE to look (specific file/directory). Grep is targeted, not exploratory.
5. **File read** — `read_file(path)` only for full-context needs

Always:
- `list_dir` on the workspace
- `checklist_write` with the full plan
- Check AGENTS.md / CLAUDE.md / project-specific instructions

**Pre-task memory load** (before any sub-agent is spawned):
1. `memory_search(task_topic)` — pull past patterns, decisions, and errors
   similar to the current task
2. `semantic_search(task_description)` — find semantically related code/patterns
3. If matches found → add to context as reference (max 3 most relevant)
4. If no matches → proceed fresh; `note` the new task type for future

**Domain context injection** (BEFORE any code-writing agent is spawned):

Kod yazan her sub-agent, projenin domain kurallarını, mimarisini ve RPC
yapısını BİLMELİDİR. Aksi halde rastgele fonksiyon kullanımı kodu kırabilir,
mimariyi bozabilir. Orkestratör aşağıdaki adımları uygular:

```
1. memory_search(category="critical_rules", query="<domain>")
   → Projenin kritik kurallarını yükle (ör: "raw SQL yasak", "sadece RPC ile yaz")
2. memory_search(category="rpc_reference", query="<task>")
   → İlgili RPC'lerin imzalarını ve parametrelerini yükle
3. memory_search(category="domain_rules", query="<task>")
   → Domain-spesifik kuralları yükle (ör: "stok hareketleri immutable")
4. semantic_search(query="<task_description>")
   → Benzer kod pattern'lerini bul
5. gitnexus_context(symbol="<hedef_fonksiyon>")
   → Değiştirilecek fonksiyonun 360° görünümü (callers/callees)
6. gitnexus_impact(target="<hedef_fonksiyon>")
   → Blast radius — değişiklik neleri kırar?
```

Bu bilgileri birleştirip sub-agent'ın prompt'una **domain context** olarak ekle.
Örnek prompt içeriği:

```
## Domain Context (Orkestratör Tarafından Sağlanır)

### Kritik Kurallar
- Tüm yazma işlemleri RPC üzerinden yapılır. Direkt INSERT/UPDATE/DELETE YASAK.
- Stok hareketleri immutable'dır. Asla silinmez. Düzeltme yeni kayıt olarak girilir.
- Her migration idempotent olmalıdır (DROP IF EXISTS + CREATE OR REPLACE).

### İlgili RPC'ler
- hayvan_ekle(params) → yeni hayvan kaydı oluşturur
- hayvan_guncelle(hayvan_id, params) → hayvan bilgilerini günceller

### Blast Radius
- Bu fonksiyonu değiştirirsen şu 3 fonksiyon etkilenir: [...]
```

**Hierarchical mode** also:
- `gitnexus_detect_changes()` to understand live state
- Define **territories** (each sub-orch owns a file/directory scope)
- Allocate **quotas** (max agents per sub-orch, total ≤ 20)
- Write `PLAN.md` with dependency graph

### A — Ask

If the task is ambiguous:
- Use `request_user_input` with 1-3 specific questions  
- **Wait** for user response
- If clear: skip

### F — Fork

#### Spawn Gate — Do I Need A Sub-Agent?

Before dispatching, assess scope with the full decision framework:

```
📋 GÖREV DEĞERLENDİRME
│
├── 1. BOYUT: Karmaşıklık
│   ├── Tek dosya / basit fix?
│   │   → request_user_input: "Bunu direkt yapayım mı, yoksa sub-agent açayım mı?"
│   │
│   ├── 2-3 tightly-coupled dosya? (HTML+JS, shared IDs)
│   │   → Spawn gate: Sor kullanıcıya
│   │   → Topoloji: Hierarchical (main handles, sub-agents isolated)
│   │   → Agent tipi: implementer
│   │
│   ├── 3+ bağımsız modül?
│   │   → Spawn: Direkt sub-agent aç (sorma)
│   │   → Topoloji: Mesh veya Star
│   │   → Agent tipi: implementer (per module) veya explorer (read-only)
│   │
│   ├── Pipeline / zincir? (output→input)
│   │   → Spawn: Direkt aç
│   │   → Topoloji: Ring
│   │   → Agent tipi: implementer
│   │   → Ek: checkpoint=true
│   │
│   └── Read-only araştırma?
│       → Spawn: Paralel explorer aç (sorma)
│       → Topoloji: Star
│       → Agent tipi: explorer (birden çok)
│       → Profile: research
│
├── 2. BOYUT: Kritiklik
│   ├── Sıradan işlem?
│   │   → Profile: default veya fast
│   │   → Consensus: none
│   │
│   ├── Riskli işlem? (bulk UPDATE, migration, geri alınamaz)
│   │   → Profile: critical
│   │   → Consensus: majority (3 implementer + 3 reviewer)
│   │   → Agent tipi: implementer + reviewer
│   │
│   └── Deneysel / keşif?
│       → Profile: fast veya research
│       → Agent tipi: explorer
│       → Consensus: none
│
├── 3. BOYUT: Agent Tipi Seçimi
│   ├── Sadece okuyacak → explorer
│   ├── Kod yazacak → implementer (varsayılan)
│   ├── İnceleme yapacak → reviewer
│   └── Çıktıları birleştirecek → consolidator
│
└── 4. BOYUT: Memory
    ├── Pre-task: memory_search(task_topic) → referans yükle
    └── Post-task: memory_add() → pattern kaydet
```

**Rules:**
- Sub-agent overhead > the work itself? Don't spawn. Ask the user.
- Kritik işlem + geri alınamaz → profile=critical (consensus zorunlu)
- Araştırma → profile=research, explorer tipi
- Pipeline → Ring topolojisi, checkpoint açık
- Varsayılan: Star topoloji, implementer tipi, consensus kapalı

**Config reference:** Agent types, quotas, model, and concurrency are defined in
`config.toml` (companion file). Profile seçimi: `profile=fast`, `profile=deep`,
`profile=critical`, `profile=research`. See [Configuration](#configuration) section.

#### Fork Decision: Topology Selection

After spawn gate confirms we need sub-agents, choose the execution topology.
Topology defines HOW agents connect, share state, and pass results.

##### Topology Reference

```
Hierarchical          Mesh                  Ring                  Star
─────────────────     ────────────────      ────────────────      ────────────────
    Queen              A ←→ B ←→ C          A → B → C → D        A, B, C → Hub
   /  |   \            ↑         ↓          ↓         ↑              ↓    ↓
  W1  W2   W3          D ←────── E          D ←────── A           Hub→Result
```

| Topology | Bağımlılık | Ne Zaman | Örnek |
|----------|-----------|----------|-------|
| **Hierarchical** | Sıralı, bağımlı | Task'ların çıktısı bir sonrakini besler | Plan → Tasarım → Kod → Test → Deploy |
| **Mesh** | Bağımsız, eşit | Modüller birbirinden bağımsız değişir | JS frontend + SQL migration + Doküman |
| **Ring** | Pipeline | Çıktı bir sonraki adımın girdisi | Parse → Transform → Validate → Load |
| **Star** | Merkezi hub | 1 orkestratör, N worker, sonuçları toplar | tools-bank ACP (Claude ↔ Goose worker) |

##### Selection Logic

```yaml
if task is research (read-only, no writes):
  topology: star
  agent_type: explorer
  reason: Flat parallel research, main orchestrator collects results.

elif task has tightly-coupled files (HTML+JS, shared IDs):
  topology: hierarchical
  profile: deep
  reason: Tight coupling — sequential processing avoids mismatch.
  execution: Main handles the coupled files, sub-agents for isolated parts.

elif task is a pipeline (output→input chain):
  topology: ring
  agent_type: implementer
  reason: Each step produces input for the next.
  checkpoint: true  # memory_add after each step for recoverability

elif task has 3+ independent modules:
  topology: mesh
  agent_type: implementer (per module)
  reason: No shared state — modules change independently.

elif task is critical (bulk update, irreversible):
  topology: hierarchical + consensus
  profile: critical
  reason: Requires review gate before execution.

else:
  topology: star
  agent_type: implementer
  reason: Default — main orchestrator, one or more workers.
```

**Rule of thumb:** Choose based on data flow — if outputs chain together → Ring.
If outputs merge → Star. If outputs are independent → Mesh.
If outputs are sequential dependencies → Hierarchical.

#### Research Mode (Flat, Parallel)

Break into independent research units. Open all in one turn.

```
agent_open(name="researcher-A", type="explore", 
           prompt="Search web for [topic]. Return structured data in English.",
           fork_context=true)

agent_open(name="researcher-B", type="explore",
           prompt="Find gaps in [area]. Return 5-10 findings in English.",
           fork_context=true)
```

**Key:**
- `type: "explore"` guarantees read-only
- `fork_context: true` preserves cache
- Agent type: `explorer` (read-only) by default for research
- Profile override: add `profile=research` for higher concurrency limits
- See [Agent Types](#agent-types) for available types
- Prompts in **English**
- Sub-agents return findings in **English**
- I synthesize in my head, report to user in **user's language**

#### Hierarchical Mode (Recursive, Depth-Controlled)

**Decompose** into sub-orchestrators. Each gets:
- A **territory** (file/directory scope — they own it)
- A **quota** (max agents they can spawn, including themselves)
- A **max_depth** (0=leaf, 1=can spawn leaves, 2=can spawn sub-orchs)
- A **goal** in English
- A **WORKER.md prompt** template (see skill companion file)

```yaml
# Main orchestrator (me):
#   quota: 20 (total system max)
#   max_depth: 3 (I can spawn sub-orchs that spawn sub-orchs)

Sub-orch example:
  name: "auth-service"
  type: custom
  agent_type: "implementer"    # or explorer / reviewer / consolidator
  profile: "deep"              # optional, overrides defaults from config.toml
  config_path: ".claude/skills/orchestrator-master/config.toml"  # loaded automatically
  allowed_tools: ["write_file", "edit_file", "read_file", "exec_shell"]
  prompt: (WORKER.md template filled for this territory)
  max_depth: 2
  fork_context: true
```

**Recursion rules:**
- `max_depth=3` (main): can spawn depth=2 agents
- `max_depth=2` (sub-orch): can spawn depth=1 agents
- `max_depth=1` (sub-sub-orch): can spawn depth=0 leaves only
- `max_depth=0` (leaf): cannot spawn. Writes files, runs tests, reports.

**Quota allocation:**
- System max: 20 concurrent (upper ceiling, not a target)
- Actual usage depends on need — small tasks use 1-2, large refactors use more
- Always reserve 2 slots for emergencies (review, hotfix)

```
Me (1) + Direct agents (2) + Auth-team (5) + API-team (6) + UI-team (4) + Reserve (2) = 20
```

**Territory enforcement:**
- **Write territory**: disjoint — each agent writes ONLY to files inside its territory. If an agent needs to touch a file outside, it must ask the parent orchestrator.
- **Read territory**: overlapping allowed — agents can read any file for context (e.g., JS agent can read HTML to verify ID names).
- If territory collision on write → parent renegotiates boundaries.
- **Frontend HTML+JS tight coupling**: when HTML and JS must change together, the main orchestrator or a single agent handles both to avoid ID/class mismatch.

**Commit Lock (Parallel Write Koruma):**

Paralel Mesh topolojisinde birden çok agent aynı anda `git commit` yapabilir.
Bu race condition'lara ve merge conflict'lerine yol açar. Commit Lock bunu engeller.

```
Mesh:
  Agent A (JS) ──→ commit(lock)
  Agent B (SQL) ──→ commit(lock)   ← aynı anda sadece 1 commit
  Agent C (Docs) ──→ commit(wait)  ← sıradaki lock'u bekler
```

**Kilit işleyişi:**
1. Her yazma agent'ı commit öncesi lock alır: `agent_acquire_commit_lock(session_id)`
2. Lock varsa (423): 3 saniye bekle, tekrar dene (max 5)
3. Lock alındı: `git add` + `git commit` + `git push`
4. Lock bırak: `agent_release_commit_lock(session_id)`
5. Sonraki agent lock'u alıp commit yapar

**Kurallar:**
- Her agent commit öncesi lock almak ZORUNDADIR
- Lock timeout: 30 saniye (max bekleme)
- Lock sahibi crash olursa 60 saniye sonra otomatik release
- Aynı anda sadece 1 commit (sequentialized)
- lock alınamazsa agent retry eder, commit'siz rapor döner

**Agent model:**
- Default model is **deepseek-v4-flash**. Always.
- Never switch to pro without user explicitly requesting it.

### E — Evaluate

#### Research Mode
1. `agent_eval(block=true)` on all sub-agents → read summaries
2. If summary insufficient → `agent_eval(block=false)` for fresh projection
3. Large outputs → `handle_read` instead of copying to context
4. Cross-check: if sub-agent claims X, verify with `read_file` or `web_search`
5. Synthesize findings in my context
6. Report to user in **user's language**

#### Hierarchical Mode
1. Each sub-orchestrator evaluates its own children recursively
2. I evaluate only my direct sub-orchestrators
3. If a sub-orch fails: retry, reassign, or absorb its territory
4. Cross-check file boundaries: `git diff --stat` to verify territory compliance
5. Run integration tests after all sub-orchs complete

#### Consensus Mode (profile=critical)

When `profile=critical` is active (consensus=majority), use 3-way review:

```
Critical Task
     │
     ├── Worker 1 (implementer) → produces output
     ├── Worker 2 (implementer) → produces output
     └── Worker 3 (implementer) → produces output
     │
     ├── Reviewer 1 (reviewer) → evaluates all 3
     ├── Reviewer 2 (reviewer) → evaluates all 3
     └── Reviewer 3 (reviewer) → evaluates all 3
     │
     └── Majority vote → select best result
          (≥2/3 agreement required)
```

**Workflow:**
1. Dispatch 3x `implementer` agents with the same task (parallel, Mesh topology)
2. Wait for all 3 to complete
3. Dispatch 3x `reviewer` agents — each reviews all 3 outputs
   
   **Reviewer her 3 çıktıyı şunlarla birlikte alır:**
   - **Task context**: "Bu SQL migration'ının amacı X tablosuna Y kolonunu eklemekti"
   - **Domain rules**: "Migration'lar idempotent olmalı, DROP IF EXISTS kullan"
   - **Acceptance criteria**: "Migration sonrası Z sorgusu çalışmalı"
   
   Reviewer sadece koda bakmaz — **kodun amaca uygunluğunu** değerlendirir.
   
4. Collect reviewer scores (1-10 scale) + rationale
5. **Majority rule**: if ≥2/3 reviewers agree on one output, that wins
6. **Weighted tiebreak**: if split, main orchestrator picks by:
   - Best verification gate results
   - Most conservative output (for destructive operations)
   - Fastest execution time (for performance-sensitive tasks)
7. Winner's output becomes the final result
8. Losers' outputs are logged via `note` for audit trail

**When to use:**
- Bulk UPDATE/DELETE operations (no rollback)
- Migration deployment to production
- Any task where failure costs > 3× the agent cost
- User explicitly says "bu kritik, dikkatli ol"

**When NOT to use:**
- Research/read-only tasks (waste of tokens)
- Rapid prototyping (slows velocity)
- Simple 1-file fixes (overkill)

#### Checkpoint Pattern (Ring Topology)

Ring topolojisinde her adım bir sonrakinin girdisini üretir. Adımlardan
biri başarısız olursa tüm zincir bozulur. Checkpoint'ler zinciri kurtarılabilir
kılar.

```
Pipeline (Ring):
  Step A → [CHECKPOINT] → Step B → [CHECKPOINT] → Step C → [CHECKPOINT]
     │                        │                        │
     └── memory_add(A)        └── memory_add(B)        └── memory_add(C)
         + checklist_mid         + checklist_mid           + finalize
```

**Ne zaman kullanılır:**
- 5+ adımlı pipeline'lar (ETL, migration, veri dönüşümü)
- Her adımı ≥30 saniye olan uzun işlemler
- Adımlar arasında dış sisteme bağımlılık olan işler (Supabase RPC, GitHub API)

**Checkpoint işleyişi:**
1. Her başarılı adım sonrası `memory_add` ile ara durumu kaydet:
   - Adım çıktısı (dosya adı, hash, satır sayısı)
   - Sonraki adımın girdi olarak ne kullanacağı
   - Şu ana kadar tamamlanan adımların listesi
2. `checklist_update` ile ilerlemeyi işaretle
3. Bir adım başarısız olursa:
   - Son checkpoint'i `memory_search` ile bul
   - Hangi adımda kaldığını tespit et
   - Başarısız adımı tekrar dene (farklı agent_type veya profile ile)
   - Checkpoint'ten devam et, başa dönme

**Checkpoint yapılandırması:** `config.toml` altında `[checkpoint]` bölümü.

#### Sub-agent Output Unavailable Fallback

If `agent_eval` returns empty/"not available" for a completed agent:

```
1. Try agent_eval(block=false, timeout_ms=5000) for a fresh projection
2. If still empty → check if agent wrote any output files (WORKER.md template
   requires agents to write results to a specified output file)
3. If no output file → check agent summary from subagent.done event
4. If summary insufficient → manually verify: read_file, grep_files on
   the files the agent was supposed to modify
5. Continue — do NOT block indefinitely. Side-effects (file writes, git commits)
   persist even if reports are lost.
```

**Key insight:** Sub-agent side-effects (file writes, git commits) persist even if the output report is lost. Verify the files, not the agent's self-report.

### R — Review & Refine

1. **Self-score** 1-10:
   - Completeness: all tasks done?
   - Accuracy: claims verified, tests pass?
   - Structure: clean, documented, follows conventions?
   - Edge cases: error paths, missing scenarios?

2. Score < 8: identify gaps, dispatch fixes, re-evaluate
3. Score ≥ 8: finalize

4. **Memory — post-task save**:
   - **Başarılı** task → `memory_add(category="code_change", priority="medium")`:
     - Ne yapıldı, hangi dosyalar değişti, hangi RPC/kural kullanıldı
     - Etiketler: dosya adları, migration no, hata kodları
   - **Başarısız** task → `note` ile hata kaydı:
     - Ne denendi, nerede takıldı, alternatif ne olabilir
   - **Yeni kural keşfi** → `memory_add(category="critical_rules", priority="high")`:
     - "X asla Y yapılmaz" tipi domain kuralı
   - **Yeni RPC/view** → `memory_add(category="rpc_reference", priority="high")`:
     - RPC adı, parametreleri, hangi migration'da eklendi
5. **Git**: `git add` + `git commit` + `git push`

---

## Configuration

The skill reads parameters from `config.toml` (companion file). This separates
runtime settings from workflow instructions.

### Defaults

| Param | Default | Açıklama |
|-------|---------|----------|
| `max_concurrent_agents` | 10 | Max concurrent sub-agents |
| `reserve_slots` | 2 | Emergency slots |
| `default_model` | `deepseek-v4-flash` | Model for sub-agents |
| `fork_context` | true | Prefix-cache sharing |
| `max_depth` | 3 | Max recursion depth |
| `default_agent_type` | `implementer` | Default agent type |
| `consensus` | `none` | Consensus mode |
| `failure_budget` | 3 | Max retries |
| `checkpoint.enabled` | true | Ring topology checkpoint |
| `checkpoint.interval` | 3 | Checkpoint every N steps |
| `checkpoint.recovery` | true | Auto-recover on failure |
| `workers.audit.interval` | 5 | Audit every N tasks |
| `workers.consolidate.interval` | 10 | Consolidate every N tasks |
| `workers.learn.interval` | 20 | Learn every N tasks |

### Profiles

```yaml
fast:     max_depth=1, concurrency=4  — lightweight, single depth
deep:     max_depth=3, concurrency=10 — full recursive mode
critical: max_depth=2, concurrency=6, consensus=majority — max quality
research: max_depth=0, concurrency=8, default_agent_type=explorer — read-only
```

Override at spawn: `agent_open(..., profile="research")`

### Per-Type Tool Restrictions

Tool access per agent type:

| Type | Allowed Tools (categories) | Can Spawn? |
|------|---------------------------|------------|
| `explorer` | read, search, web, gitnexus(read), semantic_search, supabase(read), graphify | No |
| `implementer` | read/write/edit, exec_shell, agent_open/eval/close, gitnexus(full), semantic_search, memory, supabase(full), graphify, validate, git | Yes |
| `reviewer` | read, review, exec_shell, gitnexus(read), semantic_search, memory, supabase(read), graphify, git(diff/log) | No |
| `consolidator` | read, write_file, edit_file, handle_read, gitnexus(read), semantic_search, memory, supabase(read), graphify | No |

Full tool lists per type in `config.toml` → `[agent_types.<type>]`.

---

## Agent Types

4 specialized agent types, selected at spawn time:

| Type | Role | When to Use |
|------|------|-------------|
| `explorer` | **Keşif** — read-only araştırma | Web araştırması, kod okuma, doküman analizi. Asla yazma yapmaz. |
| `implementer` | **Uygulama** — kod yazma, test | Feature implementasyonu, hata düzeltme, refactor. Varsayılan tip. |
| `reviewer` | **İnceleme** — kod review, hata bulma | Sub-agent output'larını kontrol, kod kalitesi denetimi. |
| `consolidator` | **Birleştirme** — çıktıları sentezleme | Çoklu sub-agent çıktısını birleştirme, rapor yazma. |

**Seçim kuralı:**
- Read-only task → `explorer` (en hızlı, en güvenli)
- Write task → `implementer` (full tool set)
- Quality gate → `reviewer` (consensus için)
- Merge task → `consolidator` (sentez için)

**Agent type overrides in config.toml:**
Each type has its own `[agent_types.<type>]` section defining allowed tools,
max_depth, and spawn capability. Override per-session via `profile=` parameter.

---

## Hooks

Lifecycle hooks fire at key points during task execution. All hooks are
**optional** — they implement behavior (log, notify, learn, escalate) without
blocking the main execution.

| Hook | When | Purpose |
|------|------|---------|
| `pre-dispatch` | Before sub-agent is opened | Validate inputs, check quota, load context from `memory_search` |
| `post-task` | After sub-agent completes successfully | Save pattern to `memory_add`, update checklist, log success |
| `on-failure` | When sub-agent fails (budget exhausted) | Escalate to parent, `note` the error, suggest alternative |

Hooks are configured in `config.toml` under `[hooks]`. Default: all enabled.

### Hook Implementation Templates

#### pre-dispatch
```yaml
when: before agent_open(name="X")
do:
  1. memory_search(query=task_topic, limit=3)
     → if result: add to agent prompt as "Geçmiş pattern'ler"
     → if empty: proceed fresh
  2. quota_check: available_slots > 0?
     → if no: queue task, notify user "Kota doldu, beklemeye alındı"
     → if yes: proceed
  3. profile_load: load config.toml[profile=current]
     → override agent params
```

#### post-task
```yaml
when: after agent_eval(name="X") → status=completed
do:
  1. if success:
     memory_add(content="Başarılı: [task summary]", 
                category="code_change", 
                priority="medium",
                tags="[dosya_adi],[migration_no]")
     checklist_update(id=X, status=completed)
  2. if new domain rule discovered:
     memory_add(content="Kural: [rule description]",
                category="critical_rules",
                priority="high")
```

#### on-failure
```yaml
when: agent retry budget exhausted
do:
  1. note("HATA: [task] — [error description]")
  2. memory_add(content="Başarısız: [task] — [error]",
                category="general",
                priority="low",
                tags="hata,cozulmedi")
  3. suggest_alternative:
     - Retry with different agent_type (explorer → implementer)
     - Retry with profile=critical (consensus)
     - Report to user: "X başarısız oldu, alternatif önerim: Y"
  4. absorb_territory: parent takes over if sub-orch failed
```

Hooks are optional. Enable/disable in `config.toml` under `[hooks]`.

---

## Background Workers

Background workers are long-running periodic tasks that operate alongside
the main orchestration. They don't block the main workflow — they fire
at configured intervals.

### Worker Types

| Worker | Frequency | Purpose |
|--------|-----------|---------|
| `audit` | Her 5. task'ta bir | Kod kalitesi kontrolü, hata taraması |
| `consolidate` | Her 10. task'ta bir | `memory_add` ile pattern'leri birleştir, eski notları temizle |
| `learn` | Her 20. task'ta bir | Başarılı pattern'leri analiz et, sık kullanılan akışları `note` |

### Worker Lifecycle

```
Ana akış                       Background
─────────                      ──────────
Task 1 ──┐
         ├── task_complete →   Worker: audit()
         │                     → checklist consistency check
         │                     → error pattern scan
Task 2 ──┤
         ├── task_complete
Task 3 ──┤
...       │
Task 5 ──┐
         ├── task_complete →   Worker: consolidate()
         │                     → memory_add geçmiş pattern'leri
         │                     → remove stale checkpoint'ler
Task 6 ──┤
...       │
Task 10 ─┐
         ├── task_complete →   Worker: learn()
         │                     → analyze success patterns
         │                     → note("sık kullanılan akış: ...")
```

### Config (config.toml)

```toml
[workers]
enabled = true

[workers.audit]
enabled = true
interval = 5     # her 5 task'ta bir

[workers.consolidate]
enabled = true
interval = 10    # her 10 task'ta bir

[workers.learn]
enabled = true
interval = 20    # her 20 task'ta bir
```

Her worker, ana orchestrator tarafından `post-task` hook'u içinden
tetiklenir. Worker'ın kendisi bir sub-agent değildir — ana orchestrator
kendi context'inde worker fonksiyonlarını çalıştırır.

---

## Context Management

| Technique | Purpose | When |
|-----------|---------|------|
| `fork_context: true` | Share prefix cache, reduce bloat | Every `agent_open` |
| `handle_read` | Read large outputs without copying to context | Sub-agent output > 50 lines |
| `checklist_write` | Track progress outside context | Every phase |
| `note` | Persist decisions | After key decisions |
| **No janitor agent** | Checklist + PLAN.md + CHANGELOG.md are sufficient | Never |

**Rule:** Never copy sub-agent output directly into context. Use `handle_read` for projections. No state outside checklist + plan files.

---

## Available MCP Tools (Search Before Read)

| Tool | What it does | Instead of |
|------|-------------|------------|
| `gitnexus_query(query)` | Execution flow discovery | `grep` + manual trace |
| `gitnexus_context(symbol)` | 360° symbol view (callers, callees) | Reading 5 files to understand 1 function |
| `gitnexus_impact(target)` | Blast radius analysis | Guessing what breaks |
| `memory_search(query)` | FTS5 full-text memory search | Re-asking the same question |
| `semantic_search(query)` | Vector embedding search in codebase | Reading random files to find related code |
| `grep_files(pattern)` | Regex search (targeted — know where first) | `read_file` + manual search |
| `file_search(name)` | Fuzzy file name lookup | `find -name` or `ls` + guess |
| `mcp_tools--bank_supabase_query(table)` | Live DB schema query | Reading stale migration files |
| `mcp_tools--bank_supabase_rpc(function)` | Live RPC call | Reading RPC definition + guessing params |
| `mcp_tools--bank_knowledge_graph_query(entity)` | Entity relationship lookup | Reading architecture docs |
| `mcp_tools--bank_memory_add(content)` | Persist decision to memory | Losing context in next session |
| `graphify` | Codebase graph analysis — dependencies, call graphs | Manual trace through code |
| `request_user_input` | Ask user 1-3 questions when ambiguous | Guessing user intent |

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Grep the whole codebase randomly | First understand flow via gitnexus, then grep specific files |
| Spawn a sub-agent for a single-file fix | Ask user: "Bunu direkt yapayım mı?" |
| Spawn 20 agents because max is 20 | Use only what you need; reserve 2 for emergencies |
| Copy sub-agent output directly into context | Use `handle_read` for projections |
| Replace `checklist_write` with file writes | Use `checklist_write` — it updates the sidebar progress |
| Use pro model unless asked | **Always flash by default.** Never switch without user request. |
| Read migration files for live schema | Use `supabase_query` — migrations can be stale |
| Try to fix without root cause | Systematic debugging: Phase 1 → Phase 2 → Phase 3 → Phase 4 |
| Answer from memory or mental calculation | Always use tools: `exec_shell` for math, `read_file` for content |
| Let sub-agent outputs go unverified | Always verify side-effects — `read_file`, `git diff` on claimed changes |

---

## Worker Template: WORKER.md

See companion file `WORKER.md` in this directory. It provides a standardized prompt template for sub-agents, with:
- Territory declaration
- Agent type selection (explorer / implementer / reviewer / consolidator)
- Failure budget (max retries before reporting to parent)
- Output file requirement (results written to file for persistence)
- Sub-agent spawning rules (leaf agents CANNOT spawn)

**Agent type** determines available tools and spawn capability for the worker.
See [Agent Types](#agent-types) section for details.

Load it with `load_skill("orchestrator-master")` or inline the template when spawning agents.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Sub-agent fails | Simplify prompt, retry. If still fails, absorb territory. |
| Sub-agent output unavailable | Check output file → manual verify via read_file/grep. Side-effects persist. |
| Test fails | `git revert HEAD` last change, fix, retry |
| Web search empty | Try alternative query, note the gap |
| Territory collision | Parent renegotiates boundaries. Last resort: clone project. |
| `exec_shell` timeout (>120s) | Use `task_shell_start` + `task_shell_wait` for long tasks |
| Quota exceeded | Sub-orch must reject new work and report back to parent |
| Interface mismatch | Update INTERFACES.md (written by main, read by all) |
| Commit Lock failure | Retry with exponential backoff (3s → 6s → 12s). If still locked after 5 retries, skip commit and report. |
| Checkpoint recovery fails | Fall back to previous checkpoint. Manual review required before retry. |
| Background worker error | Log via `note`, disable that worker, continue main workflow. Report to user at next interaction. |

---

## Best Practices

1. **Understand before searching.** `gitnexus_query` first to trace execution flow, then `memory_search`/`semantic_search` for concept, then targeted `grep_files` on specific files. Grep blindly in a 10k+ codebase wastes time.
2. **MCP before file.** `supabase_query` for live schema, `gitnexus_context` for code understanding, `memory_search` for past decisions. Files are stale; MCP is live.
3. **Research mode: batch all sub-agents** in one turn. Never serialize.
4. **Hierarchical mode: depth before breadth.** Allocate quota wisely.
5. **Write territory disjoint, read territory overlapping.** Writing agents must not touch the same file. Reading any file for context is always allowed.
6. **Tightly-coupled files (HTML+JS) → sequential execution.** Parallel agents on shared IDs/classes risk mismatch. Main orchestrator handles.
7. **Sub-agents speak English.** Prompts, reports, internal messages.
8. **User-facing output in user's language.** 
9. **Verify side-effects.** Sub-agent says "done" → `read_file` to confirm. Output may be unavailable but files persist.
10. **Small commits.** One logical change per commit.
11. **No janitor agent.** Checklist + PLAN.md is the truth.
12. **fork_context: true always.** Cache is expensive.
13. **handle_read for big results.** Don't bloat main context.
14. **Always flash.** Never use pro model unless the user explicitly requests it.