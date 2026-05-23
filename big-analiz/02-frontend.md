# Frontend Analizi — EgeSüt ERP

## 1. JS Modül Yapısı

### 1.1 Dosyalar ve Sorumlulukları

| Dosya | Satır | Rol | Kilit Fonksiyonlar |
|---|---|---|---|
| **config.js** | 68 | Merkezi sabitler | `HEKIMLER`, `HASTALIK_LISTESI`, `SPERMA_LISTESI`, `GRUP_PADOK` |
| **state.js** | 84 | In-memory state yönetimi | `getState()`, `setState()`, `AppState` class |
| **api.js** | 332 | Supabase + IndexedDB layer | `rpc()`, `pullTables()`, `write()`, `RPC_TABLES` map |
| **app.js** | 737 | Routing, init, global listeners | `goTo()`, `window.load`, `window.online/offline` |
| **ui.js** | 2804 | Tüm render + modal açıcılar | `renderAnimals()`, `openDet()`, `loadDash()`, otomatik dispatch |
| **forms.js** | 938 | Tüm form submit handlers | `submitAnimal()`, `submitKizginlik()`, `submitBirth()`, RPC çağrıları |
| **index.html** | ~1200 | Layout, modal template'leri, inline styles | 209 `data-action` button'u, merkezi event dispatch |
| **sw.js** | Service worker | Offline caching + background sync | |

---

### 1.2 Mimariye Genel Bakış

```
┌─────────────────────────────────────────────────────────┐
│                      index.html                         │
│  (Layout + Modal Template'leri + 209 data-action)      │
└───┬────────────────────────────────────────────────────┘
    │ User click → data-action attribute → dispatch
    ▼
┌─────────────────────────────────────────────────────────┐
│                    app.js                               │
│  (Routing: goTo() + window.load/online/offline)         │
└───┬────────────────────────────────────────────────────┘
    │ Event delegation + Page navigation
    ▼
┌──────────────────┬──────────────────┬──────────────────┐
│    ui.js         │   forms.js       │    api.js        │
│  ─────────────   │  ──────────────  │  ────────────    │
│  • Rendering     │  • Submit handle │  • RPC wrapper   │
│  • Modals        │  • Validation    │  • IndexedDB     │
│  • Autocomplete  │  • Form prep     │  • Supabase      │
└──┬───────────────┴────────┬─────────┴────────┬─────────┘
   │                        │                  │
   └─ state.js (getState) ─ + ─ config.js ────┘
      (In-memory cache)        (Constants)
```

---

## 2. HTML Sayfa Yapısı

### 2.1 Ana Layout

```html
<div id="shell">
  ├─ <div id="topbar">         (Logo, sync dot, refresh btn)
  ├─ <div id="sync-bar">       (Çevrimdışı/sinkronizasyon mesajı)
  ├─ <div id="kizginlik-bar">  (Kızgınlık uyarısı şeridi)
  ├─ <div id="pages">
  │   ├─ #pg-dash             (Dashboard)
  │   ├─ #pg-suru             (Hayvan Listesi)
  │   ├─ #pg-ureme            (Tohumlama/Kızgınlık/Gebelik/Doğum/Abort)
  │   ├─ #pg-tasks            (Görevler)
  │   ├─ #pg-gecmis           (Geçmiş)
  │   └─ #pg-log              (Hızlı Kayıt — Doğum/Tohumlama/Vaka/Toplu Aşı/Toplu İlaç/Yeni Hayvan)
  ├─ <nav id="nav">           (Bottom navigation — 5 tab)
  ├─ <div id="det">            (Hayvan Detay — sağ panel)
  ├─ <div id="stok-panel">     (Stok Yönetimi — sağ panel)
  └─ <div id="m-*">            (20+ Modal'lar)
```

### 2.2 Sayfalar

