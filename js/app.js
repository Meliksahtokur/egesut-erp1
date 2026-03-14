// ══════════════════════════════════════════
// EgeSüt — app.js
// Global state, routing, init
// ══════════════════════════════════════════

// ── SABİT VERİLER ──────────────────────────
// HEKIMLER config.js'den geliyor (const), burada tanımlanmaz
// VARSAYILAN_HEKIM config.js'den geliyor

// DB'den hekimleri yükle
async function loadHekimler() {
  try {
    const { data, error } = await db.rpc('hekim_listesi');
    if (!error && data && data.length > 0) {
      HEKIMLER = data.map(h => ({ id: h.id, ad: h.ad, telefon: h.telefon }));
    }
  } catch (e) {
    console.warn('Hekimler DB\'den yüklenemedi, fallback kullanılıyor:', e.message);
  }
  populateHekimSelects();
}

const HASTALIK_LISTESI = [
  'Mastit','Subklinik Mastit','Klinik Mastit',
  'Metrit','Endometrit','Pyometra','Retensiyo Sekundinarum','Kistik Over','Anoestrus',
  'Hipokalsemi (Süt Humması)','Ketozis','Ruminal Asidoz','Timpani','Şirden Deplasmanı',
  'Topallık (Dermatit)','Topallık (Laminit)','Beyaz Çizgi Hastalığı','Tırnak Yarası',
  'Pnömoni','Buzağı İshali','Buzağı Göbek İltihabı','Neonatal Zayıflık',
];

const HASTALIK_KAT = {
  'Meme':    ['Mastit','Subklinik Mastit','Klinik Mastit'],
  'Üreme':   ['Metrit','Endometrit','Pyometra','Retensiyo Sekundinarum','Kistik Over','Anoestrus'],
  'Metabolik':['Hipokalsemi (Süt Humması)','Ketozis','Ruminal Asidoz','Timpani','Şirden Deplasmanı'],
  'Ayak':    ['Topallık (Dermatit)','Topallık (Laminit)','Beyaz Çizgi Hastalığı','Tırnak Yarası'],
  'Solunum': ['Pnömoni'],
  'Sindirim':['Ruminal Asidoz','Timpani','Şirden Deplasmanı'],
  'Buzağı':  ['Buzağı İshali','Buzağı Göbek İltihabı','Neonatal Zayıflık'],
  'Diğer':   [],
};

const LOKASYON_KAT = {
  'Meme': ['Sol Ön','Sol Arka','Sağ Ön','Sağ Arka'],
  'Ayak': ['Sol Ön','Sol Arka','Sağ Ön','Sağ Arka'],
  'Göz':  ['Sol Göz','Sağ Göz'],
};

const SPERMA_LISTESI = [
  'ABK-Zenith-ET','ABK-Parfect-ET','ABK-Iconic-ET',
  'CRI-Crushabull','CRI-Extreme-ET','Alta-Kalahari','Alta-Achiever',
  'Semex-O-Man','Semex-Planet',
];

let _customHekimler = [];
let _customSperma   = [];
let _disFreq        = {};
let _ilacCache      = [];
let _diseasesCache  = [];  // migration 022 diseases tablosu

async function loadDiseasesDropdown(kategori) {
  const sel = g('d-disease-id');
  if (!sel) return;
  if (!_diseasesCache.length) {
    _diseasesCache = await idbGetAll('diseases');
  }
  const filtered = kategori
    ? _diseasesCache.filter(d => d.category === kategori)
    : _diseasesCache;
  const grouped = {};
  filtered.forEach(d => {
    const cat = d.category || 'Diğer';
    if (!grouped[cat]) grouped[cat] = [];
    grouped[cat].push(d);
  });
  sel.innerHTML = '<option value="">— Hastalık seçin —</option>'
    + Object.keys(grouped).sort().map(cat =>
        `<optgroup label="${cat}">${grouped[cat].map(d => `<option value="${d.id}" data-category="${d.category||''}">${d.name}</option>`).join('')}</optgroup>`
      ).join('');
}

function caseKatFiltrele() {
  const kat = g('case-kat')?.value || '';
  loadDiseasesDropdown(kat);
}

// ── GLOBAL STATE ────────────────────────────
let _A = [], _S = [], _curStk = null, _curPg = 'dash';
let _suruFilter = 'tumuu', _suruSiralama = 'kupe';
let _curUremeTab = 'kizginlik', _curGecmisFilter = 'hepsi', _curTaskFilter = 'today';
let _curTaskDet  = null, _curHst = null, _curToh = null;
let _curBildirimTab = 'bekliyor';

