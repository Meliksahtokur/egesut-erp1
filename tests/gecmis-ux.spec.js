// tests/gecmis-ux.spec.js
// EgeSüt ERP — U1 "Geçmiş / Tarihe git UX" e2e ayakları.
//
// Kilitlenen sözleşmeler (zarf U1-tg1-gecmis-ux md.1-4):
//   1. Ham BUYUK_HARF_KOD hiçbir kartta görünmez (islem_log tipi → Türkçe etiket
//      tek haritadan; bilinmeyen tip okunur yedek).
//   2. Ölü kart yok: işlem aynası kartı dâhil her kart data-action delegasyonlu;
//      islem kartı → islem detay paneli KARTIN ALTINDA açılır (eskiden sessiz
//      no-op'tu: .hist-row hedefi D9 sonrası yok).
//   3. Katlı toplu kart: aynı dakika+yığın ≥3 satır tek kart; tık → satırlar
//      görünür, her satır tıklanabilir; tekrar tık → kapanır.
//   4. Gün özeti çipleri: kategori sayaçları; tık → filtre, tekrar tık → kaldır;
//      "Tümü" çipi; mobil (≤400px) sarma.
//
// Veri disiplini: yalnız OKUMA — form submit YOK, DB yazımı YOK.
// Fixturler: 2026-09-06 (en zengin gün, tarihe-git.spec.js ile aynı ölçüm) ve
// 2026-09-13 (sahip ölçümü: toplu tedavi var — katlı kart garantili gün).

