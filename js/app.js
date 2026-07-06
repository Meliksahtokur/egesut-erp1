// ══════════════════════════════════════════
// EgeSüt — app.js
// Global state, routing, init
// ══════════════════════════════════════════

// ── UI TELEMETRY ─────────────────────────────
// Test sırasında kullanıcı hareketleri ve UI hatalarını Supabase'e loglar
const _sessionId = Math.random().toString(36).slice(2, 9);

async function uiLog(level, message, extra = {}) {
  try {
    await db.from('ui_logs').insert({
      level, message,
      source: extra.source || null,
      payload: Object.keys(extra).length ? extra : null,
      session_id: _sessionId
    });
  } catch (_) {}  // log hatası uygulamayı durdurmasın
}

// Global hata yakalayıcılar — index.html'deki _captureError uiLog'u çağırır

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

// HASTALIK_LISTESI config.js'den geliyor

// HASTALIK_KAT config.js'den geliyor

// LOKASYON_KAT config.js'den geliyor

// SPERMA_LISTESI config.js'den geliyor

let _customHekimler = [];
let _customSperma   = [];
let _disFreq        = {};
let _ilacCache      = [];


// ── GLOBAL STATE ────────────────────────────
// let _A=[], _S[], _curStk... state'e tasindi (state.js + getState/setState)
let _suruFilter = 'tumuu', _suruSiralama = 'kupe';
let _curUremeTab = 'kizginlik', _curGecmisFilter = 'hepsi', _curTaskFilter = 'today', _gecmisTumu = false, _pendWin = null;
let _tanimlarTab = 'hastaliklar';
let _curTaskDet  = null, _curHst = null, _curToh = null;
let _curBildirimTab = 'bekliyor';

// helpers.js, modal.js'den geliyor (js/utils/)
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
async function goTo(pg, push = true) {
  if(getState('currentPage')==='tasks' && pg!=='tasks' && typeof flushPendingDone==='function') flushPendingDone();
  setState('currentPage', pg);
  if (push) history.pushState({pg}, '', '#' + pg);
  document.querySelectorAll('.pg').forEach(p => p.classList.remove('on'));
  document.querySelectorAll('.nb').forEach(b => b.classList.remove('on'));
  const pgEl = g('pg-' + pg);
  const nbEl = g('nb-' + pg);
  if (pgEl) pgEl.classList.add('on');
  if (nbEl) nbEl.classList.add('on');

  if (pg === 'suru')     { if (typeof fchipReset === 'function') fchipReset(); filterA(); }
  else if (pg === 'dash')     { await Promise.all([loadDash(), loadStokList()]); }
  else if (pg === 'tasks')    { loadTasks(_curTaskFilter || 'today'); loadDash(); }
  else if (pg === 'gecmis')   { loadGecmis(_curGecmisFilter || 'hepsi'); loadDash(); }
  else if (pg === 'log')      { await Promise.all([loadBirths(), loadStokList()]); loadDash(); }
  else if (pg === 'ureme')    { loadUreme(_curUremeTab || 'kizginlik'); loadDash(); }
  else if (pg === 'bildirim') { loadBildirimler(_curBildirimTab || 'bekliyor'); loadDash(); }
  else if (pg === 'raporlar') { loadRaporlar(); loadDash(); }
  else if (pg === 'asistan')  { if (typeof asistanInit === 'function') asistanInit(); }
  if (typeof updateKizginlikAlert === 'function') updateKizginlikAlert();
}