// ── YARDIMCILAR ─────────────────────────────
function g(id)   { return document.getElementById(id); }
function v(id)   { return g(id)?.value || ''; }
function cl(id)  { const el = g(id); if (el) el.value = ''; }

function dAgo(n) { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().split('T')[0]; }
function dFwd(base, n) { const d = base ? new Date(base) : new Date(); d.setDate(d.getDate() + n); return d.toISOString().split('T')[0]; }
function fmtTarih(iso) { if (!iso) return '—'; const p = iso.slice(0, 10).split('-'); return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : iso; }

function openM(id) {
  const el = g(id); if (!el) return;
  el.classList.add('on');
  // Hayvan modalında doğum tarihi otomatik dolmasın — yaş hesabı bozuluyor
  if (id !== 'm-animal') {
    el.querySelectorAll('input[type=date]').forEach(i => { if (!i.value) i.value = new Date().toISOString().split('T')[0]; });
  }
  if (id === 'm-animal') {
    loadIrkDropdown();
    animalFormGuncelle();
  }
  if (id === 'm-insem') {
    db.from('tohumlanabilir_hayvanlar').select('*').then(({data}) => {
      window._TH = data || [];
    }).catch(console.warn);
    setTimeout(() => spermaModStok(), 100);
  }
  if (id === 'm-disease') {
    _semptomSecili = [];
    if(g('sempt-chips')) g('sempt-chips').innerHTML = '';
    if(g('d-sempt')) g('d-sempt').value = '';
    updateSemptomDropdown('');
    filterHastalikList();
  }
  if (id === 'm-disease') {
    _diseasesCache = [];
    loadDiseasesDropdown('');
  }
}
function closeM(id) {
  g(id)?.classList.remove('on');
  // Hayvan formunu tam sıfırla — bir sonraki açılışta temiz başlasın
  if (id === 'm-animal') {
    ['a-devlet','a-kupe','a-irk-txt','a-dt','a-dkg','a-agirlik','a-boy','a-renk','a-ozellik'].forEach(cl);
    const cins = g('a-cinsiyet'); if (cins) cins.value = '';
    const irkSel = g('a-irk-sel'); if (irkSel) irkSel.value = '';
    const grup = g('a-grup'); if (grup) grup.innerHTML = '<option value="">Önce cinsiyet seçin</option>';
    const padok = g('a-padok'); if (padok) padok.innerHTML = '<option value="">Önce grup seçin</option>';
    const hint = g('a-grup-hint'); if (hint) hint.style.display = 'none';
  }
}
function mClose(e, el) { if (e.target === el) el.classList.remove('on'); }

function toast(msg, err = false) {
  const el = g('toast'); if (!el) return;
  el.textContent = msg;
  el.className = 'on' + (err ? ' err' : '');
  clearTimeout(el._tid);
  el._tid = setTimeout(() => el.className = '', 3200);
}

function showDebug(msg) { console.warn('[debug]', msg); }

// Sync bar
function updateSyncBar() {
  getQueue().then(q => {
    if (!q.length) { hideSyncBar(); return; }
    setSyncBar('warn', `⏳ ${q.length} kayıt bekliyor — internet gelince otomatik gönderilecek`);
  });
}
function setSyncBar(type, txt) {
  const bar = g('sync-bar');
  if (!bar) return;
  bar.className = 'on ' + type;
  g('sync-bar-txt').textContent = txt;
}
function hideSyncBar() { const bar = g('sync-bar'); if (bar) bar.className = ''; }

// ── ROUTING ─────────────────────────────────
function goTo(pg) {
  _curPg = pg;
  document.querySelectorAll('.pg').forEach(p => p.classList.remove('on'));
  document.querySelectorAll('.nb').forEach(b => b.classList.remove('on'));
  const pgEl = g('pg-' + pg);
  const nbEl = g('nb-' + pg);
  if (pgEl) pgEl.classList.add('on');
  if (nbEl) nbEl.classList.add('on');

  if (pg === 'dash')     Promise.all([loadDash(), loadStokList()]);
  if (pg === 'tasks')    loadTasks(_curTaskFilter || 'today');
  if (pg === 'gecmis')   loadGecmis(_curGecmisFilter || 'hepsi');
  if (pg === 'log')      Promise.all([loadBirths(), loadStokList()]);
  if (pg === 'ureme')    loadUreme(_curUremeTab || 'kizginlik');
  if (pg === 'bildirim') loadBildirimler(_curBildirimTab || 'bekliyor');
  if (pg === 'raporlar') loadRaporlar();
  if (pg !== 'dash')     loadDash();
}

