# D3 — Görev doğumu, anahtar, G7/G9 (`20261110100003_ovsync_tren_gorev_dogumu.sql`)
job_id: j-20261109T084229Z-226a84

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D3-report.md

## İş
PLAN.md "### D3" bölümünü birebir uygula (Interfaces — Produces imzaları, adları, hata kodları ve payload alanları AYNEN).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı). Önceki görev report'ları aynı klasörde (`D<k>-report.md`) — yardımcı ve fixture adları için oku.
Testler (kabul betiğine bölüm olarak ekle, mevcut bölümleri bozma): TR-DOGUM-1, TR-DOGUM-N1, TR-REG-DOGUM, TR-ANAH-1, TR-ANAH-N1, TR-ANAH-GOC, TR-G9-1, TR-G9-REG, TR-UYARI-1, TR-UYARI-REG, TR-K5-KISIR.
Akış: testleri yaz → koş → ilk koşumda FAIL (ham çıktı report'a) → uygula → koş → `OZET n PASS` (önceki görevlerin testleri dahil hepsi) → db-validate --priors → commit.
Görev notları:
- D2 review KÜÇÜK (ek iş): `supabase/tests/ovsync_tren_kabul.sql` TR-K1-2'deki `random()` kullanımını deterministik bir kümeyle değiştir (ör. generate_series ile sabit 10 kural).
- D2 bulgusu: db-validate statik denetimi `LATERAL` ve `unnest(...) k(alias)` desenlerinde INCONCLUSIVE (rc=2) veriyor — bu desenlerden kaçın.
- RL-9: build.sh KOŞMA; kabul DB'si hazır.
- 6 fonksiyon md5 koruması (D0 tablosu).
- İmza değişikliği: DROP eski imza + CREATE yeni (default'lu ek parametre) aynı dosyada; tüm çağıranlar (PLAN.md D3 Etki listesi) yeni imzayla derleniyor mu — plpgsql çağrıları çalışma anında çözülür, bu yüzden her çağıran yol en az bir testte koşmalı ya da report'ta `pg_proc` taramasıyla 1-arg/4-arg çağrıların default ile çözüldüğü gösterilmeli.
- R10 G7 fail-closed: `_acik_disi_gorev_kur` NULL → açık OVSYNC_BASLAT varsa onun id'si, yoksa `OVSYNC_GOREV_ACILAMADI:{hayvan_id,sebep}`.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~520 satır (yalnız migration dosyası; kopyalanan gövdeler dahil). Test hariç. Aşım = report'ta `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D3-report.md

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS`; listelenen her TR-* id'si en az bir `kb_ok` ile koşuyor (report'ta id → PASS satırı listesi).
- db-validate exit 0.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- PLAN.md D3 "Etki" maddesindeki çağıranlar yeni imza/davranışla kırılmıyor (kanıt report'ta).
- Commit dosya dosya; mesaj `ovsync-tren L-DB D3: <özet>`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D2

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-*. Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şeyse DUR ve `SORU:` yaz.
