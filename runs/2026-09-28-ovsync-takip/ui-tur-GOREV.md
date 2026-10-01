# ui-tur — GOREV zarfı: glmf-max 25 maddelik UI test turu (sahibe demo ÖNCESİ kapı)

- **Kural kaynağı:** proje CLAUDE.md "UI testi kapısı" (BAĞLAYICI, 2026-09-25): sahibe demo
  vermeden ÖNCE aynı liste tarayıcıda koşulur; PASS olmadan sahip test almaz.
- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (kapanış turu; plan maddelerinin hepsi teslim).
- **Liste:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-test-listesi.md` (25 madde; P12'de gerçek kopyalarla eşlendi; m.11/16 P12b sonrası beklentiler güncel).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur-DONE.md` (create)
2. `runs/2026-09-28-ovsync-takip/artifacts/uitur-*.png` (kanıt ekran görüntüleri — create)
3. Yardımcı koşum betiği gerekiyorsa `~/tmp/agents/` altında (repo DIŞI)

ÜRÜN KODUNA YAZMA YASAK (js/, tests/, supabase/, index.html). FAIL bulunan madde düzeltilmez — rapor edilir.

## Görev

25 maddenin HER BİRİNİ demo modunda gerçek tarayıcıda koş (Playwright, Docker
`mcr.microsoft.com/playwright:v1.58.2-noble --network host`; worktree yerel sunucu + `?demo`;
NODE_PATH=/home/melik/egesut-erp1/node_modules; P12 spec'inin local-server + EGESUT_DEMO
initScript + IDB pull bekleme desenini `tests/e2e/ovsync-takip.spec.js`'ten al).

Madde başına üret:
- **PASS/FAIL** hükmü + kanıt (ekran görüntüsü `uitur-<madde>.png` + DOM konsol çıktısı; maddenin
  istediği kanıt katmanı: DOM/RPC/DB — listede yazıyor).
- FAIL ise: kesin gözlem (ne bekledi / ne gördü), hangi yüzey (ui.js satırı tahmini), çoğaltma adımı.

Kurallar:
- Liste maddelerindeki "beklenen görünüm" metinleri SÖZLEŞMEDİR (mockup copy birebir kabulü);
  kopya farkı FAIL'dir.
- ⚠ işaretli maddelerde (7, 8, 19) beklenti maddedeki nottan alınır (bilinçli sapmalar).
- Sahibin demo hesabı/şifresi ve geri-alma akışı DOKUNULMAZ; fixture kendi marker'lı verisiyle
  kurulur/temizlenir (P12 spec'inin temizlik deseni).
- RAM disiplini: free -g; available <5 GB → dur, rapora yaz.
- En fazla 2 self-repair (yalnız KOŞUM altyapısı; ürün değil).

## Kabul ölçütleri

1. 25/25 madde hükümlü DONE tablosu (madde → PASS/FAIL → kanıt dosyası).
2. Ekran görüntüleri artifacts/ altında; her FAIL için çoğaltma adımı.
3. **25/25 PASS → sahibe demo kapısı AÇIK** (final impl-DONE'a işlenir); herhangi FAIL →
   kalem kalem rapor, mimar fix turuna alır.

## DONE şablonu

Başlık: `ui-tur-DONE — 25/25 PASS` ya da `KISMİ (N FAIL)` · madde tablosu · kanıt listesi ·
FAIL detayları · koşum ortamı notları (sunucu portu, süre, işletim özeti).