// ── RENDER FROM LOCAL ────────────────────────
async function renderFromLocal() {
  await Promise.all([loadAnimals(), loadStock()]);
  const pg = _curPg || 'dash';
  if (pg === 'dash')     await Promise.all([loadDash(), loadStokList()]);
  if (pg === 'tasks')    await loadTasks(_curTaskFilter || 'today');
  if (pg === 'gecmis')   await loadGecmis(_curGecmisFilter || 'hepsi');
  if (pg === 'log')      await Promise.all([loadBirths(), loadStokList()]);
  if (pg === 'ureme')    loadUreme(_curUremeTab || 'kizginlik');
  if (pg === 'bildirim') loadBildirimler(_curBildirimTab || 'bekliyor');
  if (pg === 'raporlar') loadRaporlar();
  if (pg !== 'dash')     loadDash();
  checkSpermaUyari();
  updateBildirimBadge();
}

function updateBildirimBadge() { /* Sprint 3 — bildirim modülü */ }
async function loadBildirimler() { /* Sprint 3 — bildirim modülü */ }

async function refreshAll() {
  await pullFromSupabase();
  await renderFromLocal();
}

// ── HEKİM SELECTS ───────────────────────────
function populateHekimSelects() {
  const all = [...HEKIMLER, ..._customHekimler];
  ['b-hekim','i-hekim','d-hekim','ta-hekim'].forEach(id => {
    const el = g(id); if (!el) return;
    el.innerHTML = all.map(h => `<option value="${h.id}">${h.ad}</option>`).join('');
    el.value = VARSAYILAN_HEKIM;
  });
}

