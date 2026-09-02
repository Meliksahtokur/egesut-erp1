// ═══════════════════════════════════════════════════════
// ui.js — EgeSüt render & UI fonksiyonları
// ═══════════════════════════════════════════════════════

/* global
  /* global
   _curTaskFilter, _pendWin, _curUremeTab, _curGecmisFilter, _gecmisTumu, _tanimlarTab,
   _curTaskDet, _curTaskVaccineId, _curTaskTopluChildren, _curToh,
   _customHekimler, _customSperma,
   _ilacCache, _drugsCache, _disFreq,
   HEKIMLER, VARSAYILAN_HEKIM,
   HASTALIK_LISTESI, HASTALIK_KAT, LOKASYON_KAT, SEMPTOM_KAT, SEMPTOM_GENEL,
   SPERMA_LISTESI, GRUP_PADOK, PADOKLAR,
   bosKupeOner,
   getState, setState,
   g, v, cl, dAgo, dFwd, fmtTarih, fmtTarihSaat, toast, openM, closeM, mClose,
   db, rpc, rpcOptimistic, pullTables, renderSafe, renderFromLocal,
   RPC_TABLES,
   idbGetAll, idbPut, idbClearAndPut, getData, getQueue, removeFromQueue,
   openDB, syncNow, updateSyncBar
*/

let _taskKategori='all';
let _stokTab='tumu';
let _curStokDet=null;
let _prevTaskId=null;

function _findScroller(el){
  let n=el?.parentElement;
  while(n&&n!==document.body){
    const s=getComputedStyle(n).overflowY;
    if(s==='auto'||s==='scroll') return n;
    n=n.parentElement;
  }
  return null;
}
async function _keepScroll(contentEl,fn){
  const sc=_findScroller(contentEl);
  if(!sc){await fn();return;}
  const y=sc.scrollTop;
  const orig=sc.style.overflowY;
  sc.style.overflowY='hidden';
  try{await fn();}finally{
    sc.style.overflowY=orig;
    sc.scrollTop=y;
  }
}

const _katTipMap={
  asi:    ['ASI_PLANLI','ILERI_GEBE_ASI','ASI_HATIRLATMA','ASI_RAPEL'],
  vitamin:['ILERI_GEBE','TOHUMLAMA_HAZIRLIK','ILAC'],
  muayene:['MUAYENE','GEBELIK_KONTROL','VETERINER_KONTROL'],
  tedavi: ['TEDAVI','ILAC_UYGULAMA','TEDAVI_GUN','TEDAVI_SEANS'],
  bakim:  ['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP','BESLEME','BUZAGI_BAKIM'],
  diger:  null // özel mantık: _katTipMap'te olmayan tüm tipler
};
const _allKatTips=Object.values(_katTipMap).filter(Boolean).flat();
function setTaskKat(kat,btn){
  _taskKategori=kat;
  document.querySelectorAll('.kat-btn').forEach(b=>b.classList.remove('on'));
  if(btn) btn.classList.add('on');
  loadTasks(_curTaskFilter||'today');
}

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
// ── İkiz/çoklu doğum yardımcıları (saf — tests/unit/ikiz-dogum.test.js) ──
// Kardeş = aynı anne_id + aynı dogum_tarihi (olay_id'siz, migration-bağımsız kural)
function _kardeslerBul(animals,a){
  if(!a || !a.anne_id || !a.dogum_tarihi) return [];
  return (animals||[]).filter(x => x && x.id !== a.id && x.anne_id === a.anne_id && x.dogum_tarihi === a.dogum_tarihi);
}
// births = bu hayvanın kendi dogum satırları; son PENCERE gün içinde doğum varsa o satırı döner
function _ikinciYavruDogumu(births,bugunStr,pencereGun){
  if(!Array.isArray(births) || !births.length) return null;
  const enSon = births.reduce((m,d)=> (!m || (d.tarih||'') > (m.tarih||'')) ? d : m, null);
  if(!enSon || !enSon.tarih) return null;
  const sinir = new Date(bugunStr + 'T00:00:00');
  sinir.setDate(sinir.getDate() - (pencereGun || 10));
  const s = `${sinir.getFullYear()}-${String(sinir.getMonth()+1).padStart(2,'0')}-${String(sinir.getDate()).padStart(2,'0')}`;
  return enSon.tarih >= s ? enSon : null;
}
// Dashboard bandı için: anne başına tek dogum satırı (ikizde anne 1 kez görünür)
function _dogumAnneBazliTekillestir(births){
  const m = new Map();
  for(const b of (births||[])){ if(b && b.anne_id && !m.has(b.anne_id)) m.set(b.anne_id, b); }
  return [...m.values()];
}
function _dashStatRow(animals,gebeTohs,diseases,tasks,badge){
  const _taskCls=tasks.length>0?'warn':'ok';
  const sutBuzagiSayisi=animals.filter(a=>a.grup&&a.grup.includes('Süt İçen Buzağı')&&a.dogum_tarihi&&Math.floor((Date.now()-new Date(a.dogum_tarihi))/86400000)>=60).length;
  return `<div class="dash-row">
    <div class="sc ok" onclick="goTo('suru')"><div class="sv">${animals.length}</div><div class="sl">Aktif Hayvan ›</div></div>
    <div class="sc ok" onclick="showGebe()"><div class="sv">${gebeTohs.length}</div><div class="sl">Gebe ›</div></div>
    <div class="sc ${diseases.length>0?'alert':'ok'}" onclick="showHasta()"><div class="sv">${diseases.length}</div><div class="sl">Aktif Hastalık ›</div></div>
    <div class="sc ${sutBuzagiSayisi>0?'warn':'ok'}" onclick="goTo('suru');filterA()"><div class="sv">${sutBuzagiSayisi}</div><div class="sl">🍼 Sütten Kes ›</div></div>
    <div class="sc ${badge>0?'alert':_taskCls}" onclick="goTo('tasks')"><div class="sv">${tasks.length}</div><div class="sl">Bekleyen Görev ›</div></div>
  </div>`;
}
function _dashVacAlerts(today,vaxLogs,vaccines){
  if(!vaxLogs||!vaxLogs.length) return '';
  // Keep only latest non-dismissed entry per (animal_id, vaccine_id)
  const latestMap = {};
  vaxLogs
    .filter(v => !v.ertelendi)
    .sort((a, b) => (b.vaccination_date || '').localeCompare(a.vaccination_date || ''))
    .forEach(v => {
      const key = v.animal_id + '|' + v.vaccine_id;
      if (!latestMap[key]) latestMap[key] = v;
    });
  const withDue = Object.values(latestMap).filter(v => v.next_due_date);
  if(!withDue.length) return '';

  const vaxMap={};
  (vaccines||[]).forEach(v=>vaxMap[v.id]=v);

  const categorized=withDue.map(v=>{
    const due=new Date(v.next_due_date);
    const todayD=new Date(today);
    const days=Math.floor((due-todayD)/86400000);
    return{...v,days,vaxName:vaxMap[v.vaccine_id]?.name||'?'};
  }).sort((a,b)=>a.days-b.days);

  const overdue=categorized.filter(v=>v.days<0);
  const thisWeek=categorized.filter(v=>v.days>=0&&v.days<=7);
  const thisMonth=categorized.filter(v=>v.days>7&&v.days<=30);

  let priority='blue', rows=[];
  if(overdue.length){ priority='red'; rows=overdue; }
  else if(thisWeek.length){ priority='amber'; rows=thisWeek; }
  else if(thisMonth.length){ priority='blue'; rows=thisMonth; }
  else { priority='blue'; rows=categorized.slice(0,5); }

  const total=categorized.length;
  const display=rows.slice(0,5);
  // B24: gösterilen 5'ten azken 'more' yanlış (negatif/aşırı) olabiliyordu
  const more=Math.max(0,total-display.length);

  return band(priority,`💉 Yaklaşan Aşılar (${total})`,
    display.map(v=>`<div class="arow" style="display:flex;align-items:center;gap:6px">
      <div style="flex:1;cursor:pointer" onclick="openDet('${v.animal_id}')">
        <div class="arow-left">
          <div class="arow-main">${esc(v.vaxName)}</div>
          <div class="arow-sub">${v.days<0?'⚠️ '+Math.abs(v.days)+' gün gecikti':'⏰ '+v.days+' gün kaldı'}</div>
        </div>
        <div class="arow-right">${fmtTarih(v.next_due_date)}</div>
      </div>
      <button style="font-size:.7rem;font-weight:700;color:var(--ink3);background:var(--card2);border:1px solid var(--card3);border-radius:6px;padding:2px 7px;cursor:pointer;white-space:nowrap;flex-shrink:0"
        data-vlid="${escAttr(v.id)}" data-vaxname="${escAttr(v.vaxName)}"
        onclick="event.stopPropagation();asiDismiss(this.dataset.vlid,this.dataset.vaxname)">✕</button>
    </div>`).join('')+(more>0?`<div class="arow" style="opacity:.5;font-size:.68rem;text-align:center">+${more} daha</div>`:''));
}

async function ileriGebeKontrol(){
  try {
    const res=await rpc('gebelik_protokol_kontrol');
    if(res?.ok){
      const n=res.olusturulan||0;
      toast(n>0?`✅ ${n} yeni görev oluşturuldu`:'✅ Tüm görevler güncel');
      if(res.hayvanlar) window.__ileriGebeListesi=res.hayvanlar;
      if(n>0) pullTables(['gorev_log']).then(loadDash).catch(console.warn);
      else loadDash();
    }
  } catch(e){ toast('❌ '+e.message,true); }
}
function _dashBands(negStk,late,todayT,births60,nearBirth,critStk,stock,ileriGebeler,aMap,yakAsi,yakTakviye,ddMap,sessizList){
  const _dd=ddMap||{};
  const _getDis=t=>{if(t.gorev_tipi!=='TEDAVI_GUN')return '';try{return _dd[JSON.parse(t.aciklama||'{}').day_id]||'';}catch(e){return '';}};
  const _rt=(t,cls)=>renderTask(t,cls,[],[],_getDis(t));
  let h='';
  if(negStk>0) h+=band('red','🆘 Negatif Stok',`<div class="arow" onclick="goTo('log')"><div class="arow-left"><div class="arow-sub">${negStk} üründe stok sıfırın altında. Stok sekmesine git.</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`);
  if(late.length){
    h+=`<div class="sh"><span class="sh-title">🔴 Geciken Görevler</span><button class="sh-link" onclick="goTo('tasks')">Tümü →</button></div>`;
    h+=late.slice(0,4).map(t=>_rt(t,'late')).join('');
  }
  if(todayT.length){
    h+=`<div class="sh"><span class="sh-title">⏳ Bugün</span></div>`;
    h+=todayT.slice(0,4).map(t=>_rt(t,'soon')).join('');
  }
  if((yakAsi||[]).length){
    h+=`<div class="sh"><span class="sh-title">💉 Yaklaşan Aşı Görevleri (7 gün)</span><button class="sh-link" onclick="goTo('tasks')">Tümü →</button></div>`;
    h+=(yakAsi||[]).slice(0,6).map(t=>_rt(t,'near')).join('');
  }
  if((yakTakviye||[]).length){
    h+=`<div class="sh"><span class="sh-title">💊 Yarın Takviye</span></div>`;
    h+=(yakTakviye||[]).slice(0,4).map(t=>_rt(t,'')).join('');
  }
  if(births60.length){
    h+=band('amber','💛 Kızgınlık Beklenenler (58-63. gün)',
      births60.map(b=>`<div class="arow" style="display:flex;align-items:center;gap:6px"><div style="flex:1;cursor:pointer" onclick="openDet('${escAttr(b.anne_id)}')"><div class="arow-left"><div class="arow-id">${esc(b.anne_id)}</div><div class="arow-sub">${esc(b.tarih)} — ${Math.floor((Date.now()-new Date(b.tarih))/86400000)}. gün</div></div></div><button style="font-size:.65rem;font-weight:700;color:var(--red2);background:rgba(192,50,26,.1);border:1px solid rgba(192,50,26,.3);border-radius:6px;padding:2px 7px;cursor:pointer;white-space:nowrap" onclick="event.stopPropagation();kizginlikYoktu('${escAttr(b.anne_id)}','${escAttr(b.id||'')}')">✕</button></div>`).join(''));
  }
  if((ileriGebeler||[]).length){
    const kontrolBtn=`<button onclick="ileriGebeKontrol()" style="font-size:.65rem;font-weight:700;padding:3px 9px;border-radius:6px;border:1px solid var(--amber);background:rgba(255,160,0,.12);color:var(--amber);cursor:pointer;white-space:nowrap;margin-left:auto">🔔 Görev Kontrol</button>`;
    const title=`<span style="display:flex;align-items:center;gap:8px;width:100%">🤰 İleri Gebeler (210+ gün) ${kontrolBtn}</span>`;
    let inekNo=0,duveNo=0;
    h+=band('amber',title,
      (ileriGebeler||[]).map(b=>{
        const isDuve=(b.grup||'').includes('Düve');
        const no=isDuve?`D-${++duveNo}`:`${++inekNo}`;
        const kid=b.kupe_no||b.devlet_kupe||b.hayvan_id;
        const besUyari=b.gebelik_gun>=260?`<span style="background:rgba(176,120,0,.15);color:#b07800;border-radius:4px;padding:1px 5px;font-weight:700;font-size:.65rem;margin-left:4px">⚠️ Anyonik</span>`:'';
        const padokYanlis=b.padok!=='Kuru/Gebe Padok';
        const padokUyari=padokYanlis?`<span style="color:#ef4444;font-weight:700;font-size:.6rem;margin-left:4px">🔴 Transfer!</span>`:'';
        return `<div class="arow" onclick="openDet('${b.hayvan_id}')" style="${padokYanlis?'background:rgba(239,68,68,.04);':''}"><div class="arow-left"><div class="arow-id"><span style="color:var(--ink3);font-size:.65rem;margin-right:3px">${no})</span>${esc(kid)}${besUyari}${padokUyari}</div><div class="arow-sub">${b.gebelik_gun}. gün · ${esc(b.grup||'')} · ${esc(b.padok||'')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
      }).join(''));
  }
  if((sessizList||[]).length){
    const sTitle=`<span style="display:flex;align-items:center;gap:8px;width:100%">❗ Sessiz Hayvanlar (${sessizList.length})<button onclick="_showSessizList()" style="font-size:.65rem;font-weight:700;padding:3px 9px;border-radius:6px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer;white-space:nowrap;margin-left:auto">Tümünü Gör →</button></span>`;
    const sessizTop=[...(sessizList||[])].sort((a,b)=>{const af=a.sessiz_gun>=9999?1:0,bf=b.sessiz_gun>=9999?1:0;return af-bf||b.sessiz_gun-a.sessiz_gun;});
    h+=band('red',sTitle,
      sessizTop.slice(0,8).map(s=>{
        const gunTxt=s.sessiz_gun>=9999?'Hiç kayıt yok':s.sessiz_gun+' gündür sessiz';
        return `<div class="arow" onclick="openDet('${s.hayvan_id}')"><div class="arow-left"><div class="arow-id">${esc(s.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(s.grup||'')}</span></div><div class="arow-sub">${gunTxt} · Son: ${esc(s.son_aktivite||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
      }).join(''));
  }
  if(nearBirth.length){
    const nearSorted=[...nearBirth].sort((a,b)=>new Date(a.tarih)-new Date(b.tarih));
    h+=band('blue','🤰 Yaklaşan Doğumlar (≤7 gün)',
      nearSorted.map(b=>{
        const a=aMap&&aMap[b.hayvan_id];
        const kid=a?.kupe_no||a?.devlet_kupe||b.hayvan_id;
        const gun=Math.floor((Date.now()-new Date(b.tarih))/86400000);
        return `<div class="arow" onclick="openDet('${escAttr(b.hayvan_id)}')"><div class="arow-left"><div class="arow-id">${esc(kid)}</div><div class="arow-sub">${gun}. gün · ${Math.floor((new Date(b.tarih).getTime()+280*86400000-Date.now())/86400000)} gün kaldı</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
      }).join(''));
  }
  if(critStk>0){
    const cl2=stock.filter(s=>s.stok_durum==='kritik');
    h+=band('amber','⚠️ Kritik Stok',cl2.map(s=>`<div class="arow"><div class="arow-left"><div class="arow-id">${esc(s.urun_adi)}</div><div class="arow-sub">${(s.guncel_stok||0).toFixed(0)} ${s.birim||''} kaldı — eşik: ${s.esik}</div></div></div>`).join(''));
  }
  return h;
}
async function loadDash(){
  const el=document.getElementById('dash-body');
  try {
    const today=bugun();
    const [animals,diseases,tasks,stock,births60,gebeTohs,vaxLogs,vaccines,allKizginlik,allTohum]=await Promise.all([
      getData('hayvanlar',a=>a.durum==='Aktif'),
      getData('cases',c=>c.status==='active'),
      getData('gorev_log',t=>!t.tamamlandi&&!t.iptal),
      idbGetAll('stok'),
      getData('dogum',b=>b.tarih>=dAgo(63)&&b.tarih<=dAgo(58)),
      getData('tohumlama',t=>t.sonuc==='Gebe'),
      getData('vaccination_log'),
      getData('vaccines'),
      getData('kizginlik_log'),
      getData('tohumlama'),
    ]);
    const critStk=stock.filter(s=>s.stok_durum==='kritik').length;
    const negStk=stock.filter(s=>s.stok_durum==='tukendi').length;
    // parent_id olan ama parent'ı tamamlanmış görevler de top-level sayılır
    const _activePids=new Set(tasks.map(t=>t.id));
    const _isTop=t=>!t.parent_id||!_activePids.has(t.parent_id);
    const late=tasks.filter(t=>t.hedef_tarih<today&&_isTop(t));
    const todayT=tasks.filter(t=>t.hedef_tarih===today&&_isTop(t));
    const d7str=dFwd(null,7);
    const d1str=dFwd(null,1);
    const yakAsi=tasks.filter(t=>(t.gorev_tipi==='ASI_PLANLI'||t.gorev_tipi==='ILERI_GEBE_ASI')&&_isTop(t)&&t.hedef_tarih>today&&t.hedef_tarih<=d7str);
    const yakTakviye=tasks.filter(t=>t.gorev_tipi==='ILERI_GEBE'&&_isTop(t)&&t.hedef_tarih>today&&t.hedef_tarih<=d1str);
    const badge=late.length;
    const tb=document.getElementById('tbadge');
    if(tb){ tb.textContent=badge>99?'99+':badge; tb.style.display=badge>0?'flex':'none'; }
    const aMap={}; animals.forEach(a=>aMap[a.id]=a);
    const nearBirth=gebeTohs.filter(t=>{ if(!t.tarih)return false; const d=Math.floor((new Date(t.tarih).getTime()+280*86400000-Date.now())/86400000); return d>=0&&d<=7; });
    const ileriGebeler=window.__ileriGebeListesi||[];
    // Filter births60: hide if kizginlik or tohumlama recorded after birth
    const births60F=births60.filter(b=>{
      const hasK=allKizginlik.some(k=>k.hayvan_id===b.anne_id&&k.tarih>=b.tarih);
      const hasT=allTohum.some(t=>t.hayvan_id===b.anne_id&&t.tarih>=b.tarih);
      return !hasK&&!hasT;
    });
    const births60D=_dogumAnneBazliTekillestir(births60F);   // ikizde anne 1 kez
    // Buzağı sütten kesme otomatik kontrolü
    try {
      const resBuz=await rpc('buzagi_sutten_kesme_kontrol');
      if(resBuz&&resBuz.ok&&resBuz.olusturulan>0) toast('🍼 '+resBuz.olusturulan+' buzağı sütten kesme görevi oluşturuldu');
    } catch(e){ /* sessiz */ }

    // Sessiz hayvanlar listesi (dashboard band için)
    let sessizList=[];
    try{ const sl=await rpc('sessiz_hayvanlar_listele',{}); if(sl&&sl.length) sessizList=sl; }catch(e){/* sessiz */}

    // TEDAVI_GUN teşhis haritası (dashboard kartları için)
    const _dtDays=await idbGetAll('treatment_days').catch(()=>[]);
    const _dtDiseases=await idbGetAll('diseases').catch(()=>[]);
    const _dtDById=Object.fromEntries(_dtDiseases.map(d=>[d.id,d.name||'']));
    const _dtCases=await idbGetAll('cases').catch(()=>[]);
    const _dtCById=Object.fromEntries(_dtCases.map(c=>[c.id,c]));
    const _ddMap={};
    _dtDays.forEach(td=>{const c=_dtCById[td.case_id];if(c?.disease_id)_ddMap[td.id]=_dtDById[c.disease_id]||'';});

    const h=_dashStatRow(animals,gebeTohs,diseases,tasks,badge)+_dashBands(negStk,late,todayT,births60D,nearBirth,critStk,stock,ileriGebeler,aMap,yakAsi,yakTakviye,_ddMap,sessizList)+_dashVacAlerts(today,vaxLogs,vaccines);
    el.innerHTML=h||'<div class="empty"><div class="empty-ico">✅</div>Her şey yolunda</div>';
    // Protokol uyarı scanner (badge-only — açık ekranları yenilemez)
    try {
      const proto = await rpc('protokol_eksik_tara', {});
      window.__protokolUyarilar = Array.isArray(proto) ? proto : [];
      const aktif = window.__protokolUyarilar.filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
      const bb = document.getElementById('bellbadge');
      if (bb) {
        bb.textContent = aktif.length > 99 ? '99+' : aktif.length;
        bb.style.display = aktif.length > 0 ? 'flex' : 'none';
      }
    } catch(e) { console.warn('protokol_eksik_tara:', e.message); }
    // Transfer görev reconciliation (trigger'dan kaçanları kapat — idempotent)
    try { await rpc('padok_transfer_gorev_uzlastir', {}); } catch(e) { console.warn('gorev uzlastir:', e.message); }
    updateTaskBadge();
  } catch(e){
    el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}<br><button class="btn btn-o" style="margin-top:12px;width:auto;padding:8px 20px" onclick="loadDash()">Tekrar Dene</button></div>`;
  }
}
async function kizginlikYoktu(hayvanId, dogumId) {
  if (!confirm('Bu hayvanda kızgınlık gözlemlenmedi olarak kaydet?')) return;
  try {
    const res = await rpc('kizginlik_yok_kaydet', { p_hayvan_id: hayvanId, p_dogum_id: dogumId || null, p_notlar: null });
    if (res?.ok) {
      toast('📋 Kızgınlık yoktu kaydedildi');
      await pullTables(['kizginlik_log']);
      loadDash();
      if (typeof updateKizginlikAlert === 'function') updateKizginlikAlert();
    } else {
      toast('❌ ' + (res?.mesaj || 'Hata'), true);
    }
  } catch(e) { toast('❌ ' + e.message, true); }
}

// ── Kızgınlık → Tedavi Aç ────────────────────
function kizginlikTedaviAc(kayitId, kupe) {
  globalThis._kizginlikTedaviId = kayitId;
  openMWithHayvan('m-disease', 'd-hid', kupe);
}

// ── Kızgınlık Sil ────────────────────────────
async function kizginlikSil(kayitId) {
  if (!confirm('Bu kızgınlık kaydını silmek istediğinize emin misiniz?')) return;
  try {
    const res = await rpc('kizginlik_sil', { p_kayit_id: kayitId });
    toast('🗑️ Kızgınlık kaydı silindi');
    await pullTables(['kizginlik_log']);
    if (typeof loadUreme === 'function') loadUreme('kizginlik');
  } catch (e) {
    toast('❌ ' + e.message, true);
  }
}

// ── KIZGINLIK BAR ALERT ──────────────────────
async function updateKizginlikAlert() {
  try {
    const { data: _raw } = await db.from('cozulmemis_kizginlik_view')
      .select('hayvan_id,durum,gecen_saat')
      .neq('durum', 'cozuldu');
    // Aksiyon penceresi 48 saat — geçmiş kızgınlıklar uyarı üretmez (Geçti/Kaçırıldı)
    const data = (_raw || []).filter(d => d.gecen_saat == null || d.gecen_saat <= 48);
    const bar = document.getElementById('kizginlik-bar');
    const txt = document.getElementById('kizginlik-bar-txt');
    const badge = document.getElementById('ubadge');
    if (data?.length) {
      const uyariSayisi = data.filter(d => d.durum === 'uyari').length;
      bar.className = 'on ' + (uyariSayisi > 0 ? 'red' : 'amber');
      txt.textContent = '🔴 ' + data.length + ' hayvan kızgınlıkta — tohumlanmadı';
      if (badge) {
        const n = data.length;
        badge.textContent = n > 99 ? '99+' : n;
        badge.style.display = 'flex';
        badge.className = 'nbadge on';
      }
    } else {
      bar.className = '';
      if (badge) { badge.style.display = 'none'; badge.className = 'nbadge'; }
    }
  } catch(e) { /* sessiz */ }
}

async function asiDismiss(vacLogId, vaxName) {
  const note = prompt(`"${vaxName}" aşı uyarısını kapat\nNot giriniz (zorunlu):`);
  if (note === null) return; // cancelled
  if (!note.trim()) { toast('⚠️ Not zorunlu', true); return; }
  try {
    const res = await rpc('vaccination_dismiss', {
      p_vaccination_id: vacLogId,
      p_note: note.trim()
    });
    if (res?.ok) {
      toast('⏸️ Aşı uyarısı kapatıldı');
      await pullTables(['vaccination_log', 'islem_log']);
      loadDash();
    } else {
      toast('❌ ' + (res?.mesaj || 'Hata'), true);
    }
  } catch (e) {
    toast('❌ ' + e.message, true);
  }
}

async function showGebe(){
  goTo('suru');
  // B20: doğrudan renderAnimals çağırıp 250ms sonra debounce'lu filterA'ya
  // eziliyordu (goTo'nun fchipReset+filterA'ı chip'leri sıfırlıyordu). Chip
  // state'ini programatik seç, render'ı filterA'a bırak — sondaki filterA
  // çağrısı önceki zamanlayıcıyı clearTimeout ile iptal eder.
  _fchip.gebelik='gebe';
  document.querySelectorAll('[id^="fc-gebelik-"]').forEach(b=>b.classList.remove('on'));
  document.getElementById('fc-gebelik-gebe')?.classList.add('on');
  filterA();
}

function showHasta(){
  // Dashboard "Aktif Hastalık" kartı — showGebe ile aynı B20 deseni:
  // goTo('suru') fchipReset+filterA ile chip'leri sıfırladığından chip state'i
  // programatik seçilir, render'ı sondaki filterA bırakır.
  goTo('suru');
  _fchip.saglik='hasta';
  document.querySelectorAll('[id^="fc-saglik-"]').forEach(b=>b.classList.remove('on'));
  document.getElementById('fc-saglik-hasta')?.classList.add('on');
  filterA();
}

// ──────────────────────────────────────────
// GÖREVLER
// ──────────────────────────────────────────
// ── ERTELENMİŞ COMMIT (Model A) — bekleyen tamamlamalar ──
// Inline ✓ tıkları anında RPC göndermez; kuyruğa girer, filtre/sayfa değişiminde flush edilir.
let _pendingDone = new Map();   // key(gorevId|seansId) → {type,gorevId,params,cardId}
function _savePending(){
  try { localStorage.setItem('_pendingDone', JSON.stringify([..._pendingDone.values()])); } catch(e){}
}
function updatePendingFab(){
  const n=_pendingDone.size;
  const c=document.getElementById('fab-commit'), x=document.getElementById('fab-cancel');
  if(c){ c.style.display=n?'flex':'none'; c.title='Bekleyenleri gönder ('+n+')'; }
  if(x){ x.style.display=n?'flex':'none'; x.title='Hepsini iptal ('+n+')'; }
}
// Bekleyenleri iptal et — kuyruğu boşalt + işaretleri kaldır + listeyi tazele
function cancelPendingDone(){
  if(!_pendingDone.size) return;
  _pendingDone.clear(); _savePending(); updatePendingFab();
  loadTasks(_curTaskFilter||'today');
}
function _markPending(card, btn){
  if(card) card.classList.add('pending-done');
  if(btn){ btn.dataset.pending='1';
    btn.innerHTML='<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>'; }
}
function _unmarkPending(card, btn, type){
  if(card) card.classList.remove('pending-done');
  if(btn){ btn.dataset.pending='';
    btn.innerHTML = type==='seans' ? '' : '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>'; }
}
function togglePendingDone(type, gorevId, btn, extra){
  extra = extra || {};
  const key = type==='seans' ? extra.seansId : gorevId;
  if(!key) return;
  const card = btn ? btn.closest('.task-card, .seans-gorev-card') : null;
  if(_pendingDone.has(key)){
    _pendingDone.delete(key);
    _unmarkPending(card, btn, type);
  } else {
    _pendingDone.set(key, {type, gorevId, params:{gorevId, ...extra}, cardId:card?card.id:null});
    _markPending(card, btn);
  }
  _savePending();
  updatePendingFab();
}
async function flushPendingDone(){
  if(!_pendingDone.size) return;
  if(!navigator.onLine){ toast('⚠️ Çevrimiçi olunca uygulanacak'); return; }
  const items=[..._pendingDone.values()];
  _pendingDone.clear(); _savePending(); updatePendingFab();
  for(const it of items){
    try {
      if(it.type==='seans') await rpcSeansTamamla(it.params.seansId, it.params.uygulanmadi, null);
      else if(it.type==='besleme') await rpc('besleme_tamam', {p_gorev_id:it.params.gorevId});
      else if(it.type==='gorev') await rpc('gorev_tamamla', {p_gorev_id:it.params.gorevId, p_padok_hedef:it.params.padok||null});
    } catch(e){ toast('❌ Görev uygulanamadı: '+(e.message||''), true); }
  }
  try { await pullTables(['gorev_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','cases']); } catch(e){}
  if(typeof updateTaskBadge==='function') updateTaskBadge();
}
async function recoverPendingDone(){
  try {
    const raw=localStorage.getItem('_pendingDone'); if(!raw) return;
    const arr=JSON.parse(raw)||[]; if(!arr.length) return;
    arr.forEach(e=>{ const key=e.type==='seans'?e.params.seansId:e.params.gorevId; if(key) _pendingDone.set(key,e); });
    await flushPendingDone();
  } catch(e){ /* sessiz */ }
}
async function loadTasks(f,btn,opts){
  f=f||_curTaskFilter||'today';   // argümansız çağrı (ör. beslemeGunTamam) aktif filtreye düşsün — yoksa filtresiz tüm görevler (geciken dahil) listelenir
  _curTaskFilter=f;
  await flushPendingDone();   // filtre/modal kaynaklı render öncesi bekleyenleri commit et
  if(btn){ document.querySelectorAll('.fs-btn').forEach(b=>b.classList.remove('on')); btn.classList.add('on'); }
  // Bekleyen pencere chip şeridi — sadece 'all' tab'ında görünür, aktif chip _pendWin'e göre
  const _pendChips=document.getElementById('task-pend-chips');
  if(_pendChips){
    _pendChips.style.display = f==='all' ? 'flex' : 'none';
    if(f==='all'){
      const _active=_pendWin||'hepsi';
      _pendChips.querySelectorAll('.fchip').forEach(c=>c.classList.toggle('on', c.dataset.win===_active));
    }
  }
  const el=document.getElementById('tasks-body');
  const srchEl=document.getElementById('task-srch');
  if(srchEl){ srchEl.value=''; }
  await _keepScroll(el,async()=>{
  // Sadece cold load'da spinner göster — refresh'te eski liste yerinde kalsın (blink fix)
  if(!el.querySelector('.task-card')) el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const today=bugun();
    // skipPull: çağıran zaten pullTables yaptıysa içerideki tekrar pull'u atla (çift network fix)
    if(navigator.onLine && !(opts&&opts.skipPull)) await pullTables(['gorev_log','treatment_days','cases','diseases','treatment_day_uygulamalar','drug_administrations','drug_products','stok']).catch(()=>{});
    const all=await idbGetAll('gorev_log');
    if(f==='done'){
      // Besleme zincirinde her görev (ilk hariç) parent_id'li → eski filtre hepsini gizliyordu.
      // Sadece geri alınabilir ucu göster: çocuğu tamamlanmamış besleme tamamlaması.
      const _tamamliCocukluParent=new Set(all.filter(x=>x.tamamlandi&&x.parent_id).map(x=>x.parent_id));
      let done=all.filter(t=>{
        if(!t.tamamlandi||t.iptal) return false;
        if(t.gorev_tipi==='BESLEME') return !_tamamliCocukluParent.has(t.id);
        return !t.parent_id;
      });
      done.sort((a,b)=>(b.tamamlanma_tarihi||b.hedef_tarih||'').localeCompare(a.tamamlanma_tarihi||a.hedef_tarih||''));
      if(_taskKategori==='diger'){ done=done.filter(t=>!_allKatTips.includes(t.gorev_tipi)); }
      else if(_taskKategori!=='all'){ const tips=_katTipMap[_taskKategori]||[]; done=done.filter(t=>tips.includes(t.gorev_tipi)); }
      if(!done.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Henüz tamamlanan görev yok</div>'; return; }
      el.innerHTML=done.slice(0,150).map(t=>{
        const rapelChild=all.find(c=>c.parent_id===t.id&&!c.tamamlandi);
        const rapelStr=rapelChild?`<div style="font-size:.7rem;color:var(--blue);margin-top:2px">📅 Rapel: ${fmtTarih(rapelChild.hedef_tarih)}</div>`:'';
        return `<div class="task-card" style="border-left-color:var(--ink3);opacity:.75;cursor:pointer" onclick="openDoneTaskDet('${t.id}')">
        <div class="tc-header"><div class="tc-main">
          <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">
            <span class="tc-id">${(()=>{const h=getState('animals').find(a=>a.id===t.hayvan_id);return h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'GENEL');})()} </span>
            <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
          </div>
          <div class="tc-desc">${esc(t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').label||t.aciklama;}catch(e){return t.aciklama;}})():t.aciklama||'')}</div>
          <div class="tc-meta" style="color:var(--green)">✅ ${t.tamamlanma_tarihi ? fmtTarihSaat(t.tamamlanma_tarihi) : fmtTarih(t.hedef_tarih)}</div>
          ${rapelStr}
        </div></div>
      </div>`;
      }).join('');
      return;
    }
    // parent_id olan ama parent'ı tamamlanmış görevler top-level sayılır
    const _doneIds=new Set(all.filter(t=>t.tamamlandi).map(t=>t.id));
    let data=all.filter(t=>!t.tamamlandi&&!t.iptal&&(t.gorev_tipi==='TEDAVI_SEANS'||!t.parent_id||_doneIds.has(t.parent_id)));
    const _d7=dFwd(null,7);
    const _d1=dFwd(null,1);
    const _d30=dFwd(null,30);
    if(f==='today') data=data.filter(t=>t.hedef_tarih===today||((t.gorev_tipi==='ASI_PLANLI'||t.gorev_tipi==='ILERI_GEBE_ASI')&&t.hedef_tarih>today&&t.hedef_tarih<=_d7));
    else if(f==='late') data=data.filter(t=>t.hedef_tarih<today);
    else if(f==='all'){
      data=data.filter(t=>t.hedef_tarih>today);
      if(_pendWin==='yarin')   data=data.filter(t=>t.hedef_tarih===_d1);
      else if(_pendWin==='7')  data=data.filter(t=>t.hedef_tarih<=_d7);
      else if(_pendWin==='30') data=data.filter(t=>t.hedef_tarih<=_d30);
    }
    if(_taskKategori==='diger'){ data=data.filter(t=>!_allKatTips.includes(t.gorev_tipi)); }
    else if(_taskKategori!=='all'){ const tips=_katTipMap[_taskKategori]||[]; data=data.filter(t=>tips.includes(t.gorev_tipi)); }
    data.sort((a,b)=>{
      const dCmp=(a.hedef_tarih||'').localeCompare(b.hedef_tarih||'');
      if(dCmp!==0) return dCmp;
      const getTime=t=>t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').planned_time||'';}catch(e){return '';}})():'';
      return getTime(a).localeCompare(getTime(b))||(a.aciklama||'').localeCompare(b.aciklama||'');
    });
    if(!data.length){ el.innerHTML='<div class="empty"><div class="empty-ico">✅</div>Bu filtrede görev yok</div>'; return; }
    const allSubs=all.filter(t=>!!t.parent_id&&!t.tamamlandi);
    // TEDAVI_GUN için ilaç listesi: drug_administrations + stok isim haritası
    const _allDrugAdmins=await idbGetAll('drug_administrations').catch(()=>[]);
    const _allStokItems=await idbGetAll('stok').catch(()=>[]);
    const _stokNameMap=Object.fromEntries(_allStokItems.map(s=>[s.id,s.urun_adi||s.id]));
    const _allDrugProducts=await idbGetAll('drug_products').catch(()=>[]);
    const _prodMap=Object.fromEntries(_allDrugProducts.map(p=>[p.id,p]));
    const _dayDrugMap={};
    _allDrugAdmins.forEach(da=>{
      if(da.seans_admin_id) return; // saatli ilaçlar seans kartına gider, güne dump edilmez
      if(!_dayDrugMap[da.treatment_day_id])_dayDrugMap[da.treatment_day_id]=[];
      _dayDrugMap[da.treatment_day_id].push({name:_prodMap[da.drug_product_id]?.brand_name||_stokNameMap[da.stok_id]||'İlaç',dose:da.dose,unit:da.unit,route:da.route});
    });
    // TEDAVI_GUN için teshis adı: treatment_days → cases → diseases
    const _allTDays=await idbGetAll('treatment_days').catch(()=>[]);
    const _allTaskCases=await idbGetAll('cases').catch(()=>[]);
    const _allTaskDiseases=await idbGetAll('diseases').catch(()=>[]);
    const _caseById=Object.fromEntries(_allTaskCases.map(c=>[c.id,c]));
    const _diseaseById=Object.fromEntries(_allTaskDiseases.map(d=>[d.id,d.name||'']));
    const _dayDiseaseMap={};
    _allTDays.forEach(td=>{ const c=_caseById[td.case_id]; if(c?.disease_id)_dayDiseaseMap[td.id]=_diseaseById[c.disease_id]||''; });
    const _allSeans=await idbGetAll('treatment_day_uygulamalar').catch(()=>[]);
    const _seansById=Object.fromEntries(_allSeans.map(s=>[s.id,s]));
    const _tdById=Object.fromEntries(_allTDays.map(td=>[td.id,td]));
    const _caseDayCount={};
    _allTDays.forEach(td=>{ _caseDayCount[td.case_id]=(_caseDayCount[td.case_id]||0)+1; });
    // Gün başına seans ilerlemesi (ayraçta "1/3 seans")
    const _seansDayStat={};
    _allSeans.forEach(s=>{ const d=_seansDayStat[s.treatment_day_id]||(_seansDayStat[s.treatment_day_id]={total:0,done:0}); d.total++; if(s.uygulama_tamamlandi_at||s.uygulanmadi)d.done++; });
    // --- Seans görevlerini ayır, gruplara böl ---
    const seansDayIds=new Set();
    data.forEach(t=>{ if(t.gorev_tipi==='TEDAVI_SEANS'){ const sd=_seansById[t.seans_admin_id]; if(sd?.treatment_day_id)seansDayIds.add(sd.treatment_day_id); } });
    // TEDAVI_GUN gorev aciklamasi JSON {day_id, planned_time, label, ...} — try/catch fallback
    const _gorevAciklama=t=>{ try{ return JSON.parse(t.aciklama||'{}'); }catch(e){ return {}; } };
    const grupMap={};
    data.forEach(t=>{
      if(t.gorev_tipi!=='TEDAVI_SEANS')return;
      const seans=_seansById[t.seans_admin_id]; if(!seans)return;
      const dayId=seans.treatment_day_id;
      const key=(t.hayvan_id||'')+'|'+dayId;
      if(!grupMap[key]){
        const td=_tdById[dayId];
        const animal=getState('animals').find(a=>a.id===t.hayvan_id);
        grupMap[key]={ hayvan_id:t.hayvan_id, day_id:dayId,
          date:t.hedef_tarih||td?.treatment_date||'',
          gunNo:td?.day_no||'?', totalGun:td?_caseDayCount[td.case_id]||0:0,
          animalLabel:animal?(animal.kupe_no||animal.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'—'),
          disease:_dayDiseaseMap[dayId]||'',
          seansTotal:_seansDayStat[dayId]?.total||0, seansDone:_seansDayStat[dayId]?.done||0,
          items:[] };
      }
      grupMap[key].items.push({ task:t, seans,
        drugName:_prodMap[seans.drug_product_id]?.brand_name||_stokNameMap[seans.stok_id]||'İlaç' });
    });
    // --- Blokları (normal kart + seans grubu) tek listede sırala ---
    const bloklar=[];
    data.forEach(t=>{
      if(t.gorev_tipi==='TEDAVI_SEANS')return;
      if(t.gorev_tipi==='TEDAVI_GUN'){ if(seansDayIds.has(_gorevAciklama(t).day_id))return; }
      const planTime=t.gorev_tipi==='TEDAVI_GUN'?(_gorevAciklama(t).planned_time||''):'';
      bloklar.push({ sort:(t.hedef_tarih||'')+'|'+(planTime||'~')+'|n', type:'normal', task:t });
    });
    Object.values(grupMap).forEach(g=>{
      g.items.sort((a,b)=>(a.seans.planned_time||'').localeCompare(b.seans.planned_time||''));
      const ilk=g.items[0]?.seans.planned_time||'';
      bloklar.push({ sort:(g.date||'')+'|'+(ilk||'~')+'|s', type:'seans', grup:g });
    });
    bloklar.sort((a,b)=>a.sort.localeCompare(b.sort));
    el.innerHTML=bloklar.slice(0,200).map(b=>{
      if(b.type==='seans'){
        const g=b.grup;
        return renderSeansGrupAyrac(g)+'<div class="seans-grup-wrap">'+
          g.items.map(it=>renderSeansGorevKart(it.task,it.seans,{drugName:it.drugName,date:g.date})).join('')+'</div>';
      }
      const t=b.task;
      const _diff=Math.floor((new Date(t.hedef_tarih)-Date.now())/86400000);
      const _clsBase=_diff<=3?'near':'';
      const _clsMid=t.hedef_tarih===today?'soon':_clsBase;
      const cls=t.hedef_tarih<today?'late':_clsMid;
      const _tDrugs=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return _dayDrugMap[JSON.parse(t.aciklama||'{}').day_id]||[];}catch(e){return [];}})():[];
      const _tDisease=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return _dayDiseaseMap[JSON.parse(t.aciklama||'{}').day_id]||'';}catch(e){return '';}})():'';
      return renderTask(t,cls,allSubs.filter(s=>s.parent_id===t.id),_tDrugs,_tDisease);
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
  });
}
// B34: görev çipinde ham stok UUID'si yerine ürün adı (bulunamazsa kısaltılmış id)
function _stokAdi(stokId){
  if(!stokId) return '';
  const s=(getState('stock')||[]).find(x=>x.id===stokId);
  return s?.urun_adi || (stokId.length>8 ? stokId.slice(0,8)+'…' : stokId);
}
// Aşı görevinden aşıyı çözümle: (1) stok_id→vaccines.stock_item_id, (2) aciklama ad-öneki.
// Ad-öneki adımı şart: Coglavax/Vac-Sules kataloğunda stock_item_id NULL (2026-06-19 seed
// stok yaratmadı) ve add_vaccination'ın ürettiği ASI_RAPEL görevleri bu aşılarla stok_id'siz doğar.
function _asiVaccineCoz(t,vaccines){
  if(!t) return null;
  const vaxList=vaccines||[];
  if(t.stok_id){
    const s=vaxList.find(v=>v.stock_item_id===t.stok_id);
    if(s) return s;
  }
  const ad=(t.aciklama||'').replace(/^\s*💉\s*/,'').trim().toLowerCase();
  if(!ad) return null;
  const adaylar=vaxList.filter(v=>v.name&&ad.startsWith(String(v.name).toLowerCase()));
  if(!adaylar.length) return null;
  return adaylar.sort((a,b)=>b.name.length-a.name.length)[0]; // en uzun ad öncelik
}
// Aşı→stok entegrasyonu: her aşının kalan stoğu (vaccines.stock_item_id → stok).
// Ev formülü: baslangic_miktar − Σ(iptal olmayan hareket) [stokHareketGor ile aynı].
// Saf tutuldu (okuma çağıranda) — unit test edilebilir.
function _asiStokKalanlar(vaccines,stockRows,hareketRows){
  const used={};
  (hareketRows||[]).forEach(m=>{ if(m.iptal||!m.stok_id) return; used[m.stok_id]=(used[m.stok_id]||0)+(+m.miktar||0); });
  const out={};
  (vaccines||[]).forEach(vx=>{
    if(!vx.stock_item_id){ out[vx.id]=null; return; }
    const s=(stockRows||[]).find(x=>x.id===vx.stock_item_id);
    out[vx.id]= s ? (+s.baslangic_miktar||0)-(used[vx.stock_item_id]||0) : null;
  });
  return out;
}
// Tek aşı için kalan (detay modalı kullanır)
async function _asiStokKalan(vax){
  if(!vax||!vax.stock_item_id) return null;
  const [stockRows,hmvs]=await Promise.all([getData('stok'),getData('stok_hareket')]); // IDB store adı 'stok'
  return _asiStokKalanlar([vax],stockRows,hmvs)[vax.id];
}
// Detaydaki aşı formu alanlarını (ad + doz) verilen aşıya kurar; vax null ise sıfırlar.
function _asiFormVaxKur(vax){
  const adiEl=document.getElementById('td-asi-adi');
  const dozEl=document.getElementById('td-asi-doz');
  const dozInfo=document.getElementById('td-asi-doz-info');
  const dozUnit=document.getElementById('td-asi-doz-unit');
  if(adiEl) adiEl.textContent=vax?(vax.name||'—'):'—';
  if(dozEl){ dozEl.value=vax?.dose??''; dozEl.placeholder=vax?.dose??''; }
  if(dozInfo) dozInfo.textContent='St: '+((vax?.dose)??'?')+' '+(vax?.unit||'ml');
  if(dozUnit) dozUnit.textContent='('+(vax?.unit||'ml')+')';
}
// Toplu görev: tek alt görevi uygula (detaydaki tarih ile)
async function topluTekUygula(childId){
  try{
    const tarih=document.getElementById('td-asi-tarih')?.value||bugun();
    const res=await rpc('asi_planli_tamamla',{p_gorev_id:childId,p_tarih:tarih});
    if(!res||res.ok===false){ toast(_trErr(res?.mesaj||'Hata'),true); return; }
    toast('✅ Uygulandı');
    await pullTables(['gorev_log','vaccination_log','stok','stok_hareket']).catch(()=>{});
    if(_curTaskDet) openTaskDet(_curTaskDet.id);
  }catch(e){ toast(_trErr(e.message),true); }
}
// Toplu görev: açık tüm alt görevleri sırayla uygula
async function topluHepsiniUygula(){
  const tarih=document.getElementById('td-asi-tarih')?.value||bugun();
  const children=_curTaskTopluChildren||[];
  if(!children.length){ toast('Uygulanacak aşı yok',true); return; }
  let ok=0,hata=0;
  for(const c of children){
    try{
      const res=await rpc('asi_planli_tamamla',{p_gorev_id:c.id,p_tarih:tarih});
      if(res&&res.ok) ok++; else hata++;
    }catch(e){ hata++; }
  }
  if(ok>0){
    try{ await rpc('gorev_tamamla',{p_gorev_id:_curTaskDet.id}); }catch(e){}
    await pullTables(['gorev_log','vaccination_log','stok','stok_hareket']).catch(()=>{});
    toast(`✅ ${ok} aşı uygulandı${hata?` · ${hata} hata`:''}`);
    closeM('m-task-det');
    updateTaskBadge();
    loadTasks(_curTaskFilter||'today',null,{skipPull:true});
    loadDash();
  } else {
    toast('Hiçbir aşı uygulanamadı',true);
  }
}
// td-asi-vax select'i değişince uygulanacak aşıyı ve doz bilgisini güncelle
// (index.html'deki onchange attribute'u çağırır — modal router uyumu için DOM property yok)
async function tdAsiVaxSec(vId){
  _curTaskVaccineId=vId||null;
  if(!vId){ _asiFormVaxKur(null); return; }
  try{
    const vaccines=await getData('vaccines');
    _asiFormVaxKur((vaccines||[]).find(v=>v.id===vId)||null);
  }catch(e){ console.warn('vaccine lookup:',e.message); }
}

function renderTask(t,cls='',subs=[],drugs=[],diseaseName=''){
  const planTime=t.gorev_tipi==='TOHUMLAMA_PLANLI'
    ? (t.hedef_saat||'').slice(0,5)
    : t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').planned_time||'';}catch(e){return '';}})():'';
  const doneSubs=subs.filter(s=>s.tamamlandi).length;
  const allDone=subs.length>0&&doneSubs===subs.length;
  const subHtml=subs.length?`<div class="subtasks">
    ${subs.map(s=>`<div class="st-row">
      <div class="st-check ${s.tamamlandi?'done':''}" onclick="toggleSub('${s.id}','${t.id}',this)">
        ${s.tamamlandi?`<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>`:''}
      </div>
      <span class="st-label ${s.tamamlandi?'done':''}">${(()=>{try{const p=JSON.parse(s.aciklama||'{}');return esc(p.label||s.aciklama);}catch(e){return esc(s.aciklama);}})()}</span>
    </div>`).join('')}
    <div class="st-prog">${doneSubs}/${subs.length} tamamlandı</div>
  </div>`:'';
  const drugHtml=drugs.length?`<div class="subtasks" style="margin-top:4px">
    ${drugs.map(d=>`<div class="st-row">
      <span style="font-size:.7rem;min-width:16px;text-align:center;color:var(--blue)">💊</span>
      <span class="st-label" style="font-size:.72rem">${esc(d.name)}<span style="color:var(--ink3);margin-left:4px">${d.dose}${d.unit}${d.route?' · '+d.route:''}</span></span>
    </div>`).join('')}
    <div class="st-prog">${drugs.length} ilaç planlandı</div>
  </div>`:'';
  return `<div class="task-card ${cls}${allDone?' done':''}" id="tc-${t.id}" onclick="openTaskDet('${t.id}')" style="cursor:pointer">
    <div class="tc-header">
      <div class="tc-main">
        <div style="display:flex;align-items:center;gap:7px;flex-wrap:wrap">
          <span class="tc-id">${(()=>{const h=getState('animals').find(a=>a.id===t.hayvan_id);return h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'—');})()} </span>
          <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi==='ASI_PLANLI'||t.gorev_tipi==='ASI_HATIRLATMA'||t.gorev_tipi==='ASI_RAPEL')?'💉 ':''}${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
          ${diseaseName?`<span class="pill" style="background:rgba(192,50,26,.1);color:var(--red);border:1px solid rgba(192,50,26,.2)">🏥 ${esc(diseaseName)}</span>`:''}
        </div>
        <div class="tc-desc">${esc(t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').label||t.aciklama;}catch(e){return t.aciklama;}})():t.aciklama||'')}</div>
        <div class="tc-meta"><span>${fmtTarih(t.hedef_tarih)}${planTime?` <span style="color:var(--blue);font-size:.65rem">🕐 ${planTime}</span>`:''}</span>${t.stok_id?`<span>💊 ${esc(_stokAdi(t.stok_id))}</span>`:''}</div>
      </div>
      ${subs.length===0&&t.gorev_tipi==='BESLEME'?`<button class="ck-btn" onclick="event.stopPropagation();togglePendingDone('besleme','${t.id}',this)">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
      </button>`:''}
      ${subs.length===0&&t.gorev_tipi!=='ASI_PLANLI'&&t.gorev_tipi!=='ILERI_GEBE_ASI'&&t.gorev_tipi!=='BESLEME'&&t.gorev_tipi!=='TEDAVI_GUN'&&t.gorev_tipi!=='TOHUMLAMA_PLANLI'?`<button class="ck-btn" data-padok="${escAttr(t.padok_hedef||'')}" onclick="event.stopPropagation();togglePendingDone('gorev','${t.id}',this,{padok:this.dataset.padok})">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
      </button>`:''}
    </div>
    ${drugHtml}${subHtml}
  </div>`;
}
// Görev listesi: hayvan+gün seans grubu ayracı
function renderSeansGrupAyrac(g){
  const gun = `Gün ${g.gunNo}${g.totalGun?'/'+g.totalGun:''}`;
  const dis = g.disease ? ` · 🏥 ${esc(g.disease)}` : '';
  const prog = g.seansTotal ? ` · ${g.seansDone}/${g.seansTotal} seans` : '';
  const tarih = g.date ? ` · ${fmtTarih(g.date)}` : '';
  return `<div class="seans-grup-ayrac">🐄 ${esc(g.animalLabel||'—')} · ${gun}${dis}${prog}${tarih}</div>`;
}
// Görev listesi: tek seans kartı (checkbox + ▾ inline iade)
function renderSeansGorevKart(task, seans, opts={}){
  const s = { ...seans, planned_date: seans.planned_date || opts.date };
  const state = computeSeansState(s);
  const kapali = state==='done' || state==='cancelled';
  const saat = fmtSeansSaat(s.planned_time) || '—';
  const drug = esc(opts.drugName || 'İlaç');
  const meta = [`${s.dose||''}${s.unit||''}`, s.route].filter(Boolean).join(' · ');
  const durumEk = {
    'now':       '<span class="sg-now">◀ şimdi</span>',
    'overdue':   `<span class="sg-late">⚠ ${esc(fmtBeklemeSure(s))} gecikti</span>`,
    'due-soon':  `<span class="sg-soon">◐ ${esc(fmtBeklemeSure(s))} sonra</span>`,
  }[state] || '';
  if(kapali){
    const dt = state==='done'
      ? `✓ ${esc(fmtSaatKisa(s.uygulama_tamamlandi_at)||'')}`.trim()
      : '✕ Yapılamadı';
    return `<div class="seans-gorev-card s-${state} done-card">
      <span class="sg-check sg-done">✓</span>
      <span class="sg-saat">${esc(saat)}</span>
      <div class="sg-info"><div class="sg-ilac">${drug}</div><div class="sg-meta">${esc(meta)}</div></div>
      <span class="seans-chip s-${state}">${dt}</span>
    </div>`;
  }
  return `<div class="seans-gorev-card s-${state}" id="sg-${task.id}">
    <button class="sg-check" onclick="event.stopPropagation();togglePendingDone('seans','${task.id}',this,{seansId:'${seans.id}',uygulanmadi:false})" title="Uygulandı"></button>
    <span class="sg-saat">${esc(saat)}</span>
    <div class="sg-info"><div class="sg-ilac">${drug}</div><div class="sg-meta">${esc(meta)}${durumEk?' '+durumEk:''}</div></div>
    <button class="sg-expand" onclick="event.stopPropagation();toggleSeansAksiyon('${task.id}')" title="Diğer işlemler">▾</button>
    <div class="sg-actions" id="sga-${task.id}" style="display:none">
      <button class="sg-act-iade" onclick="event.stopPropagation();togglePendingDone('seans','${task.id}',this,{seansId:'${seans.id}',uygulanmadi:true})">↩ Yapılmadı · stok iade</button>
    </div>
  </div>`;
}
// Seans kartı ▾ inline aksiyon aç/kapat
function toggleSeansAksiyon(taskId){
  const el = document.getElementById('sga-'+taskId);
  if(!el) return;
  const open = el.style.display !== 'none';
  el.style.display = open ? 'none' : 'block';
  const exp = document.querySelector('#sg-'+taskId+' .sg-expand');
  if(exp) exp.textContent = open ? '▾' : '▴';
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
// ── Görev detay modalı: alt görev paneli + grup tamamlama (bölünme fix'i, 2026-09-01) ──
// Özel tipli alt görevler asla düz PATCH ile kapatılmaz: kendi RPC'leri (aşı kaydı,
// besleme zinciri, tedavi seansı, sütten kesme) bypass edilirdi. Bunlar modalda
// statik bilgi satırıdır ('⚙ form ile kapatılır'); tıklanabilir checkbox yalnız
// plain alt görevlerde. Ana görev, hiçbir tipte açık çocuk kalmadığında kapanır —
// aksi hâlde kapanan parent'ın açık çocukları top-level karta bölünür (analiz §2).
const OZEL_ALT_TIPLER=['ASI_PLANLI','ILERI_GEBE_ASI','BESLEME','TEDAVI_GUN','TEDAVI_SEANS','TOHUMLAMA_PLANLI','SUTTEN_KESME'];
function detayAltTiklanabilir(sub){ return !OZEL_ALT_TIPLER.includes(sub.gorev_tipi||''); }
// Tamamla butonu etiketi: açık plain alt yoksa mevcut etiket, varsa grup sayacı.
function detayBtnEtiketi(acikSafSayi){
  if(!acikSafSayi||acikSafSayi<=0) return '✅ Tamamlandı Olarak İşaretle';
  return `✅ ${acikSafSayi} alt görevle birlikte tamamla`;
}
// td-subs içeriği: bugünkü görsel dil korunur (yuvarlak st-check + üstü çizili done
// etiketi). Plain satırlar toggleSubDet'e HTML attribute onclick ile bağlanır —
// DOM property onclick modal router ile yarışır (AGENTS.md kuralı, 684534f deseni).
function renderTaskDetSubs(subsDone,subsAcik,parentId){
  const head=`<div style="font-size:.65rem;font-weight:700;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Alt Görevler (${subsDone.length}/${subsDone.length+subsAcik.length})</div>`;
  const rows=[...subsDone,...subsAcik].map(s=>{
    const label=(()=>{try{const p=JSON.parse(s.aciklama||'{}');return esc(p.label||s.aciklama);}catch(e){return esc(s.aciklama);}})();
    const tik=detayAltTiklanabilir(s);
    const check=`<div class="st-check ${s.tamamlandi?'done':''}"${tik?` onclick="toggleSubDet('${s.id}','${parentId}',this)"`:''} style="width:18px;height:18px;background:${s.tamamlandi?'var(--green)':'var(--card2)'};border:2px solid ${s.tamamlandi?'var(--green)':'var(--card3)'};${tik?'cursor:pointer':'cursor:default'}">${s.tamamlandi?'<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>':''}</div>`;
    return `<div style="display:flex;align-items:center;gap:8px;padding:5px 0;border-bottom:1px solid var(--card2)">
      ${check}
      <span style="font-size:.8rem;color:var(--ink);${s.tamamlandi?'text-decoration:line-through;opacity:.6':''}">${label}${tik?'':'<span style="font-size:.62rem;color:var(--ink3);margin-left:6px">⚙ form ile kapatılır</span>'}</span>
    </div>`;
  }).join('');
  return head+rows;
}
// td-subs panelini + tamamla butonu etiketini IDB'den taze okuyup yeniden çizer
// (toggleSubDet ve grupTamamla ortak çıktısı — modal içi sayaç/etiket senkronu, K1).
async function _detaySubsVeEtiket(parentId){
  const all=await idbGetAll('gorev_log');
  const subsDone=all.filter(s=>s.parent_id===parentId&&s.tamamlandi);
  const subsAcik=all.filter(s=>s.parent_id===parentId&&!s.tamamlandi);
  const subsEl=document.getElementById('td-subs');
  if(subsEl){
    if(subsDone.length+subsAcik.length>0){
      subsEl.style.display='block';
      subsEl.innerHTML=renderTaskDetSubs(subsDone,subsAcik,parentId);
    } else { subsEl.style.display='none'; }
  }
  const btn=document.getElementById('td-tamam-btn');
  // Etiketi yalnız standart tamamla butonuna yaz — TOHUMLAMA_PLANLI override'ını ve
  // gizli butonlu özel tipleri (ILERI_GEBE_ASI/TEDAVI_GUN) ezme.
  if(btn&&_curTaskDet&&_curTaskDet.id===parentId&&btn.style.display!=='none'&&_curTaskDet.gorev_tipi!=='TOHUMLAMA_PLANLI'){
    btn.textContent=detayBtnEtiketi(subsAcik.filter(s=>detayAltTiklanabilir(s)).length);
  }
}
// Modal içi alt görev toggle — toggleSub semantiği (REST PATCH, tarih set/clear).
// Parent burada KAPANMAZ: tek aksiyon noktası "tamamla" butonudur (grupTamamla).
async function toggleSubDet(subId,parentId,el){
  const subs=await getData('gorev_log',t=>t.id===subId);
  const sub=subs[0]; if(!sub) return;
  if(!detayAltTiklanabilir(sub)) return; // savunma: özel tipler form ile kapanır
  const nowDone=!sub.tamamlandi;
  await write('gorev_log',{...sub,tamamlandi:nowDone,tamamlanma_tarihi:nowDone?new Date().toISOString():null},'PATCH',`id=eq.${subId}`);
  await _detaySubsVeEtiket(parentId);
  await loadTasks(_curTaskFilter||'today');
  loadDash();
}
// Grup tamamlama: açık plain altlar sıralı PATCH ile kapanır (hata → dur + toast,
// parent'a dokunulmaz — bölünme yok). Sonra hâlâ açık çocuk (özel tip) varsa parent
// AÇIK kalır; yoksa mevcut doneTask yolu → gorev_tamamla RPC (islem_log izi, K3).
async function grupTamamla(parent,acikSafAltlar){
  const btn=document.getElementById('td-tamam-btn');
  if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
  try{
    for(const s of acikSafAltlar){
      await write('gorev_log',{...s,tamamlandi:true,tamamlanma_tarihi:new Date().toISOString()},'PATCH',`id=eq.${s.id}`);
    }
  }catch(e){
    toast(e.message,true);
    await _detaySubsVeEtiket(parent.id); // kapananlar tasarıya yansısın, etiket doğru kalsın
    if(btn) btn.disabled=false;
    return;
  }
  const cocuklar=(await idbGetAll('gorev_log')).filter(s=>s.parent_id===parent.id);
  const acik=cocuklar.filter(s=>!s.tamamlandi);
  if(acik.length){
    await _detaySubsVeEtiket(parent.id);
    if(btn) btn.disabled=false;
    toast(`✅ ${acikSafAltlar.length} alt görev tamamlandı, özel görevler açık`);
    return;
  }
  await doneTask(parent.id,parent.hayvan_id||'',parent.stok_id||'',+parent.miktar||0,parent.padok_hedef||'',{disabled:false,innerHTML:''});
  toast(`✅ ${acikSafAltlar.length} alt görev ve ana görev tamamlandı`);
  closeM('m-task-det');
  await loadTasks(_curTaskFilter||'today');
}
// onConfirm module değişkenine alınır; OK butonu index.html'de attribute onclick
// ile bağlanır (DOM property onclick modal router closeM→history.back yarışına
// girer — AGENTS.md kuralı, td-hayvan/684534f deseni)
let _confirmAction = null;
function openConfirm(title, desc, onConfirm){
  document.getElementById('m-confirm-title').textContent=title;
  document.getElementById('m-confirm-desc').textContent=desc;
  _confirmAction = onConfirm;
  openM('m-confirm');
}
function _confirmOk(){
  closeM('m-confirm');
  const fn = _confirmAction; _confirmAction = null;
  if (typeof fn === 'function') fn();
}
async function updateTaskBadge(){
  try{
    const today=bugun();
    const all=await idbGetAll('gorev_log');
    const doneIds=new Set(all.filter(t=>t.tamamlandi).map(t=>t.id));
    const tasks=all.filter(t=>!t.tamamlandi&&(t.gorev_tipi==='TEDAVI_SEANS'||!t.parent_id||doneIds.has(t.parent_id)));
    const late=tasks.filter(t=>t.hedef_tarih<today).length;
    const tb=document.getElementById('tbadge');
    if(tb){ tb.textContent=late>99?'99+':late; tb.style.display=late>0?'flex':'none'; }
  } catch(e){ /* sessiz fail */ }
}
// doneTask removed — forms.js versiyonu kullaniliyor (RPC ile)

async function beslemeGunTamam(id,btn){
  btn.disabled=true;
  btn.innerHTML='<div class="spin" style="width:14px;height:14px;border-width:2px"></div>';
  try {
    const r=await rpc('besleme_tamam',{p_gorev_id:id});
    if(!r?.ok) throw new Error(r?.mesaj||'Hata');
    const msg=r.zincir==='hayvan_artik_gebe_degil'
      ?'✅ Besleme tamamlandı — hayvan artık gebe değil, zincir kapandı'
      :'✅ Besleme tamamlandı — yarın için görev oluşturuldu';
    toast(msg);
    const elT=document.getElementById('tc-'+id);
    if(elT){ elT.classList.add('done'); setTimeout(()=>elT.remove(),320); }
    updateTaskBadge();
    loadDash();
    loadTasks(_curTaskFilter||'today');
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
    const animals=await getData('hayvanlar',a=>a.durum==='Aktif');
    if(typeof setState==='function') setState('animals',animals);
    if(typeof setState==='function'){ try{ setState('protokol_ayar', await getData('protokol_ayar')); }catch(e){/* config yoksa fallback default kullanılır */} }
    const gebeTohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
    setState('gebeIds', [...new Set(gebeTohs.map(t=>t.hayvan_id))]);
    // Tohumlama tarihi haritası (gebe badge'de gün hesabı için)
    globalThis._tohMap={};
    gebeTohs.forEach(t=>{ if(!globalThis._tohMap[t.hayvan_id]||t.tarih>globalThis._tohMap[t.hayvan_id]) globalThis._tohMap[t.hayvan_id]=t.tarih; });
    // Bekleyen tohumlama haritası (sadece sonuc=Bekliyor — badge için)
    const bosTohs=await getData('tohumlama',t=>t.sonuc==='Bekliyor');
    globalThis._bosTohMap={};
    bosTohs.forEach(t=>{
      if(!globalThis._bosTohMap[t.hayvan_id]||t.tarih>globalThis._bosTohMap[t.hayvan_id]) globalThis._bosTohMap[t.hayvan_id]=t.tarih;
    });
    // Son doğum (buzağılama) haritası — anne_id başına en son tarih
    const dogumlar=await getData('dogum');
    globalThis._sonDogumMap={};
    dogumlar.forEach(d=>{
      if(!d.anne_id||!d.tarih) return;
      if(!globalThis._sonDogumMap[d.anne_id]||d.tarih>globalThis._sonDogumMap[d.anne_id]) globalThis._sonDogumMap[d.anne_id]=d.tarih;
    });
    // Son tohumlama haritası — SONUÇ FARK ETMEZ, hayvan_id başına en son tarih
    // (doğumdan sonra hiç tohumlama yok kontrolü için — _tohMap/_bosTohMap yetersiz)
    const tumTohs=await getData('tohumlama');
    globalThis._sonTohMap={};
    tumTohs.forEach(t=>{
      if(!t.hayvan_id||!t.tarih) return;
      if(!globalThis._sonTohMap[t.hayvan_id]||t.tarih>globalThis._sonTohMap[t.hayvan_id]) globalThis._sonTohMap[t.hayvan_id]=t.tarih;
    });
    const hastaLogs=await getData('cases',c=>c.status==='active');
    setState('hastaIds', new Set(hastaLogs.map(d=>d.animal_id)));
    // Hastalık filtresi seçenekleri + vaka açılış sıralaması için aktif vaka satırları
    setState('aktifVakalar', hastaLogs);
    try{ setState('diseases', await getData('diseases')); }catch(e){/* diseases okunamazsa seçenek adı '?' düşer */}
    const sorted=[...animals].sort((a,b)=>(a.kupe_no||a.id||'').localeCompare(b.kupe_no||b.id||''));
    renderAnimals(sorted);
    _renderSuruStat();
    if (typeof renderPadokDolulukBar === 'function') renderPadokDolulukBar();
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}
// Doğum yapmış + son doğumdan sonra hiç tohumlanmamış (kısır hariç) → gün sayısı, değilse null
function _yeniDogumGun(a){
  if(a.kisir) return null;
  const dogumTarih=(globalThis._sonDogumMap||{})[a.id];
  if(!dogumTarih) return null;
  const sonToh=(globalThis._sonTohMap||{})[a.id];
  if(sonToh && sonToh>=dogumTarih) return null;   // doğumdan sonra tohumlanmış
  const gun=Math.floor((Date.now()-new Date(dogumTarih).getTime())/86400000);
  return gun>0 ? gun : null;
}
function _animalTagsHtml(a,gebeSet){
  const isGebe=gebeSet.has(a.id);
  let gebeBadge='';
  if(isGebe){
    // Tohumlama tarihinden gün hesapla
    const tohMap=globalThis._tohMap||{};
    const tohTarih=tohMap[a.id];
    let gunYazi='';
    if(tohTarih){
      const gun=Math.floor((Date.now()-new Date(tohTarih).getTime())/86400000);
      if(gun>0){ const ay=Math.floor(gun/30),g=gun%30; gunYazi=` · ${ay} ay ${g} gün`; }
    }
    gebeBadge=`<span class="tag" style="background:rgba(78,154,42,.15);color:var(--green);font-weight:700">🤰 Gebe${gunYazi}</span>`;
  }
  const hastaBadge=(getState('hastaIds')||new Set()).has(a.id)?`<span class="tag" style="background:rgba(192,50,26,.12);color:var(--red);font-weight:700">🏥 Hasta</span>`:'';
  const abortBadge=a.abort_sayisi>0?`<span class="tag" style="background:rgba(192,50,26,.18);color:var(--red);font-size:.65rem;font-weight:700;border:1px solid rgba(192,50,26,.3)">⚠️ ${a.abort_sayisi}x abort</span>`:'';
  let bosTohBadge='';
  if(!isGebe){
    const bosTohMap=globalThis._bosTohMap||{};
    const tohTarih=bosTohMap[a.id];
    if(tohTarih){
      const gun=Math.floor((Date.now()-new Date(tohTarih).getTime())/86400000);
      if(gun>0) bosTohBadge=`<span class="tag" style="background:rgba(255,160,0,.12);color:var(--amber);font-weight:700">💉 ${gun} gün önce tohumlandı</span>`;
    }
  }
  let dogumBadge='';
  const _dGun=_yeniDogumGun(a);
  if(_dGun!=null) dogumBadge=`<span class="tag" style="background:rgba(255,160,0,.12);color:var(--amber);font-weight:700">🐣 ${_dGun} gün önce doğum yaptı</span>`;
  const kisirBadge=a.kisir?`<span class="tag" style="background:rgba(255,160,0,.15);color:var(--amber);font-weight:700;font-size:.65rem">💲 Kısır</span>`:'';
  // Repeat breed badge (backend view'dan gelir: repeat_breed_active, repeat_breed_past)
  let repeatBadge='';
  if(a.repeat_breed_active) repeatBadge+=`<span class="repeat-badge active">🔁 Tekrar Aşım</span>`;
  if(a.repeat_breed_past)   repeatBadge+=`<span class="repeat-badge past">↻ Tekrar</span>`;
  return `<span class="tag tb">${esc(a.padok||'?')}</span><span class="tag tk">${esc(a.grup||'')}</span>${gebeBadge}${hastaBadge}${abortBadge}${bosTohBadge}${dogumBadge}${kisirBadge}${repeatBadge}`;
}
function _animalCardHtml(a,gebeSet,idx){
  const mainId=a.kupe_no||a.devlet_kupe||a.id||'?';
  const subId=a.kupe_no&&a.devlet_kupe?`<span style="font-size:.65rem;color:var(--ink3);font-weight:400"> · ${a.devlet_kupe}</span>`:'';
  const init=mainId.replace(/\D/g,'').slice(-3)||mainId.slice(0,2).toUpperCase();
  const yas=yasHesapla(a.dogum_tarihi);
  const seqHtml=idx!=null?`<span class="a-seq">${String(idx+1).padStart(2,'0')}</span>`:'';
  return `<div class="animal-card" data-id="${a.id}"
       onclick="if(typeof _btSecimModu!=='undefined'&&_btSecimModu){_btKartTikla('${a.id}',event)}else{openDet('${a.id}')}">
    <input type="checkbox" class="bt-cb"
           ${typeof _btSecilenIds!=='undefined'&&_btSecilenIds.includes(a.id)?'checked':''}
           onchange="event.stopPropagation();btCbDegisti('${a.id}',this.checked)">
    ${seqHtml}<div class="avt">${init}</div>
    <div class="ainfo">
      <div class="a-id">${mainId}${subId}</div>
      <div class="a-sub">${esc(a.irk||'—')}${yas?' · '+yas:''}</div>
      <div class="a-tags">${_animalTagsHtml(a,gebeSet)}</div>
    </div>
    <svg class="a-arr" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg>
  </div>`;
}
function renderAnimals(list,opts){
  const el=document.getElementById('suru-body');
  if(!list.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🐄</div>Hayvan bulunamadı</div>'; return; }
  const gebeSet=new Set(getState('gebeIds')||[]);
  const tohMap=globalThis._tohMap||{};
  // Gebe → gebelik günü; Bekliyor tohumlama → tarih DESC; diğer → küpe no.
  // opts.verilenSira: çağıran kendi sıralamasını verdi (hasta modu — vaka açılışı);
  // buradaki gebe/kupe sıralaması onu ezmesin.
  const bosTohMap=globalThis._bosTohMap||{};
  const sorted=(opts&&opts.verilenSira)?[...list]:[...list].sort((a,b)=>{
    const aT=gebeSet.has(a.id)||gebeSet.has(a.kupe_no)?tohMap[a.id]:null;
    const bT=gebeSet.has(b.id)||gebeSet.has(b.kupe_no)?tohMap[b.id]:null;
    if(aT&&bT) return aT.localeCompare(bT);
    if(aT) return -1;
    if(bT) return 1;
    const aBos=bosTohMap[a.id]||null;
    const bBos=bosTohMap[b.id]||null;
    if(aBos&&bBos) return aBos.localeCompare(bBos);
    if(aBos) return -1;
    if(bBos) return 1;
    return (a.kupe_no||a.id||'').localeCompare(b.kupe_no||b.id||'');
  });
  el.innerHTML=sorted.map((a,i)=>_animalCardHtml(a,gebeSet,i)).join('');
}

// ── SÜRÜ STAT KARTI ─────────────────────────
let _suruStatCache={};
let _suruStatOpen=false;
let _suruDenemeOpen=false;
let _suruSpermaOpen=false;
function _toggleSpermaRest(){
  _suruSpermaOpen=!_suruSpermaOpen;
  const el=document.getElementById('sperma-rest');
  if(el)el.style.display=_suruSpermaOpen?'block':'none';
  const parent=el?.parentElement;
  if(parent){const btn=parent.querySelector('[onclick*="toggleSpermaRest"]');if(btn)btn.textContent=_suruSpermaOpen?'Daralt':'[+'+(document.querySelectorAll('#sperma-rest .stat-row').length)+' daha]';}
}
// ── Sessiz sheet yardımcıları (REV-5 idle/sessiz-ui) ──
// Satır tıklanınca sheet remove EDİLMEZ — yalnız gizlenir; closeDet() geri
// gösterir (DOM korunduğu için scroll dahil). _sessizReturn: "det'ten çıkınca
// sheet'i geri aç" işareti; goTo ve popstate temizlik noktaları sıfırlar.
function _sessizSheetGizle(){
  const box=document.getElementById('sessiz-bs');
  if(box) box.style.display='none';
  globalThis._sessizReturn=true;
}
// Tam kapatma (backdrop tap) — pushState girdisi varsa tüket (protokol deseni)
function _sessizSheetKapat(){
  const box=document.getElementById('sessiz-bs');
  if(!box) return;
  box.remove();
  globalThis._sessizReturn=false;
  if(history.state?.sessiz_bs){ globalThis._modalBackGuard=true; history.back(); }
}
// Gruplu bölümleme — SAF fonksiyon (DOM yok, unit test: tests/unit/ui-pure.test.js).
// Grup sırası: en yüksek sessiz_gun'u içeren grup önce; grup içi sessiz_gun DESC.
// 'Hiç kayıt yok' (sessiz_gun>=9999) her zaman EN ALTta ayrı bölüm toplanır
// (sentinel-son kuralı, bb4ea92); satırda grubun kendi etiketi görünür kalır.
function _sessizGrupla(list){
  if(!list||!list.length) return [];
  const kayitsiz=list.filter(s=>s.sessiz_gun>=9999).sort((a,b)=>b.sessiz_gun-a.sessiz_gun);
  const diger=list.filter(s=>s.sessiz_gun<9999).sort((a,b)=>b.sessiz_gun-a.sessiz_gun);
  const groups=[];
  const byName=new Map();
  for(const s of diger){
    const gAd=s.grup||'Grupsuz';
    if(!byName.has(gAd)){ const sec={grup:gAd,items:[]}; byName.set(gAd,sec); groups.push(sec); }
    byName.get(gAd).items.push(s);
  }
  if(kayitsiz.length) groups.push({grup:'Hiç kayıt yok',items:kayitsiz});
  return groups;
}
async function _showSessizList(){
  try{
    const list=await rpc('sessiz_hayvanlar_listele',{});
    if(!list||!list.length){toast('Sessiz hayvan yok');return;}
    globalThis._sessizReturn=false; // taze açılış eski dönüş işaretini ezer
    const existedBefore=!!document.getElementById('sessiz-bs'); // öksüz history girdisi birikmesin (proto-detay deseni)
    let box=document.getElementById('sessiz-bs');
    if(box) box.remove();
    box=document.createElement('div');
    box.id='sessiz-bs';
    box.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
    box.onclick=e=>{if(e.target===box)_sessizSheetKapat();};
    const row=s=>`<div class="arow" onclick="_sessizSheetGizle();openDet('${s.hayvan_id}')" style="cursor:pointer"><div class="arow-left"><div class="arow-id">${esc(s.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(s.grup||'')}</span></div><div class="arow-sub">${s.sessiz_gun>=9999?'Hiç kayıt yok':s.sessiz_gun+' gündür sessiz'} · Son: ${esc(s.son_aktivite||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
    const rows=_sessizGrupla(list).map(g=>`<div style="font-size:.68rem;font-weight:800;color:var(--ink3);margin:12px 0 4px;letter-spacing:.02em">${esc(g.grup)} · ${g.items.length}</div>${g.items.map(row).join('')}`).join('');
    box.innerHTML=`<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:75vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))"><div style="font-weight:800;font-size:.95rem;margin-bottom:4px">❗ Sessiz Hayvanlar (${list.length})</div><div style="font-size:.75rem;color:var(--ink3);margin-bottom:14px">55+ gündür kızgınlık/tohumlama kaydı yok</div>${rows}</div>`;
    if(!existedBefore) history.pushState({sessiz_bs:1}, '', '');
    document.body.appendChild(box);
  }catch(e){toast('Hata: '+e.message);}
}
let _belirsizData=[];
let _belirsizSel=new Set();
async function _showBelirsizList(){
  try{
    const list=await rpc('hayvan_belirsiz_ureme_listele',{});
    if(!list||!list.length){toast('Belirsiz hayvan yok');return;}
    _belirsizData=list;
    _belirsizSel=new Set();
    let box=document.getElementById('belirsiz-bs');
    if(box) box.remove();
    box=document.createElement('div');
    box.id='belirsiz-bs';
    box.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
    box.onclick=e=>{if(e.target===box)box.remove();};
    document.body.appendChild(box);
    _belirsizRender();
  }catch(e){toast('Hata: '+e.message);}
}
function _belirsizRender(){
  const box=document.getElementById('belirsiz-bs'); if(!box) return;
  const prevScroll=document.getElementById('belirsiz-scroll')?.scrollTop||0;
  const list=_belirsizData, sel=_belirsizSel;
  const rows=list.map(s=>{
    const on=sel.has(s.hayvan_id);
    const hint=s.dogum_sayisi>=1?'<span style="color:var(--green2,#2e7d32)">🐮 genç anne adayı</span>':'<span style="color:var(--blue)">🐄 olgun inek adayı</span>';
    const chk=`<div style="width:22px;height:22px;border-radius:6px;border:2px solid ${on?'var(--green2,#2e7d32)':'var(--ink2)'};background:${on?'var(--green2,#2e7d32)':'transparent'};display:flex;align-items:center;justify-content:center;flex-shrink:0">${on?'<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>':''}</div>`;
    return `<div class="arow" onclick="_belirsizToggle('${s.hayvan_id}')" style="${on?'background:rgba(46,125,50,.10);':''}">${chk}<div style="flex:1;min-width:0"><div class="arow-id">${esc(s.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(s.grup||'')}</span></div><div class="arow-sub">${s.dogum_sayisi} doğum · ${s.tohumlama_sayisi} toh · ${hint}</div></div></div>`;
  }).join('');
  const n=sel.size;
  box.innerHTML=`<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:84vh;display:flex;flex-direction:column">
    <div style="padding:18px 16px 8px">
      <div style="font-weight:800;font-size:.95rem;margin-bottom:4px">⚠️ Belirsiz Üreme Statüsü (${list.length})</div>
      <div style="font-size:.72rem;color:var(--ink3);margin-bottom:10px">Seç → alttan toplu işaretle. İpucu: <b>1 doğum</b> = genç anne (Düve), <b>0 doğum</b> = olgun inek</div>
      <div style="display:flex;gap:6px;flex-wrap:wrap">
        <span onclick="event.stopPropagation();_belirsizSelPredik('all')" style="cursor:pointer;font-size:.68rem;font-weight:700;padding:4px 10px;border-radius:6px;border:1px solid var(--ink2);background:var(--ink1)">Tümü</span>
        <span onclick="event.stopPropagation();_belirsizSelPredik('dogum1')" style="cursor:pointer;font-size:.68rem;font-weight:700;padding:4px 10px;border-radius:6px;border:1px solid var(--green2,#2e7d32);color:var(--green2,#2e7d32)">🐮 1 doğumlular</span>
        <span onclick="event.stopPropagation();_belirsizSelPredik('dogum0')" style="cursor:pointer;font-size:.68rem;font-weight:700;padding:4px 10px;border-radius:6px;border:1px solid var(--blue);color:var(--blue)">🐄 0 doğumlular</span>
        <span onclick="event.stopPropagation();_belirsizSelPredik('none')" style="cursor:pointer;font-size:.68rem;font-weight:700;padding:4px 10px;border-radius:6px;border:1px solid var(--ink2)">Temizle</span>
      </div>
    </div>
    <div id="belirsiz-scroll" style="flex:1;overflow-y:auto">${rows}</div>
    <div style="padding:12px 16px;padding-bottom:calc(12px + env(safe-area-inset-bottom,0px));border-top:1px solid var(--card2);display:flex;gap:8px">
      <button onclick="_belirsizApply(true)" ${n?'':'disabled'} style="flex:1;padding:11px;border-radius:10px;border:none;font-weight:700;font-size:.8rem;cursor:${n?'pointer':'default'};background:${n?'var(--green2,#2e7d32)':'var(--ink1)'};color:${n?'#fff':'var(--ink3)'}">🐮 Genç Anne (${n})</button>
      <button onclick="_belirsizApply(false)" ${n?'':'disabled'} style="flex:1;padding:11px;border-radius:10px;border:none;font-weight:700;font-size:.8rem;cursor:${n?'pointer':'default'};background:${n?'var(--blue)':'var(--ink1)'};color:${n?'#fff':'var(--ink3)'}">🐄 Olgun İnek (${n})</button>
    </div>
  </div>`;
  const sc=document.getElementById('belirsiz-scroll');
  if(sc) sc.scrollTop=prevScroll;
}
function _belirsizToggle(id){ if(_belirsizSel.has(id))_belirsizSel.delete(id); else _belirsizSel.add(id); _belirsizRender(); }
function _belirsizSelPredik(mode){
  _belirsizSel=new Set();
  if(mode==='all') _belirsizData.forEach(s=>_belirsizSel.add(s.hayvan_id));
  else if(mode==='dogum1') _belirsizData.filter(s=>s.dogum_sayisi>=1).forEach(s=>_belirsizSel.add(s.hayvan_id));
  else if(mode==='dogum0') _belirsizData.filter(s=>s.dogum_sayisi===0).forEach(s=>_belirsizSel.add(s.hayvan_id));
  _belirsizRender();
}
async function _belirsizApply(val){
  const ids=[..._belirsizSel]; if(!ids.length) return;
  try{
    const r=await rpc('hayvan_genc_anne_isaretle_toplu',{p_ids:ids,p_genc_anne:val});
    toast(`✅ ${r.adet||ids.length} hayvan ${val?'Genç Anne (Düve)':'Olgun İnek'} işaretlendi`);
    await pullTables(['hayvanlar']).catch(()=>{});
    _suruStatCache={}; _renderSuruStat();
    const list=await rpc('hayvan_belirsiz_ureme_listele',{});
    if(!list||!list.length){ const b=document.getElementById('belirsiz-bs'); if(b)b.remove(); toast('Tüm belirsizler işaretlendi 🎉'); return; }
    _belirsizData=list; _belirsizSel=new Set(); _belirsizRender();
  }catch(e){toast('Hata: '+e.message,true);}
}
// ── Protokol sheet'leri tek noktadan kapat (B21) ──
// DOM remove + (state eşleşiyorsa) history.back. Back'in popstate'ı
// _modalBackGuard ile tüketilir → liste sheet'i ekranda kalır, dash'e atlanmaz.
function _closeProtokolListe(){
  const box = document.getElementById('protokol-bs');
  if (!box) return;
  box.remove();
  if (history.state?.protokol) { globalThis._modalBackGuard = true; history.back(); }
}
function _closeProtokolDetay(){
  const box = document.getElementById('proto-detay-bs');
  if (!box) return;
  box.remove();
  if (history.state?.proto_detay) { globalThis._modalBackGuard = true; history.back(); }
}

async function _showProtokolEkran(){
  let data = window.__protokolUyarilar;
  if (!data || !data.length) {
    try { data = await rpc('protokol_eksik_tara', {}); } catch(e) { toast('Hata: '+e.message, true); return; }
  }
  if (!data || !data.length) { toast('Protokol uyarısı yok'); return; }

  let box = document.getElementById('protokol-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'protokol-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) _closeProtokolListe(); };

  const eksik = data.filter(u => u.durum === 'eksik');
  const yaklasan = data.filter(u => u.durum === 'yaklasan');
  const tamamlandi = data.filter(u => u.durum === 'tamamlandi');

  const _renk = d => d.durum === 'eksik' ? 'var(--red2)' : d.durum === 'yaklasan' ? '#b8860b' : '#2e7d32';
  const _ikon = d => d.durum === 'eksik' ? '🔴' : d.durum === 'yaklasan' ? '🟡' : '✅';
  const _gun = d => d.durum === 'eksik' ? d.gecikme_gun + ' gün gecikmiş' : d.durum === 'yaklasan' ? Math.abs(d.gecikme_gun || 0) + ' gün kaldı' : '';

  const _satirHtml = (d, i) => `<div class="arow" data-p="${escAttr(d.protokol)}" style="border-left:3px solid ${_renk(d)};margin-bottom:6px;padding:8px 10px;cursor:pointer" onclick="_showProtokolDetay('${d.hayvan_id}',this.dataset.p,${i})">
    <div style="flex:1">
      <div style="font-weight:700;font-size:.8rem">${_ikon(d)} ${esc(d.kupe_no||'?')} <span style="font-size:.6rem;opacity:.6">${esc(d.grup||'')}</span></div>
      <div style="font-size:.7rem;color:var(--ink3)">${esc(d.adim)} · ${_gun(d)}</div>
      <div style="font-size:.6rem;opacity:.5">${esc(d.protokol)}</div>
    </div>
    <div style="display:flex;gap:6px;align-items:center" onclick="event.stopPropagation()">
      ${d.durum !== 'tamamlandi' && d.etken_kod ? `<button onclick="_protokolUygula(${i})" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--blue);background:rgba(30,100,200,.1);color:var(--blue);cursor:pointer">💉 Uygula</button>` : ''}
      ${d.durum !== 'tamamlandi' ? `<button onclick="_protokolDismiss(${i})" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>` : ''}
      ${d.durum === 'tamamlandi' && d.kapatan_ref ? `<button data-ref="${escAttr(d.kapatan_ref)}" onclick="_protokolGeriAl(this.dataset.ref)" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer">↩ Geri Al</button>` : ''}
    </div>
  </div>`;

  const eksikHtml = eksik.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:var(--red2)">🔴 Gecikmiş (${eksik.length})</div>${eksik.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';
  const yakHtml = yaklasan.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:#b8860b">🟡 Yaklaşan (${yaklasan.length})</div>${yaklasan.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';
  const tamHtml = tamamlandi.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:#2e7d32">✅ Son 24 Saat (${tamamlandi.length})</div>${tamamlandi.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';

  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:80vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:1rem;margin-bottom:4px">📋 Protokol Uyarıları</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">Doğum sonrası, ileri gebe, kızgınlık takibi</div>
    ${eksikHtml}${yakHtml}${tamHtml}
  </div>`;
  history.pushState({protokol:true}, '', '');
  document.body.appendChild(box);
}

function _showProtokolDetay(hayvanId, protokol, activeIdx){
  const data = window.__protokolUyarilar;
  if (!data) return;

  const items = data.filter(d => d.hayvan_id === hayvanId && d.protokol === protokol);
  if (!items.length) return;

  const d0 = items[0];
  // Sheet zaten açıksa (uygulama sonrası tazeleme) yeniden pushState YOK —
  // her tazelemede öksüz {proto_detay} girdisi birikiyordu (B21)
  const existedBefore = !!document.getElementById('proto-detay-bs');
  const _renk = d => d.durum === 'eksik' ? 'var(--red2)' : d.durum === 'yaklasan' ? '#b8860b' : '#2e7d32';
  const _ikon = d => d.durum === 'eksik' ? '🔴' : d.durum === 'yaklasan' ? '🟡' : '✅';

  let box = document.getElementById('proto-detay-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'proto-detay-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:350;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) _closeProtokolDetay(); };

  const _adimHtml = items.map((d, i) => {
    const globalIdx = data.indexOf(d);
    const tamamTarih = d.tamamlanma_tarihi ? fmtTarih(d.tamamlanma_tarihi) : '';
    const gecikme = d.durum === 'eksik' ? `<span style="color:var(--red2);font-weight:700">${d.gecikme_gun} gün gecikmiş</span>` :
                    d.durum === 'yaklasan' ? `<span style="color:#b8860b">${Math.abs(d.gecikme_gun||0)} gün kaldı</span>` :
                    `<span style="color:#2e7d32">${tamamTarih}</span>`;
    const butonlar = d.durum !== 'tamamlandi' && d.etken_kod
      ? `<button onclick="_protokolUygula(${globalIdx})" style="font-size:.6rem;font-weight:700;padding:3px 8px;border-radius:6px;border:1px solid var(--blue);background:rgba(30,100,200,.1);color:var(--blue);cursor:pointer">💉</button>
         <button onclick="_protokolDismiss(${globalIdx})" style="font-size:.6rem;padding:3px 6px;border-radius:6px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`
      : d.durum !== 'tamamlandi'
      ? `<button onclick="_protokolDismiss(${globalIdx})" style="font-size:.6rem;padding:3px 6px;border-radius:6px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`
      : d.kapatan_ref
      ? `<button data-ref="${escAttr(d.kapatan_ref)}" onclick="_protokolGeriAl(this.dataset.ref)" style="font-size:.6rem;padding:3px 8px;border-radius:6px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer">↩</button>`
      : '';

    return `<div style="display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:1px solid var(--card2)">
      <div style="font-size:1rem">${_ikon(d)}</div>
      <div style="flex:1">
        <div style="font-size:.78rem;font-weight:600">${esc(d.adim)}</div>
        <div style="font-size:.65rem;color:var(--ink3)">${fmtTarih(d.hedef_tarih)} · ${gecikme}</div>
      </div>
      <div style="display:flex;gap:4px">${butonlar}</div>
    </div>`;
  }).join('');

  const protokolLabel = protokol === 'DOGUM_PROTOKOL' ? 'Doğum Protokolü' :
                        protokol === 'ILERI_GEBE_PROTOKOL' ? 'İleri Gebe Protokolü' :
                        'Kızgınlık Takibi';

  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:75vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
      <div>
        <div style="font-weight:800;font-size:.95rem">
          <a href="javascript:void(0)" onclick="_protoDetayHayvanGit('${hayvanId}')" style="color:var(--blue);text-decoration:underline">${esc(d0.kupe_no||'?')}</a>
          <span style="font-size:.65rem;opacity:.6;margin-left:6px">${esc(d0.grup||'')}</span>
        </div>
        <div style="font-size:.72rem;color:var(--ink3);margin-top:2px">${protokolLabel}</div>
      </div>
      <button onclick="_closeProtokolDetay()" style="background:none;border:none;font-size:1.2rem;cursor:pointer;color:var(--ink3)">✕</button>
    </div>
    ${_adimHtml}
  </div>`;

  if (!existedBefore) history.pushState({proto_detay:true}, '', '');
  document.body.appendChild(box);
}

function _protoDetayHayvanGit(hayvanId){
  const detayBs = document.getElementById('proto-detay-bs');
  if (detayBs) detayBs.style.display = 'none';
  const protokolBs = document.getElementById('protokol-bs');
  if (protokolBs) protokolBs.style.display = 'none';
  openDet(hayvanId);
}

// §2: drug_class bazlı etken filtreleme (aktif ingredient üzerinden)
const _ETKEN_INGREDIENT = {
  'OKSITOSIN': /oxytocin|oksitosin/i,
  'PG':        /dinoprost|cloprostenol|prostaglandin/i,
  'E_VIT':     /e vitamini|vitamin e|tocopherol/i,
  'ADEMIN':    /ademin|ade\b/i,
  'KALSIYUM':  /kalsiyum|calcium/i,
  'ROTA':      /rota|corona|e\.?\s*coli/i,
  'ROTA_2DOZ': /rota|corona|e\.?\s*coli/i,  // N3: aynı aşı (2. doz etiketi)
};

// Legacy regex fallback (drug_product_id olmayan eski stoklar için)
const _ETKEN_FILTERE_LEGACY = {
  'OKSITOSIN': s => /oksitosin/i.test(s.urun_adi),
  'PG':        s => /pg\b|pgf|cloprostenol|dalmazin/i.test(s.urun_adi),
  'E_VIT':     s => /e[ .-]?vit|yeldif|carofertin/i.test(s.urun_adi),
  'ADEMIN':    s => /ademin/i.test(s.urun_adi),
  'KALSIYUM':  s => /kalsiyum/i.test(s.urun_adi),
  'ROTA':      s => /rota|corona|e\.?\s*coli/i.test(s.urun_adi),
  'ROTA_2DOZ': s => /rota|corona|e\.?\s*coli/i.test(s.urun_adi),  // N3
};

async function _etkenFiltrele(etkenKod, stoklar) {
  const rx = _ETKEN_INGREDIENT[etkenKod];
  if (!rx) return [];
  const dcMap = {};  // drug_class_id → active_ingredient
  try { (await idbGetAll('drug_classes')).forEach(dc => { dcMap[dc.id] = dc.active_ingredient||''; }); } catch(e) {}
  const dpMap = {};  // drug_product_id → drug_class_id
  try { (await idbGetAll('drug_products')).forEach(dp => { dpMap[dp.id] = dp.drug_class_id; }); } catch(e) {}

  return stoklar.filter(s => {
    if (!s.kategori || ['Yem','Sperma'].includes(s.kategori)) return false;
    if (s.drug_product_id) {
      const classId = dpMap[s.drug_product_id];
      const activeIng = classId ? (dcMap[classId] || '') : '';
      if (activeIng && rx.test(activeIng)) return true;
    }
    // Fallback: urun_adi (drug_product_id olmayan eski stoklar)
    const oldFn = _ETKEN_FILTERE_LEGACY[etkenKod];
    return oldFn ? oldFn(s) : false;
  });
}

async function _sonDozGetir(stokId) {
  try {
    // hizli_uygulama → uygulama_log'a yazıyor (drug_administrations değil)
    const logs = await idbGetAll('uygulama_log');
    const match = logs
      .filter(a => a.stok_id === stokId)
      .sort((a, b) => (b.created_at || b.tarih || '').localeCompare(a.created_at || a.tarih || ''));
    if (match.length) return { doz: match[0].doz, birim: match[0].birim || 'ml' };
  } catch(e) {}
  return null;
}

function _puDozPrefill(stokId) {
  _sonDozGetir(stokId).then(d => {
    if (!d) return;
    const dozEl = document.getElementById('pu-doz');
    const birimEl = document.getElementById('pu-birim');
    if (dozEl && d.doz) dozEl.value = d.doz;
    if (birimEl && d.birim) birimEl.value = d.birim;
  });
}

async function _protokolUygula(idx){
  const d = window.__protokolUyarilar[idx];
  if (!d) return;
  const stoklar = await idbGetAll('stok');
  const ilaclar = d.etken_kod ? await _etkenFiltrele(d.etken_kod, stoklar) : [];

  if (!ilaclar.length) {
    toast(`"${d.etken_kod || 'Bu protokol'}" için uygun stok bulunamadı. Lütfen stok girişi yapın.`, true);
    return;
  }

  let mini = document.getElementById('proto-mini');
  if (mini) mini.remove();
  mini = document.createElement('div');
  mini.id = 'proto-mini';
  mini.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:400;display:flex;align-items:flex-end';
  mini.onclick = e => { if (e.target === mini) mini.remove(); };

  const stokOpts = ilaclar.map(s => `<option value="${s.id}" data-birim="${esc(s.birim||'ml')}">${esc(s.urun_adi)}</option>`).join('');
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin'].map(r => `<option value="${r}">${r}</option>`).join('');
  const ilkBirim = ilaclar[0]?.birim || 'ml';

  mini.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:4px">💉 Protokol Uygula</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">${esc(d.kupe_no||'?')} · ${esc(d.adim)}</div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Stok</label>
    <select id="pu-stok" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${stokOpts}</select>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:2"><label style="font-size:.7rem;font-weight:600">Doz</label><input id="pu-doz" type="number" step="0.1" min="0.1" value="1" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Birim</label><input id="pu-birim" value="${ilkBirim}" readonly style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem;background:var(--card2);color:var(--ink3)"></div>
    </div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Uygulama Yolu</label>
    <select id="pu-rota" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:12px;font-size:.8rem">${rotaOpts}</select>
    <button onclick="_protokolUygulaKaydet('${d.hayvan_id}',${idx})" class="btn" style="width:100%;padding:10px;font-weight:700">Kaydet</button>
  </div>`;
  document.body.appendChild(mini);
  _puDozPrefill(ilaclar[0]?.id);
  document.getElementById('pu-stok')?.addEventListener('change', e => {
    _puDozPrefill(e.target.value);
    const opt = e.target.selectedOptions[0];
    const birimEl = document.getElementById('pu-birim');
    if (birimEl && opt?.dataset?.birim) birimEl.value = opt.dataset.birim;
  });
}

async function _protokolUygulaKaydet(hayvanId, idx){
  const stok = document.getElementById('pu-stok')?.value;
  const doz = parseFloat(document.getElementById('pu-doz')?.value);
  const birim = document.getElementById('pu-birim')?.value || 'ml';
  const rota = document.getElementById('pu-rota')?.value || 'IM';
  if (!stok) { toast('Stok seçilmedi', true); return; }
  if (!doz || isNaN(doz) || doz <= 0) { toast('Geçerli doz girin', true); return; }

  try {
    const res = await rpc('hizli_uygulama', {
      p_hayvan_id: hayvanId, p_stok_id: stok, p_doz: doz, p_birim: birim, p_rota: rota, p_notlar: ''
    });
    if (res?.ok) {
      toast('✅ Uygulama kaydedildi');
      document.getElementById('proto-mini')?.remove();
      await _islemSonrasiRefresh();
      // Detay sheet'i yerinde tazele — remove+pushState öksüz history bırakıyordu.
      // _showProtokolDetay kendi remove'unu yapar; existedBefore kontrolü
      // pushState'i atlar.
      if (document.getElementById('proto-detay-bs')) {
        const d = window.__protokolUyarilar[idx];
        if (d) _showProtokolDetay(d.hayvan_id, d.protokol, idx);
      }
    } else {
      toast(res?.mesaj || 'Hata', true);
    }
  } catch(e) { toast('Hata: '+e.message, true); }
}

async function _protokolDismiss(idx){
  const d = window.__protokolUyarilar[idx];
  if (!d) return;
  if (!confirm('Bu uyarıyı geçersiz kılmak istediğinize emin misiniz?')) return;

  try {
    const { error: insErr } = await db.from('protokol_dismiss').upsert({
      hayvan_id: d.hayvan_id,
      etken_kod: d.etken_kod || 'MANUAL',
      protokol: d.protokol,
      neden: 'Manuel dismiss'
    }, { onConflict: 'hayvan_id,etken_kod,protokol' });
    if (insErr) { toast('Hata: ' + (insErr.message || insErr.details || 'Dismiss başarısız'), true); return; }
    toast('Uyarı geçersiz kılındı');
    await _islemSonrasiRefresh();
    const detayBs = document.getElementById('proto-detay-bs');
    if (detayBs) {
      detayBs.remove();
      const d2 = window.__protokolUyarilar.find(x => x.hayvan_id === d.hayvan_id && x.protokol === d.protokol);
      if (d2) _showProtokolDetay(d2.hayvan_id, d2.protokol, window.__protokolUyarilar.indexOf(d2));
    }
  } catch(e) { toast('Hata: '+e.message, true); }
}

async function _protokolGeriAl(ref){
  if (!confirm('Bu işlemi geri almak istediğinize emin misiniz?')) return;

  const parts = ref.split(':');
  if (parts[0] === 'uygulama_log' && parts[1]) {
    try {
      const res = await rpc('hizli_uygulama_geri_al', { p_uygulama_id: parts[1] });
      if (res?.ok) {
        toast('İşlem geri alındı');
        await _islemSonrasiRefresh();
      } else {
        toast(res?.mesaj || 'Hata', true);
      }
    } catch(e) { toast('Hata: '+e.message, true); }
  } else {
    toast('Bu işlem geri alınamaz (farklı kaynak)', true);
  }
}

// §5: Ortak işlem sonrası yenileme — scanner + badge + açık ekranlar
async function _islemSonrasiRefresh(){
  try { await pullTables(['uygulama_log', 'stok_hareket']); } catch(e) {}
  try {
    const proto = await rpc('protokol_eksik_tara', {});
    window.__protokolUyarilar = Array.isArray(proto) ? proto : [];
  } catch(e) { console.warn('scanner refresh:', e.message); }

  // Badge güncelle
  try {
    const aktif = (window.__protokolUyarilar||[]).filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
    const bb = document.getElementById('bellbadge');
    if (bb) {
      bb.textContent = aktif.length > 99 ? '99+' : aktif.length;
      bb.style.display = aktif.length > 0 ? 'flex' : 'none';
    }
  } catch(e) {}

  // Görev badge güncelle
  try { updateTaskBadge(); } catch(e) {}

  // Protokol listesi açıksa yenile
  try {
    const protokolBs = document.getElementById('protokol-bs');
    if (protokolBs) { protokolBs.remove(); _showProtokolEkran(); }
  } catch(e) {}
}

async function _hayvanHizliUygulama(hayvanId){
  const stoklar = await idbGetAll('stok');
  const ilaclar = stoklar.filter(s => s.kategori && !['Yem','Sperma'].includes(s.kategori));
  if (!ilaclar.length) { toast('Stokta ilaç/vitamin bulunamadı', true); return; }

  let mini = document.getElementById('proto-mini');
  if (mini) mini.remove();
  mini = document.createElement('div');
  mini.id = 'proto-mini';
  mini.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:400;display:flex;align-items:flex-end';
  mini.onclick = e => { if (e.target === mini) mini.remove(); };

  const stokOpts = ilaclar.map(s => `<option value="${s.id}" data-birim="${esc(s.birim||'ml')}">${esc(s.urun_adi)}</option>`).join('');
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin'].map(r => `<option value="${r}">${r}</option>`).join('');
  const ilkBirim2 = ilaclar[0]?.birim || 'ml';
  const hayvanKupe = getState('animals')?.find(a=>a.id===hayvanId)?.kupe_no || hayvanId;

  mini.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:4px">💉 Hızlı Uygulama</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">${esc(hayvanKupe)} — case açmadan ilaç/vitamin kaydı</div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Stok</label>
    <select id="pu-stok" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${stokOpts}</select>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:2"><label style="font-size:.7rem;font-weight:600">Doz</label><input id="pu-doz" type="number" step="0.1" min="0.1" value="1" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Birim</label><input id="pu-birim" value="${ilkBirim2}" readonly style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem;background:var(--card2);color:var(--ink3)"></div>
    </div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Uygulama Yolu</label>
    <select id="pu-rota" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:12px;font-size:.8rem">${rotaOpts}</select>
    <button onclick="_hayvanHizliUygulaKaydet('${hayvanId}')" class="btn" style="width:100%;padding:10px;font-weight:700">Kaydet</button>
  </div>`;
  document.body.appendChild(mini);
  if (ilaclar[0]) _puDozPrefill(ilaclar[0].id);
  document.getElementById('pu-stok')?.addEventListener('change', e => {
    _puDozPrefill(e.target.value);
    const opt = e.target.selectedOptions[0];
    const birimEl = document.getElementById('pu-birim');
    if (birimEl && opt?.dataset?.birim) birimEl.value = opt.dataset.birim;
  });
}

async function _hayvanHizliUygulaKaydet(hayvanId){
  const stok = document.getElementById('pu-stok')?.value;
  const doz = parseFloat(document.getElementById('pu-doz')?.value);
  const birim = document.getElementById('pu-birim')?.value || 'ml';
  const rota = document.getElementById('pu-rota')?.value || 'IM';
  if (!stok) { toast('Stok seçilmedi', true); return; }
  if (!doz || isNaN(doz) || doz <= 0) { toast('Geçerli doz girin', true); return; }

  try {
    const res = await rpc('hizli_uygulama', {
      p_hayvan_id: hayvanId, p_stok_id: stok, p_doz: doz, p_birim: birim, p_rota: rota, p_notlar: ''
    });
    if (res?.ok) {
      toast('✅ Uygulama kaydedildi');
      document.getElementById('proto-mini')?.remove();
      _islemSonrasiRefresh();
      openDet(hayvanId, true);
    } else {
      toast(res?.mesaj || 'Hata', true);
    }
  } catch(e) { toast('Hata: '+e.message, true); }
}
let _suruStatMode='son';

// ═══ BUG-062 FIX: Grup filtre chipleri DB'den dinamik render ═══
// Sebep: HTML'de statik grup chipleri yoktu, dynamic render kayboluyordu.
// Bu fonksiyon her sürü sayfası açılışında DB'den distinct grup değerlerini çeker
// ve #fc-grup-strip placeholder'ına chip olarak basar. HTML refactor'da
// placeholder kaybolsa bile, fonksiyon DOM'a yeniden basar (regression-proof).
let _grupFiltreCache=null;
async function _renderSuruGrupFiltre(){
  const strip=document.getElementById('fc-grup-strip');
  if(!strip) return;
  // Cache: aynı session'da 1 kez çek
  if(_grupFiltreCache!==null){
    _applyGrupFiltreHtml(strip,_grupFiltreCache);
    return;
  }
  try {
    const{data,error}=await db.from('hayvanlar')
      .select('grup')
      .eq('durum','Aktif')
      .not('grup','is',null);
    if(error){ console.warn('grup filter load:',error.message); return; }
    const gruplar=[...new Set((data||[]).map(d=>d.grup))].filter(Boolean).sort((a,b)=>a.localeCompare(b,'tr'));
    _grupFiltreCache=gruplar;
    _applyGrupFiltreHtml(strip,gruplar);
  } catch(e){ console.warn('grup filter load:',e.message); }
}
function _applyGrupFiltreHtml(strip,gruplar){
  if(!gruplar.length){
    strip.innerHTML='';
    return;
  }
  // Aktif chip state'ini koru
  const aktifGrup=_fchip.grup;
  strip.innerHTML=gruplar.map(g=>{
    const gid='fc-grup-'+g.replace(/[^a-zA-Z0-9]/g,'-');
    const cls='fchip'+(aktifGrup===g?' on':'');
    return `<button class="${cls}" id="${gid}" data-action="fchip-grup" data-grup="${esc(g)}">${esc(g)}</button>`;
  }).join('');
}

function _renderSuruStat(){
  const el=document.getElementById('suru-stat-card'); if(!el) return;
  _renderSuruGrupFiltre();
  const padok=document.getElementById('pflt')?.value||'';
  const key=padok+'_'+_suruStatMode;
  if(_suruStatCache[key]){
    _applySuruStatHtml(el,_suruStatCache[key],padok);
    _fetchSuruStat(el,padok,key);
    return;
  }
  if(el.innerHTML) _showStatLoading(el,true);
  _fetchSuruStat(el,padok,key);
}

function _fetchSuruStat(el,padok,key){
  const params={p_son_donem:_suruStatMode==='son'};
  if(padok) params.p_padok=padok;
  db.rpc('stat_suru_ozet',params).then(({data})=>{
    if(data){
      _suruStatCache[key]=data;
      _applySuruStatHtml(el,data,padok);
    }
  }).catch(e=>console.warn('stat_suru_ozet:',e.message));
}

function _toggleStatMode(e){
  e.stopPropagation();
  _suruStatMode=_suruStatMode==='son'?'tum':'son';
  _renderSuruStat();
}

function _showStatLoading(el,show){
  const sp=el.querySelector('.stat-loading');
  if(show&&!sp){
    const h=el.querySelector('.stat-header');
    if(h){const s=document.createElement('span');s.className='stat-loading';h.appendChild(s);}
  } else if(!show&&sp){ sp.remove(); }
}

function _applySuruStatHtml(el,d,padok){
  const h=d.hayvan||{};
  const ho=(d.gebelik||{}).hayvan_ozet||{};
  const co=(d.gebelik||{}).cycle_ozet||{};
  const oran=ho.oran!=null?`%${ho.oran}`:'—';
  const padokLabel=padok?`🏠 ${esc(padok)} — `:'';

  const demoHtml=`<div class="stat-section">
    <div class="stat-section-title">📋 Demografik</div>
    <div class="stat-row">🐄 İnek: ${h.inek||0} · 🐮 Düve: ${h.duve||0} · 🐂 Erkek: ${h.erkek||0} · 🍼 Buzağı: ${h.buzagi||0} · 💲 Kısır: ${h.kisir||0}</div>
    <div class="stat-row">🔬 Tohumlanan: ${h.tohumlanan||0}/${h.toplam||0}</div>
  </div>`;

  const katHtml=(d.gebelik?.kategori||[]).map(k=>{
    const ico=k.ad==='İnek'?'🐄':k.ad==='Düve'?'🐮':'❓';
    return `${ico} ${esc(k.ad)}: %${k.hayvan_oran!=null?k.hayvan_oran:'—'} (${k.hayvan_gebe}/${k.hayvan_toplam})`;
  }).join(' · ')||'Veri yok';

  const gebHtml=`<div class="stat-section">
    <div class="stat-section-title">🤰 Gebelik (Hayvan)</div>
    <div class="stat-row">✅ ${ho.gebe||0}/${ho.toplam||0} gebe (${oran}) · ⭕ ${ho.bos||0} boş</div>${ho.devam_eden?`<div class="stat-row" style="color:var(--ink3);font-size:.7rem">⏳ ${ho.devam_eden} hayvan sonuç bekliyor (hesaba dahil değil)</div>`:''}
    <div class="stat-row">${katHtml}</div>
  </div>`;

  const uv=(d.gebelik||{}).ureme_verimlilik||{};
  const _uvBlock=(label,ico,g)=>{
    if(!g||!g.ham) return '';
    const hm=g.ham||{};
    const _p=v=>v!=null?`%${v}`:'—';
    return `<div class="stat-row" style="margin-top:2px"><b>${ico} ${label}</b></div>
      <div class="stat-row">① Gerçek CR: <b>${_p(hm.cr)}</b> <span style="color:var(--ink3);font-size:.7rem">(${hm.gebe||0}/${hm.tohumlama||0} tohumlama)</span></div>
      <div class="stat-row">② Hayvan ort: <b>${_p(g.hayvan_ort)}</b> <span style="color:var(--ink3);font-size:.7rem">(${g.hayvan_sayisi||0} hayvan)</span></div>
      <div class="stat-row">③ Cycle ort: <b>${_p(g.cycle_ort)}</b> <span style="color:var(--ink3);font-size:.7rem">(${g.cycle_sayisi||0} cycle · 1/deneme)</span></div>
      <div class="stat-row" style="color:var(--ink3);font-size:.7rem">⭕ ${hm.bos||0} boş${hm.bekliyor?` · ⏳ ${hm.bekliyor} bekliyor`:''}</div>`;
  };
  const verimHtml=`<div class="stat-section">
    <div class="stat-section-title">📈 Üreme Verimliliği</div>
    ${_uvBlock('İnek','🐄',uv.inek)||'<div class="stat-row" style="color:var(--ink3)">İnek verisi yok</div>'}
    ${_uvBlock('Düve','🐮',uv.duve)}
    <div class="stat-row" style="color:var(--ink3);font-size:.64rem;margin-top:3px">① tohumlama-başına gerçek oran · ② hayvan eşit ağırlık · ③ cycle eşit ağırlık</div>
  </div>`;

  const spAll=d.gebelik?.sperma_pi||[];
  const spFirst=spAll.slice(0,5);
  const spRest=spAll.slice(5);
  const _spRow=s=>`<div class="stat-row">${esc(s.ad)} — ${s.gebe}/${s.toplam} tohumlama → <b>%${s.oran!=null?s.oran:'—'}</b></div>`;
  const spFirstHtml=spFirst.map(_spRow).join('')||'<div class="stat-row" style="color:var(--ink3)">Yeterli veri yok</div>';
  const spRestHtml=spRest.map(_spRow).join('');
  const spRestBtn=spRest.length>0?`<div id="sperma-rest" style="display:${_suruSpermaOpen?'block':'none'}">${spRestHtml}</div><div class="stat-row"><span onclick="_toggleSpermaRest()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">${_suruSpermaOpen?'Daralt':'[+'+spRest.length+' daha]'}</span></div>`:'';
  const spSection=`<div class="stat-section"><div class="stat-section-title">🏆 Sperma Performansı (≥3 tohumlama)</div>${spFirstHtml}${spRestBtn}</div>`;

  const deneme=d.gebelik?.deneme||[];
  const first3=deneme.filter(dn=>dn.no<=3);
  const rest=deneme.filter(dn=>dn.no>3);
  const dnFirst=first3.map(dn=>
    `<div class="stat-row">${dn.no} denemede gebe: ${dn.gebe}/${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const dnRest=rest.map(dn=>
    `<div class="stat-row">${dn.no} denemede gebe: ${dn.gebe}/${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const restBtn=rest.length>0?`<div id="deneme-rest" style="display:${_suruDenemeOpen?'block':'none'}">${dnRest}</div><div class="stat-row"><span onclick="_toggleDenemeRest()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">${_suruDenemeOpen?'Daralt':'[+'+rest.length+' daha]'}</span></div>`:'';
  const dnSection=`<div class="stat-section"><div class="stat-section-title">🔢 Deneme Dağılımı</div>${dnFirst}${restBtn}</div>`;

  const sessizCount=h.sessiz||0;
  const sessizSection=sessizCount>0?`<div class="stat-section"><div class="stat-section-title">❗ Sessiz Hayvanlar (${sessizCount})</div><div class="stat-row" style="color:var(--ink3);font-size:.7rem">55+ gündür tohumlama/kızgınlık kaydı yok</div><div class="stat-row"><span onclick="_showSessizList()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">Listeyi gör →</span></div></div>`:'';
  const belirsizCount=h.belirsiz||0;
  const belirsizSection=belirsizCount>0?`<div class="stat-section"><div class="stat-section-title">⚠️ Belirsiz Üreme Statüsü (${belirsizCount})</div><div class="stat-row" style="color:var(--ink3);font-size:.7rem">Düve mi olgun inek mi belirsiz — incelenip işaretlenmeli</div><div class="stat-row"><span onclick="_showBelirsizList()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">Listeyi gör →</span></div></div>`:'';

  el.innerHTML=`<div class="stat-card${_suruStatOpen?' open':''}" onclick="_toggleSuruStat(event)">
    <div class="stat-header"><span>${padokLabel}🐄 ${h.toplam||0} hayvan · 🔬 ${h.tohumlanan||0} tohumlanan · 🤰 ${ho.gebe||0} gebe (${oran})</span><span class="stat-arrow">▼</span></div>
    <div class="stat-detail"><div style="display:flex;justify-content:flex-end;margin-bottom:4px"><span onclick="_toggleStatMode(event)" style="cursor:pointer;font-size:.68rem;font-weight:600;padding:2px 8px;border-radius:4px;background:var(--ink1);color:var(--ink4)">${_suruStatMode==='son'?'Son Dönem':'Tüm Zamanlar'} ↻</span></div>${demoHtml}${gebHtml}${verimHtml}${spSection}${sessizSection}${belirsizSection}${dnSection}</div>
  </div>`;
}

function _toggleSuruStat(e){
  if(e.target.closest('#deneme-rest')||e.target.onclick) return;
  _suruStatOpen=!_suruStatOpen;
  const c=document.querySelector('#suru-stat-card .stat-card');
  if(c) c.classList.toggle('open',_suruStatOpen);
}

function _toggleDenemeRest(){
  _suruDenemeOpen=!_suruDenemeOpen;
  const rest=document.getElementById('deneme-rest');
  if(rest) rest.style.display=_suruDenemeOpen?'block':'none';
  const padok=document.getElementById('pflt')?.value||'';
  const data=_suruStatCache[padok+'_'+_suruStatMode];
  if(data){
    const el=document.getElementById('suru-stat-card');
    if(el) _applySuruStatHtml(el,data,padok);
  }
}
let _filterTimer=null;
function srchDropdown(){
  const q=trLower(document.getElementById('srch')?.value||'').trim();
  const ac=document.getElementById('ac-srch');
  if(!ac) return;
  if(!q){ ac.style.display='none'; return; }
  const gebeSet=new Set(getState('gebeIds')||[]);
  const matches=srchAdaySirala(getState('animals'), q);
  if(!matches.length){ ac.style.display='none'; return; }
  ac.innerHTML=matches.map(({h:a,tier})=>{
    const main=a.kupe_no||a.devlet_kupe||a.id;
    // Irktan eşleşen satırda main eşleşme içermez (olsa tier≤5 olurdu) — vurgu yanıltır
    const mainHtml=tier===6?esc(main):vurguHtml(main,q);
    let sub=a.kupe_no&&a.devlet_kupe?` · <span style="color:var(--ink3)">${vurguHtml(a.devlet_kupe,q)}</span>`:'';
    // Irktan eşleşen satırda neden listelendiği görünmez — ırkı vurgulu göster
    if(tier===6&&a.irk) sub+=' · <span style="color:var(--ink3)">'+vurguHtml(a.irk,q)+'</span>';
    const isGebe=gebeSet.has(a.id);
    const badge=isGebe?'<span style="background:rgba(78,154,42,.15);color:var(--green);border-radius:5px;padding:1px 5px;font-size:.62rem;font-weight:700;margin-left:4px">🤰</span>':'';
    return `<div data-sid="${escAttr(a.id)}" data-main="${escAttr(main)}" onclick="srchSec(this.dataset.sid,this.dataset.main)" style="padding:9px 12px;cursor:pointer;border-bottom:1px solid var(--card3);display:flex;justify-content:space-between;align-items:center;gap:8px">
      <div style="min-width:0"><span style="font-weight:700;font-size:.85rem">${mainHtml}</span>${sub}${badge}</div>
      <span style="font-size:.68rem;color:var(--ink3);flex-shrink:0">${esc(a.padok||'')}</span>
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
let _fchip={cinsiyet:'hepsi',gebelik:null,saglik:null,kisir:null,tekrar:null,grup:null,dogum:null};
let _detOpenId=null;
// 🏥 Hasta tag'ine bağlı dinamik hastalık filtresi (T2):
// seçenekler aktif vakalardan (cases status='active' + diseases) türetilir,
// kontrol yalnız hasta tag aktifken görünür.
let _hastaHastalikSecim=new Set();  // seçili disease_id'ler — tag kapat/aç'ta korunur (arama metni gibi), sayfa değişiminde fchipReset temizler
let _hastaHastalikAcik=false;       // dropdown paneli açık mı
let _hastaHastalikSig=null;         // seçenek imzası — değişmediyse DOM yeniden kurulmaz
function fchipReset(){
  _fchip={cinsiyet:'hepsi',gebelik:null,saglik:null,kisir:null,tekrar:null,grup:null,dogum:null};
  _hastaHastalikSecim=new Set(); _hastaHastalikAcik=false; _hastaHastalikSig=null;
  document.querySelectorAll('[id^="fc-"]').forEach(b=>b.classList.remove('on'));
  document.getElementById('fc-cinsiyet-hepsi')?.classList.add('on');
}
function fchipSec(grup,deger,btn){
  if(_fchip[grup]===deger){ _fchip[grup]=null; btn.classList.remove('on'); }
  else {
    document.querySelectorAll(`[id^="fc-${grup}-"]`).forEach(b=>b.classList.remove('on'));
    _fchip[grup]=deger; btn.classList.add('on');
  }
  filterA();
}

// ── Hasta modu saf çekirdeği (unit test kapsamı) ──
// Aktif vakalardan hastalık seçenekleri: [{id,name,sayi}] — isme göre tr-alfabetik.
// Yalnız vakalarda gerçekten görünen hastalıklar çıkar (hastalar arasında metrit
// yoksa metrit seçeneği de çıkmaz).
function _hastaHastalikSecenekleri(vakalar,diseases){
  const dMap=new Map((diseases||[]).map(d=>[d.id,d?.name||'?']));
  const m=new Map();
  (vakalar||[]).forEach(v=>{
    if(!v||!v.disease_id) return;
    const cur=m.get(v.disease_id)||{id:v.disease_id,name:dMap.get(v.disease_id)||'?',sayi:0};
    cur.sayi+=1;
    m.set(v.disease_id,cur);
  });
  return [...m.values()].sort((a,b)=>a.name.localeCompare(b.name,'tr'));
}
// hayvan_id → en yeni aktif vaka açılış tarihi (start_date yoksa created_at)
function _aktifVakaAcilisMap(vakalar){
  const m=new Map();
  (vakalar||[]).forEach(v=>{
    if(!v||!v.animal_id) return;
    const t=v.start_date||v.created_at||'';
    if(!t) return;
    const cur=m.get(v.animal_id);
    if(!cur||t>cur) m.set(v.animal_id,t);
  });
  return m;
}
// Hasta modu filtre+sıralama: seçim kümesi boşsa yalnız sıralar (en yeni açılan
// vaka üstte), doluysa seçili hastalıklardan en az biri olan hayvanlara indirger.
function _hastaModuUygula(list,vakalar,secim){
  let f=list;
  if(secim&&secim.size){
    const byHayvan=new Map();
    (vakalar||[]).forEach(v=>{
      if(!v||!v.animal_id||!v.disease_id) return;
      let s=byHayvan.get(v.animal_id);
      if(!s){ s=new Set(); byHayvan.set(v.animal_id,s); }
      s.add(v.disease_id);
    });
    f=f.filter(a=>{
      const ids=byHayvan.get(a.id);
      if(!ids) return false;
      for(const d of secim) if(ids.has(d)) return true;
      return false;
    });
  }
  const acilis=_aktifVakaAcilisMap(vakalar);
  return [...f].sort((a,b)=>(acilis.get(b.id)||'').localeCompare(acilis.get(a.id)||''));
}

// ── Hasta hastalık filtresi UI (checkbox'lı dropdown; yalnız hasta tag aktifken) ──
function _hastaHastalikAcKapa(acik){
  _hastaHastalikAcik=acik;
  const p=document.getElementById('hh-drop-panel');
  if(p) p.style.display=acik?'block':'none';
}
function _hastaHastalikToggle(diseaseId,checked){
  if(checked) _hastaHastalikSecim.add(diseaseId); else _hastaHastalikSecim.delete(diseaseId);
  _hastaHastalikSig=null;   // buton etiketi (seçim sayısı) değişti → yeniden kur
  filterA();
}
function _hastaHastalikFiltreHtml(secenekler){
  const n=_hastaHastalikSecim.size;
  const satirlar=secenekler.map(s=>`
    <label style="display:flex;align-items:center;gap:8px;padding:7px 10px;font-size:.8rem;color:var(--ink);cursor:pointer;border-bottom:1px solid var(--card2)">
      <input type="checkbox" ${_hastaHastalikSecim.has(s.id)?'checked':''} data-hdid="${escAttr(s.id)}" onchange="_hastaHastalikToggle(this.dataset.hdid,this.checked)" style="width:17px;height:17px;accent-color:var(--red);flex-shrink:0;cursor:pointer">
      <span style="flex:1">${esc(s.name)}</span>
      <span style="color:var(--ink3);font-size:.72rem;font-weight:700">${s.sayi}</span>
    </label>`).join('');
  return `
    <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">
      <button class="fchip${n?' on':''}" id="hh-drop-btn" data-action="hasta-hastalik-drop">🦠 Hastalık${n?': '+n:''} ▾</button>
      ${n?`<button class="fchip" data-action="hasta-hastalik-temizle">✕ Temizle</button>`:''}
    </div>
    <div id="hh-drop-panel" style="display:${_hastaHastalikAcik?'block':'none'};background:var(--card);border:1px solid var(--card3);border-radius:10px;margin-top:4px;max-height:240px;overflow-y:auto;box-shadow:0 4px 14px rgba(0,0,0,.12)">${satirlar}</div>`;
}
function _hastaHastalikFiltreGuncelle(){
  const box=document.getElementById('hasta-hastalik-filtre');
  if(!box) return;
  if(_fchip.saglik!=='hasta'){ box.style.display='none'; box.innerHTML=''; _hastaHastalikSig=null; _hastaHastalikAcik=false; return; }
  const secenekler=_hastaHastalikSecenekleri(getState('aktifVakalar'),getState('diseases'));
  if(!secenekler.length){ box.style.display='none'; box.innerHTML=''; _hastaHastalikSig=null; return; } // filtrelenecek hastalık yok → kontrolü hiç gösterme
  const sig=secenekler.map(s=>s.id+'|'+s.sayi).join(';');
  if(sig!==_hastaHastalikSig){
    _hastaHastalikSig=sig;
    box.innerHTML=_hastaHastalikFiltreHtml(secenekler);
  }
  box.style.display='block';
}
// Panel dışına tıklayınca dropdown kapansın (srch autocomplete ile aynı desen)
document.addEventListener('click',e=>{
  if(_hastaHastalikAcik&&e.target&&typeof e.target.closest==='function'&&!e.target.closest('#hasta-hastalik-filtre'))
    _hastaHastalikAcKapa(false);
});
function filterA(){
  _hastaHastalikFiltreGuncelle();   // kontrol görünürlüğü — debounce beklemeden
  clearTimeout(_filterTimer);
  _filterTimer=setTimeout(()=>{
    const q=trLower(document.getElementById('srch')?.value||'');
    const p=document.getElementById('pflt')?.value||'';
    const gebeSet=new Set(getState('gebeIds')||[]);
    let f=getState('animals');
    if(q) f=f.filter(a=>trLower(a.id+(a.kupe_no||'')+(a.devlet_kupe||'')+(a.irk||'')).includes(q));
    if(p) {
      f=f.filter(a=>a.padok===p);
      if(p==='Buzağı Padok (Süt İçenler)'){
        f=f.filter(a=>{
          if(!a.dogum_tarihi) return true;
          return Math.floor((Date.now()-new Date(a.dogum_tarihi))/86400000)<=180;
        });
      }
    }
    if(_fchip.cinsiyet==='disi') f=f.filter(a=>a.cinsiyet==='Dişi'||!a.cinsiyet);
    else if(_fchip.cinsiyet==='erkek') f=f.filter(a=>a.cinsiyet==='Erkek');
    if(_fchip.gebelik==='gebe') f=f.filter(a=>gebeSet.has(a.id));
    else if(_fchip.gebelik==='bos') f=f.filter(a=>{
      if(gebeSet.has(a.id)) return false;
      if(a.cinsiyet==='Erkek') return false;
      if(a.kisir) return false;
      if(a.dogum_tarihi) return (Date.now()-new Date(a.dogum_tarihi).getTime())>=365*86400000;
      // dogum_tarihi yoksa yetiskin grubunda mi kontrol et
      return ['Sağmal (Laktasyonda)','Sağmal (Kuru)','Gebe İnek','Gebe Düve','Düve (Büyük)'].includes(a.grup);
    });
    if(_fchip.saglik==='hasta'){
      f=f.filter(a=>getState('hastaIds').has(a.id));
      f=_hastaModuUygula(f,getState('aktifVakalar'),_hastaHastalikSecim);
    }
    if(_fchip.kisir==='kisir') f=f.filter(a=>a.kisir);
    if(_fchip.grup) f=f.filter(a=>a.grup===_fchip.grup);
    if(_fchip.dogum==='dogurdu') f=f.filter(a=>_yeniDogumGun(a)!=null);
    if(_fchip.tekrar==='tekrar') {
      f=f.filter(a=>a.repeat_breed_active||a.repeat_breed_past);
      f.sort((a,b)=>{
        if(a.repeat_breed_active!==b.repeat_breed_active) return a.repeat_breed_active?-1:1;
        if(a.repeat_breed_past!==b.repeat_breed_past) return a.repeat_breed_past?-1:1;
        return (b.repeat_breed_count||0)-(a.repeat_breed_count||0);
      });
    }
    renderAnimals(f,_fchip.saglik==='hasta'?{verilenSira:true}:undefined);
    _renderSuruStat();
  },250);
}

// ──────────────────────────────────────────
// HAYVAN DETAY — helpers
// ──────────────────────────────────────────
function _detOzetHtml(a,births,diseases,tasks,subs,yavrular,yasRaw,yasGun,displayId){
  const infoFields=[{l:'Devlet Küpe',v:a.devlet_kupe||'—'},{l:'İşletme Küpe',v:a.kupe_no||'—'},{l:'Irk',v:a.irk||'—'},{l:'Cinsiyet',v:a.cinsiyet||'—'},{l:'Grup',v:a.grup||'—'},{l:'Padok',v:a.padok||'—'},{l:'Doğum',v:fmtTarih(a.dogum_tarihi)||'—'},{l:'Doğum Kg',v:a.dogum_kg?a.dogum_kg+' kg':'—'},{l:'Canlı Ağırlık',v:a.canli_agirlik?a.canli_agirlik+' kg':'—'},{l:'Boy',v:a.boy?a.boy+' cm':'—'},{l:'Renk',v:a.renk||'—'},{l:'Ayırt Edici',v:a.ayirici_ozellik||'—'},{l:'Durum',v:a.durum||'—'},{l:'Baba (Sperma)',v:a.baba_bilgi||'—'}];
  const anneObj=a.anne_id?getState('animals').find(x=>x.id===a.anne_id):null;
  const anneKupe=anneObj?.kupe_no||anneObj?.devlet_kupe||a.anne_id;
  let extra='';
  if(anneKupe) extra+=`<div style="background:var(--card2);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem">
    <span style="color:var(--ink3)">Anne: </span>
    <span onclick="openDet('${a.anne_id}')" style="font-weight:700;color:var(--blue);cursor:pointer">📌 ${esc(anneKupe)}</span>
  </div>`;
  const kardesler=_kardeslerBul(getState('animals'),a);
  if(kardesler.length) extra+=`<div data-kardes-row style="background:rgba(78,154,42,.08);border:1px solid rgba(78,154,42,.35);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem;display:flex;align-items:center;gap:6px;flex-wrap:wrap">
    <span style="color:var(--ink3)">Kardeş${kardesler.length>1?'ler':''} ${kardesler.length===1?'(ikiz)':'('+(kardesler.length+1)+'\'lü)'}: </span>
    ${kardesler.map(k=>`<span onclick="openDet('${k.id}')" style="background:rgba(78,154,42,.12);border:1px solid rgba(78,154,42,.4);border-radius:7px;padding:3px 8px;font-size:.78rem;font-weight:700;cursor:pointer;color:var(--green3)">🐄 ${esc(k.kupe_no||k.devlet_kupe||k.id)}</span>`).join(' ')}
    <span onclick="this.closest('[data-kardes-row]').remove()" title="Satırı kapat" style="margin-left:auto;color:var(--ink3);cursor:pointer;padding:0 4px">✕</span>
  </div>`;
  if(yavrular.length) extra+=`<div style="background:var(--card2);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem">
    <div style="color:var(--ink3);margin-bottom:4px">Yavrular (${yavrular.length}):</div>
    <div style="display:flex;flex-wrap:wrap;gap:5px">${yavrular.map(y=>`<span onclick="openDet('${y.id}')" style="background:var(--card);border:1px solid var(--card3);border-radius:7px;padding:3px 8px;font-size:.75rem;font-weight:700;cursor:pointer;color:var(--ink)">🐄 ${esc(y.kupe_no||y.devlet_kupe||y.id)}</span>`).join('')}</div>
  </div>`;
  const _ikizDog=_ikinciYavruDogumu(births,bugun(),10);
  if(_ikizDog) extra+=`<button class="btn" data-action="ikinci-yavru-ekle" data-hid="${a.id}" data-kupe="${escAttr(a.kupe_no||a.devlet_kupe||a.id)}" data-dt="${_ikizDog.tarih}" data-sperma="${escAttr(_ikizDog.baba_bilgi||'')}" style="margin-bottom:8px;padding:8px 10px;font-size:.78rem;background:rgba(78,154,42,.12);color:var(--green3);border:1px solid rgba(78,154,42,.45);font-weight:700">➕ Bu doğuma yavru ekle</button>`;
  if(a.notlar) extra+=`<div style="background:var(--card2);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem">
    <div style="color:var(--ink3);margin-bottom:4px">📝 Notlar:</div>
    <div style="color:var(--ink)">${esc(a.notlar)}</div>
  </div>`;
  return `
    <div class="stats-strip">
      <div class="ss-item"><div class="ss-val" style="font-size:${yasRaw!==null&&(yasRaw<0||yasRaw>36500)?'0.75rem':'1.15rem'}">${yasGun}</div><div class="ss-lbl">Yaş</div></div>
      <div class="ss-item"><div class="ss-val">${births.length}</div><div class="ss-lbl">Laktasyon</div></div>
      <div class="ss-item"><div class="ss-val">${diseases.length}</div><div class="ss-lbl">Toplam Vaka</div></div>
      <div class="ss-item"><div class="ss-val">${tasks.length+subs.length}</div><div class="ss-lbl">Bekl. Görev</div></div>
    </div>
    <div class="info-grid">
      ${infoFields.map(i=>`<div class="ig-item"><div class="ig-lbl">${i.l}</div><div class="ig-val">${esc(i.v)}</div></div>`).join('')}
    </div>
    ${extra}
    ${(!a.suttten_kesme_tarihi && a.grup && a.grup.includes('Buzağı')) ? `<button class="btn" data-action="sutten-kes-tekil" data-hid="${a.id}" style="margin-top:4px;padding:9px;background:rgba(78,154,42,.12);color:var(--green3);border:1px solid rgba(78,154,42,.35);font-weight:700">🍼 Sütten Kes</button>` : ''}
    ${(() => {
      if (!a.suttten_kesme_tarihi || !a.grup || !a.grup.includes('Buzağı')) return '';
      const _kg = Math.floor((Date.now() - new Date(a.suttten_kesme_tarihi)) / 86400000);
      if (_kg > 15) return '';                                  // kesimden >15 gün → gizle
      if (yasRaw !== null && yasRaw > 180) return '';           // 6 aydan büyük → gizle
      if (globalThis._sonTohMap && globalThis._sonTohMap[a.id]) return ''; // tohumlama kaydı → gizle
      return `<button class="btn" data-action="sutten-kes-geri-al" data-hid="${a.id}" style="margin-top:4px;padding:9px;background:rgba(192,50,26,.08);color:var(--red);border:1px solid rgba(192,50,26,.2);font-weight:700">↩️ Sütten Kesmeyi Geri Al</button>`;
    })()}
    <button class="btn btn-g" style="margin-top:4px;padding:9px" onclick="openAnimalEdit('${a.id}')">✏️ Bilgileri Düzenle</button>
    <button class="btn btn-o" style="margin-top:6px;padding:9px" onclick="openNotModal('${a.id}','${displayId}')">📝 Not Ekle</button>
    <button class="btn btn-o" style="margin-top:6px;padding:9px" onclick="_hayvanHizliUygulama('${a.id}')">💉 Hızlı Uygulama</button>
    <button class="btn" style="margin-top:6px;padding:9px;background:rgba(192,50,26,.08);color:var(--red);border:1px solid rgba(192,50,26,.2)" onclick="openCikisModal('${a.id}','${displayId}')">🚪 Çıkış Yap</button>`;
}
function _detUremeHtml(a,tohs,kizgs){
  const gebeTohumlama=tohs.find(t=>t.sonuc==='Gebe');
  const gebeBilgi=gebeTohumlama?(()=>{
    const toh=new Date(gebeTohumlama.tarih);
    const gunler=Math.floor((Date.now()-toh)/86400000);
    const ay=Math.floor(gunler/30), kalanGun=gunler%30;
    return `${ay} ay ${kalanGun} gün (${gunler}. gün) · Tahmini: ${dFwd(gebeTohumlama.tarih,280)}`;
  })():null;
  const bekleyenToh=tohs.find(t=>t.sonuc==='Bekliyor');
  const dogumYaptiToh=tohs.find(t=>t.sonuc==='Doğum Yaptı');
  const hid=a.kupe_no||a.devlet_kupe||a.id;
  let h=`<div style="padding:10px 0 6px;display:flex;gap:6px;flex-wrap:wrap">`;
  if(gebeTohumlama){
    h+=`<button class="btn" style="flex:1;padding:9px;background:rgba(192,50,26,.1);color:var(--red);font-weight:700" onclick="abortKaydet('${a.id}','${gebeTohumlama.id}')">⚠️ Abort / Erken Doğum</button>`;
    h+=`<button class="btn btn-g" style="flex:1;padding:9px;font-weight:700" data-hid="${escAttr(hid)}" data-sperma="${escAttr(gebeTohumlama.sperma||'')}" onclick="dogumYaptiAc('${a.id}',this.dataset.hid,'${gebeTohumlama.tarih}',this.dataset.sperma)">🐄 Doğum Yaptı</button>`;
  } else if(bekleyenToh){
    const _tohGun=Math.floor((Date.now()-new Date(bekleyenToh.tarih))/86400000);
    h+=`<button class="btn btn-g" style="flex:1;padding:9px" data-hid="${escAttr(hid)}" onclick="openInsemSafe(this.dataset.hid)">💉 Tohumlama Ekle</button>`;
    if(_tohGun>=0&&_tohGun<=15){
      h+=`<button class="btn" style="flex:1;padding:9px;font-weight:700;background:var(--purple);color:#fff;border:none" data-hid="${escAttr(hid)}" onclick="openTekrarAsim('${a.id}',this.dataset.hid)">🔁 Tekrar Aşım</button>`;
    }
  } else if(dogumYaptiToh){
    h+=`<button class="btn btn-g" style="flex:1;padding:9px" data-hid="${escAttr(hid)}" onclick="openInsemSafe(this.dataset.hid)">💉 Yeni Tohumlama Ekle</button>`;
  } else {
    h+=`<button class="btn btn-g" style="flex:1;padding:9px" data-hid="${escAttr(hid)}" onclick="openInsemSafe(this.dataset.hid)">💉 Tohumlama Ekle</button>`;
  }
  h+='</div>';
  if(gebeBilgi) h+=`<div style="background:rgba(78,154,42,.08);border:1px solid rgba(78,154,42,.2);border-radius:10px;padding:10px 12px;margin-bottom:8px;font-size:.8rem;color:var(--ink2)"><b style="color:var(--green)">🤰 Gebe</b> — ${gebeBilgi}</div>`;
  h+=(tohs.length
    ?tohs.map(t=>{
      const _ab=t.sonuc==='Abort';
      const _dot=t.sonuc==='Gebe'?'var(--green2)':_ab?'var(--red)':t.sonuc==='Boş'?'var(--red2)':'var(--amber)';
      const _sonucHtml=_ab
        ? `<b style="color:var(--red)">⚠️ Abort</b>${t.abort_notlar?` · <span style="color:var(--ink3)">${esc(t.abort_notlar)}</span>`:''}`
        : `<b>${esc(t.sonuc||'Bekliyor')}</b>`;
      return `<div class="hist-row" onclick="openTohDet('${t.id}')" style="cursor:pointer"><div class="hist-dot" style="background:${_dot}"></div><div class="hist-main"><div class="hist-title"${_ab?' style="color:var(--red)"':''}>${esc(t.sperma||'—')} <span style="background:var(--amber);color:#fff;font-size:.65rem;padding:1px 5px;border-radius:8px;font-weight:700">${t.deneme_no||1}. Deneme</span></div><div class="hist-sub">${esc(t.tarih||'')} · ${_sonucHtml}</div></div></div>`;
    }).join('')
    :'<div class="empty"><div class="empty-ico">💉</div>Tohumlama kaydı yok</div>');
  if(kizgs&&kizgs.length){
    h+='<div style="margin-top:14px;padding-top:10px;border-top:1px solid var(--border)"><div style="font-size:.72rem;font-weight:600;color:var(--ink3);text-transform:uppercase;letter-spacing:.04em;margin-bottom:6px">Kızgınlık Geçmişi</div>';
    h+=kizgs.map(k=>`<div class="hist-row"><div class="hist-dot" style="background:var(--red2)"></div><div class="hist-main"><div class="hist-title">${esc(k.belirti||'Kızgınlık')}</div><div class="hist-sub">${esc((k.tarih||k.created_at||'').slice(0,10))}</div></div></div>`).join('');
    h+='</div>';
  }
  return h;
}
async function _detRenderGecmis(id,el){
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const entries=[];

    // tohumlama
    (await idbGetAll('tohumlama').catch(()=>[])).filter(r=>r.hayvan_id===id).forEach(r=>{
      const sk=r.created_at||r.tarih||'';
      entries.push({type:'tohumlama',date:sk,sortKey:sk,data:r});
    });

    // dogum (anne)
    (await idbGetAll('dogum').catch(()=>[])).filter(r=>r.anne_id===id).forEach(r=>{
      const sk=r.created_at||r.tarih||'';
      entries.push({type:'dogum',date:sk,sortKey:sk,data:r});
    });

    // hastalik (cases)
    {
      const _dis=await idbGetAll('diseases').catch(()=>[]);
      const _hStok=await idbGetAll('stok').catch(()=>[]);
      const _hStokById=Object.fromEntries(_hStok.map(s=>[s.id,s.urun_adi||'']));
      const _hProdById=Object.fromEntries((await idbGetAll('drug_products').catch(()=>[])).map(p=>[p.id,p.brand_name||'']));
      const _hTdays=await idbGetAll('treatment_days').catch(()=>[]);
      const _hDadm=await idbGetAll('drug_administrations').catch(()=>[]);
      const _hDrugsByCase={};
      const _hDayCase=Object.fromEntries(_hTdays.map(td=>[td.id,td.case_id]));
      _hDadm.forEach(da=>{const cid=_hDayCase[da.treatment_day_id];if(!cid)return;const name=_hProdById[da.drug_product_id]||_hStokById[da.stok_id]||'';if(!name)return;if(!_hDrugsByCase[cid])_hDrugsByCase[cid]=new Set();_hDrugsByCase[cid].add(name);});
      (await idbGetAll('cases').catch(()=>[])).filter(r=>r.animal_id===id).forEach(r=>{
        const _d=_dis.find(d=>d.id===r.disease_id);
        const _drugNames=[...(_hDrugsByCase[r.id]||[])];
        const sk=r.created_at||r.start_date||'';
        entries.push({type:'hastalik',date:sk,sortKey:sk,data:{...r,disease_name:_d?.name||'?',tani:_d?.name||'?',_drugNames}});
      });
    }

    // gorev_log (tümü — pending + tamamlanmış, sadece parent_id olmayan)
    {
      const _allDrugs=await idbGetAll('drug_administrations').catch(()=>[]);
      const _allStok=await idbGetAll('stok').catch(()=>[]);
      const _stokById=Object.fromEntries(_allStok.map(s=>[s.id,s.urun_adi||'']));
      const _prodById=Object.fromEntries((await idbGetAll('drug_products').catch(()=>[])).map(p=>[p.id,p.brand_name||'']));
      const _drugsByDay={};
      _allDrugs.forEach(da=>{if(!da.treatment_day_id)return;const name=_prodById[da.drug_product_id]||_stokById[da.stok_id]||'';if(name)(_drugsByDay[da.treatment_day_id]=_drugsByDay[da.treatment_day_id]||[]).push(name);});
      const _tDays=await idbGetAll('treatment_days').catch(()=>[]);
      const _tDayById=Object.fromEntries(_tDays.map(td=>[td.id,td]));
      const _caseArr=await idbGetAll('cases').catch(()=>[]);
      const _caseById=Object.fromEntries(_caseArr.map(c=>[c.id,c]));
      const _dis=await idbGetAll('diseases').catch(()=>[]);
      const _disById=Object.fromEntries(_dis.map(d=>[d.id,d.name||'']));
      (await idbGetAll('gorev_log').catch(()=>[])).filter(r=>r.hayvan_id===id&&!r.parent_id).forEach(r=>{
        let dayId=null,_lbl='',_gunNo='';
        try{const p=typeof r.aciklama==='string'?JSON.parse(r.aciklama):r.aciklama;dayId=p?.day_id;_lbl=p?.label||'';_gunNo=p?.gun_no||'';}catch(e){}
        const _drugNames=(dayId&&_drugsByDay[dayId])||[];
        const _td=dayId&&_tDayById[dayId];
        const _cs=_td&&_caseById[_td.case_id];
        const _disName=_cs&&_disById[_cs.disease_id]||'';
        const _caseId=_cs?.id||'';
        const sk=r.tamamlanma_tarihi||r.created_at||r.hedef_tarih||'';
        entries.push({type:'gorev',date:sk,sortKey:sk,data:{...r,_drugNames,_lbl,_gunNo,_disName,_caseId}});
      });
    }

    // uygulama_log
    {
      const _uyStok=await idbGetAll('stok').catch(()=>[]);
      const _uyStokById=Object.fromEntries(_uyStok.map(s=>[s.id,s.urun_adi||'']));
      (await idbGetAll('uygulama_log').catch(()=>[])).filter(r=>r.hayvan_id===id).forEach(r=>{
        const sk=r.created_at||r.tarih||'';
        entries.push({type:'uygulama',date:sk,sortKey:sk,data:{...r,_stokAdi:_uyStokById[r.stok_id]||'?'}});
      });
    }

    // islem_log — Geri Al modal desteği için ayrı indeks tutulur
    {
      const islemLogs=(await idbGetAll('islem_log').catch(()=>[])).filter(r=>r.ana_hayvan_id===id);
      globalThis._detGecmisLogs=islemLogs;
      islemLogs.forEach((r,i)=>{
        const sk=r.created_at||r.tarih||'';
        entries.push({type:'islem',date:sk,sortKey:sk,data:r,_islemIdx:i});
      });
    }

    entries.sort((a,b)=>(b.sortKey||'').localeCompare(a.sortKey||''));
    if(!entries.length){el.innerHTML='<div class="empty"><div class="empty-ico">📋</div>Kayıt yok</div>';return;}

    // Arama metni hesapla
    entries.forEach(e=>{
      const d=e.data;
      const parts=[e.type,fmtTarih(e.date),fmtTarihSaat(e.date)];
      if(e.type==='tohumlama') parts.push(d.sperma||'',d.sonuc||'','tohumlama');
      else if(e.type==='dogum') parts.push(d.yavru_kupe||'',d.yavru_cins||'',d.dogum_tipi||'','doğum');
      else if(e.type==='hastalik') parts.push(d.disease_name||'',d.tani||'',d.status==='active'?'aktif':'kapalı',...(d._drugNames||[]));
      else if(e.type==='gorev') parts.push(d._lbl||'',d.gorev_tipi||'',d._disName||'',d.tamamlandi?'tamamlandı':'bekliyor',...(d._drugNames||[]));
      else if(e.type==='uygulama') parts.push(d._stokAdi||'',d.etken_kod||'',d.rota||'','uygulama','ilaç');
      else if(e.type==='islem'){const sn=d.snapshot||{};parts.push(d.tip||'',sn.vaccine_name||'',sn.ilac_adi||'','işlem');}
      e._s=trLower(parts.join(' '));
    });
    globalThis._detGecmisEntries=entries;

    function _renderDetGecmisList(q){
      const list=q?entries.filter(e=>trLower(q.trim()).split(/\s+/).every(t=>e._s.includes(t))):entries;
      const bodyEl=document.getElementById('det-gecmis-body');
      if(!bodyEl) return;
      if(!list.length){bodyEl.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Kayıt bulunamadı</div>';return;}
      bodyEl.innerHTML=list.map(e=>{
        if(e.type==='islem') return _gecmisEntryHtml(e,`onclick="openIslemDetay(${e._islemIdx})" style="cursor:pointer"`);
        if(e.type==='gorev' && e.data?.gorev_tipi!=='TEDAVI_GUN') return _gecmisEntryHtml(e,'');
        if(e.type==='uygulama') return _gecmisEntryHtml(e,'');
        return _gecmisEntryHtml(e);
      }).join('');
    }
    globalThis._renderDetGecmisList=_renderDetGecmisList;

    el.innerHTML=`<div style="padding:0 0 8px">
      <input id="det-gecmis-search" type="search" placeholder="Ara… (sperma, ilaç, tanı)" autocomplete="off"
        style="width:100%;box-sizing:border-box;padding:9px 12px;border:1.5px solid var(--card3);border-radius:10px;background:var(--card);color:var(--ink);font-size:.82rem"
        oninput="globalThis._renderDetGecmisList(this.value)">
    </div>
    <div id="det-gecmis-body"></div>`;
    _renderDetGecmisList('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}

// ──────────────────────────────────────────
// HAYVAN DETAY — ana fonksiyon
// ──────────────────────────────────────────
async function _detSaglikRender(el,activeCases,allDiseasesList,a,vaxLogs=[],uygulamaLogs=[]){
  const activeCaseChips=activeCases.length
    ?`<div style="margin-bottom:8px;display:flex;flex-wrap:wrap;gap:6px">`+activeCases.map(c=>{
        const dis=allDiseasesList.find(d=>d.id===c.disease_id);
        return `<div onclick="openCaseDet('${c.id}')" style="cursor:pointer;background:rgba(192,50,26,.1);border:1.5px solid var(--red);border-radius:10px;padding:6px 10px;font-size:.78rem;font-weight:700;color:var(--red)">🏥 ${esc(dis?.name||'?')}</div>`;
      }).join('')+`</div>`
    :'';
  const _caseListHtml=await renderCasesForAnimal(a.id);
  const vaxButton = `<div style="padding:6px 0 6px;display:grid;grid-template-columns:1fr 1fr;gap:6px">
    <button class="btn btn-g" style="padding:9px" data-kupe="${escAttr(a.kupe_no||a.devlet_kupe||a.id)}" onclick="openMWithHayvan('m-disease','d-hid',this.dataset.kupe)">🏥 Vaka Aç</button>
    <button class="btn btn-g" style="padding:9px" data-kupe="${escAttr(a.kupe_no||a.devlet_kupe||a.id)}" onclick="openMWithHayvan('m-vaccine','v-hid',this.dataset.kupe)">💉 Aşı Uygula</button>
    <button class="btn btn-o" style="padding:9px;grid-column:1/-1" onclick="_hayvanHizliUygulama('${a.id}')">💉 Hızlı İlaç/Vitamin Uygula</button>
  </div>`;

  // Sonraki aşı chip'i
  const vaccines = await idbGetAll('vaccines');
  const vaxMap = {};
  vaccines.forEach(v => vaxMap[v.id] = v);
  const nextDueVax = vaxLogs
    .filter(v => v.next_due_date)
    .sort((a, b) => (a.next_due_date || '').localeCompare(b.next_due_date || ''))[0];
  let nextVaxChip = '';
  if (nextDueVax) {
    const dueDate = new Date(nextDueVax.next_due_date);
    const today2 = new Date();
    today2.setHours(0,0,0,0);
    const daysDiff = Math.floor((dueDate - today2) / 86400000);
    const vaxName = vaxMap[nextDueVax.vaccine_id]?.name || '?';
    if (daysDiff < 0) {
      nextVaxChip = `<div style="margin-bottom:8px;font-size:.68rem;font-weight:700;color:var(--red);background:rgba(192,50,26,.1);border:1px solid rgba(192,50,26,.3);border-radius:8px;padding:5px 10px">⚠️ Sonraki: ${vaxName} — ${fmtTarih(nextDueVax.next_due_date)} (${Math.abs(daysDiff)} gün gecikti)</div>`;
    } else if (daysDiff <= 14) {
      nextVaxChip = `<div style="margin-bottom:8px;font-size:.68rem;font-weight:700;color:var(--amber);background:rgba(208,162,34,.1);border:1px solid rgba(208,162,34,.3);border-radius:8px;padding:5px 10px">⏰ Sonraki: ${vaxName} — ${fmtTarih(nextDueVax.next_due_date)} (${daysDiff} gün kaldı)</div>`;
    } else {
      nextVaxChip = `<div style="margin-bottom:8px;font-size:.68rem;color:var(--ink3);background:rgba(42,107,181,.08);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:5px 10px">⏰ Sonraki: ${vaxName} — ${fmtTarih(nextDueVax.next_due_date)}</div>`;
    }
  }

  // Aşı geçmişi
  const vaxHistory = vaxLogs.length
    ? `<div style="margin-top:12px;border-top:2px solid var(--card3);padding-top:8px">
        <div style="font-size:.7rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px">💉 Aşı Geçmişi</div>
        ` + vaxLogs.map(log => {
          const vac = vaccines.find(v => v.id === log.vaccine_id);
          const vacName = vac?.name || '?';
          const disease = vac?.disease_target ? ` — ${vac.disease_target}` : '';
          const nextDue = log.next_due_date ? `<div style="font-size:.68rem;color:var(--amber);margin-top:3px">⏰ Sonraki: ${fmtTarih(log.next_due_date)}</div>` : '';
          return `
            <div style="display:flex;justify-content:space-between;align-items:flex-start;padding:6px 0;border-bottom:1px solid var(--card2)">
              <div style="flex:1">
                <div style="font-weight:600;font-size:.8rem;color:var(--ink)">💉 ${vacName}${disease}</div>
                <div style="font-size:.68rem;color:var(--ink3)">${fmtTarih(log.vaccination_date)} · ${log.dose_given}${log.unit} ${log.route}</div>
                ${nextDue}
              </div>
            </div>
          `;
        }).join('') +
      `</div>`
    : `<div style="margin-top:12px;border-top:2px solid var(--card3);padding-top:8px"><div style="font-size:.75rem;color:var(--ink3)">💉 Aşı kaydı yok</div></div>`;
  
  // Hızlı uygulama geçmişi
  const stokList = await idbGetAll('stok');
  const uygulamaHtml = uygulamaLogs.length ? `<div style="margin-top:12px;border-top:2px solid var(--card3);padding-top:8px">
    <div style="font-size:.7rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px">💉 Hızlı Uygulamalar</div>
    ${uygulamaLogs.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||'')).map(u => {
      const stok = stokList.find(s => s.id === u.stok_id);
      return `<div style="display:flex;justify-content:space-between;align-items:flex-start;padding:6px 0;border-bottom:1px solid var(--card2)">
        <div style="flex:1">
          <div style="font-weight:600;font-size:.8rem;color:var(--ink)">💊 ${esc(stok?.urun_adi||'?')}</div>
          <div style="font-size:.68rem;color:var(--ink3)">${u.tarih||'?'} · ${u.doz} ${u.birim} (${u.rota}) · ${esc(u.notlar||'')}</div>
        </div>
      </div>`;
    }).join('')}
  </div>` : '';

  el.innerHTML=activeCaseChips+vaxButton+nextVaxChip+_caseListHtml+vaxHistory+uygulamaHtml;
}
function _detGorevHtml(a,tasks,subs,today){
  const kupe=a.kupe_no||a.devlet_kupe||a.id;
  // Parent'ı tamamlanmış olan rapel görevleri de üst seviyede göster
  const taskIds=new Set(tasks.map(t=>t.id));
  const orphanSubs=subs.filter(s=>!taskIds.has(s.parent_id));
  const getTime=t=>t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').planned_time||'';}catch(e){return '';}})():'';
  const allTop=[...tasks,...orphanSubs].sort((a,b)=>{const d=(a.hedef_tarih||'').localeCompare(b.hedef_tarih||'');return d||getTime(a).localeCompare(getTime(b));});
  const liste=allTop.length
    ?allTop.map(t=>{ const ts=subs.filter(s=>s.parent_id===t.id); const _stateMid=t.hedef_tarih===today?'soon':''; const state=t.hedef_tarih<today?'late':_stateMid; return renderTask(t,state,ts); }).join('')
    :'<div class="empty"><div class="empty-ico">✅</div>Bekleyen görev yok</div>';
  return `<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" data-kupe="${escAttr(kupe)}" onclick="openMWithHayvan('m-task-add','ta-hid',this.dataset.kupe)">➕ Görev Ekle</button></div>`+liste;
}
async function openDet(id, keepTab){
  _detOpenId=id;
  const activeTab = keepTab ? document.querySelector('.tab.on')?.dataset?.action?.replace('tab-','') : null;
  const curPg=getState('currentPage')||'dash';
  if (!keepTab) history.pushState({pg:curPg||'dash',det:id},'','#'+(curPg||'dash'));
  document.getElementById('det').classList.add('on');
  if (!keepTab) {
    const _backBtn = document.querySelector('.det-back');
    if (_backBtn) {
      const _svg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/></svg>';
      _backBtn.innerHTML = _svg + (window._prevTaskId ? ' Göreve Dön' : ' Sürüye Dön');
    }
  }
  document.getElementById('det-name').textContent=' ';
  document.getElementById('det-meta').textContent=' ';
  const _skelHtml='<div style="padding:16px 0">'+['80%','60%','90%','50%'].map(w=>`<div class="skel" style="height:14px;width:${w};margin-bottom:12px"></div>`).join('')+'</div>';
  ['det-chips','tab-saglik','tab-ureme','tab-gorev','tab-gecmis'].forEach(i=>{const el=document.getElementById(i);if(el)el.innerHTML='';});
  const _ozetEl=document.getElementById('tab-ozet'); if(_ozetEl) _ozetEl.innerHTML=_skelHtml;
  showTab(activeTab||'ozet',document.querySelector(activeTab?`.tab[data-action="tab-${activeTab}"]`:'.tab'));
  await pullTables(['cases','diseases','drugs','vaccines','vaccination_log','kizginlik_log','gorev_log','uygulama_log','drug_products','drug_classes']).catch(e=>toast('Veri yüklenemedi: '+e.message,true));
  if(_detOpenId!==id) return;
  try {
    const [aArr,diseases,tohs,tasks,births,subs,yavrular,activeCases,vaxLogs,kizgs,uygulamaLogs]=await Promise.all([
      getData('hayvanlar',a=>a.id===id||a.kupe_no===id||a.devlet_kupe===id),
      getData('cases',c=>c.animal_id===id),
      getData('tohumlama',t=>t.hayvan_id===id),
      getData('gorev_log',t=>t.hayvan_id===id&&!t.tamamlandi&&!t.iptal&&!t.parent_id),
      getData('dogum',b=>b.anne_id===id),
      getData('gorev_log',t=>t.hayvan_id===id&&!t.tamamlandi&&!t.iptal&&!!t.parent_id),
      getData('hayvanlar',a=>a.anne_id===id),
      getData('cases',c=>c.animal_id===id&&c.status==='active'),
      getData('vaccination_log',v=>v.animal_id===id),
      getData('kizginlik_log',k=>k.hayvan_id===id),
      getData('uygulama_log',u=>u.hayvan_id===id),
    ]);
    if(_detOpenId!==id) return;
    // K7: id/küpe referansıyla eşleşen birden çok kayıt varsa AKTİF olan önce
    const a=aArr.find(x=>x.durum==='Aktif')||aArr[0]; if(!a){ document.getElementById('det-name').textContent='Bulunamadı'; return; }
    diseases.sort((x,y)=>(y.tarih||'').localeCompare(x.tarih||''));
    tohs.sort((x,y)=>(y.tarih||'').localeCompare(x.tarih||''));
    tasks.sort((x,y)=>(x.hedef_tarih||'').localeCompare(y.hedef_tarih||''));
    vaxLogs.sort((x,y)=>(y.vaccination_date||'').localeCompare(x.vaccination_date||''));
    const yasRaw=a.dogum_tarihi?Math.floor((Date.now()-new Date(a.dogum_tarihi))/86400000):null;
    const _yasGunBase=yasRaw<0||yasRaw>36500?'Geçersiz tarih':yasHesapla(a.dogum_tarihi);
    const yasGun=yasRaw===null?'—':_yasGunBase;
    const aktifHst=diseases.filter(c=>c.status==='active').length;
    const today=bugun();
    const displayId=a.devlet_kupe||a.kupe_no||a.id;
    document.getElementById('det-name').textContent=displayId;
    document.getElementById('det-meta').textContent=`${a.irk||'—'} · ${a.padok||'?'}`;
    document.getElementById('det-chips').innerHTML=[
      {cls:'chip-k',txt:a.grup||'?'},
      {cls:'chip-k',txt:a.padok||'?'},
      aktifHst>0||activeCases.length>0?{cls:'chip-r',txt:`🚨 ${activeCases.length||aktifHst} aktif vaka`}:{cls:'chip-g',txt:'✅ Sağlıklı'},
      (()=>{const gToh=tohs.filter(t=>t.sonuc==='Gebe').sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''))[0]; if(!gToh)return null; const gun=Math.floor((Date.now()-new Date(gToh.tarih))/86400000); return {cls:'chip-g',txt:`🤰 ${gun}. gün · Tahmini: ${dFwd(gToh.tarih,280)}`};})(),
    ].filter(Boolean).map(c=>`<div class="chip ${c.cls}">${c.txt}</div>`).join('');

    document.getElementById('tab-ozet').innerHTML=_detOzetHtml(a,births,diseases,tasks,subs,yavrular,yasRaw,yasGun,displayId);

    const allDiseasesList=await idbGetAll('diseases');
    await _detSaglikRender(document.getElementById('tab-saglik'),activeCases,allDiseasesList,a,vaxLogs,uygulamaLogs);

    document.getElementById('tab-ureme').innerHTML=_detUremeHtml(a,tohs,kizgs);

    document.getElementById('tab-gorev').innerHTML=_detGorevHtml(a,tasks,subs,today);

    const gecmisEl=document.getElementById('tab-gecmis');
    if(gecmisEl) await _detRenderGecmis(id,gecmisEl);

  } catch(e){ document.getElementById('det-name').textContent='Hata: '+e.message; }
}
function closeDet(){
  document.getElementById('det').classList.remove('on');
  // REV-5: sessiz sheet'inden gelindiyse sheet'i geri göster (scroll korunur);
  // hem ✕/geri butonu hem Android geri (app.js popstate det dalı) bu noktadan döner.
  if(globalThis._sessizReturn){
    globalThis._sessizReturn=false;
    const sb=document.getElementById('sessiz-bs');
    if(sb) sb.style.display='flex';
  }
}
function fromTaskOpenDet(hayvanId, taskId) {
  window._prevTaskId = taskId;
  closeM('m-task-det');
  closeM('m-done-det');
  openDet(hayvanId);
}

// ── PADOK DEĞİŞTİR (hayvan kartı özet tab) ──
// ── İŞLEM GERİ AL (genel — padok ve görev güncellemeleri) ──
async function islemGeriAl(islemId) {
  if (!confirm('Bu işlemi geri almak istediğinize emin misiniz?')) return;
  try {
    const res = await rpc('islem_geri_al', { p_islem_id: islemId });
    toast('✅ İşlem geri alındı');
    await pullTables(['hayvanlar', 'islem_log']);
    if (typeof openDet === 'function' && window._detOpenId) openDet(window._detOpenId);
  } catch (e) {
    toast('❌ ' + e.message, true);
  }
}

function openIslemDetay(idx){
  const l=(globalThis._detGecmisLogs||[])[idx];
  if(!l) return;
  // ref_tablo varsa doğrudan ilgili detay modalını aç
  // ABORT_KAYDI hariç: abort kaydının Geri Al butonu bu panelde — toh det'e yönlendirme
  if(l.ref_tablo==='tohumlama' && l.ref_id && l.tip!=='ABORT_KAYDI'){ openTohDet(l.ref_id); return; }
  // TOHUMLAMA tipinde snapshot id varsa direkt aç
  const snapId=l.snapshot?.id;
  if(l.tip==='TOHUMLAMA' && snapId){ openTohDet(snapId); return; }
  const LABEL={'HAYVAN_EKLENDI':'Hayvan Eklendi','TOHUMLAMA':'Tohumlama','DOGUM_KAYDI':'Doğum','HASTALIK_KAYDI':'Hastalık Kaydı','TEDAVI_GUNCELLE':'Tedavi Güncelle','KIZGINLIK':'Kızgınlık','ABORT_KAYDI':'Abort','SATIS_KAYDI':'Satış','OLUM_KAYDI':'Ölüm','SUTTEN_KESME':'Sütten Kesme','KISIR_ISARETLE':'Kısır İşareti','KISIR_KALDIR':'Kısır Kaldırıldı','VAKA_ACILDI':'Vaka Açılışı','TEDAVI_GUN_EKLENDI':'Tedavi Günü Eklendi'};
  const ICO={'HAYVAN_EKLENDI':'🐮','TOHUMLAMA':'💉','DOGUM_KAYDI':'🐄','HASTALIK_KAYDI':'🏥','TEDAVI_GUNCELLE':'💊','KIZGINLIK':'🔴','ABORT_KAYDI':'⚠️','SATIS_KAYDI':'💰','OLUM_KAYDI':'💀','SUTTEN_KESME':'🍼','KISIR_ISARETLE':'💲','KISIR_KALDIR':'⭕','VAKA_ACILDI':'🏥','TEDAVI_GUN_EKLENDI':'💊'};
  const ALAN={'tarih':'Tarih','sperma':'Sperma','sonuc':'Sonuç','deneme_no':'Deneme','tani':'Tanı','siddet':'Şiddet','durum':'Durum','hekim_id':'Hekim','yavru_kupe':'Yavru Küpe','yavru_cins':'Yavru Cinsiyet','dogum_tipi':'Doğum Tipi','notlar':'Not','irk':'Irk','grup':'Grup','kupe_no':'Küpe','devlet_kupe':'Devlet Küpe'};
  const tarih=(l.created_at||l.tarih||'').slice(0,10);
  const GeriAlabilir=['TOHUMLAMA','DOGUM_KAYDI','HASTALIK_KAYDI','ABORT_KAYDI','HAYVAN_GUNCELLENDI','VAKA_ACILDI','TEDAVI_GUN_EKLENDI'];
  const payload=l.payload&&typeof l.payload==='object'?l.payload:{};
  const satirlar=Object.entries(payload)
    .filter(([k,v])=>!['hayvan_id','id','ana_hayvan_id'].includes(k)&&v!==null&&v!==undefined&&v!=='')
    .map(([k,v])=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card3);font-size:.78rem"><span style="color:var(--ink3)">${ALAN[k]||k}</span><span style="font-weight:600;color:var(--ink);text-align:right;max-width:60%">${v}</span></div>`)
    .join('');
  const gaBtn=GeriAlabilir.includes(l.tip)
    ? (l.tip === 'HAYVAN_GUNCELLENDI'
      ? `<button class="btn" style="background:var(--red);color:#fff;width:100%;margin-top:10px" onclick="islemGeriAl('${l.id}')">↩️ Geri Al</button>`
      : `<button class="btn" style="background:var(--red);color:#fff;width:100%;margin-top:10px" onclick="openGeriAl('${l.id}','${LABEL[l.tip]||l.tip} — ${tarih} tarihli kayıt geri alınacak.')">↩ Geri Al</button>`)
    : '';
  const html=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:var(--r2);padding:14px;margin-top:8px">
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
  const existing=gecmisEl?.querySelector('.islem-detay-panel');
  if(existing) existing.remove();
  const rows=gecmisEl?.querySelectorAll('.hist-row');
  const clickedRow=rows?.[idx];
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
  const a=getState('animals').find(x=>x.id===id); if(!a){ toast('Hayvan bulunamadı',true); return; }
  const modal=document.getElementById('m-animal');
  if(!modal) return;

  // Önce formu temizle — önceki değerler kalmasın
  ['a-devlet','a-kupe','a-irk-txt','a-dt','a-dkg','a-agirlik','a-boy','a-renk','a-ozellik'].forEach(fid=>{const el=document.getElementById(fid);if(el)el.value='';});
  const cins=document.getElementById('a-cinsiyet'); if(cins) cins.value='';

  modal.dataset.editId=id;
  document.getElementById('m-animal-title').textContent='✏️ Bilgileri Düzenle';
  document.getElementById('m-animal-btn').textContent='💾 Güncelle';

  openM('m-animal');

  // Mevcut değerleri doldur — async/await, setTimeout yok
  if(a.devlet_kupe) document.getElementById('a-devlet').value=a.devlet_kupe;
  if(a.kupe_no)     document.getElementById('a-kupe').value=a.kupe_no;
  if(a.cinsiyet)    document.getElementById('a-cinsiyet').value=a.cinsiyet;
  if(a.dogum_tarihi) document.getElementById('a-dt').value=a.dogum_tarihi;
  document.getElementById('a-dt').max=new Date().toISOString().slice(0,10);
  if(a.dogum_kg)    document.getElementById('a-dkg').value=a.dogum_kg;
  if(a.canli_agirlik) document.getElementById('a-agirlik').value=a.canli_agirlik;
  if(a.boy)         document.getElementById('a-boy').value=a.boy;
  if(a.renk)        document.getElementById('a-renk').value=a.renk||'';
  if(a.ayirici_ozellik) document.getElementById('a-ozellik').value=a.ayirici_ozellik||'';

  // Irk dropdown
  await loadIrkDropdown();
  const irkSel=document.getElementById('a-irk-sel');
  if(irkSel && a.irk){
    const opt=[...irkSel.options].find(o=>o.value===a.irk);
    if(opt){ irkSel.value=a.irk; }
    else {
      irkSel.value='__diger__';
      const txt=document.getElementById('a-irk-txt');
      if(txt){ txt.style.display='block'; txt.disabled=false; txt.value=a.irk; }
    }
  }

  // Kısır checkbox — sadece düzenleme modunda göster
  const kw=document.getElementById('a-kisir-wrap');
  const kc=document.getElementById('a-kisir');
  const kh=document.getElementById('a-kisir-hint');
  if(kw&&kc){
    kw.style.display='block';
    kc.checked=!!a.kisir;
    // Gebe kontrolü — gebe hayvan kısır işaretlenemez
    const gebeSet=new Set(getState('gebeIds')||[]);
    if(gebeSet.has(a.id)){
      kc.disabled=true;
      kh.textContent='(gebe hayvan kısır işaretlenemez)';
    } else {
      kc.disabled=false;
      kh.textContent='(sadece gebe olmayan hayvanlar)';
    }
  }

  // Genç anne / üreme statüsü — sadece belirsiz hayvanlarda göster
  const gw=document.getElementById('a-genc-anne-wrap');
  const gs=document.getElementById('a-genc-anne');
  if(gw&&gs){
    const dogumlar=await idbGetAll('dogum').catch(()=>[]);
    const dogumSay=(dogumlar||[]).filter(d=>d.anne_id===a.id).length;
    const grupDuve=/düve|duve/i.test(a.grup||'');
    const tohlar=await idbGetAll('tohumlama').catch(()=>[]);
    const tohVar=(tohlar||[]).some(t=>t.hayvan_id===a.id);
    const belirsiz=a.cinsiyet!=='Erkek' && !a.kisir && !grupDuve && dogumSay<2 && tohVar;
    if(belirsiz){
      gw.style.display='block';
      gs.value=(a.genc_anne===true?'true':a.genc_anne===false?'false':'');
    } else {
      gw.style.display='none';
      gs.value='';
    }
  }

  // Grup + padok
  await animalFormGuncelle();
  const grupSel=document.getElementById('a-grup');
  if(grupSel && a.grup){
    const opt=[...grupSel.options].find(o=>o.value===a.grup);
    if(!opt) grupSel.innerHTML+=`<option value="${esc(a.grup)}">${esc(a.grup)}</option>`;
    grupSel.value=a.grup;
    animalGrupDegisti();
    const padokSel=document.getElementById('a-padok');
    if(padokSel && a.padok_id){
      const popt=[...padokSel.options].find(o=>o.value===a.padok_id);
      if(!popt) padokSel.innerHTML+=`<option value="${esc(a.padok_id)}">${a.padok||a.padok_id}</option>`;
      padokSel.value=a.padok_id;
    }
  }
}

function closeAnimalEdit(){
  const modal=document.getElementById('m-animal');
  if(modal){ delete modal.dataset.editId; }
  ['a-devlet-warn','a-kupe-warn'].forEach(id=>{const el=document.getElementById(id);if(el)el.textContent='';});
  // Kısır checkbox'ı gizle
  const kw=document.getElementById('a-kisir-wrap');
  if(kw) kw.style.display='none';
  const kc=document.getElementById('a-kisir');
  if(kc){ kc.checked=false; kc.disabled=false; }
  // Genç anne select'i gizle
  const gw2=document.getElementById('a-genc-anne-wrap');
  if(gw2) gw2.style.display='none';
  const gs2=document.getElementById('a-genc-anne');
  if(gs2) gs2.value='';
  const titleEl=document.getElementById('m-animal-title');
  const btnEl=document.getElementById('m-animal-btn');
  if(titleEl) titleEl.textContent='🐄 Hayvan Ekle';
  if(btnEl)   btnEl.textContent='Kaydet';
  closeM('m-animal');
}

// Çıkış modal
function openCikisModal(hayvanId,kupe){
  const a=Math.floor(Math.random()*9)+1;
  const b=Math.floor(Math.random()*9)+1;
  document.getElementById('cx-hid').value=hayvanId;
  document.getElementById('cx-title').textContent='🚪 '+kupe+' — Çıkış';
  document.getElementById('cx-tarih').value=bugun();
  document.getElementById('cx-math-label').textContent=`${a} + ${b}`;
  document.getElementById('cx-math-ans').value='';
  document.getElementById('cx-math-ok').value=String(a+b);
  const hayvan=(getState('animals')||[]).find(h=>h.id===hayvanId);
  const infoEl=document.getElementById('cx-info');
  if(infoEl&&hayvan){
    const yas=hayvan.dogum_tarihi?Math.floor((Date.now()-new Date(hayvan.dogum_tarihi))/86400000)+' gün':'—';
    infoEl.innerHTML=`<b>${esc(kupe)}</b> · ${esc(hayvan.irk||'—')} · ${esc(hayvan.hesap_kategori||hayvan.grup||'—')}<br>Yaş: ${yas}`;
    infoEl.style.display='block';
  }
  openM('m-cikis');
}

// ──────────────────────────────────────────
// DOĞUMLAR
// ──────────────────────────────────────────
async function loadBirths(){
  const el=document.getElementById('births-body');
  await _keepScroll(el,async()=>{
  try {
    const data=await idbGetAll('dogum');
    data.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
    if(!data.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🐄</div>Henüz doğum yok</div>'; return; }
    const animals=getState('animals')||[];
    el.innerHTML=data.slice(0,8).map(b=>{
      const anneObj=animals.find(a=>a.id===b.anne_id||a.kupe_no===b.anne_id);
      const anneKupe=anneObj?.kupe_no||anneObj?.devlet_kupe||b.anne_id||'?';
      const tip=b.dogum_tipi||'Normal';
      const tipClr=tip==='Sezaryan'?'var(--red)':tip==='Güç'?'var(--amber)':'var(--green)';
      const tipBg=tip==='Sezaryan'?'rgba(192,50,26,.12)':tip==='Güç'?'rgba(176,120,0,.12)':'rgba(42,122,42,.12)';
      return `<div style="background:var(--card2);border:1px solid var(--card3);border-radius:10px;padding:10px 13px;margin-bottom:6px;display:flex;align-items:center;gap:10px">
    <div style="width:34px;height:34px;border-radius:9px;background:rgba(78,154,42,.12);display:flex;align-items:center;justify-content:center;font-size:1.1rem;flex-shrink:0">🐄</div>
    <div style="flex:1;min-width:0">
      <div style="font-weight:700;font-size:.85rem;color:var(--ink2)">${esc(anneKupe)} → <b>${esc(b.yavru_kupe||'?')}</b> <span style="color:var(--ink3);font-weight:400">(${esc(b.yavru_cins||'?')})</span></div>
      <div style="font-size:.7rem;color:var(--ink3);margin-top:2px">${fmtTarih(b.tarih)} · <span style="background:${tipBg};color:${tipClr};border-radius:4px;padding:1px 6px;font-weight:700">${tip}</span>${b.dogum_kg?' · '+b.dogum_kg+' kg':''}</div>
    </div>
  </div>`;
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
  });
}

// ──────────────────────────────────────────
// GEBE HAYVAN SEÇME
// ──────────────────────────────────────────
async function gebeledenSec(){
  const tohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
  const today2=new Date();
  const listFromToh=tohs.map(t=>{
    const toh=new Date(t.tarih);
    const dogumTahmini=new Date(toh.getTime()+280*86400000);
    const kalanGun=Math.floor((dogumTahmini-today2)/86400000);
    const hayvan=getState('animals').find(a=>a.id===t.hayvan_id||a.kupe_no===t.hayvan_id);
    return {toh:t,hayvan,kalanGun,dogumTahmini:_ymd(dogumTahmini)};
  }).filter(g=>g.hayvan);
  const gebeList=[...listFromToh];
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
        const _colorMid=urgent?'#b84c00':'#1a5c1a';
        const color=overdue?'#c0321a':_colorMid;
        const _bgMid=urgent?'rgba(184,76,0,.06)':'rgba(78,154,42,.04)';
        const bg=overdue?'rgba(192,50,26,.06)':_bgMid;
        const _badgeUrgent=`<span style="background:#b84c00;color:#fff;border-radius:8px;padding:2px 7px;font-size:.62rem;font-weight:700">⚡ ${g.kalanGun} GÜN</span>`;
        const _badgeNormal=`<span style="background:rgba(78,154,42,.15);color:#1a5c1a;border-radius:8px;padding:2px 7px;font-size:.62rem;font-weight:700">${g.kalanGun} gün kaldı</span>`;
        const _badgeMid=urgent?_badgeUrgent:_badgeNormal;
        const badge=overdue?`<span style="background:#c0321a;color:#fff;border-radius:8px;padding:2px 7px;font-size:.62rem;font-weight:700">GECİKTİ ${Math.abs(g.kalanGun)} GÜN</span>`:_badgeMid;
        return `<div data-hid="${escAttr(g.hayvan.id)}" data-kupe="${escAttr(kupe)}" data-dt="${escAttr(g.dogumTahmini)}" data-sperma="${escAttr(g.toh.sperma||'')}" onclick="anneSeç(this.dataset.hid,this.dataset.kupe,this.dataset.dt,this.dataset.sperma)"
          style="padding:12px 14px;border-bottom:1px solid var(--card3);cursor:pointer;background:${bg};display:flex;justify-content:space-between;align-items:center">
          <div>
            <div style="font-weight:700;font-size:.88rem;color:${color}">${esc(kupe)}</div>
            <div style="font-size:.68rem;color:var(--ink3);margin-top:2px">${esc(g.hayvan?.irk||'—')} · ${esc(g.toh.tarih)} · ${esc(g.toh.sperma||'?')}</div>
            <div style="font-size:.65rem;color:#888;margin-top:1px">Tahmini doğum: ${fmtTarih(g.dogumTahmini)}</div>
          </div>${badge}
        </div>`;
      }).join('');
  box.innerHTML=`<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:75vh;display:flex;flex-direction:column">
    <div style="padding:14px 16px 0;display:flex;justify-content:space-between;align-items:center">
      <div style="font-weight:800;font-size:1rem">🤰 Gebe Hayvanlar</div>
      <button onclick="document.getElementById('gebe-sec-modal').remove()" style="background:none;border:none;font-size:1.3rem;cursor:pointer;color:#999">✕</button>
    </div>
    <div style="font-size:.68rem;color:#999;padding:4px 16px 10px">280 güne yakınlığa göre sıralandı</div>
    <div style="padding:12px 14px;border-bottom:1px solid var(--card3)">
      <input id="gebe-srch" oninput="gebeFiltrele()" placeholder="Küpe no ara…" style="width:100%;padding:8px 12px;border:1.5px solid var(--green);border-radius:8px;font-size:.85rem;outline:none;box-sizing:border-box">
    </div>
    <div id="gebe-list" style="overflow-y:auto;flex:1">${listHtml}</div>
    <div style="padding:12px 16px;border-top:1px solid var(--card3)">
      <button onclick="document.getElementById('gebe-sec-modal').remove()" style="width:100%;padding:11px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">Kapat</button>
    </div>
  </div>`;
  box.style.display='flex';
  box._gebeList=gebeList;
  setTimeout(()=>document.getElementById('gebe-srch')?.focus(),100);
}
function gebeFiltrele(){
  const q=trLower(document.getElementById('gebe-srch')?.value||'');
  const box=document.getElementById('gebe-sec-modal');
  if(!box||!box._gebeList) return;
  const listEl=document.getElementById('gebe-list');
  const filtered=q?box._gebeList.filter(g=>{
    const kupe=trLower(g.hayvan?.kupe_no||g.hayvan?.devlet_kupe||g.toh.hayvan_id||'');
    return kupe.includes(q);
  }):box._gebeList;
  listEl.innerHTML=filtered.map(g=>{
    const kupe=g.hayvan?.kupe_no||g.hayvan?.devlet_kupe||g.toh.hayvan_id;
    const overdue=g.kalanGun<0, urgent=g.kalanGun<=7&&!overdue;
    const _colorMidF=urgent?'#b84c00':'#1a5c1a';
    const color=overdue?'#c0321a':_colorMidF;
    return `<div data-hid="${escAttr(g.hayvan.id)}" data-kupe="${escAttr(kupe)}" data-dt="${escAttr(g.dogumTahmini)}" data-sperma="${escAttr(g.toh.sperma||'')}"
      onclick="anneSeç(this.dataset.hid,this.dataset.kupe,this.dataset.dt,this.dataset.sperma)"
      style="padding:12px 14px;border-bottom:1px solid var(--card3);cursor:pointer">
      <div style="font-weight:700;font-size:.88rem;color:${color}">${esc(kupe)} — ${overdue?'GECİKTİ '+Math.abs(g.kalanGun)+' gün':g.kalanGun+' gün kaldı'}</div>
      <div style="font-size:.68rem;color:var(--ink3);margin-top:2px">${esc(g.hayvan?.irk||'—')} · ${esc(g.toh.sperma||'?')} · Tahmini: ${fmtTarih(g.dogumTahmini)}</div>
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
  // Baba otomasyonu
  const babaAuto=document.getElementById('b-baba-auto');
  const babaText=document.getElementById('b-baba-text');
  const babaHid=document.getElementById('b-baba');
  if(sperma){
    babaHid.value=sperma;
    babaAuto.textContent=`💉 ${sperma} — otomatik`;
    babaAuto.style.display='block';
    babaText.style.display='none';
    babaText.value='';
  } else {
    babaHid.value='';
    babaAuto.style.display='none';
    babaText.style.display='block';
  }
}
function anneSecimSifirla(){
  const el=document.getElementById('b-anne'); if(el) el.value='';
  document.getElementById('anne-secili-card').style.display='none';
  document.getElementById('btn-gebe-sec').style.display='';
}
function openDetByKupe(kupe){
  if(!kupe) return;
  const a=hayvanByKupeRef(kupe);
  if(a) openDet(a.id);
  else toast('Hayvan bulunamadı: '+kupe);
}
// K7 (spec 2026-09-01): küpe/id referansından hayvan bulma — AKTİF öncelikli.
// Aynı küpe string'i geçmişte çıkmışta + bugün aktifte varsa aktif bulunur.
function hayvanByKupeRef(ref){
  if(!ref) return undefined;
  const L=getState('animals')||[];
  const hit=a=>a&&(a.kupe_no===ref||a.devlet_kupe===ref||a.id===ref);
  return L.find(a=>hit(a)&&a.durum==='Aktif')||L.find(hit);
}
// K6: "Boş küpeler" öneri butonu — b-kupe (doğum) / a-kupe (manuel) yanındaki 💡.
// Cinsiyete göre havuz: erkek=500-599, dişi=1-999 (5xx hariç), küçükten büyüğe.
function kupeOnerGoster(alan){
  const liste=document.getElementById(alan+'-oner-list');
  if(!liste) return;
  if(liste.style.display==='flex'){ liste.style.display='none'; return; } // toggle
  const cinsSel=document.getElementById(alan==='b-kupe'?'b-cins':'a-cinsiyet');
  const cins=cinsSel?.value||'';
  const havuzCins=cins||'Dişi'; // manuel formda cinsiyet boşsa dişi havuzu göster
  const oneri=bosKupeOner(getState('animals'),havuzCins,10);
  const not=(!cins&&alan==='a-kupe')
    ?'<div style="font-size:.62rem;color:var(--ink3);width:100%">Cinsiyet seçili değil — dişi havuzu (1-999, 5xx hariç) gösteriliyor</div>'
    :'';
  liste.innerHTML=not+oneri.map(k=>'<button type="button" class="ek-chip" onclick="kupeOnerSec(\''+alan+'\',\''+k+'\')">'+k+'</button>').join('');
  liste.style.display='flex';
}
function kupeOnerSec(alan,kupe){
  const input=document.getElementById(alan);
  if(input) input.value=kupe;
  const liste=document.getElementById(alan+'-oner-list');
  if(liste) liste.style.display='none';
  if(typeof _kupeKontrolEt==='function') _kupeKontrolEt(alan); // blur ön kontrolünü tetikle
}
function dogumYaptiAc(hayvanId,kupe,tohTarih,sperma){
  const dogumTahmini=dFwd(tohTarih,280);
  anneSeç(hayvanId,kupe,dogumTahmini,sperma);
  const tarihEl=document.getElementById('b-tarih');
  if(tarihEl) tarihEl.value=bugun();
  openM('m-birth');
}
function ikinciYavruAc(hayvanId,kupe,dogumTarihi,sperma){
  anneSeç(hayvanId,kupe,dogumTarihi,sperma||'');
  const t=document.getElementById('b-tarih'); if(t) t.value=dogumTarihi;
  const k=document.getElementById('b-kupe'); if(k) k.value='';
  openM('m-birth');
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
// ── ÜREME TAB HELPER'LAR ────────────────────
async function _uremeKizginlik(el){
  // Toolbar'ı göster
  const tb=document.getElementById('kizginlik-toolbar');
  if(tb) tb.style.display='block';
  // Filtre + search oku
  const q=trLower(document.getElementById('kizginlik-srch')?.value||'').trim();
  const flt=globalThis._kizginlikFilter||'tumu';
  let list=await idbGetAll('kizginlik_log');
  const animals=getState('animals')||[];
  // Search filtresi
  if(q){
    list=list.filter(k=>{
      const h=animals.find(a=>a.id===k.hayvan_id);
      const kupe=trLower(h?.kupe_no||h?.devlet_kupe||'');
      return kupe.includes(q)||trLower(k.hayvan_id).includes(q);
    });
  }
  list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  // ── Gruplama: aksiyon penceresi 48 saat ──────────────────────────
  // ≤48h + aksiyon alınmamış → Bekleyen; postpartum → Gözlem;
  // >48h aksiyon alınmamış → Geçti/Kaçırıldı; cozuldu → Sonuçlanan.
  const KIZGINLIK_AKTIF_SAAT=48;
  // M-18 fix: k.olusturma ve k.tarih ikisi de yoksa null dön — eskiden new Date(undefined)
  // NaN üretip yanlışlıkla "bekleyen"e düşüyordu (null.olusturma/tarih durumunda ise
  // new Date(null)=epoch 1970 → yanlışlıkla "Geçti/Kaçırıldı"ya düşüyordu). İkisi de yanlıştı.
  const _ageH=k=>(k.olusturma||k.tarih)?(Date.now()-new Date(k.olusturma||k.tarih))/3600000:null;
  const _isGozlem=k=>k.sonuc==='POSTPARTUM_GOZLEM';
  let bekleyen=[], gozlem=[], gecti=[], sonuclanan=[];
  list.forEach(k=>{
    if(k.cozuldu){ sonuclanan.push(k); return; }
    if(_isGozlem(k)){ gozlem.push(k); return; }
    const yas=_ageH(k);
    if(yas===null){ bekleyen.push(k); return; } // tarih bilinmiyor — güvenli taraf: aksiyon bekleyen say
    if(yas>KIZGINLIK_AKTIF_SAAT){ gecti.push(k); return; }
    bekleyen.push(k);
  });
  // Durum filtresi: 'bekleyen' → açık olanlar (bekleyen+gözlem); 'sonuclanan' → geçmiş (geçti+sonuçlanan)
  if(flt==='bekleyen'){ gecti=[]; sonuclanan=[]; }
  else if(flt==='sonuclanan'){ bekleyen=[]; gozlem=[]; }
  const card=(k,mode)=>{
    const h=getState('animals').find(a=>a.id===k.hayvan_id);
    const kupe=h?.kupe_no||h?.devlet_kupe||k.hayvan_id;
    const badge = mode==='sonuclanan'
      ? (k.tedavi_case_id
          ? `<span style="font-size:.6rem;color:var(--red2);background:rgba(192,50,26,.1);border-radius:4px;padding:1px 5px;margin-left:4px">🏥 Tedavi</span>`
          : `<span style="font-size:.6rem;color:var(--blue);background:rgba(52,152,219,.1);border-radius:4px;padding:1px 5px;margin-left:4px">💉 Tohumlandı</span>`)
      : mode==='gozlem'
        ? `<span style="font-size:.6rem;color:var(--ink3);background:var(--card2);border-radius:4px;padding:1px 5px;margin-left:4px">👁 Gözlem</span>`
      : mode==='gecti'
        ? `<span style="font-size:.6rem;color:#8a6a1e;background:rgba(176,134,46,.12);border-radius:4px;padding:1px 5px;margin-left:4px">⌛ Geçti</span>`
      : '';
    const caseBadge = k.tedavi_case_id && mode!=='sonuclanan'
      ? `<span style="font-size:.6rem;color:var(--blue);background:rgba(42,107,181,.1);border-radius:4px;padding:1px 5px;margin-left:4px;cursor:pointer" onclick="event.stopPropagation();toast('🏥 Vaka açıldı — Tedavi sekmesinden görüntüleyin')">🔗 Vaka</span>`
      : '';
    const dot = mode==='gecti'?'#b0862e':mode==='gozlem'?'var(--ink3)':'#e74c3c';
    const ico = mode==='gecti'?'⌛':mode==='gozlem'?'👁':'🔴';
    const showAct = mode==='bekleyen';
    return `<div class="hist-row">
      <div class="hist-dot" style="background:${dot};cursor:pointer" onclick="openDet('${k.hayvan_id}')"></div>
      <div class="hist-main" style="cursor:pointer" onclick="openDet('${k.hayvan_id}')">
        <div class="hist-title">${ico} ${esc(kupe)} — ${esc(k.belirti||'Kızgınlık')} ${badge}</div>
        <div class="hist-sub">${esc(k.tarih)} ${k.notlar?'· '+esc(k.notlar):''} ${caseBadge}</div>
      </div>
      <div style="display:flex;gap:3px;flex-shrink:0;align-items:center">
        ${showAct?`
          <button style="background:var(--blue);color:#fff;padding:2px 5px;font-size:.62rem;border-radius:4px;border:none;cursor:pointer;font-weight:700"
            data-kupe="${escAttr(kupe)}" onclick="event.stopPropagation();globalThis._insemKizginlikId='${k.id}';openInsemSafe(this.dataset.kupe)">💉 Tohumla</button>
          <button style="background:rgba(42,107,181,.15);color:var(--blue);padding:2px 5px;font-size:.62rem;border-radius:4px;border:none;cursor:pointer;font-weight:700;white-space:nowrap"
            data-kupe="${escAttr(kupe)}" onclick="event.stopPropagation();kizginlikTedaviAc('${k.id}',this.dataset.kupe)">🏥 Tedavi</button>
        `:''}
        <button style="background:rgba(192,50,26,.1);color:var(--red2);padding:2px 5px;font-size:.6rem;border-radius:4px;border:none;cursor:pointer;font-weight:700;line-height:1"
          onclick="event.stopPropagation();kizginlikSil('${k.id}')">🗑️</button>
      </div>
    </div>`;
  };
  const sec=(arr,mode,title,color,topBorder)=>arr.length
    ? `<div style="${topBorder?'margin-top:12px;border-top:1px solid var(--card3);padding-top:8px;':'margin-bottom:8px;'}font-size:.72rem;font-weight:700;color:${color};text-transform:uppercase;letter-spacing:.06em;padding:4px 0">${title} (${arr.length})</div>`
      +arr.map(k=>card(k,mode)).join('')
    : '';
  const bekleyenHtml=sec(bekleyen,'bekleyen','🔴 Bekleyen Kızgınlıklar','var(--red2)',false);
  const gozlemHtml=sec(gozlem,'gozlem','👁 Gözlem (Postpartum)','var(--ink3)',bekleyen.length>0);
  const gectiHtml=sec(gecti,'gecti','⌛ Geçti / Kaçırıldı','#b0862e',bekleyen.length+gozlem.length>0);
  const sonucHtml=sec(sonuclanan,'sonuclanan','✅ Sonuçlanan','var(--green)',bekleyen.length+gozlem.length+gecti.length>0);
  el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-kizginlik')">🔴 Kızgınlık Ekle</button></div>`
    +(list.length?bekleyenHtml+gozlemHtml+gectiHtml+sonucHtml:'<div class="empty"><div class="empty-ico">🔴</div>Kızgınlık kaydı yok</div>');
}

// ── İN-FLOW VAKA AÇMA (Plan-E) ─────────────
function sorunBottomSheet(tohId, kizId) {
  let box = document.getElementById('sorun-bs');
  if (box) box.remove();

  const sorunlar = [
    { id: 'endometrit',  label: '🦠 Endometrit',    tani: 'Endometrit' },
    { id: 'kist',        label: '🔵 Kist',           tani: 'Over Kisti' },
    { id: 'tumor',       label: '🎗 Tümör',          tani: 'Tümör' },
    { id: 'pg',          label: '💊 PG Protokolü',   tani: 'PG Protokolü' },
    { id: 'prit',        label: '💉 PRIT',            tani: 'PRIT Protokolü' },
    { id: 'diger',       label: '+ Serbest Giriş',   tani: null },
  ];

  box = document.createElement('div');
  box.id = 'sorun-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) { box.remove(); _sorunBsTemizle(); } };

  box.innerHTML = `
    <div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
      <div style="font-weight:800;font-size:.95rem;margin-bottom:4px">⚠️ Tespit edilen sorunu seçin</div>
      <div style="font-size:.75rem;color:var(--ink3);margin-bottom:14px">Tohumlama kaydedildi — şimdi vaka açılıyor</div>
      <div style="display:flex;flex-wrap:wrap;gap:7px;margin-bottom:14px">
        ${sorunlar.map(s => `
          <button type="button" data-sid="${escAttr(s.id)}" data-tani="${escAttr(s.tani||'')}" onclick="sorunSec(this.dataset.sid,this.dataset.tani,event)"
            style="padding:7px 13px;border-radius:20px;border:1.5px solid var(--card3);background:var(--card);color:var(--ink2);font-size:.78rem;font-weight:600;cursor:pointer">
            ${s.label}
          </button>`).join('')}
      </div>
      <div id="sorun-serbest" style="display:none;margin-bottom:12px">
        <input id="sorun-serbest-input" class="fi" placeholder="Tanı / notlar…">
      </div>
      <div style="display:flex;gap:8px">
        <button onclick="sorunVakaAc('${tohId||''}','${kizId||''}')"
          style="flex:1;padding:12px;background:var(--red2);color:#fff;border:none;border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">
          🏥 Vaka Aç
        </button>
        <button onclick="document.getElementById('sorun-bs').remove();_sorunBsTemizle()"
          style="flex:1;padding:12px;background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:10px;font-size:.9rem;cursor:pointer">
          Şimdi Değil
        </button>
      </div>
    </div>`;
  document.body.appendChild(box);
}

let _sorunSecilen = null;

function sorunSec(id, tani, e) {
  _sorunSecilen = { id, tani };
  document.querySelectorAll('#sorun-bs button[onclick^="sorunSec"]').forEach(b => {
    b.style.background = 'var(--card)';
    b.style.borderColor = 'var(--card3)';
    b.style.color = 'var(--ink2)';
  });
  e.target.style.background = 'var(--red2)';
  e.target.style.borderColor = 'var(--red2)';
  e.target.style.color = '#fff';
  const serbest = document.getElementById('sorun-serbest');
  if (id === 'diger') serbest.style.display = 'block';
  else serbest.style.display = 'none';
}

async function sorunVakaAc(tohId, kizId) {
  if (!_sorunSecilen) { toast('Sorun türü seçin', true); return; }
  let tani = _sorunSecilen.id === 'diger'
    ? (document.getElementById('sorun-serbest-input')?.value?.trim() || 'Bilinmiyor')
    : _sorunSecilen.tani;

  try {
    let caseId;
    if (kizId) {
      const res = await rpc('kizginlik_vaka_ac', {
        p_kizginlik_id: kizId,
        p_tani: tani,
        p_tohumlama_id: tohId || null,
        p_notlar: 'Tohumlama sırasında tespit edildi'
      });
      caseId = res?.case_id;
    } else {
      _sorunPreFill = { tani, kategori: 'Üreme', notlar: 'Tohumlama sırasında tespit edildi' };
      document.getElementById('sorun-bs')?.remove();
      _sorunBsTemizle();
      openM('m-disease');
      return;
    }

    document.getElementById('sorun-bs')?.remove();
    _sorunBsTemizle();
    toast('🏥 Vaka açıldı');

    await pullTables(['cases','kizginlik_log','tohumlama']);
    renderSafe();

    if (caseId) {
      setTimeout(() => {
        if (typeof openCaseById === 'function') openCaseById(caseId);
      }, 400);
    }
  } catch(e) { toast('❌ ' + e.message, true); }
}

function _sorunBsTemizle() {
  _sorunSecilen = null;
  globalThis._insemSorunVar = false;
  globalThis._insemKizginlikId = null;
}

let _kizginlikSearchTimer=null;
function kizginlikSearch(){
  clearTimeout(_kizginlikSearchTimer);
  _kizginlikSearchTimer=setTimeout(()=>{
    if(typeof loadUreme==='function') loadUreme('kizginlik');
  },250);
}

// Tohumlama arama — 200ms debounce, multi-field (küpe + sperma + sonuç + hayvan adı)
let _tohumlamaSearchTimer=null;
function tohumlamaSearch(){
  clearTimeout(_tohumlamaSearchTimer);
  _tohumlamaSearchTimer=setTimeout(()=>{
    const inp=document.getElementById('tohumlama-srch');
    globalThis._tohSearch = trLower(inp?.value || '').trim();
    if(typeof loadUreme==='function') loadUreme('tohumlama');
  },200);
}
function kizginlikFiltre(deger,btn){
  const onceki=globalThis._kizginlikFilter||'tumu';
  globalThis._kizginlikFilter=onceki===deger?null:deger;
  ['fc-kizginlik-tumu','fc-kizginlik-bekleyen','fc-kizginlik-sonuclanan'].forEach(id=>{
    const b=document.getElementById(id);
    if(b) b.classList.toggle('on',b===btn);
  });
  if(typeof loadUreme==='function') loadUreme('kizginlik');
}

async function _uremeGebelik(el){
  // ── Bekleyen tohumlamalar bölümü ──
  const tumTohlar=await idbGetAll('tohumlama');
  const hayvanlar=getState('animals')||[];

  // Her hayvan için en son tohumlama (tarih azalan)
  const hayvanSonToh={};
  [...tumTohlar]
    .sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''))
    .forEach(t=>{ if(!hayvanSonToh[t.hayvan_id]) hayvanSonToh[t.hayvan_id]=t; });

  const bekleyenler=Object.values(hayvanSonToh)
    .filter(t=>t.sonuc==='Bekliyor')
    .sort((a,b)=>new Date(a.tarih)-new Date(b.tarih));

  let bekleyenHtml='';
  if(bekleyenler.length){
    bekleyenHtml=`<div style="margin-bottom:12px">
      <div style="font-size:.72rem;font-weight:700;color:var(--amber);text-transform:uppercase;letter-spacing:.06em;padding:6px 0 4px">
        ⏳ Sonuç Bekleyen Tohumlamalar (${bekleyenler.length})
      </div>`+
      bekleyenler.map(t=>{
        const h=hayvanlar.find(h2=>h2.id===t.hayvan_id||h2.kupe_no===t.hayvan_id);
        const kupe=h?.kupe_no||h?.devlet_kupe||t.hayvan_id;
        const gun=t.tarih?Math.floor((Date.now()-new Date(t.tarih))/86400000):'?';
        return `<div class="hist-row" style="align-items:center;gap:8px" data-kupe="${escAttr(kupe)}" data-tid="${escAttr(t.id)}">
          <div class="hist-dot" style="background:var(--amber);flex-shrink:0"></div>
          <div class="hist-main" style="flex:1;min-width:0;cursor:pointer" onclick="openDetByKupe(this.closest('[data-kupe]').dataset.kupe)">
            <div class="hist-title" style="color:var(--amber)">${esc(kupe)}</div>
            <div class="hist-sub">${esc(t.sperma||'?')} · ${fmtTarih(t.tarih)} · ${gun} gün</div>
          </div>
          <button style="background:var(--green);color:#fff;white-space:nowrap;flex-shrink:0;padding:2px 5px;font-size:.62rem;min-width:auto;line-height:1.1;border-radius:4px;border:none;cursor:pointer;font-weight:700"
            onclick="gebeAta(this.closest('[data-kupe]').dataset.tid,this.closest('[data-kupe]').dataset.kupe)">Gebe Ata</button>
        </div>`;
      }).join('')+
      `</div>`;
  }

  // ── Mevcut gebe hayvanlar bölümü ──
  const tohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
  tohs.sort((a,b)=>(a.tarih||'').localeCompare(b.tarih||''));

  const gebeHtml=(tohs.length?[...tohs.map(t=>{
    const h=getState('animals').find(a=>a.id===t.hayvan_id);
    const kupe=h?(h.kupe_no||h.devlet_kupe):t.hayvan_id;
    const gun=Math.floor((Date.now()-new Date(t.tarih).getTime())/86400000);
    const ay=Math.floor(gun/30), gKalan=gun%30;
    const dogumTahmini=dFwd(t.tarih,280);
    const kalanGun=Math.floor((new Date(dogumTahmini).getTime()-Date.now())/86400000);
    const gunBilgi=gun>400?`<b style="color:var(--red);font-size:.7rem">⚠️ Geçersiz/çok eski kayıt</b>`:`${ay} ay ${gKalan} gün (${gun}. gün) · Tahmini: ${fmtTarih(dogumTahmini)}`;
    const kalanBilgi=kalanGun<0?`<b style="color:var(--red)">⚠️ ${Math.abs(kalanGun)} gün gecikmiş — doğum kaydı girilmeli</b>`:kalanGun<=14?`<b style="color:var(--red)">⚡ ${kalanGun} gün kaldı!</b>`:`${kalanGun} gün kaldı`;
    return `<div class="hist-row" style="cursor:pointer" onclick="openDet('${t.hayvan_id}')">
      <div class="hist-dot" style="background:${kalanGun<0?'var(--red2)':'var(--green2)'}"></div>
      <div class="hist-main">
        <div class="hist-title" style="color:${kalanGun<0?'var(--red)':'var(--green)'}">🤰 ${esc(kupe)}</div>
        <div class="hist-sub">${gunBilgi}</div>
        <div class="hist-sub">${kalanBilgi}</div>
      </div>
    </div>`;
  })].join('')
  :'<div class="empty"><div class="empty-ico">🤰</div>Gebe hayvan yok</div>');

  el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-insem')">💉 Yeni Tohumlama</button></div>`+
    bekleyenHtml+gebeHtml;
}

async function gebeAta(tohId, kupe){
  openConfirm('Gebe İşaretle',`${kupe} — gebe olarak işaretlensin mi?`,async()=>{
    try {
      await rpc('tohumlama_sonuc_gebe',{p_tohumlama_id:tohId});
      toast('Gebe olarak işaretlendi');
      await pullTables(['hayvanlar','tohumlama','islem_log']);
      renderSafe();
      loadUreme('gebelik');
    } catch(e){
      toast(e.message, true);
    }
  });
}

async function _uremeDogum(el){
  // Yaklasan dogumlar (7+ ay gebe)
  const tohList=(await idbGetAll('tohumlama')).filter(t=>t.sonuc==='Gebe');
  const bugun=new Date();
  const yaklasan=tohList.filter(t=>{
    const gun=Math.floor((bugun-new Date(t.tarih))/86400000);
    return gun>=210;
  }).sort((a,b)=>{
    const ga=Math.floor((bugun-new Date(a.tarih))/86400000);
    const gb=Math.floor((bugun-new Date(b.tarih))/86400000);
    return gb-ga; // en yakin dogum en uste
  });
  const yakHtml=yaklasan.length?`<div style="margin-bottom:14px"><div style="font-weight:800;font-size:.75rem;color:var(--amber);text-transform:uppercase;margin-bottom:8px">🐄 Yaklasan Dogumlar</div>`+
    yaklasan.slice(0,10).map(t=>{
      const an=getState('animals').find(a=>a.id===t.hayvan_id);
      const kupe=an?.kupe_no||an?.devlet_kupe||t.hayvan_id;
      const gun=Math.floor((bugun-new Date(t.tarih))/86400000);
      const kalan=280-gun;
      const renk=kalan<=7?'var(--red)':kalan<=30?'var(--amber)':'var(--green)';
      const bg=kalan<=7?'rgba(192,50,26,.12)':kalan<=30?'rgba(176,120,0,.1)':'rgba(42,122,42,.08)';
      const dogumTahmin=dFwd(t.tarih,280);
      const beslemeUyari=gun>=260?`<span style="background:rgba(176,120,0,.15);color:#b07800;border-radius:4px;padding:1px 6px;font-weight:700;font-size:.7rem;margin-left:4px">⚠️ Anyonik Besleme</span>`:'';
      return `<div class="hist-row" onclick="openDet('${t.hayvan_id}')" style="cursor:pointer">
        <div class="hist-dot" style="background:${renk}"></div>
        <div class="hist-main">
          <div class="hist-title">${esc(kupe)} · ${esc(t.sperma||'?')}${beslemeUyari}</div>
          <div class="hist-sub">🐮 ${fmtTarih(t.tarih)} → Tahmini doğum: <b>${fmtTarih(dogumTahmin)}</b> · <span style="background:${bg};color:${renk};border-radius:4px;padding:1px 6px;font-weight:700;font-size:.7rem">⏳ ${kalan} gun kaldi</span></div>
        </div>
      </div>`;
    }).join('')+'</div>':'';

  // Gecmis dogumlar
  const list=(await idbGetAll('dogum')).sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  const dogHtml=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" data-action="open-birth-modal">🐄 Dogum Kaydet</button></div>`+
    (list.length?list.map(b=>{
      const anne=getState('animals').find(a=>a.id===b.anne_id);
      const anneKupe=anne?.kupe_no||anne?.devlet_kupe||b.anne_id;
      const tip=b.dogum_tipi||'Normal';
      const tipRenk=tip==='Sezaryan'?'#c0321a':tip==='Güç'?'#b07800':'#2a7a2a';
      const tipBg=tip==='Sezaryan'?'rgba(192,50,26,.1)':tip==='Güç'?'rgba(176,120,0,.1)':'rgba(42,122,42,.1)';
      return `<div class="hist-row">
        <div class="hist-dot" style="background:var(--green2)"></div>
        <div class="hist-main">
          <div class="hist-title" style="color:var(--ink2)">
            <span onclick="openDet('${b.anne_id}')" style="cursor:pointer">🐄 ${esc(anneKupe)}</span>
            → <b onclick="openDetByKupe('${b.yavru_kupe}')" style="cursor:pointer;color:var(--blue)">${esc(b.yavru_kupe)}</b> (${esc(b.yavru_cins||'?')})
          </div>
          <div class="hist-sub">${fmtTarih(b.tarih)} · <span style="background:${tipBg};color:${tipRenk};border-radius:4px;padding:1px 6px;font-weight:700;font-size:.7rem">${tip}</span></div>
        </div>
      </div>`;
    }).join(''):'<div class="empty"><div class="empty-ico">🐄</div>Dogum kaydi yok</div>');
  el.innerHTML=yakHtml+dogHtml;
}

async function _uremeTohumlama(el){
  let list=await idbGetAll('tohumlama');
  list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));

  // Searchbar filtresi (multi-field: küpe + sperma + sonuç + hayvan adı)
  const _q=trLower(globalThis._tohSearch||'').trim();
  if(_q){
    const _terms=_q.split(/\s+/).filter(Boolean);
    const _hayvanlar=getState('animals')||[];
    list=list.filter(t=>{
      const h=_hayvanlar.find(a=>a.id===t.hayvan_id);
      const kupe=trLower(h?.kupe_no||h?.devlet_kupe||'');
      const isim=trLower(h?.isim||'');
      const sperma=trLower(t.sperma||'');
      const sonuc=trLower(t.sonuc||'');
      const tarih=trLower(t.tarih||'');
      const haystack=[kupe,isim,sperma,sonuc,tarih].join(' ');
      return _terms.every(term=>haystack.includes(term));
    });
  }

  el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" data-action="open-insem-modal">💉 Tohumlama Ekle</button></div>`+
    (list.length?list.map(t=>{
      const h=getState('animals').find(a=>a.id===t.hayvan_id);
      const kupe=h?.kupe_no||h?.devlet_kupe||t.hayvan_id;
      const _gebe=t.sonuc==='Gebe';
      const _kotu=t.sonuc==='Boş'||t.sonuc==='Abort';
      const _dotMid=_kotu?'var(--red2)':'var(--amber)';
      const dot=_gebe?'var(--green2)':_dotMid;
      const _scMid=_kotu?'var(--red)':'var(--amber)';
      const sc=_gebe?'var(--green)':_scMid;
      const _bekliyor=!_gebe&&!_kotu;
      const _sonucBadge=_kotu?`<span style="background:rgba(192,50,26,.15);color:var(--red);font-size:.72rem;padding:2px 6px;border-radius:8px;font-weight:700;margin-left:4px">${t.sonuc}</span>`:'';
      return `<div class="hist-row" style="cursor:pointer;display:flex;align-items:center;gap:8px" onclick="openTohDet('${t.id}')">
        <div class="hist-dot" style="background:${dot};flex-shrink:0" role="img" aria-label="${t.sonuc||'Bekliyor'}"></div>
        <div class="hist-main" style="flex:1;min-width:0">
          <div class="hist-title" style="color:var(--ink2);display:flex;align-items:center;gap:6px;min-width:0">
            <span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0">${esc(kupe)} — ${esc(t.sperma||'?')}</span>
            <span style="flex-shrink:0;background:rgba(176,120,0,.18);color:#7a4f00;font-size:.78rem;padding:2px 6px;border-radius:8px;font-weight:700">${t.deneme_no||1}. Deneme</span>
          </div>
          <div class="hist-sub" style="font-size:.78rem">${fmtTarih(t.tarih)} · <b style="color:${sc}">${t.sonuc||'Bekliyor'}</b>${_sonucBadge}</div>
        </div>
        ${_bekliyor && t.tarih
          ? (()=>{
              const _uretGun=Math.floor((Date.now()-new Date(t.tarih))/86400000);
              return _uretGun>=0&&_uretGun<=15
                ? `<button data-hid="${escAttr(t.hayvan_id)}" data-kupe="${escAttr(kupe)}" onclick="event.stopPropagation();openTekrarAsim(this.dataset.hid,this.dataset.kupe)" style="flex-shrink:0;background:var(--purple);color:#fff;border:none;border-radius:8px;padding:7px 12px;font-size:.78rem;font-weight:700;cursor:pointer">🔁 Tekrar Aşım</button>`
                : '<span style="flex-shrink:0;font-size:.75rem;color:var(--ink3)">' + _uretGun + ' gün</span>';
            })()
          : (_bekliyor
            ? `<button data-kupe="${escAttr(kupe)}" onclick="event.stopPropagation();tekrarTohumla(this.dataset.kupe)" style="flex-shrink:0;background:var(--green);color:#fff;border:none;border-radius:8px;padding:7px 12px;font-size:.78rem;font-weight:700;cursor:pointer">💉 Tohumla</button>`
            : '')}
      </div>`;
    }).join(''):'<div class="empty"><div class="empty-ico">💉</div>'+(_q?'Arama sonucu yok':'Tohumlama kaydı yok')+'</div>');
}

async function _uremeAbort(el){
  const list=await getData('tohumlama',t=>t.abort===true||t.sonuc==='Abort');
  list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  el.innerHTML=(list.length?list.map(t=>{
    const h=getState('animals').find(a=>a.id===t.hayvan_id);
    const kupe=h?(h.kupe_no||h.devlet_kupe):t.hayvan_id;
    return `<div class="hist-row" style="cursor:pointer" onclick="openDet('${t.hayvan_id}')">
      <div class="hist-dot" style="background:var(--red2)"></div>
      <div class="hist-main">
        <div class="hist-title" style="color:var(--red)">⚠️ ${esc(kupe)} — Abort</div>
        <div class="hist-sub" style="font-size:.78rem">${fmtTarih(t.tarih)} ${t.abort_notlar?'· '+esc(t.abort_notlar):''}</div>
      </div>
    </div>`;
  }).join(''):'<div class="empty"><div class="empty-ico">⚠️</div>Abort kaydı yok</div>');
}

async function loadUreme(tab='kizginlik'){
  _curUremeTab=tab;
  const el=document.getElementById('ureme-body');
  const tb=document.getElementById('kizginlik-toolbar');
  const ttb=document.getElementById('tohumlama-toolbar');
  if(tb&&tab!=='kizginlik') tb.style.display='none';
  if(ttb) ttb.style.display = (tab==='tohumlama') ? 'block' : 'none';
  // Tab değişiminde search state temizle (I1 fix)
  if(tab!=='tohumlama'){
    globalThis._tohSearch='';
    const inp=document.getElementById('tohumlama-srch');
    if(inp) inp.value='';
  }
  await _keepScroll(el,async()=>{
    el.innerHTML='<div class="loader"><div class="spin"></div></div>';
    try {
      if(tab==='kizginlik')      await _uremeKizginlik(el);
      else if(tab==='tohumlama') await _uremeTohumlama(el);
      else if(tab==='gebelik')   await _uremeGebelik(el);
      else if(tab==='dogum')     await _uremeDogum(el);
      else if(tab==='abort')     await _uremeAbort(el);
    } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
  });
}

// ──────────────────────────────────────────
// GEÇMİŞ
// ──────────────────────────────────────────
const _GECMIS_ICO = {dogum:'🐄',tohumlama:'💉',hastalik:'🏥',gorev:'✅',uygulama:'💊',ASI_KAYDI:'💉',ASI_ERTELEME:'⏸️',TOPLU_ILAC:'💊'};
const _GECMIS_BG  = {dogum:'rgba(78,154,42,.1)',tohumlama:'rgba(42,107,181,.1)',hastalik:'rgba(192,50,26,.1)',gorev:'var(--card2)',uygulama:'rgba(120,80,200,.1)',islem:'rgba(120,120,120,.1)',ASI_KAYDI:'rgba(0,160,200,.1)',ASI_ERTELEME:'rgba(120,120,120,.1)',TOPLU_ILAC:'rgba(120,80,200,.1)'};
const _ISLEM_ICO  = {HAYVAN_EKLENDI:'🐮',ABORT_KAYDI:'⚠️',KIZGINLIK_KAYDI:'🔴',ASI_KAYDI:'💉',ASI_ERTELEME:'⏸️',TOPLU_ILAC:'💊'};
const _ISLEM_ETK  = {HAYVAN_EKLENDI:'🐮 Hayvan Eklendi',ABORT_KAYDI:'⚠️ Abort',KIZGINLIK_KAYDI:'🔴 Kızgınlık',ASI_KAYDI:'💉 Aşı Kaydı',ASI_ERTELEME:'⏸️ Aşı Ertelendi',TOPLU_ILAC:'💊 Toplu İlaç'};

function _gecmisEntryHtml(e, overrideOc){
  const {type,date,data}=e;
  const d=date&&date.length>10?fmtTarihSaat(date):fmtTarih(date);
  const hk=HEKIMLER.find(h=>h.id===data.hekim_id);
  const hkName=hk?` · ${hk.ad}`:'';
  const hayvanKey=data.hayvan_id||data.anne_id||data.animal_id;
  const hayvanObj=getState('animals').find(a=>a.id===hayvanKey||a.kupe_no===hayvanKey);
  const hayvanLabel=hayvanObj?.kupe_no||hayvanObj?.devlet_kupe||hayvanKey;
  const ico=_GECMIS_ICO[type]||(_ISLEM_ICO[data.tip]||'📋');
  const icoBg=_GECMIS_BG[type]||'rgba(120,120,120,.1)';
  let oc='',title='',sub='';
  if(type==='hastalik') oc=`onclick="openCaseDet('${data.id}')" style="cursor:pointer"`;
  else if(type==='tohumlama') oc=`onclick="openTohDet('${data.id}')" style="cursor:pointer"`;
  else if(type==='dogum') oc='';
  if(type==='dogum'){
    const anneObj=getState('animals').find(a=>a.id===data.anne_id||a.kupe_no===data.anne_id);
    const anneLabel=anneObj?.kupe_no||anneObj?.devlet_kupe||data.anne_id;
    title=`<span onclick="openDet('${data.anne_id}')" style="cursor:pointer">${esc(anneLabel)||'?'}</span> → <b onclick="openDetByKupe('${data.yavru_kupe}')" style="cursor:pointer;color:var(--blue)">${esc(data.yavru_kupe)||'?'}</b> (${esc(data.yavru_cins||'?')})`;
    sub=`${data.dogum_tipi||'Normal'}${hkName}`;
  } else if(type==='tohumlama'){
    const sc=data.sonuc==='Gebe'?'var(--green)':data.sonuc==='Boş'?'var(--red)':'var(--amber)';
    title=`${esc(hayvanLabel||'?')} — ${esc(data.sperma||'?')}`;
    sub=`${data.deneme_no||1}. Tohumlama · <b style="color:${sc}">${data.sonuc||'Bekliyor'}</b>${hkName}`;
  } else if(type==='hastalik'){
    const sc=data.status==='active'?'var(--red)':'var(--green)';
    title=`${esc(hayvanLabel||'?')} — ${esc(data.disease_name||data.tani||'?')}`;
    sub=`<b style="color:${sc}">${data.status==='active'?'Aktif':'Kapalı'}</b>${hkName}`;
  } else if(type==='gorev'){
    const gHayvan=getState('animals').find(a=>a.id===data.hayvan_id);
    const gLabel=gHayvan?(gHayvan.kupe_no||gHayvan.devlet_kupe):data.hayvan_id;
    const _done=data.tamamlandi;
    const _pill=_done?'<span style="font-size:.6rem;padding:1px 6px;border-radius:8px;background:var(--card3);color:var(--ink3)">Tamamlandı</span>':'<span style="font-size:.6rem;padding:1px 6px;border-radius:8px;background:rgba(42,107,181,.15);color:var(--blue)">Bekliyor</span>';
    if(data.gorev_tipi==='TEDAVI_GUN'){
      const lbl=data._lbl||('Gün '+(data._gunNo||'?')+' tedavisi');
      title=`${esc(gLabel||'?')} — ${lbl}`;
      const drugLine=(data._drugNames||[]).length?`<div style="font-size:.66rem;color:var(--ink2);margin-top:1px">💊 ${esc(data._drugNames.join(', '))}</div>`:'';
      const disLine=data._disName?`<span style="font-size:.62rem;color:var(--ink3)">🏥 ${esc(data._disName)}</span> · `:'';
      sub=`${drugLine}<div style="margin-top:1px">${disLine}${_pill}</div>`;
      if(data._caseId) oc=`onclick="openCaseDet('${data._caseId}')" style="cursor:pointer"`;
    } else {
      let _aLbl='';try{const _p=typeof data.aciklama==='string'?JSON.parse(data.aciklama):data.aciklama;_aLbl=_p?.label||data.aciklama||'';}catch(e){_aLbl=data.aciklama||'';}
      title=`${esc(gLabel||'GENEL')} — ${esc(_aLbl)}`;
      sub=`<span class="pill ${data.gorev_tipi||'DIGER'}">${(data.gorev_tipi||'').replace(/_/g,' ')}</span> · ${_pill}${hkName}`;
      if(data.hayvan_id) oc=`onclick="openDet('${data.hayvan_id}')" style="cursor:pointer"`;
    }
  } else if(type==='uygulama'){
    const uHayvan=getState('animals').find(a=>a.id===data.hayvan_id);
    const uLabel=uHayvan?(uHayvan.kupe_no||uHayvan.devlet_kupe):data.hayvan_id;
    title=`${esc(uLabel||'?')} — ${esc(data._stokAdi||'?')}`;
    sub=`${data.doz||'?'} ${data.birim||'ml'} · ${data.rota||'IM'}${data.notlar?' · '+esc(data.notlar):''}`;
    if(data.hayvan_id) oc=`onclick="openDet('${data.hayvan_id}')" style="cursor:pointer"`;
  } else if(type==='islem'){
    const snap=data.snapshot||{};
    const hayvanObj2=getState('animals').find(a=>a.id===data.ana_hayvan_id);
    const _exitedCache=JSON.parse(localStorage.getItem('ege_exited_kupe')||'{}');
    const kupe=hayvanObj2?.kupe_no||hayvanObj2?.devlet_kupe||snap.kupe_no||snap.devlet_kupe||_exitedCache[data.ana_hayvan_id]||data.ana_hayvan_id||'?';
    title=`${esc(kupe)} — ${_ISLEM_ETK[data.tip]||data.tip}`;
    if(data.tip==='ASI_KAYDI') sub=esc(snap.vaccine_name||'');
    else if(data.tip==='ASI_ERTELEME') sub=esc(snap.erteleme_notu||snap.vaccine_name||'');
    else if(data.tip==='TOPLU_ILAC') sub=esc(snap.ilac_adi||'');
    else sub=esc(snap.irk||snap.grup||'');
    if(snap.kupe_no||snap.devlet_kupe||['ASI_KAYDI','TOPLU_ILAC'].includes(data.tip)) oc=`onclick="openDet('${data.ana_hayvan_id}')" style="cursor:pointer"`;
  }
  if(overrideOc!==undefined) oc=overrideOc;
  return `<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:var(--r2);padding:11px 13px;margin-bottom:6px;display:flex;gap:10px;align-items:flex-start" ${oc}>
    <div style="width:36px;height:36px;border-radius:10px;background:${icoBg};display:flex;align-items:center;justify-content:center;font-size:1.1rem;flex-shrink:0">${ico}</div>
    <div style="flex:1;min-width:0">
      <div style="font-weight:700;font-size:.84rem;color:var(--ink)">${title}</div>
      <div style="font-size:.68rem;color:var(--ink3);margin-top:2px">${sub}</div>
      <div style="font-size:.62rem;color:var(--ink3);margin-top:3px">${type==='gorev'?(data.tamamlandi?'✅ ':'⏳ ')+d:d}</div>
    </div>
  </div>`;
}

function _gecmisSearchText(e){
  const d=e.data, animals=getState('animals');
  const parts=[e.type, fmtTarih(e.date)];
  const pushAnimal=(id)=>{
    if(!id)return;
    const a=animals.find(x=>x.id===id||x.kupe_no===id);
    if(a){parts.push(a.kupe_no||'',a.devlet_kupe||'',a.isim||'');}
    else parts.push(id);
  };
  pushAnimal(d.hayvan_id||d.anne_id||d.animal_id||d.ana_hayvan_id);
  if(e.type==='dogum'){parts.push(d.yavru_kupe||'',d.yavru_cins||'',d.dogum_tipi||'');pushAnimal(d.anne_id);}
  else if(e.type==='tohumlama'){parts.push(d.sperma||'',d.sonuc||'','tohumlama');}
  else if(e.type==='hastalik'){parts.push(d.disease_name||'',d.tani||'',d.status==='active'?'aktif':'kapalı','hastalık',...(d._drugNames||[]));}
  else if(e.type==='gorev'){
    parts.push(d._lbl||'',d.gorev_tipi||'',d._disName||'',d.tamamlandi?'tamamlandı':'bekliyor',...(d._drugNames||[]));
  }
  else if(e.type==='uygulama'){
    parts.push(d._stokAdi||'',d.etken_kod||'',d.birim||'',d.rota||'','hızlı uygulama','ilaç','vitamin');
  }
  else if(e.type==='islem'){
    const snap=d.snapshot||{};
    parts.push(_ISLEM_ETK[d.tip]||d.tip||'',snap.vaccine_name||'',snap.ilac_adi||'',snap.irk||'',snap.kupe_no||'',snap.devlet_kupe||'');
  }
  const hk=HEKIMLER.find(h=>h.id===d.hekim_id);
  if(hk)parts.push(hk.ad);
  return trLower(parts.join(' ')).replace(/\s+/g,' ');
}

let _gecmisAllEntries=[];
function _gecmisRender(q){
  const el=document.getElementById('gecmis-body');
  let list=_gecmisAllEntries;
  if(q){
    const terms=q.toLowerCase().trim().split(/\s+/).filter(Boolean);
    if(terms.length) list=list.filter(e=>terms.every(t=>e._s.includes(t)));
  }
  if(!list.length){el.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Kayıt bulunamadı</div>';return;}
  const countHint=q&&list.length<_gecmisAllEntries.length?`<div style="font-size:.65rem;color:var(--ink3);margin-bottom:6px;padding:0 2px">${list.length} / ${_gecmisAllEntries.length} sonuç</div>`:'';
  el.innerHTML=countHint+list.slice(0,300).map(e=>_gecmisEntryHtml(e)).join('');
}

async function loadGecmis(f,btn){
  _curGecmisFilter=f;
  if(btn){ document.querySelectorAll('#pg-gecmis .fs-btn').forEach(b=>b.classList.remove('on')); btn.classList.add('on'); }
  const el=document.getElementById('gecmis-body');
  await _keepScroll(el,async()=>{
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const entries=[];
    if(f==='hepsi'||f==='dogum')
      (await idbGetAll('dogum')).forEach(r=>entries.push({type:'dogum',date:r.tarih,sortKey:r.created_at||r.tarih||'',data:r}));
    if(f==='hepsi'||f==='tohumlama')
      (await idbGetAll('tohumlama')).forEach(r=>entries.push({type:'tohumlama',date:r.tarih,sortKey:r.created_at||r.tarih||'',data:r}));
    if(f==='hepsi'||f==='hastalik') {
      const _dis = await idbGetAll('diseases');
      const _hTdays=await idbGetAll('treatment_days').catch(()=>[]);
      const _hDadm=await idbGetAll('drug_administrations').catch(()=>[]);
      const _hStok=await idbGetAll('stok').catch(()=>[]);
      const _hStokById=Object.fromEntries(_hStok.map(s=>[s.id,s.urun_adi||'']));
      const _hProdById=Object.fromEntries((await idbGetAll('drug_products').catch(()=>[])).map(p=>[p.id,p.brand_name||'']));
      const _hDrugsByCase={};
      const _hDayCase=Object.fromEntries(_hTdays.map(td=>[td.id,td.case_id]));
      _hDadm.forEach(da=>{
        const cid=_hDayCase[da.treatment_day_id];
        if(!cid)return;
        const name=_hProdById[da.drug_product_id]||_hStokById[da.stok_id]||'';
        if(name){
          if(!_hDrugsByCase[cid])_hDrugsByCase[cid]=new Set();
          _hDrugsByCase[cid].add(name);
        }
      });
      (await idbGetAll('cases')).forEach(r=>{
        const _d = _dis.find(d=>d.id===r.disease_id);
        const _drugNames=[...(_hDrugsByCase[r.id]||[])];
        entries.push({type:'hastalik',date:r.start_date,sortKey:r.created_at||r.start_date||'',data:{...r,disease_name:_d?.name||'?',tani:_d?.name||'?',_drugNames}});
      });
    }
    if(f==='hepsi'||f==='gorev'){
      const _allDrugs=await idbGetAll('drug_administrations').catch(()=>[]);
      const _allStok=await idbGetAll('stok').catch(()=>[]);
      const _stokById=Object.fromEntries(_allStok.map(s=>[s.id,s.urun_adi||'']));
      const _prodById=Object.fromEntries((await idbGetAll('drug_products').catch(()=>[])).map(p=>[p.id,p.brand_name||'']));
      const _drugsByDay={};
      _allDrugs.forEach(da=>{
        if(!da.treatment_day_id)return;
        const name=_prodById[da.drug_product_id]||_stokById[da.stok_id]||'';
        if(name)(_drugsByDay[da.treatment_day_id]=_drugsByDay[da.treatment_day_id]||[]).push(name);
      });
      const _tDays=await idbGetAll('treatment_days').catch(()=>[]);
      const _tDayById=Object.fromEntries(_tDays.map(td=>[td.id,td]));
      const _cases=await idbGetAll('cases').catch(()=>[]);
      const _caseById=Object.fromEntries(_cases.map(c=>[c.id,c]));
      const _dis=await idbGetAll('diseases').catch(()=>[]);
      const _disById=Object.fromEntries(_dis.map(d=>[d.id,d.name||'']));
      (await getData('gorev_log',t=>(_gecmisTumu||t.tamamlandi)&&(_gecmisTumu||!t.parent_id))).forEach(r=>{
        let dayId=null,_lbl='',_gunNo='';
        try{const p=typeof r.aciklama==='string'?JSON.parse(r.aciklama):r.aciklama;dayId=p?.day_id;_lbl=p?.label||'';_gunNo=p?.gun_no||'';}catch(e){}
        const _drugNames=(dayId&&_drugsByDay[dayId])||[];
        const _td=dayId&&_tDayById[dayId];
        const _cs=_td&&_caseById[_td.case_id];
        const _disName=_cs&&_disById[_cs.disease_id]||'';
        const _caseId=_cs?.id||'';
        entries.push({type:'gorev',date:(r.tamamlanma_tarihi||r.hedef_tarih||'').slice(0,10),sortKey:r.tamamlanma_tarihi||r.hedef_tarih||'',data:{...r,_drugNames,_lbl,_gunNo,_disName,_caseId}});
      });
    }
    if(f==='hepsi'||f==='gorev'){
      const _uyStok=await idbGetAll('stok').catch(()=>[]);
      const _uyStokById=Object.fromEntries(_uyStok.map(s=>[s.id,s.urun_adi||'']));
      (await idbGetAll('uygulama_log').catch(()=>[])).forEach(r=>{
        entries.push({type:'uygulama',date:(r.tarih||r.created_at||'').slice(0,10),sortKey:r.created_at||r.tarih||'',data:{...r,_stokAdi:_uyStokById[r.stok_id]||'?'}});
      });
    }
    if(f==='hepsi'||f==='hayvan'){
      const islemTipler=['HAYVAN_EKLENDI','ABORT_KAYDI','KIZGINLIK_KAYDI','ASI_KAYDI','TOPLU_ILAC'];
      (await idbGetAll('islem_log'))
        .filter(r=>islemTipler.includes(r.tip))
        .forEach(r=>entries.push({type:'islem',date:(r.tarih||r.created_at||'').slice(0,10),sortKey:r.tarih||r.created_at||'',data:r}));
    }
    entries.sort((a,b)=>(b.sortKey||b.date||'').localeCompare(a.sortKey||a.date||''));
    entries.forEach(e=>e._s=_gecmisSearchText(e));
    _gecmisAllEntries=entries;
    const q=(document.getElementById('gecmis-search')||{}).value||'';
    _gecmisRender(q);
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
  });
}

// ──────────────────────────────────────────
// STOK — helpers
// ──────────────────────────────────────────
function _durumClr(d){ if(d==='neg')return'var(--red)'; if(d==='crit')return'var(--amber)'; return'var(--green)'; }
function _durumTxt(d){ if(d==='neg')return'🆘 Negatif'; if(d==='crit')return'⚠️ Kritik'; return'✅ Normal'; }

// ──────────────────────────────────────────
async function loadStock(){
  try {
    const [stk,vacs]=await Promise.all([idbGetAll('stok'),idbGetAll('vaccines')]);
    const stockData=stk.map(s=>{ const guncel=+(s.guncel_stok??s.baslangic_miktar??0); const durum=s.stok_durum==='tukendi'?'neg':s.stok_durum==='kritik'?'crit':'ok'; const isVaccine=(s.id||'').startsWith('STOK-AŞI-')||(vacs||[]).some(v=>v.stock_item_id===s.id); return{...s,guncel,durum,isVaccine}; });
    setState('stock', stockData);
  } catch(e){ console.error(e); }
}
function openStk(id){
  setState('curStok', getState('stock').find(s=>s.id===id)||null);
  const curStk=getState('curStok'); if(!curStk) return;
  document.getElementById('m-stk-title').textContent='📦 '+curStk.urun_adi;
  document.getElementById('se-urun').value=curStk.urun_adi;
  document.getElementById('se-birim').textContent=curStk.birim||'?';
  g('se-mik').value=''; g('se-not').value='';
  openM('m-stk');
}
async function stokDrugBagla(stokId, sel) {
  const drugId = sel.value || null;
  try {
    // B30: bağlantı KALDIRMA (drugId=null) eskiden p_drug_id:null gönderiyordu —
    // RPC'de WHERE id IS NULL → her zaman 'İlaç bulunamadı'. Kaldırma, bu
    // stoka bağlı ilacın id'siyle yapılır (drugs.stock_item_id üzerinden).
    let hedefDrugId = drugId;
    if (!hedefDrugId) {
      const drugs = await getData('drugs');
      hedefDrugId = drugs.find(d => d.stock_item_id === stokId)?.id || null;
      if (!hedefDrugId) { toast('Bu stoka bağlı ilaç bulunamadı — kaldırılacak bağlantı yok', true); return; }
    }
    // RPC: link_drug_to_stock artık drugs tablosunu düzgün güncelliyor
    // Ek batch update'e gerek yok, çünkü RPC içinde tek bir UPDATE yapılıyor
    await rpc('link_drug_to_stock', { p_drug_id: hedefDrugId, p_stock_item_id: drugId ? stokId : null });
    toast('✅ Bağlantı kaydedildi');
    _drugsCache = [];
    await loadDrugsCache();
    loadStokPanel();
  } catch(e) { toast(e.message, true); }
}

async function openStokAdd() {
  openM('m-stok-add');
  await saTipSec('ilac');
}
async function saTipSec(tip) {
  ['ilac','sperma','ekipman'].forEach(t => {
    const btn = document.getElementById('sa-tip-'+t);
    if (!btn) return;
    if (t === tip) {
      btn.style.border = '2px solid var(--green)';
      btn.style.background = 'rgba(78,154,42,.12)';
      btn.style.color = 'var(--green)';
    } else {
      btn.style.border = '1.5px solid var(--card3)';
      btn.style.background = 'var(--card)';
      btn.style.color = 'var(--ink3)';
    }
  });
  const ilacAl  = document.getElementById('sa-ilac-alani');
  const digerAl = document.getElementById('sa-diger-alani');
  const title   = document.getElementById('sa-modal-title');
  const katInp  = document.getElementById('sa-kat');
  if (tip === 'ilac') {
    ilacAl.style.display  = 'block';
    digerAl.style.display = 'none';
    title.textContent = '💊 Yeni İlaç Ekle';
    katInp.value = 'Antibiyotik';
    // Etken madde dropdown'ı doldur — önce pull et
    if (navigator.onLine) await pullTables(['drug_classes','stok_kategorileri']);
    const drugClasses = await idbGetAll('drug_classes');
    const sel = document.getElementById('sa-etken');
    if (sel) {
      if (!drugClasses.length) {
          sel.innerHTML = '<option value="">⚠️ Yüklenemedi</option>';
          // DEBUG: Supabase direkt kontrol
          try {
            db.from('drug_classes').select('id').limit(1).then(({data,error}) => {
              sel.innerHTML = error
                ? '<option value="">❌ SB hata: ' + error.message + '</option>'
                : (data && data.length
                    ? '<option value="">✅ SB var ama IDB boş — yenile</option>'
                    : '<option value="">⚠️ SB de boş</option>');
            });
          } catch(e) { sel.innerHTML = '<option value="">❌ ' + e.message + '</option>'; }
      } else {
        const grouped = {};
        drugClasses.forEach(dc => {
          if (!grouped[dc.group_name]) grouped[dc.group_name] = [];
          grouped[dc.group_name].push(dc);
        });
        sel.innerHTML = '<option value="">— Etken madde seçin (zorunlu) —</option>' +
          Object.entries(grouped).sort(([a],[b])=>a.localeCompare(b,'tr',{sensitivity:'base'})).map(([grp, list]) =>
            `<optgroup label="${grp}">${list.map(dc =>
              `<option value="${dc.id}" data-group="${dc.group_name}">${dc.class_name ? dc.class_name+' › ' : ''}${dc.active_ingredient}</option>`
            ).join('')}</optgroup>`
          ).join('');
        const allKats = await idbGetAll('stok_kategorileri');
        sel.onchange = () => {
          const opt = sel.selectedOptions[0];
          if (!katInp || !opt || !opt.value) return;
          const dc = drugClasses.find(c => c.id === opt.value);
          if (dc && dc.kategori_id) {
            const kat = (allKats||[]).find(k => k.id === dc.kategori_id);
            if (kat) { katInp.value = kat.ad; return; }
          }
          katInp.value = 'Diğer İlaç';
        };
      }
    }
  } else if (tip === 'sperma') {
    ilacAl.style.display  = 'none';
    digerAl.style.display = 'block';
    title.textContent = '💉 Yeni Sperma Ekle';
    document.getElementById('sa-ad-lbl').textContent = 'Boğa Kodu / Adı *';
    document.getElementById('sa-ad-diger').placeholder = 'Örn: Darius, ABK-Zenith';
    katInp.value = 'Sperma';
    document.getElementById('sa-birim').value = 'adet';
  } else {
    ilacAl.style.display  = 'none';
    digerAl.style.display = 'block';
    title.textContent = '🔧 Yeni Ekipman / Sarf Ekle';
    document.getElementById('sa-ad-lbl').textContent = 'Ürün Adı *';
    document.getElementById('sa-ad-diger').placeholder = 'Şırınga, Sonda, Buzağı Ceketi…';
    katInp.value = 'Ekipman';
  }
  document.getElementById('sa-ad-diger')?.focus();
}
function openStokPanel(){
  document.getElementById('stok-panel').style.transform='translateX(0)';
  loadStokPanel();
}
function closeStokPanel(){
  document.getElementById('stok-panel').style.transform='translateX(100%)';
}
function setStokTab(tab,e){
  _stokTab=tab;
  document.querySelectorAll('#stok-tabs .kat-btn').forEach(b=>b.classList.remove('on'));
  if(e&&e.target) e.target.classList.add('on');
  loadStokPanel();
}

/* ═══ TANIMLAR PANELİ ═══ */
function openTanimlarPanel(){
  document.getElementById('tanimlar-panel').style.transform='translateX(0)';
  loadTanimlarPanel();
}
function closeTanimlarPanel(){
  document.getElementById('tanimlar-panel').style.transform='translateX(100%)';
}
function setTanimlarTab(tab,e){
  _tanimlarTab=tab;
  document.querySelectorAll('#tanimlar-tabs .kat-btn').forEach(b=>b.classList.remove('on'));
  if(e&&e.target) e.target.classList.add('on');
  loadTanimlarPanel();
}

async function loadTanimlarPanel(){
  const el=document.getElementById('tanimlar-panel-body'); if(!el) return;
  await _keepScroll(el,async()=>{
    _ilacKatAdlari=null;
    if(_tanimlarTab==='hastaliklar') await _renderHastaliklar(el);
    else if(_tanimlarTab==='ilaclar') await _renderIlacSiniflari(el);
    else if(_tanimlarTab==='kategoriler') await _renderKategoriler(el);
    else if(_tanimlarTab==='sablonlar')   await _renderSablonlar(el);
  });
}

function _tanimSearchBar(){
  return `<input type="text" id="tanim-search" placeholder="🔍 Ara…" oninput="_tanimFiltrele(this.value)" style="width:100%;padding:9px 12px;border:1px solid var(--card3);border-radius:8px;margin-bottom:10px;font-size:.82rem;background:var(--card2);color:var(--ink);box-sizing:border-box">`;
}
function _tanimFiltrele(q){
  const s=q.toLowerCase().trim();
  document.querySelectorAll('.tanimlar-card').forEach(c=>{
    const txt=(c.getAttribute('data-search')||'').toLowerCase();
    c.style.display=!s||txt.includes(s)?'':'none';
  });
  document.querySelectorAll('.tanim-grup').forEach(g=>{
    const visible=g.querySelectorAll('.tanimlar-card:not([style*="display: none"])').length;
    const badge=g.querySelector('.tanim-grup-count');
    if(badge) badge.textContent=visible;
    g.style.display=visible||!s?'':'none';
  });
}

async function _renderHastaliklar(el){
  await pullTables(['diseases','cases']);
  const diseases=await idbGetAll('diseases');
  const cases=await idbGetAll('cases');
  if(!diseases.length){
    el.innerHTML='<div class="empty"><div class="empty-ico">🏥</div>Henüz hastalık tanımı yok</div>'+_tanimVarsayilanBtn('diseases');
    return;
  }
  const KAT_RENK={Meme:'#e91e63',Üreme:'#9c27b0',Metabolik:'#ff9800',Ayak:'#795548',Solunum:'#2196f3',Sindirim:'#4caf50',Buzağı:'#00bcd4',Diğer:'#607d8b'};
  const KAT_SIRA=['Meme','Üreme','Metabolik','Ayak','Solunum','Sindirim','Buzağı','Diğer'];
  const grouped={};
  diseases.forEach(d=>{const k=d.category||'Diğer';if(!grouped[k])grouped[k]=[];grouped[k].push(d);});
  let html=_tanimSearchBar();
  KAT_SIRA.forEach(kat=>{
    const items=grouped[kat];if(!items||!items.length)return;
    const renk=KAT_RENK[kat]||'#607d8b';
    const katAktif=items.reduce((n,d)=>n+cases.filter(c=>c.disease_id===d.id&&c.status==='active').length,0);
    html+=`<div class="tanim-grup" style="margin-bottom:6px">
      <div onclick="this.nextElementSibling.style.display=this.nextElementSibling.style.display==='none'?'block':'none';this.querySelector('.tanim-chev').classList.toggle('tanim-chev-open')" style="display:flex;align-items:center;gap:8px;padding:9px 10px;background:${renk}15;border:1px solid ${renk}30;border-radius:8px;cursor:pointer;user-select:none">
        <span style="width:4px;height:22px;border-radius:2px;background:${renk};flex-shrink:0"></span>
        <span style="font-weight:800;font-size:.82rem;color:${renk};flex:1">${kat}</span>
        ${katAktif?`<span style="background:${renk}22;color:${renk};padding:1px 6px;border-radius:4px;font-size:.6rem;font-weight:700">${katAktif} aktif</span>`:''}
        <span class="tanim-grup-count" style="background:var(--card3);color:var(--ink3);padding:1px 7px;border-radius:10px;font-size:.65rem;font-weight:700">${items.length}</span>
        <svg class="tanim-chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="${renk}" stroke-width="2.5" style="transition:transform .2s;flex-shrink:0"><path d="M6 9l6 6 6-6"/></svg>
      </div>
      <div style="display:none;padding:4px 0 0 0">`;
    items.forEach(d=>{
      const aktif=cases.filter(c=>c.disease_id===d.id&&c.status==='active').length;
      const kapali=cases.filter(c=>c.disease_id===d.id&&c.status==='closed').length;
      const toplam=aktif+kapali;
      html+=`<div class="tanimlar-card" data-search="${esc(d.name)} ${kat}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${renk};border-radius:8px;padding:9px 11px;margin:4px 0 0 12px">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <div>
            <div style="font-weight:700;font-size:.84rem;color:var(--ink)">${esc(d.name)}</div>
            ${toplam?`<div style="font-size:.6rem;color:var(--ink3);margin-top:1px">${toplam} vaka${aktif?' ('+aktif+' aktif)':''}</div>`:''}
          </div>
          <button onclick="_tanimEditForm('disease','${d.id}')" style="padding:5px 9px;background:var(--card2);border:none;border-radius:6px;font-size:.7rem;font-weight:700;cursor:pointer;color:var(--ink3)">Düzenle</button>
        </div>
        <div id="tdf-disease-${d.id}"></div>
      </div>`;
    });
    html+=`</div></div>`;
  });
  html+=`<button onclick="_tanimEditForm('disease','new')" style="width:100%;padding:13px;background:rgba(78,154,42,.12);border:2px dashed rgba(78,154,42,.4);border-radius:10px;color:var(--green);font-size:.88rem;font-weight:800;cursor:pointer;margin-top:8px">＋ Yeni Hastalık Ekle</button>`;
  html+=_tanimVarsayilanBtn('diseases');
  el.innerHTML=html;
}

function _tanimVarsayilanBtn(tip){
  return `<div style="text-align:center;margin-top:14px">
    <button onclick="_tanimVarsayilan('${tip}')" style="background:none;border:none;color:var(--ink3);font-size:.72rem;cursor:pointer;text-decoration:underline">🔄 Varsayılana Dön</button>
  </div>`;
}

function _tanimEditForm(tip, id){
  document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove());
  if(tip==='disease') _diseaseEditForm(id);
  else if(tip==='kategori') _kategoriEditForm(id);
}

async function _diseaseEditForm(id){
  const isNew=id==='new';
  let name='',category='';
  if(!isNew){
    const all=await idbGetAll('diseases');
    const d=all.find(x=>x.id===id);
    if(d){name=d.name;category=d.category||'';}
  }
  const KATS=['Meme','Üreme','Metabolik','Ayak','Solunum','Sindirim','Buzağı','Diğer'];
  const katOpts=KATS.map(k=>`<option ${k===category?'selected':''} value="${k}">${k}</option>`).join('');
  const formHtml=`<div class="tanim-edit-form" style="background:rgba(42,107,181,.06);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:10px;margin-top:6px">
    <div style="margin-bottom:6px"><input id="tef-disease-name" class="fi" value="${esc(name)}" placeholder="Hastalık adı" style="margin:0"></div>
    <div style="margin-bottom:8px"><select id="tef-disease-cat" class="fsel" style="margin:0"><option value="">Kategori seç…</option>${katOpts}</select></div>
    <div style="display:flex;gap:6px">
      <button onclick="_diseaseSave('${id}')" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px;font-weight:700;cursor:pointer">${isNew?'Ekle':'Kaydet'}</button>
      ${isNew?'':`<button onclick="_diseaseDelete('${id}')" style="padding:8px 12px;background:#ffebee;color:#c62828;border:none;border-radius:7px;font-weight:700;cursor:pointer">Sil</button>`}
      <button onclick="document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove())" style="padding:8px 12px;background:var(--card3);border:none;border-radius:7px;cursor:pointer">İptal</button>
    </div>
  </div>`;
  if(isNew){
    const btn=document.querySelector('#tanimlar-panel-body button[onclick*="disease"][onclick*="new"]');
    if(btn) btn.insertAdjacentHTML('beforebegin',formHtml);
  } else {
    const wrap=document.getElementById('tdf-disease-'+id);
    if(wrap) wrap.innerHTML=formHtml;
  }
}

async function _diseaseSave(id){
  const name=document.getElementById('tef-disease-name')?.value.trim();
  const cat=document.getElementById('tef-disease-cat')?.value;
  if(!name){toast('Hastalık adı zorunlu','warn');return;}
  if(!cat){toast('Kategori seçin','warn');return;}
  const isNew=id==='new';
  await rpcOptimistic(isNew?'disease_ekle':'disease_guncelle',
    isNew?{p_name:name,p_category:cat}:{p_id:id,p_name:name,p_category:cat});
  loadTanimlarPanel();
}

async function _diseaseDelete(id){
  if(!confirm('Bu hastalığı silmek istediğinize emin misiniz?')) return;
  await rpcOptimistic('disease_sil',{p_id:id});
  toast('Hastalık silindi');
  loadTanimlarPanel();
}

async function _tanimVarsayilan(tip){
  if(tip==='drug_classes'){
    const a=Math.floor(Math.random()*10)+1;
    const b=Math.floor(Math.random()*10)+1;
    const ans=prompt(`Varsayılan sistem düzenine dönülecek. Eksik varsayılanlar eklenecektir.\n\nDevam etmek için ${a} + ${b} = ? yazın:`);
    if(parseInt(ans)!==(a+b)){toast('Yanlış cevap — işlem iptal','warn');return;}
    const res=await rpcOptimistic('drug_class_varsayilan_yukle',{});
    toast(`${res.eklenen||0} yeni ilaç sınıfı eklendi`);
    loadTanimlarPanel();
    return;
  }
  const labels={diseases:'hastalık',drugs:'ilaç',kategoriler:'kategori'};
  if(!confirm(`Standart ${labels[tip]||tip} tanımları geri yüklenecek. Mevcut özel tanımlarınız silinmez. Devam?`)) return;
  const res=await rpcOptimistic('seed_defaults',{p_tip:tip});
  toast(`${res.eklenen||0} yeni ${labels[tip]} eklendi`);
  loadTanimlarPanel();
}

async function _renderIlacSiniflari(el){
  await pullTables(['drug_classes','drug_products','stok_kategorileri']);
  const allDC=await idbGetAll('drug_classes');
  const allDP=await idbGetAll('drug_products');

  if(!allDC.length){
    el.innerHTML='<div class="empty"><div class="empty-ico">💊</div>Henüz ilaç sınıfı tanımı yok</div>'+_tanimVarsayilanBtn('drug_classes');
    return;
  }

  const GRP_RENK={'Antimikrobiyaller (Antibiyotikler)':'#2196f3','Anti-inflamatuar İlaçlar':'#e91e63','Hormonlar ve Üreme İlaçları':'#9c27b0','Antiparaziter İlaçlar':'#ff9800','Vitaminler ve Mineraller':'#4caf50','Metabolik / Sıvı Tedavi':'#00bcd4','Gastrointestinal İlaçlar':'#795548','Topikal / Harici İlaçlar':'#607d8b','Anestezik / Sedatif':'#f44336'};

  const tree={};
  const placeholders=[];
  allDC.forEach(dc=>{
    const g=dc.group_name||'Diğer';
    const c=dc.class_name||'Genel';
    if(!tree[g]) tree[g]={};
    if(!tree[g][c]) tree[g][c]=[];
    if(dc.active_ingredient==='(tanımsız)'){placeholders.push(dc);return;}
    tree[g][c].push(dc);
  });
  // placeholder'ları sadece o grp+cls'de başka madde yoksa göster
  placeholders.forEach(dc=>{
    const g=dc.group_name||'Diğer';
    const c=dc.class_name||'Genel';
    if(!tree[g]) tree[g]={};
    if(!tree[g][c]) tree[g][c]=[];
    if(!tree[g][c].length) tree[g][c].push(dc);
  });

  const dpCount={};
  allDP.forEach(dp=>{dpCount[dp.drug_class_id]=(dpCount[dp.drug_class_id]||0)+1;});

  let html=_tanimSearchBar();
  const gruplar=Object.keys(tree).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'}));

  gruplar.forEach(grp=>{
    const renk=GRP_RENK[grp]||'#607d8b';
    const altGruplar=tree[grp];
    const toplamMadde=Object.values(altGruplar).reduce((s,arr)=>s+arr.length,0);

    html+=`<div class="tanim-grup" style="margin-bottom:6px">
      <div onclick="this.nextElementSibling.style.display=this.nextElementSibling.style.display==='none'?'block':'none';this.querySelector('.tanim-chev').classList.toggle('tanim-chev-open')" style="display:flex;align-items:center;gap:8px;padding:9px 10px;background:${renk}15;border:1px solid ${renk}30;border-radius:8px;cursor:pointer;user-select:none">
        <span style="width:4px;height:22px;border-radius:2px;background:${renk};flex-shrink:0"></span>
        <span style="font-weight:800;font-size:.82rem;color:${renk};flex:1">${esc(grp)}</span>
        <span class="tanim-grup-count" style="background:var(--card3);color:var(--ink3);padding:1px 7px;border-radius:10px;font-size:.65rem;font-weight:700">${toplamMadde}</span>
        <button data-grp="${escAttr(grp)}" onclick="event.stopPropagation();_dcEditInline('group',this.dataset.grp,null)" style="padding:2px 6px;background:none;border:none;cursor:pointer;font-size:.7rem" title="Düzenle">✏️</button>
        <button data-grp="${escAttr(grp)}" onclick="event.stopPropagation();_dcDeleteGroup(this.dataset.grp)" style="padding:2px 6px;background:none;border:none;cursor:pointer;font-size:.7rem" title="Sil">🗑</button>
        <svg class="tanim-chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="${renk}" stroke-width="2.5" style="transition:transform .2s;flex-shrink:0"><path d="M6 9l6 6 6-6"/></svg>
      </div>
      <div style="display:none;padding:4px 0 0 0">`;

    Object.keys(altGruplar).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'})).forEach(cls=>{
      const maddeler=altGruplar[cls];
      html+=`<div style="margin:4px 0 0 12px">
        <div onclick="const n=this.nextElementSibling;n.style.display=n.style.display==='none'?'block':'none';this.querySelector('.tanim-chev').classList.toggle('tanim-chev-open')" style="display:flex;align-items:center;gap:6px;padding:6px 8px;background:var(--card2);border-radius:6px;cursor:pointer;user-select:none">
          <span style="width:3px;height:16px;border-radius:2px;background:${renk}60;flex-shrink:0"></span>
          <span style="font-weight:700;font-size:.78rem;color:var(--ink);flex:1">${esc(cls)}</span>
          <span style="font-size:.6rem;color:var(--ink3)">${maddeler.length}</span>
          <button data-grp="${escAttr(grp)}" data-cls="${escAttr(cls)}" onclick="event.stopPropagation();_dcEditInline('class',this.dataset.grp,this.dataset.cls)" style="padding:2px 4px;background:none;border:none;cursor:pointer;font-size:.65rem" title="Düzenle">✏️</button>
          <button data-grp="${escAttr(grp)}" data-cls="${escAttr(cls)}" onclick="event.stopPropagation();_dcDeleteClass(this.dataset.grp,this.dataset.cls)" style="padding:2px 4px;background:none;border:none;cursor:pointer;font-size:.65rem" title="Sil">🗑</button>
          <svg class="tanim-chev" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--ink3)" stroke-width="2.5" style="transition:transform .2s;flex-shrink:0"><path d="M6 9l6 6 6-6"/></svg>
        </div>
        <div style="display:none;padding:2px 0 0 0">`;

      maddeler.forEach(dc=>{
        const dpBadge=dpCount[dc.id]?`<span style="background:rgba(78,154,42,.15);color:var(--green);padding:1px 5px;border-radius:4px;font-size:.58rem;font-weight:700">📦 ${dpCount[dc.id]}</span>`:'';
        html+=`<div class="tanimlar-card" data-search="${esc(dc.active_ingredient)} ${esc(grp)} ${esc(cls)}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${renk};border-radius:6px;padding:7px 10px;margin:3px 0 0 20px">
          <div style="display:flex;justify-content:space-between;align-items:center">
            <div>
              <span style="font-weight:700;font-size:.8rem;color:var(--ink)">${esc(dc.active_ingredient)}</span>
              ${dpBadge}
            </div>
            <div style="display:flex;gap:2px">
              <button onclick="_dcEditIngredient('${dc.id}')" style="padding:3px 6px;background:var(--card2);border:none;border-radius:5px;font-size:.65rem;cursor:pointer" title="Düzenle">✏️</button>
              <button onclick="_dcDeleteIngredient('${dc.id}')" style="padding:3px 6px;background:var(--card2);border:none;border-radius:5px;font-size:.65rem;cursor:pointer" title="Sil">🗑</button>
            </div>
          </div>
        </div>`;
      });

      html+=`<button data-grp="${escAttr(grp)}" data-cls="${escAttr(cls)}" onclick="_dcAddIngredient(this.dataset.grp,this.dataset.cls)" style="display:block;width:calc(100% - 20px);margin:3px 0 0 20px;padding:6px;background:none;border:1px dashed var(--card3);border-radius:5px;color:var(--ink3);font-size:.7rem;cursor:pointer;text-align:left">＋ Etken Madde Ekle</button>`;
      html+=`</div></div>`;
    });

    html+=`<button data-grp="${escAttr(grp)}" onclick="_dcAddClass(this.dataset.grp)" style="display:block;width:calc(100% - 12px);margin:4px 0 0 12px;padding:6px;background:none;border:1px dashed var(--card3);border-radius:5px;color:var(--ink3);font-size:.7rem;cursor:pointer;text-align:left">＋ Alt Grup Ekle</button>`;
    html+=`</div></div>`;
  });

  html+=`<button onclick="_dcAddGroup()" style="width:100%;padding:13px;background:rgba(78,154,42,.12);border:2px dashed rgba(78,154,42,.4);border-radius:10px;color:var(--green);font-size:.88rem;font-weight:800;cursor:pointer;margin-top:8px">＋ Yeni Grup Ekle</button>`;
  html+=_tanimVarsayilanBtn('drug_classes');
  el.innerHTML=html;
}

// ── drug_class inline CRUD ──

async function _dcAddGroup(){
  const name=prompt('Yeni grup adı:');
  if(!name||!name.trim()) return;
  try{
    await rpcOptimistic('drug_class_ekle',{p_group_name:name.trim(),p_class_name:'Genel',p_active_ingredient:'(tanımsız)'});
    toast('Grup eklendi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

async function _dcAddClass(grp){
  const name=prompt('Yeni alt grup adı:');
  if(!name||!name.trim()) return;
  try{
    await rpcOptimistic('drug_class_ekle',{p_group_name:grp,p_class_name:name.trim(),p_active_ingredient:'(tanımsız)'});
    toast('Alt grup eklendi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

async function _dcAddIngredient(grp,cls){
  const name=prompt('Yeni etken madde adı:');
  if(!name||!name.trim()) return;
  try{
    const allDC=await idbGetAll('drug_classes');
    const sameGrp=allDC.find(dc=>dc.group_name===grp);
    const katId=sameGrp?sameGrp.kategori_id:null;
    await rpcOptimistic('drug_class_ekle',{p_group_name:grp,p_class_name:cls,p_active_ingredient:name.trim(),p_kategori_id:katId});
    const placeholder=allDC.find(dc=>dc.group_name===grp&&dc.class_name===cls&&dc.active_ingredient==='(tanımsız)');
    if(placeholder) await rpcOptimistic('drug_class_sil',{p_id:placeholder.id});
    toast('Etken madde eklendi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

async function _dcEditInline(level,grp,cls){
  if(level==='group'){
    const newName=prompt('Grup adını düzenle:',grp);
    if(!newName||!newName.trim()||newName.trim()===grp) return;
    const allDC=await idbGetAll('drug_classes');
    const targets=allDC.filter(dc=>dc.group_name===grp);
    for(const dc of targets){
      await rpcOptimistic('drug_class_guncelle',{p_id:dc.id,p_group_name:newName.trim()});
    }
    toast('Grup güncellendi');
    loadTanimlarPanel();
  } else if(level==='class'){
    const newName=prompt('Alt grup adını düzenle:',cls);
    if(!newName||!newName.trim()||newName.trim()===cls) return;
    const allDC=await idbGetAll('drug_classes');
    const targets=allDC.filter(dc=>dc.group_name===grp&&dc.class_name===cls);
    for(const dc of targets){
      await rpcOptimistic('drug_class_guncelle',{p_id:dc.id,p_class_name:newName.trim()});
    }
    toast('Alt grup güncellendi');
    loadTanimlarPanel();
  }
}

async function _dcEditIngredient(id){
  const allDC=await idbGetAll('drug_classes');
  const dc=allDC.find(x=>x.id===id);
  if(!dc) return;
  const newName=prompt('Etken madde adını düzenle:',dc.active_ingredient);
  if(!newName||!newName.trim()||newName.trim()===dc.active_ingredient) return;
  try{
    await rpcOptimistic('drug_class_guncelle',{p_id:id,p_active_ingredient:newName.trim()});
    toast('Güncellendi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */
  }
}

async function _dcDeleteGroup(grp){
  const allDC=await idbGetAll('drug_classes');
  const allDP=await idbGetAll('drug_products');
  const targets=allDC.filter(dc=>dc.group_name===grp);
  const linkedDP=allDP.filter(dp=>targets.some(dc=>dc.id===dp.drug_class_id));
  if(linkedDP.length){
    toast(`Bu grubun altında ${linkedDP.length} preparat bağlı. Önce preparatları taşıyın.`,'error');
    return;
  }
  const subCount=targets.length;
  if(!confirm(`"${grp}" grubu ve altındaki ${subCount} kayıt silinecek. Emin misiniz?`)) return;
  for(const dc of targets){
    await rpcOptimistic('drug_class_sil',{p_id:dc.id});
  }
  toast('Grup silindi');
  loadTanimlarPanel();
}

async function _dcDeleteClass(grp,cls){
  const allDC=await idbGetAll('drug_classes');
  const allDP=await idbGetAll('drug_products');
  const targets=allDC.filter(dc=>dc.group_name===grp&&dc.class_name===cls);
  const linkedDP=allDP.filter(dp=>targets.some(dc=>dc.id===dp.drug_class_id));
  if(linkedDP.length){
    toast(`Bu alt grupta ${linkedDP.length} preparat bağlı. Önce preparatları taşıyın.`,'error');
    return;
  }
  if(!confirm(`"${cls}" alt grubu ve altındaki ${targets.length} etken madde silinecek. Emin misiniz?`)) return;
  for(const dc of targets){
    await rpcOptimistic('drug_class_sil',{p_id:dc.id});
  }
  toast('Alt grup silindi');
  loadTanimlarPanel();
}

async function _dcDeleteIngredient(id){
  const allDP=await idbGetAll('drug_products');
  const linked=allDP.filter(dp=>dp.drug_class_id===id);
  if(linked.length){
    toast(`Bu etken maddeye ${linked.length} preparat bağlı. Önce preparatları taşıyın.`,'error');
    return;
  }
  if(!confirm('Bu etken maddeyi silmek istediğinize emin misiniz?')) return;
  try{
    await rpcOptimistic('drug_class_sil',{p_id:id});
    toast('Silindi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

async function _renderKategoriler(el){
  await pullTables(['stok_kategorileri','stok']);
  const kats=await idbGetAll('stok_kategorileri');
  const stok=getState('stock');
  if(!kats.length){
    el.innerHTML='<div class="empty"><div class="empty-ico">📂</div>Henüz kategori tanımı yok</div>'+_tanimVarsayilanBtn('kategoriler');
    return;
  }
  const sorted=[...kats].sort((a,b)=>(a.sira||0)-(b.sira||0));
  const ilacKats=sorted.filter(k=>k.tip==='ilac');
  const genelKats=sorted.filter(k=>k.tip!=='ilac');
  let html=_tanimSearchBar();
  const _katCard=(k,count,renk)=>`<div class="tanimlar-card" data-search="${esc(k.ad)} ${k.tip||''}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${renk};border-radius:10px;padding:11px 13px;margin-bottom:7px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="display:flex;align-items:center;gap:6px"><span style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(k.ad)}</span><span style="background:${renk}18;color:${renk};padding:1px 6px;border-radius:4px;font-size:.58rem;font-weight:700">${k.tip==='ilac'?'💊 İlaç':'📦 Stok'}</span></div>
          <div style="font-size:.62rem;color:var(--ink3);margin-top:2px">${count} ürün</div>
        </div>
        <button onclick="_tanimEditForm('kategori','${k.id}')" style="padding:6px 10px;background:var(--card2);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer;color:var(--ink3)">Düzenle</button>
      </div>
      <div id="tdf-kategori-${k.id}"></div>
    </div>`;
  if(ilacKats.length){
    html+=`<div style="font-weight:800;font-size:.72rem;color:var(--ink3);text-transform:uppercase;letter-spacing:.5px;margin:4px 0 6px 2px">💊 İlaç Kategorileri</div>`;
    html+=ilacKats.map(k=>_katCard(k,stok.filter(s=>s.kategori===k.ad).length,'#2196f3')).join('');
  }
  if(genelKats.length){
    html+=`<div style="font-weight:800;font-size:.72rem;color:var(--ink3);text-transform:uppercase;letter-spacing:.5px;margin:12px 0 6px 2px">📦 Stok Kategorileri</div>`;
    html+=genelKats.map(k=>_katCard(k,stok.filter(s=>s.kategori===k.ad).length,'#ff9800')).join('');
  }
  html+=`<button onclick="_tanimEditForm('kategori','new')" style="width:100%;padding:13px;background:rgba(78,154,42,.12);border:2px dashed rgba(78,154,42,.4);border-radius:10px;color:var(--green);font-size:.88rem;font-weight:800;cursor:pointer;margin-top:8px">＋ Yeni Kategori Ekle</button>`;
  html+=_tanimVarsayilanBtn('kategoriler');
  el.innerHTML=html;
}

// ═══════════════════════════════════════════════════════════
// ŞABLON TEDAVİ PLANLAMA — TANIMLAR (#63)
// ═══════════════════════════════════════════════════════════
const _KAT_RENK_SABLON = {Meme:'#e91e63',Üreme:'#9c27b0',Metabolik:'#ff9800',Ayak:'#795548',Solunum:'#2196f3',Sindirim:'#4caf50',Buzağı:'#00bcd4',Diğer:'#607d8b'};

async function _renderSablonlar(el){
  if(navigator.onLine){
    try{ await pullTables(['tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem','diseases']); }catch(e){ console.warn('pull sablon:', e.message); }
  }
  const sablonlar = await idbGetAll('tedavi_sablonu');
  const eslem     = await idbGetAll('sablon_hastalik_eslem');
  const kalemler  = await idbGetAll('tedavi_sablonu_kalem');
  const diseases  = await idbGetAll('diseases');
  const disMap = {}; diseases.forEach(d=>disMap[d.id]=d);

  let html = `<div style="display:flex;justify-content:flex-end;margin-bottom:8px">
    <button class="btn btn-g btn-sm" data-action="sablon-yeni" style="width:auto;padding:8px 14px">＋ Yeni Şablon</button></div>`;

  if(!sablonlar.length){
    html += '<div class="empty"><div class="empty-ico">📋</div>Henüz şablon yok. "＋ Yeni Şablon" ile başlayın.</div>';
    el.innerHTML = html; return;
  }

  sablonlar.sort((a,b)=>a.ad.localeCompare(b.ad,'tr',{sensitivity:'base'}));
  sablonlar.forEach(s=>{
    const sKalem = kalemler.filter(k=>k.sablon_id===s.id);
    const tohumlamaGunNo = Number.isInteger(s.tohumlama_plani?.gun_ofset) ? s.tohumlama_plani.gun_ofset + 1 : null;
    const gunSayisi  = new Set([...sKalem.map(k=>k.gun_no), ...(tohumlamaGunNo===null?[]:[tohumlamaGunNo])]).size;
    const seansSayisi= sKalem.length + (s.tohumlama_plani ? 1 : 0);
    const disIds = eslem.filter(e=>e.sablon_id===s.id).map(e=>e.disease_id);
    const disNames = disIds.map(id=>disMap[id]?.name).filter(Boolean);
    const ilkKat = disIds.map(id=>disMap[id]?.category).find(Boolean) || 'Diğer';
    const renk = _KAT_RENK_SABLON[ilkKat] || _KAT_RENK_SABLON.Diğer;
    const etiketler = disNames.length ? disNames.map(esc).join(' · ') : '<span style="color:var(--ink3)">eşlenmemiş</span>';
    html += `<div class="tanimlar-card" data-search="${esc(s.ad)} ${disNames.map(esc).join(' ')}"
      style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${renk};border-radius:10px;padding:11px 13px;margin-bottom:7px">
      <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
        <div style="flex:1;min-width:0">
          <div style="font-weight:700;font-size:.88rem">${esc(s.ad)}</div>
          <div style="font-size:.68rem;color:var(--ink2);margin-top:2px">🏷 ${etiketler}</div>
        </div>
        <div style="font-size:.7rem;color:var(--ink2);white-space:nowrap">${gunSayisi} gün · ${seansSayisi} seans</div>
        <div style="display:flex;gap:6px">
          <button data-action="sablon-duzenle" data-id="${s.id}" title="Düzenle" style="background:var(--card2);border:none;border-radius:7px;padding:6px 9px;cursor:pointer;font-size:.85rem">✏️</button>
          <button data-action="sablon-sil" data-id="${s.id}" title="Sil" style="background:#ffebee;border:none;border-radius:7px;padding:6px 9px;cursor:pointer;font-size:.85rem">🗑️</button>
        </div>
      </div>
    </div>`;
  });
  el.innerHTML = html;
}

async function silSablon(id){
  const s = (await idbGetAll('tedavi_sablonu')).find(x=>x.id===id);
  if(!confirm(`"${s?.ad||'Şablon'}" silinsin mi?`)) return;
  try{
    await rpc('tedavi_sablon_sil', { p_id: id });
    await pullTables(['tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem']);
    toast('🗑️ Şablon silindi');
    loadTanimlarPanel();
  }catch(e){ toast('❌ '+e.message, true); }
}

// ── Builder state: { id|null, ad, aciklama, disease_ids:[uuid], gunler:[{offset,kalemler}] } ──
// offset başlangıç gününe göredir: 0 = vaka açılış günü.
// kalem = { planned_time, stok_id, drug_product_id, dose, unit, route, _drugName }
let _sablonEdit = null;
let _sablonSeansForm = null;

async function openSablonBuilder(id){
  await loadDrugsCache();
  const diseases = await idbGetAll('diseases');
  if(id){
    const s = (await idbGetAll('tedavi_sablonu')).find(x=>x.id===id);
    const eslem = (await idbGetAll('sablon_hastalik_eslem')).filter(e=>e.sablon_id===id);
    const kalemler = (await idbGetAll('tedavi_sablonu_kalem')).filter(k=>k.sablon_id===id);
    // Tohumlama tek başına bir günün etkinliği olabilir; ilaç kalemi yok diye o günü düşürme.
    const tohumlamaGunNo = Number.isInteger(s?.tohumlama_plani?.gun_ofset) ? s.tohumlama_plani.gun_ofset + 1 : null;
    const gunNos = [...new Set([...kalemler.map(k=>k.gun_no), ...(tohumlamaGunNo===null?[]:[tohumlamaGunNo])])].sort((a,b)=>a-b);
    const gunler = gunNos.map(gn => ({ offset:gn-1, kalemler:kalemler.filter(k=>k.gun_no===gn)
      .sort((a,b)=>(a.planned_time||'').localeCompare(b.planned_time||''))
      .map(k=>({ planned_time:(k.planned_time||'').slice(0,5), stok_id:k.stok_id, drug_product_id:k.drug_product_id,
                 dose:k.dose, unit:k.unit, route:k.route, _drugName:_sablonDrugName(k) })) }));
    _sablonEdit = { id, ad:s?.ad||'', aciklama:s?.aciklama||'', disease_ids:eslem.map(e=>e.disease_id), gunler:gunler.length?gunler:[{offset:0,kalemler:[]}], tohumlama_plani:s?.tohumlama_plani||null };
  } else {
    _sablonEdit = { id:null, ad:'', aciklama:'', disease_ids:[], gunler:[{offset:0,kalemler:[]}], tohumlama_plani:null };
  }
  _sablonEdit._diseases = diseases;
  document.getElementById('m-sablon-title').textContent = id ? 'Şablonu Düzenle' : 'Yeni Şablon';
  _renderSablonBuilder();
  openM('m-sablon');
}

function _sablonDrugName(k){
  const d = (_drugsCache||[]).find(x => x.id === (k.drug_product_id || k.stok_id));
  return d?.name || 'İlaç';
}

function _renderSablonBuilder(){
  const s = _sablonEdit;
  // Hastalıklar — kategoriye göre gruplu checkbox (çoka-çok, vaka girişiyle aynı dil)
  const disByCat = {};
  s._diseases.slice().sort((a,b)=>(a.name||'').localeCompare(b.name||'','tr')).forEach(d=>{
    const c = d.category || 'Diğer';
    (disByCat[c]=disByCat[c]||[]).push(d);
  });
  const disHtml = Object.keys(disByCat).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'})).map(cat=>{
    const items = disByCat[cat].map(d=>`<label style="display:flex;align-items:center;gap:8px;padding:4px 2px;cursor:pointer">
      <input type="checkbox" ${s.disease_ids.includes(d.id)?'checked':''} onchange="sablonDisToggle('${d.id}',this.checked)" style="width:17px;height:17px;accent-color:var(--green);flex-shrink:0;cursor:pointer">
      <span style="font-size:.82rem">${esc(d.name)}</span></label>`).join('');
    return `<div style="margin-bottom:6px"><div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.05em;border-bottom:1px solid var(--card3);padding-bottom:2px;margin-bottom:3px">${esc(cat)}</div>${items}</div>`;
  }).join('');
  const seciliSayi = s.disease_ids.length;

  let gunlerHtml = '';
  s.gunler.forEach((gun, gi)=>{
    const kalemler = gun.kalemler;
    const tohumlama = s.tohumlama_plani?.gun_ofset===gun.offset ? s.tohumlama_plani : null;
    const seansRows = kalemler.length
      ? kalemler.map((k,ki)=>`<div style="display:flex;align-items:center;gap:8px;padding:4px 0;font-size:.8rem">
          <span style="font-weight:700;color:var(--ink2);min-width:42px">⏰ ${esc(k.planned_time)}</span>
          <span style="flex:1">💊 ${esc(k._drugName)} <span style="color:var(--ink3);font-size:.72rem">${k.dose} ${esc(k.unit)}${k.route?' · '+esc(k.route):''}</span></span>
          <button data-action="sablon-seans-sil" data-gi="${gi}" data-ki="${ki}" style="background:none;border:none;color:var(--red);cursor:pointer">🗑️</button>
        </div>`).join('')
      : '';
    gunlerHtml += `<div class="tanimlar-card" style="margin:6px 0;padding:8px 10px;background:var(--card);border:1px solid var(--card3);border-radius:8px">
      <div style="display:flex;justify-content:space-between;align-items:center;cursor:pointer" data-action="sablon-gun-toggle" data-gi="${gi}">
        <strong>Gün ${gun.offset}</strong>
        <span style="font-size:.72rem;color:var(--ink2)">${kalemler.length} ilaç seansı${tohumlama?' · 1 tohumlama':''}
          <button data-action="sablon-gun-sil" data-gi="${gi}" style="background:none;border:none;color:var(--red);cursor:pointer">🗑️</button></span>
      </div>
      <div id="sablon-gun-body-${gi}" style="display:${gi===s.gunler.length-1?'block':'none'};margin-top:6px">
        <label style="display:flex;align-items:center;gap:7px;font-size:.76rem;color:var(--ink2);margin:4px 0 7px">Başlangıçtan gün
          <input class="fi" type="number" min="0" step="1" value="${gun.offset}" data-change="sablon-gun-ofset" data-gi="${gi}" style="width:75px;margin:0;padding:5px 7px"></label>
        ${seansRows}
        ${tohumlama?`<div style="display:flex;align-items:center;gap:8px;padding:7px 0;font-size:.8rem;border-top:1px solid var(--card3);margin-top:6px"><span style="font-weight:700;min-width:42px">🐄 ${esc(tohumlama.planned_time)}</span><span style="flex:1;font-weight:700">Planlı tohumlama <span style="font-weight:400;color:var(--ink3);font-size:.72rem">Sperma görevde seçilir</span></span><input class="fi" type="time" value="${tohumlama.planned_time}" data-change="sablon-tohumlama-saat" style="width:92px;padding:4px"><button data-action="sablon-tohumlama-sil" style="background:none;border:none;color:var(--red);cursor:pointer">🗑️</button></div>`:''}
        <button class="btn-sm" data-action="sablon-seans-ac" data-gi="${gi}" style="margin-top:6px;font-size:.78rem;font-weight:700;padding:7px 12px;background:rgba(42,107,181,.1);color:var(--blue);border:1px dashed rgba(42,107,181,.4);border-radius:7px;cursor:pointer;width:100%">＋ Bu güne seans/ilaç ekle</button>
        ${!tohumlama?`<button class="btn-sm" data-action="sablon-tohumlama-gun-ekle" data-gi="${gi}" style="margin-top:6px;font-size:.78rem;font-weight:700;padding:7px 12px;background:rgba(126,87,194,.10);color:#7151a6;border:1px dashed rgba(126,87,194,.45);border-radius:7px;cursor:pointer;width:100%">＋ Bu güne tohumlama ekle</button>`:''}
      </div>
    </div>`;
  });

  document.getElementById('m-sablon-body').innerHTML = `
    <div class="fg"><label class="flbl">Şablon adı *</label>
      <input id="sb-ad" class="fi" value="${esc(s.ad)}" placeholder="Örn. PRİT Protokolü"></div>
    <div class="fg"><label class="flbl">Hastalıklar ${seciliSayi?`<span style="color:var(--green)">(${seciliSayi} seçili)</span>`:''}</label>
      <div style="max-height:170px;overflow-y:auto;background:var(--card);border:1px solid var(--card3);border-radius:8px;padding:8px">${disHtml||'<div style="color:var(--ink3);font-size:.78rem">Hastalık tanımı yok</div>'}</div></div>
    <div class="fg"><label class="flbl">Açıklama</label>
      <input id="sb-aciklama" class="fi" value="${esc(s.aciklama)}" placeholder="opsiyonel"></div>
    <div style="display:flex;justify-content:space-between;align-items:center;margin:10px 0 4px">
      <strong>Plan</strong>
      <button class="btn-sm" data-action="sablon-gun-ekle" style="font-weight:700;padding:7px 13px;background:rgba(78,154,42,.12);color:var(--green);border:1px solid rgba(78,154,42,.35);border-radius:7px;cursor:pointer">＋ Gün Ekle</button></div>
    ${gunlerHtml}
    <button class="btn btn-g" data-action="sablon-kaydet" style="margin-top:14px">💾 Kaydet</button>
    <button class="btn btn-o" data-action="sablon-iptal" style="margin-top:6px">İptal</button>`;
}

function sablonDisToggle(id, checked){
  _syncSablonAd();
  if(checked){ if(!_sablonEdit.disease_ids.includes(id)) _sablonEdit.disease_ids.push(id); }
  else { _sablonEdit.disease_ids = _sablonEdit.disease_ids.filter(x=>x!==id); }
}

function _syncSablonAd(){
  const ad = document.getElementById('sb-ad'); const ac = document.getElementById('sb-aciklama');
  if(ad) _sablonEdit.ad = ad.value;
  if(ac) _sablonEdit.aciklama = ac.value;
}

function sablonGunEkle(){
  _syncSablonAd();
  const sonOfset = _sablonEdit.gunler.reduce((max, gun) => Math.max(max, gun.offset), -1);
  _sablonEdit.gunler.push({ offset:sonOfset+1, kalemler:[] });
  _renderSablonBuilder();
}
function sablonGunSil(gi){ _syncSablonAd(); const silinen=_sablonEdit.gunler[+gi]; if(_sablonEdit.tohumlama_plani?.gun_ofset===silinen?.offset) _sablonEdit.tohumlama_plani=null; _sablonEdit.gunler.splice(+gi,1); if(!_sablonEdit.gunler.length) _sablonEdit.gunler=[{offset:0,kalemler:[]}]; _renderSablonBuilder(); }
function sablonGunOfsetGuncelle(gi, value){
  const offset = Number(value);
  if(!Number.isInteger(offset) || offset < 0){ toast('Gün ofseti 0 veya daha büyük tam sayı olmalı', true); _renderSablonBuilder(); return; }
  if(_sablonEdit.gunler.some((gun, i) => i !== +gi && gun.offset === offset)){
    toast('Aynı gün zaten var; seansları o günün altında toplayın', true); _renderSablonBuilder(); return;
  }
  _syncSablonAd();
  const eskiOfset=_sablonEdit.gunler[+gi].offset;
  if(_sablonEdit.tohumlama_plani?.gun_ofset===eskiOfset) _sablonEdit.tohumlama_plani.gun_ofset=offset;
  _sablonEdit.gunler[+gi].offset = offset;
  _sablonEdit.gunler.sort((a,b) => a.offset-b.offset);
  _renderSablonBuilder();
}
function sablonGunToggle(gi){
  const body=document.getElementById('sablon-gun-body-'+gi); if(!body) return;
  body.style.display = body.style.display==='none' ? 'block' : 'none';
}
function sablonSeansSil(gi,ki){ _syncSablonAd(); _sablonEdit.gunler[+gi].kalemler.splice(+ki,1); _renderSablonBuilder(); }

function sablonSeansAc(gi){
  _syncSablonAd();
  if(_sablonSeansForm){ _sablonSeansForm.remove(); _sablonSeansForm=null; }
  // İlaç checkbox grupları — tedavi modalindeki caseSeansEkleFormAc ile birebir aynı dil
  const cache = _drugsCache || [];
  const groups = {};
  [...cache].sort((a,b)=>a.name.localeCompare(b.name,'tr')).forEach(dr=>{ const g=dr.group_name||'Diğer'; (groups[g]=groups[g]||[]).push(dr); });
  const groupHtml = Object.keys(groups).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'})).map(grp=>{
    const items = groups[grp].map(dr=>{
      const stokClrPos = dr.guncel<=0?'var(--red)':dr.guncel<=10?'var(--amber)':'var(--green)';
      const stokClr = dr.guncel===null?'var(--ink3)':stokClrPos;
      const stokTxt = dr.guncel!==null?dr.guncel.toFixed(1)+' '+dr.birim:'—';
      const nm = dr.name.replace(/"/g,'&quot;');
      const rt = (dr.default_route||'IM').split(' ')[0];
      return '<label style="display:flex;align-items:center;gap:8px;padding:5px 2px;cursor:pointer">'+
        '<input type="checkbox" class="cdf-chk" data-id="'+dr.id+'" data-name="'+nm+'" data-unit="'+(dr.default_unit||dr.birim||'ml')+'" data-route="'+rt+'" data-legacy="'+(dr._legacy||false)+'" onchange="cdfChkChange(this)" style="width:18px;height:18px;accent-color:var(--green);flex-shrink:0;cursor:pointer">'+
        '<div style="flex:1;min-width:0"><div style="font-size:.82rem;font-weight:600;color:var(--ink)">'+dr.name+'</div>'+
        (dr.active_ingredient?'<div style="font-size:.65rem;color:var(--ink3)">'+dr.active_ingredient+'</div>':'')+
        '</div><span style="font-size:.72rem;font-weight:700;color:'+stokClr+';flex-shrink:0">'+stokTxt+'</span></label>';
    }).join('');
    return '<div style="margin-bottom:8px"><div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px;padding-bottom:3px;border-bottom:1px solid var(--card3)">'+grp+'</div>'+items+'</div>';
  }).join('');
  const saatChips = HIZLI_SAATLER.map(t=>`<button type="button" class="btn-sm" data-action="sablon-saat-chip" data-t="${t}" style="padding:5px 10px;background:rgba(42,107,181,.1);color:var(--blue);border:none;border-radius:6px;cursor:pointer;margin-right:4px;font-weight:700">${t}</button>`).join('');
  const wrap = document.getElementById('sablon-gun-body-'+gi);
  const form = document.createElement('div');
  form.style.cssText='border:1px dashed var(--card3);border-radius:10px;padding:10px;margin-top:6px;background:var(--card2)';
  form.innerHTML =
    '<div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">⏰ Saat</div>'+
    '<div style="display:flex;gap:5px;align-items:center;flex-wrap:wrap;margin-bottom:8px">'+
    `<input id="sbs-time" class="fi" type="time" value="${HIZLI_SAATLER[0]}" style="margin:0;flex:1;min-width:100px">`+saatChips+'</div>'+
    '<div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">İlaç Seç (çoklu — bu saatte uygulanacak)</div>'+
    '<div style="max-height:200px;overflow-y:auto;background:var(--card);border-radius:8px;padding:8px;margin-bottom:8px;border:1px solid var(--card3)">'+
    (groupHtml||'<div style="color:var(--ink3);font-size:.78rem;padding:8px">İlaç bulunamadı</div>')+'</div>'+
    '<div id="cdf-doz-alani" style="display:none">'+
    '<div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Seçili İlaçlar — Doz Gir</div>'+
    '<div id="cdf-doz-satirlar"></div></div>'+
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px">'+
    `<button class="btn-sm" data-action="sablon-seans-ekle" data-gi="${gi}" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:9px;font-weight:700;cursor:pointer">＋ Seansı Ekle</button>`+
    '<button class="btn-sm" data-action="sablon-seans-vazgec" style="background:var(--card3);border:none;border-radius:7px;padding:9px;cursor:pointer">Vazgeç</button></div>';
  wrap.appendChild(form);
  _sablonSeansForm = form;
}

function sablonSaatChip(t){ const i=document.getElementById('sbs-time'); if(i) i.value=t; }
function sablonTohumlamaGunEkle(gi){ _syncSablonAd(); const gun=_sablonEdit.gunler[+gi]; _sablonEdit.tohumlama_plani={gun_ofset:gun.offset,planned_time:'08:00'}; _renderSablonBuilder(); }
function sablonTohumlamaSil(){ _syncSablonAd(); _sablonEdit.tohumlama_plani=null; _renderSablonBuilder(); }
function sablonTohumlamaSaat(value){ if(value) _sablonEdit.tohumlama_plani={..._sablonEdit.tohumlama_plani,planned_time:value}; }
function sablonSeansVazgec(){ if(_sablonSeansForm){ _sablonSeansForm.remove(); _sablonSeansForm=null; } }

function sablonSeansEkle(gi){
  if(!_sablonSeansForm) return;
  const time = document.getElementById('sbs-time')?.value;
  if(!time){ toast('Saat girin', true); return; }
  const secililer = [];
  let hata = false;
  document.querySelectorAll('.cdf-chk:checked').forEach(chk=>{
    if(hata) return;
    const id = chk.dataset.id;
    const dose = Number.parseFloat(document.querySelector('.cdf-dose-inp[data-drug-id="'+id+'"]')?.value);
    const unit = (document.querySelector('.cdf-unit-inp[data-drug-id="'+id+'"]')?.value||'').trim();
    const route = document.querySelector('.cdf-route-inp[data-drug-id="'+id+'"]')?.value || null;
    if(!dose||dose<=0){ toast(chk.dataset.name+': geçerli doz girin', true); hata=true; return; }
    if(!unit){ toast(chk.dataset.name+': birim girin', true); hata=true; return; }
    const d = (_drugsCache||[]).find(x=>x.id===id);
    secililer.push({
      planned_time: time,
      stok_id: d?.stock_id || null,
      drug_product_id: d?._legacy ? null : id,
      dose, unit, route,
      _drugName: d?.name || chk.dataset.name,
    });
  });
  if(hata) return;
  if(!secililer.length){ toast('En az bir ilaç seçin', true); return; }
  _syncSablonAd();
  secililer.forEach(k=>_sablonEdit.gunler[+gi].kalemler.push(k));
  _sablonSeansForm=null;
  _renderSablonBuilder();
}

async function sablonKaydet(){
  _syncSablonAd();
  const s=_sablonEdit;
  if(!s.ad.trim()){ toast('Şablon adı zorunlu', true); return; }
  const kalemler=[];
  s.gunler.forEach(gun=>gun.kalemler.forEach(k=>kalemler.push({
    gun_no: gun.offset+1, planned_time: k.planned_time, stok_id: k.stok_id,
    drug_product_id: k.drug_product_id, dose: k.dose, unit: k.unit, route: k.route,
  })));
  // Sadece tohumlamadan oluşan şablon da geçerlidir (senkronizasyon sonu tohumlama).
  if(!kalemler.length && !s.tohumlama_plani){ toast('En az bir seans ekleyin', true); return; }
  try{
    // tohumlama_plani anahtarını SADECE plan varsa gönder. `null` gönderilirse
    // Postgres tarafında `p_kalemler->'tohumlama_plani'` SQL NULL değil jsonb 'null'
    // döner ve doğrulama "tohumlama zorunlu" gibi davranır (DB tarafı da düzeltildi,
    // bu ikinci emniyet). Anahtarın yokluğu = "bu şablonda tohumlama yok".
    const payload = { kalemler };
    if(s.tohumlama_plani) payload.tohumlama_plani = s.tohumlama_plani;
    await rpc('tedavi_sablon_kaydet', {
      p_id: s.id, p_ad: s.ad.trim(), p_aciklama: s.aciklama||null,
      p_disease_ids: s.disease_ids, p_kalemler: payload,
    });
    await pullTables(['tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem']);
    closeM('m-sablon');
    toast('💾 Şablon kaydedildi');
    loadTanimlarPanel();
  }catch(e){ toast('❌ '+e.message, true); }
}

async function _kategoriEditForm(id){
  const isNew=id==='new';
  let ad='',tip='genel';
  if(!isNew){
    const all=await idbGetAll('stok_kategorileri');
    const k=all.find(x=>x.id===id);
    if(k){ad=k.ad;tip=k.tip||'genel';}
  }
  const formHtml=`<div class="tanim-edit-form" style="background:rgba(42,107,181,.06);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:10px;margin-top:6px">
    <div style="display:grid;grid-template-columns:2fr 1fr;gap:6px;margin-bottom:8px">
      <input id="tef-kat-ad" class="fi" value="${esc(ad)}" placeholder="Kategori adı" style="margin:0">
      <select id="tef-kat-tip" class="fsel" style="margin:0"><option ${tip==='ilac'?'selected':''} value="ilac">💊 İlaç</option><option ${tip==='genel'?'selected':''} value="genel">📦 Stok</option></select>
    </div>
    <div style="display:flex;gap:6px">
      <button onclick="_kategoriSave('${id}')" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px;font-weight:700;cursor:pointer">${isNew?'Ekle':'Kaydet'}</button>
      ${isNew?'':`<button onclick="_kategoriDelete('${id}')" style="padding:8px 12px;background:#ffebee;color:#c62828;border:none;border-radius:7px;font-weight:700;cursor:pointer">Sil</button>`}
      <button onclick="document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove())" style="padding:8px 12px;background:var(--card3);border:none;border-radius:7px;cursor:pointer">İptal</button>
    </div>
  </div>`;
  if(isNew){
    const btn=document.querySelector('#tanimlar-panel-body button[onclick*="kategori"][onclick*="new"]');
    if(btn) btn.insertAdjacentHTML('beforebegin',formHtml);
  } else {
    const wrap=document.getElementById('tdf-kategori-'+id);
    if(wrap) wrap.innerHTML=formHtml;
  }
}

async function _kategoriSave(id){
  const ad=document.getElementById('tef-kat-ad')?.value.trim();
  const tip=document.getElementById('tef-kat-tip')?.value||'genel';
  if(!ad){toast('Kategori adı zorunlu','warn');return;}
  const isNew=id==='new';
  try{
    await rpcOptimistic(isNew?'kategori_ekle':'kategori_guncelle',
      isNew?{p_ad:ad,p_tip:tip}:{p_id:id,p_new_ad:ad,p_tip:tip});
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

async function _kategoriDelete(id){
  if(!confirm('Bu kategoriyi silmek istediğinize emin misiniz?')) return;
  try{
    await rpcOptimistic('kategori_sil',{p_id:id});
    toast('Kategori silindi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

let _ilacKatAdlari=null;
async function _getIlacKatAdlari(){
  if(_ilacKatAdlari) return _ilacKatAdlari;
  const kats=(await idbGetAll('stok_kategorileri'))||[];
  _ilacKatAdlari=kats.filter(k=>k.tip==='ilac').map(k=>k.ad);
  return _ilacKatAdlari;
}
function _buildTabFilter(ilacAdlari){
  return {
    tumu:()=>true,
    ilac:s=>ilacAdlari.includes(s.kategori),
    asi:s=>s.isVaccine||s.kategori==='Aşı'||s.kategori==='Asi',
    sperma:s=>s.kategori==='Sperma',
    diger:s=>!ilacAdlari.includes(s.kategori)&&s.kategori!=='Aşı'&&s.kategori!=='Asi'&&s.kategori!=='Sperma'&&!s.isVaccine
  };
}

async function loadStokPanel(){
  const el=document.getElementById('stok-panel-body'); if(!el) return;
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  await Promise.all([loadStock(), loadDrugsCache(), pullTables(['stok_kategorileri'])]);
  const allStok=getState('stock');
  const ilacAdlari=await _getIlacKatAdlari();
  const tabFilter=_buildTabFilter(ilacAdlari);
  const tabFn=tabFilter[_stokTab]||tabFilter.tumu;
  const stok=allStok.filter(tabFn);
  if(!allStok.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📦</div>Henüz stok ürünü eklenmemiş</div>'; return; }
  if(!stok.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🔍</div>Bu sekmede ürün yok</div>'; return; }
  const ILAC_KATLAR=ilacAdlari;
  const katlar=await idbGetAll('stok_kategorileri');
  const ilacKats=(katlar||[]).filter(k=>k.tip==='ilac').sort((a,b)=>(a.sira||0)-(b.sira||0));
  const GRUPLAR=[
    {baslik:'💊 Sağlık',alt:[
      {ad:'🐂 Sperma',         filtre:s=>s.kategori==='Sperma'},
      ...ilacKats.map(k=>({
        ad:'💊 '+k.ad,
        filtre:s=>s.kategori===k.ad
      })),
      {ad:'🔧 Sarf & Ekipman', filtre:s=>['Ekipman','Sarf','Diğer'].includes(s.kategori)},
    ]},
    {baslik:'🐂 Tohumlama',alt:[
      {ad:'🐂 Tohumlama Ürünleri', filtre:s=>s.kategori==='Tohumlama'},
    ]},
    {baslik:'🌾 Yem',alt:[
      {ad:'🌾 Yem & Katkı', filtre:s=>s.kategori==='Yem'},
    ]},
  ];
  let html='';
  // Arama filtresi DOM tabanlı (stokFiltrele), input panel-body'nin üstünde
  GRUPLAR.forEach(grup=>{
    const grupStok=stok.filter(s=>grup.alt.some(a=>a.filtre(s)));
    if(!grupStok.length && grup.baslik.includes('Yem')){
      html+=`<div style="background:var(--bg2);border:1px dashed var(--bg3);border-radius:12px;padding:14px;margin-bottom:10px;opacity:.5">
        <div style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.07em">${grup.baslik}</div>
        <div style="font-size:.75rem;color:var(--ink3);margin-top:6px">Yakında — yem modülü</div>
      </div>`;
      return;
    }
    html+=`<div class="stok-group" style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.07em;margin:14px 0 8px">${grup.baslik}</div>`;
    grup.alt.forEach(alt=>{
      const liste=stok.filter(s=>alt.filtre(s));
      if(!liste.length) return;
      html+=`<div style="font-size:.65rem;font-weight:700;color:var(--ink3);margin:8px 0 4px;padding-left:4px">${alt.ad} (${liste.length})</div>`;
      html+=liste.map(s=>{
        const pct=Math.max(0,Math.min(100,(+s.baslangic_miktar||1)>0?(s.guncel/(+s.baslangic_miktar||1))*100:100));
        const barClr=_durumClr(s.durum);
        const durmTxt=_durumTxt(s.durum);
        return `<div class="stok-item" data-ad="${esc(s.urun_adi)}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${barClr};border-radius:10px;padding:11px 13px;margin-bottom:7px">
          <div style="display:flex;justify-content:space-between;align-items:flex-start">
            <div style="flex:1">
              <div style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(s.urun_adi)}${s.isVaccine?' <span style="background:var(--blue);color:#fff;padding:1px 5px;border-radius:4px;font-size:.6rem;font-weight:700">💉 Aşı Stoğu</span>':''}</div>
              <div style="font-size:.62rem;color:var(--ink3);margin-top:2px">${s.kategori||'—'} · Eşik: ${s.esik||0} ${s.birim||''}</div>
            </div>
            <div style="text-align:right;flex-shrink:0;margin-left:10px">
              <div style="font-size:1.3rem;font-weight:800;color:${barClr};line-height:1">${(s.guncel||0).toFixed(s.birim==='adet'?0:1)}</div>
              <div style="font-size:.6rem;color:var(--ink3)">${s.birim||''}</div>
            </div>
          </div>
          <div style="height:4px;background:var(--card2);border-radius:2px;margin-top:8px;overflow:hidden">
            <div style="height:100%;width:${pct}%;background:${barClr};border-radius:2px"></div>
          </div>
          <div style="display:flex;gap:6px;margin-top:8px">
            <button onclick="openStk('${s.id}')" style="flex:1;padding:6px;background:var(--green);color:#fff;border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">+ Miktar Ekle</button>
            <button onclick="stokHareketGor('${s.id}')" style="padding:6px 10px;background:var(--card2);color:var(--ink3);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">Hareketler</button>
            <button onclick="openStokDet('${s.id}')" style="padding:6px 10px;background:var(--card2);color:var(--ink3);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">Düzenle</button>
          </div>
          ${s.drug_product_id?`<div style="margin-top:5px;font-size:.65rem;color:var(--green);font-weight:700">✅ Tedaviye bağlı</div>`:''}
        </div>`;
      }).join('');
    });
  });
  // Vaccines section — birleşik kart (katalog + stok + hastalık + protokol)
  const vaxList = await getData('vaccines') || [];
  if(vaxList.length){
    const allStok = getState('stock') || [];
    const vDis = await getData('vaccine_diseases') || [];
    const allDis = await getData('diseases') || [];
    const vSteps = await getData('vaccine_protocol_steps') || [];
    const disName = id => (allDis.find(d=>d.id===id)||{}).name || '';
    html += `<div class="stok-group" style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.07em;margin:14px 0 8px;display:flex;justify-content:space-between;align-items:center">
      <span>💉 Aşı</span>
      <button onclick="openAsiEkle()" style="font-size:.72rem;font-weight:700;padding:6px 11px;background:var(--blue);color:#fff;border:none;border-radius:7px;cursor:pointer">＋ Yeni Aşı Ekle</button></div>`;
    html += vaxList.slice().sort((a,b)=>(a.name||'').localeCompare(b.name||'','tr')).map(v=>{
      const stk = v.stock_item_id ? allStok.find(s=>s.id===v.stock_item_id) : null;
      const guncel = stk ? +(stk.guncel ?? stk.guncel_stok ?? stk.baslangic_miktar ?? 0) : null;
      const esik = stk ? +(stk.esik||0) : 0;
      const chips = vDis.filter(x=>x.vaccine_id===v.id).map(x=>disName(x.disease_id)).filter(Boolean)
        .map(n=>`<span style="background:var(--card2);color:var(--ink2);font-size:.6rem;padding:1px 6px;border-radius:6px;margin:0 3px 3px 0;display:inline-block">${esc(n)}</span>`).join('') || `<span style="font-size:.62rem;color:var(--ink3)">${esc(v.disease_target||'—')}</span>`;
      const steps = vSteps.filter(s=>s.vaccine_id===v.id).sort((a,b)=>a.adim_no-b.adim_no);
      const protOzet = steps.length>1 ? `${steps.length} doz · ${steps[1].offset_gun}g ara` : 'Tek doz';
      const repeatTxt = v.repeat_interval_days ? ` · tekrar ${v.repeat_interval_days}g` : '';
      const stokBlok = v.stock_item_id
        ? `<div style="font-weight:700;font-size:1rem;color:${guncel<=esik?'var(--red)':'var(--ink)'}">${(guncel||0).toFixed(1)} ${esc(v.unit||'ml')}</div>
           <div style="display:flex;gap:6px;margin-top:6px">
             <button onclick="openStk('${v.stock_item_id}')" style="flex:1;padding:6px;background:var(--green);color:#fff;border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">+ Miktar Ekle</button>
             <button onclick="stokHareketGor('${v.stock_item_id}')" style="padding:6px 10px;background:var(--card2);color:var(--ink3);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">Hareketler</button>
           </div>`
        : `<div style="display:flex;align-items:center;gap:8px"><span style="font-size:.72rem;color:var(--ink3)">Stok yok</span>
             <button onclick="openAsiEkle('${v.id}')" style="padding:5px 10px;background:rgba(42,107,181,.1);color:var(--blue);border:1px dashed rgba(42,107,181,.4);border-radius:7px;font-size:.7rem;font-weight:700;cursor:pointer">+ Stok Ekle</button></div>`;
      return `<div class="stok-item" data-ad="${esc(v.name)}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid var(--blue);border-radius:10px;padding:11px 13px;margin-bottom:7px">
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px">
          <div style="flex:1">
            <div style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(v.name)}${v.marka?` <span style="font-weight:400;font-size:.7rem;color:var(--ink3)">${esc(v.marka)}</span>`:''}${v.is_mandatory?' <span style="color:var(--red);font-size:.6rem">🔴</span>':''}</div>
            <div style="margin-top:4px">${chips}</div>
            <div style="font-size:.62rem;color:var(--ink3);margin-top:3px">${protOzet}${repeatTxt}</div>
          </div>
          <button onclick="openAsiEkle('${v.id}')" style="background:var(--card2);color:var(--ink3);border:none;border-radius:7px;padding:5px 9px;font-size:.7rem;font-weight:700;cursor:pointer">Düzenle</button>
        </div>
        <div style="margin-top:8px">${stokBlok}</div>
      </div>`;
    }).join('');
  }
  el.innerHTML=html||'<div class="empty">Kayıt yok</div>';
}

async function openStokDet(stokId){
  const allStok=getState('stock');
  const s=allStok.find(x=>x.id===stokId);
  if(!s) return;
  _curStokDet=s;
  const modal=document.getElementById('m-stok-det');
  if(!modal){ toast('Sayfayı yenileyiniz (Ctrl+Shift+R)',true); return; }
  const t=g('stok-det-title'); if(t) t.textContent=s.urun_adi;
  const ad=g('sd-ad'); if(ad) ad.value=s.urun_adi||'';
  const kat=g('sd-kat'); if(kat) kat.value=s.kategori||'';
  const birim=g('sd-birim'); if(birim) birim.value=s.birim||'adet';
  const esik=g('sd-esik'); if(esik) esik.value=s.esik||'';
  const guncel=g('sd-guncel'); if(guncel) guncel.textContent=(s.guncel||0)+' '+(s.birim||'');
  const yeni=g('sd-yeni-miktar'); if(yeni) yeni.value='';
  openM('m-stok-det');
}

async function stokDetKaydet(){
  if(!_curStokDet) return;
  const updates={
    p_urun_adi:v('sd-ad').trim(),
    p_kategori:v('sd-kat'),
    p_birim:v('sd-birim'),
    p_esik:parseFloat(v('sd-esik'))||0
  };
  if(!updates.p_urun_adi){ toast('Ürün adı boş olamaz',true); return; }
  try {
    await rpc('stok_guncelle',{p_stok_id:_curStokDet.id,...updates});
    await pullTables(['stok']);
    closeM('m-stok-det');
    loadStokPanel();
    toast('Ürün güncellendi');
  } catch(e){ toast('Hata: '+e.message,true); return; }
}

async function stokDetArsivle(){
  if(!_curStokDet) return;
  const hareketler=await getData('stok_hareket');
  const count=hareketler.filter(h=>h.stok_id===_curStokDet.id&&!h.iptal).length;
  const msg=count>0
    ?`Bu üründe ${count} hareket kaydı var. Arşivlenecek (silinmeyecek). Devam?`
    :'Bu ürünü arşivlemek istediğinizden emin misiniz?';
  openConfirm('Ürün Arşivle',msg,async()=>{
    try {
      await rpc('stok_arsivle',{p_stok_id:_curStokDet.id});
      await pullTables(['stok']);
      closeM('m-stok-det');
      loadStokPanel();
      toast('Ürün arşivlendi');
    } catch(e){ toast('Hata: '+e.message,true); }
  });
}

async function stokDuzeltKaydet(){
  if(!_curStokDet) return;
  const yeni=parseFloat(v('sd-yeni-miktar'));
  if(isNaN(yeni)||yeni<0){ toast('Geçerli bir miktar girin',true); return; }
  const res=await rpc('stok_duzelt',{p_stok_id:_curStokDet.id,p_yeni_miktar:yeni});
  if(!res.ok){ toast(res.mesaj||'Hata',true); return; }
  await pullTables(['stok','stok_hareket']);
  document.getElementById('sd-guncel').textContent=yeni+' '+(_curStokDet.birim||'');
  document.getElementById('sd-yeni-miktar').value='';
  toast('Stok düzeltildi: '+res.eski+' → '+res.yeni);
}

async function tumStokHareketleriniGoster(){
  const el=document.getElementById('stok-hareketler-body');
  if(!el) return;
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  openM('m-stok-hareketler');
  try {
    const moves=await getData('stok_hareket');
    const stok=getState('stock')||[];
    moves.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
    if(!moves.length){
      el.innerHTML='<div class="empty"><div class="empty-ico">📋</div>Henüz stok hareketi yok</div>';
      return;
    }
    let html='';
    moves.forEach(m=>{
      const urun=stok.find(s=>s.id===m.stok_id);
      const urunAd=urun?.urun_adi||'Silinmiş Ürün';
      const birim=urun?.birim||'';
      const dec=birim==='adet'?0:1;
      const tarihFmt=fmtTarih(m.tarih);
      const isIade=m.iptal&&(m.notlar||'').startsWith('drug_admin:');
      if(isIade){
        html+=`<div style="background:var(--card);border:1px solid var(--card2);border-radius:8px;padding:10px;margin-bottom:6px;border-left:3px solid var(--red);opacity:.6">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px">
            <div style="font-weight:700;font-size:.85rem;color:var(--ink);text-decoration:line-through">${urunAd}</div>
            <div style="font-size:.85rem;font-weight:800;color:var(--red);text-decoration:line-through">−${(m.miktar||0).toFixed(dec)} ${birim}</div>
          </div>
          <div style="font-size:.68rem;color:var(--red)">❌ ${m.tur||'Tedavi'} — iptal edildi · 📅 ${tarihFmt}</div>
        </div>`;
        html+=`<div style="background:rgba(45,106,45,.06);border:1px solid rgba(45,106,45,.2);border-radius:8px;padding:10px;margin-bottom:6px;border-left:3px solid var(--green)">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px">
            <div style="font-weight:700;font-size:.85rem;color:var(--green)">${urunAd}</div>
            <div style="font-size:.85rem;font-weight:800;color:var(--green)">+${(m.miktar||0).toFixed(dec)} ${birim}</div>
          </div>
          <div style="font-size:.68rem;color:var(--green)">↩ Tedavi İadesi · 📅 ${tarihFmt}</div>
        </div>`;
      } else {
        if(m.iptal) return;
        const turRenk=m.tur==='Giriş'||m.tur==='İade'||m.tur==='Düzeltme'||m.tur==='Ekleme'?'var(--green)':'var(--red)';
        const turIsaret=m.tur==='Giriş'||m.tur==='İade'||m.tur==='Düzeltme'||m.tur==='Ekleme'?'+':'−';
        html+=`<div style="background:var(--card);border:1px solid var(--card2);border-radius:8px;padding:10px;margin-bottom:6px">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
            <div style="font-weight:700;font-size:.85rem;color:var(--ink)">${esc(urunAd)}</div>
            <div style="font-size:.85rem;font-weight:800;color:${turRenk}">${turIsaret}${(m.miktar||0).toFixed(dec)} ${esc(birim)}</div>
          </div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:4px;font-size:.68rem;color:var(--ink3)">
            <div>📅 ${tarihFmt}</div>
            <div>📝 ${esc(m.tur||'—')}</div>
          </div>
          ${m.notlar?`<div style="font-size:.68rem;color:var(--ink3);margin-top:4px;padding-top:4px;border-top:1px dashed var(--card2)">${esc(m.notlar)}</div>`:''}
        </div>`;
      }
    });
    el.innerHTML=html;
  } catch(e){
    el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}<br><button class="btn btn-g" style="margin-top:12px" onclick="tumStokHareketleriniGoster()">Tekrar Dene</button></div>`;
  }
}

async function loadStokPanel_DEPRECATED(){
  const el=document.getElementById('stok-panel-body-OLD'); if(!el) return;
  const GRUPLAR=[
    {baslik:'💊 Sağlık',ikon:'💊',alt:[
      {ad:'Sperma',   filtre:s=>s.kategori==='Sperma'},
      {ad:'İlaç',     filtre:s=>['İlaç','Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç'].includes(s.kategori)},
      {ad:'Sarf & Ekipman', filtre:s=>['Ekipman','Sarf','Malzeme'].includes(s.kategori)},
    ]},
    {baslik:'🌾 Yem',ikon:'🌾',alt:[
      {ad:'Yem & Katkı', filtre:s=>s.kategori==='Yem'},
    ]},
  ];
  let html='';
  // Arama filtresi DOM tabanlı (stokFiltrele), input panel-body'nin üstünde
  GRUPLAR.forEach(grup=>{
    const grupStok=stok.filter(s=>grup.alt.some(a=>a.filtre(s)));
    if(!grupStok.length && grup.baslik.includes('Yem')){
      html+=`<div style="background:var(--bg2);border:1px dashed var(--bg3);border-radius:12px;padding:14px;margin-bottom:10px;opacity:.5">
        <div style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.07em">${grup.baslik}</div>
        <div style="font-size:.75rem;color:var(--ink3);margin-top:6px">Yakında — yem modülü</div>
      </div>`;
      return;
    }
    html+=`<div class="stok-group" style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.07em;margin:14px 0 8px">${grup.baslik}</div>`;
    grup.alt.forEach(alt=>{
      const liste=stok.filter(s=>alt.filtre(s));
      if(!liste.length) return;
      html+=`<div style="font-size:.65rem;font-weight:700;color:var(--ink3);margin:8px 0 4px;padding-left:4px">${alt.ad} (${liste.length})</div>`;
      html+=liste.map(s=>{
        const pct=Math.max(0,Math.min(100,(+s.baslangic_miktar||1)>0?(s.guncel/(+s.baslangic_miktar||1))*100:100));
        const barClr=_durumClr(s.durum);
        const durmTxt=_durumTxt(s.durum);
        return `<div class="stok-item" data-ad="${esc(s.urun_adi)}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid ${barClr};border-radius:10px;padding:11px 13px;margin-bottom:7px">
          <div style="display:flex;justify-content:space-between;align-items:flex-start">
            <div style="flex:1">
              <div style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(s.urun_adi)}</div>
              <div style="font-size:.62rem;color:var(--ink3);margin-top:2px">${s.kategori||'—'} · Eşik: ${s.esik||0} ${s.birim||''}</div>
            </div>
            <div style="text-align:right;flex-shrink:0;margin-left:10px">
              <div style="font-size:1.3rem;font-weight:800;color:${barClr};line-height:1">${(s.guncel||0).toFixed(s.birim==='adet'?0:1)}</div>
              <div style="font-size:.6rem;color:var(--ink3)">${s.birim||''}</div>
            </div>
          </div>
          <div style="height:4px;background:var(--card2);border-radius:2px;margin-top:8px;overflow:hidden">
            <div style="height:100%;width:${pct}%;background:${barClr};border-radius:2px"></div>
          </div>
          <div style="display:flex;gap:6px;margin-top:8px">
            <button onclick="openStk('${s.id}')" style="flex:1;padding:6px;background:var(--green);color:#fff;border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">+ Stok Ekle</button>
            <button onclick="stokHareketGor('${s.id}')" style="flex:1;padding:6px;background:var(--card2);color:var(--ink3);border:none;border-radius:7px;font-size:.72rem;font-weight:700;cursor:pointer">Hareketler</button>
          </div>
        </div>`;
      }).join('');
    });
  });
  el.innerHTML=html||'<div class="empty">Kayıt yok</div>';
}
async function loadStokList(){
  const el=document.getElementById('stok-list-body'); if(!el) return;
  try {
    await loadStock();
    if(!getState('stock').length){
      el.innerHTML='<div style="text-align:center;padding:12px;color:var(--ink3);font-size:.78rem">📦 Henüz stok ürünü eklenmemiş<br><button class="sh-link" onclick="openM(\'m-stok-add\')" style="margin-top:6px;display:block;margin:6px auto 0">İlk ürünü ekle →</button></div>';
      return;
    }
    const gruplar={
      'Sperma':getState('stock').filter(s=>s.kategori==='Sperma'||(s.urun_adi||'').toLowerCase().includes('sperma')||(s.urun_adi||'').toLowerCase().includes('doz')),
      'İlaç':getState('stock').filter(s=>s.kategori==='İlaç'||(!s.kategori&&!(s.urun_adi||'').toLowerCase().includes('sperma')&&!(s.urun_adi||'').toLowerCase().includes('ekipman'))),
      'Ekipman':getState('stock').filter(s=>s.kategori==='Ekipman'||(s.urun_adi||'').toLowerCase().includes('ekipman')),
    };
    const stokKart=(s)=>{
      const pct=Math.max(0,Math.min(100,s.esik>0?(s.guncel/((+s.baslangic_miktar||1)||1))*100:100));
      const barClr=_durumClr(s.durum);
      return `<div class="stok-item" data-ad="${esc(s.urun_adi)}" style="background:var(--card);border:1px solid var(--card3);border-radius:10px;padding:11px 13px;margin-bottom:7px">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <div><div style="font-weight:700;font-size:.88rem;color:var(--ink)">${esc(s.urun_adi)}</div>
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
  } catch(e){ if(el) el.innerHTML=`<div style="color:var(--red);padding:8px;font-size:.75rem">⚠️ ${esc(e.message)}</div>`; }
}
async function stokHareketGor(stokId){
  const s=getState('stock').find(x=>x.id===stokId); if(!s) return;
  const mvs=await getData('stok_hareket',m=>m.stok_id===stokId);
  mvs.sort((a,b)=>((b.tarih||b.id)||'').localeCompare((a.tarih||a.id)||''));
  const used=mvs.filter(m=>!m.iptal).reduce((t,m)=>t+(+m.miktar||0),0);
  const kalan=(+s.baslangic_miktar||0)-used;
  let box=document.getElementById('stok-hrkt-modal');
  if(!box){
    box=document.createElement('div');
    box.id='stok-hrkt-modal';
    box.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:200;display:flex;align-items:flex-end';
    box.onclick=e=>{if(e.target===box)box.remove();};
    document.body.appendChild(box);
  }
  box.innerHTML=`<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:70vh;overflow-y:auto;padding:16px">
    <div style="font-weight:800;font-size:1rem;margin-bottom:4px">${esc(s.urun_adi)}</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">Başlangıç: <b>${s.baslangic_miktar||0} ${s.birim||''}</b> · Kullanılan: <b>${used.toFixed(1)} ${s.birim||''}</b> · Kalan: <b style="color:${kalan<=(s.esik||0)?'#c0321a':'#2d6a2d'}">${kalan.toFixed(1)} ${s.birim||''}</b></div>
    ${mvs.length===0?'<div style="color:#999;text-align:center;padding:20px">Henüz hareket yok</div>':
      mvs.map(m=>{
        const _isIade=m.iptal&&(m.notlar||'').startsWith('drug_admin:');
        const _tarih=m.tarih?(new Date(m.tarih).toLocaleString('tr-TR',{day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'})):'';
        if(_isIade){
          return `<div style="padding:6px 0;border-bottom:1px solid var(--card3);font-size:.8rem;display:flex;justify-content:space-between;border-left:3px solid var(--red);padding-left:8px;opacity:.6">
            <div><div style="font-weight:600;color:var(--red);text-decoration:line-through">${m.tur||'Tedavi'}</div><div style="color:#888;font-size:.7rem">${_tarih}</div></div>
            <div style="text-align:right"><div style="font-weight:700;color:var(--red);text-decoration:line-through">-${Math.abs(m.miktar)} ${s.birim||''}</div></div>
          </div>
          <div style="padding:6px 0;border-bottom:1px solid var(--card3);font-size:.8rem;display:flex;justify-content:space-between;border-left:3px solid var(--green);padding-left:8px">
            <div><div style="font-weight:600;color:var(--green)">↩ Tedavi İadesi</div><div style="color:#888;font-size:.7rem">${_tarih}</div></div>
            <div style="text-align:right"><div style="font-weight:700;color:var(--green)">+${Math.abs(m.miktar)} ${s.birim||''}</div></div>
          </div>`;
        }
        if(m.iptal) return '';
        return `<div style="padding:8px 0;border-bottom:1px solid var(--card3);font-size:.8rem;display:flex;justify-content:space-between">
        <div><div style="font-weight:600">${esc(m.tur||'Kullanım')}</div><div style="color:#999;font-size:.7rem">${esc(m.notlar||'')}</div><div style="color:#888;font-size:.7rem;font-weight:600">${_tarih}</div></div>
        <div style="text-align:right"><div style="font-weight:700;color:${m.miktar<0?'var(--green)':'#c0321a'}">${m.miktar<0?'+':'-'}${Math.abs(m.miktar)} ${esc(s.birim||'')}</div></div>
      </div>`;}).join('')}
    <button onclick="document.getElementById('stok-hrkt-modal').remove()" style="width:100%;margin-top:12px;padding:12px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">Kapat</button>
  </div>`;
  box.style.display='flex';
}

// ──────────────────────────────────────────
// RAPORLAR
// ──────────────────────────────────────────
async function loadRaporlar(){
  const el=document.getElementById('raporlar-body'); if(!el) return;
  await _keepScroll(el,async()=>{
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const [animals,tohs,cases,diseaseRows,births,stock]=await Promise.all([
      idbGetAll('hayvanlar'),
      idbGetAll('tohumlama'),
      idbGetAll('cases'),
      idbGetAll('diseases'),
      idbGetAll('dogum'),
      idbGetAll('stok'),
    ]);
    const aktif=animals.filter(a=>a.durum==='Aktif');
    const gebe=tohs.filter(t=>t.sonuc==='Gebe');
    const gebeOran=aktif.length?Math.round(gebe.length/aktif.length*100):0;
    const tohToplam=tohs.length;
    const tohGebe=tohs.filter(t=>t.sonuc==='Gebe').length;

    const gebelikOran=tohToplam?Math.round(tohGebe/tohToplam*100):0;
    const abortlar=tohs.filter(t=>t.abort||t.sonuc==='Abort').length;

    // Irk dağılımı
    const irkMap={};
    aktif.forEach(a=>{ const irk=a.irk||'Bilinmiyor'; irkMap[irk]=(irkMap[irk]||0)+1; });
    const irkSorted=Object.entries(irkMap).sort((a,b)=>b[1]-a[1]);

    // B5: kategori grafik ve aktif vaka cases+diseases join'ından — eskiden
    // cases satırları 'diseases' değişkenine bağlanıyordu; cases'te kategori/
    // durum yok → grafik hep 'Diğer', 'Aktif Vaka' hep 0 (yeşil) gösteriyordu
    const disById={};
    diseaseRows.forEach(d=>{ disById[d.id]=d; });
    const aktifVaka=cases.filter(c=>c.status==='active');
    const katMap={};
    cases.forEach(c=>{ const k=disById[c.disease_id]?.category||'Diğer'; katMap[k]=(katMap[k]||0)+1; });
    const katSorted=Object.entries(katMap).sort((a,b)=>b[1]-a[1]);

    // Stok durumu (stok_tuketim_view'dan hazır gelir)
    const kritikStok=stock.filter(s=>s.stok_durum==='kritik');
    const negStk=stock.filter(s=>s.stok_durum==='tukendi');

    const statKart=(label,val,sub='',clr='var(--green)')=>`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;flex:1;min-width:130px">
      <div style="font-size:1.6rem;font-weight:800;color:${clr}">${val}</div>
      <div style="font-size:.78rem;font-weight:700;color:var(--ink);margin-top:2px">${label}</div>
      ${sub?`<div style="font-size:.65rem;color:var(--ink3);margin-top:2px">${sub}</div>`:''}
    </div>`;

    let h=`<div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px">
      ${statKart('Aktif Hayvan',aktif.length,'toplam: '+animals.length)}
      ${statKart('Gebe',gebe.length,`%${gebeOran} oran`,'var(--green)')}
      ${statKart('Gebelik Oranı','%'+gebelikOran,`${tohGebe}/${tohToplam} tohumlama`,gebelikOran>=60?'var(--green)':'var(--amber)')}
      ${statKart('Abort',abortlar,'toplam kayıt',abortlar>0?'var(--red)':'var(--ink3)')}
      ${statKart('Aktif Vaka',aktifVaka.length,'hastalık',aktifVaka.length>0?'var(--red)':'var(--green)')}
      ${statKart('Toplam Doğum',births.length,'')}
    </div>`;

    if(irkSorted.length){
      h+=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">🐄 Irk Dağılımı</div>
        ${irkSorted.map(([irk,sayi])=>{
          const pct=aktif.length?Math.round(sayi/aktif.length*100):0;
          return `<div style="margin-bottom:8px">
            <div style="display:flex;justify-content:space-between;font-size:.78rem;margin-bottom:3px">
              <span style="font-weight:600">${esc(irk)}</span><span style="color:var(--ink3)">${sayi} (${pct}%)</span>
            </div>
            <div style="height:6px;background:var(--card2);border-radius:3px;overflow:hidden">
              <div style="height:100%;width:${pct}%;background:var(--green);border-radius:3px"></div>
            </div>
          </div>`;
        }).join('')}
      </div>`;
    }

    if(katSorted.length){
      h+=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">🏥 Hastalık Kategorileri</div>
        ${katSorted.map(([kat,sayi])=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>${esc(kat)}</span><span style="font-weight:700;color:var(--red)">${sayi}</span>
        </div>`).join('')}
      </div>`;
    }

    if(negStk.length||kritikStok.length){
      h+=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">📦 Stok Durumu</div>
        ${negStk.map(s=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>🆘 ${esc(s.urun_adi)}</span><span style="font-weight:700;color:var(--red)">${(s.guncel_stok ?? 0).toFixed(1)} ${s.birim||''}</span>
        </div>`).join('')}
        ${kritikStok.map(s=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>⚠️ ${esc(s.urun_adi)}</span><span style="font-weight:700;color:var(--amber)">${(s.guncel_stok ?? 0).toFixed(1)} ${s.birim||''}</span>
        </div>`).join('')}
      </div>`;
    }

    if(!navigator.onLine){
      h+=`<div style="background:rgba(180,140,0,.08);border:1px solid rgba(180,140,0,.25);border-radius:10px;padding:10px 13px;font-size:.75rem;color:var(--amber)">
        ⚠️ Çevrimdışı — veriler yerel cache'ten. Online olunca yenileyin.
      </div>`;
    }
    el.innerHTML=h;
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
  });
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
      return `<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:10px;padding:11px 13px;margin-bottom:6px">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <div>
            <div style="font-weight:700;font-size:.88rem">${esc(kupe)}</div>
            <div style="font-size:.7rem;color:var(--ink3);margin-top:2px">${esc(a.irk||'—')} · ${esc(a.grup||'—')}</div>
          </div>
          <div style="text-align:right">
            <div style="font-size:.75rem;font-weight:700;color:${clr}">${esc(a.durum)}</div>
            <div style="font-size:.65rem;color:var(--ink3)">${fmtTarih(a.cikis_tarihi)||'—'}</div>
          </div>
        </div>
        ${a.cikis_sebebi?`<div style="font-size:.7rem;color:var(--ink3);margin-top:5px;padding-top:5px;border-top:1px solid var(--card2)">${esc(a.cikis_sebebi)}${a.satis_fiyati?' · '+a.satis_fiyati+' ₺':''}</div>`:''}
      </div>`;
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}

// ──────────────────────────────────────────
// GÖREV DETAY MODAL
// ──────────────────────────────────────────
async function openTaskDet(id){
  const all=await idbGetAll('gorev_log');
  const t=all.find(x=>x.id===id); if(!t) return;
  if(t.tamamlandi){ openDoneTaskDet(id); return; }
  // NOT: TOHUMLAMA_PLANLI eskiden burada erken return ile doğrudan tohumlama
  // formuna gidiyordu — detay modalı hiç açılmadığı için "🗑 Görevi İptal Et"
  // butonuna ULAŞILAMIYORDU ve görevin tek çıkışı gerçekten tohumlamaktı.
  // Artık modal normal açılıyor; tamamla butonu aşağıda forma yönlendiriliyor.
  _curTaskDet=t;
  const today=bugun();
  const hekim=[...HEKIMLER,...(_customHekimler||[])].find(h=>h.id===t.hekim_id);
  const isLate=t.hedef_tarih<today;
  const hayvanLabel=getState('animals').find(a=>a.id===t.hayvan_id);
  const tdHayvan=document.getElementById('td-hayvan');
  tdHayvan.textContent=(hayvanLabel?.kupe_no||hayvanLabel?.devlet_kupe)||(t.hayvan_id?.length>20?'Buzağı-'+t.hayvan_id.slice(-6):t.hayvan_id)||'GENEL GÖREV';
  if(t.hayvan_id){
    tdHayvan.dataset.hid=t.hayvan_id;
  } else {
    delete tdHayvan.dataset.hid;
  }
  const _acEl=document.getElementById('td-aciklama');if(_acEl){_acEl.textContent=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').label||t.aciklama;}catch(e){return t.aciklama;}})():t.aciklama||'';delete _acEl.dataset.diseaseAppended;}
  const meta=[];
  meta.push(`📅 ${fmtTarih(t.hedef_tarih)}${isLate?' ⚠️ Gecikmiş':''}`);
  if(hekim) meta.push(`👨‍⚕️ ${esc(hekim.ad)}`);
  if(t.stok_id) meta.push(`💊 ${esc(_stokAdi(t.stok_id))}`);
  meta.push(`🏷 ${(t.gorev_tipi||'DIGER').replace(/_/g,' ')}`);
  document.getElementById('td-meta').innerHTML=meta.map(m=>`<span style="background:var(--card2);padding:3px 8px;border-radius:10px">${m}</span>`).join('');
  const subs=all.filter(s=>s.parent_id===id&&!s.tamamlandi);
  const subsDone=all.filter(s=>s.parent_id===id&&s.tamamlandi);
  const subsEl=document.getElementById('td-subs');
  if(subs.length+subsDone.length>0){
    subsEl.style.display='block';
    subsEl.innerHTML=renderTaskDetSubs(subsDone,subs,id);
  } else { subsEl.style.display='none'; }

  // Butonları reset et
  const tamamBtn=document.getElementById('td-tamam-btn');
  const asiAcBtn=document.getElementById('td-asi-ac-btn');
  const asiForm =document.getElementById('td-asi-form');
  // rapelForm removed — merged into td-asi-form
  if(tamamBtn){
    tamamBtn.style.display='block'; tamamBtn.textContent='✅ Tamamlandı Olarak İşaretle';
    // Alt görevli grup: etiket toplu kapanışı anlatsın (yalnız açık PLAIN altlar sayılır —
    // özel tipler form ile kapanır). Alt görevsiz görevde mevcut etiket kalır (K4).
    if(subs.length+subsDone.length>0) tamamBtn.textContent=detayBtnEtiketi(subs.filter(s=>detayAltTiklanabilir(s)).length);
  }
  if(asiAcBtn)  asiAcBtn.style.display='none';
  if(asiForm)   asiForm.style.display='none';
  _curTaskVaccineId=null;

  // TOHUMLAMA_PLANLI: tek tıkla "tamamlandı" olmaz — gerçek tohumlama kaydı gerekir.
  // Buton etiketi bunu söylesin; detayTamamla() forma yönlendiriyor.
  if(t.gorev_tipi==='TOHUMLAMA_PLANLI'&&tamamBtn) tamamBtn.textContent='🐄 Tohumlamayı Kaydet';

  // ILERI_GEBE_ASI / ASI_RAPEL / ASI_HATIRLATMA: standart tamamla gizle, aşı butonu göster.
  // ASI_RAPEL özel olarak işlenmeli — generic 'Tamamlandı' görevi kayıtsız kapatıyordu
  // (vaccination_log'a kayıt düşmüyordu; kullanıcının tüm Coglavax rapelleri bu yoldaydı).
  const vaxSelWrap=document.getElementById('td-asi-vax-wrap');
  const vaxSel=document.getElementById('td-asi-vax');
  if(vaxSelWrap) vaxSelWrap.style.display='none';
  if(vaxSel) vaxSel.value='';
  const topluAlan=document.getElementById('td-toplu-alani');
  if(topluAlan){ topluAlan.style.display='none'; topluAlan.innerHTML=''; }
  _asiFormVaxKur(null); // önceki görevden kalan ad/doz'u temizle (stale name fix)
  // Toplu görev (parent): aşı listesi + hepsini uygula
  if(t.gorev_tipi==='ASI_PLANLI' && !t.stok_id && topluAlan){
    if(tamamBtn) tamamBtn.style.display='none';
    if(asiAcBtn) asiAcBtn.style.display='block';
    const adiEl=document.getElementById('td-asi-adi');
    if(adiEl) adiEl.textContent='Toplu aşı görevi';
    try{
      const children=((await getData('gorev_log',c=>c.parent_id===t.id&&!c.tamamlandi&&!c.iptal))||[]);
      const doneChildren=((await getData('gorev_log',c=>c.parent_id===t.id&&c.tamamlandi))||[]);
      const stockRows=(await getData('stok'))||[];
      const hmvs=(await getData('stok_hareket'))||[];
      _curTaskTopluChildren=children;
      const tarihEl=document.getElementById('td-asi-tarih');
      const todayStr=bugun();
      if(tarihEl){tarihEl.value=todayStr;tarihEl.max=todayStr;}
      if(!children.length){
        topluAlan.innerHTML='<div style="font-size:.75rem;color:var(--green)">✅ Tüm aşılar uygulandı</div>';
        topluAlan.style.display='block';
        if(asiAcBtn) asiAcBtn.style.display='none';
      } else {
        const kalanlar=_asiStokKalanlar(children.map(c=>({id:c.stok_id,stock_item_id:c.stok_id})),stockRows,hmvs);
        topluAlan.innerHTML='<div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:4px">Aşılar ('+children.length+' kaldı'+(doneChildren.length?', '+doneChildren.length+' uygulandı':'')+')</div>'
          +children.map(c=>{
            const kalan=kalanlar[c.stok_id];
            const kalanClr=kalan==null?'var(--ink3)':(kalan<=0?'var(--red2)':'var(--green)');
            const kalanTxt=kalan==null?'':`<span style="color:${kalanClr};font-weight:700;margin-left:6px">kalan ${kalan} ml</span>`;
            return `<div style="display:flex;align-items:center;gap:6px;padding:6px 8px;background:var(--bg);border-radius:8px;margin-bottom:5px">
              <span style="flex:1;min-width:0;font-size:.78rem;font-weight:600;color:var(--ink)">${esc(c.aciklama||'Aşı')}</span>${kalanTxt}
              <button class="btn btn-g" style="width:auto;padding:5px 10px;font-size:.7rem" onclick="topluTekUygula('${escAttr(c.id)}')">Uygula</button></div>`;
          }).join('')
          +`<button class="btn btn-g" style="margin-top:4px" onclick="topluHepsiniUygula()">💉 Hepsini Uygula (${children.length})</button>`;
        topluAlan.style.display='block';
      }
    }catch(e){ console.warn('toplu görev:',e.message); }
    const tarihEl2=document.getElementById('td-asi-tarih');
    if(tarihEl2){tarihEl2.value=bugun();tarihEl2.max=bugun();}
  } else if(t.gorev_tipi==='ASI_PLANLI'||t.gorev_tipi==='ILERI_GEBE_ASI'||t.gorev_tipi==='ASI_RAPEL'||t.gorev_tipi==='ASI_HATIRLATMA'){
    if(tamamBtn) tamamBtn.style.display='none';
    if(asiAcBtn) asiAcBtn.style.display='block';
    try{
      const vaccines=await getData('vaccines');
      const vax=_asiVaccineCoz(t,vaccines);
      if(vax){
        _curTaskVaccineId=vax.id;
        _asiFormVaxKur(vax);
        // Planlı görevde planlanan doz, katalog standart dozunu ezer
        if(t.gorev_tipi==='ASI_PLANLI'&&t.miktar){ const pd=document.getElementById('td-asi-doz'); if(pd) pd.value=t.miktar; }
        // Gerçek stok entegrasyonu: görevin çekileceği stoktaki kalan miktar
        try{
          const kalan=await _asiStokKalan(vax);
          const di=document.getElementById('td-asi-doz-info');
          if(di&&kalan!=null){
            di.textContent='Kalan: '+kalan+' '+(vax.unit||'ml');
            di.style.color=kalan<=0?'var(--red2)':'var(--green)';
          }
        }catch(e2){ console.warn('stok kalan:',e2.message); }
      } else {
        // Aşı çözümlenemedi (manuel görev vb.) — formda seçim listesi aç, ölü nokta yok
        _curTaskVaccineId=null;
        if(vaxSelWrap&&vaxSel){
          vaxSel.innerHTML='<option value="">— Aşı seçin —</option>'
            +(vaccines||[]).map(v=>`<option value="${escAttr(v.id)}">${esc(v.name||v.id)}</option>`).join('');
          vaxSelWrap.style.display='block';
        }
      }
    }catch(e){ console.warn('vaccine lookup:',e.message); }
    const tarihEl=document.getElementById('td-asi-tarih');
    const todayStr=bugun();
    if(tarihEl){tarihEl.value=todayStr;tarihEl.max=todayStr;}
  }

  // TEDAVI_GUN: standart tamamla gizle, detay panel + tedavi butonu göster
  const tedaviGunBtn=document.getElementById('td-tedavi-gun-btn');
  const tedaviPanel=document.getElementById('td-tedavi-gun-panel');
  const uygNotuEl=document.getElementById('td-uygulayici-notu');
  if(t.gorev_tipi==='TEDAVI_GUN'){
    if(tamamBtn) tamamBtn.style.display='none';
    if(tedaviGunBtn) tedaviGunBtn.style.display='block';
    if(tedaviPanel) tedaviPanel.style.display='block';
    if(uygNotuEl) uygNotuEl.value='';
    // Notlar + ilaç listesi async yükle
    try{
      let meta={};
      try{ meta=JSON.parse(t.aciklama||'{}'); }catch(e){}
      const dayId=meta.day_id;
      if(dayId){
        await pullTables(['drug_administrations','treatment_days','cases','stok','diseases','drug_products']);
        const [allAdmins,allDays,allCases,allStok,allDiseases,allProducts]=await Promise.all([
          idbGetAll('drug_administrations'),
          idbGetAll('treatment_days'),
          idbGetAll('cases'),
          idbGetAll('stok'),
          idbGetAll('diseases'),
          idbGetAll('drug_products').catch(()=>[]),
        ]);
        const stokMap=Object.fromEntries(allStok.map(s=>[s.id,s.urun_adi||s.id]));
        const prodMap=Object.fromEntries(allProducts.map(p=>[p.id,p.brand_name||'']));
        const dayDrugs=allAdmins.filter(da=>da.treatment_day_id===dayId);
        const day=allDays.find(d=>d.id===dayId);
        const theCase=day?allCases.find(c=>c.id===day.case_id):null;
        const disease=theCase?allDiseases.find(d=>d.id===theCase.disease_id):null;
        // Teshis adını hem başlığa hem panele ekle
        const acEl=document.getElementById('td-aciklama');
        if(acEl&&disease?.name&&!acEl.dataset.diseaseAppended){acEl.textContent+=' · '+disease.name;acEl.dataset.diseaseAppended='1';}
        const diseaseBadgeHtml=disease?.name?`<div style="font-size:.7rem;font-weight:700;color:var(--red);background:rgba(192,50,26,.08);padding:4px 10px;border-radius:7px;margin-bottom:10px;display:inline-block">🏥 ${esc(disease.name)}</div>`:'';

        // Master planlayıcı notu
        const planWrap=document.getElementById('td-plan-notu-wrap');
        const planEl=document.getElementById('td-plan-notu');
        if(theCase?.plan_notu&&planEl){planEl.textContent=theCase.plan_notu;if(planWrap)planWrap.style.display='block';}
        else if(planWrap) planWrap.style.display='none';
        // Gün planlayıcı notu
        const gunWrap=document.getElementById('td-gun-notu-wrap');
        const gunEl=document.getElementById('td-gun-notu');
        if(day?.notes&&gunEl){gunEl.textContent=day.notes;if(gunWrap)gunWrap.style.display='block';}
        else if(gunWrap) gunWrap.style.display='none';
        // İlaç listesi
        const ilacEl=document.getElementById('td-ilac-listesi');
        if(ilacEl){
          if(dayDrugs.length){
            ilacEl.innerHTML=diseaseBadgeHtml+`<div style="font-size:.62rem;font-weight:700;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:8px">💊 İlaçlar — ${dayDrugs.length} kalem</div>`
              +dayDrugs.map(da=>`<div class="td-ilac-row" data-admin-id="${da.id}" data-uygulanmadi="false" onclick="toggleTedaviIlac('${da.id}',this)" style="display:flex;align-items:center;gap:10px;padding:10px 12px;background:var(--card2);border-radius:10px;margin-bottom:6px;cursor:pointer;transition:background .15s;-webkit-tap-highlight-color:transparent">
                <div id="td-ic-${da.id}" style="width:26px;height:26px;border-radius:50%;background:var(--green);display:flex;align-items:center;justify-content:center;flex-shrink:0;transition:background .2s,transform .15s">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>
                </div>
                <div style="flex:1;min-width:0">
                  <div style="font-size:.88rem;font-weight:600;color:var(--ink);line-height:1.2">${esc(prodMap[da.drug_product_id]||stokMap[da.stok_id]||'İlaç')}</div>
                  <div style="font-size:.7rem;color:var(--ink3);margin-top:1px">${da.dose}${da.unit}${da.route?' · <b>'+da.route+'</b>':''}</div>
                  ${da.notes?`<div style="font-size:.68rem;color:var(--ink3);margin-top:3px;font-style:italic;opacity:.8">📝 ${esc(da.notes)}</div>`:''}
                </div>
                <div id="td-ic-lbl-${da.id}" style="font-size:.65rem;font-weight:700;color:var(--green);min-width:52px;text-align:right;transition:color .2s">Uygulandı</div>
              </div>`).join('');
          } else {
            ilacEl.innerHTML=diseaseBadgeHtml+'<div style="font-size:.8rem;color:var(--ink3);padding:6px 0">İlaç planı yok</div>';
          }
        }
      }
    }catch(e){ console.warn('TEDAVI_GUN detay yüklenemedi:',e.message); }
  } else {
    if(tedaviGunBtn) tedaviGunBtn.style.display='none';
    if(tedaviPanel) tedaviPanel.style.display='none';
  }

  // Rapel görevi: parent_id varsa tarih picker göster
  if(t.parent_id&&t.gorev_tipi==='ILERI_GEBE_ASI'){
    try{
      const parent=all.find(p=>p.id===t.parent_id);
      if(parent&&parent.tamamlanma_tarihi){
        const pd=new Date(parent.tamamlanma_tarihi);
        const minD=new Date(pd); minD.setDate(minD.getDate()+14);
        const maxD=new Date(pd); maxD.setDate(maxD.getDate()+21);
        const fmt=_ymd;
        const rapelTarihEl=document.getElementById('td-rapel-tarih');
        if(rapelTarihEl){
          rapelTarihEl.min=fmt(minD);
          rapelTarihEl.max=fmt(maxD);
          rapelTarihEl.value=t.hedef_tarih||fmt(maxD);
        }
        const rapelInfo=document.getElementById('td-rapel-info');
      if(rapelInfo){
        rapelInfo.style.display='block';
        const goster=document.getElementById('td-rapel-tarih-goster');
        if(goster) goster.textContent=t.hedef_tarih?fmtTarih(t.hedef_tarih):fmt(maxD);
        // Reset edit state
        const editDiv=document.getElementById('td-rapel-edit');
        if(editDiv) editDiv.style.display='none';
        const duzenleBtn=document.getElementById('td-rapel-duzenle-btn');
        if(duzenleBtn) duzenleBtn.style.display='inline';
      }
      }
    }catch(e){ console.warn('parent lookup:',e.message); }
  }

  openM('m-task-det');

  // BUG-059 — EKG ribbon + seans kartları (sadece TEDAVI_GUN + seans verisi varsa)
  if (t.gorev_tipi === 'TEDAVI_GUN') {
    try {
      let _bugMeta = {};
      try { _bugMeta = JSON.parse(t.aciklama || '{}'); } catch (e) {}
      if (_bugMeta.day_id) {
        await renderTedaviGunSeanslar(_bugMeta.day_id);
      }
    } catch (e) { console.warn('BUG-059 ribbon render:', e.message); }
  }
}
async function detayTamamla(){
  if(!_curTaskDet) return;
  if(_curTaskDet.gorev_tipi==='TOHUMLAMA_PLANLI') return openPlanliTohumlama(_curTaskDet);
  // §3: etken_kod varsa ama stok_id yoksa → önce stok seçtir
  if (_curTaskDet.etken_kod && !_curTaskDet.stok_id) {
    return _gorevStokSecVeTamamla(_curTaskDet);
  }
  // Bölünme fix'i: açık PLAIN alt görev varsa grup tamamlama — ana görev tek başına
  // kapatılamaz (kalan çocuklar top-level karta bölünürdü, analiz §2). Özel tipli
  // altlar açıkken parent-only yol çalışır: onlar form ile kapanır, RPC bypass edilmez.
  const acikSafAltlar=(await idbGetAll('gorev_log')).filter(s=>s.parent_id===_curTaskDet.id&&!s.tamamlandi&&!s.iptal&&detayAltTiklanabilir(s));
  if(acikSafAltlar.length) return grupTamamla(_curTaskDet,acikSafAltlar);
  const btn=document.getElementById('td-tamam-btn');
  if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
  try {
    await doneTask(_curTaskDet.id,_curTaskDet.hayvan_id||'',_curTaskDet.stok_id||'',+_curTaskDet.miktar||0,_curTaskDet.padok_hedef||'',{disabled:false,innerHTML:''});
    closeM('m-task-det');
  } catch(e){ toast(e.message,true); }
  if(btn){btn.disabled=false;btn.textContent='✅ Tamamlandı Olarak İşaretle';}
}

// §3: Görev detayında stok seçimi (etken_kod varsa, stok_id boşsa)
async function _gorevStokSecVeTamamla(gorev){
  const stoklar = await idbGetAll('stok');
  const ilaclar = await _etkenFiltrele(gorev.etken_kod, stoklar);
  if (!ilaclar.length) {
    toast(`"${gorev.etken_kod}" için uygun stok bulunamadı.`, true);
    return;
  }

  let mini = document.getElementById('proto-mini');
  if (mini) mini.remove();
  mini = document.createElement('div');
  mini.id = 'proto-mini';
  mini.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:500;display:flex;align-items:flex-end';
  mini.onclick = e => { if (e.target === mini) mini.remove(); };

  const stokOpts = ilaclar.map(s => `<option value="${s.id}">${esc(s.urun_adi)} (${s.birim||''})</option>`).join('');
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin'].map(r => `<option value="${r}">${r}</option>`).join('');

  mini.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:4px">💊 Görev Tamamlama — Stok Seç</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">${esc(gorev.aciklama||'')} · ${esc(gorev.etken_kod)}</div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Stok</label>
    <select id="pu-stok" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${stokOpts}</select>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Doz</label><input id="pu-doz" type="number" step="0.1" value="10" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Birim</label><input id="pu-birim" value="ml" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
    </div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Rota</label>
    <select id="pu-rota" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:12px;font-size:.8rem">${rotaOpts}</select>
    <button data-padok="${escAttr(gorev.padok_hedef||'')}" onclick="_gorevStokTamamlaSubmit('${gorev.id}','${gorev.hayvan_id||''}',this.dataset.padok)" class="btn" style="width:100%;padding:10px;font-weight:700">Tamamla</button>
  </div>`;
  document.body.appendChild(mini);
  if (ilaclar[0]) _puDozPrefill(ilaclar[0].id);
  document.getElementById('pu-stok')?.addEventListener('change', e => _puDozPrefill(e.target.value));
}

async function _gorevStokTamamlaSubmit(gorevId, hayvanId, padokHedef){
  const stok = document.getElementById('pu-stok')?.value;
  const doz = parseFloat(document.getElementById('pu-doz')?.value);
  const birim = document.getElementById('pu-birim')?.value;
  const rota = document.getElementById('pu-rota')?.value;
  if (!stok || !doz || !birim) { toast('Stok ve doz alanlarını doldurun', true); return; }

  try {
    await rpc('hizli_uygulama', {
      p_hayvan_id: hayvanId, p_stok_id: stok, p_doz: doz,
      p_birim: birim || 'ml', p_rota: rota || 'IM', p_notlar: 'Görev tamamlama'
    });
    const res = await rpc('gorev_tamamla', { p_gorev_id: gorevId, p_padok_hedef: padokHedef || null });
    if (res?.ok) {
      toast('✅ Görev tamamlandı');
      document.getElementById('proto-mini')?.remove();
      closeM('m-task-det');
      await pullTables(['hayvanlar','gorev_log']).catch(()=>{});
      _islemSonrasiRefresh();
      loadTasks(_curTaskFilter||'today',null,{skipPull:true});
      loadDash();
    } else {
      toast(res?.mesaj || 'Hata', true);
    }
  } catch(e) { toast('Hata: '+e.message, true); }
}
function toggleTedaviIlac(adminId, el){
  const isRed = el.dataset.uygulanmadi === 'true';
  const nowRed = !isRed;
  el.dataset.uygulanmadi = nowRed ? 'true' : 'false';
  const iconEl = document.getElementById('td-ic-'+adminId);
  const lblEl = document.getElementById('td-ic-lbl-'+adminId);
  if(iconEl){
    iconEl.style.background = nowRed ? '#ef4444' : 'var(--green)';
    iconEl.style.transform = 'scale(1.15)';
    setTimeout(()=>{ if(iconEl) iconEl.style.transform='scale(1)'; }, 150);
    iconEl.innerHTML = nowRed
      ? `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M18 6L6 18M6 6l12 12"/></svg>`
      : `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>`;
  }
  if(lblEl){
    lblEl.style.color = nowRed ? '#ef4444' : 'var(--green)';
    lblEl.textContent = nowRed ? 'Uygulanmadı' : 'Uygulandı';
  }
  el.style.background = nowRed ? '#fff5f5' : 'var(--card2)';
}

async function gorevTedaviGunDone(){
  if(!_curTaskDet) return;
  // Uygulanmadı işaretli ilaçları topla
  const rows = document.querySelectorAll('#m-task-det .td-ilac-row[data-uygulanmadi="true"]');
  const uygulanmadiIds = Array.from(rows).map(r=>r.dataset.adminId).filter(Boolean);
  const totalRows = document.querySelectorAll('#m-task-det .td-ilac-row').length;
  if(uygulanmadiIds.length > 0){
    openConfirm(
      'Eksik Uygulama',
      `${uygulanmadiIds.length}/${totalRows} ilaç uygulanmadı olarak işaretlendi. Stok iadesi yapılacak. Devam?`,
      () => _tedaviGunExecute(uygulanmadiIds)
    );
    return;
  }
  await _tedaviGunExecute([]);
}

async function _tedaviGunExecute(uygulanmadiIds){
  const btn=document.getElementById('td-tedavi-gun-btn');
  if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
  const uygNotu=document.getElementById('td-uygulayici-notu')?.value?.trim()||null;
  try {
    let meta={};
    try { meta=JSON.parse(_curTaskDet.aciklama||'{}'); } catch(e){}
    if(!meta.day_id){ toast('❌ Tedavi günü ID bulunamadı', true); return; }
    await rpc('treatment_day_tamamla', {
      p_day_id: meta.day_id,
      p_not: uygNotu,
      p_uygulanmadi_ids: uygulanmadiIds.length ? uygulanmadiIds : null
    });
    await rpc('gorev_tamamla', { p_gorev_id: _curTaskDet.id });
    const msg = uygulanmadiIds.length
      ? `✅ Tamamlandı — ${uygulanmadiIds.length} ilaç iade edildi`
      : '✅ Tedavi günü tamamlandı';
    toast(msg);
    closeM('m-task-det');
    await pullTables(['treatment_days','gorev_log','drug_administrations','stok_hareket','stok']);
    loadTasks(_curTaskFilter||'today',null,{skipPull:true});
    loadDash();
    if(typeof _curCase !== 'undefined' && _curCase) await renderCaseTimeline(_curCase.id);
  } catch(e){ toast('❌ ' + e.message, true); }
  if(btn){btn.disabled=false;btn.textContent='✅ Tedavi Gününü Tamamla';}
}
function asiFormAc(){
  document.getElementById('td-asi-form').style.display='block';
  document.getElementById('td-asi-ac-btn').style.display='none';
}
async function asiUygulaVeTamamla(){
  if(!_curTaskDet){ toast('Görev bulunamadı',true); return; }
  // Aşı id: çözümlenmiş (_curTaskVaccineId) ya da formdaki seçim listesinden
  const vaxSel=document.getElementById('td-asi-vax');
  const secilenId=(vaxSel&&vaxSel.value)?vaxSel.value:_curTaskVaccineId;
  if(!secilenId){ toast('Aşı seçin',true); return; }
  const btn=document.getElementById('td-asi-uygula-btn');
  if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
  try{
    const tarih=document.getElementById('td-asi-tarih').value||bugun();
    const dozRaw=document.getElementById('td-asi-doz').value;
    const doz=dozRaw?parseFloat(dozRaw):null;
    let rapelTarih=null;
    if(_curTaskDet.gorev_tipi==='ASI_PLANLI'){
      // Planlı aşı: plan rezervasyonu kapatılır + gerçek uygulama yazılır (tek düşüm, atomik)
      const res=await rpc('asi_planli_tamamla',{
        p_gorev_id:  _curTaskDet.id,
        p_tarih:     tarih,
        p_doz:       doz,
        p_vaccine_id:secilenId,
      });
      if(!res||res.ok===false){ toast(_trErr(res?.mesaj||'Hata'),true); return; }
      rapelTarih=res.next_due||null;
    } else if(_curTaskDet.gorev_tipi==='ILERI_GEBE_ASI'){
      const res=await rpc('ileri_gebe_asi_tamamla',{
        p_gorev_id:  _curTaskDet.id,
        p_vaccine_id:secilenId,
        p_tarih:     tarih,
        p_doz:       doz,
      });
      if(!res.ok){ toast(_trErr(res.mesaj||'Hata'),true); return; }
      rapelTarih=res.rapel_tarih||null;
    } else {
      // ASI_RAPEL / ASI_HATIRLATMA: uygulama kaydı + görevi kapat.
      // notes 'GorevID:' ile başlamalı DEĞİL — add_vaccination böylece sonraki
      // rapel görevini kendisi üretir (yıllık döngünün mevcut konvansiyonu).
      const res=await rpc('add_vaccination',{
        p_animal_id: _curTaskDet.hayvan_id,
        p_vaccine_id:secilenId,
        p_date:      tarih,
        p_dose_override:doz,
        p_notes:     null,
      });
      if(!res||res.ok===false){ toast(_trErr(res?.mesaj||'Hata'),true); return; }
      await rpc('gorev_tamamla',{p_gorev_id:_curTaskDet.id});
      rapelTarih=res.next_due||null;
    }
    closeM('m-task-det');
    // stok+stok_hareket: rezervasyon flip'i ve gerçek kullanım stok kartına anında yansısın
    await pullTables(['gorev_log','vaccination_log','stok','stok_hareket']).catch(()=>{});
    updateTaskBadge();
    loadTasks(_curTaskFilter||'today',null,{skipPull:true});
    loadDash();
    const rapelStr=rapelTarih?fmtTarih(rapelTarih):null;
    toast(rapelStr?`✅ Aşı kaydedildi · Sonraki: ${rapelStr}`:'✅ Aşı kaydedildi');
  }catch(e){
    toast(_trErr(e.message),true);
  }finally{
    if(btn){btn.disabled=false;btn.textContent='Uygula ve Tamamla';}
  }
}
async function rapelTarihiKaydet(){
  if(!_curTaskDet) return;
  const tarihEl=document.getElementById('td-rapel-tarih');
  const yeniTarih=tarihEl?.value;
  if(!yeniTarih){ toast('Tarih seçin',true); return; }
  try{
    await rpc('gorev_guncelle',{p_id:_curTaskDet.id,p_hedef_tarih:yeniTarih});
    toast('📅 Rapel tarihi güncellendi');
    loadTasks(_curTaskFilter||'today');
  }catch(e){
    toast(_trErr(e.message),true);
  }
}
async function openTaskEdit(){
  if(!_curTaskDet) return;
  const t=_curTaskDet;
  document.getElementById('te-desc').value=t.aciklama||'';
  document.getElementById('te-tarih').value=t.hedef_tarih||'';
  document.getElementById('te-tip').value=t.gorev_tipi||'MANUEL';
  openM('m-task-edit');
}
async function detayIptal(){
  if(!_curTaskDet) return;
  const t=_curTaskDet;
  openConfirm('Görevi İptal Et','Bu görevi iptal etmek istediğinizden emin misiniz?',async()=>{
    await write('gorev_log',{...t,tamamlandi:true,tamamlanma_tarihi:new Date().toISOString(),iptal:true},'PATCH',`id=eq.${t.id}`);
    const subs=await getData('gorev_log',s=>s.parent_id===t.id&&!s.tamamlandi);
    for(const s of subs) await write('gorev_log',{...s,tamamlandi:true,iptal:true},'PATCH',`id=eq.${s.id}`);
    closeM('m-task-det');
    toast('🗑 Görev iptal edildi');
    updateTaskBadge();
    // planlı aşı rezervasyonunun iadesi stok kartına anında yansısın
    await pullTables(['gorev_log','stok','stok_hareket']).catch(()=>{});
    loadTasks(_curTaskFilter||'today');
    loadDash();
  });
}
async function openDoneTaskDet(id){
  const all=await idbGetAll('gorev_log');
  const t=all.find(x=>x.id===id); if(!t) return;
  _curTaskDet=t;
  const hayvan=getState('animals').find(a=>a.id===t.hayvan_id);
  const ddHayvan=document.getElementById('dd-hayvan');
  ddHayvan.textContent=(hayvan?.kupe_no||hayvan?.devlet_kupe)||t.hayvan_id||'GENEL';
  if(t.hayvan_id){
    ddHayvan.style.cursor='pointer';
    ddHayvan.dataset.hid=t.hayvan_id;
  } else {
    ddHayvan.style.cursor='';
    delete ddHayvan.dataset.hid;
  }
  document.getElementById('dd-aciklama').textContent=t.aciklama||'';
  const meta=[];
  meta.push(`📅 Hedef: ${fmtTarih(t.hedef_tarih)}`);
  meta.push(`✅ Tamamlandı: ${fmtTarih(t.tamamlanma_tarihi)}`);
  meta.push(`🏷 ${(t.gorev_tipi||'DIGER').replace(/_/g,' ')}`);
  document.getElementById('dd-meta').innerHTML=meta.map(m=>`<span style="background:var(--card2);padding:3px 8px;border-radius:10px">${m}</span>`).join('');
  const rapelEl=document.getElementById('dd-rapel');
  const rapelChild=all.find(c=>c.parent_id===id);
  if(rapelChild){
    rapelEl.style.display='block';
    rapelEl.innerHTML=rapelChild.tamamlandi
      ?`📅 Rapel: ${fmtTarih(rapelChild.hedef_tarih)} — <span style="color:var(--green)">✅ Yapıldı</span>`
      :`📅 Rapel: ${fmtTarih(rapelChild.hedef_tarih)} — <span style="color:var(--orange)">Bekliyor</span>`;
  } else { rapelEl.style.display='none'; }
  const geriBtn=document.getElementById('dd-geri-al-btn');
  const daysSince=Math.floor((Date.now()-new Date(t.tamamlanma_tarihi||0))/86400000);
  const childDone=rapelChild&&rapelChild.tamamlandi;
  if(daysSince>7||childDone){
    geriBtn.disabled=true;
    geriBtn.textContent=childDone?'Rapel yapılmış (geri alınamaz)':'7 günden eski';
  } else {
    geriBtn.disabled=false;
    geriBtn.textContent='↩️ Geri Al';
  }
  openM('m-done-det');
}
function gorevGeriAl(){
  if(!_curTaskDet) return;
  const t=_curTaskDet;
  openConfirm('Görevi Geri Al','Bu işlem aşı kaydını ve rapel görevini silecektir. Stok miktarı düzeltilecektir.',async()=>{
    const btn=document.getElementById('dd-geri-al-btn');
    if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
    try{
      const res=await rpc('gorev_geri_al',{p_gorev_id:t.id});
      if(!res.ok){ toast(_trErr(res.mesaj||'Hata'),true); return; }
      closeM('m-done-det');
      await pullTables(['gorev_log','vaccination_log','stok_hareket']).catch(()=>{});
      updateTaskBadge();
      loadTasks(_curTaskFilter||'today',null,{skipPull:true});
      loadDash();
      toast(`↩️ Görev geri alındı${res.silinen_rapel?' · Rapel silindi':''}`);
    }catch(e){
      toast(_trErr(e.message),true);
    }finally{
      if(btn){btn.disabled=false;btn.textContent='↩️ Geri Al';}
    }
  });
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
    // IDB boşsa önce Supabase'den çek
    if (navigator.onLine) {
      try { await pullTables(['drug_classes','drug_products','stok','stok_hareket']); } catch(e) { console.warn('pull drugs:', e.message); }
    }
    const stok = await idbGetAll('stok');
    const drugClasses  = await idbGetAll('drug_classes');
    const drugProducts = await idbGetAll('drug_products');
    // Her drug_product için stok miktarını (view'dan hazır)
    _drugsCache = drugProducts.map(dp => {
      const dc   = drugClasses.find(c => c.id === dp.drug_class_id) || {};
      const s    = stok.find(x => x.drug_product_id === dp.id);
      const guncel = s?.guncel_stok ?? null;
      return {
        id:               dp.id,
        name:             dp.brand_name,
        active_ingredient: dc.active_ingredient || '',
        group_name:       dc.group_name || '',
        class_name:       dc.class_name || '',
        drug_class_id:    dp.drug_class_id,
        default_unit:     dp.default_unit || (s?.birim) || 'ml',
        default_route:    dp.default_route || 'IM',
        stock_id:         s?.id || null,
        guncel,
        birim:            s?.birim || dp.default_unit || 'ml',
      };
    });
      // Fallback: drug_product_id olmayan eski stok kalemleri de ekle
      const linkedStokIds = new Set(_drugsCache.map(d => d.stock_id).filter(Boolean));
      const unlinkedStok = stok.filter(s =>
        !s.drug_product_id &&
        !linkedStokIds.has(s.id) &&
        ['Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç','İlaç','Diger Ilac','Ilac','Metabolik'].includes(s.kategori)
      );
      unlinkedStok.forEach(s => {
        const guncel = +(s.guncel_stok ?? s.baslangic_miktar ?? 0);
        _drugsCache.push({
          id: s.id, name: s.urun_adi, active_ingredient: '',
          group_name: s.kategori || '', class_name: '',
          drug_class_id: null, default_unit: s.birim || 'ml',
          default_route: 'IM', stock_id: s.id, guncel,
          birim: s.birim || 'ml', _legacy: true,
        });
      });
    _drugsCache.sort((a, b) => (b.guncel !== null ? b.guncel : -1) - (a.guncel !== null ? a.guncel : -1));
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
        <div class="hist-title">${esc(dis?.name || '?')}</div>
        <div class="hist-sub">${fmtTarih(c.start_date)} · <b style="color:${isActive ? 'var(--red)' : 'var(--green)'}">${isActive ? 'Aktif' : 'Kapalı'}</b></div>
        ${c.notes ? `<div class="hist-sub" style="margin-top:2px">${esc(c.notes)}</div>` : ''}
      </div>
    </div>`;
  }).join('');
}

// ── VAKA DETAY (CLN-03) ─────────────────────

async function openCaseDet(caseId) {
  const cases    = await idbGetAll('cases');
  const diseases = await idbGetAll('diseases');
  const c = cases.find(x => x.id === caseId);
  if (!c) { toast('Vaka bulunamadı', true); return; }
  _curCase = c;

  const disease = diseases.find(d => d.id === c.disease_id);
  const hayvan  = getState('animals').find(a => a.id === c.animal_id);
  const kupe    = hayvan ? (hayvan.kupe_no || hayvan.devlet_kupe || c.animal_id) : c.animal_id;

  const cdHayvan=document.getElementById('cd-hayvan');
  cdHayvan.textContent=kupe;
  if(hayvan){
    cdHayvan.dataset.hid=hayvan.id;
  } else {
    delete cdHayvan.dataset.hid;
  }
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

  // Geri Al butonu kontrolü — islem_log'da VAKA_ACILDI kaydı varsa göster
  let islemler = await idbGetAll('islem_log');
  let vakaIslem = islemler.find(l => l.tip === 'VAKA_ACILDI' && l.ref_id === caseId);
  if (!vakaIslem && aktif) {
    await pullTables(['islem_log']);
    islemler = await idbGetAll('islem_log');
    vakaIslem = islemler.find(l => l.tip === 'VAKA_ACILDI' && l.ref_id === caseId);
  }
  const geriAlBtn = document.getElementById('cd-geri-al-btn');
  if (geriAlBtn) {
    if (vakaIslem && aktif) {
      const diseaseName = disease?.name || '?';
      geriAlBtn.style.display = 'block';
      geriAlBtn.onclick = () => openGeriAl(vakaIslem.id, `Vaka geri alınacak: ${diseaseName} — tüm tedavi günleri silinir.`);
    } else {
      geriAlBtn.style.display = 'none';
    }
  }

  try { await loadDrugsCache(); } catch(e) { console.warn('loadDrugsCache hata:', e.message); }
  // Tedavi günlerini taze çek (kapat butonu ve timeline doğru görünsün)
  await pullTables(['treatment_days','drug_administrations','treatment_day_uygulamalar']).catch(()=>{});
  await renderCaseTimeline(caseId);
  _updateKapatBtn(caseId);
  openM('m-case-det');
}

function fmtGunSaat(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  return d.toLocaleDateString('tr-TR',{day:'2-digit',month:'2-digit'}) + ' ' +
         d.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'});
}

async function renderCaseTimeline(caseId) {
  const el = document.getElementById('cd-timeline');
  if (!el) return;
  // Re-render'da açık akordeonları + scroll'u koru (işlem sonrası modal başa dönmesin)
  const prevOpen = new Set([...el.querySelectorAll('.cd-acc.open')].map(a => a.id.replace('acc-', '')));
  const _sc = (typeof _findScroller === 'function') ? _findScroller(el) : null;
  const prevY = _sc ? _sc.scrollTop : 0;
  // İlk yüklemede "Yükleniyor" göster; re-render'da flash YOK (yoksa scroll başa kayar)
  if (!prevOpen.size) el.innerHTML = '<span style="color:var(--ink3);font-size:.78rem">Yükleniyor…</span>';
  try {
    const [allDays, allAdmins, allProducts, allStok, allSeans, allGorev] = await Promise.all([
      idbGetAll('treatment_days'),
      idbGetAll('drug_administrations'),
      idbGetAll('drug_products'),
      idbGetAll('stok'),
      idbGetAll('treatment_day_uygulamalar').catch(() => []),
      idbGetAll('gorev_log').catch(() => [])
    ]);
    // Planlı tohumlamanın kendi treatment_days satırı YOKTUR: ilaç günleri şablon
    // kalemlerinden doğar, tohumlama ise ayrı bir ofsette bağımsız bir gorev_log
    // satırıdır (canlıda 8/8 vakada ilaçsız bir güne düşüyor). Bu yüzden timeline'a
    // SANAL gün olarak enjekte edilir — durumun tek kaynağı görev satırının
    // kendisi kalır, ikinci bir kayıt üretilmez.
    const _tohPrefix = 'TEDAVI_SABLON_TOHUMLAMA:' + caseId + ':';
    const tohGorevler = allGorev
      .filter(g => g.gorev_tipi === 'TOHUMLAMA_PLANLI' && (g.kaynak || '').startsWith(_tohPrefix) && !g.iptal)
      .sort((a, b) => (a.hedef_tarih || '').localeCompare(b.hedef_tarih || ''));
    const days = allDays.filter(d => d.case_id === caseId).sort((a,b) => (a.treatment_date||'').localeCompare(b.treatment_date||''));
    const prodMap = {}; allProducts.forEach(p => { prodMap[p.id] = p; });
    const stokMap = {}; allStok.forEach(s => { stokMap[s.id] = s; });
    // Gün başına seanslar (saat bazlı plan) — sıralı, ilaç adı zenginleştirilmiş
    const seansByDay = {};
    allSeans.forEach(s => {
      if (!days.some(d => d.id === s.treatment_day_id)) return;
      (seansByDay[s.treatment_day_id] = seansByDay[s.treatment_day_id] || []).push(s);
    });
    const data = [];
    days.forEach(td => {
      const sessions = (seansByDay[td.id] || []).sort((a,b) => (a.planned_time||'').localeCompare(b.planned_time||''));
      sessions.forEach(s => {
        s.drug_name = prodMap[s.drug_product_id]?.brand_name || stokMap[s.stok_id]?.urun_adi || 'İlaç';
        s.planned_date = s.planned_date || td.treatment_date;
      });
      // Seansa bağlı drug_admins seans satırında gösterilir; burada sadece saatsiz (eski tip) ilaçlar
      const dayAdmins = allAdmins.filter(da => da.treatment_day_id === td.id && !da.seans_admin_id);
      const doneFields = { tamamlandi: td.tamamlandi, tamamlanma_tarihi: td.tamamlanma_tarihi, tamamlanma_notu: td.tamamlanma_notu, notes: td.notes, sessions };
      if (!dayAdmins.length) {
        data.push({ day_id: td.id, day_no: td.day_no, treatment_date: td.treatment_date, treatment_time: td.treatment_time || '', case_id: caseId, ...doneFields });
      } else {
        dayAdmins.forEach(da => {
          const dp = prodMap[da.drug_product_id];
          const s = stokMap[da.stok_id];
          data.push({ day_id: td.id, day_no: td.day_no, treatment_date: td.treatment_date, treatment_time: td.treatment_time || '', case_id: caseId, administration_id: da.id, drug: dp?.brand_name || s?.urun_adi || '?', dose: da.dose, unit: da.unit, route: da.route, drug_id: dp?.id, stok_id: da.stok_id, ...doneFields });
        });
      }
    });
    if (!data.length && !tohGorevler.length) {
      el.innerHTML = '<span style="color:var(--ink3);font-size:.78rem">Henüz tedavi günü yok</span>';
      return;
    }
    const byDay = {};
    data.forEach(r => {
      if (!byDay[r.day_id]) byDay[r.day_id] = { day_no: r.day_no, date: r.treatment_date, day_id: r.day_id, time: r.treatment_time || '', drugs: [], sessions: r.sessions || [], tamamlandi: r.tamamlandi, tamamlanma_tarihi: r.tamamlanma_tarihi, tamamlanma_notu: r.tamamlanma_notu, notes: r.notes };
      if (r.administration_id) byDay[r.day_id].drugs.push(r);
    });
    // Sanal tohumlama günlerini enjekte et. day_no, aynı/önceki tarihli gerçek
    // günlerin en büyüğünün 0.5 fazlası — mevcut `sort((a,b)=>a.day_no-b.day_no)`
    // sıralamasını bozmadan tohumlamayı doğru yere oturtur.
    tohGorevler.forEach(g => {
      const vid = 'toh-' + g.id;
      const oncekiMax = Object.values(byDay)
        .filter(d => !d._toh && (d.date || '') <= (g.hedef_tarih || ''))
        .reduce((m, d) => Math.max(m, d.day_no || 0), 0);
      byDay[vid] = {
        day_no: oncekiMax + 0.5, date: g.hedef_tarih, day_id: vid,
        time: (g.hedef_saat || '').slice(0, 5), drugs: [], sessions: [],
        tamamlandi: !!g.tamamlandi, tamamlanma_tarihi: g.tamamlanma_tarihi,
        tamamlanma_notu: null, notes: null, _toh: g,
      };
    });
  // Tarih gruplama: benzersiz tarihler sıralı grup numarası alır, aynı tarihtekiler A/B/C
  const SUFFIKLER = ['A','B','C','D','E','F','G'];
  const tarihSuffix = {};
  const tarihGunNo = {};
  // Benzersiz tarihleri sırala
  const benzersizTarihler = [...new Set(Object.values(byDay).map(d => d.date))].sort();
  // Her tarihe grup no ata
  const tarihGrupNo = {};
  benzersizTarihler.forEach((t, i) => { tarihGrupNo[t] = i + 1; });
  // Her tarihin kaç günü var
  const tarihCount = {};
  Object.values(byDay).forEach(day => { tarihCount[day.date] = (tarihCount[day.date]||0) + 1; });
  // Her güne no ve suffix ata
  const tarihKullanım = {};
  Object.values(byDay).sort((a,b) => a.date.localeCompare(b.date) || a.day_no - b.day_no).forEach(day => {
    const t = day.date;
    tarihGunNo[day.day_id] = tarihGrupNo[t];
    tarihKullanım[t] = (tarihKullanım[t]||0);
    tarihSuffix[day.day_id] = tarihCount[t] > 1 ? SUFFIKLER[tarihKullanım[t]] || String(tarihKullanım[t]+1) : '';
    tarihKullanım[t]++;
  });
  // Sıralı lock: önceki gün done değilse bu gün kilitli
  const sortedDays = Object.values(byDay).sort((a,b) => a.day_no - b.day_no);
  // Lock: sadece aktif vakalarda — kapalı vakalarda tüm günler açılabilir
  const lockAktif = _curCase?.status === 'active';
  sortedDays.forEach((day, idx) => {
    day._locked = lockAktif && idx > 0 && !sortedDays[idx-1].tamamlandi;
  });
  // Progress hesapla
  const totalDays = sortedDays.length;
  const doneDays  = sortedDays.filter(d => d.tamamlandi).length;
  const pct       = totalDays ? Math.round(doneDays / totalDays * 100) : 0;

  const progressHtml = totalDays > 0 ? `
    <div class="cd-progress">
      <span class="cd-progress-lbl">${doneDays}/${totalDays} Tamamlandı</span>
      <div class="cd-progress-track"><div class="cd-progress-fill" style="width:${pct}%"></div></div>
    </div>` : '';

  const aktif = _curCase?.status === 'active';
  const bugunTr = bugun();

  // Seans formu için gün verisini sakla (caseSeansFormAc okur)
  _cdDayData = {};

  el.innerHTML = progressHtml + '<div class="cd-tl-wrap">' +
    sortedDays.map(day => {
      const saatStr  = day.time ? `<span style="font-size:.68rem;color:var(--ink3);font-weight:400;margin-left:4px">${day.time.slice(0,5)}</span>` : '';
      const isDone   = day.tamamlandi;
      const isLocked = !isDone && day._locked;
      const tlCls    = isDone ? 'tl-done' : isLocked ? 'tl-locked' : 'tl-active';
      const openAttr = prevOpen.size
        ? (prevOpen.has(day.day_id) ? 'open' : '')
        : ((aktif && !isDone && day === sortedDays.find(d => !d.tamamlandi)) ? 'open' : '');
      const nodeIcon = isDone ? '✓' : '';
      const gunNo    = `Gün ${tarihGunNo[day.day_id]||day.day_no}${tarihSuffix[day.day_id]||''}`;

      // Seans planı durumu
      const toh          = day._toh || null;
      const sessions     = day.sessions || [];
      const seansKapali  = sessions.filter(s => s.uygulama_tamamlandi_at || s.uygulanmadi).length;
      const kilitliSeans = seansKapali > 0; // kapatılmış seans varsa plan değiştirilemez (RPC kuralı)
      // Sanal tohumlama günü _cdDayData'ya YAZILMAZ — seans/ilaç formları onu
      // gerçek bir gün sanıp üzerine yazmaya çalışmasın.
      if (!toh) _cdDayData[day.day_id] = { date: day.date, time: day.time, sessions, legacyDrugs: day.drugs, kilitli: kilitliSeans };

      // Başlık sağ taraf
      const seansBadge = toh
        ? `<span style="background:rgba(78,154,42,.1);color:var(--green);padding:2px 8px;border-radius:6px;font-size:.68rem;font-weight:700">🐄 Tohumlama</span>`
        : sessions.length && !isDone
        ? `<span style="background:rgba(42,107,181,.1);color:var(--blue);padding:2px 8px;border-radius:6px;font-size:.68rem;font-weight:700">⏰ ${seansKapali}/${sessions.length}</span>`
        : '';
      const badge = isDone
        ? `<span style="background:rgba(78,154,42,.12);color:var(--green);padding:2px 8px;border-radius:6px;font-size:.68rem;font-weight:700">✅ ${fmtGunSaat(day.tamamlanma_tarihi)}</span>`
        : isLocked
          ? `<span style="color:var(--ink3);font-size:.72rem">🔒</span>`
          : '';

      // Not satırı (treatment_days.notes)
      const notHtml = day.notes
        ? `<div class="cd-day-not">📝 ${esc(day.notes)}</div>`
        : '';

      // İlaç listesi — sadece saatsiz (eski tip) ilaçlar; seanslılar aşağıda
      const drugHtml = day.drugs.length
        ? `${sessions.length ? '<div class="cd-sec-lbl">💊 Hızlı ilaçlar (saatsiz)</div>' : ''}<div style="margin-top:2px">${day.drugs.map(d => `
            <div class="cd-drug-row" data-admin-id="${escAttr(d.administration_id)}">
              <div><span class="cd-drug-name">${esc(d.drug)}</span> <span class="cd-drug-meta">${esc(d.dose)} ${esc(d.unit)}${d.route?' · '+esc(d.route):''}</span></div>
              ${aktif && !isDone ? `<div style="display:flex;gap:2px">
                <button data-dose="${escAttr(d.dose)}" data-unit="${escAttr(d.unit)}" data-route="${escAttr(d.route||'')}" onclick="caseDrugDuzenle(this)" style="background:none;border:none;color:var(--blue);cursor:pointer;font-size:.85rem;padding:2px">✏️</button>
                <button data-admin-id="${escAttr(d.administration_id)}" onclick="caseDrugSil(this.dataset.adminId)" style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.85rem;padding:2px">🗑</button>
              </div>` : ''}
            </div>`).join('')}</div>`
        : ((sessions.length || toh) ? '' : `<span style="color:var(--ink3);font-size:.75rem;display:block;padding:4px 0">İlaç eklenmemiş</span>`);

      // Seans planı bölümü — şerit + satırlar
      const seansHtml = (!toh && sessions.length) ? `
        <div class="cd-sec-lbl">⏰ Seans Planı</div>
        ${renderSeansSerit(sessions, { today: day.date === bugunTr })}
        <div>${sessions.map(s => renderSeansRow(s, { readOnly: !aktif || isDone || isLocked })).join('')}</div>` : '';

      // Tohumlama kalemi — ilaç seansıyla aynı satır dilinde
      const tohState = toh
        ? (isDone ? 'done' : (day.date < bugunTr ? 'overdue' : (day.date === bugunTr ? 'now' : 'scheduled')))
        : '';
      const tohDurum = { done: '✓ Kaydedildi', overdue: '⚠ Gecikti', now: '⏱ Vakti geldi', scheduled: '⏳ Planlandı' }[tohState] || '';
      const tohHtml = toh ? `
        <div class="cd-sec-lbl">🐄 Üreme</div>
        <div class="seans-row s-${tohState}" data-gorev-id="${escAttr(toh.id)}">
          <span class="seans-saat">${esc(day.time || '—')}</span>
          <div class="seans-info">
            <div class="seans-ilac">🐄 Tohumlama</div>
            <div class="seans-meta">${esc(isDone ? tohDurum : 'Sperma kayıt sırasında seçilir · ' + tohDurum)}</div>
          </div>
          <span class="seans-chip s-${tohState}">${esc(tohDurum)}</span>
        </div>` : '';

      // Tohumlama günü kendi eylemlerini taşır: gün tamamla/sil/seans planla YOK.
      // Kayıt bugün düzelttiğimiz planlı tohumlama akışına gider, iptal tek tık.
      const tohActionsHtml = (toh && aktif && !isDone) ? `
        <div style="display:flex;gap:4px;flex-wrap:wrap;margin-top:8px;padding-top:8px;border-top:1px solid var(--card3);align-items:center">
          ${!isLocked ? `<button onclick="caseTohumlamaKaydet('${escAttr(toh.id)}')" style="flex:1;min-width:120px;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:700">🐄 Tohumlamayı Kaydet</button>` : ''}
          <button onclick="caseTohumlamaIptal('${escAttr(toh.id)}')" style="background:rgba(192,50,26,.06);color:var(--red);border:1px solid rgba(192,50,26,.15);border-radius:7px;padding:8px 9px;font-size:.8rem;cursor:pointer" title="Planlı tohumlamayı iptal et">🗑</button>
        </div>
        ${isLocked ? '<div style="margin-top:4px;font-size:.68rem;color:var(--ink3);padding:0 2px">⏳ Önceki gün tamamlanmadan tohumlama yapılamaz</div>' : ''}` : '';

      // Eylem çubuğu — seanslı günlerde gün "✅ Tamamla" yok (son seansla otomatik kapanır)
      const actionsHtml = !toh && aktif && !isDone ? `
        <div style="display:flex;gap:4px;flex-wrap:wrap;margin-top:8px;padding-top:8px;border-top:1px solid var(--card3);align-items:center">
          ${!isLocked && !sessions.length ? `<button onclick="caseDayTamamla('${day.day_id}')" style="flex:1;min-width:80px;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:700">✅ Tamamla</button>` : ''}
          ${!sessions.length ? `<button onclick="caseDrugFormAc('${day.day_id}')" style="flex:1;min-width:72px;background:var(--blue);color:#fff;border:none;border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:600">+ İlaç</button>` : ''}
          <button onclick="caseSeansEkleFormAc('${day.day_id}')" style="flex:1;min-width:72px;background:${sessions.length?'var(--card2)':'none'};color:var(--ink2);border:1px solid var(--card3);border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:600">⏰ ${sessions.length ? 'Seans Düzenle' : 'Seans Planla'}</button>
          <button onclick="caseDayNotAcById('${day.day_id}')" style="flex:1;min-width:64px;background:var(--card2);color:var(--ink2);border:1px solid var(--card3);border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer">📝 Not</button>
          <span style="display:flex;gap:2px;margin-left:auto">
            ${!sessions.length ? `<button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" style="background:none;border:1px solid var(--card3);border-radius:7px;padding:8px 9px;font-size:.8rem;color:var(--ink3);cursor:pointer" title="Saat ekle">🕐</button>` : ''}
            <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.06);color:var(--red);border:1px solid rgba(192,50,26,.15);border-radius:7px;padding:8px 9px;font-size:.8rem;cursor:pointer" title="Günü sil">🗑</button>
          </span>
        </div>
        ${isLocked ? '<div style="margin-top:4px;font-size:.68rem;color:var(--ink3);padding:0 2px">⏳ Önceki gün tamamlanmadan bu gün tamamlanamaz</div>' : ''}
        ${sessions.length && !isLocked ? '<div style="margin-top:4px;font-size:.68rem;color:var(--ink3);padding:0 2px">Son seans kapatılınca gün otomatik tamamlanır</div>' : ''}` : '';

      // data-not-b64: base64 encode ile özel karakter güvenliği
      const notB64 = day.notes ? btoa(unescape(encodeURIComponent(day.notes))) : '';

      const openCls = openAttr ? 'open' : '';
      return `
        <div class="cd-tl-item ${tlCls}">
          <div class="cd-tl-node">${nodeIcon}</div>
          <div class="cd-tl-content">
            <div class="cd-acc ${openCls}" id="acc-${day.day_id}">
              <div class="cd-acc-hdr" onclick="cdAccToggle('${day.day_id}')">
                <div class="cd-acc-title">
                  <span>${gunNo} — ${fmtTarih(day.date)}${saatStr}</span>
                </div>
                <div class="cd-acc-right">
                  ${seansBadge}
                  ${badge}
                  <span class="cd-acc-arrow">▸</span>
                </div>
              </div>
              <div class="cd-acc-body" id="drugs-${day.day_id}">
                <div class="cd-acc-body-inner" data-not-b64="${notB64}">
                  ${notHtml}
                  ${drugHtml}
                  ${seansHtml}
                  ${tohHtml}
                  ${actionsHtml}
                  ${tohActionsHtml}
                </div>
              </div>
            </div>
          </div>
        </div>`;
    }).join('') + '</div>';
  // Re-render sonrası scroll konumunu geri yükle (içerik yüksekliği benzer → başa kaymaz)
  if (_sc && prevY) _sc.scrollTop = prevY;
  // Bugünün şeritlerinde şimdi çizgisini canlı tut
  if (sortedDays.some(d => (d.sessions || []).length && d.date === bugunTr)) startNowCursorLoop();
  } catch(e) {
    el.innerHTML = `<span style="color:var(--red);font-size:.78rem">Yüklenemedi: ${esc(e.message)}</span>`;
  }
}

function caseDaySaatAc(dayId, currentTime) {
  let box = document.getElementById('saat-modal');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'saat-modal';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) box.remove(); };
  const saatVal = currentTime ? currentTime.slice(0,5) : '';
  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:14px">🕐 Tedavi Saatini Ayarla</div>
    <input type="time" id="saat-input" value="${saatVal}" style="width:100%;border:1.5px solid var(--card3);border-radius:10px;padding:12px;font-size:1.1rem;background:var(--card);color:var(--ink);outline:none;margin-bottom:12px">
    <div style="display:flex;gap:8px">
      <button onclick="caseDaySaatKaydet('${dayId}')" style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">Kaydet</button>
      <button onclick="document.getElementById('saat-modal').remove()" style="flex:1;padding:12px;background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">İptal</button>
    </div>
  </div>`;
  document.body.appendChild(box);
  setTimeout(() => document.getElementById('saat-input')?.focus(), 100);
}

async function caseDaySaatKaydet(dayId) {
  const timeVal = document.getElementById('saat-input')?.value;
  if (!timeVal) { toast('Saat seçin', true); return; }
  try {
    await rpc('update_treatment_time', { p_day_id: dayId, p_treatment_time: timeVal });
    document.getElementById('saat-modal')?.remove();
    toast('✅ Saat kaydedildi');
    await pullTables(['treatment_days']);
    if (_curCase) await renderCaseTimeline(_curCase.id);
  } catch(e) { toast('❌ ' + e.message, true); }
}

async function caseDayTamamla(dayId) {
  const btn = event?.target;
  if (btn) { btn.disabled = true; btn.textContent = '…'; }
  try {
    await rpc('treatment_day_tamamla', { p_day_id: dayId, p_not: null });
    toast('✅ Tedavi tamamlandı');
    await pullTables(['treatment_days','gorev_log']);
    if (_curCase) {
      await renderCaseTimeline(_curCase.id);
      _updateKapatBtn(_curCase.id);
    }
  } catch(e) { toast('❌ ' + e.message, true); if (btn) { btn.disabled = false; btn.textContent = '✅ Tamamla'; } }
}

function caseDayNotAc(dayId, mevcutNot) {
  let box = document.getElementById('not-modal');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'not-modal';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) box.remove(); };
  box.innerHTML = `
    <div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
      <div style="font-weight:800;font-size:.9rem;margin-bottom:12px">📝 Tedavi Notu</div>
      <textarea id="not-ta" rows="3" placeholder="Gözlem, reaksiyon, ek bilgi..."
        style="width:100%;border:1.5px solid var(--card3);border-radius:10px;padding:12px;font-size:.9rem;background:var(--card);color:var(--ink);outline:none;resize:none;box-sizing:border-box;margin-bottom:12px">${esc(mevcutNot||'')}</textarea>
      <div style="display:flex;gap:8px">
        <button onclick="caseDayNotKaydet('${dayId}')"
          style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">💾 Kaydet</button>
        <button onclick="document.getElementById('not-modal').remove()"
          style="flex:1;padding:12px;background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:10px;font-size:.9rem;cursor:pointer">İptal</button>
      </div>
    </div>`;
  document.body.appendChild(box);
  setTimeout(() => document.getElementById('not-ta')?.focus(), 100);
}

async function caseDayNotKaydet(dayId) {
  const not = document.getElementById('not-ta')?.value?.trim() || '';
  try {
    await rpc('treatment_day_not_guncelle', { p_day_id: dayId, p_notes: not || null });
    document.getElementById('not-modal')?.remove();
    toast('📝 Not kaydedildi');
    await pullTables(['treatment_days']);
    if (_curCase) await renderCaseTimeline(_curCase.id);
  } catch(e) { toast('❌ ' + e.message, true); }
}

function cdAccToggle(dayId) {
  const acc = document.getElementById('acc-' + dayId);
  if (!acc) return;
  const isOpen = acc.classList.contains('open');
  acc.classList.toggle('open', !isOpen);
}

function caseDayNotAcById(dayId) {
  const inner = document.querySelector(`#drugs-${dayId} .cd-acc-body-inner`);
  const b64 = inner?.dataset?.notB64 || '';
  const mevcutNot = b64 ? decodeURIComponent(escape(atob(b64))) : '';
  caseDayNotAc(dayId, mevcutNot);
}

async function _updateKapatBtn(caseId) {
  const btn = document.getElementById('cd-kapat-btn');
  if (!btn) return;
  const allDays = await idbGetAll('treatment_days');
  const caseDays = allDays.filter(d => d.case_id === caseId);
  const hepsiDone = caseDays.length === 0 || caseDays.every(d => d.tamamlandi);
  if (hepsiDone) {
    btn.disabled = false;
    btn.style.opacity = '';
    btn.title = '';
  } else {
    const kalan = caseDays.filter(d => !d.tamamlandi).length;
    btn.disabled = true;
    btn.style.opacity = '.45';
    btn.title = `${kalan} tedavi günü tamamlanmadan vaka kapatılamaz`;
  }
  // Erken kapat (stok iade): açık gün varken görünür, inline onay bölümü kapalı başlar
  const erkenBtn  = document.getElementById('cd-erken-kapat-btn');
  const erkenForm = document.getElementById('cd-erken-kapat-form');
  const aktif = _curCase?.status === 'active';
  if (erkenBtn)  erkenBtn.style.display = (aktif && !hepsiDone) ? 'block' : 'none';
  if (erkenForm) erkenForm.style.display = 'none';
}

async function caseGunEkle() {
  if (!_curCase) return;
  const today = new Date();
  const year = today.getFullYear();
  const month = today.getMonth();
  _gunSecimAy = month;
  _gunSecimYil = year;
  _gunSecimSecili = new Set();
  caseGunModalRender();
}

let _gunSecimAy = 0, _gunSecimYil = 0;
let _gunSecimSecili = new Set();

function caseGunModalRender() {
  let box = document.getElementById('gun-tarih-modal');
  if (!box) {
    box = document.createElement('div');
    box.id = 'gun-tarih-modal';
    box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:300;display:flex;align-items:flex-end';
    box.onclick = e => { if (e.target === box) box.remove(); };
    document.body.appendChild(box);
  }
  const ay = _gunSecimAy, yil = _gunSecimYil;
  const ilkGun = new Date(yil, ay, 1).getDay();
  const bosluk = (ilkGun + 6) % 7;
  const sonGun = new Date(yil, ay + 1, 0).getDate();
  const ayAdi = new Date(yil, ay, 1).toLocaleString('tr-TR', {month:'long', year:'numeric'});
  const bugunTr = bugun();

  let kareler = '';
  for (let i = 0; i < bosluk; i++) kareler += '<div></div>';
  for (let g = 1; g <= sonGun; g++) {
    const iso = yil + '-' + String(ay+1).padStart(2,'0') + '-' + String(g).padStart(2,'0');
    const secili = _gunSecimSecili.has(iso);
    const bugunMu = iso === bugunTr;
    kareler += '<div onclick="caseGunToggle(&#39;' + iso + '&#39;)" style="aspect-ratio:1;display:flex;align-items:center;justify-content:center;border-radius:8px;font-size:.82rem;font-weight:700;cursor:pointer;' +
      (secili ? 'background:var(--green);color:#fff;' : bugunMu ? 'background:rgba(78,154,42,.15);color:var(--green);border:1.5px solid var(--green);' : 'color:var(--ink);') +
      '">' + g + '</div>';
  }

  const seciliList = [..._gunSecimSecili].sort();
  const seciliHtml = seciliList.length
    ? '<div style="display:flex;flex-wrap:wrap;gap:4px;margin-bottom:10px">' +
      seciliList.map(d => '<span style="background:rgba(78,154,42,.12);border:1px solid var(--green);border-radius:6px;padding:2px 8px;font-size:.72rem;font-weight:700;color:var(--green)">' + d.slice(5).replaceAll('-','.') + '</span>').join('') +
      '</div>'
    : '<div style="font-size:.75rem;color:var(--ink3);margin-bottom:10px">Tarih secin</div>';

  box.innerHTML =
    '<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:16px;max-height:85vh;overflow-y:auto">' +
    '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">' +
    '<button onclick="_gunSecimAy--;if(_gunSecimAy<0){_gunSecimAy=11;_gunSecimYil--;}caseGunModalRender()" style="background:none;border:1px solid var(--card3);border-radius:8px;padding:4px 12px;cursor:pointer;font-size:1rem">‹</button>' +
    '<span style="font-weight:800;font-size:.9rem">' + ayAdi + '</span>' +
    '<button onclick="_gunSecimAy++;if(_gunSecimAy>11){_gunSecimAy=0;_gunSecimYil++;}caseGunModalRender()" style="background:none;border:1px solid var(--card3);border-radius:8px;padding:4px 12px;cursor:pointer;font-size:1rem">›</button>' +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:4px">' +
    ['Pt','Sa','Ca','Pe','Cu','Ct','Pz'].map(g => '<div style="text-align:center;font-size:.6rem;font-weight:700;color:var(--ink3);padding:3px">' + g + '</div>').join('') +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:12px">' + kareler + '</div>' +
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Secili Gunler (' + seciliList.length + ')</div>' +
    seciliHtml +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">' +
    '<button onclick="caseGunEkleOnayla()" style="padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-weight:700;cursor:pointer">Ekle</button>' +
    '<button onclick="document.getElementById(\'gun-tarih-modal\').remove()" style="padding:12px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">Iptal</button>' +
    '</div></div>';
  box.style.display = 'flex';
}

function caseGunToggle(iso) {
  if (_gunSecimSecili.has(iso)) _gunSecimSecili.delete(iso);
  else _gunSecimSecili.add(iso);
  caseGunModalRender();
}

async function caseGunEkleOnayla() {
  if (!_curCase) return;
  const secili = [..._gunSecimSecili].sort();
  if (!secili.length) { toast('En az bir gun secin', true); return; }
  document.getElementById('gun-tarih-modal')?.remove();
  try {
    for (const tarih of secili) {
      await rpc('add_treatment_day', { p_case_id: _curCase.id, p_date: tarih });
    }
    toast(secili.length + ' tedavi gunu eklendi');
    await pullTables(['cases','treatment_days']);
    _drugsCache = [];
    await loadDrugsCache();
    await renderCaseTimeline(_curCase.id);
  } catch(e) { toast(e.message, true); }
}

// ── VAKAYA PLANLI TOHUMLAMA ────────────────────────────────────────────────
// Tohumlama ilaç gibi vakanın bir kalemi; ama kaydı tohumlama_kaydet zinciri
// üzerinden gitmek zorunda (sperma, VWP, gebelik kontrol görevleri). Bu yüzden
// kart yalnızca planı taşır, kayıt planlı tohumlama formuna devreder.
function caseTohumlamaEkleAc() {
  if (!_curCase) return;
  document.getElementById('cd-toh-form')?.remove();
  const bugunTr = bugun();
  const div = document.createElement('div');
  div.id = 'cd-toh-form';
  div.style.cssText = 'background:rgba(78,154,42,.06);border:1px solid rgba(78,154,42,.2);border-radius:10px;padding:12px;margin-bottom:10px';
  div.innerHTML =
    '<div style="font-size:.74rem;font-weight:700;color:var(--ink2);margin-bottom:8px">🐄 Planlı Tohumlama Ekle</div>' +
    '<div style="display:flex;gap:8px;margin-bottom:10px">' +
      '<label style="flex:2;font-size:.7rem;color:var(--ink3)">Tarih<input id="cdt-tarih" class="fi" type="date" value="' + bugunTr + '" style="margin-top:3px"></label>' +
      '<label style="flex:1;font-size:.7rem;color:var(--ink3)">Saat<input id="cdt-saat" class="fi" type="time" value="08:00" style="margin-top:3px"></label>' +
    '</div>' +
    '<div style="display:flex;gap:6px">' +
      '<button onclick="caseTohumlamaEkleOnayla(this)" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:8px;padding:9px;font-size:.76rem;font-weight:700;cursor:pointer">Ekle</button>' +
      '<button onclick="document.getElementById(\'cd-toh-form\').remove()" style="flex:1;background:var(--card2);color:var(--ink2);border:1px solid var(--card3);border-radius:8px;padding:9px;font-size:.76rem;cursor:pointer">Vazgeç</button>' +
    '</div>';
  document.getElementById('cd-gun-bolum')?.appendChild(div);
}

async function caseTohumlamaEkleOnayla(btn) {
  if (!_curCase) return;
  const tarih = document.getElementById('cdt-tarih')?.value;
  const saat  = document.getElementById('cdt-saat')?.value || '08:00';
  if (!tarih) { toast('Tarih seçin', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Ekleniyor…'; }
  try {
    await rpc('vaka_tohumlama_ekle', { p_case_id: _curCase.id, p_tarih: tarih, p_saat: saat });
    document.getElementById('cd-toh-form')?.remove();
    toast('🐄 Planlı tohumlama eklendi');
    await pullTables(['gorev_log']);
    await renderCaseTimeline(_curCase.id);
    updateTaskBadge();
  } catch(e) {
    toast('❌ ' + e.message, true);
    if (btn) { btn.disabled = false; btn.textContent = 'Ekle'; }
  }
}

async function caseTohumlamaKaydet(gorevId) {
  const g = (await idbGetAll('gorev_log')).find(x => x.id === gorevId);
  if (!g) { toast('Planlı tohumlama görevi bulunamadı', true); return; }
  closeM('m-case-det');
  openPlanliTohumlama(g);
}

async function caseTohumlamaIptal(gorevId) {
  const g = (await idbGetAll('gorev_log')).find(x => x.id === gorevId);
  if (!g) { toast('Planlı tohumlama görevi bulunamadı', true); return; }
  openConfirm('Tohumlamayı İptal Et', 'Bu planlı tohumlama iptal edilsin mi?', async () => {
    try {
      await write('gorev_log', { ...g, tamamlandi: true, tamamlanma_tarihi: new Date().toISOString(), iptal: true }, 'PATCH', `id=eq.${g.id}`);
      toast('🗑 Planlı tohumlama iptal edildi');
      await renderCaseTimeline(_curCase.id);
      updateTaskBadge();
      loadDash();
    } catch(e) { toast('❌ ' + e.message, true); }
  });
}

let _activeDayId = null;
function caseDrugFormAc(dayId) {
  _activeDayId = dayId;
  document.querySelectorAll('.cd-drug-form, .cd-seans-form').forEach(f => f.remove());
  const container = document.getElementById('drugs-' + dayId);
  if (!container) return;

  const cache = _drugsCache || [];
  const groups = {};
  [...cache].sort((a,b) => a.name.localeCompare(b.name,'tr')).forEach(d => {
    const g = d.group_name || 'Diger';
    if (!groups[g]) groups[g] = [];
    groups[g].push(d);
  });

  const groupHtml = Object.keys(groups).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'})).map(grp => {
    const items = groups[grp].map(d => {
      const stokClrPos = d.guncel <= 0 ? 'var(--red)' : d.guncel <= 10 ? 'var(--amber)' : 'var(--green)';
      const stokClr = d.guncel === null ? 'var(--ink3)' : stokClrPos;
      const stokTxt = d.guncel !== null ? d.guncel.toFixed(1)+' '+d.birim : 'stok yok';
      const esc = d.name.replace(/"/g,'&quot;');
      const rt = (d.default_route||'IM').split(' ')[0];
      return '<label style="display:flex;align-items:center;gap:8px;padding:5px 2px;cursor:pointer">'+
        '<input type="checkbox" class="cdf-chk" data-id="'+d.id+'" data-name="'+esc+'" data-unit="'+(d.default_unit||d.birim||'ml')+'" data-route="'+rt+'" data-legacy="'+(d._legacy||false)+'"'+
        ' onchange="cdfChkChange(this)" style="width:18px;height:18px;accent-color:var(--green);flex-shrink:0;cursor:pointer">'+
        '<div style="flex:1;min-width:0"><div style="font-size:.82rem;font-weight:600;color:var(--ink)">'+d.name+'</div>'+
        (d.active_ingredient ? '<div style="font-size:.65rem;color:var(--ink3)">'+d.active_ingredient+'</div>' : '')+
        '</div><span style="font-size:.72rem;font-weight:700;color:'+stokClr+';flex-shrink:0">'+stokTxt+'</span></label>';
    }).join('');
    return '<div style="margin-bottom:8px"><div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:4px;padding:3px 0;border-bottom:1px solid var(--card3)">'+grp+'</div>'+items+'</div>';
  }).join('');

  const form = document.createElement('div');
  form.className = 'cd-drug-form';
  form.style.cssText = 'margin-top:8px;background:var(--card2);border-radius:10px;padding:10px';
  form.innerHTML =
    '<div style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:8px">Ilac Sec</div>'+
    '<div style="max-height:220px;overflow-y:auto;background:var(--card);border-radius:8px;padding:8px;margin-bottom:8px;border:1px solid var(--card3)">'+
    (groupHtml || '<div style="color:var(--ink3);font-size:.78rem;padding:8px">Stokta ilac yok</div>')+
    '</div>'+
    '<div id="cdf-doz-alani" style="display:none">'+
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Secili Ilaclar — Doz Gir</div>'+
    '<div id="cdf-doz-satirlar"></div></div>'+
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px">'+
    '<button onclick="caseDrugKaydet(this)" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:9px;font-weight:700;cursor:pointer">Kaydet</button>'+
    '<button onclick="_activeDayId=null;this.closest(\'.cd-drug-form\').remove()" style="background:var(--card3);border:none;border-radius:7px;padding:9px;cursor:pointer">Iptal</button>'+
    '</div>';
  container.appendChild(form);
}

function cdfChkChange(chk) {
  const id = chk.dataset.id;
  const name = chk.dataset.name;
  const unit = chk.dataset.unit || 'ml';
  const route = chk.dataset.route || 'IM';
  const satirlar = document.getElementById('cdf-doz-satirlar');
  const alan = document.getElementById('cdf-doz-alani');
  if (!satirlar || !alan) return;
  if (chk.checked) {
    const row = document.createElement('div');
    row.id = 'cdf-row-' + id;
    row.style.cssText = 'background:rgba(78,154,42,.06);border:1px solid rgba(78,154,42,.2);border-radius:8px;padding:8px;margin-bottom:6px';
    row.innerHTML =
      '<div style="font-size:.78rem;font-weight:700;color:var(--green);margin-bottom:5px">'+name+'</div>'+
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">'+
      '<input type="number" min="0.01" step="0.01" placeholder="Doz" class="fi cdf-dose-inp" data-drug-id="'+id+'" style="margin:0">'+
      '<input type="text" placeholder="Birim" value="'+unit+'" class="fi cdf-unit-inp" data-drug-id="'+id+'" style="margin:0">'+
      '</div>'+
      '<select class="fsel cdf-route-inp" data-drug-id="'+id+'" style="margin-top:5px">'+
      '<option value="">Uygulama yolu</option>'+
      '<option '+(route==='IM'?'selected':'')+' value="IM">IM — Kas ici</option>'+
      '<option '+(route==='IV'?'selected':'')+' value="IV">IV — Damar ici</option>'+
      '<option '+(route==='SC'?'selected':'')+' value="SC">SC — Deri alti</option>'+
      '<option '+(route==='PO'?'selected':'')+' value="PO">PO — Agizdan</option>'+
      '<option value="Topikal">Topikal</option>'+
      '<option value="Intrauterin">Intrauterin</option>'+
      '</select>';
    satirlar.appendChild(row);
  } else {
    document.getElementById('cdf-row-' + id)?.remove();
  }
  const checked = document.querySelectorAll('.cdf-chk:checked').length;
  alan.style.display = checked > 0 ? 'block' : 'none';
}

function cdfDrugAc() {}
function cdfDrugSec() {}
async function caseDrugKaydet(btn) {
  if (!_activeDayId) return;
  // Secili checkbox'lardan doz satirlarini topla
  const secililar = [];
  document.querySelectorAll('.cdf-chk:checked').forEach(chk => {
    const id = chk.dataset.id;
    const doseInp = document.querySelector('.cdf-dose-inp[data-drug-id="'+id+'"]');
    const unitInp = document.querySelector('.cdf-unit-inp[data-drug-id="'+id+'"]');
    const routeInp = document.querySelector('.cdf-route-inp[data-drug-id="'+id+'"]');
    const dose = Number.parseFloat(doseInp?.value);
    const unit = (unitInp?.value||'').trim();
    const route = routeInp?.value || null;
    if (!dose || dose <= 0) { toast(id + ': Gecerli doz girin', true); return; }
    if (!unit) { toast(id + ': Birim girin', true); return; }
    secililar.push({ id, dose, unit, route });
  });
  if (!secililar.length) { toast('Ilac secin', true); return; }
  btn.disabled = true; btn.textContent = 'Kaydediliyor...';
  try {
    const isOnline = navigator.onLine;
    for (const item of secililar) {
      const d = (_drugsCache||[]).find(x => x.id === item.id);
      if (isOnline) {
        // Online: RPC kullan
        await rpc('add_drug_administration', {
          p_day_id:          _activeDayId,
          p_drug_product_id: d?._legacy ? null : item.id,
          p_stok_id:         d?.stock_id || null,
          p_dose:            item.dose,
          p_unit:            item.unit,
          p_route:           (item.route||'').split(' ')[0] || null,
        });
      } else {
        // Offline: write() kullan + queue'ya ekle
        const adminId = crypto.randomUUID();
        const stokId = d?.stock_id || null;
        // drug_administrations tablosuna ekle (offline)
        await write('drug_administrations', {
          id: adminId,
          day_id: _activeDayId,
          drug_product_id: d?._legacy ? null : item.id,
          stok_id: stokId,
          dose: item.dose,
          unit: item.unit,
          route: (item.route||'').split(' ')[0] || null,
        });
        // Stok hareketi de ekle (offline)
        if (stokId) {
          await write('stok_hareket', {
            id: crypto.randomUUID(),
            stok_id: stokId,
            tur: 'Ilac',
            miktar: item.dose,
            notlar: 'DrugAdmin:' + adminId,
            iptal: false,
          });
        }
      }
    }
    toast('✅ ' + secililar.length + ' ilac eklendi');
    await pullTables(['stok','stok_hareket','drug_administrations','treatment_days']);
    btn.closest('.cd-drug-form').remove();
    _activeDayId = null; // M-17 fix: form kapanınca modül-düzey state sızmasın
    _drugsCache = [];
    await loadDrugsCache();
    await renderCaseTimeline(_curCase.id);
    // Stok panelini güncelle
    const _sp = document.getElementById('stok-panel');
    if (_sp && _sp.style.transform !== 'translateX(100%)') loadStokPanel();
  } catch(e) { toast(e.message, true); }
  finally { btn.disabled = false; btn.textContent = 'Kaydet'; }
}

async function caseDrugSil(adminId) {
  if (!confirm('Bu ilaç kaydı silinsin mi?')) return;
  try {
    await rpc('remove_drug_administration', { p_admin_id: adminId });
    toast('✅ Silindi');
    await pullTables(['stok','stok_hareket','drug_administrations']);
    await renderCaseTimeline(_curCase.id);
  } catch(e) { toast(e.message, true); }
}

async function caseDaySil(dayId) {
  if (!confirm('Bu tedavi gunu ve icindeki tum ilaclar silinecek. Emin misin?')) return;
  try {
    await rpc('delete_treatment_day', { p_day_id: dayId });
    toast('Tedavi gunu silindi');
    _drugsCache = [];
    await pullTables(['stok','stok_hareket','drug_administrations','treatment_days','treatment_day_uygulamalar','cases']);
    await loadDrugsCache();
    await renderCaseTimeline(_curCase.id);
    const _sp = document.getElementById('stok-panel');
    if (_sp && _sp.style.transform !== 'translateX(100%)') loadStokPanel();
  } catch(e) { toast(e.message, true); }
}

function caseDrugDuzenle(btn) {
  // M-16 fix: eskiden brittle substring selector (`button[onclick*="${adminId}"]`)
  // kullanıyordu — birden fazla satırda aynı adminId parça-eşleşirse yanlış satır
  // düzenlenebiliyordu. Artık btn zaten doğru satırın kendi elemanı (event'ten geliyor),
  // closest('.cd-drug-row') ile güvenilir + dose/unit/route dataset'ten okunuyor (raw
  // string interpolation yok, injection riski yok).
  document.querySelectorAll('.drug-edit-form').forEach(f => f.remove());
  const row = btn.closest('.cd-drug-row');
  if (!row) return;
  const adminId = row.dataset.adminId;
  const dose = btn.dataset.dose;
  const unit = btn.dataset.unit;
  const route = btn.dataset.route;
  const form = document.createElement('div');
  form.className = 'drug-edit-form';
  form.dataset.adminId = adminId;
  form.style.cssText = 'background:rgba(42,107,181,.06);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:8px;margin-top:4px';
  form.innerHTML =
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:6px">' +
    '<input id="ded-dose" type="number" min="0.01" step="0.01" value="'+escAttr(dose)+'" class="fi" style="margin:0" placeholder="Doz">' +
    '<input id="ded-unit" type="text" value="'+escAttr(unit)+'" class="fi" style="margin:0" placeholder="Birim">' +
    '</div>' +
    '<select id="ded-route" class="fsel" style="margin-bottom:6px">' +
    '<option value="">Uygulama yolu</option>' +
    '<option '+(route==='IM'?'selected':'')+' value="IM">IM — Kas ici</option>' +
    '<option '+(route==='IV'?'selected':'')+' value="IV">IV — Damar ici</option>' +
    '<option '+(route==='SC'?'selected':'')+' value="SC">SC — Deri alti</option>' +
    '<option '+(route==='PO'?'selected':'')+' value="PO">PO — Agizdan</option>' +
    '<option '+(route==='Topikal'?'selected':'')+' value="Topikal">Topikal</option>' +
    '<option '+(route==='Intrauterin'?'selected':'')+' value="Intrauterin">Intrauterin</option>' +
    '</select>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">' +
    '<button onclick="caseDrugDuzenleKaydet(this.closest(\'.drug-edit-form\').dataset.adminId)" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:7px;font-weight:700;cursor:pointer">Kaydet</button>' +
    '<button onclick="this.closest(\'.drug-edit-form\').remove()" style="background:var(--card3);border:none;border-radius:7px;padding:7px;cursor:pointer">Iptal</button>' +
    '</div>';
  row.insertAdjacentElement('afterend', form);
}

async function caseDrugDuzenleKaydet(adminId) {
  const dose = Number.parseFloat(document.getElementById('ded-dose')?.value);
  const unit = document.getElementById('ded-unit')?.value?.trim();
  const route = document.getElementById('ded-route')?.value || null;
  if (!dose || dose <= 0) { toast('Gecerli doz girin', true); return; }
  if (!unit) { toast('Birim girin', true); return; }
  try {
    await rpc('update_drug_administration', { p_admin_id: adminId, p_dose: dose, p_unit: unit, p_route: route });
    toast('Ilac guncellendi');
    document.querySelector('.drug-edit-form')?.remove();
    _drugsCache = [];
    await pullTables(['stok','stok_hareket','drug_administrations']);
    await loadDrugsCache();
    await renderCaseTimeline(_curCase.id);
  } catch(e) { toast(e.message, true); }
}


async function caseKapat() {
  if (!_curCase) return;
  if (!confirm('Vakayı kapatmak istiyor musunuz?')) return;
  try {
    await rpc('close_case', { p_case_id: _curCase.id });
    toast('✅ Vaka kapatıldı');
    await pullTables(['cases','diseases','kizginlik_log']);
    await openCaseDet(_curCase.id);
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
  const filtered=q?_hdiIlacCache.filter(s=>(s.urun_adi||'').toLowerCase().includes(q)):_hdiIlacCache.slice(0,12);
  if(!filtered.length){ ac.style.display='none'; return; }
  ac.innerHTML=filtered.map(s=>`<div data-id="${escAttr(s.id)}" data-ad="${escAttr(s.urun_adi||'')}" data-birim="${escAttr(s.birim||'')}" onclick="hdiStokSec(this.dataset.id,this.dataset.ad,this.dataset.birim)"
    style="padding:8px 12px;cursor:pointer;font-size:.82rem;border-bottom:1px solid var(--card2)"
    onmouseover="this.style.background='var(--card2)'" onmouseout="this.style.background=''">${esc(s.urun_adi)} <span style="color:var(--ink3)">${s.birim||''}</span></div>`).join('');
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
  const hayvanObj=getState('animals').find(a=>a.id===t.hayvan_id||a.kupe_no===t.hayvan_id);
  const hayvanLabel=hayvanObj?.kupe_no||hayvanObj?.devlet_kupe||t.hayvan_id;
  const td2Hayvan=document.getElementById('td2-hayvan');
  td2Hayvan.textContent=hayvanLabel||'?';
  if(hayvanObj){
    td2Hayvan.dataset.hid=hayvanObj.id;
  } else {
    delete td2Hayvan.dataset.hid;
  }
  document.getElementById('td2-sperma').textContent=`💉 ${t.sperma||'?'}`;
  const _tohGebe=t.sonuc==='Gebe';
  const _scMidToh=t.sonuc==='Boş'?'var(--red)':'var(--amber)';
  const sc=_tohGebe?'var(--green)':_scMidToh;
  const chips=[
    `<span style="background:rgba(0,0,0,.06);padding:3px 9px;border-radius:10px;font-size:.7rem;font-weight:700;color:${sc}">${t.sonuc||'Bekliyor'}</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">${t.deneme_no||1}. deneme</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">📅 ${fmtTarih(t.tarih)}</span>`,
    hk?`<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">👨‍⚕️ ${esc(hk.ad)}</span>`:'',
  ];
  document.getElementById('td2-meta').innerHTML=chips.filter(Boolean).join('');

  // Durum bazlı görünürlük
  const sonucRadios=document.getElementById('td2-sonuc-radios');
  const td2Info=document.getElementById('td2-info-msg');
  const td2BosFixed=document.getElementById('td2-bos-fixed');
  // reset
  if(sonucRadios) sonucRadios.style.display='none';
  if(td2BosFixed) td2BosFixed.style.display='none';
  if(td2Info){ td2Info.textContent=''; td2Info.style.display='none'; }
  if(t.sonuc==='Doğum Yaptı'){
    if(td2Info){ td2Info.textContent='✅ Bu kayıt doğum ile tamamlandı.'; td2Info.style.display='block'; }
  } else if(t.sonuc==='Gebe'){
    if(td2Info){ td2Info.textContent='🤰 Gebe — hayvan kartından Abort veya Doğum Yaptı işlemi yapın.'; td2Info.style.display='block'; }
  } else if(t.sonuc==='Boş'){
    // Düzeltme: Boş → Bekliyor geri alma
    if(td2BosFixed) td2BosFixed.style.display='block';
  } else {
    // Bekliyor — radio + kaydet
    if(sonucRadios){
      sonucRadios.style.display='block';
      const sel=sonucRadios.querySelector(`input[value="${t.sonuc||'Bekliyor'}"]`);
      if(sel) sel.checked=true;
    }
  }

  // islem_log'dan bu kaydın id'sini bul (geri alma için)
  const islemLog=await idbGetAll('islem_log');
  const islemKayit=islemLog.find(l=>l.tip==='TOHUMLAMA'&&l.ref_id===id);
  const abortKayit=islemLog.find(l=>l.tip==='ABORT_KAYDI'&&l.ref_id===id);

  // Son tohumlama kontrolü (event stack kuralı)
  const tumTohlar=await idbGetAll('tohumlama');
  const hayvanTohlar=tumTohlar
    .filter(t2=>t2.hayvan_id===t.hayvan_id)
    .sort((a,b)=>{const d=(b.tarih||'').localeCompare(a.tarih||'');return d!==0?d:(b.created_at||'').localeCompare(a.created_at||'');});
  const isSonToh=hayvanTohlar.length>0&&hayvanTohlar[0].id===id;

  const td2GeriAlBtn=document.getElementById('td2-geri-al-btn');
  if(td2GeriAlBtn){
    if(abortKayit&&isSonToh&&abortKayit.durum!=='geri_alindi'){
      // Abort'u geri al — kaydı silmez; geri_al RPC'si ABORT_KAYDI snapshot'ından
      // sonuc='Gebe' + tohumlama_durumu'nu restore eder.
      // GUARD (review #6): yalnızca abort hayvanın SON üreme olayıysa — eski bir
      // abort geri alınırsa sonraki açık cycle üzerinde hayalet gebelik oluşur.
      td2GeriAlBtn.style.display='block';
      td2GeriAlBtn.textContent='↩ Abort İşlemini Geri Al';
      td2GeriAlBtn.dataset.ref=abortKayit.id;
      td2GeriAlBtn.dataset.label=`${hayvanLabel} — abort geri alınacak (kayıt tekrar Gebe olur)`;
    } else if(isSonToh&&islemKayit){
      td2GeriAlBtn.style.display='block';
      td2GeriAlBtn.textContent='🔄 Bu Kaydı Geri Al';
      td2GeriAlBtn.dataset.ref=islemKayit.id;
      td2GeriAlBtn.dataset.label=`${hayvanLabel} — ${t.sperma||'?'} (${fmtTarih(t.tarih)})`;
    } else if(isSonToh&&!islemKayit&&t.sonuc==='Bekliyor'){
      // Agent/manuel kayıt — islem_log yok, doğrudan sil
      td2GeriAlBtn.style.display='block';
      td2GeriAlBtn.textContent='⚠️ Hatalı Kaydı Sil';
      td2GeriAlBtn.dataset.ref='toh:'+id;
      td2GeriAlBtn.dataset.label=`${hayvanLabel} — ${t.sperma||'?'} (${fmtTarih(t.tarih)}) [islem_log yok]`;
    } else {
      td2GeriAlBtn.style.display='none';
    }
  }

  // Eski kayıt uyarısı — her açılışta önce temizle, sonra koşula göre ekle
  const mevcutUyari=document.getElementById('td2-eski-kayit-uyari');
  if(mevcutUyari) mevcutUyari.remove();
  if(!isSonToh){
    // Geçmiş kayıt: action butonlarını gizle
    if(sonucRadios) sonucRadios.style.display='none';
    if(td2Info){ td2Info.textContent=''; td2Info.style.display='none'; }
    const td2BosFixed2=document.getElementById('td2-bos-fixed');
    if(td2BosFixed2) td2BosFixed2.style.display='none';
    // Uyarı göster
    const uyari=document.createElement('p');
    uyari.id='td2-eski-kayit-uyari';
    uyari.style.cssText='color:var(--ink3);font-size:.85rem;text-align:center;margin:8px 0;padding:6px 12px;background:var(--card2);border-radius:8px';
    uyari.textContent='Bu kayıt geçmişe ait — sadece bilgi amaçlı görüntüleniyor.';
    td2GeriAlBtn?.parentNode?.insertBefore(uyari,td2GeriAlBtn.nextSibling);
  }
  const td2TekrarBtn=document.getElementById('td2-tekrar-btn');
  if(td2TekrarBtn){
    // dataset.kupe + index.html attribute onclick (router-modal DOM onclick yasağı)
    if(t.sonuc!=='Gebe'&&t.sonuc!=='Doğum Yaptı'){ td2TekrarBtn.style.display='block'; td2TekrarBtn.dataset.kupe=hayvanLabel||t.hayvan_id; }
    else { td2TekrarBtn.style.display='none'; }
  }

  // ── Önceki denemeler history ──
  const td2Denemeler=document.getElementById('td2-denemeler');
  if(td2Denemeler){
    if(t.denemeler&&t.denemeler.length>0){
      td2Denemeler.innerHTML=`<div style="padding-top:10px;border-top:1px solid var(--card3)">
        <div style="font-size:.72rem;font-weight:700;color:var(--ink3);margin-bottom:6px">Önceki Denemeler</div>
        ${t.denemeler.map(d=>`
          <div style="display:flex;gap:8px;align-items:center;padding:4px 0;font-size:.78rem">
            <span style="background:var(--card2);border-radius:6px;padding:1px 6px;font-weight:700">${d.no}.</span>
            <span>${d.tarih||'?'}</span>
            <span style="color:var(--ink3)">· ${esc(d.sperma||'?')}</span>
          </div>`).join('')}
      </div>`;
    } else {
      td2Denemeler.innerHTML='';
    }
  }

  openM('m-toh-det');
}
function tekrarTohumla(kupe) {
  closeM('m-toh-det');
  openInsemSafe(kupe);
}
// tohSonuc → forms.js'de tanımlı (guard'lı versiyon)

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
    return `<div data-s="${escAttr(s)}" onclick="selSperma(this.dataset.s);event.stopPropagation()" style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid var(--card3);display:flex;justify-content:space-between;align-items:center">
      <span>${esc(s)}${warn?' ⚠️':''}</span>${adetTxt}
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
  return all.filter(s=>s.kategori==='Sperma').map(s=>({...s,guncel:+s.guncel_stok||0}));
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
    bnd.textContent='⚠️ Kritik sperma stoku: '+critik.map(s=>`${esc(s.urun_adi)} (${s.guncel} doz)`).join(', ');
  } else { bnd.style.display='none'; }
}
function trSpermaModStok(){
  document.getElementById('tr-sperma-stok-area').style.display='block';
  document.getElementById('tr-sperma-elle-area').style.display='none';
  document.getElementById('btn-tr-sperma-stok').style.background='rgba(42,107,181,.2)';
  document.getElementById('btn-tr-sperma-elle').style.background='var(--card2)';
  const spermalar=getState('stock').filter(s=>s.kategori==='Sperma'||s.grup==='Sperma'||(s.urun_adi||'').toLowerCase().includes('sperma')||(s.urun_adi||'').toLowerCase().includes('doz'));
  const sel=document.getElementById('tr-sperma-select');
  sel.innerHTML='<option value="">Sperma seçin…</option>'+spermalar.map(s=>`<option value="${esc(s.urun_adi)}" data-stok="${s.guncel||0}">${esc(s.urun_adi)} (${s.guncel||0} doz kaldı)</option>`).join('');
  if(!spermalar.length) sel.innerHTML='<option value="">Stokta sperma yok — Elle Gir kullanın</option>';
  document.getElementById('tr-sperma').value='';
  document.getElementById('tr-sperma-hint').textContent='';
  const kaydetBtn=document.querySelector('#m-insem-tekrar .btn-g');
  if(kaydetBtn) kaydetBtn.disabled=false;
}
function onTrSpermaSelect(sel){
  const val=sel.value;
  const stok=parseInt(sel.selectedOptions[0]?.dataset?.stok??'-1',10);
  document.getElementById('tr-sperma').value=val;
  const hint=document.getElementById('tr-sperma-hint');
  const kaydetBtn=document.querySelector('#m-insem-tekrar .btn-g');
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
function trSpermaModElle(){
  document.getElementById('tr-sperma-stok-area').style.display='none';
  document.getElementById('tr-sperma-elle-area').style.display='block';
  document.getElementById('btn-tr-sperma-elle').style.background='rgba(61,74,50,.15)';
  document.getElementById('btn-tr-sperma-stok').style.background='var(--card2)';
  document.getElementById('tr-sperma').value='';
  document.getElementById('tr-sperma-hint').textContent='';
  const kaydetBtn=document.querySelector('#m-insem-tekrar .btn-g');
  if(kaydetBtn){ kaydetBtn.disabled=false; kaydetBtn.title=''; }
}

function spermaModStok(){
  document.getElementById('sperma-stok-area').style.display='block';
  document.getElementById('sperma-elle-area').style.display='none';
  document.getElementById('btn-sperma-stok').style.background='rgba(42,107,181,.2)';
  document.getElementById('btn-sperma-elle').style.background='var(--card2)';
  const spermalar=getState('stock').filter(s=>s.kategori==='Sperma'||s.grup==='Sperma'||(s.urun_adi||'').toLowerCase().includes('sperma')||(s.urun_adi||'').toLowerCase().includes('doz'));
  const sel=document.getElementById('i-sperma-select');
  sel.innerHTML='<option value="">Sperma seçin…</option>'+spermalar.map(s=>`<option value="${esc(s.urun_adi)}" data-stok="${s.guncel||0}">${esc(s.urun_adi)} (${s.guncel||0} doz kaldı)</option>`).join('');
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
  _ilacCache=stk
    .filter(s=>s.kategori&&['Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç','İlaç'].includes(s.kategori))
    .map(s=>({...s,guncel:+s.guncel_stok||0}));
}
async function acIlac(){
  const q=(document.getElementById('d-stok-ac')?.value||'').trim();
  const ac=document.getElementById('ac-dilac'); if(!ac) return;
  if(!_ilacCache.length) await refreshIlacCache();
  const filtered=q?_ilacCache.filter(s=>trLower(s.urun_adi||'').includes(trLower(q))):_ilacCache.slice(0,12);
  if(!filtered.length){
    ac.innerHTML='<div style="padding:9px 12px;font-size:.78rem;color:var(--red)">⚠️ Stokta eşleşen ilaç yok — önce stoka ekleyin</div>';
    ac.style.display='block'; return;
  }
  ac.innerHTML=filtered.map(s=>{
    const warn=s.guncel<=0;
    const _stokColorMid=s.guncel<=5?'var(--amber)':'var(--green)';
    const _stokColor=warn?'var(--red)':_stokColorMid;
    return `<div data-id="${escAttr(s.id)}" data-ad="${escAttr(s.urun_adi||'')}" data-birim="${escAttr(s.birim||'ml')}" onclick="selIlac(this.dataset.id,this.dataset.ad,this.dataset.birim,${s.guncel});event.stopPropagation()"
      style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid var(--card3);display:flex;justify-content:space-between;align-items:center;${warn?'opacity:.5':''}">
      <div><div style="font-weight:600">${esc(s.urun_adi)}</div><div style="font-size:.65rem;color:var(--ink3)">${s.kategori||''}</div></div>
      <span style="color:${_stokColor};font-weight:700;font-size:.78rem">${s.guncel.toFixed(s.birim==='adet'?0:1)} ${s.birim||''}</span>
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
    <div class="ac-box ilac-ac" style="display:none;position:absolute;z-index:200;background:var(--card);border:1px solid var(--card3);border-radius:8px;max-height:160px;overflow-y:auto;width:100%"></div>
  </div>
  <input class="fi ilac-mik" type="number" min="0" placeholder="ml/adet" style="flex:1;margin:0">
  <button type="button" onclick="this.closest('.ilac-satir').remove()" style="background:var(--red);color:#fff;border:none;border-radius:8px;padding:6px 10px;cursor:pointer;flex-shrink:0">✕</button>`;
  container.appendChild(row);
}
async function acDilacSatir(inp){
  if (!getState('stock') || !getState('stock').length) await loadStock();
  const q=(inp.value||'').trim();
  const ac=inp.closest('.ilac-satir').querySelector('.ilac-ac');
  const stoklar=getState('stock').filter(s=>s.kategori!=='Sperma'&&!(s.urun_adi||'').toLowerCase().includes('sperma'));
  const filtered=q?stoklar.filter(s=>trLower(s.urun_adi||'').includes(trLower(q))):stoklar.slice(0,8);
  if(!filtered.length){ac.style.display='none';return;}
  ac.innerHTML=filtered.map(s=>`<div data-id="${escAttr(s.id)}" data-ad="${escAttr(s.urun_adi||'')}" data-birim="${escAttr(s.birim||'')}" onclick="selDilacSatir(this,this.dataset.id,this.dataset.ad,this.dataset.birim)" style="padding:8px 10px;cursor:pointer;font-size:.82rem;border-bottom:1px solid var(--card3)">${esc(s.urun_adi)} <span style="color:#aaa;font-size:.65rem">${s.guncel||0} ${s.birim||''}</span></div>`).join('');
  ac.style.display='block';
}
function selDilacSatir(el,id,ad,birim){
  try {
    const row=el.closest('.ilac-satir');
    if(!row) { console.warn('selDilacSatir: row not found'); return; }
    const acInp=row.querySelector('.ilac-stok-ac');
    const hidInp=row.querySelector('.ilac-stok-id');
    const mikInp=row.querySelector('.ilac-mik');
    if(acInp) acInp.value=ad;
    if(hidInp) hidInp.value=id;
    if(mikInp) mikInp.placeholder=birim||'miktar';
    const acBox=el.closest('.ilac-ac');
    if(acBox) acBox.style.display='none';
  } catch(e) { console.error('selDilacSatir error:', e); toast('İlaç seçim hatası: '+e.message, true); }
}
document.addEventListener('click',e=>{
  const ac=document.getElementById('ac-dilac');
  if(ac&&!e.target.closest('#d-stok-ac')&&!e.target.closest('#ac-dilac')) ac.style.display='none';
});

// ──────────────────────────────────────────
// HAYVAN KÜPE AUTOCOMPLETE
// ──────────────────────────────────────────

function _eligibleHayvanlar(){
  const gebeSet=new Set(getState('gebeIds')||[]);
  const minMs=330*86400000; // 330 gun (~11 ay) — Disi dana tohumlama yasi
  return getState('animals').filter(a=>{
    if(a.cinsiyet==='Erkek') return false;
    if(a.kisir) return false;
    if(gebeSet.has(a.id)) return false;
    // yas biliniyorsa: 330+ gun kontrolu
    if(a.dogum_tarihi){
      return (Date.now()-new Date(a.dogum_tarihi).getTime())>=minMs;
    }
    // dogum_tarihi YOK — zeki tahmin: laktasyon/gebe grubu → yetiskin
    // Grup adlari DB'den Turkce karakterli gelir
    if(['Sağmal (Laktasyonda)','Sağmal (Kuru)','Gebe İnek','Gebe Düve','Düve (Büyük)'].includes(a.grup)) return true;
    return true; // varsayilan: dahil et (asil filtreyi DB view yapar)
  });
}

function _activeAnimalsOnly(){
  return getState('animals').filter(a=>a.durum==='Aktif');
}

function acHayvan(inputId,listId){
  const inp=document.getElementById(inputId);
  const q=(inp?.value||'').trim();
  const ac=document.getElementById(listId); if(!ac) return;
  // DB view öncelikli, yoksa UI fallback (hybrid approach)
  let src;
  if (listId === 'ac-ihid') {
    src = globalThis._TH?.length > 0 ? globalThis._TH : _eligibleHayvanlar();
  } else if (listId === 'ac-khid') {
    src = _eligibleHayvanlar();
  } else if (listId === 'ac-dhid') {
    src = _activeAnimalsOnly();
  } else {
    src = getState('animals').length ? getState('animals') : [];
  }
  // uuid id içinde aramak alakasız satır üretir — yalnız küpe/devlet/ırk aranır.
  // Sıralama+vurgu srchDropdown ile aynı sözleşme: srchAdaySirala/vurguHtml (helpers.js)
  let rows;
  if(!q){
    const disp=a=>String(a.kupe_no||a.devlet_kupe||a.id||'');
    rows=[...src].sort((a,b)=>disp(a).localeCompare(disp(b),'tr',{numeric:true})).slice(0,10).map(a=>({a,tier:-1}));
  }else{
    rows=srchAdaySirala(src,q,12).map(x=>({a:x.h,tier:x.tier}));
  }
  if(!rows.length){
    ac.innerHTML='<div style="padding:9px 12px;font-size:.78rem;color:var(--red)">⚠️ Sürüde eşleşen hayvan bulunamadı</div>';
    ac.style.display='block'; return;
  }
  ac.innerHTML=rows.map(({a,tier})=>{
    const kupe=a.kupe_no||a.devlet_kupe||a.id;
    // Irktan eşleşen satırda küpe eşleşme içermez — vurgu yanıltır
    const kupeHtml=tier===6?esc(kupe):vurguHtml(kupe,q);
    // Eşleşme görünmez olmasın: devlet küpesinden eşleştiyse vurgulu devlet, ırksa vurgulu ırk göster
    const sagParcalar=[];
    if(a.kupe_no&&a.devlet_kupe&&a.devlet_kupe!==a.kupe_no&&(tier===1||tier===3||tier===5)) sagParcalar.push(vurguHtml(a.devlet_kupe,q));
    if(tier===6&&a.irk) sagParcalar.push(vurguHtml(a.irk,q));
    else if(a.irk) sagParcalar.push(esc(a.irk));
    if(a.padok) sagParcalar.push(esc(a.padok));
    return `<div data-kupe="${escAttr(kupe)}" onclick="selHayvan('${inputId}','${listId}',this.dataset.kupe)" style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid var(--card3);display:flex;justify-content:space-between;gap:8px">
      <span style="font-weight:600">${kupeHtml}</span>
      <span style="color:var(--ink3);font-size:.7rem;text-align:right">${sagParcalar.join(' · ')}</span>
    </div>`;
  }).join('');
  ac.style.display='block';
  // Ensure focus stays on input after first click
  if(inp && document.activeElement!==inp){ inp.focus(); }
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
  const _tid=setTimeout(()=>{
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
    if(modalId==='m-vaccine'){
      if(typeof loadVaccinesDropdown==='function') loadVaccinesDropdown();
    }
    if(modalId==='m-bulk-vaccine'){
      if(typeof loadBulkVaccinePadoklar==='function') loadBulkVaccinePadoklar();
      if(typeof loadBulkVaccineVaccines==='function') loadBulkVaccineVaccines();
    }
    if(modalId==='m-bulk-ilac'){
      if(typeof loadBulkIlacPadoklar==='function') loadBulkIlacPadoklar();
      if(typeof loadBulkIlacDropdown==='function') loadBulkIlacDropdown();
    }
    if(modalId==='m-insem'){
      const cb=document.getElementById('i-sorun-toggle');
      const thumb=document.getElementById('i-sorun-thumb');
      if(cb) cb.checked=false;
      if(thumb) thumb.style.background='var(--card3)';
      globalThis._insemSorunVar=false;
    }
  },150);
  if(inputId==='i-hid') globalThis._insemKupeTid=_tid;
}

async function openInsemSafe(kupeNo){
  const hayvan=(getState('animals')||[]).find(a=>a.kupe_no===kupeNo||a.devlet_kupe===kupeNo);
  if(!hayvan){ openMWithHayvan('m-insem','i-hid',kupeNo); return; }
  const tohs=await getData('tohumlama',t=>t.hayvan_id===hayvan.id);
  const bekliyor=tohs.find(t=>t.sonuc==='Bekliyor');
  if(bekliyor){
    const today=bugun();
    const gun=Math.floor((new Date(today)-new Date(bekliyor.tarih))/86400000);
    if(gun>=0&&gun<=15){ _openInsemIntercept(hayvan,bekliyor); return; }
  }
  openMWithHayvan('m-insem','i-hid',kupeNo);
}

function openPlanliTohumlama(gorev){
  const hayvan=(getState('animals')||[]).find(a=>a.id===gorev.hayvan_id);
  if(!hayvan){ toast('Görevin hayvanı bulunamadı',true); return; }
  globalThis._planliTohumlamaGorevId=gorev.id;
  closeM('m-task-det');
  openMWithHayvan('m-insem','i-hid',hayvan.kupe_no||hayvan.devlet_kupe||hayvan.id);
  setTimeout(()=>{ const tarih=document.getElementById('i-tarih'); if(tarih) tarih.value=new Date().toISOString().slice(0,10); },180);
}

function _openInsemIntercept(hayvan,bekliyor){
  const today=bugun();
  const gun=Math.floor((new Date(today)-new Date(bekliyor.tarih))/86400000);
  const hid=hayvan.kupe_no||hayvan.devlet_kupe||hayvan.id;
  const infoEl=document.getElementById('insem-intercept-info');
  if(infoEl) infoEl.innerHTML=`<b>${esc(hid)}</b> — ${esc(bekliyor.sperma||'?')} · <b>${gun}. gün</b> (${(bekliyor.tarih||'').slice(0,10)})`;
  globalThis._insemInterceptHayvan={id:hayvan.id,kupeNo:hid,tohId:bekliyor.id};
  openM('m-insem-intercept');
}

async function openGebelikEkle(hayvanId){
  const tohs=await getData('tohumlama',t=>t.hayvan_id===hayvanId);
  tohs.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  const son=tohs.find(t=>t.sonuc==='Bekliyor')||tohs[0];
  if(!son){ toast('Tohumlama kaydı bulunamadı',true); return; }
  const sure=confirm('Son tohumlama ('+fmtTarih(son.tarih)+' · '+(son.sperma||'—')+') Gebe olarak işaretlensin mi?');
  if(!sure) return;
  try{
    await rpc('tohumlama_sonuc_gebe', { p_tohumlama_id: son.id });
    toast('✅ Gebe işaretlendi');
    openDet(hayvanId);
  }catch(e){ toast(e.message,true); }
}

// ──────────────────────────────────────────
// HASTALIK AUTOCOMPLETE
// ──────────────────────────────────────────
// (dead code removed — ui.js acDisease unused)

// selDis fonksiyonu ui.js'de tanımlı değil — app.js'den çağrılıyor (BUG-003 fix)
document.addEventListener('click',e=>{
  const ac=document.getElementById('ac-dis');
  if(ac&&!e.target.closest('#d-tani')&&!e.target.closest('#ac-dis')) ac.style.display='none';
});

// ──────────────────────────────────────────
// AYARLAR & DATA TRAFFIC
// ──────────────────────────────────────────
function setTheme(mode) {
  if (mode === 'dark') {
    document.body.classList.add('dark');
    localStorage.setItem('ege_theme','dark');
  } else {
    document.body.classList.remove('dark');
    localStorage.setItem('ege_theme','light');
  }
  const btnSaha = document.getElementById('btn-saha-mod');
  const btnKoyu = document.getElementById('btn-koyu-mod');
  if (btnSaha) btnSaha.style.background = mode === 'light' ? 'rgba(78,154,42,.18)' : '';
  if (btnKoyu) btnKoyu.style.background = mode === 'dark'  ? 'rgba(78,154,42,.18)' : '';
}
(function(){ const t = localStorage.getItem('ege_theme') || 'dark'; setTheme(t); })();

function ayarlarAc(){
  renderAyarlarHekimList();
  renderAyarlarVaccineList();
  renderAyarlarPadokList();
  renderGrupPadokEslem();
  dataTrafficYenile();
  // Protokol ayarları — taze çek + state + render
  (async () => {
    try {
      await pullTables(['protokol_ayar']);
      if (typeof setState === 'function') setState('protokol_ayar', await getData('protokol_ayar'));
    } catch (e) { /* offline → mevcut state/IDB kullanılır */ }
    if (typeof protokolAyarYukle === 'function') protokolAyarYukle();
  })();
  // tema butonlarını senkronize et
  const cur = localStorage.getItem('ege_theme') || 'dark';
  const btnSaha = document.getElementById('btn-saha-mod');
  const btnKoyu = document.getElementById('btn-koyu-mod');
  if (btnSaha) btnSaha.style.background = cur === 'light' ? 'rgba(78,154,42,.18)' : '';
  if (btnKoyu) btnKoyu.style.background = cur === 'dark'  ? 'rgba(78,154,42,.18)' : '';
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
      .map(s => `<option value="${s.id}">${esc(s.urun_adi)}</option>`)
      .join('');
    el.innerHTML = drugs
      .sort((a, b) => (a.name || '').localeCompare(b.name || '', 'tr'))
      .map(d => {
        const linked = d.stock_item_id || '';
        return `<div style="display:flex;align-items:center;gap:6px;margin-bottom:6px">
          <div style="flex:1;font-size:.78rem;font-weight:600;color:var(--ink);min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${escAttr(d.name)}">${esc(d.name)}</div>
          <select
            data-drug-id="${d.id}"
            onchange="submitDrugStokLink('${d.id}', this.value)"
            style="flex:1.2;font-size:.72rem;padding:5px 6px;border:1.5px solid var(--card3);border-radius:8px;background:var(--card);color:var(--ink);min-width:0"
          >
            <option value="">— Bağlantı yok —</option>
            ${stokList
              .sort((a, b) => (a.urun_adi || '').localeCompare(b.urun_adi || '', 'tr'))
              .map(s => `<option value="${s.id}"${s.id === linked ? ' selected' : ''}>${esc(s.urun_adi)}</option>`)
              .join('')}
          </select>
        </div>`;
      }).join('');
  } catch (e) {
    el.innerHTML = `<div style="color:var(--red);font-size:.75rem">⚠️ ${esc(e.message)}</div>`;
  }
}

async function kuyrukTemizle(){
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
async function dataTrafficGonder(e){
  const btn=(e||window.event).target;
  btn.disabled=true; btn.textContent='Gönderiliyor…';
  await syncNow();
  await dataTrafficYenile();
  btn.disabled=false; btn.textContent='↑ Tümünü Gönder';
}
async function dataTrafficTekGonder(qid){
  const q=await getQueue();
  const op=q.find(o=>o._qid===qid); if(!op) return;
  
  // RPC mapping tablosu — her tablo/method için hangi RPC kullanılacak
  const RPC_MAP = {
    hayvanlar: { POST: 'hayvan_ekle', PATCH: 'hayvan_guncelle' },
    tohumlama: { POST: 'tohumlama_kaydet' },
    dogum: { POST: 'dogum_kaydet' },
    gorev_log: { PATCH: 'gorev_tamamla' },
    stok_hareket: { POST: 'stok_hareket_ekle' },
    kizginlik_log: { POST: 'kizginlik_kaydet', DELETE: 'kizginlik_sil' },
    cases: { POST: 'create_case' },
    drug_administrations: { POST: 'add_drug_administration', PATCH: 'update_drug_administration' }
  };
  
  try {
    const rpcInfo = RPC_MAP[op.table];
    if(!rpcInfo) throw new Error(`Tablo "${op.table}" için RPC tanımlı değil`);

    // B25: yalnız POST/PATCH okunuyordu — RPC_MAP'te tanımlı DELETE dalı
    // (kizginlik_sil) hiç seçilemiyordu, "RPC tanımlı değil" yanılgısı üretiyordu
    const rpcName = rpcInfo[op.method];
    if(!rpcName) throw new Error(`${op.method} için RPC tanımlı değil`);
    
    // M-15 fix: eskiden boş string alanları da tamamen siliyordu (NOT NULL RPC
    // parametreleri için tehlikeli — p_unit gibi alanlar '' yerine hiç gönderilmeyince
    // RPC'nin kendi DEFAULT'u devreye giriyordu, bazen NULL). Artık sadece undefined
    // çıkarılıyor; null ve '' olduğu gibi RPC'ye gidiyor, buildRpcParams kendi
    // per-alan fallback'lerine (|| null vb.) karar veriyor.
    const clean = op.method === 'POST'
      ? op.data.map(item => Object.fromEntries(Object.entries(item).filter(([k,v]) => v !== undefined)))
      : Object.fromEntries(Object.entries(op.data[0]).filter(([k,v]) => v !== undefined));
    
    // RPC parametrelerini hazırla — B6: POST'ta clean DİZİ, PATCH'te obje;
    // dizi buildRpcParams'e data.x okutunca tüm alanlar undefined oluyordu
    const rpcParams = buildRpcParams(rpcName, Array.isArray(clean) ? clean[0] : clean, op);
    
    // RPC çağrısı — REST bypass yerine backend validasyon + trigger'lar çalışır
    await rpc(rpcName, rpcParams);
    
    await removeFromQueue(qid);
    toast('✅ Kayıt gönderildi');
    
    // İlgili tabloları çek + UI refresh
    const tables = RPC_TABLES[rpcName] || [op.table];
    pullTables(tables).then(renderSafe).catch(console.warn);
    
  } catch(e){
    toast('❌ '+e.message, true);
  }
  
  await dataTrafficYenile();
  updateSyncBar();
}

// RPC parametre builder — her RPC için doğru parametre yapısını oluştur.
// İmzalar 2026-08-31 canlı pg_get_functiondef ile doğrulandı (B6):
// yanlış adlı anahtarları supabase-js sessizce yutar → Postgres DEFAULT/NULL.
function buildRpcParams(rpcName, data, op) {
  switch(rpcName) {
    case 'hayvan_ekle':
      // canlı: (p_kupe_no, p_devlet_kupe, p_irk, p_cinsiyet, p_dogum_tarihi,
      // p_grup, p_padok, p_dogum_kg, p_anne_id, p_baba_bilgi, p_canli_agirlik,
      // p_boy, p_renk, p_ayirci_ozellik[, p_padok_id])
      // eski kod p_grup_id/p_irk_id gönderiyordu — ikisi de yok
      return {
        p_kupe_no: data.kupe_no ?? null,
        p_devlet_kupe: data.devlet_kupe ?? null,
        p_irk: data.irk ?? null,
        p_cinsiyet: data.cinsiyet ?? null,
        p_dogum_tarihi: data.dogum_tarihi ?? null,
        p_grup: data.grup ?? null,
        p_padok: data.padok ?? null,
        p_dogum_kg: data.dogum_kg ?? null,
        p_anne_id: data.anne_id ?? null,
        p_baba_bilgi: data.baba_bilgi ?? null,
        p_canli_agirlik: data.canli_agirlik ?? null,
        p_boy: data.boy ?? null,
        p_renk: data.renk ?? null,
        p_ayirici_ozellik: data.ayirici_ozellik ?? null,
        ...(data.padok_id ? { p_padok_id: data.padok_id } : {})
      };
    case 'hayvan_guncelle': {
      // canlı: tam-satır update — (p_id, p_kupe_no, p_devlet_kupe, p_irk,
      // p_cinsiyet, p_dogum_tarihi, p_grup, p_padok, p_dogum_kg, p_canli_agirlik,
      // p_boy, p_renk, p_ayirici_ozellik[, p_baba_bilgi, p_notlar, p_anne_id,
      // p_padok_id][, p_kisir]). Eski kod p_alan/p_deger gönderiyordu — yok;
      // COALESCE no-op + 'ok' ile kuyruktaki düzenleme başarı sansıyordu.
      const idMatch = (op.filter || '').match(/id=eq\.([^&]+)/);
      return {
        p_id: idMatch ? idMatch[1] : (data.id ?? null),
        p_kupe_no: data.kupe_no ?? null,
        p_devlet_kupe: data.devlet_kupe ?? null,
        p_irk: data.irk ?? null,
        p_cinsiyet: data.cinsiyet ?? null,
        p_dogum_tarihi: data.dogum_tarihi ?? null,
        p_grup: data.grup ?? null,
        p_padok: data.padok ?? null,
        p_dogum_kg: data.dogum_kg ?? null,
        p_canli_agirlik: data.canli_agirlik ?? null,
        p_boy: data.boy ?? null,
        p_renk: data.renk ?? null,
        p_ayirci_ozellik: data.ayirici_ozellik ?? null,
        ...(data.baba_bilgi !== undefined ? { p_baba_bilgi: data.baba_bilgi } : {}),
        ...(data.notlar !== undefined ? { p_notlar: data.notlar } : {}),
        ...(data.anne_id !== undefined ? { p_anne_id: data.anne_id } : {}),
        ...(data.padok_id ? { p_padok_id: data.padok_id } : {}),
        ...(data.kisir !== undefined ? { p_kisir: data.kisir } : {})
      };
    }
    case 'tohumlama_kaydet':
      // canlı: (p_hayvan_id, p_tarih, p_sperma[, p_hekim_id, p_irk_bilgisi,
      // p_ek_uygulamalar, p_vwp_override]) — eski kod p_sperma_kodu/p_teknisyen
      // (yok) gönderiyordu → p_sperma zorunlu eksik → PGRST hatası
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih: data.tarih,
        p_sperma: data.sperma,
        p_hekim_id: data.hekim_id ?? null,
        p_irk_bilgisi: data.irk_bilgisi ?? null,
        p_ek_uygulamalar: data.ek_uygulamalar ?? [],
        p_vwp_override: data.vwp_override ?? false
      };
    case 'tohumlama_tekrar_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih:     data.tarih,
        p_sperma:    data.sperma,
        p_hekim_id:  data.hekim_id || null,
        p_irk_bilgisi: data.irk_bilgisi || null
      };
    case 'dogum_kaydet':
      // canlı: (p_anne_id, p_tarih, p_kupe, p_cins, p_tip, p_kg, p_baba,
      // p_hekim_id) — eski kod p_buzagi_cinsiyet/p_buzagi_kupe (yok) gönderiyordu
      return {
        p_anne_id: data.anne_id,
        p_tarih: data.tarih,
        p_kupe: data.kupe ?? data.buzagi_kupe ?? null,
        p_cins: data.cins ?? data.buzagi_cinsiyet ?? null,
        p_tip: data.tip ?? null,
        p_kg: data.kg ?? null,
        p_baba: data.baba ?? null,
        p_hekim_id: data.hekim_id ?? null
      };
    case 'stok_hareket_ekle':
      return {
        p_stok_id: data.stok_id,
        p_tur: data.tur,
        p_miktar: data.miktar,
        p_notlar: data.notlar
      };
    case 'kizginlik_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih: data.tarih,
        p_belirti: data.belirti || null,
        p_notlar: data.notlar || null
      };
    case 'kizginlik_sil':
      return {
        p_kayit_id: data.id || op.filter?.replace('id=eq.', '')
      };
    case 'create_case':
      // canlı: (p_animal_id, p_disease_id, p_notes) — eski kod p_hayvan_id/
      // p_tanis/p_tarih (hiçbiri yok) gönderiyordu
      return {
        p_animal_id: data.animal_id ?? data.hayvan_id ?? null,
        p_disease_id: data.disease_id ?? null,
        p_notes: data.notes ?? data.tanis ?? null
      };
    case 'add_drug_administration':
      // canlı: (p_day_id, p_drug_product_id, p_stok_id, p_dose, p_unit, p_route)
      // — p_time parametresi YOK (uygulama saati RPC üzerinden aktarılamaz,
      // M-14: p_stok_id eksikti, eklendi)
      return {
        p_day_id: data.day_id ?? data.treatment_day_id ?? null,
        p_drug_product_id: data.drug_product_id,
        p_stok_id: data.stok_id ?? null,
        p_dose: data.dose,
        p_unit: data.unit,
        p_route: data.route
      };
    case 'update_drug_administration':
      return {
        p_admin_id: data.id,
        p_dose: data.dose,
        p_unit: data.unit,
        p_route: data.route
      };
    case 'gorev_tamamla':
      return { p_gorev_id: data.id, p_padok_hedef: data.padok || null };
    case 'gorev_guncelle':
      // canlı: (p_id, p_aciklama, p_hedef_tarih, p_gorev_tipi)
      return {
        p_id: data.id,
        p_aciklama: data.aciklama ?? null,
        p_hedef_tarih: data.hedef_tarih ?? null,
        p_gorev_tipi: data.gorev_tipi ?? null
      };
    default:
      // Fallback — doğrudan veriyi geç
      return data;
  }
}
async function dataTrafficSil(qid){
  if(!confirm('Bu kaydı kuyruktan sil? (Supabase\'e gönderilmeyecek)')) return;
  await removeFromQueue(qid);
  toast('🗑 Kayıt kuyruktan silindi');
  await dataTrafficYenile();
  updateSyncBar();
}
async function renderAyarlarHekimList(){
  const el=document.getElementById('ay-hekim-list'); if(!el) return;
  const hekimler=await getData('hekimler');
  const all=hekimler.length?hekimler:HEKIMLER;
  el.innerHTML=all.map(h=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--card2);cursor:pointer" onclick="hekimDetAc('${h.id}')">
    <span style="font-size:.85rem;color:var(--ink);cursor:pointer">${esc(h.ad)}${h.id===VARSAYILAN_HEKIM?' <span style="font-size:.6rem;color:var(--green)">(varsayılan)</span>':''}</span>
    <button onclick="event.stopPropagation();hekimDetAc('${h.id}')" style="background:none;border:none;color:var(--ink3);font-size:.75rem;cursor:pointer;padding:4px 8px">🔍</button>
  </div>`).join('');
}
async function renderAyarlarVaccineList(){
  const el=document.getElementById('ay-vaksiyon-list'); if(!el) return;
  const vaxs=await getData('vaccines');
  if(!vaxs.length){ el.innerHTML='<div style="font-size:.75rem;color:var(--ink3)">Aşı tanımlı değil</div>'; return; }
  const intervals=[
    {val:'',lbl:'Tek Doz'},
    {val:'21',lbl:'21 gün'},
    {val:'90',lbl:'90 gün'},
    {val:'180',lbl:'180 gün'},
    {val:'365',lbl:'365 gün'}
  ];
  el.innerHTML='<div style="display:grid;gap:4px">'+vaxs.map(vac=>{
    const cur=vac.repeat_interval_days!=null?String(vac.repeat_interval_days):'';
    const opts=intervals.map(i=>`<option value="${i.val}"${cur===i.val?' selected':''}>${i.lbl}</option>`).join('');
    return `<div style="display:flex;align-items:center;gap:8px;padding:5px 0;border-bottom:1px solid var(--card2)">
      <div style="flex:1">
        <div style="font-size:.8rem;color:var(--ink)">${esc(vac.name)}${vac.is_mandatory?' <span style="font-size:.6rem;color:var(--red)">Zorunlu</span>':''}</div>
        <div style="font-size:.65rem;color:var(--ink3)">${esc(vac.disease_target||'—')} · ${vac.dose||'?'} ${vac.unit||''}</div>
      </div>
      <select onchange="vaccineRapelGuncelle('${vac.id}',this.value)" style="padding:3px 5px;border:1px solid var(--brd);border-radius:6px;font-size:.7rem;min-width:80px">${opts}</select>
    </div>`;
  }).join('')+'</div>';
}

async function vaccineRapelGuncelle(vaccineId,val){
  const days=val===''?null:parseInt(val);
  try {
    await rpc('vaccine_rapel_guncelle',{p_vaccine_id:vaccineId,p_repeat_days:days});
    await pullTables(['vaccines']);
    toast('Rapel süresi güncellendi');
  } catch(e){ toast('Hata: '+e.message,true); }
}
// renderAyarlarSpermaList (eski local-array versiyonu) ölü kod olarak arşivlendi
// (js/_archive/ayarlarSperma.bak.js) — index.html'de giriş noktası yok.
function ayarlarHekimEkle(){ document.getElementById('ay-hekim-form').style.display='block'; }
async function ayarlarHekimKaydet(){
  const ad=v('ay-hek-ad').trim(); if(!ad) return;
  const tel=v('ay-hek-tel')||null;
  try {
    await rpc('hekim_ekle',{p_ad:ad,p_telefon:tel});
    await pullTables(['hekimler']);
    await loadHekimlerFromDB();
    populateHekimSelects();
    cl('ay-hek-ad');
    document.getElementById('ay-hekim-form').style.display='none';
    renderAyarlarHekimList();
    toast(`✅ ${ad} eklendi`);
  } catch(e){ toast('Hata: '+e.message,true); return; }
}

let _curHekimDet = null;
let _hekimPeriodDays = 'all';

async function hekimDetAc(id) {
  const hekimler = await getData('hekimler');
  const h = hekimler.find(x => x.id === id) || HEKIMLER.find(x => x.id === id);
  if (!h) return;
  _curHekimDet = h;
  _hekimPeriodDays = 'all';
  const title = g('hk-title'); if (title) title.textContent = h.ad;
  const ad = g('hk-ad'); if (ad) ad.value = h.ad || '';
  // Reset period tabs
  document.querySelectorAll('#hk-period-tabs .kat-btn').forEach(b => b.classList.remove('on'));
  document.querySelector('#hk-period-tabs .kat-btn').classList.add('on');
  await renderHekimStats();
  openM('m-hekim-det');
}

function hekimPeriod(days, e) {
  _hekimPeriodDays = days;
  document.querySelectorAll('#hk-period-tabs .kat-btn').forEach(b => b.classList.remove('on'));
  if (e && e.target) e.target.classList.add('on');
  renderHekimStats();
}

async function renderHekimStats() {
  const el = g('hk-stats');
  if (!el || !_curHekimDet) return;
  el.innerHTML = '<div class="loader" style="padding:20px"><div class="spin"></div></div>';

  const hid = _curHekimDet.id;
  const [tohumlar, dogumlar] = await Promise.all([
    getData('tohumlama'),
    getData('dogum')
  ]);

  // Period filter
  const cutoff = _hekimPeriodDays === 'all' ? null : dAgo(_hekimPeriodDays);
  const hToh = tohumlar.filter(t => t.hekim_id === hid && (!cutoff || t.tarih >= cutoff));
  const hDog = dogumlar.filter(d => d.hekim_id === hid && (!cutoff || d.tarih >= cutoff));

  // Stats
  const toplamToh = hToh.length;
  const gebeToh = hToh.filter(t => t.sonuc === 'Gebe').length;
  const bosToh = hToh.filter(t => t.sonuc === 'Boş').length;
  const bekliyorToh = hToh.filter(t => t.sonuc === 'Bekliyor').length;
  const basariOrani = toplamToh > 0 ? Math.round((gebeToh / (gebeToh + bosToh || 1)) * 100) : 0;
  const toplamDog = hDog.length;

  // Sperma breakdown
  const spermaMap = {};
  hToh.forEach(t => {
    const sp = t.sperma || 'Bilinmiyor';
    if (!spermaMap[sp]) spermaMap[sp] = { toplam: 0, gebe: 0 };
    spermaMap[sp].toplam++;
    if (t.sonuc === 'Gebe') spermaMap[sp].gebe++;
  });

  const spermaRows = Object.entries(spermaMap)
    .sort((a, b) => b[1].toplam - a[1].toplam)
    .map(([sp, d]) => {
      const oran = d.toplam > 0 ? Math.round((d.gebe / d.toplam) * 100) : 0;
      return `<div style="display:flex;justify-content:space-between;padding:3px 0;font-size:.72rem">
        <span style="color:var(--ink)">${sp}</span>
        <span style="color:var(--ink3)">${d.toplam} toh · %${oran} gebe</span>
      </div>`;
    }).join('');

  const barClr = basariOrani >= 50 ? 'var(--green)' : basariOrani >= 30 ? 'var(--orange)' : 'var(--red)';

  el.innerHTML = `
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:10px">
      <div style="background:var(--card2);border-radius:8px;padding:10px;text-align:center">
        <div style="font-size:1.3rem;font-weight:800;color:var(--ink)">${toplamToh}</div>
        <div style="font-size:.65rem;color:var(--ink3)">Tohumlama</div>
      </div>
      <div style="background:var(--card2);border-radius:8px;padding:10px;text-align:center">
        <div style="font-size:1.3rem;font-weight:800;color:${barClr}">%${basariOrani}</div>
        <div style="font-size:.65rem;color:var(--ink3)">Gebelik Oranı</div>
      </div>
      <div style="background:var(--card2);border-radius:8px;padding:10px;text-align:center">
        <div style="font-size:1.3rem;font-weight:800;color:var(--green)">${gebeToh}</div>
        <div style="font-size:.65rem;color:var(--ink3)">Gebe</div>
      </div>
      <div style="background:var(--card2);border-radius:8px;padding:10px;text-align:center">
        <div style="font-size:1.3rem;font-weight:800;color:var(--ink)">${toplamDog}</div>
        <div style="font-size:.65rem;color:var(--ink3)">Doğum</div>
      </div>
    </div>
    <div style="display:flex;gap:6px;margin-bottom:8px;font-size:.65rem;color:var(--ink3)">
      <span>${bosToh} Boş</span> · <span>${bekliyorToh} Bekliyor</span>
    </div>
    ${spermaRows ? `<div style="background:var(--card2);border-radius:8px;padding:8px 10px;margin-bottom:8px">
      <div style="font-size:.65rem;font-weight:700;color:var(--ink3);margin-bottom:4px">Sperma Kullanımı</div>
      ${spermaRows}
    </div>` : ''}
  `;
}

async function hekimDetKaydet() {
  if (!_curHekimDet) return;
  const ad = v('hk-ad').trim();
  if (!ad) { toast('Hekim adı boş olamaz', true); return; }
  const tel=v('hk-tel')||null;
  try {
    await rpc('hekim_guncelle',{p_hekim_id:_curHekimDet.id,p_ad:ad,p_telefon:tel});
    await pullTables(['hekimler']);
    await loadHekimlerFromDB();
    populateHekimSelects();
    closeM('m-hekim-det');
    renderAyarlarHekimList();
    toast('Hekim güncellendi');
  } catch(e){ toast('Hata: '+e.message,true); return; }
}

async function hekimDetSil() {
  if (!_curHekimDet) return;
  try {
    await rpc('hekim_sil', { p_hekim_id: _curHekimDet.id });
  } catch (e) {
    toast(e.message || 'Silinemedi', true);
    return;
  }
  await pullTables(['hekimler']);
  await loadHekimlerFromDB();
  populateHekimSelects();
  closeM('m-hekim-det');
  renderAyarlarHekimList();
  toast('Hekim silindi');
}

// ayarlarSpermaEkle / ayarlarSpermaKaydet / renderAyarlarSpermaList (DB-backed) /
// spermaSil — ölü kod olarak arşivlendi (js/_archive/ayarlarSperma.bak.js):
// index.html'de giriş noktası (ay-sperma-list/-form/-kod elementleri) hiç yok.

// ── PADOK CRUD ──────────────────────────────
async function renderAyarlarPadokList(){
  const el=document.getElementById('ay-padok-list'); if(!el) return;
  const padoklar=await getData('padoklar');
  if(!padoklar.length){ el.innerHTML='<div style="font-size:.75rem;color:var(--ink3)">Henüz padok tanımlı değil</div>'; return; }
  el.innerHTML=padoklar.map(p=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.82rem;color:var(--ink)">${esc(p.ad)}${p.kapasite?' <span style="font-size:.65rem;color:var(--ink3)">(${p.kapasite} baş)</span>':''}</span>
    <div style="display:flex;gap:4px">
      <button onclick="padokDetayAc('${p.id}')" style="background:none;border:none;color:var(--blue);font-size:.72rem;cursor:pointer;padding:4px 6px">📋</button>
      <button onclick="padokDuzenleAc('${p.id}')" style="background:none;border:none;color:var(--ink3);font-size:.75rem;cursor:pointer;padding:4px 8px">✏️</button>
    </div>
  </div>`).join('');
}

let _curPadokDet=null;
async function padokDuzenleAc(id){
  const padoklar=await getData('padoklar');
  const p=padoklar.find(x=>x.id===id);
  if(!p) return;
  _curPadokDet=p;
  document.getElementById('padok-det-title').textContent=p.ad;
  document.getElementById('pd-ad').value=p.ad||'';
  document.getElementById('pd-kap').value=p.kapasite||'';
  openM('m-padok-det');
}

async function padokDuzenleKaydet(){
  if(!_curPadokDet) return;
  const ad=document.getElementById('pd-ad').value.trim();
  if(!ad){ toast('Padok adı boş olamaz',true); return; }
  const kap=parseInt(document.getElementById('pd-kap').value)||null;
  try {
    await rpc('padok_guncelle',{p_padok_id:_curPadokDet.id,p_ad:ad,p_kapasite:kap,p_sira:null});
    await pullTables(['padoklar']);
    await loadPadokConfig();
    closeM('m-padok-det');
    renderAyarlarPadokList();
    renderGrupPadokEslem();
    toast('Padok güncellendi');
  } catch(e){ toast('Hata: '+e.message,true); return; }
}

async function padokSilOnay(){
  if(!_curPadokDet) return;
  const id=_curPadokDet.id;
  const hayvanlar=await getData('hayvanlar');
  const count=hayvanlar.filter(h=>h.padok_id===id&&h.durum==='Aktif').length;
  if(count>0){ toast(`Bu padokta ${count} aktif hayvan var — önce hayvanları başka padoğa taşıyın`,true); return; }
  openConfirm('Padok Sil',`"${_curPadokDet.ad}" silinecek. Emin misiniz?`,async()=>{
    try {
      await rpc('padok_sil',{p_padok_id:id});
      await pullTables(['padoklar','grup_padok_eslem']);
      await loadPadokConfig();
      closeM('m-padok-det');
      renderAyarlarPadokList();
      renderGrupPadokEslem();
      toast('Padok silindi');
    } catch(e){ toast('Hata: '+e.message,true); }
  });
}

// ── Padok Detay + Transfer Functions ──

let _pdHayvanIds = []; // selected hayvan IDs for bulk transfer
let _pdTransferHayvanIds = []; // hayvan IDs pending transfer
let _pdKaynakPadokId = null; // source padok for transfer

// ── Toplu Transfer state ──
let _btSecimModu = false;
let _btSecilenIds = [];        // Cross-padok, filtreden bağımsız korunur
let _btModalSecilenIds = [];   // Modal içinde onaylanan hayvanlar
let _btHedefPadokId = null;    // Seçilen hedef padok ID
let _btEtiketMod = null;       // 'toplu' | 'tektek' | null
let _btYeniGrup = null;        // Toplu grup değişimi için seçilen yeni grup (null = grup değişmez)

function renderPadokDolulukBar() {
  const el = document.getElementById('padok-doluluk-bar');
  if (!el) return;
  if (!PADOKLAR.length) { el.innerHTML = ''; return; }
  const pfltSel = document.getElementById('pflt');
  if (pfltSel) {
    const cur = pfltSel.value;
    pfltSel.innerHTML = '<option value="">Tüm Padoklar</option>' +
      PADOKLAR.map(p => `<option value="${esc(p.ad)}">${esc(p.ad)}</option>`).join('');
    pfltSel.value = cur;
  }
  const animals = getState('animals') || [];
  const padokSayac = {};
  animals.forEach(h => {
    if (h.durum === 'Aktif' && h.padok_id) {
      padokSayac[h.padok_id] = (padokSayac[h.padok_id] || 0) + 1;
    }
  });
  el.innerHTML = PADOKLAR.map(p => {
    const dolu = padokSayac[p.id] || 0;
    const kap = p.kapasite;
    const padokAdi = (p.ad || '').replace(' Padok', '');
    if (!kap) {
      return `<div class="pdoluluk-chip" data-ad="${escAttr(p.ad)}" onclick="setPadokFiltreBt('${p.id}',this.dataset.ad)" title="${escAttr(p.ad)}: ${dolu} hayvan">
        <span class="pdoluluk-ad">${esc(padokAdi)}</span>
        <span class="pdoluluk-sayi">${dolu}</span>
      </div>`;
    }
    const yuzde = Math.round((dolu / kap) * 100);
    const renk = yuzde >= 100 ? 'var(--red)' : yuzde >= 80 ? 'var(--amber)' : 'var(--green)';
    return `<div class="pdoluluk-chip" data-ad="${escAttr(p.ad)}" onclick="setPadokFiltreBt('${p.id}',this.dataset.ad)" title="${escAttr(p.ad)}: ${dolu}/${kap}">
      <span class="pdoluluk-ad">${esc(padokAdi)}</span>
      <div class="pdoluluk-bar-wrap"><div class="pdoluluk-fill" style="width:${Math.min(yuzde,100)}%;background:${renk}"></div></div>
      <span class="pdoluluk-sayi" style="color:${renk}">${dolu}/${kap}</span>
    </div>`;
  }).join('');
}

function setPadokFiltreBt(padokId, padokAdi) {
  const sel = document.getElementById('pflt');
  if (sel) {
    sel.value = padokAdi;
    sel.dispatchEvent(new Event('change', { bubbles: true }));
  }
}

function enterBtSecimModu() {
  _btSecimModu = true;
  _btSecilenIds = [];
  const btn = document.getElementById('bt-toggle-btn');
  if (btn) {
    btn.textContent = '✕ İptal';
    btn.style.borderColor = 'var(--red)';
    btn.style.color = 'var(--red)';
    btn.style.background = 'rgba(192,50,26,.1)';
  }
  const banner = document.getElementById('bt-banner');
  if (banner) banner.style.display = 'flex';
  const bar = document.getElementById('bt-action-bar');
  if (bar) bar.style.display = 'block';
  _btGuncelleActionBar();
  _btRenderSuru();
}

function exitBtSecimModu() {
  _btSecimModu = false;
  _btSecilenIds = [];
  const btn = document.getElementById('bt-toggle-btn');
  if (btn) {
    btn.textContent = '🔀 Toplu Taşı';
    btn.style.borderColor = '';
    btn.style.color = '';
    btn.style.background = '';
  }
  const banner = document.getElementById('bt-banner');
  if (banner) banner.style.display = 'none';
  const bar = document.getElementById('bt-action-bar');
  if (bar) bar.style.display = 'none';
  const transferBtn = document.getElementById('bt-transfer-btn');
  if (transferBtn) transferBtn.disabled = true;
  _btRenderSuru();
}

function btToggleSecimModu() {
  if (_btSecimModu) exitBtSecimModu();
  else enterBtSecimModu();
}

function _btRenderSuru() {
  const suruEl = document.getElementById('suru-body') || document.getElementById('suru-list');
  if (!suruEl) return;
  if (_btSecimModu) {
    suruEl.classList.add('bt-mode');
  } else {
    suruEl.classList.remove('bt-mode');
  }
  document.querySelectorAll('.animal-card').forEach(card => {
    const id = card.dataset.id || card.dataset.hayvanId;
    if (id) card.classList.toggle('bt-selected', _btSecilenIds.includes(id));
  });
}

function _btKartTikla(id, event) {
  event.stopPropagation();
  const idx = _btSecilenIds.indexOf(id);
  if (idx > -1) _btSecilenIds.splice(idx, 1);
  else _btSecilenIds.push(id);
  _btGuncelleActionBar();
  _btRenderSuru();
}

function btCbDegisti(id, checked) {
  if (checked) {
    if (!_btSecilenIds.includes(id)) _btSecilenIds.push(id);
  } else {
    _btSecilenIds = _btSecilenIds.filter(x => x !== id);
  }
  _btGuncelleActionBar();
  _btRenderSuru();
}

function _btGuncelleActionBar() {
  const count = _btSecilenIds.length;
  const countEl = document.getElementById('bt-count');
  if (countEl) countEl.textContent = `${count} hayvan seçildi`;
  const suruData = getState('animals') || [];
  const padoklar = new Set(
    suruData.filter(h => _btSecilenIds.includes(h.id)).map(h => h.padok_id).filter(Boolean)
  );
  const padokCountEl = document.getElementById('bt-padok-count');
  if (padokCountEl) padokCountEl.textContent = padoklar.size > 0 ? `(${padoklar.size} padok)` : '';
  const transferBtn = document.getElementById('bt-transfer-btn');
  if (transferBtn) {
    transferBtn.disabled = count === 0;
    transferBtn.textContent = count > 0 ? `🔀 ${count} Taşı` : '🔀 Taşı';
  }
}

function openBulkTransfer() {
  if (!_btSecilenIds.length) return;
  _btModalSecilenIds = [..._btSecilenIds];
  _btHedefPadokId = null;
  _btEtiketMod = null;
  _btYeniGrup = null;
  const grupSel = document.getElementById('bt-f-grup');
  if (grupSel) {
    const gruplar = Object.keys(GRUP_PADOK);
    grupSel.innerHTML = '<option value="">Tüm Gruplar</option>' +
      gruplar.map(g => `<option>${g}</option>`).join('');
  }
  const kaynakSel = document.getElementById('bt-kaynak-padok-sel');
  if (kaynakSel) {
    kaynakSel.innerHTML = '<option value="">— Padok Seç —</option>' +
      PADOKLAR.map(p => `<option value="${p.id}">${esc(p.ad)}</option>`).join('');
  }
  _btRenderSerbestListe();
  _btRenderSeciliHayvanlar();
  _btRenderHedefPadoklar();
  const ozet = document.getElementById('bt-ozet');
  if (ozet) ozet.style.display = 'none';
  const etiketBolum = document.getElementById('bt-etiket-bolum');
  if (etiketBolum) etiketBolum.style.display = 'none';
  const grupBolum = document.getElementById('bt-grup-bolum');
  if (grupBolum) grupBolum.style.display = 'none';
  const onayBtn = document.getElementById('bt-onay-btn');
  if (onayBtn) onayBtn.disabled = true;
  openM('m-bulk-transfer');
  exitBtSecimModu();
}

function _btRenderSeciliHayvanlar() {
  const liste = document.getElementById('bt-secili-liste');
  const sayac = document.getElementById('bt-secili-sayac');
  if (!liste) return;
  const suruData = getState('animals') || [];
  const hayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
  sayac.textContent = `${hayvanlar.length} hayvan`;
  if (!hayvanlar.length) {
    liste.innerHTML = '<div style="color:var(--ink3);font-size:.78rem;padding:8px;text-align:center">Hayvan seçilmedi</div>';
    return;
  }
  liste.innerHTML = hayvanlar.map(h => `
    <div class="bt-hayvan-satir">
      <span style="font-weight:600;font-size:.8rem">${esc(h.kupe_no || h.id)}</span>
      <span style="font-size:.68rem;color:var(--ink3);flex:1;margin:0 6px">${esc(h.grup || '')} · ${esc(h.padok || '')}</span>
      <button onclick="btSecilidenKaldir('${h.id}')" style="background:none;border:none;color:var(--ink3);cursor:pointer;font-size:1rem;padding:2px 4px;line-height:1" title="Çıkar">×</button>
    </div>
  `).join('');
}

function btSecilidenKaldir(id) {
  _btModalSecilenIds = _btModalSecilenIds.filter(x => x !== id);
  _btRenderSeciliHayvanlar();
  _btRenderHedefPadoklar();
  _btGuncelleOzet();
  if (!_btModalSecilenIds.length) {
    const onayBtn = document.getElementById('bt-onay-btn');
    if (onayBtn) onayBtn.disabled = true;
  }
}

function _btRenderSerbestListe() {
  const el = document.getElementById('bt-serbest-input');
  if (el) el.value = '';
  const sonuc = document.getElementById('bt-serbest-sonuc');
  if (sonuc) sonuc.textContent = '';
}

function btSerbestYukle() {
  const input = document.getElementById('bt-serbest-input');
  const sonuc = document.getElementById('bt-serbest-sonuc');
  if (!input || !sonuc) return;
  const satirlar = input.value.split('\n').map(s => s.trim()).filter(Boolean);
  if (!satirlar.length) { sonuc.textContent = ''; return; }
  const suruData = getState('animals') || [];
  let eslesen = 0, bulunamayan = [];
  satirlar.forEach(aranan => {
    const hayvan = suruData.find(h =>
      h.kupe_no === aranan || h.devlet_kupe === aranan || h.id === aranan
    );
    if (hayvan && !_btModalSecilenIds.includes(hayvan.id)) {
      _btModalSecilenIds.push(hayvan.id);
      eslesen++;
    } else if (!hayvan) {
      bulunamayan.push(aranan);
    }
  });
  sonuc.textContent = `${eslesen} hayvan eklendi` + (bulunamayan.length ? ` · ${bulunamayan.length} bulunamadı: ${bulunamayan.slice(0,3).join(', ')}${bulunamayan.length > 3 ? '…' : ''}` : '');
  sonuc.style.color = bulunamayan.length ? 'var(--amber)' : 'var(--green3)';
  _btRenderSeciliHayvanlar();
  _btRenderHedefPadoklar();
  _btGuncelleOzet();
}

function _btGrupUygunMu(padok, gruplar) {
  if (!gruplar.length) return true;
  return gruplar.some(g => {
    const uyumluPadoklar = GRUP_PADOK[g];
    return uyumluPadoklar && uyumluPadoklar.includes(padok.ad);
  });
}

function _btBesiPadokMu(padok) {
  const ad = (padok.ad || '').toLowerCase();
  return ad.includes('besi');
}

function _btRenderHedefPadoklar() {
  const el = document.getElementById('bt-hedef-liste');
  if (!el) return;
  const suruData = getState('animals') || [];
  const secilenHayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
  const gruplar = [...new Set(secilenHayvanlar.map(h => h.grup).filter(Boolean))];
  const kaynakPadoklar = new Set(secilenHayvanlar.map(h => h.padok_id).filter(Boolean));
  el.innerHTML = PADOKLAR.map(p => {
    const dolu = suruData.filter(h => h.padok_id === p.id && h.durum === 'Aktif').length;
    const kap = p.kapasite;
    const yuzde = kap ? Math.round((dolu / kap) * 100) : 0;
    const tamDolu = kap && dolu >= kap;
    const uyari = kap && yuzde >= 80 && !tamDolu;
    const uygun = _btGrupUygunMu(p, gruplar);
    const besi = _btBesiPadokMu(p);
    if (kaynakPadoklar.size === 1 && kaynakPadoklar.has(p.id)) return '';
    const disabled = tamDolu;  // uyumsuz padok artık tıklanabilir (grup değişimi ile)
    const renk = yuzde >= 100 ? 'var(--red)' : yuzde >= 80 ? 'var(--amber)' : 'var(--green)';
    const selected = _btHedefPadokId === p.id;
    let badge = '';
    if (tamDolu) badge = '<span style="font-size:.6rem;color:var(--red);font-weight:700">DOLU</span>';
    else if (!uygun && !besi) badge = '<span style="font-size:.6rem;color:var(--blue)">🔀 Grup değişir</span>';
    else if (!uygun && besi) badge = '<span style="font-size:.6rem;color:var(--amber)">⚠️ Etiket gerekli</span>';
    else if (uyari) badge = '<span style="font-size:.6rem;color:var(--amber)">⚠️ Dolmak üzere</span>';
    else badge = '<span style="font-size:.6rem;color:var(--green3)">✅ Uyumlu</span>';
    return `<div class="bt-padok-opt ${disabled?'disabled':''} ${selected?'selected':''}"
                 onclick="${disabled?'':'btHedefSec(\''+p.id+'\')'}">
      <span class="bpo-ad">${esc(p.ad)}</span>
      ${badge}
      ${kap ? `<div>
        <div class="bpo-bar-wrap"><div class="bpo-bar-fill" style="width:${Math.min(yuzde,100)}%;background:${renk}"></div></div>
        <div style="font-size:.6rem;color:${renk};text-align:right">${dolu}/${kap}</div>
      </div>` : ''}
    </div>`;
  }).join('');
}

function btHedefSec(padokId) {
  _btHedefPadokId = padokId;
  _btYeniGrup = null;
  const hedef = PADOKLAR.find(p => p.id === padokId);
  const suruData = getState('animals') || [];
  const secilen = suruData.filter(h => _btModalSecilenIds.includes(h.id));
  const gruplar = [...new Set(secilen.map(h => h.grup).filter(Boolean))];
  const grupBolum = document.getElementById('bt-grup-bolum');
  const grupSel = document.getElementById('bt-yeni-grup');
  const uygun = hedef ? _btGrupUygunMu(hedef, gruplar) : true;
  if (grupBolum && grupSel) {
    if (!uygun && hedef) {
      // Hedef padoğa izinli grupları doldur (GRUP_PADOK ters eşleme)
      const izinli = Object.keys(GRUP_PADOK).filter(g => (GRUP_PADOK[g] || []).includes(hedef.ad));
      grupSel.innerHTML = '<option value="">— Yeni grup seç —</option>' +
        izinli.map(g => `<option value="${g}">${g}</option>`).join('');
      grupBolum.style.display = izinli.length ? 'block' : 'none';
    } else {
      grupBolum.style.display = 'none';
      grupSel.value = '';
    }
  }
  _btGuncelleOzet();
  _btRenderHedefPadoklar();
}

function btYeniGrupDegisti() {
  const grupSel = document.getElementById('bt-yeni-grup');
  _btYeniGrup = (grupSel && grupSel.value) ? grupSel.value : null;
  _btGuncelleOzet();
}

function _btGuncelleOzet() {
  const ozet = document.getElementById('bt-ozet');
  const etiketBolum = document.getElementById('bt-etiket-bolum');
  const onayBtn = document.getElementById('bt-onay-btn');
  if (!_btModalSecilenIds.length || !_btHedefPadokId) {
    if (ozet) ozet.style.display = 'none';
    if (etiketBolum) etiketBolum.style.display = 'none';
    if (onayBtn) onayBtn.disabled = true;
    return;
  }
  const suruData = getState('animals') || [];
  const hedef = PADOKLAR.find(p => p.id === _btHedefPadokId);
  if (!hedef) return;
  const secilenHayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
  const gruplar = _btYeniGrup ? [_btYeniGrup] : [...new Set(secilenHayvanlar.map(h => h.grup).filter(Boolean))];
  const dolu = suruData.filter(h => h.padok_id === hedef.id && h.durum === 'Aktif').length;
  const kap = hedef.kapasite;
  const uygun = _btGrupUygunMu(hedef, gruplar);
  const besi = _btBesiPadokMu(hedef);
  const kapUygun = !kap || (dolu + _btModalSecilenIds.length <= kap);
  const yeniDoluluk = kap ? Math.round(((dolu + _btModalSecilenIds.length) / kap) * 100) : 0;
  if (ozet) ozet.style.display = 'block';
  const trEl = document.getElementById('bt-ozet-transfer');
  if (trEl) { trEl.textContent = `${_btModalSecilenIds.length} hayvan → ${hedef.ad}`; trEl.className = 'ozet-value ok'; }
  const kapEl = document.getElementById('bt-ozet-kap');
  if (kapEl) {
    if (!kap) { kapEl.textContent = 'Kapasite tanımsız'; kapEl.style.color = 'var(--ink3)'; }
    else if (kapUygun) { kapEl.textContent = `✓ ${dolu + _btModalSecilenIds.length}/${kap} (%${yeniDoluluk})`; kapEl.style.color = yeniDoluluk >= 80 ? 'var(--amber)' : 'var(--green3)'; }
    else { kapEl.textContent = `✗ ${dolu + _btModalSecilenIds.length}/${kap} — Kapasite aşımı!`; kapEl.style.color = 'var(--red)'; }
  }
  const gpEl = document.getElementById('bt-ozet-grup');
  if (gpEl) {
    if (uygun) { gpEl.textContent = '✓ Tüm hayvanlar için uyumlu'; gpEl.style.color = 'var(--green3)'; }
    else if (besi) { gpEl.textContent = '⚠️ Etiket gerekli (besi transferi)'; gpEl.style.color = 'var(--amber)'; }
    else { gpEl.textContent = '✗ Grup uyumsuz'; gpEl.style.color = 'var(--red)'; }
  }
  const etiketGerekli = besi && !uygun;
  if (etiketBolum) etiketBolum.style.display = etiketGerekli ? 'block' : 'none';
  if (etiketGerekli) _btRenderEtiketTekkek();
  const etiketOk = !etiketGerekli || _btEtiketleriKontrolEt();
  if (onayBtn) {
    onayBtn.disabled = !(kapUygun && (uygun || besi || _btYeniGrup) && etiketOk);
    onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`;
  }
}

function _btRenderEtiketTekkek() {
  const el = document.getElementById('bt-etiket-tektek-liste');
  if (!el) return;
  const suruData = getState('animals') || [];
  const hayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
  el.innerHTML = hayvanlar.map(h => `
    <div style="display:flex;align-items:center;gap:8px;padding:4px 0;font-size:.78rem;border-bottom:1px solid var(--card2)">
      <span style="font-weight:600;min-width:60px">${esc(h.kupe_no||h.id)}</span>
      <span style="font-size:.68rem;color:var(--ink3);flex:1">${esc(h.grup||'')}</span>
      <label style="display:inline-flex;align-items:center;gap:4px;cursor:pointer">
        <input type="checkbox" data-hayvan="${h.id}" data-etiket="kisir" onchange="btEtiketTekkekDegisti()" style="accent-color:var(--blue)"> Kısır
      </label>
      <label style="display:inline-flex;align-items:center;gap:4px;cursor:pointer">
        <input type="checkbox" data-hayvan="${h.id}" data-etiket="satista" onchange="btEtiketTekkekDegisti()" style="accent-color:var(--blue)"> Satışta
      </label>
    </div>
  `).join('');
}

function btEtiketTopluDegisti() {
  _btEtiketMod = 'toplu';
  document.querySelectorAll('#bt-etiket-tektek-liste input[type=checkbox]').forEach(cb => { cb.checked = false; });
  _btGuncelleOzet();
}

function btEtiketTekkekDegisti() {
  _btEtiketMod = 'tektek';
  const topluKisir = document.getElementById('bt-et-toplu-kisir');
  if (topluKisir) topluKisir.checked = false;
  const topluSatista = document.getElementById('bt-et-toplu-satista');
  if (topluSatista) topluSatista.checked = false;
  _btGuncelleOzet();
}

function _btEtiketleriKontrolEt() {
  const topluKisir = document.getElementById('bt-et-toplu-kisir')?.checked;
  const topluSatista = document.getElementById('bt-et-toplu-satista')?.checked;
  if (topluKisir || topluSatista) return true;
  const tekTekCbs = document.querySelectorAll('#bt-etiket-tektek-liste input[type=checkbox]');
  if (!tekTekCbs.length) return false;
  const hayvanEtiketler = {};
  tekTekCbs.forEach(cb => { if (cb.checked) hayvanEtiketler[cb.dataset.hayvan] = true; });
  return _btModalSecilenIds.every(id => hayvanEtiketler[id]);
}

function _btEtiketleriBir() {
  const topluKisir = document.getElementById('bt-et-toplu-kisir')?.checked;
  const topluSatista = document.getElementById('bt-et-toplu-satista')?.checked;
  if (topluKisir || topluSatista) {
    const etiketler = [];
    if (topluKisir) etiketler.push('kisir');
    if (topluSatista) etiketler.push('satista');
    return { mod: 'toplu', etiketler };
  }
  const tekTekCbs = document.querySelectorAll('#bt-etiket-tektek-liste input[type=checkbox]');
  const map = {};
  tekTekCbs.forEach(cb => {
    if (cb.checked) {
      if (!map[cb.dataset.hayvan]) map[cb.dataset.hayvan] = [];
      map[cb.dataset.hayvan].push(cb.dataset.etiket);
    }
  });
  return { mod: 'tektek', map };
}

async function btTransferOnayla() {
  if (!_btModalSecilenIds.length || !_btHedefPadokId) return;
  const onayBtn = document.getElementById('bt-onay-btn');
  if (onayBtn) { onayBtn.disabled = true; onayBtn.textContent = '⏳ Taşınıyor…'; }
  try {
    let etiketParam = null;
    const hedef = PADOKLAR.find(p => p.id === _btHedefPadokId);
    const suruData = getState('animals') || [];
    const secilenHayvanlar = suruData.filter(h => _btModalSecilenIds.includes(h.id));
    const gruplar = [...new Set(secilenHayvanlar.map(h => h.grup).filter(Boolean))];
    if (_btBesiPadokMu(hedef) && !_btGrupUygunMu(hedef, gruplar)) {
      const etiketBilgi = _btEtiketleriBir();
      if (etiketBilgi.mod === 'tektek') {
        // Per-animal etiket — her hayvan için ayrı RPC çağrısı
        for (const hayvanId of _btModalSecilenIds) {
          const hayvanEtiketler = etiketBilgi.map[hayvanId] || [];
          const { data: d, error: e } = await db.rpc('padok_degistir_toplu', {
            p_hayvan_ids: [hayvanId], p_yeni_padok_id: _btHedefPadokId,
            p_etiketler: hayvanEtiketler.length ? hayvanEtiketler : null,
            p_yeni_grup: _btYeniGrup
          });
          if (e) throw e;
          if (!d.success) {
            if (d.error === 'kapasite_dolu') toast(`❌ Kapasite dolu: ${d.detay || ''}. Transfer iptal edildi.`, true);
            else toast(`❌ Transfer başarısız: ${d.mesaj || d.error || 'Hata'}`, true);
            if (onayBtn) { onayBtn.disabled = false; onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`; }
            return;
          }
        }
        toast(`✅ ${_btModalSecilenIds.length} hayvan ${hedef.ad}'a taşındı`);
      } else {
        etiketParam = etiketBilgi.etiketler;
        const { data, error } = await db.rpc('padok_degistir_toplu', {
          p_hayvan_ids: _btModalSecilenIds, p_yeni_padok_id: _btHedefPadokId, p_etiketler: etiketParam,
          p_yeni_grup: _btYeniGrup
        });
        if (error) throw error;
        if (!data.success) {
          if (data.error === 'kapasite_dolu') toast(`❌ Kapasite dolu: ${data.detay || ''}. Transfer iptal edildi.`, true);
          else toast(`❌ Transfer başarısız: ${data.mesaj || data.error || 'Hata'}`, true);
          if (onayBtn) { onayBtn.disabled = false; onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`; }
          return;
        }
        toast(`✅ ${data.hayvan_sayisi} hayvan ${data.yeni_padok}'a taşındı`);
      }
    } else {
      const { data, error } = await db.rpc('padok_degistir_toplu', {
        p_hayvan_ids: _btModalSecilenIds, p_yeni_padok_id: _btHedefPadokId, p_etiketler: null,
        p_yeni_grup: _btYeniGrup
      });
      if (error) throw error;
      if (!data.success) {
        if (data.error === 'kapasite_dolu') toast(`❌ Kapasite dolu: ${data.detay || ''}. Transfer iptal edildi.`, true);
        else toast(`❌ Transfer başarısız: ${data.mesaj || data.error || 'Hata'}`, true);
        if (onayBtn) { onayBtn.disabled = false; onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`; }
        return;
      }
      toast(`✅ ${data.hayvan_sayisi} hayvan ${data.yeni_padok}'a taşındı`);
    }
    closeM('m-bulk-transfer');
    await pullTables(['hayvanlar', 'gorev_log', 'islem_log']);
    if (typeof loadAnimals === 'function') await loadAnimals();
    if (typeof renderPadokDolulukBar === 'function') renderPadokDolulukBar();
  } catch (err) {
    console.error('btTransferOnayla hata:', err);
    toast('❌ Beklenmeyen hata: ' + (err.message || err), true);
    if (onayBtn) { onayBtn.disabled = false; onayBtn.textContent = `🔀 ${_btModalSecilenIds.length} Hayvanı Taşı`; }
  }
}

async function padokDetayAc(id) {
  const padoklar = await getData('padoklar');
  const p = padoklar.find(x => x.id === id);
  if (!p) return;
  _curPadokDet = p;
  document.getElementById('padok-det-title').textContent = p.ad;
  document.getElementById('pd-ad').value = p.ad || '';
  document.getElementById('pd-kap').value = p.kapasite || '';
  _pdHayvanIds = [];
  _pdKaynakPadokId = id;
  document.getElementById('pd-toplu-tasi-btn').style.display = 'none';
  openM('m-padok-det');
  await renderPadokHayvanlar(id);
}

async function renderPadokHayvanlar(padokId) {
  const el = document.getElementById('pd-hayvan-listesi');
  const sayiEl = document.getElementById('pd-hayvan-sayisi');
  if (!el) return;
  try {
    const hayvanlar = await getData('hayvanlar');
    const filtre = (document.getElementById('pd-hayvan-filtre')?.value || '').toLowerCase().trim();
    let padokHayvanlar = hayvanlar.filter(h => h.padok_id === padokId && h.durum === 'Aktif');
    if (filtre) {
      padokHayvanlar = padokHayvanlar.filter(h =>
        (h.kupe_no || '').toLowerCase().includes(filtre) ||
        (h.devlet_kupe || '').toLowerCase().includes(filtre) ||
        (h.irk || '').toLowerCase().includes(filtre)
      );
    }
    sayiEl.textContent = padokHayvanlar.length;
    if (!padokHayvanlar.length) {
      el.innerHTML = '<div class="empty"><div class="empty-ico">🐄</div>Bu padokta hayvan yok</div>';
      return;
    }
    el.innerHTML = padokHayvanlar.map(h => {
      const yas = h.dogum_tarihi ? (() => {
        const diff = Date.now() - new Date(h.dogum_tarihi).getTime();
        const gun = Math.floor(diff / 86400000);
        const ay = Math.floor(gun / 30);
        return ay > 0 ? `${ay} ay` : `${gun} gün`;
      })() : '—';
      const secili = _pdHayvanIds.includes(h.id);
      return `<div style="display:flex;align-items:center;gap:8px;padding:6px 4px;border-bottom:1px solid var(--card3)">
        <input type="checkbox" ${secili ? 'checked' : ''} onchange="pdToggleHayvan('${h.id}',this.checked)" style="width:16px;height:16px;cursor:pointer">
        <span style="flex:1;font-weight:600;color:var(--ink);font-size:.8rem">${esc(h.kupe_no || h.devlet_kupe || h.id)}</span>
        <span style="font-size:.7rem;color:var(--ink3)">${esc(h.grup || '—')} · ${esc(h.cinsiyet || '—')} · ${yas}</span>
        <button class="btn" data-kupe="${escAttr(h.kupe_no || h.devlet_kupe || h.id)}" style="padding:3px 8px;font-size:.7rem;background:rgba(42,107,181,.1);color:var(--blue);border:1px solid rgba(42,107,181,.2)" onclick="padokTekliTasi('${h.id}',this.dataset.kupe)">➡️</button>
      </div>`;
    }).join('');
  } catch (e) {
    el.innerHTML = `<div class="empty">⚠️ ${esc(e.message)}</div>`;
  }
}

function pdToggleHayvan(id, checked) {
  if (checked) {
    if (!_pdHayvanIds.includes(id)) _pdHayvanIds.push(id);
  } else {
    _pdHayvanIds = _pdHayvanIds.filter(x => x !== id);
  }
  document.getElementById('pd-toplu-tasi-btn').style.display = _pdHayvanIds.length > 0 ? 'inline-block' : 'none';
}

function padokTekliTasi(hayvanId, kupe) {
  _pdTransferHayvanIds = [hayvanId];
  document.getElementById('pt-bilgi').textContent = `🐄 ${kupe} → hedef padok seçin:`;
  _pdTransferAcSelector();
}

function padokTopluTasi() {
  if (!_pdHayvanIds.length) { toast('⚠️ Lütfen en az bir hayvan seçin', true); return; }
  _btSecilenIds = [..._pdHayvanIds];
  _btModalSecilenIds = [..._pdHayvanIds];
  _btHedefPadokId = null;
  openBulkTransfer();
}

async function _pdTransferAcSelector() {
  const sel = document.getElementById('pt-select');
  sel.innerHTML = '<option value="">Seçiniz...</option>';
  const padoklar = await getData('padoklar');
  const hedefPadoklar = padoklar.filter(p => p.id !== _pdKaynakPadokId);
  hedefPadoklar.forEach(p => {
    const opt = document.createElement('option');
    opt.value = p.id;
    opt.textContent = p.ad;
    sel.appendChild(opt);
  });
  openM('m-padok-transfer');
}

async function padokTransferOnayla() {
  const sel = document.getElementById('pt-select');
  const hedefId = sel.value;
  if (!hedefId) { toast('⚠️ Lütfen bir hedef padok seçin', true); return; }
  const hedefAd = sel.options[sel.selectedIndex]?.text || '?';
  closeM('m-padok-transfer');
  const ids = _pdTransferHayvanIds;
  if (!ids.length) return;
  try {
    if (ids.length === 1) {
      // Single transfer via existing RPC
      const res = await rpc('padok_degistir', { p_hayvan_id: ids[0], p_yeni_padok_id: hedefId });
      if (res && res.success) {
        toast(`✅ ${res.yeni_padok} taşındı`);
      } else {
        toast(`⚠️ ${res?.error || 'İşlem başarısız'}`, true);
      }
    } else {
      // Bulk transfer
      const res = await rpc('padok_degistir_toplu', { p_hayvan_ids: ids, p_yeni_padok_id: hedefId });
      if (res && res.success) {
        toast(`✅ ${res.hayvan_sayisi} hayvan ${res.yeni_padok}'a taşındı`);
      } else {
        toast(`⚠️ ${res?.error || 'Toplu işlem başarısız'}`, true);
      }
    }
    // Refresh
    _pdHayvanIds = [];
    document.getElementById('pd-toplu-tasi-btn').style.display = 'none';
    await pullTables(['hayvanlar']);
    await renderPadokHayvanlar(_pdKaynakPadokId);
  } catch (e) {
    toast(`⚠️ ${esc(e.message)}`, true);
  }
}

// ── End Padok Detay + Transfer ──

async function renderGrupPadokEslem(){
  const el=document.getElementById('ay-grup-padok-list'); if(!el) return;
  const [padoklar,eslem]=await Promise.all([getData('padoklar'),getData('grup_padok_eslem')]);
  const gruplar=Object.keys(GRUP_PADOK);
  if(!padoklar.length){ el.innerHTML='<div style="font-size:.75rem;color:var(--ink3)">Önce padok ekleyin</div>'; return; }
  const eslemMap={};
  eslem.forEach(e=>{ if(!eslemMap[e.grup]) eslemMap[e.grup]=new Set(); eslemMap[e.grup].add(e.padok_id); });
  el.innerHTML=gruplar.map(g=>{
    const secili=eslemMap[g]||new Set();
    const boxes=padoklar.map(p=>`
      <label style="display:flex;align-items:center;gap:5px;font-size:.75rem;color:var(--ink);padding:2px 0;cursor:pointer">
        <input type="checkbox" value="${p.id}" ${secili.has(p.id)?'checked':''} data-grup="${escAttr(g)}" onchange="grupPadokCheckbox(this.dataset.grup,this)">
        ${esc(p.ad)}
      </label>`).join('');
    return `<div style="padding:6px 0;border-bottom:1px solid var(--card2)">
      <div style="font-size:.75rem;font-weight:700;color:var(--ink);margin-bottom:4px">${esc(g)}</div>
      <div style="padding-left:8px">${boxes}</div>
    </div>`;
  }).join('');
}

async function grupPadokCheckbox(grup, checkbox){
  const padokId=checkbox.value;
  await rpc('grup_padok_eslem_toggle',{p_grup_adi:grup,p_padok_id:padokId});
  await pullTables(['grup_padok_eslem']);
  await loadPadokConfig();
  toast('Eşleme güncellendi');
}

function ayarlarPadokEkle(){ document.getElementById('ay-padok-form').style.display='block'; }

async function ayarlarPadokKaydet(){
  const ad=v('ay-padok-ad').trim(); if(!ad){ toast('Padok adı boş olamaz',true); return; }
  const kap=parseInt(v('ay-padok-kap'))||null;
  try {
    await rpc('padok_ekle',{p_ad:ad,p_kapasite:kap,p_sira:0});
    await pullTables(['padoklar']);
    await loadPadokConfig();
    cl('ay-padok-ad'); cl('ay-padok-kap');
    document.getElementById('ay-padok-form').style.display='none';
    renderAyarlarPadokList();
    toast('✅ Padok eklendi');
  } catch(e){ toast('Hata: '+e.message,true); return; }
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
  const bugunStr=bugun();
  const yarin=dFwd(bugunStr,1);
  const gorevler=await getData('gorev_log',g=>!g.tamamlandi&&!g.parent_id&&(g.hedef_tarih===bugunStr||g.hedef_tarih===yarin));
  // M-26 fix: localStorage bozuk/eski formatta JSON içerebilir — try/catch yoktu, crash riski.
  let gosterilen; try { gosterilen=JSON.parse(localStorage.getItem('bildirim_gosterilen')||'{}'); } catch(_){ gosterilen={}; }
  const simdi=Date.now();
  for(const g2 of gorevler){
    const hedef=new Date(g2.hedef_tarih+'T08:00:00');
    const fark=(hedef-now)/3600000;
    const key=`${g2.id}_${g2.hedef_tarih}`;
    if(fark>2.5&&fark<=3.5&&!gosterilen[key]){
      const hayvan=getState('animals').find(a=>a.id===g2.hayvan_id);
      const kupe=hayvan?(hayvan.kupe_no||hayvan.devlet_kupe):'Genel';
      new Notification(`⏰ 3 saat sonra: ${kupe}`,{body:g2.aciklama||'',tag:key});
      gosterilen[key]=simdi;
    }
    const sabahKey=`${g2.id}_sabah`;
    if(g2.hedef_tarih===bugunStr&&fark>=-0.5&&fark<=0.5&&!gosterilen[sabahKey]){
      const hayvan=getState('animals').find(a=>a.id===g2.hayvan_id);
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
  if(dlI) dlI.innerHTML=stk.map(s=>`<option value="${s.id}">${esc(s.urun_adi)}</option>`).join('');
}

// ═══ STOK ARAMA ═══
function stokFiltrele(q){
  q = trLower(q||'').trim();
  // Filtre: data-ad attribute ile case-insensitive match
  const rows = document.querySelectorAll('#stok-panel-body .stok-item');
  let visible = 0;
  rows.forEach(row => {
    const ad = trLower(row.dataset.ad || '');
    if (!q || ad.includes(q)) { row.style.display = ''; visible++; }
    else { row.style.display = 'none'; }
  });
  // Grup başlıklarını güncelle
  document.querySelectorAll('#stok-panel-body .stok-group').forEach(grp => {
    const items = grp.querySelectorAll('.stok-item');
    const vis = [...items].filter(r => r.style.display !== 'none').length;
    grp.style.display = q && vis === 0 ? 'none' : '';
  });
  const sonuc = document.getElementById('stok-arama-sonuc');
  if (sonuc) sonuc.textContent = q ? visible+' sonuç' : '';
}

// ═══ GÖREV KÜPE ARAMA ═══
function taskSrch(){
  const q = (document.getElementById('task-srch')?.value||'').toLowerCase().trim();
  const cards = document.querySelectorAll('#tasks-body .task-card');
  let visible = 0;
  cards.forEach(card => {
    const idSpan = card.querySelector('.tc-id');
    const text = (idSpan?.textContent||'').toLowerCase();
    if (!q || text.includes(q)) { card.style.display = ''; visible++; }
    else { card.style.display = 'none'; }
  });
  // Boş sonuç mesajını güncelle
  const body = document.getElementById('tasks-body');
  const emptyMsg = body?.querySelector('.empty:only-child');
  if (emptyMsg && visible === 0) {
    emptyMsg.innerHTML = '<div class="empty-ico">🔍</div>Eşleşen görev bulunamadı';
  }
}

// ══════════════════════════════════════════
// BUG-059 — Saat Bazlı Tedavi Seans UI
// Seans şeridi + satırlar m-case-det gün akordeonu ve
// m-task-det içinde render edilir. Ayrı modal yok.
// ══════════════════════════════════════════

// "08:00" | "08:00:00" (PostgREST time) → "08:00"
function fmtSeansSaat(timeStr) {
  return (timeStr || '').slice(0, 5);
}

// Pure: planned_time → 0-1 arası oran (24h)
function timeToRatio(timeStr) {
  const t = fmtSeansSaat(timeStr);
  if (!/^\d{1,2}:\d{2}$/.test(t)) return 0;
  const [h, m] = t.split(':').map(Number);
  return Math.max(0, Math.min(1, (h * 60 + m) / (24 * 60)));
}

// Pure: seans state hesapla (6 durum)
function computeSeansState(seans, now = new Date()) {
  if (seans.uygulama_tamamlandi_at) return 'done';
  if (seans.uygulanmadi) return 'cancelled';
  const dateStr = seans.planned_date || bugun();
  const timeStr = fmtSeansSaat(seans.planned_time) || '00:00';
  const planned = new Date(`${dateStr}T${timeStr}:00`);
  if (isNaN(planned.getTime())) return 'scheduled';
  const diffMin = (now.getTime() - planned.getTime()) / 60000;
  if (diffMin > 30) return 'overdue';
  if (diffMin > -30) return 'now';
  if (diffMin > -60) return 'due-soon';
  return 'scheduled';
}

// 24 saatlik seans şeridi — gün akordeonunda ve görev detayında
function renderSeansSerit(sessions, opts = {}) {
  const groups = new Map();
  sessions.forEach(s => {
    const k = timeToRatio(s.planned_time).toFixed(3);
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(s);
  });
  const pips = [];
  groups.forEach(arr => {
    arr.forEach((s, idx) => {
      const state = computeSeansState(s);
      const glyph = state === 'done' ? '✓' : state === 'cancelled' ? '✕' : '';
      const tip = `${fmtSeansSaat(s.planned_time)} ${s.drug_name || ''} ${s.dose || ''}${s.unit || ''}`.trim();
      const offX = PIP_STACK_OFFSETS[Math.min(idx, PIP_STACK_OFFSETS.length - 1)];
      pips.push(`<div class="seans-pip s-${state}" style="left:${(timeToRatio(s.planned_time) * 100).toFixed(2)}%;--pip-x:${offX}px" title="${esc(tip)}">${glyph}</div>`);
    });
  });
  const ticks = [25, 50, 75].map(p => `<div class="seans-tick" style="left:${p}%"></div>`).join('');
  const nowLine = opts.today ? '<div class="seans-now-line"></div>' : '';
  return `<div class="seans-strip"${opts.today ? ' data-today="1"' : ''}>
    <div class="seans-strip-labels"><span>00</span><span>06</span><span>12</span><span>18</span><span>24</span></div>
    <div class="seans-track">${ticks}${pips.join('')}${nowLine}</div>
  </div>`;
}

// Şimdi çizgisi — sadece bugünün şeritlerinde, dakikada bir güncellenir
let _nowCursorInterval = null;
function updateNowCursor() {
  const lines = document.querySelectorAll('.seans-strip[data-today] .seans-now-line');
  if (!lines.length) return;
  const now = new Date();
  const pct = ((now.getHours() * 60 + now.getMinutes()) / 1440 * 100).toFixed(2);
  lines.forEach(l => { l.style.left = pct + '%'; });
}
function startNowCursorLoop() {
  if (_nowCursorInterval) clearInterval(_nowCursorInterval);
  updateNowCursor();
  _nowCursorInterval = setInterval(updateNowCursor, 60000);
}

function fmtBeklemeSure(s) {
  const dateStr = s.planned_date || bugun();
  const planned = new Date(`${dateStr}T${fmtSeansSaat(s.planned_time) || '00:00'}:00`);
  if (isNaN(planned.getTime())) return '—';
  const diffMin = Math.round((planned.getTime() - Date.now()) / 60000);
  const abs = Math.abs(diffMin);
  if (abs < 60) return `${abs}dk`;
  const h = Math.floor(abs / 60);
  const m = abs % 60;
  if (h < 24) return `${h}sa ${m}dk`;
  return `${Math.floor(h / 24)}g ${h % 24}sa`;
}

function fmtSaatKisa(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
}

// Tek seans satırı — mevcut cd-drug-row diline uygun
function renderSeansRow(s, opts = {}) {
  const state = computeSeansState(s);
  const cfg = SEANS_STATE[state] || SEANS_STATE.scheduled;
  const durum = {
    scheduled:  `⏳ ${fmtBeklemeSure(s)} sonra`,
    'due-soon': `◐ ${fmtBeklemeSure(s)} sonra`,
    now:        '⏱ Vakti geldi',
    overdue:    `⚠ ${fmtBeklemeSure(s)} gecikti`,
    done:       `✓ Uygulandı${s.uygulama_tamamlandi_at ? ' ' + fmtSaatKisa(s.uygulama_tamamlandi_at) : ''}`,
    cancelled:  '✕ Yapılamadı',
  }[state];
  const kapali = state === 'done' || state === 'cancelled';
  const sag = (kapali || opts.readOnly)
    ? `<span class="seans-chip s-${state}">${kapali ? durum : cfg.etiket}</span>`
    : `<div class="seans-aksiyon">
         <button class="seans-btn-ok" onclick="seansTamamla('${s.id}',false,this)">✓ Uygulandı</button>
         <button class="seans-btn-iptal" onclick="seansTamamla('${s.id}',true,this)" title="Yapılamadı olarak işaretle">✕</button>
       </div>`;
  const meta = [`${s.dose || ''}${s.unit || ''}`, s.route, (!kapali && !opts.readOnly) ? durum : '']
    .filter(Boolean).join(' · ');
  return `<div class="seans-row s-${state}" data-seans-id="${s.id}">
    <span class="seans-saat">${esc(fmtSeansSaat(s.planned_time) || '—')}</span>
    <div class="seans-info">
      <div class="seans-ilac">${esc(s.drug_name || 'İlaç')}</div>
      <div class="seans-meta">${esc(meta)}</div>
    </div>
    ${sag}
  </div>`;
}

// Tedavi günü için seans bölümünü render et (m-task-det içinde)
async function renderTedaviGunSeanslar(treatmentDayId) {
  const all = await idbGetAll('treatment_day_uygulamalar');
  const sessions = all.filter(s => s.treatment_day_id === treatmentDayId);
  const wrap = document.getElementById('td-med-wrap');
  const ribbonEl = document.getElementById('td-med-ribbon');
  const sessionsEl = document.getElementById('td-med-sessions');
  if (!wrap || !ribbonEl || !sessionsEl) return;
  if (!sessions.length) {
    wrap.style.display = 'none';
    return;
  }
  const [allStok, allDays, allProducts] = await Promise.all([idbGetAll('stok').catch(() => []), idbGetAll('treatment_days').catch(() => []), idbGetAll('drug_products').catch(() => [])]);
  const stokMap = Object.fromEntries(allStok.map(x => [x.id, x.urun_adi || x.id]));
  const prodMap = Object.fromEntries(allProducts.map(p => [p.id, p.brand_name || '']));
  const day = allDays.find(d => d.id === treatmentDayId);
  const isLocked = day?.tamamlandi === true;
  sessions.forEach(s => { s.drug_name = prodMap[s.drug_product_id] || stokMap[s.stok_id] || 'İlaç'; s.planned_date = s.planned_date || day?.treatment_date; });
  sessions.sort((a, b) => (a.planned_time || '').localeCompare(b.planned_time || ''));
  const bugunTr = bugun();
  ribbonEl.innerHTML = renderSeansSerit(sessions, { today: sessions.some(s => s.planned_date === bugunTr) });
  sessionsEl.innerHTML = sessions.map(s => renderSeansRow(s, { readOnly: isLocked })).join('');
  wrap.style.display = 'block';
  startNowCursorLoop();
}

// ── Seans planı düzenleyici — gün akordeonu içinde inline form ──
// renderCaseTimeline her render'da _cdDayData'yı doldurur.
let _cdDayData = {};
let _seansAddCtx = null; // { dayId, tarih } — checkbox seans ekleme bağlamı

// Var olan "ilaç ekle" checkbox dilini seansa uyarlar: üstte tek saat seçici,
// altta gruplu checkbox ilaç listesi (cdfChkChange ile ortak doz satırları).
// Mevcut seanslar listelenir; gerçekleşmemiş olanlar 🗑 ile silinebilir (incremental).
async function caseSeansEkleFormAc(dayId) {
  const d = _cdDayData[dayId];
  if (!d || !_curCase) return;
  document.querySelectorAll('.cd-drug-form, .cd-seans-form').forEach(f => f.remove());
  const container = document.getElementById('drugs-' + dayId);
  if (!container) return;
  if (!(_drugsCache && _drugsCache.length)) { try { await loadDrugsCache(); } catch (_) {} }
  _seansAddCtx = { dayId, tarih: d.date };

  // Mevcut seanslar — done/iptal kilitli, gerçekleşmemiş 🗑 silinebilir
  const sessions = (d.sessions || []).slice().sort((a, b) => (a.planned_time || '').localeCompare(b.planned_time || ''));
  const stokMap = Object.fromEntries((getState('stock') || []).map(s => [s.id, s.urun_adi || s.id]));
  const mevcutHtml = sessions.length ? (
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px">Mevcut Seanslar</div>' +
    sessions.map(s => {
      const kapali = s.uygulama_tamamlandi_at || s.uygulanmadi;
      const ad = s.drug_name || stokMap[s.stok_id] || 'İlaç';
      const sag = kapali
        ? `<span class="seans-chip s-${s.uygulama_tamamlandi_at ? 'done' : 'cancelled'}">${s.uygulama_tamamlandi_at ? '✓' : '✕'}</span>`
        : `<span style="display:flex;gap:2px">
             <button onclick="seansDuzenleAc('${s.id}')" style="background:none;border:none;color:var(--blue);font-size:.9rem;cursor:pointer;padding:2px 4px" title="Düzenle (doz/saat/yol)">✏️</button>
             <button onclick="seansSilTekil('${s.id}')" style="background:none;border:none;color:var(--red);font-size:.95rem;cursor:pointer;padding:2px 4px" title="Seansı sil (stok iade)">🗑</button>
           </span>`;
      return `<div id="seans-mevcut-${s.id}" style="display:flex;align-items:center;gap:8px;padding:5px 2px;border-bottom:1px solid var(--card3)">
        <span style="font-weight:700;color:var(--ink2);min-width:42px">${esc(fmtSeansSaat(s.planned_time) || '—')}</span>
        <span style="flex:1;font-size:.8rem;color:var(--ink)">${esc(ad)} <span style="color:var(--ink3);font-size:.72rem">${s.dose || ''}${esc(s.unit || '')}${s.route ? ' · ' + esc(s.route) : ''}</span></span>
        ${sag}
      </div>`;
    }).join('')
  ) : '';

  // Checkbox gruplu ilaç listesi — caseDrugFormAc ile birebir aynı dil
  const cache = _drugsCache || [];
  const groups = {};
  [...cache].sort((a, b) => a.name.localeCompare(b.name, 'tr')).forEach(dr => {
    const g = dr.group_name || 'Diger';
    (groups[g] = groups[g] || []).push(dr);
  });
  const groupHtml = Object.keys(groups).sort((a, b) => a.localeCompare(b, 'tr', { sensitivity: 'base' })).map(grp => {
    const items = groups[grp].map(dr => {
      const stokClrPos = dr.guncel <= 0 ? 'var(--red)' : dr.guncel <= 10 ? 'var(--amber)' : 'var(--green)';
      const stokClr = dr.guncel === null ? 'var(--ink3)' : stokClrPos;
      const stokTxt = dr.guncel !== null ? dr.guncel.toFixed(1) + ' ' + dr.birim : 'stok yok';
      const nm = dr.name.replace(/"/g, '&quot;');
      const rt = (dr.default_route || 'IM').split(' ')[0];
      return '<label style="display:flex;align-items:center;gap:8px;padding:5px 2px;cursor:pointer">' +
        '<input type="checkbox" class="cdf-chk" data-id="' + dr.id + '" data-name="' + nm + '" data-unit="' + (dr.default_unit || dr.birim || 'ml') + '" data-route="' + rt + '" data-legacy="' + (dr._legacy || false) + '"' +
        ' onchange="cdfChkChange(this)" style="width:18px;height:18px;accent-color:var(--green);flex-shrink:0;cursor:pointer">' +
        '<div style="flex:1;min-width:0"><div style="font-size:.82rem;font-weight:600;color:var(--ink)">' + dr.name + '</div>' +
        (dr.active_ingredient ? '<div style="font-size:.65rem;color:var(--ink3)">' + dr.active_ingredient + '</div>' : '') +
        '</div><span style="font-size:.72rem;font-weight:700;color:' + stokClr + ';flex-shrink:0">' + stokTxt + '</span></label>';
    }).join('');
    return '<div style="margin-bottom:8px"><div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:4px;padding:3px 0;border-bottom:1px solid var(--card3)">' + grp + '</div>' + items + '</div>';
  }).join('');

  const saatChips = HIZLI_SAATLER.map(h => `<button type="button" class="ek-chip" onclick="seansAddSaatSec('${h}',this)">${h}</button>`).join('');

  const form = document.createElement('div');
  form.className = 'cd-seans-form';
  form.style.cssText = 'margin-top:8px;background:var(--card2);border-radius:10px;padding:10px';
  form.innerHTML =
    '<div style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:8px">⏰ Seans Planı</div>' +
    mevcutHtml +
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin:8px 0 6px">＋ Yeni Seans — Saat</div>' +
    '<div style="display:flex;gap:5px;align-items:center;flex-wrap:wrap;margin-bottom:8px">' +
    `<input id="seans-add-time" class="fi" type="time" value="${HIZLI_SAATLER[0]}" style="margin:0;flex:1;min-width:90px">` +
    saatChips + '</div>' +
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">İlaç Seç (çoklu — bu saatte uygulanacak)</div>' +
    '<div style="max-height:200px;overflow-y:auto;background:var(--card);border-radius:8px;padding:8px;margin-bottom:8px;border:1px solid var(--card3)">' +
    (groupHtml || '<div style="color:var(--ink3);font-size:.78rem;padding:8px">Stokta ilaç yok</div>') + '</div>' +
    '<div id="cdf-doz-alani" style="display:none">' +
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Seçili İlaçlar — Doz Gir</div>' +
    '<div id="cdf-doz-satirlar"></div></div>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px">' +
    '<button onclick="caseSeansEkleKaydet(this)" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:9px;font-weight:700;cursor:pointer">＋ Seansı Ekle</button>' +
    '<button onclick="this.closest(\'.cd-seans-form\').remove()" style="background:var(--card3);border:none;border-radius:7px;padding:9px;cursor:pointer">Kapat</button>' +
    '</div>';
  container.appendChild(form);
}

function seansAddSaatSec(h, btn) {
  const inp = document.getElementById('seans-add-time');
  if (inp) inp.value = h;
  btn?.parentElement?.querySelectorAll('.ek-chip').forEach(c => c.classList.remove('aktif'));
  btn?.classList.add('aktif');
}

async function seansSilTekil(seansId) {
  const dayId = _seansAddCtx?.dayId;
  openConfirm('Seansı Sil', 'Bu seans silinecek ve ilacı stoğa iade edilecek. Emin misiniz?', async () => {
    try {
      const res = await rpc('remove_treatment_session', { p_seans_id: seansId });
      if (res?.ok === false) throw new Error(res.mesaj || 'Hata');
      toast('✅ Seans silindi, stok iade edildi');
      await pullTables(['treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log']);
      if (_curCase) {
        await _keepScroll(document.getElementById('cd-timeline'), async () => {
          await renderCaseTimeline(_curCase.id);
          if (dayId) await caseSeansEkleFormAc(dayId); // editör açık kalsın, kullanıcı devam etsin
        });
        _updateKapatBtn(_curCase.id);
      }
    } catch (e) {
      toast('❌ ' + (e.message || 'Hata'), true);
    }
  });
}

// Mevcut not-done seansı yerinde düzenle: satırı inline form'a çevirir
function seansDuzenleAc(seansId) {
  const d = _seansAddCtx && _cdDayData[_seansAddCtx.dayId];
  const s = (d?.sessions || []).find(x => x.id === seansId);
  const row = document.getElementById('seans-mevcut-' + seansId);
  if (!s || !row) return;
  const yolOpts = ['IM', 'IV', 'SC', 'PO', 'Topikal', 'Intrauterin']
    .map(y => `<option value="${y}"${(s.route || '') === y ? ' selected' : ''}>${y}</option>`).join('');
  row.innerHTML = `
    <div style="display:flex;gap:5px;align-items:center;flex-wrap:wrap;width:100%">
      <input id="sd-time-${seansId}" class="fi" type="time" value="${esc(fmtSeansSaat(s.planned_time) || '08:00')}" style="margin:0;width:88px">
      <input id="sd-dose-${seansId}" class="fi" type="number" min="0.01" step="0.01" value="${s.dose ?? ''}" placeholder="Doz" style="margin:0;width:64px">
      <input id="sd-unit-${seansId}" class="fi" type="text" value="${esc(s.unit || 'ml')}" placeholder="Birim" style="margin:0;width:52px">
      <select id="sd-route-${seansId}" class="fsel" style="margin:0;flex:1;min-width:64px">${yolOpts}</select>
      <button onclick="seansDuzenleKaydet('${seansId}',this)" style="background:var(--green);color:#fff;border:none;border-radius:6px;padding:6px 10px;font-weight:700;cursor:pointer" title="Kaydet">✓</button>
      <button onclick="caseSeansEkleFormAc('${_seansAddCtx.dayId}')" style="background:var(--card3);border:none;border-radius:6px;padding:6px 9px;cursor:pointer" title="İptal">✕</button>
    </div>`;
}

async function seansDuzenleKaydet(seansId, btn) {
  const time = document.getElementById('sd-time-' + seansId)?.value;
  const dose = Number.parseFloat(document.getElementById('sd-dose-' + seansId)?.value);
  const unit = (document.getElementById('sd-unit-' + seansId)?.value || '').trim();
  const route = document.getElementById('sd-route-' + seansId)?.value || null;
  if (!time) { toast('Saat girin', true); return; }
  if (!dose || dose <= 0) { toast('Geçerli doz girin', true); return; }
  if (!unit) { toast('Birim girin', true); return; }
  const dayId = _seansAddCtx?.dayId;
  if (btn) { btn.disabled = true; btn.textContent = '…'; }
  try {
    const res = await rpc('update_treatment_session', {
      p_seans_id: seansId, p_dose: dose, p_unit: unit,
      p_route: (route || '').split(' ')[0] || null, p_planned_time: time,
    });
    if (res?.ok === false) throw new Error(res.mesaj || 'Hata');
    toast('✅ Seans güncellendi');
    await pullTables(['treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log']);
    if (_curCase) {
      await _keepScroll(document.getElementById('cd-timeline'), async () => {
        await renderCaseTimeline(_curCase.id);
        if (dayId) await caseSeansEkleFormAc(dayId); // editör açık kalsın, kullanıcı devam etsin
      });
      _updateKapatBtn(_curCase.id);
    }
  } catch (e) {
    toast('❌ ' + (e.message || 'Hata'), true);
    if (btn) { btn.disabled = false; btn.textContent = '✓'; }
  }
}

async function caseSeansEkleKaydet(btn) {
  if (!_seansAddCtx || !_curCase) return;
  const time = document.getElementById('seans-add-time')?.value;
  if (!time) { toast('Saat seçin', true); return; }
  const sessions = [];
  let hata = false;
  document.querySelectorAll('.cdf-chk:checked').forEach(chk => {
    if (hata) return;
    const id = chk.dataset.id;
    const dose = Number.parseFloat(document.querySelector('.cdf-dose-inp[data-drug-id="' + id + '"]')?.value);
    const unit = (document.querySelector('.cdf-unit-inp[data-drug-id="' + id + '"]')?.value || '').trim();
    const route = document.querySelector('.cdf-route-inp[data-drug-id="' + id + '"]')?.value || null;
    if (!dose || dose <= 0) { toast(chk.dataset.name + ': geçerli doz girin', true); hata = true; return; }
    if (!unit) { toast(chk.dataset.name + ': birim girin', true); hata = true; return; }
    const dr = (_drugsCache || []).find(x => x.id === id);
    sessions.push({
      planned_time: time,
      stok_id: dr?.stock_id || null,
      drug_product_id: dr?._legacy ? null : id,
      dose, unit,
      route: (route || '').split(' ')[0] || null,
    });
  });
  if (hata) return;
  if (!sessions.length) { toast('İlaç seçin', true); return; }
  const dayId = _seansAddCtx.dayId;
  btn.disabled = true; btn.textContent = 'Ekleniyor…';
  try {
    const res = await rpc('add_sessions_to_existing_day', { p_day_id: dayId, p_sessions: sessions });
    if (res?.ok === false) throw new Error(res.mesaj || 'Hata');
    toast(`✅ ${sessions.length} seans eklendi (${time})`);
    _seansAddCtx = null;
    await pullTables(['treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log']);
    await _keepScroll(document.getElementById('cd-timeline'), async () => {
      await renderCaseTimeline(_curCase.id);
      await caseSeansEkleFormAc(dayId); // editör açık kalsın, başka seans/ilaç eklenebilsin
    });
    _updateKapatBtn(_curCase.id);
  } catch (e) {
    toast('❌ ' + (e.message || 'Hata'), true);
    btn.disabled = false; btn.textContent = '＋ Seansı Ekle';
  }
}

// ── Erken kapat (stok iade) — m-case-det içinde inline onay bölümü ──
async function caseErkenKapatToggle() {
  const form = document.getElementById('cd-erken-kapat-form');
  const btn = document.getElementById('cd-erken-kapat-btn');
  if (!form) return;
  const acik = form.style.display !== 'none';
  if (acik) {
    form.style.display = 'none';
    if (btn) btn.style.display = 'block';
    return;
  }
  if (!_curCase) return;
  const [allDays, allApps, allStok, allProducts] = await Promise.all([
    idbGetAll('treatment_days'),
    idbGetAll('treatment_day_uygulamalar').catch(() => []),
    idbGetAll('stok').catch(() => []),
    idbGetAll('drug_products').catch(() => []),
  ]);
  const stokMap = Object.fromEntries(allStok.map(s => [s.id, s.urun_adi || s.id]));
  const prodMap = Object.fromEntries(allProducts.map(p => [p.id, p.brand_name || '']));
  const acikGunler = allDays.filter(d => d.case_id === _curCase.id && !d.tamamlandi);
  const dayIds = new Set(acikGunler.map(d => d.id));
  const kalan = allApps.filter(s => dayIds.has(s.treatment_day_id) && !s.uygulama_tamamlandi_at && !s.uygulanmadi);
  const ozetEl = document.getElementById('cd-erken-ozet');
  if (ozetEl) {
    ozetEl.innerHTML = kalan.length
      ? `<b style="color:var(--red)">⚠ ${kalan.length} seans henüz uygulanmadı:</b><br>` +
        kalan.map(s => `• ${esc(fmtTarih(s.planned_date) || '')} ${esc(fmtSeansSaat(s.planned_time))} — ${esc(prodMap[s.drug_product_id] || stokMap[s.stok_id] || '')} ${s.dose || ''}${s.unit || ''}`).join('<br>')
      : `<b style="color:var(--red)">⚠ ${acikGunler.length} tedavi günü hâlâ açık.</b> Açık günler kapatılacak.`;
  }
  const notEl = document.getElementById('cd-erken-not');
  if (notEl) notEl.value = '';
  form.style.display = 'block';
  if (btn) btn.style.display = 'none';
}

function caseErkenKapatOnayla(btn) {
  if (!_curCase) return;
  const not = document.getElementById('cd-erken-not')?.value?.trim() || null;
  openConfirm('Vakayı Erken Kapat', 'Kalan seanslar iptal edilecek ve ilaçlar stoğa iade edilecek. Emin misiniz?', async () => {
    if (btn) { btn.disabled = true; btn.textContent = 'Kapatılıyor…'; }
    try {
      const res = await rpcCloseCaseWithRemaining(_curCase.id, not);
      if (res?.ok === false) throw new Error(res.mesaj || 'Hata');
      toast('✅ Vaka kapatıldı, kalan ilaçlar stoğa iade edildi');
      closeM('m-case-det');
      await pullTables(['cases', 'treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'gorev_log']);
      loadDash();
    } catch (e) {
      toast('❌ ' + (e.message || 'Hata'), true);
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = '⏹ Kapat ve Stok İade Et'; }
    }
  });
}

// ══════════════════════════════════════════════════════════════
// AŞI EKLE/DÜZENLE — içerik-odaklı (hastalık arama+checkbox + protokol)
// ══════════════════════════════════════════════════════════════
let _asiEdit = null;
let _asiDisSearch = '';

async function openAsiEkle(vaccineId){
  const diseases = await getData('diseases') || [];
  if(vaccineId){
    const vaccines = await getData('vaccines') || [];
    const v = vaccines.find(x=>x.id===vaccineId);
    if(!v){ toast('Aşı bulunamadı',true); return; }
    const steps = (await getData('vaccine_protocol_steps')||[]).filter(s=>s.vaccine_id===vaccineId).sort((a,b)=>a.adim_no-b.adim_no);
    const vd    = (await getData('vaccine_diseases')||[]).filter(x=>x.vaccine_id===vaccineId);
    _asiEdit = {
      id:v.id, name:v.name||'', marka:v.marka||'', etken_madde:v.etken_madde||'',
      dose:v.dose||'', unit:v.unit||'ml', route:v.route||'SC',
      is_mandatory:!!v.is_mandatory, repeat:v.repeat_interval_days||'',
      protokol_tipi:v.protokol_tipi||'tek_doz',
      ikinci_doz_gun:(steps.find(s=>s.adim_no===2)?.offset_gun)||28,
      disease_ids:vd.map(x=>x.disease_id), baslangic_stok:'', esik:'',
      _hasStock:!!v.stock_item_id
    };
  } else {
    _asiEdit = { id:null, name:'', marka:'', etken_madde:'', dose:'', unit:'ml', route:'SC',
      is_mandatory:false, repeat:'', protokol_tipi:'tek_doz', ikinci_doz_gun:28,
      disease_ids:[], baslangic_stok:'', esik:'', _hasStock:false };
  }
  _asiEdit._diseases = diseases;
  _asiDisSearch = '';
  document.getElementById('m-asi-title').textContent = vaccineId ? 'Aşıyı Düzenle' : 'Yeni Aşı';
  _renderAsiForm();
  openM('m-asi-ekle');
}

function _renderAsiDiseasePicker(){
  const s = _asiEdit;
  const q = trLower(_asiDisSearch||'');
  const list = s._diseases.filter(d=> !q || trLower(d.name||'').includes(q));
  const byCat = {};
  list.slice().sort((a,b)=>(a.name||'').localeCompare(b.name||'','tr')).forEach(d=>{
    const c = d.category || 'Diğer'; (byCat[c]=byCat[c]||[]).push(d);
  });
  const inner = Object.keys(byCat).sort((a,b)=>a.localeCompare(b,'tr',{sensitivity:'base'})).map(cat=>{
    const items = byCat[cat].map(d=>`<label style="display:flex;align-items:center;gap:8px;padding:4px 2px;cursor:pointer">
      <input type="checkbox" ${s.disease_ids.includes(d.id)?'checked':''} onchange="asiDisToggle('${d.id}',this.checked)" style="width:17px;height:17px;accent-color:var(--green);flex-shrink:0">
      <span style="font-size:.82rem">${esc(d.name)}</span></label>`).join('');
    return `<div style="margin-bottom:6px"><div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;border-bottom:1px solid var(--card3);padding-bottom:2px;margin-bottom:3px">${esc(cat)}</div>${items}</div>`;
  }).join('') || '<div style="color:var(--ink3);font-size:.78rem">Hastalık bulunamadı</div>';
  return inner;
}

function _renderAsiForm(){
  const s = _asiEdit;
  const sec = s.disease_ids.length;
  const isPrimer = s.protokol_tipi==='primer_seri';
  document.getElementById('m-asi-body').innerHTML = `
    <div class="fg"><label class="flbl">Preparat adı (ürün) *</label>
      <input id="asi-name" class="fi" value="${esc(s.name)}" placeholder="Örn. Coglavax"></div>
    <div class="fg"><label class="flbl">Marka (firma)</label>
      <input id="asi-marka" class="fi" value="${esc(s.marka)}" placeholder="Örn. Ceva"></div>
    <div class="fg"><label class="flbl">Etken madde</label>
      <input id="asi-etken" class="fi" value="${esc(s.etken_madde)}" placeholder="opsiyonel"></div>
    <div style="display:flex;gap:8px">
      <div class="fg" style="flex:1"><label class="flbl">Doz</label>
        <input id="asi-dose" class="fi" type="number" step="0.1" value="${esc(String(s.dose))}" placeholder="2"></div>
      <div class="fg" style="flex:1"><label class="flbl">Birim</label>
        <input id="asi-unit" class="fi" value="${esc(s.unit)}" placeholder="ml"></div>
      <div class="fg" style="flex:1"><label class="flbl">Yol</label>
        <select id="asi-route" class="fi">
          ${['SC','IM','PO','IV'].map(r=>`<option value="${r}" ${s.route===r?'selected':''}>${r}</option>`).join('')}
        </select></div>
    </div>
    <label style="display:flex;align-items:center;gap:8px;margin:4px 0;cursor:pointer">
      <input type="checkbox" id="asi-mand" ${s.is_mandatory?'checked':''} style="width:17px;height:17px;accent-color:var(--red)">
      <span style="font-size:.85rem">Zorunlu aşı</span></label>
    <div class="fg"><label class="flbl">Hastalıklar ${sec?`<span style="color:var(--green)">(${sec} seçili)</span>`:''}</label>
      <input id="asi-dis-search" class="fi" placeholder="🔍 Hastalık ara…" value="${esc(_asiDisSearch)}" oninput="asiDisSearchInput(this.value)" style="margin-bottom:6px">
      <div id="asi-dis-list" style="max-height:160px;overflow-y:auto;background:var(--card);border:1px solid var(--card3);border-radius:8px;padding:8px">${_renderAsiDiseasePicker()}</div></div>
    <div class="fg"><label class="flbl">Brand protokolü</label>
      <div style="display:flex;gap:14px">
        <label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="radio" name="asi-prot" value="tek_doz" ${!isPrimer?'checked':''} onchange="asiProtToggle(this.value)"> Tek doz</label>
        <label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="radio" name="asi-prot" value="primer_seri" ${isPrimer?'checked':''} onchange="asiProtToggle(this.value)"> Primer seri</label>
      </div>
      <div id="asi-primer-box" style="display:${isPrimer?'block':'none'};margin-top:6px;font-size:.82rem">
        2. doz aralığı: <input id="asi-ikinci-gun" type="number" value="${esc(String(s.ikinci_doz_gun))}" style="width:64px;padding:4px 6px;border:1px solid var(--card3);border-radius:6px"> gün
      </div></div>
    <div class="fg"><label class="flbl">Yıllık tekrar (gün, ops.)</label>
      <input id="asi-repeat" class="fi" type="number" value="${esc(String(s.repeat))}" placeholder="365"></div>
    ${(!s.id || !s._hasStock) ? `<div style="display:flex;gap:8px">
      <div class="fg" style="flex:1"><label class="flbl">${s.id?'Stok ekle (ops.)':'Başlangıç stok (ops.)'}</label>
        <input id="asi-stok" class="fi" type="number" step="0.1" value="${esc(String(s.baslangic_stok))}" placeholder="boş=stoksuz"></div>
      <div class="fg" style="flex:1"><label class="flbl">Eşik (ops.)</label>
        <input id="asi-esik" class="fi" type="number" step="0.1" value="${esc(String(s.esik))}" placeholder="0"></div>
    </div>` : ''}
    <button class="btn btn-g" onclick="submitAsiEkle(this)" style="margin-top:12px">💾 Kaydet</button>`;
}

function asiDisToggle(did, checked){
  if(checked){ if(!_asiEdit.disease_ids.includes(did)) _asiEdit.disease_ids.push(did); }
  else { _asiEdit.disease_ids = _asiEdit.disease_ids.filter(x=>x!==did); }
}
function asiProtToggle(val){ _syncAsiForm(); _asiEdit.protokol_tipi = val; _renderAsiForm(); }
function asiDisSearchInput(val){ _asiDisSearch = val; _syncAsiForm(); document.getElementById('asi-dis-list').innerHTML = _renderAsiDiseasePicker(); }

function _syncAsiForm(){
  const g2 = id => document.getElementById(id);
  if(!g2('asi-name')) return;
  const s=_asiEdit;
  s.name=g2('asi-name').value; s.marka=g2('asi-marka').value; s.etken_madde=g2('asi-etken').value;
  s.dose=g2('asi-dose').value; s.unit=g2('asi-unit').value; s.route=g2('asi-route').value;
  s.is_mandatory=g2('asi-mand').checked; s.repeat=g2('asi-repeat').value;
  if(g2('asi-ikinci-gun')) s.ikinci_doz_gun=g2('asi-ikinci-gun').value;
  if(g2('asi-stok')){ s.baslangic_stok=g2('asi-stok').value; s.esik=g2('asi-esik').value; }
}
