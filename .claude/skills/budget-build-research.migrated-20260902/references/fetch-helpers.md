# Fetch helpers

## Primary: the ladder
```bash
python3 .claude/skills/budget-build-research/scripts/fetch_ladder.py "<url>" --text --max-chars 8000
```
Returns JSON: `{url, tier, status, blocked, length, content}`.
- `tier`: which engine succeeded (curl_cffi | primp | jina)
- `blocked: true` after all tiers → treat the item as UNVERIFIED.

## Jina API key (optional, higher rate limit)
Export `JINA_API_KEY=...` before calling; the ladder passes it as a Bearer token
to r.jina.ai. Without a key, Jina still works (rate-limited).

## Setup
`bash .claude/skills/budget-build-research/scripts/bootstrap.sh` installs curl_cffi + primp
into `/root/.cache/budget-build-research/venv` (fixed path, shared by all agents;
override with `BBR_VENV`). No browser is installed.

## Why no browser
Environment is PRoot with memory pressure and no Chromium. All three tiers are
HTTP-only (curl_cffi, primp) or remote (Jina) — zero local browser overhead.