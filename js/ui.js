// ═══════════════════════════════════════════════════════
// ui.js — EgeSüt render & UI fonksiyonları
// ═══════════════════════════════════════════════════════

// ──────────────────────────────────────────
// YARDIMCI RENDER
// ──────────────────────────────────────────
function band(cls,title,content){
  return `<div class="aband"><div class="aband-hdr ${cls}">${title}</div><div class="aband-body">${content}</div></div>`;
}
function yasHesapla(dogumTarihi){
  if(!dogumTarihi) return '';
  const d=new Date(dogumTarihi), now=new Date();
  let y=now.getFullYear()-d.getFullYear(), m=now.getMonth()-d.getMonth(), gn=now.getDate()-d.getDate();
  if(gn<0){ m--; gn+=new Date(now.getFullYear(),now.getMonth(),0).getDate(); }
  if(m<0){ y--; m+=12; }
  if(y>0) return `${y} yıl ${m} ay`;
  if(m>0) return `${m} ay ${gn} gün`;
  return `${gn} gün`;
}
function showTab(name,btn){
  document.querySelectorAll('.tab-pane').forEach(p=>p.classList.remove('on'));
  document.querySelectorAll('.tab').forEach(b=>b.classList.remove('on'));
  document.getElementById('tab-'+name).classList.add('on');
  if(btn) btn.classList.add('on');
}
function showTab2(name,btn){
  document.querySelectorAll('.tab2-pane').forEach(p=>p.classList.remove('on'));
  document.querySelectorAll('.tab2').forEach(b=>b.classList.remove('on'));
  document.getElementById('tab2-'+name).classList.add('on');
  if(btn) btn.classList.add('on');
}

// ──────────────────────────────────────────
// DASHBOARD
// ──────────────────────────────────────────
async function loadDash(){
  const el=document.getElementById('dash-body');
  try {
    const today=new Date().toISOString().split('T')[0];
    const [animals,diseases,tasks,stock,moves,births60,gebeTohs]=await Promise.all([
      getData('hayvanlar',a=>a.durum==='Aktif'),
      getData('cases',c=>c.status==='active'),
      getData('gorev_log',t=>!t.tamamlandi),
      idbGetAll('stok'),
      getData('stok_hareket',m=>!m.iptal),
      getData('dogum',b=>b.tarih>=dAgo(63)&&b.tarih<=dAgo(58)),
      getData('tohumlama',t=>t.sonuc==='Gebe'),
    ]);
    const stkNet={};
    stock.forEach(s=>{ const used=moves.filter(m=>m.stok_id===s.id).reduce((a,m)=>a+(+m.miktar||0),0); stkNet[s.id]=(+s.baslangic_miktar||0)-used; });
    const critStk=stock.filter(s=>stkNet[s.id]>=0&&stkNet[s.id]<=(+s.esik||0)).length;
    const negStk=stock.filter(s=>stkNet[s.id]<0).length;
    const late=tasks.filter(t=>t.hedef_tarih<today&&!t.parent_id);
    const todayT=tasks.filter(t=>t.hedef_tarih===today&&!t.parent_id);
    const badge=late.length;
    const tb=document.getElementById('tbadge');
    if(tb){ tb.textContent=badge>99?'99+':badge; tb.style.display=badge>0?'flex':'none'; }
    const nearBirth=gebeTohs.filter(t=>{ if(!t.tarih)return false; const d=Math.floor((new Date(t.tarih).getTime()+280*86400000-Date.now())/86400000); return d>=0&&d<=7; });
    let h=`<div class="stat-row">
      <div class="sc ok" onclick="goTo('suru')"><div class="sv">${animals.length}</div><div class="sl">Aktif Hayvan ›</div></div>
      <div class="sc ok" onclick="showGebe()"><div class="sv">${gebeTohs.length}</div><div class="sl">Gebe ›</div></div>
      <div class="sc ${diseases.length>0?'alert':'ok'}" onclick="goTo('gecmis');loadGecmis('hastalik')"><div class="sv">${diseases.length}</div><div class="sl">Aktif Hastalık ›</div></div>
      <div class="sc ${badge>0?'alert':tasks.length>0?'warn':'ok'}" onclick="goTo('tasks')"><div class="sv">${tasks.length}</div><div class="sl">Bekleyen Görev ›</div></div>
    </div>`;
    if(negStk>0) h+=band('red','🆘 Negatif Stok',`<div class="arow" onclick="goTo('log')"><div class="arow-left"><div class="arow-sub">${negStk} üründe stok sıfırın altında. Stok sekmesine git.</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`);
    if(late.length){
      h+=`<div class="sh"><span class="sh-title">🔴 Geciken Görevler</span><button class="sh-link" onclick="goTo('tasks')">Tümü →</button></div>`;
      h+=late.slice(0,4).map(t=>renderTask(t,'late')).join('');
    }
    if(todayT.length){
      h+=`<div class="sh"><span class="sh-title">⏳ Bugün</span></div>`;
      h+=todayT.slice(0,4).map(t=>renderTask(t,'soon')).join('');
    }
    if(births60.length){
      h+=band('amber','💛 Kızgınlık Beklenenler (58-63. gün)',
        births60.map(b=>`<div class="arow" onclick="openDet('${b.anne_id}')"><div class="arow-left"><div class="arow-id">${b.anne_id}</div><div class="arow-sub">${b.tarih} — ${Math.floor((Date.now()-new Date(b.tarih))/86400000)}. gün</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`).join(''));
    }
    if(nearBirth.length){
      h+=band('blue','🤰 Yaklaşan Doğumlar (≤7 gün)',
        nearBirth.map(b=>`<div class="arow" onclick="openDet('${b.hayvan_id}')"><div class="arow-left"><div class="arow-id">${b.hayvan_id}</div><div class="arow-sub">${Math.floor((new Date(b.tarih).getTime()+280*86400000-Date.now())/86400000)} gün kaldı</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`).join(''));
    }
    if(critStk>0){
      const cl2=stock.filter(s=>stkNet[s.id]>=0&&stkNet[s.id]<=(+s.esik||0));
      h+=band('amber','⚠️ Kritik Stok',cl2.map(s=>`<div class="arow"><div class="arow-left"><div class="arow-id">${s.urun_adi}</div><div class="arow-sub">${(stkNet[s.id]||0).toFixed(0)} ${s.birim||''} kaldı — eşik: ${s.esik}</div></div></div>`).join(''));
    }
    el.innerHTML=h||'<div class="empty"><div class="empty-ico">✅</div>Her şey yolunda</div>';
  } catch(e){
    el.innerHTML=`<div class="empty">⚠️ ${e.message}<br><button class="btn btn-o" style="margin-top:12px;width:auto;padding:8px 20px" onclick="loadDash()">Tekrar Dene</button></div>`;
  }
}
async function showGebe(){
  goTo('suru');
  const gebeTohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
  const gebeIds=new Set(gebeTohs.map(t=>t.hayvan_id));
  renderAnimals(_A.filter(a=>gebeIds.has(a.id)||gebeIds.has(a.kupe_no)));
}

