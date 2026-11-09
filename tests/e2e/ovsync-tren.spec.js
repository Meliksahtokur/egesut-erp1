// tests/e2e/ovsync-tren.spec.js
// Ovsync treni — gerçek demo DB e2e (PLAN N6 DM1 :577-581; stub YOK). Kalıp: tests/e2e/ovsync-takip.spec.js
// (E2E-TREN-PW- işaretli seed, sabit id'ler, afterAll temizlik, --workers=1).
//
// Tarih bağımsızlığı: testler haftanın gününe bağlı kalmasın diye beforeAll tren çapasını T = bugün+2 yapar
// (ovsync_tren_ayar_guncelle). T, ▶ Başlat penceresinde (hedef−2 ≤ bugün) ve bugün değil → K8 sorusu açılır (R4).
// afterAll: çapa koşum öncesi değerine döner; işaretsiz açık OVSYNC_BASLAT görevlerinin hedefi koşum öncesine geri yazılır
// (toptan erteleme demo'nun kendi görevlerini de kaydırır — K7 tren kümesinin tamamını işler).
// Sıra bağımlılığı (bilinçli, tek worker): toptan +1, ilk 8 testin T trenine bindirdiği üyeleri de kaydırır; toptan +3 yeni
// ritimde (T+1) koşar. Sıra dosya sırasıdır.
//
// Koşum (demo; dal kodu yerel sunucudan servis edilir):
//   python3 -m http.server 8137 --bind 127.0.0.1   (worktree kökü)
//   docker run --rm --network host -v "$PWD":/work -w /work -v ~/egesut-erp1:/main:ro \
//     -e NODE_PATH=/main/node_modules -e PLAYWRIGHT_DEMO_MODE=1 \
//     -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8137/ -e HOME=/tmp/pwhome \
//     mcr.microsoft.com/playwright:v1.58.2-noble \
//     /main/node_modules/.bin/playwright test tests/e2e/ovsync-tren.spec.js \
//     --reporter=list --retries=0 --workers=1
// Not: tarayıcı saat dilimi konteynerinkidir (UTC); TR gece yarısı ile UTC 21:00 arasında koşmayın (UI bugünü ≠ TR bugünü).

import { test, expect, openApp, navTo, IS_DEMO } from '../support/app.js';
import { createClient } from '@supabase/supabase-js';

const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
const MARKER = 'E2E-TREN-PW-';
const OVS_HASTALIK = 'c346e115-35ff-4430-92b8-874c505d857e';   // "Ovsync Protokol" (sablon_hastalik_eslem)
const OVS_SABLON = 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7';     // "Sağmal inek: Ovsynch-56 + çift PGs" (protokol_ailesi OVSYNC)

// serial: testler sıra bağımlı (toptan testleri önceki testlerin üyelerini kullanır). default modda bir FAIL işçiyi yeniden
// başlatır → beforeAll yeniden seed'ler (temizle) → sonraki testler sahte FAIL verir (2026-11-09 koşum 1-2 ölçümü).
test.describe.configure({ mode: !IS_DEMO ? 'skip' : 'serial' });
test.setTimeout(120000);

let db;            // demo authenticated client
let S = {};        // seed: ad → {kupe, hayvanId, gorevId?, caseId?, ...}
let CAPA0 = null;  // koşum öncesi çapa (YYYY-MM-DD)
let OB0 = [];      // koşum öncesi işaretsiz açık OVSYNC_BASLAT {id, hedef_tarih}

const trGun = n => new Date(Date.now() + 3 * 3600e3 + n * 864e5).toISOString().slice(0, 10);
const gunEkle = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 864e5).toISOString().slice(0, 10);
const B = trGun(0);          // TR bugün
const T = trGun(2);          // test treni (çapa)
const ADLAR = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'v', 'g7a', 'g7b'];

