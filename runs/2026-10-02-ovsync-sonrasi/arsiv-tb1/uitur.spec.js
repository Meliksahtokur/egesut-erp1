// uitur.spec.js — ui-tur GOREV: 25 maddelik UI test turu (sahibe demo ÖNCESİ kapı).
// Liste: runs/2026-09-28-ovsync-takip/ui-test-listesi.md (SÖZLEŞME metinler birebir).
// Desen kaynağı: tests/e2e/ovsync-takip.spec.js (P12) — local-server + EGESUT_DEMO
// initScript(storageState) + IDB pull bekleme + E2E marker fixture/temizlik.
// ÜRÜN KODUNA DOKUNULMAZ — FAIL rapor edilir, düzeltilmez.
//
// Koşum: worktree kökünde `python3 -m http.server 8137 --bind 127.0.0.1`;
// docker: mcr.microsoft.com/playwright:v1.58.2-noble --network host, /work=worktree,
// /main=ana checkout (NODE_PATH), /agents=bu klasör. --workers=1 ZORUNLU.

import { test, expect, openApp, navTo, goOffline, goOnline } from '/work/tests/support/app.js';
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
const MARKER = 'E2E-UITUR-';
const ART = '/work/runs/2026-09-28-ovsync-takip/artifacts';

const trBugun = () => new Date(Date.now() + 3 * 3600e3).toISOString().slice(0, 10);
const trGun = n => new Date(Date.now() + 3 * 3600e3 + n * 864e5).toISOString().slice(0, 10);
const trSaat = () => new Date(Date.now() + 3 * 3600e3).toISOString().slice(11, 16); // HH:MM

let db;
let S = {}; // seed kayıtları

test.setTimeout(150000);

async function shot(page, name, fullPage = true) {
  await page.screenshot({ path: `${ART}/${name}.png`, fullPage });
}

// ── DB yardımcıları ──────────────────────────────────────────────────────────
async function dbTek(tablo, sutun, deger, sutunlar = '*') {
  const { data } = await db.from(tablo).select(sutunlar).eq(sutun, deger);
  return data?.[0] ?? null;
}
async function dbBekle(fn, ms = 15000) {
  const son = Date.now() + ms;
  while (Date.now() < son) {
    const r = await fn();
    if (r) return r;
    await new Promise(t => setTimeout(t, 400));
  }
  return null;
}

// ── Sayfa yardımcıları ───────────────────────────────────────────────────────
async function ovAc(page) {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
}
async function idbGorevBekle(page, gorevId, ms = 45000) {
  await expect.poll(async () => page.evaluate(async mid => {
    if (!window.idbGetAll) return false;
    const gs = await window.idbGetAll('gorev_log');
    return gs.some(g => g && g.id === mid);
  }, gorevId), { timeout: ms, intervals: [500, 2000] }).toBe(true);
}
async function devamSeciciAc(page, ad) {
  await navTo(page, '#nb-ureme');
  await page.click('#ureme-tab-tohumlama');
  await page.fill('#tohumlama-srch', S[ad].kupe);
  const satir = page.locator('#ureme-body .hist-row', { hasText: S[ad].kupe }).first();
  await expect(satir).toBeVisible({ timeout: 10000 });
  await satir.click();
  await expect(page.locator('#m-toh-det')).toHaveClass(/on/);
  await page.check('input[name="toh-sonuc"][value="Boş"]');
  await page.click('[data-action="toh-sonuc-kaydet"]');
  await expect(page.locator('#devam-secici-bs')).toBeVisible({ timeout: 10000 });
}
async function seciciKapat(page) {
  await page.locator('#devam-secici-bs').click({ position: { x: 5, y: 5 } });
  await expect(page.locator('#devam-secici-bs')).toHaveCount(0, { timeout: 8000 });
}

// ── Fixture ──────────────────────────────────────────────────────────────────
const HAYVAN = { a:1,b:2,b1:3,b2:4,b3:5,b4:6,b5:7,b6:8,b7:9,c:10,c2:11,e:12,f:13,h:14,i:15,
  k:16,m:17,q:18,r:19,s4:20,w:21,y:22,z:23,p:24,pz:25,pe:26,g:27 };
const TOH_NO = { a:1,b:2,c:3,c2:4,e:5,f:6,h:7,i:8,k:9,m:10,q:11,s4:12,w:13,y:14,z:15,p:16,pz:17,pe:18,i2:19,p2:20,g:21,r:22 };
const GOREV_NO = { c:1,c2:2,h:3,i:4,q:5,m:6,e:7,b:8,r:9,p:10,pz:11,pe:12,g:13 };
const BASLAT_NO = { r:1,b1:2,b2:3,b3:4,b4:5,b5:6,b6:7,b7:8 };

test.beforeAll(async () => {
  db = createClient(DEMO_URL, DEMO_KEY);
  const { error } = await db.auth.signInWithPassword(DEMO_LOGIN);
  if (error) throw new Error(`demo giriş başarısız: ${error.message}`);
  S = JSON.parse(readFileSync('/agents/fixture-state.json', 'utf8'));
});


// ══ M1 — 6. stat hücresi ══════════════════════════════════════════════════════
test('M1: dashboard 6. stat hücresi (T-56) — hücre + .sv + sınıf kuralı + goTo', async ({ page }) => {
  await openApp(page);
  const hucre = page.locator('.dash-row .sc', { hasText: 'Ovsync' });
  await expect(hucre).toHaveCount(1);
  await expect(hucre).toContainText('🔄 Ovsync ›');
  const beklenen = await page.evaluate(async () => {
    const veri = await window.rpc('ovsync_takip_listele', { p_padok: null });
    const kpa = veri.kpa;
    const mv = (veri.satirlar || []).filter(s => s?.bolum === 'S2'
      && s?.muayene && typeof s.muayene.kalan_gun === 'number' && s.muayene.kalan_gun <= 0).length;
    const n = x => (typeof x === 'number' && isFinite(x) ? x : null);
    let sinif = 'warn';
    if (n(kpa.bugun) !== null && n(kpa.geciken) !== null && n(kpa.bekleyen_baslatma) !== null) {
      sinif = (kpa.bugun > 0 || kpa.geciken > 0 || mv > 0) ? 'alert' : (kpa.bekleyen_baslatma > 0 ? 'warn' : 'ok');
    }
    return { sinif, sayi: kpa.aktif };
  });
  const cls = await hucre.getAttribute('class');
  const sv = (await hucre.locator('.sv').innerText()).trim();
  expect(cls, `hücre sınıfı ${cls} — kural: ${beklenen.sinif} (kpa: ${JSON.stringify(beklenen)})`).toContain(beklenen.sinif);
  expect(sv).toBe(String(beklenen.sayi));
  await shot(page, 'uitur-01-dash-6hucre', false);
  await hucre.click();
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
});

