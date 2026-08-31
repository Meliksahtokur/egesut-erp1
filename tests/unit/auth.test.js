// tests/unit/auth.test.js
// js/auth.js — stub'lanabilir kısımların birim testleri (authGate, şifre
// değiştirme, AUTH_ERR eşleme, logout confirm kapısı, demo otomatik giriş).
//
// auth.js bir IIFE'dir; test edilebilir yüzeyi window'a bağladığı 4 fonksiyon:
// authGate / authChangePassword / authLogout / authFillAccount.
// authErr ve redirectUrl closure-özel olduğundan DOĞRUDAN test edilemez;
// AUTH_ERR eşlemesi authChangePassword'ın hata yolu üzerinden dolaylı doğrulanır.
//
// DOM-stub notları:
// - renderAuthScreen/renderResetScreen innerHTML kurar; stub innerHTML'i parse
//   etmediği için gerçek form kurulamaz. Fonksiyonların başındaki
//   `if (document.getElementById('auth-overlay')) return;` early-return'undan
//   yararlanılıyor — overlay id'leri önceden "var" sayılır, ekran kurulumu atlanır.
// - auth.js:263'teki üst-seviye db.auth.onAuthStateChange çağrısı stub'da
//   callback yakalanarak karşılanır.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement, makeStorage } = require('./support/loadModule.js');

function loadAuth({ session = null, signInError = null, updateError = null, confirmVal = false, isDemo = false, demoLogin = null } = {}) {
  const calls = { getSession: 0, signIn: [], update: [], signOut: 0, reload: 0 };
  let authCb = null;
  const db = {
    auth: {
      onAuthStateChange: (cb) => { authCb = cb; return { data: { subscription: { unsubscribe() {} } } }; },
      getSession: async () => { calls.getSession++; return { data: { session } }; },
      signInWithPassword: async (cred) => { calls.signIn.push(cred); return signInError ? { error: signInError } : { error: null }; },
      updateUser: async (p) => { calls.update.push(p); return updateError ? { error: updateError } : { error: null }; },
      signOut: async () => { calls.signOut++; return {}; },
    },
  };
  const doc = makeDomStub();
  doc.__setEl('auth-overlay', makeElement('div'));        // renderAuthScreen early-return
  doc.__setEl('auth-reset-overlay', makeElement('div'));  // renderResetScreen early-return
  const inp = Object.assign(makeElement('input'), { value: '' });
  const msg = makeElement('div');
  const emailEl = makeElement('div');
  doc.__setEl('hesap-yeni-sifre', inp);
  doc.__setEl('hesap-msg', msg);
  doc.__setEl('hesap-email', emailEl);
  const m = loadBrowserModule('js/auth.js', {
    dom: doc,
    extra: {
      db,
      sessionStorage: makeStorage(), // sandbox'ta yok — auth.js demo döngü-guard'ı kullanıyor
      IS_DEMO: isDemo,
      DEMO_LOGIN: demoLogin,
      confirm: () => confirmVal,
      location: {
        href: 'http://localhost/', origin: 'http://localhost', pathname: '/index.html',
        search: '', hash: '', reload() { calls.reload++; },
      },
    },
  });
  return { api: m.window, calls, inp, msg, emailEl, fireAuthEvent: (ev) => authCb && authCb(ev) };
}

// ── modül yüklenmesi + export sözleşmesi ───────────────────────
test('auth.js stub db ile yüklenir, 4 window exportu + onAuthStateChange kaydı', () => {
  const { api } = loadAuth();
  for (const ad of ['authGate', 'authChangePassword', 'authLogout', 'authFillAccount']) {
    assert.strictEqual(typeof api[ad], 'function', `${ad} window exportı eksik`);
  }
});

// ── authGate ───────────────────────────────────────────────────
test('authGate: oturum varsa session nesnesini aynen döner', async () => {
  const session = { user: { email: 'melik@egesut.test' }, access_token: 'tok-1' };
  const { api, calls } = loadAuth({ session });
  const out = await api.authGate();
  assert.strictEqual(out, session); // referans aynılığı — sessionUser'a yazılan değer bu
  assert.strictEqual(calls.getSession, 1);
});

test('authGate: oturum yoksa null döner (login ekranı dalı)', async () => {
  const { api, calls } = loadAuth({ session: null });
  assert.strictEqual(await api.authGate(), null);
  assert.strictEqual(calls.getSession, 1);
  // Demo değil → signIn denenmez
  assert.strictEqual(calls.signIn.length, 0);
});

test('authGate: PASSWORD_RECOVERY sonrası reset dalı — getSession çağrılmadan null', async () => {
  const { api, calls, fireAuthEvent } = loadAuth({ session: { user: { email: 'x@y.z' } } });
  fireAuthEvent('PASSWORD_RECOVERY'); // recovering = true
  assert.strictEqual(await api.authGate(), null);
  assert.strictEqual(calls.getSession, 0); // recovering dalı oturumu hiç sorgulamaz
});

test('authGate: SIGNED_OUT eventı sayfayı yeniden yükler', async () => {
  const { calls, fireAuthEvent } = loadAuth();
  fireAuthEvent('SIGNED_OUT');
  assert.strictEqual(calls.reload, 1);
});

