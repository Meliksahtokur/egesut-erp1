// ══════════════════════════════════════════════════
// EgeSüt — auth.js  (Faz 1: auth gate + şifre/mail UX)
// Oturum yoksa login ekranı gösterir, app init'i bloklar.
// api.js'den SONRA, app.js'den ÖNCE yüklenir (window.db gerekir).
// ══════════════════════════════════════════════════
(function () {
  const db = window.db;
  let mode = 'login'; // 'login' | 'signup'
  let cooldownTimer = null;
  let recovering = false;

  const AUTH_ERR = {
    'Invalid login credentials': 'E-posta veya şifre hatalı',
    'Email not confirmed': 'E-posta henüz doğrulanmadı — gelen kutunu kontrol et',
    'User already registered': 'Bu e-posta zaten kayıtlı',
    'Password should be at least 6 characters': 'Şifre en az 6 karakter olmalı',
    'Unable to validate email address: invalid format': 'Geçersiz e-posta adresi',
    'Signups not allowed for this instance': 'Kayıt şu an kapalı',
    'Email rate limit exceeded': 'Çok fazla mail isteği — biraz bekle',
    'For security purposes, you can only request this after 60 seconds.': 'Güvenlik için 60 saniyede bir deneyebilirsin',
    'New password should be different from the old password.': 'Yeni şifre eskisinden farklı olmalı',
  };
  const authErr = m => AUTH_ERR[String(m || '')] || String(m || 'Bir hata oluştu');

  const redirectUrl = () => window.location.origin + window.location.pathname;

  function msg(text, type) {
    const m = document.getElementById('auth-msg');
    if (!m) return;
    m.textContent = text || '';
    m.style.color = type === 'err' ? '#ff6b5b' : (type === 'ok' ? '#6fcf5b' : '#9aa');
  }

  // Bir butonu `secs` saniye disable edip geri sayım gösterir.
  function startCooldown(btn, secs, label) {
    if (!btn) return;
    let n = secs;
    btn.disabled = true;
    btn.textContent = label + ' (' + n + ')';
    clearInterval(cooldownTimer);
    cooldownTimer = setInterval(() => {
      n--;
      if (n <= 0) { clearInterval(cooldownTimer); btn.disabled = false; btn.textContent = label; }
      else { btn.textContent = label + ' (' + n + ')'; }
    }, 1000);
  }

  function setMode(next) {
    mode = next;
    document.getElementById('auth-tab-login').classList.toggle('on', mode === 'login');
    document.getElementById('auth-tab-signup').classList.toggle('on', mode === 'signup');
    document.getElementById('auth-submit').textContent = mode === 'login' ? 'Giriş Yap' : 'Kayıt Ol';
    const f = document.getElementById('auth-forgot');
    if (f) f.style.display = mode === 'login' ? 'block' : 'none';
    const r = document.getElementById('auth-resend');
    if (r) r.style.display = 'none';
    document.getElementById('auth-pass').setAttribute('autocomplete', mode === 'login' ? 'current-password' : 'new-password');
    msg('');
  }

  async function submit() {
    const email = document.getElementById('auth-email').value.trim();
    const pass = document.getElementById('auth-pass').value;
    const btn = document.getElementById('auth-submit');
    if (!email || !pass) { msg('E-posta ve şifre gerekli', 'err'); return; }
    btn.disabled = true; msg('Lütfen bekleyin…');
    try {
      if (mode === 'login') {
        const { error } = await db.auth.signInWithPassword({ email, password: pass });
        if (error) throw error;
        location.reload();
      } else {
        const { data, error } = await db.auth.signUp({
          email, password: pass,
          options: { emailRedirectTo: redirectUrl() }
        });
        if (error) throw error;
        if (data.session) { location.reload(); }  // confirmation kapalıysa direkt girer
        else {
          msg('Doğrulama maili gönderildi. Gelmezse "Tekrar gönder".', 'ok');
          showResend(email);
        }
      }
    } catch (e) {
      msg(authErr(e.message), 'err');
    } finally {
      btn.disabled = false;
    }
  }

  // Kayıt sonrası "doğrulama mailini tekrar gönder" butonunu göster + ilk 60sn cooldown.
  function showResend(email) {
    const r = document.getElementById('auth-resend');
    if (!r) return;
    r.style.display = 'block';
    r.onclick = async () => {
      msg('Gönderiliyor…');
      try {
        const { error } = await db.auth.resend({ type: 'signup', email, options: { emailRedirectTo: redirectUrl() } });
        if (error) throw error;
        msg('Mail tekrar gönderildi.', 'ok');
        startCooldown(r, 60, 'Tekrar gönder');
      } catch (e) {
        msg(authErr(e.message), 'err');
      }
    };
    startCooldown(r, 60, 'Tekrar gönder'); // mail az önce gitti → ilk tur beklesin
  }

  async function forgotPassword() {
    const email = document.getElementById('auth-email').value.trim();
    if (!email) { msg('Önce e-posta adresini yaz', 'err'); return; }
    const f = document.getElementById('auth-forgot');
    msg('Gönderiliyor…');
    try {
      const { error } = await db.auth.resetPasswordForEmail(email, { redirectTo: redirectUrl() });
      if (error) throw error;
      msg('Şifre sıfırlama maili gönderildi. Linke tıkla.', 'ok');
      startCooldown(f, 60, 'Şifremi unuttum');
    } catch (e) {
      msg(authErr(e.message), 'err');
    }
  }

  function renderAuthScreen() {
    if (document.getElementById('auth-overlay')) return;
    const style = document.createElement('style');
    style.textContent = '.auth-tab{background:transparent;color:#8a978c}.auth-tab.on{background:#2a352b;color:#fff}';
    document.head.appendChild(style);

    const el = document.createElement('div');
    el.id = 'auth-overlay';
    el.style.cssText = 'position:fixed;inset:0;z-index:100000;background:#0f1410;display:flex;align-items:center;justify-content:center;padding:20px';
    el.innerHTML =
      '<div style="width:100%;max-width:340px;background:#1a221b;border:1px solid #2a352b;border-radius:16px;padding:28px 22px;box-shadow:0 8px 40px rgba(0,0,0,.5)">' +
        '<div style="text-align:center;margin-bottom:22px">' +
          '<div style="font-size:1.6rem;font-weight:800;color:#fff"><span style="color:#4e9a2a">Ege</span>Süt</div>' +
          '<div style="font-size:.75rem;color:#8a978c;letter-spacing:.5px">Saha ERP</div>' +
        '</div>' +
        '<div style="display:flex;gap:6px;margin-bottom:18px;background:#0f1410;border-radius:10px;padding:4px">' +
          '<button id="auth-tab-login" type="button" class="auth-tab on" style="flex:1;padding:9px;border:0;border-radius:7px;font-size:.82rem;font-weight:700;cursor:pointer">Giriş</button>' +
          '<button id="auth-tab-signup" type="button" class="auth-tab" style="flex:1;padding:9px;border:0;border-radius:7px;font-size:.82rem;font-weight:700;cursor:pointer">Kayıt Ol</button>' +
        '</div>' +
        '<input id="auth-email" type="email" placeholder="E-posta" autocomplete="email" style="width:100%;box-sizing:border-box;padding:12px;margin-bottom:10px;background:#0f1410;border:1px solid #2a352b;border-radius:9px;color:#fff;font-size:.9rem">' +
        '<input id="auth-pass" type="password" placeholder="Şifre" autocomplete="current-password" style="width:100%;box-sizing:border-box;padding:12px;margin-bottom:14px;background:#0f1410;border:1px solid #2a352b;border-radius:9px;color:#fff;font-size:.9rem">' +
        '<button id="auth-submit" type="button" style="width:100%;padding:13px;background:#4e9a2a;border:0;border-radius:9px;color:#fff;font-size:.95rem;font-weight:800;cursor:pointer">Giriş Yap</button>' +
        '<button id="auth-forgot" type="button" style="display:block;width:100%;margin-top:10px;background:transparent;border:0;color:#8a978c;font-size:.78rem;cursor:pointer;text-decoration:underline">Şifremi unuttum</button>' +
        '<button id="auth-resend" type="button" style="display:none;width:100%;margin-top:8px;background:transparent;border:1px solid #2a352b;border-radius:9px;padding:9px;color:#9aa;font-size:.78rem;cursor:pointer">Tekrar gönder</button>' +
        '<div id="auth-msg" style="margin-top:14px;font-size:.78rem;text-align:center;min-height:18px;line-height:1.4"></div>' +
      '</div>';
    document.body.appendChild(el);

    document.getElementById('auth-tab-login').addEventListener('click', () => setMode('login'));
    document.getElementById('auth-tab-signup').addEventListener('click', () => setMode('signup'));
    document.getElementById('auth-submit').addEventListener('click', submit);
    document.getElementById('auth-forgot').addEventListener('click', forgotPassword);
    document.getElementById('auth-pass').addEventListener('keydown', e => { if (e.key === 'Enter') submit(); });
  }

  // Şifre sıfırlama linkine tıklanınca (PASSWORD_RECOVERY) "yeni şifre belirle" ekranı.
  function renderResetScreen() {
    if (document.getElementById('auth-reset-overlay')) return;
    const el = document.createElement('div');
    el.id = 'auth-reset-overlay';
    el.style.cssText = 'position:fixed;inset:0;z-index:100001;background:#0f1410;display:flex;align-items:center;justify-content:center;padding:20px';
    el.innerHTML =
      '<div style="width:100%;max-width:340px;background:#1a221b;border:1px solid #2a352b;border-radius:16px;padding:28px 22px;box-shadow:0 8px 40px rgba(0,0,0,.5)">' +
        '<div style="text-align:center;font-size:1.05rem;font-weight:800;color:#fff;margin-bottom:6px">Yeni Şifre Belirle</div>' +
        '<div style="text-align:center;font-size:.75rem;color:#8a978c;margin-bottom:18px">Hesabın için yeni bir şifre gir</div>' +
        '<input id="reset-pass" type="password" placeholder="Yeni şifre (en az 6 karakter)" autocomplete="new-password" style="width:100%;box-sizing:border-box;padding:12px;margin-bottom:14px;background:#0f1410;border:1px solid #2a352b;border-radius:9px;color:#fff;font-size:.9rem">' +
        '<button id="reset-submit" type="button" style="width:100%;padding:13px;background:#4e9a2a;border:0;border-radius:9px;color:#fff;font-size:.95rem;font-weight:800;cursor:pointer">Kaydet</button>' +
        '<div id="reset-msg" style="margin-top:14px;font-size:.78rem;text-align:center;min-height:18px;line-height:1.4"></div>' +
      '</div>';
    document.body.appendChild(el);
    document.getElementById('reset-submit').addEventListener('click', submitReset);
    document.getElementById('reset-pass').addEventListener('keydown', e => { if (e.key === 'Enter') submitReset(); });
  }

  async function submitReset() {
    const p = document.getElementById('reset-pass').value;
    const rm = document.getElementById('reset-msg');
    const setMsg = (t, c) => { if (rm) { rm.textContent = t; rm.style.color = c; } };
    if (!p || p.length < 6) { setMsg('Şifre en az 6 karakter olmalı', '#ff6b5b'); return; }
    const btn = document.getElementById('reset-submit');
    btn.disabled = true; setMsg('Kaydediliyor…', '#9aa');
    try {
      const { error } = await db.auth.updateUser({ password: p });
      if (error) throw error;
      setMsg('Şifre güncellendi, giriş yapılıyor…', '#6fcf5b');
      setTimeout(() => location.reload(), 1200);
    } catch (e) {
      setMsg(authErr(e.message), '#ff6b5b');
      btn.disabled = false;
    }
  }

  function mountUserChip(user) {
    if (document.getElementById('auth-chip')) return;
    const host = document.getElementById('top-right');
    if (!host) return;
    const chip = document.createElement('button');
    chip.id = 'auth-chip';
    chip.type = 'button';
    chip.title = (user && user.email) ? user.email : 'Çıkış';
    chip.textContent = '⎋';
    chip.style.cssText = 'background:rgba(192,50,26,.15);border:1px solid #c0321a;color:#e08070;padding:5px 10px;border-radius:20px;font-size:.85rem;cursor:pointer;margin-left:5px';
    chip.addEventListener('click', async () => {
      if (!confirm('Çıkış yapılsın mı?')) return;
      await db.auth.signOut();
      location.reload();
    });
    host.appendChild(chip);
  }

  // app.js load handler bunu EN BAŞTA await eder.
  // Oturum yoksa null döner → app init etmemeli.
  window.authGate = async function () {
    if (recovering) { renderResetScreen(); return null; }
    const { data: { session } } = await db.auth.getSession();
    if (!session) { renderAuthScreen(); return null; }
    mountUserChip(session.user);
    return session;
  };

  // Auth durum değişiklikleri
  db.auth.onAuthStateChange((event) => {
    if (event === 'PASSWORD_RECOVERY') { recovering = true; renderResetScreen(); return; }
    if (event === 'SIGNED_OUT') location.reload();
  });
})();