| ID | Başlık | İçerik | Butonu |
|---|---|---|---|
| `#pg-dash` | Panel | 8 stat card, gebe özeti, kızgınlık bandı, erişkin görev bandı | `#nb-dash` |
| `#pg-suru` | Sürü | Hayvan listesi (arama + 6 filtre chip) | `#nb-suru` |
| `#pg-ureme` | Üreme | 5 tab (Kızgınlık/Tohumlama/Gebelik/Doğum/Abort) + filtreleme | `#nb-ureme` + ubadge |
| `#pg-tasks` | Görevler | Görev listesi (4 tab + 7 kategori chip) | `#nb-tasks` + tbadge |
| `#pg-gecmis` | Geçmiş | 6 filtre (Hepsi/Doğum/Tohumlama/Hastalık/Görev/Hayvan) | `#nb-gecmis` |
| `#pg-log` | Kayıt | 6 hızlı aksiyon + son doğumlar | `#nb-log` |

### 2.3 Detay Panel ve Modal'lar

**Sağ Panel — #det:**
- Hayvan adı + meta + çipler
- 5 tab: Özet | Sağlık | Üreme | Görevler | Geçmiş
- Sağlaştır/İlaç/Undo butonları

**Stok Panel — #stok-panel:**
- 5 tab (Tümü/İlaç/Aşı/Sperma/Diğer)
- Ürün ara + ürün listesi
- Ürün ekle + hareket listesi

**20+ Modal'lar:**
```
#m-kizginlik        — Kızgınlık kaydı
#m-insem            — Tohumlama kaydı
#m-insem-tekrar     — Tekrar aşım
#m-disease          — Vaka aç (legacy)
#m-vaccine          — Aşı uygula
#m-bulk-vaccine     — Toplu aşılama (3 tab)
#m-bulk-ilac        — Toplu ilaç (3 tab)
#m-birth            — Doğum kaydı
#m-animal           — Yeni/Düzenleme hayvan
#m-stk              — Stok girişi
#m-task-add         — Manuel görev ekle
#m-stok-add         — Yeni stok ürünü
#m-stok-hareketler  — Tüm hareketler
#m-ayarlar          — Ayarlar (Hekimler + Padoklar)
```

---

## 3. UI Bileşenleri

### 3.1 Dashboard Cards

```html
<div class="stat-row">
  <div class="sc [.warn|.alert|.ok]">     <!-- Color variant -->
    <div class="sv">8</div>                  <!-- Value -->
    <div class="sl">GEBE</div>               <!-- Label -->
  </div>
  ...
</div>
```

**Renkler:** `sc.ok` (yeşil), `sc.warn` (amber), `sc.alert` (kırmızı)

### 3.2 Animal Card

```html
<div class="animal-card">
  <div class="avt">🐄</div>                    <!-- Avatar -->
  <div class="ainfo">
    <div class="a-id">001</div>                <!-- Küpe -->
    <div class="a-sub">Siyah-beyaz, 3 yaş</div><!-- Meta -->
    <div class="a-tags">
      <span class="tag tg">🔁 Gebe</span>
      <span class="repeat-badge active">🔁 Tekrar</span>
    </div>
  </div>
</div>
```

### 3.3 Task Card

```html
<div class="task-card [.late|.soon|.done]">
  <div class="tc-header">
    <div class="tc-main">
      <div class="tc-id">T-001</div>
      <div class="tc-desc">Gebelik kontrolü…</div>
      <div class="tc-meta">
        <span class="pill ILAC">ILAC</span>
        <span>Bugün</span>
      </div>
    </div>
    <button class="ck-btn"></button>             <!-- Checkbox -->
  </div>
</div>
```

**Statüsler:** `.done` (opak), `.late` (kırmızı), `.soon` (amber), normal (yeşil)

### 3.4 Modal Yapısı

```html
<div id="m-xxx" class="mo" data-action="mclose-overlay">
  <div class="modal">
    <div class="m-handle"></div>                <!-- Drag handle -->
    <div class="m-title">🔴 Başlık</div>
    <div class="m-body">
      <div class="fg">                           <!-- Form Group -->
        <label class="flbl">Label</label>
        <input class="fi" />
        <div class="fhint">Hint text</div>
      </div>
      <button class="btn btn-g">Kaydet</button>
      <button class="btn btn-o">İptal</button>
    </div>
  </div>
</div>
```

