// tests/offline-kuyruk.spec.js
// EgeSüt ERP — Offline kuyruk + replay savunma hattı (Idle-B, 2026-09-01)
//
// Kilitlediği fix — commit ef523c4 (api.js senkron katmanı paketi):
//   B17 — syncNow zehirli kuyruk: ilk kalıcı hata break yerine ATLA-DEVAM;
//        op başına 5 ardışık hata sonrası dead-letter (atlanır, kuyrukta kalır).
//        B17 öncesi tek hatalı kayıt, sonraki TÜM offline yazmaların sonsuza
//        dek yerel kalmasına yol açıyordu.
//
// Yöntem: çevrimdışı geç (gerçek modda context.setOffline) → kayıt oluştur
// (write() → IDB _queue) → kuyruktaki İLK op'un tablosunu var olmayan tabloya
// çevir (zehirli) → çevrimiçi ol → 'online' event syncNow'u tetikler →
// zehirliden SONRAKİ kayıt backend'e ulaşmalı.
// Yazma hedefi: gerçek modda demo klon DB (kullanıcı onaylı), stub modunda
// tarayıcı-içi sahte backend — prod asla değil.

import { test, expect, openApp, navTo, toastText, goOffline, goOnline,
         gorevReachedBackend, IS_DEMO } from './support/app.js';

test.skip(!IS_DEMO, 'demo-mode savunma hattı: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

async function kuyrukUzunluk(page) {
  return page.evaluate(async () => (await getQueue()).length);
}

// Çevrimdışiyken manuel görev oluştur → write() offline kuyruğa (IDB _queue) yazar
async function offlineGorevEkle(page, aciklama) {
  const bugunStr = await page.evaluate(() => bugun());
  await page.click('[data-action="open-task-add-modal"]');
  await expect(page.locator('#m-task-add')).toHaveClass(/on/);
  await page.fill('#ta-desc', aciklama);
  await page.fill('#ta-tarih', bugunStr);
  await page.click('[data-action="submit-task-add"]');
  await expect.poll(() => toastText(page), { timeout: 10000 }).toContain('Görev oluşturuldu');
  await expect(page.locator('#m-task-add')).not.toHaveClass(/on/);
}

// Kuyruktaki marker'lı op'un tablo adını var olmayana çevirir (zehirli kayıt)
async function kuyruguZehirle(page, marker) {
  return page.evaluate((m) => new Promise((resolve, reject) => {
    const req = indexedDB.open('egesut_v12');
    req.onsuccess = (e) => {
      try {
        const d = e.target.result;
        const tx = d.transaction('_queue', 'readwrite');
        const st = tx.objectStore('_queue');
        const getAll = st.getAll();
        getAll.onsuccess = () => {
          const hedef = getAll.result.find(o => (o.data || []).some(r => (r.aciklama || '').includes(m)));
          if (!hedef) { resolve(false); return; }
          hedef.table = 'e2e_tablo_yok_x'; // INSERT her seferinde kalıcı hata verir
          st.put(hedef);
          resolve(true);
        };
        tx.onerror = () => reject(tx.error);
      } catch (err) { reject(err); }
    };
    req.onerror = () => reject(req.error);
  }), marker);
}

// ═════════════════════════════════════════════════════════════════════════════
// Temel replay — offline kayıt → online → kuyruk boşalır, backend'e düşer
// ═════════════════════════════════════════════════════════════════════════════

test('offline görev → online → kuyruk boşalır, kayıt backend\'e ulaşır', async ({ page }) => {
  await openApp(page); // çevrimiçi: oturum + ilk pull
  const MARKER = `E2E-OFLINE-TEMEL-${Date.now()}`;

  await goOffline(page);
  await navTo(page, '#nb-tasks');
  await offlineGorevEkle(page, MARKER);

  // Sync bar: bekleyen kayıt görünür
  await expect(page.locator('#sync-bar')).toHaveClass(/on/);
  expect(await kuyrukUzunluk(page)).toBeGreaterThanOrEqual(1);

  // Online → 'online' event → syncNow + pullFromSupabase
  await goOnline(page);
  await expect.poll(() => kuyrukUzunluk(page), { timeout: 30000 }).toBe(0);
  await expect(page.locator('#sync-bar')).not.toHaveClass(/on/);

  await expect.poll(() => gorevReachedBackend(MARKER), { timeout: 30000 }).toBe(true);
});

// ═════════════════════════════════════════════════════════════════════════════
// B17 — zehirli kayıt kuyruğu bloklamaz: sonraki kayıtlar backend'e ulaşır
// ═════════════════════════════════════════════════════════════════════════════

test('B17: tek zehirli kayıt diğer offline kayıtların replay\'ini bloklamaz', async ({ page }) => {
  await openApp(page);
  const ZEHIRLI = `E2E-OFLINE-ZEHIR-${Date.now()}`;
  const IYI = `E2E-OFLINE-IYI-${Date.now()}`;

  await goOffline(page);
  await navTo(page, '#nb-tasks');

  // Zehirli kayıt ÖNCE (kuyrukta iyi kayıttan önce dursun — B17 tam senaryosu)
  await offlineGorevEkle(page, ZEHIRLI);
  await offlineGorevEkle(page, IYI);
  expect(await kuyrukUzunluk(page)).toBeGreaterThanOrEqual(2);

  // İlk op'u zehirle: tablo adı geçersiz → INSERT kalıcı hata
  const zehirlendi = await kuyruguZehirle(page, ZEHIRLI);
  expect(zehirlendi, 'zehirli op kuyrukta bulunup işaretlenmeli').toBe(true);

  // Online → replay: zehirli op KALIR (dead-letter adayı) ama İYİ kayıt
  // geçmeli — B17 öncesi ilk hata drain'i kırıyordu
  await goOnline(page);

  await expect.poll(() => gorevReachedBackend(IYI), { timeout: 30000 }).toBe(true);

  // Zehirli op backend'e GİTMEDİ (bilinçli) ama kuyrukta tek başına kaldı —
  // diğerlerini bloklamadığının kanıtı
  await expect.poll(() => kuyrukUzunluk(page), { timeout: 30000 }).toBe(1);
  const qHepsi = await page.evaluate(async () => (await getQueue()).map(o => o.table));
  expect(qHepsi).toEqual(['e2e_tablo_yok_x']);
  expect(await gorevReachedBackend(ZEHIRLI), 'zehirli kayıt backend\'e gönderilmemeli').toBe(false);

  // Sync bar hâlâ uyarmalı (1 kayıt bekliyor) — sessizce yutulmaz; kullanıcı
  // Veri Trafik panelinden görüp manuel 'Gönder'debilir
  await expect(page.locator('#sync-bar')).toHaveClass(/on/);
});
