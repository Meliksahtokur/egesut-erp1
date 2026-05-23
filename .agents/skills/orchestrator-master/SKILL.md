---
name: orchestrator-master
description: "Complex multi-step work: parallel research, hierarchical implementation, or both. Auto-detects mode. Dispatches sub-agents with quotas, territories, and depth limits. Sub-agents communicate in English. Main agent speaks local language with the user."
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
- User-facing output: **user's language** (Turkish in this session)

---

## Mode Selection

When the task arrives, classify it:

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
| **F** | **Fork** | Dispatch sub-agents (research = parallel explores; hierarchical = sub-orchestrators with quotas). |
| **E** | **Evaluate** | Collect results, cross-check, merge. |
| **R** | **Review & Refine** | Self-score 1-10. < 8 → iterate. ≥ 8 → commit. |

---

## Phase Details

### S — Scout

**Search before read. MCP before file.**

Priority:
1. **Memory & Knowledge** — `memory_search(topic)`, `semantic_search(query)`, `gitnexus_query(query)` — has this been solved before?
2. **Database** — `supabase_query(table)`, `supabase_rpc(functionname)` — live schema, not stale migrations
3. **Fast search** — `grep_files(pattern)` to find symbols, `file_search(name)` to find files
4. **Knowledge graph** — `gitnexus_context(symbol)` for 360° code view, `gitnexus_impact(target)` for blast radius
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
- I synthesize in my head, report to user in **Turkish**

#### Hierarchical Mode (Recursive, Depth-Controlled)

**Do NOT implement everything myself.** Decompose into sub-orchestrators, each with:
- A **territory** (file/directory scope — they own it)
- A **quota** (max agents they can spawn, including themselves)
- A **max_depth** (0=leaf, 1=can spawn leaves, 2=can spawn sub-orchs)
- A **goal** in English

```yaml
# Main orchestrator (me):
#   quota: 20 (total system max)
#   max_depth: 3 (I can spawn sub-orchs that spawn sub-orchs)

Sub-orch example:
  name: "auth-service"
  type: custom
  allowed_tools: ["write_file", "edit_file", "read_file", "exec_shell"]
  prompt: >
    You are an orchestrator. Territory: src/auth/.
    Your quota: 5 agents total (yourself + 4 children).
    max_depth: 2 (you can spawn sub-orchs that spawn leaves).
    Allocate your quota among your children.
    Write files in your territory. Communicate in English.
    Report back when all children complete.
  max_depth: 2
  fork_context: true
```

**Recursion rules:**
- `max_depth=3` (main): can spawn depth=2 agents
- `max_depth=2` (sub-orch): can spawn depth=1 agents
- `max_depth=1` (sub-sub-orch): can spawn depth=0 leaves only
- `max_depth=0` (leaf): cannot spawn. Writes files, runs tests, reports.

**Quota allocation example (total = 20):**

```
Me (1) + Direct agents (2) + Auth-team (5) + API-team (6) + UI-team (4) + Reserve (2) = 20
                                                                   
Auth-team (quota: 5, depth: 2)                                     
  ├── agent-1 (leaf, depth: 0, territory: auth/login.ts)           
  ├── agent-2 (leaf, depth: 0, territory: auth/register.ts)        
  └── utils-orch (sub-orch, depth: 1, quota: 2, territory: auth/utils/)
        ├── leaf-1 (depth: 0, territory: auth/utils/validators.ts) 
        └── leaf-2 (depth: 0, territory: auth/utils/hash.ts)       
```

**Territory enforcement:** Each agent writes ONLY to files inside its territory. If an agent needs to touch a file outside its territory, it must ask the parent orchestrator. Parent reassigns or rejects.

### E — Evaluate

#### Research Mode
1. `agent_eval(block=true)` on all sub-agents → read summaries
2. If summary insufficient → `agent_eval(block=false)` for fresh projection
3. Large outputs → `handle_read` instead of copying to context
4. Cross-check: if sub-agent claims X, verify with `read_file` or `web_search`
5. Synthesize findings in my context
6. Report to user in **Turkish**

#### Hierarchical Mode
1. Each sub-orchestrator evaluates its own children recursively
2. I evaluate only my direct sub-orchestrators
3. If a sub-orch fails: retry, reassign, or absorb its territory
4. Cross-check file boundaries: `git diff --stat` to verify territory compliance
5. Run integration tests after all sub-orchs complete

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
| `grep_files(pattern)` | Regex search across project files | `read_file` + manual search |
| `file_search(name)` | Fuzzy file name lookup | `find -name` or `ls` + guess |
| `memory_search(query)` | FTS5 full-text memory search | Re-asking the same question |
| `semantic_search(query)` | Vector embedding search in codebase | Reading random files to find related code |
| `gitnexus_query(query)` | Execution flow discovery | `grep` + manual trace |
| `gitnexus_context(symbol)` | 360° symbol view (callers, callees) | Reading 5 files to understand 1 function |
| `gitnexus_impact(target)` | Blast radius analysis | Guessing what breaks |
| `gitnexus_detect_changes()` | Dependency-aware change analysis | `git diff` + manual analysis |
| `mcp_tools--bank_knowledge_graph_query(entity)` | Entity relationship lookup | Reading architecture docs |
| `mcp_tools--bank_supabase_query(table)` | Live DB schema query | Reading stale migration files |
| `mcp_tools--bank_supabase_rpc(function)` | Live RPC call | Reading RPC definition + guessing params |
| `mcp_tools--bank_memory_add(content)` | Persist decision to memory | Losing context in next session |

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Sub-agent fails | Simplify prompt, retry. If still fails, absorb territory. |
| Test fails | `git revert HEAD` last change, fix, retry |
| Web search empty | Try alternative query, note the gap |
| Territory collision | Parent renegotiates boundaries. Last resort: clone project. |
| `exec_shell` timeout (>120s) | Use `task_shell_start` + `task_shell_wait` for long tasks |
| Quota exceeded | Sub-orch must reject new work and report back to parent |
| Interface mismatch | Update INTERFACES.md (written by main, read by all) |

---

## Best Practices

1. **Search before read.** `grep_files`, `file_search`, `semantic_search`, `memory_search` before any `read_file`. Don't read a file to find something — search for it.
2. **MCP before file.** `supabase_query` for live schema, `gitnexus_context` for code understanding, `memory_search` for past decisions. Files are stale; MCP is live.
3. **Research mode: batch all sub-agents** in one turn. Never serialize.
4. **Hierarchical mode: depth before breadth.** Allocate quota wisely.
5. **Territories must be disjoint.** No two agents own the same file.
6. **Sub-agents speak English.** Prompts, reports, internal messages.
7. **User-facing output in user's language.** Turkish in this session.
8. **verify side-effects.** Sub-agent says "done" → `read_file` to confirm.
9. **Small commits.** One logical change per commit.
10. **No janitor agent.** Checklist + PLAN.md is the truth.
11. **fork_context: true always.** Cache is expensive.
12. **handle_read for big results.** Don't bloat main context.
