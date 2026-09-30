// tests/unit/ovsync-secici.test.js — PLAN P8: devam seçici bileşeni ('bos' + 'muayene')
// (G-20260930-OVSYNC-TAKIP-IMPL, plan.md P8 — plan.md:559-588).
//
// Kapsam:
//  1. Seçenek sabitleri — mockup 01/05 copy BİREBİR (sahip onaylı; paraphrase yasak).
//  2. D3 tablosu: _muayeneSecimleri(gorevTipi) — elle iki ayrı seçenek listesi YAZILMAZ.
//  3. Buton etiketleri (plan.md:581; mockup 01/02/03) — 'muayene' modunda "Boş ata" öneki YOK (S-10).
//  4. Kilit matrisi (dry-run ovsync_kilitli + kilit_gerekce → KISIR/KURAL_GUNU/TABAN_YOK; mockup 02).
//  5. Ön seçim: Ovsync; kilitliyse Takibe bırak'a düşer (TAKIP yoksa PG).
//  6. PG doz zorunluluğu: doz boşsa Kaydet pasif (S3 hizası).
//  7. Ertele: +7 ön ayar, saat VARSAYILAN SAATSIZ (§10d #3), '→ GG.AA [SS:DD]' canlı ön izleme.
//  8. 21 g eşik: "Bu hayvan N gündür takipte, emin misiniz?" (S-7; sunucu TAKIP_UZADI ile aynı formül).
//  9. p_* parametre derlemesi: ERTALE'de saat boşsa p_saat=null; TAKIP'te saat = atama anı (UI girmez).
// 10. Sunucu red tanıma: OVSYNC_SECIM_*, PG_KAPI:* (+birleşik PG_KAPI:TAKIP_ACIK), TAKIP_ACIK,
//     TAKIP_UZADI, TOH_SONUCLU, TAKIP_KAPALI, MUAYENE_SONUC_GEREKLI.
// 11. Kapı koşulları: bayrak_kapalı → seçici AÇILMAZ (#6); offline/dry-run hatası → seçici AÇILMAZ
//     + "İnternet yok" toast'u; bayat veriyle seçim YAPILMAZ.
// 12. Mockup copy birebirlik (render gövde kaynak testleri) + handlers.js data-action kayıtları.
//
// Desen: tests/unit/ovsync-gezinti.test.js (loadBrowserModule + sandbox) ve
// tests/unit/ovsync-api.test.js (rpc stub) kopyası; ağ yok, IDB yok.
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadBrowserModule, extractFunctionSource } = require('./support/loadModule.js');
const helpers = require('../../js/utils/helpers.js');

const REPO = path.join(__dirname, '..', '..');
const UI = 'js/ui.js';
const HANDLERS = 'js/utils/handlers.js';

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

// Gerçek tarih yardımcıları (helpers.js node export'u) — mockup copy formatı bu biçime bağlı.
const GERCEK_TARIH = { fmtTarih: helpers.fmtTarih, dFwd: helpers.dFwd };

// ── Yükleyiciler ──────────────────────────────────────────────────────

// Saf yüzey: const'lar expose ile, fonksiyonlar sandbox'tan.
function loadUiSaf(extraRpcHandlers = {}, extraTohumlamaBosVeDevam) {
  return loadBrowserModule(UI, {
    expose: ['_devamSecenekler', '_muayeneEkstra'],
    extra: {
      esc: escMirror, escAttr: escAttrMirror,
      getData: async () => [], getState: () => [],
      fmtTarih: GERCEK_TARIH.fmtTarih, dFwd: GERCEK_TARIH.dFwd, bugun: helpers.bugun,
      rpc: async () => { throw new Error('rpc stub: bu testte rpc kullanılmaz'); },
      tohumlamaBosVeDevam: extraTohumlamaBosVeDevam || (async () => {
        throw new Error('tohumlamaBosVeDevam stub: beklenmeyen çağrı');
      }),
      toast: () => {}, openConfirm: (t, d, on) => {}, pullTables: async () => {},
      loadDash: () => {}, loadTasks: () => {}, loadOvsyncDash: () => {},
      ...extraRpcHandlers,
    },
  });
}

