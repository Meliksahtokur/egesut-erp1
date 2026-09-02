// tests/sutten-kes.spec.js
// Sütten kesme modal + picker smoke testi (sadece okuma — kesim YAPILMAZ).
// Veri-agnostic: süt içen buzağı VARSA modal + picker, YOKSA uygulama modalı
// hiç açmayıp "Süt içen buzağı yok" toast'ı basar (forms.js openSuttenKesModal)
// — iki dal da uygulama sözleşmesinin parçası, ikisi de doğrulanır.

import { test, expect } from '@playwright/test';

async function openApp(page) {
  await page.goto('./'); // '/' baseURL'in alt-dizinini (egesut-erp1/) düşürüp GH Pages kök 404'üne gider
  await page.waitForSelector('#pg-dash .sv', { timeout: 20000 });
}

test('sütten kes: buzağı varsa modal açılır, yoksa bilgi toastı', async ({ page }) => {
  await openApp(page);
  await page.waitForTimeout(1500); // animals state'e yüklenene kadar

  const sutIcenVar = await page.evaluate(() =>
    (typeof _sutIcenBuzagilar === 'function' ? _sutIcenBuzagilar() : []).length > 0);

  await page.evaluate(() => window.openSuttenKesModal && window.openSuttenKesModal());

  if (sutIcenVar) {
    const modal = page.locator('#m-sutten-kes');
    await expect(modal).toBeVisible({ timeout: 5000 });
    await expect(page.locator('#sk-tarih')).toHaveValue(/\d{4}-\d{2}-\d{2}/);
    const cbCount = await page.locator('#sk-liste input[type=checkbox]').count();
    expect(cbCount, 'süt içen buzağı varken picker dolu olmalı').toBeGreaterThan(0);
    await page.evaluate(() => closeM('m-sutten-kes'));
  } else {
    // Uygulama sözleşmesi: elverişli buzağı yoksa modal AÇILMAZ, toast bildirir
    await expect(page.locator('#m-sutten-kes')).toBeHidden();
    await expect
      .poll(async () => (await page.locator('#toast').innerText()).trim(), { timeout: 5000 })
      .toContain('Süt içen buzağı yok');
  }
});
