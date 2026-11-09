# D6 — Aşama RPC'leri + K11 (`20261110100006_ovsync_tren_asama.sql`)
job_id: j-20261109T084230Z-782a9a

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D6-report.md

## İş
PLAN.md "### D6" bölümünü birebir uygula (Interfaces — Produces imzaları, adları, hata kodları ve payload alanları AYNEN).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı). Önceki görev report'ları aynı klasörde (`D<k>-report.md`) — yardımcı ve fixture adları için oku.
Testler (kabul betiğine bölüm olarak ekle, mevcut bölümleri bozma): TR-K4-1, TR-K4-2, TR-K5-1, TR-K5-N1, TR-K5-N2, TR-K5-2, TR-K6-N1, TR-K6-A1, TR-K6-A-N1, TR-K6-A-N2, TR-K6-B1, TR-K6-B2, TR-ASAMA-N, TR-K11-1, TR-K11-2, TR-K11-3, TR-K11-REG, TR-KAPALI, TR-ACL-3.
Akış: testleri yaz → koş → ilk koşumda FAIL (ham çıktı report'a) → uygula → koş → `OZET n PASS` (önceki görevlerin testleri dahil hepsi) → db-validate --priors → commit.
Görev notları:
- D5 bulgusu: kabul DB'sinde `gorev_ertele_kural` boş; `gorev_ertele`'ye dayanan testler önce `pg_temp.kb_ertele_kural()` çağırır (D5 yardımcısı).
- D4-EK (root ruling, progress.md RL-11): start_first_service_protocol gecikmiş/ritim dışı görevi ilk trene yeniden hedefler; başlatılan vakada (bayrak açık, bağımsız değil) üyelik NULL → OVSYNC_TREN_UYELIK_YOK.
- R6-EK (root SORU-3, progress.md): aşama/kayma tanımı D2-EK ile güncellendi (geriye tarihli seanssız gün = yapıldı, çapa treatment_date; uygulanmadi = yapılmadı). Fixture'larda buna güven.
- SÖZLEŞME EKİ (root ruling 2026-11-09; salt ekleme): R13 `ovsync_uyari` nesnesine `kupe_no`, `planlanan_tarih` (PG1 gününün planlı tarihi), `tamamlanan_tarih` (TR), `bastan_tren_gunu` (baştan başlatılırsa bineceği tren: `_ovsync_tren_gunu(bugün)` bayrak açıkken) eklenir. Assert: `TR-EK-UYARI` (TR-K11-1 fixture'ında dört alan). Kaynak: UA1-report sapma 5.
- D2 bulgusu: db-validate statik denetimi `LATERAL` ve `unnest(...) k(alias)` desenlerinde INCONCLUSIVE (rc=2) veriyor — bu desenlerden kaçın.
- D2 bulgusu: `add_treatment_day_with_sessions` geçmiş tarihli günü `tamamlandi=true` + seans açık kurar → R6'ya göre aşama NULL. Aşama fixture'larını `kb_seans_yap` ile kur; geçmiş D0'lı vakanın NULL (belirsiz) çıkması spec §7 ile uyumlu beklenen davranıştır.
- RL-9: build.sh KOŞMA; kabul DB'si hazır.
- RL-1: etiket (`ovsync_tren`) artışı D5'te `vaka_kalan_gunleri_kaydir` içinde; `ovsync_hayvan_ertele` ayrıca ARTIRMAZ (çift sayım yasak). TR-K4-2/TR-K5-1 etiket assert'leri bunu ölçer. Aşama 0 trende vakada 'sonraki trene' fark kadar `vaka_kalan_gunleri_kaydir(case, fark)` → etiket aynı fonksiyonda += fark.
- Yeni RPC'ler `_ovsync_ic_ac()` + `pg_advisory_xact_lock(hashtext('ovsync_tren'))` ile başlar; bayrak kapalı → `OVSYNC_TREN_KAPALI`.
- `seans_tamamla` R13; md5 koruması.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~450 satır (yalnız migration dosyası; kopyalanan gövdeler dahil). Test hariç. Aşım = report'ta `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D6-report.md

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS`; listelenen her TR-* id'si en az bir `kb_ok` ile koşuyor (report'ta id → PASS satırı listesi).
- db-validate exit 0.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- PLAN.md D6 "Etki" maddesindeki çağıranlar yeni imza/davranışla kırılmıyor (kanıt report'ta).
- Commit dosya dosya; mesaj `ovsync-tren L-DB D6: <özet>`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D5

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-*. Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şeyse DUR ve `SORU:` yaz.

## Devam
Önceki report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D6-report.md (commit 00420d2, 362 PASS). Önceki worker bağlamı doldu (SARI, 317k) → taze worker, aynı brief.
T2 tur 1 DÜZELT: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D6-review-report.md:15-18. YALNIZ şu dar fix'ler (aynı migration 006 + kabul betiği):
1. (ÖNEMLİ) Lead Ruling RL-12: `ovsync_bastan_baslat` basladi=false dalında da hayvanın açık `PG_TOHUMLAMA:*` TAI'si kapatılır — mevcut başlatma dalında start_first_service_protocol'ün kapattığı yöntemle birebir aynı yol/işaret (iptal) kullanılır (sonda S2 kanıtı: `tam=t ipt=t`). Gerekçe: K6 (a)/(b) dışlaması; sonuç "tren bugün mü"ye bağlı olmamalı.
2. (ÖNEMLİ) TR-K6-B1'e aşama 2 alt senaryosu: seans 1+2 yapılmış, PG TAI açık; hem basladi=false hem basladi=true dalında `pg_temp.kb_pg_tai(v_h) IS NULL` assert'i. Önce test → FAIL (basladi=false) → fix → PASS.
3. (KÜÇÜK) 006:352-357 ve 416-421: hayvan kilidini vaka SELECT'inden ÖNCE al (ovsync_hayvan_ertele sırası) ya da kilitten sonra vaka durumunu yeniden doğrula.
4. (KÜÇÜK) D6-report'taki "bayrak 0'da ayar okunmaz" ifadesini düzelt (varsayılanlı okunur, davranış aynı).
Run: yukarıdaki ## Run (001..006 + kabul, db-validate 006 --priors 001..005, CURRENT_DATE grep). Commit `ovsync-tren L-DB D6 tur 2: K6 a/b dışlaması (PG TAI kapanır) + kilit sırası`. D6-report.md'ye `## D6 tur 2` bölümü (Run kanıtı + OZET). Diğer her şeye dokunma.
