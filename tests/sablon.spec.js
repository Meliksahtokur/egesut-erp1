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

  // Gün ekle → Gün 2 başlığı görünür
  await page.click('[data-action="sablon-gun-ekle"]');
  await expect(page.locator('#m-sablon-body')).toContainText('Gün 2');

  // İptal ile kapat (veri yazılmadı)
  await page.click('[data-action="sablon-iptal"]');
  await expect(page.locator('#m-sablon')).toBeHidden();
});