// ──────────────────────────────────────────
// GÖREVLER
// ──────────────────────────────────────────
async function loadTasks(f,btn){
  _curTaskFilter=f;
  if(btn){ document.querySelectorAll('.fs-btn').forEach(b=>b.classList.remove('on')); btn.classList.add('on'); }
  const el=document.getElementById('tasks-body');
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const today=new Date().toISOString().split('T')[0];
    const all=await idbGetAll('gorev_log');
    if(f==='done'){
      let done=all.filter(t=>t.tamamlandi&&!t.parent_id);
      done.sort((a,b)=>(b.tamamlanma_tarihi||b.hedef_tarih||'').localeCompare(a.tamamlanma_tarihi||a.hedef_tarih||''));
      if(!done.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Henüz tamamlanan görev yok</div>'; return; }
      el.innerHTML=done.slice(0,150).map(t=>`<div class="task-card" style="border-left-color:var(--ink3);opacity:.65">
        <div class="tc-header"><div class="tc-main">
          <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">
            <span class="tc-id">${(()=>{const h=_A.find(a=>a.id===t.hayvan_id);return h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'GENEL');})()} </span>
            <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
          </div>
          <div class="tc-desc">${t.aciklama||''}</div>
          <div class="tc-meta" style="color:var(--green)">✅ Tamamlandı: ${fmtTarih(t.tamamlanma_tarihi||t.hedef_tarih)}</div>
        </div></div>
      </div>`).join('');
      return;
    }
    let data=all.filter(t=>!t.tamamlandi&&!t.parent_id);
    if(f==='today') data=data.filter(t=>t.hedef_tarih<=today);
    else if(f==='late') data=data.filter(t=>t.hedef_tarih<today);
    data.sort((a,b)=>(a.hedef_tarih||'').localeCompare(b.hedef_tarih||''));
    if(!data.length){ el.innerHTML='<div class="empty"><div class="empty-ico">✅</div>Bu filtrede görev yok</div>'; return; }
    const allSubs=all.filter(t=>!!t.parent_id&&!t.tamamlandi);
    el.innerHTML=data.slice(0,150).map(t=>{
      const cls=t.hedef_tarih<today?'late':t.hedef_tarih===today?'soon':
        (()=>{ const diff=Math.floor((new Date(t.hedef_tarih)-new Date())/86400000); return diff<=3?'near':''; })();
      return renderTask(t,cls,allSubs.filter(s=>s.parent_id===t.id));
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
}
function renderTask(t,cls='',subs=[]){
  const doneSubs=subs.filter(s=>s.tamamlandi).length;
  const allDone=subs.length>0&&doneSubs===subs.length;
  const subHtml=subs.length?`<div class="subtasks">
    ${subs.map(s=>`<div class="st-row">
      <div class="st-check ${s.tamamlandi?'done':''}" onclick="toggleSub('${s.id}','${t.id}',this)">
        ${s.tamamlandi?`<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>`:''}
      </div>
      <span class="st-label ${s.tamamlandi?'done':''}">${s.aciklama}</span>
    </div>`).join('')}
    <div class="st-prog">${doneSubs}/${subs.length} tamamlandı</div>
  </div>`:'';
  return `<div class="task-card ${cls}${allDone?' done':''}" id="tc-${t.id}" onclick="openTaskDet('${t.id}')" style="cursor:pointer">
    <div class="tc-header">
      <div class="tc-main">
        <div style="display:flex;align-items:center;gap:7px;flex-wrap:wrap">
          <span class="tc-id">${(()=>{const h=_A.find(a=>a.id===t.hayvan_id);return h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'—');})()} </span>
          <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
        </div>
        <div class="tc-desc">${t.aciklama||''}</div>
        <div class="tc-meta"><span>${fmtTarih(t.hedef_tarih)}</span>${t.stok_id?`<span>💊 ${t.stok_id}</span>`:''}</div>
      </div>
      ${subs.length===0?`<button class="ck-btn" onclick="doneTask('${t.id}','${t.hayvan_id||''}','${t.stok_id||''}',${+t.miktar||0},'${t.padok_hedef||''}',this)">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
      </button>`:''}
    </div>
    ${subHtml}
  </div>`;
}
async function toggleSub(subId,parentId,el){
  const subs=await getData('gorev_log',t=>t.id===subId);
  const sub=subs[0]; if(!sub) return;
  const nowDone=!sub.tamamlandi;
  await write('gorev_log',{...sub,tamamlandi:nowDone,tamamlanma_tarihi:nowDone?new Date().toISOString():null},'PATCH',`id=eq.${subId}`);
  if(nowDone){
    const allSubs=await getData('gorev_log',t=>t.parent_id===parentId);
    const remaining=allSubs.filter(s=>s.id!==subId&&!s.tamamlandi);
    if(remaining.length===0){
      const parent=(await getData('gorev_log',t=>t.id===parentId))[0];
      if(parent) await write('gorev_log',{...parent,tamamlandi:true,tamamlanma_tarihi:new Date().toISOString()},'PATCH',`id=eq.${parentId}`);
      toast('✅ Tüm alt görevler tamamlandı, ana görev kapatıldı');
    }
  }
  await loadTasks(_curTaskFilter||'today');
  loadDash();
}
async function doneTask(id,hid,stokId,miktar,padok,btn){
  btn.disabled=true;
  btn.innerHTML='<div class="spin" style="width:14px;height:14px;border-width:2px"></div>';
  try {
    const task=(await getData('gorev_log',t=>t.id===id))[0]||{};
    await write('gorev_log',{...task,id,tamamlandi:true,tamamlanma_tarihi:new Date().toISOString()},'PATCH',`id=eq.${id}`);
    const _stokKontrol=stokId?_S.find(s=>s.id===stokId):null;
    if(stokId&&miktar>0&&_stokKontrol) await write('stok_hareket',{id:crypto.randomUUID(),stok_id:stokId,tur:'Görev',miktar,notlar:'GorevID:'+id,iptal:false});
    if(padok&&hid) await write('hayvanlar',{id:hid,padok},'PATCH',`id=eq.${hid}`);
    const elT=document.getElementById('tc-'+id);
    if(elT){ elT.classList.add('done'); setTimeout(()=>elT.remove(),320); }
    toast('✅ Tamamlandı');
    loadDash();
  } catch(e){
    btn.disabled=false;
    btn.innerHTML='<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>';
    toast(e.message,true);
  }
}

// ──────────────────────────────────────────
// SÜRÜ
// ──────────────────────────────────────────
async function loadAnimals(){
  const el=document.getElementById('suru-body');
  try {
    _A=await getData('hayvanlar',a=>a.durum==='Aktif');
    const gebeTohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
    _gebeIds=[...new Set([...gebeTohs.map(t=>t.hayvan_id),..._A.filter(a=>a.durum==='Gebe').map(a=>a.id)])];
    const hastaLogs=await getData('hastalik_log',d=>d.durum==='Aktif');
    _hastaIds=new Set(hastaLogs.map(d=>d.hayvan_id));
    _A.sort((a,b)=>(a.kupe_no||a.id||'').localeCompare(b.kupe_no||b.id||''));
    window._appState=window._appState||{}; window._appState.hayvanlar=_A;
    renderAnimals(_A);
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
}
function renderAnimals(list){
  const el=document.getElementById('suru-body');
  if(!list.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🐄</div>Hayvan bulunamadı</div>'; updatePadokOzet(list); return; }
  const gebeSet=new Set(_gebeIds||[]);
  el.innerHTML=list.map(a=>{
    const mainId=a.kupe_no||a.devlet_kupe||a.id||'?';
    const subId=a.kupe_no&&a.devlet_kupe?`<span style="font-size:.65rem;color:var(--ink3);font-weight:400"> · ${a.devlet_kupe}</span>`:'';
    const init=mainId.replace(/\D/g,'').slice(-3)||mainId.slice(0,2).toUpperCase();
    const yas=yasHesapla(a.dogum_tarihi);
    const isGebe=gebeSet.has(a.id)||a.durum==='Gebe';
    const gebeBadge=isGebe?`<span class="tag" style="background:rgba(78,154,42,.15);color:var(--green);font-weight:700">🤰 Gebe</span>`:'';
    const abortBadge=a.abort_sayisi>0?`<span class="tag" style="background:rgba(192,50,26,.12);color:var(--red);font-size:.6rem">${a.abort_sayisi}x abort</span>`:'';
    return `<div class="animal-card" onclick="openDet('${a.id}')">
      <div class="avt">${init}</div>
      <div class="ainfo">
        <div class="a-id">${mainId}${subId}</div>
        <div class="a-sub">${a.irk||'—'}${yas?' · '+yas:''}</div>
        <div class="a-tags"><span class="tag tb">${a.padok||'?'}</span><span class="tag tk">${a.grup||''}</span>${gebeBadge}${abortBadge}</div>
      </div>
      <svg class="a-arr" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg>
    </div>`;
  }).join('');
  updatePadokOzet(list);
}
function updatePadokOzet(list){
  const el=document.getElementById('padok-ozet'); if(!el) return;
  const gebeSet=new Set(_gebeIds||[]);
  const padok=document.getElementById('pflt')?.value;
  if(!list.length){ el.innerHTML=''; return; }
  const toplam=list.length;
  const disi=list.filter(a=>a.cinsiyet==='Dişi'||!a.cinsiyet).length;
  const erkek=list.filter(a=>a.cinsiyet==='Erkek').length;
  const gebe=list.filter(a=>gebeSet.has(a.id)||a.durum==='Gebe').length;
  const bos=disi-gebe;
  const isBuzagi=padok&&padok.toLowerCase().includes('buzağı');
  const chip=(txt,color)=>`<span style="background:${color};border-radius:8px;padding:3px 9px;font-size:.68rem;font-weight:700;color:#fff">${txt}</span>`;
  let html=chip(`Toplam: ${toplam}`,'rgba(61,74,50,.7)');
  if(isBuzagi||erkek>0){
    html+=chip(`Dişi: ${disi}`,'rgba(78,154,42,.7)')+chip(`Erkek: ${erkek}`,'rgba(42,107,181,.7)');
  } else {
    html+=chip(`Gebe: ${gebe}`,'rgba(78,154,42,.8)')+chip(`Boş: ${bos}`,'rgba(180,140,0,.7)');
  }
  el.innerHTML=html;
}
let _filterTimer=null;
function srchDropdown(){
  const q=(document.getElementById('srch')?.value||'').toLowerCase().trim();
  const ac=document.getElementById('ac-srch');
  if(!ac) return;
  if(!q){ ac.style.display='none'; return; }
  const gebeSet=new Set(_gebeIds||[]);
  const matches=_A.filter(a=>{
    const k=(a.kupe_no||'').toLowerCase(), d=(a.devlet_kupe||'').toLowerCase();
    return k.includes(q)||d.includes(q)||(a.irk||'').toLowerCase().includes(q);
  }).slice(0,8);
  if(!matches.length){ ac.style.display='none'; return; }
  ac.innerHTML=matches.map(a=>{
    const main=a.kupe_no||a.devlet_kupe||a.id;
    const sub=a.kupe_no&&a.devlet_kupe?` · <span style="color:#aaa">${a.devlet_kupe}</span>`:'';
    const isGebe=gebeSet.has(a.id)||a.durum==='Gebe';
    const badge=isGebe?'<span style="background:rgba(78,154,42,.15);color:var(--green);border-radius:5px;padding:1px 5px;font-size:.62rem;font-weight:700;margin-left:4px">🤰</span>':'';
    return `<div onclick="srchSec('${a.id}','${main}')" style="padding:9px 12px;cursor:pointer;border-bottom:1px solid #f0f0f0;display:flex;justify-content:space-between;align-items:center">
      <div><span style="font-weight:700;font-size:.85rem">${main}</span>${sub}${badge}</div>
      <span style="font-size:.68rem;color:#aaa">${a.padok||''}</span>
    </div>`;
  }).join('');
  ac.style.display='block';
}
function srchSec(id,kupe){
  document.getElementById('srch').value=kupe;
  document.getElementById('ac-srch').style.display='none';
  openDet(id);
}
document.addEventListener('click',e=>{
  if(!e.target.closest('#srch')&&!e.target.closest('#ac-srch'))
    { const ac=document.getElementById('ac-srch'); if(ac) ac.style.display='none'; }
});
let _fchip={cinsiyet:'hepsi',gebelik:null,saglik:null};
function fchipSec(grup,deger,btn){
  if(_fchip[grup]===deger){ _fchip[grup]=null; btn.classList.remove('on'); }
  else {
    document.querySelectorAll(`[id^="fc-${grup}-"]`).forEach(b=>b.classList.remove('on'));
    _fchip[grup]=deger; btn.classList.add('on');
  }
  filterA();
}
function filterA(){
  clearTimeout(_filterTimer);
  _filterTimer=setTimeout(()=>{
    const q=document.getElementById('srch')?.value.toLowerCase()||'';
    const p=document.getElementById('pflt')?.value||'';
    const gebeSet=new Set(_gebeIds||[]);
    let f=_A;
    if(q) f=f.filter(a=>(a.id+(a.kupe_no||'')+(a.devlet_kupe||'')+(a.irk||'')).toLowerCase().includes(q));
    if(p) f=f.filter(a=>a.padok===p);
    if(_fchip.cinsiyet==='disi') f=f.filter(a=>a.cinsiyet==='Dişi'||!a.cinsiyet);
    else if(_fchip.cinsiyet==='erkek') f=f.filter(a=>a.cinsiyet==='Erkek');
    if(_fchip.gebelik==='gebe') f=f.filter(a=>gebeSet.has(a.id)||a.durum==='Gebe');
    else if(_fchip.gebelik==='bos') f=f.filter(a=>!gebeSet.has(a.id)&&a.durum!=='Gebe');
    if(_fchip.saglik==='hasta') f=f.filter(a=>_hastaIds.has(a.id));
    renderAnimals(f);
  },250);
}

// ──────────────────────────────────────────
// HAYVAN DETAY
// ──────────────────────────────────────────
async function openDet(id){
  document.getElementById('det').classList.add('on');
  document.getElementById('det-name').textContent='Yükleniyor…';
  ['det-chips','tab-ozet','tab-saglik','tab-ureme','tab-gorev','tab-gecmis'].forEach(i=>{const el=document.getElementById(i);if(el)el.innerHTML='';});
  showTab('ozet',document.querySelector('.tab'));
  try {
    const [aArr,diseases,tohs,tasks,births,subs,yavrular,activeCases]=await Promise.all([
      getData('hayvanlar',a=>a.id===id||a.kupe_no===id||a.devlet_kupe===id),
      getData('cases',c=>c.animal_id===id),
      getData('tohumlama',t=>t.hayvan_id===id),
      getData('gorev_log',t=>t.hayvan_id===id&&!t.tamamlandi&&!t.parent_id),
      getData('dogum',b=>b.anne_id===id),
      getData('gorev_log',t=>t.hayvan_id===id&&!t.tamamlandi&&!!t.parent_id),
      getData('hayvanlar',a=>a.anne_id===id),
      getData('cases',c=>c.animal_id===id&&c.status==='active'),
    ]);
    const a=aArr[0]; if(!a){ document.getElementById('det-name').textContent='Bulunamadı'; return; }
    diseases.sort((x,y)=>(y.tarih||'').localeCompare(x.tarih||''));
    tohs.sort((x,y)=>(y.tarih||'').localeCompare(x.tarih||''));
    tasks.sort((x,y)=>(x.hedef_tarih||'').localeCompare(y.hedef_tarih||''));
    const yasRaw=a.dogum_tarihi?Math.floor((Date.now()-new Date(a.dogum_tarihi))/86400000):null;
    const yasGun=yasRaw===null?'—':yasRaw<0||yasRaw>36500?'Geçersiz tarih':yasHesapla(a.dogum_tarihi);
    const aktifHst=diseases.filter(c=>c.status==='active').length;
    const today=new Date().toISOString().split('T')[0];
    const displayId=a.devlet_kupe||a.kupe_no||a.id;
    document.getElementById('det-name').textContent=displayId;
    document.getElementById('det-meta').textContent=`${a.irk||'—'} · ${a.padok||'?'}`;
    document.getElementById('det-chips').innerHTML=[
      {cls:'chip-k',txt:a.grup||'?'},
      {cls:'chip-k',txt:a.padok||'?'},
      aktifHst>0||activeCases.length>0?{cls:'chip-r',txt:`🚨 ${activeCases.length||aktifHst} aktif vaka`}:{cls:'chip-g',txt:'✅ Sağlıklı'},
      tohs.find(t=>t.sonuc==='Gebe')?{cls:'chip-g',txt:'🤰 Gebe'}:null,
    ].filter(Boolean).map(c=>`<div class="chip ${c.cls}">${c.txt}</div>`).join('');

    document.getElementById('tab-ozet').innerHTML=`
      <div class="stats-strip">
        <div class="ss-item"><div class="ss-val" style="font-size:${yasRaw!==null&&(yasRaw<0||yasRaw>36500)?'0.75rem':'1.15rem'}">${yasGun}</div><div class="ss-lbl">Yaş</div></div>
        <div class="ss-item"><div class="ss-val">${births.length}</div><div class="ss-lbl">Laktasyon</div></div>
        <div class="ss-item"><div class="ss-val">${diseases.length}</div><div class="ss-lbl">Toplam Vaka</div></div>
        <div class="ss-item"><div class="ss-val">${tasks.length+subs.length}</div><div class="ss-lbl">Bekl. Görev</div></div>
      </div>
      <div class="info-grid">
        ${[{l:'Devlet Küpe',v:a.devlet_kupe||'—'},{l:'İşletme Küpe',v:a.kupe_no||'—'},{l:'Irk',v:a.irk||'—'},{l:'Cinsiyet',v:a.cinsiyet||'—'},{l:'Grup',v:a.grup||'—'},{l:'Padok',v:a.padok||'—'},{l:'Doğum',v:fmtTarih(a.dogum_tarihi)||'—'},{l:'Doğum Kg',v:a.dogum_kg?a.dogum_kg+' kg':'—'},{l:'Canlı Ağırlık',v:a.canli_agirlik?a.canli_agirlik+' kg':'—'},{l:'Boy',v:a.boy?a.boy+' cm':'—'},{l:'Renk',v:a.renk||'—'},{l:'Ayırt Edici',v:a.ayirici_ozellik||'—'},{l:'Durum',v:a.durum||'—'}].map(i=>`<div class="ig-item"><div class="ig-lbl">${i.l}</div><div class="ig-val">${i.v}</div></div>`).join('')}
      </div>
      ${(()=>{
        const anneObj=a.anne_id?_A.find(x=>x.id===a.anne_id):null;
        const anneKupe=anneObj?(anneObj.kupe_no||anneObj.devlet_kupe):a.anne_id;
        let ht='';
        if(anneKupe) ht+=`<div style="background:var(--card2);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem">
          <span style="color:var(--ink3)">Anne: </span>
          <span onclick="openDet('${a.anne_id}')" style="font-weight:700;color:var(--blue);cursor:pointer">📌 ${anneKupe}</span>
        </div>`;
        if(yavrular.length) ht+=`<div style="background:var(--card2);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem">
          <div style="color:var(--ink3);margin-bottom:4px">Yavrular (${yavrular.length}):</div>
          <div style="display:flex;flex-wrap:wrap;gap:5px">${yavrular.map(y=>`<span onclick="openDet('${y.id}')" style="background:var(--card);border:1px solid var(--card3);border-radius:7px;padding:3px 8px;font-size:.75rem;font-weight:700;cursor:pointer;color:var(--ink)">🐄 ${y.kupe_no||y.devlet_kupe||y.id}</span>`).join('')}</div>
        </div>`;
        if(a.notlar){
          ht+=`<div style="background:var(--card2);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem">
            <div style="color:var(--ink3);margin-bottom:4px">📝 Notlar:</div>
            <div style="color:var(--ink)">${a.notlar}</div>
          </div>`;
        }
        return ht;
      })()}
      <button class="btn btn-g" style="margin-top:4px;padding:9px" onclick="openAnimalEdit('${a.id}')">✏️ Bilgileri Düzenle</button>
      <button class="btn btn-o" style="margin-top:6px;padding:9px" onclick="openNotModal('${a.id}','${displayId}')">📝 Not Ekle</button>
      <button class="btn" style="margin-top:6px;padding:9px;background:rgba(192,50,26,.08);color:var(--red);border:1px solid rgba(192,50,26,.2)" onclick="openCikisModal('${a.id}','${displayId}')">🚪 Çıkış Yap</button>`;

    const gebeTohumlama=tohs.find(t=>t.sonuc==='Gebe');
    const gebeBilgi=gebeTohumlama?(()=>{
      const toh=new Date(gebeTohumlama.tarih);
      const gunler=Math.floor((new Date()-toh)/86400000);
      const ay=Math.floor(gunler/30), kalanGun=gunler%30;
      return `${ay} ay ${kalanGun} gün (${gunler}. gün) · Tahmini: ${dFwd(gebeTohumlama.tarih,280)}`;
    })():null;

    const allDiseasesList = await idbGetAll('diseases');
    const activeCaseChips = activeCases.length
      ? `<div style="margin-bottom:8px;display:flex;flex-wrap:wrap;gap:6px">`
        + activeCases.map(c=>{
            const dis=allDiseasesList.find(d=>d.id===c.disease_id);
            return `<div onclick="openCaseDet('${c.id}')" style="cursor:pointer;background:rgba(192,50,26,.1);border:1.5px solid var(--red);border-radius:10px;padding:6px 10px;font-size:.78rem;font-weight:700;color:var(--red)">🏥 ${dis?.name||'?'}</div>`;
          }).join('')
        + `</div>`
      : '';
    const _caseListHtml = await renderCasesForAnimal(a.id);
    document.getElementById('tab-saglik').innerHTML=
      activeCaseChips+
      `<div style="padding:6px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-disease','d-hid','${a.kupe_no||a.devlet_kupe||a.id}')">🏥 Yeni Vaka Aç</button></div>`+
      _caseListHtml+
      (diseases.length
      ?`<div style="margin-top:14px;font-size:.7rem;font-weight:700;color:var(--ink3);text-transform:uppercase;padding-bottom:4px;border-bottom:1px solid var(--card2)">Eski Kayıtlar</div>`+
      diseases.map(d=>`<div class="hist-row" onclick="openHstDet('${d.id}')" style="cursor:pointer"><div class="hist-dot" style="background:${d.durum==='Aktif'?'var(--red2)':'var(--green2)'}"></div><div class="hist-main"><div class="hist-title">${d.tani||'—'}</div><div class="hist-sub">${d.tarih||''} · ${d.siddet||''} · <b style="color:${d.durum==='Aktif'?'var(--red)':'var(--green)'}">${d.durum}</b></div>${d.semptomlar?`<div class="hist-sub" style="margin-top:3px">${d.semptomlar}</div>`:''}</div></div>`).join('')
      :'');

    const bekleyenToh=tohs.find(t=>t.sonuc==='Bekliyor');
    let uremeHtml=`<div style="padding:10px 0 6px;display:flex;gap:6px;flex-wrap:wrap">`;
    if(gebeTohumlama){
      uremeHtml+=`<button class="btn" style="flex:1;padding:9px;background:rgba(192,50,26,.1);color:var(--red);font-weight:700" onclick="abortKaydet('${a.id}','${gebeTohumlama.id}')">⚠️ Abort / Erken Doğum</button>`;
    } else if(bekleyenToh){
      uremeHtml+=`<button class="btn" style="flex:1;padding:9px;background:rgba(78,154,42,.1);color:var(--green);font-weight:700" onclick="tohSonucGuncelle('${bekleyenToh.id}','Gebe','${a.id}')">🤰 Gebe</button>`;
      uremeHtml+=`<button class="btn" style="flex:1;padding:9px;background:rgba(192,50,26,.08);color:var(--red);font-weight:700" onclick="tohSonucGuncelle('${bekleyenToh.id}','Boş','${a.id}')">❌ Boş</button>`;
      uremeHtml+=`<button class="btn btn-g" style="flex:1;padding:9px" onclick="openMWithHayvan('m-insem','i-hid','${a.kupe_no||a.devlet_kupe||a.id}')">💉 Tohumlama Ekle</button>`;
    } else {
      uremeHtml+=`<button class="btn btn-g" style="flex:1;padding:9px" onclick="openMWithHayvan('m-insem','i-hid','${a.kupe_no||a.devlet_kupe||a.id}')">💉 Tohumlama Ekle</button>`;
    }
    uremeHtml+='</div>';
    if(gebeBilgi){
      uremeHtml+=`<div style="background:rgba(78,154,42,.08);border:1px solid rgba(78,154,42,.2);border-radius:10px;padding:10px 12px;margin-bottom:8px;font-size:.8rem;color:var(--ink2)"><b style="color:var(--green)">🤰 Gebe</b> — ${gebeBilgi}</div>`;
    }
    uremeHtml+=(tohs.length
      ?tohs.map(t=>`<div class="hist-row" onclick="openTohDet('${t.id}')" style="cursor:pointer"><div class="hist-dot" style="background:${t.sonuc==='Gebe'?'var(--green2)':t.sonuc==='Boş'?'var(--red2)':'var(--amber)'}"></div><div class="hist-main"><div class="hist-title">${t.sperma||'—'} · ${t.deneme_no||1}. deneme</div><div class="hist-sub">${t.tarih||''} · <b>${t.sonuc||'Bekliyor'}</b></div></div></div>`).join('')
      :'<div class="empty"><div class="empty-ico">💉</div>Tohumlama kaydı yok</div>');
    document.getElementById('tab-ureme').innerHTML=uremeHtml;

    document.getElementById('tab-gorev').innerHTML=
      `<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-task-add','ta-hid','${a.kupe_no||a.devlet_kupe||a.id}')">➕ Görev Ekle</button></div>`+
      (tasks.length
      ?tasks.map(t=>{ const ts=subs.filter(s=>s.parent_id===t.id); return renderTask(t,t.hedef_tarih<today?'late':t.hedef_tarih===today?'soon':'',ts); }).join('')
      :'<div class="empty"><div class="empty-ico">✅</div>Bekleyen görev yok</div>');

    // Geçmiş tab — islem_log'dan çek
    const gecmisEl=document.getElementById('tab-gecmis');
    if(gecmisEl){
      gecmisEl.innerHTML='<div class="loader"><div class="spin"></div></div>';
      try {
        const {data:logs=[]}=await db.from('islem_log').select('*').eq('ana_hayvan_id',id).order('tarih',{ascending:false});
        logs.sort((x,y)=>(y.created_at||y.tarih||'').localeCompare(x.created_at||x.tarih||''));
        const ISLEM_ICO2={'HAYVAN_EKLENDI':'🐮','TOHUMLAMA':'💉','DOGUM_KAYDI':'🐄','HASTALIK_KAYDI':'🏥','TEDAVI_GUNCELLE':'💊','KIZGINLIK':'🔴','ABORT_KAYDI':'⚠️','SATIS_KAYDI':'💰','OLUM_KAYDI':'💀','SUTTEN_KESME':'🍼'};
        if(!logs.length){ gecmisEl.innerHTML='<div class="empty"><div class="empty-ico">📋</div>Kayıt yok</div>'; }
        else {
          window._detGecmisLogs = logs;
          gecmisEl.innerHTML=logs.map((l,i)=>{
            const ico=ISLEM_ICO2[l.tip]||'📋';
            const tarih=(l.created_at||l.tarih||'').slice(0,10);
            const GeriAlabilir=['TOHUMLAMA','DOGUM_KAYDI','HASTALIK_KAYDI','ABORT_KAYDI'];
            const gaIcon=GeriAlabilir.includes(l.tip)?'<span style="font-size:.6rem;color:var(--ink3);margin-left:4px">↩</span>':'';
            const tipEtiket={'HAYVAN_EKLENDI':'Hayvan Eklendi','TOHUMLAMA':'Tohumlama','DOGUM_KAYDI':'Doğum','HASTALIK_KAYDI':'Hastalık Kaydı','TEDAVI_GUNCELLE':'Tedavi Güncelle','KIZGINLIK':'Kızgınlık','ABORT_KAYDI':'Abort','SATIS_KAYDI':'Satış','OLUM_KAYDI':'Ölüm','SUTTEN_KESME':'Sütten Kesme'}[l.tip]||l.tip||'—';
            return `<div class="hist-row" style="cursor:pointer" onclick="openIslemDetay(${i})"><div class="hist-dot" style="background:var(--green2)"></div><div class="hist-main"><div class="hist-title">${ico} ${tipEtiket}${gaIcon}</div><div class="hist-sub">${tarih}</div></div><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="flex-shrink:0;opacity:.4;margin-top:2px"><path d="M9 18l6-6-6-6"/></svg></div>`;
          }).join('');
        }
      } catch(e){ gecmisEl.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
    }

  } catch(e){ document.getElementById('det-name').textContent='Hata: '+e.message; }
}
function closeDet(){ document.getElementById('det').classList.remove('on'); }

function openIslemDetay(idx){
  const l=(window._detGecmisLogs||[])[idx];
  if(!l) return;
  // ref_tablo varsa doğrudan ilgili detay modalını aç
  if(l.ref_tablo==='hastalik_log' && l.ref_id){ openHstDet(l.ref_id); return; }
  if(l.ref_tablo==='tohumlama'    && l.ref_id){ openTohDet(l.ref_id); return; }
  // ref_id yoksa snapshot'tan dene (eski kayıtlar)
  const snapId=l.snapshot?.id;
  if(l.tip==='HASTALIK_KAYDI'    && snapId){ openHstDet(snapId); return; }
  if(l.tip==='TOHUMLAMA'         && snapId){ openTohDet(snapId); return; }
  const LABEL={'HAYVAN_EKLENDI':'Hayvan Eklendi','TOHUMLAMA':'Tohumlama','DOGUM_KAYDI':'Doğum','HASTALIK_KAYDI':'Hastalık Kaydı','TEDAVI_GUNCELLE':'Tedavi Güncelle','KIZGINLIK':'Kızgınlık','ABORT_KAYDI':'Abort','SATIS_KAYDI':'Satış','OLUM_KAYDI':'Ölüm','SUTTEN_KESME':'Sütten Kesme'};
  const ICO={'HAYVAN_EKLENDI':'🐮','TOHUMLAMA':'💉','DOGUM_KAYDI':'🐄','HASTALIK_KAYDI':'🏥','TEDAVI_GUNCELLE':'💊','KIZGINLIK':'🔴','ABORT_KAYDI':'⚠️','SATIS_KAYDI':'💰','OLUM_KAYDI':'💀','SUTTEN_KESME':'🍼'};
  const ALAN={'tarih':'Tarih','sperma':'Sperma','sonuc':'Sonuç','deneme_no':'Deneme','tani':'Tanı','siddet':'Şiddet','durum':'Durum','hekim_id':'Hekim','yavru_kupe':'Yavru Küpe','yavru_cins':'Yavru Cinsiyet','dogum_tipi':'Doğum Tipi','notlar':'Not','irk':'Irk','grup':'Grup','kupe_no':'Küpe','devlet_kupe':'Devlet Küpe'};
  const tarih=(l.created_at||l.tarih||'').slice(0,10);
  const GeriAlabilir=['TOHUMLAMA','DOGUM_KAYDI','HASTALIK_KAYDI','ABORT_KAYDI'];
  const payload=l.payload&&typeof l.payload==='object'?l.payload:{};
  const satirlar=Object.entries(payload)
    .filter(([k,v])=>!['hayvan_id','id','ana_hayvan_id'].includes(k)&&v!==null&&v!==undefined&&v!=='')
    .map(([k,v])=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card3);font-size:.78rem"><span style="color:var(--ink3)">${ALAN[k]||k}</span><span style="font-weight:600;color:var(--ink);text-align:right;max-width:60%">${v}</span></div>`)
    .join('');
  const gaBtn=GeriAlabilir.includes(l.tip)?`<button class="btn" style="background:var(--red);color:#fff;width:100%;margin-top:10px" onclick="openGeriAl('${l.id}','${LABEL[l.tip]||l.tip} — ${tarih} tarihli kayıt geri alınacak.')">↩ Geri Al</button>`:'';
  const html=`<div style="background:var(--card);border:1px solid var(--card3);border-radius:var(--r2);padding:14px;margin-top:8px">
    <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px">
      <span style="font-size:1.1rem">${ICO[l.tip]||'📋'}</span>
      <span style="font-weight:700;font-size:.88rem">${LABEL[l.tip]||l.tip}</span>
      <span style="margin-left:auto;font-size:.72rem;color:var(--ink3)">${tarih}</span>
    </div>
    ${satirlar||'<div style="font-size:.78rem;color:var(--ink3);text-align:center;padding:8px 0">Detay yok</div>'}
    ${gaBtn}
    <button class="btn btn-o" style="width:100%;margin-top:6px;font-size:.8rem" onclick="this.closest('.islem-detay-panel').remove()">Kapat</button>
  </div>`;
  // Aynı panel açıksa kapat, yoksa ekle
  const gecmisEl=document.getElementById('tab-gecmis');
  const existing=gecmisEl&&gecmisEl.querySelector('.islem-detay-panel');
  if(existing) existing.remove();
  const rows=gecmisEl&&gecmisEl.querySelectorAll('.hist-row');
  const clickedRow=rows&&rows[idx];
  if(clickedRow){
    const panel=document.createElement('div');
    panel.className='islem-detay-panel';
    panel.innerHTML=html;
    clickedRow.insertAdjacentElement('afterend',panel);
  }
}

// Not modal
// ──────────────────────────────────────────
// HAYVAN BİLGİ DÜZENLEME
// ──────────────────────────────────────────
async function openAnimalEdit(id){
  const a=_A.find(x=>x.id===id); if(!a){ toast('Hayvan bulunamadı',true); return; }
  const modal=document.getElementById('m-animal');
  if(!modal) return;

  // Önce formu temizle — önceki değerler kalmasın
  ['a-devlet','a-kupe','a-irk-txt','a-dt','a-dkg','a-agirlik','a-boy','a-renk','a-ozellik'].forEach(fid=>{const el=document.getElementById(fid);if(el)el.value='';});
  const cins=document.getElementById('a-cinsiyet'); if(cins) cins.value='';

  modal.dataset.editId=id;
  document.getElementById('m-animal-title').textContent='✏️ Bilgileri Düzenle';
  document.getElementById('m-animal-btn').textContent='💾 Güncelle';

  openM('m-animal');

  // Mevcut değerleri doldur
  setTimeout(async()=>{
    if(a.devlet_kupe) document.getElementById('a-devlet').value=a.devlet_kupe;
    if(a.kupe_no)     document.getElementById('a-kupe').value=a.kupe_no;
    if(a.cinsiyet){
      document.getElementById('a-cinsiyet').value=a.cinsiyet;
    }
    if(a.dogum_tarihi) document.getElementById('a-dt').value=a.dogum_tarihi;
    if(a.dogum_kg)    document.getElementById('a-dkg').value=a.dogum_kg;
    if(a.canli_agirlik) document.getElementById('a-agirlik').value=a.canli_agirlik;
    if(a.boy)         document.getElementById('a-boy').value=a.boy;
    if(a.renk)        document.getElementById('a-renk').value=a.renk||'';
    if(a.ayirici_ozellik) document.getElementById('a-ozellik').value=a.ayirici_ozellik||'';

    // Irk dropdown
    await loadIrkDropdown();
    const irkSel=document.getElementById('a-irk-sel');
    if(irkSel && a.irk){
      // Seçeneklerde var mı?
      const opt=[...irkSel.options].find(o=>o.value===a.irk);
      if(opt){ irkSel.value=a.irk; }
      else {
        irkSel.value='__diger__';
        const txt=document.getElementById('a-irk-txt');
        if(txt){ txt.style.display='block'; txt.disabled=false; txt.value=a.irk; }
      }
    }

    // Grup + padok
    animalFormGuncelle();
    setTimeout(()=>{
      const grupSel=document.getElementById('a-grup');
      if(grupSel && a.grup){
        // Seçenekte varsa set et, yoksa ekle
        const opt=[...grupSel.options].find(o=>o.value===a.grup);
        if(!opt) grupSel.innerHTML+=`<option value="${a.grup}">${a.grup}</option>`;
        grupSel.value=a.grup;
        animalGrupDegisti();
        setTimeout(()=>{
          const padokSel=document.getElementById('a-padok');
          if(padokSel && a.padok){
            const popt=[...padokSel.options].find(o=>o.value===a.padok);
            if(!popt) padokSel.innerHTML+=`<option value="${a.padok}">${a.padok}</option>`;
            padokSel.value=a.padok;
          }
        },50);
      }
    },50);
  },100);
}

function closeAnimalEdit(){
  const modal=document.getElementById('m-animal');
  if(modal){ delete modal.dataset.editId; }
  const titleEl=document.getElementById('m-animal-title');
  const btnEl=document.getElementById('m-animal-btn');
  if(titleEl) titleEl.textContent='🐄 Hayvan Ekle';
  if(btnEl)   btnEl.textContent='Kaydet';
  closeM('m-animal');
}

function openNotModal(hayvanId,kupe){
  document.getElementById('not-hid').value=hayvanId;
  document.getElementById('not-title').textContent='📝 '+kupe+' — Not Ekle';
  document.getElementById('not-input').value='';
  openM('m-not');
}

// Çıkış modal
function openCikisModal(hayvanId,kupe){
  document.getElementById('cx-hid').value=hayvanId;
  document.getElementById('cx-title').textContent='🚪 '+kupe+' — Çıkış';
  document.getElementById('cx-tarih').value=new Date().toISOString().split('T')[0];
  openM('m-cikis');
}

// ──────────────────────────────────────────
// DOĞUMLAR
// ──────────────────────────────────────────
async function loadBirths(){
  const el=document.getElementById('births-body');
  try {
    const data=await idbGetAll('dogum');
    data.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
    if(!data.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🐄</div>Henüz doğum yok</div>'; return; }
    el.innerHTML=data.slice(0,8).map(b=>`<div style="background:#fff;border:1px solid var(--card3);border-radius:10px;padding:10px 13px;margin-bottom:6px;display:flex;align-items:center;gap:10px">
    <div style="width:34px;height:34px;border-radius:9px;background:rgba(78,154,42,.12);display:flex;align-items:center;justify-content:center;font-size:1.1rem;flex-shrink:0">🐄</div>
    <div style="flex:1;min-width:0">
      <div style="font-weight:700;font-size:.85rem;color:#1a2010">${b.anne_id} → <b>${b.yavru_kupe}</b> (${b.yavru_cins||'?'})</div>
      <div style="font-size:.7rem;color:#666;margin-top:2px">${fmtTarih(b.tarih)} · ${b.dogum_tipi||'Normal'}${b.dogum_kg?' · '+b.dogum_kg+' kg':''}</div>
    </div>
  </div>`).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
}

// ──────────────────────────────────────────
// GEBE HAYVAN SEÇME
// ──────────────────────────────────────────
async function gebeledenSec(){
  const tohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
  const gebeHayvanlar=_A.filter(a=>a.durum==='Gebe'||a.durum==='gebe');
  const today2=new Date();
  const listFromToh=tohs.map(t=>{
    const toh=new Date(t.tarih);
    const dogumTahmini=new Date(toh.getTime()+280*86400000);
    const kalanGun=Math.floor((dogumTahmini-today2)/86400000);
    const hayvan=_A.find(a=>a.id===t.hayvan_id||a.kupe_no===t.hayvan_id);
    return {toh:t,hayvan,kalanGun,dogumTahmini:dogumTahmini.toISOString().split('T')[0]};
  }).filter(g=>g.hayvan&&g.kalanGun>=-14);
  const tohHayvanIds=new Set(listFromToh.map(g=>g.hayvan?.id));
  const listFromHayvan=gebeHayvanlar.filter(a=>!tohHayvanIds.has(a.id)).map(a=>({
    toh:{hayvan_id:a.id,tarih:a.tohumlama_tarihi||'',sperma:a.baba_bilgi||''},
    hayvan:a,
    kalanGun:a.tohumlama_tarihi?Math.floor((new Date(new Date(a.tohumlama_tarihi).getTime()+280*86400000)-today2)/86400000):999,
    dogumTahmini:a.tohumlama_tarihi?new Date(new Date(a.tohumlama_tarihi).getTime()+280*86400000).toISOString().split('T')[0]:'?'
  }));
  const gebeList=[...listFromToh,...listFromHayvan];
  gebeList.sort((a,b)=>a.kalanGun-b.kalanGun);
  let box=document.getElementById('gebe-sec-modal');
  if(!box){
    box=document.createElement('div');
    box.id='gebe-sec-modal';
    box.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:300;display:flex;align-items:flex-end';
    box.onclick=e=>{if(e.target===box)box.remove();};
    document.body.appendChild(box);
  }
  const listHtml=gebeList.length===0
    ?'<div style="text-align:center;padding:24px;color:#999">Gebe hayvan kaydı bulunamadı</div>'
    :gebeList.map(g=>{
        const kupe=g.hayvan?.kupe_no||g.hayvan?.devlet_kupe||g.toh.hayvan_id;
        const urgent=g.kalanGun<=7, overdue=g.kalanGun<0;
        const color=overdue?'#c0321a':urgent?'#b84c00':'#1a5c1a';
        const bg=overdue?'rgba(192,50,26,.06)':urgent?'rgba(184,76,0,.06)':'rgba(78,154,42,.04)';
        const badge=overdue?`<span style="background:#c0321a;color:#fff;border-radius:8px;padding:2px 7px;font-size:.62rem;font-weight:700">GECİKTİ ${Math.abs(g.kalanGun)} GÜN</span>`
          :urgent?`<span style="background:#b84c00;color:#fff;border-radius:8px;padding:2px 7px;font-size:.62rem;font-weight:700">⚡ ${g.kalanGun} GÜN</span>`
          :`<span style="background:rgba(78,154,42,.15);color:#1a5c1a;border-radius:8px;padding:2px 7px;font-size:.62rem;font-weight:700">${g.kalanGun} gün kaldı</span>`;
        return `<div onclick="anneSeç('${g.hayvan.id}','${kupe}','${g.dogumTahmini}','${g.toh.sperma||''}')" 
          style="padding:12px 14px;border-bottom:1px solid #eee;cursor:pointer;background:${bg};display:flex;justify-content:space-between;align-items:center">
          <div>
            <div style="font-weight:700;font-size:.88rem;color:${color}">${kupe}</div>
            <div style="font-size:.68rem;color:#666;margin-top:2px">${g.hayvan?.irk||'—'} · ${g.toh.tarih} · ${g.toh.sperma||'?'}</div>
            <div style="font-size:.65rem;color:#888;margin-top:1px">Tahmini doğum: ${fmtTarih(g.dogumTahmini)}</div>
          </div>${badge}
        </div>`;
      }).join('');
  box.innerHTML=`<div style="background:#fff;border-radius:18px 18px 0 0;width:100%;max-height:75vh;display:flex;flex-direction:column">
    <div style="padding:14px 16px 0;display:flex;justify-content:space-between;align-items:center">
      <div style="font-weight:800;font-size:1rem">🤰 Gebe Hayvanlar</div>
      <button onclick="document.getElementById('gebe-sec-modal').remove()" style="background:none;border:none;font-size:1.3rem;cursor:pointer;color:#999">✕</button>
    </div>
    <div style="font-size:.68rem;color:#999;padding:4px 16px 10px">280 güne yakınlığa göre sıralandı</div>
    <div style="padding:12px 14px;border-bottom:1px solid #eee">
      <input id="gebe-srch" oninput="gebeFiltrele()" placeholder="Küpe no ara…" style="width:100%;padding:8px 12px;border:1.5px solid var(--green);border-radius:8px;font-size:.85rem;outline:none;box-sizing:border-box">
    </div>
    <div id="gebe-list" style="overflow-y:auto;flex:1">${listHtml}</div>
    <div style="padding:12px 16px;border-top:1px solid #eee">
      <button onclick="document.getElementById('gebe-sec-modal').remove()" style="width:100%;padding:11px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">Kapat</button>
    </div>
  </div>`;
  box.style.display='flex';
  box._gebeList=gebeList;
  setTimeout(()=>document.getElementById('gebe-srch')?.focus(),100);
}
function gebeFiltrele(){
  const q=(document.getElementById('gebe-srch')?.value||'').toLowerCase();
  const box=document.getElementById('gebe-sec-modal');
  if(!box||!box._gebeList) return;
  const listEl=document.getElementById('gebe-list');
  const filtered=q?box._gebeList.filter(g=>{
    const kupe=(g.hayvan?.kupe_no||g.hayvan?.devlet_kupe||g.toh.hayvan_id||'').toLowerCase();
    return kupe.includes(q);
  }):box._gebeList;
  listEl.innerHTML=filtered.map(g=>{
    const kupe=g.hayvan?.kupe_no||g.hayvan?.devlet_kupe||g.toh.hayvan_id;
    const overdue=g.kalanGun<0, urgent=g.kalanGun<=7&&!overdue;
    const color=overdue?'#c0321a':urgent?'#b84c00':'#1a5c1a';
    return `<div onclick="anneSeç('${g.hayvan.id}','${kupe}','${g.dogumTahmini}','${g.toh.sperma||''}')" 
      style="padding:12px 14px;border-bottom:1px solid #eee;cursor:pointer">
      <div style="font-weight:700;font-size:.88rem;color:${color}">${kupe} — ${overdue?'GECİKTİ '+Math.abs(g.kalanGun)+' gün':g.kalanGun+' gün kaldı'}</div>
      <div style="font-size:.68rem;color:#666;margin-top:2px">${g.hayvan?.irk||'—'} · ${g.toh.sperma||'?'} · Tahmini: ${fmtTarih(g.dogumTahmini)}</div>
    </div>`;
  }).join('')||'<div style="padding:20px;text-align:center;color:#999">Eşleşen hayvan yok</div>';
}
function anneSeç(hayvanId,kupe,dogumTahmini,sperma){
  let hiddenInput=document.getElementById('b-anne');
  if(!hiddenInput){
    hiddenInput=document.createElement('input');
    hiddenInput.id='b-anne'; hiddenInput.type='hidden';
    document.getElementById('m-birth').appendChild(hiddenInput);
  }
  hiddenInput.value=hayvanId;
  document.getElementById('anne-secili-adi').textContent=kupe;
  document.getElementById('anne-secili-bilgi').textContent=`Tahmini doğum: ${fmtTarih(dogumTahmini)} · Sperma: ${sperma||'?'}`;
  document.getElementById('anne-secili-card').style.display='block';
  document.getElementById('b-anne-manual').style.display='none';
  document.getElementById('btn-gebe-sec').style.display='none';
  document.getElementById('gebe-sec-modal')?.remove();
}
function anneSecimSifirla(){
  const el=document.getElementById('b-anne'); if(el) el.value='';
  document.getElementById('anne-secili-card').style.display='none';
  document.getElementById('btn-gebe-sec').style.display='';
}

// ──────────────────────────────────────────
// ÜREME SEKMESİ
// ──────────────────────────────────────────
function uremeTab(tab,btn){
  _curUremeTab=tab;
  document.querySelectorAll('#pg-ureme .fs-btn').forEach(b=>b.classList.remove('on'));
  if(btn) btn.classList.add('on');
  loadUreme(tab);
}
async function loadUreme(tab='kizginlik'){
  _curUremeTab=tab;
  const el=document.getElementById('ureme-body');
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const today=new Date().toISOString().split('T')[0];
    if(tab==='kizginlik'){
      const list=await idbGetAll('kizginlik_log');
      list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
      el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-kizginlik')">🔴 Kızgınlık Ekle</button></div>`+
        (list.length?list.map(k=>{
          const h=_A.find(a=>a.id===k.hayvan_id);
          const kupe=h?(h.kupe_no||h.devlet_kupe):k.hayvan_id;
          return `<div class="hist-row" style="cursor:pointer" onclick="openDet('${k.hayvan_id}')">
            <div class="hist-dot" style="background:#e74c3c"></div>
            <div class="hist-main">
              <div class="hist-title">🔴 ${kupe} — ${k.belirti||'Kızgınlık'}</div>
              <div class="hist-sub">${k.tarih} ${k.notlar?'· '+k.notlar:''}</div>
            </div>
          </div>`;
        }).join(''):'<div class="empty"><div class="empty-ico">🔴</div>Kızgınlık kaydı yok</div>');
    }
    else if(tab==='tohumlama'){
      const list=await idbGetAll('tohumlama');
      list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
      el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-insem')">💉 Tohumlama Ekle</button></div>`+
        (list.length?list.map(t=>{
          const h=_A.find(a=>a.id===t.hayvan_id);
          const kupe=h?(h.kupe_no||h.devlet_kupe):t.hayvan_id;
          const sc=t.sonuc==='Gebe'?'var(--green)':t.sonuc==='Boş'||t.sonuc==='Abort'?'var(--red)':'var(--amber)';
          const dot=t.sonuc==='Gebe'?'var(--green2)':t.sonuc==='Boş'||t.sonuc==='Abort'?'var(--red2)':'var(--amber)';
          return `<div class="hist-row" style="cursor:pointer" onclick="openTohDet('${t.id}')">
            <div class="hist-dot" style="background:${dot}"></div>
            <div class="hist-main">
              <div class="hist-title">${kupe} — ${t.sperma||'?'}</div>
              <div class="hist-sub">${t.tarih} · ${t.deneme_no||1}. deneme · <b style="color:${sc}">${t.sonuc||'Bekliyor'}</b></div>
            </div>
          </div>`;
        }).join(''):'<div class="empty"><div class="empty-ico">💉</div>Tohumlama kaydı yok</div>');
    }
    else if(tab==='gebelik'){
      const tohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
      const gebeHayvanlar=_A.filter(a=>a.durum==='Gebe');
      const gebeIds=new Set(tohs.map(t=>t.hayvan_id));
      const extra=gebeHayvanlar.filter(a=>!gebeIds.has(a.id));
      tohs.sort((a,b)=>(a.tarih||'').localeCompare(b.tarih||''));
      el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-insem')">💉 Yeni Tohumlama</button></div>`+
        (tohs.length||extra.length?[...tohs.map(t=>{
          const h=_A.find(a=>a.id===t.hayvan_id);
          const kupe=h?(h.kupe_no||h.devlet_kupe):t.hayvan_id;
          const gun=Math.floor((new Date()-new Date(t.tarih))/86400000);
          const ay=Math.floor(gun/30), gKalan=gun%30;
          const dogumTahmini=dFwd(t.tarih,280);
          const kalanGun=Math.floor((new Date(dogumTahmini)-new Date())/86400000);
          const urgent=kalanGun<=14;
          return `<div class="hist-row" style="cursor:pointer" onclick="openDet('${t.hayvan_id}')">
            <div class="hist-dot" style="background:var(--green2)"></div>
            <div class="hist-main">
              <div class="hist-title" style="color:var(--green)">🤰 ${kupe}</div>
              <div class="hist-sub">${ay} ay ${gKalan} gün (${gun}. gün) · Tahmini: ${fmtTarih(dogumTahmini)}</div>
              <div class="hist-sub">${urgent?`<b style="color:var(--red)">⚡ ${kalanGun} gün kaldı!</b>`:`${kalanGun} gün kaldı`}</div>
            </div>
          </div>`;
        }),...extra.map(a=>{
          const kupe=a.kupe_no||a.devlet_kupe||a.id;
          return `<div class="hist-row" style="cursor:pointer" onclick="openDet('${a.id}')">
            <div class="hist-dot" style="background:var(--green2)"></div>
            <div class="hist-main">
              <div class="hist-title" style="color:var(--green)">🤰 ${kupe} (manuel gebe)</div>
              <div class="hist-sub">Tohumlama kaydı yok</div>
            </div>
          </div>`;
        })].join('')
        :'<div class="empty"><div class="empty-ico">🤰</div>Gebe hayvan yok</div>');
    }
    else if(tab==='dogum'){
      const list=await idbGetAll('dogum');
      list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
      el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-birth')">🐄 Doğum Kaydet</button></div>`+
        (list.length?list.map(b=>{
          const anne=_A.find(a=>a.id===b.anne_id);
          const anneKupe=anne?(anne.kupe_no||anne.devlet_kupe):b.anne_id;
          return `<div class="hist-row" style="cursor:pointer" onclick="openDet('${b.anne_id}')">
            <div class="hist-dot" style="background:var(--green2)"></div>
            <div class="hist-main">
              <div class="hist-title">🐄 ${anneKupe} → <b>${b.yavru_kupe}</b> (${b.yavru_cins||'?'})</div>
              <div class="hist-sub">${b.tarih} · ${b.dogum_tipi||'Normal'}</div>
            </div>
          </div>`;
        }).join(''):'<div class="empty"><div class="empty-ico">🐄</div>Doğum kaydı yok</div>');
    }
    else if(tab==='abort'){
      const list=await getData('tohumlama',t=>t.abort===true||t.sonuc==='Abort');
      list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
      el.innerHTML=(list.length?list.map(t=>{
        const h=_A.find(a=>a.id===t.hayvan_id);
        const kupe=h?(h.kupe_no||h.devlet_kupe):t.hayvan_id;
        return `<div class="hist-row" style="cursor:pointer" onclick="openDet('${t.hayvan_id}')">
          <div class="hist-dot" style="background:var(--red2)"></div>
          <div class="hist-main">
            <div class="hist-title" style="color:var(--red)">⚠️ ${kupe} — Abort</div>
            <div class="hist-sub">${t.tarih} ${t.abort_notlar?'· '+t.abort_notlar:''}</div>
          </div>
        </div>`;
      }).join(''):'<div class="empty"><div class="empty-ico">⚠️</div>Abort kaydı yok</div>');
    }
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
}

// ──────────────────────────────────────────
// GEÇMİŞ
// ──────────────────────────────────────────
async function loadGecmis(f,btn){
  _curGecmisFilter=f;
  if(btn){ document.querySelectorAll('#pg-gecmis .fs-btn').forEach(b=>b.classList.remove('on')); btn.classList.add('on'); }
  const el=document.getElementById('gecmis-body');
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const entries=[];
    if(f==='hepsi'||f==='dogum')  (await idbGetAll('dogum')).forEach(r=>entries.push({type:'dogum',date:r.tarih,data:r}));
    if(f==='hepsi'||f==='tohumlama') (await idbGetAll('tohumlama')).forEach(r=>entries.push({type:'tohumlama',date:r.tarih,data:r}));
    if(f==='hepsi'||f==='hastalik') (await idbGetAll('hastalik_log')).forEach(r=>entries.push({type:'hastalik',date:r.tarih,data:r}));
    if(f==='hepsi'||f==='gorev') (await getData('gorev_log',t=>t.tamamlandi&&!t.parent_id)).forEach(r=>entries.push({type:'gorev',date:r.tamamlanma_tarihi||r.hedef_tarih,data:r}));
    if(f==='hepsi'||f==='hayvan'){
      const islemTipler=['HAYVAN_EKLENDI','ABORT_KAYDI','KIZGINLIK_KAYDI'];
      (await idbGetAll('islem_log'))
        .filter(r=>islemTipler.includes(r.tip))
        .forEach(r=>entries.push({type:'islem',date:(r.tarih||r.created_at||'').slice(0,10),data:r}));
    }
    entries.sort((a,b)=>(b.date||'').localeCompare(a.date||''));
    if(!entries.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Kayıt bulunamadı</div>'; return; }
    el.innerHTML=entries.slice(0,300).map(e=>{
      const {type,date,data}=e;
      const d=fmtTarih(date);
      const hk=HEKIMLER.find(h=>h.id===data.hekim_id);
      const hkName=hk?` · ${hk.ad}`:'';
      const hayvanKey=data.hayvan_id||data.anne_id;
      const hayvanObj=_A.find(a=>a.id===hayvanKey||a.kupe_no===hayvanKey);
      const hayvanLabel=hayvanObj?(hayvanObj.kupe_no||hayvanObj.devlet_kupe||hayvanKey):hayvanKey;
      const hayvanVarMi=hayvanKey&&hayvanObj;
      let oc='';
      if(type==='hastalik') oc=`onclick="openHstDet('${data.id}')" style="cursor:pointer"`;
      else if(type==='tohumlama') oc=`onclick="openTohDet('${data.id}')" style="cursor:pointer"`;
      else if(type==='dogum'&&hayvanVarMi) oc=`onclick="openDet('${hayvanKey}')" style="cursor:pointer"`;
      const ISLEM_ICO={'HAYVAN_EKLENDI':'🐮','ABORT_KAYDI':'⚠️','KIZGINLIK_KAYDI':'🔴'};
      const ico={dogum:'🐄',tohumlama:'💉',hastalik:'🏥',gorev:'✅',islem:ISLEM_ICO[data.tip]||'📋'}[type];
      const icoBg={dogum:'rgba(78,154,42,.1)',tohumlama:'rgba(42,107,181,.1)',hastalik:'rgba(192,50,26,.1)',gorev:'var(--card2)',islem:'rgba(120,120,120,.1)'}[type];
      let title='', sub='';
      if(type==='dogum'){ const anneObj=_A.find(a=>a.id===data.anne_id||a.kupe_no===data.anne_id); const anneLabel=anneObj?(anneObj.kupe_no||anneObj.devlet_kupe||data.anne_id):data.anne_id; title=`${anneLabel||'?'} → ${data.yavru_kupe||'?'} (${data.yavru_cins||'?'})`; sub=`${data.dogum_tipi||'Normal'}${hkName}`; }
      if(type==='tohumlama'){ title=`${hayvanLabel||'?'} — ${data.sperma||'?'}`; const sc=data.sonuc==='Gebe'?'var(--green)':data.sonuc==='Boş'?'var(--red)':'var(--amber)'; sub=`${data.deneme_no||1}. deneme · <b style="color:${sc}">${data.sonuc||'Bekliyor'}</b>${hkName}`; }
      if(type==='hastalik'){ title=`${hayvanLabel||'?'} — ${data.tani||'?'}`; const sc=data.durum==='Aktif'?'var(--red)':'var(--green)'; sub=`${data.siddet||''} · <b style="color:${sc}">${data.durum||''}</b>${hkName}`; }
      if(type==='gorev'){ const gHayvan=_A.find(a=>a.id===data.hayvan_id); const gLabel=gHayvan?(gHayvan.kupe_no||gHayvan.devlet_kupe):data.hayvan_id; title=`${gLabel||'GENEL'} — ${data.aciklama||''}`; sub=`<span class="pill ${data.gorev_tipi||'DIGER'}">${(data.gorev_tipi||'').replace(/_/g,' ')}</span>${hkName}`; }
      if(type==='islem'){
        const snap=data.snapshot||{}; 
        const hayvanObj2=_A.find(a=>a.id===data.ana_hayvan_id);
        const kupe=hayvanObj2?(hayvanObj2.kupe_no||hayvanObj2.devlet_kupe):snap.kupe_no||snap.devlet_kupe||data.ana_hayvan_id||'?';
        const etiket={'HAYVAN_EKLENDI':'🐮 Hayvan Eklendi','ABORT_KAYDI':'⚠️ Abort','KIZGINLIK_KAYDI':'🔴 Kızgınlık'}[data.tip]||data.tip;
        title=`${kupe} — ${etiket}`; sub=snap.irk||snap.grup||'';
        if(snap.kupe_no||snap.devlet_kupe) oc=`onclick="openDet('${data.ana_hayvan_id}')" style="cursor:pointer"`;
      }
      return `<div style="background:var(--card);border:1px solid var(--card3);border-radius:var(--r2);padding:11px 13px;margin-bottom:6px;display:flex;gap:10px;align-items:flex-start" ${oc}>
        <div style="width:36px;height:36px;border-radius:10px;background:${icoBg};display:flex;align-items:center;justify-content:center;font-size:1.1rem;flex-shrink:0">${ico}</div>
        <div style="flex:1;min-width:0">
          <div style="font-weight:700;font-size:.84rem;color:var(--ink)">${title}</div>
          <div style="font-size:.68rem;color:var(--ink3);margin-top:2px">${sub}</div>
          <div style="font-size:.62rem;color:var(--ink3);margin-top:3px">${type==='gorev'?'✅ '+d:d}</div>
        </div>
      </div>`;
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
}

// ──────────────────────────────────────────
// STOK
// ──────────────────────────────────────────
async function loadStock(){
  try {
    const [stk,moves]=await Promise.all([idbGetAll('stok'),getData('stok_hareket',m=>!m.iptal)]);
    _S=stk.map(s=>{ const used=moves.filter(m=>m.stok_id===s.id).reduce((a,m)=>a+(+m.miktar||0),0); const guncel=(+s.baslangic_miktar||0)-used; return{...s,guncel,durum:guncel<0?'neg':guncel<=(+s.esik||0)?'crit':'ok'}; });
    window._appState=window._appState||{}; window._appState.stok=_S;
  } catch(e){ console.error(e); }
}
function openStk(id){
  _curStk=_S.find(s=>s.id===id); if(!_curStk) return;
  document.getElementById('m-stk-title').textContent='📦 '+_curStk.urun_adi;
  document.getElementById('se-urun').value=_curStk.urun_adi;
  document.getElementById('se-birim').textContent=_curStk.birim||'?';
  g('se-mik').value=''; g('se-not').value='';
  openM('m-stk');
}
async function loadStokList(){
  const el=document.getElementById('stok-list-body'); if(!el) return;
  try {
    await loadStock();
    if(!_S.length){
      el.innerHTML='<div style="text-align:center;padding:12px;color:var(--ink3);font-size:.78rem">📦 Henüz stok ürünü eklenmemiş<br><button class="sh-link" onclick="openM(\'m-stok-add\')" style="margin-top:6px;display:block;margin:6px auto 0">İlk ürünü ekle →</button></div>';
      return;
    }
    const gruplar={
      'Sperma':_S.filter(s=>s.kategori==='Sperma'||(s.urun_adi||'').toLowerCase().includes('sperma')||(s.urun_adi||'').toLowerCase().includes('doz')),
      'İlaç':_S.filter(s=>s.kategori==='İlaç'||(!s.kategori&&!(s.urun_adi||'').toLowerCase().includes('sperma')&&!(s.urun_adi||'').toLowerCase().includes('ekipman'))),
      'Ekipman':_S.filter(s=>s.kategori==='Ekipman'||(s.urun_adi||'').toLowerCase().includes('ekipman')),
    };
    const stokKart=(s)=>{
      const pct=Math.max(0,Math.min(100,s.esik>0?(s.guncel/((+s.baslangic_miktar||1)||1))*100:100));
      const barClr=s.durum==='neg'?'var(--red)':s.durum==='crit'?'var(--amber)':'var(--green)';
      return `<div style="background:var(--card);border:1px solid var(--card3);border-radius:10px;padding:11px 13px;margin-bottom:7px">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <div><div style="font-weight:700;font-size:.88rem;color:var(--ink)">${s.urun_adi}</div>
            <div style="font-size:.65rem;color:var(--ink3);margin-top:2px">Eşik: ${s.esik||0} ${s.birim||''}</div></div>
          <div style="text-align:right">
            <div style="font-size:1.2rem;font-weight:800;color:${barClr}">${(s.guncel||0).toFixed(s.birim==='adet'?0:1)}</div>
            <div style="font-size:.6rem;color:var(--ink3)">${s.birim||''}</div>
          </div>
        </div>
        <div style="height:4px;background:var(--card2);border-radius:2px;margin-top:8px;overflow:hidden">
          <div style="height:100%;width:${pct}%;background:${barClr};border-radius:2px;transition:width .3s"></div>
        </div>
        <div style="display:flex;gap:6px;margin-top:8px">
          <button onclick="openStk('${s.id}')" style="flex:1;padding:6px;background:var(--green);color:#fff;border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">+ Stok Ekle</button>
          <button onclick="stokHareketGor('${s.id}')" style="flex:1;padding:6px;background:var(--card2);color:var(--ink3);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">Hareketler</button>
        </div>
      </div>`;
    };
    let html='';
    const grupIkon={'Sperma':'💉','İlaç':'💊','Ekipman':'🔧'};
    Object.entries(gruplar).forEach(([grup,liste])=>{
      if(!liste.length) return;
      html+=`<div style="margin:10px 0 5px;font-size:.72rem;font-weight:700;color:var(--ink3);text-transform:uppercase;letter-spacing:.07em">${grupIkon[grup]||'📦'} ${grup} <span style="color:var(--ink3);font-weight:400">(${liste.length})</span></div>`;
      html+=liste.map(stokKart).join('');
    });
    el.innerHTML=html;
  } catch(e){ if(el) el.innerHTML=`<div style="color:var(--red);padding:8px;font-size:.75rem">⚠️ ${e.message}</div>`; }
}
async function stokHareketGor(stokId){
  const s=_S.find(x=>x.id===stokId); if(!s) return;
  const mvs=await getData('stok_hareket',m=>m.stok_id===stokId&&!m.iptal);
  mvs.sort((a,b)=>((b.tarih||b.id)||'').localeCompare((a.tarih||a.id)||''));
  const used=mvs.reduce((t,m)=>t+(+m.miktar||0),0);
  const kalan=(+s.baslangic_miktar||0)-used;
  let box=document.getElementById('stok-hrkt-modal');
  if(!box){
    box=document.createElement('div');
    box.id='stok-hrkt-modal';
    box.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:200;display:flex;align-items:flex-end';
    box.onclick=e=>{if(e.target===box)box.remove();};
    document.body.appendChild(box);
  }
  box.innerHTML=`<div style="background:#fff;border-radius:18px 18px 0 0;width:100%;max-height:70vh;overflow-y:auto;padding:16px">
    <div style="font-weight:800;font-size:1rem;margin-bottom:4px">${s.urun_adi}</div>
    <div style="font-size:.75rem;color:#666;margin-bottom:12px">Başlangıç: <b>${s.baslangic_miktar||0} ${s.birim||''}</b> · Kullanılan: <b>${used.toFixed(1)} ${s.birim||''}</b> · Kalan: <b style="color:${kalan<=(s.esik||0)?'#c0321a':'#2d6a2d'}">${kalan.toFixed(1)} ${s.birim||''}</b></div>
    ${mvs.length===0?'<div style="color:#999;text-align:center;padding:20px">Henüz hareket yok</div>':
      mvs.map(m=>`<div style="padding:8px 0;border-bottom:1px solid #eee;font-size:.8rem;display:flex;justify-content:space-between">
        <div><div style="font-weight:600">${m.tur||'Kullanım'}</div><div style="color:#999;font-size:.7rem">${m.notlar||''}</div></div>
        <div style="font-weight:700;color:#c0321a">-${m.miktar} ${s.birim||''}</div>
      </div>`).join('')}
    <button onclick="document.getElementById('stok-hrkt-modal').remove()" style="width:100%;margin-top:12px;padding:12px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">Kapat</button>
  </div>`;
  box.style.display='flex';
}

// ──────────────────────────────────────────
// RAPORLAR
// ──────────────────────────────────────────
async function loadRaporlar(){
  const el=document.getElementById('raporlar-body'); if(!el) return;
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const [animals,tohs,diseases,births,moves,stock]=await Promise.all([
      idbGetAll('hayvanlar'),
      idbGetAll('tohumlama'),
      idbGetAll('hastalik_log'),
      idbGetAll('dogum'),
      getData('stok_hareket',m=>!m.iptal),
      idbGetAll('stok'),
    ]);
    const aktif=animals.filter(a=>a.durum==='Aktif');
    const gebe=tohs.filter(t=>t.sonuc==='Gebe');
    const gebeOran=aktif.length?Math.round(gebe.length/aktif.length*100):0;
    const tohToplam=tohs.length;
    const tohGebe=tohs.filter(t=>t.sonuc==='Gebe').length;
    const tohBos=tohs.filter(t=>t.sonuc==='Boş').length;
    const gebelikOran=tohToplam?Math.round(tohGebe/tohToplam*100):0;
    const abortlar=tohs.filter(t=>t.abort||t.sonuc==='Abort').length;

    // Irk dağılımı
    const irkMap={};
    aktif.forEach(a=>{ const irk=a.irk||'Bilinmiyor'; irkMap[irk]=(irkMap[irk]||0)+1; });
    const irkSorted=Object.entries(irkMap).sort((a,b)=>b[1]-a[1]);

    // Hastalık kategorileri
    const katMap={};
    diseases.forEach(d=>{ const k=d.kategori||'Diğer'; katMap[k]=(katMap[k]||0)+1; });
    const katSorted=Object.entries(katMap).sort((a,b)=>b[1]-a[1]);

    // Stok durumu
    const stkNet={};
    stock.forEach(s=>{ const used=moves.filter(m=>m.stok_id===s.id).reduce((a,m)=>a+(+m.miktar||0),0); stkNet[s.id]=(+s.baslangic_miktar||0)-used; });
    const kritikStok=stock.filter(s=>stkNet[s.id]>=0&&stkNet[s.id]<=(+s.esik||0));
    const negStk=stock.filter(s=>stkNet[s.id]<0);

    const statKart=(label,val,sub='',clr='var(--green)')=>`<div style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;flex:1;min-width:130px">
      <div style="font-size:1.6rem;font-weight:800;color:${clr}">${val}</div>
      <div style="font-size:.78rem;font-weight:700;color:var(--ink);margin-top:2px">${label}</div>
      ${sub?`<div style="font-size:.65rem;color:var(--ink3);margin-top:2px">${sub}</div>`:''}
    </div>`;

    let h=`<div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px">
      ${statKart('Aktif Hayvan',aktif.length,'toplam: '+animals.length)}
      ${statKart('Gebe',gebe.length,`%${gebeOran} oran`,'var(--green)')}
      ${statKart('Gebelik Oranı','%'+gebelikOran,`${tohGebe}/${tohToplam} tohumlama`,gebelikOran>=60?'var(--green)':'var(--amber)')}
      ${statKart('Abort',abortlar,'toplam kayıt',abortlar>0?'var(--red)':'var(--ink3)')}
      ${statKart('Aktif Vaka',diseases.filter(d=>d.durum==='Aktif').length,'hastalık',diseases.filter(d=>d.durum==='Aktif').length>0?'var(--red)':'var(--green)')}
      ${statKart('Toplam Doğum',births.length,'')}
    </div>`;

    if(irkSorted.length){
      h+=`<div style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">🐄 Irk Dağılımı</div>
        ${irkSorted.map(([irk,sayi])=>{
          const pct=aktif.length?Math.round(sayi/aktif.length*100):0;
          return `<div style="margin-bottom:8px">
            <div style="display:flex;justify-content:space-between;font-size:.78rem;margin-bottom:3px">
              <span style="font-weight:600">${irk}</span><span style="color:var(--ink3)">${sayi} (${pct}%)</span>
            </div>
            <div style="height:6px;background:var(--card2);border-radius:3px;overflow:hidden">
              <div style="height:100%;width:${pct}%;background:var(--green);border-radius:3px"></div>
            </div>
          </div>`;
        }).join('')}
      </div>`;
    }

    if(katSorted.length){
      h+=`<div style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">🏥 Hastalık Kategorileri</div>
        ${katSorted.map(([kat,sayi])=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>${kat}</span><span style="font-weight:700;color:var(--red)">${sayi}</span>
        </div>`).join('')}
      </div>`;
    }

    if(negStk.length||kritikStok.length){
      h+=`<div style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">📦 Stok Durumu</div>
        ${negStk.map(s=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>🆘 ${s.urun_adi}</span><span style="font-weight:700;color:var(--red)">${stkNet[s.id].toFixed(1)} ${s.birim||''}</span>
        </div>`).join('')}
        ${kritikStok.map(s=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>⚠️ ${s.urun_adi}</span><span style="font-weight:700;color:var(--amber)">${stkNet[s.id].toFixed(1)} ${s.birim||''}</span>
        </div>`).join('')}
      </div>`;
    }

    if(!navigator.onLine){
      h+=`<div style="background:rgba(180,140,0,.08);border:1px solid rgba(180,140,0,.25);border-radius:10px;padding:10px 13px;font-size:.75rem;color:var(--amber)">
        ⚠️ Çevrimdışı — veriler yerel cache'ten. Online olunca yenileyin.
      </div>`;
    }
    el.innerHTML=h;
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
}

// ──────────────────────────────────────────
// ÇIKANLAR (Satılan/Kesilen/Ölen hayvanlar)
// ──────────────────────────────────────────
async function loadCikanlar(){
  const el=document.getElementById('cikanlar-body'); if(!el) return;
  try {
    const all=await idbGetAll('hayvanlar');
    const cikanlar=all.filter(a=>a.durum&&a.durum!=='Aktif').sort((a,b)=>(b.cikis_tarihi||b.id||'').localeCompare(a.cikis_tarihi||a.id||''));
    if(!cikanlar.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Çıkan hayvan kaydı yok</div>'; return; }
    const durumRenk={Satıldı:'var(--blue)',Kesildi:'var(--amber)',Öldü:'var(--red)',Kayıp:'var(--red)'};
    el.innerHTML=cikanlar.map(a=>{
      const kupe=a.kupe_no||a.devlet_kupe||a.id;
      const clr=durumRenk[a.durum]||'var(--ink3)';
      return `<div style="background:var(--card);border:1px solid var(--card3);border-radius:10px;padding:11px 13px;margin-bottom:6px">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <div>
            <div style="font-weight:700;font-size:.88rem">${kupe}</div>
            <div style="font-size:.7rem;color:var(--ink3);margin-top:2px">${a.irk||'—'} · ${a.grup||'—'}</div>
          </div>
          <div style="text-align:right">
            <div style="font-size:.75rem;font-weight:700;color:${clr}">${a.durum}</div>
            <div style="font-size:.65rem;color:var(--ink3)">${fmtTarih(a.cikis_tarihi)||'—'}</div>
          </div>
        </div>
        ${a.cikis_sebebi?`<div style="font-size:.7rem;color:var(--ink3);margin-top:5px;padding-top:5px;border-top:1px solid var(--card2)">${a.cikis_sebebi}${a.satis_fiyati?' · '+a.satis_fiyati+' ₺':''}</div>`:''}
      </div>`;
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${e.message}</div>`; }
}

// ──────────────────────────────────────────
// GÖREV DETAY MODAL
// ──────────────────────────────────────────
async function openTaskDet(id){
  const all=await idbGetAll('gorev_log');
  const t=all.find(x=>x.id===id); if(!t) return;
  if(t.tamamlandi){ toast('Bu görev zaten tamamlanmış'); return; }
  _curTaskDet=t;
  const today=new Date().toISOString().split('T')[0];
  const hekim=[...HEKIMLER,...(_customHekimler||[])].find(h=>h.id===t.hekim_id);
  const isLate=t.hedef_tarih<today;
  const hayvanLabel=_A.find(a=>a.id===t.hayvan_id);
  document.getElementById('td-hayvan').textContent=(hayvanLabel?.kupe_no||hayvanLabel?.devlet_kupe)||(t.hayvan_id?.length>20?'Buzağı-'+t.hayvan_id.slice(-6):t.hayvan_id)||'GENEL GÖREV';
  document.getElementById('td-aciklama').textContent=t.aciklama||'';
  const meta=[];
  meta.push(`📅 ${fmtTarih(t.hedef_tarih)}${isLate?' ⚠️ Gecikmiş':''}`);
  if(hekim) meta.push(`👨‍⚕️ ${hekim.ad}`);
  if(t.stok_id) meta.push(`💊 ${t.stok_id}`);
  meta.push(`🏷 ${(t.gorev_tipi||'DIGER').replace(/_/g,' ')}`);
  document.getElementById('td-meta').innerHTML=meta.map(m=>`<span style="background:var(--card2);padding:3px 8px;border-radius:10px">${m}</span>`).join('');
  const subs=all.filter(s=>s.parent_id===id&&!s.tamamlandi);
  const subsDone=all.filter(s=>s.parent_id===id&&s.tamamlandi);
  const subsEl=document.getElementById('td-subs');
  if(subs.length+subsDone.length>0){
    subsEl.style.display='block';
    subsEl.innerHTML=`<div style="font-size:.65rem;font-weight:700;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Alt Görevler (${subsDone.length}/${subs.length+subsDone.length})</div>`
      +[...subsDone,...subs].map(s=>`<div style="display:flex;align-items:center;gap:8px;padding:5px 0;border-bottom:1px solid var(--card2)">
        <div style="width:18px;height:18px;border-radius:50%;background:${s.tamamlandi?'var(--green)':'var(--card2)'};border:2px solid ${s.tamamlandi?'var(--green)':'var(--card3)'};flex-shrink:0"></div>
        <span style="font-size:.8rem;color:var(--ink);${s.tamamlandi?'text-decoration:line-through;opacity:.6':''}">${s.aciklama}</span>
      </div>`).join('');
  } else { subsEl.style.display='none'; }
  openM('m-task-det');
}
async function detayTamamla(){
  if(!_curTaskDet) return;
  const btn=document.getElementById('td-tamam-btn');
  if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
  try {
    await doneTask(_curTaskDet.id,_curTaskDet.hayvan_id||'',_curTaskDet.stok_id||'',+_curTaskDet.miktar||0,_curTaskDet.padok_hedef||'',{disabled:false,innerHTML:''});
    closeM('m-task-det');
  } catch(e){ toast(e.message,true); }
  if(btn){btn.disabled=false;btn.textContent='✅ Tamamlandı Olarak İşaretle';}
}
async function detayIptal(){
  if(!_curTaskDet) return;
  if(!confirm('Bu görevi iptal etmek istediğinizden emin misiniz?')) return;
  const t=_curTaskDet;
  await write('gorev_log',{...t,tamamlandi:true,tamamlanma_tarihi:new Date().toISOString(),iptal:true},'PATCH',`id=eq.${t.id}`);
  const subs=await getData('gorev_log',s=>s.parent_id===t.id&&!s.tamamlandi);
  for(const s of subs) await write('gorev_log',{...s,tamamlandi:true,iptal:true},'PATCH',`id=eq.${s.id}`);
  closeM('m-task-det');
  toast('🗑 Görev iptal edildi');
  loadTasks(_curTaskFilter||'today');
  loadDash();
}

// ──────────────────────────────────────────
// HASTALIK DETAY
// ──────────────────────────────────────────

// ══════════════════════════════════════════
// VAKA SİSTEMİ (Migration 022)
// ══════════════════════════════════════════

let _curCase = null;
let _curDayId = null;
let _drugsCache = [];

async function loadDrugsCache() {
  if (!_drugsCache.length) {
    _drugsCache = await idbGetAll('drugs');
  }
  return _drugsCache;
}

async function renderCasesForAnimal(animalId) {
  const allCases = await idbGetAll('cases');
  const animalCases = allCases
    .filter(c => c.animal_id === animalId)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  if (!animalCases.length) return '<div class="empty"><div class="empty-ico">✅</div>Aktif vaka yok</div>';
  const allDiseases = await idbGetAll('diseases');
  return animalCases.map(c => {
    const dis = allDiseases.find(d => d.id === c.disease_id);
    const isActive = c.status === 'active';
    return `<div class="hist-row" onclick="openCaseDet('${c.id}')" style="cursor:pointer">
      <div class="hist-dot" style="background:${isActive ? 'var(--red2)' : 'var(--green2)'}"></div>
      <div class="hist-main">
        <div class="hist-title">${dis?.name || '?'}</div>
        <div class="hist-sub">${fmtTarih(c.start_date)} · <b style="color:${isActive ? 'var(--red)' : 'var(--green)'}">${isActive ? 'Aktif' : 'Kapalı'}</b></div>
        ${c.notes ? `<div class="hist-sub" style="margin-top:2px">${c.notes}</div>` : ''}
      </div>
    </div>`;
  }).join('');
}

async function openCaseDet(caseId) {
  const allCases = await idbGetAll('cases');
  const c = allCases.find(x => x.id === caseId);
  if (!c) { toast('Vaka bulunamadı', true); return; }
  _curCase = c;
  _curDayId = null;
  const allDiseases = await idbGetAll('diseases');
  const dis = allDiseases.find(d => d.id === c.disease_id);
  const hayvan = _A.find(a => a.id === c.animal_id);
  const hayvanLabel = hayvan ? (hayvan.kupe_no || hayvan.devlet_kupe || hayvan.id) : c.animal_id;
  const isActive = c.status === 'active';
  document.getElementById('cd-hayvan').textContent = hayvanLabel;
  document.getElementById('cd-tani').textContent = `🏥 ${dis?.name || '?'}`;
  const chips = [
    `<span style="background:${isActive ? 'rgba(192,50,26,.12)' : 'rgba(78,154,42,.12)'};color:${isActive ? 'var(--red)' : 'var(--green)'};padding:3px 9px;border-radius:10px;font-size:.7rem;font-weight:700">${isActive ? 'Aktif' : 'Kapalı'}</span>`,
    dis?.category ? `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">${dis.category}</span>` : '',
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">📅 ${fmtTarih(c.start_date)}</span>`,
  ];
  document.getElementById('cd-meta').innerHTML = chips.filter(Boolean).join('');
  const notesEl = document.getElementById('cd-notes');
  if (c.notes) { notesEl.textContent = c.notes; notesEl.style.display = 'block'; }
  else { notesEl.style.display = 'none'; }
  const gunBtn = document.getElementById('cd-gun-ekle-btn');
  const kapatBtn = document.getElementById('cd-kapat-btn');
  if (gunBtn) gunBtn.style.display = isActive ? 'block' : 'none';
  if (kapatBtn) kapatBtn.style.display = isActive ? 'block' : 'none';
  caseIlacFormKapat();
  await loadDrugsCache();
  await renderCaseTimeline(caseId);
  openM('m-case-det');
}

async function renderCaseTimeline(caseId) {
  const el = document.getElementById('cd-timeline');
  if (!el) return;
  el.innerHTML = '<div style="text-align:center;padding:12px;color:var(--ink3);font-size:.8rem">Yükleniyor…</div>';
  try {
    const { data: days, error } = await db
      .from('treatment_days').select('*').eq('case_id', caseId).order('day_no', { ascending: true });
    if (error) throw error;
    if (!days || !days.length) {
      el.innerHTML = '<div class="empty" style="padding:14px 0"><div class="empty-ico">📅</div>Henüz tedavi günü yok — "+ Gün Ekle" ile başlayın</div>';
      return;
    }
    const dayIds = days.map(d => d.id);
    const { data: admins } = await db
      .from('drug_administrations').select('*, drugs(name, default_unit)')
      .in('treatment_day_id', dayIds).order('created_at', { ascending: true });
    const adminsByDay = {};
    (admins || []).forEach(a => {
      if (!adminsByDay[a.treatment_day_id]) adminsByDay[a.treatment_day_id] = [];
      adminsByDay[a.treatment_day_id].push(a);
    });
    const isActive = _curCase?.status === 'active';
    el.innerHTML = days.map(day => {
      const dayAdmins = adminsByDay[day.id] || [];
      const drugRows = dayAdmins.length
        ? dayAdmins.map(a => `
            <div style="display:flex;align-items:center;justify-content:space-between;padding:5px 0;border-bottom:1px solid var(--card2)">
              <div>
                <span style="font-weight:600;font-size:.82rem">${a.drugs?.name || '?'}</span>
                <span style="color:var(--ink3);font-size:.78rem"> ${a.dose} ${a.unit}</span>
                ${a.route ? `<span style="margin-left:5px;background:var(--card2);padding:1px 6px;border-radius:7px;font-size:.68rem">${a.route}</span>` : ''}
              </div>
              ${isActive ? `<button onclick="deleteDrugAdmin('${a.id}','${caseId}')" style="background:none;border:none;color:var(--red);font-size:.85rem;cursor:pointer;padding:2px 6px">🗑</button>` : ''}
            </div>`).join('')
        : '<div style="color:var(--ink3);font-size:.78rem;padding:4px 0">İlaç kaydı yok</div>';
      return `
        <div style="margin-bottom:12px;border:1.5px solid var(--card3);border-radius:12px;overflow:hidden">
          <div style="background:var(--card2);padding:8px 12px;display:flex;align-items:center;justify-content:space-between">
            <div>
              <span style="font-weight:800;font-size:.85rem">Gün ${day.day_no}</span>
              <span style="color:var(--ink3);font-size:.75rem;margin-left:8px">${fmtTarih(day.treatment_date)}</span>
            </div>
            ${isActive ? `<button onclick="caseIlacFormAc('${day.id}','${day.day_no}')" style="font-size:.68rem;padding:3px 9px;background:var(--blue);color:#fff;border:none;border-radius:8px;cursor:pointer">+ İlaç</button>` : ''}
          </div>
          <div style="padding:8px 12px">${drugRows}</div>
        </div>`;
    }).join('');
  } catch(e) {
    el.innerHTML = `<div style="color:var(--red);font-size:.8rem;padding:8px">Yüklenemedi: ${e.message}</div>`;
  }
}

function caseIlacFormAc(dayId, dayNo) {
  _curDayId = dayId;
  const form = document.getElementById('cd-ilac-form');
  const label = document.getElementById('cd-ilac-gun-label');
  if (label) label.textContent = `Gün ${dayNo}`;
  const sel = document.getElementById('cd-drug-id');
  if (sel && _drugsCache.length) {
    sel.innerHTML = '<option value="">İlaç seçin…</option>'
      + _drugsCache.map(d => `<option value="${d.id}" data-unit="${d.default_unit || ''}" data-route="${d.default_route || ''}">${d.name}</option>`).join('');
  }
  document.getElementById('cd-dose').value = '';
  document.getElementById('cd-unit').value = '';
  document.getElementById('cd-route').value = '';
  if (form) form.style.display = 'block';
  form?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function caseIlacFormKapat() {
  _curDayId = null;
  const form = document.getElementById('cd-ilac-form');
  if (form) form.style.display = 'none';
}

function caseDrugSecildi() {
  const sel = document.getElementById('cd-drug-id');
  const opt = sel?.options[sel.selectedIndex];
  if (!opt) return;
  const unit  = opt.getAttribute('data-unit')  || '';
  const route = opt.getAttribute('data-route') || '';
  const unitEl  = document.getElementById('cd-unit');
  const routeEl = document.getElementById('cd-route');
  if (unitEl && !unitEl.value)   unitEl.value  = unit;
  if (routeEl && !routeEl.value) routeEl.value = route;
}

async function deleteDrugAdmin(adminId, caseId) {
  if (!confirm('Bu ilaç kaydı silinsin mi?')) return;
  try {
    const res = await rpc('remove_drug_administration', { p_admin_id: adminId });
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
    toast('✅ İlaç kaydı silindi');
    await renderCaseTimeline(caseId);
    pullTables(['stok_hareket']).then(renderSafe).catch(console.warn);
  } catch(e) { toast('❌ ' + e.message, true); }
}

// ── VAKA DETAY (CLN-03) ─────────────────────

async function openCaseDet(caseId) {
  const cases    = await idbGetAll('cases');
  const diseases = await idbGetAll('diseases');
  const c = cases.find(x => x.id === caseId);
  if (!c) { toast('Vaka bulunamadı', true); return; }
  _curCase = c;

  const disease = diseases.find(d => d.id === c.disease_id);
  const hayvan  = _A.find(a => a.id === c.animal_id);
  const kupe    = hayvan ? (hayvan.kupe_no || hayvan.devlet_kupe || c.animal_id) : c.animal_id;

  document.getElementById('cd-hayvan').textContent  = kupe;
  document.getElementById('cd-disease').textContent = '🏥 ' + (disease?.name || '?');
  document.getElementById('cd-notes').textContent   = c.notes || '';

  const aktif = c.status === 'active';
  const chips = [
    `<span style="background:${aktif?'rgba(192,50,26,.12)':'rgba(78,154,42,.12)'};color:${aktif?'var(--red)':'var(--green)'};padding:3px 9px;border-radius:10px;font-size:.7rem;font-weight:700">${aktif?'Aktif':'Kapalı'}</span>`,
    disease?.category ? `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">📂 ${disease.category}</span>` : '',
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">📅 ${fmtTarih(c.start_date)}</span>`,
    c.closed_at ? `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">🔒 ${fmtTarih(c.closed_at)}</span>` : '',
  ];
  document.getElementById('cd-meta').innerHTML = chips.filter(Boolean).join('');

  document.getElementById('cd-gun-bolum').style.display   = aktif ? 'block' : 'none';
  document.getElementById('cd-kapat-bolum').style.display = aktif ? 'block' : 'none';

  await _loadCaseDrugsCache();
  await renderCaseTimeline(caseId);
  openM('m-case-det');
}

async function renderCaseTimeline(caseId) {
  const el = document.getElementById('cd-timeline');
  if (!el) return;
  el.innerHTML = '<span style="color:var(--ink3);font-size:.78rem">Yükleniyor…</span>';
  try {
    const { data, error } = await db
      .from('treatment_timeline')
      .select('*')
      .eq('case_id', caseId)
      .order('day_no', { ascending: true });
    if (error) throw error;
    if (!data || !data.length) {
      el.innerHTML = '<span style="color:var(--ink3);font-size:.78rem">Henüz tedavi günü yok</span>';
      return;
    }
    const byDay = {};
    data.forEach(r => {
      if (!byDay[r.day_id]) byDay[r.day_id] = { day_no: r.day_no, date: r.treatment_date, day_id: r.day_id, drugs: [] };
      if (r.administration_id) byDay[r.day_id].drugs.push(r);
    });
    el.innerHTML = Object.values(byDay).map(day => `
      <div style="border:1px solid var(--card2);border-radius:10px;padding:10px;margin-bottom:8px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
          <span style="font-weight:700;font-size:.8rem">Gün ${day.day_no} — ${fmtTarih(day.date)}</span>
          ${_curCase?.status==='active'?`<button onclick="caseDrugFormAc('${day.day_id}')" style="background:var(--blue);color:#fff;border:none;border-radius:7px;padding:3px 10px;font-size:.7rem;cursor:pointer">+ İlaç</button>`:''}
        </div>
        <div id="drugs-${day.day_id}">
          ${day.drugs.length ? day.drugs.map(d => `
            <div style="display:flex;justify-content:space-between;align-items:center;padding:4px 0;border-bottom:1px solid var(--card2)">
              <span><b>${d.drug}</b> ${d.dose} ${d.unit}${d.route?' · '+d.route:''}</span>
              ${_curCase?.status==='active'?`<button onclick="caseDrugSil('${d.administration_id}')" style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.9rem">🗑</button>`:''}
            </div>`).join('') : '<span style="color:var(--ink3);font-size:.75rem">İlaç eklenmemiş</span>'}
        </div>
      </div>`).join('');
  } catch(e) {
    el.innerHTML = `<span style="color:var(--red);font-size:.78rem">Yüklenemedi: ${e.message}</span>`;
  }
}

async function caseGunEkle() {
  if (!_curCase) return;
  try {
    await rpc('add_treatment_day', { p_case_id: _curCase.id });
    toast('✅ Tedavi günü eklendi');
    await renderCaseTimeline(_curCase.id);
  } catch(e) { toast(e.message, true); }
}

let _activeDayId = null;
function caseDrugFormAc(dayId) {
  _activeDayId = dayId;
  document.querySelectorAll('.cd-drug-form').forEach(f => f.remove());
  const container = document.getElementById('drugs-' + dayId);
  if (!container) return;
  const drugs = _caseDrugsCache || [];
  const opts = drugs.map(d => `<option value="${d.id}">${d.name}${d.default_unit?' ('+d.default_unit+')':''}</option>`).join('');
  const form = document.createElement('div');
  form.className = 'cd-drug-form';
  form.style.cssText = 'margin-top:8px;background:var(--card2);border-radius:8px;padding:8px';
  form.innerHTML = `
    <select id="cdf-drug" class="fsel" style="margin-bottom:6px" onchange="onCdfDrugChange()">
      <option value="">— İlaç seçin —</option>${opts}
    </select>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:6px">
      <input id="cdf-dose" class="fi" type="number" min="0.01" step="0.01" placeholder="Doz" style="margin:0">
      <input id="cdf-unit" class="fi" placeholder="Birim" style="margin:0">
    </div>
    <select id="cdf-route" class="fsel" style="margin-bottom:6px">
      <option value="">Uygulama yolu…</option>
      <option>IM</option><option>IV</option><option>SC</option>
      <option>PO</option><option>Topikal</option><option>Intrauterin</option>
    </select>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      <button onclick="caseDrugKaydet(this)" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:7px;font-weight:700;cursor:pointer">💾 Kaydet</button>
      <button onclick="this.closest('.cd-drug-form').remove()" style="background:var(--card3);border:none;border-radius:7px;padding:7px;cursor:pointer">İptal</button>
    </div>`;
  container.appendChild(form);
}

function onCdfDrugChange() {
  const sel  = document.getElementById('cdf-drug');
  const drug = (_caseDrugsCache||[]).find(d => d.id === sel?.value);
  if (drug?.default_unit)  document.getElementById('cdf-unit').value  = drug.default_unit;
  if (drug?.default_route) document.getElementById('cdf-route').value = drug.default_route;
}

async function caseDrugKaydet(btn) {
  const drugId = document.getElementById('cdf-drug')?.value;
  const dose   = parseFloat(document.getElementById('cdf-dose')?.value);
  const unit   = document.getElementById('cdf-unit')?.value?.trim();
  const route  = document.getElementById('cdf-route')?.value || null;
  if (!drugId)        { toast('İlaç seçin', true); return; }
  if (!dose || dose<=0){ toast('Geçerli doz girin', true); return; }
  if (!unit)          { toast('Birim girin', true); return; }
  if (!_activeDayId)  return;
  btn.disabled = true; btn.textContent = 'Kaydediliyor…';
  try {
    await rpc('add_drug_administration', {
      p_day_id:  _activeDayId,
      p_drug_id: drugId,
      p_dose:    dose,
      p_unit:    unit,
      p_route:   route,
    });
    toast('✅ İlaç eklendi');
    btn.closest('.cd-drug-form').remove();
    await pullTables(['stok','stok_hareket']);
    await renderCaseTimeline(_curCase.id);
  } catch(e) { toast(e.message, true); }
  finally { btn.disabled = false; btn.textContent = '💾 Kaydet'; }
}

async function caseDrugSil(adminId) {
  if (!confirm('Bu ilaç kaydı silinsin mi?')) return;
  try {
    await rpc('remove_drug_administration', { p_admin_id: adminId });
    toast('✅ Silindi');
    await pullTables(['stok','stok_hareket']);
    await renderCaseTimeline(_curCase.id);
  } catch(e) { toast(e.message, true); }
}

async function caseKapat() {
  if (!_curCase) return;
  if (!confirm('Vakayı kapatmak istiyor musunuz?')) return;
  try {
    await rpc('close_case', { p_case_id: _curCase.id });
    toast('✅ Vaka kapatıldı');
    await pullTables(['cases']);
    await renderFromLocal();
    closeM('m-case-det');
  } catch(e) { toast(e.message, true); }
}


async function renderHstIlaclar(vakaId){
  const el=document.getElementById('hd-ilac-listesi');
  if(!el) return;
  try {
    const {data,error}=await db.from('tedavi_view').select('*').eq('vaka_id',vakaId).order('created_at',{ascending:true});
    if(error||!data||!data.length){ el.innerHTML='<span style="color:var(--ink3);font-size:.78rem">İlaç kaydı yok</span>'; return; }
    el.innerHTML=data.map(t=>`
      <div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
        <div>
          <span style="font-weight:700">${t.ilac_adi||'?'}</span>
          <span style="color:var(--ink3)"> ${t.miktar||0} ${t.ilac_birim||''}</span>
          ${t.uygulama_yolu?`<span style="margin-left:6px;background:var(--card2);padding:2px 7px;border-radius:8px;font-size:.7rem">${t.uygulama_yolu}</span>`:''}
          ${t.bekleme_suresi_gun?`<span style="margin-left:4px;color:var(--amber);font-size:.72rem">⏳ ${t.bekleme_suresi_gun}g bekleme</span>`:''}
        </div>
        <button onclick="hstIlacSil('${t.id}')" style="background:none;border:none;color:var(--red);font-size:1rem;cursor:pointer;padding:2px 6px">🗑</button>
      </div>`).join('');
  } catch(e){ el.innerHTML='<span style="color:var(--red);font-size:.78rem">Yüklenemedi</span>'; }
}

let _hdiIlacCache=[];
async function acHdiStok(inp){
  const q=(inp.value||'').toLowerCase().trim();
  const ac=document.getElementById('ac-hdi');
  if(!ac) return;
  if(!_hdiIlacCache.length){
    const {data}=await db.from('stok').select('*').eq('kategori','İlaç');
    _hdiIlacCache=data||[];
  }
  const filtered=q?_hdiIlacCache.filter(s=>s.urun_adi.toLowerCase().includes(q)):_hdiIlacCache.slice(0,12);
  if(!filtered.length){ ac.style.display='none'; return; }
  ac.innerHTML=filtered.map(s=>`<div onclick="hdiStokSec('${s.id}','${s.urun_adi.replace(/'/g,"\'")}','${s.birim||''}')"
    style="padding:8px 12px;cursor:pointer;font-size:.82rem;border-bottom:1px solid var(--card2)"
    onmouseover="this.style.background='var(--card2)'" onmouseout="this.style.background=''">${s.urun_adi} <span style="color:var(--ink3)">${s.birim||''}</span></div>`).join('');
  ac.style.display='block';
}
function hdiStokSec(id,ad,birim){
  document.getElementById('hdi-stok-id').value=id;
  document.getElementById('hdi-stok-ac').value=ad;
  document.getElementById('hdi-birim').value=birim;
  document.getElementById('ac-hdi').style.display='none';
}

// ──────────────────────────────────────────
// TOHUMLAMA DETAY MODAL
// ──────────────────────────────────────────
async function openTohDet(id){
  const all=await idbGetAll('tohumlama');
  const t=all.find(x=>x.id===id); if(!t) return;
  _curToh=t;
  const hk=[...HEKIMLER,...(_customHekimler||[])].find(x=>x.id===t.hekim_id);
  // Küpe çözümle
  const hayvanObj=_A.find(a=>a.id===t.hayvan_id||a.kupe_no===t.hayvan_id);
  const hayvanLabel=hayvanObj?(hayvanObj.kupe_no||hayvanObj.devlet_kupe||t.hayvan_id):t.hayvan_id;
  document.getElementById('td2-hayvan').textContent=hayvanLabel||'?';
  document.getElementById('td2-sperma').textContent=`💉 ${t.sperma||'?'}`;
  const sc=t.sonuc==='Gebe'?'var(--green)':t.sonuc==='Boş'?'var(--red)':'var(--amber)';
  const chips=[
    `<span style="background:rgba(0,0,0,.06);padding:3px 9px;border-radius:10px;font-size:.7rem;font-weight:700;color:${sc}">${t.sonuc||'Bekliyor'}</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">${t.deneme_no||1}. deneme</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">📅 ${fmtTarih(t.tarih)}</span>`,
    hk?`<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">👨‍⚕️ ${hk.ad}</span>`:'',
  ];
  document.getElementById('td2-meta').innerHTML=chips.filter(Boolean).join('');
  // islem_log'dan bu kaydın id'sini bul (geri alma için)
  const islemLog=await idbGetAll('islem_log');
  const islemKayit=islemLog.find(l=>l.tip==='TOHUMLAMA'&&(l.payload?.kaynak_id===id||l.snapshot?.id===id));
  const td2GeriAlBtn=document.getElementById('td2-geri-al-btn');
  if(td2GeriAlBtn){
    if(islemKayit){ td2GeriAlBtn.style.display='block'; td2GeriAlBtn.onclick=()=>openGeriAl(islemKayit.id,`${hayvanLabel} — ${t.sperma||'?'} (${fmtTarih(t.tarih)})`); }
    else { td2GeriAlBtn.style.display='none'; }
  }
  openM('m-toh-det');
}
async function tohSonuc(sonuc){
  if(!_curToh) return;
  await write('tohumlama',{..._curToh,sonuc},'PATCH',`id=eq.${_curToh.id}`);
  toast(sonuc==='Gebe'?'✅ Gebe olarak işaretlendi':sonuc==='Boş'?'Boş olarak işaretlendi':'Güncellendi');
  closeM('m-toh-det');
  await renderFromLocal();
}

// ──────────────────────────────────────────
// SPERMA AUTOCOMPLETE
// ──────────────────────────────────────────
async function acSperma(){
  const q=(document.getElementById('i-sperma')?.value||'').toLowerCase().trim();
  const ac=document.getElementById('ac-sperma'); if(!ac) return;
  const stokSperma=await getSpermaStok();
  const tohs=await idbGetAll('tohumlama');
  const used=[...new Set(tohs.map(t=>t.sperma).filter(Boolean))];
  const all=[...new Set([...stokSperma.map(s=>s.urun_adi),...SPERMA_LISTESI,...(_customSperma||[]),...used])];
  const filtered=q?all.filter(s=>s.toLowerCase().includes(q)):all;
  if(!filtered.length){ ac.style.display='none'; return; }
  const stokMap={};
  stokSperma.forEach(s=>{ stokMap[s.urun_adi]=s.guncel||0; });
  ac.innerHTML=filtered.map(s=>{
    const adet=stokMap[s];
    const warn=adet!==undefined&&adet<=5;
    const adetTxt=adet!==undefined?`<span style="color:${warn?'var(--red)':'var(--green)'};font-weight:700">${adet} doz</span>`:'';
    return `<div onclick="selSperma('${s.replace(/'/g,"\\'")}');event.stopPropagation()" style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid #eee;display:flex;justify-content:space-between;align-items:center">
      <span>${s}${warn?' ⚠️':''}</span>${adetTxt}
    </div>`;
  }).join('');
  ac.style.display='block';
}
async function selSperma(val){
  document.getElementById('i-sperma').value=val;
  document.getElementById('ac-sperma').style.display='none';
  await updateSpermaHint(val);
}
async function updateSpermaHint(val){
  const v2=val||document.getElementById('i-sperma')?.value;
  const hint=document.getElementById('sperma-stok-hint'); if(!hint||!v2) return;
  const st=await getSpermaStok();
  const s=st.find(x=>x.urun_adi===v2);
  if(s){
    const warn=s.guncel<=5;
    hint.innerHTML=`Stok: <b style="color:${warn?'var(--red)':'var(--green)'}">${s.guncel} doz</b>${warn?' ⚠️ Kritik seviye!':''}`;
  } else { hint.textContent='Stokta kayıtlı değil'; }
}
async function getSpermaStok(){
  const all=await idbGetAll('stok');
  const mvs=await getData('stok_hareket',m=>!m.iptal);
  return all.filter(s=>s.kategori==='Sperma').map(s=>{
    const used=mvs.filter(m=>m.stok_id===s.id).reduce((a,m)=>a+(+m.miktar||0),0);
    return {...s,guncel:(+s.baslangic_miktar||0)-used};
  });
}
async function dusSpermaStok(spermaAdi){
  const st=await getSpermaStok();
  const s=st.find(x=>x.urun_adi===spermaAdi);
  if(s&&s.guncel>0) await write('stok_hareket',{id:crypto.randomUUID(),stok_id:s.id,tur:'Tohumlama',miktar:1,notlar:'Tohumlama',iptal:false});
}
async function checkSpermaUyari(){
  const st=await getSpermaStok();
  const critik=st.filter(s=>s.guncel<=5&&s.guncel>=0);
  const bnd=document.getElementById('sperma-warn-band'); if(!bnd) return;
  if(critik.length>0){
    bnd.style.display='flex';
    bnd.textContent='⚠️ Kritik sperma stoku: '+critik.map(s=>`${s.urun_adi} (${s.guncel} doz)`).join(', ');
  } else { bnd.style.display='none'; }
}
function spermaModStok(){
  document.getElementById('sperma-stok-area').style.display='block';
  document.getElementById('sperma-elle-area').style.display='none';
  document.getElementById('btn-sperma-stok').style.background='rgba(42,107,181,.2)';
  document.getElementById('btn-sperma-elle').style.background='var(--card2)';
  const spermalar=_S.filter(s=>s.kategori==='Sperma'||s.grup==='Sperma'||(s.urun_adi||'').toLowerCase().includes('sperma')||(s.urun_adi||'').toLowerCase().includes('doz'));
  const sel=document.getElementById('i-sperma-select');
  sel.innerHTML='<option value="">Sperma seçin…</option>'+spermalar.map(s=>`<option value="${s.urun_adi}" data-stok="${s.guncel||0}">${s.urun_adi} (${s.guncel||0} doz kaldı)</option>`).join('');
  if(!spermalar.length) sel.innerHTML='<option value="">Stokta sperma yok — Elle Gir kullanın</option>';
  document.getElementById('i-sperma').value='';
  document.getElementById('sperma-hint').textContent='';
  const kaydetBtn=document.querySelector('#m-insem .btn-g');
  if(kaydetBtn) kaydetBtn.disabled=false;
}
function onSpermaSelect(sel){
  const val=sel.value;
  const stok=parseInt(sel.selectedOptions[0]?.dataset?.stok??'-1',10);
  document.getElementById('i-sperma').value=val;
  const hint=document.getElementById('sperma-hint');
  const kaydetBtn=document.querySelector('#m-insem .btn-g');
  if(!val){ hint.textContent=''; if(kaydetBtn) kaydetBtn.disabled=false; return; }
  if(stok<=0){
    hint.style.color='var(--red,#c0392b)';
    hint.textContent='⛔ Bu sperma stoku tükendi, kayıt yapılamaz.';
    if(kaydetBtn){ kaydetBtn.disabled=true; kaydetBtn.title='Stok yok'; }
  } else if(stok<=5){
    hint.style.color='var(--orange,#e67e22)';
    hint.textContent=`⚠️ Dikkat: Sadece ${stok} doz kaldı.`;
    if(kaydetBtn){ kaydetBtn.disabled=false; kaydetBtn.title=''; }
  } else {
    hint.style.color='var(--green,#27ae60)';
    hint.textContent=`✅ Stokta ${stok} doz mevcut.`;
    if(kaydetBtn){ kaydetBtn.disabled=false; kaydetBtn.title=''; }
  }
}
function spermaModElle(){
  document.getElementById('sperma-stok-area').style.display='none';
  document.getElementById('sperma-elle-area').style.display='block';
  document.getElementById('btn-sperma-elle').style.background='rgba(61,74,50,.15)';
  document.getElementById('btn-sperma-stok').style.background='var(--card2)';
  document.getElementById('i-sperma').value='';
  document.getElementById('sperma-hint').textContent='';
  const kaydetBtn=document.querySelector('#m-insem .btn-g');
  if(kaydetBtn){ kaydetBtn.disabled=false; kaydetBtn.title=''; }
}

// ──────────────────────────────────────────
// İLAÇ AUTOCOMPLETE
// ──────────────────────────────────────────
async function refreshIlacCache(){
  const stk=await idbGetAll('stok');
  const mvs=await getData('stok_hareket',m=>!m.iptal);
  _ilacCache=stk
    .filter(s=>s.kategori&&['Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç','İlaç'].includes(s.kategori))
    .map(s=>{ const used=mvs.filter(m=>m.stok_id===s.id).reduce((a,m)=>a+(+m.miktar||0),0); return {...s,guncel:(+s.baslangic_miktar||0)-used}; });
}
async function acIlac(){
  const q=(document.getElementById('d-stok-ac')?.value||'').toLowerCase().trim();
  const ac=document.getElementById('ac-dilac'); if(!ac) return;
  if(!_ilacCache.length) await refreshIlacCache();
  const filtered=q?_ilacCache.filter(s=>s.urun_adi.toLowerCase().includes(q)):_ilacCache.slice(0,12);
  if(!filtered.length){
    ac.innerHTML='<div style="padding:9px 12px;font-size:.78rem;color:var(--red)">⚠️ Stokta eşleşen ilaç yok — önce stoka ekleyin</div>';
    ac.style.display='block'; return;
  }
  ac.innerHTML=filtered.map(s=>{
    const warn=s.guncel<=0;
    return `<div onclick="selIlac('${s.id}','${s.urun_adi.replace(/'/g,"\\'")}','${s.birim||'ml'}',${s.guncel});event.stopPropagation()"
      style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid #eee;display:flex;justify-content:space-between;align-items:center;${warn?'opacity:.5':''}">
      <div><div style="font-weight:600">${s.urun_adi}</div><div style="font-size:.65rem;color:var(--ink3)">${s.kategori||''}</div></div>
      <span style="color:${warn?'var(--red)':s.guncel<=5?'var(--amber)':'var(--green)'};font-weight:700;font-size:.78rem">${s.guncel.toFixed(s.birim==='adet'?0:1)} ${s.birim||''}</span>
    </div>`;
  }).join('');
  ac.style.display='block';
}
function selIlac(id,ad,birim,guncel){
  document.getElementById('d-stok-ac').value=ad;
  document.getElementById('d-stok').value=id;
  document.getElementById('ac-dilac').style.display='none';
  const hint=document.getElementById('d-stok-hint');
  if(hint){ const warn=guncel<=5; hint.innerHTML=`Birim: <b>${birim}</b> · Stok: <b style="color:${warn?'var(--red)':'var(--green)'}">${guncel.toFixed(birim==='adet'?0:1)} ${birim}</b>${warn?' ⚠️':''}`; }
}
function ilacSatirEkle(){
  const container=document.getElementById('ilac-rows');
  const row=document.createElement('div');
  row.className='ilac-satir';
  row.style.cssText='display:flex;gap:6px;align-items:center;margin-bottom:6px';
  row.innerHTML=`<div style="flex:2;position:relative">
    <input class="fi ilac-stok-ac" placeholder="İlaç ara…" autocomplete="off" style="margin:0"
      oninput="acDilacSatir(this)" onfocus="acDilacSatir(this)">
    <input type="hidden" class="ilac-stok-id">
    <div class="ac-box ilac-ac" style="display:none;position:absolute;z-index:200;background:#fff;border:1px solid var(--card3);border-radius:8px;max-height:160px;overflow-y:auto;width:100%"></div>
  </div>
  <input class="fi ilac-mik" type="number" min="0" placeholder="ml/adet" style="flex:1;margin:0">
  <button type="button" onclick="this.closest('.ilac-satir').remove()" style="background:var(--red);color:#fff;border:none;border-radius:8px;padding:6px 10px;cursor:pointer;flex-shrink:0">✕</button>`;
  container.appendChild(row);
}
function acDilacSatir(inp){
  const q=(inp.value||'').toLowerCase().trim();
  const ac=inp.closest('.ilac-satir').querySelector('.ilac-ac');
  const stoklar=_S.filter(s=>s.kategori!=='Sperma'&&!(s.urun_adi||'').toLowerCase().includes('sperma'));
  const filtered=q?stoklar.filter(s=>(s.urun_adi||'').toLowerCase().includes(q)):stoklar.slice(0,8);
  if(!filtered.length){ac.style.display='none';return;}
  ac.innerHTML=filtered.map(s=>`<div onclick="selDilacSatir(this,'${s.id}','${s.urun_adi.replace(/'/g,"\\'")}','${s.birim||''}')" style="padding:8px 10px;cursor:pointer;font-size:.82rem;border-bottom:1px solid #eee">${s.urun_adi} <span style="color:#aaa;font-size:.65rem">${s.guncel||0} ${s.birim||''}</span></div>`).join('');
  ac.style.display='block';
}
function selDilacSatir(el,id,ad,birim){
  const row=el.closest('.ilac-satir');
  row.querySelector('.ilac-stok-ac').value=ad;
  row.querySelector('.ilac-stok-id').value=id;
  row.querySelector('.ilac-mik').placeholder=birim||'miktar';
  el.closest('.ilac-ac').style.display='none';
}
document.addEventListener('click',e=>{
  const ac=document.getElementById('ac-dilac');
  if(ac&&!e.target.closest('#d-stok-ac')&&!e.target.closest('#ac-dilac')) ac.style.display='none';
});

// ──────────────────────────────────────────
// HAYVAN KÜPE AUTOCOMPLETE
// ──────────────────────────────────────────
function acHayvan(inputId,listId){
  const q=(document.getElementById(inputId)?.value||'').toLowerCase().trim();
  const ac=document.getElementById(listId); if(!ac) return;
  const src=listId==='ac-ihid'?(window._TH||[]):(_A.length?_A:[]);
  if(listId==='ac-ihid'&&!window._TH){
    const ac=document.getElementById(listId); if(ac){ac.innerHTML='<div style="padding:9px 12px;font-size:.78rem;color:var(--ink3)">⏳ Yükleniyor…</div>';ac.style.display='block';} return;
  }
  const filtered=q
    ?src.filter(a=>(a.kupe_no||'').toLowerCase().includes(q)||(a.devlet_kupe||'').toLowerCase().includes(q)||(a.id||'').toLowerCase().includes(q)).slice(0,12)
    :src.slice(0,10);
  if(!filtered.length){
    ac.innerHTML='<div style="padding:9px 12px;font-size:.78rem;color:var(--red)">⚠️ Sürüde eşleşen hayvan bulunamadı</div>';
    ac.style.display='block'; return;
  }
  ac.innerHTML=filtered.map(a=>{
    const kupe=a.kupe_no||a.devlet_kupe||a.id;
    return `<div onclick="selHayvan('${inputId}','${listId}','${kupe}')" style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid #eee;display:flex;justify-content:space-between">
      <span style="font-weight:600">${kupe}</span>
      <span style="color:var(--ink3);font-size:.7rem">${a.irk||''} · ${a.padok||''}</span>
    </div>`;
  }).join('');
  ac.style.display='block';
}
function selHayvan(inputId,listId,val){
  const el=document.getElementById(inputId); if(el) el.value=val;
  const ac=document.getElementById(listId); if(ac) ac.style.display='none';
}
document.addEventListener('click',e=>{
  ['ac-ihid','ac-dhid','ac-banne','ac-sperma'].forEach(id=>{
    const ac=document.getElementById(id);
    if(ac&&!e.target.closest('#'+id)) ac.style.display='none';
  });
});
function acNav(e,listId){
  const ac=document.getElementById(listId); if(!ac||ac.style.display==='none') return;
  const items=ac.querySelectorAll('div[onclick]');
  const active=ac.querySelector('.ac-active');
  let idx=Array.from(items).indexOf(active);
  if(e.key==='ArrowDown'){ e.preventDefault(); idx=Math.min(idx+1,items.length-1); }
  else if(e.key==='ArrowUp'){ e.preventDefault(); idx=Math.max(idx-1,0); }
  else if(e.key==='Enter'&&active){ e.preventDefault(); active.click(); return; }
  else if(e.key==='Escape'){ ac.style.display='none'; return; }
  else return;
  items.forEach(i=>i.classList.remove('ac-active'));
  if(items[idx]){ items[idx].classList.add('ac-active'); items[idx].style.background='var(--card2)'; items[idx].scrollIntoView({block:'nearest'}); }
}

// ──────────────────────────────────────────
// YARDIMCI MODAL FONKSİYONLARI
// ──────────────────────────────────────────
function openMWithHayvan(modalId,inputId,kupeNo){
  openM(modalId);
  setTimeout(()=>{
    const el=document.getElementById(inputId);
    if(el){
      el.value=kupeNo;
      // Autocomplete dropdown'ı kapat — input eventi tetikleme
      const acMap={'d-hid':'ac-dhid','i-hid':'ac-ihid','b-anne':'ac-banne','case-hid':'ac-casehid'};
      const acEl=document.getElementById(acMap[inputId]);
      if(acEl) acEl.style.display='none';
    }
    if(modalId==='m-disease'){
      if(typeof loadDiseasesDropdown==='function') loadDiseasesDropdown();
    }
    if(modalId==='m-case'){
      const kat=document.getElementById('case-kat');
      if(kat) kat.value='';
      if(typeof loadDiseasesDropdown==='function') loadDiseasesDropdown('');
    }
  },150);
}
async function tohSonucGuncelle(tohId, sonuc, hayvanId){
  try{
    await db.from('tohumlama').update({sonuc}).eq('id',tohId);
    await pullTables(['tohumlama','hayvanlar']);
    renderSafe();
    toast(sonuc==='Gebe'?'✅ Gebe işaretlendi':'✅ Boş işaretlendi');
    openDet(hayvanId);
  }catch(e){ toast(e.message,true); }
}
async function openGebelikEkle(hayvanId){
  const tohs=await getData('tohumlama',t=>t.hayvan_id===hayvanId);
  tohs.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  const son=tohs.find(t=>t.sonuc==='Bekliyor')||tohs[0];
  if(!son){ toast('Tohumlama kaydı bulunamadı',true); return; }
  const sure=confirm('Son tohumlama ('+fmtTarih(son.tarih)+' · '+(son.sperma||'—')+') Gebe olarak işaretlensin mi?');
  if(!sure) return;
  try{
    await rpcOptimistic(()=>db.from('tohumlama').update({sonuc:'Gebe'}).eq('id',son.id),['tohumlama','hayvanlar']);
    toast('✅ Gebe işaretlendi');
    openDet(hayvanId);
  }catch(e){ toast(e.message,true); }
}

// ──────────────────────────────────────────
// HASTALIK AUTOCOMPLETE
// ──────────────────────────────────────────
async function acDisease(){
  const q=(document.getElementById('d-tani')?.value||'').toLowerCase().trim();
  const ac=document.getElementById('ac-dis');
  const logs=await idbGetAll('hastalik_log');
  const usedDis=[...new Set(logs.map(l=>l.tani).filter(Boolean))];
  const all=[...new Set([...HASTALIK_LISTESI,...usedDis])];
  all.sort((a,b)=>(_disFreq[b]||0)-(_disFreq[a]||0));
  const filtered=q?all.filter(d=>d.toLowerCase().includes(q)):all.slice(0,12);
  if(!filtered.length){ ac.style.display='none'; return; }
  ac.innerHTML=filtered.map(d=>`<div onclick="selDis('${d.replace(/'/g,"\\'")}');event.stopPropagation()"
    style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid #eee">
    ${d}${_disFreq[d]?` <span style="color:#aaa;font-size:.6rem">(${_disFreq[d]}x)</span>`:''}
  </div>`).join('');
  ac.style.display='block';
}
function selDis(val){
  document.getElementById('d-tani').value=val;
  document.getElementById('ac-dis').style.display='none';
}
document.addEventListener('click',e=>{
  const ac=document.getElementById('ac-dis');
  if(ac&&!e.target.closest('#d-tani')&&!e.target.closest('#ac-dis')) ac.style.display='none';
});

// ──────────────────────────────────────────
// AYARLAR & DATA TRAFFIC
// ──────────────────────────────────────────
function ayarlarAc(){
  renderAyarlarHekimList();
  renderAyarlarSpermaList();
  renderDrugStokList();
  dataTrafficYenile();
  openM('m-ayarlar');
}
async function renderDrugStokList() {
  const el = document.getElementById('ay-drug-stok-list');
  if (!el) return;
  el.innerHTML = '<div style="font-size:.75rem;color:var(--ink3);padding:6px 0">Yükleniyor…</div>';
  try {
    const [drugs, stokList] = await Promise.all([
      idbGetAll('drugs'),
      idbGetAll('stok'),
    ]);
    if (!drugs.length) {
      el.innerHTML = '<div style="font-size:.75rem;color:var(--ink3)">İlaç kaydı bulunamadı.</div>';
      return;
    }
    const stokOpts = stokList
      .sort((a, b) => (a.urun_adi || '').localeCompare(b.urun_adi || '', 'tr'))
      .map(s => `<option value="${s.id}">${s.urun_adi}</option>`)
      .join('');
    el.innerHTML = drugs
      .sort((a, b) => (a.name || '').localeCompare(b.name || '', 'tr'))
      .map(d => {
        const linked = d.stock_item_id || '';
        return `<div style="display:flex;align-items:center;gap:6px;margin-bottom:6px">
          <div style="flex:1;font-size:.78rem;font-weight:600;color:var(--ink);min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${d.name}">${d.name}</div>
          <select
            data-drug-id="${d.id}"
            onchange="submitDrugStokLink('${d.id}', this.value)"
            style="flex:1.2;font-size:.72rem;padding:5px 6px;border:1.5px solid var(--card3);border-radius:8px;background:var(--card);color:var(--ink);min-width:0"
          >
            <option value="">— Bağlantı yok —</option>
            ${stokList
              .sort((a, b) => (a.urun_adi || '').localeCompare(b.urun_adi || '', 'tr'))
              .map(s => `<option value="${s.id}"${s.id === linked ? ' selected' : ''}>${s.urun_adi}</option>`)
              .join('')}
          </select>
        </div>`;
      }).join('');
  } catch (e) {
    el.innerHTML = `<div style="color:var(--red);font-size:.75rem">⚠️ ${e.message}</div>`;
  }
}

  if(!confirm('Kuyruktaki tüm bekleyen kayıtlar silinecek. Emin misiniz?')) return;
  const q=await getQueue();
  for(const op of q) await removeFromQueue(op._qid);
  updateSyncBar();
  toast(`✅ ${q.length} kayıt kuyruktan temizlendi`);
}
async function stokHareketiTemizle(){
  const stok=await idbGetAll('stok');
  const stokIds=new Set(stok.map(s=>s.id));
  const q=await getQueue();
  let temizlenen=0;
  for(const op of q){
    if(op.table==='stok_hareket'){
      const gecersiz=op.data?.some(d=>!stokIds.has(d.stok_id));
      if(gecersiz){ await removeFromQueue(op._qid); temizlenen++; }
    }
  }
  toast(`✅ ${temizlenen} geçersiz stok hareketi kuyruktan temizlendi`);
  updateSyncBar();
}
async function dataTrafficYenile(){
  const q=await getQueue();
  const sumEl=document.getElementById('dt-summary');
  const listEl=document.getElementById('dt-list');
  if(!sumEl||!listEl) return;
  if(!q.length){ sumEl.innerHTML='<span style="color:var(--green)">✅ Kuyruk boş — tüm kayıtlar senkronize</span>'; listEl.innerHTML=''; return; }
  sumEl.innerHTML=`<span style="color:var(--amber)">⏳ ${q.length} kayıt bekliyor</span>`;
  listEl.innerHTML=q.slice(0,50).map(op=>{
    const ts=op.ts?new Date(op.ts).toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'}):'?';
    const data0=op.data?.[0]||{};
    const preview=data0.aciklama||data0.tani||data0.urun_adi||data0.kupe_no||data0.yavru_kupe||JSON.stringify(data0).slice(0,40);
    return `<div style="border:1px solid var(--card3);border-radius:8px;padding:8px 10px;margin-bottom:5px;background:var(--card)">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <span style="font-weight:700;font-size:.72rem;color:var(--ink)">${op.table}</span>
        <div style="display:flex;gap:4px">
          <span style="font-size:.62rem;background:${op.method==='POST'?'rgba(42,107,181,.1)':'rgba(255,165,0,.1)'};color:${op.method==='POST'?'var(--blue)':'var(--amber)'};padding:2px 6px;border-radius:8px;font-weight:700">${op.method}</span>
          <button onclick="dataTrafficTekGonder(${op._qid})" style="background:var(--green);color:#fff;border:none;border-radius:6px;font-size:.6rem;padding:2px 7px;cursor:pointer;font-weight:700">↑</button>
          <button onclick="dataTrafficSil(${op._qid})" style="background:rgba(192,50,26,.1);color:var(--red);border:1px solid rgba(192,50,26,.2);border-radius:6px;font-size:.6rem;padding:2px 7px;cursor:pointer;font-weight:700">✕</button>
        </div>
      </div>
      <div style="font-size:.65rem;color:var(--ink3);margin-top:3px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${preview}</div>
      <div style="font-size:.58rem;color:var(--ink3);margin-top:2px">${ts}</div>
    </div>`;
  }).join('');
}
async function dataTrafficGonder(){
  const btn=event.target;
  btn.disabled=true; btn.textContent='Gönderiliyor…';
  await syncNow();
  await dataTrafficYenile();
  btn.disabled=false; btn.textContent='↑ Tümünü Gönder';
}
async function dataTrafficTekGonder(qid){
  const q=await getQueue();
  const op=q.find(o=>o._qid===qid); if(!op) return;
  try {
    if(op.method==='POST'){
      const clean=op.data.map(item=>Object.fromEntries(Object.entries(item).filter(([k,v])=>v!==null&&v!==undefined&&v!=='')));
      for(const item of clean) await db.from(op.table).insert([item]);
    } else if(op.method==='PATCH'){
      const clean=Object.fromEntries(Object.entries(op.data[0]).filter(([k,v])=>v!==null&&v!==undefined&&v!==''));
      const [col,val]=op.filter.split('=eq.');
      await db.from(op.table).update(clean).eq(col,val);
    }
    await removeFromQueue(qid);
    toast('✅ Kayıt gönderildi');
  } catch(e){ toast('❌ '+e.message,true); }
  await dataTrafficYenile();
  updateSyncBar();
}
async function dataTrafficSil(qid){
  if(!confirm('Bu kaydı kuyruktan sil? (Supabase\'e gönderilmeyecek)')) return;
  await removeFromQueue(qid);
  toast('🗑 Kayıt kuyruktan silindi');
  await dataTrafficYenile();
  updateSyncBar();
}
function renderAyarlarHekimList(){
  const el=document.getElementById('ay-hekim-list'); if(!el) return;
  const all=[...HEKIMLER,...(_customHekimler||[])];
  el.innerHTML=all.map((h,i)=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.85rem;color:var(--ink)">${h.ad}${h.id===VARSAYILAN_HEKIM?' <span style="font-size:.6rem;color:var(--green)">(varsayılan)</span>':''}</span>
    ${i>=HEKIMLER.length?`<button onclick="customHekimSil('${h.id}')" style="background:none;border:none;color:var(--red);font-size:.75rem;cursor:pointer">Sil</button>`:'<span style="font-size:.65rem;color:var(--ink3)">Sistem</span>'}
  </div>`).join('');
}
function renderAyarlarSpermaList(){
  const el=document.getElementById('ay-sperma-list'); if(!el) return;
  const all=[...SPERMA_LISTESI,...(_customSperma||[])];
  el.innerHTML=all.map((s,i)=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.8rem;color:var(--ink)">${s}</span>
    ${i>=SPERMA_LISTESI.length?`<button onclick="customSpermaSil('${s}')" style="background:none;border:none;color:var(--red);font-size:.75rem;cursor:pointer">Sil</button>`:'<span style="font-size:.6rem;color:var(--ink3)">Sabit</span>'}
  </div>`).join('');
}
function ayarlarHekimEkle(){ document.getElementById('ay-hekim-form').style.display='block'; }
function ayarlarHekimKaydet(){
  const ad=v('ay-hek-ad').trim(); if(!ad) return;
  const id='CH'+Date.now();
  _customHekimler.push({id,ad});
  ['b-hekim','i-hekim','d-hekim','ta-hekim'].forEach(sid=>{ const el=document.getElementById(sid); if(!el) return; el.innerHTML+=`<option value="${id}">${ad}</option>`; });
  cl('ay-hek-ad');
  document.getElementById('ay-hekim-form').style.display='none';
  renderAyarlarHekimList();
  toast(`✅ ${ad} eklendi`);
}
function customHekimSil(id){
  _customHekimler=_customHekimler.filter(h=>h.id!==id);
  ['b-hekim','i-hekim','d-hekim','ta-hekim'].forEach(sid=>{ const el=document.getElementById(sid); if(!el) return; const opt=el.querySelector(`option[value="${id}"]`); if(opt) opt.remove(); });
  renderAyarlarHekimList();
}
function ayarlarSpermaEkle(){ document.getElementById('ay-sperma-form').style.display='block'; }
function ayarlarSpermaKaydet(){
  const kod=v('ay-sp-kod').trim(); if(!kod) return;
  _customSperma.push(kod);
  const dl=document.getElementById('dl-sperma');
  if(dl) dl.innerHTML+=`<option value="${kod}">`;
  cl('ay-sp-kod');
  document.getElementById('ay-sperma-form').style.display='none';
  renderAyarlarSpermaList();
  toast(`✅ ${kod} eklendi`);
}
function customSpermaSil(kod){
  _customSperma=_customSperma.filter(s=>s!==kod);
  buildSpermaList();
  renderAyarlarSpermaList();
}

// ──────────────────────────────────────────
// BİLDİRİM SİSTEMİ
// ──────────────────────────────────────────
async function bildirimIzniAl(){
  if(!('Notification' in window)){ toast('Tarayıcınız bildirimleri desteklemiyor',true); return false; }
  const isIOS=/iPad|iPhone|iPod/.test(navigator.userAgent)&&!window.MSStream;
  if(isIOS&&!window.navigator.standalone){ toast('iOS: Önce Ana Ekrana Ekle yapın, sonra bildirimleri açın',true); return false; }
  if(Notification.permission==='granted') return true;
  if(Notification.permission==='denied'){ toast('Bildirim izni reddedilmiş — tarayıcı ayarlarından açın',true); return false; }
  const result=await Notification.requestPermission();
  return result==='granted';
}
async function bildirimKontrol(){
  if(!('Notification' in window)||Notification.permission!=='granted') return;
  const now=new Date();
  const bugun=now.toISOString().split('T')[0];
  const yarin=dFwd(bugun,1);
  const gorevler=await getData('gorev_log',g=>!g.tamamlandi&&!g.parent_id&&(g.hedef_tarih===bugun||g.hedef_tarih===yarin));
  const gosterilen=JSON.parse(localStorage.getItem('bildirim_gosterilen')||'{}');
  const simdi=Date.now();
  for(const g2 of gorevler){
    const hedef=new Date(g2.hedef_tarih+'T08:00:00');
    const fark=(hedef-now)/3600000;
    const key=`${g2.id}_${g2.hedef_tarih}`;
    if(fark>2.5&&fark<=3.5&&!gosterilen[key]){
      const hayvan=_A.find(a=>a.id===g2.hayvan_id);
      const kupe=hayvan?(hayvan.kupe_no||hayvan.devlet_kupe):'Genel';
      new Notification(`⏰ 3 saat sonra: ${kupe}`,{body:g2.aciklama||'',tag:key});
      gosterilen[key]=simdi;
    }
    const sabahKey=`${g2.id}_sabah`;
    if(g2.hedef_tarih===bugun&&fark>=-0.5&&fark<=0.5&&!gosterilen[sabahKey]){
      const hayvan=_A.find(a=>a.id===g2.hayvan_id);
      const kupe=hayvan?(hayvan.kupe_no||hayvan.devlet_kupe):'Genel';
      new Notification(`📋 Bugün: ${kupe}`,{body:g2.aciklama||'',tag:sabahKey});
      gosterilen[sabahKey]=simdi;
    }
  }
  Object.keys(gosterilen).forEach(k=>{ if(simdi-gosterilen[k]>7*86400000) delete gosterilen[k]; });
  localStorage.setItem('bildirim_gosterilen',JSON.stringify(gosterilen));
}
async function bildirimAc(){
  const izin=await bildirimIzniAl();
  if(izin){ toast('✅ Bildirimler açık!'); localStorage.setItem('bildirim_aktif','1'); bildirimKontrol(); }
  else { toast('⚠️ Bildirim izni verilmedi',true); }
}

// ──────────────────────────────────────────
// DATA LISTS (datalist güncelleme)
// ──────────────────────────────────────────
async function buildDataLists(){
  const stk=await idbGetAll('stok');
  const dlI=document.getElementById('dl-ilac');
  if(dlI) dlI.innerHTML=stk.map(s=>`<option value="${s.id}">${s.urun_adi}</option>`).join('');
}