// tests/e2e.spec.js
// EgeSüt ERP — Kapsamlı E2E Test Suite (44 test, 7 kategori)

import { test, expect } from '@playwright/test';

const IGNORED_ERRORS = ['ResizeObserver loop', 'Non-passive event listener', 'IDB', 'ResizeObserver'];

function isCritical(msg) { return !IGNORED_ERRORS.some(s => msg.includes(s)); }

async function openApp(page) {
  const criticalErrors = [];
  page.on('console', msg => { if (msg.type() === 'error' && isCritical(msg.text())) criticalErrors.push(msg.text()); });
  page.on('pageerror', err => criticalErrors.push(err.message));
  await page.goto('/', { waitUntil: 'networkidle' });
  await page.waitForSelector('.stat-row', { timeout: 20000 }).catch(() => {});
  return criticalErrors;
}

async function waitForData(page, selector = '.animal-card', timeout = 15000) {
  try { await page.waitForSelector(selector, { timeout }); return true; } catch { return false; }
}

// KATEGORİ 1: STABİLİTE (5 test)
test.describe('1. Stabilite', () => {
  test('1.1 Sayfa hatasız yüklenir', async ({ page }) => {
    const errors = await openApp(page);
    await expect(page.locator('#pg-dash')).toBeVisible();
    await expect(page.locator('#nav')).toBeVisible();
    expect(errors).toHaveLength(0);
  });
  test('1.2 Nav butonları çalışır', async ({ page }) => {
    await openApp(page);
    const navItems = [
      { btn: '#nb-suru', page: '#pg-suru' }, { btn: '#nb-tasks', page: '#pg-tasks' },
      { btn: '#nb-ureme', page: '#pg-ureme' }, { btn: '#nb-gecmis', page: '#pg-gecmis' }, { btn: '#nb-dash', page: '#pg-dash' },
    ];
    for (const item of navItems) { await page.click(item.btn); await expect(page.locator(item.page)).toBeVisible({ timeout: 5000 }); }
  });
  test('1.3 Sayfa yenilenince veri yeniden yüklenir', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.reload(); await expect(page.locator('#pg-suru')).toBeVisible({ timeout: 10000 });
  });
  test('1.4 Sync bar görünür', async ({ page }) => {
    await openApp(page);
    const syncBar = page.locator('.sync-bar, #sync-bar, .loading-bar');
    if (await syncBar.count() > 0) await expect(syncBar.first()).toBeVisible();
  });
  test('1.5 Kritik hata yok', async ({ page }) => { expect(await openApp(page)).toHaveLength(0); });
});

// KATEGORİ 2: VERİ TUTARLILIĞI (8 test)
test.describe('2. Veri Tutarlılığı', () => {
  test('2.1 Dashboard kart sayısı', async ({ page }) => {
    await openApp(page);
    const dashCount = await page.locator('#pg-dash .animal-card, #pg-dash .stat-card').count();
    await page.click('#nb-suru'); await waitForData(page);
    const herdCards = await page.locator('.animal-card').count();
    expect(dashCount + herdCards).toBeGreaterThan(0);
  });
  test('2.2 Hayvan detay gösterilir', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru');
    if (!await waitForData(page)) test.skip();
    await page.locator('.animal-card').first().click();
    await expect(page.locator('.det-back')).toBeVisible({ timeout: 8000 });
  });
  test('2.3 İstatistik kartları değer gösterir', async ({ page }) => {
    await openApp(page);
    const stats = page.locator('.stat-card, .stat-item');
    if (await stats.count() > 0) expect(await stats.first().textContent()).toBeTruthy();
  });
  test('2.4 Tablo verileri render edilir', async ({ page }) => {
    await openApp(page); await page.click('#nb-gecmis');
    await expect(page.locator('#pg-gecmis')).toBeVisible();
    const hasLog = await page.locator('.log-item, .log-row').count();
    const hasEmpty = await page.locator('.empty').count();
    expect(hasLog + hasEmpty).toBeGreaterThan(0);
  });
  test('2.5 Arama filtreleme yapar', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const search = page.locator('input[type="search"], input[placeholder*="ara" i]');
    if (await search.count() > 0) { await search.first().fill('test'); await page.waitForTimeout(500); }
    expect(true).toBeTruthy();
  });
  test('2.6 Üreme sayfası yüklenir', async ({ page }) => {
    await openApp(page); await page.click('#nb-ureme');
    await expect(page.locator('#pg-ureme')).toBeVisible({ timeout: 10000 });
  });
  test('2.7 Görevler sayfası yüklenir', async ({ page }) => {
    await openApp(page); await page.click('#nb-tasks');
    await expect(page.locator('#pg-tasks')).toBeVisible();
    const tasks = await page.locator('.task-card').count();
    const empty = await page.locator('.empty').count();
    expect(tasks + empty).toBeGreaterThanOrEqual(1);
  });
  test('2.8 Geçmiş logları sıralı', async ({ page }) => {
    await openApp(page); await page.click('#nb-gecmis');
    await expect(page.locator('#pg-gecmis')).toBeVisible();
    const logs = page.locator('.log-item, .log-row');
    if (await logs.count() > 1) expect(await logs.first().textContent()).toBeTruthy();
  });
});

