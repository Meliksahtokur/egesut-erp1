// tests/e2e/ovsync-takip.spec.js
// Ovsync Takip Ekranı — demo Playwright temsilciler (plan v7 P12; katalog T-56, T-32/T-59,
// T-01/T-02/T-07, T-20, T-38/T-44, T-04/T-05 K15, T-25/T-26, T-87(21g), T-19,
// T-73 REST guard, T-89 C4, T-84/T-85, T-03/T-50 katmanları).
//
// P12 TESLİM (2026-10-01): P4–P10 implementasyonu teslim edildiği için iskelet, TESLİM
// EDİLEN UI ile hizalandı (kırmızı→yeşil; kırmızı kanıt: koşum çıktısı
// runs/.../impl-P12-DONE.md). Teslim edilen gerçekler buraya kilitli:
//   - devam seçici: `#devam-secici-bs`; kartlar `[data-action="devam-secici-sec"][data-secim=…]`
//     (radio DEĞİL); ana buton `#devam-onayla`; S3b ön seçim OVSYNC
//   - TAKIP_ACIK onay sheet: `#takip-acik-bs` (+ `#takip-acik-onayla` "Evet, takibi kapat ve
//     uygula"); yalnız PG kapısı: `#pg-kapi-bs`
//   - KPA şeridi küçük harf etiketler; bölümler `.ovs-bolum` (h2 "S0 · Bugün & Geciken");
//     S2 sayaç "muayeneye N gün", vakti dolanlarda "🩺 Muayene sonucu" butonu
//   - takipte satır: `.ovs-takip-satir` + "🔍 takipte" rozeti (satır tıklaması aksiyon YOK)
//   - 21 g onayı: `#m-confirm` (openConfirm — native dialog YASAK)
//   - invalidate: api.js `tohumlamaBosVeDevam` iki yolda da `_ovsyncTakipInvalidate` çağırır
//
// Veri politikası: veri-agnostik + E2E-TAKIP-PW- marker'lı seed (yalnız demo; cleanup afterAll).
// Her test KENDİ seed hayvanını kullanır (paralel worker'larda sıralı bağımlılık yok).
// Var olan sonuclar.json ya da başka kullanıcı artefaktına dokunulmaz — bu spec rapor yazmaz
// (hedefli koşum: --reporter=list).
//
// T-73 REST guard + T-89 C4 negatifleri bu dosyada betikleşir (plan.md:696 birebir):
// authenticated REST ile jenerik `gorev_tamamla` GEBELIK_KONTROL görevini kapatamaz
// (MUAYENE_SONUC_GEREKLI); `kizginlik_vaka_ac` onaysız açık takipli hayvanda TAKIP_ACIK red
// (tanıdan bağımsız iki varyant), onaylı çağrı vaka + takip OVSYNC kapanışı üretir.
//
// Koşum (demo; dal kodu yerel sunucudan servis edilir):
//   python3 -m http.server 8137 --bind 127.0.0.1   (worktree kökü)
//   docker run --rm --network host -v "$PWD":/work -w /work -v /home/melik/egesut-erp1:/main:ro \
//     -e NODE_PATH=/main/node_modules -e PLAYWRIGHT_DEMO_MODE=1 \
//     -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8137/ -e HOME=/tmp/pwhome \
//     mcr.microsoft.com/playwright:v1.58.2-noble \
//     /main/node_modules/.bin/playwright test tests/e2e/ovsync-takip.spec.js \
//     --reporter=list --retries=0 --workers=1

import { test, expect, openApp, navTo, goOffline, IS_DEMO } from '../support/app.js';
import { createClient } from '@supabase/supabase-js';

const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
const MARKER = 'E2E-TAKIP-PW-';

test.skip(!IS_DEMO, 'ovsync-takip temsilcileri: yalnız PLAYWRIGHT_DEMO_MODE=1 ile koşar');

// KOŞUM SÖZLEŞMESİ: --workers=1 ZORUNLU. beforeAll worker başına bir kez koşar;
// paylaşımlı seed çok-worker'da kendini siler (2026-10-01 koşum dersi: 12 worker
// → 94 kalıntı hayvan). Test dosyası tek worker'da sıralı koşar, her test bağımsız.
test.setTimeout(60000); // açık akış zincirleri (seçici→RPC→DB poll) 30 s'yi aşabilir

let db;   // demo authenticated client (seed/REST kanıtı/cleanup)
let S;    // seed kayıtları (hayvan başına {kupe, hayvanId, tohId, gorevId, ...})

// TR = UTC+3 (sabit): sunucu CURRENT_DATE (Europe/Istanbul) ile aynı takvim günü.
const trBugun = () => new Date(Date.now() + 3 * 3600e3).toISOString().slice(0, 10);
const trGun = n => new Date(Date.now() + 3 * 3600e3 + n * 864e5).toISOString().slice(0, 10);

