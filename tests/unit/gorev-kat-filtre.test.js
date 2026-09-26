// tests/unit/gorev-kat-filtre.test.js — Üreme sekmesi kategori/tarih filtresi
// K7 (BUG-UREME-SEKMESI-FILTRE) → C3 revizyonu (cila2, BUG-UREME-FILTRE-SIZINTI):
// üreme-vaka kümesi diseases.category='Üreme' yerine cases.protocol_family='OVSYNC'
// bazlıdır — 'Üreme' kategorili Metrit/Endometrit TEDAVİ seansları Üreme'ye sızıyordu.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, loadExtractedFunction } = require('./support/loadModule.js');

// F4/K7: sabitler js/ui.js KAYNAĞINDAN çıkar — fixture kopyası gerçek haritayı
// gölgeliyordu. expose kalıbı: const'lar vm lexical scope'unda kaldığı için
// ikinci script ile dışarı alınır (loadModule.js dokümanı).
const _uiExposed = loadBrowserModule('js/ui.js', {
  extra: { esc:s=>String(s), escAttr:s=>String(s), fmtTarih:s=>String(s) },
  expose: ['_katTipMap', '_allKatTips', '_planliUremeTipler'],
}).exposed;
const _katTipMap = _uiExposed._katTipMap;
const _allKatTips = _uiExposed._allKatTips;
const _planliUremeTipler = _uiExposed._planliUremeTipler;
const ortak = { _katTipMap, _allKatTips, _planliUremeTipler };

// fixture (sentezik): Ovsync (protocol_family damgalı) + Mastit (Meme, ailesiz) +
// Metrit (kategorisi 'Üreme' ama ailesiz — C3 sızıntı karşı-örneği) vakaları.
// C3 notu: kategori bilgisi artık filtrede kullanılmaz — ayırt edici protocol_family.
const cases=[
  {id:'cOv', disease_id:'dOv', status:'active', protocol_family:'OVSYNC', category:'Üreme'},
  {id:'cMast', disease_id:'dMast', status:'active', protocol_family:null, category:'Meme'},
  {id:'cMet', disease_id:'dMet', status:'active', protocol_family:null, category:'Üreme'},
];
const tdays=[
  {id:'tdOv', case_id:'cOv', day_no:1},
  {id:'tdMast', case_id:'cMast', day_no:1},
  {id:'tdMet', case_id:'cMet', day_no:1},
];
const seanslar=[
  {id:'sOv', treatment_day_id:'tdOv'},
  {id:'sMast', treatment_day_id:'tdMast'},
  {id:'sMet', treatment_day_id:'tdMet'},
];
const tdById=Object.fromEntries(tdays.map(x=>[x.id,x]));
const seansById=Object.fromEntries(seanslar.map(x=>[x.id,x]));
const gSeansOv={id:'gS1', gorev_tipi:'TEDAVI_SEANS', seans_admin_id:'sOv', parent_id:'gP1', hedef_tarih:'2026-09-25', tamamlandi:false, iptal:false};
const gGunOv={id:'gG1', gorev_tipi:'TEDAVI_GUN', parent_id:null, hedef_tarih:'2026-09-25', aciklama:JSON.stringify({day_id:'tdOv'}), tamamlandi:false, iptal:false};
const gSeansMast={id:'gS2', gorev_tipi:'TEDAVI_SEANS', seans_admin_id:'sMast', parent_id:'gP2', hedef_tarih:'2026-09-25', tamamlandi:false, iptal:false};
const gSeansMet={id:'gS3', gorev_tipi:'TEDAVI_SEANS', seans_admin_id:'sMet', parent_id:'gP3', hedef_tarih:'2026-09-25', tamamlandi:false, iptal:false};

const _uremeVakaCaseIds=loadExtractedFunction('js/ui.js','_uremeVakaCaseIds');
const _uremeGorevMi=loadExtractedFunction('js/ui.js','_uremeGorevMi',{extra:ortak});
const _kategoriFiltreUygun=loadExtractedFunction('js/ui.js','_kategoriFiltreUygun',{extra:{...ortak,_uremeGorevMi}});
const _bugunFiltreUygun=loadExtractedFunction('js/ui.js','_bugunFiltreUygun',{extra:ortak});

test('C3-1 (eskiden K7-1): üreme vaka kümesi protocol_family=OVSYNC vakaları toplar', () => {
  const s=_uremeVakaCaseIds(cases);
  assert.ok(s.has('cOv'), 'ovsync damgalı vaka kümede');
  assert.ok(!s.has('cMast')&&!s.has('cMet'), 'ailesiz vakalar kümede değil');
});