// Hekim/sperma ayarları
function renderAyarlarHekimList() {
  const el = g('ay-hekim-list'); if (!el) return;
  const all = [...HEKIMLER, ..._customHekimler];
  el.innerHTML = all.map(h => `<div style="display:flex;align-items:center;justify-content:space-between;padding:7px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.84rem">${h.ad}</span>
    ${_customHekimler.find(c => c.id === h.id) ? `<button onclick="customHekimSil('${h.id}')" style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.8rem">Sil</button>` : ''}
  </div>`).join('');
}
function renderAyarlarSpermaList() {
  const el = g('ay-sperma-list'); if (!el) return;
  const all = [...new Set([...SPERMA_LISTESI, ..._customSperma])];
  el.innerHTML = all.map(s => `<div style="display:flex;align-items:center;justify-content:space-between;padding:7px 0;border-bottom:1px solid var(--card2)">
    <span style="font-size:.84rem">${s}</span>
    ${_customSperma.includes(s) ? `<button onclick="customSpermaSil('${s.replace(/'/g,"\\'")}') " style="background:none;border:none;color:var(--red);cursor:pointer;font-size:.8rem">Sil</button>` : ''}
  </div>`).join('');
}
function ayarlarHekimEkle()  { g('ay-hekim-form').style.display = 'block'; }
function ayarlarHekimKaydet() {
  const ad = (g('ay-hekim-ad')?.value || '').trim(); if (!ad) return;
  const id = 'CH' + Date.now();
  _customHekimler.push({ id, ad });
  g('ay-hekim-form').style.display = 'none';
  if (g('ay-hekim-ad')) g('ay-hekim-ad').value = '';
  renderAyarlarHekimList();
  populateHekimSelects();
  // DB'ye de yaz (online ise)
  if (navigator.onLine) {
    db.rpc('hekim_ekle', { p_id: id, p_ad: ad }).catch(e => console.warn('Hekim DB yazılamadı:', e.message));
  }
  toast('Hekim eklendi');
}
function customHekimSil(id) {
  _customHekimler = _customHekimler.filter(h => h.id !== id);
  renderAyarlarHekimList();
  populateHekimSelects();
}
function ayarlarSpermaEkle()  { g('ay-sperma-form').style.display = 'block'; }
function ayarlarSpermaKaydet() {
  const kod = (g('ay-sperma-kod')?.value || '').trim(); if (!kod) return;
  if (!_customSperma.includes(kod)) _customSperma.push(kod);
  g('ay-sperma-form').style.display = 'none';
  if (g('ay-sperma-kod')) g('ay-sperma-kod').value = '';
  renderAyarlarSpermaList();
  buildSpermaList();
  toast('Sperma eklendi');
}
function customSpermaSil(kod) {
  _customSperma = _customSperma.filter(s => s !== kod);
  renderAyarlarSpermaList();
}

// ── IRK DROPDOWN ─────────────────────────────
// Backend'den irk listesi çek, dropdown'ı doldur
const IRK_LISTESI_SABIT = ['Holstein','Simental','Montofon','Jersey','Angus','Diğer'];

async function loadIrkDropdown() {
  const sel = g('a-irk-sel'); if (!sel) return;
  try {
    // DB'den kullanım sıklığına göre sıralı liste
    const { data } = await db.rpc('irk_listesi');
    const dbIrkler = (data || []).map(r => r.irk);
    // Sabit listeyi DB sıralamasına göre önce göster, sonra kalanlar
    const sirali = [
      ...dbIrkler.filter(i => IRK_LISTESI_SABIT.includes(i)),
      ...IRK_LISTESI_SABIT.filter(i => !dbIrkler.includes(i)),
      ...dbIrkler.filter(i => !IRK_LISTESI_SABIT.includes(i)),
    ];
    const uniq = [...new Set(sirali)];
    sel.innerHTML = '<option value="">— Seç —</option>' +
      uniq.map(r => `<option value="${r}">${r}</option>`).join('') +
      '<option value="__diger__">+ Diğer (yazın)</option>';
  } catch (e) {
    // DB hatasında sabit listeyi göster
    sel.innerHTML = '<option value="">— Seç —</option>' +
      IRK_LISTESI_SABIT.map(r => `<option value="${r}">${r}</option>`).join('') +
      '<option value="__diger__">+ Diğer (yazın)</option>';
  }
}
function irkSecimDegisti() {
  const sel = g('a-irk-sel');
  const txt = g('a-irk-txt');
  if (!sel || !txt) return;
  if (sel.value === '__diger__') {
    txt.style.display = 'block';
    txt.disabled = false;
    txt.focus();
  } else if (sel.value) {
    txt.style.display = 'none';
    txt.disabled = true;
    txt.value = '';
  } else {
    txt.style.display = 'none';
    txt.disabled = true;
    txt.value = '';
  }
}
function getIrkValue() {
  const sel = g('a-irk-sel');
  const txt = g('a-irk-txt');
  return (sel?.value) || (txt?.value?.trim()) || '';
}

// ── AKTİF HAYVAN FORMU ──────────────────────
// Cinsiyet + yaş → grup seçenekleri
// Grup → padok seçenekleri
const GRUP_PADOK = {
  'Sağmal (Laktasyonda)':      ['Sağmal Padok'],
  'Sağmal (Kuru)':             ['Kuru/Gebe Padok'],
  'Gebe Düve':                 ['Kuru/Gebe Padok'],
  'Düve (Büyük)':              ['Düve Padok (Büyük)'],
  'Düve (Küçük)':              ['Düve Padok (Küçük)'],
  'Süt İçen Buzağı':           ['Buzağı Padok (Süt İçenler)'],
  'Sütten Kesilmiş Buzağı':    ['Buzağı Padok (Sütten Kesilmiş)'],
  'Besi':                      ['Düve Padok (Büyük)', 'Düve Padok (Küçük)', 'Sağmal Padok'],
};

function animalFormGuncelle() {
  const cinsiyet = v('a-cinsiyet');
  const dt       = v('a-dt');
  const grupSel  = g('a-grup');
  const hint     = g('a-grup-hint');
  if (!grupSel) return;

  let yasGun = null;
  if (dt && dt.trim() !== '') {
    const d = new Date(dt);
    if (!isNaN(d.getTime())) yasGun = Math.floor((Date.now() - d) / 86400000);
  }

  let gruplar = [];

  if (!cinsiyet) {
    grupSel.innerHTML = '<option value="">Önce cinsiyet seçin</option>';
    g('a-padok').innerHTML = '<option value="">Önce grup seçin</option>';
    if (hint) hint.style.display = 'none';
    return;
  }

  if (cinsiyet === 'Dişi') {
    if (yasGun !== null && yasGun <= 75)
      gruplar = ['Süt İçen Buzağı'];
    else if (yasGun !== null && yasGun > 75 && yasGun <= 180)
      gruplar = ['Sütten Kesilmiş Buzağı'];
    else if (yasGun !== null && yasGun > 180 && yasGun <= 365)
      gruplar = ['Düve (Küçük)', 'Sütten Kesilmiş Buzağı'];
    else if (yasGun !== null && yasGun > 365 && yasGun <= 730)
      gruplar = ['Düve (Büyük)', 'Düve (Küçük)'];
    else
      gruplar = ['Sağmal (Laktasyonda)', 'Sağmal (Kuru)', 'Gebe Düve', 'Düve (Büyük)', 'Düve (Küçük)', 'Sütten Kesilmiş Buzağı', 'Süt İçen Buzağı'];
  } else { // Erkek
    if (yasGun !== null && yasGun <= 75)
      gruplar = ['Süt İçen Buzağı'];
    else if (yasGun !== null && yasGun > 75 && yasGun <= 180)
      gruplar = ['Sütten Kesilmiş Buzağı'];
    else
      gruplar = ['Besi', 'Sütten Kesilmiş Buzağı'];
  }

  grupSel.innerHTML = '<option value="">Seçin</option>' +
    gruplar.map(gr => `<option value="${gr}">${gr}</option>`).join('');

  if (hint) {
    if (cinsiyet === 'Erkek') {
      hint.textContent = 'Erkek hayvan Sağmal/Kuru/Gebe grubuna eklenemez';
      hint.style.display = 'block';
    } else {
      hint.style.display = 'none';
    }
  }

  g('a-padok').innerHTML = '<option value="">Önce grup seçin</option>';
  animalGrupDegisti();
}

function animalGrupDegisti() {
  const grup    = v('a-grup');
  const padokSel = g('a-padok');
  if (!padokSel) return;
  const padoklar = GRUP_PADOK[grup] || [];
  if (!padoklar.length) {
    padokSel.innerHTML = '<option value="">Önce grup seçin</option>';
    return;
  }
  padokSel.innerHTML = padoklar.map(p => `<option value="${p}">${p}</option>`).join('');
  padokSel.value = padoklar[0];
}

// ── SPERMA LİSTESİ ──────────────────────────
async function spermaModStok() {
  g('sperma-stok-area').style.display = 'block';
  g('sperma-elle-area').style.display = 'none';
  g('btn-sperma-stok').style.background = 'rgba(42,107,181,.2)';
  g('btn-sperma-elle').style.background = 'var(--card2)';

  const sel = g('i-sperma-select');
  if (!sel) return;

  // _S henüz yüklenmediyse yükle
  if (!_S || !_S.length) await loadStock();

  const stoklar = (window._appState?.stok || _S || []).filter(s => s.kategori === 'Sperma' && (s.guncel ?? s.miktar ?? 0) > 0);

  if (stoklar.length === 0) {
    sel.innerHTML = '<option value="">— Stokta sperma yok —</option>';
    g('sperma-hint').textContent = 'Stok eklemek için Stok sekmesine gidin';
  } else {
    sel.innerHTML =
      '<option value="">— Seçin —</option>' +
      stoklar.map(s => `<option value="${s.ad}">${s.ad} (${s.miktar} doz)</option>`).join('');

    g('sperma-hint').textContent = '';
  }

  g('i-sperma').value = '';
}

function spermaModElle() {
  g('sperma-stok-area').style.display = 'none';
  g('sperma-elle-area').style.display = 'block';
  g('btn-sperma-elle').style.background = 'rgba(42,107,181,.2)';
  g('btn-sperma-stok').style.background = 'var(--card2)';

  g('i-sperma').value = '';
  g('sperma-hint').textContent = 'Boğa kodu veya sperma adını yazın';
}

async function buildSpermaList() {
  const tohs = await idbGetAll('tohumlama');

  const used = [...new Set(tohs.map(t => t.sperma).filter(Boolean))];

  const all = [...new Set([
    ...SPERMA_LISTESI,
    ..._customSperma,
    ...used
  ])];

  const dl = g('dl-sperma');

  if (dl) {
    dl.innerHTML = all.map(s => `<option value="${s}">`).join('');
  }
}

// ── HASTALIK AUTOCOMPLETE ───────────────────
async function buildDiseaseFreq() {
  _disFreq = {}; // hastalik_log kaldırıldı — diseases tablosu kullanılıyor
}
// Kategoriye göre semptom listesi
const SEMPTOM_KAT = {
  'Solunum': ['Öksürük','Burun Akıntısı','Nefes Darlığı','Ateş','Hırıltı','İştahsızlık','Halsizlik'],
  'Sindirim': ['İshal','Kabızlık','Şişkinlik','İştahsızlık','Ateş','Halsizlik','Ağız Kokusu'],
  'Üreme':   ['Akıntı','Ateş','İştahsızlık','Halsizlik','Yememe','Ödem'],
  'Ayak':    ['Topallık','Şişlik','Isı Artışı','Yara','Ağrı'],
  'Meme':    ['Süt Değişimi','Meme Şişliği','Ateş','Ağrı','İştahsızlık','Halsizlik'],
  'Metabolik':['Sallantı','Düşkünlük','Ateş','Halsizlik','Titreme','Yememe','Ödem'],
  'Buzağı':  ['İshal','Halsizlik','Ateş','Göbek Şişliği','İştahsızlık','Solunum Güçlüğü'],
};
const SEMPTOM_GENEL = ['Ateş','Halsizlik','İştahsızlık','Ağrı','Ödem','Titreme','Yememe','Düşkünlük'];

function filterHastalikList() {
  const kat     = g('d-kat')?.value || '';
  const wrap    = g('tani-secenekler');
  const lokWrap = g('d-lokasyon-wrap');
  const lokSec  = g('d-lokasyon-secenekler');
  const lokLbl  = g('d-lokasyon-lbl');
  if (!wrap) return;

  const liste = kat && HASTALIK_KAT[kat] ? HASTALIK_KAT[kat] : HASTALIK_LISTESI;
  wrap.innerHTML = liste.map(h => `<button type="button" onclick="selDis('${h.replace(/'/g,"\\'")}',this)"
    style="padding:5px 11px;border:1.5px solid var(--card3);border-radius:20px;background:var(--card);font-size:.72rem;font-weight:700;color:var(--ink2);cursor:pointer;transition:all .12s"
    class="tani-btn">${h}</button>`).join('');

  const lokList = LOKASYON_KAT[kat] || [];
  if (lokList.length && lokWrap && lokSec && lokLbl) {
    lokLbl.textContent = kat === 'Meme' ? 'Çeyrek' : 'Hangi Ayak';
    lokSec.innerHTML = lokList.map(l => `<button type="button" onclick="toggleLokasyon('${l}',this)"
      style="padding:5px 11px;border:1.5px solid var(--card3);border-radius:20px;background:var(--card);font-size:.72rem;font-weight:700;color:var(--ink2);cursor:pointer"
      class="lok-btn">${l}</button>`).join('');
    lokWrap.style.display = 'block';
    g('d-lokasyon').value = '';
  } else if (lokWrap) {
    lokWrap.style.display = 'none';
    g('d-lokasyon').value = '';
  }

  // Semptom dropdown'ı güncelle
  _semptomSecili = [];
  const semptChips = g('sempt-chips');
  if (semptChips) semptChips.innerHTML = '';
  if (g('d-sempt')) g('d-sempt').value = '';
  updateSemptomDropdown(kat);

  g('d-tani').value = '';
  const acDis = g('ac-dis');
  if (acDis) acDis.style.display = 'none';
}

let _semptomSecili = [];

function updateSemptomDropdown(kat) {
  const sel = g('sempt-ekle'); if (!sel) return;
  const liste = (kat && SEMPTOM_KAT[kat]) ? SEMPTOM_KAT[kat] : SEMPTOM_GENEL;
  const kalanlar = liste.filter(s => !_semptomSecili.includes(s));
  sel.innerHTML = '<option value="">+ Semptom ekle…</option>' +
    kalanlar.map(s => `<option value="${s}">${s}</option>`).join('');
  sel.style.display = kalanlar.length ? 'block' : 'none';
}

function semptomEkle(sel) {
  const val = sel.value || sel._noReset && sel.value === '' ? sel.value : sel.value; if (!val) return;
  if (!sel._noReset) sel.value = '';
  if (_semptomSecili.includes(val)) return;
  _semptomSecili.push(val);
  const chips = g('sempt-chips'); if (!chips) return;
  const chip = document.createElement('span');
  chip.style.cssText = 'display:inline-flex;align-items:center;gap:4px;padding:4px 10px;background:rgba(42,107,181,.12);border:1px solid rgba(42,107,181,.25);border-radius:20px;font-size:.72rem;font-weight:700;color:var(--blue);cursor:pointer';
  chip.innerHTML = `${val} <span style="font-size:.9rem;opacity:.7" onclick="semptomKaldir('${val}',this.parentElement)">✕</span>`;
  chips.appendChild(chip);
  if (g('d-sempt')) g('d-sempt').value = _semptomSecili.join(', ');
  const kat = g('d-kat')?.value || '';
  updateSemptomDropdown(kat);
}

function semptomKaldir(val, chip) {
  _semptomSecili = _semptomSecili.filter(s => s !== val);
  chip?.remove();
  if (g('d-sempt')) g('d-sempt').value = _semptomSecili.join(', ');
  const kat = g('d-kat')?.value || '';
  updateSemptomDropdown(kat);
}

// ── DÜZENLEME FORMU SEMPTOM SİSTEMİ ────────────
let _hdeSmptSecili = [];

function hdeUpdateSmptDropdown(kat) {
  const sel = g('hde-sempt-ekle'); if (!sel) return;
  const liste = (kat && SEMPTOM_KAT[kat]) ? SEMPTOM_KAT[kat] : SEMPTOM_GENEL;
  const kalanlar = liste.filter(s => !_hdeSmptSecili.includes(s));
  sel.innerHTML = '<option value="">+ Semptom ekle…</option>' +
    kalanlar.map(s => `<option value="${s}">${s}</option>`).join('');
  sel.style.display = kalanlar.length ? '' : 'none';
}

function hdeSmptomEkle(sel) {
  const val = sel.value; if (!val) return;
  sel.value = '';
  if (_hdeSmptSecili.includes(val)) return;
  _hdeSmptSecili.push(val);
  const chips = g('hde-sempt-chips'); if (!chips) return;
  const chip = document.createElement('span');
  chip.style.cssText = 'display:inline-flex;align-items:center;gap:4px;padding:4px 10px;background:rgba(42,107,181,.12);border:1px solid rgba(42,107,181,.25);border-radius:20px;font-size:.72rem;font-weight:700;color:var(--blue);cursor:pointer';
  chip.innerHTML = `${val} <span style="font-size:.9rem;opacity:.7" onclick="hdeSmptomKaldir('${val}',this.parentElement)">✕</span>`;
  chips.appendChild(chip);
  if (g('hde-semptomlar')) g('hde-semptomlar').value = _hdeSmptSecili.join(', ');
  hdeUpdateSmptDropdown(g('hde-tani')?.dataset?.kat || '');
}

function hdeSmptomKaldir(val, chip) {
  _hdeSmptSecili = _hdeSmptSecili.filter(s => s !== val);
  chip?.remove();
  if (g('hde-semptomlar')) g('hde-semptomlar').value = _hdeSmptSecili.join(', ');
  hdeUpdateSmptDropdown(g('hde-tani')?.dataset?.kat || '');
}

// ── DÜZENLEME FORMU TANI AUTOCOMPLETE ────────────
function acHdeTani(inp) {
  const q = (inp.value || '').toLowerCase().trim();
  const ac = g('ac-hde-tani'); if (!ac) return;
  const kat = _curHst?.kategori || '';
  const base = (kat && HASTALIK_KAT[kat]) ? HASTALIK_KAT[kat] : HASTALIK_LISTESI;
  const filtered = q ? base.filter(h => h.toLowerCase().includes(q)) : base.slice(0, 12);
  if (!filtered.length) { ac.style.display = 'none'; return; }
  ac.innerHTML = filtered.map(h =>
    `<div onclick="hdeSelTani('${h.replace(/'/g, "\\'")}','${kat}')"
      style="padding:8px 12px;cursor:pointer;font-size:.82rem;border-bottom:1px solid var(--card2)"
      onmouseover="this.style.background='var(--card2)'" onmouseout="this.style.background=''>${h}</div>`
  ).join('');
  ac.style.display = 'block';
}

