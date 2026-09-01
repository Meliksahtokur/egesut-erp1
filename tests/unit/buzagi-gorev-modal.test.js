// tests/unit/buzagi-gorev-modal.test.js
// Bölünme fix'i saf fonksiyonları (js/ui.js): detayBtnEtiketi, detayAltTiklanabilir,
// renderTaskDetSubs.
//
// Kapsam DIŞI (bilinçli): toggleSubDet ve grupTamamla — DOM (td-subs/td-tamam-btn)
// + write()/loadTasks()/loadDash()/doneTask() yan etkileri ağırlığında; saf birim
// testle bakılmaz. Kapsamı E2E + kullanıcı canlı doğrulaması (spec §6: canlı
// prod'a test verisi yazma yasağı).
//
// Loader pattern: ui-pure.test.js ile birebir — helpers.js esc()'i DOM'a bağımlı
// olduğundan SAF aynalar enjekte edilir.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { fmtTarih } = require('../../js/utils/helpers.js');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

// Tam modülü BİR KEZ yükle; OZEL_ALT_TIPLER const'u lexical scope'ta kaldığından
// `expose` ile dışarı çıkarılır (loadModule.js başındaki doküman).
const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror, fmtTarih },
  expose: ['OZEL_ALT_TIPLER'],
});
const { detayBtnEtiketi, detayAltTiklanabilir, renderTaskDetSubs } = sandbox;
const { OZEL_ALT_TIPLER } = exposed;

const PARENT = 'parent-abc-123';
// BUZAGI_BAKIM alt görevi; istisnalar opts ile
function sub(id, label, opts = {}) {
  return {
    id,
    parent_id: PARENT,
    gorev_tipi: opts.tip || 'BUZAGI_BAKIM',
    tamamlandi: !!opts.done,
    aciklama: JSON.stringify({ label }),
  };
}

// ═══════════════════════════════════════════════════════════════
// detayBtnEtiketi (js/ui.js — toggleSub komşuluğu)
// ═══════════════════════════════════════════════════════════════
test('detayBtnEtiketi: 0 → mevcut etiket birebir (alt görevsiz görevde K4 regresyon kilidi)', () => {
  assert.strictEqual(detayBtnEtiketi(0), '✅ Tamamlandı Olarak İşaretle');
});

test('detayBtnEtiketi: 6 → grup etiketi', () => {
  assert.strictEqual(detayBtnEtiketi(6), '✅ 6 alt görevle birlikte tamamla');
});

test('detayBtnEtiketi: 1 → tekil sayı doğru yazılır', () => {
  assert.strictEqual(detayBtnEtiketi(1), '✅ 1 alt görevle birlikte tamamla');
});

// ═══════════════════════════════════════════════════════════════
// detayAltTiklanabilir — özel tipler PATCH ile kapatılamaz (RPC bypass koruması)
// ═══════════════════════════════════════════════════════════════
test('detayAltTiklanabilir: OZEL_ALT_TIPLER üyelerinin TAMAMI false', () => {
  assert.ok(OZEL_ALT_TIPLER.length >= 6, 'beklenen en az 6 özel tip');
  for (const tip of OZEL_ALT_TIPLER) {
    assert.strictEqual(detayAltTiklanabilir({ gorev_tipi: tip }), false, tip);
  }
});

test('detayAltTiklanabilir: plain ve eksik tipler true', () => {
  assert.strictEqual(detayAltTiklanabilir({ gorev_tipi: 'BUZAGI_BAKIM' }), true);
  assert.strictEqual(detayAltTiklanabilir({ gorev_tipi: 'DIGER' }), true);
  assert.strictEqual(detayAltTiklanabilir({}), true, 'gorev_tipi yoksa plain varsayılır');
});