test.beforeAll(async () => {
  db = createClient(DEMO_URL, DEMO_KEY);
  const { error } = await db.auth.signInWithPassword(DEMO_LOGIN);
  if (error) throw new Error(`demo giriş başarısız: ${error.message}`);

  // ARTIK-DAYANIKLILIK (TB-6): önceki koşumun/çöken worker'ın kalıntısı (açık takip görevi,
  // Bekliyor tohumlama, Satıldı'da kalmış hayvan) seed'i TAKIP_ACIK / "aktif değil" ile
  // kırmasın. Temizlik fail-closed: başarısızsa seed hiç başlamaz.
  await temizle('önce');

  // IDEMPOTENT SEED: tüm id'ler SABİT (harf türetilir). beforeAll worker-başına
  // ve worker-yeniden-başlangıcında TEKRAR koşabilir — her koşum AYNI duruma
  // yakınsar (var olan satır yeniden kullanılır, çocuklar tazelenir).
  S = {};
  const sabitUuid = n => `e2e10000-0000-4000-8000-${String(n).padStart(12, '0')}`;
  const tohNo = { a: 11, b: 12, c: 13, c2: 14, d: 15, e: 16, f: 17, h: 18, i: 19, l: 20 };
  const gorevNo = { a: 21, b: 22, c: 23, c2: 24, d: 25, e: 26, f: 27, h: 28, i: 29, l: 30 };

  const hayvanEkle = async ad => {
    // id UUID-BİÇİMLİ olmalı: sarmalın TAKIP-kurma yolu hayvan id'sini ::uuid'e
    // cast eder (tohumlama_bos_ve_devam → _takip_gorev_kur(uuid, …)) — düz metin
    // id'de "invalid input syntax for type uuid" (t72b-mini.py deseni). Kupe
    // okunabilir marker kalır (UI aramaları kupe_no üzerinden).
    const hayvanNo = { a: 1, b: 2, c: 3, c2: 4, d: 5, e: 6, f: 7, h: 8, i: 9, l: 10 };
    const id = `e2ef0000-0000-4000-8000-${String(hayvanNo[ad]).padStart(12, '0')}`;
    const kupe = MARKER + ad;
    const { data: got, error: eg } = await db.from('hayvanlar').select('id,durum').eq('id', id);
    if (eg) throw new Error(`seed hayvan ${ad} sorgusu başarısız: ${eg.message}`);
    if (got?.length && got[0].durum !== 'Aktif') {
      // temizle() FK yüzünden silemediği hayvanı Satıldı'ya çeker (çıkış); yeniden kullanımda
      // aktifleştir (aksi halde hizli_uygulama "Hayvan bulunamadı veya aktif değil" der).
      const { error: ea } = await db.from('hayvanlar').update({ durum: 'Aktif' }).eq('id', id);
      if (ea) throw new Error(`seed hayvan ${ad} yeniden aktifleştirme başarısız: ${ea.message}`);
    }
    if (!got?.length) {
      const { error: e1 } = await db.from('hayvanlar').insert({
        id, kupe_no: kupe, cinsiyet: 'Dişi', durum: 'Aktif',
        // 500 gün: geçmiş tarihli tohumlama seed'lerinde de VWP yaşı (tarih anında
        // ≥12 ay) tutar — tetikleyici yaşı TOHUMLAMA TARİHİNDE kontrol eder
        dogum_tarihi: trGun(-500), grup: 'Sağmal (Laktasyonda)',
      }).select('id').single();
      if (e1) throw new Error(`seed hayvan ${ad} başarısız: ${e1.message}`);
    }
    S[ad] = { kupe, hayvanId: id };
  };

  const tohumlamaEkle = async (ad, gunOffset, sonuc = 'Bekliyor') => {
    const id = sabitUuid(tohNo[ad]);
    await db.from('tohumlama').delete().eq('hayvan_id', S[ad].hayvanId);
    const { data, error: e2 } = await db.from('tohumlama').insert({
      id, hayvan_id: S[ad].hayvanId, tarih: trGun(gunOffset), sonuc,
      deneme_sayisi: 1, denemeler: [],
    }).select('id').single();
    if (e2) throw new Error(`seed tohumlama ${ad} başarısız: ${e2.message}`);
    S[ad].tohId = data.id;
  };

  const gorevEkle = async (ad, tip, gunOffset, ekstra = {}) => {
    const id = sabitUuid(gorevNo[ad]);
    await db.from('gorev_log').delete().eq('hayvan_id', S[ad].hayvanId);
    const { data, error: e3 } = await db.from('gorev_log').insert({
      id, hayvan_id: S[ad].hayvanId, gorev_tipi: tip,
      aciklama: MARKER + ad, hedef_tarih: trGun(gunOffset),
      tamamlandi: false, iptal: false,
      kaynak: ekstra.kaynak ?? ('TAKIP:' + (S[ad].tohId ?? 'E2E')),
      ...(ekstra.created_atGunOffset ? { created_at: new Date(Date.now() + 3 * 3600e3 + ekstra.created_atGunOffset * 864e5).toISOString() } : {}),
      ...(ekstra.hedef_saat ? { hedef_saat: ekstra.hedef_saat } : {}),
    }).select('id').single();
    if (e3) throw new Error(`seed görev ${ad}/${tip} başarısız: ${e3.message}`);
    if (!S[ad].gorevId) S[ad].gorevId = data.id;
    return data.id;
  };

  // PG geçmişi (son_pg): hizli_uygulama RPC — pg_application_event authenticated
  // INSERT'e KAPALI (RLS/GRANT yok — 2026-10-01 ölçüm), olay yalnız RPC yoluyla kurulur.
  const pgGecmisiEkle = async ad => {
    // RPC'den ÖNCE eski durum: açık takip görevi + Bekliyor tohumlama kaldıysa
    // hizli_uygulama PG_KAPI:TAKIP_ACIK ile reddeder (2. koşum dersi 2026-10-01).
    // AWAIT + hata kontrolü (eskiden await'siz TRY: yarış + sessiz yutma). pg_application_event
    // BİLEREK silinmez: authenticated DELETE yetkisi yok (42501, 2026-10-02 ölçüm); eski olay
    // hayvan id'sine bağlı kalır, aşağıdaki RPC yeni olay ekler (zararsız, bkz. temizle()).
    for (const t of ['gorev_log', 'tohumlama', 'uygulama_log']) {
      const { error: ed } = await db.from(t).delete().eq('hayvan_id', S[ad].hayvanId);
      if (ed) throw new Error(`seed ön-temizlik ${t}/${ad} başarısız: ${ed.message}`);
    }
    const { data: stok, error: es } = await db.from('stok').select('id,birim').eq('urun_adi', 'PGs (alke)').limit(1).single();
    if (es || !stok) throw new Error('seed PG stoğu bulunamadı (PGs (alke))');
    const { data: res, error: er } = await db.rpc('hizli_uygulama', {
      p_hayvan_id: S[ad].hayvanId, p_stok_id: stok.id, p_doz: 5,
      p_birim: stok.birim || 'ml', p_rota: 'IM', p_notlar: MARKER + 'pg-gecmis',
    });
    if (er) throw new Error(`seed hizli_uygulama ${ad} başarısız: ${er.message}`);
    if (res && res.ok === false) throw new Error(`seed hizli_uygulama ${ad} reddi: ${res.mesaj}`);
  };

  const kizginlikEkle = async (ad, no, belirti) => {
    const id = 'e2e-takip-pw-kiz-' + no;
    await db.from('kizginlik_log').delete().eq('id', id);
    const { data, error: ek } = await db.from('kizginlik_log').insert({
      id, hayvan_id: S[ad].hayvanId, tarih: trBugun(), belirti,
    }).select('id').single();
    if (ek) throw new Error(`seed kızgınlık ${ad} başarısız: ${ek.message}`);
    return data.id;
  };

  // ── A: S2 satır (Bekliyor 45 gün önce) ── "muayene vakti" (bkz. T-38 notu)
  await hayvanEkle('a');
  await tohumlamaEkle('a', -45);

  // ── B: takipte + PG geçmişi → TAKIP_ACIK sheet (yalın; Boş ataması kapıyı
  //      Boş'tan okuduğu için birleşik çıkması beklenmez — teslimatta ölçüldü)
  await hayvanEkle('b');
  await pgGecmisiEkle('b');
  await tohumlamaEkle('b', 0);
  await gorevEkle('b', 'TAKIP_MUAYENE', 7, { hedef_saat: '09:00:00' });

  // ── C: muayene vakti + GEBELIK_KONTROL görevi → birleşik sonuç ekranı (salt-okunur)
  await hayvanEkle('c');
  await tohumlamaEkle('c', -45);
  await gorevEkle('c', 'GEBELIK_KONTROL', -5, { kaynak: 'GEBELIK-KONTROL-' + S.c.tohId, created_atGunOffset: -5 });

  // ── C2: ertele (saatsiz default) — C'den bağımsız hayvan
  await hayvanEkle('c2');
  await tohumlamaEkle('c2', -45);
  await gorevEkle('c2', 'GEBELIK_KONTROL', -5, { kaynak: 'GEBELIK-KONTROL-' + S.c2.tohId });

  // ── D: kızgınlık C4 (takipte + 2 kızgınlık kaydı: Ovsync içi + dışı tanı)
  await hayvanEkle('d');
  await tohumlamaEkle('d', 0);
  await gorevEkle('d', 'TAKIP_MUAYENE', 7, { hedef_saat: '10:30:00' });
  S.d.kiz1 = await kizginlikEkle('d', 'kiz1', 'Kızgınlık');
  S.d.kiz2 = await kizginlikEkle('d', 'kiz2', 'Kızgınlık');

  // ── E: sessiz kapanış (takipte hayvana yeni tohumlama)
  await hayvanEkle('e');
  await tohumlamaEkle('e', 0);
  await gorevEkle('e', 'TAKIP_MUAYENE', 7, { hedef_saat: '08:00:00' });

  // ── F: Boş→Takibe bırak (devam seçici yolu) + invalidate temsilcisi
  await hayvanEkle('f');
  await tohumlamaEkle('f', 0);

  // ── H: takip muayenesi ertele → 21 g onayı (created_at −20 g)
  await hayvanEkle('h');
  await tohumlamaEkle('h', -20, 'Boş');
  await gorevEkle('h', 'TAKIP_MUAYENE', 7, { created_atGunOffset: -20, hedef_saat: '07:30:00' });

  // ── I: takip muayenesi → Gebe (Boş düzeltme izi; kalem 11/12)
  await hayvanEkle('i');
  await tohumlamaEkle('i', -45, 'Boş');
  await gorevEkle('i', 'TAKIP_MUAYENE', 7, { created_atGunOffset: -45, hedef_saat: '06:30:00' });

  // ── J: YOK — yalnız PG_KAPI senaryosu (Bekliyor + takipsiz) sarmal yolundan
  //      deterministik üretilemez: sarmal PG'de Boş ataması ÖNCE yapılır, _pg_kapi
  //      kararı güncel son tohumlamadan okunur → karar ALLOW döner (20261001 ölçüm,
  //      _pg_kapi:218-227). T-06 UI kanıtı glmf-max listesinde (kalem 10) kalır.
  // ── L: jenerik gorev_tamamla REST guard (GEBELIK_KONTROL sonuçsuz kapanmaz)
  await hayvanEkle('l');
  await tohumlamaEkle('l', -45);
  await gorevEkle('l', 'GEBELIK_KONTROL', -2, { kaynak: 'GEBELIK-KONTROL-' + S.l.tohId });
});

