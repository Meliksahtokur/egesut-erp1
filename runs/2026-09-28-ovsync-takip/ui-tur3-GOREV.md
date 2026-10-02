# ui-tur3 — GOREV zarfı: 25 maddelik UI turu, betik düzeltmesi + tek koşum (mekanik)

supersedes: `ui-tur2-GOREV.md` (kök neden artık bulundu; araştırma yok)

- **GOREV:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur3-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur-DONE.md`
- **Koltuk:** `ss-worker-sonnet-medium` (mekanik iş — sahip kuralı 2026-10-01)
- **Dağıtan:** mimar oturumu `ovsync-takip-09` (SendMessage adresi)
- **Liste (sözleşme):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-test-listesi.md`
- **Çalışma dizini:** `/home/melik/tmp/agents/uitur-20261001/` (uitur.spec.js, playwright.config.js, clean.cjs, fix-sablon.cjs, run4.log)

## Kök neden (doğrulandı — araştırma YAPMA)

`uitur.spec.js:86` `test.beforeAll` fixture kuruyor, `:261` `test.afterAll` temizliyor. Playwright her
FAIL'de worker'ı yeniden başlatır → afterAll + beforeAll yeniden koşar → fixture silinip yeniden
kurulur → sonraki testler `E2E-UITUR-*` hayvanlarını bulamaz (run 4: 7 PASS / 18 FAIL bu zincir).

## Adımlar

1. Yedek: `cp uitur.spec.js uitur.spec.run4.bak.js` (varsa atla). run4 JSON yedeği hazır: `uitur-sonuc.run4.bak.json`.
2. beforeAll gövdesini + bağımlı yardımcılarını `global-setup.cjs`'e, temizliği `global-teardown.cjs`'e taşı;
   `playwright.config.js`'e `globalSetup` / `globalTeardown` ekle. Testlerin beforeAll'dan aldığı değerleri
   global-setup `fixture-state.json`'a yazsın, spec okusun. Kurulum koşum başına TEK kez olur.
3. Koşum öncesi `free -g` (available <5 GB → dur, DONE'a yaz). `node fix-sablon.cjs` (idempotentse koş).
4. Önceki koşum komutunu `run4.log` başından / dosyalardan çıkar, aynı şekilde koş: Docker
   `mcr.microsoft.com/playwright:v1.58.2-noble --network host`, worktree yerel sunucu `?demo`,
   `NODE_PATH=/home/melik/egesut-erp1/node_modules`, **workers=1**. Log: `run5.log`.
5. Altyapı hatası çıkarsa en fazla 2 düzeltme turu (yalnız betik/fixture). FAIL çıkan maddeyi düzeltme — raporla.

## Yazma manifesti (TEK YAZICI)

1. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur-DONE.md` (create)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/artifacts/uitur-*.png`
3. `/home/melik/tmp/agents/uitur-20261001/**` (repo dışı)

YASAK: ürün kodu (js/, tests/, supabase/, index.html), `.ss/`, commit/push/merge, sahip demo hesabı/şifresi,
pkill / kill -9, alt-ajan açma (mekanik iş — kendin koş).

## DONE

Başlık `ui-tur-DONE — 25/25 PASS` ya da `KISMİ (N FAIL)`. Tablo: madde → PASS/FAIL → kanıt PNG yolu.
Her FAIL: hata mesajının ilk satırı + beklenen/görülen. Koşum notu: komut, süre, globalSetup değişikliği. Kısa.

Bitince: DONE dosyasını yaz, SONRA `SendMessage` ile `ovsync-takip-09`'a tek satır:
`DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur-DONE.md · sonuc: <TAMAM|KISMI|BLOKE>`
Üst sınır 45 dakika; dolarsa eldekiyle KISMI DONE yaz ve dur.
