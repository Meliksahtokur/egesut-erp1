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
};

function getUserMessage(err) {
  const msg = err?.message || String(err);
  for (const [k, v] of Object.entries(USER_FRIENDLY)) {
    if (msg.includes(k)) return v;
  }
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
