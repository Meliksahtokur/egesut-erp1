# supabase/tests/

`ovsync_pg_kabul.sql` — Ovsync/PG/Tohumlama kabul betiği. Sözleşme: `docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md`
(R3, R3.1). Migration uygulamaz, BEGIN/COMMIT/ROLLBACK taşımaz; her test bir `DO $t$…$t$` bloğu — PASS →
`RAISE NOTICE`, FAIL → `RAISE EXCEPTION` (ilk FAIL koşumu durdurur). Sonda `OZET: N PASS` basılır.

Koşum (yerel `egesut_ovsync_kabul` DB; sarmalayıcı ROLLBACK atar, kalıcı yazma yok):

```
( echo 'BEGIN;'; cat supabase/migrations/2026092300000{1,2,3,4,5,6}_*.sql supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) \
  | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -v ON_ERROR_STOP=1
```

## `ovsync_tren_kabul.sql` — Ovsync treni kabul betiği

Plan: `docs/plans/2026-11-09-ovsync-tren/PLAN.md` (N1 — L-DB, D1…D8). Seri dosyaları sırayla:
`supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql` … `20261110100008_ovsync_tren_ayar_goc.sql`
(her D görevi kendi dosyasını ekler; koşum o göreve kadarki seriyi alır).

Koşum (yerel `egesut_ovsync_kabul`; önce `bash scripts/kabul-db/build.sh` — görev başına bir kez, prod şeması verisiz):

```
( echo 'BEGIN;'; cat supabase/migrations/2026111010000[1-8]_*.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) \
  | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```

Beklenen son satır `NOTICE:  OZET: <n> PASS`; ilk FAIL koşumu durdurur (`FAIL <id>: beklenen … gerçek …`).

Sözleşme özeti:
- Migration uygulamaz, BEGIN/COMMIT/ROLLBACK taşımaz; çağıran sarar. Betik `\set QUIET on` ile başlar (son satır OZET olsun diye).
- Yardımcılar `pg_temp.kb_*`: `kb_bugun()` (Europe/Istanbul bugünü — `CURRENT_DATE` yerine), `kb_ok(kosul, test, beklenen, gercek)`,
  `kb_hayvan(yas_gun, durum, kisir)`, `kb_yerel(gun, saat)`, `kb_id(on)`, `kb_ayar(anahtar, deger)`; D2'de `kb_tren_ac/kb_tren_kapat/kb_ovsync_vaka/kb_seans_yap` eklenir.
- Senaryo izolasyonu: her senaryo `SAVEPOINT kb_s;` → `DO $t$…$t$;` → `ROLLBACK TO SAVEPOINT kb_s;`. Fixture, `protokol_ayar`
  ve `set_config(…, true)` GUC'ları (`app.ovsync_tren_ic` dahil) geri sarılır; bayrak/çapa kurulumu senaryonun içinde yapılır (`TR-IZOL-1`).
- PASS sayacı `CREATE TEMP SEQUENCE kb_gecti_seq` (geri sarımdan etkilenmez); `kb_ok` başarıda `nextval`, sonda `OZET: <currval> PASS`.
- Sayı assert'leri senaryonun kendi `KB-` hayvan kümesine süzülür.