async function rpc(ad, p) {
  const { data, error } = await db.rpc(ad, p);
  if (error) throw new Error(`${ad}: ${error.message}`);
  return data;
}
async function dbBekle(fn, ms = 15000) {
  const son = Date.now() + ms;
  while (Date.now() < son) { const r = await fn(); if (r) return r; await new Promise(t => setTimeout(t, 500)); }
  return null;
}
const aktifVaka = async hid => {
  const { data } = await db.from('cases').select('id,start_date,ovsync_tren,ovsync_bagimsiz,status,close_reason')
    .eq('animal_id', hid).eq('status', 'active').eq('protocol_family', 'OVSYNC');
  return data?.[0] ?? null;
};
const vakaOku = async cid => (await db.from('cases').select('id,status,close_reason,ovsync_tren,start_date').eq('id', cid)).data?.[0] ?? null;
const acikOb = async hid => (await db.from('gorev_log').select('id,hedef_tarih').eq('hayvan_id', hid).eq('gorev_tipi', 'OVSYNC_BASLAT')
  .eq('tamamlandi', false).eq('iptal', false)).data ?? [];
const gunler = async cid => (await db.from('treatment_days').select('id,treatment_date,day_no').eq('case_id', cid).is('disease_id', null)
  .order('treatment_date').order('day_no')).data ?? [];

