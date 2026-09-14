// tests/unit/geri-al-kopru-yedegi.test.js
// L4-W7 D2 (root R1 düzeltmesi) — köprü-ÖNCE-tarih-sonra kuralı + boş köprü
// satır-yedeği (damga 20260914-12).
//
// Kural (BAĞLAYICI, .ss/tasks/L4-R1-root-duzeltme.md D2):
//   degisim_txid varsa hedef HER ZAMAN köprüden kurulur; tarih kontrolü ve
//   zaman yedeği YALNIZ köprü yoksa. Geriye tarihli giriş çiftlikte olağandır
//   (dünkü tohumlama bugün girilir) — iş tarihi takip başlangıcıyla
//   karşılaştırılarak LOG_YOK üretilmez.
//
// Kök ölçüm (W7): S3b-ENGEL-kilitli.png'deki LOG_YOK'un çözücüdeki "tarih
// karşılaştırması" DEĞİL, BOŞ KÖPÜR'dür — yuruyus_kur.sql l4y-isl-sonuc'u iş
// değişikliğinden AYRI işlemde yazar; degisim_txid o tx'in degisim_log izi
// YOKTUR (islem_log izlenen tablo listesinde değil); 'islem' seviyesi tüm-tx
// araması boş döner → LOG_YOK. Hedef satırın (tohumlama) KENDİ log geçmişi
// sağlamdır. Yedek: dgOnizleGoster TEK tur {tablo,pk} (ZAMANSIZ) dener.
//
// Adversarial üçlü (zarf md.3):
//   T1: iş tarihi takip başlangıcından ÖNCE + degisim_txid DOLU → hedef
//       köprüden (zamansız) + önizleme yedeği OK.
//   T2: degisim_txid NULL + tarih öncesi → zaman yedeği/LOG_YOK MEŞRU
//       (yedek devreye GİRMEZ).
//   T3: DEDUP-birleşik kart (type tohumlama, undo id islem-id, cf335a8 IDB
//       yedeği) → ham islem_log satırı hedefi KÖPRÜYLE kurar.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeElement } = require('./support/loadModule.js');

// İş tarihi takip başlangıcından ÖNCE (izleme migrasyonları 2026-09-13/14'te).
const IS_TARIHI_ONCE = '2026-09-10T10:45:00+03:00';

// ── A. Çözücü (js/gecmis.js _gmGeriAlHedef) — köprü önce ──────────────
const gm = loadBrowserModule('js/gecmis.js', {
  expose: ['_gmGeriAlHedef', '_gmGeriAlBaglam'],
});
const { _gmGeriAlHedef, _gmGeriAlBaglam } = gm.exposed;

test('T1 çözücü — tarih-öncesi + degisim_txid DOLU → hedef KÖPRÜDEN, zamansız', () => {
  const satir = {
    id: 'l4y-isl-sonuc', tip: 'TOHUMLAMA_SONUC', ana_hayvan_id: 'l4y-anne',
    ref_tablo: 'tohumlama', ref_id: 'toh-1',
    tarih: IS_TARIHI_ONCE,            // İŞ tarihi geriye tarihli — olağan
    degisim_txid: '999000111',        // köprü DOLU
    snapshot: {}, payload: {},
  };
  const hedef = _gmGeriAlHedef(satir);
  assert.deepStrictEqual(j(hedef), { tablo: 'tohumlama', pk: 'toh-1', txid: '999000111' },
    'hedef köprüden kurulur');
  assert.ok(!('zaman' in hedef), 'köprülü hedefte zaman YOK — iş tarihi hiç karşılaştırılmaz');
});

