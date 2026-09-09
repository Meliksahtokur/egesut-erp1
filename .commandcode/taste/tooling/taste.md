# Tooling Preferences

- **GitNexus** (`mcp__gitnexus__*`) must be used before/after code changes: `detect_changes` for regression verification, `impact` for blast radius analysis. Confidence: 0.90
- **LSP** (pyright, typescript-language-server, postgrestools) must be active during development for real-time diagnostics. Confidence: 0.85
- **Python LSP daemon** should be running persistently (postgrestools). Confidence: 0.80
- **ruff** and **mypy** must pass clean before committing Python code. Confidence: 0.90
- **`goose-teammate.py` bridge** is the standard protocol for Goose subagent dispatch; avoid `goose run` for real work. Confidence: 0.90
- **Goose as primary subagent** for implementation, research, exploration, testing, file/DB changes. Fallback: `pi-teammate`. Confidence: 0.85
- Claude = reasoning and decision engine only. Goose/Pi = all implementation/grunt work. Confidence: 0.85
- **Review order** (mandatory, never reversed): Goose reviews/verifies FIRST, then native Claude `code-reviewer` agent only if needed afterward. Confidence: 0.80
- Use `exa`, `ddg`, and `tools-bank ddg` for web search; built-in web search tools are last resort. Confidence: 0.85
- **`tools-bank` MCP** is the primary backend toolset: supabase_*, memory_*, semantic_search, gitnexus_*, file_*, etc. Confidence: 0.90
- When dispatching to Goose via bridge, always use isolated worktree lanes, never the main repo as `cwd` for `[write]` tasks (to avoid `git_commit_lane` sweeping unrelated files). For `[read]`-only tasks, `/tmp` is safe. Confidence: 0.85
- **No native Claude subagent** (Agent tool: Explore/general-purpose/code-reviewer) unless explicitly permitted — external subagents (Goose, Pi, OMP) are the primary path. Confidence: 0.85
- **Config format: TOML** (stdlib `tomllib`), NOT YAML. No new dependencies without explicit approval. Confidence: 0.85
