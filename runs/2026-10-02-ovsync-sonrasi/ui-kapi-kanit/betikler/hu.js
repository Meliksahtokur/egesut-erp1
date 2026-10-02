// kullanım: node hu.js <etiket> <ad> <stokAdıParçası> [onayla]
const L=require('./lib'),F=require('./fx');
(async()=>{
 const [,,tag,ad,stokP,onay]=process.argv; const db=await L.db();
 const hid=`a1c00000-0000-4000-8000-${String({a:1,b:2,c:3,d:4}[ad]).padStart(12,'0')}`;
 const {data:g0}=await db.from('gorev_log').select('tamamlandi,iptal').eq('hayvan_id',hid); const {data:t0}=await db.from('tohumlama').select('sonuc').eq('hayvan_id',hid);
 const {count:u0}=await db.from('uygulama_log').select('id',{count:'exact',head:true}).eq('hayvan_id',hid);
 console.log('ÖN gorev',JSON.stringify(g0),'toh',JSON.stringify(t0),'uygulama_log',u0);
 const b=await L.browser(); const c=await L.ctx(b); const page=await c.newPage(); const log=[];
 page.on('console',m=>{ if(m.type()==='error') log.push('CONSOLE '+m.text())});
 await page.goto(L.BASE+'?demo',{waitUntil:'domcontentloaded'}); await page.waitForSelector('#pg-dash .sv',{timeout:45000});
 await page.waitForFunction(async id=>{ if(!window.idbGetAll) return false; const a=await window.idbGetAll('hayvanlar'); const s=await window.idbGetAll('stok'); return a.some(x=>x.id===id)&&s.length>0; },hid,{timeout:90000,polling:1000});
 if(stokP.startsWith('UIK')) await page.waitForFunction(async()=>{const s=await window.idbGetAll('stok');return s.some(x=>x.id==='UIK-STOK')},null,{timeout:60000,polling:1000});
 await page.waitForFunction(id=>!!getState('animals')?.some(a=>a.id===id),hid,{timeout:90000,polling:1000}).catch(()=>{}); await page.waitForTimeout(3000); console.log('animals state',await page.evaluate(id=>!!getState('animals')?.some(a=>a.id===id),hid)); await page.evaluate(id=>_hayvanHizliUygulama(id),hid).catch(e=>console.log('HU ERR',e.message)); await page.screenshot({path:L.KANIT+tag+'-pre.png'});
 await page.waitForSelector('#pu-stok');
 const val=await page.evaluate(p=>{const o=[...document.querySelectorAll('#pu-stok option')].find(x=>x.textContent.includes(p)); return o?o.value:null},stokP.replace('UIK','UIK Prostag').replace(/^UIK Prostag$/,'UIK Prostag'));
 if(!val){console.log('stok seçeneği yok');await b.close();process.exit(2)}
 await page.selectOption('#pu-stok',val); await page.waitForTimeout(500);
 const rpcs=[]; page.on('response',async r=>{ if(r.url().includes('/rpc/hizli_uygulama')) rpcs.push(r.status()+' '+(await r.text().catch(()=>'')).slice(0,300)); });
 await page.click('#pu-kaydet-btn');
 await page.waitForSelector('#takip-acik-bs, #pg-kapi-bs, #toast.on, .toast',{timeout:20000}).catch(()=>{});
 await page.waitForTimeout(1500);
 const sheet=await page.evaluate(()=>{const e=document.querySelector('#takip-acik-bs')||document.querySelector('#pg-kapi-bs');return e?{id:e.id,text:e.innerText,html:e.innerHTML}:null});
 console.log(tag,'SHEET',JSON.stringify(sheet&&{id:sheet.id,text:sheet.text}));
 await page.screenshot({path:L.KANIT+tag+'-sheet.png'});
 require('fs').writeFileSync(L.KANIT+tag+'-sheet.html',sheet?sheet.html:'(sheet yok)');
 if(onay==='onayla' && sheet){
   await page.click('#takip-acik-onayla'); await page.waitForTimeout(4000);
   const toast=await page.evaluate(()=>document.querySelector('#toast')?.innerText);
   const stillOpen=await page.evaluate(()=>!!document.querySelector('#takip-acik-bs'));
   console.log(tag,'ONAY SONRASI toast=',toast,'sheetAçık=',stillOpen); await page.screenshot({path:L.KANIT+tag+'-onay-sonrasi.png'});
   const {count:u1}=await db.from('uygulama_log').select('id',{count:'exact',head:true}).eq('hayvan_id',hid);
   console.log(tag,'uygulama_log önce/sonra',u0,u1);
 }
 console.log(tag,'RPC',JSON.stringify(rpcs),'console',JSON.stringify(log));
 await b.close();
})().catch(e=>{console.log('ERR',e.message);process.exit(1)});
