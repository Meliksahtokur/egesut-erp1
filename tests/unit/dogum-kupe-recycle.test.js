// tests/unit/dogum-kupe-recycle.test.js
// K1 recycle sonrası iki kilit (2026-10-30):
// 1) Hata metni: Postgres mesajı GERÇEK yoldan geçer (db.rpc → rpc() → _trErr → getUserMessage),
//    jenerik "Bir hata oluştu" ile ezilmez; küpe çakışması küpeyi anlatır.
// 2) K7: aynı küpe önce Ölü sonra Aktif listedeyken küpeyle arayan yollar aktif hayvanı bulur.
// 3) K1: eski doğum satırı yeniden verilen küpeyi değil o doğumun buzağısını açar (2026-10-31).
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeStorage } = require('./support/loadModule.js');

const JENERIK = 'Bir hata oluştu';

function kullaniciMetni(hamMesaj) {
  const client = { rpc: async () => ({ data: null, error: { message: hamMesaj } }) };
  const api = loadBrowserModule('js/api.js', {
    storage: makeStorage(),
    extra: {
      supabase: { createClient: () => client },
      navigator: { onLine: true, userAgent: 'node-test' },
      toast: () => {},
    },
  });
  const { sandbox: eh } = loadBrowserModule('js/utils/errorHandler.js');
  return api.sandbox.rpc('dogum_kaydet', {}).then(
    () => assert.fail('rpc reddetmeliydi'),
    (e) => eh.getUserMessage(e),
  );
}

test('rpc yolu: aktif küpe çakışması (hayvanlar_kupe_no_key) küpeyi anlatır', async () => {
  const out = await kullaniciMetni('duplicate key value violates unique constraint "hayvanlar_kupe_no_key"');
  assert.ok(out.includes('küpe'), out);
  assert.ok(!out.includes(JENERIK), out);
});

test('rpc yolu: diğer duplicate key jenerikle ezilmez', async () => {
  const out = await kullaniciMetni('duplicate key value violates unique constraint "hayvanlar_pkey"');
  assert.strictEqual(out, 'Bu kayıt zaten mevcut.');
});

test('rpc yolu: _ERR_MAP eşlemelerinin hiçbiri jenerikle ezilmez', async () => {
  for (const ham of ['new row violates row-level security policy', 'violates foreign key constraint',
    'violates not-null constraint', 'null value in column violates not null', 'network error', 'Failed to fetch']) {
    const out = await kullaniciMetni(ham);
    assert.ok(!out.includes(JENERIK), `${ham} → ${out}`);
  }
});

// ── K7 ────────────────────────────────────────────────────────────────
const OLU = { id: 'h-olu', kupe_no: '503', durum: 'Ölü' };
const AKTIF = { id: 'h-aktif', kupe_no: '503', durum: 'Aktif' };

function loadUi(animals, getData = async () => []) {
  return loadBrowserModule('js/ui.js', {
    expose: ['_btModalSecilenIds'],
    extra: {
      esc: (s) => String(s ?? ''),
      escAttr: (s) => String(s ?? ''),
      getState: (k) => (k === 'animals' ? animals : undefined),
      getData,
    },
  });
}

test('K7 openInsemSafe: ölü+aktif aynı küpede aktif hayvanın tohumlamalarına bakar', async () => {
  const bakilan = [];
  const tohumlamalar = [
    { hayvan_id: 'h-olu', sonuc: 'Gebe' },
    { hayvan_id: 'h-aktif', sonuc: 'Boş' },
  ];
  const { sandbox } = loadUi([OLU, AKTIF], async (_t, f) => {
    const liste = tohumlamalar.filter(f);
    bakilan.push(...liste.map((x) => x.hayvan_id));
    return liste;
  });
  sandbox.openMWithHayvan = () => {};
  await sandbox.openInsemSafe('503');
  assert.deepStrictEqual(bakilan, ['h-aktif']);
});

test('K7 btSerbestYukle: yapıştırılan küpe aktif hayvanı seçer', () => {
  const { sandbox, document: doc, exposed } = loadUi([OLU, AKTIF]);
  doc.__setEl('bt-serbest-input', Object.assign(doc.createElement('textarea'), { value: '503\n' }));
  doc.__setEl('bt-serbest-sonuc', doc.createElement('div'));
  sandbox.btSerbestYukle();
  assert.deepStrictEqual([...exposed._btModalSecilenIds], ['h-aktif']);
});

// ── K1: eski doğum satırı doğan buzağıyı açar (Üreme > Doğum listesi ve Geçmiş kartı) ──
const DOGUM = { anne_id: 'h-anne', tarih: '2026-01-01', yavru_kupe: '503', yavru_cins: 'Erkek' };
const yavruAksiyon = (html) => html.match(/<b data-action="(gm-[a-z]+)" data-det="([^"]*)"/)?.slice(1);

async function uremeDogumHtml(satir) {
  const { sandbox, document: doc } = loadUi([OLU, AKTIF]);
  sandbox.idbGetAll = async (t) => (t === 'dogum' ? [satir] : []);
  sandbox.fmtTarih = (s) => s;
  const el = doc.createElement('div');
  await sandbox._uremeDogum(el);
  return el.innerHTML;
}

function gecmisHtml(satir) {
  const { sandbox } = loadUi([OLU, AKTIF]);
  Object.assign(sandbox, { HEKIMLER: [], _gmUndoButtonHtml: () => '', fmtTarih: (s) => s });
  return sandbox._gecmisEntryHtml({ type: 'dogum', data: satir, eventAt: '2026-01-01' });
}

for (const [ad, uret] of [['Üreme doğum listesi', uremeDogumHtml], ['Geçmiş kartı', gecmisHtml]]) {
  test(`K1 ${ad}: buzagi_id varsa küpeyi değil doğan buzağıyı açar`, async () => {
    const html = await uret({ ...DOGUM, buzagi_id: 'h-olu' });
    assert.deepStrictEqual(yavruAksiyon(html), ['gm-det', 'h-olu']);
  });
  test(`K1 ${ad}: buzagi_id yoksa bugünkü davranış (küpeyle açar)`, async () => {
    const html = await uret({ ...DOGUM, buzagi_id: null });
    assert.deepStrictEqual(yavruAksiyon(html), ['gm-kupe', '503']);
  });
}
