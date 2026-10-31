const {boot}=require('./lib.cjs');
const K='/work/runs/2026-10-30-some-fixes/t7-kanit/';
const OLU511='b9b7c132-fc10-4439-9a86-c1d7212c5d2b';
(async()=>{
const {browser,page,cons}=await boot();
await page.waitForFunction(()=>typeof getState==='function'&&getState('animals').length>100,null,{timeout:90000});
const shot=n=>page.screenshot({path:K+n+'.png'});
const loaded=async()=>{await page.waitForFunction(()=>{const n=document.getElementById('det-name'); return n&&n.textContent.trim()&&n.textContent.trim()!=='—';},null,{timeout:20000}); await page.waitForTimeout(800);};
await page.click('#nb-ureme'); await page.waitForTimeout(500); await page.click('#ureme-tab-dogum'); await page.waitForTimeout(1200);
await page.locator('b[data-det="'+OLU511+'"]').first().click(); await loaded();
// T8-a: dogrudan tikla (calisma yolu)
await page.click('#det-scroll button[onclick^="openAnimalEdit"]'); await page.waitForTimeout(1200);
const t1=(await page.textContent('#toast')).trim(); const c1=await page.evaluate(()=>document.getElementById('toast').className+'|modal:'+document.getElementById('m-animal').classList.contains('on'));
console.log('T8a',JSON.stringify({toast:t1,cls:c1,stateDeadVar:await page.evaluate(()=>getState('animals').some(a=>a.id==='b9b7c132-fc10-4439-9a86-c1d7212c5d2b'))}));
await shot('T8a-dogrudan-tikla');
// T8-b: istemci kapisini asmak icin olu hayvan state'e eklenir (yalniz DB yolunu olcmek icin)
await page.evaluate(async(id)=>{const all=await idbGetAll('hayvanlar'); const d=all.find(a=>a.id===id); setState('animals',[...getState('animals'),d]);},OLU511);
await page.waitForTimeout(3500);
await page.click('#det-scroll button[onclick^="openAnimalEdit"]'); await page.waitForTimeout(1500);
const open=await page.evaluate(()=>document.getElementById('m-animal').classList.contains('on'));
const kupeVal=await page.inputValue('#a-kupe').catch(()=>null);
await shot('T8b-0-form');
await page.fill('#a-ozellik','T7 test notu');
await page.press('#a-kupe','Tab').catch(()=>{}); await page.waitForTimeout(1500);
const warn=(await page.textContent('#a-kupe-warn')).trim();
await page.click('[data-action="submit-animal"]'); await page.waitForTimeout(3500);
const t2=(await page.textContent('#toast')).trim(); const c2=await page.evaluate(()=>document.getElementById('toast').className+'|modal:'+document.getElementById('m-animal').classList.contains('on'));
await shot('T8b-sonuc');
console.log('T8b',JSON.stringify({open,kupeVal,warn,toast:t2,cls:c2}));
console.log('KONSOL',JSON.stringify(cons.slice(0,10)));
await browser.close();
})();
