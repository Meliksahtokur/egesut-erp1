# SPEC — SQL Migration Validation Kapısı (db-validation)

Tarih: 2026-09-24 · Sahip onayı: bu oturum (ultracode) · Dal: `db-validation-kurulum`
Durum: ONAYLANDI (revizyonlarla — §5 sahip kararları)

## 1. Problem

`main`'e giren SQL migration'lar için otomatik doğrulama katmanı YOK
[CONFIRMED `.github/workflows/test-migration-ready.yml:3-6` — tek sabit dosyanın ls/cat'ı;
`sonarcloud.yml:29` — `**/*.sql` excluede]. Syntax doğru olsa bile mevcut şemayla/veriyle
çakışan migration'lar yalnız prod'da patlar. Mevcut yerel kapılar (code-change-precheck,
db-blast-radius.sh, db-dry-run.sh) korunur; bu kapı onların ÜSTÜNE eklenir, onları değiştirmez.

## 2. Hedef

Her yeni migration, izole yerel PostgreSQL'de gerçekten uygulanıp doğrulanmadan
prod apply sürecine (mevcut sahip kapısı) giremez. Kapı deterministik, yerel ve
CI-bağımsızdır (CI 2. faz, sahibin açık kararıyla; script Actions'dan çağrılabilir
biçimde yazılır — makineye özgü mutlak yol içermez).

## 3. Mimari

```
scripts/db-validate.sh <migration.sql>
│
├─ FAZ 0  Ortam paritesi     prod PG sürümü/extension/rol/search_path/RLS ↔ yerel; davranışı
│         etkileyen fark varsa tam-uyum PASS verilmez (INCONCLUSIVE/FAIL)
├─ FAZ A  Statik             SQLFluff (postgres dialect) + Squawk (varsayılan kurallar;
│         risk               istisna = gerekçeli + kayıtlı, sqlfluff ignore değil)
├─ FAZ B  Şema uyumluluğu    migration İÇİNDE yaratılan nesneler önce hesaba katılır;
│         (yardımcı)         çözülemeyen referans execute'a bırakılır — statik katman
│         kesin hüküm VERMEZ (fail-closed ama haksız FAIL de yok)
├─ FAZ C1 SCHEMA MODE        egesut_lsp aynasından izole DB (roller ön-kurulu;
│         (zorunlu)          restore hatası = FAIL, sessiz devam YOK) → migration'ı
│         gerçek uygula → pgTAP: RLS/policy/trigger/constraint post-checks
├─ FAZ C2 DATA MODE          veri dokuran migration'da zorunlu (UNIQUE/FK/NOT NULL/
│         (koşullu)          dönüşüm): sentetik test verisi + mevcut-kayıt senaryoları
└─ FAZ D  Rapor              reports/db-validation-<sha8>.md; PASS/FAIL/INCONCLUSIVE;
          test edilmeyen kriter PASS SAYILMAZ; kanıt: komut+çıktı
```

## 4. Rapor sözleşmesi (kabul kriteri)

Rapor mutlaka içerir:
1. Kullanılan baseline'ın **tarihi** ve **şema sürümü** (ayna refresh zamanı + nesne sayıları),
2. Test edilen SQL dosyasının **SHA-256**'sı (ajan-arası dosya değişimi tespiti için),
3. Faz bazlı sonuç + her kriter için PASS/FAIL/INCONCLUSIVE,
4. Negatif-kanıt: restore hataları, apply hataları, lint bulguları,
5. Data-mode koşulmadıysa "veri uyumluluğu DOĞRULANMADI" açık cümlesi.

## 5. Sahip kararları (2026-09-24)

| Konu | Karar |
|---|---|
| CI entegrasyonu | Şimdilik yok; yerel deterministik kapı. Script CI-çağrılabilir yazılır |
| Squawk | Varsayılan kurallar + gerekçeli kayıtlı istisna mekanizması |
| Dal | `db-validation-kurulum` |
| Baseline | Güncel `egesut_lsp` aynası (Mgmt API yolu). **GT dosyasından baseline KURULMAZ** [LOCAL-MEASUREED 2026-09-24: GT boş DB'ye 620 hata] |
| Prod erişimi | Salt-okunur (Mgmt API read-only sorgular) |
| Prod apply | Mevcut sahip kapısı değişmez |
| Test modları | SCHEMA zorunlu, DATA koşullu-zorunlu; ayrı raporlanır |
| Faz B | Kesin hüküm yok; kesin karar gerçek execute'ta |
| Pilot | Güncel baseline'da henüz uygulanmamış migration + 2 negatif test (hatalı syntax; geçerli-syntax ama şema çakışması) |
| Rapor durumları | PASS / FAIL / INCONCLUSIVE |
| Ajan sınırı | Maks 6 eşzamanlı |

## 6. Ajan bilinci (atıl durmama şartı)

- `code-change-precheck` SKILL.md SQL iş akışına adım olarak girer → her migration yazan
  ajan kapıyı refleks olarak çağırır.
- `.claude/skills/db-validation/SKILL.md` trigger'ları: "migration yaz", "migration
  doğrula", "SQL hazırla", supabase/migrations/ altında yazma.
- `.harness/contract.md` invariant satırı: DB dokunan değişiklikte db-validation kanıtı zorunlu.
- tools-bank memory'ye (`critical_rules`) bir satır işlenir.

## 7. Kapsam dışı

- Prod'a herhangi bir yazma; deploy.yml canlandırma; migration replay; ground_truth.sql düzeltme;
- CI workflow dosyası (2. faz).
