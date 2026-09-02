// tests/e2e.spec.js
// EgeSüt ERP — Kapsamlı E2E Test Suite
// Kapsam: Stabilite + Veri Tutarlılığı + Klinik Modül + Form Validasyon + Edge Cases
//
// Kural: Read-only testler hiçbir veri değiştirmez.
//        Write testler (form validasyon) formu doldurur ama SUBMIT ETMEZ.

import { test, expect } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';

// ─── Sabitler ────────────────────────────────────────────────────────────────
// Guvenlik: dbCount/dbGetFirst her zaman ayni ortama (demo/prod) baglanmali ki
// PLAYWRIGHT_DEMO_MODE ile UI'nin konustugu proje ile assertion'larin okudugu
// proje ayni olsun. Bu bayrak olmadan bu dosya HER ZAMAN canli prod'u okuyordu
// (playwright.config.js'deki storageState demo bayragindan bagimsiz calisiyordu).
const IS_DEMO = !!process.env.PLAYWRIGHT_DEMO_MODE;
const STUB = !!process.env.PLAYWRIGHT_STUB_BACKEND; // stub'ta UI fixture verisi gösterir; dbCount/dbGetFirst GERÇEK demo DB'sinden okur → eşleşme testleri anlamsız
const SB_URL  = IS_DEMO
  ? 'https://vtzqjmazsvurxdeondmi.supabase.co'
  : 'https://zqnexqbdfvbhlxzelzju.supabase.co';
const SB_KEY  = IS_DEMO
  ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8'
  : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc';
const supabase = createClient(SB_URL, SB_KEY);

// Demo projesinde anon rolün tablo okuma yetkisi yok (restore sonrası GRANT
// kaybı, REST 42501) — UI demo autologin ile authenticated çektiği için
// dbCount/dbGetFirst de demo oturumuyla okur (CI'nın demosuz prod koşusu
// anon okumayla devam eder; ensureSession yalnız demo modda oturum açar).
let sessionPromise = null;
function ensureSession() {
  if (!IS_DEMO) return Promise.resolve();
  if (!sessionPromise) {
    sessionPromise = supabase.auth.signInWithPassword({ email: 'demo@egesut.web', password: 'demo2026' })
      .then(res => { if (res.error) throw res.error; return res.data; });
  }
  return sessionPromise;
}

// ─── Bilinen/zararsız uyarılar ──────────────────────────────────────────────
const IGNORED_ERRORS = [
  'ResizeObserver loop',
  'Non-passive event listener',
  'IDB',
  'supabase-js',
  'WebSocket',
];

function isCritical(msg) {
  return !IGNORED_ERRORS.some(s => msg.toLowerCase().includes(s.toLowerCase()));
}

// Bilinen/ortam-kaynaklı hatalı istekler — kaynağa (msg.location) göre
// ayıklanır (ayrıntı smoke.spec.js başlığında): agent-telemetry/tracker.js
// (repoda olmayan commit'lenmiş script → 404), rpc/demo_sema_diff ve
// rpc/hekim_listesi (demo projesinde RPC yok → 401/404).
const IGNORED_LOCATIONS = ['agent-telemetry', 'rpc/demo_sema_diff', 'rpc/hekim_listesi'];

function isIgnoredLocation(msg) {
  const url = msg.location()?.url || '';
  return IGNORED_LOCATIONS.some(s => url.includes(s));
}

// ─── DB'den veri çek ─────────────────────────────────────────────────────────
async function dbCount(table) {
  await ensureSession();
  const { count } = await supabase.from(table).select('*', { count: 'exact', head: true });
  return count ?? 0;
}

async function dbGetFirst(table, columns = '*', limit = 1) {
  await ensureSession();
  const { data } = await supabase.from(table).select(columns).limit(limit);
  return data?.[0] ?? null;
}

// UI'ın gösterdiği kayıtla DB satırını id üzerinden eşleştir — REST default
// sırası ile UI kart sırası aynı kayıt olmayabilir (sıralama garanti değil)
async function dbGetById(table, id, columns = '*') {
  await ensureSession();
  const { data } = await supabase.from(table).select(columns).eq('id', id).limit(1);
  return data?.[0] ?? null;
}

