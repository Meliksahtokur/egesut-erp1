// tests/unit/gorev-kat-filtre.test.js — K7: Üreme sekmesi kategori/tarih filtresi (BUG-UREME-SEKMESI-FILTRE)
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, loadExtractedFunction } = require('./support/loadModule.js');

// F4/K7: sabitler js/ui.js KAYNAĞINDAN çıkar — fixture kopyası gerçek haritayı gölgeliyordu
// (gerçek _katTipMap.ureme bozulsa bile bu testler geçiyordu). expose kalıbı: const'lar vm
// lexical scope'unda kaldığı için ikinci script ile dışarı alınır (loadModule.js dokümanı).
const _uiExposed = loadBrowserModule('js/ui.js', {
  extra: { esc:s=>String(s), escAttr:s=>String(s), fmtTarih:s=>String(s) },
  expose: ['_katTipMap', '_allKatTips', '_planliUremeTipler'],
}).exposed;
const _katTipMap = _uiExposed._katTipMap;
const _allKatTips = _uiExposed._allKatTips;
const _planliUremeTipler = _uiExposed._planliUremeTipler;
const ortak = { _katTipMap, _allKatTips, _planliUremeTipler };

// fixture: bir Ovsync (Üreme) vakası + bir Mastit (Meme) vakası
const diseases=[
  {id:'dOv', name:'Ovsync Protokol', category:'Üreme'},
  {id:'dMast', name:'Mastit', category:'Meme'},
];
const cases=[ {id:'cOv', disease_id:'dOv', status:'active'}, {id:'cMast', disease_id:'dMast', status:'active'} ];
const tdays=[ {id:'tdOv', case_id:'cOv', day_no:1}, {id:'tdMast', case_id:'cMast', day_no:1} ];
const seanslar=[ {id:'sOv', treatment_day_id:'tdOv'}, {id:'sMast', treatment_day_id:'tdMast'} ];
const tdById=Object.fromEntries(tdays.map(x=>[x.id,x]));
const seansById=Object.fromEntries(seanslar.map(x=>[x.id,x]));
const gSeansOv={id:'gS1', gorev_tipi:'TEDAVI_SEANS', seans_admin_id:'sOv', parent_id:'gP1', hedef_tarih:'2026-09-25', tamamlandi:false, iptal:false};
const gGunOv={id:'gG1', gorev_tipi:'TEDAVI_GUN', parent_id:null, hedef_tarih:'2026-09-25', aciklama:JSON.stringify({day_id:'tdOv'}), tamamlandi:false, iptal:false};
const gSeansMast={id:'gS2', gorev_tipi:'TEDAVI_SEANS', seans_admin_id:'sMast', parent_id:'gP2', hedef_tarih:'2026-09-25', tamamlandi:false, iptal:false};

const _uremeVakaCaseIds=loadExtractedFunction('js/ui.js','_uremeVakaCaseIds',{extra:ortak});
const _uremeGorevMi=loadExtractedFunction('js/ui.js','_uremeGorevMi',{extra:ortak});
// _kategoriFiltreUygun gövdesi _uremeGorevMi'yi çağırır — extract edilen vm ctx'ine
// bağımlı fonksiyon da geçirilmeli (loadModule extra kalıbı).
const ortakBagimli={ ...ortak, _uremeGorevMi };
const _kategoriFiltreUygun=loadExtractedFunction('js/ui.js','_kategoriFiltreUygun',{extra:ortakBagimli});
const _bugunFiltreUygun=loadExtractedFunction('js/ui.js','_bugunFiltreUygun',{extra:ortak});

test('K7-1: üreme vaka kümesi yalnız category=Üreme vakalarını toplar', () => {
  const s=_uremeVakaCaseIds(cases, diseases);
  assert.ok(s.has('cOv')&&!s.has('cMast'));
});

test('K7-2: ovsync seansı/günü Üreme\'de; Mastit seansı Tedavi\'de kalır (çift sayım yok)', () => {
  const uremeCaseIdler=new Set(['cOv']);
  assert.strictEqual(_uremeGorevMi(gSeansOv, uremeCaseIdler, tdById, seansById), true, 'ovsync seansı üreme');
  assert.strictEqual(_uremeGorevMi(gGunOv, uremeCaseIdler, tdById, seansById), true, 'ovsync tedavi günü üreme');
  assert.strictEqual(_uremeGorevMi(gSeansMast, uremeCaseIdler, tdById, seansById), false, 'mastit seansı üreme değil');
  assert.strictEqual(_kategoriFiltreUygun(gSeansOv,'ureme',uremeCaseIdler,tdById,seansById), true);
  assert.strictEqual(_kategoriFiltreUygun(gSeansOv,'tedavi',uremeCaseIdler,tdById,seansById), false, 'Tedavi sekmesi ovsync seansını ÇİFT SAYMAZ');
  assert.strictEqual(_kategoriFiltreUygun(gSeansMast,'tedavi',uremeCaseIdler,tdById,seansById), true, 'mastit Tedavi\'de kalır');
  assert.strictEqual(_kategoriFiltreUygun({gorev_tipi:'OVSYNC_BASLAT'},'ureme',uremeCaseIdler,tdById,seansById), true);
});

