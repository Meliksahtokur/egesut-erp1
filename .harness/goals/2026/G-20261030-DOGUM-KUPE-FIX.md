# G-20261030-DOGUM-KUPE-FIX

- status: DONE (root kabul 2026-10-31)
- owner: sahip; root kabul eder
- flow: root → builtin ss-worker-high (opus high); Muse YOK (sahip 2026-10-30: "muse agent kullanma sadece antropic")
- base SHA: 5d3f6a3 · launch SHA: 5d3f6a3
- branch: some-fixes
- worktree: .

## Amaç
Teşhis: `runs/2026-10-30-some-fixes/t1-report.md`
1. A: `dogum_kaydet` `COUNT(*)+1` id çakışması (tüm doğumlar düşüyor).
2. B: prod `uq_hayvanlar_kupe_no` tam unique index'i K1 recycle'ı kırıyor (domain-rules §1).
3. Hata metni jenerik "Bir hata oluştu" ile ezilmesin.
4. K1 ilk kez prod'da işleyecek: aynı küpe iki satırda olunca ölü hayvana düşen okuma yolları (K7) kapatılır.

## Write manifest
- supabase/migrations/2026103000000*_*.sql
- supabase/migrations/99999999999999_ground_truth.sql (yalnız index satırı; apply sonrası regen ayrı balance)
- js/api.js, js/ui.js, js/forms.js, js/app.js (yalnız K7/hata metni satırları)
- index.html (yalnız ?v= damgası), tests/ (ilgili birim/SQL testleri)
- reports/db-validation-*.md (git add -f)
- runs/2026-10-30-some-fixes/*

## Dokümantasyon otoritesi
`.harness/references/domain-rules.md` §1 değişmez (kural zaten K1). `rpc-reference.md` gerekirse.

## Acceptance
- scripts/db-validate.sh PASS (reports/db-validation-<sha8>.md)
- SQL: ölü küpeyle doğum geçer; aktif küpeyle red; DELETE sonrası doğum geçer; red-before kanıtı
- birim: `rpc()` yolundan geçen hata metni; ilgili süit yeşil

## Stop conditions
Domain-rules çelişkisi, FK/ON CONFLICT'in eski index'e bağlı çıkması, prod'a yazma ihtiyacı → dur, root'a.

## DB gate
Prod apply bu goal'de değil; ayrı sahip kapısı. Worker prod'a YAZMAZ.

## Report
`runs/2026-10-30-some-fixes/t3-report.md`

## Checkpoint
- 2026-10-30: goal açıldı, teşhis t1 TAMAM.
- 2026-10-31: sahip onayıyla prod'a 20261030000001 + 20261030100001 + veri onarımı uygulandı (t5, yedek ~/yedek/prod-yedek-2026-10-31-dogum-kupe/). Bekleyen sahip kapıları: 20261031000001 prod apply, demo INACTIVE/UI kapısı, merge+push. Bakiye: GT regen, veri-eslesme sizinti.
- 2026-10-31: 20261031000001 prod apply + GT senkron (t8, a5dc5e5; yedek ~/yedek/prod-yedek-2026-10-31-olu-yavru/). UI kapisi 10/11, T8 sahip karariyla dogru davranis (domain-rules §10). Bakiye: GT audit 83 eski fark ayri kalem.
- 2026-10-31: kapsam sahip karariyla genisledi: 20261031000001 (dogum_kaydet guard + kupe_musait_mi), GT senkron, domain-rules §1 ve §10 notu. Kapi: prod gorev id'li kuru test + onarim SQL'i public repodan cikti, kopya ~/yedek/prod-yedek-2026-10-31-dogum-kupe/; dal tek commit'e indi (eski uc refs/yedek/some-fixes-pre-squash-20261031, raporlardaki ara SHA'lar orada).