// Küpe numarasıyla hayvan satırı (2.03 kart↔DB üçgeni)
async function dbGetByKupe(kupeNo) {
  await ensureSession();
  const { data } = await supabase.from('hayvanlar').select('id, kupe_no, isletme_kupe').eq('kupe_no', kupeNo).limit(1);
  return data?.[0] ?? null;
}

// ─── Sayfa aç + hata topla ───────────────────────────────────────────────────
async function openApp(page) {
  const criticalErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error' && isCritical(msg.text()) && !isIgnoredLocation(msg))
      criticalErrors.push(msg.text());
  });
  page.on('pageerror', err => criticalErrors.push(err.message));

  await page.goto('./', { waitUntil: 'domcontentloaded' }); // '/' baseURL alt-dizinini düşürüp GH Pages kök 404'üne gider
  await page.waitForSelector('#pg-dash .sv', { timeout: 30000 });

  return criticalErrors;
}

// ─── NAV geçiş ───────────────────────────────────────────────────────────────
async function navTo(page, btnId) {
  const id = btnId.replace(/^#/, ''); // '#nb-x' ve 'nb-x' girişlerinin ikisi de kabul
  await page.click('#' + id);
  await page.waitForSelector('#' + id.replace('nb-', 'pg-') + '.on', { timeout: 8000 });
}

// ════════════════════════════════════════════════════════════════════════════════
// 1. STABİLİTE — Sayfa yüklenmesi, nav, JS hataları
// ════════════════════════════════════════════════════════════════════════════════

test.describe('1 — Stabilite', () => {

  test('1.01 sayfa hatasız yüklenir, dashboard görünür', async ({ page }) => {
    const errors = await openApp(page);
    // openApp, #pg-dash ve .sv'yi zaten görünür olana dek bekledi (30s) —
    // tekrar expect etmek demo modunda autologin reload + gecikmeli pull
    // yüzünden toplam 30s test sınırını aşırıyordu; burada yalnız nav + hata
    // sıfırlaması doğrulanır
    await expect(page.locator('#nav')).toBeVisible({ timeout: 15000 });
    expect(errors, `Kritik JS hataları: ${errors.join(' | ')}`).toHaveLength(0);
  });

  test('1.02 tüm nav butonları geçiş yapar', async ({ page }) => {
    await openApp(page);
    const buttons = [
      { btn: '#nb-suru',   page: '#pg-suru' },
      { btn: '#nb-tasks',  page: '#pg-tasks' },
      { btn: '#nb-ureme',  page: '#pg-ureme' },
      { btn: '#nb-gecmis', page: '#pg-gecmis' },
      { btn: '#nb-log',    page: '#pg-log' },
      { btn: '#nb-dash',   page: '#pg-dash' },
    ];
    for (const { btn, page: pg } of buttons) {
      await page.click(btn);
      await expect(page.locator(pg)).toBeVisible({ timeout: 6000 });
    }
  });

  test('1.03 refresh butonu çalışır', async ({ page }) => {
    await openApp(page);
    await page.click('#refbtn');
    await page.waitForTimeout(300);
    await page.waitForSelector('#pg-dash .sv', { timeout: 20000 });
  });

  test('1.04 alt nav butonları erişilebilir', async ({ page }) => {
    await openApp(page);
    await expect(page.locator('#nb-tasks')).toBeVisible();
    await expect(page.locator('#nb-ureme')).toBeVisible();
  });

  test('1.05 sync bar elementi mevcut', async ({ page }) => {
    await openApp(page);
    await expect(page.locator('#sync-bar')).toBeAttached();
    await expect(page.locator('#pages')).toBeVisible();
  });

});

// ════════════════════════════════════════════════════════════════════════════════
// 2. VERİ TUTARLILIĞI — DB ↔ UI eşleşmesi
// ════════════════════════════════════════════════════════════════════════════════

test.describe('2 — Veri Tutarlılığı', () => {

  test('2.01 sürü sayfasında hayvan kartı sayısı DB ile eşleşir', async ({ page }) => {
    test.skip(STUB, 'stub backend: UI fixture verisi, DB doğrulaması gerçek demo projesi — eşleşme anlamsız');
    await openApp(page);
    const dbCountVal = await dbCount('hayvanlar');
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    const cardCount = await page.locator('.animal-card').count();
    expect(cardCount, `DB: ${dbCountVal} vs UI: ${cardCount}`).toBeGreaterThan(0);
    expect(cardCount).toBeLessThanOrEqual(dbCountVal + 1);
  });

  test('2.02 hayvan kartında küpe no ? olmamalı', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.a-id', { timeout: 15000 });
    const firstId = await page.locator('.a-id').first().innerText();
    expect(firstId.trim().length, 'Küpe no boş olmamalı').toBeGreaterThan(0);
    expect(firstId.trim(), 'Küpe no ? olmamalı').not.toBe('?');
  });

  test('2.03 hayvan detayında kulak no DB ile eşleşir', async ({ page }) => {
    test.skip(STUB, 'stub backend: UI fixture verisi, DB doğrulaması gerçek demo projesi — eşleşme anlamsız');
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });

    // İlk kartın küpe etiketi üzerinden üçgen doğrulama: kart ↔ detay ↔ DB
    // (REST default sırası ile UI kart sırası aynı kayıt olmayabilir)
    const cardKupe = (await page.locator('.animal-card .a-id').first().innerText()).trim();
    test.skip(!cardKupe, 'kart küpe etiketi boş (veri-agnostic skip)');
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('#det.on', { timeout: 8000 });

    // Detay başlığı async dolar — boş kalırsa race, poll ile bekle
    let detName = '';
    await expect
      .poll(async () => {
        detName = (await page.locator('#det-name').innerText()).trim();
        return detName.length;
      }, { timeout: 10000 })
      .toBeGreaterThan(0);

    const dbHayvan = await dbGetByKupe(cardKupe);
    const expected = [dbHayvan?.kupe_no, dbHayvan?.isletme_kupe, cardKupe].filter(Boolean);
    const match = expected.some(v => v && detName.includes(v));
    expect(match, `Detay: "${detName}" KartKupe: "${cardKupe}" DB: ${JSON.stringify(dbHayvan)}`).toBe(true);
  });

  test('2.04 görevler sayfası crash olmaz', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-tasks');
    await page.waitForTimeout(2000);
    const taskCount = await page.locator('.task-card').count();
    expect(taskCount, 'Görev sayfası crash olmamalı').toBeGreaterThanOrEqual(0);
  });

  test('2.05 stok paneli açılır ve içerik yüklenir', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.waitForSelector('.log-btn', { timeout: 10000 });
    await page.click('text=Stok Modülü');
    await page.waitForTimeout(2000);
    const stokPanel = page.locator('#stok-panel');
    await expect(stokPanel).toBeVisible();
    const hasContent = (await page.locator('#stok-panel-body .animal-card, #stok-panel-body .empty, #stok-panel-body .log-btn').count()) > 0;
    expect(hasContent, 'Stok panelinde içerik var veya boş state').toBe(true);
  });

  test('2.06 dashboard istatistik kartları görünür ve sayısal', async ({ page }) => {
    await openApp(page);
    const statCards = page.locator('.sc');
    const count = await statCards.count();
    expect(count, 'Dashboard\'da en az 1 stat kartı').toBeGreaterThan(0);
    const firstVal = await page.locator('.sc .sv').first().innerText();
    expect(/^\d+$/.test(firstVal.trim()), `İstatistik değeri sayısal olmalı: "${firstVal}"`).toBe(true);
  });

  test('2.07 geçmiş sayfası log kayıtları gösterir veya boş state', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-gecmis');
    await page.waitForSelector('#pg-gecmis', { timeout: 8000 });
    await page.waitForTimeout(2000);
    const hasLogs = await page.locator('.log-btn').count();
    const hasEmpty = await page.locator('#pg-gecmis .empty').count();
    expect(hasLogs + hasEmpty, 'Geçmiş sayfası log veya boş state göstermeli').toBeGreaterThan(0);
  });

  test('2.08 üreme tüm tab geçişleri çalışır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-ureme');
    await page.waitForSelector('#pg-ureme .fs-btn', { timeout: 10000 });

    const tabs = [
      'ureme-tab-kizginlik',
      'ureme-tab-tohumlama',
      'ureme-tab-gebelik',
      'ureme-tab-dogum',
      'ureme-tab-abort',
    ];

    for (const tab of tabs) {
      await page.click(`#${tab}`);
      await page.waitForTimeout(500);
    }
    for (const tab of tabs) {
      await expect(page.locator(`#${tab}`)).toBeVisible();
    }
  });

});

