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

function showDebug(err, context) {
  const panel = g('debugPanel');
  if (!panel) return;
  const entry = document.createElement('div');
  entry.className = 'debug-entry';
  entry.innerHTML = `<strong>${new Date().toLocaleTimeString()}</strong> [${context||'?'}] ${esc(err.message || String(err))}`;
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
