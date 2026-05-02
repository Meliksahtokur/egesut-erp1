# Task-dev-008-done.md: UI Telemetry Logger Tamamlandı

**Tarih:** 2026-04-01  
**Branch:** gwen/dev  
**Commit:** `9634cac` (UI telemetry) + `60f78e2` (aktifbuglar.md silindi)

---

## ✅ Yapılanlar

### 1. Migration Oluşturuldu
**Dosya:** `supabase/migrations/20260401000034_ui_telemetry.sql`

```sql
create table public.ui_logs (
  id bigserial primary key,
  level text not null,        -- 'error' | 'warn' | 'action' | 'info'
  message text not null,
  source text,                -- dosya:satır
  payload jsonb,              -- ek veri
  session_id text,            -- test session'ı
  created_at timestamptz default now()
);
```

- RLS aktif: `anon insert` + `anon select`
- Index: `session_id + created_at`

---

### 2. app.js — uiLog Modülü
**Dosya:** `js/app.js` (satır 8-33)

```js
const _sessionId = Math.random().toString(36).slice(2, 9);

async function uiLog(level, message, extra = {}) {
  try {
    await db.from('ui_logs').insert({...});
  } catch (_) {}  // log hatası uygulamayı durdurmasın
}

// Global error handlers
window.onerror = (msg, src, line, col, err) => { uiLog('error', msg, {...}); };
window.addEventListener('unhandledrejection', e => { uiLog('error', e.reason); });
console.error wrapper (orijinal + uiLog)
```

---

### 3. forms.js — 3 Kritik Aksiyon Logları

**a) Tohumlama submit** (satır 162):
```js
uiLog('action', 'tohumlama_submit', { hayvan_id: hayvan.id, tarih });
```

**b) Doğum submit** (satır 120):
```js
uiLog('action', 'dogum_submit', { anne_id: anne.id, tarih, kupe });
```

**c) Hayvan ekle submit** (satır 76):
```js
uiLog('action', 'hayvan_ekle_submit', { kupe_no: kupe || devlet, grup: v('a-grup') });
```

---

### 4. api.js — Realtime Subscription
**Dosya:** `js/api.js` (satır 365, 380)

```js
const REALTIME_TABLES = [..., 'ui_logs'];

// initRealtime() içinde:
.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'ui_logs' },
  payload => console.log('[ui_log]', payload.new))
```

---

### 5. aktifbuglar.md Silindi
**Sebep:** Stale, yanlış bilgi içeriyor. Otorite dosya: `.claude/knowledge/bugs.md`

---

## ✅ Kabul Kriterleri

- [x] Migration oluşturuldu, tablo var
- [x] `window.onerror` + `unhandledrejection` + `console.error` yakalıyor
- [x] 3 kritik aksiyon logu var (tohumlama, doğum, hayvan ekle)
- [x] Realtime'da ui_logs kanalı var
- [x] `node --check js/*.js` PASS
- [x] `uiLog` hata fırlatsa bile uygulama çalışıyor (try/catch)
- [x] Push edildi: `9634cac` + `60f78e2`

---

## 📊 Beklenen Kullanım

### Test Session'ı
```bash
# 1. Tarayıcıda aç
# 2. F12 Console'da [ui_log] mesajlarını izle
# 3. Tohumlama/doğum/hayvan ekle → Realtime log gör
# 4. Hata simüle et → error log gör
```

### Supabase Query
```sql
select session_id, level, message, created_at
from ui_logs
order by created_at desc
limit 50;
```

---

## 🎯 Sonraki Adım

Test feedback loop kuruldu. Gwen artık:
- Test sırasında kullanıcı hareketlerini görebilir
- UI hatalarını realtime izleyebilir
- Session bazlı log analizi yapabilir

---

**Task tamamlandı.** ✅