### 3.5 Badge Sistemi

```html
<!-- Nav badge (görev sayısı) -->
<div id="tbadge" class="nbadge">12</div>        <!-- #nb-tasks'e child -->

<!-- Üreme badge -->
<div id="ubadge" class="nbadge">3</div>          <!-- #nb-ureme'ye child -->
```

**JS:** `updateTaskBadge(n)` — tbadge'i günceller
**JS:** `updateUremeBadge(n)` — ubadge'i günceller

### 3.6 Renkler & Stil Sistemi

**CSS Değişkenleri (`index.html` <style>):**
```css
:root {
  --bg: #111a0a;           /* Arka plan (dark green) */
  --bg2: #1a2812;
  --bg3: #22361a;
  --card: #f7f4ee;         /* Kart arka planı (krem) */
  --card2: #edeae2;
  --card3: #e2ddd3;
  --ink: #1a1f14;          /* Yazı rengi (siyah-yeşil) */
  --ink2: #3d4a32;
  --ink3: #6b7a5c;
  --green: #4e9a2a;        /* Başarı */
  --green2: #6abf3d;
  --green3: #98d96e;
  --amber: #c97d0a;        /* Uyarı */
  --red: #c0321a;          /* Hata */
  --red2: #e85535;
  --blue: #2a6bb5;         /* Info */
  --purple: #7c3aed;       /* Special */
}
```

**Dark Mode:** `body.dark` → `--card` açık olmaktan koyu'ya

### 3.7 Buton Varyantları

```html
<button class="btn btn-g">Kaydet</button>       <!-- Green -->
<button class="btn btn-o">İptal</button>        <!-- Outline -->
<button class="btn btn-r">Sil</button>          <!-- Red -->
<button class="btn btn-b">Info</button>         <!-- Blue -->
<button class="btn btn-sm">Mini</button>        <!-- Small -->
```

**Aktive state:** `.btn:active { transform: scale(.97) }`

---

## 4. Execution Flow'lar (Frontend)

### 4.1 Uygulama İnitialasyonu

```
window.load event
├─ openDB() — IndexedDB açılır
├─ loadHekimler() — DB'den hekimler çekilir
├─ loadIrkDropdown() — Irk listesi yüklenir
├─ renderFromLocal() — IDB'deki veri render edilir
├─ startBackgroundSync(30s) — Sync loop başlar
├─ initRealtime() — WebSocket bağlantısı kurulur
└─ if (online):
    ├─ pullFromSupabase() — Tüm tablolar çekilir
    ├─ renderFromLocal() — Yeni veri render edilir
    ├─ syncNow() — Offline queue senkronize edilir
    ├─ loadPadokConfig() + loadHekimlerFromDB() — Dinamik listeler
    └─ _TH preload — tohumlanabilir hayvanlar liste önbelleğe alınır
```

### 4.2 Sayfa Navigasyonu

**Kullanıcı tık:** Bottom nav button (`#nb-dash`, `#nb-suru`, vb.)
```
1. click event → #nav event delegation
2. Button `data-action="go-dash"` attribute'i okunur
3. goTo('dash', true) çağrılır
4. history.pushState({pg:'dash'})
5. page visibility: .pg.on class değiştirilir
6. Sayfa içeriği daha önceden renderlenmiş
```