// ══ M2 — KPA şeridi ═══════════════════════════════════════════════════════════
test('M2: KPA şeridi (T-59) — 5 hücre küçük harf; sayılar RPC kpa eşit; ovs-one; (N takipte)', async ({ page }) => {
  await ovAc(page);
  const kpa = await page.evaluate(() => window.__ovsyncTakip.veri.kpa);
  await expect(page.locator('#pg-ovsync .ovs-kpa-c')).toHaveCount(5);
  const etiketler = ['aktif', 'bugün', 'geciken', 'muayene bekleyen', 'bekleyen başlatma'];
  for (const k of etiketler) {
    await expect(page.locator('#pg-ovsync .ovs-kpa', { hasText: k })).toBeVisible();
  }
  const hucreler = await page.evaluate(() =>
    [...document.querySelectorAll('#pg-ovsync .ovs-kpa-c')].map(c => ({
      b: c.querySelector('b')?.textContent?.trim(),
      s: c.querySelector('span')?.textContent?.trim(),
      one: c.classList.contains('ovs-one'),
    })));
  const alanlar = ['aktif', 'bugun', 'geciken', 'muayene_bekleyen', 'bekleyen_baslatma'];
  hucreler.forEach((h, i) => {
    expect(h.s, `etiket ${i}`).toBe(etiketler[i]);
    expect(h.b, `kpa.${alanlar[i]} ⇔ DOM`).toBe(String(kpa[alanlar[i]]));
  });
  expect(hucreler[1].one).toBe(kpa.bugun > 0);
  const bbHucre = hucreler[4];
  const takipteSpan = await page.locator('#pg-ovsync .ovs-kpa-c', { hasText: 'bekleyen başlatma' }).locator('span').allInnerTexts();
  if ((kpa.bekleyen_baslatma_takipte ?? 0) > 0) {
    expect(takipteSpan.join(' ')).toContain(`(${kpa.bekleyen_baslatma_takipte} takipte)`);
  } else {
    expect(bbHucre.s).not.toContain('takipte');
  }
  await shot(page, 'uitur-02-kpa-seridi', false);
});

// ══ M3 — S0–S4 bölümleri ══════════════════════════════════════════════════════
test('M3: S0–S4 bölümleri (T-32) — başlık kümesi=satır kümesi; boş gizli; S3 ilk 5+tümü; S4 katlanır', async ({ page }) => {
  await ovAc(page);
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 20000 });
  const karsilastir = await page.evaluate(() => {
    const satirKume = new Set(window.__ovsyncTakip.veri.satirlar
      .map(s => s?.bolum).filter(b => /^S[0-4]$/.test(String(b))));
    const basliklar = [...document.querySelectorAll('#pg-ovsync .ovs-bolum h2')]
      .map(h => (h.textContent || '').trim().match(/^(S[0-4])/)?.[1]).filter(Boolean);
    return { satir: [...satirKume].sort(), baslik: [...new Set(basliklar)].sort() };
  });
  expect(karsilastir.baslik, `başlıklar ${karsilastir.baslik} ⇔ satırlar ${karsilastir.satir}`)
    .toEqual(karsilastir.satir);
  for (const b of ['S0 · Bugün & Geciken', 'S1 · Aktif zincirler', 'S2 · Sonuç bekleyenler', 'S3 · Başlatılmayı bekleyenler', 'S4 · Sonlananlar']) {
    await expect(page.locator('#pg-ovsync .ovs-bolum h2', { hasText: b })).toBeVisible();
  }
  // S3: ilk 5 + tümü (M)
  const s3Toplam = await page.evaluate(() =>
    window.__ovsyncTakip.veri.satirlar.filter(s => s.bolum === 'S3').length);
  expect(s3Toplam).toBeGreaterThan(5);
  await expect(page.locator('#pg-ovsync .ovs-s3-satir')).toHaveCount(5);
  await expect(page.locator('#pg-ovsync .ovs-daha')).toHaveText(`tümü (${s3Toplam})`);
  await page.click('#pg-ovsync .ovs-daha');
  await expect(page.locator('#pg-ovsync .ovs-s3-satir')).toHaveCount(s3Toplam);
  await expect(page.locator('#pg-ovsync .ovs-daha')).toHaveText('küçült');
  // S4: katlanır (varsayılan kapalı) — satır yok, açınca gelir
  await expect(page.locator('#pg-ovsync .ovs-s4-kart')).toHaveCount(0);
  await page.locator('#pg-ovsync .ovs-bolum h2', { hasText: 'S4' }).locator('.ovs-katla').click();
  await expect(page.locator('#pg-ovsync .ovs-s4-kart').first()).toBeVisible({ timeout: 15000 });
  await expect(page.locator('#pg-ovsync .ovs-s4-kart').first()).toContainText(S.s4.kupe);
  await shot(page, 'uitur-03-bolumler-s4-acik');
  await page.evaluate(() => { window._curOvsyncBolum = { acik: {} }; });
});

// ══ M4 — 🔔 köprüsü + Görevler ════════════════════════════════════════════════
test('M4: 🔔 "Tüm takibi aç →" + Görevler "Tüm ovsync takibi →" + takip görevi 🌱 Üreme çipinde (T-57)', async ({ page }) => {
  await openApp(page);
  await expect(page.locator('#dash-body', { hasText: '🌱 İlk Tohumlama (' })).toBeVisible();
  const link = page.getByRole('button', { name: 'Tüm takibi aç →' }).first();
  await expect(link).toBeVisible();
  await shot(page, 'uitur-04a-dash-ilk-tohumlama', false);
  await link.click();
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  await navTo(page, '#nb-tasks');
  await page.click('[data-action="task-kat-ureme"]');
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  const kopru = page.locator('#task-ureme-kopru');
  await expect(kopru).toBeVisible();
  await expect(kopru).toHaveText('Tüm ovsync takibi →');
  await idbGorevBekle(page, S.b.takipId);
  await expect(page.locator(`#tc-${S.b.takipId}`)).toBeVisible({ timeout: 10000 });
  await shot(page, 'uitur-04b-gorevler-ureme-kopru', false);
});

