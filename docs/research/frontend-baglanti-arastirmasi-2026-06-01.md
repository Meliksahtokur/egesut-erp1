# EgeSüt ERP — Frontend Bağlantı Araştırması

**Tarih:** 2026-06-01  
**Kapsam:** Frontend'in hangi kaynaklara bağlandığı, RPC envanteri, state yönetimi, Edge Function durumu

---

## 1. Script Yükleme Sırası (index.html)

`<body>` sonunda 13 script tag'i, aşağıdaki sırayla:

| Sıra | Dosya | Rol |
|------|-------|-----|
| 0 | `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js` | Supabase SDK (harici) |
| 1 | `js/utils/helpers.js?v=1780324600` | DOM yardımcıları, toast, autocomplete, debounce |
| 2 | `js/utils/modal.js?v=1780324600` | Modal yönetimi (openM/closeM/mClose) |
| 3 | `js/utils/errorHandler.js?v=1780324600` | Merkezi hata yönetimi (withErrorHandling) |
| 4 | `js/utils/events.js?v=1780324600` | Event handler'lar |
| 5 | `js/config.js?v=1780324600` | GRUP_PADOK mapping, sabit listeler |
| 6 | `js/state.js?v=1780324600` | AppState sınıfı, getState/setState |
| 7 | `js/api.js?v=1780324600` | Supabase client, IndexedDB, RPC wrapper, pullTables |
| 8 | `js/ui.js?v=1780324600` | Tüm render fonksiyonları (5721 satır) |
| 9 | `js/forms.js?v=1780324600` | Form submit işlemleri, validasyon |
| 10 | `js/app.js?v=1780324600` | Uygulama init, routing, global state |
| 11 | `js/utils/handlers.js?v=1780324600` | HTML onclick event function'lar |
| 12 | `agent-telemetry/tracker.js` | Agent telemetry (opsiyonel) |

Tüm yerel script'lerde `?v=1780324600` cache-buster kullanılıyor.

---

## 2. Supabase Client Initialization (js/api.js:7-18)

```js
const SB_URL  = 'https://zqnexqbdfvbhlxzelzju.supabase.co';
const SB_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';  // anon key

const { createClient } = window.supabase;
const db = createClient(SB_URL, SB_KEY);
```

