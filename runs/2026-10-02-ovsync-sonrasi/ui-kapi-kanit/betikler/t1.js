const L=require('./lib');
(async()=>{
 const b=await L.browser(); const c=await b.newContext({viewport:{width:390,height:844},locale:'tr-TR'});
 const log=[]; const page=await c.newPage();
 page.on('console',m=>{ if(m.type()==='error'||m.type()==='warning') log.push('CONSOLE '+m.type()+': '+m.text())});
 page.on('response',async r=>{ if(r.url().includes('demo_sema_diff')){ const h=r.request().headers(); const a=(h['authorization']||'').slice(-12); log.push(`NET ${r.request().method()} ${r.status()} ${r.url()} auth=...${a} apikeyOnly=${!h['authorization']||h['authorization']===('Bearer '+(h['apikey']||''))}`);} else if(r.status()>=400) log.push(`NET ${r.status()} ${r.url().slice(0,120)}`)});
 await page.goto(L.BASE+'?demo',{waitUntil:'domcontentloaded'});
 await page.waitForSelector('#pg-dash .sv',{timeout:45000}).catch(e=>log.push('dash timeout'));
 await page.waitForTimeout(8000);
 await page.screenshot({path:L.KANIT+'T1-demo-acilis.png'});
 require('fs').writeFileSync(L.KANIT+'T1-log.txt',log.join('\n')||'(boş)');
 console.log(log.join('\n')||'(boş)'); await b.close();
})();
