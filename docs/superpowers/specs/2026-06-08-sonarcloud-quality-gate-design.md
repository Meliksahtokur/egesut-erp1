# SonarCloud Quality Gate — Design Spec

**Tarih:** 2026-06-08  
**Kapsam:** OV4 — Quality Gate ERROR → PASS  
**Bağlam:** 2026-06-07 kod review analizi (55/100 skor), `fix/big-analysis-2026-06-08` branch bekliyor

---

## Mevcut Durum

Quality Gate: **ERROR** (3 koşul fail)

| Koşul | Mevcut | Eşik | Kök Neden |
|-------|--------|------|-----------|
| `new_reliability_rating` | C (3) | A (1) | ui.js:2800/2818 localeCompare + forms.js:920 arg mismatch — `fix/big-analysis` branch'inde düzeltildi, merge bekliyor |
| `new_duplicated_lines_density` | 48.6% | 3% | 147 SQL migration dosyası analiz ediliyor — yapısal duplikasyon, "yeni kod" sayılıyor |
| `new_security_hotspots_reviewed` | 0% | 100% | 12 hotspot Sonar UI'da hiç review edilmemiş |

**Araştırma bulgusu:** SonarCloud 175 dosya / 33K LOC görüyor. Projede 11 JS + 1 HTML + 147 SQL migration = ~175 dosya. `sonar.exclusions=supabase/**` CI config'inde var ama migration dosyaları analiz edilmeye devam ediyor.

**Kök neden:** `SonarSource/sonarcloud-github-action` tüm repoyu tarar; `-Dsonar.exclusions` argümanı SQL dil analizi için apply edilmiyor veya path pattern eşleşmiyor.

---

## Karar: Ara Migration'ları Analiz Dışına Al

**Gerekçe:**
- Ara migration dosyaları deploy edilmiş, immutable — değiştirilemez
- SQL duplikasyonu migration DDL pattern'ının doğasında var (tablo tanımları, policy'ler tekrar)
- `ground_truth.sql` aktif stored procedure içeriyor → analizde kalabilir (opsiyonel)
- `3%` duplikasyon eşiği ara migration'lar dahilken yapısal olarak geçilemez

**Çözüm:** `sonar-project.properties` + CI workflow'da çalışan bir exclusion pattern ekle:
- Ara migration'lar dışlanır: `supabase/migrations/[0-9]*.sql`  
- ground_truth analizde kalır: `supabase/migrations/99999999999999_ground_truth.sql`

CI workflow `args` bloğuna da aynı pattern eklenmeli — GitHub Action `sonar-project.properties`'i override edebilir.

---

## Hotspot Kararları

| Hotspot | Karar | Gerekçe |
|---------|-------|---------|
| `Math.random()` — app.js:8, ui.js:2747-2748 | **Safe** | UI label üretimi için — kriptografik güvenlik gerekmez |
| GitHub Actions tag → full SHA (6 adet) | **Acknowledged** | Resmi Supabase/SonarSource action'ları, risk kabul edilebilir |
| GitHub Actions secrets in run block (2 adet) | **Acknowledged** | Deploy workflow zorunluluğu |
| index.html SRI eksikliği (Tailwind/FontAwesome CDN) | **Safe** | PWA scope'da CDN SRI opsiyonel |

12 hotspot'un tamamı `sonar_change_issue_status` MCP ile programatik olarak review edilebilir.

---

## Ground Truth SQL Fix (Opsiyonel)

`ground_truth.sql` içinde 3 lokasyonda `= NULL` yerine `IS NULL` kullanılmalı (aktif prod bug, eğer ground_truth analizde kalırsa görünür olur):

- `ground_truth.sql:3135`
- `ground_truth.sql:8230`  
- `ground_truth.sql:8233`

Bu fix Sonar skor üzerinde minimal etkisi var ancak PostgreSQL'de semantik olarak doğru — `= NULL` hiçbir zaman true dönmez.

---

## Değişecek Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `sonar-project.properties` | `sonar.exclusions`'a `supabase/migrations/[0-9]*.sql` ekle |
| `.github/workflows/sonarcloud.yml` | `-Dsonar.exclusions` argümanına aynı pattern ekle |
| Sonar UI (MCP) | 12 hotspot `sonar_change_issue_status` ile `SAFE`/`ACKNOWLEDGED` yapılır |
| git | `fix/big-analysis-2026-06-08` → `main` merge |
| `ground_truth.sql` (opsiyonel) | 3 satır `= NULL` → `IS NULL` |

---

## Beklenen Sonuç

| Koşul | Sonra |
|-------|-------|
| `new_reliability_rating` | A — fix/big-analysis merge ile JS bugları kapanır |
| `new_duplicated_lines_density` | ~5-10% — sadece JS + HTML + ground_truth |
| `new_security_hotspots_reviewed` | 100% — 12 hotspot review edildi |
| **Quality Gate** | **PASS** |

---

## Kapsam Dışı

- Ara migration SQL bugları — dosyalar analiz dışına çıkınca sorun kalkar
- `code_smells` ve genel duplikasyon sayısının düşürülmesi — LV1/LV2 (ui.js/forms.js bölme) ile ilgili
- Test coverage — LV3 ile ilgili
- Quality Gate eşiklerini değiştirme — gerekirse son adım olarak değerlendirilebilir