test.beforeAll(async () => {
  test.setTimeout(180000);   // kanca varsayılanı 30 s; seed + temizlik ağda bunu aşabiliyor (koşum 2)
  db = createClient(DEMO_URL, DEMO_KEY);
  const { error } = await db.auth.signInWithPassword(DEMO_LOGIN);
  if (error) throw new Error(`demo giriş başarısız: ${error.message}`);
  await temizle('önce');
  const { data: ay } = await db.from('protokol_ayar').select('deger').eq('anahtar', 'ovsync_tren_capa').single();
  const c = String(ay.deger); CAPA0 = `${c.slice(0, 4)}-${c.slice(4, 6)}-${c.slice(6, 8)}`;
  const { data: ob } = await db.from('gorev_log').select('id,hedef_tarih,aciklama').eq('gorev_tipi', 'OVSYNC_BASLAT')
    .eq('tamamlandi', false).eq('iptal', false);
  OB0 = (ob ?? []).filter(g => !String(g.aciklama || '').startsWith(MARKER)).map(g => ({ id: g.id, hedef_tarih: g.hedef_tarih }));
  await rpc('ovsync_tren_ayar_guncelle', { p_aktif: true, p_capa: T });

  for (const [i, ad] of ADLAR.entries()) {
    const id = `e2e30000-0000-4000-8000-${String(i + 1).padStart(12, '0')}`;
    const kupe = MARKER + ad;
    const { data: got } = await db.from('hayvanlar').select('id,durum').eq('id', id);
    if (got?.length && got[0].durum !== 'Aktif') await db.from('hayvanlar').update({ durum: 'Aktif' }).eq('id', id);
    if (!got?.length) {
      const { error: e1 } = await db.from('hayvanlar').insert({ id, kupe_no: kupe, cinsiyet: 'Dişi', durum: 'Aktif',
        dogum_tarihi: trGun(-500), grup: 'Sağmal (Laktasyonda)' });
      if (e1) throw new Error(`seed hayvan ${ad}: ${e1.message}`);
    }
    S[ad] = { kupe, hayvanId: id };
  }
  const obEkle = async (ad, hedef) => {
    const { data, error: e } = await db.from('gorev_log').insert({ hayvan_id: S[ad].hayvanId, gorev_tipi: 'OVSYNC_BASLAT',
      aciklama: MARKER + ad, hedef_tarih: hedef, tamamlandi: false, iptal: false, kaynak: 'E2E-TREN:' + ad }).select('id').single();
    if (e) throw new Error(`seed görev ${ad}: ${e.message}`);
    S[ad].gorevId = data.id;
  };
  // V3 yolu (create_case + şablon, D0 verilen gün); tren açık ve D0 ritimdeyse etiket D0 (R3)
  const vakaEkle = async (ad, d0) => {
    const r = await rpc('create_case', { p_animal_id: S[ad].hayvanId, p_disease_id: OVS_HASTALIK, p_notes: MARKER + ad });
    await rpc('tedavi_sablon_uygula', { p_case_id: r.case_id, p_sablon_id: OVS_SABLON, p_baslangic_tarihi: d0 });
    S[ad].caseId = r.case_id;
  };
  // Hastalık-dışı gün#sıra seanslarını seans_tamamla ile kapatır; tarih verilirse uygulama anı o güne 10:00 TR çekilir
  const seansYap = async (ad, sira, tarih) => {
    const gun = (await gunler(S[ad].caseId))[sira - 1];
    const { data: ss } = await db.from('treatment_day_uygulamalar').select('id').eq('treatment_day_id', gun.id).is('uygulama_tamamlandi_at', null);
    for (const s of ss) await rpc('seans_tamamla', { p_seans_admin_id: s.id });
    if (tarih) {
      const { error: e } = await db.from('treatment_day_uygulamalar').update({ uygulama_tamamlandi_at: `${tarih}T10:00:00+03:00` })
        .in('id', ss.map(s => s.id));
      if (e) throw new Error(`seed geriye tarih ${ad}: ${e.message}`);
    }
  };
  for (const ad of ['a', 'b', 'c']) await obEkle(ad, T);
  await vakaEkle('d', gunEkle(T, -7)); await seansYap('d', 1, gunEkle(T, -7));                 // D7 treni, aşama 1, kayma 0
  for (const ad of ['e', 'f']) { await vakaEkle(ad, trGun(-7)); await seansYap(ad, 1, trGun(-7)); await seansYap(ad, 2); } // aşama 2
  await vakaEkle('g', trGun(-9)); await seansYap('g', 1, trGun(-9));                           // PG1 planı bugün−2
  await vakaEkle('h', trGun(-10));
  const tai = await rpc('tedavi_sablon_tohumlama_gorev_ekle', { p_case_id: S.h.caseId, p_sablon_id: OVS_SABLON, p_baslangic_tarihi: trGun(-10) });
  S.h.taiId = tai.gorev_id;
  for (const ad of ['g7a', 'g7b']) {
    const { data, error: e } = await db.from('tohumlama').insert({ hayvan_id: S[ad].hayvanId, tarih: trGun(-21), sonuc: 'Bekliyor',
      deneme_sayisi: 1, denemeler: [] }).select('id').single();
    if (e) throw new Error(`seed tohumlama ${ad}: ${e.message}`);
    S[ad].tohId = data.id;
  }
  // PG1 (gün#2) açık seansı: vaka kartı zaman çizelgesindeki satırı (renderSeansRow → seansTamamla; UB4 uyarı kancası orada)
  // Geriye tarihli şablon uygulaması geçmiş günleri tamamlandı yapar (seanslar açık kalır; demo ölçümü 2026-11-09) → canlı
  // vakayı taklit için gün#2+ yeniden açılır (aksi hâlde kart satırı salt-okur, ✓ Uygulandı çizilmez).
  const { error: eAc } = await db.from('treatment_days').update({ tamamlandi: false, tamamlanma_tarihi: null })
    .eq('case_id', S.g.caseId).gte('day_no', 2);
  if (eAc) throw new Error(`seed g gün aç: ${eAc.message}`);
  const pg1 = (await gunler(S.g.caseId))[1].id;
  const { data: ps } = await db.from('treatment_day_uygulamalar').select('id').eq('treatment_day_id', pg1).is('uygulama_tamamlandi_at', null);
  S.g.pg1Seans = ps?.[0]?.id;
  if (!S.g.pg1Seans) throw new Error('seed g: PG1 açık seansı bulunamadı');
});

