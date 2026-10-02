const { chromium } = require('playwright');
const path = require('path');

const dir = __dirname;
const dosyalar = [
  '01-bos-devam-secici',
  '02-ovsync-kilitli',
  '03-pg-secili',
  '04-takip-acik-onay',
  '05-takip-muayene-sonuc',
  '06-takip-ekrani-rozet',
  '07-akis',
];

(async () => {
  const browser = await chromium.launch({
    executablePath: '/home/melik/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome'
  });
  const page = await browser.newPage({ viewport: { width: 420, height: 920 } });
  for (const ad of dosyalar) {
    await page.goto('file://' + path.join(dir, ad + '.html'));
    await page.waitForTimeout(200);
    await page.screenshot({ path: path.join(dir, ad + '.png'), fullPage: true });
    console.log('OK', ad);
  }
  await browser.close();
  console.log('HEPSI TAMAM');
})().catch(e => { console.error('HATA:', e.message); process.exit(1); });