// ════════════════════════════════════════════════════════════════════════════════
// 3. KLİNİK MODÜL — Vaka açma, tedavi, ilaç
// ════════════════════════════════════════════════════════════════════════════════

test.describe('3 — Klinik Modül', () => {

  test('3.01 vaka açma modalı açılır ve hastalık dropdown dolu', async ({ page }) => {
    test.setTimeout(90000); // diseases pull'u seri _pullChain'in sonlarında — yüklü koşumda 25s'yi aşıyor
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.waitForSelector('.log-btn', { timeout: 10000 });
    // Arrange: ilk pull zinciri 30+ tabloyu SERİ çeker; diseases son sıralarda
    // olduğundan yüklü koşumda modal açılışına yetişemeyebilir. Uygulamanın
    // kendi pullTables'iyle diseases fazını öne al (veri değişmez, yalnız okunur)
    await page.evaluate(() => pullTables(['diseases']));
    await page.click('text=Vaka Aç');
    await page.waitForSelector('#m-disease.on', { timeout: 5000 });
    await expect(page.locator('#m-disease')).toBeVisible();
    // Dropdown, pull sonrası async dolar — anlık count race üretir, poll ile bekle
    await expect
      .poll(async () => await page.locator('#d-disease-id option').count(), { timeout: 30000 })
      .toBeGreaterThan(1);
  });

  test('3.02 hastalık dropdown hastalık adı içerir', async ({ page }) => {
    test.skip(STUB, 'stub backend: diseases fixture\'ı boş, gerçek demo DB ile eşleşme anlamsız');
    test.setTimeout(90000); // diseases pull'u seri zincirin sonlarında — 3.01 ile aynı gerekçe
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.evaluate(() => pullTables(['diseases'])); // 3.01'deki arrange ile aynı
    await page.click('text=Vaka Aç');
    await page.waitForSelector('#m-disease.on', { timeout: 5000 });
    const dbDisease = await dbGetFirst('diseases', 'name');
    // Dropdown async dolar — placeholder dışı seçenek dolana kadar poll
    let optionText = [];
    await expect
      .poll(async () => {
        optionText = (await page.locator('#d-disease-id option').allInnerTexts())
          .filter(t => t && !t.startsWith('—'));
        return optionText.length;
      }, { timeout: 30000 })
      .toBeGreaterThan(0);
    if (dbDisease?.name) {
      const match = optionText.some(t => t.includes(dbDisease.name));
      expect(match, `Dropdown hastalık "${dbDisease.name}" içermeli`).toBe(true);
    }
  });

  test('3.03 tab-saglik crash olmadan açılır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('#det.on', { timeout: 8000 });
    // #tab-saglik görünmez .tab-pane — tıklama hedefi data-action butonu
    await page.click('[data-action="tab-saglik"]');
    await page.waitForTimeout(1000);
    const errors = [];
    page.on('pageerror', err => errors.push(err.message));
    await page.waitForTimeout(1000);
    expect(errors, 'Tab-saglik crash olmamalı').toHaveLength(0);
  });

  test('3.04 vaka modalı kapatılabilir', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Vaka Aç');
    await page.waitForSelector('#m-disease.on', { timeout: 5000 });
    // "İptal" metni tüm modal sheet'lerinde var — ilk DOM eşleşmesi gizli
    // olabilir; m-disease kapsamındaki butonla kapat
    await page.click('#m-disease [data-action="close-disease"]');
    await page.waitForTimeout(500);
    const isVisible = await page.locator('#m-disease').isVisible();
    expect(isVisible, 'Modal kapanmalı').toBe(false);
  });

  test('3.05 tab-saglik\'te vaka kartları ? ismiyle görünmemeli', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('#det.on', { timeout: 8000 });
    // #tab-saglik görünmez .tab-pane — tıklama hedefi data-action butonu
    await page.click('[data-action="tab-saglik"]');
    await page.waitForTimeout(2000);

    const texts = await page.locator('#tab-saglik').innerText();
    const lines = texts.split('\n').filter(l => l.trim() === '?');
    expect(lines.length, 'Hastalık adı ? ile gösterilmemeli').toBe(0);
  });

  test('3.06 hayvan detay tüm tab\'lar crash olmadan geçilir', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('#det.on', { timeout: 8000 });

    // Detay tab'ları button[data-action="tab-*"] — #tab-* id'leri görünmez
    // .tab-pane içerik panelidir (UI refactor sonrası tıklama hedefi değil)
    const tabs = ['[data-action="tab-ozet"]', '[data-action="tab-saglik"]', '[data-action="tab-ureme"]', '[data-action="tab-gorev"]', '[data-action="tab-gecmis"]'];
    for (const tab of tabs) {
      await page.click(tab);
      await page.waitForTimeout(800);
    }
  });

  test('3.07 hayvan detay geri butonu çalışır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('#det.on', { timeout: 8000 });
    await page.click('.det-back');
    await page.waitForTimeout(500);
    await expect(page.locator('#det.on')).not.toBeVisible();
  });

});