test.afterAll(async () => {
  const hatalar = [];
  try {
    if (CAPA0) await rpc('ovsync_tren_ayar_guncelle', { p_aktif: true, p_capa: CAPA0 });
    for (const g of OB0) {
      const { data } = await db.from('gorev_log').select('hedef_tarih,tamamlandi,iptal').eq('id', g.id);
      const x = data?.[0];
      if (x && !x.tamamlandi && !x.iptal && x.hedef_tarih !== g.hedef_tarih) {
        const { error } = await db.from('gorev_log').update({ hedef_tarih: g.hedef_tarih }).eq('id', g.id);
        if (error) hatalar.push(`görev ${g.id} hedef geri: ${error.message}`);
      }
    }
  } catch (e) { hatalar.push(String(e.message || e)); }
  try { await temizle('sonra'); } catch (e) { hatalar.push(String(e.message || e)); }
  if (hatalar.length) throw new Error(`afterAll:\n  - ${hatalar.join('\n  - ')}`);
});

// Yalnız E2E-TREN-PW-* hayvanları (kupe_no). pg_application_event authenticated'a silinemez (FK) → hayvan Satıldı (görevler
// trg_hayvan_cikis_gorev_iptal ile iptal). Hata toplanır, sonda tek Error (sessiz yutma yok).
async function temizle(faz) {
  const hatalar = [];
  const adim = async (ad, p) => { const { data, error } = await p; if (error) { hatalar.push(`${ad}: ${error.message}`); return null; } return data ?? []; };
  const { data: eski, error: eh } = await db.from('hayvanlar').select('id').like('kupe_no', MARKER + '%');
  if (eh) throw new Error(`temizlik[${faz}] hayvan sorgusu: ${eh.message}`);
  const ids = (eski ?? []).map(h => h.id);
  if (!ids.length) return;
  const cid = ((await adim('cases', db.from('cases').select('id').in('animal_id', ids))) ?? []).map(c => c.id);
  if (cid.length) {
    const gid = ((await adim('günler', db.from('treatment_days').select('id').in('case_id', cid))) ?? []).map(g => g.id);
    if (gid.length) await adim('drug_administrations', db.from('drug_administrations').delete().in('treatment_day_id', gid).select('id'));
    await adim('treatment_day_uygulamalar', db.from('treatment_day_uygulamalar').delete().in('case_id', cid).select('id'));
    await adim('treatment_days', db.from('treatment_days').delete().in('case_id', cid).select('id'));
  }
  for (const t of ['protokol_instance', 'uygulama_log', 'gorev_log', 'tohumlama']) await adim(t, db.from(t).delete().in('hayvan_id', ids).select('id'));
  if (cid.length) await adim('cases', db.from('cases').delete().in('id', cid).select('id'));
  for (const id of ids) {
    const { error: es } = await db.from('hayvanlar').delete().eq('id', id).select('id');
    if (!es) continue;
    if (es.code !== '23503') { hatalar.push(`hayvan sil ${id}: ${es.message}`); continue; }
    await adim(`hayvan → Satıldı ${id}`, db.from('hayvanlar').update({ durum: 'Satıldı' }).eq('id', id).select('id'));
  }
  const { data: kalan } = await db.from('hayvanlar').select('id,durum').like('kupe_no', MARKER + '%');
  if ((kalan ?? []).some(h => h.durum === 'Aktif')) hatalar.push('işaretli Aktif hayvan kaldı');
  if (hatalar.length) throw new Error(`temizlik[${faz}] başarısız:\n  - ${hatalar.join('\n  - ')}`);
}

