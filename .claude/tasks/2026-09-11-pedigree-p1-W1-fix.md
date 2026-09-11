# W1 düzeltme görevi — review tur-1 bulgusu F6 (migration tarafı)

Kaynak: bağımsız review tur-1 (codex luna max), rapor
`.claude/reviews/2026-09-11-pedigree-p1-lead-review.md` (lead dalında merge'li;
tek kaynak orası). Tek tur: bu bulguyu düzelt, mekanik kapıyla kanıtla.

## Bulgu F6 — VERIFIED [silent-success] (birebir alıntı)

> ### F6 — [silent-success] VERIFIED — `db-dry-run.sh` cannot roll back W1's self-committing migration
>
> - Severity: **major**
> - Evidence: `scripts/db-dry-run.sh:92-101`;
>   `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:17,245`.
> - Mechanism: the wrapper starts a transaction and appends `ROLLBACK`, but W1
>   contains its own `BEGIN`/`COMMIT`. The migration's COMMIT closes the wrapper
>   transaction; the trailing ROLLBACK then runs outside a transaction and
>   cannot undo the DDL/backfill.
> - Impact: running the documented generic dry-run command for W1 mutates the
>   Neon mirror despite the script's "ROLLBACK / canlıya DOKUNMAZ" contract,
>   contaminating later dry-run results. The equivalent psql transaction probe
>   left a temporary relation present after the outer rollback and emitted
>   "there is no transaction in progress".

## Senin düzeltmen (migration tarafı — script tarafı W2'de)

`supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql` içinden
**açık `BEGIN`/`COMMIT` cümlelerini çıkar** (dosya başı/sonu). Gerekçe:
migration dosyaları kendi transaction'larını açmamalı — uygulayan araç
(psql/supabase db push/dry-run sarmalayıcı) tek transaction yönetir; iç
COMMIT dış sarmalayıcının ROLLBACK contract'ını kırar. Migration'ın
replay-safe DO bloğu zaten atomik; davranış değişmez.

Dikkat: migration demo DB'de HALİHAZIRDA uygulanmış durumda — bu bir dosya
düzeltmesi; demo DB'de geri alma/yeniden uygulama GEREKMEZ (replay-safe
olduğu için yeniden koşsan da no-op). `dogum_kaydet` gövdesine DOKUNMA.

## Kabul — kanıtlı

1. Migration dosyasında `grep -n '^BEGIN\|^COMMIT'` → boş çıktı (kanıt).
2. `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/dogum_buzagi_id_test.sql`
   yeniden yeşil (davranış değişmedi kanıtı).
3. `npm run test:unit` — 737/736/1 (known-red hariç yeni kırmızı yok).
4. Kendi dalına (idle/pedigree-p1-w1) commit + kırıntı.

## Ortam (önceki zarfındaki bootstrap aynen: .env/node_modules symlink +
DATABASE_URL türetme; demo vtzqjmazsvurxdeondmi; PROD erişimin yok)
