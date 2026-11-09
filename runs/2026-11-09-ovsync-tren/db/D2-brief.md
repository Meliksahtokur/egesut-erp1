# D2 — Tren çekirdeği (`20261110100002_ovsync_tren_cekirdek.sql`)
job_id: j-20261109T084229Z-c52aee

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D2-report.md

## İş
PLAN.md "### D2" bölümünü birebir uygula (Interfaces — Produces imzaları, adları, hata kodları ve payload alanları AYNEN).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı). Önceki görev report'ları aynı klasörde (`D<k>-report.md`) — yardımcı ve fixture adları için oku.
Testler (kabul betiğine bölüm olarak ekle, mevcut bölümleri bozma): TR-K1-1, TR-K2-N1, TR-K1-2, TR-TZ-1, TR-REG-1, TR-AYAR-N1, TR-AYAR-N2, TR-AYAR-N4, TR-KAYMA-1, TR-ASAMA-0/1/2/N, TR-K10-GUC, TR-ACL-1; ayrıca D2 ek yardımcıları kb_tren_ac, kb_tren_kapat, kb_ovsync_vaka, kb_seans_yap (PLAN.md N1 sözleşmesi).
Akış: testleri yaz → koş → ilk koşumda FAIL (fonksiyon yok) (ham çıktı report'a) → uygula → koş → `OZET n PASS` (önceki görevlerin testleri dahil hepsi) → db-validate --priors → commit.
Görev notları:
- D1 review KÜÇÜK-1 (ek iş): TR-IZOL-1'e fixture sızıntısı ölçümü ekle — (a) senaryosunda bir `kb_hayvan()` kur, (b)'de `SELECT count(*) FROM hayvanlar WHERE id LIKE 'KB-%'` (ya da kb_hayvan'ın gerçek kimlik kalıbı) = 0 assert.
- RL-9: build.sh KOŞMA; kabul DB'si hazır (paralelde D8a aynı DB'de BEGIN/ROLLBACK koşumu yapıyor).
- `_ovsync_tren_ayar()` R1 doğrulaması: `to_date` çağrısı BEGIN…EXCEPTION WHEN others içinde; ham 22008 dışarı çıkmaz.
- `_ovsync_asama` ve `_ovsync_pg1_kayma` R6/R18 tanımları birebir; GnRH1'in 'gerçek tamamlanma günü TR' = gün#1 seanslarının en geç `uygulama_tamamlandi_at` anının TR tarihi.
- `_ovsync_gorev_mu` bayraktan bağımsız (R5 a/b/c); `aciklama::jsonb` dönüşümü bozuk JSON'da hata atmamalı (güvenli parse: jsonb dönüşümünü yalnız `aciklama ~ '^\s*\{'` iken dene ya da EXCEPTION bloğu) → false.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~220 satır (yalnız migration dosyası; kopyalanan gövdeler dahil). Test hariç. Aşım = report'ta `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D2-report.md

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS`; listelenen her TR-* id'si en az bir `kb_ok` ile koşuyor (report'ta id → PASS satırı listesi).
- db-validate exit 0.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- PLAN.md D2 "Etki" maddesindeki çağıranlar yeni imza/davranışla kırılmıyor (kanıt report'ta).
- Commit dosya dosya; mesaj `ovsync-tren L-DB D2: <özet>`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D1

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-*. Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şeyse DUR ve `SORU:` yaz.