// IDB'ye kayıt düşene kadar bekle (ilk pull bitmeden depolar boştur)
async function idbBekle(page, depo, id) {
  await expect.poll(async () => page.evaluate(async ([d, i]) => {
    if (!window.idbGetAll) return false;
    return (await window.idbGetAll(d)).some(x => x && x.id === i);
  }, [depo, id]), { timeout: 45000, intervals: [500, 2000] }).toBe(true);
}
async function gorevKarti(page, gorevId, filtre) {
  await idbBekle(page, 'gorev_log', gorevId);
  await navTo(page, '#nb-tasks');
  await page.evaluate(f => window.loadTasks && window.loadTasks(f), filtre);
  const kart = page.locator(`#tc-${gorevId}`);
  await expect(kart).toBeVisible({ timeout: 15000 });
  return kart;
}
async function k8Sec(page, secim) {
  const k8 = page.locator('#ovt-k8-bs');
  await expect(k8).toBeVisible({ timeout: 15000 });
  await expect(k8).toContainText('🚆 Trene bin');
  await expect(k8.locator('[data-secim="TREN"]')).toHaveAttribute('aria-checked', 'true');   // K8: Trene bin ön seçili
  if (secim === 'BAGIMSIZ') await k8.locator('[data-secim="BAGIMSIZ"]').click();
  await k8.locator('[data-ovt-aksiyon="BASLAT"]').click();
  await expect(k8).toHaveCount(0, { timeout: 15000 });
}
// Uygulamayı açar ve İLK pull'un bitmesini bekler. Pull bitmeden: IDB protokol_ayar boş → bayrak kapıları (K8 sorusu,
// ui.js loadOvsyncDash) eski yola düşer; pull sonu render açık modalın seçimini sıfırlar ("Hastalık seçilmedi") — koşum 3-4
// ölçümü. Bayrak IDB'de görülünce pullTables zincirine (api.js _pullChain) eklenen tek tablo, ilk pull'un bitişini bekletir.
async function acTren(page) {
  await openApp(page);
  await expect.poll(async () => page.evaluate(async () => {
    if (!window.idbGetAll) return false;
    return (await window.idbGetAll('protokol_ayar')).some(a => a && a.anahtar === 'ovsync_tren_aktif' && Number(a.deger) === 1);
  }), { timeout: 45000, intervals: [500, 2000] }).toBe(true);
  await page.evaluate(async () => { if (window.pullTables) await window.pullTables(['protokol_ayar']); });
}
// Ön koşul: ekranın iki sunucu okuması (takip + tren listesi) hatasız döner — UI listele hatasını yutup eski yola düştüğü için
// (ui.js loadOvsyncDash) hata metni burada görünür kılınır; UI tren yoluna geçmezse kök ekran metni hata iletisine eklenir.
async function ovsyncAc(page, caseId) {
  await rpc('ovsync_takip_listele', { p_padok: null });
  const l = await rpc('ovsync_tren_listele', {});
  expect(l?.aktif, 'ovsync_tren_listele.aktif').toBe(true);
  if (caseId) await idbBekle(page, 'cases', caseId);
  await page.evaluate(() => { window._ovsyncTakipInvalidate && window._ovsyncTakipInvalidate(); window.goTo && window.goTo('ovsync'); });
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  try {
    await expect(page.locator('#pg-ovsync .ovs-bolum h2', { hasText: 'Trenler' })).toBeVisible({ timeout: 30000 });
  } catch (e) {
    const kok = await page.locator('#ovsync-root').innerText().catch(() => '(okunamadı)');
    throw new Error(`${e.message}\nOVSYNC-ROOT: ${kok.slice(0, 800)}`);
  }
}
async function devamSecici(page, ad) {
  await idbBekle(page, 'tohumlama', S[ad].tohId);
  await navTo(page, '#nb-ureme');
  await page.click('#ureme-tab-tohumlama');
  await page.fill('#tohumlama-srch', S[ad].kupe);
  const satir = page.locator('#ureme-body .hist-row', { hasText: S[ad].kupe }).first();
  await expect(satir).toBeVisible({ timeout: 10000 });
  await satir.click();
  await page.check('input[name="toh-sonuc"][value="Boş"]');
  await page.click('[data-action="toh-sonuc-kaydet"]');
  await expect(page.locator('#devam-secici-bs')).toBeVisible({ timeout: 10000 });
  expect(await page.evaluate(() => window.__devamSecici?.secim)).toBe('OVSYNC');
  await page.click('#devam-onayla');
}
async function toptanAc(page, x, caseId = S.d.caseId) {
  await ovsyncAc(page, caseId);
  // x treninin KENDİ başlığındaki düğme (geçen haftanın treni de aynı data-tarih'li düğme çiziyor — rapordaki BULGU)
  const ad = await page.evaluate(iso => window._ovtGunAd(iso), x);
  const bas = page.locator('#pg-ovsync .ovs-tren-bas', { has: page.locator('.ovs-tren-ad', { hasText: `Tren · ${ad} ·` }) });
  const btn = bas.locator(`.ovs-tren-ertele[data-tarih="${x}"]`);
  await expect(btn).toBeVisible({ timeout: 15000 });
  await btn.click();
  await expect(page.locator('#ovt-toptan-bs [data-ovt-aksiyon="ONAYLA"]')).toBeVisible({ timeout: 15000 });
}

