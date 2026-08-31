// tests/unit/forms-validation.test.js
// js/forms.js doğrulama/yardımcı fonksiyonlarının birim testleri.
// Kapsam: _kupeKontrolEt, _sutIcenBuzagilar, renderBuzagiPicker,
// vaccinePickerSearch, selectedVaccineRows, _vaccineNaive,
// ekUygulamaEkle / ekUygulama_sil / _ekListeGoster.
// Tüm db/rpc erişimi stub üzerinden — gerçek Supabase çağrısı YOK.
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const {
  loadBrowserModule,
  makeDbStub,
  makeDomStub,
  makeElement,
} = require('./support/loadModule.js');
const { getDisplayKupe } = require('../../js/utils/helpers.js');

// ── Sorgulanabilir DOM ────────────────────────────────────────────────
// Loader'ın document stub'ı querySelectorAll'u hep [] döner. forms.js'in
// test edilen fonksiyonları ('#v-list .vp-item', '.v-chk:checked',
// '.ek-chip' gibi) selector sorgularına gerçek eleman döndürmek için
// kayıt defteri (registry) tabanlı minimal selector motoru.
function matchesCompound(el, compound) {
  const tokenRe = /#([\w-]+)|\.([\w-]+)|([a-zA-Z][\w-]*)|\[([^\]=\s]+)=([^\]]+)\]|:([a-zA-Z-]+)/g;
  let m;
  while ((m = tokenRe.exec(compound))) {
    if (m[1] !== undefined) {
      if (el.id !== m[1]) return false;
    } else if (m[2] !== undefined) {
      const has = (el.classList && typeof el.classList.contains === 'function' && el.classList.contains(m[2])) ||
        String(el.className || '').split(/\s+/).includes(m[2]);
      if (!has) return false;
    } else if (m[3] !== undefined) {
      if (el.tagName !== m[3].toUpperCase()) return false;
    } else if (m[4] !== undefined) {
      // [type=checkbox] → eleman özelliği üzerinden (fixture'larda type atanır)
      if (String(el[m[4]]) !== String(m[5])) return false;
    } else if (m[6] !== undefined) {
      if (m[6] === 'checked') { if (el.checked !== true) return false; }
      else return false;
    }
  }
  return true;
}

function matchesSelector(el, selector) {
  const compounds = String(selector).trim().split(/\s+/).filter(Boolean);
  if (!compounds.length) return false;
  if (!matchesCompound(el, compounds[compounds.length - 1])) return false;
  let node = el.parentNode;
  for (let i = compounds.length - 2; i >= 0; i--) {
    while (node && !matchesCompound(node, compounds[i])) node = node.parentNode;
    if (!node) return false;
    node = node.parentNode;
  }
  return true;
}

function makeQueryableDom() {
  const base = makeDomStub();
  const registry = [];
  const doc = Object.create(base);
  doc.__reg = (el) => { if (!registry.includes(el)) registry.push(el); return el; };
  doc.__setEl = (id, el) => { base.__setEl(id, el); doc.__reg(el); return el; };
  doc.querySelectorAll = (sel) => registry.filter(el => matchesSelector(el, sel));
  doc.querySelector = (sel) => doc.querySelectorAll(sel)[0] || null;
  return doc;
}

// js/ui.js:70-79 yasHesapla'nın birebir aynası — forms.js'e global stub olarak verilir
function yasHesaplaMirror(dogumTarihi) {
  if (!dogumTarihi) return '';
  const d = new Date(dogumTarihi), now = new Date();
  let y = now.getFullYear() - d.getFullYear(), m = now.getMonth() - d.getMonth(), gn = now.getDate() - d.getDate();
  if (gn < 0) { m--; gn += new Date(now.getFullYear(), now.getMonth(), 0).getDate(); }
  if (m < 0) { y--; m += 12; }
  if (y > 0) return `${y} yıl ${m} ay`;
  if (m > 0) return `${m} ay ${gn} gün`;
  return `${gn} gün`;
}

