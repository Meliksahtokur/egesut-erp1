---
id: G-20260927-COKLU-KAYDIR
status: done
owner: Melik Şah Tokur
flow: Full mode, subagent-driven development
created: 2026-09-27
base_sha: d737c1d710aa050adc8f96eadb8279bf40175513
launch_sha: d737c1d710aa050adc8f96eadb8279bf40175513
branch: toplu-işlemler-ui-pratik-degil
worktree: /home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil
plan_report: docs/plans/2026-09-27-coklu-kaydirma-PLAN.md
report: .harness/reports/2026-09-27-coklu-kaydir.md
write_manifest:
  - .harness/goals/2026/G-20260927-COKLU-KAYDIR.md
  - supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql
  - js/api.js
  - js/ui.js
  - js/forms.js
  - index.html
  - tests/unit/coklu-kaydir-ui.test.js
  - tests/unit/vaka-toplu-ac.test.js
  - .harness/references/rpc-reference.md
  - .harness/reports/2026-09-27-coklu-kaydir.md
  - docs/plans/2026-09-27-coklu-kaydirma-SPEC.md
  - docs/plans/2026-09-27-coklu-kaydirma-PLAN.md
docs_authority:
  tracked_paths:
    write: []
    append:
      - .harness/references/rpc-reference.md
  local_paths:
    write:
      - .superpowers/sdd/2026-09-27-coklu-kaydirma-PLAN/progress.md
    append: []
  db: write
  propose_only:
    - prod DB apply (20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql)
pattern_refs:
  - FORM-SUBMIT-01
  - MODAL-ROUTER-01
  - RPC-WRITE-01
  - TESTING-01
acceptance:
  - bash scripts/db-validate.sh supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql → PASS
  - npm run test:unit → all PASS (erteleme-kaydir-ui regresyonu dahil)
  - glmf-max demo browser run 8-item list (plan Task 6 Step 4) → all PASS
stop_conditions:
  - prod DB apply, merge, push, deploy ayrı sahip kapılarıdır — asla otomatik yapılmaz
checkpoint:
  sequence: 8
  kind: final
  head: 563ac05
  docs_verdict: PASS
---

# G-20260927-COKLU-KAYDIR — Multi-case treatment shift (F1)

- **id:** G-20260927-COKLU-KAYDIR
- **status:** done (root close 2026-09-27)
- **owner:** Melik Şah Tokur (approved spec+plan in session, 2026-09-27)
- **flow:** Full mode, subagent-driven development (built-in agents, this session; no pty seats)
- **base SHA:** d737c1d710aa050adc8f96eadb8279bf40175513
- **branch:** toplu-işlemler-ui-pratik-degil
- **worktree:** /home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil
- **spec:** docs/plans/2026-09-27-coklu-kaydirma-SPEC.md
- **plan:** docs/plans/2026-09-27-coklu-kaydirma-PLAN.md
- **write manifest:**
  - `supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql` (create)
  - `js/api.js`, `js/ui.js`, `js/forms.js` (modify, sequential tasks)
  - `index.html` (modify: bar container + ?v= stamp 20260927-09)
  - `tests/unit/coklu-kaydir-ui.test.js` (create/append)
  - `tests/unit/vaka-toplu-ac.test.js` (modify: stamp assertions → value-independent — plan-review Critical fix, Task 5)
  - `.harness/references/rpc-reference.md` (append RPC entry)
  - `reports/db-validation-2026-09-27-*` (db-validate output, git add -f per repo convention)
- **pattern_refs:** FORM-SUBMIT-01, MODAL-ROUTER-01, RPC-WRITE-01, TESTING-01 (.harness/patterns/index.yaml; reused from G-20260906-TOPLU-VAKA per contract pattern-reuse rule)
- **acceptance commands:**
  - `bash scripts/db-validate.sh supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql` → PASS
  - `npm run test:unit` → all PASS (incl. existing erteleme-kaydir-ui.test.js regression)
  - glmf-max demo browser run of the 8-item list (plan Task 6 Step 4) → all PASS (UI gate before owner demo)
- **stop conditions:** prod DB apply, merge, push, deploy are separate owner gates — never automatic.
- **report path:** .superpowers/sdd/2026-09-27-coklu-kaydirma-PLAN/progress.md (SDD ledger) + task reports in same dir
- **latest checkpoint:** 6 task + fix-wave + final MERGE_READY + mimar teyit + re-demo 9:9 (563ac05)
- **docs verdict:** PASS (rpc-reference + spec/plan commitli; docs-update CLI yok — manuel mutabakat) (pre-commit checkpoint at task commits)
- **not:** PROD DB apply SAHIBIN KAPISINDA bekliyor; N-1 (belirsiz-sonuc deterministik cozum) sahibin karariyla belgelenmis risk; I-6 acik.
