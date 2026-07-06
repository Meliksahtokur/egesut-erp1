// tests/sutten-kes.spec.js
// Sütten kesme modal + picker smoke testi (sadece okuma — kesim YAPILMAZ).

import { test, expect } from '@playwright/test';

async function openApp(page) {
  await page.goto('./'); // '/' baseURL'in alt-dizinini düşürüp GH Pages kök 404'üne gider
  await page.waitForSelector('#pg-dash .sv', { timeout: 20000 });
}

test('sütten kes modal açılır ve picker render eder', async ({ page }) => {
  await openApp(page);
  // Veri (animals) state'e yüklenene kadar kısa bekleme
  await page.waitForTimeout(1500);
  await page.evaluate(() => window.openSuttenKesModal && window.openSuttenKesModal());
  const modal = page.locator('#m-sutten-kes');
  await expect(modal).toBeVisible({ timeout: 5000 });
  await expect(page.locator('#sk-tarih')).toHaveValue(/\d{4}-\d{2}-\d{2}/);
  // Picker'da en az bir checkbox veya "yok" mesajı render edilmeli
  const cbCount = await page.locator('#sk-liste input[type=checkbox]').count();
  const emptyCount = await page.locator('#sk-liste').getByText('Süt içen buzağı yok').count();
  expect(cbCount + emptyCount).toBeGreaterThan(0);
});
