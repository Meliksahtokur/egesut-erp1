// ═══════════════════════════════════════════════════════
// ui.js — EgeSüt render & UI fonksiyonları
// ═══════════════════════════════════════════════════════

/* global
  /* global
   _curTaskFilter, _curUremeTab, _curGecmisFilter, _gecmisTumu, _tanimlarTab,
   _curTaskDet, _curTaskVaccineId, _curToh,
   _customHekimler, _customSperma,
   _ilacCache, _drugsCache, _disFreq,
   HEKIMLER, VARSAYILAN_HEKIM,
   HASTALIK_LISTESI, HASTALIK_KAT, LOKASYON_KAT, SEMPTOM_KAT, SEMPTOM_GENEL,
   SPERMA_LISTESI, GRUP_PADOK, PADOKLAR,
   getState, setState,
   g, v, cl, dAgo, dFwd, fmtTarih, toast, openM, closeM, mClose,
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
  asi:['ILERI_GEBE_ASI','ASI_HATIRLATMA','ASI_RAPEL'],
  vitamin:['ILERI_GEBE'],
  muayene:['MUAYENE'],
  tedavi:['TEDAVI','ILAC_UYGULAMA','TEDAVI_GUN'],
  bakim:['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP','BESLEME'],
  diger:null // özel mantık: _katTipMap'te olmayan tüm tipler
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
function _dashStatRow(animals,gebeTohs,diseases,tasks,badge){
  const _taskCls=tasks.length>0?'warn':'ok';
  const sutBuzagiSayisi=animals.filter(a=>a.grup&&a.grup.includes('Süt İçen Buzağı')&&a.dogum_tarihi&&Math.floor((Date.now()-new Date(a.dogum_tarihi))/86400000)>=60).length;
  return `<div class="dash-row">
    <div class="sc ok" onclick="goTo('suru')"><div class="sv">${animals.length}</div><div class="sl">Aktif Hayvan ›</div></div>
    <div class="sc ok" onclick="showGebe()"><div class="sv">${gebeTohs.length}</div><div class="sl">Gebe ›</div></div>
    <div class="sc ${diseases.length>0?'alert':'ok'}" onclick="goTo('gecmis');loadGecmis('hastalik')"><div class="sv">${diseases.length}</div><div class="sl">Aktif Hastalık ›</div></div>
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
  const more=total-5;

  return band(priority,`💉 Yaklaşan Aşılar (${total})`,
    display.map(v=>`<div class="arow" style="display:flex;align-items:center;gap:6px">
      <div style="flex:1;cursor:pointer" onclick="openDet('${v.animal_id}')">
        <div class="arow-left">
          <div class="arow-main">${v.vaxName}</div>
          <div class="arow-sub">${v.days<0?'⚠️ '+Math.abs(v.days)+' gün gecikti':'⏰ '+v.days+' gün kaldı'}</div>
        </div>
        <div class="arow-right">${fmtTarih(v.next_due_date)}</div>
      </div>
      <button style="font-size:.7rem;font-weight:700;color:var(--ink3);background:var(--card2);border:1px solid var(--card3);border-radius:6px;padding:2px 7px;cursor:pointer;white-space:nowrap;flex-shrink:0"
        onclick="event.stopPropagation();asiDismiss('${v.id}','${v.vaxName}')">✕</button>
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
function _dashBands(negStk,late,todayT,births60,nearBirth,critStk,stock,muayeneGerekli,ileriGebeler,aMap,yakAsi,yakTakviye,ddMap){
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
      births60.map(b=>`<div class="arow" style="display:flex;align-items:center;gap:6px"><div style="flex:1;cursor:pointer" onclick="openDet('${b.anne_id}')"><div class="arow-left"><div class="arow-id">${b.anne_id}</div><div class="arow-sub">${b.tarih} — ${Math.floor((Date.now()-new Date(b.tarih))/86400000)}. gün</div></div></div><button style="font-size:.65rem;font-weight:700;color:var(--red2);background:rgba(192,50,26,.1);border:1px solid rgba(192,50,26,.3);border-radius:6px;padding:2px 7px;cursor:pointer;white-space:nowrap" onclick="event.stopPropagation();kizginlikYoktu('${b.anne_id}','${b.id||''}')">✕</button></div>`).join(''));
  }
  if((muayeneGerekli||[]).length){
    h+=band('red','🚨 Muayene Gerekli (90+ gün, kayıt yok)',
      muayeneGerekli.map(b=>`<div class="arow" onclick="openDet('${b.anne_id}')"><div class="arow-left"><div class="arow-id">${b.anne_id}</div><div class="arow-sub">${Math.floor((Date.now()-new Date(b.tarih))/86400000)}. gün — kızgınlık/tohumlama kaydı yok</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`).join(''));
  }
  if((ileriGebeler||[]).length){
    const kontrolBtn=`<button onclick="ileriGebeKontrol()" style="font-size:.65rem;font-weight:700;padding:3px 9px;border-radius:6px;border:1px solid var(--amber);background:rgba(255,160,0,.12);color:var(--amber);cursor:pointer;white-space:nowrap;margin-left:auto">🔔 Görev Kontrol</button>`;
    const title=`<span style="display:flex;align-items:center;gap:8px;width:100%">🤰 İleri Gebeler (210+ gün) ${kontrolBtn}</span>`;
    h+=band('amber',title,
      (ileriGebeler||[]).map(b=>{
        const kid=b.kupe_no||b.devlet_kupe||b.hayvan_id;
        const besUyari=b.gebelik_gun>=260?`<span style="background:rgba(176,120,0,.15);color:#b07800;border-radius:4px;padding:1px 5px;font-weight:700;font-size:.65rem;margin-left:4px">⚠️ Anyonik</span>`:'';
        return `<div class="arow" onclick="openDet('${b.hayvan_id}')"><div class="arow-left"><div class="arow-id">${kid}${besUyari}</div><div class="arow-sub">${b.gebelik_gun}. gün · ${b.grup||''}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
      }).join(''));
  }
  if(nearBirth.length){
    const nearSorted=[...nearBirth].sort((a,b)=>new Date(a.tarih)-new Date(b.tarih));
    h+=band('blue','🤰 Yaklaşan Doğumlar (≤7 gün)',
      nearSorted.map(b=>{
        const a=aMap&&aMap[b.hayvan_id];
        const kid=a?.kupe_no||a?.devlet_kupe||b.hayvan_id;
        const gun=Math.floor((Date.now()-new Date(b.tarih))/86400000);
        return `<div class="arow" onclick="openDet('${b.hayvan_id}')"><div class="arow-left"><div class="arow-id">${kid}</div><div class="arow-sub">${gun}. gün · ${Math.floor((new Date(b.tarih).getTime()+280*86400000-Date.now())/86400000)} gün kaldı</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
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
    const today=new Date().toISOString().split('T')[0];
    const [animals,diseases,tasks,stock,births60,births90,gebeTohs,vaxLogs,vaccines,allKizginlik,allTohum]=await Promise.all([
      getData('hayvanlar',a=>a.durum==='Aktif'),
      getData('cases',c=>c.status==='active'),
      getData('gorev_log',t=>!t.tamamlandi&&!t.iptal),
      idbGetAll('stok'),
      getData('dogum',b=>b.tarih>=dAgo(63)&&b.tarih<=dAgo(58)),
      getData('dogum',b=>b.tarih>=dAgo(150)&&b.tarih<dAgo(89)),
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
    const d7str=new Date(Date.now()+7*86400000).toISOString().split('T')[0];
    const d1str=new Date(Date.now()+86400000).toISOString().split('T')[0];
    const yakAsi=tasks.filter(t=>t.gorev_tipi==='ILERI_GEBE_ASI'&&_isTop(t)&&t.hedef_tarih>today&&t.hedef_tarih<=d7str);
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
    // 90-day: births 90-150 days ago with no kizginlik/tohumlama since
    const gebeSet90=new Set(getState('gebeIds')||[]);
    const muayeneGerekli=births90.filter(b=>{
      if(gebeSet90.has(b.anne_id)) return false; // zaten tekrar gebe
      const hasK=allKizginlik.some(k=>k.hayvan_id===b.anne_id&&k.tarih>=b.tarih);
      const hasT=allTohum.some(t=>t.hayvan_id===b.anne_id&&t.tarih>=b.tarih);
      return !hasK&&!hasT;
    });
    // Buzağı sütten kesme otomatik kontrolü
    try {
      const resBuz=await rpc('buzagi_sutten_kesme_kontrol');
      if(resBuz&&resBuz.ok&&resBuz.olusturulan>0) toast('🍼 '+resBuz.olusturulan+' buzağı sütten kesme görevi oluşturuldu');
    } catch(e){ /* sessiz */ }

    // TEDAVI_GUN teşhis haritası (dashboard kartları için)
    const _dtDays=await idbGetAll('treatment_days').catch(()=>[]);
    const _dtDiseases=await idbGetAll('diseases').catch(()=>[]);
    const _dtDById=Object.fromEntries(_dtDiseases.map(d=>[d.id,d.name||'']));
    const _dtCases=await idbGetAll('cases').catch(()=>[]);
    const _dtCById=Object.fromEntries(_dtCases.map(c=>[c.id,c]));
    const _ddMap={};
    _dtDays.forEach(td=>{const c=_dtCById[td.case_id];if(c?.disease_id)_ddMap[td.id]=_dtDById[c.disease_id]||'';});

    const h=_dashStatRow(animals,gebeTohs,diseases,tasks,badge)+_dashBands(negStk,late,todayT,births60F,nearBirth,critStk,stock,muayeneGerekli,ileriGebeler,aMap,yakAsi,yakTakviye,_ddMap)+_dashVacAlerts(today,vaxLogs,vaccines);
    el.innerHTML=h||'<div class="empty"><div class="empty-ico">✅</div>Her şey yolunda</div>';
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
    if (!res?.ok) throw new Error(res?.hata || 'Silme başarısız');
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
    const { data } = await db.from('cozulmemis_kizginlik_view')
      .select('hayvan_id,durum')
      .neq('durum', 'cozuldu');
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
  const gebeTohs=await getData('tohumlama',t=>t.sonuc==='Gebe');
  const gebeIds=new Set(gebeTohs.map(t=>t.hayvan_id));
  renderAnimals(getState('animals').filter(a=>gebeIds.has(a.id)||gebeIds.has(a.kupe_no)));
}

