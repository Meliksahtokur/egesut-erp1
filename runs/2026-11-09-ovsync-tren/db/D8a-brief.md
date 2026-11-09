# D8a — ovsync_pg_kabul.sql kurulum/fixture onarımı (regresyon tabanı)
job_id: j-20261109T084526Z-03751f

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8a-report.md

## İş
Root Ruling (SORU-1 (b), progress.md): `supabase/tests/ovsync_pg_kabul.sql` bugünkü prod şemasında (bayrak `ovsync_pg_kurallari_aktif`=1 canlı,
20261031200007 PG kapısı) koşabilir hale getirilir. YALNIZ kurulum/fixture onarımı:
- bölüm başı bayrak 0/1 kurulumu (bölüm 1 bayrak 0 → betik `UPDATE protokol_ayar` ile kendisi kurar; bölüm 2+ bayrak 1),
- gebe olmayan / PG_KAPI'ye takılmayan fixture (ör. `kb_ovsync_vaka` fixture'ı `PG_KAPI:BLOCK_PREGNANT` ile düşüyor — D0-report),
- 20261031200007 sonrası uyum (kurulum düzeyinde).
Mevcut assert'lerin BEKLENEN değerleri DEĞİŞMEZ. Bir assert'in anlamı değişmek zorundaysa DEĞİŞTİRME; report'ta `## Anlam değişikliği gereken assert'ler`
listesi (dosya:satır, mevcut beklenti, neden, önerilen) ver — karar root'un; o assert'i geçici olarak atlamak YASAK, liste ile dur (sonuc: KISMI).
Ortak kurallar: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md. D0 bulgusu: D0-report.md "Önemli bulgu".
Sonra taban: onarılmış betik SERİSİZ (prod gövdeleri) koşulur → `OZET: n PASS` ve bölüm bazında PASS sayısı (özellikle bayrak 0 bölümü — bölüm başına sayaç ya da NOTICE ile ayrıştırılabilir olmalı) `govde-taban.md`'ye DEĞİL, `d8a-taban.md`'ye yazılır.
Kabul DB'si: build.sh KOŞMA (D1'de bugün kuruldu; D1 T2 review'u aynı DB'de paralel koşuyor, DROP DATABASE onu kırar). Koşumlar BEGIN/ROLLBACK.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim kodu yok (test dosyası); değişen satır hedefi ≤ 150 (yalnız kurulum/fixture). Aşım gerekçeli.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_pg_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/d8a-taban.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8a-report.md

## Kabul
- Serisiz koşum son satırı `OZET: n PASS` (FAIL yok) — ya da anlam değişikliği listesiyle KISMI.
- `git diff` yalnız kurulum/fixture satırları; hiçbir `kb_ok(...)` beklenen ifadesi değişmemiş (report'ta `git diff -U0 | grep kb_ok` çıktısı boş olmalı ya da yalnız fixture argümanı).
- d8a-taban.md: toplam PASS + bayrak 0 bölümü PASS sayısı + ham son satırlar.
- Commit dosya dosya: `ovsync-tren L-DB D8a: ovsync_pg_kabul kurulum/fixture onarımı`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && git diff aeb2a78 -U0 -- supabase/tests/ovsync_pg_kabul.sql | grep -c "^[-+].*kb_ok"

## Bağımlı
D0, D1 (TAMAM 4a32f60)

## Review: T2 (D8 ile tek tur)

## Önceden cevaplanmış kararlar
- Root Ruling SORU-1 (b) (progress.md). Goal dosyasına yazma.
- Fixture kimlikleri benzersiz `KB-` kalır; CURRENT_DATE kullanımı bu dosyada mevcutsa dokunma (kapsam dışı).
