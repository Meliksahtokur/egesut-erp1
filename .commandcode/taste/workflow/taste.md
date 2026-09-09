# Workflow Preferences

- Uses **worktree-per-lane pattern** for parallel isolated work: `git worktree add --detach <lane-path> <base-ref>`, each lane has own venv, commits independently, lead cherry-picks verified SHAs into main, then removes worktree. Confidence: 0.90
- **Cherry-pick from lanes, never directly commit to main** from a worker. Lead reviews then cherry-picks. Confidence: 0.85
- **Verify agent results independently** — never trust self-reported success from a subagent; run pytest/ruff/mypy/git diff yourself. Confidence: 0.90
- **Prefer parallel agents** over sequential when tasks are independent ("bağlantılı değilse paralel göndersene"). Confidence: 0.85
- Status checks ~every 5 minutes during active multi-agent work. Confidence: 0.80
- **Additive-only changes** when modifying existing code: only new rules/blocks, never modify/delete existing lines unless explicitly required. Confidence: 0.85
- **git add by specific filename only** on main repo; never `git add -A` on a dirty main working tree. Verify with `git diff --cached --stat` before committing. Confidence: 0.80
- Commit + push when work is done without asking for approval (for routine work). Confidence: 0.75
- **Bulk UPDATE/DELETE/DROP**: show draft first, get explicit approval, then apply. Routine DDL (ADD COLUMN, CREATE FUNCTION, CREATE INDEX) applied directly. Confidence: 0.80
- **TDD approach** for feature implementation: write failing test → run and see it fail → minimal implementation → run and see it pass → commit. Confidence: 0.85
- **Mechanical verification** after every code change: `git diff main -- <file>` should show only additions before target anchor, no deletions/modifications. Confidence: 0.80
- For protocol/schema-uncertain work: fetch authoritative machine-readable schema rather than guessing from training data or analogous formats. Confidence: 0.85
- **Never skip pre-commit hooks (`--no-verify`)** unless the user explicitly requests it. Confidence: 0.80
- **Read-only research mode**: when user says "sadece bilgi ver" / "müdahale etme", query and report only — no modifications, no drafts, no interventions of any kind. Confidence: 0.75