test('T1 bağlam — baglam.zaman hedefe MERGE EDİLMEZ (yalnız başlık malzemesi)', () => {
  const satir = {
    id: 'l4y-isl-sonuc', tip: 'TOHUMLAMA_SONUC', ana_hayvan_id: 'l4y-anne',
    ref_tablo: 'tohumlama', ref_id: 'toh-1', tarih: IS_TARIHI_ONCE,
    degisim_txid: '999000111', snapshot: {}, payload: {},
  };
  const baglam = _gmGeriAlBaglam(satir);
  assert.strictEqual(baglam.zaman, IS_TARIHI_ONCE, 'bağlam zamanı başlık için taşınır');
  assert.ok(!('zaman' in _gmGeriAlHedef(satir)), 'ama hedefe sızmaz');
});

test('T2 çözücü — degisim_txid NULL + tarih öncesi → zaman yedeği MEŞRU', () => {
  const satir = {
    id: 'eski-1', tip: 'TOHUMLAMA_SONUC', ana_hayvan_id: 'hv-1',
    ref_tablo: 'tohumlama', ref_id: 'toh-2',
    tarih: IS_TARIHI_ONCE, degisim_txid: null, snapshot: {}, payload: {},
  };
  assert.deepStrictEqual(j(_gmGeriAlHedef(satir)),
    { tablo: 'tohumlama', pk: 'toh-2', zaman: IS_TARIHI_ONCE },
    'köprü yoksa zaman yedeği kurulur (RPC zaman yolu/LOG_YOK meşru)');
});

test('T3 DEDUP-birleşik kart — IDB ham satırı (cf335a8 yedeği) hedefi KÖPRÜYLE kurar', () => {
  // gmUndoClick IDB yedeği: idbGetAll('islem_log') satırı — DEDUP yüzünden
  // _gmIslemLogById haritasında olmayan TOHUMLAMA aynası; undo id = islem-id.
  const idbSatiri = {
    id: 'l4y-isl-toh', tip: 'TOHUMLAMA', ana_hayvan_id: 'l4y-anne',
    ref_tablo: 'tohumlama', ref_id: 'toh-1',
    tarih: '2026-09-12T10:35:00+03:00', created_at: '2026-09-14T09:00:00+03:00',
    degisim_txid: '888777666', durum: null,
    snapshot: { kupe: 'L4Y-01' }, payload: { istemci_etiketi: 'l4-yuruyus' },
  };
  assert.deepStrictEqual(j(_gmGeriAlHedef(idbSatiri)),
    { tablo: 'tohumlama', pk: 'toh-1', txid: '888777666' });
});

// ── B. _dgKopruSatirYedegi (js/degisiklikler/degisiklikler.js) ────────
const dgYukle = (rpcStub) => {
  const m = loadBrowserModule('js/degisiklikler/degisiklikler.js', {
    extra: Object.assign({
      registerActions: () => {},
      tabloEtiketi: t => t, islemEtiketi: t => t, alanEtiketi: (t, a) => a,
      pkKisa: p => String(p).slice(0, 8), fmtTarihSaat: () => '12.09 10:45',
      esc: s => String(s), escAttr: s => String(s),
      _gmIslemBaslikSatiri: b => (b && b.olayEtiketi) || 'İşlem',
      openM: () => {}, closeM: () => {}, toast: () => {},
      rpcDegisimOnizle: rpcStub || (async () => ({ geri_alinabilir: true, plan: [] })),
    }),
    expose: ['_dg', 'dgGeriAlAkisi', 'dgOnizleGoster', '_dgKopruSatirYedegi'],
  });
  // önizleme modalının elemanları
  ['dg-onizle-govde', 'dg-onizle-baslik', 'dg-onizle-onay', 'dg-onizle-engel', 'dg-gerekce']
    .forEach(id => m.document.__setEl(id, makeElement('div')));
  return m;
};

// vm-realm prototip çakışması: vm'de üretilen nesneyi test realm'ına yuvarla
const j = o => JSON.parse(JSON.stringify(o));

const LOG_YOK_HATASI = () => {
  const e = new Error('Hedef bulunamadı');
  e.data = { ok: false, hata: 'HEDEF_BULUNAMADI', detay: { neden: 'LOG_YOK' } };
  return e;
};

