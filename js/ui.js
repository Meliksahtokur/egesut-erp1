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
   openDB, syncNow, updateSyncBar,
   _gmEntriesFromSources, _gmCap, _gmGroup, _gmGroupHtml, _gmSearch,
   _gmTodayKey, _gmUndoButtonHtml, _gmDownloadCsv,
   _gmGunEntriesFromSources, _gmGroupLabel, olayGunu
*/

let _taskKategori='all';
let _stokTab='tumu';
let _curStokDet=null;
let _prevTaskId=null;

/**
 * Verilen elemanın üstündeki, dikey taşma (overflowY) özelliği 'auto' veya 'scroll' olan ilk ebeveyn elemanı arar.
 * @param {HTMLElement} el Arama işlemi için başlangıç elemanı.
 * @returns {HTMLElement|null} Bulunan taşma özelliğine sahip eleman veya bulunamazsa null.
 */
function _findScroller(el){
  let n=el?.parentElement;
  while(n&&n!==document.body){
    const s=getComputedStyle(n).overflowY;
    if(s==='auto'||s==='scroll') return n;
    n=n.parentElement;
  }
  return null;
}
/**
 * Bir zaman uyumsuz işlem sırasında içeriğin kaydırma konumunu korur; işlem bitince özgün kaydırma konumunu geri yükler.
 * @param {HTMLElement} contentEl - Kaydırma konumu korunacak içerik öğesi.
 * @param {Function} fn - Yürütülecek zaman uyumsuz işlem.
 * @returns {Promise<void>} İşlemin tamamlanmasını belirten promise.
 */
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
  ureme:  ['TOHUMLAMA_PLANLI','OVSYNC_BASLAT'],   // P3: Ovsync/PG görev tipleri 'Diğer'e düşmesin
  bakim:  ['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP','BESLEME','BUZAGI_BAKIM'],
  diger:  null // özel mantık: _katTipMap'te olmayan tüm tipler
};
const _allKatTips=Object.values(_katTipMap).filter(Boolean).flat();
const _planliUremeTipler=['OVSYNC_BASLAT','TOHUMLAMA_PLANLI'];   // K7: planlı üreme görevleri Bugün'de 7-gün pencereyle (ASI_PLANLI örneği)
// C3 (cila2): üreme-vaka kümesi hastalık KATEGORİSİ değil PROTOKOL AİLESİ bazlıdır.
// K7'nin category='Üreme' ayrımı Metrit/Endometrit gibi tedavi vakalarının
// seanslarını Üreme filtresine sızdırıyordu (BUG-UREME-FILTRE-SIZINTI).
// protocol_family='OVSYNC' damgası (K4, 20260925000013:144-147) yalnız başlamış
// ovsync zincirlerine yazılır — Metrit vb. NULL kalır, Tedavi'de listelenir.
/**
 * Verilen vaka listesinden protokol ailesi 'OVSYNC' olanları filtreleyip ID'lerini içeren bir küme döndürür.
 * @param {Array} cases Filtrelenmesi gereken vaka nesnelerinden oluşan dizi.
 * @returns {Set} 'OVSYNC' protokol ailesine sahip vakaların ID'lerinden oluşan küme.
 */
function _uremeVakaCaseIds(cases){
  return new Set((cases||[]).filter(c=>c&&c.protocol_family==='OVSYNC').map(c=>c.id));
}
/**
 * Verilen görev tipine göre üreme görevinin geçerli olup olmadığını kontrol eder.
 * Tedavi seansı veya tedavi günü görevleri için ilgili seans ve tedavi gün kayıtlarını kontrol ederek
 * üreme durumunun (case_id) üreme durumları listesinde var olup olmadığını doğrular.
 * @param {Object} t Görev nesnesi.
 * @param {Set} uremeCaseIdler Üreme durumlarının case_id'lerini içeren küme.
 * @param {Object} tdById Tedavi günlerini ID'ye göre içeren nesne.
 * @param {Object} seansById Seansları ID'ye göre içeren nesne.
 * @returns {boolean} Görevin geçerli ise true, değilse false döndürür.
 */
function _uremeGorevMi(t,uremeCaseIdler,tdById,seansById){
  if(!t) return false;
  if((_katTipMap.ureme||[]).includes(t.gorev_tipi)) return true;
  if(t.gorev_tipi==='TEDAVI_SEANS'){
    const s=seansById&&seansById[t.seans_admin_id];
    const td=s&&tdById&&tdById[s.treatment_day_id];
    return !!(td&&uremeCaseIdler&&uremeCaseIdler.has(td.case_id));
  }
  if(t.gorev_tipi==='TEDAVI_GUN'){
    let a={}; try{ a=JSON.parse(t.aciklama||'{}'); }catch(e){}
    const td=a.day_id&&tdById&&tdById[a.day_id];
    return !!(td&&uremeCaseIdler&&uremeCaseIdler.has(td.case_id));
  }
  return false;
}
/**
 * Verilen kategori tipine göre görev tipinin uygun olup olmadığını kontrol eder.
 * @param {Object} t Kontrol edilecek görev nesnesi.
 * @param {string} kat Filtreleme yapılacak kategori tipi ('all', 'diger', 'ureme', 'tedavi' vb.).
 * @param {Array} uremeCaseIdler Üreme görevlerini belirleyen case ID'leri listesi.
 * @param {Object} tdById Görev tanımları için ID bazlı eşleştirme objesi.
 * @param {Object} seansById Seans bilgileri için ID bazlı eşleştirme objesi.
 * @returns {boolean} Görevin belirtilen kategoriye uygunsa true, değilse false döndürür.
 */
function _kategoriFiltreUygun(t,kat,uremeCaseIdler,tdById,seansById){
  if(kat==='all') return true;
  if(kat==='diger') return !_allKatTips.includes(t.gorev_tipi);
  if(kat==='ureme') return _uremeGorevMi(t,uremeCaseIdler,tdById,seansById);
  if(kat==='tedavi') return (_katTipMap.tedavi||[]).includes(t.gorev_tipi)&&!_uremeGorevMi(t,uremeCaseIdler,tdById,seansById);
  return (_katTipMap[kat]||[]).includes(t.gorev_tipi);
}
/**
 * Bir görevin bugünün filtresine uygun olup olmadığını belirler: hedef tarihi bugün olan görevleri ya da planlı görev tiplerinden hedef tarihi bugünle gelecek 7 gün arasında olanları kabul eder.
 * @param {Object} t - Kontrol edilecek görev kaydı; hedef_tarih ve gorev_tipi alanlarını içerir.
 * @param {string} today - Bugünün tarihi (karşılaştırma için kullanılan biçimde).
 * @param {string} d7 - Bugünden 7 gün sonrasının tarihi.
 * @returns {boolean} Görev filtreye uygunsa true, aksi halde false.
 */
function _bugunFiltreUygun(t,today,d7){
  if(t.hedef_tarih===today) return true;
  const planli=t.gorev_tipi==='ASI_PLANLI'||t.gorev_tipi==='ILERI_GEBE_ASI'||_planliUremeTipler.includes(t.gorev_tipi);
  return planli&&t.hedef_tarih>today&&t.hedef_tarih<=d7;
}
/**
 * Belirtilen kategoriye ait görevleri yükler ve aktif kategori butonunu vurgular.
 * @param {string} kat Seçilecek kategori adı.
 * @param {HTMLElement} btn Aktif kategoriyi göstermek için tıklanan buton elemanı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function setTaskKat(kat,btn){
  _taskKategori=kat;
  document.querySelectorAll('.kat-btn').forEach(b=>b.classList.remove('on'));
  if(btn) btn.classList.add('on');
  loadTasks(_curTaskFilter||'today');
}

// ──────────────────────────────────────────
// YARDIMCI RENDER
// ──────────────────────────────────────────
/**
 * Verilen başlık ve içeriği, belirtilen CSS sınıfıyla birlikte HTML yapısı içeren bir div elementi döndürür.
 * @param {string} cls Başlık satırına eklenen CSS sınıf adı.
 * @param {string} title Div içindeki başlık metni.
 * @param {string} content Div içindeki içerik metni.
 * @returns {string} Başlık ve içeriği içeren HTML string'i.
 */
function band(cls,title,content){
  return `<div class="aband"><div class="aband-hdr ${cls}">${title}</div><div class="aband-body">${content}</div></div>`;
}
/**
 * Verilen doğum tarihine göre bugüne kadar geçen süreyi hesaplar.
 * @param {string} dogumTarihi Hesaplanacak kişinin doğum tarihi (string formatında).
 * @returns {string} Geçen süre (yıl, ay ve gün cinsinden) veya boş string (geçersiz tarih).
 */
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
/**
 * Belirtilen sekme ismine sahip elemanı aktif hale getirip diğerlerini pasif yapar.
 * @param {string} name Aktif edilecek sekmenin ID'si (tab-önceliği olmadan).
 * @param {HTMLElement} btn Aktif edilecek sekme butonu (isteğe bağlı).
 * @returns {void}
 */
function showTab(name,btn){
  document.querySelectorAll('.tab-pane').forEach(p=>p.classList.remove('on'));
  document.querySelectorAll('.tab').forEach(b=>b.classList.remove('on'));
  document.getElementById('tab-'+name).classList.add('on');
  if(btn) btn.classList.add('on');
}
/**
 * Belirtilen sekme adına sahip elemanı aktif hale getirip diğerlerini pasif yapar.
 * @param {string} name Aktif edilecek sekmenin adı.
 * @param {HTMLElement} btn Aktif edilecek sekme butonu (opsiyonel).
 * @returns {void}
 */
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
/**
 * Verilen hayvan listesinden, aynı anne_id ve dogum_tarihi'ne sahip olan ancak id'si farklı olan kardeş hayvanları filtreleyip döndürür.
 * @param {Array} animals Filtreleme yapılacak hayvan kayıtlarından oluşan dizi.
 * @param {Object} a Ana hayvan nesnesi (anne_id ve dogum_tarihi bilgisi içermeli).
 * @returns {Array} Ana hayvanın kardeşleri olan hayvan kayıtlarından oluşan dizi.
 */
function _kardeslerBul(animals,a){
  if(!a || !a.anne_id || !a.dogum_tarihi) return [];
  return (animals||[]).filter(x => x && x.id !== a.id && x.anne_id === a.anne_id && x.dogum_tarihi === a.dogum_tarihi);
}
// births = bu hayvanın kendi dogum satırları; son PENCERE gün içinde doğum varsa o satırı döner
/**
 * Verilen doğum kayıtları dizisinden, bugünden (pencereGun gün geriye) hesaplanan tarih sınırlamasına göre en son doğumu döndürür.
 * @param {Array} births Doğum kayıtlarını içeren dizi.
 * @param {string} bugunStr Bugünün tarih stringi (YYYY-MM-DD formatında).
 * @param {number} pencereGun Kontrol edilecek geçmiş gün sayısı (varsayılan 10).
 * @returns {Object|null} Tarih sınırlamasını sağlayan en son doğum kaydı veya yoksa null.
 */
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
/**
 * Anne kimliği (anne_id) alanı olan ve aynı anne_id'ye sahip birden fazla kayıt içeren doğum listesinden,
 * her anne kimliği için sadece ilk karşılaşılan kaydı alarak benzersiz kayıtları döndürür.
 * @param {Array} births Anne kimlikleri içeren doğum kayıtlarından oluşan dizi.
 * @returns {Array} Her anne kimliği için tek bir kayıt içeren dizi.
 */
function _dogumAnneBazliTekillestir(births){
  const m = new Map();
  for(const b of (births||[])){ if(b && b.anne_id && !m.has(b.anne_id)) m.set(b.anne_id, b); }
  return [...m.values()];
}
/**
 * Aktif hayvan sayısını, gebe hayvan sayısını, aktif hastalık sayısını, sütten kesilmesi gereken buzağı sayısını ve bekleyen görev sayısını içeren bir dashboard satırı HTML elemanı döndürür.
 * @param {Array} animals Aktif hayvan listesini temsil eden dizi.
 * @param {Array} gebeTohs Gebe hayvan listesini temsil eden dizi.
 * @param {Array} diseases Aktif hastalık kayıtlarını temsil eden dizi.
 * @param {Array} tasks Bekleyen görev listesini temsil eden dizi.
 * @param {number} badge Özel durum göstergesi (badge) için sayısal değer.
 * @returns {string} Dashboard istatistik satırını oluşturan HTML stringi.
 */
function _dashStatRow(animals,gebeTohs,diseases,tasks,badge){
  const _taskCls=tasks.length>0?'warn':'ok';
  // Sayaç = kesim vakti gelenler (suttenKesimeHazirSec) — modal rozet kümesiyle birebir aynı
  const sutBuzagiSayisi=suttenKesimeHazirSec(animals,(typeof suttenKesmeEsigi==='function')?suttenKesmeEsigi():60).length;
  return `<div class="dash-row">
    <div class="sc ok" onclick="goTo('suru')"><div class="sv">${animals.length}</div><div class="sl">Aktif Hayvan ›</div></div>
    <div class="sc ok" onclick="showGebe()"><div class="sv">${gebeTohs.length}</div><div class="sl">Gebe ›</div></div>
    <div class="sc ${diseases.length>0?'alert':'ok'}" onclick="showHasta()"><div class="sv">${diseases.length}</div><div class="sl">Aktif Hastalık ›</div></div>
    <div class="sc ${sutBuzagiSayisi>0?'warn':'ok'}" onclick="openSuttenKesModal()"><div class="sv">${sutBuzagiSayisi}</div><div class="sl">🍼 Sütten Kes ›</div></div>
    <div class="sc ${badge>0?'alert':_taskCls}" onclick="goTo('tasks')"><div class="sv">${tasks.length}</div><div class="sl">Bekleyen Görev ›</div></div>
  </div>`;
}
/**
 * Yaklaşan ve gecikmiş aşılara göre özet bir aşı uyarı bandı (HTML) oluşturur. Ertelenmiş kayıtları düşürür, her (hayvan, aşı) çifti için en güncel kaydı alır, varsa aktif hayvanlara filtreler, kalan gün sayısına göre kırmızı/amber/mavi öncelik belirler ve en fazla 5 satır ile kalan kayıt sayısını gösterir.
 * @param {string|Date} today Karşılaştırma için bugünün tarihi.
 * @param {Array} vaxLogs Aşı kayıtları listesi; animal_id, vaccine_id, vaccination_date, next_due_date ve ertelendi alanlarını içerir. Boş veya yoksa boş string döner.
 * @param {Array} vaccines Aşı tanım listesi; id ve name alanlarını içerir, aşı adını çözümlemek için kullanılır.
 * @param {Array} aktifIdler Sürüden çıkmamış (aktif) hayvan ID'leri; verilirse uyarılar yalnızca bu hayvanlara sınırlanır.
 * @returns {string} Öncelik rengine göre biçimlendirilmiş aşı uyarı bandı HTML'i; gösterilecek kayıt yoksa boş string.
 */
function _dashVacAlerts(today,vaxLogs,vaccines,aktifIdler){
  if(!vaxLogs||!vaxLogs.length) return '';
  // T3: hayvanı sürüden çıkmış aşı hatırlatmalarını düşür (param verilmişse)
  const _aktif=aktifIdler?new Set(aktifIdler):null;
  // Keep only latest non-dismissed entry per (animal_id, vaccine_id)
  const latestMap = {};
  vaxLogs
    .filter(v => !v.ertelendi)
    .sort((a, b) => (b.vaccination_date || '').localeCompare(a.vaccination_date || ''))
    .forEach(v => {
      const key = v.animal_id + '|' + v.vaccine_id;
      if (!latestMap[key]) latestMap[key] = v;
    });
  const withDue = Object.values(latestMap).filter(v => v.next_due_date&&(!_aktif||_aktif.has(v.animal_id)));
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

/**
 * Gebelik protokol kontrolü yaparak yeni görev oluşturulup oluşturulmadığını kontrol eder,
 * ilgili hayvan listesini günceller ve görev loglarını yükler.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda undefined döndürür.
 * @rpc gebelik_protokol_kontrol
 */
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
// 🍼 Süt İçen Buzağılar bandı (İleri Gebeler bandının altına eklenir) — saf, tests/unit/sut-buzagi-band.test.js
// Aşı takibi üç kaynaktan: vaccination_schedule ('buzağı' hedefli yaş dozları — api.js pull),
// vaccination_log (son kayıt + next_due_date yıllık rapeli), açık ASI_PLANLI görevleri (📅 planlı).
// Kesim eşiği protokol_ayar 'sutten_kesme_gun' ile beslenir (varsayılan 60).
/**
 * Sütten kesilmemiş buzağılar için yaş ve aşılama durumuna göre renkli band (HTML) oluşturur. Her buzağı için yaş takvimi dozları, zorunlu aşı kayıtları ve açık planlı aşı görevlerine göre durum rozetleri (gecikmiş/uyarı/tamam/planlı) üretir; kesim eşiğini geçenler "kesim vakti" rozetiyle işaretlenir.
 * @param {Array} animals - Hayvan kayıtları; her kayıtta dogum_tarihi, kupe_no, devlet_kupe, id, grup, padok ve suttten_kesme_tarihi alanları kullanılır.
 * @param {Array} vaccines - Aşı tanımları; id, name ve is_mandatory alanları kullanılır.
 * @param {Array} vaxLogs - Aşılama kayıtları; animal_id, vaccine_id, vaccination_date, next_due_date ve ertelendi alanları kullanılır.
 * @param {Array} tasks - Görev kayıtları; gorev_tipi 'ASI_PLANLI' olan açık görevler planlı aşı rozeti için kullanılır.
 * @param {Array} schRows - Aşı takvim satırları; target_type 'buzağı' ve timing_type 'yas' olanlar yaş bazlı dozlar olarak ele alınır.
 * @param {number|string} kesimEsik - Kesim yaş eşiği (gün); geçersizse 60 varsayılır.
 * @param {string} today - Bugünün tarihi (YYYY-MM-DD); gün hesaplamalarında referans alınır.
 * @returns {string} Oluşturulan band HTML'i; uygun buzağı yoksa boş dize.
 */
function _dashSutBuzagiBandi(animals,vaccines,vaxLogs,tasks,schRows,kesimEsik,today){
  const esik=+kesimEsik||60;
  /**
   * İki tarih stringi arasındaki gün farkını hesaplar.
   * @param {string} d1 İlk tarih (YYYY-MM-DD formatında).
   * @param {string} d2 İkinci tarih (YYYY-MM-DD formatında).
   * @returns {number} d1 ile d2 arasındaki gün sayısı.
   */
  const _gun=(d1,d2)=>Math.floor((new Date(d1+'T00:00:00')-new Date(d2+'T00:00:00'))/86400000);
  /**
   * Verilen ISO tarih formatındaki bir tarihin, belirtilen gün sayısı kadar ileri veya geri alındığı yeni tarihi YYYY-MM-DD formatında döndürür.
   * @param {string} iso ISO 8601 formatında bir tarih stringi (örneğin "2023-10-01").
   * @param {number} g Tarih üzerinde eklenmesi veya çıkarılması gereken gün sayısı.
   * @returns {string} Hesaplanan yeni tarihin YYYY-MM-DD formatındaki string gösterimi.
   */
  const _tarihEkle=(iso,g)=>{const d=new Date(iso+'T00:00:00');d.setDate(d.getDate()+g);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
  const liste=(animals||[]).map(a=>({...a,yas:a.dogum_tarihi?_gun(today,a.dogum_tarihi):null}))
    .filter(a=>a.yas!==null&&!a.suttten_kesme_tarihi&&!(a.grup||'').includes('Sütten Kesilmiş')&&((a.grup||'').includes('Buzağı')||a.yas<=180))
    .sort((x,y)=>y.yas-x.yas);
  if(!liste.length) return '';
  const vaxMap={};(vaccines||[]).forEach(v=>vaxMap[v.id]=v);
  /**
   * Verilen hayvan ve aşı kimliklerine sahip, ertelenmemiş ve en son aşı tarihine sahip kaydı bulur.
   * @param {string} aid Hayvan kimliği.
   * @param {string} vid Aşı kimliği.
   * @returns {Object|null} Bulunan en son aşı kaydı yoksa null, yoksa aşı kaydı objesi.
   */
  const sonLog=(aid,vid)=>{let b=null;(vaxLogs||[]).forEach(v=>{if(v.animal_id===aid&&v.vaccine_id===vid&&!v.ertelendi&&(!b||(v.vaccination_date||'')>(b.vaccination_date||'')))b=v;});return b;};
  /**
   * Verilen metin ve stil özelliklerini kullanarak stilize edilmiş bir HTML span elementi döndürür.
   * @param {string} t Gösterilecek metin.
   * @param {object} r Stil özelliklerini içeren nesne (bg: arka plan rengi, fg: yazı rengi).
   * @returns {string} Stilize edilmiş HTML span elementi.
   */
  const _chip=(t,r)=>`<span style="background:${r.bg};color:${r.fg};border-radius:4px;padding:1px 5px;font-weight:700;font-size:.62rem;white-space:nowrap">${t}</span>`;
  const OK={bg:'rgba(34,150,80,.12)',fg:'#2a9e50'},UYARI={bg:'rgba(255,160,0,.12)',fg:'#b07800'},GECIK={bg:'rgba(192,50,26,.1)',fg:'var(--red2)'},PLAN={bg:'rgba(59,130,246,.12)',fg:'#3b82f6'};
  const schVax={};(schRows||[]).forEach(s=>{if(s.target_type==='buzağı'&&s.timing_type==='yas')(schVax[s.vaccine_id]=schVax[s.vaccine_id]||[]).push(s);});
  Object.values(schVax).forEach(d=>d.sort((a,b)=>a.timing_days-b.timing_days));
  let gecikVar=false;
  const rows=liste.map((a,i)=>{
    const chips=[],kullanilan=new Set();
    // 1) Yaş takvimi dozları — karşılanmayan İLK doz üstünden durum (14 gün önceden görünür)
    //    Chip üretilmeyen (uzak doz) aşı, 2. adımdaki gözlemlenen rapel takibine açık kalsın.
    Object.entries(schVax).forEach(([vid,dose])=>{
      const ad=String((vaxMap[vid]||{}).name||'?').replace(/ Aşısı$/,'');
      const lg=sonLog(a.id,vid);
      const sonraki=dose.find(s=>!(lg&&(lg.vaccination_date||'')>=_tarihEkle(a.dogum_tarihi,s.timing_days-14)));
      let uretildi=false;
      if(sonraki){
        const kalan=_gun(_tarihEkle(a.dogum_tarihi,sonraki.timing_days),today);
        if(kalan<0){gecikVar=true;chips.push(_chip(`⚠️ ${esc(ad)} ${-kalan}g gecikti`,GECIK));uretildi=true;}
        else if(kalan<=14){chips.push(_chip(`⏰ ${esc(ad)} ${kalan}g`,UYARI));uretildi=true;}
      }else if(lg&&lg.next_due_date){
        const k=_gun(lg.next_due_date,today);
        if(k<0){gecikVar=true;chips.push(_chip(`⚠️ ${esc(ad)} rapel ${-k}g gecikti`,GECIK));}
        else if(k<=7)chips.push(_chip(`⏰ ${esc(ad)} rapel ${k}g`,UYARI));
        else chips.push(_chip(`✓ ${esc(ad)}`,OK));
        uretildi=true;
      }else{chips.push(_chip(`✓ ${esc(ad)}`,OK));uretildi=true;}
      if(uretildi)kullanilan.add(vid);
    });
    // 2) Zorunlu aşılar — takvimde olmayanlar yalnız kaydı varsa görünür (UI kirletmez)
    (vaccines||[]).forEach(v=>{
      if(!v.is_mandatory||kullanilan.has(v.id))return;
      const lg=sonLog(a.id,v.id);if(!lg)return;
      kullanilan.add(v.id);
      const n=String(v.name||'?').replace(/ Aşısı$/,'');
      if(lg.next_due_date){const k=_gun(lg.next_due_date,today);
        if(k<0){gecikVar=true;chips.push(_chip(`⚠️ ${esc(n)} rapel ${-k}g gecikti`,GECIK));}
        else if(k<=7)chips.push(_chip(`⏰ ${esc(n)} rapel ${k}g`,UYARI));
        else chips.push(_chip(`✓ ${esc(n)}`,OK));
      }else chips.push(_chip(`✓ ${esc(n)}`,OK));
    });
    // 3) Açık planlı aşı görevleri — kaydı olmayan aşı için 📅 planlı
    (tasks||[]).forEach(t=>{
      if(!t||t.tamamlandi||t.iptal||t.gorev_tipi!=='ASI_PLANLI'||t.hayvan_id!==a.id)return;
      const v=_asiVaccineCoz(t,vaccines);if(!v||kullanilan.has(v.id))return;
      kullanilan.add(v.id);chips.push(_chip(`📅 ${esc(v.name||'Aşı')}`,PLAN));
    });
    const kid=a.kupe_no||a.devlet_kupe||a.id;
    const kesimChip=a.yas>=esik?`<span style="background:rgba(192,50,26,.1);color:var(--red2);border-radius:4px;padding:1px 5px;font-weight:700;font-size:.62rem;margin-left:4px">🍼 kesim vakti</span>`:'';
    return `<div class="arow" onclick="openDet('${escAttr(a.id)}')"><div class="arow-left"><div class="arow-id"><span style="color:var(--ink3);font-size:.65rem;margin-right:3px">${i+1})</span>${esc(kid)}${kesimChip}</div><div class="arow-sub">${a.yas}. gün · ${esc(a.grup||'')}${a.padok?' · '+esc(a.padok):''}</div></div>${chips.length?`<div style="display:flex;gap:4px;flex-wrap:wrap;justify-content:flex-end;align-items:center;flex-shrink:0;max-width:55%">${chips.join('')}</div>`:''}<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
  });
  const kesimBtn=`<button onclick="openSuttenKesModal()" style="font-size:.65rem;font-weight:700;padding:3px 9px;border-radius:6px;border:1px solid var(--amber);background:rgba(255,160,0,.12);color:var(--amber);cursor:pointer;white-space:nowrap;margin-left:auto">🍼 Toplu Kes →</button>`;
  const title=`<span style="display:flex;align-items:center;gap:8px;width:100%">🍼 Süt İçen Buzağılar (${liste.length}) ${kesimBtn}</span>`;
  return band((gecikVar||liste.some(a=>a.yas>=esik))?'red':'amber',title,rows.join(''));
}
function _dashBands(negStk,late,todayT,births60,nearBirth,critStk,stock,ileriGebeler,aMap,yakAsi,yakTakviye,ddMap,sessizList,sutBuzagiHtml,muayeneList){
  const _dd=ddMap||{};
  /**
   * Görev tipinin 'TEDAVI_GUN' olmadığı durumlarda boş string döndürür; aksi takdirde açıklama alanındaki day_id değeri üzerinden _dd dizisinden karşılık gelen değeri döndürür.
   * @param {Object} t Görev tipini (gorev_tipi) ve açıklama alanını (aciklama) içeren nesne.
   * @returns {string} day_id'ye karşılık gelen değer veya boş string.
   */
  const _getDis=t=>{if(t.gorev_tipi!=='TEDAVI_GUN')return '';try{return _dd[JSON.parse(t.aciklama||'{}').day_id]||'';}catch(e){return '';}};
  /**
   * Verilen görevi (t) ve sınıfı (cls) kullanarak renderTask fonksiyonunu çağırır.
   * @param {any} t Görev nesnesi.
   * @param {any} cls Sınıf nesnesi.
   * @returns {any} renderTask fonksiyonunun döndürdüğü değer.
   */
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
      births60.map(b=>{const _an=aMap&&aMap[b.anne_id];const _kid=(_an&&(_an.kupe_no||_an.devlet_kupe))||b.anne_id;return `<div class="arow" style="display:flex;align-items:center;gap:6px"><div style="flex:1;cursor:pointer" onclick="openDet('${escAttr(b.anne_id)}')"><div class="arow-left"><div class="arow-id">${esc(_kid)}</div><div class="arow-sub">${esc(b.tarih)} — ${Math.floor((Date.now()-new Date(b.tarih))/86400000)}. gün</div></div></div><button style="font-size:.65rem;font-weight:700;color:var(--red2);background:rgba(192,50,26,.1);border:1px solid rgba(192,50,26,.3);border-radius:6px;padding:2px 7px;cursor:pointer;white-space:nowrap" onclick="event.stopPropagation();kizginlikYoktu('${escAttr(b.anne_id)}','${escAttr(b.id||'')}')">✕</button></div>`;}).join(''));
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
  if(sutBuzagiHtml) h+=sutBuzagiHtml;   // 🍼 Süt İçen Buzağılar — ileri gebelerin hemen altı
  // S2: 🔬 Gebelik Muayenesi Bekleyenler — sessiz bandının HEMEN ÜSTÜNDE izole kırmızı bant
  if((muayeneList||[]).length){
    const mTitle=`<span style="display:flex;align-items:center;gap:8px;width:100%">🔬 Gebelik Muayenesi Bekleyenler (${muayeneList.length})<button onclick="_showSessizList()" style="font-size:.65rem;font-weight:700;padding:3px 9px;border-radius:6px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer;white-space:nowrap;margin-left:auto">Tümünü Gör →</button></span>`;
    h+=band('red',mTitle,
      muayeneList.slice(0,8).map(m=>`<div class="arow" onclick="openDet('${escAttr(m.hayvan_id)}')"><div class="arow-left"><div class="arow-id">${esc(m.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(m.grup||'')}</span></div><div class="arow-sub">${m.bekliyor_gun}. gün Bekliyor · Son tohumlama: ${esc(m.son_tohumlama_tarihi||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`).join(''));
  }
  if((sessizList||[]).length){
    const sTitle=`<span style="display:flex;align-items:center;gap:8px;width:100%">❗ Sessiz Hayvanlar (${sessizList.length})<button onclick="_showSessizList()" style="font-size:.65rem;font-weight:700;padding:3px 9px;border-radius:6px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer;white-space:nowrap;margin-left:auto">Tümünü Gör →</button></span>`;
    const sessizTop=[...(sessizList||[])].sort((a,b)=>{const af=a.sessiz_gun>=9999?1:0,bf=b.sessiz_gun>=9999?1:0;return af-bf||b.sessiz_gun-a.sessiz_gun;});
    h+=band('red',sTitle,
      sessizTop.slice(0,8).map(s=>{
        const gunTxt=s.sessiz_gun>=9999?'Hiç kayıt yok':s.sessiz_gun+' gündür sessiz';
        return `<div class="arow" onclick="openDet('${escAttr(s.hayvan_id)}')"><div class="arow-left"><div class="arow-id">${esc(s.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(s.grup||'')}</span></div><div class="arow-sub">${gunTxt} · Son: ${esc(s.son_aktivite||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
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
/**
 * Dashboard'u yükler: aktif hayvanlar, hastalıklar, görevler, stok, doğumlar, gebelikler, aşı kayıtları ve diğer verileri getirir,
 * kritik stok uyarılarını, geciken görevleri, yaklaşan doğumları, sütten kesme kontrollerini, sessiz hayvanları ve protokol uyarılarını hesaplayarak
 * dashboard HTML içeriğini oluşturur ve 'dash-body' elementine yerleştirir.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc buzagi_sutten_kesme_kontrol, gebelik_muayene_listele, ovsync_baslat_uyarilari, padok_transfer_gorev_uzlastir, protokol_eksik_tara, sessiz_hayvanlar_listele
 */
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
    /**
     * Verilen düğümün ebeveyn ID'si boşsa veya aktif ebeveyn ID'leri kümesinde bulunmuyorsa true döndürür.
     * @param {Object} t Düğüm nesnesi.
     * @returns {boolean} Düğümün üstte olup olmadığına dair boolean değer.
     */
    const _isTop=t=>!t.parent_id||!_activePids.has(t.parent_id);
    // T3: sürüden çıkan (durum≠Aktif / cop_kutusu) hayvan hiçbir bantta görünmesin.
    // Çıkışta trigger görevleri iptal eder; bu satırlar IDB gecikmesine karşı güvenlik ağı.
    // animals boşsa (pull hatası) null → filtre devre dışı (eski davranış, tümünü gizleme)
    const aktifIdler=animals.length?new Set(animals.map(a=>a.id)):null;
    const aktifTasks=aktifHayvanSatirlari(tasks,'hayvan_id',aktifIdler);
    const late=aktifTasks.filter(t=>t.hedef_tarih<today&&_isTop(t));
    const todayT=aktifTasks.filter(t=>t.hedef_tarih===today&&_isTop(t));
    const d7str=dFwd(null,7);
    const d1str=dFwd(null,1);
    const yakAsi=aktifTasks.filter(t=>(t.gorev_tipi==='ASI_PLANLI'||t.gorev_tipi==='ILERI_GEBE_ASI')&&_isTop(t)&&t.hedef_tarih>today&&t.hedef_tarih<=d7str);
    const yakTakviye=aktifTasks.filter(t=>t.gorev_tipi==='ILERI_GEBE'&&_isTop(t)&&t.hedef_tarih>today&&t.hedef_tarih<=d1str);
    const badge=late.length;
    const tb=document.getElementById('tbadge');
    if(tb){ tb.textContent=badge>99?'99+':badge; tb.style.display=badge>0?'flex':'none'; }
    const aMap={}; animals.forEach(a=>aMap[a.id]=a);
    // T3: Gebe sayacı + Yaklaşan Doğumlar bandı yalnız aktif annelerden
    const gebeTohsA=aktifHayvanSatirlari(gebeTohs,'hayvan_id',aktifIdler);
    const nearBirth=gebeTohsA.filter(t=>{ if(!t.tarih)return false; const d=Math.floor((new Date(t.tarih).getTime()+280*86400000-Date.now())/86400000); return d>=0&&d<=7; });
    const ileriGebeler=window.__ileriGebeListesi||[];
    // Filter births60: annesi sürüden çıkmışsa gösterme; kizginlik/tohumlama
    // kaydı doğumdan sonraysa gösterme
    const births60F=aktifHayvanSatirlari(births60,'anne_id',aktifIdler).filter(b=>{
      const hasK=allKizginlik.some(k=>k.hayvan_id===b.anne_id&&k.tarih>=b.tarih);
      const hasT=allTohum.some(t=>t.hayvan_id===b.anne_id&&t.tarih>=b.tarih);
      return !hasK&&!hasT;
    });
    const births60D=_dogumAnneBazliTekillestir(births60F);   // ikizde anne 1 kez
    // 🍼 Süt içen buzağılar bandı (aşı takvimi api.js pull ile senkron: vaccination_schedule)
    let schRows=[];
    try{ schRows=await getData('vaccination_schedule')||[]; }catch(e){ /* eski IDB sürümü — bantsız devam */ }
    const kesimEsik=suttenKesmeEsigi();   // tek kaynak (forms.js; protokol_ayar yoksa 60)
    const sutBuzagiBandi=_dashSutBuzagiBandi(animals,vaccines,vaxLogs,aktifTasks,schRows,kesimEsik,today);
    // Buzağı sütten kesme otomatik kontrolü
    try {
      const resBuz=await rpc('buzagi_sutten_kesme_kontrol');
      if(resBuz&&resBuz.ok&&resBuz.olusturulan>0) toast('🍼 '+resBuz.olusturulan+' buzağı sütten kesme görevi oluşturuldu');
    } catch(e){ /* sessiz */ }

    // Sessiz hayvanlar listesi (dashboard band için)
    let sessizList=[];
    try{ const sl=await rpc('sessiz_hayvanlar_listele',{}); if(sl&&sl.length) sessizList=sl; }catch(e){/* sessiz */}

    // 🔬 Gebelik muayenesi listesi (S2) — band, sessiz bandının hemen üstünde
    let muayeneList=[];
    try{ const ml=await rpc('gebelik_muayene_listele',{}); if(ml&&ml.length) muayeneList=ml; }catch(e){/* sessiz — RPC henüz yoksa bantsız devam */}

    // TEDAVI_GUN teşhis haritası (dashboard kartları için)
    const _dtDays=await idbGetAll('treatment_days').catch(()=>[]);
    const _dtDiseases=await idbGetAll('diseases').catch(()=>[]);
    const _dtDById=Object.fromEntries(_dtDiseases.map(d=>[d.id,d.name||'']));
    const _dtCases=await idbGetAll('cases').catch(()=>[]);
    const _dtCById=Object.fromEntries(_dtCases.map(c=>[c.id,c]));
    const _ddMap={};
    _dtDays.forEach(td=>{const c=_dtCById[td.case_id];if(c?.disease_id)_ddMap[td.id]=_dtDById[c.disease_id]||'';});

    // T3+T4 birleşimi: _dashStatRow/_dashBands/_dashVacAlerts filtreli veriyle;
    // T4 süt buzağı bandı da aktifTasks alır (çıkmış buzağının görev chip'i sızmasın)
    const h=_dashStatRow(animals,gebeTohsA,diseases,aktifTasks,badge)+_dashBands(negStk,late,todayT,births60D,nearBirth,critStk,stock,ileriGebeler,aMap,yakAsi,yakTakviye,_ddMap,sessizList,sutBuzagiBandi,muayeneList)+_dashVacAlerts(today,vaxLogs,vaccines,aktifIdler);
    el.innerHTML=h||'<div class="empty"><div class="empty-ico">✅</div>Her şey yolunda</div>';
    // Protokol uyarı scanner (badge-only — açık ekranları yenilemez)
    try {
      // E1-UI: erteleme kural cache'i her dash yüklenişinde tazelenir
      // (ovsync_baslat_uyarilari deseni — salt-okuma RPC, haritada değil)
      await ertelemeKurallariYenile(true);
      const proto = await rpc('protokol_eksik_tara', {});
      window.__protokolUyarilar = Array.isArray(proto) ? proto : [];
      const aktif = window.__protokolUyarilar.filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
      // T10: rozet İlk Tohumlama uyarılarını da sayar (panelin tek diğer kaynağı)
      let ovSayi = 0;
      try {
        const ov = await rpc('ovsync_baslat_uyarilari', {});
        window.__ovsyncUyarilar = (ov && ov.uyarilar) || [];
        ovSayi = window.__ovsyncUyarilar.length;
      } catch(e) { console.warn('ovsync_baslat_uyarilari (rozet):', e.message); }
      // C4 (cila2): K8'in 3. rozet kaynağı (ovsync seans uyarıları) geri alındı —
      // sahip "ana listeye monte etmişler, ben böyle bir şey istemedim; sabahki yeterli".
      const toplam = _rozetTopla(aktif.length, ovSayi);
      const bb = document.getElementById('bellbadge');
      if (bb) {
        bb.textContent = toplam > 99 ? '99+' : toplam;
        bb.style.display = toplam > 0 ? 'flex' : 'none';
      }
    } catch(e) { console.warn('protokol_eksik_tara:', e.message); }
    // Transfer görev reconciliation (trigger'dan kaçanları kapat — idempotent)
    try { await rpc('padok_transfer_gorev_uzlastir', {}); } catch(e) { console.warn('gorev uzlastir:', e.message); }
    updateTaskBadge();
  } catch(e){
    el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}<br><button class="btn btn-o" style="margin-top:12px;width:auto;padding:8px 20px" onclick="loadDash()">Tekrar Dene</button></div>`;
  }
}
/**
 * Onay alındığında hayvanda kızgınlık gözlemlenmedi kaydını oluşturur; başarılıysa bildirim gösterir ve ilgili tabloları/arayüzü günceller.
 * @param {string|number} hayvanId - Kaydın oluşturulacağı hayvanın kimliği.
 * @param {string|number|null} dogumId - İlgili doğumun kimliği; verilmezse null gönderilir.
 * @returns {Promise<void>} İşlem sonucunu döndürmez; sonuç toast bildirimiyle kullanıcıya iletilir.
 * @rpc kizginlik_yok_kaydet
 */
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
/**
 * Verilen kayıt ID'si ve kupe bilgisini kullanarak kizginlik tedavisi başlatır.
 * @param {string} kayitId Tedavi başlatılacak kayıt ID'si.
 * @param {string} kupe Tedavi yapılacak kupe numarası.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function kizginlikTedaviAc(kayitId, kupe) {
  globalThis._kizginlikTedaviId = kayitId;
  openMWithHayvan('m-disease', 'd-hid', kupe);
}

// ── Kızgınlık Sil ────────────────────────────
/**
 * Kullanıcı onayı alındıktan sonra belirtilen kızgınlık kaydını siler, ilgili log tablosunu günceller ve gereksinimi olan modülleri yeniden yükler.
 * @param {number} kayitId Silinecek kızgınlık kaydının benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc kizginlik_sil
 */
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
/**
 * Cozulmemis_kizginlik_view tablosundan son 48 saati geçmemiş veya gecen_saat bilgisi olmayan kızgınlık kayıtlarını filtreleyerek uyarı durumunu belirler.
 * Eğer filtrelenmiş veri varsa, uyarı sayısına göre renk değiştirir, metin günceller ve badge elementini gösterir; yoksa temizler.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @tablo cozulmemis_kizginlik_view (select)
 */
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

/**
 * Belirtilen aşı ismine sahip aşı uyarısını kapatmak için zorunlu bir not alıp sunucuya gönderir.
 * Kullanıcı iptal ederse veya not boşsa işlemi iptal eder.
 * Başarılı olduğunda ilgili tabloları yeniler ve dashboard'u günceller.
 * @param {string} vacLogId Aşı kaydı için kullanılan aşı ID'si.
 * @param {string} vaxName Kapatılacak aşı uyarısının adı.
 * @returns {void} İşlem sonucu hakkında bilgi vermez.
 * @rpc vaccination_dismiss
 */
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

/**
 * Suru sayfasına yönlendirir, gebelik chip durumunu 'gebe' olarak ayarlar, ilgili chip'leri günceller ve filtreleme işlemini başlatır.
 * @returns {Promise<void>} İşlemin tamamlandığında çözülür.
 */
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

/**
 * Dashboard'daki "Aktif Hastalık" kartına tıklandığında suru görünümüne geçip sağlık filtresi chip'i olarak 'hasta' seçeneğini programatik olarak işaretler ve listeyi filtreleyerek render eder.
 * @returns {void}
 */
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
let _flushInFlight = false;   // K9: tek-uçuş kilidi — eşzamanlı flush çağrısı ikinci gönderim açmaz
let _flushHataToast = new Map();   // K9: key → {msg,ts} — kalıcı hatada tekrar toast soğuması (5 dk)
let _flushBeklenen = null;    // F4/K9: uçuştaki flush'in promise'i — kilitliyken çağıranlar bunu bekler (sessiz erken dönüş yok)
let _flushOpMs = 30000;       // F4/K9: op başına ağ zaman sınırı — timeoutsuz askıda RPC kilidi soket ölümüne dek tutmasın
let _flushPullMs = 60000;     // F4/K9: kapanış pullTables'ının sınırı (7 tablo — daha cömert)
/**
 * Bekleyen tamamlanan öğeleri localStorage'a JSON olarak kaydeder; hata oluşursa sessizce yoksayar.
 * @returns {void}
 */
function _savePending(){
  try { localStorage.setItem('_pendingDone', JSON.stringify([..._pendingDone.values()])); } catch(e){}
}
/**
 * Bekleyen işlemler sayısına göre 'fab-commit' ve 'fab-cancel' butonlarının görünürlüğünü ve başlıklarını günceller.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function updatePendingFab(){
  const n=_pendingDone.size;
  const c=document.getElementById('fab-commit'), x=document.getElementById('fab-cancel');
  if(c){ c.style.display=n?'flex':'none'; c.title='Bekleyenleri gönder ('+n+')'; }
  if(x){ x.style.display=n?'flex':'none'; x.title='Hepsini iptal ('+n+')'; }
}
// Bekleyenleri iptal et — kuyruğu boşalt + işaretleri kaldır + listeyi tazele
/**
 * Bekleyen işlemleri temizler, durumu kaydedip arayüzü günceller ve varsayılan filtre ile görevleri yükler.
 * @returns {void}
 */
function cancelPendingDone(){
  if(!_pendingDone.size) return;
  _pendingDone.clear(); _savePending(); updatePendingFab();
  loadTasks(_curTaskFilter||'today');
}
/**
 * Kart öğesine 'pending-done' sınıfını ekleyip butonun veri setini '1' olarak günceller ve bekleme işareti SVG'sini içerik olarak ayarlar.
 * @param {HTMLElement} card Kart elemanı.
 * @param {HTMLElement} btn Buton elemanı.
 * @returns {void}
 */
function _markPending(card, btn){
  if(card) card.classList.add('pending-done');
  if(btn){ btn.dataset.pending='1';
    btn.innerHTML='<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>'; }
}
/**
 * Bekleyen işaretini kaldırır: kart üzerindeki 'pending-done' sınıfını siler ve düğmeyi sıfırlar.
 * @param {HTMLElement|null} card - 'pending-done' sınıfı kaldırılacak kart öğesi.
 * @param {HTMLElement|null} btn - Bekleme durumu sıfırlanacak düğme öğesi; içeriği tipe göre ayarlanır.
 * @param {string} type - İşaretin türü; 'seans' ise düğme içeriği boşaltılır, değilse onay (check) ikonu yerleştirilir.
 * @returns {void} Dönüş değeri yoktur.
 */
function _unmarkPending(card, btn, type){
  if(card) card.classList.remove('pending-done');
  if(btn){ btn.dataset.pending='';
    btn.innerHTML = type==='seans' ? '' : '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>'; }
}
/**
 * Belirli bir görev veya seans durumunu (beklemede/pasif) değiştirir.
 * @param {string} type - İşlem türü (örneğin 'seans').
 * @param {string} gorevId - Görev ID'si.
 * @param {HTMLElement} btn - Tıklanan buton elemanı.
 * @param {Object} extra - Ek parametreler objesi.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
  if(_flushInFlight) return _flushBeklenen;   // K9+F4: tek-uçuş — ikinci gönderim açmaz; uçuşun BİTİŞİ beklenir (loadTasks bayat IDB'den render etmez)
  if(!navigator.onLine){ toast('⚠️ Çevrimiçi olunca uygulanacak'); return; }
  _flushInFlight=true;
  // F4/K9: rpc()/pullTables timeoutsuz — tek askıda ağ çağrısı kilidi soket ölümüne/page reload'a
  // kadar tutuyordu. Op başına zaman sınırı: aşarsa op hata sayılır (pending'de kalır + toast),
  // kilit serbest kalır; aşan RPC arka planda sonuçlansa bile tamamlandı idempotenttir.
  /**
   * Verilen Promise ile zaman aşımı (timeout) arasında yarışır; zaman aşımı gerçekleşirse hata döndürür,
   * işlem tamamlandığında veya zaman aşımı olduğunda Promise'ı çözer ve timeout timer'ını temizler.
   * @param {Promise} p İşlem yapılacak Promise.
   * @param {number} ms Zaman aşımı süresi (milisaniye cinsinden).
   * @param {string} ne Zaman aşımı durumunda döndürülecek hata mesajı (varsayılan: 'işlem').
   * @returns {Promise} İşlem sonucu veya zaman aşımı hatası içeren Promise.
   */
  const _rz=(p,ms,ne)=>{ let _t; const _ta=new Promise((_,rej)=>{ _t=setTimeout(()=>rej(new Error('zaman aşımı: '+(ne||'işlem'))), ms); }); return Promise.race([p,_ta]).finally(()=>clearTimeout(_t)); };
  const run=(async()=>{
    const items=[..._pendingDone.values()];
    for(const it of items){
      try {
        if(it.type==='seans') await _rz(rpcSeansTamamla(it.params.seansId, it.params.uygulanmadi, null), _flushOpMs, 'seans gönderimi');
        else if(it.type==='besleme') await _rz(rpc('besleme_tamam', {p_gorev_id:it.params.gorevId}), _flushOpMs, 'görev gönderimi');
        else if(it.type==='gorev') await _rz(rpc('gorev_tamamla', {p_gorev_id:it.params.gorevId, p_padok_hedef:it.params.padok||null}), _flushOpMs, 'görev gönderimi');
        _pendingDone.delete(it.type==='seans'?it.params.seansId:it.params.gorevId);   // K9: yalnız BAŞARILI op düşer; uçuşta eklenenlere dokunulmaz
        _flushHataToast.delete(it.type==='seans'?it.params.seansId:it.params.gorevId);
      } catch(e){
        const _msg=String((e&&e.message)||e);
        const _key=it.type==='seans'?it.params.seansId:it.params.gorevId;
        const _prev=_flushHataToast.get(_key);
        const _now=Date.now();
        if(!_prev||_prev.msg!==_msg||_now-_prev.ts>5*60*1000){
          toast('❌ Görev uygulanamadı: '+_msg, true);
          _flushHataToast.set(_key,{msg:_msg,ts:_now});
        }
        /* op pending'de kalır */
      }
    }
    _savePending(); updatePendingFab();
    try { await _rz(pullTables(['gorev_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','cases']), _flushPullMs, 'veri yenileme'); } catch(e){}
    if(typeof updateTaskBadge==='function') updateTaskBadge();
  })();
  _flushBeklenen=run.catch(()=>{});   // F4/K9: bekleyen çağıranlar reddi yutulmuş promise alır (eski sessiz-dönüş semantiği)
  try { await run; } finally { _flushInFlight=false; _flushBeklenen=null; }
}
/**
 * `_pendingDone` anahtarındaki bekleyen işlemleri alıp ilgili anahtarları (`seansId` veya `gorevId`) günceller ve temizler.
 * @returns {Promise<void>} İşlem tamamlandığında boş Promise döndürür.
 */
async function recoverPendingDone(){
  try {
    const raw=localStorage.getItem('_pendingDone'); if(!raw) return;
    const arr=JSON.parse(raw)||[]; if(!arr.length) return;
    arr.forEach(e=>{ const key=e.type==='seans'?e.params.seansId:e.params.gorevId; if(key) _pendingDone.set(key,e); });
    await flushPendingDone();
  } catch(e){ /* sessiz */ }
}
/**
 * Görev listesini (gorev_log) verilen filtreye göre yükler, süzüp sıralayarak DOM'a render eder.
 * Bekleyen tamamlamaları commit eder, filtre butonunu ve 'all' sekmesindeki pencere chip şeridini günceller,
 * tamamlanan (done) sekmesinde geri alınabilir görev uçlarını, diğer sekmelerde açık görevleri
 * seans grupları ve saat/hayvan grubu ayraçlarıyla listeler; çoklu seçim çubuğunu ve arama
 * filtrelemesini destekler. Kaydırma konumu korunur; hata durumunda hata mesajını gösterir.
 * @param {string} [f] - Filtre anahtarı ('today', 'late', 'all', 'done'); verilmezse aktif filtre (_curTaskFilter) kullanılır.
 * @param {HTMLElement} [btn] - 'on' sınıfı eklenecek filtre butonu; diğer .fs-btn butonlarından 'on' kaldırılır.
 * @param {Object} [opts] - Seçenekler. skipPull: true ise içerideki pullTables çağrısı atlanır.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen promise; görev listesi DOM'a işlenmiş olarak döner.
 */
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
  // F4: arama sekme/filtre geçişlerinde korunur — loadTasks temizlemez (eskiden
  // burada srchEl.value='' vardı); yalnız ✕/elle temizlenir.
  await _keepScroll(el,async()=>{
  // Sadece cold load'da spinner göster — refresh'te eski liste yerinde kalsın (blink fix)
  if(!el.querySelector('.task-card')) el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    const today=bugun();
    // F1 Task 3: seçim durumu sessionStorage'dan geri yüklenir — tab/filtre geçişinde
    // seçimler korunur (SPEC §4); checkbox'lar aşağıdaki render'da Set'e göre işaretlenir.
    _cokluSecimYukle();
    // skipPull: çağıran zaten pullTables yaptıysa içerideki tekrar pull'u atla (çift network fix)
    if(navigator.onLine && !(opts&&opts.skipPull)) await pullTables(['gorev_log','treatment_days','cases','diseases','treatment_day_uygulamalar','drug_administrations','drug_products','stok']).catch(()=>{});
    // E1-UI: kural cache boşsa bir kez çek — genel [Ertele] butonları ilk
    // render'da kurallı çizilsin (cache doluysa/60sn sükunette no-op; sonrasında
    // loadDash rozet tarayıcısı tazeler)
    await ertelemeKurallariYenile();
    const all=await idbGetAll('gorev_log');
    // K7: vaka-kategorili seans/gün eşlemesi süzgeçlerden ÖNCE kurulur —
    // Üreme sekmesi diseases.category='Üreme' vakasının TEDAVI_SEANS/TEDAVI_GUN'lerini kapsar.
    const _allTDays=await idbGetAll('treatment_days').catch(()=>[]);
    const _allTaskCases=await idbGetAll('cases').catch(()=>[]);
    const _allTaskDiseases=await idbGetAll('diseases').catch(()=>[]);
    const _caseById=Object.fromEntries(_allTaskCases.map(c=>[c.id,c]));
    const _diseaseById=Object.fromEntries(_allTaskDiseases.map(d=>[d.id,d.name||'']));
    const _allSeans=await idbGetAll('treatment_day_uygulamalar').catch(()=>[]);
    const _seansById=Object.fromEntries(_allSeans.map(s=>[s.id,s]));
    const _tdById=Object.fromEntries(_allTDays.map(td=>[td.id,td]));
    const _uremeCaseIdler=_uremeVakaCaseIds(_allTaskCases);   // C3: protocol_family='OVSYNC' kümesi
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
      if(_taskKategori!=='all') done=done.filter(t=>_kategoriFiltreUygun(t,_taskKategori,_uremeCaseIdler,_tdById,_seansById));   // K7: done sekmesi açık sekmelerle aynı kategori dilimini kullanır
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
    // T3: sürüden çıkan hayvanın görevleri listede görünmesin (çıkış trigger'ı
    // iptal eder; IDB gecikmesine karşı client güvenlik ağı). Hayvan listesi
    // boşsa (pull hatası) null → filtre kapalı, liste yanlışça boşalmasın.
    const _aktifHay=(getState('animals')||[]).filter(a=>a.durum==='Aktif');
    const _aktifIdler=_aktifHay.length?new Set(_aktifHay.map(a=>a.id)):null;
    data=aktifHayvanSatirlari(data,'hayvan_id',_aktifIdler);
    const _d7=dFwd(null,7);
    const _d1=dFwd(null,1);
    const _d30=dFwd(null,30);
    // K7: ASI_PLANLI 7-gün penceresi + planlı üreme (OVSYNC_BASLAT/TOHUMLAMA_PLANLI).
    // C3 (cila2): Üreme kategorisi seçiliyken pencere TÜM üreme görevlerine açılır —
    // ovsync vakasının yaklaşan TEDAVI_GUN/SEANS'ları da Bugün+Üreme'de görünür
    // ("tohumlama ve ovsync görevleri üremede görünmüyor" belirtisi).
    if(f==='today') data=data.filter(t=>_bugunFiltreUygun(t,today,_d7)
      ||(_taskKategori==='ureme'&&_kategoriFiltreUygun(t,'ureme',_uremeCaseIdler,_tdById,_seansById)
         &&t.hedef_tarih>today&&t.hedef_tarih<=_d7));
    else if(f==='late') data=data.filter(t=>t.hedef_tarih<today);
    else if(f==='all'){
      data=data.filter(t=>t.hedef_tarih>today);
      if(_pendWin==='yarin')   data=data.filter(t=>t.hedef_tarih===_d1);
      else if(_pendWin==='7')  data=data.filter(t=>t.hedef_tarih<=_d7);
      else if(_pendWin==='30') data=data.filter(t=>t.hedef_tarih<=_d30);
    }
    data=data.filter(t=>_kategoriFiltreUygun(t,_taskKategori,_uremeCaseIdler,_tdById,_seansById));   // K7: tedavi↔üreme seans ayrımı tek noktadan
    data.sort((a,b)=>{
      const dCmp=(a.hedef_tarih||'').localeCompare(b.hedef_tarih||'');
      if(dCmp!==0) return dCmp;
      /**
       * Verilen nesnin 'gorev_tipi' alanı 'TEDAVI_GUN' ise, 'aciklama' alanındaki JSON'dan 'planned_time' değerini parse edip döndürür; aksi takdirde boş string döndürür.
       * @param {Object} t Görev tipini ve açıklama bilgisini içeren nesne.
       * @returns {string} Planlanan süre değeri veya boş string.
       */
      const getTime=t=>t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').planned_time||'';}catch(e){return '';}})():'';
      return getTime(a).localeCompare(getTime(b))||(a.aciklama||'').localeCompare(b.aciklama||'');
    });
    if(!data.length){ el.innerHTML='<div class="empty"><div class="empty-ico">✅</div>Bu filtrede görev yok</div>'; return; }
    const allSubs=aktifHayvanSatirlari(all.filter(t=>!!t.parent_id&&!t.tamamlandi),'hayvan_id',_aktifIdler);
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
    // (K7: _allTDays/_allTaskCases/_allTaskDiseases/_caseById/_diseaseById/_allSeans/_seansById/_tdById
    //  haritaları yukarıda, süzgeçlerden önce kuruldu — burada yalnız türetilen tablolar)
    const _dayDiseaseMap={};
    _allTDays.forEach(td=>{ const c=_caseById[td.case_id]; if(c?.disease_id)_dayDiseaseMap[td.id]=_diseaseById[c.disease_id]||''; });
    const _caseDayCount={};
    _allTDays.forEach(td=>{ _caseDayCount[td.case_id]=(_caseDayCount[td.case_id]||0)+1; });
    // Gün başına seans ilerlemesi (ayraçta "1/3 seans")
    const _seansDayStat={};
    _allSeans.forEach(s=>{ const d=_seansDayStat[s.treatment_day_id]||(_seansDayStat[s.treatment_day_id]={total:0,done:0}); d.total++; if(s.uygulama_tamamlandi_at||s.uygulanmadi)d.done++; });
    // --- Seans görevlerini ayır, gruplara böl ---
    const seansDayIds=new Set();
    data.forEach(t=>{ if(t.gorev_tipi==='TEDAVI_SEANS'){ const sd=_seansById[t.seans_admin_id]; if(sd?.treatment_day_id)seansDayIds.add(sd.treatment_day_id); } });
    // TEDAVI_GUN gorev aciklamasi JSON {day_id, planned_time, label, ...} — try/catch fallback
    /**
     * Verilen nesnenin 'aciklama' özelliğindeki JSON stringini parse ederek döndürür; başarısız olursa boş nesne döner.
     * @param {Object} t Parse edilecek nesne, 'aciklama' özelliği JSON stringi içermelidir.
     * @returns {Object} Parse edilen JSON nesnesi veya parse hatası durumunda boş nesne.
     */
    const _gorevAciklama=t=>{ try{ return JSON.parse(t.aciklama||'{}'); }catch(e){ return {}; } };
    // C3 (cila2): grup anahtarı hayvan|DAY_ID yerine hayvan|TARİH — aynı hayvana
    // aynı gün açılan ikinci şablon uygulaması (tekillik guard'ı yok, gerçek veri:
    // aynı (case,tarih) çift day-set'leri) iki ayrı ayraç altında üst üste
    // görünüyordu ("iki görev üst üste çakışıyor"). Tek ayraca iner; "Gün N·M"
    // etiketi benzersiz gün numaralarını sırayla listeler.
    const grupMap={};
    data.forEach(t=>{
      if(t.gorev_tipi!=='TEDAVI_SEANS')return;
      const seans=_seansById[t.seans_admin_id]; if(!seans)return;
      const dayId=seans.treatment_day_id;
      const td=_tdById[dayId];
      const key=(t.hayvan_id||'')+'|'+(t.hedef_tarih||td?.treatment_date||'');
      if(!grupMap[key]){
        const animal=getState('animals').find(a=>a.id===t.hayvan_id);
        grupMap[key]={ hayvan_id:t.hayvan_id, day_id:dayId,
          date:t.hedef_tarih||td?.treatment_date||'',
          gunNoSet:new Set(), totalGun:td?_caseDayCount[td.case_id]||0:0,
          animalLabel:animal?(animal.kupe_no||animal.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'—'),
          grupAd:animal?.grup||(t.hayvan_id?'':'GENEL'),
          disease:_dayDiseaseMap[dayId]||'',
          items:[] };
      }
      if(td?.day_no!=null) grupMap[key].gunNoSet.add(td.day_no);
      grupMap[key].items.push({ task:t, seans,
        drugName:_prodMap[seans.drug_product_id]?.brand_name||_stokNameMap[seans.stok_id]||'İlaç' });
    });
    // C3: ayraç ilerlemesi items'tan (görünen görevlerden) sayılır — _seansDayStat
    // süzgeç dışı seansları da saydığı için birleşik grupta yanıltıcı olur.
    Object.values(grupMap).forEach(g=>{
      const guns=[...g.gunNoSet].sort((a,b)=>a-b);
      g.gunNo=guns.length?guns.join('·'):'?';
      if(guns.length>1) g.totalGun=0;   // çoklu gün → "N/M" kesri anlamsız, yalnız liste
      g.seansTotal=g.items.length;
      g.seansDone=g.items.filter(i=>i.seans.uygulama_tamamlandi_at||i.seans.uygulanmadi).length;
    });
    // --- Blokları (normal kart + seans grubu) topla; her bloğa F3/F4 meta'sı ---
    // F3 katmanları: tarih → saat → hayvan grubu → küpe (doğal sıra).
    // F4 arama: blok.arama = kupe + tip + açıklama + ilaç adları + teşhis.
    const bloklar=[];
    /**
     * Belirtilen grup adının öncelik sırasını döndürür. 'GENEL' grubu için 100, tanımlı gruplar için dizideki indeks, yoksa 90 döner.
     * @param {string} grupAd - Sıralanacak grup adı.
     * @returns {number} Grubun öncelik sırası.
     */
    const _grupSira=grupAd=>{
      if(grupAd==='GENEL') return 100;
      const i=(typeof GOREV_GRUP_SIRA!=='undefined'?GOREV_GRUP_SIRA:[]).indexOf(grupAd||'');
      return i>=0 ? i : 90; // tanımsız grup değeri → "Diğer" bloğu
    };
    data.forEach(t=>{
      if(t.gorev_tipi==='TEDAVI_SEANS')return;
      if(t.gorev_tipi==='TEDAVI_GUN'){ if(seansDayIds.has(_gorevAciklama(t).day_id))return; }
      const _acik=t.gorev_tipi==='TEDAVI_GUN'?_gorevAciklama(t):{};
      const h=t.hayvan_id?(getState('animals').find(a=>a.id===t.hayvan_id)):null;
      const kupe=h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):(t.hayvan_id||'GENEL'));
      const _drugs=t.gorev_tipi==='TEDAVI_GUN'?(_dayDrugMap[_acik.day_id||'']||[]):[];
      const _teshis=t.gorev_tipi==='TEDAVI_GUN'?(_dayDiseaseMap[_acik.day_id||'']||''):'';
      const _acikMetin=(_acik.label||t.aciklama||'');
      bloklar.push({ type:'normal', task:t, tarih:t.hedef_tarih||'', saat:gorevSaatAnahtari(t),
        hayvanGrup:h?.grup||(t.hayvan_id?'':'GENEL'), kupe, drugs:_drugs, teshis:_teshis,
        arama:[kupe,h?.grup||'',t.gorev_tipi,_acikMetin,_teshis,_drugs.map(d=>d.name).join(' ')].join(' ').toLowerCase() });
    });
    Object.values(grupMap).forEach(g=>{
      g.items.sort((a,b)=>(a.seans.planned_time||'').localeCompare(b.seans.planned_time||''));
      bloklar.push({ type:'seans', grup:g, tarih:g.date||'', saat:(g.items[0]?.seans.planned_time||'').slice(0,5),
        hayvanGrup:g.grupAd||'', kupe:g.animalLabel,
        arama:[g.animalLabel,g.grupAd||'','TEDAVI_SEANS',g.disease||'',g.items.map(it=>it.drugName).join(' ')].join(' ').toLowerCase() });
    });
    /**
     * Verilen saati alırsa onu döndürür, yoksa '�' karakterini döndürür.
     * @param {string} s Girilen saat değeri.
     * @returns {string} Girilen saat veya varsayılan '�' karakteri.
     */
    const _saatK=s=>s||'\uffff'; // saatsizler en sonda (spec §4.1)
    bloklar.sort((a,b)=>
      a.tarih.localeCompare(b.tarih) ||
      _saatK(a.saat).localeCompare(_saatK(b.saat)) ||
      _grupSira(a.hayvanGrup)-_grupSira(b.hayvanGrup) ||
      kuceDogalKarsilastir(a.kupe,b.kupe));
    // F4: arama aktifken limit kalkar (IDB'de tüm gorev_log zaten var)
    const _arama=(srchEl?.value||'').trim().toLowerCase();
    const _secili=_arama?bloklar.filter(b=>b.arama.includes(_arama)):bloklar;
    if(!_secili.length){
      el.innerHTML=_arama
        ?'<div class="empty"><div class="empty-ico">🔍</div>Eşleşen görev bulunamadı</div>'
        :'<div class="empty"><div class="empty-ico">✅</div>Bu filtrede görev yok</div>';
      return;
    }
    const _limitSecili=_arama?_secili:_secili.slice(0,200);
    let _html=''; let _curSaat=null; let _curGrupKey='';
    _limitSecili.forEach(b=>{
      const saatKey=b.saat||'';
      if(saatKey!==_curSaat){
        _curSaat=saatKey; _curGrupKey='';
        const _n=_secili.filter(x=>(x.saat||'')===saatKey).length;
        _html+='<div style="display:flex;align-items:center;gap:8px;margin:'+(saatKey===_limitSecili[0].saat?'2px':'12px')+' 2px 4px;font-size:.74rem;font-weight:800">'+
          '<span style="color:var(--blue)">'+(saatKey?'⏰ '+esc(saatKey):'⏰ Saatsiz')+'</span>'+
          '<span style="flex:1;height:1px;background:var(--card3)"></span>'+
          '<span style="color:var(--ink3);font-weight:700">'+_n+' görev</span></div>';
      }
      const grupEtiket=b.hayvanGrup||'Diğer';
      const gKey=saatKey+'|'+b.tarih+'|'+grupEtiket;
      if(gKey!==_curGrupKey){
        _curGrupKey=gKey;
        const _n=_secili.filter(x=>(x.saat||'')===saatKey&&(x.hayvanGrup||'')===grupEtiket).length;
        _html+='<div style="margin:4px 2px 2px;font-size:.76rem;font-weight:800;color:'+(grupEtiket==='GENEL'?'var(--ink3)':'var(--green)')+'">'+
          (grupEtiket==='GENEL'?'📋':'🐄')+' '+esc(grupEtiket)+
          ' <span style="color:var(--ink3);font-weight:600;font-size:.68rem">'+_n+'</span></div>';
      }
      if(b.type==='seans'){
        const g=b.grup;
        _html+='<div style="margin-left:8px">'+renderSeansGrupAyrac(g)+'<div class="seans-grup-wrap">'+
          g.items.map(it=>renderSeansGorevKart(it.task,it.seans,{drugName:it.drugName,date:g.date})).join('')+'</div></div>';
        return;
      }
      const t=b.task;
      const _diff=Math.floor((new Date(t.hedef_tarih)-Date.now())/86400000);
      const _clsBase=_diff<=3?'near':'';
      const _clsMid=t.hedef_tarih===today?'soon':_clsBase;
      const cls=t.hedef_tarih<today?'late':_clsMid;
      _html+='<div style="margin-left:8px">'+renderTask(t,cls,allSubs.filter(s=>s.parent_id===t.id),b.drugs,b.teshis)+'</div>';
    });
    // F1 Task 3: seçim çubuğu görev listesi başında — index.html'deki statik
    // konteyner (Task 5) mevcutsa dinamik çubuk çizilmez (id çakışması yok);
    // konteyner nerede olursa olsun görünürlük/sayaç TEK _cokluSecimBarGuncelle'den.
    if(!document.getElementById('k-coklu-bar')) _html=_cokluSecimBarHtml()+_html;
    el.innerHTML=_html;
    _cokluSecimBarGuncelle();
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
  });
}
// B34: görev çipinde ham stok UUID'si yerine ürün adı (bulunamazsa kısaltılmış id)
/**
 * Verilen stok ID'ye ait ürünün adını döndürür.
 * @param {string} stokId - Ürünün benzersiz kimlik numarası.
 * @returns {string} Ürün adı, ID'nin ilk 8 karakteri veya boş string.
 */
function _stokAdi(stokId){
  if(!stokId) return '';
  const s=(getState('stock')||[]).find(x=>x.id===stokId);
  return s?.urun_adi || (stokId.length>8 ? stokId.slice(0,8)+'…' : stokId);
}
// Aşı görevinden aşıyı çözümle: (1) stok_id→vaccines.stock_item_id, (2) aciklama ad-öneki.
// Ad-öneki adımı şart: Coglavax/Vac-Sules kataloğunda stock_item_id NULL (2026-06-19 seed
// stok yaratmadı) ve add_vaccination'ın ürettiği ASI_RAPEL görevleri bu aşılarla stok_id'siz doğar.
/**
 * Verilen stok öğesi (t) için vaccines dizisinde eşleşen bir aşı kaydını bulur.
 * Öncelikle stok_id ile eşleşme denir, yoksa açıklama metnindeki aşı simgesi ve başlangıç harfleri ile isim eşleşmesi yapılır.
 * İsim eşleşmesi varsa, en uzun isimli kaydı döndürür.
 * @param {Object} t Aranan stok öğesi nesnesi.
 * @param {Array} vaccines Aşı kayıtlarından oluşan dizi.
 * @returns {Object|null} Eşleşen aşı kaydı veya bulunamazsa null.
 */
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
/**
 * Verilen aşı stokları, mevcut stok satırları ve hareket kayıtları üzerinden, iptal edilmiş veya stok ID'si olmayan hareketleri dikkate alarak her bir aşı için kalan stok miktarını hesaplar.
 * @param {Array} vaccines Aşı kayıtlarının bulunduğu dizi.
 * @param {Array} stockRows Mevcut stok satırlarının bulunduğu dizi.
 * @param {Array} hareketRows Stok hareket kayıtlarının bulunduğu dizi.
 * @returns {Object} Her aşı ID'si için kalan stok miktarını (sayı) veya hesaplanamıyorsa null değerini içeren bir nesne.
 */
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
/**
 * Verilen stok öğesi ID'si olan öğe için kalan stok miktarını hesaplayıp döndürür.
 * @param {Object} vax Stok öğesi bilgilerini içeren nesne (stock_item_id ve id alanları gereklidir).
 * @returns {number|null} Hesaplanan kalan stok miktarı veya geçerli parametre yoksa null.
 */
async function _asiStokKalan(vax){
  if(!vax||!vax.stock_item_id) return null;
  const [stockRows,hmvs]=await Promise.all([getData('stok'),getData('stok_hareket')]); // IDB store adı 'stok'
  return _asiStokKalanlar([vax],stockRows,hmvs)[vax.id];
}
// Detaydaki aşı formu alanlarını (ad + doz) verilen aşıya kurar; vax null ise sıfırlar.
/**
 * Vaksın adını, dozunu, birim bilgilerini ve ilgili metin alanlarını günceller.
 * @param {Object} vax Güncellenecek vaksın nesnesi.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
/**
 * Toplu aşı görevlerini belirtilen tarihte sırayla uygular; başarılı olanlar varsa ana görevi tamamlar, tabloları yeniler ve arayüzü günceller. Hiç çocuk görev yoksa veya hiçbiri uygulanamazsa hata bildirimi gösterir.
 * @returns {Promise<void>} İşlem sonucunda döndürülen değer yok.
 * @rpc asi_planli_tamamla, gorev_tamamla
 */
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
/**
 * Verilen vaxId'ye sahip aşı kaydını bulup form elemanına ayarlar.
 * @param {string} vId Aranan aşı kaydının ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function tdAsiVaxSec(vId){
  _curTaskVaccineId=vId||null;
  if(!vId){ _asiFormVaxKur(null); return; }
  try{
    const vaccines=await getData('vaccines');
    _asiFormVaxKur((vaccines||[]).find(v=>v.id===vId)||null);
  }catch(e){ console.warn('vaccine lookup:',e.message); }
}


// ──────────────────────────────────────────
// ──────────────────────────────────────────
// P5: PG kapısı modalı (dinamik bottom-sheet; modal-router invariant: pushState)
// _pgKapiHata(e, tekrarDene) — PG_KAPI hatasını yakalar, koda göre ekran verir.
// tekrarDene(onay, gerekce): çağıran tarafın aynı işlemi onay parametreleriyle
// yeniden gönderen kapanışı. Gebe (BLOCK_PREGNANT) için "yine de uygula" YOK.
/**
 * PG güvenlik kapısı arayüzünü gösterir; kod durumuna göre uyarı mesajı, form alanları ve butonlar oluşturur.
 * @param {string} kodTam Tam kod adı (örn: 'PG_KAPI:BLOCK_PREGNANT').
 * @param {string} detayJson JSON formatında detay verisi (kupe_no, tohumlama_tarihi vb.).
 * @param {boolean} tekrarDene İşlemi tekrar deneme bayrağı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _pgKapiAc(kodTam, detayJson, tekrarDene){
  const kod = String(kodTam||'').replace('PG_KAPI:','');
  let detay = {};
  try { detay = JSON.parse(detayJson || '{}'); } catch(e) {}
  const kz = detay.kupe_no ?? detay.kupe ?? '';

  let box = document.getElementById('pg-kapi-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'pg-kapi-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:420;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) _pgKapiKapat(); };

  let body = '';
  if (kod === 'BLOCK_PREGNANT') {
    body = `<div style="font-size:.85rem;line-height:1.5">🔴 <b>Gebe inekte PG uygulanamaz</b>${kz?` (${esc(kz)})`:''}.<br><span style="font-size:.72rem;color:var(--ink3)">Gebelik sonlandırma ayrı, yetkili klinik işlemdir — bu ekrandan geçmez.</span></div>
      <button class="btn" style="width:100%;margin-top:14px;padding:10px;font-weight:700" onclick="_pgKapiKapat()">Tamam</button>`;
  } else if (kod === 'REQUIRE_ACK_PENDING') {
    body = `<div style="font-size:.85rem;line-height:1.5">⚠️ <b>Son tohumlama sonucu Bekliyor</b>${kz?` — ${esc(kz)}`:''}${detay.tohumlama_tarihi?` · ${fmtTarih(detay.tohumlama_tarihi)}`:''}${detay.deneme_no?` · deneme ${esc(String(detay.deneme_no))}`:''}.<br><span style="font-size:.72rem;color:var(--ink3)">PG gebeliği sonlandırabilir. "Boş ata ve uygula" tohumlamayı Boş yapıp PG'yi aynı zincirde uygular.</span></div>
      <label style="font-size:.7rem;font-weight:600;display:block;margin:10px 0 4px">Gerekçe *</label>
      <input id="pg-kapi-gerekce" class="fi" placeholder="Örn: 35. gün kontrolü negatif" oninput="document.getElementById('pg-kapi-onayla').disabled=!this.value.trim()">
      <div style="display:flex;gap:8px;margin-top:14px">
        <button class="btn" style="flex:1;padding:10px;background:var(--card2);color:var(--ink)" onclick="_pgKapiKapat()">Vazgeç</button>
        <button id="pg-kapi-onayla" class="btn" style="flex:2;padding:10px;font-weight:700" disabled onclick="_pgKapiBosAtaUygula()">Boş ata ve uygula</button>
      </div>`;
  } else if (kod === 'BLOCK_CATALOG_UNRESOLVED') {
    body = `<div style="font-size:.85rem;line-height:1.5">⚠️ <b>Ürünün PG katalog bağı belirsiz.</b><br><span style="font-size:.72rem;color:var(--ink3)">Katalog kaydı düzeltilmeden uygulama yapılamaz (yöneticiye bildirin).</span></div>
      <button class="btn" style="width:100%;margin-top:14px;padding:10px;font-weight:700" onclick="_pgKapiKapat()">Tamam</button>`;
  } else {
    body = `<div style="font-size:.85rem">İşlem reddedildi: ${esc(kodTam || 'PG_KAPI')}</div>
      <button class="btn" style="width:100%;margin-top:14px;padding:10px;font-weight:700" onclick="_pgKapiKapat()">Tamam</button>`;
  }

  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.95rem;margin-bottom:10px">🚫 PG Güvenlik Kapısı</div>
    ${body}
  </div>`;
  document.body.appendChild(box);
  history.pushState({pg_kapi:true}, '', '');
  window.__pgKapiTekrar = tekrarDene || null;
  window.__pgKapiToh = detay.tohumlama_id || null;
}
/**
 * PG_KAPI hata mesajını analiz eder, hata kodunu ve detayını ayırarak ilgili fonksiyonu çağırır.
 * @param {Error|Object} e Hata nesnesi veya hata mesajı string'i.
 * @param {boolean} tekrarDene Hata durumunda tekrar deneme işlemini tetikleyip tetiklemeyeceğini belirten bayrak.
 * @returns {boolean} Hata mesajı PG_KAPI formatında ise true, değilse false döndürür.
 */
function _pgKapiHata(e, tekrarDene){
  const msg = e?.message || String(e);
  const m = /^(PG_KAPI:[A-Z_]+):([\s\S]*)$/.exec(msg);
  if (!m) return false;         // PG_KAPI değil — çağıran normal hata akışına dönsün
  _pgKapiAc(m[1], m[2], tekrarDene);
  return true;
}
/**
 * Kapı modal kutusunu DOM'dan kaldırır, ilgili global değişkenleri temizler ve geçmişte kapı durumu kayıtlıysa bir adım geri gider.
 * @returns {void} Döndürülen değer yok.
 */
function _pgKapiKapat(){
  const box = document.getElementById('pg-kapi-bs');
  if (box) box.remove();
  window.__pgKapiTekrar = null; window.__pgKapiToh = null;
  if (history.state?.pg_kapi) { globalThis._modalBackGuard = true; history.back(); }
}
// [Boş ata ve uygula]: tohumlama_sonuc_bos → aynı zincirde uygulama p_pg_onay=true
// (tek ekranda; ikinci dokunuş yarışı buton kilidiyle engellenir — idempotency sunucuda)
/**
 * PG kapısında "Boş ata ve uygula" işlemini yürütür: gerekçeyi doğrular, tohumlamayı Boş yapıp ardından PG'yi uygulamaya çalışır; hata durumunda butonu yeniden etkinleştirir.
 * @returns {Promise<void>} İşlem sonunda değer döndürmez; başarıda kapı modalı kapatılır, hata durumunda hata mesajı gösterilir ve buton geri açılır.
 * @rpc tohumlama_sonuc_bos
 */
async function _pgKapiBosAtaUygula(){
  const btn = document.getElementById('pg-kapi-onayla');
  const gerekce = document.getElementById('pg-kapi-gerekce')?.value?.trim() || '';
  if (!gerekce || !window.__pgKapiToh || !window.__pgKapiTekrar) return;
  if (btn) { btn.disabled = true; btn.textContent = 'İşleniyor…'; }
  try {
    const r = await rpc('tohumlama_sonuc_bos', { p_tohumlama_id: window.__pgKapiToh, p_notlar: 'PG öncesi değerlendirme: ' + gerekce });
    toast('Tohumlama Boş yapıldı — PG uygulanıyor…');
    // T3b: tekrar çağrısı hata atarsa modal AÇIK kalır — yarım durum görünür,
    // aynı butonla yalnız-PG-retry mümkün (rpc ok:false gövdesi throw'a dönüşür:
    // eski ölü `if (!r?.ok)` dalı kaldırıldı — T8)
    try {
      await window.__pgKapiTekrar(true, gerekce);
    } catch (e3) {
      toast('⚠️ Tohumlama Boş kaydedildi, PG uygulanamadı — aynı butonla tekrar deneyin: ' + (getUserMessage ? getUserMessage(e3) : e3.message), true);
      if (btn) { btn.disabled = false; btn.textContent = 'Boş ata ve uygula'; }
      return;
    }
    _pgKapiKapat();
  } catch (e2) {
    toast('❌ ' + getUserMessage(e2), true);
    if (btn) { btn.disabled = false; btn.textContent = 'Boş ata ve uygula'; }
  }
}

// ──────────────────────────────────────────
// P6: Erteleme modalı — mevcut tarih giriş kalıbı + pencere canlı önizleme
// E1-UI: genel erteleme — tip kilidi kural cache'den (js'e tip listesi
// YAZILMAZ); pencere önizlemesi YALNIZ pencere_kurali='tohumlama' tiplerinde.
/**
 * Görevi ertelemek için modal penceresini açar; offline modda veya görevin ertelenememesi durumunda işlemi iptal eder.
 * @param {string} gorevId Ertelenecek görevin benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @olay change, input
 */
function _erteleModal(gorevId){
  // E6: offline'da modal açılmaz (buton zaten gizli — render sonrası
  // bağlantı düşmesi yarışı için giriş guard'ı)
  if (_ertelemeOfflineGuard('gorev-ertele')) return;
  (async () => {
    const t = (await getData('gorev_log')).find(g => g.id === gorevId);
    // E1-UI: kayıtsız/ertelenemez tip → aynı "Görev ertelenemez" toast'u
    // (fail-closed ayna — DB gorev_ertele_kural_get default'u ile aynı karar)
    const kural = t ? ertelemeKuralGetir(t.gorev_tipi) : null;
    if (!t || t.tamamlandi || t.iptal || !kural || !kural.ertelenebilir) { toast('Görev ertelenemez', true); return; }
    const bugunIso = new Date().toISOString().slice(0,10);
    let box = document.getElementById('ertele-bs');
    if (box) box.remove();
    box = document.createElement('div');
    box.id = 'ertele-bs';
    box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:420;display:flex;align-items:flex-end';
    box.onclick = e => { if (e.target === box) _erteleKapat(); };
    box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
      <div style="font-weight:800;font-size:.95rem;margin-bottom:4px">🗓️ Görevi Ertele</div>
      <div style="font-size:.72rem;color:var(--ink3);margin-bottom:12px">Mevcut hedef: ${fmtTarih(t.hedef_tarih)} ${(t.hedef_saat||'').slice(0,5)}</div>
      <div style="display:flex;gap:8px;margin-bottom:6px">
        <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Yeni tarih</label>
          <input id="ert-tarih" type="text" placeholder="gg.aa.yyyy" value="${bugunIso}" class="fi" style="width:100%"></div>
        <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Saat (boş = mevcut)</label>
          <input id="ert-saat" type="time" class="fi" style="width:100%" placeholder="${(t.hedef_saat||'09:00').slice(0,5)}"></div>
      </div>
      <div id="ert-onizleme" style="font-size:.72rem;color:var(--blue);margin:8px 0"></div>
      <button id="ert-btn" class="btn" style="width:100%;padding:10px;font-weight:700" onclick="_erteleKaydet('${escAttr(gorevId)}')">Ertele</button>
    </div>`;
    document.body.appendChild(box);
    history.pushState({ertele:true}, '', '');
    /**
     * Belirtilen tarih ve saat değerlerini alarak onizleme alanına kaydedilecek zaman aralığını gösterir.
     * Eğer pencere kuralı 'tohumlama' ise tarih ve saati yuvarlar, aksi takdirde verilen değerleri kullanır.
     * @returns {void}
     */
    const onizle = () => {
      const gun = _ovsyncTarihOku(document.getElementById('ert-tarih')?.value);
      const saat = (document.getElementById('ert-saat')?.value) || (t.hedef_saat||'09:00:00').slice(0,5);
      const o = document.getElementById('ert-onizleme');
      // E1-UI: pencereYuvarla yalnız pencere_kurali='tohumlama' tiplerinde
      // (DB _tohumlama_pencere aynası); diğer tiplerde verilen saat olduğu gibi.
      if (o && gun) o.textContent = kural.pencere_kurali === 'tohumlama'
        ? 'Kaydedilecek: ' + pencereYuvarla(gun + ' ' + saat.slice(0,5)) + ' (pencere yuvarlaması)'
        : 'Kaydedilecek: ' + gun + ' ' + saat.slice(0,5);
    };
    document.getElementById('ert-tarih')?.addEventListener('change', onizle);
    document.getElementById('ert-saat')?.addEventListener('input', onizle);
    onizle();
  })();
}
/**
 * 'ertele-bs' ID'li elemanı DOM'dan kaldırır ve geçmişte 'ertele' durumu varsa modal koruma bayrağını aktif ederek geri gider.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _erteleKapat(){
  const box = document.getElementById('ertele-bs');
  if (box) box.remove();
  if (history.state?.ertele) { globalThis._modalBackGuard = true; history.back(); }
}
/**
 * Görev ID'si verildiğinde, geçerli tarih ve saat bilgilerini kontrol edip görevi erteler.
 * Geçmiş tarih seçimi veya bağlantı kesilmesi durumunda işlemi iptal eder ve kullanıcıya bildirim gösterir.
 * Başarılı erteleme durumunda yeni hedef tarih/saat, toplam erteleme günü sayısı ve varsa uyarı mesajını gösterir.
 * @param {string} gorevId Ertelenecek görevin benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc gorev_ertele
 */
async function _erteleKaydet(gorevId){
  // E6: modal açıkken bağlantı düşerse Ertele tıklaması RPC'ye ulaşmaz
  if (_ertelemeOfflineGuard('gorev-ertele-kaydet')) return;
  const btn = document.getElementById('ert-btn');
  const tarih = _ovsyncTarihOku(document.getElementById('ert-tarih')?.value);
  const saat = document.getElementById('ert-saat')?.value || null;
  if (!tarih) { toast('Tarih gg.aa.yyyy biçiminde girin', true); return; }
  if (tarih < new Date().toISOString().slice(0,10)) { toast('Geçmiş tarih seçilemez', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'İşleniyor…'; }
  try {
    // E1-UI: genel RPC (imza tohumlama_gorev_ertele ile aynı; cevap alanları
    // toplam_erteleme_gun/uyari dahil birebir — D18 gösterimi aşağıda)
    const r = await rpc('gorev_ertele', { p_gorev_id: gorevId, p_yeni_tarih: tarih, p_yeni_saat: saat });
    toast('✅ Ertelendi → ' + fmtTarih(r.hedef_tarih) + ' ' + (r.hedef_saat||'').slice(0,5)
      + ((r.toplam_erteleme_gun|0) > 0 ? ' · toplam ' + r.toplam_erteleme_gun + ' gün erteleme' : '')
      + (r.uyari ? ' · ⚠️ ' + r.uyari : ''));
    _erteleKapat();
    loadTasks(_curTaskFilter||'today');
  } catch (e) {
    toast('❌ ' + getUserMessage(e), true);
    if (btn) { btn.disabled = false; btn.textContent = 'Ertele'; }
  }
}

// ──────────────────────────────────────────
// P7: Toplu PG sonucu modalı — applied/blocked/requires_ack; tekrar gönderim
// YALNIZ requires_ack işaretli alt kümesi (applied asla yeniden gönderilmez).
/**
 * Toplu uygulama sonucunu modal penceresi olarak gösterir, engellenenleri listeler, onay gerektirenleri işaretlenebilir şekilde sunar ve tekrar gönderme işlemini tetikler.
 * @param {Object} res Toplu işlem sonucunu içeren veri objesi (applied, blocked, requires_ack dizileri içerir).
 * @param {Function|null} tekrarGonder Seçilen kayıtları tekrar göndermek için çağrılacak fonksiyon.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _topluSonucModal(res, tekrarGonder){
  const applied = res?.applied || [];
  const blocked = res?.blocked || [];
  const ack = res?.requires_ack || [];
  let box = document.getElementById('toplu-sonuc-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'toplu-sonuc-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:420;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) _topluSonucKapat(); };
  /**
   * Bir girdiye karşılık gelen hayvanın küpe numarasını bulur; bulunamazsa hayvan kimliğini döndürür.
   * @param {Object|*} h - hayvan_id alanı içeren nesne ya da doğrudan hayvan kimliği.
   * @returns {*} Eşleşen hayvanın kupe_no değeri; bulunamazsa kullanılan hayvan kimliği.
   */
  const kz = h => getState('animals').find(a => a.id === (h.hayvan_id||h))?.kupe_no || (h.hayvan_id||h);
  const ackHtml = ack.length ? `<div style="font-weight:800;font-size:.78rem;color:#b8860b;margin:12px 0 6px">⚠️ Onay gerekli (${ack.length})</div>
    ${ack.map(h => `<label style="display:flex;gap:8px;align-items:center;font-size:.78rem;margin-bottom:6px">
      <input type="checkbox" class="ts-ack" value="${escAttr(h.hayvan_id||'')}">
      <span>${esc(kz(h))}${h.tohumlama_tarihi?' — '+fmtTarih(h.tohumlama_tarihi)+(h.deneme_no?' · deneme '+h.deneme_no:''):''}</span>
      <input class="ts-gerekce" data-h="${escAttr(h.hayvan_id||'')}" placeholder="gerekçe" style="flex:1;min-width:0;padding:4px 8px;border-radius:6px;border:1px solid var(--border);font-size:.7rem">
    </label>`).join('')}
    <button id="ts-tekrar" class="btn" style="width:100%;margin-top:10px;padding:10px;font-weight:700" onclick="_topluTekrarGonder()">Seçilenleri tekrar gönder</button>` : '';
  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:80vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.95rem;margin-bottom:10px">💊 Toplu Uygulama Sonucu</div>
    ${applied.length?`<div style="font-weight:800;font-size:.78rem;color:var(--green);margin-bottom:6px">✅ Uygulandı (${applied.length})</div><div style="font-size:.74rem;color:var(--ink3);margin-bottom:6px">${applied.map(h=>esc(kz(h))).join(', ')}</div>`:''}
    ${blocked.length?`<div style="font-weight:800;font-size:.78rem;color:var(--red2);margin:12px 0 6px">🚫 Engellendi (${blocked.length})</div>
      ${blocked.map(h=>`<div style="font-size:.74rem;margin-bottom:4px">${esc(kz(h))} — ${esc(h.code||h.sebep||'engellendi')}</div>`).join('')}`:''}
    ${ackHtml}
    <button class="btn" style="width:100%;margin-top:14px;padding:10px;background:var(--card2);color:var(--ink)" onclick="_topluSonucKapat()">Kapat</button>
  </div>`;
  document.body.appendChild(box);
  history.pushState({toplu_sonuc:true}, '', '');
  window.__topluTekrar = tekrarGonder || null;
}
function _topluSonucKapat(){
  const box = document.getElementById('toplu-sonuc-bs');
  if (box) box.remove();
  window.__topluTekrar = null;
  if (history.state?.toplu_sonuc) { globalThis._modalBackGuard = true; history.back(); }
}
/**
 * İşaretli onay kutularından seçilen hayvanlar için toplu tekrar gönderim işlemi yapar; gerekçe kontrolü yapar, butonu devre dışı bırakır ve işlem sonucuna göre tabloları yeniler.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen, değer döndürmeyen promise.
 */
async function _topluTekrarGonder(){
  const secilen = [...document.querySelectorAll('.ts-ack:checked')].map(c => c.value);
  if (!secilen.length) { toast('En az bir hayvan seçin', true); return; }
  const gerekceler = {};
  document.querySelectorAll('.ts-gerekce').forEach(g => { if (g.value.trim()) gerekceler[g.dataset.h] = g.value.trim(); });
  const eksik = secilen.filter(id => !gerekceler[id]);
  if (eksik.length) { toast('Seçilenlerin hepsi için gerekçe gerekli', true); return; }
  const btn = document.getElementById('ts-tekrar');
  if (btn) { btn.disabled = true; btn.textContent = 'İşleniyor…'; }
  try {
    const r = await window.__topluTekrar(secilen, gerekceler);
    toast(`Tekrar gönderim tamam (uygulanan: ${r?.applied?.length ?? r?.success ?? '?'})`);
    _topluSonucKapat();
    await pullTables(['gorev_log','islem_log','stok','stok_hareket']).catch(()=>{});
    loadTasks(_curTaskFilter||'today');
  } catch (e) {
    toast('❌ ' + getUserMessage(e), true);
    if (btn) { btn.disabled = false; btn.textContent = 'Seçilenleri tekrar gönder'; }
  }
}


// F4: native date YASAK — metin giriş (gg.aa.yyyy ya da yyyy-mm-dd) → 'YYYY-MM-DD' | null
/**
 * Girilen tarih stringini 'GG.AA.YYYY' formatından 'YYYY-AA-GG' formatına dönüştürür.
 * Eğer giriş 'YYYY-AA-GG' formatındaysa orijinal stringi döndürür.
 * Geçersiz tarih formatı ise null döndürür.
 * @param {string} v Girilecek tarih değeri.
 * @returns {string|null} Dönüştürülmüş tarih, orijinal geçerli tarih veya null.
 */
function _ovsyncTarihOku(v){
  const t=String(v||'').trim();
  let m=/^(\d{2})\.(\d{2})\.(\d{4})$/.exec(t);
  if(m) return m[3]+'-'+m[2]+'-'+m[1];
  m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(t);
  if(m) return m[0];
  return null;
}
// ──────────────────────────────────────────
// OVSYNC/PG (PLAN 2026-09-24 P3–P10)
// ──────────────────────────────────────────
// P3: TOHUMLAMA_PLANLI kaynak etiketi (şablon TAI / PG+48s / ilk tohumlama)
/**
 * Görev tipi 'TOHUMLAMA_PLANLI' olan kayıtlar için kaynak değerine göre özel etiket döndürür.
 * Kaynak değeri belirli öneklerle (PG_TOHUMLAMA:, TEDAVI_SABLON_TOHUMLAMA:, ILK-TOH-, ACIK-DISI-) başlıyorsa
 * ilgili renk ve stili içeren HTML pill etiketi döndürür, aksi takdirde boş string döndürür.
 * @param {Object} t Görev tipini ve kaynak değerini içeren nesne.
 * @returns {string} Kaynağa göre oluşturulmuş HTML pill etiketi veya boş string.
 */
function _tohKaynakEtiket(t){
  if(t.gorev_tipi!=='TOHUMLAMA_PLANLI') return '';
  const k=t.kaynak||'';
  if(k.indexOf('PG_TOHUMLAMA:')===0) return '<span class="pill" style="background:rgba(192,50,26,.08);color:#b3541e;border:1px solid rgba(192,50,26,.15)">PG sonrası (+48s)</span>';
  if(k.indexOf('TEDAVI_SABLON_TOHUMLAMA:')===0) return '<span class="pill" style="background:rgba(30,100,200,.08);color:var(--blue);border:1px solid rgba(30,100,200,.15)">Şablon TAI</span>';
  if(k.indexOf('ILK-TOH-')===0||k.indexOf('ACIK-DISI-')===0) return '<span class="pill" style="background:rgba(78,154,42,.1);color:var(--green);border:1px solid rgba(78,154,42,.2)">İlk tohumlama</span>';
  return '';
}
// P3: kalan/gecikmiş gün etiketi (OVSYNC_BASLAT ve TOHUMLAMA_PLANLI)
/**
 * Görev tipinin 'TOHUMLAMA_PLANLI' veya 'OVSYNC_BASLAT' olup, hedef tarihi olan görevler için bugüne kalan gün sayısını hesaplayıp HTML etiketi döndürür.
 * @param {Object} t Görev bilgilerini içeren nesne (hedef_tarih ve gorev_tipi özellikleri gereklidir).
 * @returns {string} Kalan gün sayısını veya 'bugün'/'gecikmiş' durumunu içeren HTML string'i; koşullar sağlanmazsa boş string.
 */
function _kalanGunEtiket(t){
  if(!t.hedef_tarih) return '';
  if(t.gorev_tipi!=='TOHUMLAMA_PLANLI'&&t.gorev_tipi!=='OVSYNC_BASLAT') return '';
  const bugun=new Date(); bugun.setHours(0,0,0,0);
  const h=new Date(t.hedef_tarih+'T00:00:00');
  const gun=Math.round((h-bugun)/86400000);
  if(gun>0) return `<span style="font-size:.62rem;color:var(--ink3)">· ${gun} gün kaldı</span>`;
  if(gun===0) return '<span style="font-size:.62rem;color:#b8860b">· bugün</span>';
  return `<span style="font-size:.62rem;color:var(--red2)">· ${-gun} gün gecikmiş</span>`;
}
// K4 (p5b-fix): OVSYNC_BASLAT başlatma penceresi — hedef güne kalan gün
// (_kalanGunEtiket matematiği: yerel geceyarısı normalize + T00:00:00 ayrıştırma);
// hedef_tarih yoksa null. Pencere hedef−2 gününde açılır (DB 000002 aynası).
/**
 * Verilen hedef tarih ile bugün arasındaki gün farkını hesaplar.
 * @param {Object} t Hedef tarihi içeren nesne, 'hedef_tarih' özelliği gereklidir.
 * @returns {number|null} Bugünden hedef tarihe kadar geçen gün sayısı (tam gün) veya null.
 */
function _ovsyncBaslatPencereGunu(t){
  if(!t?.hedef_tarih) return null;
  const bugun=new Date(); bugun.setHours(0,0,0,0);
  const h=new Date(t.hedef_tarih+'T00:00:00');
  return Math.round((h-bugun)/86400000);
}
// P3/P4: OVSYNC_BASLAT kart butonları — [Başlat] atomik RPC, [İptal] mevcut PATCH yolu
// P3/P4: OVSYNC_BASLAT kart butonları — [Başlat] atomik RPC, [İptal] mevcut PATCH yolu
// S1 (ortak yardımcı): OVSYNC_BASLAT kısır-kilit + Başlat/İptal markup'ı — görev kartı
// (_ovsyncBaslatBtnHtml) ve protokol paneli (_ovUyariSatirHtml) TEK buradan alır;
// kopylar drift etmişti (başlatılamaz / üreme planı yok) — kilit metni tek: "başlatılamaz".
// stopProp=false: çağıran sarmalayıcı zaten event.stopPropagation() yapıyor (panel satırı).
/**
 * Kısır (kisir) durumu, pencere süresi (pencereGun) veya erken çağrı kısıtlamaları varsa ilgili uyarı mesajını döndürür; aksi takdirde başlatma butonu ve iptal butonunu döndürür.
 * @param {boolean} kisir Kısır durumu olup olmadığını belirten bayrak.
 * @param {string} gorevId Görev kimliği.
 * @param {string} hayvanId Hayvan kimliği.
 * @param {boolean} stopProp Olayı durdurma (stopPropagation) davranışını etkinleştirecek mi?
 * @param {number} pencereGun Pencere süresi (gün cinsinden).
 * @returns {string} Duruma göre uyarı metni veya başlatma/iptal butonlarını içeren HTML string.
 */
function _ovsyncBaslatKilitHtml(kisir, gorevId, hayvanId, stopProp, pencereGun){
  const _ipt=`<button data-g="${escAttr(gorevId)}" onclick="${stopProp?'event.stopPropagation();':''}ovsyncIptal(this.dataset.g)" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`;
  if(kisir) return `<span style="font-size:.62rem;font-weight:700;color:var(--amber)">💲 Kısır işaretli — başlatılamaz</span>${_ipt}`;
  // K4 (p5b-fix): pencere henüz kapalı — ▶ Başlat ÇİKMEZ; RPC erken çağrı kapısı
  // (000002 OVSYNC_ERKEN) UI katında aynalanır. Kısır kilidi önceliği korunur.
  if(typeof pencereGun==='number' && pencereGun>2) return `<span style="font-size:.62rem;font-weight:700;color:var(--ink3)">📅 ${pencereGun-2} gün sonra başlatılabilir</span>${_ipt}`;
  return `<button data-g="${escAttr(gorevId)}" data-h="${escAttr(hayvanId)}" onclick="event.stopPropagation();ovsyncBaslat(this.dataset.g,this.dataset.h)" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--green);background:rgba(78,154,42,.12);color:var(--green);cursor:pointer">▶ Başlat</button>${_ipt}`;
}
// S1: kisir hayvanda Başlat YOK, kilitli rozet VAR; ✕ her durumda çizilir.
/**
 * Görev tipi 'OVSYNC_BASLAT' olan, tamamlanmamış ve iptal edilmemiş hayvan kayıtları için
 * kilit durumuna uygun HTML içeriği döndürür.
 * @param {Object} t Görev tipi, tamamlanma durumu, iptal durumu ve hayvan ID içeren nesne.
 * @returns {string} Kilit durumuna uygun HTML içeriği veya boş string.
 */
function _ovsyncBaslatBtnHtml(t){
  if(t.gorev_tipi!=='OVSYNC_BASLAT'||t.tamamlandi||t.iptal) return '';
  const _h=(typeof getState==='function'?getState('animals'):[]).find(a=>a.id===t.hayvan_id);
  return _ovsyncBaslatKilitHtml(!!(_h&&_h.kisir), t.id, t.hayvan_id, true, _ovsyncBaslatPencereGunu(t));
}
// E1-UI: genel [🗓️ Ertele] butonu — kural cache'den (JS'e tip listesi YAZILMAZ):
// ertelenebilir tipteki AÇIK görev kartlarında çizilir (OVSYNC_BASLAT kartında
// [Başlat] yanında); TEDAVI_GUN/TEDAVI_SEANS (kural f) ve kayıtsız tipler
// BUTONSUZ — fail-closed ayna (DB gorev_ertele_kural_get default'u).
// E6: offline'da ÜRETİLMEZ; data-ertele rozeti ertelemeBtnGuncelle'in
// canlı-DOM görünürlük taramasına girer.
/**
 * Görev detayına göre erteleme kuralı kontrol edilerek, kural geçerliyse ve online modda ise bir erteleme butonu HTML'i döndürür.
 * @param {Object} t Görev detay objesi (tamamlandi, iptal, gorev_tipi, id özellikleri içerir).
 * @returns {string} Geçerli koşullar sağlanırsa erteleme butonu HTML'i, aksi takdirde boş string.
 */
function _erteleBtnHtml(t){
  if(t.tamamlandi||t.iptal) return '';
  const kural=ertelemeKuralGetir(t.gorev_tipi);
  if(!kural||!kural.ertelenebilir) return '';
  if(!_ertelemeOnline()) return '';
  return `<button data-g="${escAttr(t.id)}" data-ertele="1" onclick="event.stopPropagation();_erteleModal(this.dataset.g)" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid var(--blue);background:rgba(30,100,200,.08);color:var(--blue);cursor:pointer">🗓️ Ertele</button>`;
}
// T10: rozet = protokol_eksik_tara aktif sayısı + ovsync_baslat_uyarilari sayısı (tek rozet birleştirme)
/**
 * İki tam sayıyı alıp onları toplayarak döndürür.
 * @param {number} n Toplanacak ilk sayı.
 * @param {number} m Toplanacak ikinci sayı.
 * @returns {number} İki sayının toplamı.
 */
function _rozetTopla(n, m){ return (n|0) + (m|0); }
// O11: PLAN Europe/Istanbul der — Türkiye kalıcı +03 (DST yok); cihaz diliminden bağımsız
/**
 * Verilen tarih ve saati Istanbul (UTC+3) zaman dilimine göre ISO 8601 dizgisine dönüştürür.
 * @param {string} gun - 'YYYY-AA-GG' biçiminde tarih dizgisi.
 * @param {string} [saat] - 'SS:DD' biçiminde saat dizgisi; verilmezse '12:00' kullanılır.
 * @returns {string} UTC+3'e göre ISO 8601 biçiminde tarih-saat dizgisi.
 */
function _istanbulAnIso(gun, saat){ return new Date(gun + 'T' + (saat || '12:00') + ':00+03:00').toISOString(); }

// P4/P10: OVSYNC_BASLAT başlatma — atomik zincir RPC + detaylı bildirim
// S4/N2: hayvanId opsiyonel — bildirim/banner hayvan kartına gider (boşsa eski davranış)
/**
 * Belirtilen görev ID'si için Ovsynch protokolünü başlatır, durum bildirimlerini gösterir ve ilgili tablo verilerini günceller.
 * @param {string} gorevId - Protokol başlatılacak görevin kimliği.
 * @param {string} hayvanId - İşlem yapılacak hayvanın kimliği.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc start_first_service_protocol
 */
async function ovsyncBaslat(gorevId, hayvanId){
  if(!gorevId) return;
  try{
    const r=await rpc('start_first_service_protocol',{p_gorev_id:gorevId});
    if(r&&r.atlandi){ toast('Atlandı: '+r.atlandi,true); }
    else if(r&&r.zaten){ toast('Protokol zaten başlatılmış'); }
    else{
      toast('✅ Ovsynch-56 başlatıldı — TAI hedefi '+fmtTarih(r.baslangic?new Date(new Date(r.baslangic).getTime()+10*86400000).toISOString().slice(0,10):''));
      // P10/B1: detaylı bildirim (izin varsa); panel kalıcı kaynak
      _ovsyncBildirim('İlk tohumlama protokolü başlatıldı','Ovsynch-56 seansları açıldı. TAI hedefi: '+fmtTarih(r.baslangic?new Date(new Date(r.baslangic).getTime()+10*86400000).toISOString().slice(0,10):''), hayvanId);
    }
    await pullTables(['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','gorev_log','stok','stok_hareket']).catch(()=>{});
    closeM('m-task-det'); updateTaskBadge(); loadTasks(_curTaskFilter||'today',null,{skipPull:true}); loadDash();
    window.__protokolUyarilar=null;   // protokol ekranı taze veriyle açılsın
  }catch(e){ toast('❌ '+getUserMessage(e),true); }
}
// E4-UI (erteleme-genel): protokol iptali — vaka bağlamına göre iki dal.
//  A) Hayvanın AKTİF protokol vakası VAR → rpc('protokol_iptal'): vaka + kalan
//     görev/seans/gün kapanışı + stok iadesi + instance kapanışı + isteğe bağlı
//     TEK yeniden-başlat görevi (onay akışı _protokolIptalAkisi'nda).
//  B) Vaka YOK (önü-başlangıç OVSYNC_BASLAT — × butonunun asıl durumu; vaka
//     start_first_service_protocol anında açılır, 000017:132) →
//     rpc('gorev_tamamla', {p_iptal:true}) T5 dalı: görev kapanır + audit
//     yazılır. Eski REST PATCH yolu KALKTI (offline kuyruğa REST bypass yazma
//     yok). Not: önü-başlangıç rotasının instance'ı aktif kalır — bu duruma
//     özel DB tarafında RPC yok (kırıntı decision 2026-09-25).
/**
 * Belirtilen görev ID'sine sahip görevi iptal eder; aktif protokol vaka bulunursa iptal akışını tetikler, yoksa kullanıcı onayı alarak görevi sonlandırır.
 * @param {string} gorevId İptal edilecek görevin benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc gorev_tamamla
 */
async function ovsyncIptal(gorevId){
  if(_ertelemeOfflineGuard('protokol-iptal')) return;   // E6: online-only (plan 3c)
  if(!gorevId) return;
  let t=null;
  try{ t=(await getData('gorev_log')).find(g=>g.id===gorevId)||null; }catch(e){}
  if(!t){ toast('Görev bulunamadı',true); return; }
  // Vaka bağlamı: aynı hayvanın AKTİF protokol vakası (başlamış zincir;
  // bayat kart yarışında × buraya düşer)
  let vaka=null;
  try{ vaka=(await getData('cases')).find(c=>c.animal_id===t.hayvan_id&&c.status==='active'&&c.protocol_family)||null; }catch(e){}
  if(vaka) return _protokolIptalAkisi(vaka);
  // B dalı: önü-başlangıç görev iptali — RPC + audit (eski PATCH yolu yok)
  if(!confirm('İlk tohumlama görevi iptal edilsin mi?')) return;
  try{
    const r=await rpc('gorev_tamamla',{p_gorev_id:gorevId,p_iptal:true});
    toast(r&&r.mesaj?r.mesaj:'Görev iptal edildi');
    updateTaskBadge(); loadTasks(_curTaskFilter||'today');
  }catch(e){ toast('❌ '+getUserMessage(e),true); }
}
// E4-UI A dalı: 'Protokolü iptal et' onay akışı — iptal edilecekler özeti
// (açık gün/seans sayısı + stok iadesi bilgisi) → isteğe bağlı yeniden başlat
// (p_yeniden_baslat) → RPC → sonuç toast + etkilenen tabloların pull'ı.
/**
 * Bir protokol vakasını onay alarak iptal eder; açık tedavi günü ve seans sayısını gösterir, RPC ile iptal işlemini gerçekleştirir ve ilgili tabloları/arayüzü tazeler.
 * @param {Object} vaka İptal edilecek protokol vakası kaydı; en azından id özelliğini içermelidir.
 * @returns {Promise<boolean|undefined>} Başarı durumunda true döner; kullanıcı onay vermezse ya da RPC hatası oluşursa döndürmez (undefined).
 * @rpc protokol_iptal
 */
async function _protokolIptalAkisi(vaka){
  let acikGun=0, acikSeans=0;
  try{
    acikGun=(await idbGetAll('treatment_days')).filter(td=>td.case_id===vaka.id&&!td.tamamlandi).length;
    acikSeans=(await idbGetAll('treatment_day_uygulamalar')).filter(s=>s.case_id===vaka.id&&!s.uygulanmadi&&!s.uygulama_tamamlandi_at).length;
  }catch(e){}
  if(!confirm(`Protokol vakası iptal edilsin mi?\n\nKapanacak: ${acikGun} açık tedavi günü, ${acikSeans} uygulanmamış seans.\nKullanılmayan ilaçlar stoğa iade edilir.`)) return;
  const yeniden=confirm('Yeniden başlat görevi (OVSYNC_BASLAT) oluşturulsun mu?');
  try{
    const r=await rpc('protokol_iptal',{p_vaka_id:vaka.id,p_yeniden_baslat:!!yeniden,p_not:null});
    toast('✅ Protokol iptal edildi — '+(r.kapanan_gorev|0)+' görev, '+(r.kapanan_seans|0)+' seans kapandı'
      +((r.iade|0)>0?' · '+r.iade+' stok iadesi':'')
      +(r.yeni_gorev_id?' · yeniden başlat görevi kuruldu':'')
      +(r.yeniden_not?' · '+r.yeniden_not:''));
    await pullTables(RPC_TABLES.protokol_iptal).catch(()=>{});
    updateTaskBadge(); loadTasks(_curTaskFilter||'today'); loadDash();
    window.__protokolUyarilar=null;   // protokol ekranı taze veriyle açılsın
    return true;   // C-1: vaka detay yüzeyi (cdProtokolIptal) başarıda modalı kapatabilsin
  }catch(e){ toast('❌ '+getUserMessage(e),true); }
}
// C-1 (E4 onarım, 2026-09-25): protokol iptal YÜZEYİ vaka detayında.
// 'Protokolü iptal et' bugün yalnız AÇIK OVSYNC_BASLAT kartındaki ✕
// butonundan erişilebiliyordu; protokol başlayınca (görev tamamlanır)
// yüzey kalmıyordu — zarf E4 ölçütü 'aktif ovsync vakasında Protokolü
// iptal et' karşılanmıyordu. Vaka detayındaki #cd-protokol-iptal-btn
// (cd-gun-bolum komşuluğu, E0 cd-kaydir-btn deseni) AKTİF +
// protocol_family'li vakada görünür (openCaseDet → ertelemeBtnGuncelle;
// online-only E6) ve aynı _protokolIptalAkisi A dalına devreder — İKİNCİ
// AKIŞ KOPYASI YOK. protocol_family UI'da zaten mevcut (cases pull
// select('*')) — api.js değişikliği gerekmez.
/**
 * Aktif protokol ailesine sahip vakada protokol iptal akışını çalıştırır; akış başarılıysa vaka detay ekranını kapatır.
 * @returns {Promise<void>} İşlem tamamlanınca çözülen bir Promise döndürür.
 */
async function cdProtokolIptal(){
  if(_ertelemeOfflineGuard('protokol-iptal')) return;   // E6: online-only (plan 3c)
  const c=(typeof _curCase!=='undefined')?_curCase:null;   // vm-extract koşum koruması (ui.js:6980 deseni)
  if(!c||c.status!=='active'||!c.protocol_family) return;   // yüzey yalnız protokol ailesi aktif vakada
  const ok=await _protokolIptalAkisi(c);
  if(ok) closeM('m-case-det');   // vaka kapandı → detay ekranı kapanır (erken-kapat deseni)
}
// P10/B3: bildirim yardımcısı — izin yoksa sessiz düşme YOK (rozet panelde); yalnız iki olayda kullanılır
// S4/N2: hayvanId varken bildirim tıklanabilir hedefe bağlanır (Notification onclick +
// izin yoksa app-içi banner). kupeNo opsiyonel — banner kupe'yi getData'dan çözer.
function _ovsyncBildirim(baslik,govde,hayvanId,kupeNo){
  try{
    if(!('Notification' in window)){
      if(hayvanId) _ovsyncBildirimBanner(hayvanId,kupeNo);
      return;
    }
    if(Notification.permission==='granted'){
      const notif = new Notification(baslik,{body:govde,tag:'ovsync-pg'});
      if(hayvanId){ notif.onclick = () => { try { window.focus(); openDet(hayvanId); } catch(e){} }; }
    }
    else if(hayvanId){ _ovsyncBildirimBanner(hayvanId,kupeNo); }
    // denied/default + hayvanId yok: panel zaten kalıcı kaynak; ilk kullanıcı etkileşiminde tek istem
  }catch(e){ /* bildirim başarısızlığı akışı etkilemez */ }
}
// P10/B2: açılış özeti — hedefi gelmiş OVSYNC_BASLAT varsa tek bildirim (cron yedeğinin UI aynası)
/**
 * Bildirim izni olup olmadığını kontrol eder, varsa 'ovsync_baslat_uyarilari' RPC çağrısı yaparak
 * hedef tarihi geçmiş olan ilk tohumlama protokolü uyarılarını filtreler ve bunları bildirim olarak gösterir.
 * @returns {void} Herhangi bir değer döndürmez.
 * @rpc ovsync_baslat_uyarilari
 */
async function ovsyncAcilisOzeti(){
  try{
    if(!('Notification' in window)||Notification.permission!=='granted') return;
    const r=await rpc('ovsync_baslat_uyarilari',{});
    const due=(r&&r.uyarilar||[]).filter(u=>u.hedef_tarih<=new Date().toISOString().slice(0,10));
    if(due.length) new Notification(due.length+' hayvanda ilk tohumlama protokolü başlatılacak',{body:due.map(u=>u.kupe_no).slice(0,10).join(', ')+(due.length>10?'…':''),tag:'ovsync-acilis'});
  }catch(e){ /* açılış bildirimi best-effort */ }
}

// ═══ F1 Task 3 — ÇOKLU SEÇİM + KAYDIRMA ÇUBUĞU (2026-09-27, coklu-kaydirma) ═══
// SPEC §4: Görevler ekranında açık TEDAVI_GUN/TEDAVI_SEANS kartlarında checkbox
// (fail-closed: diğer tiplerde çizilmez); seçim durumu oturum-içi Set + sessionStorage
// senkronu — tab geçişlerinde korunur, sekme kapanınca düşer. Seçim çubuğu ≥1 seçimde
// görünür; E6: navigator.onLine=false iken gizli. RPC'ye BURADA DOKUNULMAZ — onay
// akışı Task 4'te forms.js'te bağlanır (apiCokluKaydir, js/api.js). Değerler dataset
// ile taşınır (escAttr-inline yasağı).
window._ckSecilenGorevler=window._ckSecilenGorevler||new Set();

// Seçilebilirlik: yalnız açık tedavi gün/seans kartları (fail-closed ayna)
/**
 * Görev tipinin 'TEDAVI_GUN' veya 'TEDAVI_SEANS' olup olmadığını, görevin tamamlandı olup olmadığını ve iptal edilip edilmediğini kontrol ederek uygunluğu belirler.
 * @param {Object} t Görev bilgilerini içeren nesne.
 * @returns {boolean} Görevin çoklu seçim için uygun olup olmadığını belirten boolean değer.
 */
function _cokluSecimUygun(t){
  return !t.tamamlandi&&!t.iptal&&(t.gorev_tipi==='TEDAVI_GUN'||t.gorev_tipi==='TEDAVI_SEANS');
}

// sessionStorage → Set (her görev-listesi render'ında çağrılır — tab-geçişi koruması)
/**
 * SessionStorage'dan 'ege_coklu_secim' anahtarıyla saklanmış görev listesini okur,
 * geçerli string değerleri filtreleyerek bir Set nesnesi oluşturup pencere nesnesine atar ve bu Set'i döndürür.
 * @returns {Set} Geçerli çoklu seçim görevlerinden oluşan Set nesnesi.
 */
function _cokluSecimYukle(){
  let arr=[];
  try{ arr=JSON.parse(sessionStorage.getItem('ege_coklu_secim')||'[]'); }catch(e){ arr=[]; }
  window._ckSecilenGorevler=new Set(Array.isArray(arr)?arr.filter(x=>typeof x==='string'&&x):[]);
  return window._ckSecilenGorevler;
}

// Set → sessionStorage (bozuk storage sessizce yutulur — seçim kaybı, çökme değil)
/**
 * Seçili görevlerin listesini alıp sessionStorage'da 'ege_coklu_secim' anahtarı altında JSON formatında kalıcı olarak kaydeder.
 * @returns {void} İşlem sonucu döndürmez.
 */
function _cokluSecimKaliciYaz(){
  try{ sessionStorage.setItem('ege_coklu_secim',JSON.stringify([...(window._ckSecilenGorevler||[])])); }catch(e){}
}

// Checkbox tıkı: Set + storage + çubuğu tek noktadan günceller
/**
 * Görev ID'si ve kontrol durumu verildiğinde seçili görev listesine ekleme veya silme işlemleri yapar, ardından kalıcı yazıyı ve çubuğu günceller.
 * @param {string} gorevId İşlem yapılacak görevin ID'si.
 * @param {boolean} checked Görevin seçili olup olmadığı durumu.
 * @returns {void} İşlem sonucu döndürmez.
 */
function _cokluSecimToggle(gorevId,checked){
  if(!gorevId) return;
  if(!window._ckSecilenGorevler) _cokluSecimYukle();
  if(checked) window._ckSecilenGorevler.add(gorevId);
  else window._ckSecilenGorevler.delete(gorevId);
  _cokluSecimKaliciYaz();
  _cokluSecimBarGuncelle();
}

// Temizle: Set + storage birlikte boşalır (SPEC §4); görünen checkbox'lar işaretsizleşir.
// fix-tur1 (I-1): temizlik belirsizlik uyarısını da sıfırlar — kullanıcı seçimi
// bıraktıysa "tekrar deneme riski" uyarısının yaşamasi anlamsızdır.
/**
 * Çoklu seçim durumunu temizler: seçili görevler kümesini boşaltır, kalıcı depoya yazar,
 * kaydırma belirsizlik bayrağını sıfırlar, tüm görev seçim kutularının işaretini kaldırır
 * ve çoklu seçim çubuğunu günceller.
 * @returns {void}
 */
function _cokluSecimTemizle(){
  window._ckSecilenGorevler=new Set();
  _cokluSecimKaliciYaz();
  window._ckKaydirBelirsiz=false;
  document.querySelectorAll('.task-sec-kutu').forEach(k=>{ k.checked=false; });
  _cokluSecimBarGuncelle();
}

// fix-tur1 (I-3): seçim ∩ yüklü görev kümesi. Yüklü kaynak = IndexedDB
// gorev_log (loadTasks'ın kaynağı; görev listesi state cache'ine girmez).
// Okuma hatasında FAIL-OPEN: seçim KISMAZ — IDB erişilemezse sunucu tarafı
// GOREV_COZULEMEDI kısmi-başarıyla zaten raporlar; yanlışlıkla tüm seçimi
// silmek daha zararlı.
/**
 * Seçili görevlerin kimliklerini (id) içeren bir küme alarak,
 * 'gorev_log' veritabanından yüklenen kayıtların kimlikleriyle kesişimini hesaplar ve
 * sadece log'da kayıtlı olan seçili görev kimliklerini içeren yeni bir küme döndürür.
 * @returns {Set} Log veritabanında kayıtlı olan seçili görev kimliklerini içeren küme.
 */
async function _cokluSecimGecerliIds(){
  const secim=window._ckSecilenGorevler||new Set();
  if(!secim.size) return new Set();
  let yuklu=null;
  try{ yuklu=await idbGetAll('gorev_log'); }catch(e){ yuklu=null; }
  if(!Array.isArray(yuklu)) return new Set([...secim]);
  const yukluIds=new Set(yuklu.map(t=>t&&t.id).filter(Boolean));
  return new Set([...secim].filter(id=>yukluIds.has(id)));
}

// fix-tur1 (I-3): seçimi verilen geçerli kümeye indirir; düşen id sayısını
// döner (forms.js onay metninde bildirir). Set + sessionStorage TEK noktadan.
/**
 * Geçerli görev ID'lerini içeren bir Set ile filtreleme yapılarak,
 * geçerli olmayan görevleri (prune) belirler ve eğer varsa mevcut seçili görev listesini günceller.
 * @param {Set} gecerli Geçerli görev ID'lerinin bulunduğu Set.
 * @returns {number} Filtreleme işlemi sonucunda çıkarılan (düşen) görev sayısı.
 */
function _cokluSecimPrune(gecerli){
  const once=window._ckSecilenGorevler||new Set();
  const kalan=new Set([...once].filter(id=>gecerli.has(id)));
  const dusenSayi=once.size-kalan.size;
  if(dusenSayi>0){
    window._ckSecilenGorevler=kalan;
    _cokluSecimKaliciYaz();
    _cokluSecimBarGuncelle();
  }
  return dusenSayi;
}

// Çubuk görünürlük + sayaç: ≥1 seçim VE online iken görünür (SPEC §4 + E6).
// Statik konteyner (index.html, Task 5) olsa da olmasa da TEK buradan senkronlanır.
/**
 * Çoklu seçim barı elementini bulur, seçili görev sayısını hesaplar ve barın görünür olup olmadığını belirler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _cokluSecimBarGuncelle(){
  const bar=document.getElementById('k-coklu-bar');
  if(!bar) return;
  const n=(window._ckSecilenGorevler||new Set()).size;
  const sayac=document.getElementById('k-coklu-sayac');
  if(sayac) sayac.textContent=n+' görev seçili';
  bar.hidden=(n===0)||!_ertelemeOnline();
  bar.style.display=bar.hidden?'none':'flex';
}

// Hızlı chip: +N değerini gün girişine yazar (RPC çağrılmaz — onay Task 4'te)
/**
 * 'k-coklu-gun' kimlikli girdi alanına verilen gün değerini yazar.
 * @param {number|string} gun - Girdi alanına yazılacak gün değeri.
 * @returns {void} Hiçbir değer döndürmez.
 */
function _cokluSecimGunDoldur(gun){
  const girdi=document.getElementById('k-coklu-gun');
  if(girdi) girdi.value=String(gun);
}

// Çubuk markup'ı — loadTasks statik konteyner yoksa görev listesi başına çizer.
// Onay butonunun handler'ı YOKTUR (Task 4 forms.js bağlar); id + data-aksiyon hazır.
/**
 * Çoklu seçim arayüzü HTML yapısını oluşturur. Görev sayacını, gün butonlarını, gün girişini, kaydırma ve temizleme butonlarını içeren gizli bir div döndürür.
 * @returns {string} Çoklu seçim barı HTML kodu.
 */
function _cokluSecimBarHtml(){
  return `<div id="k-coklu-bar" hidden style="display:none;align-items:center;gap:8px;flex-wrap:wrap;margin:6px 2px 10px;padding:8px 10px;border-radius:10px;background:rgba(30,100,200,.07);border:1px solid var(--card3);font-size:.72rem">
    <span id="k-coklu-sayac" style="font-weight:800;color:var(--ink)">0 görev seçili</span>
    <span style="display:flex;gap:4px">${[1,2,3,7].map(n=>`<button type="button" data-gun="${n}" onclick="_cokluSecimGunDoldur(this.dataset.gun)" style="font-size:.68rem;font-weight:700;padding:3px 9px;border-radius:8px;border:1px solid var(--blue);background:rgba(30,100,200,.08);color:var(--blue);cursor:pointer">+${n}</button>`).join('')}</span>
    <input id="k-coklu-gun" type="number" min="1" max="31" placeholder="+gün" inputmode="numeric" style="width:64px;padding:4px 6px;border-radius:8px;border:1px solid var(--card3);font-size:.72rem">
    <button type="button" id="k-coklu-onayla" data-aksiyon="coklu-kaydir" style="font-size:.68rem;font-weight:800;padding:5px 10px;border-radius:8px;border:none;background:var(--green);color:#fff;cursor:pointer">⏩ Seçilenleri Kaydır</button>
    <button type="button" id="k-coklu-temizle" onclick="_cokluSecimTemizle()" style="font-size:.68rem;font-weight:700;padding:5px 10px;border-radius:8px;border:1px solid var(--card3);background:transparent;color:var(--ink3);cursor:pointer">Temizle</button>
  </div>`;
}

// Görev kartı checkbox'ı — yalnız _cokluSecimUygun kartlarında; Set'tekiler işaretli doğar
/**
 * Verilen görev öğesi için çoklu seçim kutusu HTML'ini oluşturur.
 * Seçili görevler listesinde olup olmadığına göre kontrol yapıp, uygunsa checkbox elementini döndürür.
 * @param {Object} t Görev bilgilerini içeren nesne.
 * @returns {string} Checkbox HTML'i veya uygun değilse boş string.
 */
function _cokluSecimKutuHtml(t){
  if(!_cokluSecimUygun(t)) return '';
  const _secili=window._ckSecilenGorevler&&window._ckSecilenGorevler.has(t.id);
  return `<input type="checkbox" class="task-sec-kutu" data-gorev-id="${escAttr(t.id)}"${_secili?' checked':''} onclick="event.stopPropagation();_cokluSecimToggle(this.dataset.gorevId,this.checked)" style="width:16px;height:16px;accent-color:var(--green);cursor:pointer;flex-shrink:0" title="Çoklu kaydırma için seç">`;
}

/**
 * Verilen görev (task) nesnesini HTML kartı olarak render eder.
 * Görevin detaylarını, alt görevlerini (subtasks), ilaç planlarını ve görev tipine göre özel etiketleri içerir.
 * @param {Object} t Görev nesnesi.
 * @param {string} cls Ekstra CSS sınıf adı.
 * @param {Array} subs Tamamlanmış veya tamamlanmamış alt görevler dizisi.
 * @param {Array} drugs Planlanmış ilaçlar dizisi.
 * @param {string} diseaseName Hastalık adı (varsa).
 * @returns {string} Görev kartının HTML kodu.
 */
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
          ${_cokluSecimKutuHtml(t)}
          <span class="tc-id">${(()=>{const h=getState('animals').find(a=>a.id===t.hayvan_id);return h?(h.kupe_no||h.devlet_kupe):(t.hayvan_id?.length>20?'BZ-'+t.hayvan_id.slice(-4):t.hayvan_id||'—');})()} </span>
          <span class="pill ${t.gorev_tipi||'DIGER'}">${(t.gorev_tipi==='ASI_PLANLI'||t.gorev_tipi==='ASI_HATIRLATMA'||t.gorev_tipi==='ASI_RAPEL')?'💉 ':''}${(t.gorev_tipi||'').replace(/_/g,' ')}</span>
          ${diseaseName?`<span class="pill" style="background:rgba(192,50,26,.1);color:var(--red);border:1px solid rgba(192,50,26,.2)">🏥 ${esc(diseaseName)}</span>`:''}
          ${_tohKaynakEtiket(t)}
        </div>
        <div class="tc-desc">${esc(t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').label||t.aciklama;}catch(e){return t.aciklama;}})():t.aciklama||'')}</div>
        <div class="tc-meta"><span>${fmtTarih(t.hedef_tarih)}${planTime?` <span style="color:var(--blue);font-size:.65rem">🕐 ${planTime}</span>`:''}</span>${_kalanGunEtiket(t)}${t.stok_id?`<span>💊 ${esc(_stokAdi(t.stok_id))}</span>`:''}</div>
      </div>
      ${subs.length===0&&t.gorev_tipi==='BESLEME'?`<button class="ck-btn" onclick="event.stopPropagation();togglePendingDone('besleme','${t.id}',this)">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
      </button>`:''}
      ${subs.length===0&&t.gorev_tipi!=='ASI_PLANLI'&&t.gorev_tipi!=='ILERI_GEBE_ASI'&&t.gorev_tipi!=='BESLEME'&&t.gorev_tipi!=='TEDAVI_GUN'&&t.gorev_tipi!=='TOHUMLAMA_PLANLI'&&t.gorev_tipi!=='OVSYNC_BASLAT'?`<button class="ck-btn" data-padok="${escAttr(t.padok_hedef||'')}" onclick="event.stopPropagation();togglePendingDone('gorev','${t.id}',this,{padok:this.dataset.padok})">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
      </button>`:''}
    </div>
    <div style="display:flex;gap:6px;align-items:center">${_ovsyncBaslatBtnHtml(t)}${_erteleBtnHtml(t)}</div>
    ${drugHtml}${subHtml}
  </div>`;
}
// Görev listesi: hayvan+gün seans grubu ayracı
/**
 * Verilen seans grubu nesnesini HTML formatında bir ayraç elemanı olarak döndürür.
 * @param {Object} g Seans grubu nesnesi.
 * @param {string} [g.gunNo] Gün numarası.
 * @param {number} [g.totalGun] Toplam gün sayısı (varsa).
 * @param {string} [g.disease] Hastalık adı (varsa).
 * @param {number} [g.seansDone] Tamamlanan seans sayısı.
 * @param {number} [g.seansTotal] Toplam seans sayısı.
 * @param {string} [g.date] Seans tarihi.
 * @param {string} [g.animalLabel] Hayvan etiketi.
 * @returns {string} HTML formatında seans ayraç elemanı.
 */
function renderSeansGrupAyrac(g){
  const gun = `Gün ${g.gunNo}${g.totalGun?'/'+g.totalGun:''}`;
  const dis = g.disease ? ` · 🏥 ${esc(g.disease)}` : '';
  const prog = g.seansTotal ? ` · ${g.seansDone}/${g.seansTotal} seans` : '';
  const tarih = g.date ? ` · ${fmtTarih(g.date)}` : '';
  return `<div class="seans-grup-ayrac">🐄 ${esc(g.animalLabel||'—')} · ${gun}${dis}${prog}${tarih}</div>`;
}
// Görev listesi: tek seans kartı (checkbox + ▾ inline iade)
/**
 * Verilen görev, seans ve opsiyonlar parametrelerini alarak görev kartı HTML'ini oluşturur.
 * Seans durumu (done, cancelled vb.) ve zaman bilgilerine göre kartın içeriğini ve stillerini belirler.
 * @param {Object} task Görev nesnesi.
 * @param {Object} seans Seans nesnesi.
 * @param {Object} opts Opsiyonel ayarlar nesnesi (date, drugName vb. içerir).
 * @returns {string} Görev kartı için HTML string'i.
 */
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
    ${_cokluSecimKutuHtml(task)}
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
/**
 * Belirli bir görev ID'sine sahip elemanın görünürlüğünü değiştirir ve genişletme okunu günceller.
 * @param {string} taskId Görevin benzersiz kimlik numarası (ID).
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function toggleSeansAksiyon(taskId){
  const el = document.getElementById('sga-'+taskId);
  if(!el) return;
  const open = el.style.display !== 'none';
  el.style.display = open ? 'none' : 'block';
  const exp = document.querySelector('#sg-'+taskId+' .sg-expand');
  if(exp) exp.textContent = open ? '▾' : '▴';
}
/**
 * Verilen alt görevin (sub) tamamlandı durumunu tersine çevirir.
 * Eğer alt görev tamamlandıysa, aynı ana görevin (parent) kalan alt görevleri kontrol eder.
 * Tüm alt görevler tamamlandıysa ana görevi de tamamlandı olarak işaretler ve bildirim gösterir.
 * @param {string} subId Tamamlanacak veya iptal edilecek alt görevin ID'si.
 * @param {string} parentId Alt görevin bağlı olduğu ana görevin ID'si.
 * @param {HTMLElement} el Görevin DOM elemanı (kodda doğrudan kullanılmamaktadır).
 * @returns {Promise<void>} İşlem tamamlandığında boş bir Promise döndürür.
 */
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
/**
 * Verilen görev tipine sahip alt tiplerin özel olup olmadığını kontrol eder.
 * @param {Object} sub Görev tipini içeren nesne.
 * @returns {boolean} Görev tipi özel alt tipler listesinde değilse true, değilse false döndürür.
 */
function detayAltTiklanabilir(sub){ return !OZEL_ALT_TIPLER.includes(sub.gorev_tipi||''); }
// Tamamla butonu etiketi: açık plain alt yoksa mevcut etiket, varsa grup sayacı.
/**
 * Açık saf sayı parametresini kontrol ederek uygun bir tamamlama mesajı döndürür.
 * @param {number} acikSafSayi - Tamamlanacak alt görev sayısını belirten sayı.
 * @returns {string} Görev durumu ve sayısına göre biçimlendirilmiş tamamlama mesajı.
 */
function detayBtnEtiketi(acikSafSayi){
  if(!acikSafSayi||acikSafSayi<=0) return '✅ Tamamlandı Olarak İşaretle';
  return `✅ ${acikSafSayi} alt görevle birlikte tamamla`;
}
// td-subs içeriği: bugünkü görsel dil korunur (yuvarlak st-check + üstü çizili done
// etiketi). Plain satırlar toggleSubDet'e HTML attribute onclick ile bağlanır —
// DOM property onclick modal router ile yarışır (AGENTS.md kuralı, 684534f deseni).
/**
 * Verilen alt görev listelerini (tamamlanan ve tamamlanmamış olanları) birleştirerek,
 * başlık bilgisi ve her bir görev için kontrol kutusu, etiket ve durum bilgilerini içeren HTML yapısını döndürür.
 * @param {Array} subsDone Tamamlanan alt görevlerin dizisi.
 * @param {Array} subsAcik Tamamlanmamış alt görevlerin dizisi.
 * @param {string} parentId Alt görevlerin bağlı olduğu ebeveyn görevin ID'si.
 * @returns {string} Alt görevlerin başlığı ve satırlarını içeren HTML string'i.
 */
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
/**
 * Verilen parentId'ye ait görev loglarını getirir, tamamlanan ve tamamlanmamış olanları ayırarak
 * 'td-subs' elementini günceller ve görev tipine göre 'td-tamam-btn' butonunun etiketini belirler.
 * @param {string} parentId İşlem yapılacak görevin ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
/**
 * Verilen alt görev ID'sine sahip görevi getirir, tamamlanma durumunu tersine çevirir ve günceller.
 * @param {string} subId Güncellenecek alt görevin ID'si.
 * @param {string} parentId Alt görevin bağlı olduğu ana görevin ID'si.
 * @param {HTMLElement} el Tıklanan DOM elementi.
 * @returns {Promise<void>} Güncelleme işleminin tamamlanması durumunda undefined döndürür.
 */
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
/**
 * Açık saf alt görevleri tamamlandı olarak işaretler; artık açık alt görev kalmadıysa ana görevi de tamamlar, aksi halde detay görünümünü güncelleyip butonu yeniden etkinleştirir.
 * @param {Object} parent - Tamamlanacak ana görev kaydı (id, hayvan_id, stok_id, miktar, padok_hedef alanlarını içerir).
 * @param {Array} acikSafAltlar - Tamamlanacak açık saf alt görev kayıtlarının dizisi.
 * @returns {Promise<void>} Herhangi bir değer döndürmez.
 */
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
// V2.2.2 (W16) — onay diyaloğuna OPSİYONEL radio grubu (tohumlama çakışma
// seçimi: üzerine yaz / atla). radyolar = {isim, varsayilan,
// secenekler:[{deger, etiket}]}; HTML dili _renderSablonSecim
// (forms.js:574) radio dili aynası — label + input[type=radio]. Yapılandırma
// yok/eksikse '' — grup hiç basılmaz (eski davranış birebir).
/**
 * Radyo listesi verisini alıp, varsayılan seçili radyoyu işaretli radio butonları içeren HTML etiketleri döndürür.
 * @param {Object} radyolar Radyo verisi nesnesi; 'isim', 'secenekler' ve 'varsayilan' özelliklerini içermelidir.
 * @returns {string} Radio butonları için HTML kodu veya geçersiz veri durumunda boş string.
 */
function _confirmRadyolarHtml(radyolar){
  if(!radyolar || !radyolar.isim || !Array.isArray(radyolar.secenekler)) return '';
  return radyolar.secenekler.map(s =>
    `<label style="display:flex;align-items:center;gap:6px;padding:3px 0;font-size:.82rem">
      <input type="radio" name="${escAttr(radyolar.isim)}" value="${escAttr(s.deger)}"${s.deger === radyolar.varsayilan ? ' checked' : ''}> ${esc(s.etiket)}</label>`
  ).join('');
}
// İşaretli radyonun değeri (yoksa null) — _confirmOk'un callback'ine ek
// argüman olarak taşınır.
/**
 * Belirtilen isimli radyo butonundan (input) seçili olanın değerini döndürür.
 * @param {string} isim Seçili radyo butonunun 'name' özelliğine sahip olması gereken isim.
 * @returns {string|null} Seçili radyo butonunun 'value' özelliği veya seçili bir buton yoksa null.
 */
function _confirmRadyoDegeri(isim){
  const el = document.querySelector('input[name="' + isim + '"]:checked');
  return el ? el.value : null;
}
/**
 * Onay kutusunu başlatır; başlık ve açıklama metnini ayarlar, radyo butonlarını (varsa) gösterir/gizler ve onay işlemini atar.
 * @param {string} title Onay kutusunun başlık metni.
 * @param {string} desc Onay kutusunun açıklama metni.
 * @param {Function} onConfirm Onay butonuna tıklandığında çalışacak işlev.
 * @param {Object} opts Opsiyonel ayarlar objesi; radyolar dizisi içerebilir.
 * @returns {void}
 */
function openConfirm(title, desc, onConfirm, opts){
  document.getElementById('m-confirm-title').textContent=title;
  document.getElementById('m-confirm-desc').textContent=desc;
  _confirmAction = onConfirm;
  // V2.2.2 — opts.radyolar varsa desc ile butonlar arasındaki konteynere
  // basılır; opts'suz çağrıda kutu TEMİZLENİR + gizlenir (önceki onayın
  // radyosu sızmaz; eski davranış birebir).
  const rk = document.getElementById('m-confirm-radyolar');
  if(rk){
    const html = (opts && opts.radyolar) ? _confirmRadyolarHtml(opts.radyolar) : '';
    rk.innerHTML = html;
    rk.style.display = html ? 'block' : 'none';
  }
  openM('m-confirm');
}
/**
 * 'm-confirm' iletişim kutusunu kapatır ve saklanan onay eylemini çalıştırır; iletişimde radyo düğmesi varsa seçili radyo değeri ek argüman olarak iletilir.
 * @returns {void}
 */
function _confirmOk(){
  closeM('m-confirm');
  const fn = _confirmAction; _confirmAction = null;
  if (typeof fn === 'function'){
    // V2.2.2 — radyolu onayda seçilen değer ek argümanla taşınır
    // (fn(chosen)); radyosuz yol args'sız fn() — mevcut çağıranlar birebir.
    const radyo = document.querySelector('#m-confirm-radyolar input[type="radio"]');
    if(radyo) fn(_confirmRadyoDegeri(radyo.name));
    else fn();
  }
}
/**
 * 'gorev_log' kayıtlarından gecikmiş görev sayısını hesaplayıp 'tbadge' rozetini günceller; rozet 99'dan fazlaysa '99+' gösterilir, gecikmiş görev yoksa gizlenir.
 * @returns {Promise<void>} İşlem tamamlanınca çözülen promise; hata durumunda sessizce yok sayılır.
 */
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

/**
 * Besleme görevini tamamlar; RPC çağrısı yapar, başarı durumunda bildirim gösterir, görev satırını listeden kaldırır ve panoyu/görev listesini yeniler. Hata durumunda butonu eski haline döndürüp hata bildirimi gösterir.
 * @param {*} id - Tamamlanacak besleme görevinin kimliği.
 * @param {*} btn - İşlemi başlatan buton öğesi; işlem sırasında devre dışı bırakılır ve spinner/ikon gösterimi için güncellenir.
 * @returns {Promise<void>} Hiçbir değer döndürmez.
 * @rpc besleme_tamam
 */
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
/**
 * Sürü görünümünü yükler: aktif hayvanları, gebelik/bekleyen tohumlama, son doğum ve son tohumlama haritalarını, aktif hasta vakalarını ve hastalık listesini getirip state'e yazarak hayvan tablosunu ve istatistik/padoluk doluluk çubuğunu render eder; hata durumunda tablo gövdesine uyarı mesajı basar.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen promise; değer döndürmez.
 */
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
/**
 * Kısırlaştırılmamış ve doğumundan sonra tekrar tohumlanmamış bir hayvan için son doğumundan bu yana geçen gün sayısını hesaplar.
 * @param {Object} a - Hayvan kaydı.
 * @param {boolean} a.kisir - Hayvanın kısırlık durumu; doğruysa null döner.
 * @param {string} a.id - Hayvanın kimliği; doğum ve tohumlama tarihlerini haritalardan bulmak için kullanılır.
 * @returns {number|null} Son doğumdan bu yana geçen gün sayısı; uygun koşul yoksa null.
 */
function _yeniDogumGun(a){
  if(a.kisir) return null;
  const dogumTarih=(globalThis._sonDogumMap||{})[a.id];
  if(!dogumTarih) return null;
  const sonToh=(globalThis._sonTohMap||{})[a.id];
  if(sonToh && sonToh>=dogumTarih) return null;   // doğumdan sonra tohumlanmış
  const gun=Math.floor((Date.now()-new Date(dogumTarih).getTime())/86400000);
  return gun>0 ? gun : null;
}
/**
 * Bir hayvanın durumuna göre (gebe, hasta, tohumlama tarihi, doğum tarihi, kısır vb.) ilgili etiketleri oluşturarak HTML string döndürür.
 * @param {Object} a Hayvan nesnesi.
 * @param {Set} gebeSet Gebe hayvanların ID'lerini içeren küme.
 * @returns {string} Hayvanın durum etiketlerini içeren HTML string.
 */
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
/**
 * Bir hayvan kaydının HTML kartını oluşturur. Kart, hayvanın kimlik bilgilerini, yaşını, ırkını ve etiketlerini içerir.
 * Ayrıca kartın tıklanabilir olması için event handler'lar ekler ve seçim durumu (checkbox) kontrolü yapar.
 * @param {Object} a Hayvanın temel bilgilerini içeren nesne (id, kupe_no, devlet_kupe, dogum_tarihi, irk vb.).
 * @param {Object} gebeSet Hamilelik durumu veya ilgili set bilgilerini içeren nesne.
 * @param {number|null} idx Kart sıralama numarası (index).
 * @returns {string} Oluşturulan HTML stringi.
 */
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
/**
 * Verilen hayvan listesini, gebe hayvanların gebelik gününe, bekleyen tohumlamaların tarihine ve diğer hayvanların küpe numarasına göre sıralayarak DOM'a render eder.
 * @param {Array} list Render edilecek hayvan kayıtlarından oluşan dizi.
 * @param {Object} opts Opsiyonel seçenekler objesi; 'verilenSira' özelliği varsa çağırıcının belirlediği sıralama korunur.
 * @returns {void} DOM elementi güncellenir, değer döndürmez.
 */
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
/**
 * Sperma rest durumunu değiştirir ve ilgili buton metnini günceller.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * 'sessiz-bs' ID'li elemanı bulup gizler ve global _sessizReturn bayrağını true olarak ayarlar.
 * @returns {void}
 */
function _sessizSheetGizle(){
  const box=document.getElementById('sessiz-bs');
  if(box) box.style.display='none';
  globalThis._sessizReturn=true;
}
// Tam kapatma (backdrop tap) — pushState girdisi varsa tüket (protokol deseni)
/**
 * 'sessiz-bs' ID'li elemanı DOM'dan kaldırır, global durum değişkenlerini günceller ve geçmişte sessiz_bs durumu varsa geriye döner.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * Sessiz hayvanları ve gebelik muayenesi bekleyenleri listeler,
 * ekranda bir modal pencere oluşturarak bu kayıtları gösterir.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc gebelik_muayene_listele, sessiz_hayvanlar_listele
 */
async function _showSessizList(){
  try{
    const list=await rpc('sessiz_hayvanlar_listele',{});
    // S2: muayene listesi — sheet'in en üstündeki izole bölümün verisi
    let muayene=[];
    try{ const ml=await rpc('gebelik_muayene_listele',{}); if(ml&&ml.length) muayene=ml; }catch(e){/* sessiz */}
    if((!list||!list.length)&&!muayene.length){toast('Sessiz hayvan yok');return;}
    globalThis._sessizReturn=false; // taze açılış eski dönüş işaretini ezer
    const existedBefore=!!document.getElementById('sessiz-bs'); // öksüz history girdisi birikmesin (proto-detay deseni)
    let box=document.getElementById('sessiz-bs');
    if(box) box.remove();
    box=document.createElement('div');
    box.id='sessiz-bs';
    box.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
    box.onclick=e=>{if(e.target===box)_sessizSheetKapat();};
    /**
     * Verilen hayvan kaydı verisini (s) alıp, sessizlik süresi ve son aktivite bilgilerini içeren bir satır HTML'i döndürür.
     * @param {Object} s Hayvan kaydı verisi (hayvan_id, kupe_no, grup, sessiz_gun, son_aktivite vb. özelliklere sahip).
     * @returns {string} Tıklanabilir bir satır HTML'i.
     */
    const row=s=>`<div class="arow" onclick="_sessizSheetGizle();openDet('${escAttr(s.hayvan_id)}')" style="cursor:pointer"><div class="arow-left"><div class="arow-id">${esc(s.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(s.grup||'')}</span></div><div class="arow-sub">${s.sessiz_gun>=9999?'Hiç kayıt yok':s.sessiz_gun+' gündür sessiz'} · Son: ${esc(s.son_aktivite||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
    /**
     * Bir hayvan kaydı verisini alıp, bekleyen gün sayısını, son tohumlama tarihini ve diğer bilgileri içeren tıklanabilir bir satır HTML'i döndürür.
     * @param {Object} m - Hayvan kaydı verisi (hayvan_id, kupe_no, grup, bekiyor_gun, son_tohumlama_tarihi vb. özelliklere sahip).
     * @returns {string} Tıklanabilir bir satır HTML'i.
     */
    const mRow=m=>`<div class="arow" onclick="_sessizSheetGizle();openDet('${escAttr(m.hayvan_id)}')" style="cursor:pointer"><div class="arow-left"><div class="arow-id">${esc(m.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(m.grup||'')}</span></div><div class="arow-sub">${m.bekliyor_gun}. gün Bekliyor · Son tohumlama: ${esc(m.son_tohumlama_tarihi||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
    const muayeneRows=muayene.length?`<div style="font-size:.68rem;font-weight:800;color:var(--red2);margin:12px 0 4px;letter-spacing:.02em">🔬 Gebelik Muayenesi Bekleyenler · ${muayene.length}</div>${muayene.map(mRow).join('')}`:'';
    const rows=muayeneRows+_sessizGrupla(list||[]).map(g=>`<div style="font-size:.68rem;font-weight:800;color:var(--ink3);margin:12px 0 4px;letter-spacing:.02em">${esc(g.grup)} · ${g.items.length}</div>${g.items.map(row).join('')}`).join('');
    // S2 review-fix: sessiz=0 + muayene>0 iken sheet başlığı muayene odaklı olur ("(0)" tuzağı yok)
    const sBaslik=(list||[]).length
      ?`<div style="font-weight:800;font-size:.95rem;margin-bottom:4px">❗ Sessiz Hayvanlar (${(list||[]).length})</div><div style="font-size:.75rem;color:var(--ink3);margin-bottom:14px">50+ gündür kızgınlık/tohumlama kaydı yok</div>`
      :`<div style="font-weight:800;font-size:.95rem;margin-bottom:4px">🔬 Gebelik Muayenesi Bekleyenler (${muayene.length})</div><div style="font-size:.75rem;color:var(--ink3);margin-bottom:14px">Son tohumlaması ≥40 gün önce Bekliyor — gebelik muayenesi bekleniyor</div>`;
    box.innerHTML=`<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:75vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">${sBaslik}${rows}</div>`;
    if(!existedBefore) history.pushState({sessiz_bs:1}, '', '');
    document.body.appendChild(box);
  }catch(e){toast('Hata: '+e.message);}
}
let _belirsizData=[];
let _belirsizSel=new Set();
/**
 * Belirsiz üreme listesi çağırır, varsa listeyi global değişkene atar,
 * bir modal kutusu oluşturur ve render fonksiyonunu çalıştırır.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda undefined döndürür.
 * @rpc hayvan_belirsiz_ureme_listele
 */
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
/**
 * "belirsiz-bs" elemanına, belirsiz üreme statüsündeki hayvanları listeleyen alt sayfa (bottom sheet) arayüzünü oluşturur. Her satırda hayvan küpe numarası, grup, doğum/tohumlama sayıları ve genç anne/olgun inek ipucu gösterilir; satıra tıklanınca seçim değişir. Üstte seçim filtreleri (Tümü, 1 doğumlular, 0 doğumlular, Temizle), altta seçili sayısıyla "Genç Anne" ve "Olgun İnek" toplu işaretleme butonları yer alır; seçim yoksa butonlar devre dışıdır. Liste yeniden çizilirken kaydırma konumu korunur.
 * @returns {void}
 */
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
/**
 * Belirlenen ID'li öğeyi belirsiz seçim kümesinden çıkarır veya ekler ve arayüzü günceller.
 * @param {string} id İşlem yapılacak öğenin ID'si.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _belirsizToggle(id){ if(_belirsizSel.has(id))_belirsizSel.delete(id); else _belirsizSel.add(id); _belirsizRender(); }
function _belirsizSelPredik(mode){
  _belirsizSel=new Set();
  if(mode==='all') _belirsizData.forEach(s=>_belirsizSel.add(s.hayvan_id));
  else if(mode==='dogum1') _belirsizData.filter(s=>s.dogum_sayisi>=1).forEach(s=>_belirsizSel.add(s.hayvan_id));
  else if(mode==='dogum0') _belirsizData.filter(s=>s.dogum_sayisi===0).forEach(s=>_belirsizSel.add(s.hayvan_id));
  _belirsizRender();
}
/**
 * Belirsiz üreme listesindeki hayvanları seçerek genç anne (düve) veya olgun inek olarak işaretler.
 * İşlem sonrası tabloyu yeniler ve belirsiz üreme listesini günceller.
 * @param {any} val - İşaretlenecek hayvanların türünü belirten değer (varsa).
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda void döner.
 * @rpc hayvan_belirsiz_ureme_listele, hayvan_genc_anne_isaretle_toplu
 */
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
/**
 * Protokol listesini DOM'dan kaldırır ve geçmişte protokol bilgisi varsa geriye döner.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _closeProtokolListe(){
  const box = document.getElementById('protokol-bs');
  if (!box) return;
  box.remove();
  if (history.state?.protokol) { globalThis._modalBackGuard = true; history.back(); }
}
/**
 * 'proto-detay-bs' ID'li modal kutusunu DOM'dan kaldırır ve geçmişte 'proto_detay' durumu varsa geriye döner.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _closeProtokolDetay(){
  const box = document.getElementById('proto-detay-bs');
  if (!box) return;
  box.remove();
  if (history.state?.proto_detay) { globalThis._modalBackGuard = true; history.back(); }
}

/**
 * Protokol uyarılarını (eksik, yaklaşan, tamamlandı) getirir, OVSYNC tohumlama görevlerini ekler ve bunları bir modal ekran olarak gösterir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 * @rpc ovsync_baslat_uyarilari, protokol_eksik_tara
 */
async function _showProtokolEkran(){
  let data = window.__protokolUyarilar;
  if (!data || !data.length) {
    try { data = await rpc('protokol_eksik_tara', {}); } catch(e) { toast('Hata: '+e.message, true); return; }
  }
  // P4: protokol_eksik_tara boş olsa bile OVSYNC_BASLAT bölümü varsa ekran açılır

  let box = document.getElementById('protokol-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'protokol-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) _closeProtokolListe(); };

  data = data || [];
  const eksik = data.filter(u => u.durum === 'eksik');
  const yaklasan = data.filter(u => u.durum === 'yaklasan');
  const tamamlandi = data.filter(u => u.durum === 'tamamlandi');

  /**
   * Durumu 'eksik' olan öğeler için kırmızı, 'yaklasan' olanlar için turuncu, diğerleri için yeşil renk döndürür.
   * @param {Object} d Durum bilgisini içeren nesne.
   * @returns {string} Duruma göre belirlenen CSS renk değeri.
   */
  const _renk = d => d.durum === 'eksik' ? 'var(--red2)' : d.durum === 'yaklasan' ? '#b8860b' : '#2e7d32';
  /**
   * Durumu 'eksik' olan kayıtlar için kırmızı, 'yaklasan' olanlar için sarı, diğerleri için yeşil emoji döndürür.
   * @param {Object} d Durumu kontrol edilecek nesne.
   * @returns {string} Duruma göre belirlenen emoji karakteri.
   */
  const _ikon = d => d.durum === 'eksik' ? '🔴' : d.durum === 'yaklasan' ? '🟡' : '✅';
  /**
   * Durumu 'eksik' olan kayıtlar için gecikme gününü, 'yaklasan' olan kayıtlar için kalan günü ve diğer durumlar için boş string döndürür.
   * @param {Object} d Durumu, gecikme günü veya kalan gün bilgisi içeren nesne.
   * @returns {string} Duruma göre hesaplanmış gün bilgisi veya boş string.
   */
  const _gun = d => d.durum === 'eksik' ? d.gecikme_gun + ' gün gecikmiş' : d.durum === 'yaklasan' ? Math.abs(d.gecikme_gun || 0) + ' gün kaldı' : '';

  /**
   * Verilen hayvan verisi ve dizin numarasını kullanarak protokol satırı HTML'ini oluşturur.
   * Satır, hayvanın durumu, uygulaması veya geri alınması gibi aksiyon butonlarını içerir.
   * @param {Object} d Hayvan verisi.
   * @param {number} i Dizindeki satır numarası.
   * @returns {string} Oluşturulan HTML satır kodu.
   */
  const _satirHtml = (d, i) => `<div class="arow" data-p="${escAttr(d.protokol)}" style="border-left:3px solid ${_renk(d)};margin-bottom:6px;padding:8px 10px;cursor:pointer" onclick="_showProtokolDetay('${escAttr(d.hayvan_id)}',this.dataset.p,${i})">
    <div style="flex:1">
      <div style="font-weight:700;font-size:.8rem">${_ikon(d)} ${esc(d.kupe_no||'?')} <span style="font-size:.6rem;opacity:.6">${esc(d.grup||'')}</span></div>
      <div style="font-size:.7rem;color:var(--ink3)">${esc(d.adim)} · ${_gun(d)}</div>
      <div style="font-size:.6rem;opacity:.5">${esc(d.protokol)}</div>
    </div>
    <div style="display:flex;gap:6px;align-items:center" onclick="event.stopPropagation()">
      ${d.durum !== 'tamamlandi' && d.etken_kod ? `<button onclick="_protokolUygula(${i})" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--blue);background:rgba(30,100,200,.1);color:var(--blue);cursor:pointer">💉 Uygula</button>` : ''}
      ${d.durum !== 'tamamlandi' ? `<button onclick="_protokolDismiss(${i})" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>` : ''}
      ${d.durum === 'tamamlandi' && d.kapatan_ref ? `<button data-action="protokol-geri-al" data-ref="${escAttr(d.kapatan_ref)}" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer">↩ Geri Al</button>` : ''}
    </div>
  </div>`;

  // P4/SK9: OVSYNC_BASLAT görevleri hedef−2 günden itibaren EN ÜSTTE ayrı bölümde
  // (saat-hassas; cron'un taradığı aynı RPC'den). index yerine gorev_id — bayat cache tuzağı yok.
  let ovHtml = '';
  try {
    const ov = await rpc('ovsync_baslat_uyarilari', {});
    window.__ovsyncUyarilar = (ov && ov.uyarilar) || [];
    const ovList = window.__ovsyncUyarilar;
    if (ovList.length) {
      ovHtml = `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:var(--green)">🌱 İlk Tohumlama (${ovList.length})<button onclick="_showOvsyncYardim()" style="margin-left:6px;width:18px;height:18px;border:1px solid var(--ink3);border-radius:50%;background:none;color:var(--ink3);font-size:.65rem;cursor:pointer;line-height:1">?</button></div>${ovList.map(_ovUyariSatirHtml).join('')}`;
    }
  } catch(e) {
    // T10: taze çağrı başarısızsa rozet önbelleğine düş (bayat-fallback; konsol uyarısıyla)
    console.warn('ovsync_baslat_uyarilari:', e.message);
    const ovList = Array.isArray(window.__ovsyncUyarilar) ? window.__ovsyncUyarilar : [];
    if (ovList.length) {
      ovHtml = `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:var(--green)">🌱 İlk Tohumlama (${ovList.length} · önbellek)<button onclick="_showOvsyncYardim()" style="margin-left:6px;width:18px;height:18px;border:1px solid var(--ink3);border-radius:50%;background:none;color:var(--ink3);font-size:.65rem;cursor:pointer;line-height:1">?</button></div>${ovList.map(_ovUyariSatirHtml).join('')}`;
    }
  }
  // C4 (cila2): K8'in seanslar panel bölümü geri alındı — sahip:
  // "ana listeye monte etmişler, ben böyle bir şey istemedim; sabahki yeterli".
  // Ovsync seansları Görevler listesinde normal görev satırları olarak görünür (1f01e8b hâli).
  if (!data.length && !ovHtml) { toast('Protokol uyarısı yok'); return; }

  const eksikHtml = eksik.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:var(--red2)">🔴 Gecikmiş (${eksik.length})</div>${eksik.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';
  const yakHtml = yaklasan.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:#b8860b">🟡 Yaklaşan (${yaklasan.length})</div>${yaklasan.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';
  const tamHtml = tamamlandi.length ? `<div style="font-weight:800;font-size:.8rem;margin:12px 0 6px;color:#2e7d32">✅ Son 24 Saat (${tamamlandi.length})</div>${tamamlandi.map((d,i) => _satirHtml(d, data.indexOf(d))).join('')}` : '';

  // P10/B3: bildirim izni kapalıysa rozet — sessiz düşme görünür kalsın
  const bildirimRozet = ('Notification' in window && Notification.permission !== 'granted')
    ? ' <span style="font-size:.6rem;color:#b8860b;border:1px solid #b8860b;border-radius:8px;padding:1px 6px;vertical-align:middle">bildirim kapalı</span>' : '';
  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:80vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:1rem;margin-bottom:4px">📋 Protokol Uyarıları${bildirimRozet}</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">Doğum sonrası, ileri gebe, kızgınlık takibi</div>
    ${ovHtml}${eksikHtml}${yakHtml}${tamHtml}
  </div>`;
  history.pushState({protokol:true}, '', '');
  document.body.appendChild(box);
}

/**
 * Belirli bir hayvanın protokol detaylarını filtreleyerek dinamik bir modal pencere oluşturur ve ekrana ekler.
 * Pencere içinde adım durumlarına göre ikonlar, tarihler ve gecikme uyarıları gösterilir.
 * Ayrıca pencereyi kapatma ve protokol uygulama gibi etkileşimli butonlar eklenir.
 * @param {number|string} hayvanId Filtreleme yapılacak hayvanın kimliği.
 * @param {string} protokol Gösterilecek protokolün adı (örn. 'DOGUM_PROTOKOL').
 * @param {number} activeIdx Aktif indeks parametresi (fonksiyonun mevcut mantığında kullanılmamaktadır).
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _showProtokolDetay(hayvanId, protokol, activeIdx){
  const data = window.__protokolUyarilar;
  if (!data) return;

  const items = data.filter(d => d.hayvan_id === hayvanId && d.protokol === protokol);
  if (!items.length) return;

  const d0 = items[0];
  // Sheet zaten açıksa (uygulama sonrası tazeleme) yeniden pushState YOK —
  // her tazelemede öksüz {proto_detay} girdisi birikiyordu (B21)
  const existedBefore = !!document.getElementById('proto-detay-bs');
  /**
   * Durumu 'eksik' olan öğeler için kırmızı, 'yaklasan' olanlar için turuncu, diğerleri için yeşil renk döndürür.
   * @param {Object} d Durum bilgisini içeren nesne.
   * @returns {string} Duruma göre belirlenen CSS renk değeri.
   */
  const _renk = d => d.durum === 'eksik' ? 'var(--red2)' : d.durum === 'yaklasan' ? '#b8860b' : '#2e7d32';
  /**
   * Durumu 'eksik' olan kayıtlar için kırmızı, 'yaklasan' olanlar için sarı, diğerleri için yeşil emoji döndürür.
   * @param {Object} d Durum bilgisini içeren nesne.
   * @returns {string} Duruma göre belirlenen emoji karakteri.
   */
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
      ? `<button data-action="protokol-geri-al" data-ref="${escAttr(d.kapatan_ref)}" style="font-size:.6rem;padding:3px 8px;border-radius:6px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer">↩</button>`
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

/**
 * Detay ve protokol bölüm gizleyip belirtilen hayvan için detay görünümünü açar.
 * @param {string|number} hayvanId - Detayı açılacak hayvanın kimliği.
 * @returns {void} Bir değer döndürmez.
 */
function _protoDetayHayvanGit(hayvanId){
  const detayBs = document.getElementById('proto-detay-bs');
  if (detayBs) detayBs.style.display = 'none';
  const protokolBs = document.getElementById('protokol-bs');
  if (protokolBs) protokolBs.style.display = 'none';
  openDet(hayvanId);
}

// S4/N1+M1: Protokol panelindeki İlk Tohumlama satırı — satır tıklaması hayvan kartını
// açar (_protoDetayHayvanGit; popstate 'det' vakası paneli geri getirir), buton hücresi
// stopPropagation sarmallı (_satirHtml deseni). "Ovsynch-56" adı sahibin kararıyla korunur;
// hedef_saat koşullu basılır (boş saat → çift-ayraç kozmetiği yok).
// S1: kisir hayvanda Başlat YOK, kilitli rozet VAR; ✕ her durumda çizilir.
/**
 * Görevsiz öneri satırı için uyarı veya başlatma etiketi döndürür.
 * Eğer görev ID'si yoksa (oneriMi), yaklaşıyor kuralı uyarısı gösterir; yoksa Ovsynch-56 senkronu başlatma etiketi gösterir.
 * @param {Object} u Hayvan ve görev bilgilerini içeren nesne (gorev_id, hayvan_id, kupe_no, kategori, hedef_tarih, tai_tarihi, taban_turu, kisir vb. alanları içerir).
 * @returns {string} HTML formatında stilize edilmiş uyarı veya başlatma satırı etiketi.
 */
function _ovUyariSatirHtml(u){
  // C5 (cila2): görevsiz öneri satırı (kuralı bugün+2 içinde, görev kural günü doğar)
  // — "Başlat" daveti yerine görevin otomatik açılacağı bilgi etiketi basılır.
  const oneriMi = !u.gorev_id;
  const ustSatir = oneriMi
    ? 'Uyarı: ilk tohumlama kuralı yaklaşıyor'
    : 'Başlat: Ovsynch-56 senkronu (56 günlük program)';
  return `<div class="arow" style="border-left:3px solid ${oneriMi?'#b8860b':'var(--green)'};margin-bottom:6px;padding:8px 10px;cursor:pointer" onclick="_protoDetayHayvanGit('${escAttr(u.hayvan_id)}')">
        <div style="flex:1">
          <div style="font-weight:700;font-size:.8rem">🌱 ${esc(u.kupe_no||'?')} <span style="font-size:.6rem;opacity:.6">${esc(u.kategori||'')}</span></div>
          <div style="font-size:.7rem;color:var(--ink3)">${ustSatir} · Hedef: ${fmtTarih(u.hedef_tarih)}${u.hedef_saat ? ' ' + String(u.hedef_saat).slice(0, 5) : ''} · Zamanlanmış tohumlama (TAI): ${fmtTarih(u.tai_tarihi)}</div>
          <div style="font-size:.6rem;opacity:.5">${u.taban_turu==='duve'?'Düve — 12a21g':u.taban_turu==='abort'?'Abort sonrası':u.taban_turu==='dogum'?'Doğum sonrası':'Açık dişi'}</div>
        </div>
        <div style="display:flex;gap:6px;align-items:center" onclick="event.stopPropagation()">
          ${oneriMi
            ? '<span style="font-size:.62rem;font-weight:700;color:#b8860b">📅 Görev hedef gününde otomatik açılır</span>'
            : _ovsyncBaslatKilitHtml(!!u.kisir, u.gorev_id, u.hayvan_id, false, _ovsyncBaslatPencereGunu(u))}
        </div>
      </div>`;
}

// C4 (cila2): K8'in panel seans yardımcıları geri alındı — seanslar bölümü
// 1f01e8b hâlinde yoktu; ovsync seansları Görevler listesinde normal görev
// satırları olarak görünür. Seans uyarı RPC'si veri katmanında kalır (dokunulmaz).

// S4/M2+M3: Ovsynch-56/TAI yardım katmanı (sahip kararı: yardım balonu İSTENİYOR).
// _showProtokolDetay öncülü alt-sheet kalıbı; seans sayısı canlı şablondan teyitli (4 kalem).
/**
 * İlk Tohumlama (Ovsynch-56) programını açıklayan tam ekran yardım alt panelini (bottom sheet) oluşturur ve sayfaya ekler. Arka plana tıklandığında ya da kapatma düğmesi aracılığıyla _closeOvsyncYardim çağrılarak kapatılabilecek şekilde davranışı bağlar; panel ilk kez açılıyorsa geçmiş durumuna bir kayıt ekler.
 * @returns {void} Değer döndürmez.
 */
function _showOvsyncYardim(){
  const existedBefore = !!document.getElementById('ovsync-yardim-bs');
  let box = document.getElementById('ovsync-yardim-bs');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'ovsync-yardim-bs';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:350;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) _closeOvsyncYardim(); };
  /**
   * Başlık ve metin içeren stilize edilmiş bir HTML div elemanı döndürür.
   * @param {string} baslik Gösterilecek başlık metni.
   * @param {string} metin Gösterilecek açıklama metni.
   * @returns {string} Başlık ve metni içeren stilize edilmiş HTML string.
   */
  const _madde = (baslik, metin) => `<div style="margin-bottom:12px">
      <div style="font-weight:800;font-size:.82rem;margin-bottom:3px">${baslik}</div>
      <div style="font-size:.75rem;color:var(--ink3);line-height:1.45">${metin}</div>
    </div>`;
  box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;max-height:70vh;overflow-y:auto;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
      <div style="font-weight:800;font-size:.95rem">❓ İlk Tohumlama (Ovsynch-56) nedir?</div>
      <button onclick="_closeOvsyncYardim()" style="background:none;border:none;font-size:1.2rem;cursor:pointer;color:var(--ink3)">✕</button>
    </div>
    ${_madde('"Ovsynch-56"', 'İneklerde doğum sonrası ilk tohumlama zamanlaması için kullanılan senkron programı. Başlat\'a dokununca 4 seanslı hormon zinciri (1./8./9./10. gün) ve tohumlama görevi açılır.')}
    ${_madde('TAI (Zamanlanmış Tohumlama)', 'Zincirin sonunda planlanan tohumlama. Ekrandaki tarih, başlatma hedefinin 10 gün sonrasıdır.')}
    ${_madde('Neden bu hayvan?', 'Düve: doğumdan 12 ay 21 gün sonra. İnek: son doğum/aborttan 51 gün sonra. Görev, hedeften 2 gün önce listede belirir.')}
  </div>`;
  if (!existedBefore) history.pushState({ovsync_yardim:true}, '', '');
  document.body.appendChild(box);
}
/**
 * 'ovsync-yardim-bs' ID'li elemanı DOM'dan kaldırır ve geçmişte ovsync_yardim durumu varsa geri sayfasına yönlendirir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _closeOvsyncYardim(){
  const box = document.getElementById('ovsync-yardim-bs');
  if (!box) return;
  box.remove();
  if (history.state?.ovsync_yardim) { globalThis._modalBackGuard = true; history.back(); }
}

// S4/N2: app-içi bildirim banner'ı — Notification izni yokken Başlat başarıdır
// tıklanabilir alt-sheet (z310: panel 300 üstü, proto-detay 350 altı). pushState YOK
// (transient toast-sınıfı yüzey); satır tıklaması banner'ı kaldırıp hayvan kartını açar.
/**
 * İlk tohumlama protokolünün başlatıldığını bildiren, alttan açılan geçici bir banner (bottom sheet) gösterir. Kupe numarası verilmemişse hayvanlar listesinden bulunmaya çalışır; banner 10 saniye sonra otomatik kapanır, arka plana tıklayınca veya hayvan kartı satırına tıklayınca ilgili hayvanın detay sayfasına giderek kapanır.
 * @param {string} hayvanId - Hayvanın benzersiz kimliği; detay sayfasına yönlendirmede kullanılır.
 * @param {string} [kupeNo] - Hayvanın kupe numarası; verilmezse hayvanlar listesinden kupe_no alanı sorgulanır.
 * @returns {Promise<void>} Banner gösterimi tamamlandığında çözülen, değer döndürmeyen Promise.
 */
async function _ovsyncBildirimBanner(hayvanId, kupeNo){
  try{
    let kupe = kupeNo;
    if (!kupe) {
      try { kupe = ((await getData('hayvanlar')) || []).find(a => a.id === hayvanId)?.kupe_no; } catch(e) {}
    }
    const box = document.createElement('div');
    box.id = 'ovsync-bildirim-bs';
    box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.35);z-index:310;display:flex;align-items:flex-end';
    box.onclick = e => { if (e.target === box) box.remove(); };
    box.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:16px;padding-bottom:calc(16px + env(safe-area-inset-bottom,0px))">
      <div style="font-weight:800;font-size:.85rem;margin-bottom:8px">✅ İlk tohumlama protokolü başlatıldı</div>
      <div onclick="document.getElementById('ovsync-bildirim-bs')?.remove();openDet('${escAttr(hayvanId)}')" style="display:flex;justify-content:space-between;align-items:center;gap:8px;padding:10px;border-radius:10px;border:1px solid var(--card2);background:rgba(78,154,42,.08);cursor:pointer">
        <span style="font-weight:700;font-size:.8rem">🌱 ${esc(kupe || '—')} · Hayvan kartına git →</span>
        <span style="color:var(--ink3)">›</span>
      </div>
    </div>`;
    document.body.appendChild(box);
    setTimeout(() => { if (box.parentNode) box.remove(); }, 10000);
  }catch(e){ /* banner başarısızlığı akışı etkilemez */ }
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

/**
 * Verilen etken koduna göre ilaç sınıflarını ve ürünlerini kontrol ederek,
 * ilgili etken maddeyi içeren stok kayıtlarını filtreler.
 * @param {string} etkenKod Filtreleme yapılacak etken maddenin kodu.
 * @param {Array} stoklar Filtrelenmesi gereken stok kayıtları dizisi.
 * @returns {Array} İlgili etken maddeyi içeren stok kayıtlarından oluşan dizi.
 */
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

/**
 * Belirtilen stok ID'sine ait son doz bilgisini uygulama log kayıtlarından getirir.
 * @param {string} stokId - Aranan doz bilgisinin kayıtlı olduğu stok kimliği.
 * @returns {Object|null} Son doz bilgisi içeren { doz, birim } objesi veya bulunamazsa null.
 */
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

/**
 * Verilen stok ID'sine ait doz ve birim bilgilerini alıp ilgili HTML elemanlarına doldurur.
 * @param {string} stokId - Doz ve birim bilgisi alınacak stokun kimliği.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function _puDozPrefill(stokId) {
  _sonDozGetir(stokId).then(d => {
    if (!d) return;
    const dozEl = document.getElementById('pu-doz');
    const birimEl = document.getElementById('pu-birim');
    if (dozEl && d.doz) dozEl.value = d.doz;
    if (birimEl && d.birim) birimEl.value = d.birim;
  });
}

// ═══ DOZAJ HELPERİ — 💡 tıkla-doldur (spec §3.3; asla otomatik yazma) ═══
// _dozHintBtnHtml: doz input'unun yanına ufak buton. drugId boş ve stokInpId
// verildiyse (pu modalları) ilaç, seçili stok option'ının data-dp'sinden çözülür.
// hayvanIds boşsa (hayvan bağlamı yok — örn. şablon builder) buton hiç üretilmez.
/**
 * Dozaj önerisi butonu için HTML kodunu oluşturur.
 * @param {string} inpId Doz giriş alanının ID'si.
 * @param {string} drugId İlaç ID'si (varsa).
 * @param {string} hayvanIds Hayvan ID'leri.
 * @param {string} stokInpId Stok giriş alanının ID'si (ilaç yoksa).
 * @returns {string} Oluşturulan buton HTML elemanı veya boş string.
 */
function _dozHintBtnHtml(inpId, drugId, hayvanIds, stokInpId) {
  if (!hayvanIds || (!drugId && !stokInpId)) return '';
  const dAttr = drugId ? ` data-drug="${drugId}"` : ` data-stok-inp="${stokInpId}"`;
  return `<button type="button" title="Dozaj önerisi: kart dozu × canlı ağırlık — tıkla, dozu doldur"` +
    ` data-action="doz-oneri"${dAttr} data-doz-inp="${inpId}" data-hayvan="${hayvanIds}"` +
    ` style="flex-shrink:0;width:34px;min-height:34px;align-self:stretch;border:none;border-radius:7px;background:rgba(42,107,181,.12);color:var(--blue);cursor:pointer;font-size:.95rem;line-height:1">💡</button>`;
}

// Buton tıklaması: artık doğrudan değer yazmaz — DOZAJ HELPER SHEET'ini açar.
// Sheet: hayvan kg + ilaç pratik/pro dozajları (kartlardan öndolum; boşsa
// buradan girilir) + canlı hesap çipleri (pratik/pro × min/varsayılan/max).
// Tek tıkla uygula → kilo HAYVAN kartına, dozaj oranları İLAÇ kartına yazılır
// (RPC) ve seçilen değer doz kutusuna aktarılır; sheet kapanır. Arka plandaki
// planlama formu ASLA kapatılmaz/sıfırlanmaz (kullanıcı kuralı, 2026-09-09).
/**
 * Verilen butonun `data-doz-inp` özelliğindeki ID'ye sahip elemanı döndürür.
 * Eğer bu özellik yoksa, butonun ebeveynindeki `input.cdf-dose-inp` sınıfına sahip input elemanını döndürür.
 * @param {HTMLElement} btn Buton elemanı.
 * @returns {HTMLElement|null} Bulunan input elemanı veya null.
 */
function _dozInpBul(btn) {
  return btn.dataset.dozInp
    ? document.getElementById(btn.dataset.dozInp)
    : (btn.parentElement && btn.parentElement.querySelector('input.cdf-dose-inp')) || null;
}

/**
 * Verilen butonun veri setinden ilaç kimliği (drugId) çıkarır, varsa stok seçiminden drugId'yi çeker,
 * ilaç önbelleğini (cache) yükler ve bulunan ilaç kartını kullanarak doz öneri sayfasını açar.
 * @param {HTMLElement} btn Buton elemanı; dataset üzerinden drugId, stok input ID'si, hayvan ID listesi gibi verileri barındırır.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function dozOneriUygula(btn) {
  try {
    let drugId = btn.dataset.drug || '';
    if (!drugId && btn.dataset.stokInp) {
      const sel = document.getElementById(btn.dataset.stokInp);
      drugId = sel?.selectedOptions?.[0]?.dataset?.dp || '';
    }
    if (!drugId) { toast('💡 Bu kayıtta ilaç kartı (drug_product) yok — öneri yapılamaz', true); return; }
    if (!(_drugsCache && _drugsCache.length)) { try { await loadDrugsCache(); } catch (e) {} }
    const kart = (_drugsCache || []).find(d => d.id === drugId);
    if (!kart) { toast('💡 İlaç kartı bulunamadı', true); return; }
    const ids = (btn.dataset.hayvan || '').split(',').filter(Boolean);
    _dozSheetAc(btn, kart, ids);
  } catch (e) {
    toast('💡 Hata: ' + (e.message || e), true);
  }
}

// ── Helper sheet ──
const _DOZ_TIP_ETIKET = { pratik: 'ml/kg yolu', pro: 'mg/kg yolu', sabit: 'Sabit doz' };
const _DOZ_SEVIYE_ETIKET = { min: 'Min', tip: 'Varsayılan', max: 'Max' };

/**
 * Doz formundaki çeşitli girdi alanlarından pozitif sayı değerlerini okuyup tek bir nesnede toplar.
 * Pratik doz alanı "X kg'a Y ml" çiftinden ml/kg oranı olarak hesaplanır; geçersiz eksik değerler null olur.
 * @returns {Object} kg, pratik, pratikKg, pro, conc, min ve max alanlarını içeren doz değerleri nesnesi; okunamayan alanlar null.
 */
function _dozSheetOku() {
  /**
   * Belirtilen ID'ye sahip input elemanının değerini alıp sayıya çevirir.
   * Değer geçerli bir pozitif sayı ise onu döndürür, aksi takdirde null döndürür.
   * @param {string} id - Değerinin alınacağı input elemanının DOM ID'si.
   * @returns {number|null} Geçerli pozitif sayı veya null.
   */
  const sayi = id => { const v = parseFloat(document.getElementById(id)?.value); return Number.isFinite(v) && v > 0 ? v : null; };
  return {
    kg: sayi('doz-sheet-kg'),
    // Pratik doz = "X kg'a Y ml" çifti (saha dili): oran = Y ÷ X (ml/kg).
    pratik: (() => { const kg = sayi('doz-sheet-pratik-kg'), ml = sayi('doz-sheet-pratik-ml');
      return (kg && ml) ? ml / kg : null; })(),
    pratikKg: sayi('doz-sheet-pratik-kg'),
    pro: sayi('doz-sheet-pro'),
    conc: sayi('doz-sheet-conc'),
    min: sayi('doz-sheet-min'),
    max: sayi('doz-sheet-max'),
  };
}

// Girdilere göre hesap tabanını kur: pro doluysa pro-bazlı (pratik çipleri
// conc'tan), değilse pratik-bazlı; ikisi de boşsa kartın kendi değerleri.
// KULLANICI NEYİ DEĞİŞTİRDİYSE O KAZANIR (2026-09-09: pro öndolumu hep
// öncelikliydi, pratik girişi görmezden geliniyordu — "aynı değerler geri
// geliyor" şikayetinin kökü):
//  - pro (mg/kg) kart değerinden farklı girildiyse ya da kart mg/kg değilken
//    elle doldurulduysa → pro-bazlı
//  - değilse pratik çifti (kg→ml) doluysa → pratik-bazlı (ml/kg)
//  - değilse kartın kendi değerleri.
/**
 * Verilen okunan doz bilgisi ve kart verisini karşılaştırarak,
 * doz birimi (mg/kg veya ml/kg) ve pratik doz değerlerini belirleyip
 * uygun standart doz objesini döndürür veya orijinal kartı döndürür.
 * @param {Object} okunan Okunan doz bilgisi (pro, pratik, min, max, conc vb. özelliklere sahip).
 * @param {Object} kart Kaynak kart verisi (std_dose_unit, std_dose, default_unit, birim vb. özelliklere sahip).
 * @returns {Object} Standart doz bilgisi içeren obje veya orijinal kart objesi.
 */
function _dozSheetTaban(okunan, kart) {
  const kartMgKg = kart.std_dose_unit === 'mg/kg';
  const proDegisti = okunan.pro && ((kartMgKg && okunan.pro !== +kart.std_dose) || (!kartMgKg && !okunan.pratik));
  if (okunan.pro && proDegisti) return { std_dose: okunan.pro, std_dose_unit: 'mg/kg', std_dose_min: okunan.min, std_dose_max: okunan.max, concentration: okunan.conc, default_unit: kart.default_unit || kart.birim || 'ml' };
  if (okunan.pratik) return { std_dose: okunan.pratik, std_dose_unit: 'ml/kg', std_dose_min: okunan.min, std_dose_max: okunan.max, concentration: okunan.conc, default_unit: kart.default_unit || kart.birim || 'ml' };
  if (okunan.pro) return { std_dose: okunan.pro, std_dose_unit: 'mg/kg', std_dose_min: okunan.min, std_dose_max: okunan.max, concentration: okunan.conc, default_unit: kart.default_unit || kart.birim || 'ml' };
  return kart;
}

/**
 * Belirtilen hayvan ID'lerine sahip hayvanları getirir, dozajlama arayüzünü oluşturur ve ekrana ekler.
 * Arayüzde hayvan bilgileri, ağırlık girişi, ilaç dozajlama seçenekleri (sabit, pratik, mg/kg) ve doz kaydetme butonları bulunur.
 * @param {HTMLElement} btn İlaç kartı butonu.
 * @param {Object} kart İlaç kartı nesnesi.
 * @param {Array} ids Seçilen hayvanların ID'lerinden oluşan dizi.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @olay click, input
 */
function _dozSheetAc(btn, kart, ids) {
  document.getElementById('doz-sheet')?.remove();
  const animals = getState('animals') || [];
  const _ilk = ids.map(id => animals.find(a => a.id === id)).filter(Boolean);
  const tekHayvan = ids.length === 1;
  const kupe = _ilk.length ? (_ilk[0].kupe_no || _ilk[0].devlet_kupe || '') : '';
  const _kgler = _ilk.map(a => +a.canli_agirlik || 0).filter(x => x > 0);
  const kgNow = _kgler.length ? Math.max(..._kgler) : '';
  const unit = kart.std_dose_unit || 'ml/kg';
  /**
   * Değer null, undefined veya boş dize ise boş dize döndürür; aksi halde değeri olduğu gibi döndürür.
   * @param {*} x - Kontrol edilecek değer.
   * @returns {*} Değer null, undefined veya boş dize ise boş dize, değilse değerin kendisi.
   */
  const _f = x => (x === null || x === undefined || x === '' ? '' : x);
  const isSabit = unit === 'ml/hayvan';

  // Repo modal deseni (.mo + .modal): dar ekranda alt-sheet, geniş ekranda
  // ortalanmış compact kart (max-width 560 — tedavi modalıyla aynı davranış).
  // z-index 600: vaka detay (.mo z-80) ve pu mini modalların (z-500) üstünde.
  const mini = document.createElement('div');
  mini.id = 'doz-sheet';
  mini.className = 'mo';
  mini.style.zIndex = '600';
  mini.setAttribute('data-action', 'mclose-overlay');
  mini.innerHTML = `<div class="modal"><div class="m-handle"></div><div style="padding:4px 16px 18px">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:2px">
      <div style="font-weight:800;font-size:.92rem">💡 Dozaj Helperı</div>
      <button id="doz-sheet-kapat" style="background:none;border:none;font-size:1.15rem;cursor:pointer;color:var(--ink3)">✕</button>
    </div>
    <div style="font-size:.73rem;color:var(--ink3);margin-bottom:12px">${_ilk.length ? '🐄 ' + esc(kupe) + (tekHayvan ? ' · kilo kaydedilir' : ' · çoklu seçim — kilo kaydedilmez, yalnız hesap') : '🐄 hayvan bağlamı yok — yalnız ilaç kartı'}</div>
    <div style="background:var(--card2);border-radius:10px;padding:10px;margin-bottom:8px">
      <label style="font-size:.68rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.05em">🐄 Hayvan</label>
      <div style="display:flex;align-items:center;gap:8px;margin-top:4px">
        <input id="doz-sheet-kg" type="number" step="0.5" min="1" inputmode="decimal" placeholder="Canlı ağırlık (kg)" value="${_f(kgNow)}" style="flex:1;padding:9px;border-radius:8px;border:1px solid var(--border);font-size:.85rem;min-width:0">
        ${tekHayvan ? '' : '<span style="font-size:.66rem;color:var(--ink3);flex-shrink:0">referans: en ağır</span>'}
      </div>
    </div>
    <div style="background:var(--card2);border-radius:10px;padding:10px;margin-bottom:8px">
      <label style="font-size:.68rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.05em">💊 ${esc(kart.name || 'İlaç kartı')} — dozajlama</label>
      ${isSabit
        ? `<div style="font-size:.78rem;margin-top:6px">Sabit doz tipi (ml/hayvan) — kart: <b>${_f(kart.std_dose)} ml</b>${kart.std_dose_min ? ' · aralık ' + _f(kart.std_dose_min) + '–' + _f(kart.std_dose_max) : ''}</div>
           <input type="hidden" id="doz-sheet-sabit" value="${_f(kart.std_dose)}">`
        : `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:6px">
        <div style="grid-column:1 / -1"><label style="font-size:.64rem;color:var(--ink3)">Pratik doz — kaç kg'a kaç ml? <span title="Örn: 50 kg'a 2 ml → 500 kg hayvana 20 ml">ⓘ</span></label><div style="display:grid;grid-template-columns:1fr 14px 1fr;gap:4px;align-items:center">
        <input id="doz-sheet-pratik-kg" type="number" step="1" min="1" inputmode="decimal" placeholder="kg" value="${unit === 'ml/kg' && +kart.std_dose > 0 ? '50' : ''}" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.82rem;min-width:0;text-align:center">
        <span style="text-align:center;color:var(--ink3);font-size:.7rem">kg'a</span>
        <input id="doz-sheet-pratik-ml" type="number" step="0.1" min="0" inputmode="decimal" placeholder="ml" value="${unit === 'ml/kg' && +kart.std_dose > 0 ? String(Math.round(+kart.std_dose * 50 * 100) / 100) : ''}" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.82rem;min-width:0;text-align:center">
        </div></div>
        <div><label style="font-size:.64rem;color:var(--ink3)">mg/kg oranı (pro)</label><input id="doz-sheet-pro" type="number" step="0.01" min="0" inputmode="decimal" placeholder="örn: 2" value="${unit === 'mg/kg' ? _f(kart.std_dose) : ''}" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.82rem;min-width:0"></div>
        <div><label style="font-size:.64rem;color:var(--ink3)">Konsantrasyon (mg/ml) — 1 ml ilaçtaki etken</label><input id="doz-sheet-conc" type="number" step="0.01" min="0" inputmode="decimal" placeholder="örn: 50" value="${_f(kart.concentration)}" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.82rem;min-width:0"></div>
        <div style="display:grid;grid-template-columns:1fr auto 1fr auto;gap:4px;align-items:end">
          <div><label style="font-size:.64rem;color:var(--ink3)">Min dozaj (<span id="doz-sheet-mm-birim">${unit === 'mg/kg' ? 'mg/kg' : 'ml/kg'}</span>)</label><input id="doz-sheet-min" type="number" step="0.01" min="0" inputmode="decimal" placeholder="örn: 0,02" value="${_f(kart.std_dose_min)}" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.82rem;min-width:0"></div>
          <button type="button" id="doz-sheet-min-btn" title="Min dozu (alt sınır) tedaviye yaz" style="height:37px;padding:0 8px;border:none;border-radius:8px;background:rgba(42,107,181,.12);color:var(--blue);font-size:.72rem;font-weight:700;cursor:pointer;white-space:nowrap">📥 —</button>
          <div><label style="font-size:.64rem;color:var(--ink3)">Max dozaj (<span id="doz-sheet-mm-birim-max">${unit === 'mg/kg' ? 'mg/kg' : 'ml/kg'}</span>)</label><input id="doz-sheet-max" type="number" step="0.01" min="0" inputmode="decimal" placeholder="örn: 0,06" value="${_f(kart.std_dose_max)}" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.82rem;min-width:0"></div>
          <button type="button" id="doz-sheet-max-btn" title="Max dozu (üst sınır) tedaviye yaz" style="height:37px;padding:0 8px;border:none;border-radius:8px;background:rgba(190,66,50,.12);color:var(--red);font-size:.72rem;font-weight:700;cursor:pointer;white-space:nowrap">📥 —</button>
        </div>
        <div style="font-size:.62rem;color:var(--ink3);margin-top:4px">Min/Max = prospektüs aralığının alt/üst dozu (aynı oranda). 📥 butonu o dozu kilo ile hesaplayıp tedaviye yazar — hayvan kilosu ve oranlar değiştikçe canlı güncellenir.</div>
      </div>
      <div style="font-size:.62rem;color:var(--ink3);margin-top:4px">ml/kg ve mg/kg aynı dozun iki yazılışıdır — konsantrasyon ikisini birbirine çevirir. <b>Pratik doz = hayvana verilecek ml</b>; aşağıda ağırlıkla hesaplanır.</div>`}
    </div>
    <div id="doz-sheet-cipler" style="margin-bottom:8px"></div>
    <div style="display:flex;gap:8px">
      <button id="doz-sheet-kaydet" class="btn" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:8px;padding:10px;font-weight:700;cursor:pointer">💾 Kartlara yaz</button>
      <button id="doz-sheet-iptal" style="flex:0 0 auto;background:var(--card3);border:none;border-radius:8px;padding:10px 14px;cursor:pointer">İptal</button>
    </div>
    <div style="font-size:.62rem;color:var(--ink3);margin-top:6px">Çipe tıkla = kaydet + doz kutusuna yaz. Sadece kaydetmek istersen "💾 Kartlara yaz". Yazmadan ✕ ile çıkabilirsin.</div>
  </div></div>`;
  document.body.appendChild(mini);
  openM('doz-sheet');
  document.getElementById('doz-sheet-kapat').onclick = _dozSheetKapat;
  document.getElementById('doz-sheet-iptal').onclick = _dozSheetKapat;
  ['doz-sheet-kg','doz-sheet-pratik-kg','doz-sheet-pratik-ml','doz-sheet-pro','doz-sheet-conc','doz-sheet-min','doz-sheet-max'].forEach(id => {
    document.getElementById(id)?.addEventListener('input', () => _dozSheetCiplerCiz(kart, btn, ids));
  });
  ['min','max'].forEach(sv => document.getElementById('doz-sheet-' + sv + '-btn')?.addEventListener('click', () => {
    const b = document.getElementById('doz-sheet-' + sv + '-btn');
    if (!b || b.disabled || !b.dataset.doz) return;
    _dozSheetUygula(btn, document.getElementById('doz-sheet'), kart, ids,
      { doz: +b.dataset.doz, birim: b.dataset.birim || 'ml', aciklama: b.dataset.aciklama || '' });
  }));
  document.getElementById('doz-sheet-kaydet').onclick = () => _dozSheetUygula(btn, mini, kart, ids, null);
  _dozSheetCiplerCiz(kart, btn, ids);
}

/**
 * 'doz-sheet' elementini bulup kapatır ve DOM'dan kaldırır.
 * @returns {void} Hiçbir değer döndürmez.
 */
function _dozSheetKapat() {
  const s = document.getElementById('doz-sheet');
  if (!s) return;
  closeM('doz-sheet');
  s.remove();
}

// Hesap çiplerini canlı çiz — her çip tek tıkla: kartlara yaz + doz kutusuna aktar + kapat.
/**
 * Doz hesaplama sheet'indeki çip butonlarını (hesaplanan doz önerileri) çizer ve min/max doz butonlarını canlı hesaplayarak günceller.
 * @param {Object} kart - Doz hesaplaması yapılan ilaç kartı.
 * @param {HTMLElement} btn - Doz uygulandığında kullanılan tetikleyici buton.
 * @param {Object} ids - Doz uygulama işleminde kullanılacak element kimlikleri.
 * @returns {void}
 */
function _dozSheetCiplerCiz(kart, btn, ids) {
  const bolum = document.getElementById('doz-sheet-cipler');
  if (!bolum) return;
  const okunan = _dozSheetOku();
  const taban = _dozSheetTaban(okunan, kart);
  const cipler = dozCipleri(okunan.kg, taban);
  if (!cipler.length) {
    bolum.innerHTML = '<div style="font-size:.72rem;color:var(--ink3);padding:6px 2px">' +
      (okunan.kg ? 'Hesap için ml/kg veya mg/kg oranını girin.' : 'Önce canlı ağırlığı girin — hayvana verilecek doz burada hesaplanır.') + '</div>';
    return;
  }
  const _renk = { pratik: 'var(--green)', pro: 'var(--blue)', sabit: 'var(--ink3)' };
  bolum.innerHTML = '<div style="font-size:.66rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.05em;margin:2px 0 6px">Hayvana verilecek doz — çipe tıkla: kartlara yazılır + doz kutusuna aktarılır</div>' +
    '<div style="display:flex;flex-wrap:wrap;gap:6px">' +
    cipler.map((c, i) => `<button type="button" data-cip="${i}" style="background:${_renk[c.tip] || 'var(--card3)'};color:#fff;border:none;border-radius:8px;padding:8px 10px;font-size:.74rem;font-weight:700;cursor:pointer;text-align:left">` +
      `${_DOZ_TIP_ETIKET[c.tip]} · ${_DOZ_SEVIYE_ETIKET[c.seviye]}: <b>${esc(String(c.doz).replace('.', ','))} ${esc(c.birim)}</b><br>` +
      `<span style="font-weight:500;font-size:.64rem;opacity:.85">${esc(c.aciklama)}</span></button>`).join('') +
    '</div>';
  bolum.querySelectorAll('[data-cip]').forEach(el => {
    el.onclick = () => _dozSheetUygula(btn, document.getElementById('doz-sheet'), kart, ids, cipler[+el.dataset.cip]);
  });
  // Min/Max 📥 butonları — hayvan kg'ı ve oranlarla CANLI hesaplanır; tıklayınca
  // kartlara yazılır + o doz tedaviye yazılır (kullanıcı istekleri, 2026-09-09).
  /**
   * Belirtilen seviye (min veya max) için doz önerisi hesaplayıp ilgili butonu günceller.
   * @param {string} seviye 'min' veya 'max' değerlerinden biri.
   * @returns {void} Fonksiyon herhangi bir değer döndürmez.
   */
  const _mmBtn = seviye => {
    const btnEl = document.getElementById('doz-sheet-' + seviye + '-btn');
    if (!btnEl) return;
    const oran = seviye === 'min' ? okunan.min : okunan.max;
    if (!oran || !okunan.kg) { btnEl.disabled = true; btnEl.textContent = '📥 —'; return; }
    const r = dozOner(okunan.kg, { ...taban, std_dose: oran });
    if (!r.ok) { btnEl.disabled = true; btnEl.textContent = '📥 —'; return; }
    btnEl.disabled = false;
    btnEl.textContent = '📥 ' + String(r.doz).replace('.', ',') + ' ' + r.birim;
    btnEl.dataset.doz = String(r.doz);
    btnEl.dataset.birim = r.birim;
    btnEl.dataset.aciklama = r.aciklama;
  };
  _mmBtn('min'); _mmBtn('max');
}

/**
 * Dozajlama sayfasından okunan verileri işleyerek, gerekli güncellemeleri (kilo, standart doz, konsantrasyon, min/max değerler) yapar ve ilgili hayvan veya ilaç kartlarını günceller.
 * @param {HTMLElement} btn Dozajlama sayfasını tetikleyen buton elemanı.
 * @param {boolean} mini Mini mod olup olmadığını belirten bayrak.
 * @param {Object} kart Güncellenecek veya oluşturulacak ilaç kartı nesnesi.
 * @param {Array} ids Güncellenecek hayvanların ID'lerinden oluşan dizi.
 * @param {Object} cip Aktif bir çip (chip) nesnesi ise çip ile ilgili işlemler (doz okuma, sayfa kapatma) yapılır.
 * @returns {Promise<void>} İşlemlerin tamamlandığı veya başarısız olduğu durumu temsil eden Promise.
 * @rpc hayvan_kilo_guncelle, ilac_dozaj_guncelle
 */
async function _dozSheetUygula(btn, mini, kart, ids, cip) {
  const okunan = _dozSheetOku();
  const dozInp = _dozInpBul(btn);
  const kaydetBtn = document.getElementById('doz-sheet-kaydet');
  /**
   * Kaydet butonunu devre dışı bırakır ve üzerini 'Yazılıyor…' metniyle günceller.
   * @returns {void} Fonksiyon bir değer döndürmez.
   */
  const _kaydetKilit = () => { if (kaydetBtn) { kaydetBtn.disabled = true; kaydetBtn.textContent = 'Yazılıyor…'; } };
  /**
   * Kaydet butonunu aktif hale getirir ve metin içeriğini '💾 Kartlara yaz' olarak günceller.
   * @returns {void} Fonksiyon bir değer döndürmez.
   */
  const _kaydetAc = () => { if (kaydetBtn) { kaydetBtn.disabled = false; kaydetBtn.textContent = '💾 Kartlara yaz'; } };
  const taban = _dozSheetTaban(okunan, kart);
  const guncellemeler = {};
  if (taban !== kart) {
    if (taban.std_dose_unit === 'mg/kg') {
      guncellemeler.std_dose = taban.std_dose;
      guncellemeler.std_dose_unit = 'mg/kg';
      if (okunan.conc) { guncellemeler.concentration = okunan.conc; guncellemeler.concentration_unit = 'mg/ml'; }
    } else {
      guncellemeler.std_dose = taban.std_dose;
      guncellemeler.std_dose_unit = 'ml/kg';
    }
    if (okunan.min) guncellemeler.std_dose_min = okunan.min;
    if (okunan.max) guncellemeler.std_dose_max = okunan.max;
  }
  const kgYaz = okunan.kg && ids.length === 1 ? okunan.kg : null;
  if (!guncellemeler.std_dose && !kgYaz && !cip) {
    toast('💡 Kaydedilecek değer yok — kilo ve dozajlama girin', true);
    return;
  }
  _kaydetKilit();
  try {
    if (kgYaz) {
      // hayvan_guncelle 3 overload'lu — minimal çağrıda PostgREST belirsizlik
      // veriyor; kilo yazımı tek amaçlı RPC'den geçer (20260909110000).
      const res = await rpc('hayvan_kilo_guncelle', { p_id: ids[0], p_canli_agirlik: kgYaz });
      if (res?.ok === false) throw new Error(res.mesaj || 'Kilo kaydı başarısız');
      const yeni = (getState('animals') || []).map(a => a.id === ids[0] ? { ...a, canli_agirlik: kgYaz } : a);
      if (yeni.length) setState('animals', yeni);
    }
    if (Object.keys(guncellemeler).length) {
      const res = await rpc('ilac_dozaj_guncelle', { p_id: kart.id, p_guncellemeler: guncellemeler });
      if (res?.ok === false) throw new Error(res.mesaj || 'İlaç kartı yazımı başarısız');
      Object.assign(kart, guncellemeler); // cache'i yerinde güncelle
    }
    pullTables(['hayvanlar', 'drug_products']).catch(() => {});
    if (!cip) _dozSheetCiplerCiz(kart, btn, ids); // kartlara-yaz sonrası çipler tazelensin
    if (cip && dozInp) dozInp.value = cip.doz;
    if (cip) {
      _dozSheetKapat(); // çip: kaydet + aktar + kapat — kaldığın yerden devam
      toast('💡 ' + cip.aciklama);
    } else {
      // 💾 Kartlara yaz: yalnız kaydet — sheet AÇIK kalır, planlamaya devam
      toast('💾 Kartlara yazıldı — sheet açık, devam edebilirsin');
      _kaydetAc();
    }
  } catch (e) {
    toast('❌ ' + (e.message || e), true);
    _kaydetAc();
  }
}

/**
 * Belirtilen indeksdeki protokol uyarısını alarak uygun stokları filtreler,
 * bir modal arayüzü oluşturur ve kullanıcıya stok, doz, uygulama yolu gibi
 * bilgileri girerek protokolü kaydetme işlemi için hazır hale getirir.
 * @param {number} idx Protokol uyarılar dizisindeki indeks.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @olay change
 */
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

  const stokOpts = ilaclar.map(s => `<option value="${s.id}" data-birim="${esc(s.birim||'ml')}" data-dp="${s.drug_product_id||''}">${esc(s.urun_adi)}</option>`).join('');
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin','Meme içi'].map(r => `<option value="${r}">${r}</option>`).join('');
  const ilkBirim = ilaclar[0]?.birim || 'ml';
  const _dozBtn = _dozHintBtnHtml('pu-doz', '', d.hayvan_id, 'pu-stok');

  mini.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:4px">💉 Protokol Uygula</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">${esc(d.kupe_no||'?')} · ${esc(d.adim)}</div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Stok</label>
    <select id="pu-stok" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${stokOpts}</select>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:2"><label style="font-size:.7rem;font-weight:600">Doz</label><div style="display:flex;gap:4px"><input id="pu-doz" type="number" step="0.1" min="0.1" value="1" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem;flex:1;min-width:0">${_dozBtn}</div></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Birim</label><input id="pu-birim" value="${ilkBirim}" readonly style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem;background:var(--card2);color:var(--ink3)"></div>
    </div>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Uygulama zamanı (opsiyonel)</label>
        <input id="pu-tarih" type="text" placeholder="gg.aa.yyyy" class="fi" style="width:100%;padding:6px;border-radius:8px;border:1px solid var(--border);font-size:.78rem"></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Saat</label>
        <input id="pu-saat" type="time" class="fi" style="width:100%;padding:6px;border-radius:8px;border:1px solid var(--border);font-size:.78rem"></div>
    </div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Uygulama Yolu</label>
    <select id="pu-rota" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:12px;font-size:.8rem">${rotaOpts}</select>
    <button id="pu-kaydet-btn" onclick="_protokolUygulaKaydet('${d.hayvan_id}',${idx})" class="btn" style="width:100%;padding:10px;font-weight:700">Kaydet</button>
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

/**
 * Belirtilen hayvan ID'si için stok, doz, rota ve uygulama tarihi gibi parametreleri doğrulayarak
 * hizli_uygulama RPC çağrısı yapar, kapı hata yönetimini (onaylı tekrar) işler ve başarılı olursa
 * protokolü kaydeder, arayüzü günceller ve butonu aktif hale getirir.
 * @param {string} hayvanId Kaydedilecek protokolün ait olduğu hayvanın ID'si.
 * @param {number} idx Protokol detayının gösterileceği dizideki indeks.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc hizli_uygulama
 */
async function _protokolUygulaKaydet(hayvanId, idx){
  const kaydetBtn=document.getElementById('pu-kaydet-btn');
  if(kaydetBtn&&kaydetBtn.disabled) return; // çift-gönderim: rpc uçuşta ikinci tık yok sayılır
  const stok = document.getElementById('pu-stok')?.value;
  const doz = parseFloat(document.getElementById('pu-doz')?.value);
  const birim = document.getElementById('pu-birim')?.value || 'ml';
  const rota = document.getElementById('pu-rota')?.value || 'IM';
  if (!stok) { toast('Stok seçilmedi', true); return; }
  if (!doz || isNaN(doz) || doz <= 0) { toast('Geçerli doz girin', true); return; }
  if(kaydetBtn){kaydetBtn.disabled=true;kaydetBtn.textContent='İşleniyor…';}

  try {
    // P8: opsiyonel uygulama anı (boş → gönderilmez; MK7: 5dk ileri / 7 gün geri)
    const olcGun = _ovsyncTarihOku(document.getElementById('pu-tarih')?.value);
    if (document.getElementById('pu-tarih')?.value?.trim() && !olcGun) { toast('Uygulama tarihi gg.aa.yyyy olmalı', true); if(kaydetBtn){kaydetBtn.disabled=false;kaydetBtn.textContent='Kaydet';} return; }
    const olcSaat = document.getElementById('pu-saat')?.value || '';
    let occurredAt = null;
    if (olcGun) {
      occurredAt = _istanbulAnIso(olcGun, olcSaat);   // O11: sabit İstanbul +03 anchor (cihaz-diliminden bağımsız)
    }
    const params = {
      p_hayvan_id: hayvanId, p_stok_id: stok, p_doz: doz, p_birim: birim, p_rota: rota, p_notlar: '',
      ...(occurredAt ? { p_occurred_at: occurredAt } : {})
    };
    // P5: PG kapısı reaktif — sunucu RAISE'ı _pgKapiHata yakalar; onaylı tekrar
    // aynı parametrelere p_pg_onay/p_pg_gerekce eklenerek gönderilir (tek ekranda)
    const res = await rpc('hizli_uygulama', params).catch(e => {
      /**
       * Hızlı uygulama işlemleri için onay ve gerekçe bilgilerini içeren bir istek gönderir.
       * @param {boolean} onay İşlem onayı.
       * @param {string|null} gerekce İşlem gerekçesi.
       * @returns {Promise} RPC çağrısının sonucu.
       * @rpc hizli_uygulama
       */
      const retry = (onay, gerekce) => rpc('hizli_uygulama', {
        ...params, p_pg_onay: onay, p_pg_gerekce: gerekce || null
      });
      if (typeof _pgKapiHata === 'function' && _pgKapiHata(e, retry)) return { ok: true, _pgKapi: true };
      throw e;
    });
    if (res?._pgKapi) return;
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
  finally {
    // sheet remove edilmişse buton kopuktur; tekrar aktif etmek zararsız
    if(kaydetBtn){kaydetBtn.disabled=false;kaydetBtn.textContent='Kaydet';}
  }
}

/**
 * Protokol uyarısını kullanıcı onayıyla geçersiz kılar; dismiss kaydını upsert eder, eşleşen açık görevleri alt görevleriyle birlikte kapatır ve ilgili ekranları tazeler.
 * @param {number} idx - window.__protokolUyarilar dizisindeki uyarının indeksi.
 * @returns {Promise<void>} İşlem sonucunda değer döndürmez; hata durumunda hata mesajıyla toast gösterir.
 * @tablo gorev_log (select), protokol_dismiss (upsert)
 */
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
    // Dismiss uyarıyı bastırır ama gorev_log'daki açık görevi kapatmıyordu —
    // protokol_eksik_tara dismiss'u görünce uyarıyı bırakıyor, lakin loadTasks
    // dismiss kaydına hiç bakmadığı için görev Görevler ekranında kalıyordu.
    // detayIptal deseniyle (tamamlandi+iptal PATCH, alt görevler parent_id ile)
    // eşleşen açık görevleri kapat. etken_kod boşsa (MANUAL dismiss) görev
    // eşleştirilmez — yalnız dismiss kaydı yazılır.
    if (d.etken_kod) {
      try {
        const { data: acikGorevler, error: gErr } = await db.from('gorev_log')
          .select('id,hayvan_id,parent_id,gorev_tipi,aciklama,hedef_tarih,tamamlanma_tarihi,kaynak,etken_kod,tamamlandi,iptal')
          .eq('hayvan_id', d.hayvan_id)
          .eq('etken_kod', d.etken_kod)
          .eq('tamamlandi', false)
          .eq('iptal', false);
        if (gErr) throw new Error(gErr.message || 'gorev_log sorgusu başarısız');
        for (const t of (acikGorevler || [])) {
          await write('gorev_log', { ...t, tamamlandi: true, tamamlanma_tarihi: new Date().toISOString(), iptal: true }, 'PATCH', `id=eq.${t.id}`);
          const subs = await getData('gorev_log', s => s.parent_id === t.id && !s.tamamlandi);
          for (const s of subs) await write('gorev_log', { ...s, tamamlandi: true, iptal: true }, 'PATCH', `id=eq.${s.id}`);
        }
      } catch(e) { console.warn('dismiss görev kapatma:', e.message); }
      // Görev verisini tazele — kapatılan görev listeden ve badge'den düşsün
      try { await pullTables(['gorev_log']); } catch(e) {}
      try { if (document.getElementById('tasks-body')) await loadTasks(_curTaskFilter||'today'); } catch(e) {}
      try { await loadDash(); } catch(e) {}
    }
    await _islemSonrasiRefresh();
    const detayBs = document.getElementById('proto-detay-bs');
    if (detayBs) {
      detayBs.remove();
      const d2 = window.__protokolUyarilar.find(x => x.hayvan_id === d.hayvan_id && x.protokol === d.protokol);
      if (d2) _showProtokolDetay(d2.hayvan_id, d2.protokol, window.__protokolUyarilar.indexOf(d2));
    }
  } catch(e) { toast('Hata: '+e.message, true); }
}

/**
 * Verilen referans ID'ye sahip uygulama log kaydı için geri alma işlemi başlatır.
 * Kayıt kaynağı 'uygulama_log' değilse veya ID eksikse işlem iptal edilir ve kullanıcıya uyarı gösterilir.
 * Başarılı işlemde kaydı geri alır, başarısızlık durumunda hata mesajı gösterir.
 * @param {string} ref Geri alınacak kaydın kimliği (ID), formatı 'uygulama_log:ID' olmalıdır.
 * @returns {void} İşlem sonucu döndürmez.
 */
async function _protokolGeriAl(ref){
  // L4-W2: tek motor — protokol kapatması L2'ye bağlandı (hedef: uygulama_log
  // satırı; eski hizli_uygulama_geri_al RPC yolu UI'dan söküldü).
  const parts = String(ref||'').split(':');
  if (parts[0] !== 'uygulama_log' || !parts[1]) { toast('Bu işlem geri alınamaz (farklı kaynak)', true); return; }
  const uid = parts[1];
  try {
    const satirlar = await idbGetAll('uygulama_log');
    const satir = satirlar.find(x => x && x.id === uid);
    const hedef = { tablo: 'uygulama_log', pk: uid };
    if (satir && satir.created_at) hedef.zaman = satir.created_at;
    await dgGeriAlAkisi(hedef, 'satir', { olayEtiketi: 'Uygulama kaydı', zaman: (satir && satir.created_at) || '', kim: '' });
  } catch(e) { toast('Hata: '+e.message, true); }
}

// §5: Ortak işlem sonrası yenileme — scanner + badge + açık ekranlar
/**
 * Uygulama logu ve stok hareketi tablolarını çeker, eksik tara protokol uyarılarını getirir,
 * bildirim badge'ini günceller, görev badge'ini yeniler ve açık protokol ekranını kapatıp yeniler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 * @rpc protokol_eksik_tara
 */
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

/**
 * Belirtilen hayvan ID'si için stoktan ilaç/vitamin seçimi, doz, birim ve uygulama yolu bilgilerini alarak
 * hızlı kayıt formunu oluşturur ve ekrana ekler.
 * @param {string} hayvanId Kayıt yapılacak hayvanın ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @olay change
 */
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
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin','Meme içi'].map(r => `<option value="${r}">${r}</option>`).join('');
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
    <button id="pu-kaydet-btn" onclick="_hayvanHizliUygulaKaydet('${hayvanId}')" class="btn" style="width:100%;padding:10px;font-weight:700">Kaydet</button>
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

/**
 * Belirtilen hayvan ID'si için stok, doz, birim ve rota bilgilerini alarak hızlı uygulama kaydı yapar.
 * Kayıt butonu durumunu yönetir, sunucu yanıtını işler ve başarılı olursa ilgili bileşenleri günceller.
 * @param {string} hayvanId Kayıt yapılacak hayvanın benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc hizli_uygulama
 */
async function _hayvanHizliUygulaKaydet(hayvanId){
  const kaydetBtn=document.getElementById('pu-kaydet-btn');
  if(kaydetBtn&&kaydetBtn.disabled) return; // çift-gönderim: rpc uçuşta ikinci tık yok sayılır
  const stok = document.getElementById('pu-stok')?.value;
  const doz = parseFloat(document.getElementById('pu-doz')?.value);
  const birim = document.getElementById('pu-birim')?.value || 'ml';
  const rota = document.getElementById('pu-rota')?.value || 'IM';
  if (!stok) { toast('Stok seçilmedi', true); return; }
  if (!doz || isNaN(doz) || doz <= 0) { toast('Geçerli doz girin', true); return; }
  if(kaydetBtn){kaydetBtn.disabled=true;kaydetBtn.textContent='İşleniyor…';}

  try {
    const params = {
      p_hayvan_id: hayvanId, p_stok_id: stok, p_doz: doz, p_birim: birim, p_rota: rota, p_notlar: ''
    };
    // P5: PG kapısı reaktif — sunucu RAISE'ı _pgKapiHata yakalar; onaylı tekrar
    // aynı parametrelere p_pg_onay/p_pg_gerekce eklenerek gönderilir (tek ekranda)
    const res = await rpc('hizli_uygulama', params).catch(e => {
      /**
       * Hızlı uygulama işlemleri için onay ve gerekçe bilgilerini içeren bir istek gönderir.
       * @param {boolean} onay İşlem onayı.
       * @param {string|null} gerekce İşlem gerekçesi.
       * @returns {Promise} RPC çağrısının sonucu.
       * @rpc hizli_uygulama
       */
      const retry = (onay, gerekce) => rpc('hizli_uygulama', {
        ...params, p_pg_onay: onay, p_pg_gerekce: gerekce || null
      });
      if (typeof _pgKapiHata === 'function' && _pgKapiHata(e, retry)) return { ok: true, _pgKapi: true };
      throw e;
    });
    if (res?._pgKapi) return;
    if (res?.ok) {
      toast('✅ Uygulama kaydedildi');
      document.getElementById('proto-mini')?.remove();
      _islemSonrasiRefresh();
      openDet(hayvanId, true);
    } else {
      toast(res?.mesaj || 'Hata', true);
    }
  } catch(e) { toast('Hata: '+e.message, true); }
  finally {
    // sheet remove edilmişse buton kopuktur; tekrar aktif etmek zararsız
    if(kaydetBtn){kaydetBtn.disabled=false;kaydetBtn.textContent='Kaydet';}
  }
}
let _suruStatMode='son';

// ═══ BUG-062 FIX: Grup filtre chipleri DB'den dinamik render ═══
// Sebep: HTML'de statik grup chipleri yoktu, dynamic render kayboluyordu.
// Bu fonksiyon her sürü sayfası açılışında DB'den distinct grup değerlerini çeker
// ve #fc-grup-strip placeholder'ına chip olarak basar. HTML refactor'da
// placeholder kaybolsa bile, fonksiyon DOM'a yeniden basar (regression-proof).
let _grupFiltreCache=null;
/**
 * Hayvanlar tablosundan durumu 'Aktif' olan grupları çeker, null olanları ve tekrarları temizleyip Türkçe alfabetik sıralama yapar,
 * bu listeyi 'fc-grup-strip' elementine filtreleme HTML'i olarak uygular ve sonucu cache'ler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 * @tablo hayvanlar (select)
 */
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
/**
 * Grup filtre çubuğuna verilen gruplar için filtre çipi (chip) butonlarını oluşturup HTML olarak yerleştirir.
 * Grup yoksa çubuğun içeriğini temizler; mevcut aktif grup state'i korunarak aktif çipe 'on' sınıfı eklenir.
 * @param {HTMLElement} strip - Çiplerin render edileceği çubuk elementi.
 * @param {Array<string>} gruplar - Render edilecek grup adlarının dizisi.
 * @returns {void}
 */
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

/**
 * Sürü istatistik kartını oluşturur; grup filtresini günceller, varsa önbellekten gösterip arka planda tazeler, yoksa yükleme göstergesiyle veri çeker.
 * @returns {void}
 */
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

/**
 * Sunucudaki 'stat_suru_ozet' RPC'sini çağırıp dönen sürü özet istatistiklerini önbelleğe alır ve ilgili elemana uygular.
 * @param {HTMLElement|string} el - Sonuç HTML'inin uygulanacağı hedef eleman.
 * @param {string|null} padok - Padok kimliği; verilirse RPC parametrelerine p_padok olarak eklenir.
 * @param {string} key - Sonucun önbellekte (_suruStatCache) saklanması için kullanılan anahtar.
 * @returns {void} Döndürdüğü değer yoktur.
 * @rpc stat_suru_ozet
 */
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

/**
 * Belirtilen elemanın içindeki stat loading göstergesini (span) gösterir veya gizler.
 * @param {HTMLElement} el Stat göstergesinin aranacağı ana HTML elemanı.
 * @param {boolean} show Göstergelerin gösterilip gösterilmeyeceğini belirten bayrak.
 * @returns {void}
 */
function _showStatLoading(el,show){
  const sp=el.querySelector('.stat-loading');
  if(show&&!sp){
    const h=el.querySelector('.stat-header');
    if(h){const s=document.createElement('span');s.className='stat-loading';h.appendChild(s);}
  } else if(!show&&sp){ sp.remove(); }
}

/**
 * Verilen hayvan ve gebelik verilerini alarak demografik, gebelik, üreme verimliliği, sperma performansı, deneme dağılımı ve özel durumlar (sessiz, belirsiz) içeren kapsamlı bir HTML istatistik kartı oluşturur.
 * @param {HTMLElement} el İstatistik kartının yerleştirileceği HTML element.
 * @param {Object} d Hayvan ve gebelik verilerini içeren veri nesnesi.
 * @param {string} [padok] Padok (barn) etiketi için opsiyonel metin.
 * @returns {void} HTML içeriği oluşturulur ve elementin innerHTML özelliğine atanır.
 */
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
    /**
     * Verilen değeri kontrol eder; null veya undefined ise '—' karakterini, aksi takdirde '%${değer}' formatında döndürür.
     * @param {*} v Kontrol edilecek değer.
     * @returns {string} Değer null/undefined ise '—', değilse '%${v}' formatındaki string.
     */
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
  /**
   * Verilen tohumlama verisinden HTML satırı oluşturur.
   * @param {Object} s Tohumlama bilgilerini içeren nesne (ad, gebe, toplam, oran).
   * @returns {string} İstatistik satırını içeren HTML stringi.
   */
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
  const sessizSection=sessizCount>0?`<div class="stat-section"><div class="stat-section-title">❗ Sessiz Hayvanlar (${sessizCount})</div><div class="stat-row" style="color:var(--ink3);font-size:.7rem">50+ gündür tohumlama/kızgınlık kaydı yok</div><div class="stat-row"><span onclick="_showSessizList()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">Listeyi gör →</span></div></div>`:'';
  const belirsizCount=h.belirsiz||0;
  const belirsizSection=belirsizCount>0?`<div class="stat-section"><div class="stat-section-title">⚠️ Belirsiz Üreme Statüsü (${belirsizCount})</div><div class="stat-row" style="color:var(--ink3);font-size:.7rem">Düve mi olgun inek mi belirsiz — incelenip işaretlenmeli</div><div class="stat-row"><span onclick="_showBelirsizList()" style="cursor:pointer;color:var(--blue);font-size:.72rem;font-weight:600">Listeyi gör →</span></div></div>`:'';

  el.innerHTML=`<div class="stat-card${_suruStatOpen?' open':''}" onclick="_toggleSuruStat(event)">
    <div class="stat-header"><span>${padokLabel}🐄 ${h.toplam||0} hayvan · 🔬 ${h.tohumlanan||0} tohumlanan · 🤰 ${ho.gebe||0} gebe (${oran})</span><span class="stat-arrow">▼</span></div>
    <div class="stat-detail"><div style="display:flex;justify-content:flex-end;margin-bottom:4px"><span onclick="_toggleStatMode(event)" style="cursor:pointer;font-size:.68rem;font-weight:600;padding:2px 8px;border-radius:4px;background:var(--ink1);color:var(--ink4)">${_suruStatMode==='son'?'Son Dönem':'Tüm Zamanlar'} ↻</span></div>${demoHtml}${gebHtml}${verimHtml}${spSection}${sessizSection}${belirsizSection}${dnSection}</div>
  </div>`;
}

/**
 * Belirli bir hedef elemana tıklandığında, 'deneme-rest' ID'li eleman veya tıklanabilir bir eleman değilse,
 * '_suruStatOpen' durumunu tersine çevirir ve '#suru-stat-card .stat-card' seçili elemanın
 * 'open' sınıfını bu yeni duruma göre açar veya kapatır.
 * @param {Event} e Tıklama olayı.
 * @returns {void}
 */
function _toggleSuruStat(e){
  if(e.target.closest('#deneme-rest')||e.target.onclick) return;
  _suruStatOpen=!_suruStatOpen;
  const c=document.querySelector('#suru-stat-card .stat-card');
  if(c) c.classList.toggle('open',_suruStatOpen);
}

/**
 * Deneme modunun açık/kapalı durumunu değiştirir ve ilgili UI elemanlarını günceller.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * 'srch' input alanındaki arama sorgusunu işleyerek, 'ac-srch' dropdown'a eşleşen hayvan sonuçlarını HTML olarak oluşturur.
 * Sorgu boşsa veya sonuç bulunamazsa dropdown'u gizler.
 * Sonuçlar, gebelik durumu, irk bilgisi ve vurgu stilleri ile formatlanır.
 * @returns {void} Dropdown'a HTML içeriği ekler veya dropdown'u gizler.
 */
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
/**
 * Arama kutusuna verilen değeri yazar, otomatik tamamlama kutusunu gizler ve ilgili detayı açar.
 * @param {*} id - Detayı açılacak öğenin kimliği.
 * @param {*} kupe - Arama kutusuna yazılacak değer.
 * @returns {void} Değer döndürmez.
 */
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
/**
 * Fchip formunu sıfırlar, tüm seçenekleri pasif hale getirir ve varsayılan 'hepsi' seçeneğini aktif yapar.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function fchipReset(){
  _fchip={cinsiyet:'hepsi',gebelik:null,saglik:null,kisir:null,tekrar:null,grup:null,dogum:null};
  _hastaHastalikSecim=new Set(); _hastaHastalikAcik=false; _hastaHastalikSig=null;
  document.querySelectorAll('[id^="fc-"]').forEach(b=>b.classList.remove('on'));
  document.getElementById('fc-cinsiyet-hepsi')?.classList.add('on');
}
/**
 * Filtre çipi seçimini yönetir; aynı değer tekrar seçilirse seçimi kaldırır, aksi halde grubun önceki seçimini temizleyip yeni değeri işaretler ve filterA()'yı çağırır.
 * @param {string} grup - Filtre çipi grubunun adı; _fchip içindeki anahtar olarak kullanılır.
 * @param {*} deger - Seçilen/grubun durumunu belirleyecek değer; tekrar seçilirse null'a ayarlanır.
 * @param {HTMLElement} btn - Seçimi temsil eden buton öğesi; 'on' sınıfı eklenip kaldırılır.
 * @returns {void} Döndürülen değer yok.
 */
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
/**
 * Verilen vakalar ve hastalık isimleri listesi üzerinden, her hastalık için vakaların sayısını hesaplayıp
 * isimlerine göre alfabetik sıralama (Türkçe) yapar ve bu bilgileri içeren bir dizi döndürür.
 * @param {Array} vakalar Vakaların listesi. Her bir vakanın 'disease_id' özelliği olmalıdır.
 * @param {Array} diseases Hastalık tanımları listesi. Her bir hastalığın 'id' ve 'name' özellikleri olmalıdır.
 * @returns {Array} Hastalık isimlerine göre sıralanmış, her birinin id, name ve sayı (vakalar sayısı) özelliklerini içeren nesnelerden oluşan dizi.
 */
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
/**
 * Verilen vaka listesinden, her bir hayvan için en son açılış tarihini (start_date veya created_at) alarak bir Map oluşturur.
 * @param {Array} vakalar İşlenecek vaka nesnelerinin bulunduğu dizi.
 * @returns {Map} Hayvan ID'lerine göre en son açılış tarihlerini içeren Map.
 */
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
/**
 * Verilen hayvan listesi ve vaka verilerini kullanarak, seçilen hastalıklara sahip hayvanları filtreler ve aktif vaka açılış tarihlerine göre sıralar.
 * @param {Array} list Filtrelenmesi gereken hayvan kayıtlarının listesi.
 * @param {Array} vakalar Vaka verileri dizisi.
 * @param {Set} secim Filtreleme işlemi için seçilecek hastalık ID'lerinin bulunduğu Set.
 * @returns {Array} Seçilen hastalıklara sahip ve aktif vaka tarihine göre sıralanmış hayvan kayıtlarından oluşan dizi.
 */
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
/**
 * Hasta hastalıkları panelini açar veya kapatır; global açık durumunu güncelleyip panelin görünürlüğünü ayarlar.
 * @param {boolean} acik - Panelin açık (true) mı kapalı (false) mı olacağını belirtir.
 * @returns {void} Döndürülen değer yok.
 */
function _hastaHastalikAcKapa(acik){
  _hastaHastalikAcik=acik;
  const p=document.getElementById('hh-drop-panel');
  if(p) p.style.display=acik?'block':'none';
}
/**
 * Belirtilen hastalık ID'sini seçim listesine ekler veya çıkarır ve buton etiketini günceller.
 * @param {number|string} diseaseId Eklenmesi veya çıkarılacak hastalığın ID'si.
 * @param {boolean} checked Hastalığın seçili olup olmadığı durumu.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _hastaHastalikToggle(diseaseId,checked){
  if(checked) _hastaHastalikSecim.add(diseaseId); else _hastaHastalikSecim.delete(diseaseId);
  _hastaHastalikSig=null;   // buton etiketi (seçim sayısı) değişti → yeniden kur
  filterA();
}
/**
 * Hastalık seçimi için HTML kontrol paneli oluşturur. Seçili hastalıkların sayısına göre buton metnini günceller, temizle butonunu gösterir veya gizler ve hastalık listesini checkbox'lar halinde render eder.
 * @param {Array} secenekler Render edilecek hastalık seçeneklerinin (id, name, sayi vb.) bulunduğu dizi.
 * @returns {string} Oluşturulan HTML kodu.
 */
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
/**
 * Hasta hastalık filtresini günceller; eğer filtreleme modu aktif değilse veya seçilecek hastalık yoksa görünümü gizler, yoksa güncel hastalık ve sayı verilerini içeren HTML'i oluşturup gösterir.
 * @returns {void}
 */
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
/**
 * Arama sorgusu, padok, cinsiyet, gebelik durumu, sağlık durumu, grup ve tekrarlı doğum gibi filtreleri uygulayarak hayvan listesini günceller ve render eder.
 * @returns {void}
 */
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
// C2 (cila2): detay kartı chip'leri — liste satırı rozet diliyle parite.
// Kısır hayvanda "💲 Kısır" chip'i (amber), _animalTagsHtml'teki badge ile aynı renk.
/**
 * Verilen veri yapısından (a) grup, padok, kisır ve gebelik bilgilerini alarak HTML chip elemanları oluşturur.
 * Aktif vaka sayısı veya aktif hastalar varsa uyarı renginde, yoksa sağlıklı renginde gösterir.
 * Gebelik durumu varsa gün sayısını ve tahmini tarihleri hesaplayarak ekler.
 * Sonuç olarak filtrelenmiş ve stilize edilmiş HTML string döndürür.
 * @param {Object} a Ana veri nesnesi (grup, padok, kisır, gebelik tarihi vb. içerir).
 * @param {Array} tohs Gebelik sonuçları listesi.
 * @param {Number} aktifHst Aktif hastalar sayısı.
 * @param {Array} activeCases Aktif vaka listesi.
 * @returns {String} Chip elemanlarını içeren HTML string.
 */
function _detChipsHtml(a,tohs,aktifHst,activeCases){
  return [
    {cls:'chip-k',txt:a.grup||'?'},
    {cls:'chip-k',txt:a.padok||'?'},
    aktifHst>0||activeCases.length>0?{cls:'chip-r',txt:`🚨 ${activeCases.length||aktifHst} aktif vaka`}:{cls:'chip-g',txt:'✅ Sağlıklı'},
    a.kisir?{style:'background:rgba(255,160,0,.15);color:var(--amber)',txt:'💲 Kısır'}:null,
    (()=>{const gToh=tohs.filter(t=>t.sonuc==='Gebe').sort((a,b)=>(b.tarih||'').localeCompare(a.tarih||''))[0]; if(!gToh)return null; const gun=Math.floor((Date.now()-new Date(gToh.tarih))/86400000); return {cls:'chip-g',txt:`🤰 ${gun}. gün · Tahmini: ${dFwd(gToh.tarih,280)}`};})(),
  ].filter(Boolean).map(c=>`<div class="chip ${c.cls||''}"${c.style?` style="${c.style}"`:''}>${esc(c.txt)}</div>`).join('');
}
/**
 * Bir hayvanın detay sayfası HTML yapısını oluşturur; temel bilgileri, anne/kardeş/yavru ilişkilerini, istatistikleri ve işlem butonlarını içerir.
 * @param {Object} a Hayvanın temel bilgilerini içeren nesne.
 * @param {Array} births Hayvanın doğum geçmişi listesi.
 * @param {Array} diseases Hayvanın hastalık/vaka geçmişi listesi.
 * @param {Array} tasks Hayvanın bekleyen görevleri listesi.
 * @param {Array} subs Hayvanın alt görevleri listesi.
 * @param {Array} yavrular Hayvanın yavruları listesi.
 * @param {number|null} yasRaw Hayvanın ham yaş değeri (gün cinsinden).
 * @param {number} yasGun Hayvanın yaşını göstermek için formatlanmış metin.
 * @param {string} displayId Hayvanın küpe numarası veya benzeri gösterim kimliği.
 * @returns {string} Hayvan detay sayfası için HTML kodu.
 */
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
    <button class="btn" style="margin-top:6px;padding:9px;background:rgba(192,50,26,.08);color:var(--red);border:1px solid rgba(192,50,26,.2)" onclick="openCikisModal('${a.id}','${displayId}')">🚪 Çıkış Yap</button>
    ${typeof degisikliklerHayvanIcin === 'function' ? `<button class="btn btn-o" style="margin-top:6px;padding:9px" data-action="dg-hayvan-degisiklikleri" data-hid="${escAttr(a.id)}" data-kupe="${escAttr(displayId)}">🧾 Bu hayvanın değişiklikleri</button>` : ''}`;
}
/**
 * Verilen tohumlama kayıtlarına (tohs) ve kızgınlık geçmişine (kizgs) göre durumuna göre butonlar ve bilgi kartları içeren HTML yapısı döndürür.
 * @param {Object} a Kayıt detaylarını içeren nesne (id, kupe_no, devlet_kupe vb. alanları içerir).
 * @param {Array} tohs Tohumlama kayıtları dizisi (sonuc: 'Gebe', 'Bekliyor', 'Doğum Yaptı', 'Abort' vb. durumları içerir).
 * @param {Array} kizgs Kızgınlık geçmişi dizisi (belirti, tarih vb. alanları içerir).
 * @returns {String} Butonlar, durum kartları ve geçmiş kayıtlarını içeren HTML string.
 */
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
// TG1-W3 (luna F9): hayvan kartı geçmişine tarih şeridi/gün filtresi — goal
// "Değişecek dosyalar" maddesinin kapanışı. Ana yüzey şeridiyle AYNI mekanizma
// (kanonik tekTarihTakvimAc + banner deseni + skipPull'suz yeniden render);
// todayKey sözleşmesi burada da geçerli — seçili gün todayKey'e geçirilmez,
// BUGÜN/DÜN etiketleri gerçek bugünden gelir.
let _detGecmisGun=null;   // kart kapsamında seçili gün (ISO) ya da null
let _detGecmisGunSayi=0;  // seçili günün (arama ÖNCESİ) olay sayısı
let _detGecmisCtx=null;   // son render bağlamı {id, el} — şerit action'ları için
let _detGecmisGunKumesi=null; // W3: kart takvimi işaretli günleri (Set<ISO>, animalId scope'lu)
/**
 * Olay geçmişi görünümü için tek tarihli takvim açarak kullanıcıyı istediği tarihe gitmesini sağlar.
 * @returns {void}
 */
function gecmisDetTariheGitAc(){
  if(!_detGecmisCtx) return;
  tekTarihTakvimAc({
    baslik:'📅 Tarihe Git',
    deger:_detGecmisGun||bugun(),
    max:bugun(), // olay görünümü geçmişe bakar; gelecek gün boş kalırdı
    // W3: olaylı günler — kart kapsamıyla (scope:{animalId}) hesaplı küme
    isaretliGunler:_detGecmisGunKumesi||undefined,
    /**
     * ISO tarih verildiğinde geçmiş detay gün seçim fonksiyonunu çağırır; aksi halde hiçbir şey yapmaz.
     * @param {string} iso - Seçilecek günün ISO formatındaki tarihi.
     * @returns {void}
     */
    onSec:iso=>{ if(iso) gecmisDetGunSec(iso); },
  });
}
/**
 * Geçmiş detay görünümündeki gün seçimi için tarih parametresini günceller ve tarayıcı geçmişi (history) yönetir.
 * Eğer gün parametresi değişmişse, tarayıcı geçmişine yeni bir durum ekler ve mevcut render bağlamı varsa
 * ilgili görünümü yeniden çizer.
 * @param {string|null} iso Güncellenecek tarih (ISO formatında) veya null.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function gecmisDetGunSec(iso){
  const _eski=_detGecmisGun;
  _detGecmisGun=iso||null;
  // W3: kart-içi gün görünümü history'ye girer — geri tuşu görünümden karta
  // döner (popstate 'det-gun' dalı → gecmisDetGunKapat), kart kapanmaz.
  if(_detGecmisGun && _detGecmisGun!==_eski) history.pushState({pg:getState('currentPage')||'dash',dgun:_detGecmisGun},'','');
  if(_detGecmisCtx) _detRenderGecmis(_detGecmisCtx.id,_detGecmisCtx.el,{gunKoru:true});
}
// W3: ✕ Kapat + geri tuşu ortak kapanışı — det-back deseni korunur (kart açık kalır).
/**
 * Geçmiş gün detay verisini sıfırlar, mevcut bağlam varsa koruyarak yeniden render eder ve geri dönüş yapar.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function gecmisDetGunKapat(){
  _detGecmisGun=null;
  if(_detGecmisCtx) _detRenderGecmis(_detGecmisCtx.id,_detGecmisCtx.el,{gunKoru:true});
  if(typeof navViewBack==='function') navViewBack();
}
/**
 * 'det-gecmis-gun-banner' elementini bulup, _detGecmisGun objesi varsa günün adını ve olay sayısını içeren bir bilgi kartı oluşturur, yoksa elementi gizler.
 * @returns {void}
 */
function _detGecmisGunBannerGuncelle(){
  const b=document.getElementById('det-gecmis-gun-banner');
  if(!b) return;
  if(!_detGecmisGun){ b.style.display='none'; b.innerHTML=''; return; }
  const gunAd=_gmGroupLabel(_detGecmisGun)||_detGecmisGun; // gerçek bugüne göre
  b.style.display='block';
  b.innerHTML=`<div style="display:flex;align-items:center;gap:8px;margin-bottom:9px;padding:8px 12px;background:rgba(42,107,181,.08);border:1.5px solid rgba(42,107,181,.35);border-radius:12px">
    <span style="font-size:1rem">📅</span>
    <div style="flex:1;min-width:0">
      <div style="font-weight:800;font-size:.8rem;color:var(--ink)">${esc(gunAd)} · ${esc(fmtTarih(_detGecmisGun))}</div>
      <div style="font-size:.66rem;color:var(--ink3)">${_detGecmisGunSayi} olay</div>
    </div>
    <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-det-gun-kapat" title="Gün görünümünden çık — karta dön">✕ Kapat</button>
  </div>`;
}
/**
 * Belirtilen hayvan ID'si için geçmiş kayıtları (görev, uygulama, işlem vb.) getirir,
 * gün filtresi uygular (varsa), arama mantığını hazırlar ve arayüzü (loader, boş durum veya liste) render eder.
 * @param {string} id Hayvanın benzersiz kimlik numarası.
 * @param {HTMLElement} el Kayıtların listeleneceği HTML elemanı.
 * @param {Object} opts Seçenekler objesi; 'gunKoru' özelliği varsa gün filtresi devreye girer.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function _detRenderGecmis(id,el,opts){
  if(!(opts&&opts.gunKoru)) _detGecmisGun=null; // yeni kart açılışı gün süzmesini sıfırlar
  _detGecmisCtx={id,el};
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    // D9 hayvan kartı paritesi: ana sekmeyle AYNI ortak veri hattı; kapsam
    // pipeline'a bildirilir (kaynak bazında mevcut eşleşme kuralları uygulanır).
    // TG1-W3: seçili gün varsa gün hattı (olayGunu + gün politikaları + DEDUP,
    // hayvan kapsamıyla) — defter hattı aynen korunur.
    const sources=await _gecmisCollectSources();
    // W3: kart takviminin işaretli günleri — hayvan kapsamlı küme (ek pull yok)
    if(typeof _gmGunKumesiFromSources==='function') _detGecmisGunKumesi=_gmGunKumesiFromSources(sources,{animalId:id});
    const entries=_detGecmisGun
      ? _gmGunEntriesFromSources(sources,{animalId:id}).filter(e=>e.olayGunu===_detGecmisGun)
      : _gmEntriesFromSources(sources,{animalId:id});
    _detGecmisGunSayi=_detGecmisGun?entries.length:0;
    if(!entries.length){
      el.innerHTML=`<div style="display:flex;gap:6px;margin-bottom:9px;align-items:center;overflow-x:auto;padding-bottom:2px">
        <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-det-gun-bugun" title="Bugünün olayları">Bugün</button>
        <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-det-gun-dun" title="Dünün olayları">Dün</button>
        <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-det-tarihe-git" title="Takvimden gün seç — o gün ne oldu?">📅 Tarihe git</button>
      </div>
      <div id="det-gecmis-gun-banner" style="display:none"></div>
      <div class="empty"><div class="empty-ico">📋</div>${_detGecmisGun?esc(fmtTarih(_detGecmisGun))+' gününe ait kayıt yok':'Kayıt yok'}</div>`;
      _detGecmisGunBannerGuncelle();
      return;
    }

    // islem detay paneli (Geri Al modal desteği korunur); U1: kart → panel
    // erişimi id haritasıyla (idx yarışı yok — her yüzey kendi id'lerini
    // haritaya EKLER; uuid'ler çakışmaz, bayat-harita ölü kart üretmez)
    const islemLogs=entries.filter(e=>e.type==='islem').map(e=>e.data);
    globalThis._detGecmisLogs=islemLogs;
    const _logMap=globalThis._gmIslemLogById||(globalThis._gmIslemLogById={});
    islemLogs.forEach(l=>{ if(l&&l.id) _logMap[l.id]=l; });
    entries.forEach(e=>{ e.searchText=_gecmisSearchText(e); });
    globalThis._detGecmisEntries=entries;

    /**
     * Detay geçmiş listesinde arama sorgusuna uyan kayıtları filtreleyip HTML olarak render eder.
     * @param {string} q - Geçmiş kayıtlarında aranacak sorgu metni.
     * @returns {void} Hiçbir değer döndürmez; sonuçlar doğrudan 'det-gecmis-body' elementine yazılır.
     */
    function _renderDetGecmisList(q){
      const list=_gmSearch(entries,q);
      const bodyEl=document.getElementById('det-gecmis-body');
      if(!bodyEl) return;
      if(!list.length){bodyEl.innerHTML='<div class="empty"><div class="empty-ico">📭</div>Kayıt bulunamadı</div>';return;}
      bodyEl.innerHTML=list.map(e=>{
        // U1: islem kartı artık _gecmisEntryHtml içinde gm-islem dataset'iyle
        // tıklanır (ana listeyle AYNI yol — islem detay paneli kart altına açılır)
        if(e.type==='gorev' && e.data?.gorev_tipi!=='TEDAVI_GUN') return _gecmisEntryHtml(e,'');
        if(e.type==='uygulama') return _gecmisEntryHtml(e,'');
        return _gecmisEntryHtml(e);
      }).join('');
    }
    globalThis._renderDetGecmisList=_renderDetGecmisList;

    el.innerHTML=`<div style="display:flex;gap:6px;margin-bottom:9px;align-items:center;overflow-x:auto;padding-bottom:2px">
      <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-det-gun-bugun" title="Bugünün olayları">Bugün</button>
      <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-det-gun-dun" title="Dünün olayları">Dün</button>
      <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-det-tarihe-git" title="Takvimden gün seç — o gün ne oldu?">📅 Tarihe git</button>
    </div>
    <div id="det-gecmis-gun-banner" style="display:none"></div>
    <div style="padding:0 0 8px">
      <input id="det-gecmis-search" type="search" placeholder="Ara… (sperma, ilaç, tanı)" autocomplete="off"
        style="width:100%;box-sizing:border-box;padding:9px 12px;border:1.5px solid var(--card3);border-radius:10px;background:var(--card);color:var(--ink);font-size:.82rem"
        oninput="globalThis._renderDetGecmisList(this.value)">
    </div>
    <div id="det-gecmis-body"></div>`;
    _detGecmisGunBannerGuncelle();
    _renderDetGecmisList('');
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
}

// ──────────────────────────────────────────
// HAYVAN DETAY — ana fonksiyon
// ──────────────────────────────────────────
/**
 * Belirli bir hayvanın sağlık durumunu (aktif vakalar, aşı geçmişi, hızlı uygulamalar vb.) HTML olarak render eder.
 * @param {HTMLElement} el Render edilecek HTML element.
 * @param {Array} activeCases Hayvanın aktif vakaları listesi.
 * @param {Array} allDiseasesList Tüm hastalıkların listesi (vaka detayları için).
 * @param {Object} a Render edilecek hayvanın veri nesnesi.
 * @param {Array} vaxLogs Hayvanın aşı uygulama geçmişi.
 * @param {Array} uygulamaLogs Hayvanın hızlı ilaç/vitamin uygulama geçmişi.
 * @returns {void} Elementin innerHTML'i güncellenir, değer döndürmez.
 */
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
/**
 * Verilen görev ve alt görev listesini, ebeveyn görevi olmayanları (yaban) dahil ederek hedef tarihe göre sıralar,
 * gün bazlı durumu (hemen, geç) belirler ve HTML formatında bir görev listesi ile "Görev Ekle" butonu döndürür.
 * @param {Object} a Görevin ait olduğu hayvan veya kullanıcı nesnesi (kupe_no, devlet_kupe veya id içerebilir).
 * @param {Array} tasks Tamamlanmış veya tamamlanmamış görevlerin dizi listesi.
 * @param {Array} subs Alt görevlerin (sub-tasks) dizi listesi.
 * @param {Date|String} today Bugünün tarihi referansı.
 * @returns {String} Görev listesini ve ekleme butonunu içeren HTML string'i.
 */
function _detGorevHtml(a,tasks,subs,today){
  const kupe=a.kupe_no||a.devlet_kupe||a.id;
  // Parent'ı tamamlanmış olan rapel görevleri de üst seviyede göster
  const taskIds=new Set(tasks.map(t=>t.id));
  const orphanSubs=subs.filter(s=>!taskIds.has(s.parent_id));
  /**
   * Verilen nesnin 'gorev_tipi' alanı 'TEDAVI_GUN' ise, 'aciklama' alanındaki JSON'dan 'planned_time' değerini parse edip döndürür; aksi takdirde boş string döndürür.
   * @param {Object} t Görev tipini ve açıklama bilgisini içeren nesne.
   * @returns {string} Planlanan süre değeri veya boş string.
   */
  const getTime=t=>t.gorev_tipi==='TEDAVI_GUN'?(()=>{try{return JSON.parse(t.aciklama||'{}').planned_time||'';}catch(e){return '';}})():'';
  const allTop=[...tasks,...orphanSubs].sort((a,b)=>{const d=(a.hedef_tarih||'').localeCompare(b.hedef_tarih||'');return d||getTime(a).localeCompare(getTime(b));});
  const liste=allTop.length
    ?allTop.map(t=>{ const ts=subs.filter(s=>s.parent_id===t.id); const _stateMid=t.hedef_tarih===today?'soon':''; const state=t.hedef_tarih<today?'late':_stateMid; return renderTask(t,state,ts); }).join('')
    :'<div class="empty"><div class="empty-ico">✅</div>Bekleyen görev yok</div>';
  return `<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" data-kupe="${escAttr(kupe)}" onclick="openMWithHayvan('m-task-add','ta-hid',this.dataset.kupe)">➕ Görev Ekle</button></div>`+liste;
}
/**
 * Belirli bir hayvan detay sayfasını açar, tarayıcı geçmişi ve sekme durumuna göre navigasyon butonlarını ayarlar,
 * ilgili veritabanından (hayvanlar, hastalıklar, görevler vb.) verileri çeker, yaş hesaplar ve detayları DOM'a render eder.
 * @param {string} id Açılacak hayvanın benzersiz kimlik numarası (id, küpe_no veya devlet_kupe).
 * @param {boolean} keepTab Mevcut sekmede kalınacak mı? (true ise geçmişi güncellemez, false ise yeni bir sayfa geçmişi oluşturur).
 * @returns {Promise<void>} Verilerin çekilmesi ve arayüzün güncellenmesi işlemi tamamlandığında çözülür.
 */
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
  ['det-chips','tab-saglik','tab-ureme','tab-pedigree','tab-gorev','tab-gecmis'].forEach(i=>{const el=document.getElementById(i);if(el)el.innerHTML='';});
  const _ozetEl=document.getElementById('tab-ozet'); if(_ozetEl) _ozetEl.innerHTML=_skelHtml;
  showTab(activeTab||'ozet',document.querySelector(activeTab?`.tab[data-action="tab-${activeTab}"]`:'.tab'));
  // Pedigree lazy-load (Task 7): openDet RPC çağırmaz; yalnız focus'u bildirir —
  // Soy sekmesi aktifse controller yükler, değilse sekme ilk aktive olduğunda yükler.
  const _pedPane=document.getElementById('tab-pedigree');
  if (typeof pedigreeSetFocus === 'function') pedigreeSetFocus(id, !!(_pedPane && _pedPane.classList && _pedPane.classList.contains('on')));
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
    document.getElementById('det-chips').innerHTML=_detChipsHtml(a,tohs,aktifHst,activeCases);

    document.getElementById('tab-ozet').innerHTML=_detOzetHtml(a,births,diseases,tasks,subs,yavrular,yasRaw,yasGun,displayId);

    const allDiseasesList=await idbGetAll('diseases');
    await _detSaglikRender(document.getElementById('tab-saglik'),activeCases,allDiseasesList,a,vaxLogs,uygulamaLogs);

    document.getElementById('tab-ureme').innerHTML=_detUremeHtml(a,tohs,kizgs);

    document.getElementById('tab-gorev').innerHTML=_detGorevHtml(a,tasks,subs,today);

    const gecmisEl=document.getElementById('tab-gecmis');
    if(gecmisEl) await _detRenderGecmis(id,gecmisEl);

  } catch(e){ document.getElementById('det-name').textContent='Hata: '+e.message; }
}
/**
 * 'det' elementinden 'on' sınıfını kaldırarak detay görünümünü kapatır.
 * Eğer sessiz sheet'ten gelindiği tespit edilirse, sheet'i tekrar görünür kılar ve scroll durumunu korur.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * Verilen görev kimliğini önceki görev olarak saklar, görev ve tamamlanma detay pencerelerini kapatıp hayvan detay penceresini açar.
 * @param {string|number} hayvanId - Detayı açılacak hayvanın kimliği.
 * @param {string|number} taskId - Önceki görev olarak saklanacak görevin kimliği.
 * @returns {void}
 */
function fromTaskOpenDet(hayvanId, taskId) {
  window._prevTaskId = taskId;
  closeM('m-task-det');
  closeM('m-done-det');
  openDet(hayvanId);
}

// ── PADOK DEĞİŞTİR (hayvan kartı özet tab) ──
// ── İŞLEM GERİ AL: L4-W2 ile legacy yolu SÖKÜLDÜ — tek giriş
// dgGeriAlAkisi (js/degisiklikler/degisiklikler.js) kullanılır. ──

/**
 * Geçmiş loglarındaki belirtilen indeksli işlemin detayını açar.
 * Eğer indeks geçersizse işlem yapılmaz.
 * @param {number} idx Geçmiş loglarındaki satırın indeks numarası.
 * @returns {void} İşlem başarılıysa hiçbir değer döndürmez.
 */
function openIslemDetay(idx){
  const l=(globalThis._detGecmisLogs||[])[idx];
  if(!l) return;
  // U1: eski idx arayüzü korundu (harici çağrı ihtimali); panel hedefi eski
  // #tab-gecmis .hist-row[idx] aramasıdır. Geçmiş kartları artık dataset+
  // delegasyonla _openIslemDetayRow(l, kartEl) kullanır — panel kartın altına açılır.
  const rows=document.getElementById('tab-gecmis')?.querySelectorAll('.hist-row');
  _openIslemDetayRow(l, rows?.[idx]);
}
// L4-07 (onarım turu): işlem detay payload satırları — SAF (string üretir,
// DOM yazmaz; testli). Değerler esc()'li (stored-XSS kapanır); hayvan referans
// alanları küpeye dönüşür (_gmHayvanKupeById deseni; çözülmezse '?' — ham UUID
// ASLA görünmez). payload.id (etkilenen kaydın kendi pk'sı) teknik değerdir —
// listede YOK.
const _DET_UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const _DET_REF_ALANLARI=['hayvan_id','ana_hayvan_id','buzagi_id','farm_animal_id','anne_id','animal_id'];
const _DET_ALAN_ETIKET={'tarih':'Tarih','sperma':'Sperma','sonuc':'Sonuç','deneme_no':'Deneme','tani':'Tanı','siddet':'Şiddet','durum':'Durum','hekim_id':'Hekim','yavru_kupe':'Yavru Küpe','yavru_cins':'Yavru Cinsiyet','dogum_tipi':'Doğum Tipi','notlar':'Not','irk':'Irk','grup':'Grup','kupe_no':'Küpe','devlet_kupe':'Devlet Küpe','orijinal_tip':'Geri alınan olay','seviye':'Kapsam','adim':'Adım'};
// L4-06: telafi kaydı payload'ı (orijinal_tip/seviye/adim) artık listede GÖRÜNÜR
// (review Minor-1) — anahtarlar ve değerleri işlem dilli etiketle basılır.
const _DET_SEVIYE_ETIKET={alan:'Alan',satir:'Kayıt',islem:'İşlem',zincir:'Zincir'};
/**
 * Verilen değeri kontrol edip uygun formatta string olarak döndürür.
 * @param {*} v Dönüştürülecek değer.
 * @returns {string} Değerin string versiyonu veya boş string.
 */
function _detayDegerMetni(v){
  if(v===null||v===undefined) return '';
  if(typeof v==='object') return JSON.stringify(v);
  return String(v);
}
/**
 * Verilen payload nesnesindeki alanları filtreleyip (id, null, undefined ve boş değerleri hariç),
 * özel etiket fonksiyonları veya sabit diziler kullanılarak değerleri işleyerek HTML satırları döndürür.
 * @param {Object} payload İşlenecek nesne.
 * @returns {string} Filtrelenmiş ve işlenmiş alanlardan oluşan HTML stringi.
 */
function _islemDetaySatirlariHtml(payload){
  const p=payload&&typeof payload==='object'?payload:{};
  return Object.entries(p)
    .filter(([k,v])=>k!=='id'&&v!==null&&v!==undefined&&v!=='')
    .map(([k,v])=>{
      let goster;
      if(k==='orijinal_tip') goster=(typeof _gmIslemTipEtiket==='function')?_gmIslemTipEtiket(_detayDegerMetni(v)):_detayDegerMetni(v);
      else if(k==='seviye') goster=_DET_SEVIYE_ETIKET[v]||_detayDegerMetni(v);
      else if(_DET_REF_ALANLARI.includes(k)){
        const kupe=(globalThis._gmHayvanKupeById||{})[String(v)];
        goster=kupe||(_DET_UUID_RE.test(_detayDegerMetni(v))?'?':_detayDegerMetni(v));
      } else goster=_detayDegerMetni(v);
      return `<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card3);font-size:.78rem"><span style="color:var(--ink3)">${_DET_ALAN_ETIKET[k]||esc(k)}</span><span style="font-weight:600;color:var(--ink);text-align:right;max-width:60%">${esc(goster)}</span></div>`;
    })
    .join('');
}
// U1 md.2: islem detay paneli — geçmiş kartından tıklanan kartın ALTINA açılır
// (anchor=el); anchor verilmezse eski .hist-row davranışı aynen. L4-W2: geri-al
// butonu tek motora (dgGeriAlAkisi) bağlandı — eski tek-arg islemGeriAl kırığı
// ve openGeriAl a+b modalı söküldü; etiket/ikon ortak haritadan (js/gecmis.js).
/**
 * Verilen işlem kaydı (l) için detay panelini oluşturur veya mevcut paneli günceller.
 * Kayıt türüne (tohumlama, abort vb.) ve snapshot ID'ye göre ilgili detay modalını açar.
 * Kayıt geri alınabilir mi kontrol edilir ve gerekirse "Geri Al" butonu eklenir.
 * Panel HTML'i oluşturulur, varsa eski panel kaldırılır ve yeni panel hedef elemana eklenir.
 * @param {Object} l İşlem kaydı nesnesi (ref_tablo, ref_id, tip, snapshot, created_at, payload, id vb. özelliklere sahip).
 * @param {HTMLElement} anchor Panelin ekleneceği veya referans alınacak hedef HTML elemanı.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function _openIslemDetayRow(l, anchor){
  if(!l) return;
  // ref_tablo varsa doğrudan ilgili detay modalını aç
  // ABORT_KAYDI hariç: abort kaydının Geri Al butonu bu panelde — toh det'e yönlendirme
  if(l.ref_tablo==='tohumlama' && l.ref_id && l.tip!=='ABORT_KAYDI'){ openTohDet(l.ref_id); return; }
  // TOHUMLAMA tipinde snapshot id varsa direkt aç
  const snapId=l.snapshot?.id;
  if(l.tip==='TOHUMLAMA' && snapId){ openTohDet(snapId); return; }
  const tarih=(l.created_at||l.tarih||'').slice(0,10);
  // L4-W2: buton kararı çözücüde — hedef üreten her kayıt geri alınabilir.
  // W5 onarım: eski `['*'].includes(l.tip)` kalıntısı her zaman false üretiyor,
  // panel butonu ÖLÜydü (sahibin "geri al butonu her yerde yok" sözü bu
  // yüzde yaşıyordu) — çözücü kararı doğrudan kullanılır.
  const geriAlabilir=!!_gmGeriAlHedef(l);
  const satirlar=_islemDetaySatirlariHtml(l.payload);
  const gaBtn=geriAlabilir&&l.id
    ? `<button class="btn" style="background:var(--red);color:#fff;width:100%;margin-top:10px" data-action="dg-det-geri-al" data-det="${escAttr(String(l.id))}">↩ Geri Al</button>`
    : '';
  const html=`<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:var(--r2);padding:14px;margin-top:8px">
    <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px">
      <span style="font-size:1.1rem">${_gmIslemTipEmoji(l.tip)}</span>
      <span style="font-weight:700;font-size:.88rem">${esc(_gmIslemTipEtiket(l.tip))}</span>
      <span style="margin-left:auto;font-size:.72rem;color:var(--ink3)">${tarih}</span>
    </div>
    ${satirlar||'<div style="font-size:.78rem;color:var(--ink3);text-align:center;padding:8px 0">Detay yok</div>'}
    ${gaBtn}
    <button class="btn btn-o" style="width:100%;margin-top:6px;font-size:.8rem" onclick="this.closest('.islem-detay-panel').remove()">Kapat</button>
  </div>`;
  // Aynı panel açıksa kapat, yoksa ekle — U1: önce tıklanan kart (anchor),
  // yoksa eski .hist-row hedefi
  const existing=document.querySelector('.islem-detay-panel');
  if(existing) existing.remove();
  let hedef=anchor;
  if(!hedef){
    const gecmisEl=document.getElementById('tab-gecmis');
    const rows=gecmisEl?.querySelectorAll('.hist-row');
    hedef=rows?.[(globalThis._detGecmisLogs||[]).indexOf(l)];
  }
  if(hedef){
    const panel=document.createElement('div');
    panel.className='islem-detay-panel';
    panel.innerHTML=html;
    hedef.insertAdjacentElement('afterend',panel);
  }
}

// Not modal
// ──────────────────────────────────────────
// HAYVAN BİLGİ DÜZENLEME
// ──────────────────────────────────────────
/**
 * Belirli bir ID'ye sahip hayvanın düzenleme arayüzünü açar, formu temizler, mevcut verileri doldurur ve ilgili kontrolleri (ırk, kısır durumu, genç anne vb.) yapılandırır.
 * @param {string} id Düzenlenecek hayvanın benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
  document.getElementById('a-dt').max=bugun(); // 20260913-16: UTC yerine yerel bugün (luna BULGU-5 — gece-yarısı kayması)
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

/**
 * Hayvan ekleme/düzenleme modalını sıfırlar ve kapatır; düzenleme kimliğini, uyarı metinlerini, kısırlık ve genç anne alanlarını gizler, başlık ve buton metinlerini varsayılana döndürür.
 * @returns {void}
 */
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
/**
 * Çıkış (satış) modalını açar; gizli hayvan kimliğini ve küpe numarasını ayarlar, basit bir doğrulama sorusu (toplama) oluşturur ve varsa hayvanın ırk, kategori ve yaş bilgilerini modalda gösterir.
 * @param {string|number} hayvanId - Çıkışı yapılacak hayvanın kimliği.
 * @param {string} kupe - Hayvanın küpe numarası; modal başlığında ve bilgi alanında gösterilir.
 * @returns {void} Değer döndürmez.
 */
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
/**
 * Son doğum kayıtlarını tarihe göre azalan sıralayıp, en fazla 8 kaydı 'births-body' elementine liste olarak render eder. Kayıt yoksa boş durum mesajı, hata olursa hata mesajı gösterir.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir Promise.
 */
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
/**
 * Sonucu 'Gebe' olan tohumlama kayıtlarını getirir, 280 günlük gebelik süresine göre tahmini doğum tarihini ve kalan günü hesaplar; hayvan eşleşmesi bulunanları kalan güne göre artan sıralayıp, arama kutusu ve her satır tıklandığında anneSeç fonksiyonunu çağıran bir alt sayfa (bottom sheet) modal olarak gösterir.
 * @returns {Promise<void>} Modal oluşturup sayfaya ekledikten sonra hiçbir değer döndürmez.
 */
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
/**
 * Gebek (tohumlama) listesini arama kutusundaki sorguya göre küpe numarasına süzer ve sonuçları modal liste elemanına HTML olarak render eder.
 * @returns {void} Hiçbir değer döndürmez; sonuçları DOM'a yazar.
 */
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
/**
 * Seçilen anne hayvanının bilgilerini arayüzde gösterir, otomatik baba seçimi durumunu ayarlar ve ilgili form elemanlarını günceller.
 * @param {string} hayvanId Anne hayvanının benzersiz kimlik numarası.
 * @param {string} kupe Anne hayvanın kuyruğu (isim) bilgisi.
 * @param {string} dogumTahmini Tahmini doğum tarihi.
 * @param {string} sperma Otomatik baba seçimi için kullanılacak sperma kaynağı kimliği.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
/**
 * Anne seçim alanını ve seçili kartı gizleyerek anne seçim sayısını sıfırlar.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function anneSecimSifirla(){
  const el=document.getElementById('b-anne'); if(el) el.value='';
  document.getElementById('anne-secili-card').style.display='none';
  document.getElementById('btn-gebe-sec').style.display='';
}
/**
 * Verilen kupe numarasına sahip hayvanı bulup detaylarını açar veya bulunamazsa hata gösterir.
 * @param {string} kupe Aranan hayvanın bulunduğu kupe numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function openDetByKupe(kupe){
  if(!kupe) return;
  const a=hayvanByKupeRef(kupe);
  if(a) openDet(a.id);
  else toast('Hayvan bulunamadı: '+kupe);
}
// K7 (spec 2026-09-01): küpe/id referansından hayvan bulma — AKTİF öncelikli.
// Aynı küpe string'i geçmişte çıkmışta + bugün aktifte varsa aktif bulunur.
/**
 * Verilen referans ID'ye (kupe_no, devlet_kupe veya id) sahip ve durumu 'Aktif' olan hayvanı döndürür; yoksa herhangi bir referansa sahip hayvanı döndürür.
 * @param {string|number} ref Aranan hayvanın kupe_no, devlet_kupe veya id alanlarından biri.
 * @returns {object|undefined} Durumu 'Aktif' olan hayvan objesi veya bulunamazsa herhangi bir hayvan objesi, yoksa undefined.
 */
function hayvanByKupeRef(ref){
  if(!ref) return undefined;
  const L=getState('animals')||[];
  /**
   * Verilen nesne (a) geçersizse false döner, geçerliyse referans edilen kimlik (ref) ile eşleşen bir alan (kupe_no, devlet_kupe veya id) içerip içermediğini kontrol eder.
   * @param {Object} a Kontrol edilecek nesne.
   * @returns {Boolean} Nesnenin referansla eşleşip eşleşmediğini belirten boolean değer.
   */
  const hit=a=>a&&(a.kupe_no===ref||a.devlet_kupe===ref||a.id===ref);
  return L.find(a=>hit(a)&&a.durum==='Aktif')||L.find(hit);
}
// K6: "Boş küpeler" öneri butonu — b-kupe (doğum) / a-kupe (manuel) yanındaki 💡.
// Cinsiyete göre havuz: erkek=500-599, dişi=1-999 (5xx hariç), küçükten büyüğe.
/**
 * Belirtilen alan için öneri listesini getirir, eğer liste zaten görünüyorsa gizler (toggle) ve cinsiyet seçimi varsa o cinsiyete göre önerileri butonlar halinde listeler.
 * @param {string} alan - Listeyi göstermek için kullanılan alan kimliği (örn: 'a-kupe').
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
/**
 * Belirtilen alan ID'sine sahip elemanın değerini günceller ve öneri listesini gizler;
 * ardından blur ön kontrolü tetikler.
 * @param {string} alan - Değerin atandığı HTML elemanının ID'si.
 * @param {any} kupe - Atanacak olan değer.
 * @returns {void}
 */
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
/**
 * Belirtilen hayvanın yavrusunu açmak için gerekli form alanlarını doldurur ve doğum ekranını açar.
 * @param {string} hayvanId Seçilecek anne hayvanın ID'si.
 * @param {string} kupe Hayvanın bulunduğu küpe numarası.
 * @param {string} dogumTarihi Yavrunun doğum tarihi.
 * @param {string} sperma Kullanılacak sperma ID'si (opsiyonel, boş ise varsayılan değer kullanılır).
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function ikinciYavruAc(hayvanId,kupe,dogumTarihi,sperma){
  anneSeç(hayvanId,kupe,dogumTarihi,sperma||'');
  const t=document.getElementById('b-tarih'); if(t) t.value=dogumTarihi;
  const k=document.getElementById('b-kupe'); if(k) k.value='';
  openM('m-birth');
}

// ──────────────────────────────────────────
// ÜREME SEKMESİ
// ──────────────────────────────────────────
/**
 * Seçilen üreme sekmesini ayarlar, sekme düğmelerinin 'on' sınıfını güncelleyip ilgili sekmeyi yükler.
 * @param {*} tab - Yüklenecek üreme sekmesi tanımlayıcısı.
 * @param {HTMLElement} btn - 'on' sınıfı eklenecek sekme düğmesi; verilmezse hiçbir düğmeye sınıf eklenmez.
 * @returns {void} Dönüş değeri yok.
 */
function uremeTab(tab,btn){
  _curUremeTab=tab;
  document.querySelectorAll('#pg-ureme .fs-btn').forEach(b=>b.classList.remove('on'));
  if(btn) btn.classList.add('on');
  loadUreme(tab);
}
// ── ÜREME TAB HELPER'LAR ────────────────────
/**
 * Kızgınlık sekmesi içeriğini oluşturur: toolbar'ı gösterir, IndexedDB'deki kızgınlık kayıtlarını arama filtresiyle süzer, 48 saatlik aksiyon penceresine göre Bekleyen/Gözlem/Geçti/Sonuçlanan olarak gruplar, durum filtresini uygular ve her kayıt için Tohumla/Tedavi/Sil butonları içeren HTML kartları üretip hedef elemana yazar.
 * @param {HTMLElement} el - İçeriğin yazılacağı hedef DOM elemanı.
 * @returns {Promise<void>} Hiçbir değer döndürmez; sonuç doğrudan el.innerHTML'e yazılır.
 */
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
  /**
   * Verilen nesne için 'olusturma' veya 'tarih' alanı varsa, bu tarih ile şu anki zaman arasındaki farkı saat cinsinden hesaplar, yoksa null döndürür.
   * @param {Object} k Nesne, 'olusturma' veya 'tarih' alanlarından en az birini içermelidir.
   * @returns {number|null} Hesaplanan saat sayısı veya null.
   */
  const _ageH=k=>(k.olusturma||k.tarih)?(Date.now()-new Date(k.olusturma||k.tarih))/3600000:null;
  /**
   * Verilen kaydın sonucunun 'POSTPARTUM_GOZLEM' olup olmadığını kontrol eder.
   * @param {Object} k - Kontrol edilecek kayıt.
   * @param {string} k.sonuc - Kaydın sonuç değeri.
   * @returns {boolean} Sonuç 'POSTPARTUM_GOZLEM' ise true, değilse false.
   */
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
  /**
   * Kızgınlık kaydı için hayvan küpe numarası, durum rozetleri, tarih/not bilgisi ve mod'a göre işlem butonları içeren HTML satırı (kart) oluşturur.
   * @param {Object} k - Kızgınlık kaydı; hayvan_id, belirti, tarih, notlar, tedavi_case_id ve id alanlarını içerir.
   * @param {string} mode - Görüntüleme modu ('sonuclanan', 'gozlem', 'gecti', 'bekleyen'); rozet, renk ve buton görünümünü belirler.
   * @returns {string} Kızgınlık kaydını temsil eden HTML dizesi.
   */
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
  /**
   * Verilen dizinin elemanlarını belirli bir modda işleyerek kartlar oluşturur ve başlık bilgisiyle birlikte HTML yapısı döndürür.
   * @param {Array} arr İşlenecek elemanların bulunduğu dizi.
   * @param {string} mode Elemanların işlenmesinde kullanılacak mod.
   * @param {string} title Gösterilecek başlık metni.
   * @param {string} color Başlığın yazı rengi.
   * @param {boolean} topBorder Başlığın üstünde kenarlık olup olmadığını belirten bayrak.
   * @returns {string} Başlık ve kartlardan oluşan HTML string'i.
   */
  const sec=(arr,mode,title,color,topBorder)=>arr.length
    ? `<div style="${topBorder?'margin-top:12px;border-top:1px solid var(--card3);padding-top:8px;':'margin-bottom:8px;'}font-size:.72rem;font-weight:700;color:${color};text-transform:uppercase;letter-spacing:.06em;padding:4px 0">${title} (${arr.length})</div>`
      +arr.map(k=>card(k,mode)).join('')
    : '';
  const bekleyenHtml=sec(bekleyen,'bekleyen','🔴 Bekleyen Kızgınlıklar','var(--red2)',false);
  const gozlemHtml=sec(gozlem,'gozlem','👁 Gözlem (Postpartum)','var(--ink3)',bekleyen.length>0);
  const gectiHtml=sec(gecti,'gecti','⌛ Geçti / Kaçırıldı','#b0862e',bekleyen.length+gozlem.length>0);
  const sonucHtml=sec(sonuclanan,'sonuclanan','✅ Sonuçlanan','var(--green)',bekleyen.length+gozlem.length+gecti.length>0);
  el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" data-action="open-kizginlik-modal">🔴 Kızgınlık Ekle</button></div>`
    +(list.length?bekleyenHtml+gozlemHtml+gectiHtml+sonucHtml:'<div class="empty"><div class="empty-ico">🔴</div>Kızgınlık kaydı yok</div>');
}

// ── İN-FLOW VAKA AÇMA (Plan-E) ─────────────
/**
 * Tohumlama sonrası tespit edilen sorunu seçmek için ekranın altında açılan bir bottom sheet (modal) oluşturur ve görüntüler.
 * @param {string} tohId - Tohumlama kaydının kimliği.
 * @param {string} kizId - Kızığın (hayvanın) kimliği.
 * @returns {void} Bir değer döndürmez.
 */
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

/**
 * Seçili sorunun ID'si ve tanımı kaydedilir, tüm sorun butonlarının stilleri sıfırlanır, seçilen buton vurgulanır ve 'diger' seçeneği görünürlüğü kontrol edilir.
 * @param {string} id Seçilen sorunun benzersel kimlik numarası.
 * @param {string} tani Seçilen sorunun açıklaması veya tanımı.
 * @param {Event} e Tıklama olayı objesi.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Seçili sorun türüne göre yeni bir vaka oluşturur veya mevcut sorun formunu doldurmak için sayfa geçişini başlatır.
 * Sorun türü seçilmemişse uyarı gösterir ve işlemi iptal eder.
 * @param {string} tohId Tohumlama kaydı kimliği (opsiyonel).
 * @param {string} kizId Kızgınlık kaydı kimliği (opsiyonel).
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc kizginlik_vaka_ac
 */
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

/**
 * Seçili sorunu sıfırlar, sorunun varlığını false olarak işaretler ve kızgınlık ID'sini null yapar.
 * @returns {void}
 */
function _sorunBsTemizle() {
  _sorunSecilen = null;
  globalThis._insemSorunVar = false;
  globalThis._insemKizginlikId = null;
}

let _kizginlikSearchTimer=null;
/**
 * Kızgınlık arama zamanlayıcısını temizler ve 250 milisaniye sonra 'kizginlik' değerini alıp loadUreme fonksiyonunu çağırır.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function kizginlikSearch(){
  clearTimeout(_kizginlikSearchTimer);
  _kizginlikSearchTimer=setTimeout(()=>{
    if(typeof loadUreme==='function') loadUreme('kizginlik');
  },250);
}

// Tohumlama arama — 200ms debounce, multi-field (küpe + sperma + sonuç + hayvan adı)
let _tohumlamaSearchTimer=null;
/**
 * Arama kutusundaki değeri alıp 200 milisaniye gecikmeli olarak işler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function tohumlamaSearch(){
  clearTimeout(_tohumlamaSearchTimer);
  _tohumlamaSearchTimer=setTimeout(()=>{
    const inp=document.getElementById('tohumlama-srch');
    globalThis._tohSearch = trLower(inp?.value || '').trim();
    if(typeof loadUreme==='function') loadUreme('tohumlama');
  },200);
}
/**
 * Kızgınlık filtresini belirlediği değere ayarlar ve ilgili butonların aktif durumunu günceller.
 * @param {string} deger Filtreleme için kullanılacak değer (örn: 'tumu', 'bekleyen', 'sonuclanan').
 * @param {HTMLElement} btn Tıklanan veya aktif edilecek buton elemanı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function kizginlikFiltre(deger,btn){
  const onceki=globalThis._kizginlikFilter||'tumu';
  globalThis._kizginlikFilter=onceki===deger?null:deger;
  ['fc-kizginlik-tumu','fc-kizginlik-bekleyen','fc-kizginlik-sonuclanan'].forEach(id=>{
    const b=document.getElementById(id);
    if(b) b.classList.toggle('on',b===btn);
  });
  if(typeof loadUreme==='function') loadUreme('kizginlik');
}

/**
 * Bekleyen ve mevcut gebe tohumlamaları listeler, her biri için detay bilgisi ve eylem butonları ekler.
 * @param {HTMLElement} el Tohumlama listesi HTML'ini oluşturmak için kullanılan DOM elementi.
 * @returns {void} Fonksiyon doğrudan DOM elementinin innerHTML'ini güncelleyerek yanıt verir.
 */
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

  el.innerHTML=`<div style="padding:10px 0 6px"><button class="btn btn-g" style="padding:9px" data-action="open-insem-modal">💉 Yeni Tohumlama</button></div>`+
    bekleyenHtml+gebeHtml;
}

/**
 * Onay penceresi göstererek tohumlama kaydını gebe olarak işaretler; başarılı olursa ilgili tabloları yeniden çeker ve gebelik görünümünü günceller.
 * @param {string|number} tohId - Gebe olarak işaretlenecek tohumlama kaydının kimliği.
 * @param {string|number} kupe - Onay mesajında gösterilecek hayvanın küpe numarası.
 * @returns {Promise<void>} İşlem tamamlanırken çözülen bir Promise; onay iptal edilirse hiçbir işlem yapmaz.
 * @rpc tohumlama_sonuc_gebe
 */
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

/**
 * Yaklaşan doğumları (gebe hayvanlar, 210+ gün) ve geçmiş doğum kayıtlarını listeler.
 * Yaklaşan doğumlar için kalan gün sayısına göre renk kodlaması yapar, besleme uyarısı ekler.
 * Geçmiş doğumları tarih sırasına göre sıralar, doğum tipini (Sezaryan, Güç vb.) gösterir.
 * Sonuç olarak HTML içeriği oluşturup verilen elemente (el) yerleştirir.
 * @param {HTMLElement} el İçeriği bu elemente yerleştirmek için kullanılan DOM elementi.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Tohumlama kayıtlarını getirir, tarihe göre sıralar ve arama filtresi uygular.
 * Sonuç olarak HTML içeriği oluşturarak verilen DOM elemanına render eder.
 * @param {HTMLElement} el Tohumlama kayıtlarının listeleneceği DOM elemanı.
 * @returns {void}
 */
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

/**
 * Belirtilen tab (varsayılan: 'kizginlik') için ureme-body elemanını günceller, ilgili toolbar'ları gösterir/gizler,
 * arama alanını temizler ve tab'a göre ilgili veri yükleme fonksiyonunu çağırır.
 * @param {string} tab - Yüklenmesi istenen tab adı (kizginlik, tohumlama, gebelik, dogum, abort).
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda çözülen Promise.
 */
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
const _GECMIS_ICO = {dogum:'🐄',tohumlama:'💉',hastalik:'🏥',gorev:'✅',uygulama:'💊',ASI_KAYDI:'💉',ASI_ERTELEME:'⏸️',TOPLU_ILAC:'💊',
  // TG1 tek-gün görünümü kategorileri (defter hattı bu tiplerde entry üretmez)
  asi:'💉',kizginlik:'🔴',stok:'📦',cikis:'🚪',sutten:'🍼',protokol:'🩺'};
const _GECMIS_BG  = {dogum:'rgba(78,154,42,.1)',tohumlama:'rgba(42,107,181,.1)',hastalik:'rgba(192,50,26,.1)',gorev:'var(--card2)',uygulama:'rgba(120,80,200,.1)',islem:'rgba(120,120,120,.1)',ASI_KAYDI:'rgba(0,160,200,.1)',ASI_ERTELEME:'rgba(120,120,120,.1)',TOPLU_ILAC:'rgba(120,80,200,.1)',
  asi:'rgba(0,160,200,.1)',kizginlik:'rgba(192,50,26,.1)',stok:'rgba(120,100,60,.12)',cikis:'rgba(120,120,120,.14)',sutten:'rgba(78,154,42,.1)',protokol:'rgba(42,107,181,.08)'};
// U1 md.1: _ISLEM_ICO/_ISLEM_ETK iki kopyası KALDIRILDI — islem_log tip etiket+
// emoji TEK kaynak js/gecmis.js (_GM_ISLEM_TIP_ETIKET/_GM_ISLEM_TIP_EMOJI ve
// _gmIslemTipEtiket/_gmIslemTipEmoji okunur yedeği).

// U1 md.3: islem kartının küpe etiketi — _gecmisEntryHtml islem dalı ile katlı
// kart satır etiketi AYNI kaynak (çıkarıldı; sıra: state → snapshot → çıkış-cache
// → IDB hayvan indeksi). ROOT KURALI (2026-09-14): ham UUID ASLA görünmez —
// çözülemeyen hayvan '?'e düşer.
function _gecmisKupeLabel(e){
  const d=e.data||{};
  const snap=d.snapshot||{};
  const hayvanObj=getState('animals').find(a=>a.id===d.ana_hayvan_id);
  let _exitedCache={};try{_exitedCache=JSON.parse(localStorage.getItem('ege_exited_kupe')||'{}');}catch(err){}
  return hayvanObj?.kupe_no||hayvanObj?.devlet_kupe||snap.kupe_no||snap.devlet_kupe||_exitedCache[d.ana_hayvan_id]
    ||(globalThis._gmHayvanKupeById||{})[d.ana_hayvan_id]||'?';
}
// U1 (root düzeltme-2): hayvansız islem kartı başlık etiketi — '?' yerine
// snapshot'taki görev adı/açıklaması, o da yoksa 'Genel'.
/**
 * Geçmiş kupenin etiketini kontrol eder; yoksa snapshot'daki açıklama, label veya notlar alanından alır ve JSON formatında ise label değerini tercih eder.
 * @param {Object} e - Geçmiş kupenin veri objesi.
 * @returns {string} Kupenin etiketini veya varsayılan 'Genel' değerini döndürür.
 */
function _gmIslemBaslikEtiketi(e){
  const k=_gecmisKupeLabel(e);
  if(k&&k!=='?') return k;
  const snap=(e.data||{}).snapshot||{};
  let a=snap.aciklama||snap.label||snap.notlar||'';
  if(typeof a==='string'&&a.trim().startsWith('{')){try{a=JSON.parse(a).label||a;}catch(err){/* ham metin */}}
  a=String(a||'').trim();
  return a||'Genel';
}
// W8-D3: hayvan referans etiketi — ham id/UUID ASLA; çözülemeyen referans
// '?' yerine nötr kısa etiket (root R1-D3: "kartta ? kalmayacak"). Saf çekirdek
// gmHayvanEtiketVeya js/gecmis.js'te (TEK kaynak, testli).
/**
 * Verilen hayvan ID'si (hid) veya kupu_no'su ile hayvanı bulur, yoksa global kupu tablosundan veya nor parametresinden değer döndürür.
 * @param {string|number} hid Aranan hayvanın ID'si veya kupu numarası.
 * @param {string} nor Varsayılan değer veya alternatif referans.
 * @returns {string} Bulunan hayvanın kupu numarası, devlet kupu numarası, global kupu tablosundaki değer, nor parametresi veya 'Hayvan' stringi.
 */
function _gmHayvanEtiketVeya(hid, nor){
  if(typeof gmHayvanEtiketVeya==='function') return gmHayvanEtiketVeya(hid,nor,getState('animals'),globalThis._gmHayvanKupeById);
  const a=hid?getState('animals').find(x=>x.id===hid||x.kupe_no===hid):null;
  return (a&&(a.kupe_no||a.devlet_kupe))||(globalThis._gmHayvanKupeById||{})[hid]||nor||'Hayvan';
}
// Katlı grubun satır etiketi — tür bazlı (islem: başlık etiketi; stok: ürün; diğer: hayvan etiketi)
/**
 * Verilen işlem tipine göre stok hareketi, çıkış, sütten çıkarma veya hayvan etiketini belirler.
 * @param {Object} e İşlem verisi ve tipini içeren nesne.
 * @returns {string} Belirlenen stok hareketi, kupesi veya hayvan etiketi.
 */
function _gmKatSatirEtiket(e){
  const d=e.data||{};
  if(e.type==='islem') return _gmIslemBaslikEtiketi(e);
  if(e.type==='stok') return d._urunAdi||'Stok hareketi';
  if(e.type==='cikis'||e.type==='sutten') return d.kupe_no||d.devlet_kupe||_gmHayvanEtiketVeya(d.id);
  const hid=d.hayvan_id||d.anne_id||d.animal_id;
  const a=hid?getState('animals').find(x=>x.id===hid||x.kupe_no===hid):null;
  return (a&&(a.kupe_no||a.devlet_kupe))||(globalThis._gmHayvanKupeById||{})[hid]||_gmHayvanEtiketVeya(hid);
}
// U1 md.3: katlanmış toplu kart — "🩺 Tedavi Günü Eklendi — 12 hayvan" + küpe
// listesi (ilk 8, kalan "+N"); tıklayınca altındaki tam kartlar açılır (gm-kat-ac).
// Tüm DB kaynaklı metin esc/escAttr; id DOM anahtarı deterministik-temizdir.
/**
 * Kayıt kaynağına, işlem tipine ve dakikaya göre etiket, emoji ve ID oluşturarak
 * stok hareketi veya işlem logu için bir kart HTML'i döndürür.
 * @param {Object} g Kayıt kaynağı, işlem tipi, girişler ve diğer verileri içeren nesne.
 * @returns {string} Oluşturulan stok kartı HTML'i ve gizli açıklama içeriği.
 */
function _gmKatKartHtml(g){
  const islemGrubu=g.sourceKey==='islem_log';
  const etiket=islemGrubu?_gmIslemTipEtiket(g.tip):(_GM_KATEGORI_TR[g.tip]||_gmIslemTipEtiket(g.tip));
  const emoji=islemGrubu?_gmIslemTipEmoji(g.tip):(_GM_KATEGORI_EMOJI[g.tip]||'📋');
  const olcu=g.sourceKey==='stok_hareket'?'kayıt':'hayvan';
  const etiketler=g.entries.map(_gmKatSatirEtiket).map(s=>String(s??''));
  const ilk=etiketler.slice(0,8).map(x=>esc(x)).join(' · ');
  const kalan=etiketler.length-8;
  const katId='gm-kat-'+String((g.dateKey||'')+'-'+(g.sourceKey||'')+'-'+(g.tip||'')+'-'+(g.dakika||'')).replace(/[^a-zA-Z0-9]+/g,'-');
  return `<div class="stok-item" style="background:var(--card);border:1.5px dashed var(--card3);border-radius:var(--r2);padding:11px 13px;margin-bottom:6px;display:flex;gap:10px;align-items:flex-start;cursor:pointer" data-action="gm-kat-ac" data-kat="${escAttr(katId)}">
    <div style="width:36px;height:36px;border-radius:10px;background:var(--card2);display:flex;align-items:center;justify-content:center;font-size:1.1rem;flex-shrink:0">${emoji}</div>
    <div style="flex:1;min-width:0">
      <div style="font-weight:700;font-size:.84rem;color:var(--ink)">${esc(etiket)} — ${Number(g.count)||0} ${olcu}</div>
      <div style="font-size:.68rem;color:var(--ink2);margin-top:2px;overflow-wrap:anywhere">${ilk}${kalan>0?` <b>+${kalan}</b>`:''}</div>
      <div style="font-size:.62rem;color:var(--ink3);margin-top:3px"><span class="gm-kat-ok">▸</span> Tıkla — ${Number(g.count)||0} kaydı göster</div>
    </div>
  </div>
  <div class="gm-kat-acik" id="${escAttr(katId)}" style="display:none">${g.entries.map(e=>_gecmisEntryHtml(e)).join('')}</div>`;
}

/**
 * Geçmiş kayıtları (hastalık, tohumlama, doğum, görev, uygulama, aşı vb.) için HTML kartı oluşturur.
 * Kayıt tipine göre başlık, alt bilgi, ikon ve tıklanabilir aksiyonları (dataset delegasyonu) belirler.
 * @param {Object} e Kayıt olayı veya veri nesnesi (type, data, eventAt, sourceKey, undoRef vb. içerir).
 * @param {string|undefined} overrideOc Inline onclick aksiyonunu zorla değiştirmek için opsiyonel string.
 * @returns {string} Geçmiş kartı HTML içeriği.
 */
function _gecmisEntryHtml(e, overrideOc){
  const {type,data}=e;
  const date=e.eventAt||e.date;   // ortak hat: eventAt esas (plan Görev 5-4)
  const d=date&&date.length>10?fmtTarihSaat(date):fmtTarih(date);
  const hk=HEKIMLER.find(h=>h.id===data.hekim_id);
  const hkName=hk?` · ${esc(hk.ad)}`:''; // TG1-W3 (luna F3): DB metni escape
  const hayvanKey=data.hayvan_id||data.anne_id||data.animal_id;
  const hayvanLabel=_gmHayvanEtiketVeya(hayvanKey); // W8-D3: ham id/UUID yerine çözülür; çözülmeyen → nötr etiket
  const ico=_GECMIS_ICO[type]||_gmIslemTipEmoji(data.tip); // U1: tek harita (gecmis.js)
  const icoBg=_GECMIS_BG[type]||'rgba(120,120,120,.1)';
  let oc='',title='',sub='';
  const _sk=e.sourceKey||type; // TG1: aynı tipin varyant kalemleri (sonuç/kapanış)
  // U1 md.2: geçmiş kartlarında inline onclick YOK — DB kimliği dataset'te
  // (escAttr) taşınır, tıklama handlers.js merkezi delegasyonuyla gider.
  if(type==='hastalik') oc=data.id?`data-action="gm-case" data-det="${escAttr(data.id)}" style="cursor:pointer"`:'';
  else if(type==='tohumlama') oc=data.id?`data-action="gm-toh" data-det="${escAttr(data.id)}" style="cursor:pointer"`:'';
  else if(type==='dogum') oc='';
  if(type==='dogum'){
    const anneLabel=_gmHayvanEtiketVeya(data.anne_id,'Anne'); // W8-D3: ham id/'?' yok
    title=`<span${data.anne_id?` data-action="gm-det" data-det="${escAttr(data.anne_id)}" style="cursor:pointer"`:''}>${esc(anneLabel)}</span> → <b${data.yavru_kupe?` data-action="gm-kupe" data-det="${escAttr(data.yavru_kupe)}" style="cursor:pointer;color:var(--blue)"`:''}>${esc(data.yavru_kupe||'Yavru')}</b>${data.yavru_cins?` (${esc(data.yavru_cins)})`:''}`; // U1: dataset delegasyonu; W8-D3: (?) kalmaz
    sub=`${esc(data.dogum_tipi||'Normal')}${hkName}`; // TG1-W3 (luna F3): dogum_tipi escape
  } else if(type==='tohumlama'&&_sk==='tohumlama_sonuc'){
    // TG1 gün görünümü: terminal sonuç KALEMİ — kendi sonuç gününde ayrı satır
    const sc=data.sonuc==='Gebe'?'var(--green)':data.sonuc==='Boş'?'var(--red)':'var(--amber)';
    title=`${esc(hayvanLabel)} — Gebelik muayenesi`;
    sub=`Sonuç: <b style="color:${sc}">${esc(data.sonuc||'—')}</b>${hkName}`;
  } else if(type==='tohumlama'){
    const sc=data.sonuc==='Gebe'?'var(--green)':data.sonuc==='Boş'?'var(--red)':'var(--amber)';
    title=`${esc(hayvanLabel)} — ${esc(data.sperma||'Tohumlama')}`; // W8-D3: DEDUP-birleşik kartta sperma boşsa islem etiketi ('?')
    sub=`${data.deneme_no||1}. Tohumlama · <b style="color:${sc}">${esc(data.sonuc||'Bekliyor')}</b>${hkName}`; // TG1-W3 (luna F3): sonuc escape
  } else if(type==='hastalik'){
    const sc=data.status==='active'?'var(--red)':'var(--green)';
    const _gunModu=!!e.olayGunu; // TG1 gün hattı entry'leri olayGunu taşır (defter taşımaz)
    title=`${esc(hayvanLabel)} — ${esc(data.disease_name||data.tani||'Vaka')}`;
    sub=_sk==='cases_kapanis'
      ?`<b style="color:var(--green)">Vaka kapandı</b>${hkName}`                          // TG1: kapanış kalemi
      :_gunModu?`<b style="color:${sc}">Vaka açıldı</b>${hkName}`                         // TG1: açılış kalemi
      :`<b style="color:${sc}">${data.status==='active'?'Aktif':'Kapalı'}</b>${hkName}`;  // defter/klasik aynen
  } else if(type==='gorev'){
    const gLabel=_gmHayvanEtiketVeya(data.hayvan_id,'GENEL'); // W8-D3: ham id yok; hayvansız görev GENEL (eski davranış, CSV aynasıyla birleşik)
    const _done=data.tamamlandi;
    const _pill=_done?'<span style="font-size:.6rem;padding:1px 6px;border-radius:8px;background:var(--card3);color:var(--ink3)">Tamamlandı</span>':'<span style="font-size:.6rem;padding:1px 6px;border-radius:8px;background:rgba(42,107,181,.15);color:var(--blue)">Bekliyor</span>';
    if(data.gorev_tipi==='TEDAVI_GUN'){
      const lbl=data._lbl||('Gün '+(data._gunNo||'?')+' tedavisi');
      title=`${esc(gLabel||'?')} — ${esc(lbl)}`; // TG1-W3 (luna F3): tedavi etiketi (DB aciklama JSON'undan) escape
      const drugLine=(data._drugNames||[]).length?`<div style="font-size:.66rem;color:var(--ink2);margin-top:1px">💊 ${esc(data._drugNames.join(', '))}</div>`:'';
      const disLine=data._disName?`<span style="font-size:.62rem;color:var(--ink3)">🏥 ${esc(data._disName)}</span> · `:'';
      sub=`${drugLine}<div style="margin-top:1px">${disLine}${_pill}</div>`;
      if(data._caseId) oc=`data-action="gm-case" data-det="${escAttr(data._caseId)}" style="cursor:pointer"`; // U1: dataset delegasyonu
    } else {
      let _aLbl='';try{const _p=typeof data.aciklama==='string'?JSON.parse(data.aciklama):data.aciklama;_aLbl=_p?.label||data.aciklama||'';}catch(e){_aLbl=data.aciklama||'';}
      // W8-D3: boş etiket → tip etiketi (tamamlanan kart "Görev Tamamlandı" —
      // R1 S1a kanıtı); pill ham kod değil TEK haritadan (gmKodDegerEtiketi;
      // haritada olmayan değer aynen, alt çizgiler boşluğa düşer).
      if(!_aLbl) _aLbl=data.tamamlandi?'Görev Tamamlandı':((typeof gmKodDegerEtiketi==='function'&&gmKodDegerEtiketi('gorev_tipi',data.gorev_tipi))||'Görev');
      const _tipPill=(typeof gmKodDegerEtiketi==='function'&&gmKodDegerEtiketi('gorev_tipi',data.gorev_tipi))||String(data.gorev_tipi||'').replace(/_/g,' ');
      title=`${esc(gLabel)} — ${esc(_aLbl)}`;
      sub=`<span class="pill ${escAttr(data.gorev_tipi||'DIGER')}">${esc(_tipPill)}</span> · ${_pill}${hkName}`; // TG1-W3 (luna F3): gorev_tipi class+metin escape
      if(data.hayvan_id) oc=`data-action="gm-det" data-det="${escAttr(data.hayvan_id)}" style="cursor:pointer"`; // U1: dataset delegasyonu
    }
  } else if(type==='uygulama'){
    const uLabel=_gmHayvanEtiketVeya(data.hayvan_id); // W8-D3: ham id yok
    title=`${esc(uLabel)} — ${esc(data._stokAdi||'Uygulama')}`;
    const _unt=typeof gmNotlarGorunur==='function'?gmNotlarGorunur(data.notlar):data.notlar;
    sub=`${esc(String(data.doz??'?'))} ${esc(data.birim||'ml')} · ${esc(data.rota||'IM')}${_unt?' · '+esc(_unt):''}`; // TG1-W3 (luna F3) escape + W8-D3: temizlenince ayraç da düşer
    if(data.hayvan_id) oc=`data-action="gm-det" data-det="${escAttr(data.hayvan_id)}" style="cursor:pointer"`; // U1: dataset delegasyonu
  } else if(type==='islem'){
    const kupe=_gmIslemBaslikEtiketi(e); // U1 root-düzeltme-2: hayvansızda '?' yerine görev adı/'Genel'
    title=`${esc(kupe)} — ${esc(_gmIslemTipEtiket(data.tip))}`; // U1: tek harita + okunur yedek — ham kod YOK (luna F3 escape'i korunur)
    const snap=data.snapshot||{};
    if(data.tip==='ASI_KAYDI') sub=esc(snap.vaccine_name||'');
    else if(data.tip==='ASI_ERTELEME') sub=esc(snap.erteleme_notu||snap.vaccine_name||'');
    else if(data.tip==='TOPLU_ILAC') sub=esc(snap.ilac_adi||'');
    else { const _irk=snap.irk||snap.grup||''; sub=esc(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(_irk).trim())?'':_irk); } // W8-D3: ham UUID alt satıra da girmez
    // U1 md.2: işlem aynası kartı KOŞULSUZ tıklanabilir — hayvan detayındaki
    // aynanın gittiği yer: islem detay paneli (openIslemDetay hattı). id yoksa
    // hayvan detayına düşer (eski kayıtlar).
    if(data.id) oc=`data-action="gm-islem" data-det="${escAttr(data.id)}" style="cursor:pointer"`;
    else if(data.ana_hayvan_id) oc=`data-action="gm-det" data-det="${escAttr(data.ana_hayvan_id)}" style="cursor:pointer"`;
  } else if(type==='asi'){
    // TG1 gün görünümü: vaccination_log kalemi (islem aynası dedup ile baskılanır)
    title=`${esc(hayvanLabel)} — ${esc(data._asiAdi||'Aşı')}`;
    sub=[data._asiAdi?'':'Aşı', data.next_due_date?`Rapel: ${fmtTarih(data.next_due_date)}`:''].filter(Boolean).join(' · ')+hkName;
    // TG1-W3 (luna F4): DB kimliği inline onclick yerine dataset + delegasyon
    if(data.animal_id) oc=`data-action="gm-det" data-det="${escAttr(data.animal_id)}" style="cursor:pointer"`;
  } else if(type==='kizginlik'){
    title=`${esc(hayvanLabel)} — Kızgınlık gözlemi`;
    sub=esc(data.belirti||'');
    if(data.hayvan_id) oc=`data-action="gm-det" data-det="${escAttr(data.hayvan_id)}" style="cursor:pointer"`; // TG1-W3 (luna F4)
  } else if(type==='stok'){
    // hayvansız kategori (rapor §E.3) — ürün adı zenginleştirmesi _urunAdi;
    // U1 md.2: stok_id bağlanabiliyorsa kart stok detayına gider
    const giris=['Giriş','İade','Düzeltme','Ekleme'].includes(data.tur);
    title=`${esc(data._urunAdi||'Stok hareketi')}`;
    const _nt=typeof gmNotlarGorunur==='function'?gmNotlarGorunur(data.notlar):data.notlar;
    sub=`<b style="color:${giris?'var(--green)':'var(--red)'}">${giris?'+':'−'}${esc(String(data.miktar??'?'))} ${esc(data._birim||'')}</b> · ${esc(data.tur||'')}${_nt?' · '+esc(_nt):''}`; // W8-D3: makine referansı görünmez; temizlenince ayraç da düşer
    if(data.stok_id) oc=`data-action="gm-stok" data-det="${escAttr(data.stok_id)}" style="cursor:pointer"`;
  } else if(type==='cikis'){
    // hayvanlar satırının KENDİSİ kaynak — etiket satırdan, state aramasız
    const lbl=data.kupe_no||data.devlet_kupe||_gmHayvanEtiketVeya(data.id);
    title=`${esc(lbl)} — Çıkış`;
    sub=`<b>${esc(data.cikis_tipi||'Çıkış')}</b> · Süruden çıkarıldı`;
    oc=`data-action="gm-det" data-det="${escAttr(data.id)}" style="cursor:pointer"`; // TG1-W3 (luna F4)
  } else if(type==='sutten'){
    const lbl=data.kupe_no||data.devlet_kupe||_gmHayvanEtiketVeya(data.id);
    title=`${esc(lbl)} — Sütten Kesme`;
    sub='Sütten kesildi';
    oc=`data-action="gm-det" data-det="${escAttr(data.id)}" style="cursor:pointer"`; // TG1-W3 (luna F4)
  } else if(type==='protokol'){
    const lbl=hayvanLabel||data.kupe_no||data.devlet_kupe||'Hayvan';
    title=`${esc(lbl)} — Protokol ${_sk==='protokol_instance_kapanis'?'kapandı':'başladı'}`;
    sub=_sk==='protokol_instance_kapanis'?'Protokol kapanışı':'Protokol başlangıcı';
    if(data.hayvan_id) oc=`data-action="gm-det" data-det="${escAttr(data.hayvan_id)}" style="cursor:pointer"`; // TG1-W3 (luna F4)
  }
  if(overrideOc!==undefined) oc=overrideOc;
  return `<div class="stok-item" style="background:var(--card);border:1px solid var(--card3);border-radius:var(--r2);padding:11px 13px;margin-bottom:6px;display:flex;gap:10px;align-items:flex-start" ${oc}>
    <div style="width:36px;height:36px;border-radius:10px;background:${icoBg};display:flex;align-items:center;justify-content:center;font-size:1.1rem;flex-shrink:0">${ico}</div>
    <div style="flex:1;min-width:0">
      <div style="font-weight:700;font-size:.84rem;color:var(--ink)">${title}</div>
      <div style="font-size:.68rem;color:var(--ink3);margin-top:2px">${sub}</div>
      <div style="font-size:.62rem;color:var(--ink3);margin-top:3px">${type==='gorev'?(data.tamamlandi?'✅ ':'⏳ ')+d:d}</div>
      ${_gmUndoButtonHtml(e.undoRef,{offline:!navigator.onLine,etiket:(e.type==='islem'&&e.data.tip==='GERI_ALINDI')?'⟲ Geri alınanı geri al':undefined})}
    </div>
  </div>`;
}

function _gecmisSearchText(e){
  const d=e.data, animals=getState('animals');
  const parts=[e.type, fmtTarih(e.eventAt||e.date)];
  /**
   * Verilen kimliğe (id veya küpe no) göre hayvanı bulup parça listesine küpe no, devlet küpe no ve isim bilgilerini ekler; hayvan bulunamazsa kimliği olduğu gibi ekler.
   * @param {*} id - Aranacak hayvanın kimliği veya küpe numarası.
   * @returns {void} Bir değer döndürmez.
   */
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
    parts.push(_gmIslemTipEtiket(d.tip),snap.vaccine_name||'',snap.ilac_adi||'',snap.irk||'',snap.kupe_no||'',snap.devlet_kupe||''); // U1: etiket + yedek aramaya da düşer
  }
  // TG1 tek-gün görünümü kategorileri
  else if(e.type==='asi'){parts.push(d._asiAdi||'','aşı','aşı kaydı');}
  else if(e.type==='kizginlik'){parts.push(d.belirti||'','kızgınlık');}
  else if(e.type==='stok'){parts.push(d._urunAdi||'',d.tur||'','stok','stok hareketi');}
  else if(e.type==='cikis'){parts.push(d.kupe_no||'',d.devlet_kupe||'',d.cikis_tipi||'','çıkış','satış');}
  else if(e.type==='sutten'){parts.push(d.kupe_no||'',d.devlet_kupe||'','sütten kesme');}
  else if(e.type==='protokol'){parts.push('protokol',e.sourceKey==='protokol_instance_kapanis'?'kapandı':'başladı');}
  const hk=HEKIMLER.find(h=>h.id===d.hekim_id);
  if(hk)parts.push(hk.ad);
  return trLower(parts.join(' ')).replace(/\s+/g,' ');
}

let _gecmisAllEntries=[];
let _gecmisAllVisible=[];
// Ana sekme + hayvan kartı geçmişi ORTAK veri hattı (D9): toplama+zenginleştirme
// burada, normalize→politika→arama→cap→gruplama js/gecmis.js'de.
/**
 * İndexedDB'den görev, tohumlama, vakalar, doğum, uygulama, işlem, aşı, kızgınlık, stok hareketi, hayvan ve protokol kayıtlarını okuyup,
 * ilaç isimleri, hastalık isimleri, stok adları ve birimler gibi ek verilerle zenginleştirilmiş nesneler oluşturarak
 * bu kayıtları anahtarlarına göre döndürür.
 * @returns {Object} Zenginleştirilmiş kayıtları içeren nesne (gorev_log, tohumlama, cases, dogum, uygulama_log, islem_log, vaccination_log, kizginlik_log, stok_hareket, hayvanlar, protokol_instance).
 */
async function _gecmisCollectSources(){
  const [gorevArr,tohArr,caseArr,dogumArr,uygArr,islemArr,vacArr,kizArr,stkHrkArr,hayvanArr,protoArr]=await Promise.all([
    idbGetAll('gorev_log'), idbGetAll('tohumlama'), idbGetAll('cases'), idbGetAll('dogum'),
    idbGetAll('uygulama_log').catch(()=>[]), idbGetAll('islem_log'),
    // TG1 Faz 1: tek-gün görünümünün 5 yeni kaynağı (rapor §B.1) — hepsi TABLES
    // pull kapsamında zaten IndexedDB'de; defter hattı bunları OKUMAZ (yalnız
    // _gmGunEntriesFromSources tüketir).
    idbGetAll('vaccination_log').catch(()=>[]), idbGetAll('kizginlik_log').catch(()=>[]),
    idbGetAll('stok_hareket').catch(()=>[]), idbGetAll('hayvanlar').catch(()=>[]),
    idbGetAll('protokol_instance').catch(()=>[])
  ]);
  // Zenginleştirme birleştirmeleri (gecmis.js saf kalır — data üzerinden taşınır)
  const [tDays,adm,disArr,stokArr,prodArr,vacArr2]=await Promise.all([
    idbGetAll('treatment_days').catch(()=>[]), idbGetAll('drug_administrations').catch(()=>[]),
    idbGetAll('diseases').catch(()=>[]), idbGetAll('stok').catch(()=>[]), idbGetAll('drug_products').catch(()=>[]),
    idbGetAll('vaccines').catch(()=>[])
  ]);
  const stokById=Object.fromEntries(stokArr.map(s=>[s.id,s.urun_adi||'']));
  const prodById=Object.fromEntries(prodArr.map(p=>[p.id,p.brand_name||'']));
  const vaxById=Object.fromEntries(vacArr2.map(v=>[v.id,v.name||'']));
  const drugsByDay={};
  adm.forEach(da=>{
    if(!da.treatment_day_id)return;
    const name=prodById[da.drug_product_id]||stokById[da.stok_id]||'';
    if(name)(drugsByDay[da.treatment_day_id]=drugsByDay[da.treatment_day_id]||[]).push(name);
  });
  const tDayById=Object.fromEntries(tDays.map(td=>[td.id,td]));
  const caseById=Object.fromEntries(caseArr.map(c=>[c.id,c]));
  const disById=Object.fromEntries(disArr.map(d=>[d.id,d.name||'']));
  const casesEnr=caseArr.map(r=>{
    const _d=disArr.find(d=>d.id===r.disease_id);
    const _drugNames=[];
    tDays.forEach(td=>{ if(td.case_id===r.id)(drugsByDay[td.id]||[]).forEach(n=>{if(!_drugNames.includes(n))_drugNames.push(n);}); });
    return {...r,disease_name:_d?.name||'?',tani:_d?.name||'?',_drugNames};
  });
  const gorevEnr=gorevArr.map(r=>{
    let dayId=null,_lbl='',_gunNo='';
    try{const p=typeof r.aciklama==='string'?JSON.parse(r.aciklama):r.aciklama;dayId=p?.day_id;_lbl=p?.label||'';_gunNo=p?.gun_no||'';}catch(e){}
    const _drugNames=(dayId&&drugsByDay[dayId])||[];
    const _td=dayId&&tDayById[dayId];
    const _cs=_td&&caseById[_td.case_id];
    const _disName=_cs&&disById[_cs.disease_id]||'';
    const _caseId=_cs?.id||'';
    return {...r,_drugNames,_lbl,_gunNo,_disName,_caseId};
  });
  const uyEnr=uygArr.map(r=>({...r,_stokAdi:stokById[r.stok_id]||'?'}));
  // TG1: aşı adı vaccines kataloğundan, stok hareketi ürün adı+birimi stok'tan zenginleştirilir
  const vacEnr=vacArr.map(r=>({...r,_asiAdi:vaxById[r.vaccine_id]?.name||''}));
  const stokSatiri=Object.fromEntries(stokArr.map(s=>[s.id,s]));
  const stkHrkEnr=stkHrkArr.map(r=>({...r,_urunAdi:stokById[r.stok_id]||'',_birim:stokSatiri[r.stok_id]?.birim||''}));
  // U1 (root 2026-09-14 düzeltme-1): id→küpe indeksi — kartlarda ham UUID ASLA
  // görünmesin. state 'animals' boot-pull commit'ini kaçırabilir; hayvanlar zaten
  // bu collect'te IDB'den okunduğu için buradan indekslenir (state-gecikmesine
  // karşı ikinci kaynak).
  globalThis._gmHayvanKupeById=Object.fromEntries(hayvanArr.map(h=>[h.id,(h.kupe_no||h.devlet_kupe||'')]).filter(([,k])=>k));
  return {
    gorev_log:gorevEnr, tohumlama:tohArr, cases:casesEnr, dogum:dogumArr, uygulama_log:uyEnr, islem_log:islemArr,
    vaccination_log:vacEnr, kizginlik_log:kizArr, stok_hareket:stkHrkEnr, hayvanlar:hayvanArr, protokol_instance:protoArr,
  };
}

// Görünüm tercihi: Defter (gün gruplu, saf-bitmiş) ↔ Klasik (eski düz liste,
// "Tümü" toggle'ı ile birlikte). localStorage'da kalıcı (D15).
/**
 * 'ege_gecmis_klasik' anahtarını localStorage'dan okuyup değeri '1' ise true döndürür, hata durumunda false döndürür.
 * @returns {boolean} Değer '1' ise true, yoksa veya hata varsa false.
 */
function _gecmisKlasik(){ try{ return localStorage.getItem('ege_gecmis_klasik')==='1'; }catch(e){ return false; } }
/**
 * Geçmiş klasik görünüm ayarını yönetir: localStorage'da 'ege_gecmis_klasik' anahtarını ayarlar,
 * 'Tümü' toggle'ını klasik görünümde aktifken gösterir ve görünüm toggle'ının arka plan rengini ve
 * iç elemanın konumunu (klasik görünümde yeşil/16px, değilse gri/2px) günceller.
 * @param {boolean} v Klasik görünümün aktif olup olmadığını belirten boolean değer.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _gecmisSetKlasik(v){
  try{ v?localStorage.setItem('ege_gecmis_klasik','1'):localStorage.removeItem('ege_gecmis_klasik'); }catch(e){}
  // "Tümü" toggle'ı yalnız klasik görünümde anlamlı
  const tum = document.getElementById('gecmis-tumu-wrap');
  if(tum) tum.style.display = v?'flex':'none';
  const sw = document.getElementById('gecmis-gorunum-toggle');
  if(sw){
    sw.style.background = v?'var(--green)':'var(--card3)';
    if(sw.firstElementChild) sw.firstElementChild.style.left = v?'16px':'2px';
  }
}

/**
 * Geçmiş kayıtlarını filtreleyip (kategori, gün, arama sorgusu) ve görünüm moduna (klasik/gün-gruplu) göre HTML içeriği oluşturarak 'gecmis-body' elementine render eder.
 * @param {string} q Arama için kullanılan sorgu metni.
 * @returns {void} Fonksiyon yan etkisi olarak DOM'u günceller, doğrudan değer döndürmez.
 */
function _gecmisRender(q){
  const el=document.getElementById('gecmis-body');
  if(!el)return;
  q=q||'';
  // kategori çipi (Tümü anahtarı kaldırıldı — D3); uygulama → Görev çipi,
  // islem → Hayvan çipi altında sayılır (bugünkü semantik)
  const f=_curGecmisFilter||'hepsi';
  let list=_gecmisAllEntries;
  if(f==='dogum') list=list.filter(e=>e.category==='dogum');
  else if(f==='tohumlama') list=list.filter(e=>e.category==='tohumlama');
  else if(f==='hastalik') list=list.filter(e=>e.category==='hastalik');
  else if(f==='gorev') list=list.filter(e=>e.category==='gorev'||e.category==='uygulama');
  else if(f==='hayvan') list=list.filter(e=>e.category==='islem');
  // U1 md.4: gün modu kategori çip filtresi (istemci tarafı, ek pull yok;
  // üst filtre düğmelerinden bağımsız daraltma — çip tekrar tık ile kalkar)
  if(_gecmisGun&&_gecmisGunCip) list=list.filter(e=>e.category===_gecmisGunCip);
  const filtreliSayi=list.length;
  list=_gmSearch(list,q);
  const {visible,total}=_gmCap(list,300);
  _gecmisAllVisible=visible;
  globalThis._gmCsvCtx={visible,meta:_gecmisCsvMeta()};
  if(!visible.length){el.innerHTML=`<div class="empty"><div class="empty-ico">📭</div>${_gecmisGun?'Bu güne ait kayıt yok':'Kayıt bulunamadı'}</div>`;return;}
  // cap ipucu (D7) / arama sonuç sayısı
  const hint=total>visible.length
    ?`<div style="font-size:.65rem;color:var(--ink3);margin-bottom:6px;padding:0 2px">İlk ${visible.length} / ${total} kayıt</div>`
    :(q.trim()&&total<filtreliSayi?`<div style="font-size:.65rem;color:var(--ink3);margin-bottom:6px;padding:0 2px">${total} / ${filtreliSayi} sonuç</div>`:'');
  // TG1 Faz 1: tek-gün görünümü — tek gün grubu; todayKey = GERÇEK bugün
  // (seçili gün ASLA todayKey'e geçirilmez — sözleşme md.4; seçili gün
  // vurgusu banner'da ayrı). Klasik/Defter ayrımı gün görünümünde anlamsız.
  if(_gecmisGun){
    const grup=_gmGroup(visible)[0];
    if(grup) el.innerHTML=hint+_gmGroupHtml(grup,_gecmisEntryHtml,{open:true,todayKey:_gmTodayKey(),katHtmlFn:_gmKatKartHtml}); // U1: katlama
    return;
  }
  // Klasik görünüm (D15): gün gruplamasız eski düz liste — U1 md.15: etiket/
  // tıklama/katlama burada da geçerli (katlama anahtarı dateKey taşır — gün güvenli)
  if(_gecmisKlasik()){
    const dugumler=_gmGunKatla(visible);
    el.innerHTML=hint+dugumler.map(d=>d.grup?_gmKatKartHtml(d):_gecmisEntryHtml(d.entry)).join('');
    return;
  }
  // arama aktifken tüm gün grupları açık zorunlu (spec C)
  const gruplar=_gmGroup(visible)
    .map(g=>_gmGroupHtml(g,_gecmisEntryHtml,{open:!!q.trim(),todayKey:_gmTodayKey(),katHtmlFn:_gmKatKartHtml})) // U1: katlama
    .join('');
  el.innerHTML=hint+gruplar;
}

// Çip etiketleri — politika geçmiş (arama öncesi) entrylerden (plan Görev 5-5)
/**
 * Geçmiş giriş kayıtlarını kategorilerine göre sayar ve ilgili DOM elementlerinin metin içeriğini kategori adı ile birlikte günceller.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function _gecmisChipCounts(){
  const e=_gecmisAllEntries;
  /**
   * Verilen kategoriye sahip öğelerin sayısını döndürür.
   * @param {string} t Filtreleme yapılacak kategori adı.
   * @returns {number} Belirtilen kategoriye sahip öğelerin sayısı.
   */
  const n=t=>e.filter(x=>x.category===t).length;
  const base={'gecmis-hepsi':'Hepsi','gecmis-dogum':'🐄 Doğum','gecmis-tohumlama':'💉 Tohumlama','gecmis-hastalik':'🏥 Hastalık','gecmis-gorev':'✅ Görev','gecmis-hayvan':'🐮 Hayvan'};
  const sayilar={'gecmis-hepsi':e.length,'gecmis-dogum':n('dogum'),'gecmis-tohumlama':n('tohumlama'),'gecmis-hastalik':n('hastalik'),'gecmis-gorev':n('gorev')+n('uygulama'),'gecmis-hayvan':n('islem')};
  Object.entries(sayilar).forEach(([act,sayi])=>{
    const b=document.querySelector(`#pg-gecmis [data-action="${act}"]`);
    if(b)b.textContent=`${base[act]} (${sayi})`;
  });
}

// CSV = WYSIWYG görünen dilim (D7) — kart alanlarının düz metin aynası
/**
 * Geçmiş CSV dışa aktarımı için küpe, detay, ek, hekim ve tip çözümleyici fonksiyonlarını içeren meta nesnesini oluşturur.
 * @returns {{kupe: Function, detay: Function, ek: Function, hekim: Function, tip: Function}} Her biri bir geçmiş kaydını (entry) alıp ilgili CSV hücre değerini döndüren çözümleyici fonksiyonlardan oluşan nesne.
 */
function _gecmisCsvMeta(){
  const animals=getState('animals');
  /**
   * Verilen kimliğe sahip hayvanın küpe numarası etiketini döndürür; hayvan bulunamazsa kimliği olduğu gibi döndürür, boş kimlikte boş dize döner.
   * @param {*} id - Aranacak hayvan kimliği veya küpe numarası.
   * @returns {string} Bulunan hayvanın kupe_no veya devlet_kupe değeri; bulunamazsa verilen kimlik, kimlik yoksa boş dize.
   */
  const lblOf=id=>{ if(!id)return''; const a=animals.find(x=>x.id===id||x.kupe_no===id); return a?(a.kupe_no||a.devlet_kupe||''):id; };
  /**
   * HEKIMLER dizisinden verilen ID'ye sahip hekimin adını döndürür.
   * @param {string} id Aranan hekimin ID'si.
   * @returns {string} Bulunan hekimin adı yoksa boş string.
   */
  const hkOf=id=>{ const h=HEKIMLER.find(x=>x.id===id); return h?h.ad:''; };
  return {
    /**
     * Verilen eylem tipine göre hayvanın küpe numarasını, etiketini veya ilgili bir değer döndürür.
     * @param {Object} e Eylem nesnesi; 'type' özelliği ile işlem türünü ('islem', 'dogum', 'cikis', 'sutten', 'stok'), 'data' özelliği ile veri objesini içerir.
     * @returns {string} İlgili hayvanın küpe numarası, devlet küpe numarası, etiketi veya boş string.
     */
    kupe:e=>{
      const d=e.data;
      if(e.type==='islem'){
        const snap=d.snapshot||{};
        const a=animals.find(x=>x.id===d.ana_hayvan_id);
        let _ex={};try{_ex=JSON.parse(localStorage.getItem('ege_exited_kupe')||'{}');}catch(err){}
        // U1 root-düzeltme-1: UUID YOK — çözülmeyen küpe CSV'de boş kalır
        return a?.kupe_no||a?.devlet_kupe||snap.kupe_no||snap.devlet_kupe||_ex[d.ana_hayvan_id]||(globalThis._gmHayvanKupeById||{})[d.ana_hayvan_id]||'';
      }
      if(e.type==='dogum')return lblOf(d.anne_id);
      // TG1 tek-gün kategorileri: hayvanlar satırı KENDİ küpesini taşır
      if(e.type==='cikis'||e.type==='sutten')return d.kupe_no||d.devlet_kupe||_gmHayvanEtiketVeya(d.id); // W8-review-I3: ham id yerine nötr (detay kolonuyla birleşik)
      if(e.type==='stok')return '';
      return lblOf(d.hayvan_id||d.anne_id||d.animal_id);
    },
    /**
     * Farklı işlem tiplerine (doğum, tohumlama, hastalık, görev, uygulama, aşı vb.) göre ilgili hayvan etiketini ve işlem detayını birleştirerek okunabilir bir metin stringi döndürür.
     * @param {Object} e İşlem verisi ve tipini içeren nesne.
     * @returns {string} İşlem tipine göre formatlanmış metin stringi.
     */
    detay:e=>{
      const d=e.data;
      // W8-D3: CSV = kartın düz metin aynası — '?' fallbacks kartlarla birlikte nötrleşti
      if(e.type==='dogum')return `${lblOf(d.anne_id)} → ${d.yavru_kupe||'Yavru'}${d.yavru_cins?` (${d.yavru_cins})`:''}`;
      if(e.type==='tohumlama')return `${lblOf(d.hayvan_id)} — ${e.sourceKey==='tohumlama_sonuc'?'Gebelik muayenesi sonucu: '+(d.sonuc||'—'):(d.sperma||'Tohumlama')}`;
      if(e.type==='hastalik')return `${lblOf(d.animal_id)} — ${d.disease_name||d.tani||'Vaka'}`;
      if(e.type==='gorev'){
        const gl=_gmHayvanEtiketVeya(d.hayvan_id,'GENEL'); // W8-review-I2: kartla birebir (hayvansız → GENEL)
        if(d.gorev_tipi==='TEDAVI_GUN')return `${gl} — ${d._lbl||('Gün '+(d._gunNo||'—')+' tedavisi')}`;
        let _aLbl='';try{const p=typeof d.aciklama==='string'?JSON.parse(d.aciklama):d.aciklama;_aLbl=p?.label||d.aciklama||'';}catch(err){_aLbl=d.aciklama||'';}
        if(!_aLbl)_aLbl=d.tamamlandi?'Görev Tamamlandı':((typeof gmKodDegerEtiketi==='function'&&gmKodDegerEtiketi('gorev_tipi',d.gorev_tipi))||'Görev');
        return `${gl} — ${_aLbl}`;
      }
      if(e.type==='uygulama')return `${lblOf(d.hayvan_id)} — ${d._stokAdi||'Uygulama'}`;
      if(e.type==='asi')return `${lblOf(d.animal_id)} — ${d._asiAdi||'Aşı'}`;
      if(e.type==='kizginlik')return `${lblOf(d.hayvan_id)} — Kızgınlık`;
      if(e.type==='stok')return d._urunAdi||'Stok hareketi';
      if(e.type==='cikis')return `${d.kupe_no||d.devlet_kupe||_gmHayvanEtiketVeya(d.id)} — Çıkış (${d.cikis_tipi||'—'})`;
      if(e.type==='sutten')return `${d.kupe_no||d.devlet_kupe||_gmHayvanEtiketVeya(d.id)} — Sütten Kesme`;
      if(e.type==='protokol')return `${lblOf(d.hayvan_id)} — Protokol`;
      const snap=d.snapshot||{};
      const k=snap.kupe_no||snap.devlet_kupe||lblOf(d.ana_hayvan_id)||'?';
      return `${k} — ${_gmIslemTipEtiket(d.tip)}`; // U1: tek harita + okunur yedek
    },
    /**
     * Farklı olay tiplerine (dogum, tohumlama, hastalik, gorev, uygulama, asi, stok, cikis, sutten, protokol) göre ilgili veriyi işleyip formatta döndürür.
     * @param {Object} e Olay nesnesi; type, data, sourceKey gibi özellikleri içerir.
     * @returns {String} Olay tipine göre oluşturulmuş formatta metin.
     */
    ek:e=>{
      const d=e.data;
      if(e.type==='dogum')return `${d.dogum_tipi||'Normal'}${hkOf(d.hekim_id)?' · '+hkOf(d.hekim_id):''}`;
      if(e.type==='tohumlama')return e.sourceKey==='tohumlama_sonuc'?`Sonuç: ${d.sonuc||''}`:`${d.deneme_no||1}. Tohumlama · ${d.sonuc||''}${hkOf(d.hekim_id)?' · '+hkOf(d.hekim_id):''}`;
      if(e.type==='hastalik')return `${e.sourceKey==='cases_kapanis'?'Vaka kapandı':(d.status==='active'?'Aktif':'Kapalı')}${hkOf(d.hekim_id)?' · '+hkOf(d.hekim_id):''}`;
      if(e.type==='gorev'){
        const parcalar=[];
        if((d._drugNames||[]).length)parcalar.push(d._drugNames.join(', '));
        if(d._disName)parcalar.push(d._disName);
        parcalar.push('Tamamlandı');
        return parcalar.join(' · ');
      }
      if(e.type==='uygulama')return `${d.doz||'?'} ${d.birim||'ml'} · ${d.rota||'IM'}${(()=>{const n=typeof gmNotlarGorunur==='function'?gmNotlarGorunur(d.notlar):d.notlar;return n?' · '+n:'';})()}`; // W8-review-I3 aynası
      if(e.type==='asi')return d.next_due_date?`Rapel: ${d.next_due_date}`:'';
      if(e.type==='stok')return `${['Giriş','İade','Düzeltme','Ekleme'].includes(d.tur)?'+':'−'}${d.miktar??'?'} ${d._birim||''} · ${d.tur||''}${d.notlar?' · '+(typeof gmNotlarGorunur==='function'?gmNotlarGorunur(d.notlar):d.notlar):''}`; // W8-D3 aynası
      if(e.type==='cikis')return d.cikis_tipi||'';
      if(e.type==='sutten')return 'Sütten kesildi';
      if(e.type==='protokol')return e.sourceKey==='protokol_instance_kapanis'?'Kapandı':'Başladı';
      const snap=d.snapshot||{};
      return snap.vaccine_name||snap.ilac_adi||snap.irk||snap.grup||'';
    },
    /**
     * 'hekim' olayını işler; olay verisindeki hekim_id ile hkOf fonksiyonunu çağırır.
     * @param {Object} e - Hekim verisini içeren olay nesnesi.
     * @param {Object} e.data - Olayın veri kısmı.
     * @param {*} e.data.hekim_id - Aranacak hekimin kimliği.
     * @returns {*} hkOf fonksiyonunun hekim_id ile döndürdüğü sonuç.
     */
    hekim:e=>hkOf(e.data.hekim_id),
    // Tip = İÇ kayıt tipi (spec D): entry tipi + varsa alt tip (gorev_tipi / islem tipi)
    /**
     * Görev veya işlem tipine göre etiketli bir string döndürür.
     * @param {Object} e Tipi 'gorev' veya 'islem' olan bir nesne.
     * @returns {String} Görev tipi, işlem tipi veya varsayılan tip içeren etiketli string.
     */
    tip:e=> e.type==='gorev'?('gorev:'+(e.data.gorev_tipi||'')):(e.type==='islem'?('islem:'+e.data.tip):e.type),
  };
}

// Geri al butonu kart içinden → TEK GİRİŞ dgGeriAlAkisi (L4-W2; a+b modalı söküldü).
// kind 'l2' → islem_log entry'si _gmIslemLogById'den çözülür (U1 haritası);
// kind 'toh' → islem_log'suz Bekliyor kaydı: hedef tohumlama satırının kendisi.
/**
 * Belirtilen ID'li işlemin geri alma işlemini gerçekleştirir.
 * Eğer tür 'toh' ise tohumlama tablosundan satır geri almayı tetikler.
 * Aksi takdirde, önce hafızadaki, yoksa IDB'den işlem loglarından ilgili kaydı bulur
 * ve bu kaydı geri alma işlemi için kullanır. Kayıt bulunamazsa kullanıcıya hata bildirir.
 * @param {string} kind İşlem türü ('toh' veya diğerleri).
 * @param {string} id Geri alınacak işlemin benzersiz kimliği.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function gmUndoClick(kind,id){
  if(kind==='toh'){
    dgGeriAlAkisi({tablo:'tohumlama',pk:id},'satir',{olayEtiketi:'Tohumlama',zaman:'',kim:''});
    return;
  }
  // L4 (lead düzeltmesi 2026-09-15): gün DEDUP'u islem-TOHUMLAMA kartını
  // tohumlama-tablo girdisiyle birleştirir — birleşik kart type 'tohumlama'
  // olduğundan _gmIslemLogById haritasına girmez, düğmenin islem-id'si burada
  // çözülmezdi. Yedek: IDB'den birebir satırı çek (tek satırlık okuma).
  let l=(globalThis._gmIslemLogById||{})[id];
  if(!l){
    try {
      const tum = await idbGetAll('islem_log');
      l = tum.find(x => x && x.id === id) || null;
    } catch (_e) { l = null; }
  }
  if(!l){ toast('⚠️ Bu olay için geri alma hedefi çözülemedi — Değişiklikler sayfasından deneyin', true); return; }
  dgGeriAlFromEntry(l);
}

/**
 * Geçmiş verilerini yükler, gerekli tablolardan (gorev_log, tohumlama, cases vb.) veri çeker,
 * gün bazlı veya klasik/defter modunda kayıtları işleyip arayüzü günceller.
 * @param {string} f Filtreleme değeri; varsayılan olarak mevcut filtre veya 'hepsi' kullanılır.
 * @param {HTMLElement} btn Aktif buton; varsa diğer butonlardan 'on' sınıfı kaldırılır ve bu butona eklenir.
 * @param {Object} opts Seçenekler objesi; skipPull özelliği varsa ve true ise çevrimiçi veri çekimi atlanır.
 * @returns {Promise<void>} Veri yükleme işlemi tamamlandığında veya hata oluştuğunda çözülür.
 */
async function loadGecmis(f,btn,opts){
  _curGecmisFilter=f||_curGecmisFilter||'hepsi';
  if(btn){ document.querySelectorAll('#pg-gecmis .fs-btn').forEach(b=>b.classList.remove('on')); btn.classList.add('on'); }
  _gecmisSetKlasik(_gecmisKlasik());
  const el=document.getElementById('gecmis-body');
  await _keepScroll(el,async()=>{
  el.innerHTML='<div class="loader"><div class="spin"></div></div>';
  try {
    // D14: sekme girişinde çevrimiçiyken taze veri çek; offline IDB önbelleği
    // (görünüm/tümü toggle'ı skipPull ile — ağ bağlantısız anında geçiş).
    // TG1: vaccination_log + kizginlik_log (rapor §G) + stok_hareket (zarf md.6
    // — gün görünümü bayat stok göstermesin) çekim listesine eklendi.
    if(navigator.onLine && !(opts&&opts.skipPull)) await pullTables(['gorev_log','tohumlama','cases','dogum','treatment_days','drug_administrations','drug_products','stok','islem_log','uygulama_log','diseases','vaccination_log','kizginlik_log','stok_hareket']).catch(()=>{});
    const sources=await _gecmisCollectSources();
    // W3: takvim işaretli günleri — IDB havuzundan tam kapsamlı gün kümesi
    // (ay sayfalama yeniden hesabı gerekmez; ay dışı günler takvimde zaten çizilmez)
    if(typeof _gmGunKumesiFromSources==='function') _gecmisGunKumesi=_gmGunKumesiFromSources(sources);
    // TG1 Faz 1: seçili gün varsa tek-gün hattı (olayGunu kuralı + gün
    // politikaları + DEDUP, js/gecmis.js _gmGunEntriesFromSources); yoksa
    // defter/klasik hattı aynen. todayKey ASLA seçili güne geçirilmez (sözleşme).
    const entries=_gecmisGun
      ? _gmGunEntriesFromSources(sources).filter(e=>e.olayGunu===_gecmisGun)
      : _gmEntriesFromSources(sources,null,{mode:_gecmisKlasik()?'klasik':'defter',tumu:_gecmisTumu});
    entries.forEach(e=>{ e.searchText=_gecmisSearchText(e); });
    _gecmisAllEntries=entries;
    // U1 md.2: islem kartı → detay paneli id haritası (merge; det yüzeyiyle çakışmaz)
    const _logMap=globalThis._gmIslemLogById||(globalThis._gmIslemLogById={});
    entries.forEach(e=>{ if(e.type==='islem'&&e.data&&e.data.id) _logMap[e.data.id]=e.data; });
    _gecmisGunSayi=_gecmisGun?entries.length:0;
    _gecmisChipCounts();
    _gecmisGunBannerGuncelle();
    _gecmisGunCiplerGuncelle(); // U1 md.4: gün özeti kategori çipleri
    const q=(document.getElementById('gecmis-search')||{}).value||'';
    _gecmisRender(q);
  } catch(e){ el.innerHTML=`<div class="empty">⚠️ ${esc(e.message)}</div>`; }
  });
}

// ── TG1 Faz 1: "tarihe git" — tek-gün görünümü girişi ─────────────
// Seçim kanonik tarih seçiciyle (tekTarihTakvimAc); Bugün/Dün hızlı
// girişleri şeritten. _gecmisGun=null → defter görünümü döner.
let _gecmisGun=null;       // seçili gün (ISO YYYY-MM-DD) ya da null
let _gecmisGunSayi=0;      // seçili günün (arama/filtre ÖNCESİ) olay sayısı
let _gecmisGunCip=null;    // U1 md.4: gün modu kategori çip filtresi (category|null)
let _gecmisGunKumesi=null; // W3: takvim işaretli günleri (Set<ISO> — loadGecmis'te tazelenir)
/**
 * Bugünün ve önceki günlerin seçilebileceği '📅 Tarihe Git' başlıklı tek tarih takvimini açar; seçilen gün için geçmiş görünümünü günceller.
 * @returns {void}
 */
function gecmisTariheGitAc(){
  tekTarihTakvimAc({
    baslik:'📅 Tarihe Git',
    deger:_gecmisGun||bugun(),
    max:bugun(), // olay görünümü geçmişe bakar; gelecek gün boş kalırdı
    // W3: olaylı günler — loadGecmis'in IDB havuzundan hesaplı küme (ek pull yok)
    isaretliGunler:_gecmisGunKumesi||undefined,
    onSec:iso=>{ if(iso) gecmisGunSec(iso); },
  });
}
/**
 * Geçmiş gün filtresini yeni bir ISO tarihli güne ayarlar, eski gün değişirse çip filtresini sıfırlar ve tarih değişikliğini tarayıcı geçmişi (history) ile kaydederek geri tuşu işlevini tetikler.
 * @param {string|null} iso Yeni geçmiş gün için ISO formatında tarih string'i veya null.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function gecmisGunSec(iso){
  const _eski=_gecmisGun;
  _gecmisGun=iso||null;
  _gecmisGunCip=null; // U1: gün değişince çip filtresi sıfırlanır
  // W3: gün görünümü history'ye girer — geri tuşu görünümden deftere döner
  // (popstate → navGeriKarar 'gun' dalı → gecmisGunKapat), sayfa değişmez.
  if(_gecmisGun && _gecmisGun!==_eski) history.pushState({pg:'gecmis',gun:_gecmisGun},'','');
  loadGecmis(null,null,{skipPull:true}); // veri tab girişinde çekildi; offline de çalışır
}
// W3: ✕ Kapat + geri tuşu ortak kapanışı — banner deseni aynen çalışır,
// history'de gün entry'si bırakmaz (navViewBack guard'lı back).
/**
 * Geçmiş gün seçimi ve ilgili referansları sıfırlar, geçmiş yükleme işlemini iptal eder ve geri dönüş butonunu tetikler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function gecmisGunKapat(){
  _gecmisGun=null;
  _gecmisGunCip=null;
  loadGecmis(null,null,{skipPull:true});
  if(typeof navViewBack==='function') navViewBack();
}
// Seçili gün vurgusu — banner todayKey'ten BAĞIMSIZ yüzeydir (sözleşme md.4):
// BUGÜN/DÜN etiketi grup başlığında gerçek bugüne göre kalır; banner yalnızca
// seçimi gösterir (etiket _gmGroupLabel'dan, gerçek todayKey ile).
/**
 * Geçmiş gün banner'ını günceller; banner elementini bulur, varsa içeriğini gün adı, tarih ve olay sayısı ile doldurur, yoksa gizler.
 * @returns {void}
 */
function _gecmisGunBannerGuncelle(){
  const b=document.getElementById('gecmis-gun-banner');
  if(!b) return;
  if(!_gecmisGun){ b.style.display='none'; b.innerHTML=''; return; }
  const gunAd=_gmGroupLabel(_gecmisGun) // BUGÜN/DÜN/d MMMM — gerçek bugüne göre
    ||_gecmisGun;
  b.style.display='block';
  b.innerHTML=`<div style="display:flex;align-items:center;gap:8px;margin-bottom:9px;padding:8px 12px;background:rgba(42,107,181,.08);border:1.5px solid rgba(42,107,181,.35);border-radius:12px">
    <span style="font-size:1rem">📅</span>
    <div style="flex:1;min-width:0">
      <div style="font-weight:800;font-size:.8rem;color:var(--ink)">${esc(gunAd)} · ${esc(fmtTarih(_gecmisGun))}</div>
      <div style="font-size:.66rem;color:var(--ink3)">${_gecmisGunSayi} olay</div>
    </div>
    <button class="fs-btn" style="white-space:nowrap;flex-shrink:0" data-action="gecmis-gun-kapat" title="Gün görünümünden çık — deftere dön">✕ Kapat</button>
  </div>`;
}
// U1 md.4: gün özeti kategori çipleri — banner'ın altında sayaçlı çip satırı;
// tık → o kategoriye filtre (tekrar tık/Tümü → kaldır). Sayaçlar filtre ÖNCESİ
// tüm günü sayar (_gmGunKategoriSayac — gecmis.js saf). Yalnız gün modunda görünür.
/**
 * Geçmiş gün çipler (filtre butonları) oluşturur veya günceller.
 * Eğer gün modu aktif değilse bileği gizler; aktifse ise tüm kategorileri ve kategori sayacına göre sıralanmış filtre butonlarını oluşturur.
 * @returns {void}
 */
function _gecmisGunCiplerGuncelle(){
  const w=document.getElementById('gecmis-gun-cipler');
  // U1 (root düzeltme-3): gün modunda eski üst filtre satırı GİZLİ — tek filtre
  // satırı çiplerdir, sayılar aynı pipeline'dan (tutarsız sayı olamaz)
  const eskiSatir=document.getElementById('gecmis-filtre-satir');
  if(eskiSatir) eskiSatir.style.display=_gecmisGun?'none':'flex';
  if(!w) return;
  if(!_gecmisGun){ w.style.display='none'; w.innerHTML=''; return; }
  const s=_gmGunKategoriSayac(_gecmisAllEntries);
  const katlar=Object.keys(_GM_KATEGORI_TR).filter(k=>s[k]).sort((a,b)=>s[b]-s[a]);
  w.style.display='block';
  w.innerHTML='<div class="gm-cip-sarm">'
    +`<button class="gm-cip${_gecmisGunCip?'':' on'}" data-action="gm-gun-cip" data-kat="" title="Tüm kategorileri göster">Tümü (${_gecmisAllEntries.length})</button>`
    +katlar.map(k=>`<button class="gm-cip${_gecmisGunCip===k?' on':''}" data-action="gm-gun-cip" data-kat="${escAttr(k)}" title="Yalnız ${esc(_GM_KATEGORI_TR[k]||k)} göster">${_GM_KATEGORI_EMOJI[k]||''} ${esc(_GM_KATEGORI_TR[k]||k)} (${s[k]})</button>`).join('')
    +'</div>';
}

// ──────────────────────────────────────────
// STOK — helpers
// ──────────────────────────────────────────
/**
 * Durum parametresine göre renk kodunu döndürür.
 * @param {string} d Durum değeri ('neg', 'crit' veya varsayılan).
 * @returns {string} CSS renk değişkeni değeri.
 */
function _durumClr(d){ if(d==='neg')return'var(--red)'; if(d==='crit')return'var(--amber)'; return'var(--green)'; }
/**
 * Durum parametresine göre özel bir durum etiketi döndürür.
 * @param {string} d - Durum kodu ('neg', 'crit' veya varsayılan).
 * @returns {string} Duruma göre belirlenen emoji ve metin içeren etiket.
 */
function _durumTxt(d){ if(d==='neg')return'🆘 Negatif'; if(d==='crit')return'⚠️ Kritik'; return'✅ Normal'; }

// ──────────────────────────────────────────
/**
 * IndexedDB'den stok ve aşı verilerini paralel olarak yükler, her stok kaydı için güncel stok miktarı, durum etiketi ve aşı olup olmadığı bilgilerini hesaplayarak 'stock' state'ine kaydeder. Hata oluşursa konsola yazar.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir Promise. Değer döndürmez.
 */
async function loadStock(){
  try {
    const [stk,vacs]=await Promise.all([idbGetAll('stok'),idbGetAll('vaccines')]);
    const stockData=stk.map(s=>{ const guncel=+(s.guncel_stok??s.baslangic_miktar??0); const durum=s.stok_durum==='tukendi'?'neg':s.stok_durum==='kritik'?'crit':'ok'; const isVaccine=(s.id||'').startsWith('STOK-AŞI-')||(vacs||[]).some(v=>v.stock_item_id===s.id); return{...s,guncel,durum,isVaccine}; });
    setState('stock', stockData);
  } catch(e){ console.error(e); }
}
/**
 * Belirtilen ID'ye sahip stok kaydını bulup arayüzü günceller ve stok modalını açar.
 * @param {string} id Aranan stok kaydının benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function openStk(id){
  setState('curStok', getState('stock').find(s=>s.id===id)||null);
  const curStk=getState('curStok'); if(!curStk) return;
  document.getElementById('m-stk-title').textContent='📦 '+curStk.urun_adi;
  document.getElementById('se-urun').value=curStk.urun_adi;
  document.getElementById('se-birim').textContent=curStk.birim||'?';
  g('se-mik').value=''; g('se-not').value='';
  openM('m-stk');
}
/**
 * Belirtilen stok ID'ye bağlı ilacı bulup RPC ile bağlantıyı kaydeder; ilaç bulunamazsa uyarı verir ve döner.
 * @param {string} stokId Bağlanacak stok öğesinin ID'si.
 * @param {HTMLElement} sel İlaç ID'sini içeren form elemanı (value özelliği ile).
 * @returns {Promise<void>} Bağlantı işleminin tamamlanması durumunda undefined döndürür.
 * @rpc link_drug_to_stock
 */
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

/**
 * Stok ekleme sayfasını açar ve ilaç tipini seçer.
 * @returns {Promise<void>} İşlemin tamamlanmasını bekleyen promise.
 */
async function openStokAdd() {
  openM('m-stok-add');
  await saTipSec('ilac');
}
/**
 * Seçili tip (ilac, sperma veya ekipman) göre modal alanlarını, başlığı ve form elemanlarını günceller;
 * seçili tip 'ilac' ise etken madde dropdown'ını ve stok kategorisini otomatik doldurur.
 * @param {string} tip Seçilecek kayıt tipi ('ilac', 'sperma' veya 'ekipman').
 * @returns {void} Fonksiyon bir değer döndürmez.
 * @tablo drug_classes (select)
 */
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
/**
 * Stok panelini görüntülemek için kaydırmak üzere açar ve panel içeriğini yükler.
 * @returns {void}
 */
function openStokPanel(){
  document.getElementById('stok-panel').style.transform='translateX(0)';
  loadStokPanel();
}
/**
 * Stok panelini sağa kaydırarak gizler.
 * @returns {void}
 */
function closeStokPanel(){
  document.getElementById('stok-panel').style.transform='translateX(100%)';
}
/**
 * Aktif stok sekmesini ayarlar, sekme düğmelerinin 'on' sınıfını günceller ve stok panelini yeniden yükler.
 * @param {*} tab - Aktif hale getirilecek stok sekmesinin tanımlayıcısı.
 * @param {Event} e - Tıklama olayını temsil eden olay nesnesi; hedef düğmeye 'on' sınıfı eklenir.
 * @returns {void}
 */
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
/**
 * Tanımlar panelini sağa kaydırarak gizler.
 * @returns {void}
 */
function closeTanimlarPanel(){
  document.getElementById('tanimlar-panel').style.transform='translateX(100%)';
}
/**
 * Tanimlar sekmesinin aktif olanı günceller ve tanimlar panelini yeniden yükler.
 * @param {Object} tab Aktif sekme nesnesi.
 * @param {Event} e Tıklama olayı nesnesi.
 * @returns {void}
 */
function setTanimlarTab(tab,e){
  _tanimlarTab=tab;
  document.querySelectorAll('#tanimlar-tabs .kat-btn').forEach(b=>b.classList.remove('on'));
  if(e&&e.target) e.target.classList.add('on');
  loadTanimlarPanel();
}

/**
 * Belirli bir sekme (hastalıklar, ilaçlar, kategoriler veya sablonlar) seçili olduğunda, ilgili veriyi yükleyip 'tanimlar-panel-body' elementini günceller.
 * @returns {Promise<void>} Veri yükleme işlemi tamamlandığında çözülür.
 */
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

/**
 * Tanim arama çubuğu HTML input elemanı döndürür.
 * @returns {string} Tanim arama çubuğu için HTML input elemanı.
 */
function _tanimSearchBar(){
  return `<input type="text" id="tanim-search" placeholder="🔍 Ara…" oninput="_tanimFiltrele(this.value)" style="width:100%;padding:9px 12px;border:1px solid var(--card3);border-radius:8px;margin-bottom:10px;font-size:.82rem;background:var(--card2);color:var(--ink);box-sizing:border-box">`;
}
/**
 * Sorgu metnine göre tanım kartlarını ve tanım gruplarını filtreleyerek gösterir veya gizler.
 * @param {string} q - Filtreleme için kullanılan arama sorgusu; boş sorgu tüm kartları ve grupları görünür yapar.
 * @returns {void} Değer döndürmez.
 */
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

/**
 * Hastalık tanımlarını veritabanından çeker, kategoriye göre gruplandırır ve aktif vaka sayıları ile birlikte HTML yapısı oluşturarak belirtilen elemana render eder.
 * @param {HTMLElement} el Render edilecek HTML elemanı.
 * @returns {void} Fonksiyon yan etkisi olarak elemanın içeriğini değiştirir, değer döndürmez.
 */
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

/**
 * Verilen tip parametresine göre varsayılan buton HTML yapısını döndürür.
 * @param {string} tip Butonun tıklanması tetikleyecek fonksiyona geçirilecek tip değeri.
 * @returns {string} Varsayılan butonun HTML kodunu içeren string.
 */
function _tanimVarsayilanBtn(tip){
  return `<div style="text-align:center;margin-top:14px">
    <button onclick="_tanimVarsayilan('${tip}')" style="background:none;border:none;color:var(--ink3);font-size:.72rem;cursor:pointer;text-decoration:underline">🔄 Varsayılana Dön</button>
  </div>`;
}

/**
 * Belirtilen tip (disease veya kategori) için düzenleme formunu temizleyip ilgili formu oluşturur.
 * @param {string} tip Formun oluşturulacağı kayıt tipini belirtir ('disease' veya 'kategori').
 * @param {string} id Düzenlenecek kaydı tanımlamak için kullanılan kimlik.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _tanimEditForm(tip, id){
  document.querySelectorAll('.tanim-edit-form').forEach(f=>f.remove());
  if(tip==='disease') _diseaseEditForm(id);
  else if(tip==='kategori') _kategoriEditForm(id);
}

/**
 * Belirtilen hastalık ID'si için düzenleme formunu oluşturur. Yeni kayıt ise formu panelin başına, mevcut kayıt ise ilgili alanın içine ekler.
 * @param {string} id Düzenlenecek hastalığın ID'si veya 'new' değeri.
 * @returns {void}
 */
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

/**
 * Hastalık kaydı oluşturma veya güncelleme işlemini gerçekleştirir.
 * @param {string} id Kayıt ID'si veya 'new' değeri (yeni kayıt için).
 * @returns {Promise<void>} İşlem tamamlandığında çözülür.
 */
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

/**
 * Kullanıcı onayı alındıktan sonra belirtilen hastalığı siler, bildirim gösterir ve tanımlar panelini yeniden yükler.
 * @param {number} id Silinecek hastalığın benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function _diseaseDelete(id){
  if(!confirm('Bu hastalığı silmek istediğinize emin misiniz?')) return;
  await rpcOptimistic('disease_sil',{p_id:id});
  toast('Hastalık silindi');
  loadTanimlarPanel();
}

/**
 * Belirtilen tip (drug_classes veya diğer tanımlar) için varsayılan değerleri yükler,
 * drug_classes tipinde kullanıcı doğrulaması yapar ve eksik öğeleri ekler,
 * diğer tiplerde ise mevcut özel tanımları koruyarak varsayılanları geri yükler.
 * @param {string} tip - İşlem yapılacak tanımların türü (örn: 'drug_classes', 'diseases', 'drugs', 'kategoriler').
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * İlaç sınıflarını (drug_classes), ürünleri (drug_products) ve stok kategorilerini çekerek
 * aktif etken maddeleri gruplar ve alt gruplara göre hiyerarşik bir yapıda HTML listesi oluşturur.
 * Boş veri durumunda uyarı mesajı gösterir, etken maddeler için düzenleme/silme ve yeni grup/alt grup ekleme
 * butonları ekler.
 * @param {HTMLElement} el Verilen HTML elemanına içeriği yazılacak hedef DOM elemanı.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Kullanıcıdan prompt ile yeni grup adı alıp RPC üzerinden ilaç grubu ekler; başarılıysa bildirim gösterip tanımlar panelini yeniler.
 * @returns {Promise<void>} İşlem tamamlanınca çözülen promise. Grup adı boşsa veya RPC hatası olursa sessizce döner.
 */
async function _dcAddGroup(){
  const name=prompt('Yeni grup adı:');
  if(!name||!name.trim()) return;
  try{
    await rpcOptimistic('drug_class_ekle',{p_group_name:name.trim(),p_class_name:'Genel',p_active_ingredient:'(tanımsız)'});
    toast('Grup eklendi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

/**
 * Kullanıcıdan yeni bir alt grup adı alarak mevcut gruba tanımsız aktif madde ile yeni bir alt grup ekler.
 * @param {string} grp Mevcut üst grup adı.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function _dcAddClass(grp){
  const name=prompt('Yeni alt grup adı:');
  if(!name||!name.trim()) return;
  try{
    await rpcOptimistic('drug_class_ekle',{p_group_name:grp,p_class_name:name.trim(),p_active_ingredient:'(tanımsız)'});
    toast('Alt grup eklendi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

/**
 * Kullanıcıdan yeni bir etken madde adı alarak ilaç sınıfına ekler, aynı isimli tanımsız kaydı siler ve paneli yeniler.
 * @param {string} grp Grup adı.
 * @param {string} cls Sınıf adı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Belirtilen seviyeye (grup veya alt grup) göre yeni bir isim girilerek ilgili kayıtları günceller.
 * @param {string} level Güncellenecek öğenin seviyesi ('group' veya 'class').
 * @param {string} grp Güncellenecek grubun mevcut adı.
 * @param {string} cls Güncellenecek alt grubun mevcut adı.
 * @returns {void} İşlem tamamlandığında bir değer döndürmez.
 */
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

/**
 * Belirtilen ID'ye sahip ilaç sınıfının etken madde adını kullanıcıdan alarak günceller.
 * @param {string} id Güncellenecek ilaç sınıfının benzersiz kimlik numarası.
 * @returns {void} İşlem başarılı veya başarısız olduğunda hiçbir değer döndürmez.
 */
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

/**
 * Belirtilen grup adına sahip ilaç sınıflarını ve bunlarla ilişkili tüm ilaç ürünlerini kontrol eder.
 * Eğer grup altında bağlı ilaç ürünü varsa hata mesajı gösterir ve işlemi iptal eder.
 * Aksi takdirde kullanıcıdan onay alır ve grubu ile altındaki tüm kayıtları siler.
 * @param {string} grp Silinmesi istenen grup adı.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirtilen grup ve sınıf adına sahip ilaç sınıflarını (etken maddeleri) kontrol eder;
 * bağlı preparat bulunursa hata gösterir, yoksa kullanıcı onayı alarak bu sınıfları ve
 * altındaki etken maddeleri siler.
 * @param {string} grp Silinmek istenen grup adı.
 * @param {string} cls Silinmek istenen sınıf adı.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirli bir drug_class_id'ye sahip etken maddeyi silmeden önce, bu maddeye bağlı preparat olup olmadığını kontrol eder.
 * Eğer bağlı preparat varsa kullanıcıyı uyarır ve silme işlemi iptal edilir.
 * Kullanıcı onay verirse etken maddeyi siler ve ilgili panelleri yeniler.
 * @param {number} id Silinmek istenen etken maddenin drug_class_id'si.
 * @returns {void} Fonksiyon her zaman bir değer döndürmez.
 */
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

/**
 * Stok kategorileri ve stok verilerini getirir, kategorileri siralayıp ilaç ve genel stok kategorilerini ayırarak HTML kartları oluşturur.
 * Eğer kategori tanımları yoksa boş durum mesajı gösterir.
 * @param {HTMLElement} el Kategori listesinin render edileceği DOM elementi.
 * @returns {void}
 */
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
  /**
   * Verilen kategori bilgisi, ürün sayısı ve renk kodu kullanılarak düzenlenebilir bir kart HTML yapısı oluşturur.
   * @param {Object} k Kategori nesnesi (ad, id, tip vb. özelliklere sahip).
   * @param {number} count Kategoriye ait ürün sayısı.
   * @param {string} renk Kartın sol kenarındaki vurgu rengi.
   * @returns {string} Oluşturulan HTML stringi.
   */
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

/**
 * İnternet bağlantısı varsa sunucudan şablon verilerini çeker, ardından yerel IndexedDB'den tüm tedavi şablonlarını, hastalık eşleşmelerini, kalemleri ve hastalık bilgilerini getirir.
 * Şablonları adlarına göre alfabetik sıralar, boş şablon yoksa uyarı gösterir ve varsa her şablon için detaylı bir HTML kartı oluşturur.
 * Oluşturulan HTML içeriğini verilen DOM elemanına yerleştirir.
 * @param {HTMLElement} el Şablon listesinin render edileceği DOM elemanı.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirtilen ID'ye sahip tedavi şablonunu silmek için onay ister ve silme işlemini gerçekleştirir.
 * @param {string} id Silinecek şablonun benzersiz kimlik numarası.
 * @returns {void} İşlem tamamlandığında veya hata oluştuğunda bir değer döndürmez.
 * @rpc tedavi_sablon_sil
 */
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

/**
 * Belirtilen şablon ID'si verildiğinde şablon düzenleme arayüzünü açar, yoksa yeni şablon oluşturma arayüzünü açar.
 * İlaç önbelleğini yükler, hastalık ve şablon eşleştirmelerini getirir, şablon kalemlerini filtreler ve
 * planlanan günleri ile ilaç detaylarını (doz, stok, uygulama yolu vb.) içeren bir veri yapısı oluşturur.
 * Sonuç olarak şablon düzenleme durumunu (_sablonEdit) günceller ve ilgili arayüzü (_renderSablonBuilder) yeniden çizer.
 * @param {string|number|null} id Düzenlenecek şablonun ID'si veya yeni şablon oluşturulacaksa null.
 * @returns {void} Fonksiyon bir değer döndürmez, sadece yan etkiler (DOM güncelleme, global değişken atama) yapar.
 */
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

/**
 * Verilen ilaç kimliği (drug_product_id veya stok_id) ile eşleşen ilacın adını döndürür.
 * @param {Object} k İlaç kimliği içeren nesne (drug_product_id veya stok_id özelliği).
 * @returns {string} Bulunan ilacın adı veya bulunamazsa 'İlaç' stringi.
 */
function _sablonDrugName(k){
  const d = (_drugsCache||[]).find(x => x.id === (k.drug_product_id || k.stok_id));
  return d?.name || 'İlaç';
}

/**
 * Şablon düzenleme formunun gövdesini (hastalık seçim kutuları, gün/seans planı, tohumlama girişleri ve kaydet/iptal düğmeleri) oluşturup 'm-sablon-body' öğesinin içine render eder.
 * @returns {void}
 */
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

/**
 * Belirtilen hastalık ID'sini şablonun hastalık listesinde aktif veya pasif olarak değiştirir.
 * @param {string} id Etkilenmesi istenen hastalığın ID'si.
 * @param {boolean} checked Hastalığın aktif edip edilmeyeceğini belirten durum.
 * @returns {void}
 */
function sablonDisToggle(id, checked){
  _syncSablonAd();
  if(checked){ if(!_sablonEdit.disease_ids.includes(id)) _sablonEdit.disease_ids.push(id); }
  else { _sablonEdit.disease_ids = _sablonEdit.disease_ids.filter(x=>x!==id); }
}

/**
 * 'sb-ad' ve 'sb-aciklama' DOM elementlerinden değerleri alarak _sablonEdit nesnesine atar.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _syncSablonAd(){
  const ad = document.getElementById('sb-ad'); const ac = document.getElementById('sb-aciklama');
  if(ad) _sablonEdit.ad = ad.value;
  if(ac) _sablonEdit.aciklama = ac.value;
}

/**
 * Şablon günlerine sıfırdan başlayarak en büyük offset değerini bulur, bu değere 1 ekleyerek yeni bir gün ekler ve arayüzü yeniden render eder.
 * @returns {void}
 */
function sablonGunEkle(){
  _syncSablonAd();
  const sonOfset = _sablonEdit.gunler.reduce((max, gun) => Math.max(max, gun.offset), -1);
  _sablonEdit.gunler.push({ offset:sonOfset+1, kalemler:[] });
  _renderSablonBuilder();
}
/**
 * Belirtilen indeksdeki gün kaydını siler, ilgili tohumlama planını yoksa sıfırlar,
 * gün listesini günceller ve arayüzü yeniden render eder.
 * @param {number} gi Silinecek günün dizideki indeks numarası.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function sablonGunSil(gi){ _syncSablonAd(); const silinen=_sablonEdit.gunler[+gi]; if(_sablonEdit.tohumlama_plani?.gun_ofset===silinen?.offset) _sablonEdit.tohumlama_plani=null; _sablonEdit.gunler.splice(+gi,1); if(!_sablonEdit.gunler.length) _sablonEdit.gunler=[{offset:0,kalemler:[]}]; _renderSablonBuilder(); }
/**
 * Belirtilen gün indeksindeki günün ofset değerini günceller, geçerliliğini kontrol eder,
 * tekrarlayan ofsetleri önler ve ofsetlere göre günleri sıralar.
 * @param {string} gi Güncellenecek günün dizideki indeksini temsil eden string.
 * @param {number|string} value Yeni ofset değeri olarak kullanılacak sayısal değer.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * Belirtilen gi parametresine sahip sablonun gövde elemanını gösterir veya gizler.
 * @param {string} gi Sablonun kimlik numarası.
 * @returns {void}
 */
function sablonGunToggle(gi){
  const body=document.getElementById('sablon-gun-body-'+gi); if(!body) return;
  body.style.display = body.style.display==='none' ? 'block' : 'none';
}
/**
 * Belirtilen gün ve kalemden şablon seansını siler.
 * @param {number} gi Silinecek seansın bulunduğu gün dizisi indeksi.
 * @param {number} ki Silinecek kalemin bulunduğu kalemler dizisi indeksi.
 * @returns {void}
 */
function sablonSeansSil(gi,ki){ _syncSablonAd(); _sablonEdit.gunler[+gi].kalemler.splice(+ki,1); _renderSablonBuilder(); }

/**
 * Belirtilen gün (gi) için sablon seans formunu oluşturur. İlaç gruplarını ve stok durumlarını listeler, saat seçimi ve doz girişi alanlarını içerir.
 * @param {string} gi Güne ait seans formu oluşturulacak gün bilgisi.
 * @returns {void}
 */
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

/**
 * Belirtilen saati 'sbs-time' ID'li elemanın değerine atar.
 * @param {string} t Atanacak saat değeri.
 * @returns {void} Hiçbir değer döndürmez.
 */
function sablonSaatChip(t){ const i=document.getElementById('sbs-time'); if(i) i.value=t; }
/**
 * Şablon oluşturucuda seçilen güne tohumlama planı ekler; şablon adını senkronize eder, seçilen günün ofseti ve '08:00' planlı saatiyle tohumlama planını ayarlar ve şablon oluşturucuyu yeniden render eder.
 * @param {number|string} gi - Tohumlama planının ekleneceği günün şablon düzenleyicideki indeksi.
 * @returns {void} Döndürme değeri yok.
 */
function sablonTohumlamaGunEkle(gi){ _syncSablonAd(); const gun=_sablonEdit.gunler[+gi]; _sablonEdit.tohumlama_plani={gun_ofset:gun.offset,planned_time:'08:00'}; _renderSablonBuilder(); }
/**
 * Şablonun tohumlama planını sıfırlar ve şablon oluşturucu arayüzünü yeniden render eder.
 * @returns {void}
 */
function sablonTohumlamaSil(){ _syncSablonAd(); _sablonEdit.tohumlama_plani=null; _renderSablonBuilder(); }
/**
 * Verilen değeri tohumlama planına kaydederek planı günceller.
 * @param {any} value - Planlanan zaman değeri.
 * @returns {void}
 */
function sablonTohumlamaSaat(value){ if(value) _sablonEdit.tohumlama_plani={..._sablonEdit.tohumlama_plani,planned_time:value}; }
/**
 * Sablon seans formunu yok eder ve referansı temizler.
 * @returns {void}
 */
function sablonSeansVazgec(){ if(_sablonSeansForm){ _sablonSeansForm.remove(); _sablonSeansForm=null; } }

/**
 * Sablon seans formu için seçilen ilaçların doz, birim ve uygulama yolu bilgilerini alarak
 * seans planına ekler. Geçersiz doz veya eksik birim girişleri durumunda kullanıcıya hata mesajı gösterir.
 * @param {number} gi Seçilen günün indeks numarası.
 * @returns {void}
 */
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

/**
 * Tedavi şablonu düzenleme formundaki verileri doğrulayıp `tedavi_sablon_kaydet` RPC'si üzerinden kaydeder, ilgili tabloları çeker ve tanımlar panelini yeniler. Doğrulama hatası veya RPC hatasında kullanıcıya hata bildirimi gösterir.
 * @returns {Promise<void>} Kayıt işleminin tamamlanmasını belirten promise; değer döndürmez.
 * @rpc tedavi_sablon_kaydet
 */
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

/**
 * Yeni bir kategori oluşturuluyorsa boş, yoksa veritabanından verileri çekerek doldurulmuş bir kategori düzenleme formu HTML'ini oluşturur ve ilgili DOM elementine ekler.
 * @param {string} id Düzenlenecek kategorinin ID'si veya 'new' değeri.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Kategori adı ve tipi alanlarından veri okuyarak yeni bir kategori ekler veya mevcut birini günceller.
 * @param {string} id Yeni kayıt ise 'new' değeri, güncelleme ise kategori ID'si.
 * @returns {void} İşlem sonucu veya hata durumunda sessizce döner.
 */
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

/**
 * Kullanıcı onayı alındıktan sonra belirtilen kategoriyi siler, başarılı olursa bildirim gösterir ve tanımlar panelini yeniden yükler.
 * @param {string} id Silinecek kategorinin ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function _kategoriDelete(id){
  if(!confirm('Bu kategoriyi silmek istediğinize emin misiniz?')) return;
  try{
    await rpcOptimistic('kategori_sil',{p_id:id});
    toast('Kategori silindi');
    loadTanimlarPanel();
  }catch(e){/* rpcOptimistic toast bastı — sessiz geç */}
}

let _ilacKatAdlari=null;
/**
 * Stok kategorilerinden tip'i 'ilac' olanları filtreleyip adlarını döndürür.
 * @returns {Array} İlaç kategorilerinin adlarından oluşan dizi.
 */
async function _getIlacKatAdlari(){
  if(_ilacKatAdlari) return _ilacKatAdlari;
  const kats=(await idbGetAll('stok_kategorileri'))||[];
  _ilacKatAdlari=kats.filter(k=>k.tip==='ilac').map(k=>k.ad);
  return _ilacKatAdlari;
}
/**
 * Verilen ilacAdlari dizisine göre filtreleme seçeneklerini döndürür.
 * @param {Array} ilacAdlari Filtreleme yapılacak ilac kategorileri listesi.
 * @returns {Object} 'tumu', 'ilac', 'asi', 'sperma' ve 'diger' anahtarlarını içeren nesne.
 */
function _buildTabFilter(ilacAdlari){
  return {
    /**
     * Her zaman `true` döndürür.
     * @returns {boolean} Her zaman `true` değeri.
     */
    tumu:()=>true,
    /**
     * Verilen ilac nesnesinin kategorisi, ilacAdlari dizisinde var mı kontrol eder.
     * @param {Object} s - Kategori bilgisini içeren ilac nesnesi.
     * @returns {boolean} İlacın kategorisinin ilacAdlari dizisinde bulunup bulunmadığını gösteren boolean değer.
     */
    ilac:s=>ilacAdlari.includes(s.kategori),
    /**
     * Verilen nesnin `isVaccine` özelliği true ise, `kategori` özelliği 'Aşı' veya 'Asi' ise true döndürür.
     * @param {Object} s Kontrol edilecek nesne.
     * @returns {Boolean} Nesnin aşı kategorisinde olup olmadığını belirten boolean değer.
     */
    asi:s=>s.isVaccine||s.kategori==='Aşı'||s.kategori==='Asi',
    /**
     * Verilen nesnenin 'kategori' özelliğinin değeri 'Sperma' ise true, değilse false döndürür.
     * @param {Object} s Kontrol edilecek nesne.
     * @returns {boolean} Nesnenin kategorisi 'Sperma' ise true, aksi halde false.
     */
    sperma:s=>s.kategori==='Sperma',
    /**
     * Verilen kaydın 'Diğer' kategoriye ait olup olmadığını belirler; kategori ilaç listesinde yoksa, 'Aşı', 'Asi' veya 'Sperma' kategorilerinden biri değilse ve aşı kaydı değilse true döndürür.
     * @param {Object} s - Kontrol edilecek kayıt; kategori ve isVaccine özelliklerini içerir.
     * @param {string} s.kategori - Kaydın kategori adı.
     * @param {boolean} s.isVaccine - Kaydın aşı olup olmadığını belirtir.
     * @returns {boolean} Kayıt 'Diğer' kategoriye uygunsa true, aksi halde false.
     */
    diger:s=>!ilacAdlari.includes(s.kategori)&&s.kategori!=='Aşı'&&s.kategori!=='Asi'&&s.kategori!=='Sperma'&&!s.isVaccine
  };
}

/**
 * Stok panelini yükler: yükleniyor göstergesi gösterir, stok ve ilaç verilerini getirir,
 * sekmeye ve kategoriye göre gruplandırılmış stok kartlarını, durum çubuklarını ve
 * işlem butonlarını render eder; ayrıca aşı (vaccine) kartlarını protokol ve stok
 * bilgileriyle birlikte panele ekler.
 * @returns {Promise<void>} Panel HTML'i DOM'a yazıldığında çözülen promise.
 */
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
      /**
       * Kategorisi 'Sperma' olan satırları süzen bir filtre fonksiyonudur; adı '🐂 Sperma' olan filtre tanımı.
       * @param {Object} s - Filtrelenecek satır kaydı; 'kategori' özelliği kontrol edilir.
       * @returns {boolean} Satırın kategorisi 'Sperma' ise true, değilse false.
       */
      {ad:'🐂 Sperma',         filtre:s=>s.kategori==='Sperma'},
      ...ilacKats.map(k=>({
        ad:'💊 '+k.ad,
        /**
         * Verilen öğenin kategorisi, k adlı kategorinin adıyla eşleşiyorsa true döndürür.
         * @param {Object} s - Kategori bilgisi içeren öğe; 'kategori' özelliği karşılaştırılır.
         * @returns {boolean} Öğenin kategorisi kategori adına eşitse true, değilse false.
         */
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
    /**
     * Verilen ID'ye sahip disney karakterinin adını bulur ve bulunamazsa boş string döndürür.
     * @param {string} id Aranan karakterin ID'si.
     * @returns {string} Bulunan karakterin adı veya karakter bulunamazsa boş string.
     */
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

/**
 * Belirtilen stok ID'sine sahip stok kaydını bulur ve ilgili modal penceresini doldurarak açar.
 * Eğer stok kaydı bulunamazsa veya modal elementi mevcut değilse işlemi iptal eder.
 * @param {string} stokId - Açılacak stok kaydının benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Detay modalında düzenlenen stok kaydını doğrular, RPC ile günceller ve stok panelini yeniler.
 * @returns {Promise<void>} Güncelleme işleminin tamamlanmasını bekleyen promise; ürün adı boşsa veya hata oluşursa güncelleme yapılmadan erken döner.
 * @rpc stok_guncelle
 */
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

/**
 * Stok düzeltme formundaki yeni miktarı kaydeder; geçersiz miktar girişini reddeder, RPC ile stoğu düzeltir, ilgili tabloları yeniden çeker ve arayüzü günceller.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir promise; hiçbir değer döndürmez.
 * @rpc stok_duzelt
 */
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

/**
 * Tüm stok hareketlerini tarih sırasına göre (yeniden eskiye) getirip modal içinde listeler; iptal edilen tedavi hareketleri için iade kaydıyla birlikte üstü çizili şekilde gösterir, veri çekme hatasında tekrar deneme butonu içeren bir hata mesajı görüntüler.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir Promise; anlamlı bir değer döndürmez.
 */
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

/**
 * 'stok-panel-body-OLD' ID'li elemanın içeriğini doldurarak eski stok panelini oluşturur.
 * Stok kayıtlarını kategori gruplarına (Sağlık, Yem) ve alt kategorilere göre filtreleyerek
 * HTML yapısını oluşturur. Stok miktarını başlangıç miktarına göre hesaplayarak
 * durum barlarını renklendirir ve her ürün için "Stok Ekle" ve "Hareketler" butonlarını ekler.
 * Eğer 'Yem' grubu için stok bulunamazsa ilgili bölümü gri tonlarda gösterir.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function loadStokPanel_DEPRECATED(){
  const el=document.getElementById('stok-panel-body-OLD'); if(!el) return;
  const GRUPLAR=[
    {baslik:'💊 Sağlık',ikon:'💊',alt:[
      {ad:'Sperma',   filtre:s=>s.kategori==='Sperma'},
      /**
       * Verilen nesnenin kategorisi belirli bir ilaç listesinde (İlaç, Antibiyotik, NSAID, vb.) olup olmadığını kontrol eder.
       * @param {Object} s Kontrol edilecek nesne.
       * @returns {Boolean} Nesnenin kategorisinin listede olup olmadığına göre true veya false.
       */
      {ad:'İlaç',     filtre:s=>['İlaç','Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç'].includes(s.kategori)},
      /**
       * Verilen nesne için kategori değeri 'Ekipman', 'Sarf' veya 'Malzeme' ise nesneyi filtrelemeye uygun olarak işaretler.
       * @param {Object} s Filtrelenmesi istenen nesne.
       * @returns {Boolean} Nesnenin kategori değeri geçerli kategorilerden biri ise true, değilse false.
       */
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
      el.innerHTML='<div style="text-align:center;padding:12px;color:var(--ink3);font-size:.78rem">📦 Henüz stok ürünü eklenmemiş<br><button class="sh-link" data-action="stok-add-open" style="margin-top:6px;display:block;margin:6px auto 0">İlk ürünü ekle →</button></div>';
      return;
    }
    const gruplar={
      'Sperma':getState('stock').filter(s=>s.kategori==='Sperma'||(s.urun_adi||'').toLowerCase().includes('sperma')||(s.urun_adi||'').toLowerCase().includes('doz')),
      'İlaç':getState('stock').filter(s=>s.kategori==='İlaç'||(!s.kategori&&!(s.urun_adi||'').toLowerCase().includes('sperma')&&!(s.urun_adi||'').toLowerCase().includes('ekipman'))),
      'Ekipman':getState('stock').filter(s=>s.kategori==='Ekipman'||(s.urun_adi||'').toLowerCase().includes('ekipman')),
    };
    /**
     * Bir stok kartını, ürün adı, eşik bilgisi, güncel miktar, birim, durum rengine göre ilerleme çubuğu ve işlem butonları içeren HTML kartı olarak oluşturur.
     * @param {Object} s - Stok kaydı verileri.
     * @param {string} s.urun_adi - Ürün adı.
     * @param {number} s.esik - Stok eşiği; 0'dan büyükse ilerleme yüzdesi hesaplanır, değilse %100 gösterilir.
     * @param {number} s.guncel - Güncel stok miktarı.
     * @param {number|string} s.baslangic_miktar - Başlangıç miktarı; yüzdesel doluluk hesabında payda olarak kullanılır.
     * @param {string} s.durum - Stok durumu; kart renkleri _durumClr fonksiyonuyla belirlenir.
     * @param {string} s.birim - Miktar birimi ('adet' ise tam sayı, değilse ondalıklı gösterilir).
     * @param {string} s.id - Stok kaydının kimliği; butonların onclick çağrılarında kullanılır.
     * @returns {string} Stok kartını temsil eden HTML dizesi.
     */
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
/**
 * Belirtilen stok ID'sine ait stok hareketlerini getirir, iptal edilmişleri filtreler,
 * tarih sırasına göre sıralar ve toplam kullanılan miktarı hesaplayarak
 * başlangıç, kullanılan ve kalan miktar bilgilerini içeren bir modal pencere oluşturur.
 * @param {string} stokId - Stok hareketlerinin sorgulanacağı stokun ID'si.
 * @returns {void} Fonksiyon bir değer döndürmez, DOM'a modal element ekler.
 */
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
/**
 * Raporlar sekmesinin içeriğini yükler; hayvan, tohumlama, vaka, hastalık, doğum ve stok verilerini IndexedDB'den paralel çekerek istatistik kartları, ırk dağılımı, hastalık kategorileri ve stok durumu bölümlerini oluşturur.
 * 'raporlar-body' elementi bulunamazsa işlem yapmaz; kaydırma konumu korunur, hata durumunda hata mesajı gösterilir. Çevrimdışıysa verilerin yerel cache'ten geldiğine dair uyarı ekler.
 * @returns {Promise<void>} Rapor görünümü oluşturulduktan sonra tamamlanan bir Promise.
 */
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

    /**
     * Bir veri kartı HTML elemanı oluşturur. Kartın başlık değerini, alt başlığını,
     * gösterim rengini ve opsiyonel bir alt metni içerir.
     * @param {string} label Kartın ana başlık metni.
     * @param {string} val Kartın ana değer metni.
     * @param {string} [sub=''] Opsiyonel alt metin. Varsayılan olarak boş string.
     * @param {string} [clr='var(--green)'] Değerin gösterim rengi için CSS değişkeni. Varsayılan olarak yeşil.
     * @returns {string} Stilize edilmiş bir HTML div elemanı içeren şablon stringi.
     */
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
/**
 * IndexedDB'deki hayvanlardan durumu 'Aktif' olmayanları (çıkanları) filtreler,
 * çıkış tarihine göre azalan sıralar ve 'cikanlar-body' elementine HTML olarak render eder.
 * Kayıt yoksa boş durum mesajı, hata oluşursa hata mesajı gösterir.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir Promise.
 */
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
/**
 * Geçerli görev detayını tamamlar: tipi ve açık alt görevlerine göre uygun tamamlama akışını (planlı tohumlama, stok seçimi, grup tamamlama veya doğrudan RPC) yürütür.
 * @returns {Promise<void>} Tamamlama işlemi bittiğinde çözülen promise; ancak `_curTaskDet` yoksa veya görev tipi 'TOHUMLAMA_PLANLI' ise erken döner.
 */
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
/**
 * Görev detayına göre uygun stokları filtreleyerek stok seçim arayüzünü oluşturur.
 * Stok bulunamazsa kullanıcıya bildirim gösterir ve fonksiyonu sonlandırır.
 * Arayüzde stok, doz, birim ve uygulama rotası seçimi içeren bir form oluşturur.
 * @param {Object} gorev Görev detaylarını içeren nesne (etken_kod, aciklama, hayvan_id vb. alanları içerir).
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @olay change
 */
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

  const stokOpts = ilaclar.map(s => `<option value="${s.id}" data-dp="${s.drug_product_id||''}">${esc(s.urun_adi)} (${s.birim||''})</option>`).join('');
  const rotaOpts = ['IM','IV','SC','PO','Topikal','Intrauterin','Meme içi'].map(r => `<option value="${r}">${r}</option>`).join('');
  const _dozBtn = _dozHintBtnHtml('pu-doz', '', gorev.hayvan_id || '', 'pu-stok');

  mini.innerHTML = `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px))">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:4px">💊 Görev Tamamlama — Stok Seç</div>
    <div style="font-size:.75rem;color:var(--ink3);margin-bottom:12px">${esc(gorev.aciklama||'')} · ${esc(gorev.etken_kod)}</div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Stok</label>
    <select id="pu-stok" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;font-size:.8rem">${stokOpts}</select>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Doz</label><div style="display:flex;gap:4px"><input id="pu-doz" type="number" step="0.1" value="10" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem;flex:1;min-width:0">${_dozBtn}</div></div>
      <div style="flex:1"><label style="font-size:.7rem;font-weight:600">Birim</label><input id="pu-birim" value="ml" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);font-size:.8rem"></div>
    </div>
    <label style="font-size:.7rem;font-weight:600;display:block;margin-bottom:4px">Rota</label>
    <select id="pu-rota" style="width:100%;padding:8px;border-radius:8px;border:1px solid var(--border);margin-bottom:12px;font-size:.8rem">${rotaOpts}</select>
    <button id="pu-kaydet-btn" data-padok="${escAttr(gorev.padok_hedef||'')}" onclick="_gorevStokTamamlaSubmit('${gorev.id}','${gorev.hayvan_id||''}',this.dataset.padok)" class="btn" style="width:100%;padding:10px;font-weight:700">Tamamla</button>
  </div>`;
  document.body.appendChild(mini);
  if (ilaclar[0]) _puDozPrefill(ilaclar[0].id);
  document.getElementById('pu-stok')?.addEventListener('change', e => _puDozPrefill(e.target.value));
}

/**
 * Hızlı uygulama RPC'sini çağırıp görevi tamamlar; çift gönderimi engeller, UI'ı güncelleyerek görev listesi ve panoyu yeniler.
 * @param {string|number} gorevId - Tamamlanacak görevin kimliği.
 * @param {string|number} hayvanId - Uygulamanın yapılacağı hayvanın kimliği.
 * @param {number|null} padokHedef - Görevin padok hedefi; verilmezse null gönderilir.
 * @returns {Promise<void>} Herhangi bir değer döndürmez; sonuçlar toast bildirimleriyle yansıtılır.
 * @rpc gorev_tamamla, hizli_uygulama
 */
async function _gorevStokTamamlaSubmit(gorevId, hayvanId, padokHedef){
  const kaydetBtn=document.getElementById('pu-kaydet-btn');
  if(kaydetBtn&&kaydetBtn.disabled) return; // çift-gönderim: rpc uçuşta ikinci tık yok sayılır
  const stok = document.getElementById('pu-stok')?.value;
  const doz = parseFloat(document.getElementById('pu-doz')?.value);
  const birim = document.getElementById('pu-birim')?.value;
  const rota = document.getElementById('pu-rota')?.value;
  if (!stok || !doz || !birim) { toast('Stok ve doz alanlarını doldurun', true); return; }
  if(kaydetBtn){kaydetBtn.disabled=true;kaydetBtn.textContent='İşleniyor…';}

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
  finally {
    // sheet remove edilmişse buton kopuktur; tekrar aktif etmek zararsız
    if(kaydetBtn){kaydetBtn.disabled=false;kaydetBtn.textContent='Tamamla';}
  }
}
/**
 * Belirli bir admin için tedavi ilac uygulandı/uygulanmadı durumunu değiştirir, ilgili ikon ve etiket rengini metnini günceller.
 * @param {string} adminId Admin kimliği.
 * @param {HTMLElement} el İlacın uygulandığı veya uygulanmadığı durumu temsil eden DOM elementi.
 * @returns {void}
 */
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

/**
 * "Uygulanmadı" işaretli ilaçlar varsa onay sorup stok iadesiyle tedavi gününü tamamlar, yoksa doğrudan tamamlar.
 * @returns {Promise<void>} İşlem tamamlanınca çözülen bir Promise.
 */
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

/**
 * Tedavi günü işlemini gerçekleştirir: belirtilen ilaçları iade eder, görevi tamamlayarak kayıtları günceller,
 * kullanıcıya işlem sonucu bildirir ve arayüzü yeniler.
 * @param {Array} uygulanmadiIds İade edilecek ilaçların ID'lerinden oluşan dizi.
 * @returns {void} İşlem sonucu toast mesajı ile bildirilir, fonksiyon bir değer döndürmez.
 * @rpc gorev_tamamla, treatment_day_tamamla
 */
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
/**
 * 'td-asi-form' elementini görünür kılar ve 'td-asi-ac-btn' elementini gizler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function asiFormAc(){
  document.getElementById('td-asi-form').style.display='block';
  document.getElementById('td-asi-ac-btn').style.display='none';
}
/**
 * Aktif görev detayına göre aşı uygulaması yapar ve görevi tamamlar; görev tipine göre
 * ilgili RPC'yi çağırır (planlı aşı, ileri gebe aşısı ya da rapel/hatırlatma), UI'ı günceller,
 * ilgili tabloları yeniden çeker ve varsa bir sonraki rapel tarihini toast ile bildirir.
 * @returns {Promise<void>} İşlem sonunda değer döndürmez.
 * @rpc add_vaccination, asi_planli_tamamla, gorev_tamamla, ileri_gebe_asi_tamamla
 */
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
/**
 * Detayı açık olan görevin rapel tarihini formdaki değerle günceller.
 * Tarih seçilmemişse kullanıcıyı uyarır; başarılı olduğunda görev listesini yeniden yükler.
 * @returns {Promise<void>} İşlem tamamlanandığında resolve olur; herhangi bir değer döndürmez.
 * @rpc gorev_guncelle
 */
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
/**
 * Geçerli görev detayı varsa görev düzenleme formunu açar; açıklama, hedef tarih ve görev tipi alanlarını mevcut görev değerleriyle doldurur.
 * @returns {Promise<void>} Görev detayı yoksa işlem yapılmadan geri döner.
 */
async function openTaskEdit(){
  if(!_curTaskDet) return;
  const t=_curTaskDet;
  document.getElementById('te-desc').value=t.aciklama||'';
  document.getElementById('te-tarih').value=t.hedef_tarih||'';
  document.getElementById('te-tip').value=t.gorev_tipi||'MANUEL';
  openM('m-task-edit');
}
/**
 * Seçili görevi iptal eder, görev loguna iptal bilgisi ekler, bağlı alt görevleri de iptal durumuna geçirir,
 * kullanıcıya iptal bildirimi gösterir ve ilgili arayüzleri günceller.
 * @returns {Promise<void>} İşlem tamamlandığında boş bir Promise döndürür.
 */
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
/**
 * Verilen görev log kaydı ID'sine sahip görev detayını getirir, ilgili hayvan bilgilerini doldurur, meta bilgilerini (hedef tarih, tamamlanma tarihi, görev tipi) ve rapel durumunu günceller. Eğer görev 7 günden eskiyse veya rapel yapılmışsa geri alma butonunu devre dışı bırakır.
 * @param {string} id Görev log kaydı için aranacak ID.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
  // L4-W2: tek motor — görev tamamlaması L2'ye bağlandı (hedef: gorev_tamamla
  // tx'i; eski gorev_geri_al RPC'si UI'dan söküldü, DB'de kalır).
  if(!_curTaskDet) return;
  const t=_curTaskDet;
  idbGetAll('islem_log').then(liste=>{
    // geri_alindi guard'ı SEÇİCİ find'ın içinde (L4-W2 review-1: ölü guard düzeltmesi)
    const islem=liste.find(l=>l.tip==='GOREV_TAMAMLA'
      &&(l.ref_id===t.id||(l.snapshot&&l.snapshot.id===t.id))
      &&(!l.durum||l.durum!=='geri_alindi'));
    if(islem){ dgGeriAlFromEntry(islem); return; }
    // islem_log kaydı yoksa (eski kayıt) hedef doğrudan görev satırı
    dgGeriAlAkisi({tablo:'gorev_log',pk:t.id},'satir',{olayEtiketi:'Görev',zaman:t.tamamlanma_tarihi||'',kim:''});
  }).catch(e=>{ toast('⚠️ Görev geçmişi okunamadı: '+(e&&e.message||'IDB hatası'), true); });
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

/**
 * İlaç cache'ini hazırlar: IDB'den ilaç sınıfları, ürünleri ve stok verilerini çeker,
 * bunları birleştirerek güncel stok miktarları, doz bilgileri ve birimlerle zenginleştirilmiş
 * bir dizi oluşturur. Eğer cache boşsa ve çevrimdışı ise mevcut veriyi kullanır.
 * Ayrıca drug_product_id'si olmayan ancak geçerli kategorilere sahip eski stok kalemlerini
 * fallback olarak ekler ve sonucu güncel stok miktarına göre azalan sırada sıralar.
 * @returns {Promise<Array>} İlaç bilgilerini içeren dizi.
 */
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
        // Dozaj helperi (20260909100000 migration): standart doz + konsantrasyon
        std_dose:         dp.std_dose ?? null,
        std_dose_unit:    dp.std_dose_unit || null,
        concentration:    dp.concentration ?? null,
        concentration_unit: dp.concentration_unit || null,
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

/**
 * Belirli bir hayvanın tüm vaka kayıtlarını getirir, en yeni olanı öne getirerek sıralar ve
 * her vakanın durumuna göre (aktif/kapalı) renkli bir liste elemanı olarak HTML stringi döndürür.
 * @param {string} animalId - Vaka kayıtlarının filtrelenmesi için kullanılacak hayvanın kimliği.
 * @returns {string} Hayvanın vakalarını içeren HTML liste elemanlarından oluşan bir string.
 */
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

/**
 * Verilen vaka ID'sine sahip vakanın detaylarını getirir, ilgili verileri (hayvan, hastalık, notlar vb.)
 * DOM elementlerine yerleştirir, durum etiketlerini oluşturur, geri alma butonunun görünürlüğünü kontrol eder
 * ve tedavi zaman çizelgesini render eder.
 * @param {string} caseId - Detayları gösterilecek vakanın benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
  ertelemeBtnGuncelle();   // E6: erteleme/kaydırma butonları online-only görünürlük

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
      // L4-W2: tek motor — entry çözücüye gider (a+b modalı yok)
      globalThis._cdGeriAlEntry = vakaIslem;
      geriAlBtn.style.display = 'block';
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

/**
 * Verilen zaman damgasını Türkçe biçimde "gg.aa ss:dd" şeklinde biçimlendirir; boş değerlerde boş string döndürür.
 * @param {number|string|Date} ts - Biçimlendirilecek zaman damgası (boş/falsy ise boş string döner).
 * @returns {string} "gg.aa ss:dd" biçiminde Türkçe tarih ve saat, ts boşsa boş string.
 */
function fmtGunSaat(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  return d.toLocaleDateString('tr-TR',{day:'2-digit',month:'2-digit'}) + ' ' +
         d.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'});
}

/**
 * Verilen vakanın tedavi zaman çizelgesini (#cd-timeline) asenkron olarak oluşturur.
 * İlaç günlerini, saatli seans planlarını ve sanal planlı tohumlama günlerini birleştirip
 * akordeon yapısında render eder; açık akordeonları ve scroll konumunu yeniden render'da korur.
 * Aktif vakalarda önceki gün tamamlanmadan sonraki gün kilitlenir ve ilerleme çubuğu gösterilir.
 * @param {string} caseId - Zaman çizelgesi oluşturulacak vakanın kimliği.
 * @returns {Promise<void>} Render tamamlananda çözülen bir promise; hata durumunda konteynere hata mesajı yazar.
 */
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

/**
 * Belirtilen gün ID'si için tedavi saat ayarlama modalını açar, mevcut saati (varsa) ön yükler ve modalın dışına tıklanırsa kapatılmasını sağlar.
 * @param {string} dayId Tedavi saatini ayarlamak istenen günün ID'si.
 * @param {string} [currentTime] Modal açılırken ön yüklenmek istenen saat değeri (varsa).
 * @returns {void}
 */
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

/**
 * Belirtilen gün ID'si için saat değerini alıp günceller, modalı kaldırır ve tabloyu yeniler.
 * @param {string} dayId Güncellenecek günün ID'si.
 * @returns {Promise<void>} İşlem tamamlandığında boş bir Promise döndürür.
 * @rpc update_treatment_time
 */
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

/**
 * Belirtilen gün ID'si ile tedavi gününü tamamlayarak işlemi gerçekleştirir.
 * @param {string} dayId Tamamlanacak tedavi gününün ID'si.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda çözülür.
 * @rpc treatment_day_tamamla
 */
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

/**
 * Tedavi notu modal penceresini açar, mevcut notu doldurur ve kaydetme/iptal butonlarını gösterir.
 * @param {string} dayId Kaydedilecek notun hangi gün (day) için olduğunu belirten kimlik.
 * @param {string} [mevcutNot] Modal açılırken textarea içinde varsayılan olarak gösterilecek mevcut not metni.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirtilen gün ID'si için kaydedilmiş notu günceller, modalı kaldırır ve ilgili tabloları çeker.
 * @param {string} dayId Güncellenecek günün ID'si.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda çözülür.
 * @rpc treatment_day_not_guncelle
 */
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

/**
 * Belirli bir güne ait akordeon (açılır/kapanır) öğesinin açık/kapalı durumunu tersine çevirir.
 * @param {string} dayId - Akordeon öğesinin kimliğini oluşturmak için kullanılan gün kimliği ('acc-' önekiyle birleştirilir).
 * @returns {void} Hiçbir değer döndürmez; eşleşen öğe bulunamazsa işlem yapılmadan çıkar.
 */
function cdAccToggle(dayId) {
  const acc = document.getElementById('acc-' + dayId);
  if (!acc) return;
  const isOpen = acc.classList.contains('open');
  acc.classList.toggle('open', !isOpen);
}

/**
 * Belirtilen gün ID'sine sahip ilaç kaydının Base64 kodlanmış notunu okuyup,
 * bu notu mevcut metin formatına çevirerek caseDayNotAc fonksiyonuna geçirir.
 * @param {string} dayId - İlaç kaydının gün ID'si.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function caseDayNotAcById(dayId) {
  const inner = document.querySelector(`#drugs-${dayId} .cd-acc-body-inner`);
  const b64 = inner?.dataset?.notB64 || '';
  const mevcutNot = b64 ? decodeURIComponent(escape(atob(b64))) : '';
  caseDayNotAc(dayId, mevcutNot);
}

/**
 * Bir vakaya ait tedavi günlerinin tamamlanma durumuna göre "vaka kapat" düğmesini etkinleştirir veya devre dışı bırakır; ayrıca aktif vakada erken kapatma düğmesini gösterip gizler.
 * @param {string} caseId - Tedavi günleri kontrol edilecek vakanın kimliği.
 * @returns {Promise<void>} Düğme durumları güncellendikten sonra tamamlanan bir Promise.
 */
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

// ═══ E0 — KALAN GÜNLERİ KAYDIR (2026-09-25, erteleme-genel S5) ═══
// Aktif vaka kartında vakanın TAMAMLANMAMIŞ günlerinin +N kaydırılması.
// RPC: vaka_kalan_gunleri_kaydir (migration 20260925100001) — açık gün
// satırları + TEDAVI_GUN/TEDAVI_SEANS görevleri + seans planları + şablon
// TAI tek atomik işlemde kayar; tamamlanmışlara dokunmaz; TAI ayrıca
// tohumlama_gorev_ertele pencere/GECMIS_TARIH korumasından geçer.
// Buton AKTİF vakada görünür (cd-gun-bolum yalnız aktifken açık) ve
// ONLINE-only: offline'da gizlenir; yine tetiklenirse toast + RPC ÇAĞRILMAZ
// (E6: guard bu buton için yazılmıştı, aşağıdaki genel zemine taşındı).

// ═══ E6 — OFFLINE ERTELEME KAPISI (2026-09-25, erteleme-genel S7) ═══
// Sahip kararı S7 (bağlayıcı): erteleme/kaydırma yolları online-only'dir.
// navigator.onLine === false iken butonların TAMAMI gizlenir (kart üretimi
// hiç çizmez + canlı DOM online/offline olaylarıyla güncellenir); yine
// tetiklenirse birleşik offline toast + console kaydı (metin guard içinde)
// ve RPC ÇAĞRILMAZ. rpcOptimistic'in genel guard'ı (js/api.js) yeterli
// DEĞİL — erteleme yolları rpc()'yi direkt çağırır; giriş guard'ı burada.

// Tek çevrimdurumu kaynağı — navigator tanımsızsa (eski koşum) online say.
/**
 * Tarayıcının çevrimiçi olup olmadığını kontrol eder ve çevrimiçi ise true, çevrimdışı ise false döndürür.
 * @returns {boolean} Tarayıcının çevrimiçi durumu.
 */
function _ertelemeOnline() {
  return !(typeof navigator !== 'undefined' && navigator.onLine === false);
}

// Ortak giriş guard'ı: offline ise toast + console kaydı atar ve true döner;
// çağıran erken çıkar, RPC'ye ulaşmaz. Tüm erteleme/kaydırma giriş
// noktaları (cdKaydirAc, caseKalanGunleriKaydir, _erteleModal,
// _erteleKaydet) bu TEK fonksiyondan geçer — kopya-yapıştır yok.
/**
 * İnternet bağlantısı yoksa erteleme işlemini engeller ve kullanıcıya bildirim gösterir.
 * @param {string} yol Ertelenmeye çalışılan yol (opsiyonel).
 * @returns {boolean} İnternet yoksa true, yoksa false döndürür.
 */
function _ertelemeOfflineGuard(yol) {
  if (_ertelemeOnline()) return false;
  toast('İnternet yok — erteleme yapılamadı', true);
  console.warn('[erteleme] offline — rpc çağrılmadı', yol || '');
  return true;
}

// Görünürlük (E0 cdKaydirBtnGuncelle'in genelleşmesi): vaka detayındaki
// #cd-kaydir-btn + görev kartlarındaki [data-ertele] erteleme butonları
// tek yerden. openCaseDet açılışta + online/offline olaylarında çağırır;
// kart üretimi (_erteleBtnHtml) offline'da butonu hiç çizmez.
/**
 * Ertelme durumu (online) ve aktif protokol vaka bilgilerine göre ilgili butonların ve seçim çubuğunun görünürlüğünü günceller.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function ertelemeBtnGuncelle() {
  const online = _ertelemeOnline();
  const cdBtn = document.getElementById('cd-kaydir-btn');
  if (cdBtn) cdBtn.style.display = online ? 'block' : 'none';
  // C-1 (E4 onarım): protokol iptal yüzeyi — online + AKTİF + protocol_family'li
  // vaka (openCaseDet _curCase'i kurar). _curCase vm-extract koşumlarında
  // bulunmayabilir — typeof koruması (ui.js:6980 deseni).
  const cdPBtn = document.getElementById('cd-protokol-iptal-btn');
  if (cdPBtn) cdPBtn.style.display = (online && typeof _curCase !== 'undefined' && _curCase && _curCase.status === 'active' && _curCase.protocol_family) ? 'block' : 'none';
  document.querySelectorAll('[data-ertele]').forEach(b => { b.style.display = online ? '' : 'none'; });
  // F1 Task 3: seçim çubuğu görünürlüğü de TEK bu yardımcıdan senkronlanır (E6 parite).
  // typeof guard: vm-extract koşumlarında yardımcı ctx'te olmayabilir (ui.js:1326 deseni).
  if(typeof _cokluSecimBarGuncelle==='function') _cokluSecimBarGuncelle();
}
window.addEventListener('online',  () => ertelemeBtnGuncelle());
window.addEventListener('offline', () => ertelemeBtnGuncelle());

// ═══ E1-UI — GENEL ERTELEME KURAL CACHE'İ (2026-09-25, erteleme-genel) ═══
// Kural TEK kaynak: canlı gorev_ertele_kural_listele RPC'si — JS'e tip listesi
// KOPYALANMAZ (plan §1). Cache AppState'e yazılır ('ertelemeKurallari':
// {gorev_tipi: {ertelenebilir, pencere_kurali}}); renderTask/_erteleModal
// senkron okur. Yenileme: loadDash rozet tarayıcısı (ovsync_baslat_uyarilari
// deseni — her dash yüklenişinde) + loadTasks girişinde cache boşsa (ilk
// renderda butonlar hazır olsun; 60 sn hata-sükuneti RPC yoksa çekiştirmez).
// Offline: cache eski kalabilir (§8-6 kabulü) — butonlar zaten gizli (E6).
// Cache yoksa FAIL-CLOSED: kayıtsız tip → buton yok, modal açılmaz.
let _ertelemeKuralSonDeneme = 0;
/**
 * 'ertelemeKurallari' anahtarını kullanarak state'den ilgili veriyi alır ve bulunamazsa boş bir obje döndürür.
 * @returns {Object} Ertelme kuralları içeren obje veya boş obje.
 */
function ertelemeKurallariGetir() { return getState('ertelemeKurallari') || {}; }
/**
 * Belirtilen tip için erteleme kuralını döndürür.
 * @param {string} tip - Aranan kuralın tipi.
 * @returns {*} Tip'e karşılık gelen erteleme kuralı veya bulunamazsa null.
 */
function ertelemeKuralGetir(tip) { return ertelemeKurallariGetir()[tip] || null; }
/**
 * Ertelenebilirlik kurallarını sunucudan getirir ve cache'e kaydeder. Cache dolu veya hata sükuneti süresi dolmadıysa çalışmaz.
 * @param {boolean} zorla Cache kontrolünü atlayıp kuralları zorla yenileme.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc gorev_ertele_kural_listele
 */
async function ertelemeKurallariYenile(zorla) {
  if (!zorla && Object.keys(ertelemeKurallariGetir()).length) return;   // cache dolu
  const simdi = Date.now();
  if (!zorla && simdi - _ertelemeKuralSonDeneme < 60000) return;        // hata sükuneti
  _ertelemeKuralSonDeneme = simdi;
  if (!_ertelemeOnline()) return;                                      // offline: mevcut cache
  try {
    const rows = await rpc('gorev_ertele_kural_listele', {});
    if (Array.isArray(rows) && rows.length) {
      const m = {};
      rows.forEach(r => { if (r && r.gorev_tipi) m[r.gorev_tipi] = { ertelenebilir: !!r.ertelenebilir, pencere_kurali: r.pencere_kurali || 'yok' }; });
      setState('ertelemeKurallari', m);
    }
  } catch (e) { console.warn('gorev_ertele_kural_listele:', e.message); }
}

// Kaydırma sayfası (bottom sheet) — caseDaySaatAc/not-modal görsel dili.
// Saf üretici: tests/unit/erteleme-kaydir-ui.test.js kilitli.
/**
 * Kalan günleri kaydırma arayüzünü oluşturan HTML yapısını döndürür.
 * Kullanıcıya vakaların tamamlanmamış günlerini ileri kaydırma seçeneklerini (+1, +2, +3) ve özel gün kaydırma inputunu sunar.
 * Tamamlanmış günlerin değişmediğini ve tarihlerin geçmişe gitmediğini belirtir.
 * @returns {string} Kaydırma işlemleri için gerekli butonlar ve inputlar içeren HTML string.
 */
function cdKaydirSheetHtml() {
  return `<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:20px 16px;padding-bottom:calc(20px + env(safe-area-inset-bottom,0px));box-sizing:border-box">
    <div style="font-weight:800;font-size:.9rem;margin-bottom:6px">⏩ Kalan Günleri Kaydır</div>
    <div style="font-size:.76rem;color:var(--ink2);line-height:1.5;margin-bottom:12px">Vakanın tamamlanmamış günleri, seans planları ve planlı tohumlaması seçtiğin kadar ileri kayar. Tamamlanmış günler değişmez, tarihler geçmişe düşmez.</div>
    <div style="display:flex;gap:8px;margin-bottom:12px">
      <button data-gun="1" onclick="caseKalanGunleriKaydir(1)" style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-size:1rem;font-weight:700;cursor:pointer">+1</button>
      <button data-gun="2" onclick="caseKalanGunleriKaydir(2)" style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-size:1rem;font-weight:700;cursor:pointer">+2</button>
      <button data-gun="3" onclick="caseKalanGunleriKaydir(3)" style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-size:1rem;font-weight:700;cursor:pointer">+3</button>
    </div>
    <div style="display:flex;gap:8px;align-items:stretch">
      <input type="number" id="kaydir-ozel-input" min="1" max="365" step="1" inputmode="numeric" placeholder="Gün" style="width:86px;border:1.5px solid var(--card3);border-radius:10px;padding:12px;font-size:1rem;background:var(--card);color:var(--ink);outline:none;text-align:center;box-sizing:border-box">
      <button id="kaydir-ozel-btn" onclick="cdKaydirOzelUygula()" style="flex:1;padding:12px;background:var(--blue);color:#fff;border:none;border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">Gün Kaydır</button>
      <button onclick="document.getElementById('kaydir-modal').remove()" style="flex:1;padding:12px;background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:10px;font-size:.9rem;font-weight:700;cursor:pointer">Vazgeç</button>
    </div>
  </div>`;
}

/**
 * Kaydırma işlemi için modal penceresini oluşturur ve sayfaya ekler.
 * Eğer sistem offline moddaydırsa veya aktif bir vaka yoksa işlemi iptal eder.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function cdKaydirAc() {
  // E6 offline kapısı: sayfa açılmaz, RPC zaten çağrılmaz
  if (_ertelemeOfflineGuard('kaydir')) return;
  if (!_curCase || _curCase.status !== 'active') { toast('Yalnız aktif vaka kaydırılabilir', true); return; }
  let box = document.getElementById('kaydir-modal');
  if (box) box.remove();
  box = document.createElement('div');
  box.id = 'kaydir-modal';
  box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:300;display:flex;align-items:flex-end';
  box.onclick = e => { if (e.target === box) box.remove(); };
  box.innerHTML = cdKaydirSheetHtml();
  document.body.appendChild(box);
}

// Özel gün girişi — mini-form uygula butonu
/**
 * 'kaydir-ozel-input' elementindeki değeri alıp caseKalanGunleriKaydir fonksiyonuna geçirir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function cdKaydirOzelUygula() {
  const v = document.getElementById('kaydir-ozel-input')?.value;
  caseKalanGunleriKaydir(v);
}

// RPC sonucu → özet toast metni. Sıfır sayılar listelenmez; hepsi sıfırsa
// (vakada açık kalem kalmamışsa) ayrı mesaj. Tarih aralığı insan dilinde.
/**
 * Kaydırılacak açık kalemler için detaylı özet metni oluşturur.
 * @param {Object} r Kaydırma işleminin detaylarını içeren nesne (tasinan_gun_satiri, tasinan_gorev, tasinan_seans, tasinan_uygulama_satiri, tai, gun, ilk_tarih, son_tarih vb. özelliklere sahip).
 * @returns {String} Oluşturulan özet mesajı veya "Kaydırılacak açık kalem bulunamadı" mesajı.
 */
function _kaydirOzetMetni(r) {
  const d = r || {};
  const parca = [];
  if (d.tasinan_gun_satiri)      parca.push(`${d.tasinan_gun_satiri} gün satırı`);
  if (d.tasinan_gorev)           parca.push(`${d.tasinan_gorev} görev`);
  if (d.tasinan_seans)           parca.push(`${d.tasinan_seans} seans görevi`);
  if (d.tasinan_uygulama_satiri) parca.push(`${d.tasinan_uygulama_satiri} seans planı`);
  if (d.tai)                     parca.push(`${d.tai} tohumlama`);
  if (!parca.length) return 'Kaydırılacak açık kalem bulunamadı';
  let m = `✅ +${d.gun} gün kaydırıldı: ${parca.join(', ')}`;
  if (d.ilk_tarih || d.son_tarih) m += ` → ${fmtTarih(d.ilk_tarih)} .. ${fmtTarih(d.son_tarih)}`;
  return m;
}

// VAKA_KAYDIRILAMAZ:<json> ailesi (+ iç içe geçebilen tohumlama hataları)
// → Türkçe mesaj. Bilinmeyen mesaj olduğu gibi kalır (sessiz yutma yok).
/**
 * Hata mesajını işleyerek okunabilir Türkçe hata mesajı döndürür veya orijinal mesajı geri verir.
 * @param {string} msg İşlenecek hata mesajı string'i.
 * @returns {string} İşlenmiş Türkçe hata mesajı veya orijinal mesaj.
 */
function _kaydirHataMesaj(msg) {
  const m = String(msg || '');
  const i = m.indexOf('VAKA_KAYDIRILAMAZ:');
  if (i !== -1) {
    try {
      const j = JSON.parse(m.slice(i + 'VAKA_KAYDIRILAMAZ:'.length));
      const tr = {
        GECERSIZ_GUN:    'Geçersiz gün sayısı — en az 1 girin',
        VAKA_BULUNAMADI: 'Vaka bulunamadı',
        VAKA_ACIK_DEGIL: 'Vaka açık değil — yalnız aktif vakalar kaydırılabilir',
      };
      if (tr[j.sebep]) return tr[j.sebep] + (j.status ? ` (durum: ${j.status})` : '');
    } catch (_) { /* JSON çözülemedi → ham mesaj düşer */ }
  }
  if (m.includes('GECMIS_TARIH'))      return 'Tohumlama tarihi geçmişe düşemez — kaydırma yapılmadı';
  if (m.includes('GOREV_ERTELENEMEZ')) return 'Planlı tohumlama ertelenemedi — kaydırma yapılmadı';
  return m;
}

/**
 * Aktif vakalar için kalan gün sayısını kaydırır (geçerli bir gün sayısı girilir).
 * İşlem sırasında ilgili arayüz elemanlarını günceller, RPC çağrısı yapar ve sonuçları gösterir.
 * @param {string} gun Kaydırılacak gün sayısı (string olarak, en az 1).
 * @returns {void} İşlem tamamlandığında veya hata oluştuğunda bir değer döndürmez.
 * @rpc vaka_kalan_gunleri_kaydir
 */
async function caseKalanGunleriKaydir(gun) {
  if (_ertelemeOfflineGuard('kaydir')) return;   // E6: offline'da RPC ÇAĞRILMAZ
  if (!_curCase || _curCase.status !== 'active') { toast('Yalnız aktif vaka kaydırılabilir', true); return; }
  const n = parseInt(gun, 10);
  if (!Number.isFinite(n) || n < 1) { toast('Geçerli bir gün sayısı girin (en az 1)', true); return; }
  const ozelBtn = document.getElementById('kaydir-ozel-btn');
  if (ozelBtn) { ozelBtn.disabled = true; ozelBtn.textContent = '…'; }
  try {
    const r = await rpc('vaka_kalan_gunleri_kaydir', { p_case_id: _curCase.id, p_gun: n });
    document.getElementById('kaydir-modal')?.remove();
    toast(_kaydirOzetMetni(r));
    // Tazele: kaydırılan tüm yüzeyler (gün satırı, görev, seans planı, audit)
    await pullTables(['treatment_days','gorev_log','treatment_day_uygulamalar','islem_log']).catch(() => {});
    if (_curCase) {
      await renderCaseTimeline(_curCase.id);
      _updateKapatBtn(_curCase.id);
    }
  } catch (e) {
    toast('❌ ' + _kaydirHataMesaj(e.message), true);
    if (ozelBtn) { ozelBtn.disabled = false; ozelBtn.textContent = 'Gün Kaydır'; }
  }
}

/**
 * Günlük seçim ayı ve yılını güncel tarihle ayarlar, giriş metnini ve hatayı temizler, ardından modalı render eder.
 * @returns {Promise<void>} İşlem tamamlandığında boş Promise döndürür.
 */
async function caseGunEkle() {
  if (!_curCase) return;
  const today = new Date();
  const year = today.getFullYear();
  const month = today.getMonth();
  _gunSecimAy = month;
  _gunSecimYil = year;
  _gunSecimSecili = new Set();
  // R1 review bulgusu: açılışta el-girişi durumu da sıfırlanmalı — kardeş
  // yüzeyler (bcTakvimAc/tekTarihTakvimAc) zaten öyle yapıyor; aksi hâlde
  // tekrar açılışta bayat metin + kırmızı hata bandı kalır.
  _gunSecimGirisMetni = '';
  _gunSecimGirisHatasi = '';
  caseGunModalRender();
}

let _gunSecimAy = 0, _gunSecimYil = 0;
let _gunSecimSecili = new Set();
// R1: el girişi durumu (kanonik bileşendeki _tekTarihGiris* kardeşi).
let _gunSecimGirisMetni = '', _gunSecimGirisHatasi = '';

/**
 * Gün seçimi için modal penceresini oluşturur veya mevcut modalı günceller.
 * Tarih ızgarasını çeker, seçili günleri renklendirir, yıl ve ay seçici dropdown'larını oluşturur
 * ve kullanıcıya tarih seçimi için bir arayüz sunar.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function caseGunModalRender() {
  tarihSeciciStilEnjekte();
  let box = document.getElementById('gun-tarih-modal');
  if (!box) {
    box = document.createElement('div');
    box.id = 'gun-tarih-modal';
    box.className = 'tarih-modal-tasiyici';
    box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:300;display:flex';
    box.onclick = e => { if (e.target === box) box.remove(); };
    document.body.appendChild(box);
  }
  const ay = _gunSecimAy, yil = _gunSecimYil;
  // Ortak ızgara çekirdeği (js/tarih/tarih.js — F3 birleşmesi: new Date/
  // yerel-ayar üretimi kalmadı). Hücre sözleşmesi: null (boş — baştaki
  // null'lar Pazartesi-bazlı boşluk, kuyruktakiler tam hafta dolgusu) |
  // {iso, gun, ayIci}.
  const hucreler = (tarihAyIzgara(yil, ay + 1) || { hucreler: [] }).hucreler;
  const bugunTr = bugun();

  let kareler = '';
  for (const h of hucreler) {
    if (!h) { kareler += '<div></div>'; continue; }
    const iso = h.iso;
    const secili = _gunSecimSecili.has(iso);
    const bugunMu = iso === bugunTr;
    kareler += '<div onclick="caseGunToggle(&#39;' + iso + '&#39;)" style="aspect-ratio:1;display:flex;align-items:center;justify-content:center;border-radius:8px;font-size:.9rem;font-weight:700;cursor:pointer;' +
      (secili ? 'background:var(--green);color:#fff;' : bugunMu ? 'background:rgba(78,154,42,.15);color:var(--green);border:1.5px solid var(--green);' : 'color:var(--ink);') +
      '">' + h.gun + '</div>';
  }

  const seciliList = [..._gunSecimSecili].sort();
  const seciliHtml = seciliList.length
    ? '<div style="display:flex;flex-wrap:wrap;gap:4px;margin-bottom:10px">' +
      seciliList.map(d => '<span style="background:rgba(78,154,42,.12);border:1px solid var(--green);border-radius:6px;padding:2px 8px;font-size:.72rem;font-weight:700;color:var(--green)">' + d.slice(5).replaceAll('-','.') + '</span>').join('') +
      '</div>'
    : '<div style="font-size:.75rem;color:var(--ink3);margin-bottom:10px">Tarih secin</div>';

  // R1 bulgu 4: başlık dropdown'ları (vaka günleri min/max'sız — varsayılan
  // aralık bugun-120 .. bugun+10, tarihYilAraligi beyanı).
  const yilAralik = tarihYilAraligi(null, null, Number(bugunTr.slice(0, 4)));
  const yilAdaylari = [];
  for (let y = yilAralik[0]; y <= yilAralik[1]; y++) yilAdaylari.push(y);
  if (!yilAdaylari.includes(yil)) yilAdaylari.push(yil);
  yilAdaylari.sort((a, b) => a - b);
  const aySecenekleri = TARIH_AY_ADLARI.map((ad, i) =>
    '<option value="' + i + '"' + (i === ay ? ' selected' : '') + '>' + ad + '</option>').join('');
  const yilSecenekleri = yilAdaylari.map(y =>
    '<option value="' + y + '"' + (y === yil ? ' selected' : '') + '>' + y + '</option>').join('');

  box.innerHTML =
    '<div class="tarih-modal-kart">' +
    '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:12px">' +
    '<button onclick="caseGunAyDegistir(-1)" aria-label="Önceki ay" style="' + _takvimNavStil + '">‹</button>' +
    '<select id="case-gun-ay-sec" onchange="caseGunAySec(this.value)" aria-label="Ay" style="' + _takvimSeciciStil + '">' + aySecenekleri + '</select>' +
    '<select id="case-gun-yil-sec" onchange="caseGunYilSec(this.value)" aria-label="Yıl" style="' + _takvimSeciciStil + ';flex:0 1 auto">' + yilSecenekleri + '</select>' +
    '<button onclick="caseGunAyDegistir(1)" aria-label="Sonraki ay" style="' + _takvimNavStil + '">›</button>' +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:4px">' +
    TARIH_GUN_ADLARI.map(g => '<div style="text-align:center;font-size:.7rem;font-weight:700;color:var(--ink3);padding:3px">' + g + '</div>').join('') +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:12px">' + kareler + '</div>' +
    '<div style="font-size:.78rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Secili Gunler (' + seciliList.length + ')</div>' +
    seciliHtml +
    '<div style="display:flex;gap:6px;margin-bottom:4px">' +
    '<input id="case-gun-giris" type="text" inputmode="numeric" autocomplete="off" placeholder="gg.aa.yyyy" value="' + escAttr(_gunSecimGirisMetni) + '" style="flex:1;min-width:0;min-height:40px;background:var(--card2);border:1px solid var(--card3);border-radius:8px;padding:8px;font-size:1rem;color:var(--ink)">' +
    '<button onclick="caseGunGirisUygula()" style="min-height:40px;padding:8px 14px;background:var(--card2);border:1px solid var(--card3);border-radius:8px;font-size:.95rem;font-weight:700;cursor:pointer;color:var(--ink)">Uygula</button>' +
    '</div>' +
    '<div id="case-gun-giris-hata" role="alert" style="display:' + (_gunSecimGirisHatasi ? 'block' : 'none') + ';font-size:.9rem;font-weight:700;color:#c0392b;margin:0 0 8px">' + (_gunSecimGirisHatasi ? '⚠️ ' + esc(_gunSecimGirisHatasi) : '') + '</div>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">' +
    '<button onclick="caseGunEkleOnayla()" style="padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-weight:700;cursor:pointer">Ekle</button>' +
    '<button onclick="document.getElementById(\'gun-tarih-modal\').remove()" style="padding:12px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">Iptal</button>' +
    '</div></div>';
  // R1: maske + Enter=Uygula (kanonik yüzeydekiyle aynı bağımsız davranış).
  tarihSeciciMaskeBagla('case-gun-giris', caseGunGirisUygula, 'case-gun-giris-hata');
  box.style.display = 'flex';
}

/**
 * Seçili olan ISO koduna sahip silahı listeden kaldırır veya ekler, giriş alanını ve hata mesajını temizler ardından modalı yeniden render eder.
 * @param {string} iso Silahın ISO kodu.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function caseGunToggle(iso) {
  if (_gunSecimSecili.has(iso)) _gunSecimSecili.delete(iso);
  else _gunSecimSecili.add(iso);
  _gunSecimGirisMetni = ''; _gunSecimGirisHatasi = '';
  caseGunModalRender();
}

// R1 bulgu 1: ‹/› inline onclick matematiği fonksiyona taşındı (kanonik
// tekTarihTakvimAyDegistir kardeşi; eski gömülü `_gunSecimAy--` dizgesi
// test edilemezdi — V2.2 dersinin aynısı). Yıl 1..9999'a kelepırlı — ızgara
// etki alanı dışı temsilsiz ay üretemez (review tutarlılık bulgusu).
/**
 * Seçili yıl ve ay değerine verilen delta (ay sayısı) kadar ileri veya geri giderek yeni yıl ve ay hesaplar.
 * Hesaplanan yıl 1 ile 9999 arasında değilse fonksiyon hiçbir değişiklik yapmadan döner.
 * @param {number} delta Yıl ve ay değerini değiştirmek için eklenecek veya çıkarılacak ay sayısı.
 * @returns {void} Yıl ve ay değişkenlerini günceller, döndürülen değer yok.
 */
function caseGunAyDegistir(delta) {
  const toplam = _gunSecimYil * 12 + _gunSecimAy + Math.trunc(Number(delta) || 0);
  const hedefYil = Math.floor(toplam / 12);
  // R1 REVİZYON (denetim B5): hedef yıl 1..9999 dışına çıkıyorsa ham modulo
  // UYGULANMAZ — sayfalama kenarda reddedilir, bulunduğun kenar ay/yıl korunur
  // (1-Ocak ‹ → Ocak-1 kalır, eski davranışta 1-Aralık'a bozuluyordu).
  if(!(hedefYil >= 1 && hedefYil <= 9999)) return;
  _gunSecimYil = hedefYil;
  _gunSecimAy = ((toplam % 12) + 12) % 12;
  caseGunModalRender();
}

// R1 bulgu 4: başlık dropdown işleyicileri.
/**
 * Geçerli bir ay numarası (0-11 arası) alan ve bu ayı global değişkene atayarak ilgili modalı render eder.
 * @param {number} deger - Render edilecek ayın numarası (0 ile 11 arasında).
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function caseGunAySec(deger) {
  const ay = Math.trunc(Number(deger));
  if (!(ay >= 0 && ay <= 11)) return;
  _gunSecimAy = ay;
  caseGunModalRender();
}
/**
 * Geçerli bir yıl (1 ile 9999 arasında) alarak yıl değişkenini ayarlar ve ilgili modalı render eder.
 * @param {number} deger - İşlenecek yıl değeri.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function caseGunYilSec(deger) {
  const yil = Math.trunc(Number(deger));
  if (!(yil >= 1 && yil <= 9999)) return;
  _gunSecimYil = yil;
  caseGunModalRender();
}

// R1 bulgu 3: el girişi — tarihGirisCoz (ayraç toleranslı) → seçime EKLE,
// görünüm o aya atlar; hata satır içi, yazdığı korunur. Vaka günleri
// min/max'sız çoklu-seçimdir: geçerli her tarih seçilebilir.
/**
 * 'case-gun-giris' girişindeki tarih bilgisini doğrular, maske veya ayrıştırma hatası varsa hatayı kaydedip modalı yeniden çizer; geçerliyse tarihi seçili günlere ekler ve yıl/ay seçimini güncelleyerek modalı yeniden çizer.
 * @returns {void}
 */
function caseGunGirisUygula() {
  const inp = document.getElementById('case-gun-giris');
  const metin = inp ? inp.value : '';
  // R1 REVİZYON B1b: bekleyen maske hatası tarihGirisCoz'dan ÖNCE reddeder.
  const maskeHatasi = tarihSeciciMaskeHatasiAl('case-gun-giris');
  if(maskeHatasi){
    _gunSecimGirisMetni = metin;
    _gunSecimGirisHatasi = maskeHatasi;
    caseGunModalRender();
    return;
  }
  const r = tarihGirisCoz(metin);
  if (!r.ok) {
    _gunSecimGirisMetni = metin;
    _gunSecimGirisHatasi = r.error;
    caseGunModalRender();
    return;
  }
  _gunSecimGirisMetni = '';
  _gunSecimGirisHatasi = '';
  _gunSecimSecili.add(r.iso);
  _gunSecimYil = Number(r.iso.slice(0, 4));
  _gunSecimAy = Number(r.iso.slice(5, 7)) - 1;
  caseGunModalRender();
}

/**
 * Seçili tedavi günlerini alıp, seçili olanları sıralar ve eğer hiçbiri seçilmemişse uyarı verir.
 * Seçilen günlerin her biri için tedavi günü ekleme işlemi yapar, tabloyu günceller, ilaç önbelleğini temizler,
 * ilaç önbelleğini yeniden yükler ve vakanın zaman çizelgesini yeniden render eder.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda void döner.
 * @rpc add_treatment_day
 */
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

// ═══ AKTİF VAKAYA ŞABLON UYGULAMA (2026-09-09) ═══
// Desen: bc-sablon-yukle (forms.js:1382) katlanır alanı + submitCase
// (forms.js:616-629) çift-RPC akışı. Çapa: _cdSablonTarih (tek-seçim takvim
// modalı, aşağıda) = şablonun 1. günü (RPC'de tarih = çapa + (gun_no − 1));
// p_baslangic_tarihi NULL ⇔ açılıştaki start_date çapası.

// Saf çekirdek — tests/unit/tedavi-sablon-aktif.test.js yeşil kilidi.
// bcSablonYukleListeRender (forms.js:1413-1421) satır hesabının DOM'suz aynası.
/**
 * Verilen eslem (işlem) dizisinden belirtilen hastalık ID'sine (diseaseId) sahip kayıtları filtreler,
 * bu kayıtlara ait sablonları bulur ve ilgili kalemleri (seans bilgilerini) işleyerek
 * sablon detaylarını, gün sayısını, seans sayısını ve tohumlama planı durumunu içeren bir dizi döndürür.
 * @param {Array} eslem Filtreleme yapılacak eslem (işlem) kayıtlarının bulunduğu dizi.
 * @param {Array} sablonlar Sablonların bulunduğu dizi.
 * @param {Array} kalemler Kalemlerin (seansların) bulunduğu dizi.
 * @param {number|string} diseaseId Filtreleme için kullanılacak hastalık ID'si.
 * @returns {Array} Her bir öğe id, ad, gun, seans ve tohumVar özelliklerini içeren nesnelerden oluşan dizi.
 */
function cdSablonListeBul(eslem, sablonlar, kalemler, diseaseId){
  const list = (eslem || []).filter(e => e.disease_id === diseaseId)
    .map(e => (sablonlar || []).find(s => s.id === e.sablon_id)).filter(Boolean);
  return list.map(s => {
    const sk = (kalemler || []).filter(k => k.sablon_id === s.id);
    const tp = s.tohumlama_plani;
    return { id: s.id, ad: s.ad,
             gun: new Set(sk.map(k => k.gun_no)).size,
             seans: sk.length,
             tohumVar: !!(tp && typeof tp === 'object' && tp.gun_ofset != null && tp.planned_time) };
  });
}

// ── TEK-TARİH TAKVİM MODALI — KANONİK bileşen (ui-map "Canonical date
// selection"; sahibe direktifi 2026-09-09: yeni yüzeylerde yerel native
// tarih inputu — type=date — KULLANILMAZ). Görsel dil: gun-tarih-modal
// (caseGunModalRender); seçim kuralı: W20 tek-seçim — hücre tıkı seçimi
// DEĞİŞTİRİR, toggle yok (F3'ten beri bc yüzeyi de bu bileşende:
// forms.js bcTarihSeciciAc). Izgara ortak çekirdekten (js/tarih/tarih.js)
// gelir; ay ‹/› + başlıktan yıl ‹/› + gg.aa.yyyy el girişi (saf tarihParse
// — hata satır içi, sessiz düzeltme yok).
// Çağıran kendi durumunu getirir:
//   tekTarihTakvimAc({ baslik, deger, onSec,      — onSec(iso) Onayla'da;
//                      min, max,                  — dahil sınırlar (ISO);
//                      temizlenebilir,            — true → Temizle + onSec(null);
//                      kapaliGun })               — kapaliGun(iso)→true =
//                                                 kapalı gün, seçilemez.
let _tekTarihAy = 0, _tekTarihYil = 0, _tekTarihSecili = null;
let _tekTarihBaslik = '📅 Takvimden Seç', _tekTarihOnSec = null;
// F1 sertleştirme (G-20260913): aralık + kapalı-gün + temizleme + el girişi.
// min/max geçerli ISO; kapaliGun(iso) → true = gün seçilemez (F3: bc yüzeyi
// bcTarihSeciciAc ve tarihAlani* bu iletir); giriş hatası yeniden render'da
// satır içi gösterilir — sessiz düzeltme YOK.
let _tekTarihMin = null, _tekTarihMax = null;
let _tekTarihTemizlenebilir = false, _tekTarihKapaliGun = null;
let _tekTarihGirisMetni = '', _tekTarihGirisHata = '';
// W3: olaylı günler (Set<'YYYY-MM-DD'>) — işaretleme yalnız render katmanında;
// boş gün beyaz kalır. Veriyi çağıran getirir (IDB yansıması; ek pull YOK).
let _tekTarihIsaretliGunler = null;

/**
 * Seçili bir tarih varsa onu, yoksa bugünü alarak takvim görünümünü ayarlar;
 * modal yığınına ekleyerek tarayıcı geçmişini günceller ve takvimi açar.
 * @param {Object} opts Seçim, başlık, min/max tarih, kapalı günler ve diğer ayarları içeren nesne.
 * @returns {void}
 */
function tekTarihTakvimAc(opts){
  // Açılış görünümü: seçili değer varsa O ay/yıl, yoksa bugün (eski hâl
  // hep bugünün ayını açıyordu — doğum gibi geçmiş tarih için uygunsuzdu).
  _tekTarihSecili = tarihGecerliMi(opts?.deger) ? opts.deger : bugun();
  _tekTarihAy  = Number(_tekTarihSecili.slice(5, 7)) - 1;
  _tekTarihYil = Number(_tekTarihSecili.slice(0, 4));
  _tekTarihBaslik = opts?.baslik || '📅 Takvimden Seç';
  _tekTarihOnSec  = opts?.onSec  || null;
  _tekTarihMin = tarihGecerliMi(opts?.min) ? opts.min : null;
  _tekTarihMax = tarihGecerliMi(opts?.max) ? opts.max : null;
  _tekTarihTemizlenebilir = opts?.temizlenebilir === true;
  _tekTarihKapaliGun = typeof opts?.kapaliGun === 'function' ? opts.kapaliGun : null;
  _tekTarihIsaretliGunler = opts?.isaretliGunler instanceof Set ? opts.isaretliGunler : null;
  _tekTarihGirisMetni = '';
  _tekTarihGirisHata = '';
  tekTarihTakvimRender();
  // W3 (hapsolmama): takvim history'ye girer — modal-stack deseni (openM'in
  // pushState{_modal} yaklaşımı). Tarayıcı/Android geri takvimi KAPATIR,
  // sayfa değişmez (popstate → navGeriKarar 'modal' dalı → closeM).
  globalThis._modalStack = (globalThis._modalStack || []).filter(x => x !== 'tek-tarih-takvim');
  globalThis._modalStack.push('tek-tarih-takvim');
  if (!(history.state && history.state.modal === 'tek-tarih-takvim')) {
    history.pushState({modal:'tek-tarih-takvim'}, '', '');
  }
}
/**
 * 'tek-tarih-takvim' kimliğine sahip takvim bileşenini closeM üzerinden kapatır.
 * @returns {void}
 */
function tekTarihTakvimKapat(){
  // Her kapanış yolu (X, backdrop, ESC, geri tuşu, Onayla) closeM'den geçer —
  // DOM remove + stack + history tek noktadan (closeM'in takvim dalı).
  closeM('tek-tarih-takvim');
}
/**
 * Verilen ISO tarihini kontrol ederek kapalı günlerde veya tarih aralığı dışındaki günleri seçmeyi engeller ve geçerli ise seçimi günceller.
 * @param {string} iso Seçilmek istenen ISO formatındaki tarih.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function tekTarihTakvimSec(iso){
  // Derinlik savunması: hücreler zaten kapalı çizilir; global çağrıya rağmen
  // kapalı gün ve aralık dışı SEÇİLEMEZ.
  if(_tekTarihKapaliGun && _tekTarihKapaliGun(iso)) return;
  if(!tarihAraliktaMi(iso, _tekTarihMin, _tekTarihMax).ok) return;
  _tekTarihGirisMetni = '';
  _tekTarihGirisHata = '';
  _tekTarihSecili = iso;
  tekTarihTakvimRender();
}
/**
 * Seçili tek tarih varsa kapalı gün kontrolü ve tarih aralığı doğrulaması yapar;
 * doğrulama başarılı ise modalı kapatır ve onSec çağrısını (varsa) tetikler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function tekTarihTakvimOnayla(){
  if(_tekTarihSecili){
    // Seçim, açılıştan gelen eski değer bile olsa kurala tabi — kural dışı
    // seçim çağıranın onSec'ine ASLA ulaşmaz.
    if(_tekTarihKapaliGun && _tekTarihKapaliGun(_tekTarihSecili)){
      _tekTarihGirisHata = 'Seçili gün kapalı — başka bir gün seçin';
      tekTarihTakvimRender();
      return;
    }
    const aralik = tarihAraliktaMi(_tekTarihSecili, _tekTarihMin, _tekTarihMax);
    if(!aralik.ok){
      _tekTarihGirisHata = aralik.error;
      tekTarihTakvimRender();
      return;
    }
  }
  // W3: onSec'i back traversal'ı bittikten SONRA koştur (continuation). onSec
  // gün görünümü gibi history push eden bir açılış yapabilir — back'in hâlâ
  // kuyrukta olduğu anda push edilirse takvim entry'si history'de sızar.
  // popstate guard (_modalBackGuard) tüketildiğinde continuation çalışır;
  // back beklenmiyorsa (history state modal değilse) hemen koşturulur.
  const _cb = _tekTarihOnSec, _secili = _tekTarihSecili;
  globalThis._modalBackDevam = _cb ? () => _cb(_secili) : null;
  tekTarihTakvimKapat();
  if (globalThis._modalBackDevam && !(history.state && history.state.modal === 'tek-tarih-takvim')) {
    const _d = globalThis._modalBackDevam;
    globalThis._modalBackDevam = null;
    _d();
  }
}
// El girişi (gg.aa.yyyy; R1: ayraç toleransı , / - boşluk da kabul) — SAF
// tarihGirisCoz üzerinden (maske-normalizasyon + tarihParse); hata → satır
// içi uyarı, yazdığı korunur; geçersiz tarih SESSİZCE düzeltilmaz, seçim
// değişmez.
/**
 * Tek tarih giriş kutusundan alınan değeri doğrular, maske hatalarını, ISO formatını,
 * tarih aralığını ve kapalı günleri kontrol eder. Geçerli bir tarih seçilirse seçilen
 * tarihi ve yıl/ay bilgilerini günceller, aksi takdirde hata mesajını ayarlar ve
 * takvimi yeniden render eder.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function tekTarihTakvimGirisUygula(){
  const inp = document.getElementById('tek-tarih-giris');
  const metin = inp ? inp.value : '';
  // R1 REVİZYON B1b: bekleyen maske hatası tarihGirisCoz'dan ÖNCE reddeder
  // (maske taşması geçerli-ama-yanlış ISO'yu Uygula'ya sızmaz).
  const maskeHatasi = tarihSeciciMaskeHatasiAl('tek-tarih-giris');
  if(maskeHatasi){
    _tekTarihGirisMetni = metin;
    _tekTarihGirisHata = maskeHatasi;
    tekTarihTakvimRender();
    return;
  }
  const r = tarihGirisCoz(metin);
  if(!r.ok){
    _tekTarihGirisMetni = metin;
    _tekTarihGirisHata = r.error;
    tekTarihTakvimRender();
    return;
  }
  const aralik = tarihAraliktaMi(r.iso, _tekTarihMin, _tekTarihMax);
  if(!aralik.ok){
    _tekTarihGirisMetni = metin;
    _tekTarihGirisHata = aralik.error;
    tekTarihTakvimRender();
    return;
  }
  // Kapalı gün el girişiyle de SEÇİLEMEZ — hücre tıkıyla aynı invaryant
  // (aksi hâlde aynı hücre hem disable hem yeşil çizilir).
  if(_tekTarihKapaliGun && _tekTarihKapaliGun(r.iso)){
    _tekTarihGirisMetni = metin;
    _tekTarihGirisHata = 'Seçili gün kapalı — başka bir gün seçin';
    tekTarihTakvimRender();
    return;
  }
  _tekTarihGirisMetni = '';
  _tekTarihGirisHata = '';
  _tekTarihSecili = r.iso;
  _tekTarihYil = Number(r.iso.slice(0, 4));
  _tekTarihAy  = Number(r.iso.slice(5, 7)) - 1;
  tekTarihTakvimRender();
}
// temizlenebilir: true verilirse seçim kaldırılabilir — onSec(null) gider.
/**
 * Tek tarih seçici durumunu sıfırlar: seçili tarihi, giriş metnini ve hata mesajını temizleyip takvimi yeniden çizer.
 * @returns {void} Döndürür.
 */
function tekTarihTakvimTemizle(){
  _tekTarihSecili = null;
  _tekTarihGirisMetni = '';
  _tekTarihGirisHata = '';
  tekTarihTakvimRender();
}
function tekTarihTakvimRender(){
  tarihSeciciStilEnjekte();
  let box = document.getElementById('tek-tarih-takvim');
  if(!box){
    box = document.createElement('div');
    box.id = 'tek-tarih-takvim';
    box.className = 'tarih-modal-tasiyici';
    box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:300;display:flex';
    // W3: backdrop kapanışı da closeM'den — history + stack tek noktadan temizlensin
    box.onclick = e => { if(e.target === box) closeM('tek-tarih-takvim'); };
    document.body.appendChild(box);
  }
  const ay = _tekTarihAy, yil = _tekTarihYil;
  // Ortak ızgara çekirdeği (js/tarih/tarih.js) — yeni Date/yerel yok; hücre
  // sözleşmesi: null (boş) | {iso, gun, ayIci}. Çekirdek geçersiz girdide
  // null garantiler; kelepırlar bugün ulaşılmasa da boş-ızgaraya düş.
  const hucreler = tarihAyIzgara(yil, ay + 1)?.hucreler || [];
  let kareler = '';
  for(const h of hucreler){
    if(!h){ kareler += '<div></div>'; continue; }
    const kapali = (_tekTarihKapaliGun && _tekTarihKapaliGun(h.iso)) ||
                   (_tekTarihMin && h.iso < _tekTarihMin) ||
                   (_tekTarihMax && h.iso > _tekTarihMax);
    const tik = kapali ? '' : ' onclick="tekTarihTakvimSec(&#39;' + h.iso + '&#39;)"';
    // W3: olaylı gün — küçük nokta + açık zemin tonu; BOŞ GÜN BEYAZ (sahibin
    // sözü); seçili gün yeşili ve kapalı gün %35 opaklık kuralı korunur.
    // İşaretleme yalnız render katmanında; tık mekanizması değişmedi.
    const isaretli = !!(_tekTarihIsaretliGunler && _tekTarihIsaretliGunler.has(h.iso));
    const secili = h.iso === _tekTarihSecili;
    kareler += '<div' + tik + ' style="aspect-ratio:1;display:flex;align-items:center;justify-content:center;border-radius:8px;font-size:.9rem;font-weight:700;cursor:' + (kapali ? 'not-allowed;opacity:.35;' : 'pointer;') +
      (secili ? 'background:var(--green);color:#fff;' : isaretli ? 'background:rgba(201,125,10,.12);color:var(--ink);' : 'color:var(--ink);') +
      ';position:relative;">' + h.gun +
      (isaretli ? '<span data-isaretli-gun="' + h.iso + '" style="position:absolute;left:50%;bottom:3px;transform:translateX(-50%);width:5px;height:5px;border-radius:50%;background:' + (secili ? '#fff' : 'var(--amber)') + ';"></span>' : '') +
      '</div>';
  }
  // R1 bulgu 4: başlıkta ay + yıl AÇILIR LİSTESİ (sahip taslağı: ikisi yan
  // yana). Ay ‹/› sayfalama okları yerinde kalır (bulgu 1: ≥40px, koyu zemin,
  // açık glif); eski ince yıl-ok satırı KALDIRILDI — yıl artık dropdown'da
  // (raporda beyanlı). Liste aralığı alanın min/max'ından (tarihYilAraligi);
  // sayfalama ile aralık dışına çıkıldıysa o yıl da listeye eklenir.
  const bugunYil = Number(bugun().slice(0, 4));
  const yilAralik = tarihYilAraligi(_tekTarihMin, _tekTarihMax, bugunYil);
  const yilAdaylari = [];
  for(let y = yilAralik[0]; y <= yilAralik[1]; y++) yilAdaylari.push(y);
  if(!yilAdaylari.includes(yil)) yilAdaylari.push(yil);
  yilAdaylari.sort((a, b) => a - b);
  const aySecenekleri = TARIH_AY_ADLARI.map((ad, i) =>
    '<option value="' + i + '"' + (i === ay ? ' selected' : '') + '>' + ad + '</option>').join('');
  const yilSecenekleri = yilAdaylari.map(y =>
    '<option value="' + y + '"' + (y === yil ? ' selected' : '') + '>' + y + '</option>').join('');
  // R1 bulgu 1: nav ok stili — TEK kaynak, ≥40px dokunma hedefi, koyu zemin
  // (var(--ink)) + yüksek kontrast glif (var(--card)); tema çiftinde renkler
  // karşılıklı ters döndüğü için açık/koyu temada da kontrast korunur.
  const navStil = _takvimNavStil;
  // R1 bulgu 5: seçiciler büyük punto; select min-height 40px (dokunma).
  const seciciStil = _takvimSeciciStil;
  box.innerHTML =
    '<div class="tarih-modal-kart">' +
    '<div style="font-size:.78rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:10px">' + esc(_tekTarihBaslik) + '</div>' +
    '<div style="font-weight:800;font-size:1.02rem;margin-bottom:12px">Seçilen: ' + fmtTarih(_tekTarihSecili) + '</div>' +
    '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:12px">' +
    '<button onclick="tekTarihTakvimAyDegistir(-1)" aria-label="Önceki ay" style="' + navStil + '">‹</button>' +
    '<select id="tek-tarih-ay-sec" onchange="tekTarihTakvimAySec(this.value)" aria-label="Ay" style="' + seciciStil + '">' + aySecenekleri + '</select>' +
    '<select id="tek-tarih-yil-sec" onchange="tekTarihTakvimYilSec(this.value)" aria-label="Yıl" style="' + seciciStil + ';flex:0 1 auto">' + yilSecenekleri + '</select>' +
    '<button onclick="tekTarihTakvimAyDegistir(1)" aria-label="Sonraki ay" style="' + navStil + '">›</button>' +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:4px">' +
    TARIH_GUN_ADLARI.map(g => '<div style="text-align:center;font-size:.7rem;font-weight:700;color:var(--ink3);padding:3px">' + g + '</div>').join('') +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:8px">' + kareler + '</div>' +
    '<div style="display:flex;gap:6px;margin-bottom:4px">' +
    '<input id="tek-tarih-giris" type="text" inputmode="numeric" autocomplete="off" placeholder="gg.aa.yyyy" value="' + escAttr(_tekTarihGirisMetni) + '" style="flex:1;min-width:0;min-height:40px;background:var(--card2);border:1px solid var(--card3);border-radius:8px;padding:8px;font-size:1rem;color:var(--ink)">' +
    '<button onclick="tekTarihTakvimGirisUygula()" style="min-height:40px;padding:8px 14px;background:var(--card2);border:1px solid var(--card3);border-radius:8px;font-size:.95rem;font-weight:700;cursor:pointer;color:var(--ink)">Uygula</button>' +
    '</div>' +
    '<div id="tek-tarih-giris-hata" role="alert" style="display:' + (_tekTarihGirisHata ? 'block' : 'none') + ';font-size:.9rem;font-weight:700;color:#c0392b;margin:0 0 8px">' + (_tekTarihGirisHata ? '⚠️ ' + esc(_tekTarihGirisHata) : '') + '</div>' +
    '<div style="display:grid;grid-template-columns:' + (_tekTarihTemizlenebilir ? '1fr 1fr 1fr' : '1fr 1fr') + ';gap:8px">' +
    (_tekTarihTemizlenebilir ? '<button onclick="tekTarihTakvimTemizle()" style="padding:12px;background:#f0f0f0;color:var(--ink2);border:none;border-radius:10px;font-weight:700;cursor:pointer">Temizle</button>' : '') +
    '<button onclick="tekTarihTakvimOnayla()" style="padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-weight:700;cursor:pointer">Onayla</button>' +
    '<button onclick="tekTarihTakvimKapat()" style="padding:12px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">İptal</button>' +
    '</div></div>';
  // R1: maske + Enter=Uygula DOM bağı (üç yüzeyde ortak yardımcı).
  tarihSeciciMaskeBagla('tek-tarih-giris', tekTarihTakvimGirisUygula, 'tek-tarih-giris-hata');
  box.style.display = 'flex';
}
/**
 * Tek tarih takvim ay değişkenine delta değerini ekleyerek ayı günceller, yıl sınırlarını (1-9999) kontrol eder ve render işlemini tetikler.
 * @param {number} delta - Ay değişimi için eklenecek veya çıkarılacak sayı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function tekTarihTakvimAyDegistir(delta){
  _tekTarihAy += Math.trunc(Number(delta) || 0);
  if(_tekTarihAy < 0){ _tekTarihAy = 11; _tekTarihYil--; }
  if(_tekTarihAy > 11){ _tekTarihAy = 0; _tekTarihYil++; }
  // Izgara etki alanı 1..9999 — dışına sayfalama temsilsiz ay üretir; kelepır.
  if(_tekTarihYil < 1){ _tekTarihYil = 1; _tekTarihAy = 0; }
  if(_tekTarihYil > 9999){ _tekTarihYil = 9999; _tekTarihAy = 11; }
  tekTarihTakvimRender();
}
// ── R1 ORTAK TAKVİM MODAL ALTYAPISI (G-20260913-TARIH-SECICI-R1) ────

// Bulgu 1/5 ortak stiller (render'lar arası TEK kaynak; const — F4 guard
// yalnız `function` bildirim adlarını tarar, buraya takılmaz).
const _takvimNavStil = 'min-width:40px;min-height:40px;background:var(--ink);color:var(--card);border:none;border-radius:10px;font-size:1.35rem;font-weight:700;cursor:pointer;line-height:1;padding:0 10px';
const _takvimSeciciStil = 'flex:1 1 auto;min-width:0;min-height:40px;background:var(--card2);border:1px solid var(--card3);border-radius:10px;font-size:1.02rem;font-weight:800;color:var(--ink);padding:4px 6px;cursor:pointer';

// Bulgu 2: masaüstü (≥900px) kartı 400px'e sabitler + ortalar; mobil (<900px)
// mevcut tam-genişlik alt-sheet DOKUNULMAZ (sahip: "telefonda gayet iyi").
// Genişlik/yerleşim bu stilin malı — kartlardaki inline width KALDIRILDI
// (inline stil, media-query kuralını ezecekti). Idempotent: tek <style>.
/**
 * Tarih seçici bileşeninin görsel düzenini (modal arka planı ve kart boyutları) belirleyen CSS stillerini DOM'a ekler.
 * Mobil cihazlarda alt hizalı, masaüstü cihazlarda ise ortalanmış bir modal yapısı oluşturur.
 * @returns {void}
 */
function tarihSeciciStilEnjekte(){
  if(document.getElementById('tarih-secici-stil')) return;
  const stil = document.createElement('style');
  stil.id = 'tarih-secici-stil';
  stil.textContent =
    '.tarih-modal-tasiyici{position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:300;display:flex;align-items:flex-end}' +
    '.tarih-modal-kart{background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:16px;max-height:85vh;overflow-y:auto}' +
    '@media (min-width:900px){' +
    '.tarih-modal-tasiyici{align-items:center;justify-content:center}' +
    '.tarih-modal-kart{width:400px;max-width:calc(100vw - 32px);border-radius:18px}' +
    '}';
  (document.head || document.documentElement).appendChild(stil);
}

// Bulgu 3 — maske/Enter DOM bağı (üç takvim yüzeyi ortak): input olayında
// tarihMaskeUygula uygular (imleç rakam sayısını korur), segment uyarısını
// hata yuvasına ANINDA yazar (re-render yok — odak/imeç kaymaz); Enter
// Uygula'yı tetikler. forms.js de bu pencere-global'ini kullanır
// (tekTarihTakvimAc'in F3'ten beri süren paylaşım deseninin devamı).
// R1 REVİZYON (denetim B1b): Uygula yolları tarihSeciciMaskeHatasiAl ile
// bekleyen maske hatasını tarihGirisCoz'dan ÖNCE görür (maske taşması
// yanlış-geçerli ISO üretemez, artık üretse bile Uygula'ya sızmaz).
/**
 * Belirtilen giriş alanına tarih maskesi uygulayan dinamik bir input event listener'ı ekler.
 * Kullanıcı giriş yaparken metni maskeye göre düzenler, imleci doğru konuma getirir ve hata mesajı gösterir.
 * Enter tuşuna basıldığında verilen işlevi (callback) tetikler.
 * @param {string} girisId Tarih girişi yapılacak input elementinin ID'si.
 * @param {function} uygulaFn Enter tuşuna basıldığında çalıştırılacak fonksiyon.
 * @param {string} hataId Hata mesajı gösterilecek span veya div elementinin ID'si (opsiyonel).
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @olay input, keydown
 */
function tarihSeciciMaskeBagla(girisId, uygulaFn, hataId){
  const inp = document.getElementById(girisId);
  if(!inp) return;
  inp.addEventListener('input', () => {
    const eski = String(inp.value == null ? '' : inp.value);
    const imlecSimdi = (typeof inp.selectionStart === 'number') ? inp.selectionStart : eski.length;
    const imlectenRakam = eski.slice(0, imlecSimdi).replace(/\D/g, '').length;
    const r = tarihMaskeUygula(eski);
    if(r.metin !== eski){
      inp.value = r.metin;
      const imlec = tarihMaskeImlec(r.metin, imlectenRakam);
      try{ inp.setSelectionRange(imlec, imlec); }catch(_){ /* stub/test DOM */ }
    }
    const yuva = hataId ? document.getElementById(hataId) : null;
    if(yuva){
      yuva.textContent = r.hata ? '⚠️ ' + r.hata : '';
      yuva.style.display = r.hata ? 'block' : 'none';
    }
  });
  inp.addEventListener('keydown', e => {
    if(e.key === 'Enter'){ e.preventDefault(); if(typeof uygulaFn === 'function') uygulaFn(); }
  });
}

// R1 REVİZYON B1b — Uygula önü maske kapısı (üç yüzey ortak): girişte
// bekleyen bir maske hatası varsa uygulama yolları tarihGirisCoz'u hiç
// çağırmadan reddeder (maske taşması geçerli-ama-yanlış ISO üretemez).
// R1 review (ÖNEMLİ→düzeltildi): kapı DURUMSUZDUR — maske sonucu depolanmaz,
// MEVCUT değerden yeniden hesaplanır. Depolanan expando, Uygula-hata
// yeniden-render'ında input'un yeniden doğmasıyla ölür ve ikinci Uygula'yı
// kapısız bırakır; hatanın kalıcı metinde yaşaması bu yolla garanti edilir.
/**
 * Belirtilen giriş ID'sine sahip elemanın değerini alıp tarih maskeleme işlemini uygular ve oluşan hatayı döndürür.
 * @param {string} girisId Tarih giriş alanının DOM'daki ID'si.
 * @returns {string|null} Tarih maskeleme işlemi sırasında oluşan hata mesajı veya işlem başarısız olduğunda null.
 */
function tarihSeciciMaskeHatasiAl(girisId){
  const inp = document.getElementById(girisId);
  if(!inp || !inp.value) return null;
  return tarihMaskeUygula(inp.value).hata;
}

// Bulgu 4 — başlık dropdown'ları: seçim duruma yazar + yeniden çizer.
// Değerler select'in value'larından gelir; aralık dışı/çöp sessiz yoksayılır
// (select zaten yalnız geçerli opsiyon taşır — savunma katmanı).
/**
 * Geçerli bir ay numarası (0-11 arası) alan ve bu ayı iç ay değişkenine atar.
 * @param {number} deger 0 ile 11 arasında bir sayı olan ay numarası.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function tekTarihTakvimAySec(deger){
  const ay = Math.trunc(Number(deger));
  if(!(ay >= 0 && ay <= 11)) return;
  _tekTarihAy = ay;
  tekTarihTakvimRender();
}
/**
 * Geçerli bir yıl aralığı (1-9999) içindeki yılı alarak tek tarih takvimini günceller.
 * @param {number} deger - Takvim için ayarlanacak yıl değeri.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function tekTarihTakvimYilSec(deger){
  const yil = Math.trunc(Number(deger));
  if(!(yil >= 1 && yil <= 9999)) return;
  _tekTarihYil = yil;
  tekTarihTakvimRender();
}

// ── TARİH ALANI BAĞLAMA — F2 (G-20260913-TARIH-SECICI) ──────────────
// Statik formlardaki native tarih alanlarını kanonik bileşene bağlar
// (karar D-20260909 kuralları: görünür buton + gizli input kalıbı).
//
// Düzen: id, native .value/.min/.max YANSIMASI ve change olayı GİZLİ
// taşıyıcı input'ta kalır — okuyucu `el.value → ISO`, yazıcı
// `el.value = ISO` ve dinamik `.min/.max` yazan hiçbir kod DEĞİŞMEZ.
// Görünür yüzey, taşıyıcının hemen ardına eklenen butondur (gg.aa.yyyy):
//   buton tıkı → tekTarihTakvimAc → onSec → taşıyıcı.value + buton etiketi.
// Taşıyıcı görünmez ama etkileşim katmanı için "görünür" ölçüde bırakılır
// (1×1, opacity:0, pointer-events:none) — mevcut e2e fill/toHaveValue
// sözleşmesi kırılmaz; klavye sekme sırasına girmez (tabindex -1) ve
// ekran okuyucuya kapalıdır (aria-hidden).
// Buton etiketi: yazıcı yolu (value property setter, ana dünya) ve dış
// yazımlar (input olayı) ile senkron kalır.
// Native descriptor LOAD-time değil çağrı-time çözülür — ui.js, HTMLInputElement
// olmayan vm-sandbox test ortamında da yüklenir.
let _tarihAlanNativeValue = null;
/**
 * HTMLInputElement prototipindeki 'value' özelliğinin tanımlayıcısını (descriptor) döndürür.
 * @returns {Object} 'value' özelliğinin descriptor objesi.
 */
function _tarihAlanValueDescriptor(){
  if(!_tarihAlanNativeValue && typeof HTMLInputElement !== 'undefined'){
    _tarihAlanNativeValue = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
  }
  return _tarihAlanNativeValue;
}
/**
 * Belirtilen ID'li input elementini tarih seçici bir bileşene dönüştürür;
 * orijinal görünümü gizli bir taşıyıcıya taşıyarak buton tabanlı bir arayüz oluşturur.
 * @param {string} id Tarih alanı için kullanılacak input elementinin ID'si.
 * @param {Object} [opts] Opsiyonel ayarlar nesnesi.
 * @returns {HTMLElement} İşlem sonrası dönüştürülmüş input elementini döndürür.
 * @olay click, input
 */
function tarihAlaniBagla(id, opts){
  const el = document.getElementById(id);
  if(!el || el.tagName !== 'INPUT' || el._tarihBagli) return el; // idempotent
  const nativeValue = _tarihAlanValueDescriptor();
  if(!nativeValue) return el;
  const o = opts || {};
  el._tarihBagli = true;
  // Orijinal görünüm butona taşınmadan ÖNCE yakalanır (aşağıdaki kaçış
  // stilleri butona kopyalanmamalı).
  const eskiStil = el.getAttribute('style') || '';
  // Gizli taşıyıcı: sözleşmenin sahibi. Yerleşimden çekilir, dokunma almaz.
  el.style.position = 'absolute';
  el.style.width = '1px';
  el.style.height = '1px';
  el.style.opacity = '0';
  el.style.pointerEvents = 'none';
  el.style.border = 'none';
  el.style.padding = '0';
  el.setAttribute('tabindex', '-1');
  el.setAttribute('aria-hidden', 'true');
  // Runtime tipi native date KALIR (kaynakta type="text"): openM'in boş
  // tarih alanlarını bugun() ile dolduran yazarı (utils/modal.js
  // querySelectorAll('input[type=date]')) ve native value sanitizasyonu
  // birebir çalışmaya devam eder. Kullanıcı bu inputa asla dokunamaz
  // (pointer-events:none, görünmez); yüzey butondur.
  el.type = 'date';
  // Yazıcı kancası: ISO yazan kod buton etiketini de güncellesin. Saklama
  // native'de kalır (izole dünya / toHaveValue / inputValue aynı ISO'yu görür).
  const self = el;
  Object.defineProperty(el, 'value', {
    configurable: true,
    /**
     * nativeValue nesnesinin get metodu çağrılarak elde edilen değeri döndürür.
     * @returns {*} nativeValue.get() çağrısının sonucu.
     */
    get(){ return nativeValue.get.call(self); },
    set(iso){
      nativeValue.set.call(self, tarihGecerliMi(iso) ? iso : '');
      tarihAlanEtiketGuncelle(self);
    }
  });
  el.addEventListener('input', () => tarihAlanEtiketGuncelle(el)); // dış yazım (fill vb.)
  // Görünür yüzey: taşıyıcının sınıfını ve Orijinal stilini devralır;
  // yerleşim-kaçış stilleri kopyalanmaz.
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.id = id + '-btn';
  btn.className = el.className || '';
  btn.setAttribute('style', eskiStil);
  btn.style.cssText += ';cursor:pointer;text-align:left;color:var(--ink)';
  btn.setAttribute('aria-haspopup', 'dialog');
  const flbl = el.previousElementSibling; // <label class="flbl"> — varsa ekran okuyucu bağlamı
  if(flbl && flbl.classList && flbl.classList.contains('flbl')) btn.setAttribute('aria-label', (flbl.textContent || '').trim());
  btn.addEventListener('click', () => tarihAlaniTakvimAc(el, o));
  el.insertAdjacentElement('afterend', btn);
  tarihAlanEtiketGuncelle(el);
  return el;
}
/**
 * Verilen tarih alanı elemanına bağlı butonun metnini günceller.
 * Tarih geçerliyse ISO formatında Türkçe karşılığını, değilse placeholder'ı veya varsayılan formatı gösterir.
 * @param {HTMLElement} el Tarih alanı elemanı.
 * @returns {void}
 */
function tarihAlanEtiketGuncelle(el){
  const btn = document.getElementById(el.id + '-btn');
  const nativeValue = _tarihAlanValueDescriptor();
  if(!btn || !nativeValue) return;
  const iso = nativeValue.get.call(el);
  const metin = tarihGecerliMi(iso) ? '📅 ' + tarihIsoTr(iso)
                                    : '📅 ' + (el.getAttribute('placeholder') || 'gg.aa.yyyy');
  if(btn.textContent !== metin) btn.textContent = metin;
}
/**
 * Belirtilen alan ve opsiyonel ayarlar üzerinden geçerli tarih sınırlarını belirleyerek tek tarih takvimi açar.
 * @param {HTMLElement} el Tarih seçimi için kullanılan input alanı elemanı.
 * @param {Object} o Takvim ayarlarını içeren opsiyonel nesne (min, max, baslik, temizlenebilir, kapaliGun vb.).
 * @returns {void} Takvimi açar, döndürülen bir değer yoktur.
 */
function tarihAlaniTakvimAc(el, o){
  // Dinamik sınırlar: alanın .min/.max'ına yazan kod önce gelir (ISO);
  // max: 'bugun' her açılışta taze değerlendirilir (LOAD-time referans YOK —
  // ui.js vm-sandbox'ta da yüklenir, bugun orada tanımsızdır); fonksiyon da
  // kabul edilir.
  const alanMin = tarihGecerliMi(el.min) ? el.min : null;
  const alanMax = tarihGecerliMi(el.max) ? el.max : null;
  const optMin = o.min === 'bugun' ? bugun() : (typeof o.min === 'function' ? o.min() : o.min);
  const optMax = o.max === 'bugun' ? bugun() : (typeof o.max === 'function' ? o.max() : o.max);
  tekTarihTakvimAc({
    baslik: o.baslik || '📅 Tarih Seç',
    deger: el.value || null,
    min: alanMin || optMin || null,
    max: alanMax || optMax || null,
    temizlenebilir: o.temizlenebilir === true,
    // F3 (G-20260913): şemadaki kapaliGun SESSİZCE DÜŞÜRÜLMEZ — fonksiyon
    // değilse null (bileşen kapalı-gün katmanını devre dışı bırakır).
    kapaliGun: typeof o.kapaliGun === 'function' ? o.kapaliGun : null,
    /**
     * Verilen ISO tarih değerini elemana atar; değer değiştiyse native 'change' olayı tetikler.
     * @param {string} iso - Elemana atanacak ISO tarih değeri; boş/falsy ise değeri temizler.
     * @returns {void} Döndürme değeri yok.
     */
    onSec: iso => {
      // Native parite: değer gerçekten değişmediyse change YAYILMAZ.
      const eski = el.value;
      el.value = iso || '';
      // data-change bağlanan akışlar (ör. a-dt → animal-guncelle) native
      // seçimle aynı olayı alsın.
      if(el.value !== eski) el.dispatchEvent(new Event('change', { bubbles: true }));
    }
  });
}
// Alan sözleşme tablosu — her alan okuyucu/yazıcı bağlamına göre:
// · max: 'bugun'  → submit doğrulaması 'ileri tarih olamaz' diyen alanlar
// · temizlenebilir → submit yolu boş değeri meşru karşılayan alanlar
// · kapaliGun: (iso) → true  → o gün seçilemez (F3 plumbing; henüz alan
//   kullanmıyor — bileşene iletimi tarihAlaniTakvimAc'ta garantili)
// · sınırsız      → görev hedef tarihleri (ta/te) — gelecek meşru
const TARIH_ALANLARI = {
  'k-tarih':        { max: 'bugun' },                       // kızgınlık tarihi
  'i-tarih':        { max: 'bugun' },                       // tohumlama tarihi
  'tr-tarih':       { max: 'bugun' },                       // tekrar aşım tarihi
  'v-date':         { max: 'bugun' },                       // aşı uygulama
  'bv-tarih':       { max: 'bugun' },                       // toplu aşı — tek-aşı kuralıyla aynı kural
  'sk-tarih':       { max: 'bugun', temizlenebilir: true }, // sütten kesme — okuyucu boşa bugun() der
  'b-tarih':        { max: 'bugun' },                       // doğum tarihi — ileri olamaz
  'a-dt':           { max: 'bugun', temizlenebilir: true }, // hayvan doğumu — boş geçilebilir (|| null)
  'ta-tarih':       {},                                     // görev hedefi — gelecek serbest
  'td-asi-tarih':   { max: 'bugun', temizlenebilir: true }, // detay açılışta .max=bugün yazar
  'td-rapel-tarih': {},                                     // pencere .min/.max ile gelir (parent+14..21);
                                                            // temizlenebilir DEĞİL — kayıt yolu boşu reddeder
  'te-tarih':       {},                                     // görev düzenle — gelecek serbest
  'cx-tarih':       { max: 'bugun' },                       // süründen çıkış olayı
  'geb-tarih':      { max: 'bugun' },                       // gebelik teşhisi
};
/**
 * TARIH_ALANLARI içindeki her tarih alanını ilgili ayarlarla bağlar.
 * @returns {void} Değer döndürmez.
 */
function tarihAlanlariniBagla(){
  for(const id in TARIH_ALANLARI) tarihAlaniBagla(id, TARIH_ALANLARI[id]);
}

// Şablon ilk-gün adapteri — çapa tarihi _cdSablonTarih'te kalır.
let _cdSablonTarih = null; // ISO — şablon çapa tarihinin TEK kaynağı
/**
 * Şablonun ilk gününü seçmek için tek tarih seçimli takvim penceresi açar; seçilen tarihi _cdSablonTarih'e kaydeder ve etiketi günceller.
 * @returns {void}
 */
function cdSablonTarihTakvimAc(){
  tekTarihTakvimAc({
    baslik: '📅 Şablonun İlk Günü — Takvimden Seç',
    deger: _cdSablonTarih,
    /**
     * Verilen ISO tarih değerini şablon tarih değişkenine atar ve tarih etiketini günceller.
     * @param {string} iso - Şablon tarihine atanacak ISO formatındaki tarih değeri.
     * @returns {void} Değer döndürmez.
     */
    onSec: iso => { _cdSablonTarih = iso; cdSablonTarihEtiketGuncelle(); }
  });
}
/**
 * Sablonun ilk gününü alıp buton metnini günceller.
 * @returns {void}
 */
function cdSablonTarihEtiketGuncelle(){
  const btn = document.getElementById('cd-sablon-tarih-btn');
  if(btn) btn.textContent = '📅 Şablonun ilk günü: ' + fmtTarih(_cdSablonTarih);
}

function caseSablonToggle(){
  const alan = document.getElementById('cd-sablon-alan');
  if(!alan) return;
  const aciliyor = alan.style.display !== 'block';
  alan.style.display = aciliyor ? 'block' : 'none';
  if(aciliyor){
    if(!_cdSablonTarih) _cdSablonTarih = bugun();
    cdSablonTarihEtiketGuncelle();
    caseSablonListeRender();
  }
}

/**
 * Belirli bir hastalığa bağlı tedavi şablonlarını (ad, gün sayısı, seans sayısı, tohumlama bilgisi) içeren bir liste oluşturur ve ekranda gösterir.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function caseSablonListeRender(){
  const list = document.getElementById('cd-sablon-list');
  if(!list || !_curCase) return;
  // Yalnız VAKANIN hastalığına bağlı şablonlar — açılış listesiyle aynı
  // kaynak (sablon_hastalik_eslem; bcSablonYukleListeRender deseni).
  const [eslem, sablonlar, kalemler] = await Promise.all([
    idbGetAll('sablon_hastalik_eslem'), idbGetAll('tedavi_sablonu'), idbGetAll('tedavi_sablonu_kalem')
  ]);
  const liste = cdSablonListeBul(eslem, sablonlar, kalemler, _curCase.disease_id);
  if(!liste.length){
    list.innerHTML = '<div style="font-size:.74rem;color:var(--ink3);padding:4px 0">Bu hastalık için kayıtlı şablon yok.</div>';
    return;
  }
  list.innerHTML = liste.map(s =>
    '<div style="display:flex;align-items:center;gap:8px;padding:5px 0;font-size:.8rem;border-bottom:1px solid var(--card3)">' +
    '<span style="flex:1;min-width:0;font-weight:600;color:var(--ink)">' + esc(s.ad) +
    '<span style="color:var(--ink2);font-size:.72rem;font-weight:400"> — ' + s.gun + ' gün · ' + s.seans + ' seans' +
    (s.tohumVar ? ' · 🐄 tohumlama' : '') + '</span></span>' +
    '<button type="button" class="ek-chip" data-action="cd-sablon-uygula" data-sablon-id="' + escAttr(s.id) +
    '" style="font-weight:700;color:var(--blue);border-color:rgba(42,107,181,.4)">Uygula</button></div>'
  ).join('');
}

/**
 * Verilen şablon ID'si için tedavi şablonunu uygular, planlı tohumlama görevlerini ekler,
 * ilgili tabloları günceller ve zaman çizelgesini yeniden render eder.
 * @param {string} sablonId Uygulanacak şablonun benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc tedavi_sablon_tohumlama_gorev_ekle, tedavi_sablon_uygula
 */
async function caseSablonUygula(sablonId){
  if(!sablonId || !_curCase) return;
  if(!navigator.onLine){ toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const tarih = _cdSablonTarih;
  if(!tarih){ toast('Şablonun ilk gününü seçin', true); return; }
  try {
    const r = await rpc('tedavi_sablon_uygula',
      { p_case_id: _curCase.id, p_sablon_id: sablonId, p_baslangic_tarihi: tarih });
    let tohumMsg = '';
    // submitCase (forms.js:620-624) toast dili birebir; ikinci RPC ayrı
    // try'da — günler zaten eklendi, tazeleme atlanmamalı.
    try {
      const planli = await rpc('tedavi_sablon_tohumlama_gorev_ekle',
        { p_case_id: _curCase.id, p_sablon_id: sablonId, p_baslangic_tarihi: tarih });
      if(planli?.sebep) toast(`ℹ️ Planlı tohumlama görevi açılmadı: ${planli.sebep}`, true);
      if(planli?.olustu) tohumMsg = ' + tohumlama';
    } catch(e) { toast('Şablon günleri eklendi ama planlı tohumlama açılamadı: ' + e.message, true); }
    if(r?.atlanan?.length) toast(`⚠️ ${r.atlanan.length} kalem atlandı (silinmiş ilaç)`, true);
    toast(`✅ Şablon uygulandı (${r?.gun_sayisi||0} gün)${tohumMsg}`);
    const alan = document.getElementById('cd-sablon-alan');
    if(alan) alan.style.display = 'none';
    await pullTables(['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log','islem_log']);
    _drugsCache = [];
    await loadDrugsCache();
    await renderCaseTimeline(_curCase.id);
    _updateKapatBtn(_curCase.id);
  } catch(e) { toast(getUserMessage(e), true); }
}

// ── VAKAYA PLANLI TOHUMLAMA ────────────────────────────────────────────────
// Tohumlama ilaç gibi vakanın bir kalemi; ama kaydı tohumlama_kaydet zinciri
// üzerinden gitmek zorunda (sperma, VWP, gebelik kontrol görevleri). Bu yüzden
// kart yalnızca planı taşır, kayıt planlı tohumlama formuna devreder.
/**
 * Eğer mevcut durum yoksa işlemi iptal eder, yoksa 'cd-toh-form' elementini kaldırıp yeni bir tohumlama ekleme formu oluşturur.
 * Formda bugünün tarihi, saat seçimi ve ekleme/vazgeç butonları bulunur.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
      '<label style="flex:2;font-size:.7rem;color:var(--ink3)">Tarih' +
      '<input type="hidden" id="cdt-tarih" value="' + bugunTr + '">' +
      '<button type="button" id="cdt-tarih-btn" data-action="cdt-takvim-ac" style="width:100%;margin-top:3px;background:var(--card);border:1px solid var(--card3);border-radius:8px;padding:8px;font-size:.8rem;font-weight:600;color:var(--ink);cursor:pointer;text-align:left">📅 ' + fmtTarih(bugunTr) + '</button></label>' +
      '<label style="flex:1;font-size:.7rem;color:var(--ink3)">Saat<input id="cdt-saat" class="fi" type="time" value="08:00" style="margin-top:3px"></label>' +
    '</div>' +
    '<div style="display:flex;gap:6px">' +
      '<button onclick="caseTohumlamaEkleOnayla(this)" style="flex:1;background:var(--green);color:#fff;border:none;border-radius:8px;padding:9px;font-size:.76rem;font-weight:700;cursor:pointer">Ekle</button>' +
      '<button onclick="document.getElementById(\'cd-toh-form\').remove()" style="flex:1;background:var(--card2);color:var(--ink2);border:1px solid var(--card3);border-radius:8px;padding:9px;font-size:.76rem;cursor:pointer">Vazgeç</button>' +
    '</div>';
  document.getElementById('cd-gun-bolum')?.appendChild(div);
}

// Tohumlama tarihi — kanonik tek-tarih takvimi (cdt-tarih hidden input'a yazar).
/**
 * Tohumlama tarihi takvimini açar; seçilen tarihi 'cdt-tarih' inputuna yazar ve 'cdt-tarih-btn' düğmesinin metnini biçimlendirilmiş tarihle günceller.
 * @returns {void}
 */
function cdtTakvimAc(){
  tekTarihTakvimAc({
    baslik: '📅 Tohumlama Tarihi — Takvimden Seç',
    deger: document.getElementById('cdt-tarih')?.value || bugun(),
    onSec: iso => {
      const inp = document.getElementById('cdt-tarih');
      if(inp) inp.value = iso;
      const btn = document.getElementById('cdt-tarih-btn');
      if(btn) btn.textContent = '📅 ' + fmtTarih(iso);
    }
  });
}

/**
 * Seçili vaka için tohumlama planı ekler, formu kaldırır ve zaman çizelgesini günceller.
 * @param {HTMLElement} btn Tıklanan buton elemanı; işlem başarılıysa devre dışı bırakılır, başarısızsa tekrar aktif edilir.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda çözülür.
 * @rpc vaka_tohumlama_ekle
 */
async function caseTohumlamaEkleOnayla(btn) {
  if (!_curCase) return;
  const tarih = document.getElementById('cdt-tarih')?.value;
  const saat  = document.getElementById('cdt-saat')?.value || '08:00';
  if (!tarih) { toast('Tarih seçin', true); return; }  if (btn) { btn.disabled = true; btn.textContent = 'Ekleniyor…'; }
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

/**
 * Verilen görev ID'sine sahip planlı tohumlama görevini bulur, detay ekranını kapatır ve görev detaylarını gösteren ekrana yönlendirir.
 * @param {number|string} gorevId - İşlenecek görevin benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function caseTohumlamaKaydet(gorevId) {
  const g = (await idbGetAll('gorev_log')).find(x => x.id === gorevId);
  if (!g) { toast('Planlı tohumlama görevi bulunamadı', true); return; }
  closeM('m-case-det');
  openPlanliTohumlama(g);
}

/**
 * Verilen görev ID'sine sahip planlı tohumlama görevini iptal eder, durumu günceller ve ilgili arayüzü yeniler.
 * @param {string} gorevId İptal edilecek görevin benzersiz kimlik numarası.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda çözülür.
 */
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
/**
 * Belirtilen gün ID'sine ait ilaç formunu oluşturur, eski formları temizler ve stoktaki ilaçları gruplandırarak HTML olarak render eder.
 * @param {string} dayId İşlenecek günün ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirtilen ID'ye sahip bir kontrol kutusu (checkbox) seçildiğinde ilgili doz satırını, seçilmediğinde ise kaldırır.
 * Seçili kontrol kutusu varsa doz giriş alanını gösterir, yoksa gizler.
 * @param {HTMLElement} chk Seçilen veya seçilmeyen kontrol kutusu elemanı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function cdfChkChange(chk) {
  const id = chk.dataset.id;
  const name = chk.dataset.name;
  const unit = chk.dataset.unit || 'ml';
  const route = chk.dataset.route || 'IM';
  const satirlar = document.getElementById('cdf-doz-satirlar');
  const alan = document.getElementById('cdf-doz-alani');
  if (!satirlar || !alan) return;
  // Hayvan bağlamı yalnız vaka detay modalı AÇIKKEN geçerli — bayat _curCase
  // şablon builder'a sızmasın (orada hayvan yok, buton da üretilmez).
  const _vakaHayvanId = document.getElementById('m-case-det')?.classList.contains('on')
    ? (_curCase?.animal_id || '') : '';
  if (chk.checked) {
    const row = document.createElement('div');
    row.id = 'cdf-row-' + id;
    row.style.cssText = 'background:rgba(78,154,42,.06);border:1px solid rgba(78,154,42,.2);border-radius:8px;padding:8px;margin-bottom:6px';
    row.innerHTML =
      '<div style="font-size:.78rem;font-weight:700;color:var(--green);margin-bottom:5px">'+name+'</div>'+
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">'+
      '<div style="display:flex;gap:4px">'+
      '<input type="number" min="0.01" step="0.01" placeholder="Doz" class="fi cdf-dose-inp" data-drug-id="'+id+'" style="margin:0;flex:1;min-width:0">'+
      _dozHintBtnHtml('', id, _vakaHayvanId)+
      '</div>'+
      '<input type="text" placeholder="Birim" value="'+unit+'" class="fi cdf-unit-inp" data-drug-id="'+id+'" style="margin:0">'+
      '<select class="fsel cdf-route-inp" data-drug-id="'+id+'" style="margin-top:5px">'+
      '<option value="">Uygulama yolu</option>'+
      '<option '+(route==='IM'?'selected':'')+' value="IM">IM — Kas ici</option>'+
      '<option '+(route==='IV'?'selected':'')+' value="IV">IV — Damar ici</option>'+
      '<option '+(route==='SC'?'selected':'')+' value="SC">SC — Deri alti</option>'+
      '<option '+(route==='PO'?'selected':'')+' value="PO">PO — Agizdan</option>'+
      '<option value="Topikal">Topikal</option>'+
      '<option value="Intrauterin">Intrauterin</option>'+
      '<option value="Meme içi">Meme içi</option>'+
      '</select>';
    satirlar.appendChild(row);
  } else {
    document.getElementById('cdf-row-' + id)?.remove();
  }
  const checked = document.querySelectorAll('.cdf-chk:checked').length;
  alan.style.display = checked > 0 ? 'block' : 'none';
}

/**
 * Herhangi bir işlem gerçekleştirmeyen boş bir fonksiyon.
 * @returns {void}
 */
function cdfDrugAc() {}
function cdfDrugSec() {}
/**
 * Seçili ilaç checkbox'ları için doz, birim ve uygulama yolu bilgilerini toplar;
 * online durumuna göre RPC veya offline (write) yöntemiyle ilaç uygulama kayıtlarını oluşturur,
 * stok hareketlerini ekler, ilgili tabloları günceller ve formu temizler.
 * @param {HTMLElement} btn Kayıt işlemi tetiklenen buton elemanı.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda çözülür.
 * @rpc add_drug_administration
 */
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

/**
 * Kullanıcıdan onay alarak ilaç uygulama kaydını siler, ilgili tabloları yeniler ve vaka zaman çizelgesini günceller.
 * @param {number|string} adminId - Silinecek ilaç uygulama kaydının kimliği.
 * @returns {Promise<void>} Hiçbir değer döndürmez.
 * @rpc remove_drug_administration
 */
async function caseDrugSil(adminId) {
  if (!confirm('Bu ilaç kaydı silinsin mi?')) return;
  try {
    await rpc('remove_drug_administration', { p_admin_id: adminId });
    toast('✅ Silindi');
    await pullTables(['stok','stok_hareket','drug_administrations']);
    await renderCaseTimeline(_curCase.id);
  } catch(e) { toast(e.message, true); }
}

/**
 * Kullanıcı onayından sonra belirtilen tedavi gününü ve içindeki tüm ilaçları siler; ilgili tabloları ve önbellekleri yeniler, zaman çizelgesini ve stok panelini günceller.
 * @param {string|number} dayId - Silinecek tedavi gününün kimliği.
 * @returns {Promise<void>} İşlem tamamlanınca çözülen Promise; hiçbir değer döndürmez.
 * @rpc delete_treatment_day
 */
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

/**
 * Belirtilen ilaç satırındaki doz, birim ve uygulama yolu bilgilerini düzenlenebilir bir form içine yükler.
 * @param {HTMLElement} btn Düzenlenecek olan ilaç satırındaki buton elemanı.
 * @returns {void}
 */
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
    '<option '+(route==='Meme içi'?'selected':'')+' value="Meme içi">Meme içi</option>' +
    '</select>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">' +
    '<button onclick="caseDrugDuzenleKaydet(this.closest(\'.drug-edit-form\').dataset.adminId)" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:7px;font-weight:700;cursor:pointer">Kaydet</button>' +
    '<button onclick="this.closest(\'.drug-edit-form\').remove()" style="background:var(--card3);border:none;border-radius:7px;padding:7px;cursor:pointer">Iptal</button>' +
    '</div>';
  row.insertAdjacentElement('afterend', form);
}

/**
 * Belirtilen admin ID'ye ait ilaç dozunu, birimini ve uygulama yolunu doğrulayıp günceller,
 * formu kaldırır, ilgili tabloları yeniden çeker ve zaman çizelgesini günceller.
 * @param {number|string} adminId Güncellenecek kayıt için admin kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @rpc update_drug_administration
 */
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


/**
 * Kullanıcı onayı alındıktan sonra mevcut vakayı kapatır, ilgili tabloları günceller ve vaka detaylarını yeniden açar.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata durumunda undefined döndürür.
 * @rpc close_case
 */
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


/**
 * Belirtilen vaka ID'sine ait tedavi ilaç kayıtlarını getirir ve HTML listesi elemanına render eder.
 * Kayıt bulunamazsa veya hata oluşursa uygun hata mesajını gösterir.
 * @param {string} vakaId - İlaç kayıtlarının getirileceği vaka ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 * @tablo tedavi_view (select)
 */
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
/**
 * Kullanıcıdan alınan arama sorgusuna göre 'İlaç' kategorisindeki stok ürünlerini filtreler ve listeleyici elemanını günceller.
 * @param {Object} inp Arama sorgusu için kullanılan input elemanı.
 * @returns {void}
 * @tablo stok (select)
 */
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
/**
 * Verilen stok bilgilerini ilgili form alanlarına yerleştirir ve 'ac-hdi' elementini gizler.
 * @param {string} id Stok ID'si.
 * @param {string} ad Stok adı.
 * @param {string} birim Stok birimi.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function hdiStokSec(id,ad,birim){
  document.getElementById('hdi-stok-id').value=id;
  document.getElementById('hdi-stok-ac').value=ad;
  document.getElementById('hdi-birim').value=birim;
  document.getElementById('ac-hdi').style.display='none';
}

// ──────────────────────────────────────────
// TOHUMLAMA DETAY MODAL
// ──────────────────────────────────────────
/**
 * Belirli bir tohumlama kaydını ID'ye göre getirir, ilgili hayvan ve hekim bilgilerini doldurur,
 * durum bazlı UI elemanlarını (radio butonlar, mesajlar, geri alma butonları) günceller ve
 * önceki deneme geçmişini listeler.
 * @param {string} id Tohumlama kaydının benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
/**
 * Belirtilen küpeyi tohumlayarak işlemi başlatır ve ilgili detay ekranını kapatır.
 * @param {string} kupe - Tohumlanacak küpe kimliği.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function tekrarTohumla(kupe) {
  closeM('m-toh-det');
  openInsemSafe(kupe);
}
// tohSonuc → forms.js'de tanımlı (guard'lı versiyon)

// ──────────────────────────────────────────
// SPERMA AUTOCOMPLETE
// ──────────────────────────────────────────
/**
 * Sperma otomatik tamamlama kutusunu, arama girdisine göre stok, sabit liste, özel kayıtlar ve kullanılmış sperma adlarıyla doldurur; stokta 5 doz ve altı olanları uyarı işaretiyle gösterir.
 * @returns {Promise<void>} Hiçbir değer döndürmez.
 */
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
/**
 * Verilen değeri 'i-sperma' inputuna atar, 'ac-sperma' elementini gizler ve sperma ipucu güncellemesini bekler.
 * @param {any} val Inputa atılacak değer.
 * @returns {Promise<void>} Güncelleme işleminin tamamlandığını gösteren Promise.
 */
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
/**
 * 'stok' tablosundan tüm kayıtları getirir, kategori 'Sperma' olanları filtreler ve
 * guncel_stok alanını sayıya çevirerek (varsa) yeni nesne oluşturup döndürür.
 * @returns {Array} Kategori 'Sperma' olan stok kayıtlarından oluşan dizi.
 */
async function getSpermaStok(){
  const all=await idbGetAll('stok');
  return all.filter(s=>s.kategori==='Sperma').map(s=>({...s,guncel:+s.guncel_stok||0}));
}
async function dusSpermaStok(spermaAdi){
  const st=await getSpermaStok();
  const s=st.find(x=>x.urun_adi===spermaAdi);
  if(s&&s.guncel>0) await write('stok_hareket',{id:crypto.randomUUID(),stok_id:s.id,tur:'Tohumlama',miktar:1,notlar:'Tohumlama',iptal:false});
}
/**
 * Sperma stokunu getirerek güncel stok seviyesi 5 veya daha az olan ürünleri belirler ve kritik uyarı bandını günceller.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function checkSpermaUyari(){
  const st=await getSpermaStok();
  const critik=st.filter(s=>s.guncel<=5&&s.guncel>=0);
  const bnd=document.getElementById('sperma-warn-band'); if(!bnd) return;
  if(critik.length>0){
    bnd.style.display='flex';
    bnd.textContent='⚠️ Kritik sperma stoku: '+critik.map(s=>`${esc(s.urun_adi)} (${s.guncel} doz)`).join(', ');
  } else { bnd.style.display='none'; }
}
/**
 * Sperma stok alanını gösterir, elle giriş alanını gizler ve sperma seçim listesini günceller.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * Seçili spermanın stok bilgisini okuyup ilgili alanları günceller, stok durumuna göre uyarı mesajı gösterir ve kaydet butonunun aktifliğini değiştirir.
 * @param {HTMLSelectElement} sel Sperma seçeneği elemanı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * Tohumlama (inseminasyon) ekranında sperma girişini "elle giriş" moduna geçirir: stok alanını gizler, elle giriş alanını gösterir, ilgili butonların arka planlarını günceller, sperma ve ipucu alanlarını temizler ve kaydet butonunu etkinleştirir.
 * @returns {void}
 */
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

/**
 * Sperma stok alanını gösterir, elle giriş alanını gizler ve sperma seçici listesini doldurur.
 * @returns {void}
 */
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
/**
 * Sperma seçici elemanın değeri ve stok bilgisini alarak arayüzü günceller.
 * Seçili spermanın stok durumuna göre uyarı mesajı gösterir ve kaydet butonunun aktifliğini değiştirir.
 * @param {HTMLSelectElement} sel Sperma seçici elemanı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * Sperma kaydını manuel giriş moduna geçirir: stok alanını gizler, elle giriş alanını gösterir, ilgili butonların stilini günceller, giriş alanını ve ipucu metnini temizler ve kaydet butonunu etkinleştirir.
 * @returns {void}
 */
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
/**
 * Stok açılır listesinde arama sorgusuna göre eşleşen ilaçları listeler ve açılır paneli görünür kılar.
 * Sorgu boşsa ilk 12 ilacı gösterir; eşleşme yoksa uyarı mesajı görüntüler.
 * İlaç önbelleği boşsa önce önbelleği yeniler.
 * @returns {Promise<void>} Hiçbir değer döndürmez; açılır paneli güncelleyerek tamamlanır.
 */
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
/**
 * Seçilen ilaç bilgisini stok form alanlarına yazar ve birim/stok ipucunu görüntüler; stok 5'in altındaysa uyarı gösterir.
 * @param {*} id - d-stok alanına yazılacak ilaç kimliği.
 * @param {*} ad - d-stok-ac alanına yazılacak ilaç adı.
 * @param {*} birim - İpucu metninde gösterilecek birim; 'adet' ise stok 0, aksi halde 1 ondalık basamakla gösterilir.
 * @param {*} guncel - İpucunda gösterilen güncel stok miktarı; 5'e eşit veya küçükse kırmızı renk ve uyarı işaretiyle gösterilir.
 * @returns {void} Değer döndürmez.
 */
function selIlac(id,ad,birim,guncel){
  document.getElementById('d-stok-ac').value=ad;
  document.getElementById('d-stok').value=id;
  document.getElementById('ac-dilac').style.display='none';
  const hint=document.getElementById('d-stok-hint');
  if(hint){ const warn=guncel<=5; hint.innerHTML=`Birim: <b>${birim}</b> · Stok: <b style="color:${warn?'var(--red)':'var(--green)'}">${guncel.toFixed(birim==='adet'?0:1)} ${birim}</b>${warn?' ⚠️':''}`; }
}
/**
 * Yeni bir ilaç satırı oluşturup 'ilac-rows' konteynerına ekler.
 * Satır, ilaç arama inputu, stok ID gizli inputu, miktar inputu ve satırı silme butonundan oluşur.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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
/**
 * Seçilen ilaç satırındaki form elemanlarını (stok adı, ID, miktar) ilgili değerlerle günceller ve 'ilac-ac' kutusunu gizler.
 * @param {HTMLElement} el Tıklanan veya seçilen temel HTML elementi.
 * @param {string} id İlaçın benzersiz kimlik numarası (ID).
 * @param {string} ad İlaçın stok adı.
 * @param {string} birim İlaç miktarının birimi (varsayılan: 'miktar').
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Tüm hayvanların durumunu kontrol edip sadece 'Aktif' olanları filtreleyerek döndürür.
 * @returns {Array} Durumu 'Aktif' olan hayvan nesnelerinden oluşan dizi.
 */
function _activeAnimalsOnly(){
  return getState('animals').filter(a=>a.durum==='Aktif');
}

/**
 * Belirtilen giriş kutusu ID'sinden alınan arama sorgusuna göre hayvan listesini filtreler, sıralar ve HTML olarak listeye ekler.
 * @param {string} inputId Arama sorgusu için kullanılan giriş elemanının ID'si.
 * @param {string} listId Hayvan listesini göstermek için hedef elemanın ID'si.
 * @returns {void}
 */
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
    /**
     * Verilen nesnenin 'kupe_no', 'devlet_kupe' veya 'id' alanlarından ilk bulunanı alıp string olarak döndürür.
     * @param {Object} a Nesne nesnesi.
     * @returns {String} Nesnenin kimlik bilgisi içeren string veya boş string.
     */
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
/**
 * Belirtilen ID'li input'un değerini ayarlar ve list ID'li elemanı gizler;
 * 'd-hid' input seçildiğinde ve loadDiseasesDropdown fonksiyonu mevcutsa bu fonksiyonu çağırarak hastalık dropdown'unu günceller.
 * @param {string} inputId Değeri ayarlanacak input elementinin ID'si.
 * @param {string} listId Gizlenecek liste elementinin ID'si.
 * @param {*} val Ayarlanacak input değeri.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function selHayvan(inputId,listId,val){
  const el=document.getElementById(inputId); if(el) el.value=val;
  const ac=document.getElementById(listId); if(ac) ac.style.display='none';
  // K6 — hayvan seçimi hastalık dropdown'unu kısır kilidiyle tazeler (cila2 C1 aynası)
  if(inputId==='d-hid' && typeof loadDiseasesDropdown==='function') loadDiseasesDropdown();
}
// G-20260906-TOPLU-VAKA — m-bulk-case çoklu küpe autocomplete.
// acHayvan klonu (tek-select akışı %100 korunur): satır seçimi inputa YAZMAZ,
// onPick(hayvan)'ı çağırır, inputu temizler, odağı korur ve listeyi kapatır.
// Kaynak sözleşmesi ac-dhid dalı ile aynı: yalnız aktif hayvanlar.
// Satırlar statik onclick="bcAcSatirSec(this)" + data-kupe (escAttr) —
// interpole onclick yok; acNav div[onclick] seçicisi böylece çalışmaya devam eder.
/**
 * Aktif hayvanları arama sorgusuna göre sıralayıp açılır otomatik tamamlama listesini doldurur ve görünür hale getirir. Boş sorguda ilk 10 hayvanı küpe numarasına göre Türkçe sıralama ile, dolu sorguda `srchAdaySirala` sonuçlarını katman (tier) bilgisiyle listeler; eşleşme yoksa uyarı mesajı gösterir.
 * @param {string} inputId - Arama sorgusunun okunacağı input öğesinin kimliği; bağlam (context) kaydına da yazılır.
 * @param {string} listId - Sonuç satırlarının basılacağı açılır liste öğesinin kimliği; bulunamazsa fonksiyon hiçbir işlem yapmadan döner.
 * @param {Function} onPick - Bir satır seçildiğinde çağrılacak geri çağırım; global bağlam kaydında saklanır.
 * @returns {void} Değer döndürmez; açılır liste DOM'unu günceller.
 */
function acHayvanMulti(inputId,listId,onPick){
  globalThis._bcAcCtx={inputId,listId,onPick};
  const inp=document.getElementById(inputId);
  const q=(inp?.value||'').trim();
  const ac=document.getElementById(listId); if(!ac) return;
  const src=_activeAnimalsOnly();
  let rows;
  if(!q){
    /**
     * Verilen nesnenin 'kupe_no', 'devlet_kupe' veya 'id' alanlarından ilk bulunanı alıp string olarak döndürür.
     * @param {Object} a Nesne nesnesi.
     * @returns {String} Nesnenin kimlik bilgisi içeren string veya boş string.
     */
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
    const kupeHtml=tier===6?esc(kupe):vurguHtml(kupe,q);
    const sagParcalar=[];
    if(a.kupe_no&&a.devlet_kupe&&a.devlet_kupe!==a.kupe_no&&(tier===1||tier===3||tier===5)) sagParcalar.push(vurguHtml(a.devlet_kupe,q));
    if(tier===6&&a.irk) sagParcalar.push(vurguHtml(a.irk,q));
    else if(a.irk) sagParcalar.push(esc(a.irk));
    if(a.padok) sagParcalar.push(esc(a.padok));
    return `<div data-kupe="${escAttr(kupe)}" onclick="bcAcSatirSec(this)" style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid var(--card3);display:flex;justify-content:space-between;gap:8px">
      <span style="font-weight:600">${kupeHtml}</span>
      <span style="color:var(--ink3);font-size:.7rem;text-align:right">${sagParcalar.join(' · ')}</span>
    </div>`;
  }).join('');
  ac.style.display='block';
  if(inp && document.activeElement!==inp){ inp.focus(); }
}
// acHayvanMulti satır seçimi — dataset.kupe'den hayvanı çözer (K7 aktif öncelikli),
// inputu temizler, odağı korur, listeyi kapatır, onPick(hayvan)'ı tetikler.
/**
 * Belirtilen elemanın bağlı olduğu '.ac-box' kutusunu gizler,
 * varsa input alanını temizler ve odaklar,
 * kupe referansını alıp onPick callback'ini tetikler.
 * @param {HTMLElement} el Tıklanan veya seçilen HTML elemanı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function bcAcSatirSec(el){
  const ctx=globalThis._bcAcCtx||{};
  const ac=el?.closest('.ac-box'); if(ac) ac.style.display='none';
  const inp=ctx.inputId?document.getElementById(ctx.inputId):null;
  const h=hayvanByKupeRef(el?.dataset.kupe);
  if(inp){ inp.value=''; inp.focus(); }
  if(h&&typeof ctx.onPick==='function') ctx.onPick(h);
}
document.addEventListener('click',e=>{
  ['ac-ihid','ac-dhid','ac-banne','ac-sperma','ac-bchid'].forEach(id=>{
    const ac=document.getElementById(id);
    if(ac&&!e.target.closest('#'+id)) ac.style.display='none';
  });
});
/**
 * Otomatik tamamlama listesinde klavye ile gezinmeyi yönetir: ok tuşlarıyla seçim, Enter ile aktivasyon ve Escape ile kapatma.
 * @param {KeyboardEvent} e - Klavye olayı; ArrowDown, ArrowUp, Enter ve Escape tuşları işlenir.
 * @param {string} listId - Otomatik tamamlama listesi elemanının kimliği.
 * @returns {void} Hiçbir değer döndürmez.
 */
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
/**
 * Belirtilen modalı açar, input'a verilen değer atar ve ilgili autocomplete dropdown'ları gizler.
 * Modal'a göre hastalık, aşı, toplu aşı, toplu ilaç veya inseminasyon modallarını açarak
 * ilgili dropdown'ları yükler veya inseminasyon sorunu toggle durumunu sıfırlar.
 * @param {string} modalId Açılacak modal'ın ID'si.
 * @param {string} inputId Değer atanan input elementinin ID'si.
 * @param {string} kupeNo Input'a atılacak kupa numarası.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Belirtilen hayvan ID'li görev için planlı tohumlama işlemini başlatır.
 * @param {Object} gorev Görev nesnesi, içinde 'hayvan_id' ve 'id' özelliklerini içerir.
 * @returns {void} İşlem tamamlandığında veya hata durumunda döndürür.
 */
function openPlanliTohumlama(gorev){
  const hayvan=(getState('animals')||[]).find(a=>a.id===gorev.hayvan_id);
  if(!hayvan){ toast('Görevin hayvanı bulunamadı',true); return; }
  globalThis._planliTohumlamaGorevId=gorev.id;
  closeM('m-task-det');
  openMWithHayvan('m-insem','i-hid',hayvan.kupe_no||hayvan.devlet_kupe||hayvan.id);
  setTimeout(()=>{ const tarih=document.getElementById('i-tarih'); if(tarih) tarih.value=bugun(); },180); // 20260913-16: UTC yerine yerel bugün (luna BULGU-4 — gece-yarısı kayması)
}

/**
 * Belirli bir hayvanın beklenen inseminasyon tarihine kadar geçen gün sayısını hesaplayarak
 * ilgili bilgi panelini günceller ve global değişkeni ayarlar.
 * @param {Object} hayvan Hayvan nesnesi (kupe_no, devlet_kupe, id, vb. özelliklere sahip).
 * @param {Object} bekliyor Beklenen inseminasyon bilgisi nesnesi (tarih, sperma, id özellikleri).
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _openInsemIntercept(hayvan,bekliyor){
  const today=bugun();
  const gun=Math.floor((new Date(today)-new Date(bekliyor.tarih))/86400000);
  const hid=hayvan.kupe_no||hayvan.devlet_kupe||hayvan.id;
  const infoEl=document.getElementById('insem-intercept-info');
  if(infoEl) infoEl.innerHTML=`<b>${esc(hid)}</b> — ${esc(bekliyor.sperma||'?')} · <b>${gun}. gün</b> (${(bekliyor.tarih||'').slice(0,10)})`;
  globalThis._insemInterceptHayvan={id:hayvan.id,kupeNo:hid,tohId:bekliyor.id};
  openM('m-insem-intercept');
}

/**
 * Belirli bir hayvanın tohumlama kayıtlarını getirir, en güncel kaydı bulur ve bu kayıt için "Gebe" durumu işaretlenir.
 * @param {string} hayvanId İşaretlenmek istenen hayvanın ID'si.
 * @returns {void} İşlem başarılı veya başarısız olduğunda kullanıcıya bildirim gösterir.
 * @rpc tohumlama_sonuc_gebe
 */
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
/**
 * Belirtilen mod'a göre tema sınıfını ekleyip çıkarır, tercihi tarayıcı hafızasına kaydeder ve butonların arka plan rengini günceller.
 * @param {string} mode 'dark' veya 'light' değerlerinden biri.
 * @returns {void}
 */
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

/**
 * Ayarlar sayfasını açarak hekim, vaccine, padok listelerini ve grup eşleştirmelerini render eder,
 * protokol ayarlarını yeniler, tema durumuna göre buton stillerini senkronize eder ve modalı açar.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Kullanıcı onayından sonra senkron kuyruğundaki tüm bekleyen kayıtları tek tek siler, senkron çubuğunu günceller ve kaç kayıt temizlendiğini bildiren bir toast gösterir.
 * @returns {Promise<void>} Kuyruk temizlendiğinde hiçbir değer döndürmez; kullanıcı onay vermezse işlem yapılmaz.
 */
async function kuyrukTemizle(){
  if(!confirm('Kuyruktaki tüm bekleyen kayıtlar silinecek. Emin misiniz?')) return;
  const q=await getQueue();
  for(const op of q) await removeFromQueue(op._qid);
  updateSyncBar();
  toast(`✅ ${q.length} kayıt kuyruktan temizlendi`);
}
/**
 * Stok tablosundan silinen kayıtlara ait ID'leri belirleyerek, bu kayıtlara sahip olmayan stok hareketlerini kuyruktan temizler.
 * @returns {void} İşlem tamamlandıktan sonra bir değer döndürmez.
 */
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
/**
 * Kuyruğu getirir, kuyruk boşsa uygun mesajı gösterir; doluysa ilk 50 kaydı listeler,
 * her kayıt için tablo adı, metod, önizleme ve zaman bilgisi içeren HTML bloğu oluşturur.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
/**
 * Toplu gönderim butonuna tıklandığında bekleyen kayıtları önizler, kullanıcı onayı alırsa kayıtları gönderir ve butonu günceller.
 * @param {Event|undefined} e Tıklama olayı veya undefined.
 * @returns {Promise<void>} İşlem tamamlandığında undefined döndürür.
 */
async function dataTrafficGonder(e){
  const btn=(e||window.event).target;
  // O10: toplu gönderim öncesi sayı+tablo kırılımı önizlemesi (tek-kayıt ↑ onaysız kalır)
  const q=await getQueue();
  if(q.length){
    const kirilim={};
    q.forEach(o=>{ kirilim[o.table]=(kirilim[o.table]||0)+1; });
    const ozet=Object.entries(kirilim).map(([t,n])=>`${t} × ${n}`).join(', ');
    if(!confirm(`Bekleyen ${q.length} kayıt gönderilecek: ${ozet}. Onaylıyor musunuz?`)) return;
  }
  btn.disabled=true; btn.textContent='Gönderiliyor…';
  await syncNow();
  await dataTrafficYenile();
  btn.disabled=false; btn.textContent='↑ Tümünü Gönder';
}
/**
 * Kuyruktaki tek bir bekleyen işlemi, tablo ve metoda göre eşlenen RPC'yi çağırarak sunucuya gönderir; başarılıysa kuyruktan çıkarır, ilgili tabloları çekip UI'ı yeniler.
 * @param {string} qid - Gönderilecek işlemin kuyruk kimliği.
 * @returns {Promise<void>} İşlem sonunda senkron göstergesini güncelleyen bir Promise.
 */
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
/**
 * RPC çağrısı adı, veri objesi ve opsiyonel operasyon parametresine göre
 * ilgili hayvan yönetimi, stok, tohumlama veya görev işlemleri için gereken
 * parametre objesini oluşturur. Parametre isimleri ve değerleri (null, undefined
 * veya boş string kontrolü) fonksiyona göre ayarlanır.
 * @param {string} rpcName - Yapılacak işlem için RPC endpoint adı (örn: 'hayvan_ekle', 'dogum_kaydet').
 * @param {Object} data - İşlem için gerekli olan veri alanlarını içeren nesne.
 * @param {Object} [op] - Opsiyonel operasyon objesi, genellikle filtre bilgisi içerir.
 * @returns {Object} RPC çağrısı için hazırlanmış parametre objesi.
 */
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
      return { p_gorev_id: data.id, p_padok_hedef: data.padok || null,
               p_iptal: data.iptal === true };   // T5: iptal-PATCH replay'i iptal olarak gider
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
/**
 * Kullanıcı onayı alındıktan sonra verilen kuyruk ID'sine sahip kaydı kuyruktan siler,
 * arayüzü yeniler ve senkronizasyon çubuğunu günceller.
 * @param {string} qid Silinecek kaydı tanımlayan kuyruk ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
async function dataTrafficSil(qid){
  if(!confirm('Bu kaydı kuyruktan sil? (Supabase\'e gönderilmeyecek)')) return;
  await removeFromQueue(qid);
  toast('🗑 Kayıt kuyruktan silindi');
  await dataTrafficYenile();
  updateSyncBar();
}
/**
 * Ayarlar ekranındaki hekim listesini veritabanından (yoksa varsayılan hekimlerden) çekerek oluşturur ve varsayılan hekimi işaretler.
 * @returns {Promise<void>} Hiçbir değer döndürmez; liste doğrudan DOM'a yazılır.
 */
async function renderAyarlarHekimList(){
  const el=document.getElementById('ay-hekim-list'); if(!el) return;
  const hekimler=await getData('hekimler');
  const all=hekimler.length?hekimler:HEKIMLER;
  el.innerHTML=all.map(h=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--card2);cursor:pointer" onclick="hekimDetAc('${h.id}')">
    <span style="font-size:.85rem;color:var(--ink);cursor:pointer">${esc(h.ad)}${h.id===VARSAYILAN_HEKIM?' <span style="font-size:.6rem;color:var(--green)">(varsayılan)</span>':''}</span>
    <button onclick="event.stopPropagation();hekimDetAc('${h.id}')" style="background:none;border:none;color:var(--ink3);font-size:.75rem;cursor:pointer;padding:4px 8px">🔍</button>
  </div>`).join('');
}
/**
 * Aşı listesini getirir, boş ise uyarı gösterir; dolu ise her aşı için tekrar aralığı seçeneği içeren HTML bloğunu oluşturur.
 * @returns {void}
 */
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

/**
 * Aşı kaydının rapel (tekrar) süresini günceller; başarı ve hata durumlarında toast mesajı gösterir.
 * @param {*} vaccineId - Güncellenecek aşının kimliği.
 * @param {*} val - Yeni rapel gün sayısı; boş string ise null olarak kaydedilir, değilse tam sayıya çevrilir.
 * @returns {Promise<void>} İşlem tamamlanınca çözülen, değer döndürmeyen promise.
 * @rpc vaccine_rapel_guncelle
 */
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
/**
 * 'ay-hekim-form' elementini görünür yaparak hekim ekleme formunu gösterir.
 * @returns {void}
 */
function ayarlarHekimEkle(){ document.getElementById('ay-hekim-form').style.display='block'; }
/**
 * Ayarlar formundan girilen ad ve telefon bilgisiyle yeni hekim kaydı oluşturur; kayıt sonrası hekim listelerini ve seçim alanlarını yeniler.
 * @returns {Promise<void>} İşlem tamamlanırken bir değer döndürmez; hata durumunda bildirim gösterip çıkar.
 * @rpc hekim_ekle
 */
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

/**
 * Belirtilen ID'ye sahip hekimin detaylarını getirir ve ilgili UI elemanlarını günceller.
 * @param {string} id - Aranan hekimin benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirtilen gün sayısına göre hekim istatistiklerini günceller ve aktif sekme sınıfını ayarlar.
 * @param {number} days Güncelleme yapılacak gün sayısı.
 * @param {Event} e Tıklama olayı objesi (varsa).
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function hekimPeriod(days, e) {
  _hekimPeriodDays = days;
  document.querySelectorAll('#hk-period-tabs .kat-btn').forEach(b => b.classList.remove('on'));
  if (e && e.target) e.target.classList.add('on');
  renderHekimStats();
}

/**
 * Seçili hekimin tohumlama ve doğum kayıtlarından istatistik kartını (toplam tohumlama, gebelik oranı, gebe/doğum sayısı ve sperma kullanımı dökümü) render eder.
 * @returns {Promise<void>} İşlem tamamlandığında hiçbir değer döndürmez.
 */
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

/**
 * Hekim detay formundaki verileri alıp günceller, tabloyu yeniler ve ilgili listeleri günceller.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata durumunda undefined döndürür.
 * @rpc hekim_guncelle
 */
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

/**
 * Mevcut seçili hekim detayını kullanarak ilgili kaydı siler, tabloyu günceller ve arayüzü yeniden render eder.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata durumunda undefined döndürür.
 * @rpc hekim_sil
 */
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
/**
 * Padok listesini getirip HTML olarak 'ay-padok-list' elementine render eder.
 * Eğer padok listesi boşsa, 'Henüz padok tanımlı değil' mesajını gösterir.
 * @returns {void}
 */
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
/**
 * Verilen ID'ye sahip padok detayını getirir ve ilgili DOM elementlerini günceller.
 * @param {string} id Padokun benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Padok detayını doğrulayıp sunucuya gönderir, tabloyu yeniler ve ilgili arayüzleri günceller.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata durumunda undefined döndürür.
 * @rpc padok_guncelle
 */
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

/**
 * Aktif hayvanı olmayan geçerli padoğu, kullanıcı onayı aldıktan sonra siler.
 * Silme öncesi padokta aktif hayvan varsa uyarı gösterip işlemi durdurur;
 * başarılı silme sonrası ilgili tabloları ve arayüz bileşenlerini yeniler.
 * @returns {Promise<void>} Herhangi bir değer döndürmez.
 * @rpc padok_sil
 */
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

/**
 * Padok doluluk çubuğunu oluşturur; padok filtre seçeneklerini günceller ve her padok için aktif hayvan sayısını, kapasiteye göre renklendirilmiş doluluk çubuğuyla gösteren çipleri render eder.
 * @returns {void} Herhangi bir değer döndürmez; sonucu DOM'a yazar.
 */
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

/**
 * Verilen padok adını 'pflt' select elementine ayarlar ve 'change' olayını tetikler.
 * @param {string} padokId - Paddonun kimliği.
 * @param {string} padokAdi - Select elementine atanacak padok adı.
 * @returns {void}
 */
function setPadokFiltreBt(padokId, padokAdi) {
  const sel = document.getElementById('pflt');
  if (sel) {
    sel.value = padokAdi;
    sel.dispatchEvent(new Event('change', { bubbles: true }));
  }
}

/**
 * Bluetooth çoklu seçim modunu etkinleştirir; seçim listesini sıfırlar, seçim düğmesinin stilini ve metnini günceller, seçim banner'ını ve eylem çubuğunu görünür kılar.
 * @returns {void}
 */
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

/**
 * Toplu taşıma seçim modundan çıkar; seçim durumunu temizler, ilgili buton, banner, eylem çubuğu gibi arayüz öğelerini sıfırlar ve sürü listesini yeniden render eder.
 * @returns {void}
 */
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

/**
 * Seçim modunu aktif veya pasif hale getirir.
 * @returns {void}
 */
function btToggleSecimModu() {
  if (_btSecimModu) exitBtSecimModu();
  else enterBtSecimModu();
}

/**
 * Sürü listesi görünümünü toplu seçim moduna göre günceller; kapsayıcıya 'bt-mode' sınıfını ekler/kaldırır ve her hayvan kartının 'bt-selected' sınıfını seçili kimliklere göre ayarlar.
 * @returns {void} Herhangi bir değer döndürmez; sürü kapsayıcı öğesi bulunamazsa işlem yapmadan çıkar.
 */
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

/**
 * Verilen kart ID'sini seçili listeye ekler veya çıkarır ve arayüzü günceller.
 * @param {string} id Seçilecek veya seçilenden çıkarılacak kartın ID'si.
 * @param {Event} event Tıklama olayı nesnesi.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _btKartTikla(id, event) {
  event.stopPropagation();
  const idx = _btSecilenIds.indexOf(id);
  if (idx > -1) _btSecilenIds.splice(idx, 1);
  else _btSecilenIds.push(id);
  _btGuncelleActionBar();
  _btRenderSuru();
}

/**
 * Onay kutusu işaretleme durumuna göre ilgili kimliği seçili kimlikler listesine ekler veya listeden çıkarır, ardından işlem çubuğunu ve sürü görünümünü günceller.
 * @param {*} id - Eklenecek veya çıkarılacak kaydın kimliği.
 * @param {boolean} checked - Onay kutusunun işaretli olup olmadığı; true ise kimlik listeye eklenir, değilse listeden çıkarılır.
 * @returns {void} Döndürme değeri yok.
 */
function btCbDegisti(id, checked) {
  if (checked) {
    if (!_btSecilenIds.includes(id)) _btSecilenIds.push(id);
  } else {
    _btSecilenIds = _btSecilenIds.filter(x => x !== id);
  }
  _btGuncelleActionBar();
  _btRenderSuru();
}

/**
 * Seçili hayvan sayısını günceller, seçili hayvanların bulunduğu padok sayısını hesaplar ve taşıma butonunun durumunu (etkinlik ve metni) ayarlar.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Seçili hayvanların varlığı kontrol edilir ve varsa, bulk transfer moduna geçiş yapılır.
 * Seçilen hayvan kopyalanır, hedef padok, etiket ve grup seçenekleri sıfırlanıp yeniden oluşturulur.
 * Serbest liste, seçili hayvanlar ve hedef padoklar yeniden render edilir.
 * Özet, etiket bölümü, grup bölümü gizlenir ve onay butonu devre dışı bırakılır.
 * Bulk transfer modalı açılır ve seçim modundan çıkış yapılır.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Seçili hayvanların listesini oluşturur ve ekranda gösterir.
 * Eğer seçili hayvan yoksa, ilgili uyarı mesajını listeye ekler.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Seçili hayvan ID'sini listeden kaldırır, arayüzü günceller ve onay butonunu boş listede devre dışı bırakır.
 * @param {number|string} id Kaldırılacak seçili hayvanın benzersiz kimlik numarası.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Serbest liste girişi ve sonuç alanlarını temizler.
 * @returns {void}
 */
function _btRenderSerbestListe() {
  const el = document.getElementById('bt-serbest-input');
  if (el) el.value = '';
  const sonuc = document.getElementById('bt-serbest-sonuc');
  if (sonuc) sonuc.textContent = '';
}

/**
 * Toplu hayvan aktarım modalındaki serbest metin girişindeki satırları okuyup küpe no, devlet küpe no veya id ile hayvanları eşleştirir; bulunanları seçilenler listesine ekler ve sonucu, seçili hayvanları, hedef padokları ile özeti güncelleyerek gösterir.
 * @returns {void}
 */
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

/**
 * Verilen padok adının, belirtilen gruplardan herhangi birinin uyumlu padok listesinde olup olmadığını kontrol eder.
 * @param {Object} padok Kontrol edilecek padok nesnesi.
 * @param {Array} gruplar Uyumluluk listesini içeren gruplar dizisi.
 * @returns {boolean} Padok en az bir grupta uyumlu ise true, yoksa false döndürür.
 */
function _btGrupUygunMu(padok, gruplar) {
  if (!gruplar.length) return true;
  return gruplar.some(g => {
    const uyumluPadoklar = GRUP_PADOK[g];
    return uyumluPadoklar && uyumluPadoklar.includes(padok.ad);
  });
}

/**
 * Padok nesnesinin 'ad' alanının küçük harf halini alıp, içinde 'besi' kelimesinin var olup olmadığını kontrol eder.
 * @param {Object} padok Ad alanı içeren nesne.
 * @returns {boolean} 'besi' kelimesi bulunduğunda true, yoksa false döndürür.
 */
function _btBesiPadokMu(padok) {
  const ad = (padok.ad || '').toLowerCase();
  return ad.includes('besi');
}

/**
 * Hayvan transferi modalında seçilebilecek hedef padok seçeneklerini DOM'a render eder; doluluk oranı, grup uyumluluğu ve seçim durumuna göre rozet ve bar görselleriyle liste oluşturur.
 * @returns {void}
 */
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

/**
 * Belirtilen padok ID'sine sahip padok için uygun grupları belirler,
 * izinli grupları doldurur ve ilgili UI elemanlarını günceller.
 * @param {string} padokId Seçilecek padokun ID'si.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Yeni grup seçeneği değiştirildiğinde tetiklenen işlemleri gerçekleştirir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function btYeniGrupDegisti() {
  const grupSel = document.getElementById('bt-yeni-grup');
  _btYeniGrup = (grupSel && grupSel.value) ? grupSel.value : null;
  _btGuncelleOzet();
}

/**
 * Toplu transfer modalındaki özet bölümünü seçilen hayvanlara ve hedef padoka göre günceller.
 *
 * Kapasite ve grup uyumluluğunu kontrol eder, özet değerlerini renk ve metin
 * olarak gösterir; gerektiğinde etiket bölümünü açar ve onay düğmesini
 * etkinleştirir/devre dışı bırakır. Seçim veya hedef padok yoksa özeti gizler
 * ve onay düğmesini devre dışı bırakır.
 *
 * @returns {void} Herhangi bir değer döndürmez; DOM'u doğrudan günceller.
 */
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

/**
 * 'bt-etiket-tektek-liste' elementindeki hayvan listesini günceller.
 * Kayıtlı hayvanlardan seçilen ID'lere sahip olanları filtreleyerek liste elemanlarını oluşturur.
 * Her elemanda hayvan numarası, grup bilgisi ve 'Kısır' ile 'Satışta' durumlarını işaretlemek için checkbox'lar bulunur.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Etiket modunu 'toplu' olarak ayarlar, tek tek listedeki tüm onay kutularını temizler ve özeti günceller.
 * @returns {void}
 */
function btEtiketTopluDegisti() {
  _btEtiketMod = 'toplu';
  document.querySelectorAll('#bt-etiket-tektek-liste input[type=checkbox]').forEach(cb => { cb.checked = false; });
  _btGuncelleOzet();
}

/**
 * Etiket modunu 'tektek' olarak ayarlar, toplu onay kutularının işaretini kaldırır ve özeti günceller.
 * @returns {void}
 */
function btEtiketTekkekDegisti() {
  _btEtiketMod = 'tektek';
  const topluKisir = document.getElementById('bt-et-toplu-kisir');
  if (topluKisir) topluKisir.checked = false;
  const topluSatista = document.getElementById('bt-et-toplu-satista');
  if (topluSatista) topluSatista.checked = false;
  _btGuncelleOzet();
}

/**
 * Toplu etiket onay kutuları ya da tek tek listedeki tüm seçili hayvanların işaretli olup olmadığını kontrol eder.
 * @returns {boolean} Toplu kutulardan biri işaretliyse veya seçili tüm hayvanlar tek tek listede işaretliyse true, aksi halde false.
 */
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

/**
 * Butik etiket seçimlerini toplar; toplu seçim kutuları işaretliyse toplu modda etiket listesi, aksi halde tek tek modda hayvan bazlı etiket haritası döndürür.
 * @returns {{mod: string, etiketler?: Array<string>, map?: Object<string, Array<string>>}} Toplu modda {mod:'toplu', etiketler}, tek tek modda {mod:'tektek', map} nesnesi.
 */
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

/**
 * Toplu transfer modalında seçilen hayvanları hedef padoka taşıma işlemini onaylar ve yürütür.
 *
 * Seçili hayvan ve hedef padok yoksa işlem yapılmaz. Onay butonu işlem sırasında devre dışı bırakılır;
 * hedef padok besi padokuyorsa ve gruplar uygun değilse, etiket moduna göre ("tektek" veya toplu)
 * `padok_degistir_toplu` RPC'si çağrılır, aksi halde etiketsiz toplu transfer yapılır. Kapasite dolu
 * veya RPC hatası durumunda kullanıcıya hata bildirimi gösterilir ve buton eski haline döndürülür.
 * Başarı durumunda modal kapatılır, ilgili tablolar yeniden çekilir ve hayvan/doluluk görünümleri yenilenir.
 *
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir promise döndürür; anlamlı bir değer döndürmez.
 * @rpc padok_degistir_toplu
 */
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

/**
 * Verilen padok ID'sine ait padok detaylarını getirir, ilgili DOM elementlerini günceller ve hayvan listesini render eder.
 * @param {number|string} id Padokun benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirtilen padok ID'sine ait aktif hayvanları getirir, filtreleme uygular ve HTML listesi olarak render eder.
 * @param {string} padokId - Filtrelenmesi istenen padokun benzersiz kimlik numarası.
 * @returns {void} Fonksiyon yanıt döndürmez, DOM elementini günceller.
 */
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

/**
 * Seçili hayvan ID'lerini _pdHayvanIds dizisine ekler veya çıkarır ve toplu taşıma butonunun görünümünü günceller.
 * @param {string} id İşlem yapılacak hayvanın benzersiz kimlik numarası.
 * @param {boolean} checked Hayvanın seçili olup olmadığı durumu.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function pdToggleHayvan(id, checked) {
  if (checked) {
    if (!_pdHayvanIds.includes(id)) _pdHayvanIds.push(id);
  } else {
    _pdHayvanIds = _pdHayvanIds.filter(x => x !== id);
  }
  document.getElementById('pd-toplu-tasi-btn').style.display = _pdHayvanIds.length > 0 ? 'inline-block' : 'none';
}

/**
 * Belirtilen hayvan ID'sini tekli taşıma listesine ekleyip, hedef padok seçimi için UI'ı günceller.
 * @param {number|string} hayvanId Taşılan hayvanın benzersel kimlik numarası.
 * @param {string} kupe Hayvanın bulunduğu mevcut kupe numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function padokTekliTasi(hayvanId, kupe) {
  _pdTransferHayvanIds = [hayvanId];
  document.getElementById('pt-bilgi').textContent = `🐄 ${kupe} → hedef padok seçin:`;
  _pdTransferAcSelector();
}

/**
 * Seçili hayvanların toplu taşıma işlemini başlatır.
 * @returns {void} İşlem tamamlandığında veya hata durumunda bir değer döndürmez.
 */
function padokTopluTasi() {
  if (!_pdHayvanIds.length) { toast('⚠️ Lütfen en az bir hayvan seçin', true); return; }
  _btSecilenIds = [..._pdHayvanIds];
  _btModalSecilenIds = [..._pdHayvanIds];
  _btHedefPadokId = null;
  openBulkTransfer();
}

/**
 * Kaynak padok ID'si hariç diğer tüm padokları filtreleyip seçici listesine ekler.
 * @returns {void}
 */
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

/**
 * Kullanıcının seçtiği hedef padok ID'sini alarak mevcut hayvanları tek tek veya toplu olarak o padoka taşır.
 * İşlem başarılı veya başarısız olduğunda kullanıcıya bildirim gösterir ve tabloyu yeniler.
 * @returns {Promise<void>} İşlem tamamlandığında boş bir Promise döndürür.
 * @rpc padok_degistir, padok_degistir_toplu
 */
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

/**
 * Padok ve grup-padok eşleşme verilerini getirerek, 'ay-grup-padok-list' elementine padok seçim kutucukları içeren HTML oluşturur.
 * Eğer padok listesi boşsa, kullanıcıya uyarı mesajı gösterir.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Seçilen padok için grup-padok eşlemesini açıp kapatır, ilgili tabloları ve padok yapılandırmasını yeniden yükler ve bilgilendirme mesajı gösterir.
 * @param {string} grup - Eşlemenin yapılacağı grup adı.
 * @param {HTMLInputElement} checkbox - value özelliği padok kimliğini içeren checkbox öğesi.
 * @returns {Promise<void>} İşlem tamamlandığında hiçbir değer döndürmez.
 * @rpc grup_padok_eslem_toggle
 */
async function grupPadokCheckbox(grup, checkbox){
  const padokId=checkbox.value;
  await rpc('grup_padok_eslem_toggle',{p_grup_adi:grup,p_padok_id:padokId});
  await pullTables(['grup_padok_eslem']);
  await loadPadokConfig();
  toast('Eşleme güncellendi');
}

/**
 * 'ay-padok-form' elementini görünür yaparak ayarlar panelini gösterir.
 * @returns {void} Hiçbir değer döndürmez.
 */
function ayarlarPadokEkle(){ document.getElementById('ay-padok-form').style.display='block'; }

/**
 * Padok adı ve kapasite alanlarından alınan verileri doğrulayarak yeni bir padok ekler,
 * ilgili tabloyu günceller, formu gizler ve padok listesini yeniden render eder.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata durumunda undefined döndürür.
 * @rpc padok_ekle
 */
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
/**
 * Tarayıcı bildirim desteğini kontrol eder, iOS cihazlarda gerekli ön koşulları (Ana Ekran'a ekleme) doğrular ve bildirim izni ister.
 * @returns {boolean} Bildirim izni başarıyla alındıysa true, aksi takdirde false döndürür.
 */
async function bildirimIzniAl(){
  if(!('Notification' in window)){ toast('Tarayıcınız bildirimleri desteklemiyor',true); return false; }
  const isIOS=/iPad|iPhone|iPod/.test(navigator.userAgent)&&!window.MSStream;
  if(isIOS&&!window.navigator.standalone){ toast('iOS: Önce Ana Ekrana Ekle yapın, sonra bildirimleri açın',true); return false; }
  if(Notification.permission==='granted') return true;
  if(Notification.permission==='denied'){ toast('Bildirim izni reddedilmiş — tarayıcı ayarlarından açın',true); return false; }
  const result=await Notification.requestPermission();
  return result==='granted';
}
/**
 * Bildirim izni kontrol edilir ve bugün/yarın tarihlerinde tamamlanmamış, iptal edilmemiş, üst görevi olmayan görevler için bildirim gösterilir. Gösterilen bildirimlerin kaydı tutularak tekrar gösterilmesini önler ve eski kayıtları temizler.
 * @returns {Promise<void>} İşlem tamamlandığında boş Promise döndürür.
 */
async function bildirimKontrol(){
  if(!('Notification' in window)||Notification.permission!=='granted') return;
  const now=new Date();
  const bugunStr=bugun();
  const yarin=dFwd(bugunStr,1);
  // C4 (cila2): K8'in seans/gecikme genişletmesi geri alındı — 1f01e8b hâli:
  // yalnız parent_id'siz görevler, bugün+yarın penceresi.
  const gorevler=await getData('gorev_log',g=>!g.tamamlandi&&!g.iptal&&!g.parent_id&&(g.hedef_tarih===bugunStr||g.hedef_tarih===yarin));
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
/**
 * Bildirim izni ister, izin verilirse aktif durumunu kaydedip kontrolü başlatır, verilmezse uyarı gösterir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
async function bildirimAc(){
  const izin=await bildirimIzniAl();
  if(izin){ toast('✅ Bildirimler açık!'); localStorage.setItem('bildirim_aktif','1'); bildirimKontrol(); }
  else { toast('⚠️ Bildirim izni verilmedi',true); }
}

// ──────────────────────────────────────────
// DATA LISTS (datalist güncelleme)
// ──────────────────────────────────────────
/**
 * 'stok' deposundaki tüm kayıtları okuyup 'dl-ilac' datalist öğesini stok seçenekleriyle doldurur.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir Promise.
 */
async function buildDataLists(){
  const stk=await idbGetAll('stok');
  const dlI=document.getElementById('dl-ilac');
  if(dlI) dlI.innerHTML=stk.map(s=>`<option value="${s.id}">${esc(s.urun_adi)}</option>`).join('');
}

// ═══ STOK ARAMA ═══
/**
 * Stok panelindeki öğeleri 'data-ad' özniteliğindeki metin ile eşleşen bir sorguya göre filtreler.
 * Sorgu boşsa tüm öğeleri gösterir, sorgu varsa içeren öğeleri gösterir ve içermeyenleri gizler.
 * Görünür öğe sayısı olmayan grup başlıklarını gizler ve arama sonuç sayısını günceller.
 * @param {string} q Filtreleme için kullanılacak arama sorgusu.
 * @returns {void}
 */
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

// ═══ GÖREV İÇERİK ARAMASI (F4 — veri katmanı) ═══
// Eski taskSrch client-side DOM gizleme'ydi: yalnız o an render edilmiş ≤200
// kartın .tc-id metninde arıyor, seans/alt görev kartları kapsam dışıydı ve
// her loadTasks'ta input temizleniyordu. Artık burada yalnız debounce var;
// filtre loadTasks içinde blok verisi üzerinden uygulanır (kupe, tip,
// açıklama, ilaç adları, teşhis), limit arama aktifken kalkar ve arama
// sekme/filtre geçişlerinde korunur.
/**
 * Belirtilen sürede (220ms) `loadTasks` fonksiyonunu tetikler; mevcut zamanlayıcıyı temizler.
 * @returns {void} Hiçbir değer döndürmez.
 */
function taskSrch(){
  clearTimeout(taskSrch._t);
  taskSrch._t=setTimeout(()=>{ loadTasks(_curTaskFilter||'today',null,{skipPull:true}); },220);
}

// ══════════════════════════════════════════
// BUG-059 — Saat Bazlı Tedavi Seans UI
// Seans şeridi + satırlar m-case-det gün akordeonu ve
// m-task-det içinde render edilir. Ayrı modal yok.
// ══════════════════════════════════════════

// "08:00" | "08:00:00" (PostgREST time) → "08:00"
/**
 * Verilen zaman stringinin ilk 5 karakterini alarak döndürür.
 * @param {string} timeStr - İşlenecek zaman stringi.
 * @returns {string} En fazla 5 karakterlik zaman stringi.
 */
function fmtSeansSaat(timeStr) {
  return (timeStr || '').slice(0, 5);
}

// Pure: planned_time → 0-1 arası oran (24h)
/**
 * Verilen saat formatındaki zamanı (saat:dakika) 24 saatlik bir günün kesri olarak döndürür.
 * @param {string} timeStr "HH:MM" formatında bir saat stringi.
 * @returns {number} 0 ile 1 arasında (dahil) bir sayı.
 */
function timeToRatio(timeStr) {
  const t = fmtSeansSaat(timeStr);
  if (!/^\d{1,2}:\d{2}$/.test(t)) return 0;
  const [h, m] = t.split(':').map(Number);
  return Math.max(0, Math.min(1, (h * 60 + m) / (24 * 60)));
}

// Pure: seans state hesapla (6 durum)
/**
 * Verilen seansların durumunu (tamamlanmış, iptal edilmiş, planlanmış, gecikmiş vb.) belirler.
 * @param {Object} seans Seans nesnesi.
 * @param {Date} now [İsteğe bağlı] Karşılaştırma için kullanılan tarih nesnesi.
 * @returns {String} Seansın durumu ('done', 'cancelled', 'scheduled', 'overdue', 'now', 'due-soon').
 */
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
/**
 * Verilen seans listesini zaman oranlarına göre gruplandırarak HTML şeridi oluşturur.
 * Her seans için durum simgesi (✓, ✕) ve detaylı bilgi (saat, ilaç, doz, birim) eklenir.
 * Zaman çizelgesi üzerindeki saat işaretleme çizgileri ve bugünün çizgisi (opsiyonel) dahil edilir.
 * @param {Array} sessions İşlenecek seans nesnelerinden oluşan dizi.
 * @param {Object} opts Opsiyonel ayarlar objesi; 'today' özelliği bugünün çizgisini gösterip göstermeyeceğini belirler.
 * @returns {string} Seans şeridini oluşturan HTML string'i.
 */
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
/**
 * Bugünün saatine göre 'seans-now-line' elementlerinin sol konumunu yüzdelik olarak günceller.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function updateNowCursor() {
  const lines = document.querySelectorAll('.seans-strip[data-today] .seans-now-line');
  if (!lines.length) return;
  const now = new Date();
  const pct = ((now.getHours() * 60 + now.getMinutes()) / 1440 * 100).toFixed(2);
  lines.forEach(l => { l.style.left = pct + '%'; });
}
/**
 * Önceki zamanlayıcıyı temizleyerek yeni bir döngü başlatır ve her 60 saniyede bir `updateNowCursor` fonksiyonunu çalıştırır.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function startNowCursorLoop() {
  if (_nowCursorInterval) clearInterval(_nowCursorInterval);
  updateNowCursor();
  _nowCursorInterval = setInterval(updateNowCursor, 60000);
}

/**
 * Verilen seans planı tarih ve saati alarak bugünden kalan bekleme süresini hesaplar.
 * Süre dakika, saat veya gün cinsinden formatta döndürülür.
 * @param {Object} s Seans bilgilerini içeren nesne (planned_date ve planned_time özellikleri).
 * @returns {String} Bekleme süresini gösteren metin (örneğin "15dk", "2sa 30dk", "1g 5sa").
 */
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

/**
 * Geçerli bir ISO 8601 tarih zinciri verildiğinde, Türkçe formatında kısa saat (saat ve dakika) döndürür.
 * @param {string} iso ISO 8601 formatında bir tarih zinciri.
 * @returns {string} Türkçe formatında saat ve dakika içeren bir string veya geçersiz giriş için boş string.
 */
function fmtSaatKisa(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
}

// Tek seans satırı — mevcut cd-drug-row diline uygun
/**
 * Verilen seans nesnesinin durumuna göre HTML satırı oluşturur.
 * Durum etiketleri, bekleme süreleri ve uygulama bilgileri dahil edilerek
 * seansın planlanan saati, ilacı, doz bilgisi ve eylem butonları (uygulama/iptal) içeren
 * bir satır döndürür.
 * @param {Object} s Seans nesnesi.
 * @param {Object} opts Opsiyonel ayarlar objesi (örn. readOnly).
 * @returns {string} Seans satırını temsil eden HTML stringi.
 */
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
/**
 * Verilen tedavi gününe ait seansları IndexedDB'den çekip Ribbon ve seans satırları olarak render eder.
 * @param {string|number} treatmentDayId - Seansları render edilecek tedavi gününün kimliği.
 * @returns {Promise<void>} Seans arayüzü render edildikten sonra tamamlanır.
 */
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
/**
 * Belirtilen gün ID'sine ait seans formunu açar, mevcut seansları listeler,
 * ilaç stoklarını gruplar ve yeni seans ekleme arayüzünü oluşturur.
 * @param {number} dayId - Seansların planlandığı günün ID'si.
 * @returns {void}
 */
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

/**
 * Belirtilen saati 'seans-add-time' inputuna ayarlar ve butona 'aktif' sınıfını eklerken diğer tüm '.ek-chip' elemanlarından bu sınıfı kaldırır.
 * @param {string} h Ayarlanacak saat değeri.
 * @param {HTMLElement} btn Aktif sınıfı eklenecek buton elemanı.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function seansAddSaatSec(h, btn) {
  const inp = document.getElementById('seans-add-time');
  if (inp) inp.value = h;
  btn?.parentElement?.querySelectorAll('.ek-chip').forEach(c => c.classList.remove('aktif'));
  btn?.classList.add('aktif');
}

/**
 * Onay penceresi göstererek belirtilen seansı siler; ilacı stoğa iade eder, ilgili tabloları yeniden çeker ve hasta zaman çizelgesini/formu güncel tutar. Hata durumunda hata mesajı gösterir.
 * @param {*} seansId - Silinecek seansın kimliği.
 * @returns {Promise<void>} İşlem tamamlandığında çözülen bir Promise.
 * @rpc remove_treatment_session
 */
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
/**
 * Belirtilen seans ID'sine sahip seansı bulup, düzenleme formunu (saat, doz, birim, uygulama yolu vb.) içeren HTML yapısını oluşturarak ilgili satıra yerleştirir.
 * @param {string} seansId Düzenlenecek seansın benzersiz kimlik numarası.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
function seansDuzenleAc(seansId) {
  const d = _seansAddCtx && _cdDayData[_seansAddCtx.dayId];
  const s = (d?.sessions || []).find(x => x.id === seansId);
  const row = document.getElementById('seans-mevcut-' + seansId);
  if (!s || !row) return;
  const yolOpts = ['IM', 'IV', 'SC', 'PO', 'Topikal', 'Intrauterin', 'Meme içi']
    .map(y => `<option value="${y}"${(s.route || '') === y ? ' selected' : ''}>${y}</option>`).join('');
  row.innerHTML = `
    <div style="display:flex;gap:5px;align-items:center;flex-wrap:wrap;width:100%">
      <input id="sd-time-${seansId}" class="fi" type="time" value="${esc(fmtSeansSaat(s.planned_time) || '08:00')}" style="margin:0;width:88px">
      <input id="sd-dose-${seansId}" class="fi" type="number" min="0.01" step="0.01" value="${s.dose ?? ''}" placeholder="Doz" style="margin:0;width:64px">
      ${_dozHintBtnHtml('sd-dose-' + seansId, s.drug_product_id || '', document.getElementById('m-case-det')?.classList.contains('on') ? (_curCase?.animal_id || '') : '')}
      <input id="sd-unit-${seansId}" class="fi" type="text" value="${esc(s.unit || 'ml')}" placeholder="Birim" style="margin:0;width:52px">
      <select id="sd-route-${seansId}" class="fsel" style="margin:0;flex:1;min-width:64px">${yolOpts}</select>
      <button onclick="seansDuzenleKaydet('${seansId}',this)" style="background:var(--green);color:#fff;border:none;border-radius:6px;padding:6px 10px;font-weight:700;cursor:pointer" title="Kaydet">✓</button>
      <button onclick="caseSeansEkleFormAc('${_seansAddCtx.dayId}')" style="background:var(--card3);border:none;border-radius:6px;padding:6px 9px;cursor:pointer" title="İptal">✕</button>
    </div>`;
}

/**
 * Bir tedavi seansının saat, doz, birim ve uygulama yolu bilgilerini doğrular, RPC ile günceller ve ilgili tabloları yeniler.
 * @param {*} seansId - Güncellenecek seansın kimliği.
 * @param {*} btn - Kaydetme sırasında devre dışı bırakılan ve metni '…' olarak değiştirilen buton öğesi.
 * @returns {Promise<void>} Güncelleme tamamlandığında çözülen bir Promise. Doğrulama hatasında uyarı gösterip hiçbir şey döndürmez.
 * @rpc update_treatment_session
 */
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

/**
 * Belirtilen saatte seçilen ilaçlar için doz ve birim bilgilerini doğrulayarak yeni seans kayıtlarını oluşturur,
 * sunucuya ekler ve başarılı olursa zaman çizelgesini günceller.
 * @param {HTMLElement} btn Tıklanma tetikleyicisi olarak kullanılan buton elemanı.
 * @returns {Promise<void>} İşlem tamamlandığında veya hata oluştuğunda çözülen bir Promise.
 * @rpc add_sessions_to_existing_day
 */
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
/**
 * Erken kapatma formunu açar veya kapatır; form kapalıysa ilgili tedavi günleri ve uygulanmamış seansları özetleyip gösterir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
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

/**
 * Erken kapatma onay butonuna tıklandığında vakayı kapatır, kalan seansları iptal eder ve ilaçları stoğa iade eder.
 * @param {HTMLElement} btn Buton elemanı; işlem sırasında devre dışı bırakılır ve işlem tamamlandıktan sonra tekrar aktif hale getirilir.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * Belirtilen aşı ID'si verildiğinde aşı düzenleme formunu doldurur veya yoksa yeni aşı ekleme formunu başlatır.
 * @param {string} vaccineId Düzenlenecek aşı için ID, yoksa yeni aşı ekleme işlemi için null.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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

/**
 * _asiEdit nesnesindeki hastalık listesini, _asiDisSearch değeriyle filtreleyerek (boş ise tümünü) alır,
 * Türkçe alfabe sırasına göre sıralar, kategori bazında gruplar ve HTML checkbox listesi olarak döndürür.
 * @returns {string} Filtrelenmiş ve kategorize edilmiş hastalık seçici HTML kodu veya "Hastalık bulunamadı" mesajı.
 */
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

/**
 * Aşı ekleme/düzenleme modalının gövde HTML'ini oluşturup 'm-asi-body' elementine basar.
 * Preparat adı, marka, etken madde, doz, birim, uygulama yolu, zorunluluk durumu,
 * hastalık seçimi, protokol tipi (tek doz/primer seri), yıllık tekrar ve stok bilgilerini içeren formu render eder.
 * @returns {void} Herhangi bir değer döndürmez; HTML içeriği doğrudan DOM'a yazar.
 */
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

/**
 * Verilen hastalık ID'sini (_asiEdit.disease_ids dizisine) ekler veya çıkarır.
 * @param {number|string} did Eklenmesi veya çıkarılacak hastalık ID'si.
 * @param {boolean} checked Parametre true ise ID eklenir, false ise ID diziden silinir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function asiDisToggle(did, checked){
  if(checked){ if(!_asiEdit.disease_ids.includes(did)) _asiEdit.disease_ids.push(did); }
  else { _asiEdit.disease_ids = _asiEdit.disease_ids.filter(x=>x!==did); }
}
/**
 * Verilen protokol tipini ayarlayarak formu senkronize eder ve yeniden render eder.
 * @param {any} val Yeni protokol tipi değeri.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function asiProtToggle(val){ _syncAsiForm(); _asiEdit.protokol_tipi = val; _renderAsiForm(); }
/**
 * Aşı/dış hastalık arama girişini güncelleyerek global arama değişkenine atar, formu senkronize eder ve hastalık seçici listesini yeniden render eder.
 * @param {*} val - Arama giriş değeri.
 * @returns {void} Değer döndürmez.
 */
function asiDisSearchInput(val){ _asiDisSearch = val; _syncAsiForm(); document.getElementById('asi-dis-list').innerHTML = _renderAsiDiseasePicker(); }

/**
 * Aşı formundaki alanları okuyup _asiEdit nesnesini güncelleyerek aşı kaydını senkronize eder; form alanları yoksa hiçbir işlem yapmaz.
 * @returns {void}
 */
function _syncAsiForm(){
  /**
   * Belirtilen ID'ye sahip DOM elementini bulup döndürür.
   * @param {string} id Bulunacak elementin ID'si.
   * @returns {HTMLElement|null} Bulunan element veya bulunamazsa null.
   */
  const g2 = id => document.getElementById(id);
  if(!g2('asi-name')) return;
  const s=_asiEdit;
  s.name=g2('asi-name').value; s.marka=g2('asi-marka').value; s.etken_madde=g2('asi-etken').value;
  s.dose=g2('asi-dose').value; s.unit=g2('asi-unit').value; s.route=g2('asi-route').value;
  s.is_mandatory=g2('asi-mand').checked; s.repeat=g2('asi-repeat').value;
  if(g2('asi-ikinci-gun')) s.ikinci_doz_gun=g2('asi-ikinci-gun').value;
  if(g2('asi-stok')){ s.baslangic_stok=g2('asi-stok').value; s.esik=g2('asi-esik').value; }
}