// afterAll hatayı FIRLATIR (fail-closed): temizlik başarısızsa açık hata görünür; test
// sonuçlarını maskelemez (hook hatası ayrı satır olarak raporlanır, test PASS/FAIL'i değişmez).
test.afterAll(async () => { await temizle('sonra'); });

// TB-6 temizlik: hayvanlar `kupe_no LIKE MARKER%` ile bulunur (id UUID'dir; marker yalnız kupe_no'da).
// Yalnız bu spec'in kendi E2E-TAKIP-PW-* fixture'ları — başka E2E-* (UITUR vb.) kümelerine DOKUNMAZ.
// Her adım hata kontrollüdür; hatalar toplanır, sonda tek Error ile fırlatılır (sessiz yutma YOK).
//   - pg_application_event BİLEREK silinmez: authenticated'a DELETE yetkisi yok (42501, 2026-10-02
//     ölçüm) ve hayvan_id FK'sı hayvan satırını tutar. Bu bilinen kısıt hata SAYILMAZ; çözümü
//     hayvanı çıkışa (Satıldı) çekmektir — trg_hayvan_cikis_gorev_iptal açık görevleri iptal eder
//     (domain-rules §10). Başka her silme hatası gerçek hata → toplanır.
//   - Sonda doğrulama: marker'lı hayvanlardan hiçbiri Aktif, hiçbir açık görev kalmamalı.
async function temizle(faz) {
  const hatalar = [];
  const adim = async (ad, p) => {
    const { data, error } = await p;
    if (error) { hatalar.push(`${ad}: ${error.message}`); return null; }
    return data ?? [];
  };
  const { data: eski, error: eh } = await db.from('hayvanlar').select('id').like('kupe_no', MARKER + '%');
  if (eh) throw new Error(`temizlik[${faz}] hayvan sorgusu başarısız: ${eh.message}`);
  const ids = (eski ?? []).map(h => h.id);
  if (!ids.length) return;

  // vaka zinciri (C4 onaylı yol: cases + gün/uygulama) — cases.animal_id üzerinden
  const cases = await adim('cases sorgu', db.from('cases').select('id').in('animal_id', ids));
  const cid = (cases ?? []).map(c => c.id);
  if (cid.length) {
    await adim('treatment_day_uygulamalar', db.from('treatment_day_uygulamalar').delete().in('case_id', cid).select('id'));
    await adim('treatment_days', db.from('treatment_days').delete().in('case_id', cid).select('id'));
  }
  for (const t of ['protokol_instance', 'kizginlik_log', 'uygulama_log', 'gorev_log', 'tohumlama']) {
    await adim(t, db.from(t).delete().in('hayvan_id', ids).select('id'));
  }
  if (cid.length) await adim('cases', db.from('cases').delete().in('id', cid).select('id'));

  // hayvan: önce sil; yalnız FK ihlali (23503, pg_application_event) → çıkış (Satıldı).
  // Çıkış, kalan açık görevleri trigger ile iptal eder. Başka hata → gerçek hata.
  for (const id of ids) {
    const { error: es } = await db.from('hayvanlar').delete().eq('id', id).select('id');
    if (!es) continue;
    if (es.code !== '23503') { hatalar.push(`hayvanlar sil ${id}: ${es.message}`); continue; }
    await adim(`hayvanlar → Satıldı ${id}`, db.from('hayvanlar').update({ durum: 'Satıldı' }).eq('id', id).select('id'));
  }

  // DOĞRULAMA: kalan marker'lı hayvan Aktif olmamalı, açık görev kalmamalı
  const { data: kalan, error: ek } = await db.from('hayvanlar').select('id,kupe_no,durum').like('kupe_no', MARKER + '%');
  if (ek) hatalar.push(`doğrulama hayvan sorgusu: ${ek.message}`);
  const aktif = (kalan ?? []).filter(h => h.durum === 'Aktif');
  if (aktif.length) hatalar.push(`${aktif.length} marker'lı hayvan hâlâ Aktif: ${aktif.map(h => h.kupe_no).join(', ')}`);
  if ((kalan ?? []).length) {
    const { data: acik, error: eo } = await db.from('gorev_log').select('id').in('hayvan_id', kalan.map(h => h.id)).eq('tamamlandi', false).eq('iptal', false);
    if (eo) hatalar.push(`doğrulama açık görev sorgusu: ${eo.message}`);
    else if (acik?.length) hatalar.push(`${acik.length} açık görev kaldı`);
  }
  if (hatalar.length) throw new Error(`temizlik[${faz}] başarısız:\n  - ${hatalar.join('\n  - ')}`);
}