const KOPRU_HEDEFI = { tablo: 'tohumlama', pk: 'toh-1', txid: '999000111' };

test('T1 yedek — köprü hedefi + LOG_YOK → {tablo,pk}; anahtar kümesi TAM o (zamansız)', () => {
  const { exposed } = dgYukle();
  assert.deepStrictEqual(j(exposed._dgKopruSatirYedegi(KOPRU_HEDEFI, LOG_YOK_HATASI())),
    { tablo: 'tohumlama', pk: 'toh-1' });
});

test('yedek yalnız LOG_YOK\'ta — başka kod/neden yedek ÜRETMEZ', () => {
  const { exposed } = dgYukle();
  const yedekFn = exposed._dgKopruSatirYedegi;
  const hata = (kod, neden) => {
    const e = new Error(kod);
    e.data = { ok: false, hata: kod, detay: neden ? { neden } : undefined };
    return e;
  };
  assert.strictEqual(yedekFn(KOPRU_HEDEFI, hata('CAKISMA')), null, 'başka kod → null');
  assert.strictEqual(yedekFn(KOPRU_HEDEFI, hata('HEDEF_BULUNAMADI', 'SATIR_YOK')), null);
  assert.strictEqual(yedekFn(KOPRU_HEDEFI, hata('HEDEF_BULUNAMADI', 'ZAMAN_ESLESME_YOK')), null);
  assert.strictEqual(yedekFn(KOPRU_HEDEFI, hata('HEDEF_BULUNAMADI')), null, 'nedissiz → null');
});

test('T2 meşru LOG_YOK korunur — köprüsüz {tablo,pk,zaman} hedefine yedek YOK', () => {
  const { exposed } = dgYukle();
  assert.strictEqual(
    exposed._dgKopruSatirYedegi({ tablo: 'tohumlama', pk: 'toh-2', zaman: IS_TARIHI_ONCE }, LOG_YOK_HATASI()),
    null,
    'zaman yedeği yalnız köprüsüz yoldadır; LOG_YOK o yolda meşrudur');
});

test('{txid} hedefi (GERI_ALINDI) satırsızdır → yedek YOK', () => {
  const { exposed } = dgYukle();
  assert.strictEqual(exposed._dgKopruSatirYedegi({ txid: '999000111' }, LOG_YOK_HATASI()), null);
});

test('alan-seviyesi hedef (txid+alan) satır-yedeğine İNMEZ (review minör-2)', () => {
  const { exposed } = dgYukle();
  assert.strictEqual(exposed._dgKopruSatirYedegi(
    { tablo: 'tohumlama', pk: 'toh-1', alan: 'sonuc', txid: '999000111' }, LOG_YOK_HATASI()),
    null, 'alan yedeği semantiği değiştirmez — hata aynen gösterilir');
});

test('bozuk girişler güvenli — null hedef/hata, boş pk', () => {
  const { exposed } = dgYukle();
  const yedekFn = exposed._dgKopruSatirYedegi;
  assert.strictEqual(yedekFn(null, LOG_YOK_HATASI()), null);
  assert.strictEqual(yedekFn(KOPRU_HEDEFI, null), null);
  assert.strictEqual(yedekFn({ tablo: 'tohumlama', pk: '', txid: '1' }, LOG_YOK_HATASI()), null);
});

