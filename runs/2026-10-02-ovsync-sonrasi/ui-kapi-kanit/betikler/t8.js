const L=require('./lib'),F=require('./fx');
const E='a1c00000-0000-4000-8000-000000000005', CASE='a0ae8f13-ee10-4556-adb8-886f338c7741';
const SEANS={bekliyor:'7efe5d36-ea4f-4294-9eff-590f361d7600',gebe:'7efe5d36-ea4f-4294-9eff-590f361d7600',katalog:'7d660f1d-0c6b-4caa-8cad-825fb9588700'};
(async()=>{ const [,,tag,varyant]=process.argv; const db=await L.db();
 // fixture: tohumlama + açık takip
 await db.from('tohumlama').delete().eq('hayvan_id',E); await db.from('gorev_log').delete().eq('hayvan_id',E).eq('gorev_tipi','TAKIP_MUAYENE');
 const sonuc=varyant==='gebe'?'Gebe':(varyant==='katalog'?'Boş':'Bekliyor');
 let r=await db.from('tohumlama').insert({id:'a1c00000-0000-4000-8000-000000000105',hayvan_id:E,tarih:F.trGun(0),sonuc,deneme_sayisi:1,denemeler:[]}); if(r.error) throw new Error('toh '+r.error.message);
 r=await db.from('gorev_log').insert({id:'a1c00000-0000-4000-8000-000000000215',hayvan_id:E,gorev_tipi:'TAKIP_MUAYENE',aciklama:'UIK-e',hedef_tarih:F.trGun(7),hedef_saat:'09:00:00',tamamlandi:false,iptal:false,kaynak:'TAKIP:UIKe'}); if(r.error) throw new Error('gorev '+r.error.message);
 // stok eşlemesi: katalog varyantı için seans stoğu UIK-STOK (katalog bağsız)
 const stokHedef=varyant==='katalog'?'UIK-STOK':'86bb424c-a517-45b7-94f9-6fce2beb98e8';
 r=await db.from('treatment_day_uygulamalar').update({stok_id:stokHedef}).eq('id',SEANS[varyant]).select('id,stok_id'); console.log('seans stok',JSON.stringify(r.data),r.error&&r.error.message);
 const {data:g0}=await db.from('gorev_log').select('id,tamamlandi,iptal').eq('hayvan_id',E).eq('gorev_tipi','TAKIP_MUAYENE'); console.log('ÖN takip',JSON.stringify(g0),'sonuc',sonuc);
 const sid=SEANS[varyant];
 const b=await L.browser(); const c=await L.ctx(b); const page=await c.newPage(); const log=[];
 page.on('console',m=>{ if(m.type()==='error') log.push(m.text())});
 await page.goto(L.BASE+'?demo',{waitUntil:'domcontentloaded'}); await page.waitForSelector('#pg-dash .sv',{timeout:45000});
 await page.waitForFunction(async id=>{const a=await idbGetAll('treatment_day_uygulamalar');const t=await idbGetAll('gorev_log');return a.some(x=>x.id===id&&true)},sid,{timeout:90000,polling:1000});
 await page.waitForFunction(id=>!!getState('animals')?.some(a=>a.id===id),E,{timeout:90000,polling:1000}).catch(()=>{}); await page.waitForTimeout(3000);
 // UI: vaka detayı → seans satırındaki GERÇEK "✓ Uygulandı" butonu
 await page.evaluate(id=>openCaseDet(id),CASE); await page.waitForTimeout(3000);
 const btn=page.locator(`button[onclick*="seansTamamla('${sid}',false"]`).first();
 const var_=await btn.count(); console.log(tag,'seans butonu bulundu:',var_);
 if(var_){ await btn.scrollIntoViewIfNeeded(); await btn.click(); } else { console.log('buton yok → seansTamamla doğrudan'); await page.evaluate(id=>seansTamamla(id,false,null),sid); }
 await page.waitForSelector('#takip-acik-bs, #pg-kapi-bs',{timeout:20000}).catch(()=>{}); await page.waitForTimeout(1500);
 const sh=await page.evaluate(()=>{const e=document.querySelector('#takip-acik-bs')||document.querySelector('#pg-kapi-bs');return e?{id:e.id,text:e.innerText}:null});
 console.log(tag,'SHEET',JSON.stringify(sh)); await page.screenshot({path:L.KANIT+tag+'-sheet.png'});
 if(varyant==='gebe'&&sh){ await page.click('#takip-acik-onayla'); await page.waitForTimeout(4000); console.log(tag,'ONAY toast=',await page.evaluate(()=>document.querySelector('#toast')?.innerText)); const {data:da}=await db.from('treatment_day_uygulamalar').select('uygulama_tamamlandi_at').eq('id',sid); console.log(tag,'seans tamamlandi_at',JSON.stringify(da)); await page.screenshot({path:L.KANIT+tag+'-onay.png'}); }
 console.log(tag,'console',JSON.stringify(log)); await b.close();
})().catch(e=>{console.log('ERR',e.message);process.exit(1)});