test('trene bin: ▶ Başlat modalında Trene bin → vaka D0 = tren', async ({ page }) => {
  await acTren(page);
  const kart = await gorevKarti(page, S.a.gorevId, 'today');
  await kart.getByText('▶ Başlat').click();
  await k8Sec(page, 'TREN');
  const v = await dbBekle(() => aktifVaka(S.a.hayvanId));
  expect(v, 'aktif Ovsync vakası açılmalı').toBeTruthy();
  expect(v.start_date).toBe(T);
  expect(v.ovsync_tren).toBe(T);
  expect(v.ovsync_bagimsiz).toBe(false);
  expect((await gunler(v.id))[0].treatment_date).toBe(T);
});

test('bağımsız başlat → D0 bugün, listede bağımsızlar', async ({ page }) => {
  await acTren(page);
  const kart = await gorevKarti(page, S.b.gorevId, 'today');
  await kart.getByText('▶ Başlat').click();
  await k8Sec(page, 'BAGIMSIZ');
  const v = await dbBekle(() => aktifVaka(S.b.hayvanId));
  expect(v, 'aktif Ovsync vakası açılmalı').toBeTruthy();
  expect(v.start_date).toBe(B);
  expect(v.ovsync_tren).toBeNull();
  expect(v.ovsync_bagimsiz).toBe(true);
  const l = await rpc('ovsync_tren_listele', {});
  expect(l.bagimsizlar.some(u => u.hayvan_id === S.b.hayvanId)).toBe(true);
  await idbBekle(page, 'cases', v.id);
  await ovsyncAc(page);
  // Bağımsız bölümü Trenler bölümünün İÇİNDE (ui.js _ovsyncTrenGovdeHtml) → başlığı doğrudan kendi .ovs-bh'si olan bölüm
  const blok = page.locator('#pg-ovsync .ovs-bolum:has(> .ovs-bh > h2:text-is("Bağımsız"))');
  await expect(blok).toContainText(S.b.kupe, { timeout: 15000 });
});

test('V3 Vaka Aç + Ovsync şablonu: Trene bin → gün#1 = tren', async ({ page }) => {
  await acTren(page);
  await idbBekle(page, 'hayvanlar', S.v.hayvanId);
  await page.evaluate(k => window.openMWithHayvan('m-disease', 'd-hid', k), S.v.kupe);
  await expect(page.locator('#m-disease')).toHaveClass(/on/);
  await expect(page.locator(`#d-disease-id option[value="${OVS_HASTALIK}"]`)).toHaveCount(1, { timeout: 15000 });
  await page.selectOption('#d-disease-id', OVS_HASTALIK);
  await page.locator(`input[name="d-sablon"][value="${OVS_SABLON}"]`).check();
  await page.click('#m-disease [data-action="submit-case"]');
  await k8Sec(page, 'TREN');
  const v = await dbBekle(async () => { const x = await aktifVaka(S.v.hayvanId); return x && (await gunler(x.id)).length ? x : null; });
  expect(v, 'vaka + şablon günleri').toBeTruthy();
  expect((await gunler(v.id))[0].treatment_date).toBe(T);
  expect(v.ovsync_tren).toBe(T);
});