// ══ M5 — Sayı eşitliği ════════════════════════════════════════════════════════
test('M5: sayı eşitliği (kabul 9) — 🔔 🌱 sayısı = KPA bekleyen-başlatma = S3 kart', async ({ page }) => {
  await openApp(page);
  const dashBant = page.locator('#dash-body div', { hasText: '🌱 İlk Tohumlama (' }).first();
  await expect(dashBant).toBeVisible();
  const m1 = await dashBant.innerText();
  const dashN = Number((m1.match(/🌱 İlk Tohumlama \((\d+)/) || [])[1]);
  expect(dashN, 'dashboard uyarı sayısı okunamadı: ' + m1).toBeGreaterThan(0);
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  const kpa = await page.evaluate(() => window.__ovsyncTakip.veri.kpa);
  const s3Gorunen = await page.locator('#pg-ovsync .ovs-s3-satir').count();
  const s3Toplam = await page.evaluate(() =>
    window.__ovsyncTakip.veri.satirlar.filter(s => s.bolum === 'S3').length);
  const fark = {
    dashUyari: dashN,
    kpaBekleyenBaslatma: kpa.bekleyen_baslatma,
    s3Toplam, s3Gorunen,
    kpaTakipte: kpa.bekleyen_baslatma_takipte,
  };
  // Sözleşme: KPA sayısı = S3 kart sayısı (aynı anda); 🔔 uyarılar alt kümesi;
  // pencere içindeki tüm bekleyenler uyarıda da görünmeli.
  expect(kpa.bekleyen_baslatma, 'KPA ⇔ S3 toplam').toBe(s3Toplam);
  const inWindow = await page.evaluate(() => {
    const bugun = new Date(Date.now() + 3 * 3600e3).toISOString().slice(0, 10);
    const plus = d => new Date(Date.parse(bugun) + d * 864e5).toISOString().slice(0, 10);
    const w = [plus(0), plus(1), plus(2)];
    return window.__ovsyncTakip.veri.satirlar.filter(s => s.bolum === 'S3'
      && w.includes(String(s.dalga_anahtari || '').slice(0, 10))).length;
  });
  expect(dashN, `🔔 uyarı sayısı ⇔ pencere içi S3 (${JSON.stringify(fark)}; pencere içi ${inWindow})`).toBe(inWindow);
  await shot(page, 'uitur-05-ovsync-s3-sayi', false);
});

// ══ M6 — Devam seçici ═════════════════════════════════════════════════════════
test('M6: devam seçici (T-01/T-07) — başlık, Sonuç Güncelle, 3 kart, buton etiketleri, alt not', async ({ page }) => {
  await openApp(page);
  await devamSeciciAc(page, 'f');
  const secici = page.locator('#devam-secici-bs');
  await expect(secici).toContainText(/TAI \d{2}\.\d{2} · \d+\. deneme \(bu laktasyon\)/);
  await expect(secici).toContainText('Sonuç Güncelle');
  await expect(secici).toContainText('❌ Boş');
  await expect(secici).toContainText('Devam nasıl olsun? (zorunlu)');
  expect(await page.evaluate(() => window.__devamSecici?.secim)).toBe('OVSYNC');
  const kartlar = secici.locator('[data-action="devam-secici-sec"]');
  await expect(kartlar).toHaveCount(3);
  await expect(secici.locator('input[type="radio"]')).toHaveCount(0);
  for (const [secim, etiket] of [['OVSYNC', '🔄 Ovsync uygula'], ['PG', '💉 PG uygula'], ['TAKIP', '🔍 Takibe bırak']]) {
    await expect(secici.locator(`[data-secim="${secim}"]`)).toContainText(etiket);
  }
  await expect(secici.locator('[data-secim="OVSYNC"]')).toContainText('hemen');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + Ovsync başlat');
  await expect(secici).toContainText('Sonuç kaydı ve seçilen devam adımı tek işlemde yapılır');
  await expect(page.locator('#m-toh-det')).not.toHaveClass(/on/);
  await shot(page, 'uitur-06-devam-secici-ovsync');
  await page.click('[data-action="devam-secici-sec"][data-secim="PG"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + PG uygula');
  await page.click('[data-action="devam-secici-sec"][data-secim="TAKIP"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + Takibe bırak');
  await seciciKapat(page);
});

// ══ M7 — PG ön dolu (⚠) ═══════════════════════════════════════════════════════
test('M7: PG ön dolu (T-02 ⚠) — ürün seçili, doz inputu YOK; PG geçmişi olmayanda buton pasif', async ({ page }) => {
  await openApp(page);
  // b: son PG kaydı var → ürün dolu + buton aktif + doz alanı yok
  await devamSeciciAc(page, 'b');
  await page.click('[data-action="devam-secici-sec"][data-secim="PG"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + PG uygula');
  await expect(page.locator('#devam-onayla')).toBeEnabled();
  const urun = await page.locator('#devam-secici-bs select[data-change="devam-urun"]').inputValue();
  expect(urun, 'PG ürünü son kullanılandan dolu olmalı').not.toBe('');
  const pgKartInput = await page.locator('#devam-secici-bs [data-secim="PG"] input').count();
  expect(pgKartInput, 'doz alanı DÜZENLENEBİLİR DEĞİLDİR — PG kartında input yok').toBe(0);
  await shot(page, 'uitur-07a-pg-on-dolu');
  await seciciKapat(page);
  // f: son PG yok → buton pasif (PG_SECIM_GEREKLI UI ikizi)
  await devamSeciciAc(page, 'f');
  await page.click('[data-action="devam-secici-sec"][data-secim="PG"]');
  await expect(page.locator('#devam-onayla')).toBeDisabled();
  await shot(page, 'uitur-07b-pg-secim-gerekli-pasif');
  await seciciKapat(page);
});

// ══ M8 — TAKIP kurulumu (⚠) ═══════════════════════════════════════════════════
test('M8: TAKIP kurulumu (T-03 ⚠) — gün girişi yok; +7 saat=atama anı; S3 🔍 takipte rozet; Üreme çipi', async ({ page }) => {
  await openApp(page);
  await devamSeciciAc(page, 'f');
  const secici = page.locator('#devam-secici-bs');
  // gün girişi İÇERMEZ
  await page.click('[data-action="devam-secici-sec"][data-secim="TAKIP"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + Takibe bırak');
  const takipInput = await secici.locator('[data-secim="TAKIP"] input').count();
  expect(takipInput, 'TAKIP kartı gün girişi İÇERMEZ').toBe(0);
  const kayitAni = trSaat();
  await page.click('#devam-onayla');
  await expect(secici).toHaveCount(0, { timeout: 20000 });
  const gorev = await dbBekle(async () => {
    const g = await db.from('gorev_log')
      .select('id,hedef_tarih,hedef_saat,gorev_tipi,kaynak')
      .eq('hayvan_id', S.f.hayvanId).eq('gorev_tipi', 'TAKIP_MUAYENE').maybeSingle();
    return g ?? null;
  });
  expect(gorev, 'TAKIP görevi kurulmalı').toBeTruthy();
  expect(gorev.hedef_tarih).toBe(trGun(7));
  expect(gorev.hedef_saat, 'saat = atama anı (kayıt ' + kayitAni + ', DB ' + gorev.hedef_saat + ')').toBeTruthy();
  const dkFark = Math.abs(
    (Date.parse('2000-01-01T' + kayitAni + ':00') - Date.parse('2000-01-01T' + String(gorev.hedef_saat).slice(0, 5) + ':00')) / 60000);
  expect(dkFark).toBeLessThanOrEqual(10);
  S.f.yeniTakipId = gorev.id;
  // S3: 🔍 takipte + muayene GG.AA SS:DD rozeti
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  const fSatir = page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.f.kupe });
  await expect(fSatir).toBeVisible({ timeout: 10000 });
  await expect(fSatir).toContainText('🔍 takipte');
  await expect(fSatir).toContainText(/muayene \d{2}\.\d{2} \d{2}:\d{2}/);
  await shot(page, 'uitur-08-s3-takipte-rozet', false);
  // Görevler'de 🌱 Üreme çipinde
  await navTo(page, '#nb-tasks');
  await page.click('[data-action="task-kat-ureme"]');
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  await idbGorevBekle(page, gorev.id);
  await expect(page.locator(`#tc-${gorev.id}`)).toBeVisible({ timeout: 10000 });
});

// ══ M9 — Kilitli Ovsync ═══════════════════════════════════════════════════════
test('M9: kilitli Ovsync (T-14..T-17) — kilit gerekçesi + ön seçim Takibe bırak', async ({ page }) => {
  await openApp(page);
  await devamSeciciAc(page, 'z');
  const secici = page.locator('#devam-secici-bs');
  const kilit = await page.evaluate(() => window.__devamSecici?.kilit);
  expect(kilit?.kilitli, 'kural günü gelmemiş hayvanda Ovsync kilitli: ' + JSON.stringify(kilit)).toBe(true);
  await expect(secici.locator('[data-secim="OVSYNC"]')).toContainText(/Kural günü|Kısır/);
  expect(await page.evaluate(() => window.__devamSecici?.secim)).toBe('TAKIP');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + Takibe bırak');
  await shot(page, 'uitur-09-ovsync-kilitli');
  await seciciKapat(page);
});