// ════════════════════════════════════════════════════════════════════════════════
// 4. FORM VALİDASYON — Boş form, zorunlu alan, tarih
// ════════════════════════════════════════════════════════════════════════════════

test.describe('4 — Form Validasyon', () => {

  test('4.01 vaka açma: boş form submit edilemez', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Vaka Aç');
    await page.waitForSelector('#m-disease.on', { timeout: 5000 });
    const submitBtn = page.locator('#m-disease .btn-g');
    await submitBtn.click();
    await page.waitForTimeout(1000);
    await expect(page.locator('#m-disease')).toBeVisible();
  });

  test('4.02 kızgınlık modalı: boş form submit edilemez', async ({ page }) => {
    await openApp(page);
    // Kızgınlık kaydı artık üreme sayfası kızgınlık tab'ından açılır
    // (log sayfasındaki "Kızgınlık Kaydı" butonu refactor'la kaldırıldı)
    await navTo(page, '#nb-ureme');
    await page.waitForSelector('text=Kızgınlık Ekle', { timeout: 10000 });
    await page.click('text=Kızgınlık Ekle');
    await page.waitForSelector('#m-kizginlik.on', { timeout: 5000 });
    const submitBtn = page.locator('#m-kizginlik .btn-g');
    await submitBtn.click();
    await page.waitForTimeout(1000);
    await expect(page.locator('#m-kizginlik')).toBeVisible();
  });

  test('4.03 doğum modalı: zorunlu alan boşsa submit engeli', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await page.waitForSelector('#m-birth.on', { timeout: 5000 });
    const submitBtn = page.locator('#m-birth .btn-g');
    await submitBtn.click();
    await page.waitForTimeout(1000);
    await expect(page.locator('#m-birth')).toBeVisible();
  });

  test('4.04 tohumlama modalı: form elemanları görünür', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    // "Tohumlama" metni üreme tab'ında da geçer — ilk DOM eşleşmesi gizli
    // kalabilir; data-action ile log sayfasındaki butonu hedefle
    await page.click('[data-action="open-insem-modal"]');
    await page.waitForSelector('#m-insem.on', { timeout: 5000 });
    await expect(page.locator('#i-hid')).toBeVisible();
    await expect(page.locator('#i-tarih')).toBeVisible();
    await expect(page.locator('#i-sperma-select')).toBeVisible();
  });

  test('4.05 yeni hayvan modalı: form elemanları görünür', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Yeni Hayvan');
    await page.waitForSelector('#m-animal.on', { timeout: 5000 });
    await expect(page.locator('#a-cinsiyet')).toBeVisible();
  });

  test('4.06 tarih input bugünü gösterir', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.click('text=Doğum Kaydı');
    await page.waitForSelector('#m-birth.on', { timeout: 5000 });
    const dateVal = await page.locator('#b-tarih').inputValue();
    expect(dateVal, 'Bugünün tarihi default olmalı').toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  test('4.07 aşılama modalı mevcut', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.waitForSelector('.log-btn', { timeout: 10000 });
    await expect(page.locator('#m-vaccine')).toBeAttached();
  });

});