// ── forms.js yükleme fabrikası ────────────────────────────────────────
// Her çağrı taze vm context'i yükler → modül durumu (_ekUygulamalar vb.)
// test grupları arasında sızamaz.
function setupForms(opts = {}) {
  const document = opts.dom || makeQueryableDom();
  const calls = { db: [], rpc: [], toast: [] };
  const stateBag = Object.assign({}, opts.state);

  // js/utils/helpers.js:4-6 aynası — sandbox'a bare global olarak verilir
  const g = (id) => document.getElementById(id);
  const v = (id) => { const el = g(id); return (el && el.value) || ''; };
  const cl = (id) => { const el = g(id); if (el) el.value = ''; };
  // helpers.js esc() aynası (innerHTML kaçışlama: & < >)
  const esc = (s) => String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

  const dbResult = opts.dbResult !== undefined ? opts.dbResult : { data: { musait: true }, error: null };
  const db = opts.db || makeDbStub({
    kupe_musait_mi: async (params) => {
      calls.db.push({ name: 'kupe_musait_mi', params });
      return dbResult;
    },
  });

  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: Object.assign({
      db,
      g, v, cl, esc,
      getState: (k) => stateBag[k],
      setState: (k, val) => { stateBag[k] = val; },
      toast: (msg, err) => { calls.toast.push({ msg, err: !!err }); },
      rpc: async (name, params) => { calls.rpc.push({ name, params }); return {}; },
      getDisplayKupe,
      yasHesapla: yasHesaplaMirror,
      idbGetAll: async () => [],
      getData: async () => [],
    }, opts.extra),
  });
  return { sandbox, document, calls, stateBag };
}

// n gün önceki ISO tarih — _sutIcenBuzagilar'ın gün matematiğiyle birebir uyumlu
const gunOnce = (n) => new Date(Date.now() - n * 86400000).toISOString();

// vm context'i içinde yaratılan nesne/dizileri host realm'ine çevir.
// assert.deepStrictEqual prototipleri de karşılaştırdığı için cross-realm
// nesneler içerikleri aynı olsa bile fail eder.
const host = (x) => JSON.parse(JSON.stringify(x));