**goTo() mantığı:**
```javascript
function goTo(pg, push = true) {
  // page hide
  document.querySelectorAll('.pg').forEach(p => p.classList.remove('on'));
  // page show
  g(`pg-${pg}`).classList.add('on');
  // nav highlight
  document.querySelectorAll('.nb').forEach(n => n.classList.remove('on'));
  g(`nb-${pg}`)?.classList.add('on');
  // history
  if (push) history.pushState({pg}, '', `#${pg}`);
}
```

### 4.3 Data-Action Dispatch Sistemi

index.html'deki `209` button'un tamamı `data-action` attribute'ine sahip.

**Pattern:**
```html
<button data-action="go-dash">Panel</button>
<button data-action="open-kizginlik">Kızgınlık Ekle</button>
<button data-action="submit-kizginlik">Kaydet</button>
```

**Dispatch nerede yapılıyor?**

forms.js ve ui.js'nin başında `data-input`, `data-change`, `data-keydown` attribute'lerine listener'lar bağlı:
```javascript
// ui.js line ~677
document.addEventListener('click', e => {
  if (!e.target.closest('#srch') && !e.target.closest('#ac-srch'))
    { const ac = document.getElementById('ac-srch'); if (ac) ac.style.display = 'none'; }
});

// forms.js:
// Dinamik olarak querySelector + onclick handler assignment (inline)
// Örn: <button data-action="submit-kizginlik" onclick="submitKizginlik(this)">
```

**Gerçek dispatch:** HTML'deki inline `onclick` attribute'leri:
```html
<button data-action="submit-kizginlik" onclick="submitKizginlik(this)">Kaydet</button>
<button onclick="goTo('dash')">Panel</button>
<button onclick="openM('m-kizginlik')">Kızgınlık Ekle</button>
```

### 4.4 Form Submit Flow

1. **User fills form** → input/textarea alanları doldurulur
2. **User clicks submit button** → `onclick="submitXxx(this)"`
3. **Validation** → `forms.js` başında kontrol
4. **RPC call** → `await rpc('fn_name', params)`
5. **pullTables()** → Etkilenen tablolar çekilir (RPC_TABLES mapinden)
6. **renderFromLocal()** → UI güncellenir
7. **Modal close** → `closeM('m-xxx')`
8. **Toast message** → Success/error feedback

**Örnek: submitKizginlik()**
```javascript
async function submitKizginlik(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  
  const kupe = v('k-hid').trim();
  const tarih = v('k-tarih');
  if (!kupe || !tarih) { toast('Gerekli alanları doldurunuz', true); return; }
  
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  
  try {
    const res = await rpc('kizginlik_kaydet', {
      p_hayvan_id: kupe,
      p_tarih: tarih,
      p_belirti: v('k-belirti'),
      p_notlar: v('k-notlar')
    });
    
    // Etkilenen tabloları çek
    await pullTables(['kizginlik_log', 'gorev_log']);
    
    // UI güncelle
    await renderFromLocal();
    
    // Modal kapat
    closeM('m-kizginlik');
    
    // Toast
    toast('🔴 Kızgınlık kaydedildi + görev oluşturuldu');
  } catch (e) {
    toast(e.message, true);
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; }
  }
}
```

### 4.5 Hayvan Detay Açılması

**Click animal card:**
```
1. onclick="openDet('hayvan-id')"
2. #det.on class eklenir (translateX(0) slide-in)
3. _detOpenId = hayvan-id (state)
4. Tab render:
   - #tab-ozet: openAnimalEdit, notlar, yapı
   - #tab-saglik: diseases + treatments
   - #tab-ureme: tohumlama history + kızgınlık + button'lar
   - #tab-gorev: task list
   - #tab-gecmis: islem_log history
5. Butonlar onclick handler'ları set edilir (dogumYaptiAc, abortKaydet, vb.)
```

### 4.6 Real-time Subscription (Realtime WebSocket)

```javascript
// api.js
function initRealtime() {
  db.channel('public:*')
    .on('postgres_changes', { event: '*', schema: 'public' }, payload => {
      console.log('RT update:', payload);
      pullTables([payload.table]);  // Tablo çekilir
      renderFromLocal();             // Render yenilenir
    })
    .subscribe();
}
```

**Fallback:** 30 saniye de bir background sync (polling)

---

## 5. CSS ve Stil Sistemi

### 5.1 Layout Sistem

**Flexbox + CSS Grid:**
```css
#shell {
  display: flex;
  flex-direction: column;
  height: 100dvh;  /* Dynamic viewport height (mobile notch compat) */
}

