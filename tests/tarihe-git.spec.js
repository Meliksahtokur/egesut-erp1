// tests/tarihe-git.spec.js
// EgeSüt ERP — TG1 Faz 1 "Tarihe git" tek-gün görünümü e2e ayakları.
//
// Kilitlenen sözleşmeler (zarf TG1-W2 md.3-4):
//   1. Geçmiş sekmesi "📅 Tarihe git" girişi KANONİK tarih seçiciyi açar
//      (tekTarihTakvimAc — #tek-tarih-takvim; yeni takvim bileşeni YOK).
//   2. Seçilen günün olayları gün görünümünde; banner seçili günü + olay
//      sayısını gösterir (sayı = dedup SONRASI pipeline sayısı).
//   3. todayKey sözleşmesi: grup etiketi (BUGÜN/DÜN) GERÇEK bugünden
//      türetilir — seçili gün todayKey'e asla geçmez.
//   4. ✕ Kapat → defter görünümü döner.
//
// Veri disiplini: yalnız OKUMA — form submit YOK, DB yazımı YOK. Demo veri
// miktarı bilinemediğinden "en zengin gün" sayfa içi pipeline'dan seçilir;
// veri hiç yoksa test skip eder (veri-bağımlı skip konvansiyonu).
//
// Ortam: PLAYWRIGHT_DEMO_MODE=1 (tarih-secici.spec.js ile aynı ayak izi).

import { test, expect, openApp, navTo, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

test.use({
  locale: 'en-US',
  viewport: { width: 412, height: 915 },
  hasTouch: true,
  isMobile: true,
});

const takvim = page => page.locator('#tek-tarih-takvim');
const banner = page => page.locator('#gecmis-gun-banner');

// Sayfa içi pipeline'dan dedup SONRASI gün sayıları (unit hattının canlı aynası)
async function gunSayilari(page) {
  return page.evaluate(async () => {
    const sources = await _gecmisCollectSources();
    const all = _gmGunEntriesFromSources(sources);
    const counts = {};
    all.forEach(e => { counts[e.olayGunu] = (counts[e.olayGunu] || 0) + 1; });
    return counts;
  });
}

test.describe('TG1 — "Tarihe git" tek-gün görünümü', () => {

  test('şerit + kanonik takvim: Bugün hücresi seçilir, banner görünür', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');

    await expect(page.locator('[data-action="gecmis-tarihe-git"]')).toBeVisible();
    await expect(page.locator('[data-action="gecmis-gun-bugun"]')).toBeVisible();
    await expect(page.locator('[data-action="gecmis-gun-dun"]')).toBeVisible();

    await page.click('[data-action="gecmis-tarihe-git"]');
    await expect(takvim(page)).toBeVisible(); // kanonik bileşen — kopya değil

    const t = await page.evaluate(() => bugun());
    const hucre = page.locator(`#tek-tarih-takvim div[onclick*="${t}"]`);
    await expect(hucre).toHaveCount(1);
    await hucre.click();
    await page.click('#tek-tarih-takvim button:has-text("Onayla")');
    await expect(takvim(page)).toHaveCount(0);

    // banner: seçili gün vurgusu + olay sayısı (0 da meşru — demo verisine bağlı)
    await expect(banner(page)).toBeVisible();
    await expect(banner(page)).toContainText(/olay/);
  });

  test('en zengin gün: banner sayısı dedup sonrası pipeline sayısıyla eşit, kartlar render', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');

    const counts = await gunSayilari(page);
    const gunler = Object.keys(counts).sort((a, b) => counts[b] - counts[a]);
    test.skip(!gunler.length, 'demo verisinde hiç olay günü yok — veri-bağımlı skip');
    const hedef = gunler[0];

    // seçim UI katmanından (eski aylara takvim sayfalaması yerine tek nokta:
    // gecmisGunSec — handlers.js'teki butonların çağırdığı aynı kapı)
    await page.evaluate(iso => gecmisGunSec(iso), hedef);

    await expect(banner(page)).toBeVisible();
    await expect(banner(page)).toContainText(`${counts[hedef]} olay`);
    await expect(page.locator('#gecmis-body .gm-gun')).toHaveCount(1);
    const kartlar = await page.locator('#gecmis-body .stok-item').count();
    expect(kartlar).toBe(counts[hedef]);

    // todayKey sözleşmesi: hedef gün bugün DEĞİLSE etiket BUGÜN olamaz
    const bugunIso = await page.evaluate(() => bugun());
    if (hedef !== bugunIso) {
      const etiket = await page.locator('#gecmis-body .gm-gun summary').innerText();
      expect(etiket, 'seçili gün todayKey olamaz — gerçek etiket: ' + etiket).not.toContain('BUGÜN');
    }
  });

  test('Dün hızlı girişi: grup etiketi DÜN (gerçek bugünden türetilir)', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');

    await page.click('[data-action="gecmis-gun-dun"]');
    await expect(banner(page)).toBeVisible();

    const dun = await page.evaluate(() => dAgo(bugun(), 1));
    expect(await page.evaluate(() => _gecmisGun)).toBe(dun);

    // olay varsa grup etiketi DÜN'dür (todayKey gerçek bugün — sözleşme md.4)
    const counts = await gunSayilari(page);
    if (counts[dun]) {
      await expect(page.locator('#gecmis-body .gm-gun summary')).toContainText('DÜN');
    } else {
      await expect(page.locator('#gecmis-body')).toContainText('Bu güne ait kayıt yok');
    }
  });

  test('✕ Kapat: defter görünümü döner, banner gizli', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');

    await page.click('[data-action="gecmis-gun-bugun"]');
    await expect(banner(page)).toBeVisible();
    await page.click('[data-action="gecmis-gun-kapat"]');

    await expect(banner(page)).toBeHidden();
    expect(await page.evaluate(() => _gecmisGun)).toBe(null);
    // defter: gün-süzmesiz görünümden gelir — body dolu (grup ya da boş-uyarı)
    const bodyText = await page.locator('#gecmis-body').innerText();
    expect(bodyText.trim().length).toBeGreaterThan(0);
  });
});