// UI bir kez (saf fonksiyonlar + const'lar).
const uiYuk = loadUiSaf();
const ui = uiYuk.sandbox;
const sabitler = uiYuk.exposed;

// ── 1. Tanım varlığı ─────────────────────────────────────────────────

test('P8: bileşen fonksiyonları ui.js tanımlı (ac/kapat/render/sec/onayla/girdi/red/params)', () => {
  for (const ad of ['_devamSeciciAc', '_devamSeciciKapat', '_devamSeciciRender',
    '_devamSeciciSec', '_devamSeciciOnayla', '_devamSeciciGirdi',
    '_devamRedIsle', '_devamRpcParams', '_muayeneSecimleri',
    '_devamButonEtiketi', '_devamKilitGerekce', '_devamOnSecim',
    '_erteleOnizleme', '_takip21Onay', '_devamPgdHazirMi', '_devamKisaTarih',
    '_devamSecenekAl']) {
    assert.equal(typeof ui[ad], 'function', `P8: ${ad} ui.js tanımlı değil`);
  }
});

// ── 2. Seçenek sabitleri — mockup 01 copy BİREBİR ────────────────────

test('P8 sabitler: OVSYNC/PG/TAKIP copy mockup 01 birebir', () => {
  assert.deepEqual(sabitler._devamSecenekler.OVSYNC,
    { etiket: '🔄 Ovsync uygula', rozet: 'hemen', alt: 'Ovsync vakası bugün açılır (4 uygulama + TAI)' },
    'OVSYNC copy mockup 01 ile birebir değil');
  assert.deepEqual(sabitler._devamSecenekler.PG,
    { etiket: '💉 PG uygula', rozet: 'hemen', alt: '+48 saat TAI görevi açılır (uygunsa)' },
    'PG copy mockup 01 ile birebir değil');
  assert.deepEqual(sabitler._devamSecenekler.TAKIP,
    { etiket: '🔍 Takibe bırak', alt: 'Bu tarihte rektal muayene görevi açılır. Bu arada kızgınlıkta tohumlanır, PG ya da Ovsync yapılırsa takip kendiliğinden kapanır.' },
    'TAKIP copy mockup 01 ile birebir değil');
});

test('P8 sabitler: muayene ekstra seçenekleri GEBE/ERTALE (mockup 01 çipi + mockup 05)', () => {
  assert.deepEqual(sabitler._muayeneEkstra.GEBE, { etiket: '✅ Gebe' }, 'GEBE copy');
  assert.deepEqual(sabitler._muayeneEkstra.ERTALE, { etiket: '📅 Muayeneyi ertele' }, 'ERTALE copy (mockup 05)');
});

test('P8 _devamSecenekAl: OVSYNC/PG/TAKIP sabitlerden, GEBE/ERTALE ekstradan döner', () => {
  assert.equal(ui._devamSecenekAl('OVSYNC').etiket, '🔄 Ovsync uygula');
  assert.equal(ui._devamSecenekAl('PG').etiket, '💉 PG uygula');
  assert.equal(ui._devamSecenekAl('TAKIP').etiket, '🔍 Takibe bırak');
  assert.equal(ui._devamSecenekAl('GEBE').etiket, '✅ Gebe');
  assert.equal(ui._devamSecenekAl('ERTALE').etiket, '📅 Muayeneyi ertele');
  assert.equal(ui._devamSecenekAl('YOK'), null);
});

// ── 3. D3 tablosu (elle iki ayrı liste YAZILMAZ) ─────────────────────

test('P8 D3: GEBELIK_KONTROL → Gebe/Ovsync/PG/Takibe bırak/Ertele', () => {
  assert.deepEqual(ui._muayeneSecimleri('GEBELIK_KONTROL'), ['GEBE', 'OVSYNC', 'PG', 'TAKIP', 'ERTALE']);
});