window.addEventListener('popstate', e => {
  // Açık modal varsa en üsttekini kapat (Android geri tuşu — tüm modallar)
  const openModals = document.querySelectorAll('.modal.on');
  if (openModals.length) {
    const top = openModals[openModals.length - 1];
    top.classList.remove('on');
    return;
  }
  // Sentinel: history stack'in dibine ulaştık — uygulamadan çıkılacak
  if (e.state?.sentinel) {
    if (confirm('Uygulamadan çıkmak istediğinizden emin misiniz?')) {
      // Onayladı — tarayıcı/PWA kapanabilir, geri gidebilir
      return;
    }
    // İptal — dash'e geri dön
    history.pushState({pg:'dash'}, '', '#dash');
    goTo('dash', false);
    return;
  }
  // Protokol iş detay bottom-sheet açıksa kapat, protokol ekranına dön
  const protoDetay = document.getElementById('proto-detay-bs');
  if (protoDetay && protoDetay.style.display !== 'none') {
    protoDetay.remove();
    // Protokol ekranı ve hayvan kartı tekrar göster
    const protokolBs = document.getElementById('protokol-bs');
    if (protokolBs) protokolBs.style.display = 'flex';
    return;
  }

  // Hayvan kartı açıksa ve protokol ekranı gizliyse — kartı kapat, protokol ekranlarını göster
  const det = document.getElementById('det');
  if (det?.classList.contains('on')) {
    closeDet();
    window._prevTaskId = null;
    const protokolBs2 = document.getElementById('protokol-bs');
    if (protokolBs2 && protokolBs2.style.display === 'none') {
      protokolBs2.style.display = 'flex';
      const protoDetay2 = document.getElementById('proto-detay-bs');
      if (protoDetay2) protoDetay2.style.display = 'flex';
    }
    return;
  }
  // Sayfalar arası geri — history.back() ile geldiğimizde push etme
  goTo(e.state?.pg || 'dash', false);
});

// ── RENDER FROM LOCAL ────────────────────────
async function renderFromLocal() {
  await Promise.all([loadAnimals(), loadStock()]);
  const pg = getState('currentPage') || 'dash';
  if (pg === 'dash')     { await Promise.all([loadDash(), loadStokList()]); }
  else if (pg === 'tasks')    { if(typeof _pendingDone!=='undefined' && _pendingDone.size){ await loadDash(); } else { await loadTasks(_curTaskFilter || 'today'); await loadDash(); } }
  else if (pg === 'gecmis')   { await loadGecmis(_curGecmisFilter || 'hepsi'); await loadDash(); }
  else if (pg === 'log')      { await Promise.all([loadBirths(), loadStokList()]); await loadDash(); }
  else if (pg === 'ureme')    { await loadUreme(_curUremeTab || 'kizginlik'); await loadDash(); }
  else if (pg === 'bildirim') { await loadBildirimler(_curBildirimTab || 'bekliyor'); await loadDash(); }
  else if (pg === 'raporlar') { await loadRaporlar(); await loadDash(); }
  if (typeof updateKizginlikAlert === 'function') updateKizginlikAlert();
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
  ['b-hekim','i-hekim','d-hekim','ta-hekim','tr-hekim'].forEach(id => {
    const el = g(id); if (!el) return;
    el.innerHTML = all.map(h => `<option value="${h.id}">${esc(h.ad)}</option>`).join('');
    el.value = VARSAYILAN_HEKIM;
  });
}

// Hekim/sperma ayarları
// renderAyarlarHekimList — defined in ui.js (Supabase-backed, with hekim card)
// ayarlarHekimEkle / ayarlarHekimKaydet — ui.js'deki DB-backed (Supabase) versiyonlar kullanılır.
// Buradaki eski yerel-_customHekimler kopyaları kaldırıldı: app.js en son yüklendiği için
// ui.js'in doğru versiyonlarını eziyordu + yanlış input id ('ay-hekim-ad') okuyordu → hekim ekleme çalışmıyordu.
// customHekimSil de öksüzdü (hiç çağrılmıyordu), silindi. (_customHekimler boş fallback olarak kalıyor.)
// renderAyarlarSpermaList / ayarlarSpermaEkle / ayarlarSpermaKaydet / customSpermaSil —
// ölü kod olarak arşivlendi (js/_archive/ayarlarSperma.bak.js): index.html'de giriş
// noktası (ay-sperma-list/-form/-kod elementleri) hiç yok, sperma zaten Stok sekmesinden
// (kategori='Sperma') yönetiliyor.

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
  } else {
    txt.style.display = 'none';
    txt.disabled = true;
    txt.value = '';
  }
}
function getIrkValue() {
  const sel = g('a-irk-sel');
  const txt = g('a-irk-txt');
  if (sel?.value === '__diger__') return txt?.value?.trim() || '';
  return sel?.value || '';
}