// ══ M10 — PG kapısı (hızlı-PG yolu) ═══════════════════════════════════════════
test('M10: PG kapısı (T-06) — hızlı-PG redsi #pg-kapi-bs; "Boş ata ve uygula" tek sarmal işlem', async ({ page }) => {
  await openApp(page);
  await page.evaluate(hid => window._hayvanHizliUygulama(hid), S.k.hayvanId);
  await expect(page.locator('#proto-mini')).toBeVisible();
  await page.selectOption('#pu-stok', { label: 'PGs (alke)' });
  await page.fill('#pu-doz', '5');
  await page.click('#pu-kaydet-btn');
  const sheet = page.locator('#pg-kapi-bs');
  await expect(sheet).toBeVisible({ timeout: 10000 });
  await expect(sheet).toContainText('Son tohumlama sonucu Bekliyor');
  const onayla = page.locator('#pg-kapi-onayla');
  await expect(onayla).toHaveText('Boş ata ve uygula');
  await expect(onayla).toBeDisabled();
  await page.fill('#pg-kapi-gerekce', 'UITUR M10 gerekce: 35. gun kontrolu negatif');
  await expect(onayla).toBeEnabled();
  await shot(page, 'uitur-10-pg-kapi-sheet', false);
  await onayla.click();
  const toh = await dbBekle(async () => {
    const t = await dbTek('tohumlama', 'id', S.k.tohId, 'sonuc');
    return t?.sonuc === 'Boş' ? t : null;
  });
  expect(toh, 'Boş ataması yazılmalı').toBeTruthy();
  const pgEvent = await dbBekle(async () => {
    const { data } = await db.from('pg_application_event').select('id').eq('hayvan_id', S.k.hayvanId);
    return data?.length ? data[0] : null;
  });
  expect(pgEvent, 'PG uygulaması aynı işlemde yazılmalı (tek transaction)').toBeTruthy();
});

// ══ M11 — TAKIP_ACIK onay sheet (yalın; Vazgeç + Evet) ═══════════════════════
test('M11: TAKIP_ACIK sheet (T-20/T-21) — app bottom-sheet, tarih/saat DOLU; Vazgeç yazmasız; Evet kapatır', async ({ page }) => {
  await openApp(page);
  let nativeDialog = false;
  page.on('dialog', d => { nativeDialog = true; d.dismiss().catch(() => {}); });
  await devamSeciciAc(page, 'b');
  await page.click('[data-action="devam-secici-sec"][data-secim="PG"]');
  await page.click('#devam-onayla');
  const sheet = page.locator('#takip-acik-bs');
  await expect(sheet).toBeVisible({ timeout: 10000 });
  await expect(sheet).toContainText('🔍');
  await expect(sheet).toContainText('Bu hayvan takipte');
  await expect(sheet).toContainText(S.b.kupe);
  await expect(sheet).toContainText(/rektal muayene takibinde/);
  await expect(sheet).toContainText(/\d{2}\.\d{2} 09:00'te rektal muayene takibinde\./);
  await expect(page.locator('#takip-acik-onayla')).toHaveText('Evet, takibi kapat ve uygula');
  await expect(sheet.getByRole('button', { name: 'Vazgeç' })).toBeVisible();
  expect(nativeDialog, 'native confirm()/alert() YASAK').toBe(false);
  await shot(page, 'uitur-11a-takip-acik-yalin-dolu');
  await sheet.getByRole('button', { name: 'Vazgeç' }).click();
  await expect(sheet).toHaveCount(0);
  let toh = await dbTek('tohumlama', 'id', S.b.tohId, 'sonuc');
  expect(toh?.sonuc).toBe('Bekliyor');
  let gorev = await dbTek('gorev_log', 'id', S.b.takipId, 'tamamlandi,iptal');
  expect(gorev?.tamamlandi).toBe(false);
  expect(gorev?.iptal).toBe(false);
  // Evet → takip kapanır + işlem uygulanır
  await devamSeciciAc(page, 'b');
  await page.click('[data-action="devam-secici-sec"][data-secim="PG"]');
  await page.click('#devam-onayla');
  await expect(page.locator('#takip-acik-bs')).toBeVisible({ timeout: 10000 });
  await page.click('#takip-acik-onayla');
  gorev = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.b.takipId, 'tamamlandi,iptal,takip_kapanis_nedeni');
    return g?.takip_kapanis_nedeni ? g : null;
  });
  expect(gorev, 'takip kapanmalı (neden PG)').toBeTruthy();
  expect(gorev.takip_kapanis_nedeni).toBe('PG');
  toh = await dbBekle(async () => {
    const t = await dbTek('tohumlama', 'id', S.b.tohId, 'sonuc');
    return t?.sonuc === 'Boş' ? t : null;
  });
  expect(toh, 'Boş ataması yazılmalı').toBeTruthy();
  const pgEvent = await dbBekle(async () => {
    const { data } = await db.from('pg_application_event').select('id').eq('hayvan_id', S.b.hayvanId);
    return data?.length ? data[0] : null;
  });
  expect(pgEvent, 'PG uygulaması yazılmalı').toBeTruthy();
  await shot(page, 'uitur-11b-takip-acik-evet-sonrasi', false);
});

// ══ M12 — Birleşik kapı ═══════════════════════════════════════════════════════
test('M12: birleşik kapı (S-4/T-86) — TEK sheet, iki gerekçe alt alta, TEK onay, tarih/saat dolu', async ({ page }) => {
  await openApp(page);
  await page.evaluate(hid => window._hayvanHizliUygulama(hid), S.m.hayvanId);
  await expect(page.locator('#proto-mini')).toBeVisible();
  await page.selectOption('#pu-stok', { label: 'PGs (alke)' });
  await page.fill('#pu-doz', '5');
  await page.click('#pu-kaydet-btn');
  const sheet = page.locator('#takip-acik-bs');
  await expect(sheet).toBeVisible({ timeout: 10000 });
  await expect(page.locator('#pg-kapi-bs')).toHaveCount(0);
  await expect(sheet).toContainText('Bu hayvan takipte');
  await expect(sheet).toContainText('💉 PG kapısı:');
  await expect(sheet).toContainText('🔍 Rektal muayene takibi:');
  await expect(sheet).toContainText(/\d{2}\.\d{2} 09:30/);
  await expect(page.locator('#takip-acik-onayla')).toHaveCount(1);
  await expect(sheet.getByRole('button', { name: 'Vazgeç' })).toBeVisible();
  await shot(page, 'uitur-12-birlesik-kapi-sheet');
  await sheet.getByRole('button', { name: 'Vazgeç' }).click();
  const toh = await dbTek('tohumlama', 'id', S.m.tohId, 'sonuc');
  expect(toh?.sonuc).toBe('Bekliyor');
  const gorev = await dbTek('gorev_log', 'id', S.m.takipId, 'tamamlandi,iptal');
  expect(gorev?.tamamlandi).toBe(false);
  expect(gorev?.iptal).toBe(false);
});

// ══ M13 — Sessiz kapanış ══════════════════════════════════════════════════════
test('M13: sessiz kapanış (T-19) — onay yok; neden=YENI_TOHUMLAMA; listeden düşer', async ({ page }) => {
  await ovAc(page);
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.e.kupe })).toBeVisible({ timeout: 10000 });
  let nativeDialog = false;
  page.on('dialog', d => { nativeDialog = true; d.dismiss().catch(() => {}); });
  const { error } = await db.from('tohumlama').insert({
    hayvan_id: S.e.hayvanId, tarih: trBugun(), sonuc: 'Bekliyor',
    deneme_sayisi: 2, denemeler: [],
  });
  expect(error, error?.message).toBeNull();
  const gorev = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.e.takipId, 'tamamlandi,takip_kapanis_nedeni');
    return g?.takip_kapanis_nedeni === 'YENI_TOHUMLAMA' ? g : null;
  });
  expect(gorev, 'takip görevi YENI_TOHUMLAMA ile kapanmalı').toBeTruthy();
  expect(nativeDialog, 'onay/dialog çıkmamalı').toBe(false);
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.e.kupe })).toHaveCount(0, { timeout: 10000 });
  await shot(page, 'uitur-13-sessiz-kapanis-sonrasi', false);
});