// ═══════════════════════════════════════════════════════════════
// renderTaskDetSubs — td-subs içeriği (saf HTML builder)
// ═══════════════════════════════════════════════════════════════
test('renderTaskDetSubs: başlık sayacı + done sınıfı + toggleSubDet id sırası', () => {
  const out = renderTaskDetSubs(
    [sub('d1', 'Kolostrum', { done: true }), sub('d2', 'Göbek kordonu', { done: true })],
    [sub('o1', 'Küpeleme'), sub('o2', 'Maya')],
    PARENT
  );
  assert.ok(out.includes('Alt Görevler (2/4)'), 'başlıkta 2/4 sayacı');
  assert.strictEqual((out.match(/st-check done/g) || []).length, 2, 'yalnız 2 done satırı done sınıflı');
  // done satırlar önce (card pattern ile aynı toggleSubDet sıralı id interpolasyonu)
  const iD1 = out.indexOf(`toggleSubDet('d1','${PARENT}',this)`);
  const iD2 = out.indexOf(`toggleSubDet('d2','${PARENT}',this)`);
  const iO1 = out.indexOf(`toggleSubDet('o1','${PARENT}',this)`);
  const iO2 = out.indexOf(`toggleSubDet('o2','${PARENT}',this)`);
  assert.ok(iD1 !== -1 && iD2 !== -1 && iO1 !== -1 && iO2 !== -1, '4 plain satır da attribute onclickli');
  assert.ok(iD1 < iD2 && iD2 < iO1 && iO1 < iO2, 'sıra: done’lar önce, sonra open’lar');
  assert.ok(out.includes('text-decoration:line-through'), 'done etiketi üstü çizili');
});

test('renderTaskDetSubs: özel tip satır statik — ipucu var, onclick ve pointer yok', () => {
  const out = renderTaskDetSubs(
    [],
    [sub('o1', 'A'), sub('ozel1', 'Özel iş', { tip: 'SUTTEN_KESME' })],
    PARENT
  );
  // Her satır '<div style="display:flex' ile başlar → satır bazında kes
  const segments = out.split('<div style="display:flex').slice(1);
  const special = segments.find(s => s.includes('Özel iş'));
  assert.ok(special, 'özel satır bulundu');
  assert.ok(special.includes('⚙ form ile kapatılır'), 'ipucu metni');
  assert.ok(!special.includes('onclick'), 'özel satır tıklanamaz');
  assert.ok(!special.includes('cursor:pointer'), 'pointer imleci yok');
  const plain = segments.find(s => s.includes(`toggleSubDet('o1'`));
  assert.ok(plain && plain.includes('cursor:pointer'), 'plain satır tıklanabilir kalır');
});

test('renderTaskDetSubs: done OZEL tip de statik kalır (done olsa bile onclick yok)', () => {
  const out = renderTaskDetSubs(
    [sub('sd1', 'Kapanmış özel', { tip: 'BESLEME', done: true })],
    [],
    PARENT
  );
  assert.ok(out.includes('st-check done'), 'görsel done');
  assert.ok(!out.includes('onclick'));
  assert.ok(out.includes('⚙ form ile kapatılır'));
});

test('renderTaskDetSubs: aciklama etiketi esc() ile kaçırılır (raw <script> girmez)', () => {
  const out = renderTaskDetSubs([], [sub('x1', '<script>alert(1)</script>')], PARENT);
  assert.ok(!out.includes('<script'), 'ham script açılışı yok');
  assert.ok(out.includes('&lt;script&gt;alert(1)&lt;/script&gt;'), 'kaçırılmış etiket');
});

test('renderTaskDetSubs: JSON olmayan aciklama → ham metin fallback esc\'li', () => {
  const s = { id: 'f1', parent_id: PARENT, gorev_tipi: 'BUZAGI_BAKIM', tamamlandi: false, aciklama: 'Düz metin <etiket>' };
  const out = renderTaskDetSubs([], [s], PARENT);
  assert.ok(out.includes('Düz metin &lt;etiket&gt;'));
});

test('renderTaskDetSubs: boş girdi → yalnız 0/0 başlığı, satır yok', () => {
  const out = renderTaskDetSubs([], [], PARENT);
  assert.strictEqual(out, '<div style="font-size:.65rem;font-weight:700;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Alt Görevler (0/0)</div>');
});
