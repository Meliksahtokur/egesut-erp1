import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 1,
  workers: process.env.CI ? 1 : undefined,
  fullyParallel: !process.env.CI,
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'tests/report' }],
  ],
  use: {
    baseURL: 'https://meliksahtokur.github.io/egesut-erp1/',
    headless: true,
    viewport: { width: 390, height: 844 },
    locale: 'tr-TR',
    actionTimeout: 10000,
  },
  projects: [
    { name: 'chromium', use: { ...devices['iPhone 14'] } },
  ],
});