function hdeSelTani(val, kat) {
  const inp = g('hde-tani'); if (!inp) return;
  inp.value = val;
  inp.dataset.kat = kat;
  g('ac-hde-tani').style.display = 'none';
  hdeUpdateSmptDropdown(kat);
}

function hdeToggleLok(val, btn) {
  btn.classList.toggle('lok-on');
  if (btn.classList.contains('lok-on')) {
    btn.style.background = 'var(--green)'; btn.style.borderColor = 'var(--green)'; btn.style.color = '#fff';
  } else {
    btn.style.background = 'var(--card)'; btn.style.borderColor = 'var(--card3)'; btn.style.color = 'var(--ink2)';
  }
  const secili = [...document.querySelectorAll('.hde-lok-btn.lok-on')].map(b => b.textContent.trim());
  document.getElementById('hde-lokasyon').value = secili.join(', ');
}

function toggleLokasyon(val, btn) {
  btn.classList.toggle('lok-on');
  if (btn.classList.contains('lok-on')) {
    btn.style.background = 'var(--green)'; btn.style.borderColor = 'var(--green)'; btn.style.color = '#fff';
  } else {
    btn.style.background = 'var(--card)'; btn.style.borderColor = 'var(--card3)'; btn.style.color = 'var(--ink2)';
  }
  const secili = [...document.querySelectorAll('.lok-btn.lok-on')].map(b => b.textContent.trim());
  g('d-lokasyon').value = secili.join(', ');
}