#pages {
  flex: 1;
  overflow: hidden;
  position: relative;
}

.pg {
  position: absolute;
  inset: 0;           /* top:0, right:0, bottom:0, left:0 */
  overflow-y: auto;
  display: none;
  padding-bottom: calc(var(--nav) + var(--safe) + 8px);  /* NAV height + safe area */
}

.pg.on {
  display: block;
}
```

**Safe area support (notch):**
```css
:root {
  --safe: env(safe-area-inset-bottom, 0px);
  --nav: 60px;
}

#nav {
  height: calc(var(--nav) + var(--safe));  /* 60px + notch bottom */
  padding-bottom: var(--safe);
}
```

### 5.2 Modal Sistem

```css
.mo {
  position: fixed;
  inset: 0;
  background: rgba(10, 20, 5, 0.8);          /* Darkened overlay -->
  backdrop-filter: blur(6px);                  /* Blur effect -->
  z-index: 80;
  display: none;
  align-items: flex-end;
  animation: slideup 0.28s cubic-bezier(.22, 1, .36, 1);
}

.mo.on {
  display: flex;
}

.modal {
  background: var(--card);
  border-radius: 22px 22px 0 0;              /* Bottom-only rounded -->
  width: 100%;
  max-height: 94dvh;
  overflow-y: auto;
  animation: slideup 0.28s;
}

@keyframes slideup {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}
```

### 5.3 Responsive Grid

```css
.stat-row {
  display: grid;
  grid-template-columns: repeat(2, 1fr);      /* 2 column -->
  gap: 8px;
}

.info-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1px;
  background: var(--card2);
  overflow: hidden;
  border-radius: var(--r2);
}
```

### 5.4 Animasyon'lar

```css
@keyframes spin { to { transform: rotate(360deg); } }
@keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.25; } }
@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }

.spin { animation: spin 0.7s linear infinite; }
#dot { animation: blink 2.5s infinite; }
.skel { animation: shimmer 1.3s infinite; }
```

### 5.5 Typography

```css
body {
  font-family: 'Plus Jakarta Sans', sans-serif;
  -webkit-font-smoothing: antialiased;
}

.logo-main { font-size: 1.3rem; font-weight: 800; }
.det-name { font-size: 1.7rem; font-weight: 800; }
.sv { font-size: 2rem; font-weight: 800; }        /* Card value -->
.pill { font-size: 0.58rem; font-weight: 800; }   /* Badge -->
.flbl { font-size: 0.65rem; font-weight: 800; text-transform: uppercase; }
```

---

## 6. Supabase Entegrasyonu (Frontend)

### 6.1 RPC Çağrıları (api.js)

**Wrapper function:**
```javascript
async function rpc(name, params = {}) {
  if (!navigator.onLine) throw new Error('İnternet bağlantısı gerekli');
  const { data, error } = await db.rpc(name, params);
  if (error) throw new Error(_trErr(error.message));
  if (data && data.ok === false) throw new Error(data.mesaj || 'İşlem başarısız');
  return data;
}
```

### 6.2 Optimistic RPC (rpcOptimistic)

```javascript
async function rpcOptimistic(name, params = {}, updateFn) {
  // 1. Update UI immediately
  if (updateFn) updateFn();
  
  try {
    // 2. Execute RPC
    const res = await rpc(name, params);
    
    // 3. Fetch updated tables
    const tables = RPC_TABLES[name] || [];
    if (tables.length) await pullTables(tables);
    
    // 4. Re-render
    await renderFromLocal();
    return res;
  } catch (e) {
    // 5. On error, re-render to revert UI
    await renderFromLocal();
    throw e;
  }
}
```

### 6.3 RPC_TABLES Map

api.js line ~260:
```javascript
const RPC_TABLES = {
  hayvan_ekle: ['hayvanlar'],
  dogum_kaydet: ['hayvanlar', 'dogum', 'gorev_log'],
  tohumlama_kaydet: ['tohumlama', 'gorev_log', 'stok', 'stok_hareket'],
  tohumlama_sonuc_gebe: ['hayvanlar', 'tohumlama', 'islem_log'],
  kizginlik_kaydet: ['kizginlik_log', 'gorev_log'],
  create_case: ['cases'],
  add_drug_administration: ['stok', 'stok_hareket', 'drug_administrations'],
  // ...
};
```

**Mantık:** RPC çağrısı sonrası bu tablolar `pullTables()` ile çekilir, IndexedDB güncellenir, UI yenilenir.

### 6.4 Table Views (Read-only)

pullTables() FETCHERS'daki views:
```javascript
const FETCHERS = {
  hayvanlar: () => db.from('hayvan_durum_view').select('*'),  /* Durum hesaplı view */
  stok: () => db.from('stok_tuketim_view').select('*'),       /* Hareket history'li */
  gebelik_ozet: () => db.from('gebelik_ozet_view').select('*'), /* Gebe sayıları */
  tohumlanabilir_hayvanlar: () => db.from('tohumlanabilir_hayvanlar').select('*'),
};
```

### 6.5 Offline Queue (IndexedDB)

write() → _writePost/PATCH:
```javascript
async function _writePost(table, arr, method, filter) {
  await idbPut(table, arr);
  if (navigator.onLine) {
    try {
      await dbInsert(table, arr);  /* Supabase'e yazılmaya çalış */
      // Queue'dan sil
      const q = await getQueue();
      for (const op of q) {
        if (op.table === table && ...) await removeFromQueue(op._qid);
      }
    } catch (e) {
      // Başarısız → offline_queue'ya koy
      await queueOp({ table, method, data: arr, filter });
      updateSyncBar();  /* Sync bar'a "syncing" göster */
    }
  } else {
    // Offline → direkt queue
    await queueOp({ table, method, data: arr, filter });
    updateSyncBar();
  }
  return arr;
}
```

---

## 7. State Yönetimi

### 7.1 Global State (state.js)

```javascript
const appState = new AppState();