test('P8 D3: TAKIP_MUAYENE → TAKIP seçenek YOK (Gebe/Ovsync/PG/Ertele)', () => {
  assert.deepEqual(ui._muayeneSecimleri('TAKIP_MUAYENE'), ['GEBE', 'OVSYNC', 'PG', 'ERTALE']);
  assert.ok(!ui._muayeneSecimleri('TAKIP_MUAYENE').includes('TAKIP'),
    'TAKIP_MUAYENE muayenesinde yeniden takibe bırakma sunucuda TAKIP_YENIDEN_SECILEMEZ — UI seçenek sunmaz');
});

test('P8 D3 tek-kaynak: _muayeneSecimleri gövdesi seçenek copy METNİNİ içermez (copy yalnız sabitte)', () => {
  // D3 ihlali: her görev tipine elle yazılmış ayrı etiket listesi = kopya copy.
  const govde = extractFunctionSource(UI, '_muayeneSecimleri');
  for (const copy of ['Ovsync uygula', 'PG uygula', 'Takibe bırak', 'Muayeneyi ertele']) {
    assert.ok(!govde.includes(copy), `D3 ihlali: _muayeneSecimleri gövdesi copy "${copy}" içeriyor — tablodan türet`);
  }
});

// ── 4. Buton etiketleri (plan.md:581 + mockup 01/02/03) ──────────────

test('P8 buton: bos modu etiketleri mockup 01/02/03 birebir', () => {
  assert.equal(ui._devamButonEtiketi('bos', 'OVSYNC'), 'Boş ata + Ovsync başlat');
  assert.equal(ui._devamButonEtiketi('bos', 'PG'), 'Boş ata + PG uygula');
  assert.equal(ui._devamButonEtiketi('bos', 'TAKIP'), 'Boş ata + Takibe bırak');
});

test('P8 buton: muayene modu etiketleri — "Boş ata" öneki YOK (S-10)', () => {
  assert.equal(ui._devamButonEtiketi('muayene', 'GEBE'), 'Muayene tamam + Gebe işaretle');
  assert.equal(ui._devamButonEtiketi('muayene', 'OVSYNC'), 'Muayene tamam + Ovsync başlat');
  assert.equal(ui._devamButonEtiketi('muayene', 'PG'), 'Muayene tamam + PG uygula');
  assert.equal(ui._devamButonEtiketi('muayene', 'ERTALE', 7), 'Muayeneyi ertele (+7 gün)');
  assert.equal(ui._devamButonEtiketi('muayene', 'ERTALE', 14), 'Muayeneyi ertele (+14 gün)');
  for (const secim of ['GEBE', 'OVSYNC', 'PG', 'ERTALE']) {
    assert.ok(!ui._devamButonEtiketi('muayene', secim).includes('Boş ata'),
      `S-10 ihlali: muayene modu ${secim} etiketinde "Boş ata" öneki var`);
  }
});

// ── 5. Kilit matrisi (mockup 02) ─────────────────────────────────────

test('P8 kilit: KISIR → "🔒 Kısır"', () => {
  assert.deepEqual(ui._devamKilitGerekce({ ovsync_kilitli: true, kilit_gerekce: 'KISIR' }),
    { kilitli: true, gerekce: '🔒 Kısır' });
});

test('P8 kilit: KURAL_GUNU → "🔒 Kural günü GG.AA — N gün var" (mockup 02: 12.10 — 14 gün var)', () => {
  assert.deepEqual(ui._devamKilitGerekce({ ovsync_kilitli: true, kilit_gerekce: 'KURAL_GUNU', kural_tarihi: '2026-10-12', kalan_gun: 14 }),
    { kilitli: true, gerekce: '🔒 Kural günü 12.10 — 14 gün var' });
});

test('P8 kilit: TABAN_YOK → kilitli + açık gerekçe (kural günü hesaplanamadı)', () => {
  const r = ui._devamKilitGerekce({ ovsync_kilitli: true, kilit_gerekce: 'TABAN_YOK' });
  assert.equal(r.kilitli, true);
  assert.ok(r.gerekce.startsWith('🔒'), 'kilit gerekçesi 🔒 ile başlamalı');
  assert.ok(r.gerekce.includes('Kural günü'), 'TABAN_YOK gerekçesi kural günü eksikliğini açıklamalı');
});

