# EgeSüt ERP — Mimari İhlal Raporu

> **Tarih:** 2026-05-16
> **Kapsam:** "Frontend asla iş mantığı yapmaz" prensibine aykırı kodlar
> **Kaynaks:** `egesut-erp-architecture` skill'inden otomatik türetilmiştir

## Özet

| Kategori | İhlal Sayısı | Risk |
|----------|-------------|------|
| Grup A — RPC Bypass (`write()` ile direkt PATCH) | 6+ lokasyon | 🔴 Yüksek |
| Grup B — Direkt REST (`db.from().insert/update/delete`) | 10+ lokasyon | 🔴 Yüksek |
| Grup C — Frontend hesaplama (DB view'ı bypass) | 8+ lokasyon | 🟡 Orta |

---

## Grup A — RPC Bypass

Frontend `write()` fonksiyonunu kullanarak REST PATCH yapıyor.
`write()` offline queue'ya yazıp REST'e gönderir, RPC'yi bypass eder.
Online'ken bu işlemler RPC'siz çalışır → state machine bypass, validasyon atlanır.

### A1 — Sütten Kesme Tarihi

**Dosya:** `js/forms.js:429, 447`
**Kod:**
```js
await write('hayvanlar', { suttten_kesme_tarihi: bugun }, 'PATCH', `id=eq.${id}`);
```
**Sorun:** `hayvan_guncelle` RPC'si var ama kullanılmıyor. Sütten kesme tarihi iş mantığıdır (laktasyon süresi, buzağı yaşı validasyonu DB'de yapılmalı).
**Yapılması Gereken:** `hayvan_guncelle` RPC'sine `p_suttten_kesme_tarihi` parametresi ekle, frontend'den `rpc('hayvan_guncelle', {...})` çağır.

### A2 — Tohumlanabilir Onay

**Dosya:** `js/forms.js:462`
**Kod:**
```js
await write('hayvanlar', { tohumlama_durumu: 'tohumlanabilir', tohumlama_onay_tarihi: new Date().toISOString().split('T')[0] }, 'PATCH', `id=eq.${hayvanId}`);
```
**Sorun:** Tohumlama state machine'i frontend'den direkt PATCH ile değiştiriliyor. Tarih de frontend'de hesaplanıyor.
**Yapılması Gereken:** `hayvan_guncelle` RPC'sine taşı veya ayrı RPC yaz (`tohumlama_onay`).

### A3 — Tohumlama Erteleme

**Dosya:** `js/forms.js:476`
**Kod:**
```js
const erteleme = dFwd(new Date().toISOString().split('T')[0], ay * 30);
await write('hayvanlar', { tohumlama_durumu: 'ertelendi', tohumlama_onay_tarihi: erteleme }, 'PATCH', `id=eq.${hayvanId}`);
```
**Sorun:** Erteleme tarihi frontend'de `dFwd()` ile hesaplanıyor (business logic). `ay * 30` gün hesabı da frontend'de. State machine bypass.
**Yapılması Gereken:** Yeni RPC (`tohumlama_ertele`) — parametre olarak `p_ay` alır, tarihi DB'de hesaplar.

### A4 — Görev Tamamlama

**Dosya:** `js/forms.js:626-631`
**Kod:**
```js
await write('gorev_log', { id, tamamlandi: true, tamamlanma_tarihi: new Date().toISOString() }, 'PATCH', `id=eq.${id}`);
await write('stok_hareket', { id: crypto.randomUUID(), stok_id: stokId, tur: 'Görev', miktar, notlar: 'GorevID:' + id, iptal: false });
await write('hayvanlar', { id: hid, padok }, 'PATCH', `id=eq.${hid}`);
```
**Sorun:** 3 farklı tabloya aynı anda direkt yazılıyor (gorev_log + stok_hareket + hayvanlar). Transaction yok. `gorev_guncelle` RPC'si zaten var ama kullanılmıyor.
**Yapılması Gereken:** `gorev_guncelle` RPC'sini kullan. RPC içinde tüm yan etkileri (stok düşümü, padok değişimi) yönet.

### A5 — Stok Ekleme/Güncelleme

**Dosya:** `js/forms.js:941, 975-981`
**Sorun:** Stok miktarı doğrudan güncelleniyor. Oysa stok ledger immutable'dır — `stok_hareket` INSERT ile çalışır, `stok.baslangic_miktar` asla değişmez (ARCHITECTURE.md §3.3).
**Yapılması Gereken:** Stok işlemleri için RPC yaz (`stok_guncelle`). Miktar değişikliği `stok_hareket` INSERT + view üzerinden hesaplanmalı.

### A6 — Tohumlama Direkt INSERT

**Dosya:** `js/forms.js:1031`
**Kod:**
```js
await write('tohumlama', { ... });
```
**Sorun:** `tohumlama_kaydet` RPC'si zaten var offline queue RPC_MAP'inde tanımlı. Ancak online'da `write()` direkt REST INSERT yapar → RPC bypass edilir.
**Yapılması Gereken:** RPC_MAP'i çevrimiçi durumda da kullanacak şekilde düzelt, veya frontend'de `rpc('tohumlama_kaydet', {...})` çağır.

---

## Grup B — Direkt REST (`db.from()`)

Frontend doğrudan Supabase REST API'ye yazıyor. Bunların çoğu admin/yönetim arayüzü işlemleri.

### B1 — Stok İşlemleri

