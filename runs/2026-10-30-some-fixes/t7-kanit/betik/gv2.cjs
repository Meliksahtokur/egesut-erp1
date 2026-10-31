const {boot}=require('./lib.cjs');
const K='/work/runs/2026-10-30-some-fixes/t7-kanit/';
(async()=>{
const {browser,page,cons}=await boot();
await page.waitForFunction(()=>typeof getState==='function'&&getState('animals').length>100,null,{timeout:90000});
const shot=n=>page.screenshot({path:K+n+'.png'});
const bell=async()=>{ await page.click('#bellbtn'); await page.waitForTimeout(3500);
  return page.evaluate(()=>[...document.querySelectorAll('.arow[data-p]')].filter(r=>r.innerText.includes('905')).map(r=>r.innerText.replace(/\s+/g,' ').trim().slice(0,70))); };
const closeBell=async()=>{ await page.mouse.click(190,30); await page.waitForTimeout(800); };
const gorevBul=async()=>{ await page.click('#nb-tasks'); await page.waitForTimeout(1500);
  await page.locator('#pg-tasks button').filter({hasText:/geciken/i}).first().click(); await page.waitForTimeout(1200);
  await page.locator('#pg-tasks input').first().fill('905'); await page.waitForTimeout(1200);
  return page.evaluate(()=>[...document.querySelectorAll('#pg-tasks button')].map(b=>(b.getAttribute('onclick')||'').match(/'gorev','([0-9a-f]{8})/)?.[1]).filter(Boolean)); };
// T9
console.log('T9 once uyari',JSON.stringify(await bell())); await shot('T9-0-uyari-once'); await closeBell();
console.log('T9 once gorev',JSON.stringify(await gorevBul())); await shot('T9-1-gorev-once');
await page.locator('button.ck-btn[onclick*="8856d31c"]').first().click(); await page.waitForTimeout(2500);
const m=await page.evaluate(()=>({confirm:document.getElementById('m-confirm')?.classList.contains('on'),toast:document.getElementById('toast').textContent}));
console.log('T9 tikla sonrasi',JSON.stringify(m)); await shot('T9-2-tamamla-sonrasi');
if(m.confirm){ await page.locator('#m-confirm button').filter({hasText:/evet|tamam|onay|uygula/i}).first().click().catch(()=>{}); await page.waitForTimeout(2500); await shot('T9-2b'); }
console.log('T9 sonra gorev',JSON.stringify(await gorevBul()));
console.log('T9 sonra uyari',JSON.stringify(await bell())); await shot('T9-3-uyari-sonra'); 
// T10: ademin uygula
await page.locator('.arow[data-p]').filter({hasText:'905'}).filter({hasText:'Ademin'}).locator('button',{hasText:'Uygula'}).first().click(); await page.waitForTimeout(2000);
await shot('T10-0-uygula-modal');
const mini=await page.evaluate(()=>({var:!!document.getElementById('proto-mini'),stok:[...(document.getElementById('pu-stok')?.options||[])].map(o=>o.text),toast:document.getElementById('toast').textContent}));
console.log('T10 mini',JSON.stringify(mini));
if(mini.var&&mini.stok.length){ await page.click('#pu-kaydet-btn'); await page.waitForTimeout(4000); await shot('T10-1-kaydet-sonra');
  console.log('T10 toast',await page.evaluate(()=>document.getElementById('toast').textContent+'|'+document.getElementById('toast').className)); 
  await page.evaluate(()=>{document.getElementById('proto-mini')?.remove();});
  console.log('T10 uyari sonra',JSON.stringify(await page.evaluate(()=>[...document.querySelectorAll('.arow[data-p]')].filter(r=>r.innerText.includes('905')).map(r=>r.innerText.replace(/\s+/g,' ').trim().slice(0,70)))));
  await closeBell().catch(()=>{});
  console.log('T10 sonra gorev',JSON.stringify(await gorevBul())); await shot('T10-2-gorev-sonra');
}
console.log('KONSOL',JSON.stringify(cons.slice(0,10)));
await browser.close();
})();
