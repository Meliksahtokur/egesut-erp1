# PLAN — SQL Migration Validation Kapısı implementasyonu

SPEC: `2026-09-24-db-validation-kapisi-spec.md` · Dal: `db-validation-kurulum`
Yürütme: fan-out, maks 6 eşzamanlı ajan · TEK-YAZICI-PER-DOSYA

## Adımlar

| # | İş | Sahip dosyalar (yalnız bunlar) | Bağımlılık |
|---|---|---|---|
| 1 | Araç kurulumu: `pipx install sqlfluff`, squawk (GitHub release binary → ~/.local/bin), pgTAP (Pacman ya da PGXN; `CREATE EXTENSION pgtap` izole DB'de) | sistem (repo dışı) | — |
| 2 | `scripts/db-build-baseline.sh` — egesut_lsp'den `pg_dump --schema-only` + rol ön-kurulumu (`agent_readonly`, `authenticated`, `anon` NOLOGIN karşılıkları) + Faz-0 ortam parite raporu (prod PG sürümü/extension/roller Mgmt API salt-okunur; fark → raporda, tam-uyum PASS engellenir) | `scripts/db-build-baseline.sh` | 1 |
| 3 | `scripts/db-validate.sh <migration.sql>` — Faz A/B/C1/C2/D sırası; SCHEMA/DATA mod ayrımı (migration'da DML/UNIQUE/FK/NOT NULL tespiti); restore hatası = FAIL; Faz B migration-içi nesneleri hesaba katar; rapor: baseline tarihi+şema sürümü+SHA-256, kriter bazlı PASS/FAIL/INCONCLUSIVE | `scripts/db-validate.sh`, `scripts/lib/` (yardımcı) | 2 |
| 4 | Skill + harness bağlama: `.claude/skills/db-validation/SKILL.md` (trigger'lar, akış, rapor şablonu); `code-change-precheck` SKILL.md SQL iş akışına adım; `.harness/contract.md` invariant satırı; `.harness/acceptance.md` kanıt listesine ekleme | `SKILL.md`, `.harness/contract.md`, `.harness/acceptance.md`, `.claude/skills/code-change-precheck/SKILL.md` | 3 (metin, paralel yazılabilir) |
| 5 | Pilot: (a) pozitif — baseline'da uygulanmamış sentetik geçerli migration; (b) negatif-1 hatalı syntax; (c) negatif-2 geçerli syntax + şema çakışması (mevcut tabloyu yeniden yarat). Üç koşumun çıktıları rapora | `tests/db-validation/pilot/` | 3 |
| 6 | Ajan bilinci: tools-bank memory `critical_rules` satırı + MEMORY.md pointer | memory (repo dışı) | 4 |
| 7 | Teslim: detect_changes + commit | repo | 5,6 |

## Red-before kanıtları (pilot)

- negatif-1: Faz A ya da C1'de FAIL beklenir; kapı sıfır-dışı çıkış kodu vermeli.
- negatif-2: C1'de `already exists` FAIL beklenir.
- pozitif: PASS raporunda SHA-256 + baseline sürümü görünmeli.

## Kabul

1. `db-validate.sh` üç pilot senaryoda beklenen sonucu üretir (kanıt: çıktılar).
2. Restore hatası sessizce geçilmiyor (negatif test yok — bilinçli; fail-closed kod yolu).
3. Skill + precheck + contract bağlantıları repoda var, trigger'ları migration yazımını yakalıyor.
4. Rapor sözleşmesi (SPEC §4) tam: tarih + şema sürümü + SHA-256.
5. Prod'a tek yazma yok (tüm akış yerel; Mgmt API yalnız GET benzeri sorgular).