// DB bekleme yardımcıları (yazma→okuma tutarlılığı için kısa poll)
async function dbTek(tablo, sutun, deger, sutunlar = '*') {
  const { data } = await db.from(tablo).select(sutunlar).eq(sutun, deger);
  return data?.[0] ?? null;
}
async function dbBekle(fn, ms = 10000) {
  const son = Date.now() + ms;
  while (Date.now() < son) {
    const r = await fn();
    if (r) return r;
    await new Promise(t => setTimeout(t, 400));
  }
  return null;
}

// ── Ortak akış: üreme → tohumlama → kayıt detayı → Boş → devam seçici ─────────
async function devamSeciciAc(page, ad) {
  // İlk IDB pull bitmeden tohumlama/hayvanlar depoları BOŞTUR (triyaj 2026-10-02: t=3 s'de
  // her ikisi boş, satır pull'dan sonra düşer → 10 s'lik görünürlük beklemesi pull süresine
  // yetmeyip "Arama sonucu yok" veriyordu). Aramadan ÖNCE seed kayıtlarının IDB'ye düşmesini bekle.
  await expect.poll(async () => page.evaluate(async ([tid, hid]) => {
    if (!window.idbGetAll) return false;
    const t = (await window.idbGetAll('tohumlama')).some(x => x && x.id === tid);
    const h = (await window.idbGetAll('hayvanlar')).some(x => x && x.id === hid);
    return t && h;
  }, [S[ad].tohId, S[ad].hayvanId]), { timeout: 45000, intervals: [500, 2000] }).toBe(true);
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

// IDB pull beklemesi: app'in gorev_log IDB deposu, ilk pull bitmeden BOŞTUR
// (_muayeneSonucAc IDB'den bulur — görev IDB'ye düşmeden tıklanırsa fallback'e
// düşer, seçici AÇILMAZ). Muayene-ekranı akışları ÖNCE bunu bekler.
async function idbGorevBekle(page, gorevId, ms = 45000) {
  await expect.poll(async () => page.evaluate(async mid => {
    if (!window.idbGetAll) return false;
    const gs = await window.idbGetAll('gorev_log');
    return gs.some(g => g && g.id === mid);
  }, gorevId), { timeout: ms, intervals: [500, 2000] }).toBe(true);
}

// ═══ 1) T-56 — Giriş: dashboard 6. stat hücresi + goTo('ovsync') ═════════════
test('T-56: dashboard 6. hücre "Ovsync" görünür; tıklayınca #pg-ovsync açılır', async ({ page }) => {
  await openApp(page);
  // K7/R4: .dash-row'da 6. .sc hücresi — "🔄 Ovsync ›" + aktif zincir sayısı
  const hucre = page.locator('.dash-row .sc', { hasText: 'Ovsync' });
  await expect(hucre).toHaveCount(1);
  await expect(hucre).toContainText('🔄');
  await hucre.click();
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
});

// ═══ 2) T-32/T-59 — Omurga: KPA şeridi (5 sayaç) + bölüm kümesi = satır kümesi ═
test('T-32/T-59: KPA şeridi 5 sayaç; render edilen bölüm başlıkları = dolu bölümler (boş gizli)', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  // §3 KPA: aktif · bugün · geciken · muayene bekleyen · bekleyen başlatma (hasText case-insensitive)
  await expect(page.locator('#pg-ovsync .ovs-kpa-c')).toHaveCount(5);
  for (const kpa of ['aktif', 'bugün', 'geciken', 'muayene bekleyen', 'bekleyen başlatma']) {
    await expect(page.locator('#pg-ovsync .ovs-kpa', { hasText: kpa })).toBeVisible();
  }
  // Boş bölüm HİÇ render edilmez: başlıklar (S0..S4) ⇔ RPC satırlarının bolum kümesi
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
});

