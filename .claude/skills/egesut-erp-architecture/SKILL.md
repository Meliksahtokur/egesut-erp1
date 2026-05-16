---
name: egesut-erp-architecture
description: EgeSüt ERP mimari felsefesi — frontend asla iş mantığı yapmaz, tüm iş backend'de (PostgreSQL RPC/trigger/view). Bu skill her oturumda yüklenir, mimari ihlalleri önler.
---

# EgeSüt ERP — Mimari Felsefe

> **Frontend asla iş mantığı yapmaz.** Sadece veri toplar ve görüntüler.
> Tüm iş mantığı, validasyon, hesaplama, state machine'ler PostgreSQL'de.
> Frontend ERP sistemlerinde **güvenilmezdir** — tarayıcıdaki JS kullanıcı tarafından değiştirilebilir.

## Neden Frontend Güvenilmez

| Sorun | Etki |
|-------|------|
| DevTools ile JS override edilebilir | İş mantığı bypass edilir |
| İki cihazda farklı versiyon | Tutarsız state → veri kaybı |
| Offline çalışırken güncel olmayabilir | Eski veriyle karar verilir |
| Race condition | Çift kayıt, yanlış state geçişi |

PostgreSQL'de bu sorunlar yoktur: ACID, RLS, trigger, CHECK constraint.

## Katman Sorumlulukları

```
┌─────────────────────────────────────────────┐
│  UI Layer (index.html + js/*.js)            │
│  • Form input toplama                       │
│  • Veri görüntüleme (render)                │
│  • Kullanıcı etkileşimi → RPC çağrısı      │
│  ✗ Hesap yapmaz                             │
│  ✗ State machine işletmez                  │
│  ✗ Validasyon yapmaz (sadece UX guard)     │
└──────────────────────┬──────────────────────┘
                       │ RPC
┌──────────────────────▼──────────────────────┐
│  DB Layer (PostgreSQL / Supabase)           │
│  • Tüm iş mantığı                           │
│  • Validasyon (CHECK, trigger)              │
│  • Hesaplama (view, RPC)                    │
│  • State machine (trigger, RPC)             │
│  • Yetkilendirme (RLS)                      │
│  • Ledger (immutable)                       │
└─────────────────────────────────────────────┘
```

## Operasyonel Kurallar

### Kural 1 — Sadece RPC ile yaz

Tüm yazma işlemleri Supabase RPC üzerinden geçer.

```sql
-- YANLIŞ ❌ — frontend direkt REST kullanıyor
await db.from('hayvanlar').update({...}).eq('id', id);

-- YANLIŞ ❌ — write() da REST kullanır (offline queue geçici çözüm)
await write('hayvanlar', {...}, 'PATCH', `id=eq.${id}`);

-- DOĞRU ✅ — backend RPC
await rpc('hayvan_guncelle', { p_id: id, p_grup: '...' });
```

Ancak **admin/yönetim işlemleri** (padok/hekim/vaccine CRUD) için RPC yoksa `db.from()` kullanılabilir — ama bu işlemlerin de RPC'ye taşınması gerekir.

### Kural 2 — Hesap backend'de

DB'de hesaplanan her şey frontend'de tekrar hesaplanmaz.

```js
// YANLIŞ ❌ — frontend stok hesabı yapıyor
const used=moves.filter(m=>m.stok_id===s.id).reduce((a,m)=>a+(+m.miktar||0),0);
const guncel=(+s.baslangic_miktar||0)-used;

// DOĞRU ✅ — view'dan hazır al
const { data } = await db.from('stok_tuketim_view').select('*');
// guncel_stok, stok_durum zaten hesaplanmış gelir
```

### Kural 3 — State machine backend'de

State geçişleri (bekliyor→gebe/boş/abort, gebe→doğum) trigger veya RPC ile yönetilir.

```sql
-- RPC içinde state geçişi
UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id = p_tohumlama_id;
UPDATE public.hayvanlar SET tohumlama_durumu = 'gebe' WHERE id = v_hayvan_id;
```

Frontend asla `write('hayvanlar', { tohumlama_durumu: 'gebe' }, 'PATCH')` yapmaz.