test('C3-2: ovsync seansı/günü Üreme\'de; Mastit VE Metrit seansı Tedavi\'de kalır', () => {
  const uremeCaseIdler=_uremeVakaCaseIds(cases);
  assert.strictEqual(_uremeGorevMi(gSeansOv, uremeCaseIdler, tdById, seansById), true, 'ovsync seansı üreme');
  assert.strictEqual(_uremeGorevMi(gGunOv, uremeCaseIdler, tdById, seansById), true, 'ovsync tedavi günü üreme');
  assert.strictEqual(_uremeGorevMi(gSeansMast, uremeCaseIdler, tdById, seansById), false, 'mastit seansı üreme değil');
  // SIZINTI KİLİDİ: Metrit kategorisi 'Üreme' — eski K7 bunu Üreme'ye alıyordu.
  assert.strictEqual(_uremeGorevMi(gSeansMet, uremeCaseIdler, tdById, seansById), false,
    'Metrit (Üreme kategorili, ailesiz) seansı üreme DEĞİL — BUG-UREME-FILTRE-SIZINTI');
  assert.strictEqual(_kategoriFiltreUygun(gSeansOv,'ureme',uremeCaseIdler,tdById,seansById), true);
  assert.strictEqual(_kategoriFiltreUygun(gSeansOv,'tedavi',uremeCaseIdler,tdById,seansById), false, 'çift sayım yok');
  assert.strictEqual(_kategoriFiltreUygun(gSeansMet,'tedavi',uremeCaseIdler,tdById,seansById), true, 'Metrit Tedavi\'de kalır');
  assert.strictEqual(_kategoriFiltreUygun({gorev_tipi:'OVSYNC_BASLAT'},'ureme',uremeCaseIdler,tdById,seansById), true);
});

test('C3-3 (eskiden K7-3): yaklaşan planlı üreme görevi Bugün penceresinde', () => {
  const today='2026-09-25', d7='2026-10-02';
  const baslat={gorev_tipi:'OVSYNC_BASLAT', hedef_tarih:'2026-09-28'};
  const planli={gorev_tipi:'TOHUMLAMA_PLANLI', hedef_tarih:'2026-10-02'};
  const uzak={gorev_tipi:'OVSYNC_BASLAT', hedef_tarih:'2026-10-06'};
  assert.strictEqual(_bugunFiltreUygun(baslat,today,d7), true, 'OVSYNC_BASLAT +3g Bugün\'de görünür');
  assert.strictEqual(_bugunFiltreUygun(planli,today,d7), true, 'pencere sınırı dahil');
  assert.strictEqual(_bugunFiltreUygun(uzak,today,d7), false, '7 günden öte Bugün\'de değil');
  assert.strictEqual(_bugunFiltreUygun({gorev_tipi:'TEDAVI_GUN',hedef_tarih:'2026-09-28'},today,d7), false,
    'yardımcı düzeyinde istisna yalnız planlı üreme+ASI tiplerine (ovsync seans genişletmesi loadTasks kablosundadır)');
  assert.strictEqual(_bugunFiltreUygun({gorev_tipi:'ASI_PLANLI',hedef_tarih:'2026-09-28'},today,d7), true, 'mevcut ASI davranışı korunur');
});

