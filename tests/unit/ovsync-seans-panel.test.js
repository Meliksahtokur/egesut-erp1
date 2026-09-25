// tests/unit/ovsync-seans-panel.test.js — K8: ovsync seans uyarıları panel/rozet/bildirim (BUG-PROTOKOL-OVSYNC-AYRIK)
'use strict';
process.env.TZ = 'Europe/Istanbul';   // K8-5 saat matematiği deterministik — dosya başında, hiçbir Date kullanımından önce (node --test dosya başına süreç açar)
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const { loadExtractedFunction } = require('./support/loadModule.js');

const _rozetTopla=loadExtractedFunction('js/ui.js','_rozetTopla');
const _dkInsanOkur=loadExtractedFunction('js/ui.js','_dkInsanOkur');
const _ovSeansBolumHtml=loadExtractedFunction('js/ui.js','_ovSeansBolumHtml',{extra:{
  esc:s=>String(s), escAttr:s=>String(s), fmtTarih:s=>String(s),
  _ovSeansSatirHtml:u=>`SATIR:${u.kupe_no}:${u.durum}`,
}});

test('K8-1: _rozetTopla 3 kaynak toplar; 2-arg geriye uyumlu', () => {
  assert.strictEqual(_rozetTopla(3,2,4), 9);
  assert.strictEqual(_rozetTopla(3,2,undefined), 5);
  assert.strictEqual(_rozetTopla(0,0,0), 0);
});

test('K8-2: _dkInsanOkur — dakika → insan okuru gecikme metni', () => {
  assert.strictEqual(_dkInsanOkur(1236), '20sa 36dk');   // sahibin dökümü: "20sa 36dk gecikti"
  assert.strictEqual(_dkInsanOkur(30), '30dk');
  assert.strictEqual(_dkInsanOkur(1560), '1g 2sa');
  assert.strictEqual(_dkInsanOkur(0), '0dk');
});

test('K8-3: bölüm — boş liste boş string; 8 gecikmiş Buserin seansı görünür', () => {
  assert.strictEqual(_ovSeansBolumHtml([]), '');
  assert.strictEqual(_ovSeansBolumHtml(null), '');
  const fixture=Array.from({length:8},(_,i)=>({gorev_id:'g'+i,hayvan_id:'h'+i,kupe_no:String(28+i),grup:'Düve (Büyük)',
    hedef_tarih:'2026-09-24',hedef_saat:'10:00',durum:'gecikmis',gun_no:1,toplam_gun:4,gecikme_dk:1236}));
  const html=_ovSeansBolumHtml(fixture);
  assert.ok(html.includes('Ovsync Seansları (8)'), 'başlık + sayı');
  assert.ok(html.includes('8 gecikmiş')||/gecikmis.*8|8.*gecikmiş/s.test(html), 'gecikmiş alt başlığı');
  assert.strictEqual((html.match(/SATIR:/g)||[]).length, 8, '8 satır');
});

test('K8-4: rozet + panel kablolaması (kaynak kanıtı)', () => {
  const src=fs.readFileSync('js/ui.js','utf8');
  assert.ok(src.includes("_rozetTopla(aktif.length, ovSayi, seansSayi)"), 'rozet 3. kaynağı toplar');
  const scan=src.slice(src.indexOf('// Protokol uyarı scanner'), src.indexOf('updateTaskBadge();', src.indexOf('// Protokol uyarı scanner')));
  assert.ok(scan.includes("rpc('ovsync_seans_uyarilari'"), 'rozet taraması seans RPC sorgular');
  const panel=src.slice(src.indexOf('async function _showProtokolEkran'), src.indexOf('function _showProtokolDetay'));
  assert.ok(panel.includes('_ovSeansBolumHtml('), 'panel bölüm üreticisini çağırır');
  assert.ok(/if\s*\(!data\.length\s*&&\s*!ovHtml\s*&&\s*!seansHtml\)/.test(panel), 'boş-durum üç kaynakla karar verir');
  assert.ok(panel.includes('${seansHtml}'), 'bölüm HTML içeriğe gömülü');
});

