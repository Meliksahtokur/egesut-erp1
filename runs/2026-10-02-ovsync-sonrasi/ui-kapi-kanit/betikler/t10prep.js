const L=require('./lib'),F=require('./fx');
(async()=>{ const db=await L.db(); const ad=process.argv[2];
 const r=await F.kur(db,ad,{toh:false,takip:true,gorevTip:'OVSYNC_BASLAT',gorevGun:0,saat:'08:00:00'});
 // kaynak ILK-TOH-DUVE
 await db.from('gorev_log').update({kaynak:'ILK-TOH-DUVE-UIK'+ad}).eq('id',r.gid);
 const {data,error}=await db.rpc('start_first_service_protocol',{p_gorev_id:r.gid});
 console.log('start',JSON.stringify(data),error&&error.message);
 const {data:cs}=await db.from('cases').select('id,status,protocol_family,start_date').eq('animal_id',r.id); console.log('cases',JSON.stringify(cs));
 const {data:g}=await db.from('gorev_log').select('id,gorev_tipi,hedef_tarih,hedef_saat,kaynak,tamamlandi,iptal').eq('hayvan_id',r.id); console.log('gorevler',JSON.stringify(g,null,0));
 const {data:td}=await db.from('treatment_days').select('day_no,treatment_date,tamamlandi').in('case_id',(cs||[]).map(c=>c.id)).order('day_no'); console.log('days',JSON.stringify(td));
})().catch(e=>{console.log('ERR',e.message);process.exit(1)});