// ──────────────────────────────────────────
// GÖREVLER
// ──────────────────────────────────────────
async function loadTasks(f,btn){
  _curTaskFilter=f;
  if(btn){ document.querySelectorAll('.fs-btn').forEach(b=>b.classList.remove('on')); btn.classList.add('on'); }
  const el=document.getElementById('tasks-body');
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  const srchEl=document.getElementById('task-srch');
  if(srchEl){ srchEl.value=''; }
  try {
    const today=new Date().toISOString().split('T')[0];
    if(navigator.onLine) await pullTables(['gorev_log','treatment_days','cases','diseases']).catch(()=>{});
    const all=await idbGetAll('gorev_log');
    if(f==='done'){
      let done=all.filter(t=>t.tamamlandi&&!t.iptal&&!t.parent_id);
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
          <div class="tc-meta" style="color:var(--green)">✅ ${fmtTarih(t.tamamlanma_tarihi||t.hedef_tarih)}</div>
          ${rapelStr}
        </div></div>
      </div>`;
      }).join('');
      return;
    }
    // parent_id olan ama parent'ı tamamlanmış görevler top-level sayılır
    const _doneIds=new Set(all.filter(t=>t.tamamlandi).map(t=>t.id));
    let data=all.filter(t=>!t.tamamlandi&&!t.iptal&&(!t.parent_id||_doneIds.has(t.parent_id)));
    const _d7=new Date(Date.now()+7*86400000).toISOString().split('T')[0];
    if(f==='today') data=data.filter(t=>t.hedef_tarih<=today||(t.gorev_tipi==='ILERI_GEBE_ASI'&&t.hedef_tarih<=_d7));
    else if(f==='late') data=data.filter(t=>t.hedef_tarih<today);
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
    const _dayDrugMap={};
    _allDrugAdmins.forEach(da=>{
      if(!_dayDrugMap[da.treatment_day_id])_dayDrugMap[da.treatment_day_id]=[];
      _dayDrugMap[da.treatment_day_id].push({name:_stokNameMap[da.stok_id]||'İlaç',dose:da.dose,unit:da.unit,route:da.route});
    });
    // TEDAVI_GUN için teshis adı: treatment_days → cases → diseases
    const _allTDays=await idbGetAll('treatment_days').catch(()=>[]);
    const _allTaskCases=await idbGetAll('cases').catch(()=>[]);
    const _allTaskDiseases=await idbGetAll('diseases').catch(()=>[]);
    const _caseById=Object.fromEntries(_allTaskCases.map(c=>[c.id,c]));
    const _diseaseById=Object.fromEntries(_allTaskDiseases.map(d=>[d.id,d.name||'']));
    const _dayDiseaseMap={};
    _allTDays.forEach(td=>{ const c=_caseById[td.case_id]; if(c?.disease_id)_dayDiseaseMap[td.id]=_diseaseById[c.disease_id]||''; });
    el.innerHTML=data.slice(0,150).map(t=>{
      const _diff=Math.floor((new Date(t.hedef_tarih)-Date.now())/86400000);
      const _clsBase=_diff<=3?'near':'';
      const _clsMid=t.hedef_tarih===today?'soon':_clsBase;
      const cls=t.hedef_tarih<today?'late':_clsMid;
      const _tDrugs=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return _dayDrugMap[JSON.parse(t.aciklama||'{}').day_id]||[];}catch(e){return [];}})():[];
      const _tDisease=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return _dayDiseaseMap[JSON.parse(t.aciklama||'{}').day_id]||'';}catch(e){return '';}})():'';
      return renderTask(t,cls,allSubs.filter(s=>s.parent_id===t.id),_tDrugs,_tDisease);
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}
function renderTask(t,cls='',subs=[],drugs=[],diseaseName=''){
  const planTime=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').planned_time||'';}catch(e){return '';}})():'';
  const doneSubs=subs.filter(s=>s.tamamlandi).length;
  const allDone=subs.length>0&&doneSubs===subs.length;
  const subHtml=subs.length?`<div class="subtasks">
    ${subs.map(s=>`<div class="st-row">
      <div class="st-check ${s.tamamlandi?'done':''}" onclick="toggleSub('${s.id}','${t.id}',this)">
        ${s.tamamlandi?`<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>`:''}
      </div>
      <span class="st-label ${s.tamamlandi?'done':''}">${esc(s.aciklama)}</span>
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
          <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi==='ASI_HATIRLATMA'||t.gorev_tipi==='ASI_RAPEL')?'💉 ':''}${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
          ${diseaseName?`<span class="pill" style="background:rgba(192,50,26,.1);color:var(--red);border:1px solid rgba(192,50,26,.2)">🏥 ${esc(diseaseName)}</span>`:''}
        </div>
        <div class="tc-desc">${esc(t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').label||t.aciklama;}catch(e){return t.aciklama;}})():t.aciklama||'')}</div>
        <div class="tc-meta"><span>${fmtTarih(t.hedef_tarih)}${planTime?` <span style="color:var(--blue);font-size:.65rem">🕐 ${planTime}</span>`:''}</span>${t.stok_id?`<span>💊 ${t.stok_id}</span>`:''}</div>
      </div>
      ${subs.length===0&&t.gorev_tipi==='BESLEME'?`<button class="ck-btn" onclick="event.stopPropagation();beslemeGunTamam('${t.id}',this)">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
      </button>`:''}
      ${subs.length===0&&t.gorev_tipi!=='ILERI_GEBE_ASI'&&t.gorev_tipi!=='BESLEME'&&t.gorev_tipi!=='TEDAVI_GUN'?`<button class="ck-btn" onclick="event.stopPropagation();doneTask('${t.id}','${t.hayvan_id||''}','${t.stok_id||''}',${+t.miktar||0},'${t.padok_hedef||''}',this)">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
      </button>`:''}
    </div>
    ${drugHtml}${subHtml}
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
function openConfirm(title, desc, onConfirm){
  document.getElementById('m-confirm-title').textContent=title;
  document.getElementById('m-confirm-desc').textContent=desc;
  const ok=document.getElementById('m-confirm-ok');
  ok.onclick=()=>{ closeM('m-confirm'); onConfirm(); };
  openM('m-confirm');
}
async function updateTaskBadge(){
  try{
    const today=new Date().toISOString().split('T')[0];
    const all=await idbGetAll('gorev_log');
    const doneIds=new Set(all.filter(t=>t.tamamlandi).map(t=>t.id));
    const tasks=all.filter(t=>!t.tamamlandi&&(!t.parent_id||doneIds.has(t.parent_id)));
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
    loadTasks();
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
    const hastaLogs=await getData('cases',c=>c.status==='active');
    setState('hastaIds', new Set(hastaLogs.map(d=>d.animal_id)));
    const sorted=[...animals].sort((a,b)=>(a.kupe_no||a.id||'').localeCompare(b.kupe_no||b.id||''));
    renderAnimals(sorted);
    _renderSuruStat();
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
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
  const kisirBadge=a.kisir?`<span class="tag" style="background:rgba(255,160,0,.15);color:var(--amber);font-weight:700;font-size:.65rem">💲 Kısır</span>`:'';
  // Repeat breed badge (backend view'dan gelir: repeat_breed_active, repeat_breed_past)
  let repeatBadge='';
  if(a.repeat_breed_active) repeatBadge+=`<span class="repeat-badge active">🔁 Tekrar Aşım</span>`;
  if(a.repeat_breed_past)   repeatBadge+=`<span class="repeat-badge past">↻ Tekrar</span>`;
  return `<span class="tag tb">${a.padok||'?'}</span><span class="tag tk">${a.grup||''}</span>${gebeBadge}${hastaBadge}${abortBadge}${bosTohBadge}${kisirBadge}${repeatBadge}`;
}
function _animalCardHtml(a,gebeSet,idx){
  const mainId=a.kupe_no||a.devlet_kupe||a.id||'?';
  const subId=a.kupe_no&&a.devlet_kupe?`<span style="font-size:.65rem;color:var(--ink3);font-weight:400"> · ${a.devlet_kupe}</span>`:'';
  const init=mainId.replace(/\D/g,'').slice(-3)||mainId.slice(0,2).toUpperCase();
  const yas=yasHesapla(a.dogum_tarihi);
  const seqHtml=idx!=null?`<span class="a-seq">${String(idx+1).padStart(2,'0')}</span>`:'';
  return `<div class="animal-card" onclick="openDet('${a.id}')">
    ${seqHtml}<div class="avt">${init}</div>
    <div class="ainfo">
      <div class="a-id">${mainId}${subId}</div>
      <div class="a-sub">${a.irk||'—'}${yas?' · '+yas:''}</div>
      <div class="a-tags">${_animalTagsHtml(a,gebeSet)}</div>
    </div>
    <svg class="a-arr" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg>
  </div>`;
}
function renderAnimals(list){
  const el=document.getElementById('suru-body');
  if(!list.length){ el.innerHTML='<div class="empty"><div class="empty-ico">🐄</div>Hayvan bulunamadı</div>'; return; }
  const gebeSet=new Set(getState('gebeIds')||[]);
  const tohMap=globalThis._tohMap||{};
  // Gebe → gebelik günü; Bekliyor tohumlama → tarih DESC; diğer → küpe no
  const bosTohMap=globalThis._bosTohMap||{};
  const sorted=[...list].sort((a,b)=>{
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

function _renderSuruStat(){
  const el=document.getElementById('suru-stat-card'); if(!el) return;
  const padok=document.getElementById('pflt')?.value||'';
  const key=padok;
  if(_suruStatCache[key]){
    _applySuruStatHtml(el,_suruStatCache[key],padok);
    _fetchSuruStat(el,padok,key);
    return;
  }
  if(el.innerHTML) _showStatLoading(el,true);
  _fetchSuruStat(el,padok,key);
}

function _fetchSuruStat(el,padok,key){
  const params=padok?{p_padok:padok}:{};
  db.rpc('stat_suru_ozet',params).then(({data})=>{
    if(data){
      _suruStatCache[key]=data;
      _applySuruStatHtml(el,data,padok);
    }
  }).catch(e=>console.warn('stat_suru_ozet:',e.message));
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
  const g=(d.gebelik||{}).ozet||{};
  const oran=g.oran!=null?`%${g.oran}`:'—';
  const padokLabel=padok?`🏠 ${esc(padok)} — `:'';

  const demoHtml=`<div class="stat-section">
    <div class="stat-section-title">📋 Demografik</div>
    <div class="stat-row">🐄 İnek: ${h.inek||0} · 🐮 Düve: ${h.duve||0} · 🐂 Erkek: ${h.erkek||0} · 🍼 Buzağı: ${h.buzagi||0} · 💲 Kısır: ${h.kisir||0}</div>
  </div>`;

  const katHtml=(d.gebelik?.kategori||[]).map(k=>{
    const ico=k.ad==='İnek'?'🐄':k.ad==='Düve'?'🐮':'❓';
    return `${ico} ${esc(k.ad)}: %${k.oran!=null?k.oran:'—'} (${k.toplam} tohum)`;
  }).join(' · ')||'Veri yok';

  const gebHtml=`<div class="stat-section">
    <div class="stat-section-title">🤰 Gebelik</div>
    <div class="stat-row">💉 ${g.toplam||0} tohumlama · ✅ ${g.gebe||0} gebe · ⭕ ${g.bos||0} boş · ⏳ ${g.bekleyen||0} bekleyen</div>
    <div class="stat-row">${katHtml}</div>
  </div>`;

  const spHtml=(d.gebelik?.sperma_top5||[]).map(s=>
    `<div class="stat-row">${esc(s.ad)} — ${s.toplam} tohum → <b>%${s.oran!=null?s.oran:'—'}</b></div>`
  ).join('')||'<div class="stat-row" style="color:var(--ink3)">Yeterli veri yok</div>';
  const spSection=`<div class="stat-section"><div class="stat-section-title">🏆 Top Spermalar (≥3 tohum)</div>${spHtml}</div>`;

  const deneme=d.gebelik?.deneme||[];
  const first3=deneme.filter(dn=>dn.no<=3);
  const rest=deneme.filter(dn=>dn.no>3);
  const dnFirst=first3.map(dn=>
    `<div class="stat-row">${dn.no}. deneme: ${dn.gebe} gebe / ${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const dnRest=rest.map(dn=>
    `<div class="stat-row">${dn.no}. deneme: ${dn.gebe} gebe / ${dn.toplam} → <b>%${dn.oran!=null?dn.oran:'—'}</b></div>`
  ).join('');
  const restBtn=rest.length>0?`<div id="deneme-rest" style="display:${_suruDenemeOpen?'block':'none'}">${dnRest}</div><div class="stat-row"><span onclick="_toggleDenemeRest()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">${_suruDenemeOpen?'Daralt':'[+'+rest.length+' daha]'}</span></div>`:'';
  const dnSection=`<div class="stat-section"><div class="stat-section-title">🔢 Deneme Dağılımı</div>${dnFirst}${restBtn}</div>`;

  el.innerHTML=`<div class="stat-card${_suruStatOpen?' open':''}" onclick="_toggleSuruStat(event)">
    <div class="stat-header"><span>${padokLabel}🐄 ${h.toplam||0} hayvan · 🤰 ${g.gebe||0} gebe (${oran}) · 🏥 ${h.hasta||0} hasta</span><span class="stat-arrow">▼</span></div>
    <div class="stat-detail">${demoHtml}${gebHtml}${spSection}${dnSection}</div>
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
  const data=_suruStatCache[padok];
  if(data){
    const el=document.getElementById('suru-stat-card');
    if(el) _applySuruStatHtml(el,data,padok);
  }
}
let _filterTimer=null;
function srchDropdown(){
  const q=(document.getElementById('srch')?.value||'').toLowerCase().trim();
  const ac=document.getElementById('ac-srch');
  if(!ac) return;
  if(!q){ ac.style.display='none'; return; }
  const gebeSet=new Set(getState('gebeIds')||[]);
  const matches=getState('animals').filter(a=>{
    const k=(a.kupe_no||'').toLowerCase(), d=(a.devlet_kupe||'').toLowerCase();
    return k.includes(q)||d.includes(q)||(a.irk||'').toLowerCase().includes(q);
  }).slice(0,8);
  if(!matches.length){ ac.style.display='none'; return; }
  ac.innerHTML=matches.map(a=>{
    const main=a.kupe_no||a.devlet_kupe||a.id;
    const sub=a.kupe_no&&a.devlet_kupe?` · <span style="color:#aaa">${a.devlet_kupe}</span>`:'';
    const isGebe=gebeSet.has(a.id);
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
let _fchip={cinsiyet:'hepsi',gebelik:null,saglik:null,kisir:null,tekrar:null};
let _detOpenId=null;
function fchipReset(){
  _fchip={cinsiyet:'hepsi',gebelik:null,saglik:null,kisir:null};
  document.querySelectorAll('[id^="fc-"]').forEach(b=>b.classList.remove('on'));
}
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
    const gebeSet=new Set(getState('gebeIds')||[]);
    let f=getState('animals');
    if(q) f=f.filter(a=>(a.id+(a.kupe_no||'')+(a.devlet_kupe||'')+(a.irk||'')).toLowerCase().includes(q));
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
    if(_fchip.saglik==='hasta') f=f.filter(a=>getState('hastaIds').has(a.id));
    if(_fchip.kisir==='kisir') f=f.filter(a=>a.kisir);
    if(_fchip.tekrar==='tekrar') {
      f=f.filter(a=>a.repeat_breed_active||a.repeat_breed_past);
      f.sort((a,b)=>{
        if(a.repeat_breed_active!==b.repeat_breed_active) return a.repeat_breed_active?-1:1;
        if(a.repeat_breed_past!==b.repeat_breed_past) return a.repeat_breed_past?-1:1;
        return (b.repeat_breed_count||0)-(a.repeat_breed_count||0);
      });
    }
    renderAnimals(f);
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
    <span onclick="openDet('${a.anne_id}')" style="font-weight:700;color:var(--blue);cursor:pointer">📌 ${anneKupe}</span>
  </div>`;
  if(yavrular.length) extra+=`<div style="background:var(--card2);border-radius:10px;padding:9px 12px;margin-bottom:8px;font-size:.8rem">
    <div style="color:var(--ink3);margin-bottom:4px">Yavrular (${yavrular.length}):</div>
    <div style="display:flex;flex-wrap:wrap;gap:5px">${yavrular.map(y=>`<span onclick="openDet('${y.id}')" style="background:var(--card);border:1px solid var(--card3);border-radius:7px;padding:3px 8px;font-size:.75rem;font-weight:700;cursor:pointer;color:var(--ink)">🐄 ${esc(y.kupe_no||y.devlet_kupe||y.id)}</span>`).join('')}</div>
  </div>`;
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
      ${infoFields.map(i=>`<div class="ig-item"><div class="ig-lbl">${i.l}</div><div class="ig-val">${i.v}</div></div>`).join('')}
    </div>
    ${extra}
    <button class="btn btn-g" style="margin-top:4px;padding:9px" onclick="openAnimalEdit('${a.id}')">✏️ Bilgileri Düzenle</button>
    <button class="btn btn-o" style="margin-top:6px;padding:9px" onclick="openNotModal('${a.id}','${displayId}')">📝 Not Ekle</button>
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
    h+=`<button class="btn btn-g" style="flex:1;padding:9px;font-weight:700" onclick="dogumYaptiAc('${a.id}','${hid}','${gebeTohumlama.tarih}','${gebeTohumlama.sperma||''}')">🐄 Doğum Yaptı</button>`;
  } else if(bekleyenToh){
    const _tohGun=Math.floor((Date.now()-new Date(bekleyenToh.tarih))/86400000);
    h+=`<button class="btn btn-g" style="flex:1;padding:9px" onclick="openInsemSafe('${hid}')">💉 Tohumlama Ekle</button>`;
    if(_tohGun>=0&&_tohGun<=15){
      h+=`<button class="btn" style="flex:1;padding:9px;font-weight:700;background:var(--purple);color:#fff;border:none" onclick="openTekrarAsim('${a.id}','${hid}')">🔁 Tekrar Aşım</button>`;
    }
  } else if(dogumYaptiToh){
    h+=`<button class="btn btn-g" style="flex:1;padding:9px" onclick="openInsemSafe('${hid}')">💉 Yeni Tohumlama Ekle</button>`;
  } else {
    h+=`<button class="btn btn-g" style="flex:1;padding:9px" onclick="openInsemSafe('${hid}')">💉 Tohumlama Ekle</button>`;
  }
  h+='</div>';
  if(gebeBilgi) h+=`<div style="background:rgba(78,154,42,.08);border:1px solid rgba(78,154,42,.2);border-radius:10px;padding:10px 12px;margin-bottom:8px;font-size:.8rem;color:var(--ink2)"><b style="color:var(--green)">🤰 Gebe</b> — ${gebeBilgi}</div>`;
  h+=(tohs.length
    ?tohs.map(t=>`<div class="hist-row" onclick="openTohDet('${t.id}')" style="cursor:pointer"><div class="hist-dot" style="background:${t.sonuc==='Gebe'?'var(--green2)':t.sonuc==='Boş'?'var(--red2)':'var(--amber)'}"></div><div class="hist-main"><div class="hist-title">${esc(t.sperma||'—')} <span style="background:var(--amber);color:#fff;font-size:.65rem;padding:1px 5px;border-radius:8px;font-weight:700">${t.deneme_no||1}. Deneme</span></div><div class="hist-sub">${esc(t.tarih||'')} · <b>${esc(t.sonuc||'Bekliyor')}</b></div></div></div>`).join('')
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
    const allLogs=await idbGetAll('islem_log');
    const logs=allLogs.filter(l=>l.ana_hayvan_id===id);
    logs.sort((x,y)=>(y.created_at||y.tarih||'').localeCompare(x.created_at||x.tarih||''));
    const ICO={'HAYVAN_EKLENDI':'🐮','TOHUMLAMA':'💉','DOGUM_KAYDI':'🐄','HASTALIK_KAYDI':'🏥','TEDAVI_GUNCELLE':'💊','KIZGINLIK':'🔴','ABORT_KAYDI':'⚠️','SATIS_KAYDI':'💰','OLUM_KAYDI':'💀','SUTTEN_KESME':'🍼','KISIR_ISARETLE':'💲','KISIR_KALDIR':'⭕'};
    const ETIKET={'HAYVAN_EKLENDI':'Hayvan Eklendi','TOHUMLAMA':'Tohumlama','DOGUM_KAYDI':'Doğum','HASTALIK_KAYDI':'Hastalık Kaydı','TEDAVI_GUNCELLE':'Tedavi Güncelle','KIZGINLIK':'Kızgınlık','ABORT_KAYDI':'Abort','SATIS_KAYDI':'Satış','OLUM_KAYDI':'Ölüm','SUTTEN_KESME':'Sütten Kesme','KISIR_ISARETLE':'Kısır İşareti','KISIR_KALDIR':'Kısır Kaldırıldı'};
    const GERI_AL=['TOHUMLAMA','DOGUM_KAYDI','HASTALIK_KAYDI','ABORT_KAYDI','HAYVAN_GUNCELLENDI'];
    if(!logs.length){ el.innerHTML='<div class="empty"><div class="empty-ico">📋</div>Kayıt yok</div>'; return; }
    globalThis._detGecmisLogs=logs;
    el.innerHTML=logs.map((l,i)=>{
      const ico=ICO[l.tip]||'📋';
      const tarih=(l.created_at||l.tarih||'').slice(0,10);
      const gaIcon=GERI_AL.includes(l.tip)?'<span style="font-size:.6rem;color:var(--ink3);margin-left:4px">↩</span>':'';
      // Padok değişikliği tespiti
      let padokHtml='';
      if (l.tip === 'HAYVAN_GUNCELLENDI' && l.snapshot && l.snapshot.old && l.snapshot.new) {
        const eskiPadokId = l.snapshot.old.padok_id;
        const yeniPadokId = l.snapshot.new.padok_id;
        if (eskiPadokId && yeniPadokId && eskiPadokId !== yeniPadokId) {
          const eskiAd = l.snapshot.old.padok || eskiPadokId;
          const yeniAd = l.snapshot.new.padok || yeniPadokId;
          padokHtml = `<div style="font-size:.65rem;color:var(--green);font-weight:600;margin-top:2px">🔀 Padok: ${eskiAd} → ${yeniAd}</div>`;
        }
      }
      return `<div class="hist-row" style="cursor:pointer" onclick="openIslemDetay(${i})"><div class="hist-dot" style="background:${padokHtml ? 'var(--green)' : 'var(--green2)'}"></div><div class="hist-main"><div class="hist-title">${ico} ${ETIKET[l.tip]||l.tip||'—'}${gaIcon}</div><div class="hist-sub">${tarih}${padokHtml}</div></div><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="flex-shrink:0;opacity:.4;margin-top:2px"><path d="M9 18l6-6-6-6"/></svg></div>`;
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}

// ──────────────────────────────────────────
// HAYVAN DETAY — ana fonksiyon
// ──────────────────────────────────────────
async function _detSaglikRender(el,activeCases,allDiseasesList,a,vaxLogs=[]){
  const activeCaseChips=activeCases.length
    ?`<div style="margin-bottom:8px;display:flex;flex-wrap:wrap;gap:6px">`+activeCases.map(c=>{
        const dis=allDiseasesList.find(d=>d.id===c.disease_id);
        return `<div onclick="openCaseDet('${c.id}')" style="cursor:pointer;background:rgba(192,50,26,.1);border:1.5px solid var(--red);border-radius:10px;padding:6px 10px;font-size:.78rem;font-weight:700;color:var(--red)">🏥 ${dis?.name||'?'}</div>`;
      }).join('')+`</div>`
    :'';
  const _caseListHtml=await renderCasesForAnimal(a.id);
  const vaxButton = `<div style="padding:6px 0 6px;display:grid;grid-template-columns:1fr 1fr;gap:6px">
    <button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-disease','d-hid','${a.kupe_no||a.devlet_kupe||a.id}')">🏥 Vaka Aç</button>
    <button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-vaccine','v-hid','${a.kupe_no||a.devlet_kupe||a.id}')">💉 Aşı Uygula</button>
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
  
  el.innerHTML=activeCaseChips+vaxButton+nextVaxChip+_caseListHtml+vaxHistory;
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
  return `<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openMWithHayvan('m-task-add','ta-hid','${kupe}')">➕ Görev Ekle</button></div>`+liste;
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
  await pullTables(['cases','diseases','drugs','vaccines','vaccination_log','kizginlik_log','gorev_log']).catch(e=>toast('Veri yüklenemedi: '+e.message,true));
  if(_detOpenId!==id) return;
  try {
    const [aArr,diseases,tohs,tasks,births,subs,yavrular,activeCases,vaxLogs,kizgs]=await Promise.all([
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
    ]);
    if(_detOpenId!==id) return;
    const a=aArr[0]; if(!a){ document.getElementById('det-name').textContent='Bulunamadı'; return; }
    diseases.sort((x,y)=>(y.tarih||'').localeCompare(x.tarih||''));
    tohs.sort((x,y)=>(y.tarih||'').localeCompare(x.tarih||''));
    tasks.sort((x,y)=>(x.hedef_tarih||'').localeCompare(y.hedef_tarih||''));
    vaxLogs.sort((x,y)=>(y.vaccination_date||'').localeCompare(x.vaccination_date||''));
    const yasRaw=a.dogum_tarihi?Math.floor((Date.now()-new Date(a.dogum_tarihi))/86400000):null;
    const _yasGunBase=yasRaw<0||yasRaw>36500?'Geçersiz tarih':yasHesapla(a.dogum_tarihi);
    const yasGun=yasRaw===null?'—':_yasGunBase;
    const aktifHst=diseases.filter(c=>c.status==='active').length;
    const today=new Date().toISOString().split('T')[0];
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
    await _detSaglikRender(document.getElementById('tab-saglik'),activeCases,allDiseasesList,a,vaxLogs);

    document.getElementById('tab-ureme').innerHTML=_detUremeHtml(a,tohs,kizgs);

    document.getElementById('tab-gorev').innerHTML=_detGorevHtml(a,tasks,subs,today);

    const gecmisEl=document.getElementById('tab-gecmis');
    if(gecmisEl) await _detRenderGecmis(id,gecmisEl);

  } catch(e){ document.getElementById('det-name').textContent='Hata: '+e.message; }
}
function closeDet(){ document.getElementById('det').classList.remove('on'); }
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
  if(l.ref_tablo==='tohumlama' && l.ref_id){ openTohDet(l.ref_id); return; }
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
  // Kısır checkbox'ı gizle
  const kw=document.getElementById('a-kisir-wrap');
  if(kw) kw.style.display='none';
  const kc=document.getElementById('a-kisir');
  if(kc){ kc.checked=false; kc.disabled=false; }
  const titleEl=document.getElementById('m-animal-title');
  const btnEl=document.getElementById('m-animal-btn');
  if(titleEl) titleEl.textContent='🐄 Hayvan Ekle';
  if(btnEl)   btnEl.textContent='Kaydet';
  closeM('m-animal');
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
      <div style="font-weight:700;font-size:.85rem;color:var(--ink2)">${anneKupe} → <b>${b.yavru_kupe||'?'}</b> <span style="color:var(--ink3);font-weight:400">(${b.yavru_cins||'?'})</span></div>
      <div style="font-size:.7rem;color:var(--ink3);margin-top:2px">${fmtTarih(b.tarih)} · <span style="background:${tipBg};color:${tipClr};border-radius:4px;padding:1px 6px;font-weight:700">${tip}</span>${b.dogum_kg?' · '+b.dogum_kg+' kg':''}</div>
    </div>
  </div>`;
    }).join('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
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
    return {toh:t,hayvan,kalanGun,dogumTahmini:dogumTahmini.toISOString().split('T')[0]};
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
        return `<div onclick="anneSeç('${g.hayvan.id}','${kupe}','${g.dogumTahmini}','${g.toh.sperma||''}')" 
          style="padding:12px 14px;border-bottom:1px solid var(--card3);cursor:pointer;background:${bg};display:flex;justify-content:space-between;align-items:center">
          <div>
            <div style="font-weight:700;font-size:.88rem;color:${color}">${kupe}</div>
            <div style="font-size:.68rem;color:var(--ink3);margin-top:2px">${g.hayvan?.irk||'—'} · ${g.toh.tarih} · ${g.toh.sperma||'?'}</div>
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
    const _colorMidF=urgent?'#b84c00':'#1a5c1a';
    const color=overdue?'#c0321a':_colorMidF;
    return `<div onclick="anneSeç('${g.hayvan.id}','${kupe}','${g.dogumTahmini}','${g.toh.sperma||''}')" 
      style="padding:12px 14px;border-bottom:1px solid var(--card3);cursor:pointer">
      <div style="font-weight:700;font-size:.88rem;color:${color}">${kupe} — ${overdue?'GECİKTİ '+Math.abs(g.kalanGun)+' gün':g.kalanGun+' gün kaldı'}</div>
      <div style="font-size:.68rem;color:var(--ink3);margin-top:2px">${g.hayvan?.irk||'—'} · ${g.toh.sperma||'?'} · Tahmini: ${fmtTarih(g.dogumTahmini)}</div>
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
  const a=getState('animals').find(x=>x.kupe_no===kupe||x.devlet_kupe===kupe);
  if(a) openDet(a.id);
  else toast('Hayvan bulunamadı: '+kupe);
}
function dogumYaptiAc(hayvanId,kupe,tohTarih,sperma){
  const dogumTahmini=dFwd(tohTarih,280);
  anneSeç(hayvanId,kupe,dogumTahmini,sperma);
  const tarihEl=document.getElementById('b-tarih');
  if(tarihEl) tarihEl.value=new Date().toISOString().split('T')[0];
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
  const q=(document.getElementById('kizginlik-srch')?.value||'').toLowerCase().trim();
  const flt=globalThis._kizginlikFilter||'tumu';
  let list=await idbGetAll('kizginlik_log');
  const animals=getState('animals')||[];
  // Search filtresi
  if(q){
    list=list.filter(k=>{
      const h=animals.find(a=>a.id===k.hayvan_id);
      const kupe=(h?.kupe_no||h?.devlet_kupe||'').toLowerCase();
      return kupe.includes(q)||k.hayvan_id.toLowerCase().includes(q);
    });
  }
  list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  // Durum filtresi
  let aktif=list.filter(k=>!k.cozuldu);
  let cozulmus=list.filter(k=>k.cozuldu);
  if(flt==='bekleyen') cozulmus=[];
  else if(flt==='sonuclanan') aktif=[];
  const card=(k,cozulduMi)=>{
    const h=getState('animals').find(a=>a.id===k.hayvan_id);
    const kupe=h?.kupe_no||h?.devlet_kupe||k.hayvan_id;
    const badge=cozulduMi
      ? k.tedavi_case_id
        ? `<span style="font-size:.6rem;color:var(--red2);background:rgba(192,50,26,.1);border-radius:4px;padding:1px 5px;margin-left:4px">🏥 Tedavi</span>`
        : `<span style="font-size:.6rem;color:var(--blue);background:rgba(52,152,219,.1);border-radius:4px;padding:1px 5px;margin-left:4px">💉 Tohumlandı</span>`
      : k.sonuc === 'POSTPARTUM_GOZLEM'
        ? `<span style="font-size:.6rem;color:var(--ink3);background:var(--card2);border-radius:4px;padding:1px 5px;margin-left:4px">👁 Gözlem</span>`
      : '';
    const caseBadge = k.tedavi_case_id && !cozulduMi
      ? `<span style="font-size:.6rem;color:var(--blue);background:rgba(42,107,181,.1);border-radius:4px;padding:1px 5px;margin-left:4px;cursor:pointer" onclick="event.stopPropagation();toast('🏥 Vaka açıldı — Tedavi sekmesinden görüntüleyin')">🔗 Vaka</span>`
      : '';
    return `<div class="hist-row">
      <div class="hist-dot" style="background:#e74c3c;cursor:pointer" onclick="openDet('${k.hayvan_id}')"></div>
      <div class="hist-main" style="cursor:pointer" onclick="openDet('${k.hayvan_id}')">
        <div class="hist-title">🔴 ${esc(kupe)} — ${esc(k.belirti||'Kızgınlık')} ${badge}</div>
        <div class="hist-sub">${esc(k.tarih)} ${k.notlar?'· '+esc(k.notlar):''} ${caseBadge}</div>
      </div>
      <div style="display:flex;gap:3px;flex-shrink:0;align-items:center">
        ${cozulduMi?'':`
          <button style="background:var(--blue);color:#fff;padding:2px 5px;font-size:.62rem;border-radius:4px;border:none;cursor:pointer;font-weight:700"
            onclick="event.stopPropagation();globalThis._insemKizginlikId='${k.id}';openInsemSafe('${kupe}')">💉 Tohumla</button>
          <button style="background:rgba(42,107,181,.15);color:var(--blue);padding:2px 5px;font-size:.62rem;border-radius:4px;border:none;cursor:pointer;font-weight:700;white-space:nowrap"
            onclick="event.stopPropagation();kizginlikTedaviAc('${k.id}','${kupe}')">🏥 Tedavi</button>
        `}
        <button style="background:rgba(192,50,26,.1);color:var(--red2);padding:2px 5px;font-size:.6rem;border-radius:4px;border:none;cursor:pointer;font-weight:700;line-height:1"
          onclick="event.stopPropagation();kizginlikSil('${k.id}')">🗑️</button>
      </div>
    </div>`;
  };
  const aktifHtml=aktif.length
    ? `<div style="margin-bottom:8px;font-size:.72rem;font-weight:700;color:var(--red2);text-transform:uppercase;letter-spacing:.06em;padding:4px 0">🔴 Bekleyen Kızgınlıklar (${aktif.length})</div>`
      +aktif.map(k=>card(k,false)).join('')
    : '';
  const cozulmusHtml=cozulmus.length
    ? `<div style="margin-top:12px;border-top:1px solid var(--card3);padding-top:8px;font-size:.72rem;font-weight:700;color:var(--green);text-transform:uppercase;letter-spacing:.06em;padding-bottom:4px">✅ Sonuçlanan (${cozulmus.length})</div>`
      +cozulmus.map(k=>card(k,true)).join('')
    : '';
  el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" onclick="openM('m-kizginlik')">🔴 Kızgınlık Ekle</button></div>`
    +(list.length?aktifHtml+cozulmusHtml:'<div class="empty"><div class="empty-ico">🔴</div>Kızgınlık kaydı yok</div>');
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
          <button type="button" onclick="sorunSec('${s.id}','${esc(s.tani||'')}',event)"
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
        return `<div class="hist-row" style="align-items:center;gap:8px">
          <div class="hist-dot" style="background:var(--amber);flex-shrink:0"></div>
          <div class="hist-main" style="flex:1;min-width:0;cursor:pointer" onclick="openDetByKupe('${kupe}')">
            <div class="hist-title" style="color:var(--amber)">${kupe}</div>
            <div class="hist-sub">${t.sperma||'?'} · ${fmtTarih(t.tarih)} · ${gun} gün</div>
          </div>
          <button style="background:var(--green);color:#fff;white-space:nowrap;flex-shrink:0;padding:2px 5px;font-size:.62rem;min-width:auto;line-height:1.1;border-radius:4px;border:none;cursor:pointer;font-weight:700"
            onclick="gebeAta('${t.id}','${kupe}')">Gebe Ata</button>
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
        <div class="hist-title" style="color:${kalanGun<0?'var(--red)':'var(--green)'}">🤰 ${kupe}</div>
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
          <div class="hist-title">${kupe} · ${t.sperma||'?'}${beslemeUyari}</div>
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
            <span onclick="openDet('${b.anne_id}')" style="cursor:pointer">🐄 ${anneKupe}</span>
            → <b onclick="openDetByKupe('${b.yavru_kupe}')" style="cursor:pointer;color:var(--blue)">${b.yavru_kupe}</b> (${b.yavru_cins||'?'})
          </div>
          <div class="hist-sub">${fmtTarih(b.tarih)} · <span style="background:${tipBg};color:${tipRenk};border-radius:4px;padding:1px 6px;font-weight:700;font-size:.7rem">${tip}</span></div>
        </div>
      </div>`;
    }).join(''):'<div class="empty"><div class="empty-ico">🐄</div>Dogum kaydi yok</div>');
  el.innerHTML=yakHtml+dogHtml;
}

async function _uremeTohumlama(el){
  const list=await idbGetAll('tohumlama');
  list.sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
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
      return `<div class="hist-row" style="cursor:pointer;display:flex;align-items:center;gap:8px" onclick="openTohDet('${t.id}')">
        <div class="hist-dot" style="background:${dot};flex-shrink:0"></div>
        <div class="hist-main" style="flex:1;min-width:0">
          <div class="hist-title" style="color:var(--ink2)">${kupe} — ${t.sperma||'?'} <span style="background:var(--amber);color:#fff;font-size:.65rem;padding:1px 5px;border-radius:8px;font-weight:700">${t.deneme_no||1}. Deneme</span></div>
          <div class="hist-sub">${t.tarih} · <b style="color:${sc}">${t.sonuc||'Bekliyor'}</b></div>
        </div>
        ${_bekliyor && t.tarih
          ? (()=>{
              const _uretGun=Math.floor((Date.now()-new Date(t.tarih))/86400000);
              return _uretGun>=0&&_uretGun<=15
                ? `<button onclick="event.stopPropagation();openTekrarAsim('${t.hayvan_id}','${kupe.replace(/'/g,"\\'")}')" style="flex-shrink:0;background:var(--purple);color:#fff;border:none;border-radius:8px;padding:6px 10px;font-size:.68rem;font-weight:700;cursor:pointer">🔁 Tekrar Aşım</button>`
                : '<span style="flex-shrink:0;font-size:.65rem;color:var(--ink3)">' + _uretGun + ' gün</span>';
            })()
          : (_bekliyor
            ? `<button onclick="event.stopPropagation();tekrarTohumla('${kupe.replace(/'/g,"\\'")}')" style="flex-shrink:0;background:var(--green);color:#fff;border:none;border-radius:8px;padding:6px 10px;font-size:.68rem;font-weight:700;cursor:pointer">💉 Tohumla</button>`
            : '')}
      </div>`;
    }).join(''):'<div class="empty"><div class="empty-ico">💉</div>Tohumlama kaydı yok</div>');
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
        <div class="hist-title" style="color:var(--red)">⚠️ ${kupe} — Abort</div>
        <div class="hist-sub">${t.tarih} ${t.abort_notlar?'· '+t.abort_notlar:''}</div>
      </div>
    </div>`;
  }).join(''):'<div class="empty"><div class="empty-ico">⚠️</div>Abort kaydı yok</div>');
}