// ══════════════════════════════════════════════════════════════════════
// _kupeKontrolEt — küpe çakışma blur kontrolü (forms.js:26)
// ══════════════════════════════════════════════════════════════════════
describe('_kupeKontrolEt (küpe çakışma blur kontrolü)', () => {
  function kupeSetup({ alan = 'a-kupe', deger = 'TR-123', editId, dbResult, db } = {}) {
    const ctx = setupForms({ dbResult, db });
    ctx.document.__setEl(alan, Object.assign(makeElement('input'), { value: deger }));
    const warn = ctx.document.__setEl(alan + '-warn', makeElement('div'));
    warn.textContent = ''; // test içinde kirletilirse başlangıç değeri bilinir
    if (editId !== undefined) {
      const modal = ctx.document.__setEl('m-animal', makeElement('div'));
      modal.dataset.editId = editId;
    }
    ctx.warn = warn;
    ctx.alan = alan;
    return ctx;
  }

  it('boş veya boşluk-dolu girdi → uyarı temizlenir, db hiç çağrılmaz', async () => {
    for (const bos of ['', '   ']) {
      const ctx = kupeSetup({ deger: bos });
      ctx.warn.textContent = '⚠️ Bu küpe zaten kayıtlı'; // kirli başlangıç
      await ctx.sandbox._kupeKontrolEt(ctx.alan);
      assert.strictEqual(ctx.warn.textContent, '');
      assert.strictEqual(ctx.calls.db.length, 0, 'db.rpc çağrılmamalı');
    }
  });

  it('uyarı elementi yoksa erken döner — hata fırlamaz, db çağrılmaz', async () => {
    const ctx = setupForms();
    ctx.document.__setEl('a-kupe', Object.assign(makeElement('input'), { value: 'TR-123' }));
    // 'a-kupe-warn' bilerek YOK
    await assert.doesNotReject(() => ctx.sandbox._kupeKontrolEt('a-kupe'));
    assert.strictEqual(ctx.calls.db.length, 0);
  });

  it('db musait:false dönerse → "⚠️ Bu küpe zaten kayıtlı" uyarısı yazılır', async () => {
    const ctx = kupeSetup({ dbResult: { data: { musait: false }, error: null } });
    await ctx.sandbox._kupeKontrolEt(ctx.alan);
    assert.strictEqual(ctx.warn.textContent, '⚠️ Bu küpe zaten kayıtlı');
    assert.strictEqual(ctx.calls.db.length, 1);
    assert.strictEqual(ctx.calls.db[0].name, 'kupe_musait_mi');
  });

  it('db musait:true dönerse → uyarı temizlenir', async () => {
    const ctx = kupeSetup({ dbResult: { data: { musait: true }, error: null } });
    ctx.warn.textContent = '⚠️ Bu küpe zaten kayıtlı';
    await ctx.sandbox._kupeKontrolEt(ctx.alan);
    assert.strictEqual(ctx.warn.textContent, '');
  });

  it('alan="a-kupe" → değer kırpılarak p_kupe_no alanına gider, p_devlet_kupe null kalır', async () => {
    const ctx = kupeSetup({ alan: 'a-kupe', deger: '  TR-123  ' });
    await ctx.sandbox._kupeKontrolEt('a-kupe');
    assert.deepStrictEqual(host(ctx.calls.db[0].params), {
      p_kupe_no: 'TR-123',
      p_devlet_kupe: null,
    });
  });

  it('alan="a-devlet" → değer p_devlet_kupe alanına gider, p_kupe_no null kalır', async () => {
    const ctx = kupeSetup({ alan: 'a-devlet', deger: 'TR-999' });
    await ctx.sandbox._kupeKontrolEt('a-devlet');
    assert.deepStrictEqual(host(ctx.calls.db[0].params), {
      p_kupe_no: null,
      p_devlet_kupe: 'TR-999',
    });
  });

  it('düzenleme modu (m-animal.dataset.editId) → p_hayvan_id RPC parametresine iletilir', async () => {
    const ctx = kupeSetup({ editId: 'H-42' });
    await ctx.sandbox._kupeKontrolEt(ctx.alan);
    assert.deepStrictEqual(host(ctx.calls.db[0].params), {
      p_kupe_no: 'TR-123',
      p_devlet_kupe: null,
      p_hayvan_id: 'H-42',
    });
  });

  it('düzenleme modu değilken p_hayvan_id anahtarı hiç gönderilmez', async () => {
    const ctx = kupeSetup(); // m-animal yok
    await ctx.sandbox._kupeKontrolEt(ctx.alan);
    assert.strictEqual('p_hayvan_id' in ctx.calls.db[0].params, false);
  });

  it('db.rpc hata fırlatırsa → reject olmaz, ÖNCEKİ uyarı korunur (fail-aware, WP-9)', async () => {
    // DÜZELTİLDİ: eskiden catch uyarıyı temizleyip sessizce 'müsait' sayıyordu
    // (fail-open). Artık önceki gerçek uyarı korunur.
    const ctx = kupeSetup({
      db: { rpc: async () => { throw new Error('db erişilemez'); } },
    });
    ctx.warn.textContent = '⚠️ Bu küpe zaten kayıtlı';
    await assert.doesNotReject(() => ctx.sandbox._kupeKontrolEt(ctx.alan));
    assert.strictEqual(ctx.warn.textContent, '⚠️ Bu küpe zaten kayıtlı');
  });

  it('db.rpc hatası + uyarı boşsa → soft not düşer, dataset.soft=1 (submit engellemez)', async () => {
    const ctx = kupeSetup({
      db: { rpc: async () => { throw new Error('db erişilemez'); } },
    });
    await assert.doesNotReject(() => ctx.sandbox._kupeKontrolEt(ctx.alan));
    assert.match(ctx.warn.textContent, /Küpe kontrolü yapılamadı/);
    assert.strictEqual(ctx.warn.dataset.soft, '1');
  });

  it('res.data null (db hata nesnesi) → uyarı temizlenir — hata "müsait" sayılır', async () => {
    // ŞÜPHELİ DAVRANIŞ: db hatası sessizce "küpe müsait" gibi işlenir;
    // çakışma kontrolü başarısız olduğunda form yanlışlıkla onaylanmış olur.
    const ctx = kupeSetup({ dbResult: { data: null, error: { message: 'bağlantı hatası' } } });
    ctx.warn.textContent = '⚠️ Bu küpe zaten kayıtlı';
    await ctx.sandbox._kupeKontrolEt(ctx.alan);
    assert.strictEqual(ctx.warn.textContent, '');
  });
});