// ── C. Akış — dgOnizleGoster TEK tur yedek (rpcDegisimOnizle stub'lı) ──
test('T1 akış — 1. çağrı KÖPRÜ (islem), LOG_YOK\'ta 2. çağrı {tablo,pk} (satir); TEK tur', async () => {
  const cagri = [];
  let deneme = 0;
  const m = dgYukle(async (hedef, seviye) => {
    cagri.push({ hedef: Object.assign({}, hedef), seviye });
    deneme++;
    if (deneme === 1) throw LOG_YOK_HATASI();
    return { geri_alinabilir: true, plan: [], cakismalar: [], sirali_rehber: [] };
  });
  await m.exposed.dgGeriAlAkisi(KOPRU_HEDEFI, 'islem',
    { olayEtiketi: 'Tohumlama Sonucu', zaman: IS_TARIHI_ONCE, kim: 'L4Y-01' });
  assert.strictEqual(cagri.length, 2, 'tam iki deneme: köprü + satır-yedeği');
  assert.deepStrictEqual(cagri[0], { hedef: KOPRU_HEDEFI, seviye: 'islem' },
    'ilk hedef HER ZAMAN köprüden');
  assert.deepStrictEqual(cagri[1], { hedef: { tablo: 'tohumlama', pk: 'toh-1' }, seviye: 'satir' },
    'yedek zamansız {tablo,pk} — tarih kontrolü/zaman yedeği devreye girmez');
  assert.strictEqual(m.exposed._dg.bekleyen.hedef.tablo, 'tohumlama',
    'uygulama aynı yedek hedefle yapılır');
  assert.strictEqual(m.exposed._dg.bekleyen.seviye, 'satir');
});

test('T2 akış — köprüsüz hedef + LOG_YOK → TEK çağrı, insan dilli LOG_YOK kalır', async () => {
  const cagri = [];
  const m = dgYukle(async (hedef, seviye) => {
    cagri.push({ hedef: Object.assign({}, hedef), seviye });
    throw LOG_YOK_HATASI();
  });
  await m.exposed.dgGeriAlAkisi({ tablo: 'tohumlama', pk: 'toh-2', zaman: IS_TARIHI_ONCE }, 'satir',
    { olayEtiketi: 'Tohumlama Sonucu', zaman: IS_TARIHI_ONCE, kim: 'L4Y-01' });
  assert.strictEqual(cagri.length, 1, 'köprüsüz yolda yedek YOK — meşru LOG_YOK');
  const govde = m.document.getElementById('dg-onizle-govde').innerHTML;
  assert.ok(govde.includes('değişiklik takibi kurulmadan önce'),
    'insan dilli yönlendirme metni aynen kalır');
});

test('sağlam köprü davranışı DEĞİŞMEDİ — LOG_YOK yoksa yedek tetiklenmez', async () => {
  const cagri = [];
  const m = dgYukle(async (hedef, seviye) => {
    cagri.push({ hedef: Object.assign({}, hedef), seviye });
    return { geri_alinabilir: true, plan: [], cakismalar: [], sirali_rehber: [] };
  });
  await m.exposed.dgGeriAlAkisi(KOPRU_HEDEFI, 'islem',
    { olayEtiketi: 'Tohumlama', zaman: '', kim: 'L4Y-01' });
  assert.strictEqual(cagri.length, 1);
  assert.deepStrictEqual(cagri[0].hedef, KOPRU_HEDEFI, 'tek çağrı — köprü hedefi aynen');
});

test('yedek turu TEK — yedek hedef de LOG_YOK verirse üçüncü çağrı YOK', async () => {
  const cagri = [];
  const m = dgYukle(async (hedef, seviye) => {
    cagri.push({ hedef: Object.assign({}, hedef), seviye });
    throw LOG_YOK_HATASI();
  });
  await m.exposed.dgGeriAlAkisi(KOPRU_HEDEFI, 'islem',
    { olayEtiketi: 'Tohumlama Sonucu', zaman: '', kim: 'L4Y-01' });
  assert.strictEqual(cagri.length, 2, 'txid\'siz yedek yeniden yedeklenmez — çıkılmaz yok');
  const govde = m.document.getElementById('dg-onizle-govde').innerHTML;
  assert.ok(govde.includes('Önizleme alınamadı'), 'son hata kullanıcının gözünde');
});