- `window.supabase` → Supabase UMD bundle (CDN'den yüklenir).
- **Anon key** kullanılır — yetkilendirme RLS politikalarına bırakılmıştır.
- Doğrudan `db.from(table).select(...)` ile okuma yapılır (view'lar üzerinden).
- Tüm yazma işlemleri Supabase RPC üzerinden yapılır.

### RPC Wrapper (js/api.js:43-49)

```js
async function rpc(name, params = {}) {
  if (!navigator.onLine) throw new Error('İnternet bağlantısı gerekli');
  const { data, error } = await db.rpc(name, params);
  if (error) throw new Error(_trErr(error.message));
  if (data && data.ok === false) throw new Error(data.mesaj || 'İşlem başarısız');
  return data;
}
```

Tüm RPC çağrıları bu wrapper'dan geçer (istisnalar: `hekim_listesi`, `irk_listesi`, `stat_suru_ozet` doğrudan `db.rpc()` ile çağrılır).

Optimistic wrapper da var — `rpcOptimistic()` (js/api.js:354-374): önce toast gösterir, sonra RPC'yi çağırır, arka planda ilgili tabloları IndexedDB'ye çeker.

---

## 3. Frontend'den Yapılan Tüm RPC Çağrıları

Toplam **~70 farklı RPC** çağrılıyor. Gruplandırılmış liste:

### Hayvan Yönetimi

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `hayvan_ekle` | forms.js:79 | Yeni hayvan kaydı |
| `hayvan_guncelle` | forms.js:53 | Hayvan düzenleme |
| `cikis_yap` | forms.js:567 | Hayvan çıkışı |
| `buzagi_sutten_kesme_onayla` | forms.js:633 | Buzağıyı sütten kes |
| `buzagi_sutten_kesme_kontrol` | ui.js:272 | Otomatik kontrol (loadDash) |
| `hayvan_tohumlanabilir_onayla` | forms.js:648 | Tohumlanabilir onayı |
| `hayvan_tohumlama_ertele` | forms.js:661 | Tohumlamayı ertele |
| `hayvan_not_ekle` | forms.js:519 | Not ekle |

### Doğum

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `dogum_kaydet` | forms.js:127 | Doğum kaydı |

### Tohumlama / Üreme

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `tohumlama_kaydet` | forms.js:241 | Tohumlama kaydı |
| `tohumlama_tekrar_kaydet` | forms.js:305 | Tekrar aşım |
| `tohumlama_sonuc_gebe` | ui.js:1750 | Gebe işaretle |
| `tohumlama_sonuc_bos` | forms.js:1051 | Boş işaretle |
| `tohumlama_sonuc_bekliyor` | forms.js:1055 | Bekliyor'a al |
| `tohumlama_abort` | forms.js:500 | Abort kaydet |
| `tohumlama_geri_al` | api.js RPC_TABLES | Tohumlama geri alma |
| `gebelik_kaydet_manual` | forms.js:1221 | Manuel gebelik kaydı |
| `gebelik_protokol_kontrol` | ui.js:161, app.js:626 | İleri gebe kontrolü |
| `kizginlik_kaydet` | forms.js:357 | Kızgınlık kaydı |
| `kizginlik_sil` | ui.js:320 | Kızgınlık sil |
| `kizginlik_yok_kaydet` | ui.js:298 | Kızgınlık yoktu |
| `kizginlik_tedavi_baglanti_kur` | forms.js:475 | Kızgınlık→tedavi bağla |
| `kizginlik_vaka_ac` | ui.js:1628 | Kızgınlıktan vaka aç |
| `sessiz_hayvanlar_listele` | ui.js:278,676 | Sessiz hayvan listesi |

### Vaka / Tedavi

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `create_case` | forms.js:453 | Vaka aç |
| `close_case` | api.js RPC_TABLES | Vaka kapat |
| `add_treatment_day` | ui.js:4070 | Tedavi günü ekle |
| `delete_treatment_day` | api.js RPC_TABLES | Tedavi günü sil |
| `update_treatment_time` | ui.js:3892 | Tedavi saati güncelle |
| `treatment_day_tamamla` | ui.js:3904 | Tedavi gününü tamamla |
| `treatment_day_not_guncelle` | ui.js:3947 | Tedavi notu güncelle |
| `add_drug_administration` | ui.js:4193 | İlaç uygulama ekle |
| `remove_drug_administration` | ui.js:4244 | İlaç uygulama sil |
| `case_geri_al` | api.js RPC_TABLES | Vaka geri alma |
| `hastalik_kapat` | forms.js:919 | Hastalık kaydı kapat |
| `hastalik_guncelle` | forms.js:1000 | Hastalık güncelle |
| `hastalik_sil` | forms.js:1023 | Hastalık sil |
| `disease_sil` | ui.js:2350 | Hastalık sil (rpcOptimistic) |
| `tedavi_ekle` | forms.js:1298 | Tedavi ekle |

### Aşılama

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `add_vaccination` | forms.js:793 | Tek aşı ekle |
| `bulk_vaccination` | api.js RPC_TABLES | Toplu aşılama |
| `vaccination_dismiss` | ui.js:361 | Aşı ertele/iptal |
| `ileri_gebe_asi_tamamla` | ui.js:3444 | İleri gebe aşı tamamla |
| `vaccine_rapel_guncelle` | api.js RPC_TABLES | Rapel tarihi güncelle |

### Stok

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `stok_ekle` | forms.js:1174 | Yeni stok ürünü ekle |
| `stok_ekleme` | forms.js:1135,1170 | Stok miktar ekle |
| `stok_guncelle` | api.js RPC_TABLES | Stok güncelle |
| `stok_arsivle` | api.js RPC_TABLES | Stok arşivle |
| `stok_hareket_ekle` | api.js RPC_TABLES | Stok hareketi ekle |
| `link_drug_to_stock` | ui.js:2096 | İlaç-stok bağlantısı |
| `drug_product_ekle` | forms.js:1183 | İlaç ürünü ekle |
| `drug_class_ekle` | api.js RPC_TABLES | İlaç sınıfı ekle |
| `drug_class_guncelle` | api.js RPC_TABLES | İlaç sınıfı güncelle |
| `drug_class_sil` | api.js RPC_TABLES | İlaç sınıfı sil |
| `drug_class_varsayilan_yukle` | ui.js:2362 | Varsayılan ilaç sınıflarını yükle |

### Görev

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `gorev_tamamla` | forms.js:830, ui.js:3911 | Görev tamamla |
| `gorev_geri_al` | ui.js:3546 | Görev geri al |
| `besleme_tamam` | ui.js:547 | Besleme görevi tamamla |

### İşlem Geçmişi / Geri Alma

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `islem_geri_al` | ui.js:1161 | İşlem geri al |
| `geri_al` | api.js RPC_TABLES | Genel geri alma |
| `abort_kaydet` | api.js RPC_TABLES | Abort kaydet |

### Admin / Referans

| RPC | Dosya:Satır | Kullanım |
|-----|-------------|----------|
| `hekim_listesi` | app.js:30 | Veteriner listesi |
| `hekim_ekle` | app.js:178 | Veteriner ekle |
| `hekim_guncelle` | api.js RPC_TABLES | Veteriner güncelle |
| `irk_listesi` | app.js:210 | Irk listesi |
| `bulk_ilac` | forms.js:~500 | Toplu ilaç uygulama |
| `stat_suru_ozet` | ui.js:707 | Sürü istatistik özeti |
| `padok_ekle` | api.js RPC_TABLES | Padok ekle |
| `padok_guncelle` | api.js RPC_TABLES | Padok güncelle |
| `padok_sil` | api.js RPC_TABLES | Padok sil |
| `grup_padok_eslem_toggle` | api.js RPC_TABLES | Grup-padok eşleme |
| `seed_defaults` | ui.js:2370 | Varsayılan veri yükle |

### Doğrudan `db.rpc()` ile çağrılanlar (wrapper'sız)

- `hekim_listesi` (app.js:30)
- `irk_listesi` (app.js:210)
- `stat_suru_ozet` (ui.js:707)
- `hekim_ekle` (app.js:178, fire-and-forget)

---

## 4. State Yönetimi (js/state.js)

Basit EventEmitter + global store, framework yok.

```js
class AppState {
  _state = {
    animals: [],               // hayvan listesi
    stock: [],                 // stok listesi
    curStok: null,             // seçili stok
    currentPage: 'dash',       // aktif sayfa
    suruFilter: 'tumuu',       // sürü filtresi
    suruSiralama: 'kupe',      // sıralama
    currentUremeTab: 'kizginlik',
    currentHistoryFilter: 'hepsi',
    currentTaskFilter: 'today',
    currentTaskDetail: null,
    currentDisease: null,
    currentInsem: null,
    currentNotificationTab: 'bekliyor',
    gebeIds: [],               // gebe hayvan ID'leri
    hastaIds: new Set(),       // hasta hayvan ID'leri (Set)
  };
  _listeners = {};

  get(key) → this._state[key]
  getAll() → shallow copy
  set(k, v) → emit(key, old, new) + emit('*')
  setBatch(obj) → toplu güncelleme, tek emit
  on(event, cb) → subscribe, return unsubscribe
  off(event, cb)
}

const AppStateInstance = new AppState();
globalThis.__state = AppStateInstance;

function getState(key)  { return globalThis.__state.get(key); }
function setState(k, v) { return globalThis.__state.set(k, v); }
```

**Önemli:** State persistence yapmaz — sadece runtime hafızası. Veriler IndexedDB'den `pullTables()` ile çekilir, state'e yazılır, UI state'ten okur.

---

## 5. Edge Function (stat-hesapla) Durumu

**Frontend'den çağrılmıyor.** `grep_files` ile `.html`, `.js`, `.ts`, `.json` dosyalarında `stat-hesapla` arandı: 0 sonuç.

Edge Function diskte mevcut:
```
supabase/functions/stat-hesapla/
├── index.ts        (206 satır — TypeScript)
├── deno.json
└── .npmrc
```

İçinde Supabase client ile doğrudan SQL sorgulama yapıyor (Türkçe locale-safe hesaplama). Deploy edilmiş olabilir ama frontend bağlı değil — **ölü/atıl kod** durumunda.

Dashboard istatistikler bunun yerine `stat_suru_ozet` SQL RPC'sini kullanıyor.

---

## 6. Dashboard İstatistik Paneli

Dashboard 3 katmanlı veri akışı kullanır:

### 6.1 Üst Satır Kartlar (`_dashStatRow`, ui.js:96-106)

| Kart | Veri Kaynağı | RPC? |
|------|-------------|------|
| Aktif Hayvan | `animals.length` (state) | Yok |
| Gebe | `gebeIds.length` (state) | Yok |
| Aktif Hastalık | `hastaIds.size` (state) | Yok |
| Sütten Kes | local filter (animals) | Yok |
| Bekleyen Görev | `tasks.length` (argüman) | Yok |

**Tamamen local/IDB verisi, RPC çağrısı yapmaz.**

### 6.2 Uyarı Bantları (`_dashBands`, ui.js:~250-289)

- `rpc('buzagi_sutten_kesme_kontrol')` — buzağı kontrol görevi oluştur
- `rpc('sessiz_hayvanlar_listele')` — sessiz hayvan listesi
- `rpc('gebelik_protokol_kontrol')` — ileri gebe kontrolü
- `db.from('cozulmemis_kizginlik_view').select(...)` — kızgınlık uyarı barı
- IDB'den: `treatment_days`, `cases`, `diseases`, `stok`, `stok_hareket`, `vaccination_log`, `vaccines`

### 6.3 Sürü İstatistik Detay Kartı (`_renderSuruStat`, ui.js:691-713)

```js
function _fetchSuruStat(el, padok, key) {
  const params = { p_son_donem: _suruStatMode === 'son' };
  if (padok) params.p_padok = padok;
  db.rpc('stat_suru_ozet', params).then(({ data }) => {
    if (data) { _suruStatCache[key] = data; _applySuruStatHtml(el, data, padok); }
  }).catch(e => console.warn('stat_suru_ozet:', e.message));
}
```

**`stat_suru_ozet` RPC** dönen veri yapısı:

```json
{
  "hayvan": { "inek": N, "duve": N, "erkek": N, "buzagi": N, "kisir": N, "toplam": N, "tohumlanan": N },
  "gebelik": {
    "hayvan_ozet": { "gebe": N, "bos": N, "toplam": N, "oran": N },
    "cycle_ozet": { "gebe_orani": N, "hizmet_araligi": N, "ilk_tohumlama": N }
  },
  "sperma_rest": [ ... ]
}
```

Cache: `_suruStatCache` ile, `_suruStatMode` ile "son dönem" / "tüm zamanlar" toggle'ı.

---

## Özet

| Soru | Cevap |
|------|-------|
| Script yükleme sırası | Supabase CDN → 6 utils → api → ui → forms → app → handlers |
| Supabase client init | `window.supabase.createClient(SB_URL, SB_KEY)` — anon key |
| RPC çağrı sayısı | ~70 farklı RPC (en yoğun: hayvan, tohumlama, tedavi, stok) |
| State yönetimi | AppState (EventEmitter), `getState/setState`, runtime only |
| Edge Function kullanımı | `stat-hesapla` frontend'den çağrılmıyor — atıl |
| Dashboard veri kaynağı | IDB (üst kartlar) + `stat_suru_ozet` RPC (detay) + 3 yardımcı RPC |
| API katmanı | Yok — frontend doğrudan Supabase RPC/JS client'a bağlı |