### Kural 4 — View'lar hazır veri döndürür

| View | Kullanım | Hesapladığı |
|------|----------|-------------|
| `hayvan_durum_view` | Hayvan kartı, sürü listesi | yaş, toh_gun, toh_sonuc, stok_durum |
| `stok_tuketim_view` | Stok listesi | guncel_stok, stok_durum (kritik/normal) |
| `tohumlanabilir_hayvanlar` | Tohumlama dropdown | toh durumu hesaplanmış hayvanlar |

Frontend bu view'lardan gelen hazır alanları kullanır, tekrar `baslangic_miktar - SUM(miktar)` yapmaz.

## Bilinen İhlaller (Refactor Gerekir)

Tespit: 2026-05-16 — Bu ihlaller felsefeye aykırıdır, yavaş yavaş RPC/view'lara taşınmalıdır.

### Grup A — RPC Bypass (`write()` ile direkt PATCH)

| Dosya | Satır | İşlem | Yapılması Gereken |
|-------|-------|-------|-------------------|
| `forms.js` | 429, 447 | Sütten kesme tarihi güncelleme | `hayvan_guncelle` RPC'sine taşı |
| `forms.js` | 462 | Tohumlanabilir onay | Yeni RPC veya `hayvan_guncelle` genişlet |
| `forms.js` | 476 | Tohumlama erteleme (+ tarih hesabı frontend'de) | Yeni RPC (`tohumlama_ertele`) |
| `forms.js` | 626-631 | Görev tamamlama (gorev_log + stok + padok) | `gorev_guncelle` RPC'si zaten var, ona taşı |
| `forms.js` | 941, 975-981 | Stok güncelleme / ekleme | `stok_guncelle` RPC'si yok, yazılmalı |
| `forms.js` | 1031 | Tohumlama direkt INSERT (offline queue üzerinden) | `tohumlama_kaydet` zaten var, offline queue RPC_MAP'i düzelt |

### Grup B — Direkt REST (`db.from(...).insert/update/delete`)

| Dosya | Satır | İşlem |
|-------|-------|-------|
| `ui.js` | 1781, 1797 | Stok güncelleme / arşivleme |
| `ui.js` | 3669 | Vaccine güncelleme |
| `ui.js` | 3686, 3800 | Hekim ekleme / güncelleme |
| `ui.js` | 3830 | Stok direkt insert |
| `ui.js` | 3892, 3909-3910, 4079-4093 | Padok CRUD (tamamen REST) |

### Grup C — Frontend Hesaplama

| Dosya | Satır | Hesaplama | DB'deki Karşılığı |
|-------|-------|-----------|-------------------|
| `ui.js` | 220, 1537, 2019, 2361, 3087, 3158 | `baslangic_miktar - SUM(miktar)` (6 kopya!) | `stok_tuketim_view.guncel_stok` |
| `forms.js` | 474 | `dFwd(... ay * 30)` — erteleme tarihi | RPC'de hesaplanmalı |
| `ui.js` | 2000, 2004 | Gebelik/boş oranı yüzdesi | View veya RPC |

## Acil Durum — Yeni Özellik Eklerken

1. **Önce DB'de RPC/trigger/view var mı kontrol et** — yoksa yaz, sonra frontend'i bağla
2. **`write()` kullanma** — `rpc()` kullan
3. **View varsa frontend'de hesaplama yapma** — view'dan gelen hazır alanı kullan
4. **State machine'i frontend'de işletme** — backend RPC/trigger yapsın
5. **Tarih/yaş/gün hesabını frontend'de yapma** — DB `CURRENT_DATE - dogum_tarihi` yapar

## Okuma Alışkanlığı

```js
// DOĞRU — view'dan hazır veri
getData('stok_tuketim_view').then(rows => render(rows));
// rows[0].guncel_stok, rows[0].stok_durum hazır

// DOĞRU — RPC'den dönen hazır sonuç
const { data } = await rpc('hayvan_guncelle', { ... });
// data.ok, data.mesaj zaten backend'de hesaplanmış

// YANLIŞ — aynı veriyi frontend'de tekrar hesaplama
const used = moves.reduce(...); // ❌
const guncel = baslangic - used;  // ❌
```