// ══════════════════════════════════════════════════════════════════════
// _sutIcenBuzagilar (forms.js:696)
// Kaynak mantık: Aktif + suttten_kesme_tarihi yok +
// (grup 'Buzağı' İÇERİR YAŞA BAKMAKSIZIN || yaş ≤ 180 gün)
// ══════════════════════════════════════════════════════════════════════
describe('_sutIcenBuzagilar (süt içen buzağı seti)', () => {
  function hayvan(over = {}) {
    return Object.assign({
      id: 'h-' + Math.random().toString(36).slice(2, 8),
      durum: 'Aktif',
      grup: 'Süt İçen Buzağı',
      dogum_tarihi: gunOnce(30),
      kupe_no: 'K-' + Math.random().toString(36).slice(2, 6),
    }, over);
  }
  function kopek(ctx, animals) { ctx.stateBag.animals = animals; return ctx.sandbox._sutIcenBuzagilar(); }

  it("grubu 'Buzağı' içeren aktif+kesilmemiş hayvan yaşından bağımsız listede", () => {
    const ctx = setupForms();
    const genc = hayvan({ id: 'a-genc', dogum_tarihi: gunOnce(30) });
    const yasli = hayvan({ id: 'a-yasli', dogum_tarihi: gunOnce(400) }); // >180 gün ama grup kuralı yetiyor
    const sonuc = kopek(ctx, [genc, yasli]);
    assert.deepStrictEqual(sonuc.map(a => a.id).sort(), ['a-genc', 'a-yasli']);
  });

  it("grubu 'Buzağı' içermeyen ama ≤180 günlük hayvan yaş kuralıyla listede", () => {
    const ctx = setupForms();
    const duve150 = hayvan({ id: 'a-duve', grup: 'Düve', dogum_tarihi: gunOnce(150) });
    const grupsuz30 = hayvan({ id: 'a-grupsuz', grup: null, dogum_tarihi: gunOnce(30) });
    const sonuc = kopek(ctx, [duve150, grupsuz30]);
    assert.deepStrictEqual(sonuc.map(a => a.id).sort(), ['a-duve', 'a-grupsuz']);
  });

  it('tam 180 gün sınırı dahil, 181 gün hariç (yaş kuralı tek başına yetmezse)', () => {
    const ctx = setupForms();
    const sinir180 = hayvan({ id: 'a-180', grup: 'Düve', dogum_tarihi: gunOnce(180) });
    const sinir181 = hayvan({ id: 'a-181', grup: 'Düve', dogum_tarihi: gunOnce(181) });
    const sonuc = kopek(ctx, [sinir180, sinir181]);
    assert.deepStrictEqual(sonuc.map(a => a.id), ['a-180']);
  });

  it("grubu 'Buzağı' içermeyen ve >180 günlük hayvan listede değil", () => {
    const ctx = setupForms();
    const inek200 = hayvan({ id: 'a-inek', grup: 'İnek', dogum_tarihi: gunOnce(200) });
    assert.strictEqual(kopek(ctx, [inek200]).length, 0);
  });

  it("durum 'Aktif' değilse (Çıktı/Satıldı) grupta olsa bile listede değil", () => {
    const ctx = setupForms();
    const cikan = hayvan({ id: 'a-cikan', durum: 'Çıktı' });
    const satilan = hayvan({ id: 'a-satilan', durum: 'Satıldı', grup: 'Buzağı' });
    assert.strictEqual(kopek(ctx, [cikan, satilan]).length, 0);
  });

  it("suttten_kesme_tarihi (üç t'li kolon adı!) doluysa listede değil", () => {
    // NOT: kaynak kod kolonu tam olarak 'suttten_kesme_tarihi' yazar (forms.js:698)
    const ctx = setupForms();
    const kesilmis = hayvan({ id: 'a-kesilmis', suttten_kesme_tarihi: '2026-01-15' });
    assert.strictEqual(kopek(ctx, [kesilmis]).length, 0);
  });

  it('dogum_tarihi yoksa: grup kuralı listede tutar, yaş kuralı tutmaz', () => {
    const ctx = setupForms();
    const grubuBuzagi = hayvan({ id: 'a-tarihsiz-1', grup: 'Süt İçen Buzağı', dogum_tarihi: null });
    const grubuDiger = hayvan({ id: 'a-tarihsiz-2', grup: 'İnek', dogum_tarihi: null });
    const sonuc = kopek(ctx, [grubuBuzagi, grubuDiger]);
    assert.deepStrictEqual(sonuc.map(a => a.id), ['a-tarihsiz-1']);
  });

  it("getState('animals') tanımsızsa → boş dizi (|| [] koruması)", () => {
    const ctx = setupForms(); // animals hiç set edilmiyor
    assert.deepStrictEqual(host(ctx.sandbox._sutIcenBuzagilar()), []);
  });
});