| Satır | İşlem |
|-------|-------|
| `ui.js:1781` | `db.from('stok').update(...)` — stok güncelleme |
| `ui.js:1797` | `db.from('stok').update({kategori:'Arsiv'})` — stok arşivleme |
| `ui.js:3830` | `db.from('stok').insert(...)` — yeni stok ekleme |

### B2 — Admin CRUD (RPC'siz)

| Satır | İşlem |
|-------|-------|
| `ui.js:3669` | `db.from('vaccines').update(...)` — aşı güncelleme |
| `ui.js:3686` | `db.from('hekimler').insert(...)` — hekim ekleme |
| `ui.js:3800` | `db.from('hekimler').update(...)` — hekim güncelleme |
| `ui.js:3892` | `db.from('padoklar').update(...)` — padok güncelleme |
| `ui.js:3909-3910` | `db.from('grup_padok_eslem').delete()` + `db.from('padoklar').delete()` — padok silme |
| `ui.js:4079-4093` | `db.from('grup_padok_eslem').insert/delete` + `db.from('padoklar').insert` — padok CRUD |

**Not:** Admin CRUD işlemleri kullanıcı sayısı az olduğu için şimdilik tolere edilebilir. Ancak yine de RPC'ye taşınmalıdır (RLS bypass riski, audit eksikliği).

---

## Grup C — Frontend Hesaplama

DB'de view/RPC ile yapılan hesaplamalar frontend'de tekrar ediliyor.

### C1 — Stok Net Hesaplama (6 Kopya!)

Aynı mantık 6 farklı yerde tekrarlanmış:

```
ui.js:220    — dashboard stok özeti
ui.js:1537   — stok listesi render
ui.js:2019   — dashboard istatistik
ui.js:2361   — stok detay sayfası
ui.js:3087   — stok kartı
ui.js:3158   — stok seçici
```

**Kod:**
```js
const used = moves.filter(m => m.stok_id === s.id).reduce((a, m) => a + (+m.miktar || 0), 0);
const guncel = (+s.baslangic_miktar || 0) - used;
```

**Çözüm:** `stok_tuketim_view` DB'de zaten var. `guncel_stok` ve `stok_durum` alanlarını hesaplar:
```sql
SELECT s.baslangic_miktar - COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) AS guncel_stok,
  CASE ... END AS stok_durum
FROM stok s LEFT JOIN stok_hareket sh ON sh.stok_id = s.id;
```

Frontend sadece `getData('stok_tuketim_view')` yapıp `row.guncel_stok`'u göstermeli.

### C2 — Tarih Hesaplamaları

| Satır | Hesaplama | Risk |
|-------|-----------|------|
| `forms.js:474` | `dFwd(... ay * 30)` — erteleme tarihi | State machine parçası, DB'de yapılmalı |
| `forms.js:886` | `Math.floor((Date.now()-new Date(t.tarih))/86400000)` — gün farkı | Render amaçlı tolere edilebilir ama view'dan gelse daha iyi |
| `ui.js:2000,2004` | `Math.round(gebe.length/aktif.length*100)` — yüzde | Raporlama, view veya RPC olabilir |

### C3 — Dashboard İstatistikleri

`ui.js:2000-2042` tüm dashboard istatistikleri (gebe/boş oranı, kritik stok sayısı) 
frontend'de hesaplanıyor. DB view'ı (`dashboard_stats` gibi) yazılıp tek kaynaktan 
çekilebilir.

---

## Remediation Plan

### Aşama 1 — Kritik (Grup A)

| # | İhlal | İş | Tahmini |
|---|-------|-----|---------|
| 1 | A1 Sütten kesme | `hayvan_guncelle` RPC'sine parametre ekle | 1 saat |
| 2 | A2 Tohumlanabilir onay | `hayvan_guncelle` RPC'sine taşı | 1 saat |
| 3 | A3 Tohumlama erteleme | Yeni RPC `tohumlama_ertele` | 2 saat |
| 4 | A4 Görev tamamlama | `gorev_guncelle` RPC'sine taşı | 2 saat |
| 5 | A6 Tohumlama direkt INSERT | RPC_MAP online düzelt | 30 dk |

### Aşama 2 — Stok (Grup B1 + C1)

| # | İş | Tahmini |
|---|-----|---------|
| 6 | `stok_guncelle` RPC'si yaz | 2 saat |
| 7 | Frontend stok hesaplamalarını `stok_tuketim_view` ile değiştir | 3 saat |

### Aşama 3 — Admin CRUD (Grup B2)

| # | İş | Tahmini |
|---|-----|---------|
| 8 | hekim/padok/vaccine RPC'leri yaz | 4 saat |
| 9 | Frontend `db.from()` çağrılarını RPC'ye çevir | 2 saat |

---

## Ek: Felsefe Kısa Referansı

```
Frontend yapar →                         Backend yapar →
─────────────────                         ─────────────────
Form toplama (input)                      Validasyon (CHECK, trigger)
Veri gösterme (render)                    İş mantığı (RPC)
RPC çağırma                               State machine (trigger)
Kullanıcı bildirimi (toast)               Hesaplama (view, RPC)
UX guard (boş alan uyarısı)               Yetkilendirme (RLS)
```

```js
// DOĞRU
const { data } = await rpc('tohumlama_kaydet', { p_hayvan_id, p_tarih, p_sperma });

// YANLIŞ
await write('tohumlama', { hayvan_id, tarih, sperma });
await db.from('tohumlama').insert({ hayvan_id, tarih, sperma });
```