// ═══ 3) T-01/T-07 + T-02 + T-03(ön ayar) — Devam seçici davranışı ════════════
test('T-01/T-07/T-02/T-03: Boş→seçici; Ovsync ön seçili; PG kartı ürün/doz ÖN DOLU; TAKIP +7 gün', async ({ page }) => {
  await openApp(page);
  await devamSeciciAc(page, 'b');
  // §6c.1: "Devam nasıl olsun? (zorunlu)"; S3b: ön seçim Ovsync; mockup 01 buton etiketi
  await expect(page.locator('#devam-secici-bs')).toContainText('Devam nasıl olsun? (zorunlu)');
  expect(await page.evaluate(() => window.__devamSecici?.secim)).toBe('OVSYNC');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + Ovsync başlat');
  // seçimsiz "yalnız Kaydet" YOK — sonuç modalı seçici akışına devredildi (görünmez)
  await expect(page.locator('#m-toh-det')).not.toHaveClass(/on/);
  // T-02: PG kartı — ürün/doz son kullanılandan ÖN DOLU (seed: hizli_uygulama PGs (alke) 5 ml)
  await page.click('[data-action="devam-secici-sec"][data-secim="PG"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + PG uygula');
  await expect(page.locator('#devam-onayla')).toBeEnabled();
  const urunDeger = await page.locator('#devam-secici-bs select[data-change="devam-urun"]').inputValue();
  expect(urunDeger, 'PG ürünü son kullanılandan dolu olmalı').not.toBe('');
  // T-03: TAKIP kartı — seçim alınır; gün ön ayarı sunucu varsayılanı +7
  // (UI kopyasında sayı YOK — kanıt T-03/T-50 testinin DB hedefinde: hedef = bugün+7)
  await page.click('[data-action="devam-secici-sec"][data-secim="TAKIP"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Boş ata + Takibe bırak');
  expect(await page.evaluate(() => window.__devamSecici?.secim)).toBe('TAKIP');
});

// ═══ 4) T-20 — TAKIP_ACIK onay sheet: app'in KENDİ bottom-sheet'i + Vazgeç ════
test('T-20: takipli+PG → TAKIP_ACIK onay sheet (#takip-acik-bs); Vazgeç yazma yapmaz', async ({ page }) => {
  await openApp(page);
  let nativeDialog = false;
  page.on('dialog', d => { nativeDialog = true; d.dismiss().catch(() => {}); });
  await devamSeciciAc(page, 'b');
  await page.click('[data-action="devam-secici-sec"][data-secim="PG"]');
  await page.click('#devam-onayla');
  // P10: TEK onay sheet — "Bu hayvan takipte" + küpe + rektal muayene gerekçesi (mockup 04)
  const sheet = page.locator('#takip-acik-bs');
  await expect(sheet).toBeVisible({ timeout: 10000 });
  await expect(sheet).toContainText('Bu hayvan takipte');
  await expect(sheet).toContainText(S.b.kupe);
  await expect(sheet).toContainText(/Rektal muayene takibi/);
  // P12b: yalın TAKIP_ACIK'ta detay DOĞRUDAN payload'dadır (takip_acik anahtarı
  // yalnız birleşikte) — _devamSeciciOnayla ortak çözümleyiciyle (ui.js
  // _takipDetayCoz) okur; sheet'te muayene tarihi + saat DOLU basılır
  // (seed b: hedef_saat '09:00:00'; UI HATASI #1 fix kanıtı, impl-P12b-DONE).
  await expect(sheet).toContainText(/\d{2}\.\d{2} 09:00'te rektal muayene takibinde\./);
  const onayBtn = page.locator('#takip-acik-onayla');
  await expect(onayBtn).toHaveText('Evet, takibi kapat ve uygula');
  await expect(sheet.getByRole('button', { name: 'Vazgeç' })).toBeVisible();
  expect(nativeDialog, 'native confirm()/alert() YASAK (§18.8, mockup 04)').toBe(false);
  // Vazgeç → hiçbir yazma yok
  await sheet.getByRole('button', { name: 'Vazgeç' }).click();
  await expect(sheet).toHaveCount(0);
  const toh = await dbTek('tohumlama', 'id', S.b.tohId, 'sonuc');
  expect(toh?.sonuc).toBe('Bekliyor');
  const gorev = await dbTek('gorev_log', 'id', S.b.gorevId, 'tamamlandi,iptal');
  expect(gorev?.tamamlandi).toBe(false);
  expect(gorev?.iptal).toBe(false);
});

// ═══ 6) T-38/T-44 — S2 satır: "muayene vakti" (40 g eşikten); "21" YOK ════════
// NOT: "muayeneye N gün" (kalan>0) dalı canlı üründe ULAŞILAMAZ: S2 kümesi
// tarih ≤ bugün−40 ile süzülür → kalan_gun = tarih+40−bugün ≤ 0 garantili →
// satır hep "muayene vakti" basar (ui.js _ovsyncMuayeneHtml kalan>0 dalı ölü;
// UI HATASI #3 — impl-P12-DONE'da raporlu). Test canlı davranışı kilitler.
test('T-38/T-44: S2 "muayene vakti" rozeti (40 g eşik); "21" sabiti yok', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync')).toHaveClass(/on/);
  // seed A: son tohumlama bugün−45 → 40 g eşiği geçti → S2 satırı + vakti rozeti
  const satir = page.locator('#pg-ovsync .ovs-s2-satir').filter({ hasText: new RegExp(S.a.kupe + '\\b') });
  await expect(satir).toBeVisible({ timeout: 10000 });
  await expect(satir).toContainText(/muayene vakti/);
  await expect(satir).toContainText(/\+\d+g/); // gecikme rozeti: kalan<0 → "+Ng"
  const govde = await page.locator('#pg-ovsync').innerText();
  expect(govde).not.toMatch(/21[.\s]*gün|21\. gün/); // T-44: "21. gün kontrol" YOK (iptal karar)
});

