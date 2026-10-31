const {boot}=require('./lib.cjs');
const K='/work/runs/2026-10-30-some-fixes/t7-kanit/';
const fs=require('fs');
const res=[];
(async()=>{
const {browser,page,cons}=await boot();
await page.waitForFunction(()=>typeof getState==='function'&&getState('animals').length>100,null,{timeout:90000});
const shot=n=>page.screenshot({path:K+n+'.png'});
async function dogum(tag,anneKupe,cins,kupe,kg='38'){
  const bypass=tag==='T5B';
  await page.click('#nb-ureme'); await page.waitForTimeout(500);
  await page.click('#ureme-tab-dogum'); await page.waitForTimeout(800);
  await page.click('[data-action="open-birth-modal"]');
  await page.waitForSelector('#m-birth.on',{timeout:5000}).catch(()=>{});
  await page.click('[data-action="birth-manual"] >> nth=1').catch(async()=>{await page.click('text=Manuel Gir')});
  await page.fill('#b-anne',anneKupe);
  await page.waitForSelector('#ac-banne >> text='+anneKupe,{timeout:5000});
  await page.locator('#ac-banne > *').filter({hasText:anneKupe}).first().click();
  await page.waitForTimeout(300);
  await page.fill('#b-tarih','2026-10-31');
  await page.selectOption('#b-cins',cins);
  await page.fill('#b-kupe',kupe);
  await page.fill('#b-dogum-kg',kg);
  await page.press('#b-kupe','Tab');
  await page.waitForTimeout(1500);
  const warn=await page.textContent('#b-kupe-warn');
  if(bypass){ await page.evaluate(()=>{const w=document.getElementById('b-kupe-warn'); w.textContent=''; delete w.dataset.soft;}); }
  await shot(tag+'-form');
  await page.click('[data-action="submit-birth"]');
  await page.waitForTimeout(3500);
  const toast=(await page.textContent('#toast')).trim(); const toastErr=await page.evaluate(()=>document.getElementById('toast').className);
  const modalOpen=await page.evaluate(()=>document.getElementById('m-birth').classList.contains('on'));
  await shot(tag+'-sonuc');
  return {warn,toast,toastErr,modalOpen};
}
const run=async(tag,...a)=>{ try{ const r=await dogum(tag,...a); console.log(tag,JSON.stringify(r)); res.push({tag,...r}); }catch(e){console.log(tag,'HATA',e.message.split('\n')[0]); res.push({tag,hata:e.message.split('\n')[0]}); await shot(tag+'-hata'); await page.evaluate(()=>{document.querySelectorAll('.mo.on').forEach(m=>m.classList.remove('on'))}); } };
const only=process.argv[2]||'all'; const X=(process.argv[3]||'').split(',');
if(only==='all'||only==='T1') await run('T1','175','Erkek','511');
if(only==='all'||only==='T2') await run('T2','154','Dişi','9102');
if(only==='all'||only==='T3') await run('T3','181','Dişi','90');
if(only==='all'||only==='T4') await run('T4','153','Dişi','37');
if(only==='all'||only==='T5') await run('T5','191','Dişi','156');
if(only==='T5B') await run('T5B','191','Dişi','156');
if(only==='T6X') await run('T6X','178','Dişi','9103');
if(only==='T7P') await run('T7P','163','Erkek','511');
console.log('KONSOL',JSON.stringify(cons.slice(0,15)));
fs.writeFileSync('/t7/dogum-res.json',JSON.stringify(res));
await browser.close();
})();
