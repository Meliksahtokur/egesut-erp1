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
// TG1-W3 (luna revizyonu):
//   F5 — DÜN oracle'ı dAgo(1) (ürün handler'ıyla AYNI doğru ifade; eski
//        dAgo(bugun(),1) NaN-NaN-NaN üretiyordu ve self-confirming'ti).
//   F6 — "en zengin gün" sayısı artık ÜRÜN PIPELINE'INDAN türetilmez: statik
//        fixture (aşağıda, ölçüm kaynağıyla belgelendi). Pipeline/dedup/pull
//        hatası bu beklentiyi GEÇEMEZ.
//   F7 — veri-bağımlı skip KALDIRILDI: fixture günü demo verisinde garantili
//        (ölçüldü); test gerçekten KOŞAR.
//   F9 — hayvan kartı geçmiş yüzeyinde de aynı tarih şeridi/gün filtresi.
//
// Veri disiplini: yalnız OKUMA — form submit YOK, DB yazımı YOK.
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

// ── F6: STATİK FİXTURE — self-oracle YASAK ─────────────────────────────
// Ölçüm (2026-09-14): demo projesinden (vtzqjmazsvurxdeondmi) REST ile
// uygulamanın çektiği yüzeylerin (hayvan_durum_view, v_gorev_log_sync,
// stok_tuketim_view, düz tablolar) tam dökümü + düzeltilmiş
// _gmGunEntriesFromSources (worktree js/gecmis.js) koşumu. Bu toplama
// ulaşmak için F10 (islem_log TAM pull'u — eski 100-satır cap'i altında o
// günün 107 islem satırından ~7'si bile gelmezdi) VE dedup (21 VAKA_ACILDI
// aynası ref+gün eşleşmesiyle baskılanır) GEREKLİDİR — sayı her ikisinin
// de canlı kanıtıdır. Demo verisi yeniden klonlanırsa bu fixture bilinçli
// olarak kırmızıya düşer (yeniden ölçüm gerekir).
const FIXTURE_GUN = {
  gun: '2026-09-06',
  toplam: 266, // dedup SONRASI (render cap 300 altında → kart sayısı = toplam)
  // Kaynak dağılımı (ölçüm kaydı — DOM'dan sayılmaz, teşhis içindir):
  //   islem_log 107 · stok_hareket 127 · gorev_log 11 · cases 21
  metinler: ['Klinik Mastit', 'Klavil (vilsan)', 'Enrolen', 'Gun 1 tedavisi'],
};

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

  test('fixture günü: banner/kart sayısı STATİK beklentiyle eşit, kaynak temsil metinleri render (luna F6/F7)', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');

    // seçim UI katmanından (eski aylara takvim sayfalaması yerine tek nokta:
    // gecmisGunSec — handlers.js'teki butonların çağırdığı aynı kapı)
    await page.evaluate(iso => gecmisGunSec(iso), FIXTURE_GUN.gun);

    // U1: tab-girişi pull yarışı — skipPull render, tam-pull'un IDB clear+put
    // penceresine denk gelirse "0 olay" ara-render görür; final kanıtın veriye
    // KONVERJE olmasını bekle (statik oracle aşağıda aynen korunur)
    await expect.poll(async () => page.evaluate(() => _gecmisGunSayi),
      { timeout: 30000, intervals: [500, 1000, 2500] }).toBeGreaterThan(0);

    await expect(banner(page)).toBeVisible();
    await expect(banner(page)).toContainText(`${FIXTURE_GUN.toplam} olay`);
    await expect(page.locator('#gecmis-body .gm-gun')).toHaveCount(1);

    // U1 katlama: banner OLAY sayısı sabit fixture'a eşit kalır (katlama render
    // gruplamasıdır — pipeline'ı değiştirmez). DOM kart sayısı = olay toplamı +
    // katlı grup sayısı (grup kartı 1 kart, içindeki üye kartlar DOM'da durur).
    const olcum = await page.evaluate(async () => {
      const sources = await _gecmisCollectSources();
      const gunluk = _gmGunEntriesFromSources(sources).filter(e => e.olayGunu === _gecmisGun);
      const dugumler = _gmGunKatla(gunluk);
      const grup = dugumler.filter(d => d.grup).length;
      const kart = document.querySelectorAll('#gecmis-body .stok-item').length;
      return { olay: gunluk.length, grup, kart };
    });
    expect(olcum.olay).toBe(FIXTURE_GUN.toplam); // dedup sonrası toplam (cap 300 altı)
    expect(olcum.kart).toBe(FIXTURE_GUN.toplam + olcum.grup); // katlı kart + üye kartlar

    // kaynak/kategori temsil metinleri: vaka (Klinik Mastit), stok (ürün
    // adları), görev (TEDAVI_GUN etiketi) — statik ölçümden
    for (const metin of FIXTURE_GUN.metinler) {
      await expect(page.locator('#gecmis-body')).toContainText(metin);
    }

    // todayKey sözleşmesi: fixture günü bugün DEĞİL → etiket BUGÜN olamaz
    const etiket = await page.locator('#gecmis-body .gm-gun summary').innerText();
    expect(etiket, 'seçili gün todayKey olamaz — gerçek etiket: ' + etiket).not.toContain('BUGÜN');
  });

  test('Dün hızlı girişi: grup etiketi DÜN (gerçek bugünden türetilir — luna F5)', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');

    await page.click('[data-action="gecmis-gun-dun"]');
    await expect(banner(page)).toBeVisible();

    // oracle ürünün DOĞRU ifadesiyle (dAgo yalnız gün sayısı alır) — eskiden
    // test, handler'daki hatalı dAgo(bugun(),1) ifadesini tekrarlıyordu
    const dun = await page.evaluate(() => dAgo(1));
    expect(await page.evaluate(() => _gecmisGun)).toBe(dun);

    // olay varsa grup etiketi DÜN'dür (todayKey gerçek bugün — sözleşme md.4);
    // dallan bir veri-varlık koşuludur, beklenti oracle'ı değildir
    const counts = await page.evaluate(async () => {
      const sources = await _gecmisCollectSources();
      const all = _gmGunEntriesFromSources(sources);
      const c = {};
      all.forEach(e => { c[e.olayGunu] = (c[e.olayGunu] || 0) + 1; });
      return c;
    });
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

  test('hayvan kartı geçmişi: aynı tarih şeridi + gün filtresi (luna F9)', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');

    // 002 küpeli hayvan (demo) — 2026-09-06'da 33 olayı var (ölçüm: 29 islem
    // + 4 vaka; stok hayvansız olduğundan hayvan kapsamına girmez).
    // Taze context: boot pull'u F10'un sayfalı tam islem_log çekimi arkasında
    // toplu commit eder (~5-6 sn; ölçüldü) — openDet hayvanları IDB'den okuduğu
    // için senkron bitmesini bekleriz. waitForFunction async predicate ile
    // vaat-nesnesine anında true der (ölçüldü) → expect.poll kullanılır; her
    // örnek gerçekten await edilir.
    await expect.poll(async () => page.evaluate(async () => (await idbGetAll('hayvanlar')).length),
      { timeout: 25000 }).toBeGreaterThan(0);
    await page.evaluate(id => openDet(id), '17a7040c-68a1-4dc9-88ee-db67ac083397');
    await expect(page.locator('#det')).toBeVisible();
    await page.click('[data-action="tab-gecmis"]'); // det modal Geçmiş sekmesi

    const strip = page.locator('[data-action="gecmis-det-tarihe-git"]');
    await expect(strip).toBeVisible();
    await expect(page.locator('[data-action="gecmis-det-gun-bugun"]')).toBeVisible();
    await expect(page.locator('[data-action="gecmis-det-gun-dun"]')).toBeVisible();

    // Bugün → kart banner'ı görünür (0 olay da meşru banner metnidir)
    await page.click('[data-action="gecmis-det-gun-bugun"]');
    const detBanner = page.locator('#det-gecmis-gun-banner');
    await expect(detBanner).toBeVisible();
    await expect(detBanner).toContainText(/olay/);

    // ölçülmüş gün → sabit sayı (hayvan kapsamlı gün hattı)
    await page.evaluate(iso => gecmisDetGunSec(iso), '2026-09-06');
    await expect(detBanner).toContainText('33 olay');
    const kartlar = await page.locator('#det-gecmis-body .stok-item').count();
    expect(kartlar).toBe(33);

    // ✕ Kapat → kartın defter görünümü döner, banner gizli
    await page.click('[data-action="gecmis-det-gun-kapat"]');
    await expect(detBanner).toBeHidden();
    expect(await page.evaluate(() => _detGecmisGun)).toBe(null);
  });
});