// ══════════════════════════════════════════════════════════════════════
// renderBuzagiPicker (forms.js:703)
// ══════════════════════════════════════════════════════════════════════
describe('renderBuzagiPicker (sütten kesme listesi + filtre)', () => {
  function pickerSetup(animals) {
    const ctx = setupForms({ state: { animals } });
    ctx.liste = ctx.document.__setEl('sk-liste', makeElement('div'));
    return ctx;
  }
  const A1 = {
    id: 'a1', kupe_no: 'TR-101', irk: 'Simental',
    durum: 'Aktif', grup: 'Süt İçen Buzağı', dogum_tarihi: gunOnce(30),
  };
  const A2 = {
    id: 'a2', kupe_no: 'TR-202', irk: 'Holstein',
    durum: 'Aktif', grup: 'Süt İçen Buzağı', dogum_tarihi: gunOnce(45),
  };

  it('boş filtre → tüm süt içen buzağılar işaretli checkbox satırı olarak render edilir', () => {
    const ctx = pickerSetup([A1, A2]);
    ctx.sandbox.renderBuzagiPicker('');
    const html = ctx.liste.innerHTML;
    assert.ok(html.includes('data-id="a1"'), 'a1 checkboxı olmalı');
    assert.ok(html.includes('data-id="a2"'), 'a2 checkboxı olmalı');
    assert.ok(html.includes('TR-101') && html.includes('TR-202'));
    assert.ok(html.includes('Simental') && html.includes('Holstein'));
    assert.ok(/checked/.test(html), 'satırlar varsayılan işaretli olmalı');
  });

  it('filtre küpe numarasını büyük/küçük harf duyarsız eşler', () => {
    const ctx = pickerSetup([A1, A2]);
    ctx.sandbox.renderBuzagiPicker('tr-2'); // küpe 'TR-202'
    assert.ok(ctx.liste.innerHTML.includes('TR-202'));
    assert.ok(!ctx.liste.innerHTML.includes('TR-101'));
  });

  it('hiçbir satır eşleşmezse "Süt içen buzağı yok" mesajı basılır', () => {
    const ctx = pickerSetup([A1, A2]);
    ctx.sandbox.renderBuzagiPicker('ZZZ-YOK');
    assert.ok(ctx.liste.innerHTML.includes('Süt içen buzağı yok'));
  });

  it('getDisplayKupe tercih sırası — kupe_no yoksa devlet_kupe ile aranır', () => {
    const devletli = {
      id: 'a3', devlet_kupe: 'DV-900', irk: 'Jersey',
      durum: 'Aktif', grup: 'Süt İçen Buzağı', dogum_tarihi: gunOnce(20),
    };
    const ctx = pickerSetup([devletli, A1]);
    ctx.sandbox.renderBuzagiPicker('dv-900');
    assert.ok(ctx.liste.innerHTML.includes('DV-900'));
    assert.ok(!ctx.liste.innerHTML.includes('TR-101'));
  });

  it('dogum_tarihi olmayan satırda yaş yerine "Yaş?" görünür', () => {
    const tarihsiz = {
      id: 'a4', kupe_no: 'TR-404', durum: 'Aktif', grup: 'Süt İçen Buzağı', dogum_tarihi: null,
    };
    const ctx = pickerSetup([tarihsiz]);
    ctx.sandbox.renderBuzagiPicker('');
    assert.ok(ctx.liste.innerHTML.includes('Yaş?'));
  });

  it('sk-liste elementi yoksa sessizce döner — hata fırlamaz', () => {
    const ctx = setupForms({ state: { animals: [A1] } }); // sk-liste YOK
    assert.doesNotThrow(() => ctx.sandbox.renderBuzagiPicker(''));
  });
});

// ══════════════════════════════════════════════════════════════════════
// vaccinePickerSearch (forms.js:885)
// ══════════════════════════════════════════════════════════════════════
describe('vaccinePickerSearch (aşı picker arama)', () => {
  function pickerSetup() {
    const ctx = setupForms();
    const list = ctx.document.__setEl('v-list', makeElement('div'));
    const mk = (name) => {
      const el = ctx.document.__reg(makeElement('label'));
      el.className = 'vp-item';
      el.dataset.name = name; // gerçek render data-name'i küçük harfe çevirir
      list.appendChild(el);
      return el;
    };
    ctx.item1 = mk('sap asisi clostridium');
    ctx.item2 = mk('brucella abortus');
    return ctx;
  }

  it('terim eşleşen öğeyi gösterir (flex), eşleşmeyeni gizler (none)', () => {
    const ctx = pickerSetup();
    ctx.sandbox.vaccinePickerSearch('v', 'sap');
    assert.strictEqual(ctx.item1.style.display, 'flex');
    assert.strictEqual(ctx.item2.style.display, 'none');
  });

  it('boş veya boşluk terim → tüm öğeler görünür', () => {
    const ctx = pickerSetup();
    ctx.item2.style.display = 'none'; // önce gizle
    ctx.sandbox.vaccinePickerSearch('v', '   ');
    assert.strictEqual(ctx.item1.style.display, 'flex');
    assert.strictEqual(ctx.item2.style.display, 'flex');
  });

  it('arama terimi lower-case çevrilir — büyük harf girdi de eşleşir', () => {
    const ctx = pickerSetup();
    ctx.sandbox.vaccinePickerSearch('v', 'SAP');
    assert.strictEqual(ctx.item1.style.display, 'flex');
    assert.strictEqual(ctx.item2.style.display, 'none');
  });

  it('eşleşme yoksa tüm öğeler gizlenir', () => {
    const ctx = pickerSetup();
    ctx.sandbox.vaccinePickerSearch('v', 'yok-boyle');
    assert.strictEqual(ctx.item1.style.display, 'none');
    assert.strictEqual(ctx.item2.style.display, 'none');
  });
});