// ══ M14 — Çıkış kapanışı ══════════════════════════════════════════════════════
test('M14: çıkış kapanışı (T-22) — hayvan çıkışı → takip kapanır (neden=CIKIS), satır düşer', async ({ page }) => {
  await ovAc(page);
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.q.kupe })).toBeVisible({ timeout: 10000 });
  const { error } = await db.from('hayvanlar').update({ durum: 'Satildi' }).eq('id', S.q.hayvanId);
  expect(error, error?.message).toBeNull();
  const gorev = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.q.takipId, 'iptal,takip_kapanis_nedeni');
    return g?.takip_kapanis_nedeni === 'CIKIS' ? g : null;
  });
  expect(gorev, 'takip görevi CIKIS ile kapanmalı').toBeTruthy();
  expect(gorev.iptal).toBe(true);
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.q.kupe })).toHaveCount(0, { timeout: 10000 });
  await shot(page, 'uitur-14-cikis-kapanisi', false);
  await db.from('hayvanlar').update({ durum: 'Aktif' }).eq('id', S.q.hayvanId);
});

// ══ M15 — Birleşik sonuç ekranı ═══════════════════════════════════════════════
test('M15: birleşik sonuç ekranı (T-04/T-76) — GK 5 kart, TM 4 kart; görev detay + S2 + 40g listesi girişleri', async ({ page }) => {
  await openApp(page);
  await idbGorevBekle(page, S.c.gorevId);
  // Giriş 1: görev detayı
  await navTo(page, '#nb-tasks');
  await page.click('[data-action="task-kat-ureme"]');
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  await page.locator(`#tc-${S.c.gorevId}`).click();
  const secici = page.locator('#devam-secici-bs');
  await expect(secici).toBeVisible({ timeout: 10000 });
  await expect(secici).toContainText('Gebelik kontrolü');
  await expect(secici).toContainText(S.c.kupe);
  await expect(secici.locator('[data-action="devam-secici-sec"]')).toHaveCount(5);
  for (const secim of ['GEBE', 'OVSYNC', 'PG', 'TAKIP', 'ERTALE']) {
    await expect(secici.locator(`[data-secim="${secim}"]`)).toHaveCount(1);
  }
  await page.click('[data-action="devam-secici-sec"][data-secim="GEBE"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Muayene tamam + Gebe işaretle');
  await shot(page, 'uitur-15a-gebelik-kontrol-5kart');
  await seciciKapat(page);
  // Giriş 2: TAKIP_MUAYENE görev detayı — 4 kart (TAKIP YOK)
  await idbGorevBekle(page, S.h.takipId);
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  await page.locator(`#tc-${S.h.takipId}`).click();
  await expect(secici).toBeVisible({ timeout: 10000 });
  await expect(secici).toContainText('Takip muayenesi');
  await expect(secici.locator('[data-action="devam-secici-sec"]')).toHaveCount(4);
  await expect(secici.locator('[data-secim="TAKIP"]')).toHaveCount(0);
  await shot(page, 'uitur-15b-takip-muayene-4kart');
  await seciciKapat(page);
  // Giriş 3: dashboard 40 g listesi (🔬 Gebelik Muayenesi Bekleyenler)
  await page.evaluate(() => window.goTo('dash'));
  await expect(page.locator('#dash-body', { hasText: '🔬 Gebelik Muayenesi Bekleyenler (' })).toBeVisible();
  await page.getByRole('button', { name: 'Tümünü Gör →' }).first().click();
  await expect(page.locator('#sessiz-bs')).toBeVisible();
  const mRow = page.locator('#sessiz-bs .arow', { hasText: S.c.kupe }).first();
  await expect(mRow).toBeVisible();
  await expect(mRow).toContainText(/\. gün Bekliyor/);
  await shot(page, 'uitur-15c-dash-40g-listesi', false);
  await mRow.click();
  await expect(page.locator('#devam-secici-bs')).toBeVisible({ timeout: 10000 });
  await expect(page.locator('#devam-secici-bs')).toContainText('Gebelik kontrolü');
  await seciciKapat(page);
});

// ══ M16 — Erteleyin saatsiz ön ayarı + P12b yerel gün + 21g onayı ════════════
test('M16: ertele (T-25/T-26/§10d#3) — gün ön +7, saat BOŞ, canlı önizleme; saatsiz kayıt; ≥21g TEK onay', async ({ page }) => {
  await ovAc(page);
  await idbGorevBekle(page, S.c2.gorevId);
  const satir = page.locator('#pg-ovsync .ovs-s2-satir', { hasText: S.c2.kupe });
  await expect(satir).toBeVisible({ timeout: 10000 });
  await satir.getByRole('button', { name: /Muayene sonucu/ }).click();
  const secici = page.locator('#devam-secici-bs');
  await expect(secici).toBeVisible({ timeout: 10000 });
  await page.click('[data-action="devam-secici-sec"][data-secim="ERTALE"]');
  const gunInput = secici.locator('input[data-alan="erteleGun"]');
  const saatInput = secici.locator('input[data-alan="erteleSaat"]');
  await expect(gunInput).toHaveValue('7');
  await expect(saatInput).toHaveValue('');
  await expect(saatInput).toHaveAttribute('title', 'Saat (boş = saatsiz)');
  const onizleme = page.locator('#devam-onizleme');
  await expect(onizleme).toContainText(/→ \d{2}\.\d{2}/);
  await saatInput.fill('14:30');
  await expect(onizleme).toContainText(/→ \d{2}\.\d{2} 14:30/);
  await saatInput.fill('');
  await expect(onizleme).toContainText(/→ \d{2}\.\d{2}/);
  await expect(onizleme).not.toContainText('14:30');
  await shot(page, 'uitur-16a-ertele-saatsiz-onizleme');
  await page.click('#devam-onayla');
  await expect(secici).toHaveCount(0, { timeout: 20000 });
  const gorev = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.c2.gorevId, 'hedef_tarih,hedef_saat');
    return g && g.hedef_tarih === trGun(7) ? g : null;
  });
  expect(gorev, `hedef Istanbul yerel bugün+7 (${trGun(7)}) olmalı — P12b`).toBeTruthy();
  expect(gorev.hedef_saat).toBeNull();
  // ≥21 g → TEK onay (#m-confirm)
  await idbGorevBekle(page, S.h.takipId);
  await navTo(page, '#nb-tasks');
  await page.click('[data-action="task-kat-ureme"]');
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  await page.locator(`#tc-${S.h.takipId}`).click();
  await expect(secici).toBeVisible({ timeout: 10000 });
  await page.click('[data-action="devam-secici-sec"][data-secim="ERTALE"]');
  await page.click('#devam-onayla');
  await expect(page.locator('#m-confirm')).toHaveClass(/on/, { timeout: 10000 });
  await expect(page.locator('#m-confirm-desc')).toContainText(/\d+ gündür takipte, emin misiniz/);
  await shot(page, 'uitur-16b-21g-onay', false);
  await page.click('#m-confirm-ok');
  await expect(secici).toHaveCount(0, { timeout: 20000 });
  const gorevH = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.h.takipId, 'hedef_tarih,hedef_saat');
    return g && g.hedef_tarih === trGun(7) ? g : null;
  });
  expect(gorevH, 'hedef +7 (yerel gün)').toBeTruthy();
  expect(gorevH.hedef_saat).toBeNull();
});

