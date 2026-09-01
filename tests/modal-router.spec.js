// tests/modal-router.spec.js
// EgeSüt ERP — Modal Router savunma hattı (Idle-B, 2026-09-01)
//
// Kilitlediği fix'ler — commit c096485 "modal router tutarlılık paketi":
//   B2  — popstate'te ölü '.modal.on' selector yerine globalThis._modalStack'in
//         EN ÜSTÜ kapanır; closeM cleanup'i Android geri tuşunda da çalışır;
//         modal kapanışı goTo tetiklemediği için alttaki sayfa + sürü filtreleri
//         korunur; _modalBackGuard kod kaynaklı history.back'in popstate'ini
//         tüketir (yığılmış modallarda alttaki yanlışlıkla kapanmaz)
//   B3  — mclose-overlay (backdrop-tap) closeM'den geçer: _planliTohumlamaGorevId
//         sıfırlanır ve m-animal formu resetlenir (eski sızıntı: kapanmış planlı
//         göreve sonraki NORMAL tohumlama yazılıyordu); öksüz history girdisi yok
//   B21 — protokol sheet'leri tek noktadan kapanır (_closeProtokolListe/Detay);
//         detay tazelemede yeniden pushState YOK (öksüz girdi birikmez);
//         {protokol}/{proto_detay} state'leri popstate'te sayfa taşımaz —
//         sheet açıkken geri tuşu uygulamayı dash'e atmıyor
//   B22 — m-confirm-ok DOM property onclick yerine attribute onclick (_confirmOk)
//
// Bu spec DB'ye yazmaz; UI/router davranışını kilitler. Prod'a HİÇ bağlanmaz.

import { test, expect, openApp, navTo, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

// Protokol sheet'i gerçek veri olmadan deterministik açmak için sentetik uyarı
// enjekte eder (veri-agnostic: demo verisinde protokol satırı varsaymaz).
async function injectProtokolUyari(page) {
  await page.evaluate(() => {
    window.__protokolUyarilar = [{
      hayvan_id: 'e2e-hayvan', kupe_no: 'E2E-KUPE', grup: 'TEST', adim: 'Test adımı',
      protokol: 'E2E-PROTOKOL', durum: 'eksik', gecikme_gun: 2,
      etken_kod: null, kapatan_ref: null, tamamlanma_tarihi: null,
    }];
    _showProtokolEkran();
  });
  await expect(page.locator('#protokol-bs')).toBeAttached();
}


// Overlay'in ÇIPLAK alanına (sheet üstü şerit) dokunur. Sheet konumu içerik
// büyümesiyle değiştiği için sabit nokta yarışır — sheet üst kenarını ölçüp
// overlay'in güvenli ortasına tıklarız (mouse.click viewport koordinatı).
async function backdropTap(page, sheetSelector) {
  const y = await page.evaluate((sel) => {
    const r = document.querySelector(sel)?.getBoundingClientRect();
    return r && r.top > 16 ? Math.max(8, Math.floor(r.top / 2)) : 15;
  }, sheetSelector);
  await page.mouse.click(195, y);
}

// ═════════════════════════════════════════════════════════════════════════════
// B2 — Android geri tuşu: yalnız modal kapanır, sayfa + filtre korunur
// ═════════════════════════════════════════════════════════════════════════════

test('B2: modal açıkken Android geri → modal kapanır, sürü sayfası ve filtre chip korunur', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-suru');
  await page.waitForSelector('.animal-card', { timeout: 15000 });

  // Sürü filtresi uygula — B2 öncesi popstate yanlış yoldan goTo tetikleyince
  // fchipReset bu chip state'ini siliyordu
  await page.click('#fc-cinsiyet-disi');
  await page.waitForTimeout(450); // filterA debounce 250ms
  await expect(page.locator('#fc-cinsiyet-disi')).toHaveClass(/on/);
  const countBefore = await page.locator('.animal-card').count();

  // Router'a kayıtlı modal aç (openM → history.pushState({modal}) + _modalStack)
  await page.evaluate(() => openM('m-insem'));
  await expect(page.locator('#m-insem')).toHaveClass(/on/);
  expect(await page.evaluate(() => history.state?.modal)).toBe('m-insem');

  // Android geri tuşu
  await page.goBack();

  await expect(page.locator('#m-insem')).not.toHaveClass(/on/);
  // Altındaki SAYFA yerinde kalmalı (goTo tetiklenmemeli)
  await expect(page.locator('#pg-suru')).toHaveClass(/on/);
  await expect(page.locator('#pg-dash')).not.toHaveClass(/on/);
  expect(await page.evaluate(() => history.state?.modal)).toBeUndefined();
  // Filtre korunmalı
  await expect(page.locator('#fc-cinsiyet-disi')).toHaveClass(/on/);
  expect(await page.evaluate(() => _fchip.cinsiyet)).toBe('disi');
  await page.waitForTimeout(450); // olası gecikmiş filterA debounce'u da geç
  expect(await page.locator('.animal-card').count()).toBe(countBefore);
});

