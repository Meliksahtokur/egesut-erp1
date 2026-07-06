// playwright.config.js
import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'https://meliksahtokur.github.io/egesut-erp1/';

// PLAYWRIGHT_DEMO_MODE=1 → js/api.js'in okuduğu EGESUT_DEMO localStorage bayrağını
// context oluşturulurken (ilk navigasyondan önce) enjekte eder — app kodu hiç değişmez,
// ?demo query param'ının yaptığını storageState ile yapıyoruz. Böylece istenirse production
// GH Pages üzerinden bile Demo-Mirror Supabase projesine (izole, resetlenebilir) bağlanılır.
const storageState = process.env.PLAYWRIGHT_DEMO_MODE
  ? { cookies: [], origins: [{ origin: new URL(baseURL).origin, localStorage: [
      { name: 'EGESUT_DEMO', value: '1' },
      { name: 'EGESUT_DEMO_POPUP_OFF', value: '1' }, // js/demo.js'in "🧪 Demo Hesabı" popup'ı testte tıklamaları engeller
    ] }] }
  : undefined;

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
    baseURL,
    storageState,
    headless: true,
    viewport: { width: 390, height: 844 }, // iPhone 14 — mobil PWA
    locale: 'tr-TR',
    actionTimeout: 10000,
    trace: 'on-first-retry', // Sadece ilk denemede trace
  },
  // baseURL localhost'a işaret ediyorsa statik sunucuyu otomatik ayağa kaldır.
  // Production (GH Pages) koşumlarında (CI dahil) bu blok devreye girmez.
  webServer: /^https?:\/\/(127\.0\.0\.1|localhost)/.test(baseURL)
    ? {
        command: 'npm run serve:local',
        url: baseURL,
        reuseExistingServer: true,
        timeout: 10000,
      }
    : undefined,
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
