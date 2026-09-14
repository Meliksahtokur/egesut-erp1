// tests/degisiklikler-geri-alma.spec.js
// EgeSüt ERP — L4-W2 "tek geri-al motoru" e2e ayakları (STUB mod, zarf PW listesi).
//
// Koşum: PLAYWRIGHT_DEMO_MODE=1 + URL ?stub → js/degisiklikler/degisiklikler-stub.js
// aktif (window.DEGISIM_STUB=true); W1 RPC'leri canlıda olmadan deterministik akış.
//
// Kilitlenen sözleşmeler (zarf kabul ölçütleri):
//   S1 — tek giriş: Değişiklikler detay ve Geçmiş kartı aynı önizleme modalını açar.
//   S3 — zincir: çakışma → öneri butonu → zincir önizleme + TEK onay + TEK bilet
//        → "N olay birlikte geri alındı" + ⟲ kısayol.
//   S3b — rehber: sirali_rehber → sıra numaralı TEK TEK geri-al listesi.
//   S4 — ham UUID/tx görünmez; uygulama-dışı/teknik varsayılan gizli + çip.
//   Engel — ZAMAN_ESLESME_YOK insan dilli + yönlendirme butonu.

import { test, expect, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'stub savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

const HAM_UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;

async function bootStub(page) {
  await page.goto('./?stub', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#pg-dash .sv', { timeout: 30000 });
  await expect.poll(() => page.evaluate(() => window.DEGISIM_STUB === true), { timeout: 10000 }).toBe(true);
  await page.evaluate(() => degisikliklerAc());
  await expect(page.locator('#dg-root .dg-stub')).toBeVisible();
}

async function detayAc(page, baslik) {
  await page.locator('#dg-liste .dg-kart', { hasText: baslik }).first().click();
  await expect(page.locator('.dg-detay-bas .dg-baslik')).toHaveText(baslik);
}

test.describe('L4-W2 — tek geri-al motoru (stub)', () => {

  test('S4: liste — uygulama-dışı varsayılan gizli + çip; ham tx yok', async ({ page }) => {
    await bootStub(page);
    // uygulama-dışı kart (Toplu İlaç / harici-panel) varsayılan GİZLİ
    await expect(page.locator('#dg-liste .dg-kart', { hasText: 'Toplu İlaç' })).toHaveCount(0);
    const cip = page.locator('#dg-liste .gm-cip', { hasText: 'Uygulama dışı (1)' });
    await expect(cip).toBeVisible();
    // ham tx sayısı listede görünmez (detay teknik bloğunda katlı)
    const metin = await page.locator('#dg-liste').innerText();
    expect(metin).not.toMatch(/tx \d{5,}/);
    expect(metin).not.toMatch(HAM_UUID);
    // çip tık → gürültü görünür, sayaç yerinde
    await cip.click();
    await expect(page.locator('#dg-liste .dg-kart', { hasText: 'Toplu İlaç' })).toBeVisible();
    await expect(page.locator('#dg-liste .gm-cip', { hasText: 'Uygulama dışı (1) ✕' })).toBeVisible();
  });

  test('S1+S4: detay — teknikal satır gizli + çip; işlemi geri al → AYNI önizleme modalı', async ({ page }) => {
    await bootStub(page);
    await detayAc(page, 'Görev Tamamlandı');
    // teknikal satır (stok_hareket) varsayılan gizli; "Teknik (1)" çipi görünür
    await expect(page.locator('.dg-satir-kart', { hasText: 'Stok hareketi' })).toHaveCount(0);
    await expect(page.locator('.gm-cip', { hasText: 'Teknik (1)' })).toBeVisible();
    // boş değer satırı gizli (notlar: ''), öne çıkan alan sırası: gorev_tipi önce
    const kartMetin = await page.locator('.dg-satir-kart').first().innerText();
    expect(kartMetin).toContain('Görev tipi');
    expect(kartMetin).not.toContain('Notlar');
    // ham pk görünmez; teknik katlamada
    expect(kartMetin).not.toMatch(HAM_UUID);
    await expect(page.locator('.dg-teknik summary').first()).toContainText('Teknik ayrıntı');
    // Teknik çipi AÇ → teknikal satır görünür (L4-W2 review-4: çip tık dikişi)
    await page.locator('.gm-cip', { hasText: 'Teknik (1)' }).click();
    await expect(page.locator('.dg-satir-kart', { hasText: 'Stok hareketi' })).toHaveCount(1);
    // tek giriş: işlem düğmesi → önizleme modalı (bilet YOK — ayrı adım)
    await page.locator('.dg-detay-bas .dg-geri').first().click();
    await expect(page.locator('#m-dg-onizle.on')).toBeVisible();
    await expect(page.locator('#dg-onizle-baslik')).toContainText('↩ İşlemi geri al');
    await expect(page.locator('#dg-onizle-govde')).toContainText('Görev kaydı silinecek');
    await expect(page.locator('#dg-onizle-onay')).toBeEnabled();
    // Vazgeç → detaya dönüş → detayın KENDİ satır düğmesi HÂLÂ çalışır
    // (L4-W2 review-4: token ayrımı dikişi — önizleme detay tokenlarını bozamaz)
    await page.locator('[data-action="dg-onizle-kapat"]').click();
    await expect(page.locator('#m-dg-onizle.on')).toHaveCount(0);
    await page.locator('.dg-satir-kart .dg-geri').first().click();
    await expect(page.locator('#m-dg-onizle.on')).toBeVisible();
    await expect(page.locator('#dg-onizle-onay')).toBeEnabled();
  });

  test('S3: zincir — çakışma önerisi → zincir önizleme → TEK onay → "3 olay birlikte geri alındı" + ⟲ kısayol', async ({ page }) => {
    await bootStub(page);
    await detayAc(page, 'Padok Güncellendi');
    await page.locator('.dg-satir-kart .dg-geri').first().click();
    // çakışma artık blok DEĞİL öneri (insan dilli liste + buton)
    await expect(page.locator('#m-dg-onizle.on')).toBeVisible();
    const oneri = page.locator('[data-test="dg-zincir-oneri"]');
    await expect(oneri).toContainText('Bu olaydan sonra 2 değişiklik daha var');
    await expect(oneri).toContainText('13.09.2026 16:10');
    await expect(oneri.locator('button', { hasText: 'Zincir olarak geri al — 2 olay birlikte' })).toBeVisible();
    // onay bu aşamada kapalı (öneri yolu)
    await expect(page.locator('#dg-onizle-onay')).toBeDisabled();
    // zincir önizleme: kart listesi + bağımlı işaret + onay cümlesi
    await oneri.locator('button', { hasText: 'Zincir olarak geri al' }).click();
    await expect(page.locator('#dg-onizle-baslik')).toContainText('🔗 Zincir geri al');
    await expect(page.locator('[data-test="dg-zincir-cumle"]')).toContainText('3 olay sıralıdır, komple geri alınacak. Onaylıyor musunuz?');
    await expect(page.locator('#dg-onizle-govde')).toContainText('bağımlı adım');
    await expect(page.locator('#dg-onizle-onay')).toBeEnabled();
    // TEK onay → bilet (stub) → TEK uygulama
    await page.locator('#dg-onizle-onay').click();
    await expect(page.locator('#m-dg-bilet.on')).toBeVisible();
    await page.fill('#dg-sifre', 'demo2026');
    await page.locator('#dg-bilet-al-btn').click();
    await expect(page.locator('[data-test="dg-sonuc"]')).toContainText('3 olay birlikte geri alındı');
    await expect(page.locator('[data-test="dg-sonuc"] button', { hasText: 'Geri alınanı geri al' })).toBeVisible();
    // ⟲ kısayol: geri alma tx'i yeni hedef olarak açılır
    await page.locator('[data-test="dg-sonuc"] button', { hasText: 'Geri alınanı geri al' }).click();
    await expect(page.locator('#dg-onizle-baslik')).toContainText('Geri alma işlemi');
  });

  test('S3b: sıralı rehber — çıkımaz yok, her satırın kendi geri-al düğmesi', async ({ page }) => {
    await bootStub(page);
    await detayAc(page, 'Tohumlama');
    await page.locator('.dg-detay-bas .dg-geri').first().click();
    const rehber = page.locator('[data-test="dg-rehber"]');
    await expect(rehber).toContainText('şu sırayla TEK TEK geri al');
    const metin = await rehber.innerText();
    // en yeni önce + sıra numaraları
    expect(metin).toContain('1. önce');
    expect(metin).toContain('Doğum kaydı');
    expect(metin).toContain('2. önce');
    expect(metin).toContain('Tohumlama sonucu (Gebe)');
    expect(metin).toContain('3.');
    expect(metin).toContain('Tohumlama kaydı');
    await expect(rehber.locator('button[data-action="dg-rehber-geri-al"]')).toHaveCount(3);
    // satır düğmesi KENDİ hedefini açar (tekil tx önizlemesi; geri_alinabilir true)
    await rehber.locator('button[data-action="dg-rehber-geri-al"]').first().click();
    await expect(page.locator('#dg-onizle-baslik')).toContainText('Doğum kaydı');
    await expect(page.locator('#dg-onizle-onay')).toBeEnabled();
    await expect(page.locator('#dg-onizle-govde')).toContainText('Kayıt önceki sürümüne dönecek');
  });

  test('Engel: ZAMAN_ESLESME_YOK → insan dilli + Değişiklikler yönlendirme', async ({ page }) => {
    await bootStub(page);
    await detayAc(page, 'Hayvan Güncellendi');
    await page.locator('.dg-detay-bas .dg-geri').first().click();
    await expect(page.locator('#dg-onizle-engel')).toBeVisible();
    await expect(page.locator('#dg-onizle-engel')).toContainText('kayıtla eşleşemedi');
    await expect(page.locator('#dg-onizle-engel button', { hasText: "Değişiklikler'den seç" })).toBeVisible();
    await expect(page.locator('#dg-onizle-onay')).toBeDisabled();
  });
});
