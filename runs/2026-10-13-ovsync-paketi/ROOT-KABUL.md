# ROOT-KABUL — ovsync-paketi (karar 10: hastalık = Ovsync içinde gün) — 2026-10-14

Kapsam: PG +48 s TAI global (§18.6, sahip karar 11) · inaktif/kist hastalık günü Ovsync vakası içinde (`treatment_days.disease_id`, tek RPC `ovsync_hastalik_gunu_ekle`, `_vaka_ovsync_mu`) · kısır zinciri closed_at · tek "+ Hastalık" modalı (mockup2 N1-N4) · S4 rozeti · görev↔uyarı senkronu · iki fazlı tazeleme. Kayıtlar (iş deposu dalı yarım-jobs): /home/melik/.herdr/worktrees/egesut-erp1/yar-m-jobs/runs/2026-10-13-ovsync-paketi/

| Bulgu / kapı | Sonuç | Commit | Ölçüm |
|---|---|---|---|
| PLAN-K10 | KABUL 4.00 (kapı 3) | — | PLAN-K10-KAPI-3.md |
| DB yarısı IMPL-K10-A + F1 | KABUL (KAPI-2) | 5afc836..76ee73e | izole 4 SQL PASS, mutantlar RED, unit taban |
| UI yarısı IMPL-K10-B | DÜZELT → F1 KABUL | 5719380..b88dc07 | +İlaç yalnız Ovsync, closed_at, ERT3 kilitleri |
| UI kapısı 1 | KISMI (e2e 17/20, blok 4-9 sn) | — | ui-kapi-k10/UI-KAPI-K10-report.md |
| F2 | DÜZELT (bütçe şişirme) | a0671b6..4aee13a | KAPI-3 |
| F3 | KABUL (KAPI-4) | 1fb2a9f..48d36bf | e2e 2×20/20, blok 0.8 sn, unit 1595/4 taban |
| UI kapısı R2 | 12/12 PASS | — | ui-kapi-k10/UI-KAPI-K10-R2-report.md |
| Timeout teşhisi | sınıf C (demo) kabul + prod izleme | — | TESHIS-TIMEOUT-report.md |
| Sahip demo | "hepsi pass" | 48d36bf | 2026-10-14 |
| Prod DB | 000002..000005 CANLI, sm 165, SIZINTI/YETIM 0 | — | prod-apply/PROD-APPLY-K10-report.md; yedek GitHub run 38537673037 |

Ruling: unit 4 pre-existing fail (LUNA-3, EG-7, EG-8, bc-tarih/"ay ‹/›") istisna; db-validate C1.ortam-paritesi INCONCLUSIVE ortam kaynaklı kabul.
Ertelenen: F-3 kizginlik_vaka_ac kısır deliği (pre-existing) · gorev_log kısmi index · KALİTE küçükleri (KAPI-2/KAPI-4).
