# ui-tur4 — GOREV zarfı: 18 madde ELLE tarayıcı yürüyüşü (sahip kararı 2026-10-01)

- **GOREV:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur4-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur4-DONE.md`
- **Koltuk:** `ss-worker-sonnet-medium`
- **Liste (beklenen görünüm = SÖZLEŞME):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-test-listesi.md`
- **Çalışma dizini:** `/home/melik/tmp/agents/uitur-20261001/` (yeni dosyalarını `yuruyus/` alt dizinine koy)

## Neden

25 maddelik otomatik betik (`uitur.spec.js`) güvenilmez çıktı. 7/25 madde PASS, kalan 18 FAIL'in
betikten mi üründen mi geldiği ayrılamadı. O betik **teknik borç (TB-1)** olarak kenara kondu.
Aynı ortamda resmi e2e süiti 12/12 geçiyor. Bu turda 18 madde **tek tek, gözle doğrulanarak**
yürünür. Amaç: her madde için güvenilir bir hüküm.

Zaten PASS olan 7 madde (1, 6, 7, 16, 17, 18, 19) bu turda YOK.

**Yürünecek 18 madde:** 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 20, 21, 22, 23, 24, 25

## Yöntem — madde başına küçük betik + gözle kontrol

Her madde için `yuruyus/m<N>.spec.js` adında ayrı, kısa bir Playwright betiği yaz ve tek başına koş.
Kurulum resmi e2e süitiyle aynıdır (12/12 geçen komut):

    docker run --rm --network host -v <worktree>:/work -w /work \
      -v /home/melik/tmp/agents/uitur-20261001:/agents -v /home/melik/egesut-erp1:/main:ro \
      -e NODE_PATH=/main/node_modules -e PLAYWRIGHT_DEMO_MODE=1 \
      -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8137/ -e HOME=/tmp/pwhome \
      mcr.microsoft.com/playwright:v1.58.2-noble /main/node_modules/.bin/playwright test -c <config> ...

Config için `/home/melik/tmp/agents/uitur-20261001/playwright-resmi.config.cjs` kalıbını kopyala;
testMatch'i yalnız ilgili `m<N>.spec.js`'e daralt; globalSetup/globalTeardown'ı KALDIR.
8137 sunucusu kapalıysa worktree kökünde `python3 -m http.server 8137` ile aç.
Oturum açma ve demo kurulumu için `tests/e2e/ovsync-takip.spec.js` içindeki `openApp`'i örnek al.

**Test verisi:** Turun başında `global-setup.cjs`'i bir kez elle koş (`node`, aynı env ile),
`fixture-state.json` hangi `E2E-UITUR-*` hayvanının hangi maddeye ait olduğunu söyler. Hangi hayvanla
hangi tıklama yolunun yürüneceğini `uitur.spec.js`'in ilgili `M<N>` bölümünden OKU. O test gövdelerini
olduğu gibi kopyalayıp koşma: o betik güvenilmez. Turun sonunda `global-teardown.cjs`'i bir kez koş.

**Her madde betiği için zorunlu bekleme kuralları:**
1. Sayfa açılışında `openApp` ile ilk veri çekmenin bitmesini bekle (resmi süit deseni).
2. Ovsync sayfasında yükleyicinin kaybolmasını bekle:
   `await expect(page.locator('#ovsync-root .loader')).toHaveCount(0, { timeout: 30000 })`.
   Veri global'inin dolmasını (`__ovsyncTakip`) render bitti sayma.
3. Fixture hayvanına bağlı adımdan önce o kaydın IndexedDB'ye geldiğini bekle (`idbGorevBekle` deseni).
4. Her kritik adımda `page.screenshot` al: `runs/2026-09-28-ovsync-takip/artifacts/yuruyus-m<N>-<adim>.png`
   (tam yol: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/artifacts/`).
5. Konsol hatalarını ve 400 üstü HTTP yanıtlarını logla. `demo_sema_diff` 401'i bilinen gürültüdür, hükme katma.

**Hüküm:** Betik "geçti/kaldı" demez; sen ekran görüntüsüne ve DOM metnine bakıp listedeki
"beklenen görünüm" metniyle karşılaştırarak hükmü verirsin. ⚠ işaretli maddelerde (8, 19) beklenti
maddedeki nottan gelir. Hüküm kodları:
- `PASS` — beklenen görünüm birebir.
- `FAIL-ÜRÜN` — veri doğru kurulmuş, ekran listeden farklı. Beklenen/görülen metni yaz.
- `FAIL-KURULUM` — maddeyi yürütecek veri ya da durum kurulamadı. Nedenini yaz.
- `UNKNOWN` — ölçemedin. Nedenini yaz.
Sessiz FAIL yasak: her FAIL'de beklenen/görülen VE ekran görüntüsü yolu olmalı.

**Madde 22 (bayrak kapalı):** `ovsync_pg_kurallari_aktif=0` yapman gerekiyorsa, önceki değeri ölç,
madde biter bitmez eski değere geri al ve geri aldığını DB'den ölçerek DONE'a yaz.
**Madde 23 (offline):** `page.context().setOffline(true)` ile.

## Yazma manifesti (TEK YAZICI)

1. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur4-DONE.md` (create)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/artifacts/yuruyus-*.png`
3. `/home/melik/tmp/agents/uitur-20261001/yuruyus/**` ve `fixture-state.json` (repo dışı)

YASAK: ürün kodu (js/, tests/, supabase/, index.html), `.ss/`, commit/push/merge, sahip demo
hesabı/şifresi, pkill / kill -9, alt-ajan açma. FAIL çıkan maddeyi düzeltme, raporla.
Koşum öncesi `free -g`; available <5 GB → dur, DONE'a yaz.

## DONE

Başlık: `ui-tur4-DONE — 18 maddeden N PASS`. Tablo: madde | hüküm | beklenen (kısa) | görülen (kısa) | PNG yolu.
Altına: FAIL-ÜRÜN maddelerinin ayrıntısı (çoğaltma adımı), FAIL-KURULUM nedenleri, madde 22 geri alma kanıtı,
teardown koşuldu mu.
Bitince DONE'u yaz, SONRA `SendMessage` ile dağıtana tek satır gönder (adres koltuk açılışında bildirilecek):
`DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur4-DONE.md · sonuc: <TAMAM|KISMI|BLOKE>`
Üst sınır 75 dakika; dolarsa eldeki maddelerle KISMI DONE yaz ve dur.
