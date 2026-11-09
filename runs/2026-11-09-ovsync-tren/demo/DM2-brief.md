# DM2 — UI kapısı (G-UI, 14 madde) + zaman senaryosu ekran vitrini — demo tarayıcı yürüyüşü
job_id: j-20261109T173631Z-8f4180

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM2-report.md

## Plan maddesi
PLAN N6 DM2 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md :586-612) — 14 maddelik tablo BİREBİR (adım, beklenen görünüm, sahibin karar sorusu) + UB-ekler "N6 eki — ZAMAN SENARYOSU" madde 2 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-ekler.md).
Proje kuralı (CLAUDE.md UI testi kapısı): PASS olmadan sahibe demo verilmez. Ölçüt DOM varlığı DEĞİL, sahibin karar sorusunun ekrandan okunması.
Durum: demo (ref `vtzqjmazsvurxdeondmi`) seri uygulanmış, tren bayrağı AÇIK, çapa 2026-11-12 (Per). Dal kodu uç 60a3b79 (N4-F3 dahil). Önceki demo kayıtları: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM1-report.md (e2e seed/temizlik kalıbı, koşum komutu) ve tests/e2e/ovsync-tren.spec.js (yardımcılar: demo girişi, IDB bekleme, görev kartı).

## İş
1. Vitrin verisi (demo, `E2E-TREN-UI-` işaretli, KALICI — sahip demosu da bunu görecek; temizlik betiği yaz ama KOŞMA): 14 maddeyi ve zaman senaryosu durumlarını aynı anda gösterecek 6–8 hayvan: bu Perşembe treninde aşama 0 (2), geçen hafta treninden aşama 1 (1, PG1 1 gün geç → `pg_pay` görünür), aşama 2 (1), bağımsız başlatılmış (1), hastalık günü girilmiş → bağımsız (1), ritim dışı (1), başlatma bekleyen OVSYNC_BASLAT görevi (1, madde 2-3 için), mastit görevi (madde 8), d2/d25 doğum fixture'ı (madde 11). Sunucu RPC'leriyle kur (doğrudan tablo INSERT yalnız RPC yolu yoksa; nedenini rapora yaz). Kurulum betiği + oluşan id'ler rapora. Prod ve başka ref YASAK.
2. Yürüyüş: standalone Playwright betiği (tarif: ~/.claude/projects/-home-melik-egesut-erp1/memory/l4-sahip-yuruyusu-tarif.md — `EGESUT_DEMO` initScript, IDB pull bekleme), dal kodu yerel sunucudan, mobil (390×844) + masaüstü (1280×800) görüntü. 14 madde sırayla; her madde: PASS/FAIL + PNG yolu + ilgili DOM metni + konsol hataları + **sahibin karar sorusuna ekrandan okunan cevap (tek cümle, ekrandaki metinle)**. Madde 10 çevrimdışı (context offline). Madde 12 renk: hesaplanmış `background-color` satır/kartlarda nötr mü (yalnız yazı rengi vurgu) — sayısal ölçüm.
3. Zaman senaryosu vitrini: vitrin hayvanlarının her biri için Ovsync ekranı + görev kartı + vaka kartı "bu hafta hangi gün kaç hayvanla ne iş var" sorusuna doğru cevap veriyor mu — beklenen cevap PLAN R1–R20 / design K1–K11'den (kural kimliğiyle) yazılır, ekrandan okunanla karşılaştırılır. Madde başına PASS/FAIL + PNG.
4. Anlam ölçümü (ui-kapisi-anlam-olcmeli dersi): her ekranda boş/"—"/"bilinmiyor" hücre oranı; çoğunluk boşsa FAIL.
5. FAIL → DÜZELTME YOK (bu brief kod yazmaz): `BULGU: <madde> — beklenen ≠ görülen — PNG — tahmini dosya:satır`. Kod düzeltmesi root kararıyla ayrı iş.
6. Mutasyon yapan adımlar (madde 3, 4-6 önizleme/onay, 9, 13, 14): onay gerektirenleri vitrin hayvanlarından AYRI, `E2E-TREN-UI-X-` işaretli kopya hayvanlarda yap ki vitrin sahip demosu için bozulmadan kalsın; onları sonda temizle.

## Model
sonnet (ss-worker) — tarayıcı yürüyüşü.

## Boyut bütçesi
Betikler `$HOME/tmp/dm2/` altında (repo dışı); repoya yalnız report + PNG'ler.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM2-report.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/ui-kapisi

## Run
ls ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/ui-kapisi/*.png | wc -l
grep -c "^| *[0-9]* *|.*PASS" ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM2-report.md

## Kabul
- 14/14 madde PASS + zaman vitrini maddeleri PASS; her madde PNG + ekrandan okunan karar cevabı.
- Vitrin verisi demoda duruyor (id listesi + temizlik betiği yolu rapora), X kopyaları temizlendi.
- FAIL varsa `sonuc: KISMI` + BULGU listesi.
- Commit: report + PNG'ler (`git add` dosya dosya ya da `git add runs/2026-11-09-ovsync-tren/demo/ui-kapisi/<dosya>`; `-A`/`.` YASAK), mesaj `ovsync-tren N6 DM2: UI kapisi`; push YOK.

## Review: root

## Önceden cevaplanmış kararlar
- Demo yazma izinli (goal); demo sahip şifresine dokunma. Demo INACTIVE ise `~/egesut-erp1/.env` `SUPABASE_DEMO_PAT` ile restore, sormadan.
- Playwright bir kez yeter: madde FAIL'i düzeltilince yalnız o madde tekrar koşulur.
- `/tmp` yasak; `$HOME/tmp/dm2/`. Ağır koşum `ram-ultracode exec --class test --wait 1800 -- bash <betik>`.
- Web/GBM gerekmez (kullanacaksan önce Skill("gbm")).
