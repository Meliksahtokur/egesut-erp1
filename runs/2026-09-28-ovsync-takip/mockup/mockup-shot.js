const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const dir = '/home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/mockup';
  const browser = await chromium.launch({
    executablePath: '/home/melik/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome'
  });
  const page = await browser.newPage({ viewport: { width: 420, height: 920 } });
  await page.goto('file://' + path.join(dir, 'ovsync-takip-mockup.html'));
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(dir, 'ovsync-takip-mockup.png'), fullPage: true });
  await browser.close();
  console.log('PNG OK');
})().catch(e => { console.error('HATA:', e.message); process.exit(1); });