async function acDisease() {
  const q   = (g('d-tani')?.value || '').toLowerCase().trim();
  const kat = g('d-kat')?.value || '';
  const ac  = g('ac-dis');
  if (!q) { ac.style.display = 'none'; return; }
  const usedDis = []; // hastalik_log kaldırıldı
  const base    = kat && HASTALIK_KAT[kat] ? HASTALIK_KAT[kat] : HASTALIK_LISTESI;
  const all     = [...new Set([...base, ...usedDis])];
  const filtered = all.filter(d => d.toLowerCase().includes(q));
  if (!filtered.length) { ac.style.display = 'none'; return; }
  ac.innerHTML = filtered.map(d => `<div onclick="selDis('${d.replace(/'/g,"\\'")}');event.stopPropagation()"
    style="padding:9px 12px;font-size:.84rem;cursor:pointer;border-bottom:1px solid #eee">${d}</div>`).join('');
  ac.style.display = 'block';
}

function selDis(val, btn) {
  g('d-tani').value = val;
  g('ac-dis').style.display = 'none';
  document.querySelectorAll('.tani-btn').forEach(b => {
    b.style.background = 'var(--card)'; b.style.borderColor = 'var(--card3)'; b.style.color = 'var(--ink2)';
  });
  if (btn) { btn.style.background = 'var(--green)'; btn.style.borderColor = 'var(--green)'; btn.style.color = '#fff'; }
}