// Okuma
getState('animals');        // Hayvan listesi
getState('currentPage');    // Aktif sayfa

// Yazma
setState('animals', data);
setState('currentPage', 'dash');
setState('hastaIds', new Set(...));

// Batch update
setState.setBatch({
  animals: [...],
  gebeIds: [...],
  currentPage: 'suru'
});
```

**State yapısı:**
```javascript
{
  animals: [],                    // Tüm hayvanlar
  stock: [],                       // Stok ürünleri
  currentPage: 'dash',             // Aktif sayfa
  currentUremeTab: 'kizginlik',    // Üreme sekmesi
  currentTaskFilter: 'today',      // Görev filtresi
  gebeIds: [],                     // Gebe hayvan ID'leri
  hastaIds: new Set(),             // Hasta hayvan ID'leri
  // ... 15+ key
}
```

### 7.2 Local State (UI-specific)

HTML data-* attributes + global JS variables:
```javascript
// ui.js
let _taskKategori = 'all';       // Task filter category
let _stokTab = 'tumu';             // Stock filter tab
let _curStokDet = null;            // Current stock detail
let _fchip = {...};                /* Animal filter state */
```

### 7.3 Form State (Input Binding)

```javascript
// Helper functions (helpers)
function g(id) { return document.getElementById(id); }
function v(id) { return g(id)?.value || ''; }      /* Get value */
function cl(id) { return g(id)?.classList; }       /* Get classList */
function esc(s) { return new DOMParser().parseFromString(s, 'text/html').documentElement.textContent; }

