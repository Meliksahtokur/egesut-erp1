const {boot}=require('./lib.cjs');
const K='/work/runs/2026-10-30-some-fixes/t7-kanit/';
const fs=require('fs'); const out={};
const AKTIF90='95016797-77fe-4448-9e03-ee3defb62a03', OLU90='H000156', AKTIF5638='456d7c6d-e1cf-4500-a325-7afe9be15260', OLU5638='H000159';
(async()=>{
const {browser,page,cons}=await boot();
await page.waitForFunction(()=>typeof getState==='function'&&getState('animals').length>100,null,{timeout:90000});
const shot=n=>page.screenshot({path:K+n+'.png'});
const R=async(t,f)=>{try{const r=await f();out[t]=r;console.log(t,JSON.stringify(r));}catch(e){out[t]={hata:e.message.split('\n')[0]};console.log(t,'HATA',out[t].hata);await shot(t+'-hata').catch(()=>{});}};
const loaded=async()=>{await page.waitForFunction(()=>{const n=document.getElementById('det-name'); return n&&n.textContent.trim()&&n.textContent.trim()!=='—';},null,{timeout:20000}); await page.waitForTimeout(800);};
const reset=async()=>{await page.evaluate(()=>{document.querySelectorAll('.mo.on').forEach(m=>m.classList.remove('on'));});};
// T6a
await R('T6a',async()=>{
  await page.click('#nb-suru'); await page.waitForTimeout(800);
  await page.fill('#srch','90'); await page.waitForTimeout(1000);
  const item=page.locator('#ac-srch > *, .ac-list > *, [id^="ac-"] > *').filter({hasText:'Süt İçenler'}).first();
  await item.click(); await loaded();
  const id=await page.evaluate(()=>_detOpenId); const nm=await page.textContent('#det-name'); const meta=await page.textContent('#det-meta');
  await shot('T6a-arama-90');
  return {detId:id,aktifMi:id===AKTIF90,name:nm.trim(),meta:meta.trim()};
});
// T6b
await R('T6b',async()=>{
  await page.evaluate(()=>{closeDet&&closeDet();}).catch(()=>{});
  await page.waitForTimeout(500);
  await page.click('#nb-suru'); await page.fill('#srch','5638'); await page.waitForTimeout(1000);
  await page.locator('[id^="ac-"] > *').filter({hasText:'5638'}).first().click(); await loaded(); await page.click('[data-action="tab-ureme"]'); await page.waitForTimeout(1500);
  const detId=await page.evaluate(()=>_detOpenId);
  const btn=page.locator('#det-scroll button[onclick^="openInsemSafe"]').first();
  const n=await btn.count(); if(!n) return {hata:'Tohumlama Ekle butonu yok', html:(await page.textContent('#det-scroll')).slice(0,300)};
  await btn.click(); await page.waitForTimeout(1500);
  const ic=await page.evaluate(()=>({h:globalThis._insemInterceptHayvan||null,on:document.getElementById('m-insem-intercept').classList.contains('on'),insemOn:document.getElementById('m-insem').classList.contains('on')}));
  await shot('T6b-tohumlama-detay');
  return {detId,...ic,aktifMi:ic.h&&ic.h.id===AKTIF5638};
});
await reset();
// T6c
await R('T6c',async()=>{
  await page.evaluate(()=>{closeDet();}); await page.waitForTimeout(600);
  await page.click('#nb-suru'); await page.waitForTimeout(500);
  await page.fill('#srch',''); await page.waitForTimeout(500);
  await page.click('[data-action="bt-toggle-mode"]'); await page.waitForTimeout(800);
  await page.locator('input[type=checkbox]').first().check({force:true}).catch(async()=>{await page.locator('.hcard, [class*=card]').first().click();});
  await page.waitForTimeout(500);
  await page.click('[data-action="bt-transfer"]'); await page.waitForTimeout(1200);
  await page.click('[data-action="bt-tab-serbest"]'); await page.waitForTimeout(500);
  await page.fill('#bt-serbest-input','5638');
  await page.click('button[onclick="btSerbestYukle()"]'); await page.waitForTimeout(800);
  const r=await page.evaluate(()=>({ids:[..._btModalSecilenIds],sonuc:document.getElementById('bt-serbest-sonuc').textContent}));
  await shot('T6c-toplu-tedavi-yapistir');
  return {...r,aktifVar:r.ids.includes(AKTIF5638),oluVar:r.ids.includes(OLU5638)};
});
console.log('KONSOL',JSON.stringify(cons.slice(0,15)));
fs.writeFileSync('/t7/ust-res.json',JSON.stringify(out));
await browser.close();
})();