// ═══ 7) T-04/T-05 K15 — Muayene vakti satırı → birleşik sonuç ekranı ══════════
test('T-04/T-05 K15: S2 "muayene vakti" → 🩺 sonuç ekranı; GEBELIK_KONTROL 5 seçim', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await idbGorevBekle(page, S.c.gorevId);
  const satir = page.locator('#pg-ovsync .ovs-s2-satir').filter({ hasText: new RegExp(S.c.kupe + '\\b') });
  await expect(satir).toBeVisible({ timeout: 10000 });
  await expect(satir).toContainText(/muayene vakti/);
  await satir.getByRole('button', { name: /Muayene sonucu/ }).click();
  const secici = page.locator('#devam-secici-bs');
  await expect(secici).toBeVisible({ timeout: 10000 });
  // K15: GEBELIK_KONTROL ekranı — eyebrow/başlık + D3 kümesi {GEBE,OVSYNC,PG,TAKIP,ERTALE}
  await expect(secici).toContainText('Gebelik kontrolü');
  await expect(secici).toContainText(S.c.kupe);
  await expect(secici.locator('[data-action="devam-secici-sec"]')).toHaveCount(5);
  for (const secim of ['GEBE', 'OVSYNC', 'PG', 'TAKIP', 'ERTALE']) {
    await expect(secici.locator(`[data-secim="${secim}"]`)).toHaveCount(1);
  }
  // ERTALE saati VARSAYILAN SAATSİZ (§10d #3)
  await page.click('[data-action="devam-secici-sec"][data-secim="ERTALE"]');
  await expect(page.locator('#devam-onayla')).toContainText('Muayeneyi ertele (+7 gün)');
  await expect(page.locator('#devam-secici-bs input[data-alan="erteleSaat"]')).toHaveValue('');
});

// ═══ 8) T-25/T-26 — Ertele: +7 ön ayar, saatsiz Kaydet → DB hedef_saat NULL ═══
test('T-25/T-26: muayeneyi ertele (+7) saatsiz → görev hedef +7, hedef_saat NULL', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await idbGorevBekle(page, S.c2.gorevId);
  const satir = page.locator('#pg-ovsync .ovs-s2-satir', { hasText: S.c2.kupe });
  await expect(satir).toBeVisible({ timeout: 10000 });
  await satir.getByRole('button', { name: /Muayene sonucu/ }).click();
  await expect(page.locator('#devam-secici-bs')).toBeVisible({ timeout: 10000 });
  await page.click('[data-action="devam-secici-sec"][data-secim="ERTALE"]');
  // saat girilebilir ama ön ayar boş — saatsiz Kaydet
  await page.click('#devam-onayla');
  await expect(page.locator('#devam-secici-bs')).toHaveCount(0, { timeout: 15000 });
  // P12b: sunucu Europe/Istanbul yerel günüyle yazar (20261001000001) — hedef
  // BİREBİR İstanbul bugünü+7 (gece koşumunda da; eski +6 toleransı UTC CURRENT_DATE
  // hatasının gölgesiydi — UI/SUNUCU HATASI #2 fix kanıtı, impl-P12b-DONE).
  const gorev = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.c2.gorevId, 'hedef_tarih,hedef_saat');
    return g && g.hedef_tarih === trGun(7) ? g : null;
  });
  expect(gorev, `görev hedefi İstanbul-yerel bugün+7 (${trGun(7)}) olmalı`).toBeTruthy();
  expect(gorev.hedef_saat).toBeNull();
});