// Usage:
const kupe = v('k-hid');          /* Get value from #k-hid input -->
const tarih = v('k-tarih');
```

---

## 8. Performance & Optimizations

### 8.1 IndexedDB Caching

- **openDB():** LocalForage-style IndexedDB açılır
- **idbPut(table, data):** Veri IndexedDB'ye yazılır (async)
- **idbGetAll(table):** Veri IndexedDB'den okunur (fast)
- **idbClearAndPut(table, data):** Clear + put (atomic)

```javascript
async function idbPut(table, data) {
  const db = await openDB();
  const tx = db.transaction([table], 'readwrite');
  const store = tx.objectStore(table);
  for (const item of data) {
    if (!item.id) item.id = crypto.randomUUID();
    await store.put(item);
  }
}
```

### 8.2 Debounced Search

```javascript
let _filterTimer;
function filterA() {
  clearTimeout(_filterTimer);
  _filterTimer = setTimeout(() => {
    // Filter + render (250ms debounce)
    renderAnimals(filtered);
  }, 250);
}
```

### 8.3 Page Transition

`.pg` sayfaları önceden DOM'da (display: none):
- Click nav → class toggle (0ms paint)
- No page creation/destruction
- CSS transition smooth

### 8.4 Realtime + Polling Fallback

```javascript
initRealtime();              // WebSocket (if available)
startBackgroundSync(30000);  // Fallback: 30sn polling
```

---

## 9. Known Limitations & TODOs

1. **No central dispatch router** — inline `onclick` attribute'leri (209 adet)
2. **No component framework** — Vanilla JS + string template
3. **No form library** — Manual validation
4. **No unit tests** — E2E Playwright tests sadece
5. **Mobile-first but no touch gestures** — Swipe, long-press yok
6. **No PWA update strategy** — Service worker basic (cache only)
7. **Dark mode** — CSS variable override sadece (full implementation yok)

---

## 10. Dosya Path Referansları

| Dosya | Satır | İçerik |
|---|---|---|
| `/root/egesut-erp1/index.html` | ~1-262 | Inline CSS + Layout |
| `/root/egesut-erp1/index.html` | 263-1200 | HTML body |
| `/root/egesut-erp1/js/api.js` | 1-50 | Config + RPC wrapper |
| `/root/egesut-erp1/js/api.js` | 220-230 | write() function |
| `/root/egesut-erp1/js/api.js` | 260-299 | RPC_TABLES map |
| `/root/egesut-erp1/js/api.js` | 324-369 | pullTables() function |
| `/root/egesut-erp1/js/app.js` | 1-50 | Helpers + uiLog |
| `/root/egesut-erp1/js/app.js` | 78-120 | goTo() + routing |
| `/root/egesut-erp1/js/app.js` | 566-660 | Event listeners + init |
| `/root/egesut-erp1/js/ui.js` | 1-50 | Helpers + task filter |
| `/root/egesut-erp1/js/ui.js` | 126-540 | Animal list + detail |
| `/root/egesut-erp1/js/ui.js` | 680-847 | Births + Üreme tabs |
| `/root/egesut-erp1/js/ui.js` | 1094-1273 | Stock management |
| `/root/egesut-erp1/js/ui.js` | 2228-2403 | Autocomplete'ler |
| `/root/egesut-erp1/js/forms.js` | 25-938 | Form submit handlers |
| `/root/egesut-erp1/js/config.js` | 1-68 | Constants |
| `/root/egesut-erp1/js/state.js` | 1-84 | AppState class |
| `/root/egesut-erp1/.claude/ui-map.md` | — | UI bölüm haritası |

---

## Summary

**EgeSüt frontend:**
- **Vanilla JS** — Framework-free, 5 core modules
- **Mobile-first CSS** — Responsive grid + flexbox
- **Offline-first architecture** — IndexedDB + Supabase
- **Event delegation** — 209 data-action button'lar
- **Modal/panel stack** — #det, #stok-panel, 20+ modal'lar
- **Real-time capable** — Supabase WebSocket + 30sn polling fallback
- **PWA ready** — Service worker + manifest.json

**Strengths:**
- Clean separation: config → state → api → ui → forms
- Offline queue + background sync
- Fast IndexedDB caching
- No external JS dependency (Supabase SDK only)

**Weaknesses:**
- No centralized router (inline onclick)
- No component framework
- Large ui.js file (2804 satır)
- Manual form validation
