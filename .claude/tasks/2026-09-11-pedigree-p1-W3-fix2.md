# W3 düzeltme-2 — root-gate F1 (empty grup) + F5 (tek satır: integrity_report)

Kaynak: root-gate tur-1 (FAIL, revizyon turu 1/1). Rapor:
`git show idle/pedigree-p1-rootgate:.claude/reviews/2026-09-11-pedigree-p1-rootgate.md`
Goal Rev 1 (7d908c5) lead dalında merge'li — G2 artık **fixture-DELTA** ölçütü:
"absent group not emitted — geçerli cutoff + sıfır ihlalde dahi grup YOK".
Tek tur — mekanik kapıyla kanıtla.

## F1 — [doc-drift] (birebir)

> ### F1 — [doc-drift] VERIFIED — valid cutoff with no violations emits an empty group
> - Location: `supabase/migrations/20260911000003_pedigree_farm_backfill.sql:442-456`;
>   the no-empty assertion in `tests/sql/pedigree_farm_backfill_test.sql:110-115`
>   does not cover this valid-cutoff path.
> - Evidence: the demo transaction added a temporary `tohumlama.semen_id`, set
>   cutoff to `2999-01-01T00:00:00Z`, inserted no violating row, and rolled back:
>   `cutoff=2999-01-01..., violation_rows=0, has_post_cutoff_group=t, post_cutoff_items=null`
> - Mechanism: `jsonb_build_object(...)` is non-NULL even when `jsonb_agg(...)`
>   returns NULL, so the `IF v_dyn_group IS NOT NULL` check appends
>   `post_cutoff_null_semen` with `items: null`. This violates the plan's
>   absent-group rule and can make consumers that call
>   `jsonb_array_elements(g->'items')` fail. The test's
>   `jsonb_array_length(g->'items') = 0` predicate also does not match NULL.
> - Recommendation: build/append the dynamic group only when at least one row
>   exists (count or non-NULL aggregate guard), and add a valid-cutoff/no-violation
>   assertion.

**Talimat:** aggregate guard — grubu yalnız ≥1 ihlal satırında oluştur/ekle
(`jsonb_agg` NULL'una karşı sayım guard'ı); teste yeni blok: geçerli cutoff +
sıfır ihlal → `post_cutoff_null_semen` grubu YOK (ne items:null ne boş dizi).

## F5 — SENİN KISMIN (tek satır; birebir alıntı W2 zarfında)

> Location: `supabase/migrations/20260911000003_pedigree_farm_backfill.sql:475-477`;
> evidence: `service_report=t` (yalnız PUBLIC, anon revoke edilmiş).

**Talimat:** migration 000003'te `REVOKE EXECUTE ON FUNCTION
public.pedigree_integrity_report() FROM service_role`; teste assertion:
`has_function_privilege('service_role','public.pedigree_integrity_report()')=f`,
authenticated `=t`.

## Kabul — kanıtlı

1. `psql $DATABASE_URL -f tests/sql/pedigree_farm_backfill_test.sql` yeşil +
   iki yeni assertion bloğu (geçerli-cutoff-sıfır-ihlal grup yok; service_role).
2. `npm run test:unit` — 737/736/1 (yeni kırmızı yok).
3. Değişen dosyalar YALNIZ migration 000003 + pedigree_farm_backfill_test.sql.
4. Kendi dalına (idle/pedigree-p1-w3) commit + kırıntı.

Ortam: önceki zarf bootstrap aynen (demo vtzqjmazsvurxdeondmi; PROD yok).
