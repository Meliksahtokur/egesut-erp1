// tests/tarih-secici.spec.js
// EgeSüt ERP — F2 kanonik tarih seçici göcü (G-20260913-TARIH-SECICI).
//
// Kilitlediği davranış: native <input type="date"> yerine tarih alanları
// kanonik TR takvimi (tekTarihTakvimAc) açar. Tarayıcı/OS locale'i YÜZEYE
// sızmaz — en-US tarayıcıda bile ay adları Türkçe (TARIH_AY_ADLARI),
// biçim gg.aa.yyyy, saklanan değer ISO.
//
// RED-YEŞİL: taban commit'te (native input) bu spec KIRMIZIDIR — takvim
// modalı (#tek-tarih-takvim) hiç var olmaz ve input.type === 'date' olur.
// yeşil kanıt: #tek-tarih-takvim açılır + type !== 'date' + değer ISO.
//
// Veri disiplini: yalnız OKUMA — form submit YOK, DB yazımı YOK (demo
// modda bile). "Kaydedilen değer" = formun submit anında okuyacağı
// el.value sözleşmesi (ISO) alan düzeyinde doğrulanır (gece-tarih.spec
// konvansiyonuyla aynı ayak izi).
//
// Ortam: PLAYWRIGHT_DEMO_MODE=1 zorunlu (sahne demo-Mirror Supabase'e
// bağlanır; prod'a asla gidilmez — tests/support/app.js koşum modları).