// ══ M17 — Üreme geçmişi iki satır + tahmini doğum ═════════════════════════════
test('M17: üreme geçmişi iki satır (T-84) — üstü çizili Boş + Gebe; tahmini doğum Gebe\'den', async ({ page }) => {
  await ovAc(page);
  await idbGorevBekle(page, S.i.takipId);
  await navTo(page, '#nb-tasks');
  await page.click('[data-action="task-kat-ureme"]');
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  await page.locator(`#tc-${S.i.takipId}`).click();
  const secici = page.locator('#devam-secici-bs');
  await expect(secici).toBeVisible({ timeout: 10000 });
  await page.click('[data-action="devam-secici-sec"][data-secim="GEBE"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Muayene tamam + Gebe işaretle');
  await page.click('#devam-onayla');
  await expect(secici).toHaveCount(0, { timeout: 20000 });
  const toh = await dbBekle(async () => {
    const t = await dbTek('tohumlama', 'id', S.i.tohId, 'sonuc');
    return t?.sonuc === 'Gebe' ? t : null;
  });
  expect(toh, 'takip muayenesinde Gebe → kayıt Gebe olur').toBeTruthy();
  await page.evaluate(() => window.pullTables && window.pullTables(['tohumlama', 'islem_log']));
  await navTo(page, '#nb-ureme');
  await page.click('#ureme-tab-tohumlama');
  await page.fill('#tohumlama-srch', S.i.kupe);
  const satir = page.locator('#ureme-body .hist-row', { hasText: S.i.kupe }).first();
  await expect(satir).toBeVisible({ timeout: 10000 });
  await expect(satir).toContainText('❌ Boş (');
  await expect(satir).toContainText('✅ Gebe');
  await expect(satir.locator('span', { hasText: '❌ Boş (' })).toHaveCSS('text-decoration', /line-through/);
  // tahmini doğum Gebe'den (toh -45g + 280 = +235g)
  await page.evaluate(hid => window.openDet(hid, true), S.i.hayvanId);
  const gebelikChip = page.locator('body').getByText(/🤰 .*Tahmini:/).first();
  await expect(gebelikChip).toBeVisible({ timeout: 10000 });
  const beklenen = trGun(235);
  const beklenenKisa = beklenen.slice(8, 10) + '.' + beklenen.slice(5, 7) + '.' + beklenen.slice(0, 4);
  const chipTxt = await gebelikChip.innerText();
  expect(chipTxt.includes(beklenen) || chipTxt.includes(beklenenKisa),
    `tahmini doğum ${beklenen}/${beklenenKisa} olmalı — chip: ${chipTxt}`).toBe(true);
  await shot(page, 'uitur-17-iki-satir-tahmini-dogum', false);
});

// ══ M18 — Göreli gün ══════════════════════════════════════════════════════════
test('M18: göreli gün (T-85) — geçmiş satırında bugün/dün/N gün önce', async ({ page }) => {
  await openApp(page);
  await navTo(page, '#nb-ureme');
  await page.click('#ureme-tab-tohumlama');
  await page.fill('#tohumlama-srch', S.i.kupe);
  const satir = page.locator('#ureme-body .hist-row', { hasText: S.i.kupe }).first();
  await expect(satir).toBeVisible({ timeout: 10000 });
  await expect(satir).toContainText(/bugün|dün|\d+ gün önce/);
  await shot(page, 'uitur-18-goreli-gun', false);
});

// ══ M19 — S2 satır sağ hücresi (⚠ HATA-3) + ayar testi ═══════════════════════
test('M19: S2 "muayene vakti · +Ng" (T-38/T-43/T-44 ⚠); ayar 35→satır kayar; "21" yok', async ({ page }) => {
  await ovAc(page);
  const aSatir = page.locator('#pg-ovsync .ovs-s2-satir', { hasText: S.a.kupe });
  await expect(aSatir).toBeVisible({ timeout: 10000 });
  await expect(aSatir).toContainText(/muayene vakti/);
  await expect(aSatir).toContainText(/\+\d+g/);
  await expect(aSatir.getByRole('button', { name: /Muayene sonucu/ })).toBeVisible();
  const govde = await page.locator('#pg-ovsync').innerText();
  expect(govde).not.toMatch(/21[.\s]*gün|21\. gün/);
  const once = await aSatir.innerText();
  await shot(page, 'uitur-19a-s2-vakti-plus5g', false);
  // ayar 40→35: w (-38g) satırı S2'ye kayar; a rozeti değişir
  const { error: e1 } = await db.from('protokol_ayar').update({ deger: 35 }).eq('anahtar', 'sessiz_tohumlama_muafiyet_gun');
  expect(e1, e1?.message).toBeNull();
  try {
    await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
    await page.evaluate(() => window.goTo('ovsync'));
    await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
    const wSatir = page.locator('#pg-ovsync .ovs-s2-satir', { hasText: S.w.kupe });
    await expect(wSatir).toBeVisible({ timeout: 10000 });
    await expect(wSatir).toContainText(/muayene vakti/);
    const sonra = await page.locator('#pg-ovsync .ovs-s2-satir', { hasText: S.a.kupe }).innerText();
    expect(sonra, 'eşik 35 ile a rozeti değişmeli\nönce: ' + once).not.toBe(once);
    await shot(page, 'uitur-19b-ayar35-satir-kaydi', false);
  } finally {
    await db.from('protokol_ayar').update({ deger: 40 }).eq('anahtar', 'sessiz_tohumlama_muafiyet_gun');
  }
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  await expect(page.locator('#pg-ovsync .ovs-s2-satir', { hasText: S.w.kupe })).toHaveCount(0, { timeout: 10000 });
});

// ══ M25 — Invalidate (g zinciri kurulumu; m20 öncesi koşar) ═══════════════════
test('M25: invalidate (T-50) — yazma sonrası __ovsyncTakip=null; taze veri; bayat satır kalmaz', async ({ page }) => {
  await ovAc(page);
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.g.kupe })).toHaveCount(0);
  const gToh = await dbTek('tohumlama', 'id', S.g.tohId, 'id');
  expect(gToh, 'g tohumlama yok').toBeTruthy();
  await page.evaluate(async tohId => {
    await window.tohumlamaBosVeDevam({ p_tohumlama_id: tohId, p_secim: 'OVSYNC', p_gun: 7 });
  }, S.g.tohId);
  await expect.poll(async () =>
    page.evaluate(() => (window.__ovsyncTakip === null || window.__ovsyncTakip === undefined) ? 'taze' : 'bayat'),
  { timeout: 15000 }).toBe('taze');
  const gorev = await dbBekle(async () => {
    const { data } = await db.from('gorev_log')
      .select('id').eq('hayvan_id', S.g.hayvanId)
      .eq('gorev_tipi', 'OVSYNC_BASLAT').eq('tamamlandi', false).eq('iptal', false);
    return data?.[0] ?? null;
  });
  expect(gorev, 'sarmal OVSYNC → OVSYNC_BASLAT görevi kurulmalı').toBeTruthy();
  S.g.baslatId = gorev.id;
  await page.evaluate(() => { window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  const gKart = page.locator('#pg-ovsync .ovs-s3-satir', { hasText: S.g.kupe });
  await expect(gKart).toBeVisible({ timeout: 10000 });
  await expect(gKart.getByRole('button', { name: /Başlat/ })).toBeVisible();
  await shot(page, 'uitur-25-invalidaze-g-s3', false);
});

