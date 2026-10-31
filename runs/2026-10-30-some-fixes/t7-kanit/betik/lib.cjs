const { chromium } = require('playwright');
const BASE='http://127.0.0.1:8137/';
async function boot(){
  const browser=await chromium.launch();
  const ctx=await browser.newContext({viewport:{width:390,height:844},locale:'tr-TR'});
  await ctx.addInitScript(()=>{localStorage.setItem('EGESUT_DEMO','1');localStorage.setItem('EGESUT_DEMO_POPUP_OFF','1');});
  const page=await ctx.newPage();
  const cons=[];
  page.on('console',m=>{ if(['error','warning'].includes(m.type())) cons.push(m.type()+': '+m.text()); });
  page.on('response',r=>{ if(r.status()>=400) cons.push('HTTP '+r.status()+' '+r.request().method()+' '+r.url().replace(/\?.*/,'').slice(-80)); });
  page.on('pageerror',e=>cons.push('pageerror: '+e.message));
  await page.goto(BASE+'?demo',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('#pg-dash .sv',{timeout:60000});
  return {browser,ctx,page,cons};
}
module.exports={boot,BASE};
