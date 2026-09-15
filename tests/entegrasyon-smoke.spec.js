// tests/entegrasyon-smoke.spec.js
// EgeSüt ERP — L4 entegrasyon dumanı: GERÇEK RPC (stub YOK, ?stub'sız açılış).
// W1 motor genişletmesi demo'da canlı OLDUKTAN SONRA lead entegrasyon kanıtı:
//   1. Değişiklikler listesi gerçek degisim_listele'den dolar; stub banner YOK.
//   2. Tx detayı gerçek veriyle açılır.
//   3. Geri-al düğmesi GERÇEK degisim_onizle modalını açar (iptalle kapanır —
//      mutasyon YOK; bilet/uygulama insan akışı yürüyüşünde sahibte).
// Yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar (stub savunma hattı deseni).
import { test, expect, IS_DEMO, openApp } from './support/app.js';

test.skip(!IS_DEMO, 'gerçek-RPC dumanı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

test('entegrasyon: gerçek RPC listesi + gerçek önizleme (stub inert)', async ({ page }) => {
  await openApp(page); // ?stub YOK — window.DEGISIM_STUB tanımsız kalmalı
  await expect.poll(() => page.evaluate(() => typeof window.DEGISIM_STUB), { timeout: 5000 }).toBe('undefined');

  await page.evaluate(() => degisikliklerAc());
  // Gerçek listede görünür kart tümü gürültü filtresine takılmış olabilir
  // (demo kayıtları psql/koşum kaynaklı → 'uygulama dışı'); özet + çip akışı üzerinden doğrula.
  await page.waitForSelector('#dg-liste .dg-sayac, #dg-liste .dg-kart', { timeout: 30000 });
  let kartSayi = await page.locator('#dg-liste .dg-kart').count();
  if (kartSayi === 0) {
    const cip = page.locator('#dg-liste .gm-cip, #dg-root .gm-cip', { hasText: 'Uygulama dışı' }).first();
    await cip.click(); // gürültüyü göster
    await page.waitForSelector('#dg-liste .dg-kart', { timeout: 15000 });
    kartSayi = await page.locator('#dg-liste .dg-kart').count();
  }
  expect(kartSayi).toBeGreaterThan(0); // gerçek degisim_listele verisi
  await expect(page.locator('#dg-root .dg-stub')).toHaveCount(0); // stub banner YOK

  await page.locator('#dg-liste .dg-kart').first().click();
  await page.waitForSelector('.dg-detay-bas', { timeout: 15000 });

  const btn = page.locator('[data-action="dg-geri-al"]').first();
  if (await btn.count()) {
    await btn.click();
    await page.waitForSelector('#m-dg-onizle', { state: 'visible', timeout: 15000 });
    await expect(page.locator('#dg-onizle-govde')).not.toBeEmpty();
    await page.locator('[data-action="dg-onizle-kapat"], #dg-onizle-kapat').first().click();
    await page.waitForSelector('#m-dg-onizle', { state: 'hidden', timeout: 8000 });
  } else {
    test.info().annotations.push({ type: 'note', description: 'ilk tx satırında geri-al düğmesi yok (U satır değil) — önizleme adımı atlandı' });
  }
});