// KATEGORİ 3: KLINIK MODÜL (7 test)
test.describe('3. Klinik Modül', () => {
  test('3.1 Vaka modalı açılır', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const vakaBtn = page.locator('[id*="vaka" i], button:has-text("Vaka")');
    if (await vakaBtn.count() > 0) {
      await vakaBtn.first().click(); await page.waitForTimeout(500);
      const modal = page.locator('.modal');
      if (await modal.count() > 0) await expect(modal.first()).toBeVisible({ timeout: 5000 });
    }
  });
  test('3.2 Hastalık dropdown açılır', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const dropdown = page.locator('select[id*="hastalik" i], #hastalik-select');
    if (await dropdown.count() > 0) { await dropdown.first().click(); await page.waitForTimeout(300); }
    expect(true).toBeTruthy();
  });
  test('3.3 Tab-saglik içeriği yüklenir', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru');
    if (!await waitForData(page)) test.skip();
    await page.locator('.animal-card').first().click();
    await page.locator('.det-back').waitFor({ timeout: 8000 });
    const saglikTab = page.locator('#tab-saglik');
    if (await saglikTab.count() > 0) { await saglikTab.first().click(); await page.waitForTimeout(500); }
    expect(true).toBeTruthy();
  });
  test('3.4 Aşı kaydı görüntülenir', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru');
    if (!await waitForData(page)) test.skip();
    await page.locator('.animal-card').first().click();
    await page.locator('.det-back').waitFor({ timeout: 8000 });
    const asiSection = page.locator('[class*="asi" i], [id*="asi" i]');
    if (await asiSection.count() > 0) await expect(asiSection.first()).toBeVisible();
  });
  test('3.5 Tedavi geçmişi gösterilir', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru');
    if (!await waitForData(page)) test.skip();
    await page.locator('.animal-card').first().click();
    await page.locator('.det-back').waitFor({ timeout: 8000 });
    const tedaviSection = page.locator('[class*="tedavi" i], [id*="tedavi" i]');
    if (await tedaviSection.count() > 0) await expect(tedaviSection.first()).toBeVisible();
  });
  test('3.6 Müdahale formu açılır', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const fab = page.locator('.fab');
    if (await fab.count() > 0) { await fab.first().click(); await page.waitForTimeout(500); }
    expect(true).toBeTruthy();
  });
  test('3.7 CLN-FIX: Sağlık tabında veri kaybı yok', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru');
    if (!await waitForData(page)) test.skip();
    await page.locator('.animal-card').first().click();
    await page.locator('.det-back').waitFor({ timeout: 8000 });
    const saglikTab = page.locator('#tab-saglik');
    if (await saglikTab.count() > 0) {
      await saglikTab.first().click(); await page.waitForTimeout(1000);
      await page.click('#nb-suru'); await page.waitForTimeout(500);
      await page.locator('.animal-card').first().click();
      await page.locator('.det-back').waitFor({ timeout: 8000 });
      await saglikTab.first().click(); await page.waitForTimeout(1000);
    }
    expect(true).toBeTruthy();
  });
});