// ══════════════════════════════════════════════════════════════════════
// selectedVaccineRows (forms.js:893)
// ══════════════════════════════════════════════════════════════════════
describe('selectedVaccineRows (seçili aşı satırlarını toplama)', () => {
  function chkFixture(ctx, { id, name, dose, checked = true, cls = 'v-chk' }) {
    const chk = ctx.document.__reg(makeElement('input'));
    chk.className = cls;
    chk.checked = checked;
    chk.dataset.id = id;
    chk.dataset.name = name;
    chk.dataset.dose = dose;
    return chk;
  }
  function rowFixture(ctx, id, { doseVal, offVal, offDef }) {
    const row = ctx.document.__setEl('v-row-' + id, makeElement('div'));
    if (doseVal !== undefined) {
      const dose = ctx.document.__reg(makeElement('input'));
      dose.className = 'fi vp-dose'; dose.value = doseVal;
      row.appendChild(dose);
    }
    if (offVal !== undefined) {
      const off = ctx.document.__reg(makeElement('input'));
      off.className = 'fi vp-off'; off.value = offVal; off.dataset.def = offDef;
      row.appendChild(off);
    }
    return row;
  }

  it('seçili satır: doz/offset input değerleri ve dataset varsayılanları parse edilir', () => {
    const ctx = setupForms();
    chkFixture(ctx, { id: 'V1', name: 'Şap Aşısı', dose: '5' });
    rowFixture(ctx, 'V1', { doseVal: '2.5', offVal: '30', offDef: '28' });
    const out = ctx.sandbox.selectedVaccineRows('v');
    assert.deepStrictEqual(host(out), [{
      id: 'V1', name: 'Şap Aşısı',
      dose: 2.5,        // satır dozu (parseFloat)
      stdDose: 5,       // dataset dozu (parseFloat)
      offset: 30,       // satır offset'i (parseInt)
      defOffset: 28,    // offset inputunun data-def'i (parseInt)
    }]);
  });

  it('satır elementi olmayan seçili aşı → dose/offset null; işaretsiz checkbox hiç toplanmaz', () => {
    const ctx = setupForms();
    chkFixture(ctx, { id: 'V2', name: 'Brucella', dose: '' });           // satırı yok
    chkFixture(ctx, { id: 'V3', name: 'Johna', dose: '3', checked: false }); // işaretsiz
    rowFixture(ctx, 'V3', { doseVal: '9', offVal: '9', offDef: '9' });   // işaretsize ait satır — yok sayılmalı
    const out = ctx.sandbox.selectedVaccineRows('v');
    assert.strictEqual(out.length, 1, 'sadece işaretli + satırsız V2 toplanmalı');
    assert.deepStrictEqual(host(out[0]), {
      id: 'V2', name: 'Brucella', dose: null, stdDose: null, offset: null, defOffset: null,
    });
  });

  it('boş input değerleri null kalır ama dolu data-def yine de defOffset verir', () => {
    const ctx = setupForms();
    chkFixture(ctx, { id: 'V4', name: 'Karbonhidrat', dose: '2' });
    rowFixture(ctx, 'V4', { doseVal: '', offVal: '', offDef: '21' });
    const out = ctx.sandbox.selectedVaccineRows('v');
    assert.deepStrictEqual(host(out[0]), {
      id: 'V4', name: 'Karbonhidrat',
      dose: null, stdDose: 2, offset: null, defOffset: 21,
    });
  });

  it("prefix parametresi sınıf adını doğru kurar — 'bv' yalnız .bv-chk:checked toplar", () => {
    const ctx = setupForms();
    chkFixture(ctx, { id: 'V9', name: 'Sızan', dose: '1' });            // v-chk — bv sorgusuna girmemeli
    chkFixture(ctx, { id: 'B1', name: 'Topal', dose: '', cls: 'bv-chk' });
    const out = ctx.sandbox.selectedVaccineRows('bv');
    assert.strictEqual(out.length, 1);
    assert.strictEqual(out[0].id, 'B1');
  });
});

