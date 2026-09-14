// tests/geri-alma-w3-nav.spec.js
// EgeSüt ERP — L4-W3 gezinme: hapsolmama + takvim işaretli günleri (S5 + S6).
//
// Kilitlenen sözleşmeler (zarf L4-W3 md.A/B; plan raporu §1g/§6/§8 S5+S6):
//   1. Takvim (#tek-tarih-takvim) history'de — tarayıcı geri TAKVİMİ KAPATIR,
//      sayfa değişmez (S5).
//   2. Gün görünümü (ana + hayvan kartı) history'de — geri görünümden deftere/
//      karta döner; banner ✕ Kapat aynen çalışır; det-back deseni korunur (S5).
//   3. Değişiklikler tx detayı history'de — geri detayı kapatır, listeye döner (S5).
//   4. ESC en üst router-modalı (takvim dahil) kapatır; autocomplete paneli
//      açıkken ESC paneli kapatır, modal kapanmaz (çakışma YOK).
//   5. pg-degisiklikler + pg-asistan başlığında "← Geri" önceki sayfaya döner.
//   6. İşaretli günler: demo fixture günü 2026-09-06 (ölçülmüş — tarihe-git
//      spec FIXTURE_GUN ile aynı kaynak) takvimde nokta ile görünür; boş gün
//      noktasız/beyaz; takvim açılışında YENİ AĞ İSTEĞİ YOK (IDB yansıması).
//   7. L4-08 (onarım turu): önizleme modalı iç yeniden-açılışı (zincir önerisi/
//      ⟲ → 2. openM) YENİ history entry EKLEMEZ; Vazgeç tek back ile temiz döner,
//      sonraki geri altındaki görünümü kapatır (açık modal başına TEK entry).
//
// Koşum: PLAYWRIGHT_DEMO_MODE=1 (Docker); tx-detay testleri ?stub ile (W2 deseni).
// Veri disiplini: yalnız OKUMA — form submit YOK, DB yazımı YOK.

import { test, expect, openApp, navTo, goOffline, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

test.use({
  locale: 'en-US',
  viewport: { width: 412, height: 915 },
  hasTouch: true,
  isMobile: true,
});

const takvim = page => page.locator('#tek-tarih-takvim');
const banner = page => page.locator('#gecmis-gun-banner');
const detBanner = page => page.locator('#det-gecmis-gun-banner');
// tarihe-git.spec.js FIXTURE_GUN ile aynı ölçümlü demo günü (2026-09-14 ölçümü)
const FIXTURE_GUN = '2026-09-06';
const KART_HAYVAN = '17a7040c-68a1-4dc9-88ee-db67ac083397'; // 002 küpeli (demo)

async function takvimiAcBugunSec(page) {
  await page.click('[data-action="gecmis-tarihe-git"]');
  await expect(takvim(page)).toBeVisible();
  await page.click('#tek-tarih-takvim button:has-text("Onayla")');
  await expect(takvim(page)).toHaveCount(0);
  await expect(banner(page)).toBeVisible();
}

// ── S5: hapsolmama — her geri TUŞU bir seviye yukarı kapatır ─────────

test('S5a: takvim açıkken tarayıcı geri → takvim KAPANIR, sayfa değişmez', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-gecmis');
  await page.click('[data-action="gecmis-tarihe-git"]');
  await expect(takvim(page)).toBeVisible();

  await page.goBack();

  await expect(takvim(page)).toHaveCount(0, 'takvim kapanmalı');
  await expect(page.locator('#pg-gecmis.on')).toBeVisible('sayfa AYNI kalmalı');
  await expect(banner(page)).toBeHidden('gün görünümü açılmamalı — yalnız takvim kapandı');
});

test('S5b: gün görünümü açıkken geri → deftere döner, sayfa değişmez (continuation kanıtı)', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-gecmis');
  await takvimiAcBugunSec(page);

  await page.goBack();

  await expect(banner(page)).toBeHidden('gün görünümü kapanmalı');
  await expect(page.locator('#pg-gecmis.on')).toBeVisible('sayfa AYNI kalmalı');
  // continuation: onSec back-traversal'dan SONRA koşar — takvim entry'si sızmadı
  // (sızsaydı bu İLK goBack hiçbir şey yapmazdı)
  await expect(page.evaluate(() => _gecmisGun)).resolves.toBe(null);
});

