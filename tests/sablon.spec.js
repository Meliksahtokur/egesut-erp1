// tests/sablon.spec.js
// #63 Şablon Tedavi Planlama — smoke
// Kural: sadece UI render kontrolü, hiçbir kayıt DB'ye yazılmaz (Kaydet'e basılmaz).

import { test, expect } from '@playwright/test';

async function openApp(page) {
  await page.goto('./'); // '/' baseURL'in alt-dizinini düşürüp GH Pages kök 404'üne gider
  await page.waitForSelector('#pg-dash .sv', { timeout: 20000 });
}

test('Tanımlar Şablonlar sekmesi açılır ve builder render olur', async ({ page }) => {
  await openApp(page);

  // Tanımlar panelini global fonksiyonla aç (nav yolundan bağımsız)
  await page.evaluate(() => openTanimlarPanel());
  await expect(page.locator('[data-action="tanimlar-tab-sablonlar"]')).toBeVisible({ timeout: 10000 });

  // Şablonlar sekmesine geç
  await page.click('[data-action="tanimlar-tab-sablonlar"]');
  await expect(page.locator('[data-action="sablon-yeni"]')).toBeVisible({ timeout: 10000 });

  // Yeni şablon builder modalını aç
  await page.click('[data-action="sablon-yeni"]');
  await expect(page.locator('#m-sablon')).toBeVisible();
  await expect(page.locator('#sb-ad')).toBeVisible();

  // Yeni şablon başlangıç gününü Gün 0 olarak gösterir.
  await expect(page.locator('#m-sablon-body')).toContainText('Gün 0');
  await page.check('[data-change="sablon-tohumlama-toggle"]');
  await expect(page.locator('#m-sablon-body')).toContainText('Planlı tohumlama ekle');

  // İkinci günün ofseti düzenlenebilir ve korunur.
  await page.click('[data-action="sablon-gun-ekle"]');
  const offsets = page.locator('[data-change="sablon-gun-ofset"]');
  await offsets.nth(1).fill('7');
  await offsets.nth(1).press('Tab');
  await expect(page.locator('#m-sablon-body')).toContainText('Gün 7');

  // İptal ile kapat (veri yazılmadı)
  await page.click('[data-action="sablon-iptal"]');
  await expect(page.locator('#m-sablon')).toBeHidden();
});