test('P8 kilit: kilitli değil → {kilitli:false, gerekce:null}', () => {
  assert.deepEqual(ui._devamKilitGerekce({ ovsync_kilitli: false, kilit_gerekce: null }),
    { kilitli: false, gerekce: null });
});

test('P8 kısa tarih: GG.AA biçimi (mockup copy kısa yıl-sız)', () => {
  assert.equal(ui._devamKisaTarih('2026-10-12'), '12.10');
  assert.equal(ui._devamKisaTarih('2026-09-28'), '28.09');
});

// ── 6. Ön seçim ──────────────────────────────────────────────────────

test('P8 ön seçim: kilitli değil → OVSYNC', () => {
  assert.equal(ui._devamOnSecim({ ovsync_kilitli: false }, ['OVSYNC', 'PG', 'TAKIP']), 'OVSYNC');
});

test('P8 ön seçim: kilitli + bos modu → Takibe bırak (mockup 02)', () => {
  assert.equal(ui._devamOnSecim({ ovsync_kilitli: true }, ['OVSYNC', 'PG', 'TAKIP']), 'TAKIP');
});

test('P8 ön seçim: kilitli + GEBELIK_KONTROL → TAKIP listede varsa TAKIP', () => {
  assert.equal(ui._devamOnSecim({ ovsync_kilitli: true }, ['GEBE', 'OVSYNC', 'PG', 'TAKIP', 'ERTALE']), 'TAKIP');
});

test('P8 ön seçim: kilitli + TAKIP_MUAYENE (TAKIP yok) → PG', () => {
  assert.equal(ui._devamOnSecim({ ovsync_kilitli: true }, ['GEBE', 'OVSYNC', 'PG', 'ERTALE']), 'PG');
});

// ── 7. PG doz zorunluluğu ────────────────────────────────────────────

test('P8 PG doz: doz boşsa pasif (Kaydet engelli), doluysa hazır', () => {
  assert.equal(ui._devamPgdHazirMi('PG', ''), false, 'doz boş → pasif');
  assert.equal(ui._devamPgdHazirMi('PG', null), false, 'doz null → pasif');
  assert.equal(ui._devamPgdHazirMi('PG', '2'), true, 'doz dolu → hazır');
  assert.equal(ui._devamPgdHazirMi('OVSYNC', ''), true, 'doz yalnız PG seçiminde zorunlu');
  assert.equal(ui._devamPgdHazirMi('TAKIP', ''), true);
});

// ── 8. Ertele ön izleme: saat varsayılan SAATSIZ (§10d #3) ──────────

test('P8 ertele ön izleme: saat yoksa yalnız tarih "→ GG.AA"', () => {
  assert.equal(ui._erteleOnizleme('2026-09-30', 7, null), '→ 07.10');
  assert.equal(ui._erteleOnizleme('2026-09-30', 7, ''), '→ 07.10', 'boş string saat = saatsiz');
});

test('P8 ertele ön izleme: saat varsa "→ GG.AA SS:DD" (mockup 05: → 05.10 14:35)', () => {
  assert.equal(ui._erteleOnizleme('2026-09-28', 7, '14:35'), '→ 05.10 14:35');
});

test('P8 ertele: +7 ön ayar — state erteleGun başlangıcı 7 (mockup 05 gün girişi 7)', () => {
  // _devamSeciciAc açılış state'i; DOM koşumu testinde de doğrulanır.
  assert.equal(ui._devamButonEtiketi('muayene', 'ERTALE', 7), 'Muayeneyi ertele (+7 gün)');
});

// ── 9. 21 g eşik (S-7; sunucu TAKIP_UZADI formülü: yeni hedef − ilk kuruluş) ──

test('P8 21g: bos_tarihi verili → toplam = (bugun+gun) − bos_tarihi; ≥21 → onay + mesaj', () => {
  const r = ui._takip21Onay({ bos_tarihi: '2026-09-09' }, {}, 7, '2026-09-30');
  assert.ok(r, '28 gün takip → onay gerekli');
  assert.equal(r.toplam, 28);
  assert.equal(r.mesaj, 'Bu hayvan 28 gündür takipte, emin misiniz?');
});