import { test, expect, openApp, navTo, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

// Android-Firefox benzeri mobil yüzey + en-US locale — THREAT modeli tam bu:
// eski native input en-US Firefox/Android'de mm/dd/yyyy sistem takvimini
// açıyordu. Kanonik bileşen locale'den bağımsız Türkçe basmak zorunda.
test.use({
  locale: 'en-US',
  viewport: { width: 412, height: 915 },
  hasTouch: true,
  isMobile: true,
});

const TR_AYLAR = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

const takvim = page => page.locator('#tek-tarih-takvim');
const bugunIso = page => page.evaluate(() => bugun());

async function inputMeta(page, sel) {
  return page.evaluate(s => {
    const el = document.querySelector(s);
    return { type: el.type, value: el.value, raw: el.getAttribute('type') };
  }, sel);
}

// NOT: taşıyıcının runtime tipi yazıcı-uyumu için 'date'tir (bkz.
// tarihAlaniBagla yorumu); kaynak-düzeyi göç kanıtı grep kabulüdür
// (type="date" sayısı 0 — teslim raporunda) ve butonun varlığıdır:
// taban commit'te (#b-tarih-btn yok) bu spec kırmızıdır.

async function gunHucreTikla(page, iso) {
  // Hücreler onclick="tekTarihTakvimSec('ISO')" taşır; kapalı/aralık-dışı
  // günlerde onclick YOKTUR (F1). Yanlış-tarih seçimi testi uyarmalı.
  const hucre = page.locator(`#tek-tarih-takvim div[onclick*="${iso}"]`);
  await expect(hucre, `${iso} hücresi tıklanabilir olmalı`).toHaveCount(1);
  await hucre.click();
  await page.click('#tek-tarih-takvim button:has-text("Onayla")');
  await expect(takvim(page)).toHaveCount(0);
}

test.describe('F2 — kanonik tarih seçici (native date göcü)', () => {

  test('b-tarih (doğum): TR takvim açılır, bugün seçilir, değer ISO', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await expect(page.locator('#m-birth')).toHaveClass(/on/);

    // Göç işareti: kanonik buton var (tabanda YOK → kırmızı) ve TR etiketli
    await expect(page.locator('#b-tarih-btn')).toHaveCount(1);
    expect(await page.locator('#b-tarih-btn').textContent()).toMatch(/📅 \d{2}\.\d{2}\.\d{4}/);
    const meta = await inputMeta(page, '#b-tarih');
    expect(meta.value).toMatch(/^\d{4}-\d{2}-\d{2}$/); // init default bugun() — ISO taşıyıcıda

    await page.click('#b-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    // Ay başlığı Türkçe — en-US locale'ine rağmen (locale sızıntı kilidi).
    // R1: başlık artık ay/yıl <select> dropdown'ı — seçili opsiyon TR ay adı.
    const seciliAy = await page.locator('#tek-tarih-ay-sec option:checked').innerText();
    expect(TR_AYLAR, `seçili ay TR olmalı: "${seciliAy}"`).toContain(seciliAy);

    const t = await bugunIso(page);
    await gunHucreTikla(page, t);
    await expect(page.locator('#b-tarih')).toHaveValue(t); // okuyucu sözleşmesi: ISO
    // Görünür yüzey TR biçimde — gg.aa.yyyy (locale'den bağımsız)
    await expect(page.locator('#b-tarih-btn')).toHaveText(new RegExp('📅 ' + t.slice(8) + '\\.' + t.slice(5, 7) + '\\.' + t.slice(0, 4)));
  });

  test('i-tarih (tohumlama): el girişi gg.aa.yyyy → ISO; en-US altında mm/dd YORUMU YOK', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('[data-action="open-insem-modal"]');
    await expect(page.locator('#m-insem')).toHaveClass(/on/);

    await page.click('#i-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    // mm/dd tuzağı e2e ayağı: 15.07.2026 Türkçe gün.ay.yıl — mm/dd yorumu
    // yapılsaydı 2026-07-15 DEĞİL başka bir gün çıkardı (ay 15 geçersizdi).
    await page.fill('#tek-tarih-giris', '15.07.2026');
    await page.click('#tek-tarih-takvim button:has-text("Uygula")');

    // El girişi görünümü Temmuz'a taşıdı — R1: başlık dropdown'da okunur
    await expect(page.locator('#tek-tarih-ay-sec')).toHaveValue('6'); // Temmuz (0-based)
    await expect(page.locator('#tek-tarih-yil-sec')).toHaveValue('2026');

    await page.click('#tek-tarih-takvim button:has-text("Onayla")');
    await expect(takvim(page)).toHaveCount(0);
    await expect(page.locator('#i-tarih')).toHaveValue('2026-07-15');
  });

  test('a-dt (hayvan doğumu): seçim change olayı tetikler, Temizle boşaltır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Yeni Hayvan');
    await expect(page.locator('#m-animal')).toHaveClass(/on/);

    // data-change="animal-guncelle" akışı change olayıyla beslenir —
    // takvimden seçim native seçimle aynı olayı vermelidir.
    await page.evaluate(() => {
      window.__aDtChange = 0;
      document.getElementById('a-dt').addEventListener('change', () => { window.__aDtChange++; });
    });

    expect(await page.evaluate(() => document.getElementById('a-dt').value)).toBe('');

    await page.click('#a-dt-btn');
    await expect(takvim(page)).toBeVisible();
    const t = await bugunIso(page);
    await gunHucreTikla(page, t);
    await expect(page.locator('#a-dt')).toHaveValue(t);
    expect(await page.evaluate(() => window.__aDtChange)).toBe(1);

    // temizlenebilir: Temizle + Onayla → alan boşalır (p_dogum_tarihi || null yolu)
    await page.click('#a-dt-btn');
    await expect(takvim(page)).toBeVisible();
    await page.click('#tek-tarih-takvim button:has-text("Temizle")');
    await page.click('#tek-tarih-takvim button:has-text("Onayla")');
    await expect(takvim(page)).toHaveCount(0);
    expect(await page.evaluate(() => document.getElementById('a-dt').value)).toBe('');
    expect(await page.evaluate(() => window.__aDtChange)).toBe(2);
  });

  test('max sınırı: b-tarih takviminde gelecek günler tıklanamaz', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await expect(page.locator('#m-birth')).toHaveClass(/on/);

    await page.click('#b-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    // Gelecek bir gün (yarından 40 gün sonra) — max=bugun → hücrede onclick YOK
    const gelecek = await page.evaluate(() => dFwd(bugun(), 40));
    const hucre = page.locator(`#tek-tarih-takvim div[onclick*="${gelecek}"]`);
    await expect(hucre, 'gelecek gün seçilemez olmalı (onclick yok)').toHaveCount(0);
    await page.click('#tek-tarih-takvim button:has-text("İptal")');
    await expect(takvim(page)).toHaveCount(0);
  });
});

// ═══ R1 — SAHİP TESTİ REVİZYONU (G-20260913-TARIH-SECICI-R1) ═══
// Bulgu 2: masaüstü (≥900px) modal kartı 400px + ortalı; mobil (412×915)
// tam-genişlik alt-sheet KORUNUR ("telefonda gayet iyi").
// Bulgu 1: nav okları ≥40px dokunma hedefi.
// Bulgu 4: başlıkta ay+yıl dropdown.
// Bulgu 3: maske — 11122026 → 11.12.2026; ayraç toleransı 13,09,2026.