// ═════════════════════════════════════════════════════════════════════════════
// B2 (yığın) + B22 — confirm üstteyken geri yalnız confirm'i kapatır;
// OK butonu attribute onclick ile action'ı çalıştırır
// ═════════════════════════════════════════════════════════════════════════════

test('B2+B22: yığılmış confirm üstteyken geri → yalnız confirm kapanır, alttaki modal ayakta', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-suru');
  await page.waitForSelector('.animal-card', { timeout: 15000 });

  // Alt modal + üstünde confirm (yığın)
  await page.evaluate(() => openM('m-insem'));
  await expect(page.locator('#m-insem')).toHaveClass(/on/);
  await page.evaluate(() => openConfirm('E2E Başlık', 'E2E açıklama', () => { window.__e2eConfirmKoptu = true; }));
  await expect(page.locator('#m-confirm')).toHaveClass(/on/);

  // Android geri → en üstteki (confirm) kapanmalı, alttaki m-insem KALMALI
  await page.goBack();
  await expect(page.locator('#m-confirm')).not.toHaveClass(/on/);
  await expect(page.locator('#m-insem')).toHaveClass(/on/);
  await expect(page.locator('#pg-suru')).toHaveClass(/on/);
  // Confirm geri ile kapandı → action ÇALIŞMAMALI
  expect(await page.evaluate(() => window.__e2eConfirmKoptu)).toBeUndefined();

  // B22: OK butonu attribute onclick (_confirmOk) ile kapatır + action çalışır;
  // closeM'in guarded history.back'i alt modali yakmamalı
  await page.evaluate(() => openConfirm('E2E Başlık 2', 'E2E', () => { window.__e2eConfirmOkCalisti = true; }));
  await expect(page.locator('#m-confirm')).toHaveClass(/on/);
  await page.click('#m-confirm-ok');
  await expect(page.locator('#m-confirm')).not.toHaveClass(/on/);
  await expect(page.locator('#m-insem')).toHaveClass(/on/); // _modalBackGuard koruması
  await expect(page.locator('#pg-suru')).toHaveClass(/on/); // sayfa da korunur
  expect(await page.evaluate(() => window.__e2eConfirmOkCalisti)).toBe(true);

  // Temizlik: kalan modalı kapat (guarded back)
  await page.evaluate(() => closeM('m-insem'));
  await expect(page.locator('#m-insem')).not.toHaveClass(/on/);
});

// ═════════════════════════════════════════════════════════════════════════════
// B3 — backdrop-tap kapatması closeM'den geçer: planlı-tohumlama bayrağı sıfırlanır
// ═════════════════════════════════════════════════════════════════════════════