// ══ M20 — Satır gün şeması (g zinciri Başlat) ═════════════════════════════════
test('M20: satır gün şeması (T-35/36) — d0● d7◌ d8◌ d9◌ TAI⏳; renk dili; N/4 uygulandı; nötr etiketler', async ({ page }) => {
  await ovAc(page);
  const gKart = page.locator('#pg-ovsync .ovs-s3-satir', { hasText: S.g.kupe });
  await expect(gKart.getByRole('button', { name: /Başlat/ })).toBeVisible({ timeout: 10000 });
  await gKart.getByRole('button', { name: /Başlat/ }).click();
  // d0 (1. uygulama) bugün tamam — satır S1'de kalsın (bugun_isi olmasın);
  // tarihler Başlat'ın ürettiği d0/d7/d8/d9 yerleşimiyle korunur
  {
    const { data: vaka } = await db.from('cases').select('id').eq('animal_id', S.g.hayvanId)
      .eq('protocol_family', 'OVSYNC').eq('status', 'active');
    if (vaka?.[0]) {
      await db.from('treatment_days').update({ tamamlandi: true, tamamlanma_tarihi: new Date().toISOString() })
        .eq('case_id', vaka[0].id).eq('day_no', 1);
    }
  }
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  const kart = page.locator('#pg-ovsync .ovs-kart', { hasText: S.g.kupe }).first();
  await expect(kart).toBeVisible({ timeout: 15000 });
  // gün şeridi: 4 gün + TAI
  await expect(kart.locator('.ovs-g')).toHaveCount(5);
  await expect(kart.locator('.ovs-g-tai')).toHaveCount(1);
  const etiketler = await kart.locator('.ovs-g small').allInnerTexts();
  expect(etiketler, 'nötr gün etiketleri (A10)').toEqual(['1. uygulama', '2. uygulama', '3. uygulama', '4. uygulama', 'TAI']);
  // alt bilgi: N/4 uygulandı · sıradaki…
  const alt = await kart.locator('.ovs-alt').first().innerText();
  const m = alt.match(/(\d)\/4 uygulandı/);
  expect(m, 'alt "N/4 uygulandı · sıradaki…" olmalı: ' + alt).toBeTruthy();
  const tamamSayi = Number(m[1]);
  await expect(kart.locator('.ovs-alt').first()).toContainText('sıradaki');
  // renk dili: N hücre tamam (yeşil), kalanlar plan/gecikti
  const siniflar = await kart.locator('.ovs-g').evaluateAll(els => els.map(e => [...e.classList].find(c => c.startsWith('ovs-g-'))));
  const gecerli = ['ovs-g-tamam', 'ovs-g-plan', 'ovs-g-gecikti', 'ovs-g-soluk', 'ovs-g-tutarsiz', 'ovs-g-bugun'];
  for (const s of siniflar) expect(gecerli, 'renk dili sınıfı: ' + s).toContain(s);
  expect(siniflar.filter(s => s === 'ovs-g-tamam').length).toBe(tamamSayi);
  await shot(page, 'uitur-20-gun-semasi');
});

// ══ M21 — Sapma/deneme rozetleri + dalga grup başlığı (DB-seed'li protokol durumları) ══
test('M21: rozetler (T-69/T-67) — kayma +Ng / erken Ng / görevsiz / erken TAI / deneme; Dalga başlığı', async ({ page }) => {
  // ── ürün yoluyla zincir kur (sarmal + start_first_service_protocol), sonra
  //    tarih kaydırmalarıyla sapma durumları üretilir (marker'lı fixture)
  const zincirKur = async ad => {
    const res = await db.rpc('tohumlama_bos_ve_devam', {
      p_tohumlama_id: S[ad].tohId, p_secim: 'OVSYNC', p_gun: 7,
    });
    if (res.error) throw new Error(`${ad} sarmal: ${res.error.message}`);
    if (res.data?.ok === false) throw new Error(`${ad} sarmal reddi: ${res.data.mesaj}`);
    S[ad].ovGorevId = res.data.ovsync_gorev_id;
    const bas = await db.rpc('start_first_service_protocol', { p_gorev_id: S[ad].ovGorevId });
    if (bas.error) throw new Error(`${ad} baslat: ${bas.error.message}`);
    const { data: vaka } = await db.from('cases').select('id,start_date')
      .eq('animal_id', S[ad].hayvanId).eq('protocol_family', 'OVSYNC').eq('status', 'active');
    S[ad].caseId = vaka?.[0]?.id;
    expect(S[ad].caseId, ad + ' vaka açılmalı').toBeTruthy();
    const { data: gunler } = await db.from('treatment_days').select('id,day_no')
      .eq('case_id', S[ad].caseId).order('day_no');
    S[ad].gunler = gunler ?? [];
    expect(S[ad].gunler.length).toBe(4);
    const { data: tai } = await db.from('gorev_log').select('id').eq('hayvan_id', S[ad].hayvanId)
      .eq('gorev_tipi', 'TOHUMLAMA_PLANLI');
    S[ad].taiId = tai?.[0]?.id ?? null;
  };
  const gunYaz = async (ad, dayNo, tarih, tamamlandi) => {
    const g = S[ad].gunler.find(x => x.day_no === dayNo);
    await db.from('treatment_days').update({
      treatment_date: tarih, tamamlandi: !!tamamlandi,
      tamamlanma_tarihi: tamamlandi ? new Date(Date.parse(tarih + 'T10:00:00+03:00')).toISOString() : null,
    }).eq('id', g.id);
  };
  await zincirKur('p');
  await zincirKur('pz');
  await zincirKur('pe');
  // p: kayma +3g (hedef -10, fiili -7), erken TAI, 2. deneme
  await db.from('cases').update({ start_date: trGun(-10) }).eq('id', S.p.caseId);
  await db.from('gorev_log').update({ hedef_tarih: trGun(-10), tamamlandi: true }).eq('id', S.p.ovGorevId);
  await gunYaz('p', 1, trGun(-7), true);
  await gunYaz('p', 2, trGun(1), false);
  await gunYaz('p', 3, trGun(2), false);
  await gunYaz('p', 4, trGun(3), false);
  if (S.p.taiId) await db.from('gorev_log').update({ hedef_tarih: trGun(9) }).eq('id', S.p.taiId);
  await db.from('tohumlama').insert({
    hayvan_id: S.p.hayvanId, tarih: trGun(-1), sonuc: 'Bekliyor', deneme_sayisi: 2, denemeler: [],
  });
  // pz: görevsiz TAI (TAI görevi silinir; kayma 0)
  await gunYaz('pz', 1, trGun(-5), true);
  await gunYaz('pz', 2, trGun(1), false);
  await gunYaz('pz', 3, trGun(2), false);
  await gunYaz('pz', 4, trGun(3), false);
  await db.from('gorev_log').update({ hedef_tarih: trGun(-5), tamamlandi: true }).eq('id', S.pz.ovGorevId);
  if (S.pz.taiId) await db.from('gorev_log').delete().eq('id', S.pz.taiId);
  // pe: erken 2g (hedef +2, fiili bugün) + S0 BUGÜN (d1 bugün planli)
  await gunYaz('pe', 1, trGun(0), false);
  await gunYaz('pe', 2, trGun(1), false);
  await gunYaz('pe', 3, trGun(2), false);
  await gunYaz('pe', 4, trGun(3), false);
  await db.from('gorev_log').update({ hedef_tarih: trGun(2), tamamlandi: true }).eq('id', S.pe.ovGorevId);

  await page.evaluate(() => { window.__ovsyncTakip = null; });
  await ovAc(page);
  const pKart = page.locator('#pg-ovsync .ovs-kart', { hasText: S.p.kupe }).first();
  await expect(pKart).toBeVisible({ timeout: 15000 });
  await expect(pKart.locator('.ovs-rozet-kayma')).toContainText(/hedef \d{2}\.\d{2} → fiilen \+3g/);
  await expect(pKart.locator('.ovs-rozet-erken')).toContainText('erken TAI');
  await expect(pKart.locator('.ovs-rozet-deneme')).toContainText('2. deneme — önceki boş');
  const pzKart = page.locator('#pg-ovsync .ovs-kart', { hasText: S.pz.kupe }).first();
  await expect(pzKart).toBeVisible({ timeout: 15000 });
  await expect(pzKart.locator('.ovs-rozet-gorevsiz')).toContainText('görevsiz');
  const peKart = page.locator('#pg-ovsync .ovs-kart', { hasText: S.pe.kupe }).first();
  await expect(peKart).toBeVisible({ timeout: 15000 });
  await expect(peKart.locator('.ovs-rozet-erken').first()).toContainText(/erken \d+g/);
  // dalwa grup başlığı (S1): 'Dalga: hedef GG.AA → fiilen GG.AA' + 'N hayvan'
  const gt = page.locator('#pg-ovsync .ovs-grup .ovs-gt', { hasText: 'Dalga: hedef' }).filter({ hasText: 'hayvan' });
  await expect(gt.first()).toBeVisible();
  const gtTxt = await gt.first().innerText();
  expect(gtTxt).toMatch(/Dalga: hedef \d{2}\.\d{2} → fiilen \d{2}\.\d{2}/);
  expect(gtTxt).toMatch(/\d+ hayvan/);
  await shot(page, 'uitur-21-rozetler-dalga');
});

