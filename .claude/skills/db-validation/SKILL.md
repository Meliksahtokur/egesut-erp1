---
name: db-validation
description: SQL migration doğrulama kapısı — yeni bir supabase/migrations/*.sql yazmadan ÖNCE taslak üzerinde VE apply öncesi final dosyada scripts/db-validate.sh çalıştırılır. "Migration yaz", "migration doğrula", "SQL migration hazırla", "şema değişikliği" denince veya supabase/migrations/ altına dosya yazacaksan MUTLAKA kullan — sahip söylemeden, refleks olarak.
---

# SQL Migration Validation Kapısı (db-validation)

Her yeni migration, izole yerel PostgreSQL'de gerçekten uygulanıp
doğrulanmadan teslim edilmez. Bu kapı mevcut ön-kontrollerin
(code-change-precheck, db-blast-radius.sh, db-dry-run.sh) ÜSTÜNE eklenir;
onların yerine geçmez.

## Ne zaman ZORUNLU (sahip söylemeden)

1. `supabase/migrations/` altına yeni bir `.sql` yazmadan ÖNCE — **taslak
   üzerinde** (hata erken yakalanır, yeniden yazım ucuz olur).
2. Migration'ı teslim etmeden ÖNCE — **final dosyada** (dosya değiştiyse
   kanıt eskimiş demektir; SHA-256 raporla eşleşmeli).

Trigger'lar: "migration yaz", "migration doğrula", "SQL migration hazırla",
"şema değişikliği", `supabase/migrations/` altına herhangi bir yazma.
`scripts/db-validate.sh <migration> ` kanıtı olmadan migration teslim edilmez.

## Nasıl çağrılır

```bash
bash scripts/db-validate.sh <migration.sql>
```

Rapor `reports/db-validation-<sha8>.md` altına düşer (sha8 = migration
dosyasının SHA-256'inin ilk 8 karakteri).

## Rapor durumları

| Durum | Anlamı |
|---|---|
| **PASS** | Tüm fazlar kanıtlı geçti (ortam paritesi tam dahil) |
| **FAIL** | Restore/apply hatası, lint bulgusu veya pgTAP post-check düştü — migration düzeltilmeden teslim edilmez |
| **INCONCLUSIVE** | Kapı karar veremedi (ortam parite farkı, çözülemeyen koşul vb.) |

## INCONCLUSIVE'da ne yapılır

Kendi başına "geçti" sayma: raporu ve nedenini **sahibe sor** ve onun
kararını bekle. Test edilmeyen kriter PASS SAYILMAZ.

## Raporda ne olmalı (kontrol et)

- Baseline **tarihi + şema sürümü** (ayna refresh zamanı, nesne sayıları),
- Migration dosyasının **SHA-256**'si (ajan-arası dosya değişimini yakalar),
- Faz bazlı (A statik / B şema / C1 SCHEMA / C2 DATA / D rapor) sonuçlar,
- Veri dokuran migration'da DATA MODE çalıştırılmadıysa "veri uyumluluğu
  DOĞRULANMADI" açık cümlesi.

## Bilinen uyarılar

- Baseline daima güncel `egesut_lsp` aynasıdır; ground_truth dosyasından
  baseline KURULMAZ (GT boş DB'de 620 hata verir, 2026-09-24 ölçümü).
- Kapı yalnızca yerel çalışır; prod apply bu kapıyı GEÇMEZ — prod apply
  sahip kapısında (DB runbook) kalır.
- Restore hatası sessizce geçilmez: FAIL'dir.
