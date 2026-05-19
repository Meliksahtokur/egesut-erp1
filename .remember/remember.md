# Handoff

## State
I fixed 3 UI bugs (dashboard showing cancelled tasks, padok cache not refreshing after task completion, missing "Hayvana Git" button) in commit 14fa365. Fixed kuru dönem false-positive crisis (30 tasks cancelled, grup reverted) via migrations 000001-000003. Propagated SQL approval gate + canonical reference rules to all agent layers (AGENTS.md, egesut-erp-architecture/SKILL.md, recipes, ~/.goose-persistent.md). Fixed gorev_log.id type docs (TEXT not uuid) in commit 21cb5ac. tools-bank memory entries #95-#99 written. Handoff doc at `/root/tools-bank/blackboard/handoff-20260518.md`.

## Next
1. **UI test** kuru dönem flow — kupe 002/185/149/122 ineklerini elle test et: padok seç → görevi tamamla → hayvan kartı güncelliyor mu?
2. **ground_truth.sql güncelle** — migrations 000001/000002/000003 henüz `99999999999999_ground_truth.sql`'e dahil edilmedi
3. **Approval gate canlı test** — Goose'a SQL task ver, gerçekten `approval_req` atıyor mu gözlemle

## Context
- `gorev_log.id` = TEXT (uuid string saklar) — WHERE cast gerekmez, INSERT: `gen_random_uuid()::text`
- ASLA `*_revize.sql` / `*_fix.sql` referans alma — sadece `99999999999999_ground_truth.sql`
- 4 gerçek kuru dönem ineği DB'de: kupe 002, 185, 149, 122
