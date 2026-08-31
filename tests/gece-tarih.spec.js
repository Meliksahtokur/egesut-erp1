// tests/gece-tarih.spec.js
// EgeSüt ERP — Gece (01:00) tarih kayması savunması (Idle-B, 2026-09-01)
//
// Kilitlediği fix — commit 45b41a1 "yerel tarih helper bugun()/_ymd":
//   B4 — toISOString() UTC'dir; İstanbul 00:00-02:59 arasında UTC hâlâ DÜNKÜ
//        gündedir. Eski kod "bugün"ü UTC'den ürettiği için gece yarısından sonra:
//        (a) form tarih default'ları DÜNE kayıyordu,
//        (b) bugünün doğum tarihi "ileri tarih" diye REDDEDİLİYORDU.
//        bugun()/_ymd yerel bileşenlerle üretir.
//
// Yöntem: Playwright clock İstanbul saati 01:00'a sabitlenir (UTC = dünkü gün)
// ve timezoneId=Europe/Istanbul ile yerel/UTC farkı deterministik kılınır.

import { test, expect, openApp, navTo, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

// İstanbul 2026-09-01T01:00:00+03:00 → UTC 2026-08-31T22:00Z.
// Yerel "bugün" = 2026-09-01; UTC "bugün" = 2026-08-31 (B4 bug'ının tam koşulu).
const GEC_E001_UTC = new Date('2026-08-31T22:00:00Z');
const BUGUN_YEREL = '2026-09-01';

test.describe('B4 — gece 01:00 (Europe/Istanbul)', () => {
  test.use({ timezoneId: 'Europe/Istanbul' });

  test('clock 01:00: bugun() yerel tarihi basar, doğum formu default BUGÜN', async ({ page }) => {
    await page.clock.install({ time: GEC_E001_UTC });
    await openApp(page);

    // Probe: helper yerel bileşenlerle üretiyor mu? (UTC kullansaydı dünkü gün dönerdi)
    expect(await page.evaluate(() => bugun())).toBe(BUGUN_YEREL);

    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await expect(page.locator('#m-birth')).toHaveClass(/on/);
    await expect(page.locator('#b-tarih')).toHaveValue(BUGUN_YEREL);

    // Kapat (closeM guarded back ile history'yi de düzeltir)
    await page.evaluate(() => closeM('m-birth'));
    await expect(page.locator('#m-birth')).not.toHaveClass(/on/);
  });

  test('clock 01:00: tohumlama ve görev formlarının default tarihi BUGÜN', async ({ page }) => {
    await page.clock.install({ time: GEC_E001_UTC });
    await openApp(page);
    expect(await page.evaluate(() => bugun())).toBe(BUGUN_YEREL);

    // Tohumlama modalı (log sayfası akışı)
    await navTo(page, '#nb-log');
    await page.evaluate(() => { document.getElementById('i-tarih').value = ''; openM('m-insem'); });
    await expect(page.locator('#m-insem')).toHaveClass(/on/);
    await expect(page.locator('#i-tarih')).toHaveValue(BUGUN_YEREL);
    await page.evaluate(() => closeM('m-insem'));

    // Manuel görev modalı
    await navTo(page, '#nb-tasks');
    await page.evaluate(() => { document.getElementById('ta-tarih').value = ''; openM('m-task-add'); });
    await expect(page.locator('#m-task-add')).toHaveClass(/on/);
    await expect(page.locator('#ta-tarih')).toHaveValue(BUGUN_YEREL);
    await page.evaluate(() => closeM('m-task-add'));
  });

  test('clock 01:00: bugünün doğum tarihi "ileri tarih" diye reddedilmez', async ({ page }) => {
    await page.clock.install({ time: GEC_E001_UTC });
    await openApp(page);

    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await expect(page.locator('#m-birth')).toHaveClass(/on/);

    // Formu geçerli doldur (anne: sürüden dinamik küpe — veri-agnostic;
    // stub backend'de fixture sürüsünden gelir, gerçek demo'da canlı veriden)
    const anneKupe = await page.evaluate(() => {
      const a = (getState('animals') || []).find(x => x.kupe_no || x.devlet_kupe);
      return a ? (a.kupe_no || a.devlet_kupe) : null;
    });
    test.skip(!anneKupe, 'sürüde küpeli hayvan yok (beklenmedik veri durumu)');
    await page.evaluate(k => { document.getElementById('b-anne').value = k; }, anneKupe);
    await page.fill('#b-kupe', `E2E-GECE-${Date.now()}`);
    await page.fill('#b-tarih', BUGUN_YEREL); // yerel BUGÜN — B4 bug'ında > UTC dün → red

    await page.locator('#m-birth .btn-g').click();
    await page.waitForTimeout(1200);

    // B4 kilidi: yerel bugünün tarihi ileri DEĞİLDİR — bu toast gelmemeli.
    // (Backend hatası görünebilir; istenen yalnızca frontend'in YANLIŞ kapıdan
    // reddetmemesi.)
    const toast = (await page.locator('#toast').innerText()).trim();
    expect(toast, `Toast: "${toast}"`).not.toContain('ileri tarih');
  });
});