test('P8 21g: tam 21 → onay (≥ eşik)', () => {
  // başlangıç 2026-09-16 → hedef 2026-10-07 → tam 21 gün
  const r = ui._takip21Onay({ bos_tarihi: '2026-09-16' }, {}, 7, '2026-09-30');
  assert.ok(r, 'tam 21 gün eşikte onay gerekir');
  assert.equal(r.toplam, 21);
});

test('P8 21g: 20 gün → onay YOK (null)', () => {
  assert.equal(ui._takip21Onay({ bos_tarihi: '2026-09-18' }, {}, 7, '2026-09-30'), null);
});

test('P8 21g: bos_tarihi yoksa hedef−varsayılan_gun tahmini (P8 sözleşmesi; P9 görev created_at taşır)', () => {
  // takip_bilgi.hedef_tarih 2026-08-20 → tahmini başlangıç 2026-08-13; bugun 09-30 + 7 = 10-07 → 55 gün
  const r = ui._takip21Onay({}, { takip_bilgi: { hedef_tarih: '2026-08-20' } }, 7, '2026-09-30');
  assert.ok(r);
  assert.equal(r.toplam, 55);
});

test('P8 21g: takip_bilgi yoksa onay YOK (takip zinciri yok)', () => {
  assert.equal(ui._takip21Onay({}, {}, 7, '2026-09-30'), null);
});

// ── 10. p_* parametre derlemesi (P2b imza birebir taşınır) ──────────

test('P8 params: bos+PG — ürün/doz taşınır, p_gun/p_saat null, p_onay false', () => {
  const p = ui._devamRpcParams({
    mod: 'bos', baglam: { tohumlama_id: 't1' }, secim: 'PG',
    pgStokId: 's1', pgDoz: '2', erteleGun: 7, erteleSaat: '', onay21: false,
  });
  assert.deepEqual(p, {
    p_tohumlama_id: 't1', p_muayene_gorev_id: null, p_secim: 'PG',
    p_pg_urun: 's1', p_pg_doz: 2, p_gun: null, p_saat: null, p_notlar: null, p_onay: false,
  });
});

test('P8 params: bos+TAKIP — p_gun=7 (varsayılan), p_saat=null (saat = atama anı, UI girmez)', () => {
  const p = ui._devamRpcParams({
    mod: 'bos', baglam: { tohumlama_id: 't1' }, secim: 'TAKIP',
    pgStokId: null, pgDoz: '', erteleGun: 7, erteleSaat: '', onay21: false,
    onbilgi: { varsayilan_gun: 7 },
  });
  assert.equal(p.p_gun, 7);
  assert.equal(p.p_saat, null);
});

test('P8 params: muayene+ERTALE — saat boş → p_saat=null (varsayılan saatsiz); girilirse taşınır', () => {
  const bos = ui._devamRpcParams({
    mod: 'muayene', baglam: { muayene_gorev_id: 'g1' }, secim: 'ERTALE',
    pgStokId: null, pgDoz: '', erteleGun: 7, erteleSaat: '', onay21: false,
  });
  assert.equal(bos.p_muayene_gorev_id, 'g1');
  assert.equal(bos.p_gun, 7);
  assert.equal(bos.p_saat, null);

  const dolu = ui._devamRpcParams({
    mod: 'muayene', baglam: { muayene_gorev_id: 'g1' }, secim: 'ERTALE',
    pgStokId: null, pgDoz: '', erteleGun: 14, erteleSaat: '14:35', onay21: false,
  });
  assert.equal(dolu.p_gun, 14);
  assert.equal(dolu.p_saat, '14:35');
});

