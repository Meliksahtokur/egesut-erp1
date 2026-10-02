# GOREV — diyagram re-check (ss-lead-codex, luna/max) — tek tur, hızlı

- **GÖREV zarfı:** bu dosya · **DONE:** mevcut dosyaya EK yaz: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/diyagram-review-DONE.md` (yalnızca `## 6. Re-check` bölümü)
- Worktree: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip`

## İlk iş (sahip kuralı)
`/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` + `references/codex-tools.md` oku, uygula.

## Görev
Önceki review'unun (aynı DONE dosyası §4) 3 bulgusuna göre diyagramlar düzeltildi. Güncel dosya: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/diyagramlar.md` (v2, "katalog düzeltmeleriyle hizalı", 311 satır). Kanonik katalog: `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` T-97/T-98/T-100 (~satır 811–841).

Üç düzeltmenin bulgunu kapatıp kapatmadığını doğrula:
1. **T-97:** tam `p_tohumlama_id` fixture'ı + tüm çağrılarda aynı kimlik + "red bayrak kapısından gelir, `GIRIS_CIFT_ANLAMLI` beklenmez" sınırı.
2. **T-98:** fixture (a) izinli red kümesi {`TOH_SONUCLU`, `BOS_DUZELTME_KOSUL`}; fixture (b) deterministik `treatment_date`/`created_at` kurulumu.
3. **T-100:** `pg_get_functiondef` H3 kaynak kanıtı adımı; 40P01/55P03 "destekleyici" etiketi.

## DONE formatı (## 6. Re-check bölümü)
Bulgu başına KAPANDI/AÇIK + tek satır kanıt (`dosya:satır`) + **Yeni HÜKÜM: KABUL / DÜZELTME**.

## Yazma manifesti
- YALNIZCA `runs/2026-09-28-ovsync-takip/diyagram-review-DONE.md`'ye `## 6` bölümü. Başka her şey okuma-only. Commit yok.
- Pane'de tek satır: `RECHECK: <hüküm>`.
