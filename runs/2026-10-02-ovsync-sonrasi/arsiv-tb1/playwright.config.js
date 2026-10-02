// ui-tur koşum config'i — repo DIŞI (~/tmp/agents); repo config'inin aynısı
// (demo storageState + mobil viewport). Test dosyası /agents/uitur.spec.js.
import { defineConfig } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:8137/';

const storageState = {
  cookies: [],
  origins: [{ origin: new URL(baseURL).origin, localStorage: [
    { name: 'EGESUT_DEMO', value: '1' },
    { name: 'EGESUT_DEMO_POPUP_OFF', value: '1' },
  ] }],
};

export default defineConfig({
  globalSetup: '/agents/global-setup.cjs',
  globalTeardown: '/agents/global-teardown.cjs',
  testDir: '/agents',
  testMatch: /uitur\.spec\.js/,
  timeout: 120000,
  retries: 0,
  workers: 1,
  fullyParallel: false,
  reporter: [
    ['list'],
    ['json', { outputFile: '/agents/uitur-sonuc.json' }],
  ],
  use: {
    baseURL,
    storageState,
    headless: true,
    viewport: { width: 390, height: 844 },
    locale: 'tr-TR',
    actionTimeout: 10000,
    trace: 'off',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});
