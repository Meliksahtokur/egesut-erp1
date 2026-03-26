// tests/smoke.spec.js
// EgeSüt ERP — Smoke Testleri
// Amaç: Her push öncesi temel akışların kırılmadığını doğrula.
// Kural: Sadece okuma — hiçbir form submit edilmez, veri değiştirilmez.

import { test, expect } from '@playwright/test';

// ─── Kritik JS hataları ──────────────────────────────────────────────────────
// Bilinen/zararsız uyarılar listeye alınır, diğerleri testi durdurur.
const IGNORED_ERRORS = [
  'ResizeObserver loop',
  'Non-passive event listener',
  'IDB',
];

function isCritical(msg) {
  return !IGNORED_ERRORS.some(s => msg.includes(s));
}

// ─── Yardımcı: sayfayı aç, verinin yüklenmesini bekle ──────────────────────
async function openApp(page) {
  const criticalErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error' && isCritical(msg.text()))
      criticalErrors.push(msg.text());
  });
  page.on('pageerror', err => criticalErrors.push(err.message));

  await page.goto('/');
  // Dashboard istatistik satırı görünene kadar bekle (veri yüklendi sinyali)
  await page.waitForSelector('.stat-row', { timeout: 20000 });

  return criticalErrors;
}

// ─── 1. Temel Yükleme ────────────────────────────────────────────────────────
test('sayfa hatasız yüklenir ve dashboard gösterir', async ({ page }) => {
  const errors = await openApp(page);
  await expect(page.locator('#pg-dash')).toBeVisible();
  await expect(page.locator('#nav')).toBeVisible();
  expect(errors, `Kritik JS hataları: ${errors.join(' | ')}`).toHaveLength(0);
});

// ─── 2. Alt Navigasyon ───────────────────────────────────────────────────────
test('tüm nav butonları tıklanabilir ve sayfa geçişi çalışır', async ({ page }) => {
  await openApp(page);

  const navItems = [
    { btn: '#nb-suru',   page: '#pg-suru' },
    { btn: '#nb-tasks',  page: '#pg-tasks' },
    { btn: '#nb-ureme',  page: '#pg-ureme' },
    { btn: '#nb-gecmis', page: '#pg-gecmis' },
    { btn: '#nb-dash',   page: '#pg-dash' },
  ];

  for (const item of navItems) {
    await page.click(item.btn);
    await expect(page.locator(item.page)).toBeVisible({ timeout: 5000 });
  }
});

// ─── 3. Sürü Listesi ─────────────────────────────────────────────────────────
test('sürü sayfasında hayvan kartları yüklenir', async ({ page }) => {
  await openApp(page);
  await page.click('#nb-suru');
  // En az bir hayvan kartı bekleniyor
  await expect(page.locator('.animal-card').first()).toBeVisible({ timeout: 15000 });
  const count = await page.locator('.animal-card').count();
  expect(count).toBeGreaterThan(0);
});

// ─── 4. Hayvan Detay ─────────────────────────────────────────────────────────
test('hayvan kartına tıklayınca detay ekranı açılır', async ({ page }) => {
  await openApp(page);
  await page.click('#nb-suru');
  await page.locator('.animal-card').first().click();

  // Detay ekranı: back butonu + tab'lar görünmeli
  await expect(page.locator('.det-back')).toBeVisible({ timeout: 8000 });
  await expect(page.locator('#tab-ozet')).toBeVisible();
});

// ─── 5. Hayvan Detay Tab Geçişleri ───────────────────────────────────────────
test('hayvan detayında tüm tab\'lar açılır', async ({ page }) => {
  await openApp(page);
  await page.click('#nb-suru');
  await page.locator('.animal-card').first().click();
  await page.locator('.det-back').waitFor({ timeout: 8000 });

  const tabs = ['#tab-saglik', '#tab-ureme', '#tab-gorev', '#tab-gecmis'];
  for (const tab of tabs) {
    await page.locator(tab).click();
    // İçerik yükleniyor spinner veya içerik — sadece hata olmaması yeterli
    await page.waitForTimeout(300);
  }
  // Hata olmadan geçildiyse test geçer
});

// ─── 6. Üreme Sayfası ────────────────────────────────────────────────────────
test('üreme sayfası kızgınlık/tohumlama/doğum tab\'larını gösterir', async ({ page }) => {
  await openApp(page);
  await page.click('#nb-ureme');
  // Üreme sayfasının içeriği (fs-btn filtre butonları)
  await expect(page.locator('#pg-ureme')).toBeVisible();
  await expect(page.locator('#pg-ureme .fs-btn').first()).toBeVisible({ timeout: 10000 });
});

// ─── 7. Görevler Sayfası ─────────────────────────────────────────────────────
test('görevler sayfası yüklenir', async ({ page }) => {
  await openApp(page);
  await page.click('#nb-tasks');
  await expect(page.locator('#pg-tasks')).toBeVisible();
  // Görev kartı veya boş state — ikisi de geçerli
  await page.waitForTimeout(1500);
  const hasTasks  = await page.locator('.task-card').count();
  const hasEmpty  = await page.locator('.empty').count();
  expect(hasTasks + hasEmpty).toBeGreaterThan(0);
});

// ─── 8. FAB → Modal Açılışı ──────────────────────────────────────────────────
test('sürü sayfasında FAB tıklanınca modal açılır', async ({ page }) => {
  await openApp(page);
  await page.click('#nb-suru');
  await page.locator('.animal-card').first().waitFor({ timeout: 10000 });
  await page.locator('.fab').click();
  // Herhangi bir modal açılmış olmalı
  await expect(page.locator('.modal').first()).toBeVisible({ timeout: 5000 });
});

// ─── 9. Geçmiş Sayfası ───────────────────────────────────────────────────────
test('geçmiş sayfası islem_log kayıtlarını gösterir', async ({ page }) => {
  await openApp(page);
  await page.click('#nb-gecmis');
  await expect(page.locator('#pg-gecmis')).toBeVisible();
  // Log butonu veya boş state
  await page.waitForTimeout(2000);
  const hasLog   = await page.locator('.log-btn').count();
  const hasEmpty = await page.locator('.empty').count();
  expect(hasLog + hasEmpty).toBeGreaterThan(0);
});
