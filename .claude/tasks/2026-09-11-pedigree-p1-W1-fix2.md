# W1 düzeltme-2 — root-gate F2 (KRİTİK) + F3 + EOF

Kaynak: root-gate tur-1 (FAIL, revizyon turu 1/1). Rapor:
`git show idle/pedigree-p1-rootgate:.claude/reviews/2026-09-11-pedigree-p1-rootgate.md`
Goal Rev 1 (7d908c5) lead dalında merge'li. Tek tur — mekanik kapıyla kanıtla.

## F2 — KRİTİK [dead-path] (birebir)

> ### F2 — [dead-path] VERIFIED — W1 overwrites the newer D53 postpartum behavior
> - Location: `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:140-183`;
>   newer main migration `supabase/migrations/20260906000001_postpartum_d53_e_vitamin_tek.sql:2-9,122-163`.
> - Evidence: W1 writes `53. Gün: Ademin`, `53. Gün: Yeldif`, and `54. Gün: Yeldif`
>   at lines 148-150 and returns `10+7` at line 183. Main's later behavioral fix
>   specifies one `53. Gün: E Vitamini` task and `8+7`. The live demo probe returned:
>   `has_old_d53_ademin=t, has_old_d54_yeldif=t, has_new_d53_evit=f, returns_old_10_plus_7=t`
> - Mechanism: applying the target's later `20260911...00001` migration after
>   main's `20260906...00001` migration replaces `dogum_kaydet` with the stale
>   ten-task body. A real birth therefore resurrects the removed Ademin task,
>   duplicates E_VIT at d53/d54, and reports 17 tasks instead of 15.
> - Recommendation: rebase the W1 function body on the current D53-correct body
>   and retain only the `buzagi_id` binding change; add a regression assertion
>   for the 8+7 behavior.

**Talimat:** `dogum_kaydet` gövdesini **güncel D53-düzgün gövde** üzerine
yeniden kur: taban = `supabase/migrations/20260906000001_postpartum_d53_e_vitamin_tek.sql`'in
`dogum_kaydet` tanımı (senin ağacında var); ona YALNIZ buzagi_id bağlama
değişikliğini ekle (INSERT dogum → INSERT hayvanlar → UPDATE dogum.buzagi_id).
10 görevlik eski gövdeye DÖNME. Regression: 8+7 dönüş + `53. Gün: E Vitamini`
var + Ademin/Yeldif d53/d54 YOK. Demo'ya yeniden uygula (CREATE OR REPLACE
güncel gövdeyi geri getirir) ve root'un probe'unu tekrarla: `has_new_d53_evit=t`.

## F3 — [fake-arm] (birebir)

> ### F3 — [fake-arm] VERIFIED — G0b backfill coverage executes a copy, not the migration's backfill
> - Location: `tests/sql/dogum_buzagi_id_test.sql:106-142` versus the production
>   migration block `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:198-242`.
> - Evidence: the test explicitly labels its `DO $bf$` block "migration ...
>   birebir kopyasi" and runs that block after inserting the four fixtures. The
>   migration has no callable backfill function; its actual `DO $mig$` block is
>   not invoked or replayed by the test.
> - Recommendation: extract the production backfill into one internal callable
>   function and test that function, or apply the real migration in a disposable
>   transaction/schema and assert the resulting four classes; do not maintain a
>   second algorithm in the fixture.

**Talimat:** migration'da backfill'i çağrılabilir iç fonksiyona çıkar
(`_dogum_buzagi_backfill()` — grantsız INTERNAL desen); migration DO bloğu bu
fonksiyonu çağırır; test DO $bf$ KOPYASINI SİLİP bu fonksiyonu çağırır. Tek
algoritma, tek kaynak.

## Ayrıca: migration dosyası EOF boş satırı — `git diff --check` temiz olsun.

## Kabul — kanıtlı

1. `git diff --check` temiz (EOF dahil).
2. `psql $DATABASE_URL -f tests/sql/dogum_buzagi_id_test.sql` yeşil — GERÇEK
   backfill kolu üzerinden + yeni D53 regression bloğu (8+7, E-Vit, Ademin yok).
3. Demo probe: `has_new_d53_evit=t`, `returns_old_10_plus_7=f`.
4. `npm run test:unit` — 737/736/1 (known-red hariç yeni kırmızı yok).
5. Değişen dosyalar YALNIZ migration 000001 + dogum_buzagi_id_test.sql.
6. Kendi dalına (idle/pedigree-p1-w1) commit + kırıntı.

Ortam: önceki zarf bootstrap aynen (demo vtzqjmazsvurxdeondmi; PROD yok).