test('P8 params: muayene+GEBE — pg alanları null; onay21 → p_onay=true taşınır', () => {
  const p = ui._devamRpcParams({
    mod: 'muayene', baglam: { muayene_gorev_id: 'g1' }, secim: 'GEBE',
    pgStokId: 's1', pgDoz: '2', erteleGun: 7, erteleSaat: '', onay21: true,
  });
  assert.equal(p.p_secim, 'GEBE');
  assert.equal(p.p_pg_urun, null, 'GEBE seçiminde pg ürün gönderilmez');
  assert.equal(p.p_pg_doz, null);
  assert.equal(p.p_onay, true, 'onay21 → p_onay=true (TAKIP_UZADI tek onay)');
});

// ── 11. Sunucu red tanıma (_devamRedIsle) ────────────────────────────

test('P8 red: OVSYNC_SECIM_* kodları tanınır', () => {
  assert.equal(ui._devamRedIsle('OVSYNC_SECIM_KISIR:{}')?.kod, 'OVSYNC_SECIM_KISIR');
  assert.equal(ui._devamRedIsle('OVSYNC_SECIM_ERKEN:{}')?.kod, 'OVSYNC_SECIM_ERKEN');
});

test('P8 red: PG_KAPI:* tanınır — birleşik PG_KAPI:TAKIP_ACIK AYRI kod (TAKIP_ACIK"a düşmez)', () => {
  assert.equal(ui._devamRedIsle('PG_KAPI:BLOCK_PREGNANT:{}')?.kod, 'PG_KAPI:BLOCK_PREGNANT');
  const birlesik = ui._devamRedIsle('PG_KAPI:TAKIP_ACIK:{"muayene_tarihi":"2026-10-05"}');
  assert.equal(birlesik?.kod, 'PG_KAPI:TAKIP_ACIK', 'birleşik payload kendi koduyla tanınır');
  assert.notEqual(birlesik?.kod, 'PG_KAPI');
});

test('P8 red: TAKIP_ACIK / TAKIP_UZADI / TOH_SONUCLU / TAKIP_KAPALI / MUAYENE_SONUC_GEREKLI', () => {
  assert.equal(ui._devamRedIsle('TAKIP_ACIK:{"muayene_tarihi":"2026-10-05","muayene_saat":"14:35"}')?.kod, 'TAKIP_ACIK');
  assert.equal(ui._devamRedIsle('TAKIP_UZADI:{"toplam_gun":28}')?.kod, 'TAKIP_UZADI');
  assert.equal(ui._devamRedIsle('TOH_SONUCLU:{}')?.kod, 'TOH_SONUCLU');
  assert.equal(ui._devamRedIsle('TAKIP_KAPALI:{}')?.kod, 'TAKIP_KAPALI');
  assert.equal(ui._devamRedIsle('MUAYENE_SONUC_GEREKLI:{}')?.kod, 'MUAYENE_SONUC_GEREKLI');
});

test('P8 red: tanımsız hata → null (normal hata akışına döner)', () => {
  assert.equal(ui._devamRedIsle('fetch failed'), null);
  assert.equal(ui._devamRedIsle(''), null);
});

// ── 12. Kapı koşumları: bayrak-kapalı (#6) / offline / başarılı açılış ──

function bosBaglam() {
  return { tohumlama_id: 'toh-1', kupe_no: '197', grup: 'Sağmal' };
}

test('P8 kapı: bayrak_kapalı → seçici AÇILMAZ + "Ovsync/PG kuralları kapalı" notu', async () => {
  const toastlar = [];
  const yuk = loadUiSaf({ toast: (m) => toastlar.push(m) }, async () => ({
    ok: true, bayrak_kapali: true, ovsync_kilitli: false,
  }));
  const s = yuk.sandbox;
  await s._devamSeciciAc('bos', bosBaglam());
  assert.notEqual(s.window.__devamSecici?.acik, true, 'bayrak kapalıyken seçici açılamaz');
  assert.ok(toastlar.some(m => m.includes('Ovsync/PG kuralları kapalı')),
    'bayrak-kapalı notu toast/uyarı ile verilmeli: ' + JSON.stringify(toastlar));
});