test.describe('R1 — masaüstü kompakt modal (1920×1080)', () => {
  test.use({ viewport: { width: 1920, height: 1080 }, hasTouch: false, isMobile: false });

  test('masaüstü: modal kartı 360–440px + ortalı; nav oku ≥40px', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await expect(page.locator('#m-birth')).toHaveClass(/on/);
    await page.click('#b-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    const kart = await page.locator('#tek-tarih-takvim .tarih-modal-kart').boundingBox();
    expect(kart.width).toBeLessThanOrEqual(440);
    expect(kart.width).toBeGreaterThanOrEqual(360);
    expect(kart.x + kart.width / 2).toBeGreaterThan(1920 / 2 - 40); // yatay ortada
    expect(kart.x + kart.width / 2).toBeLessThan(1920 / 2 + 40);
    expect(kart.y + kart.height / 2).toBeGreaterThan(1080 / 2 - 80); // dikey ortada
    expect(kart.y + kart.height / 2).toBeLessThan(1080 / 2 + 80);

    const ok = await page.locator('#tek-tarih-takvim button[aria-label="Önceki ay"]').boundingBox();
    expect(ok.width).toBeGreaterThanOrEqual(40);
    expect(ok.height).toBeGreaterThanOrEqual(40);
  });

  test('dropdown: ay/yıl seçimi görünümü taşır, hücre seçimi değeri yazar', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await expect(page.locator('#m-birth')).toHaveClass(/on/);
    await page.click('#b-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    // Doğum senaryosu (sahip: geçmiş yıllar hâkim) — Ocak 2018'e atla
    await page.selectOption('#tek-tarih-ay-sec', '0');
    await page.selectOption('#tek-tarih-yil-sec', '2018');
    await expect(page.locator('#tek-tarih-ay-sec')).toHaveValue('0');
    await expect(page.locator('#tek-tarih-yil-sec')).toHaveValue('2018');

    await page.locator('#tek-tarih-takvim div[onclick*="2018-01-15"]').click();
    await page.click('#tek-tarih-takvim button:has-text("Onayla")');
    await expect(takvim(page)).toHaveCount(0);
    await expect(page.locator('#b-tarih')).toHaveValue('2018-01-15');
    await expect(page.locator('#b-tarih-btn')).toHaveText(/📅 15\.01\.2018/);
  });
});

test.describe('R1 — mobil korunur + maske girişi (412×915)', () => {
  test.use({ viewport: { width: 412, height: 915 }, hasTouch: true, isMobile: true });

  test('maske: 11122026 → 11.12.2026; Uygula Aralığa atlar ve seçer', async ({ page }) => {
    // Yüzey: ta-tarih (görev hedefi — gelecek serbest); i-tarih max=bugun
    // olduğu için sahibin gelecek-tarih örneği orada red edilir (kural doğru,
    // yüzey yanlış olurdu). FAB görevler sayfasındadır.
    await openApp(page);
    await navTo(page, '#nb-tasks');
    await page.click('[data-action="open-task-add-modal"]');
    await expect(page.locator('#m-task-add')).toHaveClass(/on/);
    await page.click('#ta-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    await page.fill('#tek-tarih-giris', '11122026');
    await expect(page.locator('#tek-tarih-giris')).toHaveValue('11.12.2026');
    await page.click('#tek-tarih-takvim button:has-text("Uygula")');
    await expect(page.locator('#tek-tarih-ay-sec')).toHaveValue('11');
    await expect(page.locator('#tek-tarih-yil-sec')).toHaveValue('2026');
    await page.locator('#tek-tarih-takvim div[onclick*="2026-12-11"]').click();
    await page.click('#tek-tarih-takvim button:has-text("Onayla")');
    await expect(takvim(page)).toHaveCount(0);
    await expect(page.locator('#ta-tarih')).toHaveValue('2026-12-11');
  });

  test('ayraç toleransı: 13,09,2026 → 13.09.2026 (sahibin bugünkü hata örneği)', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('[data-action="open-insem-modal"]');
    await expect(page.locator('#m-insem')).toHaveClass(/on/);
    await page.click('#i-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    await page.fill('#tek-tarih-giris', '13,09,2026');
    await expect(page.locator('#tek-tarih-giris')).toHaveValue('13.09.2026');
    await page.click('#tek-tarih-takvim button:has-text("Uygula")');
    await expect(page.locator('#tek-tarih-ay-sec')).toHaveValue('8'); // Eylül
    await page.click('#tek-tarih-takvim button:has-text("Onayla")');
    await expect(takvim(page)).toHaveCount(0);
    await expect(page.locator('#i-tarih')).toHaveValue('2026-09-13');
  });

  test('mobil: kart tam-genişlik alt-sheet kalır, gün tıkı davranışı aynı', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await expect(page.locator('#m-birth')).toHaveClass(/on/);
    await page.click('#b-tarih-btn');
    await expect(takvim(page)).toBeVisible();

    const kart = await page.locator('#tek-tarih-takvim .tarih-modal-kart').boundingBox();
    expect(kart.width).toBeGreaterThan(412 * 0.9);          // tam genişlik (alt-sheet)
    expect(kart.y + kart.height).toBeGreaterThan(915 - 60); // alta yaslı

    const t = await bugunIso(page);
    await page.locator(`#tek-tarih-takvim div[onclick*="${t}"]`).click();
    await page.click('#tek-tarih-takvim button:has-text("Onayla")');
    await expect(takvim(page)).toHaveCount(0);
    await expect(page.locator('#b-tarih')).toHaveValue(t);
  });
});