import { test, expect, openApp, navTo, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

test.use({
  locale: 'en-US',
  viewport: { width: 390, height: 844 }, // kabul ölçütü mobil boyutu
  hasTouch: true,
  isMobile: true,
});

const RAW_KOD = /[A-Z]{4,}_[A-Z_]{2,}/; // ham kod biçimi: KELIME_KELIME (alt çizgili)
const HAM_UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i; // ham hayvan id YOK (root-1)

test.describe('U1 — Geçmiş/Tarihe-git UX', () => {

  test('gün görünümü: ham kod YOK, ham UUID YOK, her kart data-action delegasyonlu, tek filtre satırı', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');
    await page.evaluate(iso => gecmisGunSec(iso), '2026-09-06');
    await expect(page.locator('#gecmis-body .gm-gun')).toHaveCount(1);

    // root-1: hayvan verisi geldikten sonra tara — boot-pull gecikmesi UUID
    // yanlış-pozitifi üretmesin (ölçüm: hayvanlar store commit'i ~5.5 sn)
    await expect.poll(async () => page.evaluate(() => (getState('animals') || []).length),
      { timeout: 30000, intervals: [500, 1000, 2500] }).toBeGreaterThan(0);

    // md.1: görünür metinde ham KELIME_KELIME kodu YOK (textContent CSS
    // text-transform'dan etkilenmez — uppercase pill biçimleri yanlış-pozitif vermez)
    const govdeMetni = await page.locator('#gecmis-body').textContent();
    const ham = govdeMetni.match(new RegExp(RAW_KOD.source, 'g'));
    expect(ham, 'görünür metinde ham kod: ' + (ham || []).join(', ')).toBeNull();

    // root-1: ham hayvan UUID'si kartlarda ASLA görünmez (çözülemeyen → '?')
    const uuid = govdeMetni.match(new RegExp(HAM_UUID.source, 'gi'));
    expect(uuid, 'görünür UUID: ' + (uuid || []).join(', ')).toBeNull();

    // md.2: kartlar dataset-delegasyonlu — inline onclick YOK
    const onclicklu = await page.locator('#gecmis-body .stok-item[onclick]').count();
    expect(onclicklu).toBe(0);

    // md.2: işlem aynası kartları dâhil HER kartın bir hedefi var
    const hedefsiz = await page.evaluate(() => {
      const kartlar = [...document.querySelectorAll('#gecmis-body .stok-item')];
      return kartlar
        .filter(k => !k.hasAttribute('data-action') && !k.closest('.islem-detay-panel'))
        .map(k => (k.querySelector('div[style*="font-weight:700"]') || {}).textContent || k.textContent.slice(0, 40));
    });
    expect(hedefsiz, 'hedefsiz kartlar: ' + hedefsiz.join(' | ')).toEqual([]);

    // root-3: gün modunda TEK filtre satırı — eski satır gizli, çipler görünür
    expect(await page.locator('#gecmis-filtre-satir').isHidden()).toBe(true);
    await expect(page.locator('#gecmis-gun-cipler .gm-cip').first()).toBeVisible();
  });

  test('islem kartı → islem detay paneli kartın altında açılır, Kapat ile gider', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');
    await page.evaluate(iso => gecmisGunSec(iso), '2026-09-06');
    await expect(page.locator('#gecmis-body .gm-gun')).toHaveCount(1);

    const islemKart = page.locator('#gecmis-body [data-action="gm-islem"]').first();
    await expect(islemKart).toBeVisible();
    await islemKart.click();

    const panel = page.locator('.islem-detay-panel');
    await expect(panel).toBeVisible();
    const panelMetni = await panel.textContent();
    expect(panelMetni, 'panel metni ham kod içermemeli').not.toMatch(RAW_KOD);

    await panel.locator('button:has-text("Kapat")').click();
    await expect(panel).toHaveCount(0);
  });

  test('toplu gün (2026-09-13): katlı kart açılır — satırlar görünür ve tıklanabilir', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');
    await page.evaluate(iso => gecmisGunSec(iso), '2026-09-13');
    await expect(page.locator('#gecmis-body .gm-gun')).toHaveCount(1);

    // sahip ölçümü: 13.09'da toplu tedavi var → katlı grup en az 1
    const katliKart = page.locator('#gecmis-body [data-action="gm-kat-ac"]').first();
    await expect(katliKart).toBeVisible();
    await expect(katliKart).toContainText(/hayvan|kayıt/);

    const katId = await katliKart.getAttribute('data-kat');
    const icerik = page.locator(`[id="${katId}"]`);
    await expect(icerik).toBeHidden();

    await katliKart.click(); // aç
    await expect(icerik).toBeVisible();
    const satirSayi = await icerik.locator(':scope > .stok-item').count();
    expect(satirSayi).toBeGreaterThanOrEqual(3);
    // her satır tıklanabilir (data-action'lı)
    const hedefsizSatir = await icerik.locator(':scope > .stok-item:not([data-action])').count();
    expect(hedefsizSatir).toBe(0);

    // satırdan biri → kendi detayına gider (islem satırı → detay paneli)
    const islemSatir = icerik.locator(':scope > .stok-item[data-action="gm-islem"]').first();
    if (await islemSatir.count()) {
      await islemSatir.click();
      await expect(page.locator('.islem-detay-panel')).toBeVisible();
      await page.locator('.islem-detay-panel button:has-text("Kapat")').click();
    }

    await katliKart.click(); // kapa
    await expect(icerik).toBeHidden();
  });

  test('çipler: Tümü sayısı gün toplamı, kategori filtresi toggle, mobil sarma', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');
    await page.evaluate(iso => gecmisGunSec(iso), '2026-09-06');
    await expect(page.locator('#gecmis-gun-cipler .gm-cip')).toBeVisible();

    // Tümü çipi = günün toplam olay sayısı (dedup sonrası — banner ile aynı kaynak)
    const tumu = page.locator('#gecmis-gun-cipler .gm-cip').first();
    await expect(tumu).toContainText(/^Tümü \(\d+\)$/);

    // ilk kategori çipine tıkla → filtre ETKİN (state + yapısal sayı eşliği)
    const kip = page.locator('#gecmis-gun-cipler .gm-cip').nth(1);
    const kat = await kip.getAttribute('data-kat');
    await kip.click();
    expect(await page.evaluate(() => _gecmisGunCip)).toBe(kat);
    const olcum = await page.evaluate(async () => {
      const sources = await _gecmisCollectSources();
      const gunluk = _gmGunEntriesFromSources(sources).filter(e => e.olayGunu === _gecmisGun);
      const suzulen = gunluk.filter(e => e.category === _gecmisGunCip);
      const grup = _gmGunKatla(suzulen).filter(d => d.grup).length;
      const kart = document.querySelectorAll('#gecmis-body .stok-item').length;
      return { beklenen: suzulen.length + grup, kart };
    });
    expect(olcum.kart).toBe(olcum.beklenen);

    // tekrar tık → filtre kalkar; Tümü çipi de filtresiz duruma getirir
    await kip.click();
    expect(await page.evaluate(() => _gecmisGunCip)).toBe(null);
    await tumu.click();
    expect(await page.evaluate(() => _gecmisGunCip)).toBe(null);

    // mobil (390px): çipler sarılır — en az iki ayrı satır (offsetTop farkı)
    const sarilma = await page.evaluate(() => {
      const cipler = [...document.querySelectorAll('#gecmis-gun-cipler .gm-cip')];
      const ustler = new Set(cipler.map(c => Math.round(c.getBoundingClientRect().top)));
      return { adet: cipler.length, satir: ustler.size };
    });
    expect(sarilma.adet).toBeGreaterThanOrEqual(3);
    expect(sarilma.satir, '390px genişlikte çipler tek satıra sığmalı değil').toBeGreaterThanOrEqual(2);
  });
});