test('P8 kapı: offline / dry-run hatası → seçici AÇILMAZ + "İnternet yok" toast', async () => {
  const toastlar = [];
  const yuk = loadUiSaf({ toast: (m) => toastlar.push(m) }, async () => {
    throw new Error('Failed to fetch');
  });
  const s = yuk.sandbox;
  await s._devamSeciciAc('bos', bosBaglam());
  assert.notEqual(s.window.__devamSecici?.acik, true, 'dry-run hatasında seçici açılamaz (bayat veriyle seçim yok)');
  assert.ok(toastlar.some(m => m.includes('İnternet yok')), '"İnternet yok" toast gerekli: ' + JSON.stringify(toastlar));
});

test('P8 kapı: başarılı dry-run → seçici açık; ön seçim OVSYNC; erteleGun=7; saat saatsiz', async () => {
  const onbilgi = {
    ok: true, bayrak_kapali: false, varsayilan_gun: 7,
    ovsync_kilitli: false, kilit_gerekce: null, kural_tarihi: '2026-10-12', kalan_gun: null,
    son_pg: { stok_id: 's9', urun_adi: 'Estrumate', doz: 2, birim: 'ml' },
    deneme_sayisi: 2, takip_acik: false, takip_bilgi: null,
  };
  const yuk = loadUiSaf({}, async () => onbilgi);
  const s = yuk.sandbox;
  await s._devamSeciciAc('bos', bosBaglam());
  assert.equal(s.window.__devamSecici?.acik, true, 'başarılı dry-run sonrası seçici açık olmalı');
  assert.equal(s.window.__devamSecici?.secim, 'OVSYNC', 'ön seçim Ovsync');
  assert.equal(s.window.__devamSecici?.erteleGun, 7, '+7 ön ayar');
  assert.equal(s.window.__devamSecici?.erteleSaat, '', 'saat varsayılan SAATSIZ (boş)');
  assert.equal(s.window.__devamSecici?.pgStokId, 's9', 'son_pg ön-dolu');
});

test('P8 kapı: kilitli dry-run → ön seçim TAKIP seçeneğine düşer (mockup 02)', async () => {
  const onbilgi = {
    ok: true, bayrak_kapali: false, varsayilan_gun: 7,
    ovsync_kilitli: true, kilit_gerekce: 'KURAL_GUNU', kural_tarihi: '2026-10-12', kalan_gun: 14,
    son_pg: null, deneme_sayisi: 1, takip_acik: false, takip_bilgi: null,
  };
  const yuk = loadUiSaf({}, async () => onbilgi);
  const s = yuk.sandbox;
  await s._devamSeciciAc('bos', bosBaglam());
  assert.equal(s.window.__devamSecici?.secim, 'TAKIP', 'kilitliyken ön seçim Takibe bırak');
  assert.equal(s.window.__devamSecici?.kilit?.gerekce, '🔒 Kural günü 12.10 — 14 gün var');
});

test('P8 kapı: _devamSeciciKapat → acik=false', async () => {
  const onbilgi = { ok: true, bayrak_kapali: false, ovsync_kilitli: false };
  const yuk = loadUiSaf({}, async () => onbilgi);
  const s = yuk.sandbox;
  await s._devamSeciciAc('bos', bosBaglam());
  s._devamSeciciKapat();
  assert.notEqual(s.window.__devamSecici?.acik, true, 'kapatma sonrası acik=false');
});

// ── 13. Mockup copy birebirlik (render gövde kaynak testleri) ────────

test('P8 copy: grup başlığı + dipnot + sonuc çipleri mockup 01 birebir', () => {
  const govde = extractFunctionSource(UI, '_devamSeciciRender');
  assert.ok(govde.includes('Devam nasıl olsun? (zorunlu)'), 'grup başlığı mockup 01 birebir değil');
  assert.ok(govde.includes('Sonuç kaydı ve seçilen devam adımı tek işlemde yapılır'), 'dipnot mockup 01 birebir değil');
  assert.ok(govde.includes('Sonuç Güncelle'), '"Sonuç Güncelle" başlığı yok');
  assert.ok(govde.includes('✅ Gebe') && govde.includes('❌ Boş'), 'bos modu sonuc çipleri ✅ Gebe / ❌ Boş yok');
});