test('K8-5: bildirimKontrol — gecikmiş seans bildirir, hedef_saat okur, dedup çalışır', async () => {
  const { loadBrowserModule } = require('./support/loadModule.js');
  const vm=require('node:vm');
  const src=require('./support/loadModule.js').extractFunctionSource('js/ui.js','bildirimKontrol');
  const bildirimler=[];
  class FakeNotif{ constructor(title,opts){ bildirimler.push({title,tag:opts&&opts.tag,body:opts&&opts.body}); } }
  FakeNotif.permission='granted';
  const storage=(()=>{ const m=new Map(); return {getItem:k=>m.get(k)??null,setItem:(k,v)=>m.set(k,String(v)),removeItem:k=>m.delete(k)}; })();
  class FixedDate extends Date { constructor(...a){ if(a.length===0) super('2026-09-25T09:30:00+03:00'); else super(...a); } }
  const gorevler=[
    {id:'gSeans', hayvan_id:'h1', gorev_tipi:'TEDAVI_SEANS', parent_id:'gP', tamamlandi:false,
     hedef_tarih:'2026-09-24', hedef_saat:'10:00:00', aciklama:'Gün 1/4 Buserin'},          // gecikmiş (dün 10:00)
    {id:'gBugun', hayvan_id:'h1', gorev_tipi:'TEDAVI_SEANS', parent_id:'gP2', tamamlandi:false,
     hedef_tarih:'2026-09-25', hedef_saat:'12:30:00', aciklama:'öğle seansı'},              // 3 saat sonra → erken uyarı (hedef_saat!)
    {id:'gJson', hayvan_id:'h1', gorev_tipi:'TEDAVI_SEANS', parent_id:'gP3', tamamlandi:false,
     hedef_tarih:'2026-09-24', hedef_saat:'11:00:00',                                       // gecikmiş + JSON açıklama (F4/K8)
     aciklama:JSON.stringify({label:'Gun 2 - Seans (08:00)', day_id:'da9e87c3-0f56-4775-aee9-7140aadd55bb', admin_id:'9b2c1a69-332b-49b0-a96b-5c4103847280', planned_time:'08:00'})},
  ];
  const ctx={ console, Date:FixedDate, Math, JSON, Map, Set, Promise, Number,
    Notification:FakeNotif, window:{ Notification:FakeNotif },
    bugun:()=>'2026-09-25', dFwd:(b,n)=>n===1?'2026-09-26':b,
    getData:async(table,fn)=>gorevler.filter(fn),
    getState:(k)=>k==='animals' ? [{id:'h1',kupe_no:'28'}] : undefined,
    localStorage:storage, _istanbulAnIso:null };
  vm.createContext(ctx);
  const bk=vm.runInContext(`(${src})`, ctx, { filename:'js/ui.js#bildirimKontrol' });
  await bk();
  const tags=bildirimler.map(b=>b.tag);
  assert.ok(tags.some(t=>String(t).startsWith('gSeans_gecik_2026-09-25')), 'gecikmiş seans bildirimi + günlük dedup anahtarı');
  assert.ok(bildirimler.some(b=>String(b.tag)==='gBugun_2026-09-25'), '3-saat-erken penceresi hedef_saat=12:30 üzerinden (08:00 sabiti değil)');
  // F4/K8: JSON açıklamalı seans — gövde ham JSON değil label; düz metin olduğu gibi kalır
  const bj=bildirimler.find(b=>String(b.tag)==='gJson_gecik_2026-09-25');
  assert.ok(bj, 'JSON açıklamalı seans gecikmiş kolunda bildirilir');
  assert.strictEqual(bj.body, 'Gun 2 - Seans (08:00)', 'gövde JSON\'ın label alanı olmalı (F4/K8)');
  assert.ok(!String(bj.body).includes('"day_id"'), 'gövde çiğ JSON basmaz');
  const bs=bildirimler.find(b=>String(b.tag)==='gSeans_gecik_2026-09-25');
  assert.strictEqual(bs.body, 'Gün 1/4 Buserin', 'düz metin açıklama değişmeden kalır');
  const n1=bildirimler.length;
  await bk();   // ikinci koşum (saatlik interval)
  assert.strictEqual(bildirimler.length, n1, 'dedup — tekrar bildirim yok');
});
