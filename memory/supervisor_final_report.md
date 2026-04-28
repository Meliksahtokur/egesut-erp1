# egesut-erp1 — Final Analiz Raporu

**Supervisor:** Claude  
**Tarih:** 2026-04-17  
**Proje Durumu:** Aktif geliştirme (fix/tech-debt branch)  
**Analiz Kapsamı:** Python + JavaScript + Supabase, ~10,693 LOC

---

## Özet

EgeSüt ERP, **hayvancılık işletmesi yönetimi** için geliştirilmiş single-page uygulamadır. Supabase (PostgreSQL) backend, vanilla JavaScript frontend, ve Python automation script'leri içerir. Proje olgun bir mimariye sahip ancak **teknik borç birikimi** ve **dokümantasyon eksikliği** kritik seviyeye ulaşmıştır.

| Metrik | Değer |
|--------|-------|
| Toplam Satır | ~10,693 |
| JavaScript Dosyaları | 6 dosya, 5,587 LOC |
| Migration Sayısı | 42 |
| Test Kapsamı | Playwright E2E, 44 test |
| Bilinen Bug | 4 (SPEC.md'de listeli) |
| Teknik Borç | Yüksek |

---

## 🔴 KRITIK BULGULAR

### K-1: `CREATE OR REPLACE` Migration Anti-Pattern

**Severity:** Kritik — Veri kaybı riski  
**Dosyalar:** `supabase/migrations/*.sql` (32/42 dosya)

```sql
-- ❌ YANLIŞ — 42P13 hatası verir
CREATE OR REPLACE FUNCTION public.func_adi(...) ...
```

Her fonksiyonda birden fazla overload olabilir. `CREATE OR REPLACE` sadece son imzayı korur, diğerleri orphaned kalır. Mevcut kod 32 migration'da bu anti-pattern'i kullanıyor.

**Etki:** DB fonksiyon imzaları drift ediyor, bazı RPC çağrıları başarısız olabilir.  
**Zorunlu Çözüm:** `DROP FUNCTION IF EXISTS` → `CREATE FUNCTION` döngüsü kullanılmalı.

---

### K-2: Orphaned JavaScript Fonksiyonları

**Severity:** Kritik — Runtime hatalar  
**Dosyalar:** `js/ui.js`, `js/forms.js`

| Sorun | Durum |
|-------|-------|
| `loadDiseasesDropdown` çift tanımlı | ⚠️ SPEC'de var |
| `_loadCaseDrugsCache` / `_caseDrugsCache` tanımsız | ⚠️ SPEC'de var |
| `openCaseDet` çift tanım (~satır 1242 vs 1855) | ⚠️ SPEC'de var |
| `selDis` fonksiyonu bulunamıyor | ⚠️ DEBUG yorumu var |

`openCaseDet` fonksiyonu şu anda tek tanımlı (son tanım kazanır), ancak SPEC'de "CLN-FIX-1" olarak işaretli eski bir çift tanım riski mevcut.

**Etki:** Belirli UI akışlarında `ReferenceError` oluşabilir.  
**Zorunlu Çözüm:** SPEC.md'deki CLN-FIX serisi uygulanmalı.

---

### K-3: Stok Yönetimi Race Condition Riski

**Severity:** Kritik — Veri tutarlılığı  
**Alan:** `drug_administrations` trigger → `stok_hareket`

Kural: "Stok düşümü SADECE `drug_administrations` INSERT trigger'ından gerçekleşir" dediniz, ancak:

1. İlaç ekleme/silme işlemleri farklı transaction'larda çalışıyor
2. Offline-first senkronizasyonunda aynı ilaç iki kez silinebilir
3. Optimistic UI güncellemesi DB ile çelişebilir

**Etki:** Stok hareketleri çift kayıt veya negatif stok değeri oluşabilir.  
**Zorunlu Çözüm:** Idempotent stok_hareket ekleme veya unique constraint kontrolü.

---

## 🟡 ÖNEMLİ BULGULAR

### O-1: Console.log/console.warn Serbest Kullanım

**Severity:** Orta — Performans ve güvenlik  
**Dosyalar:** `js/api.js`, `js/app.js`, `js/forms.js`

```
js/api.js: 14 adet console.log/warn
js/app.js: 11 adet console.log/warn
js/forms.js: 9 adet console.log/warn
```

Production'da bu log'lar:
- Kullanıcı deneyimini bozar
- Log dökümanı şişirir
- Potansiyel bilgi sızdırma riski

**Öneri:** Global `DEBUG_MODE` flag ile kontrol edilmeli veya tamamen kaldırılmalı.

---

### O-2: Tekrar Eden `pullTables` Zincirleri

**Severity:** Orta — Performans  
**Dosyalar:** `js/forms.js` (9 yerde)

```javascript
// Her form submit sonrası aynı pattern
pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
```

Her seferinde tüm hayvanlar tablosu çekiliyor. Case-based sisteme geçişle bu artık gereksiz — sadece etkilenen hayvan çekilmeli.

**Öneri:** Hedefli tablo güncellemesi (incremental pull).

---

### O-3: Deprecated RPC Kullanım Potansiyeli

**Severity:** Orta — Bakım zorluğu  
**Dosyalar:** `js/forms.js`, `js/ui.js`

Eski sistem RPC'leri:
- `hastalik_kaydet` — deprecated
- `tedavi_ekle` — deprecated
- `tedavi_sil` — deprecated

Eski UI kodları hâlâ bu fonksiyonlara referans verebilir. Temizlik yapılmadı.

**Öneri:** Deprecated fonksiyonlar için `console.warn` ile logger veya tam kaldırma.

---

### O-4: Migration Versiyonlama Tutarsızlığı

**Severity:** Orta — Deployment riski  
**Dosyalar:** `supabase/migrations/`

| Dosya | Sorun |
|-------|-------|
| `20260409000001_fix_kizginlik_log_select_policy.sql` | 7 satır |
| `20260409000001_fix_tohumlama_sonuc_gebe.sql` | 83 satır |

Aynı timestamp ile iki migration dosyası var. Bu, sıralama veya deployment hatasına yol açabilir.

**Öneri:** Her migration için unique timestamp + 3 basamaklı sequence.

---

### O-5: Yapılandırma Tek Nokta

**Severity:** Orta — Güvenlik  
**Dosyalar:** `js/config.js`, `.claude/CREDENTIALS.md`

```javascript
// config.js — hardcoded URL
const CONFIG = {
  SUPABASE_URL: 'https://zqnexqbdfvbhlxzelzju.supabase.co',
  SUPABASE_ANON_KEY: '...'
};
```

Anon key ve URL frontend'de açık. Production'da RLS kritik.

**Öneri:** Key rotation mekanizması ve environment-based config.

---

## 🟢 OPTİMİZE ÖNERİLERİ

### OPT-1: Test Coverage Artırımı

**Mevcut:** Playwright E2E (44 test)  
**Eksik:** Unit test, integration test

**Öneri:** Vitest veya Jest ile core fonksiyonları test edilmeli.

---

### OPT-2: Code Splitting

**Mevcut:** Tek bundle (~3171 LOC ui.js)  
**Öneri:** Modal bazlı chunking

```
ui.js → ui.modals.js, ui.dashboard.js, ui.forms.js
```

---

### OPT-3: State Yönetimi Merkezi

**Mevcut:** 10+ global değişken (`_A`, `_S`, `_curTaskFilter`, vb.)  
**Öneri:** Tek `AppState` objesi veya Redux-like pattern

---

### OPT-4: RPC Type Safety

**Mevcut:** Runtime type check yok  
**Öneri:** JSDoc annotation + TypeScript veya PropTypes

---

### OPT-5: Offline-First Sync Protocol

**Mevcut:** Basic IDB + syncNow()  
**Öneri:** CRDT veya operation transform-based conflict resolution

---

## Detaylı Dosya Analizi

### `js/ui.js` (3171 LOC, 143 fonksiyon)

| Metrik | Değer |
|--------|-------|
| Fonksiyon sayısı | 70 async function |
| Global dependency | 35 global değişken |
| Console kullanımı | 0 (temiz) |
| FIXME/TODO | 2 adet (DEBUG, selDis) |

**Güçlü Yönler:**
- i18n Türkçe fonksiyon isimleri tutarlı
- Modal sistemi merkezi yönetim
- Formatter/helper fonksiyonlar ayrışmış

**Zayıf Yönler:**
- `band()`, `_dashStatRow()` gibi büyük template string'ler
- CSS class bazlı rendering (debug zor)
- Error boundary yok

---

### `js/forms.js` (1093 LOC, 48 fonksiyon)

| Metrik | Değer |
|--------|-------|
| Async function | 35 |
| pullTables çağrısı | 9 |
| Console kullanımı | 9 (warning-level) |

**Güçlü Yönler:**
- Form validation merkezi
- RPC wrapper pattern tutarlı

**Zayıf Yönler:**
- Form state'in bir kısmı DOM'da, bir kısmı JS'de
- Submit handler'lar karmaşık callback chains

---

### `js/api.js` (404 LOC, 24 fonksiyon)

| Metrik | Değer |
|--------|-------|
| Console log | 14 |
| Realtime | Aktif |

**Güçlü Yönler:**
- IndexedDB abstraction temiz
- Sync queue mekanizması sağlam

**Zayıf Yönler:**
- Retry logic minimal
- Error recovery eksik

---

### `supabase/migrations/` (42 dosya)

**Toplam:** 42 migration, ~5500 LOC SQL

| Kategori | Sayı |
|----------|------|
| Schema oluşturma | ~15 |
| FK/Constraint | ~8 |
| Trigger | ~6 |
| RPC fonksiyonu | ~12 |
| Fix/hotfix | ~5 |

**Risk:** `CREATE OR REPLACE` kullanımı yüksek.

---

## Öncelikli Eylem Planı

### 1. Acil (Bu Sprint)

- [ ] K-1: Migration protocol güncelle — DROP + CREATE pattern
- [ ] K-2: CLN-FIX serisini uygula (SPEC.md)
- [ ] K-3: Stok race condition için idempotent handler

### 2. Kısa Vade (1-2 Sprint)

- [ ] O-1: Console.log'ları DEBUG flag'e bağla
- [ ] O-2: pullTables optimizasyonu
- [ ] O-4: Migration timestamp tutarlılığı

### 3. Orta Vade (3-4 Sprint)

- [ ] OPT-1: Unit test ekle
- [ ] OPT-3: State merkezileştirme
- [ ] OPT-5: Conflict resolution protocol

---

## Sonuç

Proje **fonksiyonel ve üretimde** görünüyor, ancak teknik borç ciddi. En kritik sorun:

1. **Migration anti-pattern** — veri kaybı riski
2. **Orphaned JS fonksiyonları** — runtime hatalar
3. **Sync race condition** — veri tutarsızlığı

Bunlar düzeltildikten sonra proje stabilize olacak. Devam eden geliştirme için SPEC.md ve ARCHITECTURE.md güncel tutulmalı.

---

*Bu rapor otomatik olarak oluşturulmuştur.*