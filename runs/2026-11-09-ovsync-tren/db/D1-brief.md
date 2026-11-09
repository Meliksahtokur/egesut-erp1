# D1 — Faz 0: doğum sonrası PG → hatırlatma (`20261110100001_dogum_pg_hatirlatma.sql`)
job_id: j-20261109T084229Z-f6978a

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D1-report.md

## İş
PLAN.md "### D1" bölümünü birebir uygula; ayrıca N1 başındaki "Kabul betiği sözleşmesi" + "Senaryo izolasyonu (zorunlu, D1'de kurulur)"
maddelerinin TAMAMI bu görevde kurulur (kabul betiğinin ilk sürümü: yardımcılar `kb_bugun/kb_ok/kb_hayvan/kb_yerel`, `kb_gecti_seq` temp sequence sayaç,
SAVEPOINT kb_s / DO / ROLLBACK TO SAVEPOINT kb_s üçlüsü, sonda `OZET: <n> PASS`). Kalıp: `supabase/tests/ovsync_pg_kabul.sql` yardımcıları
(kopyala-uyarla; `CURRENT_DATE` yerine `kb_bugun()` = TR bugünü). Kapı tur 2 eki: PLAN.md:196'daki "bölüm başında bayrak/çapa UPDATE" kurulumu
senaryo İÇİNDE yapılır (savepoint ile sıfırlanır).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı).
D0 tabanı: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/govde-taban.md` (dogum_kaydet md5 + varsa DRIFT gövdesi).
`supabase/tests/README.md`'ye `ovsync_tren_kabul.sql` bölümü ekle (koşum komutu, seri dosyaları, sözleşme özeti — mevcut metni silme).
Testler: TR-F0-1, TR-F0-2, TR-F0-3, TR-F0-4, TR-IZOL-1, TR-F0-ACL (PLAN.md tanımları). TR-F0-1 açıklama metinleri gövdedeki gerçek
`aciklama` değerleridir (`kanit/fn/dogum_kaydet.sql:97-99`: '2. Gün PG', '39. Gün PG (Presynch-14 senkron)', '25. Gün PG').
Akış: testleri yaz → koş → `FAIL TR-F0-1` (ham çıktıyı report'a) → uygula → koş → `OZET n PASS` → db-validate → commit.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~120 satır (migration dosyası; dogum_kaydet gövde kopyası dahil). Test/README hariç.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/README.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D1-report.md

## Kabul
- Kabul koşumu son satırı `NOTICE:  OZET: <n> PASS`, n ≥ 6 ve testlerin her biri en az bir kb_ok.
- db-validate exit 0 (PASS).
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- `dogum_kaydet` md5 koruması dosya başında; PG kodu silinmemiş, bayrak arkasında (yorum "arşiv — sahip 2026-11-09").
- Commit (3 dosya, dosya dosya): mesaj `ovsync-tren L-DB D1: doğum sonrası PG → hatırlatma (Faz 0)`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D0

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-1..RL-5.
- Hatırlatma `aktif` alanı = bayrak 0 iken true (plan); bayrak 1 iken `satirlar` boş.
- "Son doğum" = annenin en son `dogum.tarih`'i (ikiz olayında aynı tarih tek satır sayılır — hayvan başına tek satır).
- Yalnız Aktif dişi (`hayvanlar` aktif durum kolonu — mevcut gövdelerdeki kalıp neyse o).