test('B3: backdrop-tap kapatma _planliTohumlamaGorevId sızıntısını temizler ve history girdisini düşürür', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-log');

  // Planlı tohumlama akışının bıraktığı durumu simüle et: bayrak takılı
  await page.evaluate(() => { globalThis._planliTohumlamaGorevId = 'e2e-stale-gorev-id'; });

  await page.evaluate(() => openM('m-insem'));
  await expect(page.locator('#m-insem')).toHaveClass(/on/);
  expect(await page.evaluate(() => history.state?.modal)).toBe('m-insem');

  // Backdrop'a (overlay'in sheet dışı alanına) dokun
  await backdropTap(page, '#m-insem .modal');

  await expect(page.locator('#m-insem')).not.toHaveClass(/on/);
  // B3 kilidi: closeM temizliği backdrop yolunda da çalışır — sonraki NORMAL
  // tohumlama eski planlı görev id'sine yazmaz
  expect(await page.evaluate(() => globalThis._planliTohumlamaGorevId)).toBeNull();
  // Öksüz history girdisi yok: modal state tüketildi
  expect(await page.evaluate(() => history.state?.modal)).toBeUndefined();
  await expect(page.locator('#pg-log')).toHaveClass(/on/); // sayfa fırlamadı
});

// ═════════════════════════════════════════════════════════════════════════════
// B21 — protokol sheet'leri: öksüz history yok, geri tuşu dash'e atmıyor
// ═════════════════════════════════════════════════════════════════════════════

test('B21: protokol liste/detay sheet kapanışları öksüz history üretmez, geri normal çalışır', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-suru'); // dash → suru (geri tuşu deneyi için bilinen sayfa sırası)

  await injectProtokolUyari(page);
  const lenListe = await page.evaluate(() => history.length);
  expect(await page.evaluate(() => history.state?.protokol)).toBe(true);

  // Detay sheet aç → +1 history girdisi
  await page.evaluate(() => _showProtokolDetay('e2e-hayvan', 'E2E-PROTOKOL', 0));
  await expect(page.locator('#proto-detay-bs')).toBeAttached();
  const lenDetay = await page.evaluate(() => history.length);
  expect(lenDetay).toBe(lenListe + 1);

  // B21: detay tazelemede yeniden pushState YOK (öksüz girdi birikmez)
  await page.evaluate(() => _showProtokolDetay('e2e-hayvan', 'E2E-PROTOKOL', 0));
  await expect(page.locator('#proto-detay-bs')).toBeAttached();
  expect(await page.evaluate(() => history.length)).toBe(lenDetay);

  // Detayı kendi yoluyla kapat → guarded back tüketilir: liste yerinde, sayfa suru.
  // (B21 öncesi: kapanışın UNguarded history.back'i popstate üretiyor,
  // {protokol} state'inde e.state.pg undefined → goTo('dash') → dash'e atlama)
  await page.evaluate(() => _closeProtokolDetay());
  await expect(page.locator('#proto-detay-bs')).toHaveCount(0);
  await expect(page.locator('#protokol-bs')).toBeAttached();
  await expect(page.locator('#pg-suru')).toHaveClass(/on/);
  await expect(page.locator('#pg-dash')).not.toHaveClass(/on/);

  // Listeyi backdrop ile kapat → yine guarded, sayfa suru kalır
  await backdropTap(page, '#protokol-bs > div');
  await expect(page.locator('#protokol-bs')).toHaveCount(0);
  await expect(page.locator('#pg-suru')).toHaveClass(/on/);

  // Kümülatif öksüz girdi yok: tek normal geri → dash'e DÖNMELİ (öksüz {protokol}
  // girdisi kalsaydı bu back popstate'te yakılırdı ve dash'e ulaşılamazdı)
  await page.goBack();
  await expect(page.locator('#pg-dash')).toHaveClass(/on/);
  await expect(page.locator('#pg-suru')).not.toHaveClass(/on/);
});

test('B21: sheet açıkken Android geri → uygulama dash\'e atlamaz, sayfa yerinde kalır', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-suru');

  await injectProtokolUyari(page);

  // Android geri: sheet'in history girdisi tüketilir ama {protokol} state'ine
  // düşen popstate sayfa taşımamalı (B21: return) — dash'e atlama yok
  await page.goBack();
  await expect(page.locator('#pg-suru')).toHaveClass(/on/);
  await expect(page.locator('#pg-dash')).not.toHaveClass(/on/);
});
