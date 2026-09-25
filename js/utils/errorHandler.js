// js/utils/errorHandler.js
// Merkezi hata yönetimi

let debugMode = false;
try { debugMode = localStorage.getItem('debug') === 'true'; } catch(e) {}

const USER_FRIENDLY = {
  'Failed to fetch': 'İnternet bağlantısı kesildi.',
  'NetworkError': 'Sunucuya ulaşılamıyor.',
  'timeout': 'İşlem zaman aşımına uğradı.',
  'duplicate key': 'Bu kayıt zaten mevcut.',
  'PGRST': 'Veritabanı işlemi başarısız oldu.',
  // D18: erteleme kuralları — RAISE kodları msg.includes ile eşleşir
  'GOREV_ERTELENEMEZ': 'Bu görev ertelenemez (protokol/zincir kuralı).',
  'GECMIS_TARIH': 'Geçmiş tarihe erteleme yapılamaz.',
};

// PG_KAPI:<KOD>:<json> ayrıştırıcı (PLAN P1). JSON bozuksa bile KOD gösterilir —
// fail-loud; tanınmayan kod jeneriğe düşmez, KOD kendisi gösterilir.
function pgKapiMesaj(msg) {
  const m = /^(PG_KAPI:[A-Z_]+):(.*)$/s.exec(msg);
  if (!m) return null;
  const kodTam = m[1];
  let detay = {};
  try { detay = JSON.parse(m[2]); } catch (e) { /* detay bozuksa KOD yine gösterilir */ }
  const sozluk = (typeof PG_HATA_SOZLUGU !== 'undefined') ? PG_HATA_SOZLUGU : {};
  const sablon = sozluk[kodTam] || null;
  const doldur = (t) => t
    .replace('{kupe}', detay.kupe_no ?? detay.kupe ?? '')
    .replace('{tarih}', detay.tohumlama_tarihi ?? detay.tarih ?? '')
    .replace('{deneme}', detay.deneme_no ?? '')
    .replace('{gun}', detay.gun ?? '');
  if (sablon) {
    return doldur(sablon)
      .replace(/\(\s*\)/g, '')            // boş parantez kalıntısı
      .replace(/,\s*,/g, ',')             // art arda virgül
      .replace(/,\s*\./g, '.')            // nokta öncesi virgül
      .replace(/\s{2,}/g, ' ')
      .trim();
  }
  // Sözlükte olmayan yeni PG_KAPI kodu: KOD'u görünür kıl (sessiz jenerik YOK)
  return 'İşlem reddedildi: ' + kodTam.replace('PG_KAPI:', '');
}

function getUserMessage(err) {
  const msg = err?.message || String(err);
  // 1) PG_KAPI sözleşmesi (en özel; önce bak)
  const pg = pgKapiMesaj(msg);
  if (pg) return pg;
  // 2) Ovsync/PG yeni hata kodları (config sözlüğünden, tek kaynak)
  if (typeof PG_HATA_SOZLUGU !== 'undefined') {
    for (const [k, v] of Object.entries(PG_HATA_SOZLUGU)) {
      if (msg.includes(k)) return v;
    }
  }
  // 3) Kalıplı çeviriler
  for (const [k, v] of Object.entries(USER_FRIENDLY)) {
    if (msg.includes(k)) return v;
  }
  // 4) Tanınmayan mesaj: jenerik EZME YOK — sunucunun Türkçe 'mesaj'ı zaten
  // anlamlıysa (nokta içeriyor + 15+ karakter) olduğu gibi gösterilir.
  if (msg.length >= 15 && /[a-zçğıöşü]/i.test(msg) && /[.!?]$|[.!?]\s|:/.test(msg)) return msg;
  return 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
}

function withErrorHandling(fn, context) {
  return async (...args) => {
    try { return await fn(...args); }
    catch (err) {
      console.error(`[EgeSüt] ${context || '?'}:`, err);
      toast(getUserMessage(err), true);
      if (debugMode) showDebug(err, context);
      return null;
    }
  };
}

// Modül self-contained olmalı: global esc helpers.js'ten önce yüklenebilir /
// yüklenmeyebilir (script hataları window.onerror'a erken düşer) — test-rapor #4
function _dbgEsc(x) {
  return String(x ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function showDebug(err, context) {
  const panel = g('debugPanel');
  if (!panel) return;
  const entry = document.createElement('div');
  entry.className = 'debug-entry';
  entry.innerHTML = `<strong>${new Date().toLocaleTimeString()}</strong> [${_dbgEsc(context||'?')}] ${_dbgEsc(err?.message || String(err))}`;
  panel.prepend(entry);
  if (panel.children.length > 50) panel.lastChild?.remove();
}

window.addEventListener('error', (e) => {
  console.error('[EgeSüt] Global error:', e.message, e.filename, e.lineno);
  if (debugMode) showDebug(e.error || e, 'window.onerror');
});

window.addEventListener('unhandledrejection', (e) => {
  console.error('[EgeSüt] Unhandled:', e.reason);
  toast('Beklenmeyen bir hata oluştu.', true);
  if (debugMode) showDebug(e.reason, 'unhandledrejection');
});
