---
id: G-20261031-HAYVAN-TAKIP
status: active
owner: Melik Şah Tokur
flow: Full mode, root -> mimar -> ss-worker-high (opus); Muse ve sonnet yok
created: 2026-10-31
base_sha: db46032
launch_sha: db46032
branch: hayvan-takipte
worktree: null
plan_report: docs/plans/2026-10-31-hayvan-takip-PLAN.md
report: .harness/reports/2026-10-31-hayvan-takip.md
write_manifest:
  - .harness/goals/2026/G-20261031-HAYVAN-TAKIP.md
  - .harness/reports/2026-10-31-hayvan-takip.md
  - docs/plans/2026-10-31-hayvan-takip-PLAN.md
  - docs/plans/2026-10-31-hayvan-takip-SPEC.md
  - .harness/references/domain-rules.md
  - .harness/references/rpc-reference.md
  - .harness/references/ui-map.md
  - supabase/migrations/20261031200001_hayvan_takip_sema.sql
  - supabase/migrations/20261031200002_hayvan_takip_rpc.sql
  - supabase/migrations/20261031200003_gorev_tamamla_hayvan_takip.sql
  - supabase/migrations/20261031200004_hayvan_takip_halsizlik_etiket.sql
  - supabase/migrations/20261031200005_hayvan_takip_muayene_vaka.sql
  - tests/db-validation/hayvan_takip_priors.sql
  - tests/sql/hayvan_takip_kos.sh
  - tests/sql/hayvan_takip_karsi_test.sql
  - tests/sql/hayvan_takip_karsi_mutant.sql
  - tests/sql/hayvan_takip_test.sql
  - js/config.js
  - js/api.js
  - js/hayvan-takip.js
  - js/hayvan-takip-pencere.js
  - js/utils/handlers.js
  - js/utils/modal.js
  - js/utils/helpers.js
  - js/utils/events.js
  - js/app.js
  - js/gecmis.js
  - js/degisiklikler/etiketler.js
  - js/ui.js
  - js/forms.js
  - index.html
  - tests/unit/hayvan-takip.test.js
  - tests/unit/hayvan-takip-pencere.test.js
  - tests/unit/hayvan-takip-gecmis.test.js
  - tests/unit/hayvan-takip-ui.test.js
  - tests/unit/hayvan-takip-vaka.test.js
  - tests/unit/hayvan-takip-belge.test.js
  - tests/unit/saat-alani.test.js
  - tests/unit/forms-validation.test.js
  - tests/unit/vaka-toplu-ac.test.js
  - tests/unit/erteleme-genel-ui.test.js
  - tests/unit/ovsync-secici.test.js
  - tests/unit/hizli-uygulama-guard.test.js
docs_authority:
  tracked_paths:
    write:
      - docs/plans/2026-10-31-hayvan-takip-SPEC.md
    append:
      - .harness/references/domain-rules.md
      - .harness/references/rpc-reference.md
      - .harness/references/ui-map.md
  local_paths:
    write: []
    append: []
  db: write
  propose_only:
    - prod DB apply (S1, sahip kapisi)
    - R14 disi demo yazimi
    - merge ve push (S1, sahip kapisi)
pattern_refs:
  - RPC-WRITE-01
  - MODAL-ROUTER-01
  - FORM-SUBMIT-01
  - TESTING-01
pattern_exceptions:
  - OFFLINE-SYNC-01 uygulanmaz; spec kapsam disi cevrimdisi kuyruk, yeni RPC'ler online-only