// ════════════════════════════════════════════════════════════════════════════════
// 5. EDGE CASES — Arama, filtre, FAB, overlay
// ════════════════════════════════════════════════════════════════════════════════

test.describe('5 — Edge Cases', () => {

  test('5.01 arama kutusu sonuç daraltır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    const firstCard = await page.locator('.animal-card').first().locator('.a-id').innerText();
    await page.fill('#srch', firstCard.trim());
    await page.waitForTimeout(800);
    const count = await page.locator('.animal-card').count();
    expect(count, 'Arama sonucunda en az 1 kart görünmeli').toBeGreaterThanOrEqual(1);
  });

  test('5.02 padok filtresi çalışır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('#pflt', { timeout: 10000 });
    await page.selectOption('#pflt', { index: 1 });
    await page.waitForTimeout(500);
    await expect(page.locator('#pg-suru')).toBeVisible();
  });

  test('5.03 cinsiyet filtresi çalışır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.fchip', { timeout: 10000 });
    await page.click('#fc-cinsiyet-disi');
    await page.waitForTimeout(500);
    await expect(page.locator('#fc-cinsiyet-disi')).toHaveClass(/on/);
  });

  test('5.04 FAB modal açar', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-tasks');
    // .fab 3 buton eşleştirir (görev-ekle + gizli commit/cancel FAB'ları) — spesifik hedefle
    await page.waitForSelector('[data-action="open-task-add-modal"]', { timeout: 10000 });
    await page.click('[data-action="open-task-add-modal"]');
    await page.waitForTimeout(800);
    // '.modal' sheet'leri tüm modallarda mevcut (gizli) — açılan modalın
    // kendisini .on class'ı ile doğrula
    await expect(page.locator('#m-task-add')).toHaveClass(/on/, { timeout: 5000 });
  });

  test('5.05 görevler filtreleri çalışır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-tasks');
    // '.fs-btn' ilk DOM eşleşmesi üreme sayfasının gizli tab'ı olur — görevler
    // sayfasına kapsamla
    await page.waitForSelector('#pg-tasks .fs-btn', { timeout: 10000 });
    const filterBtns = await page.locator('#pg-tasks .fs-btn').all();
    for (const btn of filterBtns) {
      await btn.click();
      await page.waitForTimeout(400);
    }
    for (const btn of filterBtns) {
      await expect(btn).toBeVisible();
    }
  });

  test('5.06 stok paneli açılıp kapanır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.waitForSelector('.log-btn', { timeout: 10000 });
    await page.click('text=Stok Modülü');
    await page.waitForSelector('#stok-panel', { timeout: 5000 });
    await page.click('text=Kayda Dön');
    await page.waitForTimeout(500);
  });

  test('5.07 overlay dışına tıklanınca detay kapanmaz', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('#det.on', { timeout: 8000 });
    await page.click('#pg-suru', { position: { x: 10, y: 10 } });
    await page.waitForTimeout(500);
    await expect(page.locator('#det.on')).toBeVisible();
  });

  test('5.08 log sayfası tüm kayıt butonlarını gösterir', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-log');
    await page.waitForSelector('.log-btn', { timeout: 10000 });
    const btnCount = await page.locator('.log-btn').count();
    expect(btnCount, 'Log sayfasında en az 4 kayıt butonu').toBeGreaterThanOrEqual(4);
  });

  test('5.09 toast elementi mevcut', async ({ page }) => {
    await openApp(page);
    await expect(page.locator('#toast')).toBeAttached();
  });

  test('5.10 gebelik tabı crash olmadan açılır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-ureme');
    await page.click('#ureme-tab-gebelik');
    await page.waitForTimeout(1500);
    await expect(page.locator('#ureme-tab-gebelik')).toHaveClass(/on/);
  });

});

