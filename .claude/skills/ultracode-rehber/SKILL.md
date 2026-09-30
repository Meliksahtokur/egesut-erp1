---
name: ultracode-rehber
description: egesut-erp1 reposunda hangi isi hangi ss-workflow ile kosacagini, dinamik MAX_CONC (RAM'den tureyen) paralellik kuralini ve KANIT etiketi disiplinini anlatir. Kullanicinin ya da bir ust ajanin "ultracode", "harness isleri", "paralel inceleme", "repo haritasi" demesi ya da bu repoya workflow katmani kurulmasi gerektiginde kullan.
---

# ultracode-rehber — egesut-erp1 harness kilavuzu

Bu repo (vanilla JS + Supabase Postgres, 157 baslik real isletme ERP'si) icin
harness katmani `.claude/workflows/` altindadir. Is turune gore workflow sec:

## Is → workflow eslesmesi

| Is | Workflow | Not |
|---|---|---|
| Degisiklik/PR incelemesi, bug avi | `ss-parallel-review` | 6 boyut paralel (silent-success, dry-run-guard, ui-monolith-regression, schema-drift, offline-queue-ordering, breeding-vaccination-logic); sonra her bulgu skepsis ajaniyla celistirilir |
| Repo tanima, yeni ajan onboarding, mimari ozet | `ss-repo-map` | 6 acidan paralel tarama + TEK sentez ajani |
| Tek dosyali ufak duzeltme, migration yazimi | workflow YOK | deneysel degil; direkt uygula, `scripts/ground-truth-audit.sh` kosut |

Repo-ozel sartlar (aksi halde yazilarin BLOKLANIR — hookify guardlari):
- Toplu onarim RPC'leri `p_dry_run` arkasinda kalmali.
- Eski migration DOSYALMAZ (append-only canli gecmis).
- `js/ui.js` 10.6k satirlik monolit — degisiklik oncesi `ss-parallel-review` kos.

## MAX_CONC dinamik kurali (sahip karari 2026-09-24; eski sabit 6 KALKTI)

- Her workflow ayni anda EN FAZLA MAX_CONC ajan firlatir. MAX_CONC dinamik:
  kosu basinda `free -b` ile available RAM olculur, floor((available-6GB)/1.5GB),
  TAVAN 16. Ram-probe ajani olcumden turetir (fail-closed).
- Fazlar siralidir (Find→Verify, Scan→Synthesize); yalniz faz-ici bagimsiz isler
  paralellesir. Sentez/karar katmani TEK ajandir, fan-out'a bolunmez.
- Sebep: makine bellek/pids tavani (onceki fork-bomb/OOM olaylari) — parcak
  sayisi asla sabitten buyuk somut literal olmamali.
- Scriptlerde `Date.now` / `Math.random` YASAK (deterministik plan), TypeScript
  annotasyon YASAK (saf JS, `node --check` gecmeli).

## KANIT etiketi kurali

- Bulgu iddialari KANITSIZ raporlanamaz: dosya + satir + kanit metni zorunlu
  (schema `required` ile zorlanir).
- Verify fazini gecen her bulgu `KANIT:skepsis-verified` etiketi tasiyan
  `confirmed` listesine girer; curuyenler `dropped` listesinde gerekcesiyle
  saklanir (neden dustugu kaybolmaz).
- `confirmed` bos olabilir; bos sonuc basari degil, "bulunamadi" bilgisidir —
  asla bulgu uydurma.
