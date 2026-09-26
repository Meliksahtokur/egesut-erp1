// tests/unit/nav-geri-karar.test.js
// js/utils/handlers.js — W3 (hapsolmama) geri tuşu karar makinesi.
//
// Kilitlenen sözleşmeler (zarf L4-W3 md.A.2/A.7; goal frozen contract "Gezinme"):
//   1. navGeriKarar: her popstate'te EN ÜSTTEKİ tek katman kapanır; mevcut dal
//      sırası korunur (modal → sessiz → sentinel → proto-detay → kart-içi gün
//      görünümü → kart det → state-guard → ana gün → tx detayı → sayfa nav).
//   2. navViewBack: normal kapanış (✕ Kapat, ‹ Listeye dön) history'de görünüm
//      entry'si bırakmaz — gun/dtx/dgun state'i varsa guard'lı back.
//   3. det-back deseni (go-back → det dalı) REGRESYONLA korunur: kart açık,
//      kart-içi gün görünümü kapalıyken karar 'det'tir — kart kapanır.
//   4. navGeriDon: history'de geri varsa back; boşsa Log nav'ına düşer.
//
// RED-BEFORE: navGeriKarar/navViewBack sandbox'ta yokken tüm testler kırmızıdır
// (kanıt: bu dosyanın impl-öncesi koşumu — W3 teslim raporu).

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub } = require('./support/loadModule.js');

function loadHandlers() {
  const calls = { backs: 0, goTo: [] };
  const history = {
    state: null,
    length: 5,
    pushState(s) { this.state = s; },
    replaceState(s) { this.state = s; },
    back() { this.state = null; this.length = Math.max(1, this.length - 1); calls.backs++; },
    go() {},
  };
  const doc = makeDomStub();
  const m_actions = {};
  const m = loadBrowserModule('js/utils/handlers.js', {
    dom: doc,
    extra: {
      history,
      registerActions: (obj) => { Object.assign(m_actions, obj); },
    },
  });
  return { api: m.sandbox, actions: m_actions, history, calls };
}

// ── §1: katman önceliği — mevcut sıra korunur ──────────────────────

test('navGeriKarar: modalBackGuard → yut (kod kaynaklı back tüketilir)', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ modalBackGuard: true, modalStack: ['m-x'] });
  assert.strictEqual(k.tur, 'yut');
});

test('navGeriKarar: açık sessiz sheet → sessiz (modal stack önceliğini alır)', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ sessizAcik: true, modalStack: ['m-x'] });
  assert.strictEqual(k.tur, 'sessiz');
});

test('navGeriKarar: modal stack en üsttekini verir (takvim dahil)', () => {
  const { api } = loadHandlers();
  const k1 = api.navGeriKarar({ modalStack: [] });
  assert.strictEqual(k1.tur, 'sayfa');
  const k2 = api.navGeriKarar({ modalStack: ['tek-tarih-takvim'] });
  assert.strictEqual(k2.tur, 'modal');
  assert.strictEqual(k2.id, 'tek-tarih-takvim');
  const k3 = api.navGeriKarar({ modalStack: ['m-animal', 'tek-tarih-takvim'] });
  assert.strictEqual(k3.id, 'tek-tarih-takvim', 'en üstte açılan kapanır');
});

test('navGeriKarar: sentinel state → sentinel (dip onayı)', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ sentinel: true, state: { sentinel: true } });
  assert.strictEqual(k.tur, 'sentinel');
});

test('navGeriKarar: proto-detay sheet → proto-detay', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ protoDetayAcik: true });
  assert.strictEqual(k.tur, 'proto-detay');
});

// ── §3: det-back regresyonu (W3 öncesi davranış aynen) ──────────────

test('navGeriKarar: kart açık, kart-içi gün kapalı → det (det-back deseni korunur)', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ detAcik: true, detGunAcik: false, state: { pg: 'suru' } });
  assert.strictEqual(k.tur, 'det');
});

test('navGeriKarar: kart + kart-içi gün görünümü açık → önce gün kapanır', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ detAcik: true, detGunAcik: true, state: { pg: 'suru', det: 'h1', dgun: '2026-09-01' } });
  assert.strictEqual(k.tur, 'det-gun');
});

// ── §1: state-guard — modal/sheet state'i sayfa taşımaz (B21) ───────

