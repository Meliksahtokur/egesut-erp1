# Coding Style Preferences

- **Python 3.14** is the current system default; venvs use `~/.venvs/<name>/`. Confidence: 0.85
- **No `pip` available** on system Python; use venv with pre-installed packages or standalone scripts. Confidence: 0.80
- **TR language** for codebase content (Turkish comments, docstrings, variable names in domain logic). Confidence: 0.75
- **Vanilla JS** stack (no build step, no framework overhead). PWA with service worker. Confidence: 0.80
- **Supabase SDK + parameterized RPC** for all database access; no raw SQL string concatenation. Confidence: 0.85
- **Business logic in PostgreSQL** (functions, triggers, RLS), NOT in frontend JS. `frontend iş mantığı yapmaz`. Confidence: 0.90
- **Protocol-DI adapter pattern** for multi-source engines (runtime_checkable Protocol, registry, per-source adapters). Confidence: 0.80
- **asyncio + Semaphore per-source** concurrency model for Python scrapers. Confidence: 0.75
- **curl_cffi** with chrome131 impersonation for HTTP fetching (not raw requests/urllib). Confidence: 0.80
- **selectolax** (Lexbor) for HTML parsing on Python 3.14; lxml has no 3.14 wheel so trafilatura/extruct currently unavailable. Confidence: 0.80
- **MCP servers**: tools-bank, gitnexus, supabase-demo as the three canonical MCP tool providers for Goose sessions. Confidence: 0.85
- **Lazy LSP startup** — language servers spawned on first use per session, not eagerly. Triggers: `.js/.ts/.tsx/.jsx` → typescript-language-server, `.py` → pyright, `.sql` → postgrestools lsp-proxy. Confidence: 0.85
