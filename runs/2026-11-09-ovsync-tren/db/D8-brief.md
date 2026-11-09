# D8 — Ayar ve göç (`20261110100008_ovsync_tren_ayar_goc.sql`)
job_id: j-20261109T084230Z-dc2082

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8-report.md

## İş
PLAN.md "### D8" bölümünü birebir uygula (Interfaces — Produces imzaları, adları, hata kodları ve payload alanları AYNEN).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı). Önceki görev report'ları aynı klasörde (`D<k>-report.md`) — yardımcı ve fixture adları için oku.
Testler (kabul betiğine bölüm olarak ekle, mevcut bölümleri bozma): TR-GOC-1, TR-GOC-2, TR-GOC-3, TR-GOC-4, TR-AYAR-P1, TR-AYAR-N3, TR-AYAR-CRON, TR-ACL-5.
Akış: testleri yaz → koş → ilk koşumda FAIL (ham çıktı report'a) → uygula → koş → `OZET n PASS` (önceki görevlerin testleri dahil hepsi) → db-validate --priors → commit.
Görev notları:
- ROOT RULING SORU-4 (progress.md 'SORU-4 CEVAP' + RL-13) — `supabase/tests/ovsync_pg_kabul.sql` bu görevde yazılabilir: A6 (:1506, :1514-1515 ACL dizisine yeni imzalar — A4 kalıbı, kontrol sayısı/rolleri azalmaz), A7 (:1684 R10 yeni anahtar biçimi), A5 (S10 iki dal: aktif=1 → 15, aktif=0 → 12 + d2 hatırlatma assert'i, RL-13). Her değişen assert yanında `-- root ruling 2026-11-09 SORU-4 Ax: <§ / fn:satır>`. Başka assert DEĞİŞMEZ.
- D8 regresyon kabulü (SORU-4): düzeltilmiş ovsync_pg_kabul.sql SERİ (001..008) ile tam PASS (OZET) + Bölüm 1 PASS sayısı; `git diff 4e46386 -- supabase/tests/ovsync_pg_kabul.sql` assert diff'i yalnız A5–A7 kalemlerini içerir → diff dosyası `runs/2026-11-09-ovsync-tren/db/d8-pgk-assert-diff.txt` (kanıt); d8-regresyon.md'de yeni OZET ve D8a tabanıyla (482/31) fark açıklaması.
- D5 review tur 2 KÜÇÜK (ek iş): `supabase/tests/ovsync_tren_kabul.sql` ~1646-1653 22:00 testine saat yuvarlamasının `hedef_tarih`'i gerçekten ertesi güne kaydırdığı (ya da kaydırmadığı) beklentisini açık assert olarak ekle.
- D5 bulgusu: kabul DB'sinde `gorev_ertele_kural` boş; `gorev_ertele`'ye dayanan testler önce `pg_temp.kb_ertele_kural()` çağırır (D5 yardımcısı).
- D4-EK (root ruling, progress.md RL-11): start_first_service_protocol gecikmiş/ritim dışı görevi ilk trene yeniden hedefler; başlatılan vakada (bayrak açık, bağımsız değil) üyelik NULL → OVSYNC_TREN_UYELIK_YOK.
- D3 review KÜÇÜK (ek iş): R10 'son tohumlama' sırası mutantını öldüren assert `TR-ANAH-2` — iki tohumlamalı hayvanda `kaynak_ref` son tohumlama id'siyle biter.
- D3 review KÜÇÜK (not): bayrak açıkken ayar bozuksa cron/uyarı/takip toptan OVSYNC_TREN_AYAR ile düşer (spec §7) — `ovsync_tren_ayar_guncelle` açılıştan önce ayarı doğrular; d8-regresyon.md'ye runbook notu.
- R6-EK (root SORU-3): `ovsync_tren_yeniden_hedefle` dönüşüne `belirsiz_asama:[{case_id, hayvan_id, kupe_no}]` + `belirsiz_sayisi` (aktif OVSYNC vakalarından `_ovsync_asama` NULL olanlar; kuru modda da) eklenir — prod runbook P1c yanında sahibe gider. Assert `TR-GOC-5`.
- D2 review KÜÇÜK: `_ovsync_tren_ayar()` çapa min/max'ı okumuyor; `ovsync_tren_ayar_guncelle` çapayı 20260101..20991231 aralığında doğrulasın (aralık dışı → `OVSYNC_TREN_AYAR`), assert `TR-AYAR-N5`.
- D2 bulgusu: db-validate statik denetimi `LATERAL` ve `unnest(...) k(alias)` desenlerinde INCONCLUSIVE (rc=2) veriyor — bu desenlerden kaçın.
- RL-9: build.sh KOŞMA; kabul DB'si hazır.
- Ek iş (PLAN.md D8 + root Ruling SORU-1 (b)): regresyon eşitliği = D8a'da onarılmış `ovsync_pg_kabul.sql` seri 001..008 uygulanmış halde koşulur; kabul = bayrak 0 bölümünde `d8a-taban.md` ile birebir eşit PASS sayısı (taban: serisiz toplam 482, Bölüm 1 bayrak 0 = 31, Bölüm 0 = 29 — D8a-report.md) (toplam da raporlanır; fark varsa assert id'leriyle) + tüm TR-*-REG testleri PASS → `d8-regresyon.md`; seri bütün koşumu; geri alma provası `runs/2026-11-09-ovsync-tren/db/geri-al.sql` (seri sonrası aynı transaction'da koşulur → 16 fonksiyonun md5'i D0 tablosuyla aynı, yeni fonksiyonlar yok, `cases.ovsync_tren` yok). Hepsi BEGIN/ROLLBACK sarmalında, yerel kabul DB'sinde.
- `ovsync_tren_ayar_guncelle` `islem_log` PROTOKOL_AYAR kalıbı `protokol_ayar_guncelle` ile aynı snapshot.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~200 satır (yalnız migration dosyası; kopyalanan gövdeler dahil). Test hariç. Aşım = report'ta `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_pg_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/d8-pgk-assert-diff.txt
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8-report.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/d8-regresyon.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/geri-al.sql

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS`; listelenen her TR-* id'si en az bir `kb_ok` ile koşuyor (report'ta id → PASS satırı listesi).
- db-validate exit 0.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- PLAN.md D8 "Etki" maddesindeki çağıranlar yeni imza/davranışla kırılmıyor (kanıt report'ta).
- Commit dosya dosya; mesaj `ovsync-tren L-DB D8: <özet>`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D7, D8a

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-*. Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şeyse DUR ve `SORU:` yaz.

## Devam
Önceki report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8-report.md (commit acd0f71, 539 PASS). Taze worker. T2 tek tur DÜZELT: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8-review-report.md:19-22. YALNIZ (008 + kabul betiği):
1. RL-18: 008:151 `IF p_aktif` → `IF p_aktif AND (v_aktif = 0 OR v_yeni_c <> v_eski_c)` (göç + üyelik yalnız açılışta ya da çapa değişince); değişmeyen çağrıda `yeniden_hedef` null. TR-GOC-3 idempotentliği doğrudan `ovsync_tren_yeniden_hedefle(false)` ile ölçülsün. Yeni TR-GOC-6: açılıştan sonra tren gününde `start_first_service_protocol(.., p_bagimsiz=>true)` → `ovsync_tren_ayar_guncelle(true, aynı çapa)` → `ovsync_tren` NULL kalır.
2. KÜÇÜK: 008:135 koşulu `IF v_aktif IS NULL OR (p_aktif AND v_eski_c IS NULL)`; TR-AYAR-P1'e "çapa satırı silinmiş + kapat → ok, aktif 0".
3. KÜÇÜK: 008:131-134 dört SELECT → tek sorgu (FILTER).
Önce test → FAIL → fix → PASS. Run: yukarıdaki ## Run + pgk seri koşumu (487/Bölüm 1 33 değişmemeli). Commit `ovsync-tren L-DB D8 tur 2: RL-18 göç yalnız açılış/çapa değişiminde`. D8-report.md'ye `## D8 tur 2` (Run kanıtı + OZET). Yeni review turu yok — Run kanıtın kapanış kanıtıdır. Yalın çalış.
