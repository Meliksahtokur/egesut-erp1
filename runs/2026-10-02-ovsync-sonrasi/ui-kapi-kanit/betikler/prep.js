const L=require('./lib'),F=require('./fx');
(async()=>{ const db=await L.db(); console.log('temizle önce',await F.temizle(db));
 const r={}; r.a=await F.kur(db,'a',{takip:true,tohSonuc:'Bekliyor'}); r.b=await F.kur(db,'b',{takip:true,tohSonuc:'Gebe'});
 r.c=await F.kur(db,'c',{takip:true,tohSonuc:'Boş'});
 const {error}=await db.from('stok').insert({id:'UIK-STOK',urun_adi:'UIK Prostag',birim:'ml',baslangic_miktar:10,kategori:'Diğer İlaç'}); if(error) console.log('stok insert HATA',error.message);
 r.d=await F.kur(db,'d',{takip:false,tohSonuc:'Bekliyor'}); // T9 takipsiz
 console.log(JSON.stringify(r)); })().catch(e=>{console.log('ERR',e.message);process.exit(1)});