test('G7 Boş sonrası Ovsync uygula: Trene bin → görev hedefi tren; Bağımsız → vaka bugün', async ({ page }) => {
  await acTren(page);
  await devamSecici(page, 'g7a');
  await k8Sec(page, 'TREN');
  const ob = await dbBekle(async () => (await acikOb(S.g7a.hayvanId))[0]);
  expect(ob, 'Trene bin → açık OVSYNC_BASLAT').toBeTruthy();
  expect(ob.hedef_tarih).toBe(T);
  expect(await aktifVaka(S.g7a.hayvanId)).toBeNull();
  await devamSecici(page, 'g7b');
  await k8Sec(page, 'BAGIMSIZ');
  const v = await dbBekle(() => aktifVaka(S.g7b.hayvanId), 45000);
  expect(v, 'Bağımsız → vaka bugün başlar').toBeTruthy();
  expect(v.start_date).toBe(B);
  expect(v.ovsync_bagimsiz).toBe(true);
});

test('geç tamamlama: PG1 seansı 2 gün geç → uyarı sheet\'i', async ({ page }) => {
  await acTren(page);
  // Görevler listesinde seans kartı (#sg-…) ✓ işareti flushPendingDone'dan geçer (uyarı kancası yok) → vaka kartı yolu
  await idbBekle(page, 'treatment_day_uygulamalar', S.g.pg1Seans);
  await page.evaluate(c => window.openCaseDet(c), S.g.caseId);
  await expect(page.locator('#m-case-det')).toHaveClass(/on/, { timeout: 10000 });
  const ok = page.locator(`#m-case-det .seans-row[data-seans-id="${S.g.pg1Seans}"] .seans-btn-ok`);
  await expect(ok).toBeVisible({ timeout: 15000 });
  await ok.click();
  const sheet = page.locator('#ovt-uyari-bs');
  await expect(sheet).toBeVisible({ timeout: 15000 });
  await expect(sheet).toContainText('PG1 2 gün geç — baştan başlat önerilir');
  await expect(sheet.locator('[data-ovt-aksiyon="BASTAN"]')).toBeVisible();
});

test('aşama 2 (a): PG48 → kalan günler kapandı, TAI durur', async ({ page }) => {
  await acTren(page);
  await ovsyncAc(page, S.e.caseId);
  const btn = page.locator(`#pg-ovsync [data-ovt-aksiyon="PG48"][data-case="${S.e.caseId}"]`);
  await expect(btn).toBeVisible({ timeout: 15000 });
  await btn.click();
  const acik = await dbBekle(async () => {
    const { data } = await db.from('treatment_day_uygulamalar').select('id,uygulama_tamamlandi_at,uygulanmadi').eq('case_id', S.e.caseId);
    return data && !data.some(u => !u.uygulama_tamamlandi_at && !u.uygulanmadi) ? data : null;
  });
  expect(acik, 'kalan seanslar kapanmalı (uygulanmadı)').toBeTruthy();
  const { data: tai } = await db.from('gorev_log').select('id').eq('hayvan_id', S.e.hayvanId).eq('gorev_tipi', 'TOHUMLAMA_PLANLI')
    .like('kaynak', 'PG_TOHUMLAMA:%').eq('tamamlandi', false).eq('iptal', false);
  expect(tai.length, 'PG1+48 TAI açık kalmalı').toBe(1);
});

test('aşama 2 (b): baştan başlat → yeni görev tren günü', async ({ page }) => {
  await acTren(page);
  await ovsyncAc(page, S.f.caseId);
  const btn = page.locator(`#pg-ovsync [data-ovt-aksiyon="BASTAN"][data-case="${S.f.caseId}"]`);
  await expect(btn).toBeVisible({ timeout: 15000 });
  await btn.click();
  const ob = await dbBekle(async () => (await acikOb(S.f.hayvanId))[0]);
  expect(ob, 'yeni OVSYNC_BASLAT görevi').toBeTruthy();
  expect(ob.hedef_tarih).toBe(T);
  const eski = await vakaOku(S.f.caseId);
  expect(eski.status).not.toBe('active');
  expect(eski.close_reason).toBe('IPTAL');
});