async function loadUreme(tab='kizginlik'){
  _curUremeTab=tab;
  const el=document.getElementById('ureme-body');
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  // Kizginlik disindaki tablerde toolbar'i gizle
  const tb=document.getElementById('kizginlik-toolbar');
  if(tb&&tab!=='kizginlik') tb.style.display='none';
  try {
    if(tab==='kizginlik')      await _uremeKizginlik(el);
    else if(tab==='tohumlama') await _uremeTohumlama(el);
    else if(tab==='gebelik')   await _uremeGebelik(el);
    else if(tab==='dogum')     await _uremeDogum(el);
    else if(tab==='abort')     await _uremeAbort(el);
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}

// ──────────────────────────────────────────
// GEÇMİŞ
// ──────────────────────────────────────────
const _GECMIS_ICO = {dogum:'🐄',tohumlama:'💉',hastalik:'🏥',gorev:'✅',ASI_KAYDI:'💉',ASI_ERTELEME:'⏸️',TOPLU_ILAC:'💊'};
const _GECMIS_BG  = {dogum:'rgba(78,154,42,.1)',tohumlama:'rgba(42,107,181,.1)',hastalik:'rgba(192,50,26,.1)',gorev:'var(--card2)',islem:'rgba(120,120,120,.1)',ASI_KAYDI:'rgba(0,160,200,.1)',ASI_ERTELEME:'rgba(120,120,120,.1)',TOPLU_ILAC:'rgba(120,80,200,.1)'};
const _ISLEM_ICO  = {HAYVAN_EKLENDI:'🐮',ABORT_KAYDI:'⚠️',KIZGINLIK_KAYDI:'🔴',ASI_KAYDI:'💉',ASI_ERTELEME:'⏸️',TOPLU_ILAC:'💊'};
const _ISLEM_ETK  = {HAYVAN_EKLENDI:'🐮 Hayvan Eklendi',ABORT_KAYDI:'⚠️ Abort',KIZGINLIK_KAYDI:'🔴 Kızgınlık',ASI_KAYDI:'💉 Aşı Kaydı',ASI_ERTELEME:'⏸️ Aşı Ertelendi',TOPLU_ILAC:'💊 Toplu İlaç'};

function _gecmisEntryHtml(e){
  const {type,date,data}=e;
  const d=fmtTarih(date);
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
    title=`<span onclick="openDet('${data.anne_id}')" style="cursor:pointer">${anneLabel||'?'}</span> → <b onclick="openDetByKupe('${data.yavru_kupe}')" style="cursor:pointer;color:var(--blue)">${data.yavru_kupe||'?'}</b> (${data.yavru_cins||'?'})`;
    sub=`${data.dogum_tipi||'Normal'}${hkName}`;
  } else if(type==='tohumlama'){
    const sc=data.sonuc==='Gebe'?'var(--green)':data.sonuc==='Boş'?'var(--red)':'var(--amber)';
    title=`${hayvanLabel||'?'} — ${data.sperma||'?'}`;
    sub=`${data.deneme_no||1}. Tohumlama · <b style="color:${sc}">${data.sonuc||'Bekliyor'}</b>${hkName}`;
  } else if(type==='hastalik'){
    const sc=data.status==='active'?'var(--red)':'var(--green)';
    title=`${hayvanLabel||'?'} — ${data.disease_name||data.tani||'?'}`;
    sub=`<b style="color:${sc}">${data.status==='active'?'Aktif':'Kapalı'}</b>${hkName}`;
  } else if(type==='gorev'){
    const gHayvan=getState('animals').find(a=>a.id===data.hayvan_id);
    const gLabel=gHayvan?(gHayvan.kupe_no||gHayvan.devlet_kupe):data.hayvan_id;
    const _done=data.tamamlandi;
    const _pill=_done?'<span style="font-size:.6rem;padding:1px 6px;border-radius:8px;background:var(--card3);color:var(--ink3)">Tamamlandı</span>':'<span style="font-size:.6rem;padding:1px 6px;border-radius:8px;background:rgba(42,107,181,.15);color:var(--blue)">Bekliyor</span>';
    if(data.gorev_tipi==='TEDAVI_GUN'){
      const lbl=data._lbl||('Gün '+(data._gunNo||'?')+' tedavisi');
      title=`${gLabel||'?'} — ${lbl}`;
      const drugLine=(data._drugNames||[]).length?`<div style="font-size:.66rem;color:var(--ink2);margin-top:1px">💊 ${data._drugNames.join(', ')}</div>`:'';
      const disLine=data._disName?`<span style="font-size:.62rem;color:var(--ink3)">🏥 ${data._disName}</span> · `:'';
      sub=`${drugLine}<div style="margin-top:1px">${disLine}${_pill}</div>`;
      if(data._caseId) oc=`onclick="openCaseDet('${data._caseId}')" style="cursor:pointer"`;
    } else {
      let _aLbl='';try{const _p=typeof data.aciklama==='string'?JSON.parse(data.aciklama):data.aciklama;_aLbl=_p?.label||data.aciklama||'';}catch(e){_aLbl=data.aciklama||'';}
      title=`${gLabel||'GENEL'} — ${_aLbl}`;
      sub=`<span class="pill ${data.gorev_tipi||'DIGER'}">${(data.gorev_tipi||'').replace(/_/g,' ')}</span> · ${_pill}${hkName}`;
      if(data.hayvan_id) oc=`onclick="openDet('${data.hayvan_id}')" style="cursor:pointer"`;
    }
  } else if(type==='islem'){
    const snap=data.snapshot||{};
    const hayvanObj2=getState('animals').find(a=>a.id===data.ana_hayvan_id);
    const kupe=hayvanObj2?.kupe_no||hayvanObj2?.devlet_kupe||snap.kupe_no||snap.devlet_kupe||data.ana_hayvan_id||'?';
    title=`${kupe} — ${_ISLEM_ETK[data.tip]||data.tip}`;
    if(data.tip==='ASI_KAYDI') sub=snap.vaccine_name||'';
    else if(data.tip==='ASI_ERTELEME') sub=snap.erteleme_notu||snap.vaccine_name||'';
    else if(data.tip==='TOPLU_ILAC') sub=snap.ilac_adi||'';
    else sub=snap.irk||snap.grup||'';
    if(snap.kupe_no||snap.devlet_kupe||['ASI_KAYDI','TOPLU_ILAC'].includes(data.tip)) oc=`onclick="openDet('${data.ana_hayvan_id}')" style="cursor:pointer"`;
  }
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
  else if(e.type==='islem'){
    const snap=d.snapshot||{};
    parts.push(_ISLEM_ETK[d.tip]||d.tip||'',snap.vaccine_name||'',snap.ilac_adi||'',snap.irk||'',snap.kupe_no||'',snap.devlet_kupe||'');
  }
  const hk=HEKIMLER.find(h=>h.id===d.hekim_id);
  if(hk)parts.push(hk.ad);
  return parts.join(' ').toLowerCase().replace(/\s+/g,' ');
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
      const _hDrugsByCase={};
      const _hDayCase=Object.fromEntries(_hTdays.map(td=>[td.id,td.case_id]));
      _hDadm.forEach(da=>{
        const cid=_hDayCase[da.treatment_day_id];
        if(!cid)return;
        const name=_hStokById[da.stok_id]||'';
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
      const _drugsByDay={};
      _allDrugs.forEach(da=>{
        if(!da.treatment_day_id)return;
        const name=_stokById[da.stok_id]||'';
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
    // RPC: link_drug_to_stock artık drugs tablosunu düzgün güncelliyor
    // Ek batch update'e gerek yok, çünkü RPC içinde tek bir UPDATE yapılıyor
    await rpc('link_drug_to_stock', { p_drug_id: drugId, p_stock_item_id: drugId ? stokId : null });
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
          Object.entries(grouped).sort().map(([grp, list]) =>
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
  const res=await rpcOptimistic(isNew?'disease_ekle':'disease_guncelle',
    isNew?{p_name:name,p_category:cat}:{p_id:id,p_name:name,p_category:cat},
    null,['diseases']);
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  loadTanimlarPanel();
}

async function _diseaseDelete(id){
  if(!confirm('Bu hastalığı silmek istediğinize emin misiniz?')) return;
  const res=await rpcOptimistic('disease_sil',{p_id:id});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
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
    if(res&&res.ok===false){toast(res.mesaj,'error');return;}
    toast(`${res.eklenen||0} yeni ilaç sınıfı eklendi`);
    loadTanimlarPanel();
    return;
  }
  const labels={diseases:'hastalık',drugs:'ilaç',kategoriler:'kategori'};
  if(!confirm(`Standart ${labels[tip]||tip} tanımları geri yüklenecek. Mevcut özel tanımlarınız silinmez. Devam?`)) return;
  const res=await rpcOptimistic('seed_defaults',{p_tip:tip});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
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
  const gruplar=Object.keys(tree).sort();

  gruplar.forEach(grp=>{
    const renk=GRP_RENK[grp]||'#607d8b';
    const altGruplar=tree[grp];
    const toplamMadde=Object.values(altGruplar).reduce((s,arr)=>s+arr.length,0);

    html+=`<div class="tanim-grup" style="margin-bottom:6px">
      <div onclick="this.nextElementSibling.style.display=this.nextElementSibling.style.display==='none'?'block':'none';this.querySelector('.tanim-chev').classList.toggle('tanim-chev-open')" style="display:flex;align-items:center;gap:8px;padding:9px 10px;background:${renk}15;border:1px solid ${renk}30;border-radius:8px;cursor:pointer;user-select:none">
        <span style="width:4px;height:22px;border-radius:2px;background:${renk};flex-shrink:0"></span>
        <span style="font-weight:800;font-size:.82rem;color:${renk};flex:1">${esc(grp)}</span>
        <span class="tanim-grup-count" style="background:var(--card3);color:var(--ink3);padding:1px 7px;border-radius:10px;font-size:.65rem;font-weight:700">${toplamMadde}</span>
        <button onclick="event.stopPropagation();_dcEditInline('group','${esc(grp)}',null)" style="padding:2px 6px;background:none;border:none;cursor:pointer;font-size:.7rem" title="Düzenle">✏️</button>
        <button onclick="event.stopPropagation();_dcDeleteGroup('${esc(grp)}')" style="padding:2px 6px;background:none;border:none;cursor:pointer;font-size:.7rem" title="Sil">🗑</button>
        <svg class="tanim-chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="${renk}" stroke-width="2.5" style="transition:transform .2s;flex-shrink:0"><path d="M6 9l6 6 6-6"/></svg>
      </div>
      <div style="display:none;padding:4px 0 0 0">`;

    Object.keys(altGruplar).sort().forEach(cls=>{
      const maddeler=altGruplar[cls];
      html+=`<div style="margin:4px 0 0 12px">
        <div onclick="const n=this.nextElementSibling;n.style.display=n.style.display==='none'?'block':'none';this.querySelector('.tanim-chev').classList.toggle('tanim-chev-open')" style="display:flex;align-items:center;gap:6px;padding:6px 8px;background:var(--card2);border-radius:6px;cursor:pointer;user-select:none">
          <span style="width:3px;height:16px;border-radius:2px;background:${renk}60;flex-shrink:0"></span>
          <span style="font-weight:700;font-size:.78rem;color:var(--ink);flex:1">${esc(cls)}</span>
          <span style="font-size:.6rem;color:var(--ink3)">${maddeler.length}</span>
          <button onclick="event.stopPropagation();_dcEditInline('class','${esc(grp)}','${esc(cls)}')" style="padding:2px 4px;background:none;border:none;cursor:pointer;font-size:.65rem" title="Düzenle">✏️</button>
          <button onclick="event.stopPropagation();_dcDeleteClass('${esc(grp)}','${esc(cls)}')" style="padding:2px 4px;background:none;border:none;cursor:pointer;font-size:.65rem" title="Sil">🗑</button>
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

      html+=`<button onclick="_dcAddIngredient('${esc(grp)}','${esc(cls)}')" style="display:block;width:calc(100% - 20px);margin:3px 0 0 20px;padding:6px;background:none;border:1px dashed var(--card3);border-radius:5px;color:var(--ink3);font-size:.7rem;cursor:pointer;text-align:left">＋ Etken Madde Ekle</button>`;
      html+=`</div></div>`;
    });

    html+=`<button onclick="_dcAddClass('${esc(grp)}')" style="display:block;width:calc(100% - 12px);margin:4px 0 0 12px;padding:6px;background:none;border:1px dashed var(--card3);border-radius:5px;color:var(--ink3);font-size:.7rem;cursor:pointer;text-align:left">＋ Alt Grup Ekle</button>`;
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
  const res=await rpcOptimistic('drug_class_ekle',{p_group_name:name.trim(),p_class_name:'Genel',p_active_ingredient:'(tanımsız)'});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Grup eklendi');
  loadTanimlarPanel();
}

async function _dcAddClass(grp){
  const name=prompt('Yeni alt grup adı:');
  if(!name||!name.trim()) return;
  const res=await rpcOptimistic('drug_class_ekle',{p_group_name:grp,p_class_name:name.trim(),p_active_ingredient:'(tanımsız)'});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Alt grup eklendi');
  loadTanimlarPanel();
}

async function _dcAddIngredient(grp,cls){
  const name=prompt('Yeni etken madde adı:');
  if(!name||!name.trim()) return;
  const allDC=await idbGetAll('drug_classes');
  const sameGrp=allDC.find(dc=>dc.group_name===grp);
  const katId=sameGrp?sameGrp.kategori_id:null;
  const res=await rpcOptimistic('drug_class_ekle',{p_group_name:grp,p_class_name:cls,p_active_ingredient:name.trim(),p_kategori_id:katId});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  const placeholder=allDC.find(dc=>dc.group_name===grp&&dc.class_name===cls&&dc.active_ingredient==='(tanımsız)');
  if(placeholder) await rpcOptimistic('drug_class_sil',{p_id:placeholder.id});
  toast('Etken madde eklendi');
  loadTanimlarPanel();
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
  const res=await rpcOptimistic('drug_class_guncelle',{p_id:id,p_active_ingredient:newName.trim()});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Güncellendi');
  loadTanimlarPanel();
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
  const res=await rpcOptimistic('drug_class_sil',{p_id:id});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Silindi');
  loadTanimlarPanel();
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
  const res=await rpcOptimistic(isNew?'kategori_ekle':'kategori_guncelle',
    isNew?{p_ad:ad,p_tip:tip}:{p_id:id,p_new_ad:ad,p_tip:tip});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  loadTanimlarPanel();
}

async function _kategoriDelete(id){
  if(!confirm('Bu kategoriyi silmek istediğinize emin misiniz?')) return;
  const res=await rpcOptimistic('kategori_sil',{p_id:id});
  if(res&&res.ok===false){toast(res.mesaj,'error');return;}
  toast('Kategori silindi');
  loadTanimlarPanel();
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
    {baslik:'💉 Aşılar',alt:[
      {ad:'💉 Aşı Ürünleri', filtre:s=>s.isVaccine||s.kategori==='Aşı'},
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
// Vaccines section
  const vaxList=await getData('vaccines');
  if(vaxList&&vaxList.length){
    html+=`<div class="stok-group" style="font-size:.72rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.07em;margin:14px 0 8px">💉 Aşı</div>`;
    html+=`<div style="font-size:.65rem;font-weight:700;color:var(--ink3);margin:8px 0 4px;padding-left:4px">💉 Kayıtlı Aşılar (${vaxList.length})</div>`;
    html+=vaxList.map(v=>{
      const interval=v.repeat_interval_days?(v.repeat_interval_days===365?'Yıllık':v.repeat_interval_days===180?'6 Aylık':v.repeat_interval_days+' günde bir'):'Tek Doz';
      const mandatory=v.is_mandatory?'🔴 Zorunlu':'🔵 Opsiyonel';
      return `<div class="stok-item" data-ad="${esc(v.name)}" style="background:var(--card);border:1px solid var(--card3);border-left:3px solid var(--blue);border-radius:10px;padding:11px 13px;margin-bottom:7px">
        <div style="display:flex;justify-content:space-between;align-items:flex-start">
          <div style="flex:1">
            <div style="font-weight:700;font-size:.88rem;color:var(--ink)">${v.name}</div>
            <div style="font-size:.62rem;color:var(--ink3);margin-top:2px">${v.disease_target||'—'} · ${interval} · ${mandatory}</div>
            ${v.dosage_ml?`<div style="font-size:.62rem;color:var(--ink3)">Standart doz: ${v.dosage_ml} ml</div>`:''}
          </div>
        </div>
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
  const{error}=await rpc('stok_guncelle',{p_stok_id:_curStokDet.id,...updates});
  if(error){ toast('Hata: '+error.message,true); return; }
  await pullTables(['stok']);
  closeM('m-stok-det');
  loadStokPanel();
  toast('Ürün güncellendi');
}

async function stokDetArsivle(){
  if(!_curStokDet) return;
  const hareketler=await getData('stok_hareket');
  const count=hareketler.filter(h=>h.stok_id===_curStokDet.id&&!h.iptal).length;
  const msg=count>0
    ?`Bu üründe ${count} hareket kaydı var. Arşivlenecek (silinmeyecek). Devam?`
    :'Bu ürünü arşivlemek istediğinizden emin misiniz?';
  openConfirm('Ürün Arşivle',msg,async()=>{
    const{error}=await rpc('stok_arsivle',{p_stok_id:_curStokDet.id});
    if(error){ toast('Hata: '+error.message,true); return; }
    await pullTables(['stok']);
    closeM('m-stok-det');
    loadStokPanel();
    toast('Ürün arşivlendi');
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
            <div style="font-weight:700;font-size:.85rem;color:var(--ink)">${urunAd}</div>
            <div style="font-size:.85rem;font-weight:800;color:${turRenk}">${turIsaret}${(m.miktar||0).toFixed(dec)} ${birim}</div>
          </div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:4px;font-size:.68rem;color:var(--ink3)">
            <div>📅 ${tarihFmt}</div>
            <div>📝 ${m.tur||'—'}</div>
          </div>
          ${m.notlar?`<div style="font-size:.68rem;color:var(--ink3);margin-top:4px;padding-top:4px;border-top:1px dashed var(--card2)">${m.notlar}</div>`:''}
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
        <div><div style="font-weight:600">${m.tur||'Kullanım'}</div><div style="color:#999;font-size:.7rem">${m.notlar||''}</div><div style="color:#888;font-size:.7rem;font-weight:600">${_tarih}</div></div>
        <div style="text-align:right"><div style="font-weight:700;color:${m.miktar<0?'var(--green)':'#c0321a'}">${m.miktar<0?'+':'-'}${Math.abs(m.miktar)} ${s.birim||''}</div></div>
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
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const [animals,tohs,diseases,births,stock]=await Promise.all([
      idbGetAll('hayvanlar'),
      idbGetAll('tohumlama'),
      idbGetAll('cases'),
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

    // Hastalık kategorileri
    const katMap={};
    diseases.forEach(d=>{ const k=d.kategori||'Diğer'; katMap[k]=(katMap[k]||0)+1; });
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
      ${statKart('Aktif Vaka',diseases.filter(d=>d.durum==='Aktif').length,'hastalık',diseases.filter(d=>d.durum==='Aktif').length>0?'var(--red)':'var(--green)')}
      ${statKart('Toplam Doğum',births.length,'')}
    </div>`;

    if(irkSorted.length){
      h+=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
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
      h+=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">🏥 Hastalık Kategorileri</div>
        ${katSorted.map(([kat,sayi])=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>${kat}</span><span style="font-weight:700;color:var(--red)">${sayi}</span>
        </div>`).join('')}
      </div>`;
    }

    if(negStk.length||kritikStok.length){
      h+=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="font-weight:700;font-size:.85rem;margin-bottom:10px">📦 Stok Durumu</div>
        ${negStk.map(s=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>🆘 ${esc(s.urun_adi)}</span><span style="font-weight:700;color:var(--red)">${stkNet[s.id].toFixed(1)} ${s.birim||''}</span>
        </div>`).join('')}
        ${kritikStok.map(s=>`<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2);font-size:.8rem">
          <span>⚠️ ${esc(s.urun_adi)}</span><span style="font-weight:700;color:var(--amber)">${stkNet[s.id].toFixed(1)} ${s.birim||''}</span>
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
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}

// ──────────────────────────────────────────
// GÖREV DETAY MODAL
// ──────────────────────────────────────────
async function openTaskDet(id){
  const all=await idbGetAll('gorev_log');
  const t=all.find(x=>x.id===id); if(!t) return;
  if(t.tamamlandi){ openDoneTaskDet(id); return; }
  _curTaskDet=t;
  const today=new Date().toISOString().split('T')[0];
  const hekim=[...HEKIMLER,...(_customHekimler||[])].find(h=>h.id===t.hekim_id);
  const isLate=t.hedef_tarih<today;
  const hayvanLabel=getState('animals').find(a=>a.id===t.hayvan_id);
  const tdHayvan=document.getElementById('td-hayvan');
  tdHayvan.textContent=(hayvanLabel?.kupe_no||hayvanLabel?.devlet_kupe)||(t.hayvan_id?.length>20?'Buzağı-'+t.hayvan_id.slice(-6):t.hayvan_id)||'GENEL GÖREV';
  if(t.hayvan_id){
    tdHayvan.style.cursor='pointer';
    tdHayvan.onclick=()=>{ closeM('m-task-det'); openDet(t.hayvan_id); };
  } else {
    tdHayvan.style.cursor='';
    tdHayvan.onclick=null;
  }
  const _acEl=document.getElementById('td-aciklama');if(_acEl){_acEl.textContent=t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').label||t.aciklama;}catch(e){return t.aciklama;}})():t.aciklama||'';delete _acEl.dataset.diseaseAppended;}
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
        <span style="font-size:.8rem;color:var(--ink);${s.tamamlandi?'text-decoration:line-through;opacity:.6':''}">${esc(s.aciklama)}</span>
      </div>`).join('');
  } else { subsEl.style.display='none'; }

  // Butonları reset et
  const tamamBtn=document.getElementById('td-tamam-btn');
  const asiAcBtn=document.getElementById('td-asi-ac-btn');
  const asiForm =document.getElementById('td-asi-form');
  // rapelForm removed — merged into td-asi-form
  if(tamamBtn)  tamamBtn.style.display='block';
  if(asiAcBtn)  asiAcBtn.style.display='none';
  if(asiForm)   asiForm.style.display='none';
  _curTaskVaccineId=null;

  // ILERI_GEBE_ASI: standart tamamla gizle, aşı butonu göster
  if(t.gorev_tipi==='ILERI_GEBE_ASI'){
    if(tamamBtn) tamamBtn.style.display='none';
    if(asiAcBtn) asiAcBtn.style.display='block';
    try{
      const vaccines=await getData('vaccines');
      const vax=vaccines.find(v=>v.stock_item_id===t.stok_id);
      if(vax){
        _curTaskVaccineId=vax.id;
        document.getElementById('td-asi-adi').textContent=vax.name||'Rota-Corona';
        const dozEl=document.getElementById('td-asi-doz');
        if(dozEl){
          if(vax.dose) dozEl.value=vax.dose;
          dozEl.placeholder=vax.dose||'';
        }
        const dozInfo=document.getElementById('td-asi-doz-info');
        if(dozInfo) dozInfo.textContent='St: '+(vax.dose||'?')+' '+(vax.unit||'ml');
        const dozUnit=document.getElementById('td-asi-doz-unit');
        if(dozUnit) dozUnit.textContent='('+(vax.unit||'ml')+')';
      }
    }catch(e){ console.warn('vaccine lookup:',e.message); }
    const tarihEl=document.getElementById('td-asi-tarih');
    const todayStr=new Date().toISOString().split('T')[0];
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
        await pullTables(['drug_administrations','treatment_days','cases','stok','diseases']);
        const [allAdmins,allDays,allCases,allStok,allDiseases]=await Promise.all([
          idbGetAll('drug_administrations'),
          idbGetAll('treatment_days'),
          idbGetAll('cases'),
          idbGetAll('stok'),
          idbGetAll('diseases'),
        ]);
        const stokMap=Object.fromEntries(allStok.map(s=>[s.id,s.urun_adi||s.id]));
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
                  <div style="font-size:.88rem;font-weight:600;color:var(--ink);line-height:1.2">${esc(stokMap[da.stok_id]||'İlaç')}</div>
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
        const fmt=d=>d.toISOString().split('T')[0];
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
    loadTasks(_curTaskFilter||'today');
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
  if(!_curTaskDet||!_curTaskVaccineId){ toast('Aşı bilgisi eksik',true); return; }
  const btn=document.getElementById('td-asi-uygula-btn');
  if(btn){btn.disabled=true;btn.textContent='İşleniyor…';}
  try{
    const tarih=document.getElementById('td-asi-tarih').value||new Date().toISOString().split('T')[0];
    const dozRaw=document.getElementById('td-asi-doz').value;
    const doz=dozRaw?parseFloat(dozRaw):null;
    const res=await rpc('ileri_gebe_asi_tamamla',{
      p_gorev_id:  _curTaskDet.id,
      p_vaccine_id:_curTaskVaccineId,
      p_tarih:     tarih,
      p_doz:       doz,
    });
    if(!res.ok){ toast(_trErr(res.mesaj||'Hata'),true); return; }
    closeM('m-task-det');
    await pullTables(['gorev_log']).catch(()=>{});
    updateTaskBadge();
    loadTasks(_curTaskFilter||'today');
    loadDash();
    const rapelTarih=res.rapel_tarih?fmtTarih(res.rapel_tarih):null;
    toast(rapelTarih?`✅ Aşı kaydedildi · Rapel: ${rapelTarih}`:'✅ Aşı kaydedildi');
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
    await write('gorev_log',{hedef_tarih:yeniTarih},'PATCH',`id=eq.${_curTaskDet.id}`);
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
    ddHayvan.onclick=()=>{ closeM('m-done-det'); openDet(t.hayvan_id); };
  } else {
    ddHayvan.style.cursor='';
    ddHayvan.onclick=null;
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
      loadTasks(_curTaskFilter||'today');
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
        ['Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diger Ilac','Ilac'].includes(s.kategori)
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
        <div class="hist-title">${dis?.name || '?'}</div>
        <div class="hist-sub">${fmtTarih(c.start_date)} · <b style="color:${isActive ? 'var(--red)' : 'var(--green)'}">${isActive ? 'Aktif' : 'Kapalı'}</b></div>
        ${c.notes ? `<div class="hist-sub" style="margin-top:2px">${c.notes}</div>` : ''}
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
    cdHayvan.style.cursor='pointer';
    cdHayvan.onclick=()=>{ closeM('m-case-det'); openDet(hayvan.id); };
  } else {
    cdHayvan.style.cursor='';
    cdHayvan.onclick=null;
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
  const islemler = await idbGetAll('islem_log');
  const vakaIslem = islemler.find(l => l.tip === 'VAKA_ACILDI' && l.ref_id === caseId);
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
  await pullTables(['treatment_days','drug_administrations']).catch(()=>{});
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
  el.innerHTML = '<span style="color:var(--ink3);font-size:.78rem">Yükleniyor…</span>';
  try {
    const [allDays, allAdmins, allProducts, allStok] = await Promise.all([
      idbGetAll('treatment_days'),
      idbGetAll('drug_administrations'),
      idbGetAll('drug_products'),
      idbGetAll('stok')
    ]);
    const days = allDays.filter(d => d.case_id === caseId).sort((a,b) => (a.treatment_date||'').localeCompare(b.treatment_date||''));
    const prodMap = {}; allProducts.forEach(p => { prodMap[p.id] = p; });
    const stokMap = {}; allStok.forEach(s => { stokMap[s.id] = s; });
    const data = [];
    days.forEach(td => {
      const dayAdmins = allAdmins.filter(da => da.treatment_day_id === td.id);
      const doneFields = { tamamlandi: td.tamamlandi, tamamlanma_tarihi: td.tamamlanma_tarihi, tamamlanma_notu: td.tamamlanma_notu, notes: td.notes };
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
    if (!data.length) {
      el.innerHTML = '<span style="color:var(--ink3);font-size:.78rem">Henüz tedavi günü yok</span>';
      return;
    }
    const byDay = {};
    data.forEach(r => {
      if (!byDay[r.day_id]) byDay[r.day_id] = { day_no: r.day_no, date: r.treatment_date, day_id: r.day_id, time: r.treatment_time || '', drugs: [], tamamlandi: r.tamamlandi, tamamlanma_tarihi: r.tamamlanma_tarihi, tamamlanma_notu: r.tamamlanma_notu, notes: r.notes };
      if (r.administration_id) byDay[r.day_id].drugs.push(r);
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

  el.innerHTML = progressHtml + '<div class="cd-tl-wrap">' +
    sortedDays.map(day => {
      const saatStr  = day.time ? `<span style="font-size:.68rem;color:var(--ink3);font-weight:400;margin-left:4px">${day.time.slice(0,5)}</span>` : '';
      const isDone   = day.tamamlandi;
      const isLocked = !isDone && day._locked;
      const tlCls    = isDone ? 'tl-done' : isLocked ? 'tl-locked' : 'tl-active';
      const openAttr = (aktif && !isDone && day === sortedDays.find(d => !d.tamamlandi)) ? 'open' : '';
      const nodeIcon = isDone ? '✓' : '';
      const gunNo    = `Gün ${tarihGunNo[day.day_id]||day.day_no}${tarihSuffix[day.day_id]||''}`;

      // Başlık sağ taraf
      const badge = isDone
        ? `<span style="background:rgba(78,154,42,.12);color:var(--green);padding:2px 8px;border-radius:6px;font-size:.68rem;font-weight:700">✅ ${fmtGunSaat(day.tamamlanma_tarihi)}</span>`
        : isLocked
          ? `<span style="color:var(--ink3);font-size:.72rem">🔒</span>`
          : '';

      // Not satırı (treatment_days.notes)
      const notHtml = day.notes
        ? `<div class="cd-day-not">📝 ${esc(day.notes)}</div>`
        : '';

      // İlaç listesi
      const drugHtml = day.drugs.length
        ? `<div style="margin-top:2px">${day.drugs.map(d => `
            <div class="cd-drug-row">
              <div><span class="cd-drug-name">${esc(d.drug)}</span> <span class="cd-drug-meta">${d.dose} ${d.unit}${d.route?' · '+d.route:''}</span></div>
              ${aktif && !isDone ? `<div style="display:flex;gap:2px">
                <button onclick="caseDrugDuzenle('${d.administration_id}','${d.dose}','${d.unit}','${d.route||''}')" style="background:none;border:none;color:var(--blue);cursor:pointer;font-size:.85rem;padding:2px">✏️</button>
                <button onclick="caseDrugSil('${d.administration_id}')" style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.85rem;padding:2px">🗑</button>
              </div>` : ''}
            </div>`).join('')}</div>`
        : `<span style="color:var(--ink3);font-size:.75rem;display:block;padding:4px 0">İlaç eklenmemiş</span>`;

      // Eylem çubuğu — lock'tan bağımsız planlama + ikincil eylemler tek satırda
      const actionsHtml = aktif && !isDone ? `
        <div style="display:flex;gap:4px;flex-wrap:wrap;margin-top:8px;padding-top:8px;border-top:1px solid var(--card3);align-items:center">
          ${!isLocked ? `<button onclick="caseDayTamamla('${day.day_id}')" style="flex:1;min-width:80px;background:var(--green);color:#fff;border:none;border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:700">✅ Tamamla</button>` : ''}
          <button onclick="caseDrugFormAc('${day.day_id}')" style="flex:1;min-width:72px;background:var(--blue);color:#fff;border:none;border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer;font-weight:600">+ İlaç</button>
          <button onclick="caseDayNotAcById('${day.day_id}')" style="flex:1;min-width:64px;background:var(--card2);color:var(--ink2);border:1px solid var(--card3);border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer">📝 Not</button>
          <button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" style="background:none;border:1px solid var(--card3);border-radius:7px;padding:8px 10px;font-size:.74rem;color:var(--ink3);cursor:pointer" title="Saat ekle">🕐</button>
          <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.06);color:var(--red);border:1px solid rgba(192,50,26,.15);border-radius:7px;padding:8px 10px;font-size:.74rem;cursor:pointer" title="Günü sil">🗑</button>
        </div>
        ${isLocked ? '<div style="margin-top:4px;font-size:.68rem;color:var(--ink3);padding:0 2px">⏳ Önceki gün tamamlanmadan bu gün tamamlanamaz</div>' : ''}` : '';

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
                  ${badge}
                  <span class="cd-acc-arrow">▸</span>
                </div>
              </div>
              <div class="cd-acc-body" id="drugs-${day.day_id}">
                <div class="cd-acc-body-inner" data-not-b64="${notB64}">
                  ${notHtml}
                  ${drugHtml}
                  ${actionsHtml}
                </div>
              </div>
            </div>
          </div>
        </div>`;
    }).join('') + '</div>';
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
    // İlgili TEDAVI_GUN gorev_log kaydını da tamamla
    const allGorevler = await idbGetAll('gorev_log');
    const tedaviGorev = allGorevler.find(g => {
      if (g.gorev_tipi !== 'TEDAVI_GUN' || g.tamamlandi) return false;
      try { return JSON.parse(g.aciklama||'{}').day_id === dayId; } catch(e) { return false; }
    });
    if (tedaviGorev) await rpc('gorev_tamamla', { p_gorev_id: tedaviGorev.id }).catch(()=>{});
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
  const kapatBolum = document.getElementById('cd-kapat-bolum');
  if (!kapatBolum) return;
  const allDays = await idbGetAll('treatment_days');
  const caseDays = allDays.filter(d => d.case_id === caseId);
  const hepsiDone = caseDays.length === 0 || caseDays.every(d => d.tamamlandi);
  const btn = kapatBolum.querySelector('button');
  if (!btn) return;
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
  const bugun = new Date().toISOString().split('T')[0];

  let kareler = '';
  for (let i = 0; i < bosluk; i++) kareler += '<div></div>';
  for (let g = 1; g <= sonGun; g++) {
    const iso = yil + '-' + String(ay+1).padStart(2,'0') + '-' + String(g).padStart(2,'0');
    const secili = _gunSecimSecili.has(iso);
    const bugunMu = iso === bugun;
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



let _activeDayId = null;
function caseDrugFormAc(dayId) {
  _activeDayId = dayId;
  document.querySelectorAll('.cd-drug-form').forEach(f => f.remove());
  const container = document.getElementById('drugs-' + dayId);
  if (!container) return;

  const cache = _drugsCache || [];
  const groups = {};
  [...cache].sort((a,b) => a.name.localeCompare(b.name,'tr')).forEach(d => {
    const g = d.group_name || 'Diger';
    if (!groups[g]) groups[g] = [];
    groups[g].push(d);
  });

  const groupHtml = Object.keys(groups).sort().map(grp => {
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
    '<button onclick="this.closest(\'.cd-drug-form\').remove()" style="background:var(--card3);border:none;border-radius:7px;padding:9px;cursor:pointer">Iptal</button>'+
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
    await pullTables(['stok','stok_hareket','drug_administrations','treatment_days','cases']);
    await loadDrugsCache();
    await renderCaseTimeline(_curCase.id);
    const _sp = document.getElementById('stok-panel');
    if (_sp && _sp.style.transform !== 'translateX(100%)') loadStokPanel();
  } catch(e) { toast(e.message, true); }
}

function caseDrugDuzenle(adminId, dose, unit, route) {
  // Inline edit — satiri bul ve form ac
  const satirlar = document.querySelectorAll('[data-admin-id]');
  document.querySelectorAll('.drug-edit-form').forEach(f => f.remove());
  // Admin satırının parent div'ini bul
  const btn = document.querySelector(`button[onclick*="${adminId}"][onclick*="caseDrugDuzenle"]`);
  if (!btn) return;
  const row = btn.closest('div[style*="border-bottom"]');
  if (!row) return;
  const form = document.createElement('div');
  form.className = 'drug-edit-form';
  form.style.cssText = 'background:rgba(42,107,181,.06);border:1px solid rgba(42,107,181,.2);border-radius:8px;padding:8px;margin-top:4px';
  form.innerHTML =
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:6px">' +
    '<input id="ded-dose" type="number" min="0.01" step="0.01" value="'+dose+'" class="fi" style="margin:0" placeholder="Doz">' +
    '<input id="ded-unit" type="text" value="'+unit+'" class="fi" style="margin:0" placeholder="Birim">' +
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
    '<button onclick="caseDrugDuzenleKaydet(\''+adminId+'\')" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:7px;font-weight:700;cursor:pointer">Kaydet</button>' +
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
  const filtered=q?_hdiIlacCache.filter(s=>s.urun_adi.toLowerCase().includes(q)):_hdiIlacCache.slice(0,12);
  if(!filtered.length){ ac.style.display='none'; return; }
  ac.innerHTML=filtered.map(s=>`<div onclick="hdiStokSec('${s.id}','${s.urun_adi.replace(/'/g,"\'")}','${s.birim||''}')"
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
    td2Hayvan.style.cursor='pointer';
    td2Hayvan.onclick=()=>{ closeM('m-toh-det'); openDet(hayvanObj.id); };
  } else {
    td2Hayvan.style.cursor='';
    td2Hayvan.onclick=null;
  }
  document.getElementById('td2-sperma').textContent=`💉 ${t.sperma||'?'}`;
  const _tohGebe=t.sonuc==='Gebe';
  const _scMidToh=t.sonuc==='Boş'?'var(--red)':'var(--amber)';
  const sc=_tohGebe?'var(--green)':_scMidToh;
  const chips=[
    `<span style="background:rgba(0,0,0,.06);padding:3px 9px;border-radius:10px;font-size:.7rem;font-weight:700;color:${sc}">${t.sonuc||'Bekliyor'}</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">${t.deneme_no||1}. deneme</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">📅 ${fmtTarih(t.tarih)}</span>`,
    hk?`<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">👨‍⚕️ ${hk.ad}</span>`:'',
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

  // Son tohumlama kontrolü (event stack kuralı)
  const tumTohlar=await idbGetAll('tohumlama');
  const hayvanTohlar=tumTohlar
    .filter(t2=>t2.hayvan_id===t.hayvan_id)
    .sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''));
  const isSonToh=hayvanTohlar.length>0&&hayvanTohlar[0].id===id;

  const td2GeriAlBtn=document.getElementById('td2-geri-al-btn');
  if(td2GeriAlBtn){
    td2GeriAlBtn.style.display=(isSonToh&&islemKayit)?'block':'none';
    if(isSonToh&&islemKayit){
      td2GeriAlBtn.onclick=()=>openGeriAl(islemKayit.id,`${hayvanLabel} — ${t.sperma||'?'} (${fmtTarih(t.tarih)})`);
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
    if(t.sonuc!=='Gebe'&&t.sonuc!=='Doğum Yaptı'){ td2TekrarBtn.style.display='block'; td2TekrarBtn.onclick=()=>tekrarTohumla(hayvanLabel||t.hayvan_id); }
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
            <span style="color:var(--ink3)">· ${d.sperma||'?'}</span>
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
    return `<div onclick="selSperma('${s.replace(/'/g,"\\'")}');event.stopPropagation()" style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid var(--card3);display:flex;justify-content:space-between;align-items:center">
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
    const _stokColorMid=s.guncel<=5?'var(--amber)':'var(--green)';
    const _stokColor=warn?'var(--red)':_stokColorMid;
    return `<div onclick="selIlac('${s.id}','${s.urun_adi.replace(/"/g,'&quot;').replace(/'/g,"\\'")}','${s.birim||'ml'}',${s.guncel});event.stopPropagation()"
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
  const q=(inp.value||'').toLowerCase().trim();
  const ac=inp.closest('.ilac-satir').querySelector('.ilac-ac');
  const stoklar=getState('stock').filter(s=>s.kategori!=='Sperma'&&!(s.urun_adi||'').toLowerCase().includes('sperma'));
  const filtered=q?stoklar.filter(s=>(s.urun_adi||'').toLowerCase().includes(q)):stoklar.slice(0,8);
  if(!filtered.length){ac.style.display='none';return;}
  ac.innerHTML=filtered.map(s=>`<div onclick="selDilacSatir(this,'${s.id}','${s.urun_adi.replace(/"/g,'&quot;').replace(/'/g,"\\'")}','${s.birim||''}')" style="padding:8px 10px;cursor:pointer;font-size:.82rem;border-bottom:1px solid var(--card3)">${esc(s.urun_adi)} <span style="color:#aaa;font-size:.65rem">${s.guncel||0} ${s.birim||''}</span></div>`).join('');
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
  const q=(inp?.value||'').toLowerCase().trim();
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
  const filtered=q
    ?src.filter(a=>(a.kupe_no||'').toLowerCase().includes(q)||(a.devlet_kupe||'').toLowerCase().includes(q)||(a.id||'').toLowerCase().includes(q)).slice(0,12)
    :src.slice(0,10);
  if(!filtered.length){
    ac.innerHTML='<div style="padding:9px 12px;font-size:.78rem;color:var(--red)">⚠️ Sürüde eşleşen hayvan bulunamadı</div>';
    ac.style.display='block'; return;
  }
  ac.innerHTML=filtered.map(a=>{
    const kupe=a.kupe_no||a.devlet_kupe||a.id;
    return `<div onclick="selHayvan('${inputId}','${listId}','${kupe}')" style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid var(--card3);display:flex;justify-content:space-between">
      <span style="font-weight:600">${kupe}</span>
      <span style="color:var(--ink3);font-size:.7rem">${a.irk||''} · ${a.padok||''}</span>
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
    const today=new Date().toISOString().split('T')[0];
    const gun=Math.floor((new Date(today)-new Date(bekliyor.tarih))/86400000);
    if(gun>=0&&gun<=15){ _openInsemIntercept(hayvan,bekliyor); return; }
  }
  openMWithHayvan('m-insem','i-hid',kupeNo);
}

function _openInsemIntercept(hayvan,bekliyor){
  const today=new Date().toISOString().split('T')[0];
  const gun=Math.floor((new Date(today)-new Date(bekliyor.tarih))/86400000);
  const hid=hayvan.kupe_no||hayvan.devlet_kupe||hayvan.id;
  const infoEl=document.getElementById('insem-intercept-info');
  if(infoEl) infoEl.innerHTML=`<b>${hid}</b> — ${bekliyor.sperma||'?'} · <b>${gun}. gün</b> (${(bekliyor.tarih||'').slice(0,10)})`;
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
    const { error } = await rpc('tohumlama_sonuc_gebe', { p_tohumlama_id: son.id }); if (error) throw error; toast('✅ Gebe işaretlendi');
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
          <div style="flex:1;font-size:.78rem;font-weight:600;color:var(--ink);min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${d.name}">${d.name}</div>
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
    
    const rpcName = op.method === 'POST' ? rpcInfo.POST : rpcInfo.PATCH;
    if(!rpcName) throw new Error(`${op.method} için RPC tanımlı değil`);
    
    // Veriyi temizle (null/undefined/boş string'leri çıkar)
    const clean = op.method === 'POST'
      ? op.data.map(item => Object.fromEntries(Object.entries(item).filter(([k,v]) => v !== null && v !== undefined && v !== '')))
      : Object.fromEntries(Object.entries(op.data[0]).filter(([k,v]) => v !== null && v !== undefined && v !== ''));
    
    // RPC parametrelerini hazırla
    const rpcParams = buildRpcParams(rpcName, clean, op);
    
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

// RPC parametre builder — her RPC için doğru parametre yapısını oluştur
function buildRpcParams(rpcName, data, op) {
  switch(rpcName) {
    case 'hayvan_ekle':
      return {
        p_kupe_no: data.kupe_no,
        p_grup_id: data.grup_id,
        p_dogum_tarihi: data.dogum_tarihi,
        p_cinsiyet: data.cinsiyet,
        p_irk_id: data.irk_id
      };
    case 'hayvan_guncelle': {
      // PATCH için: hangi alan güncellenecek?
      const [col, val] = op.filter.split('=eq.');
      return {
        p_id: data[col] || val,
        p_alan: Object.keys(data)[0],
        p_deger: Object.values(data)[0]
      };
    }
    case 'tohumlama_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih: data.tarih,
        p_sperma_kodu: data.sperma_kodu,
        p_teknisyen: data.teknisyen
      };
    case 'tohumlama_tekrar_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih:     data.tarih,
        p_sperma:    data.sperma,
        p_hekim_id:  data.hekim_id || null,
      };
    case 'dogum_kaydet':
      return {
        p_anne_id: data.anne_id,
        p_tarih: data.tarih,
        p_buzagi_cinsiyet: data.buzagi_cinsiyet,
        p_buzagi_kupe: data.buzagi_kupe
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
      return {
        p_hayvan_id: data.hayvan_id,
        p_tanis: data.tanis,
        p_tarih: data.tarih
      };
    case 'add_drug_administration':
      return {
        p_day_id: data.day_id,
        p_drug_product_id: data.drug_product_id,
        p_dose: data.dose,
        p_unit: data.unit,
        p_route: data.route,
        p_time: data.time
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
      return { p_gorev_id: data.id, p_padok_hedef: data.padok || null };
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
        <div style="font-size:.8rem;color:var(--ink)">${vac.name}${vac.is_mandatory?' <span style="font-size:.6rem;color:var(--red)">Zorunlu</span>':''}</div>
        <div style="font-size:.65rem;color:var(--ink3)">${vac.disease_target||'—'} · ${vac.dose||'?'} ${vac.unit||''}</div>
      </div>
      <select onchange="vaccineRapelGuncelle('${vac.id}',this.value)" style="padding:3px 5px;border:1px solid var(--brd);border-radius:6px;font-size:.7rem;min-width:80px">${opts}</select>
    </div>`;
  }).join('')+'</div>';
}

async function vaccineRapelGuncelle(vaccineId,val){
  const days=val===''?null:parseInt(val);
  const{error}=await rpc('vaccine_rapel_guncelle',{p_vaccine_id:vaccineId,p_repeat_days:days});
  if(error){toast('Hata: '+error.message,true);return;}
  await pullTables(['vaccines']);
  toast('Rapel süresi güncellendi');
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
async function ayarlarHekimKaydet(){
  const ad=v('ay-hek-ad').trim(); if(!ad) return;
  const tel=v('ay-hek-tel')||null;
  const{error}=await rpc('hekim_ekle',{p_ad:ad,p_telefon:tel});
  if(error){ toast('Hata: '+error.message,true); return; }
  await pullTables(['hekimler']);
  await loadHekimlerFromDB();
  populateHekimSelects();
  cl('ay-hek-ad');
  document.getElementById('ay-hekim-form').style.display='none';
  renderAyarlarHekimList();
  toast(`✅ ${ad} eklendi`);
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
  const cutoff = _hekimPeriodDays === 'all' ? null : new Date(Date.now() - _hekimPeriodDays * 86400000).toISOString().split('T')[0];
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
  const { error } = await rpc('hekim_guncelle',{p_hekim_id:_curHekimDet.id,p_ad:ad,p_telefon:tel});
  if (error) { toast('Hata: ' + error.message, true); return; }
  await pullTables(['hekimler']);
  await loadHekimlerFromDB();
  populateHekimSelects();
  closeM('m-hekim-det');
  renderAyarlarHekimList();
  toast('Hekim güncellendi');
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

function ayarlarSpermaEkle(){ document.getElementById('ay-sperma-form').style.display='block'; }
async function ayarlarSpermaKaydet(){
  const kod=v('ay-sp-kod').trim(); if(!kod) return;
  // Stok tablosuna Sperma kategorisinde ekle (RPC)
  const{error}=await rpc('stok_ekle',{p_urun_adi:kod,p_kategori:'Sperma',p_birim:'doz',p_baslangic_miktar:0,p_esik:0});
  if(error){ toast('Hata: '+error.message,true); return; }
  await pullTables(['stok']);
  cl('ay-sp-kod');
  document.getElementById('ay-sperma-form').style.display='none';
  renderAyarlarSpermaList();
  buildSpermaList();
  toast(`✅ ${kod} eklendi`);
}
async function renderAyarlarSpermaList(){
  const el=document.getElementById('ay-sperma-list'); if(!el) return;
  const stoklar=await getData('stok');
  const spermalar=stoklar.filter(s=>s.kategori==='Sperma');
  if(!spermalar.length){ el.innerHTML='<div style="font-size:.75rem;color:var(--ink3)">Henüz sperma eklenmedi</div>'; return; }
  el.innerHTML=spermalar.map(s=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.8rem;color:var(--ink)">${esc(s.urun_adi)}</span>
    <button onclick="spermaSil('${s.id}')" style="background:none;border:none;color:var(--red);font-size:.75rem;cursor:pointer">Sil</button>
  </div>`).join('');
}
async function spermaSil(stokId){
  const res=await rpc('sperma_sil',{p_stok_id:stokId});
  if(!res.ok){ toast(res.mesaj||'Silinemedi',true); return; }
  await pullTables(['stok','stok_hareket']);
  renderAyarlarSpermaList();
  buildSpermaList();
  toast('Sperma silindi');
}

// ── PADOK CRUD ──────────────────────────────
async function renderAyarlarPadokList(){
  const el=document.getElementById('ay-padok-list'); if(!el) return;
  const padoklar=await getData('padoklar');
  if(!padoklar.length){ el.innerHTML='<div style="font-size:.75rem;color:var(--ink3)">Henüz padok tanımlı değil</div>'; return; }
  el.innerHTML=padoklar.map(p=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.82rem;color:var(--ink)">${p.ad}${p.kapasite?' <span style="font-size:.65rem;color:var(--ink3)">(${p.kapasite} baş)</span>':''}</span>
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
  const{error}=await rpc('padok_guncelle',{p_padok_id:_curPadokDet.id,p_ad:ad,p_kapasite:kap,p_sira:null});
  if(error){ toast('Hata: '+error.message,true); return; }
  await pullTables(['padoklar']);
  await loadPadokConfig();
  closeM('m-padok-det');
  renderAyarlarPadokList();
  renderGrupPadokEslem();
  toast('Padok güncellendi');
}

async function padokSilOnay(){
  if(!_curPadokDet) return;
  const id=_curPadokDet.id;
  const hayvanlar=await getData('hayvanlar');
  const count=hayvanlar.filter(h=>h.padok_id===id&&h.durum==='Aktif').length;
  if(count>0){ toast(`Bu padokta ${count} aktif hayvan var — önce hayvanları başka padoğa taşıyın`,true); return; }
  openConfirm('Padok Sil',`"${_curPadokDet.ad}" silinecek. Emin misiniz?`,async()=>{
    const{error}=await rpc('padok_sil',{p_padok_id:id});
    if(error){ toast('Hata: '+error.message,true); return; }
    await pullTables(['padoklar','grup_padok_eslem']);
    await loadPadokConfig();
    closeM('m-padok-det');
    renderAyarlarPadokList();
    renderGrupPadokEslem();
    toast('Padok silindi');
  });
}

// ── Padok Detay + Transfer Functions ──

let _pdHayvanIds = []; // selected hayvan IDs for bulk transfer
let _pdTransferHayvanIds = []; // hayvan IDs pending transfer
let _pdKaynakPadokId = null; // source padok for transfer

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
        <span style="flex:1;font-weight:600;color:var(--ink);font-size:.8rem">${h.kupe_no || h.devlet_kupe || h.id}</span>
        <span style="font-size:.7rem;color:var(--ink3)">${h.grup || '—'} · ${h.cinsiyet || '—'} · ${yas}</span>
        <button class="btn" style="padding:3px 8px;font-size:.7rem;background:rgba(42,107,181,.1);color:var(--blue);border:1px solid rgba(42,107,181,.2)" onclick="padokTekliTasi('${h.id}','${h.kupe_no || h.devlet_kupe || h.id}')">➡️</button>
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
  _pdTransferHayvanIds = [..._pdHayvanIds];
  document.getElementById('pt-bilgi').textContent = `📦 ${_pdHayvanIds.length} hayvan → hedef padok seçin:`;
  _pdTransferAcSelector();
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
        toast(`✅ ${res.basarili} hayvan ${res.yeni_padok} taşındı${res.basarisiz > 0 ? `, ${res.basarisiz} başarısız` : ''}`);
      } else {
        toast(`⚠️ ${res?.error || 'Toplu işlem başarısız'}`, true);
      }
    }
    // Refresh
    _pdHayvanIds = [];
    document.getElementById('pd-toplu-tasi-btn').style.display = 'none';
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
        <input type="checkbox" value="${p.id}" ${secili.has(p.id)?'checked':''} onchange="grupPadokCheckbox('${g}',this)">
        ${p.ad}
      </label>`).join('');
    return `<div style="padding:6px 0;border-bottom:1px solid var(--card2)">
      <div style="font-size:.75rem;font-weight:700;color:var(--ink);margin-bottom:4px">${g}</div>
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
  const{error}=await rpc('padok_ekle',{p_ad:ad,p_kapasite:kap,p_sira:0});
  if(error){ toast('Hata: '+error.message,true); return; }
  await pullTables(['padoklar']);
  await loadPadokConfig();
  cl('ay-padok-ad'); cl('ay-padok-kap');
  document.getElementById('ay-padok-form').style.display='none';
  renderAyarlarPadokList();
  toast('✅ Padok eklendi');
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
      const hayvan=getState('animals').find(a=>a.id===g2.hayvan_id);
      const kupe=hayvan?(hayvan.kupe_no||hayvan.devlet_kupe):'Genel';
      new Notification(`⏰ 3 saat sonra: ${kupe}`,{body:g2.aciklama||'',tag:key});
      gosterilen[key]=simdi;
    }
    const sabahKey=`${g2.id}_sabah`;
    if(g2.hedef_tarih===bugun&&fark>=-0.5&&fark<=0.5&&!gosterilen[sabahKey]){
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
  q = (q||'').toLowerCase().trim();
  // Filtre: data-ad attribute ile case-insensitive match
  const rows = document.querySelectorAll('#stok-panel-body .stok-item');
  let visible = 0;
  rows.forEach(row => {
    const ad = (row.dataset.ad || '').toLowerCase();
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