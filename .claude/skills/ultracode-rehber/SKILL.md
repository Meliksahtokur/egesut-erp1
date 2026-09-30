---
name: ultracode-rehber
description: egesut-erp1 reposunda hangi isi hangi ss-workflow ile kosacagini soyler. Kullanicinin ya da bir ust ajanin "ultracode", "paralel inceleme", "repo haritasi" demesi ya da bu repoda workflow katmani gerektiginde kullan. Paralellik/ram-pool kurallari burada DEGIL — once ultracode-master.
---

# ultracode-rehber — egesut-erp1 routing

ONCE `ultracode-master` (global sozlesme: karar agaci, ram-pool akisi
[ramPlan → lanes → ramClose], exec, resume epoch, ret/deny tablosu, skill
birlesimi). Bu rehber YALNIZ bu repoda is → workflow routing'idir;
paralellik kurali anlatisi icermez.

## Is → workflow eslesmesi

| Is | Workflow | Not |
|---|---|---|
| Degisiklik/PR incelemesi, bug avi | `ss-parallel-review` | 6 boyut paralel (silent-success, dry-run-guard, ui-monolith-regression, schema-drift, offline-queue-ordering, breeding-vaccination-logic); her bulgu skepsis ajaniyla celistirilir, ayakta kalanlar `KANIT:skepsis-verified` etiketiyle raporlanir (KANITSIZ bulgu raporlanamaz) |
| Repo tanima, yeni ajan onboarding, mimari ozet | `ss-repo-map` | 6 acidan paralel tarama + TEK sentez ajani |
| Tek dosyali ufak duzeltme, migration yazimi | workflow YOK | deneysel degil; direkt uygula, `scripts/ground-truth-audit.sh` kosut |

Repo-ozel sartlar (aksi halde yazilarin BLOKLANIR — hookify guardlari):
- Toplu onarim RPC'leri `p_dry_run` arkasinda kalmali.
- Eski migration DOSYALMAZ (append-only canli gecmis).
- `js/ui.js` 10.6k satirlik monolit — degisiklik oncesi `ss-parallel-review` kos.

Workflow scriptleri saf JS (TypeScript annotasyon YOK; `Date.now` /
`Math.random` YASAK — epoch `args.ramEpoch` ile disaridan gelir) ve fan-out
fazlarini ram-pool snippet bloguyla kosar; detay ve kurallar
ultracode-master'da.