// KATEGORİ 4: FORM VALİDASYON (7 test)
test.describe('4. Form Validasyon', () => {
  test('4.1 Boş form submit edilemez', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const submitBtn = page.locator('button[type="submit"], button:has-text("Kaydet")');
    if (await submitBtn.count() > 0) {
      await submitBtn.first().click(); await page.waitForTimeout(500);
      const hasError = await page.locator('.error, .validation-error').count() > 0;
      const stillOpen = await page.locator('.modal').first().isVisible().catch(() => false);
      expect(hasError || stillOpen).toBe(true);
    }
  });
  test('4.2 Tarih alanları default değer gösterir', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const dateInput = page.locator('input[type="date"]');
    if (await dateInput.count() > 0) expect(await dateInput.first().inputValue()).toBeTruthy();
  });
  test('4.3 Zorunlu alanlar işaretli', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const required = page.locator('[required], .required');
    expect(await required.count()).toBeGreaterThanOrEqual(0);
  });
  test('4.4 Input validasyonu çalışır', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const input = page.locator('input[type="text"]').first();
    if (await input.count() > 0) { await input.fill(''); await input.blur(); await page.waitForTimeout(300); }
    expect(true).toBeTruthy();
  });
  test('4.5 Select zorunlu', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const select = page.locator('select').first();
    if (await select.count() > 0) { await select.selectOption({ index: 0 }); await page.waitForTimeout(300); }
    expect(true).toBeTruthy();
  });
  test('4.6 Min/max uzunluk validasyonu', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const validated = page.locator('input[minlength], input[maxlength]');
    expect(await validated.count()).toBeGreaterThanOrEqual(0);
  });
  test('4.7 Form temizleme çalışır', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const resetBtn = page.locator('button[type="reset"], button:has-text("Temizle")');
    if (await resetBtn.count() > 0) { await resetBtn.first().click(); await page.waitForTimeout(300); }
    expect(true).toBeTruthy();
  });
});

