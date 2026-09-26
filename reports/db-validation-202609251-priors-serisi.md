# db-validate --priors Seri Koşusu (G2 yeniden-üretilebilirlik) — 2026-09-25

- Oturum: tek arka plan koşusu (erteleme-genel/f4-gate); hedef başına C1+C2 baseline + priors
- Motor: VAL_DB_URL (postgres:17) · baseline: egesut_lsp aynası (prod, taze)

| Hedef | Priors | Sonuç | Rapor |
| `20260925100001_vaka_kalan_gunleri_kaydir.sql` | 0 | PASS | reports/db-validation-519c2e30.md |
| `20260925100002_add_treatment_day_ust_gorev_tarihi.sql` | 1 | PASS | reports/db-validation-7d66b886.md |
| `20260925100003_gorev_ertele_kural_tablo_seed.sql` | 2 | PASS | reports/db-validation-f03f1a95.md |
| `20260925100004_gorev_ertele_rpcs.sql` | 3 | PASS | reports/db-validation-b9adca56.md |
| `20260925100005_bagimsiz_pg_vaka_kapat.sql` | 4 | PASS | reports/db-validation-a5505160.md |
| `20260925100006_protokol_iptal.sql` | 5 | PASS | reports/db-validation-fee68007.md |
| `20260925100007_erteleme_f4_onarim.sql` | 6 | PASS | reports/db-validation-4df69cd3.md |

**SERİ SONUCU: TÜMÜ PASS (7/7)** — 202609251 serisi ayna-üzerinden priors zinciriyle uçtan uca yeniden-üretilebilir.