// ═══ 9) T-87 — Takip muayenesi ertele ≥21 g: TEK onay (S-7), TAKIP kartı YOK ══
test('T-87: TAKIP_MUAYENE ekranı 4 seçim (TAKIP yok); ertelemede "N gündür takipte" onayı', async ({ page }) => {
  await openApp(page);
  await idbGorevBekle(page, S.h.gorevId);
  await navTo(page, '#nb-tasks');
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  const kart = page.locator(`#tc-${S.h.gorevId}`);
  await expect(kart).toBeVisible({ timeout: 10000 });
  await kart.click();
  const secici = page.locator('#devam-secici-bs');
  await expect(secici).toBeVisible({ timeout: 10000 });
  await expect(secici).toContainText('Takip muayenesi');
  await expect(secici.locator('[data-action="devam-secici-sec"]')).toHaveCount(4);
  await expect(secici.locator('[data-secim="TAKIP"]')).toHaveCount(0); // D3: TAKIP_MUAYENE'de TAKIP yok
  // +7 erteleme; takip başlangıcı created_at−20 → toplam 27 ≥ 21 → TEK onay (S-7)
  await page.click('[data-action="devam-secici-sec"][data-secim="ERTALE"]');
  await page.click('#devam-onayla');
  await expect(page.locator('#m-confirm')).toHaveClass(/on/, { timeout: 10000 });
  // ≥21 eşiğinin kanıtı = onayın ÇIKMASI; gün sayısı saat-dilimi yuvarlamasıyla
  // 26/27 arası oynar (created_at UTC/TR sınırı — 2026-10-01 koşum ölçümü)
  await expect(page.locator('#m-confirm-desc')).toContainText(/\d+ gündür takipte, emin misiniz/);
  await page.click('#m-confirm-ok');
  await expect(secici).toHaveCount(0, { timeout: 15000 });
  const gorev = await dbTek('gorev_log', 'id', S.h.gorevId, 'hedef_tarih,hedef_saat,takip_kapanis_nedeni');
  // P12b: hedef = Europe/Istanbul yerel bugün+7 (20261001000001; bkz. T-25 notu)
  expect(gorev?.hedef_tarih).toBe(trGun(7));
  expect(gorev?.hedef_saat).toBeNull();
});

// ═══ 10) T-19 — Sessiz kapanış: takipli hayvana tohumlama → onay YOK, iz kayıtlı ═
test('T-19: takipli hayvana yeni tohumlama → sessiz kapanış (neden=YENI_TOHUMLAMA), listeden düşer', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.e.kupe })).toBeVisible({ timeout: 10000 });
  // REST tohumlama — tetikleyici sessiz kapatır (onay/dialog yok; UI hiçbir akışa girmez)
  const { error } = await db.from('tohumlama').insert({
    hayvan_id: S.e.hayvanId, tarih: trBugun(), sonuc: 'Bekliyor',
    deneme_sayisi: 2, denemeler: [],
  });
  expect(error, error?.message).toBeNull();
  const gorev = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.e.gorevId, 'tamamlandi,takip_kapanis_nedeni');
    return g?.takip_kapanis_nedeni === 'YENI_TOHUMLAMA' ? g : null;
  });
  expect(gorev, 'takip görevi YENI_TOHUMLAMA ile kapanmalı').toBeTruthy();
  await page.evaluate(() => window.goTo && window.goTo('dash'));
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.e.kupe })).toHaveCount(0, { timeout: 10000 });
});

// ═══ 11) T-73 REST guard + T-89 C4 — betikleşmiş DB-SQL katmanları ═══════════
test('T-73/T-89: jenerik gorev_tamamla GEBELIK_KONTROL kapatamaz; kizginlik_vaka_ac TAKIP_ACIK (2 varyant) + onaylı kapanış', async ({ page }) => {
  await openApp(page); // kanıt koşumu UI oturumuyla aynı zeminde; REST çağrıları db client'tan

  // ── T-73: GEBELIK_KONTROL görevi jenerik gorev_tamamla ile SONUÇSUZ KAPANMAZ ──
  const { error: guardErr } = await db.rpc('gorev_tamamla', { p_gorev_id: S.l.gorevId });
  expect(guardErr, 'jenerik tamamlama MUAYENE_SONUC_GEREKLI ile reddedilmeli').toBeTruthy();
  expect(guardErr.message).toContain('MUAYENE_SONUC_GEREKLI');
  const lGorev = await dbTek('gorev_log', 'id', S.l.gorevId, 'tamamlandi');
  expect(lGorev?.tamamlandi).toBe(false);

  // ── T-89 C4 negatif 1: Ovsync tanısı, onaysız → TAKIP_ACIK ──
  const { error: c4a } = await db.rpc('kizginlik_vaka_ac', {
    p_kizginlik_id: S.d.kiz1, p_tani: 'Ovsync', p_takip_onay: false,
  });
  expect(c4a, 'onaysız kizginlik_vaka_ac TAKIP_ACIK ile reddedilmeli').toBeTruthy();
  expect(c4a.message).toContain('TAKIP_ACIK');

  // ── T-89 C4 negatif 2: Ovsync-DIŞI tanı, onaysız → yine TAKIP_ACIK (tanıdan bağımsız) ──
  const { error: c4b } = await db.rpc('kizginlik_vaka_ac', {
    p_kizginlik_id: S.d.kiz2, p_tani: 'Metrit', p_takip_onay: false,
  });
  expect(c4b, 'ovsync-dışı tanıda da onaysız çağrı TAKIP_ACIK ile reddedilmeli').toBeTruthy();
  expect(c4b.message).toContain('TAKIP_ACIK');
  const oncekiCase = (await db.from('cases').select('id').eq('animal_id', S.d.hayvanId)).data?.length ?? 0;

  // ── T-89 C4 onaylı: vaka açılır + takip OVSYNC nedeniyle kapanır ──
  const { error: c4ok } = await db.rpc('kizginlik_vaka_ac', {
    p_kizginlik_id: S.d.kiz1, p_tani: 'Ovsync', p_takip_onay: true,
  });
  expect(c4ok, c4ok?.message).toBeNull();
  const dCase = await dbBekle(async () => {
    const c = await db.from('cases').select('id,status').eq('animal_id', S.d.hayvanId);
    return (c.data?.length ?? 0) > oncekiCase ? c.data[c.data.length - 1] : null;
  });
  expect(dCase, 'onaylı çağrı vaka açmalı').toBeTruthy();
  const dGorev = await dbBekle(async () => {
    const g = await dbTek('gorev_log', 'id', S.d.gorevId, 'takip_kapanis_nedeni');
    return g?.takip_kapanis_nedeni === 'OVSYNC' ? g : null;
  });
  expect(dGorev, 'takip OVSYNC nedeniyle kapanmalı').toBeTruthy();
});