// ══════════════════════════════════════════════════════════════════════
// _vaccineNaive (forms.js:923)
// ══════════════════════════════════════════════════════════════════════
describe('_vaccineNaive (muadil aşı naive hesabı)', () => {
  function naiveSetup(logs, diseases) {
    return setupForms({
      state: { vaccination_log: logs, vaccine_diseases: diseases },
    }).sandbox;
  }

  it('aşı kaydı hiç yoksa → naive (true)', () => {
    const sandbox = naiveSetup(undefined, undefined);
    assert.strictEqual(sandbox._vaccineNaive('A1', 'V1'), true);
  });

  it('başka hayvanların logları sayılmaz → bu hayvan naive', () => {
    const sandbox = naiveSetup(
      [{ animal_id: 'A2', vaccine_id: 'V1' }],
      [{ vaccine_id: 'V1', disease_id: 'D1' }],
    );
    assert.strictEqual(sandbox._vaccineNaive('A1', 'V1'), true);
  });

  it('aynı aşı daha önce uygulanmışsa → naive değil (false)', () => {
    const sandbox = naiveSetup(
      [{ animal_id: 'A1', vaccine_id: 'V1' }],
      [],
    );
    assert.strictEqual(sandbox._vaccineNaive('A1', 'V1'), false);
  });

  it('farklı aşı ama aynı hastalığı kapsıyorsa (muadil) → naive değil', () => {
    const sandbox = naiveSetup(
      [{ animal_id: 'A1', vaccine_id: 'V2' }],
      [
        { vaccine_id: 'V1', disease_id: 'D1' },
        { vaccine_id: 'V2', disease_id: 'D1' }, // V2 de D1'i kapsıyor
      ],
    );
    assert.strictEqual(sandbox._vaccineNaive('A1', 'V1'), false);
  });

  it('ilgisi olmayan aşı/hastalık geçmişi → naive kalır', () => {
    const sandbox = naiveSetup(
      [{ animal_id: 'A1', vaccine_id: 'V2' }],
      [
        { vaccine_id: 'V1', disease_id: 'D1' },
        { vaccine_id: 'V2', disease_id: 'D2' }, // hastalık kesişmiyor
      ],
    );
    assert.strictEqual(sandbox._vaccineNaive('A1', 'V1'), true);
  });

  it("çoklu hastalık kesişimi — tek ortak hastalık bile naive'i bozmaya yeter", () => {
    const sandbox = naiveSetup(
      [{ animal_id: 'A1', vaccine_id: 'V3' }],
      [
        { vaccine_id: 'V1', disease_id: 'D1' },
        { vaccine_id: 'V1', disease_id: 'D3' },
        { vaccine_id: 'V3', disease_id: 'D3' }, // V3 yalnız D3'ü kapsıyor
      ],
    );
    assert.strictEqual(sandbox._vaccineNaive('A1', 'V1'), false);
  });
});