test('P8 copy: PG bölüm etiketi mockup 03 birebir', () => {
  const govde = extractFunctionSource(UI, '_devamSeciciRender');
  assert.ok(govde.includes('Ürün ve doz (son kullanılan, değiştirilebilir)'),
    'PG ürün+doz etiketi mockup 03 birebir değil');
});

test('P8 copy: muayene başlıkları + bilgi kutusu + kızgınlık linki (mockup 05)', () => {
  const govde = extractFunctionSource(UI, '_devamSeciciRender');
  assert.ok(govde.includes('🔬 Takip muayenesi — Küpe'), 'TAKIP_MUAYENE başlık öneki yok');
  assert.ok(govde.includes('🔬 Gebelik kontrolü — Küpe'), 'GEBELIK_KONTROL başlık öneki yok');
  assert.ok(govde.includes('Boş atandı') && govde.includes('gün'), 'TAKIP_MUAYENE bilgi kutusu yok');
  assert.ok(govde.includes('🐄 Kızgınlıkta → tohumlama kaydına geç'), 'kızgınlık link-butonu mockup 05 birebir değil');
});

test('P8 copy: bayrak-kapalı notu + 21g onay mesajı sözleşme metinleri', () => {
  const ac = extractFunctionSource(UI, '_devamSeciciAc');
  assert.ok(ac.includes('Ovsync/PG kuralları kapalı'), 'bayrak-kapalı notu yok');
  assert.ok(ac.includes('İnternet yok'), 'offline toast metni yok');
  const onay = extractFunctionSource(UI, '_takip21Onay');
  assert.ok(onay.includes('gündür takipte, emin misiniz?'), 'S-7 onay mesajı birebir değil');
});

test('P8 copy: _pgKapiHata yeniden kullanımı (PG_KAPI yeni sheet YAZILMAZ — mevcut kapı sarmalı)', () => {
  const onayla = extractFunctionSource(UI, '_devamSeciciOnayla');
  assert.ok(onayla.includes('_pgKapiHata'), 'PG_KAPI red akışı mevcut _pgKapiHata sarmalını kullanmalı');
});

// ── 14. handlers.js data-action kayıtları ────────────────────────────

test('P8 handlers: data-action kayıtları (kapat/sek/onayla + kızgınlık geçişi)', () => {
  const kay = fs.readFileSync(path.join(REPO, HANDLERS), 'utf8');
  for (const ad of ['devam-secici-kapat', 'devam-secici-sec', 'devam-secici-onayla', 'devam-kizginlik-gecis']) {
    assert.ok(kay.includes(`'${ad}'`), `handlers.js: '${ad}' action kaydı yok`);
  }
});

test('P8 handlers: data-input kayıtları (ertele gün/saat + pg doz/ürün)', () => {
  const kay = fs.readFileSync(path.join(REPO, HANDLERS), 'utf8');
  for (const ad of ['devam-girdi', 'devam-urun']) {
    assert.ok(kay.includes(`'${ad}'`), `handlers.js: '${ad}' input/change kaydı yok`);
  }
});

// ── 15. P9 bağlama YOK (drift kapısı — zarf sınırı) ──────────────────

test('P8 sınır: _muayeneSonucAc TANIMI bu teslimde YAZILMAZ (P9 işi; P6 typeof-köprüsü mevcut)', () => {
  const uiKay = fs.readFileSync(path.join(REPO, UI), 'utf8');
  // P6/P7 parçaları P9'a typeof-guard köprüsü yazmış durumda (mevcut davranış, dokunulmaz);
  // P8 yalnız TANIMI yazmamalı (function _muayeneSonucAc(...)).
  assert.ok(!/^\s*(async\s+)?function\s+_muayeneSonucAc\s*\(/m.test(uiKay),
    'P8 _muayeneSonucAc tanımlamamalı (P9 Interfaces)');
  const formsKay = fs.readFileSync(path.join(REPO, 'js/forms.js'), 'utf8');
  assert.ok(!formsKay.includes('_devamSeciciAc'), 'P8 forms.js DOKUNULMAZ (tohSonuc bağlama P9)');
});