// ═══ 12) T-84/T-85 — Takip muayenesi→Gebe: Boş düzeltme izi, iki satır + göreli gün ═
test('T-84/T-85: takipte Gebe → tohumlama Gebe olur; üreme geçmişinde üstü çizili Boş + Gebe + göreli gün', async ({ page }) => {
  await openApp(page);
  await idbGorevBekle(page, S.i.gorevId);
  await navTo(page, '#nb-tasks');
  await page.evaluate(() => window.loadTasks && window.loadTasks('all'));
  const kart = page.locator(`#tc-${S.i.gorevId}`);
  await expect(kart).toBeVisible({ timeout: 10000 });
  await kart.click();
  const secici = page.locator('#devam-secici-bs');
  await expect(secici).toBeVisible({ timeout: 10000 });
  await page.click('[data-action="devam-secici-sec"][data-secim="GEBE"]');
  await expect(page.locator('#devam-onayla')).toHaveText('Muayene tamam + Gebe işaretle');
  await page.click('#devam-onayla');
  await expect(secici).toHaveCount(0, { timeout: 15000 });
  // sunucu: Boş kayıt Gebe'ye çevrilir + GEBE_ATAMA/bos_duzeltme izi (T-78 yolu)
  const toh = await dbBekle(async () => {
    const t = await dbTek('tohumlama', 'id', S.i.tohId, 'sonuc');
    return t?.sonuc === 'Gebe' ? t : null;
  });
  expect(toh, 'takip muayenesinde Gebe → kayıt Gebe olur').toBeTruthy();
  // UI render: üreme → tohumlama listesi — KALEM 11: üstü çizili Boş + Gebe; KALEM 12: göreli gün
  await page.evaluate(() => window.pullTables && window.pullTables(['tohumlama', 'islem_log']));
  await navTo(page, '#nb-ureme');
  await page.click('#ureme-tab-tohumlama');
  await page.fill('#tohumlama-srch', S.i.kupe);
  const satir = page.locator('#ureme-body .hist-row', { hasText: S.i.kupe }).first();
  await expect(satir).toBeVisible({ timeout: 10000 });
  await expect(satir).toContainText('❌ Boş (');
  await expect(satir.locator('span', { hasText: '❌ Boş (' })).toHaveCSS('text-decoration', /line-through/);
  await expect(satir).toContainText('✅ Gebe');
  await expect(satir).toContainText(/bugün|dün|\d+ gün önce/); // T-85 göreli gün etiketi
});

// ═══ 13) T-03 + T-50 — Boş→Takibe bırak (+7g) + yazma-sonrası invalidate ══════
test('T-03/T-50: TAKIP seçimi görev kurar (+7g) ve __ovsyncTakip cache bozulur; S3 🔍 takipte', async ({ page }) => {
  await openApp(page);
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  await page.waitForFunction(() => window.__ovsyncTakip?.veri, null, { timeout: 20000 });
  await expect(page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.f.kupe })).toHaveCount(0);
  // uygulamanın KENDİ api yolundan yazma (api.js invalidate noktası — T-50 temsilcisi)
  // toh id DB'den okunur (S/seed yarışına değil, DB gerçekine yaslan)
  const fToh = await dbBekle(async () => {
    const t = await db.from('tohumlama').select('id').eq('hayvan_id', S.f.hayvanId);
    return t.data?.[0]?.id ?? null;
  });
  expect(fToh, 'F tohumlama satırı yok').toBeTruthy();
  await page.evaluate(async tohId => {
    await window.tohumlamaBosVeDevam({ p_tohumlama_id: tohId, p_secim: 'TAKIP', p_gun: 7 });
  }, fToh);
  // T-50: yazma sonrası cache null (taze) — bayat satır kalmaz
  await expect.poll(async () =>
    page.evaluate(() => (window.__ovsyncTakip === null || window.__ovsyncTakip === undefined) ? 'taze' : 'bayat'),
  { timeout: 15000 }).toBe('taze');
  // T-03: görev bugün+7 (saat = atama anı) + S3'te 🔍 takipte rozeti
  const gorev = await dbBekle(async () => {
    const g = await db.from('gorev_log').select('id,hedef_tarih,hedef_saat,takip_kapanis_nedeni')
      .eq('hayvan_id', S.f.hayvanId).eq('gorev_tipi', 'TAKIP_MUAYENE').eq('kaynak', 'TAKIP:' + S.f.tohId);
    return g.data?.[0] ?? null;
  });
  expect(gorev, 'TAKIP görevi kurulmalı').toBeTruthy();
  // hedef boundary: sunucu CURRENT_DATE UTC oturumunda — bkz. T-25 notu (HATA #2)
  expect([trGun(6), trGun(7)]).toContain(gorev.hedef_tarih);
  await page.evaluate(() => window.goTo && window.goTo('dash'));
  await page.evaluate(() => window.goTo && window.goTo('ovsync'));
  const fSatir = page.locator('#pg-ovsync .ovs-takip-satir', { hasText: S.f.kupe });
  await expect(fSatir).toBeVisible({ timeout: 10000 });
  await expect(fSatir).toContainText('🔍 takipte');
});