// ══════════════════════════════════════════════════════════════════════
// ekUygulamaEkle / ekUygulama_sil / _ekListeGoster (forms.js:198-263)
// Modül-içi `_ekUygulamalar` dizisi public fonksiyonlarla sürülür.
// ══════════════════════════════════════════════════════════════════════
describe('ek uygulama akışı (ekChipSec → ekUygulamaEkle → ekUygulama_sil)', () => {
  function ekSetup() {
    const ctx = setupForms();
    ctx.document.__setEl('ek-liste', makeElement('div'));
    ctx.stokRow = ctx.document.__setEl('ek-stok-row', makeElement('div'));
    ctx.sel = ctx.document.__setEl('ek-stok-sel', makeElement('select'));
    // gerçek <select>'te options her zaman bir HTMLCollection'dır;
    // stub'da forms.js:233'ün `sel.options[...]` erişimi patlamasın diye boş varsayılan
    ctx.sel.options = [];
    ctx.sel.selectedIndex = 0;
    ctx.doz = ctx.document.__setEl('ek-doz', makeElement('input'));
    ctx.yol = ctx.document.__setEl('ek-yol', makeElement('select'));
    ctx.chip = ctx.document.__reg(makeElement('button'));
    ctx.chip.className = 'ek-chip';
    ctx.chip.dataset.tur = 'GnRH';
    ctx.chip2 = ctx.document.__reg(makeElement('button'));
    ctx.chip2.className = 'ek-chip';
    ctx.chip2.dataset.tur = 'E Vitamini';
    ctx.tick = () => new Promise(r => setTimeout(r, 0)); // _ekStokYukle async işinin oturması
    return ctx;
  }
  function stokSec(ctx, { value, ad, birim = 'ml' }) {
    const opt = makeElement('option');
    opt.dataset.ad = ad;
    opt.dataset.birim = birim;
    ctx.sel.value = value;
    ctx.sel.selectedIndex = 0;
    ctx.sel.options = [opt];
  }

  it('ekle → listele → sil → liste gizlenir tam akışı', async () => {
    const ctx = ekSetup();
    const liste = ctx.document.getElementById('ek-liste');

    // 1) GnRH ekle
    ctx.sandbox.ekChipSec(ctx.chip);
    await ctx.tick();
    assert.strictEqual(ctx.chip.classList.contains('aktif'), true);
    stokSec(ctx, { value: 'stok-1', ad: 'Ovarelin', birim: 'ml' });
    ctx.doz.value = '2.5';
    ctx.yol.value = 'IM';
    ctx.sandbox.ekUygulamaEkle();

    assert.strictEqual(liste.style.display, 'block');
    assert.match(liste.innerHTML, /<b>GnRH<\/b>/);
    assert.ok(liste.innerHTML.includes('Ovarelin'));
    assert.ok(liste.innerHTML.includes('2.5 ml'));
    assert.ok(liste.innerHTML.includes('IM'));
    assert.ok(liste.innerHTML.includes('ekUygulama_sil(0)'));
    assert.strictEqual(ctx.doz.value, '', 'doz alanı eklemeden sonra temizlenir');
    assert.strictEqual(ctx.chip.classList.contains('aktif'), false, 'chip seçimi sıfırlanır');
    assert.strictEqual(ctx.stokRow.style.display, 'none', 'stok satırı gizlenir');

    // 2) ikinci uygulama (E Vitamini)
    ctx.sandbox.ekChipSec(ctx.chip2);
    await ctx.tick();
    stokSec(ctx, { value: 'stok-2', ad: 'Selevit', birim: 'ml' });
    ctx.doz.value = '1';
    ctx.yol.value = 'SC';
    ctx.sandbox.ekUygulamaEkle();
    assert.ok(liste.innerHTML.includes('Selevit'));
    assert.ok(liste.innerHTML.includes('ekUygulama_sil(1)'), 'iki satırlık liste indekslenmeli');
    assert.ok(liste.innerHTML.includes('Ovarelin'));

    // 3) ilkini sil
    ctx.sandbox.ekUygulama_sil(0);
    assert.ok(!liste.innerHTML.includes('Ovarelin'), 'silinen satır listeden kalkmalı');
    assert.ok(liste.innerHTML.includes('Selevit'), 'kalan satır durmalı');
    assert.strictEqual(liste.style.display, 'block');

    // 4) sonuncuyu sil → liste gizlenir
    ctx.sandbox.ekUygulama_sil(0);
    assert.strictEqual(liste.style.display, 'none');
  });

  it('tür seçilmeden ekleme → "Uygulama türü seçin" uyarısı, hiçbir şey eklenmez', () => {
    const ctx = ekSetup();
    ctx.doz.value = '2';
    ctx.sandbox.ekUygulamaEkle(); // ekChipSec çağrılmadı
    assert.strictEqual(ctx.calls.toast.length, 1);
    assert.strictEqual(ctx.calls.toast[0].msg, 'Uygulama türü seçin');
    assert.strictEqual(ctx.calls.toast[0].err, true);
    assert.strictEqual(ctx.document.getElementById('ek-liste').innerHTML, '');
  });

  it('geçersiz doz (0, negatif, sayı değil, boş) → "Doz girin", hiçbiri eklenmez', async () => {
    const ctx = ekSetup();
    ctx.sandbox.ekChipSec(ctx.chip);
    await ctx.tick();
    for (const kotu of ['0', '-1', 'abc', '']) {
      ctx.doz.value = kotu;
      ctx.sandbox.ekUygulamaEkle();
    }
    assert.strictEqual(ctx.calls.toast.length, 4);
    ctx.calls.toast.forEach(t => assert.strictEqual(t.msg, 'Doz girin'));
    assert.strictEqual(ctx.document.getElementById('ek-liste').innerHTML, '');
  });

  it('_ekListeGoster tür ve stok adı üzerinde HTML kaçışlaması uygular', async () => {
    const ctx = ekSetup();
    ctx.chip.dataset.tur = 'A&B <b>x</b>';
    ctx.sandbox.ekChipSec(ctx.chip);
    await ctx.tick();
    stokSec(ctx, { value: 'stok-9', ad: '<script>zmnr</script>' });
    ctx.doz.value = '1';
    ctx.yol.value = 'IM';
    ctx.sandbox.ekUygulamaEkle();
    const html = ctx.document.getElementById('ek-liste').innerHTML;
    assert.ok(html.includes('A&amp;B &lt;b&gt;x&lt;/b&gt;'), 'tür escape edilmiş görünmeli');
    assert.ok(html.includes('&lt;script&gt;zmnr&lt;/script&gt;'), 'stok adı escape edilmiş görünmeli');
    assert.ok(!html.includes('<b>x</b>'), 'ham HTML sızmamalı');
  });
});