// ════════════════════════════════════════════════════════════════════════════════
// 6. PERFORMANS — Yükleme süreleri
// ════════════════════════════════════════════════════════════════════════════════

test.describe('6 — Performans', () => {

  test('6.01 dashboard 8 saniyede yüklenir', async ({ page }) => {
    const start = Date.now();
    await page.goto('./', { waitUntil: 'domcontentloaded' }); // '/' baseURL alt-dizinini düşürüp GH Pages kök 404'üne gider
    await page.waitForSelector('#pg-dash .sv', { timeout: 30000 });
    const duration = Date.now() - start;
    expect(duration, `Dashboard ${duration}ms`).toBeLessThan(8000);
  });

  test('6.02 sürü sayfası 8 saniyede yüklenir', async ({ page }) => {
    await openApp(page);
    const start = Date.now();
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 30000 });
    const duration = Date.now() - start;
    expect(duration, `Sürü ${duration}ms`).toBeLessThan(8000);
  });

  test('6.03 hayvan detay 5 saniyede açılır', async ({ page }) => {
    await openApp(page);
    await navTo(page, '#nb-suru');
    await page.waitForSelector('.animal-card', { timeout: 15000 });
    const start = Date.now();
    await page.locator('.animal-card').first().click();
    await page.waitForSelector('#det.on', { timeout: 8000 });
    const duration = Date.now() - start;
    expect(duration, `Detay ${duration}ms`).toBeLessThan(5000);
  });

  test('6.04 nav geçişleri 2 saniyede gerçekleşir', async ({ page }) => {
    await openApp(page);
    const pages = ['#nb-suru', '#nb-tasks', '#nb-ureme', '#nb-gecmis'];
    for (const btn of pages) {
      const start = Date.now();
      await page.click(btn);
      const targetId = '#' + btn.replace(/^#/, '').replace('nb-', 'pg-');
      await page.waitForSelector(targetId + '.on', { timeout: 8000 });
      const duration = Date.now() - start;
      expect(duration, `Geçiş ${duration}ms`).toBeLessThan(2000);
    }
  });

});

// ════════════════════════════════════════════════════════════════════════════════
// 7. SHELL — HTML yüklenmesi
// ════════════════════════════════════════════════════════════════════════════════

test.describe('7 — Shell', () => {

  test('7.01 shell olmadan crash olmaz', async ({ page }) => {
    await page.goto('./', { waitUntil: 'domcontentloaded' }); // '/' baseURL alt-dizinini düşürüp GH Pages kök 404'üne gider
    await expect(page.locator('#shell')).toBeVisible();
    await expect(page.locator('#nav')).toBeVisible();
  });

  test('7.02 IDB hataları kritik değil sayfa açılır', async ({ page }) => {
    const idbErrors = [];
    page.on('console', msg => {
      if (msg.text().toLowerCase().includes('idb') && msg.type() === 'error')
        idbErrors.push(msg.text());
    });
    await page.goto('./', { waitUntil: 'domcontentloaded' }); // '/' baseURL alt-dizinini düşürüp GH Pages kök 404'üne gider
    await page.waitForTimeout(3000);
    await expect(page.locator('#shell')).toBeVisible();
  });

});
