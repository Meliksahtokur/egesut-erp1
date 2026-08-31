// tests/kritik-akis.spec.js
// EgeSüt ERP — Kritik akış savunma hattı (Idle-B, 2026-09-01)
//
// Kilitlediği fix'ler:
//   B20 (commit 0785bc9) — Dashboard "Gebe ›" kartı: showGebe artık doğrudan
//        renderAnimals çağırıp 250ms sonra debounce'lu filterA'ya ezilmiyor;
//        chip state'i programatik seçilir (_fchip.gebelik='gebe'), render
//        filterA'ya bırakılır → gebe filtresi kalıcı.
//   Ayrıca regression kilidi: tohumlama→sonuç→gebe listesi zinciri ve
//   görev ekle→tamamla→geri al zinciri (gorev_tamamla/gorev_geri_al RPC'leri).
//
// Veri politikası: VERİ-AGNOSTIC — küpe/ürün adı varsayılmaz, listelerden
// dinamik seçilir (gerçek demo verisi her an değişebilir). Demo projesi izole
// klondur; yazmalar kullanıcı tarafından ONAYLI (IDLE-GOREV.md). Marker'lar
// E2E- öneklidir.

import { test, expect, openApp, navTo, toastText, gorevByMarker, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

// Bekleyen (Bekliyor) bir tohumlamayı UI üzerinden Gebe işaretler.
// Dönüş: işaretlenen hayvanın küpe etiketi | null (uygun kayıt yoksa → skip).
async function ilkBekliyoruGebeYap(page) {
  await navTo(page, '#nb-ureme');
  await page.click('#ureme-tab-tohumlama');
  await page.waitForSelector('#ureme-body .hist-row', { timeout: 10000 });
  await page.waitForTimeout(600); // liste IDB'den dolsun

  const bekliyor = page.locator('#ureme-body .hist-row', {
    has: page.locator('.hist-sub b', { hasText: 'Bekliyor' }),
  }).first();
  if (!(await bekliyor.count())) return null;

  const rowText = await bekliyor.innerText();
  const kupe = rowText.split('—')[0].trim();

  await bekliyor.click();
  await expect(page.locator('#m-toh-det')).toHaveClass(/on/);
  await expect(page.locator('#td2-sonuc-radios')).toBeVisible(); // yalnız Bekliyor'da görünür

  await page.check('input[name="toh-sonuc"][value="Gebe"]');
  await page.click('[data-action="toh-sonuc-kaydet"]');
  await expect.poll(() => toastText(page), { timeout: 15000 }).toContain('Gebe olarak işaretlendi');
  await expect(page.locator('#m-toh-det')).not.toHaveClass(/on/);
  return kupe;
}

// ═════════════════════════════════════════════════════════════════════════════
// Akış 1 — tohumlama (Bekliyor) → sonuç Gebe → gebe listesinde görünür
// ═════════════════════════════════════════════════════════════════════════════

test('tohumlama sonucu Gebe işaretlenir → gebelik listesine düşer', async ({ page }) => {
  await openApp(page);
  const kupe = await ilkBekliyoruGebeYap(page);
  test.skip(!kupe, 'veride Bekliyor tohumlama kaydı yok (veri-agnostic skip)');

  // Gebelik sekmesi: işaretlenen hayvanın küpesi listede
  await page.click('#ureme-tab-gebelik');
  await expect
    .poll(async () => (await page.locator('#ureme-body').innerText()).includes(kupe), { timeout: 10000 })
    .toBe(true);
});

// ═════════════════════════════════════════════════════════════════════════════
// B20 — "Gebe ›" dashboard kartı: chip 250ms debounce sonrası da ezilmiyor
// ═════════════════════════════════════════════════════════════════════════════

test('B20: "Gebe ›" kartı → gebe chip ve filtresi debounce sonrası da korunur', async ({ page }) => {
  await openApp(page);

  // Önkoşul: en az bir gebe hayvan (yoksa UI üzerinden bir tane işaretle)
  let gebeSayi = await page.evaluate(() => (new Set(getState('gebeIds') || [])).size);
  if (!gebeSayi) {
    const kupe = await ilkBekliyoruGebeYap(page);
    test.skip(!kupe, 'gebe hayvan yok + işaretlenecek Bekliyor kayıt yok');
    await expect
      .poll(async () => (await page.evaluate(() => (new Set(getState('gebeIds') || [])).size)), { timeout: 15000 })
      .toBeGreaterThan(0);
  }

  // Dashboard "Gebe ›" kartına tıkla (.sc.ok'lerin İLKİ "Aktif Hayvan" —
  // etiketle hedefle, sıraya güvenme)
  await page.locator('.sc.ok').filter({ hasText: 'Gebe ›' }).click();
  await expect(page.locator('#pg-suru')).toHaveClass(/on/);

  // 250ms debounce + render geçtikten SONRA hâlâ gebe filtresi ayakta olmalı.
  // (B20 öncesi: direkt render ~250ms sonra fchipReset'li filterA tarafından
  // eziliyor, chip sönüp tüm sürü geliyordu.)
  await page.waitForTimeout(700);
  await expect(page.locator('#fc-gebelik-gebe')).toHaveClass(/on/);
  expect(await page.evaluate(() => _fchip.gebelik)).toBe('gebe');

  const { beklenen, toplam } = await page.evaluate(() => {
    const g = new Set(getState('gebeIds') || []);
    const hayvanlar = getState('animals') || [];
    return {
      beklenen: hayvanlar.filter(a => g.has(a.id)).length,
      toplam: hayvanlar.length,
    };
  });
  const kartSayisi = await page.locator('.animal-card').count();
  expect(kartSayisi, `gebe kart sayısı (beklenen ${beklenen}, toplam sürü ${toplam})`).toBe(beklenen);
});

// ═════════════════════════════════════════════════════════════════════════════
// Akış 2 — görev ekle → tamamla → geri al (+ filtre chip davranışı)
// ═════════════════════════════════════════════════════════════════════════════

test('görev ekle → tamamla → geri al; filtre chip doğru state\'te', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-tasks');

  const MARKER = `E2E-IDLE-B-GOREV-${Date.now()}`;
  const bugunStr = await page.evaluate(() => bugun());

  // ── EKLE ──
  await page.click('[data-action="open-task-add-modal"]');
  await expect(page.locator('#m-task-add')).toHaveClass(/on/);
  await page.fill('#ta-desc', MARKER);
  await page.fill('#ta-tarih', bugunStr); // GENEL görev — hayvan alanı boş (veri-agnostic)
  await page.click('[data-action="submit-task-add"]');
  await expect.poll(() => toastText(page), { timeout: 15000 }).toContain('Görev oluşturuldu');
  await expect(page.locator('#m-task-add')).not.toHaveClass(/on/);

  // Bugün filtresi chip aktif ve yeni görev listede
  const kart = page.locator('#pg-tasks .task-card', { hasText: MARKER }).first();
  await expect(kart).toBeVisible({ timeout: 10000 });
  await expect(page.locator('[data-action="tasks-today"]')).toHaveClass(/on/);

  // Bekleyen filtresi: bugünün görevi "bekleyen" (ileri tarih) penceresinde
  // değildir — chip değişir, kart bu filtrede listelenmez (bilinçli davranış)
  await page.click('[data-action="tasks-all"]');
  await expect(page.locator('[data-action="tasks-all"]')).toHaveClass(/on/);
  await page.waitForTimeout(400);

  // ── TAMAMLA ── (önce Bugün'e dön)
  await page.click('[data-action="tasks-today"]');
  await expect(kart).toBeVisible({ timeout: 10000 });
  await kart.click();
  await expect(page.locator('#m-task-det')).toHaveClass(/on/);
  await page.click('#td-tamam-btn');
  await expect.poll(() => toastText(page), { timeout: 20000 }).toContain('Tamamlandı');
  await expect(page.locator('#m-task-det')).not.toHaveClass(/on/);
  await page.waitForTimeout(800); // kart DOM'dan düşsün (320ms animasyon + reload)

  // Tamamlanan filtresi chip + kart orada
  await page.click('[data-action="tasks-done"]');
  await expect(page.locator('[data-action="tasks-done"]')).toHaveClass(/on/);
  const doneKart = page.locator('#pg-tasks .task-card', { hasText: MARKER }).first();
  await expect(doneKart).toBeVisible({ timeout: 10000 });

  // ── GERİ AL ── (done detay → confirm → gorev_geri_al)
  await doneKart.click();
  await expect(page.locator('#m-done-det')).toHaveClass(/on/);
  const geriBtn = page.locator('#dd-geri-al-btn');
  await expect(geriBtn).toBeEnabled();
  await geriBtn.click();
  await expect(page.locator('#m-confirm')).toHaveClass(/on/);
  await page.click('#m-confirm-ok');
  await expect.poll(() => toastText(page), { timeout: 20000 }).toContain('geri alındı');

  // DB doğrulaması: görev geri açıldı — tamamlandi=false
  // (gerçek mod: demo projesinden SELECT; stub modu: RPC handler'ın mutasyonu)
  await expect.poll(async () => (await gorevByMarker(MARKER))?.tamamlandi, { timeout: 20000 }).toBe(false);
});
