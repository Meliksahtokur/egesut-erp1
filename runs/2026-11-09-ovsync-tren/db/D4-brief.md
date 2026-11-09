# D4 — Başlatma yolları ve K8 sunucu tarafı (`20261110100004_ovsync_tren_baslatma.sql`)
job_id: j-20261109T084229Z-7724dc

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D4-report.md

## İş
PLAN.md "### D4" bölümünü birebir uygula (Interfaces — Produces imzaları, adları, hata kodları ve payload alanları AYNEN).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı). Önceki görev report'ları aynı klasörde (`D<k>-report.md`) — yardımcı ve fixture adları için oku.
Testler (kabul betiğine bölüm olarak ekle, mevcut bölümleri bozma): TR-K8-1, TR-K8-2, TR-K8-3, TR-K8-REG, TR-K8-V3, TR-K8-V4, TR-K8-KISIR, TR-TZ-2, TR-ONIZLE-1, TR-ONIZLE-2, TR-ACL-2.
Akış: testleri yaz → koş → ilk koşumda FAIL (ham çıktı report'a) → uygula → koş → `OZET n PASS` (önceki görevlerin testleri dahil hepsi) → db-validate --priors → commit.
Görev notları:
- SÖZLEŞME EKİ (root ruling 2026-11-09, sahip onaylı mockup; salt ekleme, mevcut alanlar değişmez): `ovsync_tren_onizle` dönüşüne `kupe_no` (p_hayvan_id'nin küpesi; NULL hayvan → NULL), `kural_tarihi` (`_ovsync_kural_tarihi(hayvan)`; yoksa NULL), `uye_kupeler text[]` (o trene zaten binmiş hayvanların küpeleri: `ovsync_tren`=tren_gunu aktif OVSYNC vaka + o güne hedefli açık OVSYNC_BASLAT; sıralı). Assert: `TR-EK-ONIZLE` (üç alan fixture'la birebir). Kaynak: runs/2026-11-09-ovsync-tren/ui/UA1-report.md sapma 1.
- D2 bulgusu: db-validate statik denetimi `LATERAL` ve `unnest(...) k(alias)` desenlerinde INCONCLUSIVE (rc=2) veriyor — bu desenlerden kaçın.
- RL-9: build.sh KOŞMA; kabul DB'si hazır.
- `start_first_service_protocol` DROP (uuid, boolean) + CREATE (uuid, boolean, boolean); GRANT authenticated; cron `ilk_tohumlama_zamanlayici` tek-arg çağrısı çalışmalı (test ya da kanıt).
- R4: üyelik sunucuda yalnız D0 tarihinden; `vaka_toplu_ac` ve `tedavi_sablon_uygula` imzası DEĞİŞMEZ.
- `_vaka_ac_tek` yalnız CURRENT_DATE → TR değişikliği.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~450 satır (yalnız migration dosyası; kopyalanan gövdeler dahil). Test hariç. Aşım = report'ta `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D4-report.md

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS`; listelenen her TR-* id'si en az bir `kb_ok` ile koşuyor (report'ta id → PASS satırı listesi).
- db-validate exit 0.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- PLAN.md D4 "Etki" maddesindeki çağıranlar yeni imza/davranışla kırılmıyor (kanıt report'ta).
- Commit dosya dosya; mesaj `ovsync-tren L-DB D4: <özet>`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D3

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-*. Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şeyse DUR ve `SORU:` yaz.
