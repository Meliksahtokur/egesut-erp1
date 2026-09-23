# supabase/tests/

`ovsync_pg_kabul.sql` — Ovsync/PG/Tohumlama kabul betiği. Sözleşme: `docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md`
(R3, R3.1). Migration uygulamaz, BEGIN/COMMIT/ROLLBACK taşımaz; her test bir `DO $t$…$t$` bloğu — PASS →
`RAISE NOTICE`, FAIL → `RAISE EXCEPTION` (ilk FAIL koşumu durdurur). Sonda `OZET: N PASS` basılır.

Koşum (yerel `egesut_ovsync_kabul` DB; sarmalayıcı ROLLBACK atar, kalıcı yazma yok):

```
( echo 'BEGIN;'; cat supabase/migrations/2026092300000{1,2,3,4,5,6}_*.sql supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) \
  | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -v ON_ERROR_STOP=1
```