test('S5b-✕: banner "✕ Kapat" aynen çalışır VE history\'yi temizler', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-gecmis');
  await takvimiAcBugunSec(page);

  await page.click('[data-action="gecmis-gun-kapat"]');
  await expect(banner(page)).toBeHidden();

  // ✕ sonrası GERİ: bir sonraki sayfa-entry'sine temiz dönmeli (gün görünümü
  // yeniden açILMAMALI — navViewBack entry'yi sildi)
  await page.goBack();
  await expect(banner(page)).toBeHidden('history temiz — geri gün görünümünü geri getirmez');
  await expect(page.locator('.pg.on')).toHaveCount(1);
});

test('S5c: kart-içi gün görünümü geri → karta döner (det-back deseni korunur)', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-gecmis');
  await expect.poll(async () => page.evaluate(async () => (await idbGetAll('hayvanlar')).length),
    { timeout: 25000 }).toBeGreaterThan(0);
  await page.evaluate(id => openDet(id), KART_HAYVAN);
  await expect(page.locator('#det')).toBeVisible();
  await page.click('[data-action="tab-gecmis"]');

  await page.click('[data-action="gecmis-det-tarihe-git"]');
  await expect(takvim(page)).toBeVisible();
  await page.click('#tek-tarih-takvim button:has-text("Onayla")');
  await expect(takvim(page)).toHaveCount(0);
  await expect(detBanner(page)).toBeVisible();

  await page.goBack();

  await expect(detBanner(page)).toBeHidden('kart-içi gün kapanmalı');
  await expect(page.locator('#det')).toBeVisible('KART AÇIK KALIR — det-back deseni');
  // ikinci geri: kart kapanır (mevcut desen — closeDet 'on' classını düşürür;
  // #det fixed+transform deseni olduğundan görünürlük = 'on' class'ı)
  await page.goBack();
  await expect.poll(async () => page.evaluate(() => document.getElementById('det').classList.contains('on')),
    { timeout: 5000 }).toBe(false, 'kart kapandı');
  await expect(page.locator('#pg-gecmis.on')).toBeVisible('geçmiş sayfasındayız');
  await expect(banner(page)).toBeHidden();
});

test('S5d: Değişiklikler tx detayı geri → liste görünümü (gerçek RPC)', async ({ page }) => {
  // Entegrasyon sonrası stub SÖKÜLDÜ (2026-09-14) — gerçek degisim_listele ile.
  await openApp(page);
  await page.evaluate(() => degisikliklerAc());
  await page.waitForSelector('#dg-liste .dg-sayac, #dg-liste .dg-kart', { timeout: 30000 });
  if ((await page.locator('#dg-liste .dg-kart').count()) === 0) {
    await page.locator('.gm-cip', { hasText: 'Uygulama dışı' }).first().click();
    await page.waitForSelector('#dg-liste .dg-kart', { timeout: 15000 });
  }
  await expect(page.locator('#dg-root .dg-stub')).toHaveCount(0, 'stub yok — gerçek RPC');

  await page.locator('#dg-liste .dg-kart').first().click();
  await expect(page.locator('.dg-detay-bas .dg-baslik')).toBeVisible('detay açıldı');
  await expect(page.locator('[data-action="dg-liste-don"]')).toBeVisible();

  await page.goBack();

  await expect(page.locator('[data-action="dg-liste-don"]')).toHaveCount(0, 'detay kapandı');
  await expect(page.locator('#dg-liste .dg-kart').first()).toBeVisible('liste görünümü');
  await expect(page.locator('#pg-degisiklikler.on')).toBeVisible('sayfa AYNI kalmalı');
});