test('C3-4 (eskiden K7-4): loadTasks kablolaması — kaynak kanıtı', () => {
  const src=require('fs').readFileSync('js/ui.js','utf8');
  const lt=src.slice(src.indexOf('async function loadTasks'), src.indexOf('function _stokAdi'));
  assert.ok(lt.includes('_bugunFiltreUygun(t,today,_d7)'), 'today süzgeci yardımcıdan');
  assert.ok((lt.match(/_kategoriFiltreUygun\(/g)||[]).length>=3, 'açık + done + C3 üreme-pencere kategori süzgeçleri');
  // C3: Bugün penceresi, Üreme kategorisi seçiliyken üreme görevlerine açılır
  assert.ok(lt.includes("_taskKategori==='ureme'&&_kategoriFiltreUygun(t,'ureme'"),
    'C3 üreme pencere genişletmesi kablosuz kalmadı');
  // C3: seans grup anahtarı hayvan|TARİH (mükerrer üst-üste grup giderimi)
  assert.ok(lt.includes("key=(t.hayvan_id||'')+'|'+(t.hedef_tarih||td?.treatment_date||'')"),
    'grup anahtarı hayvan|tarih (C3 mükerrer)');
  assert.ok(!lt.includes("key=(t.hayvan_id||'')+'|'+dayId"), 'eski hayvan|dayId anahtarı yok');
  const ixHarita=lt.indexOf('_uremeVakaCaseIds(');
  const ixFiltre=lt.indexOf('_kategoriFiltreUygun(');
  assert.ok(ixHarita>-1&&ixFiltre>-1&&ixHarita<ixFiltre, 'üreme vaka kümesi süzgeçlerden ÖNCE kurulmalı');
});

test('C3-5 (eskiden K7-5): gerçek harita sabitleri kilitli', () => {
  assert.ok(Array.isArray(_katTipMap.ureme) && _katTipMap.ureme.includes('TOHUMLAMA_PLANLI')
    && _katTipMap.ureme.includes('OVSYNC_BASLAT'), 'üreme listesi planlı üreme tiplerini içerir');
  assert.ok(Array.isArray(_katTipMap.tedavi) && _katTipMap.tedavi.includes('TEDAVI_SEANS')
    && _katTipMap.tedavi.includes('TEDAVI_GUN'), 'tedavi listesi seans/gün tiplerini içerir');
  assert.deepStrictEqual([..._planliUremeTipler].sort(), ['OVSYNC_BASLAT','TOHUMLAMA_PLANLI'],
    '_planliUremeTipler tam olarak bu iki tip');
  assert.ok(_allKatTips.includes('TEDAVI_SEANS') && _allKatTips.includes('OVSYNC_BASLAT')
    && _allKatTips.includes('ASI_PLANLI'), '_allKatTips türetilmiş liste ipuçlarını taşır');
});

// ─────────────────────────────────────────────────────────────────────────────
// C3 SAYI KANITI: fixture DEMO verisinden türetildi (2026-09-25 çekimi;
// id'ler birebir). SQL eşdeğeri (Bugün+Üreme penceresi): 25 görev —
//   SELECT count(*) ... (test başlığındaki sorgu, cila2 DONE kaydında tam metin)
// Zincir: top-level eleme → Bugün penceresi (C3 üreme genişletmesiyle) → kategori.
// ─────────────────────────────────────────────────────────────────────────────
const D_CASES=[
  {id:'cOvA', protocol_family:'OVSYNC'},           // demo c065e94e (Gün1/2/3/4 zinciri)
  {id:'cOvB', protocol_family:'OVSYNC'},           // demo 2f2721e7 (208 — bugün+yaklaşan)
  {id:'cOvC', protocol_family:'OVSYNC'},           // demo 1e9b93a9
  {id:'cOvD', protocol_family:'OVSYNC'},           // demo bf9644c7
  {id:'cOvE', protocol_family:'OVSYNC'},           // demo aa786467
  {id:'cOvF', protocol_family:'OVSYNC'},           // demo f90731be
  {id:'cOvG', protocol_family:'OVSYNC'},           // demo 03b10e2a
  {id:'cOvH', protocol_family:'OVSYNC'},           // demo b284807a
  {id:'cOvI', protocol_family:'OVSYNC'},           // demo 25a638aa
  {id:'cOvJ', protocol_family:'OVSYNC'},           // demo 1b5c2a83
  {id:'cOvK', protocol_family:'OVSYNC'},           // demo 59eca038 zinciri (09-26)
  {id:'cOvL', protocol_family:'OVSYNC'},           // demo 90ff6bde zinciri (09-26)
  {id:'cOvM', protocol_family:'OVSYNC'},           // demo 982fbd16 zinciri (09-26)
  {id:'cOvN', protocol_family:'OVSYNC'},           // demo cf41ebd4 zinciri (09-26)
  {id:'cOvO', protocol_family:'OVSYNC'},           // demo bcc67af7 zinciri (09-26)
  {id:'cOvP', protocol_family:'OVSYNC'},           // demo 42906906 zinciri (09-26)
  {id:'cOvQ', protocol_family:'OVSYNC'},           // demo b27968b2 zinciri (09-26)
  {id:'cOvR', protocol_family:'OVSYNC'},           // demo ba865063 zinciri (09-26)
  {id:'cMet', protocol_family:null},               // Metrit (81a4376c) — SIZINTI karşı-örneği
  {id:'cMast', protocol_family:null},              // Mastit
];
const D_TDS=[
  {id:'tdB1', case_id:'cOvB'},   // 758378ab · 09-25 (208 bugün GUN+SEANS)
  {id:'tdA2', case_id:'cOvA'},   // efd7a815 · 09-25 (002 bugün GUN+SEANS)
  {id:'tdA3', case_id:'cOvA'},   // 69ba3c46 · 09-26
  {id:'tdA4', case_id:'cOvA'},   // 18afa9e9 · 09-27
  {id:'tdB2', case_id:'cOvB'},   // 8676fef4 · 10-02 (pencere ucu)
  {id:'tdC1', case_id:'cOvC'},   // 356a8368 · 09-26
  {id:'tdD1', case_id:'cOvD'},   // 674b2f94 · 09-26
  {id:'tdE1', case_id:'cOvE'},   // 08aa02e8 · 09-26
  {id:'tdF1', case_id:'cOvF'},   // e59feda5 · 09-26
  {id:'tdG1', case_id:'cOvG'},   // 31009749 · 09-26
  {id:'tdH1', case_id:'cOvH'},   // 21d0c77f · 09-26
  {id:'tdI1', case_id:'cOvI'},   // b15b1dd9 · 09-26
  {id:'tdJ1', case_id:'cOvJ'},   // 5e355728 · 09-26
  {id:'tdK1', case_id:'cOvK'},   // 59eca038 zinciri · 09-26
  {id:'tdL1', case_id:'cOvL'},   // 90ff6bde zinciri · 09-26
  {id:'tdM1', case_id:'cOvM'},   // 982fbd16 zinciri · 09-26
  {id:'tdN1', case_id:'cOvN'},   // cf41ebd4 zinciri · 09-26
  {id:'tdO1', case_id:'cOvO'},   // bcc67af7 zinciri · 09-26
  {id:'tdP1', case_id:'cOvP'},   // 42906906 zinciri · 09-26
  {id:'tdQ1', case_id:'cOvQ'},   // b27968b2 zinciri · 09-26
  {id:'tdR1', case_id:'cOvR'},   // ba865063 zinciri · 09-26
  {id:'tdMet', case_id:'cMet'},
  {id:'tdMast', case_id:'cMast'},
];
const D_SEANS=[
  {id:'sB1', treatment_day_id:'tdB1'},   // 86393dd2
  {id:'sA2', treatment_day_id:'tdA2'},   // 30187335
  {id:'sA3', treatment_day_id:'tdA3'},   // 646528e9
  {id:'sA4', treatment_day_id:'tdA4'},   // 042088c2
  {id:'sB2', treatment_day_id:'tdB2'},   // bfdabc07 (10-02)
  {id:'sC1', treatment_day_id:'tdC1'}, {id:'sD1', treatment_day_id:'tdD1'}, {id:'sE1', treatment_day_id:'tdE1'},
  {id:'sF1', treatment_day_id:'tdF1'}, {id:'sG1', treatment_day_id:'tdG1'}, {id:'sH1', treatment_day_id:'tdH1'},
  {id:'sI1', treatment_day_id:'tdI1'}, {id:'sJ1', treatment_day_id:'tdJ1'}, {id:'sK1', treatment_day_id:'tdK1'},
  {id:'sL1', treatment_day_id:'tdL1'}, {id:'sM1', treatment_day_id:'tdM1'}, {id:'sN1', treatment_day_id:'tdN1'},
  {id:'sO1', treatment_day_id:'tdO1'}, {id:'sP1', treatment_day_id:'tdP1'}, {id:'sQ1', treatment_day_id:'tdQ1'},
  {id:'sR1', treatment_day_id:'tdR1'},
  {id:'sMet', treatment_day_id:'tdMet'}, // 6d833a29 — Metrit bugün
  {id:'sMast', treatment_day_id:'tdMast'},
];
const D_tdById=Object.fromEntries(D_TDS.map(x=>[x.id,x]));
const D_seansById=Object.fromEntries(D_SEANS.map(x=>[x.id,x]));
const g=(id,tip,hedef,extra={})=>({id, gorev_tipi:tip, hedef_tarih:hedef, tamamlandi:false, iptal:false, parent_id:null, ...extra});
// Demo çekiminin Bugün+Üreme penceresi içindeki TÜM görevleri (25):
const D_GOREVLER=[
  // bugün 09-25
  g('dG1','TEDAVI_GUN','2026-09-25',{aciklama:JSON.stringify({day_id:'tdA2'})}),
  g('dG2','TEDAVI_GUN','2026-09-25',{aciklama:JSON.stringify({day_id:'tdB1'})}),
  g('dS1','TEDAVI_SEANS','2026-09-25',{seans_admin_id:'sB1',parent_id:'p1'}),
  g('dS2','TEDAVI_SEANS','2026-09-25',{seans_admin_id:'sA2',parent_id:'p2'}),
  // 09-26 (8 GUN + 9 SEANS — demo çekimi birebir)
  g('dG3','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdM1'})}),
  g('dG4','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdN1'})}),
  g('dG5','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdK1'})}),
  g('dG6','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdF1'})}),
  g('dG7','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdG1'})}),
  g('dG8','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdR1'})}),
  g('dG9','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdJ1'})}),
  g('dG10','TEDAVI_GUN','2026-09-26',{aciklama:JSON.stringify({day_id:'tdI1'})}),
  g('dS3','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sA3',parent_id:'p4'}),
  g('dS4','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sM1',parent_id:'p7'}),
  g('dS5','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sN1',parent_id:'p10'}),
  g('dS6','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sK1',parent_id:'p12'}),
  g('dS7','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sF1',parent_id:'p5'}),
  g('dS8','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sG1',parent_id:'p14'}),
  g('dS9','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sR1',parent_id:'p8'}),
  g('dS10','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sJ1',parent_id:'p3'}),
  g('dS11','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sI1',parent_id:'p6'}),
  // 09-27
  g('dS17','TEDAVI_SEANS','2026-09-27',{seans_admin_id:'sA4',parent_id:'p17'}),
  g('dT1','TOHUMLAMA_PLANLI','2026-09-27'),   // 208 TAI (PG_TOHUMLAMA)
  // 09-28
  g('dT2','TOHUMLAMA_PLANLI','2026-09-28'),   // 002 TAI (şablon TAI)
  // 10-02 pencere ucu
  g('dS18','TEDAVI_SEANS','2026-10-02',{seans_admin_id:'sB2',parent_id:'p18'}),
  // KARŞI-ÖRNEKLER (Üreme'de OLMAMALI):
  g('xMet','TEDAVI_SEANS','2026-09-25',{seans_admin_id:'sMet',parent_id:'px1'}),   // Metrit bugün → Tedavi
  g('xMast','TEDAVI_SEANS','2026-09-26',{seans_admin_id:'sMast',parent_id:'px2'}), // Mastit → Tedavi
  g('xUzak','OVSYNC_BASLAT','2026-12-29'),                                        // pencere dışı
  g('xBitti','TOHUMLAMA_PLANLI','2026-09-26',{tamamlandi:true}),                   // tamamlanmış → top-level elemede düşer
];