test('navGeriKarar: state.protokol/proto_detay/modal + görünüm kapalı → yut', () => {
  const { api } = loadHandlers();
  assert.strictEqual(api.navGeriKarar({ state: { modal: 'm-stk' } }).tur, 'yut');
  assert.strictEqual(api.navGeriKarar({ state: { protokol: 1 } }).tur, 'yut');
  assert.strictEqual(api.navGeriKarar({ state: { proto_detay: 1 } }).tur, 'yut');
});

// ── §1: W3 yeni katmanları — det dalından SONRA, sayfa nav'dan ÖNCE ──

test('navGeriKarar: ana gün görünümü açık → gun (kart kapalıyken)', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ gecmisGunAcik: true, state: { pg: 'gecmis', gun: '2026-09-12' } });
  assert.strictEqual(k.tur, 'gun');
});

test('navGeriKarar: tx detayı açık → tx-detay; ikisi kapalı → sayfa nav', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ txDetayAcik: true, state: { pg: 'degisiklikler', dtx: '42' } });
  assert.strictEqual(k.tur, 'tx-detay');
  // Not: vm realm objesi — alan bazlı doğrulama (deepStrictEqual prototype atar)
  const k2 = api.navGeriKarar({ state: { pg: 'log' } });
  assert.strictEqual(k2.tur, 'sayfa');
  assert.strictEqual(k2.pg, 'log');
  const k3 = api.navGeriKarar({});
  assert.strictEqual(k3.tur, 'sayfa');
  assert.strictEqual(k3.pg, 'dash', 'state yok → dash (mevcut davranış)');
});

test('navGeriKarar: kart açıkken sayfa-içi gün dalı ÇALIŞMAZ (overlay üstte)', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ detAcik: true, detGunAcik: false, gecmisGunAcik: true, state: { pg: 'gecmis' } });
  assert.strictEqual(k.tur, 'det', 'önce kart kapanır; ana gün bir sonraki geri');
});

// ── §2: navViewBack — görünümlerin normal kapanışı history temizler ──

test('navViewBack: gun/dtx/dgun state varsa guard+back; yoksa dokunmaz', () => {
  const { api, history, calls } = loadHandlers();
  history.state = { pg: 'gecmis', gun: '2026-09-12' };
  api.navViewBack();
  assert.strictEqual(calls.backs, 1, 'gün entry back edildi');
  history.state = { pg: 'degisiklikler', dtx: '42' };
  api.navViewBack();
  assert.strictEqual(calls.backs, 2, 'tx entry back edildi');
  history.state = { pg: 'suru', dgun: '2026-09-01' };
  api.navViewBack();
  assert.strictEqual(calls.backs, 3, 'kart-içi gün entry back edildi');
  history.state = { pg: 'gecmis' };
  api.navViewBack();
  assert.strictEqual(calls.backs, 3, 'görünüm state yok — back ÇAĞRILMAZ');
});

// ── §4: navGeriDon — başlıktaki ← Geri ──────────────────────────────

test('navGeriDon: history > 1 → back; history 1 → Log nav', () => {
  const { api, calls } = loadHandlers();
  api.navGeriDon();
  assert.strictEqual(calls.backs, 1);
  // history.length 1 → goTo('log') fallback'ı
  const m2 = loadHandlers();
  m2.history.length = 1;
  m2.api.goTo = (pg, push) => m2.calls.goTo.push([pg, push]);
  m2.api.navGeriDon();
  assert.deepStrictEqual(m2.calls.goTo[0], ['log', undefined], 'boş history → Log sayfasına');
});

// ── action bağlantıları (registerActions) ────────────────────────────

test('actions: gecmis-gun-kapat/gecmis-det-gun-kapat/nav-geri kayıtlı', () => {
  const { actions } = loadHandlers();
  assert.strictEqual(typeof actions['gecmis-gun-kapat'], 'function');
  assert.strictEqual(typeof actions['gecmis-det-gun-kapat'], 'function');
  assert.strictEqual(typeof actions['nav-geri'], 'function');
  assert.strictEqual(typeof actions['go-back'], 'function');
});

// ── S4/M2: ovsync-yardim vakası (proto-detay'dan sonra; DOM remove-edilir) ──

test('navGeriKarar: açık ovsync yardım sheet → ovsync-yardim', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ ovsyncYardimAcik: true });
  assert.strictEqual(k.tur, 'ovsync-yardim');
});

test('navGeriKarar: {ovsync_yardim} state (DOM yok) → yut (sayfa taşınmaz)', () => {
  const { api } = loadHandlers();
  const k = api.navGeriKarar({ state: { ovsync_yardim: true } });
  assert.strictEqual(k.tur, 'yut');
});
