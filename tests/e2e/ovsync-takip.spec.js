// tests/e2e/ovsync-takip.spec.js
// Ovsync Takip Ekranı — demo Playwright temsilciler (plan v7 P12; katalog T-56, T-32/T-59,
// T-01/T-07, T-20, T-38/T-44, T-47/T-48, T-55, T-50 katmanları).
//
// ZARF SEMANTİĞİ (runs/2026-09-28-ovsync-takip/test-uygulanabilir-GOREV.md): ürün UI'sı
// (P5-P10: #pg-ovsync sayfası, 6. stat hücresi, devam seçici, TAKIP_ACIK sheet, S3 rozeti)
// henüz uygulanmadı → bu spec'in assertion'ları BUGÜN KIRMIZI ÇIKAR; kırmızı = beklenen-öncesi
// durumdur, PASS SAYILMAZ. Testler test.skip iskeleti DEĞİLDİR — P5-P10 uygulandıkça aynı
// assertion'lar yeşile döner (D7 sırası: kırmızı iskeletler uygulama adımının önünde, #17).
//
// Veri politikası: veri-agnostik (mevcut tests/*.spec.js deseni) + E2E-TAKIP-PW- marker'lı
// seed (yalnız demo; cleanup afterAll). Var olan sonuclar.json ya da başka kullanıcı
// artefaktına dokunulmaz — bu spec rapor yazmaz (hedefli koşum: --reporter=list).
//
// Koşum (demo):
//   NODE_PATH=/home/melik/egesut-erp1/node_modules npx playwright test tests/e2e/ovsync-takip.spec.js \
//     --config=playwright.config.js PLAYWRIGHT_DEMO_MODE=1 --reporter=list --retries=0
//   (PLAYWRIGHT_DEMO_MODE env değişkeni olarak verilir.)

import { test, expect, openApp, navTo, goOffline, IS_DEMO } from '../support/app.js';
import { createClient } from '@supabase/supabase-js';

const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
const MARKER = 'E2E-TAKIP-PW-';

