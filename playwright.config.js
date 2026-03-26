// playwright.config.js
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 1,
  use: {
    baseURL: 'https://meliksahtokur.github.io/egesut-erp1/',
    headless: true,
    viewport: { width: 390, height: 844 }, // iPhone 14 — mobil PWA
    locale: 'tr-TR',
    // Supabase çağrıları için yeterli bekleme
    actionTimeout: 10000,
  },
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'tests/report' }]],
});
