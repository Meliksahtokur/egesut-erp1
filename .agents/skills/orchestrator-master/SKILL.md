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
| **F** | **Fork** | Dispatch sub-agents (research = parallel explores; hierarchical = sub-orchestrators with quotas). **Parallel vs Sequential** decision: tightly-coupled files (HTML+JS) → sequential; independent files → parallel. |
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

Before dispatching, assess scope:

```
├── 1 file / minor fix?
│   → request_user_input: "Bunu direkt yapayım mı, yoksa sub-agent açayım mı?"
│
├── 2-3 tightly-coupled files (HTML+JS that share IDs)?
│   → request_user_input: "Tightly-coupled değişiklik, ben yapayım mı?"
│
├── 3+ independent modules?
│   → Sub-agent aç (sorma — bariz büyük iş)
│
└── Read-only research?
    → Paralel explore agent'ları (sorma)
```

**Rule:** Sub-agent overhead > the work itself? Don't spawn. Ask the user.

#### Fork Decision: Parallel vs Sequential

After spawn gate confirms we need sub-agents, decide execution strategy:

```yaml
if task has tightly-coupled files (e.g. HTML + JS must change together,
   or two files share IDs/function names that must match):
  strategy: sequential
  reason: Tight coupling — parallel agents would need to agree on
          shared identifiers, which adds overhead and risks mismatch.
  execution: Main implements directly, sub-agents for isolated review.

elif task has independent files (e.g. separate modules, unrelated dirs):
  strategy: parallel
  reason: No shared state — agents work independently, results merge cleanly.

elif task is research (read-only, no writes):
  strategy: parallel
  reason: Read-only agents never conflict. Use explore type.
```

**Rule of thumb:** If changing file A would break file B without coordinated edits → sequential. If files can be edited independently → parallel.

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

4. **Memory**: `mcp_tools--bank_memory_add` (if available) or `note` for key decisions
5. **Git**: `git add` + `git commit` + `git push`

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
- Failure budget (max retries before reporting to parent)
- Output file requirement (results written to file for persistence)
- Sub-agent spawning rules (leaf agents CANNOT spawn)

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
