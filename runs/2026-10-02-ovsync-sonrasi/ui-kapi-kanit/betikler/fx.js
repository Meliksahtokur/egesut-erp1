const L=require('./lib');
const M='UIK-';
const trGun=n=>new Date(Date.now()+3*3600e3+n*864e5).toISOString().slice(0,10);
const hid=n=>`a1c00000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const NO={a:1,b:2,c:3,d:4,e:5,f:6,s:7};
async function kur(db,ad,{toh=null,tohGun=0,takip=false,tohSonuc='Bekliyor',gorevTip='TAKIP_MUAYENE',gorevGun=7,saat='09:00:00'}={}){
  const id=hid(NO[ad]); const kupe=M+ad;
  // önce eski
  for(const t of ['gorev_log','tohumlama','uygulama_log']) { const {error}=await db.from(t).delete().eq('hayvan_id',id); if(error) throw new Error(t+' sil: '+error.message); }
  const {data:g}=await db.from('hayvanlar').select('id,durum').eq('id',id);
  if(g?.length){ await db.from('hayvanlar').update({durum:'Aktif'}).eq('id',id); }
  else { const {error}=await db.from('hayvanlar').insert({id,kupe_no:kupe,cinsiyet:'Dişi',durum:'Aktif',dogum_tarihi:trGun(-500),grup:'Sağmal (Laktasyonda)'}); if(error) throw new Error('hayvan: '+error.message); }
  let tid=null;
  if(toh!==false){ tid=hid(100+NO[ad]); const {error}=await db.from('tohumlama').insert({id:tid,hayvan_id:id,tarih:trGun(tohGun),sonuc:tohSonuc,deneme_sayisi:1,denemeler:[]}); if(error) throw new Error('toh: '+error.message); }
  let gid=null;
  if(takip){ gid=hid(200+NO[ad]); const {error}=await db.from('gorev_log').insert({id:gid,hayvan_id:id,gorev_tipi:gorevTip,aciklama:M+ad,hedef_tarih:trGun(gorevGun),hedef_saat:saat,tamamlandi:false,iptal:false,kaynak:'TAKIP:'+(tid||'UIK')}); if(error) throw new Error('gorev: '+error.message); }
  return {id,kupe,tid,gid};
}
async function temizle(db){
  const {data:h}=await db.from('hayvanlar').select('id').like('kupe_no',M+'%'); const ids=(h||[]).map(x=>x.id); const out=[];
  if(ids.length){
   const {data:cs}=await db.from('cases').select('id').in('animal_id',ids); const cid=(cs||[]).map(c=>c.id);
   if(cid.length){ await db.from('treatment_day_uygulamalar').delete().in('case_id',cid); await db.from('treatment_days').delete().in('case_id',cid); }
   for(const t of ['protokol_instance','kizginlik_log','uygulama_log','gorev_log','tohumlama']){ const {error}=await db.from(t).delete().in('hayvan_id',ids); if(error) out.push(t+': '+error.message); }
   if(cid.length) await db.from('cases').delete().in('id',cid);
   for(const id of ids){ const {error}=await db.from('hayvanlar').delete().eq('id',id); if(error){ if(error.code==='23503'){ const r=await db.from('hayvanlar').update({durum:'Satildi'}).eq('id',id); if(r.error) out.push('satildi '+r.error.message);} else out.push('sil '+error.message);} }
  }
  await db.from('stok').delete().like('id','UIK-%');
  return out;
}
module.exports={kur,temizle,M,trGun};
