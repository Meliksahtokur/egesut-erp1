// playwright.config.js
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 1,
  workers: process.env.CI ? 1 : undefined, // CI'da shard başına 1 worker
  fullyParallel: !process.env.CI, // Local'de paralel, CI'da sequential
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'tests/report' }],
  ],
  use: {
    baseURL: 'https://meliksahtokur.github.io/egesut-erp1/',
    headless: true,
    viewport: { width: 390, height: 844 }, // iPhone 14 — mobil PWA
    locale: 'tr-TR',
    actionTimeout: 10000,
    trace: 'on-first-retry', // Sadece ilk denemede trace
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['iPhone 14'] },
    },
    // Diğer browser'lar (opsiyonel)
    // {
    //   name: 'firefox',
    //   use: { ...devices['iPhone 14'] },
    // },
  ],
});