test('K7-3: yaklaşan planlı üreme görevi Bugün penceresinde (ASI_PLANLI benzeri istisna)', () => {
  const today='2026-09-25', d7='2026-10-02';
  const baslat={gorev_tipi:'OVSYNC_BASLAT', hedef_tarih:'2026-09-28'};
  const planli={gorev_tipi:'TOHUMLAMA_PLANLI', hedef_tarih:'2026-10-02'};
  const uzak={gorev_tipi:'OVSYNC_BASLAT', hedef_tarih:'2026-10-06'};
  assert.strictEqual(_bugunFiltreUygun(baslat,today,d7), true, 'OVSYNC_BASLAT +3g Bugün\'de görünür');
  assert.strictEqual(_bugunFiltreUygun(planli,today,d7), true, 'pencere sınırı dahil');
  assert.strictEqual(_bugunFiltreUygun(uzak,today,d7), false, '7 günden öte Bugün\'de değil');
  assert.strictEqual(_bugunFiltreUygun({gorev_tipi:'TEDAVI_GUN',hedef_tarih:'2026-09-28'},today,d7), false, 'istisna yalnız planlı üreme+ASI tiplerine');
  assert.strictEqual(_bugunFiltreUygun({gorev_tipi:'ASI_PLANLI',hedef_tarih:'2026-09-28'},today,d7), true, 'mevcut ASI davranışı korunur');
});

test('K7-4: loadTasks kablolaması — yardımcılar çağrılıyor (kaynak kanıtı)', () => {
  const src=require('fs').readFileSync('js/ui.js','utf8');
  // loadTasks'ten sonraki ilk üst-seviye fonksiyon _stokAdi'dir; recoverPendingDone ÖNCEDİR, çapa olmaz
  const lt=src.slice(src.indexOf('async function loadTasks'), src.indexOf('function _stokAdi'));
  assert.ok(lt.includes('_bugunFiltreUygun(t,today,_d7)'), 'today süzgeci yardımcıdan');
  assert.ok((lt.match(/_kategoriFiltreUygun\(/g)||[]).length>=2, 'açık + done kategori süzgeçleri yardımcıdan');
  const ixHarita=lt.indexOf('_uremeVakaCaseIds(');
  const ixFiltre=lt.indexOf('_kategoriFiltreUygun(');
  assert.ok(ixHarita>-1&&ixFiltre>-1&&ixHarita<ixFiltre, 'üreme vaka kümesi süzgeçlerden ÖNCE kurulmalı');
});

// F4/K7: gerçek harita içeriğini kilitle — yukarıdaki sabitler js/ui.js kaynağından geldiği
// için bu assertion'lar kaynaktaki geri düşüşü (ör. TOHUMLAMA_PLANLI silinmesi) yakalar.
test('K7-5: gerçek _katTipMap/_planliUremeTipler içeriği kilitli (kaynak-sabitleri, fixture değil)', () => {
  assert.ok(Array.isArray(_katTipMap.ureme) && _katTipMap.ureme.includes('TOHUMLAMA_PLANLI')
    && _katTipMap.ureme.includes('OVSYNC_BASLAT'), 'üreme listesi planlı üreme tiplerini içerir');
  assert.ok(Array.isArray(_katTipMap.tedavi) && _katTipMap.tedavi.includes('TEDAVI_SEANS')
    && _katTipMap.tedavi.includes('TEDAVI_GUN'), 'tedavi listesi seans/gün tiplerini içerir');
  assert.deepStrictEqual([..._planliUremeTipler].sort(), ['OVSYNC_BASLAT','TOHUMLAMA_PLANLI'],
    '_planliUremeTipler tam olarak bu iki tip');
  assert.ok(_allKatTips.includes('TEDAVI_SEANS') && _allKatTips.includes('OVSYNC_BASLAT')
    && _allKatTips.includes('ASI_PLANLI'), '_allKatTips türetilmiş liste ipuçlarını taşır');
});
