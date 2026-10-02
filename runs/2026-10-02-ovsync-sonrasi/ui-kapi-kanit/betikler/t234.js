const L=require('./lib');
(async()=>{
 const b=await L.browser(); const c=await L.ctx(b); const page=await c.newPage();
 const out=[]; const P=(s)=>{out.push(s);console.log(s)};
 page.on('console',m=>{ if(m.type()==='error') P('CONSOLE error: '+m.text())});
 await page.goto(L.BASE+'?demo',{waitUntil:'domcontentloaded'});
 await page.waitForSelector('#pg-dash .sv',{timeout:45000});
 await page.waitForTimeout(5000);
 const rootTxt=async()=>page.evaluate(()=>{const r=document.querySelector('#ovsync-root');return r?{html:r.innerText.slice(0,500),loader:r.querySelectorAll('.loader').length,hata:/Yerel veri okunamad/.test(r.innerText),btn:[...r.querySelectorAll('button')].map(x=>x.innerText).filter(t=>/Tekrar/.test(t))}:null});
 // T2
 await page.locator('.dash-row .sc',{hasText:'Ovsync'}).click();
 await page.waitForSelector('#pg-ovsync.on');
 await page.waitForFunction(()=>document.querySelectorAll('#ovsync-root .loader').length===0 && document.querySelector('#ovsync-root').innerText.length>50,null,{timeout:45000});
 await page.waitForTimeout(1500);
 const r2=await rootTxt(); P('T2 '+JSON.stringify(r2)); await page.screenshot({path:L.KANIT+'T2-normal.png'});
 // T3: override getData
 const ov=await page.evaluate(()=>{ window.__orig=window.getData; window.getData=()=>new Promise(()=>{}); return typeof window.__orig; });
 P('getData tipi (override öncesi): '+ov);
 const t0=Date.now();
 await page.evaluate(()=>{ loadOvsyncDash(); });
 await page.waitForTimeout(2000);
 P('T3 t+2s '+JSON.stringify(await rootTxt())); await page.screenshot({path:L.KANIT+'T3-spinner-2s.png'});
 await page.waitForFunction(()=>/Yerel veri okunamad/.test(document.querySelector('#ovsync-root').innerText),null,{timeout:25000});
 P('T3 hata görünme süresi ~'+((Date.now()-t0)/1000).toFixed(1)+' sn');
 const r3=await rootTxt(); P('T3 '+JSON.stringify(r3)); await page.screenshot({path:L.KANIT+'T3-hata.png'});
 // T4
 await page.evaluate(()=>{ window.getData=window.__orig; });
 await page.locator('#ovsync-root button',{hasText:'Tekrar Dene'}).click();
 await page.waitForFunction(()=>document.querySelectorAll('#ovsync-root .loader').length===0 && !/Yerel veri okunamad/.test(document.querySelector('#ovsync-root').innerText) && document.querySelector('#ovsync-root').innerText.length>50,null,{timeout:45000});
 await page.waitForTimeout(1500);
 const r4=await rootTxt(); P('T4 '+JSON.stringify(r4)); await page.screenshot({path:L.KANIT+'T4-tekrar-dene.png'});
 require('fs').writeFileSync(L.KANIT+'T2-T4-log.txt',out.join('\n')); await b.close();
})().catch(e=>{console.log('ERR',e.message);process.exit(1)});
