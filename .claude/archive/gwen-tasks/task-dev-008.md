# Task-dev-008: UI Telemetry Logger

**Durum:** bekliyor
**Branch:** gwen/dev
**Session:** dev

---

## Açıklama

Test sırasında kullanıcı hareketleri ve UI hataları Supabase'e loglanacak. Gwen realtime ile okuyacak — test feedback loop'u kurulacak.

---

## 1. Migration

`supabase/migrations/` altına yeni migration:

```sql
create table if not exists public.ui_logs (
  id bigserial primary key,
  level text not null,        -- 'error' | 'warn' | 'action' | 'info'
  message text not null,
  source text,                -- dosya:satır (hata için)
  payload jsonb,              -- ek veri (form değerleri, tıklanan element vb.)
  session_id text,            -- test session'ı ayırt etmek için
  created_at timestamptz default now()
);

alter table public.ui_logs enable row level security;
create policy "anon insert" on public.ui_logs for insert to anon with check (true);
create policy "anon select" on public.ui_logs for select to anon using (true);
```

---

## 2. app.js — Logger modülü

`js/app.js` içine, init fonksiyonunun üstüne ekle:

```js
// ── UI TELEMETRY ─────────────────────────────
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

// Global hata yakalayıcılar
window.onerror = (msg, src, line, col, err) => {
  uiLog('error', msg, { source: `${src}:${line}`, stack: err?.stack });
};
window.addEventListener('unhandledrejection', e => {
  uiLog('error', e.reason?.message || String(e.reason), { type: 'unhandled_rejection' });
});
const _origConsoleError = console.error.bind(console);
console.error = (...args) => {
  uiLog('error', args.join(' '));
  _origConsoleError(...args);
};
```

---

## 3. Kritik aksiyon logları

`js/forms.js` içinde form submit handler'larına ekle — sadece kritik 3 aksiyon:

**Tohumlama submit:**
```js
uiLog('action', 'tohumlama_submit', { hayvan_id, tarih });
```

**Doğum submit:**
```js
uiLog('action', 'dogum_submit', { anne_id, tarih });
```

**Hayvan ekle submit:**
```js
uiLog('action', 'hayvan_ekle_submit', { kupe_no, grup });
```

---

## 4. api.js — Realtime'a ui_logs ekle

`REALTIME_TABLES` dizisine `'ui_logs'` ekle.

`initRealtime()` içine:
```js
.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'ui_logs' },
  payload => console.log('[ui_log]', payload.new))
```

---

## Kabul Kriterleri

- [ ] Migration oluşturuldu, tablo var
- [ ] `window.onerror` + `unhandledrejection` + `console.error` yakalıyor
- [ ] 3 kritik aksiyon logu var (tohumlama, doğum, hayvan ekle)
- [ ] Realtime'da ui_logs kanalı var
- [ ] `node --check js/*.js` PASS
- [ ] `uiLog` hata fırlatsa bile uygulama çalışmaya devam ediyor (try/catch)

---

## Notlar

- `uiLog` async ama `await` bekleme — fire and forget, UI'ı bloke etme
- Sadece test için değil, production'da da çalışacak (sessiz, hafif)
- Tamamlanınca `task-dev-008-done.md` yaz
