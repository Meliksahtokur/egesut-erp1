// ══════════════════════════════════════════════════
// EgeSüt — demo.js  (Demo modu UI: banner + klon butonu + popup + şema-diff)
// Sadece IS_DEMO iken çalışır. api.js/auth.js/ui.js'den SONRA yüklenir.
// Klon motoru: demo_klonla() RPC (demo/02_demo_klonla.sql). Şema-diff: demo_sema_diff() RPC.
// ══════════════════════════════════════════════════
(function () {
  if (!window.IS_DEMO) return;
  const db = window.db;

  // ── Prod'dan klonla (senkronizasyon) ──
  async function klonla(btn) {
    if (!confirm('Demo verisi prod\'un GÜNCEL kopyasıyla değiştirilecek.\nBuradaki demo değişiklikleri SİLİNİR. Devam edilsin mi?')) return;
    const old = btn ? btn.textContent : '';
    if (btn) { btn.disabled = true; btn.textContent = '↻ Senkronize ediliyor…'; }
    try {
      const { data, error } = await db.rpc('demo_klonla');
      if (error) throw error;
      alert('✓ Senkronize edildi: ' + (data.rows || '?') + ' satır · ' + (data.ms || '?') + ' ms.\nSayfa yenileniyor.');
      location.reload();
    } catch (e) {
      alert('Klon hatası: ' + (e.message || e));
      if (btn) { btn.disabled = false; btn.textContent = old; }
    }
  }

  // ── Şema-diff uyarısı (prod'a tablo/kolon eklendi mi?) ──
  async function semaDiffKontrol(bar) {
    try {
      const { data, error } = await db.rpc('demo_sema_diff');
      if (error || !data) return;
      const et = (data.eksik_tablo || []), ek = (data.eksik_kolon || []);
      if (!et.length && !ek.length) return;
      const w = document.createElement('div');
      w.style.cssText = 'background:#7a3a00;color:#fff;padding:5px 12px;font-size:.66rem;font-weight:700';
      w.textContent = '⚠️ Şema drift: prod\'a ' + et.length + ' tablo / ' + ek.length +
        ' kolon eklenmiş, demo eskimiş. Migration\'ı demo\'ya uygula + FDW yenile.';
      bar.insertAdjacentElement('afterend', w);
    } catch (_) {}
  }

  // ── Demo bandı (topbar altına) ──
  function injectBar() {
    const topbar = document.getElementById('topbar');
    if (!topbar || document.getElementById('demo-bar')) return;
    const bar = document.createElement('div');
    bar.id = 'demo-bar';
    bar.style.cssText = 'background:#b07a2a;color:#1a130a;padding:6px 12px;display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:.72rem;font-weight:800;flex-shrink:0';
    bar.innerHTML =
      '<span>🧪 DEMO — yazdıkların geçici</span>' +
      '<span style="display:flex;gap:6px">' +
        '<button id="demo-klonla" style="background:#1a130a;color:#e0a94a;border:0;border-radius:14px;padding:5px 11px;font-size:.72rem;font-weight:800;cursor:pointer">↻ Prod\'dan Klonla</button>' +
        '<button id="demo-cikis" style="background:rgba(0,0,0,.18);color:#1a130a;border:0;border-radius:14px;padding:5px 11px;font-size:.72rem;font-weight:700;cursor:pointer">Çıkış</button>' +
      '</span>';
    topbar.insertAdjacentElement('afterend', bar);
    document.getElementById('demo-klonla').addEventListener('click', e => klonla(e.currentTarget));
    document.getElementById('demo-cikis').addEventListener('click', () => window.authLogout && window.authLogout());
    // AI asistanını gizle — edge fonksiyonu demo projesinde yok
    const ab = document.getElementById('asistanbtn'); if (ab) ab.style.display = 'none';
    semaDiffKontrol(bar);
  }

  // ── Girişten sonra hatırlatma popup'ı ("bir daha gösterme") ──
  function showPopup() {
    if (localStorage.getItem('EGESUT_DEMO_POPUP_OFF') === '1') return;
    if (document.getElementById('demo-popup')) return;
    const el = document.createElement('div');
    el.id = 'demo-popup';
    el.style.cssText = 'position:fixed;inset:0;z-index:100002;background:rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;padding:20px';
    el.innerHTML =
      '<div style="width:100%;max-width:330px;background:#1a221b;border:1px solid #b07a2a;border-radius:16px;padding:24px 20px;box-shadow:0 8px 40px rgba(0,0,0,.6)">' +
        '<div style="font-size:1.05rem;font-weight:800;color:#e0a94a;text-align:center;margin-bottom:10px">🧪 Demo Hesabı</div>' +
        '<div style="font-size:.82rem;color:#cdd;line-height:1.5;text-align:center">İşlem yapmadan önce üstteki <b style="color:#e0a94a">↻ Prod\'dan Klonla</b> butonuna basarak verileri güncelle. Demo\'da yazdıkların kalıcı değildir; her klon üzerine yazar.</div>' +
        '<label style="display:flex;align-items:center;gap:8px;margin-top:16px;font-size:.75rem;color:#9aa;cursor:pointer;justify-content:center">' +
          '<input id="demo-popup-off" type="checkbox" style="width:16px;height:16px"> Bir daha gösterme</label>' +
        '<button id="demo-popup-ok" style="width:100%;margin-top:16px;padding:12px;background:#b07a2a;border:0;border-radius:9px;color:#1a130a;font-size:.9rem;font-weight:800;cursor:pointer">Anladım</button>' +
      '</div>';
    document.body.appendChild(el);
    document.getElementById('demo-popup-ok').addEventListener('click', () => {
      if (document.getElementById('demo-popup-off').checked) localStorage.setItem('EGESUT_DEMO_POPUP_OFF', '1');
      el.remove();
    });
  }

  function init() { injectBar(); showPopup(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
