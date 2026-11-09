# D5 — K10 sunucu kilidi + K9 (`20261110100005_ovsync_tren_kilit.sql`)
job_id: j-20261109T084229Z-483a58

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D5-report.md

## İş
PLAN.md "### D5" bölümünü birebir uygula (Interfaces — Produces imzaları, adları, hata kodları ve payload alanları AYNEN).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı). Önceki görev report'ları aynı klasörde (`D<k>-report.md`) — yardımcı ve fixture adları için oku.
Testler (kabul betiğine bölüm olarak ekle, mevcut bölümleri bozma): TR-K10-1..9, TR-K10-REG, TR-K10-IC, TR-K9-1, TR-K9-N1 (bu görevde `ovsync_tren IS NULL` assert'i).
Akış: testleri yaz → koş → ilk koşumda FAIL (ham çıktı report'a) → uygula → koş → `OZET n PASS` (önceki görevlerin testleri dahil hepsi) → db-validate --priors → commit.
Görev notları:
- D4 review KÜÇÜK (ek iş, dar fix): `supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:432` `CASE WHEN public._ovsync_tren_aktif() AND public._ovsync_tren_gunu_mu(v_bas) THEN v_bas END` → `CASE WHEN public._ovsync_tren_aktif() THEN CASE WHEN public._ovsync_tren_gunu_mu(v_bas) THEN v_bas END END` (bayrak 0'da ayar okunmaması değerlendirme sırasına bırakılmaz). TR-K8-REG yeniden PASS. db-validate 004'ü de yeniden koş.
- D2 bulgusu: db-validate statik denetimi `LATERAL` ve `unnest(...) k(alias)` desenlerinde INCONCLUSIVE (rc=2) veriyor — bu desenlerden kaçın.
- RL-9: build.sh KOŞMA; kabul DB'si hazır.
- RL-1 (progress.md): `vaka_kalan_gunleri_kaydir` başarılı kaydırmada aynı fonksiyonda `ovsync_tren = ovsync_tren + p_gun` (yalnız NOT NULL). TR-K10-IC'ye etiket assert'i ekle (iç bayrakla kaydırılan trende vakada etiket +k). Bayrak 0'da kolon NULL → davranış birebir.
- `_coklu` dönüşüne `ovsync_atlanan`; bu satırlar toplam/atlanan/hatalar'a girmez.
- `ovsync_hastalik_gunu_ekle` başta `_ovsync_ic_ac()`, dönüşe `tren_ayrildi`.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~600 satır (yalnız migration dosyası; kopyalanan gövdeler dahil). Test hariç. Aşım = report'ta `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D5-report.md

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS`; listelenen her TR-* id'si en az bir `kb_ok` ile koşuyor (report'ta id → PASS satırı listesi).
- db-validate exit 0.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- PLAN.md D5 "Etki" maddesindeki çağıranlar yeni imza/davranışla kırılmıyor (kanıt report'ta).
- Commit dosya dosya; mesaj `ovsync-tren L-DB D5: <özet>`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D4

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-*. Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şeyse DUR ve `SORU:` yaz.
