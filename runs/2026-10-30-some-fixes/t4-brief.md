# t4 — Görev/protokol etken_kod fix + veri onarım SQL'i
job_id: j-20261030T182831Z-b9f9ad
## Plan maddesi
Goal: .harness/goals/2026/G-20261030-PROTOKOL-ETKEN.md
Teşhis (oku, tekrar ölçme): runs/2026-10-30-some-fixes/t2-report.md
Önce: .harness/references/domain-rules.md §12, §15; skill code-change-precheck, db-validation, test-driven-development-obra.

1. Şema/fn migration (`supabase/migrations/20261030100001_*.sql`): canlıdan çekilen gövdeler taban.
   - F1: `gebelik_protokol_kontrol` 3 INSERT'e `etken_kod` (ROTA, ADEMIN, E_VIT).
   - F2: `hizli_uygulama`, `p_occurred_at` doluysa `uygulama_log.tarih`e o tarihi yazar; boşsa bugünkü varsayılan. Tarayıcı penceresi DEĞİŞMEZ.
2. Veri onarım SQL'i ayrı dosya, migrations DIŞINDA: `runs/2026-10-30-some-fixes/t4-veri-onarim.sql` (idempotent, BEGIN…COMMIT; prod'da KOŞMA, önce/sonra sayım SELECT'leri dahil). Sahip kararları (2026-10-30):
   - 9 görevde `etken_kod` backfill (907, 906, 207 × ROTA/ADEMIN/E_VIT; id'ler raporda ve `~/tmp/t2/`, canlıdan doğrula).
   - 906 Rota `20bd2c65`: GEÇERLİ SAY → doğrudan UPDATE ile kapat, `kapatan_ref='vaccination_log:c03e8db3'`. `gorev_tamamla` KULLANMA (sahte uygulama_log + stok düşümü). Tamamlanma tarihi aşı tarihi; trigger yan etkisini gövdeden kontrol et.
   - 191 Ademin `51a66c91` ve E Vit `4647be58`: YENİDEN AÇ (tamamlandi=false, tamamlanma_tarihi/kapatan_ref temizle). Bu görevleri `_gorev_dinle`nin neden kapattığını raporla; yeniden kapanma riski varsa söyle (F4 kapsam dışı).
   - 169 d39 PG: sahip ✕ ile kapatacak. SQL'e girmez; yalnız ✕ yan etkisini (t2 ek bulgu 1-2) rapora yaz: 169'un açık PG görevi var mı, hangileri iptal olur, canlı SELECT.
3. Testler: davranış ölçer (metin değil). db-validate ortamında ya da yerel PG'de: etken'li görev done → `protokol_eksik_tara` satırı düşer; `hizli_uygulama` → eşleşen görev kapanır; `p_occurred_at` tarihe yazılır. Red-before kanıtı. Veri onarım SQL'ini de kuru koşu ile (yerel, gerçek olmayan veriyle) sına.

## Model
opus (high)
## Yazılabilir dosyalar
supabase/migrations/20261030100001_*.sql (tek dosya)
runs/2026-10-30-some-fixes/t4-veri-onarim.sql
runs/2026-10-30-some-fixes/t4-report.md
tests/ altında yalnız yeni test dosyaları
reports/db-validation-*.md (git add -f)
## Boyut bütçesi
migration ≈ iki gövde + 5 satır; onarım ≤60 satır; test ≤120 satır.
## Run
scripts/db-validate.sh <migration yolu>
(davranış testi komutunu kendin belirle, rapora ekle)
## Bağımlı
t2
## Review: T2
## Önceden cevaplanmış kararlar
- Yukarıdaki 3 sahip kararı kesin, yeniden sorma. F3/F4 kapsam dışı (rapora not). Ground truth'a DOKUNMA (t3 yazıcısı; apply sonrası regen).
- Prod'a yazma, push, merge yok. Commit serbest (git add dosya dosya). Muse yok.
- t3 paralel koşuyor: migration damgası 20261030000001 onun, js/ ve ground truth onun; dokunma.
- Göreli yol hatası tekrarı yok: geçici dosyalar yalnız $HOME/tmp mutlak yolda, ana checkout'a yazma.