test.skip(!IS_DEMO, 'ovsync-takip temsilcileri: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

let db; // demo authenticated client (seed/cleanup)
let seedKupe;

test.beforeAll(async () => {
  db = createClient(DEMO_URL, DEMO_KEY);
  const { error } = await db.auth.signInWithPassword(DEMO_LOGIN);
  if (error) throw new Error(`demo giriş başarısız: ${error.message}`);

  // Eski marker'lı kalıntıları temizle (idempotent seed)
  await temizle();

  // T-01/T-20 zemini: kural günü gelmiş Dişi hayvan + Bekliyor tohumlama + açık takip
  seedKupe = MARKER + Math.random().toString(36).slice(2, 8);
  const { error: e1 } = await db.from('hayvanlar').insert({
    id: seedKupe, kupe_no: seedKupe, cinsiyet: 'Dişi',
    dogum_tarihi: new Date(Date.now() - 400 * 864e5).toISOString().slice(0, 10),
    grup: 'Sağmal (Laktasyonda)',
  }).select('id').single();
  if (e1) throw new Error(`seed hayvan başarısız: ${e1.message}`);
  const { data: t, error: e2 } = await db.from('tohumlama').insert({
    hayvan_id: seedKupe, tarih: new Date().toISOString().slice(0, 10),
    sonuc: 'Bekliyor', deneme_sayisi: 1, denemeler: [],
  }).select('id').single();
  if (e2) throw new Error(`seed tohumlama başarısız: ${e2.message}`);
  const { error: e3 } = await db.from('gorev_log').insert({
    hayvan_id: seedKupe, gorev_tipi: 'TAKIP_MUAYENE', aciklama: MARKER + 'takip',
    hedef_tarih: new Date(Date.now() + 7 * 864e5).toISOString().slice(0, 10),
    tamamlandi: false, iptal: false, kaynak: 'TAKIP:' + t.id,
  });
  if (e3) throw new Error(`seed takip görevi başarısız: ${e3.message}`);
});

test.afterAll(async () => { await temizle(); });

async function temizle() {
  const { data: eski } = await db.from('hayvanlar').select('id').like('id', MARKER + '%');
  for (const h of eski ?? []) {
    await db.from('gorev_log').delete().eq('hayvan_id', h.id);
    await db.from('tohumlama').delete().eq('hayvan_id', h.id);
    await db.from('hayvanlar').delete().eq('id', h.id);
  }
}

// ═══ 1) T-56 — Giriş: dashboard 6. stat hücresi + goTo('ovsync') ═════════════
test('T-56: dashboard 6. hücre "Ovsync" görünür; tıklayınca #pg-ovsync açılır', async ({ page }) => {
  await openApp(page);
  // K7/R4: .dash-row'a yeni 6. .sc hücresi — "🔄 Ovsync ›" + aktif zincir sayısı
  const hucre = page.locator('.dash-row .sc', { hasText: 'Ovsync' });
  await expect(hucre).toHaveCount(1);
  await expect(hucre).toContainText('🔄');
  // onclick="goTo('ovsync')" — tıkla → sayfa .on
  await hucre.click();
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
});

// ═══ 2) T-32 + T-59 — Sayfa omurgası: KPA şeridi + S0-S4 + boş bölüm gizli ═══
test('T-32/T-59: ovsync sayfası KPA şeridi (5 sayaç) + S0-S4 bölümleri; boş bölüm gizli', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  // §3: Aktif/Bugün/Geciken/Muayene bekleyen/Bekleyen başlatma
  for (const kpa of ['Aktif', 'Bugün', 'Geciken', 'Muayene', 'Bekleyen başlatma']) {
    await expect(page.locator('#pg-ovsync', { hasText: kpa }).first()).toBeVisible();
  }
  // §3: boşsa gizli — S0 "BUGÜN & GECİKEN" bölümü seed'de boş → render EDİLMEZ
  const s0 = page.locator('#pg-ovsync [data-bolum="S0"], #pg-ovsync section', { hasText: 'BUGÜN' });
  await expect(s0).toHaveCount(0);
});

// ═══ 3) T-01 + T-07 — Devam seçici: Boş sonrası zorunlu seçim, Ovsync ön seçili ═══
test('T-01/T-07: Boş → devam seçici; Ovsync ön seçili; etiket seçimle değişir', async ({ page }) => {
  await openApp(page);
  // seed hayvanın Bekliyor tohumlaması: Üreme → Tohumlama tab → arama (mevcut app deseni)
  await navTo(page, '#nb-ureme');
  await page.click('#ureme-tab-tohumlama');
  await page.fill('#tohumlama-srch', seedKupe);
  const satir = page.locator('#ureme-body .hist-row', { hasText: seedKupe }).first();
  await expect(satir).toBeVisible();
  await satir.click();
  await expect(page.locator('#m-toh-det')).toHaveClass(/on/);
  await page.check('input[name="toh-sonuc"][value="Boş"]');
  // §6c.1: confirm() KALKTI — sarmal RPC + devam seçici (mockup 01)
  await expect(page.getByText('Devam nasıl olsun?')).toBeVisible();
  await expect(page.getByRole('radio', { name: /Ovsync/ })).toBeChecked(); // S3b: ön seçim Ovsync
  await expect(page.getByRole('button', { name: /Boş ata \+ Ovsync başlat/ })).toBeVisible();
  // S3: seçim zorunlu — "yalnız Boş ata" düğmesi YOK (mockup 01: seçilmeden Kaydet pasif)
  await expect(page.getByRole('button', { name: /^Kaydet$/ })).toHaveCount(0);
});