test('toptan +1: önizleme KAYAR, onay sonrası görev hedefleri +1, başlık yeni gün', async ({ page }) => {
  await acTren(page);
  await toptanAc(page, T);
  const satir = page.locator('#ovt-toptan-bs .ovs-on-satir', { hasText: S.c.kupe });
  const yeni = gunEkle(T, 1);
  const ad = await page.evaluate(iso => window._ovtGunAd(iso), yeni);
  await expect(satir.locator('.ovs-on-sonuc')).toHaveText(`kayar → ${ad}`);
  await expect(page.locator('#ovt-toptan-bs .ovs-on-satir', { hasText: S.d.kupe }).locator('.ovs-on-sonuc')).toHaveText(`kayar → ${ad}`);
  await page.locator('#ovt-toptan-bs [data-ovt-aksiyon="ONAYLA"]').click();
  await expect(page.locator('#ovt-toptan-bs')).toHaveCount(0, { timeout: 20000 });
  const ob = await dbBekle(async () => { const x = (await acikOb(S.c.hayvanId))[0]; return x?.hedef_tarih === yeni ? x : null; });
  expect(ob, `c görevi ${yeni}`).toBeTruthy();
  expect((await acikOb(S.g7a.hayvanId))[0]?.hedef_tarih).toBe(yeni);
  expect((await aktifVaka(S.a.hayvanId))?.ovsync_tren).toBe(yeni);
  const { data: ay } = await db.from('protokol_ayar').select('deger').eq('anahtar', 'ovsync_tren_capa').single();
  expect(String(ay.deger)).toBe(yeni.replace(/-/g, ''));
  await ovsyncAc(page);
  await expect(page.locator('#pg-ovsync .ovs-tren-bas', { hasText: `Tren · ${ad}` })).toBeVisible({ timeout: 15000 });
});

test('toptan +3: aşama 1 BASTAN → eski vaka IPTAL', async ({ page }) => {
  await acTren(page);
  const x = gunEkle(T, 1);
  await toptanAc(page, x);
  await page.locator('#ovt-toptan-bs [data-n="3"]').click();
  const satir = page.locator('#ovt-toptan-bs .ovs-on-satir', { hasText: S.d.kupe });
  await expect(satir.locator('.ovs-on-sonuc')).toContainText('baştan başlar →', { timeout: 15000 });
  await page.locator('#ovt-toptan-bs [data-ovt-aksiyon="ONAYLA"]').click();
  await expect(page.locator('#ovt-toptan-bs')).toHaveCount(0, { timeout: 20000 });
  const eski = await dbBekle(async () => { const v = await vakaOku(S.d.caseId); return v?.status !== 'active' ? v : null; });
  expect(eski, 'eski vaka kapanmalı').toBeTruthy();
  expect(eski.close_reason).toBe('IPTAL');
  expect((await acikOb(S.d.hayvanId))[0]?.hedef_tarih).toBe(gunEkle(x, 3));
});

// Sonda: TAI kartı tren eylemlerinden etkilenmez (h ritim dışı); bağımsız okuma testi.
test('görevler ekranı: Ovsync TAI\'de Ertele yok', async ({ page }) => {
  await acTren(page);
  await idbBekle(page, 'cases', S.h.caseId);
  const kart = await gorevKarti(page, S.h.taiId, 'today');
  await expect(kart.locator('[data-ertele]'), 'Ovsync TAI kartında Ertele düğmesi').toHaveCount(0);
  await expect(kart.locator('.ovs-duzenle-link')).toHaveText('Ovsync ekranında düzenle →');
});
