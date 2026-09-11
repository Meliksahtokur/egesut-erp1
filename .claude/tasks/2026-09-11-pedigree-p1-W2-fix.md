# W2 düzeltme görevi — review tur-1 bulguları F1, F2, F3, F4, F5, F6 (script tarafı)

Kaynak: bağımsız review tur-1 (codex luna max), rapor
`.claude/reviews/2026-09-11-pedigree-p1-lead-review.md` (lead dalında merge'li;
tek kaynak orası). Tek tur: bulguları düzelt, mekanik kapıyla kanıtla.
İkinci review açılmayacak — doğrulama mekanik kapıdır.

## Bulgular (birebir alıntı)

> ### F1 — [unmeasured-claim] VERIFIED — `authenticated` retains direct DML on `semen_catalog`
>
> - Severity: **major**
> - Evidence: `supabase/migrations/20260911000002_pedigree_foundation.sql:132-141`;
>   `tests/sql/pedigree_graph_test.sql:297-310`.
> - Mechanism: the migration revokes `anon` on `semen_catalog` but does not
>   revoke the measured default-ACL `authenticated=arwd`; `GRANT SELECT` does
>   not remove the inherited INSERT/UPDATE/DELETE privileges. RLS is
>   `USING(true)`/`WITH CHECK(true)` at migration lines 126-127.
> - Impact: an authenticated client can write or delete catalog rows directly,
>   bypassing `semen_catalog_upsert`, its operator guard, stock-category check,
>   bull-sex check, historical-reference check, and advisory lock.
> - Demo evidence: `has_table_privilege` returned `auth_select=t, auth_insert=t,
>   auth_update=t, auth_delete=t, anon_select=f`; a `SET LOCAL ROLE
>   authenticated` direct INSERT into `semen_catalog` returned a UUID and was
>   then rolled back.

> ### F2 — [scope-violation] VERIFIED — SECURITY DEFINER helper functions are callable by anon
>
> - Severity: **major**
> - Evidence: `supabase/migrations/20260911000002_pedigree_foundation.sql:168-213`;
>   the only helper-specific revokes are for `assert_is_operator()` at
>   `:161-162` and `_pedigree_parent_set_core(...)` at `:313-315`.
> - Mechanism: `pedigree_ensure_farm_node(text)` and `pedigree_is_ancestor(uuid,uuid)`
>   are `SECURITY DEFINER` functions with no `REVOKE ... FROM PUBLIC`; their
>   default PUBLIC EXECUTE remains. `pedigree_ensure_farm_node` performs graph
>   DML under the definer, while `pedigree_is_ancestor` reads graph ancestry
>   without an operator guard.
> - Impact: the anon role can create a farm node for an existing animal and
>   query ancestry outside the authenticated, operator-guarded RPC surface.
> - Demo evidence: live privilege query returned `anon_exec=t` for both helpers;
>   `SET LOCAL ROLE anon; SELECT pedigree_ensure_farm_node(...)` succeeded.

> ### F3 — [silent-success] VERIFIED — NULL `p_replace` silently overwrites an existing parent
>
> - Severity: **major**
> - Evidence: `supabase/migrations/20260911000002_pedigree_foundation.sql:285-291`.
> - Mechanism: when a child/role already has a different parent, the guard is
>   `IF NOT p_replace THEN ...`. In PL/pgSQL, `NOT NULL` is NULL and does not
>   enter the branch, so an explicitly supplied `p_replace=NULL` reaches the
>   UPDATE and replaces the parent.
> - Impact: a caller sending JSON/RPC `p_replace: null` can change authoritative
>   parentage without the required explicit replacement flag.

> ### F4 — [fake-arm] VERIFIED — the "birth path" test calls INTERNAL core directly, not `dogum_kaydet`
>
> - Severity: **major**
> - Evidence: `tests/sql/pedigree_graph_test.sql:47-63` directly invokes
>   `_pedigree_parent_set_core(...)`; no production caller in either reviewed
>   migration invokes `_pedigree_parent_set_core`.
> - Impact: G1's "birth-path bypasses guard via INTERNAL core" claim is green on
>   a preconstructed fake arm while the live `dogum_kaydet` production
>   definition has no `_pedigree_parent_set_core` reference.