test('S5e: ESC — takvimi kapatır; autocomplete paneli açıkken modal KALIR', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-gecmis');
  await page.click('[data-action="gecmis-tarihe-git"]');
  await expect(takvim(page)).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(takvim(page)).toHaveCount(0, 'ESC takvimi kapatır');

  // Modal + autocomplete çakışması: görev ekle modalı (ta-hid → ac-tahid paneli)
  await page.evaluate(() => openMWithHayvan('m-task-add', 'ta-hid', '002'));
  await expect(page.locator('#m-task-add.on')).toBeVisible();
  await page.fill('#ta-hid', '0');
  await expect.poll(async () => page.evaluate(() => {
    const p = document.getElementById('ac-tahid');
    return p ? p.style.display !== 'none' : false;
  }), { timeout: 8000 }).toBe(true);

  await page.keyboard.press('Escape'); // 1. ESC: yalnız panel kapansın
  await expect.poll(async () => page.evaluate(() => {
    const p = document.getElementById('ac-tahid');
    return p ? p.style.display !== 'none' : true;
  }), { timeout: 4000 }).toBe(false);
  await expect(page.locator('#m-task-add.on')).toBeVisible('modal AÇIK kalmalı — çakışma YOK');

  await page.keyboard.press('Escape'); // 2. ESC: panel kapalı — modal kapanır
  await expect(page.locator('#m-task-add.on')).toHaveCount(0);

  // review senaryosu: panel açık AMA odak başka yerde (dış-tık gizleme
  // listesinde olmayan ac-tahid paneli açık kalır) — ESC yine işlevsel olmalı:
  // 1. ESC paneli kapatır, 2. ESC modalı
  await page.evaluate(() => openMWithHayvan('m-task-add', 'ta-hid', '002'));
  await expect(page.locator('#m-task-add.on')).toBeVisible();
  await page.fill('#ta-hid', '0');
  await expect.poll(async () => page.evaluate(() => {
    const p = document.getElementById('ac-tahid');
    return p ? p.style.display !== 'none' : false;
  }), { timeout: 8000 }).toBe(true);
  await page.evaluate(() => document.activeElement?.blur());
  await page.keyboard.press('Escape'); // 1. ESC (odak-dışı): panel kapanır
  await expect.poll(async () => page.evaluate(() => {
    const p = document.getElementById('ac-tahid');
    return p ? p.style.display !== 'none' : true;
  }), { timeout: 4000 }).toBe(false, 'panel kapandı');
  await expect(page.locator('#m-task-add.on')).toBeVisible('modal hâlâ açık');
  await page.keyboard.press('Escape'); // 2. ESC: modal kapanır
  await expect(page.locator('#m-task-add.on')).toHaveCount(0);
});