// ══ M22 — Bayrak kapalı ═══════════════════════════════════════════════════════
test('M22: bayrak kapalı (T-46) — 🔒 şerit; boş liste sessiz gösterilmez; seçici açılmaz', async ({ page }) => {
  await ovAc(page);
  const { error: e1 } = await db.from('protokol_ayar').update({ deger: 0 }).eq('anahtar', 'ovsync_pg_kurallari_aktif');
  expect(e1, e1?.message).toBeNull();
  try {
    await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
    await page.evaluate(() => window.goTo('ovsync'));
    await expect(page.locator('#pg-ovsync')).toContainText('🔒 Ovsync/PG kuralları kapalı — takip verisi yok', { timeout: 15000 });
    await shot(page, 'uitur-22-bayrak-kapali', false);
    // §6c seçici açılmaz — y hayvanında Boş kaydet
    await navTo(page, '#nb-ureme');
    await page.click('#ureme-tab-tohumlama');
    await page.fill('#tohumlama-srch', S.y.kupe);
    const satir = page.locator('#ureme-body .hist-row', { hasText: S.y.kupe }).first();
    await expect(satir).toBeVisible({ timeout: 10000 });
    await satir.click();
    await expect(page.locator('#m-toh-det')).toHaveClass(/on/);
    await page.check('input[name="toh-sonuc"][value="Boş"]');
    await page.click('[data-action="toh-sonuc-kaydet"]');
    await expect(page.locator('#toast')).toContainText('Ovsync/PG kuralları kapalı — Boş kaydı mevcut akışla yapılır');
    await expect(page.locator('#devam-secici-bs')).toHaveCount(0);
  } finally {
    await db.from('protokol_ayar').update({ deger: 1 }).eq('anahtar', 'ovsync_pg_kurallari_aktif');
  }
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  await expect(page.locator('#pg-ovsync .ovs-kpa-c')).toHaveCount(5);
});

// ══ M23 — Offline ═════════════════════════════════════════════════════════════
test('M23: offline (T-47/T-48) — bayat "⚠️ çevrimdışı · HH:MM verisi"; önbelleksiz "📡 İnternet yok"', async ({ page }) => {
  await ovAc(page);
  await goOffline(page);
  await page.evaluate(() => window.goTo('dash'));
  await page.evaluate(() => window.goTo('ovsync'));
  const bayat = page.locator('#pg-ovsync', { hasText: '⚠️ çevrimdışı · ' });
  await expect(bayat).toBeVisible({ timeout: 45000 });
  const bayatTxt = await page.locator('#ovsync-root').innerText();
  expect(bayatTxt).toMatch(/⚠️ çevrimdışı · \d{2}:\d{2} verisi/);
  // bayat İÇERİK de gösterilir (sessiz boş YASAK)
  await expect(page.locator('#pg-ovsync .ovs-kpa-c').first()).toBeVisible();
  await shot(page, 'uitur-23a-offline-bayat', false);
  // önbelleksiz
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toContainText('📡 İnternet yok — takip verisi alınamadı', { timeout: 45000 });
  await shot(page, 'uitur-23b-offline-onbelleksiz', false);
  await goOnline(page);
  await page.evaluate(() => { window.__ovsyncTakip = null; window.goTo('dash'); });
  await page.evaluate(() => window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  await expect(page.locator('#pg-ovsync .ovs-kpa-c')).toHaveCount(5);
});

// ══ M24 — Gezinme ═════════════════════════════════════════════════════════════
test('M24: gezinme (T-51..T-55) — yatay geçiş; ‹ Geri=history.back; scroll geri yükleme; modal guard', async ({ page }) => {
  await ovAc(page);
  await expect(page).toHaveURL(/#ovsync/);
  await page.evaluate(() => { document.querySelector('#pg-ovsync').scrollTop = 300; });
  await page.click('#nb-tasks');
  await expect(page.locator('#pg-tasks')).toHaveClass(/on/);
  await expect(page).toHaveURL(/#tasks/);
  await page.locator('[data-action="nav-geri"]').first().click();
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/, { timeout: 10000 });
  await expect(page).toHaveURL(/#ovsync/);
  const scrollY = await page.evaluate(() => document.querySelector('#pg-ovsync').scrollTop);
  expect(scrollY, 'ovsync scroll konumu saklanıp geri yüklenmeli (§6b)').toBeGreaterThanOrEqual(200);
  await shot(page, 'uitur-24a-scroll-restore', false);
  // modal açıkken geri — yalnız modal kapanır
  await idbGorevBekle(page, S.c.gorevId);
  await page.waitForFunction(() => window.__ovsyncTakip?.veri?.satirlar, null, { timeout: 30000 });
  const cSatir = page.locator('#pg-ovsync .ovs-s2-satir', { hasText: S.c.kupe });
  await expect(cSatir).toBeVisible({ timeout: 10000 });
  await cSatir.getByRole('button', { name: /Muayene sonucu/ }).click();
  await expect(page.locator('#devam-secici-bs')).toBeVisible({ timeout: 10000 });
  expect(await page.evaluate(() => !!history.state?.devam_secici)).toBe(true);
  await page.locator('[data-action="nav-geri"]').first().click();
  await expect(page.locator('#devam-secici-bs')).toHaveCount(0, { timeout: 10000 });
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  await expect(page).toHaveURL(/#ovsync/);
  expect(await page.evaluate(() => !!history.state?.devam_secici)).toBe(false);
  await shot(page, 'uitur-24b-modal-geri-guard', false);
});