document.addEventListener('click', e => {
  const ac = g('ac-dis');
  if (ac && !e.target.closest('#d-tani') && !e.target.closest('#ac-dis')) ac.style.display = 'none';
  const acHde = g('ac-hde-tani');
  if (acHde && !e.target.closest('#hde-tani') && !e.target.closest('#ac-hde-tani')) acHde.style.display = 'none';
});

// Enter → sonraki alan
document.addEventListener('keydown', e => {
  if (e.key !== 'Enter') return;
  const tag = e.target.tagName;
  if (tag === 'TEXTAREA') return;
  if (tag === 'INPUT' || tag === 'SELECT') {
    e.preventDefault();
    const modal = e.target.closest('.modal');
    if (!modal) return;
    const fields = Array.from(modal.querySelectorAll('input:not([disabled]),select:not([disabled]),textarea:not([disabled]),button.btn:not([disabled])'));
    const idx = fields.indexOf(e.target);
    if (idx >= 0 && idx < fields.length - 1) fields[idx + 1].focus();
  }
});

// ── INIT ─────────────────────────────────────
window.addEventListener('load', async () => {
  try { await openDB(); } catch (e) { console.error('DB hatası:', e.message); }

  const t = new Date().toISOString().split('T')[0];
  ['b-tarih','i-tarih','ta-tarih','k-tarih'].forEach(id => { const el = g(id); if (el) el.value = t; });

  await loadHekimler();  // DB'den + fallback
  await loadIrkDropdown();

  try { await renderFromLocal(); } catch (e) {
    console.warn('render err:', e);
    const el = g('dash-body');
    if (el) el.innerHTML = `<div class="empty" style="padding:20px">⚠️ Yükleme hatası: ${e.message}<br><button class="btn btn-g" style="margin-top:12px" onclick="location.reload()">Yenile</button></div>`;
  }
  updateSyncBar();

  if (navigator.onLine) {
    try {
      await pullFromSupabase();
      await renderFromLocal();
      syncNow();
    } catch (e) { console.warn('Pull failed:', e.message); }
  } else {
    g('dot')?.classList.add('warn');
    toast('Çevrimdışı — yerel veri gösteriliyor');
  }

  buildSpermaList();
  buildDiseaseFreq();

  if (localStorage.getItem('bildirim_aktif') === '1') {
    bildirimKontrol();
    setInterval(bildirimKontrol, 3600000);
  }
});

window.addEventListener('online', async () => {
  g('dot')?.classList.remove('off', 'warn');
  toast('🌐 Bağlantı geldi');
  await syncNow();
  await pullFromSupabase();
  renderFromLocal();
});

window.addEventListener('offline', () => {
  g('dot')?.classList.add('off');
  toast('📵 Çevrimdışı — kayıtlar cihazda saklanacak');
});

// Service Worker — tüm kayıtları temizle
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(regs => {
    regs.forEach(r => r.unregister());
  });
  caches.keys().then(keys => keys.forEach(k => caches.delete(k)));
}