test('S5f: başlık "← Geri" — asistan ve Değişiklikler önceki sayfaya döner', async ({ page }) => {
  await openApp(page);
  // asistan girişi mobil viewport'ta üst-bar butonu gizli — goTo ile açılır
  // (nb şeridinde asistan düğmesi yok; ürün mevcut giriş yolları aynen korunur)
  await page.evaluate(() => goTo('asistan'));
  await expect(page.locator('#pg-asistan.on')).toBeVisible();
  await expect(page.locator('#pg-asistan .btn[data-action="nav-geri"]')).toBeVisible();
  await page.click('#pg-asistan .btn[data-action="nav-geri"]');
  await expect(page.locator('#pg-dash.on')).toBeVisible('asistan → dash');

  await page.goto('./?stub', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#pg-dash .sv', { timeout: 30000 });
  await page.evaluate(() => degisikliklerAc());
  await expect(page.locator('#dg-root .dg-bas')).toBeVisible();
  await page.click('[data-action="nav-geri"]');
  await expect(page.locator('#pg-dash.on')).toBeVisible('değişiklikler → dash');
});

// ── L4-08 (onarım turu): önizleme modalı iç yeniden-açılışta TEK entry ──
// zincir önerisi/⟲ yolları dgOnizleGoster → openM('m-dg-onizle') İKİNCİ kez
// çağırır; guardsız push fazladan entry sızdırır, closeM tek back attığından
// S5 "tek geri" bozulurdu (luna L4-08).

test('S5-L4-08 (yapısal): modal iç yeniden-açılış TEK entry — Vazgeç sonrası tek geri altındaki görünümü kapatır', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => degisikliklerAc());
  await page.waitForSelector('#dg-root .dg-bas', { timeout: 30000 });

  // 1. açılış + iç yeniden-açılış (zincir önerisi/⟲'nin openM çağrısı birebir)
  await page.evaluate(() => openM('m-dg-onizle'));
  const len1 = await page.evaluate(() => history.length);
  await page.evaluate(() => openM('m-dg-onizle'));
  const len2 = await page.evaluate(() => history.length);
  expect(len2, 'aynı-id ikinci openM history sızdırmaz (L4-08 invariant)').toBe(len1);

  // 2. Vazgeç (kapat yolu — closeM tek back) → tepede modal-entry KALMAZ
  await page.click('[data-action="dg-onizle-kapat"]');
  await expect(page.locator('#m-dg-onizle.on')).toHaveCount(0);
  await expect.poll(async () => page.evaluate(() => !!(history.state && history.state.modal)))
    .toBe(false, 'Vazgeç sonrası history tepesinde modal-entry kalmaz');

  // 3. TEK geri → modal DEĞİL, altındaki görünüm kapanır (degisiklikler → dash)
  await page.goBack();
  await expect(page.locator('#m-dg-onizle.on')).toHaveCount(0, 'modal geri gelmez — entry sızmadı');
  await expect(page.locator('#pg-degisiklikler.on')).toHaveCount(0, 'altındaki görünüm kapandı');
  await expect(page.locator('#pg-dash.on')).toBeVisible();
});

test('S3-L4-08 (gerçek akış): zincir önerisi iç yeniden-açılış TEK entry — Vazgeç temiz döner', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => degisikliklerAc());
  await page.waitForSelector('#dg-liste .dg-sayac, #dg-liste .dg-kart', { timeout: 30000 });
  if ((await page.locator('#dg-liste .dg-kart').count()) === 0) {
    await page.locator('#dg-liste .gm-cip, #dg-root .gm-cip', { hasText: 'Uygulama dışı' }).first().click();
    await page.waitForSelector('#dg-liste .dg-kart', { timeout: 15000 });
  }
  // Çakışma eski tx'lerin satırlarında olur (liste en yeni önce) — sondan tarama
  const kartlar = page.locator('#dg-liste .dg-kart');
  const toplam = await kartlar.count();
  const tarama = Math.min(toplam, 4);
  let bulundu = false;
  for (let i = tarama - 1; i >= 0 && !bulundu; i--) {
    await kartlar.nth(i).click();
    await page.waitForSelector('.dg-detay-bas', { timeout: 15000 });
    const btn = page.locator('.dg-satir-kart [data-action="dg-geri-al"]').first();
    if (!(await btn.count())) { await page.click('[data-action="dg-liste-don"]'); continue; }
    await btn.click();
    await page.waitForSelector('#m-dg-onizle.on', { timeout: 15000 });
    await page.waitForSelector('#dg-onizle-govde .dg-plan, #dg-onizle-govde .dg-not', { timeout: 15000 });
    if (await page.locator('[data-test="dg-zincir-oneri"]').count()) {
      bulundu = true;
      const len1 = await page.evaluate(() => history.length);
      await page.locator('[data-test="dg-zincir-oneri"] button').click();
      await page.waitForSelector('#dg-onizle-govde [data-test="dg-zincir-cumle"]', { timeout: 15000 });
      const len2 = await page.evaluate(() => history.length);
      expect(len2, 'zincir önizlemesi (2. openM) history sızdırmaz').toBe(len1);
    } else {
      await page.click('[data-action="dg-onizle-kapat"]');
      await page.waitForSelector('#m-dg-onizle', { state: 'hidden', timeout: 8000 });
      await page.click('[data-action="dg-liste-don"]');
    }
  }
  if (!bulundu) {
    test.skip(true, 'demo verisinde taranan tx\'lerde zincir-önerisi üreten çakışma yok — yapısal S5-L4-08 testi + lead yürüyüşü kapsar');
    return;
  }
  await page.click('[data-action="dg-onizle-kapat"]');
  await expect(page.locator('#m-dg-onizle.on')).toHaveCount(0);
  await expect.poll(async () => page.evaluate(() => !!(history.state && history.state.modal)))
    .toBe(false, 'Vazgeç sonrası history tepesinde modal-entry kalmaz (tek entry)');
  await page.goBack();
  await expect(page.locator('#m-dg-onizle.on')).toHaveCount(0, 'modal bir sonraki geriye gelmez');
});