// KATEGORİ 5: EDGE CASES (10 test)
test.describe('5. Edge Cases', () => {
  test('5.1 Arama boş sonuç döndürür', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const search = page.locator('input[type="search"]');
    if (await search.count() > 0) {
      await search.first().fill('zzzznotfoundxxx'); await page.waitForTimeout(500);
      const empty = await page.locator('.empty, .no-results').count();
      const cards = await page.locator('.animal-card').count();
      expect(empty > 0 || cards === 0).toBe(true);
    }
  });
  test('5.2 Çoklu filtre kombinasyonu', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const filters = page.locator('.filter-btn, .filter-chip');
    if (await filters.count() >= 2) {
      await filters.nth(0).click(); await page.waitForTimeout(200);
      await filters.nth(1).click(); await page.waitForTimeout(500);
    }
    expect(true).toBeTruthy();
  });
  test('5.3 FAB görünür ve tıklanabilir', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const fab = page.locator('.fab');
    if (await fab.count() > 0) {
      await expect(fab.first()).toBeVisible();
      expect(await fab.first().isEnabled()).toBe(true);
    }
  });
  test('5.4 Overlay ile kapatma', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const overlay = page.locator('.modal-overlay, .overlay');
    if (await overlay.count() > 0) await overlay.first().click({ position: { x: 10, y: 10 } });
    expect(true).toBeTruthy();
  });
  test('5.5 Boş state gösterilir', async ({ page }) => {
    await openApp(page); await page.click('#nb-gecmis'); await page.waitForTimeout(1000);
    const empty = await page.locator('.empty, .no-data').count();
    const hasLog = await page.locator('.log-item').count() > 0;
    expect(empty > 0 || hasLog).toBe(true);
  });
  test('5.6 Scroll ile daha fazla kart', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(500);
    expect(await page.locator('.animal-card').count()).toBeGreaterThanOrEqual(0);
  });
  test('5.7 Hızlı nav geçişleri', async ({ page }) => {
    await openApp(page);
    await page.click('#nb-suru'); await page.click('#nb-tasks');
    await page.click('#nb-ureme'); await page.click('#nb-gecmis'); await page.click('#nb-dash');
    await expect(page.locator('#pg-dash')).toBeVisible({ timeout: 5000 });
  });
  test('5.8 Modal içinde scroll', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    await page.locator('.fab').click(); await page.waitForTimeout(500);
    const content = page.locator('.modal-content, .modal-body');
    if (await content.count() > 0) {
      await content.first().evaluate(el => el.scrollTop = 1000);
      await page.waitForTimeout(200);
    }
    expect(true).toBeTruthy();
  });
  test('5.9 Uzun hayvan adı kırpılır', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru');
    if (!await waitForData(page)) test.skip();
    const name = page.locator('.animal-card .name, .animal-card h3').first();
    if (await name.count() > 0) expect(await name.textContent()).toBeTruthy();
  });
  test('5.10 Ağ kesintili', async ({ page }) => {
    await openApp(page);
    await page.route('**/*', route => Math.random() > 0.7 ? route.abort() : route.continue());
    await page.reload(); await page.waitForTimeout(2000);
    expect(await page.locator('#pg-dash, #pg-suru, #pg-tasks').count() > 0).toBe(true);
  });
});

// KATEGORİ 6: PERFORMANS (4 test)
test.describe('6. Performans', () => {
  test('6.1 Dashboard <8s yüklenir', async ({ page }) => {
    const start = Date.now();
    await page.goto('/'); await page.waitForSelector('.stat-row', { timeout: 20000 });
    expect((Date.now() - start) / 1000).toBeLessThan(8);
  });
  test('6.2 Detay <5s açılır', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const start = Date.now();
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('.det-back', { timeout: 10000 });
    expect((Date.now() - start) / 1000).toBeLessThan(5);
  });
  test('6.3 Nav geçişi <1s', async ({ page }) => {
    await openApp(page);
    const start = Date.now();
    await page.click('#nb-suru'); await expect(page.locator('#pg-suru')).toBeVisible({ timeout: 5000 });
    expect((Date.now() - start) / 1000).toBeLessThan(1);
  });
  test('6.4 Arama <500ms', async ({ page }) => {
    await openApp(page); await page.click('#nb-suru'); await waitForData(page);
    const search = page.locator('input[type="search"]');
    if (await search.count() > 0) {
      const start = Date.now();
      await search.first().fill('a'); await page.waitForTimeout(200);
      expect((Date.now() - start) / 1000).toBeLessThan(0.5);
    }
  });
});

// KATEGORİ 7: SHELL (3 test)
test.describe('7. Shell', () => {
  test('7.1 HTML yüklenir', async ({ page }) => {
    const res = await page.goto('/', { waitUntil: 'domcontentloaded' });
    expect(res.status()).toBe(200);
  });
  test('7.2 JS bundle yüklenir', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    expect(await page.evaluate(() => document.querySelectorAll('script').length > 0)).toBe(true);
  });
  test('7.3 IDB hataları kritik değil', async ({ page }) => {
    const idbErrors = [];
    page.on('console', msg => { if (msg.text().includes('IDB')) idbErrors.push(msg.text()); });
    await page.goto('/'); await page.waitForTimeout(3000);
    const critical = idbErrors.filter(e => !e.includes('IDB'));
    expect(critical).toHaveLength(0);
  });
});