> ### F5 — [silent-success] VERIFIED — the tracked dry-run can accept a stale or partially loaded mirror
>
> - Severity: **major**
> - Evidence: `scripts/refresh_lsp_schema.sh:147-180,183-198,210-225`;
>   `scripts/db-dry-run.sh:78-82`.
> - Mechanism: the local reset is `psql ... ON_ERROR_STOP=0 ... || true`; each
>   load also uses `ON_ERROR_STOP=0` and increments `LOAD_ERRORS` only when psql
>   exits nonzero. psql file execution with `ON_ERROR_STOP=0` returns zero even
>   after a SQL error, and the final count mismatch only emits a warning;
>   `refresh_lsp_schema.sh` still exits zero. `db-dry-run.sh` treats that zero
>   as "Ayna tazelendi" and continues with the stale/partial mirror when
>   refresh fails.

> ### F6 — (script tarafı; migration tarafı W1'de düzeltiliyor)
>
> `scripts/db-dry-run.sh:92-101` — sarmalayıcı BEGIN...ROLLBACK açıyor ama
> içinde kendi COMMIT'i olan bir migration sarmalayıcı transaction'ını kapatır;
> kalan ROLLBACK transaction dışında koşar, DDL/backfill geri alınamaz.

## Düzeltme talimatları

1. **F1:** `semen_catalog` için `REVOKE INSERT, UPDATE, DELETE ON
   public.semen_catalog FROM authenticated` (SELECT kalır — D3 IDB sync).
   Aynı watchdog'lu fixture ekle: `has_table_privilege` ile dört tabloda
   (nodes/parentage/catalog/meta) authenticated'ın DML'i `f`, `semen_catalog`
   SELECT `t`; `SET LOCAL ROLE authenticated` doğrudan INSERT → reddi.
2. **F2:** `pedigree_ensure_farm_node`, `pedigree_is_ancestor` ve trigger
   sarmalayıcısı için `REVOKE EXECUTE ... FROM PUBLIC`. Trigger yolu KIRILMAMALI
   (Postgres trigger çağrısında EXECUTE ayrıca denetlemez; yine de KANITLA):
   fixture'ta authenticated `INSERT INTO hayvanlar` → node yaratıldı; anon
   doğrudan `SELECT pedigree_ensure_farm_node(...)` → reddi.
3. **F3:** guard'ı üç-değerli mantığa dayanıklı yap: `p_replace IS DISTINCT
   FROM TRUE` → reddet (NULL = açık onay DEĞİL, fail-closed). Fixture: aynı
   role+farklı parent + `p_replace=>NULL` → hata; `p_replace=>true` → başarı.
4. **F4 (lead kararı, scope):** `dogum_kaydet`→core ÜRETİM bağlantısı P1'de
   YOK — planda "doğum parentage write" Faz 7'dir (Task 0.4; ET owner kapısı
   önkoşul). Üretim koduna bağlantı EKLEME. Test bloğunu dürüstleştir: adını/
   yorumunu "INTERNAL core guard'sız çağrılabilir (mekanizma kanıtı — üretim
   bağlantısı Faz 7)" yap; `dogum_kaydet` akışı iddiası taşımasın.
5. **F5:** `refresh_lsp_schema.sh`'te `ON_ERROR_STOP=1` (veya eşdeğeri gerçek
   hata sayımı; `-v ON_ERROR_STOP=0` + exit-code yok sayımı olmaz); yükleme
   hatasında SIFIRDIŞI nonzero. `db-dry-run.sh` refresh başarısızsa devam
   ETMEsin (fail-closed). Betiği ÇALIŞTIRMA (PROD Mgmt API okur) — yalnız kod
   düzelt + `bash -n` sentaks kanıtı.
6. **F6 (script tarafı):** `db-dry-run.sh` içi BEGIN/COMMIT içeren migration
   dosyasını reddetsin (statik grep guard'ı, fail-closed, açık hata mesajı).
   W1 kendi migration'ından iç transaction'ları çıkarıyor; guard gelecekteki
   dosyalar için kalır.

## Kabul — kanıtlı

1. `pedigree_graph_test.sql` yeniden yeşil + YENİ fixture blokları (F1/F2/F3
   iddiaları) yeşil; çıktı teslim notunda.
2. `bash -n scripts/db-dry-run.sh scripts/refresh_lsp_schema.sh` exit 0.
3. `npm run test:unit` — 737/736/1 (known-red gecmis-pipeline:283; yeni
   kırmızı yok).
4. Değişen dosyalar YALNIZ: migration 000002, pedigree_graph_test.sql,
   scripts/db-dry-run.sh, scripts/refresh_lsp_schema.sh (js/ yok).
5. Kendi dalına (idle/pedigree-p1-w2) commit + kırıntı.

## Ortam (önceki zarfındaki bootstrap aynen; demo vtzqjmazsvurxdeondmi;
PROD erişimin yok; refresh_lsp_schema.sh'i ÇALIŞTIRMA)