// ── S6: takvim işaretli günler — boş gün beyaz, olaylı gün noktalı ────

test('S6a: ana Geçmiş takvimi — ÇEVRİMDIŞINDA bile işaretli (IDB yansıması; ek pull bağımlılığı YOK)', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-gecmis');
  await expect.poll(async () => page.evaluate(async () => (await idbGetAll('hayvanlar')).length),
    { timeout: 25000 }).toBeGreaterThan(0);

  // Zarf kabul 4'ün en güçlü kanıtı: ağ KAPALIYKEN takvim işaretli günleri
  // çizebiliyorsa işaretleme IDB yansımasından okunuyor demektir — ek RPC/pull
  // bağımlılığı YOK (çevrimiçi istek-zamanlaması ölçümü yarışlı olduğundan
  // bu yapısal kanıt seçildi; plan §6 çevrimdışı-kuyruk notu da burada doğar:
  // henüz sunucuya gitmemiş olay da cihazda işaretlenir).
  await goOffline(page);

  // IDB tam doluyken gün kümesini TAZE hesaplat (skipPull — üründe sekme
  // yeniden girişinde de koşan aynı yol; boot pull yarışını çıkartır)
  await page.evaluate(() => loadGecmis(null, null, { skipPull: true }));
  await expect.poll(async () => page.evaluate(gun => !!(_gecmisGunKumesi && _gecmisGunKumesi.has(gun)), FIXTURE_GUN),
    { timeout: 15000 }).toBe(true);

  await page.click('[data-action="gecmis-tarihe-git"]');
  await expect(takvim(page)).toBeVisible();

  const isaretli = page.locator('#tek-tarih-takvim [data-isaretli-gun]');
  expect(await isaretli.count()).toBeGreaterThan(0, 'demo verisinde olaylı gün var');
  await expect(page.locator(`#tek-tarih-takvim [data-isaretli-gun="${FIXTURE_GUN}"]`))
    .toHaveCount(1, 'ölçülmüş fixture günü işaretli');

  // boş gün beyaz: işaretsiz bir hücrede açık-amber zemin YOK, nokta YOK
  const bos = await page.evaluate(() => {
    const h = [...document.querySelectorAll('#tek-tarih-takvim div[onclick]')]
      .find(d => !d.querySelector('[data-isaretli-gun]'));
    if (!h) return null;
    return { zemin: h.style.background.includes('rgba(201,125,10'), nokta: !!h.querySelector('span') };
  });
  expect(bos).not.toBe(null);
  expect(bos.zemin).toBe(false);
  expect(bos.nokta).toBe(false);
});

test('S6b: kart takvimi — hayvan kapsamlı işaretli günler (002: 2026-09-06)', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-gecmis');
  await expect.poll(async () => page.evaluate(async () => (await idbGetAll('hayvanlar')).length),
    { timeout: 25000 }).toBeGreaterThan(0);
  await page.evaluate(id => openDet(id), KART_HAYVAN);
  await expect(page.locator('#det')).toBeVisible();
  await page.click('[data-action="tab-gecmis"]');

  await page.click('[data-action="gecmis-det-tarihe-git"]');
  await expect(takvim(page)).toBeVisible();
  await expect(page.locator(`#tek-tarih-takvim [data-isaretli-gun="${FIXTURE_GUN}"]`))
    .toHaveCount(1, 'kapsamlı küme — hayvanın olay günü işaretli');
});