// ── AKTİF HAYVAN FORMU ──────────────────────
// Cinsiyet + yaş → grup seçenekleri
// Grup → padok seçenekleri
// GRUP_PADOK config.js'den geliyor

async function animalFormGuncelle() {
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

  // Mevcut hayvanın geçmişini kontrol et (düzenleme modunda)
  const editId = g('m-animal')?.dataset.editId || null;
  let tohumlanmis = false;
  let dogumAbortVar = false;
  if (editId) {
    const [tohumlar, dogumlar] = await Promise.all([idbGetAll('tohumlama'), idbGetAll('dogum')]);
    const hayvanTohumlar = tohumlar.filter(t => t.hayvan_id === editId);
    tohumlanmis = hayvanTohumlar.length > 0;
    dogumAbortVar = dogumlar.some(d => d.anne_id === editId) ||
                   hayvanTohumlar.some(t => t.sonuc === 'Doğum Yaptı' || t.sonuc === 'Abort');
  }

  let gruplar = [];

  if (!cinsiyet) {
    grupSel.innerHTML = '<option value="">Önce cinsiyet seçin</option>';
    g('a-padok').innerHTML = '<option value="">Önce grup seçin</option>';
    if (hint) hint.style.display = 'none';
    return;
  }

  if (cinsiyet === 'Dişi') {
    if (dogumAbortVar) {
      // Doğum veya abort geçmişi → artık inek, sadece laktasyon/kuru
      gruplar = ['Sağmal (Laktasyonda)', 'Sağmal (Kuru)'];
    } else if (tohumlanmis) {
      // Tohumlanmış ama henüz doğum/abort yok → düve veya gebe düve veya inek
      gruplar = ['Gebe Düve', 'Sağmal (Laktasyonda)', 'Sağmal (Kuru)', 'Düve (Büyük)', 'Düve (Küçük)'];
    } else if (yasGun !== null && yasGun <= 180) {
      gruplar = ['Süt İçen Buzağı', 'Sütten Kesilmiş Buzağı'];
    } else if (yasGun !== null && yasGun > 180 && yasGun <= 365) {
      gruplar = ['Düve (Küçük)'];
    } else if (yasGun !== null && yasGun > 365 && yasGun <= 730) {
      gruplar = ['Düve (Büyük)', 'Düve (Küçük)'];
    } else {
      // 730+ gün veya yaş bilinmiyor → yetişkin dişi, buzağı grubu yok
      gruplar = ['Sağmal (Laktasyonda)', 'Sağmal (Kuru)', 'Gebe Düve', 'Düve (Büyük)', 'Düve (Küçük)'];
    }
  } else if (yasGun !== null && yasGun <= 180) { // Erkek buzağı
    gruplar = ['Süt İçen Buzağı', 'Sütten Kesilmiş Buzağı'];
  } else if (yasGun !== null && yasGun > 180) {
    gruplar = ['Besi'];
  } else {
    // Erkek, yaş bilinmiyor
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
  const padokAdlari = GRUP_PADOK[grup] || [];
  if (!padokAdlari.length) {
    padokSel.innerHTML = '<option value="">Önce grup seçin</option>';
    return;
  }
  // PADOKLAR dizisinden UUID'leri bul (DB yüklüyse), yoksa ad kullan
  const opts = padokAdlari.map(ad => {
    const p = PADOKLAR.find(x => x.ad === ad);
    return p ? `<option value="${p.id}">${p.ad}</option>` : `<option value="">${ad}</option>`;
  });
  padokSel.innerHTML = opts.join('');
  // Besi grubunda cinsiyet bazlı varsayılan padok
  if (grup === 'Besi') {
    const cins = v('a-cinsiyet');
    const hedef = cins === 'Erkek' ? 'Besi Padok (Erkek)' : 'Besi Padok (Dişi)';
    const p = PADOKLAR.find(x => x.ad === hedef);
    if (p) padokSel.value = p.id;
  }
}

// ── SPERMA LİSTESİ ──────────────────────────
async function spermaModStok() {
  g('sperma-stok-area').style.display = 'block';
  g('sperma-elle-area').style.display = 'none';
  g('btn-sperma-stok').style.background = 'rgba(42,107,181,.2)';
  g('btn-sperma-elle').style.background = 'var(--card2)';

  const sel = g('i-sperma-select');
  if (!sel) return;

  if (!getState('stock') || !getState('stock').length) await loadStock();

  const stoklar = (getState('stock') || []).filter(s =>
    s.kategori === 'Sperma' || s.grup === 'Sperma' ||
    (s.urun_adi || '').toLowerCase().includes('sperma') ||
    (s.urun_adi || '').toLowerCase().includes('doz')
  );

  if (stoklar.length === 0) {
    sel.innerHTML = '<option value="">— Stokta sperma yok —</option>';
    g('sperma-hint').textContent = 'Stok eklemek için Stok sekmesine gidin';
  } else {
    sel.innerHTML =
      '<option value="">— Seçin —</option>' +
      stoklar.map(s => `<option value="${s.urun_adi}" data-stok="${s.guncel ?? 0}">${s.urun_adi} (${s.guncel ?? 0} doz)</option>`).join('');
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
// SEMPTOM_KAT config.js'den geliyor
// SEMPTOM_GENEL config.js'den geliyor

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
  const val = sel.value; if (!val) return;
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

function selDis(val, btn) {
  g('d-tani').value = val;
  g('ac-dis').style.display = 'none';
  // Tanı butonlarını resetle
  document.querySelectorAll('.tani-btn').forEach(b => {
    b.style.background = 'var(--card)'; b.style.borderColor = 'var(--card3)'; b.style.color = 'var(--ink2)';
  });
  if (btn) { btn.style.background = 'var(--green)'; btn.style.borderColor = 'var(--green)'; btn.style.color = '#fff'; }
  // Form alanlarını temizle (BUG-003 fix)
  const form = g('ac-dis')?.closest('form') || document.querySelector('.vaka-form');
  if (form) form.reset();
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
window.addEventListener('load', withErrorHandling(async () => {
  // ── AUTH GATE (Faz 1) — oturum yoksa login göster, app init etme ──
  const _session = await window.authGate();
  if (!_session) return;

  // Sentinel state — stack'in dibini işaretle (çıkış onayı için)
  history.replaceState({sentinel:true}, '', '#');
  history.pushState({pg:'dash'}, '', '#dash');
  try { await openDB(); } catch (e) { console.error('DB hatası:', e.message); }

  const t = new Date().toISOString().split('T')[0];
  ['b-tarih','i-tarih','ta-tarih','k-tarih'].forEach(id => { const el = g(id); if (el) el.value = t; });

  await loadHekimler();  // DB'den + fallback
  await loadIrkDropdown();

  try { await renderFromLocal(); } catch (e) {
    console.warn('render err:', e);
    const el = g('dash-body');
    if (el) el.innerHTML = `<div class="empty" style="padding:20px">⚠️ Yükleme hatası: ${esc(e.message)}<br><button class="btn btn-g" style="margin-top:12px" onclick="location.reload()">Yenile</button></div>`;
  }
  updateSyncBar();

  // Background sync başlat (organik realtime geçişi — 30sn interval)
  startBackgroundSync(30000);
  initRealtime(); // Realtime WebSocket — bağlanırsa polling durur

  if (navigator.onLine) {
    try {
      await pullFromSupabase();
      await recoverPendingDone();   // çökme öncesi bekleyenleri commit et
      await renderFromLocal();
      syncNow();
      // Padok + hekim config yükle (IDB dolu olduktan sonra)
      await Promise.all([loadPadokConfig(), loadHekimlerFromDB()]);
      populateHekimSelects();
      // _TH ön yükleme — tohumlama modalı açıldığında dropdown hazır olsun
      db.from('tohumlanabilir_hayvanlar').select('*').then(({data}) => {
        globalThis._TH = data || [];
      }).catch(console.warn);
      // İleri gebe görev kontrolü — sessiz, fire-and-forget
      rpc('gebelik_protokol_kontrol').then(res=>{ if(res?.hayvanlar){ window.__ileriGebeListesi=res.hayvanlar; loadDash(); } }).catch(console.warn);
    } catch (e) { console.warn('Pull failed:', e.message); }
  } else {
    g('dot')?.classList.add('warn');
    toast('Çevrimdışı — yerel veri gösteriliyor');
    // Çevrimdışı: IDB'den yükle
    Promise.all([loadPadokConfig(), loadHekimlerFromDB()]).then(() => populateHekimSelects()).catch(console.warn);
  }

  buildSpermaList();
  buildDiseaseFreq();

  if (localStorage.getItem('bildirim_aktif') === '1') {
    bildirimKontrol();
    setInterval(bildirimKontrol, 3600000);
  }
}));

window.addEventListener('online', withErrorHandling(async () => {
  g('dot')?.classList.remove('off', 'warn');
  toast('🌐 Bağlantı geldi');
  // Background sync yeniden başlat
  startBackgroundSync(30000);
  await syncNow();
  await pullFromSupabase();
  renderFromLocal();
}));

window.addEventListener('offline', () => {
  g('dot')?.classList.add('off');
  toast('📵 Çevrimdışı — kayıtlar cihazda saklanacak');
  // Background sync durdur (internet yokken gereksiz)
  stopBackgroundSync();
});

// Service Worker — tüm kayıtları temizle
// ── PWA INSTALL ──────────────────────────────
let _pwaPrompt = null;
window.addEventListener('beforeinstallprompt', e => {
  e.preventDefault();
  _pwaPrompt = e;
  const btn = document.getElementById('pwa-install-btn');
  if (btn) btn.style.display = 'inline-block';
});
window.addEventListener('appinstalled', () => {
  _pwaPrompt = null;
  toast('✅ EgeSüt ana ekrana eklendi!');
});
function pwaInstall() {
  if (_pwaPrompt) {
    _pwaPrompt.prompt();
    _pwaPrompt.userChoice.then(r => {
      if (r.outcome === 'accepted') toast('✅ Kurulum başladı');
      _pwaPrompt = null;
    });
  } else {
    // Zaten kuruluysa veya tarayıcı prompt'u desteklemiyorsa talimat
    const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
    if (isIOS) toast('Safari\'de: Paylaş → Ana Ekrana Ekle');
    else toast('Tarayıcı menüsü (⋮) → Ana Ekrana Ekle / Uygulamayı Kur');
  }
}

// M-10 fix: eskiden her sayfa yüklemesinde TÜM service worker + cache'leri siliyordu.
// Uygulamanın hiçbir yerinde serviceWorker.register() çağrısı yok (grep ile doğrulandı) —
// bu blok sadece eski bir deploy'dan kalmış olabilecek SW/cache'i temizlemek için var.
// Her yüklemede tekrarlamaya gerek yok, bir kere yeter.
if ('serviceWorker' in navigator && !localStorage.getItem('ege_sw_temizlendi')) {
  navigator.serviceWorker.getRegistrations().then(regs => {
    regs.forEach(r => r.unregister());
  });
  caches.keys().then(keys => keys.forEach(k => caches.delete(k)));
  try { localStorage.setItem('ege_sw_temizlendi', '1'); } catch(_) {}
}