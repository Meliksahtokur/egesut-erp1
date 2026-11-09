# D7 — Tren listesi ve toptan erteleme (`20261110100007_ovsync_tren_toptan.sql`)
job_id: j-20261109T084230Z-1a1f01

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D7-report.md

## İş
PLAN.md "### D7" bölümünü birebir uygula (Interfaces — Produces imzaları, adları, hata kodları ve payload alanları AYNEN).
Ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md` (bağlayıcı). Önceki görev report'ları aynı klasörde (`D<k>-report.md`) — yardımcı ve fixture adları için oku.
Testler (kabul betiğine bölüm olarak ekle, mevcut bölümleri bozma): TR-K3-1, TR-LISTE-1, TR-LISTE-2, TR-K7-1..7, TR-K7-KISMI, TR-K7-HAFTA2, TR-K7-TOL, TR-K7-RITIM, TR-K7-N1, TR-K7-N2, TR-K7-ONIZLE, TR-K9-N1 (listede bagimsizlar), TR-ACL-4.
Akış: testleri yaz → koş → ilk koşumda FAIL (ham çıktı report'a) → uygula → koş → `OZET n PASS` (önceki görevlerin testleri dahil hepsi) → db-validate --priors → commit.
Görev notları:
- D6 review tur 2 KÜÇÜK (ek iş, dar fix): `supabase/migrations/20261110100006_ovsync_tren_asama.sql:439-445` `ovsync_bastan_baslat` basladi=false dalı iptal ettiği PG TAI id'lerini dönüşe (`iptal_tai:[uuid]`) ve islem_log payload'ına yazsın (başlatma yolundaki kalıp); TR-K6-B1 aşama 2 alt senaryosuna assert. db-validate 006'yı da yeniden koş.
- D7 toptan BASTAN/PG48 üyeleri için D6 RPC'lerini (ovsync_bastan_baslat, ovsync_pg48_tohumla) yeniden kullan — K6 a/b dışlaması (RL-12) böylece toptanda da geçerli.
- D5 bulgusu: kabul DB'sinde `gorev_ertele_kural` boş; `gorev_ertele`'ye dayanan testler önce `pg_temp.kb_ertele_kural()` çağırır (D5 yardımcısı).
- D4-EK (root ruling, progress.md RL-11): start_first_service_protocol gecikmiş/ritim dışı görevi ilk trene yeniden hedefler; başlatılan vakada (bayrak açık, bağımsız değil) üyelik NULL → OVSYNC_TREN_UYELIK_YOK.
- R6-EK (root SORU-3): `OVSYNC_TREN_ERTELE_DUSTU` `dusenler[]` satırına `oneri:'BASTAN_BASLAT_YA_DA_SEANS_ISARETLE'` (aşama belirsiz düşüşte) eklenir; assert TR-K7-5 genişletilir.
- SÖZLEŞME EKİ (root ruling 2026-11-09; salt ekleme — root mesajı listele'yi D6'ya yazmış, plan'da listele D7'de: burada uygulanır):
  (a) `ovsync_tren_listele` üye satırına `pg_pay int` (aşama 1'de `tolerans − _ovsync_pg1_kayma(case)`, ≥0 değilse 0'a kırpma YOK — ham değer; aşama≠1 → NULL), `ritim_disi_neden text` (ritim dışı üyede, örn. 'PG +1 gün' = kayma kaynaklı; ritimdekilerde NULL), `pg1_zaman timestamptz` (PG1 seansı tamamlandıysa en geç `uygulama_tamamlandi_at`, değilse NULL).
  (b) `ovsync_tren_ertele_onizle` (ve `_ovsync_tren_ertele_plan`) `uyeler` satırına `ovsync_tren date` (üyenin treni; görev üyede hedef tarihi), `pg1_zaman`, `pg_pay` (aynı tanım); üst düzeye `tren_sayisi int` (uyeler'deki farklı ovsync_tren sayısı) ve `dokunulmaz:{bagimsiz:int, ritim_disi:int}` (o tarihte işi olan ama kümeye girmeyenler).
  Assert'ler: `TR-EK-LISTE` (pg_pay aşama1=tolerans−kayma, aşama0/2 NULL; ritim_disi_neden; pg1_zaman), `TR-EK-ONIZLE-2` (ovsync_tren, tren_sayisi=2 iki trenli fixture'da, dokunulmaz sayıları). Kaynak: UA1-report sapma 2,3,4.
- D2 bulgusu: db-validate statik denetimi `LATERAL` ve `unnest(...) k(alias)` desenlerinde INCONCLUSIVE (rc=2) veriyor — bu desenlerden kaçın.
- D2 bulgusu: `add_treatment_day_with_sessions` geçmiş tarihli günü `tamamlandi=true` + seans açık kurar → R6'ya göre aşama NULL. Aşama fixture'larını `kb_seans_yap` ile kur; geçmiş D0'lı vakanın NULL (belirsiz) çıkması spec §7 ile uyumlu beklenen davranıştır.
- RL-9: build.sh KOŞMA; kabul DB'si hazır.
- RL-1: aşama 0/1 KAYAR üyelerde etiket `vaka_kalan_gunleri_kaydir` içinde artar; `ovsync_tren_ertele` ayrıca artırmaz.
- Kısmi başarı YOK: üye başına alt-blok, hata listesi doluysa sonda `OVSYNC_TREN_ERTELE_DUSTU` RAISE (çapa dahil her şey geri) — TR-K7-5 bunu ölçer.
- Önizleme yazmaz (TR-K7-ONIZLE md5).

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim SQL ~400 satır (yalnız migration dosyası; kopyalanan gövdeler dahil). Test hariç. Aşım = report'ta `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D7-report.md

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS`; listelenen her TR-* id'si en az bir `kb_ok` ile koşuyor (report'ta id → PASS satırı listesi).
- db-validate exit 0.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- PLAN.md D7 "Etki" maddesindeki çağıranlar yeni imza/davranışla kırılmıyor (kanıt report'ta).
- Commit dosya dosya; mesaj `ovsync-tren L-DB D7: <özet>`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D6

## Review: T2

## Önceden cevaplanmış kararlar
- PLAN.md S1–S11, R1–R20, Kapı tur 2 ekleri; progress.md RL-*. Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şeyse DUR ve `SORU:` yaz.

## Devam
Önceki report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D7-report.md (commit 9dc700c, 456 PASS). Önceki worker bağlamı doldu → taze worker, aynı brief.
T2 tur 1 DÜZELT: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D7-review-report.md:15-19. Lead Ruling'leri progress.md RL-14..RL-17 (bağlayıcı). YALNIZ şunlar (007 + kabul betiği; 006'ya gerekmedikçe dokunma):
1. RL-14: `ovsync_tren > X` aşama 0 aktif OVSYNC vakaları toptanda +N (vaka_kalan_gunleri_kaydir; etiket RL-1 ile), plan/dönüş/önizlemede `ileri_vakalar:[{case_id, hayvan_id, kupe_no, eski, yeni}]`. Assert TR-K7-ILERI.
2. RL-15: toptan BASTAN hedefi = X+N, aynı işlemde başlatma yok. TR-K7-2'yi X=bugün,N=7 ve X=bugün+3,N=4 varyantlarıyla genişlet (hedef X+N, basladi=false). D7-report Varsayım 1 / "X bugünse her zaman X+N" ifadesini düzelt.
3. RL-16: ilk ritim günü kapısı + assert TR-K7-N3.
4. RL-17: (iii) aşama 0 üye → BASTAN; assert TR-K7-GECIKMIS.
5. KÜÇÜK: `_ovsync_pg1_kayma` satır başına bir kez; KAPALI payload'ında doğru rpc adı (ya da kaldır).
Önce testler → FAIL → fix → PASS. Run: yukarıdaki ## Run (+ 006 değiştiyse db-validate 006). Commit `ovsync-tren L-DB D7 tur 2: RL-14..17 (toptan ileri vakalar, X+N, ilk tren kapısı)`. D7-report.md'ye `## D7 tur 2` (Run kanıtı + OZET + BOYUT). Bağlamı verimli kullan.