// ═══ 4) T-20 — TAKIP_ACIK onay penceresi: app kendi sheet'i, confirm() DEĞİL ═══
test('T-20: takipli hayvanda PG seçimi → TAKIP_ACIK onay sheet (native dialog YASAK)', async ({ page }) => {
  await openApp(page);
  let nativeDialog = false;
  page.on('dialog', d => { nativeDialog = true; d.dismiss().catch(() => {}); });
  // takipteki hayvan: ovsync S3 → takip muayene ekranı → PG seç → Kaydet → sunucu TAKIP_ACIK
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  const satir = page.locator('#pg-ovsync', { hasText: seedKupe }).first();
  await expect(satir).toBeVisible();
  await satir.click();
  await page.getByRole('radio', { name: /PG uygula/ }).check();
  await page.getByRole('button', { name: /PG uygula/ }).click();
  // sheet (#pg-kapi-bs deseni; TAKIP_ACIK varyantı — P10) metni mockup 04:
  const sheet = page.locator('#pg-kapi-bs, [data-sheet="takip-acik"]');
  await expect(sheet).toBeVisible();
  await expect(sheet).toContainText(seedKupe);           // küpe
  await expect(sheet).toContainText(/takip kapatılıp|takibinde/i);
  expect(nativeDialog, 'tarayıcı confirm()/alert() KULLANILMAMALI (§18.8, mockup 04)').toBe(false);
});

// ═══ 5) T-38 + T-44 — S2 sayaç: "muayeneye N gün" (eşik ayardan; 21 YOK) ═════
test('T-38/T-44: S2 sayaç "muayeneye N gün"; 21 sabiti yok', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  // K2/§18.13: sayaç = _ayar('sessiz_tohumlama_muafiyet_gun',40) — demo ayarı 40 (ölçüldü)
  const sayac = page.getByText(/muayeneye \d+ gün/);
  await expect(sayac.first()).toBeVisible();
  const govde = await page.locator('#pg-ovsync').innerText();
  expect(govde).not.toMatch(/21[.\s]*gün|21\. gün/); // T-44: "21. gün kontrol" YOK (iptal karar)
});

// ═══ 6) T-47/T-48 — Offline: bayat etiket / açık mesaj (sessiz boş YASAK) ════
test('T-47/T-48: offline → "çevrimdışı · HH:MM verisi" ya da açık mesaj', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  await goOffline(page);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#pg-dash .sv', { timeout: 30000 });
  const metin = await page.locator('body').innerText();
  const bayatEtiket = /çevrimdışı · \d{2}:\d{2} verisi/.test(metin);
  const acikMesaj = /İnternet yok — takip verisi alınamadı/.test(metin);
  expect(bayatEtiket || acikMesaj, 'sessiz boş liste YASAK (§5/R6)').toBe(true);
});

// ═══ 7) T-55 — Gezinme: ‹ = history.back() (goTo('dash') DEĞİL) ══════════════
test('T-55: ovsync → görevler → ovsync; ‹ bir adım geri (history.back)', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  await navTo(page, '#nb-gorevler');
  await page.evaluate(() => window.goTo && window.goTo('ovsync')); // hub'a uğramadan yatay geçiş (T-51)
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  await page.click('[data-action="nav-geri"]'); // ‹ (R13: history.back)
  await expect(page.locator('#pg-gorevler')).toHaveClass(/on/); // bir adım geri = görevler
});

// ═══ 8) T-50 — Yazma sonrası invalidate: __ovsyncTakip = null ════════════════
test('T-50: takip verisi önbelleği yazma akışından sonra tazelenir (__ovsyncTakip=null)', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  await page.waitForFunction(() => window.__ovsyncTakip !== undefined, null, { timeout: 15000 });
  // seed takibi kapat: görevi iptal et (yazma yolu — takip kapanışı DB'den)
  await db.from('gorev_log').update({ iptal: true }).eq('hayvan_id', seedKupe).eq('gorev_tipi', 'TAKIP_MUAYENE');
  // uygulama yazma-sonrası invalidate geleneğini uygular (§5: __ovsyncTakip=null + yeniden yükle)
  await expect.poll(async () =>
    page.evaluate(() => window.__ovsyncTakip === null || window.__ovsyncTakip === undefined ? 'taze' : 'bayat'),
  { timeout: 15000 }).toBe('taze');
});