test('authGate: demo otomatik giriş — hatalıysa null döner, reload YOK, bir kez denenir', async () => {
  const { api, calls } = loadAuth({
    session: null, isDemo: true,
    demoLogin: { email: 'demo@test.local', password: 'yanlis' }, // gerçek kimlik DEĞİL
    signInError: { message: 'Invalid login credentials' },
  });
  assert.strictEqual(await api.authGate(), null);
  assert.strictEqual(calls.signIn.length, 1);
  assert.strictEqual(calls.reload, 0);
  // Döngü guard'ı: ikinci çağrıda sessionStorage bayrağı ayarlı → tekrar deneme yok
  assert.strictEqual(await api.authGate(), null);
  assert.strictEqual(calls.signIn.length, 1);
});

test('authGate: demo otomatik giriş başarılıysa reload edilir', async () => {
  const { api, calls } = loadAuth({
    session: null, isDemo: true,
    demoLogin: { email: 'demo@test.local', password: 'dogru' },
  });
  assert.strictEqual(await api.authGate(), null);
  assert.strictEqual(calls.signIn.length, 1);
  assert.strictEqual(calls.reload, 1);
});

// ── authChangePassword ─────────────────────────────────────────
test('authChangePassword: 6 karakterden kısa şifre reddedilir, updateUser çağrılmaz', async () => {
  const { api, calls, inp, msg } = loadAuth();
  inp.value = '12345';
  await api.authChangePassword();
  assert.strictEqual(msg.textContent, 'Şifre en az 6 karakter olmalı');
  assert.strictEqual(msg.style.color, '#ff6b5b');
  assert.strictEqual(calls.update.length, 0);
});

test('authChangePassword: geçerli şifre updateUser({password}) ile kaydedilir, input temizlenir', async () => {
  const { api, calls, inp, msg } = loadAuth();
  inp.value = 'uzunparola';
  await api.authChangePassword();
  assert.strictEqual(calls.update.length, 1);
  // Not: parametre vm realm'ında yaratıldığı için deepStrictEqual prototype
  // çakışması atar — alan bazlı doğrulama yapılır.
  assert.strictEqual(calls.update[0].password, 'uzunparola');
  assert.deepStrictEqual(Object.keys(calls.update[0]), ['password']);
  assert.strictEqual(msg.textContent, 'Şifre güncellendi ✓');
  assert.strictEqual(msg.style.color, '#4e9a2a');
  assert.strictEqual(inp.value, '');
});

test('AUTH_ERR eşleme: bilinen supabase mesajları Türkçe karşılığa çevrilir', async () => {
  const durumlar = [
    ['Invalid login credentials', 'E-posta veya şifre hatalı'],
    ['Email not confirmed', 'E-posta henüz doğrulanmadı — gelen kutunu kontrol et'],
    ['Password should be at least 6 characters', 'Şifre en az 6 karakter olmalı'],
  ];
  for (const [supabaseMsg, tr] of durumlar) {
    const { api, inp, msg } = loadAuth({ updateError: { message: supabaseMsg } });
    inp.value = 'uzunparola';
    await api.authChangePassword();
    assert.strictEqual(msg.textContent, tr, `${supabaseMsg} → ${tr} olmalı`);
    assert.strictEqual(msg.style.color, '#ff6b5b');
  }
});

test('AUTH_ERR eşleme: bilinmeyen mesaj aynen, boş mesaj "Bir hata oluştu"', async () => {
  {
    const { api, inp, msg } = loadAuth({ updateError: { message: 'Tuhaf bir hata' } });
    inp.value = 'uzunparola';
    await api.authChangePassword();
    assert.strictEqual(msg.textContent, 'Tuhaf bir hata'); // eşleşme yoksa ham mesaj
  }
  {
    const { api, inp, msg } = loadAuth({ updateError: {} }); // message alanı yok
    inp.value = 'uzunparola';
    await api.authChangePassword();
    assert.strictEqual(msg.textContent, 'Bir hata oluştu');
  }
});

// ── authFillAccount ────────────────────────────────────────────
test('authFillAccount: oturum yoksa "—", oturum varsa e-posta yazılır', async () => {
  {
    const { api, emailEl } = loadAuth({ session: null });
    api.authFillAccount(); // authGate çağrılmadan — sessionUser null
    assert.strictEqual(emailEl.textContent, '—');
  }
  {
    const { api, emailEl, inp, msg } = loadAuth({ session: { user: { email: 'melik@egesut.test' } } });
    await api.authGate(); // sessionUser doldurur
    inp.value = 'eski-deger';
    msg.textContent = 'eski mesaj';
    api.authFillAccount();
    assert.strictEqual(emailEl.textContent, 'melik@egesut.test');
    assert.strictEqual(inp.value, '');           // şifre alanı temizlenir
    assert.strictEqual(msg.textContent, '');     // mesaj temizlenir
  }
});

// ── authLogout ─────────────────────────────────────────────────
test('authLogout: confirm reddedilirse signOut/reload çağrılmaz', async () => {
  const { api, calls } = loadAuth({ confirmVal: false });
  await api.authLogout();
  assert.strictEqual(calls.signOut, 0);
  assert.strictEqual(calls.reload, 0);
});

test('authLogout: confirm onaylanırsa signOut + reload çalışır', async () => {
  const { api, calls } = loadAuth({ confirmVal: true });
  await api.authLogout();
  assert.strictEqual(calls.signOut, 1);
  assert.strictEqual(calls.reload, 1);
});
