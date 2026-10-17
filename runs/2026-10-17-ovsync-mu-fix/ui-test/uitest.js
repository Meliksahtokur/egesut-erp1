const { chromium } = require('playwright');
const fs = require('fs');
const PORT = process.argv[2];
const OUT = __dirname;
const R = {};
(async () => {
  const exe = process.env.HOME + '/.cache/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-linux64/chrome-headless-shell';
  const b = await chromium.launch({ executablePath: exe });
  const ctx = await b.newContext({ viewport: { width: 420, height: 900 } });
  await ctx.addInitScript(() => { localStorage.setItem('EGESUT_DEMO','1'); localStorage.setItem('EGESUT_DEMO_POPUP_OFF','1'); });
  const p = await ctx.newPage();
  const errs = [], reqs = [], http4 = [];
  p.on('console', m => { if (m.type()==='error') errs.push('console: '+m.text()); });
  p.on('pageerror', e => errs.push('pageerror: '+e.message));
  p.on('request', r => { if (/js\/ui\.js/.test(r.url())) reqs.push(r.url()); });
  p.on('response', r => { if (r.status()>=400) http4.push(r.status()+' '+r.url()); });
  await p.goto(`http://localhost:${PORT}/index.html?demo`);
  await p.waitForSelector('#pg-dash .sv', { timeout: 60000 });
  for (let i=0;i<90;i++){ const ok=await p.evaluate(async()=>{const a=await idbGetAll('cases');const g=await idbGetAll('gorev_log');return a.length>0&&g.length>0;}).catch(()=>false); if(ok)break; await p.waitForTimeout(1000);}
  await p.waitForTimeout(3000);

  const durum = (id) => p.evaluate(async (id) => {
    const bar = document.getElementById('cd-hastalik-bar');
    const h = document.getElementById('cd-hastalik-btn'), i = document.getElementById('cd-ilac-btn');
    const cs = e => e ? getComputedStyle(e).display : 'YOK';
    return { curCase: _curCase && _curCase.id, bar: cs(bar), h: cs(h), i: cs(i) };
  }, id);
  const ac = async (id) => {
    await p.evaluate(id => openCaseDet(id), id);
    await p.waitForTimeout(1500);
    // hastalik bar async sync bekle
    await p.waitForTimeout(1200);
  };
  const kapat = async () => { await p.evaluate(() => { document.querySelectorAll('.bs-bg,.modal-bg,.overlay').forEach(()=>{}); if (typeof closeM==='function') { try{closeM('m-case-det');}catch(e){} } }); await p.waitForTimeout(300); };

  const veri = await p.evaluate(async () => {
    const cases = await idbGetAll('cases'), gl = await idbGetAll('gorev_log'), an = await idbGetAll('animals').catch(()=>[]);
    const kupe = id => (an.find(a=>a.id===id)||{}).kupe_no || (an.find(a=>a.id===id)||{}).tag_no;
    const act = cases.filter(c=>c.status==='active');
    const logsOf = c => gl.filter(g=>String(g.kaynak||'').startsWith('TEDAVI_SABLON_TOHUMLAMA:'+c.id+':'));
    const c232 = cases.find(c=>c.id.startsWith('232e7f7d'));
    return {
      c232: c232 && { id: c232.id, status: c232.status, pf: c232.protocol_family, kupe: kupe(c232.animal_id), logs: logsOf(c232).map(g=>g.kaynak+' iptal='+g.iptal) },
      anyLogs232: gl.filter(g=>String(g.kaynak||'').includes('232e7f7d')).map(g=>g.kaynak),
      manuel: act.filter(c=>c.protocol_family==null).map(c=>({id:c.id,k:kupe(c.animal_id),l:logsOf(c).map(g=>g.kaynak.split(':')[2]+'/iptal='+g.iptal)})).filter(x=>x.l.length&&x.l.every(s=>s.startsWith('MANUEL'))),
      ovs: act.filter(c=>c.protocol_family==='OVSYNC').map(c=>({id:c.id,k:kupe(c.animal_id)})).slice(0,6),
    };
  });
  R.veri = veri;

  // 1
  if (veri.c232) {
    await ac(veri.c232.id);
    R.m1 = await durum(); R.m1.not = 'gorev_log tohumlama satiri: ' + (veri.c232.logs.length||0) + ' (tum 232e7f7d referansli: ' + veri.anyLogs232.length + '); pf=' + veri.c232.pf + ' kupe=' + veri.c232.kupe;
    await p.screenshot({ path: OUT+'/m1-mastit-232e7f7d.png' });
    await p.evaluate(()=>{const e=document.getElementById('cd-hastalik-bar'); if(e) e.scrollIntoView({block:'center'});});
    await p.screenshot({ path: OUT+'/m1-mastit-232e7f7d-bar.png' });
    await kapat();
  }
  // 2
  if (veri.manuel.length) {
    await ac(veri.manuel[0].id);
    R.m2 = Object.assign({ vaka: veri.manuel[0] }, await durum());
    await p.screenshot({ path: OUT+'/m2-manuel.png' });
    await kapat();
  } else R.m2 = 'uygulanamaz: damgasiz acik + yalniz :MANUEL logu vaka yok';
  // 3
  const ov = veri.ovs[0];
  await ac(ov.id);
  R.m3 = Object.assign({ vaka: ov }, await durum());
  await p.evaluate(()=>{const e=document.getElementById('cd-hastalik-bar'); if(e) e.scrollIntoView({block:'center'});});
  await p.screenshot({ path: OUT+'/m3-ovsync-bar.png' });
  await p.evaluate(()=>document.getElementById('cd-hastalik-btn').click());
  await p.waitForTimeout(2500);
  R.m3.sheet = await p.evaluate(()=>{
    const m = [...document.querySelectorAll('body *')].filter(e=>e.children.length===0 && /\+ Hastalık —/.test(e.textContent)).map(e=>e.textContent.trim().slice(0,80));
    return m;
  });
  await p.screenshot({ path: OUT+'/m3-hastalik-sheet.png' });
  await p.evaluate(()=>{const e=document.getElementById('hastalik-modal'); if(e) e.remove();}); await p.waitForTimeout(800);
  await p.evaluate(()=>{ ['hastalik-bs','hg-bs'].forEach(i=>{const e=document.getElementById(i); if(e) e.remove();}); });
  // 4
  await p.evaluate(()=>{ document.querySelectorAll('[id$="-bs"]').forEach(e=>e.remove()); });
  await p.evaluate(()=>{ if(typeof closeM==='function'){try{closeM('m-case-det')}catch(e){}} goTo('ovsync'); });
  await p.waitForTimeout(6000);
  R.m4 = await p.evaluate(()=>{
    const t = document.getElementById('pg-ovsync').innerText;
    return { adet: (t.match(/MUAYENEDE SORUN VARSA HASTALIK GÜNÜ AÇ/g)||[]).length, kart: document.querySelectorAll('#pg-ovsync .ovs-kart').length, head: t.slice(0,120) };
  });
  await p.evaluate(()=>{ const e=[...document.querySelectorAll('#pg-ovsync *')].find(e=>e.children.length===0&&/MUAYENEDE SORUN VARSA/.test(e.textContent)); if(e) e.scrollIntoView({block:'center'}); });
  await p.waitForTimeout(500);
  await p.screenshot({ path: OUT+'/m4-ovsync-takip.png' });
  // 5
  R.m5 = { errs, http4, uiReqs: reqs };
  fs.writeFileSync(OUT+'/sonuclar.json', JSON.stringify(R, null, 2));
  console.log(JSON.stringify(R, null, 2));
  await b.close();
})();
