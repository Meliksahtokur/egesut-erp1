// ARŞİV — 2026-07-06, "kardeş bug" temizliği (hekim duplike-gölge deseninin sperma karşılığı).
// Bu dosya HİÇBİR YERDEN import/load EDİLMEZ — sadece referans amaçlı arşivlenmiştir.
//
// Neden ölü kod: index.html'de `ay-sperma-list` / `ay-sperma-form` / `ay-sp-kod` / `ay-sperma-kod`
// elementlerinin HİÇBİRİ yok. `ayarlarSpermaEkle()` (giriş noktası) hiçbir yerden çağrılmıyor
// (grep ile doğrulandı: index.html + js/*'de sıfır çağıran). Sperma stok yönetimi zaten genel
// Stok sekmesinden (`m-stok-add` modalı, kategori='Sperma') yapılıyor — bu ayrı "Ayarlar→Sperma"
// mini-CRUD'u supersede edilmiş, temizlenmemiş.
//
// Üç implementasyon vardı (script yükleme sırası: ui.js → forms.js → app.js, app.js en son
// yüklenir ve global adları ezerdi — ama hiçbiri zaten hiç tetiklenmiyordu):

// ── 1) js/app.js:184-209 (EN SON yüklenen, "kazanan" ama yine de ölü) ──
function renderAyarlarSpermaList_APPJS_ESKI() {
  const el = g('ay-sperma-list'); if (!el) return;
  const all = [...new Set([...SPERMA_LISTESI, ..._customSperma])];
  el.innerHTML = all.map(s => `<div style="display:flex;align-items:center;justify-content:space-between;padding:7px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.84rem">${s}</span>
    ${_customSperma.includes(s) ? `<button onclick="customSpermaSil('${s.replace(/'/g,"\\'")}') " style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.8rem">Sil</button>` : ''}
  </div>`).join('');
}
function ayarlarSpermaEkle_APPJS_ESKI()  { g('ay-sperma-form').style.display = 'block'; }
function ayarlarSpermaKaydet_APPJS_ESKI() {
  const kod = (g('ay-sperma-kod')?.value || '').trim(); if (!kod) return;
  if (!_customSperma.includes(kod)) _customSperma.push(kod);
  g('ay-sperma-form').style.display = 'none';
  if (g('ay-sperma-kod')) g('ay-sperma-kod').value = '';
  renderAyarlarSpermaList();
  buildSpermaList();
  toast('Sperma eklendi');
}
function customSpermaSil_APPJS_ESKI(kod) {
  _customSperma = _customSperma.filter(s => s !== kod);
  renderAyarlarSpermaList();
}

// ── 2) js/ui.js:6652-6658 (eski, local-array versiyonu, ui.js:6818'in gölgesinde kalırdı) ──
function renderAyarlarSpermaList_UIJS_ESKI(){
  const el=document.getElementById('ay-sperma-list'); if(!el) return;
  const all=[...SPERMA_LISTESI,...(_customSperma||[])];
  el.innerHTML=all.map((s,i)=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.8rem;color:var(--ink)">${s}</span>
    ${i>=SPERMA_LISTESI.length?`<button onclick="customSpermaSil('${s}')" style="background:none;border:none;color:var(--red);font-size:.75rem;cursor:pointer">Sil</button>`:'<span style="font-size:.6rem;color:var(--ink3)">Sabit</span>'}</div>`).join('');
}

// ── 3) js/ui.js:6805-6835 (YENİ/doğru tasarlanmış DB-backed versiyon — RPC'lere bağlıydı
//       ama yine hiç tetiklenmiyordu, çünkü index.html'de giriş noktası hiç yoktu) ──
function ayarlarSpermaEkle_UIJS_YENI(){ document.getElementById('ay-sperma-form').style.display='block'; }
async function ayarlarSpermaKaydet_UIJS_YENI(){
  const kod=v('ay-sp-kod').trim(); if(!kod) return;
  const{error}=await rpc('stok_ekle',{p_urun_adi:kod,p_kategori:'Sperma',p_birim:'doz',p_baslangic_miktar:0,p_esik:0});
  if(error){ toast('Hata: '+error.message,true); return; }
  await pullTables(['stok']);
  cl('ay-sp-kod');
  document.getElementById('ay-sperma-form').style.display='none';
  renderAyarlarSpermaList();
  buildSpermaList();
  toast(`✅ ${kod} eklendi`);
}
async function renderAyarlarSpermaList_UIJS_YENI(){
  const el=document.getElementById('ay-sperma-list'); if(!el) return;
  const stoklar=await getData('stok');
  const spermalar=stoklar.filter(s=>s.kategori==='Sperma');
  if(!spermalar.length){ el.innerHTML='<div style="font-size:.75rem;color:var(--ink3)">Henüz sperma eklenmedi</div>'; return; }
  el.innerHTML=spermalar.map(s=>`<div style="display:flex;align-items:center;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.8rem;color:var(--ink)">${esc(s.urun_adi)}</span>
    <button onclick="spermaSil('${s.id}')" style="background:none;border:none;color:var(--red);font-size:.75rem;cursor:pointer">Sil</button>
  </div>`).join('');
}
async function spermaSil_UIJS_YENI(stokId){
  const res=await rpc('sperma_sil',{p_stok_id:stokId});
  if(!res.ok){ toast(res.mesaj||'Silinemedi',true); return; }
  await pullTables(['stok','stok_hareket']);
  renderAyarlarSpermaList();
  buildSpermaList();
  toast('Sperma silindi');
}

// İleride bu mini-ekran geri getirilmek istenirse: (3) numaralı DB-backed versiyon en
// doğrusu — sadece index.html'e ay-sperma-list/ay-sperma-form/ay-sp-kod elementlerini
// eklemek + fonksiyon adlarındaki _UIJS_YENI son ekini kaldırmak yeterli.