test('C3-6 SAYI KANITI: demo türevli fixture — Bugün+Üreme = 25 (SQL eşit)', () => {
  const uremeCaseIdler=_uremeVakaCaseIds(D_CASES);
  // 1) top-level eleme (loadTasks:762 eşdeğeri)
  const doneIds=new Set(D_GOREVLER.filter(t=>t.tamamlandi).map(t=>t.id));
  let data=D_GOREVLER.filter(t=>!t.tamamlandi&&!t.iptal&&(t.gorev_tipi==='TEDAVI_SEANS'||!t.parent_id||doneIds.has(t.parent_id)));
  // 2) Bugün penceresi + C3 üreme genişletmesi (loadTasks today kolu eşdeğeri)
  const today='2026-09-25', d7='2026-10-02';
  data=data.filter(t=>_bugunFiltreUygun(t,today,d7)
    ||(_kategoriFiltreUygun(t,'ureme',uremeCaseIdler,D_tdById,D_seansById)&&t.hedef_tarih>today&&t.hedef_tarih<=d7));
  // 3) kategori
  data=data.filter(t=>_kategoriFiltreUygun(t,'ureme',uremeCaseIdler,D_tdById,D_seansById));
  assert.strictEqual(data.length, 25,
    'demo SQL sayısı (25) = UI zinciri sayısı — BUGS kabul ölçütü');
  // karşı-örnekler listede yok:
  const ids=new Set(data.map(t=>t.id));
  assert.ok(!ids.has('xMet')&&!ids.has('xMast'), 'tedavi seansları sızmadı');
  assert.ok(!ids.has('xUzak'), 'pencere dışı üreme yok');
});

test('C3-7: aynı (hayvan,tarih) iki seans günü TEK gruba iner (mükerrer)', () => {
  // loadTasks grup anahtarı kaynak-kilitli (C3-4). Burada davranış eşdeğeri:
  // aynı hayvan + aynı hedef tarihli TEDAVI_SEANS görevleri tek ayraca düşer.
  const src=require('fs').readFileSync('js/ui.js','utf8');
  const lt=src.slice(src.indexOf('async function loadTasks'), src.indexOf('function _stokAdi'));
  assert.ok(lt.includes('gunNoSet'), 'birleşik gün etiketi seti (C3)');
  assert.ok(lt.includes('g.seansTotal=g.items.length'), 'ayraç ilerlemesi görünen görevlerden sayılır (C3)');
});