acceptance:
  - scripts/db-validate.sh her migration icin PASS (--priors tests/db-validation/hayvan_takip_priors.sql + onceki dosyalar)
  - tests/sql/hayvan_takip_kos.sh ile hayvan_takip_test.sql rc=0
  - tests/sql/hayvan_takip_kos.sh ile hayvan_takip_karsi_test.sql rc=0, migration'siz (T1 Run) KOS_MOD=topla mutant DUSEN tam olarak KR01-KR07 ve KR09
  - node --test tests/unit/*.test.js yalniz M0'da olculen taban kirmizilari (db46032: 1598/1592/5/1)
  - U1 26/26 PASS ve anlam olcumu
stop_conditions:
  - push, merge, prod YASAK; S1 sahip kapisi
  - db-validate INCONCLUSIVE sonucunda sahibe sor
  - domain-rules ya da spec davranisiyla celiskide SORU ile dur
  - U1 PASS olmadan sahibe demo verilmez
  - Manifest disina cikilmaz; Muse ve sonnet acilmaz
checkpoint:
  sequence: 1
  kind: pre-commit
  head: db46032
  docs_verdict: PARTIAL
---

# G-20261031-HAYVAN-TAKIP — Hayvan Takip (📌 Takipte) implementasyonu

- **id:** G-20261031-HAYVAN-TAKIP
- **status:** active (plan kapısı bekliyor)
- **owner:** Melik Şah Tokur (spec onayı 2026-10-31; push, merge, prod yalnız sahip kapısı)
- **flow:** Full mode. Root → mimar → lead/worker alt ajanları (`ss-worker-high`, `model=opus`). Muse ve sonnet yok (sahip 2026-10-31). Ultracode yok.
- **base SHA:** `db46032`
- **launch SHA:** plan commit'i (bu goal'ü ekleyen commit, `git log -1 -- .harness/goals/2026/G-20261031-HAYVAN-TAKIP.md`)
- **branch:** `hayvan-takipte`
- **worktree:** herdr worktree `egesut-erp1/hayvan-takipte`. Frontmatter'da `null`: repo public, mutlak yol yazılmaz; konum otoritesi `git worktree list`.
- **spec:** `docs/plans/2026-10-31-hayvan-takip-SPEC.md`
- **plan:** `docs/plans/2026-10-31-hayvan-takip-PLAN.md` (görevler M0, T0-T6, F1-F5, D1, K1, U1, S1)
- **spec sapması (sahip onaylı, 2026-10-31):** R10: Ö3b prod apply sonrasına kalır, spec §7 "faz kapanmadan" kuralının istisnası. Sahip kararları R6, R7 `domain-rules.md` §20.7-8'de (`5abe587`).
- **scope:** Spec §4-§6'nın tamamı; kapsam dışı spec §1. Prod apply, merge, push bu goal'ün kabul kapsamında değildir; S1 sahip kapısıdır.
- **write manifest (dosya başına tek düğüm, plan DAG'ı):**
  - M0: merge commit (main'den gelen dosyalar manifest ihlali sayılmaz)
  - T0: `tests/db-validation/hayvan_takip_priors.sql`
  - T1: `tests/sql/hayvan_takip_kos.sh`, `tests/sql/hayvan_takip_karsi_test.sql`, `tests/sql/hayvan_takip_karsi_mutant.sql`
  - T2: `tests/sql/hayvan_takip_test.sql`
  - T3: `supabase/migrations/20261031200001_hayvan_takip_sema.sql`
  - T4: `supabase/migrations/20261031200002_hayvan_takip_rpc.sql`
  - T5: `supabase/migrations/20261031200003_gorev_tamamla_hayvan_takip.sql`
  - T6: `docs/plans/2026-10-31-hayvan-takip-SPEC.md`, `.harness/references/domain-rules.md`
  - F1: `js/config.js`, `js/api.js`, `js/hayvan-takip.js`, `tests/unit/hayvan-takip.test.js`
  - F2: `js/hayvan-takip-pencere.js`, `index.html`, `js/utils/handlers.js`, `tests/unit/hayvan-takip-pencere.test.js`
  - F3: `js/gecmis.js`, `js/degisiklikler/etiketler.js`, `tests/unit/hayvan-takip-gecmis.test.js`
  - F4: `js/ui.js`, `tests/unit/hayvan-takip-ui.test.js`
  - F5: `js/forms.js`, `tests/unit/hayvan-takip-vaka.test.js`
  - D1: `.harness/references/rpc-reference.md`, `.harness/references/ui-map.md`
  - U2-G0: `supabase/migrations/20261031200004_hayvan_takip_halsizlik_etiket.sql` (diğer dosyalar yukarıdaki düğümlerde)
  - U2-M1: `supabase/migrations/20261031200005_hayvan_takip_muayene_vaka.sql`, `js/utils/modal.js` (diğer dosyalar yukarıdaki düğümlerde)
  - U2-S1: `js/utils/helpers.js`, `js/utils/events.js`, `tests/unit/saat-alani.test.js`, `tests/unit/forms-validation.test.js`, `tests/unit/vaka-toplu-ac.test.js`, `tests/unit/erteleme-genel-ui.test.js`, `tests/unit/ovsync-secici.test.js`, `tests/unit/hizli-uygulama-guard.test.js` (diğer dosyalar yukarıdaki düğümlerde)
  - U2-K: `tests/unit/hayvan-takip-belge.test.js` (diğer dosyalar yukarıdaki düğümlerde)
  - Plan ve kapanış: `docs/plans/2026-10-31-hayvan-takip-PLAN.md`, bu goal dosyası, `.harness/reports/2026-10-31-hayvan-takip.md`
  - Yerel: `runs/2026-10-31-hayvan-takip/*`, `.crumbs/*`
- **tracked paths:** yukarıdaki manifestin `runs/` ve `.crumbs/` dışındaki dosyaları. `docs/plans/` gitignore'dadır, `git add -f` ile eklenir.
- **local paths:** `runs/2026-10-31-hayvan-takip/*`, `.crumbs/*`, `reports/db-validation-*`
- **docs authority:** T6 spec ve domain-rules; D1 rpc-reference ve ui-map; root bu goal'ün checkpoint'leri. Workers kanonik belleğe yazmaz.
- **DB authority:** Canlı şema okuması (prod ve demo, yalnız SELECT) T0'da serbest (spec Ö2). **Demo yazma yetkisi (sahip açık talimatı, 2026-10-31):** kapsam yalnız T6: demo'ya migration apply + yalnız ROLLBACK'li `demo_klonla`, `db-validate` PASS sonrası. Commit edilen `demo_klonla`, başka TRUNCATE, prod işlemi ve kapsam dışı demo yazımı bu yetkiye girmez. **Yetki genişlemesi (sahip, 2026-10-31):** T6 Ö1 ve U1 için yalnız `E2E-HT-O1` ve `E2E-HT-UI-` önekli COMMIT'li fixture yazımı, yalnız demoda. Prod yazma YOK; S1 sahip kapısı. Demo sahip şifresi okunmaz, yazılmaz, değiştirilmez. Canlı şema tek otoritedir.
- **pattern_refs:** `RPC-WRITE-01`, `MODAL-ROUTER-01`, `FORM-SUBMIT-01`, `TESTING-01`
- **pattern_exceptions:** `OFFLINE-SYNC-01` uygulanmaz: spec §1 ve §6 çevrimdışı kuyruğu kapsam dışı tutar, yeni RPC'ler online-only kalır.
- **acceptance commands:**
  - Her migration: `scripts/db-validate.sh` (taslak ve final) `--priors tests/db-validation/hayvan_takip_priors.sql` + serinin önceki dosyaları; `PASS`, rapor `reports/db-validation-<sha8>.md`.
  - `bash tests/sql/hayvan_takip_kos.sh` rc=0 (argümansız: seri migration'lar + `hayvan_takip_test.sql`).
  - `bash tests/sql/hayvan_takip_kos.sh <3 migration> tests/sql/hayvan_takip_karsi_test.sql` rc=0, `OZET: 11 PASS`; migration'sız (T1 Run) `KOS_MOD=topla` mutant `DUSEN` tam olarak `KR01-KR07`, `KR09`.
  - `node --test tests/unit/*.test.js` (`NODE_PATH` ana checkout): yalnız M0'da ölçülen taban kırmızıları (db46032: 1598/1592/5/1).
  - Değişen JS'te `node --check`; `git diff --check`.
  - U1 26/26 PASS + anlam ölçümü.
- **stop conditions:** Push, merge, prod YASAK. `db-validate` INCONCLUSIVE'da sahibe sor. Domain-rules ya da spec davranışıyla çelişkide `SORU:`. Sahibe U1 PASS olmadan demo verilmez. Dosya manifest dışına çıkılmaz. Muse ve sonnet açılmaz. Paylaşılan DB (`egesut_ovsync_kabul`, `egesut_val_tmp`) başka oturumda meşgulse lead'e sor.
- **report path:** `runs/2026-10-31-hayvan-takip/<görev-id>-report.md`; final `.harness/reports/2026-10-31-hayvan-takip.md` (root)
- **latest checkpoint:** 2026-10-31 — spec `db46032`; plan ve goal yazıldı, kapı tur 1 bulguları düzeltildi, plan kapısı tur 2 (`ss-reviewer-kapi`) bekliyor. Kod, migration, DB mutasyonu yok.
- **docs verdict:** bekliyor.
