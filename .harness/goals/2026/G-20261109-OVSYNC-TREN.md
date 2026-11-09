---
id: G-20261109-OVSYNC-TREN
status: active
owner: Melik Şah Tokur
flow: Full mode, root -> ss-kulvar-lead-opus (L-DB, L-MOCK, L-UI, L-DEMO) -> ss-worker-high (opus); Muse yok (sahip 2026-11-07)
created: 2026-11-09
base_sha: 11b92eb
launch_sha: 11b92eb
branch: ovsync-tren
worktree: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
spec: docs/plans/2026-11-09-ovsync-tren/design.md
plan_report: docs/plans/2026-11-09-ovsync-tren/PLAN.md
report: runs/2026-11-09-ovsync-tren/
write_manifest:
  - .harness/goals/2026/G-20261109-OVSYNC-TREN.md
  - docs/plans/2026-11-09-ovsync-tren/design.md
  - docs/plans/2026-11-09-ovsync-tren/PLAN.md
  - .harness/references/domain-rules.md
  - .harness/references/rpc-reference.md
  - .harness/references/ui-map.md
  - supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
  - supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
  - supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
  - supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
  - supabase/migrations/20261110100005_ovsync_tren_kilit.sql
  - supabase/migrations/20261110100006_ovsync_tren_asama.sql
  - supabase/migrations/20261110100007_ovsync_tren_toptan.sql
  - supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql
  - supabase/migrations/99999999999999_ground_truth.sql
  - supabase/tests/ovsync_tren_kabul.sql
  - supabase/tests/ovsync_pg_kabul.sql   # D8a (root ruling 2026-11-09): yalnız kurulum/fixture onarımı
  - supabase/tests/README.md
  - js/ovsync-tren.js
  - js/ui.js
  - js/forms.js
  - js/api.js
  - index.html
  - tests/unit/ovsync-tren.test.js
  - tests/unit/ovsync-tren-entegrasyon.test.js
  - tests/e2e/ovsync-tren.spec.js
  - runs/2026-11-09-ovsync-tren/**
---

# Ovsync Treni

Spec (sahip onaylı 2026-11-09, "tamam kral yazalım"): `docs/plans/2026-11-09-ovsync-tren/design.md`.
Plan (kapı tur 2 KABUL 4.33): `docs/plans/2026-11-09-ovsync-tren/PLAN.md`. Yürütme onayı: sahip "onay" (2026-11-09).

## Yetkiler
- Demo DB yazma: N6 (L-DEMO) için izinli — sahip planı "onay" ile yürütmeye açtı; plan N6 demo apply içerir.
- Prod DB yazma: AYRI KAPI (N7). Sahip demo onayı + P1c anahtar listesi sahibe gösterilmeden prod'a yazılmaz.
- Commit: dal `ovsync-tren` içinde, düğüm başına; merge/push yalnız `ss-merge-gate`.

## Sıra
N0 → (N1 L-DB ∥ N2 L-MOCK) → G-MOCK (sahip) → N3 → N4 → N5 → N6 → G-UI (worker sonnet-medium PASS) → G-SAHIP → N7.
