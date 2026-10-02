# e2e triyaj GÖREV — ovsync-takip.spec.js 12/12 (kalem 3 kalanı)

- **Koltuk:** ss-worker-sonnet-medium (herdr ayrı tab)
- **GOREV:** /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/e2e-triyaj-GOREV.md (bu dosya)
- **DONE:** /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/e2e-triyaj-DONE.md
- **Goal:** /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/.harness/goals/2026/G-20261002-OVSYNC-SONRASI-BORC.md
- **Kod:** worktree /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi, HEAD `626e3ee` (dal ovsync-sonrasi). NODE_PATH=/home/melik/egesut-erp1/node_modules.
- **Önce oku:** /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/k3-TB6-DONE.md (önceki koşumlar, A/B, loglar ~/tmp/ovsync-sonrasi-k3/). Skill: systematic-debugging-obra.

## Durum
`temizle()` düzeltildi (626e3ee). e2e en iyi 11/12. İki ayrı kırmızı imza:
1. **T-01/T-20** — `b` hayvanı Üreme listesinde "Arama sonucu yok"; HEAD `ffdc342` arşivinde de görülüyor → flake/veri görünürlüğü (IDB pull sonrası arama). 
2. **T-84/T-85 timeout (+ ardından T-03/T-50)** — YALNIZ çalışma ağacında görüldü (w2, w3); o sırada çalışma ağacında js/ui.js (TB-3 zaman aşımı + TB-5 yorum), js/demo.js (TB-2 onAuthStateChange) ve demo'ya 20261002000002 uygulanıyordu. **Soru: bu turun ürün değişikliklerinden biri regresyon mu?**

## Yap
1. A/B (aynı demo DB, migration artık demo'da kalıcı): `git archive ffdc342` vs `git archive 626e3ee` — her biri temizlik sonrası **2 tur** yalnız ovsync-takip.spec.js; ayrı port. Sonuç tablosu.
2. T-84/T-85 yalnız B'de kırmızıysa: bisect — `626e3ee` üzerinde tek tek geri al (js/demo.js'i ffdc342 sürümüne / js/ui.js TB-3 hunk'ını) ve hangi değişikliğin tetiklediğini bul (kopya ağaçta; worktree'ye yazma). Kök neden + kanıt (trace/ekran görüntüsü/konsol).
3. T-01/T-20 için: hayvan IDB'ye ne zaman düşüyor, test neyi bekliyor — test bekleme koşulu mu eksik (ör. pull bitmeden arama)? Ürün değil test sorunuysa minimal test düzeltmesi öner (diff olarak DONE'a yaz).
4. Düzeltme: **test dosyası düzeltmesi** gerekiyorsa `tests/e2e/ovsync-takip.spec.js`'e yazabilirsin (tek yazar sensin) ve 12/12'yi 2 ardışık turda göster. **Ürün kodu (js/) regresyonu** bulursan DÜZELTME — kök + önerilen diff ile DONE'a yaz, dur.
5. 2 kendi-onarım turundan sonra hâlâ kırmızıysa dur, raporla.

## Kurallar
- Yalnız demo DB; prod'a dokunma. Demo sahip şifresine dokunma.
- Yazabileceğin: `tests/e2e/ovsync-takip.spec.js` (worktree), DONE, kanıt dizini `/home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/e2e-triyaj-kanit/`, $TMPDIR/~/tmp (/tmp YASAK). git add/commit YOK.
- İş sonu `kupe_no LIKE 'E2E-%' AND durum='Aktif'` = 0 ölçümü.

## DONE biçimi
A/B tablosu (koşum | ağaç | sonuç | kırmızılar), kök neden(ler) kanıt etiketli ([OBSERVED]/[CONFIRMED]/[INFERRED]), uygulanan test diff'i ya da önerilen ürün diff'i, E2E aktif ölçümü. Son satır `SONUC: YESIL_12|URUN_REGRESYONU|FLAKE_KALDI|BLOKE`.
Bitince DONE'u yaz, SONRA mimar oturumuna (seni açan; ListAgents) SendMessage: `DONE: /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/e2e-triyaj-DONE.md · sonuc: <...>`.
