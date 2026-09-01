// tests/support/app.js
// E2E spec'lerinin paylaşılan yardımcıları.
//
// Koşum modları:
//   PLAYWRIGHT_DEMO_MODE=1                        → gerçek Demo-Mirror Supabase (birincil)
//   PLAYWRIGHT_DEMO_MODE=1 PLAYWRIGHT_STUB_BACKEND=1 → tarayıcı-içi sahte demo backend
//     (demo projesi erişilemediğinde — paused/NXDOMAIN — ortam engeli çözümü;
//      tests/support/stub-backend.js bkz. Prod'e asla gidilmez.)

import { test, expect } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';
import { installStubBackend, store, insertLog } from './stub-backend.js';

export const IS_DEMO = !!process.env.PLAYWRIGHT_DEMO_MODE;
export const STUB = !!process.env.PLAYWRIGHT_STUB_BACKEND;

const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
// js/api.js DEMO_LOGIN ile aynı — demo projesinde anon rolün tablo okuma
// yetkisi yok (2026-09 restore sonrası GRANT kaybı, REST 42501); UI demo
// autologin ile authenticated çektiği için DB doğrulamaları da aynı yoldan
// okur (bkz. rapor: demo anon-yetki bulgusu).
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
const supabase = STUB ? null : createClient(DEMO_URL, DEMO_KEY);

// Oturum isteklerini tek seferlik önbelleğe alır (worker başına 1 login).
let sessionPromise = null;
function demoSession() {
  if (!sessionPromise) {
    sessionPromise = supabase.auth.signInWithPassword(DEMO_LOGIN).then(res => {
      if (res.error) throw res.error;
      return res.data;
    });
  }
  return sessionPromise;
}

export async function openApp(page) {
  if (STUB) await installStubBackend(page);
  await page.goto('./', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#pg-dash .sv', { timeout: 30000 });
}

export async function navTo(page, btnId) {
  const id = btnId.replace(/^#/, ''); // '#nb-x' ve 'nb-x' girişlerinin ikisi de kabul
  await page.click('#' + id);
  await page.waitForSelector('#' + id.replace('nb-', 'pg-') + '.on', { timeout: 8000 });
}

export async function toastText(page) {
  return (await page.locator('#toast').innerText()).trim();
}

// ── Çevrimdışı/çevrimiçi geçişi ─────────────────────────────────────────────
// Gerçek modda context.setOffline (ağ düzeyi). Stub modunda fulfill'lu route'lar
// ağa çıkmadığından setOffline etkisiz kalabilir → navigator.onLine'ı sayfa
// içinde override edip app'in kendi 'online' event'ini tetikleriz (aynı kod
// yolu: syncNow + pullFromSupabase).
export async function goOffline(page) {
  if (STUB) {
    await page.evaluate(() => {
      Object.defineProperty(navigator, 'onLine', { get: () => false, configurable: true });
      window.dispatchEvent(new Event('offline'));
    });
  } else {
    await page.context().setOffline(true);
    await page.waitForTimeout(400);
  }
}

export async function goOnline(page) {
  if (STUB) {
    await page.evaluate(() => {
      Object.defineProperty(navigator, 'onLine', { get: () => true, configurable: true });
      window.dispatchEvent(new Event('online'));
    });
  } else {
    await page.context().setOffline(false);
  }
}

// ── DB doğrulama soyutlaması ────────────────────────────────────────────────
// Gerçek mod: demo projesinden SELECT. Stub modu: route handler'ın canlı
// store'u (aynı worker sürecinde) — sunucunun yapacağı mutasyonu RPC handler
// zaten uyguladı.

// gorev_log'da açıklaması marker içeren tek satır
export async function gorevByMarker(marker) {
  if (STUB) {
    return store.gorev_log.find(r => (r.aciklama || '').includes(marker)) || null;
  }
  await demoSession();
  const { data } = await supabase.from('gorev_log').select('id,tamamlandi').eq('aciklama', marker);
  return data?.[0] ?? null;
}

// gorev_log'a marker'lı satırın DB/endpoint'e ulaşmış olması
export async function gorevReachedBackend(marker) {
  if (STUB) return insertLog.some(e => e.table === 'gorev_log' && e.rows.some(r => (r.aciklama || '').includes(marker)));
  await demoSession();
  const { data } = await supabase.from('gorev_log').select('id').eq('aciklama', marker);
  return (data?.length || 0) > 0;
}

export { test, expect };
